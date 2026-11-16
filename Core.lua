local _, ns = ...
local Protocol = ns.Protocol
local Names = ns.Names
local Rows = ns.Rows
local Bags = ns.Bags

local PREFIX = "PartyBag"
-- Looting fires BAG_UPDATE_DELAYED in bursts; waiting lets one snapshot cover the whole burst.
local BROADCAST_DELAY = 2
-- Spacing chunks keeps us well under the client's addon-message throttle.
local SEND_INTERVAL = 0.2

local L = LibStub("AceLocale-3.0"):GetLocale("PartyBag")

ns.DEFAULTS = { showHeader = false, showSelf = false, mode = "SHORT" }

local playerName
local peers = {}   -- [name] = { [itemID] = count }
local pending = {} -- [name] = { seq, total, received, counts }
local roster = {}  -- [name] = classFile
-- The client rebuilds item tooltips several times a second, so rows are built once per item and reused.
local rowCache = {} -- [itemID] = { { name, count, r, g, b } }
-- Shared by the broadcast and the own tooltip row; dropped on every bag change so one scan serves both.
local selfCounts
local wasInGroup = false
local lastSent
local seq = 0
local broadcastTimer
local broadcastForced = false
local queue = {}
local queueTicker

local function Print(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99PartyBag|r: " .. text)
end

-- Brackets expose stray whitespace or realm suffixes that would otherwise look identical in chat.
local function Debug(fmt, ...)
    if PartyBagDB and PartyBagDB.debug then
        Print("|cff999999debug|r " .. fmt:format(...))
    end
end

local function InvalidateRows(reason)
    Debug("rows reset: %s", reason)
    wipe(rowCache)
end

local function NormalizeName(name)
    return name and Ambiguate(name, "none")
end

local function GroupChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and not IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return "INSTANCE_CHAT"
    end
    if IsInRaid() then
        return "RAID"
    end
    if IsInGroup() then
        return "PARTY"
    end
end

local GetNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots

local function GetSlotItem(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then
            return info.itemID, info.stackCount
        end
        return nil
    end
    local _, count, _, _, _, _, _, _, _, itemID = GetContainerItemInfo(bag, slot)
    return itemID, count
end

local function ScanBags()
    return Bags.Scan(Bags.LastIndex(NUM_BAG_SLOTS, NUM_TOTAL_EQUIPPED_BAG_SLOTS), GetNumSlots, GetSlotItem)
end

local function GetSelfCounts()
    if not selfCounts then
        selfCounts = ScanBags()
    end
    return selfCounts
end

function ns.OnSettingsChanged()
    InvalidateRows("settings")
end

local function PumpQueue()
    local message = table.remove(queue, 1)
    if not message then
        queueTicker:Cancel()
        queueTicker = nil
        return
    end
    local channel = GroupChannel()
    if channel then
        C_ChatInfo.SendAddonMessage(PREFIX, message.text, channel)
    end
end

local function Enqueue(kind, texts)
    -- An unsent tail of an older snapshot is obsolete; receivers drop the partial when chunk 1 of the new one arrives.
    if kind == "S" then
        for i = #queue, 1, -1 do
            if queue[i].kind == "S" then
                table.remove(queue, i)
            end
        end
    end
    for _, text in ipairs(texts) do
        queue[#queue + 1] = { kind = kind, text = text }
    end
    if not queueTicker then
        queueTicker = C_Timer.NewTicker(SEND_INTERVAL, PumpQueue)
    end
end

local function Broadcast()
    local force = broadcastForced
    broadcastTimer, broadcastForced = nil, false
    if not GroupChannel() then
        return
    end
    local tokens = Protocol.Serialize(GetSelfCounts())
    local signature = table.concat(tokens, ",")
    if not force and signature == lastSent then
        return
    end
    lastSent = signature
    seq = seq + 1
    Enqueue("S", Protocol.BuildSnapshot(tokens, seq))
end

-- force=true resends even an unchanged snapshot, because a newcomer has never seen it.
local function ScheduleBroadcast(delay, force)
    broadcastForced = broadcastForced or force or false
    if broadcastTimer then
        return
    end
    broadcastTimer = C_Timer.NewTimer(delay, Broadcast)
end

local function RequestSnapshots()
    Enqueue("R", { Protocol.BuildRequest() })
end

local function RefreshRoster()
    wipe(roster)
    InvalidateRows("roster")
    local unknown = false
    local prefix, count = "party", GetNumSubgroupMembers()
    if IsInRaid() then
        prefix, count = "raid", GetNumGroupMembers()
    end
    for i = 1, count do
        local unit = prefix .. i
        local name = Names.FromParts(UnitFullName(unit))
        if not name or name == UNKNOWNOBJECT then
            Debug("roster %s: not resolved yet", unit)
            unknown = true
        else
            local _, classFile = UnitClass(unit)
            Debug("roster %s: [%s], class %s", unit, name, tostring(classFile))
            roster[name] = classFile or true
        end
    end
    -- Names resolve lazily after a roster change; pruning now would wipe valid peers.
    if unknown then
        return
    end
    for name in pairs(peers) do
        if not roster[name] then
            peers[name] = nil
        end
    end
    for name in pairs(pending) do
        if not roster[name] then
            pending[name] = nil
        end
    end
end

local function OnGroupChanged()
    local inGroup = IsInGroup()
    if not inGroup then
        wipe(peers)
        wipe(pending)
        wipe(roster)
        InvalidateRows("left group")
        wipe(queue)
        lastSent = nil
        wasInGroup = false
        return
    end
    RefreshRoster()
    if not wasInGroup then
        wasInGroup = true
        RequestSnapshots()
        ScheduleBroadcast(BROADCAST_DELAY, true)
    end
end

local function OnSnapshotChunk(sender, message)
    if message.idx == 1 then
        pending[sender] = { seq = message.seq, total = message.total, received = 0, counts = {} }
    end
    local state = pending[sender]
    -- A chunk without its predecessors means we joined mid-transfer; wait for the next full snapshot.
    if not state or state.seq ~= message.seq or state.received + 1 ~= message.idx then
        pending[sender] = nil
        return
    end
    Protocol.DecodePayload(message.payload, state.counts)
    state.received = message.idx
    if state.received == state.total then
        Debug("snapshot complete from [%s]", sender)
        peers[sender] = state.counts
        pending[sender] = nil
        InvalidateRows("snapshot")
    end
end

local function OnAddonMessage(prefix, text, _, sender)
    if prefix ~= PREFIX then
        return
    end
    local name = NormalizeName(sender)
    if not name or name == playerName then
        Debug("drop self [%s] -> [%s], player [%s]", tostring(sender), tostring(name), tostring(playerName))
        return
    end
    local message = Protocol.Parse(text)
    if not message then
        Debug("drop unparsed from [%s]: %s", name, text)
        return
    end
    Debug("recv %s from [%s] -> [%s], player [%s]", message.kind, sender, name, tostring(playerName))
    if message.kind == "R" then
        -- Jitter spreads replies so a whole raid does not answer in the same frame.
        ScheduleBroadcast(1 + math.random() * 1.5, true)
    elseif message.kind == "S" then
        OnSnapshotChunk(name, message)
    end
end

local function ClassColor(classFile)
    local color = RAID_CLASS_COLORS[classFile]
    if color then
        return color.r, color.g, color.b
    end
    return 1, 1, 1
end

local function BuildRows(itemID)
    local showSelf = PartyBagDB.showSelf
    local rows = Rows.Build(peers, itemID, {
        full = PartyBagDB.mode == "FULL",
        selfName = showSelf and playerName or nil,
        selfCounts = showSelf and GetSelfCounts() or nil,
    })
    local _, selfClass = UnitClass("player")
    for _, row in ipairs(rows) do
        local classFile = row.name == playerName and selfClass or roster[row.name]
        Debug("tooltip item %d: [%s] = %d, class %s", itemID, row.name, row.count, tostring(classFile))
        row.r, row.g, row.b = ClassColor(classFile)
    end
    return rows
end

-- Debug-only probe: reads the first row back a moment later to see whether the client recolored it after us.
local tooltipCalls, colorCheckPending = 0, false
local function ProbeRowColor(tooltip, firstLine, rows)
    tooltipCalls = tooltipCalls + 1
    if colorCheckPending or not (PartyBagDB and PartyBagDB.debug) then
        return
    end
    colorCheckPending = true
    C_Timer.After(0.3, function()
        colorCheckPending = false
        for i, row in ipairs(rows) do
            local lineIndex = firstLine + i - 1
            local line = _G[tooltip:GetName() .. "TextLeft" .. lineIndex]
            local text = line and line:GetText()
            local r, g, b = 0, 0, 0
            if line then
                r, g, b = line:GetTextColor()
            end
            Debug("probe line %d [%s] = %.2f %.2f %.2f, expected [%s] = %.2f %.2f %.2f, calls %d, shown %s",
                lineIndex, tostring(text), r, g, b, row.name, row.r, row.g, row.b, tooltipCalls, tostring(tooltip:IsShown()))
        end
        tooltipCalls = 0
    end)
end

local function AddTooltipLines(tooltip, itemID)
    -- Solo there is nobody to compare with, so even the own row would only repeat the bag count.
    if not itemID or not IsInGroup() or not (next(peers) or PartyBagDB.showSelf) then
        return
    end
    local rows = rowCache[itemID]
    if not rows then
        rows = BuildRows(itemID)
        rowCache[itemID] = rows
    end
    if #rows == 0 then
        return
    end
    tooltip:AddLine(" ")
    if PartyBagDB.showHeader then
        tooltip:AddLine(L.TOOLTIP_HEADER, 0.2, 1, 0.6)
    end
    for _, row in ipairs(rows) do
        tooltip:AddDoubleLine(row.name, row.count, row.r, row.g, row.b, 1, 1, 1)
    end
    local firstLine = tooltip:NumLines() - #rows + 1
    local probeNow = PartyBagDB.debug and not colorCheckPending
    local function ReadNow(stage)
        local line = _G[tooltip:GetName() .. "TextLeft" .. (firstLine + #rows - 1)]
        Debug("probe %s line %d = %.2f %.2f %.2f", stage, firstLine + #rows - 1, line:GetTextColor())
    end
    if probeNow then
        ReadNow("after add")
    end
    ProbeRowColor(tooltip, firstLine, rows)
    tooltip:Show()
    if probeNow then
        ReadNow("after show")
    end
end

local function HookTooltips()
    -- Comparison tooltips are excluded so the same block is not printed two or three times.
    local targets = { [GameTooltip] = true, [ItemRefTooltip] = true }
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            if targets[tooltip] then
                AddTooltipLines(tooltip, data and data.id)
            end
        end)
        Debug("hook: TooltipDataProcessor")
        return
    end
    Debug("hook: OnTooltipSetItem")
    local getInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    for tooltip in pairs(targets) do
        tooltip:HookScript("OnTooltipSetItem", function(self)
            local _, link = self:GetItem()
            if link then
                AddTooltipLines(self, (getInstant(link)))
            end
        end)
    end
end

local function PrintStatus()
    if not IsInGroup() then
        Print(L.NOT_IN_GROUP)
        return
    end
    if not next(peers) then
        Print(L.NO_DATA)
        return
    end
    for name, counts in pairs(peers) do
        local kinds = 0
        for _ in pairs(counts) do
            kinds = kinds + 1
        end
        Print("[" .. name .. "]: " .. kinds)
    end
end

SLASH_PARTYBAG1 = "/partybag"
SLASH_PARTYBAG2 = "/pbag"
SlashCmdList.PARTYBAG = function(input)
    input = strtrim(input or ""):lower()
    if input == "sync" then
        if not IsInGroup() then
            Print(L.NOT_IN_GROUP)
            return
        end
        RequestSnapshots()
        ScheduleBroadcast(0.5, true)
        Print(L.SYNC_REQUESTED)
    elseif input == "debug" then
        PartyBagDB.debug = not PartyBagDB.debug
        Print(PartyBagDB.debug and L.DEBUG_ON or L.DEBUG_OFF)
        local fullName, fullRealm = UnitFullName("player")
        Debug("player [%s], full [%s]-[%s], realm [%s], normalized [%s]", tostring(playerName),
            tostring(fullName), tostring(fullRealm), tostring(GetRealmName()), tostring(GetNormalizedRealmName()))
    elseif input == "" then
        PrintStatus()
    else
        Print(L.USAGE)
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
        OnAddonMessage(...)
    elseif event == "BAG_UPDATE_DELAYED" then
        selfCounts = nil
        -- Bags can report in before PLAYER_LOGIN, when saved settings are not set up yet.
        if PartyBagDB and PartyBagDB.showSelf then
            InvalidateRows("bags")
        end
        if IsInGroup() then
            ScheduleBroadcast(BROADCAST_DELAY, false)
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        OnGroupChanged()
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...
        -- After /reload or login the peer table is empty even though the group is unchanged;
        -- plain zoning keeps it, so re-requesting then would only add chat traffic.
        if isInitialLogin or isReloadingUi then
            wasInGroup = false
        end
        OnGroupChanged()
    elseif event == "PLAYER_LOGIN" then
        PartyBagDB = PartyBagDB or {}
        for key, value in pairs(ns.DEFAULTS) do
            if PartyBagDB[key] == nil then
                PartyBagDB[key] = value
            end
        end
        playerName = Names.FromParts(UnitFullName("player"))
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        HookTooltips()
        ns.RegisterOptions()
    end
end)

local _, ns = ...
local Protocol = ns.Protocol

local PREFIX = "PartyBag"
-- Looting fires BAG_UPDATE_DELAYED in bursts; waiting lets one snapshot cover the whole burst.
local BROADCAST_DELAY = 2
-- Spacing chunks keeps us well under the client's addon-message throttle.
local SEND_INTERVAL = 0.2

local L = ns.L

local playerName
local peers = {}   -- [name] = { [itemID] = count }
local pending = {} -- [name] = { seq, total, received, counts }
local roster = {}  -- [name] = classFile
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
    local counts = {}
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, GetNumSlots(bag) or 0 do
            local itemID, count = GetSlotItem(bag, slot)
            if itemID then
                counts[itemID] = (counts[itemID] or 0) + (count or 1)
            end
        end
    end
    return counts
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
    local tokens = Protocol.Serialize(ScanBags())
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
    local unknown = false
    local prefix, count = "party", GetNumSubgroupMembers()
    if IsInRaid() then
        prefix, count = "raid", GetNumGroupMembers()
    end
    for i = 1, count do
        local unit = prefix .. i
        local name = GetUnitName(unit, true)
        if not name or name == UNKNOWNOBJECT then
            unknown = true
        else
            local _, classFile = UnitClass(unit)
            roster[NormalizeName(name)] = classFile or true
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
        peers[sender] = state.counts
        pending[sender] = nil
    end
end

local function OnAddonMessage(prefix, text, _, sender)
    if prefix ~= PREFIX then
        return
    end
    local name = NormalizeName(sender)
    if not name or name == playerName then
        return
    end
    local message = Protocol.Parse(text)
    if not message then
        return
    end
    if message.kind == "R" then
        -- Jitter spreads replies so a whole raid does not answer in the same frame.
        ScheduleBroadcast(1 + math.random() * 1.5, true)
    elseif message.kind == "S" then
        OnSnapshotChunk(name, message)
    end
end

local function AddTooltipLines(tooltip, itemID)
    if not itemID or not next(peers) then
        return
    end
    local rows = {}
    for name, counts in pairs(peers) do
        local count = counts[itemID]
        if count then
            rows[#rows + 1] = { name = name, count = count }
        end
    end
    if #rows == 0 then
        return
    end
    table.sort(rows, function(a, b)
        if a.count ~= b.count then
            return a.count > b.count
        end
        return a.name < b.name
    end)
    tooltip:AddLine(" ")
    tooltip:AddLine(L.TOOLTIP_HEADER, 0.2, 1, 0.6)
    for _, row in ipairs(rows) do
        local color = RAID_CLASS_COLORS[roster[row.name]]
        local r, g, b = 1, 1, 1
        if color then
            r, g, b = color.r, color.g, color.b
        end
        tooltip:AddDoubleLine(row.name, row.count, r, g, b, 1, 1, 1)
    end
    tooltip:Show()
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
        return
    end
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
        Print(name .. ": " .. kinds)
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
        playerName = UnitName("player")
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        HookTooltips()
    end
end)

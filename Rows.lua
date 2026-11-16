-- Pure tooltip row selection, kept free of WoW API calls so it can be unit-tested outside the client.
local _, ns = ...

local Rows = {}
ns.Rows = Rows

-- A fixed order lets the eye find a player in the same place on every item, so counts do not move rows.
local function ByName(a, b)
    if a.isSelf ~= b.isSelf then
        return a.isSelf
    end
    local left, right = a.name:lower(), b.name:lower()
    if left ~= right then
        return left < right
    end
    return a.name < b.name
end

-- options.full keeps players without the item as 0: in FULL mode "nobody has it" is itself the answer.
function Rows.Build(peers, itemID, options)
    local rows = {}
    local function Add(name, counts, isSelf)
        local count = counts[itemID]
        if count or options.full then
            rows[#rows + 1] = { name = name, count = count or 0, isSelf = isSelf or false }
        end
    end
    for name, counts in pairs(peers) do
        Add(name, counts)
    end
    if options.selfName and options.selfCounts then
        Add(options.selfName, options.selfCounts, true)
    end
    table.sort(rows, ByName)
    return rows
end

local function Channel(value)
    return math.floor(value * 255 + 0.5)
end

-- The client's tooltip refresh resets line colors set through AddDoubleLine, but not colors inside the text.
function Rows.Colorize(text, r, g, b)
    return ("|cff%02x%02x%02x%s|r"):format(Channel(r), Channel(g), Channel(b), text)
end

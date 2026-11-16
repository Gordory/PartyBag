-- Pure tooltip row selection, kept free of WoW API calls so it can be unit-tested outside the client.
local _, ns = ...

local Rows = {}
ns.Rows = Rows

local function ByCountThenName(a, b)
    if a.count ~= b.count then
        return a.count > b.count
    end
    return a.name < b.name
end

-- options.full keeps players without the item as 0: in FULL mode "nobody has it" is itself the answer.
function Rows.Build(peers, itemID, options)
    local rows = {}
    local function Add(name, counts)
        local count = counts[itemID]
        if count or options.full then
            rows[#rows + 1] = { name = name, count = count or 0 }
        end
    end
    for name, counts in pairs(peers) do
        Add(name, counts)
    end
    if options.selfName and options.selfCounts then
        Add(options.selfName, options.selfCounts)
    end
    table.sort(rows, ByCountThenName)
    return rows
end

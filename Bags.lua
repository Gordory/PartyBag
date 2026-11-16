-- Pure bag scanning, with the client calls passed in so it can be unit-tested outside the client.
local _, ns = ...

local Bags = {}
ns.Bags = Bags

-- The reagent bag sits in the last equipped slot past NUM_BAG_SLOTS; only the total covers it.
function Bags.LastIndex(numBagSlots, numTotalEquipped)
    return numTotalEquipped or numBagSlots
end

-- Empty bag slots report 0 slots, so gaps such as bags 0-2 plus the reagent bag are simply skipped.
function Bags.Scan(lastIndex, getNumSlots, getSlotItem)
    local counts = {}
    for bag = 0, lastIndex do
        for slot = 1, getNumSlots(bag) or 0 do
            local itemID, count = getSlotItem(bag, slot)
            if itemID then
                counts[itemID] = (counts[itemID] or 0) + (count or 1)
            end
        end
    end
    return counts
end

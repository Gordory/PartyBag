-- Run from the repo root: lua tests/bags_test.lua
local ns = {}
assert(loadfile("Bags.lua"))("PartyBag", ns)
local Bags = ns.Bags

-- Clients with a reagent bag report it in the total; older ones only have NUM_BAG_SLOTS.
assert(Bags.LastIndex(4, 5) == 5)
assert(Bags.LastIndex(4, nil) == 4)

-- Bags 0-2 equipped, slots 3-4 empty, reagent bag in slot 5: the gap must not stop the scan.
local slots = { [0] = 2, [1] = 1, [2] = 1, [3] = 0, [4] = 0, [5] = 2 }
local items = {
    [0] = { { 100, 5 }, { 200, 1 } },
    [1] = { { 100, 3 } },
    [2] = { {} },
    [5] = { { 300, 20 }, { 300, 7 } },
}
local counts = Bags.Scan(5, function(bag)
    return slots[bag]
end, function(bag, slot)
    local item = items[bag] and items[bag][slot]
    return item and item[1], item and item[2]
end)
assert(counts[100] == 8, "backpack + bag 1")
assert(counts[200] == 1)
assert(counts[300] == 27, "reagent bag in slot 5")

print("bags_test: ok")

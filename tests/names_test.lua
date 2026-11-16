-- Run from the repo root: lua tests/names_test.lua
local ns = {}
assert(loadfile("Names.lua"))("PartyBag", ns)
local Names = ns.Names

-- WoW Forever names are two words; UnitFullName splits them into name and "realm", while addon messages carry both.
assert(Names.FromParts("Гордори", "Фалстад") == "Гордори Фалстад")
assert(Names.FromParts("Suu", "Zorya") == "Suu Zorya")
-- A single-word name comes back with no second part at all, or with an empty one.
assert(Names.FromParts("Гордори", nil) == "Гордори")
assert(Names.FromParts("Гордори", "") == "Гордори")
assert(Names.FromParts(nil, "Фалстад") == nil)

print("names_test: ok")

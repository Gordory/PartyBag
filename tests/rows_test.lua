-- Run from the repo root: lua tests/rows_test.lua
local ns = {}
assert(loadfile("Rows.lua"))("PartyBag", ns)
local Rows = ns.Rows

local function Check(rows, expected)
    assert(#rows == #expected, ("expected %d rows, got %d"):format(#expected, #rows))
    for i, want in ipairs(expected) do
        local got = rows[i]
        assert(got.name == want[1] and got.count == want[2],
            ("row %d: expected %s=%d, got %s=%d"):format(i, want[1], want[2], got.name, got.count))
    end
end

local peers = { A = { [1] = 2 }, B = { [2] = 5 } }

-- SHORT hides players without the item.
Check(Rows.Build(peers, 1, { full = false }), { { "A", 2 } })
-- FULL keeps everyone who sent data, with 0.
Check(Rows.Build(peers, 1, { full = true }), { { "A", 2 }, { "B", 0 } })
-- Own row joins the sort like any other player.
Check(Rows.Build(peers, 1, { full = false, selfName = "Me", selfCounts = { [1] = 7 } }), { { "Me", 7 }, { "A", 2 } })
-- Own row is skipped unless both name and counts are given.
Check(Rows.Build(peers, 1, { full = false, selfCounts = { [1] = 7 } }), { { "A", 2 } })
-- FULL shows own 0 too, still on top.
Check(Rows.Build(peers, 1, { full = true, selfName = "Me", selfCounts = {} }), { { "Me", 0 }, { "A", 2 }, { "B", 0 } })
-- SHORT with own items only and self hidden: nothing to show.
Check(Rows.Build({}, 1, { full = false }), {})
-- FULL where nobody has the item still lists everyone.
Check(Rows.Build(peers, 3, { full = true }), { { "A", 0 }, { "B", 0 } })
-- Others keep one order for every item: by name, regardless of counts.
Check(Rows.Build({ B = { [1] = 9 }, A = { [1] = 1 } }, 1, { full = false }), { { "A", 1 }, { "B", 9 } })
-- Letter case does not split the order.
Check(Rows.Build({ b = { [1] = 1 }, A = { [1] = 1 }, C = { [1] = 1 } }, 1, { full = false }), { { "A", 1 }, { "b", 1 }, { "C", 1 } })
-- Own row stays first even with the smallest count and a later name.
Check(Rows.Build({ A = { [1] = 9 } }, 1, { full = false, selfName = "Z", selfCounts = { [1] = 1 } }), { { "Z", 1 }, { "A", 9 } })

-- Inline color codes survive the client's tooltip refresh, which drops AddDoubleLine colors.
assert(Rows.Colorize("Гордори Фалстад", 0, 0.44, 0.87) == "|cff0070deГордори Фалстад|r")
assert(Rows.Colorize("Suu Zorya", 1, 1, 1) == "|cffffffffSuu Zorya|r")

print("rows_test: ok")

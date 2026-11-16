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
-- FULL shows own 0 too.
Check(Rows.Build(peers, 1, { full = true, selfName = "Me", selfCounts = {} }), { { "A", 2 }, { "B", 0 }, { "Me", 0 } })
-- SHORT with own items only and self hidden: nothing to show.
Check(Rows.Build({}, 1, { full = false }), {})
-- FULL where nobody has the item still lists everyone.
Check(Rows.Build(peers, 3, { full = true }), { { "A", 0 }, { "B", 0 } })
-- Ties sort by name.
Check(Rows.Build({ B = { [1] = 3 }, A = { [1] = 3 } }, 1, { full = false }), { { "A", 3 }, { "B", 3 } })

print("rows_test: ok")

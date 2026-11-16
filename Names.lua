-- Pure name handling, kept free of WoW API calls so it can be unit-tested outside the client.
local _, ns = ...

local Names = {}
ns.Names = Names

-- WoW Forever character names are two words, which UnitFullName returns as name and realm,
-- while addon messages carry the whole "Name Surname". Joining the parts gives the same key for both.
function Names.FromParts(name, realm)
    if not name then
        return nil
    end
    if realm and realm ~= "" then
        return name .. " " .. realm
    end
    return name
end

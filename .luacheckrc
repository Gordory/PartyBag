-- WoW runs Lua 5.1; the globals below are the client API this addon relies on.
std = "lua51"
max_line_length = false
-- ._* are macOS AppleDouble files created on non-APFS volumes.
exclude_files = { ".worktrees/**", "**/._*", "Libs/**" }

globals = {
    "PartyBagDB",
    "SLASH_PARTYBAG1",
    "SLASH_PARTYBAG2",
    "SlashCmdList",
}

read_globals = {
    "Ambiguate",
    "C_ChatInfo",
    "C_Container",
    "C_Item",
    "C_Timer",
    "CreateFrame",
    "DEFAULT_CHAT_FRAME",
    "Enum",
    "GameTooltip",
    "GameTooltip_Hide",
    "GetContainerItemInfo",
    "GetContainerNumSlots",
    "GetItemInfoInstant",
    "GetLocale",
    "GetNumGroupMembers",
    "GetNumSubgroupMembers",
    "GetNormalizedRealmName",
    "GetRealmName",
    "InterfaceOptions_AddCategory",
    "IsInGroup",
    "IsInRaid",
    "LibStub",
    "ItemRefTooltip",
    "LE_PARTY_CATEGORY_HOME",
    "LE_PARTY_CATEGORY_INSTANCE",
    "NUM_BAG_SLOTS",
    "RAID_CLASS_COLORS",
    "Settings",
    "TooltipDataProcessor",
    "UNKNOWNOBJECT",
    "UnitClass",
    "UnitFullName",
    "strtrim",
    "wipe",
}

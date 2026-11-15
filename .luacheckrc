-- WoW runs Lua 5.1; the globals below are the client API this addon relies on.
std = "lua51"
max_line_length = false
-- ._* are macOS AppleDouble files created on non-APFS volumes.
exclude_files = { ".worktrees/**", "**/._*", "Libs/**" }

globals = {
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
    "GetContainerItemInfo",
    "GetContainerNumSlots",
    "GetItemInfoInstant",
    "GetLocale",
    "GetNumGroupMembers",
    "GetNumSubgroupMembers",
    "GetUnitName",
    "IsInGroup",
    "IsInRaid",
    "LibStub",
    "ItemRefTooltip",
    "LE_PARTY_CATEGORY_HOME",
    "LE_PARTY_CATEGORY_INSTANCE",
    "NUM_BAG_SLOTS",
    "RAID_CLASS_COLORS",
    "TooltipDataProcessor",
    "UNKNOWNOBJECT",
    "UnitClass",
    "UnitName",
    "strtrim",
    "wipe",
}

-- Base strings: every key lives here, so a locale file only overrides what it translates
-- and anything it misses falls back to English instead of nil.
local _, ns = ...

ns.L = {
    TOOLTIP_HEADER = "Party bags:",
    SYNC_REQUESTED = "requested snapshots from the group.",
    NOT_IN_GROUP = "you are not in a group.",
    NO_DATA = "no data from party members yet.",
    USAGE = "/partybag — status, /partybag sync — re-request data",
}

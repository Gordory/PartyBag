local L = LibStub("AceLocale-3.0"):NewLocale("PartyBag", "enUS", true)
if not L then return end

L.TOOLTIP_HEADER = "Party bags:"
L.SYNC_REQUESTED = "requested snapshots from the group."
L.NOT_IN_GROUP = "you are not in a group."
L.NO_DATA = "no data from party members yet."
L.USAGE = "/partybag — status, /partybag sync — re-request data, /partybag debug — toggle debug output"
L.DEBUG_ON = "debug mode on."
L.DEBUG_OFF = "debug mode off."

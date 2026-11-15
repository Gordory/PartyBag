local _, ns = ...
-- The TOC already loads this file only on ruRU clients; the guard covers clients
-- that ignore [AllowLoadTextLocale] and would otherwise apply it everywhere.
if GetLocale() ~= "ruRU" then return end
local L = ns.L

L.TOOLTIP_HEADER = "В сумках группы:"
L.SYNC_REQUESTED = "запросил данные у группы."
L.NOT_IN_GROUP = "вы не в группе."
L.NO_DATA = "пока нет данных от членов группы."
L.USAGE = "/partybag — статус, /partybag sync — перезапросить данные"

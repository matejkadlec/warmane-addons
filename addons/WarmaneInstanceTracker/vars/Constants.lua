local addonName, addon = ...

addon.vars = addon.vars or {}

-- Shared constants used across tracker modules
addon.vars.KILL_XP_MATCH_WINDOW = 3
addon.vars.COMPLETION_XP_SETTLE_DELAY = 1
addon.vars.ACTIVE_RUN_RESTORE_WINDOW = 1800
addon.vars.TABLE_ROWS_DISPLAYED = 12
addon.vars.TABLE_ROW_HEIGHT = 20
addon.vars.TABLE_COLUMN_SPACING = 6
addon.vars.TABLE_COLUMNS = {
    { key = "character", label = "Character", width = 90, justify = "LEFT", sortType = "text" },
    { key = "instanceName", label = "Instance", width = 230, justify = "LEFT", sortType = "text" },
    { key = "totalRuns", label = "Total Runs", width = 60, justify = "RIGHT", sortType = "number" },
    { key = "averageXP", label = "Average XP", width = 85, justify = "RIGHT", sortType = "number", dashLast = true },
    { key = "averageTime", label = "Average Time", width = 85, justify = "RIGHT", sortType = "number" },
    { key = "fastestTime", label = "Fastest Time", width = 85, justify = "RIGHT", sortType = "number" },
    { key = "averageXPPerMinute", label = "XP Per Minute", width = 85, justify = "RIGHT", sortType = "number", dashLast = true }

}
addon.vars.FRAME_NAMES = {
    stats = "WITStatsFrame",
    config = "WITConfigFrame",
    export = "WITExportFrame"
}

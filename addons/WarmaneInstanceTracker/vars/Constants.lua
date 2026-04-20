local addonName, addon = ...

addon.vars = addon.vars or {}

-- Shared constants used across tracker modules
addon.vars.KILL_XP_MATCH_WINDOW = 3
addon.vars.COMPLETION_XP_SETTLE_DELAY = 1
addon.vars.ACTIVE_RUN_RESTORE_WINDOW = 1800
addon.vars.TABLE_ROWS_DISPLAYED = 12
addon.vars.TABLE_ROW_HEIGHT = 20
addon.vars.TABLE_COLUMN_SPACING = 8
addon.vars.TABLE_COLUMNS = {
    { key = "character", label = "Character", width = 100, justify = "LEFT" },
    { key = "instanceName", label = "Instance", width = 230, justify = "LEFT" },
    { key = "totalRuns", label = "Total Runs", width = 80, justify = "RIGHT" },
    { key = "averageXP", label = "Average XP", width = 100, justify = "RIGHT" },
    { key = "averageTime", label = "Average Time", width = 95, justify = "RIGHT" },
    { key = "fastestTime", label = "Fastest Time", width = 120, justify = "RIGHT" }
}
addon.vars.FRAME_NAMES = {
    stats = "WITStatsFrame",
    config = "WITConfigFrame"
}

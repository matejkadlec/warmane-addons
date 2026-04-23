local addonName, addon = ...

local type = type
local pairs = pairs
local table_insert = table.insert

local frameNames = (addon.vars and addon.vars.FRAME_NAMES) or {
    stats = "WITStatsFrame",
    config = "WITConfigFrame",
    export = "WITExportFrame"
}

local function RemoveFromSpecialFrames(frameName)
    if type(UISpecialFrames) ~= "table" then
        return
    end

    for index, name in pairs(UISpecialFrames) do
        if name == frameName then
            UISpecialFrames[index] = nil
        end
    end
end

local function AddToSpecialFrames(frameName)
    if type(UISpecialFrames) ~= "table" then
        return
    end

    for _, name in pairs(UISpecialFrames) do
        if name == frameName then
            return
        end
    end

    table_insert(UISpecialFrames, frameName)
end

-- Keep Esc behavior classic: child dialogs close before the main table
addon.uiSpecialFrames = {
    UpdateEscOrder = function(statsShown, configShown, exportShown)
        RemoveFromSpecialFrames(frameNames.stats)
        RemoveFromSpecialFrames(frameNames.config)
        RemoveFromSpecialFrames(frameNames.export)

        if exportShown then
            AddToSpecialFrames(frameNames.export)
            return
        end

        if configShown then
            AddToSpecialFrames(frameNames.config)
            return
        end

        if statsShown then
            AddToSpecialFrames(frameNames.stats)
        end
    end
}

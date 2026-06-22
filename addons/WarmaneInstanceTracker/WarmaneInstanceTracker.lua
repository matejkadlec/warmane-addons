local addonName, addon = ...

-- Cache frequently used functions
local print = print
local pcall = pcall
local type = type

-- Import local modules from addon namespace
local common = addon.common
local utils = addon.utils
local ui = addon.ui or {}
local uiSpecialFrames = addon.uiSpecialFrames
local runTracker = addon.runTracker
local slashCommands = addon.slashCommands

-- Keep references to modular UI controllers
local statsTableUI = nil
local configFrameUI = nil
local exportDialogUI = nil
local interfaceOptionsUI = nil

local ADDON_FULL_NAME = "WarmaneInstanceTracker"

-- Forward declare helpers used across UI callbacks
local ToggleConfigFrame
local ToggleStatsTable
local OpenStatsTable
local ExportStatsTable
local OpenInterfaceOptions
local RefreshConfigCheckboxes
local RefreshStatsTableIfOpen
local UpdateSpecialFrameEscOrder
local SetInstanceTrackingWithMessage
local SetPartyMessageWithMessage
local SetDebugPrintingWithMessage
local SetDebugLoggingWithMessage

-- Keep Esc behavior classic by delegating ordering to the dedicated UI module
UpdateSpecialFrameEscOrder = function()
    if not uiSpecialFrames or type(uiSpecialFrames.UpdateEscOrder) ~= "function" then
        return
    end

    local statsShown = statsTableUI and statsTableUI.IsShown and statsTableUI.IsShown() or false
    local configShown = configFrameUI and configFrameUI.IsShown and configFrameUI.IsShown() or false
    local exportShown = exportDialogUI and exportDialogUI.IsShown and exportDialogUI.IsShown() or false
    uiSpecialFrames.UpdateEscOrder(statsShown, configShown, exportShown)
end

-- Toggle instance tracking and print the same messages used by /wit on and /wit off
SetInstanceTrackingWithMessage = function(enabled)
    local currentlyEnabled = type(runTracker.IsInstanceTrackingEnabled) == "function" and runTracker.IsInstanceTrackingEnabled()
    if currentlyEnabled == enabled then
        print(common.Message("WIT", ADDON_FULL_NAME .. " is already " .. (enabled and "enabled" or "disabled") .. "."))
        return
    end

    runTracker.SetInstanceTrackingEnabled(enabled)
    print(common.Message("WIT", ADDON_FULL_NAME .. " " .. (enabled and "enabled" or "disabled") .. "."))
end

-- Toggle party completion messages with user-facing chat feedback
SetPartyMessageWithMessage = function(enabled)
    if type(runTracker.IsPartyMessageEnabled) == "function" and runTracker.IsPartyMessageEnabled() == enabled then
        return
    end

    runTracker.SetPartyMessageEnabled(enabled)
    print(common.Message("WIT", "Party message", enabled and "enabled." or "disabled."))
end

-- Toggle boss/combat debug printing with user-facing chat feedback
SetDebugPrintingWithMessage = function(enabled)
    if type(runTracker.IsDebugPrintingEnabled) == "function" and runTracker.IsDebugPrintingEnabled() == enabled then
        return
    end

    runTracker.SetDebugPrintingEnabled(enabled)
    print(common.Message("WIT", "Debug printing", enabled and "enabled." or "disabled."))
end

-- Toggle persisted debug logging with user-facing chat feedback
SetDebugLoggingWithMessage = function(enabled)
    if type(runTracker.IsDebugLoggingEnabled) == "function" and runTracker.IsDebugLoggingEnabled() == enabled then
        return
    end

    runTracker.SetDebugLoggingEnabled(enabled)
    print(common.Message("WIT", "Debug logging", enabled and "enabled." or "disabled."))
end

-- Build UI controllers once and inject callbacks back into tracker logic
local function EnsureUIControllers()
    if not configFrameUI and type(ui.CreateConfigFrame) == "function" then
        configFrameUI = ui.CreateConfigFrame({
            getState = function()
                return runTracker.GetSettingsState()
            end,
            onSetInstanceTracking = SetInstanceTrackingWithMessage,
            onSetPartyMessage = SetPartyMessageWithMessage,
            onSetDebugPrinting = SetDebugPrintingWithMessage,
            onSetDebugLogging = SetDebugLoggingWithMessage,
            onVisibilityChanged = UpdateSpecialFrameEscOrder
        })
    end

    if not exportDialogUI and type(ui.CreateExportDialog) == "function" then
        exportDialogUI = ui.CreateExportDialog({
            onVisibilityChanged = UpdateSpecialFrameEscOrder
        })
    end

    if not statsTableUI and type(ui.CreateStatsTable) == "function" then
        statsTableUI = ui.CreateStatsTable({
            toggleConfig = function()
                if OpenInterfaceOptions then
                    OpenInterfaceOptions()
                end
            end,
            onExport = function(csvText)
                EnsureUIControllers()
                if exportDialogUI and exportDialogUI.Show then
                    exportDialogUI.Show(csvText)
                end
            end,
            onVisibilityChanged = UpdateSpecialFrameEscOrder
        })
    end

    if not interfaceOptionsUI and type(ui.CreateInterfaceOptions) == "function" then
        interfaceOptionsUI = ui.CreateInterfaceOptions({
            getState = function()
                return runTracker.GetSettingsState()
            end,
            getRunControlState = function()
                return runTracker.GetRunControlState()
            end,
            openStatsTable = OpenStatsTable,
            exportStatsTable = ExportStatsTable,
            printStatus = function()
                runTracker.PrintStatus()
            end,
            startRun = function()
                runTracker.StartManual()
            end,
            endRun = function()
                runTracker.EndManual(false)
            end,
            pauseRun = function()
                runTracker.PauseManual()
            end,
            continueRun = function()
                runTracker.ContinueManual()
            end,
            resetRun = function()
                runTracker.ResetManual()
            end,
            onSetInstanceTracking = SetInstanceTrackingWithMessage,
            onSetPartyMessage = SetPartyMessageWithMessage,
            onSetDebugPrinting = SetDebugPrintingWithMessage,
            onSetDebugLogging = SetDebugLoggingWithMessage,
            onSetStatsCharacterFilterMode = function(mode)
                runTracker.SetStatsCharacterFilterMode(mode)
            end,
            onSetStatsLevelRange = function(levelRange)
                runTracker.SetStatsLevelRange(levelRange)
            end,
            onSetStatsTableScale = function(scalePercent)
                runTracker.SetStatsTableScale(scalePercent)
            end
        })
    end
end

-- Sync config checkboxes with current persisted settings
RefreshConfigCheckboxes = function()
    if configFrameUI and configFrameUI.RefreshCheckboxes then
        configFrameUI.RefreshCheckboxes()
    end

    if interfaceOptionsUI and interfaceOptionsUI.RefreshCheckboxes then
        interfaceOptionsUI.RefreshCheckboxes()
    end
end

-- Refresh stats table when visible so completion/debug writes reflect immediately
RefreshStatsTableIfOpen = function()
    if not statsTableUI or not statsTableUI.IsShown or not statsTableUI.Refresh then
        return
    end
    if statsTableUI.IsShown() then
        statsTableUI.Refresh()
    end
end

-- Toggle settings window visibility
ToggleConfigFrame = function()
    EnsureUIControllers()
    if configFrameUI and configFrameUI.Toggle then
        configFrameUI.Toggle()
    end
end

-- Open the run statistics table
OpenStatsTable = function()
    EnsureUIControllers()
    if statsTableUI and statsTableUI.Show then
        statsTableUI.Show()
    end
end

-- Toggle table window visibility for slash command usage
ToggleStatsTable = function()
    EnsureUIControllers()
    if statsTableUI and statsTableUI.Toggle then
        statsTableUI.Toggle()
    end
end

-- Export run statistics using the same path as the table Export button
ExportStatsTable = function()
    EnsureUIControllers()
    if statsTableUI and statsTableUI.Export then
        statsTableUI.Export()
    end
end

-- Open WIT inside the Blizzard Interface Options AddOns tab
OpenInterfaceOptions = function()
    EnsureUIControllers()
    if interfaceOptionsUI and interfaceOptionsUI.Open then
        interfaceOptionsUI.Open()
    end
end

-- Main frame for event handling
local WIT = CreateFrame("Frame")

runTracker.SetCallbacks({
    refreshStatsTable = RefreshStatsTableIfOpen,
    refreshConfigCheckboxes = RefreshConfigCheckboxes,
    setAutoStartUpdateEnabled = function(enabled)
        if enabled then
            WIT:SetScript("OnUpdate", function(self, elapsed)
                runTracker.HandleUpdate()
            end)
        else
            WIT:SetScript("OnUpdate", nil)
        end
    end
})

slashCommands.Register({
    toggleConfig = OpenInterfaceOptions,
    toggleStatsTable = ToggleStatsTable,
    enableAddon = function()
        SetInstanceTrackingWithMessage(true)
    end,
    disableAddon = function()
        SetInstanceTrackingWithMessage(false)
    end
})

-- Register events needed for tracking
WIT:RegisterEvent("ADDON_LOADED")
WIT:RegisterEvent("ZONE_CHANGED_NEW_AREA")
WIT:RegisterEvent("PLAYER_ENTERING_WORLD")
WIT:RegisterEvent("PLAYER_LOGOUT")
WIT:RegisterEvent("PLAYER_XP_UPDATE")
WIT:RegisterEvent("PLAYER_LEVEL_UP")
WIT:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
WIT:RegisterEvent("PLAYER_DEAD")
WIT:RegisterEvent("PLAYER_ALIVE")
WIT:RegisterEvent("PLAYER_UNGHOST")
WIT:RegisterEvent("PARTY_MEMBERS_CHANGED")
WIT:RegisterEvent("UNIT_AURA")
WIT:RegisterEvent("CHAT_MSG_SYSTEM")
WIT:RegisterEvent("LFG_PROPOSAL_SHOW")
WIT:RegisterEvent("LFG_PROPOSAL_UPDATE")

-- Main event handler
WIT:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        local success = pcall(utils.InitializeSavedData)
        if not success then
            print(common.ErrorMessage("WIT", "initialize saved data"))
            return
        end

        runTracker.LoadSettingsFromSavedData()
        EnsureUIControllers()
        print(common.Message("WIT", "WarmaneInstanceTracker loaded"))
        return
    end

    runTracker.HandleEvent(event, ...)
end)

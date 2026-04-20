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

-- Forward declare helpers used across UI callbacks
local ToggleConfigFrame
local ToggleStatsTable
local RefreshConfigCheckboxes
local RefreshStatsTableIfOpen
local UpdateSpecialFrameEscOrder

-- Keep Esc behavior classic by delegating ordering to the dedicated UI module
UpdateSpecialFrameEscOrder = function()
    if not uiSpecialFrames or type(uiSpecialFrames.UpdateEscOrder) ~= "function" then
        return
    end

    local statsShown = statsTableUI and statsTableUI.IsShown and statsTableUI.IsShown() or false
    local configShown = configFrameUI and configFrameUI.IsShown and configFrameUI.IsShown() or false
    uiSpecialFrames.UpdateEscOrder(statsShown, configShown)
end

-- Build UI controllers once and inject callbacks back into tracker logic
local function EnsureUIControllers()
    if not configFrameUI and type(ui.CreateConfigFrame) == "function" then
        configFrameUI = ui.CreateConfigFrame({
            getState = function()
                return runTracker.GetSettingsState()
            end,
            onSetInstanceTracking = function(enabled)
                runTracker.SetInstanceTrackingEnabled(enabled)
            end,
            onSetPartyMessage = function(enabled)
                runTracker.SetPartyMessageEnabled(enabled)
            end,
            onSetDebugPrinting = function(enabled)
                runTracker.SetDebugPrintingEnabled(enabled)
            end,
            onSetDebugLogging = function(enabled)
                runTracker.SetDebugLoggingEnabled(enabled)
            end,
            onVisibilityChanged = UpdateSpecialFrameEscOrder
        })
    end

    if not statsTableUI and type(ui.CreateStatsTable) == "function" then
        statsTableUI = ui.CreateStatsTable({
            toggleConfig = function()
                if ToggleConfigFrame then
                    ToggleConfigFrame()
                end
            end,
            onVisibilityChanged = UpdateSpecialFrameEscOrder
        })
    end
end

-- Sync config checkboxes with current persisted settings
RefreshConfigCheckboxes = function()
    if not configFrameUI or not configFrameUI.RefreshCheckboxes then
        return
    end
    configFrameUI.RefreshCheckboxes()
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

-- Toggle table window visibility for slash command usage
ToggleStatsTable = function()
    EnsureUIControllers()
    if statsTableUI and statsTableUI.Toggle then
        statsTableUI.Toggle()
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
    toggleConfig = ToggleConfigFrame,
    toggleStatsTable = ToggleStatsTable
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
        print(common.Message("WIT", "WarmaneInstanceTracker loaded"))
        return
    end

    runTracker.HandleEvent(event, ...)
end)

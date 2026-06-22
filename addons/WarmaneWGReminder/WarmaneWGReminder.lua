local addonName, addon = ...

-- Cache frequently used functions
local getglobal = getglobal
local ipairs = ipairs
local print = print
local tostring = tostring
local type = type
local pcall = pcall
local math_floor = math.floor
local string_format = string.format
local string_lower = string.lower
local UnitLevel = UnitLevel
local strsplit = strsplit
local strtrim = strtrim

-- Define color codes
local COLOR = {
    ORANGE = "|cFFFF8000",
    YELLOW = "|cFFFFFF00",
    RED = "|cFFFF0000"
}

-- Format general messages with prefix and optional value
local function FormatMessage(prefix, msg, value)
    if type(prefix) ~= "string" or type(msg) ~= "string" then return "" end
    local formattedPrefix = string_format("%s[%s]", COLOR.ORANGE, prefix)
    if value then
        return string_format("%s %s%s %s%s|r",
            formattedPrefix, COLOR.YELLOW, msg, COLOR.ORANGE, value)
    end
    return string_format("%s %s%s|r", formattedPrefix, COLOR.YELLOW, msg)
end

-- Format error messages with colored prefix and red body
local function FormatErrorMessage(prefix, msg)
    if type(prefix) ~= "string" or type(msg) ~= "string" then return "" end
    return string_format("%s[%s] %sFailed to %s|r",
        COLOR.ORANGE, prefix, COLOR.RED, msg)
end

-- Reminder thresholds in minutes before battle
local REMINDER_MINUTES = {30, 15, 5}
local INITIAL_NOTICE_UPPER_SECONDS = 15 * 60
local FIVE_MINUTES_SECONDS = 5 * 60
local REQUIRED_LEVEL = 80
local ADDON_PREFIX = "WWR"
local ADDON_FULL_NAME = "WarmaneWGReminder"
local DEFAULT_ADDON_ENABLED = true
local PARENT_CATEGORY_NAME = "Warmane AddOns"
local PARENT_PANEL_NAME = "WarmaneAddOnsInterfaceOptionsPanel"

-- Polling interval in seconds
local CHECK_INTERVAL = 5

-- Create frame for event handling and timer management
local frame = CreateFrame("Frame")

-- State tracking variables
local remindersSent = {}
local lastWaitTime = nil
local battleActive = false
local initialCheckDone = false
local countdownInitialized = false
local reminderActive = false
local interfaceOptionsPanel = nil
local interfaceOptionsCheckbox = nil

local RefreshInterfaceOptions

-- Create the saved settings table and populate validated defaults
local function InitializeSavedData()
    if type(WarmaneWGReminderSettings) ~= "table" then
        WarmaneWGReminderSettings = {}
    end

    if type(WarmaneWGReminderSettings.enabled) ~= "boolean" then
        WarmaneWGReminderSettings.enabled = DEFAULT_ADDON_ENABLED
    end
end

-- Read the current persisted enabled state safely
local function IsAddonEnabled()
    InitializeSavedData()
    return WarmaneWGReminderSettings.enabled
end

-- Persist one validated enabled state
local function SetSavedAddonEnabled(enabled)
    InitializeSavedData()
    WarmaneWGReminderSettings.enabled = enabled and true or false
end

-- Resets all reminder flags for the next battle cycle
local function ResetReminders()
    for _, minutes in ipairs(REMINDER_MINUTES) do
        remindersSent[minutes] = false
    end
end

-- Query the Wintergrasp timer API without throwing Lua errors
local function QueryWintergraspWaitTime()
    if type(GetWintergraspWaitTime) ~= "function" then
        return false, nil
    end

    local success, waitTime = pcall(GetWintergraspWaitTime)
    if not success then
        return false, nil
    end

    return true, waitTime
end

-- Safely get time until next Wintergrasp battle
local function GetTimeUntilBattle()
    local isAvailable, waitTime = QueryWintergraspWaitTime()
    if isAvailable and type(waitTime) == "number" and waitTime > 0 then
        return waitTime
    end
    return nil
end

-- Format seconds into a human-readable time string with appropriate units
local function FormatTime(seconds)
    if type(seconds) ~= "number" or seconds < 0 then return "0 seconds" end
    local totalMinutes = math_floor(seconds / 60)
    local secs = math_floor(seconds % 60)

    if totalMinutes >= 60 then
        -- Show hours and minutes (no seconds)
        local hours = math_floor(totalMinutes / 60)
        local mins = totalMinutes % 60
        local hourStr = hours == 1 and "1 hour" or (hours .. " hours")
        if mins == 0 then
            return hourStr
        end
        local minStr = mins == 1 and "1 minute" or (mins .. " minutes")
        return hourStr .. " " .. minStr
    elseif totalMinutes > 0 then
        -- Show minutes and seconds
        local minStr = totalMinutes == 1 and "1 minute" or (totalMinutes .. " minutes")
        if secs == 0 then
            return minStr
        end
        local secStr = secs == 1 and "1 second" or (secs .. " seconds")
        return minStr .. " " .. secStr
    else
        -- Less than 1 minute, show seconds only
        return secs == 1 and "1 second" or (secs .. " seconds")
    end
end

-- Show one precise login message only inside the final 15 minutes, excluding the 5 minute threshold
local function ShouldShowInitialWaitMessage(waitTime)
    return waitTime < FIVE_MINUTES_SECONDS
        or (waitTime > FIVE_MINUTES_SECONDS and waitTime < INITIAL_NOTICE_UPPER_SECONDS)
end

-- Store the current countdown state without replaying already-passed thresholds
local function InitializeReminderState(waitTime, showInitialWaitMessage)
    ResetReminders()

    if waitTime then
        for _, minutes in ipairs(REMINDER_MINUTES) do
            if waitTime < minutes * 60 then
                remindersSent[minutes] = true
            end
        end

        if showInitialWaitMessage and ShouldShowInitialWaitMessage(waitTime) then
            print(FormatMessage(ADDON_PREFIX, "Battle for Wintergrasp starts in", FormatTime(waitTime)))
        end

        lastWaitTime = waitTime
        battleActive = false
        countdownInitialized = true
    else
        -- A nil timer at login can mean active battle or unavailable API, so keep the state unknown.
        battleActive = false
        lastWaitTime = nil
        countdownInitialized = false
    end
end

-- Initialize reminder flags based on current wait time
local function InitializeReminders(showInitialWaitMessage)
    local waitTime = GetTimeUntilBattle()
    InitializeReminderState(waitTime, showInitialWaitMessage)
end

-- Checks battle state transitions and sends reminders
local function CheckBattleStatus()
    local waitTime = GetTimeUntilBattle()

    if waitTime then
        if not countdownInitialized and not battleActive then
            InitializeReminderState(waitTime, true)
            initialCheckDone = true
            return
        end

        -- We have a countdown, battle is not active
        if battleActive and initialCheckDone then
            -- Transition: battle was active, now ended (only notify if we were online)
            print(FormatMessage(ADDON_PREFIX, "Battle for Wintergrasp has ended"))
        end
        if battleActive then
            ResetReminders()
            battleActive = false
        end

        -- Check reminder thresholds
        for _, minutes in ipairs(REMINDER_MINUTES) do
            local thresholdSeconds = minutes * 60
            if waitTime <= thresholdSeconds
                and (not lastWaitTime or lastWaitTime >= thresholdSeconds)
                and not remindersSent[minutes] then
                print(FormatMessage(ADDON_PREFIX, "Battle for Wintergrasp starts in", minutes .. " minutes"))
                remindersSent[minutes] = true
            end
        end

        lastWaitTime = waitTime
        countdownInitialized = true
    else
        -- nil means battle is active or API unavailable
        if lastWaitTime and not battleActive and initialCheckDone then
            -- Transition: had countdown, now nil → battle started (only notify if we were online)
            print(FormatMessage(ADDON_PREFIX, "Battle for Wintergrasp has started!"))
        end
        if lastWaitTime and not battleActive then
            battleActive = true
        end
        lastWaitTime = nil
        countdownInitialized = false
    end

    initialCheckDone = true
end

-- True only for characters where this addon should be active
local function IsReminderAllowedForLevel()
    return type(UnitLevel) == "function" and UnitLevel("player") == REQUIRED_LEVEL
end

-- Start reminder polling and initialize runtime state
local function ActivateReminder(self, showLoadedMessage)
    if reminderActive then
        return
    end

    if type(GetWintergraspWaitTime) ~= "function" then
        print(FormatMessage(ADDON_PREFIX, "Wintergrasp timer API unavailable"))
        return
    end

    initialCheckDone = false
    InitializeReminders(true)
    self.timer = 0
    self:SetScript("OnUpdate", function(frameRef, elapsed)
        frameRef.timer = (frameRef.timer or 0) + elapsed
        if frameRef.timer >= CHECK_INTERVAL then
            CheckBattleStatus()
            frameRef.timer = 0
        end
    end)

    reminderActive = true
    if showLoadedMessage then
        print(FormatMessage(ADDON_PREFIX, ADDON_FULL_NAME .. " loaded"))
    end
end

-- Stop reminder polling and clear transient state
local function DeactivateReminder(self)
    self:SetScript("OnUpdate", nil)
    self.timer = 0
    reminderActive = false
    ResetReminders()
    lastWaitTime = nil
    battleActive = false
    initialCheckDone = false
    countdownInitialized = false
end

-- Apply activation state based on current character level
local function RefreshReminderActivation(self, showLoadedMessage)
    if not IsAddonEnabled() then
        DeactivateReminder(self)
        return
    end

    if IsReminderAllowedForLevel() then
        ActivateReminder(self, showLoadedMessage)
    else
        DeactivateReminder(self)
    end
end

-- Enable or disable reminders without reloading the UI
local function SetAddonEnabled(enabled)
    local currentlyEnabled = IsAddonEnabled()
    if currentlyEnabled == enabled then
        print(FormatMessage(ADDON_PREFIX, string_format("%s is already %s.", ADDON_FULL_NAME, enabled and "enabled" or "disabled")))
        return
    end

    SetSavedAddonEnabled(enabled)
    if enabled then
        RefreshReminderActivation(frame, false)
        print(FormatMessage(ADDON_PREFIX, ADDON_FULL_NAME .. " enabled."))
    else
        DeactivateReminder(frame)
        print(FormatMessage(ADDON_PREFIX, ADDON_FULL_NAME .. " disabled."))
    end

    if RefreshInterfaceOptions then
        RefreshInterfaceOptions()
    end
end

-- Register required events
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LEVEL_UP")

-- Event handler
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        InitializeSavedData()
        RefreshReminderActivation(self, true)
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LEVEL_UP" then
        RefreshReminderActivation(self, false)
    elseif event == "PLAYER_LEAVING_WORLD" then
        -- Clean up timer before logout/reload
        self:SetScript("OnUpdate", nil)
        self.timer = 0
        reminderActive = false
    end
end)

-- Print help text listing available slash commands
local function PrintHelp()
    print(FormatMessage(ADDON_PREFIX, "Available commands:"))
    print(string_format("  %s/wwr %s- Print when the next Wintergrasp battle starts|r", COLOR.ORANGE, COLOR.YELLOW))
    print(string_format("  %s/wwr on %s- Enable Wintergrasp reminders|r", COLOR.ORANGE, COLOR.YELLOW))
    print(string_format("  %s/wwr off %s- Disable Wintergrasp reminders|r", COLOR.ORANGE, COLOR.YELLOW))
    print(string_format("  %s/wwr when %s- Print when the next Wintergrasp battle starts|r", COLOR.ORANGE, COLOR.YELLOW))
    print(string_format("  %s/wwr help %s- Show this help|r", COLOR.ORANGE, COLOR.YELLOW))
    print(string_format("  %s/wwr -h %s- Short version of /wwr help|r", COLOR.ORANGE, COLOR.YELLOW))
end

-- Handle the /wwr when subcommand
local function HandleWhen()
    local isAvailable, waitTime = QueryWintergraspWaitTime()
    if not isAvailable then
        print(FormatErrorMessage(ADDON_PREFIX, "retrieve Wintergrasp timer data"))
        return
    end

    if waitTime then
        print(FormatMessage(ADDON_PREFIX, "Next battle for Wintergrasp starts in", FormatTime(waitTime)))
    else
        -- Blizzard treats a nil or non-positive timer as battle in progress.
        print(FormatMessage(ADDON_PREFIX, "Battle for Wintergrasp is active right now!"))
    end
end

local function EnsureWarmaneAddOnsCategory(defaultOpenFunc)
    local parentPanel = getglobal(PARENT_PANEL_NAME)
    if not parentPanel then
        parentPanel = CreateFrame("Frame", PARENT_PANEL_NAME)
        parentPanel.name = PARENT_CATEGORY_NAME

        local title = parentPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", parentPanel, "TOPLEFT", 16, -16)
        title:SetText(PARENT_CATEGORY_NAME)

        parentPanel:SetScript("OnShow", function(self)
            if self.warmaneRedirecting or type(self.warmaneOpenDefaultChild) ~= "function" then
                return
            end

            self.warmaneRedirecting = true
            self.warmaneOpenDefaultChild()
            self.warmaneRedirecting = false
        end)

        parentPanel:Hide()
        InterfaceOptions_AddCategory(parentPanel)
    end

    if type(parentPanel.warmaneOpenDefaultChild) ~= "function" then
        parentPanel.warmaneOpenDefaultChild = defaultOpenFunc
    end
end

RefreshInterfaceOptions = function()
    if interfaceOptionsCheckbox then
        interfaceOptionsCheckbox:SetChecked(IsAddonEnabled())
    end
end

local function EnableAddon()
    SetAddonEnabled(true)
end

local function DisableAddon()
    SetAddonEnabled(false)
end

-- Define available subcommands
local SUBCOMMANDS = {
    ["on"] = { handler = EnableAddon, args = 0 },
    ["off"] = { handler = DisableAddon, args = 0 },
    ["when"] = { handler = HandleWhen, args = 0 },
    ["help"] = { handler = PrintHelp, args = 0 },
    ["-h"] = { handler = PrintHelp, args = 0 },
}

-- Register slash command
SLASH_WWR1 = "/wwr"
SlashCmdList["WWR"] = function(msg)
    -- Normalize slash command input before dispatching to subcommands
    local rawMsg = strtrim(msg or "")

    -- No arguments behave like /wwr when
    if rawMsg == "" then
        HandleWhen()
        return
    end

    -- Split input into subcommand and remaining args
    local subcommand, args = strsplit(" ", rawMsg, 2)
    subcommand = subcommand and string_lower(subcommand) or ""
    args = strtrim(args or "")
    local command = SUBCOMMANDS[subcommand]

    if not command then
        print(FormatErrorMessage(ADDON_PREFIX, string_format(
            "find subcommand '%s'. Use /wwr help to see available commands", subcommand)))
        return
    end

    -- Validate argument count
    if command.args == 0 and args ~= "" then
        print(FormatErrorMessage(ADDON_PREFIX, string_format(
            "execute command. Wrong number of arguments for '%s' (expected 0)", subcommand)))
        return
    end

    command.handler(args)
end

local function RegisterInterfaceOptions()
    local function OpenPanel()
        if interfaceOptionsPanel and type(InterfaceOptionsFrame_OpenToCategory) == "function" then
            InterfaceOptionsFrame_OpenToCategory(interfaceOptionsPanel)
        end
    end

    EnsureWarmaneAddOnsCategory(OpenPanel)

    interfaceOptionsPanel = CreateFrame("Frame", "WWRInterfaceOptionsPanel")
    interfaceOptionsPanel.name = "WG Reminder"
    interfaceOptionsPanel.parent = PARENT_CATEGORY_NAME

    local title = interfaceOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", interfaceOptionsPanel, "TOPLEFT", 16, -16)
    title:SetText("Warmane WG Reminder")

    local header = interfaceOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", interfaceOptionsPanel, "TOPLEFT", 18, -52)
    header:SetText("User settings")

    interfaceOptionsCheckbox = CreateFrame("CheckButton", "WWRInterfaceOptionsEnabled", interfaceOptionsPanel, "InterfaceOptionsCheckButtonTemplate")
    interfaceOptionsCheckbox:SetPoint("TOPLEFT", interfaceOptionsPanel, "TOPLEFT", 14, -76)
    getglobal(interfaceOptionsCheckbox:GetName() .. "Text"):SetText("Enable Wintergrasp reminders")
    interfaceOptionsCheckbox:SetScript("OnClick", function(self)
        SetAddonEnabled(self:GetChecked() and true or false)
    end)

    interfaceOptionsPanel:SetScript("OnShow", RefreshInterfaceOptions)
    interfaceOptionsPanel.refresh = RefreshInterfaceOptions
    interfaceOptionsPanel:Hide()
    InterfaceOptions_AddCategory(interfaceOptionsPanel)
end

RegisterInterfaceOptions()

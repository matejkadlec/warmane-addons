local addonName, addon = ...

-- Cache frequently used functions
local type = type
local pcall = pcall
local math_floor = math.floor
local string_format = string.format
local UnitLevel = UnitLevel

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
local REQUIRED_LEVEL = 80

-- Polling interval in seconds
local CHECK_INTERVAL = 5

-- Create frame for event handling and timer management
local frame = CreateFrame("Frame")

-- State tracking variables
local remindersSent = {}
local lastWaitTime = nil
local battleActive = false
local initialCheckDone = false
local reminderActive = false

-- Resets all reminder flags for the next battle cycle
local function ResetReminders()
    for _, minutes in ipairs(REMINDER_MINUTES) do
        remindersSent[minutes] = false
    end
end

-- Safely get time until next Wintergrasp battle
local function GetTimeUntilBattle()
    if not GetWintergraspWaitTime then return nil end
    local success, waitTime = pcall(GetWintergraspWaitTime)
    if success and type(waitTime) == "number" and waitTime > 0 then
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

-- Initialize reminder flags based on current wait time
local function InitializeReminders()
    ResetReminders()
    local waitTime = GetTimeUntilBattle()
    if waitTime then
        local minutesUntil = math_floor(waitTime / 60)
        -- Mark past thresholds as already sent to avoid spam on login
        for _, minutes in ipairs(REMINDER_MINUTES) do
            if minutesUntil <= minutes then
                remindersSent[minutes] = true
            end
        end
        lastWaitTime = waitTime
        battleActive = false
    else
        -- nil could mean battle active or outside Northrend
        battleActive = true
        lastWaitTime = nil
    end
end

-- Checks battle state transitions and sends reminders
local function CheckBattleStatus()
    local waitTime = GetTimeUntilBattle()

    if waitTime then
        -- We have a countdown, battle is not active
        if battleActive and initialCheckDone then
            -- Transition: battle was active, now ended (only notify if we were online)
            print(FormatMessage("WWR", "Battle for Wintergrasp has ended"))
        end
        if battleActive then
            ResetReminders()
            battleActive = false
        end

        -- Check reminder thresholds
        local minutesUntil = math_floor(waitTime / 60)
        for _, minutes in ipairs(REMINDER_MINUTES) do
            if minutesUntil <= minutes and not remindersSent[minutes] then
                print(FormatMessage("WWR", "Battle for Wintergrasp starts in", minutes .. " minutes"))
                remindersSent[minutes] = true
            end
        end

        lastWaitTime = waitTime
    else
        -- nil means battle is active or API unavailable
        if lastWaitTime and not battleActive and initialCheckDone then
            -- Transition: had countdown, now nil → battle started (only notify if we were online)
            print(FormatMessage("WWR", "Battle for Wintergrasp has started!"))
        end
        if lastWaitTime and not battleActive then
            battleActive = true
        end
        lastWaitTime = nil
    end

    initialCheckDone = true
end

-- True only for characters where this addon should be active
local function IsReminderAllowedForLevel()
    return type(UnitLevel) == "function" and UnitLevel("player") == REQUIRED_LEVEL
end

-- Start reminder polling and initialize runtime state
local function ActivateReminder(self)
    if reminderActive then
        return
    end

    if not GetWintergraspWaitTime then
        print(FormatMessage("WWR", "Wintergrasp timer API unavailable"))
        return
    end

    InitializeReminders()
    self.timer = 0
    self:SetScript("OnUpdate", function(frameRef, elapsed)
        frameRef.timer = (frameRef.timer or 0) + elapsed
        if frameRef.timer >= CHECK_INTERVAL then
            CheckBattleStatus()
            frameRef.timer = 0
        end
    end)

    reminderActive = true
    print(FormatMessage("WWR", "WarmaneWGReminder loaded"))
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
end

-- Apply activation state based on current character level
local function RefreshReminderActivation(self)
    if IsReminderAllowedForLevel() then
        ActivateReminder(self)
    else
        DeactivateReminder(self)
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
        RefreshReminderActivation(self)
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LEVEL_UP" then
        RefreshReminderActivation(self)
    elseif event == "PLAYER_LEAVING_WORLD" then
        -- Clean up timer before logout/reload
        self:SetScript("OnUpdate", nil)
        self.timer = 0
        reminderActive = false
    end
end)

-- Print help text listing available slash commands
local function PrintHelp()
    print(FormatMessage("WWR", "Available commands:"))
    print(string_format("  %s/wwr when %s- Prints the time until the next battle for Wintergrasp|r", COLOR.ORANGE, COLOR.YELLOW))
end

-- Handle the /wwr when subcommand
local function HandleWhen()
    if not reminderActive then
        print(FormatMessage("WWR", "Addon is active only at level", tostring(REQUIRED_LEVEL)))
        return
    end

    local waitTime = GetTimeUntilBattle()
    if waitTime then
        print(FormatMessage("WWR", "Next battle for Wintergrasp starts in", FormatTime(waitTime)))
    elseif battleActive then
        print(FormatMessage("WWR", "Battle for Wintergrasp is active right now!"))
    else
        print(FormatErrorMessage("WWR", "retrieve Wintergrasp timer data"))
    end
end

-- Define available subcommands
local SUBCOMMANDS = {
    ["when"] = { handler = HandleWhen, args = 0 },
    ["help"] = { handler = PrintHelp, args = 0 },
}

-- Register slash command
SLASH_WWR1 = "/wwr"
SlashCmdList["WWR"] = function(msg)
    -- Trim and lowercase input
    msg = strtrim(msg):lower()

    -- No arguments shows help
    if msg == "" then
        PrintHelp()
        return
    end

    -- Split input into subcommand and remaining args
    local subcommand, args = strsplit(" ", msg, 2)
    local command = SUBCOMMANDS[subcommand]

    if not command then
        print(FormatErrorMessage("WWR", string_format(
            "find subcommand '%s'. Use /wwr help to see available commands", subcommand)))
        return
    end

    -- Validate argument count
    if command.args == 0 and args and strtrim(args) ~= "" then
        print(FormatErrorMessage("WWR", string_format(
            "execute command. Wrong number of arguments for '%s' (expected 0)", subcommand)))
        return
    end

    command.handler()
end

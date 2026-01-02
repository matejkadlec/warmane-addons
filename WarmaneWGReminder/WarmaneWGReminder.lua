local addonName, addon = ...

-- Cache frequently used functions for better performance
local GetGameTime = GetGameTime
local math_floor = math.floor

-- Import WarmaneCommonUtils from global scope
local WCU = _G.WarmaneCommonUtils
local common_format = WCU.common_format

-- Wintergrasp configuration constants
local BATTLE_HOURS = {0, 3, 6, 9, 12, 15, 18, 21}
local REMINDER_MINUTES = {30, 15, 5}
local BATTLE_DURATION = 30

-- Create frame for event handling and timer management
local frame = CreateFrame("Frame")
local remindersSent = {}

-- Determines if the given hour is a Wintergrasp battle hou
local function IsBattleHour(hour)
    for _, battleHour in ipairs(BATTLE_HOURS) do
        if hour == battleHour then
            return true
        end
    end
    return false
end

-- Calculates the time in seconds until the next Wintergrasp battle
local function CalculateTimeUntilNextBattle()
    local serverHour, serverMinute = GetGameTime()
    local currentSeconds = serverHour * 3600 + serverMinute * 60

    -- Find the next battle today
    local nextBattleSeconds = nil
    for _, hour in ipairs(BATTLE_HOURS) do
        local battleTimeSeconds = hour * 3600
        if battleTimeSeconds > currentSeconds then
            nextBattleSeconds = battleTimeSeconds
            break
        end
    end

    -- If no battles left today, use first battle tomorrow
    if not nextBattleSeconds then
        nextBattleSeconds = BATTLE_HOURS[1] * 3600 + 24 * 3600
    end

    return nextBattleSeconds - currentSeconds
end

-- Checks for and announces battle status and upcoming reminders
local function CheckTimeUntilNextBattle()
    -- Check for active battle first
    local serverHour, serverMinute = GetGameTime()
    
    if IsBattleHour(serverHour) and (serverMinute < BATTLE_DURATION) then       
        -- Announce battle start
        if IsBattleHour(serverHour) and serverMinute == 0 then
            print(common_format.Message("WWR", "Battle for Wintergrasp has begun!"))
        end
    else
        -- Announce battle end
        if IsBattleHour(serverHour) and serverMinute == 30 then
            print(common_format.Message("WWR", "Battle for Wintergrasp has ended."))
            ResetReminders()
        end
        
        -- Process reminders for upcoming battle
        local timeUntilBattle = CalculateTimeUntilNextBattle()
        local minutesUntilBattle = math_floor(timeUntilBattle / 60)
        
        -- Check each configured reminder interval
        for _, minutes in ipairs(REMINDER_MINUTES) do
            -- Trigger reminder when we reach the exact minute threshold
            if minutesUntilBattle == minutes and not remindersSent[minutes] then
                print(common_format.Message("WWR", "Battle for Wintergrasp starts in", minutes .. " minutes"))
                remindersSent[minutes] = true
            elseif minutesUntilBattle > minutes then
                -- Reset reminder flag once we're past the window
                remindersSent[minutes] = false
            end
        end
    end
end

-- Resets all reminder flags for the next battle cycle
local function ResetReminders()
    for _, minutes in ipairs(REMINDER_MINUTES) do
        remindersSent[minutes] = false
    end
end

-- Register required events
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")

-- Event handler
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        -- Initialize addon state
        ResetReminders()
        
        -- Set up timer for periodic checks
        self:SetScript("OnUpdate", function(self, elapsed)
            self.timer = (self.timer or 0) + elapsed
            -- Perform check every second
            if self.timer >= 1 then
                CheckTimeUntilNextBattle()
                self.timer = 0
            end
        end)
        
        -- Show addon loaded message
        print(string.format("|cFFFF8000Warmane|cFFFFFF00WGReminder loaded|r"))
    elseif event == "PLAYER_LEAVING_WORLD" then
        -- Clean up before logout/reload
        self:SetScript("OnUpdate", nil)
    end
end)
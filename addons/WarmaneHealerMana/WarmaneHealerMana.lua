local addonName, addon = ...

-- Cache frequently used functions
local print = print
local pcall = pcall
local tonumber = tonumber
local type = type
local math_floor = math.floor
local string_format = string.format
local string_lower = string.lower
local strtrim = strtrim
local strsplit = strsplit
local CreateFrame = CreateFrame
local GetNumPartyMembers = GetNumPartyMembers
local GetNumRaidMembers = GetNumRaidMembers
local GetTime = GetTime
local IsInInstance = IsInInstance
local SendChatMessage = SendChatMessage
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitName = UnitName
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType

-- Define color codes
local COLOR = {
    ORANGE = "|cFFFF8000",
    YELLOW = "|cFFFFFF00",
    RED = "|cFFFF0000"
}

local ADDON_PREFIX = "WHM"
local ALERT_MESSAGE = "Healer Mana: I'm out of mana!"
local DEFAULT_ALERT_DELAY = 60
local MIN_ALERT_DELAY = 30
local MAX_ALERT_DELAY = 180
local DEFAULT_MANA_THRESHOLD = 10
local MIN_MANA_THRESHOLD = 5
local MAX_MANA_THRESHOLD = 25
local CHECK_INTERVAL = 0.5
local ADDON_FULL_NAME = "WarmaneHealerMana"
local DEFAULT_ADDON_ENABLED = true

local frame = CreateFrame("Frame")
local lastAlertAt = -DEFAULT_ALERT_DELAY

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

-- Create the saved settings table and populate validated defaults
local function InitializeSavedData()
    if type(HealerManaSettings) ~= "table" then
        HealerManaSettings = {}
    end

    if type(HealerManaSettings.enabled) ~= "boolean" then
        HealerManaSettings.enabled = DEFAULT_ADDON_ENABLED
    end

    local savedDelay = HealerManaSettings.alertDelay
    if type(savedDelay) ~= "number" or
        savedDelay < MIN_ALERT_DELAY or
        savedDelay > MAX_ALERT_DELAY or
        savedDelay ~= math_floor(savedDelay) then
        HealerManaSettings.alertDelay = DEFAULT_ALERT_DELAY
    end

    local savedThreshold = HealerManaSettings.manaThreshold
    if type(savedThreshold) ~= "number" or
        savedThreshold < MIN_MANA_THRESHOLD or
        savedThreshold > MAX_MANA_THRESHOLD or
        savedThreshold ~= math_floor(savedThreshold) then
        HealerManaSettings.manaThreshold = DEFAULT_MANA_THRESHOLD
    end
end

-- Read the current persisted enabled state safely
local function IsAddonEnabled()
    InitializeSavedData()
    return HealerManaSettings.enabled
end

-- Persist one validated enabled state
local function SetSavedAddonEnabled(enabled)
    InitializeSavedData()
    HealerManaSettings.enabled = enabled and true or false
end

-- Read the current persisted delay safely
local function GetAlertDelay()
    if type(HealerManaSettings) ~= "table" then
        return DEFAULT_ALERT_DELAY
    end

    local savedDelay = HealerManaSettings.alertDelay
    if type(savedDelay) ~= "number" then
        return DEFAULT_ALERT_DELAY
    end

    return savedDelay
end

-- Persist one validated delay value
local function SetAlertDelay(seconds)
    if type(HealerManaSettings) ~= "table" then
        HealerManaSettings = {}
    end

    HealerManaSettings.alertDelay = seconds
end

-- Read the current persisted mana threshold safely
local function GetManaThreshold()
    if type(HealerManaSettings) ~= "table" then
        return DEFAULT_MANA_THRESHOLD
    end

    local savedThreshold = HealerManaSettings.manaThreshold
    if type(savedThreshold) ~= "number" then
        return DEFAULT_MANA_THRESHOLD
    end

    return savedThreshold
end

-- Persist one validated mana threshold value
local function SetManaThreshold(threshold)
    if type(HealerManaSettings) ~= "table" then
        HealerManaSettings = {}
    end

    HealerManaSettings.manaThreshold = threshold
end

-- Escape outbound chat control characters so plain text cannot fail to send
local function EscapeOutboundChatMessage(message)
    return message:gsub("|", "||")
end

-- Resolve the best group chat channel available in 3.3.5a
local function GetGroupChatChannel()
    if type(GetNumRaidMembers) == "function" and GetNumRaidMembers() > 0 then
        return "RAID"
    end

    if type(GetNumPartyMembers) == "function" and GetNumPartyMembers() > 0 then
        return "PARTY"
    end

    if type(UnitName) == "function" and UnitName("party1") then
        return "PARTY"
    end

    return nil
end

-- Return true only while the player is inside a 5-player dungeon instance
local function IsActiveDungeonInstance()
    if type(IsInInstance) ~= "function" then
        return false
    end

    local success, isInstance, instanceType = pcall(IsInInstance)
    return success and isInstance and instanceType == "party"
end

-- Return whether the player is currently assigned as a healer
local function IsPlayerHealer()
    if type(UnitGroupRolesAssigned) ~= "function" then
        return false
    end

    local _, isHealer = UnitGroupRolesAssigned("player")
    return isHealer == true
end

-- Return whether the player currently uses mana and is under the configured threshold
local function IsLowMana()
    if type(UnitPowerType) ~= "function" or type(UnitPower) ~= "function" or type(UnitPowerMax) ~= "function" then
        return false
    end

    local powerType, powerToken = UnitPowerType("player")
    if powerToken ~= "MANA" then
        return false
    end

    local maxMana = UnitPowerMax("player", powerType)
    if type(maxMana) ~= "number" or maxMana <= 0 then
        return false
    end

    local currentMana = UnitPower("player", powerType)
    if type(currentMana) ~= "number" then
        return false
    end

    return currentMana * 100 <= maxMana * GetManaThreshold()
end

-- Send the party warning using the same group-channel pattern as WIT
local function SendLowManaAlert()
    local channel = GetGroupChatChannel()
    if not channel or type(SendChatMessage) ~= "function" then
        return
    end

    local success = pcall(SendChatMessage, EscapeOutboundChatMessage(ALERT_MESSAGE), channel)
    if not success then
        print(FormatErrorMessage(ADDON_PREFIX, "send healer mana warning"))
    end
end

-- Check all activation conditions and send at most one alert per cooldown
local function CheckLowManaAlert()
    if not IsAddonEnabled() then
        return
    end

    local now = GetTime()
    if now - lastAlertAt < GetAlertDelay() then
        return
    end

    if not IsActiveDungeonInstance() or not IsPlayerHealer() or not IsLowMana() then
        return
    end

    SendLowManaAlert()
    lastAlertAt = now
end

-- Print slash command help text
local function PrintHelp()
    print(FormatMessage(ADDON_PREFIX, "Available commands:"))
    print("  |cFFFF8000/whm on |cFFFFFF00- Enable healer mana warnings|r")
    print("  |cFFFF8000/whm off |cFFFFFF00- Disable healer mana warnings|r")
    print("  |cFFFF8000/whm help |cFFFFFF00- Show this help|r")
    print("  |cFFFF8000/whm delay |cFFFFFF00- Show the current warning delay|r")
    print("  |cFFFF8000/whm delay <seconds> |cFFFFFF00- Set the warning delay (30-180)|r")
    print("  |cFFFF8000/whm threshold |cFFFFFF00- Show the current mana threshold|r")
    print("  |cFFFF8000/whm threshold <integer> |cFFFFFF00- Set the mana threshold percent (5-25)|r")
end

-- Print the currently active saved delay
local function PrintDelay()
    print(FormatMessage(ADDON_PREFIX, "Current warning delay", tostring(GetAlertDelay())))
end

-- Print the currently active saved mana threshold
local function PrintThreshold()
    print(FormatMessage(ADDON_PREFIX, "Current mana threshold", GetManaThreshold() .. "%"))
end

-- Parse one integer value from slash command input
local function ParseIntegerArgument(rawArg)
    local trimmedArg = strtrim(rawArg or "")
    if trimmedArg == "" then
        return nil
    end

    if not trimmedArg:match("^%-?%d+$") then
        return nil
    end

    local parsedValue = tonumber(trimmedArg)
    if type(parsedValue) ~= "number" or parsedValue ~= math_floor(parsedValue) then
        return nil
    end

    return parsedValue
end

-- Handle /whm delay and /whm delay <seconds>
local function HandleDelay(args)
    local trimmedArgs = strtrim(args or "")
    if trimmedArgs == "" then
        PrintDelay()
        return
    end

    local firstArg, extraArg = strsplit(" ", trimmedArgs, 2)
    extraArg = strtrim(extraArg or "")

    if extraArg ~= "" then
        print(FormatErrorMessage(ADDON_PREFIX,
            "execute command. Wrong number of arguments for 'delay' (expected 1)"))
        return
    end

    local seconds = ParseIntegerArgument(firstArg)
    if not seconds then
        print(FormatErrorMessage(ADDON_PREFIX,
            "execute command. Invalid argument for 'delay' (expected seconds from 30 to 180)"))
        return
    end

    if seconds < MIN_ALERT_DELAY or seconds > MAX_ALERT_DELAY then
        print(FormatErrorMessage(ADDON_PREFIX,
            "execute command. Invalid argument for 'delay' (expected seconds from 30 to 180)"))
        return
    end

    SetAlertDelay(seconds)
    print(FormatMessage(ADDON_PREFIX, "Warning delay set to", tostring(seconds)))
end

-- Handle /whm threshold and /whm threshold <integer>
local function HandleThreshold(args)
    local trimmedArgs = strtrim(args or "")
    if trimmedArgs == "" then
        PrintThreshold()
        return
    end

    local firstArg, extraArg = strsplit(" ", trimmedArgs, 2)
    extraArg = strtrim(extraArg or "")

    if extraArg ~= "" then
        print(FormatErrorMessage(ADDON_PREFIX,
            "execute command. Wrong number of arguments for 'threshold' (expected 1)"))
        return
    end

    local threshold = ParseIntegerArgument(firstArg)
    if not threshold then
        print(FormatErrorMessage(ADDON_PREFIX,
            "execute command. Invalid argument for 'threshold' (expected percent from 5 to 25)"))
        return
    end

    if threshold < MIN_MANA_THRESHOLD or threshold > MAX_MANA_THRESHOLD then
        print(FormatErrorMessage(ADDON_PREFIX,
            "execute command. Invalid argument for 'threshold' (expected percent from 5 to 25)"))
        return
    end

    SetManaThreshold(threshold)
    print(FormatMessage(ADDON_PREFIX, "Mana threshold set to", threshold .. "%"))
end

-- Enable or disable healer mana warnings without reloading the UI
local function SetAddonEnabled(enabled)
    local currentlyEnabled = IsAddonEnabled()
    if currentlyEnabled == enabled then
        print(FormatMessage(ADDON_PREFIX, string_format("%s is already %s.", ADDON_FULL_NAME, enabled and "enabled" or "disabled")))
        return
    end

    SetSavedAddonEnabled(enabled)
    lastAlertAt = -GetAlertDelay()
    print(FormatMessage(ADDON_PREFIX, string_format("%s %s.", ADDON_FULL_NAME, enabled and "enabled" or "disabled")))
end

local function EnableAddon()
    SetAddonEnabled(true)
end

local function DisableAddon()
    SetAddonEnabled(false)
end

local SUBCOMMANDS = {
    ["on"] = { handler = EnableAddon, args = 0 },
    ["off"] = { handler = DisableAddon, args = 0 },
    ["help"] = { handler = PrintHelp, args = 0 },
    ["delay"] = { handler = HandleDelay, args = 1 },
    ["threshold"] = { handler = HandleThreshold, args = 1 }
}

-- Register slash command parser following Blizzard pattern
local function RegisterSlashCommands()
    SLASH_WHM1 = "/whm"
    SlashCmdList["WHM"] = function(msg)
        local rawMsg = strtrim(msg or "")
        local normalizedMsg = string_lower(rawMsg)

        if normalizedMsg == "" then
            PrintHelp()
            return
        end

        local subcommand = strsplit(" ", normalizedMsg, 2)
        local command = SUBCOMMANDS[subcommand]
        local _, rawArgs = strsplit(" ", rawMsg, 2)
        rawArgs = strtrim(rawArgs or "")

        if not command then
            print(FormatErrorMessage(ADDON_PREFIX, string_format(
                "find subcommand '%s'. Use /whm help to see available commands", subcommand)))
            return
        end

        if command.args == 0 and rawArgs ~= "" then
            print(FormatErrorMessage(ADDON_PREFIX, string_format(
                "execute command. Wrong number of arguments for '%s' (expected %d)", subcommand, command.args)))
            return
        end

        command.handler(rawArgs)
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
frame:RegisterEvent("UNIT_DISPLAYPOWER")
frame:RegisterEvent("UNIT_MANA")
frame:RegisterEvent("UNIT_MAXMANA")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

frame:SetScript("OnUpdate", function(self, elapsed)
    self.timer = (self.timer or 0) + elapsed
    if self.timer < CHECK_INTERVAL then
        return
    end

    self.timer = 0
    CheckLowManaAlert()
end)

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        InitializeSavedData()
        RegisterSlashCommands()
        print(FormatMessage(ADDON_PREFIX, "WarmaneHealerMana loaded"))
        return
    end

    if (event == "UNIT_MANA" or event == "UNIT_MAXMANA" or event == "UNIT_DISPLAYPOWER") and ... ~= "player" then
        return
    end

    CheckLowManaAlert()
end)

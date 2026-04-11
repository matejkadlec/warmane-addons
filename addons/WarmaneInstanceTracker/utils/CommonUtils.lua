local addonName, addon = ...

-- Cache frequently used functions
local type = type
local pcall = pcall
local math_floor = math.floor
local string_format = string.format
local string_sub = string.sub

-- Define color codes used in chat messages
local COLOR = {
    ORANGE = "|cFFFF8000",
    YELLOW = "|cFFFFFF00",
    RED = "|cFFFF0000"
}

-- Format numbers with dots as thousand separators
local function FormatNumber(number)
    if type(number) ~= "number" then
        return "0"
    end
    local formatted = tostring(number)
    local k = #formatted % 3
    if k == 0 then k = 3 end
    local result = string_sub(formatted, 1, k)
    for i = k + 1, #formatted, 3 do
        result = result .. "." .. string_sub(formatted, i, i + 2)
    end
    return result
end

-- Format general messages with prefix and optional value
local function FormatMessage(prefix, msg, value, showColon)
    if type(prefix) ~= "string" or type(msg) ~= "string" then return "" end
    local formattedPrefix = string_format("%s[%s]", COLOR.ORANGE, prefix)
    if value then
        if showColon then
            return string_format("%s %s%s: %s%s|r",
                formattedPrefix, COLOR.YELLOW, msg, COLOR.ORANGE, value)
        else
            return string_format("%s %s%s %s%s|r",
                formattedPrefix, COLOR.YELLOW, msg, COLOR.ORANGE, value)
        end
    end
    return string_format("%s %s%s|r", formattedPrefix, COLOR.YELLOW, msg)
end

-- Format error messages with colored prefix and red body
local function FormatErrorMessage(prefix, msg)
    if type(prefix) ~= "string" or type(msg) ~= "string" then return "" end
    return string_format("%s[%s] %sFailed to %s|r",
        COLOR.ORANGE, prefix, COLOR.RED, msg)
end

-- Safely get instance name with fallback to zone name
local function SafeGetRealZoneText()
    local success, zoneName = pcall(GetRealZoneText)
    if success and zoneName and zoneName ~= "" then
        return zoneName
    end

    success, zoneName = pcall(GetZoneText)
    if success and zoneName and zoneName ~= "" then
        -- Remove instance numbers like "(1)" or " (2)" from the end
        return zoneName:gsub("%s*%([%d]+%)", "")
    end

    return "Unknown Zone"
end

-- Safely get current XP with error handling
local function SafeUnitXP(unit)
    if not unit then return nil end
    local success, xp = pcall(UnitXP, unit)
    if not success or type(xp) ~= "number" then
        print(FormatErrorMessage("WIT", "retrieve XP data"))
        return nil
    end
    return xp
end

-- Safely get max XP for current level with validation
local function SafeUnitXPMax(unit)
    if not unit then return 1 end
    local success, maxXp = pcall(UnitXPMax, unit)
    if not success or type(maxXp) ~= "number" or maxXp <= 0 then
        print(FormatErrorMessage("WIT", "retrieve valid max XP data"))
        return 1
    end
    return maxXp
end

-- Safely get current level with validation
local function SafeUnitLevel(unit)
    if not unit then return 1 end
    local success, level = pcall(UnitLevel, unit)
    if not success or type(level) ~= "number" or level <= 0 then
        print(FormatErrorMessage("WIT", "retrieve valid level data"))
        return 1
    end
    return level
end

-- Export common utilities to addon namespace
addon.common = {
    Message = FormatMessage,
    ErrorMessage = FormatErrorMessage,
    Number = FormatNumber,
}

addon.safe = {
    GetRealZoneText = SafeGetRealZoneText,
    UnitXP = SafeUnitXP,
    UnitXPMax = SafeUnitXPMax,
    UnitLevel = SafeUnitLevel,
}

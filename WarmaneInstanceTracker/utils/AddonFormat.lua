local addonName, addon = ...

-- Cache frequently used functions
local type = type
local math_floor = math.floor
local math_abs = math.abs
local string_format = string.format

-- Import common utils for base formatting
local WCU = _G.WarmaneCommonUtils

-- Define color codes
local COLOR = {
    GREEN = "|cFF00FF00",
    RED = "|cFFFF0000",
    ORANGE = "|cFFFF8000",
    YELLOW = "|cFFFFFF00"
}

addon.format = {
    -- Format entering instance format with consistent coloring
    EnteringMessage = function(instanceName, timeMsg)
        -- Validate input
        if type(instanceName) ~= "string" then return "" end
        
        return string_format("%s[WIT] %sEntering%s %s%s, fastest time:%s %s%s, good luck!|r",
            COLOR.ORANGE,               -- [WIT]
            COLOR.YELLOW,               -- Entering
            COLOR.ORANGE, instanceName, -- instanceName
            COLOR.YELLOW,               -- , fastest time:
            COLOR.ORANGE, timeMsg,      -- timeMsg
            COLOR.YELLOW)               -- , good luck!
    end,

    -- Format time difference with color coding and +/- prefix
    TimeDifference = function(currentTime, compareTime)
        if type(currentTime) ~= "number" or type(compareTime) ~= "number" then
            return ""
        end
        
        if currentTime == compareTime then return "" end
        
        local diff = math_abs(currentTime - compareTime)
        local minutes = math_floor(diff / 60)
        local seconds = diff % 60
        -- Current faster than compared = green with minus, slower = red with plus
        local color = currentTime < compareTime and COLOR.GREEN or COLOR.RED
        local sign = currentTime < compareTime and "-" or "+"
        
        if minutes > 0 then
            return string_format(" %s(%s%d min %d sec)|r", 
                color, sign, minutes, seconds)
        else
            return string_format(" %s(%s%d sec)|r", 
                color, sign, seconds)
        end
    end,

    -- Format XP difference with color coding and +/- prefix
    XPDifference = function(currentXP, compareXP)
        if type(currentXP) ~= "number" or type(compareXP) ~= "number" then
            return ""
        end
        
        if currentXP == compareXP then return "" end
        
        local diff = math_abs(currentXP - compareXP)
        local color = currentXP > compareXP and COLOR.GREEN or COLOR.RED
        local sign = currentXP > compareXP and "+" or "-"
        
        return string_format(" %s(%s%s)|r", 
            color, sign, WCU.common_format.Number(diff))
    end
}

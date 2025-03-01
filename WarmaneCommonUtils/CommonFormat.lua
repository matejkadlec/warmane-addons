-- Cache frequently used functions
local type = type
local math_floor = math.floor
local math_abs = math.abs
local string_format = string.format
local string_sub = string.sub

-- Access library from global scope
local WCU = _G.WarmaneCommonUtils

-- Define color codes used in chat messages
local COLOR = {
    ORANGE = "|cFFFF8000",
    YELLOW = "|cFFFFFF00",
    RED = "|cFFFF0000"
}

-- Format numbers with dots as thousand separators
WCU.common_format = {
    -- Format general messages with prefix and optional value
    Message = function(prefix, msg, value, showColon)
        -- Validate input
        if type(prefix) ~= "string" or type(msg) ~= "string" then return "" end
        
        local formattedPrefix = string_format("%s[%s] ", COLOR.ORANGE, prefix)
        
        if value then
            if showColon then
                return string_format("%s%s%s: %s%s|r", 
                    formattedPrefix, COLOR.YELLOW, msg, COLOR.ORANGE, value)
            else
                return string_format("%s%s%s %s%s|r", 
                    formattedPrefix, COLOR.YELLOW, msg, COLOR.ORANGE, value)
            end
        end
        
        return string_format("%s%s%s|r", formattedPrefix, COLOR.YELLOW, msg)
    end,

    Number = function(number)
        -- Validate input
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
    end,

    -- Format error messages in red color
    ErrorMessage = function(prefix, msg)
        if type(prefix) ~= "string" or type(msg) ~= "string" then return "" end
        return string_format("%s[%s] Failed to %s|r", COLOR.RED, prefix, msg)
    end
}

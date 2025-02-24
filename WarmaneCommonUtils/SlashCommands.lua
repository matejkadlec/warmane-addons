-- Cache frequently used functions
local string_format = string.format
local C_Timer = C_Timer

-- Access library from global scope
local WCU = _G.WarmaneCommonUtils

-- Define color codes
local COLOR = {
    ORANGE = "|cFFFF8000",
    YELLOW = "|cFFFFFF00"
}

WCU.slash_command = {
    Toggle = function(prefix, addonName, enabledVar)
        enabledVar = not enabledVar
        print(WCU.common_format.Message(prefix, addonName, enabledVar and "enabled" or "disabled", false))
        return enabledVar
    end,

    ToggleWithDelay = function(prefix, addonName, enabledVar)
        enabledVar = not enabledVar
        local state = enabledVar and "Enabling" or "Disabling"
        
        print(string_format("%s[%s]%s %s %s%s%s...",
            COLOR.ORANGE,
            prefix,
            COLOR.YELLOW,
            state,
            COLOR.ORANGE,
            addonName,
            COLOR.YELLOW))
            
        C_Timer.After(2.5, function()
            print(WCU.common_format.Message(prefix, addonName, 
                enabledVar and "enabled" or "disabled", false))
        end)
        
        return enabledVar
    end
}

-- Cache frequently used functions
local pcall = pcall

-- Access library from global scope
local WCU = _G.WarmaneCommonUtils

-- Format error messages
local function ErrorMessage(message)
    return WCU.common_format.ErrorMessage(message)
end

WCU.safe = {
    -- Safely get instance name with fallback to zone name
    GetRealZoneText = function() 
        local success = false
        local zoneName = nil

        -- Try GetRealZoneText first   
        success, zoneName = pcall(GetRealZoneText)
        if success and zoneName and zoneName ~= "" then
            return zoneName
        end

        -- Fall back to GetZoneText and clean it
        success, zoneName = pcall(GetZoneText)
        if success and zoneName and zoneName ~= "" then
            -- Remove instance numbers like "(1)" or " (2)" from the end
            return zoneName:gsub("%s*%([%d]+%)", "")
        end
        
        return "Unknown Zone"
    end,

    -- Safely get current XP with error handling
    UnitXP = function(unit)
        if not unit then return nil end
        local success, xp = pcall(UnitXP, unit)
        if not success or type(xp) ~= "number" then
            print(ErrorMessage("retrieve XP data"))
            return nil
        end
        return xp
    end,

    -- Safely get max XP for current level with validation
    UnitXPMax = function(unit)
        if not unit then return 1 end
        local success, maxXp = pcall(UnitXPMax, unit)
        if not success or type(maxXp) ~= "number" or maxXp <= 0 then
            print(ErrorMessage("retrieve valid max XP data"))
            return 1
        end
        return maxXp
    end,

    -- Safely get current level with validation
    UnitLevel = function(unit)
        if not unit then return 1 end
        local success, level = pcall(UnitLevel, unit)
        if not success or type(level) ~= "number" or level <= 0 then
            print(ErrorMessage("retrieve valid level data"))
            return 1
        end
        return level
    end
}

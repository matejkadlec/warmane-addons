local addonName, addon = ...

-- Cache freqently used functions
local type = type
local ipairs = ipairs

-- Import WarmaneCommonUtils from global scope
local safe = _G.WarmaneCommonUtils.safe

addon.utils = {
    -- Get NPC ID from dstGUID
    GetNPCId = function(dstGUID)
        if not dstGUID or type(dstGUID) ~= "string" then 
            return nil 
        end
        return tonumber(dstGUID:sub(9, 12), 16)
    end,

    -- Create or initialize saved variables database with default values
    InitializeSavedData = function()
        -- Ensure clean initialization
        if not WITSavedData or type(WITSavedData) ~= "table" then
            WITSavedData = { instances = {} }
        end
        -- Clear corrupted or invalid data
        if type(WITSavedData.instances) ~= "table" then
            WITSavedData.instances = {}
        end
    end,

    -- Calculate average and fastest times for a specific dungeon
    GetInstanceStats = function(instanceName)
        -- Single validation for saved data
        if not instanceName or type(instanceName) ~= "string" or 
           instanceName == "" or 
           not WITSavedData or 
           type(WITSavedData.instances) ~= "table" then
            return nil
        end
        
        local totalTime = 0
        local fastestTime = nil
        local totalXP = 0
        local totalRuns = 0
        local currentCharacter = UnitName("player")
        
        -- Validate each run entry once
        for _, run in ipairs(WITSavedData.instances) do
            if type(run) == "table" and 
               run.name == instanceName and 
               run.duration > 0 and
               run.character == currentCharacter then
                
                totalTime = totalTime + run.duration
                if not fastestTime or run.duration < fastestTime then
                    fastestTime = run.duration
                end

                if run.xpGained and run.xpGained > 0 then
                    totalXP = totalXP + run.xpGained
                end
                totalRuns = totalRuns + 1
            end
        end
        
        if totalRuns == 0 then return nil end
        
        return {
            averageTime = totalTime / totalRuns,
            fastestTime = fastestTime,
            averageXP = totalXP > 0 and (totalXP / totalRuns) or nil,
            totalRuns = totalRuns
        }
    end
}

local addonName, addon = ...

-- Cache frequently used functions
local time = time
local print = print
local math_floor = math.floor
local string_format = string.format

-- Import WarmaneCommonUtils and local utils
local WCU = _G.WarmaneCommonUtils
local common_format = WCU.common_format
local safe = WCU.safe
local utils = addon.utils
local format = addon.format

-- Initialize instance tracking state variables
local inInstance = false
local instanceName = ""
local startTime = 0
local xpGained = 0
local initialXP = 0
local initialXPMax = 0
local initialLevel = 0
local mobsKilled = 0
local lastXPUpdate = 0
local isCorpseRunning = false

-- Process and display instance completion statistics
function ProcessInstanceCompletion()
    -- Validate essential state first
    if not inInstance or startTime == 0 then 
        print(common_format.ErrorMessage("WIT", "process completion (invalid state)"))
        print(common_format.Message("WIT", "Debug - inInstance", tostring(inInstance), true))
        print(common_format.Message("WIT", "Debug - startTime", format.Time(startTime), true))
        print(common_format.Message("WIT", "Debug - instanceName", instanceName, true))
        return 
    end
    
    -- Calculate run duration
    local duration = time() - startTime
    
    -- Check if player is max level
    local isMaxLevel = safe.UnitLevel("player") == MAX_PLAYER_LEVEL
    
    if isMaxLevel then
        -- For max level characters, only track time
        if duration <= 0 then
            print(common_format.ErrorMessage("WIT", "save instance data (invalid duration)"))
            return
        end
        
        -- Prepare instance data
        local instanceData = {
            name = instanceName,
            duration = duration,
            timestamp = time(),
            character = UnitName("player"),
            level = safe.UnitLevel("player")
        }
        
        -- Save run data to persistent storage
        if WITSavedData then
            table_insert(WITSavedData.instances, instanceData)
        else
            print(common_format.ErrorMessage("WIT", "access saved data (corrupted or not initialized)"))
            return
        end
        
        -- Get statistical data for time comparisons
        local stats = utils.GetInstanceStats(instanceName)
        
        -- Display completion statistics
        print(common_format.Message("WIT", instanceName .. " completed in", format.Time(duration), false))
        
        if duration ~= stats.averageTime then
            print(common_format.Message("WIT", "Average time", format.Time(stats.averageTime) .. 
                format.TimeDifference(duration, stats.averageTime), true))
        end
        if duration ~= stats.fastestTime then
            print(common_format.Message("WIT", "Fastest time", format.Time(stats.fastestTime) .. 
                format.TimeDifference(duration, stats.fastestTime), true))
        end
        
        -- Reset state variables
        inInstance = false
        instanceName = ""
        startTime = 0
        return
    end
    
    -- Continue with existing XP tracking logic for non-max level characters
    local currentXP = safe.UnitXP("player")
    local currentLevel = safe.UnitLevel("player")
    local reachedMaxLevel = currentLevel == MAX_PLAYER_LEVEL and initialLevel == MAX_PLAYER_LEVEL - 1
    
    -- Handle XP calculation across level-ups
    if currentLevel > initialLevel then
        xpGained = (initialXPMax - initialXP) + currentXP
    else
        xpGained = currentXP - initialXP
    end

    -- Single validation for all required data
    if not instanceName or instanceName == "" or
       duration <= 0 or
       xpGained <= 0 or
       mobsKilled <= 0 then
        print(common_format.ErrorMessage("WIT", "save instance data (invalid values)"))
        print(common_format.Message("WIT", "Debug - instanceName", instanceName, true))
        print(common_format.Message("WIT", "Debug - duration", format.Time(duration), true))
        print(common_format.Message("WIT", "Debug - xpGained", format.Number(xpGained), true))
        print(common_format.Message("WIT", "Debug - mobsKilled", format.Number(mobsKilled), true))
        return
    end
    
    -- For Unknown Zone, only show basic statistics
    if instanceName == "Unknown Zone" then
        local xpToLevel = currentLevel > initialLevel and safe.UnitXPMax("player") or 
            (safe.UnitXPMax("player") - safe.UnitXP("player"))

        print(common_format.Message("WIT", instanceName .. " completed in", format.Time(duration), false))
        print(common_format.Message("WIT", "Mobs killed", format.Number(mobsKilled), true))
        print(common_format.Message("WIT", "Average XP per mob", format.Number(math_floor(xpGained / mobsKilled)), true))
        print(common_format.Message("WIT", "XP received", format.Number(xpGained), true))
        print(common_format.Message("WIT", "Runs until next level", string_format("%.1f", xpToLevel / xpGained), true))
        
        -- Reset state variables
        inInstance = false
        instanceName = ""
        startTime = 0
        xpGained = 0
        initialXP = 0
        initialXPMax = 0
        initialLevel = 0
        mobsKilled = 0
        return
    end
    
    -- Continue with normal processing for known zones
    
    -- Prepare instance data (no fallback values, data is validated)
    local instanceData = {
        name = instanceName,
        duration = duration,
        xpGained = xpGained,
        timestamp = time(),
        character = UnitName("player"),
    }
    
    -- Save run data to persistent storage
    if WITSavedData then
        table_insert(WITSavedData.instances, instanceData)
    else
        print(common_format.ErrorMessage("WIT", "access saved data (corrupted or not initialized)"))
        return
    end
    
    -- Get statistical data for comparisons
    local stats = utils.GetInstanceStats(instanceName)
    if not stats then
        print(common_format.ErrorMessage("WIT", "retrieve instance statistics"))
        return
    end
    local xpPerMob = math_floor(xpGained / mobsKilled)
    
    -- Display completion statistics if XP was gained
    print(common_format.Message("WIT", instanceName .. " completed in", format.Time(duration), false))
    if duration ~= stats.averageTime then
        print(common_format.Message("WIT", "Average time", format.Time(stats.averageTime) .. 
            format.TimeDifference(duration, stats.averageTime), true))
    end
    if duration ~= stats.fastestTime then
        print(common_format.Message("WIT", "Fastest time", format.Time(stats.fastestTime) .. 
            format.TimeDifference(duration, stats.fastestTime), true))
    end
    print(common_format.Message("WIT", "Mobs killed", format.Number(mobsKilled), true))
    print(common_format.Message("WIT", "Average XP per mob", format.Number(xpPerMob), true))
    print(common_format.Message("WIT", "XP received", format.Number(xpGained), true))
    if xpGained ~= stats.averageXP then
        print(common_format.Message("WIT", "Average XP received", format.Number(stats.averageXP) .. 
            format.XPDifference(xpGained, stats.averageXP), true))
    end
    
    -- Only show XP to level info if player hasn't reached max level
    if not reachedMaxLevel then
        local xpToLevel = currentLevel > initialLevel and safe.UnitXPMax("player") or 
            (safe.UnitXPMax("player") - safe.UnitXP("player"))
        local runsNeeded = xpToLevel / stats.averageXP
        
        print(common_format.Message("WIT", "XP until next level", format.Number(xpToLevel), true))
        print(common_format.Message("WIT", "Runs until next level", "~" .. string_format("%.1f", runsNeeded), true))
    end

    -- Reset all instance state variables after completion
    inInstance = false
    instanceName = ""
    startTime = 0
    xpGained = 0
    initialXP = 0
    initialXPMax = 0
    initialLevel = 0
    mobsKilled = 0
end

-- Main frame for event handling
local WIT = CreateFrame("Frame")

-- Initialize final boss data
local DUNGEON_FINAL_BOSSES = addon.DUNGEON_FINAL_BOSSES

-- Register events needed for tracking
WIT:RegisterEvent("ADDON_LOADED")
WIT:RegisterEvent("ZONE_CHANGED_NEW_AREA")
WIT:RegisterEvent("PLAYER_XP_UPDATE")
WIT:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
WIT:RegisterEvent("PLAYER_DEAD")

-- Main event handler
WIT:SetScript("OnEvent", function(self, event, ...)
    -- Initialize addon data and show welcome message
    if event == "ADDON_LOADED" and ... == addonName then
        local success = pcall(utils.InitializeSavedData)
        if not success then
            print(common_format.ErrorMessage("WIT", "initialize saved data"))
            return
        end
        
        print(string_format("|cFFFF8000Warmane|cFFFFFF00InstanceTracker loaded|r"))
        
    -- Handle combat events for boss kills and mob tracking
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then        
        if inInstance then
            local _, subevent, _, _, _, dstGUID = ...
            
            if subevent == "UNIT_DIED" then
                -- Get timestamp to use in PLAYER_XP_UPDATE for mobsKilled tracking 
                lastXPUpdate = time()
                
                -- Get NPC ID for final boss of the instance
                local npcId = utils.GetNPCId(dstGUID)
                if npcId then
                    if DUNGEON_FINAL_BOSSES[npcId] == instanceName then
                        ProcessInstanceCompletion()
                        return
                    end
                end
            end
        end

    elseif event == "PLAYER_XP_UPDATE" then
        -- Only count mob if XP was gained within 1 second of mob death
        if inInstance and (time() - lastXPUpdate) <= 1 then
            mobsKilled = mobsKilled + 1
        end

    elseif event == "PLAYER_DEAD" then
        if inInstance then
            isCorpseRunning = true
        end

    elseif event == "ZONE_CHANGED_NEW_AREA" then        
        local success, isInstance, instanceType = pcall(IsInInstance)
        if not success then
            print(common_format.ErrorMessage("WIT", "check instance status"))
            return
        end

        if isInstance and instanceType == "party" then
            -- Only start tracking if this isn't a corpse run
            if not isCorpseRunning then
                inInstance = true
                instanceName = safe.GetRealZoneText()
                startTime = time()
                initialXP = safe.UnitXP("player")
                initialXPMax = safe.UnitXPMax("player")
                initialLevel = safe.UnitLevel("player")
                mobsKilled = 0
                xpGained = 0
                local stats = utils.GetInstanceStats(instanceName)
                local fastestTime = stats and stats.fastest
                local timeMsg = fastestTime and format.Time(fastestTime) or "not recorded"
                print(format.EnteringMessage(instanceName, timeMsg))
            else
                -- We're back from corpse run
                isCorpseRunning = false
            end
        end
    end
end)

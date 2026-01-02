local addonName, addon = ...

-- Cache frequently used functions
local select = select
local GetSpellInfo = GetSpellInfo
local UnitCreatureType = UnitCreatureType
local CastSpellByName = CastSpellByName
local string_format = string.format
local GetTime = GetTime
local UnitReaction = UnitReaction

-- Import WarmaneCommonUtils from global scope
local WCU = _G.WarmaneCommonUtils
local common_format = WCU.common_format

-- Define tracking spells and their corresponding creature types
local TRACKING_SPELLS = {
    ["Beast"] = "Track Beasts",
    ["Demon"] = "Track Demons",
    ["Dragonkin"] = "Track Dragonkin",
    ["Elemental"] = "Track Elementals",
    ["Giant"] = "Track Giants",
    ["Undead"] = "Track Undead",
    ["Humanoid"] = "Track Humanoids"
}

-- Mapping of tracking texture paths to tracking type names
local MINIMAP_TRACKING = {
    ["Interface\\Icons\\Ability_Tracking"] = "Track Beasts",
    ["Interface\\Icons\\Spell_Shadow_SummonFelHunter"] = "Track Demons",
    ["Interface\\Icons\\INV_Misc_Head_Dragon_01"] = "Track Dragonkin",
    ["Interface\\Icons\\Spell_Frost_SummonWaterElemental"] = "Track Elementals",
    ["Interface\\Icons\\Ability_Racial_Avatar"] = "Track Giants",
    ["Interface\\Icons\\Spell_Shadow_DarkSummoning"] = "Track Undead",
    ["Interface\\Icons\\Spell_Holy_PrayerOfHealing"] = "Track Humanoids"
}

-- Create main frame
local WTA = CreateFrame("Frame")

-- Initialize tracking aid variables
local playerClass = nil
local lastCastTime = 0
local lastKnownTracking = nil

-- Global cooldown in seconds
local GCD_DELAY = 1.5

-- Function to get current active tracking
local function GetActiveTracking()
    local texture = GetTrackingTexture()
    if texture then
        return MINIMAP_TRACKING[texture] or "Not Tracking Creature Type"
    end
end

-- Register both initial events
WTA:RegisterEvent("ADDON_LOADED")
WTA:RegisterEvent("MINIMAP_UPDATE_TRACKING")

-- Main event handler
WTA:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        -- Check if player is a hunter
        playerClass = select(2, UnitClass("player"))
        if playerClass ~= "HUNTER" then
            self:UnregisterAllEvents()
            return
        end
        
        -- Print loading message
        print(string_format("|cFFFF8000Warmane|cFFFFFF00TrackingAid loaded|r"))
        
        -- Register target change event only for hunters
        self:RegisterEvent("PLAYER_TARGET_CHANGED")
        
    elseif event == "MINIMAP_UPDATE_TRACKING" then
        -- Update lastCastTime when tracking changes manually
        local currentTracking = GetActiveTracking()
        if currentTracking ~= lastKnownTracking then
            lastCastTime = GetTime()
            lastKnownTracking = currentTracking
        end
        
    elseif event == "PLAYER_TARGET_CHANGED" then        
        if UnitExists("target") then
            -- Check if target is neutral or hostile
            local reaction = UnitReaction("player", "target")
            if reaction and reaction <= 4 then  -- 4 or less means neutral or hostile
                local creatureType = UnitCreatureType("target")
                local trackingSpell = TRACKING_SPELLS[creatureType]
                local currentTracking = GetActiveTracking()
                
                if trackingSpell and trackingSpell ~= currentTracking then
                    local currentTime = GetTime()
                    local timeSinceLastCast = currentTime - lastCastTime
                    
                    if timeSinceLastCast >= GCD_DELAY then
                        CastSpellByName(trackingSpell)
                        lastCastTime = currentTime
                        lastKnownTracking = trackingSpell
                        
                        local _, _, icon = GetSpellInfo(trackingSpell)
                        if icon then
                            print(common_format.Message("WTA", "Switched to", trackingSpell, true))
                        end
                    else
                        local remainingTime = GCD_DELAY - timeSinceLastCast
                        local timeText = remainingTime >= 1 and 
                            string_format("%.1f |cFFFFFF00second|r", remainingTime) or
                            string_format("%.1f |cFFFFFF00seconds|r", remainingTime)
                        print(common_format.Message("WTA", "You need to wait", timeText))
                    end
                end
            end
        end
    end
end)

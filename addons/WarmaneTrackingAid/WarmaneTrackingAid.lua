local addonName, addon = ...

-- Cache frequently used functions
local getglobal = getglobal
local print = print
local select = select
local type = type
local GetSpellInfo = GetSpellInfo
local UnitCreatureType = UnitCreatureType
local CastSpellByName = CastSpellByName
local string_format = string.format
local string_lower = string.lower
local GetTime = GetTime
local UnitReaction = UnitReaction
local strsplit = strsplit
local strtrim = strtrim

-- Define color codes
local COLOR = {
    ORANGE = "|cFFFF8000",
    YELLOW = "|cFFFFFF00",
    RED = "|cFFFF0000"
}

local ADDON_PREFIX = "WTA"
local ADDON_FULL_NAME = "WarmaneTrackingAid"
local DEFAULT_ADDON_ENABLED = true
local PARENT_CATEGORY_NAME = "Warmane AddOns"
local PARENT_PANEL_NAME = "WarmaneAddOnsInterfaceOptionsPanel"

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
local trackingAidActive = false
local interfaceOptionsPanel = nil
local interfaceOptionsCheckbox = nil

local RefreshInterfaceOptions

-- Global cooldown in seconds
local GCD_DELAY = 1.5

-- Create the saved settings table and populate validated defaults
local function InitializeSavedData()
    if type(WarmaneTrackingAidSettings) ~= "table" then
        WarmaneTrackingAidSettings = {}
    end

    if type(WarmaneTrackingAidSettings.enabled) ~= "boolean" then
        WarmaneTrackingAidSettings.enabled = DEFAULT_ADDON_ENABLED
    end
end

-- Read the current persisted enabled state safely
local function IsAddonEnabled()
    InitializeSavedData()
    return WarmaneTrackingAidSettings.enabled
end

-- Persist one validated enabled state
local function SetSavedAddonEnabled(enabled)
    InitializeSavedData()
    WarmaneTrackingAidSettings.enabled = enabled and true or false
end

-- Function to get current active tracking
local function GetActiveTracking()
    local texture = GetTrackingTexture()
    if texture then
        return MINIMAP_TRACKING[texture] or "Not Tracking Creature Type"
    end
end

-- Start tracking aid events for Hunter characters
local function ActivateTrackingAid()
    if trackingAidActive or playerClass ~= "HUNTER" or not IsAddonEnabled() then
        return
    end

    lastKnownTracking = GetActiveTracking()
    WTA:RegisterEvent("MINIMAP_UPDATE_TRACKING")
    WTA:RegisterEvent("PLAYER_TARGET_CHANGED")
    trackingAidActive = true
end

-- Stop tracking aid events and clear transient state
local function DeactivateTrackingAid()
    WTA:UnregisterEvent("MINIMAP_UPDATE_TRACKING")
    WTA:UnregisterEvent("PLAYER_TARGET_CHANGED")
    lastCastTime = 0
    lastKnownTracking = nil
    trackingAidActive = false
end

-- Apply activation state based on class and saved settings
local function RefreshTrackingAidActivation()
    if playerClass == "HUNTER" and IsAddonEnabled() then
        ActivateTrackingAid()
    else
        DeactivateTrackingAid()
    end
end

-- Register the initialization event; runtime events are enabled only while active
WTA:RegisterEvent("ADDON_LOADED")

-- Main event handler
WTA:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        InitializeSavedData()

        -- Check if player is a hunter
        playerClass = select(2, UnitClass("player"))
        if playerClass ~= "HUNTER" then
            DeactivateTrackingAid()
            return
        end
        
        -- Print loading message
        print(FormatMessage(ADDON_PREFIX, ADDON_FULL_NAME .. " loaded"))
        RefreshTrackingAidActivation()
        return
    end

    if not trackingAidActive then
        return
    end
        
    if event == "MINIMAP_UPDATE_TRACKING" then
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
                            -- Extract creature type name from spell (e.g. "Track Humanoids" -> "Humanoids")
                            local creatureTypeName = trackingSpell:gsub("Track ", "")
                            print(FormatMessage(ADDON_PREFIX, "Switched to track", creatureTypeName))
                        end
                    else
                        -- Notify player about GCD cooldown
                        local remainingTime = GCD_DELAY - timeSinceLastCast
                        local timeText = string_format("%.1f seconds", remainingTime)
                        print(FormatMessage(ADDON_PREFIX, "You need to wait", timeText))
                    end
                end
            end
        end
    end
end)

-- Print help text listing available slash commands
local function PrintHelp()
    print(FormatMessage(ADDON_PREFIX, "Available commands:"))
    print("  |cFFFF8000/wta |cFFFFFF00- Show this help|r")
    print("  |cFFFF8000/wta on |cFFFFFF00- Enable Hunter tracking aid|r")
    print("  |cFFFF8000/wta off |cFFFFFF00- Disable Hunter tracking aid|r")
    print("  |cFFFF8000/wta help |cFFFFFF00- Show this help|r")
end

-- Enable or disable tracking aid without reloading the UI
local function SetAddonEnabled(enabled)
    local currentlyEnabled = IsAddonEnabled()
    if currentlyEnabled == enabled then
        print(FormatMessage(ADDON_PREFIX, string_format("%s is already %s.", ADDON_FULL_NAME, enabled and "enabled" or "disabled")))
        return
    end

    SetSavedAddonEnabled(enabled)
    RefreshTrackingAidActivation()
    print(FormatMessage(ADDON_PREFIX, string_format("%s %s.", ADDON_FULL_NAME, enabled and "enabled" or "disabled")))

    if RefreshInterfaceOptions then
        RefreshInterfaceOptions()
    end
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
    ["help"] = { handler = PrintHelp, args = 0 }
}

-- Register slash command parser following Blizzard pattern
SLASH_WTA1 = "/wta"
SlashCmdList["WTA"] = function(msg)
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
            "find subcommand '%s'. Use /wta help to see available commands", subcommand)))
        return
    end

    if command.args == 0 and rawArgs ~= "" then
        print(FormatErrorMessage(ADDON_PREFIX, string_format(
            "execute command. Wrong number of arguments for '%s' (expected %d)", subcommand, command.args)))
        return
    end

    command.handler(rawArgs)
end

local function EnsureWarmaneAddOnsCategory(defaultOpenFunc)
    local parentPanel = getglobal(PARENT_PANEL_NAME)
    if not parentPanel then
        parentPanel = CreateFrame("Frame", PARENT_PANEL_NAME)
        parentPanel.name = PARENT_CATEGORY_NAME

        local title = parentPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", parentPanel, "TOPLEFT", 16, -16)
        title:SetText(PARENT_CATEGORY_NAME)

        parentPanel:SetScript("OnShow", function(self)
            if self.warmaneRedirecting or type(self.warmaneOpenDefaultChild) ~= "function" then
                return
            end

            self.warmaneRedirecting = true
            self.warmaneOpenDefaultChild()
            self.warmaneRedirecting = false
        end)

        parentPanel:Hide()
        InterfaceOptions_AddCategory(parentPanel)
    end

    if type(parentPanel.warmaneOpenDefaultChild) ~= "function" then
        parentPanel.warmaneOpenDefaultChild = defaultOpenFunc
    end
end

RefreshInterfaceOptions = function()
    if interfaceOptionsCheckbox then
        interfaceOptionsCheckbox:SetChecked(IsAddonEnabled())
    end
end

local function RegisterInterfaceOptions()
    local function OpenPanel()
        if interfaceOptionsPanel and type(InterfaceOptionsFrame_OpenToCategory) == "function" then
            InterfaceOptionsFrame_OpenToCategory(interfaceOptionsPanel)
        end
    end

    EnsureWarmaneAddOnsCategory(OpenPanel)

    interfaceOptionsPanel = CreateFrame("Frame", "WTAInterfaceOptionsPanel")
    interfaceOptionsPanel.name = "Tracking Aid"
    interfaceOptionsPanel.parent = PARENT_CATEGORY_NAME

    local title = interfaceOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", interfaceOptionsPanel, "TOPLEFT", 16, -16)
    title:SetText("Warmane Tracking Aid")

    local header = interfaceOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", interfaceOptionsPanel, "TOPLEFT", 18, -52)
    header:SetText("User settings")

    interfaceOptionsCheckbox = CreateFrame("CheckButton", "WTAInterfaceOptionsEnabled", interfaceOptionsPanel, "InterfaceOptionsCheckButtonTemplate")
    interfaceOptionsCheckbox:SetPoint("TOPLEFT", interfaceOptionsPanel, "TOPLEFT", 14, -76)
    getglobal(interfaceOptionsCheckbox:GetName() .. "Text"):SetText("Enable Hunter tracking aid")
    interfaceOptionsCheckbox:SetScript("OnClick", function(self)
        SetAddonEnabled(self:GetChecked() and true or false)
    end)

    interfaceOptionsPanel:SetScript("OnShow", RefreshInterfaceOptions)
    interfaceOptionsPanel.refresh = RefreshInterfaceOptions
    interfaceOptionsPanel:Hide()
    InterfaceOptions_AddCategory(interfaceOptionsPanel)
end

RegisterInterfaceOptions()

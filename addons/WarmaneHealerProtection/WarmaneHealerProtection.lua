local addonName, addon = ...

-- Cache frequently used functions
local getglobal = getglobal
local print = print
local pairs = pairs
local pcall = pcall
local tonumber = tonumber
local type = type
local math_floor = math.floor
local bit_band = bit.band
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
local UnitCanAttack = UnitCanAttack
local UnitDetailedThreatSituation = UnitDetailedThreatSituation
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitHealth = UnitHealth
local UnitIsPlayer = UnitIsPlayer
local UnitIsUnit = UnitIsUnit
local UnitName = UnitName
local UnitThreatSituation = UnitThreatSituation

-- Define color codes
local COLOR = {
    ORANGE = "|cFFFF8000",
    YELLOW = "|cFFFFFF00",
    RED = "|cFFFF0000"
}

local ADDON_PREFIX = "WHP"
local ALERT_MESSAGE = "Healer Protection: I have aggro!"
local DEFAULT_ALERT_DELAY = 15
local MIN_ALERT_DELAY = 5
local MAX_ALERT_DELAY = 120
local CHECK_INTERVAL = 0.5
local RECENT_ATTACK_TTL = 4
local ADDON_FULL_NAME = "WarmaneHealerProtection"
local DEFAULT_ADDON_ENABLED = true
local PARENT_CATEGORY_NAME = "Warmane AddOns"
local PARENT_PANEL_NAME = "WarmaneAddOnsInterfaceOptionsPanel"

local ATTACK_EVENTS = {
    DAMAGE_SHIELD = true,
    DAMAGE_SHIELD_MISSED = true,
    RANGE_DAMAGE = true,
    RANGE_MISSED = true,
    SPELL_DAMAGE = true,
    SPELL_MISSED = true,
    SPELL_PERIODIC_DAMAGE = true,
    SPELL_PERIODIC_MISSED = true,
    SWING_DAMAGE = true,
    SWING_MISSED = true
}

local UNIT_TOKENS = {
    "target",
    "focus",
    "mouseover",
    "pettarget",
    "targettarget",
    "focus-target"
}

local frame = CreateFrame("Frame")
local recentAttackers = {}
local lastAlertAt = -DEFAULT_ALERT_DELAY
local playerGuid = nil
local interfaceOptionsPanel = nil
local interfaceOptionsCheckbox = nil
local delaySlider = nil
local delayValueText = nil
local refreshingInterfaceOptions = false

local RefreshInterfaceOptions

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

-- Create the saved settings table and populate the default delay
local function InitializeSavedData()
    if type(HealerProtectionSettings) ~= "table" then
        HealerProtectionSettings = {}
    end

    if type(HealerProtectionSettings.enabled) ~= "boolean" then
        HealerProtectionSettings.enabled = DEFAULT_ADDON_ENABLED
    end

    local savedDelay = HealerProtectionSettings.alertDelay
    if type(savedDelay) ~= "number" or
        savedDelay < MIN_ALERT_DELAY or
        savedDelay > MAX_ALERT_DELAY or
        savedDelay ~= math_floor(savedDelay) then
        HealerProtectionSettings.alertDelay = DEFAULT_ALERT_DELAY
    end
end

-- Read the current persisted enabled state safely
local function IsAddonEnabled()
    InitializeSavedData()
    return HealerProtectionSettings.enabled
end

-- Persist one validated enabled state
local function SetSavedAddonEnabled(enabled)
    InitializeSavedData()
    HealerProtectionSettings.enabled = enabled and true or false
end

-- Read the current persisted delay safely
local function GetAlertDelay()
    if type(HealerProtectionSettings) ~= "table" then
        return DEFAULT_ALERT_DELAY
    end

    local savedDelay = HealerProtectionSettings.alertDelay
    if type(savedDelay) ~= "number" then
        return DEFAULT_ALERT_DELAY
    end

    return savedDelay
end

-- Persist one validated delay value
local function SetAlertDelay(seconds)
    if type(HealerProtectionSettings) ~= "table" then
        HealerProtectionSettings = {}
    end

    HealerProtectionSettings.alertDelay = seconds
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

-- Build a target token using the formats present in 3.3.5a FrameXML
local function GetTargetToken(unit)
    if unit == "focus" then
        return "focus-target"
    end

    return unit .. "target"
end

-- Return true for visible hostile NPC-style units worth counting as mobs
local function IsHostileMob(unit)
    if type(UnitExists) == "function" and not UnitExists(unit) then
        return false
    end

    if type(UnitCanAttack) == "function" and not UnitCanAttack("player", unit) then
        return false
    end

    if type(UnitIsPlayer) == "function" and UnitIsPlayer(unit) then
        return false
    end

    if type(UnitHealth) == "function" and UnitHealth(unit) <= 0 then
        return false
    end

    return true
end

-- Return whether the visible hostile unit is actually on the player
local function IsMobAttackingPlayer(unit)
    if type(UnitDetailedThreatSituation) == "function" then
        local isTanking, status = UnitDetailedThreatSituation("player", unit)
        if isTanking or status == 3 then
            return true
        end
    end

    if type(UnitThreatSituation) == "function" then
        local status = UnitThreatSituation("player", unit)
        if status == 3 then
            return true
        end
    end

    local targetToken = GetTargetToken(unit)
    if type(UnitExists) == "function" and UnitExists(targetToken) then
        return type(UnitIsUnit) == "function" and UnitIsUnit(targetToken, "player")
    end

    return false
end

-- Add a visible hostile unit once to the unique aggro set
local function AddVisibleAggroMob(unit, seenMobs)
    if not IsHostileMob(unit) or not IsMobAttackingPlayer(unit) then
        return 0
    end

    local guid = type(UnitGUID) == "function" and UnitGUID(unit) or nil
    if not guid then
        return 0
    end

    if seenMobs[guid] then
        return 0
    end

    seenMobs[guid] = true
    return 1
end

-- Count visible party/raid target units where the player is tanking
local function CountVisibleAggroMobs(seenMobs)
    local count = 0

    for _, unit in pairs(UNIT_TOKENS) do
        count = count + AddVisibleAggroMob(unit, seenMobs)
    end

    for i = 1, 4 do
        count = count + AddVisibleAggroMob("party" .. i .. "target", seenMobs)
        count = count + AddVisibleAggroMob("partypet" .. i .. "target", seenMobs)
    end

    if type(GetNumRaidMembers) == "function" and GetNumRaidMembers() > 0 then
        for i = 1, 40 do
            count = count + AddVisibleAggroMob("raid" .. i .. "target", seenMobs)
            count = count + AddVisibleAggroMob("raidpet" .. i .. "target", seenMobs)
        end
    end

    return count
end

-- Drop old combat-log attackers and count the recent ones as active aggro
local function CountRecentAttackers(now, seenMobs)
    local count = 0

    for guid, lastSeenAt in pairs(recentAttackers) do
        if now - lastSeenAt > RECENT_ATTACK_TTL then
            recentAttackers[guid] = nil
        elseif not seenMobs[guid] then
            seenMobs[guid] = true
            count = count + 1
        end
    end

    return count
end

-- Return true when a combat-log source flag belongs to a hostile dungeon mob
local function IsHostileMobSource(sourceFlags)
    if type(sourceFlags) ~= "number" then
        return false
    end

    local reaction = bit_band(sourceFlags, COMBATLOG_OBJECT_REACTION_MASK)
    if reaction ~= COMBATLOG_OBJECT_REACTION_HOSTILE and reaction ~= COMBATLOG_OBJECT_REACTION_NEUTRAL then
        return false
    end

    local sourceType = bit_band(sourceFlags, COMBATLOG_OBJECT_TYPE_MASK)
    return sourceType == COMBATLOG_OBJECT_TYPE_NPC or sourceType == COMBATLOG_OBJECT_TYPE_GUARDIAN
end

-- Store hostile mobs that recently damaged or tried to hit the player
local function HandleCombatLogEvent(...)
    if not playerGuid then
        return
    end

    local _, subevent, sourceGUID, _, sourceFlags, destGUID = ...
    if not ATTACK_EVENTS[subevent] or destGUID ~= playerGuid then
        return
    end

    if sourceGUID and sourceGUID ~= playerGuid and IsHostileMobSource(sourceFlags) then
        recentAttackers[sourceGUID] = GetTime()
    end
end

-- Send the party warning using the same group-channel pattern as WIT
local function SendAggroAlert()
    local channel = GetGroupChatChannel()
    if not channel or type(SendChatMessage) ~= "function" then
        return
    end

    local success = pcall(SendChatMessage, EscapeOutboundChatMessage(ALERT_MESSAGE), channel)
    if not success then
        print(FormatErrorMessage(ADDON_PREFIX, "send healer protection warning"))
    end
end

-- Check all activation conditions and send at most one alert per cooldown
local function CheckAggroAlert()
    if not IsAddonEnabled() then
        return
    end

    local now = GetTime()
    if now - lastAlertAt < GetAlertDelay() then
        return
    end

    if not IsActiveDungeonInstance() or not IsPlayerHealer() then
        return
    end

    local seenMobs = {}
    local aggroMobCount = CountVisibleAggroMobs(seenMobs) + CountRecentAttackers(now, seenMobs)
    if aggroMobCount < 1 then
        return
    end

    SendAggroAlert()
    lastAlertAt = now
end

-- Clear temporary aggro state when the addon should no longer warn
local function ResetAggroState()
    for guid in pairs(recentAttackers) do
        recentAttackers[guid] = nil
    end
end

-- Print slash command help text
local function PrintHelp()
    print(FormatMessage(ADDON_PREFIX, "Available commands:"))
    print("  |cFFFF8000/whp on |cFFFFFF00- Enable healer protection warnings|r")
    print("  |cFFFF8000/whp off |cFFFFFF00- Disable healer protection warnings|r")
    print("  |cFFFF8000/whp help |cFFFFFF00- Show this help|r")
    print("  |cFFFF8000/whp delay |cFFFFFF00- Show the current warning delay|r")
    print("  |cFFFF8000/whp delay <seconds> |cFFFFFF00- Set the warning delay (5-120)|r")
end

-- Print the currently active saved delay
local function PrintDelay()
    print(FormatMessage(ADDON_PREFIX, "Current warning delay", tostring(GetAlertDelay())))
end

-- Parse one integer delay value from slash command input
local function ParseDelayArgument(rawArg)
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

-- Handle /whp delay and /whp delay <seconds>
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

    local seconds = ParseDelayArgument(firstArg)
    if not seconds then
        print(FormatErrorMessage(ADDON_PREFIX,
            "execute command. Invalid argument for 'delay' (expected seconds from 5 to 120)"))
        return
    end

    if seconds < MIN_ALERT_DELAY or seconds > MAX_ALERT_DELAY then
        print(FormatErrorMessage(ADDON_PREFIX,
            "execute command. Invalid argument for 'delay' (expected seconds from 5 to 120)"))
        return
    end

    SetAlertDelay(seconds)
    print(FormatMessage(ADDON_PREFIX, "Warning delay set to", tostring(seconds)))
end

-- Enable or disable healer protection warnings without reloading the UI
local function SetAddonEnabled(enabled)
    local currentlyEnabled = IsAddonEnabled()
    if currentlyEnabled == enabled then
        print(FormatMessage(ADDON_PREFIX, string_format("%s is already %s.", ADDON_FULL_NAME, enabled and "enabled" or "disabled")))
        return
    end

    SetSavedAddonEnabled(enabled)
    lastAlertAt = -GetAlertDelay()
    if not enabled then
        ResetAggroState()
    end
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

-- Register slash command parser following Blizzard pattern
local function RegisterSlashCommands()
    local subcommands = {
        ["on"] = { handler = EnableAddon, args = 0 },
        ["off"] = { handler = DisableAddon, args = 0 },
        ["help"] = { handler = PrintHelp, args = 0 },
        ["delay"] = { handler = HandleDelay }
    }

    SLASH_WHP1 = "/whp"
    SlashCmdList["WHP"] = function(msg)
        local rawMsg = strtrim(msg or "")
        local normalizedMsg = string_lower(rawMsg)

        if normalizedMsg == "" then
            PrintHelp()
            return
        end

        local subcommand = strsplit(" ", normalizedMsg, 2)
        local command = subcommands[subcommand]
        local _, rawArgs = strsplit(" ", rawMsg, 2)
        rawArgs = strtrim(rawArgs or "")

        if not command then
            print(FormatErrorMessage(ADDON_PREFIX, string_format(
                "find subcommand '%s'. Use /whp help to see available commands", subcommand)))
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
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

frame:SetScript("OnUpdate", function(self, elapsed)
    self.timer = (self.timer or 0) + elapsed
    if self.timer < CHECK_INTERVAL then
        return
    end

    self.timer = 0
    CheckAggroAlert()
end)

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        InitializeSavedData()
        RegisterSlashCommands()
        playerGuid = type(UnitGUID) == "function" and UnitGUID("player") or nil
        print(FormatMessage(ADDON_PREFIX, "WarmaneHealerProtection loaded"))
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        playerGuid = type(UnitGUID) == "function" and UnitGUID("player") or nil
        ResetAggroState()
        return
    end

    if event == "ZONE_CHANGED_NEW_AREA" and not IsActiveDungeonInstance() then
        ResetAggroState()
        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if IsAddonEnabled() then
            HandleCombatLogEvent(...)
        end
    end

    CheckAggroAlert()
end)

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
    refreshingInterfaceOptions = true

    if interfaceOptionsCheckbox then
        interfaceOptionsCheckbox:SetChecked(IsAddonEnabled())
    end
    if delaySlider then
        delaySlider:SetValue(GetAlertDelay())
    end
    if delayValueText then
        delayValueText:SetText(GetAlertDelay() .. " sec")
    end

    refreshingInterfaceOptions = false
end

local function RegisterInterfaceOptions()
    local function OpenPanel()
        if interfaceOptionsPanel and type(InterfaceOptionsFrame_OpenToCategory) == "function" then
            InterfaceOptionsFrame_OpenToCategory(interfaceOptionsPanel)
        end
    end

    EnsureWarmaneAddOnsCategory(OpenPanel)

    interfaceOptionsPanel = CreateFrame("Frame", "WHPInterfaceOptionsPanel")
    interfaceOptionsPanel.name = "Healer Protection"
    interfaceOptionsPanel.parent = PARENT_CATEGORY_NAME

    local title = interfaceOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", interfaceOptionsPanel, "TOPLEFT", 16, -16)
    title:SetText("Warmane Healer Protection")

    local header = interfaceOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", interfaceOptionsPanel, "TOPLEFT", 18, -52)
    header:SetText("User settings")

    interfaceOptionsCheckbox = CreateFrame("CheckButton", "WHPInterfaceOptionsEnabled", interfaceOptionsPanel, "InterfaceOptionsCheckButtonTemplate")
    interfaceOptionsCheckbox:SetPoint("TOPLEFT", interfaceOptionsPanel, "TOPLEFT", 14, -76)
    getglobal(interfaceOptionsCheckbox:GetName() .. "Text"):SetText("Enable healer protection warnings")
    interfaceOptionsCheckbox:SetScript("OnClick", function(self)
        SetAddonEnabled(self:GetChecked() and true or false)
    end)

    local delayLabel = interfaceOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    delayLabel:SetPoint("TOPLEFT", interfaceOptionsPanel, "TOPLEFT", 18, -124)
    delayLabel:SetText("Warning delay")

    delaySlider = CreateFrame("Slider", "WHPInterfaceOptionsDelaySlider", interfaceOptionsPanel, "OptionsSliderTemplate")
    delaySlider:SetPoint("TOPLEFT", interfaceOptionsPanel, "TOPLEFT", 128, -122)
    delaySlider:SetWidth(170)
    delaySlider:SetMinMaxValues(MIN_ALERT_DELAY, MAX_ALERT_DELAY)
    delaySlider:SetValueStep(5)
    getglobal(delaySlider:GetName() .. "Low"):SetText(MIN_ALERT_DELAY .. "s")
    getglobal(delaySlider:GetName() .. "High"):SetText(MAX_ALERT_DELAY .. "s")
    delayValueText = interfaceOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    delayValueText:SetPoint("LEFT", delaySlider, "RIGHT", 18, 0)
    delaySlider:SetScript("OnValueChanged", function(self, value)
        local roundedValue = math_floor((value + 2.5) / 5) * 5
        if roundedValue < MIN_ALERT_DELAY then
            roundedValue = MIN_ALERT_DELAY
        elseif roundedValue > MAX_ALERT_DELAY then
            roundedValue = MAX_ALERT_DELAY
        end
        if roundedValue ~= value then
            self:SetValue(roundedValue)
            return
        end
        delayValueText:SetText(roundedValue .. " sec")
        if not refreshingInterfaceOptions then
            SetAlertDelay(roundedValue)
            lastAlertAt = -GetAlertDelay()
            print(FormatMessage(ADDON_PREFIX, "Warning delay set to", tostring(roundedValue)))
        end
    end)

    interfaceOptionsPanel:SetScript("OnShow", RefreshInterfaceOptions)
    interfaceOptionsPanel.refresh = RefreshInterfaceOptions
    interfaceOptionsPanel:Hide()
    InterfaceOptions_AddCategory(interfaceOptionsPanel)
end

RegisterInterfaceOptions()

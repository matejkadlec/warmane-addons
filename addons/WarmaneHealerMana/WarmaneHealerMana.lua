local addonName, addon = ...

-- Cache frequently used functions
local getglobal = getglobal
local print = print
local pcall = pcall
local tonumber = tonumber
local type = type
local math_floor = math.floor
local string_format = string.format
local string_lower = string.lower
local strtrim = strtrim
local strsplit = strsplit
local CreateFrame = CreateFrame
local GetActiveTalentGroup = GetActiveTalentGroup
local GetNumPartyMembers = GetNumPartyMembers
local GetNumRaidMembers = GetNumRaidMembers
local GetTalentTabInfo = GetTalentTabInfo
local GetTime = GetTime
local IsInInstance = IsInInstance
local SendChatMessage = SendChatMessage
local UnitClass = UnitClass
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitName = UnitName
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType

-- Define color codes
local COLOR = {
    ORANGE = "|cFFFF8000",
    YELLOW = "|cFFFFFF00",
    RED = "|cFFFF0000"
}

local ADDON_PREFIX = "WHM"
local ALERT_MESSAGE = "Healer Mana: I'm out of mana!"
local DEFAULT_ALERT_DELAY = 60
local MIN_ALERT_DELAY = 30
local MAX_ALERT_DELAY = 180
local DEFAULT_MANA_THRESHOLD = 10
local MIN_MANA_THRESHOLD = 5
local MAX_MANA_THRESHOLD = 25
local MANA_THRESHOLD_STEP = 5
local CHECK_INTERVAL = 0.5
local ADDON_FULL_NAME = "WarmaneHealerMana"
local DEFAULT_ADDON_ENABLED = true
local AUTO_ACTIVATE_PARTY_SIZES = { 2, 3, 5, 10, 25 }
local DEFAULT_AUTO_ACTIVATE_PARTY_SIZES = {
    [2] = false,
    [3] = false,
    [5] = true,
    [10] = true,
    [25] = true
}
local HEALER_TALENT_TABS = {
    DRUID = { [3] = true },
    PALADIN = { [1] = true },
    PRIEST = { [1] = true, [2] = true },
    SHAMAN = { [3] = true }
}
local PARENT_CATEGORY_NAME = "Warmane AddOns"
local PARENT_PANEL_NAME = "WarmaneAddOnsInterfaceOptionsPanel"

local frame = CreateFrame("Frame")
local lastAlertAt = -DEFAULT_ALERT_DELAY
local interfaceOptionsPanel = nil
local interfaceOptionsCheckbox = nil
local delaySlider = nil
local delayValueText = nil
local thresholdSlider = nil
local thresholdValueText = nil
local interfaceOptionsPartyCheckboxes = {}
local refreshingInterfaceOptions = false

local RefreshInterfaceOptions

-- Start a full warning cooldown from the current moment
local function StartAlertCooldown()
    lastAlertAt = type(GetTime) == "function" and GetTime() or 0
end

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

-- Return whether one mana threshold value matches the supported 5% steps
local function IsValidManaThreshold(threshold)
    return type(threshold) == "number"
        and threshold >= MIN_MANA_THRESHOLD
        and threshold <= MAX_MANA_THRESHOLD
        and threshold == math_floor(threshold)
        and threshold % MANA_THRESHOLD_STEP == 0
end

-- Create the saved settings table and populate validated defaults
local function InitializeSavedData()
    if type(HealerManaSettings) ~= "table" then
        HealerManaSettings = {}
    end

    if type(HealerManaSettings.enabled) ~= "boolean" then
        HealerManaSettings.enabled = DEFAULT_ADDON_ENABLED
    end

    if type(HealerManaSettings.autoActivatePartySizes) ~= "table" then
        HealerManaSettings.autoActivatePartySizes = {}
    end

    for i = 1, #AUTO_ACTIVATE_PARTY_SIZES do
        local partySize = AUTO_ACTIVATE_PARTY_SIZES[i]
        if type(HealerManaSettings.autoActivatePartySizes[partySize]) ~= "boolean" then
            HealerManaSettings.autoActivatePartySizes[partySize] = DEFAULT_AUTO_ACTIVATE_PARTY_SIZES[partySize]
        end
    end

    local savedDelay = HealerManaSettings.alertDelay
    if type(savedDelay) ~= "number" or
        savedDelay < MIN_ALERT_DELAY or
        savedDelay > MAX_ALERT_DELAY or
        savedDelay ~= math_floor(savedDelay) then
        HealerManaSettings.alertDelay = DEFAULT_ALERT_DELAY
    end

    local savedThreshold = HealerManaSettings.manaThreshold
    if not IsValidManaThreshold(savedThreshold) then
        HealerManaSettings.manaThreshold = DEFAULT_MANA_THRESHOLD
    end
end

-- Read the current persisted enabled state safely
local function IsAddonEnabled()
    InitializeSavedData()
    return HealerManaSettings.enabled
end

-- Persist one validated enabled state
local function SetSavedAddonEnabled(enabled)
    InitializeSavedData()
    HealerManaSettings.enabled = enabled and true or false
end

-- Return whether a party size can be configured for auto-activation
local function IsSupportedPartySize(partySize)
    return DEFAULT_AUTO_ACTIVATE_PARTY_SIZES[partySize] ~= nil
end

-- Read one persisted auto-activation party-size toggle safely
local function IsAutoActivatePartySizeEnabled(partySize)
    InitializeSavedData()
    return HealerManaSettings.autoActivatePartySizes[partySize] == true
end

-- Persist one validated auto-activation party-size toggle
local function SetSavedAutoActivatePartySize(partySize, enabled)
    InitializeSavedData()
    HealerManaSettings.autoActivatePartySizes[partySize] = enabled and true or false
end

-- Read the current persisted delay safely
local function GetAlertDelay()
    if type(HealerManaSettings) ~= "table" then
        return DEFAULT_ALERT_DELAY
    end

    local savedDelay = HealerManaSettings.alertDelay
    if type(savedDelay) ~= "number" then
        return DEFAULT_ALERT_DELAY
    end

    return savedDelay
end

-- Persist one validated delay value
local function SetAlertDelay(seconds)
    if type(HealerManaSettings) ~= "table" then
        HealerManaSettings = {}
    end

    HealerManaSettings.alertDelay = seconds
end

-- Read the current persisted mana threshold safely
local function GetManaThreshold()
    if type(HealerManaSettings) ~= "table" then
        return DEFAULT_MANA_THRESHOLD
    end

    local savedThreshold = HealerManaSettings.manaThreshold
    if type(savedThreshold) ~= "number" then
        return DEFAULT_MANA_THRESHOLD
    end

    return savedThreshold
end

-- Persist one validated mana threshold value
local function SetManaThreshold(threshold)
    if type(HealerManaSettings) ~= "table" then
        HealerManaSettings = {}
    end

    HealerManaSettings.manaThreshold = threshold
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

-- Return the current group size using the 3.3.5a party/raid APIs
local function GetCurrentPartySize()
    if type(GetNumRaidMembers) == "function" then
        local raidMembers = GetNumRaidMembers()
        if raidMembers > 0 then
            return raidMembers
        end
    end

    if type(GetNumPartyMembers) == "function" then
        local partyMembers = GetNumPartyMembers()
        if partyMembers > 0 then
            return partyMembers + 1
        end
    end

    if type(UnitName) == "function" and UnitName("party1") then
        return 2
    end

    return 1
end

-- Return true only while the current party or raid instance size is enabled
local function IsActiveGroupInstance()
    if type(IsInInstance) ~= "function" then
        return false
    end

    local success, isInstance, instanceType = pcall(IsInInstance)
    if not success or not isInstance or (instanceType ~= "party" and instanceType ~= "raid") then
        return false
    end

    return IsAutoActivatePartySizeEnabled(GetCurrentPartySize())
end

-- Return true for classes that can reasonably be the healer in manual groups
local function IsPlayerHealerClass()
    if type(UnitClass) ~= "function" then
        return false
    end

    local _, classFileName = UnitClass("player")
    return HEALER_TALENT_TABS[classFileName] ~= nil
end

-- Return healer talent status when the active spec is clear enough to trust
local function IsPlayerUsingHealerTalents()
    if type(UnitClass) ~= "function" or type(GetActiveTalentGroup) ~= "function" or type(GetTalentTabInfo) ~= "function" then
        return nil
    end

    local _, classFileName = UnitClass("player")
    local healerTabs = HEALER_TALENT_TABS[classFileName]
    if not healerTabs then
        return false
    end

    local groupSuccess, talentGroup = pcall(GetActiveTalentGroup, false, false)
    if not groupSuccess or type(talentGroup) ~= "number" then
        return nil
    end

    local highestPoints = 0
    local highestTab = nil
    local hasHealerTie = false

    for i = 1, 3 do
        local tabSuccess, _, _, pointsSpent = pcall(GetTalentTabInfo, i, false, false, talentGroup)
        if tabSuccess and type(pointsSpent) == "number" then
            if pointsSpent > highestPoints then
                highestPoints = pointsSpent
                highestTab = i
                hasHealerTie = healerTabs[i] == true
            elseif pointsSpent == highestPoints and pointsSpent > 0 and healerTabs[i] then
                hasHealerTie = true
            end
        end
    end

    if highestPoints <= 0 then
        return nil
    end

    return healerTabs[highestTab] == true or hasHealerTie
end

-- Return whether the player is assigned or likely acting as a healer
local function IsPlayerHealer()
    if type(UnitGroupRolesAssigned) == "function" then
        local isTank, isHealer, isDamage = UnitGroupRolesAssigned("player")
        if isHealer == true then
            return true
        end
        if isTank == true or isDamage == true then
            return false
        end
    end

    local isHealerTalents = IsPlayerUsingHealerTalents()
    if isHealerTalents ~= nil then
        return isHealerTalents
    end

    return IsPlayerHealerClass()
end

-- Return whether the player currently uses mana and is under the configured threshold
local function IsLowMana()
    if type(UnitPowerType) ~= "function" or type(UnitPower) ~= "function" or type(UnitPowerMax) ~= "function" then
        return false
    end

    local powerType, powerToken = UnitPowerType("player")
    if powerToken ~= "MANA" then
        return false
    end

    local maxMana = UnitPowerMax("player", powerType)
    if type(maxMana) ~= "number" or maxMana <= 0 then
        return false
    end

    local currentMana = UnitPower("player", powerType)
    if type(currentMana) ~= "number" then
        return false
    end

    return currentMana * 100 <= maxMana * GetManaThreshold()
end

-- Send the party warning using the same group-channel pattern as WIT
local function SendLowManaAlert()
    local channel = GetGroupChatChannel()
    if not channel or type(SendChatMessage) ~= "function" then
        return
    end

    local success = pcall(SendChatMessage, EscapeOutboundChatMessage(ALERT_MESSAGE), channel)
    if not success then
        print(FormatErrorMessage(ADDON_PREFIX, "send healer mana warning"))
    end
end

-- Check all activation conditions and send at most one alert per cooldown
local function CheckLowManaAlert()
    if not IsAddonEnabled() then
        return
    end

    local now = GetTime()
    if now - lastAlertAt < GetAlertDelay() then
        return
    end

    if not IsActiveGroupInstance() or not IsPlayerHealer() or not IsLowMana() then
        return
    end

    SendLowManaAlert()
    lastAlertAt = now
end

-- Print slash command help text
local function PrintHelp()
    print(FormatMessage(ADDON_PREFIX, "Available commands:"))
    print("  |cFFFF8000/whm on |cFFFFFF00- Enable healer mana warnings|r")
    print("  |cFFFF8000/whm off |cFFFFFF00- Disable healer mana warnings|r")
    print("  |cFFFF8000/whm party <2|3|5|10|25> <on|off> |cFFFFFF00- Enable/disable auto-activate for a party size|r")
    print("  |cFFFF8000/whm help |cFFFFFF00- Show this help|r")
    print("  |cFFFF8000/whm delay |cFFFFFF00- Show the current warning delay|r")
    print("  |cFFFF8000/whm delay <seconds> |cFFFFFF00- Set the warning delay (30-180)|r")
    print("  |cFFFF8000/whm threshold |cFFFFFF00- Show the current mana threshold|r")
    print("  |cFFFF8000/whm threshold <5|10|15|20|25> |cFFFFFF00- Set the mana threshold percent|r")
end

-- Print the currently active saved delay
local function PrintDelay()
    print(FormatMessage(ADDON_PREFIX, "Current warning delay", tostring(GetAlertDelay())))
end

-- Print the currently active saved mana threshold
local function PrintThreshold()
    print(FormatMessage(ADDON_PREFIX, "Current mana threshold", GetManaThreshold() .. "%"))
end

-- Print the saved auto-activation state for one party size
local function PrintAutoActivatePartySize(partySize, enabled)
    print(FormatMessage(ADDON_PREFIX, string_format("%s%d%s party size auto-activate %s.",
        COLOR.ORANGE, partySize, COLOR.YELLOW, enabled and "on" or "off")))
end

-- Parse one integer value from slash command input
local function ParseIntegerArgument(rawArg)
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

-- Handle /whm delay and /whm delay <seconds>
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

    local seconds = ParseIntegerArgument(firstArg)
    if not seconds then
        print(FormatErrorMessage(ADDON_PREFIX,
            "execute command. Invalid argument for 'delay' (expected seconds from 30 to 180)"))
        return
    end

    if seconds < MIN_ALERT_DELAY or seconds > MAX_ALERT_DELAY then
        print(FormatErrorMessage(ADDON_PREFIX,
            "execute command. Invalid argument for 'delay' (expected seconds from 30 to 180)"))
        return
    end

    SetAlertDelay(seconds)
    print(FormatMessage(ADDON_PREFIX, "Warning delay set to", tostring(seconds)))
end

-- Handle /whm threshold and /whm threshold <5|10|15|20|25>
local function HandleThreshold(args)
    local trimmedArgs = strtrim(args or "")
    if trimmedArgs == "" then
        PrintThreshold()
        return
    end

    local firstArg, extraArg = strsplit(" ", trimmedArgs, 2)
    extraArg = strtrim(extraArg or "")

    if extraArg ~= "" then
        print(FormatErrorMessage(ADDON_PREFIX,
            "execute command. Wrong number of arguments for 'threshold' (expected 1)"))
        return
    end

    local threshold = ParseIntegerArgument(firstArg)
    if not threshold then
        print(FormatErrorMessage(ADDON_PREFIX,
            "execute command. Invalid argument for 'threshold' (expected 5, 10, 15, 20, or 25)"))
        return
    end

    if not IsValidManaThreshold(threshold) then
        print(FormatErrorMessage(ADDON_PREFIX,
            "execute command. Invalid argument for 'threshold' (expected 5, 10, 15, 20, or 25)"))
        return
    end

    SetManaThreshold(threshold)
    print(FormatMessage(ADDON_PREFIX, "Mana threshold set to", threshold .. "%"))
end

-- Enable or disable auto-activation for one supported party size
local function SetAutoActivatePartySize(partySize, enabled)
    SetSavedAutoActivatePartySize(partySize, enabled)
    PrintAutoActivatePartySize(partySize, enabled)

    if RefreshInterfaceOptions then
        RefreshInterfaceOptions()
    end
end

-- Handle /whm party <2|3|5|10|25> <on|off>
local function HandleParty(args)
    local trimmedArgs = strtrim(args or "")
    local sizeArg, remainingArgs = strsplit(" ", trimmedArgs, 2)
    remainingArgs = strtrim(remainingArgs or "")
    local stateArg, extraArg = strsplit(" ", remainingArgs, 2)
    extraArg = strtrim(extraArg or "")

    if trimmedArgs == "" or remainingArgs == "" or extraArg ~= "" then
        print(FormatErrorMessage(ADDON_PREFIX,
            "execute command. Wrong number of arguments for 'party' (expected 2)"))
        return
    end

    local partySize = ParseIntegerArgument(sizeArg)
    if not partySize or not IsSupportedPartySize(partySize) then
        print(FormatErrorMessage(ADDON_PREFIX,
            "execute command. Invalid argument for 'party' (expected party size 2, 3, 5, 10, or 25)"))
        return
    end

    local normalizedState = string_lower(stateArg or "")
    if normalizedState ~= "on" and normalizedState ~= "off" then
        print(FormatErrorMessage(ADDON_PREFIX,
            "execute command. Invalid argument for 'party' (expected on or off)"))
        return
    end

    SetAutoActivatePartySize(partySize, normalizedState == "on")
end

-- Enable or disable healer mana warnings without reloading the UI
local function SetAddonEnabled(enabled)
    local currentlyEnabled = IsAddonEnabled()
    if currentlyEnabled == enabled then
        print(FormatMessage(ADDON_PREFIX, string_format("%s is already %s.", ADDON_FULL_NAME, enabled and "enabled" or "disabled")))
        return
    end

    SetSavedAddonEnabled(enabled)
    if enabled then
        StartAlertCooldown()
    else
        lastAlertAt = -GetAlertDelay()
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

local SUBCOMMANDS = {
    ["on"] = { handler = EnableAddon, args = 0 },
    ["off"] = { handler = DisableAddon, args = 0 },
    ["party"] = { handler = HandleParty, args = 2 },
    ["help"] = { handler = PrintHelp, args = 0 },
    ["delay"] = { handler = HandleDelay, args = 1 },
    ["threshold"] = { handler = HandleThreshold, args = 1 }
}

-- Register slash command parser following Blizzard pattern
local function RegisterSlashCommands()
    SLASH_WHM1 = "/whm"
    SlashCmdList["WHM"] = function(msg)
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
                "find subcommand '%s'. Use /whm help to see available commands", subcommand)))
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
frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
frame:RegisterEvent("RAID_ROSTER_UPDATE")
frame:RegisterEvent("UNIT_DISPLAYPOWER")
frame:RegisterEvent("UNIT_MANA")
frame:RegisterEvent("UNIT_MAXMANA")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

frame:SetScript("OnUpdate", function(self, elapsed)
    self.timer = (self.timer or 0) + elapsed
    if self.timer < CHECK_INTERVAL then
        return
    end

    self.timer = 0
    CheckLowManaAlert()
end)

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        InitializeSavedData()
        RegisterSlashCommands()
        StartAlertCooldown()
        print(FormatMessage(ADDON_PREFIX, "WarmaneHealerMana loaded"))
        return
    end

    if (event == "UNIT_MANA" or event == "UNIT_MAXMANA" or event == "UNIT_DISPLAYPOWER") and ... ~= "player" then
        return
    end

    CheckLowManaAlert()
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
    if thresholdSlider then
        thresholdSlider:SetValue(GetManaThreshold())
    end
    if thresholdValueText then
        thresholdValueText:SetText(GetManaThreshold() .. "%")
    end
    for i = 1, #AUTO_ACTIVATE_PARTY_SIZES do
        local partySize = AUTO_ACTIVATE_PARTY_SIZES[i]
        local checkbox = interfaceOptionsPartyCheckboxes[partySize]
        if checkbox then
            checkbox:SetChecked(IsAutoActivatePartySizeEnabled(partySize))
        end
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

    interfaceOptionsPanel = CreateFrame("Frame", "WHMInterfaceOptionsPanel")
    interfaceOptionsPanel.name = "Healer Mana"
    interfaceOptionsPanel.parent = PARENT_CATEGORY_NAME

    local title = interfaceOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", interfaceOptionsPanel, "TOPLEFT", 16, -16)
    title:SetText("Warmane Healer Mana")

    local header = interfaceOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", interfaceOptionsPanel, "TOPLEFT", 18, -52)
    header:SetText("User settings")

    interfaceOptionsCheckbox = CreateFrame("CheckButton", "WHMInterfaceOptionsEnabled", interfaceOptionsPanel, "InterfaceOptionsCheckButtonTemplate")
    interfaceOptionsCheckbox:SetPoint("TOPLEFT", interfaceOptionsPanel, "TOPLEFT", 14, -76)
    getglobal(interfaceOptionsCheckbox:GetName() .. "Text"):SetText("Enable healer mana warnings")
    interfaceOptionsCheckbox:SetScript("OnClick", function(self)
        SetAddonEnabled(self:GetChecked() and true or false)
    end)

    local delayLabel = interfaceOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    delayLabel:SetPoint("TOPLEFT", interfaceOptionsPanel, "TOPLEFT", 18, -124)
    delayLabel:SetText("Warning delay")

    delaySlider = CreateFrame("Slider", "WHMInterfaceOptionsDelaySlider", interfaceOptionsPanel, "OptionsSliderTemplate")
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

    local thresholdLabel = interfaceOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    thresholdLabel:SetPoint("TOPLEFT", interfaceOptionsPanel, "TOPLEFT", 18, -174)
    thresholdLabel:SetText("Mana threshold")

    thresholdSlider = CreateFrame("Slider", "WHMInterfaceOptionsThresholdSlider", interfaceOptionsPanel, "OptionsSliderTemplate")
    thresholdSlider:SetPoint("TOPLEFT", interfaceOptionsPanel, "TOPLEFT", 128, -172)
    thresholdSlider:SetWidth(170)
    thresholdSlider:SetMinMaxValues(MIN_MANA_THRESHOLD, MAX_MANA_THRESHOLD)
    thresholdSlider:SetValueStep(MANA_THRESHOLD_STEP)
    getglobal(thresholdSlider:GetName() .. "Low"):SetText(MIN_MANA_THRESHOLD .. "%")
    getglobal(thresholdSlider:GetName() .. "High"):SetText(MAX_MANA_THRESHOLD .. "%")
    thresholdValueText = interfaceOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    thresholdValueText:SetPoint("LEFT", thresholdSlider, "RIGHT", 18, 0)
    thresholdSlider:SetScript("OnValueChanged", function(self, value)
        local roundedValue = math_floor((value + (MANA_THRESHOLD_STEP / 2)) / MANA_THRESHOLD_STEP) * MANA_THRESHOLD_STEP
        if roundedValue < MIN_MANA_THRESHOLD then
            roundedValue = MIN_MANA_THRESHOLD
        elseif roundedValue > MAX_MANA_THRESHOLD then
            roundedValue = MAX_MANA_THRESHOLD
        end
        if roundedValue ~= value then
            self:SetValue(roundedValue)
            return
        end
        thresholdValueText:SetText(roundedValue .. "%")
        if not refreshingInterfaceOptions then
            SetManaThreshold(roundedValue)
            print(FormatMessage(ADDON_PREFIX, "Mana threshold set to", roundedValue .. "%"))
        end
    end)

    local autoActivateHeader = interfaceOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    autoActivateHeader:SetPoint("TOPLEFT", interfaceOptionsPanel, "TOPLEFT", 18, -224)
    autoActivateHeader:SetText("Auto-Activate On:")

    for i = 1, #AUTO_ACTIVATE_PARTY_SIZES do
        local partySize = AUTO_ACTIVATE_PARTY_SIZES[i]
        local checkbox = CreateFrame("CheckButton", "WHMInterfaceOptionsPartySize" .. partySize, interfaceOptionsPanel, "InterfaceOptionsCheckButtonTemplate")
        checkbox.partySize = partySize
        checkbox:SetPoint("TOPLEFT", interfaceOptionsPanel, "TOPLEFT", 14, -238 - ((i - 1) * 24))
        getglobal(checkbox:GetName() .. "Text"):SetText(partySize .. " Player Group")
        checkbox:SetScript("OnClick", function(self)
            if not refreshingInterfaceOptions then
                SetAutoActivatePartySize(self.partySize, self:GetChecked() and true or false)
            end
        end)
        interfaceOptionsPartyCheckboxes[partySize] = checkbox
    end

    interfaceOptionsPanel:SetScript("OnShow", RefreshInterfaceOptions)
    interfaceOptionsPanel.refresh = RefreshInterfaceOptions
    interfaceOptionsPanel:Hide()
    InterfaceOptions_AddCategory(interfaceOptionsPanel)
end

RegisterInterfaceOptions()

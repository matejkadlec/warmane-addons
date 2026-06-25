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
local string_gsub = string.gsub
local string_lower = string.lower
local string_sub = string.sub
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
local UnitCanAttack = UnitCanAttack
local UnitClassification = UnitClassification
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
local OLD_DEFAULT_ALERT_DELAY = 15
local DEFAULT_ALERT_DELAY = 60
local DEFAULT_OUTSIDE_ALERT_DELAY = 30
local MIN_ALERT_DELAY = 5
local MAX_ALERT_DELAY = 120
local CHECK_INTERVAL = 0.5
local RECENT_ATTACK_TTL = 4
local DEFAULT_MIN_NON_BOSS_AGGRO_MOBS = 3
local DEFAULT_MIN_BOSS_AGGRO_MOBS = 1
local DEFAULT_OUTSIDE_MIN_NON_BOSS_AGGRO_MOBS = 1
local DEFAULT_OUTSIDE_MIN_BOSS_AGGRO_MOBS = 1
local MIN_NON_BOSS_AGGRO_MOB_OPTIONS = { 1, 2, 3, 5, 10 }
local MIN_BOSS_AGGRO_MOB_OPTIONS = { 1, 2, 3 }
local ADDON_FULL_NAME = "WarmaneHealerProtection"
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

local DIRECT_ATTACK_EVENTS = {
    RANGE_DAMAGE = true,
    RANGE_MISSED = true,
    SWING_DAMAGE = true,
    SWING_MISSED = true
}

-- Dungeon boss NPC IDs from DBM classic/TBC/WotLK party modules for non-elite boss detection
local KNOWN_DUNGEON_BOSS_NPC_IDS = {
    [639] = true, [642] = true, [643] = true, [644] = true, [645] = true, [646] = true, [647] = true, [1663] = true,
    [1666] = true, [1696] = true, [1716] = true, [1717] = true, [1720] = true, [1763] = true, [1853] = true, [2748] = true,
    [3586] = true, [3653] = true, [3654] = true, [3669] = true, [3670] = true, [3671] = true, [3673] = true, [3674] = true,
    [3872] = true, [3886] = true, [3887] = true, [3914] = true, [3927] = true, [3974] = true, [3975] = true, [3976] = true,
    [3977] = true, [3983] = true, [4274] = true, [4275] = true, [4278] = true, [4279] = true, [4420] = true, [4421] = true,
    [4422] = true, [4424] = true, [4425] = true, [4428] = true, [4542] = true, [4543] = true, [4829] = true, [4830] = true,
    [4831] = true, [4832] = true, [4842] = true, [4854] = true, [4887] = true, [5709] = true, [5710] = true, [5719] = true,
    [5720] = true, [5721] = true, [5722] = true, [5775] = true, [5912] = true, [6168] = true, [6229] = true, [6235] = true,
    [6243] = true, [6487] = true, [6906] = true, [6907] = true, [6908] = true, [6910] = true, [7023] = true, [7079] = true,
    [7206] = true, [7228] = true, [7267] = true, [7271] = true, [7272] = true, [7273] = true, [7275] = true, [7291] = true,
    [7354] = true, [7355] = true, [7356] = true, [7357] = true, [7358] = true, [7361] = true, [7795] = true, [7796] = true,
    [7800] = true, [8127] = true, [8443] = true, [8567] = true, [8983] = true, [9016] = true, [9017] = true, [9018] = true,
    [9019] = true, [9024] = true, [9025] = true, [9027] = true, [9028] = true, [9029] = true, [9030] = true, [9031] = true,
    [9032] = true, [9033] = true, [9034] = true, [9035] = true, [9036] = true, [9037] = true, [9038] = true, [9039] = true,
    [9040] = true, [9041] = true, [9056] = true, [9156] = true, [9196] = true, [9236] = true, [9237] = true, [9319] = true,
    [9499] = true, [9502] = true, [9537] = true, [9568] = true, [9736] = true, [9816] = true, [9938] = true, [10220] = true,
    [10264] = true, [10268] = true, [10339] = true, [10363] = true, [10429] = true, [10430] = true, [10432] = true, [10433] = true,
    [10435] = true, [10436] = true, [10437] = true, [10438] = true, [10439] = true, [10502] = true, [10503] = true, [10504] = true,
    [10505] = true, [10506] = true, [10507] = true, [10508] = true, [10509] = true, [10516] = true, [10558] = true, [10584] = true,
    [10596] = true, [10808] = true, [10811] = true, [10812] = true, [10813] = true, [10899] = true, [10901] = true, [10997] = true,
    [11032] = true, [11143] = true, [11261] = true, [11486] = true, [11487] = true, [11488] = true, [11489] = true, [11490] = true,
    [11492] = true, [11496] = true, [11501] = true, [11517] = true, [11518] = true, [11519] = true, [11520] = true, [11622] = true,
    [12201] = true, [12203] = true, [12225] = true, [12236] = true, [12258] = true, [13280] = true, [13282] = true, [13596] = true,
    [13601] = true, [14321] = true, [14322] = true, [14323] = true, [14324] = true, [14325] = true, [14326] = true, [14327] = true,
    [16042] = true, [16807] = true, [16808] = true, [16809] = true, [17306] = true, [17307] = true, [17308] = true, [17377] = true,
    [17380] = true, [17381] = true, [17537] = true, [17770] = true, [17796] = true, [17797] = true, [17798] = true, [17826] = true,
    [17848] = true, [17862] = true, [17879] = true, [17880] = true, [17881] = true, [17882] = true, [17941] = true, [17942] = true,
    [17975] = true, [17976] = true, [17977] = true, [17978] = true, [17980] = true, [17991] = true, [18096] = true, [18105] = true,
    [18341] = true, [18343] = true, [18344] = true, [18371] = true, [18373] = true, [18472] = true, [18473] = true, [18667] = true,
    [18708] = true, [18731] = true, [18732] = true, [19218] = true, [19219] = true, [19220] = true, [19221] = true, [19710] = true,
    [20870] = true, [20885] = true, [20886] = true, [20912] = true, [20923] = true, [22930] = true, [23035] = true, [23953] = true,
    [23954] = true, [24200] = true, [24201] = true, [24560] = true, [24664] = true, [24723] = true, [24744] = true, [26529] = true,
    [26530] = true, [26532] = true, [26533] = true, [26630] = true, [26631] = true, [26632] = true, [26668] = true, [26687] = true,
    [26693] = true, [26723] = true, [26731] = true, [26763] = true, [26794] = true, [26796] = true, [26798] = true, [26861] = true,
    [27447] = true, [27483] = true, [27654] = true, [27655] = true, [27656] = true, [27975] = true, [27977] = true, [27978] = true,
    [28070] = true, [28546] = true, [28586] = true, [28587] = true, [28684] = true, [28921] = true, [28923] = true, [29120] = true,
    [29266] = true, [29304] = true, [29305] = true, [29306] = true, [29307] = true, [29308] = true, [29309] = true, [29310] = true,
    [29311] = true, [29312] = true, [29313] = true, [29314] = true, [29315] = true, [29316] = true, [29932] = true, [30258] = true,
    [31134] = true, [34657] = true, [34701] = true, [34702] = true, [34703] = true, [34705] = true, [34928] = true, [35119] = true,
    [35451] = true, [35569] = true, [35570] = true, [35571] = true, [35572] = true, [35617] = true, [36476] = true, [36494] = true,
    [36497] = true, [36502] = true, [36658] = true, [36661] = true, [38112] = true, [38113] = true
}

local BOSS_UNIT_TOKENS = {
    "boss1",
    "boss2",
    "boss3",
    "boss4"
}

local UNIT_TOKENS = {
    "target",
    "focus",
    "mouseover",
    "pettarget",
    "targettarget",
    "focus-target",
    "boss1",
    "boss2",
    "boss3",
    "boss4"
}

local frame = CreateFrame("Frame")
local recentAttackers = {}
local lastAlertAt = -DEFAULT_ALERT_DELAY
local playerGuid = nil
local interfaceOptionsPanel = nil
local interfaceOptionsCheckbox = nil
local insideInstancesCheckbox = nil
local outsideInstancesCheckbox = nil
local delaySlider = nil
local delayValueText = nil
local outsideDelaySlider = nil
local outsideDelayValueText = nil
local minNonBossDropdown = nil
local minBossDropdown = nil
local outsideMinNonBossDropdown = nil
local outsideMinBossDropdown = nil
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

-- Return whether a numeric value is one of the supported dropdown choices
local function IsValueInOptions(value, options)
    if type(value) ~= "number" or value ~= math_floor(value) then
        return false
    end

    for i = 1, #options do
        if options[i] == value then
            return true
        end
    end

    return false
end

-- Return whether one non-boss aggro threshold is supported
local function IsValidMinNonBossAggroMobs(value)
    return IsValueInOptions(value, MIN_NON_BOSS_AGGRO_MOB_OPTIONS)
end

-- Return whether one boss aggro threshold is supported
local function IsValidMinBossAggroMobs(value)
    return IsValueInOptions(value, MIN_BOSS_AGGRO_MOB_OPTIONS)
end

-- Create the saved settings table and populate validated defaults
local function InitializeSavedData()
    if type(HealerProtectionSettings) ~= "table" then
        HealerProtectionSettings = {}
    end

    if type(HealerProtectionSettings.enabled) ~= "boolean" then
        HealerProtectionSettings.enabled = DEFAULT_ADDON_ENABLED
    end

    if type(HealerProtectionSettings.enabledInsideInstances) ~= "boolean" then
        HealerProtectionSettings.enabledInsideInstances = HealerProtectionSettings.enabled == true
    end

    if type(HealerProtectionSettings.enabledOutsideInstances) ~= "boolean" then
        HealerProtectionSettings.enabledOutsideInstances = HealerProtectionSettings.enabled == true
    end

    if HealerProtectionSettings.enabled ~= true then
        HealerProtectionSettings.enabledInsideInstances = false
        HealerProtectionSettings.enabledOutsideInstances = false
    elseif not HealerProtectionSettings.enabledInsideInstances and not HealerProtectionSettings.enabledOutsideInstances then
        HealerProtectionSettings.enabled = false
    end

    if type(HealerProtectionSettings.autoActivatePartySizes) ~= "table" then
        HealerProtectionSettings.autoActivatePartySizes = {}
    end

    for i = 1, #AUTO_ACTIVATE_PARTY_SIZES do
        local partySize = AUTO_ACTIVATE_PARTY_SIZES[i]
        if type(HealerProtectionSettings.autoActivatePartySizes[partySize]) ~= "boolean" then
            HealerProtectionSettings.autoActivatePartySizes[partySize] = DEFAULT_AUTO_ACTIVATE_PARTY_SIZES[partySize]
        end
    end

    local savedDelay = HealerProtectionSettings.alertDelay
    if type(savedDelay) ~= "number" or
        savedDelay < MIN_ALERT_DELAY or
        savedDelay > MAX_ALERT_DELAY or
        savedDelay ~= math_floor(savedDelay) or
        savedDelay == OLD_DEFAULT_ALERT_DELAY then
        HealerProtectionSettings.alertDelay = DEFAULT_ALERT_DELAY
    end

    local savedOutsideDelay = HealerProtectionSettings.outsideAlertDelay
    if type(savedOutsideDelay) ~= "number" or
        savedOutsideDelay < MIN_ALERT_DELAY or
        savedOutsideDelay > MAX_ALERT_DELAY or
        savedOutsideDelay ~= math_floor(savedOutsideDelay) then
        HealerProtectionSettings.outsideAlertDelay = DEFAULT_OUTSIDE_ALERT_DELAY
    end

    if not IsValidMinNonBossAggroMobs(HealerProtectionSettings.minNonBossAggroMobs) then
        HealerProtectionSettings.minNonBossAggroMobs = DEFAULT_MIN_NON_BOSS_AGGRO_MOBS
    end

    if not IsValidMinBossAggroMobs(HealerProtectionSettings.minBossAggroMobs) then
        HealerProtectionSettings.minBossAggroMobs = DEFAULT_MIN_BOSS_AGGRO_MOBS
    end

    if not IsValidMinNonBossAggroMobs(HealerProtectionSettings.outsideMinNonBossAggroMobs) then
        HealerProtectionSettings.outsideMinNonBossAggroMobs = DEFAULT_OUTSIDE_MIN_NON_BOSS_AGGRO_MOBS
    end

    if not IsValidMinBossAggroMobs(HealerProtectionSettings.outsideMinBossAggroMobs) then
        HealerProtectionSettings.outsideMinBossAggroMobs = DEFAULT_OUTSIDE_MIN_BOSS_AGGRO_MOBS
    end
end

-- Read the current persisted enabled state safely
local function IsAddonEnabled()
    InitializeSavedData()
    return HealerProtectionSettings.enabled
end

-- Persist one validated enabled state
local function SetSavedAddonEnabled(enabled, syncLocations)
    InitializeSavedData()
    HealerProtectionSettings.enabled = enabled and true or false
    if syncLocations ~= false then
        HealerProtectionSettings.enabledInsideInstances = HealerProtectionSettings.enabled
        HealerProtectionSettings.enabledOutsideInstances = HealerProtectionSettings.enabled
    end
end

-- Read whether warnings are enabled inside party or raid instances
local function IsInsideInstancesEnabled()
    InitializeSavedData()
    return HealerProtectionSettings.enabledInsideInstances == true
end

-- Read whether warnings are enabled while grouped outside instances
local function IsOutsideInstancesEnabled()
    InitializeSavedData()
    return HealerProtectionSettings.enabledOutsideInstances == true
end

-- Persist one child location toggle and keep the parent enabled state consistent
local function SetSavedLocationEnabled(location, enabled)
    InitializeSavedData()

    if location == "inside" then
        HealerProtectionSettings.enabledInsideInstances = enabled and true or false
    elseif location == "outside" then
        HealerProtectionSettings.enabledOutsideInstances = enabled and true or false
    end

    if HealerProtectionSettings.enabledInsideInstances or HealerProtectionSettings.enabledOutsideInstances then
        SetSavedAddonEnabled(true, false)
    else
        SetSavedAddonEnabled(false, false)
    end
end

-- Read one persisted auto-activation party-size toggle safely
local function IsAutoActivatePartySizeEnabled(partySize)
    InitializeSavedData()
    return HealerProtectionSettings.autoActivatePartySizes[partySize] == true
end

-- Persist one validated auto-activation party-size toggle
local function SetSavedAutoActivatePartySize(partySize, enabled)
    InitializeSavedData()
    HealerProtectionSettings.autoActivatePartySizes[partySize] = enabled and true or false
end

-- Read the current persisted delay safely for one location
local function GetAlertDelay(location)
    if type(HealerProtectionSettings) ~= "table" then
        return location == "outside" and DEFAULT_OUTSIDE_ALERT_DELAY or DEFAULT_ALERT_DELAY
    end

    local savedDelay
    if location == "outside" then
        savedDelay = HealerProtectionSettings.outsideAlertDelay
    else
        savedDelay = HealerProtectionSettings.alertDelay
    end
    if type(savedDelay) ~= "number" then
        return location == "outside" and DEFAULT_OUTSIDE_ALERT_DELAY or DEFAULT_ALERT_DELAY
    end

    return savedDelay
end

-- Persist one validated delay value for one location
local function SetAlertDelay(seconds, location)
    if type(HealerProtectionSettings) ~= "table" then
        HealerProtectionSettings = {}
    end

    if location == "outside" then
        HealerProtectionSettings.outsideAlertDelay = seconds
    else
        HealerProtectionSettings.alertDelay = seconds
    end
end

-- Read the current persisted non-boss aggro threshold safely for one location
local function GetMinNonBossAggroMobs(location)
    if type(HealerProtectionSettings) ~= "table" then
        return location == "outside" and DEFAULT_OUTSIDE_MIN_NON_BOSS_AGGRO_MOBS or DEFAULT_MIN_NON_BOSS_AGGRO_MOBS
    end

    local savedValue
    if location == "outside" then
        savedValue = HealerProtectionSettings.outsideMinNonBossAggroMobs
    else
        savedValue = HealerProtectionSettings.minNonBossAggroMobs
    end
    if not IsValidMinNonBossAggroMobs(savedValue) then
        return location == "outside" and DEFAULT_OUTSIDE_MIN_NON_BOSS_AGGRO_MOBS or DEFAULT_MIN_NON_BOSS_AGGRO_MOBS
    end

    return savedValue
end

-- Persist one validated non-boss aggro threshold for one location
local function SetMinNonBossAggroMobs(value, location)
    if type(HealerProtectionSettings) ~= "table" then
        HealerProtectionSettings = {}
    end

    if location == "outside" then
        HealerProtectionSettings.outsideMinNonBossAggroMobs = value
    else
        HealerProtectionSettings.minNonBossAggroMobs = value
    end
end

-- Read the current persisted boss aggro threshold safely for one location
local function GetMinBossAggroMobs(location)
    if type(HealerProtectionSettings) ~= "table" then
        return location == "outside" and DEFAULT_OUTSIDE_MIN_BOSS_AGGRO_MOBS or DEFAULT_MIN_BOSS_AGGRO_MOBS
    end

    local savedValue
    if location == "outside" then
        savedValue = HealerProtectionSettings.outsideMinBossAggroMobs
    else
        savedValue = HealerProtectionSettings.minBossAggroMobs
    end
    if not IsValidMinBossAggroMobs(savedValue) then
        return location == "outside" and DEFAULT_OUTSIDE_MIN_BOSS_AGGRO_MOBS or DEFAULT_MIN_BOSS_AGGRO_MOBS
    end

    return savedValue
end

-- Persist one validated boss aggro threshold for one location
local function SetMinBossAggroMobs(value, location)
    if type(HealerProtectionSettings) ~= "table" then
        HealerProtectionSettings = {}
    end

    if location == "outside" then
        HealerProtectionSettings.outsideMinBossAggroMobs = value
    else
        HealerProtectionSettings.minBossAggroMobs = value
    end
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

-- Return the enabled location name while the current grouped location and party size are enabled
local function GetEnabledGroupedLocation()
    if type(IsInInstance) ~= "function" then
        return nil
    end

    local success, isInstance, instanceType = pcall(IsInInstance)
    if not success then
        return nil
    end

    if not IsAutoActivatePartySizeEnabled(GetCurrentPartySize()) then
        return nil
    end

    if isInstance and (instanceType == "party" or instanceType == "raid") then
        return IsInsideInstancesEnabled() and "inside" or nil
    end

    if not isInstance then
        return IsOutsideInstancesEnabled() and "outside" or nil
    end

    return nil
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

-- Build a target token using the formats present in 3.3.5a FrameXML
local function GetTargetToken(unit)
    if unit == "focus" then
        return "focus-target"
    end

    return unit .. "target"
end

-- Normalize GUID format so 3.3.5 NPC ID parsing works with or without 0x
local function NormalizeGuid(guid)
    if type(guid) ~= "string" or guid == "" then
        return nil
    end

    local normalized = string_gsub(guid, "^0[xX]", "")
    if #normalized < 10 then
        return nil
    end

    return normalized
end

-- Extract the NPC entry ID from a 3.3.5 creature GUID
local function GetNPCId(guid)
    local normalized = NormalizeGuid(guid)
    if not normalized then
        return nil
    end

    local npcHex = string_sub(normalized, 7, 10)
    if not npcHex or #npcHex < 4 then
        return nil
    end

    local npcId = tonumber(npcHex, 16)
    if not npcId or npcId <= 0 then
        return nil
    end

    return npcId
end

-- Return whether a GUID belongs to a known dungeon boss NPC
local function IsKnownDungeonBossGUID(guid)
    local npcId = GetNPCId(guid)
    return npcId and KNOWN_DUNGEON_BOSS_NPC_IDS[npcId] == true
end

-- Return whether a visible unit is one of the boss unit frames
local function IsBossUnitToken(unit)
    if type(UnitExists) ~= "function" or type(UnitIsUnit) ~= "function" then
        return false
    end

    for i = 1, #BOSS_UNIT_TOKENS do
        local bossUnit = BOSS_UNIT_TOKENS[i]
        if UnitExists(bossUnit) and UnitIsUnit(unit, bossUnit) then
            return true
        end
    end

    return false
end

-- Return whether a visible unit has the explicit boss classification
local function IsWorldBossUnit(unit)
    if type(UnitClassification) ~= "function" then
        return false
    end

    local success, classification = pcall(UnitClassification, unit)
    return success and classification == "worldboss"
end

-- Return whether a visible hostile unit should use the boss threshold
local function IsBossMob(unit)
    local guid = type(UnitGUID) == "function" and UnitGUID(unit) or nil
    return IsKnownDungeonBossGUID(guid) or IsBossUnitToken(unit) or IsWorldBossUnit(unit)
end

-- Return whether a combat-log GUID currently matches a visible boss unit
local function IsVisibleBossGUID(guid)
    if type(guid) ~= "string" or guid == "" or type(UnitGUID) ~= "function" then
        return false
    end

    for i = 1, #BOSS_UNIT_TOKENS do
        local bossUnit = BOSS_UNIT_TOKENS[i]
        if type(UnitExists) ~= "function" or UnitExists(bossUnit) then
            if UnitGUID(bossUnit) == guid then
                return true
            end
        end
    end

    return false
end

-- Return whether a combat-log source should use the boss threshold
local function IsBossMobGUID(guid)
    return IsKnownDungeonBossGUID(guid) or IsVisibleBossGUID(guid)
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
        return 0, 0
    end

    local guid = type(UnitGUID) == "function" and UnitGUID(unit) or nil
    if not guid then
        return 0, 0
    end

    if seenMobs[guid] then
        return 0, 0
    end

    seenMobs[guid] = true
    if IsBossMob(unit) then
        return 0, 1
    end

    return 1, 0
end

-- Count visible party/raid target units where the player is tanking
local function CountVisibleAggroMobs(seenMobs)
    local nonBossCount = 0
    local bossCount = 0

    for _, unit in pairs(UNIT_TOKENS) do
        local addedNonBoss, addedBoss = AddVisibleAggroMob(unit, seenMobs)
        nonBossCount = nonBossCount + addedNonBoss
        bossCount = bossCount + addedBoss
    end

    for i = 1, 4 do
        local addedNonBoss, addedBoss = AddVisibleAggroMob("party" .. i .. "target", seenMobs)
        nonBossCount = nonBossCount + addedNonBoss
        bossCount = bossCount + addedBoss

        addedNonBoss, addedBoss = AddVisibleAggroMob("partypet" .. i .. "target", seenMobs)
        nonBossCount = nonBossCount + addedNonBoss
        bossCount = bossCount + addedBoss
    end

    if type(GetNumRaidMembers) == "function" and GetNumRaidMembers() > 0 then
        for i = 1, 40 do
            local addedNonBoss, addedBoss = AddVisibleAggroMob("raid" .. i .. "target", seenMobs)
            nonBossCount = nonBossCount + addedNonBoss
            bossCount = bossCount + addedBoss

            addedNonBoss, addedBoss = AddVisibleAggroMob("raidpet" .. i .. "target", seenMobs)
            nonBossCount = nonBossCount + addedNonBoss
            bossCount = bossCount + addedBoss
        end
    end

    return nonBossCount, bossCount
end

-- Drop old combat-log attackers and count the recent ones as active aggro
local function CountRecentAttackers(now, seenMobs)
    local nonBossCount = 0
    local bossCount = 0

    for guid, attackerData in pairs(recentAttackers) do
        local lastSeenAt = type(attackerData) == "table" and attackerData.lastSeenAt or attackerData
        if type(lastSeenAt) ~= "number" then
            recentAttackers[guid] = nil
        elseif now - lastSeenAt > RECENT_ATTACK_TTL then
            recentAttackers[guid] = nil
        elseif not seenMobs[guid] then
            seenMobs[guid] = true
            local isBoss = type(attackerData) == "table" and attackerData.isBoss == true
            isBoss = isBoss or IsBossMobGUID(guid)
            if isBoss then
                bossCount = bossCount + 1
            else
                nonBossCount = nonBossCount + 1
            end
        end
    end

    return nonBossCount, bossCount
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
    if not DIRECT_ATTACK_EVENTS[subevent] or destGUID ~= playerGuid then
        return
    end

    if sourceGUID and sourceGUID ~= playerGuid and IsHostileMobSource(sourceFlags) then
        recentAttackers[sourceGUID] = {
            lastSeenAt = GetTime(),
            isBoss = IsBossMobGUID(sourceGUID)
        }
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

    local location = GetEnabledGroupedLocation()
    if not location or not IsPlayerHealer() then
        return
    end

    local now = GetTime()
    if now - lastAlertAt < GetAlertDelay(location) then
        return
    end

    local seenMobs = {}
    local nonBossAggroCount, bossAggroCount = CountVisibleAggroMobs(seenMobs)
    local recentNonBossCount, recentBossCount = CountRecentAttackers(now, seenMobs)
    nonBossAggroCount = nonBossAggroCount + recentNonBossCount
    bossAggroCount = bossAggroCount + recentBossCount

    if nonBossAggroCount < GetMinNonBossAggroMobs(location) and bossAggroCount < GetMinBossAggroMobs(location) then
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
    print("  |cFFFF8000/whp |cFFFFFF00- Show this help|r")
    print("  |cFFFF8000/whp on |cFFFFFF00- Enable healer protection warnings|r")
    print("  |cFFFF8000/whp off |cFFFFFF00- Disable healer protection warnings|r")
    print("  |cFFFF8000/whp help |cFFFFFF00- Show this help|r")
end

-- Persist one non-boss aggro threshold from the settings UI
local function UpdateMinNonBossAggroMobs(value, location)
    SetMinNonBossAggroMobs(value, location)

    if RefreshInterfaceOptions then
        RefreshInterfaceOptions()
    end
end

-- Persist one boss aggro threshold from the settings UI
local function UpdateMinBossAggroMobs(value, location)
    SetMinBossAggroMobs(value, location)

    if RefreshInterfaceOptions then
        RefreshInterfaceOptions()
    end
end

-- Enable or disable auto-activation for one supported party size
local function SetAutoActivatePartySize(partySize, enabled)
    SetSavedAutoActivatePartySize(partySize, enabled)
    if not enabled and GetCurrentPartySize() == partySize then
        ResetAggroState()
    end

    if RefreshInterfaceOptions then
        RefreshInterfaceOptions()
    end
end

-- Enable or disable healer protection warnings without reloading the UI
local function SetAddonEnabled(enabled)
    local currentlyEnabled = IsAddonEnabled()
    local fullyEnabled = currentlyEnabled and IsInsideInstancesEnabled() and IsOutsideInstancesEnabled()
    local fullyDisabled = not currentlyEnabled and not IsInsideInstancesEnabled() and not IsOutsideInstancesEnabled()
    if (enabled and fullyEnabled) or (not enabled and fullyDisabled) then
        print(FormatMessage(ADDON_PREFIX, string_format("%s is already %s.", ADDON_FULL_NAME, enabled and "enabled" or "disabled")))
        return
    end

    SetSavedAddonEnabled(enabled, true)
    if enabled then
        StartAlertCooldown()
    else
        lastAlertAt = -GetAlertDelay("inside")
    end
    if not enabled then
        ResetAggroState()
    end
    print(FormatMessage(ADDON_PREFIX, string_format("%s %s.", ADDON_FULL_NAME, enabled and "enabled" or "disabled")))

    if RefreshInterfaceOptions then
        RefreshInterfaceOptions()
    end
end

-- Toggle one child location setting from the options UI
local function SetLocationEnabled(location, enabled)
    SetSavedLocationEnabled(location, enabled)
    if IsAddonEnabled() then
        StartAlertCooldown()
    else
        lastAlertAt = -GetAlertDelay("inside")
        ResetAggroState()
    end

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
    ["help"] = { handler = PrintHelp, args = 0 },
}

-- Register slash command parser following Blizzard pattern
local function RegisterSlashCommands()
    SLASH_WHP1 = "/whp"
    SlashCmdList["WHP"] = function(msg)
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
frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("RAID_ROSTER_UPDATE")
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
        StartAlertCooldown()
        print(FormatMessage(ADDON_PREFIX, "WarmaneHealerProtection loaded"))
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        playerGuid = type(UnitGUID) == "function" and UnitGUID("player") or nil
        ResetAggroState()
        return
    end

    if (event == "ZONE_CHANGED_NEW_AREA" or event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE")
        and not GetEnabledGroupedLocation() then
        ResetAggroState()
        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if IsAddonEnabled() and GetEnabledGroupedLocation() then
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

-- Enable or disable a child checkbox and its smaller label together
local function SetChildCheckboxEnabled(checkbox, enabled)
    if not checkbox then
        return
    end

    local text = getglobal(checkbox:GetName() .. "Text")
    if enabled then
        checkbox:Enable()
        if text then
            text:SetFontObject("GameFontHighlightSmall")
        end
    else
        checkbox:Disable()
        if text then
            text:SetFontObject("GameFontDisableSmall")
        end
    end
end

-- Populate the non-boss aggro threshold dropdown
local function InitializeMinNonBossDropdown()
    local selectedValue = GetMinNonBossAggroMobs("inside")

    for i = 1, #MIN_NON_BOSS_AGGRO_MOB_OPTIONS do
        local value = MIN_NON_BOSS_AGGRO_MOB_OPTIONS[i]
        local info = UIDropDownMenu_CreateInfo()
        info.text = tostring(value)
        info.value = value
        info.checked = selectedValue == value
        info.func = function(self)
            UpdateMinNonBossAggroMobs(self.value, "inside")
        end
        UIDropDownMenu_AddButton(info)
    end
end

-- Populate the boss aggro threshold dropdown
local function InitializeMinBossDropdown()
    local selectedValue = GetMinBossAggroMobs("inside")

    for i = 1, #MIN_BOSS_AGGRO_MOB_OPTIONS do
        local value = MIN_BOSS_AGGRO_MOB_OPTIONS[i]
        local info = UIDropDownMenu_CreateInfo()
        info.text = tostring(value)
        info.value = value
        info.checked = selectedValue == value
        info.func = function(self)
            UpdateMinBossAggroMobs(self.value, "inside")
        end
        UIDropDownMenu_AddButton(info)
    end
end

-- Populate the outside non-boss aggro threshold dropdown
local function InitializeOutsideMinNonBossDropdown()
    local selectedValue = GetMinNonBossAggroMobs("outside")

    for i = 1, #MIN_NON_BOSS_AGGRO_MOB_OPTIONS do
        local value = MIN_NON_BOSS_AGGRO_MOB_OPTIONS[i]
        local info = UIDropDownMenu_CreateInfo()
        info.text = tostring(value)
        info.value = value
        info.checked = selectedValue == value
        info.func = function(self)
            UpdateMinNonBossAggroMobs(self.value, "outside")
        end
        UIDropDownMenu_AddButton(info)
    end
end

-- Populate the outside boss aggro threshold dropdown
local function InitializeOutsideMinBossDropdown()
    local selectedValue = GetMinBossAggroMobs("outside")

    for i = 1, #MIN_BOSS_AGGRO_MOB_OPTIONS do
        local value = MIN_BOSS_AGGRO_MOB_OPTIONS[i]
        local info = UIDropDownMenu_CreateInfo()
        info.text = tostring(value)
        info.value = value
        info.checked = selectedValue == value
        info.func = function(self)
            UpdateMinBossAggroMobs(self.value, "outside")
        end
        UIDropDownMenu_AddButton(info)
    end
end

RefreshInterfaceOptions = function()
    refreshingInterfaceOptions = true

    if interfaceOptionsCheckbox then
        interfaceOptionsCheckbox:SetChecked(IsAddonEnabled())
    end
    if insideInstancesCheckbox then
        insideInstancesCheckbox:SetChecked(IsInsideInstancesEnabled())
        SetChildCheckboxEnabled(insideInstancesCheckbox, IsAddonEnabled())
    end
    if outsideInstancesCheckbox then
        outsideInstancesCheckbox:SetChecked(IsOutsideInstancesEnabled())
        SetChildCheckboxEnabled(outsideInstancesCheckbox, IsAddonEnabled())
    end
    if delaySlider then
        delaySlider:SetValue(GetAlertDelay("inside"))
    end
    if delayValueText then
        delayValueText:SetText(GetAlertDelay("inside") .. " sec")
    end
    if outsideDelaySlider then
        outsideDelaySlider:SetValue(GetAlertDelay("outside"))
    end
    if outsideDelayValueText then
        outsideDelayValueText:SetText(GetAlertDelay("outside") .. " sec")
    end
    if minNonBossDropdown then
        UIDropDownMenu_SetSelectedValue(minNonBossDropdown, GetMinNonBossAggroMobs("inside"))
        UIDropDownMenu_SetText(minNonBossDropdown, tostring(GetMinNonBossAggroMobs("inside")))
    end
    if minBossDropdown then
        UIDropDownMenu_SetSelectedValue(minBossDropdown, GetMinBossAggroMobs("inside"))
        UIDropDownMenu_SetText(minBossDropdown, tostring(GetMinBossAggroMobs("inside")))
    end
    if outsideMinNonBossDropdown then
        UIDropDownMenu_SetSelectedValue(outsideMinNonBossDropdown, GetMinNonBossAggroMobs("outside"))
        UIDropDownMenu_SetText(outsideMinNonBossDropdown, tostring(GetMinNonBossAggroMobs("outside")))
    end
    if outsideMinBossDropdown then
        UIDropDownMenu_SetSelectedValue(outsideMinBossDropdown, GetMinBossAggroMobs("outside"))
        UIDropDownMenu_SetText(outsideMinBossDropdown, tostring(GetMinBossAggroMobs("outside")))
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

    interfaceOptionsPanel = CreateFrame("Frame", "WHPInterfaceOptionsPanel")
    interfaceOptionsPanel.name = "Healer Protection"
    interfaceOptionsPanel.parent = PARENT_CATEGORY_NAME

    local title = interfaceOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", interfaceOptionsPanel, "TOPLEFT", 16, -16)
    title:SetText("Warmane Healer Protection")

    local scrollFrame = CreateFrame("ScrollFrame", "WHPInterfaceOptionsScrollFrame", interfaceOptionsPanel, "UIPanelScrollFrameTemplate")
    scrollFrame.scrollBarHideable = true
    scrollFrame:SetPoint("TOPLEFT", interfaceOptionsPanel, "TOPLEFT", 0, -44)
    scrollFrame:SetPoint("BOTTOMRIGHT", interfaceOptionsPanel, "BOTTOMRIGHT", -28, 16)

    local contentPanel = CreateFrame("Frame", "WHPInterfaceOptionsScrollChild", scrollFrame)
    contentPanel:SetWidth(560)
    contentPanel:SetHeight(640)
    scrollFrame:SetScrollChild(contentPanel)
    if type(ScrollFrame_OnScrollRangeChanged) == "function" then
        ScrollFrame_OnScrollRangeChanged(scrollFrame)
    end

    local header = contentPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalMed3")
    header:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 18, -8)
    header:SetText("User Settings")

    interfaceOptionsCheckbox = CreateFrame("CheckButton", "WHPInterfaceOptionsEnabled", contentPanel, "InterfaceOptionsCheckButtonTemplate")
    interfaceOptionsCheckbox:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 14, -32)
    getglobal(interfaceOptionsCheckbox:GetName() .. "Text"):SetText("Enable Healer Protection Warnings")
    interfaceOptionsCheckbox:SetScript("OnClick", function(self)
        SetAddonEnabled(self:GetChecked() and true or false)
    end)

    insideInstancesCheckbox = CreateFrame("CheckButton", "WHPInterfaceOptionsInsideInstances", contentPanel, "InterfaceOptionsSmallCheckButtonTemplate")
    insideInstancesCheckbox:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 34, -58)
    getglobal(insideInstancesCheckbox:GetName() .. "Text"):SetText("Enable Inside Instances")
    insideInstancesCheckbox:SetScript("OnClick", function(self)
        if not refreshingInterfaceOptions then
            SetLocationEnabled("inside", self:GetChecked() and true or false)
        end
    end)

    outsideInstancesCheckbox = CreateFrame("CheckButton", "WHPInterfaceOptionsOutsideInstances", contentPanel, "InterfaceOptionsSmallCheckButtonTemplate")
    outsideInstancesCheckbox:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 34, -80)
    getglobal(outsideInstancesCheckbox:GetName() .. "Text"):SetText("Enable Outside Instances")
    outsideInstancesCheckbox:SetScript("OnClick", function(self)
        if not refreshingInterfaceOptions then
            SetLocationEnabled("outside", self:GetChecked() and true or false)
        end
    end)

    local insideHeader = contentPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    insideHeader:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 18, -110)
    insideHeader:SetText("Inside Instances")

    local delayLabel = contentPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    delayLabel:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 34, -138)
    delayLabel:SetText("Warning Delay")

    delaySlider = CreateFrame("Slider", "WHPInterfaceOptionsDelaySlider", contentPanel, "OptionsSliderTemplate")
    delaySlider:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 150, -136)
    delaySlider:SetWidth(170)
    delaySlider:SetMinMaxValues(MIN_ALERT_DELAY, MAX_ALERT_DELAY)
    delaySlider:SetValueStep(5)
    getglobal(delaySlider:GetName() .. "Low"):SetText(MIN_ALERT_DELAY .. "s")
    getglobal(delaySlider:GetName() .. "High"):SetText(MAX_ALERT_DELAY .. "s")
    delayValueText = contentPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
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
            SetAlertDelay(roundedValue, "inside")
            lastAlertAt = -GetAlertDelay("inside")
        end
    end)

    local minNonBossLabel = contentPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    minNonBossLabel:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 34, -172)
    minNonBossLabel:SetText("Min count of aggroed non-boss mobs")

    minNonBossDropdown = CreateFrame("Frame", "WHPInterfaceOptionsMinNonBossDropDown", contentPanel, "UIDropDownMenuTemplate")
    minNonBossDropdown:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 270, -164)
    UIDropDownMenu_SetWidth(minNonBossDropdown, 70)
    UIDropDownMenu_Initialize(minNonBossDropdown, InitializeMinNonBossDropdown)

    local minBossLabel = contentPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    minBossLabel:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 34, -206)
    minBossLabel:SetText("Min count of aggroed boss mobs")

    minBossDropdown = CreateFrame("Frame", "WHPInterfaceOptionsMinBossDropDown", contentPanel, "UIDropDownMenuTemplate")
    minBossDropdown:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 270, -198)
    UIDropDownMenu_SetWidth(minBossDropdown, 70)
    UIDropDownMenu_Initialize(minBossDropdown, InitializeMinBossDropdown)

    local outsideHeader = contentPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    outsideHeader:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 18, -248)
    outsideHeader:SetText("Outside Instances")

    local outsideDelayLabel = contentPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    outsideDelayLabel:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 34, -276)
    outsideDelayLabel:SetText("Warning Delay")

    outsideDelaySlider = CreateFrame("Slider", "WHPInterfaceOptionsOutsideDelaySlider", contentPanel, "OptionsSliderTemplate")
    outsideDelaySlider:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 150, -274)
    outsideDelaySlider:SetWidth(170)
    outsideDelaySlider:SetMinMaxValues(MIN_ALERT_DELAY, MAX_ALERT_DELAY)
    outsideDelaySlider:SetValueStep(5)
    getglobal(outsideDelaySlider:GetName() .. "Low"):SetText(MIN_ALERT_DELAY .. "s")
    getglobal(outsideDelaySlider:GetName() .. "High"):SetText(MAX_ALERT_DELAY .. "s")
    outsideDelayValueText = contentPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    outsideDelayValueText:SetPoint("LEFT", outsideDelaySlider, "RIGHT", 18, 0)
    outsideDelaySlider:SetScript("OnValueChanged", function(self, value)
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
        outsideDelayValueText:SetText(roundedValue .. " sec")
        if not refreshingInterfaceOptions then
            SetAlertDelay(roundedValue, "outside")
            lastAlertAt = -GetAlertDelay("outside")
        end
    end)

    local outsideMinNonBossLabel = contentPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    outsideMinNonBossLabel:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 34, -310)
    outsideMinNonBossLabel:SetText("Min count of aggroed non-boss mobs")

    outsideMinNonBossDropdown = CreateFrame("Frame", "WHPInterfaceOptionsOutsideMinNonBossDropDown", contentPanel, "UIDropDownMenuTemplate")
    outsideMinNonBossDropdown:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 270, -302)
    UIDropDownMenu_SetWidth(outsideMinNonBossDropdown, 70)
    UIDropDownMenu_Initialize(outsideMinNonBossDropdown, InitializeOutsideMinNonBossDropdown)

    local outsideMinBossLabel = contentPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    outsideMinBossLabel:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 34, -344)
    outsideMinBossLabel:SetText("Min count of aggroed boss mobs")

    outsideMinBossDropdown = CreateFrame("Frame", "WHPInterfaceOptionsOutsideMinBossDropDown", contentPanel, "UIDropDownMenuTemplate")
    outsideMinBossDropdown:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 270, -336)
    UIDropDownMenu_SetWidth(outsideMinBossDropdown, 70)
    UIDropDownMenu_Initialize(outsideMinBossDropdown, InitializeOutsideMinBossDropdown)

    local autoActivateHeader = contentPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalMed3")
    autoActivateHeader:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 18, -390)
    autoActivateHeader:SetText("Auto-Activate On:")

    for i = 1, #AUTO_ACTIVATE_PARTY_SIZES do
        local partySize = AUTO_ACTIVATE_PARTY_SIZES[i]
        local checkbox = CreateFrame("CheckButton", "WHPInterfaceOptionsPartySize" .. partySize, contentPanel, "InterfaceOptionsCheckButtonTemplate")
        checkbox.partySize = partySize
        checkbox:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 14, -404 - ((i - 1) * 24))
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

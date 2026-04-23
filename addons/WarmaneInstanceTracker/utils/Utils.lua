local addonName, addon = ...

-- Cache frequently used functions
local type = type
local tonumber = tonumber
local ipairs = ipairs
local pairs = pairs
local tinsert = tinsert
local tremove = table.remove
local table_sort = table.sort
local math_floor = math.floor
local string_sub = string.sub
local string_gsub = string.gsub

-- Track schema version for saved aggregate stats
local STATS_SCHEMA_VERSION = 2
local MAX_PLAYER_LEVEL_FALLBACK = 80
local DEBUG_LOG_MAX_ENTRIES = 5000

-- Default configurable addon settings
local DEFAULT_SETTINGS = {
    enableInstanceTracking = true,
    enablePartyMessage = true,
    enableDebugPrinting = false,
    enableDebugLogging = false
}

-- Validate string values used in run/stat records
local function IsValidText(value)
    return type(value) == "string" and value ~= ""
end

-- Ensure saved variable roots exist and keep expected table shapes
local function EnsureSavedVariableTables()
    if type(InstancesData) ~= "table" then
        InstancesData = {}
    end
    if type(SettingsData) ~= "table" then
        SettingsData = {}
    end
    if type(DebugData) ~= "table" then
        DebugData = {}
    end

    if type(InstancesData.instances) ~= "table" then
        InstancesData.instances = {}
    end
    if type(InstancesData.instanceStats) ~= "table" then
        InstancesData.instanceStats = {}
    end
    if type(InstancesData.characterLevels) ~= "table" then
        InstancesData.characterLevels = {}
    end
    if type(InstancesData.activeRun) ~= "table" then
        InstancesData.activeRun = nil
    end

    if type(DebugData.deathLog) ~= "table" then
        DebugData.deathLog = {}
    end
end

-- Apply default values for user/developer settings
local function EnsureDefaultSettings()
    for key, defaultValue in pairs(DEFAULT_SETTINGS) do
        if type(SettingsData[key]) ~= "boolean" then
            SettingsData[key] = defaultValue
        end
    end
end

-- Build a unique key for one character + one instance
local function BuildStatsKey(character, instanceName)
    return character .. "||" .. instanceName
end

-- Use the WotLK max-level global when available, with Warmane's cap as fallback
local function GetMaxPlayerLevel()
    if type(MAX_PLAYER_LEVEL) == "number" and MAX_PLAYER_LEVEL > 0 then
        return MAX_PLAYER_LEVEL
    end

    return MAX_PLAYER_LEVEL_FALLBACK
end

-- Normalize levels from live and historical run records
local function NormalizeLevel(level)
    local numericLevel = tonumber(level)
    if type(numericLevel) ~= "number" or numericLevel <= 0 then
        return nil
    end

    return math_floor(numericLevel)
end

-- Normalize GUID format so parsing works with and without "0x" prefix
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

-- Round numbers to nearest integer for average fields
local function RoundNumber(value)
    if type(value) ~= "number" then
        return 0
    end
    return math_floor(value + 0.5)
end

-- Ensure aggregate table always exists
local function EnsureInstanceStatsTable()
    if type(InstancesData.instanceStats) ~= "table" then
        InstancesData.instanceStats = {}
    end
    if type(InstancesData.characterLevels) ~= "table" then
        InstancesData.characterLevels = {}
    end
end

-- Keep one latest known level per character and mirror it into all rows
local function UpdateCharacterLevel(character, level)
    if not IsValidText(character) then
        return nil
    end

    local normalizedLevel = NormalizeLevel(level)
    if not normalizedLevel then
        return InstancesData.characterLevels and InstancesData.characterLevels[character] or nil
    end

    EnsureInstanceStatsTable()

    local previousLevel = NormalizeLevel(InstancesData.characterLevels[character])
    if previousLevel and previousLevel > normalizedLevel then
        normalizedLevel = previousLevel
    end

    InstancesData.characterLevels[character] = normalizedLevel

    for _, record in pairs(InstancesData.instanceStats) do
        if type(record) == "table" and record.character == character then
            record.characterLevel = normalizedLevel
        end
    end

    return normalizedLevel
end

-- Historical records only know eligibility when the new flag exists or XP was earned
local function ResolveRunXPEligibility(run, runXP)
    if type(run) == "table" and type(run.xpEligible) == "boolean" then
        return run.xpEligible
    end

    if type(runXP) == "number" and runXP > 0 then
        return true
    end

    local runLevel = type(run) == "table" and NormalizeLevel(run.level) or nil
    if runLevel and runLevel >= GetMaxPlayerLevel() then
        return false
    end

    return false
end

-- Recompute average values from totals and run count
local function RecalculateAverages(record)
    if type(record) ~= "table" or type(record.totalRuns) ~= "number" or record.totalRuns <= 0 then
        return
    end

    record.averageTime = RoundNumber(record.totalDuration / record.totalRuns)

    if type(record.xpRuns) == "number" and record.xpRuns > 0 then
        record.averageXP = RoundNumber(record.totalXP / record.xpRuns)
        if type(record.totalXPDuration) == "number" and record.totalXPDuration > 0 then
            record.averageXPPerMinute = RoundNumber(record.totalXP / (record.totalXPDuration / 60))
        else
            record.averageXPPerMinute = 0
        end
    else
        record.averageXP = nil
        record.averageXPPerMinute = nil
    end
end

-- Validate one aggregate stats record
local function IsValidStatsRecord(record)
    return type(record) == "table" and
        IsValidText(record.character) and
        IsValidText(record.instanceName) and
        type(record.totalRuns) == "number" and record.totalRuns > 0 and
        type(record.totalXP) == "number" and record.totalXP >= 0 and
        type(record.xpRuns) == "number" and record.xpRuns >= 0 and record.xpRuns <= record.totalRuns and
        type(record.totalXPDuration) == "number" and record.totalXPDuration >= 0 and
        type(record.totalDuration) == "number" and record.totalDuration > 0 and
        type(record.fastestTime) == "number" and record.fastestTime > 0
end

-- Insert one run into the aggregate table
local function UpsertInstanceStats(character, instanceName, duration, xpGained, xpEligible, characterLevel)
    if not IsValidText(character) or not IsValidText(instanceName) then
        return nil
    end
    if type(duration) ~= "number" or duration <= 0 then
        return nil
    end

    local safeXP = type(xpGained) == "number" and xpGained or 0
    if safeXP < 0 then
        safeXP = 0
    end

    EnsureInstanceStatsTable()
    local knownLevel = UpdateCharacterLevel(character, characterLevel)

    local key = BuildStatsKey(character, instanceName)
    local record = InstancesData.instanceStats[key]

    if type(record) ~= "table" then
        record = {
            character = character,
            instanceName = instanceName,
            characterLevel = knownLevel,
            totalRuns = 0,
            totalXP = 0,
            xpRuns = 0,
            totalXPDuration = 0,
            totalDuration = 0,
            averageTime = 0,
            fastestTime = 0
        }
        InstancesData.instanceStats[key] = record
    end

    record.character = character
    record.instanceName = instanceName
    record.characterLevel = knownLevel or NormalizeLevel(record.characterLevel)
    record.totalRuns = (type(record.totalRuns) == "number" and record.totalRuns or 0) + 1
    record.totalDuration = (type(record.totalDuration) == "number" and record.totalDuration or 0) + duration

    if xpEligible == true then
        record.totalXP = (type(record.totalXP) == "number" and record.totalXP or 0) + safeXP
        record.xpRuns = (type(record.xpRuns) == "number" and record.xpRuns or 0) + 1
        record.totalXPDuration = (type(record.totalXPDuration) == "number" and record.totalXPDuration or 0) + duration
    else
        record.totalXP = type(record.totalXP) == "number" and record.totalXP or 0
        record.xpRuns = type(record.xpRuns) == "number" and record.xpRuns or 0
        record.totalXPDuration = type(record.totalXPDuration) == "number" and record.totalXPDuration or 0
    end

    if type(record.fastestTime) ~= "number" or record.fastestTime <= 0 or duration < record.fastestTime then
        record.fastestTime = duration
    end

    RecalculateAverages(record)
    return record
end

-- Rebuild aggregate table from historical runs once during schema migration
local function RebuildInstanceStatsFromInstances()
    InstancesData.instanceStats = {}
    InstancesData.characterLevels = {}
    if type(InstancesData.instances) ~= "table" then
        return
    end

    for _, run in ipairs(InstancesData.instances) do
        if type(run) == "table" and
            IsValidText(run.character) and
            IsValidText(run.name) and
            type(run.duration) == "number" and run.duration > 0 then
            local runXP = type(run.xpGained) == "number" and run.xpGained or 0
            if runXP < 0 then
                runXP = 0
            end
            local runLevel = NormalizeLevel(run.level)
            local xpEligible = ResolveRunXPEligibility(run, runXP)
            UpsertInstanceStats(run.character, run.name, run.duration, runXP, xpEligible, runLevel)
        end
    end
end

-- Keep only valid aggregate rows and refresh computed values
local function SanitizeInstanceStats()
    EnsureInstanceStatsTable()

    for key, record in pairs(InstancesData.instanceStats) do
        if not IsValidStatsRecord(record) then
            InstancesData.instanceStats[key] = nil
        else
            if type(record.xpRuns) ~= "number" then
                record.xpRuns = 0
            end
            if type(record.totalXPDuration) ~= "number" then
                record.totalXPDuration = 0
            end
            if record.xpRuns > record.totalRuns then
                record.xpRuns = record.totalRuns
            end
            if record.fastestTime > record.totalDuration then
                record.fastestTime = record.totalDuration
            end
            record.characterLevel = UpdateCharacterLevel(record.character, record.characterLevel)
            RecalculateAverages(record)
        end
    end
end

-- Sort aggregate rows by character and then by instance name
local function SortRows(left, right)
    if left.character ~= right.character then
        return left.character < right.character
    end
    if left.instanceName ~= right.instanceName then
        return left.instanceName < right.instanceName
    end
    return left.totalRuns > right.totalRuns
end

-- Trim debug log size to configured cap
local function TrimDebugLog()
    if type(DebugData.deathLog) ~= "table" then
        DebugData.deathLog = {}
        return
    end

    while #DebugData.deathLog > DEBUG_LOG_MAX_ENTRIES do
        tremove(DebugData.deathLog, 1)
    end
end

addon.utils = {
    -- Get NPC ID from dstGUID
    GetNPCId = function(dstGUID)
        local normalized = NormalizeGuid(dstGUID)
        if not normalized then
            return nil
        end

        -- In 3.3.5 GUID layout, NPC entry is encoded in hex digits 7-10
        local npcHex = string_sub(normalized, 7, 10)
        if not npcHex or #npcHex < 4 then
            return nil
        end

        local npcId = tonumber(npcHex, 16)
        if not npcId or npcId <= 0 then
            return nil
        end

        return npcId
    end,

    -- Create or initialize saved variables database with default values
    InitializeSavedData = function()
        EnsureSavedVariableTables()
        EnsureDefaultSettings()

        if type(InstancesData.instances) ~= "table" then
            InstancesData.instances = {}
        end

        if InstancesData.statsSchemaVersion ~= STATS_SCHEMA_VERSION or
            type(InstancesData.instanceStats) ~= "table" then
            RebuildInstanceStatsFromInstances()
            InstancesData.statsSchemaVersion = STATS_SCHEMA_VERSION
        end

        SanitizeInstanceStats()
        TrimDebugLog()
    end,

    -- Save one run and update aggregate stats table
    SaveInstanceRun = function(instanceData)
        if type(instanceData) ~= "table" then
            return false
        end
        if type(InstancesData) ~= "table" or type(InstancesData.instances) ~= "table" then
            return false
        end
        if not IsValidText(instanceData.name) or
            not IsValidText(instanceData.character) or
            type(instanceData.duration) ~= "number" or
            instanceData.duration <= 0 then
            return false
        end

        local runXP = type(instanceData.xpGained) == "number" and instanceData.xpGained or 0
        if runXP < 0 then
            runXP = 0
        end
        instanceData.xpGained = runXP

        local characterLevel = NormalizeLevel(instanceData.level)
        if characterLevel then
            instanceData.level = characterLevel
        end

        if type(instanceData.xpEligible) ~= "boolean" then
            instanceData.xpEligible = ResolveRunXPEligibility(instanceData, runXP)
        end

        tinsert(InstancesData.instances, instanceData)
        return UpsertInstanceStats(
            instanceData.character,
            instanceData.name,
            instanceData.duration,
            runXP,
            instanceData.xpEligible,
            characterLevel
        ) ~= nil
    end,

    -- Persist the currently active run so /reload can resume it
    SaveActiveRun = function(activeRun)
        if type(InstancesData) ~= "table" then
            InstancesData = {}
        end
        if type(activeRun) ~= "table" then
            InstancesData.activeRun = nil
            return
        end

        InstancesData.activeRun = activeRun
    end,

    GetActiveRun = function()
        if type(InstancesData) ~= "table" or type(InstancesData.activeRun) ~= "table" then
            return nil
        end

        return InstancesData.activeRun
    end,

    ClearActiveRun = function()
        if type(InstancesData) == "table" then
            InstancesData.activeRun = nil
        end
    end,

    -- Update all aggregate rows for one character with a known live level
    UpdateCharacterLevel = function(character, level)
        if not IsValidText(character) then
            return 0
        end

        local normalizedLevel = NormalizeLevel(level)
        if not normalizedLevel then
            return 0
        end

        EnsureInstanceStatsTable()
        UpdateCharacterLevel(character, normalizedLevel)

        local updatedRows = 0
        for _, record in pairs(InstancesData.instanceStats) do
            if type(record) == "table" and record.character == character then
                updatedRows = updatedRows + 1
            end
        end

        return updatedRows
    end,

    -- Fetch aggregate stats rows for table UI rendering
    GetAllInstanceStatsRows = function()
        if type(InstancesData) ~= "table" or type(InstancesData.instanceStats) ~= "table" then
            return {}
        end

        local rows = {}

        for _, record in pairs(InstancesData.instanceStats) do
            if IsValidStatsRecord(record) then
                rows[#rows + 1] = {
                    character = record.character,
                    instanceName = record.instanceName,
                    characterLevel = record.characterLevel,
                    totalRuns = record.totalRuns,
                    totalXP = record.totalXP,
                    xpRuns = record.xpRuns,
                    totalXPDuration = record.totalXPDuration,
                    totalDuration = record.totalDuration,
                    averageXP = record.averageXP,
                    averageTime = record.averageTime,
                    averageXPPerMinute = record.averageXPPerMinute,
                    fastestTime = record.fastestTime
                }
            end
        end

        table_sort(rows, SortRows)
        return rows
    end,

    -- Fetch average and fastest values for one instance of current character
    GetInstanceStats = function(instanceName)
        if not instanceName or type(instanceName) ~= "string" or
            instanceName == "" or
            type(InstancesData) ~= "table" or
            type(InstancesData.instanceStats) ~= "table" then
            return nil
        end

        local currentCharacter = UnitName("player")
        if not IsValidText(currentCharacter) then
            return nil
        end

        local key = BuildStatsKey(currentCharacter, instanceName)
        local record = InstancesData.instanceStats[key]
        if not IsValidStatsRecord(record) then
            return nil
        end

        return {
            averageTime = record.averageTime,
            fastestTime = record.fastestTime,
            averageXP = record.xpRuns > 0 and record.averageXP and record.averageXP > 0 and record.averageXP or nil,
            totalRuns = record.totalRuns
        }
    end,

    -- User settings getters/setters
    IsInstanceTrackingEnabled = function()
        return type(SettingsData) == "table" and SettingsData.enableInstanceTracking ~= false
    end,

    SetInstanceTrackingEnabled = function(enabled)
        if type(SettingsData) ~= "table" then
            SettingsData = {}
        end
        SettingsData.enableInstanceTracking = enabled == true
    end,

    IsPartyMessageEnabled = function()
        return type(SettingsData) == "table" and SettingsData.enablePartyMessage ~= false
    end,

    SetPartyMessageEnabled = function(enabled)
        if type(SettingsData) ~= "table" then
            SettingsData = {}
        end
        SettingsData.enablePartyMessage = enabled == true
    end,

    -- Developer settings getters/setters
    IsDebugPrintingEnabled = function()
        return type(SettingsData) == "table" and SettingsData.enableDebugPrinting == true
    end,

    SetDebugPrintingEnabled = function(enabled)
        if type(SettingsData) ~= "table" then
            SettingsData = {}
        end
        SettingsData.enableDebugPrinting = enabled == true
    end,

    IsDebugLoggingEnabled = function()
        return type(SettingsData) == "table" and SettingsData.enableDebugLogging == true
    end,

    SetDebugLoggingEnabled = function(enabled)
        if type(SettingsData) ~= "table" then
            SettingsData = {}
        end
        SettingsData.enableDebugLogging = enabled == true
    end,

    -- Debug log helpers
    AppendDebugDeathLog = function(entry)
        if type(entry) ~= "table" then
            return false
        end
        if type(DebugData) ~= "table" then
            DebugData = {}
        end
        if type(DebugData.deathLog) ~= "table" then
            DebugData.deathLog = {}
        end

        tinsert(DebugData.deathLog, entry)
        TrimDebugLog()
        return true
    end,

    GetDebugDeathLogCount = function()
        if type(DebugData) ~= "table" or type(DebugData.deathLog) ~= "table" then
            return 0
        end
        return #DebugData.deathLog
    end,

    ClearDebugDeathLog = function()
        if type(DebugData) ~= "table" then
            DebugData = {}
        end
        DebugData.deathLog = {}
    end
}

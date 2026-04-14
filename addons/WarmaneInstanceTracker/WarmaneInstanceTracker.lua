local addonName, addon = ...

-- Cache frequently used functions
local time = time
local date = date
local print = print
local type = type
local pairs = pairs
local tostring = tostring
local tonumber = tonumber
local math_floor = math.floor
local string_format = string.format
local string_gsub = string.gsub
local string_lower = string.lower
local strtrim = strtrim
local strsplit = strsplit
local UnitGUID = UnitGUID
local UnitName = UnitName
local GetTime = GetTime
local SendChatMessage = SendChatMessage
local GetNumPartyMembers = GetNumPartyMembers

-- Import local utils from addon namespace
local common = addon.common
local safe = addon.safe
local utils = addon.utils
local format = addon.format
local vars = addon.vars or {}
local ui = addon.ui or {}
local uiSpecialFrames = addon.uiSpecialFrames
local DUNGEON_FINAL_BOSSES = addon.DUNGEON_FINAL_BOSSES
local DUNGEON_DEBUG_BOSSES = addon.DUNGEON_DEBUG_BOSSES or {}

-- Keep references to modular UI controllers
local statsTableUI = nil
local configFrameUI = nil

-- Forward declare helpers used across functions
local ToggleConfigFrame
local ToggleStatsTable
local RefreshConfigCheckboxes
local RefreshStatsTableIfOpen
local UpdateSpecialFrameEscOrder
local DebugMessage

-- Initialize instance tracking state variables
local inInstance = false
local instanceName = ""
local startTime = 0
local xpGained = 0
local initialXP = 0
local initialXPMax = 0
local initialLevel = 0
local mobsKilled = 0
local isCorpseRunning = false
local pendingKillCount = 0
local lastKillEventAt = 0
local KILL_XP_MATCH_WINDOW = vars.KILL_XP_MATCH_WINDOW or 3
local instanceTrackingEnabled = true
local partyMessageEnabled = true
local debugMode = false
local debugLoggingEnabled = false

-- Normalize one instance name so final-boss mapping survives format differences
local function NormalizeInstanceName(rawName)
    if type(rawName) ~= "string" then
        return nil
    end

    local normalized = strtrim(rawName)
    if normalized == "" then
        return nil
    end

    normalized = string_lower(normalized)
    normalized = string_gsub(normalized, "%s*%(%d+%)%s*$", "")
    normalized = string_gsub(normalized, "[^%w%s]", " ")
    normalized = string_gsub(normalized, "%s+", " ")
    normalized = strtrim(normalized)

    if normalized == "" then
        return nil
    end

    return normalized
end

-- Compare two instance names after normalization to avoid strict-text mismatches
local function AreInstanceNamesEquivalent(leftName, rightName)
    local normalizedLeft = NormalizeInstanceName(leftName)
    local normalizedRight = NormalizeInstanceName(rightName)

    if not normalizedLeft or not normalizedRight then
        return false
    end

    return normalizedLeft == normalizedRight
end

-- Reset active tracking values so failed completion never keeps stale state
local function ResetInstanceTrackingState()
    inInstance = false
    instanceName = ""
    startTime = 0
    xpGained = 0
    initialXP = 0
    initialXPMax = 0
    initialLevel = 0
    mobsKilled = 0
    isCorpseRunning = false
    pendingKillCount = 0
    lastKillEventAt = 0
end

-- Start tracking for the provided party-instance name
local function StartInstanceTracking(resolvedInstanceName)
    if type(resolvedInstanceName) ~= "string" or resolvedInstanceName == "" then
        resolvedInstanceName = "Unknown Zone"
    end

    inInstance = true
    instanceName = resolvedInstanceName
    startTime = time()
    initialXP = safe.UnitXP("player") or 0
    initialXPMax = safe.UnitXPMax("player") or 1
    initialLevel = safe.UnitLevel("player") or 1
    mobsKilled = 0
    xpGained = 0
    pendingKillCount = 0
    lastKillEventAt = 0
    isCorpseRunning = false

    local stats = utils.GetInstanceStats(instanceName)
    local fastestTime = stats and stats.fastestTime
    local timeMsg = fastestTime and format.Time(fastestTime) or "not recorded"
    print(format.EnteringMessage(instanceName, timeMsg))
end

-- Resolve current party-instance name using instance info and zone fallback
local function ResolveCurrentPartyInstanceName()
    local success, isInstance, instanceType = pcall(IsInInstance)
    if not success then
        return nil, false, false
    end

    if not isInstance or instanceType ~= "party" then
        return nil, false, true
    end

    local resolvedInstanceName = nil
    if type(GetInstanceInfo) == "function" then
        local infoSuccess, infoName = pcall(GetInstanceInfo)
        if infoSuccess and type(infoName) == "string" and infoName ~= "" then
            resolvedInstanceName = infoName
        end
    end

    if type(resolvedInstanceName) ~= "string" or resolvedInstanceName == "" then
        resolvedInstanceName = safe.GetRealZoneText()
    end

    if type(resolvedInstanceName) ~= "string" or resolvedInstanceName == "" then
        resolvedInstanceName = "Unknown Zone"
    end

    return resolvedInstanceName, true, true
end

-- Keep instance state in sync on zone/world transitions
local function RefreshInstanceTrackingContext(eventSource)
    if not instanceTrackingEnabled then
        if inInstance then
            DebugMessage("context-reset", "tracking disabled")
            DebugMessage("context-source", eventSource or "unknown")
        end
        ResetInstanceTrackingState()
        return
    end

    local resolvedInstanceName, isPartyInstance, hasValidStatus = ResolveCurrentPartyInstanceName()
    if not hasValidStatus then
        print(common.ErrorMessage("WIT", "check instance status"))
        return
    end

    if not isPartyInstance then
        if inInstance then
            DebugMessage("context-reset", "left party instance")
            DebugMessage("context-source", eventSource or "unknown")
        end
        ResetInstanceTrackingState()
        return
    end

    if inInstance then
        if AreInstanceNamesEquivalent(instanceName, resolvedInstanceName) then
            if isCorpseRunning then
                DebugMessage("corpse-run", "resumed same instance")
                isCorpseRunning = false
            end
            return
        end

        DebugMessage("instance-switch-from", instanceName ~= "" and instanceName or "nil")
        DebugMessage("instance-switch-to", resolvedInstanceName)
        ResetInstanceTrackingState()
    end

    StartInstanceTracking(resolvedInstanceName)
end

-- Print a debug chat line only when debug mode is enabled
DebugMessage = function(label, value)
    if not debugMode then
        return
    end
    print(common.Message("WIT", "Debug - " .. label, value, true))
end

-- Recalculate tracked XP gain from entry baseline and current player XP/level
local function RecalculateTrackedXP()
    if not inInstance then
        xpGained = 0
        return 0, safe.UnitLevel("player"), false, false
    end

    local currentLevel = safe.UnitLevel("player")
    local isMaxLevel = currentLevel == MAX_PLAYER_LEVEL
    local reachedMaxLevel = isMaxLevel and initialLevel == MAX_PLAYER_LEVEL - 1

    if initialLevel == MAX_PLAYER_LEVEL then
        xpGained = 0
        return xpGained, currentLevel, isMaxLevel, reachedMaxLevel
    end

    local currentXP = safe.UnitXP("player")
    if type(currentXP) ~= "number" or currentXP < 0 then
        currentXP = 0
    end

    if currentLevel > initialLevel then
        xpGained = (initialXPMax - initialXP) + currentXP
    else
        xpGained = currentXP - initialXP
    end

    if type(xpGained) ~= "number" or xpGained < 0 then
        xpGained = 0
    end

    return xpGained, currentLevel, isMaxLevel, reachedMaxLevel
end

-- Load current settings from split SavedVariables
local function LoadSettingsFromSavedData()
    instanceTrackingEnabled = utils.IsInstanceTrackingEnabled()
    partyMessageEnabled = utils.IsPartyMessageEnabled()
    debugMode = utils.IsDebugPrintingEnabled()
    debugLoggingEnabled = utils.IsDebugLoggingEnabled()
end

-- Return number of persisted death log entries
local function GetDebugDeathLogCount()
    return utils.GetDebugDeathLogCount()
end

-- Persist one death event for offline inspection in SavedVariables
local function AppendDebugDeathLog(eventTime, subevent, dstGUID, dstName, npcId, matchedBossInstance, isKnownBoss, isFinalBossMatch)
    if not debugLoggingEnabled then
        return
    end

    local entry = {
        timestamp = eventTime,
        timestampText = date("%Y-%m-%d %H:%M:%S", eventTime),
        instanceName = instanceName ~= "" and instanceName or "Unknown Zone",
        subevent = subevent or "UNKNOWN",
        npcId = npcId or 0,
        unitName = dstName or "Unknown",
        rawGUID = dstGUID or "nil",
        matchedBossInstance = matchedBossInstance or nil,
        isKnownBoss = isKnownBoss and true or false,
        isFinalBossMatch = isFinalBossMatch and true or false
    }

    utils.AppendDebugDeathLog(entry)
end

-- Print death debug lines only for known boss IDs
local function ShouldPrintCombatDebug(isKnownBoss, isFinalBossMatch)
    if not debugMode then
        return false
    end
    if isFinalBossMatch then
        return true
    end
    return isKnownBoss
end

-- Send one plain-text completion summary to party chat
local function SendPartyCompletionSummary(message)
    if type(message) ~= "string" or message == "" then
        return
    end
    if type(GetNumPartyMembers) ~= "function" or GetNumPartyMembers() <= 0 then
        return
    end
    if type(SendChatMessage) ~= "function" then
        return
    end

    pcall(SendChatMessage, message, "PARTY")
end

-- Format numbers with comma as thousand separator for debug output
local function FormatNumberWithCommas(number)
    if type(number) ~= "number" then
        return "0"
    end

    local rounded = math_floor(number + 0.5)
    local sign = ""

    if rounded < 0 then
        sign = "-"
        rounded = -rounded
    end

    local formatted = tostring(rounded)
    while true do
        local nextFormatted, replacements = string_gsub(formatted, "^(%d+)(%d%d%d)", "%1,%2")
        formatted = nextFormatted
        if replacements == 0 then
            break
        end
    end

    return sign .. formatted
end

-- Format seconds into HH:MM:SS for debug and party summary output
local function FormatTableTime(seconds)
    if type(seconds) ~= "number" or seconds < 0 then
        return "0:00:00"
    end

    local totalSeconds = math_floor(seconds + 0.5)
    local hours = math_floor(totalSeconds / 3600)
    local minutes = math_floor((totalSeconds % 3600) / 60)
    local remainingSeconds = totalSeconds % 60
    return string_format("%d:%02d:%02d", hours, minutes, remainingSeconds)
end

-- Keep Esc behavior classic by delegating ordering to the dedicated UI module
UpdateSpecialFrameEscOrder = function()
    if not uiSpecialFrames or type(uiSpecialFrames.UpdateEscOrder) ~= "function" then
        return
    end

    local statsShown = statsTableUI and statsTableUI.IsShown and statsTableUI.IsShown() or false
    local configShown = configFrameUI and configFrameUI.IsShown and configFrameUI.IsShown() or false
    uiSpecialFrames.UpdateEscOrder(statsShown, configShown)
end

-- Build UI controllers once and inject callbacks back into tracker logic
local function EnsureUIControllers()
    if not configFrameUI and type(ui.CreateConfigFrame) == "function" then
        configFrameUI = ui.CreateConfigFrame({
            getState = function()
                return {
                    instanceTrackingEnabled = instanceTrackingEnabled,
                    partyMessageEnabled = partyMessageEnabled,
                    debugMode = debugMode,
                    debugLoggingEnabled = debugLoggingEnabled
                }
            end,
            onSetInstanceTracking = function(enabled)
                instanceTrackingEnabled = enabled and true or false
                utils.SetInstanceTrackingEnabled(instanceTrackingEnabled)
                if not instanceTrackingEnabled then
                    ResetInstanceTrackingState()
                end
            end,
            onSetPartyMessage = function(enabled)
                partyMessageEnabled = enabled and true or false
                utils.SetPartyMessageEnabled(partyMessageEnabled)
            end,
            onSetDebugPrinting = function(enabled)
                debugMode = enabled and true or false
                utils.SetDebugPrintingEnabled(debugMode)
            end,
            onSetDebugLogging = function(enabled)
                debugLoggingEnabled = enabled and true or false
                utils.SetDebugLoggingEnabled(debugLoggingEnabled)
            end,
            onVisibilityChanged = UpdateSpecialFrameEscOrder
        })
    end

    if not statsTableUI and type(ui.CreateStatsTable) == "function" then
        statsTableUI = ui.CreateStatsTable({
            toggleConfig = function()
                if ToggleConfigFrame then
                    ToggleConfigFrame()
                end
            end,
            onVisibilityChanged = UpdateSpecialFrameEscOrder
        })
    end
end

-- Sync config checkboxes with current persisted settings
RefreshConfigCheckboxes = function()
    if not configFrameUI or not configFrameUI.RefreshCheckboxes then
        return
    end
    configFrameUI.RefreshCheckboxes()
end

-- Refresh stats table when visible so completion/debug writes reflect immediately
RefreshStatsTableIfOpen = function()
    if not statsTableUI or not statsTableUI.IsShown or not statsTableUI.Refresh then
        return
    end
    if statsTableUI.IsShown() then
        statsTableUI.Refresh()
    end
end

-- Toggle settings window visibility
ToggleConfigFrame = function()
    EnsureUIControllers()
    if configFrameUI and configFrameUI.Toggle then
        configFrameUI.Toggle()
    end
end

-- Toggle table window visibility for slash command usage
ToggleStatsTable = function()
    EnsureUIControllers()
    if statsTableUI and statsTableUI.Toggle then
        statsTableUI.Toggle()
    end
end

-- Handle explicit config subcommand
local function HandleConfig()
    ToggleConfigFrame()
end

-- Print slash command help text
local function PrintHelp()
    print(common.Message("WIT", "Available commands:"))
    print("  |cFFFF8000/wit |cFFFFFF00- Open or close the stats table|r")
    print("  |cFFFF8000/wit config |cFFFFFF00- Open or close the settings window|r")
    print("  |cFFFF8000/wit debug |cFFFFFF00- Show debug subcommands|r")
    print("  |cFFFF8000/wit help |cFFFFFF00- Show this help|r")
end

-- Print help text for debug subcommands
local function PrintDebugHelp()
    print(common.Message("WIT", "Debug commands:"))
    print("  |cFFFF8000/wit debug help |cFFFFFF00- Show debug command help|r")
    print("  |cFFFF8000/wit debug on |cFFFFFF00- Enable boss-only chat debug + optional all-deaths SavedVariables log|r")
    print("  |cFFFF8000/wit debug off |cFFFFFF00- Disable verbose boss/combat debug output|r")
    print("  |cFFFF8000/wit debug log status |cFFFFFF00- Show death log capture status and entry count|r")
    print("  |cFFFF8000/wit debug log on |cFFFFFF00- Enable all unit death capture into SavedVariables|r")
    print("  |cFFFF8000/wit debug log off |cFFFFFF00- Disable all unit death capture into SavedVariables|r")
    print("  |cFFFF8000/wit debug log clear |cFFFFFF00- Clear persisted unit death log entries|r")
    print("  |cFFFF8000/wit debug state |cFFFFFF00- Print current tracker state values|r")
    print("  |cFFFF8000/wit debug target |cFFFFFF00- Print target GUID, parsed NPC ID and mapped instance|r")
    print("  |cFFFF8000/wit debug simulate \"Instance\" duration xp |cFFFFFF00- Save synthetic run data|r")
end

-- Parse debug simulate arguments with quoted or simple instance names
local function ParseSimulateArguments(rawArgs)
    if not rawArgs then
        return nil, nil, nil
    end

    local instanceNameArg, durationArg, xpArg = rawArgs:match("^\"([^\"]+)\"%s+(%-?%d+)%s+(%-?%d+)%s*$")
    if instanceNameArg then
        return instanceNameArg, tonumber(durationArg), tonumber(xpArg)
    end

    instanceNameArg, durationArg, xpArg = rawArgs:match("^(%S+)%s+(%-?%d+)%s+(%-?%d+)%s*$")
    if instanceNameArg then
        return instanceNameArg, tonumber(durationArg), tonumber(xpArg)
    end

    return nil, nil, nil
end

-- Print current live tracking state to simplify dungeon testing
local function HandleDebugState()
    RecalculateTrackedXP()
    local elapsed = inInstance and startTime > 0 and (time() - startTime) or 0

    print(common.Message("WIT", "Debug state - inInstance", tostring(inInstance), true))
    print(common.Message("WIT", "Debug state - instanceName", instanceName ~= "" and instanceName or "nil", true))
    print(common.Message("WIT", "Debug state - elapsed", FormatTableTime(elapsed), true))
    print(common.Message("WIT", "Debug state - mobsKilled", tostring(mobsKilled), true))
    print(common.Message("WIT", "Debug state - pendingKills", tostring(pendingKillCount), true))
    print(common.Message("WIT", "Debug state - xpGained", tostring(xpGained), true))
    print(common.Message("WIT", "Debug state - corpseRun", tostring(isCorpseRunning), true))
    print(common.Message("WIT", "Debug state - mode", debugMode and "on" or "off", true))
    print(common.Message("WIT", "Debug state - deathLogCapture", debugLoggingEnabled and "on" or "off", true))
    print(common.Message("WIT", "Debug state - deathLogEntries", tostring(GetDebugDeathLogCount()), true))
end

-- Manage persistent death-log capture for all unit deaths during debug mode
local function HandleDebugLog(args)
    local trimmedArgs = strtrim(args or "")
    local logSubcommand, logArgs = strsplit(" ", trimmedArgs, 2)
    logSubcommand = (logSubcommand and logSubcommand ~= "") and logSubcommand:lower() or "status"
    logArgs = strtrim(logArgs or "")

    if logSubcommand == "status" then
        if logArgs ~= "" then
            print(common.ErrorMessage("WIT", "execute command. Wrong number of arguments for 'debug log status' (expected 0)"))
            return
        end
        print(common.Message("WIT", "Debug death log capture", debugLoggingEnabled and "enabled" or "disabled", true))
        print(common.Message("WIT", "Debug death log entries", tostring(GetDebugDeathLogCount()), true))
        return
    end

    if logSubcommand == "on" then
        if logArgs ~= "" then
            print(common.ErrorMessage("WIT", "execute command. Wrong number of arguments for 'debug log on' (expected 0)"))
            return
        end
        debugLoggingEnabled = true
        utils.SetDebugLoggingEnabled(true)
        RefreshConfigCheckboxes()
        print(common.Message("WIT", "Debug death log capture", "enabled", true))
        return
    end

    if logSubcommand == "off" then
        if logArgs ~= "" then
            print(common.ErrorMessage("WIT", "execute command. Wrong number of arguments for 'debug log off' (expected 0)"))
            return
        end
        debugLoggingEnabled = false
        utils.SetDebugLoggingEnabled(false)
        RefreshConfigCheckboxes()
        print(common.Message("WIT", "Debug death log capture", "disabled", true))
        return
    end

    if logSubcommand == "clear" then
        if logArgs ~= "" then
            print(common.ErrorMessage("WIT", "execute command. Wrong number of arguments for 'debug log clear' (expected 0)"))
            return
        end
        utils.ClearDebugDeathLog()
        print(common.Message("WIT", "Debug death log", "cleared", true))
        return
    end

    print(common.ErrorMessage("WIT", string_format(
        "find subcommand '%s'. Use /wit debug help to see available commands", "debug log " .. logSubcommand)))
end

-- Print target GUID parsing details to verify NPC ID extraction
local function HandleDebugTarget()
    local targetGuid = UnitGUID("target")
    if not targetGuid then
        print(common.ErrorMessage("WIT", "retrieve target GUID (no target selected)"))
        return
    end

    local targetName = UnitName("target") or "Unknown"
    local npcId = utils.GetNPCId(targetGuid)
    local mappedInstance = npcId and DUNGEON_FINAL_BOSSES[npcId] or nil
    local isKnownBoss = npcId and DUNGEON_DEBUG_BOSSES[npcId] or false

    print(common.Message("WIT", "Debug target", targetName, true))
    print(common.Message("WIT", "Target GUID", targetGuid, true))
    print(common.Message("WIT", "Parsed NPC ID", npcId and tostring(npcId) or "nil", true))
    print(common.Message("WIT", "Known debug boss", isKnownBoss and "yes" or "no", true))
    print(common.Message("WIT", "Mapped instance", mappedInstance or "not found", true))
end

-- Save a synthetic run to avoid long dungeon test loops
local function HandleDebugSimulate(args)
    local trimmedArgs = strtrim(args or "")
    local instanceNameArg, durationArg, xpArg = ParseSimulateArguments(trimmedArgs)

    if not instanceNameArg or not durationArg or not xpArg then
        print(common.ErrorMessage("WIT", "execute command. Wrong number of arguments for 'debug simulate' (expected 3)"))
        return
    end

    if durationArg <= 0 then
        print(common.ErrorMessage("WIT", "execute command. Invalid duration for 'debug simulate' (expected > 0)"))
        return
    end

    local character = UnitName("player")
    if not character or character == "" then
        print(common.ErrorMessage("WIT", "retrieve current character name"))
        return
    end

    if xpArg < 0 then
        xpArg = 0
    end

    local instanceData = {
        name = instanceNameArg,
        duration = math_floor(durationArg),
        xpGained = math_floor(xpArg),
        timestamp = time(),
        character = character,
        level = safe.UnitLevel("player")
    }

    local saved = utils.SaveInstanceRun(instanceData)
    if not saved then
        print(common.ErrorMessage("WIT", "save simulated run data"))
        return
    end

    print(common.Message("WIT", "Debug simulate saved", instanceNameArg, true))
    print(common.Message("WIT", "Simulated duration", FormatTableTime(durationArg), true))
    print(common.Message("WIT", "Simulated XP", FormatNumberWithCommas(xpArg), true))

    RefreshStatsTableIfOpen()
end

-- Handle all /wit debug subcommands
local function HandleDebug(args)
    local trimmedArgs = strtrim(args or "")
    if trimmedArgs == "" then
        PrintDebugHelp()
        return
    end

    local debugSubcommand, debugArgs = strsplit(" ", trimmedArgs, 2)
    debugSubcommand = debugSubcommand and debugSubcommand:lower() or ""
    debugArgs = strtrim(debugArgs or "")

    if debugSubcommand == "help" then
        if debugArgs ~= "" then
            print(common.ErrorMessage("WIT", "execute command. Wrong number of arguments for 'debug help' (expected 0)"))
            return
        end
        PrintDebugHelp()
        return
    end

    if debugSubcommand == "on" then
        if debugArgs ~= "" then
            print(common.ErrorMessage("WIT", "execute command. Wrong number of arguments for 'debug on' (expected 0)"))
            return
        end
        debugMode = true
        utils.SetDebugPrintingEnabled(true)
        RefreshConfigCheckboxes()
        print(common.Message("WIT", "Debug mode", "enabled (boss-only chat output)", true))
        return
    end

    if debugSubcommand == "off" then
        if debugArgs ~= "" then
            print(common.ErrorMessage("WIT", "execute command. Wrong number of arguments for 'debug off' (expected 0)"))
            return
        end
        debugMode = false
        utils.SetDebugPrintingEnabled(false)
        RefreshConfigCheckboxes()
        print(common.Message("WIT", "Debug mode", "disabled", true))
        return
    end

    if debugSubcommand == "log" then
        HandleDebugLog(debugArgs)
        return
    end

    if debugSubcommand == "state" then
        if debugArgs ~= "" then
            print(common.ErrorMessage("WIT", "execute command. Wrong number of arguments for 'debug state' (expected 0)"))
            return
        end
        HandleDebugState()
        return
    end

    if debugSubcommand == "target" then
        if debugArgs ~= "" then
            print(common.ErrorMessage("WIT", "execute command. Wrong number of arguments for 'debug target' (expected 0)"))
            return
        end
        HandleDebugTarget()
        return
    end

    if debugSubcommand == "simulate" then
        HandleDebugSimulate(debugArgs)
        return
    end

    print(common.ErrorMessage("WIT", string_format(
        "find subcommand '%s'. Use /wit debug help to see available commands", debugSubcommand)))
end

-- Define available slash subcommands
local SUBCOMMANDS = {
    ["config"] = { handler = HandleConfig, args = 0 },
    ["debug"] = { handler = HandleDebug },
    ["help"] = { handler = PrintHelp, args = 0 },
}

-- Register slash command parser following Blizzard pattern
SLASH_WIT1 = "/wit"
SlashCmdList["WIT"] = function(msg)
    local rawMsg = strtrim(msg or "")
    local normalizedMsg = rawMsg:lower()

    -- Open the table directly when no subcommand is provided
    if normalizedMsg == "" then
        ToggleStatsTable()
        return
    end

    -- Parse first word as subcommand and validate it
    local subcommand = strsplit(" ", normalizedMsg, 2)
    local command = SUBCOMMANDS[subcommand]
    local _, rawArgs = strsplit(" ", rawMsg, 2)
    rawArgs = strtrim(rawArgs or "")

    if not command then
        print(common.ErrorMessage("WIT", string_format(
            "find subcommand '%s'. Use /wit help to see available commands", subcommand)))
        return
    end

    -- Ensure subcommand receives the expected argument count
    if command.args == 0 and rawArgs ~= "" then
        print(common.ErrorMessage("WIT", string_format(
            "execute command. Wrong number of arguments for '%s' (expected %d)", subcommand, command.args)))
        return
    end

    command.handler(rawArgs)
end

-- Process and display instance completion statistics
local function ProcessInstanceCompletion()
    -- Validate essential state first
    if not inInstance or startTime == 0 then
        print(common.ErrorMessage("WIT", "process completion (invalid state)"))
        DebugMessage("inInstance", tostring(inInstance))
        DebugMessage("startTime", tostring(startTime))
        DebugMessage("instanceName", instanceName ~= "" and instanceName or "nil")
        ResetInstanceTrackingState()
        return
    end

    -- Calculate run duration
    local duration = time() - startTime
    if not instanceName or instanceName == "" or duration <= 0 then
        print(common.ErrorMessage("WIT", "save instance data (invalid essentials)"))
        DebugMessage("instanceName", instanceName ~= "" and instanceName or "nil")
        DebugMessage("duration", tostring(duration))
        ResetInstanceTrackingState()
        return
    end

    local currentCharacter = UnitName("player")
    if not currentCharacter or currentCharacter == "" then
        print(common.ErrorMessage("WIT", "retrieve current character name"))
        ResetInstanceTrackingState()
        return
    end

    -- Recalculate XP from baseline before saving completion run
    local _, currentLevel, isMaxLevel, reachedMaxLevel = RecalculateTrackedXP()

    -- Save run data even for zero-xp or zero-kill edge runs
    local instanceData = {
        name = instanceName,
        duration = duration,
        xpGained = xpGained,
        timestamp = time(),
        character = currentCharacter,
    }

    -- Save run data to persistent storage and aggregate stats
    local saved = utils.SaveInstanceRun(instanceData)
    if not saved then
        print(common.ErrorMessage("WIT", "access saved data (corrupted or not initialized)"))
        ResetInstanceTrackingState()
        return
    end

    -- Get statistical data for comparisons
    local stats = utils.GetInstanceStats(instanceName)
    if not stats then
        print(common.ErrorMessage("WIT", "retrieve instance statistics"))
        -- Continue with run output even when aggregated retrieval fails
        stats = {
            averageTime = duration,
            fastestTime = duration,
            averageXP = xpGained > 0 and xpGained or nil,
            totalRuns = 1
        }
    end

    -- Display completion statistics
    print(common.Message("WIT", instanceName .. " completed in", format.Time(duration), false))
    if duration ~= stats.averageTime then
        print(common.Message("WIT", "Average time", format.Time(stats.averageTime) ..
            format.TimeDifference(duration, stats.averageTime), true))
    end
    if duration ~= stats.fastestTime then
        print(common.Message("WIT", "Fastest time", format.Time(stats.fastestTime) ..
            format.TimeDifference(duration, stats.fastestTime), true))
    end

    if not isMaxLevel then
        print(common.Message("WIT", "Mobs killed", format.Number(mobsKilled), true))
        if mobsKilled > 0 then
            local xpPerMob = math_floor(xpGained / mobsKilled)
            print(common.Message("WIT", "Average XP per mob", format.Number(xpPerMob), true))
        else
            print(common.Message("WIT", "Average XP per mob", "n/a (0 mobs counted)", true))
        end

        print(common.Message("WIT", "XP received", format.Number(xpGained), true))
        if stats.averageXP and xpGained ~= stats.averageXP then
            print(common.Message("WIT", "Average XP received", format.Number(stats.averageXP) ..
                format.XPDifference(xpGained, stats.averageXP), true))
        end
    end

    local runsTillNextLevelText = "n/a"

    -- Keep unknown-zone output simple but safe for 0-xp cases
    if not isMaxLevel and instanceName == "Unknown Zone" then
        local xpToLevel = currentLevel > initialLevel and safe.UnitXPMax("player") or
            (safe.UnitXPMax("player") - safe.UnitXP("player"))

        if xpGained > 0 then
            runsTillNextLevelText = string_format("%.1f", xpToLevel / xpGained)
            print(common.Message("WIT", "Runs until next level", runsTillNextLevelText, true))
        else
            print(common.Message("WIT", "Runs until next level", "n/a (0 XP run)", true))
        end
    end

    -- Show XP-to-level data only when relevant and computable
    if not isMaxLevel and instanceName ~= "Unknown Zone" and not reachedMaxLevel then
        local xpToLevel = currentLevel > initialLevel and safe.UnitXPMax("player") or
            (safe.UnitXPMax("player") - safe.UnitXP("player"))
        local runsNeeded = stats.averageXP and (xpToLevel / stats.averageXP) or 0

        print(common.Message("WIT", "XP until next level", format.Number(xpToLevel), true))
        if stats.averageXP and stats.averageXP > 0 then
            runsTillNextLevelText = string_format("%.1f", runsNeeded)
            print(common.Message("WIT", "Runs until next level", "~" .. runsTillNextLevelText, true))
        else
            print(common.Message("WIT", "Runs until next level", "n/a (average XP is 0)", true))
        end
    end

    -- Post one plain summary line to /party so group members can see run result
    if partyMessageEnabled then
        local partySummary = string_format(
            "[WIT] %s finished in %s | XP gained: %s | Runs till next level: %s",
            instanceName,
            FormatTableTime(duration),
            format.Number(xpGained),
            runsTillNextLevelText
        )
        SendPartyCompletionSummary(partySummary)
    end

    -- Refresh UI table if it is currently open
    RefreshStatsTableIfOpen()

    -- Reset all state variables after completion processing
    ResetInstanceTrackingState()
end

-- Main frame for event handling
local WIT = CreateFrame("Frame")

-- Register events needed for tracking
WIT:RegisterEvent("ADDON_LOADED")
WIT:RegisterEvent("ZONE_CHANGED_NEW_AREA")
WIT:RegisterEvent("PLAYER_ENTERING_WORLD")
WIT:RegisterEvent("PLAYER_XP_UPDATE")
WIT:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
WIT:RegisterEvent("PLAYER_DEAD")

-- Main event handler
WIT:SetScript("OnEvent", function(self, event, ...)
    -- Initialize addon data and show welcome message
    if event == "ADDON_LOADED" and ... == addonName then
        local success = pcall(utils.InitializeSavedData)
        if not success then
            print(common.ErrorMessage("WIT", "initialize saved data"))
            return
        end

        -- Load persisted user/developer settings from SavedVariables
        LoadSettingsFromSavedData()

        print(common.Message("WIT", "WarmaneInstanceTracker loaded"))

        -- Handle combat events for boss kills and mob tracking
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if inInstance and instanceTrackingEnabled then
            local _, subevent, _, _, _, dstGUID, dstName = ...

            if subevent == "UNIT_DIED" or subevent == "UNIT_DESTROYED" or subevent == "PARTY_KILL" then
                -- Track death timing to correlate near-future XP updates with kill count
                local eventTime = GetTime()
                local eventTimestamp = time()
                pendingKillCount = pendingKillCount + 1
                lastKillEventAt = eventTime

                -- Get NPC ID for final boss of the instance
                local npcId = utils.GetNPCId(dstGUID)
                local matchedBossInstance = npcId and DUNGEON_FINAL_BOSSES[npcId] or nil
                local isKnownBoss = npcId and DUNGEON_DEBUG_BOSSES[npcId] or false
                local isMappedFinalBoss = matchedBossInstance ~= nil
                local isFinalBossMatch = isMappedFinalBoss and AreInstanceNamesEquivalent(matchedBossInstance, instanceName)

                -- Persist all deaths for offline analysis when debug log capture is enabled
                AppendDebugDeathLog(eventTimestamp, subevent, dstGUID, dstName, npcId, matchedBossInstance, isKnownBoss, isFinalBossMatch)

                if ShouldPrintCombatDebug(isKnownBoss, isFinalBossMatch) then
                    DebugMessage("combat-subevent", subevent)
                    DebugMessage("combat-instanceName", instanceName ~= "" and instanceName or "nil")
                    DebugMessage("combat-unitName", dstName or "Unknown")
                    DebugMessage("combat-rawGUID", dstGUID or "nil")
                    DebugMessage("combat-parsedNpcId", npcId and tostring(npcId) or "nil")
                    DebugMessage("combat-isKnownBoss", isKnownBoss and "true" or "false")
                    DebugMessage("combat-matchedInstance", matchedBossInstance or "nil")
                end

                if debugMode and isMappedFinalBoss and not isFinalBossMatch then
                    DebugMessage("final-boss-name-mismatch", "mapped to different instance")
                    DebugMessage("mismatch-trackedInstance", instanceName ~= "" and instanceName or "nil")
                    DebugMessage("mismatch-mappedInstance", matchedBossInstance)
                    DebugMessage("mismatch-trackedNormalized", NormalizeInstanceName(instanceName) or "nil")
                    DebugMessage("mismatch-mappedNormalized", NormalizeInstanceName(matchedBossInstance) or "nil")
                end

                if isFinalBossMatch then
                    DebugMessage("completion-trigger", "matched final boss")
                    ProcessInstanceCompletion()
                    return
                end
            end
        end

    elseif event == "PLAYER_XP_UPDATE" then
        if not instanceTrackingEnabled then
            return
        end

        -- Keep live tracked XP up to date for debug and completion consistency
        RecalculateTrackedXP()

        -- Count kills if XP update happened close to one or more death events
        if inInstance and pendingKillCount > 0 and lastKillEventAt > 0 then
            local elapsedSinceKill = GetTime() - lastKillEventAt
            if elapsedSinceKill <= KILL_XP_MATCH_WINDOW then
                mobsKilled = mobsKilled + pendingKillCount
                pendingKillCount = 0
                lastKillEventAt = 0
            elseif elapsedSinceKill > (KILL_XP_MATCH_WINDOW * 2) then
                -- Expire stale pending kills to avoid linking unrelated XP sources
                pendingKillCount = 0
                lastKillEventAt = 0
            end
        end

    elseif event == "PLAYER_DEAD" then
        if inInstance and instanceTrackingEnabled then
            isCorpseRunning = true
        end

    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        RefreshInstanceTrackingContext(event)
    end
end)

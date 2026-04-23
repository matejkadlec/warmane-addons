local addonName, addon = ...

-- Cache frequently used functions
local time = time
local date = date
local print = print
local type = type
local pcall = pcall
local tostring = tostring
local tonumber = tonumber
local math_floor = math.floor
local string_format = string.format
local string_gsub = string.gsub
local string_lower = string.lower
local string_match = string.match
local string_sub = string.sub
local strtrim = strtrim
local UnitGUID = UnitGUID
local UnitName = UnitName
local GetTime = GetTime
local SendChatMessage = SendChatMessage
local GetNumPartyMembers = GetNumPartyMembers
local GetNumRaidMembers = GetNumRaidMembers

-- Import local utils from addon namespace
local common = addon.common
local safe = addon.safe
local utils = addon.utils
local format = addon.format
local vars = addon.vars or {}
local DUNGEON_FINAL_BOSSES = addon.DUNGEON_FINAL_BOSSES
local DUNGEON_DEBUG_BOSSES = addon.DUNGEON_DEBUG_BOSSES or {}
local DUNGEON_BASE_INSTANCE_NAMES = addon.DUNGEON_BASE_INSTANCE_NAMES or {}

local COLOR = {
    ORANGE = "|cFFFF8000",
    YELLOW = "|cFFFFFF00"
}

local STATE_INACTIVE = "inactive"
local STATE_ACTIVE = "active"
local STATE_PAUSED = "paused"
local STATE_IGNORED_IN_PROGRESS = "ignored-in-progress"
local RECENT_GROUP_REASON_WINDOW = 5
local RECENT_LFG_INSTANCE_WINDOW = 300
local KILL_XP_MATCH_WINDOW = vars.KILL_XP_MATCH_WINDOW or 3
local AUTO_START_DELAY = vars.AUTO_START_DELAY or 1
local COMPLETION_XP_SETTLE_DELAY = vars.COMPLETION_XP_SETTLE_DELAY or 1
local ACTIVE_RUN_RESTORE_WINDOW = vars.ACTIVE_RUN_RESTORE_WINDOW or 1800

-- Initialize instance tracking state variables
local state = STATE_INACTIVE
local instanceName = ""
local startTime = 0
local pausedDuration = 0
local pauseStartedAt = 0
local xpGained = 0
local initialLevel = 0
local xpCheckpoint = 0
local xpCheckpointMax = 0
local levelCheckpoint = 0
local mobsKilled = 0
local isCorpseRunning = false
local isInsideTrackedInstance = false
local pendingKillCount = 0
local lastKillEventAt = 0
local runHadGroup = false
local ignoredInstanceName = ""
local ignoredMessagePrinted = false
local pendingInProgressName = nil
local pendingStartInstanceName = nil
local pendingStartAt = 0
local pendingStartWallTime = 0
local pendingCompletionSaveRun = false
local pendingCompletionSendPartySummary = false
local pendingCompletionAt = 0
local recentGroupLossReason = nil
local recentGroupLossAt = 0
local recentLFGInstanceName = nil
local recentLFGInstanceAt = 0
local instanceTrackingEnabled = true
local partyMessageEnabled = true
local debugMode = false
local debugLoggingEnabled = false
local callbacks = {}

local runTracker = {}

local ClearPersistedActiveRun
local PersistActiveRun
local TryRestoreActiveRun

-- Ask the bootstrap frame to enable or disable scheduled tracker updates
local function SetAutoStartUpdateEnabled(enabled)
    if type(callbacks.setAutoStartUpdateEnabled) == "function" then
        callbacks.setAutoStartUpdateEnabled(enabled and true or false)
    end
end

-- Return whether a delayed automatic start is waiting for an OnUpdate tick
local function HasPendingStart()
    return pendingStartInstanceName ~= nil and pendingStartAt > 0
end

-- Return whether a final-boss completion is waiting for XP events to settle
local function HasPendingCompletion()
    return pendingCompletionAt > 0
end

-- Keep the single OnUpdate script active while any scheduled work is pending
local function RefreshScheduledUpdateEnabled()
    SetAutoStartUpdateEnabled(HasPendingStart() or HasPendingCompletion())
end

-- Clear delayed automatic start state
local function ClearPendingStart()
    pendingStartInstanceName = nil
    pendingStartAt = 0
    pendingStartWallTime = 0
    RefreshScheduledUpdateEnabled()
end

-- Clear delayed completion state after it fires or the active run is aborted
local function ClearPendingCompletion()
    pendingCompletionSaveRun = false
    pendingCompletionSendPartySummary = false
    pendingCompletionAt = 0
    RefreshScheduledUpdateEnabled()
end

-- Print a debug chat line only when debug mode is enabled
local function DebugMessage(label, value)
    if not debugMode then
        return
    end
    print(common.Message("WIT", "Debug - " .. label, value, true))
end

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

-- Use parent instance names for wing matching when the client reports only a base zone
local function GetComparableInstanceName(rawName)
    if type(rawName) ~= "string" then
        return rawName
    end

    return DUNGEON_BASE_INSTANCE_NAMES[rawName] or rawName
end

-- Compare two instance names after normalization to avoid strict-text mismatches
local function AreInstanceNamesEquivalent(leftName, rightName)
    local normalizedLeft = NormalizeInstanceName(GetComparableInstanceName(leftName))
    local normalizedRight = NormalizeInstanceName(GetComparableInstanceName(rightName))

    if not normalizedLeft or not normalizedRight then
        return false
    end

    return normalizedLeft == normalizedRight
end

-- Remember the exact LFG proposal name so winged dungeons are tracked precisely
local function SetRecentLFGInstanceName(instanceName)
    if type(instanceName) ~= "string" or instanceName == "" then
        return
    end

    recentLFGInstanceName = instanceName
    recentLFGInstanceAt = GetTime()
end

-- Resolve the precise proposal dungeon name from its LFG dungeon ID
local function ResolveLFGProposalInstanceName(proposalId, proposedName)
    if type(proposalId) == "number" and type(GetLFGDungeonInfo) == "function" then
        local success, dungeonName = pcall(GetLFGDungeonInfo, proposalId)
        if success and type(dungeonName) == "string" and dungeonName ~= "" then
            return dungeonName
        end
    end

    return proposedName
end

-- Clear stale LFG proposal context after it has served the current run
local function ClearRecentLFGInstanceName()
    recentLFGInstanceName = nil
    recentLFGInstanceAt = 0
end

-- Prefer a recent exact LFG wing name when the live zone is only a parent name
local function ResolveRecentLFGInstanceName(resolvedInstanceName)
    if type(recentLFGInstanceName) ~= "string" or recentLFGInstanceName == "" then
        return resolvedInstanceName
    end

    if (GetTime() - recentLFGInstanceAt) > RECENT_LFG_INSTANCE_WINDOW then
        ClearRecentLFGInstanceName()
        return resolvedInstanceName
    end

    if AreInstanceNamesEquivalent(resolvedInstanceName, recentLFGInstanceName) then
        return recentLFGInstanceName
    end

    return resolvedInstanceName
end

-- Return whether a normal active or paused run exists
local function HasTrackedRun()
    return state == STATE_ACTIVE or state == STATE_PAUSED
end

-- Return whether the player still belongs to a party, raid, or LFG dungeon group
local function HasActiveInstanceGroup()
    if type(IsPartyLFG) == "function" and IsPartyLFG() then
        return true
    end

    if type(GetNumRaidMembers) == "function" and GetNumRaidMembers() > 0 then
        return true
    end

    if type(GetNumPartyMembers) == "function" and GetNumPartyMembers() > 0 then
        return true
    end

    if type(UnitName) == "function" and UnitName("party1") then
        return true
    end

    return false
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

    resolvedInstanceName = ResolveRecentLFGInstanceName(resolvedInstanceName)

    return resolvedInstanceName, true, true
end

-- Clear the saved active run snapshot once it is no longer resumable
ClearPersistedActiveRun = function()
    if type(utils.ClearActiveRun) == "function" then
        utils.ClearActiveRun()
    end
end

-- Capture current XP baseline for incremental XP tracking
local function CaptureXPCheckpoint()
    levelCheckpoint = safe.UnitLevel("player") or 1
    xpCheckpoint = safe.UnitXP("player") or 0
    xpCheckpointMax = safe.UnitXPMax("player") or 1
end

-- Reset active tracking values so failed completion never keeps stale state
local function ResetInstanceTrackingState()
    ClearPendingStart()
    state = STATE_INACTIVE
    instanceName = ""
    startTime = 0
    pausedDuration = 0
    pauseStartedAt = 0
    xpGained = 0
    initialLevel = 0
    xpCheckpoint = 0
    xpCheckpointMax = 0
    levelCheckpoint = 0
    mobsKilled = 0
    isCorpseRunning = false
    isInsideTrackedInstance = false
    pendingKillCount = 0
    lastKillEventAt = 0
    runHadGroup = false
    ClearRecentLFGInstanceName()
    ClearPendingCompletion()
    ClearPersistedActiveRun()
end

-- Clear ignored-in-progress state after leaving that dungeon/group
local function ClearIgnoredInProgressState()
    ClearPendingStart()
    if state == STATE_IGNORED_IN_PROGRESS then
        DebugMessage("ignored-in-progress", "cleared")
    end
    state = STATE_INACTIVE
    ignoredInstanceName = ""
    ignoredMessagePrinted = false
end

-- Refresh the saved UI table when a run is saved
local function RefreshStatsTableIfOpen()
    if type(callbacks.refreshStatsTable) == "function" then
        callbacks.refreshStatsTable()
    end
end

-- Refresh the config UI after slash command setting changes
local function RefreshConfigCheckboxes()
    if type(callbacks.refreshConfigCheckboxes) == "function" then
        callbacks.refreshConfigCheckboxes()
    end
end

-- Format a chat line with one highlighted instance name
local function InstanceActionMessage(textBefore, highlightedValue, textAfter)
    return string_format("%s[WIT] %s%s%s%s%s%s|r",
        COLOR.ORANGE,
        COLOR.YELLOW,
        textBefore or "",
        COLOR.ORANGE,
        highlightedValue or "",
        COLOR.YELLOW,
        textAfter or "")
end

-- Print a no-save abort reason and discard the active run
local function AbortCurrentRun(reason)
    if not HasTrackedRun() then
        ResetInstanceTrackingState()
        return
    end

    if reason == "removed" then
        print(common.Message("WIT", "You were removed from the instance group. This run will not count towards statistics."))
    elseif reason == "left" then
        print(common.Message("WIT", "You left the instance group early. This run will not count towards statistics."))
    elseif reason == "disabled" then
        print(common.Message("WIT", "Instance tracking was disabled. This run will not count towards statistics."))
    elseif reason == "switched" then
        print(common.Message("WIT", "You entered a different instance before completion. The previous run will not count towards statistics."))
    else
        print(common.Message("WIT", "Your instance group ended before completion. This run will not count towards statistics."))
    end

    DebugMessage("abort-reason", reason or "group-ended")
    ResetInstanceTrackingState()
end

-- Start tracking for the provided party-instance name
local function StartInstanceTracking(resolvedInstanceName, source, startedAt)
    ClearPendingStart()

    if type(resolvedInstanceName) ~= "string" or resolvedInstanceName == "" then
        resolvedInstanceName = "Unknown Zone"
    end

    state = STATE_ACTIVE
    instanceName = resolvedInstanceName
    startTime = type(startedAt) == "number" and startedAt > 0 and startedAt or time()
    pausedDuration = 0
    pauseStartedAt = 0
    xpGained = 0
    initialLevel = safe.UnitLevel("player") or 1
    mobsKilled = 0
    pendingKillCount = 0
    lastKillEventAt = 0
    isCorpseRunning = false
    isInsideTrackedInstance = true
    runHadGroup = HasActiveInstanceGroup()
    CaptureXPCheckpoint()
    PersistActiveRun(false)

    if source == "manual" then
        print(InstanceActionMessage("Started a fresh tracking of ", instanceName, "."))
        return
    end

    local stats = utils.GetInstanceStats(instanceName)
    local fastestTime = stats and stats.fastestTime
    local timeMsg = fastestTime and format.Time(fastestTime) or "not recorded"
    print(format.EnteringMessage(instanceName, timeMsg))
end

-- Print in-progress message once and ignore the current run
local function MarkIgnoredInProgress(resolvedInstanceName)
    ClearPendingStart()

    if type(resolvedInstanceName) ~= "string" or resolvedInstanceName == "" then
        resolvedInstanceName = pendingInProgressName or "Unknown Zone"
    end

    if HasTrackedRun() then
        ResetInstanceTrackingState()
    end

    state = STATE_IGNORED_IN_PROGRESS
    ignoredInstanceName = resolvedInstanceName
    pendingInProgressName = nil
    ClearPersistedActiveRun()

    if not ignoredMessagePrinted then
        print(common.Message("WIT", "You joined an instance in progress. This run will not count towards statistics."))
        ignoredMessagePrinted = true
    end
end

-- Return elapsed run time with paused time excluded
local function GetElapsedSeconds()
    if not HasTrackedRun() or startTime == 0 then
        return 0
    end

    local excludedPausedTime = pausedDuration
    if state == STATE_PAUSED and pauseStartedAt > 0 then
        excludedPausedTime = excludedPausedTime + (time() - pauseStartedAt)
    end

    local elapsed = time() - startTime - excludedPausedTime
    if elapsed < 0 then
        return 0
    end

    return elapsed
end

-- Recalculate tracked XP using incremental checkpoints so paused XP is ignored
local function UpdateTrackedXP()
    local currentLevel = safe.UnitLevel("player") or levelCheckpoint or 1
    local isMaxLevel = currentLevel == MAX_PLAYER_LEVEL
    local reachedMaxLevel = isMaxLevel and initialLevel == MAX_PLAYER_LEVEL - 1

    if not HasTrackedRun() then
        xpGained = 0
        return 0, currentLevel, isMaxLevel, reachedMaxLevel
    end

    if state ~= STATE_ACTIVE or not isInsideTrackedInstance then
        return xpGained, currentLevel, isMaxLevel, reachedMaxLevel
    end

    if levelCheckpoint == MAX_PLAYER_LEVEL then
        return xpGained, currentLevel, isMaxLevel, reachedMaxLevel
    end

    local currentXP = safe.UnitXP("player")
    if type(currentXP) ~= "number" or currentXP < 0 then
        currentXP = 0
    end

    local gainedSinceCheckpoint = 0
    if currentLevel > levelCheckpoint then
        gainedSinceCheckpoint = (xpCheckpointMax - xpCheckpoint) + currentXP
    elseif currentLevel == levelCheckpoint then
        gainedSinceCheckpoint = currentXP - xpCheckpoint
    end

    if type(gainedSinceCheckpoint) ~= "number" or gainedSinceCheckpoint < 0 then
        gainedSinceCheckpoint = 0
    end

    xpGained = xpGained + gainedSinceCheckpoint
    CaptureXPCheckpoint()

    return xpGained, currentLevel, isMaxLevel, reachedMaxLevel
end

-- Persist active run state so /reload can resume duration and XP counters
PersistActiveRun = function(updateXP)
    if not HasTrackedRun() then
        ClearPersistedActiveRun()
        return
    end

    if updateXP ~= false then
        UpdateTrackedXP()
    end

    local currentCharacter = UnitName("player")
    if type(currentCharacter) ~= "string" or currentCharacter == "" then
        return
    end

    if type(utils.SaveActiveRun) == "function" then
        utils.SaveActiveRun({
            character = currentCharacter,
            instanceName = instanceName,
            state = state,
            startTime = startTime,
            pausedDuration = pausedDuration,
            pauseStartedAt = pauseStartedAt,
            xpGained = xpGained,
            initialLevel = initialLevel,
            xpCheckpoint = xpCheckpoint,
            xpCheckpointMax = xpCheckpointMax,
            levelCheckpoint = levelCheckpoint,
            mobsKilled = mobsKilled,
            runHadGroup = runHadGroup,
            savedAt = time()
        })
    end
end

-- Restore an active run snapshot when a /reload returns to the same instance
TryRestoreActiveRun = function()
    if HasTrackedRun() or not instanceTrackingEnabled or type(utils.GetActiveRun) ~= "function" then
        return false
    end

    local snapshot = utils.GetActiveRun()
    if type(snapshot) ~= "table" then
        return false
    end

    local currentCharacter = UnitName("player")
    if type(currentCharacter) ~= "string" or currentCharacter == "" or snapshot.character ~= currentCharacter then
        ClearPersistedActiveRun()
        return false
    end

    if type(snapshot.savedAt) ~= "number" or (time() - snapshot.savedAt) > ACTIVE_RUN_RESTORE_WINDOW then
        ClearPersistedActiveRun()
        return false
    end

    if type(snapshot.instanceName) ~= "string" or snapshot.instanceName == "" then
        ClearPersistedActiveRun()
        return false
    end

    local resolvedInstanceName, isPartyInstance, hasValidStatus = ResolveCurrentPartyInstanceName()
    if not hasValidStatus then
        return false
    end

    if not isPartyInstance or not AreInstanceNamesEquivalent(snapshot.instanceName, resolvedInstanceName) then
        ClearPersistedActiveRun()
        return false
    end

    ClearPendingStart()
    ClearPendingCompletion()
    state = snapshot.state == STATE_PAUSED and STATE_PAUSED or STATE_ACTIVE
    instanceName = snapshot.instanceName
    startTime = type(snapshot.startTime) == "number" and snapshot.startTime > 0 and snapshot.startTime or time()
    pausedDuration = type(snapshot.pausedDuration) == "number" and snapshot.pausedDuration >= 0 and snapshot.pausedDuration or 0
    pauseStartedAt = type(snapshot.pauseStartedAt) == "number" and snapshot.pauseStartedAt > 0 and snapshot.pauseStartedAt or 0
    xpGained = type(snapshot.xpGained) == "number" and snapshot.xpGained >= 0 and snapshot.xpGained or 0
    initialLevel = type(snapshot.initialLevel) == "number" and snapshot.initialLevel > 0 and snapshot.initialLevel or safe.UnitLevel("player") or 1
    xpCheckpoint = type(snapshot.xpCheckpoint) == "number" and snapshot.xpCheckpoint >= 0 and snapshot.xpCheckpoint or safe.UnitXP("player") or 0
    xpCheckpointMax = type(snapshot.xpCheckpointMax) == "number" and snapshot.xpCheckpointMax > 0 and snapshot.xpCheckpointMax or safe.UnitXPMax("player") or 1
    levelCheckpoint = type(snapshot.levelCheckpoint) == "number" and snapshot.levelCheckpoint > 0 and snapshot.levelCheckpoint or safe.UnitLevel("player") or 1
    mobsKilled = type(snapshot.mobsKilled) == "number" and snapshot.mobsKilled >= 0 and snapshot.mobsKilled or 0
    isCorpseRunning = false
    isInsideTrackedInstance = true
    pendingKillCount = 0
    lastKillEventAt = 0
    runHadGroup = snapshot.runHadGroup == true or HasActiveInstanceGroup()
    ClearRecentLFGInstanceName()

    PersistActiveRun(false)
    print(InstanceActionMessage("Resumed tracking of ", instanceName, " after reload."))
    return true
end

-- Return current XP remaining only when the XP bar data is ready and useful
local function GetXPToNextLevel()
    local currentXP = safe.UnitXP("player")
    local maxXP = safe.UnitXPMax("player")

    if type(currentXP) ~= "number" or type(maxXP) ~= "number" then
        return nil
    end

    if maxXP <= 0 or currentXP < 0 or currentXP >= maxXP then
        return nil
    end

    return maxXP - currentXP
end

-- Format positive run counts without rounding small values down to 0.0
local function FormatRunsUntilNextLevel(runsNeeded)
    if type(runsNeeded) ~= "number" or runsNeeded <= 0 then
        return nil
    end

    if runsNeeded < 0.1 then
        return "0.1"
    end

    return string_format("%.1f", runsNeeded)
end

-- Delay completion briefly so PLAYER_XP_UPDATE/PLAYER_LEVEL_UP can update XP state
local function ScheduleInstanceCompletion(saveRun, sendPartySummary)
    if HasPendingCompletion() then
        return
    end

    pendingCompletionSaveRun = saveRun == true
    pendingCompletionSendPartySummary = sendPartySummary == true
    pendingCompletionAt = GetTime()
    RefreshScheduledUpdateEnabled()
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
        instanceName = instanceName ~= "" and instanceName or ignoredInstanceName ~= "" and ignoredInstanceName or "Unknown Zone",
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

-- Escape outbound chat control characters so plain text cannot fail to send
local function EscapeOutboundChatMessage(message)
    return string_gsub(message, "|", "||")
end

-- Resolve the best group chat channel available in 3.3.5a
local function GetGroupCompletionChannel()
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

-- Send one plain-text completion summary to group chat
local function SendPartyCompletionSummary(message)
    if type(message) ~= "string" or message == "" then
        return
    end

    local channel = GetGroupCompletionChannel()
    if not channel then
        DebugMessage("party-summary", "skipped (not in group)")
        return
    end

    if type(SendChatMessage) ~= "function" then
        return
    end

    local success, errorMessage = pcall(SendChatMessage, EscapeOutboundChatMessage(message), channel)
    if not success then
        print(common.ErrorMessage("WIT", "send party completion summary"))
        DebugMessage("party-summary-error", tostring(errorMessage))
    end
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

-- Format seconds into HH:MM:SS for debug and status output
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

-- Process and display instance completion statistics
local function ProcessInstanceCompletion(saveRun, sendPartySummary)
    if not HasTrackedRun() or startTime == 0 then
        print(common.ErrorMessage("WIT", "process completion (invalid state)"))
        DebugMessage("state", state)
        DebugMessage("startTime", tostring(startTime))
        DebugMessage("instanceName", instanceName ~= "" and instanceName or "nil")
        ResetInstanceTrackingState()
        return
    end

    UpdateTrackedXP()

    local duration = GetElapsedSeconds()
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

    local currentLevel = safe.UnitLevel("player") or initialLevel
    local isMaxLevel = currentLevel == MAX_PLAYER_LEVEL
    local reachedMaxLevel = isMaxLevel and initialLevel == MAX_PLAYER_LEVEL - 1

    if saveRun then
        local instanceData = {
            name = instanceName,
            duration = duration,
            xpGained = xpGained,
            timestamp = time(),
            character = currentCharacter,
        }

        local saved = utils.SaveInstanceRun(instanceData)
        if not saved then
            print(common.ErrorMessage("WIT", "access saved data (corrupted or not initialized)"))
            ResetInstanceTrackingState()
            return
        end
    end

    local stats = utils.GetInstanceStats(instanceName)
    if not stats then
        if saveRun then
            print(common.ErrorMessage("WIT", "retrieve instance statistics"))
        end
        stats = {
            averageTime = duration,
            fastestTime = duration,
            averageXP = xpGained > 0 and xpGained or nil,
            totalRuns = saveRun and 1 or 0
        }
    end

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

    if not isMaxLevel and instanceName == "Unknown Zone" then
        local xpToLevel = GetXPToNextLevel()
        local runsNeededText = nil
        if xpToLevel and xpGained > 0 then
            runsNeededText = FormatRunsUntilNextLevel(xpToLevel / xpGained)
        end

        if runsNeededText then
            runsTillNextLevelText = runsNeededText
            print(common.Message("WIT", "Runs until next level", runsTillNextLevelText, true))
        elseif not xpToLevel then
            print(common.Message("WIT", "Runs until next level", "n/a (level data updating)", true))
        else
            print(common.Message("WIT", "Runs until next level", "n/a (0 XP run)", true))
        end
    end

    if not isMaxLevel and instanceName ~= "Unknown Zone" and not reachedMaxLevel then
        local xpToLevel = GetXPToNextLevel()
        local runsNeeded = xpToLevel and stats.averageXP and (xpToLevel / stats.averageXP) or nil
        local runsNeededText = FormatRunsUntilNextLevel(runsNeeded)

        print(common.Message("WIT", "XP until next level", xpToLevel and format.Number(xpToLevel) or "n/a (level data updating)", true))
        if runsNeededText and stats.averageXP and stats.averageXP > 0 then
            runsTillNextLevelText = runsNeededText
            print(common.Message("WIT", "Runs until next level", "~" .. runsTillNextLevelText, true))
        elseif not xpToLevel then
            print(common.Message("WIT", "Runs until next level", "n/a (level data updating)", true))
        else
            print(common.Message("WIT", "Runs until next level", "n/a (average XP is 0)", true))
        end
    end

    -- Never send the completion party summary for max-level characters.
    if sendPartySummary and partyMessageEnabled and not isMaxLevel then
        local partySummary = string_format(
            "[WIT] %s completed in %s. XP received: %s. Runs until next level: %s.",
            instanceName,
            format.Time(duration),
            format.Number(xpGained),
            runsTillNextLevelText
        )
        SendPartyCompletionSummary(partySummary)
    end

    if saveRun then
        RefreshStatsTableIfOpen()
    end

    ResetInstanceTrackingState()
end

-- Resolve a recent system-message reason for group loss
local function GetRecentGroupLossReason()
    if recentGroupLossReason and (GetTime() - recentGroupLossAt) <= RECENT_GROUP_REASON_WINDOW then
        return recentGroupLossReason
    end

    if type(GetLFGDeserterExpiration) == "function" and GetLFGDeserterExpiration() then
        return "left"
    end

    return "group-ended"
end

-- Remember a nearby system-message reason for the next roster update
local function SetRecentGroupLossReason(reason)
    recentGroupLossReason = reason
    recentGroupLossAt = GetTime()
end

-- Delay automatic starts briefly so in-progress system messages can arrive first
local function ScheduleAutoStart(resolvedInstanceName)
    if pendingStartInstanceName and
        AreInstanceNamesEquivalent(pendingStartInstanceName, resolvedInstanceName) then
        return
    end

    pendingStartInstanceName = resolvedInstanceName
    pendingStartAt = GetTime()
    pendingStartWallTime = time()
    RefreshScheduledUpdateEnabled()
end

-- Keep instance state in sync on zone/world transitions
local function RefreshInstanceTrackingContext(eventSource)
    if not instanceTrackingEnabled then
        if HasTrackedRun() then
            DebugMessage("context-reset", "tracking disabled")
            DebugMessage("context-source", eventSource or "unknown")
        end
        ResetInstanceTrackingState()
        ClearIgnoredInProgressState()
        return
    end

    local resolvedInstanceName, isPartyInstance, hasValidStatus = ResolveCurrentPartyInstanceName()
    if not hasValidStatus then
        print(common.ErrorMessage("WIT", "check instance status"))
        return
    end

    if state == STATE_IGNORED_IN_PROGRESS then
        if isPartyInstance then
            if ignoredInstanceName == "" or AreInstanceNamesEquivalent(ignoredInstanceName, resolvedInstanceName) then
                ignoredInstanceName = ignoredInstanceName ~= "" and ignoredInstanceName or resolvedInstanceName
                return
            end

            ClearIgnoredInProgressState()
        elseif HasActiveInstanceGroup() then
            return
        else
            ClearIgnoredInProgressState()
            return
        end
    end

    if not isPartyInstance then
        if HasTrackedRun() then
            -- PLAYER_ENTERING_WORLD can briefly report a non-instance state during /reload.
            if eventSource == "PLAYER_ENTERING_WORLD" then
                DebugMessage("context-pending-world", "preserving tracked instance state")
                return
            end

            if runHadGroup and not HasActiveInstanceGroup() then
                AbortCurrentRun(GetRecentGroupLossReason())
                return
            end

            isInsideTrackedInstance = false
            DebugMessage("context-outside", eventSource or "unknown")
        end
        return
    end

    if pendingInProgressName then
        MarkIgnoredInProgress(resolvedInstanceName)
        return
    end

    if HasTrackedRun() then
        if AreInstanceNamesEquivalent(instanceName, resolvedInstanceName) then
            isInsideTrackedInstance = true
            if isCorpseRunning then
                DebugMessage("corpse-run", "resumed same instance")
                isCorpseRunning = false
            end
            if HasActiveInstanceGroup() then
                runHadGroup = true
            end
            CaptureXPCheckpoint()
            PersistActiveRun(false)
            return
        end

        DebugMessage("instance-switch-from", instanceName ~= "" and instanceName or "nil")
        DebugMessage("instance-switch-to", resolvedInstanceName)
        AbortCurrentRun("switched")
    end

    ScheduleAutoStart(resolvedInstanceName)
end

-- Detect reliable Dungeon Finder proposals that already have killed encounters
local function CaptureLFGProposalProgress()
    if type(GetLFGProposal) ~= "function" then
        return
    end

    local success, proposalExists, proposalType, proposalId, proposedName, texture, role, hasResponded,
        totalEncounters, completedEncounters =
        pcall(GetLFGProposal)
    if not success or not proposalExists then
        return
    end

    local proposalInstanceName = ResolveLFGProposalInstanceName(proposalId, proposedName)
    SetRecentLFGInstanceName(proposalInstanceName)

    if type(completedEncounters) == "number" and completedEncounters > 0 then
        pendingInProgressName = proposalInstanceName
        DebugMessage("proposal-in-progress", string_format("%d/%s", completedEncounters, tostring(totalEncounters)))

        local resolvedInstanceName, isPartyInstance = ResolveCurrentPartyInstanceName()
        if isPartyInstance then
            MarkIgnoredInProgress(resolvedInstanceName)
        end
    end
end

-- Return the stable literal prefix before the first format marker
local function GetFormattedMessagePrefix(formatText)
    if type(formatText) ~= "string" or formatText == "" then
        return nil
    end

    local prefix = string_match(formatText, "^(.-)%%")
    if type(prefix) == "string" and prefix ~= "" then
        return prefix
    end

    return formatText
end

-- Match system messages whose globals are format strings
local function MessageStartsWithFormatted(message, formatText)
    local prefix = GetFormattedMessagePrefix(formatText)
    if not prefix or prefix == "" then
        return false
    end

    return string_sub(message or "", 1, #prefix) == prefix
end

-- Handle system chat messages that classify run lifecycle transitions
local function HandleSystemMessage(message)
    if type(message) ~= "string" or message == "" then
        return
    end

    if MessageStartsWithFormatted(message, INSTANCE_LOCK_TIMER) or
        MessageStartsWithFormatted(message, INSTANCE_LOCK_TIMER_PREVIOUSLY_SAVED) then
        local resolvedInstanceName = select(1, ResolveCurrentPartyInstanceName())
        MarkIgnoredInProgress(resolvedInstanceName)
        return
    end

    if MessageStartsWithFormatted(message, INSTANCE_BOOT_TIMER) or message == ERR_UNINVITE_YOU then
        SetRecentGroupLossReason("removed")
        if HasTrackedRun() then
            AbortCurrentRun("removed")
        end
        return
    end

    if message == ERR_LEFT_GROUP_YOU then
        SetRecentGroupLossReason("left")
        if HasTrackedRun() then
            AbortCurrentRun("left")
        end
        return
    end

    if message == ERR_GROUP_DISBANDED or message == NOT_IN_GROUP then
        SetRecentGroupLossReason("group-ended")
        if HasTrackedRun() then
            AbortCurrentRun("group-ended")
        end
    end
end

-- Handle party roster updates that happen without a clear system message
local function HandleGroupChanged()
    if HasTrackedRun() and HasActiveInstanceGroup() then
        runHadGroup = true
        PersistActiveRun(false)
        return
    end

    if HasTrackedRun() and runHadGroup and not HasActiveInstanceGroup() then
        AbortCurrentRun(GetRecentGroupLossReason())
        return
    end

    if state == STATE_IGNORED_IN_PROGRESS and not HasActiveInstanceGroup() then
        ClearIgnoredInProgressState()
    end
end

-- Handle all tracked combat-log deaths
local function HandleCombatLogEvent(...)
    if state ~= STATE_ACTIVE or not instanceTrackingEnabled or not isInsideTrackedInstance then
        return
    end

    local _, subevent, _, _, _, dstGUID, dstName = ...
    if subevent ~= "UNIT_DIED" and subevent ~= "UNIT_DESTROYED" and subevent ~= "PARTY_KILL" then
        return
    end

    local eventTime = GetTime()
    local eventTimestamp = time()
    pendingKillCount = pendingKillCount + 1
    lastKillEventAt = eventTime

    local npcId = utils.GetNPCId(dstGUID)
    local matchedBossInstance = npcId and DUNGEON_FINAL_BOSSES[npcId] or nil
    local isKnownBoss = npcId and DUNGEON_DEBUG_BOSSES[npcId] or false
    local isMappedFinalBoss = matchedBossInstance ~= nil
    local isFinalBossMatch = isMappedFinalBoss and AreInstanceNamesEquivalent(matchedBossInstance, instanceName)

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
        instanceName = matchedBossInstance
        PersistActiveRun(true)
        ScheduleInstanceCompletion(true, true)
    end
end

-- Handle one XP/level update and correlate nearby death events with mob kills
local function HandleXPUpdate()
    if not instanceTrackingEnabled or state ~= STATE_ACTIVE then
        return
    end

    UpdateTrackedXP()

    if pendingKillCount > 0 and lastKillEventAt > 0 and isInsideTrackedInstance then
        local elapsedSinceKill = GetTime() - lastKillEventAt
        if elapsedSinceKill <= KILL_XP_MATCH_WINDOW then
            mobsKilled = mobsKilled + pendingKillCount
            pendingKillCount = 0
            lastKillEventAt = 0
        elseif elapsedSinceKill > (KILL_XP_MATCH_WINDOW * 2) then
            pendingKillCount = 0
            lastKillEventAt = 0
        end
    end

    PersistActiveRun(false)
end

-- Load current settings from split SavedVariables
function runTracker.LoadSettingsFromSavedData()
    instanceTrackingEnabled = utils.IsInstanceTrackingEnabled()
    partyMessageEnabled = utils.IsPartyMessageEnabled()
    debugMode = utils.IsDebugPrintingEnabled()
    debugLoggingEnabled = utils.IsDebugLoggingEnabled()
end

-- Install callbacks owned by the bootstrap/UI module
function runTracker.SetCallbacks(nextCallbacks)
    callbacks = nextCallbacks or {}
end

-- Return current settings for UI checkboxes
function runTracker.GetSettingsState()
    return {
        instanceTrackingEnabled = instanceTrackingEnabled,
        partyMessageEnabled = partyMessageEnabled,
        debugMode = debugMode,
        debugLoggingEnabled = debugLoggingEnabled
    }
end

-- Toggle automatic tracking and abort active runs if disabled
function runTracker.SetInstanceTrackingEnabled(enabled)
    instanceTrackingEnabled = enabled and true or false
    utils.SetInstanceTrackingEnabled(instanceTrackingEnabled)

    if not instanceTrackingEnabled then
        if HasTrackedRun() then
            AbortCurrentRun("disabled")
        else
            ResetInstanceTrackingState()
        end
        ClearIgnoredInProgressState()
    end
end

-- Toggle party completion messages
function runTracker.SetPartyMessageEnabled(enabled)
    partyMessageEnabled = enabled and true or false
    utils.SetPartyMessageEnabled(partyMessageEnabled)
end

-- Toggle boss/combat debug printing
function runTracker.SetDebugPrintingEnabled(enabled)
    debugMode = enabled and true or false
    utils.SetDebugPrintingEnabled(debugMode)
    RefreshConfigCheckboxes()
end

-- Toggle persisted death-log capture
function runTracker.SetDebugLoggingEnabled(enabled)
    debugLoggingEnabled = enabled and true or false
    utils.SetDebugLoggingEnabled(debugLoggingEnabled)
    RefreshConfigCheckboxes()
end

-- Return whether debug death logging is enabled
function runTracker.IsDebugLoggingEnabled()
    return debugLoggingEnabled
end

-- Return current debug death log count
function runTracker.GetDebugDeathLogCount()
    return GetDebugDeathLogCount()
end

-- Clear persisted debug death logs
function runTracker.ClearDebugDeathLog()
    utils.ClearDebugDeathLog()
end

-- Print current live tracking state to simplify dungeon testing
function runTracker.PrintDebugState()
    UpdateTrackedXP()
    local elapsed = HasTrackedRun() and GetElapsedSeconds() or 0

    print(common.Message("WIT", "Debug state - state", state, true))
    print(common.Message("WIT", "Debug state - instanceName", instanceName ~= "" and instanceName or "nil", true))
    print(common.Message("WIT", "Debug state - elapsed", FormatTableTime(elapsed), true))
    print(common.Message("WIT", "Debug state - mobsKilled", tostring(mobsKilled), true))
    print(common.Message("WIT", "Debug state - pendingKills", tostring(pendingKillCount), true))
    print(common.Message("WIT", "Debug state - xpGained", tostring(xpGained), true))
    print(common.Message("WIT", "Debug state - corpseRun", tostring(isCorpseRunning), true))
    print(common.Message("WIT", "Debug state - insideInstance", tostring(isInsideTrackedInstance), true))
    print(common.Message("WIT", "Debug state - mode", debugMode and "on" or "off", true))
    print(common.Message("WIT", "Debug state - deathLogCapture", debugLoggingEnabled and "on" or "off", true))
    print(common.Message("WIT", "Debug state - deathLogEntries", tostring(GetDebugDeathLogCount()), true))
end

-- Print target GUID parsing details to verify NPC ID extraction
function runTracker.PrintDebugTarget()
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
function runTracker.SaveDebugSimulatedRun(instanceNameArg, durationArg, xpArg)
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

-- Print user-facing status for active or paused runs
function runTracker.PrintStatus()
    if not HasTrackedRun() then
        print(common.Message("WIT", "No active instance run was detected."))
        return
    end

    local displayState = state == STATE_PAUSED and "paused" or "active"
    print(string_format("%s[WIT] %sState: %s%s%s. Instance: %s%s%s. Time passed: %s%s%s.|r",
        COLOR.ORANGE,
        COLOR.YELLOW,
        COLOR.ORANGE, displayState, COLOR.YELLOW,
        COLOR.ORANGE, instanceName, COLOR.YELLOW,
        COLOR.ORANGE, FormatTableTime(GetElapsedSeconds()), COLOR.YELLOW))
end

-- Start tracking manually from the current party instance
function runTracker.StartManual()
    if not instanceTrackingEnabled then
        print(common.Message("WIT", "Instance tracking is disabled. Enable it in /wit config first."))
        return
    end

    if HasTrackedRun() then
        print(common.Message("WIT", "Existing instance run was detected, no action was done."))
        return
    end

    if state == STATE_IGNORED_IN_PROGRESS then
        print(common.Message("WIT", "This instance was marked as in progress. This run will not count towards statistics."))
        return
    end

    local resolvedInstanceName, isPartyInstance, hasValidStatus = ResolveCurrentPartyInstanceName()
    if not hasValidStatus then
        print(common.ErrorMessage("WIT", "check instance status"))
        return
    end

    if not isPartyInstance then
        print(common.Message("WIT", "No party instance was detected."))
        return
    end

    StartInstanceTracking(resolvedInstanceName, "manual")
end

-- End current run, optionally saving it to persistent stats
function runTracker.EndManual(saveRun)
    if not HasTrackedRun() then
        print(common.Message("WIT", "No active instance tracking was detected."))
        return
    end

    ProcessInstanceCompletion(saveRun == true, false)
end

-- Reset current run and start fresh for the same/current instance
function runTracker.ResetManual()
    if not HasTrackedRun() then
        print(common.Message("WIT", "No active instance tracking was detected."))
        return
    end

    local resolvedInstanceName = instanceName
    local currentInstanceName, isPartyInstance = ResolveCurrentPartyInstanceName()
    if isPartyInstance and type(currentInstanceName) == "string" and currentInstanceName ~= "" then
        resolvedInstanceName = currentInstanceName
    end

    ResetInstanceTrackingState()
    StartInstanceTracking(resolvedInstanceName, "manual")
end

-- Pause current run and freeze all tracked counters
function runTracker.PauseManual()
    if state == STATE_PAUSED then
        print(common.Message("WIT", "The instance run is already paused. To continue tracking, run /wit continue."))
        return
    end

    if state ~= STATE_ACTIVE then
        print(common.Message("WIT", "No active instance tracking was detected."))
        return
    end

    UpdateTrackedXP()
    state = STATE_PAUSED
    pauseStartedAt = time()
    pendingKillCount = 0
    lastKillEventAt = 0
    PersistActiveRun(false)
    print(InstanceActionMessage("Paused tracking of ", instanceName, "."))
end

-- Resume a paused run without counting XP earned while paused
function runTracker.ContinueManual()
    if state ~= STATE_PAUSED then
        print(common.Message("WIT", "No paused tracking to continue with was detected."))
        return
    end

    if pauseStartedAt > 0 then
        pausedDuration = pausedDuration + (time() - pauseStartedAt)
    end
    pauseStartedAt = 0
    state = STATE_ACTIVE
    CaptureXPCheckpoint()
    PersistActiveRun(false)
    print(InstanceActionMessage("Continued tracking of ", instanceName, "."))
end

-- Complete delayed automatic starts after reliable in-progress signals had a chance to arrive
function runTracker.HandleUpdate()
    if HasPendingStart() and (GetTime() - pendingStartAt) >= AUTO_START_DELAY then
        local scheduledInstanceName = pendingStartInstanceName
        local scheduledStartTime = pendingStartWallTime
        ClearPendingStart()

        if state == STATE_INACTIVE and instanceTrackingEnabled then
            local resolvedInstanceName, isPartyInstance, hasValidStatus = ResolveCurrentPartyInstanceName()
            if not hasValidStatus then
                print(common.ErrorMessage("WIT", "check instance status"))
            elseif isPartyInstance and AreInstanceNamesEquivalent(scheduledInstanceName, resolvedInstanceName) then
                if pendingInProgressName then
                    MarkIgnoredInProgress(resolvedInstanceName)
                else
                    StartInstanceTracking(resolvedInstanceName, "auto", scheduledStartTime)
                end
            end
        end
    end

    if HasPendingCompletion() and (GetTime() - pendingCompletionAt) >= COMPLETION_XP_SETTLE_DELAY then
        local saveRun = pendingCompletionSaveRun
        local sendPartySummary = pendingCompletionSendPartySummary
        ClearPendingCompletion()
        ProcessInstanceCompletion(saveRun, sendPartySummary)
    end

    RefreshScheduledUpdateEnabled()
end

-- Route supported game events into the run tracker
function runTracker.HandleEvent(event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        HandleCombatLogEvent(...)
    elseif event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" then
        HandleXPUpdate()
    elseif event == "PLAYER_DEAD" then
        if HasTrackedRun() and instanceTrackingEnabled then
            isCorpseRunning = true
        end
    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        if HasTrackedRun() then
            isCorpseRunning = false
            CaptureXPCheckpoint()
            PersistActiveRun(false)
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        if event == "PLAYER_ENTERING_WORLD" then
            TryRestoreActiveRun()
        end
        RefreshInstanceTrackingContext(event)
    elseif event == "PLAYER_LOGOUT" then
        PersistActiveRun(true)
    elseif event == "PARTY_MEMBERS_CHANGED" then
        HandleGroupChanged()
    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" and HasTrackedRun() and runHadGroup and not HasActiveInstanceGroup() then
            AbortCurrentRun(GetRecentGroupLossReason())
        end
    elseif event == "CHAT_MSG_SYSTEM" then
        HandleSystemMessage(...)
    elseif event == "LFG_PROPOSAL_SHOW" or event == "LFG_PROPOSAL_UPDATE" then
        CaptureLFGProposalProgress()
    end
end

addon.runTracker = runTracker

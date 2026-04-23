local addonName, addon = ...

-- Cache frequently used functions
local print = print
local tonumber = tonumber
local type = type
local string_format = string.format
local string_lower = string.lower
local strtrim = strtrim
local strsplit = strsplit

local common = addon.common
local runTracker = addon.runTracker

local slashCommands = {}

-- Print slash command help text
local function PrintHelp()
    print(common.Message("WIT", "Available commands:"))
    print("  |cFFFF8000/wit |cFFFFFF00- Open or close the stats table|r")
    print("  |cFFFF8000/wit config |cFFFFFF00- Open or close the settings window|r")
    print("  |cFFFF8000/wit status |cFFFFFF00- Show current tracking state|r")
    print("  |cFFFF8000/wit update |cFFFFFF00- Update saved rows with this character's current level|r")
    print("  |cFFFF8000/wit start |cFFFFFF00- Start tracking the current instance|r")
    print("  |cFFFF8000/wit -s |cFFFFFF00- Short version of /wit start|r")
    print("  |cFFFF8000/wit end |cFFFFFF00- End tracking without saving statistics|r")
    print("  |cFFFF8000/wit end -s |cFFFFFF00- End tracking and save statistics|r")
    print("  |cFFFF8000/wit -e |cFFFFFF00- Short version of /wit end|r")
    print("  |cFFFF8000/wit reset |cFFFFFF00- Restart the current tracking run|r")
    print("  |cFFFF8000/wit pause |cFFFFFF00- Pause the current tracking run|r")
    print("  |cFFFF8000/wit -p |cFFFFFF00- Short version of /wit pause|r")
    print("  |cFFFF8000/wit continue |cFFFFFF00- Continue a paused tracking run|r")
    print("  |cFFFF8000/wit -c |cFFFFFF00- Short version of /wit continue|r")
    print("  |cFFFF8000/wit debug |cFFFFFF00- Show debug subcommands|r")
    print("  |cFFFF8000/wit help |cFFFFFF00- Show this help|r")
    print("  |cFFFF8000/wit -h |cFFFFFF00- Short version of /wit help|r")
end

-- Print help text for debug subcommands
local function PrintDebugHelp()
    print(common.Message("WIT", "Debug commands:"))
    print("  |cFFFF8000/wit debug help |cFFFFFF00- Show debug command help|r")
    print("  |cFFFF8000/wit debug on |cFFFFFF00-    Enable boss-only chat debug + optional all-deaths SavedVariables log|r")
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

-- Manage persistent death-log capture for all unit deaths during debug mode
local function HandleDebugLog(args)
    local trimmedArgs = strtrim(args or "")
    local logSubcommand, logArgs = strsplit(" ", trimmedArgs, 2)
    logSubcommand = (logSubcommand and logSubcommand ~= "") and string_lower(logSubcommand) or "status"
    logArgs = strtrim(logArgs or "")

    if logSubcommand == "status" then
        if logArgs ~= "" then
            print(common.ErrorMessage("WIT", "execute command. Wrong number of arguments for 'debug log status' (expected 0)"))
            return
        end
        print(common.Message("WIT", "Debug death log capture", runTracker.IsDebugLoggingEnabled() and "enabled" or "disabled", true))
        print(common.Message("WIT", "Debug death log entries", tostring(runTracker.GetDebugDeathLogCount()), true))
        return
    end

    if logSubcommand == "on" then
        if logArgs ~= "" then
            print(common.ErrorMessage("WIT", "execute command. Wrong number of arguments for 'debug log on' (expected 0)"))
            return
        end
        runTracker.SetDebugLoggingEnabled(true)
        print(common.Message("WIT", "Debug death log capture", "enabled", true))
        return
    end

    if logSubcommand == "off" then
        if logArgs ~= "" then
            print(common.ErrorMessage("WIT", "execute command. Wrong number of arguments for 'debug log off' (expected 0)"))
            return
        end
        runTracker.SetDebugLoggingEnabled(false)
        print(common.Message("WIT", "Debug death log capture", "disabled", true))
        return
    end

    if logSubcommand == "clear" then
        if logArgs ~= "" then
            print(common.ErrorMessage("WIT", "execute command. Wrong number of arguments for 'debug log clear' (expected 0)"))
            return
        end
        runTracker.ClearDebugDeathLog()
        print(common.Message("WIT", "Debug death log", "cleared", true))
        return
    end

    print(common.ErrorMessage("WIT", string_format(
        "find subcommand '%s'. Use /wit debug help to see available commands", "debug log " .. logSubcommand)))
end

-- Save a synthetic run to avoid long dungeon test loops
local function HandleDebugSimulate(args)
    local trimmedArgs = strtrim(args or "")
    local instanceNameArg, durationArg, xpArg = ParseSimulateArguments(trimmedArgs)

    if not instanceNameArg or not durationArg or not xpArg then
        print(common.ErrorMessage("WIT", "execute command. Wrong number of arguments for 'debug simulate' (expected 3)"))
        return
    end

    runTracker.SaveDebugSimulatedRun(instanceNameArg, durationArg, xpArg)
end

-- Handle all /wit debug subcommands
local function HandleDebug(args)
    local trimmedArgs = strtrim(args or "")
    if trimmedArgs == "" then
        PrintDebugHelp()
        return
    end

    local debugSubcommand, debugArgs = strsplit(" ", trimmedArgs, 2)
    debugSubcommand = debugSubcommand and string_lower(debugSubcommand) or ""
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
        runTracker.SetDebugPrintingEnabled(true)
        print(common.Message("WIT", "Debug mode", "enabled (boss-only chat output)", true))
        return
    end

    if debugSubcommand == "off" then
        if debugArgs ~= "" then
            print(common.ErrorMessage("WIT", "execute command. Wrong number of arguments for 'debug off' (expected 0)"))
            return
        end
        runTracker.SetDebugPrintingEnabled(false)
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
        runTracker.PrintDebugState()
        return
    end

    if debugSubcommand == "target" then
        if debugArgs ~= "" then
            print(common.ErrorMessage("WIT", "execute command. Wrong number of arguments for 'debug target' (expected 0)"))
            return
        end
        runTracker.PrintDebugTarget()
        return
    end

    if debugSubcommand == "simulate" then
        HandleDebugSimulate(debugArgs)
        return
    end

    print(common.ErrorMessage("WIT", string_format(
        "find subcommand '%s'. Use /wit debug help to see available commands", debugSubcommand)))
end

-- Handle /wit end optional save flag
local function HandleEnd(args)
    local trimmedArgs = strtrim(args or "")
    local normalizedArgs = string_lower(trimmedArgs)
    if trimmedArgs == "" then
        runTracker.EndManual(false)
        return
    end

    if normalizedArgs == "-s" then
        runTracker.EndManual(true)
        return
    end

    local firstArg, extraArg = strsplit(" ", trimmedArgs, 2)
    if extraArg and extraArg ~= "" then
        print(common.ErrorMessage("WIT", "execute command. Wrong number of arguments for 'end' (expected 0 or 1)"))
        return
    end

    print(common.ErrorMessage("WIT", string_format(
        "execute command. Invalid argument for 'end' (expected -s, got '%s')", firstArg)))
end

-- Define available slash subcommands and aliases
local function BuildSubcommands(options)
    return {
        ["config"] = { handler = options.toggleConfig, args = 0 },
        ["debug"] = { handler = HandleDebug },
        ["help"] = { handler = PrintHelp, args = 0 },
        ["-h"] = { handler = PrintHelp, args = 0 },
        ["status"] = { handler = runTracker.PrintStatus, args = 0 },
        ["update"] = { handler = runTracker.UpdateCurrentCharacterLevel, args = 0 },
        ["start"] = { handler = runTracker.StartManual, args = 0 },
        ["-s"] = { handler = runTracker.StartManual, args = 0 },
        ["end"] = { handler = HandleEnd },
        ["-e"] = { handler = HandleEnd },
        ["reset"] = { handler = runTracker.ResetManual, args = 0 },
        ["pause"] = { handler = runTracker.PauseManual, args = 0 },
        ["-p"] = { handler = runTracker.PauseManual, args = 0 },
        ["continue"] = { handler = runTracker.ContinueManual, args = 0 },
        ["-c"] = { handler = runTracker.ContinueManual, args = 0 },
    }
end

-- Register slash command parser following Blizzard pattern
function slashCommands.Register(options)
    options = options or {}
    local subcommands = BuildSubcommands(options)

    SLASH_WIT1 = "/wit"
    SlashCmdList["WIT"] = function(msg)
        local rawMsg = strtrim(msg or "")
        local normalizedMsg = string_lower(rawMsg)

        if normalizedMsg == "" then
            if type(options.toggleStatsTable) == "function" then
                options.toggleStatsTable()
            end
            return
        end

        local subcommand = strsplit(" ", normalizedMsg, 2)
        local command = subcommands[subcommand]
        local _, rawArgs = strsplit(" ", rawMsg, 2)
        rawArgs = strtrim(rawArgs or "")

        if not command then
            print(common.ErrorMessage("WIT", string_format(
                "find subcommand '%s'. Use /wit help to see available commands", subcommand)))
            return
        end

        if command.args == 0 and rawArgs ~= "" then
            print(common.ErrorMessage("WIT", string_format(
                "execute command. Wrong number of arguments for '%s' (expected %d)", subcommand, command.args)))
            return
        end

        command.handler(rawArgs)
    end
end

addon.slashCommands = slashCommands

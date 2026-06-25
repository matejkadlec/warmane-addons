local addonName, addon = ...

-- Cache frequently used functions
local print = print
local type = type
local string_format = string.format
local string_lower = string.lower
local strtrim = strtrim
local strsplit = strsplit

local common = addon.common
local runTracker = addon.runTracker

local slashCommands = {}
local ADDON_FULL_NAME = "WarmaneInstanceTracker"

-- Print slash command help text
local function PrintHelp()
    print(common.Message("WIT", "Available commands:"))
    print("  |cFFFF8000/wit |cFFFFFF00- Open or close the stats table|r")
    print("  |cFFFF8000/wit on |cFFFFFF00- Enable instance tracking|r")
    print("  |cFFFF8000/wit off |cFFFFFF00- Disable instance tracking|r")
    print("  |cFFFF8000/wit help |cFFFFFF00- Show this help|r")
end

-- Enable or disable instance tracking without reloading the UI
local function SetAddonEnabled(enabled)
    local currentlyEnabled = type(runTracker.IsInstanceTrackingEnabled) == "function"
        and runTracker.IsInstanceTrackingEnabled()

    if currentlyEnabled == enabled then
        print(common.Message("WIT", string_format("%s is already %s.", ADDON_FULL_NAME, enabled and "enabled" or "disabled")))
        return
    end

    runTracker.SetInstanceTrackingEnabled(enabled)
    print(common.Message("WIT", string_format("%s %s.", ADDON_FULL_NAME, enabled and "enabled" or "disabled")))
end

local function EnableAddon()
    SetAddonEnabled(true)
end

local function DisableAddon()
    SetAddonEnabled(false)
end

-- Define the intentionally small slash subcommand set
local function BuildSubcommands(options)
    return {
        ["on"] = { handler = type(options.enableAddon) == "function" and options.enableAddon or EnableAddon, args = 0 },
        ["off"] = { handler = type(options.disableAddon) == "function" and options.disableAddon or DisableAddon, args = 0 },
        ["help"] = { handler = PrintHelp, args = 0 },
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

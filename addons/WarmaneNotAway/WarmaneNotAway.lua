local addonName = ...

-- Cache frequently used functions
local getglobal = getglobal
local print = print
local type = type
local string_format = string.format
local string_lower = string.lower
local strsplit = strsplit
local strtrim = strtrim
local SetCVar = SetCVar

-- Define color codes
local COLOR = {
    ORANGE = "|cFFFF8000",
    YELLOW = "|cFFFFFF00",
    RED = "|cFFFF0000"
}

local ADDON_PREFIX = "WNA"
local ADDON_FULL_NAME = "WarmaneNotAway"
local DEFAULT_ADDON_ENABLED = true
local PARENT_CATEGORY_NAME = "Warmane AddOns"
local PARENT_PANEL_NAME = "WarmaneAddOnsInterfaceOptionsPanel"

local interfaceOptionsPanel = nil
local interfaceOptionsCheckbox = nil

local RefreshInterfaceOptions

-- Format general messages with colored prefix
local function FormatMessage(prefix, msg)
    if type(prefix) ~= "string" or type(msg) ~= "string" then
        return ""
    end

    return string_format("%s[%s] %s%s|r", COLOR.ORANGE, prefix, COLOR.YELLOW, msg)
end

-- Format error messages with colored prefix and red body
local function FormatErrorMessage(prefix, msg)
    if type(prefix) ~= "string" or type(msg) ~= "string" then return "" end
    return string_format("%s[%s] %sFailed to %s|r",
        COLOR.ORANGE, prefix, COLOR.RED, msg)
end

-- Create the saved settings table and populate validated defaults
local function InitializeSavedData()
    if type(WarmaneNotAwaySettings) ~= "table" then
        WarmaneNotAwaySettings = {}
    end

    if type(WarmaneNotAwaySettings.enabled) ~= "boolean" then
        WarmaneNotAwaySettings.enabled = DEFAULT_ADDON_ENABLED
    end
end

-- Read the current persisted enabled state safely
local function IsAddonEnabled()
    InitializeSavedData()
    return WarmaneNotAwaySettings.enabled
end

-- Persist one validated enabled state
local function SetSavedAddonEnabled(enabled)
    InitializeSavedData()
    WarmaneNotAwaySettings.enabled = enabled and true or false
end

-- Enable built-in AFK auto-clear behavior
local function EnsureAutoClearAFK()
    SetCVar("autoClearAFK", "1")
end

-- Disable built-in AFK auto-clear behavior when this addon is turned off
local function DisableAutoClearAFK()
    SetCVar("autoClearAFK", "0")
end

-- Create frame for event handling
local WNA = CreateFrame("Frame")

-- Register required events
WNA:RegisterEvent("ADDON_LOADED")
WNA:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Handle addon initialization and world transitions
WNA:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        InitializeSavedData()
        if IsAddonEnabled() then
            EnsureAutoClearAFK()
        end
        print(FormatMessage(ADDON_PREFIX, ADDON_FULL_NAME .. " loaded"))
    elseif event == "PLAYER_ENTERING_WORLD" and IsAddonEnabled() then
        EnsureAutoClearAFK()
    end
end)

-- Print help text listing available slash commands
local function PrintHelp()
    print(FormatMessage(ADDON_PREFIX, "Available commands:"))
    print("  |cFFFF8000/wna |cFFFFFF00- Show this help|r")
    print("  |cFFFF8000/wna on |cFFFFFF00- Enable AFK auto-clear|r")
    print("  |cFFFF8000/wna off |cFFFFFF00- Disable AFK auto-clear|r")
    print("  |cFFFF8000/wna help |cFFFFFF00- Show this help|r")
end

-- Enable or disable AFK auto-clear without reloading the UI
local function SetAddonEnabled(enabled)
    local currentlyEnabled = IsAddonEnabled()
    if currentlyEnabled == enabled then
        print(FormatMessage(ADDON_PREFIX, string_format("%s is already %s.", ADDON_FULL_NAME, enabled and "enabled" or "disabled")))
        return
    end

    SetSavedAddonEnabled(enabled)
    if enabled then
        EnsureAutoClearAFK()
    else
        DisableAutoClearAFK()
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
    ["help"] = { handler = PrintHelp, args = 0 }
}

-- Register slash command parser following Blizzard pattern
SLASH_WNA1 = "/wna"
SlashCmdList["WNA"] = function(msg)
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
            "find subcommand '%s'. Use /wna help to see available commands", subcommand)))
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

    interfaceOptionsPanel = CreateFrame("Frame", "WNAInterfaceOptionsPanel")
    interfaceOptionsPanel.name = "Not Away"
    interfaceOptionsPanel.parent = PARENT_CATEGORY_NAME

    local title = interfaceOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", interfaceOptionsPanel, "TOPLEFT", 16, -16)
    title:SetText("Warmane Not Away")

    local header = interfaceOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalMed3")
    header:SetPoint("TOPLEFT", interfaceOptionsPanel, "TOPLEFT", 18, -52)
    header:SetText("User Settings")

    interfaceOptionsCheckbox = CreateFrame("CheckButton", "WNAInterfaceOptionsEnabled", interfaceOptionsPanel, "InterfaceOptionsCheckButtonTemplate")
    interfaceOptionsCheckbox:SetPoint("TOPLEFT", interfaceOptionsPanel, "TOPLEFT", 14, -76)
    getglobal(interfaceOptionsCheckbox:GetName() .. "Text"):SetText("Enable AFK auto-clear")
    interfaceOptionsCheckbox:SetScript("OnClick", function(self)
        SetAddonEnabled(self:GetChecked() and true or false)
    end)

    interfaceOptionsPanel:SetScript("OnShow", RefreshInterfaceOptions)
    interfaceOptionsPanel.refresh = RefreshInterfaceOptions
    interfaceOptionsPanel:Hide()
    InterfaceOptions_AddCategory(interfaceOptionsPanel)
end

RegisterInterfaceOptions()

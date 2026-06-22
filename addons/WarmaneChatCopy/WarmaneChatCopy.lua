-- Initialize addon hooks
local originalChatFrame
local originalSetItemRef

-- Cache frequently used functions
local gsub = gsub
local getglobal = getglobal
local print = print
local string_format = string.format
local string_lower = string.lower
local strfind = strfind
local strmatch = strmatch
local strsub = strsub
local strsplit = strsplit
local strtrim = strtrim
local type = type

-- Import color codes
local COLOR = {
    ORANGE = "|cFFFF8000",
    YELLOW = "|cFFFFFF00",
    RED = "|cFFFF0000"
}

local ADDON_PREFIX = "WCC"
local ADDON_FULL_NAME = "WarmaneChatCopy"
local DEFAULT_COPY_ENABLED = true
local PARENT_CATEGORY_NAME = "Warmane AddOns"
local PARENT_PANEL_NAME = "WarmaneAddOnsInterfaceOptionsPanel"

local interfaceOptionsPanel = nil
local interfaceOptionsCheckbox = nil

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

-- Create the saved settings table and populate validated defaults
local function InitializeSavedData()
    if type(WarmaneChatCopySettings) ~= "table" then
        WarmaneChatCopySettings = {}
    end

    if type(WarmaneChatCopySettings.enabled) ~= "boolean" then
        WarmaneChatCopySettings.enabled = DEFAULT_COPY_ENABLED
    end
end

-- Read the current persisted enabled state safely
local function IsCopyEnabled()
    InitializeSavedData()
    return WarmaneChatCopySettings.enabled
end

-- Persist one validated enabled state
local function SetCopyEnabled(enabled)
    InitializeSavedData()
    WarmaneChatCopySettings.enabled = enabled and true or false
end

function Initialize()
    InitializeSavedData()

    -- Hook chat frame event handler
    if not originalChatFrame then 
        originalChatFrame = ChatFrame_OnEvent 
    end
    ChatFrame_OnEvent = HandleFrameEvent
    
    -- Hook hyperlink handler
    if not originalSetItemRef then 
        originalSetItemRef = SetItemRef 
    end
    SetItemRef = HandleItemRef
    
    -- Set window title
    windowTitle:SetText("WarmaneChatCopy")
end

function HandleFrameEvent(self, event, ...)
    -- Keep last dispatched event so message wrapping can apply event-specific rules.
    self.wccLastEvent = event
    originalChatFrame(self, event, ...)
    
    if not self.originalMessage then 
        self.originalMessage = self.AddMessage
        self.AddMessage = HandleMessage
    end
end

-- Skip copy-wrapping for no-channel loot lines so item links stay tooltip-clickable.
local function ShouldBypassCopyWrap(frame, message)
    if type(message) ~= "string" then
        return false
    end
    if not frame or frame.wccLastEvent ~= "CHAT_MSG_LOOT" then
        return false
    end
    if not strfind(message, "|Hitem:", 1, true) then
        return false
    end
    if strfind(message, "|Hchannel:", 1, true) then
        return false
    end
    return true
end

function HandleMessage(frame, msg, r, g, b, id, ...)
    if not IsCopyEnabled() then
        frame:originalMessage(msg, r, g, b, id, ...)
        return
    end

    if ShouldBypassCopyWrap(frame, msg) then
        frame:originalMessage(msg, r, g, b, id, ...)
        return
    end

    frame:originalMessage(BuildCopyMessage(msg), r, g, b, id, ...)
end

-- Only the channel prefix should trigger copying so player links keep Blizzard behavior.
function BuildCopyMessage(message)
    if not IsCopyEnabled() then
        return message
    end

    if type(message) ~= "string" or not strfind(message, "|Hchannel:", 1, true) then
        return message
    end

    local channelStart, _, displayText, channelEnd = strmatch(message, "()(|Hchannel:[^|]+|h(.-)|h)()")
    if not channelStart then
        return message
    end

    local copyLink = "|Hcopy"..ProcessMessage(message).."|h"..displayText.."|h"
    return strsub(message, 1, channelStart - 1) .. copyLink .. strsub(message, channelEnd)
end

function ProcessMessage(message)
	local msg = ""
	local part = ""
	local mode = 0
	while (strfind(message, "(%d-) |4(.-):(.-);")) do
		local _, _, num, sing, plur = strfind(message, "(%d-) |4(.-):(.-);");
		if (num == "1") then message = gsub(message, "(%d-) |4(.-):(.-);", num.." "..sing, 1);
		else message = gsub(message, "(%d-) |4(.-):(.-);", num.." "..plur, 1);
		end
	end
	local retStat = 0;
	for i = 1, strlen(message) do
		if (message == "") then break end
		if (mode == 0) then
			if (strsub(message, 1, 2) == "|H") then
				mode = 1
				message = strsub(message, 3)
			elseif (strsub(message, 1, 2) == "|T") then
				mode = 3
				retStat = 0
				message = strsub(message, 3)
				part = ""
			elseif (strsub(message, 1, 2) == "||") then
				message = strsub(message, 3)
				msg = msg.."||"
			elseif (strsub(message, 1, 2) == "|c") then message = strsub(message, 11)
			elseif (strsub(message, 1, 2) == "|C") then message = strsub(message, 11)
			elseif (strsub(message, 1, 2) == "|r") then message = strsub(message, 3)
			elseif (strsub(message, 1, 2) == "|R") then message = strsub(message, 3)
			else
				msg = msg..strsub(message, 1, 1)
				message = strsub(message, 2)
			end
		elseif (mode == 1) then
			if (strsub(message, 1, 2) == "|h") then
				mode = 2
				message = strsub(message, 3)
			else message = strsub(message, 2)
			end
		elseif (mode == 2) then
			if (strsub(message, 1, 2) == "|h") then
				mode = 0
				message = strsub(message, 3)
			elseif (strsub(message, 1, 2) == "|T") then
				mode = 3
				retStat = 2
				message = strsub(message, 3)
				part = ""
			elseif (strsub(message, 1, 2) == "||") then
				message = strsub(message, 3)
				msg = msg.."||"
			elseif (strsub(message, 1, 2) == "|c") then message = strsub(message, 11)
			elseif (strsub(message, 1, 2) == "|C") then message = strsub(message, 11)
			elseif (strsub(message, 1, 2) == "|r") then message = strsub(message, 3)
			elseif (strsub(message, 1, 2) == "|R") then message = strsub(message, 3)
			else
				msg = msg..strsub(message, 1, 1)
				message = strsub(message, 2)
			end
		elseif (mode == 3) then
			if (strsub(message, 1, 2) == "|t") then
				mode = retStat
				message = strsub(message, 3)
			else
				part = part..strsub(message, 1, 1)
				message = strsub(message, 2)
			end
		end
	end
	msg = gsub(gsub(msg, "/", "/1"), "|", "/2")
	return msg
end

function HandleItemRef(link, text, button, chatFrame)
    if strsub(link, 1, 4) == "copy" then
        if not IsCopyEnabled() then
            return
        end

        local decodedMessage = gsub(gsub(strsub(link, 5), "/2", "|"), "/1", "/")
        
        if not copyFrame:IsShown() then
            copyFrame:Show()
            copyFrame:SetBackdropColor(0, 0, 0, 0.9)
            messageText:SetFont(DEFAULT_CHAT_FRAME:GetFont())
            messageText:SetText("")
        end
        
        if messageText:GetText() == "" then 
            messageText:SetText(decodedMessage) 
        else 
            messageText:SetText(messageText:GetText().."\n"..decodedMessage) 
        end
        
        messageText:HighlightText()
        messageText:SetFocus()
        return
    end
    
    originalSetItemRef(link, text, button, chatFrame)
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

local function RefreshInterfaceOptions()
    if interfaceOptionsCheckbox then
        interfaceOptionsCheckbox:SetChecked(IsCopyEnabled())
    end
end

-- Print help text listing available slash commands
local function PrintHelp()
    print(FormatMessage(ADDON_PREFIX, "Available commands:"))
    print("  |cFFFF8000/wcc |cFFFFFF00- Show this help|r")
    print("  |cFFFF8000/wcc on |cFFFFFF00- Enable chat copy|r")
    print("  |cFFFF8000/wcc off |cFFFFFF00- Disable chat copy|r")
    print("  |cFFFF8000/wcc help |cFFFFFF00- Show this help|r")
end

-- Enable or disable chat copy without reloading the UI
local function SetAddonEnabled(enabled)
    local currentlyEnabled = IsCopyEnabled()
    if currentlyEnabled == enabled then
        print(FormatMessage(ADDON_PREFIX, string_format("%s is already %s.", ADDON_FULL_NAME, enabled and "enabled" or "disabled")))
        return
    end

    SetCopyEnabled(enabled)

    if not IsCopyEnabled() and copyFrame and copyFrame:IsShown() then
        copyFrame:Hide()
    end

    if IsCopyEnabled() then
        print(FormatMessage(ADDON_PREFIX, ADDON_FULL_NAME .. " enabled."))
    else
        print(FormatMessage(ADDON_PREFIX, ADDON_FULL_NAME .. " disabled."))
    end

    RefreshInterfaceOptions()
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
SLASH_WCC1 = "/wcc"
SlashCmdList["WCC"] = function(msg)
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
            "find subcommand '%s'. Use /wcc help to see available commands", subcommand)))
        return
    end

    if command.args == 0 and rawArgs ~= "" then
        print(FormatErrorMessage(ADDON_PREFIX, string_format(
            "execute command. Wrong number of arguments for '%s' (expected %d)", subcommand, command.args)))
        return
    end

    command.handler(rawArgs)
end

local function RegisterInterfaceOptions()
    local function OpenPanel()
        if interfaceOptionsPanel and type(InterfaceOptionsFrame_OpenToCategory) == "function" then
            InterfaceOptionsFrame_OpenToCategory(interfaceOptionsPanel)
        end
    end

    EnsureWarmaneAddOnsCategory(OpenPanel)

    interfaceOptionsPanel = CreateFrame("Frame", "WCCInterfaceOptionsPanel")
    interfaceOptionsPanel.name = "Chat Copy"
    interfaceOptionsPanel.parent = PARENT_CATEGORY_NAME

    local title = interfaceOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", interfaceOptionsPanel, "TOPLEFT", 16, -16)
    title:SetText("Warmane Chat Copy")

    local header = interfaceOptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetPoint("TOPLEFT", interfaceOptionsPanel, "TOPLEFT", 18, -52)
    header:SetText("User settings")

    interfaceOptionsCheckbox = CreateFrame("CheckButton", "WCCInterfaceOptionsEnabled", interfaceOptionsPanel, "InterfaceOptionsCheckButtonTemplate")
    interfaceOptionsCheckbox:SetPoint("TOPLEFT", interfaceOptionsPanel, "TOPLEFT", 14, -76)
    getglobal(interfaceOptionsCheckbox:GetName() .. "Text"):SetText("Enable chat copy")
    interfaceOptionsCheckbox:SetScript("OnClick", function(self)
        SetAddonEnabled(self:GetChecked() and true or false)
    end)

    interfaceOptionsPanel:SetScript("OnShow", RefreshInterfaceOptions)
    interfaceOptionsPanel.refresh = RefreshInterfaceOptions
    interfaceOptionsPanel:Hide()
    InterfaceOptions_AddCategory(interfaceOptionsPanel)
end

RegisterInterfaceOptions()

-- Print loading message
print(FormatMessage(ADDON_PREFIX, "WarmaneChatCopy loaded"))

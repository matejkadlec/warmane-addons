local addonName, addon = ...

local getglobal = getglobal
local type = type

addon.ui = addon.ui or {}

local frameNames = (addon.vars and addon.vars.FRAME_NAMES) or {
    config = "WITConfigFrame"
}

-- Create and manage the settings frame for user/developer toggles
addon.ui.CreateConfigFrame = function(options)
    options = options or {}

    local configFrame = nil
    local configCheckboxes = {}

    local function RefreshCheckboxes()
        if not configFrame or not options.getState then
            return
        end

        local state = options.getState() or {}
        if configCheckboxes.enableInstanceTracking then
            configCheckboxes.enableInstanceTracking:SetChecked(state.instanceTrackingEnabled and true or false)
        end
        if configCheckboxes.enablePartyMessage then
            configCheckboxes.enablePartyMessage:SetChecked(state.partyMessageEnabled and true or false)
        end
        if configCheckboxes.enableDebugPrinting then
            configCheckboxes.enableDebugPrinting:SetChecked(state.debugMode and true or false)
        end
        if configCheckboxes.enableDebugLogging then
            configCheckboxes.enableDebugLogging:SetChecked(state.debugLoggingEnabled and true or false)
        end
    end

    local function NotifyVisibilityChanged()
        if type(options.onVisibilityChanged) == "function" then
            options.onVisibilityChanged()
        end
    end

    local function CreateFrameIfNeeded()
        if configFrame then
            return
        end

        configFrame = CreateFrame("Frame", frameNames.config, UIParent)
        configFrame:SetWidth(360)
        configFrame:SetHeight(250)
        configFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        configFrame:SetFrameStrata("DIALOG")
        configFrame:SetToplevel(true)
        configFrame:EnableMouse(true)
        configFrame:SetMovable(true)
        configFrame:RegisterForDrag("LeftButton")
        configFrame:SetScript("OnDragStart", function(self)
            self:StartMoving()
        end)
        configFrame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
        end)
        configFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        configFrame:SetBackdropColor(0, 0, 0, 0.97)
        configFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        configFrame:Hide()

        local title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", configFrame, "TOP", 0, -16)
        title:SetText("Warmane Instace Tracker Settings")

        local closeButton = CreateFrame("Button", nil, configFrame, "UIPanelCloseButton")
        closeButton:SetPoint("TOPRIGHT", configFrame, "TOPRIGHT", -5, -5)

        local userHeader = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        userHeader:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 18, -44)
        userHeader:SetText("User settings")

        local userTracking = CreateFrame("CheckButton", "WITConfigEnableInstanceTracking", configFrame, "InterfaceOptionsCheckButtonTemplate")
        userTracking:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 14, -66)
        getglobal(userTracking:GetName() .. "Text"):SetText("Enable instance tracking")
        userTracking:SetScript("OnClick", function(self)
            if type(options.onSetInstanceTracking) == "function" then
                options.onSetInstanceTracking(self:GetChecked() and true or false)
            end
        end)

        local userPartyMessage = CreateFrame("CheckButton", "WITConfigEnablePartyMessage", configFrame, "InterfaceOptionsCheckButtonTemplate")
        userPartyMessage:SetPoint("TOPLEFT", userTracking, "BOTTOMLEFT", 0, -8)
        getglobal(userPartyMessage:GetName() .. "Text"):SetText("Enable party message")
        userPartyMessage:SetScript("OnClick", function(self)
            if type(options.onSetPartyMessage) == "function" then
                options.onSetPartyMessage(self:GetChecked() and true or false)
            end
        end)

        local devHeader = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        devHeader:SetPoint("TOPLEFT", userPartyMessage, "BOTTOMLEFT", 4, -20)
        devHeader:SetText("Developer settings")

        local devDebugPrinting = CreateFrame("CheckButton", "WITConfigEnableDebugPrinting", configFrame, "InterfaceOptionsCheckButtonTemplate")
        devDebugPrinting:SetPoint("TOPLEFT", devHeader, "BOTTOMLEFT", -4, -6)
        getglobal(devDebugPrinting:GetName() .. "Text"):SetText("Enable debug printing")
        devDebugPrinting:SetScript("OnClick", function(self)
            if type(options.onSetDebugPrinting) == "function" then
                options.onSetDebugPrinting(self:GetChecked() and true or false)
            end
        end)

        local devDebugLogging = CreateFrame("CheckButton", "WITConfigEnableDebugLogging", configFrame, "InterfaceOptionsCheckButtonTemplate")
        devDebugLogging:SetPoint("TOPLEFT", devDebugPrinting, "BOTTOMLEFT", 0, -8)
        getglobal(devDebugLogging:GetName() .. "Text"):SetText("Enable debug logging")
        devDebugLogging:SetScript("OnClick", function(self)
            if type(options.onSetDebugLogging) == "function" then
                options.onSetDebugLogging(self:GetChecked() and true or false)
            end
        end)

        configCheckboxes = {
            enableInstanceTracking = userTracking,
            enablePartyMessage = userPartyMessage,
            enableDebugPrinting = devDebugPrinting,
            enableDebugLogging = devDebugLogging
        }

        configFrame:SetScript("OnShow", function()
            RefreshCheckboxes()
            NotifyVisibilityChanged()
        end)
        configFrame:SetScript("OnHide", function()
            NotifyVisibilityChanged()
        end)
    end

    return {
        Toggle = function()
            CreateFrameIfNeeded()
            if configFrame:IsShown() then
                configFrame:Hide()
            else
                configFrame:Show()
            end
        end,
        RefreshCheckboxes = function()
            RefreshCheckboxes()
        end,
        IsShown = function()
            return configFrame and configFrame:IsShown() or false
        end
    }
end

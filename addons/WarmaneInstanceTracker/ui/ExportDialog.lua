local addonName, addon = ...

local type = type

addon.ui = addon.ui or {}

local frameNames = (addon.vars and addon.vars.FRAME_NAMES) or {
    export = "WITExportFrame"
}

-- Create and manage the CSV export dialog
addon.ui.CreateExportDialog = function(options)
    options = options or {}

    local exportFrame = nil
    local exportEditBox = nil

    local function NotifyVisibilityChanged()
        if type(options.onVisibilityChanged) == "function" then
            options.onVisibilityChanged()
        end
    end

    local function CreateFrameIfNeeded()
        if exportFrame then
            return
        end

        exportFrame = CreateFrame("Frame", frameNames.export, UIParent)
        exportFrame:SetWidth(620)
        exportFrame:SetHeight(400)
        exportFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        exportFrame:SetFrameStrata("DIALOG")
        exportFrame:SetToplevel(true)
        exportFrame:EnableMouse(true)
        exportFrame:SetMovable(true)
        exportFrame:RegisterForDrag("LeftButton")
        exportFrame:SetScript("OnDragStart", function(self)
            self:StartMoving()
        end)
        exportFrame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
        end)
        exportFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        exportFrame:SetBackdropColor(0, 0, 0, 0.97)
        exportFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        exportFrame:Hide()

        local title = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", exportFrame, "TOP", 0, -16)
        title:SetText("Warmane Instance Tracker - Export")

        local closeButton = CreateFrame("Button", nil, exportFrame, "UIPanelCloseButton")
        closeButton:SetPoint("TOPRIGHT", exportFrame, "TOPRIGHT", -5, -5)

        local scrollFrame = CreateFrame("ScrollFrame", "WITExportScrollFrame", exportFrame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", exportFrame, "TOPLEFT", 18, -48)
        scrollFrame:SetPoint("BOTTOMRIGHT", exportFrame, "BOTTOMRIGHT", -34, 52)

        exportEditBox = CreateFrame("EditBox", "WITExportEditBox", scrollFrame)
        exportEditBox:SetMultiLine(true)
        exportEditBox:SetAutoFocus(false)
        exportEditBox:SetFontObject(ChatFontNormal)
        exportEditBox:SetWidth(540)
        exportEditBox:SetHeight(3000)
        exportEditBox:SetScript("OnEscapePressed", function()
            exportFrame:Hide()
        end)
        exportEditBox:SetScript("OnEditFocusGained", function(self)
            self:HighlightText()
        end)
        scrollFrame:SetScrollChild(exportEditBox)

        local cancelButton = CreateFrame("Button", nil, exportFrame, "UIPanelButtonTemplate")
        cancelButton:SetWidth(90)
        cancelButton:SetHeight(22)
        cancelButton:SetPoint("BOTTOMRIGHT", exportFrame, "BOTTOMRIGHT", -18, 18)
        cancelButton:SetText("Cancel")
        cancelButton:SetScript("OnClick", function()
            exportFrame:Hide()
        end)

        exportFrame:SetScript("OnShow", function()
            NotifyVisibilityChanged()
        end)
        exportFrame:SetScript("OnHide", function()
            if exportEditBox then
                exportEditBox:ClearFocus()
            end
            NotifyVisibilityChanged()
        end)
    end

    return {
        Show = function(csvText)
            CreateFrameIfNeeded()
            exportEditBox:SetText(csvText or "")
            exportFrame:Show()
            exportEditBox:SetFocus()
            exportEditBox:HighlightText()
        end,
        Hide = function()
            if exportFrame then
                exportFrame:Hide()
            end
        end,
        IsShown = function()
            return exportFrame and exportFrame:IsShown() or false
        end
    }
end

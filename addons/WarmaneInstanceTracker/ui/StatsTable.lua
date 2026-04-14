local addonName, addon = ...

local type = type
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local math_floor = math.floor
local string_format = string.format
local string_gsub = string.gsub

addon.ui = addon.ui or {}

local vars = addon.vars or {}
local TABLE_ROWS_DISPLAYED = vars.TABLE_ROWS_DISPLAYED or 12
local TABLE_ROW_HEIGHT = vars.TABLE_ROW_HEIGHT or 20
local TABLE_COLUMN_SPACING = vars.TABLE_COLUMN_SPACING or 8
local TABLE_COLUMNS = vars.TABLE_COLUMNS or {}
local frameNames = vars.FRAME_NAMES or {
    stats = "WITStatsFrame"
}

-- Build and manage the run-statistics table frame
addon.ui.CreateStatsTable = function(options)
    options = options or {}

    local utils = addon.utils

    local statsFrame = nil
    local statsScrollFrame = nil
    local statsRows = {}
    local statsRowsData = {}
    local statsEmptyText = nil
    local instanceLevelRangesByName = nil

    local function BuildInstanceLevelRanges()
        local ranges = {}

        if type(GetLFDChoiceInfo) ~= "function" then
            return ranges
        end

        local seeded = {}
        local success, result = pcall(GetLFDChoiceInfo, seeded)
        local infoTable = seeded
        if success and type(result) == "table" then
            infoTable = result
        end
        if type(infoTable) ~= "table" then
            return ranges
        end

        for _, info in pairs(infoTable) do
            if type(info) == "table" then
                local dungeonName = info[1]
                local minLevel = info[3]
                local maxLevel = info[4]

                if type(dungeonName) == "string" and dungeonName ~= "" and
                    type(minLevel) == "number" and minLevel > 0 and
                    type(maxLevel) == "number" and maxLevel > 0 then
                    local existing = ranges[dungeonName]
                    if not existing then
                        ranges[dungeonName] = { minLevel = minLevel, maxLevel = maxLevel }
                    else
                        if minLevel < existing.minLevel then
                            existing.minLevel = minLevel
                        end
                        if maxLevel > existing.maxLevel then
                            existing.maxLevel = maxLevel
                        end
                    end
                end
            end
        end

        return ranges
    end

    local function FormatInstanceNameWithLevelRange(rawName)
        if type(rawName) ~= "string" or rawName == "" then
            return ""
        end

        if type(instanceLevelRangesByName) ~= "table" then
            instanceLevelRangesByName = BuildInstanceLevelRanges()
        end

        local range = instanceLevelRangesByName[rawName]
        if type(range) ~= "table" then
            return rawName
        end

        local minLevel = range.minLevel
        local maxLevel = range.maxLevel
        if type(minLevel) ~= "number" or type(maxLevel) ~= "number" then
            return rawName
        end

        return string_format("%s (%d-%d)", rawName, minLevel, maxLevel)
    end

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

    local function UpdateRows()
        if not statsFrame or not statsScrollFrame then
            return
        end

        local totalRows = #statsRowsData
        FauxScrollFrame_Update(statsScrollFrame, totalRows, TABLE_ROWS_DISPLAYED, TABLE_ROW_HEIGHT)

        local offset = FauxScrollFrame_GetOffset(statsScrollFrame)

        for i = 1, TABLE_ROWS_DISPLAYED do
            local row = statsRows[i]
            local data = statsRowsData[offset + i]

            if data then
                row.cells.character:SetText(data.character or "")
                row.cells.instanceName:SetText(FormatInstanceNameWithLevelRange(data.instanceName))
                row.cells.totalRuns:SetText(tostring(data.totalRuns or 0))
                row.cells.averageXP:SetText(FormatNumberWithCommas(data.averageXP or 0))
                row.cells.averageTime:SetText(FormatTableTime(data.averageTime or 0))
                row.cells.fastestTime:SetText(FormatTableTime(data.fastestTime or 0))
                row:Show()
            else
                row:Hide()
            end
        end

        if totalRows == 0 then
            statsEmptyText:Show()
        else
            statsEmptyText:Hide()
        end
    end

    local function Refresh()
        if not statsFrame then
            return
        end

        statsRowsData = utils.GetAllInstanceStatsRows()
        UpdateRows()
    end

    local function NotifyVisibilityChanged()
        if type(options.onVisibilityChanged) == "function" then
            options.onVisibilityChanged()
        end
    end

    local function CreateFrameIfNeeded()
        if statsFrame then
            return
        end

        statsFrame = CreateFrame("Frame", frameNames.stats, UIParent)
        statsFrame:SetWidth(720)
        statsFrame:SetHeight(360)
        statsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        statsFrame:SetFrameStrata("DIALOG")
        statsFrame:SetToplevel(true)
        statsFrame:EnableMouse(true)
        statsFrame:SetMovable(true)
        statsFrame:RegisterForDrag("LeftButton")
        statsFrame:SetScript("OnDragStart", function(self)
            self:StartMoving()
        end)
        statsFrame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
        end)
        statsFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        statsFrame:SetBackdropColor(0, 0, 0, 0.88)
        statsFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        statsFrame:Hide()

        local title = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", statsFrame, "TOP", 0, -16)
        title:SetText("Warmane Instance Tracker - Run Statistics")

        local closeButton = CreateFrame("Button", nil, statsFrame, "UIPanelCloseButton")
        closeButton:SetPoint("TOPRIGHT", statsFrame, "TOPRIGHT", -5, -5)

        local configButton = CreateFrame("Button", nil, statsFrame, "UIPanelButtonTemplate")
        configButton:SetWidth(80)
        configButton:SetHeight(18)
        configButton:SetPoint("TOPRIGHT", closeButton, "TOPLEFT", -2, -7)
        configButton:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
        configButton:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
        configButton:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight", "ADD")
        if configButton:GetNormalTexture() then
            configButton:GetNormalTexture():SetAllPoints(configButton)
            configButton:GetNormalTexture():SetVertexColor(0.85, 0.12, 0.12, 1)
        end
        if configButton:GetPushedTexture() then
            configButton:GetPushedTexture():SetAllPoints(configButton)
            configButton:GetPushedTexture():SetVertexColor(0.70, 0.08, 0.08, 1)
        end
        if configButton:GetHighlightTexture() then
            configButton:GetHighlightTexture():SetAllPoints(configButton)
            configButton:GetHighlightTexture():SetVertexColor(1, 0.35, 0.35, 0.8)
        end
        configButton:SetText("Settings")
        local configButtonLabel = configButton:GetFontString()
        if configButtonLabel then
            configButtonLabel:SetTextColor(1, 0.82, 0, 1)
            configButtonLabel:SetShadowColor(0, 0, 0, 1)
            configButtonLabel:SetShadowOffset(1, -1)
            configButtonLabel:ClearAllPoints()
            configButtonLabel:SetPoint("CENTER", configButton, "CENTER", 0, 0)
        end
        configButton:SetScript("OnClick", function()
            if type(options.toggleConfig) == "function" then
                options.toggleConfig()
            end
        end)

        local headerBackground = statsFrame:CreateTexture(nil, "ARTWORK")
        headerBackground:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 12, -36)
        headerBackground:SetPoint("TOPRIGHT", statsFrame, "TOPRIGHT", -12, -36)
        headerBackground:SetHeight(22)
        headerBackground:SetTexture(0.2, 0.2, 0.2, 0.6)

        local bodyBackground = statsFrame:CreateTexture(nil, "BORDER")
        bodyBackground:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 12, -58)
        bodyBackground:SetPoint("BOTTOMRIGHT", statsFrame, "BOTTOMRIGHT", -12, 20)
        bodyBackground:SetTexture(0, 0, 0, 0.25)

        local totalColumnWidth = 0
        for _, column in ipairs(TABLE_COLUMNS) do
            local header = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            header:SetWidth(column.width)
            header:SetJustifyH(column.justify)
            header:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 16 + totalColumnWidth, -42)
            header:SetText(column.label)

            totalColumnWidth = totalColumnWidth + column.width + TABLE_COLUMN_SPACING
        end

        statsScrollFrame = CreateFrame("ScrollFrame", "WITStatsScrollFrame", statsFrame, "FauxScrollFrameTemplate")
        statsScrollFrame:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 16, -58)
        statsScrollFrame:SetPoint("BOTTOMRIGHT", statsFrame, "BOTTOMRIGHT", -12, 20)
        statsScrollFrame:SetScript("OnVerticalScroll", function(self, offset)
            FauxScrollFrame_OnVerticalScroll(self, offset, TABLE_ROW_HEIGHT, UpdateRows)
        end)

        for i = 1, TABLE_ROWS_DISPLAYED do
            local row = CreateFrame("Frame", nil, statsFrame)
            row:SetWidth(totalColumnWidth - TABLE_COLUMN_SPACING)
            row:SetHeight(TABLE_ROW_HEIGHT)
            row:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 16, -60 - ((i - 1) * TABLE_ROW_HEIGHT))
            row.cells = {}

            if i % 2 == 0 then
                row.altBackground = row:CreateTexture(nil, "BACKGROUND")
                row.altBackground:SetAllPoints(row)
                row.altBackground:SetTexture(1, 1, 1, 0.03)
            end

            local offsetX = 0
            for _, column in ipairs(TABLE_COLUMNS) do
                local cell = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                cell:SetWidth(column.width)
                cell:SetJustifyH(column.justify)
                cell:SetPoint("LEFT", row, "LEFT", offsetX, 0)
                row.cells[column.key] = cell

                offsetX = offsetX + column.width + TABLE_COLUMN_SPACING
            end

            statsRows[i] = row
        end

        statsEmptyText = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        statsEmptyText:SetPoint("CENTER", statsFrame, "CENTER", 0, -10)
        statsEmptyText:SetText("|cFFFFFF00No tracked runs yet. Complete a dungeon to populate this table.|r")
        statsEmptyText:Hide()

        statsFrame:SetScript("OnShow", function()
            Refresh()
            NotifyVisibilityChanged()
        end)
        statsFrame:SetScript("OnHide", function()
            NotifyVisibilityChanged()
        end)
    end

    return {
        Toggle = function()
            CreateFrameIfNeeded()
            if statsFrame:IsShown() then
                statsFrame:Hide()
            else
                statsFrame:Show()
            end
        end,
        Refresh = function()
            Refresh()
        end,
        IsShown = function()
            return statsFrame and statsFrame:IsShown() or false
        end
    }
end

local addonName, addon = ...

local type = type
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local table_concat = table.concat
local table_sort = table.sort
local math_floor = math.floor
local string_format = string.format
local string_find = string.find
local string_gsub = string.gsub
local string_lower = string.lower
local strtrim = strtrim
local UnitName = UnitName
local UnitLevel = UnitLevel

addon.ui = addon.ui or {}

local vars = addon.vars or {}
local TABLE_ROWS_DISPLAYED = vars.TABLE_ROWS_DISPLAYED or 12
local TABLE_ROW_HEIGHT = vars.TABLE_ROW_HEIGHT or 20
local TABLE_COLUMN_SPACING = vars.TABLE_COLUMN_SPACING or 6
local TABLE_COLUMNS = vars.TABLE_COLUMNS or {}
local frameNames = vars.FRAME_NAMES or {
    stats = "WITStatsFrame"
}

-- Keep the table frame width tied to configured columns instead of a fixed gutter
local function CalculateTableContentWidth()
    local width = 0

    for index, column in ipairs(TABLE_COLUMNS) do
        width = width + (column.width or 0)
        if index < #TABLE_COLUMNS then
            width = width + TABLE_COLUMN_SPACING
        end
    end

    return width
end

-- Build and manage the run-statistics table frame
addon.ui.CreateStatsTable = function(options)
    options = options or {}

    local utils = addon.utils
    local format = addon.format or {}

    local statsFrame = nil
    local statsScrollFrame = nil
    local statsRows = {}
    local statsRowsData = {}
    local allStatsRows = {}
    local statsEmptyText = nil
    local searchBox = nil
    local characterDropdown = nil
    local headerButtons = {}
    local characterOptions = {}
    local selectedCharacters = {}
    local selectedCharacterCount = 0
    local searchText = ""
    local sortKey = nil
    local sortAscending = true
    local instanceLevelRangesByName = nil
    local configuredLevelRanges = addon.DUNGEON_LEVEL_RANGES or {}
    local displayNameAliases = addon.DUNGEON_INSTANCE_NAME_ALIASES or {}

    local function ApplyStatsFrameScale()
        if not statsFrame or not utils or type(utils.GetStatsTableScale) ~= "function" then
            return
        end

        local scalePercent = utils.GetStatsTableScale()
        if type(scalePercent) ~= "number" then
            scalePercent = 100
        end

        statsFrame:SetScale(scalePercent / 100)
    end

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

        local displayName = displayNameAliases[rawName] or rawName

        if type(instanceLevelRangesByName) ~= "table" then
            instanceLevelRangesByName = BuildInstanceLevelRanges()
        end

        local range = instanceLevelRangesByName[displayName] or instanceLevelRangesByName[rawName]
        if type(range) ~= "table" then
            range = configuredLevelRanges[displayName] or configuredLevelRanges[rawName]
        end
        if type(range) ~= "table" then
            return displayName
        end

        local minLevel = range.minLevel
        local maxLevel = range.maxLevel
        if type(minLevel) ~= "number" or type(maxLevel) ~= "number" then
            return displayName
        end

        return string_format("%s (%d - %d)", displayName, minLevel, maxLevel)
    end

    local function GetInstanceLevelRange(rawName)
        if type(rawName) ~= "string" or rawName == "" then
            return nil
        end

        local displayName = displayNameAliases[rawName] or rawName

        if type(instanceLevelRangesByName) ~= "table" then
            instanceLevelRangesByName = BuildInstanceLevelRanges()
        end

        return instanceLevelRangesByName[displayName]
            or instanceLevelRangesByName[rawName]
            or configuredLevelRanges[displayName]
            or configuredLevelRanges[rawName]
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

    local function HasXPData(data)
        return type(data) == "table" and type(data.xpRuns) == "number" and data.xpRuns > 0
    end

    local function HasLevelProgressData(data)
        return type(data) == "table" and type(data.levelProgressRuns) == "number" and data.levelProgressRuns > 0
    end

    local function FormatLevelProgress(value)
        if type(format.LevelProgress) == "function" then
            return format.LevelProgress(value)
        end

        return "-"
    end

    local function FormatCharacterName(data)
        if type(data) ~= "table" then
            return ""
        end

        if type(data.characterLevel) == "number" and data.characterLevel > 0 then
            return string_format("%s (%d)", data.character or "", data.characterLevel)
        end

        return data.character or ""
    end

    local function GetColumnByKey(key)
        for _, column in ipairs(TABLE_COLUMNS) do
            if column.key == key then
                return column
            end
        end

        return nil
    end

    local function GetDisplayValue(data, key)
        if type(data) ~= "table" then
            return ""
        end

        if key == "character" then
            return FormatCharacterName(data)
        elseif key == "instanceName" then
            return FormatInstanceNameWithLevelRange(data.instanceName)
        elseif key == "totalRuns" then
            return tostring(data.totalRuns or 0)
        elseif key == "averageXP" then
            return HasXPData(data) and FormatNumberWithCommas(data.averageXP or 0) or "-"
        elseif key == "averageTime" then
            return FormatTableTime(data.averageTime or 0)
        elseif key == "averageXPPerMinute" then
            return HasXPData(data) and FormatNumberWithCommas(data.averageXPPerMinute or 0) or "-"
        elseif key == "averageLevelsPerMinute" then
            return HasLevelProgressData(data) and FormatLevelProgress(data.averageLevelsPerMinute) or "-"
        elseif key == "averageLevelsPerRun" then
            return HasLevelProgressData(data) and FormatLevelProgress(data.averageLevelsPerRun) or "-"
        elseif key == "fastestTime" then
            return FormatTableTime(data.fastestTime or 0)
        end

        return tostring(data[key] or "")
    end

    local function DefaultRowLessThan(left, right)
        if left.character ~= right.character then
            return (left.character or "") < (right.character or "")
        end
        if left.instanceName ~= right.instanceName then
            return (left.instanceName or "") < (right.instanceName or "")
        end
        return (left.totalRuns or 0) > (right.totalRuns or 0)
    end

    local function GetSortValue(data, column)
        if not data or not column then
            return nil
        end

        if column.dashLast and not HasXPData(data) then
            if column.key == "averageLevelsPerMinute" or column.key == "averageLevelsPerRun" then
                return HasLevelProgressData(data) and data[column.key] or nil
            end

            return nil
        end

        if column.sortType == "number" then
            return data[column.key]
        end

        return string_lower(GetDisplayValue(data, column.key) or "")
    end

    local function SortFilteredRows()
        if not sortKey then
            table_sort(statsRowsData, DefaultRowLessThan)
            return
        end

        local sortColumn = GetColumnByKey(sortKey)
        table_sort(statsRowsData, function(left, right)
            local leftValue = GetSortValue(left, sortColumn)
            local rightValue = GetSortValue(right, sortColumn)
            local leftMissing = leftValue == nil
            local rightMissing = rightValue == nil

            if leftMissing or rightMissing then
                if leftMissing ~= rightMissing then
                    return not leftMissing
                end
                return DefaultRowLessThan(left, right)
            end

            if leftValue == rightValue then
                return DefaultRowLessThan(left, right)
            end

            if sortAscending then
                return leftValue < rightValue
            end

            return leftValue > rightValue
        end)
    end

    local function BuildSearchText(data)
        local parts = {}

        for _, column in ipairs(TABLE_COLUMNS) do
            parts[#parts + 1] = string_lower(GetDisplayValue(data, column.key))
        end

        return table_concat(parts, " ")
    end

    local function RowMatchesCharacter(data)
        if selectedCharacterCount == 0 then
            return true
        end

        return data and selectedCharacters[data.character] == true
    end

    local function RowMatchesSearch(data)
        if searchText == "" then
            return true
        end

        return string_find(BuildSearchText(data), searchText, 1, true) ~= nil
    end

    local function RowMatchesLevelRange(data)
        if not utils or type(utils.GetStatsLevelRange) ~= "function" then
            return true
        end

        local levelRange = utils.GetStatsLevelRange()
        if type(levelRange) ~= "number" or levelRange <= 0 then
            return true
        end

        if type(data) ~= "table" then
            return true
        end

        local instanceRange = GetInstanceLevelRange(data.instanceName)
        if type(instanceRange) ~= "table" or
            type(instanceRange.minLevel) ~= "number" or
            type(instanceRange.maxLevel) ~= "number" then
            return true
        end

        local characterLevel = type(UnitLevel) == "function" and UnitLevel("player") or nil
        if type(characterLevel) ~= "number" or characterLevel <= 0 then
            characterLevel = type(data) == "table" and data.characterLevel or nil
        end
        if type(characterLevel) ~= "number" then
            return true
        end

        return instanceRange.maxLevel >= characterLevel - levelRange
            and instanceRange.minLevel <= characterLevel + levelRange
    end

    local function ResetScrollOffset()
        if statsScrollFrame and type(FauxScrollFrame_SetOffset) == "function" then
            FauxScrollFrame_SetOffset(statsScrollFrame, 0)
        end
    end

    local function UpdateHeaderLabels()
        for _, column in ipairs(TABLE_COLUMNS) do
            local header = headerButtons[column.key]
            if header and header.text then
                local label = column.label
                if sortKey == column.key then
                    label = label .. (sortAscending and " ^" or " v")
                end
                header.text:SetText(label)
            end
        end
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
                for _, column in ipairs(TABLE_COLUMNS) do
                    row.cells[column.key]:SetText(GetDisplayValue(data, column.key))
                end
                row:Show()
            else
                row:Hide()
            end
        end

        if totalRows == 0 then
            if #allStatsRows == 0 then
                statsEmptyText:SetText("|cFFFFFF00No tracked runs yet. Complete a dungeon to populate this table.|r")
            else
                statsEmptyText:SetText("|cFFFFFF00No matching runs.|r")
            end
            statsEmptyText:Show()
        else
            statsEmptyText:Hide()
        end
    end

    local function ApplyFiltersAndSort(resetOffset)
        statsRowsData = {}

        for _, row in ipairs(allStatsRows) do
            if RowMatchesCharacter(row) and RowMatchesSearch(row) and RowMatchesLevelRange(row) then
                statsRowsData[#statsRowsData + 1] = row
            end
        end

        SortFilteredRows()
        UpdateHeaderLabels()

        if resetOffset then
            ResetScrollOffset()
        end

        UpdateRows()
    end

    local function UpdateCharacterDropdownText()
        if not characterDropdown or type(UIDropDownMenu_SetText) ~= "function" then
            return
        end

        if selectedCharacterCount == 0 then
            UIDropDownMenu_SetText(characterDropdown, "All")
            return
        end

        if selectedCharacterCount == 1 then
            for characterName, selected in pairs(selectedCharacters) do
                if selected then
                    UIDropDownMenu_SetText(characterDropdown, characterName)
                    return
                end
            end
        end

        UIDropDownMenu_SetText(characterDropdown, string_format("%d selected", selectedCharacterCount))
    end

    local function ApplyCharacterFilterSetting()
        selectedCharacters = {}
        selectedCharacterCount = 0

        if utils and type(utils.GetStatsCharacterFilterMode) == "function" and
            utils.GetStatsCharacterFilterMode() == "current" then
            local currentCharacter = type(UnitName) == "function" and UnitName("player") or nil
            if type(currentCharacter) == "string" and currentCharacter ~= "" then
                selectedCharacters[currentCharacter] = true
                selectedCharacterCount = 1
            end
        end

        UpdateCharacterDropdownText()
    end

    local function RefreshCharacterOptions()
        local seen = {}
        characterOptions = {}

        for _, row in ipairs(allStatsRows) do
            if type(row.character) == "string" and row.character ~= "" and not seen[row.character] then
                seen[row.character] = true
                characterOptions[#characterOptions + 1] = row.character
            end
        end

        table_sort(characterOptions)

        ApplyCharacterFilterSetting()
    end

    local function ToggleCharacterSelection(characterName)
        if type(characterName) ~= "string" or characterName == "" then
            return
        end

        if selectedCharacters[characterName] then
            selectedCharacters[characterName] = nil
            selectedCharacterCount = selectedCharacterCount - 1
        else
            selectedCharacters[characterName] = true
            selectedCharacterCount = selectedCharacterCount + 1
        end

        if selectedCharacterCount < 0 then
            selectedCharacterCount = 0
        end
    end

    local function RefreshOpenCharacterDropdownChecks()
        local listFrame = _G and _G["DropDownList1"]
        if not listFrame or not listFrame:IsShown() then
            return
        end

        for i = 1, (listFrame.numButtons or 0) do
            local button = _G["DropDownList1Button" .. i]
            local check = button and _G[button:GetName() .. "Check"]
            if button and check then
                if button.arg1 then
                    if selectedCharacters[button.arg1] then
                        check:Show()
                    else
                        check:Hide()
                    end
                elseif button:GetText() == "All" then
                    if selectedCharacterCount == 0 then
                        check:Show()
                    else
                        check:Hide()
                    end
                end
            end
        end
    end

    local function InitializeCharacterDropdown()
        local info = UIDropDownMenu_CreateInfo()
        info.text = "All"
        info.checked = selectedCharacterCount == 0
        info.func = function()
            selectedCharacters = {}
            selectedCharacterCount = 0
            UpdateCharacterDropdownText()
            ApplyFiltersAndSort(true)
            RefreshOpenCharacterDropdownChecks()
        end
        UIDropDownMenu_AddButton(info)

        for _, characterName in ipairs(characterOptions) do
            info = UIDropDownMenu_CreateInfo()
            info.text = characterName
            info.arg1 = characterName
            info.checked = selectedCharacters[characterName] == true
            info.keepShownOnClick = 1
            info.func = function(button, selectedName)
                ToggleCharacterSelection(selectedName)
                UpdateCharacterDropdownText()
                ApplyFiltersAndSort(true)
                RefreshOpenCharacterDropdownChecks()
            end
            UIDropDownMenu_AddButton(info)
        end
    end

    local function EscapeCSVValue(value)
        value = tostring(value or "")

        if string_find(value, "[\",\n\r]") then
            value = "\"" .. string_gsub(value, "\"", "\"\"") .. "\""
        end

        return value
    end

    local function BuildExportCSV()
        local lines = {}
        local headers = {}

        for _, column in ipairs(TABLE_COLUMNS) do
            headers[#headers + 1] = EscapeCSVValue(column.label)
        end

        lines[#lines + 1] = table_concat(headers, ",")

        for _, row in ipairs(statsRowsData) do
            local values = {}
            for _, column in ipairs(TABLE_COLUMNS) do
                values[#values + 1] = EscapeCSVValue(GetDisplayValue(row, column.key))
            end
            lines[#lines + 1] = table_concat(values, ",")
        end

        return table_concat(lines, "\n")
    end

    local function Refresh()
        if not statsFrame then
            return
        end

        allStatsRows = utils.GetAllInstanceStatsRows()
        ApplyStatsFrameScale()
        RefreshCharacterOptions()
        ApplyFiltersAndSort(false)
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

        local tableContentWidth = CalculateTableContentWidth()

        statsFrame = CreateFrame("Frame", frameNames.stats, UIParent)
        statsFrame:SetWidth(tableContentWidth + 32)
        statsFrame:SetHeight(400)
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
        configButton:SetWidth(70)
        configButton:SetHeight(18)
        configButton:SetPoint("TOPRIGHT", statsFrame, "TOPRIGHT", -12, -43)
        configButton:SetText("Settings")
        configButton:SetScript("OnClick", function()
            if type(options.toggleConfig) == "function" then
                options.toggleConfig()
            end
        end)

        local exportButton = CreateFrame("Button", nil, statsFrame, "UIPanelButtonTemplate")
        exportButton:SetWidth(70)
        exportButton:SetHeight(18)
        exportButton:SetPoint("TOPRIGHT", configButton, "TOPLEFT", -4, 0)
        exportButton:SetText("Export")
        exportButton:SetScript("OnClick", function()
            if type(options.onExport) == "function" then
                options.onExport(BuildExportCSV())
            end
        end)

        local searchLabel = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        searchLabel:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 18, -43)
        searchLabel:SetText("Search")

        searchBox = CreateFrame("EditBox", "WITStatsSearchBox", statsFrame, "InputBoxTemplate")
        searchBox:SetWidth(150)
        searchBox:SetHeight(20)
        searchBox:SetAutoFocus(false)
        searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 10, 0)
        searchBox:SetScript("OnTextChanged", function(self)
            searchText = string_lower(strtrim(self:GetText() or ""))
            ApplyFiltersAndSort(true)
        end)

        local characterLabel = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        characterLabel:SetPoint("LEFT", searchBox, "RIGHT", 24, 0)
        characterLabel:SetText("Character")

        characterDropdown = CreateFrame("Frame", "WITStatsCharacterDropDown", statsFrame, "UIDropDownMenuTemplate")
        characterDropdown:SetPoint("LEFT", characterLabel, "RIGHT", -12, -3)
        UIDropDownMenu_SetWidth(characterDropdown, 130)
        UIDropDownMenu_Initialize(characterDropdown, InitializeCharacterDropdown)
        UpdateCharacterDropdownText()

        local headerBackground = statsFrame:CreateTexture(nil, "ARTWORK")
        headerBackground:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 12, -72)
        headerBackground:SetPoint("TOPRIGHT", statsFrame, "TOPRIGHT", -12, -72)
        headerBackground:SetHeight(22)
        headerBackground:SetTexture(0.2, 0.2, 0.2, 0.6)

        local bodyBackground = statsFrame:CreateTexture(nil, "BORDER")
        bodyBackground:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 12, -94)
        bodyBackground:SetPoint("BOTTOMRIGHT", statsFrame, "BOTTOMRIGHT", -12, 20)
        bodyBackground:SetTexture(0, 0, 0, 0.25)

        local totalColumnWidth = 0
        for _, column in ipairs(TABLE_COLUMNS) do
            local columnKey = column.key
            local header = CreateFrame("Button", nil, statsFrame)
            header:SetWidth(column.width)
            header:SetHeight(18)
            header:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 16 + totalColumnWidth, -76)
            header:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            header.text:SetAllPoints(header)
            header.text:SetJustifyH(column.justify)
            header.text:SetText(column.label)
            header:SetScript("OnClick", function()
                if sortKey == columnKey then
                    sortAscending = not sortAscending
                else
                    sortKey = columnKey
                    sortAscending = true
                end
                ApplyFiltersAndSort(true)
            end)
            headerButtons[columnKey] = header

            totalColumnWidth = totalColumnWidth + column.width + TABLE_COLUMN_SPACING
        end

        statsScrollFrame = CreateFrame("ScrollFrame", "WITStatsScrollFrame", statsFrame, "FauxScrollFrameTemplate")
        statsScrollFrame:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 16, -94)
        statsScrollFrame:SetPoint("BOTTOMRIGHT", statsFrame, "BOTTOMRIGHT", -12, 20)
        statsScrollFrame:SetScript("OnVerticalScroll", function(self, offset)
            FauxScrollFrame_OnVerticalScroll(self, offset, TABLE_ROW_HEIGHT, UpdateRows)
        end)

        for i = 1, TABLE_ROWS_DISPLAYED do
            local row = CreateFrame("Frame", nil, statsFrame)
            row:SetWidth(totalColumnWidth - TABLE_COLUMN_SPACING)
            row:SetHeight(TABLE_ROW_HEIGHT)
            row:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 16, -96 - ((i - 1) * TABLE_ROW_HEIGHT))
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
                cell:SetHeight(TABLE_ROW_HEIGHT)
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
            if type(CloseDropDownMenus) == "function" then
                CloseDropDownMenus()
            end
            NotifyVisibilityChanged()
        end)
    end

    return {
        Show = function()
            CreateFrameIfNeeded()
            ApplyStatsFrameScale()
            statsFrame:Show()
        end,
        Toggle = function()
            CreateFrameIfNeeded()
            if statsFrame:IsShown() then
                statsFrame:Hide()
            else
                ApplyStatsFrameScale()
                statsFrame:Show()
            end
        end,
        Export = function()
            CreateFrameIfNeeded()
            Refresh()
            if type(options.onExport) == "function" then
                options.onExport(BuildExportCSV())
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

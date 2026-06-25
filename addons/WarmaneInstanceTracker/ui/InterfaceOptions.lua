local addonName, addon = ...

local getglobal = getglobal
local math_floor = math.floor
local string_format = string.format
local type = type

addon.ui = addon.ui or {}

local PARENT_CATEGORY_NAME = "Warmane AddOns"
local PARENT_PANEL_NAME = "WarmaneAddOnsInterfaceOptionsPanel"
local INSTANCE_TRACKER_CATEGORY_NAME = "Instance Tracker"

local CHARACTER_FILTER_OPTIONS = {
    { value = "current", text = "Current character" },
    { value = "all", text = "All characters" }
}

local LEVEL_RANGE_OPTIONS = {
    { value = 0, text = "Ignore level range" },
    { value = 5, text = "5 levels" },
    { value = 10, text = "10 levels" },
    { value = 15, text = "15 levels" },
    { value = 20, text = "20 levels" }
}

local function EnsureWarmaneAddOnsCategory(defaultOpenFunc, forceDefault)
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

    if forceDefault or type(parentPanel.warmaneOpenDefaultChild) ~= "function" then
        parentPanel.warmaneOpenDefaultChild = defaultOpenFunc
    end

    return parentPanel
end

local function FormatElapsed(seconds)
    if type(seconds) ~= "number" or seconds < 0 then
        return "0 sec"
    end

    local totalSeconds = math_floor(seconds + 0.5)
    local hours = math_floor(totalSeconds / 3600)
    local minutes = math_floor((totalSeconds % 3600) / 60)
    local remainingSeconds = totalSeconds % 60

    if hours > 0 then
        return string_format("%d h %d min %d sec", hours, minutes, remainingSeconds)
    end
    if minutes > 0 then
        return string_format("%d min %d sec", minutes, remainingSeconds)
    end
    return string_format("%d sec", remainingSeconds)
end

local function FindOptionText(options, value)
    for _, option in ipairs(options) do
        if option.value == value then
            return option.text
        end
    end

    return options[1].text
end

-- Create the Interface Options panels for the Warmane AddOns group
addon.ui.CreateInterfaceOptions = function(options)
    options = options or {}

    local instancePanel = nil
    local checkboxes = {}
    local dropdowns = {}
    local tableScaleSlider = nil
    local tableScaleValueText = nil
    local currentRunText = nil
    local elapsedText = nil
    local statusButton = nil
    local startEndButton = nil
    local pauseContinueButton = nil
    local resetButton = nil
    local refreshingControls = false
    local redirectingToChild = false

    local function GetState()
        if type(options.getState) == "function" then
            return options.getState() or {}
        end

        return {}
    end

    local function RefreshCheckboxes()
        if not instancePanel then
            return
        end

        local state = GetState()
        if checkboxes.enableInstanceTracking then
            checkboxes.enableInstanceTracking:SetChecked(state.instanceTrackingEnabled and true or false)
        end
        if checkboxes.enablePartyMessage then
            checkboxes.enablePartyMessage:SetChecked(state.partyMessageEnabled and true or false)
        end
        if checkboxes.enableDebugPrinting then
            checkboxes.enableDebugPrinting:SetChecked(state.debugMode and true or false)
        end
        if checkboxes.enableDebugLogging then
            checkboxes.enableDebugLogging:SetChecked(state.debugLoggingEnabled and true or false)
        end
    end

    local function SetButtonEnabled(button, enabled)
        if not button then
            return
        end

        if enabled then
            button:Enable()
        else
            button:Disable()
        end
    end

    local function RefreshRunControls()
        if not instancePanel then
            return
        end

        local state = {}
        if type(options.getRunControlState) == "function" then
            state = options.getRunControlState() or {}
        end

        local hasRun = state.hasRun == true
        currentRunText:SetText("Current run: " .. (hasRun and state.instanceName or "No active run"))
        elapsedText:SetText("Time Elapsed: " .. FormatElapsed(state.elapsedSeconds))
        startEndButton:SetText(hasRun and "End" or "Start")
        pauseContinueButton:SetText(state.isPaused and "Continue" or "Pause")

        SetButtonEnabled(statusButton, hasRun)
        SetButtonEnabled(startEndButton, true)
        SetButtonEnabled(pauseContinueButton, hasRun)
        SetButtonEnabled(resetButton, hasRun)
    end

    local function RefreshDropdowns()
        local state = GetState()

        if dropdowns.characterFilter then
            UIDropDownMenu_SetText(dropdowns.characterFilter, FindOptionText(CHARACTER_FILTER_OPTIONS, state.statsCharacterFilterMode or "current"))
        end

        if dropdowns.levelRange then
            UIDropDownMenu_SetText(dropdowns.levelRange, FindOptionText(LEVEL_RANGE_OPTIONS, state.statsLevelRange or 0))
        end
    end

    local function RefreshTableScaleSlider()
        if not tableScaleSlider then
            return
        end

        local state = GetState()
        local scale = type(state.statsTableScale) == "number" and state.statsTableScale or 100

        refreshingControls = true
        tableScaleSlider:SetValue(scale)
        refreshingControls = false

        if tableScaleValueText then
            tableScaleValueText:SetText(scale .. "%")
        end
    end

    local function RefreshAllControls()
        RefreshCheckboxes()
        RefreshRunControls()
        RefreshDropdowns()
        RefreshTableScaleSlider()
    end

    local function OpenInstanceTrackerCategory()
        if redirectingToChild or not instancePanel or type(InterfaceOptionsFrame_OpenToCategory) ~= "function" then
            return
        end

        redirectingToChild = true
        InterfaceOptionsFrame_OpenToCategory(instancePanel)
        redirectingToChild = false
    end

    local function CreateHeader(parent, text, y)
        local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalMed3")
        header:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, y)
        header:SetText(text)
        return header
    end

    local function CreateLabel(parent, text, x, y)
        local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        label:SetText(text)
        return label
    end

    local function CreateCheckbox(parent, name, label, y, callback)
        local checkbox = CreateFrame("CheckButton", name, parent, "InterfaceOptionsCheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, y)
        getglobal(checkbox:GetName() .. "Text"):SetText(label)
        checkbox:SetScript("OnClick", function(self)
            if type(callback) == "function" then
                callback(self:GetChecked() and true or false)
            end
            RefreshAllControls()
        end)
        return checkbox
    end

    local function CreateButton(parent, name, text, x, y, width, callback)
        local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
        button:SetWidth(width)
        button:SetHeight(22)
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        button:SetText(text)
        button:SetScript("OnClick", function()
            if type(callback) == "function" then
                callback()
            end
            RefreshAllControls()
        end)
        return button
    end

    local function InitializeCharacterFilterDropdown()
        local state = GetState()
        local currentValue = state.statsCharacterFilterMode or "current"

        for _, option in ipairs(CHARACTER_FILTER_OPTIONS) do
            local value = option.value
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.checked = currentValue == value
            info.func = function()
                if type(options.onSetStatsCharacterFilterMode) == "function" then
                    options.onSetStatsCharacterFilterMode(value)
                end
                RefreshAllControls()
            end
            UIDropDownMenu_AddButton(info)
        end
    end

    local function InitializeLevelRangeDropdown()
        local state = GetState()
        local currentValue = state.statsLevelRange or 0

        for _, option in ipairs(LEVEL_RANGE_OPTIONS) do
            local value = option.value
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.checked = currentValue == value
            info.func = function()
                if type(options.onSetStatsLevelRange) == "function" then
                    options.onSetStatsLevelRange(value)
                end
                RefreshAllControls()
            end
            UIDropDownMenu_AddButton(info)
        end
    end

    EnsureWarmaneAddOnsCategory(OpenInstanceTrackerCategory, true)

    instancePanel = CreateFrame("Frame", "WITInstanceTrackerInterfaceOptions")
    instancePanel.name = INSTANCE_TRACKER_CATEGORY_NAME
    instancePanel.parent = PARENT_CATEGORY_NAME

    local title = instancePanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", instancePanel, "TOPLEFT", 16, -16)
    title:SetText("Warmane Instance Tracker")

    CreateHeader(instancePanel, "Run Statistics", -52)
    CreateButton(instancePanel, "WITInterfaceOptionsOpenStatsButton", "Open Run Statistics", 18, -76, 150, options.openStatsTable)
    CreateButton(instancePanel, "WITInterfaceOptionsExportStatsButton", "Export Run Statistics", 184, -76, 160, options.exportStatsTable)

    currentRunText = instancePanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    currentRunText:SetPoint("TOPLEFT", instancePanel, "TOPLEFT", 18, -120)
    currentRunText:SetText("Current run: No active run")

    elapsedText = instancePanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    elapsedText:SetPoint("TOPLEFT", instancePanel, "TOPLEFT", 18, -140)
    elapsedText:SetText("Time Elapsed: 0 sec")

    statusButton = CreateButton(instancePanel, "WITInterfaceOptionsStatusButton", "Status", 18, -166, 78, options.printStatus)
    startEndButton = CreateButton(instancePanel, "WITInterfaceOptionsStartEndButton", "Start", 104, -166, 78, function()
        local state = type(options.getRunControlState) == "function" and options.getRunControlState() or {}
        if state and state.hasRun then
            if type(options.endRun) == "function" then
                options.endRun()
            end
        elseif type(options.startRun) == "function" then
            options.startRun()
        end
    end)
    pauseContinueButton = CreateButton(instancePanel, "WITInterfaceOptionsPauseContinueButton", "Pause", 190, -166, 98, function()
        local state = type(options.getRunControlState) == "function" and options.getRunControlState() or {}
        if state and state.isPaused then
            if type(options.continueRun) == "function" then
                options.continueRun()
            end
        elseif type(options.pauseRun) == "function" then
            options.pauseRun()
        end
    end)
    resetButton = CreateButton(instancePanel, "WITInterfaceOptionsResetButton", "Reset", 296, -166, 78, options.resetRun)

    CreateHeader(instancePanel, "User Settings", -212)
    checkboxes.enableInstanceTracking = CreateCheckbox(
        instancePanel,
        "WITInterfaceOptionsEnableInstanceTracking",
        "Enable instance tracker",
        -236,
        options.onSetInstanceTracking
    )
    checkboxes.enablePartyMessage = CreateCheckbox(
        instancePanel,
        "WITInterfaceOptionsEnablePartyMessage",
        "Enable party message",
        -264,
        options.onSetPartyMessage
    )

    CreateHeader(instancePanel, "Table Settings", -308)
    CreateLabel(instancePanel, "Show characters", 18, -334)
    dropdowns.characterFilter = CreateFrame("Frame", "WITInterfaceOptionsCharacterFilterDropDown", instancePanel, "UIDropDownMenuTemplate")
    dropdowns.characterFilter:SetPoint("TOPLEFT", instancePanel, "TOPLEFT", 128, -326)
    UIDropDownMenu_SetWidth(dropdowns.characterFilter, 150)
    UIDropDownMenu_Initialize(dropdowns.characterFilter, InitializeCharacterFilterDropdown)

    CreateLabel(instancePanel, "Level range", 18, -368)
    dropdowns.levelRange = CreateFrame("Frame", "WITInterfaceOptionsLevelRangeDropDown", instancePanel, "UIDropDownMenuTemplate")
    dropdowns.levelRange:SetPoint("TOPLEFT", instancePanel, "TOPLEFT", 128, -360)
    UIDropDownMenu_SetWidth(dropdowns.levelRange, 150)
    UIDropDownMenu_Initialize(dropdowns.levelRange, InitializeLevelRangeDropdown)

    CreateLabel(instancePanel, "Table size", 18, -410)
    tableScaleSlider = CreateFrame("Slider", "WITInterfaceOptionsTableScaleSlider", instancePanel, "OptionsSliderTemplate")
    tableScaleSlider:SetPoint("TOPLEFT", instancePanel, "TOPLEFT", 128, -408)
    tableScaleSlider:SetWidth(170)
    tableScaleSlider:SetMinMaxValues(50, 150)
    tableScaleSlider:SetValueStep(10)
    getglobal(tableScaleSlider:GetName() .. "Low"):SetText("50%")
    getglobal(tableScaleSlider:GetName() .. "High"):SetText("150%")
    tableScaleValueText = instancePanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    tableScaleValueText:SetPoint("LEFT", tableScaleSlider, "RIGHT", 18, 0)
    tableScaleValueText:SetText("100%")
    tableScaleSlider:SetScript("OnValueChanged", function(self, value)
        local roundedValue = math_floor((value + 5) / 10) * 10
        if roundedValue < 50 then
            roundedValue = 50
        elseif roundedValue > 150 then
            roundedValue = 150
        end

        if roundedValue ~= value then
            self:SetValue(roundedValue)
            return
        end

        if tableScaleValueText then
            tableScaleValueText:SetText(roundedValue .. "%")
        end

        if not refreshingControls and type(options.onSetStatsTableScale) == "function" then
            options.onSetStatsTableScale(roundedValue)
        end
    end)

    CreateHeader(instancePanel, "Developer Settings", -466)
    checkboxes.enableDebugPrinting = CreateCheckbox(
        instancePanel,
        "WITInterfaceOptionsEnableDebugPrinting",
        "Enable debug printing",
        -490,
        options.onSetDebugPrinting
    )
    checkboxes.enableDebugLogging = CreateCheckbox(
        instancePanel,
        "WITInterfaceOptionsEnableDebugLogging",
        "Enable debug logging",
        -518,
        options.onSetDebugLogging
    )

    instancePanel:SetScript("OnShow", function(self)
        RefreshAllControls()
        self.timer = 0
    end)
    instancePanel:SetScript("OnUpdate", function(self, elapsed)
        self.timer = (self.timer or 0) + elapsed
        if self.timer >= 1 then
            self.timer = 0
            RefreshRunControls()
        end
    end)

    instancePanel.refresh = RefreshAllControls
    instancePanel:Hide()
    InterfaceOptions_AddCategory(instancePanel)

    return {
        Open = function()
            OpenInstanceTrackerCategory()
        end,
        RefreshCheckboxes = function()
            RefreshCheckboxes()
        end,
        RefreshAll = function()
            RefreshAllControls()
        end
    }
end

local addonName = ...

-- Cache frequently used functions
local type = type
local string_format = string.format
local SetCVar = SetCVar

-- Define color codes
local COLOR = {
    ORANGE = "|cFFFF8000",
    YELLOW = "|cFFFFFF00"
}

-- Format general messages with colored prefix
local function FormatMessage(prefix, msg)
    if type(prefix) ~= "string" or type(msg) ~= "string" then
        return ""
    end

    return string_format("%s[%s] %s%s|r", COLOR.ORANGE, prefix, COLOR.YELLOW, msg)
end

-- Enable built-in AFK auto-clear behavior
local function EnsureAutoClearAFK()
    SetCVar("autoClearAFK", "1")
end

-- Create frame for event handling
local WNA = CreateFrame("Frame")

-- Register required events
WNA:RegisterEvent("ADDON_LOADED")
WNA:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Handle addon initialization and world transitions
WNA:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        EnsureAutoClearAFK()
        print(FormatMessage("WNA", "WarmaneNotAway loaded"))
    elseif event == "PLAYER_ENTERING_WORLD" then
        EnsureAutoClearAFK()
    end
end)

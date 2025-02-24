-- Initialize addon hooks
local originalChatFrame
local originalSetItemRef

-- Cache frequently used functions
local gsub = gsub
local strsub = strsub

-- Import color codes
local COLOR = {
    ORANGE = "|cFFFF8000",
    YELLOW = "|cFFFFFF00"
}

function Initialize()
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
    originalChatFrame(self, event, ...)
    
    if not self.originalMessage then 
        self.originalMessage = self.AddMessage
        self.AddMessage = HandleMessage
    end
end

function HandleMessage(frame, msg, r, g, b, id)
    local newMsg = "|Hcopy"..ProcessMessage(msg).."|h" .. msg .. "|h"
    frame:originalMessage(newMsg, r, g, b, id)
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

function HandleItemRef(link, text, button)
    if strsub(link, 1, 4) == "copy" then
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
    
    originalSetItemRef(link, text, button)
end

-- Print loading message
print(string.format("|cFFFF8000Warmane|cFFFFFF00 Chat Copy loaded|r"))

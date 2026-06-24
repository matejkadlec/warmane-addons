
MBB_Version = "0.63";
MBB_TOOLTIP1 = "Ctrl + Right click on a button to reattach it to the minimap.";
MBB_OPTIONS_HEADER = "Options";
MBB_OPTIONS_OKBUTTON = "Ok";
MBB_OPTIONS_CANCELBUTTON = "Cancel";
MBB_OPTIONS_SLIDEROFF = "Off";
MBB_OPTIONS_SLIDERSEK = "sec";
MBB_OPTIONS_SLIDERLABEL = "Collapse Timeout:";
MBB_OPTIONS_EXPANSIONLABEL = "Expand to:";
MBB_OPTIONS_EXPANSIONLEFT = "Left";
MBB_OPTIONS_EXPANSIONTOP = "Top";
MBB_OPTIONS_EXPANSIONRIGHT = "Right";
MBB_OPTIONS_EXPANSIONBOTTOM = "Bottom";
MBB_OPTIONS_MAXBUTTONSLABEL = "Max. Buttons/Line:";
MBB_OPTIONS_MAXBUTTONSINFO = "(0=infinity)";
MBB_OPTIONS_ALTEXPANSIONLABEL = "Alt. Expand to:";
MBB_HELP1 = "Type \"/mbb <cmd>\" where <cmd> is one of the following:";
MBB_HELP2 = "  |c00ffffffbuttons|r: Shows a list of all frames in the MBB bar";
MBB_HELP3 = "  |c00ffffffreset position|r: resets the position of the MBB minimap button";
MBB_HELP4 = "  |c00ffffffreset all|r: resets all options";
MBB_NOERRORS = "No errors found!";
MBB_DebugFlag = 0;
MBB_DragFlag = 0;
MBB_ShowTimeout = -1;
MBB_CheckTime = 0;
MBB_IsShown = 0;
MBB_FuBar_MinimapContainer = "FuBarPlugin-MinimapContainer-2.0";
MBB_Buttons = {};
MBB_Exclude = {};
MBB_DebugInfo = {};
MBB_UseEnumerateChildren = {};
MBB_ValidPoints = {
	["TOPLEFT"] = 1,
	["TOP"] = 1,
	["TOPRIGHT"] = 1,
	["LEFT"] = 1,
	["CENTER"] = 1,
	["RIGHT"] = 1,
	["BOTTOMLEFT"] = 1,
	["BOTTOM"] = 1,
	["BOTTOMRIGHT"] = 1
};
MBB_DefaultOptions = {
	["ButtonPos"] = {-18, -100},
	["ButtonPoint"] = {"TOPLEFT", "TOPLEFT", -18, -100},
	["AttachToMinimap"] = 1,
	["CollapseTimeout"] = 1,
	["ExpandDirection"] = 1,
	["MaxButtonsPerLine"] = 0,
	["AltExpandDirection"] = 4
};

function MBB_CopyOptionValue(value)
	if( type(value) ~= "table" ) then
		return value;
	end

	local copy = {};
	for key, childValue in pairs(value) do
		copy[key] = childValue;
	end
	return copy;
end

function MBB_CopyDefaultOptions()
	local options = {};
	for opt,val in pairs(MBB_DefaultOptions) do
		options[opt] = MBB_CopyOptionValue(val);
	end
	return options;
end

function MBB_IsValidPoint(point)
	return type(point) == "string" and MBB_ValidPoints[point] == 1;
end

function MBB_IsValidPosition(position)
	return type(position) == "table" and type(position[1]) == "number" and type(position[2]) == "number";
end

function MBB_IsValidButtonPoint(point)
	return type(point) == "table" and MBB_IsValidPoint(point[1]) and MBB_IsValidPoint(point[2])
		and type(point[3]) == "number" and type(point[4]) == "number";
end

function MBB_NormalizeOptions()
	if( type(MBB_Options) ~= "table" ) then
		MBB_Options = MBB_CopyDefaultOptions();
	end

	for opt,val in pairs(MBB_DefaultOptions) do
		if( MBB_Options[opt] == nil ) then
			MBB_Debug(opt .. " option set to default: " .. tostring(val));
			MBB_Options[opt] = MBB_CopyOptionValue(val);
		else
			MBB_Debug(opt .. " option exists: " .. tostring(MBB_Options[opt]));
		end
	end

	if( MBB_Options.AttachToMinimap ~= 0 and MBB_Options.AttachToMinimap ~= 1 ) then
		MBB_Options.AttachToMinimap = MBB_DefaultOptions.AttachToMinimap;
	end

	if( not MBB_IsValidPosition(MBB_Options.ButtonPos) ) then
		MBB_Options.ButtonPos = MBB_CopyOptionValue(MBB_DefaultOptions.ButtonPos);
	end

	if( not MBB_IsValidButtonPoint(MBB_Options.ButtonPoint) ) then
		if( MBB_Options.AttachToMinimap == 1 ) then
			MBB_Options.ButtonPoint = {"TOPLEFT", "TOPLEFT", MBB_Options.ButtonPos[1], MBB_Options.ButtonPos[2]};
		else
			MBB_Options.ButtonPoint = {"CENTER", "CENTER", MBB_Options.ButtonPos[1], MBB_Options.ButtonPos[2]};
		end
	end
end

if(not MBB_Options) then
	MBB_Options = MBB_CopyDefaultOptions();
end
	
MBB_Include = {
	[1] = "WIM_IconFrame",
	[2] = "CTMod2_MinimapButton",
	[3] = "PoisonerMinimapButton",
};

MBB_Ignore = {
	[1] = "MiniMapTrackingFrame",
	[2] = "MiniMapMeetingStoneFrame",
	[3] = "MiniMapMailFrame",
	[4] = "MiniMapBattlefieldFrame",
	[5] = "MiniMapWorldMapButton",
	[6] = "MiniMapPing",
	[7] = "MinimapBackdrop",
	[8] = "MinimapZoomIn",
	[9] = "MinimapZoomOut",
	[10] = "BookOfTracksFrame",
	[11] = "GatherNote",
	[12] = "FishingExtravaganzaMini",
	[13] = "MiniNotePOI",
	[14] = "RecipeRadarMinimapIcon",
	[15] = "FWGMinimapPOI",
	[16] = "CartographerNotesPOI",
	[17] = "MBB_MinimapButtonFrame",
	[18] = "EnhancedFrameMinimapButton",
	[19] = "GFW_TrackMenuFrame",
	[20] = "GFW_TrackMenuButton",
	[21] = "TDial_TrackingIcon",
	[22] = "TDial_TrackButton",
	[23] = "MiniMapTracking",
	[24] = "GatherMatePin",
	[25] = "HandyNotesPin",
	[26] = "TimeManagerClockButton",
	[27] = "GameTimeFrame",
	[28] = "DA_Minimap",
};

MBB_IgnoreSize = {
	[1] = "AM_MinimapButton",
	[2] = "STC_HealthstoneButton",
	[3] = "STC_ShardButton",
	[4] = "STC_SoulstoneButton",
	[5] = "STC_SpellstoneButton",
	[6] = "STC_FirestoneButton"
};

MBB_ExtraSize = {
	["GathererMinimapButton"] = function()
		GathererMinimapButton.mask:SetHeight(31);
		GathererMinimapButton.mask:SetWidth(31);
	end
};

function MBB_EnumerateChildren(frame)
	local children = {};
	local current = nil;
	local scanned = 0;
	
	while( type(EnumerateFrames) == "function" ) do
		current = EnumerateFrames(current);
		if( not current ) then
			break;
		end
		
		scanned = scanned + 1;
		if( scanned > 20000 ) then
			MBB_Debug("Frame enumeration stopped at safety limit");
			break;
		end
		
		if( current.GetParent and current:GetParent() == frame ) then
			table.insert(children, current);
		end
	end
	
	return children;
end

function MBB_GetChildren(frame)
	local children = {};
	if( not frame or not frame.GetChildren ) then
		return children;
	end
	
	local frameName = frame.GetName and frame:GetName() or tostring(frame);
	if( MBB_UseEnumerateChildren[frameName] and type(EnumerateFrames) == "function" ) then
		return MBB_EnumerateChildren(frame);
	end
	
	local values = {pcall(frame.GetChildren, frame)};
	if( values[1] ) then
		for i=2,table.maxn(values) do
			table.insert(children, values[i]);
		end
		return children;
	end
	
	MBB_Debug("Could not scan children for " .. tostring(frameName) .. ": " .. tostring(values[2]));
	if( type(EnumerateFrames) == "function" ) then
		MBB_UseEnumerateChildren[frameName] = true;
		return MBB_EnumerateChildren(frame);
	end
	
	return children;
end

function MBB_OnLoad()
--	hooksecurefunc("SecureHandlerClickTemplate_onclick", MBB_SecureOnClick);
--	hooksecurefunc("SecureHandlerClickTemplate_OnEnter", MBB_SecureOnEnter);
--	hooksecurefunc("SecureHandlerClickTemplate_OnLeave", MBB_SecureOnLeave);
	
	if( AceLibrary ) then
		if( AceLibrary:HasInstance(MBB_FuBar_MinimapContainer) ) then
			AceLibrary(MBB_FuBar_MinimapContainer).oldAddPlugin = AceLibrary(MBB_FuBar_MinimapContainer).AddPlugin;
			AceLibrary(MBB_FuBar_MinimapContainer).AddPlugin = function(...)
				local plugin = select(2, ...);
				local value = AceLibrary(MBB_FuBar_MinimapContainer):oldAddPlugin(plugin);
				local button = plugin.minimapFrame:GetName();
				local frame = getglobal(button);
				
				if( not frame.oshow ) then
					MBB_PrepareButton(button);
					--if( not MBB_IsExcluded(button) ) then
					if( not MBB_IsInArray(MBB_Exclude, button) ) then
						MBB_AddButton(button);
						MBB_SetPositions();
					end
				end
				
				return value;
			end
			
			AceLibrary(MBB_FuBar_MinimapContainer).oldRemovePlugin = AceLibrary(MBB_FuBar_MinimapContainer).RemovePlugin;
			AceLibrary(MBB_FuBar_MinimapContainer).RemovePlugin = function(...)
				local plugin = select(2, ...);
				local button = plugin.minimapFrame:GetName();
				local frame = getglobal(button);
				
				if( not frame.oshow ) then
					MBB_PrepareButton(button);
				end
				
				local value = AceLibrary(MBB_FuBar_MinimapContainer):oldRemovePlugin(plugin);
				return value;
			end
		end
	end
	
	this:RegisterEvent("VARIABLES_LOADED");
	SLASH_MBB1 = "/mmbb";
	SLASH_MBB2 = "/minimapbuttonbag";
	SlashCmdList["MBB"] = MBB_SlashHandler;
end

function MBB_SlashHandler(cmd)
	if( cmd == "buttons" ) then
		MBB_Print("MBB Buttons:");
		for i,name in ipairs(MBB_Buttons) do
			MBB_Print("  " .. name);
		end
	elseif( string.sub(cmd, 1, 6) == "debug " ) then
		local iStart, iEnd, sFrame = string.find(cmd, "debug (.+)");
		
		local hasClick, hasMouseUp, hasMouseDown, hasEnter, hasLeave = MBB_TestFrame(sFrame);
		
		MBB_Debug("Frame: " .. sFrame);
		if( hasClick ) then
			MBB_Debug("  has OnClick script");
		else
			MBB_Debug("  has no OnClick script");
		end
		if( hasMouseUp ) then
			MBB_Debug("  has OnMouseUp script");
		else
			MBB_Debug("  has no OnMouseUp script");
		end
		if( hasMouseDown ) then
			MBB_Debug("  has OnMouseDown script");
		else
			MBB_Debug("  has no OnMouseDown script");
		end
		if( hasEnter ) then
			MBB_Debug("  has OnEnter script");
		else
			MBB_Debug("  has no OnEnter script");
		end
		if( hasLeave ) then
			MBB_Debug("  has OnLeave script");
		else
			MBB_Debug("  has no OnLeave script");
		end
	elseif( cmd == "reset position" ) then
		MBB_Options.AttachToMinimap = MBB_DefaultOptions.AttachToMinimap;
		MBB_Options.ButtonPos = MBB_CopyOptionValue(MBB_DefaultOptions.ButtonPos);
		MBB_Options.ButtonPoint = MBB_CopyOptionValue(MBB_DefaultOptions.ButtonPoint);
		MBB_SetButtonPosition();
	elseif( cmd == "reset all" ) then
		MBB_Options = MBB_CopyDefaultOptions();
		for i=1,table.maxn(MBB_Exclude) do
			MBB_AddButton(MBB_Exclude[i]);
		end
		MBB_SetPositions();
		MBB_SetButtonPosition();
	elseif( cmd == "errors" ) then
		if( table.maxn(MBB_DebugInfo) > 0 ) then
			for name, arr in pairs(MBB_DebugInfo) do
				MBB_Print(name);
				for _, error in pairs(arr) do
					MBB_Print("  " .. error);
				end
			end
		else
			MBB_Print(MBB_NOERRORS);
		end
	else
		MBB_Print("MBB v" .. MBB_Version .. ":");
		MBB_Print(MBB_HELP1);
		MBB_Print(MBB_HELP2);
		MBB_Print(MBB_HELP3);
		MBB_Print(MBB_HELP4);
	end
end

function MBB_TestFrame(name)
	local hasClick = false;
	local hasMouseUp = false;
	local hasMouseDown = false;
	local hasEnter = false;
	local hasLeave = false;
	local testframe = getglobal(name);
	
	if( testframe ) then
		if( not testframe.HasScript ) then
			if( testframe:GetName() ) then
				if( not MBB_DebugInfo[testframe:GetName()] ) then
					MBB_DebugInfo[testframe:GetName()] = {};
				end
				if( not MBB_IsInArray(MBB_DebugInfo[testframe:GetName()], "No HasScript") ) then
					table.insert(MBB_DebugInfo[testframe:GetName()], "No HasScript");
				end
			end
		else
			if( testframe:HasScript("OnClick") ) then
				local test = testframe:GetScript("OnClick");
				if( test ) then
					hasClick = true;
				end
			end
			if( testframe:HasScript("OnMouseUp") ) then
				local test = testframe:GetScript("OnMouseUp");
				if( test ) then
					hasMouseUp = true;
				end
			end
			if( testframe:HasScript("OnMouseDown") ) then
				local test = testframe:GetScript("OnMouseDown");
				if( test ) then
					hasMouseDown = true;
				end
			end
			if( testframe:HasScript("OnEnter") ) then
				local test = testframe:GetScript("OnEnter");
				if( test ) then
					hasEnter = true;
				end
			end
			if( testframe:HasScript("OnLeave") ) then
				local test = testframe:GetScript("OnLeave");
				if( test ) then
					hasLeave = true;
				end
			end
		end
	end
	
	return hasClick, hasMouseUp, hasMouseDown, hasEnter, hasLeave;
end

function MBB_OnEvent()
	if ( event == "VARIABLES_LOADED" ) then
		MBB_NormalizeOptions();
		
		MBB_SetButtonPosition();
		
		local children = MBB_GetChildren(Minimap);
		local additional = MBB_GetChildren(MinimapBackdrop);
		for _,child in ipairs(additional) do
			table.insert(children, child);
		end
		for _,child in ipairs(MBB_Include) do
			local childframe = getglobal(child);
			if( childframe ) then
				table.insert(children, childframe);
			end
		end
		
		for _,child in ipairs(children) do
			if( child and child.GetName and child:GetName() ) then
				local ignore = false;
				local exclude = false;
				for i,needle in ipairs(MBB_Ignore) do
					if( string.find(child:GetName(), needle) ) then
						ignore = true;
					end
				end
				if( not ignore ) then
					if( (not child.HasScript) or not child:HasScript("OnClick") ) then
						for _,subchild in ipairs(MBB_GetChildren(child)) do
							if( subchild.HasScript and subchild:HasScript("OnClick") ) then
								child = subchild;
								child.hasParentFrame = true;
								break;
							end
						end
					end
					
					local hasClick, hasMouseUp, hasMouseDown, hasEnter, hasLeave = MBB_TestFrame(child:GetName());
					
					if( hasClick or hasMouseUp or hasMouseDown ) then
						local name = child:GetName();
						
						MBB_PrepareButton(name);
						if( not MBB_IsInArray(MBB_Exclude, name) ) then
							if( child:IsVisible() ) then
								MBB_Debug("Button is visible: " .. name);
							else
								MBB_Debug("Button is not visible: " .. name);
							end
							MBB_Debug("Button added: " .. name);
							MBB_AddButton(name);
						else
							MBB_Debug("Button excluded: " .. name);
						end
					else
						MBB_Debug("Frame is no button: " .. child:GetName());
					end
				else
					MBB_Debug("Frame ignored: " .. child:GetName());
				end
			end
		end
		
		MBB_SetPositions();
	end
end

function MBB_PrepareButton(name)
	local buttonframe = getglobal(name);
	local hasHeader;
	if( not buttonframe or buttonframe.oshow ) then
		return;
	end
	
	if( buttonframe.GetAttribute ) then
		hasHeader = buttonframe:GetAttribute("anchorchild");
		if( hasHeader and hasHeader == "$parent" and not buttonframe.hasParentFrame ) then
			MBB_Debug("buttonframe has header parent");
			buttonframe.hasParentFrame = true;
		end
	else
		if( buttonframe:GetName() ) then
			if( not MBB_DebugInfo[buttonframe:GetName()] ) then
				MBB_DebugInfo[buttonframe:GetName()] = {};
			end
			if( not MBB_IsInArray(MBB_DebugInfo[buttonframe:GetName()], "No GetAttribute") ) then
				table.insert(MBB_DebugInfo[buttonframe:GetName()], "No GetAttribute");
			end
		end
	end
	
	if( buttonframe ) then
		if( buttonframe.RegisterForClicks ) then
			buttonframe:RegisterForClicks("LeftButtonDown","RightButtonDown");
		end
		
		buttonframe.isvisible = buttonframe:IsVisible();
		
		if( buttonframe.hasParentFrame ) then
			local parent = buttonframe:GetParent();
			parent.MBBChild = buttonframe:GetName();
			buttonframe.parentisvisible = parent:IsVisible();
			parent.oshow = parent.Show;
			parent.Show = function(...)
				local parent = select(1, ...);
				MBB_Debug("Parent Frame: " .. parent:GetName());
				local child = getglobal(parent.MBBChild);
				MBB_Debug("Child Frame: " .. child:GetName());
				child.parentisvisible = true;
				MBB_Debug("Showing frame: " .. parent:GetName());
				if( not MBB_IsInArray(MBB_Exclude, child:GetName()) ) then
					MBB_SetPositions();
				end
				if( MBB_IsInArray(MBB_Exclude, child:GetName()) or MBB_IsShown == 1 ) then
					parent.oshow(select(1, ...));
					--child.oshow(child);
				end
			end
			parent.ohide = parent.Hide;
			parent.Hide = function(...)
				local parent = select(1, ...);
				MBB_Debug("Parent Frame: " .. parent:GetName());
				local child = getglobal(parent.MBBChild);
				MBB_Debug("Child Frame: " .. child:GetName());
				child.parentisvisible = false;
				MBB_Debug("Hiding frame: " .. parent:GetName());
				parent.ohide(select(1, ...));
				if( not MBB_IsInArray(MBB_Exclude, child:GetName()) ) then
					MBB_SetPositions();
				end
			end
		end
		
		buttonframe.oshow = buttonframe.Show;
		buttonframe.Show = function(...)
			local innerframe = select(1, ...);
			innerframe.isvisible = true;
			MBB_Debug("Showing innerframe: " .. innerframe:GetName());
			if( not MBB_IsInArray(MBB_Exclude, innerframe:GetName()) ) then
				MBB_SetPositions();
			end
			if( MBB_IsInArray(MBB_Exclude, innerframe:GetName()) or MBB_IsShown == 1 ) then
				--[[if( innerframe.hasParentFrame ) then
					local parent = innerframe:GetParent();
					parent.oshow(parent);
				else]]
					innerframe.oshow(select(1, ...));
				--end
			end
		end
		buttonframe.ohide = buttonframe.Hide;
		buttonframe.Hide = function(...)
			local innerframe = select(1, ...);
			MBB_Debug("Hiding innerframe: " .. innerframe:GetName());
			if( innerframe ~= buttonframe ) then
				innerframe.isvisible = false;
				innerframe.ohide(innerframe);
			end
			if( not MBB_IsInArray(MBB_Exclude, innerframe:GetName()) ) then
				MBB_SetPositions();
			end
		end
		
		if( buttonframe:HasScript("OnClick") and not hasHeader ) then
			buttonframe.oclick = buttonframe:GetScript("OnClick");
			buttonframe:SetScript("OnClick", function(...)
				if( arg1 and arg1 == "RightButton" and IsControlKeyDown() ) then
					local name = this:GetName();
					if( MBB_IsInArray(MBB_Exclude, name) ) then
						MBB_AddButton(name);
					else
						MBB_RestoreButton(name);
					end
					MBB_SetPositions();
				elseif( this.oclick ) then
					this.oclick(select(1, ...));
				end
			end);
		elseif( buttonframe:HasScript("OnMouseUp") and not hasHeader ) then
			buttonframe.omouseup = buttonframe:GetScript("OnMouseUp");
			buttonframe:SetScript("OnMouseUp", function(...)
				if( arg1 and arg1 == "RightButton" and IsControlKeyDown() ) then
					local name = this:GetName();
					if( MBB_IsInArray(MBB_Exclude, name) ) then
						MBB_AddButton(name);
					else
						MBB_RestoreButton(name);
					end
					MBB_SetPositions();
				elseif( this.omouseup ) then
					this.omouseup(select(1, ...));
				end
			end);
		elseif( buttonframe:HasScript("OnMouseDown") and not hasHeader ) then
			buttonframe.omousedown = buttonframe:GetScript("OnMouseDown");
			buttonframe:SetScript("OnMouseDown", function(...)
				if( arg1 and arg1 == "RightButton" and IsControlKeyDown() ) then
					local name = this:GetName();
					if( MBB_IsInArray(MBB_Exclude, name) ) then
						MBB_AddButton(name);
					else
						MBB_RestoreButton(name);
					end
					MBB_SetPositions();
				elseif( this.omousedown ) then
					this.omousedown(select(1, ...));
				end
			end);
		end
		if( buttonframe:HasScript("OnEnter") and not hasHeader ) then
			buttonframe.oenter = buttonframe:GetScript("OnEnter");
			buttonframe:SetScript("OnEnter", function(...)
				if( IsControlKeyDown() ) then
					local button;
					if( MBB_IsInArray(MBB_Exclude, this:GetName()) ) then
						button = getglobal("MBB_ButtonAdd");
					else
						button = getglobal("MBB_ButtonRemove");
					end
					button.MBBButtonName = this:GetName();
					button:ClearAllPoints();
					button:SetPoint("BOTTOM", this, "TOP", 0, 0);
					button:Show();
				end
				if( not MBB_IsInArray(MBB_Exclude, this:GetName()) ) then
					MBB_ShowTimeout = -1;
				end
				if( this.oenter ) then
					this.oenter(select(1, ...));
				end
			end);
		end
		if( buttonframe:HasScript("OnLeave") and not hasHeader ) then
			buttonframe.oleave = buttonframe:GetScript("OnLeave");
			buttonframe:SetScript("OnLeave", function(...)
				if( not MBB_IsInArray(MBB_Exclude, this:GetName()) ) then
					MBB_ShowTimeout = 0;
				end
				if( this.oleave ) then
					this.oleave(select(1, ...));
				end
			end);
		end
	end
end

function MBB_AddButton(name)
	local child = getglobal(name);
	if( not child or MBB_IsInArray(MBB_Buttons, name) ) then
		return;
	end
	
	child.opoint = {child:GetPoint()};
	if( not child.opoint[1] ) then
		child.opoint = {"TOP", Minimap, "BOTTOM", 0, 0};
	end
	child.osize = {child:GetHeight(),child:GetWidth()};
	child.oclearallpoints = child.ClearAllPoints;
	child.ClearAllPoints = function() end;
	child.osetpoint = child.SetPoint;
	child.SetPoint = function() end;
	if( MBB_IsShown == 0 ) then
		if( child.hasParentFrame ) then
			local parent = child:GetParent();
			if( child.oshow ) then
				child.oshow(child);
			end
			if( parent and parent.ohide ) then
				parent.ohide(parent);
			end
		else
			if( child.ohide ) then
				child.ohide(child);
			end
		end
	end
	table.insert(MBB_Buttons, name);
	local i = MBB_IsInArray(MBB_Exclude, name);
	if( i ) then
		table.remove(MBB_Exclude, i);
	end
end

function MBB_RestoreButton(name)
	local button = getglobal(name);
	if( not button or not button.oclearallpoints or not button.osetpoint ) then
		return;
	end
	
	button.oclearallpoints(button);
	button.osetpoint(button, button.opoint[1], button.opoint[2], button.opoint[3], button.opoint[4], button.opoint[5]);
	button:SetHeight(button.osize[1]);
	button:SetWidth(button.osize[1]);
	button.ClearAllPoints = button.oclearallpoints;
	button.SetPoint = button.osetpoint;
	MBB_Debug("EVENT Restoring Button");
	if( button.hasParentFrame ) then
		local parent = button:GetParent();
		if( parent and parent.oshow ) then
			parent.oshow(parent);
		end
	else
		if( button.oshow ) then
			button.oshow(button);
		end
	end
	
	table.insert(MBB_Exclude, name);
	local i = MBB_IsInArray(MBB_Buttons, button:GetName());
	if( i ) then
		table.remove(MBB_Buttons, i);
	end
end

function MBB_SetPositions()
	local directions = {
		[1] = {"RIGHT", "LEFT"},
		[2] = {"BOTTOM", "TOP"},
		[3] = {"LEFT", "RIGHT"},
		[4] = {"TOP", "BOTTOM"}
	};
	local offsets = {
		[1] = {-5, 0},
		[2] = {0, 5},
		[3] = {5, 0},
		[4] = {0, -5}
	};
	
	local pos = {0, 0};
	local parentid = 0;
	local firstid = 1;
	local count = 1;
	for i,name in ipairs(MBB_Buttons) do
		local positionframe = getglobal(name);
		if( not positionframe ) then
			MBB_Debug("Missing button frame: " .. tostring(name));
		elseif( not positionframe.hasParentFrame ) then
			positionframe.parentisvisible = true;
		end
		if( positionframe and positionframe.isvisible and positionframe.parentisvisible ) then
			local parent;
			if( parentid==0 ) then
				parent = MBB_MinimapButtonFrame;
			else
				parent = getglobal(MBB_Buttons[parentid]);
			end
			if( not parent ) then
				parent = MBB_MinimapButtonFrame;
			end
			
			if( not MBB_IsInArray(MBB_IgnoreSize, name) ) then
				if( MBB_ExtraSize[name] ) then
					local func = MBB_ExtraSize[name];
					func();
				else
					positionframe:SetHeight(31); -- 33
					positionframe:SetWidth(31);
				end
			end
			
			local direction;
			
			if( MBB_Options.MaxButtonsPerLine > 0 and count > MBB_Options.MaxButtonsPerLine ) then
				parent = getglobal(MBB_Buttons[firstid]);
				if( not parent ) then
					parent = MBB_MinimapButtonFrame;
				end
				direction = {directions[MBB_Options.AltExpandDirection][1], directions[MBB_Options.AltExpandDirection][2]};
				if( MBB_ExtraSize[name] or MBB_IsInArray(MBB_IgnoreSize, name) or MBB_ExtraSize[parent:GetName()] or MBB_IsInArray(MBB_IgnoreSize, parent:GetName()) ) then
					pos = offsets[MBB_Options.AltExpandDirection];
				else
					pos = {0, 0};
				end
				count = 2;
				firstid = i;
			else
				direction = {directions[MBB_Options.ExpandDirection][1], directions[MBB_Options.ExpandDirection][2]};
				if( MBB_ExtraSize[name] or MBB_IsInArray(MBB_IgnoreSize, name) or MBB_ExtraSize[parent:GetName()] or MBB_IsInArray(MBB_IgnoreSize, parent:GetName()) ) then
					pos = offsets[MBB_Options.ExpandDirection];
				else
					pos = {0, 0};
				end
				count = count + 1;
			end
			
			positionframe.oclearallpoints(positionframe);
			positionframe.osetpoint(positionframe, direction[1], parent, direction[2], pos[1], pos[2]);
			
			parentid = i;
		end
	end
end

function MBB_OnClick(arg1)
	if( arg1 and arg1 == "RightButton" and IsControlKeyDown() ) then
		if( MBB_Options.AttachToMinimap == 1 ) then
			--[[local xpos,ypos = GetCursorPosition();
			local scale = GetCVar("uiScale");]]
			MBB_Options.AttachToMinimap = 0;
			MBB_Options.ButtonPos = {0, 0};	--{(xpos/scale)-10, (ypos/scale)-10};
			MBB_Options.ButtonPoint = {"CENTER", "CENTER", 0, 0};
			MBB_SetButtonPosition();
		else
			MBB_Options.AttachToMinimap = 1;
			MBB_Options.ButtonPos = MBB_CopyOptionValue(MBB_DefaultOptions.ButtonPos);
			MBB_Options.ButtonPoint = MBB_CopyOptionValue(MBB_DefaultOptions.ButtonPoint);
			MBB_SetButtonPosition();
		end
	elseif( arg1 and arg1 == "RightButton" ) then
		MBB_OptionsFrame:Show();
	else
		if( MBB_IsShown == 1 ) then
			MBB_HideButtons();
		else
			MBB_Debug("EVENT OnClick");
			for i,name in ipairs(MBB_Buttons) do
				local clickframe = getglobal(name);
				if( clickframe and not clickframe.hasParentFrame ) then
					clickframe.parentisvisible = true;
				end
				if( clickframe and clickframe.isvisible and clickframe.parentisvisible ) then
					if( clickframe.hasParentFrame and clickframe.hasParentFrame ) then
						local parent = clickframe:GetParent();
						if( parent and parent.oshow ) then
							parent.oshow(parent);
						elseif( parent ) then
							if( parent:GetName() ) then
								if( not MBB_DebugInfo[parent:GetName()] ) then
									MBB_DebugInfo[parent:GetName()] = {};
								end
								if( not MBB_IsInArray(MBB_DebugInfo[parent:GetName()], "No oshow") ) then
									table.insert(MBB_DebugInfo[parent:GetName()], "No oshow");
								end
							end
						end
					elseif( clickframe.oshow ) then
						clickframe.oshow(clickframe);
					end
				end
			end
			MBB_IsShown = 1;
			--MBB_ShowTimeout = 0;
		end
	end
end

function MBB_HideButtons()
	MBB_ShowTimeout = -1;
	for i,name in ipairs(MBB_Buttons) do
		local buttonhideframe = getglobal(name);
		if( buttonhideframe and buttonhideframe.hasParentFrame ) then
			local parent = buttonhideframe:GetParent();
			if( parent and parent.ohide ) then
				parent.ohide(parent);
			elseif( parent ) then
				if( parent:GetName() ) then
					if( not MBB_DebugInfo[parent:GetName()] ) then
						MBB_DebugInfo[parent:GetName()] = {};
					end
					if( not MBB_IsInArray(MBB_DebugInfo[parent:GetName()], "No ohide") ) then
						table.insert(MBB_DebugInfo[parent:GetName()], "No ohide");
					end
				end
				buttonhideframe.ohide(buttonhideframe);
			end
		elseif( buttonhideframe and buttonhideframe.ohide ) then
			buttonhideframe.ohide(buttonhideframe);
		end
	end
	MBB_IsShown = 0;
end

function MBB_IsKnownButton(name, opt)
	if( not name ) then
		return false;
	end
	if( not opt ) then
		opt = 1;
	end
	
	if( opt <= 1 ) then
		for _, button in ipairs(MBB_Buttons) do
			if( button == name ) then
				return true;
			end
		end
	end
	if( opt <= 2 ) then
		for _, button in ipairs(MBB_Exclude) do
			if( button == name ) then
				return true;
			end
		end
	end
	if( opt <= 3 ) then
		for _, button in ipairs(MBB_Ignore) do
			if( string.find(name, button) ) then
				return true;
			end
		end
	end
	
	return false;
end

function MBB_OnUpdate(elapsed)
	if( MBB_CheckTime >= 3 ) then
		MBB_CheckTime = 0;
		local children = MBB_GetChildren(Minimap);
		for _, child in ipairs(children) do
			if( child and child.HasScript and child.GetName ) then
				local name = child:GetName();
				if( name and child:HasScript("OnClick") and not child.oshow and not MBB_IsKnownButton(name, 3) ) then
					MBB_PrepareButton(name);
					if( not MBB_IsInArray(MBB_Exclude, name) ) then
						MBB_AddButton(name);
						MBB_SetPositions();
					end
				end
			end
		end
	else
		MBB_CheckTime = MBB_CheckTime + elapsed;
	end
	
	if( MBB_DragFlag == 1 and MBB_Options.AttachToMinimap == 1 ) then
		local xpos,ypos = GetCursorPosition();
		local xmin,ymin = Minimap:GetLeft(), Minimap:GetBottom();

		xpos = xmin-xpos/Minimap:GetEffectiveScale()+70;
		ypos = ypos/Minimap:GetEffectiveScale()-ymin-70;

		local angle = math.deg(math.atan2(ypos,xpos));
		
		local buttonX = 53-(cos(angle)*81);
		local buttonY = -55+(sin(angle)*81);
		MBB_MinimapButtonFrame:ClearAllPoints();
		MBB_MinimapButtonFrame:SetPoint("TOPLEFT", Minimap, "TOPLEFT", buttonX, buttonY);
		MBB_Options.ButtonPos = {buttonX, buttonY};
		MBB_Options.ButtonPoint = {"TOPLEFT", "TOPLEFT", buttonX, buttonY};
	end
	
	if( MBB_Options.CollapseTimeout and MBB_Options.CollapseTimeout ~= 0 ) then
		if( MBB_ShowTimeout >= MBB_Options.CollapseTimeout and MBB_IsShown == 1 ) then
			MBB_HideButtons();
		end
		if( MBB_ShowTimeout ~= -1 ) then
			MBB_ShowTimeout = MBB_ShowTimeout + elapsed;
		end
	end
end

function MBB_ResetPosition()
	MBB_Options.ButtonPos = MBB_CopyOptionValue(MBB_DefaultOptions.ButtonPos);
	MBB_Options.ButtonPoint = MBB_CopyOptionValue(MBB_DefaultOptions.ButtonPoint);
	MBB_Options.AttachToMinimap = MBB_DefaultOptions.AttachToMinimap;
	
	MBB_SetButtonPosition();
end

function MBB_SaveButtonPosition()
	if( not MBB_MinimapButtonFrame or not MBB_MinimapButtonFrame.GetPoint ) then
		return;
	end

	local point, _, relativePoint, xpos, ypos = MBB_MinimapButtonFrame:GetPoint();
	if( type(xpos) ~= "number" or type(ypos) ~= "number" ) then
		return;
	end

	if( MBB_Options.AttachToMinimap == 1 ) then
		MBB_Options.ButtonPos = {xpos, ypos};
		MBB_Options.ButtonPoint = {"TOPLEFT", "TOPLEFT", xpos, ypos};
		return;
	end

	if( not MBB_IsValidPoint(point) ) then
		point = "CENTER";
	end
	if( not MBB_IsValidPoint(relativePoint) ) then
		relativePoint = point;
	end

	MBB_Options.ButtonPos = {xpos, ypos};
	MBB_Options.ButtonPoint = {point, relativePoint, xpos, ypos};
end

function MBB_OnDragStop()
	if( MBB_Options.AttachToMinimap == 1 ) then
		MBB_DragFlag = 0;
	else
		MBB_MinimapButtonFrame:StopMovingOrSizing();
	end
	MBB_SaveButtonPosition();
end

function MBB_SetButtonPosition()
	MBB_NormalizeOptions();

	if( MBB_Options.AttachToMinimap == 1 ) then
		MBB_MinimapButtonFrame:ClearAllPoints();
		MBB_MinimapButtonFrame:SetPoint("TOPLEFT", Minimap, "TOPLEFT", MBB_Options.ButtonPos[1], MBB_Options.ButtonPos[2]);
		MBB_Options.ButtonPoint = {"TOPLEFT", "TOPLEFT", MBB_Options.ButtonPos[1], MBB_Options.ButtonPos[2]};
	else
		local buttonPoint = MBB_Options.ButtonPoint;
		MBB_MinimapButtonFrame:ClearAllPoints();
		MBB_MinimapButtonFrame:SetPoint(buttonPoint[1], UIParent, buttonPoint[2], buttonPoint[3], buttonPoint[4]);
		MBB_Options.ButtonPos = {buttonPoint[3], buttonPoint[4]};
	end
end

function MBB_RadioButton_OnClick(id, alt)
	local substring;
	if( alt ) then
		substring = "Alt";
	else
		substring = "";
	end
	local buttons = {
		[1] = "Left",
		[2] = "Top",
		[3] = "Right",
		[4] = "Bottom"
	};
	
	for i,name in ipairs(buttons) do
		if( i == id ) then
			getglobal("MBB_OptionsFrame_" .. name .. substring .. "Radio"):SetChecked(true);
		else
			getglobal("MBB_OptionsFrame_" .. name .. substring .. "Radio"):SetChecked(nil);
		end
	end
end

function MBB_UpdateAltRadioButtons()
	local buttons = {
		[1] = "Left",
		[2] = "Top",
		[3] = "Right",
		[4] = "Bottom"
	};
	
	local exchecked = 1;
	
	for i,name in pairs(buttons) do
		if( getglobal("MBB_OptionsFrame_" .. name .. "Radio"):GetChecked() ) then
			exchecked = i;
			break;
		end
	end
	
	local checked = false;
	local textbox = getglobal("MBB_OptionsFrame_MaxButtonsTextBox");
	
	for i,name in pairs(buttons) do
		local radio = getglobal("MBB_OptionsFrame_" .. name .. "AltRadio");
		local label = getglobal("MBB_OptionsFrame_" .. name .. "AltRadioLabel");
		if( textbox:GetText() == "" or tonumber(textbox:GetText()) == 0 ) then
			radio:Disable();
			radio:SetChecked(nil);
			label:SetTextColor(0.5, 0.5, 0.5);
		else
			if( exchecked % 2 == i % 2 ) then
				if( radio:GetChecked() ) then
					checked = true;
					if( i == 4 ) then
						getglobal("MBB_OptionsFrame_LeftAltRadio"):SetChecked(true);
					else
						getglobal("MBB_OptionsFrame_" .. buttons[i+1] .. "AltRadio"):SetChecked(true);
					end
				end
				radio:Disable();
				radio:SetChecked(nil);
				label:SetTextColor(0.5, 0.5, 0.5);
			else
				if( radio:GetChecked() ) then
					checked = true;
				end
				radio:Enable();
				label:SetTextColor(1, 1, 1);
			end
		end
	end
	
	if( not checked and tonumber(textbox:GetText()) ~= 0 and textbox:GetText() ~= "" ) then
		if( exchecked % 2 == 1 ) then
			getglobal("MBB_OptionsFrame_TopAltRadio"):SetChecked(true);
		else
			getglobal("MBB_OptionsFrame_LeftAltRadio"):SetChecked(true);
		end
	end
end

function MBB_Debug(msg)
	if (MBB_DebugFlag == 1) then
		MBB_Print("MBB Debug : " .. tostring(msg));
	end
end

function MBB_Test()
	local children = MBB_GetChildren(Minimap);
	for _, child in ipairs(children) do
		if( child.GetName and child:GetName() and not MBB_IsKnownButton(child:GetName()) ) then
			ChatFrame1:AddMessage(child:GetName());
		end
	end
end

function MBB_IsInArray(array, needle)
	if(type(array) == "table") then
		--MBB_Debug("Looking for " .. tostring(needle) .. " in " .. tostring(array));
		for i, element in pairs(array) do
			if(type(element) ==  type(needle) and element == needle) then
				return i;
			end
		end
	end
	return nil;
end

function MBB_SecureOnClick(self, button, down)
	local name = self:GetName();
	if(name) then -- trap to check for nils
		MBB_Debug("Name: " .. name);
		MBB_Debug("Button: " .. button);
		if( MBB_IsInArray(MBB_Buttons, name) ) then
			if( button == "RightButton" and IsControlKeyDown() ) then
				MBB_Debug("Restoring button: " .. name);
				MBB_RestoreButton(name);
				MBB_SetPositions();
			end
		elseif( MBB_IsInArray(MBB_Exclude, name) ) then
			if( button == "RightButton" and IsControlKeyDown() ) then
				MBB_Debug("Adding button: " .. name);
				MBB_AddButton(name);
				MBB_SetPositions();
			end
		end
	end
end

function MBB_SecureOnEnter(self)
	local name = self:GetName();
	if(name) then -- trap to check for nils
		MBB_Debug("Name: " .. name);
		if( MBB_IsInArray(MBB_Buttons, name) ) then
			if( IsControlKeyDown() ) then
				local button = getglobal("MBB_ButtonRemove");
				button.MBBButtonName = name;
				button:ClearAllPoints();
				button:SetPoint("BOTTOM", this, "TOP", 0, 0);
				button:Show();
			end
			MBB_ShowTimeout = -1;
		elseif( MBB_IsInArray(MBB_Exclude, name) ) then
			if( IsControlKeyDown() ) then
				local button = getglobal("MBB_ButtonAdd");
				button.MBBButtonName = name;
				button:ClearAllPoints();
				button:SetPoint("BOTTOM", this, "TOP", 0, 0);
				button:Show();
			end
		end
	end
end

function MBB_SecureOnLeave(self)
	local name = self:GetName();
	if(name) then -- trap to check for nils
		MBB_Debug("Name: " .. name);
		if( MBB_IsInArray(MBB_Buttons, name) ) then
			MBB_ShowTimeout = 0;
		elseif( MBB_IsInArray(MBB_Exclude, name) ) then
		
		end
	end
end

function MBB_Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage(msg, 0.2, 0.8, 0.8);
end

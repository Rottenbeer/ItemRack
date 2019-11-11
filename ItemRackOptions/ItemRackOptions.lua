local _

ItemRackOpt = {
	Icons = {}, -- list of all icons possible for a set
	Inv = {}, -- 0-19 currently chosen items per slot
	HoldInv = {}, -- 0-19 ItemRackOpt.Inv held when picking set
	SetList = {}, -- numerically-indexed list of set names
	selectedIcon = 0,
	prevFrame = nil, -- previous subframe a frame should return to (ItemRackOptSubFrame1-x)
	numSubFrames = 8, -- number of subframes
	slotOrder = {1,2,3,15,5,4,19,9,16,17,18,0,14,13,12,11,8,7,6,10,6,7,8,11,12,13,14,0,18,17,16,9,19,4,5,15,3,2},
	currentMarquee = 1,
}

ItemRack.CheckButtonLabels = {
	["ItemRackOptItemStatsPriorityText"] = "Priority",
	["ItemRackOptItemStatsKeepEquippedText"] = "Pause Queue",
	["ItemRackOptQueueEnableText"] = "Auto Queue This Slot",
	["ItemRackOptSetsHideCheckButtonText"] = "Hide",
	["ItemRackOptEventEditBuffAnyMountText"] = "Any mount",
	["ItemRackOptEventEditBuffUnequipText"] = "Unequip when buff fades",
	["ItemRackOptEventEditBuffNotInPVPText"] = "Except in PVP instances",
	["ItemRackOptEventEditStanceUnequipText"] = "Unequip on leaving stance",
	["ItemRackOptEventEditZoneUnequipText"] = "Unequip on leaving zone",
	["ItemRackOptEventEditStanceNotInPVPText"] = "Except in PVP instances",
}

function ItemRackOpt.InvOnEnter(self)
	local id = self:GetID()
	if ItemRack.IsTimerActive("SlotMarquee") then
		_G["ItemRackOptInv"..id.."Icon"]:SetVertexColor(1,1,1,1)
		return
	end
	local menuDock,mainDock,menuOrient = "TOPRIGHT","TOPLEFT","HORIZONTAL"
	if id==0 or (id>=16 and id<=18) then
		menuDock,mainDock,menuOrient = "TOPLEFT","BOTTOMLEFT","VERTICAL"
	elseif id>=6 and id<=14 and id~=9 then
		menuDock,mainDock = "TOPLEFT","TOPRIGHT"
	end
	ItemRack.DockWindows(menuDock,_G["ItemRackOptInv"..id],mainDock,menuOrient)
	ItemRack.BuildMenu(id,ItemRackSettings.EquipOnSetPick=="OFF" and 1)
	ItemRack.IDTooltip(self,ItemRackOpt.Inv[id].id)
end

function ItemRackOpt.InvOnLeave(self)
	ItemRack.ClearTooltip()
	if ItemRack.IsTimerActive("SlotMarquee") then
		_G["ItemRackOptInv"..self:GetID().."Icon"]:SetVertexColor(.25,.25,.25,1)
	end
end

function ItemRackOpt.OnLoad(self)
	table.insert(UISpecialFrames,"ItemRackOptFrame")
	ItemRackOptInv0:SetScale(.8)
	for i=0,19 do
		ItemRackOpt.Inv[i] = {}
		ItemRackOpt.HoldInv[i] = {}
	end
	ItemRackOpt.PopulateInitialIcons()
	ItemRackOpt.PopulateEventList()
	ItemRackOptSetsCurrentSet:EnableMouse(false)

	ItemRackOptFrameTitle:SetText("IR "..ItemRack.Version)

	-- OptInfo: this table drives the scrollable options. must be defined after xml defined (so buttons are non-nil)
	-- type = "label", "check", "number", "slider", "button" : what type of option element
	-- optset = ItemRackUser or ItemRackSettings : which table setting exists in
	-- variable = "Var" : index of the optset. ie, ItemRackUser.Locked is optset ItemRackUser, variable "Locked"
	-- depend = "Var" : option depends on optset["Var"]=="ON"
	-- label = "string" : text of option
	-- tooltip = "string" : tooltip shown on option
	-- button = frame : reference to the button shown on the option (editbox, slider or actual button)
	-- combatlock = 1/nil : whether option can be changed in combat (key bindings, hide when ooc, etc)
	ItemRackOpt.OptInfo = {
		{type="label",label=(UnitName("player")).."'s Settings"},
		{type="check",optset=ItemRackUser,variable="Locked",label="Lock Buttons",tooltip="Prevent buttons and menus from being moved."},
		{type="check",optset=ItemRackUser,variable="EnableEvents",label="Enable events",tooltip="Enable events to automatically swap gear."},
		{type="check",optset=ItemRackUser,variable="EnableQueues",label="Enable auto queues",tooltip="Enables auto queues to automatically swap gear."},
		{type="number",optset=ItemRackUser,variable="ButtonSpacing",button=ItemRackOptButtonSpacing,label="Button spacing",tooltip="Padding distance between buttons.",combatlock=1},
		{type="slider",button=ItemRackOptButtonSpacingSlider,variable="ButtonSpacing",label="Button spacing",tooltip="Padding distance between buttons.", min=0, max=24, step=1, form="%d",combatlock=1},
		{type="number",optset=ItemRackUser,variable="Alpha",button=ItemRackOptAlpha,label="Transparency",tooltip="Transparency (alpha) of the buttons and menu."},
		{type="slider",button=ItemRackOptAlphaSlider,variable="Alpha",label="Transparency",tooltip="Transparency (alpha) of the buttons and menu.", min=.1, max=1, step=.05, form="%.2f"},
		{type="number",optset=ItemRackUser,variable="MainScale",button=ItemRackOptMainScale,label="Button scale",tooltip="Scale size of the item buttons.",combatlock=1},
		{type="slider",button=ItemRackOptMainScaleSlider,variable="MainScale",label="Button scale",tooltip="Scale size of the item buttons.", min=.5, max=2, step=.05, form="%.2f",combatlock=1},

		{type="number",optset=ItemRackUser,variable="MenuScale",button=ItemRackOptMenuScale,label="Menu scale",tooltip="Scale size of the menu in relation to the button it's docked to."},
		{type="slider",button=ItemRackOptMenuScaleSlider,variable="MenuScale",label="Menu scale",tooltip="Scale size of the menu.", min=.5, max=2, step=.05, form="%.2f"},

		{type="check",optset=ItemRackUser,variable="SetMenuWrap",label="Set menu wrap",tooltip="Check this to set a fixed value when the menu wraps to a new row.  Uncheck to let ItemRack decide."},

		{type="number",optset=ItemRackUser,variable="SetMenuWrapValue",depend="SetMenuWrap",button=ItemRackOptSetMenuWrapValue,label="When to wrap",tooltip="When 'Set menu wrap' checked, this is the number of menu items before wrapping to a new row/column."},
		{type="slider",optset=ItemRackUser,button=ItemRackOptSetMenuWrapValueSlider,depend="SetMenuWrap",variable="SetMenuWrapValue",label="When to wrap",tooltip="When 'Set menu wrap' checked, this is the number of menu items before wrapping to a new row/column.", min=1, max=30, step=1, form="%d"},

		{type="label",label="Global Settings"},
		{type="check",optset=ItemRackSettings,variable="MenuOnShift",label="Menu on Shift",tooltip="Only show menu while Shift is held down."},
		{type="check",optset=ItemRackSettings,variable="MenuOnRight",label="Menu on right click",tooltip="Open menu by right clicking buttons.",combatlock=1},
		{type="check",optset=ItemRackSettings,variable="HideOOC",label="Hide out of combat",tooltip="Hide the buttons while out of combat.",combatlock=1},
		{type="check",optset=ItemRackSettings,variable="HidePetBattle",label="Hide during pet battles",tooltip="Hide the buttons during a pet battle."},
		{type="check",optset=ItemRackSettings,variable="Notify",label="Notify when ready",tooltip="Announce when an item you used comes off cooldown."},
		{type="check",optset=ItemRackSettings,variable="NotifyThirty",label="Notify at 30",tooltip="Announce when an item you used is at 30 seconds cooldown."},
		{type="check",optset=ItemRackSettings,variable="NotifyChatAlso",label="Notify chat also",tooltip="Send cooldown notifications to chat also."},
		{type="check",optset=ItemRackSettings,variable="ShowSetInTooltip",label="Show set info in tooltips",tooltip="Show which set an item belongs to in the tooltip."},
		{type="check",optset=ItemRackSettings,variable="ShowTooltips",label="Show tooltips",tooltip="Show tooltips like the one you're reading now."},
		{type="check",optset=ItemRackSettings,variable="TinyTooltips",depend="ShowTooltips",label="Tiny Tooltips",tooltip="Shrink item tooltips to display only name, cooldown and durability."},
		{type="check",optset=ItemRackSettings,variable="TooltipFollow",depend="ShowTooltips",label="Tooltips at pointer",tooltip="Show tooltips near the mouse."},
		{type="check",optset=ItemRackSettings,variable="CooldownCount",label="Cooldown numbers",tooltip="Display the cooldown time as a number over items."},
		{type="check",optset=ItemRackSettings,variable="LargeNumbers",depend="CooldownCount",label="Large numbers",tooltip="Use a larger font for cooldown numbers."},
		{type="check",optset=ItemRackSettings,variable="Cooldown90",depend="CooldownCount",label="Countdown at 90",tooltip="Use seconds instead of minutes starting at 90 seconds remaining."},
		{type="check",optset=ItemRackSettings,variable="AllowEmpty",label="Allow empty slots",tooltip="Add an empty slot to menus of equipped items."},
		{type="check",optset=ItemRackSettings,variable="AllowHidden",label="Allow hidden items",tooltip="Enable Alt+clicking of menu items to hide/show them in the menu.  Hold Alt as you enter a menu to show all."},
		{type="check",optset=ItemRackSettings,variable="HideTradables",label="Hide tradables",tooltip="Prevent tradable items from showing up in the menu."},
		{type="check",optset=ItemRackSettings,variable="ShowMinimap",label="Show minimap button",tooltip="Show the minimap button to access options or change sets."},
		{type="check",optset=ItemRackSettings,variable="SquareMinimap",depend="ShowMinimap",label="Square minimap",tooltip="If you use a square minimap, make the button drag along square edge."},
		{type="check",optset=ItemRackSettings,variable="MinimapTooltip",depend="ShowMinimap",label="Show minimap tooltip",tooltip="If tooltips enabled, show what mouse clicks will do when clicking the minimap button."},
		{type="check",optset=ItemRackSettings,variable="TrinketMenuMode",label="TrinketMenu mode",tooltip="When mouseover of either trinket slot, open anchored to the top trinket.  Left click of a menu item will equip to the top trinket.  Right click will equip to the bottom trinket."},
		{type="check",optset=ItemRackSettings,variable="AnchorOther",depend="TrinketMenuMode",label="Anchor other trinket",tooltip="In TrinketMenu mode, trinket menus dock to the top trinket.  Check this to anchor them to the bottom trinket."},
		{type="check",optset=ItemRackSettings,variable="EquipToggle",label="Toggle sets on equip",tooltip="When a set is equipped, if it's already equipped, unequip it."},
		{type="check",optset=ItemRackSettings,variable="ShowHotKeys",label="Show key bindings",tooltip="Display key bindings on buttons"},
		{type="check",optset=ItemRackSettings,variable="EquipOnSetPick",label="Equip in options",tooltip="Check this to equip sets and items when selecting items in options or from the dropdown in the Sets tab."},
		{type="check",optset=ItemRackSettings,variable="CharacterSheetMenus",label="Character sheet menus",tooltip="While this is checked, mouseover of slots on the character sheet will pop out a menu of items that can go in that slot."},
		{type="check",optset=ItemRackSettings,variable="DisableAltClick",label="Disable Alt+Click",tooltip="Alt+Click on buttons dragged from the character sheet toggles auto queue for that slot.  Check this to disable that behavior. (ie to use Alt+click to self cast instead.)",combatlock=1},
		{type="label",label=""},
		{type="button",button=ItemRackOptKeyBindings,label="Slot Key Bindings",tooltip="Set key bindings to use slots.",combatlock=1},
		{type="button",button=ItemRackOptResetBar,label="Reset Buttons",tooltip="Remove all buttons and restore to default alpha and scale.",combatlock=1},
		{type="button",button=ItemRackOptResetEvents,label="Reset Events",tooltip="Restore default events or wipe all events to default settings."},
		{type="button",button=ItemRackOptResetEverything,label="Reset Everything",tooltip="Wipe all settings, sets and events to restore mod to a default state.",combatlock=1},
	}

	ItemRackOpt.InitializeSliders()
	ItemRackOpt.TabOnClick(self,1) -- start at tab 1 (config)

	ItemRackOptBindFrame:EnableMouseWheel(true)

	ItemRack.CreateTimer("SlotMarquee",ItemRackOpt.SlotMarquee,.1,1)

	for i in pairs(ItemRack.CheckButtonLabels) do
		_G[i]:SetText(ItemRack.CheckButtonLabels[i])
		_G[i]:SetTextColor(1,1,1,1)
	end

end

function ItemRackOpt.InitializeSliders()
	local opt,button
	for i=1,#(ItemRackOpt.OptInfo) do
		opt = ItemRackOpt.OptInfo[i]
		if opt.type=="slider" then
			opt.button:SetMinMaxValues(opt.min,opt.max)
			opt.button:SetValueStep(opt.step)
			opt.button:SetValue(ItemRackUser[opt.variable])
			_G[opt.button:GetName().."Min"]:SetText(string.format(opt.form,opt.min))
			_G[opt.button:GetName().."Max"]:SetText(string.format(opt.form,opt.max))
			opt.button.form = opt.form
			opt.button.min = opt.min
			opt.button.max = opt.max
			ItemRackOpt.UpdateSlider(opt.variable)
		end
	end
end

function ItemRackOpt.OnShow(setname)
	for i=0,19 do
		ItemRackOpt.Inv[i].id = ItemRack.GetID(i)
	end
	if ItemRackUser.CurrentSet and ItemRackUser.Sets[ItemRackUser.CurrentSet] then
		ItemRackOptSetsName:SetText(ItemRackUser.CurrentSet)
		ItemRackOpt.selectedIcon = ItemRackUser.Sets[ItemRackUser.CurrentSet].icon
		for i=0,19 do
			ItemRackOpt.Inv[i].selected = ItemRackUser.Sets[ItemRackUser.CurrentSet].equip[i] and 1 or nil
		end
	else
		ItemRackOptSetsName:SetText("")
		ItemRackOpt.selectedIcon = ItemRackOpt.Icons[math.random(#(ItemRackOpt.Icons)-20)+20]
	end
	ItemRackOpt.UpdateInv()
	ItemRackOptSubFrame5:Hide()
	ItemRackOpt.ListScrollFrameUpdate()
end

function ItemRackOpt.ChangeEditingSet()
	local setname = ItemRackUser.CurrentSet
	if setname and ItemRackUser.Sets[setname] then
		local set = ItemRackUser.Sets[setname].equip
		for i=0,19 do
			if set[i] then
				ItemRackOpt.Inv[i].id = set[i]
				ItemRackOpt.Inv[i].selected = 1
			else
				ItemRackOpt.Inv[i].selected = nil
				ItemRackOpt.Inv[i].id = ItemRack.GetID(i)
			end
		end
		ItemRackOptSetsName:SetText(setname)
		ItemRackOpt.selectedIcon = ItemRackUser.Sets[setname].icon
		ItemRackOpt.UpdateInv()
		ItemRackOptSubFrame5:Hide()
	end
end

function ItemRackOpt.UpdateInv()
	if ItemRack.IsTimerActive("SlotMarquee") then return end
	local icon,texture,border,item
	for i=0,19 do
		icon = _G["ItemRackOptInv"..i.."Icon"]
		border = _G["ItemRackOptInv"..i.."Border"]
		border:Hide()
		if ItemRackOpt.Inv[i].id~=0 then
			_,texture = ItemRack.GetInfoByID(ItemRackOpt.Inv[i].id) --pass the button's ItemRack-style ID to a function that retrieves the texture for the item 
			if ItemRackOpt.Inv[i].selected and ItemRack.GetCountByID(ItemRackOpt.Inv[i].id)==0 then
				if ItemRack.FindInBank(ItemRackOpt.Inv[i].id) then
					border:SetVertexColor(.3,.5,1)
				else
					border:SetVertexColor(1,.1,.1)
				end
				_G["ItemRackOptInv"..i.."Border"]:Show()
			end
		else
			_,texture = GetInventorySlotInfo(ItemRack.SlotInfo[i].name)
		end
		icon:SetTexture(texture)
		item = _G["ItemRackOptInv"..i]
		item:UnlockHighlight()
		if ItemRackOpt.Inv[i].selected then
			icon:SetVertexColor(1,1,1)
			if ItemRackOpt.Inv[i].id==0 then
				item:LockHighlight()
			end
		else
			icon:SetVertexColor(.25,.25,.25)
		end
	end
	ItemRackOpt.PopulateInvIcons()
	ItemRackOpt.ValidateSetButtons()
	ItemRackOptSetsCurrentSetIcon:SetTexture(ItemRackOpt.selectedIcon)
end

function ItemRackOpt.ToggleInvSelect(self)
	local id = self:GetID()
	self:SetChecked(false)
	if ItemRack.IsTimerActive("SlotMarquee") or ItemRackOptSubFrame4:IsVisible() then
		if ItemRackOptSubFrame6:IsVisible() then
			ItemRackOpt.BindSlot(id)
		else
			ItemRackOpt.SetupQueue(id)
		end
	elseif IsShiftKeyDown() then
		ItemRack.ChatLinkID(ItemRackOpt.Inv[id].id)
	else
		ItemRackOpt.Inv[id].selected = not ItemRackOpt.Inv[id].selected
		ItemRackOpt.UpdateInv()
	end
end

-- central function for handling the buttons throughout options UI
function ItemRackOpt.ButtonOnClick(self)

	local button = self:GetName()

	if button=="ItemRackOptToggleInvAll" then
		local state = not ItemRackOpt.Inv[1].selected
		for i=0,19 do
			ItemRackOpt.Inv[i].selected = state
		end
		ItemRackOpt.UpdateInv()
	elseif button=="ItemRackOptClose" then
		ItemRackOptFrame:Hide()
	elseif button=="ItemRackOptSetsSaveButton" then
		ItemRackOpt.SaveSet()
	elseif button=="ItemRackOptSetsDeleteButton" then
		ItemRackOpt.DeleteSet()
		ItemRackOpt.ValidateSetButtons()
	elseif button=="ItemRackOptSetsBindButton" then
		ItemRackOpt.BindSet()
	elseif button=="ItemRackOptSetsDropDownButton" then
		ItemRackOptSubFrame5:Show()
	elseif button=="ItemRackOptSetListClose" then
		ItemRackOptSubFrame5:Hide()
	elseif button=="ItemRackOptSlotBindCancel" then
		ItemRackOptSubFrame6:Hide()
	elseif button=="ItemRackOptBindCancel" then
		ItemRackOptBindFrame:Hide()
	elseif button=="ItemRackOptBindUnbind" then
		ItemRackOpt.UnbindKey()
		ItemRackOptBindFrame:Hide()
	elseif button=="ItemRackOptKeyBindings" then
		ItemRackOptSubFrame6:Show()
	elseif button=="ItemRackOptSortListClose" then
		ItemRackOptSubFrame7:Hide()
	elseif button=="ItemRackOptResetBar" then
		ItemRack.ResetButtons()
	elseif button=="ItemRackOptResetEverything" then
		ItemRack.ResetEverything()
	elseif button=="ItemRackOptEventEdit" then
		ItemRackOptSubFrame8:Show()
	elseif button=="ItemRackOptEventEditCancel" then
		ItemRackOptSubFrame8:Hide()
	elseif button=="ItemRackOptEventNew" then
		ItemRackOpt.EventSelected = nil
		ItemRackOpt.EventListScrollFrameUpdate()
		ItemRackOpt.ValidateEventListButtons()
		ItemRackOptSubFrame8:Show()
	elseif button=="ItemRackOptEventEditSave" then
		ItemRackOpt.EventEditSave()
	elseif button=="ItemRackOptEventDelete" then
		ItemRackOpt.EventEditDelete()
	elseif button=="ItemRackOptEventEditExpand" then
		ItemRackOpt.ToggleEventEditor()
	elseif button=="ItemRackFloatingEditorClose" then
		ItemRackFloatingEditor:Hide()
	elseif button=="ItemRackOptResetEvents" then
		ItemRack.ResetEvents()
	elseif button=="ItemRackFloatingEditorSave" then
		ItemRackFloatingEditor:Hide()
		ItemRackOpt.EventEditSave()
	elseif button=="ItemRackFloatingEditorTest" then
		RunScript(ItemRackFloatingEditorEditBox:GetText())
	elseif button=="ItemRackFloatingEditorUndo" then
		ItemRackFloatingEditorEditBox:SetText(ItemRackOptEventEditScriptEditBox:GetText())
	end
end

--[[ Icon choices ]]

function ItemRackOpt.PopulateInvIcons()
	local texture
	for i=0,19 do
		if ItemRackOpt.Inv[i].id and ItemRackOpt.Inv[i].id~=0 then
			_,texture = ItemRack.GetInfoByID(ItemRackOpt.Inv[i].id)
		else
			_,texture = GetInventorySlotInfo(ItemRack.SlotInfo[i].name)
		end
		ItemRackOpt.Icons[i+1] = texture
	end
	ItemRackOpt.SetsIconScrollFrameUpdate()
end

function ItemRackOpt.PopulateInitialIcons()
	ItemRackOpt.Icons = {}
	for i=0,19 do
		table.insert(ItemRackOpt.Icons,"Interface\\Icons\\INV_Misc_QuestionMark")
	end
	ItemRackOpt.PopulateInvIcons()
	table.insert(ItemRackOpt.Icons,"Interface\\Icons\\INV_Banner_02")
	table.insert(ItemRackOpt.Icons,"Interface\\Icons\\INV_Banner_03")
	RefreshPlayerSpellIconInfo()
	local numMacros = #GetMacroIcons(MACRO_ICON_FILENAMES)
	local texture
	for i=1,numMacros do
		texture = GetSpellorMacroIconInfo(i)
		if(type(texture) == "number") then
			table.insert(ItemRackOpt.Icons,texture)
		else
			table.insert(ItemRackOpt.Icons,"Interface\\Icons\\"..texture)
		end
	end
end

function ItemRackOpt.SetsIconScrollFrameUpdate()

	local item, texture, idx
	local offset = FauxScrollFrame_GetOffset(ItemRackOptSetsIconScrollFrame)

	FauxScrollFrame_Update(ItemRackOptSetsIconScrollFrame, ceil(#(ItemRackOpt.Icons)/5),5,28)
	
	for i=1,25 do
		item = _G["ItemRackOptSetsIcon"..i]
		idx = (offset*5) + i
		if idx<=#(ItemRackOpt.Icons) then
			texture = ItemRackOpt.Icons[idx]
			_G["ItemRackOptSetsIcon"..i.."Icon"]:SetTexture(texture)
			item:Show()
			if texture==ItemRackOpt.selectedIcon then
				item:LockHighlight()
			else
				item:UnlockHighlight()
			end
		else
			item:Hide()
		end

	end
end

function ItemRackOpt.SetsIconOnClick(self)
	local idx = self:GetID() + FauxScrollFrame_GetOffset(ItemRackOptSetsIconScrollFrame)*5
	ItemRackOpt.selectedIcon = ItemRackOpt.Icons[idx]
	ItemRackOptSetsCurrentSetIcon:SetTexture(ItemRackOpt.selectedIcon)
	ItemRackOpt.SetsIconScrollFrameUpdate()
end

function ItemRackOpt.SaveSet()
	ItemRackOptSetsName:ClearFocus()
	local setname = ItemRackOptSetsName:GetText()
	ItemRackUser.Sets[setname] = ItemRackUser.Sets[setname] or {}
	local set = ItemRackUser.Sets[setname]
	set.icon = ItemRackOpt.selectedIcon
	set.oldset = nil
	set.old = {}
	set.equip = {}
	for i=0,19 do
		if ItemRackOpt.Inv[i].selected then
			set.equip[i] = ItemRackOpt.Inv[i].id
		end
	end
	-- set.equip[0] = nil
	-- set.equip[18] = nil
	ItemRackOpt.ReconcileSetBindings()
	ItemRackOpt.ValidateSetButtons()
	ItemRack:FireItemRackEvent("ITEMRACK_SET_SAVED", setname)
end

function ItemRackOpt.ValidateSetButtons()
	ItemRackOptSetsSaveButton:Disable()
	ItemRackOptSetsBindButton:Disable()
	ItemRackOptSetsDeleteButton:Disable()
	ItemRackOptSetsHideCheckButton:Disable()
	ItemRackOptSetsHideCheckButtonText:SetTextColor(.5,.5,.5,1)
	ItemRackOptSetsHideCheckButton:SetChecked(false)
	local setname = ItemRackOptSetsName:GetText()
	if string.len(setname)>0 then
		for i=0,19 do
			if ItemRackOpt.Inv[i].selected then
				ItemRackOptSetsSaveButton:Enable()
				break
			end
		end
	end
	if ItemRackUser.Sets[setname] then
		ItemRackOptSetsDeleteButton:Enable()
		ItemRackOptSetsBindButton:Enable()
		ItemRackOptSetsHideCheckButton:Enable()
		ItemRackOptSetsHideCheckButtonText:SetTextColor(1,1,1,1)
		ItemRackOptSetsHideCheckButton:SetChecked(ItemRack.IsHidden(setname))
		ItemRackOptSetsCurrentSetIcon:SetTexture(ItemRackUser.Sets[setname].icon)
	end
end

function ItemRackOpt.LoadSet()
	ItemRackOptSetsName:ClearFocus()
	local setname = ItemRackOptSetsName:GetText()
	if ItemRackUser.Sets[setname] then
		local set = ItemRackUser.Sets[setname].equip
		for i=0,19 do
			ItemRackOpt.Inv[i].selected = nil
			if set[i] then
				ItemRackOpt.Inv[i].id = set[i]
				ItemRackOpt.Inv[i].selected = 1
			end
		end
		ItemRackOpt.selectedIcon = ItemRackUser.Sets[setname].icon
		ItemRackOpt.UpdateInv()
	end
end

function ItemRackOpt.DeleteSet()
	local setname = ItemRackOptSetsName:GetText()
	ItemRackUser.Sets[setname] = nil
	ItemRackOpt.PopulateSetList()
	ItemRack.CleanupEvents()
	ItemRackOpt.PopulateEventList()
	ItemRack:FireItemRackEvent("ITEMRACK_SET_DELETED", setname)
end

function ItemRackOpt.HideSet()
	local setname = ItemRackOptSetsName:GetText()
	if setname and ItemRackUser.Sets[setname] then
		if ItemRackOptSetsHideCheckButton:GetChecked() then
			ItemRack.AddHidden(setname)
		else
			ItemRack.RemoveHidden(setname)
		end
	end
end

function ItemRackOpt.MakeEscable(frame,add)
	local found
	for i in pairs(UISpecialFrames) do
		if UISpecialFrames[i]==frame then
			found = i
		end
	end
	if not found and add=="add" then
		table.insert(UISpecialFrames,frame)
	elseif found and add=="remove" then
		table.remove(UISpecialFrames,found)
	end
end

function ItemRackOpt.SaveInv()
	for i=0,19 do
		ItemRackOpt.HoldInv[i].id = ItemRackOpt.Inv[i].id
		ItemRackOpt.HoldInv[i].selected = ItemRackOpt.Inv[i].selected
	end
end

function ItemRackOpt.RestoreInv()
	for i=0,19 do
		ItemRackOpt.Inv[i].id = ItemRackOpt.HoldInv[i].id
		ItemRackOpt.Inv[i].selected = ItemRackOpt.HoldInv[i].selected
	end
	ItemRackOpt.UpdateInv()
end

-- when set chooser dropdown shown
function ItemRackOpt.PickSetOnShow()
  -- remove ItemRack_SetsFrame from UISpecialFrames and add ItemRack_Sets_SetSelect
	ItemRackOpt.MakeEscable("ItemRackOptSubFrame5","add")
	ItemRackOpt.MakeEscable("ItemRackOptFrame","remove")
	ItemRackOpt.HideCurrentSubFrame(5)
	ItemRackOpt.SaveInv()
	ItemRackOpt.PopulateSetList()
end

-- when set chooser dropdown hidden
function ItemRackOpt.PickSetOnHide()
	-- remove ItemRack_Sets_SetSelect from UISpecialFrames and add ItemRack_SetsFrame
	ItemRackOpt.MakeEscable("ItemRackOptSubFrame5","remove")
	ItemRackOpt.MakeEscable("ItemRackOptFrame","add")
	ItemRackOpt.ShowPrevSubFrame()

	if ItemRackOpt.EventSelected and ItemRackOpt.prevFrame==ItemRackOptSubFrame3 then
		local event = ItemRackOpt.EventList[ItemRackOpt.EventSelected][1]
		-- if going back to events frame and selected event is enabled with no set, unenable it
		if not ItemRackUser.Events.Set[event] then
			ItemRackUser.Events.Enabled[event] = nil
			ItemRackOpt.PopulateEventList()
--			ItemRack.Print("That event can't be enabled without choosing a set.")
		end
	end

	ItemRackOpt.RestoreInv()
end

function ItemRackOpt.SetListOnEnter(self)
	_G[self:GetName().."Highlight"]:Show()
	local set = ItemRackUser.Sets[ItemRackOpt.SetList[self:GetID()+FauxScrollFrame_GetOffset(ItemRackOptSetListScrollFrame)]].equip
	for i=0,19 do
		if set[i] then
			ItemRackOpt.Inv[i].id = set[i]
			ItemRackOpt.Inv[i].selected = 1
		else
			ItemRackOpt.Inv[i].id = ItemRackOpt.HoldInv[i].id
			ItemRackOpt.Inv[i].selected = nil
		end
	end
	ItemRackOpt.UpdateInv()
end

function ItemRackOpt.SetListScrollFrameUpdate()

	local item, texture, idx
	local offset = FauxScrollFrame_GetOffset(ItemRackOptSetListScrollFrame)

	FauxScrollFrame_Update(ItemRackOptSetListScrollFrame, #(ItemRackOpt.SetList), 10, 24)
	
	for i=1,10 do
		item = _G["ItemRackOptSetList"..i]
		idx = offset + i
		if idx<=#(ItemRackOpt.SetList) then
			_G["ItemRackOptSetList"..i.."Name"]:SetText(ItemRackOpt.SetList[idx])
			_G["ItemRackOptSetList"..i.."Icon"]:SetTexture(ItemRackUser.Sets[ItemRackOpt.SetList[idx]].icon)
			_G["ItemRackOptSetList"..i.."Key"]:SetText(ItemRackUser.Sets[ItemRackOpt.SetList[idx]].key)
			if ItemRack.IsHidden(ItemRackOpt.SetList[idx]) then
				_G["ItemRackOptSetList"..i.."Name"]:SetTextColor(.7,.7,.7,1)
			else
				_G["ItemRackOptSetList"..i.."Name"]:SetTextColor(1,1,1,1)
			end
			item:Show()
		else
			item:Hide()
		end

	end
end

function ItemRackOpt.PopulateSetList()
	for i in pairs(ItemRackOpt.SetList) do
		ItemRackOpt.SetList[i] = nil
	end
	for i in pairs(ItemRackUser.Sets) do
		if not string.match(i,"^~") then --do not list internal sets, prefixed with ~
			table.insert(ItemRackOpt.SetList,i)
		end
	end
	table.sort(ItemRackOpt.SetList)
	ItemRackOpt.SetListScrollFrameUpdate()
end

-- when a set is chosen in the set list
function ItemRackOpt.SelectSetList(self)
	local setname = ItemRackOpt.SetList[self:GetID()+FauxScrollFrame_GetOffset(ItemRackOptSetListScrollFrame)]
	for i=0,19 do
		ItemRackOpt.HoldInv[i].id = ItemRackOpt.Inv[i].id
		ItemRackOpt.HoldInv[i].selected = ItemRackOpt.Inv[i].selected
	end

	if ItemRackOpt.prevFrame==ItemRackOptSubFrame3 then
		-- fill out event info if picking an event's set
		local event = ItemRackOpt.EventList[ItemRackOpt.EventSelected][1]
		if not ItemRackUser.Events.Set[event] then
			ItemRackUser.Events.Enabled[event] = true
		end
		ItemRackUser.Events.Set[event] = setname
		ItemRackOpt.PopulateEventList()
	else
		-- fill out set build info if picking a set (ItemRackOptSubFrame2)
		ItemRackOpt.selectedIcon = ItemRackUser.Sets[setname].icon
		ItemRackOptSetsName:SetText(setname)
		if ItemRackSettings.EquipOnSetPick=="ON" then
			ItemRack.EquipSet(setname)
		end
	end

	ItemRackOptSubFrame5:Hide()
	ItemRackOpt.UpdateInv()
end	

--[[ Options list ]]

function ItemRackOpt.ListScrollFrameUpdate()
	local offset = FauxScrollFrame_GetOffset(ItemRackOptListScrollFrame)
	FauxScrollFrame_Update(ItemRackOptListScrollFrame, #(ItemRackOpt.OptInfo),11,24)

	for i=1,#(ItemRackOpt.OptInfo) do
		if ItemRackOpt.OptInfo[i].button then
			ItemRackOpt.OptInfo[i].button:SetFrameLevel(ItemRackOptList1:GetFrameLevel()+1)
			ItemRackOpt.OptInfo[i].button:Hide()
		end
	end

	local item,idx,opt,button,lock
	for i=1,11 do
		button = _G["ItemRackOptList"..i]
		_G["ItemRackOptList"..i.."Label"]:Hide()
		_G["ItemRackOptList"..i.."CheckText"]:Hide()
		_G["ItemRackOptList"..i.."CheckButton"]:Hide()
		_G["ItemRackOptList"..i.."NumberLabel"]:Hide()
		_G["ItemRackOptList"..i.."Underline"]:Hide()
		idx = offset+i
		if idx<=#(ItemRackOpt.OptInfo) then
			opt = ItemRackOpt.OptInfo[idx]
			lock = ItemRack.inCombat and opt.combatlock
			button:SetAlpha(lock and .5 or 1)
			if opt.type=="label" then
				item = _G["ItemRackOptList"..i.."Label"]
				item:SetText(opt.label)
				item:Show()
				if string.len(opt.label)>1 then
					_G["ItemRackOptList"..i.."Underline"]:Show()
				end
			elseif opt.type=="check" then
				item = _G["ItemRackOptList"..i.."CheckText"]
				item:SetWidth(opt.depend and 116 or 128)
				item:SetText(opt.label)
				if opt.depend and opt.optset[opt.depend]=="OFF" then
					item:SetTextColor(.5,.5,.5,1)
				else
					item:SetTextColor(1,1,1,1)
				end
				item:Show()
				item = _G["ItemRackOptList"..i.."CheckButton"]
				item:SetChecked(opt.optset[opt.variable]=="ON")
				if lock or (opt.depend and opt.optset[opt.depend]=="OFF") then
					item:Disable()
				else
					item:Enable()
				end
				item:Show()
			elseif opt.type=="number" then
				item = _G["ItemRackOptList"..i.."NumberLabel"]
				item:SetText(opt.label)
				if opt.depend and opt.optset[opt.depend]=="OFF" then
					item:SetTextColor(.5,.5,.5,1)
					opt.button:EnableMouse(false)
					opt.button:SetAlpha(.5)
				else
					item:SetTextColor(1,1,1,1)
					opt.button:EnableMouse(lock and false or true)
					opt.button:SetAlpha(lock and .5 or 1)
				end
				item:Show()
				opt.button:SetPoint("LEFT",item,"RIGHT",16,-1)
				opt.button:Show()
			elseif opt.type=="slider" then
				opt.button:SetPoint("LEFT",button,"LEFT",32,4)
				if opt.depend and opt.optset[opt.depend]=="OFF" then
					opt.button:EnableMouse(false)
					opt.button:SetAlpha(.5)
				else
					opt.button:EnableMouse(lock and false or true)
					opt.button:SetAlpha(lock and .5 or 1)
				end
				opt.button:Show()
			elseif opt.type=="button" then
				opt.button:SetPoint("LEFT",button,"LEFT",16,0)
				opt.button:EnableMouse(lock and false or true)
				opt.button:SetAlpha(lock and .5 or 1)
				opt.button:Show()
			end
			button:Show()
		else
			button:Hide()
		end
	end

end

function ItemRackOpt.SliderValueChanged(self)
	local name = string.match(self:GetName(),"ItemRackOpt(.+)Slider")
	if ItemRackUser[name] and ItemRackOpt.OptInfo then
		ItemRackUser[name] = self:GetValue()
		ItemRackOpt.UpdateSlider(name)
	end
end

function ItemRackOpt.UpdateSlider(name)
	if ItemRackOpt.OptInfo then
		local slider = _G["ItemRackOpt"..name.."Slider"]
		local value = ItemRackUser[name]
		local number = _G["ItemRackOpt"..name]
		if slider and value and number then
			number:SetText(string.format(slider.form or "%s",value))
			if name=="ButtonSpacing" then
				ItemRack.ConstructLayout()
			elseif name=="Alpha" then
				ItemRack.ReflectAlpha()
			elseif name=="MenuScale" then
				ItemRack.ReflectMenuScale()
			elseif name=="MainScale" then
				ItemRack.ReflectMainScale(1)
			end
		end
	end
end

function ItemRackOpt.NumberEditBoxOnEnter(self)
	self:ClearFocus()
	local name = string.match(self:GetName(),"ItemRackOpt(.+)")
	local newValue = tonumber(self:GetText())
	local slider = _G[self:GetName().."Slider"]
	if newValue and newValue>=slider.min and newValue<=slider.max then
		ItemRackUser[name] = newValue
		slider:SetValue(newValue)
	end
	ItemRackOpt.UpdateSlider(name)
end

function ItemRackOpt.NumberEditBoxOnEscape(self)
	self:ClearFocus()
	ItemRackOpt.UpdateSlider(string.match(self:GetName(),"ItemRackOpt(.+)"))
end

function ItemRackOpt.OptListCheckButtonOnClick(self,override)
	local button = override and override or self
	local check = button:GetChecked() and "ON" or "OFF"
	local idx = button:GetParent():GetID() + FauxScrollFrame_GetOffset(ItemRackOptListScrollFrame)
	local opt = ItemRackOpt.OptInfo[idx]
	if opt and opt.variable then
		opt.optset[opt.variable] = check
	end
	if opt.variable=="MenuOnRight" then
		ItemRack.ReflectMenuOnRight()
	elseif opt.variable=="HideOOC" then
		ItemRack.ReflectHideOOC()
	elseif opt.variable=="HidePetBattle" then
		ItemRack.ReflectHidePetBattle()
	elseif opt.variable=="CooldownCount" then
		for i in pairs(ItemRackUser.Buttons) do
			_G["ItemRackButton"..i.."Time"]:SetText("")
		end
		for i=1,#(ItemRack.Menu) do
			if _G["ItemRackMenu"..i] then
				_G["ItemRackMenu"..i.."Time"]:SetText("")
			end
		end
		ItemRack.WriteButtonCooldowns()
		ItemRack.WriteMenuCooldowns()
	elseif opt.variable=="LargeNumbers" then
		ItemRack.ReflectCooldownFont()
	elseif opt.variable=="ShowMinimap" or opt.variable=="SquareMinimap" then
		ItemRack.MoveMinimap()
	elseif opt.variable=="EnableQueues" then
		ItemRack.UpdateCombatQueue()
	elseif opt.variable=="ShowHotKeys" then
		ItemRack.KeyBindingsChanged()
	elseif opt.variable=="EnableEvents" then
		ItemRack.RegisterEvents()
	elseif opt.variable=="DisableAltClick" then
		ItemRack.UpdateDisableAltClick()
	end
	ItemRackOpt.ListScrollFrameUpdate()
end

function ItemRackOpt.OptListOnEnter(self,id)
	if id and type(id)=="number" then
		local idx = id + FauxScrollFrame_GetOffset(ItemRackOptListScrollFrame)
		if ItemRackOpt.OptInfo[idx].tooltip then
			ItemRack.OnTooltip(self,ItemRackOpt.OptInfo[idx].label,ItemRackOpt.OptInfo[idx].tooltip)
		end
	else
		for i=1,#(ItemRackOpt.OptInfo) do
			if ItemRackOpt.OptInfo[i].button==id then
				ItemRack.OnTooltip(self,ItemRackOpt.OptInfo[i].label,ItemRackOpt.OptInfo[i].tooltip)
				break
			end
		end
	end
end

function ItemRackOpt.OptListOnClick(self)
	local check = _G[self:GetName().."CheckButton"]
	if check and check:IsVisible() and check:IsEnabled()==true then
		check:SetChecked(not check:GetChecked())
		ItemRackOpt.OptListCheckButtonOnClick(self,check)
	end
end

--[[ Tabs ]]

function ItemRackOpt.TabOnClick(self,override)
	ItemRackOptBindFrame:Hide()
	for i=ItemRackOpt.numSubFrames,1,-1 do
		_G["ItemRackOptSubFrame"..i]:Hide()
	end
	local which = override or self:GetID()
	local tab,frame
	for i=1,4 do
		tab = _G["ItemRackOptTab"..i]
		if which==i then
			tab:Disable()
			tab:EnableMouse(false)
			_G["ItemRackOptSubFrame"..i]:Show()
		else
			tab:Enable()
			tab:EnableMouse(true)
		end
	end
end

--[[ Bindings frame ]]

-- hides currently shown subframes except one if passed (ie, ItemRackOpt.HideCurrentSubFrame(5) to hide all but set picker)
function ItemRackOpt.HideCurrentSubFrame(except)
	local frame,prev
	for i=ItemRackOpt.numSubFrames,1,-1 do
		if i~=except then
			frame = _G["ItemRackOptSubFrame"..i]
			if frame:IsVisible() then
				frame:Hide()
				prev = prev or frame
			end
		end
	end
	ItemRackOpt.prevFrame = prev
end

function ItemRackOpt.ShowPrevSubFrame()
	if ItemRackOpt.prevFrame then
		ItemRackOpt.prevFrame:Show()
	else
		ItemRackOptSubFrame1:Show()
	end
end

function ItemRackOpt.BindSet()
	local setname = ItemRackOptSetsName:GetText()
	ItemRackOpt.Binding = { type="Set", name="Set \""..setname.."\"", buttonName="ItemRack"..UnitName("player")..GetRealmName()..setname }
	ItemRackOpt.Binding.button = _G[buttonName] or CreateFrame("Button",ItemRackOpt.Binding.buttonName,nil,"SecureActionButtonTemplate")
	ItemRackOptBindFrame:Show()	
end

function ItemRackOpt.BindFrameOnShow()
	if not ItemRackOpt.Binding then return end
	ItemRackOpt.HideCurrentSubFrame()
	ItemRackOpt.Binding.currentKey=GetBindingKey("CLICK "..ItemRackOpt.Binding.buttonName..":LeftButton") or "Not bound"
	ItemRackOptBindFrameBindee:SetText(ItemRackOpt.Binding.name)
	ItemRackOptBindFrameCurrently:SetText("Currently: "..ItemRackOpt.Binding.currentKey)
end

function ItemRackOpt.BindFrameOnHide()
	ItemRackOpt.ShowPrevSubFrame()
	ItemRackOpt.ReconcileSetBindings()
	ItemRackOpt.Binding = nil
end

function ItemRackOpt.BindFrameOnKeyDown(self,key)
	if key=="ESCAPE" then
		self:Hide()
		return
	end
	local screenshotKey = GetBindingKey("SCREENSHOT");
	if ( screenshotKey and key == screenshotKey ) then
		Screenshot();
		return;
	end
	local button
	-- Convert the mouse button names
	if ( key == "LeftButton" ) then
		button = "BUTTON1"
	elseif ( key == "RightButton" ) then
		button = "BUTTON2"
	elseif ( key == "MiddleButton" ) then
		button = "BUTTON3"
	elseif ( key == "Button4" ) then
		button = "BUTTON4"
	elseif ( key == "Button5" ) then
		button = "BUTTON5"
	end
	local keyPressed
	if ( button ) then
		if ( button == "BUTTON1" or button == "BUTTON2" ) then
			return;
		end
		keyPressed = button;
	else
		keyPressed = key;
	end
	if keyPressed=="UNKNOWN" or keyPressed=="LSHIFT" or keyPressed=="RSHIFT" or keyPressed=="LCTRL" or keyPressed=="RCTRL" or keyPressed=="LALT" or keyPressed=="RALT" then
		return
	end
	if ( IsShiftKeyDown() ) then
		keyPressed = "SHIFT-"..keyPressed
	end
	if ( IsControlKeyDown() ) then
		keyPressed = "CTRL-"..keyPressed
	end
	if ( IsAltKeyDown() ) then
		keyPressed = "ALT-"..keyPressed
	end
	if keyPressed then
		ItemRackOpt.Binding.keyPressed = keyPressed
		local oldAction = GetBindingAction(keyPressed)
		if oldAction~="" and keyPressed~=ItemRackOpt.Binding.currentKey then
			StaticPopupDialogs["ItemRackCONFIRMBINDING"] = {
				text = NORMAL_FONT_COLOR_CODE..ItemRackOpt.Binding.keyPressed..FONT_COLOR_CODE_CLOSE.." is currently bound to "..NORMAL_FONT_COLOR_CODE..(GetBindingText(oldAction,"BINDING_NAME_") or "")..FONT_COLOR_CODE_CLOSE.."\n\nDo you want to bind "..NORMAL_FONT_COLOR_CODE..keyPressed..FONT_COLOR_CODE_CLOSE.." to "..NORMAL_FONT_COLOR_CODE..ItemRackOpt.Binding.name..FONT_COLOR_CODE_CLOSE.."?",
				button1 = "Yes",
				button2 = "No",
				timeout = 0,
				hideOnEscape = 1,
				OnAccept = ItemRackOpt.SetKeyBinding,
				OnCancel = ItemRackOpt.ResetBindFrame
			}
			ItemRackOptBindFrame:EnableKeyboard(false) -- turn off keyboard catching
			ItemRackOptBindFrame:EnableMouse(false) -- and mouse
			ItemRackOptBindCancel:Disable()
			ItemRackOptBindUnbind:Disable()
			StaticPopup_Show("ItemRackCONFIRMBINDING")
		else
			ItemRackOpt.SetKeyBinding()
		end
	end
end

function ItemRackOpt.SetKeyBinding()
	if not InCombatLockdown() and ItemRackOpt.Binding.keyPressed then
		ItemRackOpt.UnbindKey()
		SetBindingClick(ItemRackOpt.Binding.keyPressed,ItemRackOpt.Binding.buttonName)
	else
		ItemRack.Print("Sorry, you can't bind keys while in combat.")
	end
	ItemRackOpt.ResetBindFrame()
	ItemRackOptBindFrame:Hide()
end

function ItemRackOpt.ResetBindFrame()
	ItemRackOptBindFrame:EnableKeyboard(true)
	ItemRackOptBindFrame:EnableMouse(true)
	ItemRackOptBindCancel:Enable()
	ItemRackOptBindUnbind:Enable()
end

function ItemRackOpt.UnbindKey()
	if not InCombatLockdown() and ItemRackOpt.Binding.buttonName then
		local action = "CLICK "..ItemRackOpt.Binding.buttonName..":LeftButton"
		while GetBindingKey(action) do
			SetBinding(GetBindingKey(action))
		end
	end
	if ItemRackOpt.prevFrame==ItemRackOptSubFrame6 then
		ItemRackOpt.prevFrame = nil
	end
end

function ItemRackOpt.ReconcileSetBindings()
	local buttonName,key
	for i in pairs(ItemRackUser.Sets) do
		ItemRackUser.Sets[i].key = nil
		buttonName = "ItemRack"..UnitName("player")..GetRealmName()..i
		if _G[buttonName] then
			key = GetBindingKey("CLICK "..buttonName..":LeftButton")
			if key and key~="" then
				ItemRackUser.Sets[i].key = key
			end
		end
	end
	ItemRack.SetSetBindings()
end

--[[ Slot bindings ]]

function ItemRackOpt.SlotBindFrameOnShow()
	ItemRackOpt.MakeEscable("ItemRackOptSubFrame6","add")
	ItemRackOpt.MakeEscable("ItemRackOptFrame","remove")
	ItemRackOpt.HideCurrentSubFrame(6)
	ItemRackOpt.StartMarquee()
end

function ItemRackOpt.SlotBindFrameOnHide()
	ItemRackOpt.MakeEscable("ItemRackOptSubFrame6","remove")
	ItemRackOpt.MakeEscable("ItemRackOptFrame","add")
	ItemRackOpt.ShowPrevSubFrame()
	ItemRackOpt.StopMarquee()
end

function ItemRackOpt.StartMarquee()
	ItemRackOpt.SaveInv()
	for i=0,19 do
		ItemRackOpt.Inv[i].selected = nil
	end
	ItemRackOptToggleInvAll:Hide()
	ItemRackOpt.UpdateInv()
	ItemRack.StartTimer("SlotMarquee")
end

function ItemRackOpt.StopMarquee()
	ItemRack.StopTimer("SlotMarquee")
	_G["ItemRackOptInv"..ItemRackOpt.slotOrder[ItemRackOpt.currentMarquee+1]]:UnlockHighlight()
	ItemRackOpt.RestoreInv()
	ItemRackOptToggleInvAll:Show()
end

function ItemRackOpt.SlotMarquee()
	_G["ItemRackOptInv"..ItemRackOpt.slotOrder[ItemRackOpt.currentMarquee+1]]:UnlockHighlight()
	ItemRackOpt.currentMarquee = mod(ItemRackOpt.currentMarquee+1,#(ItemRackOpt.slotOrder))
	_G["ItemRackOptInv"..ItemRackOpt.slotOrder[ItemRackOpt.currentMarquee+1]]:LockHighlight()
end

function ItemRackOpt.BindSlot(slot)
	ItemRackOpt.Binding = { type="Slot", name=ItemRack.SlotInfo[slot].real, buttonName="ItemRackButton"..slot }
	ItemRackOpt.Binding.button = _G[buttonName]
	ItemRackOptBindFrame:Show()	
end

--[[ Auto queues ]]

function ItemRackOpt.QueuesFrameOnShow()
	ItemRackOpt.StartMarquee()
end

function ItemRackOpt.QueuesFrameOnHide()
	ItemRackOpt.StopMarquee()
end

function ItemRackOpt.SlotQueueFrameOnShow()
	ItemRackOpt.MakeEscable("ItemRackOptSubFrame7","add")
	ItemRackOpt.MakeEscable("ItemRackOptFrame","remove")
	ItemRackOpt.HideCurrentSubFrame(7)
	for i=0,19 do
		_G["ItemRackOptInv"..i]:Hide()
	end
	ItemRackOptToggleInvAll:Hide()
end

function ItemRackOpt.SlotQueueFrameOnHide()
	ItemRackOpt.MakeEscable("ItemRackOptSubFrame7","remove")
	ItemRackOpt.MakeEscable("ItemRackOptFrame","add")
	ItemRackOpt.ShowPrevSubFrame()
	for i=0,19 do
		_G["ItemRackOptInv"..i]:Show()
	end
	ItemRackOptToggleInvAll:Show()
end

function ItemRackOpt.SetupQueue(id)
	if not ItemRackUser.Queues[id] then
		ItemRackUser.Queues[id] = {}
	end
	ItemRackOpt.SelectedSlot = id
	ItemRackOpt.SortSelected = nil
	ItemRackOptSlotQueueName:SetText(ItemRack.SlotInfo[id].real)
	ItemRackOpt.PopulateSortList(id)
	ItemRackOpt.ValidateSortButtons()
	ItemRackOptSubFrame7:Show()
end

function ItemRackOpt.PopulateSortList(slot)
	local sortList = ItemRackUser.Queues[slot]
	ItemRack.DockWindows("TOPLEFT",ItemRackOptInv1,"TOPRIGHT")
	ItemRack.BuildMenu(slot,1) -- make a dummy menu to fetch all wearable items for that slot
	ItemRackMenuFrame:Hide()
	for i=1,#(ItemRack.Menu) do
		ItemRackOpt.AddToSortList(sortList,ItemRack.Menu[i]) -- insert new items from menu (in bags/inventory)
	end
	ItemRackOptSortListScrollFrameScrollBar:SetValue(0)
	ItemRackOpt.SortListScrollFrameUpdate()
end

function ItemRackOpt.AddToSortList(sortList,id)
	local found
	for i=1,#(sortList) do
		found = found or sortList[i]==id
	end
	if not found then
		table.insert(sortList,id)
	end
end

function ItemRackOpt.SortListScrollFrameUpdate()

	local item, name, texture, quality, idx
	local slot = ItemRackOpt.SelectedSlot
	local sortList = slot and ItemRackUser.Queues[slot]
	local offset = FauxScrollFrame_GetOffset(ItemRackOptSortListScrollFrame)

	FauxScrollFrame_Update(ItemRackOptSortListScrollFrame, sortList and #(sortList) or 0, 11, 24)
	
	for i=1,11 do
		item = _G["ItemRackOptSortList"..i]
		idx = offset + i
		if sortList and idx<=#(sortList) then
			if sortList[idx]==0 then
				name,texture,quality = "-- stop queue here --","Interface\\Buttons\\UI-GroupLoot-Pass-Up",1
			else
				name,texture,_,quality = ItemRack.GetInfoByID(sortList[idx])
			end
			_G["ItemRackOptSortList"..i.."Name"]:SetText(name)
			_G["ItemRackOptSortList"..i.."Icon"]:SetTexture(texture)
			_G["ItemRackOptSortList"..i.."Name"]:SetTextColor(GetItemQualityColor(quality or 1))
			item:Show()
			if idx==ItemRackOpt.SortSelected then
				ItemRackOpt.LockHighlight(item)
			else
				ItemRackOpt.UnlockHighlight(item)
			end
		else
			item:Hide()
		end

	end
end

function ItemRackOpt.LockHighlight(frame)
	if type(frame)=="string" then frame = _G[frame] end
	if not frame then return end
	frame.lockedHighlight = true
	_G[frame:GetName().."Highlight"]:Show()
end

function ItemRackOpt.UnlockHighlight(frame)
	if type(frame)=="string" then frame = _G[frame] end
	if not frame then return end
	frame.lockedHighlight = false
	_G[frame:GetName().."Highlight"]:Hide()
end

function ItemRackOpt.SortListOnClick(self)
	local idx = FauxScrollFrame_GetOffset(ItemRackOptSortListScrollFrame) + self:GetID()
	if ItemRackOpt.SortSelected == idx then
		ItemRackOpt.SortSelected = nil
	else
		ItemRackOpt.SortSelected = idx
	end
	ItemRackOpt.SortListScrollFrameUpdate()
	ItemRackOpt.ValidateSortButtons()
end

function ItemRackOpt.ValidateSortButtons()
	local selected = ItemRackOpt.SortSelected
	local list = ItemRackUser.Queues[ItemRackOpt.SelectedSlot]
	ItemRackOptSortMoveTop:Enable()
	ItemRackOptSortMoveUp:Enable()
	ItemRackOptSortMoveDown:Enable()
	ItemRackOptSortMoveBottom:Enable()
	if not selected or #(list)<2 then -- none selected, disable all
		ItemRackOptSortMoveTop:Disable()
		ItemRackOptSortMoveUp:Disable()
		ItemRackOptSortMoveDown:Disable()
		ItemRackOptSortMoveBottom:Disable()
	elseif selected==1 then
		ItemRackOptSortMoveTop:Disable()
		ItemRackOptSortMoveUp:Disable()
	elseif selected == #(list) then
		ItemRackOptSortMoveDown:Disable()
		ItemRackOptSortMoveBottom:Disable()
	end
	local idx = FauxScrollFrame_GetOffset(ItemRackOptSortListScrollFrame)
	if selected and list[selected] and list[selected]~=0 then
		ItemRackOptSortMoveDelete:Enable()
		-- display delay/priority/etc
		ItemRackOptItemStatsFrame:Show()
		ItemRackOptSlotQueueName:Hide()
		ItemRackOptQueueEnable:Hide()
		local baseID = ItemRack.GetIRString(list[selected],true)
		ItemRackOptItemStatsPriority:SetChecked(ItemRackItems[baseID] and ItemRackItems[baseID].priority or false)
		ItemRackOptItemStatsKeepEquipped:SetChecked(ItemRackItems[baseID] and ItemRackItems[baseID].keep or false)
		ItemRackOptItemStatsDelay:SetText((ItemRackItems[baseID] and ItemRackItems[baseID].delay) or "0")
	else
		ItemRackOptSortMoveDelete:Disable()
		ItemRackOptItemStatsFrame:Hide()
		ItemRackOptSlotQueueName:Show()
		ItemRackOptQueueEnable:Show()
	end
	if not IsShiftKeyDown() and selected then -- keep selected visible on list, moving thumb as needed, unless shift is down
		local parent = ItemRackOptSortListScrollFrameScrollBar
		local offset
		if selected <= idx then
			offset = (selected==1) and 0 or (parent:GetValue() - (parent:GetHeight() / 2))
			parent:SetValue(offset)
			PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
		elseif selected >= (idx+12) then
			offset = (selected==#(list)) and ItemRackOptSortListScrollFrame:GetVerticalScrollRange() or (parent:GetValue() + (parent:GetHeight() / 2))
			parent:SetValue(offset)
			PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON);
		end
	end
	ItemRackOptQueueEnable:SetChecked(ItemRackUser.QueuesEnabled[ItemRackOpt.SelectedSlot])
end

function ItemRackOpt.SortMove(self)
	local dir = ((self==ItemRackOptSortMoveUp) and -1) or ((self==ItemRackOptSortMoveTop) and "top") or ((self==ItemRackOptSortMoveDown) and 1) or ((self==ItemRackOptSortMoveBottom) and "bottom")
	local list = ItemRackUser.Queues[ItemRackOpt.SelectedSlot]
	local idx1 = ItemRackOpt.SortSelected
	if dir then
		local idx2 = ((dir=="top") and 1) or ((dir=="bottom") and #(list)) or idx1+dir
		local temp = list[idx1]
		if tonumber(dir) then
			list[idx1] = list[idx2]
			list[idx2] = temp
		elseif dir=="top" then
			table.remove(list,idx1)
			table.insert(list,1,temp)
		elseif dir=="bottom" then
			table.remove(list,idx1)
			table.insert(list,temp)
		end
		ItemRackOpt.SortSelected = idx2
	elseif self==ItemRackOptSortMoveDelete then
		table.remove(list,idx1)
		ItemRackOpt.SortSelected = nil
	end
	ItemRackOpt.ValidateSortButtons()
	ItemRackOpt.SortListScrollFrameUpdate()
end

function ItemRackOpt.SortListOnEnter(self)
	_G[self:GetName().."Highlight"]:Show()
	local idx = FauxScrollFrame_GetOffset(ItemRackOptSortListScrollFrame) + self:GetID()
	local list = ItemRackUser.Queues[ItemRackOpt.SelectedSlot]
	if list[idx] then
		if list[idx]==0 then
			ItemRack.OnTooltip(self,"Stop Queue Here","Move this to mark an explicit end to an order. ie, if you have a clickable trinket with a passive effect, and would like to use the passive effect if no better trinkets are off cooldown.")
		else
			ItemRack.IDTooltip(self,list[idx])
		end
	end
end

function ItemRackOpt.SortListOnLeave(self)
	GameTooltip:Hide()
	if not self.lockedHighlight then
		_G[self:GetName().."Highlight"]:Hide()
	end
end

-- if an ItemRackItems has no non-default values, remove the entry
function ItemRackOpt.ItemStatsCleanup(id)
	if ItemRackItems[id] then
		local item = ItemRackItems[id]
		if not item.delay and not item.priority and not item.keep then
			ItemRackItems[id] = nil
		end
	end
end

function ItemRackOpt.ItemStatsDelayOnTextChanged(self)
	local baseID = ItemRack.GetIRString(ItemRackUser.Queues[ItemRackOpt.SelectedSlot][ItemRackOpt.SortSelected],true)
	local value = tonumber(self:GetText() or "") or 0
	if value~=0 then
		if not ItemRackItems[baseID] then
			ItemRackItems[baseID] = {}
		end
		ItemRackItems[baseID].delay = value
	else
		if ItemRackItems[baseID] then
			ItemRackItems[baseID].delay = nil
		end
		ItemRackOpt.ItemStatsCleanup(baseID)
	end
end

function ItemRackOpt.ItemStatsCheckOnClick(self)
	local baseID = ItemRack.GetIRString(ItemRackUser.Queues[ItemRackOpt.SelectedSlot][ItemRackOpt.SortSelected],true)
	local value = self:GetChecked()
	local which = self==ItemRackOptItemStatsPriority and "priority" or "keep"
	if value then
		if not ItemRackItems[baseID] then
			ItemRackItems[baseID] = {}
		end
		ItemRackItems[baseID][which] = 1
	else
		if ItemRackItems[baseID] then
			ItemRackItems[baseID][which] = nil
		end
		ItemRackOpt.ItemStatsCleanup(baseID)
	end
end

function ItemRackOpt.QueueEnableSlotOnClick(self)
	ItemRackUser.QueuesEnabled[ItemRackOpt.SelectedSlot] = self:GetChecked()
	ItemRack.UpdateCombatQueue()
end

--[[ Events ]]

ItemRackOpt.EventList = {}

function ItemRackOpt.PopulateEventList()
	local list = ItemRackOpt.EventList
	local events = ItemRackEvents
	local user = ItemRackUser.Events

	-- if an event is selected, save it as oldevent
	local oldevent = ItemRackOpt.EventSelected and list[ItemRackOpt.EventSelected][1] or nil
	ItemRackOpt.EventSelected = nil

	local safeToRegister = 1 -- assume it's safe to register events

	for i in pairs(list) do
		list[i] = nil
	end
	local setname
	for i in pairs(events) do
		if user.Set[i] then
			setname = user.Set[i]
		elseif events[i].Type=="Script" and user.Enabled[i] then
			setname = "zzz" -- give it a fake set name for sorting purposes
		else
			setname = nil
		end
		if user.Enabled[i] and not setname then
			safeToRegister = nil
		end
		table.insert(list,{i,events[i].Type,user.Enabled[i],setname})
	end

	local function sortbyset(e1,e2)
		if e1 and e2 and e1[4] and not e2[4] then
			return true -- sort by set defined
		elseif e1 and e2 and e1[4] and e2[4] and e1[1]<e2[1] then
			return true -- sort set-defined by alpha
		elseif e1 and e2 and not e1[4] and not e2[4] and e1[1]<e2[1] then
			return true -- sort set-undefined by alpha
		else
			return false
		end
	end
	table.sort(ItemRackOpt.EventList,sortbyset)

	-- find oldevent if it existed
	if oldevent then
		for i=1,#(list) do
			if list[i][1]==oldevent then
				ItemRackOpt.EventSelected = i
				break
			end
		end
	end
	ItemRackOpt.EventListScrollFrameUpdate()
	ItemRackOpt.ValidateEventListButtons()

	if safeToRegister then
		ItemRack.RegisterEvents()
	end
end

function ItemRackOpt.EventListScrollFrameUpdate()

	local item, icon, texture, idx
	local offset = FauxScrollFrame_GetOffset(ItemRackOptEventListScrollFrame)
	local list = ItemRackOpt.EventList

	FauxScrollFrame_Update(ItemRackOptEventListScrollFrame, #(list), 9, 24)

	for i=1,9 do
		item = _G["ItemRackOptEventList"..i]
		idx = offset + i
		if idx<=#(list) then
			_G["ItemRackOptEventList"..i.."Name"]:SetText(list[idx][1])
			icon = _G["ItemRackOptEventList"..i.."Icon"]
			if list[idx][2]=="Script" then
				texture = "Interface\\AddOns\\ItemRackOptions\\ItemRackScriptIcon"
			elseif ItemRackUser.Events.Set[list[idx][1]] then
				texture = ItemRackUser.Sets[ItemRackUser.Events.Set[list[idx][1]]].icon
			else
				texture = "Interface\\Icons\\INV_Misc_QuestionMark"
			end
			icon:SetNormalTexture(texture)
			icon:SetPushedTexture(texture)
			_G["ItemRackOptEventList"..i.."Enabled"]:SetChecked(ItemRackUser.Events.Enabled[list[idx][1]])
			if idx==ItemRackOpt.EventSelected then
				ItemRackOpt.LockHighlight(item)
			else
				ItemRackOpt.UnlockHighlight(item)
			end
			item:Show()
		else
			item:Hide()
		end
	end
end

function ItemRackOpt.EventListOnClick(self)
	local idx = FauxScrollFrame_GetOffset(ItemRackOptEventListScrollFrame) + self:GetID()
	if ItemRackOpt.EventSelected == idx then
		ItemRackOpt.EventSelected = nil
	else
		ItemRackOpt.EventSelected = idx
	end
	ItemRackOpt.EventListScrollFrameUpdate()
	ItemRackOpt.ValidateEventListButtons()
end

function ItemRackOpt.EventListOnDoubleClick(self)
	ItemRackOpt.EventSelected = nil
	ItemRackOpt.EventListOnClick(self)
	ItemRackOptSubFrame8:Show()
end

function ItemRackOpt.EventListOnEnter(self,child)
	local idx = FauxScrollFrame_GetOffset(ItemRackOptEventListScrollFrame) + (child and self:GetParent():GetID() or self:GetID())
	local eventName = ItemRackOpt.EventList[idx][1]
	local eventType = ItemRackOpt.EventList[idx][2]
	local event = ItemRackEvents[eventName]
	local desc = "|cFFBBBBBBEquips a set when "
	if eventType=="Buff" then
		if event.Anymount then
			desc = desc.."riding any mount."
		else
			desc = desc.."gaining the buff "..event.Buff
		end
	elseif eventType=="Stance" then
		if event.Stance == 0 then
			desc = desc.."leaving forms."
		else
			desc = desc.."entering stance:"..event.Stance.."."
		end
	elseif eventType=="Zone" then
		desc = desc.."entering one of the following zones:"
		for i in pairs(event.Zones) do
			desc = desc.."\n"..i
		end
	else
		desc = "|cFFBBBBBBScript event triggered on "..event.Trigger
		local comment = string.match(event.Script,"--%[%[(.+)%]%]")
		if comment then
			desc = desc.."\n"..comment
		end
	end
	if event.NotInPVP then
		desc = desc.."\n|cFF888888Except in PVP instances."
	end
	if event.Unequip then
		desc = desc.."\n|cFF888888Unequips when condition ends."
	end
	ItemRack.OnTooltip(self,eventName,desc)	
	_G[(child and self:GetParent():GetName() or self:GetName()).."Highlight"]:Show()
end

function ItemRackOpt.EventListOnLeave(self,child)
	GameTooltip:Hide()
	if child and not self:GetParent().lockedHighlight then
		_G[self:GetParent():GetName().."Highlight"]:Hide()
	elseif not child and not self.lockedHighlight then
		_G[self:GetName().."Highlight"]:Hide()
	end
end

function ItemRackOpt.ValidateEventListButtons()
	if ItemRackOpt.EventSelected then
		ItemRackOptEventEdit:Enable()
		ItemRackOptEventDelete:Enable()
	else
		ItemRackOptEventEdit:Disable()
		ItemRackOptEventDelete:Disable()
	end
end

function ItemRackOpt.EventListIconOnClick(self)
	local idx = FauxScrollFrame_GetOffset(ItemRackOptEventListScrollFrame) + self:GetParent():GetID()
	ItemRackOpt.EventSelected = idx
	ItemRackOpt.EventListScrollFrameUpdate()
	ItemRackOpt.ValidateEventListButtons()
	if ItemRackOpt.EventList[ItemRackOpt.EventSelected][2]~="Script" then
		ItemRackOptSubFrame5:Show() -- Buff, Stance or Zone event, go pick a set
	else
		ItemRackOptSubFrame8:Show() -- Script event, go straight to editing it
	end
end

function ItemRackOpt.EventListEnabledOnClick(self)
	local idx = FauxScrollFrame_GetOffset(ItemRackOptEventListScrollFrame) + self:GetParent():GetID()
	ItemRackOpt.EventSelected = idx
	local checked = self:GetChecked()
	ItemRackUser.Events.Enabled[ItemRackOpt.EventList[idx][1]] = checked
	if checked then
		ItemRackUser.EnableEvents = "ON"
		ItemRack.ReflectEventsRunning()
	end
	if checked and ItemRackOpt.EventList[idx][2]~="Script" and not ItemRackUser.Events.Set[ItemRackOpt.EventList[idx][1]] then
		-- if an event without a set is being checked, choose a set
		ItemRackOpt.EventListIconOnClick(self)
	end
	if not checked then
		ItemRackOpt.EventSelected = nil
		ItemRackUser.Events.Enabled[ItemRackOpt.EventList[idx][1]] = nil
	end
	ItemRackOpt.PopulateEventList()
end

function ItemRackOpt.EventEditOnShow()
	ItemRackOpt.MakeEscable("ItemRackOptSubFrame8","add")
	ItemRackOpt.MakeEscable("ItemRackOptFrame","remove")
	ItemRackOpt.HideCurrentSubFrame(8)
	ItemRackOpt.EventEditPopulateFrame()
end

function ItemRackOpt.EventEditOnHide()
	ItemRackFloatingEditor:Hide()
	ItemRackOpt.MakeEscable("ItemRackOptSubFrame8","remove")
	ItemRackOpt.MakeEscable("ItemRackOptFrame","add")
	ItemRackOptEventEditPickTypeFrame:Hide()
	ItemRackOpt.ShowPrevSubFrame()
end

function ItemRackOpt.EventEditClearFrame()
	ItemRackOptEventEditNameEdit:SetText("")
	ItemRackOptEventEditTypeDropText:SetText("Pick one")
	ItemRackOptEventEditBuffName:SetText("")
	ItemRackOptEventEditBuffAnyMount:SetChecked(false)
	ItemRackOptEventEditBuffUnequip:SetChecked(false)
	ItemRackOptEventEditBuffNotInPVP:SetChecked(false)
	ItemRackOptEventEditStanceName:SetText("")
	ItemRackOptEventEditStanceUnequip:SetChecked(false)
	ItemRackOptEventEditStanceNotInPVP:SetChecked(false)
	ItemRackOptEventEditZoneEditBox:SetText("")
	ItemRackOptEventEditZoneUnequip:SetChecked(false)
	ItemRackOptEventEditScriptTrigger:SetText("")
	ItemRackOptEventEditScriptEditBox:SetText("")
end

function ItemRackOpt.EventEditPopulateFrame()
	local idx = ItemRackOpt.EventSelected
	local eventName = idx and ItemRackOpt.EventList[idx][1] or ""
	local event = ItemRackEvents[eventName]
	ItemRackOpt.EventEditClearFrame()
	if idx and event then
		ItemRackOptEventEditNameEdit:SetText(eventName)
		ItemRackOptEventEditNameEdit:SetCursorPosition(0)
		ItemRackOptEventEditTypeDropText:SetText(event.Type)
		ItemRackOptEventEditBuffName:SetText(event.Buff or "")
		ItemRackOptEventEditBuffName:SetCursorPosition(0)
		if event.Anymount then
			ItemRackOptEventEditBuffAnyMount:SetChecked(true)
			ItemRackOptEventEditBuffName:SetText("Any mount")
		end
		ItemRackOptEventEditBuffUnequip:SetChecked(event.Unequip)
		ItemRackOptEventEditBuffNotInPVP:SetChecked(event.NotInPVP)
		ItemRackOptEventEditStanceName:SetText(event.Stance or "")
		ItemRackOptEventEditStanceUnequip:SetChecked(event.Unequip)
		ItemRackOptEventEditStanceNotInPVP:SetChecked(event.NotInPVP)
		ItemRackOptEventEditZoneEditBox:SetText(ItemRackOpt.ConvertZoneTableToList(event.Zones))
		ItemRackOptEventEditZoneEditBox:SetCursorPosition(0)
		ItemRackOptEventEditZoneUnequip:SetChecked(event.Unequip)
		ItemRackOptEventEditScriptTrigger:SetText(event.Trigger or "")
		ItemRackOptEventEditScriptTrigger:SetCursorPosition(0)
		ItemRackOptEventEditScriptEditBox:SetText(event.Script or "")
		ItemRackOptEventEditScriptEditBox:SetCursorPosition(0)
	else
		ItemRackOptEventEditNameEdit:SetFocus()
	end
	ItemRackOpt.EventEditAnyMountChanged()
	ItemRackOpt.EventEditDisplayType()
end

function ItemRackOpt.EventEditDisplayType()
	local eventType = ItemRackOptEventEditTypeDropText:GetText() or ""
	ItemRackOptEventEditBuffFrame:Hide()
	ItemRackOptEventEditStanceFrame:Hide()
	ItemRackOptEventEditZoneFrame:Hide()
	ItemRackOptEventEditScriptFrame:Hide()
	local eventFrame = _G["ItemRackOptEventEdit"..eventType.."Frame"]
	if eventFrame then
		eventFrame:Show()
	end
	ItemRackOpt.EventEditValidateButtons()
end

function ItemRackOpt.ConvertZoneTableToList(t)
	local list = ""
	if t then
		for i in pairs(t) do
			list = list..i.."\n"
		end
	end
	return list
end
function ItemRackOpt.ConvertZoneListToTable(list,t)
	list=list.."\n"
	for line in string.gmatch(list,"(.-)\n") do
		if strlen(line)>0 then
			t[line] = 1
		end
	end
end

function ItemRackOpt.EventEditTypeDropDownOnClick()
	local pickFrame = ItemRackOptEventEditPickTypeFrame
	if pickFrame:IsVisible() then
		ItemRackOptEventEditPickTypeFrame:Hide()
	else
		ItemRackOptEventEditPickTypeFrame:Show()
	end
end

function ItemRackOpt.EventEditPickTypeOnClick(self)
	ItemRackOptEventEditPickTypeFrame:Hide()
	ItemRackOptEventEditTypeDropText:SetText(self:GetText())
	ItemRackOpt.EventEditDisplayType()
end

function ItemRackOpt.EventEditAnyMountChanged()
	local item = ItemRackOptEventEditBuffName
	if ItemRackOptEventEditBuffAnyMount:GetChecked() then
		item:EnableMouse(false)
		item:SetTextColor(.5,.5,.5)
		item:ClearFocus()
	else
		item:EnableMouse(true)
		item:SetTextColor(1,1,1)
	end
	ItemRackOpt.EventEditValidateButtons()
end

function ItemRackOpt.EventEditValidateButtons()
	local safe = 1 -- default to assume event edit form is filled out ok
	local test
	if strlen(ItemRackOptEventEditNameEdit:GetText())<1 then
		safe = nil
	end
	test = ItemRackOptEventEditTypeDropText:GetText()
	if test~="Buff" and test~="Stance" and test~="Zone" and test~="Script" then
		safe = nil
	end
	local eventType = ItemRackOptEventEditTypeDropText:GetText()
	if eventType=="Buff" then
		if ItemRackOptEventEditBuffAnyMount:GetChecked() then
			safe = 1
		else
			test = ItemRackOptEventEditBuffName:GetText()
			if test=="Any mount" or strlen(test)<1 then
				safe = nil
			end
		end
	elseif eventType=="Stance" then
		if strlen(ItemRackOptEventEditStanceName:GetText())<1 then
			safe = nil
		end
	elseif eventType=="Zone" then
		if strlen(ItemRackOptEventEditZoneEditBox:GetText())<1 then
			safe = nil
		end
	elseif eventType=="Script" then
		test = ItemRackFloatingEditor:IsVisible() and ItemRackFloatingEditorEditBox:GetText() or ItemRackOptEventEditScriptEditBox:GetText()
		if strlen(ItemRackOptEventEditScriptTrigger:GetText())<1 then
			safe = nil
		elseif strlen(test)<1 then
			safe = nil
		end
	end
	if safe then
		ItemRackOptEventEditSave:Enable()
	else
		ItemRackOptEventEditSave:Disable()
	end
	return safe
end

function ItemRackOpt.EventEditSave(override)
	if ItemRackFloatingEditor:IsVisible() then
		ItemRackFloatingEditor:Hide()
	end
	local eventNameEdit = ItemRackOptEventEditNameEdit
	eventNameEdit:SetFocus() -- grab focus from whatever had it
	eventNameEdit:ClearFocus() -- and clear it (so ESC works with static popups)
	local eventName = eventNameEdit:GetText()
	if not override then -- if override is set, this was run via a static popup
		local oldName = ItemRackOpt.EventSelected and ItemRackOpt.EventList[ItemRackOpt.EventSelected][1] or ""
		if (not ItemRackOpt.EventSelected and ItemRackEvents[eventName]) or (ItemRackEvents[eventName] and oldName~=eventName) then
			StaticPopupDialogs["ItemRackConfirmEventOverwrite"] = {
				text = "An event with that name already exists.\nDo you want to overwrite it?",
				button1 = "Yes", button2 = "No", timeout = 0, hideOnEscape = 1, whileDead = 1,
				OnAccept = function() StaticPopupDialogs["ItemRackConfirmEventOverwrite"].OnCancel() ItemRackOpt.EventEditSave(1) end,
				OnCancel = function() ItemRackOptEventEditSave:Enable() ItemRackOptEventEditCancel:Enable() end
			}
			ItemRackOptEventEditSave:Disable()
			ItemRackOptEventEditCancel:Disable()
			StaticPopup_Show("ItemRackConfirmEventOverwrite")
			return
		end
	end
	ItemRackEvents[eventName] = {}
	local event=ItemRackEvents[eventName]
	event.Type = ItemRackOptEventEditTypeDropText:GetText()
	if event.Type=="Buff" then
		event.Anymount = ItemRackOptEventEditBuffAnyMount:GetChecked()
		event.Buff = ItemRackOptEventEditBuffName:GetText()
		event.Unequip = ItemRackOptEventEditBuffUnequip:GetChecked()
		event.NotInPVP = ItemRackOptEventEditBuffNotInPVP:GetChecked()
	elseif event.Type=="Stance" then
		event.Stance = ItemRackOptEventEditStanceName:GetText()
		if tonumber(event.Stance) then
			event.Stance = tonumber(event.Stance)
		end
		event.Unequip = ItemRackOptEventEditStanceUnequip:GetChecked()
		event.NotInPVP = ItemRackOptEventEditStanceNotInPVP:GetChecked()
	elseif event.Type=="Zone" then
		event.Unequip = ItemRackOptEventEditZoneUnequip:GetChecked()
		event.Zones = {}
		ItemRackOpt.ConvertZoneListToTable(ItemRackOptEventEditZoneEditBox:GetText(),event.Zones)
	elseif event.Type=="Script" then
		event.Trigger = ItemRackOptEventEditScriptTrigger:GetText()
		event.Script = ItemRackOptEventEditScriptEditBox:GetText()
		ItemRackUser.Events.Enabled[eventName] = true
		ItemRackUser.EnableEvents = "ON"
		ItemRack.ReflectEventsRunning()
	end
	ItemRack.Print("Event \""..eventName.."\" saved.")
	ItemRackOptSubFrame8:Hide()     
	ItemRackOpt.PopulateEventList()
	-- select this new event in the event list
	for i=1,#(ItemRackOpt.EventList) do
		if ItemRackOpt.EventList[i][1]==eventName then
			ItemRackOpt.EventSelected = i
			break
		end
	end
	ItemRackOpt.EventListScrollFrameUpdate()
	ItemRackOpt.ValidateEventListButtons()
end

function ItemRackOpt.EventEditDelete(override)
	local eventName = ItemRackOpt.EventList[ItemRackOpt.EventSelected][1]
	if ItemRackUser.Events.Set[eventName] or ItemRackUser.Events.Enabled[eventName] then
		ItemRackUser.Events.Set[eventName] = nil
		ItemRackUser.Events.Enabled[eventName] = nil
		ItemRackOpt.EventSelected = nil
		ItemRackOpt.PopulateEventList()
		return
	end
	if not override then
		StaticPopupDialogs["ItemRackConfirmEventDelete"] = {
			text = "Are you sure you want to delete the event \""..eventName.."\"?",
			button1 = "Yes", button2 = "No", timeout = 0, hideOnEscape = 1, whileDead = 1,
			OnAccept = function() StaticPopupDialogs["ItemRackConfirmEventDelete"].OnCancel() ItemRackOpt.EventEditDelete(1) end,
			OnCancel = function() ItemRackOptEventNew:Enable() ItemRackOpt.ValidateEventListButtons() end
		}
		ItemRackOptEventEdit:Disable()
		ItemRackOptEventDelete:Disable()
		ItemRackOptEventNew:Disable()
		StaticPopup_Show("ItemRackConfirmEventDelete")
		return
	end
	ItemRackEvents[eventName] = nil
	ItemRackOpt.EventSelected = nil
	ItemRack.CleanupEvents()
	ItemRackOpt.PopulateEventList()
	ItemRack.Print("Event \""..eventName.."\" deleted.")
end

function ItemRackOpt.ToggleEventEditor()
	if not ItemRackFloatingEditor:IsVisible() then
		ItemRackFloatingEditorEditBox:SetWidth(ItemRackFloatingEditor:GetWidth()-50)
		ItemRackFloatingEditorEditBox:SetText(ItemRackOptEventEditScriptEditBox:GetText())
		ItemRackOpt.MakeEscable("ItemRackFloatingEditor","add")
		ItemRackOpt.MakeEscable("ItemRackOptSubFrame8","remove")
		ItemRackOptEventEditScriptEditBox:HighlightText()
		ItemRackOptEventEditScriptEditLabel:Hide()
		ItemRackOptEventEditScriptEditBackdrop:Hide()
		ItemRackOptEventEditScriptEditScrollFrame:Hide()
		ItemRackFloatingEditor:Show()
	else
		ItemRackFloatingEditor:Hide()
	end
end

function ItemRackOpt.FloatingEditorOnHide()
	ItemRackOpt.MakeEscable("ItemRackFloatingEditor","remove")
	if ItemRackOptEventEditScriptFrame:IsVisible() then
		ItemRackOpt.MakeEscable("ItemRackOptSubFrame8","add")
	end
	ItemRackOptEventEditScriptEditBox:SetText(ItemRackFloatingEditorEditBox:GetText())
	ItemRackOptEventEditScriptEditLabel:Show()
	ItemRackOptEventEditScriptEditBackdrop:Show()
	ItemRackOptEventEditScriptEditScrollFrame:Show()
end

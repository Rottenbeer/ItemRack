--[[ Default event definitions

	Events can be one of four types:
		Buff : Triggered by PLAYER_AURAS_CHANGED and delayed .3 sec
		Zone : Triggered by ZONE_CHANGED_NEW_AREA and delayed .5 sec
		Stance : Triggered by UPDATE_SHAPESHIFT_FORM and not delayed
		Script : User-defined trigger

		Buff and Stance share an attribute : 
		  NotInPVP : nil or 1, whether to ignore this event if pvp flag is set

		Buff, Zone and Stance share an attribute :
		  Unequip : nil or 1, whether to unequip the set when condition ends

		Buff has a special case attribute:
		  Anymount: nil or 1, whether the buff is any mount (IsPlayerMounted())
		 
		Zone has a table:
		  Zones : Indexed by name of zone, lookup table for zones to define this event

		Script has its own attributes:
		  Trigger : Event (ie "UNIT_AURA") that triggers the script
		  Script : Actual script run through RunScript
		
	The set to equip is defined in ItemRackUser.Events.Set, indexed by event name
	The set to equip is nil if it's a Script event.  Sets equip/unequip explicitly
	Whether an event is enabled is in ItemRackuser.Events.Enabled, indexed by event name
]]

-- increment this value when default events are changed to deploy them to existing events
ItemRack.EventsVersion = 15

-- default events, loaded when no events exist or ItemRack.EventsVersion is increased
ItemRack.DefaultEvents = {
	["PVP"] = {
		Type = "Zone",
		Unequip = 1,  
		Zones = {
			["Alterac Valley"] = 1,
			["Arathi Basin"] = 1,
			["Warsong Gulch"] = 1,
			["Eye of the Storm"] = 1,
			["Ruins of Lordaeron"] = 1,
			["Blade's Edge Arena"] = 1,
			["Nagrand Arena"] = 1,
		}
	},
	["City"] = {
		Type = "Zone",
		Unequip = 1,
		Zones = {
			["Ironforge"] = 1,
			["Stormwind City"] = 1,
			["Darnassus"] = 1,
			["The Exodar"] = 1,
			["Orgrimmar"] = 1,
			["Thunder Bluff"] = 1,
			["Silvermoon City"] = 1,
			["Undercity"] = 1,
			["Shattrath City"] = 1,
			["Dalaran"] = 1,
		}
	},
	["Mounted"] = { Type = "Buff", Unequip = 1, Anymount = 1 },
	["Drinking"] = { Type = "Buff", Unequip = 1, Buff = "Drink" },
	["Evocation"] = { Type = "Buff", Unequip = 1, Buff = "Evocation" },

	["Warrior Battle"] = { Type = "Stance", Stance = 1 },
	["Warrior Defensive"] = { Type = "Stance", Stance = 2 },
	["Warrior Berserker"] = { Type = "Stance", Stance = 3 },

	["Priest Shadowform"] = { Type = "Stance", Unequip = 1, Stance = 1 },

	["Druid Humanoid"] = { Type = "Stance", Stance = 0 },
	["Druid Bear"] = { Type = "Stance", Stance = 1 },
	["Druid Aquatic"] = { Type = "Stance", Stance = 2 },
	["Druid Cat"] = { Type = "Stance", Stance = 3 },
	["Druid Travel"] = { Type = "Stance", Stance = 4 },
	["Druid Moonkin"] = { Type = "Stance", Stance = "Moonkin Form" },

	["Rogue Stealth"] = { Type = "Stance", Unequip = 1, Stance = 1 },

	["Shaman Ghostwolf"] = { Type = "Stance", Unequip = 1, Stance = 1 },

	["Swimming"] = {
		["Trigger"] = "MIRROR_TIMER_START",
		["Type"] = "Script",
		["Script"] = "local set = \"Name of set\"\nif IsSwimming() and not IsSetEquipped(set) then\n  EquipSet(set)\n  if not SwimmingEvent then\n    function SwimmingEvent()\n      if not IsSwimming() then\n        ItemRack.StopTimer(\"SwimmingEvent\")\n        UnequipSet(set)\n      end\n    end\n    ItemRack.CreateTimer(\"SwimmingEvent\",SwimmingEvent,.5,1)\n  end\n  ItemRack.StartTimer(\"SwimmingEvent\")\nend\n--[[Equips a set when swimming and breath gauge appears and unequips soon after you stop swimming.]]",
	},

	["Buffs Gained"] = {
		Type = "Script",
		Trigger = "UNIT_AURA",
		Script = "if arg1==\"player\" then\n  IRScriptBuffs = IRScriptBuffs or {}\n  local buffs = IRScriptBuffs\n  for i in pairs(buffs) do\n    if not AuraUtil.FindAuraByName(i,\"player\") then\n      buffs[i] = nil\n    end\n  end\n  local i,b = 1,1\n  while b do\n    b = AuraUtil.FindAuraByName(i,\"player\")\n    if b and not buffs[b] then\n      ItemRack.Print(\"Gained buff: \"..b)\n      buffs[b] = 1\n    end\n    i = i+1\n  end\nend\n--[[For script demonstration purposes. Doesn't equip anything just informs when a buff is gained.]]",
	},

	["After Cast"] = {
		Type = "Script",
		Trigger = "UNIT_SPELLCAST_SUCCEEDED",
		Script = "local spell = \"Name of spell\"\nlocal set = \"Name of set\"\nif arg1==\"player\" and arg2==spell then\n  EquipSet(set)\nend\n\n--[[This event will equip \"Name of set\" when \"Name of spell\" has finished casting.  Change the names for your own use.]]",
	},
}

-- resetDefault to reload/update default events, resetAll to wipe all events and recreate them
function ItemRack.LoadEvents(resetDefault,resetAll)

	local version = tonumber(ItemRackSettings.EventsVersion) or 0
	if ItemRack.EventsVersion > version then
		resetDefault = 1 -- force a load of default events (leaving custom ones intact)
		ItemRackSettings.EventsVersion = ItemRack.EventsVersion
	end

	if not ItemRackUser.Events or resetAll then
		ItemRackUser.Events = {
			Enabled = {}, -- indexed by name of event, whether an event is enabled
			Set = {} -- indexed by name of event, the set defined for the event, if any
		}
	end

	if not ItemRackEvents or resetAll then
		ItemRackEvents = {}
	end

	if resetDefault or resetAll then
		for i in pairs(ItemRack.DefaultEvents) do
			ItemRack.CopyDefaultEvent(i)
		end
	end

	ItemRack.CleanupEvents()
	if ItemRackOpt then
		ItemRackOpt.PopulateEventList() -- if options loaded, recreate event list there
	end
end

function ItemRack.CopyDefaultEvent(eventName)
	ItemRackEvents[eventName] = {}
	local event = ItemRackEvents[eventName]
	local default = ItemRack.DefaultEvents[eventName]

	for i in pairs(default) do
		if type(default[i])~="table" then
			event[i] = default[i]
		else
			-- recursive scares me :P /chicken
			-- this copies a sub-table. if events ever go one more table deep, do a recursive copy
			event[i] = {}
			for j in pairs(default[i]) do
				event[i][j] = default[i][j]
			end
		end
	end
end

-- clear sets of deleted events, clear events with deleted sets
function ItemRack.CleanupEvents()
	local event = ItemRackUser.Events

	-- go through ItemRackUser.Events.Set for deleted events or sets
	for i in pairs(event.Set) do
		if not ItemRackEvents[i] then
			-- this event no longer exists, remove it
			event.Set[i] = nil
			event.Enabled[i] = nil
		end
		if not ItemRackUser.Sets[event.Set[i]] then
			-- this set no longer exists, remove it
			event.Set[i] = nil
			event.Enabled[i] = nil
		end
	end

	-- go through ItemRackUser.Events.Enabled for deleted events
	for i in pairs(event.Enabled) do
		if not ItemRackEvents[i] then
			-- this event no longer exists, remove it
			event.Set[i] = nil
			event.Enabled[i] = nil
		end
		if event.Enabled[i] == false then
			-- this was disabled but not removed
			event.Enabled[i] = nil
		end
	end
end

function ItemRack.ResetEvents(resetDefault,resetAll)
	if not resetDefault and not resetAll then
		StaticPopupDialogs["ItemRackConfirmResetEvents"] = {
			text = "Do you want to restore just Default events, or wipe All events and restore to default?",
			button1 = "Default", button2 = "Cancel", button3 = "All", timeout = 0, hideOnEscape = 1, whileDead = 1,
			OnAccept = function() ItemRack.ResetEvents(1) end,
			OnAlt = function() ItemRack.ResetEvents(1,1) end,
		}
		StaticPopup_Show("ItemRackConfirmResetEvents")
	else
		ItemRack.LoadEvents(resetDefault,resetAll)
	end
end

function ItemRack.InitEvents()
	ItemRack.LoadEvents()

	ItemRack.CreateTimer("EventsBuffTimer",ItemRack.ProcessBuffEvent,.50)
	ItemRack.CreateTimer("EventsZoneTimer",ItemRack.ProcessZoneEvent,.33)

	if ItemRackButton20Queue then
		ItemRackButton20Queue:SetTexture("Interface\\AddOns\\ItemRack\\ItemRackGear")
	else
		print("ItemRackButton20Queue doesn't exist?")
	end

	ItemRack.RegisterEvents()
end

function ItemRack.RegisterEvents()
	local frame = ItemRackEventProcessingFrame
	frame:UnregisterAllEvents()
	ItemRack.ReflectEventsRunning()
	if ItemRackUser.EnableEvents=="OFF" then
		return
	end
	local enabled = ItemRackUser.Events.Enabled
	local events = ItemRackEvents
	local eventType
	for eventName in pairs(enabled) do
		eventType = events[eventName].Type
		if eventType=="Buff" then
			if not frame:IsEventRegistered("UNIT_AURA") then
				frame:RegisterEvent("UNIT_AURA")
			end
		elseif eventType=="Stance" then
			if not frame:IsEventRegistered("UPDATE_SHAPESHIFT_FORM") then
				frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
			end
		elseif eventType=="Zone" then
			if not frame:IsEventRegistered("ZONE_CHANGED_NEW_AREA") then
				frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
			end
		elseif eventType=="Script" then
			if not frame:IsEventRegistered(events[eventName].Trigger) then
				frame:RegisterEvent(events[eventName].Trigger)
			end
		end
	end
	ItemRack.ProcessStanceEvent()
	ItemRack.ProcessZoneEvent()
	ItemRack.ProcessBuffEvent()
end

function ItemRack.ToggleEvents(self)
	ItemRackUser.EnableEvents = ItemRackUser.EnableEvents=="ON" and "OFF" or "ON"
	if not next(ItemRackUser.Events.Enabled) then
		-- user is turning on events with no events enabled, go to events frame
		LoadAddOn("ItemRackOptions")
		ItemRackOptFrame:Show()
		ItemRackOpt.TabOnClick(self,3)
	else
		if ItemRackOptFrame and ItemRackOptFrame:IsVisible() then
			ItemRackOpt.ListScrollFrameUpdate()
		end
	end
	ItemRack.RegisterEvents()
end

--[[ Event processing ]]

function ItemRack.ProcessingFrameOnEvent(self,event,...)
	local enabled = ItemRackUser.Events.Enabled
	local events = ItemRackEvents
	local startBuff, startZone, startStance, eventType
	local arg1,arg2 = ...;

	for eventName in pairs(enabled) do
		eventType = events[eventName].Type
		if event=="UNIT_AURA" and eventType=="Buff" and arg1=="player" then
			startBuff = 1
		elseif event=="UPDATE_SHAPESHIFT_FORM" and eventType=="Stance" then
			startStance = 1
		elseif event=="ZONE_CHANGED_NEW_AREA" and eventType=="Zone" then
			startZone = 1
		elseif eventType=="Script" and events[eventName].Trigger==event then
			RunScript(events[eventName].Script)
		end
	end
	if startStance then
		ItemRack.ProcessStanceEvent()
	end
	if startBuff then
		ItemRack.StartTimer("EventsBuffTimer")
	end
	if startZone then
		ItemRack.StartTimer("EventsZoneTimer")
	end
end

function ItemRack.GetStanceNumber(name)
	if tonumber(name) then
		return name
	end
	for i=1,GetNumShapeshiftForms() do
		if name==select(2,GetShapeshiftFormInfo(i)) then
			return i
		end
	end
end

function ItemRack.ProcessStanceEvent()
	local enabled = ItemRackUser.Events.Enabled
	local events = ItemRackEvents

	local currentStance = GetShapeshiftForm()
	local stance, setToEquip, setToUnequip, setname, skip

	for eventName in pairs(enabled) do
		if events[eventName].Type=="Stance" then
			skip = nil
			if events[eventName].NotInPVP then
				local _,instanceType = IsInInstance()
				if instanceType=="arena" or instanceType=="pvp" then
					skip = 1
				end
			end
			if not skip then
				stance = ItemRack.GetStanceNumber(events[eventName].Stance)
				setname = ItemRackUser.Events.Set[eventName]
				if stance==currentStance and not ItemRack.IsSetEquipped(setname) then
					-- if this event is for this stance, then we'll want to equip this one
					setToEquip = ItemRackUser.Events.Set[eventName]
				end
				if stance~=currentStance and events[eventName].Unequip and ItemRack.IsSetEquipped(setname) then
					-- if this event is for last stance, then we'll want to unequip it
					setToUnequip = ItemRackUser.Events.Set[eventName]
				end
			end
		end
	end
	if setToUnequip then
		ItemRack.UnequipSet(setToUnequip)
	end
	if setToEquip then
		ItemRack.EquipSet(setToEquip)
	end
end

function ItemRack.ProcessZoneEvent()
	local enabled = ItemRackUser.Events.Enabled
	local events = ItemRackEvents

	local currentZone = GetRealZoneText()
	local setToEquip, setToUnequip, setname

	for eventName in pairs(enabled) do
		if events[eventName].Type=="Zone" then
			setname = ItemRackUser.Events.Set[eventName]
			if events[eventName].Zones[currentZone] and not ItemRack.IsSetEquipped(setname) then
				setToEquip = setname
			elseif not events[eventName].Zones[currentZone] and events[eventName].Unequip and ItemRack.IsSetEquipped(setname) then
				setToUnequip = setname
			end
		end
	end
	if setToUnequip then
		ItemRack.UnequipSet(setToUnequip)
	end
	if setToEquip then
		ItemRack.EquipSet(setToEquip)
	end
end

function ItemRack.ProcessBuffEvent()
	local enabled = ItemRackUser.Events.Enabled
	local events = ItemRackEvents

	local buff, setname, isSetEquipped, skip

	for eventName in pairs(enabled) do
		if events[eventName].Type=="Buff" then
			skip = nil
			if events[eventName].NotInPVP then
				local _,instanceType = IsInInstance()
				if instanceType=="arena" or instanceType=="pvp" then
					skip = 1
				end
			end
			if not skip then
				if events[eventName].Anymount then
					buff = IsMounted() and not UnitOnTaxi("player")
				else
					buff = AuraUtil.FindAuraByName(events[eventName].Buff,"player")
				end
				setname = ItemRackUser.Events.Set[eventName]
				isSetEquipped = ItemRack.IsSetEquipped(setname)
				if buff and not isSetEquipped then
					ItemRack.EquipSet(setname)
				elseif not buff and isSetEquipped then
					ItemRack.UnequipSet(setname)
				end
			end
		end
	end
end

function ItemRack.ReflectEventsRunning()
	if ItemRackUser.EnableEvents=="ON" and next(ItemRackUser.Events.Enabled) then
		-- if events enabled and an event is enabled, show gear icons on set and minimap button
		if ItemRackUser.Buttons[20] then
			ItemRackButton20Queue:Show()
		end
		ItemRackMinimapGear:Show()
	else
		if ItemRackUser.Buttons[20] then
			ItemRackButton20Queue:Hide()
		end
		ItemRackMinimapGear:Hide()
	end
end

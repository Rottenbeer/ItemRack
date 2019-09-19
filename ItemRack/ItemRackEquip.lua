-- ItemRackEquip.lua : ItemRack.EquipSet and its supporting functions.

ItemRack.SwapList = {} -- table of item ids that want to swap in, indexed by slot
ItemRack.AbortSwap = nil -- reasons: 1=not enough room, 2=item on cursor, 3=in spell targeting mode, 4=item lock
ItemRack.AbortReasons = {"Not enough room.","Something is on the cursor.","In spell targeting mode.","Another swap is in progress."}

ItemRack.SetsWaiting = {} -- numerically indexed table of {"setname",func} ie {"pvp",ItemRack.EquipSet}

-- Legion artifact items that act as two items
ItemRack.PhantomItem = {
	[128293] = true, -- Blades of the Fallen Prince (frost death knight)
	[127830] = true, -- Twinblades of the Deceiver (havoc demon hunter)
	[128831] = true, -- Aldrachi Warblades (vengeance demon hunter)
	[128859] = true, -- Fangs of Ashamane (feral druid)
	[128822] = true, -- Claws of Ursoc (guardian druid)
	[133959] = true, -- Heart of the Phoenix (fire mage)
	[133948] = true, -- Fists of the Heavens (windwalker monk)
	[128867] = true, -- Oathseeker (prot pally)
	[133958] = true, -- Secrets of the Void (shadow priest)
	[128869] = true, -- The Kingslayers (assassin rogue)
	[134552] = true, -- The Dreadblades (outlaw rogue)
	[128479] = true, -- Fangs of the Devourer (subtlety rogue)
	[128936] = true, -- The Highkeeper's Ward (ele shaman)
	[128873] = true, -- Fury of the Stonemother (enh shaman)
	[128934] = true, -- Shield of the Sea Queen (resto shaman)
	[128943] = true, -- Skull of the Man'ari (demo lock)
	[134553] = true, -- Warswords of the Valarjar (fury warrior)
	[128289] = true, -- Scale of the Earth-Warder (prot warrior)
}

function ItemRack.ProcessSetsWaiting()
	local setwaiting = ItemRack.SetsWaiting[1][1]
	local whichequip = ItemRack.SetsWaiting[1][2]
	table.remove(ItemRack.SetsWaiting,1)
	whichequip(setwaiting)
end

function ItemRack.AddSetToSetsWaiting(setwaiting,whichequip)
	local wait = ItemRack.SetsWaiting
	for i in pairs(wait) do
		if wait[i][1]==setwaiting and wait[i][2]==whichequip then
			return
		end
	end
	table.insert(wait,{setwaiting,whichequip})
end

function ItemRack.EquipSet(setname)
	if not setname or not ItemRackUser.Sets[setname] then
		ItemRack.Print("Set \""..tostring(setname).."\" doesn't exist.")
		return
	end
	if ItemRack.NowCasting or ItemRack.AnythingLocked() then
		-- a swap is in progress, add this set to the wait list and leave
		ItemRack.AddSetToSetsWaiting(setname,ItemRack.EquipSet)
		return
	end
	local set = ItemRackUser.Sets[setname]
	local swap = ItemRack.SwapList
	for i in pairs(swap) do
		swap[i] = nil
	end
	local inv,bag,slot
	local couldntFind
	for i in pairs(set.equip) do
		if ItemRack.GetID(i)~=set.equip[i] then -- if intended item is not worn (exact match)
			inv,bag,slot = ItemRack.FindItem(set.equip[i])
			if not inv and not bag then
				-- if not found at all, then start/add to list of items not found
				couldntFind = couldntFind or "Could not find: "
				couldntFind = couldntFind.."["..tostring(ItemRack.GetInfoByID(set.equip[i])).."] "
			elseif inv~=i then -- and finding intended item doesn't point to worn
				swap[i] = set.equip[i] -- then note this item for a swap
			end
		end
	end
	ItemRack.Print(couldntFind) -- if couldntFind is nil then nothing will print

	-- at this point, ItemRack.SwapList has only what needs to be swapped, indexed by slot
	if not next(swap) then
--		ItemRack.Print("Set already equipped.")
		ItemRack.EndSetSwap(setname) -- end swap if set already equipped
		return
	end
	
	if set.old then
		for i in pairs(set.old) do
			set.old[i] = nil -- wipe old items
		end
		set.oldset = ItemRackUser.CurrentSet
	end

	-- if in combat or dead, combat queue items wanting to equip and only let swappables through
	if UnitAffectingCombat("player") or ItemRack.IsPlayerReallyDead() then
		for i in pairs(swap) do
			ItemRack.AddToCombatQueue(i,swap[i])
			-- print("Combat queue "..ItemRack.GetInfoByID(swap[i]))
			swap[i] = nil
			if set.old then
				set.old[i] = ItemRack.GetID(i)
				ItemRack.CombatSet = setname
			elseif set.oldset then
				ItemRack.CombatSet = set.oldset
			end
		end
	end
	if not next(swap) then
		return
	end

	ItemRack.IterateSwapList(setname) -- run SwapList swaps
	if not next(swap) then
		ItemRack.EndSetSwap(setname)
		return -- leave if swap completed on first pass
	end

	-- a second pass is needed. ItemRack.SwapList (swap) has the list of remaining items to swap.
	-- With ItemRack.SetSwapping defined, ITEM_LOCK_CHANGED will call LockChangedDuringSetSwap()
	-- to determine when to run a second pass.
	ItemRack.SetSwapping = setname
end

function ItemRack.AnythingLocked()
	local isLocked = nil
	for i=1,19 do
		if IsInventoryItemLocked(i) then
			return 1
		end
	end
	if not isLocked then
		for i=0,4 do
			for j=1,GetContainerNumSlots(i) do
				if select(3,GetContainerItemInfo(i,j)) then
					return 1
				end
			end
		end
	end
end

function ItemRack.LockChangedDuringSetSwap()
	if not ItemRack.AnythingLocked() then
		local setname = ItemRack.SetSwapping
		ItemRack.SetSwapping = nil
		ItemRack.IterateSwapList(setname)
		ItemRack.EndSetSwap(setname)
	end
end

function ItemRack.IterateSwapList(setname)
 
	local set = ItemRackUser.Sets[setname]
	local swap = ItemRack.SwapList

	ItemRack.AbortSwap = nil
	ItemRack.ClearLockList()
	
	local skip = nil
	for i=0,19 do -- go in order to handle skips correctly
		if skip or ItemRack.AbortSwap then
			skip = nil
		elseif swap[i] then
			if swap[i]==0 then -- if intended to be empty
				bag,slot = ItemRack.FindSpace()
				if bag then
					if set.old then
						set.old[i] = ItemRack.GetID(i)
					end
					ItemRack.MoveItem(i,nil,bag,slot) -- empty slot
					swap[i] = nil
				else
					ItemRack.AbortSwap = 1
					return
				end
			else
				inv,bag,slot = ItemRack.FindItem(swap[i],1)
				if bag then
					if select(3,ItemRack.GetInfoByID(swap[i]))=="INVTYPE_2HWEAPON" then
						-- this is a 2H weapon. swap both slots at once if offhand equipped
						if set.old then
							set.old[i] = ItemRack.GetID(i)
							set.old[i+1] = ItemRack.GetID(i+1)
						end
						if GetInventoryItemLink("player",17) then
							local freeBag,freeSlot = ItemRack.FindSpace()
							if freeBag then
								ItemRack.MoveItem(17,nil,freeBag,freeSlot)
							else
								ItemRack.AbortSwap=1
							end
						end
						ItemRack.MoveItem(bag,slot,16,nil)
						swap[16] = nil
						swap[17] = nil -- fix by Romracer
						skip = 1
					else
						if set.old then
							set.old[i] = ItemRack.GetID(i)
						end
						ItemRack.MoveItem(bag,slot,i,nil)
						swap[i] = nil
					end
				elseif inv==(i+1) and ItemRack.SameID(swap[i+1],ItemRack.GetID(i)) then
					-- item is in other slot and other slot wants to go to this one
					if set.old then
						set.old[i] = ItemRack.GetID(i)
						set.old[i+1] = ItemRack.GetID(i+1)
					end
					ItemRack.MoveItem(i,nil,i+1,nil)
					swap[i] = nil
					swap[i+1] = nil
					skip = 1
				end
			end
		end
	end
	if ItemRack.AbortSwap then
		ItemRack.Print("Swap stopped. "..(ItemRack.AbortReasons[ItemRack.AbortSwap] or ""))
	end
end

function ItemRack.EndSetSwap(setname)
	ItemRack.SetSwapping = nil
	if setname then
		if not string.match(setname,"^~") then --do not list internal sets, prefixed with ~
			ItemRackUser.CurrentSet = setname
			ItemRack.UpdateCurrentSet()
		elseif ItemRackUser.Sets[setname].oldset then
			-- if this is a special set that stored a setname, set current to that setname
			ItemRackUser.CurrentSet = ItemRackUser.Sets[setname].oldset
			ItemRackUser.Sets[setname].oldset = nil
			ItemRack.UpdateCurrentSet()
		end
		if ItemRackOptFrame and ItemRackOptFrame:IsVisible() then
			ItemRackOpt.ChangeEditingSet()
		end
	end
--	ItemRack.Print("End of set swap. CurrentSet: "..tostring(ItemRackUser.CurrentSet))
end

-- moves an item from bag,slot to bag,slot (slot is nil for bag=inv)
function ItemRack.MoveItem(fromBag,fromSlot,toBag,toSlot)
	local abort
	if CursorHasItem() then
		abort = 2
	elseif SpellIsTargeting() then
		abort = 3
	elseif not fromSlot and ItemRack.PhantomItem[GetInventoryItemID("player",fromBag) or 1] then
		return  -- oscarucb: ignore swap requests on slots containing "phantom" artifact items
	elseif (not fromSlot and IsInventoryItemLocked(fromBag)) or (not toSlot and IsInventoryItemLocked(toBag)) then
		abort = 4
	elseif (fromSlot and select(3,GetContainerItemInfo(fromBag,fromSlot))) or (toSlot and select(3,GetContainerItemInfo(toBag,toSlot))) then
		abort = 4
	end
	if abort then
		ItemRack.AbortSwap = abort
		return
	else
		if fromSlot then
			PickupContainerItem(fromBag,fromSlot)
		else
			PickupInventoryItem(fromBag)
		end
		if toSlot then
			PickupContainerItem(toBag,toSlot)
		else
			PickupInventoryItem(toBag)
		end
	end
end

function ItemRack.IsSetEquipped(setname,exact)
	if setname and ItemRackUser.Sets[setname] then
		local set = ItemRackUser.Sets[setname].equip
		local id
		for i in pairs(set) do
			id = ItemRack.GetID(i)
			if (exact and set[i]~=id) or (not exact and not ItemRack.SameID(set[i],ItemRack.GetID(i))) then
				return false
			end
		end
		return true
	end
end

function ItemRack.UnequipSet(setname)
	if setname and ItemRackUser.Sets[setname] and ItemRackUser.Sets[setname].old then
		if ItemRack.AnythingLocked() then
			ItemRack.AddSetToSetsWaiting(setname,ItemRack.UnequipSet)
			return
		end
		local old = ItemRackUser.Sets[setname].old
		local unequip = ItemRackUser.Sets["~Unequip"].equip
		for i in pairs(unequip) do
			unequip[i] = nil
		end
		for i in pairs(old) do
			unequip[i] = old[i]
			-- old[i] = nil
		end
		ItemRackUser.Sets["~Unequip"].oldset = ItemRackUser.Sets[setname].oldset
		ItemRack.EquipSet("~Unequip")
	end
end

function ItemRack.ToggleSet(setname,exact)
	if ItemRack.IsSetEquipped(setname,exact) then
--		print("remove "..setname)
		ItemRack.UnequipSet(setname)
	else
--		print("equip "..setname)
		ItemRack.EquipSet(setname)
	end
end

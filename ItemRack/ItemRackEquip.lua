-- ItemRackEquip.lua : ItemRack.EquipSet and its supporting functions.
local GetContainerNumSlots, GetContainerItemLink, GetContainerItemCooldown, GetContainerItemInfo, GetItemCooldown, PickupContainerItem, ContainerIDToInventoryID
if C_Container then
	GetContainerNumSlots = C_Container.GetContainerNumSlots
	GetContainerItemLink = C_Container.GetContainerItemLink
	GetContainerItemCooldown = C_Container.GetContainerItemCooldown
	GetItemCooldown = C_Container.GetItemCooldown
	PickupContainerItem = C_Container.PickupContainerItem
	ContainerIDToInventoryID = C_Container.ContainerIDToInventoryID
	GetContainerItemInfo = function(bag, slot)
		local info = C_Container.GetContainerItemInfo(bag, slot)
		if info then
			return info.iconFileID, info.stackCount, info.isLocked, info.quality, info.isReadable, info.hasLoot, info.hyperlink, info.isFiltered, info.hasNoValue, info.itemID, info.isBound
		else
			return
		end
	end
else
	GetContainerNumSlots, GetContainerItemLink, GetContainerItemCooldown, GetContainerItemInfo, GetItemCooldown, PickupContainerItem, ContainerIDToInventoryID =
	_G.GetContainerNumSlots, _G.GetContainerItemLink, _G.GetContainerItemCooldown, _G.GetContainerItemInfo, _G.GetItemCooldown, _G.PickupContainerItem, _G.ContainerIDToInventoryID
end

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

ItemRack.UniqueGems = {
	-- Wrath JC gems
	[36766] = 3, --bright-dragons-eye
	[36767] = 3, --solid-dragons-eye
	[42142] = 3, --bold-dragons-eye
	[42143] = 3, --delicate-dragons-eye
	[42144] = 3, --runed-dragons-eye
	[42145] = 3, --sparkling-dragons-eye
	[42146] = 3, --lustrous-dragons-eye
	[42148] = 3, --brilliant-dragons-eye
	[42149] = 3, --smooth-dragons-eye
	[42150] = 3, --quick-dragons-eye
	[42151] = 3, --subtle-dragons-eye
	[42152] = 3, --flashing-dragons-eye
	[42153] = 3, --fractured-dragons-eye
	[42154] = 3, --precise-dragons-eye
	[42155] = 3, --stormy-dragons-eye
	[42156] = 3, --rigid-dragons-eye
	[42157] = 3, --thick-dragons-eye
	[42158] = 3, --mystic-dragons-eye
	[49110] = 3, --nightmare-tear
	-- Other
	[27679] = 1, --sublime-mystic-dawnstone
	[27777] = 1, --stark-blood-garnet
	[27785] = 1, --notched-deep-peridot
	[27786] = 1, --barbed-deep-peridot
	[27809] = 1, --barbed-deep-peridot
	[27812] = 1, --stark-blood-garnet
	[27820] = 1, --notched-deep-peridot
	[28360] = 1, --mighty-blood-garnet
	[28361] = 1, --mighty-blood-garnet
	[28556] = 1, --swift-windfire-diamond
	[28557] = 1, --swift-starfire-diamond
	[30571] = 1, --don-rodrigos-heart
	[30598] = 1, --don-amancios-heart
	[32634] = 1, --unstable-amethyst
	[32635] = 1, --unstable-peridot
	[32636] = 1, --unstable-sapphire
	[32637] = 1, --unstable-citrine
	[32638] = 1, --unstable-topaz
	[32639] = 1, --unstable-talasite
	[32735] = 1, --radiant-spencerite
	[33131] = 1, --crimson-sun
	[33132] = 1, --delicate-fire-ruby
	[33133] = 1, --don-julios-heart
	[33134] = 1, --kailees-rose
	[33135] = 1, --falling-star
	[33137] = 1, --sparkling-falling-star
	[33138] = 1, --mystic-bladestone
	[33139] = 1, --brilliant-bladestone
	[33140] = 1, --blood-of-amber
	[33141] = 1, --great-bladestone
	[33142] = 1, --rigid-bladestone
	[33143] = 1, --stone-of-blades
	[33144] = 1, --facet-of-eternity
	[34256] = 1, --charmed-amani-jewel
	[34831] = 1, --eye-of-the-sea
	[42701] = 1, --enchanted-pearl
	[42702] = 1, --enchanted-tear
	[44066] = 1, --kharmaas-grace
	--[41492] = 1, --perfect-inscribed-citrine DEBUG
}
ItemRack.eqBackOfTheBusOffset = 100

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

function ItemRack.OrderSwaps(swap)
	for k,v in pairs(swap) do
		if swap[k] and swap[k] ~= 0 then
			local itemID, enchantID, gem1, gem2, gem3 = ItemRack.GetEnhancements(swap[k])
			if (ItemRack.UniqueGems[gem1] or ItemRack.UniqueGems[gem2] or ItemRack.UniqueGems[gem3])
			and k < ItemRack.eqBackOfTheBusOffset then
				swap[k+ItemRack.eqBackOfTheBusOffset] = v
				swap[k] = nil
			end
		end
	end
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

	if ItemRackUser.Sets[setname].ShowHelm ~= nil then
		if ItemRackUser.Sets[setname].ShowHelm == 1 then
			ShowHelm(true)
		else
			ShowHelm(false)
		end
	end
	
	if ItemRackUser.Sets[setname].ShowCloak ~= nil then
		if ItemRackUser.Sets[setname].ShowCloak == 1 then
			ShowCloak(true)
		else
			ShowCloak(false)
		end
	end

	ItemRack.OrderSwaps(swap) -- bump items with unique gems to the end of the line

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

	local treatAs2H = nil
	local skip, inv, bag, slot
	for k=0,19+ItemRack.eqBackOfTheBusOffset do
		local i = k
		if k >= ItemRack.eqBackOfTheBusOffset then
			i = k-ItemRack.eqBackOfTheBusOffset
		end
		if skip or ItemRack.AbortSwap then
			skip = nil
		elseif swap[k] then
			if swap[k]==0 then -- if intended to be empty
				bag,slot = ItemRack.FindSpace()
				if bag then
					if set.old then
						set.old[i] = ItemRack.GetID(i)
					end
					ItemRack.MoveItem(i,nil,bag,slot) -- empty slot
					swap[k] = nil
				else
					ItemRack.AbortSwap = 1
					return
				end
			else
				inv,bag,slot = ItemRack.FindItem(swap[k],1)
				if bag then
					if i==16 and ItemRack.HasTitansGrip then
						local subtype = select(7,GetItemInfo(GetContainerItemLink(bag,slot)))
						if subtype and ItemRack.NoTitansGrip[subtype] then
							treatAs2H = 1
						end
					end
					-- TODO: Polarms, Fishing Poles and Staves (7th GetItemInfo) cannot
					-- be equipped alongside Two-Handed Axes, Two-Handed Maces and Two-Handed Swords
					if (not ItemRack.HasTitansGrip or treatAs2H) and select(3,ItemRack.GetInfoByID(swap[k]))=="INVTYPE_2HWEAPON" then
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
						swap[k] = nil
						swap[k+1] = nil -- fix by Romracer
						skip = 1
					else
						if set.old then
							set.old[i] = ItemRack.GetID(i)
						end
						ItemRack.MoveItem(bag,slot,i,nil)
						swap[k] = nil
					end
				elseif inv==(i+1) and ItemRack.SameID(swap[k+1],ItemRack.GetID(i)) then
					-- item is in other slot and other slot wants to go to this one
					if set.old then
						set.old[i] = ItemRack.GetID(i)
						set.old[i+1] = ItemRack.GetID(i+1)
					end
					ItemRack.MoveItem(i,nil,i+1,nil)
					swap[k] = nil
					swap[k+1] = nil
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
		
		ItemRack.UpdateCombatQueue() -- update button gear icon if per set queues is active
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
			if toBag == INVSLOT_AMMO then -- workaround for classic ammo slot weirdness
				toBag = INVSLOT_RANGED
			end
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

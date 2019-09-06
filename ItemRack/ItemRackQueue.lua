-- ItemRackQueue.lua
local _

function ItemRack.PeriodicQueueCheck()
	if SpellIsTargeting() then
		return
	end
	if ItemRackUser.EnableQueues=="ON" then
		for i in pairs(ItemRackUser.QueuesEnabled) do
			ItemRack.ProcessAutoQueue(i)
		end
	end
end

function ItemRack.ProcessAutoQueue(slot)
	if not slot or IsInventoryItemLocked(slot) then
		return
	end

	local start,duration,enable = GetInventoryItemCooldown("player",slot)
	local timeLeft = GetTime()-start
	local baseID = ItemRack.GetIRString(GetInventoryItemLink("player",slot),true,true)
	local icon = _G["ItemRackButton"..slot.."Queue"]

	if not baseID then return end

	local buff = GetItemSpell(baseID)
	if buff then
		if AuraUtil.FindAuraByName(buff,"player") or (start>0 and (duration-timeLeft)>30 and timeLeft<1) then
			icon:SetDesaturated(1)
			return
		end
	end

	if ItemRackItems[baseID] then
		if ItemRackItems[baseID].keep then
			icon:SetVertexColor(1,.5,.5)
			return -- leave if .keep flag set on this item
		end
		if ItemRackItems[baseID].delay then
			-- leave if currently equipped trinket is on cooldown for less than its delay
			if start>0 and (duration-timeLeft)>30 and timeLeft<ItemRackItems[baseID].delay then
				icon:SetDesaturated(1)
				return
			end
		end
	end
	icon:SetDesaturated(0)
	icon:SetVertexColor(1,1,1)

	local ready = ItemRack.ItemNearReady(baseID)
	if ready and ItemRack.CombatQueue[slot] then
		ItemRack.CombatQueue[slot] = nil
		ItemRack.UpdateCombatQueue()
	end

	local list,rank = ItemRackUser.Queues[slot]

	local candidate,bag,s
	for i=1,#(list) do
		candidate = string.match(list[i],"(%d+)") --FIXME: not sure what list[i] is; it might simply be cleaning up some sort of slot number to make sure it is numeric, OR it might actually be an itemID... if it is the latter then this (conversion to baseID) should be handled by either ItemRack.GetIRString(list[i],true) if list[i] is an ItemRack-style ID or ItemRack.GetIRString(list[i],true,true) if list[i] is a regular ItemLink/ItemString, MOST things point to it being an ItemRack-style ID, but I do not want to mess anything up if this is in fact just a regular number, so I'll leave the line as it is
		if list[i]==0 then
			break
		elseif ready and candidate==baseID then
			break
		else
			if not ready or enable==0 or (ItemRackItems[candidate] and ItemRackItems[candidate].priority) then
				if ItemRack.ItemNearReady(candidate) then
					if GetItemCount(candidate)>0 and not IsEquippedItem(candidate) then
						_,bag,s = ItemRack.FindItem(list[i])
						if bag then
							if ItemRack.CombatQueue[slot]~=list[i] then
								ItemRack.EquipItemByID(list[i],slot)
							end
							break
						end
					end
				end
			end
		end
	end
end

function ItemRack.ItemNearReady(id)
	local start,duration = GetItemCooldown(id)
	if start==0 or duration-(GetTime()-start)<30 then
		return 1
	end
end

function ItemRack.SetQueue(slot,newQueue)
	if not newQueue then
		ItemRackUser.QueuesEnabled[slot] = nil
	elseif type(newQueue)=="table" then
		ItemRackUser.Queues[slot] = ItemRackUser.Queues[slot] or {}
		for i in pairs(ItemRackUser.Queues[slot]) do
			ItemRackUser.Queues[slot][i] = nil
		end
		for i=1,#(newQueue) do
			table.insert(ItemRackUser.Queues[slot],newQueue[i])
		end
		if ItemRackOptFrame:IsVisible() then
			if ItemRackOptSubFrame7:IsVisible() and ItemRackOpt.SelectedSlot==slot then
				ItemRackOpt.SetupQueue(slot)
			else
				ItemRackOpt.UpdateInv()
			end
		end
		ItemRackUser.QueuesEnabled[slot] = 1
	end
	ItemRack.UpdateCombatQueue()
end

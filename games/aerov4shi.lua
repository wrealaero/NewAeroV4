--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end
local vapeEvents = setmetatable({}, {
	__index = function(self, index)
		self[index] = Instance.new('BindableEvent')
		return self[index]
	end
})

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local httpService = cloneref(game:GetService('HttpService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local collectionService = cloneref(game:GetService('CollectionService'))
local contextActionService = cloneref(game:GetService('ContextActionService'))
local guiService = cloneref(game:GetService('GuiService'))
local coreGui = cloneref(game:GetService('CoreGui'))
local starterGui = cloneref(game:GetService('StarterGui'))

local isnetworkowner = identifyexecutor and table.find({'AWP', 'Nihon'}, ({identifyexecutor()})[1]) and isnetworkowner or function()
	return true
end
local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset

local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local uipallet = vape.Libraries.uipallet
local tween = vape.Libraries.tween
local color = vape.Libraries.color
local whitelist = vape.Libraries.whitelist
local prediction = vape.Libraries.prediction
local getfontsize = vape.Libraries.getfontsize
local getcustomasset = vape.Libraries.getcustomasset


local store = {
	attackReach = 0,
	attackReachUpdate = tick(),
	damage = {},
	damageBlockFail = tick(),
	hand = {},
	localHand = {},
	inventory = {
		inventory = {
			items = {},
			armor = {}
		},
		hotbar = {}
	},
	inventories = {},
	matchState = 0,
	queueType = 'bedwars_test',
	tools = {}
}
local Reach = {}
local HitBoxes = {}
local HitFix = {}
local InfiniteFly = {}
local TrapDisabler
local AntiFallPart
local bedwars, remotes, sides, oldinvrender, oldSwing = {}, {}, {}

local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = getcustomasset('newvape/assets/new/blur.png')
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end

local function collection(tags, module, customadd, customremove)
	tags = typeof(tags) ~= 'table' and {tags} or tags
	local objs, connections = {}, {}

	for _, tag in tags do
		table.insert(connections, collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
			if customadd then
				customadd(objs, v, tag)
				return
			end
			table.insert(objs, v)
		end))
		table.insert(connections, collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
			if customremove then
				customremove(objs, v, tag)
				return
			end
			v = table.find(objs, v)
			if v then
				table.remove(objs, v)
			end
		end))

		for _, v in collectionService:GetTagged(tag) do
			if customadd then
				customadd(objs, v, tag)
				continue
			end
			table.insert(objs, v)
		end
	end

	local cleanFunc = function(self)
		for _, v in connections do
			v:Disconnect()
		end
		table.clear(connections)
		table.clear(objs)
		table.clear(self)
	end
	if module then
		module:Clean(cleanFunc)
	end
	return objs, cleanFunc
end

local function getBestArmor(slot)
	local closest, mag = nil, 0

	for _, item in store.inventory.inventory.items do
		local meta = item and bedwars.ItemMeta[item.itemType] or {}

		if meta.armor and meta.armor.slot == slot then
			local newmag = (meta.armor.damageReductionMultiplier or 0)

			if newmag > mag then
				closest, mag = item, newmag
			end
		end
	end

	return closest
end

local function getBow()
	local bestBow, bestBowSlot, bestBowDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local bowMeta = bedwars.ItemMeta[item.itemType].projectileSource
		if bowMeta and table.find(bowMeta.ammoItemTypes, 'arrow') then
			local bowDamage = bedwars.ProjectileMeta[bowMeta.projectileType('arrow')].combat.damage or 0
			if bowDamage > bestBowDamage then
				bestBow, bestBowSlot, bestBowDamage = item, slot, bowDamage
			end
		end
	end
	return bestBow, bestBowSlot
end

local function getItem(itemName, inv)
	for slot, item in (inv or store.inventory.inventory.items) do
		if item.itemType == itemName then
			return item, slot
		end
	end
	return nil
end

local function getRoactRender(func)
	return debug.getupvalue(debug.getupvalue(debug.getupvalue(func, 3).render, 2).render, 1)
end

local function getSword()
	local bestSword, bestSwordSlot, bestSwordDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local swordMeta = bedwars.ItemMeta[item.itemType].sword
		if swordMeta then
			local swordDamage = swordMeta.damage or 0
			if swordDamage > bestSwordDamage then
				bestSword, bestSwordSlot, bestSwordDamage = item, slot, swordDamage
			end
		end
	end
	return bestSword, bestSwordSlot
end

local function getTool(breakType)
	local bestTool, bestToolSlot, bestToolDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local toolMeta = bedwars.ItemMeta[item.itemType].breakBlock
		if toolMeta then
			local toolDamage = toolMeta[breakType] or 0
			if toolDamage > bestToolDamage then
				bestTool, bestToolSlot, bestToolDamage = item, slot, toolDamage
			end
		end
	end
	return bestTool, bestToolSlot
end

local function getWool()
	for _, wool in (inv or store.inventory.inventory.items) do
		if wool.itemType:find('wool') then
			return wool and wool.itemType, wool and wool.amount
		end
	end
end

local function getStrength(plr)
	if not plr.Player then
		return 0
	end

	local strength = 0
	for _, v in (store.inventories[plr.Player] or {items = {}}).items do
		local itemmeta = bedwars.ItemMeta[v.itemType]
		if itemmeta and itemmeta.sword and itemmeta.sword.damage > strength then
			strength = itemmeta.sword.damage
		end
	end

	return strength
end

local function getPlacedBlock(pos)
	if not pos then
		return
	end
	local roundedPosition = bedwars.BlockController:getBlockPosition(pos)
	return bedwars.BlockController:getStore():getBlockAt(roundedPosition), roundedPosition
end

local function getBlocksInPoints(s, e)
	local blocks, list = bedwars.BlockController:getStore(), {}
	for x = s.X, e.X do
		for y = s.Y, e.Y do
			for z = s.Z, e.Z do
				local vec = Vector3.new(x, y, z)
				if blocks:getBlockAt(vec) then
					table.insert(list, vec * 3)
				end
			end
		end
	end
	return list
end

local function getNearGround(range)
	range = Vector3.new(3, 3, 3) * (range or 10)
	local localPosition, mag, closest = entitylib.character.RootPart.Position, 60
	local blocks = getBlocksInPoints(bedwars.BlockController:getBlockPosition(localPosition - range), bedwars.BlockController:getBlockPosition(localPosition + range))

	for _, v in blocks do
		if not getPlacedBlock(v + Vector3.new(0, 3, 0)) then
			local newmag = (localPosition - v).Magnitude
			if newmag < mag then
				mag, closest = newmag, v + Vector3.new(0, 3, 0)
			end
		end
	end

	table.clear(blocks)
	return closest
end

local function getShieldAttribute(char)
	local returned = 0
	for name, val in char:GetAttributes() do
		if name:find('Shield') and type(val) == 'number' and val > 0 then
			returned += val
		end
	end
	return returned
end

local function getSpeed()
	local multi, increase, modifiers = 0, true, bedwars.SprintController:getMovementStatusModifier():getModifiers()

	for v in modifiers do
		local val = v.constantSpeedMultiplier and v.constantSpeedMultiplier or 0
		if val and val > math.max(multi, 1) then
			increase = false
			multi = val - (0.06 * math.round(val))
		end
	end

	for v in modifiers do
		multi += math.max((v.moveSpeedMultiplier or 0) - 1, 0)
	end

	if multi > 0 and increase then
		multi += 0.16 + (0.02 * math.round(multi))
	end

	return 20 * (multi + 1)
end

local function getTableSize(tab)
	local ind = 0
	for _ in tab do
		ind += 1
	end
	return ind
end

local function hotbarSwitch(slot)
	if slot and store.inventory.hotbarSlot ~= slot then
		bedwars.Store:dispatch({
			type = 'InventorySelectHotbarSlot',
			slot = slot
		})
		vapeEvents.InventoryChanged.Event:Wait()
		return true
	end
	return false
end

local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end
	return nil
end

local function isTarget(plr)
	return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
end

local function notif(...) return
	vape:CreateNotification(...)
end

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end

local function roundPos(vec)
	return Vector3.new(math.round(vec.X / 3) * 3, math.round(vec.Y / 3) * 3, math.round(vec.Z / 3) * 3)
end

local function switchItem(tool, delayTime)
	delayTime = delayTime or 0.05
	local check = lplr.Character and lplr.Character:FindFirstChild('HandInvItem') or nil
	if check and check.Value ~= tool and tool.Parent ~= nil then
		task.spawn(function()
			bedwars.Client:Get(remotes.EquipItem):CallServerAsync({hand = tool})
		end)
		check.Value = tool
		if delayTime > 0 then
			task.wait(delayTime)
		end
		return true
	end
end

local function waitForChildOfType(obj, name, timeout, prop)
	local check, returned = tick() + timeout
	repeat
		returned = prop and obj[name] or obj:FindFirstChildOfClass(name)
		if returned and returned.Name ~= 'UpperTorso' or check < tick() then
			break
		end
		task.wait()
	until false
	return returned
end

local frictionTable, oldfrict = {}, {}
local frictionConnection
local frictionState

local function modifyVelocity(v)
	if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
		oldfrict[v] = v.CustomPhysicalProperties or 'none'
		v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
	end
end

local function updateVelocity(force)
	local newState = getTableSize(frictionTable) > 0
	if frictionState ~= newState or force then
		if frictionConnection then
			frictionConnection:Disconnect()
		end
		if newState then
			if entitylib.isAlive then
				for _, v in entitylib.character.Character:GetDescendants() do
					modifyVelocity(v)
				end
				frictionConnection = entitylib.character.Character.DescendantAdded:Connect(modifyVelocity)
			end
		else
			for i, v in oldfrict do
				i.CustomPhysicalProperties = v ~= 'none' and v or nil
			end
			table.clear(oldfrict)
		end
	end
	frictionState = newState
end

local kitorder = {
	hannah = 5,
	spirit_assassin = 4,
	dasher = 3,
	jade = 2,
	regent = 1
}

local sortmethods = {
	Damage = function(a, b)
		return a.Entity.Character:GetAttribute('LastDamageTakenTime') < b.Entity.Character:GetAttribute('LastDamageTakenTime')
	end,
	Threat = function(a, b)
		return getStrength(a.Entity) > getStrength(b.Entity)
	end,
	Kit = function(a, b)
		return (a.Entity.Player and kitorder[a.Entity.Player:GetAttribute('PlayingAsKit')] or 0) > (b.Entity.Player and kitorder[b.Entity.Player:GetAttribute('PlayingAsKit')] or 0)
	end,
	Health = function(a, b)
		return a.Entity.Health < b.Entity.Health
	end,
	Angle = function(a, b)
		local selfrootpos = entitylib.character.RootPart.Position
		local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
		local angle = math.acos(localfacing:Dot(((a.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)).Unit))
		local angle2 = math.acos(localfacing:Dot(((b.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)).Unit))
		return angle < angle2
	end
}

run(function()
	local oldstart = entitylib.start
	local function customEntity(ent)
		if ent:HasTag('inventory-entity') and not ent:HasTag('Monster') then
			return
		end

		entitylib.addEntity(ent, nil, ent:HasTag('Drone') and function(self)
			local droneplr = playersService:GetPlayerByUserId(self.Character:GetAttribute('PlayerUserId'))
			return not droneplr or lplr:GetAttribute('Team') ~= droneplr:GetAttribute('Team')
		end or function(self)
			return lplr:GetAttribute('Team') ~= self.Character:GetAttribute('Team')
		end)
	end

	entitylib.start = function()
		oldstart()
		if entitylib.Running then
			for _, ent in collectionService:GetTagged('entity') do
				customEntity(ent)
			end
			table.insert(entitylib.Connections, collectionService:GetInstanceAddedSignal('entity'):Connect(customEntity))
			table.insert(entitylib.Connections, collectionService:GetInstanceRemovedSignal('entity'):Connect(function(ent)
				entitylib.removeEntity(ent)
			end))
		end
	end

	entitylib.addPlayer = function(plr)
		if plr.Character then
			entitylib.refreshEntity(plr.Character, plr)
		end
		entitylib.PlayerConnections[plr] = {
			plr.CharacterAdded:Connect(function(char)
				entitylib.refreshEntity(char, plr)
			end),
			plr.CharacterRemoving:Connect(function(char)
				entitylib.removeEntity(char, plr == lplr)
			end),
			plr:GetAttributeChangedSignal('Team'):Connect(function()
				for _, v in entitylib.List do
					if v.Targetable ~= entitylib.targetCheck(v) then
						entitylib.refreshEntity(v.Character, v.Player)
					end
				end

				if plr == lplr then
					entitylib.start()
				else
					entitylib.refreshEntity(plr.Character, plr)
				end
			end)
		}
	end

	entitylib.addEntity = function(char, plr, teamfunc)
		if not char then return end
		entitylib.EntityThreads[char] = task.spawn(function()
			local hum, humrootpart, head
			if plr then
				hum = waitForChildOfType(char, 'Humanoid', 10)
				humrootpart = hum and waitForChildOfType(hum, 'RootPart', workspace.StreamingEnabled and 9e9 or 10, true)
				head = char:WaitForChild('Head', 10) or humrootpart
			else
				hum = {HipHeight = 0.5}
				humrootpart = waitForChildOfType(char, 'PrimaryPart', 10, true)
				head = humrootpart
			end
			local updateobjects = plr and plr ~= lplr and {
				char:WaitForChild('ArmorInvItem_0', 5),
				char:WaitForChild('ArmorInvItem_1', 5),
				char:WaitForChild('ArmorInvItem_2', 5),
				char:WaitForChild('HandInvItem', 5)
			} or {}

			if hum and humrootpart then
				local entity = {
					Connections = {},
					Character = char,
					Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char),
					Head = head,
					Humanoid = hum,
					HumanoidRootPart = humrootpart,
					HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
					Jumps = 0,
					JumpTick = tick(),
					Jumping = false,
					LandTick = tick(),
					MaxHealth = char:GetAttribute('MaxHealth') or 100,
					NPC = plr == nil,
					Player = plr,
					RootPart = humrootpart,
					TeamCheck = teamfunc
				}

				if plr == lplr then
					entity.AirTime = tick()
					entitylib.character = entity
					entitylib.isAlive = true
					entitylib.Events.LocalAdded:Fire(entity)
					table.insert(entitylib.Connections, char.AttributeChanged:Connect(function(attr)
						vapeEvents.AttributeChanged:Fire(attr)
					end))
				else
					entity.Targetable = entitylib.targetCheck(entity)

					for _, v in entitylib.getUpdateConnections(entity) do
						table.insert(entity.Connections, v:Connect(function()
							entity.Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char)
							entity.MaxHealth = char:GetAttribute('MaxHealth') or 100
							entitylib.Events.EntityUpdated:Fire(entity)
						end))
					end

					for _, v in updateobjects do
						table.insert(entity.Connections, v:GetPropertyChangedSignal('Value'):Connect(function()
							task.delay(0.1, function()
								if bedwars.getInventory then
									store.inventories[plr] = bedwars.getInventory(plr)
									entitylib.Events.EntityUpdated:Fire(entity)
								end
							end)
						end))
					end

					if plr then
						local anim = char:FindFirstChild('Animate')
						if anim then
							pcall(function()
								anim = anim.jump:FindFirstChildWhichIsA('Animation').AnimationId
								table.insert(entity.Connections, hum.Animator.AnimationPlayed:Connect(function(playedanim)
									if playedanim.Animation.AnimationId == anim then
										entity.JumpTick = tick()
										entity.Jumps += 1
										entity.LandTick = tick() + 1
										entity.Jumping = entity.Jumps > 1
									end
								end))
							end)
						end

						task.delay(0.1, function()
							if bedwars.getInventory then
								store.inventories[plr] = bedwars.getInventory(plr)
							end
						end)
					end
					table.insert(entitylib.List, entity)
					entitylib.Events.EntityAdded:Fire(entity)
				end

				table.insert(entity.Connections, char.ChildRemoved:Connect(function(part)
					if part == humrootpart or part == hum or part == head then
						if part == humrootpart and hum.RootPart then
							humrootpart = hum.RootPart
							entity.RootPart = hum.RootPart
							entity.HumanoidRootPart = hum.RootPart
							return
						end
						entitylib.removeEntity(char, plr == lplr)
					end
				end))
			end
			entitylib.EntityThreads[char] = nil
		end)
	end

	entitylib.getUpdateConnections = function(ent)
		local char = ent.Character
		local tab = {
			char:GetAttributeChangedSignal('Health'),
			char:GetAttributeChangedSignal('MaxHealth'),
			{
				Connect = function()
					ent.Friend = ent.Player and isFriend(ent.Player) or nil
					ent.Target = ent.Player and isTarget(ent.Player) or nil
					return {Disconnect = function() end}
				end
			}
		}

		if ent.Player then
			table.insert(tab, ent.Player:GetAttributeChangedSignal('PlayingAsKit'))
		end

		for name, val in char:GetAttributes() do
			if name:find('Shield') and type(val) == 'number' then
				table.insert(tab, char:GetAttributeChangedSignal(name))
			end
		end

		return tab
	end

	entitylib.targetCheck = function(ent)
		if ent.TeamCheck then
			return ent:TeamCheck()
		end
		if ent.NPC then return true end
		if isFriend(ent.Player) then return false end
		if not select(2, whitelist:get(ent.Player)) then return false end
		return lplr:GetAttribute('Team') ~= ent.Player:GetAttribute('Team')
	end
	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
end)
entitylib.start()

run(function()
	local KnitInit, Knit
	repeat
		KnitInit, Knit = pcall(function()
			return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9)
		end)
		if KnitInit then break end
		task.wait()
	until KnitInit

	if not debug.getupvalue(Knit.Start, 1) then
		repeat task.wait() until debug.getupvalue(Knit.Start, 1)
	end

	local Flamework = require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
	local InventoryUtil = require(replicatedStorage.TS.inventory['inventory-util']).InventoryUtil
	local Client = require(replicatedStorage.TS.remotes).default.Client
	local OldGet, OldBreak = Client.Get

	bedwars = setmetatable({
		AbilityController = Flamework.resolveDependency('@easy-games/game-core:client/controllers/ability/ability-controller@AbilityController'),
		AnimationType = require(replicatedStorage.TS.animation['animation-type']).AnimationType,
		AnimationUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out['shared'].util['animation-util']).AnimationUtil,
		AppController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.controllers['app-controller']).AppController,
		BedBreakEffectMeta = require(replicatedStorage.TS.locker['bed-break-effect']['bed-break-effect-meta']).BedBreakEffectMeta,
		BedwarsKitMeta = require(replicatedStorage.TS.games.bedwars.kit['bedwars-kit-meta']).BedwarsKitMeta,
		BlockBreaker = Knit.Controllers.BlockBreakController.blockBreaker,
		BlockController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out).BlockEngine,
		BlockEngine = require(lplr.PlayerScripts.TS.lib['block-engine']['client-block-engine']).ClientBlockEngine,
		BlockPlacer = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.client.placement['block-placer']).BlockPlacer,
		BowConstantsTable = debug.getupvalue(Knit.Controllers.ProjectileController.enableBeam, 8),
		ClickHold = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.ui.lib.util['click-hold']).ClickHold,
		Client = Client,
		ClientConstructor = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts'].net.out.client),
		ClientDamageBlock = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.shared.remotes).BlockEngineRemotes.Client,
		CombatConstant = require(replicatedStorage.TS.combat['combat-constant']).CombatConstant,
		DamageIndicator = Knit.Controllers.DamageIndicatorController.spawnDamageIndicator,
		DefaultKillEffect = require(lplr.PlayerScripts.TS.controllers.game.locker['kill-effect'].effects['default-kill-effect']),
		EmoteType = require(replicatedStorage.TS.locker.emote['emote-type']).EmoteType,
		GameAnimationUtil = require(replicatedStorage.TS.animation['animation-util']).GameAnimationUtil,
		getIcon = function(item, showinv)
			local itemmeta = bedwars.ItemMeta[item.itemType]
			return itemmeta and showinv and itemmeta.image or ''
		end,
		getInventory = function(plr)
			local suc, res = pcall(function()
				return InventoryUtil.getInventory(plr)
			end)
			return suc and res or {
				items = {},
				armor = {}
			}
		end,
		HudAliveCount = require(lplr.PlayerScripts.TS.controllers.global['top-bar'].ui.game['hud-alive-player-counts']).HudAlivePlayerCounts,
		ItemMeta = debug.getupvalue(require(replicatedStorage.TS.item['item-meta']).getItemMeta, 1),
		KillEffectMeta = require(replicatedStorage.TS.locker['kill-effect']['kill-effect-meta']).KillEffectMeta,
		KillFeedController = Flamework.resolveDependency('client/controllers/game/kill-feed/kill-feed-controller@KillFeedController'),
		Knit = Knit,
		KnockbackUtil = require(replicatedStorage.TS.damage['knockback-util']).KnockbackUtil,
		MageKitUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.mage['mage-kit-util']).MageKitUtil,
		NametagController = Knit.Controllers.NametagController,
		PartyController = Flamework.resolveDependency('@easy-games/lobby:client/controllers/party-controller@PartyController'),
		ProjectileMeta = require(replicatedStorage.TS.projectile['projectile-meta']).ProjectileMeta,
		QueryUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil,
		QueueCard = require(lplr.PlayerScripts.TS.controllers.global.queue.ui['queue-card']).QueueCard,
		QueueMeta = require(replicatedStorage.TS.game['queue-meta']).QueueMeta,
		Roact = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts']['roact'].src),
		RuntimeLib = require(replicatedStorage['rbxts_include'].RuntimeLib),
		SoundList = require(replicatedStorage.TS.sound['game-sound']).GameSound,
		SoundManager = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).SoundManager,
		Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore,
		TeamUpgradeMeta = debug.getupvalue(require(replicatedStorage.TS.games.bedwars['team-upgrade']['team-upgrade-meta']).getTeamUpgradeMetaForQueue, 6),
		UILayers = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).UILayers,
		VisualizerUtils = require(lplr.PlayerScripts.TS.lib.visualizer['visualizer-utils']).VisualizerUtils,
		WeldTable = require(replicatedStorage.TS.util['weld-util']).WeldUtil,
		WinEffectMeta = require(replicatedStorage.TS.locker['win-effect']['win-effect-meta']).WinEffectMeta,
		ZapNetworking = require(lplr.PlayerScripts.TS.lib.network)
	}, {
		__index = function(self, ind)
			rawset(self, ind, Knit.Controllers[ind])
			return rawget(self, ind)
		end
	})

	local remoteNames = {
		AfkStatus = debug.getproto(Knit.Controllers.AfkController.KnitStart, 1),
		AttackEntity = Knit.Controllers.SwordController.sendServerRequest,
		BeePickup = Knit.Controllers.BeeNetController.trigger,
		CannonAim = debug.getproto(Knit.Controllers.CannonController.startAiming, 5),
		CannonLaunch = Knit.Controllers.CannonHandController.launchSelf,
		ConsumeBattery = debug.getproto(Knit.Controllers.BatteryController.onKitLocalActivated, 1),
		ConsumeItem = debug.getproto(Knit.Controllers.ConsumeController.onEnable, 1),
		ConsumeSoul = Knit.Controllers.GrimReaperController.consumeSoul,
		ConsumeTreeOrb = debug.getproto(Knit.Controllers.EldertreeController.createTreeOrbInteraction, 1),
		DepositPinata = debug.getproto(debug.getproto(Knit.Controllers.PiggyBankController.KnitStart, 2), 5),
		DragonBreath = debug.getproto(Knit.Controllers.VoidDragonController.onKitLocalActivated, 5),
		DragonEndFly = debug.getproto(Knit.Controllers.VoidDragonController.flapWings, 1),
		DragonFly = Knit.Controllers.VoidDragonController.flapWings,
		DropItem = Knit.Controllers.ItemDropController.dropItemInHand,
		EquipItem = debug.getproto(require(replicatedStorage.TS.entity.entities['inventory-entity']).InventoryEntity.equipItem, 3),
		FireProjectile = debug.getupvalue(Knit.Controllers.ProjectileController.launchProjectileWithValues, 2),
		GroundHit = Knit.Controllers.FallDamageController.KnitStart,
		GuitarHeal = Knit.Controllers.GuitarController.performHeal,
		HannahKill = debug.getproto(Knit.Controllers.HannahController.registerExecuteInteractions, 1),
		HarvestCrop = debug.getproto(debug.getproto(Knit.Controllers.CropController.KnitStart, 4), 1),
		KaliyahPunch = debug.getproto(Knit.Controllers.DragonSlayerController.onKitLocalActivated, 1),
		MageSelect = debug.getproto(Knit.Controllers.MageController.registerTomeInteraction, 1),
		MinerDig = debug.getproto(Knit.Controllers.MinerController.setupMinerPrompts, 1),
		PickupItem = Knit.Controllers.ItemDropController.checkForPickup,
		PickupMetal = debug.getproto(Knit.Controllers.HiddenMetalController.onKitLocalActivated, 4),
		ReportPlayer = require(lplr.PlayerScripts.TS.controllers.global.report['report-controller']).default.reportPlayer,
		ResetCharacter = debug.getproto(Knit.Controllers.ResetController.createBindable, 1),
		SpawnRaven = debug.getproto(Knit.Controllers.RavenController.KnitStart, 1),
		SummonerClawAttack = Knit.Controllers.SummonerClawHandController.attack,
		WarlockTarget = debug.getproto(Knit.Controllers.WarlockStaffController.KnitStart, 2)
	}

	local function dumpRemote(tab)
		local ind
		for i, v in tab do
			if v == 'Client' then
				ind = i
				break
			end
		end
		return ind and tab[ind + 1] or ''
	end

	local preDumped = {
		EquipItem = 'SetInvItem'
	}

	for i, v in remoteNames do
		local remote = dumpRemote(debug.getconstants(v))
		if remote == '' then
			if not preDumped[i] then
				notif('Vape', 'Failed to grab remote ('..i..')', 10, 'alert')
			end
			remote = preDumped[i] or ''
		end
		remotes[i] = remote
	end

	OldBreak = bedwars.BlockController.isBlockBreakable

	Client.Get = function(self, remoteName)
		local call = OldGet(self, remoteName)

		if remoteName == remotes.AttackEntity then
			return {
				instance = call.instance,
				SendToServer = function(_, attackTable, ...)
					local suc, plr = pcall(function()
						return playersService:GetPlayerFromCharacter(attackTable.entityInstance)
					end)

					local selfpos = attackTable.validate.selfPosition.value
					local targetpos = attackTable.validate.targetPosition.value
					store.attackReach = ((selfpos - targetpos).Magnitude * 100) // 1 / 100
					store.attackReachUpdate = tick() + 1

					if Reach.Enabled or HitBoxes.Enabled then
						attackTable.validate.raycast = attackTable.validate.raycast or {}
						attackTable.validate.selfPosition.value += CFrame.lookAt(selfpos, targetpos).LookVector * math.max((selfpos - targetpos).Magnitude - 14.399, 0)
					end

					if suc and plr then
						if not select(2, whitelist:get(plr)) then return end
					end

					return call:SendToServer(attackTable, ...)
				end
			}
		elseif remoteName == 'StepOnSnapTrap' and TrapDisabler.Enabled then
			return {SendToServer = function() end}
		end

		return call
	end

	bedwars.BlockController.isBlockBreakable = function(self, breakTable, plr)
		local obj = bedwars.BlockController:getStore():getBlockAt(breakTable.blockPosition)

		if obj and obj.Name == 'bed' then
			for _, plr in playersService:GetPlayers() do
				if obj:GetAttribute('Team'..(plr:GetAttribute('Team') or 0)..'NoBreak') and not select(2, whitelist:get(plr)) then
					return false
				end
			end
		end

		return OldBreak(self, breakTable, plr)
	end

	local cache, blockhealthbar = {}, {blockHealth = -1, breakingBlockPosition = Vector3.zero}
	store.blockPlacer = bedwars.BlockPlacer.new(bedwars.BlockEngine, 'wool_white')

	local function getBlockHealth(block, blockpos)
		local blockdata = bedwars.BlockController:getStore():getBlockData(blockpos)
		return (blockdata and (blockdata:GetAttribute('1') or blockdata:GetAttribute('Health')) or block:GetAttribute('Health'))
	end

	local function getBlockHits(block, blockpos)
		if not block then return 0 end
		local breaktype = bedwars.ItemMeta[block.Name].block.breakType
		local tool = store.tools[breaktype]
		tool = tool and bedwars.ItemMeta[tool.itemType].breakBlock[breaktype] or 2
		return getBlockHealth(block, bedwars.BlockController:getBlockPosition(blockpos)) / tool
	end

	--[[
		Pathfinding using a luau version of dijkstra's algorithm
		Source: https://stackoverflow.com/questions/39355587/speeding-up-dijkstras-algorithm-to-solve-a-3d-maze
	]]
	local function calculatePath(target, blockpos)
		if cache[blockpos] then
			return unpack(cache[blockpos])
		end
		local visited, unvisited, distances, air, path = {}, {{0, blockpos}}, {[blockpos] = 0}, {}, {}

		for _ = 1, 10000 do
			local _, node = next(unvisited)
			if not node then break end
			table.remove(unvisited, 1)
			visited[node[2]] = true

			for _, side in sides do
				side = node[2] + side
				if visited[side] then continue end

				local block = getPlacedBlock(side)
				if not block or block:GetAttribute('NoBreak') or block == target then
					if not block then
						air[node[2]] = true
					end
					continue
				end

				local curdist = getBlockHits(block, side) + node[1]
				if curdist < (distances[side] or math.huge) then
					table.insert(unvisited, {curdist, side})
					distances[side] = curdist
					path[side] = node[2]
				end
			end
		end

		local pos, cost = nil, math.huge
		for node in air do
			if distances[node] < cost then
				pos, cost = node, distances[node]
			end
		end

		if pos then
			cache[blockpos] = {
				pos,
				cost,
				path
			}
			return pos, cost, path
		end
	end

	bedwars.placeBlock = function(pos, item)
		if getItem(item) then
			store.blockPlacer.blockType = item
			return store.blockPlacer:placeBlock(bedwars.BlockController:getBlockPosition(pos))
		end
	end

	bedwars.breakBlock = function(block, effects, anim, customHealthbar)
		if lplr:GetAttribute('DenyBlockBreak') or not entitylib.isAlive or InfiniteFly.Enabled then return end
		local handler = bedwars.BlockController:getHandlerRegistry():getHandler(block.Name)
		local cost, pos, target, path = math.huge

		for _, v in (handler and handler:getContainedPositions(block) or {block.Position / 3}) do
			local dpos, dcost, dpath = calculatePath(block, v * 3)
			if dpos and dcost < cost then
				cost, pos, target, path = dcost, dpos, v * 3, dpath
			end
		end

		if pos then
			if (entitylib.character.RootPart.Position - pos).Magnitude > 30 then return end
			local dblock, dpos = getPlacedBlock(pos)
			if not dblock then return end

			if (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 0.4 then
				local breaktype = bedwars.ItemMeta[dblock.Name].block.breakType
				local tool = store.tools[breaktype]
				if tool then
					switchItem(tool.tool)
				end
			end

			if blockhealthbar.blockHealth == -1 or dpos ~= blockhealthbar.breakingBlockPosition then
				blockhealthbar.blockHealth = getBlockHealth(dblock, dpos)
				blockhealthbar.breakingBlockPosition = dpos
			end

			bedwars.ClientDamageBlock:Get('DamageBlock'):CallServerAsync({
				blockRef = {blockPosition = dpos},
				hitPosition = pos,
				hitNormal = Vector3.FromNormalId(Enum.NormalId.Top)
			}):andThen(function(result)
				if result then
					if result == 'cancelled' then
						store.damageBlockFail = tick() + 1
						return
					end

					if effects then
						local blockdmg = (blockhealthbar.blockHealth - (result == 'destroyed' and 0 or getBlockHealth(dblock, dpos)))
						customHealthbar = customHealthbar or bedwars.BlockBreaker.updateHealthbar
						customHealthbar(bedwars.BlockBreaker, {blockPosition = dpos}, blockhealthbar.blockHealth, dblock:GetAttribute('MaxHealth'), blockdmg, dblock)
						blockhealthbar.blockHealth = math.max(blockhealthbar.blockHealth - blockdmg, 0)

						if blockhealthbar.blockHealth <= 0 then
							bedwars.BlockBreaker.breakEffect:playBreak(dblock.Name, dpos, lplr)
							bedwars.BlockBreaker.healthbarMaid:DoCleaning()
							blockhealthbar.breakingBlockPosition = Vector3.zero
						else
							bedwars.BlockBreaker.breakEffect:playHit(dblock.Name, dpos, lplr)
						end
					end

					if anim then
						local animation = bedwars.AnimationUtil:playAnimation(lplr, bedwars.BlockController:getAnimationController():getAssetId(1))
						bedwars.ViewmodelController:playAnimation(15)
						task.wait(0.3)
						animation:Stop()
						animation:Destroy()
					end
				end
			end)

			if effects then
				return pos, path, target
			end
		end
	end

	for _, v in Enum.NormalId:GetEnumItems() do
		table.insert(sides, Vector3.FromNormalId(v) * 3)
	end

	local function updateStore(new, old)
		if new.Bedwars ~= old.Bedwars then
			store.equippedKit = new.Bedwars.kit ~= 'none' and new.Bedwars.kit or ''
		end

		if new.Game ~= old.Game then
			store.matchState = new.Game.matchState
			store.queueType = new.Game.queueType or 'bedwars_test'
		end

		if new.Inventory ~= old.Inventory then
			local newinv = (new.Inventory and new.Inventory.observedInventory or {inventory = {}})
			local oldinv = (old.Inventory and old.Inventory.observedInventory or {inventory = {}})
			store.inventory = newinv

			if newinv ~= oldinv then
				vapeEvents.InventoryChanged:Fire()
			end

			if newinv.inventory.items ~= oldinv.inventory.items then
				vapeEvents.InventoryAmountChanged:Fire()
				store.tools.sword = getSword()
				for _, v in {'stone', 'wood', 'wool'} do
					store.tools[v] = getTool(v)
				end
			end

			if newinv.inventory.hand ~= oldinv.inventory.hand then
				local currentHand, toolType = new.Inventory.observedInventory.inventory.hand, ''
				if currentHand then
					local handData = bedwars.ItemMeta[currentHand.itemType]
					toolType = handData.sword and 'sword' or handData.block and 'block' or currentHand.itemType:find('bow') and 'bow'
				end

				store.hand = {
					tool = currentHand and currentHand.tool,
					amount = currentHand and currentHand.amount or 0,
					toolType = toolType
				}
			end
		end
	end

	local storeChanged = bedwars.Store.changed:connect(updateStore)
	updateStore(bedwars.Store:getState(), {})

	for _, event in {'MatchEndEvent', 'EntityDeathEvent', 'BedwarsBedBreak', 'BalloonPopped', 'AngelProgress', 'GrapplingHookFunctions'} do
		if not vape.Connections then return end
		bedwars.Client:WaitFor(event):andThen(function(connection)
			vape:Clean(connection:Connect(function(...)
				vapeEvents[event]:Fire(...)
			end))
		end)
	end

	vape:Clean(bedwars.ZapNetworking.EntityDamageEventZap.On(function(...)
		vapeEvents.EntityDamageEvent:Fire({
			entityInstance = ...,
			damage = select(2, ...),
			damageType = select(3, ...),
			fromPosition = select(4, ...),
			fromEntity = select(5, ...),
			knockbackMultiplier = select(6, ...),
			knockbackId = select(7, ...),
			disableDamageHighlight = select(13, ...)
		})
	end))

	for _, event in {'PlaceBlockEvent', 'BreakBlockEvent'} do
		vape:Clean(bedwars.ZapNetworking[event..'Zap'].On(function(...)
			local data = {
				blockRef = {
					blockPosition = ...,
				},
				player = select(5, ...)
			}
			for i, v in cache do
				if ((data.blockRef.blockPosition * 3) - v[1]).Magnitude <= 30 then
					table.clear(v[3])
					table.clear(v)
					cache[i] = nil
				end
			end
			vapeEvents[event]:Fire(data)
		end))
	end

	store.blocks = collection('block', gui)
	store.shop = collection({'BedwarsItemShop', 'TeamUpgradeShopkeeper'}, gui, function(tab, obj)
		table.insert(tab, {
			Id = obj.Name,
			RootPart = obj,
			Shop = obj:HasTag('BedwarsItemShop'),
			Upgrades = obj:HasTag('TeamUpgradeShopkeeper')
		})
	end)
	store.enchant = collection({'enchant-table', 'broken-enchant-table'}, gui, nil, function(tab, obj, tag)
		if obj:HasTag('enchant-table') and tag == 'broken-enchant-table' then return end
		obj = table.find(tab, obj)
		if obj then
			table.remove(tab, obj)
		end
	end)

	local kills = sessioninfo:AddItem('Kills')
	local beds = sessioninfo:AddItem('Beds')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')

	local mapname = 'Unknown'
	sessioninfo:AddItem('Map', 0, function()
		return mapname
	end, false)

	task.delay(1, function()
		games:Increment()
	end)

	task.spawn(function()
		pcall(function()
			repeat task.wait() until store.matchState ~= 0 or vape.Loaded == nil
			if vape.Loaded == nil then return end
			mapname = workspace:WaitForChild('Map', 5):WaitForChild('Worlds', 5):GetChildren()[1].Name
			mapname = string.gsub(string.split(mapname, '_')[2] or mapname, '-', '') or 'Blank'
		end)
	end)

	vape:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
		if bedTable.player and bedTable.player.UserId == lplr.UserId then
			beds:Increment()
		end
	end))

	vape:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winTable)
		if (bedwars.Store:getState().Game.myTeam or {}).id == winTable.winningTeamId or lplr.Neutral then
			wins:Increment()
		end
	end))

	vape:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
		local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
		local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
		if not killed or not killer then return end

		if killed ~= lplr and killer == lplr then
			kills:Increment()
		end
	end))

	task.spawn(function()
		repeat
			if entitylib.isAlive then
				entitylib.character.AirTime = entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and tick() or entitylib.character.AirTime
			end

			for _, v in entitylib.List do
				v.LandTick = math.abs(v.RootPart.Velocity.Y) < 0.1 and v.LandTick or tick()
				if (tick() - v.LandTick) > 0.2 and v.Jumps ~= 0 then
					v.Jumps = 0
					v.Jumping = false
				end
			end
			task.wait()
		until vape.Loaded == nil
	end)

	pcall(function()
		if getthreadidentity and setthreadidentity then
			local old = getthreadidentity()
			setthreadidentity(2)

			bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
			bedwars.ShopItems = debug.getupvalue(debug.getupvalue(bedwars.Shop.getShopItem, 1), 2)
			bedwars.Shop.getShopItem('iron_sword', lplr)

			setthreadidentity(old)
			store.shopLoaded = true
		else
			task.spawn(function()
				repeat
					task.wait(0.1)
				until vape.Loaded == nil or bedwars.AppController:isAppOpen('BedwarsItemShopApp')

				bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
				bedwars.ShopItems = debug.getupvalue(debug.getupvalue(bedwars.Shop.getShopItem, 1), 2)
				store.shopLoaded = true
			end)
		end
	end)

	vape:Clean(function()
		Client.Get = OldGet
		bedwars.BlockController.isBlockBreakable = OldBreak
		store.blockPlacer:disable()
		for _, v in vapeEvents do
			v:Destroy()
		end
		for _, v in cache do
			table.clear(v[3])
			table.clear(v)
		end
		table.clear(store.blockPlacer)
		table.clear(vapeEvents)
		table.clear(bedwars)
		table.clear(store)
		table.clear(cache)
		table.clear(sides)
		table.clear(remotes)
		storeChanged:disconnect()
		storeChanged = nil
	end)
end)

run(function()
	local function isFirstPerson()
		if not (lplr.Character and lplr.Character:FindFirstChild("Head")) then return nil end
		return (lplr.Character.Head.Position - gameCamera.CFrame.Position).Magnitude < 2
	end
	
	local function hasValidWeapon()
		local toolType = store.hand.toolType
		return toolType == 'sword' or toolType == 'bow' or toolType == 'crossbow' or toolType == 'headhunter'
	end
	
	local function isHoldingProjectile()
		local toolType = store.hand.toolType
		return toolType == 'bow' or toolType == 'crossbow' or toolType == 'headhunter'
	end
	
	local AimAssist
	local Targets
	local Sort
	local AimSpeed
	local Distance
	local AngleSlider
	local StrafeIncrease
	local KillauraTarget
	local ClickAim
	local ShopCheck
	local FirstPersonCheck
	local SmoothMode
	local VerticalAim
	local VerticalOffset
	local AimPart
	local ProjectileMode
	local ProjectileAimSpeed
	
	AimAssist = vape.Categories.Combat:CreateModule({
		Name = 'AimAssist',
		Function = function(callback)
			if callback then
				AimAssist:Clean(runService.Heartbeat:Connect(function(dt)
					if entitylib.isAlive and hasValidWeapon() and ((not ClickAim.Enabled) or (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) < 0.4) then
						if FirstPersonCheck.Enabled then
							if not isFirstPerson() then return end
						end
						
						if ShopCheck.Enabled then
							local isShop = lplr:FindFirstChild("PlayerGui") and lplr:FindFirstChild("PlayerGui"):FindFirstChild("ItemShop")
							if isShop then return end
						end
						
						local useProjectileMode = ProjectileMode.Enabled and isHoldingProjectile()
						local effectiveDistance = useProjectileMode and 9999 or Distance.Value
						
						local ent = KillauraTarget.Enabled and store.KillauraTarget or entitylib.EntityPosition({
							Range = effectiveDistance,
							Part = 'RootPart',
							Wallcheck = Targets.Walls.Enabled,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Sort = sortmethods[Sort.Value]
						})
						
						if ent then
							pcall(function()
								local plr = ent
								vapeTargetInfo.Targets.AimAssist = {
									Humanoid = {
										Health = (plr.Character:GetAttribute("Health") or plr.Humanoid.Health) + getShieldAttribute(plr.Character),
										MaxHealth = plr.Character:GetAttribute("MaxHealth") or plr.Humanoid.MaxHealth
									},
									Player = plr.Player
								}
							end)
							
							local delta = (ent.RootPart.Position - entitylib.character.RootPart.Position)
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
							local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
							if angle >= (math.rad(AngleSlider.Value) / 2) then return end
							
							targetinfo.Targets[ent] = tick() + 1
							
							local aimPosition = ent.RootPart.Position
							if AimPart.Value ~= "Root" then
								local targetPart = ent.Character:FindFirstChild(AimPart.Value == "Head" and "Head" or "Torso")
								if targetPart then
									aimPosition = targetPart.Position
								end
							end
							
							if useProjectileMode then
								local originPos = entitylib.character.RootPart.Position
								local distance = (aimPosition - originPos).Magnitude
								
								local projSpeed = 100 
								local gravity = 196.2
								
								if store.hand.tool then
									local toolName = store.hand.tool.Name
									if toolName:find("crossbow") then
										projSpeed = 200
									elseif toolName:find("headhunter") then
										projSpeed = 180
									end
								end
								
								local balloons = ent.Character:GetAttribute('InflatedBalloons')
								local playerGravity = workspace.Gravity
								if balloons and balloons > 0 then
									playerGravity = workspace.Gravity * math.max(1 - (balloons * 0.05), 0.7)
								end
								
								local predictedPosition = prediction.predictStrafingMovement(
									ent.Player,
									ent.RootPart,
									projSpeed,
									gravity,
									originPos
								)
								
								if predictedPosition then
									aimPosition = predictedPosition
								end
								
								if VerticalAim.Enabled then
									aimPosition = aimPosition + Vector3.new(0, VerticalOffset.Value, 0)
								end
								
								local finalAimSpeed = ProjectileAimSpeed.Value
								if StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) then
									finalAimSpeed = finalAimSpeed + 3
								end
								
								local targetCFrame = CFrame.lookAt(gameCamera.CFrame.p, aimPosition)
								if SmoothMode.Value == "Linear" then
									gameCamera.CFrame = gameCamera.CFrame:Lerp(targetCFrame, finalAimSpeed * dt)
								elseif SmoothMode.Value == "Elastic" then
									local lerpAmount = 1 - math.exp(-finalAimSpeed * dt)
									gameCamera.CFrame = gameCamera.CFrame:Lerp(targetCFrame, lerpAmount)
								elseif SmoothMode.Value == "Instant" then
									gameCamera.CFrame = targetCFrame
								end
							else
								if VerticalAim.Enabled then
									aimPosition = aimPosition + Vector3.new(0, VerticalOffset.Value, 0)
								end
								
								local finalAimSpeed = AimSpeed.Value
								if StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) then
									finalAimSpeed = finalAimSpeed + 10
								end
								
								if SmoothMode.Value == "Linear" then
									gameCamera.CFrame = gameCamera.CFrame:Lerp(CFrame.lookAt(gameCamera.CFrame.p, aimPosition), finalAimSpeed * dt)
								elseif SmoothMode.Value == "Elastic" then
									local lerpAmount = 1 - math.exp(-finalAimSpeed * dt)
									gameCamera.CFrame = gameCamera.CFrame:Lerp(CFrame.lookAt(gameCamera.CFrame.p, aimPosition), lerpAmount)
								elseif SmoothMode.Value == "Instant" then
									gameCamera.CFrame = CFrame.lookAt(gameCamera.CFrame.p, aimPosition)
								end
							end
						end
					end
				end))
			end
		end,
		Tooltip = 'Compensates for your absolute garbage tracking skills with sword or projectile'
	})
	
	Targets = AimAssist:CreateTargets({
		Players = true, 
		Walls = true
	})
	
	local methods = {'Damage', 'Distance'}
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	
	Sort = AimAssist:CreateDropdown({
		Name = 'Target Mode',
		List = methods
	})
	
	AimSpeed = AimAssist:CreateSlider({
		Name = 'Aim Speed',
		Min = 1,
		Max = 20,
		Default = 6
	})
	
	Distance = AimAssist:CreateSlider({
		Name = 'Distance',
		Min = 1,
		Max = 30,
		Default = 30,
		Suffix = function(val) 
			return val == 1 and 'stud' or 'studs' 
		end
	})
	
	AngleSlider = AimAssist:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 70
	})
	
	SmoothMode = AimAssist:CreateDropdown({
		Name = 'Smooth Mode',
		List = {'Linear', 'Elastic', 'Instant'},
		Default = 'Linear',
		Tooltip = 'The transition from garbage to actually on target'
	})
	
	AimPart = AimAssist:CreateDropdown({
		Name = 'Aim Part',
		List = {'Root', 'Head', 'Torso'},
		Default = 'Root',
		Tooltip = 'Which part of the enemy to actually aim at (surprise: not the sky)'
	})
	
	ProjectileMode = AimAssist:CreateToggle({
		Name = 'Projectile Mode',
		Default = false,
		Tooltip = 'Does the fucking math for you so you might actually hit something for once',
		Function = function(callback)
			ProjectileAimSpeed.Object.Visible = callback
		end
	})
	
	ProjectileAimSpeed = AimAssist:CreateSlider({
		Name = 'Projectile Speed',
		Min = 1,
		Max = 15,
		Default = 8,
		Visible = false,
		Tooltip = 'How fast your slow ass aims with projectiles'
	})
	
	ClickAim = AimAssist:CreateToggle({
		Name = 'Click Aim',
		Default = true,
		Tooltip = 'Only helps your dumb ass aim when you are actually attacking'
	})
	
	KillauraTarget = AimAssist:CreateToggle({
		Name = 'Use killaura target',
		Tooltip = 'Because killaura apparently has better target selection than your dumb ass'
	})
	
	VerticalAim = AimAssist:CreateToggle({
		Name = 'Vertical Offset',
		Default = false,
		Tooltip = 'Stop aiming at fucking ankles',
		Function = function(callback)
			VerticalOffset.Object.Visible = callback
		end
	})
	
	VerticalOffset = AimAssist:CreateSlider({
		Name = 'Offset',
		Min = -3,
		Max = 3,
		Default = 0,
		Decimal = 10,
		Visible = false,
		Tooltip = 'Because apparently vertical aiming is too hard for your two brain cells'
	})
	
	ShopCheck = AimAssist:CreateToggle({
		Name = "Shop Check",
		Default = false,
		Tooltip = 'Stops you from being that guy who aims while in shop lmao'
	})
	
	FirstPersonCheck = AimAssist:CreateToggle({
		Name = "First Person Check",
		Default = false,
		Tooltip = 'Only works in first person'
	})
	
	StrafeIncrease = AimAssist:CreateToggle({
		Name = 'Strafe increase',
		Tooltip = 'Faster aim when strafing (A/D)'
	})
end)

run(function()
    local KitRender = vape.Categories.Render:CreateModule({
        Name = 'Kit Render',
        Function = function(callback)
            if callback then
                local Players = game:GetService("Players")
                local player = Players.LocalPlayer
                local PlayerGui = player:WaitForChild("PlayerGui")

                local ids = {
                    ['none'] = "rbxassetid://16493320215",
                    ["random"] = "rbxassetid://79773209697352",
                    ["cowgirl"] = "rbxassetid://9155462968",
                    ["davey"] = "rbxassetid://9155464612",
                    ["warlock"] = "rbxassetid://15186338366",
                    ["ember"] = "rbxassetid://9630017904",
                    ["black_market_trader"] = "rbxassetid://9630017904",
                    ["yeti"] = "rbxassetid://9166205917",
                    ["scarab"] = "rbxassetid://137137517627492",
                    ["defender"] = "rbxassetid://131690429591874",
                    ["cactus"] = "rbxassetid://104436517801089",
                    ["oasis"] = "rbxassetid://120283205213823",
                    ["berserker"] = "rbxassetid://90258047545241",
                    ["sword_shield"] = "rbxassetid://131690429591874",
                    ["airbender"] = "rbxassetid://74712750354593",
                    ["gun_blade"] = "rbxassetid://138231219644853",
                    ["frost_hammer_kit"] = "rbxassetid://11838567073",
                    ["spider_queen"] = "rbxassetid://95237509752482",
                    ["archer"] = "rbxassetid://9224796984",
                    ["axolotl"] = "rbxassetid://9155466713",
                    ["baker"] = "rbxassetid://9155463919",
                    ["barbarian"] = "rbxassetid://9166207628",
                    ["builder"] = "rbxassetid://9155463708",
                    ["necromancer"] = "rbxassetid://11343458097",
                    ["cyber"] = "rbxassetid://9507126891",
                    ["sorcerer"] = "rbxassetid://97940108361528",
                    ["bigman"] = "rbxassetid://9155467211",
                    ["spirit_assassin"] = "rbxassetid://10406002412",
                    ["farmer_cletus"] = "rbxassetid://9155466936",
                    ["ice_queen"] = "rbxassetid://9155466204",
                    ["grim_reaper"] = "rbxassetid://9155467410",
                    ["spirit_gardener"] = "rbxassetid://132108376114488",
                    ["hannah"] = "rbxassetid://10726577232",
                    ["shielder"] = "rbxassetid://9155464114",
                    ["summoner"] = "rbxassetid://18922378956",
                    ["glacial_skater"] = "rbxassetid://84628060516931",
                    ["dragon_sword"] = "rbxassetid://16215630104",
                    ["lumen"] = "rbxassetid://9630018371",
                    ["flower_bee"] = "rbxassetid://101569742252812",
                    ["jellyfish"] = "rbxassetid://18129974852",
                    ["melody"] = "rbxassetid://9155464915",
                    ["mimic"] = "rbxassetid://14783283296",
                    ["miner"] = "rbxassetid://9166208461",
                    ["nazar"] = "rbxassetid://18926951849",
                    ["seahorse"] = "rbxassetid://11902552560",
                    ["elk_master"] = "rbxassetid://15714972287",
                    ["rebellion_leader"] = "rbxassetid://18926409564",
                    ["void_hunter"] = "rbxassetid://122370766273698",
                    ["taliyah"] = "rbxassetid://13989437601",
                    ["angel"] = "rbxassetid://9166208240",
                    ["harpoon"] = "rbxassetid://18250634847",
                    ["void_walker"] = "rbxassetid://78915127961078",
                    ["spirit_summoner"] = "rbxassetid://95760990786863",
                    ["triple_shot"] = "rbxassetid://9166208149",
                    ["void_knight"] = "rbxassetid://73636326782144",
                    ["regent"] = "rbxassetid://9166208904",
                    ["vulcan"] = "rbxassetid://9155465543",
                    ["owl"] = "rbxassetid://12509401147",
                    ["dasher"] = "rbxassetid://9155467645",
                    ["disruptor"] = "rbxassetid://11596993583",
                    ["wizard"] = "rbxassetid://13353923546",
                    ["aery"] = "rbxassetid://9155463221",
                    ["agni"] = "rbxassetid://17024640133",
                    ["alchemist"] = "rbxassetid://9155462512",
                    ["spearman"] = "rbxassetid://9166207341",
                    ["beekeeper"] = "rbxassetid://9312831285",
                    ["falconer"] = "rbxassetid://17022941869",
                    ["bounty_hunter"] = "rbxassetid://9166208649",
                    ["blood_assassin"] = "rbxassetid://12520290159",
                    ["battery"] = "rbxassetid://10159166528",
                    ["steam_engineer"] = "rbxassetid://15380413567",
                    ["vesta"] = "rbxassetid://9568930198",
                    ["beast"] = "rbxassetid://9155465124",
                    ["dino_tamer"] = "rbxassetid://9872357009",
                    ["drill"] = "rbxassetid://12955100280",
                    ["elektra"] = "rbxassetid://13841413050",
                    ["fisherman"] = "rbxassetid://9166208359",
                    ["queen_bee"] = "rbxassetid://12671498918",
                    ["card"] = "rbxassetid://13841410580",
                    ["frosty"] = "rbxassetid://9166208762",
                    ["gingerbread_man"] = "rbxassetid://9155464364",
                    ["ghost_catcher"] = "rbxassetid://9224802656",
                    ["tinker"] = "rbxassetid://17025762404",
                    ["ignis"] = "rbxassetid://13835258938",
                    ["oil_man"] = "rbxassetid://9166206259",
                    ["jade"] = "rbxassetid://9166306816",
                    ["dragon_slayer"] = "rbxassetid://10982192175",
                    ["paladin"] = "rbxassetid://11202785737",
                    ["pinata"] = "rbxassetid://10011261147",
                    ["merchant"] = "rbxassetid://9872356790",
                    ["metal_detector"] = "rbxassetid://9378298061",
                    ["slime_tamer"] = "rbxassetid://15379766168",
                    ["nyoka"] = "rbxassetid://17022941410",
                    ["midnight"] = "rbxassetid://9155462763",
                    ["pyro"] = "rbxassetid://9155464770",
                    ["raven"] = "rbxassetid://9166206554",
                    ["santa"] = "rbxassetid://9166206101",
                    ["sheep_herder"] = "rbxassetid://9155465730",
                    ["smoke"] = "rbxassetid://9155462247",
                    ["spirit_catcher"] = "rbxassetid://9166207943",
                    ["star_collector"] = "rbxassetid://9872356516",
                    ["styx"] = "rbxassetid://17014536631",
                    ["block_kicker"] = "rbxassetid://15382536098",
                    ["trapper"] = "rbxassetid://9166206875",
                    ["hatter"] = "rbxassetid://12509388633",
                    ["ninja"] = "rbxassetid://15517037848",
                    ["jailor"] = "rbxassetid://11664116980",
                    ["warrior"] = "rbxassetid://9166207008",
                    ["mage"] = "rbxassetid://10982191792",
                    ["void_dragon"] = "rbxassetid://10982192753",
                    ["cat"] = "rbxassetid://15350740470",
                    ["wind_walker"] = "rbxassetid://9872355499"
                }

                local function createkitrender(plr)
                    local icon = Instance.new("ImageLabel")
                    icon.Name = "ReVapeKitRender"
                    icon.AnchorPoint = Vector2.new(1, 0.5)
                    icon.BackgroundTransparency = 1
                    icon.Position = UDim2.new(1.05, 0, 0.5, 0)
                    icon.Size = UDim2.new(1.5, 0, 1.5, 0)
                    icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
                    icon.ImageTransparency = 0.4
                    icon.ScaleType = Enum.ScaleType.Crop
                    local uar = Instance.new("UIAspectRatioConstraint")
                    uar.AspectRatio = 1
                    uar.AspectType = Enum.AspectType.FitWithinMaxSize
                    uar.DominantAxis = Enum.DominantAxis.Width
                    uar.Parent = icon
                    icon.Image = ids[plr:GetAttribute("PlayingAsKit")] or ids["none"]
                    return icon
                end

                local function removeallkitrenders()
                    for _, v in ipairs(PlayerGui:GetDescendants()) do
                        if v:IsA("ImageLabel") and v.Name == "ReVapeKitRender" then
                            v:Destroy()
                        end
                    end
                end

                local function refreshicon(icon, plr)
                    icon.Image = ids[plr:GetAttribute("PlayingAsKit")] or ids["none"]
                end

                local function findPlayer(label, container)
                    local render = container:FindFirstChild("PlayerRender", true)
                    if render and render:IsA("ImageLabel") and render.Image then
                        local userId = string.match(render.Image, "id=(%d+)")
                        if userId then
                            local plr = Players:GetPlayerByUserId(tonumber(userId))
                            if plr then return plr end
                        end
                    end
                    local text = label.Text
                    for _, plr in ipairs(Players:GetPlayers()) do
                        if plr.Name == text or plr.DisplayName == text or plr:GetAttribute("DisguiseDisplayName") == text then
                            return plr
                        end
                    end
                end

                local function handleLabel(label)
                    if not (label:IsA("TextLabel") and label.Name == "PlayerName") then return end
                    task.spawn(function()
                        local container = label.Parent
                        for _ = 1, 3 do
                            if container and container.Parent then
                                container = container.Parent
                            end
                        end
                        if not container or not container:IsA("Frame") then return end
                        local playerFound = findPlayer(label, container)
                        if not playerFound then
                            task.wait(0.5)
                            playerFound = findPlayer(label, container)
                        end
                        if not playerFound then return end
                        container.Name = playerFound.Name
                        local card = container:FindFirstChild("1") and container["1"]:FindFirstChild("MatchDraftPlayerCard")
                        if not card then return end
                        local icon = card:FindFirstChild("ReVapeKitRender")
                        if not icon then
                            icon = createkitrender(playerFound)
                            icon.Parent = card
                        end
                        task.spawn(function()
                            while container and container.Parent and KitRender.Enabled do
                                local updatedPlayer = findPlayer(label, container)
                                if updatedPlayer and updatedPlayer ~= playerFound then
                                    playerFound = updatedPlayer
                                end
                                if playerFound and icon then
                                    refreshicon(icon, playerFound)
                                end
                                task.wait(1)
                            end
                        end)
                    end)
                end

                task.spawn(function()
                    local team2 = PlayerGui:WaitForChild("MatchDraftApp")
                        :WaitForChild("DraftAppBackground")
                        :WaitForChild("BodyContainer")
                        :WaitForChild("Team2Column")

                    for _, child in ipairs(team2:GetDescendants()) do
                        handleLabel(child)
                    end

                    team2.DescendantAdded:Connect(function(child)
                        handleLabel(child)
                    end)
                end)

                KitRender.Connections = {}
            else
                if KitRender.Connections then
                    for _, connection in pairs(KitRender.Connections) do
                        connection:Disconnect()
                    end
                    KitRender.Connections = nil
                end
                
                local Players = game:GetService("Players")
                local player = Players.LocalPlayer
                local PlayerGui = player:WaitForChild("PlayerGui")
                
                for _, v in ipairs(PlayerGui:GetDescendants()) do
                    if v:IsA("ImageLabel") and v.Name == "ReVapeKitRender" then
                        v:Destroy()
                    end
                end
            end
        end,
        Tooltip = 'Shows kit icons next to player names in the match draft screen'
    })
end)

local HitBoxes = {}
run(function()
	local Mode
	local Expand
	local AutoToggle
	local objects, set = {}
	local hitboxConnections = {}
	local HitBoxesEnabled = false
	local autoHitboxEnabled = false
	local lastSwordState = false
	local hitboxCheckConnection = nil
	
	local function hasSwordEquipped()
		if not store.inventory or not store.inventory.hotbar then 
			return false 
		end
		
		local hotbarSlot = store.inventory.hotbarSlot
		if not hotbarSlot or not store.inventory.hotbar[hotbarSlot + 1] then 
			return false 
		end
		
		local currentItem = store.inventory.hotbar[hotbarSlot + 1].item
		if not currentItem then 
			return false 
		end
		
		local itemMeta = bedwars.ItemMeta[currentItem.itemType]
		local hasSword = itemMeta and itemMeta.sword ~= nil
		
		return hasSword
	end
	
	local function createHitbox(ent)
		if ent.Targetable and ent.Player then
			local success = pcall(function()
				local hitbox = Instance.new('Part')
				hitbox.Size = Vector3.new(3, 6, 3) + Vector3.one * (Expand.Value / 5)
				hitbox.Position = ent.RootPart.Position
				hitbox.CanCollide = false
				hitbox.Massless = true
				hitbox.Transparency = 1
				hitbox.Parent = ent.Character
				
				local weld = Instance.new('Motor6D')
				weld.Part0 = hitbox
				weld.Part1 = ent.RootPart
				weld.Parent = hitbox
				
				objects[ent] = hitbox
			end)
		end
	end
	
	local function removeHitbox(ent)
		if objects[ent] then
			objects[ent]:Destroy()
			objects[ent] = nil
		end
	end
	
	local function applySwordHitbox(enabled)
		if not bedwars or not bedwars.SwordController then
			return false
		end
		
		if not bedwars.SwordController.swingSwordInRegion then
			return false
		end
		
		local success, errorMsg = pcall(function()
			if enabled then
				debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (Expand.Value / 3))
				set = true
			else
				debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, 3.8)
				set = nil
			end
		end)
		
		return success
	end
	
	local function updatePlayerHitboxes()
		for ent, part in pairs(objects) do
			if part and part.Parent then
				part.Size = Vector3.new(3, 6, 3) + Vector3.one * (Expand.Value / 5)
			end
		end
	end
	
	local function setupAutoHitboxToggle()
		if hitboxCheckConnection then
			hitboxCheckConnection:Disconnect()
			hitboxCheckConnection = nil
		end
		
		hitboxCheckConnection = runService.Heartbeat:Connect(function()
			if not HitBoxes.Enabled or not autoHitboxEnabled or Mode.Value == 'Sword' then 
				return 
			end
			
			local hasSword = hasSwordEquipped()
			
			if hasSword ~= lastSwordState then
				if hasSword then
					if not HitBoxesEnabled then
						for _, conn in hitboxConnections do
							conn:Disconnect()
						end
						hitboxConnections = {}
						table.insert(hitboxConnections, entitylib.Events.EntityAdded:Connect(createHitbox))
						table.insert(hitboxConnections, entitylib.Events.EntityRemoving:Connect(removeHitbox))
						for _, ent in entitylib.List do
							createHitbox(ent)
						end
						HitBoxesEnabled = true
						notif('Auto HitBox', 'HitBoxes auto-enabled (Sword equipped)', 2, 'normal')
					end
				else
					if HitBoxesEnabled then
						for _, part in objects do
							part:Destroy()
						end
						table.clear(objects)
						for _, conn in hitboxConnections do
							conn:Disconnect()
						end
						table.clear(hitboxConnections)
						HitBoxesEnabled = false
						notif('Auto HitBox', 'HitBoxes auto-disabled (No sword)', 2, 'normal')
					end
				end
				lastSwordState = hasSword
			end
		end)
		
		lastSwordState = hasSwordEquipped()
		
		if lastSwordState and not HitBoxesEnabled and Mode.Value == 'Player' then
			for _, conn in hitboxConnections do
				conn:Disconnect()
			end
			hitboxConnections = {}
			table.insert(hitboxConnections, entitylib.Events.EntityAdded:Connect(createHitbox))
			table.insert(hitboxConnections, entitylib.Events.EntityRemoving:Connect(removeHitbox))
			for _, ent in entitylib.List do
				createHitbox(ent)
			end
			HitBoxesEnabled = true
			notif('Auto HitBox', 'HitBoxes auto-enabled (Sword equipped)', 2, 'normal')
		elseif not lastSwordState and HitBoxesEnabled and Mode.Value == 'Player' then
			for _, part in objects do
				part:Destroy()
			end
			table.clear(objects)
			for _, conn in hitboxConnections do
				conn:Disconnect()
			end
			table.clear(hitboxConnections)
			HitBoxesEnabled = false
			notif('Auto HitBox', 'HitBoxes auto-disabled (No sword)', 2, 'normal')
		end
	end
	
	HitBoxes = vape.Categories.Blatant:CreateModule({
		Name = 'HitBoxes',
		Function = function(callback)
			if callback then
				if Mode.Value == 'Sword' then
					local success = applySwordHitbox(true)
					if success then
						HitBoxesEnabled = true
						if autoHitboxEnabled then
							notif('HitBoxes', 'Auto toggle only works in Player mode', 3, 'alert')
						end
					else
						notif('HitBoxes', 'Failed to enable sword hitboxes', 3, 'alert')
						HitBoxes:Toggle()
					end
				else
					if autoHitboxEnabled then
						setupAutoHitboxToggle()
					else
						HitBoxes:Clean(entitylib.Events.EntityAdded:Connect(createHitbox))
						HitBoxes:Clean(entitylib.Events.EntityRemoving:Connect(function(ent)
							removeHitbox(ent)
						end))
						for _, ent in entitylib.List do
							createHitbox(ent)
						end
						HitBoxesEnabled = true
					end
				end
			else
				if set then
					applySwordHitbox(false)
				end
				for _, part in objects do
					part:Destroy()
				end
				table.clear(objects)
				for _, conn in hitboxConnections do
					conn:Disconnect()
				end
				table.clear(hitboxConnections)
				if hitboxCheckConnection then
					hitboxCheckConnection:Disconnect()
					hitboxCheckConnection = nil
				end
				HitBoxesEnabled = false
				autoHitboxEnabled = false
				lastSwordState = false
			end
		end,
		Tooltip = 'Expands attack hitbox'
	})
	
	Mode = HitBoxes:CreateDropdown({
		Name = 'Mode',
		List = {'Sword', 'Player'},
		Function = function()
			if HitBoxes.Enabled then
				HitBoxes:Toggle()
				HitBoxes:Toggle()
			end
			if autoHitboxEnabled and Mode.Value == 'Sword' then
				notif('HitBoxes', 'Auto toggle only works in Player mode', 3, 'alert')
			end
		end,
		Tooltip = 'Sword - Increases the range around you to hit entities\nPlayer - Increases the players hitbox'
	})
	
	Expand = HitBoxes:CreateSlider({
		Name = 'Expand amount',
		Min = 0,
		Max = 50, 
		Default = 14.4,
		Decimal = 10,
		Function = function(val)
			if HitBoxes.Enabled then
				if Mode.Value == 'Sword' then
					applySwordHitbox(true)
				else
					updatePlayerHitboxes()
				end
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	
	AutoToggle = HitBoxes:CreateToggle({
		Name = 'Auto Toggle',
		Function = function(callback)
			autoHitboxEnabled = callback
			if callback and HitBoxes.Enabled then
				if Mode.Value == 'Sword' then
					notif('HitBoxes', 'Auto toggle only works in Player mode', 3, 'alert')
					AutoToggle:Toggle()
					return
				end
				setupAutoHitboxToggle()
			elseif HitBoxes.Enabled and Mode.Value == 'Player' then
				for _, part in objects do
					part:Destroy()
				end
				table.clear(objects)
				for _, conn in hitboxConnections do
					conn:Disconnect()
				end
				table.clear(hitboxConnections)
				
				HitBoxes:Clean(entitylib.Events.EntityAdded:Connect(createHitbox))
				HitBoxes:Clean(entitylib.Events.EntityRemoving:Connect(function(ent)
					removeHitbox(ent)
				end))
				for _, ent in entitylib.List do
					createHitbox(ent)
				end
				HitBoxesEnabled = true
			end
		end,
		Tooltip = 'Automatically turns hitboxes on/off when you equip/unequip swords (Player mode only)'
	})
end)


local Attacking
run(function()
    local Killaura
    local Targets
    local Sort
    local SwingRange
    local AttackRange
    local RangeCircle
    local RangeCirclePart
    local UpdateRate
    local AngleSlider
    local MaxTargets
    local Mouse
    local Swing
    local GUI
    local BoxSwingColor
    local BoxAttackColor
    local ParticleTexture
    local ParticleColor1
    local ParticleColor2
    local ParticleSize
    local Face
    local Animation
    local AnimationMode
    local AnimationSpeed
    local AnimationTween
    local Limit
	local SwingAngleSlider
    local SyncHits
    local lastAttackTime = 0
    local lastManualSwing = 0
    local lastSwingServerTime = 0
    local lastSwingServerTimeDelta = 0
    local SwingTime
    local SwingTimeSlider
    local swingCooldown = 0
	local ContinueSwinging
	local ContinueSwingTime
	local lastTargetTime = 0
	local continueSwingCount = 0
    local Particles, Boxes = {}, {}
    local anims, AnimDelay, AnimTween, armC0 = vape.Libraries.auraanims, tick()
    local AttackRemote
    task.spawn(function()
        AttackRemote = bedwars.Client:Get(remotes.AttackEntity)
    end)

    local function optimizeHitData(selfpos, targetpos, delta)
        local direction = (targetpos - selfpos).Unit
        local distance = (selfpos - targetpos).Magnitude
        
        local optimizedSelfPos = selfpos
        local optimizedTargetPos = targetpos
        
        if distance > 18 then
            optimizedSelfPos = selfpos + (direction * 2.2)
            optimizedTargetPos = targetpos - (direction * 0.5)
        elseif distance > 14.4 then
            optimizedSelfPos = selfpos + (direction * 1.8)
            optimizedTargetPos = targetpos - (direction * 0.3)
        elseif distance > 10 then
            optimizedSelfPos = selfpos + (direction * 1.2)
        else
            optimizedSelfPos = selfpos + (direction * 0.6)
        end
        
        optimizedSelfPos = optimizedSelfPos + Vector3.new(0, 0.8, 0)
        optimizedTargetPos = optimizedTargetPos + Vector3.new(0, 1.2, 0)
        
        return optimizedSelfPos, optimizedTargetPos, direction
    end

    local function getOptimizedAttackTiming()
        local currentTime = tick()
        local baseDelay = 0.11 
        
        if currentTime - lastAttackTime < baseDelay then
            return false
        end
        
        return true
    end

	local function FireAttackRemote(attackTable, ...)
		if not AttackRemote then return end

		local suc, plr = pcall(function()
			return playersService:GetPlayerFromCharacter(attackTable.entityInstance)
		end)

		local selfpos = attackTable.validate.selfPosition.value
		local targetpos = attackTable.validate.targetPosition.value
		local actualDistance = (selfpos - targetpos).Magnitude

		store.attackReach = (actualDistance * 100) // 1 / 100
		store.attackReachUpdate = tick() + 1

		if actualDistance > 14.4 and actualDistance <= 30 then
			local direction = (targetpos - selfpos).Unit
			
			local moveDistance = math.min(actualDistance - 14.3, 8) 
			attackTable.validate.selfPosition.value = selfpos + (direction * moveDistance)
			
			local pullDistance = math.min(actualDistance - 14.3, 4)
			attackTable.validate.targetPosition.value = targetpos - (direction * pullDistance)
			
			attackTable.validate.raycast = attackTable.validate.raycast or {}
			attackTable.validate.raycast.cameraPosition = attackTable.validate.raycast.cameraPosition or {}
			attackTable.validate.raycast.cursorDirection = attackTable.validate.raycast.cursorDirection or {}
			
			local extendedOrigin = selfpos + (direction * math.min(actualDistance - 12, 15))
			attackTable.validate.raycast.cameraPosition.value = extendedOrigin
			attackTable.validate.raycast.cursorDirection.value = direction
			
			attackTable.validate.targetPosition = attackTable.validate.targetPosition or {value = targetpos}
			attackTable.validate.selfPosition = attackTable.validate.selfPosition or {value = selfpos}
		end

		if suc and plr then
			if not select(2, whitelist:get(plr)) then return end
		end

		return AttackRemote:SendToServer(attackTable, ...)
	end

    local lastSwingServerTime = 0
    local lastSwingServerTimeDelta = 0

    local function createRangeCircle()
        local suc, err = pcall(function()
            if (not shared.CheatEngineMode) then
                RangeCirclePart = Instance.new("MeshPart")
                RangeCirclePart.MeshId = "rbxassetid://3726303797"
                if shared.RiseMode and GuiLibrary.GUICoreColor and GuiLibrary.GUICoreColorChanged then
                    RangeCirclePart.Color = GuiLibrary.GUICoreColor
                    GuiLibrary.GUICoreColorChanged.Event:Connect(function()
                        RangeCirclePart.Color = GuiLibrary.GUICoreColor
                    end)
                else
                    RangeCirclePart.Color = Color3.fromHSV(BoxSwingColor["Hue"], BoxSwingColor["Sat"], BoxSwingColor.Value)
                end
                RangeCirclePart.CanCollide = false
                RangeCirclePart.Anchored = true
                RangeCirclePart.Material = Enum.Material.Neon
                RangeCirclePart.Size = Vector3.new(SwingRange.Value * 0.7, 0.01, SwingRange.Value * 0.7)
                if Killaura.Enabled then
                    RangeCirclePart.Parent = gameCamera
                end
                RangeCirclePart:SetAttribute("gamecore_GameQueryIgnore", true)
            end
        end)
        if (not suc) then
            pcall(function()
                if RangeCirclePart then
                    RangeCirclePart:Destroy()
                    RangeCirclePart = nil
                end
                InfoNotification("Killaura - Range Visualiser Circle", "There was an error creating the circle. Disabling...", 2)
            end)
        end
    end

    local function getAttackData()
        if Mouse.Enabled then
            if not inputService:IsMouseButtonPressed(0) then return false end
        end

        if GUI.Enabled then
            if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then return false end
        end

        local sword = Limit.Enabled and store.hand or store.tools.sword
        if not sword or not sword.tool then return false end

        local meta = bedwars.ItemMeta[sword.tool.Name]
        if Limit.Enabled then
            if store.hand.toolType ~= 'sword' or bedwars.DaoController.chargingMaid then return false end
        end

        if SwingTime.Enabled then
            local swingSpeed = SwingTimeSlider.Value
            return sword, meta, (tick() - lastAttackTime) >= swingSpeed
        else
            return sword, meta, true
        end
    end
	
	local function resetSwordCooldown()
		if bedwars.SwordController then
			bedwars.SwordController.lastAttack = 0
			bedwars.SwordController.lastSwing = 0
			
			if bedwars.SwordController.lastChargedAttackTimeMap then
				for weaponName, _ in pairs(bedwars.SwordController.lastChargedAttackTimeMap) do
					bedwars.SwordController.lastChargedAttackTimeMap[weaponName] = 0
				end
			end
		end
	end

	local function shouldContinueSwinging()
		if not ContinueSwinging.Enabled then return false end
		
		local plrs = entitylib.AllPosition({
			Range = AttackRange.Value,
			Wallcheck = Targets.Walls.Enabled or nil,
			Part = 'RootPart',
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Limit = MaxTargets.Value
		})
		
		if #plrs > 0 then
			lastTargetTime = tick()
			continueSwingCount = 0
			return false
		end
		
		if lastTargetTime == 0 then
			return false
		end
		
		local timeSinceLastTarget = tick() - lastTargetTime
		local swingDuration = ContinueSwingTime.Value
		
		if timeSinceLastTarget <= swingDuration then
			return true
		end
		
		continueSwingCount = 0
		return false
	end

    local preserveSwordIcon = false
    local sigridcheck = false

    Killaura = vape.Categories.Blatant:CreateModule({
        Name = 'Killaura',
        Function = function(callback)
			if callback then
				lastSwingServerTime = Workspace:GetServerTimeNow()
				lastSwingServerTimeDelta = 0
				lastAttackTime = 0
				swingCooldown = 0
				resetSwordCooldown() 
				lastTargetTime = 0 
				continueSwingCount = 0

                if RangeCircle.Enabled then
                    createRangeCircle()
                end
                if inputService.TouchEnabled and not preserveSwordIcon then
                    pcall(function()
                        lplr.PlayerGui.MobileUI['2'].Visible = Limit.Enabled
                    end)
                end

                if Animation.Enabled and not (identifyexecutor and table.find({'Argon', 'Delta'}, ({identifyexecutor()})[1])) then
                    local fake = {
                        Controllers = {
                            ViewmodelController = {
                                isVisible = function()
                                    return not Attacking
                                end,
                                playAnimation = function(...)
                                    local args = {...}
                                    if not Attacking then
                                        pcall(function()
                                            bedwars.ViewmodelController:playAnimation(select(2, unpack(args)))
                                        end)
                                    end
                                end
                            }
                        }
                    }

                    task.spawn(function()
                        local started = false
                        repeat
                            if Attacking then
                                if not armC0 then
                                    armC0 = gameCamera.Viewmodel.RightHand.RightWrist.C0
                                end
                                local first = not started
                                started = true

                                if AnimationMode.Value == 'Random' then
                                    anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
                                end

                                for _, v in anims[AnimationMode.Value] do
                                    AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(first and (AnimationTween.Enabled and 0.001 or 0.1) or v.Time / AnimationSpeed.Value, Enum.EasingStyle.Linear), {
                                        C0 = armC0 * v.CFrame
                                    })
                                    AnimTween:Play()
                                    AnimTween.Completed:Wait()
                                    first = false
                                    if (not Killaura.Enabled) or (not Attacking) then break end
                                end
                            elseif started then
                                started = false
                                AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
                                    C0 = armC0
                                })
                                AnimTween:Play()
                            end

                            if not started then
                                task.wait(1 / UpdateRate.Value)
                            end
                        until (not Killaura.Enabled) or (not Animation.Enabled)
                    end)
                end

                repeat
                    pcall(function()
                        if entitylib.isAlive and entitylib.character.HumanoidRootPart then
                            TweenService:Create(RangeCirclePart, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Position = entitylib.character.HumanoidRootPart.Position - Vector3.new(0, entitylib.character.Humanoid.HipHeight, 0)}):Play()
                        end
                    end)
                    local attacked, sword, meta, canAttack = {}, getAttackData()
                    Attacking = false
                    store.KillauraTarget = nil
                    pcall(function() vapeTargetInfo.Targets.Killaura = nil end)

					local shouldSwing = shouldContinueSwinging()
					if sword and (canAttack or (shouldSwing and lastTargetTime > 0)) then
						if sigridcheck and entitylib.isAlive and lplr.Character:FindFirstChild("elk") then return end
						local isClaw = string.find(string.lower(tostring(sword and sword.itemType or "")), "summoner_claw")
						local plrs = entitylib.AllPosition({
							Range = SwingRange.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = MaxTargets.Value,
							Sort = sortmethods[Sort.Value]
						})
						
						if #plrs > 0 then
							lastTargetTime = tick()
							continueSwingCount = 0
						elseif lastTargetTime == 0 then
							lastTargetTime = 0
						end
						
						switchItem(sword.tool, 0)
						local selfpos = entitylib.character.RootPart.Position
						local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)

						if #plrs > 0 then
							for _, v in plrs do
								local delta = (v.RootPart.Position - selfpos)
								local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
								local swingAngle = SwingAngleSlider and math.rad(SwingAngleSlider.Value) or math.rad(AngleSlider.Value)
								if angle > (swingAngle / 2) then continue end

								table.insert(attacked, {
									Entity = v,
									Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor
								})
								targetinfo.Targets[v] = tick() + 1
								pcall(function()
									local plr = v
									vapeTargetInfo.Targets.Killaura = {
										Humanoid = {
											Health = (plr.Character:GetAttribute("Health") or plr.Humanoid.Health) + getShieldAttribute(plr.Character),
											MaxHealth = plr.Character:GetAttribute("MaxHealth") or plr.Humanoid.MaxHealth
										},
										Player = plr.Player
									}
								end)
								if not Attacking then
									Attacking = true
									store.KillauraTarget = v
									if not isClaw then
										if not Swing.Enabled and AnimDelay <= tick() then
											local swingSpeed = 0.25
											if SwingTime.Enabled then
												swingSpeed = math.max(SwingTimeSlider.Value, 0.11)
											elseif meta.sword.respectAttackSpeedForEffects then
												swingSpeed = meta.sword.attackSpeed
											end
											AnimDelay = tick() + swingSpeed
											bedwars.SwordController:playSwordEffect(meta, false)
											if meta.displayName:find(' Scythe') then
												bedwars.ScytheController:playLocalAnimation()
											end

											if vape.ThreadFix then
												setthreadidentity(8)
											end
										end
									end
								end

								local canHit = delta.Magnitude <= AttackRange.Value
								local extendedRangeCheck = delta.Magnitude <= (AttackRange.Value + 5) 

								if not canHit and not extendedRangeCheck then continue end

								if SyncHits.Enabled then
									local swingSpeed = SwingTime.Enabled and SwingTimeSlider.Value or (meta.sword.respectAttackSpeedForEffects and meta.sword.attackSpeed or 0.42)
									local timeSinceLastSwing = tick() - swingCooldown
									local requiredDelay = math.max(swingSpeed * 0.8, 0.1) 
									
									if timeSinceLastSwing < requiredDelay then 
										continue 
									end
								end

								local actualRoot = v.Character.PrimaryPart
								if actualRoot then
									local dir = CFrame.lookAt(selfpos, actualRoot.Position).LookVector

									local pos = selfpos
									local targetPos = actualRoot.Position

									if not SyncHits.Enabled or (tick() - swingCooldown) >= 0.1 then
										swingCooldown = tick()
									end
									lastSwingServerTimeDelta = workspace:GetServerTimeNow() - lastSwingServerTime
									lastSwingServerTime = workspace:GetServerTimeNow()

									store.attackReach = (delta.Magnitude * 100) // 1 / 100
									store.attackReachUpdate = tick() + 1

									if SwingTime.Enabled then
										lastAttackTime = tick()

										if delta.Magnitude < 14.4 and SwingTimeSlider.Value > 0.11 then
											AnimDelay = tick()
										end
									end

									if isClaw then
										KaidaController:request(v.Character)
									else
										local attackData = {
											weapon = sword.tool,
											entityInstance = v.Character,
											chargedAttack = {chargeRatio = 0},
											validate = {
												raycast = {
													cameraPosition = {value = pos},
													cursorDirection = {value = dir}
												},
												targetPosition = {value = targetPos},
												selfPosition = {value = pos}
											}
										}
										
										attackData.validate = attackData.validate or {}
										attackData.validate.raycast = attackData.validate.raycast or {}
										attackData.validate.targetPosition = attackData.validate.targetPosition or {value = targetPos}
										attackData.validate.selfPosition = attackData.validate.selfPosition or {value = pos}
										
										attackData.validate.raycast.cameraPosition = attackData.validate.raycast.cameraPosition or {value = pos}
										attackData.validate.raycast.cursorDirection = attackData.validate.raycast.cursorDirection or {value = dir}
										
										FireAttackRemote(attackData)
									end
								end
							end
						elseif shouldSwing then

							Attacking = true
							if not isClaw then
								if not Swing.Enabled and AnimDelay <= tick() then
									local swingSpeed = 0.25
									if SwingTime.Enabled then
										swingSpeed = math.max(SwingTimeSlider.Value, 0.11)
									elseif meta.sword.respectAttackSpeedForEffects then
										swingSpeed = meta.sword.attackSpeed
									end
									AnimDelay = tick() + swingSpeed
									bedwars.SwordController:playSwordEffect(meta, false)
									if meta.displayName:find(' Scythe') then
										bedwars.ScytheController:playLocalAnimation()
									end

									if vape.ThreadFix then
										setthreadidentity(8)
									end
								end
							end

							local currentSwingSpeed = SwingTime.Enabled and SwingTimeSlider.Value or (meta.sword.respectAttackSpeedForEffects and meta.sword.attackSpeed or 0.42)
							local minSwingDelay = math.max(currentSwingSpeed, 0.05)
							
							if not SyncHits.Enabled or (tick() - swingCooldown) >= minSwingDelay then
								swingCooldown = tick()
								
								local dir = entitylib.character.RootPart.CFrame.LookVector
								local pos = entitylib.character.RootPart.Position
								local targetPos = pos + dir * 10

								local attackData = {
									weapon = sword.tool,
									entityInstance = entitylib.character,
									chargedAttack = {chargeRatio = 0},
									validate = {
										raycast = {
											cameraPosition = {value = pos},
											cursorDirection = {value = dir}
										},
										targetPosition = {value = targetPos},
										selfPosition = {value = pos}
									}
								}
								
								attackData.validate = attackData.validate or {}
								attackData.validate.raycast = attackData.validate.raycast or {}
								attackData.validate.targetPosition = attackData.validate.targetPosition or {value = targetPos}
								attackData.validate.selfPosition = attackData.validate.selfPosition or {value = pos}
								
								attackData.validate.raycast.cameraPosition = attackData.validate.raycast.cameraPosition or {value = pos}
								attackData.validate.raycast.cursorDirection = attackData.validate.raycast.cursorDirection or {value = dir}
								
								FireAttackRemote(attackData)
							end
						end
					end

                    pcall(function()
                        for i, v in Boxes do
                            v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
                            if v.Adornee then
                                v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
                                v.Transparency = 1 - attacked[i].Check.Opacity
                            end
                        end

                        for i, v in Particles do
                            v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
                            v.Parent = attacked[i] and gameCamera or nil
                        end
                    end)

                    if Face.Enabled and attacked[1] then
                        local vec = attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
                        entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(vec.X, entitylib.character.RootPart.Position.Y + 0.001, vec.Z))
                    end
                    pcall(function() if RangeCirclePart ~= nil then RangeCirclePart.Parent = gameCamera end end)

                    task.wait(1 / UpdateRate.Value)
                until not Killaura.Enabled
			else
				lastTargetTime = 0
				continueSwingCount = 0
				
				store.KillauraTarget = nil
				for _, v in Boxes do
					v.Adornee = nil
				end
				for _, v in Particles do
					v.Parent = nil
				end
				if inputService.TouchEnabled then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = true
					end)
				end
				Attacking = false
				if armC0 then
					AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
						C0 = armC0
					})
					AnimTween:Play()
				end
				if RangeCirclePart ~= nil then RangeCirclePart:Destroy() end
			end
        end,
        Tooltip = 'Attack players around you\nwithout aiming at them.'
    })

    pcall(function()
        local PSI = Killaura:CreateToggle({
            Name = 'Preserve Sword Icon',
            Function = function(callback)
                preserveSwordIcon = callback
            end,
            Default = true
        })
        PSI.Object.Visible = inputService.TouchEnabled
    end)

    Targets = Killaura:CreateTargets({
        Players = true,
        NPCs = true
    })
    local methods = {'Damage', 'Distance'}
    for i in sortmethods do
        if not table.find(methods, i) then
            table.insert(methods, i)
        end
    end
	SwingRange = Killaura:CreateSlider({
		Name = 'Swing range',
		Min = 1,
		Max = 40, 
		Default = 22, 
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 35,
		Default = 22, 
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
    RangeCircle = Killaura:CreateToggle({
        Name = "Range Visualiser",
        Function = function(call)
            if call then
                createRangeCircle()
            else
                if RangeCirclePart then
                    RangeCirclePart:Destroy()
                    RangeCirclePart = nil
                end
            end
        end
    })
    AngleSlider = Killaura:CreateSlider({
        Name = 'Max angle',
        Min = 1,
        Max = 360,
        Default = 360
    })
	SwingAngleSlider = Killaura:CreateSlider({
		Name = 'Swing angle',
		Min = 1,
		Max = 360,
		Default = 360
	})
    UpdateRate = Killaura:CreateSlider({
        Name = 'Update rate',
        Min = 1,
        Max = 120,
        Default = 60,
        Suffix = 'hz'
    })
    MaxTargets = Killaura:CreateSlider({
        Name = 'Max targets',
        Min = 1,
        Max = 5,
        Default = 5
    })
    Sort = Killaura:CreateDropdown({
        Name = 'Target Mode',
        List = methods
    })
    Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
    Swing = Killaura:CreateToggle({Name = 'No Swing'})
    GUI = Killaura:CreateToggle({Name = 'GUI check'})
    SwingTime = Killaura:CreateToggle({
        Name = 'Custom Swing Time',
        Function = function(callback)
            SwingTimeSlider.Object.Visible = callback
        end
    })
    SwingTimeSlider = Killaura:CreateSlider({
        Name = 'Swing Time',
        Min = 0,
        Max = 1,
        Default = 0.42,
        Decimal = 100,
        Visible = false
    })
	ContinueSwinging = Killaura:CreateToggle({
		Name = 'Continue Swinging',
		Tooltip = 'Swing X times after losing target (based on swing speed)',
		Function = function(callback)
			if ContinueSwingTime then
				ContinueSwingTime.Object.Visible = callback
			end
		end
	})
	ContinueSwingTime = Killaura:CreateSlider({
		Name = 'Swing Duration',
		Min = 0,  
		Max = 5,  
		Default = 1,
		Decimal = 10,
		Suffix = 's',
		Visible = false
	})
    SyncHits = Killaura:CreateToggle({
        Name = 'Sync Hits',
        Tooltip = 'Waits for sword animation before attacking'
    })
    Killaura:CreateToggle({
        Name = 'Show target',
        Function = function(callback)
            BoxSwingColor.Object.Visible = callback
            BoxAttackColor.Object.Visible = callback
            if callback then
                for i = 1, 10 do
                    local box = Instance.new('BoxHandleAdornment')
                    box.Adornee = nil
                    box.AlwaysOnTop = true
                    box.Size = Vector3.new(3, 5, 3)
                    box.CFrame = CFrame.new(0, -0.5, 0)
                    box.ZIndex = 0
                    box.Parent = vape.gui
                    Boxes[i] = box
                end
            else
                for _, v in Boxes do
                    v:Destroy()
                end
                table.clear(Boxes)
            end
        end
    })
    BoxSwingColor = Killaura:CreateColorSlider({
        Name = 'Target Color',
        Darker = true,
        DefaultHue = 0.6,
        DefaultOpacity = 0.5,
        Visible = false,
        Function = function(hue, sat, val)
            if Killaura.Enabled and RangeCirclePart ~= nil then
                RangeCirclePart.Color = Color3.fromHSV(hue, sat, val)
            end
        end
    })
    BoxAttackColor = Killaura:CreateColorSlider({
        Name = 'Attack Color',
        Darker = true,
        DefaultOpacity = 0.5,
        Visible = false
    })
    Killaura:CreateToggle({
        Name = 'Target particles',
        Function = function(callback)
            ParticleTexture.Object.Visible = callback
            ParticleColor1.Object.Visible = callback
            ParticleColor2.Object.Visible = callback
            ParticleSize.Object.Visible = callback
            if callback then
                for i = 1, 10 do
                    local part = Instance.new('Part')
                    part.Size = Vector3.new(2, 4, 2)
                    part.Anchored = true
                    part.CanCollide = false
                    part.Transparency = 1
                    part.CanQuery = false
                    part.Parent = Killaura.Enabled and gameCamera or nil
                    local particles = Instance.new('ParticleEmitter')
                    particles.Brightness = 1.5
                    particles.Size = NumberSequence.new(ParticleSize.Value)
                    particles.Shape = Enum.ParticleEmitterShape.Sphere
                    particles.Texture = ParticleTexture.Value
                    particles.Transparency = NumberSequence.new(0)
                    particles.Lifetime = NumberRange.new(0.4)
                    particles.Speed = NumberRange.new(16)
                    particles.Rate = 128
                    particles.Drag = 16
                    particles.ShapePartial = 1
                    particles.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
                        ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
                    })
                    particles.Parent = part
                    Particles[i] = part
                end
            else
                for _, v in Particles do
                    v:Destroy()
                end
                table.clear(Particles)
            end
        end
    })
    ParticleTexture = Killaura:CreateTextBox({
        Name = 'Texture',
        Default = 'rbxassetid://14736249347',
        Function = function()
            for _, v in Particles do
                v.ParticleEmitter.Texture = ParticleTexture.Value
            end
        end,
        Darker = true,
        Visible = false
    })
    ParticleColor1 = Killaura:CreateColorSlider({
        Name = 'Color Begin',
        Function = function(hue, sat, val)
            for _, v in Particles do
                v.ParticleEmitter.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
                    ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
                })
            end
        end,
        Darker = true,
        Visible = false
    })
    ParticleColor2 = Killaura:CreateColorSlider({
        Name = 'Color End',
        Function = function(hue, sat, val)
            for _, v in Particles do
                v.ParticleEmitter.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
                    ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
                })
            end
        end,
        Darker = true,
        Visible = false
    })
    ParticleSize = Killaura:CreateSlider({
        Name = 'Size',
        Min = 0,
        Max = 1,
        Default = 0.2,
        Decimal = 100,
        Function = function(val)
            for _, v in Particles do
                v.ParticleEmitter.Size = NumberSequence.new(val)
            end
        end,
        Darker = true,
        Visible = false
    })
    Face = Killaura:CreateToggle({Name = 'Face target'})
    Animation = Killaura:CreateToggle({
        Name = 'Custom Animation',
        Function = function(callback)
            AnimationMode.Object.Visible = callback
            AnimationTween.Object.Visible = callback
            AnimationSpeed.Object.Visible = callback
            if Killaura.Enabled then
                Killaura:Toggle()
                Killaura:Toggle()
            end
        end
    })
    local animnames = {}
    for i in anims do
        table.insert(animnames, i)
    end
    AnimationMode = Killaura:CreateDropdown({
        Name = 'Animation Mode',
        List = animnames,
        Darker = true,
        Visible = false
    })
    AnimationSpeed = Killaura:CreateSlider({
        Name = 'Animation Speed',
        Min = 0,
        Max = 2,
        Default = 1,
        Decimal = 10,
        Darker = true,
        Visible = false
    })
    AnimationTween = Killaura:CreateToggle({
        Name = 'No Tween',
        Darker = true,
        Visible = false
    })
    Limit = Killaura:CreateToggle({
        Name = 'Limit to items',
        Function = function(callback)
            if inputService.TouchEnabled and Killaura.Enabled then
                pcall(function()
                    lplr.PlayerGui.MobileUI['2'].Visible = callback
                end)
            end
        end,
        Tooltip = 'Only attacks when the sword is held'
    })
    Killaura:CreateToggle({
        Name = "Sigrid Check",
        Default = false,
        Function = function(call)
            sigridcheck = call
        end
    })
end)

run(function()
    local PromptButtonHoldBegan = nil
    local ProximityPromptService = cloneref(game:GetService('ProximityPromptService'))

    local InstantPP = vape.Categories.Utility:CreateModule({
        Name = 'InstantPP',
        Function = function(callback)
            if callback then
                if fireproximityprompt then
                    PromptButtonHoldBegan = ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
                        fireproximityprompt(prompt)
                    end)
                else
                    errorNotification('InstantPP', 'Your exploit does not support this command (missing fireproximityprompt)', 5)
                    InstantPP:Toggle()
                end
            else
                if PromptButtonHoldBegan ~= nil then
                    PromptButtonHoldBegan:Disconnect()
                    PromptButtonHoldBegan = nil
                end
            end
        end,
        Tooltip = 'Instantly activates proximity prompts.'
    })
end)

run(function()
	local ProjectileAimbot
	local TargetPart
	local Targets
	local FOV
	local Range
	local OtherProjectiles
	local Blacklist
	local TargetVisualiser

	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	rayCheck.FilterDescendantsInstances = {workspace:FindFirstChild('Map') or workspace}
	local oldCalculateImportantLaunchValues = nil
	
	local selectedTarget = nil
	local targetOutline = nil
	local hovering = false
	local CoreConnections = {}
	
	local UserInputService = game:GetService("UserInputService")
	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	local function updateOutline(target)
		if targetOutline then
			targetOutline:Destroy()
			targetOutline = nil
		end
		if target and TargetVisualiser.Enabled then
			targetOutline = Instance.new("Highlight")
			targetOutline.FillTransparency = 1
			targetOutline.OutlineColor = Color3.fromRGB(255, 0, 0)
			targetOutline.OutlineTransparency = 0
			targetOutline.Adornee = target.Character
			targetOutline.Parent = target.Character
		end
	end

	local function handlePlayerSelection()
		local mouse = lplr:GetMouse()
		local function selectTarget(target)
			if not target then return end
			if target and target.Parent then
				local plr = playersService:GetPlayerFromCharacter(target.Parent)
				if plr then
					if selectedTarget == plr then
						selectedTarget = nil
						updateOutline(nil)
					else
						selectedTarget = plr
						updateOutline(plr)
					end
				end
			end
		end
		
		local con
		if isMobile then
			con = UserInputService.TouchTapInWorld:Connect(function(touchPos)
				if not hovering then updateOutline(nil); return end
				if not ProjectileAimbot.Enabled then pcall(function() con:Disconnect() end); updateOutline(nil); return end
				local ray = workspace.CurrentCamera:ScreenPointToRay(touchPos.X, touchPos.Y)
				local result = workspace:Raycast(ray.Origin, ray.Direction * 1000)
				if result and result.Instance then
					selectTarget(result.Instance)
				end
			end)
			table.insert(CoreConnections, con)
		end
	end

	ProjectileAimbot = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAimbot',
		Function = function(callback)
			if callback then
				handlePlayerSelection()
				
				oldCalculateImportantLaunchValues = bedwars.ProjectileController.calculateImportantLaunchValues
				bedwars.ProjectileController.calculateImportantLaunchValues = function(...)	
					hovering = true
					local self, projmeta, worldmeta, origin, shootpos = ...
					local originPos = entitylib.isAlive and (shootpos or entitylib.character.RootPart.Position) or Vector3.zero
					
					local plr
					if selectedTarget and selectedTarget.Character and (selectedTarget.Character.PrimaryPart.Position - originPos).Magnitude <= Range.Value then
						plr = selectedTarget
					else
						plr = entitylib.EntityMouse({
							Part = TargetPart.Value,
							Range = FOV.Value,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled,
							Origin = originPos
						})
					end
					updateOutline(plr)
					
					if plr and plr.Character and plr[TargetPart.Value] and (plr[TargetPart.Value].Position - originPos).Magnitude <= Range.Value then
						local pos = shootpos or (self.getLaunchPosition and self:getLaunchPosition(origin) or origin)
						if not pos then
							return oldCalculateImportantLaunchValues(...)
						end

						if (not OtherProjectiles.Enabled) and not projmeta.projectile:find('arrow') then
							return oldCalculateImportantLaunchValues(...)
						end

						if table.find(Blacklist.ListEnabled, projmeta.projectile) then
							return oldCalculateImportantLaunchValues(...)
						end

						local meta = projmeta:getProjectileMeta() or {}
						local lifetime = (worldmeta and meta.predictionLifetimeSec or meta.lifetimeSec or 3)
						local gravity = (meta.gravitationalAcceleration or 196.2) * projmeta.gravityMultiplier
						local projSpeed = (meta.launchVelocity or 100)
						local offsetpos = pos + (projmeta.projectile == 'owl_projectile' and Vector3.zero or projmeta.fromPositionOffset)
						local balloons = plr.Character:GetAttribute('InflatedBalloons')
						local playerGravity = workspace.Gravity

						if balloons and balloons > 0 then
							local gravityMultiplier = 1 - (balloons * 0.05)
							playerGravity = workspace.Gravity * math.max(gravityMultiplier, 0.7)
						end

						if plr.Character.PrimaryPart and plr.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
							playerGravity = 6
						end

						if plr.Player and plr.Player:GetAttribute('IsOwlTarget') then
							for _, owl in collectionService:GetTagged('Owl') do
								if owl:GetAttribute('Target') == plr.Player.UserId and owl:GetAttribute('Status') == 2 then
									playerGravity = 0
									break
								end
							end
						end

						if store.hand and store.hand.tool then
							if store.hand.tool.Name:find("spellbook") then
								local targetPos = plr.RootPart.Position
								local selfPos = lplr.Character.PrimaryPart.Position
								local expectedTime = (selfPos - targetPos).Magnitude / 160
								targetPos = targetPos + (plr.RootPart.Velocity * expectedTime)
								return {
									initialVelocity = (targetPos - selfPos).Unit * 160,
									positionFrom = offsetpos,
									deltaT = 2,
									gravitationalAcceleration = 1,
									drawDurationSeconds = 5
								}
							elseif store.hand.tool.Name:find("chakram") then
								local targetPos = plr.RootPart.Position
								local selfPos = lplr.Character.PrimaryPart.Position
								local expectedTime = (selfPos - targetPos).Magnitude / 80
								targetPos = targetPos + (plr.RootPart.Velocity * expectedTime)
								return {
									initialVelocity = (targetPos - selfPos).Unit * 80,
									positionFrom = offsetpos,
									deltaT = 2,
									gravitationalAcceleration = 1,
									drawDurationSeconds = 5
								}
							end
						end
						
						local rawLook = CFrame.new(offsetpos, plr[TargetPart.Value].Position)
						local distance = (plr[TargetPart.Value].Position - offsetpos).Magnitude
						
						local predictedPosition = prediction.predictStrafingMovement(plr.Player, plr[TargetPart.Value], projSpeed, gravity, offsetpos)

						local newlook = prediction.smoothAim(rawLook, predictedPosition, distance)
						
						if projmeta.projectile ~= 'owl_projectile' then
							newlook = newlook * CFrame.new(
								bedwars.BowConstantsTable.RelX or 0,
								(bedwars.BowConstantsTable.RelY or 0) - 0.15, 
								bedwars.BowConstantsTable.RelZ or 0
							)
						end
						
						local targetVelocity = projmeta.projectile == 'telepearl' and Vector3.zero or plr[TargetPart.Value].Velocity
						
						local calc = prediction.SolveTrajectory(
							newlook.p, 
							projSpeed, 
							gravity, 
							predictedPosition, 
							targetVelocity, 
							playerGravity, 
							plr.HipHeight, 
							plr.Jumping and 50 or nil,
							rayCheck
						)
						
						if calc then
							local finalDirection = (calc - newlook.p).Unit
							local angleFromHorizontal = math.acos(math.clamp(finalDirection:Dot(Vector3.new(0, 1, 0)), -1, 1))
							
							local minAngle = math.rad(1)
							local maxAngle = math.rad(179)
							
							if angleFromHorizontal > minAngle and angleFromHorizontal < maxAngle then
								targetinfo.Targets[plr] = tick() + 1
								return {
									initialVelocity = finalDirection * projSpeed,
									positionFrom = offsetpos,
									deltaT = lifetime,
									gravitationalAcceleration = gravity,
									drawDurationSeconds = 5
								}
							end
						end
					end

					hovering = false
					return oldCalculateImportantLaunchValues(...)
				end
			else
				if bedwars.ProjectileController and bedwars.ProjectileController.calculateImportantLaunchValues then
					bedwars.ProjectileController.calculateImportantLaunchValues = oldCalculateImportantLaunchValues
				end
				if targetOutline then
					targetOutline:Destroy()
					targetOutline = nil
				end
				selectedTarget = nil
				for i,v in pairs(CoreConnections) do
					pcall(function() v:Disconnect() end)
				end
				table.clear(CoreConnections)
			end
		end,
		Tooltip = 'Silently adjusts your aim towards the enemy. Click a player to lock onto them (red outline).'
	})
	
	Targets = ProjectileAimbot:CreateTargets({
		Players = true,
		Walls = true
	})
	TargetPart = ProjectileAimbot:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head'}
	})
	FOV = ProjectileAimbot:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 1000
	})
	Range = ProjectileAimbot:CreateSlider({
		Name = 'Range',
		Min = 10,
		Max = 500,
		Default = 100,
		Tooltip = 'Maximum distance for target locking'
	})
	TargetVisualiser = ProjectileAimbot:CreateToggle({Name = "Target Visualiser", Default = true})
	OtherProjectiles = ProjectileAimbot:CreateToggle({
		Name = 'Other Projectiles',
		Default = true,
		Function = function(call)
			if Blacklist then
				Blacklist.Object.Visible = call
			end
		end
	})
	Blacklist = ProjectileAimbot:CreateTextList({
		Name = 'Blacklist',
		Darker = true,
		Default = {'telepearl'}
	})
end)
	
local function isFirstPerson()
	if not (lplr.Character and lplr.Character:FindFirstChild("Head")) then return false end
	return (lplr.Character.Head.Position - gameCamera.CFrame.Position).Magnitude < 2
end

run(function()
	local shooting, old = false
	local AutoShootInterval
	local AutoShootSwitchSpeed
	local AutoShootRange
	local AutoShootFOV
	local lastAutoShootTime = 0
	local autoShootEnabled = false
	local KillauraTargetCheck
	local FirstPersonCheck
	
	_G.autoShootLock = _G.autoShootLock or false
	
	local VirtualInputManager = game:GetService("VirtualInputManager")
	
	local function leftClick()
		pcall(function()
			VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
			task.wait(0.05)
			VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
		end)
	end
	
	local function getBows()
		local bows = {}
		for i, v in store.inventory.hotbar do
			if v.item and v.item.itemType then
				local itemMeta = bedwars.ItemMeta[v.item.itemType]
				if itemMeta and itemMeta.projectileSource then
					local projectileSource = itemMeta.projectileSource
					if projectileSource.ammoItemTypes and table.find(projectileSource.ammoItemTypes, 'arrow') then
						table.insert(bows, i - 1)
					end
				end
			end
		end
		return bows
	end
	
	local function getSwordSlot()
		for i, v in store.inventory.hotbar do
			if v.item and bedwars.ItemMeta[v.item.itemType] then
				local meta = bedwars.ItemMeta[v.item.itemType]
				if meta.sword then
					return i - 1
				end
			end
		end
		return nil
	end
	
	local function hasValidTarget()
		if KillauraTargetCheck.Enabled then
			return store.KillauraTarget ~= nil
		else
			if not entitylib.isAlive then return false end
			
			local myPos = entitylib.character.RootPart.Position
			local myLook = entitylib.character.RootPart.CFrame.LookVector
			
			for _, entity in entitylib.List do
				if entity.Player == lplr then continue end
				if not entity.Character then continue end
				if not entity.RootPart then continue end
				
				if entity.Player then
					if lplr:GetAttribute('Team') == entity.Player:GetAttribute('Team') then
						continue
					end
				else
					if not entity.Targetable then
						continue
					end
				end
				
				local distance = (entity.RootPart.Position - myPos).Magnitude
				if distance > AutoShootRange.Value then continue end
				
				local toTarget = (entity.RootPart.Position - myPos).Unit
				local dot = myLook:Dot(toTarget)
				local angle = math.acos(dot)
				local fovRad = math.rad(AutoShootFOV.Value)
				
				if angle <= fovRad then
					return true
				end
			end
			
			return false
		end
	end
	
	local AutoShoot = vape.Categories.Utility:CreateModule({
		Name = 'AutoShoot',
		Function = function(callback)
			if callback then
				autoShootEnabled = true
				old = bedwars.ProjectileController.createLocalProjectile
				bedwars.ProjectileController.createLocalProjectile = function(...)
					local source, data, proj = ...
					if source and proj and (proj == 'arrow' or bedwars.ProjectileMeta[proj] and bedwars.ProjectileMeta[proj].combat) and not _G.autoShootLock then
						task.spawn(function()
							if FirstPersonCheck.Enabled and not isFirstPerson() then
								return
							end
							
							if KillauraTargetCheck.Enabled then
								if not store.KillauraTarget then
									return
								end
							else
								if not hasValidTarget() then
									return
								end
							end
							
							local bows = getBows()
							if #bows > 0 then
								_G.autoShootLock = true
								task.wait(0.15)
								local selected = store.inventory.hotbarSlot
								for _, v in bows do
									if hotbarSwitch(v) then
										task.wait(0.05)
										leftClick()
										task.wait(0.05)
									end
								end
								hotbarSwitch(selected)
								_G.autoShootLock = false
							end
						end)
					end
					return old(...)
				end
				
				task.spawn(function()
					repeat
						task.wait(0.1)
						if autoShootEnabled and not _G.autoShootLock then
							if FirstPersonCheck.Enabled and not isFirstPerson() then
								continue
							end
							
							if KillauraTargetCheck.Enabled then
								if not store.KillauraTarget then
									continue
								end
							else
								if not hasValidTarget() then
									continue
								end
							end
							
							local currentTime = tick()
							if (currentTime - lastAutoShootTime) >= AutoShootInterval.Value then
								local bows = getBows()
								local swordSlot = getSwordSlot()
								
								if #bows > 0 then
									_G.autoShootLock = true
									lastAutoShootTime = currentTime
									local originalSlot = store.inventory.hotbarSlot
									
									for _, bowSlot in bows do
										if hotbarSwitch(bowSlot) then
											task.wait(AutoShootSwitchSpeed.Value)
											leftClick()
											task.wait(0.05)
										end
									end
									
									if swordSlot then
										hotbarSwitch(swordSlot)
									else
										hotbarSwitch(originalSlot)
									end
									
									_G.autoShootLock = false
								end
							end
						end
					until not autoShootEnabled
				end)
			else
				autoShootEnabled = false
				if old then
					bedwars.ProjectileController.createLocalProjectile = old
				end
				_G.autoShootLock = false
			end
		end,
		Tooltip = 'Automatically switches to bows and shoots them'
	})
	
	AutoShootInterval = AutoShoot:CreateSlider({
		Name = 'Shoot Interval',
		Min = 0.1,
		Max = 3,
		Default = 0.5,
		Decimal = 10,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end,
		Tooltip = 'How often to auto-shoot bows'
	})
	
	AutoShootSwitchSpeed = AutoShoot:CreateSlider({
		Name = 'Switch Delay',
		Min = 0,
		Max = 0.2,
		Default = 0.05,
		Decimal = 100,
		Suffix = 's',
		Tooltip = 'Delay between switching and shooting (lower = faster)'
	})
	
	AutoShootRange = AutoShoot:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 20,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'Maximum range to auto-shoot'
	})
	
	AutoShootFOV = AutoShoot:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 180,
		Default = 90,
		Tooltip = 'Field of view for target detection (1-180 degrees)'
	})
	
	KillauraTargetCheck = AutoShoot:CreateToggle({
		Name = 'Require Killaura Target',
		Default = false,
		Tooltip = 'Only auto-shoot when Killaura has a target (overrides Range/FOV)'
	})
	
	FirstPersonCheck = AutoShoot:CreateToggle({
		Name = 'First Person Only',
		Default = false,
		Tooltip = 'Only works in first person mode'
	})
end)

run(function()
	local AutoGloopInterval
	local AutoGloopSwitchSpeed
	local AutoGloopRange
	local AutoGloopFOV
	local lastAutoGloopTime = 0
	local autoGloopEnabled = false
	local GloopKillauraTargetCheck
	local FirstPersonCheck
	
	local VirtualInputManager = game:GetService("VirtualInputManager")
	
	local function leftClick()
		pcall(function()
			VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
			task.wait(0.05)
			VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
		end)
	end
	
	local function getGloopSlots()
		local gloops = {}
		for i, v in store.inventory.hotbar do
			if v.item and v.item.itemType then
				if v.item.itemType == 'glue_projectile' then
					table.insert(gloops, i - 1)
				end
			end
		end
		return gloops
	end
	
	local function getSwordSlot()
		for i, v in store.inventory.hotbar do
			if v.item and bedwars.ItemMeta[v.item.itemType] then
				local meta = bedwars.ItemMeta[v.item.itemType]
				if meta.sword then
					return i - 1
				end
			end
		end
		return nil
	end
	
	local function getClosestTargetDistance()
		if not entitylib.isAlive then return math.huge end
		
		local myPos = entitylib.character.RootPart.Position
		local myLook = entitylib.character.RootPart.CFrame.LookVector
		local closestDist = math.huge
		
		for _, entity in entitylib.List do
			if entity.Player == lplr then continue end
			if not entity.Character then continue end
			if not entity.RootPart then continue end
			
			if entity.Player then
				if lplr:GetAttribute('Team') == entity.Player:GetAttribute('Team') then
					continue
				end
			else
				if not entity.Targetable then
					continue
				end
			end
			
			local distance = (entity.RootPart.Position - myPos).Magnitude
			if distance > AutoGloopRange.Value then continue end
			
			local toTarget = (entity.RootPart.Position - myPos).Unit
			local dot = myLook:Dot(toTarget)
			local angle = math.acos(dot)
			local fovRad = math.rad(AutoGloopFOV.Value)
			
			if angle <= fovRad then
				closestDist = math.min(closestDist, distance)
			end
		end
		
		return closestDist
	end
	
	local function hasValidTarget()
		if GloopKillauraTargetCheck.Enabled then
			return store.KillauraTarget ~= nil
		else
			return getClosestTargetDistance() <= AutoGloopRange.Value
		end
	end
	
	local AutoGloop = vape.Categories.Utility:CreateModule({
		Name = 'AutoGloop',
		Function = function(callback)
			if callback then
				autoGloopEnabled = true
				
				task.spawn(function()
					repeat
						task.wait(0.1)
						if autoGloopEnabled and not _G.autoShootLock then
							if FirstPersonCheck.Enabled and not isFirstPerson() then
								continue
							end
							
							if not hasValidTarget() then
								continue
							end
							
							local closestDist = getClosestTargetDistance()
							if closestDist > 14 then
								continue
							end
							
							local currentTime = tick()
							if (currentTime - lastAutoGloopTime) >= AutoGloopInterval.Value then
								local gloops = getGloopSlots()
								local swordSlot = getSwordSlot()
								
								if #gloops > 0 then
									_G.autoShootLock = true
									lastAutoGloopTime = currentTime
									local originalSlot = store.inventory.hotbarSlot
									
									for _, gloopSlot in gloops do
										if hotbarSwitch(gloopSlot) then
											task.wait(AutoGloopSwitchSpeed.Value)
											leftClick()
											task.wait(0.05)
										end
									end
									
									if swordSlot then
										hotbarSwitch(swordSlot)
									else
										hotbarSwitch(originalSlot)
									end
									
									_G.autoShootLock = false
								end
							end
						end
					until not autoGloopEnabled
				end)
			else
				autoGloopEnabled = false
			end
		end,
		Tooltip = 'Automatically throws gloop at close range enemies (under 12 studs)'
	})
	
	AutoGloopInterval = AutoGloop:CreateSlider({
		Name = 'Throw Interval',
		Min = 0.1,
		Max = 16,
		Default = 0.8,
		Decimal = 10,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end,
		Tooltip = 'How often to throw gloop'
	})
	
	AutoGloopSwitchSpeed = AutoGloop:CreateSlider({
		Name = 'Switch Delay',
		Min = 0,
		Max = 0.2,
		Default = 0.05,
		Decimal = 100,
		Suffix = 's',
		Tooltip = 'Delay between switching and throwing (lower = faster)'
	})
	
	AutoGloopRange = AutoGloop:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 15,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'Maximum range to detect targets'
	})
	
	AutoGloopFOV = AutoGloop:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 180,
		Default = 90,
		Tooltip = 'Field of view for target detection (1-180 degrees)'
	})
	
	GloopKillauraTargetCheck = AutoGloop:CreateToggle({
		Name = 'Require Killaura Target',
		Default = false,
		Tooltip = 'Only throw gloop when Killaura has a target'
	})
	
	FirstPersonCheck = AutoGloop:CreateToggle({
		Name = 'First Person Only',
		Default = false,
		Tooltip = 'Only works in first person mode'
	})
end)

run(function()
	local AutoFireballInterval
	local AutoFireballSwitchSpeed
	local AutoFireballRange
	local AutoFireballFOV
	local lastAutoFireballTime = 0
	local autoFireballEnabled = false
	local FireballKillauraTargetCheck
	local FirstPersonCheck
	
	local VirtualInputManager = game:GetService("VirtualInputManager")
	
	local function leftClick()
		pcall(function()
			VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
			task.wait(0.05)
			VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
		end)
	end
	
	local function getFireballSlots()
		local fireballs = {}
		for i, v in store.inventory.hotbar do
			if v.item and v.item.itemType then
				if v.item.itemType == 'fireball' then
					table.insert(fireballs, i - 1)
				end
			end
		end
		return fireballs
	end
	
	local function getSwordSlot()
		for i, v in store.inventory.hotbar do
			if v.item and bedwars.ItemMeta[v.item.itemType] then
				local meta = bedwars.ItemMeta[v.item.itemType]
				if meta.sword then
					return i - 1
				end
			end
		end
		return nil
	end
	
	local function hasValidTarget()
		if FireballKillauraTargetCheck.Enabled then
			return store.KillauraTarget ~= nil
		else
			if not entitylib.isAlive then return false end
			
			local myPos = entitylib.character.RootPart.Position
			local myLook = entitylib.character.RootPart.CFrame.LookVector
			
			for _, entity in entitylib.List do
				if entity.Player == lplr then continue end
				if not entity.Character then continue end
				if not entity.RootPart then continue end
				
				if entity.Player then
					if lplr:GetAttribute('Team') == entity.Player:GetAttribute('Team') then
						continue
					end
				else
					if not entity.Targetable then
						continue
					end
				end
				
				local distance = (entity.RootPart.Position - myPos).Magnitude
				if distance > AutoFireballRange.Value then continue end
				
				local toTarget = (entity.RootPart.Position - myPos).Unit
				local dot = myLook:Dot(toTarget)
				local angle = math.acos(dot)
				local fovRad = math.rad(AutoFireballFOV.Value)
				
				if angle <= fovRad then
					return true
				end
			end
			
			return false
		end
	end
	
	local AutoFireball = vape.Categories.Utility:CreateModule({
		Name = 'AutoFireball',
		Function = function(callback)
			if callback then
				autoFireballEnabled = true
				
				task.spawn(function()
					repeat
						task.wait(0.1)
						if autoFireballEnabled and not _G.autoShootLock then
							if FirstPersonCheck.Enabled and not isFirstPerson() then
								continue
							end
							
							if not hasValidTarget() then
								continue
							end
							
							local currentTime = tick()
							if (currentTime - lastAutoFireballTime) >= AutoFireballInterval.Value then
								local fireballs = getFireballSlots()
								local swordSlot = getSwordSlot()
								
								if #fireballs > 0 then
									_G.autoShootLock = true
									lastAutoFireballTime = currentTime
									local originalSlot = store.inventory.hotbarSlot
									
									for _, fireballSlot in fireballs do
										if hotbarSwitch(fireballSlot) then
											task.wait(AutoFireballSwitchSpeed.Value)
											leftClick()
											task.wait(0.05)
										end
									end
									
									if swordSlot then
										hotbarSwitch(swordSlot)
									else
										hotbarSwitch(originalSlot)
									end
									
									_G.autoShootLock = false
								end
							end
						end
					until not autoFireballEnabled
				end)
			else
				autoFireballEnabled = false
			end
		end,
		Tooltip = 'Automatically throws fireballs at enemies'
	})
	
	AutoFireballInterval = AutoFireball:CreateSlider({
		Name = 'Throw Interval',
		Min = 0.1,
		Max = 3,
		Default = 0.8,
		Decimal = 10,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end,
		Tooltip = 'How often to throw fireballs'
	})
	
	AutoFireballSwitchSpeed = AutoFireball:CreateSlider({
		Name = 'Switch Delay',
		Min = 0,
		Max = 0.2,
		Default = 0.05,
		Decimal = 100,
		Suffix = 's',
		Tooltip = 'Delay between switching and throwing (lower = faster)'
	})
	
	AutoFireballRange = AutoFireball:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 15,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'Maximum range to throw fireballs'
	})
	
	AutoFireballFOV = AutoFireball:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 180,
		Default = 90,
		Tooltip = 'Field of view for target detection (1-180 degrees)'
	})
	
	FireballKillauraTargetCheck = AutoFireball:CreateToggle({
		Name = 'Require Killaura Target',
		Default = false,
		Tooltip = 'Only throw fireballs when Killaura has a target'
	})
	
	FirstPersonCheck = AutoFireball:CreateToggle({
		Name = 'First Person Only',
		Default = false,
		Tooltip = 'Only works in first person mode'
	})
end)

run(function()
	local AutoFireInterval
	local lastAutoFireTime = 0
	local autoFireEnabled = false
	local autoFireThread = nil
	local FirstPersonCheck
	
	local VirtualInputManager = game:GetService("VirtualInputManager")
	
	local function leftClick()
		pcall(function()
			VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
			task.wait(0.01)
			VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
		end)
	end
	
	local function isHoldingShootableWeapon()
		if not store.hand or not store.hand.tool then return false end
		
		local itemMeta = bedwars.ItemMeta[store.hand.tool.Name]
		if not itemMeta then return false end
		
		if itemMeta.projectileSource then
			local projectileSource = itemMeta.projectileSource
			if projectileSource.ammoItemTypes and (table.find(projectileSource.ammoItemTypes, 'arrow') or #projectileSource.ammoItemTypes > 0) then
				return true
			end
		end
		
		if store.hand.toolType == 'bow' then
			return true
		end
		
		return false
	end
	
	local AutoFire = vape.Categories.Utility:CreateModule({
		Name = 'AutoFire',
		Function = function(callback)
			if callback then
				autoFireEnabled = true
				
				if autoFireThread then
					coroutine.close(autoFireThread)
				end
				
				autoFireThread = task.spawn(function()
					while autoFireEnabled and entitylib.isAlive do
						if FirstPersonCheck.Enabled and not isFirstPerson() then
							task.wait(0.1)
							continue
						end
						
						local currentTime = tick()
						local interval = math.max(AutoFireInterval.Value, 0.1) 
						
						if (currentTime - lastAutoFireTime) >= interval then
							if isHoldingShootableWeapon() then
								leftClick()
								lastAutoFireTime = currentTime
							end
						end
						
						local waitTime = math.min(0.05, interval / 2)
						for i = 1, math.ceil(waitTime / 0.01) do
							if not autoFireEnabled then break end
							task.wait(0.01)
						end
					end
					autoFireThread = nil
				end)
			else
				autoFireEnabled = false
				if autoFireThread then
					coroutine.close(autoFireThread)
					autoFireThread = nil
				end
			end
		end,
		Tooltip = 'Automatically shoots when holding bows/projectile weapons'
	})
	
	AutoFireInterval = AutoFire:CreateSlider({
		Name = 'Fire Rate',
		Min = 0.1,
		Max = 3,
		Default = 0.5,
		Decimal = 10,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end,
		Tooltip = 'How often to auto-fire'
	})
	
	FirstPersonCheck = AutoFire:CreateToggle({
		Name = 'First Person Only',
		Default = false,
		Tooltip = 'Only works in first person mode'
	})
end)

run(function()
	local AutoKit
	local Legit
	local Toggles = {}
	
	local function kitCollection(id, func, range, specific)
		local objs = type(id) == 'table' and id or collection(id, AutoKit)
		repeat
			if entitylib.isAlive then
				local localPosition = entitylib.character.RootPart.Position
				for _, v in objs do
					if InfiniteFly.Enabled or not AutoKit.Enabled then break end
					local part = not v:IsA('Model') and v or v.PrimaryPart
					if part and (part.Position - localPosition).Magnitude <= (not Legit.Enabled and specific and math.huge or range) then
						func(v)
					end
				end
			end
			task.wait(0.1)
		until not AutoKit.Enabled
	end
	
	local AutoKitFunctions = {
		spider_queen = function()
			local isAiming = false
			local aimingTarget = nil
			
			repeat
				if entitylib.isAlive and bedwars.AbilityController then
					local plr = entitylib.EntityPosition({
						Range = not Legit.Enabled and 80 or 50,
						Part = 'RootPart',
						Players = true,
						Sort = sortmethods.Health
					})
					
					if plr and not isAiming and bedwars.AbilityController:canUseAbility('spider_queen_web_bridge_aim') then
						bedwars.AbilityController:useAbility('spider_queen_web_bridge_aim')
						isAiming = true
						aimingTarget = plr
						task.wait(0.1)
					end
					
					if isAiming and aimingTarget and aimingTarget.RootPart then
						local localPosition = entitylib.character.RootPart.Position
						local targetPosition = aimingTarget.RootPart.Position
						
						local direction
						if Legit.Enabled then
							direction = (targetPosition - localPosition).Unit
						else
							direction = (targetPosition - localPosition).Unit
						end
						
						if bedwars.AbilityController:canUseAbility('spider_queen_web_bridge_fire') then
							bedwars.AbilityController:useAbility('spider_queen_web_bridge_fire', newproxy(true), {
								direction = direction
							})
							isAiming = false
							aimingTarget = nil
							task.wait(0.3)
						end
					end
					
					if isAiming and (not aimingTarget or not aimingTarget.RootPart) then
						isAiming = false
						aimingTarget = nil
					end
					
					local summonAbility = 'spider_queen_summon_spiders'
					if bedwars.AbilityController:canUseAbility(summonAbility) then
						bedwars.AbilityController:useAbility(summonAbility)
					end
				end
				
				task.wait(0.05)
			until not AutoKit.Enabled
		end,
		battery = function()
			repeat
				if entitylib.isAlive then
					local localPosition = entitylib.character.RootPart.Position
					for i, v in bedwars.BatteryEffectsController.liveBatteries do
						if (v.position - localPosition).Magnitude <= 10 then
							local BatteryInfo = bedwars.BatteryEffectsController:getBatteryInfo(i)
							if not BatteryInfo or BatteryInfo.activateTime >= workspace:GetServerTimeNow() or BatteryInfo.consumeTime + 0.1 >= workspace:GetServerTimeNow() then continue end
							BatteryInfo.consumeTime = workspace:GetServerTimeNow()
							bedwars.Client:Get(remotes.ConsumeBattery):SendToServer({batteryId = i})
						end
					end
				end
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		beekeeper = function()
			kitCollection('bee', function(v)
				bedwars.Client:Get(remotes.BeePickup):SendToServer({beeId = v:GetAttribute('BeeId')})
			end, 18, false)
		end,
		bigman = function()
			kitCollection('treeOrb', function(v)
				if bedwars.Client:Get(remotes.ConsumeTreeOrb):CallServer({treeOrbSecret = v:GetAttribute('TreeOrbSecret')}) then
					v:Destroy()
				end
			end, 12, false)
		end,
		blood_assassin = function()
			AutoKit:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
				if not entitylib.isAlive then return end
				
				local attacker = playersService:GetPlayerFromCharacter(damageTable.fromEntity)
				local victim = playersService:GetPlayerFromCharacter(damageTable.entityInstance)
				
				if attacker == lplr and victim and victim ~= lplr then
					local storeState = bedwars.Store:getState()
					local activeContract = storeState.Kit.activeContract
					local availableContracts = storeState.Kit.availableContracts or {}
					
					if not activeContract then
						for _, contract in availableContracts do
							if contract.target == victim then
								bedwars.Client:Get('BloodAssassinSelectContract'):SendToServer({
									contractId = contract.id
								})
								break
							end
						end
					end
				end
			end))
			
			repeat
				if entitylib.isAlive then
					local storeState = bedwars.Store:getState()
					local activeContract = storeState.Kit.activeContract
					local availableContracts = storeState.Kit.availableContracts or {}
					
					if not activeContract and #availableContracts > 0 then
						local bestContract = availableContracts[1]
						for _, contract in availableContracts do
							if contract.difficulty > bestContract.difficulty then
								bestContract = contract
							end
						end
						
						bedwars.Client:Get('BloodAssassinSelectContract'):SendToServer({
							contractId = bestContract.id
						})
						task.wait(0.5)
					end
				end
				task.wait(1)
			until not AutoKit.Enabled
		end,
		block_kicker = function()
			local old = bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition
			bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition = function(...)
				local origin, dir = select(2, ...)
				local plr = entitylib.EntityMouse({
					Part = 'RootPart',
					Range = 1000,
					Origin = origin,
					Players = true,
					Wallcheck = true
				})
	
				if plr then
					local calc = prediction.SolveTrajectory(origin, 100, 20, plr.RootPart.Position, plr.RootPart.Velocity, workspace.Gravity, plr.HipHeight, plr.Jumping and 42.6 or nil)
	
					if calc then
						for i, v in debug.getstack(2) do
							if v == dir then
								debug.setstack(2, i, CFrame.lookAt(origin, calc).LookVector)
							end
						end
					end
				end
	
				return old(...)
			end
	
			AutoKit:Clean(function()
				bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition = old
			end)
		end,
		cat = function()
			local old = bedwars.CatController.leap
			bedwars.CatController.leap = function(...)
				vapeEvents.CatPounce:Fire()
				return old(...)
			end
	
			AutoKit:Clean(function()
				bedwars.CatController.leap = old
			end)
		end,
		davey = function()
			local old = bedwars.CannonHandController.launchSelf
			bedwars.CannonHandController.launchSelf = function(...)
				local res = {old(...)}
				local self, block = ...
	
				if block:GetAttribute('PlacedByUserId') == lplr.UserId and (block.Position - entitylib.character.RootPart.Position).Magnitude < 30 then
					task.spawn(bedwars.breakBlock, block, false, nil, true)
				end
	
				return unpack(res)
			end
	
			AutoKit:Clean(function()
				bedwars.CannonHandController.launchSelf = old
			end)
		end,
		dragon_slayer = function()
			kitCollection('KaliyahPunchInteraction', function(v)
				bedwars.DragonSlayerController:deleteEmblem(v)
				bedwars.DragonSlayerController:playPunchAnimation(Vector3.zero)
				bedwars.Client:Get(remotes.KaliyahPunch):SendToServer({
					target = v
				})
			end, 18, true)
		end,
		drill = function()
			repeat
				if not AutoKit.Enabled then
					break
				end
		
				local foundDrill = false
				for _, child in workspace:GetDescendants() do
					if child:IsA("Model") and child.Name == "Drill" then
						local drillPrimaryPart = child.PrimaryPart
						if drillPrimaryPart then
							foundDrill = true
							local args = {
								{
									drill = child
								}
							}
							local success, err = pcall(function()
								game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("ExtractFromDrill"):FireServer(unpack(args))
							end)
		
							task.wait(0.05)
						end
					elseif child:IsA("BasePart") and child.Name == "Drill" then
						foundDrill = true
						local args = {
							{
								drill = child
							}
						}
						local success, err = pcall(function()
							game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("ExtractFromDrill"):FireServer(unpack(args))
						end)
		
						task.wait(0.05)
					end
				end
				task.wait(0.5)
			until not AutoKit.Enabled
		end,
		farmer_cletus = function()
			kitCollection('HarvestableCrop', function(v)
				if bedwars.Client:Get(remotes.HarvestCrop):CallServer({position = bedwars.BlockController:getBlockPosition(v.Position)}) then
					bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.PUNCH)
					bedwars.SoundManager:playSound(bedwars.SoundList.CROP_HARVEST)
				end
			end, 10, false)
		end,
		fisherman = function()
			local old = bedwars.FishingMinigameController.startMinigame
			bedwars.FishingMinigameController.startMinigame = function(_, _, result)
				result({win = true})
			end
	
			AutoKit:Clean(function()
				bedwars.FishingMinigameController.startMinigame = old
			end)
		end,
		gingerbread_man = function()
			local old = bedwars.LaunchPadController.attemptLaunch
			bedwars.LaunchPadController.attemptLaunch = function(...)
				local res = {old(...)}
				local self, block = ...
	
				if (workspace:GetServerTimeNow() - self.lastLaunch) < 0.4 then
					if block:GetAttribute('PlacedByUserId') == lplr.UserId and (block.Position - entitylib.character.RootPart.Position).Magnitude < 30 then
						task.spawn(bedwars.breakBlock, block, false, nil, true)
					end
				end
	
				return unpack(res)
			end
	
			AutoKit:Clean(function()
				bedwars.LaunchPadController.attemptLaunch = old
			end)
		end,
		hannah = function()
			kitCollection('HannahExecuteInteraction', function(v)
				local billboard = bedwars.Client:Get(remotes.HannahKill):CallServer({
					user = lplr,
					victimEntity = v
				}) and v:FindFirstChild('Hannah Execution Icon')
	
				if billboard then
					billboard:Destroy()
				end
			end, 30, true)
		end,
		jailor = function()
			kitCollection('jailor_soul', function(v)
				bedwars.JailorController:collectEntity(lplr, v, 'JailorSoul')
			end, 20, false)
		end,
		grim_reaper = function()
			kitCollection(bedwars.GrimReaperController.soulsByPosition, function(v)
				if entitylib.isAlive and lplr.Character:GetAttribute('Health') <= (lplr.Character:GetAttribute('MaxHealth') / 4) and (not lplr.Character:GetAttribute('GrimReaperChannel')) then
					bedwars.Client:Get(remotes.ConsumeSoul):CallServer({
						secret = v:GetAttribute('GrimReaperSoulSecret')
					})
				end
			end, 120, false)
		end,
		melody = function()
			repeat
				local mag, hp, ent = 30, math.huge
				if entitylib.isAlive then
					local localPosition = entitylib.character.RootPart.Position
					for _, v in entitylib.List do
						if v.Player and v.Player:GetAttribute('Team') == lplr:GetAttribute('Team') then
							local newmag = (localPosition - v.RootPart.Position).Magnitude
							if newmag <= mag and v.Health < hp and v.Health < v.MaxHealth then
								mag, hp, ent = newmag, v.Health, v
							end
						end
					end
				end
	
				if ent and getItem('guitar') then
					bedwars.Client:Get(remotes.GuitarHeal):SendToServer({
						healTarget = ent.Character
					})
				end
	
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		metal_detector = function()
			kitCollection('hidden-metal', function(v)
				bedwars.Client:Get(remotes.PickupMetal):SendToServer({
					id = v:GetAttribute('Id')
				})
			end, 50, false)
		end,
		mimic = function()
			repeat
				if not entitylib.isAlive then
					task.wait(0.1)
					continue
				end
				
				local localPosition = entitylib.character.RootPart.Position
				for _, v in entitylib.List do
					if v.Targetable and v.Character and v.Player then
						local distance = (v.RootPart.Position - localPosition).Magnitude
						if distance <= (Legit.Enabled and 12 or 30) then
							if collectionService:HasTag(v.Character, "MimicBLockPickPocketPlayer") then
								pcall(function()
									local success = replicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("MimicBlockPickPocketPlayer"):InvokeServer(v.Player)
								end)
								task.wait(0.5)
							end
						end
					end
				end
				
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		miner = function()
			kitCollection('petrified-player', function(v)
				bedwars.Client:Get(remotes.MinerDig):SendToServer({
					petrifyId = v:GetAttribute('PetrifyId')
				})
			end, 6, true)
		end,
		pinata = function()
			kitCollection(lplr.Name..':pinata', function(v)
				if getItem('candy') then
					bedwars.Client:Get(remotes.DepositPinata):CallServer(v)
				end
			end, 6, true)
		end,
		spirit_assassin = function()
			kitCollection('EvelynnSoul', function(v)
				bedwars.SpiritAssassinController:useSpirit(lplr, v)
			end, 120, true)
		end,
		star_collector = function()
			kitCollection('stars', function(v)
				bedwars.StarCollectorController:collectEntity(lplr, v, v.Name)
			end, 20, false)
		end,
		summoner = function()
			repeat
				if not entitylib.isAlive then
					task.wait(0.1)
					continue
				end
				
				local plr = entitylib.EntityPosition({
					Range = 31,
					Part = 'RootPart',
					Players = true,
					Sort = sortmethods.Health
				})
	
				if plr and (not Legit.Enabled or (lplr.Character:GetAttribute('Health') or 0) > 0) then
					local localPosition = entitylib.character.RootPart.Position
					local shootDir = CFrame.lookAt(localPosition, plr.RootPart.Position).LookVector
					localPosition += shootDir * math.max((localPosition - plr.RootPart.Position).Magnitude - 16, 0)
	
					bedwars.Client:Get(remotes.SummonerClawAttack):SendToServer({
						position = localPosition,
						direction = shootDir,
						clientTime = workspace:GetServerTimeNow()
					})
				end
	
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		void_dragon = function()
			local oldflap = bedwars.VoidDragonController.flapWings
			local flapped
	
			bedwars.VoidDragonController.flapWings = function(self)
				if not flapped and bedwars.Client:Get(remotes.DragonFly):CallServer() then
					local modifier = bedwars.SprintController:getMovementStatusModifier():addModifier({
						blockSprint = true,
						constantSpeedMultiplier = 2
					})
					self.SpeedMaid:GiveTask(modifier)
					self.SpeedMaid:GiveTask(function()
						flapped = false
					end)
					flapped = true
				end
			end
	
			AutoKit:Clean(function()
				bedwars.VoidDragonController.flapWings = oldflap
			end)
	
			repeat
				if not entitylib.isAlive then
					task.wait(0.1)
					continue
				end
				
				if bedwars.VoidDragonController.inDragonForm then
					local plr = entitylib.EntityPosition({
						Range = 30,
						Part = 'RootPart',
						Players = true
					})
	
					if plr then
						bedwars.Client:Get(remotes.DragonBreath):SendToServer({
							player = lplr,
							targetPoint = plr.RootPart.Position
						})
					end
				end
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		warlock = function()
			local lastTarget
			repeat
				if not entitylib.isAlive then
					lastTarget = nil
					task.wait(0.1)
					continue
				end
				
				if store.hand.tool and store.hand.tool.Name == 'warlock_staff' then
					local plr = entitylib.EntityPosition({
						Range = 30,
						Part = 'RootPart',
						Players = true,
						NPCs = true
					})
	
					if plr and plr.Character ~= lastTarget then
						if not bedwars.Client:Get(remotes.WarlockTarget):CallServer({
							target = plr.Character
						}) then
							plr = nil
						end
					end
	
					lastTarget = plr and plr.Character
				else
					lastTarget = nil
				end
	
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		wizard = function()
			repeat
				if not entitylib.isAlive then
					task.wait(0.1)
					continue
				end
				
				local ability = lplr:GetAttribute('WizardAbility')
				if ability and bedwars.AbilityController:canUseAbility(ability) then
					local plr = entitylib.EntityPosition({
						Range = 50,
						Part = 'RootPart',
						Players = true,
						Sort = sortmethods.Health
					})
	
					if plr then
						bedwars.AbilityController:useAbility(ability, newproxy(true), {target = plr.RootPart.Position})
					end
				end
	
				task.wait(0.1)
			until not AutoKit.Enabled
		end
	}
	
	AutoKit = vape.Categories.Utility:CreateModule({
		Name = 'AutoKit',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.equippedKit ~= '' and store.matchState ~= 0 or (not AutoKit.Enabled)
				if AutoKit.Enabled and AutoKitFunctions[store.equippedKit] and Toggles[store.equippedKit].Enabled then
					AutoKitFunctions[store.equippedKit]()
				end
			end
		end,
		Tooltip = 'Automatically uses kit abilities.'
	})
	Legit = AutoKit:CreateToggle({Name = 'Legit Range'})
	local sortTable = {}
	for i in AutoKitFunctions do
		table.insert(sortTable, i)
	end
	table.sort(sortTable, function(a, b)
		return bedwars.BedwarsKitMeta[a].name < bedwars.BedwarsKitMeta[b].name
	end)
	for _, v in sortTable do
		Toggles[v] = AutoKit:CreateToggle({
			Name = bedwars.BedwarsKitMeta[v].name,
			Default = true
		})
	end
end)

run(function()
	local CannonHandController = bedwars.CannonHandController
	local CannonController = bedwars.CannonController

	local oldLaunchSelf = CannonHandController.launchSelf
	local oldStopAiming = CannonController.stopAiming
	local oldStartAiming = CannonController.startAiming

	local function isHoldingPickaxe()
		if not entitylib.isAlive then return false end
		
		local handItem = store.hand
		if not handItem or not handItem.tool then return false end
		
		local itemName = handItem.tool.Name:lower()
		local isPickaxe = itemName:find("pickaxe") or 
						 itemName:find("drill") or 
						 itemName:find("gauntlet") or
						 itemName:find("hammer") or
						 itemName:find("axe")
		
		return isPickaxe
	end

	local function getNearestCannon()
		local nearest
		local nearestDist = math.huge

		for i,v in pairs(CannonController.getCannons()) do
			pcall(function()
				local dist = (v.Position - lplr.Character.PrimaryPart.Position).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					nearest = v
				end
			end)
		end

		return nearest
	end

	local speed_was_disabled = nil

	local function disableSpeed()
		pcall(function()
			if vape.Modules.Speed.Enabled then
				vape.Modules.Speed:Toggle(false)
				speed_was_disabled = true
			else
				speed_was_disabled = false
			end	
		end)
	end

	local function enableSpeed()
		task.wait(3)
		if speed_was_disabled then
			pcall(function()
				if not vape.Modules.Speed.Enabled then
					vape.Modules.Speed:Toggle(false)
				end
				speed_was_disabled = nil
			end)
		end
	end
	
	local function breakCannon(cannon, shootfunc)
		if BetterDaveyPickaxeCheck.Enabled and not isHoldingPickaxe() then
			InfoNotification("BetterDavey", "You need to HOLD a pickaxe to break cannons!", 3)
			if BetterDaveyAutojump.Enabled then
				lplr.Character.Humanoid:ChangeState(3)
			end
			local res = shootfunc()
			enableSpeed()
			return res
		end
		
		local pos = cannon.Position
		local res
		task.delay(0, function()
			local block, blockpos = getPlacedBlock(pos)
			if block and block.Name == 'cannon' and (entitylib.character.RootPart.Position - block.Position).Magnitude < 20 then
				local broken = 0.1
				if bedwars.BlockController:calculateBlockDamage(lplr, {blockPosition = blockpos}) < block:GetAttribute('Health') then
					broken = 0.4
					bedwars.breakBlock(block, true, true)
				end

				task.delay(broken, function()
					if BetterDaveyAutojump.Enabled then
						lplr.Character.Humanoid:ChangeState(3)
					end
					res = shootfunc()
					task.spawn(bedwars.breakBlock, block, false, nil, true)
					return res
				end)
			end
		end)
	end

	BetterDavey = vape.Categories.Utility:CreateModule({
		Name = 'BetterDavey',
		Function = function(callback)
			if callback then
				local stopIndex = 0

				CannonHandController.launchSelf = function(...)
					disableSpeed()

					if BetterDaveyAutoBreak.Enabled then
						local cannon = getNearestCannon()
						if cannon then
							local args = {...}
							local result = breakCannon(cannon, function() return oldLaunchSelf(unpack(args)) end)
							enableSpeed()
							return result
						else
							if BetterDaveyAutojump.Enabled then
								lplr.Character.Humanoid:ChangeState(3)
							end
							local res = oldLaunchSelf(...)
							enableSpeed()
							return res
						end
					else
						if BetterDaveyAutojump.Enabled then
							lplr.Character.Humanoid:ChangeState(3)
						end
						local res = oldLaunchSelf(...)
						enableSpeed()
						return res
					end
				end

				CannonController.stopAiming = function(...)
					stopIndex += 1

					if BetterDaveyAutoLaunch.Enabled and stopIndex == 2 then
						if BetterDaveyAutoBreak.Enabled and BetterDaveyPickaxeCheck.Enabled and not isHoldingPickaxe() then
							InfoNotification("BetterDavey", "Hold a pickaxe to auto-break!", 3)
							return oldStopAiming(...)
						end
						
						local cannon = getNearestCannon()
						if cannon then
							CannonHandController:launchSelf(cannon)
						end
					end

					return oldStopAiming(...)
				end

				CannonController.startAiming = function(...)
					stopIndex = 0
					return oldStartAiming(...)
				end
			else
				CannonHandController.launchSelf = oldLaunchSelf
				CannonController.stopAiming = oldStopAiming
				CannonController.startAiming = oldStartAiming
			end
		end
	})
	
	BetterDaveyAutojump = BetterDavey:CreateToggle({
		Name = 'Auto jump',
		Default = true,
		HoverText = 'Automatically jumps when launching from a cannon',
		Function = function() end
	})
	
	BetterDaveyAutoLaunch = BetterDavey:CreateToggle({
		Name = 'Auto launch',
		Default = true,
		HoverText = 'Automatically launches you from a cannon when you finish aiming',
		Function = function() end
	})
	
	BetterDaveyAutoBreak = BetterDavey:CreateToggle({
		Name = 'Auto break',
		Default = true,
		HoverText = 'Automatically breaks a cannon when you launch from it',
		Function = function() end
	})
	
	BetterDaveyPickaxeCheck = BetterDavey:CreateToggle({
		Name = 'Pickaxe Check',
		Default = true,
		HoverText = 'Must be HOLDING a pickaxe to break cannons\nWill NOT switch tools automatically',
		Function = function() end
	})
end)

run(function()
    local AutoCounter
    local TntCount
    local LimitItem

    local function fixPosition(pos)
        return bedwars.BlockController:getBlockPosition(pos) * 3
    end

    local allOurTnt = {}
    local ourTntPositions = {}

    local originalPlaceBlock = bedwars.placeBlock
    bedwars.placeBlock = function(pos, blockType, ...)
        local result = originalPlaceBlock(pos, blockType, ...)

        if blockType == "tnt" then
            local fixedPos = fixPosition(pos)
            ourTntPositions[tostring(fixedPos)] = true
            
            task.spawn(function()
                task.wait(0.3)
                for _, obj in workspace:GetDescendants() do
                    if obj.Name == "tnt" and obj:IsA("Part") then
                        local distance = (fixPosition(obj.Position) - fixedPos).Magnitude
                        if distance < 2 then
                            allOurTnt[obj] = true
                        end
                    end
                end
            end)
        end

        return result
    end

    workspace.DescendantAdded:Connect(function(obj)
        if obj.Name == "tnt" and obj:IsA("Part") then
            task.wait(0.1)

            local placerId = obj:GetAttribute("PlacedByUserId")
            if placerId and placerId == lplr.UserId then
                allOurTnt[obj] = true
                ourTntPositions[tostring(fixPosition(obj.Position))] = true
            else
                local tntPos = tostring(fixPosition(obj.Position))
                if ourTntPositions[tntPos] then
                    allOurTnt[obj] = true
                end
            end

            obj.AncestryChanged:Connect(function()
                if not obj.Parent then
                    allOurTnt[obj] = nil
                    ourTntPositions[tostring(fixPosition(obj.Position))] = nil
                end
            end)
        end
    end)

    local function isEnemyTnt(tntBlock)
        if not tntBlock then return false end

        if allOurTnt[tntBlock] then
            return false
        end

        local tntPos = tostring(fixPosition(tntBlock.Position))
        if ourTntPositions[tntPos] then
            allOurTnt[tntBlock] = true
            return false
        end

        local placerId = tntBlock:GetAttribute("PlacedByUserId")
        if placerId and placerId == lplr.UserId then
            allOurTnt[tntBlock] = true
            ourTntPositions[tntPos] = true
            return false
        end

        return true
    end

    local function isHoldingTnt()
        local currentTool = store.hand.tool
        return currentTool and currentTool.Name == "tnt"
    end

    AutoCounter = vape.Categories.World:CreateModule({
        Name = 'AutoCounter',
        Function = function(callback)
            if callback then
                local counteredTnt = {}

                for _, obj in workspace:GetDescendants() do
                    if obj.Name == "tnt" and obj:IsA("Part") then
                        local placerId = obj:GetAttribute("PlacedByUserId")
                        if placerId and placerId == lplr.UserId then
                            allOurTnt[obj] = true
                            ourTntPositions[tostring(fixPosition(obj.Position))] = true
                        end
                    end
                end

                repeat
                    if not entitylib.isAlive then
                        task.wait(0.1)
                        continue
                    end

                    if LimitItem.Enabled and not isHoldingTnt() then
                        task.wait(0.1)
                        continue
                    end

                    if not getItem("tnt") then
                        task.wait(0.1)
                        continue
                    end

                    for _, obj in workspace:GetDescendants() do
                        if obj.Name == "tnt" and obj:IsA("Part") and not counteredTnt[obj] then
                            if isEnemyTnt(obj) then
                                local distance = (entitylib.character.RootPart.Position - obj.Position).Magnitude

                                if distance <= 30 then
                                    local placedCount = 0
                                    
                                    for _, side in Enum.NormalId:GetEnumItems() do
                                        if LimitItem.Enabled and not isHoldingTnt() then
                                            break
                                        end

                                        if placedCount >= TntCount.Value then break end

                                        local sideVec = Vector3.fromNormalId(side)
                                        if sideVec.Y == 0 then
                                            local placePos = fixPosition(obj.Position + sideVec * 3.5)

                                            if not getPlacedBlock(placePos) and getItem("tnt") then
                                                if LimitItem.Enabled and not isHoldingTnt() then
                                                    break
                                                end

                                                bedwars.placeBlock(placePos, "tnt")
                                                placedCount = placedCount + 1
                                                task.wait(0.05)
                                            end
                                        end
                                    end

                                    counteredTnt[obj] = true

                                    task.spawn(function()
                                        if obj.Parent then
                                            obj.AncestryChanged:Wait()
                                        end
                                        counteredTnt[obj] = nil
                                    end)
                                end
                            end
                        end
                    end

                    task.wait(0.1)
                until not AutoCounter.Enabled
            else
                table.clear(allOurTnt)
                table.clear(ourTntPositions)
            end
        end,
        Tooltip = 'Automatically places TNT around enemy TNT - Now with proper team detection!'
    })

    TntCount = AutoCounter:CreateSlider({
        Name = 'TNT Count',
        Min = 1,
        Max = 5,
        Default = 3
    })

    LimitItem = AutoCounter:CreateToggle({
        Name = 'Limit to TNT',
        Default = true,
        Tooltip = 'Only works when holding TNT'
    })
end)

run(function()
	vape.Categories.World:CreateModule({
		Name = 'Anti-AFK',
		Function = function(callback)
			if callback then
				for _, v in getconnections(lplr.Idled) do
					v:Disconnect()
				end
	
				for _, v in getconnections(runService.Heartbeat) do
					if type(v.Function) == 'function' and table.find(debug.getconstants(v.Function), remotes.AfkStatus) then
						v:Disconnect()
					end
				end
	
				bedwars.Client:Get(remotes.AfkStatus):SendToServer({
					afk = false
				})
			end
		end,
		Tooltip = 'Lets you stay ingame without getting kicked'
	})
end)

run(function()
    local AutoBuildUp
    local LimitItem
    local adjacent = {}
    
    for x = -3, 3, 3 do
        for y = -3, 3, 3 do
            for z = -3, 3, 3 do
                local vec = Vector3.new(x, y, z)
                if vec ~= Vector3.zero then
                    table.insert(adjacent, vec)
                end
            end
        end
    end
    
    local function nearCorner(poscheck, pos)
        local startpos = poscheck - Vector3.new(3, 3, 3)
        local endpos = poscheck + Vector3.new(3, 3, 3)
        local check = poscheck + (pos - poscheck).Unit * 100
        return Vector3.new(math.clamp(check.X, startpos.X, endpos.X), math.clamp(check.Y, startpos.Y, endpos.Y), math.clamp(check.Z, startpos.Z, endpos.Z))
    end
    
    local function blockProximity(pos)
        local mag, returned = 60
        local tab = getBlocksInPoints(bedwars.BlockController:getBlockPosition(pos - Vector3.new(21, 21, 21)), bedwars.BlockController:getBlockPosition(pos + Vector3.new(21, 21, 21)))
        for _, v in tab do
            local blockpos = nearCorner(v, pos)
            local newmag = (pos - blockpos).Magnitude
            if newmag < mag then
                mag, returned = newmag, blockpos
            end
        end
        table.clear(tab)
        return returned
    end
    
    local function checkAdjacent(pos)
        for _, v in adjacent do
            if getPlacedBlock(pos + v) then
                return true
            end
        end
        return false
    end
    
    local function getScaffoldBlock()
        if LimitItem.Enabled then
            if store.hand.toolType == 'block' then
                return store.hand.tool.Name
            end
            return nil
        else
            local wool = getWool()
            if wool then
                return wool
            else
                for _, item in store.inventory.inventory.items do
                    if bedwars.ItemMeta[item.itemType].block then
                        return item.itemType
                    end
                end
            end
        end
        return nil
    end
    
    local function canPlaceAtPosition(blockpos)
        if not checkAdjacent(blockpos) then
            return false
        end
        
        local checkBelow = blockpos - Vector3.new(0, 3, 0)
        local hasSupport = false
        
        for i = 1, 10 do
            if getPlacedBlock(checkBelow) then
                hasSupport = true
                break
            end
            checkBelow = checkBelow - Vector3.new(0, 3, 0)
        end
        
        return hasSupport or checkAdjacent(blockpos)
    end
    
    AutoBuildUp = vape.Categories.World:CreateModule({
        Name = 'AutoBuildUp',
        Function = function(callback)
            if callback then
                repeat
                    if entitylib.isAlive then
                        local wool = getScaffoldBlock()
                        
                        if wool then
                            local root = entitylib.character.RootPart
                            
                            if inputService:IsKeyDown(Enum.KeyCode.Space) and (not inputService:GetFocusedTextBox()) then
                                local currentpos = roundPos(root.Position - Vector3.new(0, entitylib.character.HipHeight + 1.5, 0))
                                
                                local block, blockpos = getPlacedBlock(currentpos)
                                if not block then
                                    blockpos = blockpos * 3
                                    
                                    if checkAdjacent(blockpos) then
                                        if canPlaceAtPosition(blockpos) then
                                            task.spawn(bedwars.placeBlock, blockpos, wool, false)
                                        end
                                    else
                                        local nearestBlock = blockProximity(currentpos)
                                        if nearestBlock and canPlaceAtPosition(nearestBlock) then
                                            task.spawn(bedwars.placeBlock, nearestBlock, wool, false)
                                        end
                                    end
                                end
                            end
                        end
                    end
                    
                    task.wait(0.03)
                until not AutoBuildUp.Enabled
            end
        end,
        Tooltip = 'Automatically places blocks under you ONLY when jumping'
    })
    
    LimitItem = AutoBuildUp:CreateToggle({
        Name = 'Limit to items',
        Default = false,
        Tooltip = 'Only place blocks when holding a block item'
    })
end)
	
run(function()
	local AutoSuffocate
	local Range
	local LimitItem
	local InstantSuffocate
	local SmartMode
	
	local function fixPosition(pos)
		return bedwars.BlockController:getBlockPosition(pos) * 3
	end
	
	local function countSurroundingBlocks(pos)
		local count = 0
		for _, side in Enum.NormalId:GetEnumItems() do
			if side == Enum.NormalId.Top or side == Enum.NormalId.Bottom then continue end
			local checkPos = fixPosition(pos + Vector3.fromNormalId(side) * 2)
			if getPlacedBlock(checkPos) then
				count += 1
			end
		end
		return count
	end
	
	local function isInVoid(pos)
		for i = 1, 10 do
			local checkPos = fixPosition(pos - Vector3.new(0, i * 3, 0))
			if getPlacedBlock(checkPos) then
				return false
			end
		end
		return true
	end
	
	local function getSmartSuffocationBlocks(ent)
		local rootPos = ent.RootPart.Position
		local headPos = ent.Head.Position
		local needPlaced = {}
		local surroundingBlocks = countSurroundingBlocks(rootPos)
		local inVoid = isInVoid(rootPos)
		
		if surroundingBlocks >= 1 and surroundingBlocks <= 2 then
			for _, side in Enum.NormalId:GetEnumItems() do
				if side == Enum.NormalId.Top or side == Enum.NormalId.Bottom then continue end
				local sidePos = fixPosition(rootPos + Vector3.fromNormalId(side) * 2)
				if not getPlacedBlock(sidePos) then
					table.insert(needPlaced, sidePos)
				end
			end
			table.insert(needPlaced, fixPosition(headPos))
			table.insert(needPlaced, fixPosition(rootPos - Vector3.new(0, 3, 0)))
		
		elseif inVoid then
			table.insert(needPlaced, fixPosition(rootPos - Vector3.new(0, 3, 0)))
			table.insert(needPlaced, fixPosition(headPos + Vector3.new(0, 3, 0)))
			for _, side in Enum.NormalId:GetEnumItems() do
				if side == Enum.NormalId.Top or side == Enum.NormalId.Bottom then continue end
				local sidePos = fixPosition(rootPos + Vector3.fromNormalId(side) * 2)
				table.insert(needPlaced, sidePos)
			end
			table.insert(needPlaced, fixPosition(headPos))
		
		elseif surroundingBlocks == 3 then
			for _, side in Enum.NormalId:GetEnumItems() do
				if side == Enum.NormalId.Top or side == Enum.NormalId.Bottom then continue end
				local sidePos = fixPosition(rootPos + Vector3.fromNormalId(side) * 2)
				if not getPlacedBlock(sidePos) then
					table.insert(needPlaced, sidePos)
				end
			end
			table.insert(needPlaced, fixPosition(headPos))
			table.insert(needPlaced, fixPosition(rootPos - Vector3.new(0, 3, 0)))
		
		elseif surroundingBlocks >= 4 then
			table.insert(needPlaced, fixPosition(headPos))
			table.insert(needPlaced, fixPosition(rootPos - Vector3.new(0, 3, 0)))
		
		else
			table.insert(needPlaced, fixPosition(rootPos - Vector3.new(0, 3, 0)))
			for _, side in Enum.NormalId:GetEnumItems() do
				if side == Enum.NormalId.Top or side == Enum.NormalId.Bottom then continue end
				local sidePos = fixPosition(rootPos + Vector3.fromNormalId(side) * 2)
				table.insert(needPlaced, sidePos)
			end
			table.insert(needPlaced, fixPosition(headPos))
		end
		
		return needPlaced
	end
	
	local function getBasicSuffocationBlocks(ent)
		local needPlaced = {}
		
		for _, side in Enum.NormalId:GetEnumItems() do
			side = Vector3.fromNormalId(side)
			if side.Y ~= 0 then continue end
			
			side = fixPosition(ent.RootPart.Position + side * 2)
			if not getPlacedBlock(side) then
				table.insert(needPlaced, side)
			end
		end
		
		if #needPlaced < 3 then
			table.insert(needPlaced, fixPosition(ent.Head.Position))
			table.insert(needPlaced, fixPosition(ent.RootPart.Position - Vector3.new(0, 1, 0)))
		end
		
		return needPlaced
	end
	
	AutoSuffocate = vape.Categories.World:CreateModule({
		Name = 'AutoSuffocate',
		Function = function(callback)
			if callback then
				repeat
					local item = store.hand.toolType == 'block' and store.hand.tool.Name or not LimitItem.Enabled and getWool()
	
					if item then
						local plrs = entitylib.AllPosition({
							Part = 'RootPart',
							Range = Range.Value,
							Players = true
						})
	
						for _, ent in plrs do
							local needPlaced = SmartMode.Enabled and getSmartSuffocationBlocks(ent) or getBasicSuffocationBlocks(ent)
	
							if InstantSuffocate.Enabled then
								for _, pos in needPlaced do
									if not getPlacedBlock(pos) then
										task.spawn(bedwars.placeBlock, pos, item)
									end
								end
							else
								for _, pos in needPlaced do
									if not getPlacedBlock(pos) then
										task.spawn(bedwars.placeBlock, pos, item)
										break
									end
								end
							end
						end
					end
	
					task.wait(InstantSuffocate.Enabled and 0.05 or 0.09)
				until not AutoSuffocate.Enabled
			end
		end,
		Tooltip = 'Places blocks on nearby confined entities'
	})
	Range = AutoSuffocate:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 20,
		Default = 20,
		Function = function() end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	SmartMode = AutoSuffocate:CreateToggle({
		Name = 'Smart Mode',
		Default = true,
		Tooltip = 'Detects scenarios: walls, void, corners, open areas'
	})
	LimitItem = AutoSuffocate:CreateToggle({
		Name = 'Limit to Items',
		Default = true,
		Function = function() end
	})
	InstantSuffocate = AutoSuffocate:CreateToggle({
		Name = 'Instant Suffocate',
		Function = function() end,
		Tooltip = 'Instantly places all suffocation blocks instead of one at a time'
	})
end)

run(function()
	local AutoBuy
	local Sword
	local Armor
	local Upgrades
	local TierCheck
	local BedwarsCheck
	local GUI
	local SmartCheck
	local Custom = {}
	local CustomPost = {}
	local UpgradeToggles = {}
	local Functions, id = {}
	local Callbacks = {Custom, Functions, CustomPost}
	local npctick = tick()
	
	local swords = {
		'wood_sword',
		'stone_sword',
		'iron_sword',
		'diamond_sword',
		'emerald_sword'
	}
	
	local armors = {
		'none',
		'leather_chestplate',
		'iron_chestplate',
		'diamond_chestplate',
		'emerald_chestplate'
	}
	
	local axes = {
		'none',
		'wood_axe',
		'stone_axe',
		'iron_axe',
		'diamond_axe'
	}
	
	local pickaxes = {
		'none',
		'wood_pickaxe',
		'stone_pickaxe',
		'iron_pickaxe',
		'diamond_pickaxe'
	}
	
	local function getShopNPC()
		local shop, items, upgrades, newid = nil, false, false, nil
		if entitylib.isAlive then
			local localPosition = entitylib.character.RootPart.Position
			for _, v in store.shop do
				if (v.RootPart.Position - localPosition).Magnitude <= 20 then
					shop = v.Upgrades or v.Shop or nil
					upgrades = upgrades or v.Upgrades
					items = items or v.Shop
					newid = v.Shop and v.Id or newid
				end
			end
		end
		return shop, items, upgrades, newid
	end
	
	local function canBuy(item, currencytable, amount)
		amount = amount or 1
		if not currencytable[item.currency] then
			local currency = getItem(item.currency)
			currencytable[item.currency] = currency and currency.amount or 0
		end
		if item.ignoredByKit and table.find(item.ignoredByKit, store.equippedKit or '') then return false end
		if item.lockedByForge or item.disabled then return false end
		if item.require and item.require.teamUpgrade then
			if (bedwars.Store:getState().Bedwars.teamUpgrades[item.require.teamUpgrade.upgradeId] or -1) < item.require.teamUpgrade.lowestTierIndex then
				return false
			end
		end
		return currencytable[item.currency] >= (item.price * amount)
	end
	
	local function buyItem(item, currencytable)
		if not id then return end
		notif('AutoBuy', 'Bought '..bedwars.ItemMeta[item.itemType].displayName, 3)
		bedwars.Client:Get('BedwarsPurchaseItem'):CallServerAsync({
			shopItem = item,
			shopId = id
		}):andThen(function(suc)
			if suc then
				bedwars.SoundManager:playSound(bedwars.SoundList.BEDWARS_PURCHASE_ITEM)
				bedwars.Store:dispatch({
					type = 'BedwarsAddItemPurchased',
					itemType = item.itemType
				})
			end
		end)
		currencytable[item.currency] -= item.price
	end
	
	local function buyUpgrade(upgradeType, currencytable)
		if not Upgrades.Enabled then return end
		local upgrade = bedwars.TeamUpgradeMeta[upgradeType]
		local currentUpgrades = bedwars.Store:getState().Bedwars.teamUpgrades[lplr:GetAttribute('Team')] or {}
		local currentTier = (currentUpgrades[upgradeType] or 0) + 1
		local bought = false
	
		for i = currentTier, #upgrade.tiers do
			local tier = upgrade.tiers[i]
			if tier.availableOnlyInQueue and not table.find(tier.availableOnlyInQueue, store.queueType) then continue end
	
			if canBuy({currency = 'diamond', price = tier.cost}, currencytable) then
				notif('AutoBuy', 'Bought '..(upgrade.name == 'Armor' and 'Protection' or upgrade.name)..' '..i, 3)
				bedwars.Client:Get('RequestPurchaseTeamUpgrade'):CallServerAsync(upgradeType)
				currencytable.diamond -= tier.cost
				bought = true
			else
				break
			end
		end
	
		return bought
	end
	
	local function buyTool(tool, tools, currencytable)
		local bought, buyable = false
		tool = tool and table.find(tools, tool.itemType) and table.find(tools, tool.itemType) + 1 or math.huge
	
		for i = tool, #tools do
			local v = bedwars.Shop.getShopItem(tools[i], lplr)
			if canBuy(v, currencytable) then
				if SmartCheck.Enabled and bedwars.ItemMeta[tools[i]].breakBlock and i > 2 then
					if Armor.Enabled then
						local currentarmor = store.inventory.inventory.armor[2]
						currentarmor = currentarmor and currentarmor ~= 'empty' and currentarmor.itemType or 'none'
						if (table.find(armors, currentarmor) or 3) < 3 then break end
					end
					if Sword.Enabled then
						if store.tools.sword and (table.find(swords, store.tools.sword.itemType) or 2) < 2 then break end
					end
				end
				bought = true
				buyable = v
			end
			if TierCheck.Enabled and v.nextTier then break end
		end
	
		if buyable then
			buyItem(buyable, currencytable)
		end
	
		return bought
	end
	
	AutoBuy = vape.Categories.Inventory:CreateModule({
		Name = 'AutoBuy',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.queueType ~= 'bedwars_test'
				if BedwarsCheck.Enabled and not store.queueType:find('bedwars') then return end
	
				local lastupgrades
				AutoBuy:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(function()
					if (npctick - tick()) > 1 then npctick = tick() end
				end))
	
				repeat
					local npc, shop, upgrades, newid = getShopNPC()
					id = newid
					if GUI.Enabled then
						if not (bedwars.AppController:isAppOpen('BedwarsItemShopApp') or bedwars.AppController:isAppOpen('TeamUpgradeApp')) then
							npc = nil
						end
					end
	
					if npc and lastupgrades ~= upgrades then
						if (npctick - tick()) > 1 then npctick = tick() end
						lastupgrades = upgrades
					end
	
					if npc and npctick <= tick() and store.matchState ~= 2 and store.shopLoaded then
						local currencytable = {}
						local waitcheck
						for _, tab in Callbacks do
							for _, callback in tab do
								if callback(currencytable, shop, upgrades) then
									waitcheck = true
								end
							end
						end
						npctick = tick() + (waitcheck and 0.4 or math.huge)
					end
	
					task.wait(0.1)
				until not AutoBuy.Enabled
			else
				npctick = tick()
			end
		end,
		Tooltip = 'Automatically buys items when you go near the shop'
	})
	Sword = AutoBuy:CreateToggle({
		Name = 'Buy Sword',
		Function = function(callback)
			npctick = tick()
			Functions[2] = callback and function(currencytable, shop)
				if not shop then return end
	
				if store.equippedKit == 'dasher' then
					swords = {
						[1] = 'wood_dao',
						[2] = 'stone_dao',
						[3] = 'iron_dao',
						[4] = 'diamond_dao',
						[5] = 'emerald_dao'
					}
				elseif store.equippedKit == 'ice_queen' then
					swords[5] = 'ice_sword'
				elseif store.equippedKit == 'ember' then
					swords[5] = 'infernal_saber'
				elseif store.equippedKit == 'lumen' then
					swords[5] = 'light_sword'
				end
	
				return buyTool(store.tools.sword, swords, currencytable)
			end or nil
		end
	})
	Armor = AutoBuy:CreateToggle({
		Name = 'Buy Armor',
		Function = function(callback)
			npctick = tick()
			Functions[1] = callback and function(currencytable, shop)
				if not shop then return end
				local currentarmor = store.inventory.inventory.armor[2] ~= 'empty' and store.inventory.inventory.armor[2] or getBestArmor(1)
				currentarmor = currentarmor and currentarmor.itemType or 'none'
				return buyTool({itemType = currentarmor}, armors, currencytable)
			end or nil
		end,
		Default = true
	})
	AutoBuy:CreateToggle({
		Name = 'Buy Axe',
		Function = function(callback)
			npctick = tick()
			Functions[3] = callback and function(currencytable, shop)
				if not shop then return end
				return buyTool(store.tools.wood or {itemType = 'none'}, axes, currencytable)
			end or nil
		end
	})
	AutoBuy:CreateToggle({
		Name = 'Buy Pickaxe',
		Function = function(callback)
			npctick = tick()
			Functions[4] = callback and function(currencytable, shop)
				if not shop then return end
				return buyTool(store.tools.stone, pickaxes, currencytable)
			end or nil
		end
	})
	Upgrades = AutoBuy:CreateToggle({
		Name = 'Buy Upgrades',
		Function = function(callback)
			for _, v in UpgradeToggles do
				v.Object.Visible = callback
			end
		end,
		Default = true
	})
	local count = 0
	for i, v in bedwars.TeamUpgradeMeta do
		local toggleCount = count
		table.insert(UpgradeToggles, AutoBuy:CreateToggle({
			Name = 'Buy '..(v.name == 'Armor' and 'Protection' or v.name),
			Function = function(callback)
				npctick = tick()
				Functions[5 + toggleCount + (v.name == 'Armor' and 20 or 0)] = callback and function(currencytable, shop, upgrades)
					if not upgrades then return end
					if v.disabledInQueue and table.find(v.disabledInQueue, store.queueType) then return end
					return buyUpgrade(i, currencytable)
				end or nil
			end,
			Darker = true,
			Default = (i == 'ARMOR' or i == 'DAMAGE')
		}))
		count += 1
	end
	TierCheck = AutoBuy:CreateToggle({Name = 'Tier Check'})
	BedwarsCheck = AutoBuy:CreateToggle({
		Name = 'Only Bedwars',
		Function = function()
			if AutoBuy.Enabled then
				AutoBuy:Toggle()
				AutoBuy:Toggle()
			end
		end,
		Default = true
	})
	GUI = AutoBuy:CreateToggle({Name = 'GUI check'})
	SmartCheck = AutoBuy:CreateToggle({
		Name = 'Smart check',
		Default = true,
		Tooltip = 'Buys iron armor before iron axe'
	})
	local KeepBuying = AutoBuy:CreateToggle({
		Name = 'Keep Buying',
		Tooltip = 'Always buys the set amount from item list, ignoring current inventory',
		Function = function(callback)
			if callback then
				npctick = tick()
			end
		end
	})
	AutoBuy:CreateTextList({
		Name = 'Item',
		Placeholder = 'priority/item/amount/skip50',
		Function = function(list)
			table.clear(Custom)
			table.clear(CustomPost)
			for _, entry in list do
				local tab = entry:split('/')
				local ind = tonumber(tab[1])
				if ind then
					local isPost = tab[4] and tab[4]:lower():find('after')
					local skipAmount = tab[4] and tonumber(tab[4]:match('%d+')) or nil
					
					(isPost and CustomPost or Custom)[ind] = function(currencytable, shop)
						if not shop then return end
						if not store.shopLoaded then return end
						
						local success, v = pcall(function()
							return bedwars.Shop.getShopItem(tab[2], lplr)
						end)
						
						if not success or not v then
							return false
						end
						
						local item = getItem(tab[2] == 'wool_white' and bedwars.Shop.getTeamWool(lplr:GetAttribute('Team')) or tab[2])
						local currentAmount = item and item.amount or 0
						local targetAmount = tonumber(tab[3])
						
						if tab[2] == 'arrow' and skipAmount then
							local hasBow = getBow()
							local hasCrossbow = getItem('crossbow')
							local hasHeadhunter = getItem('headhunter_bow')
							if not (hasBow or hasCrossbow or hasHeadhunter) then
								return false
							end
						end
						
						if KeepBuying.Enabled then
							local purchasesNeeded = math.ceil(targetAmount / v.amount)
							
							if purchasesNeeded > 0 and canBuy(v, currencytable, purchasesNeeded) then
								for _ = 1, purchasesNeeded do
									buyItem(v, currencytable)
								end
								return true
							end
						else
							local needToBuy = math.max(0, targetAmount - currentAmount)
							
							if needToBuy <= 0 then
								return false
							end

							if skipAmount and currentAmount >= skipAmount then
								return false
							end
							
							local purchasesNeeded = math.ceil(needToBuy / v.amount)
							
							if canBuy(v, currencytable, purchasesNeeded) then
								for _ = 1, purchasesNeeded do
									buyItem(v, currencytable)
								end
								return true
							end
						end
						
						return false
					end
				end
			end
		end
	})
end)

run(function()
    HitFix = vape.Categories.Blatant:CreateModule({
        Name = 'HitFix',
        Function = function(callback)
            if callback then
                pcall(function()
                    if bedwars.SwordController and bedwars.SwordController.swingSwordAtMouse then
                        debug.setconstant(bedwars.SwordController.swingSwordAtMouse, 23, 'raycast')
                        debug.setupvalue(bedwars.SwordController.swingSwordAtMouse, 4, bedwars.QueryUtil)

                        local constants = debug.getconstants(bedwars.SwordController.swingSwordAtMouse)
                        for i, v in ipairs(constants) do
                            if v == 0.15 then
                                debug.setconstant(bedwars.SwordController.swingSwordAtMouse, i, 0.1)
                            end
                        end
                    end
                end)
                
                pcall(function()
                    local oldSwing = bedwars.SwordController.swingSword
                    bedwars.SwordController.swingSword = function(...)
                        local args = {...}
                        return oldSwing(...)
                    end
                end)
            else
                pcall(function()
                    if bedwars.SwordController and bedwars.SwordController.swingSwordAtMouse then
                        debug.setconstant(bedwars.SwordController.swingSwordAtMouse, 23, 'Raycast')
                        debug.setupvalue(bedwars.SwordController.swingSwordAtMouse, 4, workspace)
                        
                        local constants = debug.getconstants(bedwars.SwordController.swingSwordAtMouse)
                        for i, v in ipairs(constants) do
                            if v == 0.1 then
                                debug.setconstant(bedwars.SwordController.swingSwordAtMouse, i, 0.15)
                            end
                        end
                    end
                end)
            end
        end,
        Tooltip = 'Improves hit registration and reduces ghost hits'
    })
end)

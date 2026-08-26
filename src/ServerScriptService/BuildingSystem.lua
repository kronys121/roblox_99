-- Places crafted Buildables into the world, grid-snapped, with tracked
-- durability (Health/MaxHealth attributes). The client sends a desired
-- CFrame (from its placement preview); the server re-validates distance,
-- snaps it to the grid, and spends from the shared Warehouse Buildable
-- stock -- never trusting the client's placement or inventory claims.
--
-- Exposes FindNearestStructure/DamageStructure so EnemySpawner's AI can
-- attack fortifications blocking their path to a player.

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlaceBuilding = Remotes:WaitForChild("PlaceBuilding")
local Notify = Remotes:WaitForChild("Notify")

local Warehouse = require(script.Parent:WaitForChild("Warehouse"))

local BuildingSystem = {}

local placedStructures = {} -- [Model] = true

local function snapToGrid(position)
	local gridSize = GameConfig.Building.GridSize
	return Vector3.new(
		math.floor(position.X / gridSize + 0.5) * gridSize,
		position.Y,
		math.floor(position.Z / gridSize + 0.5) * gridSize
	)
end

local function finalizeStructure(model, itemName, primaryPart)
	model.PrimaryPart = primaryPart

	local maxHealth = (GameConfig.Building.Structures[itemName] or { MaxHealth = 100 }).MaxHealth
	model:SetAttribute("StructureType", itemName)
	model:SetAttribute("Health", maxHealth)
	model:SetAttribute("MaxHealth", maxHealth)
	CollectionService:AddTag(model, "Structure")

	local repairPrompt = Instance.new("ProximityPrompt")
	repairPrompt.ActionText = "Repair"
	repairPrompt.ObjectText = itemName
	repairPrompt.HoldDuration = 1
	repairPrompt.MaxActivationDistance = 10
	repairPrompt.Parent = primaryPart

	repairPrompt.Triggered:Connect(function(player)
		local health = model:GetAttribute("Health") or 0
		local max = model:GetAttribute("MaxHealth") or health
		if health >= max then
			Notify:FireClient(player, itemName .. " is already at full health.")
			return
		end
		if not Warehouse.SpendResources(GameConfig.Building.RepairCost) then
			Notify:FireClient(player, "Not enough resources in the Warehouse to repair.")
			return
		end
		model:SetAttribute("Health", math.min(max, health + GameConfig.Building.RepairAmount))
	end)

	placedStructures[model] = true
	model.Destroying:Connect(function()
		placedStructures[model] = nil
	end)

	if itemName == "SpikeTrap" then
		task.spawn(function()
			local Enemies = Workspace:WaitForChild("Enemies")
			while model.Parent do
				task.wait(GameConfig.Building.TrapInterval)
				if not model.PrimaryPart then
					continue
				end
				for _, enemyModel in ipairs(Enemies:GetChildren()) do
					local enemyRoot = enemyModel.PrimaryPart
					local enemyHumanoid = enemyModel:FindFirstChildOfClass("Humanoid")
					if enemyRoot and enemyHumanoid and enemyHumanoid.Health > 0 then
						local dist = (enemyRoot.Position - model.PrimaryPart.Position).Magnitude
						if dist <= GameConfig.Building.TrapRadius then
							enemyHumanoid:TakeDamage(GameConfig.Building.TrapDamage)
						end
					end
				end
			end
		end)
	end

	return model
end

local function buildCampfire(cframe)
	local model = Instance.new("Model")
	model.Name = "Campfire"

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(4, 1, 4)
	base.Anchored = true
	base.CanCollide = true
	base.Material = Enum.Material.Rock
	base.Color = Color3.fromRGB(80, 80, 80)
	base.CFrame = cframe
	base.Parent = model

	local flame = Instance.new("Part")
	flame.Name = "Flame"
	flame.Size = Vector3.new(1.5, 2, 1.5)
	flame.Shape = Enum.PartType.Cylinder
	flame.Anchored = true
	flame.CanCollide = false
	flame.Material = Enum.Material.Neon
	flame.Color = Color3.fromRGB(255, 140, 40)
	flame.CFrame = cframe * CFrame.new(0, 1.5, 0)
	flame.Parent = model

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 60)
	light.Range = 20
	light.Brightness = 2
	light.Parent = flame

	return model, base
end

local function buildWall(cframe, height, thickness, color, material)
	local wall = Instance.new("Part")
	wall.Name = "Wall"
	wall.Size = Vector3.new(8, height, thickness)
	wall.Anchored = true
	wall.CanCollide = true
	wall.Material = material
	wall.Color = color
	wall.CFrame = cframe

	local model = Instance.new("Model")
	wall.Parent = model
	return model, wall
end

local function buildWoodWall(cframe)
	return buildWall(cframe, 6, 1, Color3.fromRGB(110, 80, 55), Enum.Material.WoodPlanks)
end

local function buildWoodDoor(cframe)
	local model, door = buildWall(cframe, 7, 0.6, Color3.fromRGB(95, 65, 45), Enum.Material.WoodPlanks)
	model.Name = "WoodDoor"
	return model, door
end

local function buildReinforcedWall(cframe)
	local model, wall = buildWall(cframe, 6, 1.5, Color3.fromRGB(120, 120, 130), Enum.Material.Metal)
	model.Name = "ReinforcedWall"
	return model, wall
end

local function buildSpikeTrap(cframe)
	local model = Instance.new("Model")
	model.Name = "SpikeTrap"

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(4, 0.4, 4)
	base.Anchored = true
	base.CanCollide = true
	base.Material = Enum.Material.Metal
	base.Color = Color3.fromRGB(70, 70, 75)
	base.CFrame = cframe
	base.Parent = model

	for i = 1, 5 do
		local spike = Instance.new("Part")
		spike.Name = "Spike"
		spike.Shape = Enum.PartType.Cylinder
		spike.Size = Vector3.new(1.2, 0.3, 0.3)
		spike.Anchored = true
		spike.CanCollide = false
		spike.Material = Enum.Material.Metal
		spike.Color = Color3.fromRGB(150, 150, 155)
		local offset = Vector3.new(math.random(-15, 15) / 10, 0, math.random(-15, 15) / 10)
		spike.CFrame = (cframe * CFrame.new(offset.X, 0.8, offset.Z)) * CFrame.Angles(0, 0, math.rad(90))
		spike.Parent = model
	end

	return model, base
end

local function buildWatchTower(cframe)
	local model = Instance.new("Model")
	model.Name = "WatchTower"

	local pillarHeight = 16
	local pillar = Instance.new("Part")
	pillar.Name = "Pillar"
	pillar.Size = Vector3.new(3, pillarHeight, 3)
	pillar.Anchored = true
	pillar.CanCollide = true
	pillar.Material = Enum.Material.WoodPlanks
	pillar.Color = Color3.fromRGB(100, 72, 48)
	pillar.CFrame = cframe * CFrame.new(0, pillarHeight / 2, 0)
	pillar.Parent = model

	local platform = Instance.new("Part")
	platform.Name = "Platform"
	platform.Size = Vector3.new(8, 1, 8)
	platform.Anchored = true
	platform.CanCollide = true
	platform.Material = Enum.Material.WoodPlanks
	platform.Color = Color3.fromRGB(120, 90, 60)
	platform.CFrame = cframe * CFrame.new(0, pillarHeight, 0)
	platform.Parent = model

	return model, pillar
end

local builders = {
	Campfire = buildCampfire,
	WoodWall = buildWoodWall,
	WoodDoor = buildWoodDoor,
	SpikeTrap = buildSpikeTrap,
	WatchTower = buildWatchTower,
	ReinforcedWall = buildReinforcedWall,
}

function BuildingSystem.FindNearestStructure(position, maxDistance)
	local nearest, nearestDist = nil, maxDistance
	for model in pairs(placedStructures) do
		if model.Parent and model.PrimaryPart then
			local dist = (model.PrimaryPart.Position - position).Magnitude
			if dist <= nearestDist then
				nearest, nearestDist = model, dist
			end
		end
	end
	return nearest, nearestDist
end

function BuildingSystem.DamageStructure(model, amount)
	if not model or not model.Parent then
		return
	end
	local health = (model:GetAttribute("Health") or 0) - amount
	if health <= 0 then
		placedStructures[model] = nil
		model:Destroy()
	else
		model:SetAttribute("Health", health)
	end
end

function BuildingSystem.Start()
	PlaceBuilding.OnServerEvent:Connect(function(player, itemName, cframe)
		local builder = builders[itemName]
		if not builder or typeof(cframe) ~= "CFrame" then
			return
		end

		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			return
		end

		local distance = (rootPart.Position - cframe.Position).Magnitude
		if distance > GameConfig.Building.MaxPlaceDistance then
			return
		end

		if not Warehouse.ConsumeBuildable(itemName) then
			Notify:FireClient(player, "No " .. itemName .. " in the Warehouse to place.")
			return
		end

		local snappedPosition = snapToGrid(cframe.Position)
		local snappedCFrame = CFrame.new(snappedPosition) * (cframe - cframe.Position)

		local playerBuildings = Workspace:FindFirstChild("PlayerBuildings")
		local model, primaryPart = builder(snappedCFrame)
		finalizeStructure(model, itemName, primaryPart)
		model.Parent = playerBuildings or Workspace
	end)
end

return BuildingSystem

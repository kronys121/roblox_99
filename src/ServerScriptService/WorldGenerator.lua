-- Procedurally builds the forest map: ground, spawn point, and scattered
-- resource nodes (trees, rocks, bushes). Runs once at server start so the
-- place is playable without any hand-authored map assets.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("GameConfig"))

local WorldGenerator = {}

local function newPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		part[key] = value
	end
	return part
end

local function buildGround()
	local size = GameConfig.World.GroundSize
	local ground = newPart({
		Name = "Ground",
		Size = size,
		Position = Vector3.new(0, -size.Y / 2, 0),
		Color = Color3.fromRGB(58, 92, 47),
		Material = Enum.Material.Grass,
		Parent = Workspace,
	})
	return ground
end

local function buildSpawn()
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MainSpawn"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(0, 1, 0)
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Material = Enum.Material.WoodPlanks
	spawn.Color = Color3.fromRGB(120, 85, 60)
	spawn.Duration = 0
	spawn.Parent = Workspace
	return spawn
end

local function randomPointOnGround(margin)
	local size = GameConfig.World.GroundSize
	local halfX = size.X / 2 - margin
	local halfZ = size.Z / 2 - margin
	return Vector3.new(
		math.random(-halfX, halfX),
		0,
		math.random(-halfZ, halfZ)
	)
end

-- Keeps nodes from spawning on top of the spawn platform.
local function isTooCloseToSpawn(point)
	return (Vector3.new(point.X, 0, point.Z)).Magnitude < 25
end

local function buildTree(folder, point)
	local model = Instance.new("Model")
	model.Name = "Tree"

	local trunkHeight = math.random(6, 10)
	local trunk = newPart({
		Name = "Trunk",
		Size = Vector3.new(2, trunkHeight, 2),
		Position = point + Vector3.new(0, trunkHeight / 2, 0),
		Color = Color3.fromRGB(90, 62, 40),
		Material = Enum.Material.Wood,
		Parent = model,
	})

	local leaves = newPart({
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(8, 8, 8),
		Position = point + Vector3.new(0, trunkHeight + 2, 0),
		Color = Color3.fromRGB(38, 82, 40),
		Material = Enum.Material.Grass,
		Parent = model,
	})

	model.PrimaryPart = trunk

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Chop"
	prompt.ObjectText = "Tree"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.Parent = trunk

	model:SetAttribute("ResourceType", "Tree")
	model:SetAttribute("Health", GameConfig.Resources.Tree.Health)
	model:SetAttribute("MaxHealth", GameConfig.Resources.Tree.Health)
	CollectionService:AddTag(model, "ResourceNode")

	model.Parent = folder
	return model, leaves
end

local function buildRock(folder, point)
	local size = Vector3.new(math.random(4, 6), math.random(3, 4), math.random(4, 6))
	local rock = newPart({
		Name = "Rock",
		Size = size,
		Position = point + Vector3.new(0, size.Y / 2, 0),
		Color = Color3.fromRGB(110, 110, 110),
		Material = Enum.Material.Rock,
	})

	local model = Instance.new("Model")
	model.Name = "Rock"
	rock.Parent = model
	model.PrimaryPart = rock

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Mine"
	prompt.ObjectText = "Rock"
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 10
	prompt.Parent = rock

	model:SetAttribute("ResourceType", "Rock")
	model:SetAttribute("Health", GameConfig.Resources.Rock.Health)
	model:SetAttribute("MaxHealth", GameConfig.Resources.Rock.Health)
	CollectionService:AddTag(model, "ResourceNode")

	model.Parent = folder
	return model, rock
end

local function buildBush(folder, point)
	local bush = newPart({
		Name = "Bush",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 2.5, 3),
		Position = point + Vector3.new(0, 1.25, 0),
		Color = Color3.fromRGB(52, 100, 46),
		Material = Enum.Material.Grass,
	})

	local model = Instance.new("Model")
	model.Name = "Bush"
	bush.Parent = model
	model.PrimaryPart = bush

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick"
	prompt.ObjectText = "Berries"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 8
	prompt.Parent = bush

	model:SetAttribute("ResourceType", "Bush")
	model:SetAttribute("Health", GameConfig.Resources.Bush.Health)
	model:SetAttribute("MaxHealth", GameConfig.Resources.Bush.Health)
	CollectionService:AddTag(model, "ResourceNode")

	model.Parent = folder
	return model, bush
end

function WorldGenerator.Generate()
	buildGround()
	buildSpawn()

	local nodesFolder = Instance.new("Folder")
	nodesFolder.Name = "ResourceNodes"
	nodesFolder.Parent = Workspace

	for _ = 1, GameConfig.World.TreeCount do
		local point = randomPointOnGround(15)
		if not isTooCloseToSpawn(point) then
			buildTree(nodesFolder, point)
		end
	end

	for _ = 1, GameConfig.World.RockCount do
		local point = randomPointOnGround(15)
		if not isTooCloseToSpawn(point) then
			buildRock(nodesFolder, point)
		end
	end

	for _ = 1, GameConfig.World.BushCount do
		local point = randomPointOnGround(15)
		if not isTooCloseToSpawn(point) then
			buildBush(nodesFolder, point)
		end
	end

	local buildablesFolder = Instance.new("Folder")
	buildablesFolder.Name = "PlayerBuildings"
	buildablesFolder.Parent = Workspace

	local enemiesFolder = Instance.new("Folder")
	enemiesFolder.Name = "Enemies"
	enemiesFolder.Parent = Workspace
end

return WorldGenerator

-- Places crafted buildables into the world. The client sends a desired
-- CFrame (from its placement preview); the server re-validates distance
-- and inventory before actually creating anything, since the client
-- cannot be trusted.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlaceBuilding = Remotes:WaitForChild("PlaceBuilding")

local PlayerDataManager = require(script.Parent:WaitForChild("PlayerDataManager"))

local BuildingSystem = {}

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

	model.PrimaryPart = base
	return model
end

local function buildWoodWall(cframe)
	local wall = Instance.new("Part")
	wall.Name = "WoodWall"
	wall.Size = Vector3.new(8, 6, 1)
	wall.Anchored = true
	wall.CanCollide = true
	wall.Material = Enum.Material.WoodPlanks
	wall.Color = Color3.fromRGB(110, 80, 55)
	wall.CFrame = cframe

	local model = Instance.new("Model")
	model.Name = "WoodWall"
	wall.Parent = model
	model.PrimaryPart = wall
	return model
end

local builders = {
	Campfire = buildCampfire,
	WoodWall = buildWoodWall,
}

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

		if not PlayerDataManager.ConsumeBuildable(player, itemName) then
			return
		end

		local playerBuildings = Workspace:FindFirstChild("PlayerBuildings")
		local model = builder(cframe)
		model.Parent = playerBuildings or Workspace
	end)
end

return BuildingSystem

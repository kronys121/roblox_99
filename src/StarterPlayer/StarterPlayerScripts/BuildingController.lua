-- Placement mode for crafted buildables. Cycle items with "B"/"Tab",
-- move the mouse to aim a grid-snapped ghost preview along the ground,
-- left-click to place. The server re-validates and re-snaps everything;
-- this is purely a preview.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer

local BuildingController = {}

local GHOST_TEMPLATES = {
	Campfire = { Size = Vector3.new(4, 2, 4), Color = Color3.fromRGB(255, 140, 40) },
	WoodWall = { Size = Vector3.new(8, 6, 1), Color = Color3.fromRGB(110, 80, 55) },
	WoodDoor = { Size = Vector3.new(8, 7, 0.6), Color = Color3.fromRGB(95, 65, 45) },
	SpikeTrap = { Size = Vector3.new(4, 0.4, 4), Color = Color3.fromRGB(70, 70, 75) },
	WatchTower = { Size = Vector3.new(8, 16, 8), Color = Color3.fromRGB(110, 82, 54) },
	ReinforcedWall = { Size = Vector3.new(8, 6, 1.5), Color = Color3.fromRGB(120, 120, 130) },
}

local BUILDABLE_ORDER = { "Campfire", "WoodWall", "WoodDoor", "SpikeTrap", "WatchTower", "ReinforcedWall" }

local function snapToGrid(position)
	local gridSize = GameConfig.Building.GridSize
	return Vector3.new(
		math.floor(position.X / gridSize + 0.5) * gridSize,
		position.Y,
		math.floor(position.Z / gridSize + 0.5) * gridSize
	)
end

function BuildingController.Init(hud)
	local owned = {}
	for _, name in ipairs(BUILDABLE_ORDER) do
		owned[name] = 0
	end

	local selectedIndex = 1
	local buildModeActive = false
	local ghost = nil

	local function currentItem()
		return BUILDABLE_ORDER[selectedIndex]
	end

	local function destroyGhost()
		if ghost then
			ghost:Destroy()
			ghost = nil
		end
	end

	local function createGhost(itemName)
		destroyGhost()
		local template = GHOST_TEMPLATES[itemName]
		if not template then
			return
		end
		local part = Instance.new("Part")
		part.Name = "PlacementGhost"
		part.Size = template.Size
		part.Color = template.Color
		part.Material = Enum.Material.ForceField
		part.Transparency = 0.5
		part.CanCollide = false
		part.Anchored = true
		part.Parent = Workspace
		ghost = part
	end

	local function setBuildMode(active)
		buildModeActive = active
		if active and owned[currentItem()] and owned[currentItem()] > 0 then
			createGhost(currentItem())
			hud.ShowToast("Build mode: " .. currentItem())
		else
			destroyGhost()
			if active then
				hud.ShowToast("You have none of that to place")
			end
		end
	end

	Remotes.BuildablesUpdated.OnClientEvent:Connect(function(counts)
		for name, amount in pairs(counts) do
			owned[name] = amount
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end

		if input.KeyCode == Enum.KeyCode.B then
			setBuildMode(not buildModeActive)
		elseif input.KeyCode == Enum.KeyCode.Tab and buildModeActive then
			selectedIndex = (selectedIndex % #BUILDABLE_ORDER) + 1
			createGhost(currentItem())
			hud.ShowToast("Selected: " .. currentItem())
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and buildModeActive and ghost then
			local itemName = currentItem()
			if (owned[itemName] or 0) > 0 then
				Remotes.PlaceBuilding:FireServer(itemName, ghost.CFrame)
			else
				hud.ShowToast("You have none of that to place")
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		if not buildModeActive or not ghost then
			return
		end

		local mouse = player:GetMouse()
		local target = mouse.Hit
		if target then
			local size = ghost.Size
			local snapped = snapToGrid(target.Position)
			ghost.CFrame = CFrame.new(snapped + Vector3.new(0, size.Y / 2, 0))
		end
	end)

	return {
		Toggle = function()
			setBuildMode(not buildModeActive)
		end,
	}
end

return BuildingController

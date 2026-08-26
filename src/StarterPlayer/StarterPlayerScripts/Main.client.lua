-- Client entry point: wires up the HUD, crafting menu, building mode,
-- and sprint input.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local HUDController = require(script.Parent:WaitForChild("HUDController"))
local CraftingController = require(script.Parent:WaitForChild("CraftingController"))
local BuildingController = require(script.Parent:WaitForChild("BuildingController"))

local hud = HUDController.Init()
CraftingController.Init(hud)
BuildingController.Init(hud)

local sprinting = false

local function setSprinting(value)
	if sprinting == value then
		return
	end
	sprinting = value
	Remotes.SetSprinting:FireServer(sprinting)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		setSprinting(true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		setSprinting(false)
	end
end)

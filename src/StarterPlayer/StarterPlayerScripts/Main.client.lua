-- Client entry point: wires up the HUD, crafting menu, building mode,
-- shop, leaderboard, and sprint input.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local HUDController = require(script.Parent:WaitForChild("HUDController"))
local CraftingController = require(script.Parent:WaitForChild("CraftingController"))
local BuildingController = require(script.Parent:WaitForChild("BuildingController"))
local ShopController = require(script.Parent:WaitForChild("ShopController"))
local LeaderboardController = require(script.Parent:WaitForChild("LeaderboardController"))
local ActionBarController = require(script.Parent:WaitForChild("ActionBarController"))

local hud = HUDController.Init()
local crafting = CraftingController.Init(hud)
local building = BuildingController.Init(hud)
local shop = ShopController.Init(hud)
local leaderboard = LeaderboardController.Init(hud)

ActionBarController.Init(hud, {
	crafting.Toggle,
	building.Toggle,
	shop.Toggle,
	leaderboard.Toggle,
})

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

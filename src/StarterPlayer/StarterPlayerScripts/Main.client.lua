-- Client entry point: wires up the HUD, crafting menu, building mode,
-- inventory, shop, leaderboard, and sprint input.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local HUDController = require(script.Parent:WaitForChild("HUDController"))
local CraftingController = require(script.Parent:WaitForChild("CraftingController"))
local BuildingController = require(script.Parent:WaitForChild("BuildingController"))
local InventoryController = require(script.Parent:WaitForChild("InventoryController"))
local ShopController = require(script.Parent:WaitForChild("ShopController"))
local LeaderboardController = require(script.Parent:WaitForChild("LeaderboardController"))
local ActionBarController = require(script.Parent:WaitForChild("ActionBarController"))

local hud = HUDController.Init()

-- Every menu/mode below closes all the others when it opens, since the
-- screen doesn't have room for more than one of these popups at once.
-- `menus` is filled in just after they're all created; closeAllMenus is
-- handed to each Init call as a closure over it, so the order here is
-- safe even though the list doesn't exist yet at that point.
local menus = {}
local function closeAllMenus()
	for _, menu in ipairs(menus) do
		menu.SetVisible(false)
	end
end

local crafting = CraftingController.Init(hud, closeAllMenus)
local building = BuildingController.Init(hud, closeAllMenus)
local inventory = InventoryController.Init(hud, closeAllMenus)
local shop = ShopController.Init(hud, closeAllMenus)
local leaderboard = LeaderboardController.Init(hud, closeAllMenus)

menus = { crafting, building, inventory, shop, leaderboard }

ActionBarController.Init(hud, {
	crafting.Toggle,
	building.Toggle,
	inventory.Toggle,
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

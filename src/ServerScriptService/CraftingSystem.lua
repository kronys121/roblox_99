-- Validates and fulfills craft requests. Tools are inserted directly into
-- the player's Backpack; Buildables are tracked as counts in
-- PlayerDataManager and placed later via BuildingSystem.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CraftItem = Remotes:WaitForChild("CraftItem")

local PlayerDataManager = require(script.Parent:WaitForChild("PlayerDataManager"))

local CraftingSystem = {}

local function playerHasTool(player, toolName)
	local character = player.Character
	local backpack = player:FindFirstChild("Backpack")
	if character and character:FindFirstChild(toolName) then
		return true
	end
	if backpack and backpack:FindFirstChild(toolName) then
		return true
	end
	return false
end

local function giveTool(player, toolName)
	local tool = Instance.new("Tool")
	tool.Name = toolName
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 2, 0.4)
	handle.Color = toolName == "Axe" and Color3.fromRGB(120, 80, 40) or Color3.fromRGB(90, 90, 100)
	handle.Material = Enum.Material.Wood
	handle.Parent = tool

	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		tool.Parent = backpack
	end
end

function CraftingSystem.Start()
	CraftItem.OnServerInvoke = function(player, itemName)
		local recipe = GameConfig.Recipes[itemName]
		if not recipe then
			return false, "Unknown recipe"
		end

		if recipe.Kind == "Tool" and playerHasTool(player, itemName) then
			return false, "Already own this tool"
		end

		if recipe.Kind == "Tool" and not player:FindFirstChild("Backpack") then
			return false, "Cannot craft right now"
		end

		if not PlayerDataManager.SpendResources(player, recipe.Cost) then
			return false, "Not enough resources"
		end

		if recipe.Kind == "Tool" then
			giveTool(player, itemName)
		elseif recipe.Kind == "Buildable" then
			PlayerDataManager.AddBuildable(player, itemName, 1)
		end

		return true, itemName
	end
end

return CraftingSystem

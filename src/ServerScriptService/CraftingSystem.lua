-- Validates and fulfills craft requests against the shared Warehouse
-- stockpile (never personal inventory, so crafting is a cooperative
-- action). Tools are inserted directly into the crafting player's
-- Backpack; Buildables are added to the shared Buildable stock for
-- anyone to place via BuildingSystem. `Requires` enforces the tool
-- prerequisite tree (Tier 1 -> 2 -> 3 -> 4).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CraftItem = Remotes:WaitForChild("CraftItem")

local Warehouse = require(script.Parent:WaitForChild("Warehouse"))
local GamePassService = require(script.Parent:WaitForChild("GamePassService"))

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

		if recipe.Requires and not playerHasTool(player, recipe.Requires) then
			return false, "Requires " .. recipe.Requires
		end

		if recipe.Kind == "Tool" and playerHasTool(player, itemName) then
			return false, "Already own this tool"
		end

		if recipe.Kind == "Tool" and not player:FindFirstChild("Backpack") then
			return false, "Cannot craft right now"
		end

		if not Warehouse.SpendResources(recipe.Cost) then
			return false, "Not enough resources in the Warehouse"
		end

		local craftTime = recipe.CraftTime or 0
		if craftTime > 0 and not GamePassService.PlayerOwnsEffect(player, "FastCraft") then
			task.wait(craftTime)
		end

		-- The player could have left mid-craft; refund the Warehouse and
		-- bail rather than granting a tool/buildable to nobody.
		if player.Parent == nil then
			for resourceName, amount in pairs(recipe.Cost) do
				Warehouse.AddResource(resourceName, amount)
			end
			return false, "Player left"
		end

		if recipe.Kind == "Tool" then
			giveTool(player, itemName)
		elseif recipe.Kind == "Buildable" then
			Warehouse.AddBuildable(itemName, 1)
		end

		return true, itemName
	end
end

return CraftingSystem

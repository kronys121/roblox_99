-- Handles gathering: a player triggers a ProximityPrompt on a resource
-- node, the node loses health, and once depleted it hides and respawns
-- after a cooldown. All yields are computed server-side.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local PlayerDataManager = require(script.Parent:WaitForChild("PlayerDataManager"))

local ResourceNodes = {}

local function equippedToolName(player)
	local character = player.Character
	if not character then
		return nil
	end
	local tool = character:FindFirstChildOfClass("Tool")
	return tool and tool.Name or nil
end

local function gatherAmountFor(player, resourceType)
	local tool = equippedToolName(player)
	if resourceType == "Tree" and tool == "Axe" then
		return GameConfig.GatherAmounts.Axe
	elseif resourceType == "Rock" and tool == "Pickaxe" then
		return GameConfig.GatherAmounts.Pickaxe
	end
	return GameConfig.GatherAmounts.BareHands
end

local function setNodeVisible(model, visible)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = visible and 0 or 1
			descendant.CanCollide = visible
		elseif descendant:IsA("ProximityPrompt") then
			descendant.Enabled = visible
		end
	end
end

local function respawnNode(model, resourceType)
	local config = GameConfig.Resources[resourceType]
	task.delay(config.RespawnTime, function()
		if not model or not model.Parent then
			return
		end
		model:SetAttribute("Health", config.Health)
		setNodeVisible(model, true)
	end)
end

local function onNodeTriggered(prompt, player)
	local model = prompt:FindFirstAncestorOfClass("Model")
	if not model then
		return
	end

	local resourceType = model:GetAttribute("ResourceType")
	local config = GameConfig.Resources[resourceType]
	if not config then
		return
	end

	local health = model:GetAttribute("Health") or 0
	if health <= 0 then
		return
	end

	health -= 1
	model:SetAttribute("Health", health)

	local amount = gatherAmountFor(player, resourceType)
	PlayerDataManager.AddResource(player, config.Yields, amount)

	if health <= 0 then
		setNodeVisible(model, false)
		respawnNode(model, resourceType)
	end
end

function ResourceNodes.Start()
	for _, model in ipairs(CollectionService:GetTagged("ResourceNode")) do
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("ProximityPrompt") then
				descendant.Triggered:Connect(function(player)
					onNodeTriggered(descendant, player)
				end)
			end
		end
	end
end

return ResourceNodes

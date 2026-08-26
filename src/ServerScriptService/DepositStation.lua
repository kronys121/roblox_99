-- Wires up the Warehouse chest's ProximityPrompt (built by WorldGenerator)
-- so any player can empty their personal carry into the shared stockpile.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Notify = Remotes:WaitForChild("Notify")

local PlayerDataManager = require(script.Parent:WaitForChild("PlayerDataManager"))
local Warehouse = require(script.Parent:WaitForChild("Warehouse"))

local RESOURCE_NAMES = { "Wood", "Stone", "Berries", "Water", "RareMaterial" }

local DepositStation = {}

function DepositStation.Start()
	local warehouseFolder = Workspace:WaitForChild("Warehouse")
	local chest = warehouseFolder:WaitForChild("Chest")
	local prompt = chest:WaitForChild("ProximityPrompt")

	prompt.Triggered:Connect(function(player)
		local data = PlayerDataManager.Get(player)
		if not data then
			return
		end

		local depositedAny = false
		for _, name in ipairs(RESOURCE_NAMES) do
			local amount = data[name] or 0
			if amount > 0 then
				Warehouse.AddResource(name, amount)
				PlayerDataManager.SpendResources(player, { [name] = amount })
				depositedAny = true
			end
		end

		if depositedAny then
			Notify:FireClient(player, "Deposited your resources into the Warehouse.")
		else
			Notify:FireClient(player, "You have nothing to deposit.")
		end
	end)
end

return DepositStation

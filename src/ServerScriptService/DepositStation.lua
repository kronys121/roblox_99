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
	-- Runs in the background: if the Warehouse chest is ever missing
	-- (e.g. WorldGenerator failed), this waits forever rather than
	-- erroring, and must not block the rest of Main.server.lua's startup.
	task.spawn(function()
		local warehouseFolder = Workspace:WaitForChild("Warehouse", 10)
		local chest = warehouseFolder and warehouseFolder:WaitForChild("Chest", 10)
		local prompt = chest and chest:WaitForChild("ProximityPrompt", 10)

		if not prompt then
			warn("DepositStation: Warehouse chest/prompt never appeared; deposits are disabled.")
			return
		end

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
	end)
end

return DepositStation

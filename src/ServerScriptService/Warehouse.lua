-- The shared base stockpile: raw resources deposited by any player, and
-- crafted Buildables waiting to be placed. Crafting and building always
-- spend from here rather than from a personal inventory, which is what
-- makes gathering, crafting, and building a genuinely cooperative loop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local WarehouseUpdated = Remotes:WaitForChild("WarehouseUpdated")
local BuildablesUpdated = Remotes:WaitForChild("BuildablesUpdated")

local WorldStateStore = require(script.Parent:WaitForChild("WorldStateStore"))

local Warehouse = {}

local SAVE_INTERVAL = 10

local resources = WorldStateStore.LoadWarehouse()
local buildables = { Campfire = 0, WoodWall = 0, WoodDoor = 0, SpikeTrap = 0, WatchTower = 0, ReinforcedWall = 0 }
local dirty = false

local function broadcastResources()
	WarehouseUpdated:FireAllClients(resources)
end

local function broadcastBuildables()
	BuildablesUpdated:FireAllClients(buildables)
end

function Warehouse.Init()
	broadcastResources()
	broadcastBuildables()

	task.spawn(function()
		while true do
			task.wait(SAVE_INTERVAL)
			if dirty then
				dirty = false
				WorldStateStore.SaveWarehouse(resources)
			end
		end
	end)
end

function Warehouse.GetResources()
	return resources
end

function Warehouse.GetBuildables()
	return buildables
end

function Warehouse.AddResource(resourceName, amount)
	if resources[resourceName] == nil or amount == 0 then
		return
	end
	resources[resourceName] = math.max(0, resources[resourceName] + amount)
	dirty = true
	broadcastResources()
end

function Warehouse.HasResources(cost)
	for name, amount in pairs(cost) do
		if (resources[name] or 0) < amount then
			return false
		end
	end
	return true
end

function Warehouse.SpendResources(cost)
	if not Warehouse.HasResources(cost) then
		return false
	end
	for name, amount in pairs(cost) do
		resources[name] -= amount
	end
	dirty = true
	broadcastResources()
	return true
end

function Warehouse.AddBuildable(itemName, amount)
	buildables[itemName] = (buildables[itemName] or 0) + amount
	broadcastBuildables()
end

function Warehouse.ConsumeBuildable(itemName)
	if (buildables[itemName] or 0) <= 0 then
		return false
	end
	buildables[itemName] -= 1
	broadcastBuildables()
	return true
end

game:BindToClose(function()
	WorldStateStore.SaveWarehouse(resources)
end)

return Warehouse

-- Owns all per-player persisted state: resource counts and best night
-- reached. Exposes a small API other server modules use instead of
-- touching DataStores directly.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local InventoryUpdated = Remotes:WaitForChild("InventoryUpdated")
local BuildablesUpdated = Remotes:WaitForChild("BuildablesUpdated")

local store = DataStoreService:GetDataStore("PlayerData_v1")

local PlayerDataManager = {}
local dataByPlayer = {} -- [Player] = { Wood, Stone, Berries, BestNight, Buildables = {} }

local DEFAULT_DATA = {
	Wood = 0,
	Stone = 0,
	Berries = 0,
	BestNight = 0,
	Buildables = { Campfire = 0, WoodWall = 0 },
}

local function deepCopy(t)
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = (type(v) == "table") and deepCopy(v) or v
	end
	return copy
end

local function pushInventory(player)
	local data = dataByPlayer[player]
	if not data then
		return
	end
	InventoryUpdated:FireClient(player, {
		Wood = data.Wood,
		Stone = data.Stone,
		Berries = data.Berries,
	})
end

local function pushBuildables(player)
	local data = dataByPlayer[player]
	if not data then
		return
	end
	BuildablesUpdated:FireClient(player, data.Buildables)
end

local function ensureLeaderstats(player, data)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local nights = leaderstats:FindFirstChild("Best Night")
	if not nights then
		nights = Instance.new("IntValue")
		nights.Name = "Best Night"
		nights.Parent = leaderstats
	end
	nights.Value = data.BestNight
end

function PlayerDataManager.Load(player)
	local data = deepCopy(DEFAULT_DATA)

	local ok, result = pcall(function()
		return store:GetAsync("Player_" .. player.UserId)
	end)

	if ok and type(result) == "table" then
		data.Wood = result.Wood or 0
		data.Stone = result.Stone or 0
		data.Berries = result.Berries or 0
		data.BestNight = result.BestNight or 0
		data.Buildables = result.Buildables or deepCopy(DEFAULT_DATA.Buildables)
	elseif not ok then
		warn(("PlayerDataManager: failed to load data for %s: %s"):format(player.Name, tostring(result)))
	end

	dataByPlayer[player] = data
	ensureLeaderstats(player, data)
	pushInventory(player)
	pushBuildables(player)
end

function PlayerDataManager.Save(player)
	local data = dataByPlayer[player]
	if not data then
		return
	end

	local ok, err = pcall(function()
		store:SetAsync("Player_" .. player.UserId, data)
	end)

	if not ok then
		warn(("PlayerDataManager: failed to save data for %s: %s"):format(player.Name, tostring(err)))
	end
end

function PlayerDataManager.Release(player)
	PlayerDataManager.Save(player)
	dataByPlayer[player] = nil
end

function PlayerDataManager.Get(player)
	return dataByPlayer[player]
end

function PlayerDataManager.AddResource(player, resourceName, amount)
	local data = dataByPlayer[player]
	if not data or amount == 0 then
		return
	end
	data[resourceName] = math.max(0, (data[resourceName] or 0) + amount)
	pushInventory(player)
end

function PlayerDataManager.HasResources(player, cost)
	local data = dataByPlayer[player]
	if not data then
		return false
	end
	for resourceName, amount in pairs(cost) do
		if (data[resourceName] or 0) < amount then
			return false
		end
	end
	return true
end

function PlayerDataManager.SpendResources(player, cost)
	if not PlayerDataManager.HasResources(player, cost) then
		return false
	end
	local data = dataByPlayer[player]
	for resourceName, amount in pairs(cost) do
		data[resourceName] -= amount
	end
	pushInventory(player)
	return true
end

function PlayerDataManager.AddBuildable(player, itemName, amount)
	local data = dataByPlayer[player]
	if not data then
		return
	end
	data.Buildables[itemName] = (data.Buildables[itemName] or 0) + amount
	pushBuildables(player)
end

function PlayerDataManager.ConsumeBuildable(player, itemName)
	local data = dataByPlayer[player]
	if not data or (data.Buildables[itemName] or 0) <= 0 then
		return false
	end
	data.Buildables[itemName] -= 1
	pushBuildables(player)
	return true
end

function PlayerDataManager.ReportNight(player, night)
	local data = dataByPlayer[player]
	if not data then
		return
	end
	if night > data.BestNight then
		data.BestNight = night
		local leaderstats = player:FindFirstChild("leaderstats")
		local nights = leaderstats and leaderstats:FindFirstChild("Best Night")
		if nights then
			nights.Value = night
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	PlayerDataManager.Release(player)
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerDataManager.Save(player)
	end
end)

return PlayerDataManager

-- Owns per-player persisted state: personal carry (gathered resources not
-- yet deposited at the base Warehouse), best night reached, Embers
-- currency, and owned/active cosmetics. Shared/base-wide state (the
-- Warehouse stockpile, the current night) lives in Warehouse.lua and
-- WorldStateStore.lua instead.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local InventoryUpdated = Remotes:WaitForChild("InventoryUpdated")
local CurrencyUpdated = Remotes:WaitForChild("CurrencyUpdated")

local store = DataStoreService:GetDataStore("PlayerData_v2")

local GamePassService = require(script.Parent:WaitForChild("GamePassService"))

local PlayerDataManager = {}
local dataByPlayer = {} -- [Player] = { Wood, Stone, Berries, Water, RareMaterial, BestNight, Currency, OwnedCosmetics, ActiveCosmetic }

local RESOURCE_NAMES = { "Wood", "Stone", "Berries", "Water", "RareMaterial" }

local function defaultData()
	return {
		Wood = 0,
		Stone = 0,
		Berries = 0,
		Water = 0,
		RareMaterial = 0,
		BestNight = 0,
		Currency = 0,
		OwnedCosmetics = {},
		ActiveCosmetic = nil,
	}
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
		Water = data.Water,
		RareMaterial = data.RareMaterial,
	})
end

local function pushCurrency(player)
	local data = dataByPlayer[player]
	if not data then
		return
	end
	CurrencyUpdated:FireClient(player, {
		Currency = data.Currency,
		CurrencyName = GameConfig.Currency.Name,
		OwnedCosmetics = data.OwnedCosmetics,
		ActiveCosmetic = data.ActiveCosmetic,
	})
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
	-- Data exists with defaults the instant the player joins -- gathering,
	-- crafting, etc. all work immediately -- rather than waiting on the
	-- DataStore round-trip below, which can be slow or throttled
	-- (especially in Studio Play Solo testing). The real save, if any,
	-- merges in whenever it arrives.
	local data = defaultData()
	dataByPlayer[player] = data
	ensureLeaderstats(player, data)
	pushInventory(player)
	pushCurrency(player)

	task.spawn(function()
		local ok, result = pcall(function()
			return store:GetAsync("Player_" .. player.UserId)
		end)

		-- The player may have already left (or never really had this
		-- table, if two loads somehow raced) by the time this resolves.
		if dataByPlayer[player] ~= data then
			return
		end

		if ok and type(result) == "table" then
			for _, name in ipairs(RESOURCE_NAMES) do
				data[name] = result[name] or data[name]
			end
			data.BestNight = result.BestNight or data.BestNight
			data.Currency = result.Currency or data.Currency
			data.OwnedCosmetics = result.OwnedCosmetics or data.OwnedCosmetics
			data.ActiveCosmetic = result.ActiveCosmetic
			ensureLeaderstats(player, data)
			pushInventory(player)
			pushCurrency(player)
		elseif not ok then
			warn(("PlayerDataManager: failed to load data for %s: %s"):format(player.Name, tostring(result)))
		end
	end)
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

function PlayerDataManager.CarryCap(player)
	local cap = GameConfig.Carry.MaxPerResource
	if GamePassService.PlayerOwnsEffect(player, "ExtraCarry") then
		cap += GameConfig.Carry.ExtraCarryGamePassBonus
	end
	return cap
end

function PlayerDataManager.AddResource(player, resourceName, amount)
	local data = dataByPlayer[player]
	if not data or amount == 0 then
		return
	end
	local cap = amount > 0 and PlayerDataManager.CarryCap(player) or math.huge
	data[resourceName] = math.clamp((data[resourceName] or 0) + amount, 0, cap)
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

function PlayerDataManager.AddCurrency(player, amount)
	local data = dataByPlayer[player]
	if not data or amount == 0 then
		return
	end
	data.Currency = math.max(0, data.Currency + amount)
	pushCurrency(player)
end

function PlayerDataManager.SpendCurrency(player, amount)
	local data = dataByPlayer[player]
	if not data or (data.Currency or 0) < amount then
		return false
	end
	data.Currency -= amount
	pushCurrency(player)
	return true
end

function PlayerDataManager.OwnsCosmetic(player, cosmeticId)
	local data = dataByPlayer[player]
	if not data then
		return false
	end
	return table.find(data.OwnedCosmetics, cosmeticId) ~= nil
end

function PlayerDataManager.GrantCosmetic(player, cosmeticId)
	local data = dataByPlayer[player]
	if not data or PlayerDataManager.OwnsCosmetic(player, cosmeticId) then
		return
	end
	table.insert(data.OwnedCosmetics, cosmeticId)
	pushCurrency(player)
end

function PlayerDataManager.SetActiveCosmetic(player, cosmeticId)
	local data = dataByPlayer[player]
	if not data then
		return
	end
	if cosmeticId ~= nil and not PlayerDataManager.OwnsCosmetic(player, cosmeticId) then
		return
	end
	data.ActiveCosmetic = cosmeticId
	pushCurrency(player)
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

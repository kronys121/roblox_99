-- Persists shared run state -- the current night and the base Warehouse
-- stockpile -- so a server that restarts resumes the same run instead of
-- resetting to Night 0 with an empty stockpile. This is a single-run
-- coop game: both saves live under one fixed key each, not per player.

local DataStoreService = game:GetService("DataStoreService")

local store = DataStoreService:GetDataStore("WorldState_v1")
local NIGHT_KEY = "CurrentRun"
local WAREHOUSE_KEY = "Warehouse"

local DEFAULT_WAREHOUSE = { Wood = 0, Stone = 0, Berries = 0, Water = 0, RareMaterial = 0 }

local WorldStateStore = {}

function WorldStateStore.LoadNight()
	local ok, result = pcall(function()
		return store:GetAsync(NIGHT_KEY)
	end)

	if ok and type(result) == "table" and type(result.Night) == "number" then
		return result.Night
	end

	if not ok then
		warn("WorldStateStore: failed to load saved night: " .. tostring(result))
	end

	return 0
end

function WorldStateStore.SaveNight(night)
	local ok, err = pcall(function()
		store:SetAsync(NIGHT_KEY, { Night = night })
	end)

	if not ok then
		warn("WorldStateStore: failed to save night: " .. tostring(err))
	end
end

function WorldStateStore.LoadWarehouse()
	local stock = {}
	for name, default in pairs(DEFAULT_WAREHOUSE) do
		stock[name] = default
	end

	local ok, result = pcall(function()
		return store:GetAsync(WAREHOUSE_KEY)
	end)

	if ok and type(result) == "table" then
		for name in pairs(DEFAULT_WAREHOUSE) do
			if type(result[name]) == "number" then
				stock[name] = result[name]
			end
		end
	elseif not ok then
		warn("WorldStateStore: failed to load warehouse: " .. tostring(result))
	end

	return stock
end

function WorldStateStore.SaveWarehouse(stock)
	local ok, err = pcall(function()
		store:SetAsync(WAREHOUSE_KEY, stock)
	end)

	if not ok then
		warn("WorldStateStore: failed to save warehouse: " .. tostring(err))
	end
end

return WorldStateStore

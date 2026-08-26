-- Persists shared run state so a server that restarts resumes the same
-- run instead of restarting at Night 0. This is a single-run coop game:
-- the save lives under one fixed key, not per player.

local DataStoreService = game:GetService("DataStoreService")

local store = DataStoreService:GetDataStore("WorldState_v1")
local SAVE_KEY = "CurrentRun"

local WorldStateStore = {}

function WorldStateStore.LoadNight()
	local ok, result = pcall(function()
		return store:GetAsync(SAVE_KEY)
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
		store:SetAsync(SAVE_KEY, { Night = night })
	end)

	if not ok then
		warn("WorldStateStore: failed to save night: " .. tostring(err))
	end
end

return WorldStateStore

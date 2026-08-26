-- Global leaderboard of the best night reached, across every server.
-- Backed by an OrderedDataStore so ranking/sorting is handled for us.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetLeaderboard = Remotes:WaitForChild("GetLeaderboard")

local orderedStore = DataStoreService:GetOrderedDataStore("BestNightLeaderboard_v1")

local LeaderboardService = {}

function LeaderboardService.ReportScore(player, night)
	if night <= 0 then
		return
	end
	-- UpdateAsync (rather than SetAsync) so this can never downgrade a
	-- player's recorded best, e.g. if this world's run is shorter than
	-- one they previously played in.
	local ok, err = pcall(function()
		orderedStore:UpdateAsync("Player_" .. player.UserId, function(oldValue)
			return math.max(oldValue or 0, night)
		end)
	end)
	if not ok then
		warn("LeaderboardService: failed to report score: " .. tostring(err))
	end
end

local function fetchTop(limit)
	local ok, pages = pcall(function()
		return orderedStore:GetSortedAsync(false, limit)
	end)

	if not ok then
		warn("LeaderboardService: failed to fetch leaderboard: " .. tostring(pages))
		return {}
	end

	local results = {}
	for _, entry in ipairs(pages:GetCurrentPage()) do
		local userId = tonumber(entry.key:match("Player_(%d+)"))
		local name = "Unknown"

		if userId then
			local ok2, nameResult = pcall(function()
				return Players:GetNameFromUserIdAsync(userId)
			end)
			if ok2 then
				name = nameResult
			end
		end

		table.insert(results, { Name = name, Night = entry.value })
	end

	return results
end

function LeaderboardService.Start()
	GetLeaderboard.OnServerInvoke = function(_player, limit)
		limit = math.clamp(limit or 10, 1, 25)
		return fetchTop(limit)
	end
end

return LeaderboardService

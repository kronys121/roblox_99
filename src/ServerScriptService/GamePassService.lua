-- Checks Game Pass ownership for gameplay effects (extra carry capacity,
-- instant crafting). Entries in GameConfig.GamePasses with Id <= 0 are
-- "not configured yet" (no real Game Pass created for this experience
-- in the Creator Dashboard) and always report as not owned -- gameplay
-- simply behaves as the free-tier default until real IDs are added.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local GamePassService = {}

local ownershipCache = {} -- [UserId] = { [passId] = boolean }

function GamePassService.PlayerOwnsEffect(player, effectName)
	for _, pass in ipairs(GameConfig.GamePasses) do
		if pass.Effect == effectName and pass.Id > 0 then
			local userCache = ownershipCache[player.UserId]
			if userCache and userCache[pass.Id] ~= nil then
				if userCache[pass.Id] then
					return true
				end
			else
				local ok, owns = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
				end)

				ownershipCache[player.UserId] = ownershipCache[player.UserId] or {}
				ownershipCache[player.UserId][pass.Id] = ok and owns

				if ok and owns then
					return true
				end

				if not ok then
					warn("GamePassService: ownership check failed: " .. tostring(owns))
				end
			end
		end
	end
	return false
end

Players.PlayerRemoving:Connect(function(player)
	ownershipCache[player.UserId] = nil
end)

return GamePassService

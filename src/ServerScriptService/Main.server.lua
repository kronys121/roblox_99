-- Server entry point: builds the world, then wires up every gameplay
-- system in dependency order.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify")

local WorldGenerator = require(script.Parent:WaitForChild("WorldGenerator"))
local DayNightCycle = require(script.Parent:WaitForChild("DayNightCycle"))
local Warehouse = require(script.Parent:WaitForChild("Warehouse"))
local PlayerDataManager = require(script.Parent:WaitForChild("PlayerDataManager"))
local SurvivalStats = require(script.Parent:WaitForChild("SurvivalStats"))
local ResourceNodes = require(script.Parent:WaitForChild("ResourceNodes"))
local CraftingSystem = require(script.Parent:WaitForChild("CraftingSystem"))
local BuildingSystem = require(script.Parent:WaitForChild("BuildingSystem"))
local EnemySpawner = require(script.Parent:WaitForChild("EnemySpawner"))
local DepositStation = require(script.Parent:WaitForChild("DepositStation"))
local LeaderboardService = require(script.Parent:WaitForChild("LeaderboardService"))
local ShopService = require(script.Parent:WaitForChild("ShopService"))

-- Each system starts independently: if one throws, the rest still start
-- instead of a single bug (e.g. in world generation) silently taking out
-- gathering, crafting, and building along with it.
local function safeStart(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		warn(("Main: %s failed to start: %s"):format(name, tostring(err)))
	end
end

safeStart("WorldGenerator", WorldGenerator.Generate)
safeStart("Warehouse", Warehouse.Init)
safeStart("ResourceNodes", ResourceNodes.Start)
safeStart("CraftingSystem", CraftingSystem.Start)
safeStart("BuildingSystem", BuildingSystem.Start)
safeStart("SurvivalStats", SurvivalStats.Start)
safeStart("DepositStation", DepositStation.Start)
safeStart("LeaderboardService", LeaderboardService.Start)
safeStart("ShopService", ShopService.Start)

DayNightCycle.NightStarted.Event:Connect(function(nightNumber)
	EnemySpawner.OnNightStarted(nightNumber)

	local isBossNight = nightNumber % GameConfig.Boss.EveryNNights == 0
	local reward = GameConfig.Currency.PerNightSurvived + (isBossNight and GameConfig.Currency.BossNightBonus or 0)
	local message = isBossNight and ("A boss stirs on Night " .. nightNumber .. "...") or ("Night " .. nightNumber .. " has fallen...")

	for _, player in ipairs(Players:GetPlayers()) do
		PlayerDataManager.ReportNight(player, nightNumber)
		LeaderboardService.ReportScore(player, nightNumber)
		PlayerDataManager.AddCurrency(player, reward)
		Notify:FireClient(player, message)
	end
end)

DayNightCycle.DayStarted.Event:Connect(function()
	EnemySpawner.OnDayStarted()
end)

Players.PlayerAdded:Connect(function(player)
	PlayerDataManager.Load(player)

	player.CharacterAdded:Connect(function(character)
		SurvivalStats.OnCharacterAdded(player, character)
		ShopService.ApplyActiveCosmetic(player, character)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	SurvivalStats.OnPlayerRemoving(player)
end)

DayNightCycle.Start()

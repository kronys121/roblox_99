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

WorldGenerator.Generate()
Warehouse.Init()
ResourceNodes.Start()
CraftingSystem.Start()
BuildingSystem.Start()
SurvivalStats.Start()
DepositStation.Start()
LeaderboardService.Start()
ShopService.Start()

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

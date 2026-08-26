-- Server entry point: builds the world, then wires up every gameplay
-- system in dependency order.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify")

local WorldGenerator = require(script.Parent:WaitForChild("WorldGenerator"))
local DayNightCycle = require(script.Parent:WaitForChild("DayNightCycle"))
local PlayerDataManager = require(script.Parent:WaitForChild("PlayerDataManager"))
local SurvivalStats = require(script.Parent:WaitForChild("SurvivalStats"))
local ResourceNodes = require(script.Parent:WaitForChild("ResourceNodes"))
local CraftingSystem = require(script.Parent:WaitForChild("CraftingSystem"))
local BuildingSystem = require(script.Parent:WaitForChild("BuildingSystem"))
local EnemySpawner = require(script.Parent:WaitForChild("EnemySpawner"))

WorldGenerator.Generate()
ResourceNodes.Start()
CraftingSystem.Start()
BuildingSystem.Start()
SurvivalStats.Start()

DayNightCycle.NightStarted.Event:Connect(function(nightNumber)
	EnemySpawner.OnNightStarted()
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerDataManager.ReportNight(player, nightNumber)
		Notify:FireClient(player, "Night " .. nightNumber .. " has fallen...")
	end
end)

DayNightCycle.DayStarted.Event:Connect(function()
	EnemySpawner.OnDayStarted()
end)

Players.PlayerAdded:Connect(function(player)
	PlayerDataManager.Load(player)

	player.CharacterAdded:Connect(function(character)
		SurvivalStats.OnCharacterAdded(player, character)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	SurvivalStats.OnPlayerRemoving(player)
end)

DayNightCycle.Start()

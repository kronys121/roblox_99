-- Per-player Health/Hunger/Thirst/Stamina simulation. Hunger and Thirst
-- drain constantly and damage the player when empty; Stamina drains
-- while sprinting (client reports sprint state) and regenerates
-- otherwise. Health is the character's own Humanoid.Health, just synced
-- into the same StatsUpdated payload the HUD already listens to.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local StatsUpdated = Remotes:WaitForChild("StatsUpdated")
local SetSprinting = Remotes:WaitForChild("SetSprinting")
local EatFood = Remotes:WaitForChild("EatFood")
local DrinkWater = Remotes:WaitForChild("DrinkWater")
local Notify = Remotes:WaitForChild("Notify")

local PlayerDataManager = require(script.Parent:WaitForChild("PlayerDataManager"))

local SurvivalStats = {}

local statsByPlayer = {} -- [Player] = { Hunger, Thirst, Stamina, Sprinting }

local function pushStats(player)
	local stats = statsByPlayer[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not stats or not humanoid then
		return
	end
	StatsUpdated:FireClient(player, {
		Health = humanoid.Health,
		MaxHealth = humanoid.MaxHealth,
		Hunger = stats.Hunger,
		Thirst = stats.Thirst,
		Stamina = stats.Stamina,
	})
end

local function applySpeed(player, sprinting)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.WalkSpeed = sprinting and GameConfig.Stamina.SprintSpeed or GameConfig.Stamina.WalkSpeed
end

function SurvivalStats.OnCharacterAdded(player, character)
	statsByPlayer[player] = {
		Hunger = GameConfig.Hunger.Max,
		Thirst = GameConfig.Thirst.Max,
		Stamina = GameConfig.Stamina.Max,
		Sprinting = false,
	}

	local humanoid = character:WaitForChild("Humanoid")
	humanoid.MaxHealth = GameConfig.Health.Max
	humanoid.Health = GameConfig.Health.Max
	humanoid.WalkSpeed = GameConfig.Stamina.WalkSpeed

	pushStats(player)

	humanoid.Died:Connect(function()
		Notify:FireClient(player, "You died. Respawning...")
	end)
end

function SurvivalStats.OnPlayerRemoving(player)
	statsByPlayer[player] = nil
end

function SurvivalStats.Start()
	SetSprinting.OnServerEvent:Connect(function(player, sprinting)
		local stats = statsByPlayer[player]
		if not stats then
			return
		end
		stats.Sprinting = (sprinting == true) and stats.Stamina > GameConfig.Stamina.MinToSprint
		applySpeed(player, stats.Sprinting)
	end)

	EatFood.OnServerEvent:Connect(function(player)
		local stats = statsByPlayer[player]
		if not stats then
			return
		end
		if PlayerDataManager.SpendResources(player, { Berries = 1 }) then
			stats.Hunger = math.min(GameConfig.Hunger.Max, stats.Hunger + GameConfig.Hunger.BerriesRestore)
			pushStats(player)
		end
	end)

	DrinkWater.OnServerEvent:Connect(function(player)
		local stats = statsByPlayer[player]
		if not stats then
			return
		end
		if PlayerDataManager.SpendResources(player, { Water = 1 }) then
			stats.Thirst = math.min(GameConfig.Thirst.Max, stats.Thirst + GameConfig.Thirst.WaterRestore)
			pushStats(player)
		end
	end)

	local sinceLastPush = 0
	local PUSH_INTERVAL = 0.25

	RunService.Heartbeat:Connect(function(dt)
		sinceLastPush += dt
		local shouldPush = sinceLastPush >= PUSH_INTERVAL
		if shouldPush then
			sinceLastPush = 0
		end

		for player, stats in pairs(statsByPlayer) do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then
				continue
			end

			stats.Hunger = math.max(0, stats.Hunger - GameConfig.Hunger.DrainPerSecond * dt)
			if stats.Hunger <= 0 then
				humanoid:TakeDamage(GameConfig.Hunger.DamagePerSecondWhenEmpty * dt)
			end

			stats.Thirst = math.max(0, stats.Thirst - GameConfig.Thirst.DrainPerSecond * dt)
			if stats.Thirst <= 0 then
				humanoid:TakeDamage(GameConfig.Thirst.DamagePerSecondWhenEmpty * dt)
			end

			if stats.Sprinting then
				stats.Stamina = math.max(0, stats.Stamina - GameConfig.Stamina.DrainPerSecondSprinting * dt)
				if stats.Stamina <= 0 then
					stats.Sprinting = false
					applySpeed(player, false)
				end
			else
				stats.Stamina = math.min(GameConfig.Stamina.Max, stats.Stamina + GameConfig.Stamina.RegenPerSecond * dt)
			end

			if shouldPush then
				pushStats(player)
			end
		end
	end)
end

return SurvivalStats

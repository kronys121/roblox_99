-- Drives the day/night loop: advances Lighting.ClockTime, tracks which
-- night the server is on (out of GameConfig.TotalNights), and exposes
-- BindableEvents so other server systems (enemy spawner, stats) can react
-- without polling.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DayNightChanged = Remotes:WaitForChild("DayNightChanged")

local DayNightCycle = {}
DayNightCycle.NightStarted = Instance.new("BindableEvent")
DayNightCycle.DayStarted = Instance.new("BindableEvent")

DayNightCycle.CurrentNight = 0
DayNightCycle.Phase = "Day" -- "Day" | "Night"
DayNightCycle.GameComplete = false

local DAWN_CLOCK = 6
local DUSK_CLOCK = 19

local function broadcast()
	DayNightChanged:FireAllClients(DayNightCycle.Phase, DayNightCycle.CurrentNight, GameConfig.TotalNights)
end

function DayNightCycle.Start()
	task.spawn(function()
		while true do
			-- Daytime
			DayNightCycle.Phase = "Day"
			broadcast()
			DayNightCycle.DayStarted:Fire(DayNightCycle.CurrentNight)

			local dayElapsed = 0
			while dayElapsed < GameConfig.DayLength do
				local dt = RunService.Heartbeat:Wait()
				dayElapsed += dt
				local alpha = dayElapsed / GameConfig.DayLength
				Lighting.ClockTime = DAWN_CLOCK + alpha * (DUSK_CLOCK - DAWN_CLOCK)
			end

			if DayNightCycle.CurrentNight >= GameConfig.TotalNights then
				DayNightCycle.GameComplete = true
				break
			end

			-- Nighttime
			DayNightCycle.CurrentNight += 1
			DayNightCycle.Phase = "Night"
			broadcast()
			DayNightCycle.NightStarted:Fire(DayNightCycle.CurrentNight)

			local nightElapsed = 0
			while nightElapsed < GameConfig.NightLength do
				local dt = RunService.Heartbeat:Wait()
				nightElapsed += dt
				local alpha = nightElapsed / GameConfig.NightLength
				-- Swing from dusk, through midnight, to dawn.
				if alpha < 0.5 then
					Lighting.ClockTime = DUSK_CLOCK + (alpha * 2) * (24 - DUSK_CLOCK)
				else
					Lighting.ClockTime = ((alpha - 0.5) * 2) * DAWN_CLOCK
				end
			end
		end
	end)
end

return DayNightCycle

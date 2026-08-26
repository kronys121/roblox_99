-- The base framework every other system attaches to. Drives the
-- day/night loop: advances Lighting (ClockTime, Ambient, OutdoorAmbient,
-- fog, and a subtle color tint) between Day and Night presets, and
-- tracks which night the run is on (persisted across server restarts via
-- WorldStateStore).
--
-- Other systems hook in via:
--   DayNightCycle.NightStarted:Fire(nightNumber) -- night N begins
--   DayNightCycle.DayStarted:Fire(nightsSurvived) -- day begins (0 before Night 1)
-- rather than polling CurrentNight/Phase directly.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DayNightConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("DayNightConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DayNightChanged = Remotes:WaitForChild("DayNightChanged")

local WorldStateStore = require(script.Parent:WaitForChild("WorldStateStore"))

local DayNightCycle = {}
DayNightCycle.NightStarted = Instance.new("BindableEvent")
DayNightCycle.DayStarted = Instance.new("BindableEvent")

DayNightCycle.CurrentNight = WorldStateStore.LoadNight()
DayNightCycle.Phase = "Day" -- "Day" | "Night"
DayNightCycle.GameComplete = false

local BROADCAST_INTERVAL = 1 -- seconds between UI countdown updates

local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "DayNightTint"
tint.Parent = Lighting

local function crossfade(fromPreset, toPreset, alpha)
	Lighting.Ambient = fromPreset.Ambient:Lerp(toPreset.Ambient, alpha)
	Lighting.OutdoorAmbient = fromPreset.OutdoorAmbient:Lerp(toPreset.OutdoorAmbient, alpha)
	Lighting.Brightness = fromPreset.Brightness + (toPreset.Brightness - fromPreset.Brightness) * alpha
	Lighting.FogColor = fromPreset.FogColor:Lerp(toPreset.FogColor, alpha)
	Lighting.FogEnd = fromPreset.FogEnd + (toPreset.FogEnd - fromPreset.FogEnd) * alpha
	tint.TintColor = fromPreset.Tint:Lerp(toPreset.Tint, alpha)
end

local function broadcast(phaseLength, elapsed)
	DayNightChanged:FireAllClients({
		Phase = DayNightCycle.Phase,
		Night = DayNightCycle.CurrentNight,
		TotalNights = DayNightConfig.TotalNights,
		TimeLeft = math.max(0, phaseLength - elapsed),
		PhaseLength = phaseLength,
	})
end

local function runDayPhase()
	DayNightCycle.Phase = "Day"
	broadcast(DayNightConfig.DayLength, 0)
	DayNightCycle.DayStarted:Fire(DayNightCycle.CurrentNight)

	local elapsed = 0
	local sinceBroadcast = 0

	while elapsed < DayNightConfig.DayLength do
		local dt = RunService.Heartbeat:Wait()
		elapsed += dt
		sinceBroadcast += dt

		local dayAlpha = elapsed / DayNightConfig.DayLength
		Lighting.ClockTime = DayNightConfig.DawnClockTime + dayAlpha * (DayNightConfig.DuskClockTime - DayNightConfig.DawnClockTime)

		local fadeAlpha = math.clamp(elapsed / DayNightConfig.TransitionTime, 0, 1)
		crossfade(DayNightConfig.Lighting.Night, DayNightConfig.Lighting.Day, fadeAlpha)

		if sinceBroadcast >= BROADCAST_INTERVAL then
			sinceBroadcast = 0
			broadcast(DayNightConfig.DayLength, elapsed)
		end
	end
end

local function runNightPhase()
	DayNightCycle.CurrentNight += 1
	WorldStateStore.SaveNight(DayNightCycle.CurrentNight)

	DayNightCycle.Phase = "Night"
	broadcast(DayNightConfig.NightLength, 0)
	DayNightCycle.NightStarted:Fire(DayNightCycle.CurrentNight)

	local elapsed = 0
	local sinceBroadcast = 0

	while elapsed < DayNightConfig.NightLength do
		local dt = RunService.Heartbeat:Wait()
		elapsed += dt
		sinceBroadcast += dt

		-- Swing from dusk, through midnight, to dawn.
		local alpha = elapsed / DayNightConfig.NightLength
		if alpha < 0.5 then
			Lighting.ClockTime = DayNightConfig.DuskClockTime + (alpha * 2) * (24 - DayNightConfig.DuskClockTime)
		else
			Lighting.ClockTime = ((alpha - 0.5) * 2) * DayNightConfig.DawnClockTime
		end

		local fadeAlpha = math.clamp(elapsed / DayNightConfig.TransitionTime, 0, 1)
		crossfade(DayNightConfig.Lighting.Day, DayNightConfig.Lighting.Night, fadeAlpha)

		if sinceBroadcast >= BROADCAST_INTERVAL then
			sinceBroadcast = 0
			broadcast(DayNightConfig.NightLength, elapsed)
		end
	end
end

function DayNightCycle.Start()
	task.spawn(function()
		while true do
			runDayPhase()

			if DayNightCycle.CurrentNight >= DayNightConfig.TotalNights then
				DayNightCycle.GameComplete = true
				broadcast(0, 0)
				break
			end

			runNightPhase()
		end
	end)
end

return DayNightCycle

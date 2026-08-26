-- Timing and atmosphere for the day/night cycle. This is the single
-- source of truth for pacing (day/night length, total nights) and for
-- the Lighting presets crossfaded between at dawn/dusk. Retune the whole
-- game's rhythm and mood by editing values here only.

local DayNightConfig = {}

DayNightConfig.TotalNights = 99

DayNightConfig.DayLength = 300 -- 5 minutes
DayNightConfig.NightLength = 180 -- 3 minutes

-- How long (seconds, real time) the sunrise/sunset crossfade takes at the
-- start of each phase. Kept independent of DayLength/NightLength so it
-- stays a believable transition even if pacing is retuned later.
DayNightConfig.TransitionTime = 20

DayNightConfig.DawnClockTime = 6
DayNightConfig.DuskClockTime = 19

-- Lighting/atmosphere presets. Day is crossfaded in at the start of each
-- day phase (from the previous Night preset); Night is crossfaded in at
-- the start of each night phase (from the previous Day preset). Tuned
-- for a dim, misty survival-horror forest rather than a bright, clear
-- sunny day -- even daytime stays a little overcast and close-fogged.
DayNightConfig.Lighting = {
	Day = {
		Ambient = Color3.fromRGB(60, 65, 60),
		OutdoorAmbient = Color3.fromRGB(105, 110, 100),
		Brightness = 1.8,
		FogColor = Color3.fromRGB(130, 140, 125),
		FogEnd = 550,
		Tint = Color3.fromRGB(235, 240, 230),
	},
	Night = {
		Ambient = Color3.fromRGB(4, 4, 8),
		OutdoorAmbient = Color3.fromRGB(6, 6, 12),
		Brightness = 0.25,
		FogColor = Color3.fromRGB(2, 2, 5),
		FogEnd = 130,
		Tint = Color3.fromRGB(120, 140, 190),
	},
}

return DayNightConfig

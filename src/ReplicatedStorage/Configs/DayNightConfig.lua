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
-- the start of each night phase (from the previous Day preset).
DayNightConfig.Lighting = {
	Day = {
		Ambient = Color3.fromRGB(90, 90, 100),
		OutdoorAmbient = Color3.fromRGB(150, 150, 160),
		Brightness = 3,
		FogColor = Color3.fromRGB(170, 190, 200),
		FogEnd = 1200,
		Tint = Color3.fromRGB(255, 255, 255),
	},
	Night = {
		Ambient = Color3.fromRGB(15, 15, 25),
		OutdoorAmbient = Color3.fromRGB(20, 20, 35),
		Brightness = 0.75,
		FogColor = Color3.fromRGB(5, 5, 12),
		FogEnd = 300,
		Tint = Color3.fromRGB(150, 170, 210),
	},
}

return DayNightConfig

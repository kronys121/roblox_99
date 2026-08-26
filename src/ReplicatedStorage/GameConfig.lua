-- Shared configuration for 99 Nights in the Forest.
-- Read by both server and client; server is the source of truth for anything
-- that affects gameplay balance or persisted data.

local GameConfig = {}

-- Day/night pacing and total run length now live in
-- ReplicatedStorage/Configs/DayNightConfig.lua.

GameConfig.Hunger = {
	Max = 100,
	DrainPerSecond = 100 / (8 * 60),
	StarvingDamagePerSecond = 2,
	BerriesRestore = 20,
}

GameConfig.Stamina = {
	Max = 100,
	DrainPerSecondSprinting = 12,
	RegenPerSecond = 8,
	MinToSprint = 5,
	SprintSpeed = 24,
	WalkSpeed = 16,
}

-- Resource nodes scattered around the map.
GameConfig.Resources = {
	Tree = { Yields = "Wood", Health = 3, RespawnTime = 30 },
	Rock = { Yields = "Stone", Health = 4, RespawnTime = 45 },
	Bush = { Yields = "Berries", Health = 1, RespawnTime = 25 },
}

-- How much a single gather hit yields, depending on equipped tool.
GameConfig.GatherAmounts = {
	BareHands = 1,
	Axe = 3,
	Pickaxe = 3,
}

-- Crafting recipes. Keys map to either a Tool (goes in Backpack) or a
-- Buildable (goes in the player's placeable inventory, see BuildingSystem).
GameConfig.Recipes = {
	Axe = { Cost = { Wood = 5 }, Kind = "Tool" },
	Pickaxe = { Cost = { Wood = 5, Stone = 3 }, Kind = "Tool" },
	Campfire = { Cost = { Wood = 8, Stone = 4 }, Kind = "Buildable" },
	WoodWall = { Cost = { Wood = 10 }, Kind = "Buildable" },
}

GameConfig.Enemies = {
	MaxAlive = 12,
	SpawnIntervalNight = 8,
	Damage = 10,
	Health = 60,
	WalkSpeed = 10,
	ChaseRange = 45,
	AttackRange = 5,
	AttackCooldown = 1.5,
}

GameConfig.Building = {
	MaxPlaceDistance = 20,
}

GameConfig.World = {
	GroundSize = Vector3.new(500, 4, 500),
	TreeCount = 140,
	RockCount = 70,
	BushCount = 90,
}

return GameConfig

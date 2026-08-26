-- Shared configuration for 99 Nights in the Forest.
-- Read by both server and client; server is the source of truth for anything
-- that affects gameplay balance or persisted data.
--
-- Day/night pacing lives in Configs/DayNightConfig.lua. Everything else
-- (survival, gathering, crafting, building, enemies, meta-progression)
-- lives here so balance can be retuned without touching system logic.

local GameConfig = {}

-- Personal carry cap per resource. Gathering fills this pouch; players
-- must return to the base Warehouse to deposit into the shared stockpile
-- before they can carry more (or before crafting/building, which always
-- spends from the shared stockpile, not personal carry).
GameConfig.Carry = {
	MaxPerResource = 50,
	ExtraCarryGamePassBonus = 50,
}

GameConfig.Health = {
	Max = 100,
}

GameConfig.Hunger = {
	Max = 100,
	DrainPerSecond = 100 / (10 * 60),
	DamagePerSecondWhenEmpty = 2,
	BerriesRestore = 30,
}

GameConfig.Thirst = {
	Max = 100,
	DrainPerSecond = 100 / (7 * 60),
	DamagePerSecondWhenEmpty = 3,
	WaterRestore = 40,
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
	WaterSource = { Yields = "Water", Health = 1, RespawnTime = 10 },
	OreVein = { Yields = "RareMaterial", Health = 5, RespawnTime = 90 },
}

-- How much a single gather hit yields, depending on equipped tool.
GameConfig.GatherAmounts = {
	BareHands = 1,
	Axe = 3, -- boosts Tree
	Pickaxe = 3, -- boosts Rock and OreVein
}

-- Crafting tree: Tools -> Weapons -> Fortifications -> Advanced gear.
-- `Requires` names a Tool the crafting player must already own (in their
-- Backpack or hand) -- that prerequisite is what makes this a tree
-- instead of a flat list. Cost is always paid out of the shared base
-- Warehouse, never personal carry, so crafting is a genuinely
-- cooperative action. `CraftTime` (seconds) is skipped entirely for
-- players holding the "Swift Crafting" Game Pass.
GameConfig.Recipes = {
	-- Tier 1: basic tools + a utility buildable.
	Axe = { Tier = 1, Kind = "Tool", Cost = { Wood = 5 }, CraftTime = 0 },
	Pickaxe = { Tier = 1, Kind = "Tool", Cost = { Wood = 5, Stone = 3 }, CraftTime = 0 },
	Campfire = { Tier = 1, Kind = "Buildable", Cost = { Wood = 8, Stone = 4 }, CraftTime = 1 },

	-- Tier 2: weapons, gated behind a basic tool.
	Spear = { Tier = 2, Kind = "Tool", Cost = { Wood = 8, Stone = 4 }, Requires = "Axe", CraftTime = 2 },
	Sword = { Tier = 2, Kind = "Tool", Cost = { Stone = 10, RareMaterial = 2 }, Requires = "Pickaxe", CraftTime = 2 },

	-- Tier 3: fortifications for the base.
	WoodWall = { Tier = 3, Kind = "Buildable", Cost = { Wood = 10 }, CraftTime = 2 },
	WoodDoor = { Tier = 3, Kind = "Buildable", Cost = { Wood = 8 }, CraftTime = 2 },
	SpikeTrap = { Tier = 3, Kind = "Buildable", Cost = { Wood = 6, Stone = 6 }, Requires = "Spear", CraftTime = 3 },
	WatchTower = { Tier = 3, Kind = "Buildable", Cost = { Wood = 25, Stone = 10 }, CraftTime = 4 },

	-- Tier 4: advanced gear, gated behind rare material + a tier-2 weapon/tool.
	SteelPickaxe = { Tier = 4, Kind = "Tool", Cost = { RareMaterial = 8, Wood = 5 }, Requires = "Pickaxe", CraftTime = 4 },
	Crossbow = { Tier = 4, Kind = "Tool", Cost = { RareMaterial = 10, Wood = 10 }, Requires = "Sword", CraftTime = 5 },
	ReinforcedWall = { Tier = 4, Kind = "Buildable", Cost = { Stone = 15, RareMaterial = 5 }, Requires = "Pickaxe", CraftTime = 5 },
}

-- Base enemy stats plus how they scale with night number and player
-- count. Use GameConfig.Enemies.ForNight(night, playerCount) rather than
-- reading the base fields directly.
GameConfig.Enemies = {
	BaseHealth = 60,
	BaseDamage = 10,
	BaseWalkSpeed = 10,
	BaseChaseRange = 18, -- small early on: enemies mostly patrol
	AttackRange = 5,
	AttackCooldown = 1.5,

	BaseMaxAlive = 5,
	MaxAliveHardCap = 40,

	HealthPerNight = 3,
	DamagePerNight = 0.6,
	SpeedPerNight = 0.15,
	ChaseRangePerNight = 1.2,
	ChaseRangeCap = 80,
	MaxAlivePerNight = 0.6,
	MaxAlivePerPlayer = 2,

	SpawnIntervalBase = 8,
	SpawnIntervalMinFloor = 2,
	SpawnIntervalReductionPerNight = 0.06,

	-- From this night onward, enemies that spot a player alert nearby
	-- enemies to converge on the same target ("coordinated attacks").
	CoordinatedNightThreshold = 15,
	AlertTTL = 6,
}

function GameConfig.Enemies.ForNight(night, playerCount)
	local enemies = GameConfig.Enemies
	playerCount = math.max(1, playerCount)

	return {
		Health = enemies.BaseHealth + night * enemies.HealthPerNight,
		Damage = enemies.BaseDamage + night * enemies.DamagePerNight,
		WalkSpeed = enemies.BaseWalkSpeed + night * enemies.SpeedPerNight,
		ChaseRange = math.min(enemies.ChaseRangeCap, enemies.BaseChaseRange + night * enemies.ChaseRangePerNight),
		MaxAlive = math.min(
			enemies.MaxAliveHardCap,
			math.floor(enemies.BaseMaxAlive + night * enemies.MaxAlivePerNight + playerCount * enemies.MaxAlivePerPlayer)
		),
		SpawnInterval = math.max(
			enemies.SpawnIntervalMinFloor,
			enemies.SpawnIntervalBase - night * enemies.SpawnIntervalReductionPerNight
		),
		Coordinated = night >= enemies.CoordinatedNightThreshold,
	}
end

-- Boss creatures spawn every EveryNNights, on top of the normal horde.
GameConfig.Boss = {
	EveryNNights = 10,
	HealthMultiplier = 8,
	DamageMultiplier = 2.5,
	WalkSpeedMultiplier = 0.8,
	SizeMultiplier = 2.2,
}

-- Base building: grid-snapped placement, structure durability, repair.
GameConfig.Building = {
	GridSize = 4,
	MaxPlaceDistance = 24,
	RepairAmount = 40,
	RepairCost = { Wood = 3, Stone = 2 },
	TrapDamage = 15,
	TrapRadius = 5,
	TrapInterval = 1,
	Structures = {
		Campfire = { MaxHealth = 80 },
		WoodWall = { MaxHealth = 150 },
		WoodDoor = { MaxHealth = 100 },
		SpikeTrap = { MaxHealth = 60 },
		WatchTower = { MaxHealth = 250 },
		ReinforcedWall = { MaxHealth = 400 },
	},
}

-- Meta-progression currency, earned per night survived (see
-- Main.server.lua's NightStarted handler) and spent in the cosmetic shop.
GameConfig.Currency = {
	Name = "Embers",
	PerNightSurvived = 15,
	BossNightBonus = 100,
}

-- Cosmetics purchasable with Embers (not Robux) -- purely procedural
-- (a colored aura light), so no external asset/image IDs are required.
GameConfig.Cosmetics = {
	{ Id = "Ember", Name = "Ember Aura", Cost = 150, Color = Color3.fromRGB(255, 140, 40) },
	{ Id = "Frost", Name = "Frost Aura", Cost = 150, Color = Color3.fromRGB(140, 200, 255) },
	{ Id = "Venom", Name = "Venom Aura", Cost = 200, Color = Color3.fromRGB(120, 255, 100) },
	{ Id = "Royal", Name = "Royal Aura", Cost = 300, Color = Color3.fromRGB(200, 120, 255) },
}

-- Real Robux monetization. These IDs are placeholders (0) because a
-- Game Pass only gets a real ID once you create it for this experience
-- in the Roblox Creator Dashboard -- that's a per-game asset only you
-- can create, not something that can be filled in for you. Until an
-- entry's Id is a real positive number, GamePassService treats it as
-- "not configured yet": the shop shows it but disables the buy button
-- instead of prompting a purchase that would just fail.
GameConfig.GamePasses = {
	{ Id = 0, Name = "Extra Backpack", Description = "+50 personal carry capacity per resource", Effect = "ExtraCarry" },
	{ Id = 0, Name = "Swift Crafting", Description = "Crafting finishes instantly", Effect = "FastCraft" },
}

GameConfig.World = {
	GroundSize = Vector3.new(600, 4, 600),
	TreeCount = 160,
	RockCount = 80,
	BushCount = 90,
	WaterSourceCount = 10,
	OreVeinCount = 18,
}

return GameConfig

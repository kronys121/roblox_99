-- Spawns simple "Forest Creature" NPCs during the night and drives their
-- chase/attack behavior. Creatures are built procedurally (no rig assets
-- required) and are cleaned up at dawn.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local EnemySpawner = {}

local activeCreatures = {}
local nightRunToken = 0

local function createCreature()
	local model = Instance.new("Model")
	model.Name = "ForestCreature"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(3, 4, 2)
	root.Color = Color3.fromRGB(35, 30, 32)
	root.Material = Enum.Material.Slate
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(2, 2, 2)
	head.Color = Color3.fromRGB(60, 20, 20)
	head.Material = Enum.Material.Slate
	head.Parent = model

	head.CFrame = root.CFrame * CFrame.new(0, 3, 0)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = head
	weld.Parent = root

	local eye = Instance.new("PointLight")
	eye.Color = Color3.fromRGB(255, 60, 60)
	eye.Range = 8
	eye.Brightness = 1.5
	eye.Parent = head

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = GameConfig.Enemies.Health
	humanoid.Health = GameConfig.Enemies.Health
	humanoid.WalkSpeed = GameConfig.Enemies.WalkSpeed
	humanoid.Parent = model

	model.PrimaryPart = root
	return model
end

local function edgeSpawnPoint()
	local size = GameConfig.World.GroundSize
	local halfX, halfZ = size.X / 2 - 10, size.Z / 2 - 10
	local side = math.random(1, 4)
	if side == 1 then
		return Vector3.new(-halfX, 4, math.random(-halfZ, halfZ))
	elseif side == 2 then
		return Vector3.new(halfX, 4, math.random(-halfZ, halfZ))
	elseif side == 3 then
		return Vector3.new(math.random(-halfX, halfX), 4, -halfZ)
	else
		return Vector3.new(math.random(-halfX, halfX), 4, halfZ)
	end
end

local function nearestPlayerRoot(fromPosition)
	local nearest, nearestDist = nil, math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local dist = (root.Position - fromPosition).Magnitude
			if dist < nearestDist then
				nearest, nearestDist = root, dist
			end
		end
	end
	return nearest, nearestDist
end

local function runCreatureAI(model, myToken)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model.PrimaryPart
	local lastAttack = 0

	humanoid.Died:Connect(function()
		activeCreatures[model] = nil
		task.delay(3, function()
			model:Destroy()
		end)
	end)

	while model.Parent and myToken == nightRunToken and humanoid.Health > 0 do
		local targetRoot, dist = nearestPlayerRoot(root.Position)

		if targetRoot and dist <= GameConfig.Enemies.ChaseRange then
			humanoid:MoveTo(targetRoot.Position)
			if dist <= GameConfig.Enemies.AttackRange then
				local now = os.clock()
				if now - lastAttack >= GameConfig.Enemies.AttackCooldown then
					lastAttack = now
					local targetHumanoid = targetRoot.Parent:FindFirstChildOfClass("Humanoid")
					if targetHumanoid then
						targetHumanoid:TakeDamage(GameConfig.Enemies.Damage)
					end
				end
			end
		else
			-- Wander randomly while no player is nearby.
			local wanderTarget = root.Position + Vector3.new(math.random(-20, 20), 0, math.random(-20, 20))
			humanoid:MoveTo(wanderTarget)
			task.wait(2)
		end

		task.wait(0.5)
	end
end

local function spawnCreature()
	local enemiesFolder = Workspace:FindFirstChild("Enemies")
	if not enemiesFolder then
		return
	end

	local model = createCreature()
	model:PivotTo(CFrame.new(edgeSpawnPoint()))
	model.Parent = enemiesFolder

	activeCreatures[model] = true
	task.spawn(runCreatureAI, model, nightRunToken)
end

local function clearAllCreatures()
	nightRunToken += 1
	for model in pairs(activeCreatures) do
		if model.Parent then
			model:Destroy()
		end
	end
	activeCreatures = {}
end

function EnemySpawner.OnNightStarted()
	nightRunToken += 1
	local myToken = nightRunToken

	task.spawn(function()
		while myToken == nightRunToken do
			local count = 0
			for _ in pairs(activeCreatures) do
				count += 1
			end
			if count < GameConfig.Enemies.MaxAlive then
				spawnCreature()
			end
			task.wait(GameConfig.Enemies.SpawnIntervalNight)
		end
	end)
end

function EnemySpawner.OnDayStarted()
	clearAllCreatures()
end

return EnemySpawner

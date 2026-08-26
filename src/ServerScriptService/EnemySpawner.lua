-- Spawns "Forest Creature" NPCs during the night and drives their AI via
-- PathfindingService. Difficulty (health/damage/speed/chase range/count)
-- scales with the current night and player count (GameConfig.Enemies.
-- ForNight). Every GameConfig.Boss.EveryNNights, a scaled-up boss also
-- spawns. From GameConfig.Enemies.CoordinatedNightThreshold onward,
-- spotting a player alerts nearby creatures to converge on the same
-- target ("coordinated attacks") instead of each acting independently.
--
-- Creatures are built procedurally (no rig assets required) and are
-- cleaned up at dawn.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local BuildingSystem = require(script.Parent:WaitForChild("BuildingSystem"))
local DayNightCycle = require(script.Parent:WaitForChild("DayNightCycle"))

local EnemySpawner = {}

local activeCreatures = {} -- [Model] = true
local nightRunToken = 0
local lastAlert = nil -- { Position = Vector3, ExpiresAt = number }

local function createCreature(isBoss)
	local sizeMul = isBoss and GameConfig.Boss.SizeMultiplier or 1

	local model = Instance.new("Model")
	model.Name = isBoss and "ForestBoss" or "ForestCreature"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(3, 4, 2) * sizeMul
	root.Color = isBoss and Color3.fromRGB(90, 15, 15) or Color3.fromRGB(35, 30, 32)
	root.Material = Enum.Material.Slate
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(2, 2, 2) * sizeMul
	head.Color = isBoss and Color3.fromRGB(120, 20, 20) or Color3.fromRGB(60, 20, 20)
	head.Material = Enum.Material.Slate
	head.Parent = model

	head.CFrame = root.CFrame * CFrame.new(0, 3 * sizeMul, 0)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = head
	weld.Parent = root

	local eye = Instance.new("PointLight")
	eye.Color = Color3.fromRGB(255, 60, 60)
	eye.Range = isBoss and 16 or 8
	eye.Brightness = isBoss and 3 or 1.5
	eye.Parent = head

	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = model

	model.PrimaryPart = root
	return model, humanoid
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

local function nearestPlayerRoot(fromPosition, chaseRange)
	local nearest, nearestDist = nil, chaseRange
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local dist = (root.Position - fromPosition).Magnitude
			if dist <= nearestDist then
				nearest, nearestDist = root, dist
			end
		end
	end
	return nearest, nearestDist
end

local function pickTargetPosition(root, difficulty)
	local playerRoot, dist = nearestPlayerRoot(root.Position, difficulty.ChaseRange)
	if playerRoot then
		if difficulty.Coordinated then
			lastAlert = { Position = playerRoot.Position, ExpiresAt = os.clock() + GameConfig.Enemies.AlertTTL }
		end
		return playerRoot.Position, playerRoot, dist
	end

	if difficulty.Coordinated and lastAlert and os.clock() < lastAlert.ExpiresAt then
		return lastAlert.Position, nil, nil
	end

	return nil, nil, nil
end

-- Walks a humanoid along a computed path's waypoints. Returns once the
-- path is finished, abandoned (isStillValid fails), or a waypoint stalls.
local function followPath(humanoid, waypoints, isStillValid)
	for i = 2, #waypoints do
		if not isStillValid() then
			return
		end

		local waypoint = waypoints[i]
		humanoid:MoveTo(waypoint.Position)

		local reached = false
		local connection
		connection = humanoid.MoveToFinished:Connect(function()
			reached = true
		end)

		local elapsed = 0
		while not reached and elapsed < 3 and isStillValid() do
			task.wait(0.1)
			elapsed += 0.1
		end
		connection:Disconnect()

		if not isStillValid() then
			return
		end
	end
end

local function runCreatureAI(model, humanoid, myToken, isBoss)
	local root = model.PrimaryPart
	local lastAttack = 0

	local function isStillValid()
		return model.Parent and myToken == nightRunToken and humanoid.Health > 0
	end

	humanoid.Died:Connect(function()
		activeCreatures[model] = nil
		task.delay(3, function()
			if model.Parent then
				model:Destroy()
			end
		end)
	end)

	local agentParams = {
		AgentRadius = isBoss and 5 or 2.5,
		AgentHeight = isBoss and 10 or 5,
		AgentCanJump = false,
	}

	while isStillValid() do
		local difficulty = GameConfig.Enemies.ForNight(DayNightCycle.CurrentNight, math.max(1, #Players:GetPlayers()))
		local damage = difficulty.Damage * (isBoss and GameConfig.Boss.DamageMultiplier or 1)

		local targetPosition, targetPlayerRoot, distToPlayer = pickTargetPosition(root, difficulty)

		-- While actively chasing/alerted, smash any structure within reach
		-- first -- close enough to hit is close enough to be "in the way".
		local nearestStructure = BuildingSystem.FindNearestStructure(root.Position, GameConfig.Enemies.AttackRange * 1.5)
		if nearestStructure and targetPosition then
			local now = os.clock()
			if now - lastAttack >= GameConfig.Enemies.AttackCooldown then
				lastAttack = now
				BuildingSystem.DamageStructure(nearestStructure, damage)
			end
			task.wait(0.3)
			continue
		end

		if not targetPosition then
			-- Nothing to chase: patrol randomly near the current spot.
			local wanderTarget = root.Position + Vector3.new(math.random(-20, 20), 0, math.random(-20, 20))
			humanoid.WalkSpeed = difficulty.WalkSpeed * (isBoss and GameConfig.Boss.WalkSpeedMultiplier or 1)
			humanoid:MoveTo(wanderTarget)
			task.wait(2)
			continue
		end

		if targetPlayerRoot and distToPlayer and distToPlayer <= GameConfig.Enemies.AttackRange then
			local now = os.clock()
			if now - lastAttack >= GameConfig.Enemies.AttackCooldown then
				lastAttack = now
				local targetHumanoid = targetPlayerRoot.Parent:FindFirstChildOfClass("Humanoid")
				if targetHumanoid then
					targetHumanoid:TakeDamage(damage)
				end
			end
			task.wait(0.3)
			continue
		end

		humanoid.WalkSpeed = difficulty.WalkSpeed * (isBoss and GameConfig.Boss.WalkSpeedMultiplier or 1)

		local path = PathfindingService:CreatePath(agentParams)
		local ok = pcall(function()
			path:ComputeAsync(root.Position, targetPosition)
		end)

		if ok and path.Status == Enum.PathStatus.Success then
			followPath(humanoid, path:GetWaypoints(), isStillValid)
		else
			-- No route found (e.g. boxed in): fall back to a direct move
			-- so the creature still makes progress instead of freezing.
			humanoid:MoveTo(targetPosition)
			task.wait(1)
		end
	end
end

local function applyDifficulty(humanoid, difficulty, isBoss)
	humanoid.MaxHealth = isBoss and (difficulty.Health * GameConfig.Boss.HealthMultiplier) or difficulty.Health
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = difficulty.WalkSpeed * (isBoss and GameConfig.Boss.WalkSpeedMultiplier or 1)
end

local function spawnCreature(isBoss)
	local enemiesFolder = Workspace:FindFirstChild("Enemies")
	if not enemiesFolder then
		return
	end

	local difficulty = GameConfig.Enemies.ForNight(DayNightCycle.CurrentNight, math.max(1, #Players:GetPlayers()))

	local model, humanoid = createCreature(isBoss)
	applyDifficulty(humanoid, difficulty, isBoss)
	model:PivotTo(CFrame.new(edgeSpawnPoint()))
	model.Parent = enemiesFolder

	local myToken = nightRunToken
	activeCreatures[model] = true
	task.spawn(runCreatureAI, model, humanoid, myToken, isBoss)
end

local function clearAllCreatures()
	nightRunToken += 1
	lastAlert = nil
	for model in pairs(activeCreatures) do
		if model.Parent then
			model:Destroy()
		end
	end
	activeCreatures = {}
end

function EnemySpawner.OnNightStarted(night)
	nightRunToken += 1
	local myToken = nightRunToken

	if night % GameConfig.Boss.EveryNNights == 0 then
		spawnCreature(true)
	end

	task.spawn(function()
		while myToken == nightRunToken do
			local count = 0
			for _ in pairs(activeCreatures) do
				count += 1
			end

			local difficulty = GameConfig.Enemies.ForNight(night, math.max(1, #Players:GetPlayers()))
			if count < difficulty.MaxAlive then
				spawnCreature(false)
			end
			task.wait(difficulty.SpawnInterval)
		end
	end)
end

function EnemySpawner.OnDayStarted()
	clearAllCreatures()
end

return EnemySpawner

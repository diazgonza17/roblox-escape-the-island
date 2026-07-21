-- ==========================================
-- SERVICES
-- ==========================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- ==========================================
-- CONFIGURATION
-- ==========================================

local configFolder = script.Parent:WaitForChild("config")
local ENEMY_SPAWN_ZONES = require(configFolder:WaitForChild("EnemySpawnZones"))

-- ==========================================
-- CONSTANTS
-- ==========================================

local DEBUG_ROOT_FOLDER_NAME = "Debug"
local DEBUG_ZONES_FOLDER_NAME = "EnemySpawnZones"

local ENEMIES_FOLDER_NAME = "Enemies"

local PLACEHOLDER_ENEMY_NAME_PREFIX = "Enemy"
local PLACEHOLDER_ENEMY_SIZE = Vector3.new(3, 3, 3)
local PLACEHOLDER_ENEMY_COLOR = Color3.fromRGB(170, 50, 255)

local ENEMY_UPDATE_INTERVAL = 0.01
local ENEMY_MOVEMENT_SPEED = 10
local ENEMY_RETURN_STOP_DISTANCE = 1
local ENEMY_TARGET_STOP_DISTANCE = 4
local ENEMY_TARGET_HEIGHT_OFFSET = 2
local TARGETED_ENEMY_COLOR = Color3.fromRGB(255, 50, 100)

-- ==========================================
-- RUNTIME STATE
-- ==========================================

local randomGenerator = Random.new()
local enemyStates = {}

-- ==========================================
-- GENERAL HELPERS
-- ==========================================

local function getOrCreateFolder(parent, folderName)
	local existingInstance = parent:FindFirstChild(folderName)
	if existingInstance then
		if existingInstance:IsA("Folder") then return existingInstance end

		warn(string.format("Cannot create debug folder %s because that name is already in use", folderName))
		return nil
	end

	local folder = Instance.new("Folder")
	folder.Name = folderName
	folder.Parent = parent
	return folder
end

-- ==========================================
-- SPAWN POSITION HELPERS
-- ==========================================

local function getRandomPointInZone(zone)
	local halfSize = zone.size / 2
	local localOffset = Vector3.new(
		randomGenerator:NextNumber(-halfSize.X, halfSize.X),
		randomGenerator:NextNumber(-halfSize.Y, halfSize.Y),
		randomGenerator:NextNumber(-halfSize.Z, halfSize.Z)
	)

	return zone.cframe:PointToWorldSpace(localOffset)
end

-- ==========================================
-- PLAYER AND RANGE HELPERS
-- ==========================================

local function getLivingPlayerRootPart(player)
	if player.Parent ~= Players then return nil end

	local character = player.Character
	if not character then return nil end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return nil end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then return nil end

	return rootPart
end

local function getPlayerDistanceFromZone(player, zone)
	local rootPart = getLivingPlayerRootPart(player)
	if not rootPart then return nil end

	local offsetFromZone = rootPart.Position - zone.cframe.Position
	return offsetFromZone.Magnitude
end

local function isLivingPlayerWithinRange(player, zone, range)
	local distanceFromZone = getPlayerDistanceFromZone(player, zone)
	if not distanceFromZone then return false end

	return distanceFromZone <= range
end

local function hasLivingPlayerNearZone(zone)
	for _, player in Players:GetPlayers() do
		if isLivingPlayerWithinRange(player, zone, zone.activationRange) then return true end
	end

	return false
end

-- ==========================================
-- ENEMY CREATION AND STATE
-- ==========================================

local function createPlaceholderEnemy(zone, enermyNumber, parent)
	local enemy = Instance.new("Part")
	enemy.Name = string.format("%s%d", PLACEHOLDER_ENEMY_NAME_PREFIX, enermyNumber)
	enemy.Shape = Enum.PartType.Ball
	enemy.Size = PLACEHOLDER_ENEMY_SIZE

	enemy.Anchored = true
	enemy.CanCollide = false
	enemy.CanTouch = false
	enemy.CastShadow = false

	enemy.Color = PLACEHOLDER_ENEMY_COLOR
	enemy.Material = Enum.Material.Neon

	local spawnPosition = getRandomPointInZone(zone)
	enemy.Position = spawnPosition

	enemy:SetAttribute("SpawnZoneId", zone.id)
	enemy.Parent = parent

	enemyStates[enemy] = {
		zone = zone,
		target = nil,
		returnPosition = spawnPosition
	}

	enemy.Destroying:Connect(function()
		enemyStates[enemy] = nil
	end)

	return enemy
end

-- ==========================================
-- MOVEMENT
-- ==========================================

local function moveEnemyTowardPosition(enemy, destination, stopDistance, deltaTime)
	local offsetToDestination = destination - enemy.Position
	local distanceToDestination = offsetToDestination.Magnitude
	if distanceToDestination <= stopDistance then return end

	local maximumMovement = ENEMY_MOVEMENT_SPEED * deltaTime
	local remainingDistance = distanceToDestination - stopDistance
	local movementDistance = math.min(maximumMovement, remainingDistance)

	local movementDirection = offsetToDestination.Unit
	enemy.Position += movementDirection * movementDistance
end

local function updateEnemyMovement(enemy, state, deltaTime)
	local target = state.target

	if target then
		local targetRootPart = getLivingPlayerRootPart(target)

		if targetRootPart then
			local targetPosition = targetRootPart.Position + Vector3.new(0, ENEMY_TARGET_HEIGHT_OFFSET, 0)
			moveEnemyTowardPosition(enemy, targetPosition, ENEMY_TARGET_STOP_DISTANCE, deltaTime)

			return
		end
	end

	moveEnemyTowardPosition(enemy, state.returnPosition, ENEMY_RETURN_STOP_DISTANCE, deltaTime)
end

-- ==========================================
-- TARGETING
-- ==========================================

local function findNearestTargetForEnemy(enemy, zone)
	local nearestPlayer = nil
	local nearestDistanceFromEnemy = math.huge

	for _, player in Players:GetPlayers() do
		local rootPart = getLivingPlayerRootPart(player)
		if not rootPart then continue end

		local distanceFromZone = (rootPart.Position - zone.cframe.Position).Magnitude
		if distanceFromZone > zone.leashRange then continue end

		local distanceFromEnemy = (rootPart.Position - enemy.Position).Magnitude
		if distanceFromEnemy < nearestDistanceFromEnemy then
			nearestPlayer = player
			nearestDistanceFromEnemy = distanceFromEnemy
		end
	end

	return nearestPlayer
end

local function setEnemyTarget(enemy, state, target)
	local previousTarget = state.target
	state.target = target

	if previousTarget and not target then 
		state.returnPosition = getRandomPointInZone(state.zone)
	end

	if target then
		enemy:SetAttribute("TargetUserId", target.UserId)
		enemy.Color = TARGETED_ENEMY_COLOR
	else
		enemy:SetAttribute("TargetUserId", nil)
		enemy.Color = PLACEHOLDER_ENEMY_COLOR
	end
end

local function updateEnemyTarget(enemy, state)
	local currentTarget = state.target
	if currentTarget and isLivingPlayerWithinRange(currentTarget, state.zone, state.zone.leashRange) then return end

	local newTarget = findNearestTargetForEnemy(enemy, state.zone)
	setEnemyTarget(enemy, state, newTarget)
end

local function runEnemySimulation(enemiesFolder)
	local previousUpdateTime = time()

	while enemiesFolder.Parent do
		local currentTime = time()
		local deltaTime = currentTime - previousUpdateTime
		previousUpdateTime = currentTime

		for enemy, state in enemyStates do
			if enemy:IsDescendantOf(enemiesFolder) then 
				updateEnemyTarget(enemy, state)
				updateEnemyMovement(enemy, state, deltaTime)
			else 
				enemyStates[enemy] = nil 
			end
		end

		task.wait(ENEMY_UPDATE_INTERVAL)
	end
end

-- ==========================================
-- SPAWNING
-- ==========================================

local function runZoneSpawner(zone, zoneEnemiesFolder)
	local nextEnemyNumber = 1

	while zoneEnemiesFolder.Parent do
		local hasNearbyPlayer = hasLivingPlayerNearZone(zone)
		local aliveCount = #zoneEnemiesFolder:GetChildren()

		if hasNearbyPlayer and aliveCount < zone.maxAlive then
			createPlaceholderEnemy(zone, nextEnemyNumber, zoneEnemiesFolder)
			nextEnemyNumber += 1
		end

		task.wait(zone.spawnInterval)
	end
end

-- ==========================================
-- STUDIO DEBUG VISUALIZATION
-- ==========================================

local function configureDebugPart(debugPart)
	debugPart.Anchored = true
	debugPart.CanCollide = false
	debugPart.CanTouch = false
	debugPart.CanQuery = false
	debugPart.CastShadow = false
end

local function createDebugZoneVolume(zone, parent)
	local debugPart = Instance.new("Part")
	debugPart.Name = "ZoneVolume"

	configureDebugPart(debugPart)

	debugPart.Color = Color3.fromRGB(255,100,50)
	debugPart.Material = Enum.Material.ForceField
	debugPart.Transparency = 0.5
	debugPart.CFrame = zone.cframe
	debugPart.Size = zone.size
	debugPart.Parent = parent
end

local function createDebugRangeSphere(zone, parent, partName, range, color)
	local diameter = range * 2

	local debugPart = Instance.new("Part")
	debugPart.Name = partName

	configureDebugPart(debugPart)

	debugPart.Shape = Enum.PartType.Ball
	debugPart.Color = color
	debugPart.Material = Enum.Material.ForceField
	debugPart.Transparency = 0.5

	debugPart.Size = Vector3.new(diameter, diameter, diameter)
	debugPart.Position = zone.cframe.Position
	debugPart.Parent = parent
end

local function createDebugZoneVisualization(zone, debugZonesFolder)
	local zoneFolder = getOrCreateFolder(debugZonesFolder, zone.id)
	if not zoneFolder then return end

	createDebugZoneVolume(zone, zoneFolder)
	createDebugRangeSphere(zone, zoneFolder, "ActivationRange", zone.activationRange, Color3.fromRGB(50, 150, 255))
	createDebugRangeSphere(zone, zoneFolder, "LeashRange", zone.leashRange, Color3.fromRGB(255, 50, 200))
end

local function createDebugZoneVisualizations()
	local debugRootFolder = getOrCreateFolder(Workspace, DEBUG_ROOT_FOLDER_NAME)
	if not debugRootFolder then return end

	local debugZonesFolder = getOrCreateFolder(debugRootFolder, DEBUG_ZONES_FOLDER_NAME)
	if not debugZonesFolder then return end

	for _, zone in ENEMY_SPAWN_ZONES do
		createDebugZoneVisualization(zone, debugZonesFolder)
	end
end

-- ==========================================
-- INITIALIZATION
-- ==========================================

local function initializeEnemyZones()
	local enemiesFolder = getOrCreateFolder(Workspace, ENEMIES_FOLDER_NAME)
	if not enemiesFolder then return end

	for _, zone in ENEMY_SPAWN_ZONES do
		local zoneEnemiesFolder = getOrCreateFolder(enemiesFolder, zone.id)
		if not zoneEnemiesFolder then return end

		task.spawn(function ()
			runZoneSpawner(zone, zoneEnemiesFolder)
		end)
	end

	task.spawn(function ()
		runEnemySimulation(enemiesFolder)
	end)
end

if RunService:IsStudio() then
	createDebugZoneVisualizations()
end

initializeEnemyZones()

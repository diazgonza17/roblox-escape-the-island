local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local padVisualEvent = ReplicatedStorage:WaitForChild("PadVisualEvent")
local getPadInitialText = ReplicatedStorage:WaitForChild("GetPadInitialTextFunction")

local Leaderboard = require(ServerStorage.Leaderboard)
local PlayerData = require(ServerStorage.PlayerData)

local JUMP_KEY_NAME = PlayerData.JUMP_KEY_NAME
local SPEED_KEY_NAME = PlayerData.SPEED_KEY_NAME
local COIN_KEY_NAME = PlayerData.COIN_KEY_NAME
local UPGRADES_HISTORY_KEY_NAME = PlayerData.UPGRADES_HISTORY_KEY_NAME

local upgradesFolder = Workspace.World.Upgrades

local JUMP_POWER_INITIAL = 50
local WALK_SPEED_INITIAL = 16
local HOLD_DURATION = 1
local PAD_CHECK_INTERVAL = 0.2

local padDataCache = {}
local playerPurchaseHistory = {}

local function calculateCurrentCost(baseCost, multiplier, n) 
	return math.floor(baseCost * (multiplier ^ n))
end

local function applyStatUpdate(player, humanoid, statType, newValue)
	if statType == "JumpPower" then
		humanoid.JumpPower = newValue
		Leaderboard.setStat(player, JUMP_KEY_NAME, newValue)
		PlayerData.updateValue(player, JUMP_KEY_NAME, function() return newValue end)
	elseif statType == "WalkSpeed" then
		humanoid.WalkSpeed = newValue
		Leaderboard.setStat(player, SPEED_KEY_NAME, newValue)
		PlayerData.updateValue(player, SPEED_KEY_NAME, function() return newValue end)
	end
end

local function isCharacterOnPad(upgradePad, character)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return false
	end

	local localPosition = upgradePad.CFrame:PointToObjectSpace(rootPart.Position)

	local halfSize = upgradePad.Size / 2

	local withinX = math.abs(localPosition.X) <= halfSize.X
	local withinZ = math.abs(localPosition.Z) <= halfSize.Z

	local verticalTolerance = 6
	local withinY = localPosition.Y >= -verticalTolerance and localPosition.Y <= verticalTolerance

	return withinX and withinZ and withinY
end

local function setupUpgradePad(upgradePad)
	local upgradeType = upgradePad:GetAttribute("UpgradeType")
	local baseCost = upgradePad:GetAttribute("Cost")
	local boostAmount = upgradePad:GetAttribute("BoostAmount")
	local multiplier = upgradePad:GetAttribute("Multiplier")
	local padId = upgradePad:GetAttribute("PadId")
	
	padDataCache[upgradePad] = {
		upgradeType = upgradeType,
		baseCost = baseCost,
		boostAmount = boostAmount,
		multiplier = multiplier,
		padId = padId
	}
	
	local stateByPlayer = {}
	
	local function updateClientText(player, n_value)
		local currentCost = calculateCurrentCost(baseCost, multiplier, n_value)
		local newText = string.format("+%d %s\n%d coins", boostAmount, upgradeType, currentCost)
		padVisualEvent:FireClient(player, upgradePad, "UpdateText", newText)
	end
	
	
	local function clearStatePlayer(player)
		stateByPlayer[player] = nil
		padVisualEvent:FireClient(player, upgradePad, "HoldCancel")
	end
	
	local function purchaseUpgrade(player, character)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return false
		end
		
		local userId = player.UserId
		if not playerPurchaseHistory[userId] then playerPurchaseHistory[userId] = {} end
		local n = playerPurchaseHistory[userId][padId] or 0
		
		local currentCost = calculateCurrentCost(baseCost, multiplier, n)
		local currentCoins = PlayerData.getValue(player, COIN_KEY_NAME) or 0
		
		if currentCoins < currentCost then
			return false
		end
		
		local newCoinAmount = PlayerData.updateValue(player, COIN_KEY_NAME, function(oldAmount)
			return (oldAmount or 0) - currentCost
		end)
		
		Leaderboard.setStat(player, COIN_KEY_NAME, newCoinAmount)
		playerPurchaseHistory[userId][padId] = n + 1
		PlayerData.updateValue(player, UPGRADES_HISTORY_KEY_NAME, function() return playerPurchaseHistory[userId] end)

		if upgradeType == "JumpPower" then
			applyStatUpdate(player, humanoid, "JumpPower", humanoid.JumpPower + boostAmount)
		elseif upgradeType == "WalkSpeed" then
			applyStatUpdate(player, humanoid, "WalkSpeed", humanoid.WalkSpeed + boostAmount)
		end
		
		local nextCost = calculateCurrentCost(baseCost, multiplier, n+1)
		updateClientText(player, n+1)
		
		return true
	end
	
	task.spawn(function()
		while upgradePad.Parent do 
			for _, player in Players:GetPlayers() do 
				local character = player.Character
				local playerState = stateByPlayer[player]
				
				if not character then
					if playerState then
						clearStatePlayer(player)
					end
					continue
				end
								
				local onPad = isCharacterOnPad(upgradePad, character)
								
				if not onPad then
					if playerState then
						clearStatePlayer(player)
					end
					continue
				end
				
				if playerState and playerState.mode == "waiting_for_exit" then
					continue
				end
				
				local userId = player.UserId
				if not playerPurchaseHistory[userId] then playerPurchaseHistory[userId] = {} end
				local n = playerPurchaseHistory[userId][padId] or 0

				local currentCost = calculateCurrentCost(baseCost, multiplier, n)
				local currentCoins = PlayerData.getValue(player, COIN_KEY_NAME) or 0
				
				if currentCoins < currentCost then
					if not playerState then
						stateByPlayer[player] = { mode = "insufficient_funds" }
						padVisualEvent:FireClient(player, upgradePad, "NotEnoughMoney")
					end
					continue
				end
				
				if not playerState or playerState.mode ~= "holding" then 
					stateByPlayer[player] = { mode = "holding", holdStartTime = tick() }
					padVisualEvent:FireClient(player, upgradePad, "HoldStart")
					continue
				end
				
				local heldTime = tick() - playerState.holdStartTime
				if heldTime >= HOLD_DURATION then
					
					local success = purchaseUpgrade(player, character)
					
					if success then
						padVisualEvent:FireClient(player, upgradePad, "PurchaseSuccess")
					else
						padVisualEvent:FireClient(player, upgradePad, "HoldCancel")
					end
					
					stateByPlayer[player] = { mode = "waiting_for_exit"}
				end
			end
			
			task.wait(PAD_CHECK_INTERVAL)
		end
	end)
end

getPadInitialText.OnServerInvoke = function(player, requestedPad)	
	local data = padDataCache[requestedPad]
	if not data then 
		warn("[SERVER] ERROR: No se encontró data en caché para el pad solicitado.")
		return "Error" 
	end
	
	local userId = player.UserId
	local n = 0
	if playerPurchaseHistory[userId] and playerPurchaseHistory[userId][data.padId] then
		n = playerPurchaseHistory[userId][data.padId]
	end
	
	local currentCost = calculateCurrentCost(data.baseCost, data.multiplier, n)
	local resultText = string.format("+%d %s\n%d coins", data.boostAmount, data.upgradeType, currentCost)
	
	return resultText
end

for _, upgradePad in upgradesFolder:GetChildren() do
	setupUpgradePad(upgradePad)
end

local function onPlayerAdded(player)
	local savedHistory = PlayerData.getValue(player, UPGRADES_HISTORY_KEY_NAME)
	
	if savedHistory and type(savedHistory) == "table" then
		playerPurchaseHistory[player.UserId] = savedHistory
	else
		playerPurchaseHistory[player.UserId] = {}
	end
	
	local savedJump = PlayerData.getValue(player, JUMP_KEY_NAME)
	local savedSpeed = PlayerData.getValue(player, SPEED_KEY_NAME)
	
	local currentJump = if (savedJump == nil or savedJump == 0) then JUMP_POWER_INITIAL else savedJump
	local currentSpeed = if (savedSpeed == nil or savedSpeed == 0) then WALK_SPEED_INITIAL else savedSpeed
	
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")	
					
		applyStatUpdate(player, humanoid, "JumpPower", currentJump)
		applyStatUpdate(player, humanoid, "WalkSpeed", currentSpeed)

	end)
end

local function onPlayerRemoved(player)
	PlayerData.removeData(player)
end

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoved)

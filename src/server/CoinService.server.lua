
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Leaderboard = require(ServerScriptService.modules.Leaderboard)
local PlayerData = require(ServerScriptService.modules.PlayerData)

local COIN_KEY_NAME = PlayerData.COIN_KEY_NAME
local COIN_COOLDOWN = 10
local COIN_INCREMENT = 100
local COIN_SPIN_SPEED = 120
local COIN_TAG_NAME = "Coin"

local activeCoinParts = {}

-- ==========================================
-- LÓGICA DE JUGADORES (Data y Leaderboard)
-- ==========================================
local function updatePlayerCoins(player, updateFunction)
	local newCoinAmount = PlayerData.updateValue(player, COIN_KEY_NAME, updateFunction)
	if newCoinAmount then 
		Leaderboard.setStat(player, COIN_KEY_NAME, newCoinAmount) 
	end
end

local function onPlayerAdded(player)
	local savedCoins = PlayerData.getValue(player, COIN_KEY_NAME)
	
	if not savedCoins then
		updatePlayerCoins(player, function() return 0 end)
	else
		Leaderboard.setStat(player, COIN_KEY_NAME, savedCoins)
	end
end

local function onPlayerRemoved(player)
	PlayerData.removeData(player)
end

-- ==========================================
-- LÓGICA DE INTERACCIÓN CON MONEDAS
-- ==========================================
local function onCoinTouched(otherPart, coinPart)
	if coinPart:GetAttribute("Enabled") then
		local character = otherPart:FindFirstAncestorOfClass("Model")
		local player = Players:GetPlayerFromCharacter(character)

		if player then
			coinPart.Transparency = 1
			coinPart:SetAttribute("Enabled", false)
			
			updatePlayerCoins(player, function(oldCoinAmount)
				return (oldCoinAmount or 0) + COIN_INCREMENT
			end)
			
			task.wait(COIN_COOLDOWN)
			coinPart.Transparency = 0
			coinPart:SetAttribute("Enabled", true)
		end
	end
end

-- ==========================================
-- LÓGICA DE COLLECTION SERVICE Y RENDIMIENTO
-- ==========================================
local function onCoinAdded(coinPackage)
	local coinPart = coinPackage:FindFirstChild("Coin")

	if coinPart then
		activeCoinParts[coinPart] = true

		coinPart:SetAttribute("Enabled", true)
		coinPart.Touched:Connect(function(otherPart)
			onCoinTouched(otherPart, coinPart)
		end)
	end
end

local function onCoinRemoved(coinPackage)
	local coinPart = coinPackage:FindFirstChild("Coin")
	if coinPart then
		activeCoinParts[coinPart] = nil
	end
end

CollectionService:GetInstanceAddedSignal(COIN_TAG_NAME):Connect(onCoinAdded)
CollectionService:GetInstanceRemovedSignal(COIN_TAG_NAME):Connect(onCoinRemoved)

for _, coinPackage in CollectionService:GetTagged(COIN_TAG_NAME) do 
	onCoinAdded(coinPackage)
end

-- ==========================================
-- LÓGICA DE GIRO
-- ==========================================
RunService.Heartbeat:Connect(function(deltaTime)
	local rotationAmount = math.rad(COIN_SPIN_SPEED * deltaTime)

	for coinPart in pairs(activeCoinParts) do
		coinPart.CFrame = coinPart.CFrame * CFrame.Angles(0, rotationAmount, 0)
	end
end)

-- ==========================================
-- INICIALIZAR EVENTOS DE JUGADORES
-- ==========================================
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoved)

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Leaderboard = require(ServerStorage.Leaderboard)
local PlayerData = require(ServerStorage.PlayerData)

local coins = Workspace.World.Coins:GetChildren()

local COIN_KEY_NAME = PlayerData.COIN_KEY_NAME
local COIN_COOLDOWN = 10
local COIN_INCREMENT = 100

local function updatePlayerCoins(player, updateFunction)
	local newCoinAmount = PlayerData.updateValue(player, COIN_KEY_NAME, updateFunction)
	if newCoinAmount then 
		Leaderboard.setStat(player, COIN_KEY_NAME, newCoinAmount) 
	end
end

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

for _, packageItem in coins do 
	local coinPart = packageItem:FindFirstChild("Coin")
	if coinPart then
		coinPart:SetAttribute("Enabled", true)
		coinPart.Touched:Connect(function(otherPart)
			onCoinTouched(otherPart, coinPart)
		end)
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

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoved)
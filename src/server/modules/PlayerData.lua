
local PlayerData = {}
PlayerData.COIN_KEY_NAME = "Coins"
PlayerData.JUMP_KEY_NAME = "Jump"
PlayerData.SPEED_KEY_NAME = "Speed"
PlayerData.UPGRADES_HISTORY_KEY_NAME = "UpgradesHistory"

local playerData = {}

local DEFAULT_PLAYER_DATA = table.freeze({
	[PlayerData.COIN_KEY_NAME] = 0,
	[PlayerData.JUMP_KEY_NAME] = 0,
	[PlayerData.SPEED_KEY_NAME] = 0,
})

local function getData(player)
	local id = player.UserId
	local data = playerData[id]
	
	if not data then
		data = table.clone(DEFAULT_PLAYER_DATA)
		playerData[id] = data
	end
	
	return data
end

function PlayerData.getValue(player, key)
	if not player then return nil end
	return getData(player)[key]
end

function PlayerData.updateValue(player, key, updateFunction)
	if not player then return nil end
	local data = getData(player)
	data[key] = updateFunction(data[key])
	return data[key]
end

function PlayerData.removeData(player)
	playerData[player.UserId] = nil
end

return PlayerData
-- ============================================================
-- DATASTORE BACKUP — Roblox DataStoreService fallback for Supabase
-- Persists critical player data locally in case Supabase is down
-- ============================================================

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local DataStoreBackup = {}

-- State
DataStoreBackup.dataStore = nil
DataStoreBackup.lastSaveTime = {} -- { [userId] = os.clock() timestamp }
DataStoreBackup._autoSaveConnection = nil

-- Config
local SAVE_DEBOUNCE = 30 -- minimum seconds between saves per player
local AUTO_SAVE_INTERVAL = 60 -- seconds between auto-save cycles
local DATA_STORE_NAME = "MansionMayhemPlayerData"

-- ============================================================
-- INITIALIZATION
-- ============================================================

function DataStoreBackup.init()
	local success, store = pcall(function()
		return DataStoreService:GetDataStore(DATA_STORE_NAME)
	end)

	if success then
		DataStoreBackup.dataStore = store
		print("[DataStoreBackup] DataStore initialized:", DATA_STORE_NAME)
	else
		warn("[DataStoreBackup] Failed to get DataStore:", store)
	end
end

-- ============================================================
-- SAVE PLAYER DATA
-- ============================================================

function DataStoreBackup.savePlayer(userId, data)
	if not DataStoreBackup.dataStore then return false end
	if not userId or not data then return false end

	-- Debounce: max once per 30 seconds per player
	local now = os.clock()
	if DataStoreBackup.lastSaveTime[userId] and (now - DataStoreBackup.lastSaveTime[userId]) < SAVE_DEBOUNCE then
		return false -- too soon, skip
	end

	local key = "player_" .. tostring(userId)

	-- Build the data table with only the fields we want to persist
	local saveData = {
		xp = data.xp or 0,
		coins = data.coins or 0,
		immunityShards = data.immunityShards or 0,
		immunityTokens = data.immunityTokens or 0,
		fightsWon = data.fightsWon or 0,
		fightsLost = data.fightsLost or 0,
		allianceCount = data.allianceCount or 0,
		betrayalCount = data.betrayalCount or 0,
		checkedInToday = data.checkedInToday or false,
		lastCheckIn = data.lastCheckIn or "",
		eliminated = data.eliminated or false,
		queenCount = data.queenCount or 0,
		savedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
	}

	local success, err = pcall(function()
		DataStoreBackup.dataStore:SetAsync(key, saveData)
	end)

	if success then
		DataStoreBackup.lastSaveTime[userId] = now
		return true
	else
		warn("[DataStoreBackup] Save failed for", userId, ":", err)
		return false
	end
end

-- ============================================================
-- LOAD PLAYER DATA
-- ============================================================

function DataStoreBackup.loadPlayer(userId)
	if not DataStoreBackup.dataStore then return nil end
	if not userId then return nil end

	local key = "player_" .. tostring(userId)

	local success, data = pcall(function()
		return DataStoreBackup.dataStore:GetAsync(key)
	end)

	if success and data then
		print("[DataStoreBackup] Loaded data for player", userId)
		return data
	elseif not success then
		warn("[DataStoreBackup] Load failed for", userId, ":", data)
	end

	return nil
end

-- ============================================================
-- DELETE PLAYER DATA
-- ============================================================

function DataStoreBackup.deletePlayer(userId)
	if not DataStoreBackup.dataStore then return false end
	if not userId then return false end

	local key = "player_" .. tostring(userId)

	local success, err = pcall(function()
		DataStoreBackup.dataStore:RemoveAsync(key)
	end)

	if success then
		print("[DataStoreBackup] Deleted data for player", userId)
		DataStoreBackup.lastSaveTime[userId] = nil
		return true
	else
		warn("[DataStoreBackup] Delete failed for", userId, ":", err)
		return false
	end
end

-- ============================================================
-- AUTO-SAVE ALL ACTIVE PLAYERS
-- ============================================================

function DataStoreBackup.autoSave(gameManager)
	if not DataStoreBackup.dataStore then return end
	if not gameManager or not gameManager.playerMap then return end

	local savedCount = 0

	for userId, playerData in gameManager.playerMap do
		-- Build a complete data snapshot from playerMap + subsystem state
		local fullData = DataStoreBackup._buildFullPlayerData(userId, playerData, gameManager)

		local saved = DataStoreBackup.savePlayer(userId, fullData)
		if saved then
			savedCount += 1
		end
	end

	if savedCount > 0 then
		print("[DataStoreBackup] Auto-save complete:", savedCount, "player(s) saved")
	end
end

-- ============================================================
-- ON PLAYER LEAVE — Save before disconnect
-- ============================================================

function DataStoreBackup.onPlayerLeave(player, gameManager)
	if not player or not gameManager then return end

	local userId = player.UserId
	local playerData = gameManager.playerMap[userId]
	if not playerData then return end

	-- Force save (bypass debounce by clearing last save time)
	DataStoreBackup.lastSaveTime[userId] = nil

	local fullData = DataStoreBackup._buildFullPlayerData(userId, playerData, gameManager)
	local saved = DataStoreBackup.savePlayer(userId, fullData)

	if saved then
		print("[DataStoreBackup] Saved data for departing player:", player.Name)
	end
end

-- ============================================================
-- MERGE LOADED DATA INTO PLAYER MAP ENTRY
-- ============================================================

function DataStoreBackup.mergeIntoPlayerData(playerData, savedData)
	if not playerData or not savedData then return playerData end

	-- Only merge numeric/persistent fields, don't override fresh session state
	playerData.xp = math.max(playerData.xp or 0, savedData.xp or 0)
	playerData.coins = math.max(playerData.coins or 0, savedData.coins or 0)
	playerData.fightsWon = math.max(playerData.fightsWon or 0, savedData.fightsWon or 0)
	playerData.fightsLost = math.max(playerData.fightsLost or 0, savedData.fightsLost or 0)
	playerData.queenCount = math.max(playerData.queenCount or 0, savedData.queenCount or 0)

	-- Carry forward elimination status
	if savedData.eliminated then
		playerData.eliminated = true
	end

	return playerData
end

-- ============================================================
-- INTERNAL: Build full data snapshot
-- ============================================================

function DataStoreBackup._buildFullPlayerData(userId, playerData, gameManager)
	local data = {
		xp = playerData.xp or 0,
		coins = playerData.coins or 0,
		fightsWon = playerData.fightsWon or 0,
		fightsLost = playerData.fightsLost or 0,
		eliminated = playerData.eliminated or false,
		queenCount = playerData.queenCount or 0,
		checkedInToday = playerData.checkedIn or false,
		lastCheckIn = playerData.lastCheckIn or "",
	}

	-- Pull immunity data from ImmunitySystem
	if gameManager.immunitySystem then
		data.immunityShards = gameManager.immunitySystem.getShards(userId)
		data.immunityTokens = gameManager.immunitySystem.getTokens(userId)
	else
		data.immunityShards = 0
		data.immunityTokens = 0
	end

	-- Pull alliance stats from AllianceSystem
	if gameManager.allianceSystem then
		local stats = gameManager.allianceSystem.getPlayerStats(userId)
		data.allianceCount = stats.alliance_count or 0
		data.betrayalCount = stats.betrayal_count or 0
	else
		data.allianceCount = 0
		data.betrayalCount = 0
	end

	return data
end

-- ============================================================
-- START AUTO-SAVE LOOP
-- ============================================================

function DataStoreBackup.startAutoSaveLoop(gameManager)
	DataStoreBackup._autoSaveConnection = task.spawn(function()
		while true do
			task.wait(AUTO_SAVE_INTERVAL)
			DataStoreBackup.autoSave(gameManager)
		end
	end)
	print("[DataStoreBackup] Auto-save loop started (every", AUTO_SAVE_INTERVAL, "seconds)")
end

return DataStoreBackup

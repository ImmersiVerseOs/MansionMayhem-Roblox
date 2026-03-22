-- ============================================================
-- FIGHT SYSTEM — Proximity-triggered altercations in the Mansion
-- Detects fights, tracks intensity, dispatches security, awards XP
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SupabaseAPI = require(script.Parent.SupabaseAPI)
local Config = require(ReplicatedStorage.Shared.Config)

local FightSystem = {}

-- State
FightSystem.activeFights = {} -- { [fightId] = fightData }
FightSystem.fightCooldowns = {} -- { [sortedPlayerKey] = cooldownEndTime }
FightSystem.playerProximity = {} -- { [sortedPlayerKey] = { startTime, distance } }
FightSystem.fightIdCounter = 0
FightSystem._heartbeatConnection = nil

-- Config
local PROXIMITY_TRIGGER_DISTANCE = 5 -- studs
local PROXIMITY_TRIGGER_DURATION = 3 -- seconds of close proximity to trigger
local FIGHT_COOLDOWN = 120 -- seconds between fights for same pair
local SECURITY_DISPATCH_THRESHOLD = 7 -- intensity threshold
local SECURITY_BREAKUP_DELAY = 10 -- seconds before security arrives
local FIGHT_AUTO_RESOLVE_TIME = 30 -- seconds before auto-resolve
local XP_WINNER = 25
local XP_LOSER = -10
local XP_INSTIGATOR_PENALTY = -15
local DRAMA_PER_INTENSITY = 5

-- Fight locations
local MANSION_ROOMS = {
	"Lobby", "Living Room", "Kitchen", "Drama Room",
	"Confession Booth", "Rooftop", "Corridor", "Bedroom",
}

-- ============================================================
-- INITIALIZATION
-- ============================================================

function FightSystem.init()
	-- Start proximity detection loop
	FightSystem._heartbeatConnection = RunService.Heartbeat:Connect(function()
		FightSystem._checkProximity()
	end)

	print("[FightSystem] Initialized — proximity detection active")
end

-- ============================================================
-- PROXIMITY DETECTION
-- ============================================================

function FightSystem._checkProximity()
	local players = Players:GetPlayers()
	local now = os.clock()

	for i = 1, #players do
		for j = i + 1, #players do
			local p1 = players[i]
			local p2 = players[j]

			if not p1.Character or not p2.Character then continue end
			local hrp1 = p1.Character:FindFirstChild("HumanoidRootPart")
			local hrp2 = p2.Character:FindFirstChild("HumanoidRootPart")
			if not hrp1 or not hrp2 then continue end

			local distance = (hrp1.Position - hrp2.Position).Magnitude
			local key = FightSystem._pairKey(p1.UserId, p2.UserId)

			if distance <= PROXIMITY_TRIGGER_DISTANCE then
				-- Players are close
				if not FightSystem.playerProximity[key] then
					FightSystem.playerProximity[key] = {
						startTime = now,
						player1 = p1,
						player2 = p2,
					}
				else
					local elapsed = now - FightSystem.playerProximity[key].startTime
					if elapsed >= PROXIMITY_TRIGGER_DURATION then
						-- Check cooldown
						if not FightSystem.fightCooldowns[key] or FightSystem.fightCooldowns[key] < now then
							-- Proximity trigger met — offer fight interaction
							FightSystem._offerFightInteraction(p1, p2, key)
							FightSystem.playerProximity[key] = nil -- reset
						end
					end
				end
			else
				-- Players moved apart
				FightSystem.playerProximity[key] = nil
			end
		end
	end
end

function FightSystem._pairKey(id1, id2)
	if id1 < id2 then
		return id1 .. "_" .. id2
	else
		return id2 .. "_" .. id1
	end
end

function FightSystem._offerFightInteraction(player1, player2, pairKey)
	-- Send fight prompt to both players
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("FightPrompt")
	if remote then
		remote:FireClient(player1, {
			targetUserId = player2.UserId,
			targetName = player2.DisplayName or player2.Name,
		})
		remote:FireClient(player2, {
			targetUserId = player1.UserId,
			targetName = player1.DisplayName or player1.Name,
		})
	end
end

-- ============================================================
-- FIGHT INITIATION (called by client interaction)
-- ============================================================

function FightSystem.startFight(aggressor, defenderUserId, reason, gameManager)
	if not aggressor then return nil end

	local defender = Players:GetPlayerByUserId(defenderUserId)
	if not defender then return nil end

	local pairKey = FightSystem._pairKey(aggressor.UserId, defenderUserId)

	-- Check cooldown
	local now = os.clock()
	if FightSystem.fightCooldowns[pairKey] and FightSystem.fightCooldowns[pairKey] > now then
		return nil
	end

	-- Determine intensity based on player history
	local intensity = FightSystem._calculateIntensity(aggressor.UserId, defenderUserId, gameManager)

	-- Generate fight ID
	FightSystem.fightIdCounter += 1
	local fightId = "fight_" .. FightSystem.fightIdCounter .. "_" .. os.time()

	-- Determine location based on character position
	local location = FightSystem._detectLocation(aggressor)

	-- Create fight record
	local fight = {
		id = fightId,
		aggressorId = aggressor.UserId,
		aggressorName = aggressor.DisplayName or aggressor.Name,
		defenderId = defenderUserId,
		defenderName = defender.DisplayName or defender.Name,
		intensity = intensity,
		location = location,
		reason = reason or "Tensions boiled over",
		status = "active",
		startTime = os.clock(),
		dramaPoints = intensity * DRAMA_PER_INTENSITY,
		securityDispatched = false,
	}

	FightSystem.activeFights[fightId] = fight

	-- Set cooldown
	FightSystem.fightCooldowns[pairKey] = os.clock() + FIGHT_COOLDOWN

	print("[FightSystem] FIGHT STARTED:", fight.aggressorName, "vs", fight.defenderName, "— Intensity:", intensity, "at", location)

	-- Broadcast fight alert to all players
	FightSystem._broadcastFightAlert(fight, gameManager)

	-- Auto-dispatch security at high intensity
	if intensity >= SECURITY_DISPATCH_THRESHOLD then
		fight.securityDispatched = true
		FightSystem._dispatchSecurity(fightId, gameManager)
	end

	-- Auto-resolve timer
	task.delay(FIGHT_AUTO_RESOLVE_TIME, function()
		if FightSystem.activeFights[fightId] and FightSystem.activeFights[fightId].status == "active" then
			FightSystem.resolveFight(fightId, nil, gameManager)
		end
	end)

	-- Call Supabase
	if gameManager and gameManager.seasonData then
		local seasonId = gameManager.seasonData.season and gameManager.seasonData.season.id
		if seasonId then
			task.spawn(function()
				SupabaseAPI.startFight(
					seasonId,
					tostring(aggressor.UserId),
					tostring(defenderUserId),
					location,
					reason or "Tensions boiled over",
					intensity
				)
			end)
		end
	end

	return fight
end

function FightSystem._calculateIntensity(aggressorId, defenderId, gameManager)
	local base = math.random(3, 6)

	-- Check if they are in same alliance (betrayal = higher intensity)
	if gameManager and gameManager.allianceSystem then
		local sameAlliance = gameManager.allianceSystem.areAllied(aggressorId, defenderId)
		if sameAlliance then
			base += 2 -- betrayal makes fights more intense
		end
	end

	-- Check fight history between pair
	local pairKey = FightSystem._pairKey(aggressorId, defenderId)
	local previousFights = 0
	for _, fight in FightSystem.activeFights do
		if fight.status == "resolved" then
			local fk = FightSystem._pairKey(fight.aggressorId, fight.defenderId)
			if fk == pairKey then
				previousFights += 1
			end
		end
	end
	base += math.min(previousFights, 3) -- recurring fights escalate

	return math.min(math.max(base, 1), 10)
end

function FightSystem._detectLocation(player)
	if not player.Character then return "Unknown" end
	local hrp = player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return "Unknown" end

	local pos = hrp.Position

	-- Check position against known room coordinates
	if pos.Y > 35 then return "Rooftop" end
	if pos.Y > 18 then return "Bedrooms" end

	if pos.X < 40 then return "Lobby" end
	if pos.X >= 40 and pos.X < 70 and pos.Z > 10 then return "Living Room" end
	if pos.X >= 80 and pos.X < 110 and pos.Z > 10 then return "Kitchen" end
	if pos.X >= 40 and pos.X < 70 and pos.Z < -10 then return "Drama Room" end
	if pos.X >= 80 and pos.X < 110 and pos.Z < -10 then return "Confession Booth" end
	if pos.X >= 120 and pos.Z < -5 then return "Elimination Room" end

	return "Corridor"
end

-- ============================================================
-- FIGHT ALERTS
-- ============================================================

function FightSystem._broadcastFightAlert(fight, gameManager)
	-- Director announcement
	if gameManager then
		local intensityWord = fight.intensity >= 7 and "MAJOR" or (fight.intensity >= 4 and "heated" or "minor")
		gameManager.directorAnnounce(
			"FIGHT ALERT: A " .. intensityWord .. " altercation between " ..
			fight.aggressorName .. " and " .. fight.defenderName ..
			" in the " .. fight.location .. "! Intensity: " .. fight.intensity .. "/10"
		)
	end

	-- Send alert to all clients
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("FightAlert")
	if remote then
		remote:FireAllClients({
			fightId = fight.id,
			aggressor = fight.aggressorName,
			defender = fight.defenderName,
			intensity = fight.intensity,
			location = fight.location,
			securityDispatched = fight.securityDispatched,
			message = fight.securityDispatched and "SECURITY HAS BEEN DISPATCHED!" or "The cameras are rolling...",
		})
	end
end

-- ============================================================
-- SECURITY DISPATCH
-- ============================================================

function FightSystem._dispatchSecurity(fightId, gameManager)
	print("[FightSystem] SECURITY DISPATCHED for fight:", fightId)

	if gameManager then
		task.wait(2)
		gameManager.directorAnnounce("SECURITY TO THE " .. string.upper(FightSystem.activeFights[fightId].location) .. "! BREAK IT UP!")
	end

	-- Security NPC behavior: after delay, break up the fight
	task.delay(SECURITY_BREAKUP_DELAY, function()
		local fight = FightSystem.activeFights[fightId]
		if fight and fight.status == "active" then
			FightSystem.breakupFight(fightId, gameManager)
		end
	end)
end

function FightSystem.breakupFight(fightId, gameManager)
	local fight = FightSystem.activeFights[fightId]
	if not fight or fight.status ~= "active" then return end

	fight.status = "broken_up"
	print("[FightSystem] Fight broken up by security:", fight.aggressorName, "vs", fight.defenderName)

	if gameManager then
		gameManager.directorAnnounce("Security has separated " .. fight.aggressorName .. " and " .. fight.defenderName .. ". Everyone cool off.")
	end

	-- Separate the players physically
	local aggressor = Players:GetPlayerByUserId(fight.aggressorId)
	local defender = Players:GetPlayerByUserId(fight.defenderId)

	if aggressor and aggressor.Character then
		local hrp = aggressor.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.CFrame = CFrame.new(hrp.Position + Vector3.new(15, 0, 0))
		end
	end

	if defender and defender.Character then
		local hrp = defender.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.CFrame = CFrame.new(hrp.Position + Vector3.new(-15, 0, 0))
		end
	end

	-- Then resolve
	task.delay(3, function()
		FightSystem.resolveFight(fightId, nil, gameManager)
	end)
end

-- ============================================================
-- FIGHT RESOLUTION
-- ============================================================

function FightSystem.resolveFight(fightId, winnerId, gameManager)
	local fight = FightSystem.activeFights[fightId]
	if not fight then return end
	if fight.status == "resolved" then return end

	fight.status = "resolved"

	-- Determine winner if not specified (random based on intensity)
	if not winnerId then
		-- Higher intensity = aggressor more likely to "lose" (impulsive)
		local aggressorWinChance = 0.5 - (fight.intensity * 0.03)
		if math.random() < aggressorWinChance then
			winnerId = fight.aggressorId
		else
			winnerId = fight.defenderId
		end
	end

	local loserId = winnerId == fight.aggressorId and fight.defenderId or fight.aggressorId
	local winnerName = winnerId == fight.aggressorId and fight.aggressorName or fight.defenderName
	local loserName = loserId == fight.aggressorId and fight.aggressorName or fight.defenderName

	print("[FightSystem] Fight resolved:", winnerName, "wins over", loserName)

	-- XP rewards/penalties
	FightSystem._applyXP(fight, winnerId, loserId, gameManager)

	-- Notify clients
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("FightResolved")
	if remote then
		remote:FireAllClients({
			fightId = fightId,
			winner = winnerName,
			loser = loserName,
			intensity = fight.intensity,
			dramaPoints = fight.dramaPoints,
		})
	end

	-- Consequences announcement
	if gameManager and fight.intensity >= 8 then
		task.wait(2)
		gameManager.directorAnnounce(fight.aggressorName .. " receives an EXILE WARNING for starting a high-intensity fight.")
	end

	return {
		winner = winnerId,
		loser = loserId,
		intensity = fight.intensity,
		dramaPoints = fight.dramaPoints,
	}
end

function FightSystem._applyXP(fight, winnerId, loserId, gameManager)
	if not gameManager then return end

	-- Winner XP
	local winnerData = gameManager.playerMap[winnerId]
	if winnerData then
		winnerData.xp = (winnerData.xp or 0) + XP_WINNER
	end

	-- Loser XP
	local loserData = gameManager.playerMap[loserId]
	if loserData then
		loserData.xp = math.max(0, (loserData.xp or 0) + XP_LOSER)
	end

	-- Instigator penalty (always applies to aggressor)
	local aggressorData = gameManager.playerMap[fight.aggressorId]
	if aggressorData then
		aggressorData.xp = math.max(0, (aggressorData.xp or 0) + XP_INSTIGATOR_PENALTY)
	end

	-- Track fight stats
	if winnerData then winnerData.fightsWon = (winnerData.fightsWon or 0) + 1 end
	if loserData then loserData.fightsLost = (loserData.fightsLost or 0) + 1 end
end

-- ============================================================
-- UTILITIES
-- ============================================================

function FightSystem.getActiveFights()
	local list = {}
	for _, fight in FightSystem.activeFights do
		if fight.status == "active" then
			table.insert(list, fight)
		end
	end
	return list
end

function FightSystem.onPlayerLeave(player)
	-- Resolve any active fights involving this player
	for fightId, fight in FightSystem.activeFights do
		if fight.status == "active" then
			if fight.aggressorId == player.UserId or fight.defenderId == player.UserId then
				fight.status = "resolved"
				print("[FightSystem] Fight auto-resolved — player left:", player.Name)
			end
		end
	end

	-- Clean up proximity tracking
	for key, data in FightSystem.playerProximity do
		if data.player1 == player or data.player2 == player then
			FightSystem.playerProximity[key] = nil
		end
	end
end

function FightSystem.shutdown()
	if FightSystem._heartbeatConnection then
		FightSystem._heartbeatConnection:Disconnect()
		FightSystem._heartbeatConnection = nil
	end
end

return FightSystem

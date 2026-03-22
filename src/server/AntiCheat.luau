-- ============================================================
-- ANTI-CHEAT — Server-side validation for all game actions
-- Never trust client data. Validate everything before processing.
-- ============================================================

local Players = game:GetService("Players")

local AntiCheat = {}

-- State
AntiCheat.violations = {} -- { [userId] = { count, actions = {} } }
AntiCheat.rateLimits = {} -- { [userId .. "_" .. action] = lastTimestamp }
AntiCheat.fightLog = {} -- { [userId] = { today = dateString, count = number } }
AntiCheat.fightPairCooldowns = {} -- { [pairKey] = expiresAt (os.clock) }
AntiCheat.immunityUsedThisRound = {} -- { [userId] = true }

-- Config
local WARN_THRESHOLD = 3
local KICK_THRESHOLD = 5

-- ============================================================
-- INITIALIZATION
-- ============================================================

function AntiCheat.init()
	print("[AntiCheat] Server-side validation system initialized")
end

-- ============================================================
-- VOTE VALIDATION
-- ============================================================

function AntiCheat.validateVote(player, nomineeUserId, gameManager)
	if not player or not nomineeUserId then
		return false, "missing_params"
	end

	local userId = player.UserId

	-- Check: player isn't eliminated
	local playerData = gameManager.playerMap[userId]
	if not playerData then
		AntiCheat.logSuspicious(player, "vote", "player not in playerMap")
		return false, "not_in_game"
	end
	if playerData.eliminated then
		AntiCheat.logSuspicious(player, "vote", "eliminated player tried to vote")
		return false, "eliminated"
	end

	-- Check: voting phase is active
	local votingSystem = gameManager.votingSystem
	if not votingSystem or votingSystem.phase ~= "voting" then
		AntiCheat.logSuspicious(player, "vote", "vote outside voting phase: " .. tostring(votingSystem and votingSystem.phase))
		return false, "wrong_phase"
	end

	-- Check: nominee exists and is a valid nominee
	if not votingSystem.nominees[nomineeUserId] then
		AntiCheat.logSuspicious(player, "vote", "voted for non-nominee: " .. tostring(nomineeUserId))
		return false, "invalid_nominee"
	end

	-- Check: nominee isn't eliminated
	local nomineeData = gameManager.playerMap[nomineeUserId]
	if nomineeData and nomineeData.eliminated then
		AntiCheat.logSuspicious(player, "vote", "voted for eliminated player")
		return false, "nominee_eliminated"
	end

	-- Check: nominee isn't immune
	local immunitySystem = gameManager.immunitySystem
	if immunitySystem and immunitySystem.isImmune(nomineeUserId) then
		AntiCheat.logSuspicious(player, "vote", "voted for immune player: " .. tostring(nomineeUserId))
		return false, "nominee_immune"
	end

	-- Check: can't vote for yourself
	if userId == nomineeUserId then
		AntiCheat.logSuspicious(player, "vote", "tried to vote for self")
		return false, "self_vote"
	end

	return true, "ok"
end

-- ============================================================
-- NOMINATION VALIDATION
-- ============================================================

function AntiCheat.validateNomination(player, nomineeUserId, gameManager)
	if not player or not nomineeUserId then
		return false, "missing_params"
	end

	local userId = player.UserId

	-- Check: player isn't eliminated
	local playerData = gameManager.playerMap[userId]
	if not playerData then
		AntiCheat.logSuspicious(player, "nomination", "player not in playerMap")
		return false, "not_in_game"
	end
	if playerData.eliminated then
		AntiCheat.logSuspicious(player, "nomination", "eliminated player tried to nominate")
		return false, "eliminated"
	end

	-- Check: nomination phase active
	local votingSystem = gameManager.votingSystem
	if not votingSystem or votingSystem.phase ~= "nominating" then
		AntiCheat.logSuspicious(player, "nomination", "nomination outside phase: " .. tostring(votingSystem and votingSystem.phase))
		return false, "wrong_phase"
	end

	-- Check: nominee exists in the server
	local nomineePlayer = Players:GetPlayerByUserId(nomineeUserId)
	if not nomineePlayer then
		AntiCheat.logSuspicious(player, "nomination", "nominee not in server: " .. tostring(nomineeUserId))
		return false, "player_not_found"
	end

	-- Check: nominee isn't eliminated
	local nomineeData = gameManager.playerMap[nomineeUserId]
	if nomineeData and nomineeData.eliminated then
		return false, "nominee_eliminated"
	end

	-- Check: can't nominate yourself
	if userId == nomineeUserId then
		AntiCheat.logSuspicious(player, "nomination", "tried to nominate self")
		return false, "self_nominate"
	end

	return true, "ok"
end

-- ============================================================
-- FIGHT VALIDATION
-- ============================================================

function AntiCheat.validateFight(player, defenderUserId, gameManager)
	if not player or not defenderUserId then
		return false, "missing_params"
	end

	local userId = player.UserId

	-- Check: not the same player
	if userId == defenderUserId then
		AntiCheat.logSuspicious(player, "fight", "tried to fight self")
		return false, "self_fight"
	end

	-- Check: attacker is alive and not eliminated
	local attackerData = gameManager.playerMap[userId]
	if not attackerData then
		AntiCheat.logSuspicious(player, "fight", "attacker not in playerMap")
		return false, "not_in_game"
	end
	if attackerData.eliminated then
		AntiCheat.logSuspicious(player, "fight", "eliminated player tried to fight")
		return false, "eliminated"
	end

	-- Check: defender exists and is not eliminated
	local defenderPlayer = Players:GetPlayerByUserId(defenderUserId)
	if not defenderPlayer then
		return false, "defender_not_found"
	end
	local defenderData = gameManager.playerMap[defenderUserId]
	if not defenderData then
		return false, "defender_not_in_game"
	end
	if defenderData.eliminated then
		return false, "defender_eliminated"
	end

	-- Check: cooldown between same pair (60 seconds)
	local pairKey = AntiCheat._pairKey(userId, defenderUserId)
	local now = os.clock()
	if AntiCheat.fightPairCooldowns[pairKey] and AntiCheat.fightPairCooldowns[pairKey] > now then
		return false, "pair_cooldown"
	end

	-- Check: fight limit per player per day (max 5)
	local today = os.date("!%Y-%m-%d")
	if not AntiCheat.fightLog[userId] then
		AntiCheat.fightLog[userId] = { today = today, count = 0 }
	end
	-- Reset count if new day
	if AntiCheat.fightLog[userId].today ~= today then
		AntiCheat.fightLog[userId] = { today = today, count = 0 }
	end
	if AntiCheat.fightLog[userId].count >= 5 then
		AntiCheat.logSuspicious(player, "fight", "exceeded daily fight limit")
		return false, "daily_limit"
	end

	return true, "ok"
end

-- Record a fight after validation passes (called by GameManager)
function AntiCheat.recordFight(attackerUserId, defenderUserId)
	local pairKey = AntiCheat._pairKey(attackerUserId, defenderUserId)
	AntiCheat.fightPairCooldowns[pairKey] = os.clock() + 60

	local today = os.date("!%Y-%m-%d")
	if not AntiCheat.fightLog[attackerUserId] then
		AntiCheat.fightLog[attackerUserId] = { today = today, count = 0 }
	end
	if AntiCheat.fightLog[attackerUserId].today ~= today then
		AntiCheat.fightLog[attackerUserId] = { today = today, count = 0 }
	end
	AntiCheat.fightLog[attackerUserId].count += 1
end

function AntiCheat._pairKey(id1, id2)
	if id1 < id2 then
		return id1 .. "_" .. id2
	else
		return id2 .. "_" .. id1
	end
end

-- ============================================================
-- ALLIANCE PROPOSAL VALIDATION
-- ============================================================

function AntiCheat.validateAllianceProposal(player, targetUserId, gameManager)
	if not player or not targetUserId then
		return false, "missing_params"
	end

	local userId = player.UserId

	-- Check: not the same player
	if userId == targetUserId then
		AntiCheat.logSuspicious(player, "alliance", "tried to ally with self")
		return false, "self_alliance"
	end

	-- Check: proposer is alive and not eliminated
	local proposerData = gameManager.playerMap[userId]
	if not proposerData then
		return false, "not_in_game"
	end
	if proposerData.eliminated then
		AntiCheat.logSuspicious(player, "alliance", "eliminated player tried to propose alliance")
		return false, "eliminated"
	end

	-- Check: target exists and is not eliminated
	local targetPlayer = Players:GetPlayerByUserId(targetUserId)
	if not targetPlayer then
		return false, "target_not_found"
	end
	local targetData = gameManager.playerMap[targetUserId]
	if not targetData then
		return false, "target_not_in_game"
	end
	if targetData.eliminated then
		return false, "target_eliminated"
	end

	-- Check: not already in same alliance
	local allianceSystem = gameManager.allianceSystem
	if allianceSystem then
		if allianceSystem.areAllied(userId, targetUserId) then
			return false, "already_allied"
		end

		-- Check: max alliance size not exceeded
		local proposerAllianceId = allianceSystem.playerAlliance[userId]
		if proposerAllianceId then
			local alliance = allianceSystem.alliances[proposerAllianceId]
			if alliance then
				local memberCount = 0
				for _ in alliance.members do memberCount += 1 end
				if memberCount >= 4 then -- MAX_ALLIANCE_SIZE
					return false, "alliance_full"
				end
			end
		end
	end

	return true, "ok"
end

-- ============================================================
-- IMMUNITY USE VALIDATION
-- ============================================================

function AntiCheat.validateImmunityUse(player, gameManager)
	if not player then
		return false, "missing_params"
	end

	local userId = player.UserId

	-- Check: player isn't eliminated
	local playerData = gameManager.playerMap[userId]
	if playerData and playerData.eliminated then
		AntiCheat.logSuspicious(player, "immunity", "eliminated player tried to use immunity")
		return false, "eliminated"
	end

	-- Check: player has a token
	local immunitySystem = gameManager.immunitySystem
	if not immunitySystem then
		return false, "system_unavailable"
	end
	local tokens = immunitySystem.getTokens(userId)
	if tokens <= 0 then
		AntiCheat.logSuspicious(player, "immunity", "tried to use immunity with no tokens")
		return false, "no_tokens"
	end

	-- Check: nomination/voting phase is active
	local votingSystem = gameManager.votingSystem
	if not votingSystem then
		return false, "system_unavailable"
	end
	local phase = votingSystem.phase
	if phase ~= "nominating" and phase ~= "voting" then
		AntiCheat.logSuspicious(player, "immunity", "tried to use immunity outside nom/vote phase: " .. tostring(phase))
		return false, "wrong_phase"
	end

	-- Check: hasn't already used one this round
	if AntiCheat.immunityUsedThisRound[userId] then
		AntiCheat.logSuspicious(player, "immunity", "tried to use immunity twice in same round")
		return false, "already_used_this_round"
	end

	return true, "ok"
end

-- Record immunity use after validation passes
function AntiCheat.recordImmunityUse(userId)
	AntiCheat.immunityUsedThisRound[userId] = true
end

-- Clear immunity round tracking (call at end of round)
function AntiCheat.clearImmunityRound()
	AntiCheat.immunityUsedThisRound = {}
end

-- ============================================================
-- CHECK-IN VALIDATION
-- ============================================================

function AntiCheat.validateCheckIn(player, gameManager)
	if not player then
		return false, "missing_params"
	end

	local userId = player.UserId

	-- Check: active season exists
	if not gameManager.seasonData or not gameManager.seasonData.active then
		return false, "no_active_season"
	end

	-- Check: hasn't checked in already today
	local playerData = gameManager.playerMap[userId]
	if not playerData then
		return false, "not_in_game"
	end
	if playerData.checkedIn then
		return false, "already_checked_in"
	end

	return true, "ok"
end

-- ============================================================
-- SUSPICIOUS ACTIVITY LOGGING
-- ============================================================

function AntiCheat.logSuspicious(player, action, details)
	if not player then return end

	local userId = player.UserId

	if not AntiCheat.violations[userId] then
		AntiCheat.violations[userId] = { count = 0, actions = {} }
	end

	AntiCheat.violations[userId].count += 1
	table.insert(AntiCheat.violations[userId].actions, {
		action = action,
		details = details,
		timestamp = os.time(),
	})

	local count = AntiCheat.violations[userId].count
	warn("[AntiCheat] SUSPICIOUS:", player.Name, "— Action:", action, "— Details:", details, "— Violations:", count)

	-- Warn at threshold
	if count == WARN_THRESHOLD then
		warn("[AntiCheat] WARNING issued to", player.Name, "— ", count, "violations")
		-- Could send a client-side warning message here
	end

	-- Kick at threshold
	if count >= KICK_THRESHOLD then
		warn("[AntiCheat] KICKING", player.Name, "— ", count, "violations exceeded threshold")
		player:Kick("You have been removed for suspicious activity. If this is an error, please rejoin.")
	end
end

-- ============================================================
-- RATE LIMITER
-- ============================================================

function AntiCheat.rateLimit(player, action, cooldownSeconds)
	if not player then return false end

	local key = tostring(player.UserId) .. "_" .. action
	local now = os.clock()

	if AntiCheat.rateLimits[key] and now < AntiCheat.rateLimits[key] then
		return false -- too soon, action denied
	end

	AntiCheat.rateLimits[key] = now + cooldownSeconds
	return true -- action allowed
end

-- ============================================================
-- CLEANUP
-- ============================================================

function AntiCheat.onPlayerLeave(player)
	-- Keep violations for the session (don't clear so reconnecting doesn't reset)
	-- Clear rate limits
	local prefix = tostring(player.UserId) .. "_"
	for key in AntiCheat.rateLimits do
		if string.sub(key, 1, #prefix) == prefix then
			AntiCheat.rateLimits[key] = nil
		end
	end
end

return AntiCheat

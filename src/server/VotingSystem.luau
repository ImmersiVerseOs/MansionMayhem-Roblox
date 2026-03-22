-- ============================================================
-- VOTING SYSTEM — Nomination + voting + tallying for Mansion Mayhem
-- Handles the full nomination-to-results pipeline with dramatic flair
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SupabaseAPI = require(script.Parent.SupabaseAPI)
local Config = require(ReplicatedStorage.Shared.Config)

local VotingSystem = {}

-- State
VotingSystem.phase = "idle" -- idle | nominating | voting | tallying | results
VotingSystem.nominees = {} -- { [userId] = { name, nominatedBy = {}, nominationCount } }
VotingSystem.votes = {} -- { [voterId] = nomineeId }
VotingSystem.voteHistory = {} -- { { voterId, voterName, nomineeId, nomineeName, round } }
VotingSystem.currentRound = 0
VotingSystem.nominationTimer = nil
VotingSystem.votingTimer = nil

-- Config
local NOMINATION_DURATION = 90 -- seconds
local VOTING_DURATION = 60 -- seconds
local MIN_NOMINEES = 2
local MAX_NOMINEES = 4

-- ============================================================
-- NOMINATION PHASE
-- ============================================================

function VotingSystem.startNominationPhase(gameManager)
	if VotingSystem.phase ~= "idle" then
		warn("[VotingSystem] Cannot start nominations — phase is:", VotingSystem.phase)
		return false
	end

	VotingSystem.phase = "nominating"
	VotingSystem.nominees = {}
	VotingSystem.votes = {}
	VotingSystem.voteHistory = {}
	VotingSystem.currentRound += 1

	print("[VotingSystem] Nomination phase started — Round", VotingSystem.currentRound)

	-- Announce nomination phase
	if gameManager then
		gameManager.directorAnnounce("NOMINATION TIME. You have " .. NOMINATION_DURATION .. " seconds to nominate a housemate for elimination.")
	end

	-- Notify clients to open nomination UI
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("NominationStart")
	if remote then
		-- Send list of eligible players (active, non-immune)
		local eligible = VotingSystem._getEligiblePlayers(gameManager)
		remote:FireAllClients({
			duration = NOMINATION_DURATION,
			eligible = eligible,
		})
	end

	-- Timer for nomination phase
	VotingSystem.nominationTimer = task.delay(NOMINATION_DURATION, function()
		VotingSystem._closeNominations(gameManager)
	end)

	return true
end

function VotingSystem.handleNomination(player, nomineeUserId, gameManager)
	if VotingSystem.phase ~= "nominating" then return end
	if not player or not nomineeUserId then return end

	-- Cannot nominate yourself
	if player.UserId == nomineeUserId then return end

	-- Check nominee is a valid player in the game
	local nomineePlayer = Players:GetPlayerByUserId(nomineeUserId)
	if not nomineePlayer then return end

	-- Check if this player is immune
	if gameManager and gameManager.immunitySystem then
		if gameManager.immunitySystem.isImmune(nomineeUserId) then
			-- Notify the nominator that this player is immune
			local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("NominationResult")
			if remote then
				remote:FireClient(player, { success = false, reason = "immune" })
			end
			return
		end
	end

	-- Record nomination
	if not VotingSystem.nominees[nomineeUserId] then
		VotingSystem.nominees[nomineeUserId] = {
			name = nomineePlayer.DisplayName or nomineePlayer.Name,
			nominatedBy = {},
			nominationCount = 0,
		}
	end

	-- Prevent double-nomination by same player
	if VotingSystem.nominees[nomineeUserId].nominatedBy[player.UserId] then return end

	VotingSystem.nominees[nomineeUserId].nominatedBy[player.UserId] = true
	VotingSystem.nominees[nomineeUserId].nominationCount += 1

	print("[VotingSystem]", player.DisplayName, "nominated", VotingSystem.nominees[nomineeUserId].name)

	-- Notify the nominator of success
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("NominationResult")
	if remote then
		remote:FireClient(player, { success = true, nominee = VotingSystem.nominees[nomineeUserId].name })
	end
end

function VotingSystem._closeNominations(gameManager)
	if VotingSystem.phase ~= "nominating" then return end

	-- Sort nominees by nomination count, take top MAX_NOMINEES
	local sorted = {}
	for userId, data in VotingSystem.nominees do
		table.insert(sorted, { userId = userId, name = data.name, count = data.nominationCount })
	end
	table.sort(sorted, function(a, b) return a.count > b.count end)

	-- Ensure minimum nominees (if not enough, auto-nominate least popular / random)
	if #sorted < MIN_NOMINEES then
		local eligible = VotingSystem._getEligiblePlayers(gameManager)
		for _, p in eligible do
			if #sorted >= MIN_NOMINEES then break end
			local alreadyNominated = false
			for _, s in sorted do
				if s.userId == p.userId then
					alreadyNominated = true
					break
				end
			end
			if not alreadyNominated then
				table.insert(sorted, { userId = p.userId, name = p.name, count = 0 })
			end
		end
	end

	-- Trim to max nominees
	local finalNominees = {}
	for i = 1, math.min(#sorted, MAX_NOMINEES) do
		finalNominees[i] = sorted[i]
	end

	-- Store trimmed nominee list back
	local trimmedNominees = {}
	for _, n in finalNominees do
		trimmedNominees[n.userId] = {
			name = n.name,
			nominatedBy = VotingSystem.nominees[n.userId] and VotingSystem.nominees[n.userId].nominatedBy or {},
			nominationCount = n.count,
		}
	end
	VotingSystem.nominees = trimmedNominees

	-- Move to voting phase
	VotingSystem.startVotingPhase(finalNominees, gameManager)
end

function VotingSystem._getEligiblePlayers(gameManager)
	local eligible = {}
	for _, player in Players:GetPlayers() do
		local isImmune = false
		if gameManager and gameManager.immunitySystem then
			isImmune = gameManager.immunitySystem.isImmune(player.UserId)
		end
		-- Check player is active (not eliminated / spectator)
		local playerData = gameManager and gameManager.playerMap[player.UserId]
		local isEliminated = playerData and playerData.eliminated
		if not isImmune and not isEliminated then
			table.insert(eligible, {
				userId = player.UserId,
				name = player.DisplayName or player.Name,
			})
		end
	end
	return eligible
end

-- ============================================================
-- VOTING PHASE
-- ============================================================

function VotingSystem.startVotingPhase(nomineeList, gameManager)
	VotingSystem.phase = "voting"
	VotingSystem.votes = {}

	print("[VotingSystem] Voting phase started with", #nomineeList, "nominees")

	-- Build nominee names for announcement
	local names = {}
	for _, n in nomineeList do
		table.insert(names, n.name)
	end
	local nameStr = table.concat(names, ", ")

	-- Dramatic announcement
	if gameManager then
		gameManager.directorAnnounce("The nominees are: " .. nameStr .. ". You have " .. VOTING_DURATION .. " seconds to cast your vote.")
	end

	-- Send nominee list to all clients
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("VoteStart")
	if remote then
		remote:FireAllClients({
			nominees = nomineeList,
			duration = VOTING_DURATION,
			round = VotingSystem.currentRound,
		})
	end

	-- Timer for voting phase
	VotingSystem.votingTimer = task.delay(VOTING_DURATION, function()
		VotingSystem.tallyVotes(gameManager)
	end)
end

function VotingSystem.handleVote(player, nomineeUserId, gameManager)
	if VotingSystem.phase ~= "voting" then return end
	if not player or not nomineeUserId then return end

	-- Cannot vote for yourself
	if player.UserId == nomineeUserId then return end

	-- Must be a valid nominee
	if not VotingSystem.nominees[nomineeUserId] then return end

	-- Check if player is eliminated (spectators cannot vote)
	if gameManager then
		local playerData = gameManager.playerMap[player.UserId]
		if playerData and playerData.eliminated then return end
	end

	-- Record vote (overwrite if they change their mind)
	local previousVote = VotingSystem.votes[player.UserId]
	VotingSystem.votes[player.UserId] = nomineeUserId

	-- Track vote history
	local nomineeName = VotingSystem.nominees[nomineeUserId] and VotingSystem.nominees[nomineeUserId].name or "Unknown"
	table.insert(VotingSystem.voteHistory, {
		voterId = player.UserId,
		voterName = player.DisplayName or player.Name,
		nomineeId = nomineeUserId,
		nomineeName = nomineeName,
		round = VotingSystem.currentRound,
		changed = previousVote ~= nil,
	})

	print("[VotingSystem]", player.DisplayName, "voted for", nomineeName)

	-- Confirm vote to player
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("VoteConfirm")
	if remote then
		remote:FireClient(player, {
			success = true,
			votedFor = nomineeName,
			changed = previousVote ~= nil,
		})
	end

	-- Check if queen gets 1.5x weight
	if gameManager and gameManager.queenSystem then
		local queenId = gameManager.queenSystem.getCurrentQueenId()
		if queenId == player.UserId then
			-- Queen's vote is worth 1.5 — we handle this in tallying
			print("[VotingSystem] Queen's vote registered (1.5x weight)")
		end
	end

	-- Detect alliance betrayal
	if gameManager and gameManager.allianceSystem then
		gameManager.allianceSystem.checkBetrayalOnVote(player.UserId, nomineeUserId)
	end
end

-- ============================================================
-- TALLY + RESULTS
-- ============================================================

function VotingSystem.tallyVotes(gameManager)
	if VotingSystem.phase ~= "voting" then return end
	VotingSystem.phase = "tallying"

	print("[VotingSystem] Tallying votes...")

	-- Count votes per nominee, applying Queen's 1.5x weight
	local tally = {} -- { [nomineeId] = voteCount }
	local queenId = nil
	if gameManager and gameManager.queenSystem then
		queenId = gameManager.queenSystem.getCurrentQueenId()
	end

	for voterId, nomineeId in VotingSystem.votes do
		if not tally[nomineeId] then
			tally[nomineeId] = 0
		end
		local weight = 1
		if queenId and voterId == queenId then
			weight = 1.5
		end
		-- Apply Extra Vote game pass (2 votes instead of 1)
		local voteCount = 1
		if gameManager and gameManager.monetizationSystem then
			local voterPlayer = game:GetService("Players"):GetPlayerByUserId(voterId)
			if voterPlayer then
				voteCount = gameManager.monetizationSystem.getVoteCount(voterPlayer)
			end
		end
		tally[nomineeId] += weight * voteCount
	end

	-- Sort by vote count descending
	local results = {}
	for nomineeId, count in tally do
		local nomineeData = VotingSystem.nominees[nomineeId]
		table.insert(results, {
			userId = nomineeId,
			name = nomineeData and nomineeData.name or "Unknown",
			voteCount = count,
		})
	end
	table.sort(results, function(a, b) return a.voteCount > b.voteCount end)

	-- Include nominees with zero votes
	for nomineeId, data in VotingSystem.nominees do
		if not tally[nomineeId] then
			table.insert(results, {
				userId = nomineeId,
				name = data.name,
				voteCount = 0,
			})
		end
	end

	-- Determine eliminated player (highest votes)
	local eliminatedPlayer = results[1]

	-- Handle tie: both with same votes — Director breaks the tie (random for now)
	if #results >= 2 and results[1].voteCount == results[2].voteCount then
		-- Tiebreaker: random selection
		local tiedPlayers = {}
		local topCount = results[1].voteCount
		for _, r in results do
			if r.voteCount == topCount then
				table.insert(tiedPlayers, r)
			end
		end
		eliminatedPlayer = tiedPlayers[math.random(1, #tiedPlayers)]

		if gameManager then
			gameManager.directorAnnounce("We have a TIE! The Director will break the deadlock...")
			task.wait(3)
		end
	end

	-- Submit vote results to Supabase
	if gameManager and gameManager.seasonData then
		local seasonId = gameManager.seasonData.season and gameManager.seasonData.season.id
		if seasonId then
			SupabaseAPI.submitVote(seasonId, VotingSystem.currentRound, results, VotingSystem.votes)
		end
	end

	-- Announce results
	VotingSystem.phase = "results"
	VotingSystem.announceResults(results, eliminatedPlayer, gameManager)

	return eliminatedPlayer
end

function VotingSystem.announceResults(results, eliminatedPlayer, gameManager)
	if gameManager then
		gameManager.directorAnnounce("The votes have been tallied. Let me reveal the results...")
	end

	-- Send results to all clients with a dramatic reveal
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("VoteEnd")
	if remote then
		remote:FireAllClients({
			results = results,
			eliminated = eliminatedPlayer,
			round = VotingSystem.currentRound,
			totalVotes = 0, -- will be calculated below
		})
	end

	-- Count total votes for stats
	local totalVotes = 0
	for _ in VotingSystem.votes do
		totalVotes += 1
	end

	print("[VotingSystem] Results — Eliminated:", eliminatedPlayer and eliminatedPlayer.name or "NONE")
	for _, r in results do
		print("  ", r.name, ":", r.voteCount, "votes")
	end

	-- Reset for next round (phase stays "results" until GameManager resets)
	return eliminatedPlayer
end

-- ============================================================
-- WHO VOTED FOR WHOM (for betrayal tracking / post-vote reveals)
-- ============================================================

function VotingSystem.getVoteRecord()
	return VotingSystem.voteHistory
end

function VotingSystem.getWhoVotedFor(nomineeUserId)
	local voters = {}
	for voterId, nomineeId in VotingSystem.votes do
		if nomineeId == nomineeUserId then
			local player = Players:GetPlayerByUserId(voterId)
			table.insert(voters, {
				userId = voterId,
				name = player and (player.DisplayName or player.Name) or "Left",
			})
		end
	end
	return voters
end

-- ============================================================
-- CLEANUP
-- ============================================================

function VotingSystem.reset()
	VotingSystem.phase = "idle"
	VotingSystem.nominees = {}
	VotingSystem.votes = {}
	VotingSystem.voteHistory = {}

	if VotingSystem.nominationTimer then
		task.cancel(VotingSystem.nominationTimer)
		VotingSystem.nominationTimer = nil
	end
	if VotingSystem.votingTimer then
		task.cancel(VotingSystem.votingTimer)
		VotingSystem.votingTimer = nil
	end

	print("[VotingSystem] Reset complete")
end

-- Handle player leaving during vote
function VotingSystem.onPlayerLeave(player)
	if VotingSystem.phase == "idle" then return end

	-- Remove their vote
	VotingSystem.votes[player.UserId] = nil

	-- Remove from nominees if nominated
	VotingSystem.nominees[player.UserId] = nil

	print("[VotingSystem] Player left during vote:", player.Name)
end

return VotingSystem

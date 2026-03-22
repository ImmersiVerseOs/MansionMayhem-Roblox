-- ============================================================
-- ALLIANCE SYSTEM — Player alliances, betrayal detection, rooms
-- Players can form alliances (2-4 players), track loyalty/betrayal
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SupabaseAPI = require(script.Parent.SupabaseAPI)
local Config = require(ReplicatedStorage.Shared.Config)

local AllianceSystem = {}

-- State
AllianceSystem.alliances = {} -- { [allianceId] = { id, name, members = {userId=true}, leader, createdAt } }
AllianceSystem.playerAlliance = {} -- { [userId] = allianceId }
AllianceSystem.pendingInvites = {} -- { [targetUserId] = { allianceId, fromUserId, fromName, timestamp } }
AllianceSystem.allianceIdCounter = 0
AllianceSystem.betrayals = {} -- { [userId] = { count, events = {} } }
AllianceSystem.playerStats = {} -- { [userId] = { alliance_count, betrayal_count } }

-- Config
local MIN_ALLIANCE_SIZE = 2
local MAX_ALLIANCE_SIZE = 4
local INVITE_TIMEOUT = 60 -- seconds
local MAX_ALLIANCES_PER_PLAYER = 1 -- one alliance at a time

-- Alliance name generator
local ALLIANCE_PREFIXES = { "The", "Team", "House", "Squad", "Circle", "Alliance" }
local ALLIANCE_SUFFIXES = {
	"Crown", "Shadows", "Serpents", "Flames", "Frost",
	"Thorns", "Vipers", "Storm", "Eclipse", "Phoenix",
	"Chaos", "Unity", "Power", "Reign", "Dynasty",
}

-- ============================================================
-- ALLIANCE CREATION
-- ============================================================

function AllianceSystem.proposeAlliance(proposerPlayer, targetUserId, gameManager)
	if not proposerPlayer then return { success = false, reason = "invalid_player" } end

	local proposerId = proposerPlayer.UserId

	-- Check proposer isn't eliminated
	if gameManager then
		local data = gameManager.playerMap[proposerId]
		if data and data.eliminated then
			return { success = false, reason = "eliminated" }
		end
	end

	-- Check if proposer already in an alliance
	if AllianceSystem.playerAlliance[proposerId] then
		local existingAlliance = AllianceSystem.alliances[AllianceSystem.playerAlliance[proposerId]]
		if existingAlliance then
			-- Check if alliance is full
			local memberCount = 0
			for _ in existingAlliance.members do memberCount += 1 end
			if memberCount >= MAX_ALLIANCE_SIZE then
				return { success = false, reason = "alliance_full" }
			end
		end
	end

	-- Check target player exists and is active
	local targetPlayer = Players:GetPlayerByUserId(targetUserId)
	if not targetPlayer then
		return { success = false, reason = "player_not_found" }
	end

	-- Check target isn't already in proposer's alliance
	if AllianceSystem.playerAlliance[proposerId] and AllianceSystem.playerAlliance[targetUserId] then
		if AllianceSystem.playerAlliance[proposerId] == AllianceSystem.playerAlliance[targetUserId] then
			return { success = false, reason = "already_allied" }
		end
	end

	-- Check for pending invite
	if AllianceSystem.pendingInvites[targetUserId] and AllianceSystem.pendingInvites[targetUserId].fromUserId == proposerId then
		return { success = false, reason = "invite_pending" }
	end

	-- If proposer has no alliance, create a new one
	local allianceId = AllianceSystem.playerAlliance[proposerId]
	if not allianceId then
		allianceId = AllianceSystem._createAlliance(proposerId, proposerPlayer.DisplayName or proposerPlayer.Name)
	end

	-- Send invite
	AllianceSystem.pendingInvites[targetUserId] = {
		allianceId = allianceId,
		fromUserId = proposerId,
		fromName = proposerPlayer.DisplayName or proposerPlayer.Name,
		timestamp = os.clock(),
	}

	-- Notify target
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("AllianceInvite")
	if remote then
		local alliance = AllianceSystem.alliances[allianceId]
		remote:FireClient(targetPlayer, {
			allianceId = allianceId,
			allianceName = alliance and alliance.name or "Unknown Alliance",
			fromUserId = proposerId,
			fromName = proposerPlayer.DisplayName or proposerPlayer.Name,
			timeout = INVITE_TIMEOUT,
		})
	end

	-- Auto-expire invite
	task.delay(INVITE_TIMEOUT, function()
		if AllianceSystem.pendingInvites[targetUserId] and AllianceSystem.pendingInvites[targetUserId].allianceId == allianceId then
			AllianceSystem.pendingInvites[targetUserId] = nil
		end
	end)

	print("[AllianceSystem]", proposerPlayer.DisplayName, "invited", targetPlayer.DisplayName, "to alliance")

	return {
		success = true,
		allianceId = allianceId,
		allianceName = AllianceSystem.alliances[allianceId] and AllianceSystem.alliances[allianceId].name or "Alliance",
	}
end

function AllianceSystem._createAlliance(leaderUserId, leaderName)
	AllianceSystem.allianceIdCounter += 1
	local allianceId = "alliance_" .. AllianceSystem.allianceIdCounter

	local name = ALLIANCE_PREFIXES[math.random(1, #ALLIANCE_PREFIXES)] .. " " ..
		ALLIANCE_SUFFIXES[math.random(1, #ALLIANCE_SUFFIXES)]

	AllianceSystem.alliances[allianceId] = {
		id = allianceId,
		name = name,
		members = { [leaderUserId] = true },
		leader = leaderUserId,
		leaderName = leaderName,
		createdAt = os.time(),
	}

	AllianceSystem.playerAlliance[leaderUserId] = allianceId

	-- Track stats
	if not AllianceSystem.playerStats[leaderUserId] then
		AllianceSystem.playerStats[leaderUserId] = { alliance_count = 0, betrayal_count = 0 }
	end
	AllianceSystem.playerStats[leaderUserId].alliance_count += 1

	print("[AllianceSystem] Alliance created:", name, "— Leader:", leaderName)

	return allianceId
end

-- ============================================================
-- ACCEPT / DECLINE INVITES
-- ============================================================

function AllianceSystem.acceptInvite(player, gameManager)
	if not player then return { success = false, reason = "invalid_player" } end

	local invite = AllianceSystem.pendingInvites[player.UserId]
	if not invite then
		return { success = false, reason = "no_invite" }
	end

	-- Check invite hasn't expired
	if os.clock() - invite.timestamp > INVITE_TIMEOUT then
		AllianceSystem.pendingInvites[player.UserId] = nil
		return { success = false, reason = "invite_expired" }
	end

	local alliance = AllianceSystem.alliances[invite.allianceId]
	if not alliance then
		AllianceSystem.pendingInvites[player.UserId] = nil
		return { success = false, reason = "alliance_not_found" }
	end

	-- Check alliance size
	local memberCount = 0
	for _ in alliance.members do memberCount += 1 end
	if memberCount >= MAX_ALLIANCE_SIZE then
		AllianceSystem.pendingInvites[player.UserId] = nil
		return { success = false, reason = "alliance_full" }
	end

	-- Leave current alliance if in one
	if AllianceSystem.playerAlliance[player.UserId] then
		AllianceSystem.leaveAlliance(player, gameManager)
	end

	-- Add to alliance
	alliance.members[player.UserId] = true
	AllianceSystem.playerAlliance[player.UserId] = invite.allianceId

	-- Track stats
	if not AllianceSystem.playerStats[player.UserId] then
		AllianceSystem.playerStats[player.UserId] = { alliance_count = 0, betrayal_count = 0 }
	end
	AllianceSystem.playerStats[player.UserId].alliance_count += 1

	-- Clear invite
	AllianceSystem.pendingInvites[player.UserId] = nil

	print("[AllianceSystem]", player.DisplayName, "joined alliance:", alliance.name)

	-- Notify all alliance members
	AllianceSystem._notifyAllianceMembers(invite.allianceId, {
		type = "member_joined",
		name = player.DisplayName or player.Name,
		allianceName = alliance.name,
	})

	-- Director announcement if alliance reaches max size
	if memberCount + 1 >= MAX_ALLIANCE_SIZE and gameManager then
		gameManager.directorAnnounce("A POWER ALLIANCE has formed: " .. alliance.name .. " is now at full strength!")
	end

	-- Sync to Supabase
	if gameManager and gameManager.seasonData then
		local seasonId = gameManager.seasonData.season and gameManager.seasonData.season.id
		if seasonId then
			task.spawn(function()
				SupabaseAPI.createAlliance(seasonId, invite.allianceId, alliance.name, alliance.members)
			end)
		end
	end

	return {
		success = true,
		allianceId = invite.allianceId,
		allianceName = alliance.name,
	}
end

function AllianceSystem.declineInvite(player, gameManager)
	if not player then return end

	local invite = AllianceSystem.pendingInvites[player.UserId]
	if not invite then return end

	AllianceSystem.pendingInvites[player.UserId] = nil

	-- Notify the inviter
	local inviter = Players:GetPlayerByUserId(invite.fromUserId)
	if inviter then
		local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("AllianceUpdate")
		if remote then
			remote:FireClient(inviter, {
				type = "invite_declined",
				name = player.DisplayName or player.Name,
			})
		end
	end

	print("[AllianceSystem]", player.DisplayName, "declined alliance invite from", invite.fromName)
end

-- ============================================================
-- LEAVE ALLIANCE
-- ============================================================

function AllianceSystem.leaveAlliance(player, gameManager)
	if not player then return end

	local allianceId = AllianceSystem.playerAlliance[player.UserId]
	if not allianceId then return end

	local alliance = AllianceSystem.alliances[allianceId]
	if not alliance then
		AllianceSystem.playerAlliance[player.UserId] = nil
		return
	end

	-- Remove from alliance
	alliance.members[player.UserId] = nil
	AllianceSystem.playerAlliance[player.UserId] = nil

	print("[AllianceSystem]", player.DisplayName, "left alliance:", alliance.name)

	-- Notify remaining members
	AllianceSystem._notifyAllianceMembers(allianceId, {
		type = "member_left",
		name = player.DisplayName or player.Name,
		allianceName = alliance.name,
	})

	-- Check if alliance is empty (dissolve)
	local memberCount = 0
	for _ in alliance.members do memberCount += 1 end
	if memberCount == 0 then
		AllianceSystem.alliances[allianceId] = nil
		print("[AllianceSystem] Alliance dissolved:", alliance.name)
	elseif alliance.leader == player.UserId then
		-- Transfer leadership
		for memberId in alliance.members do
			alliance.leader = memberId
			local memberPlayer = Players:GetPlayerByUserId(memberId)
			alliance.leaderName = memberPlayer and (memberPlayer.DisplayName or memberPlayer.Name) or "Unknown"
			break
		end
	end
end

-- ============================================================
-- BETRAYAL DETECTION
-- ============================================================

function AllianceSystem.checkBetrayalOnVote(voterUserId, votedForUserId)
	-- Check if voter and target are in the same alliance
	local voterAlliance = AllianceSystem.playerAlliance[voterUserId]
	local targetAlliance = AllianceSystem.playerAlliance[votedForUserId]

	if voterAlliance and targetAlliance and voterAlliance == targetAlliance then
		-- BETRAYAL DETECTED
		if not AllianceSystem.betrayals[voterUserId] then
			AllianceSystem.betrayals[voterUserId] = { count = 0, events = {} }
		end

		AllianceSystem.betrayals[voterUserId].count += 1
		table.insert(AllianceSystem.betrayals[voterUserId].events, {
			targetId = votedForUserId,
			allianceId = voterAlliance,
			timestamp = os.time(),
		})

		-- Track stats
		if not AllianceSystem.playerStats[voterUserId] then
			AllianceSystem.playerStats[voterUserId] = { alliance_count = 0, betrayal_count = 0 }
		end
		AllianceSystem.playerStats[voterUserId].betrayal_count += 1

		local voterPlayer = Players:GetPlayerByUserId(voterUserId)
		local targetPlayer = Players:GetPlayerByUserId(votedForUserId)
		local voterName = voterPlayer and (voterPlayer.DisplayName or voterPlayer.Name) or "Unknown"
		local targetName = targetPlayer and (targetPlayer.DisplayName or targetPlayer.Name) or "Unknown"

		print("[AllianceSystem] BETRAYAL:", voterName, "voted against ally", targetName)

		-- Notify alliance members of betrayal (post-vote reveal)
		local alliance = AllianceSystem.alliances[voterAlliance]
		if alliance then
			AllianceSystem._notifyAllianceMembers(voterAlliance, {
				type = "betrayal",
				betrayerName = voterName,
				betrayerId = voterUserId,
				targetName = targetName,
				targetId = votedForUserId,
				allianceName = alliance.name,
			})
		end

		return true
	end

	return false
end

-- ============================================================
-- QUERIES
-- ============================================================

function AllianceSystem.areAllied(userId1, userId2)
	local a1 = AllianceSystem.playerAlliance[userId1]
	local a2 = AllianceSystem.playerAlliance[userId2]
	return a1 and a2 and a1 == a2
end

function AllianceSystem.getAlliance(userId)
	local allianceId = AllianceSystem.playerAlliance[userId]
	if not allianceId then return nil end
	return AllianceSystem.alliances[allianceId]
end

function AllianceSystem.getAllianceMembers(allianceId)
	local alliance = AllianceSystem.alliances[allianceId]
	if not alliance then return {} end

	local members = {}
	for memberId in alliance.members do
		local player = Players:GetPlayerByUserId(memberId)
		table.insert(members, {
			userId = memberId,
			name = player and (player.DisplayName or player.Name) or "Unknown",
			isLeader = memberId == alliance.leader,
		})
	end
	return members
end

function AllianceSystem.getAllAlliances()
	local list = {}
	for allianceId, alliance in AllianceSystem.alliances do
		local memberCount = 0
		for _ in alliance.members do memberCount += 1 end
		table.insert(list, {
			id = allianceId,
			name = alliance.name,
			leaderName = alliance.leaderName,
			memberCount = memberCount,
			members = AllianceSystem.getAllianceMembers(allianceId),
		})
	end
	return list
end

function AllianceSystem.getPlayerStats(userId)
	return AllianceSystem.playerStats[userId] or { alliance_count = 0, betrayal_count = 0 }
end

-- ============================================================
-- NOTIFICATIONS
-- ============================================================

function AllianceSystem._notifyAllianceMembers(allianceId, data)
	local alliance = AllianceSystem.alliances[allianceId]
	if not alliance then return end

	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("AllianceUpdate")
	if not remote then return end

	for memberId in alliance.members do
		local player = Players:GetPlayerByUserId(memberId)
		if player then
			remote:FireClient(player, data)
		end
	end
end

-- ============================================================
-- CLEANUP
-- ============================================================

function AllianceSystem.onPlayerLeave(player)
	-- Remove from alliance
	AllianceSystem.leaveAlliance(player, nil)
	-- Clear pending invites
	AllianceSystem.pendingInvites[player.UserId] = nil
end

return AllianceSystem

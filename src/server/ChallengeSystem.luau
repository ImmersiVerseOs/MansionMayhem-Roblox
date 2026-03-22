-- ============================================================
-- CHALLENGE SYSTEM — Daily individual + group challenges
-- Social, physical, mental challenge types with XP/coin rewards
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SupabaseAPI = require(script.Parent.SupabaseAPI)
local Config = require(ReplicatedStorage.Shared.Config)

local ChallengeSystem = {}

-- State
ChallengeSystem.activeChallenges = {} -- { [challengeId] = challengeData }
ChallengeSystem.playerChallenges = {} -- { [userId] = { [challengeId] = { accepted, progress, completed } } }
ChallengeSystem.groupGoals = {} -- { [goalId] = goalData }
ChallengeSystem.challengeIdCounter = 0

-- ============================================================
-- CHALLENGE TEMPLATES
-- ============================================================

local INDIVIDUAL_CHALLENGES = {
	-- Social challenges
	{
		type = "social",
		title = "Social Butterfly",
		description = "Have a conversation within 10 studs of 5 different players.",
		goal = 5,
		xpReward = 30,
		coinReward = 15,
		duration = 600, -- 10 minutes
		icon = "chat",
	},
	{
		type = "social",
		title = "Alliance Broker",
		description = "Propose an alliance to another player.",
		goal = 1,
		xpReward = 20,
		coinReward = 10,
		duration = 300,
		icon = "handshake",
	},
	{
		type = "social",
		title = "Confession King",
		description = "Post 3 confessions to the Tea Wall.",
		goal = 3,
		xpReward = 25,
		coinReward = 12,
		duration = 900,
		icon = "confession",
	},
	{
		type = "social",
		title = "Room Tour",
		description = "Visit all 10 bedrooms on the upper floor.",
		goal = 10,
		xpReward = 35,
		coinReward = 20,
		duration = 600,
		icon = "explore",
	},

	-- Physical challenges
	{
		type = "physical",
		title = "Speed Demon",
		description = "Complete a lap from the Lobby to the Rooftop and back in under 60 seconds.",
		goal = 1,
		xpReward = 40,
		coinReward = 25,
		duration = 120,
		icon = "run",
	},
	{
		type = "physical",
		title = "Pool Party",
		description = "Stay in the rooftop pool area for 2 consecutive minutes.",
		goal = 1,
		xpReward = 15,
		coinReward = 8,
		duration = 300,
		icon = "pool",
	},
	{
		type = "physical",
		title = "Elevator Challenge",
		description = "Ride the elevator 3 times.",
		goal = 3,
		xpReward = 20,
		coinReward = 10,
		duration = 600,
		icon = "elevator",
	},
	{
		type = "physical",
		title = "Mansion Marathon",
		description = "Walk through every room in the mansion.",
		goal = 8,
		xpReward = 50,
		coinReward = 30,
		duration = 900,
		icon = "marathon",
	},

	-- Mental challenges
	{
		type = "mental",
		title = "Memory Master",
		description = "Name all 10 bedrooms correctly. (Visit each one.)",
		goal = 10,
		xpReward = 45,
		coinReward = 25,
		duration = 600,
		icon = "brain",
	},
	{
		type = "mental",
		title = "Drama Detective",
		description = "Witness 2 fights or confrontations.",
		goal = 2,
		xpReward = 30,
		coinReward = 15,
		duration = 1800,
		icon = "detective",
	},
	{
		type = "mental",
		title = "Tea Reader",
		description = "Read 10 confessions on the Tea Wall.",
		goal = 10,
		xpReward = 20,
		coinReward = 10,
		duration = 300,
		icon = "tea",
	},
	{
		type = "mental",
		title = "Power Player",
		description = "Earn 50 XP through any combination of activities.",
		goal = 50,
		xpReward = 35,
		coinReward = 20,
		duration = 1800,
		icon = "xp",
	},
}

local GROUP_GOALS = {
	{
		title = "House Harmony",
		description = "All active players check in today.",
		condition = "all_checkin",
		xpReward = 50,
		coinReward = 30,
		penalty = 0,
	},
	{
		title = "Drama Free Day",
		description = "No fights for the entire day.",
		condition = "no_fights",
		xpReward = 40,
		coinReward = 20,
		penalty = -10, -- everyone loses XP if failed
	},
	{
		title = "Social Hour",
		description = "Every player must visit the Living Room at least once.",
		condition = "all_visit_living",
		xpReward = 30,
		coinReward = 15,
		penalty = 0,
	},
	{
		title = "Alliance Day",
		description = "At least 3 alliances must be formed today.",
		condition = "three_alliances",
		xpReward = 35,
		coinReward = 20,
		penalty = -5,
	},
	{
		title = "Confession Chain",
		description = "At least 10 confessions posted to the Tea Wall today.",
		condition = "ten_confessions",
		xpReward = 25,
		coinReward = 15,
		penalty = 0,
	},
}

-- ============================================================
-- DAILY CHALLENGE GENERATION
-- ============================================================

function ChallengeSystem.generateDailyChallenges(gameManager)
	-- Clear yesterday's challenges
	ChallengeSystem.activeChallenges = {}
	ChallengeSystem.playerChallenges = {}

	-- Pick 3 individual challenges (one of each type)
	local socialChallenges = {}
	local physicalChallenges = {}
	local mentalChallenges = {}

	for _, c in INDIVIDUAL_CHALLENGES do
		if c.type == "social" then table.insert(socialChallenges, c) end
		if c.type == "physical" then table.insert(physicalChallenges, c) end
		if c.type == "mental" then table.insert(mentalChallenges, c) end
	end

	local dailyChallenges = {}

	if #socialChallenges > 0 then
		table.insert(dailyChallenges, socialChallenges[math.random(1, #socialChallenges)])
	end
	if #physicalChallenges > 0 then
		table.insert(dailyChallenges, physicalChallenges[math.random(1, #physicalChallenges)])
	end
	if #mentalChallenges > 0 then
		table.insert(dailyChallenges, mentalChallenges[math.random(1, #mentalChallenges)])
	end

	-- Register them
	for _, template in dailyChallenges do
		ChallengeSystem.challengeIdCounter += 1
		local challengeId = "challenge_" .. ChallengeSystem.challengeIdCounter

		ChallengeSystem.activeChallenges[challengeId] = {
			id = challengeId,
			type = template.type,
			title = template.title,
			description = template.description,
			goal = template.goal,
			xpReward = template.xpReward,
			coinReward = template.coinReward,
			duration = template.duration,
			icon = template.icon,
			createdAt = os.time(),
		}
	end

	-- Pick 1 group goal
	local groupGoal = GROUP_GOALS[math.random(1, #GROUP_GOALS)]
	ChallengeSystem.challengeIdCounter += 1
	local goalId = "goal_" .. ChallengeSystem.challengeIdCounter
	ChallengeSystem.groupGoals[goalId] = {
		id = goalId,
		title = groupGoal.title,
		description = groupGoal.description,
		condition = groupGoal.condition,
		xpReward = groupGoal.xpReward,
		coinReward = groupGoal.coinReward,
		penalty = groupGoal.penalty,
		completed = false,
		failed = false,
		trackedData = {},
	}

	print("[ChallengeSystem] Generated", #dailyChallenges, "challenges + 1 group goal")

	-- Announce
	if gameManager then
		gameManager.directorAnnounce("Today's CHALLENGES are ready! Open the Challenge tab to see what the Mansion has in store.")
	end

	-- Broadcast to all clients
	ChallengeSystem._broadcastChallengeList()

	return dailyChallenges
end

function ChallengeSystem._broadcastChallengeList()
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("ChallengeList")
	if not remote then return end

	local challenges = {}
	for id, c in ChallengeSystem.activeChallenges do
		table.insert(challenges, {
			id = id,
			type = c.type,
			title = c.title,
			description = c.description,
			goal = c.goal,
			xpReward = c.xpReward,
			coinReward = c.coinReward,
			duration = c.duration,
			icon = c.icon,
		})
	end

	local goals = {}
	for id, g in ChallengeSystem.groupGoals do
		if not g.completed and not g.failed then
			table.insert(goals, {
				id = id,
				title = g.title,
				description = g.description,
				xpReward = g.xpReward,
				coinReward = g.coinReward,
				penalty = g.penalty,
			})
		end
	end

	remote:FireAllClients({
		challenges = challenges,
		groupGoals = goals,
	})
end

-- ============================================================
-- ACCEPT CHALLENGE
-- ============================================================

function ChallengeSystem.acceptChallenge(player, challengeId)
	if not player or not challengeId then return { success = false, reason = "invalid_params" } end

	local challenge = ChallengeSystem.activeChallenges[challengeId]
	if not challenge then
		return { success = false, reason = "challenge_not_found" }
	end

	-- Initialize player challenge tracking
	if not ChallengeSystem.playerChallenges[player.UserId] then
		ChallengeSystem.playerChallenges[player.UserId] = {}
	end

	-- Check if already accepted
	if ChallengeSystem.playerChallenges[player.UserId][challengeId] then
		return { success = false, reason = "already_accepted" }
	end

	ChallengeSystem.playerChallenges[player.UserId][challengeId] = {
		accepted = true,
		progress = 0,
		completed = false,
		acceptedAt = os.clock(),
	}

	print("[ChallengeSystem]", player.DisplayName, "accepted challenge:", challenge.title)

	-- Start duration timer
	task.delay(challenge.duration, function()
		local pc = ChallengeSystem.playerChallenges[player.UserId]
		if pc and pc[challengeId] and not pc[challengeId].completed then
			-- Challenge expired
			pc[challengeId].expired = true
			local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("ChallengeUpdate")
			if remote then
				remote:FireClient(player, {
					type = "expired",
					challengeId = challengeId,
					title = challenge.title,
				})
			end
		end
	end)

	-- Confirm to client
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("ChallengeUpdate")
	if remote then
		remote:FireClient(player, {
			type = "accepted",
			challengeId = challengeId,
			title = challenge.title,
			goal = challenge.goal,
			duration = challenge.duration,
		})
	end

	return { success = true }
end

-- ============================================================
-- UPDATE CHALLENGE PROGRESS
-- ============================================================

function ChallengeSystem.updateProgress(player, challengeId, incrementBy, gameManager)
	if not player or not challengeId then return end

	local pc = ChallengeSystem.playerChallenges[player.UserId]
	if not pc or not pc[challengeId] then return end
	if pc[challengeId].completed or pc[challengeId].expired then return end

	local challenge = ChallengeSystem.activeChallenges[challengeId]
	if not challenge then return end

	pc[challengeId].progress += (incrementBy or 1)

	-- Notify client of progress
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("ChallengeUpdate")
	if remote then
		remote:FireClient(player, {
			type = "progress",
			challengeId = challengeId,
			progress = pc[challengeId].progress,
			goal = challenge.goal,
		})
	end

	-- Check completion
	if pc[challengeId].progress >= challenge.goal then
		ChallengeSystem.completeChallenge(player, challengeId, gameManager)
	end
end

-- ============================================================
-- COMPLETE CHALLENGE
-- ============================================================

function ChallengeSystem.completeChallenge(player, challengeId, gameManager)
	if not player or not challengeId then return end

	local pc = ChallengeSystem.playerChallenges[player.UserId]
	if not pc or not pc[challengeId] then return end
	if pc[challengeId].completed then return end

	local challenge = ChallengeSystem.activeChallenges[challengeId]
	if not challenge then return end

	pc[challengeId].completed = true

	print("[ChallengeSystem]", player.DisplayName, "completed challenge:", challenge.title)

	-- Award XP and coins
	if gameManager then
		local playerData = gameManager.playerMap[player.UserId]
		if playerData then
			playerData.xp = (playerData.xp or 0) + challenge.xpReward
			playerData.coins = (playerData.coins or 0) + challenge.coinReward
		end
	end

	-- Notify client
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("ChallengeUpdate")
	if remote then
		remote:FireClient(player, {
			type = "completed",
			challengeId = challengeId,
			title = challenge.title,
			xpReward = challenge.xpReward,
			coinReward = challenge.coinReward,
		})
	end

	-- Director commentary on notable completions
	if gameManager and challenge.xpReward >= 40 then
		gameManager.directorAnnounce(player.DisplayName .. " just CRUSHED the " .. challenge.title .. " challenge! +" .. challenge.xpReward .. " XP")
	end

	-- Sync to Supabase
	if gameManager and gameManager.seasonData then
		local seasonId = gameManager.seasonData.season and gameManager.seasonData.season.id
		if seasonId then
			task.spawn(function()
				SupabaseAPI.completeChallenge(seasonId, tostring(player.UserId), challengeId, challenge.xpReward)
			end)
		end
	end
end

-- ============================================================
-- GROUP GOAL TRACKING
-- ============================================================

function ChallengeSystem.trackGroupGoal(eventType, data, gameManager)
	for goalId, goal in ChallengeSystem.groupGoals do
		if goal.completed or goal.failed then continue end

		if goal.condition == "all_checkin" and eventType == "checkin" then
			goal.trackedData[data.userId] = true
			-- Check if all active players checked in
			local allCheckedIn = true
			for _, player in Players:GetPlayers() do
				if not goal.trackedData[player.UserId] then
					allCheckedIn = false
					break
				end
			end
			if allCheckedIn and #Players:GetPlayers() > 0 then
				ChallengeSystem._completeGroupGoal(goalId, gameManager)
			end

		elseif goal.condition == "no_fights" and eventType == "fight" then
			-- Fight happened = goal failed
			ChallengeSystem._failGroupGoal(goalId, gameManager)

		elseif goal.condition == "all_visit_living" and eventType == "visit_living" then
			goal.trackedData[data.userId] = true
			local allVisited = true
			for _, player in Players:GetPlayers() do
				if not goal.trackedData[player.UserId] then
					allVisited = false
					break
				end
			end
			if allVisited and #Players:GetPlayers() > 0 then
				ChallengeSystem._completeGroupGoal(goalId, gameManager)
			end

		elseif goal.condition == "three_alliances" and eventType == "alliance_formed" then
			goal.trackedData.count = (goal.trackedData.count or 0) + 1
			if goal.trackedData.count >= 3 then
				ChallengeSystem._completeGroupGoal(goalId, gameManager)
			end

		elseif goal.condition == "ten_confessions" and eventType == "confession" then
			goal.trackedData.count = (goal.trackedData.count or 0) + 1
			if goal.trackedData.count >= 10 then
				ChallengeSystem._completeGroupGoal(goalId, gameManager)
			end
		end
	end
end

function ChallengeSystem._completeGroupGoal(goalId, gameManager)
	local goal = ChallengeSystem.groupGoals[goalId]
	if not goal then return end

	goal.completed = true
	print("[ChallengeSystem] GROUP GOAL COMPLETED:", goal.title)

	-- Reward all active players
	for _, player in Players:GetPlayers() do
		if gameManager then
			local playerData = gameManager.playerMap[player.UserId]
			if playerData and not playerData.eliminated then
				playerData.xp = (playerData.xp or 0) + goal.xpReward
				playerData.coins = (playerData.coins or 0) + goal.coinReward
			end
		end
	end

	-- Announce
	if gameManager then
		gameManager.directorAnnounce(
			"HOUSE GOAL ACHIEVED: " .. goal.title .. "! Everyone earns +" ..
			goal.xpReward .. " XP and +" .. goal.coinReward .. " coins!"
		)
	end

	-- Notify clients
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("GroupGoalUpdate")
	if remote then
		remote:FireAllClients({
			type = "completed",
			goalId = goalId,
			title = goal.title,
			xpReward = goal.xpReward,
			coinReward = goal.coinReward,
		})
	end
end

function ChallengeSystem._failGroupGoal(goalId, gameManager)
	local goal = ChallengeSystem.groupGoals[goalId]
	if not goal then return end

	goal.failed = true
	print("[ChallengeSystem] GROUP GOAL FAILED:", goal.title)

	-- Apply penalty if any
	if goal.penalty ~= 0 then
		for _, player in Players:GetPlayers() do
			if gameManager then
				local playerData = gameManager.playerMap[player.UserId]
				if playerData and not playerData.eliminated then
					playerData.xp = math.max(0, (playerData.xp or 0) + goal.penalty)
				end
			end
		end
	end

	-- Announce failure
	if gameManager then
		local penaltyMsg = ""
		if goal.penalty ~= 0 then
			penaltyMsg = " Everyone loses " .. math.abs(goal.penalty) .. " XP."
		end
		gameManager.directorAnnounce(
			"HOUSE GOAL FAILED: " .. goal.title .. "." .. penaltyMsg .. " Do better tomorrow."
		)
	end

	-- Notify clients
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("GroupGoalUpdate")
	if remote then
		remote:FireAllClients({
			type = "failed",
			goalId = goalId,
			title = goal.title,
			penalty = goal.penalty,
		})
	end
end

-- ============================================================
-- QUERIES
-- ============================================================

function ChallengeSystem.getPlayerProgress(userId)
	local challenges = {}
	local pc = ChallengeSystem.playerChallenges[userId]
	if not pc then return challenges end

	for challengeId, status in pc do
		local challenge = ChallengeSystem.activeChallenges[challengeId]
		if challenge then
			table.insert(challenges, {
				id = challengeId,
				title = challenge.title,
				type = challenge.type,
				progress = status.progress,
				goal = challenge.goal,
				completed = status.completed,
				expired = status.expired or false,
			})
		end
	end
	return challenges
end

function ChallengeSystem.getActiveChallenges()
	local list = {}
	for id, c in ChallengeSystem.activeChallenges do
		table.insert(list, {
			id = id,
			type = c.type,
			title = c.title,
			description = c.description,
			goal = c.goal,
			xpReward = c.xpReward,
			coinReward = c.coinReward,
			duration = c.duration,
		})
	end
	return list
end

function ChallengeSystem.onPlayerLeave(player)
	ChallengeSystem.playerChallenges[player.UserId] = nil
end

return ChallengeSystem

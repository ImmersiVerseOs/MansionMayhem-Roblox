-- ============================================================
-- BADGE SYSTEM — Roblox badges for milestones in Mansion Mayhem
-- Uses placeholder IDs (0) — replace with real Badge IDs from Creator Hub
-- ============================================================

local BadgeService = game:GetService("BadgeService")

local BadgeSystem = {}

-- Badge definitions: name -> { id, description }
-- Replace the 0 IDs with real badge IDs from Roblox Creator Hub
local BADGES = {
	["Welcome to the Mansion"] = {
		id = 0,
		description = "First time joining the Mansion of Mayhem",
	},
	["First Check-In"] = {
		id = 0,
		description = "Complete your first daily check-in",
	},
	["Tea Spiller"] = {
		id = 0,
		description = "Post your first confession on the Tea Wall",
	},
	["Survivor"] = {
		id = 0,
		description = "Survive your first elimination round",
	},
	["Queen of the Week"] = {
		id = 0,
		description = "Become Queen for the first time",
	},
	["Alliance Maker"] = {
		id = 0,
		description = "Form your first alliance",
	},
	["Backstabber"] = {
		id = 0,
		description = "Betray an alliance member",
	},
	["Fight Club"] = {
		id = 0,
		description = "Win your first fight",
	},
	["Immunity Shield"] = {
		id = 0,
		description = "Use your first immunity token",
	},
	["Challenge Champion"] = {
		id = 0,
		description = "Complete 10 challenges",
	},
	["Drama Queen"] = {
		id = 0,
		description = "Start 10 fights",
	},
	["Mansion Veteran"] = {
		id = 0,
		description = "Play 50 games",
	},
}

-- ============================================================
-- INITIALIZATION
-- ============================================================

function BadgeSystem.init()
	print("[BadgeSystem] Initialized with", 0, "badges configured")

	-- Count configured badges (those with non-zero IDs)
	local configured = 0
	for _, badge in BADGES do
		if badge.id ~= 0 then
			configured += 1
		end
	end

	if configured == 0 then
		print("[BadgeSystem] WARNING: All badge IDs are 0 (placeholder). Create badges on Creator Hub and update IDs.")
	else
		print("[BadgeSystem]", configured, "of", 12, "badges have real IDs configured")
	end
end

-- ============================================================
-- AWARD BADGE — Safely awards a badge to a player
-- ============================================================

function BadgeSystem.awardBadge(player, badgeName: string): boolean
	local badge = BADGES[badgeName]
	if not badge then
		warn("[BadgeSystem] Unknown badge name:", badgeName)
		return false
	end

	-- Skip if placeholder ID
	if badge.id == 0 then
		print("[BadgeSystem] Would award '" .. badgeName .. "' to " .. player.Name .. " (placeholder ID, skipping)")
		return false
	end

	-- Check if player already has the badge
	local alreadyHas = BadgeSystem.hasBadge(player, badgeName)
	if alreadyHas then
		return false -- Already has it, no need to award again
	end

	-- Award the badge with pcall for safety
	local success, err = pcall(function()
		BadgeService:AwardBadge(player.UserId, badge.id)
	end)

	if success then
		print("[BadgeSystem] Awarded '" .. badgeName .. "' to " .. player.Name)
		return true
	else
		warn("[BadgeSystem] Failed to award '" .. badgeName .. "' to " .. player.Name .. ":", err)
		return false
	end
end

-- ============================================================
-- HAS BADGE — Checks if a player already has a badge
-- ============================================================

function BadgeSystem.hasBadge(player, badgeName: string): boolean
	local badge = BADGES[badgeName]
	if not badge then return false end
	if badge.id == 0 then return false end

	local success, hasBadge = pcall(function()
		return BadgeService:UserHasBadgeAsync(player.UserId, badge.id)
	end)

	if success then
		return hasBadge
	else
		warn("[BadgeSystem] Failed to check badge '" .. badgeName .. "' for " .. player.Name)
		return false
	end
end

-- ============================================================
-- CHECK MILESTONES — Checks all milestone conditions and awards earned badges
-- ============================================================

function BadgeSystem.checkMilestones(player, gameManager)
	if not player or not gameManager then return end

	local playerData = gameManager.playerMap[player.UserId]
	if not playerData then return end

	-- "Challenge Champion" — completed 10 challenges
	local challengesCompleted = playerData.challengesCompleted or 0
	if challengesCompleted >= 10 then
		BadgeSystem.awardBadge(player, "Challenge Champion")
	end

	-- "Drama Queen" — started 10 fights
	local fightsStarted = playerData.fightsStarted or 0
	if fightsStarted >= 10 then
		BadgeSystem.awardBadge(player, "Drama Queen")
	end

	-- "Mansion Veteran" — played 50 games
	local gamesPlayed = playerData.gamesPlayed or 0
	if gamesPlayed >= 50 then
		BadgeSystem.awardBadge(player, "Mansion Veteran")
	end
end

-- ============================================================
-- GET BADGE INFO — Returns badge info for display purposes
-- ============================================================

function BadgeSystem.getBadgeInfo(badgeName: string)
	return BADGES[badgeName]
end

function BadgeSystem.getAllBadgeNames(): { string }
	local names = {}
	for name in BADGES do
		table.insert(names, name)
	end
	return names
end

return BadgeSystem

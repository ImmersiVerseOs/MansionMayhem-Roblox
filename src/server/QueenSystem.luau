-- ============================================================
-- QUEEN SYSTEM — Queen of the Week: crowning, privileges, tracking
-- Queen gets master suite, 1.5x vote weight, immunity for first week
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SupabaseAPI = require(script.Parent.SupabaseAPI)
local Config = require(ReplicatedStorage.Shared.Config)

local QueenSystem = {}

-- State
QueenSystem.currentQueen = nil -- { userId, name, crownedAt, weekNumber, approvalRating }
QueenSystem.queenHistory = {} -- { { userId, name, weekNumber, approvalRating } }
QueenSystem.approvalVotes = {} -- { [voterId] = "approve" | "disapprove" }
QueenSystem.queenPrivileges = {
	masterSuite = true,
	roomAssignment = true,
	voteWeight = 1.5,
	immunityFirstWeek = true,
}

-- ============================================================
-- CROWNING CEREMONY
-- ============================================================

function QueenSystem.crownQueen(userId, gameManager)
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		warn("[QueenSystem] Cannot crown — player not found:", userId)
		return false
	end

	local playerName = player.DisplayName or player.Name
	local weekNumber = 0
	if gameManager and gameManager.seasonData and gameManager.seasonData.week then
		weekNumber = gameManager.seasonData.week.week_number or 0
	end

	-- Store previous queen in history
	if QueenSystem.currentQueen then
		table.insert(QueenSystem.queenHistory, {
			userId = QueenSystem.currentQueen.userId,
			name = QueenSystem.currentQueen.name,
			weekNumber = QueenSystem.currentQueen.weekNumber,
			approvalRating = QueenSystem.currentQueen.approvalRating,
		})
	end

	-- Set new queen
	QueenSystem.currentQueen = {
		userId = userId,
		name = playerName,
		crownedAt = os.time(),
		weekNumber = weekNumber,
		approvalRating = 100, -- starts at 100%
	}

	-- Reset approval votes
	QueenSystem.approvalVotes = {}

	print("[QueenSystem] QUEEN CROWNED:", playerName, "— Week", weekNumber)

	-- Run crowning ceremony
	QueenSystem._runCrowningCeremony(player, gameManager)

	-- Sync to Supabase
	if gameManager and gameManager.seasonData then
		local seasonId = gameManager.seasonData.season and gameManager.seasonData.season.id
		if seasonId then
			task.spawn(function()
				SupabaseAPI.crownQueen(seasonId, tostring(userId), weekNumber)
			end)
		end
	end

	return true
end

function QueenSystem._runCrowningCeremony(player, gameManager)
	-- Step 1: Director announcement
	if gameManager then
		gameManager.directorAnnounce("ATTENTION HOUSEMATES! It is time to crown this week's QUEEN OF THE MANSION!")
	end

	task.wait(3)

	-- Step 2: Teleport queen to stage/throne area (Elimination Room stage)
	local character = player.Character
	if character then
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.CFrame = CFrame.new(135, 3, -25) -- Elimination Room stage center
		end
	end

	-- Step 3: Apply crown visual effect
	QueenSystem._applyCrownEffect(player)

	-- Step 4: Notify all clients of crowning
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("QueenCrowned")
	if remote then
		remote:FireAllClients({
			queenUserId = player.UserId,
			queenName = player.DisplayName or player.Name,
			weekNumber = QueenSystem.currentQueen.weekNumber,
			privileges = {
				"Master Suite (The Crown Suite)",
				"Room Assignment Power",
				"1.5x Vote Weight",
				"Immunity (first week as Queen)",
			},
		})
	end

	task.wait(3)

	-- Step 5: Director describes privileges
	if gameManager then
		gameManager.directorAnnounce(
			player.DisplayName .. " now has the CROWN SUITE, the power to ASSIGN ROOMS, " ..
			"a 1.5x VOTE WEIGHT, and IMMUNITY for this week! Use your power wisely... or don't."
		)
	end

	-- Step 6: Move queen to Crown Suite
	task.wait(5)
	if character then
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			-- Crown Suite position (Room 1 on upper floor)
			hrp.CFrame = CFrame.new(40, 21, 22)
		end
	end

	if gameManager then
		gameManager.directorAnnounce(player.DisplayName .. " has moved into THE CROWN SUITE. Long live the Queen.")
	end
end

function QueenSystem._applyCrownEffect(player)
	local character = player.Character
	if not character then return end

	local head = character:FindFirstChild("Head")
	if not head then return end

	-- Remove existing crown
	local existing = head:FindFirstChild("CrownEffect")
	if existing then existing:Destroy() end

	-- Create crown glow (golden neon part above head)
	local crown = Instance.new("Part")
	crown.Name = "CrownEffect"
	crown.Shape = Enum.PartType.Ball
	crown.Size = Vector3.new(1.5, 0.8, 1.5)
	crown.Color = Config.Colors.Gold
	crown.Material = Enum.Material.Neon
	crown.Transparency = 0.2
	crown.CanCollide = false
	crown.Anchored = false
	crown.Massless = true
	crown.Parent = head

	-- Weld to head
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = crown
	weld.Parent = crown

	crown.CFrame = head.CFrame * CFrame.new(0, 1.2, 0)

	-- Add golden PointLight
	local light = Instance.new("PointLight")
	light.Color = Config.Colors.Gold
	light.Brightness = 2
	light.Range = 15
	light.Parent = crown

	-- Add BillboardGui with "QUEEN" label
	local bg = Instance.new("BillboardGui")
	bg.Name = "QueenLabel"
	bg.Size = UDim2.new(0, 80, 0, 25)
	bg.StudsOffset = Vector3.new(0, 3.5, 0)
	bg.AlwaysOnTop = true
	bg.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundColor3 = Config.Colors.Gold
	label.BackgroundTransparency = 0.3
	label.Text = "QUEEN"
	label.TextColor3 = Config.Colors.Background
	label.TextSize = 14
	label.Font = Enum.Font.GothamBold
	label.Parent = bg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label
end

function QueenSystem._removeCrownEffect(userId)
	local player = Players:GetPlayerByUserId(userId)
	if not player or not player.Character then return end

	local head = player.Character:FindFirstChild("Head")
	if not head then return end

	local crown = head:FindFirstChild("CrownEffect")
	if crown then crown:Destroy() end

	local queenLabel = head:FindFirstChild("QueenLabel")
	if queenLabel then queenLabel:Destroy() end
end

-- ============================================================
-- QUEEN PRIVILEGES
-- ============================================================

function QueenSystem.getCurrentQueenId()
	if QueenSystem.currentQueen then
		return QueenSystem.currentQueen.userId
	end
	return nil
end

function QueenSystem.getCurrentQueenName()
	if QueenSystem.currentQueen then
		return QueenSystem.currentQueen.name
	end
	return nil
end

function QueenSystem.isQueen(userId)
	return QueenSystem.currentQueen ~= nil and QueenSystem.currentQueen.userId == userId
end

function QueenSystem.getVoteWeight(userId)
	if QueenSystem.isQueen(userId) then
		return QueenSystem.queenPrivileges.voteWeight
	end
	return 1
end

function QueenSystem.hasImmunity(userId)
	if not QueenSystem.isQueen(userId) then return false end
	-- Queen has immunity only in her first week as queen
	return QueenSystem.queenPrivileges.immunityFirstWeek
end

-- ============================================================
-- APPROVAL RATING
-- ============================================================

function QueenSystem.submitApproval(voterPlayer, approve)
	if not voterPlayer or not QueenSystem.currentQueen then return end

	-- Queen cannot vote on herself
	if voterPlayer.UserId == QueenSystem.currentQueen.userId then return end

	AllianceSystem_approvalVotes = AllianceSystem_approvalVotes or {}
	QueenSystem.approvalVotes[voterPlayer.UserId] = approve and "approve" or "disapprove"

	-- Recalculate approval rating
	local approveCount = 0
	local totalCount = 0
	for _, vote in QueenSystem.approvalVotes do
		totalCount += 1
		if vote == "approve" then
			approveCount += 1
		end
	end

	if totalCount > 0 then
		QueenSystem.currentQueen.approvalRating = math.floor((approveCount / totalCount) * 100)
	end

	print("[QueenSystem] Approval rating:", QueenSystem.currentQueen.approvalRating .. "%")

	-- Notify queen of new approval rating
	local queenPlayer = Players:GetPlayerByUserId(QueenSystem.currentQueen.userId)
	if queenPlayer then
		local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("QueenApproval")
		if remote then
			remote:FireClient(queenPlayer, {
				approvalRating = QueenSystem.currentQueen.approvalRating,
				totalVotes = totalCount,
			})
		end
	end
end

function QueenSystem.getApprovalRating()
	if QueenSystem.currentQueen then
		return QueenSystem.currentQueen.approvalRating
	end
	return 0
end

-- ============================================================
-- ROOM ASSIGNMENT (Queen's power)
-- ============================================================

function QueenSystem.assignRoom(queenPlayer, targetUserId, roomNumber, gameManager)
	if not queenPlayer then return { success = false, reason = "invalid_player" } end

	-- Verify this player is the queen
	if not QueenSystem.isQueen(queenPlayer.UserId) then
		return { success = false, reason = "not_queen" }
	end

	-- Validate room number
	if roomNumber < 1 or roomNumber > Config.BEDROOMS then
		return { success = false, reason = "invalid_room" }
	end

	-- Verify target player exists
	local targetPlayer = Players:GetPlayerByUserId(targetUserId)
	if not targetPlayer then
		return { success = false, reason = "player_not_found" }
	end

	-- Update room assignment in GameManager
	if gameManager then
		local playerData = gameManager.playerMap[targetUserId]
		if playerData then
			playerData.room = roomNumber
		end
	end

	local roomConfig = Config.BEDROOM_NAMES[roomNumber]
	local roomName = roomConfig and roomConfig.name or ("Room " .. roomNumber)

	print("[QueenSystem] Queen assigned", targetPlayer.DisplayName, "to", roomName)

	-- Notify the target
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("RoomAssignment")
	if remote then
		remote:FireClient(targetPlayer, {
			roomNumber = roomNumber,
			roomName = roomName,
			assignedBy = "queen",
			queenName = queenPlayer.DisplayName or queenPlayer.Name,
		})
	end

	-- Director commentary on interesting assignments
	if roomConfig and roomConfig.exile and gameManager then
		gameManager.directorAnnounce(
			"The Queen has sent " .. targetPlayer.DisplayName .. " to THE DOG HOUSE. Cold. Ice cold."
		)
	end

	return { success = true, roomNumber = roomNumber, roomName = roomName }
end

-- ============================================================
-- DETHRONE (end of queen's reign)
-- ============================================================

function QueenSystem.dethroneQueen(gameManager)
	if not QueenSystem.currentQueen then return end

	local queenName = QueenSystem.currentQueen.name
	local queenUserId = QueenSystem.currentQueen.userId

	-- Remove crown effect
	QueenSystem._removeCrownEffect(queenUserId)

	-- Move to history
	table.insert(QueenSystem.queenHistory, {
		userId = QueenSystem.currentQueen.userId,
		name = QueenSystem.currentQueen.name,
		weekNumber = QueenSystem.currentQueen.weekNumber,
		approvalRating = QueenSystem.currentQueen.approvalRating,
	})

	QueenSystem.currentQueen = nil
	QueenSystem.approvalVotes = {}

	if gameManager then
		gameManager.directorAnnounce(queenName .. "'s reign has ended. A new Queen will be crowned.")
	end

	print("[QueenSystem] Queen dethroned:", queenName)
end

-- ============================================================
-- QUEEN SELECTION (determine who becomes queen)
-- ============================================================

function QueenSystem.selectQueenByXP(gameManager)
	-- Queen = player with highest XP who hasn't been queen this season
	if not gameManager then return nil end

	local bestPlayer = nil
	local bestXP = -1

	for userId, data in gameManager.playerMap do
		if data.eliminated then continue end

		-- Check if already been queen
		local wasQueen = false
		for _, h in QueenSystem.queenHistory do
			if h.userId == userId then
				wasQueen = true
				break
			end
		end
		if QueenSystem.currentQueen and QueenSystem.currentQueen.userId == userId then
			wasQueen = true
		end

		if not wasQueen then
			local xp = data.xp or 0
			if xp > bestXP then
				bestXP = xp
				bestPlayer = userId
			end
		end
	end

	-- If everyone has been queen, allow repeats
	if not bestPlayer then
		for userId, data in gameManager.playerMap do
			if data.eliminated then continue end
			local xp = data.xp or 0
			if xp > bestXP then
				bestXP = xp
				bestPlayer = userId
			end
		end
	end

	return bestPlayer
end

-- ============================================================
-- CLEANUP
-- ============================================================

function QueenSystem.onPlayerLeave(player)
	-- If the queen leaves, dethrone
	if QueenSystem.currentQueen and QueenSystem.currentQueen.userId == player.UserId then
		QueenSystem.dethroneQueen(nil)
	end
	-- Remove approval vote
	QueenSystem.approvalVotes[player.UserId] = nil
end

function QueenSystem.getQueenInfo()
	if not QueenSystem.currentQueen then
		return nil
	end
	return {
		userId = QueenSystem.currentQueen.userId,
		name = QueenSystem.currentQueen.name,
		weekNumber = QueenSystem.currentQueen.weekNumber,
		approvalRating = QueenSystem.currentQueen.approvalRating,
		privileges = QueenSystem.queenPrivileges,
	}
end

function QueenSystem.getQueenHistory()
	return QueenSystem.queenHistory
end

return QueenSystem

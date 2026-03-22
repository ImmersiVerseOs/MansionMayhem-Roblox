-- ============================================================
-- ELIMINATION SYSTEM — Dramatic ceremony + removal for Mansion Mayhem
-- Teleports players to Elimination Room, reveals votes, eliminates
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SupabaseAPI = require(script.Parent.SupabaseAPI)
local Config = require(ReplicatedStorage.Shared.Config)

local EliminationSystem = {}

-- State
EliminationSystem.isActive = false
EliminationSystem.eliminatedPlayers = {} -- { [userId] = { name, week, round } }
EliminationSystem.spectators = {} -- { [userId] = true }

-- Elimination Room location (matches MansionBuilder)
local ELIMINATION_ROOM_CENTER = Vector3.new(135, 1, -25)
local STAGE_CENTER = Vector3.new(135, 2, -25)
local AUDIENCE_START = Vector3.new(125, 1, -15)

-- ============================================================
-- ELIMINATION CEREMONY
-- ============================================================

function EliminationSystem.startCeremony(gameManager)
	if EliminationSystem.isActive then
		warn("[EliminationSystem] Ceremony already in progress")
		return false
	end

	EliminationSystem.isActive = true
	print("[EliminationSystem] Starting Elimination Ceremony...")

	-- Director announcement
	if gameManager then
		gameManager.directorAnnounce("Everyone to the Elimination Room. NOW.")
	end

	task.wait(3)

	-- Teleport all active players to the Elimination Room
	EliminationSystem._teleportAllToEliminationRoom(gameManager)

	task.wait(2)

	-- Dim the lights effect (notify clients)
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("EliminationStart")
	if remote then
		remote:FireAllClients({
			phase = "gathering",
			message = "The votes have been cast. The Director will now reveal the results.",
		})
	end

	task.wait(3)

	if gameManager then
		gameManager.directorAnnounce("Let the elimination begin.")
	end

	return true
end

function EliminationSystem._teleportAllToEliminationRoom(gameManager)
	local index = 0
	for _, player in Players:GetPlayers() do
		-- Skip spectators
		if EliminationSystem.spectators[player.UserId] then continue end

		local character = player.Character
		if character then
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			if humanoidRootPart then
				-- Arrange in a semicircle around the stage
				local angle = math.rad(180 + (index * 18) - 80)
				local radius = 12
				local pos = Vector3.new(
					STAGE_CENTER.X + math.cos(angle) * radius,
					STAGE_CENTER.Y,
					STAGE_CENTER.Z + math.sin(angle) * radius
				)
				humanoidRootPart.CFrame = CFrame.new(pos, STAGE_CENTER)
				index += 1
			end
		end
	end

	print("[EliminationSystem] Teleported", index, "players to Elimination Room")
end

-- ============================================================
-- DRAMATIC REVEAL SEQUENCE
-- ============================================================

function EliminationSystem.runDramaticReveal(nominees, results, gameManager)
	if not EliminationSystem.isActive then return end

	print("[EliminationSystem] Running dramatic reveal sequence...")

	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("EliminationReveal")

	-- Step 1: Spotlight on each nominee with a pause
	for i, nominee in nominees do
		if gameManager then
			gameManager.directorAnnounce(nominee.name .. "... step forward.")
		end

		-- Move nominee to stage
		local nomineePlayer = Players:GetPlayerByUserId(nominee.userId)
		if nomineePlayer and nomineePlayer.Character then
			local hrp = nomineePlayer.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local stageAngle = math.rad(90 + (i - 1) * (180 / math.max(#nominees - 1, 1)))
				local stagePos = Vector3.new(
					STAGE_CENTER.X + math.cos(stageAngle) * 4,
					STAGE_CENTER.Y + 1,
					STAGE_CENTER.Z + math.sin(stageAngle) * 4
				)
				hrp.CFrame = CFrame.new(stagePos, STAGE_CENTER)
			end
		end

		if remote then
			remote:FireAllClients({
				phase = "spotlight",
				nomineeIndex = i,
				nomineeName = nominee.name,
				nomineeUserId = nominee.userId,
			})
		end

		task.wait(3)
	end

	-- Step 2: Countdown
	if gameManager then
		gameManager.directorAnnounce("The person leaving the Mansion tonight is...")
	end

	if remote then
		remote:FireAllClients({
			phase = "countdown",
			duration = 5,
		})
	end

	-- Dramatic countdown
	for i = 5, 1, -1 do
		task.wait(1)
		if remote then
			remote:FireAllClients({
				phase = "countdown_tick",
				number = i,
			})
		end
	end

	task.wait(1)

	-- Step 3: Reveal the eliminated player
	local eliminated = results[1] -- highest votes
	if eliminated then
		if gameManager then
			gameManager.directorAnnounce(eliminated.name .. "... your time in the Mansion is OVER.")
		end

		if remote then
			remote:FireAllClients({
				phase = "eliminated",
				name = eliminated.name,
				userId = eliminated.userId,
				voteCount = eliminated.voteCount,
				results = results,
			})
		end

		task.wait(5)
	end

	return eliminated
end

-- ============================================================
-- PROCESS ELIMINATION
-- ============================================================

function EliminationSystem.eliminatePlayer(userId, gameManager)
	local player = Players:GetPlayerByUserId(userId)
	local playerName = "Unknown"

	if player then
		playerName = player.DisplayName or player.Name
	end

	print("[EliminationSystem] Eliminating:", playerName, "(", userId, ")")

	-- Record locally
	local currentWeek = 0
	if gameManager and gameManager.seasonData and gameManager.seasonData.week then
		currentWeek = gameManager.seasonData.week.week_number or 0
	end

	EliminationSystem.eliminatedPlayers[userId] = {
		name = playerName,
		week = currentWeek,
		round = gameManager and gameManager.votingSystem and gameManager.votingSystem.currentRound or 0,
	}

	-- Update player data in GameManager
	if gameManager then
		local playerData = gameManager.playerMap[userId]
		if playerData then
			playerData.eliminated = true
			playerData.eliminatedWeek = currentWeek
		end
	end

	-- Move to spectator mode
	EliminationSystem.spectators[userId] = true

	-- Update Supabase
	if gameManager and gameManager.seasonData then
		local seasonId = gameManager.seasonData.season and gameManager.seasonData.season.id
		if seasonId then
			SupabaseAPI.eliminatePlayer(seasonId, tostring(userId), currentWeek)
		end
	end

	-- Apply spectator mode to the player
	if player then
		EliminationSystem._applySpectatorMode(player, gameManager)
	end

	-- Director farewell
	if gameManager then
		task.wait(3)
		gameManager.directorAnnounce(playerName .. " has left the Mansion. " .. EliminationSystem._getEliminationQuote())
	end

	-- Notify all clients
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("EliminationComplete")
	if remote then
		remote:FireAllClients({
			eliminatedName = playerName,
			eliminatedUserId = userId,
			remainingPlayers = EliminationSystem._countActivePlayers(gameManager),
		})
	end

	EliminationSystem.isActive = false
end

function EliminationSystem._applySpectatorMode(player, gameManager)
	-- Make the player invisible and unable to interact
	local character = player.Character
	if character then
		-- Make transparent
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") then
				part.Transparency = 0.7
				part.CanCollide = false
			end
		end

		-- Add a "SPECTATOR" overhead label
		local head = character:FindFirstChild("Head")
		if head then
			local existing = head:FindFirstChild("SpectatorGui")
			if not existing then
				local bg = Instance.new("BillboardGui")
				bg.Name = "SpectatorGui"
				bg.Size = UDim2.new(0, 100, 0, 30)
				bg.StudsOffset = Vector3.new(0, 3, 0)
				bg.AlwaysOnTop = true
				bg.Parent = head

				local label = Instance.new("TextLabel")
				label.Size = UDim2.new(1, 0, 1, 0)
				label.BackgroundTransparency = 1
				label.Text = "SPECTATOR"
				label.TextColor3 = Config.Colors.TextMuted
				label.TextSize = 14
				label.Font = Enum.Font.GothamBold
				label.Parent = bg
			end
		end
	end

	-- Teleport to rooftop (spectator area)
	local rooftopY = 20 + 14 + 2
	if character then
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.CFrame = CFrame.new(100, rooftopY + 2, 0)
		end
	end

	-- Notify the eliminated player
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("SpectatorMode")
	if remote then
		remote:FireClient(player, {
			eliminated = true,
			message = "You have been eliminated. You can now spectate the remaining players.",
		})
	end
end

function EliminationSystem._countActivePlayers(gameManager)
	local count = 0
	if gameManager then
		for userId, data in gameManager.playerMap do
			if not data.eliminated then
				count += 1
			end
		end
	end
	return count
end

function EliminationSystem._getEliminationQuote()
	local quotes = {
		"The Mansion shows no mercy.",
		"Another one bites the dust.",
		"The game continues without them.",
		"Goodbye is never easy... except when it is.",
		"The Mansion giveth, and the Mansion taketh away.",
		"Their story ends here. Yours continues.",
		"One less player. One step closer to the crown.",
		"In this house, nobody is safe forever.",
	}
	return quotes[math.random(1, #quotes)]
end

-- ============================================================
-- FULL ELIMINATION FLOW (called by GameManager)
-- ============================================================

function EliminationSystem.runFullElimination(nominees, results, gameManager)
	-- 1. Start ceremony (teleport everyone)
	EliminationSystem.startCeremony(gameManager)
	task.wait(5)

	-- 2. Dramatic reveal (spotlights, countdown)
	local eliminated = EliminationSystem.runDramaticReveal(nominees, results, gameManager)
	task.wait(3)

	-- 3. Process the elimination
	if eliminated then
		EliminationSystem.eliminatePlayer(eliminated.userId, gameManager)
	end

	return eliminated
end

-- ============================================================
-- UTILITIES
-- ============================================================

function EliminationSystem.isSpectator(userId)
	return EliminationSystem.spectators[userId] == true
end

function EliminationSystem.isEliminated(userId)
	return EliminationSystem.eliminatedPlayers[userId] ~= nil
end

function EliminationSystem.getEliminatedList()
	local list = {}
	for userId, data in EliminationSystem.eliminatedPlayers do
		table.insert(list, {
			userId = userId,
			name = data.name,
			week = data.week,
		})
	end
	table.sort(list, function(a, b) return a.week < b.week end)
	return list
end

function EliminationSystem.onPlayerLeave(player)
	-- If an eliminated spectator leaves, just clean up
	EliminationSystem.spectators[player.UserId] = nil
end

return EliminationSystem

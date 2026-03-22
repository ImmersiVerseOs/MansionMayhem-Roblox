-- ============================================================
-- GAME MANAGER — Core game loop for Mansion Mayhem Roblox
-- Manages seasons, daily events, voting, elimination, rooms
-- Day type state machine with phase transitions
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TextService = game:GetService("TextService")

local SupabaseAPI = require(script.Parent.SupabaseAPI)
local Config = require(ReplicatedStorage.Shared.Config)
local VotingSystem = require(script.Parent.VotingSystem)
local EliminationSystem = require(script.Parent.EliminationSystem)
local FightSystem = require(script.Parent.FightSystem)
local AllianceSystem = require(script.Parent.AllianceSystem)
local QueenSystem = require(script.Parent.QueenSystem)
local ChallengeSystem = require(script.Parent.ChallengeSystem)
local ImmunitySystem = require(script.Parent.ImmunitySystem)
local MonetizationSystem = require(script.Parent.MonetizationSystem)
local NPCSystem = require(script.Parent.NPCSystem)
local AntiCheat = require(script.Parent.AntiCheat)
local DataStoreBackup = require(script.Parent.DataStoreBackup)
local BadgeSystem = require(script.Parent.BadgeSystem)

-- Private server detection
local isPrivateServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0

local GameManager = {}
GameManager.seasonData = nil
GameManager.events = {}
GameManager.playerMap = {} -- Roblox UserId -> mansion player data
GameManager.currentPhase = "lobby"

-- Expose sub-systems for cross-references
GameManager.votingSystem = VotingSystem
GameManager.eliminationSystem = EliminationSystem
GameManager.fightSystem = FightSystem
GameManager.allianceSystem = AllianceSystem
GameManager.queenSystem = QueenSystem
GameManager.challengeSystem = ChallengeSystem
GameManager.immunitySystem = ImmunitySystem
GameManager.monetizationSystem = MonetizationSystem
GameManager.npcSystem = NPCSystem
GameManager.antiCheat = AntiCheat
GameManager.dataStoreBackup = DataStoreBackup
GameManager.badgeSystem = BadgeSystem

-- Day type state machine order
local DAY_PHASES = {
	"move_in",        -- Day 1: arrivals + room assignment
	"social",         -- Day 2: alliances form
	"challenge",      -- Day 3: main challenge
	"whisper",        -- Day 4: secrets + Director twists
	"confrontation",  -- Day 5: face-offs
	"deliberation",   -- Day 6: campaigning + last pleas
	"elimination",    -- Day 7: vote + someone goes home
}

-- ============================================================
-- INITIALIZATION
-- ============================================================

function GameManager.init()
	print("[GameManager] Starting Mansion Mayhem...")

	-- Create RemoteEvents for client communication
	local remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage

	local events = {
		-- Existing
		"SeasonUpdate", "EventUpdate", "TeaWallUpdate",
		"DirectorAnnounce", "VoteStart", "VoteEnd",
		"RoomAssignment", "FightAlert", "CheckInResult",
		"PostConfession", "CastVote", "RequestCheckIn",
		"ScenarioUpdate", "LeaderboardUpdate",

		-- Voting
		"NominationStart", "NominationResult", "SubmitNomination",
		"VoteConfirm",

		-- Elimination
		"EliminationStart", "EliminationReveal", "EliminationComplete",
		"SpectatorMode",

		-- Fight
		"FightPrompt", "FightResolved", "StartFight",

		-- Alliance
		"AllianceInvite", "AllianceUpdate", "ProposeAlliance",
		"AcceptAlliance", "DeclineAlliance", "LeaveAlliance",

		-- Queen
		"QueenCrowned", "QueenApproval", "SubmitApproval",
		"QueenAssignRoom",

		-- Challenge
		"ChallengeList", "ChallengeUpdate", "AcceptChallenge",
		"GroupGoalUpdate",

		-- Immunity
		"ImmunityUpdate", "ImmunityAnnounce", "UseImmunityToken",

		-- Season info
		"SeasonInfoRequest", "SeasonInfoResponse",
		"LeaderboardRequest",

		-- Phase
		"PhaseUpdate",

		-- Effects & Camera
		"PlayEffect",
		"CameraControl",

		-- Error messaging
		"ErrorMessage",

		-- Bus system
		"BusCountdown",
		"BusCinematic",
		"BusArrive",
	}

	for _, name in events do
		local re = Instance.new("RemoteEvent")
		re.Name = name
		re.Parent = remotes
	end

	-- Load season data
	GameManager.loadSeason()

	-- Set up player connections
	Players.PlayerAdded:Connect(GameManager.onPlayerJoin)
	Players.PlayerRemoving:Connect(GameManager.onPlayerLeave)

	-- Wire client->server event handlers
	GameManager._wireClientEvents(remotes)

	-- Initialize sub-systems
	AntiCheat.init()
	DataStoreBackup.init()
	BadgeSystem.init()
	FightSystem.init()

	-- Initialize NPCs (spawn crew in the mansion)
	local mansion = workspace:FindFirstChild("Mansion")
	NPCSystem.init(mansion)

	-- Generate daily challenges
	ChallengeSystem.generateDailyChallenges(GameManager)

	-- Start game loop
	GameManager.startGameLoop()

	-- Start DataStore auto-save loop (every 60 seconds)
	DataStoreBackup.startAutoSaveLoop(GameManager)

	-- Private server admin commands
	if isPrivateServer then
		print("[GameManager] Private server detected. Owner ID:", game.PrivateServerOwnerId)
		if Config.PRIVATE_SERVER and Config.PRIVATE_SERVER.customSettings and Config.PRIVATE_SERVER.customSettings.fastMode then
			print("[GameManager] Fast mode enabled for private server (30s phase timers)")
		end

		Players.PlayerAdded:Connect(function(p)
			if p.UserId == game.PrivateServerOwnerId then
				print("[GameManager] Private server owner joined:", p.Name)
				p.Chatted:Connect(function(msg)
					if msg == "/skip" then
						-- Advance to next phase
						local currentIndex = 0
						for i, phase in DAY_PHASES do
							if phase == GameManager.currentPhase then
								currentIndex = i
								break
							end
						end
						local nextIndex = (currentIndex % #DAY_PHASES) + 1
						GameManager.setPhase(DAY_PHASES[nextIndex])
						GameManager.directorAnnounce("The owner has advanced the phase!")
					elseif msg:sub(1, 12) == "/startphase " then
						local targetPhase = msg:sub(13):lower():gsub(" ", "_")
						local validPhase = false
						for _, phase in DAY_PHASES do
							if phase == targetPhase then
								validPhase = true
								break
							end
						end
						if validPhase then
							GameManager.setPhase(targetPhase)
							GameManager.directorAnnounce("The owner has set the phase to: " .. targetPhase)
						end
					elseif msg:sub(1, 6) == "/crown" then
						local targetName = msg:sub(8)
						if targetName and #targetName > 0 then
							for _, target in Players:GetPlayers() do
								if target.Name:lower() == targetName:lower() or target.DisplayName:lower() == targetName:lower() then
									QueenSystem.dethroneQueen(GameManager)
									QueenSystem.crownQueen(target.UserId, GameManager)
									GameManager.directorAnnounce(target.DisplayName .. " has been crowned by the server owner!")
									break
								end
							end
						end
					end
				end)
			end
		end)
	end

	print("[GameManager] Mansion Mayhem ready!")
end

-- ============================================================
-- ERROR MESSAGING
-- ============================================================

function GameManager.sendError(player, message)
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("ErrorMessage")
	if remote then
		remote:FireClient(player, { error = true, message = message })
	end
end

-- ============================================================
-- TEXT FILTERING (Roblox TextService)
-- ============================================================

function GameManager.filterText(text, player)
	local success, result = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId)
	end)
	if success then
		local filterSuccess, filtered = pcall(function()
			return result:GetNonChatStringForBroadcastAsync()
		end)
		if filterSuccess then
			return filtered
		end
	end
	return nil -- reject if filtering fails
end

-- ============================================================
-- CLIENT EVENT WIRING
-- ============================================================

function GameManager._wireClientEvents(remotes)
	-- Confession
	local postConfession = remotes:FindFirstChild("PostConfession")
	if postConfession then
		postConfession.OnServerEvent:Connect(function(player, text)
			GameManager.handleConfession(player, text)
		end)
	end

	-- Check-in (with AntiCheat validation)
	local requestCheckIn = remotes:FindFirstChild("RequestCheckIn")
	if requestCheckIn then
		requestCheckIn.OnServerEvent:Connect(function(player)
			local valid, reason = AntiCheat.validateCheckIn(player, GameManager)
			if not valid then
				GameManager.sendError(player, "Check-in denied: " .. (reason or "unknown"))
				return
			end
			if not AntiCheat.rateLimit(player, "checkin", 5) then
				GameManager.sendError(player, "Please wait before checking in again.")
				return
			end
			GameManager.handleCheckIn(player)
		end)
	end

	-- Voting / Nomination (with AntiCheat validation)
	local castVote = remotes:FindFirstChild("CastVote")
	if castVote then
		castVote.OnServerEvent:Connect(function(player, nomineeId)
			local valid, reason = AntiCheat.validateVote(player, nomineeId, GameManager)
			if not valid then
				GameManager.sendError(player, "Vote denied: " .. (reason or "unknown"))
				return
			end
			if not AntiCheat.rateLimit(player, "vote", 2) then
				GameManager.sendError(player, "Please wait before voting again.")
				return
			end
			VotingSystem.handleVote(player, nomineeId, GameManager)
		end)
	end

	local submitNomination = remotes:FindFirstChild("SubmitNomination")
	if submitNomination then
		submitNomination.OnServerEvent:Connect(function(player, nomineeUserId)
			local valid, reason = AntiCheat.validateNomination(player, nomineeUserId, GameManager)
			if not valid then
				GameManager.sendError(player, "Nomination denied: " .. (reason or "unknown"))
				return
			end
			if not AntiCheat.rateLimit(player, "nomination", 3) then
				GameManager.sendError(player, "Please wait before nominating again.")
				return
			end
			VotingSystem.handleNomination(player, nomineeUserId, GameManager)
		end)
	end

	-- Fight (with AntiCheat validation)
	local startFight = remotes:FindFirstChild("StartFight")
	if startFight then
		startFight.OnServerEvent:Connect(function(player, defenderUserId, reason)
			local valid, acReason = AntiCheat.validateFight(player, defenderUserId, GameManager)
			if not valid then
				GameManager.sendError(player, "Fight denied: " .. (acReason or "unknown"))
				return
			end
			if not AntiCheat.rateLimit(player, "fight", 5) then
				GameManager.sendError(player, "Please wait before starting another fight.")
				return
			end

			local fight = FightSystem.startFight(player, defenderUserId, reason, GameManager)

			-- Record fight in AntiCheat tracking
			if fight then
				AntiCheat.recordFight(player.UserId, defenderUserId)

				-- Track fights started for "Drama Queen" milestone
				local attackerData = GameManager.playerMap[player.UserId]
				if attackerData then
					attackerData.fightsStarted = (attackerData.fightsStarted or 0) + 1
				end

				-- Check if fighter is betraying an alliance member -> "Backstabber" badge
				if AllianceSystem.areAllied(player.UserId, defenderUserId) then
					task.spawn(function()
						BadgeSystem.awardBadge(player, "Backstabber")
					end)
				end
			end

			-- Dispatch NPCs and effects when a fight starts
			if fight then
				local fightPos = Vector3.new(0, 1, 0)
				if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
					fightPos = player.Character.HumanoidRootPart.Position
				end

				-- Dispatch camera crew to any fight
				NPCSystem.dispatchCamera(fightPos)

				-- Dispatch security at high intensity
				if fight.intensity >= 7 then
					NPCSystem.dispatchSecurity(fightPos)
				end

				-- Fire sparks effect at fight location
				local playEffect = remotes:FindFirstChild("PlayEffect")
				if playEffect then
					playEffect:FireAllClients({
						effect = "fireSparks",
						position = fightPos,
						continuous = false,
					})
				end
			end
		end)
	end

	-- Alliance (with AntiCheat validation on propose)
	local proposeAlliance = remotes:FindFirstChild("ProposeAlliance")
	if proposeAlliance then
		proposeAlliance.OnServerEvent:Connect(function(player, targetUserId)
			local valid, acReason = AntiCheat.validateAllianceProposal(player, targetUserId, GameManager)
			if not valid then
				GameManager.sendError(player, "Alliance proposal denied: " .. (acReason or "unknown"))
				return
			end
			if not AntiCheat.rateLimit(player, "alliance_propose", 5) then
				GameManager.sendError(player, "Please wait before proposing another alliance.")
				return
			end

			local result = AllianceSystem.proposeAlliance(player, targetUserId, GameManager)
			local remote = remotes:FindFirstChild("AllianceUpdate")
			if remote then
				remote:FireClient(player, {
					type = "propose_result",
					success = result.success,
					reason = result.reason,
					allianceName = result.allianceName,
				})
			end
		end)
	end

	local acceptAlliance = remotes:FindFirstChild("AcceptAlliance")
	if acceptAlliance then
		acceptAlliance.OnServerEvent:Connect(function(player)
			local result = AllianceSystem.acceptInvite(player, GameManager)
			local remote = remotes:FindFirstChild("AllianceUpdate")
			if remote then
				remote:FireClient(player, {
					type = "accept_result",
					success = result.success,
					reason = result.reason,
					allianceName = result.allianceName,
				})
			end
			-- Award "Alliance Maker" badge on successful alliance
			if result.success then
				task.spawn(function()
					BadgeSystem.awardBadge(player, "Alliance Maker")
				end)
			end
		end)
	end

	local declineAlliance = remotes:FindFirstChild("DeclineAlliance")
	if declineAlliance then
		declineAlliance.OnServerEvent:Connect(function(player)
			AllianceSystem.declineInvite(player, GameManager)
		end)
	end

	local leaveAlliance = remotes:FindFirstChild("LeaveAlliance")
	if leaveAlliance then
		leaveAlliance.OnServerEvent:Connect(function(player)
			AllianceSystem.leaveAlliance(player, GameManager)
		end)
	end

	-- Queen approval
	local submitApproval = remotes:FindFirstChild("SubmitApproval")
	if submitApproval then
		submitApproval.OnServerEvent:Connect(function(player, approve)
			QueenSystem.submitApproval(player, approve)
		end)
	end

	-- Queen room assignment
	local queenAssignRoom = remotes:FindFirstChild("QueenAssignRoom")
	if queenAssignRoom then
		queenAssignRoom.OnServerEvent:Connect(function(player, targetUserId, roomNumber)
			local result = QueenSystem.assignRoom(player, targetUserId, roomNumber, GameManager)
			local remote = remotes:FindFirstChild("AllianceUpdate")
			if remote then
				remote:FireClient(player, {
					type = "room_assign_result",
					success = result.success,
					reason = result.reason,
					roomName = result.roomName,
				})
			end
		end)
	end

	-- Challenge
	local acceptChallenge = remotes:FindFirstChild("AcceptChallenge")
	if acceptChallenge then
		acceptChallenge.OnServerEvent:Connect(function(player, challengeId)
			ChallengeSystem.acceptChallenge(player, challengeId)
		end)
	end

	-- Immunity (with AntiCheat validation)
	local useImmunityToken = remotes:FindFirstChild("UseImmunityToken")
	if useImmunityToken then
		useImmunityToken.OnServerEvent:Connect(function(player)
			local valid, acReason = AntiCheat.validateImmunityUse(player, GameManager)
			if not valid then
				GameManager.sendError(player, "Immunity use denied: " .. (acReason or "unknown"))
				return
			end
			if not AntiCheat.rateLimit(player, "immunity", 5) then
				GameManager.sendError(player, "Please wait before using immunity again.")
				return
			end

			local result = ImmunitySystem.useToken(player, GameManager)
			if result and result.success then
				AntiCheat.recordImmunityUse(player.UserId)
				-- Award "Immunity Shield" badge on first immunity use
				task.spawn(function()
					BadgeSystem.awardBadge(player, "Immunity Shield")
				end)
			end
		end)
	end

	-- Season info request
	local seasonInfoReq = remotes:FindFirstChild("SeasonInfoRequest")
	if seasonInfoReq then
		seasonInfoReq.OnServerEvent:Connect(function(player)
			GameManager._sendSeasonInfo(player)
		end)
	end

	-- Leaderboard request
	local leaderboardReq = remotes:FindFirstChild("LeaderboardRequest")
	if leaderboardReq then
		leaderboardReq.OnServerEvent:Connect(function(player)
			GameManager._sendLeaderboard(player)
		end)
	end
end

-- ============================================================
-- SEASON DATA
-- ============================================================

function GameManager.loadSeason()
	local status = SupabaseAPI.getSeasonStatus()
	if status and status.active then
		GameManager.seasonData = status
		print("[GameManager] Season loaded:", status.season.title)

		-- Load today's events
		GameManager.events = SupabaseAPI.getEvents(status.season.id) or {}
		print("[GameManager] Events loaded:", #GameManager.events)

		-- Determine current phase from day type
		if status.day then
			GameManager.currentPhase = status.day.day_type or "lobby"
		end

		-- Broadcast to all players
		GameManager.broadcastSeasonUpdate()
	else
		print("[GameManager] No active season")
	end
end

function GameManager.broadcastSeasonUpdate()
	local remote = ReplicatedStorage.Remotes:FindFirstChild("SeasonUpdate")
	if remote and GameManager.seasonData then
		remote:FireAllClients(GameManager.seasonData)
	end
end

-- ============================================================
-- PLAYER MANAGEMENT
-- ============================================================

function GameManager.onPlayerJoin(player)
	print("[GameManager] Player joined:", player.Name, "(ID:", player.UserId, ")")

	-- Map Roblox player to mansion player
	GameManager.playerMap[player.UserId] = {
		robloxId = player.UserId,
		name = player.DisplayName or player.Name,
		room = nil,
		checkedIn = false,
		eliminated = false,
		xp = 0,
		coins = 0,
		fightsWon = 0,
		fightsLost = 0,
		queenCount = 0,
	}

	-- Load saved data from DataStoreBackup and merge
	task.spawn(function()
		local savedData = DataStoreBackup.loadPlayer(player.UserId)
		if savedData then
			local playerData = GameManager.playerMap[player.UserId]
			if playerData then
				DataStoreBackup.mergeIntoPlayerData(playerData, savedData)
				print("[GameManager] Merged DataStore backup for", player.Name)
			end
		end
	end)

	-- Send current season data
	local remote = ReplicatedStorage.Remotes:FindFirstChild("SeasonUpdate")
	if remote and GameManager.seasonData then
		remote:FireClient(player, GameManager.seasonData)
	end

	-- Send events
	local eventRemote = ReplicatedStorage.Remotes:FindFirstChild("EventUpdate")
	if eventRemote then
		eventRemote:FireClient(player, GameManager.events)
	end

	-- Load and send tea wall
	GameManager.sendTeaWall(player)

	-- Send phase update
	GameManager._sendPhaseUpdate(player)

	-- Sync immunity data
	ImmunitySystem.syncToClient(player)

	-- Send challenge list
	local challengeRemote = ReplicatedStorage.Remotes:FindFirstChild("ChallengeList")
	if challengeRemote then
		challengeRemote:FireClient(player, {
			challenges = ChallengeSystem.getActiveChallenges(),
			groupGoals = {},
		})
	end

	-- Apply VIP tag if player has VIP pass
	task.spawn(function()
		task.wait(2) -- Wait for game pass cache to populate
		if MonetizationSystem.hasGamePass(player, "VIP") then
			MonetizationSystem._applyVIPTag(player)
		end
	end)

	-- Award "Welcome to the Mansion" badge on first join
	task.spawn(function()
		BadgeSystem.awardBadge(player, "Welcome to the Mansion")
	end)

	-- Announce arrival
	GameManager.directorAnnounce(player.DisplayName .. " has entered the Mansion.")
end

function GameManager.onPlayerLeave(player)
	-- Save player data to DataStoreBackup before disconnect
	DataStoreBackup.onPlayerLeave(player, GameManager)

	-- Notify all sub-systems
	VotingSystem.onPlayerLeave(player)
	EliminationSystem.onPlayerLeave(player)
	FightSystem.onPlayerLeave(player)
	AllianceSystem.onPlayerLeave(player)
	QueenSystem.onPlayerLeave(player)
	ChallengeSystem.onPlayerLeave(player)
	ImmunitySystem.onPlayerLeave(player)
	AntiCheat.onPlayerLeave(player)

	GameManager.playerMap[player.UserId] = nil
	print("[GameManager] Player left:", player.Name)
end

-- ============================================================
-- PHASE MANAGEMENT (Day Type State Machine)
-- ============================================================

function GameManager.setPhase(newPhase)
	local oldPhase = GameManager.currentPhase
	GameManager.currentPhase = newPhase

	print("[GameManager] Phase transition:", oldPhase, "->", newPhase)

	-- Broadcast phase change
	local remote = ReplicatedStorage.Remotes:FindFirstChild("PhaseUpdate")
	if remote then
		remote:FireAllClients({
			phase = newPhase,
			previousPhase = oldPhase,
		})
	end

	-- Execute phase-specific logic
	GameManager._onPhaseStart(newPhase)
end

function GameManager._onPhaseStart(phase)
	if phase == "move_in" then
		GameManager.directorAnnounce("WELCOME to the Mansion of Mayhem! Time to meet your housemates and find your rooms.")

	elseif phase == "social" then
		GameManager.directorAnnounce("SOCIAL DAY. Form alliances, make friends, make enemies. The cameras are always watching.")
		ChallengeSystem.generateDailyChallenges(GameManager)

	elseif phase == "challenge" then
		GameManager.directorAnnounce("CHALLENGE DAY. Today you compete. The winner earns glory, XP, and possibly the Crown.")
		ChallengeSystem.generateDailyChallenges(GameManager)

	elseif phase == "whisper" then
		GameManager.directorAnnounce("WHISPER DAY. Secrets are currency in the Mansion. The Director has information that could change everything.")

	elseif phase == "confrontation" then
		GameManager.directorAnnounce("CONFRONTATION DAY. Time to face the music. The truth WILL come out today.")

	elseif phase == "deliberation" then
		GameManager.directorAnnounce("DELIBERATION DAY. Tomorrow someone goes home. Campaign for your life. This is your last chance.")
		-- Start nominations
		task.delay(10, function()
			VotingSystem.startNominationPhase(GameManager)
		end)

	elseif phase == "elimination" then
		GameManager.directorAnnounce("ELIMINATION NIGHT. The votes have been cast. Someone is leaving the Mansion TONIGHT.")
		-- Run elimination sequence
		task.delay(10, function()
			GameManager._runEliminationSequence()
		end)
	end
end

function GameManager._runEliminationSequence()
	-- Get voting results
	local eliminatedPlayer = VotingSystem.tallyVotes(GameManager)
	if not eliminatedPlayer then
		GameManager.directorAnnounce("No valid votes were cast. The Director spares everyone... this time.")
		return
	end

	-- Build nominee list for dramatic reveal
	local nominees = {}
	for userId, data in VotingSystem.nominees do
		table.insert(nominees, { userId = userId, name = data.name })
	end

	-- Build results list
	local results = {}
	for _, nominee in nominees do
		local voteCount = 0
		for _, votedForId in VotingSystem.votes do
			if votedForId == nominee.userId then
				voteCount += 1
			end
		end
		table.insert(results, {
			userId = nominee.userId,
			name = nominee.name,
			voteCount = voteCount,
		})
	end
	table.sort(results, function(a, b) return a.voteCount > b.voteCount end)

	-- Run full elimination ceremony
	EliminationSystem.runFullElimination(nominees, results, GameManager)

	-- Award "Survivor" badge to all players who survived this elimination
	task.spawn(function()
		for userId, data in GameManager.playerMap do
			if not data.eliminated then
				local survivorPlayer = Players:GetPlayerByUserId(userId)
				if survivorPlayer then
					BadgeSystem.awardBadge(survivorPlayer, "Survivor")
				end
			end
		end
	end)

	-- Dispatch camera crew and Director to elimination room
	local elimRoomPos = Vector3.new(135, 1, -25)
	NPCSystem.dispatchCamera(elimRoomPos)
	NPCSystem.teleportNPC("THE DIRECTOR", elimRoomPos + Vector3.new(-5, 0, 5))

	-- Fire elimination effects to clients
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local playEffect = remotes:FindFirstChild("PlayEffect")
		if playEffect then
			playEffect:FireAllClients({
				effect = "smoke",
				position = elimRoomPos,
				duration = 10,
			})
			playEffect:FireAllClients({
				effect = "spotlightSweep",
				position = elimRoomPos,
				duration = 20,
			})
		end

		-- Camera control: orbit around podium then zoom on eliminated
		local cameraControl = remotes:FindFirstChild("CameraControl")
		if cameraControl then
			cameraControl:FireAllClients({
				action = "orbitAround",
				center = elimRoomPos,
				radius = 15,
				duration = 8,
				height = 8,
			})

			-- After orbit, zoom on eliminated player
			local eliminated = results[1]
			if eliminated then
				task.delay(9, function()
					cameraControl:FireAllClients({
						action = "zoomOnPlayer",
						targetUserId = eliminated.userId,
						distance = 6,
						duration = 3,
					})
				end)

				-- Unlock camera after dramatic moment
				task.delay(15, function()
					cameraControl:FireAllClients({
						action = "unlockCamera",
					})
				end)
			end
		end
	end

	-- Clear voting state
	task.delay(30, function()
		VotingSystem.reset()
		ImmunitySystem.clearRoundImmunity()
		AntiCheat.clearImmunityRound()
	end)

	-- Crown new queen after elimination
	task.delay(45, function()
		-- Dethrone current queen
		QueenSystem.dethroneQueen(GameManager)
		-- Select and crown new queen
		local newQueenId = QueenSystem.selectQueenByXP(GameManager)
		if newQueenId then
			QueenSystem.crownQueen(newQueenId, GameManager)
			-- Grant queen immunity
			ImmunitySystem.grantQueenImmunity(newQueenId, GameManager)

			-- Award "Queen of the Week" badge
			local queenBadgePlayer = Players:GetPlayerByUserId(newQueenId)
			if queenBadgePlayer then
				task.spawn(function()
					BadgeSystem.awardBadge(queenBadgePlayer, "Queen of the Week")
				end)
			end

			-- Fire confetti and camera for queen crowning
			local qRemotes = ReplicatedStorage:FindFirstChild("Remotes")
			if qRemotes then
				local queenPlayer = Players:GetPlayerByUserId(newQueenId)
				local queenPos = Vector3.new(135, 3, -25) -- stage center
				if queenPlayer and queenPlayer.Character then
					local hrp = queenPlayer.Character:FindFirstChild("HumanoidRootPart")
					if hrp then queenPos = hrp.Position end
				end

				local playEffect = qRemotes:FindFirstChild("PlayEffect")
				if playEffect then
					playEffect:FireAllClients({
						effect = "confetti",
						position = queenPos,
						duration = 5,
					})
					-- Crown sparkle on the queen
					playEffect:FireAllClients({
						effect = "crownSparkle",
						targetUserId = newQueenId,
						enable = true,
					})
				end

				-- Camera: pan to throne, zoom on queen
				local cameraControl = qRemotes:FindFirstChild("CameraControl")
				if cameraControl then
					cameraControl:FireAllClients({
						action = "panTo",
						targetPosition = queenPos,
						duration = 2,
					})
					task.delay(3, function()
						cameraControl:FireAllClients({
							action = "zoomOnPlayer",
							targetUserId = newQueenId,
							distance = 6,
							duration = 2,
						})
					end)
					task.delay(8, function()
						cameraControl:FireAllClients({
							action = "unlockCamera",
						})
					end)
				end
			end
		end
	end)
end

function GameManager._sendPhaseUpdate(player)
	local remote = ReplicatedStorage.Remotes:FindFirstChild("PhaseUpdate")
	if remote then
		remote:FireClient(player, {
			phase = GameManager.currentPhase,
			previousPhase = nil,
		})
	end
end

-- ============================================================
-- SEASON INFO (for client panel)
-- ============================================================

function GameManager._sendSeasonInfo(player)
	local remote = ReplicatedStorage.Remotes:FindFirstChild("SeasonInfoResponse")
	if not remote then return end

	local queenInfo = QueenSystem.getQueenInfo()
	local activePlayers = 0
	local eliminatedPlayers = 0
	for _, data in GameManager.playerMap do
		if data.eliminated then
			eliminatedPlayers += 1
		else
			activePlayers += 1
		end
	end

	remote:FireClient(player, {
		season = GameManager.seasonData and GameManager.seasonData.season or nil,
		week = GameManager.seasonData and GameManager.seasonData.week or nil,
		day = GameManager.seasonData and GameManager.seasonData.day or nil,
		phase = GameManager.currentPhase,
		queen = queenInfo,
		activePlayers = activePlayers,
		eliminatedPlayers = eliminatedPlayers,
		eliminatedList = EliminationSystem.getEliminatedList(),
		alliances = AllianceSystem.getAllAlliances(),
	})
end

function GameManager._sendLeaderboard(player)
	local remote = ReplicatedStorage.Remotes:FindFirstChild("LeaderboardUpdate")
	if not remote then return end

	-- Build leaderboard from local player data
	local leaderboard = {}
	for userId, data in GameManager.playerMap do
		table.insert(leaderboard, {
			userId = userId,
			name = data.name,
			xp = data.xp or 0,
			eliminated = data.eliminated or false,
			fightsWon = data.fightsWon or 0,
		})
	end
	table.sort(leaderboard, function(a, b) return a.xp > b.xp end)

	-- Also try Supabase leaderboard
	if GameManager.seasonData and GameManager.seasonData.season then
		task.spawn(function()
			local supaLeaderboard = SupabaseAPI.getLeaderboard(GameManager.seasonData.season.id)
			if supaLeaderboard and #supaLeaderboard > 0 then
				remote:FireClient(player, {
					leaderboard = supaLeaderboard,
					source = "supabase",
				})
			end
		end)
	end

	remote:FireClient(player, {
		leaderboard = leaderboard,
		source = "local",
	})
end

-- ============================================================
-- TEA WALL
-- ============================================================

function GameManager.sendTeaWall(player)
	local confessions = SupabaseAPI.getConfessions(15)
	if confessions then
		local remote = ReplicatedStorage.Remotes:FindFirstChild("TeaWallUpdate")
		if remote then
			if player then
				remote:FireClient(player, confessions)
			else
				remote:FireAllClients(confessions)
			end
		end
	end
end

function GameManager.handleConfession(player, text)
	if not text or #text < 1 or #text > 280 then return end

	-- Rate limit confessions
	if not AntiCheat.rateLimit(player, "confession", 5) then
		GameManager.sendError(player, "Please wait before posting another confession.")
		return
	end

	-- Filter text through Roblox TextService
	local filteredText = GameManager.filterText(text, player)
	if not filteredText then
		GameManager.sendError(player, "Your confession could not be posted. Text filtering failed.")
		return
	end

	local gameId = "a0000000-0000-0000-0000-000000000001"
	SupabaseAPI.postConfession(gameId, "", filteredText)
	print("[TeaRoom]", player.Name, "posted:", filteredText)

	-- Award "Tea Spiller" badge for first confession
	task.spawn(function()
		BadgeSystem.awardBadge(player, "Tea Spiller")
	end)

	-- Track group goal
	ChallengeSystem.trackGroupGoal("confession", { userId = player.UserId }, GameManager)

	-- Refresh tea wall for everyone
	task.delay(1, function()
		GameManager.sendTeaWall(nil)
	end)
end

-- ============================================================
-- CHECK-IN
-- ============================================================

function GameManager.handleCheckIn(player)
	if not GameManager.seasonData or not GameManager.seasonData.active then return end

	local playerData = GameManager.playerMap[player.UserId]
	if playerData and playerData.checkedIn then
		local remote = ReplicatedStorage.Remotes:FindFirstChild("CheckInResult")
		if remote then remote:FireClient(player, { already_checked_in = true }) end
		return
	end

	local result = SupabaseAPI.checkIn(
		GameManager.seasonData.season.id,
		tostring(player.UserId)
	)

	if result then
		if playerData then playerData.checkedIn = true end

		-- Award immunity shard from check-in streak
		if result.immunity_shard_awarded then
			ImmunitySystem.awardShard(player.UserId, 1, "checkin_streak", GameManager)
		end

		-- Award "First Check-In" badge
		task.spawn(function()
			BadgeSystem.awardBadge(player, "First Check-In")
		end)

		-- Track group goal
		ChallengeSystem.trackGroupGoal("checkin", { userId = player.UserId }, GameManager)

		local remote = ReplicatedStorage.Remotes:FindFirstChild("CheckInResult")
		if remote then remote:FireClient(player, result) end
	end
end

-- ============================================================
-- DIRECTOR ANNOUNCEMENTS
-- ============================================================

function GameManager.directorAnnounce(message)
	local remote = ReplicatedStorage.Remotes:FindFirstChild("DirectorAnnounce")
	if remote then
		remote:FireAllClients(message)
	end
	print("[Director]", message)
end

-- ============================================================
-- XP AWARDING (applies Double XP multiplier from monetization)
-- ============================================================

function GameManager.awardXP(userId, amount)
	local playerData = GameManager.playerMap[userId]
	if not playerData then return end

	-- Apply XP multiplier from monetization
	local robloxPlayer = Players:GetPlayerByUserId(userId)
	local multiplier = 1
	if robloxPlayer then
		multiplier = MonetizationSystem.getXPMultiplier(robloxPlayer)
	end

	local finalXP = amount * multiplier
	playerData.xp = (playerData.xp or 0) + finalXP

	if multiplier > 1 then
		print("[GameManager] XP awarded to", playerData.name, ":", finalXP, "(", multiplier, "x multiplier)")
	end

	return finalXP
end

-- ============================================================
-- GAME LOOP — Runs every 60 seconds
-- ============================================================

function GameManager.startGameLoop()
	-- Determine tick interval (private server fast mode uses shorter intervals)
	local tickInterval = 60
	if isPrivateServer and Config.PRIVATE_SERVER and Config.PRIVATE_SERVER.customSettings and Config.PRIVATE_SERVER.customSettings.fastMode then
		tickInterval = 30
	end

	-- Main tick
	task.spawn(function()
		while true do
			task.wait(tickInterval)
			GameManager.tick()
		end
	end)

	-- Data refresh (5 minutes)
	task.spawn(function()
		while true do
			task.wait(300)
			GameManager.loadSeason()
			GameManager.sendTeaWall(nil)
		end
	end)

	-- Phase check (30 seconds) — check if day type changed from Supabase
	task.spawn(function()
		while true do
			task.wait(30)
			GameManager._checkPhaseTransition()
		end
	end)
end

function GameManager.tick()
	-- Check if any events should start
	local now = os.time()
	for _, event in GameManager.events do
		if event.status == "scheduled" then
			local eventTime = GameManager.parseISO(event.starts_at)
			if eventTime and now >= eventTime then
				GameManager.directorAnnounce("EVENT: " .. event.title .. " -- " .. (event.description or ""))
				event.status = "active"
			end
		end
	end

	-- Track fight group goal (if no active fights, day is drama-free so far)
	local activeFights = FightSystem.getActiveFights()
	if #activeFights > 0 then
		ChallengeSystem.trackGroupGoal("fight", {}, GameManager)
	end

	-- Check milestone badges periodically for all players
	for userId, data in GameManager.playerMap do
		local robloxPlayer = Players:GetPlayerByUserId(userId)
		if robloxPlayer then
			-- "Fight Club" — first fight win
			if (data.fightsWon or 0) >= 1 then
				task.spawn(function()
					BadgeSystem.awardBadge(robloxPlayer, "Fight Club")
				end)
			end

			-- Check milestone badges (Challenge Champion, Drama Queen, Mansion Veteran)
			BadgeSystem.checkMilestones(robloxPlayer, GameManager)
		end
	end
end

function GameManager._checkPhaseTransition()
	if not GameManager.seasonData or not GameManager.seasonData.day then return end

	local currentDayType = GameManager.seasonData.day.day_type
	if currentDayType and currentDayType ~= GameManager.currentPhase then
		GameManager.setPhase(currentDayType)
	end
end

function GameManager.parseISO(isoString: string): number?
	if not isoString then return nil end
	local y, m, d, h, mi, s = isoString:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
	if y then
		return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = tonumber(h), min = tonumber(mi), sec = tonumber(s) })
	end
	return nil
end

return GameManager

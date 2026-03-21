-- ============================================================
-- GAME MANAGER — Core game loop for Mansion Mayhem Roblox
-- Manages seasons, daily events, voting, elimination, rooms
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local SupabaseAPI = require(script.Parent.SupabaseAPI)
local Config = require(ReplicatedStorage.Shared.Config)

local GameManager = {}
GameManager.seasonData = nil
GameManager.events = {}
GameManager.playerMap = {} -- Roblox UserId → mansion player data
GameManager.currentPhase = "lobby"

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
		"SeasonUpdate", "EventUpdate", "TeaWallUpdate",
		"DirectorAnnounce", "VoteStart", "VoteEnd",
		"RoomAssignment", "FightAlert", "CheckInResult",
		"PostConfession", "CastVote", "RequestCheckIn",
		"ScenarioUpdate", "LeaderboardUpdate",
	}

	for _, name in events do
		-- RemoteEvents for server→client
		if name == "PostConfession" or name == "CastVote" or name == "RequestCheckIn" then
			local re = Instance.new("RemoteEvent")
			re.Name = name
			re.Parent = remotes
		else
			local re = Instance.new("RemoteEvent")
			re.Name = name
			re.Parent = remotes
		end
	end

	-- Load season data
	GameManager.loadSeason()

	-- Set up player connections
	Players.PlayerAdded:Connect(GameManager.onPlayerJoin)
	Players.PlayerRemoving:Connect(GameManager.onPlayerLeave)

	-- Handle client requests
	local postConfession = remotes:FindFirstChild("PostConfession")
	if postConfession then
		postConfession.OnServerEvent:Connect(function(player, text)
			GameManager.handleConfession(player, text)
		end)
	end

	local requestCheckIn = remotes:FindFirstChild("RequestCheckIn")
	if requestCheckIn then
		requestCheckIn.OnServerEvent:Connect(function(player)
			GameManager.handleCheckIn(player)
		end)
	end

	local castVote = remotes:FindFirstChild("CastVote")
	if castVote then
		castVote.OnServerEvent:Connect(function(player, nomineeId)
			GameManager.handleVote(player, nomineeId)
		end)
	end

	-- Start game loop
	GameManager.startGameLoop()

	print("[GameManager] Mansion Mayhem ready!")
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
	}

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

	-- Announce arrival
	GameManager.directorAnnounce(player.DisplayName .. " has entered the Mansion.")
end

function GameManager.onPlayerLeave(player)
	GameManager.playerMap[player.UserId] = nil
	print("[GameManager] Player left:", player.Name)
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

	local gameId = "a0000000-0000-0000-0000-000000000001" -- default game
	SupabaseAPI.postConfession(gameId, "", text)
	print("[TeaRoom]", player.Name, "posted:", text)

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
		local remote = ReplicatedStorage.Remotes:FindFirstChild("CheckInResult")
		if remote then remote:FireClient(player, result) end
	end
end

-- ============================================================
-- VOTING
-- ============================================================

function GameManager.handleVote(player, nomineeId)
	print("[Vote]", player.Name, "voted for", nomineeId)
	-- TODO: Record vote via Edge Function
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
-- GAME LOOP — Runs every 60 seconds
-- ============================================================

function GameManager.startGameLoop()
	task.spawn(function()
		while true do
			task.wait(60)
			GameManager.tick()
		end
	end)

	-- Refresh data every 5 minutes
	task.spawn(function()
		while true do
			task.wait(300)
			GameManager.loadSeason()
			GameManager.sendTeaWall(nil)
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
				-- Event should be active
				GameManager.directorAnnounce("EVENT: " .. event.title .. " — " .. (event.description or ""))
				event.status = "active" -- local cache update
			end
		end
	end
end

function GameManager.parseISO(isoString: string): number?
	if not isoString then return nil end
	-- Simple ISO parse (YYYY-MM-DDTHH:MM:SS)
	local y, m, d, h, mi, s = isoString:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
	if y then
		return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = tonumber(h), min = tonumber(mi), sec = tonumber(s) })
	end
	return nil
end

return GameManager

-- ============================================================
-- SUPABASE API — Server-side HTTP bridge to Supabase
-- All API calls go through the server (HttpService is server-only)
-- ============================================================

local HttpService = game:GetService("HttpService")
local Config = require(game.ReplicatedStorage.Shared.Config)

local SupabaseAPI = {}

-- Headers for all requests
local function headers()
	return {
		["apikey"] = Config.SUPABASE_KEY,
		["Authorization"] = "Bearer " .. Config.SUPABASE_KEY,
		["Content-Type"] = "application/json",
	}
end

-- GET from REST API
function SupabaseAPI.get(table_name: string, query: string?): any
	local url = Config.REST_BASE .. "/" .. table_name
	if query then url = url .. "?" .. query end

	local success, response = pcall(function()
		return HttpService:GetAsync(url, false, headers())
	end)

	if success then
		return HttpService:JSONDecode(response)
	else
		warn("[SupabaseAPI] GET failed:", table_name, response)
		return nil
	end
end

-- POST to Edge Function
function SupabaseAPI.callFunction(fn_name: string, body: any): any
	local url = Config.API_BASE .. "/" .. fn_name

	local success, response = pcall(function()
		return HttpService:PostAsync(url, HttpService:JSONEncode(body or {}), Enum.HttpContentType.ApplicationJson, false, headers())
	end)

	if success then
		return HttpService:JSONDecode(response)
	else
		warn("[SupabaseAPI] Function call failed:", fn_name, response)
		return nil
	end
end

-- POST to REST API (insert)
function SupabaseAPI.insert(table_name: string, data: any): any
	local url = Config.REST_BASE .. "/" .. table_name

	local h = headers()
	h["Prefer"] = "return=representation"

	local success, response = pcall(function()
		return HttpService:PostAsync(url, HttpService:JSONEncode(data), Enum.HttpContentType.ApplicationJson, false, h)
	end)

	if success then
		return HttpService:JSONDecode(response)
	else
		warn("[SupabaseAPI] INSERT failed:", table_name, response)
		return nil
	end
end

-- PATCH to REST API (update)
function SupabaseAPI.update(table_name: string, query: string, data: any): any
	local url = Config.REST_BASE .. "/" .. table_name .. "?" .. query

	local h = headers()
	h["Prefer"] = "return=representation"

	local success, response = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = "PATCH",
			Headers = h,
			Body = HttpService:JSONEncode(data),
		})
	end)

	if success and response then
		if type(response) == "table" and response.Body then
			local ok, decoded = pcall(function()
				return HttpService:JSONDecode(response.Body)
			end)
			if ok then return decoded end
		end
		return response
	else
		warn("[SupabaseAPI] UPDATE failed:", table_name, response)
		return nil
	end
end

-- ============================================================
-- HIGH-LEVEL API FUNCTIONS (existing)
-- ============================================================

-- Get active season status
function SupabaseAPI.getSeasonStatus(): any
	return SupabaseAPI.callFunction("season-api/status", nil)
end

-- Get bedrooms
function SupabaseAPI.getBedrooms(): any
	return SupabaseAPI.get("bedrooms", "order=room_number")
end

-- Get AI crew
function SupabaseAPI.getCrew(): any
	return SupabaseAPI.get("ai_crew", "order=crew_role")
end

-- Get today's events
function SupabaseAPI.getEvents(seasonId: string): any
	local days = SupabaseAPI.get("season_days", "season_id=eq." .. seasonId .. "&status=eq.active&select=id")
	if not days or #days == 0 then return {} end
	local dayId = days[1].id
	return SupabaseAPI.get("scheduled_events", "day_id=eq." .. dayId .. "&order=starts_at")
end

-- Get confessions for tea wall
function SupabaseAPI.getConfessions(limit: number?): any
	local l = limit or 15
	return SupabaseAPI.get("mm_confession_cards", "is_approved=eq.true&order=created_at.desc&limit=" .. l .. "&select=*,cast_members(display_name)")
end

-- Post a confession
function SupabaseAPI.postConfession(gameId: string, castMemberId: string, text: string): any
	return SupabaseAPI.insert("mm_confession_cards", {
		game_id = gameId,
		cast_member_id = castMemberId,
		confession_text = text,
		is_anonymous = false,
		is_approved = true,
	})
end

-- Get scenarios
function SupabaseAPI.getScenarios(gameId: string): any
	return SupabaseAPI.get("scenarios", "game_id=eq." .. gameId .. "&status=eq.active&order=created_at.desc")
end

-- Get cast members
function SupabaseAPI.getCastMembers(): any
	return SupabaseAPI.get("cast_members", "is_ai_player=eq.true&order=display_name")
end

-- Get leaderboard
function SupabaseAPI.getLeaderboard(seasonId: string): any
	return SupabaseAPI.get("season_players", "season_id=eq." .. seasonId .. "&status=eq.active&order=xp.desc&limit=20")
end

-- Get alliance rooms
function SupabaseAPI.getAllianceRooms(gameId: string): any
	return SupabaseAPI.get("mm_alliance_rooms", "game_id=eq." .. gameId .. "&status=eq.active&order=updated_at.desc")
end

-- Daily check-in
function SupabaseAPI.checkIn(seasonId: string, playerId: string): any
	return SupabaseAPI.callFunction("check-in", {
		season_id = seasonId,
		player_id = playerId,
		platform = "roblox",
	})
end

-- Start a fight
function SupabaseAPI.startFight(seasonId: string, aggressorId: string, defenderId: string, location: string, reason: string, intensity: number): any
	return SupabaseAPI.callFunction("fight-system/start", {
		season_id = seasonId,
		aggressor_id = aggressorId,
		defender_id = defenderId,
		fight_type = "verbal",
		location = location,
		trigger_reason = reason,
		intensity = intensity,
	})
end

-- ============================================================
-- NEW API FUNCTIONS (for all game systems)
-- ============================================================

-- Submit vote results
function SupabaseAPI.submitVote(seasonId: string, round: number, results: any, votes: any): any
	-- Store vote data via edge function or direct insert
	local voteData = {}
	for voterId, nomineeId in votes do
		table.insert(voteData, {
			voter_id = tostring(voterId),
			nominee_id = tostring(nomineeId),
			round = round,
		})
	end

	return SupabaseAPI.callFunction("season-api/vote", {
		season_id = seasonId,
		round = round,
		results = results,
		votes = voteData,
	})
end

-- Get vote results
function SupabaseAPI.getVoteResults(seasonId: string, round: number?): any
	local query = "season_id=eq." .. seasonId
	if round then
		query = query .. "&round=eq." .. round
	end
	query = query .. "&order=vote_count.desc"
	return SupabaseAPI.get("vote_results", query)
end

-- Eliminate a player
function SupabaseAPI.eliminatePlayer(seasonId: string, playerId: string, weekNumber: number): any
	return SupabaseAPI.update(
		"season_players",
		"season_id=eq." .. seasonId .. "&player_id=eq." .. playerId,
		{
			status = "eliminated",
			eliminated_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
			elimination_week = weekNumber,
		}
	)
end

-- Create/update alliance
function SupabaseAPI.createAlliance(seasonId: string, allianceId: string, allianceName: string, members: any): any
	local memberIds = {}
	for memberId in members do
		table.insert(memberIds, tostring(memberId))
	end

	return SupabaseAPI.insert("mm_alliance_rooms", {
		season_id = seasonId,
		alliance_name = allianceName,
		member_ids = memberIds,
		status = "active",
	})
end

-- Crown queen
function SupabaseAPI.crownQueen(seasonId: string, playerId: string, weekNumber: number): any
	-- Get current week ID
	local weeks = SupabaseAPI.get("season_weeks", "season_id=eq." .. seasonId .. "&status=eq.active&select=id")
	local weekId = weeks and #weeks > 0 and weeks[1].id or nil

	if weekId then
		return SupabaseAPI.insert("queen_reigns", {
			season_id = seasonId,
			player_id = playerId,
			week_id = weekId,
			crowned_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		})
	end

	return nil
end

-- Complete a challenge
function SupabaseAPI.completeChallenge(seasonId: string, playerId: string, challengeId: string, xpEarned: number): any
	return SupabaseAPI.insert("challenge_completions", {
		season_id = seasonId,
		player_id = playerId,
		challenge_id = challengeId,
		xp_earned = xpEarned,
		completed_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
	})
end

-- Use immunity token
function SupabaseAPI.useImmunity(seasonId: string, playerId: string): any
	-- Decrement immunity_shards in season_players
	local player = SupabaseAPI.get("season_players", "season_id=eq." .. seasonId .. "&player_id=eq." .. playerId .. "&select=immunity_shards")
	if player and #player > 0 then
		local currentShards = player[1].immunity_shards or 0
		return SupabaseAPI.update(
			"season_players",
			"season_id=eq." .. seasonId .. "&player_id=eq." .. playerId,
			{
				immunity_shards = math.max(0, currentShards - 3),
			}
		)
	end
	return nil
end

-- Room assignment
function SupabaseAPI.assignRoom(seasonId: string, action: string, params: any): any
	local body = params or {}
	body.action = action
	body.season_id = seasonId
	return SupabaseAPI.callFunction("room-assignments", body)
end

return SupabaseAPI

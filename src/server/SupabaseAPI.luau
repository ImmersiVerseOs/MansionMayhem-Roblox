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

-- ============================================================
-- HIGH-LEVEL API FUNCTIONS
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

return SupabaseAPI

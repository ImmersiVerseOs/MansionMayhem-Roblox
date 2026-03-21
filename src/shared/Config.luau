-- ============================================================
-- MANSION MAYHEM ROBLOX — SHARED CONFIG
-- Same Supabase backend as the App + VR
-- ============================================================

local Config = {}

-- Supabase connection (same database as web app)
Config.SUPABASE_URL = "https://fpxbhqibimekjhlumnmc.supabase.co"
Config.SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZweGJocWliaW1la2pobHVtbm1jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEwMjUwODYsImV4cCI6MjA4NjYwMTA4Nn0.0BmbaObOERMZ5r4znb5BQbrGpB5lE5Fq6KnEzxA0YhY"
Config.API_BASE = Config.SUPABASE_URL .. "/functions/v1"
Config.REST_BASE = Config.SUPABASE_URL .. "/rest/v1"

-- Game settings
Config.MAX_PLAYERS = 20
Config.BEDROOMS = 10
Config.PLAYERS_PER_ROOM = 2

-- Room names (matching the database)
Config.BEDROOM_NAMES = {
	[1]  = { name = "The Crown Suite",  color = Color3.fromHex("#FFD700"), master = true,  exile = false },
	[2]  = { name = "Velvet Noir",      color = Color3.fromHex("#9B30FF"), master = false, exile = false },
	[3]  = { name = "Neon Paradise",    color = Color3.fromHex("#FF1493"), master = false, exile = false },
	[4]  = { name = "The Ice Box",      color = Color3.fromHex("#00BFFF"), master = false, exile = false },
	[5]  = { name = "Jungle Room",      color = Color3.fromHex("#1B5E3B"), master = false, exile = false },
	[6]  = { name = "The War Room",     color = Color3.fromHex("#E94560"), master = false, exile = false },
	[7]  = { name = "Cloud Nine",       color = Color3.fromHex("#F8F4F0"), master = false, exile = false },
	[8]  = { name = "The Vault",        color = Color3.fromHex("#C0C0C0"), master = false, exile = false },
	[9]  = { name = "Midnight Garden",  color = Color3.fromHex("#4A0E2E"), master = false, exile = false },
	[10] = { name = "The Dog House",    color = Color3.fromHex("#666666"), master = false, exile = true },
}

-- UI Colors
Config.Colors = {
	Background = Color3.fromHex("#0A0610"),
	Surface    = Color3.fromHex("#1A0E22"),
	Card       = Color3.fromHex("#221430"),
	Border     = Color3.fromHex("#2D1B4E"),
	Pink       = Color3.fromHex("#FF1493"),
	Gold       = Color3.fromHex("#FFD700"),
	Purple     = Color3.fromHex("#9B30FF"),
	Blue       = Color3.fromHex("#00BFFF"),
	Red        = Color3.fromHex("#E94560"),
	Green      = Color3.fromHex("#22C55E"),
	Text       = Color3.fromHex("#F8F4F0"),
	TextMuted  = Color3.fromHex("#808080"),
}

return Config

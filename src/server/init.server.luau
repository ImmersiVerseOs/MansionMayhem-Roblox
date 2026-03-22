-- ============================================================
-- MANSION MAYHEM ROBLOX — Server Entry Point
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Visual startup indicator (shows in 3D world even without Output window)
local function showMessage(text)
	local msg = Instance.new("Message")
	msg.Text = text
	msg.Parent = workspace
	task.delay(3, function() msg:Destroy() end)
end

showMessage("Mansion Mayhem — Loading...")

-- Wait for Rojo-synced shared modules (with timeout)
local shared = ReplicatedStorage:WaitForChild("Shared", 10)
if not shared then
	showMessage("ERROR: Shared folder not found! Is Rojo connected?")
	-- Create fallback Config inline so mansion still builds
	shared = Instance.new("Folder")
	shared.Name = "Shared"
	shared.Parent = ReplicatedStorage

	local configModule = Instance.new("ModuleScript")
	configModule.Name = "Config"
	configModule.Source = [[
local Config = {}
Config.SUPABASE_URL = ""
Config.SUPABASE_KEY = ""
Config.API_BASE = ""
Config.REST_BASE = ""
Config.MAX_PLAYERS = 20
Config.BEDROOMS = 10
Config.PLAYERS_PER_ROOM = 2
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
Config.Colors = {
	Background = Color3.fromHex("#0A0610"),
	Pink = Color3.fromHex("#FF1493"),
	Gold = Color3.fromHex("#FFD700"),
	Purple = Color3.fromHex("#9B30FF"),
}
return Config
]]
	configModule.Parent = shared
else
	shared:WaitForChild("Config", 5)
end

-- Persistent message that stays on screen
local function showPersist(text)
	local existing = workspace:FindFirstChild("DebugMsg")
	if existing then existing:Destroy() end
	local msg = Instance.new("Message")
	msg.Name = "DebugMsg"
	msg.Text = text
	msg.Parent = workspace
end

showPersist("Step 1: Requiring MansionBuilder...")
task.wait(0.1)

local ok1, err1 = pcall(function()
	local MansionBuilder = require(script.MansionBuilder)
	showPersist("Step 2: Building mansion...")
	task.wait(0.1)
	MansionBuilder.build()
	showPersist("Step 2b: Adding lights...")
	task.wait(0.1)
	local mansion = workspace:FindFirstChild("Mansion")
	if mansion then
		MansionBuilder.addAllLights(mansion)
	end
end)

if not ok1 then
	showPersist("MANSION BUILD ERROR: " .. tostring(err1))
	task.wait(30)
	return
end

showPersist("Step 3: Starting GameManager...")
task.wait(0.1)

local ok2, err2 = pcall(function()
	local GameManager = require(script.GameManager)
	GameManager.init()
end)

if not ok2 then
	showPersist("GAME MANAGER ERROR: " .. tostring(err2))
	task.wait(30)
	return
end

showPersist("Step 4: Starting MonetizationSystem...")
task.wait(0.1)

local ok3, err3 = pcall(function()
	local MonetizationSystem = require(script.MonetizationSystem)
	MonetizationSystem.init()
end)

if not ok3 then
	showPersist("MONETIZATION ERROR: " .. tostring(err3))
	task.wait(5)
	-- Non-fatal: continue without monetization
end

showPersist("MANSION OF MAYHEM — READY!")
task.wait(5)
local dm = workspace:FindFirstChild("DebugMsg")
if dm then dm:Destroy() end

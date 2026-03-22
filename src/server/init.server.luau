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

-- Wait for shared modules (baked in by rojo build)
local shared = ReplicatedStorage:WaitForChild("Shared", 10)
if not shared then
	showMessage("ERROR: Shared folder not found! Rebuild with rojo build.")
	task.wait(30)
	return
end
shared:WaitForChild("Config", 5)

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

showPersist("Step 2c: Building Hollywood Bus Station...")
task.wait(0.1)

local ok1b, err1b = pcall(function()
	local BusSystem = require(script.BusSystem)
	local mansion = workspace:FindFirstChild("Mansion")
	BusSystem.init(mansion)
end)

if not ok1b then
	showPersist("BUS SYSTEM ERROR: " .. tostring(err1b))
	task.wait(5)
	-- Non-fatal: continue without bus system
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

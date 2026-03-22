-- ============================================================
-- MANSION MAYHEM ROBLOX — Client Entry Point
-- Initializes all UI systems and handles server communication
-- ============================================================

local LoadingScreen = require(script.Parent.LoadingScreen)
local MainUI = require(script.Parent.MainUI)
local ParticleEffects = require(script.Parent.ParticleEffects)
local CinematicCamera = require(script.Parent.CinematicCamera)
local TutorialSystem = require(script.Parent.TutorialSystem)

-- Show loading screen FIRST (before anything else)
LoadingScreen.show()

-- Initialize UI after character loads
local player = game.Players.LocalPlayer
player.CharacterAdded:Wait()
task.wait(1)

-- Initialize core systems
MainUI.init()
ParticleEffects.init()
CinematicCamera.init()

-- Store references for MainUI event handlers
MainUI._particleEffects = ParticleEffects
MainUI._cinematicCamera = CinematicCamera

-- Hide loading screen with fade now that everything is ready
LoadingScreen.hide()

-- Show tutorial for first-time players
if TutorialSystem.shouldShow() then
	task.wait(0.5)
	TutorialSystem.show()
end

print("[Client] Mansion Mayhem UI ready for", player.DisplayName)

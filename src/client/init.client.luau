-- ============================================================
-- MANSION MAYHEM ROBLOX — Client Entry Point
-- ============================================================

local MainUI = require(script.Parent.MainUI)

-- Initialize UI after character loads
local player = game.Players.LocalPlayer
player.CharacterAdded:Wait()
task.wait(1)

MainUI.init()

print("[Client] Mansion Mayhem UI ready for", player.DisplayName)

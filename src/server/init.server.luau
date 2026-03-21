-- ============================================================
-- MANSION MAYHEM ROBLOX — Server Entry Point
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for shared modules
local shared = Instance.new("Folder")
shared.Name = "Shared"
shared.Parent = ReplicatedStorage

-- Copy shared config to ReplicatedStorage
-- (In Roblox Studio, you'd organize this in the Explorer)

print("==========================================")
print("  MANSION OF MAYHEM — ROBLOX EDITION")
print("  Reality TV meets gaming. 20 players.")
print("  10 bedrooms. 1 survivor.")
print("==========================================")

-- Build the mansion
local MansionBuilder = require(script.Parent.MansionBuilder)
MansionBuilder.build()

-- Start game systems
local GameManager = require(script.Parent.GameManager)
GameManager.init()

print("[Server] All systems online. The Mansion awaits.")

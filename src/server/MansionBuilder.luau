-- ============================================================
-- MANSION BUILDER — Creates the 3D mansion environment
-- Run this once on server start to build the mansion
-- ============================================================

local Config = require(game.ReplicatedStorage.Shared.Config)

local MansionBuilder = {}

local FLOOR_Y = 0
local FLOOR2_Y = 20
local WALL_HEIGHT = 14
local ROOM_SIZE = 30

-- Material colors
local MARBLE = Color3.fromHex("#1A0E14")
local WALL_COLOR = Color3.fromHex("#1A0E18")
local GOLD = Color3.fromHex("#D4A847")
local NEON_PINK = Color3.fromHex("#FF1493")
local DARK = Color3.fromHex("#0A0610")

function MansionBuilder.build()
	local mansion = Instance.new("Folder")
	mansion.Name = "Mansion"
	mansion.Parent = workspace

	-- Ground Floor
	MansionBuilder.buildLobby(mansion)
	MansionBuilder.buildCorridor(mansion)
	MansionBuilder.buildLivingRoom(mansion)
	MansionBuilder.buildKitchen(mansion)
	MansionBuilder.buildDramaRoom(mansion)
	MansionBuilder.buildConfessionBooth(mansion)
	MansionBuilder.buildEliminationRoom(mansion)
	MansionBuilder.buildElevator(mansion)

	-- Upper Floor — Bedrooms
	MansionBuilder.buildBedroomFloor(mansion)

	-- Rooftop
	MansionBuilder.buildRooftop(mansion)

	-- Lighting
	MansionBuilder.setupLighting()

	print("[MansionBuilder] Mansion built!")
	return mansion
end

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================

function MansionBuilder.createPart(parent, name, pos, size, color, mat, anchored)
	local part = Instance.new("Part")
	part.Name = name
	part.Position = pos
	part.Size = size
	part.Color = color or WALL_COLOR
	part.Material = mat or Enum.Material.SmoothPlastic
	part.Anchored = anchored ~= false
	part.CanCollide = true
	part.Parent = parent
	return part
end

function MansionBuilder.createNeon(parent, name, pos, size, color)
	local part = MansionBuilder.createPart(parent, name, pos, size, color or NEON_PINK, Enum.Material.Neon)
	return part
end

function MansionBuilder.createSign(parent, text, pos, size, color)
	local part = Instance.new("Part")
	part.Name = "Sign_" .. text
	part.Position = pos
	part.Size = Vector3.new(size or 8, 3, 0.2)
	part.Color = DARK
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.Parent = parent

	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.Parent = part

	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(1, 0, 1, 0)
	tl.BackgroundTransparency = 1
	tl.Text = text
	tl.TextColor3 = color or GOLD
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamBold
	tl.Parent = sg

	return part
end

-- ============================================================
-- ROOMS
-- ============================================================

function MansionBuilder.buildLobby(parent)
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = parent

	-- Floor
	MansionBuilder.createPart(lobby, "Floor", Vector3.new(20, -0.5, 0), Vector3.new(40, 1, 60), MARBLE, Enum.Material.Marble)
	-- Ceiling
	MansionBuilder.createPart(lobby, "Ceiling", Vector3.new(20, WALL_HEIGHT, 0), Vector3.new(40, 1, 60), DARK)
	-- Walls
	MansionBuilder.createPart(lobby, "WallWest", Vector3.new(0, WALL_HEIGHT/2, 0), Vector3.new(1, WALL_HEIGHT, 60), WALL_COLOR)
	MansionBuilder.createPart(lobby, "WallNorth", Vector3.new(20, WALL_HEIGHT/2, 30), Vector3.new(40, WALL_HEIGHT, 1), WALL_COLOR)
	MansionBuilder.createPart(lobby, "WallSouth", Vector3.new(20, WALL_HEIGHT/2, -30), Vector3.new(40, WALL_HEIGHT, 1), WALL_COLOR)

	-- Neon accents
	MansionBuilder.createNeon(lobby, "NeonFloorN", Vector3.new(20, 0.1, 29), Vector3.new(38, 0.2, 0.3), NEON_PINK)
	MansionBuilder.createNeon(lobby, "NeonFloorS", Vector3.new(20, 0.1, -29), Vector3.new(38, 0.2, 0.3), NEON_PINK)
	MansionBuilder.createNeon(lobby, "NeonCeiling", Vector3.new(20, WALL_HEIGHT - 0.2, 0), Vector3.new(38, 0.2, 0.3), GOLD)

	-- Sign
	MansionBuilder.createSign(lobby, "MANSION OF MAYHEM", Vector3.new(1, 10, 0), 12, NEON_PINK)
	MansionBuilder.createSign(lobby, "The Lobby", Vector3.new(1, 7, 0), 8, GOLD)

	-- Spawn point
	local spawn = Instance.new("SpawnLocation")
	spawn.Position = Vector3.new(20, 1, 0)
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Parent = lobby
end

function MansionBuilder.buildCorridor(parent)
	local corr = Instance.new("Folder")
	corr.Name = "Corridor"
	corr.Parent = parent

	-- Long corridor connecting rooms
	MansionBuilder.createPart(corr, "Floor", Vector3.new(100, -0.5, 0), Vector3.new(160, 1, 20), MARBLE, Enum.Material.Marble)
	MansionBuilder.createPart(corr, "Ceiling", Vector3.new(100, WALL_HEIGHT, 0), Vector3.new(160, 1, 20), DARK)
	-- Gold baseboards
	MansionBuilder.createNeon(corr, "BaseN", Vector3.new(100, 0.3, 9.5), Vector3.new(160, 0.5, 0.2), GOLD)
	MansionBuilder.createNeon(corr, "BaseS", Vector3.new(100, 0.3, -9.5), Vector3.new(160, 0.5, 0.2), GOLD)
end

function MansionBuilder.buildLivingRoom(parent)
	local room = Instance.new("Folder")
	room.Name = "LivingRoom"
	room.Parent = parent

	local cx, cz = 55, 25
	MansionBuilder.createPart(room, "Floor", Vector3.new(cx, -0.5, cz), Vector3.new(ROOM_SIZE, 1, ROOM_SIZE), MARBLE, Enum.Material.Marble)
	MansionBuilder.createPart(room, "Ceiling", Vector3.new(cx, WALL_HEIGHT, cz), Vector3.new(ROOM_SIZE, 1, ROOM_SIZE), DARK)
	MansionBuilder.createPart(room, "WallBack", Vector3.new(cx, WALL_HEIGHT/2, cz + ROOM_SIZE/2), Vector3.new(ROOM_SIZE, WALL_HEIGHT, 1), WALL_COLOR)
	MansionBuilder.createPart(room, "WallLeft", Vector3.new(cx - ROOM_SIZE/2, WALL_HEIGHT/2, cz), Vector3.new(1, WALL_HEIGHT, ROOM_SIZE), WALL_COLOR)
	MansionBuilder.createPart(room, "WallRight", Vector3.new(cx + ROOM_SIZE/2, WALL_HEIGHT/2, cz), Vector3.new(1, WALL_HEIGHT, ROOM_SIZE), WALL_COLOR)
	MansionBuilder.createSign(room, "THE LIVING ROOM", Vector3.new(cx, WALL_HEIGHT - 2, cz - ROOM_SIZE/2 + 1), 10, NEON_PINK)

	-- Tea Wall (SurfaceGui for confessions)
	local teaWall = MansionBuilder.createPart(room, "TeaWall", Vector3.new(cx, 7, cz + ROOM_SIZE/2 - 0.5), Vector3.new(20, 10, 0.5), Color3.fromHex("#130D1A"))
	MansionBuilder.createSign(room, "TEA WALL", Vector3.new(cx, 12.5, cz + ROOM_SIZE/2 - 0.3), 8, Color3.fromHex("#FFD700"))
end

function MansionBuilder.buildKitchen(parent)
	local room = Instance.new("Folder")
	room.Name = "Kitchen"
	room.Parent = parent
	local cx, cz = 95, 25
	MansionBuilder.createPart(room, "Floor", Vector3.new(cx, -0.5, cz), Vector3.new(ROOM_SIZE, 1, ROOM_SIZE), Color3.fromHex("#1a0e14"), Enum.Material.Marble)
	MansionBuilder.createPart(room, "Ceiling", Vector3.new(cx, WALL_HEIGHT, cz), Vector3.new(ROOM_SIZE, 1, ROOM_SIZE), DARK)
	MansionBuilder.createPart(room, "WallBack", Vector3.new(cx, WALL_HEIGHT/2, cz + ROOM_SIZE/2), Vector3.new(ROOM_SIZE, WALL_HEIGHT, 1), WALL_COLOR)
	MansionBuilder.createPart(room, "WallLeft", Vector3.new(cx - ROOM_SIZE/2, WALL_HEIGHT/2, cz), Vector3.new(1, WALL_HEIGHT, ROOM_SIZE), WALL_COLOR)
	MansionBuilder.createPart(room, "WallRight", Vector3.new(cx + ROOM_SIZE/2, WALL_HEIGHT/2, cz), Vector3.new(1, WALL_HEIGHT, ROOM_SIZE), WALL_COLOR)
	MansionBuilder.createSign(room, "THE KITCHEN", Vector3.new(cx, WALL_HEIGHT - 2, cz - ROOM_SIZE/2 + 1), 10, GOLD)
end

function MansionBuilder.buildDramaRoom(parent)
	local room = Instance.new("Folder")
	room.Name = "DramaRoom"
	room.Parent = parent
	local cx, cz = 55, -25
	MansionBuilder.createPart(room, "Floor", Vector3.new(cx, -0.5, cz), Vector3.new(ROOM_SIZE, 1, ROOM_SIZE), MARBLE, Enum.Material.Marble)
	MansionBuilder.createPart(room, "Ceiling", Vector3.new(cx, WALL_HEIGHT, cz), Vector3.new(ROOM_SIZE, 1, ROOM_SIZE), DARK)
	MansionBuilder.createPart(room, "WallBack", Vector3.new(cx, WALL_HEIGHT/2, cz - ROOM_SIZE/2), Vector3.new(ROOM_SIZE, WALL_HEIGHT, 1), WALL_COLOR)
	MansionBuilder.createPart(room, "WallLeft", Vector3.new(cx - ROOM_SIZE/2, WALL_HEIGHT/2, cz), Vector3.new(1, WALL_HEIGHT, ROOM_SIZE), WALL_COLOR)
	MansionBuilder.createPart(room, "WallRight", Vector3.new(cx + ROOM_SIZE/2, WALL_HEIGHT/2, cz), Vector3.new(1, WALL_HEIGHT, ROOM_SIZE), WALL_COLOR)
	MansionBuilder.createSign(room, "THE DRAMA ROOM", Vector3.new(cx, WALL_HEIGHT - 2, cz + ROOM_SIZE/2 - 1), 10, Color3.fromHex("#E94560"))
end

function MansionBuilder.buildConfessionBooth(parent)
	local room = Instance.new("Folder")
	room.Name = "ConfessionBooth"
	room.Parent = parent
	local cx, cz = 95, -25
	MansionBuilder.createPart(room, "Floor", Vector3.new(cx, -0.5, cz), Vector3.new(ROOM_SIZE, 1, ROOM_SIZE), MARBLE, Enum.Material.Marble)
	MansionBuilder.createPart(room, "Ceiling", Vector3.new(cx, WALL_HEIGHT, cz), Vector3.new(ROOM_SIZE, 1, ROOM_SIZE), DARK)
	MansionBuilder.createPart(room, "WallBack", Vector3.new(cx, WALL_HEIGHT/2, cz - ROOM_SIZE/2), Vector3.new(ROOM_SIZE, WALL_HEIGHT, 1), WALL_COLOR)
	MansionBuilder.createPart(room, "WallLeft", Vector3.new(cx - ROOM_SIZE/2, WALL_HEIGHT/2, cz), Vector3.new(1, WALL_HEIGHT, ROOM_SIZE), WALL_COLOR)
	MansionBuilder.createPart(room, "WallRight", Vector3.new(cx + ROOM_SIZE/2, WALL_HEIGHT/2, cz), Vector3.new(1, WALL_HEIGHT, ROOM_SIZE), WALL_COLOR)
	MansionBuilder.createSign(room, "CONFESSION BOOTH", Vector3.new(cx, WALL_HEIGHT - 2, cz + ROOM_SIZE/2 - 1), 10, Color3.fromHex("#9B30FF"))
	-- Purple ambient
	MansionBuilder.createNeon(room, "PurpleGlow", Vector3.new(cx, 1, cz), Vector3.new(10, 0.3, 10), Color3.fromHex("#9B30FF"))
end

function MansionBuilder.buildEliminationRoom(parent)
	local room = Instance.new("Folder")
	room.Name = "EliminationRoom"
	room.Parent = parent
	local cx, cz = 135, -25
	MansionBuilder.createPart(room, "Floor", Vector3.new(cx, -0.5, cz), Vector3.new(ROOM_SIZE+10, 1, ROOM_SIZE+10), Color3.fromHex("#080510"), Enum.Material.Marble)
	MansionBuilder.createPart(room, "Ceiling", Vector3.new(cx, WALL_HEIGHT, cz), Vector3.new(ROOM_SIZE+10, 1, ROOM_SIZE+10), DARK)
	MansionBuilder.createPart(room, "WallBack", Vector3.new(cx, WALL_HEIGHT/2, cz - (ROOM_SIZE+10)/2), Vector3.new(ROOM_SIZE+10, WALL_HEIGHT, 1), Color3.fromHex("#0a0610"))
	MansionBuilder.createPart(room, "WallLeft", Vector3.new(cx - (ROOM_SIZE+10)/2, WALL_HEIGHT/2, cz), Vector3.new(1, WALL_HEIGHT, ROOM_SIZE+10), Color3.fromHex("#0a0610"))
	MansionBuilder.createPart(room, "WallRight", Vector3.new(cx + (ROOM_SIZE+10)/2, WALL_HEIGHT/2, cz), Vector3.new(1, WALL_HEIGHT, ROOM_SIZE+10), Color3.fromHex("#0a0610"))
	MansionBuilder.createSign(room, "ELIMINATION", Vector3.new(cx, WALL_HEIGHT - 2, cz + (ROOM_SIZE+10)/2 - 1), 12, Color3.fromHex("#E94560"))

	-- Circular stage
	local stage = Instance.new("Part")
	stage.Name = "Stage"
	stage.Shape = Enum.PartType.Cylinder
	stage.Size = Vector3.new(1, 20, 20)
	stage.Position = Vector3.new(cx, 0.5, cz)
	stage.Orientation = Vector3.new(0, 0, 90)
	stage.Color = Color3.fromHex("#1a0a12")
	stage.Material = Enum.Material.Marble
	stage.Anchored = true
	stage.Parent = room

	-- Neon ring
	MansionBuilder.createNeon(room, "StageRing", Vector3.new(cx, 0.8, cz), Vector3.new(22, 0.3, 22), NEON_PINK)
end

function MansionBuilder.buildElevator(parent)
	local elev = Instance.new("Folder")
	elev.Name = "Elevator"
	elev.Parent = parent
	MansionBuilder.createPart(elev, "Platform", Vector3.new(170, -0.5, 0), Vector3.new(15, 1, 15), Color3.fromHex("#F0E8DC"), Enum.Material.Marble)
	MansionBuilder.createPart(elev, "ShaftBack", Vector3.new(170, 20, 8), Vector3.new(15, 50, 0.5), Color3.new(0.1,0.1,0.1))
	MansionBuilder.createPart(elev, "ShaftLeft", Vector3.new(163, 20, 0), Vector3.new(0.5, 50, 15), Color3.new(0.1,0.1,0.1))
	MansionBuilder.createSign(elev, "ELEVATOR", Vector3.new(170, 12, -7), 6, GOLD)
end

-- ============================================================
-- BEDROOMS (Upper Floor)
-- ============================================================

function MansionBuilder.buildBedroomFloor(parent)
	local floor2 = Instance.new("Folder")
	floor2.Name = "BedroomFloor"
	floor2.Parent = parent

	-- Upper corridor
	MansionBuilder.createPart(floor2, "Floor", Vector3.new(100, FLOOR2_Y - 0.5, 0), Vector3.new(140, 1, 15), MARBLE, Enum.Material.Marble)
	MansionBuilder.createPart(floor2, "Ceiling", Vector3.new(100, FLOOR2_Y + WALL_HEIGHT, 0), Vector3.new(140, 1, 15), DARK)
	MansionBuilder.createSign(floor2, "BEDROOMS", Vector3.new(35, FLOOR2_Y + 8, 0), 10, GOLD)

	-- Build 10 bedrooms (5 north, 5 south)
	for i = 1, 10 do
		MansionBuilder.buildBedroom(floor2, i)
	end
end

function MansionBuilder.buildBedroom(parent, roomNum)
	local config = Config.BEDROOM_NAMES[roomNum]
	if not config then return end

	local room = Instance.new("Folder")
	room.Name = "Bedroom_" .. roomNum
	room.Parent = parent

	-- Position: rooms 1-5 north, 6-10 south
	local col = roomNum <= 5 and (roomNum - 1) or (roomNum - 6)
	local side = roomNum <= 5 and 1 or -1
	local cx = 40 + col * 30
	local cz = side * 22

	-- Room shell
	local floorColor = config.exile and Color3.new(0.05, 0.05, 0.05) or MARBLE
	MansionBuilder.createPart(room, "Floor", Vector3.new(cx, FLOOR2_Y - 0.5, cz), Vector3.new(25, 1, 20), floorColor, Enum.Material.Marble)
	MansionBuilder.createPart(room, "Ceiling", Vector3.new(cx, FLOOR2_Y + WALL_HEIGHT, cz), Vector3.new(25, 1, 20), DARK)
	MansionBuilder.createPart(room, "WallBack", Vector3.new(cx, FLOOR2_Y + WALL_HEIGHT/2, cz + side * 10), Vector3.new(25, WALL_HEIGHT, 1), WALL_COLOR)
	MansionBuilder.createPart(room, "WallLeft", Vector3.new(cx - 12.5, FLOOR2_Y + WALL_HEIGHT/2, cz), Vector3.new(1, WALL_HEIGHT, 20), WALL_COLOR)
	MansionBuilder.createPart(room, "WallRight", Vector3.new(cx + 12.5, FLOOR2_Y + WALL_HEIGHT/2, cz), Vector3.new(1, WALL_HEIGHT, 20), WALL_COLOR)

	-- Room name sign
	MansionBuilder.createSign(room, config.name, Vector3.new(cx, FLOOR2_Y + WALL_HEIGHT - 2, cz - side * 9), 8, config.color)
	-- Room number
	MansionBuilder.createSign(room, "#" .. roomNum, Vector3.new(cx - 10, FLOOR2_Y + 5, cz - side * 9), 3, GOLD)

	-- Accent neon strip
	MansionBuilder.createNeon(room, "Accent", Vector3.new(cx, FLOOR2_Y + 0.1, cz + side * 9), Vector3.new(23, 0.2, 0.3), config.color)

	-- Two beds
	if not config.exile then
		-- Bed 1
		MansionBuilder.createPart(room, "Bed1", Vector3.new(cx - 5, FLOOR2_Y + 1.5, cz + side * 5), Vector3.new(5, 3, 8), config.color)
		MansionBuilder.createPart(room, "Pillow1", Vector3.new(cx - 5, FLOOR2_Y + 3.2, cz + side * 8), Vector3.new(3, 0.5, 2), Color3.new(1, 1, 1))
		-- Bed 2
		MansionBuilder.createPart(room, "Bed2", Vector3.new(cx + 5, FLOOR2_Y + 1.5, cz + side * 5), Vector3.new(5, 3, 8), config.color)
		MansionBuilder.createPart(room, "Pillow2", Vector3.new(cx + 5, FLOOR2_Y + 3.2, cz + side * 8), Vector3.new(3, 0.5, 2), Color3.new(1, 1, 1))
		-- Nightstand
		MansionBuilder.createPart(room, "Nightstand", Vector3.new(cx, FLOOR2_Y + 1, cz + side * 5), Vector3.new(2, 2, 2), GOLD)
	else
		-- Dog House: thin mattresses on floor
		MansionBuilder.createPart(room, "Mattress1", Vector3.new(cx - 5, FLOOR2_Y + 0.3, cz + side * 4), Vector3.new(4, 0.5, 7), Color3.new(0.2, 0.2, 0.2))
		MansionBuilder.createPart(room, "Mattress2", Vector3.new(cx + 5, FLOOR2_Y + 0.3, cz + side * 4), Vector3.new(4, 0.5, 7), Color3.new(0.2, 0.2, 0.2))
		MansionBuilder.createSign(room, "You know what you did.", Vector3.new(cx, FLOOR2_Y + 5, cz + side * 9), 8, Color3.new(0.3, 0.3, 0.3))
	end

	-- Crown for master suite
	if config.master then
		MansionBuilder.createNeon(room, "CrownGlow", Vector3.new(cx, FLOOR2_Y + WALL_HEIGHT - 1, cz), Vector3.new(8, 0.3, 8), GOLD)
	end
end

-- ============================================================
-- ROOFTOP
-- ============================================================

function MansionBuilder.buildRooftop(parent)
	local rooftop = Instance.new("Folder")
	rooftop.Name = "Rooftop"
	rooftop.Parent = parent
	local ry = FLOOR2_Y + WALL_HEIGHT + 2

	MansionBuilder.createPart(rooftop, "Floor", Vector3.new(100, ry - 0.5, 0), Vector3.new(100, 1, 100), Color3.fromHex("#1a1520"), Enum.Material.Concrete)
	-- Low walls
	MansionBuilder.createPart(rooftop, "WallN", Vector3.new(100, ry + 1.5, 50), Vector3.new(100, 3, 1), WALL_COLOR)
	MansionBuilder.createPart(rooftop, "WallS", Vector3.new(100, ry + 1.5, -50), Vector3.new(100, 3, 1), WALL_COLOR)
	MansionBuilder.createPart(rooftop, "WallE", Vector3.new(150, ry + 1.5, 0), Vector3.new(1, 3, 100), WALL_COLOR)
	MansionBuilder.createPart(rooftop, "WallW", Vector3.new(50, ry + 1.5, 0), Vector3.new(1, 3, 100), WALL_COLOR)
	MansionBuilder.createSign(rooftop, "THE ROOFTOP", Vector3.new(100, ry + 8, -49), 12, GOLD)

	-- Pool (blue neon circle)
	local pool = Instance.new("Part")
	pool.Name = "Pool"
	pool.Shape = Enum.PartType.Cylinder
	pool.Size = Vector3.new(2, 30, 30)
	pool.Position = Vector3.new(120, ry + 0.5, 0)
	pool.Orientation = Vector3.new(0, 0, 90)
	pool.Color = Color3.fromHex("#00BFFF")
	pool.Material = Enum.Material.Neon
	pool.Transparency = 0.3
	pool.Anchored = true
	pool.Parent = rooftop
end

-- ============================================================
-- LIGHTING
-- ============================================================

function MansionBuilder.setupLighting()
	local lighting = game:GetService("Lighting")
	lighting.ClockTime = 0 -- Nighttime
	lighting.Ambient = Color3.fromHex("#0A0610")
	lighting.OutdoorAmbient = Color3.fromHex("#0A0610")
	lighting.Brightness = 0
	lighting.FogEnd = 500
	lighting.FogColor = Color3.fromHex("#0A0610")

	-- Bloom for neon glow
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.3
	bloom.Size = 20
	bloom.Threshold = 0.8
	bloom.Parent = lighting

	-- Color correction for mood
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.2
	cc.TintColor = Color3.fromHex("#F0E0FF")
	cc.Parent = lighting
end

return MansionBuilder

-- ============================================================
-- MANSION BUILDER — Luxury Reality TV Mansion
-- Love Island Villa x Luxury Penthouse aesthetic
-- Fully enclosed mansion with outer shell, roof, doorways
-- ============================================================

local TweenService = game:GetService("TweenService")
local Config = require(game.ReplicatedStorage.Shared.Config)

local MansionBuilder = {}

-- ============================================================
-- CONSTANTS
-- ============================================================

local FLOOR_Y = 0
local FLOOR2_Y = 22
local WALL_HEIGHT = 16
local ROOM_SIZE = 45

-- Mansion outer bounds (used for outer shell)
-- Ground floor spans from lobby (X=-5) to elevator (X=210), Z from -60 to 55
local OUTER_X_MIN = -10
local OUTER_X_MAX = 210
local OUTER_Z_MIN = -62
local OUTER_Z_MAX = 55
local OUTER_WIDTH = OUTER_X_MAX - OUTER_X_MIN
local OUTER_DEPTH = OUTER_Z_MAX - OUTER_Z_MIN
local OUTER_CX = (OUTER_X_MIN + OUTER_X_MAX) / 2
local OUTER_CZ = (OUTER_Z_MIN + OUTER_Z_MAX) / 2

-- Doorway dimensions
local DOORWAY_WIDTH = 6
local DOORWAY_HEIGHT = 10
local DOOR_FRAME_THICKNESS = 0.5

-- Color palette — warm luxury tones
local MARBLE_WHITE  = Color3.fromHex("#F0E6D8")
local MARBLE_DARK   = Color3.fromHex("#1A0E14")
local WALL_COLOR    = Color3.fromHex("#1E1428")
local WALL_LIGHT    = Color3.fromHex("#2A1E35")
local GOLD          = Color3.fromHex("#D4A847")
local GOLD_BRIGHT   = Color3.fromHex("#FFD700")
local NEON_PINK     = Color3.fromHex("#FF1493")
local ROSE_GOLD     = Color3.fromHex("#E8A0BF")
local DARK          = Color3.fromHex("#0A0610")
local CREAM         = Color3.fromHex("#F0E8DC")
local TEAL_GREEN    = Color3.fromHex("#1B5E3B")
local PURPLE        = Color3.fromHex("#9B30FF")
local PURPLE_DARK   = Color3.fromHex("#2D1050")
local CRIMSON       = Color3.fromHex("#E94560")
local AMBER         = Color3.fromHex("#FFBF00")
local SKY_BLUE      = Color3.fromHex("#00BFFF")
local GLASS_BLUE    = Color3.fromHex("#88CCEE")
local COUCH_CREAM   = Color3.fromHex("#E8DDD0")
local COUCH_GREEN   = Color3.fromHex("#1B4D3E")
local CURTAIN_DARK  = Color3.fromHex("#12081E")

-- ============================================================
-- CORE HELPER FUNCTIONS
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
	part.CanCollide = false
	return part
end

function MansionBuilder.createSign(parent, text, pos, size, color, rotation)
	local part = Instance.new("Part")
	part.Name = "Sign_" .. text
	part.Position = pos
	part.Size = Vector3.new(size or 8, 3, 0.2)
	part.Color = DARK
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 0.5
	if rotation then
		part.Orientation = rotation
	end
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

	-- Also add a back-face SurfaceGui so sign is readable from both sides
	local sg2 = Instance.new("SurfaceGui")
	sg2.Face = Enum.NormalId.Back
	sg2.Parent = part
	local tl2 = Instance.new("TextLabel")
	tl2.Size = UDim2.new(1, 0, 1, 0)
	tl2.BackgroundTransparency = 1
	tl2.Text = text
	tl2.TextColor3 = color or GOLD
	tl2.TextScaled = true
	tl2.Font = Enum.Font.GothamBold
	tl2.Parent = sg2

	return part
end

-- ============================================================
-- DOORWAY HELPER — Creates a wall with a doorway opening
-- The wall is split into 3 parts: left section, above-door section, right section
-- Plus gold door frame trim
-- ============================================================

function MansionBuilder.createWallWithDoorway(parent, name, wallPos, wallSize, doorCenterOffset, wallColor, floorY)
	-- wallPos = center of the full wall
	-- wallSize = full wall dimensions (X, Y, Z)
	-- doorCenterOffset = offset along the long axis of the wall for the door center (0 = centered)
	-- For X-axis walls (WallNorth/South), the door offset is along X
	-- For Z-axis walls (WallEast/West), the door offset is along Z

	local wc = wallColor or WALL_COLOR
	local fy = floorY or FLOOR_Y
	local dw = DOORWAY_WIDTH
	local dh = DOORWAY_HEIGHT
	local offset = doorCenterOffset or 0

	-- Determine wall orientation
	local isXWall = wallSize.X > wallSize.Z -- wall stretches along X axis

	if isXWall then
		local fullLen = wallSize.X
		local wallThick = wallSize.Z
		local wallH = wallSize.Y

		local doorLeft = offset - dw / 2
		local doorRight = offset + dw / 2

		-- Left section (from -fullLen/2 to doorLeft)
		local leftLen = (fullLen / 2) + doorLeft
		if leftLen > 0.5 then
			local leftCx = wallPos.X - fullLen / 2 + leftLen / 2
			MansionBuilder.createPart(parent, name .. "_L",
				Vector3.new(leftCx, wallPos.Y, wallPos.Z),
				Vector3.new(leftLen, wallH, wallThick), wc)
		end

		-- Right section (from doorRight to fullLen/2)
		local rightLen = (fullLen / 2) - doorRight
		if rightLen > 0.5 then
			local rightCx = wallPos.X + fullLen / 2 - rightLen / 2
			MansionBuilder.createPart(parent, name .. "_R",
				Vector3.new(rightCx, wallPos.Y, wallPos.Z),
				Vector3.new(rightLen, wallH, wallThick), wc)
		end

		-- Above-door section
		local aboveH = wallH - dh
		if aboveH > 0.5 then
			local aboveCy = wallPos.Y + wallH / 2 - aboveH / 2
			MansionBuilder.createPart(parent, name .. "_Top",
				Vector3.new(wallPos.X + offset, aboveCy, wallPos.Z),
				Vector3.new(dw, aboveH, wallThick), wc)
		end

		-- Gold door frame
		local doorBottomY = wallPos.Y - wallH / 2
		-- Left jamb
		MansionBuilder.createPart(parent, name .. "_FrameL",
			Vector3.new(wallPos.X + doorLeft, doorBottomY + dh / 2, wallPos.Z),
			Vector3.new(DOOR_FRAME_THICKNESS, dh, wallThick + 0.4), GOLD, Enum.Material.Metal)
		-- Right jamb
		MansionBuilder.createPart(parent, name .. "_FrameR",
			Vector3.new(wallPos.X + doorRight, doorBottomY + dh / 2, wallPos.Z),
			Vector3.new(DOOR_FRAME_THICKNESS, dh, wallThick + 0.4), GOLD, Enum.Material.Metal)
		-- Top lintel
		MansionBuilder.createPart(parent, name .. "_FrameTop",
			Vector3.new(wallPos.X + offset, doorBottomY + dh, wallPos.Z),
			Vector3.new(dw + DOOR_FRAME_THICKNESS * 2, DOOR_FRAME_THICKNESS, wallThick + 0.4), GOLD, Enum.Material.Metal)
	else
		-- Z-axis wall (stretches along Z)
		local fullLen = wallSize.Z
		local wallThick = wallSize.X
		local wallH = wallSize.Y

		local doorLeft = offset - dw / 2
		local doorRight = offset + dw / 2

		-- Left section (negative Z side)
		local leftLen = (fullLen / 2) + doorLeft
		if leftLen > 0.5 then
			local leftCz = wallPos.Z - fullLen / 2 + leftLen / 2
			MansionBuilder.createPart(parent, name .. "_L",
				Vector3.new(wallPos.X, wallPos.Y, leftCz),
				Vector3.new(wallThick, wallH, leftLen), wc)
		end

		-- Right section (positive Z side)
		local rightLen = (fullLen / 2) - doorRight
		if rightLen > 0.5 then
			local rightCz = wallPos.Z + fullLen / 2 - rightLen / 2
			MansionBuilder.createPart(parent, name .. "_R",
				Vector3.new(wallPos.X, wallPos.Y, rightCz),
				Vector3.new(wallThick, wallH, rightLen), wc)
		end

		-- Above-door section
		local aboveH = wallH - dh
		if aboveH > 0.5 then
			local aboveCy = wallPos.Y + wallH / 2 - aboveH / 2
			MansionBuilder.createPart(parent, name .. "_Top",
				Vector3.new(wallPos.X, aboveCy, wallPos.Z + offset),
				Vector3.new(wallThick, aboveH, dw), wc)
		end

		-- Gold door frame
		local doorBottomY = wallPos.Y - wallH / 2
		-- Left jamb
		MansionBuilder.createPart(parent, name .. "_FrameL",
			Vector3.new(wallPos.X, doorBottomY + dh / 2, wallPos.Z + doorLeft),
			Vector3.new(wallThick + 0.4, dh, DOOR_FRAME_THICKNESS), GOLD, Enum.Material.Metal)
		-- Right jamb
		MansionBuilder.createPart(parent, name .. "_FrameR",
			Vector3.new(wallPos.X, doorBottomY + dh / 2, wallPos.Z + doorRight),
			Vector3.new(wallThick + 0.4, dh, DOOR_FRAME_THICKNESS), GOLD, Enum.Material.Metal)
		-- Top lintel
		MansionBuilder.createPart(parent, name .. "_FrameTop",
			Vector3.new(wallPos.X, doorBottomY + dh, wallPos.Z + offset),
			Vector3.new(wallThick + 0.4, DOOR_FRAME_THICKNESS, dw + DOOR_FRAME_THICKNESS * 2), GOLD, Enum.Material.Metal)
	end
end

-- ============================================================
-- WINDOW HELPER — Creates a transparent glass section in a wall
-- ============================================================

function MansionBuilder.createWindow(parent, pos, size, name)
	local win = MansionBuilder.createPart(parent, name or "Window", pos, size, GLASS_BLUE, Enum.Material.Glass)
	win.Transparency = 0.5
	-- Gold frame around window
	MansionBuilder.createPart(parent, (name or "Window") .. "_FrameTop",
		pos + Vector3.new(0, size.Y / 2, 0),
		Vector3.new(size.X + 0.4, 0.3, size.Z + 0.4), GOLD, Enum.Material.Metal)
	MansionBuilder.createPart(parent, (name or "Window") .. "_FrameBot",
		pos - Vector3.new(0, size.Y / 2, 0),
		Vector3.new(size.X + 0.4, 0.3, size.Z + 0.4), GOLD, Enum.Material.Metal)
	return win
end

-- ============================================================
-- NEW FURNITURE HELPERS
-- ============================================================

function MansionBuilder.createCouch(parent, pos, size, rotation, color)
	local couch = Instance.new("Model")
	couch.Name = "Couch"
	couch.Parent = parent

	-- Seat cushion
	local seat = MansionBuilder.createPart(couch, "Seat", pos, size or Vector3.new(8, 2, 4), color or COUCH_CREAM, Enum.Material.Fabric)
	if rotation then seat.Orientation = rotation end

	-- Backrest — offset based on rotation
	local backOffset = Vector3.new(0, 1.5, -2)
	if rotation then
		local ry = rotation.Y
		if math.abs(ry - 90) < 1 or math.abs(ry + 270) < 1 then
			backOffset = Vector3.new(-2, 1.5, 0)
		elseif math.abs(ry + 90) < 1 or math.abs(ry - 270) < 1 then
			backOffset = Vector3.new(2, 1.5, 0)
		elseif math.abs(ry - 180) < 1 or math.abs(ry + 180) < 1 then
			backOffset = Vector3.new(0, 1.5, 2)
		end
	end
	local back = MansionBuilder.createPart(couch, "Back",
		pos + backOffset,
		Vector3.new((size and size.X) or 8, 3, 1),
		color or COUCH_CREAM, Enum.Material.Fabric)
	if rotation then back.Orientation = rotation end

	-- Throw pillows
	local pillowColors = {GOLD_BRIGHT, NEON_PINK, ROSE_GOLD}
	for i = 1, 2 do
		local px = (i == 1) and -2 or 2
		MansionBuilder.createPart(couch, "Pillow" .. i,
			pos + Vector3.new(px, 1.2, -1),
			Vector3.new(1.5, 1, 1.2),
			pillowColors[i], Enum.Material.Fabric)
	end

	return couch
end

function MansionBuilder.createPlant(parent, pos, height)
	local plant = Instance.new("Model")
	plant.Name = "Plant"
	plant.Parent = parent

	-- Pot
	local pot = Instance.new("Part")
	pot.Name = "Pot"
	pot.Shape = Enum.PartType.Cylinder
	pot.Size = Vector3.new(3, 4, 4)
	pot.Position = pos + Vector3.new(0, 1.5, 0)
	pot.Orientation = Vector3.new(0, 0, 90)
	pot.Color = GOLD
	pot.Material = Enum.Material.SmoothPlastic
	pot.Anchored = true
	pot.Parent = plant

	-- Trunk
	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size = Vector3.new(height or 10, 1.5, 1.5)
	trunk.Position = pos + Vector3.new(0, (height or 10) / 2 + 3, 0)
	trunk.Orientation = Vector3.new(0, 0, 0)
	trunk.Color = Color3.fromHex("#3B2F1A")
	trunk.Material = Enum.Material.Wood
	trunk.Anchored = true
	trunk.Parent = plant

	-- Canopy — cluster of green spheres
	local topY = pos.Y + (height or 10) + 3
	for i = 1, 5 do
		local leaf = Instance.new("Part")
		leaf.Name = "Leaf" .. i
		leaf.Shape = Enum.PartType.Ball
		leaf.Size = Vector3.new(4, 4, 4)
		local offsets = {
			Vector3.new(0, 0, 0),
			Vector3.new(2, -1, 1),
			Vector3.new(-2, -1, -1),
			Vector3.new(1, 1, -2),
			Vector3.new(-1, 1, 2),
		}
		leaf.Position = Vector3.new(pos.X, topY, pos.Z) + offsets[i]
		leaf.Color = Color3.fromHex("#2D8B46")
		leaf.Material = Enum.Material.Grass
		leaf.Anchored = true
		leaf.CanCollide = false
		leaf.Parent = plant
	end

	return plant
end

function MansionBuilder.createPendantLight(parent, pos, color, brightness)
	local pendant = Instance.new("Model")
	pendant.Name = "PendantLight"
	pendant.Parent = parent

	-- Cord
	MansionBuilder.createPart(pendant, "Cord", pos + Vector3.new(0, 1.5, 0), Vector3.new(0.2, 3, 0.2), GOLD)

	-- Shade (sphere)
	local shade = Instance.new("Part")
	shade.Name = "Shade"
	shade.Shape = Enum.PartType.Ball
	shade.Size = Vector3.new(3, 3, 3)
	shade.Position = pos
	shade.Color = color or GOLD
	shade.Material = Enum.Material.Neon
	shade.Anchored = true
	shade.Transparency = 0.2
	shade.CanCollide = false
	shade.Parent = pendant

	local pl = Instance.new("PointLight")
	pl.Color = color or Color3.fromHex("#FFEEDD")
	pl.Brightness = brightness or 1.5
	pl.Range = 30
	pl.Parent = shade

	return pendant
end

function MansionBuilder.createBarStool(parent, pos)
	local stool = Instance.new("Model")
	stool.Name = "BarStool"
	stool.Parent = parent

	-- Leg (cylinder)
	local leg = Instance.new("Part")
	leg.Name = "Leg"
	leg.Shape = Enum.PartType.Cylinder
	leg.Size = Vector3.new(3.5, 1, 1)
	leg.Position = pos + Vector3.new(0, 1.75, 0)
	leg.Orientation = Vector3.new(0, 0, 0)
	leg.Color = GOLD
	leg.Material = Enum.Material.Metal
	leg.Anchored = true
	leg.Parent = stool

	-- Seat (cylinder)
	local seat = Instance.new("Part")
	seat.Name = "Seat"
	seat.Shape = Enum.PartType.Cylinder
	seat.Size = Vector3.new(0.8, 2.5, 2.5)
	seat.Position = pos + Vector3.new(0, 3.8, 0)
	seat.Orientation = Vector3.new(0, 0, 90)
	seat.Color = CREAM
	seat.Material = Enum.Material.Fabric
	seat.Anchored = true
	seat.Parent = stool

	return stool
end

function MansionBuilder.createSconce(parent, pos, direction)
	local sconce = Instance.new("Model")
	sconce.Name = "Sconce"
	sconce.Parent = parent

	-- Bracket
	MansionBuilder.createPart(sconce, "Bracket", pos, Vector3.new(1, 2, 1), GOLD, Enum.Material.Metal)

	-- Bulb
	local bulb = Instance.new("Part")
	bulb.Name = "Bulb"
	bulb.Shape = Enum.PartType.Ball
	bulb.Size = Vector3.new(1.5, 1.5, 1.5)
	bulb.Position = pos + (direction or Vector3.new(0, 0, 1))
	bulb.Color = AMBER
	bulb.Material = Enum.Material.Neon
	bulb.Anchored = true
	bulb.CanCollide = false
	bulb.Parent = sconce

	local pl = Instance.new("PointLight")
	pl.Color = Color3.fromHex("#FFEEDD")
	pl.Brightness = 1.2
	pl.Range = 20
	pl.Parent = bulb

	return sconce
end

function MansionBuilder.createSkyline(parent)
	local skyline = Instance.new("Model")
	skyline.Name = "Skyline"
	skyline.Parent = parent

	-- Row of buildings at edge
	local buildingHeights = {60, 45, 80, 35, 70, 55, 90, 40, 65, 50, 75, 42, 85, 38, 58}
	local startX = -80
	for i, h in ipairs(buildingHeights) do
		local bx = startX + (i - 1) * 12
		local building = MansionBuilder.createPart(skyline, "Building" .. i,
			Vector3.new(bx + 100, h / 2 + FLOOR2_Y + WALL_HEIGHT, 80),
			Vector3.new(8, h, 8),
			Color3.fromHex("#0D0D15"), Enum.Material.SmoothPlastic)

		-- Window lights — small yellow neon dots
		for wy = 1, math.floor(h / 8) do
			for wx = 1, 2 do
				local windowX = bx + 100 + (wx == 1 and -2 or 2)
				local windowY = FLOOR2_Y + WALL_HEIGHT + wy * 7
				if windowY < FLOOR2_Y + WALL_HEIGHT + h - 3 then
					local window = MansionBuilder.createNeon(skyline, "Win" .. i .. "_" .. wy .. "_" .. wx,
						Vector3.new(windowX, windowY, 76),
						Vector3.new(1.5, 1.5, 0.3),
						Color3.fromHex("#FFE488"))
					window.Transparency = 0.3
				end
			end
		end
	end

	return skyline
end

function MansionBuilder.createFlowerVase(parent, pos, flowerColor)
	local vase = Instance.new("Model")
	vase.Name = "FlowerVase"
	vase.Parent = parent

	-- Base pedestal
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(3, 2, 2)
	base.Position = pos + Vector3.new(0, 1.5, 0)
	base.Orientation = Vector3.new(0, 0, 0)
	base.Color = GOLD
	base.Material = Enum.Material.Metal
	base.Anchored = true
	base.Parent = vase

	-- Flowers (spheres)
	local fColors = flowerColor or {NEON_PINK, ROSE_GOLD, Color3.fromHex("#FF6B8A")}
	for i = 1, 3 do
		local flower = Instance.new("Part")
		flower.Name = "Flower" .. i
		flower.Shape = Enum.PartType.Ball
		flower.Size = Vector3.new(1.2, 1.2, 1.2)
		local offsets = {Vector3.new(-0.5, 3.5, 0), Vector3.new(0.5, 4, 0.3), Vector3.new(0, 3.8, -0.4)}
		flower.Position = pos + offsets[i]
		flower.Color = fColors[((i - 1) % #fColors) + 1]
		flower.Material = Enum.Material.SmoothPlastic
		flower.Anchored = true
		flower.CanCollide = false
		flower.Parent = vase
	end

	return vase
end

function MansionBuilder.createChandelier(parent, pos, radius, color)
	local chandelier = Instance.new("Model")
	chandelier.Name = "Chandelier"
	chandelier.Parent = parent

	-- Central ring (neon)
	-- We approximate a ring with 8 neon bars arranged in octagon
	local segments = 8
	for i = 1, segments do
		local angle = (i - 1) * (2 * math.pi / segments)
		local nextAngle = i * (2 * math.pi / segments)
		local midAngle = (angle + nextAngle) / 2
		local r = radius or 8
		local cx = pos.X + math.cos(midAngle) * r
		local cz = pos.Z + math.sin(midAngle) * r
		local segLen = 2 * r * math.sin(math.pi / segments)
		local bar = MansionBuilder.createNeon(chandelier, "Ring" .. i,
			Vector3.new(cx, pos.Y, cz),
			Vector3.new(segLen, 0.5, 0.5),
			color or GOLD_BRIGHT)
		bar.Orientation = Vector3.new(0, math.deg(midAngle), 0)
	end

	-- Hanging chains
	for i = 1, 4 do
		local angle = (i - 1) * (math.pi / 2)
		local r = (radius or 8) * 0.5
		MansionBuilder.createPart(chandelier, "Chain" .. i,
			Vector3.new(pos.X + math.cos(angle) * r, pos.Y + 2, pos.Z + math.sin(angle) * r),
			Vector3.new(0.2, 4, 0.2), GOLD, Enum.Material.Metal)
	end

	-- Central light
	local center = Instance.new("Part")
	center.Name = "CenterLight"
	center.Shape = Enum.PartType.Ball
	center.Size = Vector3.new(2, 2, 2)
	center.Position = pos
	center.Color = color or GOLD_BRIGHT
	center.Material = Enum.Material.Neon
	center.Anchored = true
	center.CanCollide = false
	center.Parent = chandelier

	local pl = Instance.new("PointLight")
	pl.Color = Color3.fromHex("#FFEEDD")
	pl.Brightness = 2
	pl.Range = 50
	pl.Parent = center

	return chandelier
end

function MansionBuilder.createArtFrame(parent, pos, size, rotation)
	local frame = Instance.new("Model")
	frame.Name = "ArtFrame"
	frame.Parent = parent

	-- Gold border frame
	local borderSize = size or Vector3.new(4, 3, 0.3)
	local border = MansionBuilder.createPart(frame, "Border", pos, borderSize + Vector3.new(0.6, 0.6, 0), GOLD, Enum.Material.Metal)
	if rotation then border.Orientation = rotation end

	-- Dark canvas
	local canvas = MansionBuilder.createPart(frame, "Canvas", pos + Vector3.new(0, 0, 0.05), borderSize, Color3.fromHex("#1A1225"))
	if rotation then canvas.Orientation = rotation end
	canvas.CanCollide = false

	return frame
end

function MansionBuilder.createFountain(parent, pos)
	local fountain = Instance.new("Model")
	fountain.Name = "Fountain"
	fountain.Parent = parent

	-- Base pool
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(2, 12, 12)
	base.Position = pos + Vector3.new(0, 1, 0)
	base.Orientation = Vector3.new(0, 0, 90)
	base.Color = MARBLE_WHITE
	base.Material = Enum.Material.Marble
	base.Anchored = true
	base.Parent = fountain

	-- Water
	local water = Instance.new("Part")
	water.Name = "Water"
	water.Shape = Enum.PartType.Cylinder
	water.Size = Vector3.new(1.5, 11, 11)
	water.Position = pos + Vector3.new(0, 1.3, 0)
	water.Orientation = Vector3.new(0, 0, 90)
	water.Color = SKY_BLUE
	water.Material = Enum.Material.Neon
	water.Transparency = 0.4
	water.Anchored = true
	water.CanCollide = false
	water.Parent = fountain

	-- Center pillar
	local pillar = Instance.new("Part")
	pillar.Name = "Pillar"
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Size = Vector3.new(6, 2, 2)
	pillar.Position = pos + Vector3.new(0, 4, 0)
	pillar.Color = MARBLE_WHITE
	pillar.Material = Enum.Material.Marble
	pillar.Anchored = true
	pillar.Parent = fountain

	-- Water jet glow
	MansionBuilder.createNeon(fountain, "Jet", pos + Vector3.new(0, 8, 0), Vector3.new(0.5, 4, 0.5), SKY_BLUE)

	return fountain
end

-- ============================================================
-- ROOM SHELL HELPER — builds floor, ceiling, walls for a room
-- Now supports doorway specification
-- ============================================================

function MansionBuilder.createRoomShell(parent, name, cx, cy, cz, width, depth, wallHeight, floorColor, wallColor, ceilColor, floorMat)
	local room = Instance.new("Folder")
	room.Name = name
	room.Parent = parent

	local wh = wallHeight or WALL_HEIGHT
	local hw = width / 2
	local hd = depth / 2

	-- Floor
	MansionBuilder.createPart(room, "Floor",
		Vector3.new(cx, cy - 0.5, cz),
		Vector3.new(width, 1, depth),
		floorColor or MARBLE_WHITE, floorMat or Enum.Material.Marble)

	-- Ceiling
	MansionBuilder.createPart(room, "Ceiling",
		Vector3.new(cx, cy + wh, cz),
		Vector3.new(width, 1, depth),
		ceilColor or DARK)

	-- Walls — North, South, East, West (solid by default)
	MansionBuilder.createPart(room, "WallNorth",
		Vector3.new(cx, cy + wh / 2, cz + hd),
		Vector3.new(width, wh, 1),
		wallColor or WALL_COLOR)
	MansionBuilder.createPart(room, "WallSouth",
		Vector3.new(cx, cy + wh / 2, cz - hd),
		Vector3.new(width, wh, 1),
		wallColor or WALL_COLOR)
	MansionBuilder.createPart(room, "WallWest",
		Vector3.new(cx - hw, cy + wh / 2, cz),
		Vector3.new(1, wh, depth),
		wallColor or WALL_COLOR)
	MansionBuilder.createPart(room, "WallEast",
		Vector3.new(cx + hw, cy + wh / 2, cz),
		Vector3.new(1, wh, depth),
		wallColor or WALL_COLOR)

	-- Gold floor trim neon strips
	MansionBuilder.createNeon(room, "FloorTrimN", Vector3.new(cx, cy + 0.1, cz + hd - 0.5), Vector3.new(width - 2, 0.2, 0.3), GOLD)
	MansionBuilder.createNeon(room, "FloorTrimS", Vector3.new(cx, cy + 0.1, cz - hd + 0.5), Vector3.new(width - 2, 0.2, 0.3), GOLD)
	MansionBuilder.createNeon(room, "FloorTrimW", Vector3.new(cx - hw + 0.5, cy + 0.1, cz), Vector3.new(0.3, 0.2, depth - 2), GOLD)
	MansionBuilder.createNeon(room, "FloorTrimE", Vector3.new(cx + hw - 0.5, cy + 0.1, cz), Vector3.new(0.3, 0.2, depth - 2), GOLD)

	-- Gold ceiling cove lighting
	MansionBuilder.createNeon(room, "CeilTrimN", Vector3.new(cx, cy + wh - 0.3, cz + hd - 0.5), Vector3.new(width - 2, 0.2, 0.3), GOLD)
	MansionBuilder.createNeon(room, "CeilTrimS", Vector3.new(cx, cy + wh - 0.3, cz - hd + 0.5), Vector3.new(width - 2, 0.2, 0.3), GOLD)

	return room
end

-- ============================================================
-- Helper to replace a solid wall with a doorway version
-- Removes the named wall part and adds doorway sections
-- ============================================================

function MansionBuilder.addDoorwayToWall(room, wallName, doorOffset, floorY)
	local wall = room:FindFirstChild(wallName)
	if not wall then return end

	local wallPos = wall.Position
	local wallSize = wall.Size
	local wallColor = wall.Color
	local fy = floorY or FLOOR_Y

	wall:Destroy()

	MansionBuilder.createWallWithDoorway(room, wallName, wallPos, wallSize, doorOffset or 0, wallColor, fy)
end

-- ============================================================
-- MAIN BUILD FUNCTION
-- ============================================================

function MansionBuilder.build()
	local mansion = Instance.new("Folder")
	mansion.Name = "Mansion"
	mansion.Parent = workspace

	-- Exterior
	MansionBuilder.buildExterior(mansion)

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

	-- Outer Shell — wraps the entire mansion
	MansionBuilder.buildOuterShell(mansion)

	-- Roof over upper floor
	MansionBuilder.buildRoof(mansion)

	-- Add doorways between rooms and corridor
	MansionBuilder.addAllDoorways(mansion)

	-- Add windows to exterior walls
	MansionBuilder.addExteriorWindows(mansion)

	-- Lighting
	MansionBuilder.setupLighting()

	print("[MansionBuilder] Luxury mansion built!")
	return mansion
end

-- ============================================================
-- OUTER SHELL — 4 exterior walls wrapping both floors
-- ============================================================

function MansionBuilder.buildOuterShell(parent)
	local shell = Instance.new("Folder")
	shell.Name = "OuterShell"
	shell.Parent = parent

	local totalHeight = FLOOR2_Y + WALL_HEIGHT + 1 -- full height of both floors
	local cy = totalHeight / 2

	-- West wall (front entrance side) — has main entrance doorway
	MansionBuilder.createWallWithDoorway(shell, "OuterWallWest",
		Vector3.new(OUTER_X_MIN, cy, OUTER_CZ),
		Vector3.new(1.5, totalHeight, OUTER_DEPTH),
		0, -- door centered at Z=0 (lobby entrance)
		WALL_COLOR, FLOOR_Y)

	-- East wall (back side, elevator side)
	MansionBuilder.createPart(shell, "OuterWallEast",
		Vector3.new(OUTER_X_MAX, cy, OUTER_CZ),
		Vector3.new(1.5, totalHeight, OUTER_DEPTH), WALL_COLOR)

	-- North wall (positive Z side)
	MansionBuilder.createPart(shell, "OuterWallNorth",
		Vector3.new(OUTER_CX, cy, OUTER_Z_MAX),
		Vector3.new(OUTER_WIDTH, totalHeight, 1.5), WALL_COLOR)

	-- South wall (negative Z side)
	MansionBuilder.createPart(shell, "OuterWallSouth",
		Vector3.new(OUTER_CX, cy, OUTER_Z_MIN),
		Vector3.new(OUTER_WIDTH, totalHeight, 1.5), WALL_COLOR)
end

-- ============================================================
-- ROOF — Covers the entire upper floor
-- ============================================================

function MansionBuilder.buildRoof(parent)
	local roof = Instance.new("Folder")
	roof.Name = "Roof"
	roof.Parent = parent

	local roofY = FLOOR2_Y + WALL_HEIGHT + 1

	-- Main flat roof slab covering the building footprint
	-- Rooftop area is open-air, so the roof covers everything EXCEPT the rooftop zone
	-- Rooftop zone is cx=100, cz=0, 120x100 — at Y = roofY
	-- The rooftop buildRooftop already creates a floor at ry = FLOOR2_Y + WALL_HEIGHT + 2
	-- So the roof covers the area that ISN'T the rooftop

	-- Roof section west of rooftop (X from OUTER_X_MIN to 40)
	local westRoofWidth = 40 - OUTER_X_MIN
	if westRoofWidth > 1 then
		MansionBuilder.createPart(roof, "RoofWest",
			Vector3.new(OUTER_X_MIN + westRoofWidth / 2, roofY, OUTER_CZ),
			Vector3.new(westRoofWidth, 1.5, OUTER_DEPTH),
			Color3.fromHex("#1A1225"), Enum.Material.SmoothPlastic)
	end

	-- Roof section east of rooftop (X from 160 to OUTER_X_MAX)
	local eastRoofWidth = OUTER_X_MAX - 160
	if eastRoofWidth > 1 then
		MansionBuilder.createPart(roof, "RoofEast",
			Vector3.new(160 + eastRoofWidth / 2, roofY, OUTER_CZ),
			Vector3.new(eastRoofWidth, 1.5, OUTER_DEPTH),
			Color3.fromHex("#1A1225"), Enum.Material.SmoothPlastic)
	end

	-- Roof section north of rooftop (X from 40 to 160, Z from rooftop north edge to building north)
	local rooftopNorthZ = 50
	local northRoofDepth = OUTER_Z_MAX - rooftopNorthZ
	if northRoofDepth > 1 then
		MansionBuilder.createPart(roof, "RoofNorth",
			Vector3.new(100, roofY, rooftopNorthZ + northRoofDepth / 2),
			Vector3.new(120, 1.5, northRoofDepth),
			Color3.fromHex("#1A1225"), Enum.Material.SmoothPlastic)
	end

	-- Roof section south of rooftop (X from 40 to 160, Z from building south to rooftop south edge)
	local rooftopSouthZ = -50
	local southRoofDepth = rooftopSouthZ - OUTER_Z_MIN
	if southRoofDepth > 1 then
		MansionBuilder.createPart(roof, "RoofSouth",
			Vector3.new(100, roofY, OUTER_Z_MIN + southRoofDepth / 2),
			Vector3.new(120, 1.5, southRoofDepth),
			Color3.fromHex("#1A1225"), Enum.Material.SmoothPlastic)
	end

	-- Rooftop stairwell / elevator access enclosure
	-- Small enclosed room on the rooftop for elevator exit
	local encX, encZ = 195, 0
	local encW, encD = 16, 16
	local encH = 12
	MansionBuilder.createPart(roof, "StairEncN",
		Vector3.new(encX, roofY + encH / 2 + 1, encZ + encD / 2),
		Vector3.new(encW, encH, 1), WALL_COLOR)
	MansionBuilder.createPart(roof, "StairEncS",
		Vector3.new(encX, roofY + encH / 2 + 1, encZ - encD / 2),
		Vector3.new(encW, encH, 1), WALL_COLOR)
	MansionBuilder.createPart(roof, "StairEncE",
		Vector3.new(encX + encW / 2, roofY + encH / 2 + 1, encZ),
		Vector3.new(1, encH, encD), WALL_COLOR)
	-- West side has doorway to rooftop
	MansionBuilder.createWallWithDoorway(roof, "StairEncW",
		Vector3.new(encX - encW / 2, roofY + encH / 2 + 1, encZ),
		Vector3.new(1, encH, encD),
		0, WALL_COLOR, roofY + 1)
	-- Small roof on enclosure
	MansionBuilder.createPart(roof, "StairEncRoof",
		Vector3.new(encX, roofY + encH + 1.5, encZ),
		Vector3.new(encW + 2, 1, encD + 2),
		Color3.fromHex("#1A1225"), Enum.Material.SmoothPlastic)

	-- Gold trim along roof edge
	MansionBuilder.createNeon(roof, "RoofTrimN",
		Vector3.new(OUTER_CX, roofY + 0.8, OUTER_Z_MAX),
		Vector3.new(OUTER_WIDTH, 0.3, 1.5), GOLD)
	MansionBuilder.createNeon(roof, "RoofTrimS",
		Vector3.new(OUTER_CX, roofY + 0.8, OUTER_Z_MIN),
		Vector3.new(OUTER_WIDTH, 0.3, 1.5), GOLD)
	MansionBuilder.createNeon(roof, "RoofTrimE",
		Vector3.new(OUTER_X_MAX, roofY + 0.8, OUTER_CZ),
		Vector3.new(1.5, 0.3, OUTER_DEPTH), GOLD)
	MansionBuilder.createNeon(roof, "RoofTrimW",
		Vector3.new(OUTER_X_MIN, roofY + 0.8, OUTER_CZ),
		Vector3.new(1.5, 0.3, OUTER_DEPTH), GOLD)
end

-- ============================================================
-- ADD ALL DOORWAYS — Punch doorways between rooms and corridor
-- ============================================================

function MansionBuilder.addAllDoorways(mansion)
	-- The corridor runs at X=110, Z=0, stretching X from 10 to 210, width 18 (Z from -9 to 9)
	-- Rooms connect to the corridor via their walls facing the corridor

	-- Lobby (cx=20, cz=0, 50x50) — connects east to corridor
	-- The lobby's east wall faces the corridor. Remove it and add doorway.
	local lobby = mansion:FindFirstChild("Lobby")
	if lobby then
		MansionBuilder.addDoorwayToWall(lobby, "WallNorth", 0, FLOOR_Y)
		MansionBuilder.addDoorwayToWall(lobby, "WallSouth", 0, FLOOR_Y)
	end

	-- Living Room (cx=60, cz=30, 45x45) — south wall faces corridor (corridor Z=+9)
	local livingRoom = mansion:FindFirstChild("LivingRoom")
	if livingRoom then
		MansionBuilder.addDoorwayToWall(livingRoom, "WallSouth", 0, FLOOR_Y)
	end

	-- Kitchen (cx=100, cz=30, 45x45) — south wall faces corridor
	local kitchen = mansion:FindFirstChild("Kitchen")
	if kitchen then
		MansionBuilder.addDoorwayToWall(kitchen, "WallSouth", 0, FLOOR_Y)
	end

	-- Drama Room (cx=60, cz=-35, 45x45) — north wall faces corridor
	local dramaRoom = mansion:FindFirstChild("DramaRoom")
	if dramaRoom then
		MansionBuilder.addDoorwayToWall(dramaRoom, "WallNorth", 0, FLOOR_Y)
	end

	-- Confession Booth (cx=100, cz=-35, 25x25) — north wall faces corridor
	local confession = mansion:FindFirstChild("ConfessionBooth")
	if confession then
		MansionBuilder.addDoorwayToWall(confession, "WallNorth", 0, FLOOR_Y)
	end

	-- Elimination Room (cx=150, cz=-35, 50x50) — north wall faces corridor
	local elimination = mansion:FindFirstChild("EliminationRoom")
	if elimination then
		MansionBuilder.addDoorwayToWall(elimination, "WallNorth", 0, FLOOR_Y)
	end
end

-- ============================================================
-- ADD EXTERIOR WINDOWS — Glass windows on outer walls
-- ============================================================

function MansionBuilder.addExteriorWindows(mansion)
	local shell = mansion:FindFirstChild("OuterShell")
	if not shell then return end

	local winH = 6
	local winW = 8
	local winD = 0.5

	-- Kitchen windows on north outer wall (kitchen faces north, city views)
	-- Kitchen is at cx=100, cz=30, so windows on the north outer wall at Z=OUTER_Z_MAX
	for i = 1, 3 do
		local wx = 80 + (i - 1) * 15
		MansionBuilder.createWindow(shell,
			Vector3.new(wx, WALL_HEIGHT / 2 + 2, OUTER_Z_MAX - 0.2),
			Vector3.new(winW, winH, winD),
			"KitchenWin" .. i)
	end

	-- Living Room windows on north outer wall
	for i = 1, 2 do
		local wx = 45 + (i - 1) * 18
		MansionBuilder.createWindow(shell,
			Vector3.new(wx, WALL_HEIGHT / 2 + 2, OUTER_Z_MAX - 0.2),
			Vector3.new(winW, winH, winD),
			"LivingWin" .. i)
	end

	-- South wall windows (Drama Room, Elimination Room)
	for i = 1, 3 do
		local wx = 50 + (i - 1) * 20
		MansionBuilder.createWindow(shell,
			Vector3.new(wx, WALL_HEIGHT / 2 + 2, OUTER_Z_MIN + 0.2),
			Vector3.new(winW, winH, winD),
			"SouthWin" .. i)
	end

	-- Upper floor windows (bedrooms) — north side
	for i = 1, 4 do
		local wx = 50 + (i - 1) * 35
		MansionBuilder.createWindow(shell,
			Vector3.new(wx, FLOOR2_Y + WALL_HEIGHT / 2 + 2, OUTER_Z_MAX - 0.2),
			Vector3.new(winW, winH, winD),
			"UpperNorthWin" .. i)
	end

	-- Upper floor windows — south side
	for i = 1, 4 do
		local wx = 50 + (i - 1) * 35
		MansionBuilder.createWindow(shell,
			Vector3.new(wx, FLOOR2_Y + WALL_HEIGHT / 2 + 2, OUTER_Z_MIN + 0.2),
			Vector3.new(winW, winH, winD),
			"UpperSouthWin" .. i)
	end

	-- East wall windows
	for i = 1, 2 do
		local wz = -20 + (i - 1) * 40
		MansionBuilder.createWindow(shell,
			Vector3.new(OUTER_X_MAX - 0.2, WALL_HEIGHT / 2 + 2, wz),
			Vector3.new(winD, winH, winW),
			"EastWin" .. i)
	end
end

-- ============================================================
-- MANSION EXTERIOR
-- ============================================================

function MansionBuilder.buildExterior(parent)
	local ext = Instance.new("Folder")
	ext.Name = "Exterior"
	ext.Parent = parent

	-- Ground plane (large)
	MansionBuilder.createPart(ext, "Ground",
		Vector3.new(100, -1, 0),
		Vector3.new(400, 1, 400),
		Color3.fromHex("#1A1A1A"), Enum.Material.Concrete)

	-- Driveway
	MansionBuilder.createPart(ext, "Driveway",
		Vector3.new(-30, -0.4, 0),
		Vector3.new(60, 0.5, 20),
		Color3.fromHex("#2A2A2A"), Enum.Material.Concrete)

	-- Grand entrance columns (4 pairs)
	for i = 1, 4 do
		local zOff = (i - 2.5) * 8
		for side = -1, 1, 2 do
			local col = Instance.new("Part")
			col.Name = "Column" .. i .. "_" .. (side == 1 and "L" or "R")
			col.Shape = Enum.PartType.Cylinder
			col.Size = Vector3.new(FLOOR2_Y + WALL_HEIGHT + 5, 3, 3)
			col.Position = Vector3.new(-5, (FLOOR2_Y + WALL_HEIGHT + 5) / 2 - 0.5, zOff)
			col.Color = MARBLE_WHITE
			col.Material = Enum.Material.Marble
			col.Anchored = true
			col.Parent = ext
		end
	end

	-- Entrance facade wall
	MansionBuilder.createPart(ext, "Facade",
		Vector3.new(-8, (FLOOR2_Y + WALL_HEIGHT) / 2, 0),
		Vector3.new(2, FLOOR2_Y + WALL_HEIGHT + 2, 50),
		WALL_COLOR)

	-- "MANSION OF MAYHEM" entrance sign
	MansionBuilder.createSign(ext, "MANSION OF MAYHEM",
		Vector3.new(-9.5, FLOOR2_Y + WALL_HEIGHT - 2, 0), 18, GOLD_BRIGHT)

	-- Neon glow behind sign
	MansionBuilder.createNeon(ext, "SignGlow",
		Vector3.new(-8.5, FLOOR2_Y + WALL_HEIGHT - 2, 0),
		Vector3.new(20, 4, 0.5), GOLD)

	-- Fountain in front
	MansionBuilder.createFountain(ext, Vector3.new(-30, -0.5, 0))

	-- Tropical landscaping — palm trees
	local treePositions = {
		Vector3.new(-45, -0.5, 15),
		Vector3.new(-45, -0.5, -15),
		Vector3.new(-20, -0.5, 25),
		Vector3.new(-20, -0.5, -25),
		Vector3.new(5, -0.5, 30),
		Vector3.new(5, -0.5, -30),
	}
	for i, tPos in ipairs(treePositions) do
		MansionBuilder.createPlant(ext, tPos, 12 + (i % 3) * 2)
	end

	-- Bushes (green spheres low to ground)
	for i = 1, 8 do
		local bush = Instance.new("Part")
		bush.Name = "Bush" .. i
		bush.Shape = Enum.PartType.Ball
		bush.Size = Vector3.new(4, 3, 4)
		bush.Position = Vector3.new(-15 + (i - 1) * 4, 1, (i % 2 == 0) and 22 or -22)
		bush.Color = Color3.fromHex("#1B5E3B")
		bush.Material = Enum.Material.Grass
		bush.Anchored = true
		bush.Parent = ext
	end

	-- Night sky dome with stars
	local sky = Instance.new("Part")
	sky.Name = "NightSky"
	sky.Shape = Enum.PartType.Ball
	sky.Size = Vector3.new(600, 600, 600)
	sky.Position = Vector3.new(100, 100, 0)
	sky.Color = Color3.fromHex("#050510")
	sky.Material = Enum.Material.SmoothPlastic
	sky.Transparency = 0.3
	sky.Anchored = true
	sky.CanCollide = false
	sky.Parent = ext

	-- Stars
	for i = 1, 40 do
		local angle1 = math.random() * math.pi
		local angle2 = math.random() * 2 * math.pi
		local r = 280
		local sx = 100 + r * math.sin(angle1) * math.cos(angle2)
		local sy = 100 + math.abs(r * math.cos(angle1))
		local sz = r * math.sin(angle1) * math.sin(angle2)
		MansionBuilder.createNeon(ext, "Star" .. i,
			Vector3.new(sx, sy, sz),
			Vector3.new(0.5, 0.5, 0.5),
			Color3.new(1, 1, 1))
	end
end

-- ============================================================
-- THE LOBBY — Luxury entrance (NO spawn here — spawn is at Hollywood)
-- ============================================================

function MansionBuilder.buildLobby(parent)
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = parent

	local cx, cz = 20, 0
	local roomW, roomD = 50, 50

	-- Floor (marble)
	MansionBuilder.createPart(lobby, "Floor",
		Vector3.new(cx, -0.5, cz),
		Vector3.new(roomW, 1, roomD),
		MARBLE_WHITE, Enum.Material.Marble)

	-- Ceiling
	MansionBuilder.createPart(lobby, "Ceiling",
		Vector3.new(cx, WALL_HEIGHT, cz),
		Vector3.new(roomW, 1, roomD), DARK)

	-- Walls (all 4 walls — doorways added later)
	MansionBuilder.createPart(lobby, "WallWest",
		Vector3.new(cx - roomW / 2, WALL_HEIGHT / 2, cz),
		Vector3.new(1, WALL_HEIGHT, roomD), WALL_COLOR)
	MansionBuilder.createPart(lobby, "WallNorth",
		Vector3.new(cx, WALL_HEIGHT / 2, cz + roomD / 2),
		Vector3.new(roomW, WALL_HEIGHT, 1), WALL_COLOR)
	MansionBuilder.createPart(lobby, "WallSouth",
		Vector3.new(cx, WALL_HEIGHT / 2, cz - roomD / 2),
		Vector3.new(roomW, WALL_HEIGHT, 1), WALL_COLOR)
	MansionBuilder.createPart(lobby, "WallEast",
		Vector3.new(cx + roomW / 2, WALL_HEIGHT / 2, cz),
		Vector3.new(1, WALL_HEIGHT, roomD), WALL_COLOR)

	-- Gold floor neon trim
	MansionBuilder.createNeon(lobby, "FloorTrimN", Vector3.new(cx, 0.1, cz + roomD / 2 - 1), Vector3.new(roomW - 2, 0.2, 0.3), GOLD)
	MansionBuilder.createNeon(lobby, "FloorTrimS", Vector3.new(cx, 0.1, cz - roomD / 2 + 1), Vector3.new(roomW - 2, 0.2, 0.3), GOLD)
	MansionBuilder.createNeon(lobby, "FloorTrimW", Vector3.new(cx - roomW / 2 + 1, 0.1, cz), Vector3.new(0.3, 0.2, roomD - 2), GOLD)
	MansionBuilder.createNeon(lobby, "FloorTrimE", Vector3.new(cx + roomW / 2 - 1, 0.1, cz), Vector3.new(0.3, 0.2, roomD - 2), GOLD)

	-- Gold ceiling cove trim
	MansionBuilder.createNeon(lobby, "CeilTrimN", Vector3.new(cx, WALL_HEIGHT - 0.3, cz + roomD / 2 - 1), Vector3.new(roomW - 2, 0.2, 0.3), GOLD)
	MansionBuilder.createNeon(lobby, "CeilTrimS", Vector3.new(cx, WALL_HEIGHT - 0.3, cz - roomD / 2 + 1), Vector3.new(roomW - 2, 0.2, 0.3), GOLD)

	-- Raised center platform (circular)
	local platform = Instance.new("Part")
	platform.Name = "CenterPlatform"
	platform.Shape = Enum.PartType.Cylinder
	platform.Size = Vector3.new(1.5, 20, 20)
	platform.Position = Vector3.new(cx, 0.75, cz)
	platform.Orientation = Vector3.new(0, 0, 90)
	platform.Color = MARBLE_WHITE
	platform.Material = Enum.Material.Marble
	platform.Anchored = true
	platform.Parent = lobby

	-- "Welcome to The Lobby" neon sign on back wall (pink/rose gold)
	MansionBuilder.createSign(lobby, "Welcome to The Lobby",
		Vector3.new(cx - roomW / 2 + 1, 10, cz), 14, ROSE_GOLD)
	MansionBuilder.createNeon(lobby, "SignGlow",
		Vector3.new(cx - roomW / 2 + 0.5, 10, cz),
		Vector3.new(0.3, 4, 16), NEON_PINK)

	-- Circular neon ring chandelier
	MansionBuilder.createChandelier(lobby, Vector3.new(cx, WALL_HEIGHT - 2, cz), 8, GOLD_BRIGHT)

	-- 4 curved cream couches arranged in circle facing center
	local couchPositions = {
		{pos = Vector3.new(cx, 0, cz + 12), rot = Vector3.new(0, 0, 0)},
		{pos = Vector3.new(cx, 0, cz - 12), rot = Vector3.new(0, 180, 0)},
		{pos = Vector3.new(cx + 12, 0, cz), rot = Vector3.new(0, -90, 0)},
		{pos = Vector3.new(cx - 10, 0, cz), rot = Vector3.new(0, 90, 0)},
	}

	for i, cData in ipairs(couchPositions) do
		MansionBuilder.createCouch(lobby, cData.pos + Vector3.new(0, 1.5, 0),
			Vector3.new(8, 2, 4), cData.rot, COUCH_CREAM)
	end

	-- Round glass coffee table with gold base (center)
	local tableBase = Instance.new("Part")
	tableBase.Name = "CoffeeTableBase"
	tableBase.Shape = Enum.PartType.Cylinder
	tableBase.Size = Vector3.new(2.5, 2, 2)
	tableBase.Position = Vector3.new(cx, 2.5, cz)
	tableBase.Color = GOLD
	tableBase.Material = Enum.Material.Metal
	tableBase.Anchored = true
	tableBase.Parent = lobby

	local tableTop = Instance.new("Part")
	tableTop.Name = "CoffeeTableTop"
	tableTop.Shape = Enum.PartType.Cylinder
	tableTop.Size = Vector3.new(1, 6, 6)
	tableTop.Position = Vector3.new(cx, 3.8, cz)
	tableTop.Orientation = Vector3.new(0, 0, 90)
	tableTop.Color = GLASS_BLUE
	tableTop.Material = Enum.Material.Glass
	tableTop.Transparency = 0.5
	tableTop.Anchored = true
	tableTop.Parent = lobby

	-- Bar area (east side)
	local barX = cx + 16
	local barZ = cz + 15
	-- Bar counter
	MansionBuilder.createPart(lobby, "BarCounter",
		Vector3.new(barX, 2, barZ),
		Vector3.new(12, 4, 3), MARBLE_WHITE, Enum.Material.Marble)
	-- Bar counter top accent
	MansionBuilder.createNeon(lobby, "BarTopGlow",
		Vector3.new(barX, 4.1, barZ),
		Vector3.new(12, 0.2, 3), GOLD)

	-- Bar back shelves
	MansionBuilder.createPart(lobby, "BarBackWall",
		Vector3.new(barX, 6, barZ + 3),
		Vector3.new(12, 8, 1), WALL_LIGHT)
	-- Shelves
	for s = 1, 3 do
		MansionBuilder.createPart(lobby, "BarShelf" .. s,
			Vector3.new(barX, 3.5 + s * 2.5, barZ + 2.5),
			Vector3.new(10, 0.3, 2), GOLD, Enum.Material.Metal)
	end
	-- Bottles (colored parts on shelves)
	local bottleColors = {NEON_PINK, GOLD_BRIGHT, PURPLE, SKY_BLUE, CRIMSON, AMBER}
	for s = 1, 3 do
		for b = 1, 4 do
			local bottle = Instance.new("Part")
			bottle.Name = "Bottle" .. s .. "_" .. b
			bottle.Size = Vector3.new(0.6, 1.8, 0.6)
			bottle.Position = Vector3.new(barX - 3.5 + b * 2, 4.5 + s * 2.5, barZ + 2.5)
			bottle.Color = bottleColors[((s + b - 2) % #bottleColors) + 1]
			bottle.Material = Enum.Material.Glass
			bottle.Transparency = 0.3
			bottle.Anchored = true
			bottle.CanCollide = false
			bottle.Parent = lobby
		end
	end

	-- Bar stools
	for i = 1, 4 do
		MansionBuilder.createBarStool(lobby, Vector3.new(barX - 4.5 + i * 3, 0, barZ - 3))
	end

	-- Tropical plants (4 corners-ish)
	MansionBuilder.createPlant(lobby, Vector3.new(cx - 20, 0, cz + 20), 8)
	MansionBuilder.createPlant(lobby, Vector3.new(cx - 20, 0, cz - 20), 9)
	MansionBuilder.createPlant(lobby, Vector3.new(cx + 20, 0, cz - 20), 7)
	MansionBuilder.createPlant(lobby, Vector3.new(cx + 20, 0, cz + 5), 8)

	-- Lobby teleport destination (where bus passengers arrive)
	-- No SpawnLocation here — spawn is at Hollywood station
	local arrivalMark = MansionBuilder.createPart(lobby, "ArrivalPoint",
		Vector3.new(cx, 0.1, cz),
		Vector3.new(8, 0.2, 8), GOLD, Enum.Material.Neon)
	arrivalMark.Transparency = 0.8
	arrivalMark.CanCollide = false
end

-- ============================================================
-- CONFESSIONAL BOOTH — Dark, moody, intimate
-- ============================================================

function MansionBuilder.buildConfessionBooth(parent)
	local cx, cz = 100, -35
	local roomW, roomD = 25, 25

	local room = MansionBuilder.createRoomShell(parent, "ConfessionBooth",
		cx, FLOOR_Y, cz, roomW, roomD, WALL_HEIGHT,
		PURPLE_DARK, Color3.fromHex("#120820"), DARK, Enum.Material.Marble)

	-- Override floor with dark dramatic marble
	MansionBuilder.createNeon(room, "PurpleFloorGlow",
		Vector3.new(cx, 0.15, cz),
		Vector3.new(roomW - 4, 0.2, roomD - 4), PURPLE)

	-- Large teal/dark green velvet couch
	MansionBuilder.createCouch(room,
		Vector3.new(cx, 1.5, cz + 5),
		Vector3.new(12, 3, 5), Vector3.new(0, 180, 0), COUCH_GREEN)

	-- Extra sequin/sparkle pillows on couch (gold + pink)
	MansionBuilder.createPart(room, "GoldPillow1",
		Vector3.new(cx - 4, 3.5, cz + 5),
		Vector3.new(1.5, 1, 1.2), GOLD_BRIGHT, Enum.Material.Foil)
	MansionBuilder.createPart(room, "PinkPillow1",
		Vector3.new(cx + 4, 3.5, cz + 5),
		Vector3.new(1.5, 1, 1.2), NEON_PINK, Enum.Material.Foil)
	MansionBuilder.createPart(room, "GoldPillow2",
		Vector3.new(cx - 1, 3.5, cz + 5),
		Vector3.new(1.2, 0.8, 1), ROSE_GOLD, Enum.Material.Foil)

	-- "Mansion Mayhem" neon sign on wall behind couch
	MansionBuilder.createSign(room, "Mansion Mayhem",
		Vector3.new(cx, 9, cz + roomD / 2 - 1), 12, NEON_PINK)
	MansionBuilder.createNeon(room, "SignBackGlow",
		Vector3.new(cx, 9, cz + roomD / 2 - 0.5),
		Vector3.new(14, 4, 0.3), NEON_PINK)

	-- Crown icon above text (gold neon)
	MansionBuilder.createNeon(room, "CrownBase",
		Vector3.new(cx, 12, cz + roomD / 2 - 1),
		Vector3.new(6, 0.5, 0.3), GOLD_BRIGHT)
	MansionBuilder.createNeon(room, "CrownPeak1",
		Vector3.new(cx - 2, 13, cz + roomD / 2 - 1),
		Vector3.new(0.5, 2, 0.3), GOLD_BRIGHT)
	MansionBuilder.createNeon(room, "CrownPeak2",
		Vector3.new(cx, 13.5, cz + roomD / 2 - 1),
		Vector3.new(0.5, 2.5, 0.3), GOLD_BRIGHT)
	MansionBuilder.createNeon(room, "CrownPeak3",
		Vector3.new(cx + 2, 13, cz + roomD / 2 - 1),
		Vector3.new(0.5, 2, 0.3), GOLD_BRIGHT)

	-- Two palm tree neon signs flanking (purple/blue)
	MansionBuilder.createNeon(room, "PalmLeftTrunk",
		Vector3.new(cx - 8, 8, cz + roomD / 2 - 1),
		Vector3.new(0.5, 6, 0.3), PURPLE)
	MansionBuilder.createNeon(room, "PalmLeftLeaf1",
		Vector3.new(cx - 9, 11.5, cz + roomD / 2 - 1),
		Vector3.new(3, 0.5, 0.3), SKY_BLUE)
	MansionBuilder.createNeon(room, "PalmLeftLeaf2",
		Vector3.new(cx - 7, 12, cz + roomD / 2 - 1),
		Vector3.new(3, 0.5, 0.3), SKY_BLUE)
	MansionBuilder.createNeon(room, "PalmRightTrunk",
		Vector3.new(cx + 8, 8, cz + roomD / 2 - 1),
		Vector3.new(0.5, 6, 0.3), PURPLE)
	MansionBuilder.createNeon(room, "PalmRightLeaf1",
		Vector3.new(cx + 9, 11.5, cz + roomD / 2 - 1),
		Vector3.new(3, 0.5, 0.3), SKY_BLUE)
	MansionBuilder.createNeon(room, "PalmRightLeaf2",
		Vector3.new(cx + 7, 12, cz + roomD / 2 - 1),
		Vector3.new(3, 0.5, 0.3), SKY_BLUE)

	-- Purple bead curtain at entrance (thin purple neon strips)
	local entranceZ = cz - roomD / 2
	for i = 1, 10 do
		local bx = cx - 5 + i
		MansionBuilder.createNeon(room, "BeadCurtain" .. i,
			Vector3.new(bx, WALL_HEIGHT / 2, entranceZ + 0.5),
			Vector3.new(0.15, WALL_HEIGHT - 2, 0.15), PURPLE)
	end
end

-- ============================================================
-- ROOFTOP — Open air party paradise
-- ============================================================

function MansionBuilder.buildRooftop(parent)
	local rooftop = Instance.new("Folder")
	rooftop.Name = "Rooftop"
	rooftop.Parent = parent

	local ry = FLOOR2_Y + WALL_HEIGHT + 2
	local cx, cz = 100, 0
	local roofW, roofD = 120, 100

	-- Floor (marble)
	MansionBuilder.createPart(rooftop, "Floor",
		Vector3.new(cx, ry - 0.5, cz),
		Vector3.new(roofW, 1, roofD),
		MARBLE_WHITE, Enum.Material.Marble)

	-- Low glass railing around edge
	for _, wall in ipairs({
		{"RailN", Vector3.new(cx, ry + 2, cz + roofD / 2), Vector3.new(roofW, 4, 1)},
		{"RailS", Vector3.new(cx, ry + 2, cz - roofD / 2), Vector3.new(roofW, 4, 1)},
		{"RailE", Vector3.new(cx + roofW / 2, ry + 2, cz), Vector3.new(1, 4, roofD)},
		{"RailW", Vector3.new(cx - roofW / 2, ry + 2, cz), Vector3.new(1, 4, roofD)},
	}) do
		local rail = MansionBuilder.createPart(rooftop, wall[1], wall[2], wall[3],
			GLASS_BLUE, Enum.Material.Glass)
		rail.Transparency = 0.6
	end

	-- Gold railing top trim
	MansionBuilder.createNeon(rooftop, "RailTopN", Vector3.new(cx, ry + 4.1, cz + roofD / 2), Vector3.new(roofW, 0.3, 1.2), GOLD)
	MansionBuilder.createNeon(rooftop, "RailTopS", Vector3.new(cx, ry + 4.1, cz - roofD / 2), Vector3.new(roofW, 0.3, 1.2), GOLD)
	MansionBuilder.createNeon(rooftop, "RailTopE", Vector3.new(cx + roofW / 2, ry + 4.1, cz), Vector3.new(1.2, 0.3, roofD), GOLD)
	MansionBuilder.createNeon(rooftop, "RailTopW", Vector3.new(cx - roofW / 2, ry + 4.1, cz), Vector3.new(1.2, 0.3, roofD), GOLD)

	-- Infinity pool
	local pool = Instance.new("Part")
	pool.Name = "Pool"
	pool.Shape = Enum.PartType.Cylinder
	pool.Size = Vector3.new(3, 35, 20)
	pool.Position = Vector3.new(cx + 20, ry + 0.8, cz + 15)
	pool.Orientation = Vector3.new(0, 0, 90)
	pool.Color = SKY_BLUE
	pool.Material = Enum.Material.Neon
	pool.Transparency = 0.4
	pool.Anchored = true
	pool.Parent = rooftop

	-- Pool border
	local poolBorder = Instance.new("Part")
	poolBorder.Name = "PoolBorder"
	poolBorder.Shape = Enum.PartType.Cylinder
	poolBorder.Size = Vector3.new(1, 37, 22)
	poolBorder.Position = Vector3.new(cx + 20, ry + 0.2, cz + 15)
	poolBorder.Orientation = Vector3.new(0, 0, 90)
	poolBorder.Color = MARBLE_WHITE
	poolBorder.Material = Enum.Material.Marble
	poolBorder.Anchored = true
	poolBorder.Parent = rooftop

	-- Circular fire pit in center
	local pitBase = Instance.new("Part")
	pitBase.Name = "FirePitBase"
	pitBase.Shape = Enum.PartType.Cylinder
	pitBase.Size = Vector3.new(2, 10, 10)
	pitBase.Position = Vector3.new(cx - 15, ry + 0.8, cz - 5)
	pitBase.Orientation = Vector3.new(0, 0, 90)
	pitBase.Color = Color3.fromHex("#3A3A3A")
	pitBase.Material = Enum.Material.Slate
	pitBase.Anchored = true
	pitBase.Parent = rooftop

	-- Fire glow
	local fire = MansionBuilder.createNeon(rooftop, "FireGlow",
		Vector3.new(cx - 15, ry + 2.5, cz - 5),
		Vector3.new(5, 3, 5), Color3.fromHex("#FF6600"))
	local firePL = Instance.new("PointLight")
	firePL.Color = Color3.fromHex("#FF8800")
	firePL.Brightness = 3
	firePL.Range = 35
	firePL.Parent = fire

	-- Curved lounge seating around fire pit (C-shape)
	local fireX, fireZ = cx - 15, cz - 5
	local loungeAngles = {0, 45, 90, 135, 180, 225, 270}
	for i, angle in ipairs(loungeAngles) do
		local rad = math.rad(angle)
		local lx = fireX + math.cos(rad) * 9
		local lz = fireZ + math.sin(rad) * 9
		local lounger = MansionBuilder.createPart(rooftop, "Lounger" .. i,
			Vector3.new(lx, ry + 1, lz),
			Vector3.new(5, 2, 3), COUCH_CREAM, Enum.Material.Fabric)
		lounger.Orientation = Vector3.new(0, -angle, 0)
	end

	-- Gold accent side tables
	for i = 1, 4 do
		local angle = math.rad((i - 1) * 90 + 45)
		local st = Instance.new("Part")
		st.Name = "SideTable" .. i
		st.Shape = Enum.PartType.Cylinder
		st.Size = Vector3.new(1.5, 2, 2)
		st.Position = Vector3.new(fireX + math.cos(angle) * 12, ry + 1.2, fireZ + math.sin(angle) * 12)
		st.Color = GOLD
		st.Material = Enum.Material.Metal
		st.Anchored = true
		st.Parent = rooftop
	end

	-- Palm trees on rooftop
	MansionBuilder.createPlant(rooftop, Vector3.new(cx - 50, ry, cz + 40), 10)
	MansionBuilder.createPlant(rooftop, Vector3.new(cx + 50, ry, cz + 40), 12)
	MansionBuilder.createPlant(rooftop, Vector3.new(cx - 50, ry, cz - 40), 11)
	MansionBuilder.createPlant(rooftop, Vector3.new(cx + 50, ry, cz - 40), 9)

	-- "Party" neon sign on building wall side
	MansionBuilder.createSign(rooftop, "PARTY",
		Vector3.new(cx - roofW / 2 + 2, ry + 6, cz), 10, NEON_PINK)

	MansionBuilder.createNeon(rooftop, "PartyGlow",
		Vector3.new(cx - roofW / 2 + 1, ry + 6, cz),
		Vector3.new(0.3, 4, 12), NEON_PINK)

	-- City skyline backdrop
	MansionBuilder.createSkyline(rooftop)

	-- Purple/pink ambient sky lighting
	local skyLight1 = MansionBuilder.createNeon(rooftop, "SkyGlow1",
		Vector3.new(cx, ry + 30, cz),
		Vector3.new(60, 0.5, 60), PURPLE)
	skyLight1.Transparency = 0.7
	local skyLight2 = MansionBuilder.createNeon(rooftop, "SkyGlow2",
		Vector3.new(cx, ry + 35, cz),
		Vector3.new(80, 0.5, 80), NEON_PINK)
	skyLight2.Transparency = 0.8
end

-- ============================================================
-- KITCHEN — Luxury marble & pendant lights
-- ============================================================

function MansionBuilder.buildKitchen(parent)
	local cx, cz = 100, 30
	local roomW, roomD = ROOM_SIZE, ROOM_SIZE

	local room = MansionBuilder.createRoomShell(parent, "Kitchen",
		cx, FLOOR_Y, cz, roomW, roomD, WALL_HEIGHT,
		MARBLE_WHITE, WALL_COLOR, DARK)

	-- Sign
	MansionBuilder.createSign(room, "THE KITCHEN",
		Vector3.new(cx, WALL_HEIGHT - 2, cz - roomD / 2 + 1), 10, GOLD)

	-- Large marble island (center)
	MansionBuilder.createPart(room, "Island",
		Vector3.new(cx, 2, cz),
		Vector3.new(16, 4, 5), MARBLE_WHITE, Enum.Material.Marble)
	-- Island top accent
	MansionBuilder.createNeon(room, "IslandTopGlow",
		Vector3.new(cx, 4.1, cz),
		Vector3.new(16, 0.15, 5), GOLD)

	-- 4 bar stools at island
	for i = 1, 4 do
		MansionBuilder.createBarStool(room, Vector3.new(cx - 6 + i * 3, 0, cz - 4))
	end

	-- 3 pendant lights above island
	for i = 1, 3 do
		MansionBuilder.createPendantLight(room,
			Vector3.new(cx - 5 + (i - 1) * 5, WALL_HEIGHT - 3, cz),
			AMBER, 1.5)
	end

	-- Marble counters along back wall
	MansionBuilder.createPart(room, "BackCounter",
		Vector3.new(cx, 2, cz + roomD / 2 - 2),
		Vector3.new(roomW - 4, 4, 3), MARBLE_WHITE, Enum.Material.Marble)
	-- Backsplash
	MansionBuilder.createPart(room, "Backsplash",
		Vector3.new(cx, 6, cz + roomD / 2 - 1),
		Vector3.new(roomW - 4, 4, 0.5), Color3.fromHex("#C8B8A8"), Enum.Material.Marble)

	-- Under-counter neon strip (gold)
	MansionBuilder.createNeon(room, "UnderCounterGlow",
		Vector3.new(cx, 0.3, cz + roomD / 2 - 2),
		Vector3.new(roomW - 6, 0.2, 0.3), GOLD)
	MansionBuilder.createNeon(room, "UnderIslandGlow",
		Vector3.new(cx, 0.3, cz),
		Vector3.new(16, 0.2, 0.3), GOLD)

	-- Neon heart sign on side wall (pink)
	MansionBuilder.createNeon(room, "HeartL",
		Vector3.new(cx - roomW / 2 + 1, 9, cz),
		Vector3.new(0.3, 2, 2), NEON_PINK)
	MansionBuilder.createNeon(room, "HeartR",
		Vector3.new(cx - roomW / 2 + 1, 9, cz + 2),
		Vector3.new(0.3, 2, 2), NEON_PINK)
	MansionBuilder.createNeon(room, "HeartV",
		Vector3.new(cx - roomW / 2 + 1, 7.5, cz + 1),
		Vector3.new(0.3, 1.5, 1), NEON_PINK)

	-- Flowers in vases on counter
	MansionBuilder.createFlowerVase(room, Vector3.new(cx - 8, 4, cz + roomD / 2 - 2))
	MansionBuilder.createFlowerVase(room, Vector3.new(cx + 8, 4, cz + roomD / 2 - 2))

	-- Wine glasses on counter (tiny transparent cylinders)
	for i = 1, 4 do
		local glass = Instance.new("Part")
		glass.Name = "WineGlass" .. i
		glass.Shape = Enum.PartType.Cylinder
		glass.Size = Vector3.new(1.5, 0.8, 0.8)
		glass.Position = Vector3.new(cx - 3 + i * 2, 4.8, cz + roomD / 2 - 2)
		glass.Color = Color3.new(1, 1, 1)
		glass.Material = Enum.Material.Glass
		glass.Transparency = 0.6
		glass.Anchored = true
		glass.CanCollide = false
		glass.Parent = room
	end
end

-- ============================================================
-- CORRIDOR — Grand hallway connecting rooms
-- ============================================================

function MansionBuilder.buildCorridor(parent)
	local corr = Instance.new("Folder")
	corr.Name = "Corridor"
	corr.Parent = parent

	local cx, cz = 110, 0
	local corrLen = 200
	local corrWidth = 18

	-- Floor (polished marble, reflective)
	MansionBuilder.createPart(corr, "Floor",
		Vector3.new(cx, -0.5, cz),
		Vector3.new(corrLen, 1, corrWidth),
		MARBLE_WHITE, Enum.Material.Marble)

	-- Ceiling
	MansionBuilder.createPart(corr, "Ceiling",
		Vector3.new(cx, WALL_HEIGHT, cz),
		Vector3.new(corrLen, 1, corrWidth), DARK)

	-- Corridor walls (north and south) — these are the interior corridor walls
	-- Rooms branch off from these walls via doorways
	MansionBuilder.createPart(corr, "WallNorth",
		Vector3.new(cx, WALL_HEIGHT / 2, cz + corrWidth / 2),
		Vector3.new(corrLen, WALL_HEIGHT, 1), WALL_COLOR)
	MansionBuilder.createPart(corr, "WallSouth",
		Vector3.new(cx, WALL_HEIGHT / 2, cz - corrWidth / 2),
		Vector3.new(corrLen, WALL_HEIGHT, 1), WALL_COLOR)

	-- Gold LED strips along ceiling edges
	MansionBuilder.createNeon(corr, "CeilStripN",
		Vector3.new(cx, WALL_HEIGHT - 0.3, cz + corrWidth / 2 - 0.5),
		Vector3.new(corrLen, 0.2, 0.3), GOLD)
	MansionBuilder.createNeon(corr, "CeilStripS",
		Vector3.new(cx, WALL_HEIGHT - 0.3, cz - corrWidth / 2 + 0.5),
		Vector3.new(corrLen, 0.2, 0.3), GOLD)

	-- Gold LED strips along floor edges
	MansionBuilder.createNeon(corr, "FloorStripN",
		Vector3.new(cx, 0.1, cz + corrWidth / 2 - 0.5),
		Vector3.new(corrLen, 0.2, 0.3), GOLD)
	MansionBuilder.createNeon(corr, "FloorStripS",
		Vector3.new(cx, 0.1, cz - corrWidth / 2 + 0.5),
		Vector3.new(corrLen, 0.2, 0.3), GOLD)

	-- Wall sconces every 15 studs
	local startX = cx - corrLen / 2 + 10
	local endX = cx + corrLen / 2 - 10
	for x = startX, endX, 15 do
		-- North wall sconce
		MansionBuilder.createSconce(corr,
			Vector3.new(x, 8, cz + corrWidth / 2 - 1),
			Vector3.new(0, 0, -1))
		-- South wall sconce
		MansionBuilder.createSconce(corr,
			Vector3.new(x, 8, cz - corrWidth / 2 + 1),
			Vector3.new(0, 0, 1))
	end

	-- Framed art on walls (every 20 studs)
	for x = startX + 7, endX, 20 do
		-- North wall art
		MansionBuilder.createArtFrame(corr,
			Vector3.new(x, 7, cz + corrWidth / 2 - 0.5),
			Vector3.new(5, 4, 0.3))
		-- South wall art
		MansionBuilder.createArtFrame(corr,
			Vector3.new(x, 7, cz - corrWidth / 2 + 0.5),
			Vector3.new(5, 4, 0.3))
	end

	-- Flower vase pedestals at intervals
	for x = startX + 15, endX, 30 do
		MansionBuilder.createFlowerVase(corr, Vector3.new(x, 0, cz + 5))
		MansionBuilder.createFlowerVase(corr, Vector3.new(x, 0, cz - 5))
	end

	-- Add doorways in corridor walls to connect to rooms
	-- Living Room is at Z=30, corridor north wall at Z=9 — doorway at X=60
	MansionBuilder.addDoorwayToWall(corr, "WallNorth", -50, FLOOR_Y) -- offset: 60 - 110 = -50

	-- Kitchen at Z=30, corridor north wall — doorway at X=100
	-- We need a second doorway in the north wall. Since addDoorwayToWall destroys the wall,
	-- we handle corridor doorways differently: we build the corridor walls with gaps

	-- Actually, let's rebuild corridor walls with multiple doorway openings
	-- Remove the solid north and south walls and replace with segmented walls

	local northWall = corr:FindFirstChild("WallNorth")
	local southWall = corr:FindFirstChild("WallSouth")

	if northWall then northWall:Destroy() end
	if southWall then southWall:Destroy() end

	-- North wall doorways: Living Room (X=60), Kitchen (X=100)
	local northDoors = {60, 100} -- X positions of doorway centers
	-- South wall doorways: Drama Room (X=60), Confession (X=100), Elimination (X=150)
	local southDoors = {60, 100, 150}

	-- Build north wall segments with doorway gaps
	MansionBuilder._buildSegmentedWall(corr, "CorrWallN",
		cx - corrLen / 2, cx + corrLen / 2,      -- X range
		WALL_HEIGHT / 2, cz + corrWidth / 2,     -- Y center, Z position
		WALL_HEIGHT, 1,                           -- height, thickness (Z)
		northDoors, DOORWAY_WIDTH, DOORWAY_HEIGHT,
		WALL_COLOR, true)                         -- isXWall=true

	-- Build south wall segments with doorway gaps
	MansionBuilder._buildSegmentedWall(corr, "CorrWallS",
		cx - corrLen / 2, cx + corrLen / 2,
		WALL_HEIGHT / 2, cz - corrWidth / 2,
		WALL_HEIGHT, 1,
		southDoors, DOORWAY_WIDTH, DOORWAY_HEIGHT,
		WALL_COLOR, true)
end

-- ============================================================
-- Helper: Build a wall along X with multiple doorway openings
-- ============================================================

function MansionBuilder._buildSegmentedWall(parent, baseName, xMin, xMax, yCen, zPos, wallH, wallThick, doorXPositions, doorW, doorH, wallColor, isXWall)
	-- Sort door positions
	table.sort(doorXPositions)

	local segIdx = 0
	local prevEnd = xMin

	for _, doorX in ipairs(doorXPositions) do
		local doorLeft = doorX - doorW / 2
		local doorRight = doorX + doorW / 2

		-- Segment before this door
		local segLen = doorLeft - prevEnd
		if segLen > 0.5 then
			segIdx = segIdx + 1
			local segCx = prevEnd + segLen / 2
			MansionBuilder.createPart(parent, baseName .. "_Seg" .. segIdx,
				Vector3.new(segCx, yCen, zPos),
				Vector3.new(segLen, wallH, wallThick),
				wallColor or WALL_COLOR)
		end

		-- Above-door segment
		local aboveH = wallH - doorH
		if aboveH > 0.5 then
			segIdx = segIdx + 1
			local aboveCy = yCen + wallH / 2 - aboveH / 2
			MansionBuilder.createPart(parent, baseName .. "_Above" .. segIdx,
				Vector3.new(doorX, aboveCy, zPos),
				Vector3.new(doorW, aboveH, wallThick),
				wallColor or WALL_COLOR)
		end

		-- Gold door frame
		local doorBottomY = yCen - wallH / 2
		-- Left jamb
		MansionBuilder.createPart(parent, baseName .. "_FrameL" .. segIdx,
			Vector3.new(doorLeft, doorBottomY + doorH / 2, zPos),
			Vector3.new(DOOR_FRAME_THICKNESS, doorH, wallThick + 0.4), GOLD, Enum.Material.Metal)
		-- Right jamb
		MansionBuilder.createPart(parent, baseName .. "_FrameR" .. segIdx,
			Vector3.new(doorRight, doorBottomY + doorH / 2, zPos),
			Vector3.new(DOOR_FRAME_THICKNESS, doorH, wallThick + 0.4), GOLD, Enum.Material.Metal)
		-- Top lintel
		MansionBuilder.createPart(parent, baseName .. "_FrameT" .. segIdx,
			Vector3.new(doorX, doorBottomY + doorH, zPos),
			Vector3.new(doorW + DOOR_FRAME_THICKNESS * 2, DOOR_FRAME_THICKNESS, wallThick + 0.4), GOLD, Enum.Material.Metal)

		prevEnd = doorRight
	end

	-- Final segment after last door
	local lastSegLen = xMax - prevEnd
	if lastSegLen > 0.5 then
		segIdx = segIdx + 1
		local segCx = prevEnd + lastSegLen / 2
		MansionBuilder.createPart(parent, baseName .. "_Seg" .. segIdx,
			Vector3.new(segCx, yCen, zPos),
			Vector3.new(lastSegLen, wallH, wallThick),
			wallColor or WALL_COLOR)
	end
end

-- ============================================================
-- ELIMINATION ROOM — Dark & dramatic
-- ============================================================

function MansionBuilder.buildEliminationRoom(parent)
	local cx, cz = 150, -35
	local roomW, roomD = 50, 50

	local room = MansionBuilder.createRoomShell(parent, "EliminationRoom",
		cx, FLOOR_Y, cz, roomW, roomD, WALL_HEIGHT,
		MARBLE_DARK, Color3.fromHex("#0A0610"), DARK, Enum.Material.Marble)

	-- Dark curtains around walls (tall thin parts)
	for i = 1, 12 do
		local angle = (i - 1) * (2 * math.pi / 12)
		local curtainX = cx + math.cos(angle) * (roomW / 2 - 2)
		local curtainZ = cz + math.sin(angle) * (roomD / 2 - 2)
		MansionBuilder.createPart(room, "Curtain" .. i,
			Vector3.new(curtainX, WALL_HEIGHT / 2, curtainZ),
			Vector3.new(3, WALL_HEIGHT - 2, 0.5),
			CURTAIN_DARK, Enum.Material.Fabric)
	end

	-- Center podium (dark metallic cylinder, narrow)
	local podium = Instance.new("Part")
	podium.Name = "Podium"
	podium.Shape = Enum.PartType.Cylinder
	podium.Size = Vector3.new(4, 5, 5)
	podium.Position = Vector3.new(cx, 2, cz)
	podium.Orientation = Vector3.new(0, 0, 0)
	podium.Color = Color3.fromHex("#1A0A12")
	podium.Material = Enum.Material.Metal
	podium.Anchored = true
	podium.Parent = room

	-- Dramatic spotlight from ceiling onto podium
	local spotPart = MansionBuilder.createPart(room, "SpotlightMount",
		Vector3.new(cx, WALL_HEIGHT - 1, cz),
		Vector3.new(2, 1, 2), DARK)
	spotPart.CanCollide = false
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Brightness = 5
	spot.Range = 30
	spot.Angle = 35
	spot.Color = Color3.new(1, 1, 1)
	spot.Parent = spotPart

	-- Pink neon rings on floor around podium (2 concentric)
	for ring = 1, 2 do
		local r = 5 + ring * 4
		for seg = 1, 12 do
			local a1 = (seg - 1) * (2 * math.pi / 12)
			local a2 = seg * (2 * math.pi / 12)
			local midA = (a1 + a2) / 2
			local nx = cx + math.cos(midA) * r
			local nz = cz + math.sin(midA) * r
			local segLen = 2 * r * math.sin(math.pi / 12)
			local neonSeg = MansionBuilder.createNeon(room, "Ring" .. ring .. "_" .. seg,
				Vector3.new(nx, 0.15, nz),
				Vector3.new(segLen, 0.3, 0.5), NEON_PINK)
			neonSeg.Orientation = Vector3.new(0, math.deg(midA), 0)
		end
	end

	-- 4 arched alcoves with warm amber lights
	local alcovePositions = {
		{x = cx - roomW / 2 + 3, z = cz - 10, dir = Vector3.new(1, 0, 0)},
		{x = cx - roomW / 2 + 3, z = cz + 10, dir = Vector3.new(1, 0, 0)},
		{x = cx + roomW / 2 - 3, z = cz - 10, dir = Vector3.new(-1, 0, 0)},
		{x = cx + roomW / 2 - 3, z = cz + 10, dir = Vector3.new(-1, 0, 0)},
	}
	for i, alc in ipairs(alcovePositions) do
		-- Arch frame
		MansionBuilder.createPart(room, "AlcoveL" .. i,
			Vector3.new(alc.x, 4, alc.z - 3),
			Vector3.new(1, 8, 1), GOLD, Enum.Material.Metal)
		MansionBuilder.createPart(room, "AlcoveR" .. i,
			Vector3.new(alc.x, 4, alc.z + 3),
			Vector3.new(1, 8, 1), GOLD, Enum.Material.Metal)
		MansionBuilder.createPart(room, "AlcoveTop" .. i,
			Vector3.new(alc.x, 8.5, alc.z),
			Vector3.new(1, 1, 7), GOLD, Enum.Material.Metal)

		-- Warm light
		local alcLight = MansionBuilder.createNeon(room, "AlcoveLight" .. i,
			Vector3.new(alc.x, 7, alc.z),
			Vector3.new(0.5, 0.5, 0.5), AMBER)
		local alcPL = Instance.new("PointLight")
		alcPL.Color = Color3.fromHex("#FFAA44")
		alcPL.Brightness = 2
		alcPL.Range = 20
		alcPL.Parent = alcLight

		-- Flower vase in alcove
		MansionBuilder.createFlowerVase(room, Vector3.new(alc.x, 0, alc.z))
	end

	-- Seating area (semi-circle facing podium)
	for i = 1, 8 do
		local angle = math.rad(180 + (i - 1) * 22.5)
		local seatR = 16
		local sx = cx + math.cos(angle) * seatR
		local sz = cz + math.sin(angle) * seatR
		MansionBuilder.createPart(room, "Seat" .. i,
			Vector3.new(sx, 1.5, sz),
			Vector3.new(3, 3, 3), COUCH_CREAM, Enum.Material.Fabric)
	end

	-- "ELIMINATION" sign
	MansionBuilder.createSign(room, "ELIMINATION",
		Vector3.new(cx, WALL_HEIGHT - 2, cz + roomD / 2 - 1), 14, CRIMSON)
	MansionBuilder.createNeon(room, "EliminationGlow",
		Vector3.new(cx, WALL_HEIGHT - 2, cz + roomD / 2 - 0.5),
		Vector3.new(16, 4, 0.3), CRIMSON)

	-- Fog/atmosphere effect (dark neon near floor for darkness)
	local fog = MansionBuilder.createNeon(room, "FloorFog",
		Vector3.new(cx, 0.1, cz),
		Vector3.new(roomW - 4, 0.15, roomD - 4), Color3.fromHex("#050208"))
	fog.Transparency = 0.5
end

-- ============================================================
-- LIVING ROOM — Multiple seating areas, Tea Wall
-- ============================================================

function MansionBuilder.buildLivingRoom(parent)
	local cx, cz = 60, 30
	local roomW, roomD = ROOM_SIZE, ROOM_SIZE

	local room = MansionBuilder.createRoomShell(parent, "LivingRoom",
		cx, FLOOR_Y, cz, roomW, roomD, WALL_HEIGHT,
		MARBLE_WHITE, WALL_COLOR, DARK)

	-- Sign
	MansionBuilder.createSign(room, "THE LIVING ROOM",
		Vector3.new(cx, WALL_HEIGHT - 2, cz - roomD / 2 + 1), 12, NEON_PINK)

	-- L-shaped sectional couch (cream/beige)
	MansionBuilder.createCouch(room,
		Vector3.new(cx - 10, 1.5, cz + 10),
		Vector3.new(14, 2.5, 5), Vector3.new(0, 0, 0), COUCH_CREAM)
	MansionBuilder.createCouch(room,
		Vector3.new(cx - 15, 1.5, cz + 4),
		Vector3.new(8, 2.5, 5), Vector3.new(0, 90, 0), COUCH_CREAM)

	-- Round rug under seating (circular thin part)
	local rug = Instance.new("Part")
	rug.Name = "Rug"
	rug.Shape = Enum.PartType.Cylinder
	rug.Size = Vector3.new(0.3, 18, 18)
	rug.Position = Vector3.new(cx - 8, 0.15, cz + 6)
	rug.Orientation = Vector3.new(0, 0, 90)
	rug.Color = Color3.fromHex("#3A2840")
	rug.Material = Enum.Material.Fabric
	rug.Anchored = true
	rug.CanCollide = false
	rug.Parent = room

	-- Tea Wall: Large flat screen TV on north wall
	local teaWall = MansionBuilder.createPart(room, "TeaWallTV",
		Vector3.new(cx - 5, 7, cz + roomD / 2 - 0.8),
		Vector3.new(20, 12, 0.5), Color3.fromHex("#0D0D0D"))

	-- SurfaceGui for confessions
	local tvGui = Instance.new("SurfaceGui")
	tvGui.Face = Enum.NormalId.Back
	tvGui.Parent = teaWall
	local tvLabel = Instance.new("TextLabel")
	tvLabel.Size = UDim2.new(1, 0, 1, 0)
	tvLabel.BackgroundColor3 = Color3.fromHex("#0D0D0D")
	tvLabel.Text = "TEA WALL\n\nConfessions will appear here..."
	tvLabel.TextColor3 = NEON_PINK
	tvLabel.TextScaled = true
	tvLabel.Font = Enum.Font.GothamBold
	tvLabel.Parent = tvGui

	-- "TEA WALL" neon sign above TV
	MansionBuilder.createSign(room, "TEA WALL",
		Vector3.new(cx - 5, 13.5, cz + roomD / 2 - 0.5), 8, GOLD_BRIGHT)

	-- TV frame (gold border)
	MansionBuilder.createNeon(room, "TVFrameTop",
		Vector3.new(cx - 5, 13.1, cz + roomD / 2 - 0.8), Vector3.new(20.5, 0.3, 0.6), GOLD)
	MansionBuilder.createNeon(room, "TVFrameBot",
		Vector3.new(cx - 5, 0.9, cz + roomD / 2 - 0.8), Vector3.new(20.5, 0.3, 0.6), GOLD)
	MansionBuilder.createNeon(room, "TVFrameL",
		Vector3.new(cx - 15.2, 7, cz + roomD / 2 - 0.8), Vector3.new(0.3, 12.5, 0.6), GOLD)
	MansionBuilder.createNeon(room, "TVFrameR",
		Vector3.new(cx + 5.2, 7, cz + roomD / 2 - 0.8), Vector3.new(0.3, 12.5, 0.6), GOLD)

	-- Gold frame mirror on west wall
	MansionBuilder.createArtFrame(room,
		Vector3.new(cx - roomW / 2 + 0.5, 7, cz + 5),
		Vector3.new(0.3, 6, 4))
	local mirror = MansionBuilder.createPart(room, "Mirror",
		Vector3.new(cx - roomW / 2 + 0.8, 7, cz + 5),
		Vector3.new(0.2, 5.5, 3.5), Color3.new(0.8, 0.85, 0.9), Enum.Material.Glass)
	mirror.Reflectance = 0.8
	mirror.Transparency = 0.1

	-- Bookshelf/display shelf on east side
	MansionBuilder.createPart(room, "BookshelfBack",
		Vector3.new(cx + roomW / 2 - 2, 5, cz - 5),
		Vector3.new(3, 10, 8), WALL_LIGHT)
	for s = 1, 4 do
		MansionBuilder.createPart(room, "Shelf" .. s,
			Vector3.new(cx + roomW / 2 - 2, 1.5 + s * 2.2, cz - 5),
			Vector3.new(3.2, 0.3, 8.2), GOLD, Enum.Material.Metal)
	end
	-- Books (colored rectangles)
	local bookColors = {CRIMSON, PURPLE, SKY_BLUE, GOLD_BRIGHT, NEON_PINK}
	for s = 1, 3 do
		for b = 1, 5 do
			MansionBuilder.createPart(room, "Book" .. s .. "_" .. b,
				Vector3.new(cx + roomW / 2 - 2, 2.2 + s * 2.2, cz - 8 + b * 1.5),
				Vector3.new(1.2, 1.8, 0.8),
				bookColors[((s + b - 2) % #bookColors) + 1])
		end
	end

	-- Plants in corners
	MansionBuilder.createPlant(room, Vector3.new(cx + roomW / 2 - 3, 0, cz + roomD / 2 - 3), 7)
	MansionBuilder.createPlant(room, Vector3.new(cx - roomW / 2 + 3, 0, cz - roomD / 2 + 3), 6)

	-- Neon accent strips along floor
	MansionBuilder.createNeon(room, "AccentGlow",
		Vector3.new(cx, 0.1, cz),
		Vector3.new(10, 0.15, 10), NEON_PINK)

	-- Coffee table
	MansionBuilder.createPart(room, "CoffeeTable",
		Vector3.new(cx - 8, 1.5, cz + 4),
		Vector3.new(5, 1.5, 3), GOLD, Enum.Material.Metal)
	local ctTop = MansionBuilder.createPart(room, "CoffeeTableTop",
		Vector3.new(cx - 8, 2.4, cz + 4),
		Vector3.new(5.5, 0.3, 3.5), GLASS_BLUE, Enum.Material.Glass)
	ctTop.Transparency = 0.4
end

-- ============================================================
-- DRAMA ROOM — Red/crimson themed confrontation arena
-- ============================================================

function MansionBuilder.buildDramaRoom(parent)
	local cx, cz = 60, -35
	local roomW, roomD = ROOM_SIZE, ROOM_SIZE

	local room = MansionBuilder.createRoomShell(parent, "DramaRoom",
		cx, FLOOR_Y, cz, roomW, roomD, WALL_HEIGHT,
		MARBLE_DARK, Color3.fromHex("#1A0A0A"), DARK, Enum.Material.Marble)

	-- "THE DRAMA ROOM" neon sign
	MansionBuilder.createSign(room, "THE DRAMA ROOM",
		Vector3.new(cx, WALL_HEIGHT - 2, cz + roomD / 2 - 1), 14, CRIMSON)
	MansionBuilder.createNeon(room, "DramaSignGlow",
		Vector3.new(cx, WALL_HEIGHT - 2, cz + roomD / 2 - 0.5),
		Vector3.new(16, 4, 0.3), CRIMSON)

	-- Dramatic red lighting (floor glow)
	MansionBuilder.createNeon(room, "RedFloorGlow",
		Vector3.new(cx, 0.15, cz),
		Vector3.new(roomW - 6, 0.2, roomD - 6), CRIMSON)

	-- Stage/platform area (raised)
	MansionBuilder.createPart(room, "Stage",
		Vector3.new(cx, 1, cz + 5),
		Vector3.new(18, 2, 18), Color3.fromHex("#1A0A0A"), Enum.Material.Marble)

	-- Boxing ring-style roped area for confrontations
	local ringCx, ringCz = cx, cz + 5
	local ringHalf = 8
	local postPositions = {
		Vector3.new(ringCx - ringHalf, 4, ringCz - ringHalf),
		Vector3.new(ringCx + ringHalf, 4, ringCz - ringHalf),
		Vector3.new(ringCx + ringHalf, 4, ringCz + ringHalf),
		Vector3.new(ringCx - ringHalf, 4, ringCz + ringHalf),
	}
	for i, ppos in ipairs(postPositions) do
		local post = Instance.new("Part")
		post.Name = "RingPost" .. i
		post.Shape = Enum.PartType.Cylinder
		post.Size = Vector3.new(6, 1.5, 1.5)
		post.Position = ppos
		post.Color = GOLD
		post.Material = Enum.Material.Metal
		post.Anchored = true
		post.Parent = room
	end

	-- Ropes between posts (3 levels)
	local ropeConnections = {{1, 2}, {2, 3}, {3, 4}, {4, 1}}
	for _, conn in ipairs(ropeConnections) do
		local p1 = postPositions[conn[1]]
		local p2 = postPositions[conn[2]]
		local mid = (p1 + p2) / 2
		local diff = p2 - p1
		local length = diff.Magnitude
		local angle = math.deg(math.atan2(diff.X, diff.Z))

		for ropeLevel = 1, 3 do
			local ropeY = 2.5 + ropeLevel * 1.2
			local rope = MansionBuilder.createNeon(room, "Rope" .. conn[1] .. conn[2] .. "_" .. ropeLevel,
				Vector3.new(mid.X, ropeY, mid.Z),
				Vector3.new(length, 0.3, 0.3), CRIMSON)
			rope.Orientation = Vector3.new(0, angle, 0)
		end
	end

	-- Audience seating (rows of seats)
	for row = 1, 3 do
		for seat = 1, 6 do
			local sx = cx - 12 + seat * 4
			local sz = cz - 10 - row * 3
			MansionBuilder.createPart(room, "AudienceSeat_R" .. row .. "S" .. seat,
				Vector3.new(sx, 1.2 + row * 0.5, sz),
				Vector3.new(3, 2.5, 2.5), COUCH_CREAM, Enum.Material.Fabric)
		end
	end

	-- Dramatic red spotlights on ring
	for i = 1, 2 do
		local slX = cx + (i == 1 and -5 or 5)
		local slPart = MansionBuilder.createPart(room, "RedSpot" .. i,
			Vector3.new(slX, WALL_HEIGHT - 1, cz + 5),
			Vector3.new(1.5, 1, 1.5), CRIMSON, Enum.Material.Neon)
		slPart.CanCollide = false
		local sl = Instance.new("SpotLight")
		sl.Face = Enum.NormalId.Bottom
		sl.Brightness = 4
		sl.Range = 25
		sl.Angle = 45
		sl.Color = CRIMSON
		sl.Parent = slPart
	end
end

-- ============================================================
-- ELEVATOR — Glass, gold-framed, TweenService powered
-- ============================================================

function MansionBuilder.buildElevator(parent)
	local elev = Instance.new("Folder")
	elev.Name = "Elevator"
	elev.Parent = parent

	local ex, ez = 195, 0
	local shaftW, shaftD = 12, 12
	local shaftHeight = FLOOR2_Y + WALL_HEIGHT + 10

	-- Elevator shaft walls (glass + gold frame)
	-- Back wall
	local shaftBack = MansionBuilder.createPart(elev, "ShaftBack",
		Vector3.new(ex, shaftHeight / 2, ez + shaftD / 2),
		Vector3.new(shaftW, shaftHeight, 0.5),
		GLASS_BLUE, Enum.Material.Glass)
	shaftBack.Transparency = 0.5

	-- Left wall
	local shaftLeft = MansionBuilder.createPart(elev, "ShaftLeft",
		Vector3.new(ex - shaftW / 2, shaftHeight / 2, ez),
		Vector3.new(0.5, shaftHeight, shaftD),
		GLASS_BLUE, Enum.Material.Glass)
	shaftLeft.Transparency = 0.5

	-- Right wall
	local shaftRight = MansionBuilder.createPart(elev, "ShaftRight",
		Vector3.new(ex + shaftW / 2, shaftHeight / 2, ez),
		Vector3.new(0.5, shaftHeight, shaftD),
		GLASS_BLUE, Enum.Material.Glass)
	shaftRight.Transparency = 0.5

	-- Gold frame edges (vertical)
	local framePositions = {
		Vector3.new(ex - shaftW / 2, shaftHeight / 2, ez - shaftD / 2),
		Vector3.new(ex + shaftW / 2, shaftHeight / 2, ez - shaftD / 2),
		Vector3.new(ex - shaftW / 2, shaftHeight / 2, ez + shaftD / 2),
		Vector3.new(ex + shaftW / 2, shaftHeight / 2, ez + shaftD / 2),
	}
	for i, fpos in ipairs(framePositions) do
		MansionBuilder.createPart(elev, "Frame" .. i, fpos,
			Vector3.new(0.8, shaftHeight, 0.8), GOLD, Enum.Material.Metal)
	end

	-- Moving platform
	local platform = MansionBuilder.createPart(elev, "ElevatorPlatform",
		Vector3.new(ex, 0.5, ez),
		Vector3.new(shaftW - 1, 1, shaftD - 1), MARBLE_WHITE, Enum.Material.Marble)

	-- Floor indicator signs
	MansionBuilder.createSign(elev, "G", Vector3.new(ex - shaftW / 2 - 1, 3, ez), 3, GOLD)
	MansionBuilder.createSign(elev, "2", Vector3.new(ex - shaftW / 2 - 1, FLOOR2_Y + 3, ez), 3, GOLD)
	MansionBuilder.createSign(elev, "R", Vector3.new(ex - shaftW / 2 - 1, FLOOR2_Y + WALL_HEIGHT + 5, ez), 3, GOLD)

	-- "ELEVATOR" sign
	MansionBuilder.createSign(elev, "ELEVATOR",
		Vector3.new(ex, 10, ez - shaftD / 2 - 1), 6, GOLD)

	-- Call buttons at each floor level
	local floorYPositions = {
		{y = 3, name = "CallGround"},
		{y = FLOOR2_Y + 2, name = "CallFloor2"},
		{y = FLOOR2_Y + WALL_HEIGHT + 4, name = "CallRooftop"},
	}
	for _, floorData in ipairs(floorYPositions) do
		local button = MansionBuilder.createPart(elev, floorData.name,
			Vector3.new(ex - shaftW / 2 - 1.5, floorData.y, ez),
			Vector3.new(1, 1.5, 1.5), GOLD, Enum.Material.Metal)

		local click = Instance.new("ClickDetector")
		click.MaxActivationDistance = 15
		click.Parent = button

		-- Neon indicator
		MansionBuilder.createNeon(elev, floorData.name .. "Light",
			Vector3.new(ex - shaftW / 2 - 1.5, floorData.y + 1, ez),
			Vector3.new(0.5, 0.5, 0.5), GOLD_BRIGHT)
	end

	-- Interior light
	local elevLight = MansionBuilder.createNeon(elev, "InteriorLight",
		Vector3.new(ex, shaftHeight - 2, ez),
		Vector3.new(4, 0.3, 4), GOLD_BRIGHT)
	local elevPL = Instance.new("PointLight")
	elevPL.Color = Color3.fromHex("#FFEEDD")
	elevPL.Brightness = 1.5
	elevPL.Range = 20
	elevPL.Parent = elevLight

	-- Wire elevator movement directly (no Script.Source needed)
	local TweenService = game:GetService("TweenService")
	local elevPlatform = elev:FindFirstChild("ElevatorPlatform")

	local FLOOR_POSITIONS = {
		Ground = 0.5,
		Floor2 = FLOOR2_Y + 0.5,
		Rooftop = FLOOR2_Y + WALL_HEIGHT + 2.5,
	}

	local isMoving = false
	local currentFloor = "Ground"

	local function moveToFloor(targetFloor)
		if isMoving then return end
		if currentFloor == targetFloor then return end
		isMoving = true

		local targetY = FLOOR_POSITIONS[targetFloor]
		if elevPlatform then
			local tweenInfo = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
			local tween = TweenService:Create(elevPlatform, tweenInfo, {
				Position = Vector3.new(elevPlatform.Position.X, targetY, elevPlatform.Position.Z)
			})
			tween:Play()
			tween.Completed:Wait()
		end
		currentFloor = targetFloor
		isMoving = false
	end

	-- Connect call buttons
	task.spawn(function()
		local callGround = elev:FindFirstChild("CallGround")
		local callFloor2 = elev:FindFirstChild("CallFloor2")
		local callRooftop = elev:FindFirstChild("CallRooftop")

		if callGround then
			local cd = callGround:FindFirstChildOfClass("ClickDetector")
			if cd then cd.MouseClick:Connect(function() moveToFloor("Ground") end) end
		end
		if callFloor2 then
			local cd = callFloor2:FindFirstChildOfClass("ClickDetector")
			if cd then cd.MouseClick:Connect(function() moveToFloor("Floor2") end) end
		end
		if callRooftop then
			local cd = callRooftop:FindFirstChildOfClass("ClickDetector")
			if cd then cd.MouseClick:Connect(function() moveToFloor("Rooftop") end) end
		end
	end)
end

-- ============================================================
-- BEDROOMS (Upper Floor) — Enhanced with luxury furnishings
-- ============================================================

function MansionBuilder.buildBedroomFloor(parent)
	local floor2 = Instance.new("Folder")
	floor2.Name = "BedroomFloor"
	floor2.Parent = parent

	-- Upper floor corridor base
	MansionBuilder.createPart(floor2, "Floor",
		Vector3.new(110, FLOOR2_Y - 0.5, 0),
		Vector3.new(170, 1, 18), MARBLE_WHITE, Enum.Material.Marble)
	MansionBuilder.createPart(floor2, "Ceiling",
		Vector3.new(110, FLOOR2_Y + WALL_HEIGHT, 0),
		Vector3.new(170, 1, 18), DARK)

	-- Upper corridor walls (north and south) with doorways to bedrooms
	-- Rooms 1-5 are north (positive Z), rooms 6-10 are south (negative Z)
	-- Bedroom positions: col = (roomNum-1) for 1-5, (roomNum-6) for 6-10
	-- cx = 40 + col * 32

	local northDoorPositions = {}
	local southDoorPositions = {}
	for i = 1, 10 do
		local col = i <= 5 and (i - 1) or (i - 6)
		local doorX = 40 + col * 32
		if i <= 5 then
			table.insert(northDoorPositions, doorX)
		else
			table.insert(southDoorPositions, doorX)
		end
	end

	-- Build north corridor wall with doorways
	MansionBuilder._buildSegmentedWall(floor2, "UpperCorrN",
		25, 195,           -- X range
		FLOOR2_Y + WALL_HEIGHT / 2, 9,  -- Y center, Z position (north side of 18-wide corridor)
		WALL_HEIGHT, 1,
		northDoorPositions, DOORWAY_WIDTH, DOORWAY_HEIGHT,
		WALL_COLOR, true)

	-- Build south corridor wall with doorways
	MansionBuilder._buildSegmentedWall(floor2, "UpperCorrS",
		25, 195,
		FLOOR2_Y + WALL_HEIGHT / 2, -9,
		WALL_HEIGHT, 1,
		southDoorPositions, DOORWAY_WIDTH, DOORWAY_HEIGHT,
		WALL_COLOR, true)

	-- Upper corridor gold trim
	MansionBuilder.createNeon(floor2, "UpperTrimN",
		Vector3.new(110, FLOOR2_Y + 0.1, 8.5),
		Vector3.new(170, 0.2, 0.3), GOLD)
	MansionBuilder.createNeon(floor2, "UpperTrimS",
		Vector3.new(110, FLOOR2_Y + 0.1, -8.5),
		Vector3.new(170, 0.2, 0.3), GOLD)
	MansionBuilder.createNeon(floor2, "UpperCeilTrimN",
		Vector3.new(110, FLOOR2_Y + WALL_HEIGHT - 0.3, 8.5),
		Vector3.new(170, 0.2, 0.3), GOLD)
	MansionBuilder.createNeon(floor2, "UpperCeilTrimS",
		Vector3.new(110, FLOOR2_Y + WALL_HEIGHT - 0.3, -8.5),
		Vector3.new(170, 0.2, 0.3), GOLD)

	-- "BEDROOMS" sign
	MansionBuilder.createSign(floor2, "BEDROOMS",
		Vector3.new(30, FLOOR2_Y + 8, 0), 12, GOLD)

	-- Wall sconces in upper corridor
	for x = 35, 190, 20 do
		MansionBuilder.createSconce(floor2, Vector3.new(x, FLOOR2_Y + 8, 8), Vector3.new(0, 0, -1))
		MansionBuilder.createSconce(floor2, Vector3.new(x, FLOOR2_Y + 8, -8), Vector3.new(0, 0, 1))
	end

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
	local cx = 40 + col * 32
	local cz = side * 25
	local bw, bd = 28, 22

	-- Room shell
	local floorColor = config.exile and Color3.new(0.08, 0.08, 0.08) or MARBLE_WHITE
	local wallCol = config.exile and Color3.fromHex("#0A0A0A") or WALL_COLOR

	MansionBuilder.createPart(room, "Floor",
		Vector3.new(cx, FLOOR2_Y - 0.5, cz),
		Vector3.new(bw, 1, bd), floorColor, Enum.Material.Marble)
	MansionBuilder.createPart(room, "Ceiling",
		Vector3.new(cx, FLOOR2_Y + WALL_HEIGHT, cz),
		Vector3.new(bw, 1, bd), DARK)
	MansionBuilder.createPart(room, "WallBack",
		Vector3.new(cx, FLOOR2_Y + WALL_HEIGHT / 2, cz + side * bd / 2),
		Vector3.new(bw, WALL_HEIGHT, 1), wallCol)
	MansionBuilder.createPart(room, "WallLeft",
		Vector3.new(cx - bw / 2, FLOOR2_Y + WALL_HEIGHT / 2, cz),
		Vector3.new(1, WALL_HEIGHT, bd), wallCol)
	MansionBuilder.createPart(room, "WallRight",
		Vector3.new(cx + bw / 2, FLOOR2_Y + WALL_HEIGHT / 2, cz),
		Vector3.new(1, WALL_HEIGHT, bd), wallCol)

	-- Front wall (corridor side) — has doorway, built by the corridor wall segments
	-- So we do NOT add a front wall here; the corridor wall handles it

	-- Room-colored accent wall (back wall overlay strip)
	MansionBuilder.createPart(room, "AccentWall",
		Vector3.new(cx, FLOOR2_Y + WALL_HEIGHT / 2, cz + side * (bd / 2 - 0.3)),
		Vector3.new(bw - 2, WALL_HEIGHT - 2, 0.3), config.color)

	-- Room name sign
	MansionBuilder.createSign(room, config.name,
		Vector3.new(cx, FLOOR2_Y + WALL_HEIGHT - 2, cz - side * (bd / 2 - 1)), 10, config.color)
	-- Room number
	MansionBuilder.createSign(room, "#" .. roomNum,
		Vector3.new(cx - bw / 2 + 3, FLOOR2_Y + 5, cz - side * (bd / 2 - 1)), 3, GOLD)

	-- Accent neon strip along floor
	MansionBuilder.createNeon(room, "Accent",
		Vector3.new(cx, FLOOR2_Y + 0.1, cz + side * (bd / 2 - 1)),
		Vector3.new(bw - 2, 0.2, 0.3), config.color)

	-- Rug under beds
	local rug = Instance.new("Part")
	rug.Name = "Rug"
	rug.Shape = Enum.PartType.Cylinder
	rug.Size = Vector3.new(0.3, 16, 10)
	rug.Position = Vector3.new(cx, FLOOR2_Y + 0.15, cz + side * 4)
	rug.Orientation = Vector3.new(0, 0, 90)
	rug.Color = config.exile and Color3.new(0.1, 0.1, 0.1) or Color3.fromHex("#3A2840")
	rug.Material = Enum.Material.Fabric
	rug.Anchored = true
	rug.CanCollide = false
	rug.Parent = room

	if config.master then
		-- ===== CROWN SUITE: Extra large, golden everything =====
		MansionBuilder.createPart(room, "BedFrame",
			Vector3.new(cx, FLOOR2_Y + 1, cz + side * 5),
			Vector3.new(12, 2, 10), GOLD, Enum.Material.Metal)
		MansionBuilder.createPart(room, "Mattress",
			Vector3.new(cx, FLOOR2_Y + 2.5, cz + side * 5),
			Vector3.new(11, 1.5, 9), CREAM, Enum.Material.Fabric)
		MansionBuilder.createPart(room, "Headboard",
			Vector3.new(cx, FLOOR2_Y + 5, cz + side * 9.5),
			Vector3.new(12, 6, 1), GOLD, Enum.Material.Metal)
		MansionBuilder.createPart(room, "Pillow1",
			Vector3.new(cx - 3, FLOOR2_Y + 3.5, cz + side * 8),
			Vector3.new(3, 1, 2), GOLD_BRIGHT, Enum.Material.Fabric)
		MansionBuilder.createPart(room, "Pillow2",
			Vector3.new(cx + 3, FLOOR2_Y + 3.5, cz + side * 8),
			Vector3.new(3, 1, 2), CREAM, Enum.Material.Fabric)

		-- Throne chair
		MansionBuilder.createPart(room, "ThroneBase",
			Vector3.new(cx - 8, FLOOR2_Y + 1.5, cz - side * 2),
			Vector3.new(4, 3, 4), GOLD, Enum.Material.Metal)
		MansionBuilder.createPart(room, "ThroneBack",
			Vector3.new(cx - 8, FLOOR2_Y + 5, cz - side * 3.5),
			Vector3.new(4, 6, 1), GOLD, Enum.Material.Metal)
		MansionBuilder.createPart(room, "ThroneCushion",
			Vector3.new(cx - 8, FLOOR2_Y + 3.2, cz - side * 2),
			Vector3.new(3.5, 0.8, 3.5), CRIMSON, Enum.Material.Fabric)

		-- Chandelier
		MansionBuilder.createChandelier(room,
			Vector3.new(cx, FLOOR2_Y + WALL_HEIGHT - 2, cz + side * 3), 5, GOLD_BRIGHT)

		-- Nightstands with lamps (both sides)
		for ns = -1, 1, 2 do
			MansionBuilder.createPart(room, "Nightstand" .. (ns == -1 and "L" or "R"),
				Vector3.new(cx + ns * 8, FLOOR2_Y + 1, cz + side * 5),
				Vector3.new(2.5, 2, 2.5), GOLD, Enum.Material.Metal)
			local lamp = MansionBuilder.createPart(room, "Lamp" .. (ns == -1 and "L" or "R"),
				Vector3.new(cx + ns * 8, FLOOR2_Y + 3, cz + side * 5),
				Vector3.new(1, 2, 1), AMBER, Enum.Material.Neon)
			lamp.CanCollide = false
			local lpl = Instance.new("PointLight")
			lpl.Color = Color3.fromHex("#FFEEDD")
			lpl.Brightness = 1
			lpl.Range = 15
			lpl.Parent = lamp
		end

		-- Crown neon glow
		MansionBuilder.createNeon(room, "CrownGlow",
			Vector3.new(cx, FLOOR2_Y + WALL_HEIGHT - 1, cz + side * 3),
			Vector3.new(10, 0.3, 10), GOLD_BRIGHT)

		-- Mirror
		local crownMirror = MansionBuilder.createPart(room, "Mirror",
			Vector3.new(cx + bw / 2 - 1, FLOOR2_Y + 6, cz),
			Vector3.new(0.3, 5, 4), Color3.new(0.8, 0.85, 0.9), Enum.Material.Glass)
		crownMirror.Reflectance = 0.8

	elseif config.exile then
		-- ===== DOG HOUSE: Bare, cold, single dim light =====
		MansionBuilder.createPart(room, "Mattress1",
			Vector3.new(cx - 5, FLOOR2_Y + 0.3, cz + side * 4),
			Vector3.new(4, 0.5, 7), Color3.new(0.15, 0.15, 0.15), Enum.Material.Fabric)
		MansionBuilder.createPart(room, "Mattress2",
			Vector3.new(cx + 5, FLOOR2_Y + 0.3, cz + side * 4),
			Vector3.new(4, 0.5, 7), Color3.new(0.15, 0.15, 0.15), Enum.Material.Fabric)

		MansionBuilder.createPart(room, "SadPillow1",
			Vector3.new(cx - 5, FLOOR2_Y + 0.7, cz + side * 7),
			Vector3.new(2, 0.3, 1.5), Color3.new(0.25, 0.25, 0.25), Enum.Material.Fabric)
		MansionBuilder.createPart(room, "SadPillow2",
			Vector3.new(cx + 5, FLOOR2_Y + 0.7, cz + side * 7),
			Vector3.new(2, 0.3, 1.5), Color3.new(0.25, 0.25, 0.25), Enum.Material.Fabric)

		local dimBulb = MansionBuilder.createPart(room, "DimBulb",
			Vector3.new(cx, FLOOR2_Y + WALL_HEIGHT - 1, cz),
			Vector3.new(1, 1, 1), Color3.new(0.3, 0.3, 0.2), Enum.Material.Neon)
		dimBulb.CanCollide = false
		local dimLight = Instance.new("PointLight")
		dimLight.Color = Color3.new(0.4, 0.35, 0.2)
		dimLight.Brightness = 0.3
		dimLight.Range = 15
		dimLight.Parent = dimBulb

		MansionBuilder.createSign(room, "You know what you did.",
			Vector3.new(cx, FLOOR2_Y + 5, cz + side * (bd / 2 - 1.5)), 10, Color3.new(0.3, 0.3, 0.3))

	else
		-- ===== STANDARD LUXURY BEDROOM =====
		for bedI = -1, 1, 2 do
			local bx = cx + bedI * 6

			MansionBuilder.createPart(room, "BedFrame" .. (bedI == -1 and "1" or "2"),
				Vector3.new(bx, FLOOR2_Y + 0.8, cz + side * 5),
				Vector3.new(6, 1.5, 9), config.color, Enum.Material.SmoothPlastic)
			MansionBuilder.createPart(room, "Mattress" .. (bedI == -1 and "1" or "2"),
				Vector3.new(bx, FLOOR2_Y + 2, cz + side * 5),
				Vector3.new(5.5, 1, 8.5), CREAM, Enum.Material.Fabric)
			MansionBuilder.createPart(room, "Headboard" .. (bedI == -1 and "1" or "2"),
				Vector3.new(bx, FLOOR2_Y + 4, cz + side * 9),
				Vector3.new(6, 4, 0.8), config.color, Enum.Material.SmoothPlastic)
			MansionBuilder.createPart(room, "Pillow" .. (bedI == -1 and "1" or "2"),
				Vector3.new(bx, FLOOR2_Y + 2.8, cz + side * 8),
				Vector3.new(3, 0.6, 2), Color3.new(1, 1, 1), Enum.Material.Fabric)
		end

		-- Nightstand between beds with lamp
		MansionBuilder.createPart(room, "Nightstand",
			Vector3.new(cx, FLOOR2_Y + 1, cz + side * 5),
			Vector3.new(2.5, 2, 2.5), GOLD, Enum.Material.Metal)
		local lamp = MansionBuilder.createPart(room, "Lamp",
			Vector3.new(cx, FLOOR2_Y + 3, cz + side * 5),
			Vector3.new(1, 2, 1), AMBER, Enum.Material.Neon)
		lamp.CanCollide = false
		local lpl = Instance.new("PointLight")
		lpl.Color = Color3.fromHex("#FFEEDD")
		lpl.Brightness = 1
		lpl.Range = 18
		lpl.Parent = lamp

		-- Mirror on wall
		local bedroomMirror = MansionBuilder.createPart(room, "Mirror",
			Vector3.new(cx - bw / 2 + 1, FLOOR2_Y + 6, cz - side * 2),
			Vector3.new(0.3, 4, 3), Color3.new(0.8, 0.85, 0.9), Enum.Material.Glass)
		bedroomMirror.Reflectance = 0.7
		MansionBuilder.createPart(room, "MirrorFrame",
			Vector3.new(cx - bw / 2 + 1, FLOOR2_Y + 6, cz - side * 2),
			Vector3.new(0.35, 4.5, 3.5), GOLD, Enum.Material.Metal)
	end
end

-- ============================================================
-- LIGHTING SETUP
-- ============================================================

function MansionBuilder.setupLighting()
	local lighting = game:GetService("Lighting")
	lighting.ClockTime = 21
	lighting.Ambient = Color3.fromHex("#2A1E35")
	lighting.OutdoorAmbient = Color3.fromHex("#1A1225")
	lighting.Brightness = 1.5
	lighting.FogEnd = 1000
	lighting.FogColor = Color3.fromHex("#0A0610")
	lighting.GlobalShadows = true
	lighting.EnvironmentDiffuseScale = 0.5
	lighting.EnvironmentSpecularScale = 0.3

	-- Bloom for that lush neon glow
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 30
	bloom.Threshold = 0.65
	bloom.Parent = lighting

	-- Color correction for warm luxury mood
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.3
	cc.Contrast = 0.1
	cc.TintColor = Color3.fromHex("#F0E0FF")
	cc.Parent = lighting

	-- Atmosphere for outdoor depth
	local atmo = Instance.new("Atmosphere")
	atmo.Density = 0.15
	atmo.Offset = 0.5
	atmo.Color = Color3.fromHex("#1A1030")
	atmo.Decay = Color3.fromHex("#2A1E40")
	atmo.Glare = 0.2
	atmo.Haze = 2
	atmo.Parent = lighting

	-- Depth of field for cinematic feel
	local dof = Instance.new("DepthOfFieldEffect")
	dof.FarIntensity = 0.05
	dof.FocusDistance = 50
	dof.InFocusRadius = 30
	dof.NearIntensity = 0
	dof.Parent = lighting

	-- Sun rays for drama
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.05
	rays.Spread = 0.3
	rays.Parent = lighting
end

-- ============================================================
-- ROOM LIGHTS — Add ceiling PointLights to rooms
-- ============================================================

function MansionBuilder.addRoomLights(parent, cx, cy, cz, color, range)
	local light = Instance.new("Part")
	light.Name = "CeilingLight"
	light.Size = Vector3.new(3, 0.3, 3)
	light.Position = Vector3.new(cx, cy - 1.5, cz)
	light.Color = color or GOLD
	light.Material = Enum.Material.Neon
	light.Anchored = true
	light.CanCollide = false
	light.Parent = parent

	local pl = Instance.new("PointLight")
	pl.Color = color or Color3.fromHex("#FFEEDD")
	pl.Brightness = 1.8
	pl.Range = range or 40
	pl.Parent = light
end

-- ============================================================
-- ADD ALL LIGHTS — Master lighting pass after build
-- ============================================================

function MansionBuilder.addAllLights(mansion)
	-- Ground floor lights
	MansionBuilder.addRoomLights(mansion, 20, WALL_HEIGHT, 0, GOLD, 55)          -- Lobby
	MansionBuilder.addRoomLights(mansion, 60, WALL_HEIGHT, 30, NEON_PINK, 45)    -- Living Room
	MansionBuilder.addRoomLights(mansion, 100, WALL_HEIGHT, 30, GOLD, 45)         -- Kitchen
	MansionBuilder.addRoomLights(mansion, 60, WALL_HEIGHT, -35, CRIMSON, 45)     -- Drama Room
	MansionBuilder.addRoomLights(mansion, 100, WALL_HEIGHT, -35, PURPLE, 40)     -- Confession
	MansionBuilder.addRoomLights(mansion, 150, WALL_HEIGHT, -35, CRIMSON, 50)    -- Elimination

	-- Corridor lights (every 25 studs)
	for x = 20, 200, 25 do
		MansionBuilder.addRoomLights(mansion, x, WALL_HEIGHT, 0, GOLD, 30)
	end

	-- Bedroom lights
	for i = 1, 10 do
		local col = i <= 5 and (i - 1) or (i - 6)
		local side = i <= 5 and 1 or -1
		local cx = 40 + col * 32
		local cz = side * 25
		local bConfig = Config.BEDROOM_NAMES[i]
		if bConfig then
			if bConfig.exile then
				-- Dog house gets minimal light (already handled in buildBedroom)
			else
				MansionBuilder.addRoomLights(mansion, cx, FLOOR2_Y + WALL_HEIGHT, cz, bConfig.color, 35)
			end
		end
	end

	-- Rooftop lights
	local ry = FLOOR2_Y + WALL_HEIGHT + 2
	MansionBuilder.addRoomLights(mansion, 80, ry + 10, 0, GOLD, 70)
	MansionBuilder.addRoomLights(mansion, 120, ry + 10, 15, SKY_BLUE, 60)
	MansionBuilder.addRoomLights(mansion, 100, ry + 10, -20, NEON_PINK, 50)

	-- Exterior entrance lights
	MansionBuilder.addRoomLights(mansion, -10, 15, 0, GOLD, 50)
	MansionBuilder.addRoomLights(mansion, -30, 8, 10, GOLD, 40)
	MansionBuilder.addRoomLights(mansion, -30, 8, -10, GOLD, 40)

	print("[MansionBuilder] All luxury lights installed!")
end

return MansionBuilder

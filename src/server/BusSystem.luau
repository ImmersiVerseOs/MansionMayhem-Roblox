-- ============================================================
-- BUS SYSTEM — Hollywood Arrival Experience
-- Players spawn at Hollywood bus station, ride the bus
-- to the Mansion of Mayhem with cinematic transition
-- ============================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BusSystem = {}

-- Constants
local STATION_POS = Vector3.new(-500, 0, 0)  -- Far from mansion
local BUS_POS = Vector3.new(-480, 0, 15)      -- Bus parked at station
local MANSION_LOBBY_POS = Vector3.new(20, 3, 0) -- Lobby arrival point

-- Colors
local GOLD = Color3.fromHex("#D4A847")
local GOLD_BRIGHT = Color3.fromHex("#FFD700")
local NEON_PINK = Color3.fromHex("#FF1493")
local DARK = Color3.fromHex("#0A0610")
local MARBLE_WHITE = Color3.fromHex("#F0E6D8")
local WALL_COLOR = Color3.fromHex("#1E1428")
local ROSE_GOLD = Color3.fromHex("#E8A0BF")
local PALM_GREEN = Color3.fromHex("#2D8B46")
local HILL_GREEN = Color3.fromHex("#1B5E3B")
local BUS_PINK = Color3.fromHex("#FF69B4")
local SIDEWALK_GRAY = Color3.fromHex("#808080")
local BUILDING_DARK = Color3.fromHex("#2A2A35")

-- State
BusSystem._busModel = nil
BusSystem._stationModel = nil
BusSystem._countdownActive = false
BusSystem._rideInProgress = false

-- ============================================================
-- HELPER
-- ============================================================

local function createPart(parent, name, pos, size, color, mat)
	local part = Instance.new("Part")
	part.Name = name
	part.Position = pos
	part.Size = size
	part.Color = color or WALL_COLOR
	part.Material = mat or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = true
	part.Parent = parent
	return part
end

local function createNeon(parent, name, pos, size, color)
	local part = createPart(parent, name, pos, size, color or NEON_PINK, Enum.Material.Neon)
	part.CanCollide = false
	return part
end

local function createSign(parent, text, pos, sizeX, color, rotation)
	local part = Instance.new("Part")
	part.Name = "Sign_" .. text
	part.Position = pos
	part.Size = Vector3.new(sizeX or 8, 3, 0.3)
	part.Color = DARK
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 0.3
	if rotation then part.Orientation = rotation end
	part.Parent = parent

	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.Parent = part
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(1, 0, 1, 0)
	tl.BackgroundTransparency = 1
	tl.Text = text
	tl.TextColor3 = color or GOLD_BRIGHT
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamBold
	tl.Parent = sg

	local sg2 = Instance.new("SurfaceGui")
	sg2.Face = Enum.NormalId.Back
	sg2.Parent = part
	local tl2 = Instance.new("TextLabel")
	tl2.Size = UDim2.new(1, 0, 1, 0)
	tl2.BackgroundTransparency = 1
	tl2.Text = text
	tl2.TextColor3 = color or GOLD_BRIGHT
	tl2.TextScaled = true
	tl2.Font = Enum.Font.GothamBold
	tl2.Parent = sg2

	return part
end

local function createPalmTree(parent, pos, height)
	local tree = Instance.new("Model")
	tree.Name = "PalmTree"
	tree.Parent = parent

	-- Trunk
	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size = Vector3.new(height or 15, 2, 2)
	trunk.Position = pos + Vector3.new(0, (height or 15) / 2, 0)
	trunk.Color = Color3.fromHex("#8B7355")
	trunk.Material = Enum.Material.Wood
	trunk.Anchored = true
	trunk.Parent = tree

	-- Leaves (cluster of green parts)
	local topY = pos.Y + (height or 15)
	for i = 1, 6 do
		local angle = (i - 1) * (math.pi / 3)
		local leaf = Instance.new("Part")
		leaf.Name = "Leaf" .. i
		leaf.Size = Vector3.new(6, 0.5, 2)
		leaf.Position = Vector3.new(pos.X + math.cos(angle) * 3, topY, pos.Z + math.sin(angle) * 3)
		leaf.Orientation = Vector3.new(0, math.deg(angle), -30)
		leaf.Color = PALM_GREEN
		leaf.Material = Enum.Material.Grass
		leaf.Anchored = true
		leaf.CanCollide = false
		leaf.Parent = tree
	end

	return tree
end

-- ============================================================
-- BUILD HOLLYWOOD STATION
-- ============================================================

function BusSystem.buildStation(parent)
	local station = Instance.new("Folder")
	station.Name = "HollywoodStation"
	station.Parent = parent

	local sx, sz = STATION_POS.X, STATION_POS.Z

	-- Ground plane
	createPart(station, "Ground",
		Vector3.new(sx, -1, sz),
		Vector3.new(200, 1, 150),
		Color3.fromHex("#333333"), Enum.Material.Concrete)

	-- Sidewalk
	createPart(station, "Sidewalk",
		Vector3.new(sx, -0.4, sz),
		Vector3.new(120, 0.5, 80),
		SIDEWALK_GRAY, Enum.Material.Concrete)

	-- ===== HOLLYWOOD SIGN ON HILLSIDE =====
	-- Green hill
	local hillX, hillZ = sx + 60, sz - 40
	createPart(station, "Hill1",
		Vector3.new(hillX, 5, hillZ),
		Vector3.new(60, 12, 20), HILL_GREEN, Enum.Material.Grass)
	createPart(station, "Hill2",
		Vector3.new(hillX, 12, hillZ - 3),
		Vector3.new(55, 8, 15), HILL_GREEN, Enum.Material.Grass)
	createPart(station, "Hill3",
		Vector3.new(hillX, 17, hillZ - 5),
		Vector3.new(45, 5, 10), HILL_GREEN, Enum.Material.Grass)

	-- HOLLYWOOD letters (each letter is a gold neon part)
	local letters = {"H", "O", "L", "L", "Y", "W", "O", "O", "D"}
	for i, letter in ipairs(letters) do
		local lx = hillX - 30 + (i - 1) * 7
		local lPart = Instance.new("Part")
		lPart.Name = "Letter_" .. letter .. i
		lPart.Position = Vector3.new(lx, 22, hillZ - 8)
		lPart.Size = Vector3.new(5, 8, 1)
		lPart.Color = GOLD_BRIGHT
		lPart.Material = Enum.Material.Neon
		lPart.Anchored = true
		lPart.CanCollide = false
		lPart.Parent = station

		-- SurfaceGui with the letter
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.Parent = lPart
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.new(1, 0, 1, 0)
		tl.BackgroundTransparency = 1
		tl.Text = letter
		tl.TextColor3 = Color3.new(1, 1, 1)
		tl.TextScaled = true
		tl.Font = Enum.Font.GothamBold
		tl.Parent = sg

		local sg2 = Instance.new("SurfaceGui")
		sg2.Face = Enum.NormalId.Back
		sg2.Parent = lPart
		local tl2 = Instance.new("TextLabel")
		tl2.Size = UDim2.new(1, 0, 1, 0)
		tl2.BackgroundTransparency = 1
		tl2.Text = letter
		tl2.TextColor3 = Color3.new(1, 1, 1)
		tl2.TextScaled = true
		tl2.Font = Enum.Font.GothamBold
		tl2.Parent = sg2
	end

	-- ===== BUS STOP SHELTER =====
	local shelterX, shelterZ = sx - 10, sz + 10
	-- Shelter roof
	createPart(station, "ShelterRoof",
		Vector3.new(shelterX, 10, shelterZ),
		Vector3.new(16, 0.5, 8), GOLD, Enum.Material.Metal)
	-- Shelter back wall
	createPart(station, "ShelterBack",
		Vector3.new(shelterX, 5, shelterZ + 4),
		Vector3.new(16, 10, 0.5), Color3.fromHex("#1A1225"), Enum.Material.SmoothPlastic)
	-- Shelter side walls
	createPart(station, "ShelterSideL",
		Vector3.new(shelterX - 8, 5, shelterZ),
		Vector3.new(0.5, 10, 8), Color3.fromHex("#1A1225"))
	createPart(station, "ShelterSideR",
		Vector3.new(shelterX + 8, 5, shelterZ),
		Vector3.new(0.5, 10, 8), Color3.fromHex("#1A1225"))

	-- Bench inside shelter
	createPart(station, "Bench",
		Vector3.new(shelterX, 2, shelterZ + 2),
		Vector3.new(12, 1, 2), MARBLE_WHITE, Enum.Material.Marble)
	createPart(station, "BenchLegs1",
		Vector3.new(shelterX - 4, 1, shelterZ + 2),
		Vector3.new(0.5, 2, 2), GOLD, Enum.Material.Metal)
	createPart(station, "BenchLegs2",
		Vector3.new(shelterX + 4, 1, shelterZ + 2),
		Vector3.new(0.5, 2, 2), GOLD, Enum.Material.Metal)

	-- Shelter sign
	createSign(station, "MANSION OF MAYHEM SHUTTLE",
		Vector3.new(shelterX, 8, shelterZ + 4.5), 14, NEON_PINK)

	-- Departure countdown sign (will be updated)
	local countdownSign = createPart(station, "CountdownSign",
		Vector3.new(shelterX, 6, shelterZ + 4.5),
		Vector3.new(10, 2, 0.3), DARK)
	countdownSign.CanCollide = false
	local cdGui = Instance.new("SurfaceGui")
	cdGui.Name = "CountdownGui"
	cdGui.Face = Enum.NormalId.Front
	cdGui.Parent = countdownSign
	local cdLabel = Instance.new("TextLabel")
	cdLabel.Name = "CountdownLabel"
	cdLabel.Size = UDim2.new(1, 0, 1, 0)
	cdLabel.BackgroundTransparency = 1
	cdLabel.Text = "Waiting for players..."
	cdLabel.TextColor3 = GOLD_BRIGHT
	cdLabel.TextScaled = true
	cdLabel.Font = Enum.Font.GothamBold
	cdLabel.Parent = cdGui

	-- ===== PALM TREES =====
	createPalmTree(station, Vector3.new(sx - 40, 0, sz + 20), 18)
	createPalmTree(station, Vector3.new(sx + 40, 0, sz + 20), 15)
	createPalmTree(station, Vector3.new(sx - 30, 0, sz - 25), 20)
	createPalmTree(station, Vector3.new(sx + 30, 0, sz - 25), 16)
	createPalmTree(station, Vector3.new(sx - 50, 0, sz - 10), 14)
	createPalmTree(station, Vector3.new(sx + 50, 0, sz - 10), 17)

	-- ===== BACKGROUND BUILDINGS =====
	local buildingPositions = {
		{x = sx - 70, z = sz - 50, w = 15, h = 40, d = 15},
		{x = sx - 50, z = sz - 55, w = 12, h = 55, d = 12},
		{x = sx - 30, z = sz - 60, w = 18, h = 30, d = 14},
		{x = sx + 70, z = sz - 50, w = 14, h = 45, d = 14},
		{x = sx + 50, z = sz - 55, w = 16, h = 35, d = 12},
		{x = sx + 85, z = sz - 45, w = 12, h = 60, d = 12},
	}
	for i, b in ipairs(buildingPositions) do
		createPart(station, "BGBuilding" .. i,
			Vector3.new(b.x, b.h / 2, b.z),
			Vector3.new(b.w, b.h, b.d),
			BUILDING_DARK, Enum.Material.SmoothPlastic)
		-- Window dots
		for wy = 1, math.floor(b.h / 10) do
			for wx = 1, 2 do
				createNeon(station, "BGWin" .. i .. "_" .. wy .. "_" .. wx,
					Vector3.new(b.x + (wx == 1 and -3 or 3), wy * 8, b.z + b.d / 2 + 0.2),
					Vector3.new(2, 2, 0.2),
					Color3.fromHex("#FFE488"))
			end
		end
	end

	-- ===== ROAD =====
	createPart(station, "Road",
		Vector3.new(sx, -0.3, sz + 25),
		Vector3.new(200, 0.3, 12),
		Color3.fromHex("#222222"), Enum.Material.Asphalt)
	-- Road lines
	for i = 1, 10 do
		createPart(station, "RoadLine" .. i,
			Vector3.new(sx - 90 + (i - 1) * 20, -0.1, sz + 25),
			Vector3.new(8, 0.1, 0.5),
			Color3.new(1, 1, 0), Enum.Material.Neon)
	end

	-- ===== SPAWN LOCATION =====
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HollywoodSpawn"
	spawn.Position = Vector3.new(sx, 2, sz)
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Parent = station

	-- ===== STAR WALK =====
	for i = 1, 6 do
		local starX = sx - 25 + (i - 1) * 10
		local star = Instance.new("Part")
		star.Name = "WalkOfFameStar" .. i
		star.Shape = Enum.PartType.Cylinder
		star.Size = Vector3.new(0.2, 4, 4)
		star.Position = Vector3.new(starX, -0.3, sz + 5)
		star.Orientation = Vector3.new(0, 0, 90)
		star.Color = GOLD_BRIGHT
		star.Material = Enum.Material.Neon
		star.Anchored = true
		star.CanCollide = false
		star.Transparency = 0.4
		star.Parent = station
	end

	BusSystem._stationModel = station
	return station
end

-- ============================================================
-- BUILD LUXURY BUS
-- ============================================================

function BusSystem.buildBus(parent)
	local bus = Instance.new("Model")
	bus.Name = "MayhemBus"
	bus.Parent = parent

	local bx, bz = BUS_POS.X, BUS_POS.Z
	local busLen = 30
	local busW = 8
	local busH = 8

	-- Body (main rectangular body)
	local body = createPart(bus, "Body",
		Vector3.new(bx, busH / 2 + 2, bz),
		Vector3.new(busLen, busH, busW), BUS_PINK)

	-- Roof
	createPart(bus, "Roof",
		Vector3.new(bx, busH + 2.5, bz),
		Vector3.new(busLen, 1, busW), GOLD, Enum.Material.Metal)

	-- Floor
	createPart(bus, "BusFloor",
		Vector3.new(bx, 2, bz),
		Vector3.new(busLen, 0.5, busW), DARK)

	-- Windshield (front)
	local windshield = createPart(bus, "Windshield",
		Vector3.new(bx - busLen / 2 - 0.2, busH / 2 + 3, bz),
		Vector3.new(0.3, busH - 2, busW - 1), Color3.fromHex("#88CCEE"), Enum.Material.Glass)
	windshield.Transparency = 0.4

	-- Rear window
	local rearWin = createPart(bus, "RearWindow",
		Vector3.new(bx + busLen / 2 + 0.2, busH / 2 + 3, bz),
		Vector3.new(0.3, busH - 3, busW - 2), Color3.fromHex("#88CCEE"), Enum.Material.Glass)
	rearWin.Transparency = 0.5

	-- Side windows (left)
	for i = 1, 5 do
		local wx = bx - busLen / 2 + 3 + (i - 1) * 5.5
		local win = createPart(bus, "WindowL" .. i,
			Vector3.new(wx, busH / 2 + 3, bz - busW / 2 - 0.1),
			Vector3.new(4, 3, 0.2), Color3.fromHex("#88CCEE"), Enum.Material.Glass)
		win.Transparency = 0.4
	end

	-- Side windows (right)
	for i = 1, 5 do
		local wx = bx - busLen / 2 + 3 + (i - 1) * 5.5
		local win = createPart(bus, "WindowR" .. i,
			Vector3.new(wx, busH / 2 + 3, bz + busW / 2 + 0.1),
			Vector3.new(4, 3, 0.2), Color3.fromHex("#88CCEE"), Enum.Material.Glass)
		win.Transparency = 0.4
	end

	-- Wheels (4)
	local wheelPositions = {
		Vector3.new(bx - busLen / 2 + 4, 1, bz - busW / 2),
		Vector3.new(bx - busLen / 2 + 4, 1, bz + busW / 2),
		Vector3.new(bx + busLen / 2 - 4, 1, bz - busW / 2),
		Vector3.new(bx + busLen / 2 - 4, 1, bz + busW / 2),
	}
	for i, wpos in ipairs(wheelPositions) do
		local wheel = Instance.new("Part")
		wheel.Name = "Wheel" .. i
		wheel.Shape = Enum.PartType.Cylinder
		wheel.Size = Vector3.new(1, 2.5, 2.5)
		wheel.Position = wpos
		wheel.Orientation = Vector3.new(90, 0, 0)
		wheel.Color = Color3.new(0.1, 0.1, 0.1)
		wheel.Material = Enum.Material.SmoothPlastic
		wheel.Anchored = true
		wheel.Parent = bus
	end

	-- "MANSION OF MAYHEM" text on side
	createSign(bus, "MANSION OF MAYHEM",
		Vector3.new(bx, busH / 2 + 5, bz - busW / 2 - 0.3), 20, GOLD_BRIGHT)
	createSign(bus, "MANSION OF MAYHEM",
		Vector3.new(bx, busH / 2 + 5, bz + busW / 2 + 0.3), 20, GOLD_BRIGHT,
		Vector3.new(0, 180, 0))

	-- Gold accent stripe
	createNeon(bus, "StripeL",
		Vector3.new(bx, 3, bz - busW / 2 - 0.1),
		Vector3.new(busLen, 0.5, 0.2), GOLD_BRIGHT)
	createNeon(bus, "StripeR",
		Vector3.new(bx, 3, bz + busW / 2 + 0.1),
		Vector3.new(busLen, 0.5, 0.2), GOLD_BRIGHT)

	-- Headlights
	createNeon(bus, "HeadlightL",
		Vector3.new(bx - busLen / 2 - 0.3, 4, bz - 2),
		Vector3.new(0.3, 1, 1.5), Color3.new(1, 1, 0.9))
	createNeon(bus, "HeadlightR",
		Vector3.new(bx - busLen / 2 - 0.3, 4, bz + 2),
		Vector3.new(0.3, 1, 1.5), Color3.new(1, 1, 0.9))

	-- Taillights
	createNeon(bus, "TaillightL",
		Vector3.new(bx + busLen / 2 + 0.3, 4, bz - 2),
		Vector3.new(0.3, 1, 1.5), Color3.fromHex("#FF0000"))
	createNeon(bus, "TaillightR",
		Vector3.new(bx + busLen / 2 + 0.3, 4, bz + 2),
		Vector3.new(0.3, 1, 1.5), Color3.fromHex("#FF0000"))

	-- Interior seating (simple benches inside)
	for row = 1, 4 do
		local seatX = bx - busLen / 2 + 5 + (row - 1) * 6
		-- Left bench
		createPart(bus, "SeatL" .. row,
			Vector3.new(seatX, 3.5, bz - 2),
			Vector3.new(3, 1.5, 2), MARBLE_WHITE, Enum.Material.Fabric)
		-- Right bench
		createPart(bus, "SeatR" .. row,
			Vector3.new(seatX, 3.5, bz + 2),
			Vector3.new(3, 1.5, 2), MARBLE_WHITE, Enum.Material.Fabric)
	end

	-- Interior light
	local intLight = createNeon(bus, "InteriorLight",
		Vector3.new(bx, busH + 1.5, bz),
		Vector3.new(busLen - 4, 0.3, 2), GOLD_BRIGHT)
	local pl = Instance.new("PointLight")
	pl.Color = Color3.fromHex("#FFEEDD")
	pl.Brightness = 1.5
	pl.Range = 25
	pl.Parent = intLight

	BusSystem._busModel = bus
	return bus
end

-- ============================================================
-- INITIALIZATION
-- ============================================================

function BusSystem.init(mansion)
	local hollywoodFolder = Instance.new("Folder")
	hollywoodFolder.Name = "HollywoodArea"
	hollywoodFolder.Parent = workspace

	-- Build the Hollywood station and bus
	BusSystem.buildStation(hollywoodFolder)
	BusSystem.buildBus(hollywoodFolder)

	-- Start the bus departure loop
	task.spawn(function()
		-- Wait for players to join
		task.wait(5)
		BusSystem._runDepartureLoop()
	end)

	print("[BusSystem] Hollywood station built and bus ready!")
end

-- ============================================================
-- BUS DEPARTURE LOOP
-- ============================================================

function BusSystem._runDepartureLoop()
	while true do
		-- Wait until at least 1 player is in the game
		while #Players:GetPlayers() == 0 do
			task.wait(2)
		end

		-- Start countdown
		BusSystem.startCountdown(60)

		-- Board passengers
		BusSystem.boardPassengers()

		-- Run the ride cinematic
		BusSystem.startRide()

		-- Arrive at mansion
		BusSystem.arrive()

		-- Wait before next cycle (in case new players join later)
		task.wait(30)
	end
end

-- ============================================================
-- COUNTDOWN
-- ============================================================

function BusSystem.startCountdown(duration)
	BusSystem._countdownActive = true
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")

	-- Update the countdown sign at the station
	local station = BusSystem._stationModel
	local countdownSign = station and station:FindFirstChild("CountdownSign")
	local cdGui = countdownSign and countdownSign:FindFirstChild("CountdownGui")
	local cdLabel = cdGui and cdGui:FindFirstChild("CountdownLabel")

	for t = duration, 0, -1 do
		if not BusSystem._countdownActive then break end

		local minutes = math.floor(t / 60)
		local seconds = t % 60
		local timeStr = string.format("%d:%02d", minutes, seconds)

		-- Update physical sign
		if cdLabel then
			cdLabel.Text = "Bus departs in: " .. timeStr
		end

		-- Fire event to all clients
		if remotes then
			local countdownEvent = remotes:FindFirstChild("BusCountdown")
			if countdownEvent then
				countdownEvent:FireAllClients({
					timeRemaining = t,
					timeStr = timeStr,
				})
			end
		end

		task.wait(1)
	end

	if cdLabel then
		cdLabel.Text = "DEPARTING NOW!"
	end

	BusSystem._countdownActive = false
end

-- ============================================================
-- BOARD PASSENGERS
-- ============================================================

function BusSystem.boardPassengers()
	local boardedPlayers = {}

	-- Find all players near the Hollywood station
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local dist = (hrp.Position - STATION_POS).Magnitude
				if dist < 150 then  -- Within station area
					table.insert(boardedPlayers, player)
				end
			end
		end
	end

	-- If no one is nearby, board everyone (failsafe)
	if #boardedPlayers == 0 then
		for _, player in Players:GetPlayers() do
			table.insert(boardedPlayers, player)
		end
	end

	-- Teleport boarded players onto bus seats
	local bx, bz = BUS_POS.X, BUS_POS.Z
	for i, player in ipairs(boardedPlayers) do
		local character = player.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local row = math.ceil(i / 2)
				local side = (i % 2 == 1) and -2 or 2
				local seatX = bx - 10 + (row - 1) * 6
				hrp.CFrame = CFrame.new(seatX, 5, bz + side)
			end
		end
	end

	BusSystem._boardedPlayers = boardedPlayers
end

-- ============================================================
-- START RIDE (Cinematic)
-- ============================================================

function BusSystem.startRide()
	BusSystem._rideInProgress = true

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then return end

	local cinematicEvent = remotes:FindFirstChild("BusCinematic")

	-- Tell all boarded clients to show cinematic overlay
	if cinematicEvent then
		cinematicEvent:FireAllClients({
			action = "start",
			text = "EN ROUTE TO THE MANSION...",
		})
	end

	-- Wait for the "ride" duration (15 seconds)
	-- Optionally tween bus toward mansion for visual effect
	local bus = BusSystem._busModel
	if bus then
		local body = bus:FindFirstChild("Body")
		if body then
			-- We just do a slow fade/transition, no actual bus movement needed
			-- since players see the letterbox overlay
		end
	end

	task.wait(15)

	BusSystem._rideInProgress = false
end

-- ============================================================
-- ARRIVE AT MANSION
-- ============================================================

function BusSystem.arrive()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")

	-- Teleport all boarded players to the mansion lobby
	local boardedPlayers = BusSystem._boardedPlayers or {}

	-- If the list is empty, teleport everyone
	if #boardedPlayers == 0 then
		for _, player in Players:GetPlayers() do
			table.insert(boardedPlayers, player)
		end
	end

	for i, player in ipairs(boardedPlayers) do
		local character = player.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				-- Spread players around the lobby arrival point
				local angle = (i - 1) * (2 * math.pi / math.max(#boardedPlayers, 1))
				local offset = Vector3.new(math.cos(angle) * 5, 0, math.sin(angle) * 5)
				hrp.CFrame = CFrame.new(MANSION_LOBBY_POS + offset)
			end
		end
	end

	-- Tell clients to remove cinematic
	if remotes then
		local arriveEvent = remotes:FindFirstChild("BusArrive")
		if arriveEvent then
			arriveEvent:FireAllClients({
				message = "WELCOME TO THE MANSION OF MAYHEM!",
			})
		end

		-- Director announcement
		task.delay(3, function()
			local directorEvent = remotes:FindFirstChild("DirectorAnnounce")
			if directorEvent then
				directorEvent:FireAllClients("Welcome to the Mansion of Mayhem!")
			end
		end)
	end

	BusSystem._boardedPlayers = {}
end

return BusSystem

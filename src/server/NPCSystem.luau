-- ============================================================
-- NPC SYSTEM — Crew members that patrol the Mansion
-- Director, Security Officers, Camera Operators, House Manager
-- Walk between waypoints, respond to events (fights, eliminations)
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local NPCSystem = {}

-- State
NPCSystem.npcs = {} -- { [name] = { model, config, currentWaypoint, patrolTask } }
NPCSystem.mansion = nil

-- ============================================================
-- NPC CONFIGURATIONS
-- ============================================================

local NPC_CONFIGS = {
	{
		name = "THE DIRECTOR",
		displayName = "THE DIRECTOR",
		labelColor = Color3.fromHex("#FFD700"),
		bodyColor = Color3.fromHex("#0A0A0A"), -- black outfit
		accentColor = Color3.fromHex("#FFD700"), -- gold sunglasses
		hasAccent = true,
		waypoints = {
			Vector3.new(135, 1, -25), -- Elimination Room center
			Vector3.new(120, 1, -20), -- Elimination Room edge
			Vector3.new(75, 1, 0),    -- Main corridor
			Vector3.new(55, 1, -15),  -- Near Drama Room
			Vector3.new(95, 1, 0),    -- Mid corridor
			Vector3.new(135, 1, -25), -- Back to Elimination Room
		},
		walkSpeed = 8,
		idleTime = 6,
	},
	{
		name = "OFFICER KANE",
		displayName = "OFFICER KANE",
		labelColor = Color3.fromHex("#F8F4F0"),
		bodyColor = Color3.fromHex("#1A3A6B"), -- blue security uniform
		accentColor = nil,
		hasAccent = false,
		waypoints = {
			Vector3.new(55, 1, 0),    -- Near lobby-corridor junction
			Vector3.new(75, 1, 0),    -- Main corridor
			Vector3.new(55, 1, -20),  -- Drama Room entrance
			Vector3.new(55, 1, 15),   -- Living Room entrance
			Vector3.new(35, 1, 0),    -- Lobby area
			Vector3.new(55, 1, 0),    -- Back to start
		},
		walkSpeed = 10,
		idleTime = 4,
	},
	{
		name = "OFFICER REYES",
		displayName = "OFFICER REYES",
		labelColor = Color3.fromHex("#F8F4F0"),
		bodyColor = Color3.fromHex("#1A3A6B"), -- blue security uniform
		accentColor = nil,
		hasAccent = false,
		waypoints = {
			Vector3.new(95, 1, 0),    -- Mid corridor
			Vector3.new(110, 1, 0),   -- Near Elimination/Kitchen
			Vector3.new(95, 1, 15),   -- Kitchen entrance
			Vector3.new(95, 1, -15),  -- Confession Booth entrance
			Vector3.new(120, 1, -10), -- Near Elimination Room
			Vector3.new(95, 1, 0),    -- Back to start
		},
		walkSpeed = 10,
		idleTime = 4,
	},
	{
		name = "LENS",
		displayName = "\xF0\x9F\x93\xB7 LENS",
		labelColor = Color3.fromHex("#F8F4F0"),
		bodyColor = Color3.fromHex("#333333"), -- dark gray crew outfit
		accentColor = Color3.fromHex("#808080"), -- camera prop (gray box)
		hasAccent = true,
		waypoints = {
			Vector3.new(55, 1, 15),   -- Living Room
			Vector3.new(35, 1, 5),    -- Lobby
			Vector3.new(55, 1, -20),  -- Drama Room
			Vector3.new(75, 1, 0),    -- Corridor
		},
		walkSpeed = 12,
		idleTime = 3,
	},
	{
		name = "FLASH",
		displayName = "\xF0\x9F\x93\xB7 FLASH",
		labelColor = Color3.fromHex("#F8F4F0"),
		bodyColor = Color3.fromHex("#333333"), -- dark gray crew outfit
		accentColor = Color3.fromHex("#808080"), -- camera prop
		hasAccent = true,
		waypoints = {
			Vector3.new(95, 1, 15),   -- Kitchen area
			Vector3.new(135, 1, -25), -- Elimination Room
			Vector3.new(95, 1, -15),  -- Confession Booth
			Vector3.new(110, 1, 0),   -- Corridor near kitchen
		},
		walkSpeed = 12,
		idleTime = 3,
	},
	{
		name = "MS. STERLING",
		displayName = "MS. STERLING",
		labelColor = Color3.fromHex("#F8F4F0"),
		bodyColor = Color3.fromHex("#6A0DAD"), -- purple elegant outfit
		accentColor = nil,
		hasAccent = false,
		waypoints = {
			Vector3.new(25, 1, 5),    -- Lobby entrance
			Vector3.new(35, 1, 0),    -- Lobby center
			Vector3.new(55, 1, 15),   -- Near Living Room
			Vector3.new(95, 1, 15),   -- Kitchen area
			Vector3.new(55, 1, 0),    -- Corridor
			Vector3.new(25, 1, 5),    -- Back to lobby
		},
		walkSpeed = 7,
		idleTime = 5,
	},
}

-- ============================================================
-- INITIALIZATION
-- ============================================================

function NPCSystem.init(mansion)
	NPCSystem.mansion = mansion or workspace:FindFirstChild("Mansion")

	print("[NPCSystem] Spawning NPC crew members...")

	for _, config in NPC_CONFIGS do
		NPCSystem.spawnNPC(config.name, config)
	end

	print("[NPCSystem] All NPCs spawned:", #NPC_CONFIGS, "crew members")
end

-- ============================================================
-- NPC MODEL CREATION
-- ============================================================

function NPCSystem.spawnNPC(name, config)
	-- Create the NPC model
	local model = Instance.new("Model")
	model.Name = "NPC_" .. name:gsub(" ", "_")

	-- Create Humanoid
	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = config.walkSpeed or 10
	humanoid.Health = 100
	humanoid.MaxHealth = 100
	humanoid.Parent = model

	-- Body dimensions
	local torsoSize = Vector3.new(2, 2.5, 1)
	local headSize = Vector3.new(1.4, 1.4, 1.4)
	local armSize = Vector3.new(0.8, 2.4, 0.8)
	local legSize = Vector3.new(0.8, 2.4, 0.8)

	local spawnPos = config.waypoints[1] or Vector3.new(50, 1, 0)
	local baseY = spawnPos.Y + legSize.Y + torsoSize.Y / 2

	-- Torso (HumanoidRootPart)
	local torso = Instance.new("Part")
	torso.Name = "HumanoidRootPart"
	torso.Size = torsoSize
	torso.CFrame = CFrame.new(spawnPos.X, baseY, spawnPos.Z)
	torso.Color = config.bodyColor
	torso.Material = Enum.Material.SmoothPlastic
	torso.Anchored = false
	torso.CanCollide = true
	torso.Parent = model

	-- Head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = headSize
	head.Shape = Enum.PartType.Ball
	head.Color = Color3.fromHex("#D2A679") -- skin tone
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = false
	head.CanCollide = false
	head.Parent = model

	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = torso
	headWeld.Part1 = head
	headWeld.Parent = head
	head.CFrame = torso.CFrame * CFrame.new(0, torsoSize.Y / 2 + headSize.Y / 2, 0)

	-- Left Arm
	local leftArm = Instance.new("Part")
	leftArm.Name = "LeftArm"
	leftArm.Size = armSize
	leftArm.Color = config.bodyColor
	leftArm.Material = Enum.Material.SmoothPlastic
	leftArm.Anchored = false
	leftArm.CanCollide = false
	leftArm.Parent = model

	local leftArmWeld = Instance.new("WeldConstraint")
	leftArmWeld.Part0 = torso
	leftArmWeld.Part1 = leftArm
	leftArmWeld.Parent = leftArm
	leftArm.CFrame = torso.CFrame * CFrame.new(-(torsoSize.X / 2 + armSize.X / 2), 0, 0)

	-- Right Arm
	local rightArm = Instance.new("Part")
	rightArm.Name = "RightArm"
	rightArm.Size = armSize
	rightArm.Color = config.bodyColor
	rightArm.Material = Enum.Material.SmoothPlastic
	rightArm.Anchored = false
	rightArm.CanCollide = false
	rightArm.Parent = model

	local rightArmWeld = Instance.new("WeldConstraint")
	rightArmWeld.Part0 = torso
	rightArmWeld.Part1 = rightArm
	rightArmWeld.Parent = rightArm
	rightArm.CFrame = torso.CFrame * CFrame.new(torsoSize.X / 2 + armSize.X / 2, 0, 0)

	-- Left Leg
	local leftLeg = Instance.new("Part")
	leftLeg.Name = "LeftLeg"
	leftLeg.Size = legSize
	leftLeg.Color = config.bodyColor
	leftLeg.Material = Enum.Material.SmoothPlastic
	leftLeg.Anchored = false
	leftLeg.CanCollide = false
	leftLeg.Parent = model

	local leftLegWeld = Instance.new("WeldConstraint")
	leftLegWeld.Part0 = torso
	leftLegWeld.Part1 = leftLeg
	leftLegWeld.Parent = leftLeg
	leftLeg.CFrame = torso.CFrame * CFrame.new(-0.5, -(torsoSize.Y / 2 + legSize.Y / 2), 0)

	-- Right Leg
	local rightLeg = Instance.new("Part")
	rightLeg.Name = "RightLeg"
	rightLeg.Size = legSize
	rightLeg.Color = config.bodyColor
	rightLeg.Material = Enum.Material.SmoothPlastic
	rightLeg.Anchored = false
	rightLeg.CanCollide = false
	rightLeg.Parent = model

	local rightLegWeld = Instance.new("WeldConstraint")
	rightLegWeld.Part0 = torso
	rightLegWeld.Part1 = rightLeg
	rightLegWeld.Parent = rightLeg
	rightLeg.CFrame = torso.CFrame * CFrame.new(0.5, -(torsoSize.Y / 2 + legSize.Y / 2), 0)

	-- Accent piece (sunglasses for Director, camera for Lens/Flash)
	if config.hasAccent and config.accentColor then
		local accent = Instance.new("Part")
		accent.Name = "Accent"
		accent.CanCollide = false
		accent.Anchored = false
		accent.Color = config.accentColor
		accent.Material = Enum.Material.Neon

		-- Camera operators get a shoulder-mounted box
		if name == "LENS" or name == "FLASH" then
			accent.Size = Vector3.new(0.6, 0.5, 0.8)
			accent.Material = Enum.Material.Metal
			local accentWeld = Instance.new("WeldConstraint")
			accentWeld.Part0 = rightArm
			accentWeld.Part1 = accent
			accentWeld.Parent = accent
			accent.CFrame = rightArm.CFrame * CFrame.new(0, armSize.Y / 2 + 0.3, 0.3)
		else
			-- Director gets gold sunglasses (small bar across eyes)
			accent.Size = Vector3.new(1.2, 0.2, 0.2)
			local accentWeld = Instance.new("WeldConstraint")
			accentWeld.Part0 = head
			accentWeld.Part1 = accent
			accentWeld.Parent = accent
			accent.CFrame = head.CFrame * CFrame.new(0, 0.1, -headSize.Z / 2 - 0.05)
		end

		accent.Parent = model
	end

	-- BillboardGui name tag
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Size = UDim2.new(0, 150, 0, 30)
	billboard.StudsOffset = Vector3.new(0, headSize.Y + 1.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 80
	billboard.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundColor3 = Color3.fromHex("#0A0610")
	nameLabel.BackgroundTransparency = 0.4
	nameLabel.Text = config.displayName
	nameLabel.TextColor3 = config.labelColor
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = false
	nameLabel.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = nameLabel

	local stroke = Instance.new("UIStroke")
	stroke.Color = config.labelColor
	stroke.Thickness = 1
	stroke.Transparency = 0.5
	stroke.Parent = nameLabel

	-- Set PrimaryPart
	model.PrimaryPart = torso

	-- Parent to workspace
	local npcFolder = workspace:FindFirstChild("NPCs")
	if not npcFolder then
		npcFolder = Instance.new("Folder")
		npcFolder.Name = "NPCs"
		npcFolder.Parent = workspace
	end
	model.Parent = npcFolder

	-- Store NPC data
	NPCSystem.npcs[name] = {
		model = model,
		config = config,
		currentWaypoint = 1,
		patrolTask = nil,
		dispatched = false,
	}

	-- Start patrol
	NPCSystem.patrol(name, config.waypoints)

	print("[NPCSystem] Spawned:", name)
	return model
end

-- ============================================================
-- PATROL SYSTEM
-- ============================================================

function NPCSystem.patrol(name, waypoints)
	local npcData = NPCSystem.npcs[name]
	if not npcData then return end

	-- Cancel existing patrol
	if npcData.patrolTask then
		task.cancel(npcData.patrolTask)
		npcData.patrolTask = nil
	end

	npcData.dispatched = false

	npcData.patrolTask = task.spawn(function()
		while true do
			local model = npcData.model
			if not model or not model.Parent then break end

			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local rootPart = model:FindFirstChild("HumanoidRootPart")
			if not humanoid or not rootPart or humanoid.Health <= 0 then break end

			-- Get current waypoint
			local waypointIndex = npcData.currentWaypoint
			local targetPos = waypoints[waypointIndex]
			if not targetPos then
				npcData.currentWaypoint = 1
				targetPos = waypoints[1]
			end

			-- If dispatched to a different location, stop normal patrol
			if npcData.dispatched then
				task.wait(1)
				continue
			end

			-- Move to waypoint
			humanoid:MoveTo(targetPos)

			-- Wait for arrival or timeout
			local reached = humanoid.MoveToFinished:Wait()

			-- Idle at waypoint
			local idleTime = npcData.config.idleTime or 4
			task.wait(idleTime)

			-- Advance to next waypoint
			npcData.currentWaypoint = (waypointIndex % #waypoints) + 1
		end
	end)
end

-- ============================================================
-- TELEPORT NPC
-- ============================================================

function NPCSystem.teleportNPC(name, position)
	local npcData = NPCSystem.npcs[name]
	if not npcData then return end

	local model = npcData.model
	if not model or not model.Parent then return end

	local rootPart = model:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	rootPart.CFrame = CFrame.new(position)
	print("[NPCSystem] Teleported", name, "to", tostring(position))
end

-- ============================================================
-- DISPATCH SECURITY
-- ============================================================

function NPCSystem.dispatchSecurity(position)
	print("[NPCSystem] Dispatching security to", tostring(position))

	local securityNames = { "OFFICER KANE", "OFFICER REYES" }

	for _, officerName in securityNames do
		local npcData = NPCSystem.npcs[officerName]
		if not npcData then continue end

		local model = npcData.model
		if not model or not model.Parent then continue end

		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if not humanoid then continue end

		-- Mark as dispatched (pauses normal patrol)
		npcData.dispatched = true

		-- Move security to the fight location
		humanoid:MoveTo(position)

		-- After arriving and waiting, resume patrol
		task.spawn(function()
			humanoid.MoveToFinished:Wait()

			-- Stay at location for a while
			task.wait(15)

			-- Resume normal patrol
			npcData.dispatched = false
			npcData.currentWaypoint = 1
			NPCSystem.patrol(officerName, npcData.config.waypoints)
		end)
	end
end

-- ============================================================
-- DISPATCH CAMERA CREW
-- ============================================================

function NPCSystem.dispatchCamera(position)
	print("[NPCSystem] Dispatching camera crew to", tostring(position))

	local cameraNames = { "LENS", "FLASH" }

	for _, camName in cameraNames do
		local npcData = NPCSystem.npcs[camName]
		if not npcData then continue end

		local model = npcData.model
		if not model or not model.Parent then continue end

		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if not humanoid then continue end

		-- Mark as dispatched
		npcData.dispatched = true

		-- Move camera crew to the action
		humanoid:MoveTo(position)

		-- After filming, resume patrol
		task.spawn(function()
			humanoid.MoveToFinished:Wait()

			-- "Film" for a while
			task.wait(10)

			-- Resume normal patrol
			npcData.dispatched = false
			npcData.currentWaypoint = 1
			NPCSystem.patrol(camName, npcData.config.waypoints)
		end)
	end
end

-- ============================================================
-- UTILITIES
-- ============================================================

function NPCSystem.getNPC(name)
	local data = NPCSystem.npcs[name]
	if data then
		return data.model
	end
	return nil
end

function NPCSystem.getNPCPosition(name)
	local data = NPCSystem.npcs[name]
	if data and data.model then
		local rootPart = data.model:FindFirstChild("HumanoidRootPart")
		if rootPart then
			return rootPart.Position
		end
	end
	return nil
end

return NPCSystem

-- ============================================================
-- PARTICLE EFFECTS — Client-side visual effects for Mansion Mayhem
-- Confetti, Smoke, Fire Sparks, Shield Glow, Spotlight, Crown Sparkle
-- ============================================================

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ParticleEffects = {}

-- Track active effects for cleanup
ParticleEffects._activeEffects = {} -- { [id] = { parts, connections } }
ParticleEffects._effectCounter = 0

-- ============================================================
-- INITIALIZATION
-- ============================================================

function ParticleEffects.init()
	-- Create a folder for effect parts
	local folder = workspace:FindFirstChild("ClientEffects")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ClientEffects"
		folder.Parent = workspace
	end
	ParticleEffects._folder = folder
	print("[ParticleEffects] Initialized")
end

-- ============================================================
-- HELPER: Generate unique effect ID
-- ============================================================

local function nextId()
	ParticleEffects._effectCounter += 1
	return "effect_" .. ParticleEffects._effectCounter
end

local function cleanupEffect(id, delay)
	task.delay(delay or 0, function()
		local effect = ParticleEffects._activeEffects[id]
		if not effect then return end

		-- Disconnect any RunService connections
		for _, conn in effect.connections or {} do
			if typeof(conn) == "RBXScriptConnection" then
				conn:Disconnect()
			end
		end

		-- Destroy parts
		for _, part in effect.parts or {} do
			if part and part.Parent then
				part:Destroy()
			end
		end

		ParticleEffects._activeEffects[id] = nil
	end)
end

-- ============================================================
-- CONFETTI — Colorful particles for celebrations
-- ============================================================

function ParticleEffects.confetti(position, duration)
	duration = duration or 5

	local id = nextId()
	local parts = {}
	local connections = {}

	-- Create emitter part above position
	local emitterPart = Instance.new("Part")
	emitterPart.Name = "ConfettiEmitter"
	emitterPart.Size = Vector3.new(8, 1, 8)
	emitterPart.Position = position + Vector3.new(0, 15, 0)
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.Transparency = 1
	emitterPart.Parent = ParticleEffects._folder
	table.insert(parts, emitterPart)

	-- Confetti colors
	local confettiColors = {
		Color3.fromHex("#FFD700"), -- Gold
		Color3.fromHex("#FF1493"), -- Pink
		Color3.fromHex("#9B30FF"), -- Purple
		Color3.fromHex("#F8F4F0"), -- White
	}

	-- Create a ParticleEmitter for each color
	for _, color in confettiColors do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(color)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(0.5, 0.5),
			NumberSequenceKeypoint.new(1, 0.1),
		})
		emitter.Lifetime = NumberRange.new(2, 4)
		emitter.Rate = 50 / #confettiColors -- total ~50/sec
		emitter.Speed = NumberRange.new(2, 6)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.RotSpeed = NumberRange.new(-180, 180)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.Acceleration = Vector3.new(0, -8, 0) -- gravity-like fall
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.8, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.LightEmission = 0.3
		emitter.Parent = emitterPart
	end

	ParticleEffects._activeEffects[id] = { parts = parts, connections = connections }

	-- Stop emitting after duration, then cleanup
	task.delay(duration, function()
		for _, child in emitterPart:GetChildren() do
			if child:IsA("ParticleEmitter") then
				child.Enabled = false
			end
		end
	end)

	cleanupEffect(id, duration + 5) -- extra time for particles to fade

	return id
end

-- ============================================================
-- SMOKE / FOG — Dark smoke rising from floor
-- ============================================================

function ParticleEffects.smoke(position, duration)
	duration = duration or 10

	local id = nextId()
	local parts = {}
	local connections = {}

	-- Create emitter at floor level
	local emitterPart = Instance.new("Part")
	emitterPart.Name = "SmokeEmitter"
	emitterPart.Size = Vector3.new(12, 1, 12)
	emitterPart.Position = position + Vector3.new(0, 0.5, 0)
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.Transparency = 1
	emitterPart.Parent = ParticleEffects._folder
	table.insert(parts, emitterPart)

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("#1A1A1A")),
		ColorSequenceKeypoint.new(0.5, Color3.fromHex("#333333")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("#555555")),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 4),
		NumberSequenceKeypoint.new(1, 8),
	})
	emitter.Lifetime = NumberRange.new(4, 7)
	emitter.Rate = 15
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-20, 20)
	emitter.Acceleration = Vector3.new(0, 2, 0) -- slow rise
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.3, 0.3),
		NumberSequenceKeypoint.new(0.7, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.LightEmission = 0
	emitter.LightInfluence = 0.5
	emitter.Parent = emitterPart

	ParticleEffects._activeEffects[id] = { parts = parts, connections = connections }

	-- Stop after duration
	task.delay(duration, function()
		emitter.Enabled = false
	end)

	cleanupEffect(id, duration + 8)

	return id
end

-- ============================================================
-- FIRE SPARKS — Orange/red particles rising
-- ============================================================

function ParticleEffects.fireSparks(position, continuous)
	local id = nextId()
	local parts = {}
	local connections = {}

	local emitterPart = Instance.new("Part")
	emitterPart.Name = "FireSparksEmitter"
	emitterPart.Size = Vector3.new(3, 1, 3)
	emitterPart.Position = position + Vector3.new(0, 0.5, 0)
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.Transparency = 1
	emitterPart.Parent = ParticleEffects._folder
	table.insert(parts, emitterPart)

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("#FF4500")),
		ColorSequenceKeypoint.new(0.4, Color3.fromHex("#FF8C00")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("#FFD700")),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.3, 0.4),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	emitter.Lifetime = NumberRange.new(0.5, 1.5)
	emitter.Rate = 30
	emitter.Speed = NumberRange.new(4, 10)
	emitter.SpreadAngle = Vector2.new(15, 15)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Acceleration = Vector3.new(0, 3, 0)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.LightEmission = 1
	emitter.Parent = emitterPart

	-- Point light for glow
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromHex("#FF6600")
	glow.Brightness = 2
	glow.Range = 12
	glow.Parent = emitterPart

	ParticleEffects._activeEffects[id] = { parts = parts, connections = connections }

	if not continuous then
		-- 3-second burst for fights
		task.delay(3, function()
			emitter.Enabled = false
			glow.Enabled = false
		end)
		cleanupEffect(id, 6)
	end

	return id
end

-- ============================================================
-- SHIELD GLOW — Blue/cyan particles orbiting player
-- ============================================================

function ParticleEffects.shieldGlow(character, enable)
	if not character then return nil end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end

	-- Cleanup existing shield effect
	local existingShield = rootPart:FindFirstChild("ShieldGlow")
	if existingShield then
		existingShield:Destroy()
	end

	if not enable then return nil end

	local id = nextId()
	local parts = {}
	local connections = {}

	-- Create orbiting attachment on root part
	local attachment = Instance.new("Attachment")
	attachment.Name = "ShieldGlow"
	attachment.Parent = rootPart

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("#00BFFF")),
		ColorSequenceKeypoint.new(0.5, Color3.fromHex("#00FFFF")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("#0088FF")),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.5, 0.3),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	emitter.Lifetime = NumberRange.new(0.8, 1.5)
	emitter.Rate = 25
	emitter.Speed = NumberRange.new(2, 4)
	emitter.SpreadAngle = Vector2.new(360, 360)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-60, 60)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.LightEmission = 0.8
	emitter.Parent = attachment

	-- Soft blue point light
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex("#00BFFF")
	light.Brightness = 1.5
	light.Range = 10
	light.Parent = attachment

	ParticleEffects._activeEffects[id] = { parts = { attachment }, connections = connections }

	return id
end

-- ============================================================
-- SPOTLIGHT SWEEP — Sweeping light in elimination room
-- ============================================================

function ParticleEffects.spotlightSweep(position, duration)
	duration = duration or 15

	local id = nextId()
	local parts = {}
	local connections = {}

	-- Create spotlight part above the center
	local spotPart = Instance.new("Part")
	spotPart.Name = "SpotlightSweep"
	spotPart.Size = Vector3.new(1, 1, 1)
	spotPart.Position = position + Vector3.new(0, 14, 0) -- near ceiling
	spotPart.Anchored = true
	spotPart.CanCollide = false
	spotPart.Transparency = 1
	spotPart.Parent = ParticleEffects._folder
	table.insert(parts, spotPart)

	-- Create a SpotLight pointing downward
	local spotlight = Instance.new("SpotLight")
	spotlight.Color = Color3.fromHex("#F8F4F0")
	spotlight.Brightness = 5
	spotlight.Range = 30
	spotlight.Angle = 25
	spotlight.Face = Enum.NormalId.Bottom
	spotlight.Parent = spotPart

	-- Sweep the spotlight in a circle using RunService
	local startTime = os.clock()
	local radius = 6
	local sweepSpeed = 1.5 -- revolutions per cycle

	local conn = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		if elapsed > duration then return end

		local angle = elapsed * sweepSpeed * math.pi * 2
		local offsetX = math.cos(angle) * radius
		local offsetZ = math.sin(angle) * radius

		spotPart.CFrame = CFrame.new(
			position.X + offsetX,
			position.Y + 14,
			position.Z + offsetZ
		) * CFrame.Angles(math.rad(90 + 20), 0, 0) -- angled downward
	end)
	table.insert(connections, conn)

	ParticleEffects._activeEffects[id] = { parts = parts, connections = connections }

	cleanupEffect(id, duration + 1)

	return id
end

-- ============================================================
-- CROWN SPARKLE — Golden particles around queen's head
-- ============================================================

function ParticleEffects.crownSparkle(character, enable)
	if not character then return nil end

	local head = character:FindFirstChild("Head")
	if not head then return nil end

	-- Cleanup existing sparkle
	local existingSparkle = head:FindFirstChild("CrownSparkle")
	if existingSparkle then
		existingSparkle:Destroy()
	end

	if not enable then return nil end

	local id = nextId()
	local parts = {}
	local connections = {}

	local attachment = Instance.new("Attachment")
	attachment.Name = "CrownSparkle"
	attachment.Position = Vector3.new(0, 1.2, 0) -- above head
	attachment.Parent = head

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("#FFD700")),
		ColorSequenceKeypoint.new(0.5, Color3.fromHex("#FFEC80")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("#FFD700")),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.3, 0.15),
		NumberSequenceKeypoint.new(1, 0.02),
	})
	emitter.Lifetime = NumberRange.new(0.5, 1.2)
	emitter.Rate = 12
	emitter.Speed = NumberRange.new(0.5, 2)
	emitter.SpreadAngle = Vector2.new(360, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-45, 45)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.LightEmission = 1
	emitter.Parent = attachment

	ParticleEffects._activeEffects[id] = { parts = { attachment }, connections = connections }

	return id
end

-- ============================================================
-- CLEANUP ALL
-- ============================================================

function ParticleEffects.cleanup()
	for id, _ in ParticleEffects._activeEffects do
		cleanupEffect(id, 0)
	end
end

return ParticleEffects

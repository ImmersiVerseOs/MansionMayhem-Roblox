-- ============================================================
-- SPECTATOR SYSTEM — Free-fly and follow-cam for eliminated players
-- Cycle between alive players, free-cam with WASD, Tab to toggle mode
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local SpectatorSystem = {}

-- State
SpectatorSystem._active = false
SpectatorSystem._mode = "follow" -- "follow" or "freecam"
SpectatorSystem._targetIndex = 1
SpectatorSystem._alivePlayers = {}
SpectatorSystem._freeCamCFrame = CFrame.new(100, 40, 0) -- starting position
SpectatorSystem._moveSpeed = 40
SpectatorSystem._renderConnection = nil
SpectatorSystem._inputConnection = nil
SpectatorSystem._spectatorHUD = nil

-- Movement keys state
SpectatorSystem._keys = {
	W = false,
	A = false,
	S = false,
	D = false,
	Space = false,
	LeftShift = false,
}

-- ============================================================
-- INITIALIZATION
-- ============================================================

function SpectatorSystem.init()
	-- Nothing to do on init — spectator mode is activated by server event
	print("[SpectatorSystem] Spectator system ready")
end

-- ============================================================
-- ENTER SPECTATOR MODE
-- ============================================================

function SpectatorSystem.enterSpectatorMode()
	if SpectatorSystem._active then return end
	SpectatorSystem._active = true
	SpectatorSystem._mode = "follow"
	SpectatorSystem._targetIndex = 1

	print("[SpectatorSystem] Entering spectator mode")

	-- Build alive player list
	SpectatorSystem._refreshAlivePlayers()

	-- Detach camera from character
	camera.CameraType = Enum.CameraType.Scriptable

	-- Create spectator HUD
	SpectatorSystem._createSpectatorHUD()

	-- Set up input handling
	SpectatorSystem._inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		SpectatorSystem._handleInput(input)
	end)

	-- Track key releases for free-cam movement
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not SpectatorSystem._active then return end
		if gameProcessed then return end
		local keyName = input.KeyCode.Name
		if SpectatorSystem._keys[keyName] ~= nil then
			SpectatorSystem._keys[keyName] = true
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if not SpectatorSystem._active then return end
		local keyName = input.KeyCode.Name
		if SpectatorSystem._keys[keyName] ~= nil then
			SpectatorSystem._keys[keyName] = false
		end
	end)

	-- Start render loop
	SpectatorSystem._renderConnection = RunService.RenderStepped:Connect(function(dt)
		SpectatorSystem._update(dt)
	end)

	-- Start following first alive player
	if #SpectatorSystem._alivePlayers > 0 then
		SpectatorSystem.followPlayer(SpectatorSystem._alivePlayers[1])
	else
		SpectatorSystem.freeCam()
	end
end

-- ============================================================
-- EXIT SPECTATOR MODE
-- ============================================================

function SpectatorSystem.exitSpectatorMode()
	if not SpectatorSystem._active then return end
	SpectatorSystem._active = false

	print("[SpectatorSystem] Exiting spectator mode")

	-- Disconnect render loop
	if SpectatorSystem._renderConnection then
		SpectatorSystem._renderConnection:Disconnect()
		SpectatorSystem._renderConnection = nil
	end

	-- Disconnect input
	if SpectatorSystem._inputConnection then
		SpectatorSystem._inputConnection:Disconnect()
		SpectatorSystem._inputConnection = nil
	end

	-- Reset camera
	camera.CameraType = Enum.CameraType.Custom
	if player.Character then
		camera.CameraSubject = player.Character:FindFirstChild("Humanoid")
	end

	-- Remove spectator HUD
	SpectatorSystem._removeSpectatorHUD()

	-- Reset key state
	for key in SpectatorSystem._keys do
		SpectatorSystem._keys[key] = false
	end
end

-- ============================================================
-- FOLLOW PLAYER MODE
-- ============================================================

function SpectatorSystem.followPlayer(targetPlayer)
	if not SpectatorSystem._active then return end
	if not targetPlayer then return end

	SpectatorSystem._mode = "follow"

	-- Find the target's character
	local character = targetPlayer.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = humanoid
		end
	end

	-- Update HUD
	SpectatorSystem._updateHUD()
end

-- ============================================================
-- FREE CAM MODE
-- ============================================================

function SpectatorSystem.freeCam()
	if not SpectatorSystem._active then return end

	SpectatorSystem._mode = "freecam"
	camera.CameraType = Enum.CameraType.Scriptable

	-- Initialize free cam position from current camera
	SpectatorSystem._freeCamCFrame = camera.CFrame

	-- Update HUD
	SpectatorSystem._updateHUD()
end

-- ============================================================
-- CYCLE PLAYERS
-- ============================================================

function SpectatorSystem.nextPlayer()
	if not SpectatorSystem._active then return end

	SpectatorSystem._refreshAlivePlayers()
	if #SpectatorSystem._alivePlayers == 0 then return end

	SpectatorSystem._targetIndex = SpectatorSystem._targetIndex + 1
	if SpectatorSystem._targetIndex > #SpectatorSystem._alivePlayers then
		SpectatorSystem._targetIndex = 1
	end

	local target = SpectatorSystem._alivePlayers[SpectatorSystem._targetIndex]
	if target then
		SpectatorSystem.followPlayer(target)
	end
end

function SpectatorSystem.prevPlayer()
	if not SpectatorSystem._active then return end

	SpectatorSystem._refreshAlivePlayers()
	if #SpectatorSystem._alivePlayers == 0 then return end

	SpectatorSystem._targetIndex = SpectatorSystem._targetIndex - 1
	if SpectatorSystem._targetIndex < 1 then
		SpectatorSystem._targetIndex = #SpectatorSystem._alivePlayers
	end

	local target = SpectatorSystem._alivePlayers[SpectatorSystem._targetIndex]
	if target then
		SpectatorSystem.followPlayer(target)
	end
end

-- ============================================================
-- UPDATE LOOP
-- ============================================================

function SpectatorSystem._update(dt)
	if not SpectatorSystem._active then return end

	if SpectatorSystem._mode == "freecam" then
		-- Free-fly camera with WASD
		local moveDir = Vector3.new(0, 0, 0)

		if SpectatorSystem._keys.W then
			moveDir = moveDir + camera.CFrame.LookVector
		end
		if SpectatorSystem._keys.S then
			moveDir = moveDir - camera.CFrame.LookVector
		end
		if SpectatorSystem._keys.A then
			moveDir = moveDir - camera.CFrame.RightVector
		end
		if SpectatorSystem._keys.D then
			moveDir = moveDir + camera.CFrame.RightVector
		end
		if SpectatorSystem._keys.Space then
			moveDir = moveDir + Vector3.new(0, 1, 0)
		end
		if SpectatorSystem._keys.LeftShift then
			moveDir = moveDir - Vector3.new(0, 1, 0)
		end

		if moveDir.Magnitude > 0 then
			moveDir = moveDir.Unit * SpectatorSystem._moveSpeed * dt
			SpectatorSystem._freeCamCFrame = CFrame.new(SpectatorSystem._freeCamCFrame.Position + moveDir) * SpectatorSystem._freeCamCFrame.Rotation
		end

		-- Apply mouse rotation from UserInputService
		camera.CFrame = SpectatorSystem._freeCamCFrame

	elseif SpectatorSystem._mode == "follow" then
		-- Camera follows the target player (handled by CameraType.Custom)
		-- Just ensure the target is still valid
		if #SpectatorSystem._alivePlayers > 0 then
			local target = SpectatorSystem._alivePlayers[SpectatorSystem._targetIndex]
			if not target or not target.Parent or not target.Character then
				SpectatorSystem.nextPlayer()
			end
		end
	end
end

-- ============================================================
-- INPUT HANDLING
-- ============================================================

function SpectatorSystem._handleInput(input)
	if not SpectatorSystem._active then return end

	if input.KeyCode == Enum.KeyCode.E then
		SpectatorSystem.nextPlayer()

	elseif input.KeyCode == Enum.KeyCode.Q then
		SpectatorSystem.prevPlayer()

	elseif input.KeyCode == Enum.KeyCode.Tab then
		-- Toggle between free-cam and follow mode
		if SpectatorSystem._mode == "follow" then
			SpectatorSystem.freeCam()
		else
			-- Switch back to follow
			if #SpectatorSystem._alivePlayers > 0 then
				local target = SpectatorSystem._alivePlayers[SpectatorSystem._targetIndex]
				if target then
					SpectatorSystem.followPlayer(target)
				end
			end
		end
	end
end

-- ============================================================
-- ALIVE PLAYER LIST
-- ============================================================

function SpectatorSystem._refreshAlivePlayers()
	SpectatorSystem._alivePlayers = {}

	for _, p in Players:GetPlayers() do
		-- Skip self (we are spectating)
		if p ~= player and p.Character then
			-- Only add players who are not transparent (not spectators themselves)
			local hrp = p.Character:FindFirstChild("HumanoidRootPart")
			if hrp and hrp.Transparency < 0.5 then
				table.insert(SpectatorSystem._alivePlayers, p)
			end
		end
	end

	-- Clamp target index
	if SpectatorSystem._targetIndex > #SpectatorSystem._alivePlayers then
		SpectatorSystem._targetIndex = math.max(1, #SpectatorSystem._alivePlayers)
	end
end

-- ============================================================
-- SPECTATOR HUD
-- ============================================================

function SpectatorSystem._createSpectatorHUD()
	local sg = playerGui:FindFirstChild("MansionUI")
	if not sg then return end

	-- Remove existing if any
	SpectatorSystem._removeSpectatorHUD()

	local hudFrame = Instance.new("Frame")
	hudFrame.Name = "SpectatorHUD"
	hudFrame.Size = UDim2.new(1, 0, 1, 0)
	hudFrame.BackgroundTransparency = 1
	hudFrame.BorderSizePixel = 0
	hudFrame.ZIndex = 5
	hudFrame.Parent = sg

	-- SPECTATOR watermark (semi-transparent, centered)
	local watermark = Instance.new("TextLabel")
	watermark.Name = "Watermark"
	watermark.Size = UDim2.new(0.4, 0, 0, 40)
	watermark.Position = UDim2.new(0.3, 0, 0.05, 0)
	watermark.BackgroundTransparency = 1
	watermark.Text = "SPECTATOR"
	watermark.TextColor3 = Config.Colors.Text
	watermark.TextTransparency = 0.6
	watermark.TextSize = 32
	watermark.Font = Enum.Font.GothamBold
	watermark.Parent = hudFrame

	-- Controls help text at bottom
	local controls = Instance.new("Frame")
	controls.Name = "ControlsHelp"
	controls.Size = UDim2.new(0.5, 0, 0, 70)
	controls.Position = UDim2.new(0.25, 0, 1, -140)
	controls.BackgroundColor3 = Config.Colors.Background
	controls.BackgroundTransparency = 0.4
	controls.BorderSizePixel = 0
	controls.Parent = hudFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = controls

	local controlsText = Instance.new("TextLabel")
	controlsText.Name = "ControlsText"
	controlsText.Size = UDim2.new(0.9, 0, 1, 0)
	controlsText.Position = UDim2.new(0.05, 0, 0, 0)
	controlsText.BackgroundTransparency = 1
	controlsText.Text = "Q/E - Cycle players  |  Tab - Toggle free-cam\nWASD - Move (free-cam)  |  Space/Shift - Up/Down"
	controlsText.TextColor3 = Config.Colors.TextMuted
	controlsText.TextSize = 11
	controlsText.Font = Enum.Font.Gotham
	controlsText.TextWrapped = true
	controlsText.Parent = controls

	-- Target player info (who you're watching)
	local targetInfo = Instance.new("Frame")
	targetInfo.Name = "TargetInfo"
	targetInfo.Size = UDim2.new(0.3, 0, 0, 35)
	targetInfo.Position = UDim2.new(0.35, 0, 0, 60)
	targetInfo.BackgroundColor3 = Config.Colors.Surface
	targetInfo.BackgroundTransparency = 0.3
	targetInfo.BorderSizePixel = 0
	targetInfo.Parent = hudFrame

	local targetCorner = Instance.new("UICorner")
	targetCorner.CornerRadius = UDim.new(0, 8)
	targetCorner.Parent = targetInfo

	local targetLabel = Instance.new("TextLabel")
	targetLabel.Name = "TargetLabel"
	targetLabel.Size = UDim2.new(1, 0, 1, 0)
	targetLabel.BackgroundTransparency = 1
	targetLabel.Text = "Watching: ..."
	targetLabel.TextColor3 = Config.Colors.Pink
	targetLabel.TextSize = 12
	targetLabel.Font = Enum.Font.GothamBold
	targetLabel.Parent = targetInfo

	-- Mode indicator
	local modeLabel = Instance.new("TextLabel")
	modeLabel.Name = "ModeLabel"
	modeLabel.Size = UDim2.new(0.15, 0, 0, 22)
	modeLabel.Position = UDim2.new(0.425, 0, 0, 98)
	modeLabel.BackgroundColor3 = Config.Colors.Card
	modeLabel.BackgroundTransparency = 0.3
	modeLabel.Text = "FOLLOW"
	modeLabel.TextColor3 = Config.Colors.Gold
	modeLabel.TextSize = 10
	modeLabel.Font = Enum.Font.GothamBold
	modeLabel.Parent = hudFrame

	local modeCorner = Instance.new("UICorner")
	modeCorner.CornerRadius = UDim.new(0, 6)
	modeCorner.Parent = modeLabel

	SpectatorSystem._spectatorHUD = hudFrame
	SpectatorSystem._updateHUD()
end

function SpectatorSystem._removeSpectatorHUD()
	local sg = playerGui:FindFirstChild("MansionUI")
	if not sg then return end

	local existing = sg:FindFirstChild("SpectatorHUD")
	if existing then
		existing:Destroy()
	end
	SpectatorSystem._spectatorHUD = nil
end

function SpectatorSystem._updateHUD()
	if not SpectatorSystem._spectatorHUD then return end
	local hud = SpectatorSystem._spectatorHUD

	-- Update target label
	local targetInfo = hud:FindFirstChild("TargetInfo")
	if targetInfo then
		local targetLabel = targetInfo:FindFirstChild("TargetLabel")
		if targetLabel then
			if SpectatorSystem._mode == "follow" and #SpectatorSystem._alivePlayers > 0 then
				local target = SpectatorSystem._alivePlayers[SpectatorSystem._targetIndex]
				if target then
					targetLabel.Text = "Watching: " .. target.DisplayName .. " (" .. SpectatorSystem._targetIndex .. "/" .. #SpectatorSystem._alivePlayers .. ")"
				else
					targetLabel.Text = "Watching: ..."
				end
			elseif SpectatorSystem._mode == "freecam" then
				targetLabel.Text = "Free Camera"
			else
				targetLabel.Text = "No players to watch"
			end
		end
	end

	-- Update mode label
	local modeLabel = hud:FindFirstChild("ModeLabel")
	if modeLabel then
		if SpectatorSystem._mode == "follow" then
			modeLabel.Text = "FOLLOW"
			modeLabel.TextColor3 = Config.Colors.Gold
		else
			modeLabel.Text = "FREE CAM"
			modeLabel.TextColor3 = Config.Colors.Blue
		end
	end
end

return SpectatorSystem

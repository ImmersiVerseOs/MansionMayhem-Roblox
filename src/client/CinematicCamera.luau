-- ============================================================
-- CINEMATIC CAMERA — Dramatic camera control for key moments
-- Elimination ceremonies, Queen crowning, fights, announcements
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local CinematicCamera = {}

-- State
CinematicCamera._isLocked = false
CinematicCamera._originalCameraType = nil
CinematicCamera._activeTween = nil
CinematicCamera._activeConnection = nil
CinematicCamera._darkenFrame = nil

-- ============================================================
-- INITIALIZATION
-- ============================================================

function CinematicCamera.init()
	-- Pre-create the screen darken frame for dramatic reveals
	local playerGui = player:WaitForChild("PlayerGui")
	local sg = playerGui:FindFirstChild("MansionUI")
	if sg then
		local darken = Instance.new("Frame")
		darken.Name = "CinematicDarken"
		darken.Size = UDim2.new(1, 0, 1, 0)
		darken.Position = UDim2.new(0, 0, 0, 0)
		darken.BackgroundColor3 = Color3.new(0, 0, 0)
		darken.BackgroundTransparency = 1 -- fully transparent by default
		darken.BorderSizePixel = 0
		darken.ZIndex = 100
		darken.Visible = false
		darken.Parent = sg

		CinematicCamera._darkenFrame = darken
	end

	print("[CinematicCamera] Initialized")
end

-- ============================================================
-- LOCK / UNLOCK CAMERA
-- ============================================================

function CinematicCamera.lockCamera()
	if CinematicCamera._isLocked then return end

	local camera = workspace.CurrentCamera
	CinematicCamera._originalCameraType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	CinematicCamera._isLocked = true
end

function CinematicCamera.unlockCamera()
	if not CinematicCamera._isLocked then return end

	-- Stop any active connections
	CinematicCamera._stopActive()

	local camera = workspace.CurrentCamera
	camera.CameraType = CinematicCamera._originalCameraType or Enum.CameraType.Custom
	CinematicCamera._isLocked = false

	-- Hide darken
	if CinematicCamera._darkenFrame then
		CinematicCamera._darkenFrame.Visible = false
		CinematicCamera._darkenFrame.BackgroundTransparency = 1
	end
end

function CinematicCamera._stopActive()
	if CinematicCamera._activeTween then
		CinematicCamera._activeTween:Cancel()
		CinematicCamera._activeTween = nil
	end
	if CinematicCamera._activeConnection then
		CinematicCamera._activeConnection:Disconnect()
		CinematicCamera._activeConnection = nil
	end
end

-- ============================================================
-- PAN TO — Smooth camera pan to a target position
-- ============================================================

function CinematicCamera.panTo(targetPosition, duration)
	duration = duration or 2

	CinematicCamera.lockCamera()
	CinematicCamera._stopActive()

	local camera = workspace.CurrentCamera
	local startCFrame = camera.CFrame
	local lookAt = targetPosition

	-- Calculate a good camera position (slightly above and behind)
	local direction = (targetPosition - startCFrame.Position).Unit
	local cameraTarget = targetPosition - direction * 10 + Vector3.new(0, 5, 0)
	local endCFrame = CFrame.new(cameraTarget, lookAt)

	-- Tween the camera
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local startTime = os.clock()

	CinematicCamera._activeConnection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		local alpha = math.clamp(elapsed / duration, 0, 1)

		-- Smooth ease in-out
		local smoothAlpha = alpha * alpha * (3 - 2 * alpha)

		camera.CFrame = startCFrame:Lerp(endCFrame, smoothAlpha)

		if alpha >= 1 then
			CinematicCamera._stopActive()
		end
	end)
end

-- ============================================================
-- ZOOM ON PLAYER — Close-up on a specific player
-- ============================================================

function CinematicCamera.zoomOnPlayer(targetPlayer, distance, duration)
	distance = distance or 6
	duration = duration or 1.5

	CinematicCamera.lockCamera()
	CinematicCamera._stopActive()

	local camera = workspace.CurrentCamera

	-- Find target character
	local character = nil
	if typeof(targetPlayer) == "Instance" and targetPlayer:IsA("Player") then
		character = targetPlayer.Character
	elseif typeof(targetPlayer) == "number" then
		local p = Players:GetPlayerByUserId(targetPlayer)
		if p then character = p.Character end
	end

	if not character then
		CinematicCamera.unlockCamera()
		return
	end

	local head = character:FindFirstChild("Head")
	if not head then
		CinematicCamera.unlockCamera()
		return
	end

	local startCFrame = camera.CFrame
	local startTime = os.clock()

	CinematicCamera._activeConnection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		local alpha = math.clamp(elapsed / duration, 0, 1)
		local smoothAlpha = alpha * alpha * (3 - 2 * alpha)

		-- Target: slightly in front of and above the player's head
		local headPos = head.Position
		local lookDir = head.CFrame.LookVector
		local cameraPos = headPos + lookDir * distance + Vector3.new(0, 1.5, 0)
		local endCFrame = CFrame.new(cameraPos, headPos)

		camera.CFrame = startCFrame:Lerp(endCFrame, smoothAlpha)

		if alpha >= 1 then
			-- Keep following head after zoom
			if CinematicCamera._activeConnection then
				CinematicCamera._activeConnection:Disconnect()
			end
			CinematicCamera._activeConnection = RunService.RenderStepped:Connect(function()
				if not head or not head.Parent then
					CinematicCamera._stopActive()
					return
				end
				local hp = head.Position
				local ld = head.CFrame.LookVector
				local cp = hp + ld * distance + Vector3.new(0, 1.5, 0)
				camera.CFrame = CFrame.new(cp, hp)
			end)
		end
	end)
end

-- ============================================================
-- ORBIT AROUND — Orbit camera around a center point
-- ============================================================

function CinematicCamera.orbitAround(center, radius, duration, height)
	radius = radius or 15
	duration = duration or 8
	height = height or 8

	CinematicCamera.lockCamera()
	CinematicCamera._stopActive()

	local camera = workspace.CurrentCamera
	local startTime = os.clock()

	CinematicCamera._activeConnection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		if elapsed > duration then
			CinematicCamera._stopActive()
			return
		end

		local progress = elapsed / duration
		local angle = progress * math.pi * 2 -- full orbit

		local x = center.X + math.cos(angle) * radius
		local z = center.Z + math.sin(angle) * radius
		local y = center.Y + height

		camera.CFrame = CFrame.new(Vector3.new(x, y, z), center)
	end)
end

-- ============================================================
-- DRAMATIC REVEAL — Slow zoom in with screen darken
-- ============================================================

function CinematicCamera.dramaticReveal(targetPosition)
	CinematicCamera.lockCamera()
	CinematicCamera._stopActive()

	local camera = workspace.CurrentCamera

	-- Darken the screen
	if CinematicCamera._darkenFrame then
		CinematicCamera._darkenFrame.Visible = true
		CinematicCamera._darkenFrame.BackgroundTransparency = 1

		local darkenTween = TweenService:Create(
			CinematicCamera._darkenFrame,
			TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ BackgroundTransparency = 0.6 }
		)
		darkenTween:Play()
	end

	-- Start far away and zoom in slowly
	local startDistance = 30
	local endDistance = 8
	local duration = 4
	local height = 10

	local startPos = targetPosition + Vector3.new(startDistance, height, 0)
	camera.CFrame = CFrame.new(startPos, targetPosition)

	local startTime = os.clock()

	CinematicCamera._activeConnection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		local alpha = math.clamp(elapsed / duration, 0, 1)
		local smoothAlpha = alpha * alpha * (3 - 2 * alpha)

		local currentDistance = startDistance + (endDistance - startDistance) * smoothAlpha
		local currentHeight = height * (1 - smoothAlpha * 0.3)
		local angle = smoothAlpha * math.pi * 0.3 -- slight orbit during zoom

		local x = targetPosition.X + math.cos(angle) * currentDistance
		local z = targetPosition.Z + math.sin(angle) * currentDistance
		local y = targetPosition.Y + currentHeight

		camera.CFrame = CFrame.new(Vector3.new(x, y, z), targetPosition)

		if alpha >= 1 then
			CinematicCamera._stopActive()

			-- Lighten screen back
			if CinematicCamera._darkenFrame then
				task.delay(2, function()
					local lightenTween = TweenService:Create(
						CinematicCamera._darkenFrame,
						TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ BackgroundTransparency = 1 }
					)
					lightenTween:Play()
					lightenTween.Completed:Connect(function()
						CinematicCamera._darkenFrame.Visible = false
					end)
				end)
			end
		end
	end)
end

return CinematicCamera

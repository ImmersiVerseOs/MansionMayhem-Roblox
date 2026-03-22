-- ============================================================
-- LOADING SCREEN — Branded loading screen for Mansion Mayhem
-- Shows while game assets load, with animated tips and effects
-- ============================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local LoadingScreen = {}

-- Loading tips that cycle every 3 seconds
local TIPS = {
	"Form alliances to survive longer...",
	"The Queen chooses who sleeps where...",
	"Check in daily for immunity shards...",
	"Post confessions on the Tea Wall...",
	"The Director is always watching...",
	"3 immunity shards = 1 immunity token...",
	"Win challenges for XP and coins...",
	"The Dog House is no place for a winner...",
}

local _screenGui = nil
local _tipIndex = 1
local _dotCount = 0
local _running = false
local _tipConnection = nil
local _dotConnection = nil

-- ============================================================
-- SHOW — Creates and displays the loading screen
-- ============================================================

function LoadingScreen.show()
	if _screenGui then return end
	_running = true

	local sg = Instance.new("ScreenGui")
	sg.Name = "LoadingScreen"
	sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.DisplayOrder = 100 -- Render above everything
	sg.IgnoreGuiInset = true
	sg.Parent = playerGui
	_screenGui = sg

	-- Full screen dark purple background
	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.Position = UDim2.new(0, 0, 0, 0)
	bg.BackgroundColor3 = Color3.fromHex("#0A0610")
	bg.BorderSizePixel = 0
	bg.Parent = sg

	-- Pink neon border glow (outer frame with gradient)
	local glowBorder = Instance.new("Frame")
	glowBorder.Name = "GlowBorder"
	glowBorder.Size = UDim2.new(1, -20, 1, -20)
	glowBorder.Position = UDim2.new(0, 10, 0, 10)
	glowBorder.BackgroundTransparency = 1
	glowBorder.BorderSizePixel = 0
	glowBorder.Parent = bg

	local borderStroke = Instance.new("UIStroke")
	borderStroke.Color = Color3.fromHex("#FF1493")
	borderStroke.Thickness = 3
	borderStroke.Transparency = 0.3
	borderStroke.Parent = glowBorder

	local borderCorner = Instance.new("UICorner")
	borderCorner.CornerRadius = UDim.new(0, 16)
	borderCorner.Parent = glowBorder

	-- Outer glow layer (softer, larger)
	local glowOuter = Instance.new("Frame")
	glowOuter.Name = "GlowOuter"
	glowOuter.Size = UDim2.new(1, -14, 1, -14)
	glowOuter.Position = UDim2.new(0, 7, 0, 7)
	glowOuter.BackgroundTransparency = 1
	glowOuter.BorderSizePixel = 0
	glowOuter.Parent = bg

	local outerStroke = Instance.new("UIStroke")
	outerStroke.Color = Color3.fromHex("#FF1493")
	outerStroke.Thickness = 6
	outerStroke.Transparency = 0.7
	outerStroke.Parent = glowOuter

	local outerCorner = Instance.new("UICorner")
	outerCorner.CornerRadius = UDim.new(0, 20)
	outerCorner.Parent = glowOuter

	-- Animate the glow border pulsing
	task.spawn(function()
		while _running and borderStroke and borderStroke.Parent do
			TweenService:Create(borderStroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Transparency = 0.1,
			}):Play()
			TweenService:Create(outerStroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Transparency = 0.5,
			}):Play()
			task.wait(1.5)
			if not _running then break end
			TweenService:Create(borderStroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Transparency = 0.5,
			}):Play()
			TweenService:Create(outerStroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Transparency = 0.85,
			}):Play()
			task.wait(1.5)
		end
	end)

	-- Center container for content
	local center = Instance.new("Frame")
	center.Name = "CenterContainer"
	center.Size = UDim2.new(0.8, 0, 0.6, 0)
	center.Position = UDim2.new(0.1, 0, 0.15, 0)
	center.BackgroundTransparency = 1
	center.Parent = bg

	-- Crown symbol above title
	local crown = Instance.new("TextLabel")
	crown.Name = "Crown"
	crown.Size = UDim2.new(1, 0, 0, 60)
	crown.Position = UDim2.new(0, 0, 0.15, 0)
	crown.BackgroundTransparency = 1
	crown.Text = "\xF0\x9F\x91\x91" -- Crown emoji
	crown.TextColor3 = Color3.fromHex("#FFD700")
	crown.TextSize = 48
	crown.Font = Enum.Font.GothamBold
	crown.Parent = center

	-- Main title: MANSION OF MAYHEM
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 60)
	title.Position = UDim2.new(0, 0, 0.32, 0)
	title.BackgroundTransparency = 1
	title.Text = "MANSION OF MAYHEM"
	title.TextColor3 = Color3.fromHex("#FFD700")
	title.TextSize = 42
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.Parent = center

	-- Gold stroke on title for extra pop
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.fromHex("#B8860B")
	titleStroke.Thickness = 1
	titleStroke.Transparency = 0.5
	titleStroke.Parent = title

	-- Tagline
	local tagline = Instance.new("TextLabel")
	tagline.Name = "Tagline"
	tagline.Size = UDim2.new(1, 0, 0, 30)
	tagline.Position = UDim2.new(0, 0, 0.48, 0)
	tagline.BackgroundTransparency = 1
	tagline.Text = "20 players. 10 bedrooms. 1 survivor."
	tagline.TextColor3 = Color3.fromHex("#FF1493")
	tagline.TextSize = 20
	tagline.Font = Enum.Font.GothamBold
	tagline.Parent = center

	-- Loading dots text
	local loadingLabel = Instance.new("TextLabel")
	loadingLabel.Name = "LoadingLabel"
	loadingLabel.Size = UDim2.new(1, 0, 0, 30)
	loadingLabel.Position = UDim2.new(0, 0, 0.62, 0)
	loadingLabel.BackgroundTransparency = 1
	loadingLabel.Text = "Loading"
	loadingLabel.TextColor3 = Color3.fromHex("#F8F4F0")
	loadingLabel.TextSize = 16
	loadingLabel.Font = Enum.Font.Gotham
	loadingLabel.Parent = center

	-- Tip label
	local tipLabel = Instance.new("TextLabel")
	tipLabel.Name = "TipLabel"
	tipLabel.Size = UDim2.new(0.8, 0, 0, 30)
	tipLabel.Position = UDim2.new(0.1, 0, 0.78, 0)
	tipLabel.BackgroundTransparency = 1
	tipLabel.Text = TIPS[1]
	tipLabel.TextColor3 = Color3.fromHex("#808080")
	tipLabel.TextSize = 14
	tipLabel.Font = Enum.Font.GothamMedium
	tipLabel.TextWrapped = true
	tipLabel.Parent = center

	-- Tip prefix
	local tipPrefix = Instance.new("TextLabel")
	tipPrefix.Name = "TipPrefix"
	tipPrefix.Size = UDim2.new(0.8, 0, 0, 20)
	tipPrefix.Position = UDim2.new(0.1, 0, 0.73, 0)
	tipPrefix.BackgroundTransparency = 1
	tipPrefix.Text = "TIP:"
	tipPrefix.TextColor3 = Color3.fromHex("#FF1493")
	tipPrefix.TextSize = 12
	tipPrefix.Font = Enum.Font.GothamBold
	tipPrefix.Parent = center

	-- Animate loading dots
	_dotCount = 0
	task.spawn(function()
		while _running do
			_dotCount = (_dotCount % 3) + 1
			local dots = string.rep(".", _dotCount)
			if loadingLabel and loadingLabel.Parent then
				loadingLabel.Text = "Loading" .. dots
			end
			task.wait(0.5)
		end
	end)

	-- Cycle tips every 3 seconds
	_tipIndex = 1
	task.spawn(function()
		while _running do
			task.wait(3)
			if not _running then break end
			_tipIndex = (_tipIndex % #TIPS) + 1
			if tipLabel and tipLabel.Parent then
				-- Fade out
				TweenService:Create(tipLabel, TweenInfo.new(0.3), {
					TextTransparency = 1,
				}):Play()
				task.wait(0.3)
				if not _running then break end
				tipLabel.Text = TIPS[_tipIndex]
				-- Fade in
				TweenService:Create(tipLabel, TweenInfo.new(0.3), {
					TextTransparency = 0,
				}):Play()
			end
		end
	end)

	print("[LoadingScreen] Displayed")
end

-- ============================================================
-- UPDATE TIP — Manually cycle to next tip
-- ============================================================

function LoadingScreen.updateTip()
	if not _screenGui then return end
	_tipIndex = (_tipIndex % #TIPS) + 1

	local center = _screenGui:FindFirstChild("Background")
	if not center then return end
	center = center:FindFirstChild("CenterContainer")
	if not center then return end
	local tipLabel = center:FindFirstChild("TipLabel")
	if tipLabel then
		tipLabel.Text = TIPS[_tipIndex]
	end
end

-- ============================================================
-- HIDE — Fade out and destroy loading screen
-- ============================================================

function LoadingScreen.hide()
	_running = false

	if not _screenGui then return end

	local bg = _screenGui:FindFirstChild("Background")
	if bg then
		-- Fade out the entire background
		local fadeInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local fadeTween = TweenService:Create(bg, fadeInfo, {
			BackgroundTransparency = 1,
		})

		-- Also fade all children
		for _, desc in bg:GetDescendants() do
			if desc:IsA("TextLabel") then
				TweenService:Create(desc, fadeInfo, {
					TextTransparency = 1,
				}):Play()
			elseif desc:IsA("Frame") then
				TweenService:Create(desc, fadeInfo, {
					BackgroundTransparency = 1,
				}):Play()
			elseif desc:IsA("UIStroke") then
				TweenService:Create(desc, fadeInfo, {
					Transparency = 1,
				}):Play()
			end
		end

		fadeTween:Play()
		fadeTween.Completed:Wait()
	end

	-- Destroy
	if _screenGui then
		_screenGui:Destroy()
		_screenGui = nil
	end

	print("[LoadingScreen] Hidden and destroyed")
end

return LoadingScreen

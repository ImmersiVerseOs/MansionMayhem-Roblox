-- ============================================================
-- TUTORIAL SYSTEM — First-join onboarding walkthrough
-- Step-by-step overlay with dark background + highlighted text
-- ============================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local SoundSystem = require(script.Parent.SoundSystem)

local TutorialSystem = {}

-- Platform detection for adaptive sizing
local isTouch = UserInputService.TouchEnabled
local BASE_TEXT_SCALE = isTouch and 1.25 or 1.0
local MIN_BUTTON_SIZE = isTouch and 48 or 36

-- Tutorial steps
local STEPS = {
	{
		title = "Welcome to Mansion of Mayhem!",
		body = "You've just moved into the most dramatic mansion in Roblox. "
			.. "Compete, scheme, and survive to become Queen of the Mansion!",
		highlight = nil,
	},
	{
		title = "Explore the Mansion",
		body = "Walk around to discover themed rooms like The Crown Suite, "
			.. "Velvet Noir, Neon Paradise, and more. Each room has a unique vibe!",
		highlight = nil,
	},
	{
		title = "Form Alliances",
		body = "Team up with other players for protection. But watch out — "
			.. "alliances can be broken! Tap the ALLY tab to manage your crew.",
		highlight = nil,
	},
	{
		title = "Daily Check-In",
		body = "Tap CHECK IN every day to earn XP and build your streak. "
			.. "Hit a 7-day streak for an Immunity Shard!",
		highlight = nil,
	},
	{
		title = "The Tea Wall",
		body = "Got secrets? Post confessions on the Tea Wall for everyone to see. "
			.. "Read the drama, spill the tea, stir the pot!",
		highlight = nil,
	},
	{
		title = "Survive Elimination",
		body = "Each round, players vote to eliminate someone. Use Immunity Tokens "
			.. "to protect yourself. Collect 3 shards to earn a token!",
		highlight = nil,
	},
	{
		title = "Become Queen!",
		body = "The player with the most XP, alliances, and strategy earns the crown. "
			.. "Reign supreme — until someone takes it from you!",
		highlight = nil,
	},
}

-- ============================================================
-- CHECK IF TUTORIAL NEEDED
-- ============================================================

function TutorialSystem.shouldShow()
	local attr = player:GetAttribute("TutorialComplete")
	return not attr
end

-- ============================================================
-- SHOW TUTORIAL
-- ============================================================

function TutorialSystem.show()
	if not TutorialSystem.shouldShow() then return end

	local sg = Instance.new("ScreenGui")
	sg.Name = "TutorialUI"
	sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.DisplayOrder = 100 -- Above all other UI
	sg.Parent = playerGui

	-- Dark overlay background
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 50
	overlay.Parent = sg

	-- Content card
	local card = Instance.new("Frame")
	card.Name = "TutorialCard"
	card.Size = UDim2.new(0.5, 0, 0.45, 0)
	card.Position = UDim2.new(0.25, 0, 0.275, 0)
	card.BackgroundColor3 = Config.Colors.Surface
	card.BorderSizePixel = 0
	card.ZIndex = 51
	card.Parent = sg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = Config.Colors.Gold
	stroke.Thickness = 2
	stroke.Parent = card

	-- Step counter (e.g., "1 / 7")
	local stepCounter = Instance.new("TextLabel")
	stepCounter.Name = "StepCounter"
	stepCounter.Size = UDim2.new(1, 0, 0, 24)
	stepCounter.Position = UDim2.new(0, 0, 0, 10)
	stepCounter.BackgroundTransparency = 1
	stepCounter.Text = "1 / " .. #STEPS
	stepCounter.TextColor3 = Config.Colors.TextMuted
	stepCounter.TextSize = math.floor(11 * BASE_TEXT_SCALE)
	stepCounter.Font = Enum.Font.Gotham
	stepCounter.ZIndex = 52
	stepCounter.Parent = card

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0.85, 0, 0, 40)
	title.Position = UDim2.new(0.075, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Text = ""
	title.TextColor3 = Config.Colors.Gold
	title.TextSize = math.floor(22 * BASE_TEXT_SCALE)
	title.Font = Enum.Font.GothamBold
	title.TextWrapped = true
	title.ZIndex = 52
	title.Parent = card

	-- Body text
	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Size = UDim2.new(0.85, 0, 0.4, 0)
	body.Position = UDim2.new(0.075, 0, 0, 90)
	body.BackgroundTransparency = 1
	body.Text = ""
	body.TextColor3 = Config.Colors.Text
	body.TextSize = math.floor(14 * BASE_TEXT_SCALE)
	body.Font = Enum.Font.Gotham
	body.TextWrapped = true
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.ZIndex = 52
	body.Parent = card

	-- Progress dots
	local dotsFrame = Instance.new("Frame")
	dotsFrame.Name = "Dots"
	dotsFrame.Size = UDim2.new(0.5, 0, 0, 12)
	dotsFrame.Position = UDim2.new(0.25, 0, 1, -60)
	dotsFrame.BackgroundTransparency = 1
	dotsFrame.ZIndex = 52
	dotsFrame.Parent = card

	local dotsLayout = Instance.new("UIListLayout")
	dotsLayout.FillDirection = Enum.FillDirection.Horizontal
	dotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dotsLayout.Padding = UDim.new(0, 8)
	dotsLayout.Parent = dotsFrame

	for i = 1, #STEPS do
		local dot = Instance.new("Frame")
		dot.Name = "Dot_" .. i
		dot.Size = UDim2.new(0, 10, 0, 10)
		dot.BackgroundColor3 = Config.Colors.Border
		dot.BorderSizePixel = 0
		dot.ZIndex = 52
		dot.Parent = dotsFrame

		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(1, 0)
		dotCorner.Parent = dot
	end

	-- Next button
	local nextBtnHeight = math.max(MIN_BUTTON_SIZE, 36)
	local nextBtn = Instance.new("TextButton")
	nextBtn.Name = "NextBtn"
	nextBtn.Size = UDim2.new(0.35, 0, 0, nextBtnHeight)
	nextBtn.Position = UDim2.new(0.55, 0, 1, -(nextBtnHeight + 12))
	nextBtn.BackgroundColor3 = Config.Colors.Pink
	nextBtn.Text = "Next"
	nextBtn.TextColor3 = Color3.new(1, 1, 1)
	nextBtn.TextSize = math.floor(14 * BASE_TEXT_SCALE)
	nextBtn.Font = Enum.Font.GothamBold
	nextBtn.ZIndex = 52
	nextBtn.Parent = card

	local nextCorner = Instance.new("UICorner")
	nextCorner.CornerRadius = UDim.new(0, 8)
	nextCorner.Parent = nextBtn

	-- Skip button
	local skipBtn = Instance.new("TextButton")
	skipBtn.Name = "SkipBtn"
	skipBtn.Size = UDim2.new(0.35, 0, 0, nextBtnHeight)
	skipBtn.Position = UDim2.new(0.1, 0, 1, -(nextBtnHeight + 12))
	skipBtn.BackgroundTransparency = 1
	skipBtn.Text = "Skip Tutorial"
	skipBtn.TextColor3 = Config.Colors.TextMuted
	skipBtn.TextSize = math.floor(12 * BASE_TEXT_SCALE)
	skipBtn.Font = Enum.Font.GothamBold
	skipBtn.ZIndex = 52
	skipBtn.Parent = card

	-- State
	local currentStep = 1

	local function updateStep()
		local step = STEPS[currentStep]
		title.Text = step.title
		body.Text = step.body
		stepCounter.Text = currentStep .. " / " .. #STEPS

		-- Update dots
		for i = 1, #STEPS do
			local dot = dotsFrame:FindFirstChild("Dot_" .. i)
			if dot then
				dot.BackgroundColor3 = (i == currentStep) and Config.Colors.Pink or Config.Colors.Border
			end
		end

		-- Update button text on last step
		if currentStep == #STEPS then
			nextBtn.Text = "Let's Go!"
			nextBtn.BackgroundColor3 = Config.Colors.Gold
		else
			nextBtn.Text = "Next"
			nextBtn.BackgroundColor3 = Config.Colors.Pink
		end

		-- Animate card entrance
		card.Position = UDim2.new(0.25, 0, 0.3, 0)
		card.BackgroundTransparency = 0.1
		TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.25, 0, 0.275, 0),
			BackgroundTransparency = 0,
		}):Play()
	end

	local function completeTutorial()
		SoundSystem.play("ui_click")
		player:SetAttribute("TutorialComplete", true)

		-- Fade out
		TweenService:Create(overlay, TweenInfo.new(0.4), {
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
			Position = UDim2.new(0.25, 0, 1.2, 0),
		}):Play()

		task.delay(0.5, function()
			sg:Destroy()
		end)
	end

	nextBtn.MouseButton1Click:Connect(function()
		SoundSystem.play("ui_click")
		if currentStep < #STEPS then
			currentStep += 1
			updateStep()
		else
			completeTutorial()
		end
	end)

	skipBtn.MouseButton1Click:Connect(function()
		completeTutorial()
	end)

	-- Show first step
	updateStep()
	SoundSystem.play("notification")
end

return TutorialSystem

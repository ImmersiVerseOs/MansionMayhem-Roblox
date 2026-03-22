-- ============================================================
-- MAIN UI — Client-side HUD and interactive screens
-- Voting, Elimination, Fight alerts, Alliances, Challenges,
-- Immunity, Season info, Leaderboard
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for shared config
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local SoundSystem = require(script.Parent.SoundSystem)
local ShopUI = require(script.Parent.ShopUI)
local SpectatorSystem = require(script.Parent.SpectatorSystem)

local MainUI = {}

-- Track open panels
MainUI._teaOpen = false
MainUI._activePanelName = nil

-- Platform detection
local isTouch = UserInputService.TouchEnabled
local isGamepad = UserInputService.GamepadEnabled

-- Adaptive scaling based on platform
local BASE_TEXT_SCALE = isTouch and 1.25 or 1.0
local MIN_BUTTON_SIZE = isTouch and 48 or 30
local NAV_HEIGHT = isTouch and 72 or 60
local HUD_HEIGHT = isTouch and 60 or 50

-- ============================================================
-- HELPERS
-- ============================================================

local function createCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = parent
	return corner
end

local function createStroke(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Config.Colors.Border
	stroke.Thickness = thickness or 1
	stroke.Parent = parent
	return stroke
end

local function tweenIn(frame, targetPos, duration)
	TweenService:Create(frame, TweenInfo.new(duration or 0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Position = targetPos,
	}):Play()
end

local function tweenOut(frame, targetPos, duration)
	TweenService:Create(frame, TweenInfo.new(duration or 0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
		Position = targetPos,
	}):Play()
end

local function createCloseButton(parent, callback)
	local closeBtnSize = math.max(MIN_BUTTON_SIZE, 30)
	local btn = Instance.new("TextButton")
	btn.Name = "CloseBtn"
	btn.Size = UDim2.new(0, closeBtnSize, 0, closeBtnSize)
	btn.Position = UDim2.new(1, -(closeBtnSize + 5), 0, 5)
	btn.BackgroundTransparency = 1
	btn.Text = "X"
	btn.TextColor3 = Config.Colors.TextMuted
	btn.TextSize = math.floor(16 * BASE_TEXT_SCALE)
	btn.Font = Enum.Font.GothamBold
	btn.Parent = parent
	btn.MouseButton1Click:Connect(function()
		SoundSystem.play("ui_click")
		callback()
	end)
	return btn
end

-- ============================================================
-- INITIALIZATION
-- ============================================================

function MainUI.init()
	-- Initialize sound system
	SoundSystem.init()

	local sg = Instance.new("ScreenGui")
	sg.Name = "MansionUI"
	sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.Parent = playerGui

	-- Core UI
	MainUI.createHUD(sg)
	MainUI.createBottomNav(sg)
	MainUI.createTeaPanel(sg)
	MainUI.createDirectorOverlay(sg)
	MainUI.createCheckInPopup(sg)

	-- New panels
	MainUI.createVotingScreen(sg)
	MainUI.createEliminationOverlay(sg)
	MainUI.createFightAlertPopup(sg)
	MainUI.createAlliancePanel(sg)
	MainUI.createChallengePanel(sg)
	MainUI.createImmunityHUD(sg)
	MainUI.createSeasonInfoPanel(sg)
	MainUI.createLeaderboardPanel(sg)

	-- Bus UI elements
	MainUI.createBusUI(sg)

	-- Shop panel
	ShopUI.createShopPanel(sg)

	-- Initialize spectator system
	SpectatorSystem.init()

	-- Gamepad support: create selection highlight
	if isGamepad then
		MainUI._setupGamepadNav(sg)
	end

	-- Listen for server events
	MainUI.listenForEvents()

	-- Start ambient background music
	SoundSystem.playMusic("mansion_ambient")

	print("[MainUI] UI initialized")
end

-- ============================================================
-- GAMEPAD NAVIGATION SUPPORT
-- ============================================================

function MainUI._setupGamepadNav(sg)
	-- Add gamepad prompts overlay
	local promptFrame = Instance.new("Frame")
	promptFrame.Name = "GamepadPrompts"
	promptFrame.Size = UDim2.new(0, 200, 0, 30)
	promptFrame.Position = UDim2.new(1, -210, 1, -(NAV_HEIGHT + 35))
	promptFrame.BackgroundTransparency = 1
	promptFrame.Parent = sg

	local aPrompt = Instance.new("TextLabel")
	aPrompt.Name = "APrompt"
	aPrompt.Size = UDim2.new(0.5, 0, 1, 0)
	aPrompt.BackgroundTransparency = 1
	aPrompt.Text = "[A] Confirm"
	aPrompt.TextColor3 = Config.Colors.Green
	aPrompt.TextSize = math.floor(11 * BASE_TEXT_SCALE)
	aPrompt.Font = Enum.Font.GothamBold
	aPrompt.TextXAlignment = Enum.TextXAlignment.Right
	aPrompt.Parent = promptFrame

	local bPrompt = Instance.new("TextLabel")
	bPrompt.Name = "BPrompt"
	bPrompt.Size = UDim2.new(0.5, 0, 1, 0)
	bPrompt.Position = UDim2.new(0.5, 0, 0, 0)
	bPrompt.BackgroundTransparency = 1
	bPrompt.Text = "[B] Back"
	bPrompt.TextColor3 = Config.Colors.Red
	bPrompt.TextSize = math.floor(11 * BASE_TEXT_SCALE)
	bPrompt.Font = Enum.Font.GothamBold
	bPrompt.TextXAlignment = Enum.TextXAlignment.Right
	bPrompt.Parent = promptFrame

	-- Set initial selected object to bottom nav first button when gamepad connects
	task.defer(function()
		local nav = sg:FindFirstChild("BottomNav")
		if nav then
			local firstBtn = nav:FindFirstChildWhichIsA("TextButton")
			if firstBtn then
				GuiService.SelectedObject = firstBtn
			end
		end
	end)

	-- B button closes current panel
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.ButtonB then
			MainUI._closeAllPanels()
		end
	end)
end

-- ============================================================
-- HUD (Top Bar)
-- ============================================================

function MainUI.createHUD(parent)
	local hud = Instance.new("Frame")
	hud.Name = "HUD"
	hud.Size = UDim2.new(1, 0, 0, HUD_HEIGHT)
	hud.Position = UDim2.new(0, 0, 0, 0)
	hud.BackgroundColor3 = Config.Colors.Background
	hud.BackgroundTransparency = 0.2
	hud.BorderSizePixel = 0
	hud.Parent = parent

	-- Season title
	local title = Instance.new("TextLabel")
	title.Name = "SeasonTitle"
	title.Size = UDim2.new(0.4, 0, 1, 0)
	title.Position = UDim2.new(0, 12, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "MANSION OF MAYHEM"
	title.TextColor3 = Config.Colors.Gold
	title.TextSize = math.floor(16 * BASE_TEXT_SCALE)
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = hud

	-- Phase indicator
	local phase = Instance.new("TextLabel")
	phase.Name = "PhaseLabel"
	phase.Size = UDim2.new(0.25, 0, 1, 0)
	phase.Position = UDim2.new(0.4, 0, 0, 0)
	phase.BackgroundTransparency = 1
	phase.Text = "MOVE IN"
	phase.TextColor3 = Config.Colors.Pink
	phase.TextSize = math.floor(12 * BASE_TEXT_SCALE)
	phase.Font = Enum.Font.GothamBold
	phase.Parent = hud

	-- Invite Friends button
	local inviteBtnSize = math.max(MIN_BUTTON_SIZE, 30)
	local inviteBtn = Instance.new("TextButton")
	inviteBtn.Name = "InviteBtn"
	inviteBtn.Size = UDim2.new(0, 80, 0, inviteBtnSize)
	inviteBtn.Position = UDim2.new(0.65, 0, 0.5, -(inviteBtnSize / 2))
	inviteBtn.BackgroundColor3 = Config.Colors.Pink
	inviteBtn.BackgroundTransparency = 0.3
	inviteBtn.Text = "Invite"
	inviteBtn.TextColor3 = Config.Colors.Text
	inviteBtn.TextSize = math.floor(12 * BASE_TEXT_SCALE)
	inviteBtn.Font = Enum.Font.GothamBold
	inviteBtn.Parent = hud
	createCorner(inviteBtn, 6)
	createStroke(inviteBtn, Config.Colors.Pink, 1)

	inviteBtn.MouseButton1Click:Connect(function()
		SoundSystem.play("ui_click")
		local SocialService = game:GetService("SocialService")
		local success, canInvite = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		if success and canInvite then
			SocialService:PromptGameInvite(player)
		end
	end)

	-- Bottom border neon
	local border = Instance.new("Frame")
	border.Size = UDim2.new(1, 0, 0, 2)
	border.Position = UDim2.new(0, 0, 1, -2)
	border.BackgroundColor3 = Config.Colors.Pink
	border.BorderSizePixel = 0
	border.Parent = hud
end

-- ============================================================
-- IMMUNITY HUD (shard counter — always visible)
-- ============================================================

function MainUI.createImmunityHUD(parent)
	local frame = Instance.new("Frame")
	frame.Name = "ImmunityHUD"
	frame.Size = UDim2.new(0, 140, 0, 40)
	frame.Position = UDim2.new(1, -155, 0, 5)
	frame.BackgroundColor3 = Config.Colors.Surface
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.Parent = parent

	createCorner(frame, 8)

	-- Shield icon + shard count
	local shardLabel = Instance.new("TextLabel")
	shardLabel.Name = "ShardLabel"
	shardLabel.Size = UDim2.new(0.5, 0, 1, 0)
	shardLabel.Position = UDim2.new(0, 5, 0, 0)
	shardLabel.BackgroundTransparency = 1
	shardLabel.Text = "0/3"
	shardLabel.TextColor3 = Config.Colors.Blue
	shardLabel.TextSize = 12
	shardLabel.Font = Enum.Font.GothamBold
	shardLabel.TextXAlignment = Enum.TextXAlignment.Left
	shardLabel.Parent = frame

	-- Token count
	local tokenLabel = Instance.new("TextLabel")
	tokenLabel.Name = "TokenLabel"
	tokenLabel.Size = UDim2.new(0.5, 0, 1, 0)
	tokenLabel.Position = UDim2.new(0.5, 0, 0, 0)
	tokenLabel.BackgroundTransparency = 1
	tokenLabel.Text = "0 tokens"
	tokenLabel.TextColor3 = Config.Colors.Gold
	tokenLabel.TextSize = 12
	tokenLabel.Font = Enum.Font.GothamBold
	tokenLabel.TextXAlignment = Enum.TextXAlignment.Right
	tokenLabel.Parent = frame
end

function MainUI.updateImmunityHUD(shards, tokens)
	local sg = playerGui:FindFirstChild("MansionUI")
	if not sg then return end
	local frame = sg:FindFirstChild("ImmunityHUD")
	if not frame then return end

	frame.ShardLabel.Text = tostring(shards or 0) .. "/3"
	frame.TokenLabel.Text = tostring(tokens or 0) .. " tokens"
end

-- ============================================================
-- BOTTOM NAV
-- ============================================================

function MainUI.createBottomNav(parent)
	local nav = Instance.new("Frame")
	nav.Name = "BottomNav"
	nav.Size = UDim2.new(1, 0, 0, NAV_HEIGHT)
	nav.Position = UDim2.new(0, 0, 1, -NAV_HEIGHT)
	nav.BackgroundColor3 = Config.Colors.Surface
	nav.BackgroundTransparency = 0.1
	nav.BorderSizePixel = 0
	nav.Parent = parent

	local topBorder = Instance.new("Frame")
	topBorder.Size = UDim2.new(1, 0, 0, 1)
	topBorder.BackgroundColor3 = Config.Colors.Border
	topBorder.BorderSizePixel = 0
	topBorder.Parent = nav

	local tabs = {
		{ text = "Home",       emoji = "HOME" },
		{ text = "Tea",        emoji = "TEA" },
		{ text = "Check In",   emoji = "CHECK" },
		{ text = "Vote",       emoji = "VOTE" },
		{ text = "Alliance",   emoji = "ALLY" },
		{ text = "Challenge",  emoji = "QUEST" },
		{ text = "Shop",       emoji = "\xF0\x9F\x92\x8E" },
		{ text = "Season",     emoji = "INFO" },
		{ text = "Ranks",      emoji = "RANK" },
	}

	local tabTextSize = math.floor(8 * BASE_TEXT_SCALE)
	if isTouch then tabTextSize = math.max(tabTextSize, 10) end

	for i, tab in tabs do
		local btn = Instance.new("TextButton")
		btn.Name = "Tab_" .. tab.text
		btn.Size = UDim2.new(1 / #tabs, 0, 1, -5)
		btn.Position = UDim2.new((i - 1) / #tabs, 0, 0, 5)
		btn.BackgroundTransparency = 1
		btn.Text = tab.emoji .. "\n" .. tab.text
		btn.TextColor3 = Config.Colors.TextMuted
		btn.TextSize = tabTextSize
		btn.Font = Enum.Font.GothamBold
		btn.Parent = nav

		-- Gamepad selection highlighting
		if isGamepad then
			btn.SelectionImageObject = MainUI._createSelectionHighlight()
		end

		btn.MouseButton1Click:Connect(function()
			SoundSystem.play("ui_click")
			MainUI.onTabClick(tab.text)
			for _, child in nav:GetChildren() do
				if child:IsA("TextButton") then
					child.TextColor3 = Config.Colors.TextMuted
				end
			end
			btn.TextColor3 = Config.Colors.Pink
		end)
	end
end

function MainUI._createSelectionHighlight()
	local highlight = Instance.new("ImageLabel")
	highlight.Name = "SelectionHighlight"
	highlight.Size = UDim2.new(1, 4, 1, 4)
	highlight.Position = UDim2.new(0, -2, 0, -2)
	highlight.BackgroundColor3 = Config.Colors.Pink
	highlight.BackgroundTransparency = 0.7
	highlight.BorderSizePixel = 0
	highlight.Image = ""
	createCorner(highlight, 6)
	createStroke(highlight, Config.Colors.Pink, 2)
	return highlight
end

function MainUI.onTabClick(tabName)
	-- Close any open panel first
	MainUI._closeAllPanels()

	if tabName == "Tea" then
		MainUI.toggleTeaPanel()
	elseif tabName == "Check In" then
		MainUI.showCheckIn()
	elseif tabName == "Vote" then
		-- Voting handled by server push
	elseif tabName == "Alliance" then
		MainUI.togglePanel("AlliancePanel")
	elseif tabName == "Challenge" then
		MainUI.togglePanel("ChallengePanel")
	elseif tabName == "Season" then
		MainUI.togglePanel("SeasonInfoPanel")
		-- Request fresh data
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		if remotes then
			local req = remotes:FindFirstChild("SeasonInfoRequest")
			if req then req:FireServer() end
		end
	elseif tabName == "Shop" then
		MainUI.togglePanel("ShopPanel")
	elseif tabName == "Ranks" then
		MainUI.togglePanel("LeaderboardPanel")
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		if remotes then
			local req = remotes:FindFirstChild("LeaderboardRequest")
			if req then req:FireServer() end
		end
	end
end

function MainUI._closeAllPanels()
	local sg = playerGui:FindFirstChild("MansionUI")
	if not sg then return end

	local panels = { "AlliancePanel", "ChallengePanel", "SeasonInfoPanel", "LeaderboardPanel", "ShopPanel" }
	for _, name in panels do
		local panel = sg:FindFirstChild(name)
		if panel and panel.Visible then
			panel.Visible = false
		end
	end

	if MainUI._teaOpen then
		MainUI.toggleTeaPanel()
	end

	MainUI._activePanelName = nil
end

function MainUI.togglePanel(panelName)
	local sg = playerGui:FindFirstChild("MansionUI")
	if not sg then return end

	local panel = sg:FindFirstChild(panelName)
	if not panel then return end

	if MainUI._activePanelName == panelName then
		panel.Visible = false
		MainUI._activePanelName = nil
	else
		panel.Visible = true
		MainUI._activePanelName = panelName
	end
end

-- ============================================================
-- TEA WALL PANEL
-- ============================================================

function MainUI.createTeaPanel(parent)
	local panel = Instance.new("ScrollingFrame")
	panel.Name = "TeaPanel"
	panel.Size = UDim2.new(0.35, 0, 0.7, 0)
	panel.Position = UDim2.new(1, 0, 0.05, 0)
	panel.BackgroundColor3 = Config.Colors.Surface
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.ScrollBarThickness = 4
	panel.CanvasSize = UDim2.new(0, 0, 0, 0)
	panel.Parent = parent

	createCorner(panel)
	createStroke(panel, Config.Colors.Border)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 35)
	title.BackgroundColor3 = Config.Colors.Card
	title.BorderSizePixel = 0
	title.Text = "TEA ROOM"
	title.TextColor3 = Config.Colors.Gold
	title.TextSize = 14
	title.Font = Enum.Font.GothamBold
	title.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = panel
end

function MainUI.toggleTeaPanel()
	local sg = playerGui:FindFirstChild("MansionUI")
	if not sg then return end
	local panel = sg.TeaPanel
	MainUI._teaOpen = not MainUI._teaOpen

	local target = MainUI._teaOpen
		and UDim2.new(0.64, 0, 0.05, 0)
		or UDim2.new(1, 0, 0.05, 0)

	TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Position = target,
	}):Play()
end

function MainUI.updateTeaWall(confessions)
	local sg = playerGui:FindFirstChild("MansionUI")
	if not sg then return end
	local panel = sg.TeaPanel
	for _, child in panel:GetChildren() do
		if child:IsA("Frame") then child:Destroy() end
	end

	local order = 1
	for _, c in confessions do
		local card = Instance.new("Frame")
		card.Name = "Confession_" .. order
		card.Size = UDim2.new(1, -8, 0, 60)
		card.BackgroundColor3 = Config.Colors.Card
		card.BorderSizePixel = 0
		card.LayoutOrder = order
		card.Parent = panel
		createCorner(card, 6)

		local author = Instance.new("TextLabel")
		author.Size = UDim2.new(1, -8, 0, 14)
		author.Position = UDim2.new(0, 4, 0, 4)
		author.BackgroundTransparency = 1
		author.Text = c.cast_members and c.cast_members.display_name or "Anonymous"
		author.TextColor3 = Config.Colors.Pink
		author.TextSize = 11
		author.Font = Enum.Font.GothamBold
		author.TextXAlignment = Enum.TextXAlignment.Left
		author.Parent = card

		local text = Instance.new("TextLabel")
		text.Size = UDim2.new(1, -8, 1, -22)
		text.Position = UDim2.new(0, 4, 0, 20)
		text.BackgroundTransparency = 1
		text.Text = c.confession_text or ""
		text.TextColor3 = Config.Colors.Text
		text.TextSize = 11
		text.Font = Enum.Font.Gotham
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextYAlignment = Enum.TextYAlignment.Top
		text.TextWrapped = true
		text.Parent = card

		order += 1
	end

	panel.CanvasSize = UDim2.new(0, 0, 0, order * 64 + 40)
end

-- ============================================================
-- DIRECTOR ANNOUNCEMENT OVERLAY
-- ============================================================

function MainUI.createDirectorOverlay(parent)
	local overlay = Instance.new("Frame")
	overlay.Name = "DirectorOverlay"
	overlay.Size = UDim2.new(0.6, 0, 0, 80)
	overlay.Position = UDim2.new(0.2, 0, -0.15, 0)
	overlay.BackgroundColor3 = Config.Colors.Background
	overlay.BackgroundTransparency = 0.1
	overlay.BorderSizePixel = 0
	overlay.Parent = parent

	createCorner(overlay)
	createStroke(overlay, Config.Colors.Gold)

	local label = Instance.new("TextLabel")
	label.Name = "DirectorLabel"
	label.Size = UDim2.new(0, 120, 0, 16)
	label.Position = UDim2.new(0, 12, 0, 8)
	label.BackgroundTransparency = 1
	label.Text = "THE DIRECTOR"
	label.TextColor3 = Config.Colors.Gold
	label.TextSize = 10
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = overlay

	local msg = Instance.new("TextLabel")
	msg.Name = "DirectorText"
	msg.Size = UDim2.new(1, -24, 1, -26)
	msg.Position = UDim2.new(0, 12, 0, 26)
	msg.BackgroundTransparency = 1
	msg.Text = ""
	msg.TextColor3 = Config.Colors.Text
	msg.TextSize = 13
	msg.Font = Enum.Font.Gotham
	msg.TextXAlignment = Enum.TextXAlignment.Left
	msg.TextWrapped = true
	msg.Parent = overlay
end

function MainUI.showDirectorAnnouncement(message)
	local sg = playerGui:FindFirstChild("MansionUI")
	if not sg then return end
	local overlay = sg.DirectorOverlay
	overlay.DirectorText.Text = message

	SoundSystem.play("director_chime")
	tweenIn(overlay, UDim2.new(0.2, 0, 0.02, 0), 0.5)

	task.delay(6, function()
		tweenOut(overlay, UDim2.new(0.2, 0, -0.15, 0), 0.5)
	end)
end

-- ============================================================
-- CHECK-IN POPUP
-- ============================================================

function MainUI.createCheckInPopup(parent)
	local popup = Instance.new("Frame")
	popup.Name = "CheckInPopup"
	popup.Size = UDim2.new(0.4, 0, 0.3, 0)
	popup.Position = UDim2.new(0.3, 0, 0.35, 0)
	popup.BackgroundColor3 = Config.Colors.Surface
	popup.BorderSizePixel = 0
	popup.Visible = false
	popup.Parent = parent

	createCorner(popup, 14)
	createStroke(popup, Config.Colors.Gold)

	local title = Instance.new("TextLabel")
	title.Name = "CheckInTitle"
	title.Size = UDim2.new(1, 0, 0.3, 0)
	title.Position = UDim2.new(0, 0, 0.15, 0)
	title.BackgroundTransparency = 1
	title.Text = "Daily Check-In"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextSize = 18
	title.Font = Enum.Font.GothamBold
	title.Parent = popup

	local btn = Instance.new("TextButton")
	btn.Name = "CheckInBtn"
	btn.Size = UDim2.new(0.6, 0, 0.2, 0)
	btn.Position = UDim2.new(0.2, 0, 0.6, 0)
	btn.BackgroundColor3 = Config.Colors.Pink
	btn.Text = "CHECK IN NOW"
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.TextSize = 14
	btn.Font = Enum.Font.GothamBold
	btn.Parent = popup
	createCorner(btn, 8)

	btn.MouseButton1Click:Connect(function()
		SoundSystem.play("ui_click")
		local remote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("RequestCheckIn")
		if remote then remote:FireServer() end
		btn.Text = "..."
	end)

	createCloseButton(popup, function()
		popup.Visible = false
	end)
end

function MainUI.showCheckIn()
	local sg = playerGui:FindFirstChild("MansionUI")
	if not sg then return end
	sg.CheckInPopup.Visible = true
	sg.CheckInPopup.CheckInBtn.Text = "CHECK IN NOW"
	sg.CheckInPopup.CheckInTitle.Text = "Daily Check-In"
end

function MainUI.showCheckInResult(result)
	local sg = playerGui:FindFirstChild("MansionUI")
	if not sg then return end
	local popup = sg.CheckInPopup
	if result.already_checked_in then
		popup.CheckInTitle.Text = "Already checked in today!"
		popup.CheckInBtn.Text = "DONE"
	else
		SoundSystem.play("check_in_success")
		popup.CheckInTitle.Text = "+" .. (result.xp_earned or 10) .. " XP | " .. (result.streak or 1) .. " day streak"
		popup.CheckInBtn.Text = "CHECKED IN"
		if result.immunity_shard_awarded then
			popup.CheckInTitle.Text = popup.CheckInTitle.Text .. "\nIMMUNITY SHARD EARNED!"
		end
	end
	task.delay(3, function() popup.Visible = false end)
end

-- ============================================================
-- VOTING SCREEN
-- ============================================================

function MainUI.createVotingScreen(parent)
	local panel = Instance.new("Frame")
	panel.Name = "VotingScreen"
	panel.Size = UDim2.new(0.5, 0, 0.6, 0)
	panel.Position = UDim2.new(0.25, 0, 0.15, 0)
	panel.BackgroundColor3 = Config.Colors.Background
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 10
	panel.Parent = parent

	createCorner(panel, 14)
	createStroke(panel, Config.Colors.Red, 2)

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "VoteTitle"
	title.Size = UDim2.new(1, 0, 0, 45)
	title.BackgroundColor3 = Config.Colors.Red
	title.BackgroundTransparency = 0.5
	title.BorderSizePixel = 0
	title.Text = "ELIMINATION VOTE"
	title.TextColor3 = Config.Colors.Gold
	title.TextSize = 20
	title.Font = Enum.Font.GothamBold
	title.Parent = panel
	createCorner(title, 14)

	-- Timer
	local timer = Instance.new("TextLabel")
	timer.Name = "VoteTimer"
	timer.Size = UDim2.new(1, 0, 0, 20)
	timer.Position = UDim2.new(0, 0, 0, 45)
	timer.BackgroundTransparency = 1
	timer.Text = "60 seconds remaining"
	timer.TextColor3 = Config.Colors.Pink
	timer.TextSize = 12
	timer.Font = Enum.Font.GothamBold
	timer.Parent = panel

	-- Nominee list container
	local nominees = Instance.new("ScrollingFrame")
	nominees.Name = "NomineeList"
	nominees.Size = UDim2.new(0.9, 0, 0.6, 0)
	nominees.Position = UDim2.new(0.05, 0, 0, 70)
	nominees.BackgroundTransparency = 1
	nominees.BorderSizePixel = 0
	nominees.ScrollBarThickness = 4
	nominees.CanvasSize = UDim2.new(0, 0, 0, 0)
	nominees.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = nominees

	-- Status label
	local status = Instance.new("TextLabel")
	status.Name = "VoteStatus"
	status.Size = UDim2.new(0.9, 0, 0, 25)
	status.Position = UDim2.new(0.05, 0, 1, -35)
	status.BackgroundTransparency = 1
	status.Text = ""
	status.TextColor3 = Config.Colors.Green
	status.TextSize = 12
	status.Font = Enum.Font.GothamBold
	status.Parent = panel
end

function MainUI.showVotingScreen(data)
	local sg = playerGui:FindFirstChild("MansionUI")
	if not sg then return end
	local panel = sg.VotingScreen

	panel.VoteTitle.Text = "ELIMINATION VOTE"
	panel.VoteStatus.Text = ""
	panel.Visible = true

	-- Clear existing nominees
	local list = panel.NomineeList
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then child:Destroy() end
	end

	-- Build nominee buttons
	for i, nominee in data.nominees do
		local card = Instance.new("Frame")
		card.Name = "Nominee_" .. i
		card.Size = UDim2.new(1, 0, 0, 50)
		card.BackgroundColor3 = Config.Colors.Card
		card.BorderSizePixel = 0
		card.LayoutOrder = i
		card.Parent = list
		createCorner(card, 8)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.6, 0, 1, 0)
		nameLabel.Position = UDim2.new(0, 12, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = nominee.name
		nameLabel.TextColor3 = Config.Colors.Text
		nameLabel.TextSize = 14
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = card

		local voteBtn = Instance.new("TextButton")
		voteBtn.Name = "VoteBtn"
		voteBtn.Size = UDim2.new(0, 80, 0, 32)
		voteBtn.Position = UDim2.new(1, -90, 0.5, -16)
		voteBtn.BackgroundColor3 = Config.Colors.Red
		voteBtn.Text = "VOTE"
		voteBtn.TextColor3 = Color3.new(1, 1, 1)
		voteBtn.TextSize = 12
		voteBtn.Font = Enum.Font.GothamBold
		voteBtn.Parent = card
		createCorner(voteBtn, 6)

		voteBtn.MouseButton1Click:Connect(function()
			SoundSystem.play("vote_cast")
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			if remotes then
				local castVote = remotes:FindFirstChild("CastVote")
				if castVote then
					castVote:FireServer(nominee.userId)
				end
			end
			-- Visual feedback
			for _, c in list:GetChildren() do
				if c:IsA("Frame") then
					local btn2 = c:FindFirstChild("VoteBtn")
					if btn2 then
						btn2.BackgroundColor3 = Config.Colors.Card
						btn2.Text = "VOTE"
					end
				end
			end
			voteBtn.BackgroundColor3 = Config.Colors.Green
			voteBtn.Text = "VOTED"
			panel.VoteStatus.Text = "Vote cast for " .. nominee.name
		end)
	end

	list.CanvasSize = UDim2.new(0, 0, 0, #data.nominees * 58)

	-- Countdown timer
	if data.duration then
		task.spawn(function()
			local remaining = data.duration
			while remaining > 0 and panel.Visible do
				panel.VoteTimer.Text = remaining .. " seconds remaining"
				task.wait(1)
				remaining -= 1
			end
			panel.VoteTimer.Text = "Voting closed"
		end)
	end
end

function MainUI.showVoteConfirm(data)
	local sg = playerGui:FindFirstChild("MansionUI")
	if not sg then return end
	local panel = sg.VotingScreen
	if panel.Visible then
		panel.VoteStatus.Text = "Vote confirmed: " .. (data.votedFor or "")
		if data.changed then
			panel.VoteStatus.Text = panel.VoteStatus.Text .. " (changed)"
		end
		panel.VoteStatus.TextColor3 = Config.Colors.Green
	end
end

function MainUI.showVoteResults(data)
	local sg = playerGui:FindFirstChild("MansionUI")
	if not sg then return end
	local panel = sg.VotingScreen

	panel.VoteTitle.Text = "VOTE RESULTS"

	local list = panel.NomineeList
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then child:Destroy() end
	end

	if data.results then
		for i, result in data.results do
			local card = Instance.new("Frame")
			card.Name = "Result_" .. i
			card.Size = UDim2.new(1, 0, 0, 40)
			card.BackgroundColor3 = result.userId == (data.eliminated and data.eliminated.userId) and Config.Colors.Red or Config.Colors.Card
			card.BackgroundTransparency = result.userId == (data.eliminated and data.eliminated.userId) and 0.3 or 0
			card.BorderSizePixel = 0
			card.LayoutOrder = i
			card.Parent = list
			createCorner(card, 6)

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(0.7, 0, 1, 0)
			nameLabel.Position = UDim2.new(0, 12, 0, 0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = result.name
			nameLabel.TextColor3 = Config.Colors.Text
			nameLabel.TextSize = 14
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.Parent = card

			local countLabel = Instance.new("TextLabel")
			countLabel.Size = UDim2.new(0.3, -12, 1, 0)
			countLabel.Position = UDim2.new(0.7, 0, 0, 0)
			countLabel.BackgroundTransparency = 1
			countLabel.Text = tostring(result.voteCount) .. " votes"
			countLabel.TextColor3 = Config.Colors.Gold
			countLabel.TextSize = 12
			countLabel.Font = Enum.Font.GothamBold
			countLabel.TextXAlignment = Enum.TextXAlignment.Right
			countLabel.Parent = card
		end
		list.CanvasSize = UDim2.new(0, 0, 0, #data.results * 48)
	end

	if data.eliminated then
		panel.VoteStatus.Text = data.eliminated.name .. " has been ELIMINATED."
		panel.VoteStatus.TextColor3 = Config.Colors.Red
	end

	task.delay(15, function()
		panel.Visible = false
	end)
end

-- ============================================================
-- ELIMINATION OVERLAY (fullscreen dramatic reveal)
-- ============================================================

function MainUI.createEliminationOverlay(parent)
	local overlay = Instance.new("Frame")
	overlay.Name = "EliminationOverlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Config.Colors.Background
	overlay.BackgroundTransparency = 0.2
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.ZIndex = 20
	overlay.Parent = parent

	-- Center text
	local mainText = Instance.new("TextLabel")
	mainText.Name = "MainText"
	mainText.Size = UDim2.new(0.8, 0, 0.15, 0)
	mainText.Position = UDim2.new(0.1, 0, 0.35, 0)
	mainText.BackgroundTransparency = 1
	mainText.Text = ""
	mainText.TextColor3 = Config.Colors.Gold
	mainText.TextSize = 36
	mainText.Font = Enum.Font.GothamBold
	mainText.TextWrapped = true
	mainText.Parent = overlay

	-- Sub text
	local subText = Instance.new("TextLabel")
	subText.Name = "SubText"
	subText.Size = UDim2.new(0.6, 0, 0.08, 0)
	subText.Position = UDim2.new(0.2, 0, 0.52, 0)
	subText.BackgroundTransparency = 1
	subText.Text = ""
	subText.TextColor3 = Config.Colors.Text
	subText.TextSize = 18
	subText.Font = Enum.Font.Gotham
	subText.TextWrapped = true
	subText.Parent = overlay

	-- Countdown number
	local countdownLabel = Instance.new("TextLabel")
	countdownLabel.Name = "Countdown"
	countdownLabel.Size = UDim2.new(0.3, 0, 0.2, 0)
	countdownLabel.Position = UDim2.new(0.35, 0, 0.4, 0)
	countdownLabel.BackgroundTransparency = 1
	countdownLabel.Text = ""
	countdownLabel.TextColor3 = Config.Colors.Red
	countdownLabel.TextSize = 72
	countdownLabel.Font = Enum.Font.GothamBold
	countdownLabel.Visible = false
	countdownLabel.Parent = overlay
end

function MainUI.handleEliminationReveal(data)
	local sg = playerGui:FindFirstChild("MansionUI")
	if not sg then return end
	local overlay = sg.EliminationOverlay

	if data.phase == "gathering" then
		overlay.Visible = true
		overlay.MainText.Text = "ELIMINATION CEREMONY"
		overlay.SubText.Text = data.message or ""
		overlay.Countdown.Visible = false
		-- Switch to tense music
		SoundSystem.playMusic("elimination_tension")
		SoundSystem.play("elimination_drumroll")

	elseif data.phase == "spotlight" then
		overlay.Visible = true
		overlay.MainText.Text = data.nomineeName or ""
		overlay.SubText.Text = "The cameras focus..."
		overlay.Countdown.Visible = false

	elseif data.phase == "countdown" then
		overlay.MainText.Text = "THE PERSON LEAVING IS..."
		overlay.SubText.Text = ""
		overlay.Countdown.Visible = true

	elseif data.phase == "countdown_tick" then
		overlay.Countdown.Text = tostring(data.number)
		-- Scale animation
		overlay.Countdown.TextSize = 72
		TweenService:Create(overlay.Countdown, TweenInfo.new(0.5), {
			TextSize = 48,
		}):Play()

	elseif data.phase == "eliminated" then
		overlay.Countdown.Visible = false
		overlay.MainText.Text = data.name or "Unknown"
		overlay.MainText.TextColor3 = Config.Colors.Red
		overlay.SubText.Text = "ELIMINATED | " .. tostring(data.voteCount or 0) .. " votes"
		SoundSystem.play("elimination_reveal")

		-- Fade out after delay, return to ambient music
		task.delay(8, function()
			overlay.MainText.TextColor3 = Config.Colors.Gold
			overlay.Visible = false
			SoundSystem.playMusic("mansion_ambient")
		end)
	end
end

function MainUI.handleEliminationStart(data)
	MainUI.handleEliminationReveal(data)
end

function MainUI.handleEliminationComplete(data)
	local sg = playerGui:FindFirstChild("MansionUI")
	if not sg then return end

	-- Show brief notification
	MainUI.showDirectorAnnouncement(
		(data.eliminatedName or "Someone") .. " has left the Mansion. " ..
		tostring(data.remainingPlayers or "?") .. " players remain."
	)
end

function MainUI.handleSpectatorMode(data)
	local sg = playerGui:FindFirstChild("MansionUI")
	if not sg then return end

	-- Enter spectator camera system
	SpectatorSystem.enterSpectatorMode()

	-- Hide interactive UI elements (spectators cannot interact)
	local interactiveElements = { "VotingScreen", "AlliancePanel", "CheckInPopup" }
	for _, elemName in interactiveElements do
		local elem = sg:FindFirstChild(elemName)
		if elem then
			elem.Visible = false
		end
	end

	-- Hide interactive nav buttons (vote, alliance, challenge)
	local nav = sg:FindFirstChild("BottomNav")
	if nav then
		local hiddenTabs = { "Tab_Vote", "Tab_Alliance", "Tab_Challenge" }
		for _, tabName in hiddenTabs do
			local tab = nav:FindFirstChild(tabName)
			if tab then
				tab.Visible = false
			end
		end
	end
end

-- ============================================================
-- FIGHT ALERT POPUP
-- ============================================================

function MainUI.createFightAlertPopup(parent)
	local popup = Instance.new("Frame")
	popup.Name = "FightAlert"
	popup.Size = UDim2.new(0.45, 0, 0, 70)
	popup.Position = UDim2.new(0.275, 0, 1.1, 0) -- hidden below
	popup.BackgroundColor3 = Config.Colors.Background
	popup.BackgroundTransparency = 0.1
	popup.BorderSizePixel = 0
	popup.Parent = parent
	popup.ZIndex = 15

	createCorner(popup, 10)
	createStroke(popup, Config.Colors.Red, 2)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "FightTitle"
	titleLabel.Size = UDim2.new(1, -16, 0, 18)
	titleLabel.Position = UDim2.new(0, 8, 0, 6)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "FIGHT ALERT"
	titleLabel.TextColor3 = Config.Colors.Red
	titleLabel.TextSize = 12
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = popup

	local msgLabel = Instance.new("TextLabel")
	msgLabel.Name = "FightMessage"
	msgLabel.Size = UDim2.new(1, -16, 0, 40)
	msgLabel.Position = UDim2.new(0, 8, 0, 26)
	msgLabel.BackgroundTransparency = 1
	msgLabel.Text = ""
	msgLabel.TextColor3 = Config.Colors.Text
	msgLabel.TextSize = 11
	msgLabel.Font = Enum.Font.Gotham
	msgLabel.TextXAlignment = Enum.TextXAlignment.Left
	msgLabel.TextWrapped = true
	msgLabel.Parent = popup
end

function MainUI.showFightAlert(data)
	local sg = playerGui:FindFirstChild("MansionUI")
	if not sg then return end
	local popup = sg.FightAlert

	SoundSystem.play("fight_alert")

	popup.FightTitle.Text = "FIGHT ALERT (Intensity: " .. tostring(data.intensity or "?") .. "/10)"
	popup.FightMessage.Text = (data.aggressor or "?") .. " vs " .. (data.defender or "?") ..
		" in the " .. (data.location or "Mansion") ..
		(data.securityDispatched and " | SECURITY DISPATCHED" or "")

	-- Slide in from bottom
	tweenIn(popup, UDim2.new(0.275, 0, 0.85, 0), 0.4)

	-- Slide out after 6 seconds
	task.delay(6, function()
		tweenOut(popup, UDim2.new(0.275, 0, 1.1, 0), 0.3)
	end)
end

function MainUI.showFightResolved(data)
	MainUI.showDirectorAnnouncement(
		"Fight resolved: " .. (data.winner or "?") .. " wins. Drama: " .. tostring(data.dramaPoints or 0) .. " pts"
	)
end

-- ============================================================
-- ALLIANCE MANAGEMENT PANEL
-- ============================================================

function MainUI.createAlliancePanel(parent)
	local panel = Instance.new("Frame")
	panel.Name = "AlliancePanel"
	panel.Size = UDim2.new(0.45, 0, 0.65, 0)
	panel.Position = UDim2.new(0.275, 0, 0.12, 0)
	panel.BackgroundColor3 = Config.Colors.Background
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = parent

	createCorner(panel, 14)
	createStroke(panel, Config.Colors.Purple, 2)

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "AllianceTitle"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundColor3 = Config.Colors.Purple
	title.BackgroundTransparency = 0.5
	title.BorderSizePixel = 0
	title.Text = "ALLIANCES"
	title.TextColor3 = Config.Colors.Gold
	title.TextSize = 18
	title.Font = Enum.Font.GothamBold
	title.Parent = panel
	createCorner(title, 14)

	-- Alliance info area
	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "AllianceInfo"
	infoLabel.Size = UDim2.new(0.9, 0, 0, 30)
	infoLabel.Position = UDim2.new(0.05, 0, 0, 45)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Text = "No alliance yet. Walk up to a player and propose one!"
	infoLabel.TextColor3 = Config.Colors.TextMuted
	infoLabel.TextSize = 11
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextWrapped = true
	infoLabel.Parent = panel

	-- Member list
	local memberList = Instance.new("ScrollingFrame")
	memberList.Name = "MemberList"
	memberList.Size = UDim2.new(0.9, 0, 0.5, 0)
	memberList.Position = UDim2.new(0.05, 0, 0, 80)
	memberList.BackgroundTransparency = 1
	memberList.BorderSizePixel = 0
	memberList.ScrollBarThickness = 3
	memberList.CanvasSize = UDim2.new(0, 0, 0, 0)
	memberList.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = memberList

	-- Leave alliance button
	local leaveBtn = Instance.new("TextButton")
	leaveBtn.Name = "LeaveAllianceBtn"
	leaveBtn.Size = UDim2.new(0.4, 0, 0, 32)
	leaveBtn.Position = UDim2.new(0.3, 0, 1, -42)
	leaveBtn.BackgroundColor3 = Config.Colors.Red
	leaveBtn.Text = "LEAVE ALLIANCE"
	leaveBtn.TextColor3 = Color3.new(1, 1, 1)
	leaveBtn.TextSize = 11
	leaveBtn.Font = Enum.Font.GothamBold
	leaveBtn.Visible = false
	leaveBtn.Parent = panel
	createCorner(leaveBtn, 6)

	leaveBtn.MouseButton1Click:Connect(function()
		SoundSystem.play("ui_click")
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		if remotes then
			local remote = remotes:FindFirstChild("LeaveAlliance")
			if remote then remote:FireServer() end
		end
	end)

	createCloseButton(panel, function()
		panel.Visible = false
		MainUI._activePanelName = nil
	end)
end

function MainUI.updateAlliancePanel(data)
	local sg = playerGui:FindFirstChild("MansionUI")
	if not sg then return end
	local panel = sg:FindFirstChild("AlliancePanel")
	if not panel then return end

	if data.type == "member_joined" then
		panel.AllianceInfo.Text = data.name .. " joined " .. (data.allianceName or "the alliance") .. "!"
		panel.AllianceInfo.TextColor3 = Config.Colors.Green
	elseif data.type == "member_left" then
		panel.AllianceInfo.Text = data.name .. " left the alliance."
		panel.AllianceInfo.TextColor3 = Config.Colors.Red
	elseif data.type == "betrayal" then
		panel.AllianceInfo.Text = "BETRAYAL: " .. (data.betrayerName or "Someone") .. " voted against " .. (data.targetName or "an ally") .. "!"
		panel.AllianceInfo.TextColor3 = Config.Colors.Red
	elseif data.type == "invite_declined" then
		panel.AllianceInfo.Text = (data.name or "They") .. " declined your alliance invite."
		panel.AllianceInfo.TextColor3 = Config.Colors.TextMuted
	elseif data.type == "accept_result" then
		if data.success then
			panel.AllianceInfo.Text = "Joined alliance: " .. (data.allianceName or "")
			panel.AllianceInfo.TextColor3 = Config.Colors.Green
			panel.LeaveAllianceBtn.Visible = true
		else
			panel.AllianceInfo.Text = "Could not join: " .. (data.reason or "unknown")
			panel.AllianceInfo.TextColor3 = Config.Colors.Red
		end
	elseif data.type == "propose_result" then
		if data.success then
			panel.AllianceInfo.Text = "Alliance invite sent!"
			panel.AllianceInfo.TextColor3 = Config.Colors.Green
			panel.LeaveAllianceBtn.Visible = true
		else
			panel.AllianceInfo.Text = "Cannot propose: " .. (data.reason or "unknown")
			panel.AllianceInfo.TextColor3 = Config.Colors.Red
		end
	end
end

function MainUI.showAllianceInvite(data)
	local sg = playerGui:FindFirstChild("MansionUI")
	if not sg then return end

	-- Create invite popup
	local existing = sg:FindFirstChild("AllianceInvitePopup")
	if existing then existing:Destroy() end

	local popup = Instance.new("Frame")
	popup.Name = "AllianceInvitePopup"
	popup.Size = UDim2.new(0.4, 0, 0.2, 0)
	popup.Position = UDim2.new(0.3, 0, 0.4, 0)
	popup.BackgroundColor3 = Config.Colors.Surface
	popup.BorderSizePixel = 0
	popup.ZIndex = 15
	popup.Parent = sg
	createCorner(popup, 12)
	createStroke(popup, Config.Colors.Purple)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.35, 0)
	title.BackgroundTransparency = 1
	title.Text = (data.fromName or "Someone") .. " wants you to join\n" .. (data.allianceName or "their alliance")
	title.TextColor3 = Config.Colors.Text
	title.TextSize = 13
	title.Font = Enum.Font.GothamBold
	title.TextWrapped = true
	title.Parent = popup

	local acceptBtn = Instance.new("TextButton")
	acceptBtn.Size = UDim2.new(0.4, 0, 0, 30)
	acceptBtn.Position = UDim2.new(0.05, 0, 0.6, 0)
	acceptBtn.BackgroundColor3 = Config.Colors.Green
	acceptBtn.Text = "ACCEPT"
	acceptBtn.TextColor3 = Color3.new(1, 1, 1)
	acceptBtn.TextSize = 12
	acceptBtn.Font = Enum.Font.GothamBold
	acceptBtn.Parent = popup
	createCorner(acceptBtn, 6)

	local declineBtn = Instance.new("TextButton")
	declineBtn.Size = UDim2.new(0.4, 0, 0, 30)
	declineBtn.Position = UDim2.new(0.55, 0, 0.6, 0)
	declineBtn.BackgroundColor3 = Config.Colors.Red
	declineBtn.Text = "DECLINE"
	declineBtn.TextColor3 = Color3.new(1, 1, 1)
	declineBtn.TextSize = 12
	declineBtn.Font = Enum.Font.GothamBold
	declineBtn.Parent = popup
	createCorner(declineBtn, 6)

	acceptBtn.MouseButton1Click:Connect(function()
		SoundSystem.play("alliance_form")
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		if remotes then
			local r = remotes:FindFirstChild("AcceptAlliance")
			if r then r:FireServer() end
		end
		popup:Destroy()
	end)

	declineBtn.MouseButton1Click:Connect(function()
		SoundSystem.play("ui_click")
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		if remotes then
			local r = remotes:FindFirstChild("DeclineAlliance")
			if r then r:FireServer() end
		end
		popup:Destroy()
	end)

	-- Auto-dismiss after timeout
	task.delay(data.timeout or 60, function()
		if popup and popup.Parent then popup:Destroy() end
	end)
end

-- ============================================================
-- CHALLENGE LIST + COMPLETION UI
-- ============================================================

function MainUI.createChallengePanel(parent)
	local panel = Instance.new("Frame")
	panel.Name = "ChallengePanel"
	panel.Size = UDim2.new(0.5, 0, 0.65, 0)
	panel.Position = UDim2.new(0.25, 0, 0.12, 0)
	panel.BackgroundColor3 = Config.Colors.Background
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = parent

	createCorner(panel, 14)
	createStroke(panel, Config.Colors.Green, 2)

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "ChallengeTitle"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundColor3 = Config.Colors.Green
	title.BackgroundTransparency = 0.5
	title.BorderSizePixel = 0
	title.Text = "DAILY CHALLENGES"
	title.TextColor3 = Config.Colors.Gold
	title.TextSize = 18
	title.Font = Enum.Font.GothamBold
	title.Parent = panel
	createCorner(title, 14)

	-- Challenge list
	local challengeList = Instance.new("ScrollingFrame")
	challengeList.Name = "ChallengeList"
	challengeList.Size = UDim2.new(0.9, 0, 0.55, 0)
	challengeList.Position = UDim2.new(0.05, 0, 0, 50)
	challengeList.BackgroundTransparency = 1
	challengeList.BorderSizePixel = 0
	challengeList.ScrollBarThickness = 3
	challengeList.CanvasSize = UDim2.new(0, 0, 0, 0)
	challengeList.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = challengeList

	-- Group goal section
	local goalTitle = Instance.new("TextLabel")
	goalTitle.Name = "GoalTitle"
	goalTitle.Size = UDim2.new(0.9, 0, 0, 25)
	goalTitle.Position = UDim2.new(0.05, 0, 0.6, 5)
	goalTitle.BackgroundTransparency = 1
	goalTitle.Text = "HOUSE GOAL"
	goalTitle.TextColor3 = Config.Colors.Gold
	goalTitle.TextSize = 12
	goalTitle.Font = Enum.Font.GothamBold
	goalTitle.TextXAlignment = Enum.TextXAlignment.Left
	goalTitle.Parent = panel

	local goalDesc = Instance.new("TextLabel")
	goalDesc.Name = "GoalDescription"
	goalDesc.Size = UDim2.new(0.9, 0, 0, 40)
	goalDesc.Position = UDim2.new(0.05, 0, 0.6, 30)
	goalDesc.BackgroundTransparency = 1
	goalDesc.Text = "No group goal active"
	goalDesc.TextColor3 = Config.Colors.TextMuted
	goalDesc.TextSize = 11
	goalDesc.Font = Enum.Font.Gotham
	goalDesc.TextWrapped = true
	goalDesc.TextXAlignment = Enum.TextXAlignment.Left
	goalDesc.Parent = panel

	createCloseButton(panel, function()
		panel.Visible = false
		MainUI._activePanelName = nil
	end)
end

function MainUI.updateChallengeList(data)
	local sg = playerGui:FindFirstChild("MansionUI")
	if not sg then return end
	local panel = sg:FindFirstChild("ChallengePanel")
	if not panel then return end

	local list = panel.ChallengeList
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then child:Destroy() end
	end

	if data.challenges then
		for i, challenge in data.challenges do
			local card = Instance.new("Frame")
			card.Name = "Challenge_" .. i
			card.Size = UDim2.new(1, 0, 0, 65)
			card.BackgroundColor3 = Config.Colors.Card
			card.BorderSizePixel = 0
			card.LayoutOrder = i
			card.Parent = list
			createCorner(card, 8)

			-- Type badge
			local typeColors = { social = Config.Colors.Pink, physical = Config.Colors.Blue, mental = Config.Colors.Purple }
			local badge = Instance.new("Frame")
			badge.Size = UDim2.new(0, 4, 1, -8)
			badge.Position = UDim2.new(0, 4, 0, 4)
			badge.BackgroundColor3 = typeColors[challenge.type] or Config.Colors.TextMuted
			badge.BorderSizePixel = 0
			badge.Parent = card
			createCorner(badge, 2)

			local titleLabel = Instance.new("TextLabel")
			titleLabel.Size = UDim2.new(0.6, 0, 0, 16)
			titleLabel.Position = UDim2.new(0, 16, 0, 4)
			titleLabel.BackgroundTransparency = 1
			titleLabel.Text = challenge.title .. " [" .. string.upper(challenge.type) .. "]"
			titleLabel.TextColor3 = Config.Colors.Text
			titleLabel.TextSize = 11
			titleLabel.Font = Enum.Font.GothamBold
			titleLabel.TextXAlignment = Enum.TextXAlignment.Left
			titleLabel.Parent = card

			local descLabel = Instance.new("TextLabel")
			descLabel.Size = UDim2.new(0.7, 0, 0, 25)
			descLabel.Position = UDim2.new(0, 16, 0, 22)
			descLabel.BackgroundTransparency = 1
			descLabel.Text = challenge.description
			descLabel.TextColor3 = Config.Colors.TextMuted
			descLabel.TextSize = 9
			descLabel.Font = Enum.Font.Gotham
			descLabel.TextWrapped = true
			descLabel.TextXAlignment = Enum.TextXAlignment.Left
			descLabel.Parent = card

			local rewardLabel = Instance.new("TextLabel")
			rewardLabel.Size = UDim2.new(0.3, 0, 0, 14)
			rewardLabel.Position = UDim2.new(0, 16, 0, 48)
			rewardLabel.BackgroundTransparency = 1
			rewardLabel.Text = "+" .. challenge.xpReward .. " XP  +" .. challenge.coinReward .. " coins"
			rewardLabel.TextColor3 = Config.Colors.Gold
			rewardLabel.TextSize = 9
			rewardLabel.Font = Enum.Font.GothamBold
			rewardLabel.TextXAlignment = Enum.TextXAlignment.Left
			rewardLabel.Parent = card

			local acceptBtn = Instance.new("TextButton")
			acceptBtn.Name = "AcceptBtn"
			acceptBtn.Size = UDim2.new(0, 70, 0, 28)
			acceptBtn.Position = UDim2.new(1, -80, 0.5, -14)
			acceptBtn.BackgroundColor3 = Config.Colors.Green
			acceptBtn.Text = "ACCEPT"
			acceptBtn.TextColor3 = Color3.new(1, 1, 1)
			acceptBtn.TextSize = 10
			acceptBtn.Font = Enum.Font.GothamBold
			acceptBtn.Parent = card
			createCorner(acceptBtn, 6)

			acceptBtn.MouseButton1Click:Connect(function()
				SoundSystem.play("ui_click")
				local remotes = ReplicatedStorage:FindFirstChild("Remotes")
				if remotes then
					local r = remotes:FindFirstChild("AcceptChallenge")
					if r then r:FireServer(challenge.id) end
				end
				acceptBtn.Text = "..."
				acceptBtn.BackgroundColor3 = Config.Colors.TextMuted
			end)
		end

		list.CanvasSize = UDim2.new(0, 0, 0, #data.challenges * 71)
	end

	-- Update group goal
	if data.groupGoals and #data.groupGoals > 0 then
		local goal = data.groupGoals[1]
		panel.GoalDescription.Text = goal.title .. ": " .. goal.description ..
			" (+" .. goal.xpReward .. " XP)"
		panel.GoalDescription.TextColor3 = Config.Colors.Text
	end
end

function MainUI.handleChallengeUpdate(data)
	if data.type == "accepted" then
		MainUI.showDirectorAnnouncement("Challenge accepted: " .. (data.title or ""))
	elseif data.type == "completed" then
		SoundSystem.play("challenge_complete")
		MainUI.showDirectorAnnouncement(
			"Challenge COMPLETE: " .. (data.title or "") ..
			" | +" .. tostring(data.xpReward or 0) .. " XP"
		)
	elseif data.type == "progress" then
		-- Update progress in challenge panel (if open)
		local sg = playerGui:FindFirstChild("MansionUI")
		if sg then
			local panel = sg:FindFirstChild("ChallengePanel")
			if panel and panel.Visible then
				-- Could refresh the list, but a simple notification suffices
			end
		end
	elseif data.type == "expired" then
		MainUI.showDirectorAnnouncement("Challenge expired: " .. (data.title or ""))
	end
end

function MainUI.handleGroupGoalUpdate(data)
	if data.type == "completed" then
		MainUI.showDirectorAnnouncement(
			"HOUSE GOAL ACHIEVED: " .. (data.title or "") ..
			" | Everyone gets +" .. tostring(data.xpReward or 0) .. " XP!"
		)
	elseif data.type == "failed" then
		MainUI.showDirectorAnnouncement(
			"HOUSE GOAL FAILED: " .. (data.title or "") ..
			(data.penalty and data.penalty ~= 0 and (" | -" .. math.abs(data.penalty) .. " XP for everyone") or "")
		)
	end
end

-- ============================================================
-- SEASON INFO PANEL
-- ============================================================

function MainUI.createSeasonInfoPanel(parent)
	local panel = Instance.new("Frame")
	panel.Name = "SeasonInfoPanel"
	panel.Size = UDim2.new(0.45, 0, 0.65, 0)
	panel.Position = UDim2.new(0.275, 0, 0.12, 0)
	panel.BackgroundColor3 = Config.Colors.Background
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = parent

	createCorner(panel, 14)
	createStroke(panel, Config.Colors.Gold, 2)

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "SeasonTitle"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundColor3 = Config.Colors.Gold
	title.BackgroundTransparency = 0.5
	title.BorderSizePixel = 0
	title.Text = "SEASON INFO"
	title.TextColor3 = Config.Colors.Background
	title.TextSize = 18
	title.Font = Enum.Font.GothamBold
	title.Parent = panel
	createCorner(title, 14)

	-- Info content
	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.Size = UDim2.new(0.9, 0, 0.85, 0)
	content.Position = UDim2.new(0.05, 0, 0, 45)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 3
	content.CanvasSize = UDim2.new(0, 0, 0, 400)
	content.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = content

	-- Placeholder items
	local items = {
		{ name = "SeasonName", label = "Season:", value = "..." },
		{ name = "WeekNum", label = "Week:", value = "..." },
		{ name = "DayType", label = "Day Type:", value = "..." },
		{ name = "Phase", label = "Current Phase:", value = "..." },
		{ name = "Queen", label = "Queen:", value = "None" },
		{ name = "ActivePlayers", label = "Active Players:", value = "..." },
		{ name = "Eliminated", label = "Eliminated:", value = "..." },
	}

	for i, item in items do
		local row = Instance.new("Frame")
		row.Name = item.name
		row.Size = UDim2.new(1, 0, 0, 28)
		row.BackgroundColor3 = Config.Colors.Card
		row.BorderSizePixel = 0
		row.LayoutOrder = i
		row.Parent = content
		createCorner(row, 4)

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.5, 0, 1, 0)
		lbl.Position = UDim2.new(0, 8, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = item.label
		lbl.TextColor3 = Config.Colors.TextMuted
		lbl.TextSize = 11
		lbl.Font = Enum.Font.Gotham
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = row

		local val = Instance.new("TextLabel")
		val.Name = "Value"
		val.Size = UDim2.new(0.5, -8, 1, 0)
		val.Position = UDim2.new(0.5, 0, 0, 0)
		val.BackgroundTransparency = 1
		val.Text = item.value
		val.TextColor3 = Config.Colors.Gold
		val.TextSize = 11
		val.Font = Enum.Font.GothamBold
		val.TextXAlignment = Enum.TextXAlignment.Right
		val.Parent = row
	end

	-- Invite friends label at the bottom
	local inviteLabel = Instance.new("TextLabel")
	inviteLabel.Name = "InviteLabel"
	inviteLabel.Size = UDim2.new(1, 0, 0, 30)
	inviteLabel.BackgroundTransparency = 1
	inviteLabel.Text = "Invite your friends to the Mansion!"
	inviteLabel.TextColor3 = Config.Colors.Pink
	inviteLabel.TextSize = math.floor(13 * BASE_TEXT_SCALE)
	inviteLabel.Font = Enum.Font.GothamBold
	inviteLabel.LayoutOrder = #items + 1
	inviteLabel.Parent = content

	createCloseButton(panel, function()
		panel.Visible = false
		MainUI._activePanelName = nil
	end)
end

function MainUI.updateSeasonInfo(data)
	local sg = playerGui:FindFirstChild("MansionUI")
	if not sg then return end
	local panel = sg:FindFirstChild("SeasonInfoPanel")
	if not panel then return end
	local content = panel:FindFirstChild("Content")
	if not content then return end

	local function setValue(name, value)
		local row = content:FindFirstChild(name)
		if row then
			local val = row:FindFirstChild("Value")
			if val then val.Text = tostring(value) end
		end
	end

	setValue("SeasonName", data.season and data.season.title or "No Season")
	setValue("WeekNum", data.week and ("Week " .. data.week.week_number) or "N/A")
	setValue("DayType", data.day and string.upper(data.day.day_type or ""):gsub("_", " ") or "N/A")
	setValue("Phase", data.phase and string.upper(data.phase):gsub("_", " ") or "LOBBY")
	setValue("Queen", data.queen and data.queen.name or "None")
	setValue("ActivePlayers", tostring(data.activePlayers or 0))
	setValue("Eliminated", tostring(data.eliminatedPlayers or 0))
end

-- ============================================================
-- LEADERBOARD PANEL
-- ============================================================

function MainUI.createLeaderboardPanel(parent)
	local panel = Instance.new("Frame")
	panel.Name = "LeaderboardPanel"
	panel.Size = UDim2.new(0.4, 0, 0.65, 0)
	panel.Position = UDim2.new(0.3, 0, 0.12, 0)
	panel.BackgroundColor3 = Config.Colors.Background
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = parent

	createCorner(panel, 14)
	createStroke(panel, Config.Colors.Gold, 2)

	-- Title
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundColor3 = Config.Colors.Gold
	title.BackgroundTransparency = 0.5
	title.BorderSizePixel = 0
	title.Text = "LEADERBOARD"
	title.TextColor3 = Config.Colors.Background
	title.TextSize = 18
	title.Font = Enum.Font.GothamBold
	title.Parent = panel
	createCorner(title, 14)

	-- Player list
	local list = Instance.new("ScrollingFrame")
	list.Name = "PlayerList"
	list.Size = UDim2.new(0.9, 0, 0.85, 0)
	list.Position = UDim2.new(0.05, 0, 0, 45)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 3
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = list

	createCloseButton(panel, function()
		panel.Visible = false
		MainUI._activePanelName = nil
	end)
end

function MainUI.updateLeaderboard(data)
	local sg = playerGui:FindFirstChild("MansionUI")
	if not sg then return end
	local panel = sg:FindFirstChild("LeaderboardPanel")
	if not panel then return end

	local list = panel.PlayerList
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then child:Destroy() end
	end

	local leaderboard = data.leaderboard or {}
	for i, entry in leaderboard do
		local row = Instance.new("Frame")
		row.Name = "Rank_" .. i
		row.Size = UDim2.new(1, 0, 0, 32)
		row.BackgroundColor3 = i <= 3 and Config.Colors.Card or Config.Colors.Surface
		row.BorderSizePixel = 0
		row.LayoutOrder = i
		row.Parent = list
		createCorner(row, 4)

		-- Rank colors
		local rankColors = { Config.Colors.Gold, Color3.fromHex("#C0C0C0"), Color3.fromHex("#CD7F32") }
		local rankColor = rankColors[i] or Config.Colors.TextMuted

		local rankLabel = Instance.new("TextLabel")
		rankLabel.Size = UDim2.new(0, 25, 1, 0)
		rankLabel.Position = UDim2.new(0, 4, 0, 0)
		rankLabel.BackgroundTransparency = 1
		rankLabel.Text = "#" .. i
		rankLabel.TextColor3 = rankColor
		rankLabel.TextSize = 11
		rankLabel.Font = Enum.Font.GothamBold
		rankLabel.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.5, 0, 1, 0)
		nameLabel.Position = UDim2.new(0, 32, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = entry.name or entry.display_name or "Unknown"
		nameLabel.TextColor3 = (entry.eliminated) and Config.Colors.TextMuted or Config.Colors.Text
		nameLabel.TextSize = 11
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = row

		local xpLabel = Instance.new("TextLabel")
		xpLabel.Size = UDim2.new(0.25, -8, 1, 0)
		xpLabel.Position = UDim2.new(0.75, 0, 0, 0)
		xpLabel.BackgroundTransparency = 1
		xpLabel.Text = tostring(entry.xp or 0) .. " XP"
		xpLabel.TextColor3 = Config.Colors.Gold
		xpLabel.TextSize = 10
		xpLabel.Font = Enum.Font.GothamBold
		xpLabel.TextXAlignment = Enum.TextXAlignment.Right
		xpLabel.Parent = row
	end

	list.CanvasSize = UDim2.new(0, 0, 0, #leaderboard * 36)
end

-- ============================================================
-- QUEEN CROWN NOTIFICATION
-- ============================================================

function MainUI.showQueenCrowned(data)
	local sg = playerGui:FindFirstChild("MansionUI")
	if not sg then return end

	SoundSystem.play("queen_crowning")
	SoundSystem.playMusic("celebration")

	MainUI.showDirectorAnnouncement(
		"ALL HAIL THE QUEEN: " .. (data.queenName or "???") ..
		" | Week " .. tostring(data.weekNumber or "?")
	)

	-- Return to ambient music after celebration
	task.delay(15, function()
		SoundSystem.playMusic("mansion_ambient")
	end)
end

-- ============================================================
-- EVENT LISTENERS
-- ============================================================

function MainUI.listenForEvents()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")

	-- Season update
	remotes:WaitForChild("SeasonUpdate").OnClientEvent:Connect(function(data)
		if data and data.season then
			local sg = playerGui:FindFirstChild("MansionUI")
			if not sg then return end
			local hud = sg:FindFirstChild("HUD")
			if hud then
				hud.SeasonTitle.Text = data.season.title or "MANSION OF MAYHEM"
				if data.day then
					hud.PhaseLabel.Text = string.upper(data.day.day_type:gsub("_", " "))
				end
			end
		end
	end)

	-- Tea wall
	remotes:WaitForChild("TeaWallUpdate").OnClientEvent:Connect(function(confessions)
		MainUI.updateTeaWall(confessions)
	end)

	-- Director announcements
	remotes:WaitForChild("DirectorAnnounce").OnClientEvent:Connect(function(message)
		MainUI.showDirectorAnnouncement(message)
	end)

	-- Check-in result
	remotes:WaitForChild("CheckInResult").OnClientEvent:Connect(function(result)
		MainUI.showCheckInResult(result)
	end)

	-- Event update
	remotes:WaitForChild("EventUpdate").OnClientEvent:Connect(function(events)
		-- Could show events list UI here
	end)

	-- Phase update
	remotes:WaitForChild("PhaseUpdate").OnClientEvent:Connect(function(data)
		local sg = playerGui:FindFirstChild("MansionUI")
		if not sg then return end
		local hud = sg:FindFirstChild("HUD")
		if hud then
			hud.PhaseLabel.Text = string.upper((data.phase or ""):gsub("_", " "))
		end
	end)

	-- Voting
	remotes:WaitForChild("VoteStart").OnClientEvent:Connect(function(data)
		MainUI.showVotingScreen(data)
	end)

	remotes:WaitForChild("VoteEnd").OnClientEvent:Connect(function(data)
		MainUI.showVoteResults(data)
	end)

	remotes:WaitForChild("VoteConfirm").OnClientEvent:Connect(function(data)
		MainUI.showVoteConfirm(data)
	end)

	-- Nomination
	remotes:WaitForChild("NominationStart").OnClientEvent:Connect(function(data)
		-- Show nomination screen (reuse voting screen with different title)
		data.nominees = {}
		for _, p in data.eligible or {} do
			table.insert(data.nominees, p)
		end

		local sg = playerGui:FindFirstChild("MansionUI")
		if not sg then return end
		local panel = sg.VotingScreen
		panel.VoteTitle.Text = "NOMINATE FOR ELIMINATION"
		panel.VoteStatus.Text = "Select a player to nominate"
		panel.Visible = true

		local list = panel.NomineeList
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then child:Destroy() end
		end

		for i, nominee in data.eligible or {} do
			local card = Instance.new("Frame")
			card.Size = UDim2.new(1, 0, 0, 40)
			card.BackgroundColor3 = Config.Colors.Card
			card.BorderSizePixel = 0
			card.LayoutOrder = i
			card.Parent = list
			createCorner(card, 6)

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(0.6, 0, 1, 0)
			nameLabel.Position = UDim2.new(0, 12, 0, 0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = nominee.name
			nameLabel.TextColor3 = Config.Colors.Text
			nameLabel.TextSize = 12
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.Parent = card

			local nomBtn = Instance.new("TextButton")
			nomBtn.Size = UDim2.new(0, 80, 0, 28)
			nomBtn.Position = UDim2.new(1, -90, 0.5, -14)
			nomBtn.BackgroundColor3 = Config.Colors.Red
			nomBtn.Text = "NOMINATE"
			nomBtn.TextColor3 = Color3.new(1, 1, 1)
			nomBtn.TextSize = 10
			nomBtn.Font = Enum.Font.GothamBold
			nomBtn.Parent = card
			createCorner(nomBtn, 6)

			nomBtn.MouseButton1Click:Connect(function()
				SoundSystem.play("vote_cast")
				local rems = ReplicatedStorage:FindFirstChild("Remotes")
				if rems then
					local r = rems:FindFirstChild("SubmitNomination")
					if r then r:FireServer(nominee.userId) end
				end
				nomBtn.Text = "DONE"
				nomBtn.BackgroundColor3 = Config.Colors.TextMuted
			end)
		end

		list.CanvasSize = UDim2.new(0, 0, 0, #(data.eligible or {}) * 46)

		-- Timer
		if data.duration then
			task.spawn(function()
				local remaining = data.duration
				while remaining > 0 and panel.Visible do
					panel.VoteTimer.Text = remaining .. "s — Nomination phase"
					task.wait(1)
					remaining -= 1
				end
			end)
		end
	end)

	-- Elimination
	remotes:WaitForChild("EliminationStart").OnClientEvent:Connect(function(data)
		MainUI.handleEliminationStart(data)
	end)

	remotes:WaitForChild("EliminationReveal").OnClientEvent:Connect(function(data)
		MainUI.handleEliminationReveal(data)
	end)

	remotes:WaitForChild("EliminationComplete").OnClientEvent:Connect(function(data)
		MainUI.handleEliminationComplete(data)
	end)

	remotes:WaitForChild("SpectatorMode").OnClientEvent:Connect(function(data)
		MainUI.handleSpectatorMode(data)
	end)

	-- Fight
	remotes:WaitForChild("FightAlert").OnClientEvent:Connect(function(data)
		MainUI.showFightAlert(data)
	end)

	remotes:WaitForChild("FightResolved").OnClientEvent:Connect(function(data)
		MainUI.showFightResolved(data)
	end)

	-- Alliance
	remotes:WaitForChild("AllianceInvite").OnClientEvent:Connect(function(data)
		MainUI.showAllianceInvite(data)
	end)

	remotes:WaitForChild("AllianceUpdate").OnClientEvent:Connect(function(data)
		MainUI.updateAlliancePanel(data)
	end)

	-- Queen
	remotes:WaitForChild("QueenCrowned").OnClientEvent:Connect(function(data)
		MainUI.showQueenCrowned(data)
	end)

	-- Challenges
	remotes:WaitForChild("ChallengeList").OnClientEvent:Connect(function(data)
		MainUI.updateChallengeList(data)
	end)

	remotes:WaitForChild("ChallengeUpdate").OnClientEvent:Connect(function(data)
		MainUI.handleChallengeUpdate(data)
	end)

	remotes:WaitForChild("GroupGoalUpdate").OnClientEvent:Connect(function(data)
		MainUI.handleGroupGoalUpdate(data)
	end)

	-- Immunity
	remotes:WaitForChild("ImmunityUpdate").OnClientEvent:Connect(function(data)
		if data.type == "shard_update" or data.type == "full_sync" or data.type == "token_used" or data.type == "token_earned" then
			MainUI.updateImmunityHUD(data.shards, data.tokens)
		end
		if data.type == "token_used" then
			SoundSystem.play("immunity_use")
		end
		if data.message then
			MainUI.showDirectorAnnouncement(data.message)
		end
	end)

	remotes:WaitForChild("ImmunityAnnounce").OnClientEvent:Connect(function(data)
		if data.immune then
			SoundSystem.play("immunity_use")
			MainUI.showDirectorAnnouncement((data.name or "Someone") .. " is IMMUNE this round!")
		end
	end)

	-- Season info response
	remotes:WaitForChild("SeasonInfoResponse").OnClientEvent:Connect(function(data)
		MainUI.updateSeasonInfo(data)
	end)

	-- Leaderboard
	remotes:WaitForChild("LeaderboardUpdate").OnClientEvent:Connect(function(data)
		MainUI.updateLeaderboard(data)
	end)

	-- Particle Effects
	remotes:WaitForChild("PlayEffect").OnClientEvent:Connect(function(data)
		if not MainUI._particleEffects then return end
		local fx = MainUI._particleEffects

		if data.effect == "confetti" then
			fx.confetti(data.position, data.duration)

		elseif data.effect == "smoke" then
			fx.smoke(data.position, data.duration)

		elseif data.effect == "fireSparks" then
			fx.fireSparks(data.position, data.continuous)

		elseif data.effect == "shieldGlow" then
			local targetPlayer = Players:GetPlayerByUserId(data.targetUserId or 0)
			if targetPlayer and targetPlayer.Character then
				fx.shieldGlow(targetPlayer.Character, data.enable)
			end

		elseif data.effect == "spotlightSweep" then
			fx.spotlightSweep(data.position, data.duration)

		elseif data.effect == "crownSparkle" then
			local targetPlayer = Players:GetPlayerByUserId(data.targetUserId or 0)
			if targetPlayer and targetPlayer.Character then
				fx.crownSparkle(targetPlayer.Character, data.enable)
			end
		end
	end)

	-- Cinematic Camera Control
	remotes:WaitForChild("CameraControl").OnClientEvent:Connect(function(data)
		if not MainUI._cinematicCamera then return end
		local cam = MainUI._cinematicCamera

		if data.action == "lockCamera" then
			cam.lockCamera()

		elseif data.action == "unlockCamera" then
			cam.unlockCamera()

		elseif data.action == "panTo" then
			cam.panTo(data.targetPosition, data.duration)

		elseif data.action == "zoomOnPlayer" then
			cam.zoomOnPlayer(data.targetUserId, data.distance, data.duration)

		elseif data.action == "orbitAround" then
			cam.orbitAround(data.center, data.radius, data.duration, data.height)

		elseif data.action == "dramaticReveal" then
			cam.dramaticReveal(data.targetPosition)
		end
	end)

	-- Bus system events
	MainUI._listenBusEvents()
end

-- ============================================================
-- BUS UI — Countdown, Cinematic, Arrival
-- ============================================================

function MainUI.createBusUI(parent)
	-- Bus countdown timer (big text on screen)
	local countdownFrame = Instance.new("Frame")
	countdownFrame.Name = "BusCountdown"
	countdownFrame.Size = UDim2.new(0, 300, 0, 80)
	countdownFrame.Position = UDim2.new(0.5, -150, 0, 20)
	countdownFrame.BackgroundColor3 = Color3.fromHex("#0A0610")
	countdownFrame.BackgroundTransparency = 0.3
	countdownFrame.BorderSizePixel = 0
	countdownFrame.Visible = false
	countdownFrame.ZIndex = 20
	countdownFrame.Parent = parent
	createCorner(countdownFrame, 12)
	createStroke(countdownFrame, Color3.fromHex("#FFD700"), 2)

	local countdownTitle = Instance.new("TextLabel")
	countdownTitle.Name = "Title"
	countdownTitle.Size = UDim2.new(1, 0, 0.4, 0)
	countdownTitle.BackgroundTransparency = 1
	countdownTitle.Text = "BUS DEPARTING IN"
	countdownTitle.TextColor3 = Color3.fromHex("#FFD700")
	countdownTitle.TextSize = math.floor(14 * BASE_TEXT_SCALE)
	countdownTitle.Font = Enum.Font.GothamBold
	countdownTitle.Parent = countdownFrame

	local countdownTime = Instance.new("TextLabel")
	countdownTime.Name = "TimeLabel"
	countdownTime.Size = UDim2.new(1, 0, 0.6, 0)
	countdownTime.Position = UDim2.new(0, 0, 0.4, 0)
	countdownTime.BackgroundTransparency = 1
	countdownTime.Text = "1:00"
	countdownTime.TextColor3 = Color3.new(1, 1, 1)
	countdownTime.TextSize = math.floor(32 * BASE_TEXT_SCALE)
	countdownTime.Font = Enum.Font.GothamBold
	countdownTime.Parent = countdownFrame

	-- Cinematic overlay (letterbox + text)
	local cinematicFrame = Instance.new("Frame")
	cinematicFrame.Name = "BusCinematic"
	cinematicFrame.Size = UDim2.new(1, 0, 1, 0)
	cinematicFrame.BackgroundTransparency = 1
	cinematicFrame.Visible = false
	cinematicFrame.ZIndex = 50
	cinematicFrame.Parent = parent

	-- Top letterbox bar
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0.12, 0)
	topBar.Position = UDim2.new(0, 0, 0, 0)
	topBar.BackgroundColor3 = Color3.new(0, 0, 0)
	topBar.BorderSizePixel = 0
	topBar.ZIndex = 51
	topBar.Parent = cinematicFrame

	-- Bottom letterbox bar
	local bottomBar = Instance.new("Frame")
	bottomBar.Name = "BottomBar"
	bottomBar.Size = UDim2.new(1, 0, 0.12, 0)
	bottomBar.Position = UDim2.new(0, 0, 0.88, 0)
	bottomBar.BackgroundColor3 = Color3.new(0, 0, 0)
	bottomBar.BorderSizePixel = 0
	bottomBar.ZIndex = 51
	bottomBar.Parent = cinematicFrame

	-- Dark background overlay
	local darkOverlay = Instance.new("Frame")
	darkOverlay.Name = "DarkOverlay"
	darkOverlay.Size = UDim2.new(1, 0, 0.76, 0)
	darkOverlay.Position = UDim2.new(0, 0, 0.12, 0)
	darkOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
	darkOverlay.BackgroundTransparency = 0.3
	darkOverlay.BorderSizePixel = 0
	darkOverlay.ZIndex = 50
	darkOverlay.Parent = cinematicFrame

	-- Center text
	local cinematicText = Instance.new("TextLabel")
	cinematicText.Name = "CinematicText"
	cinematicText.Size = UDim2.new(0.8, 0, 0.15, 0)
	cinematicText.Position = UDim2.new(0.1, 0, 0.42, 0)
	cinematicText.BackgroundTransparency = 1
	cinematicText.Text = "EN ROUTE TO THE MANSION..."
	cinematicText.TextColor3 = Color3.fromHex("#FFD700")
	cinematicText.TextSize = math.floor(28 * BASE_TEXT_SCALE)
	cinematicText.Font = Enum.Font.GothamBold
	cinematicText.ZIndex = 52
	cinematicText.Parent = cinematicFrame

	-- Loading dots
	local dotsLabel = Instance.new("TextLabel")
	dotsLabel.Name = "DotsLabel"
	dotsLabel.Size = UDim2.new(0.5, 0, 0.08, 0)
	dotsLabel.Position = UDim2.new(0.25, 0, 0.58, 0)
	dotsLabel.BackgroundTransparency = 1
	dotsLabel.Text = "..."
	dotsLabel.TextColor3 = Color3.fromHex("#E8A0BF")
	dotsLabel.TextSize = math.floor(24 * BASE_TEXT_SCALE)
	dotsLabel.Font = Enum.Font.GothamBold
	dotsLabel.ZIndex = 52
	dotsLabel.Parent = cinematicFrame

	-- Arrival overlay
	local arriveFrame = Instance.new("Frame")
	arriveFrame.Name = "BusArrival"
	arriveFrame.Size = UDim2.new(1, 0, 1, 0)
	arriveFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	arriveFrame.BackgroundTransparency = 0.5
	arriveFrame.Visible = false
	arriveFrame.ZIndex = 50
	arriveFrame.Parent = parent

	local arriveText = Instance.new("TextLabel")
	arriveText.Name = "ArriveText"
	arriveText.Size = UDim2.new(0.8, 0, 0.15, 0)
	arriveText.Position = UDim2.new(0.1, 0, 0.42, 0)
	arriveText.BackgroundTransparency = 1
	arriveText.Text = "WELCOME TO THE MANSION OF MAYHEM"
	arriveText.TextColor3 = Color3.fromHex("#FFD700")
	arriveText.TextSize = math.floor(32 * BASE_TEXT_SCALE)
	arriveText.Font = Enum.Font.GothamBold
	arriveText.ZIndex = 51
	arriveText.Parent = arriveFrame
end

function MainUI._listenBusEvents()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local sg = playerGui:FindFirstChild("MansionUI")
	if not sg then return end

	-- Bus countdown
	local countdownEvent = remotes:FindFirstChild("BusCountdown")
	if countdownEvent then
		countdownEvent.OnClientEvent:Connect(function(data)
			local countdownFrame = sg:FindFirstChild("BusCountdown")
			if not countdownFrame then return end

			if data.timeRemaining and data.timeRemaining > 0 then
				countdownFrame.Visible = true
				local timeLabel = countdownFrame:FindFirstChild("TimeLabel")
				if timeLabel then
					timeLabel.Text = data.timeStr or tostring(data.timeRemaining)
				end
			else
				countdownFrame.Visible = false
			end
		end)
	end

	-- Bus cinematic
	local cinematicEvent = remotes:FindFirstChild("BusCinematic")
	if cinematicEvent then
		cinematicEvent.OnClientEvent:Connect(function(data)
			local cinematicFrame = sg:FindFirstChild("BusCinematic")
			if not cinematicFrame then return end

			if data.action == "start" then
				cinematicFrame.Visible = true
				-- Hide countdown
				local countdownFrame = sg:FindFirstChild("BusCountdown")
				if countdownFrame then countdownFrame.Visible = false end

				-- Update text if provided
				local textLabel = cinematicFrame:FindFirstChild("CinematicText")
				if textLabel and data.text then
					textLabel.Text = data.text
				end

				-- Animate loading dots
				task.spawn(function()
					local dotsLabel = cinematicFrame:FindFirstChild("DotsLabel")
					if dotsLabel then
						local dots = {".", "..", "...", "....", "....."}
						local idx = 1
						while cinematicFrame.Visible do
							dotsLabel.Text = dots[idx]
							idx = (idx % #dots) + 1
							task.wait(0.5)
						end
					end
				end)

			elseif data.action == "stop" then
				cinematicFrame.Visible = false
			end
		end)
	end

	-- Bus arrive
	local arriveEvent = remotes:FindFirstChild("BusArrive")
	if arriveEvent then
		arriveEvent.OnClientEvent:Connect(function(data)
			-- Hide cinematic
			local cinematicFrame = sg:FindFirstChild("BusCinematic")
			if cinematicFrame then cinematicFrame.Visible = false end

			-- Show arrival splash
			local arriveFrame = sg:FindFirstChild("BusArrival")
			if arriveFrame then
				local arriveText = arriveFrame:FindFirstChild("ArriveText")
				if arriveText and data.message then
					arriveText.Text = data.message
				end

				arriveFrame.Visible = true
				arriveFrame.BackgroundTransparency = 0

				-- Fade out after 3 seconds
				task.delay(1, function()
					TweenService:Create(arriveFrame, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						BackgroundTransparency = 1,
					}):Play()
					if arriveText then
						TweenService:Create(arriveText, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							TextTransparency = 1,
						}):Play()
					end
					task.delay(2.5, function()
						arriveFrame.Visible = false
						arriveFrame.BackgroundTransparency = 0.5
						if arriveText then arriveText.TextTransparency = 0 end
					end)
				end)
			end
		end)
	end
end

return MainUI

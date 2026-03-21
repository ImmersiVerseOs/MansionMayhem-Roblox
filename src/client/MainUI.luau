-- ============================================================
-- MAIN UI — Client-side HUD and interactive screens
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MainUI = {}

function MainUI.init()
	-- Create main ScreenGui
	local sg = Instance.new("ScreenGui")
	sg.Name = "MansionUI"
	sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.Parent = playerGui

	-- HUD (top bar)
	MainUI.createHUD(sg)
	-- Bottom nav
	MainUI.createBottomNav(sg)
	-- Tea wall panel (togglable)
	MainUI.createTeaPanel(sg)
	-- Director announcement overlay
	MainUI.createDirectorOverlay(sg)
	-- Check-in popup
	MainUI.createCheckInPopup(sg)

	-- Listen for server events
	MainUI.listenForEvents()

	print("[MainUI] UI initialized")
end

-- ============================================================
-- HUD (Top Bar)
-- ============================================================

function MainUI.createHUD(parent)
	local hud = Instance.new("Frame")
	hud.Name = "HUD"
	hud.Size = UDim2.new(1, 0, 0, 50)
	hud.Position = UDim2.new(0, 0, 0, 0)
	hud.BackgroundColor3 = Color3.fromHex("#0A0610")
	hud.BackgroundTransparency = 0.2
	hud.BorderSizePixel = 0
	hud.Parent = parent

	-- Season title
	local title = Instance.new("TextLabel")
	title.Name = "SeasonTitle"
	title.Size = UDim2.new(0.5, 0, 1, 0)
	title.Position = UDim2.new(0, 12, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "MANSION OF MAYHEM"
	title.TextColor3 = Color3.fromHex("#FFD700")
	title.TextSize = 16
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = hud

	-- Phase indicator
	local phase = Instance.new("TextLabel")
	phase.Name = "PhaseLabel"
	phase.Size = UDim2.new(0.3, 0, 1, 0)
	phase.Position = UDim2.new(0.7, -12, 0, 0)
	phase.BackgroundTransparency = 1
	phase.Text = "MOVE IN"
	phase.TextColor3 = Color3.fromHex("#FF1493")
	phase.TextSize = 12
	phase.Font = Enum.Font.GothamBold
	phase.TextXAlignment = Enum.TextXAlignment.Right
	phase.Parent = hud

	-- Bottom border neon
	local border = Instance.new("Frame")
	border.Size = UDim2.new(1, 0, 0, 2)
	border.Position = UDim2.new(0, 0, 1, -2)
	border.BackgroundColor3 = Color3.fromHex("#FF1493")
	border.BorderSizePixel = 0
	border.Parent = hud
end

-- ============================================================
-- BOTTOM NAV
-- ============================================================

function MainUI.createBottomNav(parent)
	local nav = Instance.new("Frame")
	nav.Name = "BottomNav"
	nav.Size = UDim2.new(1, 0, 0, 60)
	nav.Position = UDim2.new(0, 0, 1, -60)
	nav.BackgroundColor3 = Color3.fromHex("#130D1A")
	nav.BackgroundTransparency = 0.1
	nav.BorderSizePixel = 0
	nav.Parent = parent

	local topBorder = Instance.new("Frame")
	topBorder.Size = UDim2.new(1, 0, 0, 1)
	topBorder.BackgroundColor3 = Color3.fromHex("#2D1B4E")
	topBorder.BorderSizePixel = 0
	topBorder.Parent = nav

	local tabs = {
		{ icon = "rbxassetid://0", text = "Home",   emoji = "🏠" },
		{ icon = "rbxassetid://0", text = "Tea",    emoji = "☕" },
		{ icon = "rbxassetid://0", text = "Check In",emoji = "🔥" },
		{ icon = "rbxassetid://0", text = "Vote",   emoji = "🗳️" },
		{ icon = "rbxassetid://0", text = "Season", emoji = "👑" },
	}

	for i, tab in tabs do
		local btn = Instance.new("TextButton")
		btn.Name = "Tab_" .. tab.text
		btn.Size = UDim2.new(1/#tabs, 0, 1, -5)
		btn.Position = UDim2.new((i-1)/#tabs, 0, 0, 5)
		btn.BackgroundTransparency = 1
		btn.Text = tab.emoji .. "\n" .. tab.text
		btn.TextColor3 = Color3.fromHex("#808080")
		btn.TextSize = 10
		btn.Font = Enum.Font.GothamBold
		btn.Parent = nav

		btn.MouseButton1Click:Connect(function()
			MainUI.onTabClick(tab.text)
			-- Highlight active tab
			for _, child in nav:GetChildren() do
				if child:IsA("TextButton") then
					child.TextColor3 = Color3.fromHex("#808080")
				end
			end
			btn.TextColor3 = Color3.fromHex("#FF1493")
		end)
	end
end

function MainUI.onTabClick(tabName)
	if tabName == "Tea" then
		MainUI.toggleTeaPanel()
	elseif tabName == "Check In" then
		MainUI.showCheckIn()
	elseif tabName == "Season" then
		-- Show season info
	elseif tabName == "Vote" then
		-- Show voting
	end
end

-- ============================================================
-- TEA WALL PANEL
-- ============================================================

function MainUI.createTeaPanel(parent)
	local panel = Instance.new("ScrollingFrame")
	panel.Name = "TeaPanel"
	panel.Size = UDim2.new(0.35, 0, 0.7, 0)
	panel.Position = UDim2.new(1, 0, 0.05, 0) -- hidden off-screen
	panel.BackgroundColor3 = Color3.fromHex("#130D1A")
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.ScrollBarThickness = 4
	panel.CanvasSize = UDim2.new(0, 0, 0, 0)
	panel.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local border = Instance.new("UIStroke")
	border.Color = Color3.fromHex("#2D1B4E")
	border.Thickness = 1
	border.Parent = panel

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 35)
	title.BackgroundColor3 = Color3.fromHex("#1A0E22")
	title.BorderSizePixel = 0
	title.Text = "☕ TEA ROOM"
	title.TextColor3 = Color3.fromHex("#FFD700")
	title.TextSize = 14
	title.Font = Enum.Font.GothamBold
	title.Parent = panel

	-- Layout
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = panel
end

MainUI._teaOpen = false

function MainUI.toggleTeaPanel()
	local panel = playerGui.MansionUI.TeaPanel
	MainUI._teaOpen = not MainUI._teaOpen

	local target = MainUI._teaOpen
		and UDim2.new(0.64, 0, 0.05, 0)
		or UDim2.new(1, 0, 0.05, 0)

	TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Position = target
	}):Play()
end

function MainUI.updateTeaWall(confessions)
	local panel = playerGui.MansionUI.TeaPanel
	-- Clear existing posts (keep title and layout)
	for _, child in panel:GetChildren() do
		if child:IsA("Frame") then child:Destroy() end
	end

	local order = 1
	for _, c in confessions do
		local card = Instance.new("Frame")
		card.Name = "Confession_" .. order
		card.Size = UDim2.new(1, -8, 0, 60)
		card.BackgroundColor3 = Color3.fromHex("#1A0E22")
		card.BorderSizePixel = 0
		card.LayoutOrder = order
		card.Parent = panel

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 6)
		cardCorner.Parent = card

		local author = Instance.new("TextLabel")
		author.Size = UDim2.new(1, -8, 0, 14)
		author.Position = UDim2.new(0, 4, 0, 4)
		author.BackgroundTransparency = 1
		author.Text = c.cast_members and c.cast_members.display_name or "Anonymous"
		author.TextColor3 = Color3.fromHex("#FF1493")
		author.TextSize = 11
		author.Font = Enum.Font.GothamBold
		author.TextXAlignment = Enum.TextXAlignment.Left
		author.Parent = card

		local text = Instance.new("TextLabel")
		text.Size = UDim2.new(1, -8, 1, -22)
		text.Position = UDim2.new(0, 4, 0, 20)
		text.BackgroundTransparency = 1
		text.Text = c.confession_text or ""
		text.TextColor3 = Color3.fromHex("#F8F4F0")
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
	overlay.Position = UDim2.new(0.2, 0, -0.15, 0) -- hidden above
	overlay.BackgroundColor3 = Color3.fromHex("#0A0610")
	overlay.BackgroundTransparency = 0.1
	overlay.BorderSizePixel = 0
	overlay.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = overlay

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex("#FFD700")
	stroke.Thickness = 1
	stroke.Parent = overlay

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(0, 40, 1, 0)
	icon.BackgroundTransparency = 1
	icon.Text = "👁️"
	icon.TextSize = 24
	icon.Parent = overlay

	local label = Instance.new("TextLabel")
	label.Name = "DirectorLabel"
	label.Size = UDim2.new(0, 100, 0, 16)
	label.Position = UDim2.new(0, 40, 0, 8)
	label.BackgroundTransparency = 1
	label.Text = "THE DIRECTOR"
	label.TextColor3 = Color3.fromHex("#FFD700")
	label.TextSize = 10
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = overlay

	local msg = Instance.new("TextLabel")
	msg.Name = "DirectorText"
	msg.Size = UDim2.new(1, -50, 1, -26)
	msg.Position = UDim2.new(0, 40, 0, 26)
	msg.BackgroundTransparency = 1
	msg.Text = ""
	msg.TextColor3 = Color3.fromHex("#F8F4F0")
	msg.TextSize = 13
	msg.Font = Enum.Font.Gotham
	msg.TextXAlignment = Enum.TextXAlignment.Left
	msg.TextWrapped = true
	msg.Parent = overlay
end

function MainUI.showDirectorAnnouncement(message)
	local overlay = playerGui.MansionUI.DirectorOverlay
	overlay.DirectorText.Text = message

	-- Slide in from top
	TweenService:Create(overlay, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.2, 0, 0.02, 0)
	}):Play()

	-- Slide out after 6 seconds
	task.delay(6, function()
		TweenService:Create(overlay, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
			Position = UDim2.new(0.2, 0, -0.15, 0)
		}):Play()
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
	popup.BackgroundColor3 = Color3.fromHex("#130D1A")
	popup.BorderSizePixel = 0
	popup.Visible = false
	popup.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = popup

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex("#FFD700")
	stroke.Thickness = 1
	stroke.Parent = popup

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(1, 0, 0.3, 0)
	icon.BackgroundTransparency = 1
	icon.Text = "🔥"
	icon.TextSize = 36
	icon.Parent = popup

	local title = Instance.new("TextLabel")
	title.Name = "CheckInTitle"
	title.Size = UDim2.new(1, 0, 0.2, 0)
	title.Position = UDim2.new(0, 0, 0.3, 0)
	title.BackgroundTransparency = 1
	title.Text = "Daily Check-In"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextSize = 18
	title.Font = Enum.Font.GothamBold
	title.Parent = popup

	local btn = Instance.new("TextButton")
	btn.Name = "CheckInBtn"
	btn.Size = UDim2.new(0.6, 0, 0.2, 0)
	btn.Position = UDim2.new(0.2, 0, 0.65, 0)
	btn.BackgroundColor3 = Color3.fromHex("#FF1493")
	btn.Text = "CHECK IN NOW"
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.TextSize = 14
	btn.Font = Enum.Font.GothamBold
	btn.Parent = popup

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = btn

	btn.MouseButton1Click:Connect(function()
		local remote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("RequestCheckIn")
		if remote then remote:FireServer() end
		btn.Text = "..."
	end)
end

function MainUI.showCheckIn()
	local popup = playerGui.MansionUI.CheckInPopup
	popup.Visible = true
end

function MainUI.showCheckInResult(result)
	local popup = playerGui.MansionUI.CheckInPopup
	if result.already_checked_in then
		popup.CheckInTitle.Text = "Already checked in today!"
		popup.CheckInBtn.Text = "✅ DONE"
	else
		popup.CheckInTitle.Text = "+" .. (result.xp_earned or 10) .. " XP | " .. (result.streak or 1) .. " day streak"
		popup.CheckInBtn.Text = "✅ CHECKED IN"
		if result.immunity_shard_awarded then
			popup.CheckInTitle.Text = popup.CheckInTitle.Text .. "\n🛡️ IMMUNITY SHARD!"
		end
	end
	task.delay(3, function() popup.Visible = false end)
end

-- ============================================================
-- EVENT LISTENERS
-- ============================================================

function MainUI.listenForEvents()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")

	remotes:WaitForChild("SeasonUpdate").OnClientEvent:Connect(function(data)
		if data and data.season then
			local hud = playerGui.MansionUI.HUD
			hud.SeasonTitle.Text = data.season.title or "MANSION OF MAYHEM"
			if data.day then
				hud.PhaseLabel.Text = string.upper(data.day.day_type:gsub("_", " "))
			end
		end
	end)

	remotes:WaitForChild("TeaWallUpdate").OnClientEvent:Connect(function(confessions)
		MainUI.updateTeaWall(confessions)
	end)

	remotes:WaitForChild("DirectorAnnounce").OnClientEvent:Connect(function(message)
		MainUI.showDirectorAnnouncement(message)
	end)

	remotes:WaitForChild("CheckInResult").OnClientEvent:Connect(function(result)
		MainUI.showCheckInResult(result)
	end)

	remotes:WaitForChild("EventUpdate").OnClientEvent:Connect(function(events)
		-- TODO: Show events list UI
	end)
end

return MainUI

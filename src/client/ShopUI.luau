-- ============================================================
-- SHOP UI — In-game shop for Game Passes and Dev Products
-- Gold/premium themed UI matching mansion aesthetic
-- ============================================================

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ShopUI = {}

-- ============================================================
-- ITEM DEFINITIONS (mirrors server MonetizationSystem)
-- IDs are placeholders — will match server IDs
-- ============================================================

local GAME_PASSES = {
	{
		name = "VIP",
		displayName = "VIP Pass",
		description = "Gold name tag, VIP lounge access, exclusive outfit colors",
		id = 0,
		price = "499",
		icon = "VIP",
		color = Config.Colors.Gold,
	},
	{
		name = "DoubleXP",
		displayName = "Double XP",
		description = "2x XP from all activities — level up faster",
		id = 0,
		price = "299",
		icon = "2X",
		color = Config.Colors.Purple,
	},
	{
		name = "ExtraVote",
		displayName = "Extra Vote",
		description = "Cast 2 votes during elimination instead of 1",
		id = 0,
		price = "399",
		icon = "2V",
		color = Config.Colors.Red,
	},
	{
		name = "CustomRoom",
		displayName = "Custom Room",
		description = "Decorate your bedroom with exclusive items",
		id = 0,
		price = "199",
		icon = "ROOM",
		color = Config.Colors.Blue,
	},
}

local DEV_PRODUCTS = {
	{
		name = "ImmunityToken",
		displayName = "Immunity Token",
		description = "Buy 1 immunity token to survive elimination",
		id = 0,
		price = "149",
		icon = "SHIELD",
		color = Config.Colors.Green,
	},
	{
		name = "Coins50",
		displayName = "50 Coins",
		description = "In-game currency for the Mansion",
		id = 0,
		price = "49",
		icon = "COIN",
		color = Config.Colors.Gold,
	},
	{
		name = "RoomUpgrade",
		displayName = "Room Upgrade",
		description = "Upgrade your bedroom temporarily",
		id = 0,
		price = "99",
		icon = "UP",
		color = Config.Colors.Pink,
	},
	{
		name = "ConfettiBomb",
		displayName = "Confetti Bomb",
		description = "Throw confetti on yourself (flex)",
		id = 0,
		price = "29",
		icon = "PARTY",
		color = Config.Colors.Purple,
	},
}

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

-- ============================================================
-- CREATE SHOP PANEL
-- ============================================================

function ShopUI.createShopPanel(parent)
	local panel = Instance.new("Frame")
	panel.Name = "ShopPanel"
	panel.Size = UDim2.new(0.55, 0, 0.75, 0)
	panel.Position = UDim2.new(0.225, 0, 0.08, 0)
	panel.BackgroundColor3 = Config.Colors.Background
	panel.BackgroundTransparency = 0.03
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 10
	panel.Parent = parent

	createCorner(panel, 16)
	createStroke(panel, Config.Colors.Gold, 2)

	-- Title bar
	local titleBar = Instance.new("Frame")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, 50)
	titleBar.BackgroundColor3 = Config.Colors.Gold
	titleBar.BackgroundTransparency = 0.3
	titleBar.BorderSizePixel = 0
	titleBar.Parent = panel
	createCorner(titleBar, 16)

	-- Cover bottom corners of title bar
	local titleBarCover = Instance.new("Frame")
	titleBarCover.Size = UDim2.new(1, 0, 0, 16)
	titleBarCover.Position = UDim2.new(0, 0, 1, -16)
	titleBarCover.BackgroundColor3 = Config.Colors.Gold
	titleBarCover.BackgroundTransparency = 0.3
	titleBarCover.BorderSizePixel = 0
	titleBarCover.Parent = titleBar

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(0.8, 0, 1, 0)
	titleLabel.Position = UDim2.new(0, 16, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "MANSION SHOP"
	titleLabel.TextColor3 = Config.Colors.Background
	titleLabel.TextSize = 22
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = titleBar

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -44, 0, 7)
	closeBtn.BackgroundColor3 = Config.Colors.Background
	closeBtn.BackgroundTransparency = 0.5
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Config.Colors.Gold
	closeBtn.TextSize = 16
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = titleBar
	createCorner(closeBtn, 8)

	closeBtn.MouseButton1Click:Connect(function()
		panel.Visible = false
	end)

	-- Scrolling content area
	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.Size = UDim2.new(0.94, 0, 1, -60)
	content.Position = UDim2.new(0.03, 0, 0, 55)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 4
	content.ScrollBarImageColor3 = Config.Colors.Gold
	content.CanvasSize = UDim2.new(0, 0, 0, 0)
	content.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = content

	-- Section: Game Passes
	ShopUI._createSectionHeader(content, "GAME PASSES (One-Time)", 0, Config.Colors.Gold)

	for i, pass in GAME_PASSES do
		ShopUI._createShopItem(content, pass, "gamepass", i)
	end

	-- Divider
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Size = UDim2.new(0.9, 0, 0, 2)
	divider.BackgroundColor3 = Config.Colors.Border
	divider.BorderSizePixel = 0
	divider.LayoutOrder = #GAME_PASSES + 2
	divider.Parent = content
	createCorner(divider, 1)

	-- Section: Dev Products
	ShopUI._createSectionHeader(content, "ITEMS (Repeatable)", #GAME_PASSES + 3, Config.Colors.Pink)

	for i, product in DEV_PRODUCTS do
		ShopUI._createShopItem(content, product, "devproduct", #GAME_PASSES + 4 + i)
	end

	-- Update canvas size
	local totalItems = #GAME_PASSES + #DEV_PRODUCTS + 4 -- headers + divider + padding
	content.CanvasSize = UDim2.new(0, 0, 0, totalItems * 95 + 60)

	return panel
end

-- ============================================================
-- SECTION HEADER
-- ============================================================

function ShopUI._createSectionHeader(parent, text, order, color)
	local header = Instance.new("Frame")
	header.Name = "Header_" .. text
	header.Size = UDim2.new(1, 0, 0, 30)
	header.BackgroundTransparency = 1
	header.BorderSizePixel = 0
	header.LayoutOrder = order
	header.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Position = UDim2.new(0, 4, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Config.Colors.Gold
	label.TextSize = 13
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = header

	-- Accent line
	local line = Instance.new("Frame")
	line.Size = UDim2.new(1, 0, 0, 1)
	line.Position = UDim2.new(0, 0, 1, -1)
	line.BackgroundColor3 = color or Config.Colors.Gold
	line.BackgroundTransparency = 0.5
	line.BorderSizePixel = 0
	line.Parent = header
end

-- ============================================================
-- SHOP ITEM CARD
-- ============================================================

function ShopUI._createShopItem(parent, itemData, itemType, order)
	local card = Instance.new("Frame")
	card.Name = "Item_" .. itemData.name
	card.Size = UDim2.new(1, 0, 0, 80)
	card.BackgroundColor3 = Config.Colors.Card
	card.BorderSizePixel = 0
	card.LayoutOrder = order
	card.Parent = parent
	createCorner(card, 10)

	-- Left accent bar
	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0, 4, 0.8, 0)
	accent.Position = UDim2.new(0, 6, 0.1, 0)
	accent.BackgroundColor3 = itemData.color or Config.Colors.Gold
	accent.BorderSizePixel = 0
	accent.Parent = card
	createCorner(accent, 2)

	-- Icon badge
	local iconFrame = Instance.new("Frame")
	iconFrame.Size = UDim2.new(0, 44, 0, 44)
	iconFrame.Position = UDim2.new(0, 18, 0.5, -22)
	iconFrame.BackgroundColor3 = itemData.color or Config.Colors.Gold
	iconFrame.BackgroundTransparency = 0.2
	iconFrame.BorderSizePixel = 0
	iconFrame.Parent = card
	createCorner(iconFrame, 8)

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.new(1, 0, 1, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = itemData.icon or "?"
	iconLabel.TextColor3 = Config.Colors.Background
	iconLabel.TextSize = 11
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.Parent = iconFrame

	-- Item name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.5, 0, 0, 20)
	nameLabel.Position = UDim2.new(0, 72, 0, 10)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = itemData.displayName
	nameLabel.TextColor3 = Config.Colors.Text
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = card

	-- Description
	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(0.55, 0, 0, 32)
	descLabel.Position = UDim2.new(0, 72, 0, 32)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = itemData.description
	descLabel.TextColor3 = Config.Colors.TextMuted
	descLabel.TextSize = 10
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextWrapped = true
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.Parent = card

	-- Buy button
	local buyBtn = Instance.new("TextButton")
	buyBtn.Name = "BuyBtn"
	buyBtn.Size = UDim2.new(0, 90, 0, 36)
	buyBtn.Position = UDim2.new(1, -100, 0.5, -18)
	buyBtn.BackgroundColor3 = Config.Colors.Gold
	buyBtn.Text = "R$ " .. itemData.price
	buyBtn.TextColor3 = Config.Colors.Background
	buyBtn.TextSize = 13
	buyBtn.Font = Enum.Font.GothamBold
	buyBtn.Parent = card
	createCorner(buyBtn, 8)

	-- Hover effect
	buyBtn.MouseEnter:Connect(function()
		TweenService:Create(buyBtn, TweenInfo.new(0.15), {
			BackgroundColor3 = Color3.fromHex("#FFE44D"),
		}):Play()
	end)
	buyBtn.MouseLeave:Connect(function()
		TweenService:Create(buyBtn, TweenInfo.new(0.15), {
			BackgroundColor3 = Config.Colors.Gold,
		}):Play()
	end)

	-- Purchase handler
	buyBtn.MouseButton1Click:Connect(function()
		if itemType == "gamepass" and itemData.id ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, itemData.id)
		elseif itemType == "devproduct" and itemData.id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, itemData.id)
		else
			-- Placeholder — show message
			buyBtn.Text = "COMING SOON"
			buyBtn.BackgroundColor3 = Config.Colors.TextMuted
			task.delay(2, function()
				buyBtn.Text = "R$ " .. itemData.price
				buyBtn.BackgroundColor3 = Config.Colors.Gold
			end)
		end
	end)

	-- If game pass, check ownership and show "OWNED" status
	if itemType == "gamepass" and itemData.id ~= 0 then
		task.spawn(function()
			local success, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, itemData.id)
			end)
			if success and owns then
				buyBtn.Text = "OWNED"
				buyBtn.BackgroundColor3 = Config.Colors.Green
			end
		end)
	end
end

return ShopUI

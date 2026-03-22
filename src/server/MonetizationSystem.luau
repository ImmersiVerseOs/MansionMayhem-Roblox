-- ============================================================
-- MONETIZATION SYSTEM — Game Passes + Dev Products for Mansion Mayhem
-- Handles purchases, perks, and receipt processing
-- ============================================================

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MonetizationSystem = {}

-- ============================================================
-- GAME PASS DEFINITIONS (one-time purchases)
-- Replace 0 with actual Roblox Game Pass IDs after creation
-- ============================================================

MonetizationSystem.GAME_PASSES = {
	VIP = {
		id = 0,
		name = "VIP Pass",
		description = "Gold name tag, VIP lounge access, exclusive outfit colors",
		price = 499,
	},
	DoubleXP = {
		id = 0,
		name = "Double XP",
		description = "2x XP from all activities",
		price = 299,
	},
	ExtraVote = {
		id = 0,
		name = "Extra Vote",
		description = "Cast 2 votes during elimination instead of 1",
		price = 399,
	},
	CustomRoom = {
		id = 0,
		name = "Custom Room",
		description = "Decorate your bedroom with exclusive items",
		price = 199,
	},
}

-- ============================================================
-- DEV PRODUCT DEFINITIONS (repeatable purchases)
-- Replace 0 with actual Roblox Developer Product IDs after creation
-- ============================================================

MonetizationSystem.DEV_PRODUCTS = {
	ImmunityToken = {
		id = 0,
		name = "Immunity Token",
		description = "Buy 1 immunity token to survive elimination",
		price = 149,
	},
	Coins50 = {
		id = 0,
		name = "50 Coins",
		description = "In-game currency for the Mansion",
		price = 49,
	},
	RoomUpgrade = {
		id = 0,
		name = "Room Upgrade",
		description = "Upgrade your bedroom temporarily",
		price = 99,
	},
	ConfettiBomb = {
		id = 0,
		name = "Confetti Bomb",
		description = "Throw confetti on yourself (flex)",
		price = 29,
	},
}

-- State
MonetizationSystem._gamePassCache = {} -- { [userId] = { [passName] = true/false } }
MonetizationSystem._pendingReceipts = {} -- track processed receipts

-- ============================================================
-- INITIALIZATION
-- ============================================================

function MonetizationSystem.init()
	print("[MonetizationSystem] Initializing monetization...")

	-- Set up ProcessReceipt callback for dev products
	MarketplaceService.ProcessReceipt = MonetizationSystem.processReceipt

	-- Listen for game pass purchase completion to update cache
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
		if wasPurchased then
			MonetizationSystem._onGamePassPurchased(player, gamePassId)
		end
	end)

	-- Pre-cache game passes for existing players
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			MonetizationSystem._cacheGamePasses(player)
		end)
	end

	-- Cache game passes for new players
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			MonetizationSystem._cacheGamePasses(player)
		end)
	end)

	-- Clean up on leave
	Players.PlayerRemoving:Connect(function(player)
		MonetizationSystem._gamePassCache[player.UserId] = nil
	end)

	print("[MonetizationSystem] Monetization ready!")
end

-- ============================================================
-- GAME PASS FUNCTIONS
-- ============================================================

function MonetizationSystem._cacheGamePasses(player)
	MonetizationSystem._gamePassCache[player.UserId] = {}

	for passName, passData in MonetizationSystem.GAME_PASSES do
		if passData.id ~= 0 then
			local success, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passData.id)
			end)
			if success then
				MonetizationSystem._gamePassCache[player.UserId][passName] = owns
				if owns then
					print("[MonetizationSystem]", player.Name, "owns game pass:", passName)
				end
			else
				MonetizationSystem._gamePassCache[player.UserId][passName] = false
			end
		else
			MonetizationSystem._gamePassCache[player.UserId][passName] = false
		end
	end
end

function MonetizationSystem._onGamePassPurchased(player, gamePassId)
	if not player then return end

	for passName, passData in MonetizationSystem.GAME_PASSES do
		if passData.id == gamePassId then
			if not MonetizationSystem._gamePassCache[player.UserId] then
				MonetizationSystem._gamePassCache[player.UserId] = {}
			end
			MonetizationSystem._gamePassCache[player.UserId][passName] = true
			print("[MonetizationSystem]", player.Name, "purchased game pass:", passName)

			-- Apply immediate perks
			if passName == "VIP" then
				MonetizationSystem._applyVIPTag(player)
			end

			break
		end
	end
end

function MonetizationSystem.hasGamePass(player, passName)
	if not player then return false end
	local cache = MonetizationSystem._gamePassCache[player.UserId]
	if cache then
		return cache[passName] == true
	end
	return false
end

function MonetizationSystem.promptPurchase(player, passName)
	if not player then return end

	-- Check game passes first
	local passData = MonetizationSystem.GAME_PASSES[passName]
	if passData then
		if passData.id ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, passData.id)
		else
			warn("[MonetizationSystem] Game pass ID is 0 (placeholder) for:", passName)
		end
		return
	end

	-- Check dev products
	local productData = MonetizationSystem.DEV_PRODUCTS[passName]
	if productData then
		if productData.id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, productData.id)
		else
			warn("[MonetizationSystem] Dev product ID is 0 (placeholder) for:", passName)
		end
		return
	end

	warn("[MonetizationSystem] Unknown purchase name:", passName)
end

-- ============================================================
-- DEV PRODUCT RECEIPT PROCESSING
-- ============================================================

function MonetizationSystem.processReceipt(receiptInfo)
	local playerId = receiptInfo.PlayerId
	local productId = receiptInfo.ProductId
	local purchaseId = receiptInfo.PurchaseId

	-- Prevent duplicate processing
	if MonetizationSystem._pendingReceipts[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	MonetizationSystem._pendingReceipts[purchaseId] = true

	local player = Players:GetPlayerByUserId(playerId)
	if not player then
		MonetizationSystem._pendingReceipts[purchaseId] = nil
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Find which product was purchased
	local productName = nil
	for name, data in MonetizationSystem.DEV_PRODUCTS do
		if data.id == productId then
			productName = name
			break
		end
	end

	if not productName then
		warn("[MonetizationSystem] Unknown product ID:", productId)
		MonetizationSystem._pendingReceipts[purchaseId] = nil
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	print("[MonetizationSystem] Processing dev product:", productName, "for", player.Name)

	local success = pcall(function()
		MonetizationSystem._grantDevProduct(player, productName)
	end)

	if success then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		MonetizationSystem._pendingReceipts[purchaseId] = nil
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

function MonetizationSystem._grantDevProduct(player, productName)
	-- Get GameManager reference for player data
	local gameManager = nil
	local ok, gm = pcall(function()
		return require(script.Parent.GameManager)
	end)
	if ok then gameManager = gm end

	if productName == "ImmunityToken" then
		-- Grant 1 immunity token
		if gameManager and gameManager.immunitySystem then
			gameManager.immunitySystem.awardToken(player.UserId, 1, "purchase", gameManager)
		end
		print("[MonetizationSystem]", player.Name, "received 1 Immunity Token")

	elseif productName == "Coins50" then
		-- Add 50 coins
		if gameManager then
			local playerData = gameManager.playerMap[player.UserId]
			if playerData then
				playerData.coins = (playerData.coins or 0) + 50
			end
		end
		print("[MonetizationSystem]", player.Name, "received 50 coins")

	elseif productName == "RoomUpgrade" then
		-- Room upgrade — flag for this session
		if gameManager then
			local playerData = gameManager.playerMap[player.UserId]
			if playerData then
				playerData.roomUpgraded = true
			end
		end
		print("[MonetizationSystem]", player.Name, "upgraded their room")

	elseif productName == "ConfettiBomb" then
		-- Fire confetti effect for the player
		MonetizationSystem._fireConfetti(player)
		print("[MonetizationSystem]", player.Name, "threw a confetti bomb!")
	end
end

-- ============================================================
-- VIP FEATURES
-- ============================================================

function MonetizationSystem.getVIPPlayers()
	local vips = {}
	for userId, cache in MonetizationSystem._gamePassCache do
		if cache.VIP == true then
			table.insert(vips, userId)
		end
	end
	return vips
end

function MonetizationSystem._applyVIPTag(player)
	local character = player.Character
	if not character then
		player.CharacterAdded:Once(function(char)
			MonetizationSystem._createVIPTag(char)
		end)
		return
	end
	MonetizationSystem._createVIPTag(character)
end

function MonetizationSystem._createVIPTag(character)
	local head = character:FindFirstChild("Head")
	if not head then return end

	-- Remove existing tag if any
	local existing = head:FindFirstChild("VIPTag")
	if existing then existing:Destroy() end

	local bg = Instance.new("BillboardGui")
	bg.Name = "VIPTag"
	bg.Size = UDim2.new(0, 80, 0, 20)
	bg.StudsOffset = Vector3.new(0, 2.2, 0)
	bg.AlwaysOnTop = true
	bg.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundColor3 = Config.Colors.Gold
	label.BackgroundTransparency = 0.2
	label.Text = "VIP"
	label.TextColor3 = Config.Colors.Background
	label.TextSize = 12
	label.Font = Enum.Font.GothamBold
	label.Parent = bg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end

-- ============================================================
-- XP MULTIPLIER
-- ============================================================

function MonetizationSystem.getXPMultiplier(player)
	if MonetizationSystem.hasGamePass(player, "DoubleXP") then
		return 2
	end
	return 1
end

-- ============================================================
-- VOTE COUNT (Extra Vote pass)
-- ============================================================

function MonetizationSystem.getVoteCount(player)
	if MonetizationSystem.hasGamePass(player, "ExtraVote") then
		return 2
	end
	return 1
end

-- ============================================================
-- CONFETTI EFFECT
-- ============================================================

function MonetizationSystem._fireConfetti(player)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Create confetti particles
	local attachment = Instance.new("Attachment")
	attachment.Name = "ConfettiAttachment"
	attachment.Parent = hrp

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Confetti"
	emitter.Rate = 100
	emitter.Lifetime = NumberRange.new(1, 3)
	emitter.Speed = NumberRange.new(5, 15)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.RotSpeed = NumberRange.new(-360, 360)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Config.Colors.Gold),
		ColorSequenceKeypoint.new(0.25, Config.Colors.Pink),
		ColorSequenceKeypoint.new(0.5, Config.Colors.Purple),
		ColorSequenceKeypoint.new(0.75, Config.Colors.Blue),
		ColorSequenceKeypoint.new(1, Config.Colors.Green),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = attachment

	-- Director announcement
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("DirectorAnnounce")
	if remote then
		remote:FireAllClients(player.DisplayName .. " just threw a CONFETTI BOMB!")
	end

	-- Clean up after 4 seconds
	task.delay(4, function()
		if attachment and attachment.Parent then
			attachment:Destroy()
		end
	end)
end

return MonetizationSystem

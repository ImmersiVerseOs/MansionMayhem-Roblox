-- ============================================================
-- IMMUNITY SYSTEM — Shards + tokens + shield effects
-- 3 shards = 1 immunity token. Use during nomination to be safe.
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SupabaseAPI = require(script.Parent.SupabaseAPI)
local Config = require(ReplicatedStorage.Shared.Config)

local ImmunitySystem = {}

-- State
ImmunitySystem.playerShards = {} -- { [userId] = shardCount }
ImmunitySystem.playerTokens = {} -- { [userId] = tokenCount }
ImmunitySystem.immunePlayers = {} -- { [userId] = { reason, expiresAt } }
ImmunitySystem.shieldEffects = {} -- { [userId] = partInstance }

-- Config
local SHARDS_PER_TOKEN = 3
local MAX_TOKENS = 3
local MAX_SHARDS = 99

-- ============================================================
-- SHARD MANAGEMENT
-- ============================================================

function ImmunitySystem.awardShard(userId, count, reason, gameManager)
	count = count or 1

	if not ImmunitySystem.playerShards[userId] then
		ImmunitySystem.playerShards[userId] = 0
	end

	ImmunitySystem.playerShards[userId] = math.min(
		ImmunitySystem.playerShards[userId] + count,
		MAX_SHARDS
	)

	local player = Players:GetPlayerByUserId(userId)
	local playerName = player and (player.DisplayName or player.Name) or "Unknown"

	print("[ImmunitySystem] Awarded", count, "shard(s) to", playerName, "— Total:", ImmunitySystem.playerShards[userId], "— Reason:", reason or "unspecified")

	-- Check for auto-conversion to token
	local shardsNow = ImmunitySystem.playerShards[userId]
	if shardsNow >= SHARDS_PER_TOKEN then
		local tokensToMake = math.floor(shardsNow / SHARDS_PER_TOKEN)
		local currentTokens = ImmunitySystem.playerTokens[userId] or 0

		-- Cap tokens
		local tokensToActuallyMake = math.min(tokensToMake, MAX_TOKENS - currentTokens)
		if tokensToActuallyMake > 0 then
			ImmunitySystem.playerShards[userId] = shardsNow - (tokensToActuallyMake * SHARDS_PER_TOKEN)
			ImmunitySystem.playerTokens[userId] = (ImmunitySystem.playerTokens[userId] or 0) + tokensToActuallyMake

			print("[ImmunitySystem]", playerName, "converted", tokensToActuallyMake, "token(s)! Tokens:", ImmunitySystem.playerTokens[userId])

			-- Notify player of token conversion
			if player then
				local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("ImmunityUpdate")
				if remote then
					remote:FireClient(player, {
						type = "token_earned",
						tokens = ImmunitySystem.playerTokens[userId],
						shards = ImmunitySystem.playerShards[userId],
						message = "You forged an IMMUNITY TOKEN! (" .. SHARDS_PER_TOKEN .. " shards = 1 token)",
					})
				end
			end

			-- Director announcement
			if gameManager and tokensToActuallyMake > 0 then
				gameManager.directorAnnounce(playerName .. " has earned an IMMUNITY TOKEN. The game just changed.")
			end
		end
	end

	-- Update client HUD
	if player then
		local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("ImmunityUpdate")
		if remote then
			remote:FireClient(player, {
				type = "shard_update",
				shards = ImmunitySystem.playerShards[userId],
				tokens = ImmunitySystem.playerTokens[userId] or 0,
			})
		end
	end
end

function ImmunitySystem.removeShard(userId, count)
	count = count or 1
	if not ImmunitySystem.playerShards[userId] then return end
	ImmunitySystem.playerShards[userId] = math.max(0, ImmunitySystem.playerShards[userId] - count)
end

-- ============================================================
-- TOKEN USAGE
-- ============================================================

function ImmunitySystem.useToken(player, gameManager)
	if not player then return { success = false, reason = "invalid_player" } end

	local userId = player.UserId
	local tokens = ImmunitySystem.playerTokens[userId] or 0

	if tokens <= 0 then
		return { success = false, reason = "no_tokens" }
	end

	-- Check if already immune
	if ImmunitySystem.immunePlayers[userId] then
		return { success = false, reason = "already_immune" }
	end

	-- Consume token
	ImmunitySystem.playerTokens[userId] = tokens - 1

	-- Grant immunity for this nomination/voting round
	ImmunitySystem.immunePlayers[userId] = {
		reason = "token",
		expiresAt = os.time() + 3600, -- 1 hour (covers a voting round)
	}

	print("[ImmunitySystem]", player.DisplayName, "used an IMMUNITY TOKEN! Remaining:", ImmunitySystem.playerTokens[userId])

	-- Apply visual shield effect
	ImmunitySystem._applyShieldEffect(player)

	-- Director announcement
	if gameManager then
		gameManager.directorAnnounce(
			player.DisplayName .. " has played an IMMUNITY TOKEN! They CANNOT be eliminated this round!"
		)
	end

	-- Notify all clients
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("ImmunityUpdate")
	if remote then
		-- Notify the user
		remote:FireClient(player, {
			type = "token_used",
			tokens = ImmunitySystem.playerTokens[userId],
			shards = ImmunitySystem.playerShards[userId] or 0,
			immune = true,
		})

		-- Notify everyone about the immune player
		local immuneRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("ImmunityAnnounce")
		if immuneRemote then
			immuneRemote:FireAllClients({
				userId = userId,
				name = player.DisplayName or player.Name,
				immune = true,
			})
		end

		-- Fire shield glow particle effect on the immune player
		local playEffect = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("PlayEffect")
		if playEffect then
			playEffect:FireAllClients({
				effect = "shieldGlow",
				targetUserId = userId,
				enable = true,
			})
		end
	end

	-- Sync to Supabase
	if gameManager and gameManager.seasonData then
		local seasonId = gameManager.seasonData.season and gameManager.seasonData.season.id
		if seasonId then
			task.spawn(function()
				SupabaseAPI.useImmunity(seasonId, tostring(userId))
			end)
		end
	end

	return { success = true, tokensRemaining = ImmunitySystem.playerTokens[userId] }
end

-- ============================================================
-- QUEEN IMMUNITY
-- ============================================================

function ImmunitySystem.grantQueenImmunity(userId, gameManager)
	ImmunitySystem.immunePlayers[userId] = {
		reason = "queen",
		expiresAt = os.time() + (7 * 24 * 3600), -- 1 week
	}

	local player = Players:GetPlayerByUserId(userId)
	if player then
		ImmunitySystem._applyShieldEffect(player)
	end

	print("[ImmunitySystem] Queen immunity granted to", userId)
end

function ImmunitySystem.revokeQueenImmunity(userId)
	if ImmunitySystem.immunePlayers[userId] and ImmunitySystem.immunePlayers[userId].reason == "queen" then
		ImmunitySystem.immunePlayers[userId] = nil
		ImmunitySystem._removeShieldEffect(userId)
	end
end

-- ============================================================
-- IMMUNITY CHECKS
-- ============================================================

function ImmunitySystem.isImmune(userId)
	local immunity = ImmunitySystem.immunePlayers[userId]
	if not immunity then return false end

	-- Check expiration
	if immunity.expiresAt and os.time() > immunity.expiresAt then
		ImmunitySystem.immunePlayers[userId] = nil
		ImmunitySystem._removeShieldEffect(userId)
		return false
	end

	return true
end

function ImmunitySystem.getShards(userId)
	return ImmunitySystem.playerShards[userId] or 0
end

function ImmunitySystem.getTokens(userId)
	return ImmunitySystem.playerTokens[userId] or 0
end

function ImmunitySystem.getImmunityInfo(userId)
	return {
		shards = ImmunitySystem.playerShards[userId] or 0,
		tokens = ImmunitySystem.playerTokens[userId] or 0,
		immune = ImmunitySystem.isImmune(userId),
		reason = ImmunitySystem.immunePlayers[userId] and ImmunitySystem.immunePlayers[userId].reason or nil,
	}
end

-- ============================================================
-- CLEAR ROUND IMMUNITY (after voting ends)
-- ============================================================

function ImmunitySystem.clearRoundImmunity()
	local cleared = {}
	for userId, immunity in ImmunitySystem.immunePlayers do
		if immunity.reason == "token" then
			table.insert(cleared, userId)
		end
	end

	for _, userId in cleared do
		ImmunitySystem.immunePlayers[userId] = nil
		ImmunitySystem._removeShieldEffect(userId)
	end

	if #cleared > 0 then
		print("[ImmunitySystem] Cleared round immunity for", #cleared, "player(s)")
	end
end

-- ============================================================
-- VISUAL SHIELD EFFECT
-- ============================================================

function ImmunitySystem._applyShieldEffect(player)
	if not player or not player.Character then return end

	local hrp = player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Remove existing shield
	ImmunitySystem._removeShieldEffect(player.UserId)

	-- Create shield sphere around player
	local shield = Instance.new("Part")
	shield.Name = "ImmunityShield"
	shield.Shape = Enum.PartType.Ball
	shield.Size = Vector3.new(8, 8, 8)
	shield.Color = Config.Colors.Blue
	shield.Material = Enum.Material.ForceField
	shield.Transparency = 0.7
	shield.CanCollide = false
	shield.Anchored = false
	shield.Massless = true
	shield.Parent = player.Character

	-- Weld to HumanoidRootPart
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = shield
	weld.Parent = shield

	shield.CFrame = hrp.CFrame

	-- Add glow
	local light = Instance.new("PointLight")
	light.Color = Config.Colors.Blue
	light.Brightness = 1.5
	light.Range = 20
	light.Parent = shield

	-- Add particle emitter for sparkle effect
	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(Config.Colors.Blue, Config.Colors.Gold)
	particles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
	particles.Lifetime = NumberRange.new(0.5, 1.5)
	particles.Rate = 20
	particles.Speed = NumberRange.new(2, 5)
	particles.SpreadAngle = Vector2.new(360, 360)
	particles.Parent = shield

	ImmunitySystem.shieldEffects[player.UserId] = shield
end

function ImmunitySystem._removeShieldEffect(userId)
	local shield = ImmunitySystem.shieldEffects[userId]
	if shield then
		shield:Destroy()
		ImmunitySystem.shieldEffects[userId] = nil
	end
end

-- ============================================================
-- SYNC ALL TO CLIENT (when player joins or reconnects)
-- ============================================================

function ImmunitySystem.syncToClient(player)
	if not player then return end

	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("ImmunityUpdate")
	if remote then
		remote:FireClient(player, {
			type = "full_sync",
			shards = ImmunitySystem.playerShards[player.UserId] or 0,
			tokens = ImmunitySystem.playerTokens[player.UserId] or 0,
			immune = ImmunitySystem.isImmune(player.UserId),
		})
	end
end

-- ============================================================
-- CLEANUP
-- ============================================================

function ImmunitySystem.onPlayerLeave(player)
	ImmunitySystem._removeShieldEffect(player.UserId)
	ImmunitySystem.immunePlayers[player.UserId] = nil
	-- Keep shards/tokens in case they rejoin (don't wipe)
end

return ImmunitySystem

-- ============================================================
-- SOUND SYSTEM — Manages all game audio
-- Sound effects + looping background music
-- ============================================================

local SoundService = game:GetService("SoundService")

local SoundSystem = {}

-- Track current music
SoundSystem._currentMusic = nil
SoundSystem._musicVolume = 0.5
SoundSystem._initialized = false

-- Sound effect definitions
local SFX = {
	elimination_drumroll = { id = "rbxassetid://5765633489", volume = 0.8 },
	elimination_reveal   = { id = "rbxassetid://5765634832", volume = 0.8 },
	fight_alert          = { id = "rbxassetid://5765635476", volume = 0.7 },
	queen_crowning       = { id = "rbxassetid://5765636123", volume = 0.9 },
	vote_cast            = { id = "rbxassetid://421058925",  volume = 0.6 },
	check_in_success     = { id = "rbxassetid://421058925",  volume = 0.6 },
	director_chime       = { id = "rbxassetid://6042053626", volume = 0.7 },
	immunity_use         = { id = "rbxassetid://4612373815", volume = 0.7 },
	alliance_form        = { id = "rbxassetid://4612373815", volume = 0.6 },
	challenge_complete   = { id = "rbxassetid://5765634832", volume = 0.7 },
	ui_click             = { id = "rbxassetid://876939830",  volume = 0.4 },
	ui_open              = { id = "rbxassetid://876939830",  volume = 0.3 },
	notification         = { id = "rbxassetid://6042053626", volume = 0.5 },
}

-- Background music definitions
local MUSIC = {
	mansion_ambient      = { id = "rbxassetid://1837849285", volume = 0.3 },
	elimination_tension  = { id = "rbxassetid://1839841276", volume = 0.35 },
	celebration          = { id = "rbxassetid://1845554017", volume = 0.35 },
	drama_buildup        = { id = "rbxassetid://1836677817", volume = 0.3 },
}

-- ============================================================
-- INITIALIZATION
-- ============================================================

function SoundSystem.init()
	if SoundSystem._initialized then return end
	SoundSystem._initialized = true

	-- Create SFX folder under SoundService
	local sfxFolder = Instance.new("Folder")
	sfxFolder.Name = "SFX"
	sfxFolder.Parent = SoundService

	for name, data in SFX do
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = data.id
		sound.Volume = data.volume
		sound.Looped = false
		sound.Parent = sfxFolder
	end

	-- Create Music folder under SoundService
	local musicFolder = Instance.new("Folder")
	musicFolder.Name = "Music"
	musicFolder.Parent = SoundService

	for name, data in MUSIC do
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = data.id
		sound.Volume = data.volume * SoundSystem._musicVolume
		sound.Looped = true
		sound.Parent = musicFolder
	end

	print("[SoundSystem] Initialized — " .. tostring(#SFX) .. " SFX, " .. tostring(#MUSIC) .. " music tracks")
end

-- ============================================================
-- PLAY SOUND EFFECT
-- ============================================================

function SoundSystem.play(soundName)
	local sfxFolder = SoundService:FindFirstChild("SFX")
	if not sfxFolder then return end

	local sound = sfxFolder:FindFirstChild(soundName)
	if sound then
		sound:Play()
	else
		warn("[SoundSystem] Unknown SFX: " .. tostring(soundName))
	end
end

-- ============================================================
-- BACKGROUND MUSIC
-- ============================================================

function SoundSystem.playMusic(musicName)
	-- Stop current music first
	SoundSystem.stopMusic()

	local musicFolder = SoundService:FindFirstChild("Music")
	if not musicFolder then return end

	local sound = musicFolder:FindFirstChild(musicName)
	if sound then
		sound.Volume = (MUSIC[musicName] and MUSIC[musicName].volume or 0.3) * SoundSystem._musicVolume
		sound:Play()
		SoundSystem._currentMusic = sound
	else
		warn("[SoundSystem] Unknown music track: " .. tostring(musicName))
	end
end

function SoundSystem.stopMusic()
	if SoundSystem._currentMusic then
		SoundSystem._currentMusic:Stop()
		SoundSystem._currentMusic = nil
	end
end

function SoundSystem.setMusicVolume(vol)
	vol = math.clamp(vol, 0, 1)
	SoundSystem._musicVolume = vol

	-- Update currently playing music
	if SoundSystem._currentMusic then
		local name = SoundSystem._currentMusic.Name
		local baseVol = MUSIC[name] and MUSIC[name].volume or 0.3
		SoundSystem._currentMusic.Volume = baseVol * vol
	end
end

return SoundSystem

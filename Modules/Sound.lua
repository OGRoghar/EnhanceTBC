-- Modules/Sound.lua
local ADDON_NAME, ETBC = ...

ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.Sound = mod

local driver
local inCombat = false

-- Track previous state for combat restore
local prev = {
  musicMute = nil,
  ambienceMute = nil,
  musicVolume = nil,
  ambienceVolume = nil,
}

local function EnsureDriver()
  if driver then return end
  driver = CreateFrame("Frame", "EnhanceTBC_SoundDriver", UIParent)
  driver:Hide()
end

local function GetDB()
  ETBC.db.profile.sound = ETBC.db.profile.sound or {}
  local db = ETBC.db.profile.sound
  if db.enabled == nil then db.enabled = true end

  if db.masterMute == nil then db.masterMute = false end
  if db.musicMute == nil then db.musicMute = false end
  if db.ambienceMute == nil then db.ambienceMute = false end

  if db.masterVolume == nil then db.masterVolume = 1.0 end
  if db.sfxVolume == nil then db.sfxVolume = 1.0 end
  if db.musicVolume == nil then db.musicVolume = 0.7 end
  if db.ambienceVolume == nil then db.ambienceVolume = 0.7 end

  if db.autoUnmuteOnLogin == nil then db.autoUnmuteOnLogin = false end
  if db.autoMuteInCombat == nil then db.autoMuteInCombat = false end
  if db.autoMuteInCombatMode == nil then db.autoMuteInCombatMode = "MUSIC" end
  if db.autoMuteInCombatRestore == nil then db.autoMuteInCombatRestore = true end

  if db.pushToTalk == nil then db.pushToTalk = false end

  return db
end

local function Clamp01(v)
  v = tonumber(v) or 0
  if v < 0 then return 0 end
  if v > 1 then return 1 end
  return v
end

local function IsPlayerInCombat()
  if InCombatLockdown and InCombatLockdown() then return true end
  if UnitAffectingCombat then return UnitAffectingCombat("player") and true or false end
  return false
end

local function SetCVarSafe(name, value)
  if type(name) ~= "string" then return end
  if value == nil then return end
  -- Convert booleans to 0/1 for CVars
  if type(value) == "boolean" then
    value = value and "1" or "0"
  end
  SetCVar(name, tostring(value))
end

local function ApplyCVars(db)
  -- Mute toggles
  SetCVarSafe("Sound_EnableAllSound", db.masterMute and 0 or 1)
  SetCVarSafe("Sound_EnableMusic", db.musicMute and 0 or 1)
  SetCVarSafe("Sound_EnableAmbience", db.ambienceMute and 0 or 1)

  -- Volume sliders
  SetCVarSafe("Sound_MasterVolume", Clamp01(db.masterVolume))
  SetCVarSafe("Sound_SFXVolume", Clamp01(db.sfxVolume))
  SetCVarSafe("Sound_MusicVolume", Clamp01(db.musicVolume))
  SetCVarSafe("Sound_AmbienceVolume", Clamp01(db.ambienceVolume))

  -- Voice toggle (if supported)
  -- Some classic clients use these; harmless if ignored
  SetCVarSafe("VoiceChatMode", db.pushToTalk and 1 or 0) -- 1 often push-to-talk
end

local function SnapshotForCombat(db)
  prev.musicMute = (GetCVar("Sound_EnableMusic") == "0")
  prev.ambienceMute = (GetCVar("Sound_EnableAmbience") == "0")
  prev.musicVolume = tonumber(GetCVar("Sound_MusicVolume") or "0.7") or 0.7
  prev.ambienceVolume = tonumber(GetCVar("Sound_AmbienceVolume") or "0.7") or 0.7
end

local function ApplyCombatMute(db)
  if not db.autoMuteInCombat then return end
  if not inCombat then return end

  local mode = db.autoMuteInCombatMode or "MUSIC"
  if mode == "MUSIC" then
    SetCVarSafe("Sound_EnableMusic", 0)
  elseif mode == "AMBIENCE" then
    SetCVarSafe("Sound_EnableAmbience", 0)
  else
    SetCVarSafe("Sound_EnableMusic", 0)
    SetCVarSafe("Sound_EnableAmbience", 0)
  end
end

local function RestoreAfterCombat(db)
  if not db.autoMuteInCombat then return end
  if not db.autoMuteInCombatRestore then return end

  -- restore mutes/volumes as they were before combat
  if prev.musicMute ~= nil then
    SetCVarSafe("Sound_EnableMusic", prev.musicMute and 0 or 1)
  end
  if prev.ambienceMute ~= nil then
    SetCVarSafe("Sound_EnableAmbience", prev.ambienceMute and 0 or 1)
  end
  if prev.musicVolume ~= nil then
    SetCVarSafe("Sound_MusicVolume", Clamp01(prev.musicVolume))
  end
  if prev.ambienceVolume ~= nil then
    SetCVarSafe("Sound_AmbienceVolume", Clamp01(prev.ambienceVolume))
  end
end

local function OnEnterCombat()
  local db = GetDB()
  if not (ETBC.db.profile.general.enabled and db.enabled) then return end
  if not db.autoMuteInCombat then return end

  inCombat = true
  SnapshotForCombat(db)
  ApplyCombatMute(db)
end

local function OnLeaveCombat()
  local db = GetDB()
  if not (ETBC.db.profile.general.enabled and db.enabled) then return end
  if not db.autoMuteInCombat then return end

  inCombat = false
  RestoreAfterCombat(db)
end

local function OnLogin(db)
  if db.autoUnmuteOnLogin then
    -- turn on sound systems, but keep your chosen mutes afterward
    SetCVarSafe("Sound_EnableAllSound", 1)
    ApplyCVars(db)
  else
    ApplyCVars(db)
  end
end

local function Apply()
  EnsureDriver()

  local db = GetDB()
  local enabled = ETBC.db.profile.general.enabled and db.enabled

  driver:UnregisterAllEvents()
  driver:SetScript("OnEvent", nil)

  if enabled then
    OnLogin(db)

    inCombat = IsPlayerInCombat()
    if inCombat and db.autoMuteInCombat then
      SnapshotForCombat(db)
      ApplyCombatMute(db)
    end

    driver:RegisterEvent("PLAYER_LOGIN")
    driver:RegisterEvent("PLAYER_REGEN_DISABLED")
    driver:RegisterEvent("PLAYER_REGEN_ENABLED")

    driver:SetScript("OnEvent", function(_, event)
      if event == "PLAYER_LOGIN" then
        OnLogin(db)
      elseif event == "PLAYER_REGEN_DISABLED" then
        OnEnterCombat()
      elseif event == "PLAYER_REGEN_ENABLED" then
        OnLeaveCombat()
      end
    end)

    driver:Show()
  else
    if inCombat then
      RestoreAfterCombat(db)
    end
    inCombat = false
    driver:Hide()
  end
end

ETBC.ApplyBus:Register("sound", Apply)
ETBC.ApplyBus:Register("general", Apply)

-- Settings/Settings_Sound.lua
local ADDON_NAME, ETBC = ...
local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceTBC")
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
  if db.autoMuteInCombatMode == nil then db.autoMuteInCombatMode = "MUSIC" end -- MUSIC / AMBIENCE / BOTH
  if db.autoMuteInCombatRestore == nil then db.autoMuteInCombatRestore = true end

  if db.pushToTalk == nil then db.pushToTalk = false end

  return db
end

local function EnsureDefaults()
  if not ETBC.db or not ETBC.db.profile then return end
  GetDB()
end

ETBC.SettingsRegistry:RegisterGroup("sound", {
  name = "Sound",
  order = 40,
  options = function()
    EnsureDefaults()
    local db = GetDB()

    local combatModes = {
      MUSIC = "Mute Music",
      AMBIENCE = "Mute Ambience",
      BOTH = "Mute Music + Ambience",
    }

    return {
      enabled = {
        type = "toggle",
        name = "Enable Sound module",
        order = 1,
        get = function() return db.enabled end,
        set = function(_, v) db.enabled = v and true or false; ETBC.ApplyBus:Notify("sound") end,
      },

      mutes = {
        type = "group",
        name = "Mute Toggles",
        order = 10,
        inline = true,
        args = {
          masterMute = {
            type = "toggle",
            name = "Master Mute",
            order = 1,
            get = function() return db.masterMute end,
            set = function(_, v) db.masterMute = v and true or false; ETBC.ApplyBus:Notify("sound") end,
            disabled = function() return not db.enabled end,
          },
          musicMute = {
            type = "toggle",
            name = "Mute Music",
            order = 2,
            get = function() return db.musicMute end,
            set = function(_, v) db.musicMute = v and true or false; ETBC.ApplyBus:Notify("sound") end,
            disabled = function() return not db.enabled end,
          },
          ambienceMute = {
            type = "toggle",
            name = "Mute Ambience",
            order = 3,
            get = function() return db.ambienceMute end,
            set = function(_, v) db.ambienceMute = v and true or false; ETBC.ApplyBus:Notify("sound") end,
            disabled = function() return not db.enabled end,
          },
        },
      },

      volumes = {
        type = "group",
        name = "Volume Sliders",
        order = 20,
        inline = true,
        args = {
          masterVolume = {
            type = "range",
            name = "Master Volume",
            order = 1,
            min = 0, max = 1, step = 0.01,
            get = function() return db.masterVolume end,
            set = function(_, v) db.masterVolume = v; ETBC.ApplyBus:Notify("sound") end,
            disabled = function() return not db.enabled end,
          },
          sfxVolume = {
            type = "range",
            name = "SFX Volume",
            order = 2,
            min = 0, max = 1, step = 0.01,
            get = function() return db.sfxVolume end,
            set = function(_, v) db.sfxVolume = v; ETBC.ApplyBus:Notify("sound") end,
            disabled = function() return not db.enabled end,
          },
          musicVolume = {
            type = "range",
            name = "Music Volume",
            order = 3,
            min = 0, max = 1, step = 0.01,
            get = function() return db.musicVolume end,
            set = function(_, v) db.musicVolume = v; ETBC.ApplyBus:Notify("sound") end,
            disabled = function() return not db.enabled end,
          },
          ambienceVolume = {
            type = "range",
            name = "Ambience Volume",
            order = 4,
            min = 0, max = 1, step = 0.01,
            get = function() return db.ambienceVolume end,
            set = function(_, v) db.ambienceVolume = v; ETBC.ApplyBus:Notify("sound") end,
            disabled = function() return not db.enabled end,
          },
        },
      },

      smart = {
        type = "group",
        name = "Smart Rules",
        order = 30,
        inline = true,
        args = {
          autoUnmuteOnLogin = {
            type = "toggle",
            name = "Auto-unmute on Login",
            order = 1,
            get = function() return db.autoUnmuteOnLogin end,
            set = function(_, v) db.autoUnmuteOnLogin = v and true or false; ETBC.ApplyBus:Notify("sound") end,
            disabled = function() return not db.enabled end,
          },
          autoMuteInCombat = {
            type = "toggle",
            name = "Auto-mute in Combat",
            order = 2,
            get = function() return db.autoMuteInCombat end,
            set = function(_, v) db.autoMuteInCombat = v and true or false; ETBC.ApplyBus:Notify("sound") end,
            disabled = function() return not db.enabled end,
          },
          autoMuteInCombatMode = {
            type = "select",
            name = "Combat mute target",
            order = 3,
            values = combatModes,
            get = function() return db.autoMuteInCombatMode end,
            set = function(_, v) db.autoMuteInCombatMode = v; ETBC.ApplyBus:Notify("sound") end,
            disabled = function() return not (db.enabled and db.autoMuteInCombat) end,
          },
          autoMuteInCombatRestore = {
            type = "toggle",
            name = "Restore after leaving combat",
            order = 4,
            get = function() return db.autoMuteInCombatRestore end,
            set = function(_, v) db.autoMuteInCombatRestore = v and true or false; ETBC.ApplyBus:Notify("sound") end,
            disabled = function() return not (db.enabled and db.autoMuteInCombat) end,
          },
          pushToTalk = {
            type = "toggle",
            name = "Voice: Push-to-Talk",
            order = 5,
            get = function() return db.pushToTalk end,
            set = function(_, v) db.pushToTalk = v and true or false; ETBC.ApplyBus:Notify("sound") end,
            disabled = function() return not db.enabled end,
          },
        },
      },
    }
  end,
})

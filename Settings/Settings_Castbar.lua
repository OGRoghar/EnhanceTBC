-- Settings/Settings_Castbar.lua
-- EnhanceTBC - Castbar+ settings

local _, ETBC = ...
local CASTBAR_DEFAULTS = {
  enabled = true,
  player = true,
  target = true,
  focus = true,

  width = 240,
  height = 18,
  scale = 1.00,
  xOffset = 0,
  yOffset = 0,

  font = "Friz Quadrata TT",
  texture = "Blizzard",
  fontSize = 12,
  outline = "OUTLINE",
  shadow = true,
  showTime = true,
  timeFormat = "REMAIN",
  decimals = 1,

  skin = true,
  showChannelTicks = false,
  classColorPlayerCastbar = false,

  castColor = { 0.25, 0.80, 0.25 },
  channelColor = { 0.25, 0.55, 1.00 },
  nonInterruptibleColor = { 0.85, 0.25, 0.25 },
  backgroundAlpha = 0.35,
  borderAlpha = 0.95,

  showLatency = true,
  latencyMode = "CAST",
  latencyAlpha = 0.45,
  latencyColor = { 1.0, 0.15, 0.15 },

  fadeOut = true,
  fadeOutTime = 0.20,

  onlyInCombat = false,
  oocAlpha = 1.0,
  combatAlpha = 1.0,
}

local function GetDB()
  ETBC.db.profile.castbar = ETBC.db.profile.castbar or {}
  local db = ETBC.db.profile.castbar

  for key, value in pairs(CASTBAR_DEFAULTS) do
    if db[key] == nil then
      if type(value) == "table" then
        db[key] = { value[1], value[2], value[3] }
      else
        db[key] = value
      end
    end
  end

  return db
end

local function EnsureDefaults()
  if not ETBC.db or not ETBC.db.profile then return end
  GetDB()
end

local function LSM_Fonts()
  if ETBC.LSM and ETBC.LSM.HashTable then
    return ETBC.LSM:HashTable("font")
  end
  return {
    ["Friz Quadrata TT"] = "Fonts\\FRIZQT__.TTF",
    ["Arial Narrow"] = "Fonts\\ARIALN.TTF",
    ["Skurri"] = "Fonts\\SKURRI.TTF",
    ["Morpheus"] = "Fonts\\MORPHEUS.TTF",
  }
end

local function LSM_Textures()
  if ETBC.LSM and ETBC.LSM.HashTable then
    return ETBC.LSM:HashTable("statusbar")
  end
  return { Blizzard = "Interface\\TargetingFrame\\UI-StatusBar" }
end

ETBC.SettingsRegistry:RegisterGroup("castbar", {
  name = "Castbar+",
  order = 18,
  options = function()
    EnsureDefaults()
    local db = GetDB()

    return {
      enabled = {
        type = "toggle",
        name = "Enable",
        order = 1,
        width = "full",
        get = function() return db.enabled end,
        set = function(_, v) db.enabled = v and true or false; ETBC.ApplyBus:Notify("castbar") end,
      },

      framesHeader = { type = "header", name = "Frames", order = 10 },

      player = {
        type = "toggle",
        name = "Player castbar",
        order = 11,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.player end,
        set = function(_, v) db.player = v and true or false; ETBC.ApplyBus:Notify("castbar") end,
      },

      target = {
        type = "toggle",
        name = "Target castbar",
        order = 12,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.target end,
        set = function(_, v) db.target = v and true or false; ETBC.ApplyBus:Notify("castbar") end,
      },

      focus = {
        type = "toggle",
        name = "Focus castbar",
        order = 13,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.focus end,
        set = function(_, v) db.focus = v and true or false; ETBC.ApplyBus:Notify("castbar") end,
      },

      playerIconInfo = {
        type = "description",
        name = "Player spell icon is forced visible while Castbar+ is enabled.",
        order = 14,
        width = "full",
      },

      layoutHeader = { type = "header", name = "Layout", order = 20 },

      scale = {
        type = "range",
        name = "Scale",
        order = 21,
        min = 0.70, max = 1.60, step = 0.01,
        disabled = function() return not db.enabled end,
        get = function() return db.scale end,
        set = function(_, v) db.scale = v; ETBC.ApplyBus:Notify("castbar") end,
      },

      skin = {
        type = "toggle",
        name = "Use Castbar Skin",
        desc = "Applies the EnhanceTBC castbar skin (backdrop, icon border, hidden spark/flash). " ..
          "Player icon remains visible while Castbar+ is enabled.",
        order = 23,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.skin end,
        set = function(_, v) db.skin = v and true or false; ETBC.ApplyBus:Notify("castbar") end,
      },

      texture = {
        type = "select",
        name = "Bar texture",
        order = 24,
        disabled = function() return not db.enabled end,
        values = LSM_Textures,
        get = function() return db.texture end,
        set = function(_, v) db.texture = v; ETBC.ApplyBus:Notify("castbar") end,
      },

      xOffset = {
        type = "range",
        name = "Player X offset",
        desc = "Moves only the player castbar.",
        order = 25,
        min = -200, max = 200, step = 1,
        disabled = function() return not db.enabled end,
        get = function() return db.xOffset end,
        set = function(_, v) db.xOffset = v; ETBC.ApplyBus:Notify("castbar") end,
      },

      yOffset = {
        type = "range",
        name = "Player Y offset",
        desc = "Moves only the player castbar.",
        order = 26,
        min = -200, max = 200, step = 1,
        disabled = function() return not db.enabled end,
        get = function() return db.yOffset end,
        set = function(_, v) db.yOffset = v; ETBC.ApplyBus:Notify("castbar") end,
      },

      textHeader = { type = "header", name = "Text", order = 30 },

      font = {
        type = "select",
        name = "Font",
        order = 31,
        disabled = function() return not db.enabled end,
        values = LSM_Fonts,
        get = function() return db.font end,
        set = function(_, v) db.font = v; ETBC.ApplyBus:Notify("castbar") end,
      },

      fontSize = {
        type = "range",
        name = "Font size",
        order = 32,
        min = 8, max = 22, step = 1,
        disabled = function() return not db.enabled end,
        get = function() return db.fontSize end,
        set = function(_, v) db.fontSize = v; ETBC.ApplyBus:Notify("castbar") end,
      },

      outline = {
        type = "select",
        name = "Outline",
        order = 33,
        disabled = function() return not db.enabled end,
        values = function()
          return { [""] = "None", OUTLINE = "Outline", THICKOUTLINE = "Thick" }
        end,
        get = function() return db.outline end,
        set = function(_, v) db.outline = v; ETBC.ApplyBus:Notify("castbar") end,
      },

      shadow = {
        type = "toggle",
        name = "Shadow",
        order = 34,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.shadow end,
        set = function(_, v) db.shadow = v and true or false; ETBC.ApplyBus:Notify("castbar") end,
      },

      showTime = {
        type = "toggle",
        name = "Show timer text",
        order = 35,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.showTime end,
        set = function(_, v) db.showTime = v and true or false; ETBC.ApplyBus:Notify("castbar") end,
      },

      timeFormat = {
        type = "select",
        name = "Timer format",
        order = 36,
        disabled = function() return not (db.enabled and db.showTime) end,
        values = function()
          return { REMAIN = "Remaining", ELAPSED = "Elapsed", BOTH = "Elapsed/Total" }
        end,
        get = function() return db.timeFormat end,
        set = function(_, v) db.timeFormat = v; ETBC.ApplyBus:Notify("castbar") end,
      },

      decimals = {
        type = "range",
        name = "Timer decimals",
        order = 37,
        min = 0, max = 2, step = 1,
        disabled = function() return not (db.enabled and db.showTime) end,
        get = function() return db.decimals end,
        set = function(_, v) db.decimals = v; ETBC.ApplyBus:Notify("castbar") end,
      },

      colorHeader = { type = "header", name = "Colors", order = 40 },

      classColorPlayerCastbar = {
        type = "toggle",
        name = "Class-color player cast/channel",
        desc = "Applies only to the player castbar. Overrides Casting and Channeling colors for player casts only. "
          .. "Non-interruptible, target, and focus castbars continue using the custom color settings below.",
        order = 40.1,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.classColorPlayerCastbar end,
        set = function(_, v) db.classColorPlayerCastbar = v and true or false; ETBC.ApplyBus:Notify("castbar") end,
      },

      castColor = {
        type = "color",
        name = "Casting",
        order = 41,
        disabled = function() return not db.enabled end,
        get = function() local c=db.castColor; return c[1],c[2],c[3] end,
        set = function(_, r,g,b) db.castColor={r,g,b}; ETBC.ApplyBus:Notify("castbar") end,
      },

      channelColor = {
        type = "color",
        name = "Channeling",
        order = 42,
        disabled = function() return not db.enabled end,
        get = function() local c=db.channelColor; return c[1],c[2],c[3] end,
        set = function(_, r,g,b) db.channelColor={r,g,b}; ETBC.ApplyBus:Notify("castbar") end,
      },

      nonInterruptibleColor = {
        type = "color",
        name = "Non-interruptible",
        order = 43,
        disabled = function() return not db.enabled end,
        get = function() local c=db.nonInterruptibleColor; return c[1],c[2],c[3] end,
        set = function(_, r,g,b) db.nonInterruptibleColor={r,g,b}; ETBC.ApplyBus:Notify("castbar") end,
      },

      backgroundAlpha = {
        type = "range",
        name = "Background alpha",
        order = 44,
        min = 0.0, max = 0.8, step = 0.01,
        disabled = function() return not db.enabled end,
        get = function() return db.backgroundAlpha end,
        set = function(_, v) db.backgroundAlpha = v; ETBC.ApplyBus:Notify("castbar") end,
      },

      borderAlpha = {
        type = "range",
        name = "Border alpha",
        order = 45,
        min = 0.0, max = 1.0, step = 0.01,
        disabled = function() return not db.enabled end,
        get = function() return db.borderAlpha end,
        set = function(_, v) db.borderAlpha = v; ETBC.ApplyBus:Notify("castbar") end,
      },

      latencyHeader = { type = "header", name = "Latency (Player)", order = 50 },

      showLatency = {
        type = "toggle",
        name = "Show latency safe zone",
        order = 51,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.showLatency end,
        set = function(_, v) db.showLatency = v and true or false; ETBC.ApplyBus:Notify("castbar") end,
      },

      latencyMode = {
        type = "select",
        name = "Latency source",
        order = 52,
        disabled = function() return not (db.enabled and db.showLatency) end,
        values = function()
          return { CAST = "Cast events", NET = "Network stats" }
        end,
        get = function() return db.latencyMode end,
        set = function(_, v) db.latencyMode = v; ETBC.ApplyBus:Notify("castbar") end,
      },

      latencyAlpha = {
        type = "range",
        name = "Latency alpha",
        order = 53,
        min = 0.0, max = 1.0, step = 0.01,
        disabled = function() return not (db.enabled and db.showLatency) end,
        get = function() return db.latencyAlpha end,
        set = function(_, v) db.latencyAlpha = v; ETBC.ApplyBus:Notify("castbar") end,
      },

      latencyColor = {
        type = "color",
        name = "Latency color",
        order = 54,
        disabled = function() return not (db.enabled and db.showLatency) end,
        get = function() local c=db.latencyColor; return c[1],c[2],c[3] end,
        set = function(_, r,g,b) db.latencyColor={r,g,b}; ETBC.ApplyBus:Notify("castbar") end,
      },

      channelHeader = { type = "header", name = "Channeling", order = 55 },

      showChannelTicks = {
        type = "toggle",
        name = "Show channel tick markers",
        order = 56,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.showChannelTicks end,
        set = function(_, v) db.showChannelTicks = v and true or false; ETBC.ApplyBus:Notify("castbar") end,
      },

      fadeHeader = { type = "header", name = "Fade Out", order = 60 },

      fadeOut = {
        type = "toggle",
        name = "Fade after cast finishes",
        order = 61,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.fadeOut end,
        set = function(_, v) db.fadeOut = v and true or false; ETBC.ApplyBus:Notify("castbar") end,
      },

      fadeOutTime = {
        type = "range",
        name = "Fade time",
        order = 62,
        min = 0.0, max = 1.0, step = 0.01,
        disabled = function() return not (db.enabled and db.fadeOut) end,
        get = function() return db.fadeOutTime end,
        set = function(_, v) db.fadeOutTime = v; ETBC.ApplyBus:Notify("castbar") end,
      },

      preview = {
        type = "execute",
        name = "Show Preview",
        order = 70,
        width = "full",
        disabled = function() return not db.enabled end,
        func = function()
          if ETBC.Modules and ETBC.Modules.Castbar and ETBC.Modules.Castbar.ShowPreview then
            ETBC.Modules.Castbar:ShowPreview(2.0)
          end
        end,
      },
    }
  end,
})

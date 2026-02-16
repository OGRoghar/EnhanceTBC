-- Settings/Settings_Castbar.lua
-- EnhanceTBC - Castbar+ settings

local ADDON_NAME, ETBC = ...

local function GetDB()
  ETBC.db.profile.castbar = ETBC.db.profile.castbar or {}
  local db = ETBC.db.profile.castbar

  if db.enabled == nil then db.enabled = true end

  -- Per-frame toggles
  if db.player == nil then db.player = true end
  if db.target == nil then db.target = true end
  if db.focus == nil then db.focus = true end

  -- Layout
  if db.width == nil then db.width = 240 end
  if db.height == nil then db.height = 18 end
  if db.scale == nil then db.scale = 1.00 end
  if db.xOffset == nil then db.xOffset = 0 end
  if db.yOffset == nil then db.yOffset = 0 end

  -- Text
  if db.font == nil then db.font = "Friz Quadrata TT" end
  if db.fontSize == nil then db.fontSize = 12 end
  if db.outline == nil then db.outline = "OUTLINE" end
  if db.shadow == nil then db.shadow = true end
  if db.showTime == nil then db.showTime = true end
  if db.timeFormat == nil then db.timeFormat = "REMAIN" end -- REMAIN / ELAPSED
  if db.decimals == nil then db.decimals = 1 end

  -- Colors
  if db.castColor == nil then db.castColor = { 0.25, 0.80, 0.25 } end
  if db.channelColor == nil then db.channelColor = { 0.25, 0.55, 1.00 } end
  if db.nonInterruptibleColor == nil then db.nonInterruptibleColor = { 0.85, 0.25, 0.25 } end
  if db.backgroundAlpha == nil then db.backgroundAlpha = 0.35 end
  if db.borderAlpha == nil then db.borderAlpha = 0.95 end

  -- Latency (player only)
  if db.showLatency == nil then db.showLatency = true end
  if db.latencyAlpha == nil then db.latencyAlpha = 0.45 end
  if db.latencyColor == nil then db.latencyColor = { 1.0, 0.15, 0.15 } end

  -- Fade out
  if db.fadeOut == nil then db.fadeOut = true end
  if db.fadeOutTime == nil then db.fadeOutTime = 0.20 end

  return db
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

ETBC.SettingsRegistry:RegisterGroup("castbar", {
  name = "Castbar+",
  order = 18,
  options = function()
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

      layoutHeader = { type = "header", name = "Layout", order = 20 },

      width = {
        type = "range",
        name = "Width",
        desc = "Not functional due to Blizzard frame limitations. Use Scale instead.",
        order = 21,
        min = 120, max = 520, step = 1,
        disabled = function() return true end,
        get = function() return db.width end,
        set = function(_, v) db.width = v; ETBC.ApplyBus:Notify("castbar") end,
      },

      height = {
        type = "range",
        name = "Height",
        desc = "Not functional due to Blizzard frame limitations. Use Scale instead.",
        order = 22,
        min = 10, max = 40, step = 1,
        disabled = function() return true end,
        get = function() return db.height end,
        set = function(_, v) db.height = v; ETBC.ApplyBus:Notify("castbar") end,
      },

      scale = {
        type = "range",
        name = "Scale",
        order = 23,
        min = 0.70, max = 1.60, step = 0.01,
        disabled = function() return not db.enabled end,
        get = function() return db.scale end,
        set = function(_, v) db.scale = v; ETBC.ApplyBus:Notify("castbar") end,
      },

      xOffset = {
        type = "range",
        name = "X offset",
        order = 24,
        min = -200, max = 200, step = 1,
        disabled = function() return not db.enabled end,
        get = function() return db.xOffset end,
        set = function(_, v) db.xOffset = v; ETBC.ApplyBus:Notify("castbar") end,
      },

      yOffset = {
        type = "range",
        name = "Y offset",
        order = 25,
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
          return { REMAIN = "Remaining", ELAPSED = "Elapsed" }
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

      latencyAlpha = {
        type = "range",
        name = "Latency alpha",
        order = 52,
        min = 0.0, max = 1.0, step = 0.01,
        disabled = function() return not (db.enabled and db.showLatency) end,
        get = function() return db.latencyAlpha end,
        set = function(_, v) db.latencyAlpha = v; ETBC.ApplyBus:Notify("castbar") end,
      },

      latencyColor = {
        type = "color",
        name = "Latency color",
        order = 53,
        disabled = function() return not (db.enabled and db.showLatency) end,
        get = function() local c=db.latencyColor; return c[1],c[2],c[3] end,
        set = function(_, r,g,b) db.latencyColor={r,g,b}; ETBC.ApplyBus:Notify("castbar") end,
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
    }
  end,
})

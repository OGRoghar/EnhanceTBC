-- Settings/Settings_Cooldowns.lua
-- EnhanceTBC - Cooldown Text Engine settings (OmniCC-lite)

local _, ETBC = ...
local function GetDB()
  ETBC.db.profile.cooldowns = ETBC.db.profile.cooldowns or {}
  local db = ETBC.db.profile.cooldowns

  if db.enabled == nil then db.enabled = true end

  -- Where to show text
  if db.actionButtons == nil then db.actionButtons = true end
  if db.buffsDebuffs == nil then db.buffsDebuffs = true end
  if db.otherCooldownFrames == nil then db.otherCooldownFrames = true end -- fallback/global

  -- Display rules
  if db.minDuration == nil then db.minDuration = 2.5 end
  if db.maxDuration == nil then db.maxDuration = 3600 end
  if db.hideWhenGCD == nil then db.hideWhenGCD = true end
  if db.hideWhenNoDuration == nil then db.hideWhenNoDuration = true end
  if db.hideWhenPaused == nil then db.hideWhenPaused = true end
  if db.showSwipe == nil then db.showSwipe = true end
  -- does not change cooldown behavior, just hides Blizzard swipe if false

  -- Formatting
  if db.mmssThreshold == nil then db.mmssThreshold = 60 end
  if db.showTenths == nil then db.showTenths = true end
  if db.tenthsThreshold == nil then db.tenthsThreshold = 3.0 end
  if db.roundUp == nil then db.roundUp = true end

  -- Style
  if db.font == nil then db.font = "Friz Quadrata TT" end
  if db.size == nil then db.size = 16 end
  if db.outline == nil then db.outline = "OUTLINE" end
  if db.shadow == nil then db.shadow = true end
  if db.scaleByIcon == nil then db.scaleByIcon = true end
  if db.minScale == nil then db.minScale = 0.70 end
  if db.maxScale == nil then db.maxScale = 1.10 end

  -- Colors
  if db.colorNormal == nil then db.colorNormal = { 0.90, 0.95, 0.90 } end
  if db.colorSoon == nil then db.colorSoon = { 1.00, 0.85, 0.25 } end
  if db.colorNow == nil then db.colorNow = { 1.00, 0.35, 0.35 } end
  if db.soonThreshold == nil then db.soonThreshold = 5.0 end
  if db.nowThreshold == nil then db.nowThreshold = 2.0 end

  -- Performance
  if db.updateInterval == nil then db.updateInterval = 0.08 end -- seconds
  if db.maxTracked == nil then db.maxTracked = 400 end

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

ETBC.SettingsRegistry:RegisterGroup("cooldowns", {
  name = "Cooldown Text",
  order = 33,
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
        set = function(_, v) db.enabled = v and true or false; ETBC.ApplyBus:Notify("cooldowns") end,
      },

      whereHeader = { type = "header", name = "Where", order = 5 },

      actionButtons = {
        type = "toggle",
        name = "Action buttons",
        order = 6,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.actionButtons end,
        set = function(_, v) db.actionButtons = v and true or false; ETBC.ApplyBus:Notify("cooldowns") end,
      },

      buffsDebuffs = {
        type = "toggle",
        name = "Buffs / debuffs",
        order = 7,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.buffsDebuffs end,
        set = function(_, v) db.buffsDebuffs = v and true or false; ETBC.ApplyBus:Notify("cooldowns") end,
      },

      otherCooldownFrames = {
        type = "toggle",
        name = "Other cooldown frames (fallback)",
        desc = "Catches most cooldown frames via global hooks.",
        order = 8,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.otherCooldownFrames end,
        set = function(_, v) db.otherCooldownFrames = v and true or false; ETBC.ApplyBus:Notify("cooldowns") end,
      },

      rulesHeader = { type = "header", name = "Rules", order = 15 },

      minDuration = {
        type = "range",
        name = "Minimum duration to show",
        order = 16,
        min = 0.0, max = 20.0, step = 0.1,
        disabled = function() return not db.enabled end,
        get = function() return db.minDuration end,
        set = function(_, v) db.minDuration = v; ETBC.ApplyBus:Notify("cooldowns") end,
      },

      maxDuration = {
        type = "range",
        name = "Maximum duration to show",
        order = 17,
        min = 10, max = 86400, step = 10,
        disabled = function() return not db.enabled end,
        get = function() return db.maxDuration end,
        set = function(_, v) db.maxDuration = v; ETBC.ApplyBus:Notify("cooldowns") end,
      },

      hideWhenGCD = {
        type = "toggle",
        name = "Hide Global Cooldown",
        order = 18,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.hideWhenGCD end,
        set = function(_, v) db.hideWhenGCD = v and true or false; ETBC.ApplyBus:Notify("cooldowns") end,
      },

      showSwipe = {
        type = "toggle",
        name = "Show cooldown swipe",
        desc = "If disabled, the dark swipe overlay is hidden (text remains).",
        order = 19,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.showSwipe end,
        set = function(_, v) db.showSwipe = v and true or false; ETBC.ApplyBus:Notify("cooldowns") end,
      },

      formattingHeader = { type = "header", name = "Formatting", order = 30 },

      mmssThreshold = {
        type = "range",
        name = "Use MM:SS at (seconds)",
        order = 31,
        min = 30, max = 600, step = 5,
        disabled = function() return not db.enabled end,
        get = function() return db.mmssThreshold end,
        set = function(_, v) db.mmssThreshold = v; ETBC.ApplyBus:Notify("cooldowns") end,
      },

      showTenths = {
        type = "toggle",
        name = "Show tenths near ready",
        order = 32,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.showTenths end,
        set = function(_, v) db.showTenths = v and true or false; ETBC.ApplyBus:Notify("cooldowns") end,
      },

      tenthsThreshold = {
        type = "range",
        name = "Tenths threshold (seconds)",
        order = 33,
        min = 0.5, max = 10.0, step = 0.1,
        disabled = function() return not (db.enabled and db.showTenths) end,
        get = function() return db.tenthsThreshold end,
        set = function(_, v) db.tenthsThreshold = v; ETBC.ApplyBus:Notify("cooldowns") end,
      },

      roundUp = {
        type = "toggle",
        name = "Round up seconds",
        desc = "Prevents showing 0s too early.",
        order = 34,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.roundUp end,
        set = function(_, v) db.roundUp = v and true or false; ETBC.ApplyBus:Notify("cooldowns") end,
      },

      styleHeader = { type = "header", name = "Style", order = 40 },

      font = {
        type = "select",
        name = "Font",
        order = 41,
        disabled = function() return not db.enabled end,
        values = LSM_Fonts,
        get = function() return db.font end,
        set = function(_, v) db.font = v; ETBC.ApplyBus:Notify("cooldowns") end,
      },

      size = {
        type = "range",
        name = "Font size",
        order = 42,
        min = 10, max = 30, step = 1,
        disabled = function() return not db.enabled end,
        get = function() return db.size end,
        set = function(_, v) db.size = v; ETBC.ApplyBus:Notify("cooldowns") end,
      },

      outline = {
        type = "select",
        name = "Outline",
        order = 43,
        disabled = function() return not db.enabled end,
        values = function()
          return { [""] = "None", OUTLINE = "Outline", THICKOUTLINE = "Thick" }
        end,
        get = function() return db.outline end,
        set = function(_, v) db.outline = v; ETBC.ApplyBus:Notify("cooldowns") end,
      },

      shadow = {
        type = "toggle",
        name = "Shadow",
        order = 44,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.shadow end,
        set = function(_, v) db.shadow = v and true or false; ETBC.ApplyBus:Notify("cooldowns") end,
      },

      scaleByIcon = {
        type = "toggle",
        name = "Scale by icon size",
        desc = "Auto-scales text smaller on small icons.",
        order = 45,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.scaleByIcon end,
        set = function(_, v) db.scaleByIcon = v and true or false; ETBC.ApplyBus:Notify("cooldowns") end,
      },

      minScale = {
        type = "range",
        name = "Min scale",
        order = 46,
        min = 0.40, max = 1.00, step = 0.01,
        disabled = function() return not (db.enabled and db.scaleByIcon) end,
        get = function() return db.minScale end,
        set = function(_, v) db.minScale = v; ETBC.ApplyBus:Notify("cooldowns") end,
      },

      maxScale = {
        type = "range",
        name = "Max scale",
        order = 47,
        min = 0.80, max = 1.40, step = 0.01,
        disabled = function() return not (db.enabled and db.scaleByIcon) end,
        get = function() return db.maxScale end,
        set = function(_, v) db.maxScale = v; ETBC.ApplyBus:Notify("cooldowns") end,
      },

      colorsHeader = { type = "header", name = "Colors", order = 55 },

      soonThreshold = {
        type = "range",
        name = "Soon threshold",
        order = 56,
        min = 1.0, max = 20.0, step = 0.5,
        disabled = function() return not db.enabled end,
        get = function() return db.soonThreshold end,
        set = function(_, v) db.soonThreshold = v; ETBC.ApplyBus:Notify("cooldowns") end,
      },

      nowThreshold = {
        type = "range",
        name = "Now threshold",
        order = 57,
        min = 0.5, max = 10.0, step = 0.5,
        disabled = function() return not db.enabled end,
        get = function() return db.nowThreshold end,
        set = function(_, v) db.nowThreshold = v; ETBC.ApplyBus:Notify("cooldowns") end,
      },

      colorNormal = {
        type = "color",
        name = "Normal",
        order = 58,
        disabled = function() return not db.enabled end,
        get = function() local c=db.colorNormal; return c[1],c[2],c[3] end,
        set = function(_, r,g,b) db.colorNormal={r,g,b}; ETBC.ApplyBus:Notify("cooldowns") end,
      },

      colorSoon = {
        type = "color",
        name = "Soon",
        order = 59,
        disabled = function() return not db.enabled end,
        get = function() local c=db.colorSoon; return c[1],c[2],c[3] end,
        set = function(_, r,g,b) db.colorSoon={r,g,b}; ETBC.ApplyBus:Notify("cooldowns") end,
      },

      colorNow = {
        type = "color",
        name = "Now",
        order = 60,
        disabled = function() return not db.enabled end,
        get = function() local c=db.colorNow; return c[1],c[2],c[3] end,
        set = function(_, r,g,b) db.colorNow={r,g,b}; ETBC.ApplyBus:Notify("cooldowns") end,
      },

      perfHeader = { type = "header", name = "Performance", order = 70 },

      updateInterval = {
        type = "range",
        name = "Update interval",
        desc = "Lower = smoother, higher = lighter.",
        order = 71,
        min = 0.03, max = 0.25, step = 0.01,
        disabled = function() return not db.enabled end,
        get = function() return db.updateInterval end,
        set = function(_, v) db.updateInterval = v; ETBC.ApplyBus:Notify("cooldowns") end,
      },

      maxTracked = {
        type = "range",
        name = "Max tracked cooldowns",
        order = 72,
        min = 50, max = 800, step = 10,
        disabled = function() return not db.enabled end,
        get = function() return db.maxTracked end,
        set = function(_, v) db.maxTracked = v; ETBC.ApplyBus:Notify("cooldowns") end,
      },
    }
  end,
})

-- Settings/Settings_UnitFrames.lua
-- EnhanceTBC - UnitFrame Micro Enhancer settings (Blizzard frames)

local ADDON_NAME, ETBC = ...
local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceTBC")
local function GetDB()
  ETBC.db.profile.unitframes = ETBC.db.profile.unitframes or {}
  local db = ETBC.db.profile.unitframes

  if db.enabled == nil then db.enabled = true end

  -- Core features
  if db.classColorHealth == nil then db.classColorHealth = true end
  if db.healthPercentText == nil then db.healthPercentText = true end
  if db.powerValueText == nil then db.powerValueText = false end
  if db.hidePortraits == nil then db.hidePortraits = false end

  -- Which frames
  if db.player == nil then db.player = true end
  if db.target == nil then db.target = true end
  if db.focus == nil then db.focus = true end
  if db.party == nil then db.party = false end

  -- Sizing
  if db.resize == nil then db.resize = true end
  if db.scale == nil then db.scale = 1.00 end

  -- Text styling
  if db.font == nil then db.font = "Friz Quadrata TT" end
  if db.fontSize == nil then db.fontSize = 11 end
  if db.outline == nil then db.outline = "OUTLINE" end
  if db.shadow == nil then db.shadow = true end
  if db.textColor == nil then db.textColor = { 1, 1, 1 } end

  -- Misc
  if db.onlyShowTextWhenNotFull == nil then db.onlyShowTextWhenNotFull = true end

  if db.healthTextMode == nil then
    db.healthTextMode = db.healthPercentText and "PERCENT" or "NONE"
  end
  if db.powerTextMode == nil then
    db.powerTextMode = db.powerValueText and "VALUE" or "NONE"
  end

  if db.healthTextOffsetX == nil then db.healthTextOffsetX = 0 end
  if db.healthTextOffsetY == nil then db.healthTextOffsetY = 0 end
  if db.powerTextOffsetX == nil then db.powerTextOffsetX = 0 end
  if db.powerTextOffsetY == nil then db.powerTextOffsetY = 0 end

  if db.disableBlizzardStatusText == nil then db.disableBlizzardStatusText = true end

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

ETBC.SettingsRegistry:RegisterGroup("unitframes", {
  name = "Unit Frames",
  order = 14,
  options = function()
    local db = GetDB()

    return {
      enabled = {
        type = "toggle",
        name = "Enable",
        order = 1,
        width = "full",
        get = function() return db.enabled end,
        set = function(_, v) db.enabled = v and true or false; ETBC.ApplyBus:Notify("unitframes") end,
      },

      framesHeader = { type = "header", name = "Frames", order = 10 },

      player = {
        type = "toggle",
        name = "Player frame",
        order = 11, width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.player end,
        set = function(_, v) db.player = v and true or false; ETBC.ApplyBus:Notify("unitframes") end,
      },
      target = {
        type = "toggle",
        name = "Target frame",
        order = 12, width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.target end,
        set = function(_, v) db.target = v and true or false; ETBC.ApplyBus:Notify("unitframes") end,
      },
      focus = {
        type = "toggle",
        name = "Focus frame",
        order = 13, width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.focus end,
        set = function(_, v) db.focus = v and true or false; ETBC.ApplyBus:Notify("unitframes") end,
      },
      party = {
        type = "toggle",
        name = "Party frames",
        desc = "Applies lightweight text/class-color tweaks to party frames.",
        order = 14, width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.party end,
        set = function(_, v) db.party = v and true or false; ETBC.ApplyBus:Notify("unitframes") end,
      },

      featuresHeader = { type = "header", name = "Features", order = 20 },

      classColorHealth = {
        type = "toggle",
        name = "Class-color health bars (players only)",
        order = 21, width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.classColorHealth end,
        set = function(_, v) db.classColorHealth = v and true or false; ETBC.ApplyBus:Notify("unitframes") end,
      },

      healthPercentText = {
        type = "select",
        name = "Health text",
        desc = "Choose percent, full values, or both.",
        order = 22, width = "full",
        disabled = function() return not db.enabled end,
        values = function() return { NONE = "None", PERCENT = "Percent", VALUE = "Value", BOTH = "Value + Percent" } end,
        get = function() return db.healthTextMode or "PERCENT" end,
        set = function(_, v) db.healthTextMode = v; ETBC.ApplyBus:Notify("unitframes") end,
      },

      powerValueText = {
        type = "select",
        name = "Power text",
        desc = "Shows power as percent, value, or both.",
        order = 23, width = "full",
        disabled = function() return not db.enabled end,
        values = function() return { NONE = "None", PERCENT = "Percent", VALUE = "Value", BOTH = "Value + Percent" } end,
        get = function() return db.powerTextMode or "NONE" end,
        set = function(_, v) db.powerTextMode = v; ETBC.ApplyBus:Notify("unitframes") end,
      },

      hidePortraits = {
        type = "toggle",
        name = "Hide portraits",
        order = 24, width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.hidePortraits end,
        set = function(_, v) db.hidePortraits = v and true or false; ETBC.ApplyBus:Notify("unitframes") end,
      },

      onlyShowTextWhenNotFull = {
        type = "toggle",
        name = "Only show health % when not full",
        order = 25, width = "full",
        disabled = function() return not (db.enabled and db.healthTextMode and db.healthTextMode ~= "NONE") end,
        get = function() return db.onlyShowTextWhenNotFull end,
        set = function(_, v) db.onlyShowTextWhenNotFull = v and true or false; ETBC.ApplyBus:Notify("unitframes") end,
      },

      healthTextOffsetX = {
        type = "range",
        name = "Health text X offset",
        order = 26,
        min = -40, max = 40, step = 1,
        disabled = function() return not (db.enabled and db.healthTextMode and db.healthTextMode ~= "NONE") end,
        get = function() return db.healthTextOffsetX or 0 end,
        set = function(_, v) db.healthTextOffsetX = v; ETBC.ApplyBus:Notify("unitframes") end,
      },

      healthTextOffsetY = {
        type = "range",
        name = "Health text Y offset",
        order = 27,
        min = -40, max = 40, step = 1,
        disabled = function() return not (db.enabled and db.healthTextMode and db.healthTextMode ~= "NONE") end,
        get = function() return db.healthTextOffsetY or 0 end,
        set = function(_, v) db.healthTextOffsetY = v; ETBC.ApplyBus:Notify("unitframes") end,
      },

      powerTextOffsetX = {
        type = "range",
        name = "Power text X offset",
        order = 28,
        min = -40, max = 40, step = 1,
        disabled = function() return not (db.enabled and db.powerTextMode and db.powerTextMode ~= "NONE") end,
        get = function() return db.powerTextOffsetX or 0 end,
        set = function(_, v) db.powerTextOffsetX = v; ETBC.ApplyBus:Notify("unitframes") end,
      },

      powerTextOffsetY = {
        type = "range",
        name = "Power text Y offset",
        order = 29,
        min = -40, max = 40, step = 1,
        disabled = function() return not (db.enabled and db.powerTextMode and db.powerTextMode ~= "NONE") end,
        get = function() return db.powerTextOffsetY or 0 end,
        set = function(_, v) db.powerTextOffsetY = v; ETBC.ApplyBus:Notify("unitframes") end,
      },

      disableBlizzardStatusText = {
        type = "toggle",
        name = "Disable Blizzard status text",
        desc = "Turns off Blizzard unit-frame numbers so only EnhanceTBC text shows.",
        order = 30, width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.disableBlizzardStatusText end,
        set = function(_, v) db.disableBlizzardStatusText = v and true or false; ETBC.ApplyBus:Notify("unitframes") end,
      },

      sizingHeader = { type = "header", name = "Sizing (Player/Target/Focus)", order = 40 },

      resize = {
        type = "toggle",
        name = "Enable sizing tweaks",
        order = 41, width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.resize end,
        set = function(_, v) db.resize = v and true or false; ETBC.ApplyBus:Notify("unitframes") end,
      },

      scale = {
        type = "range",
        name = "Frame scale",
        order = 42,
        min = 0.80, max = 1.40, step = 0.01,
        disabled = function() return not (db.enabled and db.resize) end,
        get = function() return db.scale end,
        set = function(_, v) db.scale = v; ETBC.ApplyBus:Notify("unitframes") end,
      },

      textHeader = { type = "header", name = "Text Style", order = 50 },

      font = {
        type = "select",
        name = "Font",
        order = 51,
        disabled = function() return not db.enabled end,
        values = LSM_Fonts,
        get = function() return db.font end,
        set = function(_, v) db.font = v; ETBC.ApplyBus:Notify("unitframes") end,
      },

      fontSize = {
        type = "range",
        name = "Font size",
        order = 52,
        min = 8, max = 18, step = 1,
        disabled = function() return not db.enabled end,
        get = function() return db.fontSize end,
        set = function(_, v) db.fontSize = v; ETBC.ApplyBus:Notify("unitframes") end,
      },

      outline = {
        type = "select",
        name = "Outline",
        order = 53,
        disabled = function() return not db.enabled end,
        values = function() return { [""] = "None", OUTLINE = "Outline", THICKOUTLINE = "Thick" } end,
        get = function() return db.outline end,
        set = function(_, v) db.outline = v; ETBC.ApplyBus:Notify("unitframes") end,
      },

      shadow = {
        type = "toggle",
        name = "Shadow",
        order = 54, width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.shadow end,
        set = function(_, v) db.shadow = v and true or false; ETBC.ApplyBus:Notify("unitframes") end,
      },

      textColor = {
        type = "color",
        name = "Text color",
        order = 55,
        disabled = function() return not db.enabled end,
        get = function()
          local c = db.textColor or { 1, 1, 1 }
          return c[1], c[2], c[3]
        end,
        set = function(_, r, g, b)
          db.textColor = { r, g, b }
          ETBC.ApplyBus:Notify("unitframes")
        end,
      },
    }
  end,
})

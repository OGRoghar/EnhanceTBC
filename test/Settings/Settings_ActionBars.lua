-- Settings/Settings_ActionBars.lua
-- EnhanceTBC - Actionbar Micro Tweaks (Blizzard bars)

local _, ETBC = ...
local function GetDB()
  ETBC.db.profile.actionbars = ETBC.db.profile.actionbars or {}
  local db = ETBC.db.profile.actionbars

  if db.enabled == nil then db.enabled = true end

  -- Layout
  if db.buttonSize == nil then db.buttonSize = 36 end
  if db.buttonSpacing == nil then db.buttonSpacing = 4 end

  -- Text
  if db.hideMacroText == nil then db.hideMacroText = false end
  if db.hideHotkeys == nil then db.hideHotkeys = false end
  if db.hotkeyFont == nil then db.hotkeyFont = "Friz Quadrata TT" end
  if db.hotkeyFontSize == nil then db.hotkeyFontSize = 11 end
  if db.hotkeyOutline == nil then db.hotkeyOutline = "OUTLINE" end
  if db.hotkeyShadow == nil then db.hotkeyShadow = true end

  -- Fade
  if db.fadeOOC == nil then db.fadeOOC = false end
  if db.oocAlpha == nil then db.oocAlpha = 0.45 end
  if db.combatAlpha == nil then db.combatAlpha = 1.0 end

  if db.fullRangeTint == nil then db.fullRangeTint = true end
  if db.rangeTintMode == nil then
    db.rangeTintMode = db.fullRangeTint and "FULL" or "ICON"
  end
  db.rangeTint = db.rangeTint or {}
  if db.rangeTint.r == nil then db.rangeTint.r = 1.0 end
  if db.rangeTint.g == nil then db.rangeTint.g = 0.15 end
  if db.rangeTint.b == nil then db.rangeTint.b = 0.15 end
  if db.rangeTint.a == nil then db.rangeTint.a = 0.35 end

  -- Which bars
  if db.mainBar == nil then db.mainBar = true end
  if db.multiBars == nil then db.multiBars = true end
  if db.petBar == nil then db.petBar = true end
  if db.stanceBar == nil then db.stanceBar = true end

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

ETBC.SettingsRegistry:RegisterGroup("actionbars", {
  name = "Action Bars",
  order = 16,
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
        set = function(_, v) db.enabled = v and true or false; ETBC.ApplyBus:Notify("actionbars") end,
      },

      barsHeader = { type = "header", name = "Bars", order = 10 },

      mainBar = {
        type = "toggle",
        name = "Main action bar",
        order = 11, width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.mainBar end,
        set = function(_, v) db.mainBar = v and true or false; ETBC.ApplyBus:Notify("actionbars") end,
      },

      multiBars = {
        type = "toggle",
        name = "Multi action bars",
        desc = "BottomLeft, BottomRight, Right, Right2 (if enabled).",
        order = 12, width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.multiBars end,
        set = function(_, v) db.multiBars = v and true or false; ETBC.ApplyBus:Notify("actionbars") end,
      },

      petBar = {
        type = "toggle",
        name = "Pet bar",
        order = 13, width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.petBar end,
        set = function(_, v) db.petBar = v and true or false; ETBC.ApplyBus:Notify("actionbars") end,
      },

      stanceBar = {
        type = "toggle",
        name = "Stance/Shapeshift bar",
        order = 14, width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.stanceBar end,
        set = function(_, v) db.stanceBar = v and true or false; ETBC.ApplyBus:Notify("actionbars") end,
      },

      layoutHeader = { type = "header", name = "Layout", order = 20 },

      buttonSize = {
        type = "range",
        name = "Button size",
        order = 21,
        min = 24, max = 52, step = 1,
        disabled = function() return not db.enabled end,
        get = function() return db.buttonSize end,
        set = function(_, v) db.buttonSize = v; ETBC.ApplyBus:Notify("actionbars") end,
      },

      buttonSpacing = {
        type = "range",
        name = "Button spacing",
        order = 22,
        min = 0, max = 16, step = 1,
        disabled = function() return not db.enabled end,
        get = function() return db.buttonSpacing end,
        set = function(_, v) db.buttonSpacing = v; ETBC.ApplyBus:Notify("actionbars") end,
      },

      textHeader = { type = "header", name = "Text", order = 30 },

      hideMacroText = {
        type = "toggle",
        name = "Hide macro text",
        order = 31, width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.hideMacroText end,
        set = function(_, v) db.hideMacroText = v and true or false; ETBC.ApplyBus:Notify("actionbars") end,
      },

      hideHotkeys = {
        type = "toggle",
        name = "Hide hotkeys",
        order = 32, width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.hideHotkeys end,
        set = function(_, v) db.hideHotkeys = v and true or false; ETBC.ApplyBus:Notify("actionbars") end,
      },

      hotkeyFont = {
        type = "select",
        name = "Hotkey font",
        order = 33,
        disabled = function() return not db.enabled end,
        values = LSM_Fonts,
        get = function() return db.hotkeyFont end,
        set = function(_, v) db.hotkeyFont = v; ETBC.ApplyBus:Notify("actionbars") end,
      },

      hotkeyFontSize = {
        type = "range",
        name = "Hotkey font size",
        order = 34,
        min = 8, max = 18, step = 1,
        disabled = function() return not db.enabled end,
        get = function() return db.hotkeyFontSize end,
        set = function(_, v) db.hotkeyFontSize = v; ETBC.ApplyBus:Notify("actionbars") end,
      },

      hotkeyOutline = {
        type = "select",
        name = "Hotkey outline",
        order = 35,
        disabled = function() return not db.enabled end,
        values = function() return { [""] = "None", OUTLINE = "Outline", THICKOUTLINE = "Thick" } end,
        get = function() return db.hotkeyOutline end,
        set = function(_, v) db.hotkeyOutline = v; ETBC.ApplyBus:Notify("actionbars") end,
      },

      hotkeyShadow = {
        type = "toggle",
        name = "Hotkey shadow",
        order = 36, width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.hotkeyShadow end,
        set = function(_, v) db.hotkeyShadow = v and true or false; ETBC.ApplyBus:Notify("actionbars") end,
      },

      fadeHeader = { type = "header", name = "Fade", order = 40 },

      fadeOOC = {
        type = "toggle",
        name = "Fade out of combat",
        desc = "Out of combat bars fade to a lower alpha. In combat they return to full alpha.",
        order = 41, width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.fadeOOC end,
        set = function(_, v) db.fadeOOC = v and true or false; ETBC.ApplyBus:Notify("actionbars") end,
      },

      oocAlpha = {
        type = "range",
        name = "Out of combat alpha",
        order = 42,
        min = 0.0, max = 1.0, step = 0.01,
        disabled = function() return not (db.enabled and db.fadeOOC) end,
        get = function() return db.oocAlpha end,
        set = function(_, v) db.oocAlpha = v; ETBC.ApplyBus:Notify("actionbars") end,
      },

      combatAlpha = {
        type = "range",
        name = "In combat alpha",
        order = 43,
        min = 0.0, max = 1.0, step = 0.01,
        disabled = function() return not (db.enabled and db.fadeOOC) end,
        get = function() return db.combatAlpha end,
        set = function(_, v) db.combatAlpha = v; ETBC.ApplyBus:Notify("actionbars") end,
      },

      rangeHeader = { type = "header", name = "Range Tint", order = 50 },

      rangeTintMode = {
        type = "select",
        name = "Range tint mode",
        desc = "How out-of-range action buttons are tinted.",
        order = 51,
        disabled = function() return not db.enabled end,
        values = function()
          return {
            FULL = "Full button overlay",
            ICON = "Icon only tint",
          }
        end,
        get = function() return db.rangeTintMode or (db.fullRangeTint and "FULL" or "ICON") end,
        set = function(_, v)
          db.rangeTintMode = v
          db.fullRangeTint = (v == "FULL")
          ETBC.ApplyBus:Notify("actionbars")
        end,
      },

      rangeTintColor = {
        type = "color",
        name = "Range tint color",
        order = 52,
        hasAlpha = true,
        disabled = function() return not db.enabled end,
        get = function()
          local c = db.rangeTint or {}
          return c.r or 1.0, c.g or 0.15, c.b or 0.15, c.a or 0.35
        end,
        set = function(_, r, g, b, a)
          db.rangeTint = db.rangeTint or {}
          db.rangeTint.r = r
          db.rangeTint.g = g
          db.rangeTint.b = b
          db.rangeTint.a = a
          ETBC.ApplyBus:Notify("actionbars")
        end,
      },
    }
  end,
})

-- Settings/Settings_Mouse.lua
-- EnhanceTBC - Mouse options (cursor overlay + trails)

local ADDON_NAME, ETBC = ...

local function EnsureDefaults()
  ETBC.defaults = ETBC.defaults or { profile = {} }
  ETBC.defaults.profile = ETBC.defaults.profile or {}

  ETBC.defaults.profile.mouse = ETBC.defaults.profile.mouse or {
    enabled = true,
    cursor = {
      enabled = false,
      texture = "Glow.tga",
      size = 34,
      alpha = 0.95,
      color = { 0.20, 1.00, 0.20 },
      blend = "ADD",
    },
    trail = {
      enabled = false,
      texture = "Ring Soft 2.tga",
      size = 26,
      alpha = 0.55,
      color = { 0.20, 1.00, 0.20 },
      blend = "ADD",
      spacing = 18,
      life = 0.22,
      maxActive = 32,
      onlyInCombat = false,
      onlyWhenMoving = true,
    },
  }
end

EnsureDefaults()

local CURSOR_TEXTURES = {
  ["Circle 1.tga"] = "Circle 1",
  ["Circle 2.tga"] = "Circle 2",
  ["Cross 1.tga"] = "Cross 1",
  ["Cross 2.tga"] = "Cross 2",
  ["Cross 3.tga"] = "Cross 3",
  ["Glow 1.tga"] = "Glow 1",
  ["Glow.tga"] = "Glow",
  ["Glow Reversed.tga"] = "Glow Reversed",
  ["Ring 1.tga"] = "Ring 1",
  ["Ring 2.tga"] = "Ring 2",
  ["Ring 3.tga"] = "Ring 3",
  ["Ring 4.tga"] = "Ring 4",
  ["Ring Soft 1.tga"] = "Ring Soft 1",
  ["Ring Soft 2.tga"] = "Ring Soft 2",
  ["Ring Soft 3.tga"] = "Ring Soft 3",
  ["Ring Soft 4.tga"] = "Ring Soft 4",
  ["Sphere Edge 2.tga"] = "Sphere Edge 2",
  ["Star 1.tga"] = "Star 1",
  ["Swirl.tga"] = "Swirl",
}

local BLEND_MODES = {
  BLEND = "Blend",
  ADD = "Add (Glow)",
  MOD = "Modulate",
}

local function DB()
  return ETBC.db.profile.mouse
end

local function ApplyMouse()
  if ETBC.Modules and ETBC.Modules.Mouse and ETBC.Modules.Mouse.Apply then
    ETBC.Modules.Mouse:Apply()
    return
  end
  if ETBC.ApplyBus and ETBC.ApplyBus.Notify then
    ETBC.ApplyBus:Notify("mouse")
  elseif ETBC.ApplyBus and ETBC.ApplyBus.NotifyAll then
    ETBC.ApplyBus:NotifyAll()
  end
end

ETBC.SettingsRegistry:RegisterGroup("mouse", {
  name = "Mouse",
  order = 20,
  icon = "Interface\\Icons\\INV_Misc_EngGizmos_17",
  category = "Utility",
  options = function()
    return {
      header = {
        type = "header",
        name = "Mouse Enhancements",
        order = 0,
      },

      enabled = {
        type = "toggle",
        name = "Enable Mouse module",
        order = 1,
        width = "full",
        get = function() return DB().enabled end,
        set = function(_, v) DB().enabled = v and true or false; ApplyMouse() end,
      },

      cursorHeader = {
        type = "header",
        name = "Cursor Overlay",
        order = 10,
      },

      cursorEnabled = {
        type = "toggle",
        name = "Enable cursor overlay",
        desc = "Draws an overlay at your mouse position. (Does not replace the system cursor.)",
        order = 11,
        width = "full",
        get = function() return DB().cursor.enabled end,
        set = function(_, v) DB().cursor.enabled = v and true or false; ApplyMouse() end,
      },

      cursorTexture = {
        type = "select",
        name = "Cursor texture",
        order = 12,
        values = CURSOR_TEXTURES,
        disabled = function() return not DB().cursor.enabled end,
        get = function() return DB().cursor.texture end,
        set = function(_, v) DB().cursor.texture = v; ApplyMouse() end,
      },

      cursorBlend = {
        type = "select",
        name = "Blend mode",
        order = 13,
        values = BLEND_MODES,
        disabled = function() return not DB().cursor.enabled end,
        get = function() return (DB().cursor.blend or "ADD") end,
        set = function(_, v) DB().cursor.blend = v; ApplyMouse() end,
      },

      cursorSize = {
        type = "range",
        name = "Size",
        order = 14,
        min = 12, max = 96, step = 1,
        disabled = function() return not DB().cursor.enabled end,
        get = function() return DB().cursor.size end,
        set = function(_, v) DB().cursor.size = v; ApplyMouse() end,
      },

      cursorAlpha = {
        type = "range",
        name = "Alpha",
        order = 15,
        min = 0.05, max = 1.0, step = 0.01,
        disabled = function() return not DB().cursor.enabled end,
        get = function() return DB().cursor.alpha end,
        set = function(_, v) DB().cursor.alpha = v; ApplyMouse() end,
      },

      cursorColor = {
        type = "color",
        name = "Color",
        order = 16,
        disabled = function() return not DB().cursor.enabled end,
        get = function()
          local c = DB().cursor.color or { 1, 1, 1 }
          return c[1], c[2], c[3]
        end,
        set = function(_, r, g, b)
          DB().cursor.color = { r, g, b }
          ApplyMouse()
        end,
      },

      trailHeader = {
        type = "header",
        name = "Cursor Trails",
        order = 30,
      },

      trailEnabled = {
        type = "toggle",
        name = "Enable trails",
        desc = "Spawns a continuous trail behind your cursor using the selected texture. Lightweight pooled textures.",
        order = 31,
        width = "full",
        get = function() return DB().trail.enabled end,
        set = function(_, v) DB().trail.enabled = v and true or false; ApplyMouse() end,
      },

      trailOnlyInCombat = {
        type = "toggle",
        name = "Only in combat",
        order = 32,
        disabled = function() return not DB().trail.enabled end,
        get = function() return DB().trail.onlyInCombat end,
        set = function(_, v) DB().trail.onlyInCombat = v and true or false; ApplyMouse() end,
      },

      trailOnlyWhenMoving = {
        type = "toggle",
        name = "Only when moving mouse",
        desc = "Spawns trail textures based on cursor distance moved.",
        order = 33,
        disabled = function() return not DB().trail.enabled end,
        get = function() return DB().trail.onlyWhenMoving end,
        set = function(_, v) DB().trail.onlyWhenMoving = v and true or false; ApplyMouse() end,
      },

      trailTexture = {
        type = "select",
        name = "Trail texture",
        order = 34,
        values = CURSOR_TEXTURES,
        disabled = function() return not DB().trail.enabled end,
        get = function() return DB().trail.texture end,
        set = function(_, v) DB().trail.texture = v; ApplyMouse() end,
      },

      trailBlend = {
        type = "select",
        name = "Blend mode",
        order = 35,
        values = BLEND_MODES,
        disabled = function() return not DB().trail.enabled end,
        get = function() return (DB().trail.blend or "ADD") end,
        set = function(_, v) DB().trail.blend = v; ApplyMouse() end,
      },

      trailSize = {
        type = "range",
        name = "Trail size",
        order = 36,
        min = 8, max = 96, step = 1,
        disabled = function() return not DB().trail.enabled end,
        get = function() return DB().trail.size end,
        set = function(_, v) DB().trail.size = v; ApplyMouse() end,
      },

      trailAlpha = {
        type = "range",
        name = "Trail alpha",
        order = 37,
        min = 0.03, max = 1.0, step = 0.01,
        disabled = function() return not DB().trail.enabled end,
        get = function() return DB().trail.alpha end,
        set = function(_, v) DB().trail.alpha = v; ApplyMouse() end,
      },

      trailLife = {
        type = "range",
        name = "Life (seconds)",
        order = 38,
        min = 0.05, max = 1.00, step = 0.01,
        disabled = function() return not DB().trail.enabled end,
        get = function() return DB().trail.life end,
        set = function(_, v) DB().trail.life = v; ApplyMouse() end,
      },

      trailSpacing = {
        type = "range",
        name = "Spacing (pixels)",
        desc = "Lower = denser trail. Higher = fewer spawns (better performance).",
        order = 39,
        min = 6, max = 64, step = 1,
        disabled = function() return not DB().trail.enabled end,
        get = function() return DB().trail.spacing end,
        set = function(_, v) DB().trail.spacing = v; ApplyMouse() end,
      },

      trailMax = {
        type = "range",
        name = "Max active pieces",
        desc = "Hard cap to keep performance stable.",
        order = 40,
        min = 8, max = 96, step = 1,
        disabled = function() return not DB().trail.enabled end,
        get = function() return DB().trail.maxActive end,
        set = function(_, v) DB().trail.maxActive = v; ApplyMouse() end,
      },

      trailColor = {
        type = "color",
        name = "Trail color",
        order = 41,
        disabled = function() return not DB().trail.enabled end,
        get = function()
          local c = DB().trail.color or { 1, 1, 1 }
          return c[1], c[2], c[3]
        end,
        set = function(_, r, g, b)
          DB().trail.color = { r, g, b }
          ApplyMouse()
        end,
      },
    }
  end,
})

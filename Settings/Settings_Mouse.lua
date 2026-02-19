-- Settings/Settings_Mouse.lua
-- EnhanceTBC - CursorTrail-style options (2D cursor + trail)

local _, ETBC = ...

local function EnsureDB()
  if not ETBC.db or not ETBC.db.profile then
    return ETBC.defaults and ETBC.defaults.profile and ETBC.defaults.profile.mouse or {}
  end

  ETBC.db.profile.mouse = ETBC.db.profile.mouse or {}
  local db = ETBC.db.profile.mouse

  if db.enabled == nil then db.enabled = true end

  if db.cursorEnabled == nil then db.cursorEnabled = true end
  if db.cursorTexture == nil then db.cursorTexture = "Glow.tga" end
  if db.cursorCustomTexture == nil then db.cursorCustomTexture = "" end
  if db.cursorSize == nil then db.cursorSize = 32 end
  if db.cursorAlpha == nil then db.cursorAlpha = 0.9 end
  if db.cursorBlend == nil then db.cursorBlend = "ADD" end
  if db.cursorColor == nil then db.cursorColor = { 0.2, 1.0, 0.2 } end

  db.trail = db.trail or {}
  if db.trail.enabled == nil then db.trail.enabled = true end
  if db.trail.texture == nil then db.trail.texture = "Ring Soft 2.tga" end
  if db.trail.customTexture == nil then db.trail.customTexture = "" end
  if db.trail.size == nil then db.trail.size = 24 end
  if db.trail.alpha == nil then db.trail.alpha = 0.5 end
  if db.trail.blend == nil then db.trail.blend = "ADD" end
  if db.trail.color == nil then db.trail.color = { 0.2, 1.0, 0.2 } end
  if db.trail.spacing == nil then db.trail.spacing = 16 end
  if db.trail.life == nil then db.trail.life = 0.25 end
  if db.trail.maxActive == nil then db.trail.maxActive = 30 end
  if db.trail.onlyWhenMoving == nil then db.trail.onlyWhenMoving = true end

  if db.hideWhenIdle == nil then db.hideWhenIdle = false end
  if db.idleDelay == nil then db.idleDelay = 1.0 end

  return db
end

local function DB() return EnsureDB() end

local function EnsureDefaults()
  EnsureDB()
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

ETBC.SettingsRegistry:RegisterGroup("mouse", {
  name = "Mouse",
  order = 20,
  icon = "Interface\\Icons\\INV_Misc_EngGizmos_17",
  category = "Utility",
  options = function()
    EnsureDefaults()
    return {
      header = { type = "header", name = "CursorTrail", order = 0 },

      enabled = {
        type = "toggle",
        name = "Enable CursorTrail",
        order = 1,
        width = "full",
        get = function() return DB().enabled end,
        set = function(_, v) DB().enabled = v and true or false; ApplyMouse() end,
      },

      cursorHeader = { type = "header", name = "Cursor", order = 10 },

      cursorEnabled = {
        type = "toggle",
        name = "Show cursor",
        order = 11,
        width = "full",
        disabled = function() return not DB().enabled end,
        get = function() return DB().cursorEnabled end,
        set = function(_, v) DB().cursorEnabled = v and true or false; ApplyMouse() end,
      },

      cursorTexture = {
        type = "select",
        name = "Cursor texture",
        order = 12,
        values = CURSOR_TEXTURES,
        disabled = function() return not (DB().enabled and DB().cursorEnabled) end,
        get = function() return DB().cursorTexture end,
        set = function(_, v) DB().cursorTexture = v; ApplyMouse() end,
      },

      cursorCustomTexture = {
        type = "input",
        name = "Cursor custom texture path",
        desc = "Optional. Full texture path overrides the selected texture.",
        order = 12.5,
        width = "full",
        disabled = function() return not (DB().enabled and DB().cursorEnabled) end,
        get = function() return DB().cursorCustomTexture end,
        set = function(_, v) DB().cursorCustomTexture = v; ApplyMouse() end,
      },

      cursorSize = {
        type = "range",
        name = "Cursor size",
        order = 13,
        min = 12, max = 96, step = 1,
        disabled = function() return not (DB().enabled and DB().cursorEnabled) end,
        get = function() return DB().cursorSize end,
        set = function(_, v) DB().cursorSize = v; ApplyMouse() end,
      },

      cursorAlpha = {
        type = "range",
        name = "Cursor alpha",
        order = 14,
        min = 0.05, max = 1.0, step = 0.01,
        disabled = function() return not (DB().enabled and DB().cursorEnabled) end,
        get = function() return DB().cursorAlpha end,
        set = function(_, v) DB().cursorAlpha = v; ApplyMouse() end,
      },

      cursorBlend = {
        type = "select",
        name = "Cursor blend",
        order = 15,
        values = BLEND_MODES,
        disabled = function() return not (DB().enabled and DB().cursorEnabled) end,
        get = function() return DB().cursorBlend end,
        set = function(_, v) DB().cursorBlend = v; ApplyMouse() end,
      },

      cursorColor = {
        type = "color",
        name = "Cursor color",
        order = 16,
        hasAlpha = false,
        disabled = function() return not (DB().enabled and DB().cursorEnabled) end,
        get = function()
          local c = DB().cursorColor
          return c[1], c[2], c[3]
        end,
        set = function(_, r, g, b)
          DB().cursorColor = { r, g, b }
          ApplyMouse()
        end,
      },

      trailHeader = { type = "header", name = "Trail", order = 30 },

      trailEnabled = {
        type = "toggle",
        name = "Show trail",
        order = 31,
        width = "full",
        disabled = function() return not DB().enabled end,
        get = function() return DB().trail.enabled end,
        set = function(_, v) DB().trail.enabled = v and true or false; ApplyMouse() end,
      },

      trailTexture = {
        type = "select",
        name = "Trail texture",
        order = 32,
        values = CURSOR_TEXTURES,
        disabled = function() return not (DB().enabled and DB().trail.enabled) end,
        get = function() return DB().trail.texture end,
        set = function(_, v) DB().trail.texture = v; ApplyMouse() end,
      },

      trailCustomTexture = {
        type = "input",
        name = "Trail custom texture path",
        desc = "Optional. Full texture path overrides the selected texture.",
        order = 32.5,
        width = "full",
        disabled = function() return not (DB().enabled and DB().trail.enabled) end,
        get = function() return DB().trail.customTexture end,
        set = function(_, v) DB().trail.customTexture = v; ApplyMouse() end,
      },

      trailSize = {
        type = "range",
        name = "Trail size",
        order = 33,
        min = 8, max = 96, step = 1,
        disabled = function() return not (DB().enabled and DB().trail.enabled) end,
        get = function() return DB().trail.size end,
        set = function(_, v) DB().trail.size = v; ApplyMouse() end,
      },

      trailAlpha = {
        type = "range",
        name = "Trail alpha",
        order = 34,
        min = 0.05, max = 1.0, step = 0.01,
        disabled = function() return not (DB().enabled and DB().trail.enabled) end,
        get = function() return DB().trail.alpha end,
        set = function(_, v) DB().trail.alpha = v; ApplyMouse() end,
      },

      trailBlend = {
        type = "select",
        name = "Trail blend",
        order = 35,
        values = BLEND_MODES,
        disabled = function() return not (DB().enabled and DB().trail.enabled) end,
        get = function() return DB().trail.blend end,
        set = function(_, v) DB().trail.blend = v; ApplyMouse() end,
      },

      trailColor = {
        type = "color",
        name = "Trail color",
        order = 36,
        hasAlpha = false,
        disabled = function() return not (DB().enabled and DB().trail.enabled) end,
        get = function()
          local c = DB().trail.color
          return c[1], c[2], c[3]
        end,
        set = function(_, r, g, b)
          DB().trail.color = { r, g, b }
          ApplyMouse()
        end,
      },

      trailSpacing = {
        type = "range",
        name = "Trail spacing",
        order = 37,
        min = 4, max = 60, step = 1,
        disabled = function() return not (DB().enabled and DB().trail.enabled) end,
        get = function() return DB().trail.spacing end,
        set = function(_, v) DB().trail.spacing = v; ApplyMouse() end,
      },

      trailLife = {
        type = "range",
        name = "Trail duration",
        order = 38,
        min = 0.05, max = 1.5, step = 0.01,
        disabled = function() return not (DB().enabled and DB().trail.enabled) end,
        get = function() return DB().trail.life end,
        set = function(_, v) DB().trail.life = v; ApplyMouse() end,
      },

      trailMax = {
        type = "range",
        name = "Max trail segments",
        order = 39,
        min = 5, max = 120, step = 1,
        disabled = function() return not (DB().enabled and DB().trail.enabled) end,
        get = function() return DB().trail.maxActive end,
        set = function(_, v) DB().trail.maxActive = v; ApplyMouse() end,
      },

      trailOnlyWhenMoving = {
        type = "toggle",
        name = "Trail only when moving",
        order = 40,
        width = "full",
        disabled = function() return not (DB().enabled and DB().trail.enabled) end,
        get = function() return DB().trail.onlyWhenMoving end,
        set = function(_, v) DB().trail.onlyWhenMoving = v and true or false; ApplyMouse() end,
      },

      behaviorHeader = { type = "header", name = "Behavior", order = 50 },

      hideWhenIdle = {
        type = "toggle",
        name = "Hide when idle",
        order = 51,
        width = "full",
        disabled = function() return not DB().enabled end,
        get = function() return DB().hideWhenIdle end,
        set = function(_, v) DB().hideWhenIdle = v and true or false; ApplyMouse() end,
      },

      idleDelay = {
        type = "range",
        name = "Idle delay",
        order = 52,
        min = 0.1, max = 5.0, step = 0.1,
        disabled = function() return not (DB().enabled and DB().hideWhenIdle) end,
        get = function() return DB().idleDelay end,
        set = function(_, v) DB().idleDelay = v; ApplyMouse() end,
      },
    }
  end,
})

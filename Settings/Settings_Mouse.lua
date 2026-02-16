-- Settings/Settings_Mouse.lua
-- EnhanceTBC - Mouse options (cursor overlay + trails) + Spell Model cursor/trail (GAME internal paths)
-- Includes camera tuning to reduce "boxy" PlayerModel look.

local ADDON_NAME, ETBC = ...

local function EnsureDB()
  if not ETBC.db or not ETBC.db.profile then
    return ETBC.defaults and ETBC.defaults.profile and ETBC.defaults.profile.mouse or {}
  end

  ETBC.db.profile.mouse = ETBC.db.profile.mouse or {}
  local db = ETBC.db.profile.mouse

  if db.enabled == nil then db.enabled = true end
  if db.effectType == nil then db.effectType = "texture" end -- texture|model|both
  if db.debugModels == nil then db.debugModels = false end
  if db.spellKey == nil then db.spellKey = "LightningBolt" end

  db.model = db.model or {}
  if db.model.enabled == nil then db.model.enabled = false end
  if db.model.size == nil then db.model.size = 96 end
  if db.model.alpha == nil then db.model.alpha = 1.0 end
  if db.model.scale == nil then db.model.scale = 0.02 end
  if db.model.facing == nil then db.model.facing = 0 end
  if db.model.spin == nil then db.model.spin = 0 end
  if db.model.offsetX == nil then db.model.offsetX = 0 end
  if db.model.offsetY == nil then db.model.offsetY = 0 end
  if db.model.onlyInCombat == nil then db.model.onlyInCombat = false end
  if db.model.camDistance == nil then db.model.camDistance = 1.0 end
  if db.model.portraitZoom == nil then db.model.portraitZoom = 0 end
  if db.model.posZ == nil then db.model.posZ = 0 end

  db.modelTrail = db.modelTrail or {}
  if db.modelTrail.enabled == nil then db.modelTrail.enabled = false end
  if db.modelTrail.size == nil then db.modelTrail.size = 72 end
  if db.modelTrail.alpha == nil then db.modelTrail.alpha = 0.95 end
  if db.modelTrail.scale == nil then db.modelTrail.scale = 0.02 end
  if db.modelTrail.spacing == nil then db.modelTrail.spacing = 20 end
  if db.modelTrail.life == nil then db.modelTrail.life = 0.30 end
  if db.modelTrail.maxActive == nil then db.modelTrail.maxActive = 12 end
  if db.modelTrail.onlyInCombat == nil then db.modelTrail.onlyInCombat = false end
  if db.modelTrail.onlyWhenMoving == nil then db.modelTrail.onlyWhenMoving = true end
  if db.modelTrail.spin == nil then db.modelTrail.spin = 0 end
  if db.modelTrail.facing == nil then db.modelTrail.facing = 0 end
  if db.modelTrail.camDistance == nil then db.modelTrail.camDistance = 1.0 end
  if db.modelTrail.portraitZoom == nil then db.modelTrail.portraitZoom = 0 end
  if db.modelTrail.posZ == nil then db.modelTrail.posZ = 0 end

  db.cursor = db.cursor or {}
  if db.cursor.enabled == nil then db.cursor.enabled = false end
  if db.cursor.texture == nil then db.cursor.texture = "Glow.tga" end
  if db.cursor.size == nil then db.cursor.size = 34 end
  if db.cursor.alpha == nil then db.cursor.alpha = 0.95 end
  if db.cursor.color == nil then db.cursor.color = { 0.20, 1.00, 0.20 } end
  if db.cursor.blend == nil then db.cursor.blend = "ADD" end

  db.trail = db.trail or {}
  if db.trail.enabled == nil then db.trail.enabled = false end
  if db.trail.texture == nil then db.trail.texture = "Ring Soft 2.tga" end
  if db.trail.size == nil then db.trail.size = 26 end
  if db.trail.alpha == nil then db.trail.alpha = 0.55 end
  if db.trail.color == nil then db.trail.color = { 0.20, 1.00, 0.20 } end
  if db.trail.blend == nil then db.trail.blend = "ADD" end
  if db.trail.spacing == nil then db.trail.spacing = 18 end
  if db.trail.life == nil then db.trail.life = 0.22 end
  if db.trail.maxActive == nil then db.trail.maxActive = 32 end
  if db.trail.onlyInCombat == nil then db.trail.onlyInCombat = false end
  if db.trail.onlyWhenMoving == nil then db.trail.onlyWhenMoving = true end

  return db
end

local function DB() return EnsureDB() end

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

local SPELL_VALUES = {
  Holy = "Holy",
  ShadowBolt = "ShadowBolt",
  LightningBolt = "LightningBolt",
  Fireball = "Fireball",
}

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
    return {
      header = { type = "header", name = "Mouse Enhancements", order = 0 },

      enabled = {
        type = "toggle",
        name = "Enable Mouse module",
        order = 1,
        width = "full",
        get = function() return DB().enabled end,
        set = function(_, v) DB().enabled = v and true or false; ApplyMouse() end,
      },

      effectType = {
        type = "select",
        name = "Effect Type",
        order = 2,
        width = "full",
        values = {
          texture = "Textures (overlay + trails)",
          model   = "Spell Models (cursor / trail)",
          both    = "Both (heavier)",
        },
        get = function() return DB().effectType or "texture" end,
        set = function(_, v) DB().effectType = v; ApplyMouse() end,
      },

      spellKey = {
        type = "select",
        name = "Spell effect (3D)",
        order = 3,
        width = "full",
        values = SPELL_VALUES,
        get = function() return DB().spellKey or "LightningBolt" end,
        set = function(_, v) DB().spellKey = v; ApplyMouse() end,
      },

      debugModels = {
        type = "toggle",
        name = "Debug model loading",
        desc = "Prints a message if the selected spell model path fails to load on your client.",
        order = 4,
        width = "full",
        get = function() return DB().debugModels and true or false end,
        set = function(_, v) DB().debugModels = v and true or false; ApplyMouse() end,
      },

      -- =========================
      -- 3D MODEL CURSOR (single)
      -- =========================
      modelHeader = { type = "header", name = "Spell Model Cursor (single)", order = 10 },

      modelEnabled = {
        type = "toggle",
        name = "Enable cursor model (single)",
        desc = "One model follows your cursor (heavier than textures).",
        order = 11,
        width = "full",
        get = function() return DB().model.enabled end,
        set = function(_, v) DB().model.enabled = v and true or false; ApplyMouse() end,
      },

      modelOnlyInCombat = {
        type = "toggle",
        name = "Only in combat",
        order = 12,
        disabled = function() return not DB().model.enabled end,
        get = function() return DB().model.onlyInCombat end,
        set = function(_, v) DB().model.onlyInCombat = v and true or false; ApplyMouse() end,
      },

      modelSize = {
        type = "range",
        name = "Frame size",
        order = 13,
        min = 32, max = 256, step = 1,
        disabled = function() return not DB().model.enabled end,
        get = function() return DB().model.size end,
        set = function(_, v) DB().model.size = v; ApplyMouse() end,
      },

      modelAlpha = {
        type = "range",
        name = "Alpha",
        order = 14,
        min = 0.05, max = 1.0, step = 0.01,
        disabled = function() return not DB().model.enabled end,
        get = function() return DB().model.alpha end,
        set = function(_, v) DB().model.alpha = v; ApplyMouse() end,
      },

      modelScale = {
        type = "range",
        name = "Model scale",
        desc = "Controls how large the 3D model appears inside the frame.",
        order = 15,
        min = 0.001, max = 0.25, step = 0.001,
        disabled = function() return not DB().model.enabled end,
        get = function() return DB().model.scale end,
        set = function(_, v) DB().model.scale = v; ApplyMouse() end,
      },

      modelFacing = {
        type = "range",
        name = "Facing (degrees)",
        order = 16,
        min = -180, max = 180, step = 1,
        disabled = function() return not DB().model.enabled end,
        get = function() return DB().model.facing end,
        set = function(_, v) DB().model.facing = v; ApplyMouse() end,
      },

      modelSpin = {
        type = "range",
        name = "Spin speed (deg/sec)",
        desc = "0 = no spin. Positive/negative spins over time.",
        order = 17,
        min = -720, max = 720, step = 5,
        disabled = function() return not DB().model.enabled end,
        get = function() return DB().model.spin end,
        set = function(_, v) DB().model.spin = v; ApplyMouse() end,
      },

      modelOffsetX = {
        type = "range",
        name = "Offset X",
        order = 18,
        min = -200, max = 200, step = 1,
        disabled = function() return not DB().model.enabled end,
        get = function() return DB().model.offsetX end,
        set = function(_, v) DB().model.offsetX = v; ApplyMouse() end,
      },

      modelOffsetY = {
        type = "range",
        name = "Offset Y",
        order = 19,
        min = -200, max = 200, step = 1,
        disabled = function() return not DB().model.enabled end,
        get = function() return DB().model.offsetY end,
        set = function(_, v) DB().model.offsetY = v; ApplyMouse() end,
      },

      modelCamDistance = {
        type = "range",
        name = "Camera distance",
        desc = "Lower can reduce the boxy look by filling the frame better.",
        order = 20,
        min = 0.10, max = 3.00, step = 0.01,
        disabled = function() return not DB().model.enabled end,
        get = function() return DB().model.camDistance or 1.0 end,
        set = function(_, v) DB().model.camDistance = v; ApplyMouse() end,
      },

      modelPortraitZoom = {
        type = "range",
        name = "Portrait zoom",
        order = 21,
        min = 0.00, max = 1.00, step = 0.01,
        disabled = function() return not DB().model.enabled end,
        get = function() return DB().model.portraitZoom or 0 end,
        set = function(_, v) DB().model.portraitZoom = v; ApplyMouse() end,
      },

      modelPosZ = {
        type = "range",
        name = "Model Z position",
        desc = "Moves the model toward/away from the camera in some builds.",
        order = 22,
        min = -5.0, max = 5.0, step = 0.05,
        disabled = function() return not DB().model.enabled end,
        get = function() return DB().model.posZ or 0 end,
        set = function(_, v) DB().model.posZ = v; ApplyMouse() end,
      },

      -- =========================
      -- 3D MODEL TRAIL (pooled)
      -- =========================
      modelTrailHeader = { type = "header", name = "Spell Model Trail", order = 30 },

      modelTrailEnabled = {
        type = "toggle",
        name = "Enable model trail",
        desc = "Drops short-lived models along your cursor path (pooled).",
        order = 31,
        width = "full",
        get = function() return DB().modelTrail.enabled end,
        set = function(_, v) DB().modelTrail.enabled = v and true or false; ApplyMouse() end,
      },

      modelTrailOnlyInCombat = {
        type = "toggle",
        name = "Only in combat",
        order = 32,
        disabled = function() return not DB().modelTrail.enabled end,
        get = function() return DB().modelTrail.onlyInCombat end,
        set = function(_, v) DB().modelTrail.onlyInCombat = v and true or false; ApplyMouse() end,
      },

      modelTrailOnlyWhenMoving = {
        type = "toggle",
        name = "Only when moving mouse",
        order = 33,
        disabled = function() return not DB().modelTrail.enabled end,
        get = function() return DB().modelTrail.onlyWhenMoving end,
        set = function(_, v) DB().modelTrail.onlyWhenMoving = v and true or false; ApplyMouse() end,
      },

      modelTrailSize = {
        type = "range",
        name = "Trail frame size",
        order = 34,
        min = 24, max = 192, step = 1,
        disabled = function() return not DB().modelTrail.enabled end,
        get = function() return DB().modelTrail.size end,
        set = function(_, v) DB().modelTrail.size = v; ApplyMouse() end,
      },

      modelTrailAlpha = {
        type = "range",
        name = "Trail alpha",
        order = 35,
        min = 0.05, max = 1.0, step = 0.01,
        disabled = function() return not DB().modelTrail.enabled end,
        get = function() return DB().modelTrail.alpha end,
        set = function(_, v) DB().modelTrail.alpha = v; ApplyMouse() end,
      },

      modelTrailScale = {
        type = "range",
        name = "Trail model scale",
        order = 36,
        min = 0.001, max = 0.25, step = 0.001,
        disabled = function() return not DB().modelTrail.enabled end,
        get = function() return DB().modelTrail.scale end,
        set = function(_, v) DB().modelTrail.scale = v; ApplyMouse() end,
      },

      modelTrailLife = {
        type = "range",
        name = "Life (seconds)",
        order = 37,
        min = 0.05, max = 1.50, step = 0.01,
        disabled = function() return not DB().modelTrail.enabled end,
        get = function() return DB().modelTrail.life end,
        set = function(_, v) DB().modelTrail.life = v; ApplyMouse() end,
      },

      modelTrailSpacing = {
        type = "range",
        name = "Spacing (pixels)",
        desc = "Distance between spawns. Higher = fewer models (better performance).",
        order = 38,
        min = 4, max = 80, step = 1,
        disabled = function() return not DB().modelTrail.enabled end,
        get = function() return DB().modelTrail.spacing end,
        set = function(_, v) DB().modelTrail.spacing = v; ApplyMouse() end,
      },

      modelTrailMax = {
        type = "range",
        name = "Max active models",
        desc = "Hard cap for performance stability.",
        order = 39,
        min = 2, max = 40, step = 1,
        disabled = function() return not DB().modelTrail.enabled end,
        get = function() return DB().modelTrail.maxActive end,
        set = function(_, v) DB().modelTrail.maxActive = v; ApplyMouse() end,
      },

      modelTrailFacing = {
        type = "range",
        name = "Facing (degrees)",
        order = 40,
        min = -180, max = 180, step = 1,
        disabled = function() return not DB().modelTrail.enabled end,
        get = function() return DB().modelTrail.facing end,
        set = function(_, v) DB().modelTrail.facing = v; ApplyMouse() end,
      },

      modelTrailSpin = {
        type = "range",
        name = "Spin speed (deg/sec)",
        order = 41,
        min = -720, max = 720, step = 5,
        disabled = function() return not DB().modelTrail.enabled end,
        get = function() return DB().modelTrail.spin end,
        set = function(_, v) DB().modelTrail.spin = v; ApplyMouse() end,
      },

      modelTrailCamDistance = {
        type = "range",
        name = "Trail camera distance",
        order = 42,
        min = 0.10, max = 3.00, step = 0.01,
        disabled = function() return not DB().modelTrail.enabled end,
        get = function() return DB().modelTrail.camDistance or 1.0 end,
        set = function(_, v) DB().modelTrail.camDistance = v; ApplyMouse() end,
      },

      modelTrailPortraitZoom = {
        type = "range",
        name = "Trail portrait zoom",
        order = 43,
        min = 0.00, max = 1.00, step = 0.01,
        disabled = function() return not DB().modelTrail.enabled end,
        get = function() return DB().modelTrail.portraitZoom or 0 end,
        set = function(_, v) DB().modelTrail.portraitZoom = v; ApplyMouse() end,
      },

      modelTrailPosZ = {
        type = "range",
        name = "Trail model Z position",
        order = 44,
        min = -5.0, max = 5.0, step = 0.05,
        disabled = function() return not DB().modelTrail.enabled end,
        get = function() return DB().modelTrail.posZ or 0 end,
        set = function(_, v) DB().modelTrail.posZ = v; ApplyMouse() end,
      },

      -- =========================
      -- 2D CURSOR OVERLAY
      -- =========================
      cursorHeader = { type = "header", name = "Cursor Overlay (2D)", order = 60 },

      cursorEnabled = {
        type = "toggle",
        name = "Enable cursor overlay",
        desc = "Draws an overlay at your mouse position (does not replace the system cursor).",
        order = 61,
        width = "full",
        get = function() return DB().cursor.enabled end,
        set = function(_, v) DB().cursor.enabled = v and true or false; ApplyMouse() end,
      },

      cursorTexture = {
        type = "select",
        name = "Cursor texture",
        order = 62,
        values = CURSOR_TEXTURES,
        disabled = function() return not DB().cursor.enabled end,
        get = function() return DB().cursor.texture end,
        set = function(_, v) DB().cursor.texture = v; ApplyMouse() end,
      },

      cursorBlend = {
        type = "select",
        name = "Blend mode",
        order = 63,
        values = BLEND_MODES,
        disabled = function() return not DB().cursor.enabled end,
        get = function() return DB().cursor.blend or "ADD" end,
        set = function(_, v) DB().cursor.blend = v; ApplyMouse() end,
      },

      cursorSize = {
        type = "range",
        name = "Size",
        order = 64,
        min = 12, max = 96, step = 1,
        disabled = function() return not DB().cursor.enabled end,
        get = function() return DB().cursor.size end,
        set = function(_, v) DB().cursor.size = v; ApplyMouse() end,
      },

      cursorAlpha = {
        type = "range",
        name = "Alpha",
        order = 65,
        min = 0.05, max = 1.0, step = 0.01,
        disabled = function() return not DB().cursor.enabled end,
        get = function() return DB().cursor.alpha end,
        set = function(_, v) DB().cursor.alpha = v; ApplyMouse() end,
      },

      cursorColor = {
        type = "color",
        name = "Color",
        order = 66,
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

      -- =========================
      -- 2D TRAILS
      -- =========================
      trailHeader = { type = "header", name = "Cursor Trails (2D)", order = 80 },

      trailEnabled = {
        type = "toggle",
        name = "Enable trails",
        desc = "Spawns a continuous trail behind your cursor using the selected texture.",
        order = 81,
        width = "full",
        get = function() return DB().trail.enabled end,
        set = function(_, v) DB().trail.enabled = v and true or false; ApplyMouse() end,
      },

      trailOnlyInCombat = {
        type = "toggle",
        name = "Only in combat",
        order = 82,
        disabled = function() return not DB().trail.enabled end,
        get = function() return DB().trail.onlyInCombat end,
        set = function(_, v) DB().trail.onlyInCombat = v and true or false; ApplyMouse() end,
      },

      trailOnlyWhenMoving = {
        type = "toggle",
        name = "Only when moving mouse",
        desc = "Spawns trail textures based on cursor distance moved.",
        order = 83,
        disabled = function() return not DB().trail.enabled end,
        get = function() return DB().trail.onlyWhenMoving end,
        set = function(_, v) DB().trail.onlyWhenMoving = v and true or false; ApplyMouse() end,
      },

      trailTexture = {
        type = "select",
        name = "Trail texture",
        order = 84,
        values = CURSOR_TEXTURES,
        disabled = function() return not DB().trail.enabled end,
        get = function() return DB().trail.texture end,
        set = function(_, v) DB().trail.texture = v; ApplyMouse() end,
      },

      trailBlend = {
        type = "select",
        name = "Blend mode",
        order = 85,
        values = BLEND_MODES,
        disabled = function() return not DB().trail.enabled end,
        get = function() return DB().trail.blend or "ADD" end,
        set = function(_, v) DB().trail.blend = v; ApplyMouse() end,
      },

      trailSize = {
        type = "range",
        name = "Trail size",
        order = 86,
        min = 8, max = 96, step = 1,
        disabled = function() return not DB().trail.enabled end,
        get = function() return DB().trail.size end,
        set = function(_, v) DB().trail.size = v; ApplyMouse() end,
      },

      trailAlpha = {
        type = "range",
        name = "Trail alpha",
        order = 87,
        min = 0.03, max = 1.0, step = 0.01,
        disabled = function() return not DB().trail.enabled end,
        get = function() return DB().trail.alpha end,
        set = function(_, v) DB().trail.alpha = v; ApplyMouse() end,
      },

      trailLife = {
        type = "range",
        name = "Life (seconds)",
        order = 88,
        min = 0.05, max = 1.00, step = 0.01,
        disabled = function() return not DB().trail.enabled end,
        get = function() return DB().trail.life end,
        set = function(_, v) DB().trail.life = v; ApplyMouse() end,
      },

      trailSpacing = {
        type = "range",
        name = "Spacing (pixels)",
        desc = "Lower = denser trail. Higher = fewer spawns (better performance).",
        order = 89,
        min = 6, max = 64, step = 1,
        disabled = function() return not DB().trail.enabled end,
        get = function() return DB().trail.spacing end,
        set = function(_, v) DB().trail.spacing = v; ApplyMouse() end,
      },

      trailMax = {
        type = "range",
        name = "Max active pieces",
        desc = "Hard cap to keep performance stable.",
        order = 90,
        min = 8, max = 96, step = 1,
        disabled = function() return not DB().trail.enabled end,
        get = function() return DB().trail.maxActive end,
        set = function(_, v) DB().trail.maxActive = v; ApplyMouse() end,
      },

      trailColor = {
        type = "color",
        name = "Trail color",
        order = 91,
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
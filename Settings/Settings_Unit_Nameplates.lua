-- Settings/Settings_Unit_Nameplates.lua
-- EnhanceTBC - Unit nameplate settings

local _, ETBC = ...

local function GetDB()
  ETBC.db.profile.nameplates = ETBC.db.profile.nameplates or {}
  local db = ETBC.db.profile.nameplates

  if db.enabled == nil then db.enabled = true end

  if db.enemy_nameplate_width == nil then db.enemy_nameplate_width = 109 end
  if db.enemy_nameplate_height == nil then db.enemy_nameplate_height = 12.5 end
  if db.nameplate_texture == nil then db.nameplate_texture = "Blizzard" end
  if db.enemy_nameplate_castbar_width == nil then db.enemy_nameplate_castbar_width = 109 end
  if db.enemy_nameplate_castbar_height == nil then db.enemy_nameplate_castbar_height = 12.5 end

  if db.friendly_nameplate_width == nil then db.friendly_nameplate_width = 42 end
  if db.friendly_nameplate_height == nil then db.friendly_nameplate_height = 12.5 end
  if db.friendly_nameplate_castbar_width == nil then db.friendly_nameplate_castbar_width = 42 end
  if db.friendly_nameplate_castbar_height == nil then db.friendly_nameplate_castbar_height = 12.5 end

  if db.enemy_nameplate_health_text == nil then db.enemy_nameplate_health_text = true end
  if db.enemy_nameplate_health_text_mode == nil then db.enemy_nameplate_health_text_mode = "BOTH" end
  if db.enemy_nameplate_name_font_size == nil then db.enemy_nameplate_name_font_size = 10 end
  if db.enemy_nameplate_health_font_size == nil then db.enemy_nameplate_health_font_size = 9.5 end
  db.enemy_nameplate_health_text_color = db.enemy_nameplate_health_text_color or { r = 1.0, g = 0.82, b = 0.0 }
  db.enemy_nameplate_background_color = db.enemy_nameplate_background_color or { r = 0.02, g = 0.02, b = 0.02 }
  if db.enemy_nameplate_background_alpha == nil then db.enemy_nameplate_background_alpha = 0.85 end
  db.enemy_nameplate_border_color = db.enemy_nameplate_border_color or { r = 0.04, g = 0.04, b = 0.04 }
  if db.enemy_nameplate_border_size == nil then db.enemy_nameplate_border_size = 1 end
  if db.enemy_nameplate_execute_enabled == nil then db.enemy_nameplate_execute_enabled = false end
  if db.enemy_nameplate_execute_threshold == nil then db.enemy_nameplate_execute_threshold = 20 end
  db.enemy_nameplate_execute_color = db.enemy_nameplate_execute_color or { r = 1.0, g = 0.35, b = 0.05 }
  if db.enemy_nameplate_debuff == nil then db.enemy_nameplate_debuff = true end
  if db.enemy_nameplate_debuff_scale == nil then db.enemy_nameplate_debuff_scale = 1.0 end

  if db.enemy_nameplate_player_debuffs == nil then db.enemy_nameplate_player_debuffs = true end
  if db.enemy_nameplate_player_debuffs_scale == nil then db.enemy_nameplate_player_debuffs_scale = 1.0 end
  if db.enemy_nameplate_player_debuffs_padding == nil then db.enemy_nameplate_player_debuffs_padding = 4 end

  if db.enemy_nameplate_stance == nil then db.enemy_nameplate_stance = true end
  if db.enemy_nameplate_stance_scale == nil then db.enemy_nameplate_stance_scale = 1.0 end

  if db.class_colored_nameplates == nil then db.class_colored_nameplates = true end
  if db.friendly_nameplate_default_color == nil then db.friendly_nameplate_default_color = false end
  if db.nameplate_unit_target_color == nil then db.nameplate_unit_target_color = true end
  db.nameplate_unit_target_color_value = db.nameplate_unit_target_color_value or { r = 0.1, g = 0.55, b = 1.0 }
  if db.totem_nameplate_colors == nil then db.totem_nameplate_colors = true end
  if db.useAuraDeltaUpdates == nil then db.useAuraDeltaUpdates = true end
  if db.useSpellIDAuraLookup == nil then db.useSpellIDAuraLookup = true end
  db.selectedPreset = db.selectedPreset or "PVE"
  if db.autoPreset == nil then db.autoPreset = false end
  db.power = db.power or {}
  if db.power.enabled == nil then db.power.enabled = true end
  if db.power.height == nil then db.power.height = 6 end
  db.power.textMode = db.power.textMode or "NONE"
  db.power.targetTextMode = db.power.targetTextMode or "PERCENT"
  if db.power.friendlyAlways == nil then db.power.friendlyAlways = false end
  db.targeting = db.targeting or {}
  if db.targeting.showTargetOfTarget == nil then db.targeting.showTargetOfTarget = true end
  db.threat = db.threat or {}
  if db.threat.enabled == nil then db.threat.enabled = true end
  if db.threat.showPercent == nil then db.threat.showPercent = false end

  return db
end

local function EnsureDefaults()
  if not ETBC.db or not ETBC.db.profile then return end
  GetDB()
end

local function LSM_Textures()
  local textures
  if ETBC.LSM and ETBC.LSM.HashTable then
    textures = ETBC.LSM:HashTable("statusbar")
  else
    textures = { Blizzard = "Interface\\TargetingFrame\\UI-StatusBar" }
  end

  local labels = {}
  for name, path in pairs(textures) do
    if type(path) == "string" and path ~= "" then
      labels[name] = "|T" .. path .. ":14:96|t  " .. name
    else
      labels[name] = name
    end
  end
  return labels
end

ETBC.SettingsRegistry:RegisterGroup("nameplates", {
  name = "Unit Nameplates",
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
        set = function(_, v) db.enabled = v and true or false; ETBC.ApplyBus:Notify("nameplates") end,
      },

      presetsHeader = { type = "header", name = "Presets and preview", order = 2 },
      selectedPreset = {
        type = "select", name = "Nameplate preset", order = 3,
        desc = "Applies a curated nameplate-only layout. The previous nameplate profile can be restored once with Undo.",
        values = { MINIMAL = "Minimal", PVE = "PvE", TANK = "Tank", HEALER = "Healer", PVP = "PvP" },
        get = function() return db.selectedPreset or "PVE" end,
        set = function(_, value)
          local profiles = ETBC.Modules and ETBC.Modules.Nameplates and ETBC.Modules.Nameplates.Internal.Profiles
          if profiles then profiles:Apply(value) end
        end,
      },
      autoPreset = {
        type = "toggle", name = "Automatic context preset", order = 4,
        desc = "Uses PvP in arenas and battlegrounds, then assigned tank/healer roles. Ambiguous solo roles keep your selected preset.",
        get = function() return db.autoPreset == true end,
        set = function(_, value)
          db.autoPreset = value and true or false
          ETBC.ApplyBus:Notify("nameplates")
        end,
      },
      undoPreset = {
        type = "execute", name = "Undo last preset", order = 5,
        disabled = function() return type(db.presetUndo) ~= "table" end,
        func = function()
          local profiles = ETBC.Modules and ETBC.Modules.Nameplates and ETBC.Modules.Nameplates.Internal.Profiles
          if profiles then profiles:Undo() end
        end,
      },

      powerHeader = { type = "header", name = "Health and power", order = 6 },
      powerEnabled = {
        type = "toggle", name = "Primary power bar", order = 6.1,
        desc = "Shows mana, rage, energy, focus, and any other valid primary resource beneath health.",
        get = function() return db.power and db.power.enabled ~= false end,
        set = function(_, value) db.power.enabled = value and true or false; ETBC.ApplyBus:Notify("nameplates") end,
      },
      powerHeight = {
        type = "range", name = "Power bar height", order = 6.2, min = 2, max = 10, step = 1,
        disabled = function() return not db.enabled or not db.power.enabled end,
        get = function() return db.power.height or 6 end,
        set = function(_, value) db.power.height = value; ETBC.ApplyBus:Notify("nameplates") end,
      },
      powerTextMode = {
        type = "select", name = "Power text", order = 6.3,
        desc = "Text is kept inside the resource bar and hidden automatically on bars below 6 pixels high.",
        values = { NONE = "None", PERCENT = "Percent", VALUE = "Value", VALUE_MAX = "Value / maximum" },
        disabled = function() return not db.enabled or not db.power.enabled end,
        get = function() return db.power.textMode or "NONE" end,
        set = function(_, value) db.power.textMode = value; ETBC.ApplyBus:Notify("nameplates") end,
      },
      friendlyPowerAlways = {
        type = "toggle", name = "Power on all friendly plates", order = 6.4,
        desc = "Off by default. Friendly target and focus power remains visible when available.",
        disabled = function() return not db.enabled or not db.power.enabled end,
        get = function() return db.power.friendlyAlways == true end,
        set = function(_, value) db.power.friendlyAlways = value and true or false; ETBC.ApplyBus:Notify("nameplates") end,
      },

      combatHeader = { type = "header", name = "Threat and targeting", order = 7 },
      threatPercent = {
        type = "toggle", name = "Show threat percentage", order = 7.1,
        get = function() return db.threat and db.threat.showPercent == true end,
        set = function(_, value) db.threat.showPercent = value and true or false; ETBC.ApplyBus:Notify("nameplates") end,
      },
      targetOfTarget = {
        type = "toggle", name = "Show target-of-target", order = 7.2,
        get = function() return db.targeting and db.targeting.showTargetOfTarget ~= false end,
        set = function(_, value) db.targeting.showTargetOfTarget = value and true or false; ETBC.ApplyBus:Notify("nameplates") end,
      },

      enemyHeader = { type = "header", name = "Enemy Nameplates", order = 10 },

      nameplate_texture = {
        type = "select",
        name = "Health bar texture",
        desc = "Selects the LibSharedMedia texture used by enemy and friendly nameplate health bars.",
        order = 10.5,
        width = "full",
        disabled = function() return not db.enabled end,
        values = LSM_Textures,
        get = function() return db.nameplate_texture or "Blizzard" end,
        set = function(_, v)
          db.nameplate_texture = v
          ETBC.ApplyBus:Notify("nameplates")
        end,
      },

      enemy_nameplate_width = {
        type = "range",
        name = "Health width",
        order = 11,
        min = 60, max = 200, step = 1,
        disabled = function() return not db.enabled end,
        get = function() return db.enemy_nameplate_width end,
        set = function(_, v) db.enemy_nameplate_width = v; ETBC.ApplyBus:Notify("nameplates") end,
      },
      enemy_nameplate_height = {
        type = "range",
        name = "Health height",
        order = 12,
        min = 8, max = 24, step = 0.5,
        disabled = function() return not db.enabled end,
        get = function() return db.enemy_nameplate_height end,
        set = function(_, v) db.enemy_nameplate_height = v; ETBC.ApplyBus:Notify("nameplates") end,
      },
      enemy_nameplate_castbar_width = {
        type = "range",
        name = "Castbar width",
        order = 13,
        min = 60, max = 200, step = 1,
        disabled = function() return not db.enabled end,
        get = function() return db.enemy_nameplate_castbar_width end,
        set = function(_, v) db.enemy_nameplate_castbar_width = v; ETBC.ApplyBus:Notify("nameplates") end,
      },
      enemy_nameplate_castbar_height = {
        type = "range",
        name = "Castbar height",
        order = 14,
        min = 8, max = 24, step = 0.5,
        disabled = function() return not db.enabled end,
        get = function() return db.enemy_nameplate_castbar_height end,
        set = function(_, v) db.enemy_nameplate_castbar_height = v; ETBC.ApplyBus:Notify("nameplates") end,
      },

      enemy_nameplate_health_text = {
        type = "toggle",
        name = "Show health text",
        order = 15,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.enemy_nameplate_health_text end,
        set = function(_, v)
          db.enemy_nameplate_health_text = v and true or false
          ETBC.ApplyBus:Notify("nameplates")
        end,
      },

      enemy_nameplate_health_text_mode = {
        type = "select",
        name = "Health text mode",
        order = 15.1,
        values = { PERCENT = "Percentage", VALUE = "Current value", BOTH = "Percentage and value" },
        disabled = function() return not (db.enabled and db.enemy_nameplate_health_text) end,
        get = function() return db.enemy_nameplate_health_text_mode end,
        set = function(_, v) db.enemy_nameplate_health_text_mode = v; ETBC.ApplyBus:Notify("nameplates") end,
      },
      enemy_nameplate_name_font_size = {
        type = "range",
        name = "Name font size",
        order = 15.11,
        min = 8, max = 18, step = 0.5,
        disabled = function() return not db.enabled end,
        get = function() return db.enemy_nameplate_name_font_size end,
        set = function(_, v) db.enemy_nameplate_name_font_size = v; ETBC.ApplyBus:Notify("nameplates") end,
      },
      enemy_nameplate_health_font_size = {
        type = "range",
        name = "Health font size",
        order = 15.12,
        min = 7, max = 16, step = 0.5,
        disabled = function() return not (db.enabled and db.enemy_nameplate_health_text) end,
        get = function() return db.enemy_nameplate_health_font_size end,
        set = function(_, v) db.enemy_nameplate_health_font_size = v; ETBC.ApplyBus:Notify("nameplates") end,
      },
      enemy_nameplate_health_text_color = {
        type = "color",
        name = "Health text color",
        order = 15.13,
        disabled = function() return not (db.enabled and db.enemy_nameplate_health_text) end,
        get = function()
          local c = db.enemy_nameplate_health_text_color
          return c.r, c.g, c.b
        end,
        set = function(_, r, g, b)
          db.enemy_nameplate_health_text_color = { r = r, g = g, b = b }
          ETBC.ApplyBus:Notify("nameplates")
        end,
      },
      enemy_nameplate_background_color = {
        type = "color",
        name = "Missing-health color",
        order = 15.2,
        disabled = function() return not db.enabled end,
        get = function()
          local c = db.enemy_nameplate_background_color
          return c.r, c.g, c.b
        end,
        set = function(_, r, g, b)
          db.enemy_nameplate_background_color = { r = r, g = g, b = b }
          ETBC.ApplyBus:Notify("nameplates")
        end,
      },
      enemy_nameplate_background_alpha = {
        type = "range",
        name = "Missing-health opacity",
        order = 15.3,
        min = 0, max = 1, step = 0.05,
        disabled = function() return not db.enabled end,
        get = function() return db.enemy_nameplate_background_alpha end,
        set = function(_, v) db.enemy_nameplate_background_alpha = v; ETBC.ApplyBus:Notify("nameplates") end,
      },
      enemy_nameplate_border_color = {
        type = "color",
        name = "Health border color",
        order = 15.31,
        disabled = function() return not db.enabled end,
        get = function()
          local c = db.enemy_nameplate_border_color
          return c.r, c.g, c.b
        end,
        set = function(_, r, g, b)
          db.enemy_nameplate_border_color = { r = r, g = g, b = b }
          ETBC.ApplyBus:Notify("nameplates")
        end,
      },
      enemy_nameplate_border_size = {
        type = "range",
        name = "Health border thickness",
        order = 15.32,
        min = 0, max = 3, step = 0.5,
        disabled = function() return not db.enabled end,
        get = function() return db.enemy_nameplate_border_size end,
        set = function(_, v) db.enemy_nameplate_border_size = v; ETBC.ApplyBus:Notify("nameplates") end,
      },
      enemy_nameplate_execute_enabled = {
        type = "toggle",
        name = "Execute-range coloring",
        order = 15.4,
        disabled = function() return not db.enabled end,
        get = function() return db.enemy_nameplate_execute_enabled end,
        set = function(_, v) db.enemy_nameplate_execute_enabled = v and true or false; ETBC.ApplyBus:Notify("nameplates") end,
      },
      enemy_nameplate_execute_threshold = {
        type = "range",
        name = "Execute threshold",
        order = 15.5,
        min = 5, max = 40, step = 1,
        disabled = function() return not (db.enabled and db.enemy_nameplate_execute_enabled) end,
        get = function() return db.enemy_nameplate_execute_threshold end,
        set = function(_, v) db.enemy_nameplate_execute_threshold = v; ETBC.ApplyBus:Notify("nameplates") end,
      },
      enemy_nameplate_execute_color = {
        type = "color",
        name = "Execute color",
        order = 15.6,
        disabled = function() return not (db.enabled and db.enemy_nameplate_execute_enabled) end,
        get = function()
          local c = db.enemy_nameplate_execute_color
          return c.r, c.g, c.b
        end,
        set = function(_, r, g, b)
          db.enemy_nameplate_execute_color = { r = r, g = g, b = b }
          ETBC.ApplyBus:Notify("nameplates")
        end,
      },

      enemy_nameplate_debuff = {
        type = "toggle",
        name = "Show priority debuff",
        order = 16,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.enemy_nameplate_debuff end,
        set = function(_, v)
          db.enemy_nameplate_debuff = v and true or false
          ETBC.ApplyBus:Notify("nameplates")
        end,
      },

      enemy_nameplate_debuff_scale = {
        type = "range",
        name = "Debuff scale",
        order = 17,
        min = 0.6, max = 1.6, step = 0.05,
        disabled = function() return not (db.enabled and db.enemy_nameplate_debuff) end,
        get = function() return db.enemy_nameplate_debuff_scale end,
        set = function(_, v) db.enemy_nameplate_debuff_scale = v; ETBC.ApplyBus:Notify("nameplates") end,
      },

      enemy_nameplate_player_debuffs = {
        type = "toggle",
        name = "Show player debuffs",
        desc = "Shows your tracked debuffs separately on enemy nameplates when available.",
        order = 18,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.enemy_nameplate_player_debuffs end,
        set = function(_, v)
          db.enemy_nameplate_player_debuffs = v and true or false
          ETBC.ApplyBus:Notify("nameplates")
        end,
      },

      enemy_nameplate_player_debuffs_scale = {
        type = "range",
        name = "Player debuffs scale",
        order = 19,
        min = 0.6, max = 1.6, step = 0.05,
        disabled = function() return not (db.enabled and db.enemy_nameplate_player_debuffs) end,
        get = function() return db.enemy_nameplate_player_debuffs_scale end,
        set = function(_, v) db.enemy_nameplate_player_debuffs_scale = v; ETBC.ApplyBus:Notify("nameplates") end,
      },

      enemy_nameplate_player_debuffs_padding = {
        type = "range",
        name = "Player debuffs padding",
        order = 20,
        min = 0, max = 12, step = 1,
        disabled = function() return not (db.enabled and db.enemy_nameplate_player_debuffs) end,
        get = function() return db.enemy_nameplate_player_debuffs_padding end,
        set = function(_, v) db.enemy_nameplate_player_debuffs_padding = v; ETBC.ApplyBus:Notify("nameplates") end,
      },

      enemy_nameplate_stance = {
        type = "toggle",
        name = "Show stance icon",
        order = 21,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.enemy_nameplate_stance end,
        set = function(_, v)
          db.enemy_nameplate_stance = v and true or false
          ETBC.ApplyBus:Notify("nameplates")
        end,
      },

      enemy_nameplate_stance_scale = {
        type = "range",
        name = "Stance icon scale",
        order = 22,
        min = 0.6, max = 1.6, step = 0.05,
        disabled = function() return not (db.enabled and db.enemy_nameplate_stance) end,
        get = function() return db.enemy_nameplate_stance_scale end,
        set = function(_, v) db.enemy_nameplate_stance_scale = v; ETBC.ApplyBus:Notify("nameplates") end,
      },
      useAuraDeltaUpdates = {
        type = "toggle",
        name = "Use Aura Delta Events",
        desc = "Uses UNIT_AURA delta payloads to skip redundant refresh work when possible.",
        order = 23,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.useAuraDeltaUpdates end,
        set = function(_, v) db.useAuraDeltaUpdates = v and true or false; ETBC.ApplyBus:Notify("nameplates") end,
      },
      useSpellIDAuraLookup = {
        type = "toggle",
        name = "Use SpellID Aura Lookup",
        desc = "Uses C_UnitAuras.GetUnitAuraBySpellID for tracked aura checks before loop fallback.",
        order = 24,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.useSpellIDAuraLookup end,
        set = function(_, v) db.useSpellIDAuraLookup = v and true or false; ETBC.ApplyBus:Notify("nameplates") end,
      },

      friendlyHeader = { type = "header", name = "Friendly Nameplates", order = 30 },

      friendly_nameplate_width = {
        type = "range",
        name = "Health width",
        order = 31,
        min = 30, max = 120, step = 1,
        disabled = function() return not db.enabled end,
        get = function() return db.friendly_nameplate_width end,
        set = function(_, v) db.friendly_nameplate_width = v; ETBC.ApplyBus:Notify("nameplates") end,
      },
      friendly_nameplate_height = {
        type = "range",
        name = "Health height",
        order = 32,
        min = 8, max = 24, step = 0.5,
        disabled = function() return not db.enabled end,
        get = function() return db.friendly_nameplate_height end,
        set = function(_, v) db.friendly_nameplate_height = v; ETBC.ApplyBus:Notify("nameplates") end,
      },
      friendly_nameplate_castbar_width = {
        type = "range",
        name = "Castbar width",
        order = 33,
        min = 30, max = 120, step = 1,
        disabled = function() return not db.enabled end,
        get = function() return db.friendly_nameplate_castbar_width end,
        set = function(_, v) db.friendly_nameplate_castbar_width = v; ETBC.ApplyBus:Notify("nameplates") end,
      },
      friendly_nameplate_castbar_height = {
        type = "range",
        name = "Castbar height",
        order = 34,
        min = 8, max = 24, step = 0.5,
        disabled = function() return not db.enabled end,
        get = function() return db.friendly_nameplate_castbar_height end,
        set = function(_, v) db.friendly_nameplate_castbar_height = v; ETBC.ApplyBus:Notify("nameplates") end,
      },

      colorHeader = { type = "header", name = "Colors", order = 40 },

      class_colored_nameplates = {
        type = "toggle",
        name = "Class colored nameplates",
        desc = "Uses class colors on enemy and friendly player nameplates when the client provides class info.",
        order = 41,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.class_colored_nameplates end,
        set = function(_, v) db.class_colored_nameplates = v and true or false; ETBC.ApplyBus:Notify("nameplates") end,
      },

      friendly_nameplate_default_color = {
        type = "toggle",
        name = "Use default friendly color",
        desc = "Keeps Blizzard's default friendly nameplate colors instead of EnhanceTBC recoloring.",
        order = 42,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.friendly_nameplate_default_color end,
        set = function(_, v)
          db.friendly_nameplate_default_color = v and true or false
          ETBC.ApplyBus:Notify("nameplates")
        end,
      },

      nameplate_unit_target_color = {
        type = "toggle",
        name = "Highlight enemy targeting you",
        desc = "Highlights enemy nameplates when that unit is currently targeting you.",
        order = 43,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.nameplate_unit_target_color end,
        set = function(_, v)
          db.nameplate_unit_target_color = v and true or false
          ETBC.ApplyBus:Notify("nameplates")
        end,
      },

      nameplate_unit_target_color_value = {
        type = "color",
        name = "Targeting-you color",
        order = 43.5,
        disabled = function() return not (db.enabled and db.nameplate_unit_target_color) end,
        get = function()
          local c = db.nameplate_unit_target_color_value
          return c.r, c.g, c.b
        end,
        set = function(_, r, g, b)
          db.nameplate_unit_target_color_value = { r = r, g = g, b = b }
          ETBC.ApplyBus:Notify("nameplates")
        end,
      },

      totem_nameplate_colors = {
        type = "toggle",
        name = "Totem color overrides",
        desc = "Applies totem-specific colors to supported enemy totem nameplates.",
        order = 44,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.totem_nameplate_colors end,
        set = function(_, v) db.totem_nameplate_colors = v and true or false; ETBC.ApplyBus:Notify("nameplates") end,
      },
    }
  end,
})

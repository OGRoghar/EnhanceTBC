-- Settings/Settings_Unit_Nameplates.lua
-- EnhanceTBC - Unit nameplate settings

local _, ETBC = ...

local function GetDB()
  ETBC.db.profile.nameplates = ETBC.db.profile.nameplates or {}
  local db = ETBC.db.profile.nameplates

  if db.enabled == nil then db.enabled = true end

  if db.enemy_nameplate_width == nil then db.enemy_nameplate_width = 109 end
  if db.enemy_nameplate_height == nil then db.enemy_nameplate_height = 12.5 end
  if db.enemy_nameplate_castbar_width == nil then db.enemy_nameplate_castbar_width = 109 end
  if db.enemy_nameplate_castbar_height == nil then db.enemy_nameplate_castbar_height = 12.5 end

  if db.friendly_nameplate_width == nil then db.friendly_nameplate_width = 42 end
  if db.friendly_nameplate_height == nil then db.friendly_nameplate_height = 12.5 end
  if db.friendly_nameplate_castbar_width == nil then db.friendly_nameplate_castbar_width = 42 end
  if db.friendly_nameplate_castbar_height == nil then db.friendly_nameplate_castbar_height = 12.5 end

  if db.enemy_nameplate_health_text == nil then db.enemy_nameplate_health_text = true end
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
  if db.totem_nameplate_colors == nil then db.totem_nameplate_colors = true end
  if db.useAuraDeltaUpdates == nil then db.useAuraDeltaUpdates = true end
  if db.useSpellIDAuraLookup == nil then db.useSpellIDAuraLookup = true end

  return db
end

local function EnsureDefaults()
  if not ETBC.db or not ETBC.db.profile then return end
  GetDB()
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

      enemyHeader = { type = "header", name = "Enemy Nameplates", order = 10 },

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
        order = 41,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.class_colored_nameplates end,
        set = function(_, v) db.class_colored_nameplates = v and true or false; ETBC.ApplyBus:Notify("nameplates") end,
      },

      friendly_nameplate_default_color = {
        type = "toggle",
        name = "Use default friendly color",
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
        name = "Highlight enemy targetting you",
        order = 43,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.nameplate_unit_target_color end,
        set = function(_, v)
          db.nameplate_unit_target_color = v and true or false
          ETBC.ApplyBus:Notify("nameplates")
        end,
      },

      totem_nameplate_colors = {
        type = "toggle",
        name = "Totem color overrides",
        order = 44,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.totem_nameplate_colors end,
        set = function(_, v) db.totem_nameplate_colors = v and true or false; ETBC.ApplyBus:Notify("nameplates") end,
      },
    }
  end,
})

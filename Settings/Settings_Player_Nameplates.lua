-- Settings/Settings_Player_Nameplates.lua
-- EnhanceTBC - Player nameplate settings

local _, ETBC = ...

local function GetDB()
  ETBC.db.profile.player_nameplates = ETBC.db.profile.player_nameplates or {}
  local db = ETBC.db.profile.player_nameplates

  if db.enabled == nil then db.enabled = true end
  if db.player_nameplate_frame == nil then db.player_nameplate_frame = true end
  if db.player_nameplate_scale == nil then db.player_nameplate_scale = 0.9 end
  if db.player_nameplate_alpha == nil then db.player_nameplate_alpha = 1 end
  if db.player_nameplate_width == nil then db.player_nameplate_width = 128 end
  if db.player_nameplate_height == nil then db.player_nameplate_height = 22 end
  if db.player_nameplate_pos_y == nil then db.player_nameplate_pos_y = -105 end
  if db.player_nameplate_show == nil then db.player_nameplate_show = false end
  if db.player_nameplate_health == nil then db.player_nameplate_health = false end
  if db.player_nameplate_text == nil then db.player_nameplate_text = true end

  if db.player_alt_manabar == nil then db.player_alt_manabar = true end

  if db.player_melee_swing_timer == nil then db.player_melee_swing_timer = false end
  if db.player_melee_swing_timer_show_offhand == nil then
    db.player_melee_swing_timer_show_offhand = false
  end
  if db.player_melee_swing_timer_only_in_combat == nil then
    db.player_melee_swing_timer_only_in_combat = false
  end
  if db.player_melee_swing_timer_hide_out_of_combat == nil then
    db.player_melee_swing_timer_hide_out_of_combat = false
  end
  if db.player_melee_swing_timer_width == nil then db.player_melee_swing_timer_width = 230 end
  if db.player_melee_swing_timer_height == nil then db.player_melee_swing_timer_height = 9 end
  if db.player_melee_swing_timer_alpha == nil then db.player_melee_swing_timer_alpha = 1 end
  if db.player_melee_swing_timer_color == nil then
    db.player_melee_swing_timer_color = { r = 1, g = 1, b = 1, a = 1 }
  end
  if db.player_melee_swing_timer_seperate == nil then db.player_melee_swing_timer_seperate = false end
  if db.player_melee_swing_timer_scale == nil then db.player_melee_swing_timer_scale = 1 end
  if db.player_melee_swing_timer_pos_y == nil then db.player_melee_swing_timer_pos_y = -150 end
  if db.player_melee_swing_timer_icon == nil then db.player_melee_swing_timer_icon = true end
  if db.player_melee_swing_timer_text == nil then db.player_melee_swing_timer_text = true end

  if db.player_ranged_cast_timer == nil then db.player_ranged_cast_timer = false end
  if db.player_ranged_cast_timer_width == nil then db.player_ranged_cast_timer_width = 230 end
  if db.player_ranged_cast_timer_height == nil then db.player_ranged_cast_timer_height = 9 end
  if db.player_ranged_cast_timer_alpha == nil then db.player_ranged_cast_timer_alpha = 1 end
  if db.player_ranged_cast_timer_color == nil then
    db.player_ranged_cast_timer_color = { r = 1, g = 1, b = 1, a = 1 }
  end
  if db.player_ranged_cast_timer_seperate == nil then db.player_ranged_cast_timer_seperate = false end
  if db.player_ranged_cast_timer_scale == nil then db.player_ranged_cast_timer_scale = 1 end
  if db.player_ranged_cast_timer_pos_y == nil then db.player_ranged_cast_timer_pos_y = -140 end
  if db.player_ranged_cast_timer_text == nil then db.player_ranged_cast_timer_text = true end
  if db.player_auto_shot_timer == nil then db.player_auto_shot_timer = true end

  return db
end

local function EnsureDefaults()
  if not ETBC.db or not ETBC.db.profile then return end
  GetDB()
end

ETBC.SettingsRegistry:RegisterGroup("player_nameplates", {
  name = "Player Nameplate",
  order = 17,
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
        set = function(_, v)
          db.enabled = v and true or false
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },

      frameHeader = { type = "header", name = "Frame", order = 10 },

      player_nameplate_frame = {
        type = "toggle",
        name = "Show frame",
        order = 11,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.player_nameplate_frame end,
        set = function(_, v)
          db.player_nameplate_frame = v and true or false
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },
      player_nameplate_scale = {
        type = "range",
        name = "Scale",
        order = 12,
        min = 0.5, max = 1.5, step = 0.05,
        disabled = function() return not db.enabled end,
        get = function() return db.player_nameplate_scale end,
        set = function(_, v)
          db.player_nameplate_scale = v
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },
      player_nameplate_alpha = {
        type = "range",
        name = "Alpha",
        order = 13,
        min = 0.1, max = 1, step = 0.05,
        disabled = function() return not db.enabled end,
        get = function() return db.player_nameplate_alpha end,
        set = function(_, v)
          db.player_nameplate_alpha = v
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },
      player_nameplate_width = {
        type = "range",
        name = "Width",
        order = 14,
        min = 80, max = 220, step = 1,
        disabled = function() return not db.enabled end,
        get = function() return db.player_nameplate_width end,
        set = function(_, v)
          db.player_nameplate_width = v
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },
      player_nameplate_height = {
        type = "range",
        name = "Height",
        order = 15,
        min = 10, max = 32, step = 1,
        disabled = function() return not db.enabled end,
        get = function() return db.player_nameplate_height end,
        set = function(_, v)
          db.player_nameplate_height = v
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },
      player_nameplate_pos_y = {
        type = "range",
        name = "Y Offset",
        order = 16,
        min = -300, max = 100, step = 1,
        disabled = function() return not db.enabled end,
        get = function() return db.player_nameplate_pos_y end,
        set = function(_, v)
          db.player_nameplate_pos_y = v
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },
      player_nameplate_show = {
        type = "toggle",
        name = "Always show",
        order = 17,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.player_nameplate_show end,
        set = function(_, v)
          db.player_nameplate_show = v and true or false
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },
      player_nameplate_health = {
        type = "toggle",
        name = "Hide health bar",
        order = 18,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.player_nameplate_health end,
        set = function(_, v)
          db.player_nameplate_health = v and true or false
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },
      player_nameplate_text = {
        type = "toggle",
        name = "Show health/mana text",
        order = 19,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.player_nameplate_text end,
        set = function(_, v)
          db.player_nameplate_text = v and true or false
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },
      player_alt_manabar = {
        type = "toggle",
        name = "Show alt mana bar",
        order = 20,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.player_alt_manabar end,
        set = function(_, v)
          db.player_alt_manabar = v and true or false
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },

      meleeHeader = { type = "header", name = "Melee Swing Timer", order = 30 },

      player_melee_swing_timer = {
        type = "toggle",
        name = "Enable",
        order = 31,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.player_melee_swing_timer end,
        set = function(_, v)
          db.player_melee_swing_timer = v and true or false
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },
      player_melee_swing_timer_show_offhand = {
        type = "toggle",
        name = "Show off-hand bar",
        order = 32,
        width = "full",
        disabled = function() return not (db.enabled and db.player_melee_swing_timer) end,
        get = function() return db.player_melee_swing_timer_show_offhand end,
        set = function(_, v)
          db.player_melee_swing_timer_show_offhand = v and true or false
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },
      player_melee_swing_timer_only_in_combat = {
        type = "toggle",
        name = "Only show in combat",
        order = 33,
        width = "full",
        disabled = function() return not (db.enabled and db.player_melee_swing_timer) end,
        get = function() return db.player_melee_swing_timer_only_in_combat end,
        set = function(_, v)
          db.player_melee_swing_timer_only_in_combat = v and true or false
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },
      player_melee_swing_timer_hide_out_of_combat = {
        type = "toggle",
        name = "Hide out of combat",
        order = 34,
        width = "full",
        disabled = function() return not (db.enabled and db.player_melee_swing_timer) end,
        get = function() return db.player_melee_swing_timer_hide_out_of_combat end,
        set = function(_, v)
          db.player_melee_swing_timer_hide_out_of_combat = v and true or false
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },
      player_melee_swing_timer_seperate = {
        type = "toggle",
        name = "Separate from nameplate",
        order = 35,
        width = "full",
        disabled = function() return not (db.enabled and db.player_melee_swing_timer) end,
        get = function() return db.player_melee_swing_timer_seperate end,
        set = function(_, v)
          db.player_melee_swing_timer_seperate = v and true or false
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },
      player_melee_swing_timer_width = {
        type = "range",
        name = "Width",
        order = 36,
        min = 120, max = 320, step = 1,
        disabled = function() return not (db.enabled and db.player_melee_swing_timer) end,
        get = function() return db.player_melee_swing_timer_width end,
        set = function(_, v)
          db.player_melee_swing_timer_width = v
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },
      player_melee_swing_timer_height = {
        type = "range",
        name = "Height",
        order = 37,
        min = 6, max = 24, step = 1,
        disabled = function() return not (db.enabled and db.player_melee_swing_timer) end,
        get = function() return db.player_melee_swing_timer_height end,
        set = function(_, v)
          db.player_melee_swing_timer_height = v
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },
      player_melee_swing_timer_scale = {
        type = "range",
        name = "Scale",
        order = 38,
        min = 0.5, max = 1.5, step = 0.05,
        disabled = function() return not (db.enabled and db.player_melee_swing_timer) end,
        get = function() return db.player_melee_swing_timer_scale end,
        set = function(_, v)
          db.player_melee_swing_timer_scale = v
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },
      player_melee_swing_timer_alpha = {
        type = "range",
        name = "Alpha",
        order = 39,
        min = 0.1, max = 1, step = 0.05,
        disabled = function() return not (db.enabled and db.player_melee_swing_timer) end,
        get = function() return db.player_melee_swing_timer_alpha end,
        set = function(_, v)
          db.player_melee_swing_timer_alpha = v
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },
      player_melee_swing_timer_pos_y = {
        type = "range",
        name = "Y Offset",
        order = 40,
        min = -400, max = 100, step = 1,
        disabled = function() return not (db.enabled and db.player_melee_swing_timer) end,
        get = function() return db.player_melee_swing_timer_pos_y end,
        set = function(_, v)
          db.player_melee_swing_timer_pos_y = v
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },
      player_melee_swing_timer_icon = {
        type = "toggle",
        name = "Show ability icon",
        order = 41,
        width = "full",
        disabled = function() return not (db.enabled and db.player_melee_swing_timer) end,
        get = function() return db.player_melee_swing_timer_icon end,
        set = function(_, v)
          db.player_melee_swing_timer_icon = v and true or false
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },
      player_melee_swing_timer_text = {
        type = "toggle",
        name = "Show timer text",
        order = 42,
        width = "full",
        disabled = function() return not (db.enabled and db.player_melee_swing_timer) end,
        get = function() return db.player_melee_swing_timer_text end,
        set = function(_, v)
          db.player_melee_swing_timer_text = v and true or false
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },
      player_melee_swing_timer_color = {
        type = "color",
        name = "Bar Color",
        order = 43,
        hasAlpha = true,
        disabled = function() return not (db.enabled and db.player_melee_swing_timer) end,
        get = function()
          local c = db.player_melee_swing_timer_color
          return c.r, c.g, c.b, (c.a or 1)
        end,
        set = function(_, r, g, b, a)
          local c = db.player_melee_swing_timer_color
          c.r, c.g, c.b, c.a = r, g, b, a
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },

      rangedHeader = { type = "header", name = "Ranged Cast Timer", order = 50 },

      player_ranged_cast_timer = {
        type = "toggle",
        name = "Enable",
        order = 51,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.player_ranged_cast_timer end,
        set = function(_, v)
          db.player_ranged_cast_timer = v and true or false
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },
      player_ranged_cast_timer_seperate = {
        type = "toggle",
        name = "Separate from nameplate",
        order = 52,
        width = "full",
        disabled = function() return not (db.enabled and db.player_ranged_cast_timer) end,
        get = function() return db.player_ranged_cast_timer_seperate end,
        set = function(_, v)
          db.player_ranged_cast_timer_seperate = v and true or false
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },
      player_ranged_cast_timer_width = {
        type = "range",
        name = "Width",
        order = 53,
        min = 120, max = 320, step = 1,
        disabled = function() return not (db.enabled and db.player_ranged_cast_timer) end,
        get = function() return db.player_ranged_cast_timer_width end,
        set = function(_, v) db.player_ranged_cast_timer_width = v; ETBC.ApplyBus:Notify("player_nameplates") end,
      },
      player_ranged_cast_timer_height = {
        type = "range",
        name = "Height",
        order = 54,
        min = 6, max = 24, step = 1,
        disabled = function() return not (db.enabled and db.player_ranged_cast_timer) end,
        get = function() return db.player_ranged_cast_timer_height end,
        set = function(_, v) db.player_ranged_cast_timer_height = v; ETBC.ApplyBus:Notify("player_nameplates") end,
      },
      player_ranged_cast_timer_scale = {
        type = "range",
        name = "Scale",
        order = 55,
        min = 0.5, max = 1.5, step = 0.05,
        disabled = function() return not (db.enabled and db.player_ranged_cast_timer) end,
        get = function() return db.player_ranged_cast_timer_scale end,
        set = function(_, v) db.player_ranged_cast_timer_scale = v; ETBC.ApplyBus:Notify("player_nameplates") end,
      },
      player_ranged_cast_timer_alpha = {
        type = "range",
        name = "Alpha",
        order = 56,
        min = 0.1, max = 1, step = 0.05,
        disabled = function() return not (db.enabled and db.player_ranged_cast_timer) end,
        get = function() return db.player_ranged_cast_timer_alpha end,
        set = function(_, v) db.player_ranged_cast_timer_alpha = v; ETBC.ApplyBus:Notify("player_nameplates") end,
      },
      player_ranged_cast_timer_pos_y = {
        type = "range",
        name = "Y Offset",
        order = 57,
        min = -400, max = 100, step = 1,
        disabled = function() return not (db.enabled and db.player_ranged_cast_timer) end,
        get = function() return db.player_ranged_cast_timer_pos_y end,
        set = function(_, v) db.player_ranged_cast_timer_pos_y = v; ETBC.ApplyBus:Notify("player_nameplates") end,
      },
      player_ranged_cast_timer_text = {
        type = "toggle",
        name = "Show timer text",
        order = 58,
        width = "full",
        disabled = function() return not (db.enabled and db.player_ranged_cast_timer) end,
        get = function() return db.player_ranged_cast_timer_text end,
        set = function(_, v)
          db.player_ranged_cast_timer_text = v and true or false
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },
      player_auto_shot_timer = {
        type = "toggle",
        name = "Show auto shot timer",
        order = 59,
        width = "full",
        disabled = function() return not (db.enabled and db.player_ranged_cast_timer) end,
        get = function() return db.player_auto_shot_timer end,
        set = function(_, v)
          db.player_auto_shot_timer = v and true or false
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },
      player_ranged_cast_timer_color = {
        type = "color",
        name = "Bar Color",
        order = 60,
        hasAlpha = true,
        disabled = function() return not (db.enabled and db.player_ranged_cast_timer) end,
        get = function()
          local c = db.player_ranged_cast_timer_color
          return c.r, c.g, c.b, (c.a or 1)
        end,
        set = function(_, r, g, b, a)
          local c = db.player_ranged_cast_timer_color
          c.r, c.g, c.b, c.a = r, g, b, a
          ETBC.ApplyBus:Notify("player_nameplates")
        end,
      },
    }
  end,
})

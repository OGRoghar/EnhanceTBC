-- Settings/Settings_Objectives.lua
-- EnhanceTBC - Quest / Objective Helper settings (TBC WatchFrame / ObjectiveTracker)

local ADDON_NAME, ETBC = ...

local function GetDB()
  ETBC.db.profile.objectives = ETBC.db.profile.objectives or {}
  local db = ETBC.db.profile.objectives

  if db.enabled == nil then db.enabled = true end

  -- Visibility in combat
  if db.hideInCombat == nil then db.hideInCombat = false end
  if db.fadeInCombat == nil then db.fadeInCombat = true end
  if db.combatAlpha == nil then db.combatAlpha = 0.20 end
  if db.fadeTime == nil then db.fadeTime = 0.12 end

  -- Layout
  if db.width == nil then db.width = 300 end
  if db.clampToScreen == nil then db.clampToScreen = true end

  -- Style
  if db.background == nil then db.background = true end
  if db.bgAlpha == nil then db.bgAlpha = 0.35 end
  if db.borderAlpha == nil then db.borderAlpha = 0.95 end
  if db.scale == nil then db.scale = 1.00 end

  -- Font
  if db.fontScale == nil then db.fontScale = 1.00 end

  -- Behavior
  if db.autoCollapseCompleted == nil then db.autoCollapseCompleted = true end
  if db.onlyCollapseInDungeons == nil then db.onlyCollapseInDungeons = false end

  return db
end

ETBC.SettingsRegistry:RegisterGroup("objectives", {
  name = "Objectives",
  order = 42,
  options = function()
    local db = GetDB()

    return {
      enabled = {
        type = "toggle",
        name = "Enable",
        order = 1,
        width = "full",
        get = function() return db.enabled end,
        set = function(_, v) db.enabled = v and true or false; ETBC.ApplyBus:Notify("objectives") end,
      },

      combatHeader = { type = "header", name = "Combat Visibility", order = 10 },

      hideInCombat = {
        type = "toggle",
        name = "Hide in combat",
        order = 11,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.hideInCombat end,
        set = function(_, v) db.hideInCombat = v and true or false; ETBC.ApplyBus:Notify("objectives") end,
      },

      fadeInCombat = {
        type = "toggle",
        name = "Fade in combat",
        desc = "If Hide is enabled, this is ignored.",
        order = 12,
        width = "full",
        disabled = function() return not db.enabled or db.hideInCombat end,
        get = function() return db.fadeInCombat end,
        set = function(_, v) db.fadeInCombat = v and true or false; ETBC.ApplyBus:Notify("objectives") end,
      },

      combatAlpha = {
        type = "range",
        name = "Combat alpha",
        order = 13,
        min = 0.00, max = 0.60, step = 0.01,
        disabled = function() return not (db.enabled and not db.hideInCombat and db.fadeInCombat) end,
        get = function() return db.combatAlpha end,
        set = function(_, v) db.combatAlpha = v; ETBC.ApplyBus:Notify("objectives") end,
      },

      fadeTime = {
        type = "range",
        name = "Fade time",
        order = 14,
        min = 0.00, max = 0.50, step = 0.01,
        disabled = function() return not (db.enabled and (db.fadeInCombat or db.hideInCombat)) end,
        get = function() return db.fadeTime end,
        set = function(_, v) db.fadeTime = v; ETBC.ApplyBus:Notify("objectives") end,
      },

      layoutHeader = { type = "header", name = "Layout", order = 20 },

      width = {
        type = "range",
        name = "Width",
        order = 21,
        min = 180, max = 520, step = 1,
        disabled = function() return not db.enabled end,
        get = function() return db.width end,
        set = function(_, v) db.width = v; ETBC.ApplyBus:Notify("objectives") end,
      },

      scale = {
        type = "range",
        name = "Scale",
        order = 22,
        min = 0.70, max = 1.60, step = 0.01,
        disabled = function() return not db.enabled end,
        get = function() return db.scale end,
        set = function(_, v) db.scale = v; ETBC.ApplyBus:Notify("objectives") end,
      },

      fontScale = {
        type = "range",
        name = "Font scale",
        order = 23,
        min = 0.80, max = 1.40, step = 0.01,
        disabled = function() return not db.enabled end,
        get = function() return db.fontScale end,
        set = function(_, v) db.fontScale = v; ETBC.ApplyBus:Notify("objectives") end,
      },

      styleHeader = { type = "header", name = "Style", order = 30 },

      background = {
        type = "toggle",
        name = "Background panel",
        order = 31,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.background end,
        set = function(_, v) db.background = v and true or false; ETBC.ApplyBus:Notify("objectives") end,
      },

      bgAlpha = {
        type = "range",
        name = "Background alpha",
        order = 32,
        min = 0.00, max = 0.75, step = 0.01,
        disabled = function() return not (db.enabled and db.background) end,
        get = function() return db.bgAlpha end,
        set = function(_, v) db.bgAlpha = v; ETBC.ApplyBus:Notify("objectives") end,
      },

      borderAlpha = {
        type = "range",
        name = "Border alpha",
        order = 33,
        min = 0.00, max = 1.00, step = 0.01,
        disabled = function() return not (db.enabled and db.background) end,
        get = function() return db.borderAlpha end,
        set = function(_, v) db.borderAlpha = v; ETBC.ApplyBus:Notify("objectives") end,
      },

      behaviorHeader = { type = "header", name = "Behavior", order = 40 },

      autoCollapseCompleted = {
        type = "toggle",
        name = "Auto-collapse completed quests",
        order = 41,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.autoCollapseCompleted end,
        set = function(_, v) db.autoCollapseCompleted = v and true or false; ETBC.ApplyBus:Notify("objectives") end,
      },

      onlyCollapseInDungeons = {
        type = "toggle",
        name = "Only auto-collapse in dungeons/raids",
        order = 42,
        width = "full",
        disabled = function() return not (db.enabled and db.autoCollapseCompleted) end,
        get = function() return db.onlyCollapseInDungeons end,
        set = function(_, v) db.onlyCollapseInDungeons = v and true or false; ETBC.ApplyBus:Notify("objectives") end,
      },
    }
  end,
})

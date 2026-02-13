-- Settings/Settings_Visibility.lua
-- Global visibility rules engine settings for EnhanceTBC.
-- Provides reusable rule presets + a “Custom Rule” builder other modules can reuse.

local ADDON_NAME, ETBC = ...

local function GetDB()
  ETBC.db.profile.visibility = ETBC.db.profile.visibility or {}
  local db = ETBC.db.profile.visibility

  if db.enabled == nil then db.enabled = true end

  -- Global update throttle (prevents rapid spam from multiple events)
  if db.throttle == nil then db.throttle = 0.05 end

  -- Presets usable by any module (string key -> rule table)
  db.presets = db.presets or {}

  local function EnsurePreset(key, rule)
    if not db.presets[key] then
      db.presets[key] = rule
    end
  end

  -- Minimal, useful defaults
  EnsurePreset("ALWAYS", {
    name = "Always",
    enabled = true,
    mode = "ALWAYS",
  })

  EnsurePreset("COMBAT", {
    name = "Only in combat",
    enabled = true,
    mode = "CUSTOM",
    requireCombat = true,
  })

  EnsurePreset("OUT_OF_COMBAT", {
    name = "Only out of combat",
    enabled = true,
    mode = "CUSTOM",
    requireOutOfCombat = true,
  })

  EnsurePreset("INSTANCE", {
    name = "Only in instances",
    enabled = true,
    mode = "CUSTOM",
    instance = { party = true, raid = true, scenario = true, arena = true, pvp = true },
  })

  EnsurePreset("GROUP", {
    name = "Only in group (party or raid)",
    enabled = true,
    mode = "CUSTOM",
    requireGroup = true,
  })

  EnsurePreset("RAID", {
    name = "Only in raid",
    enabled = true,
    mode = "CUSTOM",
    requireRaid = true,
  })

  EnsurePreset("PARTY", {
    name = "Only in party (not raid)",
    enabled = true,
    mode = "CUSTOM",
    requireParty = true,
  })

  EnsurePreset("RESTING", {
    name = "Only while resting",
    enabled = true,
    mode = "CUSTOM",
    requireResting = true,
  })

  EnsurePreset("MOUNTED", {
    name = "Only while mounted",
    enabled = true,
    mode = "CUSTOM",
    requireMounted = true,
  })

  -- Editor scratchpad (for modules to copy into their own settings if desired)
  db.editor = db.editor or {
    enabled = true,
    mode = "CUSTOM",

    -- Combat
    requireCombat = false,
    requireOutOfCombat = false,

    -- Group
    requireGroup = false,
    requireParty = false,
    requireRaid = false,

    -- Player states
    requireResting = false,
    requireMounted = false,
    requireDead = false,
    requireAlive = false,

    -- Targets
    requireTarget = false,
    requireNoTarget = false,

    -- Instances
    instance = { world = false, party = false, raid = false, arena = false, pvp = false, scenario = false },

    -- Advanced
    invert = false, -- invert final result
  }

  return db
end

local INSTANCE_LABELS = {
  world = "Open World",
  party = "Dungeon (5-man)",
  raid = "Raid",
  arena = "Arena",
  pvp = "Battleground",
  scenario = "Scenario",
}

ETBC.SettingsRegistry:RegisterGroup("visibility", {
  name = "Visibility",
  order = 70,
  options = function()
    local db = GetDB()

    return {
      enabled = {
        type = "toggle",
        name = "Enable Visibility engine",
        desc = "Provides shared visibility checks and optional auto show/hide binding for modules.",
        order = 1,
        width = "full",
        get = function() return db.enabled end,
        set = function(_, v)
          db.enabled = v and true or false
          ETBC.ApplyBus:Notify("visibility")
        end,
      },

      throttle = {
        type = "range",
        name = "Update throttle",
        desc = "Prevents rapid re-evaluations from multiple events. Keep low for responsiveness.",
        order = 2,
        min = 0.00, max = 0.50, step = 0.01,
        disabled = function() return not db.enabled end,
        get = function() return db.throttle end,
        set = function(_, v)
          db.throttle = v
          ETBC.ApplyBus:Notify("visibility")
        end,
      },

      presetsHeader = {
        type = "header",
        name = "Presets (Reusable)",
        order = 10,
      },

      presetsInfo = {
        type = "description",
        name = "Presets are shared visibility rules that other modules can reference.\nThis page also provides a “Rule Editor” you can use as a template when building per-module visibility options later.",
        order = 11,
      },

      editorHeader = {
        type = "header",
        name = "Rule Editor (Template)",
        order = 20,
      },

      requireCombat = {
        type = "toggle",
        name = "Require: In combat",
        order = 21,
        width = "full",
        disabled = function() return not (db.enabled and db.editor) end,
        get = function() return db.editor.requireCombat end,
        set = function(_, v) db.editor.requireCombat = v and true or false; ETBC.ApplyBus:Notify("visibility") end,
      },

      requireOutOfCombat = {
        type = "toggle",
        name = "Require: Out of combat",
        order = 22,
        width = "full",
        disabled = function() return not (db.enabled and db.editor) end,
        get = function() return db.editor.requireOutOfCombat end,
        set = function(_, v) db.editor.requireOutOfCombat = v and true or false; ETBC.ApplyBus:Notify("visibility") end,
      },

      requireGroup = {
        type = "toggle",
        name = "Require: In group (party or raid)",
        order = 23,
        width = "full",
        disabled = function() return not (db.enabled and db.editor) end,
        get = function() return db.editor.requireGroup end,
        set = function(_, v) db.editor.requireGroup = v and true or false; ETBC.ApplyBus:Notify("visibility") end,
      },

      requireParty = {
        type = "toggle",
        name = "Require: In party (not raid)",
        order = 24,
        width = "full",
        disabled = function() return not (db.enabled and db.editor) end,
        get = function() return db.editor.requireParty end,
        set = function(_, v) db.editor.requireParty = v and true or false; ETBC.ApplyBus:Notify("visibility") end,
      },

      requireRaid = {
        type = "toggle",
        name = "Require: In raid",
        order = 25,
        width = "full",
        disabled = function() return not (db.enabled and db.editor) end,
        get = function() return db.editor.requireRaid end,
        set = function(_, v) db.editor.requireRaid = v and true or false; ETBC.ApplyBus:Notify("visibility") end,
      },

      requireResting = {
        type = "toggle",
        name = "Require: Resting",
        order = 26,
        width = "full",
        disabled = function() return not (db.enabled and db.editor) end,
        get = function() return db.editor.requireResting end,
        set = function(_, v) db.editor.requireResting = v and true or false; ETBC.ApplyBus:Notify("visibility") end,
      },

      requireMounted = {
        type = "toggle",
        name = "Require: Mounted",
        order = 27,
        width = "full",
        disabled = function() return not (db.enabled and db.editor) end,
        get = function() return db.editor.requireMounted end,
        set = function(_, v) db.editor.requireMounted = v and true or false; ETBC.ApplyBus:Notify("visibility") end,
      },

      requireDead = {
        type = "toggle",
        name = "Require: Dead/ghost",
        order = 28,
        width = "full",
        disabled = function() return not (db.enabled and db.editor) end,
        get = function() return db.editor.requireDead end,
        set = function(_, v) db.editor.requireDead = v and true or false; ETBC.ApplyBus:Notify("visibility") end,
      },

      requireAlive = {
        type = "toggle",
        name = "Require: Alive",
        order = 29,
        width = "full",
        disabled = function() return not (db.enabled and db.editor) end,
        get = function() return db.editor.requireAlive end,
        set = function(_, v) db.editor.requireAlive = v and true or false; ETBC.ApplyBus:Notify("visibility") end,
      },

      requireTarget = {
        type = "toggle",
        name = "Require: Have target",
        order = 30,
        width = "full",
        disabled = function() return not (db.enabled and db.editor) end,
        get = function() return db.editor.requireTarget end,
        set = function(_, v) db.editor.requireTarget = v and true or false; ETBC.ApplyBus:Notify("visibility") end,
      },

      requireNoTarget = {
        type = "toggle",
        name = "Require: No target",
        order = 31,
        width = "full",
        disabled = function() return not (db.enabled and db.editor) end,
        get = function() return db.editor.requireNoTarget end,
        set = function(_, v) db.editor.requireNoTarget = v and true or false; ETBC.ApplyBus:Notify("visibility") end,
      },

      instanceHeader = {
        type = "header",
        name = "Instance Types",
        order = 40,
      },

      instanceDesc = {
        type = "description",
        name = "If you check any instance type, the rule requires you to be in one of the selected types.\nIf none are checked, instance type is ignored.",
        order = 41,
      },

      instanceWorld = {
        type = "toggle",
        name = INSTANCE_LABELS.world,
        order = 42,
        disabled = function() return not (db.enabled and db.editor) end,
        get = function() return db.editor.instance.world end,
        set = function(_, v) db.editor.instance.world = v and true or false; ETBC.ApplyBus:Notify("visibility") end,
      },

      instanceParty = {
        type = "toggle",
        name = INSTANCE_LABELS.party,
        order = 43,
        disabled = function() return not (db.enabled and db.editor) end,
        get = function() return db.editor.instance.party end,
        set = function(_, v) db.editor.instance.party = v and true or false; ETBC.ApplyBus:Notify("visibility") end,
      },

      instanceRaid = {
        type = "toggle",
        name = INSTANCE_LABELS.raid,
        order = 44,
        disabled = function() return not (db.enabled and db.editor) end,
        get = function() return db.editor.instance.raid end,
        set = function(_, v) db.editor.instance.raid = v and true or false; ETBC.ApplyBus:Notify("visibility") end,
      },

      instanceArena = {
        type = "toggle",
        name = INSTANCE_LABELS.arena,
        order = 45,
        disabled = function() return not (db.enabled and db.editor) end,
        get = function() return db.editor.instance.arena end,
        set = function(_, v) db.editor.instance.arena = v and true or false; ETBC.ApplyBus:Notify("visibility") end,
      },

      instancePVP = {
        type = "toggle",
        name = INSTANCE_LABELS.pvp,
        order = 46,
        disabled = function() return not (db.enabled and db.editor) end,
        get = function() return db.editor.instance.pvp end,
        set = function(_, v) db.editor.instance.pvp = v and true or false; ETBC.ApplyBus:Notify("visibility") end,
      },

      instanceScenario = {
        type = "toggle",
        name = INSTANCE_LABELS.scenario,
        order = 47,
        disabled = function() return not (db.enabled and db.editor) end,
        get = function() return db.editor.instance.scenario end,
        set = function(_, v) db.editor.instance.scenario = v and true or false; ETBC.ApplyBus:Notify("visibility") end,
      },

      invert = {
        type = "toggle",
        name = "Invert result",
        desc = "If enabled, the final rule result is flipped (show becomes hide and vice versa).",
        order = 60,
        width = "full",
        disabled = function() return not (db.enabled and db.editor) end,
        get = function() return db.editor.invert end,
        set = function(_, v) db.editor.invert = v and true or false; ETBC.ApplyBus:Notify("visibility") end,
      },
    }
  end,
})

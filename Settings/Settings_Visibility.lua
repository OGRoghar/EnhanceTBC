-- Settings/Settings_Visibility.lua
local ADDON_NAME, ETBC = ...

local function EnsureDB()
  if not ETBC.db or not ETBC.db.profile then return nil end

  ETBC.db.profile.visibility = ETBC.db.profile.visibility or {}
  local db = ETBC.db.profile.visibility

  if db.enabled == nil then db.enabled = true end

  db.global = db.global or {}
  local g = db.global
  if g.enabled == nil then g.enabled = true end
  if g.inCombat == nil then g.inCombat = false end
  if g.outOfCombat == nil then g.outOfCombat = false end
  if g.inInstance == nil then g.inInstance = false end
  if g.inRaid == nil then g.inRaid = false end
  if g.inParty == nil then g.inParty = false end
  if g.solo == nil then g.solo = false end
  if g.inBattleground == nil then g.inBattleground = false end

  db.modules = db.modules or {}

  return db
end

local function Notify()
  if ETBC.ApplyBus and ETBC.ApplyBus.Notify then
    ETBC.ApplyBus:Notify("visibility")
  end
end

local function NewCondGroup(name, getT, setT, orderBase)
  local function Toggle(key, label, order)
    return {
      type = "toggle",
      name = label,
      order = order,
      width = "full",
      get = function()
        local t = getT()
        return (t and t[key]) and true or false
      end,
      set = function(_, v)
        local t = setT()
        if t then t[key] = v and true or false end
        Notify()
      end,
    }
  end

  return {
    type = "group",
    name = name,
    inline = true,
    order = orderBase,
    args = {
      enabled        = Toggle("enabled",        "Enable these conditions", 1),
      inCombat       = Toggle("inCombat",       "Only in combat",          10),
      outOfCombat    = Toggle("outOfCombat",    "Only out of combat",      11),
      inInstance     = Toggle("inInstance",     "Only in instances",       12),
      inRaid         = Toggle("inRaid",         "Only in raids",           13),
      inParty        = Toggle("inParty",        "Only in party",           14),
      solo           = Toggle("solo",           "Only when solo",          15),
      inBattleground = Toggle("inBattleground", "Only in battlegrounds",   16),
    },
  }
end

local function GetKnownModules()
  return {
    { key = "auras",         name = "Auras" },
    { key = "actiontracker", name = "ActionTracker" },
    { key = "combattext",    name = "CombatText" },
    { key = "gcdbar",        name = "GCD Bar" },
    { key = "tooltip",       name = "Tooltip" },
    { key = "mouse",         name = "Mouse" },
    { key = "vendor",        name = "Vendor" },
    { key = "mailbox",       name = "Mailbox" },
    { key = "chatim",        name = "ChatIM" },
    { key = "friends",       name = "Friends" },
    { key = "ui",            name = "UI" },
    { key = "unitframes",    name = "UnitFrames" },
    { key = "castbar",       name = "Castbar" },
    { key = "actionbars",    name = "ActionBars" },
    { key = "minimap",       name = "Minimap" },
    { key = "sound",         name = "Sound" },
  }
end

ETBC.SettingsRegistry:RegisterGroup("visibility", {
  name = "Visibility",
  order = 6,
  options = function()
    local db = EnsureDB()
    if not db then
      return {
        _msg = {
          type = "description",
          name = "Visibility is not ready yet (database not initialized). Reload if this persists.",
          order = 1,
        },
      }
    end

    local args = {}

    args.enabled = {
      type = "toggle",
      name = "Enable Visibility system",
      desc = "Master toggle. When off, modules should behave normally.",
      order = 1,
      width = "full",
      get = function() return db.enabled and true or false end,
      set = function(_, v)
        db.enabled = v and true or false
        Notify()
      end,
    }

    args.note = {
      type = "description",
      name = "Tip: If you enable multiple conditions at once, they are treated as AND (must all match).",
      order = 2,
    }

    args.globalHeader = { type = "header", name = "Global Conditions", order = 9 }

    args.global = NewCondGroup(
      "Global Conditions (default)",
      function() return db.global end,
      function() db.global = db.global or {}; return db.global end,
      10
    )

    args.perModuleHeader = { type = "header", name = "Per-Module Overrides", order = 49 }

    local modGroupArgs = {}
    local mods = GetKnownModules()

    for i, m in ipairs(mods) do
      local key = m.key
      local name = m.name

      db.modules[key] = db.modules[key] or {
        enabled = false,
        inCombat = false,
        outOfCombat = false,
        inInstance = false,
        inRaid = false,
        inParty = false,
        solo = false,
        inBattleground = false,
      }

      modGroupArgs[key] = NewCondGroup(
        name,
        function() return db.modules[key] end,
        function() db.modules[key] = db.modules[key] or {}; return db.modules[key] end,
        i
      )
    end

    args.modules = {
      type = "group",
      name = "Overrides",
      order = 50,
      args = modGroupArgs,
    }

    args.toolsHeader = { type = "header", name = "Tools", order = 90 }

    args.resetOverrides = {
      type = "execute",
      name = "Reset all overrides",
      desc = "Turns off per-module overrides (global remains).",
      order = 91,
      func = function()
        db.modules = {}
        Notify()
      end,
    }

    return args
  end,
})

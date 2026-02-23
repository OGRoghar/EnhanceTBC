-- Settings/Settings_Visibility.lua
-- Shared visibility engine settings.

local _, ETBC = ...

local MODULE_KEYS = {
  "auras",
  "actiontracker",
  "combattext",
  "objectives",
}

local MODULE_LABELS = {
  auras = "Auras",
  actiontracker = "Action Tracker",
  combattext = "Combat Text",
  objectives = "Objectives",
}

local function GetDB()
  ETBC.db.profile.visibility = ETBC.db.profile.visibility or {}
  local db = ETBC.db.profile.visibility

  if db.enabled == nil then db.enabled = true end
  if db.throttle == nil then db.throttle = 0.05 end
  db.presets = db.presets or {}
  db.modulePresets = db.modulePresets or {}

  local function EnsurePreset(key, rule)
    if not db.presets[key] then
      db.presets[key] = rule
    end
  end

  -- Built-in presets consumed by ETBC.Visibility:Evaluate("<KEY>")
  EnsurePreset("ALWAYS", { name = "Always", enabled = true, mode = "ALWAYS" })
  EnsurePreset("COMBAT", { name = "Only in combat", enabled = true, mode = "CUSTOM", requireCombat = true })
  EnsurePreset("OUT_OF_COMBAT", {
    name = "Only out of combat", enabled = true, mode = "CUSTOM", requireOutOfCombat = true,
  })
  EnsurePreset("INSTANCE", {
    name = "Only in instances",
    enabled = true,
    mode = "CUSTOM",
    instance = { party = true, raid = true, arena = true, pvp = true, scenario = true },
  })
  EnsurePreset("GROUP", { name = "Only in group", enabled = true, mode = "CUSTOM", requireGroup = true })
  EnsurePreset("RAID", { name = "Only in raid", enabled = true, mode = "CUSTOM", requireRaid = true })
  EnsurePreset("PARTY", { name = "Only in party (not raid)", enabled = true, mode = "CUSTOM", requireParty = true })

  for i = 1, #MODULE_KEYS do
    local key = MODULE_KEYS[i]
    if db.modulePresets[key] == nil then
      db.modulePresets[key] = "NONE"
    end
  end

  return db
end

ETBC.SettingsRegistry:RegisterGroup("visibility", {
  name = "Visibility",
  order = 70,
  options = function()
    local db = GetDB()

    local function PresetValues()
      local values = { NONE = "Use legacy/global rules" }
      local ordered = { "ALWAYS", "COMBAT", "OUT_OF_COMBAT", "INSTANCE", "GROUP", "RAID", "PARTY" }
      for i = 1, #ordered do
        local key = ordered[i]
        local p = db.presets[key]
        local name = (p and p.name) or key
        values[key] = ("%s (%s)"):format(name, key)
      end
      return values
    end

    local function PreviewSummary()
      local vis = ETBC.Modules and ETBC.Modules.Visibility
      if not vis or not vis.Allowed then
        return "Visibility module not loaded."
      end

      local lines = { "Current module visibility:" }
      for i = 1, #MODULE_KEYS do
        local key = MODULE_KEYS[i]
        local label = MODULE_LABELS[key] or key
        local preset = db.modulePresets[key] or "NONE"
        local allowed = vis:Allowed(key)
        lines[#lines + 1] = ("- %s: %s (preset: %s)"):format(label, allowed and "ALLOWED" or "BLOCKED", preset)
      end
      return table.concat(lines, "\n")
    end

    local function NotifyVisibility()
      if ETBC.ApplyBus and ETBC.ApplyBus.Notify then
        ETBC.ApplyBus:Notify("visibility")
      end
    end

    local function PrintSummary(text)
      if ETBC and ETBC.Print then
        ETBC:Print(text)
      elseif DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99EnhanceTBC|r " .. tostring(text))
      end
    end

    local function PresetSummary()
      local lines = {}
      local ordered = { "ALWAYS", "COMBAT", "OUT_OF_COMBAT", "INSTANCE", "GROUP", "RAID", "PARTY" }
      for i = 1, #ordered do
        local key = ordered[i]
        local p = db.presets[key]
        if p and p.name then
          lines[#lines + 1] = ("- %s: %s"):format(key, p.name)
        end
      end
      return table.concat(lines, "\n")
    end

    return {
      enabled = {
        type = "toggle",
        name = "Enable Visibility Engine",
        desc = "Provides shared visibility evaluation and frame binding APIs.",
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
        name = "Update Throttle",
        desc = "Delay between visibility refresh passes after state changes.",
        order = 2,
        min = 0.00, max = 0.50, step = 0.01,
        disabled = function() return not db.enabled end,
        get = function() return db.throttle end,
        set = function(_, v)
          db.throttle = tonumber(v) or 0.05
          ETBC.ApplyBus:Notify("visibility")
        end,
      },
      presetsHeader = {
        type = "header",
        name = "Built-In Presets",
        order = 10,
      },
      presetsInfo = {
        type = "description",
        name = "These preset keys can be used by modules through ETBC.Visibility:Evaluate(\"KEY\").\n\n"
          .. PresetSummary(),
        order = 11,
      },
      notes = {
        type = "description",
        name = "Per-module legacy rule editing remains in profile data for compatibility. "
          .. "Use module preset selectors below for active visibility control.",
        order = 12,
      },

      moduleHeader = {
        type = "header",
        name = "Module Presets",
        order = 20,
      },

      moduleInfo = {
        type = "description",
        name = "Assign a preset to each module. \"Use legacy/global rules\" keeps current compatibility behavior.",
        order = 21,
      },

      moduleAuras = {
        type = "select",
        name = "Auras",
        order = 22,
        values = PresetValues,
        disabled = function() return not db.enabled end,
        get = function() return db.modulePresets.auras or "NONE" end,
        set = function(_, v) db.modulePresets.auras = v; NotifyVisibility() end,
      },

      moduleActionTracker = {
        type = "select",
        name = "Action Tracker",
        order = 23,
        values = PresetValues,
        disabled = function() return not db.enabled end,
        get = function() return db.modulePresets.actiontracker or "NONE" end,
        set = function(_, v) db.modulePresets.actiontracker = v; NotifyVisibility() end,
      },

      moduleCombatText = {
        type = "select",
        name = "Combat Text",
        order = 24,
        values = PresetValues,
        disabled = function() return not db.enabled end,
        get = function() return db.modulePresets.combattext or "NONE" end,
        set = function(_, v) db.modulePresets.combattext = v; NotifyVisibility() end,
      },

      moduleObjectives = {
        type = "select",
        name = "Objectives",
        order = 25,
        values = PresetValues,
        disabled = function() return not db.enabled end,
        get = function() return db.modulePresets.objectives or "NONE" end,
        set = function(_, v) db.modulePresets.objectives = v; NotifyVisibility() end,
      },

      previewHeader = {
        type = "header",
        name = "Preview",
        order = 30,
      },

      previewNow = {
        type = "execute",
        name = "Preview current visibility",
        order = 31,
        disabled = function() return not db.enabled end,
        func = function()
          local summary = PreviewSummary()
          PrintSummary(summary)
        end,
      },

      previewText = {
        type = "description",
        name = function()
          return PreviewSummary()
        end,
        order = 32,
      },
    }
  end,
})



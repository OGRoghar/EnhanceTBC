-- Settings/Settings_Visibility.lua
-- Shared visibility engine settings.

local _, ETBC = ...

local function GetDB()
  ETBC.db.profile.visibility = ETBC.db.profile.visibility or {}
  local db = ETBC.db.profile.visibility

  if db.enabled == nil then db.enabled = true end
  if db.throttle == nil then db.throttle = 0.05 end
  db.presets = db.presets or {}

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

  return db
end

ETBC.SettingsRegistry:RegisterGroup("visibility", {
  name = "Visibility",
  order = 70,
  options = function()
    local db = GetDB()

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
        name = "Per-module visibility editors were removed from this page "
          .. "because they were template-only and not wired to active modules in this branch.",
        order = 12,
      },
    }
  end,
})



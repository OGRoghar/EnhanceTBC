-- Settings/Settings_ActionTracker.lua
local _, ETBC = ...
local LSM = ETBC.media

local function OutlineValues()
  return {
    NONE = "None",
    OUTLINE = "Outline",
    THICKOUTLINE = "Thick Outline",
    MONOCHROMEOUTLINE = "Mono + Outline",
  }
end

local function FontValues()
  local out = {}
  if LSM and LSM.HashTable then
    out = LSM:HashTable(ETBC.LSM_FONTS) or {}
  end
  out["Friz Quadrata TT"] = out["Friz Quadrata TT"] or "Friz Quadrata TT"
  return out
end

local function EnsureDefaults()
  if not ETBC.db or not ETBC.db.profile then return end
  ETBC.db.profile.actiontracker = ETBC.db.profile.actiontracker or {}
  local db = ETBC.db.profile.actiontracker
  db.anchor = db.anchor or {}
  db.border = db.border or {}
  db.border.color = db.border.color or {}
  db.nameText = db.nameText or {}
  db.nameText.color = db.nameText.color or {}
end

ETBC.SettingsRegistry:RegisterGroup("actiontracker", {
  name = "ActionTracker",
  order = 9,
  options = function()
    EnsureDefaults()
    local db = ETBC.db.profile.actiontracker

    return {
      enabled = {
        type = "toggle",
        name = "Enable ActionTracker",
        order = 1,
        get = function() return db.enabled end,
        set = function(_, v) db.enabled = v and true or false; ETBC.ApplyBus:Notify("actiontracker") end,
      },

      preview = {
        type = "toggle",
        name = "Preview Mode",
        desc = "Shows dummy actions so you can position and style the tracker.",
        order = 2,
        get = function() return db.preview end,
        set = function(_, v) db.preview = v and true or false; ETBC.ApplyBus:Notify("actiontracker") end,
      },

      tracking = {
        type = "group",
        name = "Tracking",
        order = 10,
        inline = true,
        args = {
          trackSpells = {
            type = "toggle",
            name = "Track Spells",
            order = 1,
            get = function() return db.trackSpells end,
            set = function(_, v) db.trackSpells = v and true or false; ETBC.ApplyBus:Notify("actiontracker") end,
          },
          trackItems = {
            type = "toggle",
            name = "Track Items (later)",
            desc = "Reserved for item-use tracking. Currently off by default.",
            order = 2,
            get = function() return db.trackItems end,
            set = function(_, v) db.trackItems = v and true or false; ETBC.ApplyBus:Notify("actiontracker") end,
          },
          onlyPlayer = {
            type = "toggle",
            name = "Only Player",
            desc = "Only track your own actions (recommended).",
            order = 3,
            get = function() return db.onlyPlayer end,
            set = function(_, v) db.onlyPlayer = v and true or false; ETBC.ApplyBus:Notify("actiontracker") end,
          },
          maxEntries = {
            type = "range",
            name = "Max Entries",
            order = 4,
            min = 1, max = 20, step = 1,
            get = function() return db.maxEntries end,
            set = function(_, v) db.maxEntries = v; ETBC.ApplyBus:Notify("actiontracker") end,
          },
          lifetime = {
            type = "range",
            name = "Entry Lifetime (sec)",
            order = 5,
            min = 2, max = 30, step = 1,
            get = function() return db.lifetime end,
            set = function(_, v) db.lifetime = v; ETBC.ApplyBus:Notify("actiontracker") end,
          },
        },
      },

      layout = {
        type = "group",
        name = "Layout",
        order = 20,
        inline = true,
        args = {
          iconSize = {
            type = "range",
            name = "Icon Size",
            order = 1,
            min = 16, max = 64, step = 1,
            get = function() return db.iconSize end,
            set = function(_, v) db.iconSize = v; ETBC.ApplyBus:Notify("actiontracker") end,
          },
          spacing = {
            type = "range",
            name = "Spacing",
            order = 2,
            min = 0, max = 20, step = 1,
            get = function() return db.spacing end,
            set = function(_, v) db.spacing = v; ETBC.ApplyBus:Notify("actiontracker") end,
          },
          perRow = {
            type = "range",
            name = "Icons Per Row",
            order = 3,
            min = 1, max = 20, step = 1,
            get = function() return db.perRow end,
            set = function(_, v) db.perRow = v; ETBC.ApplyBus:Notify("actiontracker") end,
          },
          growthX = {
            type = "select",
            name = "Horizontal Growth",
            order = 4,
            values = { LEFT = "Left", RIGHT = "Right" },
            get = function() return db.growthX end,
            set = function(_, v) db.growthX = v; ETBC.ApplyBus:Notify("actiontracker") end,
          },
          growthY = {
            type = "select",
            name = "Vertical Growth",
            order = 5,
            values = { DOWN = "Down", UP = "Up" },
            get = function() return db.growthY end,
            set = function(_, v) db.growthY = v; ETBC.ApplyBus:Notify("actiontracker") end,
          },
        },
      },

      visuals = {
        type = "group",
        name = "Visuals",
        order = 30,
        inline = true,
        args = {
          showCooldownSpiral = {
            type = "toggle",
            name = "Show Cooldown Spiral",
            order = 1,
            get = function() return db.showCooldownSpiral end,
            set = function(_, v) db.showCooldownSpiral = v and true or false; ETBC.ApplyBus:Notify("actiontracker") end,
          },
          borderEnabled = {
            type = "toggle",
            name = "Enable Borders",
            order = 2,
            get = function() return db.border.enabled end,
            set = function(_, v) db.border.enabled = v and true or false; ETBC.ApplyBus:Notify("actiontracker") end,
          },
          borderColor = {
            type = "color",
            name = "Border Color",
            order = 3,
            hasAlpha = true,
            get = function()
              local c = db.border.color
              return c.r, c.g, c.b, (c.a or 1)
            end,
            set = function(_, r, g, b, a)
              local c = db.border.color
              c.r, c.g, c.b, c.a = r, g, b, a
              ETBC.ApplyBus:Notify("actiontracker")
            end,
            disabled = function() return not db.border.enabled end,
          },
          showName = {
            type = "toggle",
            name = "Show Spell Name",
            order = 4,
            get = function() return db.showName end,
            set = function(_, v) db.showName = v and true or false; ETBC.ApplyBus:Notify("actiontracker") end,
          },
          nameFont = {
            type = "select",
            name = "Name Font",
            order = 5,
            values = FontValues,
            get = function() return db.nameText.font end,
            set = function(_, v) db.nameText.font = v; ETBC.ApplyBus:Notify("actiontracker") end,
            disabled = function() return not db.showName end,
          },
          nameSize = {
            type = "range",
            name = "Name Size",
            order = 6,
            min = 8, max = 24, step = 1,
            get = function() return db.nameText.size end,
            set = function(_, v) db.nameText.size = v; ETBC.ApplyBus:Notify("actiontracker") end,
            disabled = function() return not db.showName end,
          },
          nameOutline = {
            type = "select",
            name = "Name Outline",
            order = 7,
            values = OutlineValues,
            get = function() return db.nameText.outline end,
            set = function(_, v) db.nameText.outline = v; ETBC.ApplyBus:Notify("actiontracker") end,
            disabled = function() return not db.showName end,
          },
          nameClassColor = {
            type = "toggle",
            name = "Class Color Name",
            order = 8,
            get = function() return db.nameText.classColor end,
            set = function(_, v)
              db.nameText.classColor = v and true or false
              ETBC.ApplyBus:Notify("actiontracker")
            end,
            disabled = function() return not db.showName end,
          },
          nameColor = {
            type = "color",
            name = "Name Color",
            order = 9,
            hasAlpha = true,
            get = function()
              local c = db.nameText.color
              return c.r, c.g, c.b, (c.a or 1)
            end,
            set = function(_, r, g, b, a)
              local c = db.nameText.color
              c.r, c.g, c.b, c.a = r, g, b, a
              ETBC.ApplyBus:Notify("actiontracker")
            end,
            disabled = function() return (not db.showName) or db.nameText.classColor end,
          },
        },
      },
    }
  end,
})

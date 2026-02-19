-- Settings/Settings_CombatText.lua
local _, ETBC = ...
local LSM = ETBC.media

local function FontValues()
  local out = {}
  if LSM and LSM.HashTable then
    out = LSM:HashTable(ETBC.LSM_FONTS) or {}
  end
  out["Friz Quadrata TT"] = out["Friz Quadrata TT"] or "Friz Quadrata TT"
  return out
end

local function OutlineValues()
  return {
    NONE = "None",
    OUTLINE = "Outline",
    THICKOUTLINE = "Thick Outline",
    MONOCHROMEOUTLINE = "Mono + Outline",
  }
end

local function FloatDirValues()
  return { UP = "Up", DOWN = "Down" }
end

local function EnsureDefaults()
  if not ETBC.db or not ETBC.db.profile then return end
  ETBC.db.profile.combattext = ETBC.db.profile.combattext or {}
  local db = ETBC.db.profile.combattext
  db.crit = db.crit or {}
  db.crit.color = db.crit.color or {}
  db.blizzard = db.blizzard or {}
  db.anchor = db.anchor or {}
  db.overrideColor = db.overrideColor or {}
end

ETBC.SettingsRegistry:RegisterGroup("combattext", {
  name = "CombatText",
  order = 12,
  options = function()
    EnsureDefaults()
    local db = ETBC.db.profile.combattext

    return {
      enabled = {
        type = "toggle",
        name = "Enable CombatText",
        order = 1,
        get = function() return db.enabled end,
        set = function(_, v) db.enabled = v and true or false; ETBC.ApplyBus:Notify("combattext") end,
      },

      preview = {
        type = "toggle",
        name = "Preview Mode",
        order = 2,
        get = function() return db.preview end,
        set = function(_, v) db.preview = v and true or false; ETBC.ApplyBus:Notify("combattext") end,
      },

      blizzard = {
        type = "group",
        name = "Blizzard Combat Text",
        order = 5,
        inline = true,
        args = {
          disableBlizzardFCT = {
            type = "toggle",
            name = "Disable Blizzard Floating Combat Text while enabled",
            desc = "Prevents double combat text (Blizzard + addon).",
            order = 1,
            get = function() return db.blizzard.disableBlizzardFCT end,
            set = function(_, v)
              db.blizzard.disableBlizzardFCT = v and true or false
              ETBC.ApplyBus:Notify("combattext")
            end,
          },
          restoreOnDisable = {
            type = "toggle",
            name = "Restore Blizzard settings when disabled",
            order = 2,
            get = function() return db.blizzard.restoreOnDisable end,
            set = function(_, v)
              db.blizzard.restoreOnDisable = v and true or false
              ETBC.ApplyBus:Notify("combattext")
            end,
            disabled = function() return not db.blizzard.disableBlizzardFCT end,
          },
        },
      },

      tracking = {
        type = "group",
        name = "Tracking",
        order = 6,
        inline = true,
        args = {
          trackOutgoing = {
            type = "toggle", name = "Track Outgoing", order = 1,
            get = function() return db.trackOutgoing end,
            set = function(_, v) db.trackOutgoing = v and true or false; ETBC.ApplyBus:Notify("combattext") end,
          },
          trackIncoming = {
            type = "toggle", name = "Track Incoming", order = 2,
            get = function() return db.trackIncoming end,
            set = function(_, v) db.trackIncoming = v and true or false; ETBC.ApplyBus:Notify("combattext") end,
          },
          showDirection = {
            type = "toggle", name = "Show IN/OUT Prefix", order = 3,
            get = function() return db.showDirection end,
            set = function(_, v) db.showDirection = v and true or false; ETBC.ApplyBus:Notify("combattext") end,
          },
          splitDirections = {
            type = "toggle",
            name = "Split Directions (Incoming opposite)",
            order = 4,
            get = function() return db.splitDirections end,
            set = function(_, v) db.splitDirections = v and true or false; ETBC.ApplyBus:Notify("combattext") end,
            disabled = function() return not db.trackIncoming end,
          },
        },
      },

      content = {
        type = "group",
        name = "Content",
        order = 20,
        inline = true,
        args = {
          showDamage = {
            type = "toggle", name = "Damage", order = 1,
            get = function() return db.showDamage end,
            set = function(_, v)
              db.showDamage = v and true or false
              ETBC.ApplyBus:Notify("combattext")
            end,
          },
          showHeals = {
            type = "toggle", name = "Heals", order = 2,
            get = function() return db.showHeals end,
            set = function(_, v)
              db.showHeals = v and true or false
              ETBC.ApplyBus:Notify("combattext")
            end,
          },
          showMisses = {
            type = "toggle", name = "Miss/Dodge/Parry", order = 3,
            get = function() return db.showMisses end,
            set = function(_, v)
              db.showMisses = v and true or false
              ETBC.ApplyBus:Notify("combattext")
            end,
          },
          showInterrupts = {
            type = "toggle", name = "Interrupts", order = 4,
            get = function() return db.showInterrupts end,
            set = function(_, v)
              db.showInterrupts = v and true or false
              ETBC.ApplyBus:Notify("combattext")
            end,
          },
          showDispels = {
            type = "toggle", name = "Dispels/Stolen", order = 5,
            get = function() return db.showDispels end,
            set = function(_, v)
              db.showDispels = v and true or false
              ETBC.ApplyBus:Notify("combattext")
            end,
          },

          showSpellName = {
            type = "toggle", name = "Show Spell Name", order = 6,
            get = function() return db.showSpellName end,
            set = function(_, v)
              db.showSpellName = v and true or false
              ETBC.ApplyBus:Notify("combattext")
            end,
          },
          showOverheal = {
            type = "toggle", name = "Show Overheal Tag", order = 7,
            get = function() return db.showOverheal end,
            set = function(_, v)
              db.showOverheal = v and true or false
              ETBC.ApplyBus:Notify("combattext")
            end,
          },
        },
      },

      spam = {
        type = "group",
        name = "Spam Control",
        order = 30,
        inline = true,
        args = {
          throttleWindow = {
            type = "range", name = "Throttle Window (sec)", order = 1,
            min = 0.05, max = 0.50, step = 0.01,
            get = function() return db.throttleWindow end,
            set = function(_, v) db.throttleWindow = v; ETBC.ApplyBus:Notify("combattext") end,
          },
          maxLines = {
            type = "range", name = "Max Lines", order = 2,
            min = 3, max = 20, step = 1,
            get = function() return db.maxLines end,
            set = function(_, v) db.maxLines = v; ETBC.ApplyBus:Notify("combattext") end,
          },
        },
      },

      anim = {
        type = "group",
        name = "Animation",
        order = 40,
        inline = true,
        args = {
          floatDirection = {
            type = "select", name = "Float Direction", order = 1,
            values = FloatDirValues,
            get = function() return db.floatDirection end,
            set = function(_, v) db.floatDirection = v; ETBC.ApplyBus:Notify("combattext") end,
          },
          floatDistance = {
            type = "range", name = "Float Distance", order = 2,
            min = 10, max = 180, step = 1,
            get = function() return db.floatDistance end,
            set = function(_, v) db.floatDistance = v; ETBC.ApplyBus:Notify("combattext") end,
          },
          duration = {
            type = "range", name = "Duration (sec)", order = 3,
            min = 0.6, max = 3.0, step = 0.05,
            get = function() return db.duration end,
            set = function(_, v) db.duration = v; ETBC.ApplyBus:Notify("combattext") end,
          },
          fadeStart = {
            type = "range", name = "Fade Start (sec)", order = 4,
            min = 0.1, max = 2.5, step = 0.05,
            get = function() return db.fadeStart end,
            set = function(_, v) db.fadeStart = v; ETBC.ApplyBus:Notify("combattext") end,
          },
          randomX = {
            type = "range", name = "Horizontal Spread", order = 5,
            min = 0, max = 120, step = 1,
            get = function() return db.randomX end,
            set = function(_, v) db.randomX = v; ETBC.ApplyBus:Notify("combattext") end,
          },
        },
      },

      visuals = {
        type = "group",
        name = "Visuals",
        order = 50,
        inline = true,
        args = {
          font = {
            type = "select", name = "Font", order = 1, values = FontValues,
            get = function() return db.font end,
            set = function(_, v) db.font = v; ETBC.ApplyBus:Notify("combattext") end,
          },
          size = {
            type = "range", name = "Size", order = 2, min = 10, max = 48, step = 1,
            get = function() return db.size end,
            set = function(_, v) db.size = v; ETBC.ApplyBus:Notify("combattext") end,
          },
          outline = {
            type = "select", name = "Outline", order = 3, values = OutlineValues,
            get = function() return db.outline end,
            set = function(_, v) db.outline = v; ETBC.ApplyBus:Notify("combattext") end,
          },
          shadow = {
            type = "toggle", name = "Shadow", order = 4,
            get = function() return db.shadow end,
            set = function(_, v) db.shadow = v and true or false; ETBC.ApplyBus:Notify("combattext") end,
          },

          classColor = {
            type = "toggle", name = "Use Class Color", order = 5,
            get = function() return db.classColor end,
            set = function(_, v) db.classColor = v and true or false; ETBC.ApplyBus:Notify("combattext") end,
          },
          useDamageColors = {
            type = "toggle", name = "Use Damage/Heal Colors", order = 6,
            get = function() return db.useDamageColors end,
            set = function(_, v) db.useDamageColors = v and true or false; ETBC.ApplyBus:Notify("combattext") end,
            disabled = function() return db.classColor end,
          },
          useSchoolColors = {
            type = "toggle", name = "Use School Colors", order = 7,
            get = function() return db.useSchoolColors end,
            set = function(_, v) db.useSchoolColors = v and true or false; ETBC.ApplyBus:Notify("combattext") end,
            disabled = function() return db.classColor end,
          },

          overrideColor = {
            type="color", name="Override Color", order=8, hasAlpha=true,
            get=function() local c=db.overrideColor; return c.r,c.g,c.b,(c.a or 1) end,
            set=function(_,r,g,b,a)
              local c=db.overrideColor
              c.r,c.g,c.b,c.a=r,g,b,a
              ETBC.ApplyBus:Notify("combattext")
            end,
            disabled=function() return db.classColor or db.useDamageColors or db.useSchoolColors end,
          },
        },
      },

      crit = {
        type = "group",
        name = "Crit Highlight",
        order = 60,
        inline = true,
        args = {
          enabled = {
            type = "toggle", name = "Enable", order = 1,
            get = function() return db.crit.enabled end,
            set = function(_, v) db.crit.enabled = v and true or false; ETBC.ApplyBus:Notify("combattext") end,
          },
          scale = {
            type = "range", name = "Scale", order = 2,
            min = 1.0, max = 2.5, step = 0.01,
            get = function() return db.crit.scale end,
            set = function(_, v) db.crit.scale = v; ETBC.ApplyBus:Notify("combattext") end,
            disabled = function() return not db.crit.enabled end,
          },
          useCritColor = {
            type = "toggle", name = "Use Crit Color", order = 3,
            get = function() return db.crit.useCritColor end,
            set = function(_, v) db.crit.useCritColor = v and true or false; ETBC.ApplyBus:Notify("combattext") end,
            disabled = function() return not db.crit.enabled end,
          },
          color = {
            type="color", name="Crit Color", order=4, hasAlpha=true,
            get=function() local c=db.crit.color; return c.r,c.g,c.b,(c.a or 1) end,
            set=function(_,r,g,b,a)
              local c=db.crit.color
              c.r,c.g,c.b,c.a=r,g,b,a
              ETBC.ApplyBus:Notify("combattext")
            end,
            disabled=function() return (not db.crit.enabled) or (not db.crit.useCritColor) end,
          },
        },
      },

      position = {
        type = "group",
        name = "Position",
        order = 70,
        inline = true,
        args = {
          hint = { type="description", name="Use /etbc move to reposition CombatText.", order=1 },
        },
      },
    }
  end,
})

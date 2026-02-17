-- Settings/Settings_Auras.lua
local ADDON_NAME, ETBC = ...
local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceTBC")
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

local function PointValues()
  return {
    TOPLEFT="TOPLEFT", TOP="TOP", TOPRIGHT="TOPRIGHT",
    LEFT="LEFT", CENTER="CENTER", RIGHT="RIGHT",
    BOTTOMLEFT="BOTTOMLEFT", BOTTOM="BOTTOM", BOTTOMRIGHT="BOTTOMRIGHT"
  }
end

ETBC.SettingsRegistry:RegisterGroup("auras", {
  name = "Auras",
  order = 8,
  options = function()
    local db = ETBC.db.profile.auras

    return {
      enabled = {
        type = "toggle",
        name = "Enable Auras",
        order = 1,
        get = function() return db.enabled end,
        set = function(_, v) db.enabled = v and true or false; ETBC.ApplyBus:Notify("auras") end,
      },

      preview = {
        type = "toggle",
        name = "Preview Mode",
        desc = "Show dummy auras for layout testing.",
        order = 2,
        get = function() return db.preview end,
        set = function(_, v) db.preview = v and true or false; ETBC.ApplyBus:Notify("auras") end,
      },

      mover = {
        type = "group",
        name = "Move Handles",
        order = 5,
        inline = true,
        args = {
          showMoveHandles = {
            type = "toggle",
            name = "Show Move Handles (Buffs/Debuffs)",
            desc = "Shows draggable boxes you can drag to reposition Buffs and Debuffs without typing X/Y. Turn OFF to hide them.",
            order = 1,
            get = function() return db.showMoveHandles end,
            set = function(_, v) db.showMoveHandles = v and true or false; ETBC.ApplyBus:Notify("auras") end,
          },
          moveSnapToGrid = {
            type = "toggle",
            name = "Snap to Mover Grid",
            desc = "Snaps drag to your mover grid size (default 8).",
            order = 2,
            get = function() return db.moveSnapToGrid end,
            set = function(_, v) db.moveSnapToGrid = v and true or false; ETBC.ApplyBus:Notify("auras") end,
            disabled = function() return not db.showMoveHandles end,
          },
        },
      },

      common = {
        type = "group",
        name = "Common",
        order = 10,
        inline = true,
        args = {
          playerOnly = {
            type = "toggle",
            name = "Player Only",
            desc = "Best-effort filter for auras applied by you. Some auras may not report caster reliably.",
            order = 1,
            get = function() return db.playerOnly end,
            set = function(_, v) db.playerOnly = v and true or false; ETBC.ApplyBus:Notify("auras") end,
          },
          useBlizzardTooltips = {
            type = "toggle",
            name = "Tooltip on Hover",
            order = 2,
            get = function() return db.useBlizzardTooltips end,
            set = function(_, v) db.useBlizzardTooltips = v and true or false; ETBC.ApplyBus:Notify("auras") end,
          },
        },
      },

      sorting = {
        type = "group",
        name = "Sorting",
        order = 20,
        inline = true,
        args = {
          sortMode = {
            type = "select",
            name = "Sort Mode",
            order = 1,
            values = { TIME = "Time Remaining", NAME = "Name" },
            get = function() return db.sortMode end,
            set = function(_, v) db.sortMode = v; ETBC.ApplyBus:Notify("auras") end,
          },
          sortAscending = {
            type = "toggle",
            name = "Ascending",
            desc = "Ascending = low-to-high (time) or A-to-Z (name).",
            order = 2,
            get = function() return db.sortAscending end,
            set = function(_, v) db.sortAscending = v and true or false; ETBC.ApplyBus:Notify("auras") end,
          },
        },
      },

      cooldowns = {
        type = "group",
        name = "Cooldowns",
        order = 30,
        inline = true,
        args = {
          showCooldownSpiral = {
            type = "toggle",
            name = "Show Cooldown Spiral",
            order = 1,
            get = function() return db.showCooldownSpiral end,
            set = function(_, v) db.showCooldownSpiral = v and true or false; ETBC.ApplyBus:Notify("auras") end,
          },
        },
      },

      borders = {
        type = "group",
        name = "Borders",
        order = 40,
        inline = true,
        args = {
          enabled = {
            type = "toggle",
            name = "Enable Borders",
            order = 1,
            get = function() return db.border.enabled end,
            set = function(_, v) db.border.enabled = v and true or false; ETBC.ApplyBus:Notify("auras") end,
          },
          color = {
            type = "color",
            name = "Border Color",
            order = 2,
            hasAlpha = true,
            get = function()
              local c = db.border.color
              return c.r, c.g, c.b, (c.a or 1)
            end,
            set = function(_, r, g, b, a)
              local c = db.border.color
              c.r, c.g, c.b, c.a = r, g, b, a
              ETBC.ApplyBus:Notify("auras")
            end,
            disabled = function() return not db.border.enabled end,
          },
          debuffTypeColors = {
            type = "toggle",
            name = "Debuff Type Colors",
            desc = "Color borders by debuff type (Magic/Curse/Disease/Poison).",
            order = 3,
            get = function() return db.border.debuffTypeColors end,
            set = function(_, v) db.border.debuffTypeColors = v and true or false; ETBC.ApplyBus:Notify("auras") end,
            disabled = function() return not db.border.enabled end,
          },
        },
      },

      buffs = {
        type = "group",
        name = "Buffs",
        order = 60,
        args = {
          enabled = {
            type = "toggle",
            name = "Show Buffs",
            order = 1,
            get = function() return db.buffs.enabled end,
            set = function(_, v) db.buffs.enabled = v and true or false; ETBC.ApplyBus:Notify("auras") end,
          },

          layout = {
            type = "group",
            name = "Layout",
            order = 10,
            inline = true,
            args = {
              iconSize = { type="range", name="Icon Size", order=1, min=16, max=64, step=1,
                get=function() return db.buffs.iconSize end,
                set=function(_, v) db.buffs.iconSize=v; ETBC.ApplyBus:Notify("auras") end,
                disabled=function() return not db.buffs.enabled end,
              },
              spacing = { type="range", name="Spacing", order=2, min=0, max=20, step=1,
                get=function() return db.buffs.spacing end,
                set=function(_, v) db.buffs.spacing=v; ETBC.ApplyBus:Notify("auras") end,
                disabled=function() return not db.buffs.enabled end,
              },
              perRow = { type="range", name="Icons Per Row", order=3, min=1, max=20, step=1,
                get=function() return db.buffs.perRow end,
                set=function(_, v) db.buffs.perRow=v; ETBC.ApplyBus:Notify("auras") end,
                disabled=function() return not db.buffs.enabled end,
              },
              growthX = { type="select", name="Horizontal Growth", order=4, values={ LEFT="Left", RIGHT="Right" },
                get=function() return db.buffs.growthX end,
                set=function(_, v) db.buffs.growthX=v; ETBC.ApplyBus:Notify("auras") end,
                disabled=function() return not db.buffs.enabled end,
              },
              growthY = { type="select", name="Vertical Growth", order=5, values={ DOWN="Down", UP="Up" },
                get=function() return db.buffs.growthY end,
                set=function(_, v) db.buffs.growthY=v; ETBC.ApplyBus:Notify("auras") end,
                disabled=function() return not db.buffs.enabled end,
              },
            },
          },

          anchor = {
            type = "group",
            name = "Anchor",
            order = 20,
            inline = true,
            args = {
              point = { type="select", name="Point", order=1, values=PointValues,
                get=function() return db.buffs.anchor.point end,
                set=function(_, v) db.buffs.anchor.point=v; ETBC.ApplyBus:Notify("auras") end,
                disabled=function() return not db.buffs.enabled end,
              },
              relPoint = { type="select", name="Relative Point", order=2, values=PointValues,
                get=function() return db.buffs.anchor.relPoint end,
                set=function(_, v) db.buffs.anchor.relPoint=v; ETBC.ApplyBus:Notify("auras") end,
                disabled=function() return not db.buffs.enabled end,
              },
              x = { type="range", name="X Offset", order=3, min=-800, max=800, step=1,
                get=function() return db.buffs.anchor.x end,
                set=function(_, v) db.buffs.anchor.x=v; ETBC.ApplyBus:Notify("auras") end,
                disabled=function() return not db.buffs.enabled end,
              },
              y = { type="range", name="Y Offset", order=4, min=-800, max=800, step=1,
                get=function() return db.buffs.anchor.y end,
                set=function(_, v) db.buffs.anchor.y=v; ETBC.ApplyBus:Notify("auras") end,
                disabled=function() return not db.buffs.enabled end,
              },
            },
          },
        },
      },

      debuffs = {
        type = "group",
        name = "Debuffs",
        order = 70,
        args = {
          enabled = {
            type = "toggle",
            name = "Show Debuffs",
            order = 1,
            get = function() return db.debuffs.enabled end,
            set = function(_, v) db.debuffs.enabled = v and true or false; ETBC.ApplyBus:Notify("auras") end,
          },

          layout = {
            type = "group",
            name = "Layout",
            order = 10,
            inline = true,
            args = {
              iconSize = { type="range", name="Icon Size", order=1, min=16, max=64, step=1,
                get=function() return db.debuffs.iconSize end,
                set=function(_, v) db.debuffs.iconSize=v; ETBC.ApplyBus:Notify("auras") end,
                disabled=function() return not db.debuffs.enabled end,
              },
              spacing = { type="range", name="Spacing", order=2, min=0, max=20, step=1,
                get=function() return db.debuffs.spacing end,
                set=function(_, v) db.debuffs.spacing=v; ETBC.ApplyBus:Notify("auras") end,
                disabled=function() return not db.debuffs.enabled end,
              },
              perRow = { type="range", name="Icons Per Row", order=3, min=1, max=20, step=1,
                get=function() return db.debuffs.perRow end,
                set=function(_, v) db.debuffs.perRow=v; ETBC.ApplyBus:Notify("auras") end,
                disabled=function() return not db.debuffs.enabled end,
              },
              growthX = { type="select", name="Horizontal Growth", order=4, values={ LEFT="Left", RIGHT="Right" },
                get=function() return db.debuffs.growthX end,
                set=function(_, v) db.debuffs.growthX=v; ETBC.ApplyBus:Notify("auras") end,
                disabled=function() return not db.debuffs.enabled end,
              },
              growthY = { type="select", name="Vertical Growth", order=5, values={ DOWN="Down", UP="Up" },
                get=function() return db.debuffs.growthY end,
                set=function(_, v) db.debuffs.growthY=v; ETBC.ApplyBus:Notify("auras") end,
                disabled=function() return not db.debuffs.enabled end,
              },
            },
          },

          anchor = {
            type = "group",
            name = "Anchor",
            order = 20,
            inline = true,
            args = {
              point = { type="select", name="Point", order=1, values=PointValues,
                get=function() return db.debuffs.anchor.point end,
                set=function(_, v) db.debuffs.anchor.point=v; ETBC.ApplyBus:Notify("auras") end,
                disabled=function() return not db.debuffs.enabled end,
              },
              relPoint = { type="select", name="Relative Point", order=2, values=PointValues,
                get=function() return db.debuffs.anchor.relPoint end,
                set=function(_, v) db.debuffs.anchor.relPoint=v; ETBC.ApplyBus:Notify("auras") end,
                disabled=function() return not db.debuffs.enabled end,
              },
              x = { type="range", name="X Offset", order=3, min=-800, max=800, step=1,
                get=function() return db.debuffs.anchor.x end,
                set=function(_, v) db.debuffs.anchor.x=v; ETBC.ApplyBus:Notify("auras") end,
                disabled=function() return not db.debuffs.enabled end,
              },
              y = { type="range", name="Y Offset", order=4, min=-800, max=800, step=1,
                get=function() return db.debuffs.anchor.y end,
                set=function(_, v) db.debuffs.anchor.y=v; ETBC.ApplyBus:Notify("auras") end,
                disabled=function() return not db.debuffs.enabled end,
              },
            },
          },
        },
      },
    }
  end,
})

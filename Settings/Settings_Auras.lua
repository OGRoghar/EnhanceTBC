-- Settings/Settings_Auras.lua
local _, ETBC = ...
local LSM = ETBC.LSM

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
    out = LSM:HashTable("font") or {}
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

local function EnsureDefaults()
  if not ETBC.db or not ETBC.db.profile then return end
  ETBC.db.profile.auras = ETBC.db.profile.auras or {}
  local db = ETBC.db.profile.auras
  db.buffs = db.buffs or {}
  db.debuffs = db.debuffs or {}
  db.border = db.border or {}
  db.durationText = db.durationText or {}
  db.countText = db.countText or {}
  if db.useDeltaAuraUpdates == nil then db.useDeltaAuraUpdates = true end
end

ETBC.SettingsRegistry:RegisterGroup("auras", {
  name = "Auras",
  order = 8,
  options = function()
    EnsureDefaults()
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
        desc = "Shows dummy aura icons for in-world layout testing (separate from the /etbc preview card).",
        order = 2,
        get = function() return db.preview end,
        set = function(_, v) db.preview = v and true or false; ETBC.ApplyBus:Notify("auras") end,
      },

      common = {
        type = "group",
        name = "Common",
        desc = "Shared aura behavior, tooltip handling, icon trimming, and update strategy.",
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
          trimIcons = {
            type = "toggle",
            name = "Trim Icon Texture",
            desc = "Crops icon edges for a cleaner square look.",
            order = 3,
            width = "full",
            get = function() return db.trimIcons end,
            set = function(_, v) db.trimIcons = v and true or false; ETBC.ApplyBus:Notify("auras") end,
          },
          useDeltaAuraUpdates = {
            type = "toggle",
            name = "Use Delta Aura Updates",
            desc = "Uses UNIT_AURA update payloads when available for lower update cost.",
            order = 4,
            width = "full",
            get = function() return db.useDeltaAuraUpdates end,
            set = function(_, v) db.useDeltaAuraUpdates = v and true or false; ETBC.ApplyBus:Notify("auras") end,
          },
        },
      },

      sorting = {
        type = "group",
        name = "Sorting",
        desc = "Sort order for shown aura icons when multiple auras are visible.",
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
        desc = "Cooldown spiral display options for aura icons.",
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

      text = {
        type = "group",
        name = "Text",
        desc = "Duration/count text toggles and font styling for aura icons.",
        order = 35,
        inline = true,
        args = {
          showDurationText = {
            type = "toggle",
            name = "Show Duration Text",
            order = 1,
            width = "full",
            get = function() return db.showDurationText end,
            set = function(_, v) db.showDurationText = v and true or false; ETBC.ApplyBus:Notify("auras") end,
          },
          durationFont = {
            type = "select",
            name = "Duration Font",
            order = 2,
            values = FontValues,
            get = function() return db.durationText.font end,
            set = function(_, v) db.durationText.font = v; ETBC.ApplyBus:Notify("auras") end,
            disabled = function() return not db.showDurationText end,
          },
          durationSize = {
            type = "range",
            name = "Duration Size",
            order = 3,
            min = 8, max = 24, step = 1,
            get = function() return db.durationText.size end,
            set = function(_, v) db.durationText.size = v; ETBC.ApplyBus:Notify("auras") end,
            disabled = function() return not db.showDurationText end,
          },
          durationOutline = {
            type = "select",
            name = "Duration Outline",
            order = 4,
            values = OutlineValues,
            get = function() return db.durationText.outline end,
            set = function(_, v) db.durationText.outline = v; ETBC.ApplyBus:Notify("auras") end,
            disabled = function() return not db.showDurationText end,
          },
          showCountText = {
            type = "toggle",
            name = "Show Count Text",
            order = 5,
            width = "full",
            get = function() return db.showCountText end,
            set = function(_, v) db.showCountText = v and true or false; ETBC.ApplyBus:Notify("auras") end,
          },
          countFont = {
            type = "select",
            name = "Count Font",
            order = 6,
            values = FontValues,
            get = function() return db.countText.font end,
            set = function(_, v) db.countText.font = v; ETBC.ApplyBus:Notify("auras") end,
            disabled = function() return not db.showCountText end,
          },
          countSize = {
            type = "range",
            name = "Count Size",
            order = 7,
            min = 8, max = 24, step = 1,
            get = function() return db.countText.size end,
            set = function(_, v) db.countText.size = v; ETBC.ApplyBus:Notify("auras") end,
            disabled = function() return not db.showCountText end,
          },
          countOutline = {
            type = "select",
            name = "Count Outline",
            order = 8,
            values = OutlineValues,
            get = function() return db.countText.outline end,
            set = function(_, v) db.countText.outline = v; ETBC.ApplyBus:Notify("auras") end,
            disabled = function() return not db.showCountText end,
          },
        },
      },

      borders = {
        type = "group",
        name = "Borders",
        desc = "Aura icon border styling, including optional debuff-type coloring.",
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
        desc = "Enable and configure the buff icon set layout and anchor.",
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
            desc = "Buff icon size, spacing, row count, and growth directions.",
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
            desc = "Buff anchor point and offset relative to the tracked frame.",
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
        desc = "Enable and configure the debuff icon set layout and anchor.",
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
            desc = "Debuff icon size, spacing, row count, and growth directions.",
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
            desc = "Debuff anchor point and offset relative to the tracked frame.",
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

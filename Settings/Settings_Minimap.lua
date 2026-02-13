-- Settings/Settings_Minimap.lua
local ADDON_NAME, ETBC = ...

local function EnsureDB()
  if not ETBC.db or not ETBC.db.profile then return nil end
  ETBC.db.profile.minimap = ETBC.db.profile.minimap or {}
  local db = ETBC.db.profile.minimap

  if db.enabled == nil then db.enabled = true end
  if db.shape == nil then db.shape = "CIRCLE" end
  if db.squareSize == nil then db.squareSize = 140 end
  if db.mapScale == nil then db.mapScale = 1.0 end
  if db.hideDayNight == nil then db.hideDayNight = true end

  db.border = db.border or {}
  if db.border.enabled == nil then db.border.enabled = true end
  if db.border.size == nil then db.border.size = 2 end
  if db.border.alpha == nil then db.border.alpha = 0.90 end
  if db.border.r == nil then db.border.r = 0.15 end
  if db.border.g == nil then db.border.g = 0.15 end
  if db.border.b == nil then db.border.b = 0.15 end

  db.background = db.background or {}
  if db.background.enabled == nil then db.background.enabled = false end
  if db.background.alpha == nil then db.background.alpha = 0.0 end
  if db.background.r == nil then db.background.r = 0 end
  if db.background.g == nil then db.background.g = 0 end
  if db.background.b == nil then db.background.b = 0 end

  db.collector = db.collector or {}
  local c = db.collector
  if c.enabled == nil then c.enabled = true end
  if c.flyoutMode == nil then c.flyoutMode = "CLICK" end
  if c.startOpen == nil then c.startOpen = false end
  if c.locked == nil then c.locked = true end

  if c.iconSize == nil then c.iconSize = 28 end
  if c.columns == nil then c.columns = 6 end
  if c.spacing == nil then c.spacing = 4 end
  if c.padding == nil then c.padding = 6 end
  if c.scale == nil then c.scale = 1.0 end
  if c.bgAlpha == nil then c.bgAlpha = 0.35 end
  if c.borderAlpha == nil then c.borderAlpha = 0.85 end

  if c.includeLibDBIcon == nil then c.includeLibDBIcon = true end
  if c.includeExtra == nil then c.includeExtra = "" end
  if c.exclude == nil then c.exclude = "" end

  c.pos = c.pos or {}
  if c.pos.point == nil then c.pos.point = "TOPRIGHT" end
  if c.pos.relPoint == nil then c.pos.relPoint = "TOPLEFT" end
  if c.pos.x == nil then c.pos.x = 8 end
  if c.pos.y == nil then c.pos.y = 0 end

  c.toggle = c.toggle or {}
  if c.toggle.point == nil then c.toggle.point = "TOPRIGHT" end
  if c.toggle.relPoint == nil then c.toggle.relPoint = "BOTTOMRIGHT" end
  if c.toggle.x == nil then c.toggle.x = 2 end
  if c.toggle.y == nil then c.toggle.y = -2 end

  return db
end

local function Notify()
  if ETBC.ApplyBus and ETBC.ApplyBus.Notify then
    ETBC.ApplyBus:Notify("minimap")
  end
end

ETBC.SettingsRegistry:RegisterGroup("minimap", {
  name = "Minimap",
  order = 9,
  options = function()
    local db = EnsureDB()
    if not db then
      return {
        type = "group",
        name = "Minimap",
        args = {
          msg = { type="description", name="Minimap settings unavailable (DB not ready).", order=1 },
        },
      }
    end

    local c = db.collector

    return {
      type = "group",
      name = "Minimap",
      args = {
        enabled = {
          type = "toggle",
          name = "Enable Minimap Module",
          order = 1,
          width = "full",
          get = function() return db.enabled and true or false end,
          set = function(_, v) db.enabled = v and true or false; Notify() end,
        },

        mapScale = {
          type = "range",
          name = "Minimap Scale",
          desc = "Scales the minimap itself (not the flyout).",
          order = 2,
          min = 0.70, max = 1.50, step = 0.05,
          disabled = function() return not db.enabled end,
          get = function() return db.mapScale end,
          set = function(_, v) db.mapScale = v; Notify() end,
        },

        shapeHeader = { type="header", name="Shape", order=9 },

        shape = {
          type = "select",
          name = "Minimap Shape",
          order = 10,
          values = { CIRCLE="Circle (Default)", SQUARE="Square" },
          disabled = function() return not db.enabled end,
          get = function() return db.shape end,
          set = function(_, v) db.shape = v; Notify() end,
        },

        squareSize = {
          type = "range",
          name = "Square Size",
          order = 11,
          min = 110, max = 220, step = 1,
          disabled = function() return not (db.enabled and db.shape == "SQUARE") end,
          get = function() return db.squareSize end,
          set = function(_, v) db.squareSize = v; Notify() end,
        },

        hideDayNight = {
          type = "toggle",
          name = "Hide day/night indicator",
          order = 12,
          width = "full",
          disabled = function() return not db.enabled end,
          get = function() return db.hideDayNight and true or false end,
          set = function(_, v) db.hideDayNight = v and true or false; Notify() end,
        },

        styleHeader = { type="header", name="Style", order=19 },

        border = {
          type = "group",
          name = "Border",
          order = 20,
          inline = true,
          args = {
            enabled = {
              type="toggle", name="Enable Border", order=1,
              disabled=function() return not db.enabled end,
              get=function() return db.border.enabled end,
              set=function(_, v) db.border.enabled = v and true or false; Notify() end,
            },
            size = {
              type="range", name="Border Size", order=2, min=1, max=8, step=1,
              disabled=function() return not (db.enabled and db.border.enabled) end,
              get=function() return db.border.size end,
              set=function(_, v) db.border.size = v; Notify() end,
            },
            alpha = {
              type="range", name="Border Alpha", order=3, min=0, max=1, step=0.05,
              disabled=function() return not (db.enabled and db.border.enabled) end,
              get=function() return db.border.alpha end,
              set=function(_, v) db.border.alpha = v; Notify() end,
            },
          },
        },

        background = {
          type="group",
          name="Background",
          order=21,
          inline=true,
          args = {
            enabled = {
              type="toggle", name="Enable Background", order=1,
              disabled=function() return not db.enabled end,
              get=function() return db.background.enabled end,
              set=function(_, v) db.background.enabled = v and true or false; Notify() end,
            },
            alpha = {
              type="range", name="Background Alpha", order=2, min=0, max=1, step=0.05,
              disabled=function() return not (db.enabled and db.background.enabled) end,
              get=function() return db.background.alpha end,
              set=function(_, v) db.background.alpha = v; Notify() end,
            },
          },
        },

        collectorHeader = { type="header", name="Addon Button Flyout", order=39 },

        collectorEnabled = {
          type="toggle",
          name="Enable addon button flyout",
          order=40,
          width="full",
          disabled=function() return not db.enabled end,
          get=function() return c.enabled and true or false end,
          set=function(_, v) c.enabled = v and true or false; Notify() end,
        },

        flyoutMode = {
          type="select",
          name="Flyout behavior",
          order=41,
          values = { CLICK="Toggle on click", HOVER="Show on hover", ALWAYS="Always open" },
          disabled=function() return not (db.enabled and c.enabled) end,
          get=function() return c.flyoutMode end,
          set=function(_, v) c.flyoutMode = v; Notify() end,
        },

        startOpen = {
          type="toggle",
          name="Start open (login)",
          order=42,
          width="full",
          disabled=function() return not (db.enabled and c.enabled) end,
          get=function() return c.startOpen and true or false end,
          set=function(_, v) c.startOpen = v and true or false; Notify() end,
        },

        locked = {
          type="toggle",
          name="Lock flyout box",
          order=43,
          width="full",
          disabled=function() return not (db.enabled and c.enabled) end,
          get=function() return c.locked and true or false end,
          set=function(_, v) c.locked = v and true or false; Notify() end,
        },

        layout = {
          type="group",
          name="Box Layout",
          order=50,
          inline=true,
          args = {
            iconSize = {
              type="range", name="Icon Size", order=1, min=16, max=42, step=1,
              disabled=function() return not (db.enabled and c.enabled) end,
              get=function() return c.iconSize end,
              set=function(_, v) c.iconSize = v; Notify() end,
            },
            columns = {
              type="range", name="Max Columns", order=2, min=1, max=12, step=1,
              disabled=function() return not (db.enabled and c.enabled) end,
              get=function() return c.columns end,
              set=function(_, v) c.columns = v; Notify() end,
            },
            spacing = {
              type="range", name="Spacing", order=3, min=0, max=14, step=1,
              disabled=function() return not (db.enabled and c.enabled) end,
              get=function() return c.spacing end,
              set=function(_, v) c.spacing = v; Notify() end,
            },
            padding = {
              type="range", name="Padding", order=4, min=0, max=16, step=1,
              disabled=function() return not (db.enabled and c.enabled) end,
              get=function() return c.padding end,
              set=function(_, v) c.padding = v; Notify() end,
            },
            scale = {
              type="range", name="Flyout Box Scale", order=5, min=0.7, max=1.5, step=0.05,
              disabled=function() return not (db.enabled and c.enabled) end,
              get=function() return c.scale end,
              set=function(_, v) c.scale = v; Notify() end,
            },
          },
        },

        style2 = {
          type="group",
          name="Box Style",
          order=51,
          inline=true,
          args = {
            bgAlpha = {
              type="range", name="Background Alpha", order=1, min=0, max=1, step=0.05,
              disabled=function() return not (db.enabled and c.enabled) end,
              get=function() return c.bgAlpha end,
              set=function(_, v) c.bgAlpha = v; Notify() end,
            },
            borderAlpha = {
              type="range", name="Border Alpha", order=2, min=0, max=1, step=0.05,
              disabled=function() return not (db.enabled and c.enabled) end,
              get=function() return c.borderAlpha end,
              set=function(_, v) c.borderAlpha = v; Notify() end,
            },
          },
        },

        filters = {
          type="group",
          name="Filters",
          order=52,
          inline=true,
          args = {
            includeLibDBIcon = {
              type="toggle",
              name="Collect LibDBIcon buttons (recommended)",
              order=1, width="full",
              disabled=function() return not (db.enabled and c.enabled) end,
              get=function() return c.includeLibDBIcon and true or false end,
              set=function(_, v) c.includeLibDBIcon = v and true or false; Notify() end,
            },
            includeExtra = {
              type="input",
              name="Also include these frame names",
              desc="Comma-separated exact frame names for non-LDB addon buttons.",
              order=2, width="full",
              disabled=function() return not (db.enabled and c.enabled) end,
              get=function() return tostring(c.includeExtra or "") end,
              set=function(_, v) c.includeExtra = tostring(v or ""); Notify() end,
            },
            exclude = {
              type="input",
              name="Exclude these frame names",
              desc="Comma-separated exact frame names.",
              order=3, width="full",
              disabled=function() return not (db.enabled and c.enabled) end,
              get=function() return tostring(c.exclude or "") end,
              set=function(_, v) c.exclude = tostring(v or ""); Notify() end,
            },
          },
        },
      },
    }
  end,
})

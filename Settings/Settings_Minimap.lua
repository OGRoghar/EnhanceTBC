-- Settings/Settings_Minimap.lua
local ADDON_NAME, ETBC = ...

local function EnsureDB()
  if not ETBC.db or not ETBC.db.profile then return nil end
  ETBC.db.profile.minimap = ETBC.db.profile.minimap or {}
  local db = ETBC.db.profile.minimap

  if db.enabled == nil then db.enabled = true end

  if db.shape == nil then db.shape = "CIRCLE" end -- CIRCLE / SQUARE
  if db.mapScale == nil then db.mapScale = 1.0 end
  if db.squareSize == nil then db.squareSize = 140 end

  db.border = db.border or {}
  if db.border.enabled == nil then db.border.enabled = true end
  if db.border.size == nil then db.border.size = 2 end
  if db.border.alpha == nil then db.border.alpha = 0.90 end
  if db.border.r == nil then db.border.r = 0.18 end
  if db.border.g == nil then db.border.g = 0.20 end
  if db.border.b == nil then db.border.b = 0.18 end

  db.zoneText = db.zoneText or {}
  if db.zoneText.enabled == nil then db.zoneText.enabled = true end
  if db.zoneText.point == nil then db.zoneText.point = "TOP" end
  if db.zoneText.x == nil then db.zoneText.x = 0 end
  if db.zoneText.y == nil then db.zoneText.y = -2 end
  if db.zoneText.fontSize == nil then db.zoneText.fontSize = 12 end
  if db.zoneText.alpha == nil then db.zoneText.alpha = 1.0 end

  db.clock = db.clock or {}
  if db.clock.enabled == nil then db.clock.enabled = true end
  if db.clock.point == nil then db.clock.point = "BOTTOM" end
  if db.clock.x == nil then db.clock.x = 0 end
  if db.clock.y == nil then db.clock.y = -2 end -- moved DOWN
  if db.clock.fontSize == nil then db.clock.fontSize = 12 end
  if db.clock.alpha == nil then db.clock.alpha = 1.0 end

  db.blizzButtons = db.blizzButtons or {}
  if db.blizzButtons.enabled == nil then db.blizzButtons.enabled = true end
  if db.blizzButtons.size == nil then db.blizzButtons.size = 32 end

  db.blizzButtons.zoom = db.blizzButtons.zoom or {}
  if db.blizzButtons.zoom.point == nil then db.blizzButtons.zoom.point = "LEFT" end
  if db.blizzButtons.zoom.relPoint == nil then db.blizzButtons.zoom.relPoint = "LEFT" end
  if db.blizzButtons.zoom.x == nil then db.blizzButtons.zoom.x = -10 end
  if db.blizzButtons.zoom.y == nil then db.blizzButtons.zoom.y = 0 end

  db.blizzButtons.tracking = db.blizzButtons.tracking or {}
  if db.blizzButtons.tracking.point == nil then db.blizzButtons.tracking.point = "TOPRIGHT" end
  if db.blizzButtons.tracking.relPoint == nil then db.blizzButtons.tracking.relPoint = "TOPRIGHT" end
  if db.blizzButtons.tracking.x == nil then db.blizzButtons.tracking.x = 6 end
  if db.blizzButtons.tracking.y == nil then db.blizzButtons.tracking.y = -2 end

  db.blizzButtons.mail = db.blizzButtons.mail or {}
  if db.blizzButtons.mail.point == nil then db.blizzButtons.mail.point = "TOP" end
  if db.blizzButtons.mail.relPoint == nil then db.blizzButtons.mail.relPoint = "TOP" end
  if db.blizzButtons.mail.x == nil then db.blizzButtons.mail.x = 0 end
  if db.blizzButtons.mail.y == nil then db.blizzButtons.mail.y = 6 end

  db.blizzButtons.lfg = db.blizzButtons.lfg or {}
  if db.blizzButtons.lfg.point == nil then db.blizzButtons.lfg.point = "BOTTOMLEFT" end
  if db.blizzButtons.lfg.relPoint == nil then db.blizzButtons.lfg.relPoint = "BOTTOMLEFT" end
  if db.blizzButtons.lfg.x == nil then db.blizzButtons.lfg.x = -2 end
  if db.blizzButtons.lfg.y == nil then db.blizzButtons.lfg.y = -2 end

  db.flyout = db.flyout or {}
  if db.flyout.enabled == nil then db.flyout.enabled = true end
  if db.flyout.locked == nil then db.flyout.locked = true end
  if db.flyout.startOpen == nil then db.flyout.startOpen = false end

  if db.flyout.iconSize == nil then db.flyout.iconSize = 28 end
  if db.flyout.columns == nil then db.flyout.columns = 6 end
  if db.flyout.spacing == nil then db.flyout.spacing = 4 end
  if db.flyout.padding == nil then db.flyout.padding = 6 end
  if db.flyout.scale == nil then db.flyout.scale = 1.0 end
  if db.flyout.bgAlpha == nil then db.flyout.bgAlpha = 0.70 end
  if db.flyout.borderAlpha == nil then db.flyout.borderAlpha = 0.90 end

  if db.flyout.includeExtra == nil then db.flyout.includeExtra = "" end
  if db.flyout.exclude == nil then db.flyout.exclude = "" end

  db.flyout.pos = db.flyout.pos or {}
  if db.flyout.pos.point == nil then db.flyout.pos.point = "TOPRIGHT" end
  if db.flyout.pos.relPoint == nil then db.flyout.pos.relPoint = "BOTTOMRIGHT" end
  if db.flyout.pos.x == nil then db.flyout.pos.x = 0 end
  if db.flyout.pos.y == nil then db.flyout.pos.y = -8 end

  db.flyout.toggle = db.flyout.toggle or {}
  if db.flyout.toggle.point == nil then db.flyout.toggle.point = "BOTTOM" end
  if db.flyout.toggle.relPoint == nil then db.flyout.toggle.relPoint = "BOTTOM" end
  if db.flyout.toggle.x == nil then db.flyout.toggle.x = 0 end
  if db.flyout.toggle.y == nil then db.flyout.toggle.y = -14 end

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
      return { type="group", name="Minimap", args={ msg={ type="description", name="DB not ready.", order=1 } } }
    end

    return {
      enabled = {
        type="toggle", name="Enable Minimap Module", order=1, width="full",
        get=function() return db.enabled and true or false end,
        set=function(_, v) db.enabled = v and true or false; Notify() end,
      },
      mapScale = {
        type="range", name="Minimap Scale", order=2, min=0.70, max=1.50, step=0.05,
        disabled=function() return not db.enabled end,
        get=function() return db.mapScale end,
        set=function(_, v) db.mapScale=v; Notify() end,
      },
      shapeHeader = { type="header", name="Shape", order=9 },
      shape = {
        type="select", name="Minimap Shape", order=10,
        values={ CIRCLE="Circle (Default)", SQUARE="Square" },
        disabled=function() return not db.enabled end,
        get=function() return db.shape end,
        set=function(_, v) db.shape=v; Notify() end,
      },
      squareSize = {
        type="range", name="Square Size", order=11, min=110, max=220, step=1,
        disabled=function() return not (db.enabled and db.shape=="SQUARE") end,
        get=function() return db.squareSize end,
        set=function(_, v) db.squareSize=v; Notify() end,
      },

      borderHeader = { type="header", name="Border", order=19 },
      borderEnabled = {
        type="toggle", name="Enable Border", order=20, width="full",
        disabled=function() return not db.enabled end,
        get=function() return db.border.enabled and true or false end,
        set=function(_, v) db.border.enabled=v and true or false; Notify() end,
      },
      borderSize = {
        type="range", name="Border Size", order=21, min=1, max=8, step=1,
        disabled=function() return not (db.enabled and db.border.enabled) end,
        get=function() return db.border.size end,
        set=function(_, v) db.border.size=v; Notify() end,
      },
      borderAlpha = {
        type="range", name="Border Alpha", order=22, min=0, max=1, step=0.05,
        disabled=function() return not (db.enabled and db.border.enabled) end,
        get=function() return db.border.alpha end,
        set=function(_, v) db.border.alpha=v; Notify() end,
      },

      zoneHeader = { type="header", name="Zone Text", order=29 },
      zoneEnabled = {
        type="toggle", name="Show zone name", order=30, width="full",
        disabled=function() return not db.enabled end,
        get=function() return db.zoneText.enabled and true or false end,
        set=function(_, v) db.zoneText.enabled=v and true or false; Notify() end,
      },
      zoneFont = {
        type="range", name="Zone font size", order=31, min=8, max=20, step=1,
        disabled=function() return not (db.enabled and db.zoneText.enabled) end,
        get=function() return db.zoneText.fontSize end,
        set=function(_, v) db.zoneText.fontSize=v; Notify() end,
      },

      clockHeader = { type="header", name="Clock", order=39 },
      clockEnabled = {
        type="toggle", name="Show clock (bottom center)", order=40, width="full",
        disabled=function() return not db.enabled end,
        get=function() return db.clock.enabled and true or false end,
        set=function(_, v) db.clock.enabled=v and true or false; Notify() end,
      },
      clockFont = {
        type="range", name="Clock font size", order=41, min=8, max=20, step=1,
        disabled=function() return not (db.enabled and db.clock.enabled) end,
        get=function() return db.clock.fontSize end,
        set=function(_, v) db.clock.fontSize=v; Notify() end,
      },

      blizzHeader = { type="header", name="Blizzard Buttons (Do NOT scale)", order=49 },
      blizzEnabled = {
        type="toggle", name="Re-anchor Blizzard minimap buttons", order=50, width="full",
        disabled=function() return not db.enabled end,
        get=function() return db.blizzButtons.enabled and true or false end,
        set=function(_, v) db.blizzButtons.enabled=v and true or false; Notify() end,
      },
      blizzSize = {
        type="range", name="Blizzard button size", order=51, min=20, max=42, step=1,
        disabled=function() return not (db.enabled and db.blizzButtons.enabled) end,
        get=function() return db.blizzButtons.size end,
        set=function(_, v) db.blizzButtons.size=v; Notify() end,
      },

      flyoutHeader = { type="header", name="Addon Button Flyout", order=59 },
      flyoutEnabled = {
        type="toggle", name="Enable addon icon flyout", order=60, width="full",
        disabled=function() return not db.enabled end,
        get=function() return db.flyout.enabled and true or false end,
        set=function(_, v) db.flyout.enabled=v and true or false; Notify() end,
      },
      flyoutLocked = {
        type="toggle", name="Lock flyout position", order=61, width="full",
        disabled=function() return not (db.enabled and db.flyout.enabled) end,
        get=function() return db.flyout.locked and true or false end,
        set=function(_, v) db.flyout.locked=v and true or false; Notify() end,
      },
      flyoutStartOpen = {
        type="toggle", name="Start open (login)", order=62, width="full",
        disabled=function() return not (db.enabled and db.flyout.enabled) end,
        get=function() return db.flyout.startOpen and true or false end,
        set=function(_, v) db.flyout.startOpen=v and true or false; Notify() end,
      },

      flyoutLayout = {
        type="group", name="Flyout Layout", order=70, inline=true,
        args = {
          iconSize = {
            type="range", name="Icon size", order=1, min=16, max=44, step=1,
            disabled=function() return not (db.enabled and db.flyout.enabled) end,
            get=function() return db.flyout.iconSize end,
            set=function(_, v) db.flyout.iconSize=v; Notify() end,
          },
          columns = {
            type="range", name="Max columns", order=2, min=1, max=12, step=1,
            disabled=function() return not (db.enabled and db.flyout.enabled) end,
            get=function() return db.flyout.columns end,
            set=function(_, v) db.flyout.columns=v; Notify() end,
          },
          spacing = {
            type="range", name="Spacing", order=3, min=0, max=14, step=1,
            disabled=function() return not (db.enabled and db.flyout.enabled) end,
            get=function() return db.flyout.spacing end,
            set=function(_, v) db.flyout.spacing=v; Notify() end,
          },
          padding = {
            type="range", name="Padding", order=4, min=0, max=20, step=1,
            disabled=function() return not (db.enabled and db.flyout.enabled) end,
            get=function() return db.flyout.padding end,
            set=function(_, v) db.flyout.padding=v; Notify() end,
          },
          scale = {
            type="range", name="Flyout scale", order=5, min=0.7, max=1.5, step=0.05,
            disabled=function() return not (db.enabled and db.flyout.enabled) end,
            get=function() return db.flyout.scale end,
            set=function(_, v) db.flyout.scale=v; Notify() end,
          },
          bgAlpha = {
            type="range", name="Background alpha", order=6, min=0, max=1, step=0.05,
            disabled=function() return not (db.enabled and db.flyout.enabled) end,
            get=function() return db.flyout.bgAlpha end,
            set=function(_, v) db.flyout.bgAlpha=v; Notify() end,
          },
          borderAlpha = {
            type="range", name="Border alpha", order=7, min=0, max=1, step=0.05,
            disabled=function() return not (db.enabled and db.flyout.enabled) end,
            get=function() return db.flyout.borderAlpha end,
            set=function(_, v) db.flyout.borderAlpha=v; Notify() end,
          },
        },
      },

      flyoutFilters = {
        type="group", name="Flyout Filters", order=71, inline=true,
        args = {
          includeExtra = {
            type="input", name="Also include these frame names", order=1, width="full",
            disabled=function() return not (db.enabled and db.flyout.enabled) end,
            get=function() return tostring(db.flyout.includeExtra or "") end,
            set=function(_, v) db.flyout.includeExtra=tostring(v or ""); Notify() end,
          },
          exclude = {
            type="input", name="Exclude these frame names", order=2, width="full",
            disabled=function() return not (db.enabled and db.flyout.enabled) end,
            get=function() return tostring(db.flyout.exclude or "") end,
            set=function(_, v) db.flyout.exclude=tostring(v or ""); Notify() end,
          },
        },
      },

      toolsHeader = { type="header", name="Tools", order=90 },
      resetFlyoutPos = {
        type="execute", name="Reset flyout position", order=91,
        disabled=function() return not (db.enabled and db.flyout.enabled) end,
        func=function()
          db.flyout.pos.point, db.flyout.pos.relPoint, db.flyout.pos.x, db.flyout.pos.y = "TOPRIGHT", "BOTTOMRIGHT", 0, -8
          db.flyout.toggle.point, db.flyout.toggle.relPoint, db.flyout.toggle.x, db.flyout.toggle.y = "BOTTOM", "BOTTOM", 0, -14
          Notify()
        end,
      },
    }
  end,
})

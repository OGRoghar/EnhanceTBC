-- Settings/Settings_Minimap.lua
local ADDON_NAME, ETBC = ...

local function EnsureDB()
  if not ETBC.db or not ETBC.db.profile then return nil end
  ETBC.db.profile.minimap = ETBC.db.profile.minimap or {}
  local db = ETBC.db.profile.minimap

  if db.enabled == nil then db.enabled = true end

  -- Shape
  if db.shape == nil then db.shape = "CIRCLE" end -- CIRCLE / SQUARE
  if db.squareSize == nil then db.squareSize = 140 end

  -- Scale (applies to the MINIMAP itself, not the flyout box)
  if db.mapScale == nil then db.mapScale = 1.0 end

  -- Collector (addon buttons only)
  db.collector = db.collector or {}
  local c = db.collector
  if c.enabled == nil then c.enabled = true end

  -- Flyout behavior
  if c.flyoutMode == nil then c.flyoutMode = "CLICK" end -- CLICK / HOVER / ALWAYS
  if c.startOpen == nil then c.startOpen = false end

  -- Lock flyout position
  if c.locked == nil then c.locked = true end

  -- Box layout
  if c.iconSize == nil then c.iconSize = 28 end
  if c.columns == nil then c.columns = 6 end
  if c.spacing == nil then c.spacing = 4 end
  if c.padding == nil then c.padding = 6 end
  if c.scale == nil then c.scale = 1.0 end
  if c.bgAlpha == nil then c.bgAlpha = 0.70 end
  if c.borderAlpha == nil then c.borderAlpha = 0.90 end

  -- Safety: only addon buttons
  if c.includeLibDBIcon == nil then c.includeLibDBIcon = true end

  -- Extra include / exclude lists
  if c.includeExtra == nil then c.includeExtra = "" end     -- comma-separated frame names
  if c.exclude == nil then c.exclude = "" end               -- comma-separated frame names

  -- Position of the box (relative to minimap)
  c.pos = c.pos or {}
  local p = c.pos
  if p.point == nil then p.point = "TOPRIGHT" end
  if p.relPoint == nil then p.relPoint = "TOPLEFT" end
  if p.x == nil then p.x = 8 end
  if p.y == nil then p.y = 0 end

  -- Flyout toggle button position
  c.toggle = c.toggle or {}
  local t = c.toggle
  if t.point == nil then t.point = "TOPRIGHT" end
  if t.relPoint == nil then t.relPoint = "BOTTOMRIGHT" end
  if t.x == nil then t.x = 2 end
  if t.y == nil then t.y = -2 end

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
        enabled = { type="description", name="Minimap settings unavailable (DB not ready).", order=1 },
      }
    end

    local c = db.collector

    return {
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
        desc = "Scales the minimap itself (not the flyout box).",
        order = 2,
        min = 0.70, max = 1.50, step = 0.05,
        disabled = function() return not db.enabled end,
        get = function() return db.mapScale end,
        set = function(_, v) db.mapScale = v; Notify() end,
      },

      shapeHeader = { type = "header", name = "Shape", order = 9 },

      shape = {
        type = "select",
        name = "Minimap Shape",
        order = 10,
        values = { CIRCLE = "Circle (Default)", SQUARE = "Square" },
        disabled = function() return not db.enabled end,
        get = function() return db.shape end,
        set = function(_, v) db.shape = v; Notify() end,
      },

      squareSize = {
        type = "range",
        name = "Square Size",
        desc = "Only used when shape is Square. Adjusts the minimap frame size so it fits cleanly.",
        order = 11,
        min = 110, max = 200, step = 1,
        disabled = function() return not (db.enabled and db.shape == "SQUARE") end,
        get = function() return db.squareSize end,
        set = function(_, v) db.squareSize = v; Notify() end,
      },

      collectorHeader = { type = "header", name = "Addon Button Flyout", order = 19 },

      collectorEnabled = {
        type = "toggle",
        name = "Enable addon button flyout",
        desc = "Collects addon minimap buttons (LibDBIcon + your optional includes) into a box.",
        order = 20,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return c.enabled and true or false end,
        set = function(_, v) c.enabled = v and true or false; Notify() end,
      },

      flyoutMode = {
        type = "select",
        name = "Flyout behavior",
        order = 21,
        values = { CLICK = "Toggle on click", HOVER = "Show on hover", ALWAYS = "Always open" },
        disabled = function() return not (db.enabled and c.enabled) end,
        get = function() return c.flyoutMode end,
        set = function(_, v) c.flyoutMode = v; Notify() end,
      },

      startOpen = {
        type = "toggle",
        name = "Start open (login)",
        order = 22,
        width = "full",
        disabled = function() return not (db.enabled and c.enabled) end,
        get = function() return c.startOpen and true or false end,
        set = function(_, v) c.startOpen = v and true or false; Notify() end,
      },

      locked = {
        type = "toggle",
        name = "Lock flyout box",
        desc = "Prevents dragging/repositioning the flyout box.",
        order = 23,
        width = "full",
        disabled = function() return not (db.enabled and c.enabled) end,
        get = function() return c.locked and true or false end,
        set = function(_, v) c.locked = v and true or false; Notify() end,
      },

      layout = {
        type = "group",
        name = "Box Layout",
        order = 30,
        inline = true,
        args = {
          iconSize = {
            type="range", name="Icon Size", order=1, min=16, max=42, step=1,
            disabled=function() return not (db.enabled and c.enabled) end,
            get=function() return c.iconSize end,
            set=function(_, v) c.iconSize=v; Notify() end,
          },
          columns = {
            type="range", name="Max Columns", order=2, min=1, max=12, step=1,
            desc="The flyout dynamically shrinks to use fewer columns if there are fewer buttons.",
            disabled=function() return not (db.enabled and c.enabled) end,
            get=function() return c.columns end,
            set=function(_, v) c.columns=v; Notify() end,
          },
          spacing = {
            type="range", name="Spacing", order=3, min=0, max=14, step=1,
            disabled=function() return not (db.enabled and c.enabled) end,
            get=function() return c.spacing end,
            set=function(_, v) c.spacing=v; Notify() end,
          },
          padding = {
            type="range", name="Padding", order=4, min=0, max=16, step=1,
            disabled=function() return not (db.enabled and c.enabled) end,
            get=function() return c.padding end,
            set=function(_, v) c.padding=v; Notify() end,
          },
          scale = {
            type="range", name="Flyout Box Scale", order=5, min=0.7, max=1.5, step=0.05,
            disabled=function() return not (db.enabled and c.enabled) end,
            get=function() return c.scale end,
            set=function(_, v) c.scale=v; Notify() end,
          },
        },
      },

      style = {
        type = "group",
        name = "Box Style",
        order = 31,
        inline = true,
        args = {
          bgAlpha = {
            type="range", name="Background Alpha", order=1, min=0, max=1, step=0.05,
            disabled=function() return not (db.enabled and c.enabled) end,
            get=function() return c.bgAlpha end,
            set=function(_, v) c.bgAlpha=v; Notify() end,
          },
          borderAlpha = {
            type="range", name="Border Alpha", order=2, min=0, max=1, step=0.05,
            disabled=function() return not (db.enabled and c.enabled) end,
            get=function() return c.borderAlpha end,
            set=function(_, v) c.borderAlpha=v; Notify() end,
          },
        },
      },

      filters = {
        type = "group",
        name = "Filters (Safety)",
        order = 32,
        inline = true,
        args = {
          includeLibDBIcon = {
            type="toggle",
            name="Collect LibDBIcon buttons (recommended)",
            desc="Most addon minimap icons are LibDBIcon10_*.",
            order=1, width="full",
            disabled=function() return not (db.enabled and c.enabled) end,
            get=function() return c.includeLibDBIcon and true or false end,
            set=function(_, v) c.includeLibDBIcon = v and true or false; Notify() end,
          },
          includeExtra = {
            type="input",
            name="Also include these frame names",
            desc="Comma-separated exact frame names for non-LDB addon buttons.\nExample: MinimapButtonButton, SomeAddonMinimapButton",
            order=2, width="full",
            disabled=function() return not (db.enabled and c.enabled) end,
            get=function() return tostring(c.includeExtra or "") end,
            set=function(_, v) c.includeExtra = tostring(v or ""); Notify() end,
          },
          exclude = {
            type="input",
            name="Exclude these frame names",
            desc="Comma-separated exact frame names.\nUse this if an addon icon should NOT be collected.",
            order=3, width="full",
            disabled=function() return not (db.enabled and c.enabled) end,
            get=function() return tostring(c.exclude or "") end,
            set=function(_, v) c.exclude = tostring(v or ""); Notify() end,
          },
        },
      },

      toolsHeader = { type="header", name="Tools", order=90 },

      resetFlyoutPos = {
        type="execute", name="Reset flyout positions", order=91,
        disabled=function() return not (db.enabled and c.enabled) end,
        func=function()
          c.pos.point, c.pos.relPoint, c.pos.x, c.pos.y = "TOPRIGHT", "TOPLEFT", 8, 0
          c.toggle.point, c.toggle.relPoint, c.toggle.x, c.toggle.y = "TOPRIGHT", "BOTTOMRIGHT", 2, -2
          Notify()
        end,
      },
    }
  end,
})

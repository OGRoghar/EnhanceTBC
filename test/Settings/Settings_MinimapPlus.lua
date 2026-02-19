-- Settings/Settings_MinimapPlus.lua
-- EnhanceTBC - MinimapPlus options

local _, ETBC = ...

local function EnsureDefaults()
  if not ETBC.db or not ETBC.db.profile then return end
  ETBC.db.profile.minimapPlus = ETBC.db.profile.minimapPlus or {}
  local db = ETBC.db.profile.minimapPlus

  if db.enabled == nil then db.enabled = true end

  if db.minimap_icons == nil and db.minimapIcons ~= nil then db.minimap_icons = db.minimapIcons end
  if db.minimapIcons == nil and db.minimap_icons ~= nil then db.minimapIcons = db.minimap_icons end
  if db.minimap_icons == nil then db.minimap_icons = true end
  if db.minimapIcons == nil then db.minimapIcons = db.minimap_icons end

  if db.minimap_performance == nil and db.minimapPerformance ~= nil then
    db.minimap_performance = db.minimapPerformance
  end
  if db.minimapPerformance == nil and db.minimap_performance ~= nil then
    db.minimapPerformance = db.minimap_performance
  end
  if db.minimap_performance == nil then db.minimap_performance = false end
  if db.minimapPerformance == nil then db.minimapPerformance = db.minimap_performance end

  if db.square_mask == nil and db.squareMinimap ~= nil then db.square_mask = db.squareMinimap end
  if db.squareMinimap == nil and db.square_mask ~= nil then db.squareMinimap = db.square_mask end
  if db.square_mask == nil then db.square_mask = true end
  if db.squareMinimap == nil then db.squareMinimap = db.square_mask end

  if db.hideMinimapToggleButton == nil then db.hideMinimapToggleButton = true end

  if db.sink_addons == nil then db.sink_addons = true end
  if db.sink_visible == nil and db.sinkEnabled ~= nil then db.sink_visible = db.sinkEnabled end
  if db.sinkEnabled == nil and db.sink_visible ~= nil then db.sinkEnabled = db.sink_visible end
  if db.sink_visible == nil then db.sink_visible = false end
  if db.sinkEnabled == nil then db.sinkEnabled = db.sink_visible end

  if db.sink_scan_interval == nil then
    db.sink_scan_interval = type(db.scanInterval) == "number" and db.scanInterval or 5
  end
  db.scanInterval = db.sink_scan_interval

  db.sink_anchor = db.sink_anchor or {}
end

local function GetDB()
  EnsureDefaults()
  return ETBC.db.profile.minimapPlus
end

local function Apply()
  if ETBC.ApplyBus and ETBC.ApplyBus.Notify then
    ETBC.ApplyBus:Notify("minimapplus")
  elseif ETBC.Modules and ETBC.Modules.MinimapPlus and ETBC.Modules.MinimapPlus.Apply then
    ETBC.Modules.MinimapPlus:Apply()
  end
end

ETBC.SettingsRegistry:RegisterGroup("minimapplus", {
  name = "Minimap",
  order = 30,
  options = function()
    EnsureDefaults()
    local db = GetDB()

    return {
      enabled = {
        type = "toggle",
        name = "Enable",
        order = 1,
        width = "full",
        get = function() return db.enabled end,
        set = function(_, v)
          db.enabled = v and true or false
          Apply()
        end,
      },

      layoutHeader = {
        type = "header",
        name = "Layout",
        order = 5,
      },

      squareMask = {
        type = "toggle",
        name = "Square Minimap Mask",
        order = 6,
        width = "full",
        get = function() return db.square_mask end,
        set = function(_, v)
          db.square_mask = v and true or false
          db.squareMinimap = db.square_mask
          Apply()
        end,
      },

      hideToggle = {
        type = "toggle",
        name = "Hide Minimap Toggle Button",
        order = 7,
        width = "full",
        get = function() return db.hideMinimapToggleButton end,
        set = function(_, v)
          db.hideMinimapToggleButton = v and true or false
          Apply()
        end,
      },

      rowsHeader = {
        type = "header",
        name = "Rows",
        order = 10,
      },

      iconsRow = {
        type = "toggle",
        name = "Show Icons Row",
        desc = "Displays friends, guild, bag space, and durability info above the minimap.",
        order = 11,
        width = "full",
        get = function() return db.minimap_icons end,
        set = function(_, v)
          db.minimap_icons = v and true or false
          db.minimapIcons = db.minimap_icons
          Apply()
        end,
      },

      performanceRow = {
        type = "toggle",
        name = "Show Performance Row",
        desc = "Displays ms and fps below the minimap.",
        order = 12,
        width = "full",
        get = function() return db.minimap_performance end,
        set = function(_, v)
          db.minimap_performance = v and true or false
          db.minimapPerformance = db.minimap_performance
          Apply()
        end,
      },

      sinkHeader = {
        type = "header",
        name = "Button Sink",
        order = 20,
      },

      sinkAddons = {
        type = "toggle",
        name = "Enable Addon Button Sink",
        desc = "Captures LibDBIcon addon minimap buttons into the sink tray.",
        order = 21,
        width = "full",
        get = function() return db.sink_addons end,
        set = function(_, v)
          db.sink_addons = v and true or false
          Apply()
        end,
      },

      sinkVisible = {
        type = "toggle",
        name = "Show Sink Tray",
        desc = "Also available from right-clicking the EnhanceTBC minimap icon.",
        order = 22,
        width = "full",
        disabled = function() return not db.sink_addons end,
        get = function() return db.sink_visible end,
        set = function(_, v)
          db.sink_visible = v and true or false
          db.sinkEnabled = db.sink_visible
          Apply()
        end,
      },

      sinkScanInterval = {
        type = "range",
        name = "Sink Scan Interval (sec)",
        desc = "How often to rescan for newly loaded addon minimap buttons.",
        order = 23,
        min = 1, max = 30, step = 1,
        disabled = function() return not db.sink_addons end,
        get = function() return tonumber(db.sink_scan_interval) or 5 end,
        set = function(_, v)
          db.sink_scan_interval = tonumber(v) or 5
          db.scanInterval = db.sink_scan_interval
          Apply()
        end,
      },
    }
  end,
})

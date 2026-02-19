-- Settings/Settings_MinimapPlus.lua
-- AceConfig options for Modules/MinimapPlus.lua

local ADDON_NAME, ETBC = ...
ETBC.Settings = ETBC.Settings or {}

local function EnsureDefaults()
  if not ETBC.db or not ETBC.db.profile then return end
  ETBC.db.profile.minimapPlus = ETBC.db.profile.minimapPlus or {}
  local db = ETBC.db.profile.minimapPlus

  if db.enabled == nil then db.enabled = true end
  if db.minimapIcons == nil then db.minimapIcons = true end
  if db.minimapPerformance == nil then db.minimapPerformance = false end
  if db.hideMinimapToggleButton == nil then db.hideMinimapToggleButton = true end
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

ETBC.Settings.MinimapPlus = function()
  EnsureDefaults()

  return {
    type = "group",
    name = "Minimap",
    order = 30,
    args = {
      enabled = {
        type = "toggle",
        name = "Enable",
        order = 1,
        width = "full",
        get = function() return GetDB().enabled end,
        set = function(_, v)
          GetDB().enabled = v and true or false
          Apply()
        end,
      },

      iconsRow = {
        type = "toggle",
        name = "Show Icons Row",
        desc = "Displays friends, guild, bag space, and durability info above the minimap.",
        order = 10,
        width = "full",
        get = function() return GetDB().minimapIcons end,
        set = function(_, v)
          GetDB().minimapIcons = v and true or false
          Apply()
        end,
      },

      performanceRow = {
        type = "toggle",
        name = "Show Performance Row",
        desc = "Displays ms and fps below the minimap.",
        order = 11,
        width = "full",
        get = function() return GetDB().minimapPerformance end,
        set = function(_, v)
          GetDB().minimapPerformance = v and true or false
          Apply()
        end,
      },

      hideToggle = {
        type = "toggle",
        name = "Hide Minimap Toggle Button",
        order = 12,
        width = "full",
        get = function() return GetDB().hideMinimapToggleButton end,
        set = function(_, v)
          GetDB().hideMinimapToggleButton = v and true or false
          Apply()
        end,
      },
    },
  }
end

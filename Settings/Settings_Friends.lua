-- Settings/Settings_Friends.lua
local ADDON_NAME, ETBC = ...

local function GetDB()
  ETBC.db.profile.friends = ETBC.db.profile.friends or {}
  local db = ETBC.db.profile.friends

  if db.enabled == nil then db.enabled = true end
  if db.showLocation == nil then db.showLocation = true end
  if db.hideOwnRealm == nil then db.hideOwnRealm = true end
  if db.nameFontSize == nil then db.nameFontSize = 0 end

  return db
end

local function Apply()
  if ETBC.ApplyBus and ETBC.ApplyBus.Notify then
    ETBC.ApplyBus:Notify("friends")
  end
end

ETBC.SettingsRegistry:RegisterGroup("friends", {
  name = "Friends",
  order = 35,
  options = function()
    local db = GetDB()

    return {
      enabled = {
        type = "toggle",
        name = "Enable Friends List Enhancements",
        desc = "Enable EnhanceQoL-style friends list with area/realm display, class colors, and level display",
        width = "full",
        order = 1,
        get = function() return db.enabled end,
        set = function(_, v) 
          db.enabled = v and true or false
          Apply()
        end,
      },

      header1 = {
        type = "header",
        name = "Display Options",
        order = 10,
      },

      showLocation = {
        type = "toggle",
        name = "Show Location",
        desc = "Show area and realm information in the friends list",
        width = "full",
        order = 11,
        get = function() return db.showLocation end,
        set = function(_, v) 
          db.showLocation = v and true or false
          Apply()
        end,
        disabled = function() return not db.enabled end,
      },

      hideOwnRealm = {
        type = "toggle",
        name = "Hide Own Realm",
        desc = "Hide your own realm name to reduce clutter",
        width = "full",
        order = 12,
        get = function() return db.hideOwnRealm end,
        set = function(_, v) 
          db.hideOwnRealm = v and true or false
          Apply()
        end,
        disabled = function() return not db.enabled or not db.showLocation end,
      },

      nameFontSize = {
        type = "range",
        name = "Name Font Size",
        desc = "Adjust the font size for friend names (0 = default size)",
        order = 13,
        min = 0,
        max = 24,
        step = 1,
        get = function() return db.nameFontSize end,
        set = function(_, v) 
          db.nameFontSize = v
          Apply()
        end,
        disabled = function() return not db.enabled end,
      },

      header2 = {
        type = "header",
        name = "Features",
        order = 20,
      },

      info = {
        type = "description",
        name = "This module provides:\n" ..
               "• Class-colored character names\n" ..
               "• Level display with difficulty coloring\n" ..
               "• Area and realm display (WoW friends)\n" ..
               "• Faction icons for cross-faction friends\n" ..
               "• Battle.net Rich Presence support\n" ..
               "• Improved offline friend display",
        order = 21,
      },
    }
  end,
})

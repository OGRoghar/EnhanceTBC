-- Settings/Settings_Friends.lua
local ADDON_NAME, ETBC = ...

local function GetDB()
  ETBC.db.profile.friends = ETBC.db.profile.friends or {}
  local db = ETBC.db.profile.friends

  if db.enabled == nil then db.enabled = true end
  if db.classColors == nil then db.classColors = true end
  if db.levelColors == nil then db.levelColors = true end
  if db.offlineGray == nil then db.offlineGray = true end
  if db.showStatus == nil then db.showStatus = true end
  if db.showZoneColor == nil then db.showZoneColor = false end

  -- subtle tinting for online names if classColors is off
  if db.onlineNameColor == nil then db.onlineNameColor = { r = 0.70, g = 1.00, b = 0.70, a = 1 } end

  return db
end

ETBC.SettingsRegistry:RegisterGroup("friends", {
  name = "Friends",
  order = 35,
  options = function()
    local db = GetDB()

    return {
      enabled = {
        type = "toggle",
        name = "Enable FriendsListDecor",
        order = 1,
        get = function() return db.enabled end,
        set = function(_, v) db.enabled = v and true or false; ETBC.ApplyBus:Notify("friends") end,
      },

      visuals = {
        type = "group",
        name = "Visuals",
        order = 10,
        inline = true,
        args = {
          classColors = {
            type = "toggle",
            name = "Class color names",
            order = 1,
            get = function() return db.classColors end,
            set = function(_, v) db.classColors = v and true or false; ETBC.ApplyBus:Notify("friends") end,
            disabled = function() return not db.enabled end,
          },
          levelColors = {
            type = "toggle",
            name = "Color level by difficulty",
            order = 2,
            get = function() return db.levelColors end,
            set = function(_, v) db.levelColors = v and true or false; ETBC.ApplyBus:Notify("friends") end,
            disabled = function() return not db.enabled end,
          },
          offlineGray = {
            type = "toggle",
            name = "Gray out offline friends",
            order = 3,
            get = function() return db.offlineGray end,
            set = function(_, v) db.offlineGray = v and true or false; ETBC.ApplyBus:Notify("friends") end,
            disabled = function() return not db.enabled end,
          },
          showStatus = {
            type = "toggle",
            name = "Show AFK/DND tag tint",
            order = 4,
            get = function() return db.showStatus end,
            set = function(_, v) db.showStatus = v and true or false; ETBC.ApplyBus:Notify("friends") end,
            disabled = function() return not db.enabled end,
          },
          showZoneColor = {
            type = "toggle",
            name = "Tint zone text (subtle)",
            order = 5,
            get = function() return db.showZoneColor end,
            set = function(_, v) db.showZoneColor = v and true or false; ETBC.ApplyBus:Notify("friends") end,
            disabled = function() return not db.enabled end,
          },
          onlineNameColor = {
            type = "color",
            name = "Online name color (when class color off)",
            order = 6,
            hasAlpha = false,
            get = function()
              local c = db.onlineNameColor or { r = 0.70, g = 1.00, b = 0.70 }
              return c.r, c.g, c.b
            end,
            set = function(_, r, g, b)
              db.onlineNameColor = db.onlineNameColor or {}
              db.onlineNameColor.r, db.onlineNameColor.g, db.onlineNameColor.b = r, g, b
              ETBC.ApplyBus:Notify("friends")
            end,
            disabled = function() return not db.enabled end,
          },
        },
      },
    }
  end,
})

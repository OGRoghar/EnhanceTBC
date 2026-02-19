-- Settings/Settings_General.lua
local _, ETBC = ...
local function EnsureDefaults()
  if not ETBC.db or not ETBC.db.profile then return end
  ETBC.db.profile.general = ETBC.db.profile.general or {}
  ETBC.db.profile.general.ui = ETBC.db.profile.general.ui or {}
end
ETBC.SettingsRegistry:RegisterGroup("general", {
  name = "General",
  order = 1,
  options = function()
    EnsureDefaults()
    return {
      infoHeader = {
        type = "header",
        name = "EnhanceTBC Settings",
        order = 0,
      },

      liveUpdateInfo = {
        type = "description",
        name = "|cff00ff00✓ Live Updates:|r Most settings apply immediately without requiring a /reload.\n"
          .. "|cffffaa00Note:|r Some CVars and certain UI changes may require a reload to take full effect.",
        order = 0.5,
        width = "full",
      },

      enabled = {
        type = "toggle",
        name = "Enable EnhanceTBC",
        desc = "Master enable/disable.",
        order = 1,
        get = function() return ETBC.db.profile.general.enabled end,
        set = function(_, v)
          ETBC.db.profile.general.enabled = v and true or false
          ETBC.ApplyBus:NotifyAll()
        end,
      },

      ui = {
        type = "group",
        name = "UI",
        order = 10,
        inline = true,
        args = {
          theme = {
            type = "select",
            name = "Theme",
            order = 1,
            values = {
              WarcraftGreen = "Warcraft Green",
              BlackSteel = "Black Steel",
            },
            get = function() return ETBC.db.profile.general.ui.theme end,
            set = function(_, v)
              ETBC.db.profile.general.ui.theme = v
              ETBC.ApplyBus:Notify("general")
            end,
          },
          scale = {
            type = "range",
            name = "Config Scale",
            order = 2,
            min = 0.85, max = 1.25, step = 0.01,
            get = function() return ETBC.db.profile.general.ui.scale end,
            set = function(_, v)
              ETBC.db.profile.general.ui.scale = v
              ETBC.ApplyBus:Notify("general")
              if ETBC.UI and ETBC.UI.frame and ETBC.UI.frame.frame then
                ETBC.UI.frame.frame:SetScale(v)
              end
            end,
          },
          debug = {
            type = "toggle",
            name = "Debug Logging",
            order = 3,
            get = function() return ETBC.db.profile.general.debug end,
            set = function(_, v)
              ETBC.db.profile.general.debug = v and true or false
            end,
          },
        }
      },
    }
  end,
})

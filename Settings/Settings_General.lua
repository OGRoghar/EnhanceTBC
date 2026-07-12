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
        name = "✓ Live Updates: Most settings apply immediately without requiring a /reload.\n"
          .. "Note: Some CVars and certain UI changes may require a reload to take full effect.",
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

      presets = {
        type = "group",
        name = "Setup Presets",
        desc = "Apply a curated starting point. You can continue adjusting every setting afterward.",
        order = 5,
        inline = true,
        args = {
          selected = {
            type = "select",
            name = "Preset",
            order = 1,
            values = function() return (ETBC.Presets and ETBC.Presets.names) or {} end,
            get = function() return ETBC.db.profile.general.pendingPreset or "ENHANCED" end,
            set = function(_, v) ETBC.db.profile.general.pendingPreset = v end,
          },
          apply = {
            type = "execute",
            name = "Apply Preset",
            confirm = true,
            confirmText = "Apply this preset? Your current profile will be saved as a one-level preset backup.",
            order = 2,
            func = function()
              if ETBC.Presets and ETBC.Presets.Apply then
                ETBC.Presets:Apply(ETBC.db.profile.general.pendingPreset or "ENHANCED")
              end
            end,
          },
          undo = {
            type = "execute",
            name = "Undo Last Preset",
            order = 3,
            func = function()
              if not (ETBC.Presets and ETBC.Presets.Undo) then return end
              local ok, err = ETBC.Presets:Undo()
              if ETBC.Print then
                ETBC:Print(ok and "Restored the pre-preset profile." or ("Undo preset failed: " .. tostring(err)))
              end
            end,
          },
        },
      },

      diagnostics = {
        type = "execute",
        name = "Print Diagnostics",
        desc = "Prints addon/client version, build, module state, combat lockdown, Plater detection, and Lua memory.",
        order = 6,
        func = function()
          if ETBC.PrintDiagnostics then ETBC:PrintDiagnostics() end
        end,
      },

      selfTest = {
        type = "execute",
        name = "Run Compatibility Self-Test",
        desc = "Checks required build-68575 APIs and core addon services without invoking protected actions.",
        order = 6.5,
        func = function()
          if ETBC.RunSelfTest then ETBC:RunSelfTest() end
        end,
      },

      undoImport = {
        type = "execute",
        name = "Undo Last Profile Import",
        desc = "Restores the profile snapshot saved immediately before the most recent confirmed import.",
        order = 7,
        func = function()
          if not ETBC.UndoLastProfileImport then return end
          local ok, err = ETBC:UndoLastProfileImport()
          if ETBC.Print then
            ETBC:Print(ok and "Restored the pre-import profile." or ("Undo import failed: " .. tostring(err)))
          end
        end,
      },

      clearFavorites = {
        type = "execute",
        name = "Clear Module Favorites",
        desc = "Clears the Favorites section in the /etbc module tree. Reopen the window to rebuild the tree.",
        order = 8,
        func = function()
          local profile = ETBC.db and ETBC.db.profile
          if profile and profile.ui and profile.ui.config then
            if type(profile.ui.config.moduleFavorites) == "table" then
              wipe(profile.ui.config.moduleFavorites)
            end
          end
        end,
      },

      clearRecent = {
        type = "execute",
        name = "Clear Recently Changed",
        desc = "Clears the Recently Changed section in the /etbc module tree. Reopen the window to rebuild the tree.",
        order = 9,
        func = function()
          local profile = ETBC.db and ETBC.db.profile
          if profile and profile.ui and profile.ui.config then
            if type(profile.ui.config.recentModules) == "table" then
              wipe(profile.ui.config.recentModules)
            end
          end
        end,
      },

      ui = {
        type = "group",
        name = "UI",
        desc = "Global addon UI frame theming/scaling used by shared EnhanceTBC windows "
          .. "(not the /etbc config theme selector).",
        order = 10,
        inline = true,
        args = {
          theme = {
            type = "select",
            name = "Addon UI theme",
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
              ETBC.db.profile.ui = ETBC.db.profile.ui or {}
              ETBC.db.profile.ui.config = ETBC.db.profile.ui.config or {}
              ETBC.db.profile.ui.config.scale = v
              ETBC.ApplyBus:Notify("general")
              local window = ETBC.UI and ETBC.UI.ConfigWindow and ETBC.UI.ConfigWindow.Internal
                and ETBC.UI.ConfigWindow.Internal.Window
              if window and window.SetWindowScale then
                window.SetWindowScale(v)
              end
            end,
          },
          debug = {
            type = "toggle",
            name = "Debug Logging",
            desc = "Enables extra debug output for troubleshooting. Leave off during normal play.",
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

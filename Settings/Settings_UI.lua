-- Settings/Settings_UI.lua
-- EnhanceTBC - UI settings (global quality-of-life)

local ADDON_NAME, ETBC = ...
local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceTBC")
local function GetDB()
  ETBC.db.profile.ui = ETBC.db.profile.ui or {}
  local db = ETBC.db.profile.ui

  if db.enabled == nil then db.enabled = true end

  -- Camera max zoom (zoom out further from character)
  if db.cameraMaxZoom == nil then db.cameraMaxZoom = true end
  if db.cameraMaxZoomFactor == nil then db.cameraMaxZoomFactor = 2.6 end

  return db
end

ETBC.SettingsRegistry:RegisterGroup("ui", {
  name = "UI",
  order = 8,
  options = function()
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
          ETBC.ApplyBus:Notify("ui")
        end,
      },

      cameraHeader = { type = "header", name = "Camera", order = 10 },

      cameraMaxZoom = {
        type = "toggle",
        name = "Increase max camera zoom distance",
        desc = "One-shot apply: sets your max zoom when enabled/changed, and does not keep re-applying after.",
        order = 11,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.cameraMaxZoom end,
        set = function(_, v)
          db.cameraMaxZoom = v and true or false
          ETBC.ApplyBus:Notify("ui")
        end,
      },

      cameraMaxZoomFactor = {
        type = "range",
        name = "Max zoom factor",
        desc = "Common values: 2.6 (classic-feel), 3.0+ (very far). One-shot apply.",
        order = 12,
        min = 1.0, max = 4.0, step = 0.1,
        disabled = function() return not (db.enabled and db.cameraMaxZoom) end,
        get = function() return db.cameraMaxZoomFactor end,
        set = function(_, v)
          db.cameraMaxZoomFactor = v
          ETBC.ApplyBus:Notify("ui")
        end,
      },

      resetHeader = { type = "header", name = "Tools", order = 90 },

      restoreNow = {
        type = "execute",
        name = "Restore previous zoom now",
        desc = "Restores the value from before EnhanceTBC changed it (if available this session).",
        order = 91,
        disabled = function() return not db.enabled end,
        func = function()
          if ETBC.Modules and ETBC.Modules.UI and ETBC.Modules.UI.RestoreCameraZoom then
            ETBC.Modules.UI:RestoreCameraZoom(true)
          end
        end,
      },
    }
  end,
})

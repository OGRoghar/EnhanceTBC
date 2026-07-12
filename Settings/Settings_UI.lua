-- Settings/Settings_UI.lua
-- EnhanceTBC - UI settings (global quality-of-life)

local _, ETBC = ...
local function GetDB()
  ETBC.db.profile.ui = ETBC.db.profile.ui or {}
  local db = ETBC.db.profile.ui

  if db.enabled == nil then db.enabled = true end

  -- Camera max zoom (zoom out further from character)
  if db.cameraMaxZoom == nil then db.cameraMaxZoom = true end
  if db.cameraMaxZoomFactor == nil then db.cameraMaxZoomFactor = 2.6 end
  if db.deleteWordForHighQuality == nil then db.deleteWordForHighQuality = true end

  return db
end

local function GetConfigWindowDB()
  if not (ETBC and ETBC.db and ETBC.db.profile) then return nil end
  ETBC.db.profile.ui = ETBC.db.profile.ui or {}
  ETBC.db.profile.ui.config = ETBC.db.profile.ui.config or {}
  local cfg = ETBC.db.profile.ui.config
  return cfg
end

local function EnsureDefaults()
  if not ETBC.db or not ETBC.db.profile then return end
  GetDB()
end

ETBC.SettingsRegistry:RegisterGroup("ui", {
  name = "UI",
  order = 8,
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

      deleteHeader = { type = "header", name = "Delete Protection", order = 30 },

      deleteWordForHighQuality = {
        type = "toggle",
        name = "Require typing DELETE for rare/epic/legendary",
        desc = "Adds a text confirmation step when deleting quality 3+ items from bags.",
        order = 31,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.deleteWordForHighQuality end,
        set = function(_, v)
          db.deleteWordForHighQuality = v and true or false
          ETBC.ApplyBus:Notify("ui")
        end,
      },

      configWindowHeader = { type = "header", name = "Config Window", order = 60 },

      configTextScale = {
        type = "range",
        name = "Control Center text scale",
        desc = "Adjusts text inside the modern configuration window.",
        order = 61,
        min = 0.9, max = 1.25, step = 0.05,
        disabled = function() return not db.enabled end,
        get = function()
          local cfg = GetConfigWindowDB()
          return (cfg and cfg.textScale) or 1
        end,
        set = function(_, v)
          local cfg = GetConfigWindowDB(); if cfg then cfg.textScale = tonumber(v) or 1 end
          if ETBC.UI and ETBC.UI.ControlCenter then ETBC.UI.ControlCenter:RefreshAccessibility() end
        end,
      },

      configHighContrast = {
        type = "toggle", name = "High contrast", order = 62,
        desc = "Strengthens borders and secondary text without changing the visual identity.",
        get = function() local cfg=GetConfigWindowDB(); return cfg and cfg.highContrast or false end,
        set = function(_,v) local cfg=GetConfigWindowDB(); if cfg then cfg.highContrast=v and true or false end; if ETBC.UI and ETBC.UI.ControlCenter then ETBC.UI.ControlCenter:RefreshAccessibility() end end,
      },

      configReducedMotion = {
        type = "toggle", name = "Reduced motion", order = 63,
        desc = "Disables nonessential interface fades and transitions.",
        get = function() local cfg=GetConfigWindowDB(); return cfg and cfg.reducedMotion or false end,
        set = function(_,v) local cfg=GetConfigWindowDB(); if cfg then cfg.reducedMotion=v and true or false end end,
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

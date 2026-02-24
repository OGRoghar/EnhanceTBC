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

local function GetConfigWindowThemeHelpers()
  local ui = ETBC and ETBC.UI
  local cw = ui and ui.ConfigWindow
  local internal = cw and cw.Internal
  return internal and internal.Theme or nil, internal and internal.Window or nil
end

local function GetConfigWindowDB()
  local themeHelpers = select(1, GetConfigWindowThemeHelpers())
  local dataHelpers = ETBC and ETBC.UI and ETBC.UI.ConfigWindow and ETBC.UI.ConfigWindow.Internal
    and ETBC.UI.ConfigWindow.Internal.Data or nil

  if dataHelpers and type(dataHelpers.GetUIDB) == "function" then
    return dataHelpers.GetUIDB()
  end

  if not (ETBC and ETBC.db and ETBC.db.profile) then return nil end
  ETBC.db.profile.ui = ETBC.db.profile.ui or {}
  ETBC.db.profile.ui.config = ETBC.db.profile.ui.config or {}
  local cfg = ETBC.db.profile.ui.config
  if cfg.theme == nil then
    cfg.theme = (themeHelpers and themeHelpers.DEFAULT_THEME_KEY) or "EnhanceGreen"
  end
  return cfg
end

local function GetConfigThemeChoices()
  local themeHelpers = select(1, GetConfigWindowThemeHelpers())
  if themeHelpers and type(themeHelpers.GetConfigThemeChoices) == "function" then
    return themeHelpers.GetConfigThemeChoices()
  end
  return {
    EnhanceGreen = "Enhance Green",
    WoWBasic = "WoW Basic",
  }
end

local function SetConfigWindowTheme(themeKey)
  local cfg = GetConfigWindowDB()
  if not cfg then return end

  local themeHelpers, windowHelpers = GetConfigWindowThemeHelpers()
  cfg.theme = tostring(themeKey or "")

  if themeHelpers and type(themeHelpers.ApplyConfigTheme) == "function" then
    cfg.theme = themeHelpers.ApplyConfigTheme(cfg.theme)
  end

  if windowHelpers and type(windowHelpers.RefreshTheme) == "function" then
    pcall(windowHelpers.RefreshTheme)
  end
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

      configWindowTheme = {
        type = "select",
        name = "Config window theme",
        desc = "Applies only to the custom /etbc config window and updates live when it is open.",
        order = 61,
        width = "full",
        disabled = function() return not db.enabled end,
        values = function()
          return GetConfigThemeChoices()
        end,
        get = function()
          local cfg = GetConfigWindowDB()
          return (cfg and cfg.theme) or "EnhanceGreen"
        end,
        set = function(_, v)
          SetConfigWindowTheme(v)
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

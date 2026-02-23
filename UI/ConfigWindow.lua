-- UI/ConfigWindow.lua
-- EnhanceTBC - Custom config window that renders AceConfig-style options tables
-- using AceGUI widgets, with SettingsRegistry group tree + search.
--
-- IMPORTANT:
-- - This file supports AceConfig "info" paths (get/set/disabled/hidden/values/func)
-- - It also supports legacy tables where get/set expect the option table itself.
-- - Groups are sourced from ETBC.SettingsRegistry:GetGroups()

local _, ETBC = ...
ETBC.UI = ETBC.UI or {}
local UI = ETBC.UI

UI.ConfigWindow = UI.ConfigWindow or {}
local ConfigWindow = UI.ConfigWindow
ConfigWindow.Internal = ConfigWindow.Internal or {}

local ThemeHelpers = ConfigWindow.Internal.Theme or {}

if not StaticPopupDialogs.ETBC_EXEC_CONFIRM then
  StaticPopupDialogs.ETBC_EXEC_CONFIRM = {
    text = "%s",
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, data)
      if data and type(data.exec) == "function" then
        pcall(data.exec)
      end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
  }
end

local THEME = ThemeHelpers.THEME

function ConfigWindow.GetTheme()
  return THEME
end

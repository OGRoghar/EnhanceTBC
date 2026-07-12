-- UI/ConfigWindow.lua
-- EnhanceTBC Control Center namespace and shared confirmation dialog.

local _, ETBC = ...
ETBC.UI = ETBC.UI or {}
local UI = ETBC.UI

UI.ConfigWindow = UI.ConfigWindow or {}
local ConfigWindow = UI.ConfigWindow

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

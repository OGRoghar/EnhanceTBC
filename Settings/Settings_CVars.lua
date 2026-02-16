-- Settings/Settings_CVars.lua
-- EnhanceTBC - SettingsRegistry registration for CVars module

local ADDON_NAME, ETBC = ...
local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceTBC")
if not ETBC.SettingsRegistry or type(ETBC.SettingsRegistry.RegisterGroup) ~= "function" then
  return
end

ETBC.SettingsRegistry:RegisterGroup("cvars", {
  name = "CVars",
  order = 260,
  category = "Utility",
  options = function()
    if ETBC.Modules and ETBC.Modules.CVars and ETBC.Modules.CVars.BuildOptions then
      return ETBC.Modules.CVars:BuildOptions()
    end
    return {
      type = "group",
      name = "CVars",
      args = {
        _missing = { type = "description", name = "CVars module not available.", order = 1 },
      },
    }
  end,
})
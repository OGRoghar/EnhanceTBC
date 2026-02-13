-- Settings/Settings_Minimap.lua
-- EnhanceTBC - Minimap button settings

local ADDON_NAME, ETBC = ...

local function GetDB()
  ETBC.db.profile.minimapIcon = ETBC.db.profile.minimapIcon or {}
  local db = ETBC.db.profile.minimapIcon
  if db.hide == nil then db.hide = false end
  return db
end

ETBC.SettingsRegistry:RegisterGroup("minimap", {
  name = "Minimap",
  order = 7,
  options = function()
    local db = GetDB()

    return {
      showIcon = {
        type = "toggle",
        name = "Show minimap button",
        order = 1,
        width = "full",
        get = function() return not db.hide end,
        set = function(_, v)
          db.hide = not (v and true or false)
          if ETBC.ToggleMinimapIcon then
            ETBC:ToggleMinimapIcon(v and true or false)
          elseif ETBC.InitMinimapIcon then
            ETBC:InitMinimapIcon()
          end
        end,
      },
    }
  end,
})

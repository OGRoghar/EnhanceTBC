-- Modules/Minimap.lua
-- EnhanceTBC - Minimap apply driver (show/hide + register)
-- Core/MinimapButton.lua owns the actual LDB/DBIcon implementation.

local ADDON_NAME, ETBC = ...

ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.Minimap = mod

local function GetDB()
  if not ETBC.db or not ETBC.db.profile then return nil end
  ETBC.db.profile.minimapIcon = ETBC.db.profile.minimapIcon or { hide = false }
  return ETBC.db.profile.minimapIcon
end

local function Apply()
  local generalEnabled = ETBC.db and ETBC.db.profile and ETBC.db.profile.general and ETBC.db.profile.general.enabled
  if not generalEnabled then return end

  local db = GetDB()
  if not db then return end

  -- Ensure icon exists
  if ETBC.InitMinimapIcon then
    ETBC:InitMinimapIcon()
  end

  -- Apply visibility
  if ETBC.ToggleMinimapIcon then
    ETBC:ToggleMinimapIcon(not db.hide)
  end
end

if ETBC.ApplyBus and ETBC.ApplyBus.Register then
  ETBC.ApplyBus:Register("general", Apply)
  ETBC.ApplyBus:Register("minimap", Apply)
end

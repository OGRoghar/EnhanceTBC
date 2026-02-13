-- Modules/UI.lua
-- EnhanceTBC - UI module (global QoL settings)
-- One-shot camera max zoom:
--  - Stores original cameraDistanceMaxZoomFactor (session)
--  - Applies chosen factor once on login and on setting changes
--  - Restores original when disabled
--
-- Performance: no OnUpdate. Minimal events.

local ADDON_NAME, ETBC = ...

ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.UI = mod

local driver
local storedZoom -- session-stored original zoom factor (string)

local function GetDB()
  ETBC.db.profile.ui = ETBC.db.profile.ui or {}
  return ETBC.db.profile.ui
end

local function EnsureDriver()
  if driver then return end
  driver = CreateFrame("Frame", "EnhanceTBC_UIDriver", UIParent)
end

local function SafeSetCVar(name, value)
  if not SetCVar then return end
  pcall(SetCVar, name, tostring(value))
end

local function SafeGetCVar(name)
  if not GetCVar then return nil end
  local ok, v = pcall(GetCVar, name)
  if ok then return v end
  return nil
end

function mod:StoreCameraZoomIfNeeded()
  if storedZoom ~= nil then return end
  storedZoom = SafeGetCVar("cameraDistanceMaxZoomFactor")
end

function mod:ApplyCameraZoomOneShot()
  local db = GetDB()
  if not (db and db.enabled and db.cameraMaxZoom) then return end

  self:StoreCameraZoomIfNeeded()

  local target = tonumber(db.cameraMaxZoomFactor) or 2.6
  if target < 1.0 then target = 1.0 end
  if target > 4.0 then target = 4.0 end

  SafeSetCVar("cameraDistanceMaxZoomFactor", target)
end

function mod:RestoreCameraZoom(force)
  local db = GetDB()
  if force or (db and (not db.enabled or not db.cameraMaxZoom)) then
    if storedZoom ~= nil then
      SafeSetCVar("cameraDistanceMaxZoomFactor", storedZoom)
    end
  end
end

local function Apply()
  EnsureDriver()

  local db = GetDB()
  local generalEnabled = ETBC.db.profile.general and ETBC.db.profile.general.enabled

  if not (generalEnabled and db.enabled) then
    mod:RestoreCameraZoom(true)
    driver:UnregisterAllEvents()
    driver:SetScript("OnEvent", nil)
    return
  end

  -- Apply immediately on ApplyBus changes (toggle/slider change)
  if db.cameraMaxZoom then
    mod:ApplyCameraZoomOneShot()
  else
    mod:RestoreCameraZoom(false)
  end

  -- One-shot apply at login/entering world (no CVAR_UPDATE reapply)
  driver:UnregisterAllEvents()
  driver:RegisterEvent("PLAYER_ENTERING_WORLD")

  driver:SetScript("OnEvent", function()
    local db2 = GetDB()
    if not (ETBC.db.profile.general and ETBC.db.profile.general.enabled and db2.enabled) then return end

    if db2.cameraMaxZoom then
      mod:ApplyCameraZoomOneShot()
    end
  end)
end

ETBC.ApplyBus:Register("ui", Apply)
ETBC.ApplyBus:Register("general", Apply)

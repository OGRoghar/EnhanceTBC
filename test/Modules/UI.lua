-- Modules/UI.lua
-- EnhanceTBC - UI module (global QoL settings)
-- One-shot camera max zoom:
--  - Stores original cameraDistanceMaxZoomFactor (session)
--  - Applies chosen factor once on login and on setting changes
--  - Restores original when disabled
--
-- Performance: no OnUpdate. Minimal events.

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.UI = mod

local driver
local storedZoom -- session-stored original zoom factor (string)
local deleteHookInstalled = false
local originalDeleteCursorItem

if not StaticPopupDialogs.ETBC_DELETE_WORD_CONFIRM then
  StaticPopupDialogs.ETBC_DELETE_WORD_CONFIRM = {
    text = "Type DELETE to permanently delete this item:\n%s",
    button1 = DELETE,
    button2 = CANCEL,
    hasEditBox = 1,
    maxLetters = 6,
    whileDead = 1,
    hideOnEscape = 1,
    timeout = 0,
    preferredIndex = 3,
    OnShow = function(self)
      if self and self.editBox then
        self.editBox:SetText("")
        self.editBox:SetFocus()
      end
      if self and self.button1 then
        self.button1:Disable()
      end
    end,
    EditBoxOnTextChanged = function(editBox)
      local parent = editBox and editBox:GetParent()
      local txt = (editBox and editBox:GetText() or ""):upper()
      if parent and parent.button1 then
        if txt == "DELETE" then
          parent.button1:Enable()
        else
          parent.button1:Disable()
        end
      end
    end,
    OnAccept = function(_, data)
      if not data or type(data.fn) ~= "function" then return end
      data.fn(unpack(data.args or {}))
    end,
  }
end

local function GetDB()
  ETBC.db.profile.ui = ETBC.db.profile.ui or {}
  local db = ETBC.db.profile.ui

  if db.enabled == nil then db.enabled = true end
  if db.cameraMaxZoom == nil then db.cameraMaxZoom = true end
  if db.cameraMaxZoomFactor == nil then db.cameraMaxZoomFactor = 2.6 end
  if db.deleteWordForHighQuality == nil then db.deleteWordForHighQuality = true end

  return db
end

local function CursorItemQualityAndLabel()
  if type(GetCursorInfo) ~= "function" then return nil, nil end

  local infoType, itemID, itemLink = GetCursorInfo()
  if infoType ~= "item" then return nil, nil end

  local quality
  if type(GetItemInfo) == "function" then
    local _, _, q = GetItemInfo(itemLink or itemID)
    quality = q
  end

  if not quality and type(GetItemInfoInstant) == "function" then
    local _, _, q = GetItemInfoInstant(itemLink or itemID)
    quality = q
  end

  return quality, itemLink or (itemID and ("item:" .. tostring(itemID))) or "item"
end

local function ShouldRequireDeleteWord(db)
  if not (db and db.enabled and db.deleteWordForHighQuality) then
    return false
  end

  local quality = CursorItemQualityAndLabel()
  return type(quality) == "number" and quality >= 3
end

local function EnsureDeleteHook()
  if deleteHookInstalled then return end
  if type(DeleteCursorItem) ~= "function" then return end

  originalDeleteCursorItem = DeleteCursorItem

  DeleteCursorItem = function(...)
    local db = GetDB()
    if ShouldRequireDeleteWord(db) then
      local _, label = CursorItemQualityAndLabel()
      StaticPopup_Show("ETBC_DELETE_WORD_CONFIRM", tostring(label or "item"), nil, {
        fn = originalDeleteCursorItem,
        args = { ... },
      })
      return
    end
    return originalDeleteCursorItem(...)
  end

  deleteHookInstalled = true
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

function mod.StoreCameraZoomIfNeeded()
  if storedZoom ~= nil then return end
  storedZoom = SafeGetCVar("cameraDistanceMaxZoomFactor")
end

function mod.ApplyCameraZoomOneShot()
  local db = GetDB()
  if not (db and db.enabled and db.cameraMaxZoom) then return end

  mod.StoreCameraZoomIfNeeded()

  local target = tonumber(db.cameraMaxZoomFactor) or 2.6
  if target < 1.0 then target = 1.0 end
  if target > 4.0 then target = 4.0 end

  SafeSetCVar("cameraDistanceMaxZoomFactor", target)
end

function mod.RestoreCameraZoom(force)
  local db = GetDB()
  if force or (db and (not db.enabled or not db.cameraMaxZoom)) then
    if storedZoom ~= nil then
      SafeSetCVar("cameraDistanceMaxZoomFactor", storedZoom)
    end
  end
end

local function Apply()
  EnsureDriver()
  EnsureDeleteHook()

  local db = GetDB()
  local generalEnabled = ETBC.db.profile.general and ETBC.db.profile.general.enabled

  if not (generalEnabled and db.enabled) then
    mod:RestoreCameraZoom(true)
    driver:UnregisterAllEvents()
    driver:SetScript("OnEvent", nil)
    driver:Hide()
    return
  end

  -- Apply immediately on ApplyBus changes (toggle/slider change)
  if db.cameraMaxZoom then
    mod.ApplyCameraZoomOneShot()
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
      mod.ApplyCameraZoomOneShot()
    end
  end)

  driver:Show()
end

ETBC.ApplyBus:Register("ui", Apply)
ETBC.ApplyBus:Register("general", Apply)

local ADDON_NAME, ETBC = ...

ETBC.FeatureSuite = ETBC.FeatureSuite or {}
local Suite = ETBC.FeatureSuite
local FEATURES = {
  hud = "EnhanceTBC_HUD",
  inventory = "EnhanceTBC_Inventory",
  combat = "EnhanceTBC_Combat",
}
local providers = {}
local editMode = false

local function Copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for key, child in pairs(value) do out[Copy(key, seen)] = Copy(child, seen) end
  return out
end

local function ProfileFeature(key)
  local profile = ETBC.db and ETBC.db.profile
  if not profile or not FEATURES[key] then return nil end
  profile.suite = profile.suite or {}
  profile.suite[key] = profile.suite[key] or { enabled = false }
  return profile.suite[key]
end

function Suite:Load(key)
  if not FEATURES[key] then return false, "unknown feature key" end
  return true
end

function Suite:GetState(key)
  local state = ProfileFeature(key)
  if not state then return nil, "unknown feature key" end
  local addon = FEATURES[key]
  return {
    key = key,
    addon = addon,
    available = true,
    loaded = true,
    integrated = true,
    enabled = state.enabled and true or false,
  }
end

function Suite:SetEnabled(key, enabled)
  if type(enabled) ~= "boolean" then return false, "enabled must be boolean" end
  local state = ProfileFeature(key)
  if not state then return false, "unknown feature key" end
  if state.enabled == enabled then return true end
  state.enabled = enabled
  local owned = ETBC.db.profile[key]
  if type(owned) == "table" then owned.enabled = enabled end
  if ETBC.ApplyBus then ETBC.ApplyBus:Notify(key) end
  if ETBC.PublicAPIInternal and ETBC.PublicAPIInternal.OnFeatureStateChanged then
    ETBC.PublicAPIInternal.OnFeatureStateChanged(key, enabled)
  end
  return true
end

function Suite:LoadEnabled()
  -- Runtime definitions are loaded by EnhanceTBC.toc. ApplyBus controls work.
end

function Suite:SetEditMode(enabled, scope)
  enabled = enabled and true or false
  if editMode == enabled then return true end
  editMode = enabled
  if ETBC.Mover and ETBC.Mover.SetMoveMode then ETBC.Mover:SetMoveMode(enabled) end
  if ETBC.PublicAPIInternal and ETBC.PublicAPIInternal.OnEditModeChanged then
    ETBC.PublicAPIInternal.OnEditModeChanged(enabled, tostring(scope or "all"))
  end
  return true
end

function Suite:IsEditMode() return editMode end

function Suite:RegisterProvider(owner, key, provider)
  if type(owner) ~= "table" and type(owner) ~= "string" then return false, "invalid owner" end
  if type(key) ~= "string" or key == "" then return false, "invalid provider key" end
  if type(provider) ~= "table" or type(provider.GetValue) ~= "function" then return false, "provider requires GetValue" end
  if providers[key] and providers[key].owner ~= owner then return false, "provider key already owned" end
  providers[key] = { owner = owner, provider = provider }
  return true
end

function Suite:UnregisterProvider(owner, key)
  local entry = providers[key]
  if not entry or entry.owner ~= owner then return false, "provider is not owned by caller" end
  providers[key] = nil
  return true
end

function Suite:GetProviderValue(key, context)
  local entry = providers[key]
  if not entry then return nil, "unknown provider" end
  local ok, value = pcall(entry.provider.GetValue, entry.provider, Copy(context or {}))
  if not ok then return nil, tostring(value) end
  return Copy(value)
end

function Suite:GetDiagnostics()
  local result = { editMode = editMode, features = {}, providerCount = 0 }
  for key in pairs(FEATURES) do result.features[key] = self:GetState(key) end
  for _ in pairs(providers) do result.providerCount = result.providerCount + 1 end
  return result
end

function ETBC:OpenSuiteSetup()
  if StaticPopup_Show and StaticPopupDialogs and StaticPopupDialogs.ETBC_SUITE_SETUP then
    StaticPopup_Show("ETBC_SUITE_SETUP", nil, nil, { owner = self })
  else
    self:OpenConfig()
  end
end

if StaticPopupDialogs and not StaticPopupDialogs.ETBC_SUITE_SETUP then
  StaticPopupDialogs.ETBC_SUITE_SETUP = {
    text = "Enable the EnhanceTBC next-generation suite? Features remain individually optional.",
    button1 = "Enable HUD",
    button2 = "Not Now",
    button3 = "Open Settings",
    timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
    OnAccept = function(_, data) if data and data.owner then Suite:SetEnabled("hud", true) end end,
    OnCancel = function(_, data)
      local general = data and data.owner and data.owner.db and data.owner.db.profile.general
      if general then general.suiteSetupCompleted = true end
    end,
    OnAlt = function(_, data) if data and data.owner then data.owner:OpenConfig() end end,
  }
end

ETBC.ApplyBus:Register("suite", function() Suite:LoadEnabled() end)

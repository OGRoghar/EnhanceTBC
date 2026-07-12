-- Stable integration surface for third-party addons.

local ADDON_NAME, ETBC = ...
if not ETBC then return end

local CallbackHandler = LibStub("CallbackHandler-1.0", true)
local API = _G.EnhanceTBC_API or {}
local callbacks = CallbackHandler and CallbackHandler:New(API) or nil
local publicMovers = {}
local publicVisibility = {}
local moduleSnapshot = {}
local ready = false

API.API_VERSION = 1

local VALID_CALLBACKS = {
  READY = true,
  MODULE_STATE_CHANGED = true,
  PROFILE_CHANGED = true,
  SETTINGS_APPLIED = true,
  FEATURE_STATE_CHANGED = true,
  EDIT_MODE_CHANGED = true,
  EQUIPMENT_AUDIT_UPDATED = true,
  COMBAT_SEGMENT_STARTED = true,
  COMBAT_SEGMENT_ENDED = true,
}

local function Copy(value, seen)
  if type(value) ~= "table" then return value end
  if type(value.GetObjectType) == "function" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for key, child in pairs(value) do
    out[Copy(key, seen)] = Copy(child, seen)
  end
  return out
end

local function Fire(event, ...)
  if callbacks and VALID_CALLBACKS[event] then
    callbacks:Fire(event, ...)
  end
end

if API.RegisterCallback then
  local RegisterCallback = API.RegisterCallback
  API.RegisterCallback = function(owner, event, handler, ...)
    if not VALID_CALLBACKS[event] then return false, "unknown callback event" end
    RegisterCallback(owner, event, handler, ...)
    return true
  end
end

local function NormalizeKey(value)
  if type(value) ~= "string" then return "" end
  return value:lower():gsub("[^a-z0-9]", "")
end

local function ResolveModuleKey(key)
  local target = NormalizeKey(key)
  if target == "" then return nil end
  local groups = ETBC.SettingsRegistry and ETBC.SettingsRegistry:GetGroups() or {}
  for i = 1, #groups do
    local candidate = groups[i] and groups[i].key
    if candidate and candidate ~= "general" and NormalizeKey(candidate) == target then return candidate end
  end
  return nil
end

local function GetProfileEntry(key)
  if not (ready and ETBC.db and type(ETBC.db.profile) == "table") then
    return nil, nil, nil
  end
  local moduleKey = ResolveModuleKey(key)
  local profileKey = moduleKey and ETBC.ResolveProfileKey and ETBC:ResolveProfileKey(moduleKey) or nil
  local entry = profileKey and ETBC.db.profile[profileKey] or nil
  if type(entry) ~= "table" or entry.enabled == nil then return nil, nil, nil end
  return moduleKey, profileKey, entry
end

local function GetMetricEnum()
  return Enum and Enum.AddOnProfilerMetric or nil
end

local function ReadMetric(metric)
  local ok, value = pcall(C_AddOnProfiler.GetAddOnMetric, ADDON_NAME, metric)
  if ok then return tonumber(value) end
  return nil
end

function API.GetAPIVersion()
  return API.API_VERSION
end

function API.GetAddonVersion()
  return tostring(ETBC.version or "unknown")
end

function API.IsReady()
  return ready and true or false
end

function API.GetModuleKeys()
  local out = {}
  if not ready then return out end
  local groups = ETBC.SettingsRegistry and ETBC.SettingsRegistry:GetGroups() or {}
  for i = 1, #groups do
    local key = groups[i] and groups[i].key
    if key and key ~= "general" and GetProfileEntry(key) then out[#out + 1] = key end
  end
  table.sort(out)
  return out
end

function API.GetModuleState(key)
  if type(key) ~= "string" or key == "" then return nil, "invalid module key" end
  if not ready then return nil, "addon not ready" end
  local moduleKey, profileKey, entry = GetProfileEntry(key)
  if not moduleKey then return nil, "unknown module key" end
  return {
    key = moduleKey,
    profileKey = profileKey,
    enabled = entry.enabled and true or false,
  }
end

function API.SetModuleEnabled(key, enabled)
  if type(key) ~= "string" or key == "" then return false, "invalid module key" end
  if type(enabled) ~= "boolean" then return false, "enabled must be boolean" end
  if not ready then return false, "addon not ready" end
  local moduleKey, _, entry = GetProfileEntry(key)
  if not entry then return false, "unknown module key" end
  if entry.enabled == enabled then return true end
  entry.enabled = enabled
  if ETBC.ApplyBus and ETBC.ApplyBus.Notify then ETBC.ApplyBus:Notify(moduleKey) end
  return true
end

function API.RequestRefresh(key)
  if type(key) ~= "string" or key == "" then return false, "invalid apply key" end
  if not ready then return false, "addon not ready" end
  local known = false
  local keys = ETBC.ApplyBus and ETBC.ApplyBus:Keys() or {}
  for i = 1, #keys do if keys[i] == key then known = true break end end
  if not known then return false, "unknown apply key" end
  ETBC.ApplyBus:Notify(key)
  return true
end


function API.RegisterMover(key, frame, options)
  if type(key) ~= "string" or key == "" then return false, "invalid mover key" end
  if not ready then return false, "addon not ready" end
  if type(frame) ~= "table" then return false, "frame must be a frame object" end
  if options ~= nil and type(options) ~= "table" then return false, "options must be a table" end
  if publicMovers[key] and publicMovers[key] ~= frame then return false, "mover key already owned" end
  local registered = ETBC.Mover and ETBC.Mover:GetRegistered() or {}
  if registered[key] and registered[key].frame ~= frame and not publicMovers[key] then
    return false, "mover key belongs to EnhanceTBC"
  end
  if not (ETBC.Mover and ETBC.Mover.Register) then return false, "mover service unavailable" end
  ETBC.Mover:Register(key, frame, Copy(options or {}))
  publicMovers[key] = frame
  return true
end

function API.UnregisterMover(key)
  if type(key) ~= "string" or key == "" then return false, "invalid mover key" end
  if not publicMovers[key] then return false, "mover key is not owned by public API" end
  if ETBC.Mover and ETBC.Mover.Unregister then ETBC.Mover:Unregister(key) end
  publicMovers[key] = nil
  return true
end

function API.BindVisibility(key, frame, ruleProvider, onChange)
  if type(key) ~= "string" or key == "" then return false, "invalid visibility key" end
  if not ready then return false, "addon not ready" end
  if type(frame) ~= "table" then return false, "frame must be a frame object" end
  if type(ruleProvider) ~= "function" then return false, "ruleProvider must be a function" end
  if onChange ~= nil and type(onChange) ~= "function" then return false, "onChange must be a function" end
  if not (ETBC.Visibility and ETBC.Visibility.Bind) then return false, "visibility service unavailable" end
  if ETBC.Visibility:IsBound(key) and not publicVisibility[key] then
    return false, "visibility key belongs to EnhanceTBC"
  end
  ETBC.Visibility:Bind(key, frame, ruleProvider, onChange)
  publicVisibility[key] = frame
  return true
end

function API.UnbindVisibility(key)
  if type(key) ~= "string" or key == "" then return false, "invalid visibility key" end
  if not publicVisibility[key] then return false, "visibility key is not owned by public API" end
  if not (ETBC.Visibility and ETBC.Visibility.Unbind) then return false, "visibility service unavailable" end
  ETBC.Visibility:Unbind(key)
  publicVisibility[key] = nil
  return true
end

function API.GetPerformanceSnapshot()
  local snapshot = {
    available = false,
    enabled = false,
    addonName = ADDON_NAME,
    metrics = {},
  }
  if not (C_AddOnProfiler and type(C_AddOnProfiler.IsEnabled) == "function"
    and type(C_AddOnProfiler.GetAddOnMetric) == "function") then
    snapshot.error = "C_AddOnProfiler unavailable"
    return snapshot
  end
  snapshot.available = true
  local ok, enabled = pcall(C_AddOnProfiler.IsEnabled)
  if not ok then snapshot.error = tostring(enabled); return snapshot end
  snapshot.enabled = enabled and true or false
  if not snapshot.enabled then return snapshot end

  local metric = GetMetricEnum()
  if type(metric) ~= "table" then snapshot.error = "AddOnProfilerMetric enum unavailable"; return snapshot end
  local definitions = {
    sessionAverageMs = metric.SessionAverageTime,
    recentAverageMs = metric.RecentAverageTime,
    lastTickMs = metric.LastTime,
    peakMs = metric.PeakTime,
    ticksOver1Ms = metric.CountTimeOver1Ms,
    ticksOver5Ms = metric.CountTimeOver5Ms,
    ticksOver10Ms = metric.CountTimeOver10Ms,
  }
  for name, enumValue in pairs(definitions) do
    if enumValue ~= nil then snapshot.metrics[name] = ReadMetric(enumValue) end
  end
  if type(C_AddOnProfiler.CheckForPerformanceMessage) == "function" then
    local warningOK, warning = pcall(C_AddOnProfiler.CheckForPerformanceMessage)
    if warningOK and type(warning) == "table" then snapshot.warning = Copy(warning) end
  end
  return snapshot
end

function API.GetDiagnostics()
  if not ready or not ETBC.GetDiagnostics then return nil, "addon not ready" end
  return Copy(ETBC:GetDiagnostics())
end

function API.GetFeatureState(key)
  if type(key) ~= "string" or key == "" then return nil, "invalid feature key" end
  if not ready then return nil, "addon not ready" end
  if not (ETBC.FeatureSuite and ETBC.FeatureSuite.GetState) then return nil, "feature service unavailable" end
  local state, reason = ETBC.FeatureSuite:GetState(NormalizeKey(key))
  return state and Copy(state) or nil, reason
end

function API.SetFeatureEnabled(key, enabled)
  if type(key) ~= "string" or key == "" then return false, "invalid feature key" end
  if type(enabled) ~= "boolean" then return false, "enabled must be boolean" end
  if not ready then return false, "addon not ready" end
  if not (ETBC.FeatureSuite and ETBC.FeatureSuite.SetEnabled) then return false, "feature service unavailable" end
  return ETBC.FeatureSuite:SetEnabled(NormalizeKey(key), enabled)
end

function API.OpenConfiguration(section)
  if section ~= nil and type(section) ~= "string" then return false, "section must be a string" end
  if not ready then return false, "addon not ready" end
  ETBC._requestedConfigSection = section
  if ETBC.OpenConfig then ETBC:OpenConfig(); return true end
  return false, "configuration unavailable"
end

function API.EnterEditMode(scope)
  if scope ~= nil and type(scope) ~= "string" then return false, "scope must be a string" end
  if not ready then return false, "addon not ready" end
  if not (ETBC.FeatureSuite and ETBC.FeatureSuite.SetEditMode) then return false, "edit mode unavailable" end
  return ETBC.FeatureSuite:SetEditMode(true, scope)
end

function API.RegisterDataProvider(owner, key, provider)
  if not ready then return false, "addon not ready" end
  if not ETBC.FeatureSuite then return false, "provider service unavailable" end
  return ETBC.FeatureSuite:RegisterProvider(owner, key, provider)
end

function API.UnregisterDataProvider(owner, key)
  if not ready then return false, "addon not ready" end
  if not ETBC.FeatureSuite then return false, "provider service unavailable" end
  return ETBC.FeatureSuite:UnregisterProvider(owner, key)
end

function API.GetEquipmentAudit(unit)
  if unit ~= nil and type(unit) ~= "string" then return nil, "unit must be a string" end
  if not ready then return nil, "addon not ready" end
  if not (ETBC.InventorySuite and ETBC.InventorySuite.GetAudit) then return nil, "inventory feature unavailable" end
  local result, reason = ETBC.InventorySuite:GetAudit(unit or "player")
  return result and Copy(result) or nil, reason
end

function API.GetCombatSnapshot(segment, category)
  if segment ~= nil and type(segment) ~= "string" and type(segment) ~= "number" then return nil, "invalid segment" end
  if category ~= nil and type(category) ~= "string" then return nil, "invalid category" end
  if not ready then return nil, "addon not ready" end
  if not (ETBC.CombatSuite and ETBC.CombatSuite.GetSnapshot) then return nil, "combat feature unavailable" end
  local result, reason = ETBC.CombatSuite:GetSnapshot(segment or "current", category or "damage")
  return result and Copy(result) or nil, reason
end

ETBC.GetPerformanceSnapshot = API.GetPerformanceSnapshot
ETBC.PublicAPIInternal = {
  MarkReady = function()
    if ready then return end
    ready = true
    local keys = API.GetModuleKeys()
    for i = 1, #keys do
      local state = API.GetModuleState(keys[i])
      if state then moduleSnapshot[keys[i]] = state.enabled end
    end
    Fire("READY", API.API_VERSION, API.GetAddonVersion())
  end,
  OnProfileChanged = function(reason)
    moduleSnapshot = {}
    Fire("PROFILE_CHANGED", tostring(reason or "unknown"))
  end,
  OnSettingsApplied = function(key)
    local state = API.GetModuleState(key)
    if state and moduleSnapshot[key] ~= state.enabled then
      moduleSnapshot[key] = state.enabled
      Fire("MODULE_STATE_CHANGED", key, state.enabled)
    end
    Fire("SETTINGS_APPLIED", key)
  end,
  OnFeatureStateChanged = function(key, enabled) Fire("FEATURE_STATE_CHANGED", key, enabled and true or false) end,
  OnEditModeChanged = function(enabled, scope) Fire("EDIT_MODE_CHANGED", enabled and true or false, scope) end,
  OnEquipmentAuditUpdated = function(unit) Fire("EQUIPMENT_AUDIT_UPDATED", unit) end,
  OnCombatSegmentStarted = function(id) Fire("COMBAT_SEGMENT_STARTED", id) end,
  OnCombatSegmentEnded = function(id) Fire("COMBAT_SEGMENT_ENDED", id) end,
}

ETBC.PublicAPI = API
_G.EnhanceTBC_API = API

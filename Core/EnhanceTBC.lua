-- Core/EnhanceTBC.lua
local ADDON_NAME, ETBC = ...
local AceAddon = LibStub("AceAddon-3.0")
local AceDB = LibStub("AceDB-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local AceSerializer = LibStub("AceSerializer-3.0", true)
local LibDeflate = LibStub("LibDeflate", true)

ETBC = AceAddon:NewAddon(
  ETBC,
  ADDON_NAME,
  "AceEvent-3.0",
  "AceConsole-3.0",
  "AceHook-3.0",
  "AceTimer-3.0",
  "AceBucket-3.0",
  "AceComm-3.0"
)
_G.EnhanceTBC = ETBC
_G.ETBC = ETBC

local PROFILE_COMM_PREFIX = "ETBCP1"
local PROFILE_EXPORT_VERSION = 1
local PROFILE_SCHEMA_VERSION = 2
local CURRENT_INTERFACE = 20506
local COMPATIBLE_PROFILE_INTERFACES = {
  [20505] = true,
  [CURRENT_INTERFACE] = true,
}
local blizPanel
local REMOVED_PROFILE_KEYS = {
  gcdbar = true,
  player_nameplates = true,
}

local function MigrateProfileSchema(profile)
  if type(profile) ~= "table" then return end
  profile.general = profile.general or {}
  local current = tonumber(profile.general.profileSchemaVersion) or 0

  if current < 2 then
    local legacyScale = profile.general.ui and profile.general.ui.scale
    if legacyScale ~= nil then
      profile.ui = profile.ui or {}
      profile.ui.config = profile.ui.config or {}
      if profile.ui.config.scale == nil then profile.ui.config.scale = legacyScale end
    end
  end

  profile.general.profileSchemaVersion = PROFILE_SCHEMA_VERSION
end

local function NotifyAllSettings()
  if ETBC.ApplyBus and ETBC.ApplyBus.NotifyAllNow then
    ETBC.ApplyBus:NotifyAllNow()
  elseif ETBC.ApplyBus and ETBC.ApplyBus.NotifyAll then
    ETBC.ApplyBus:NotifyAll()
  end
end

local function DeepCopy(src)
  if type(src) ~= "table" then return src end
  local dst = {}
  for k, v in pairs(src) do
    dst[k] = DeepCopy(v)
  end
  return dst
end

local function ReplaceTable(dst, src)
  if type(dst) ~= "table" or type(src) ~= "table" then return end
  wipe(dst)
  for k, v in pairs(src) do
    if type(v) == "table" then
      dst[k] = DeepCopy(v)
    else
      dst[k] = v
    end
  end
end

local function DeepEqual(a, b, seen)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  if a == b then return true end
  seen = seen or {}
  if seen[a] == b then return true end
  seen[a] = b
  for k, v in pairs(a) do
    if not DeepEqual(v, b[k], seen) then return false end
  end
  for k in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end

local function BuildImportPreview(self, payload, sender)
  local changed = {}
  local current = self and self.db and self.db.profile or {}
  local incoming = payload and payload.profile or {}
  for key, value in pairs(incoming) do
    if not DeepEqual(value, current[key]) then changed[#changed + 1] = tostring(key) end
  end
  for key in pairs(current) do
    if incoming[key] == nil then changed[#changed + 1] = tostring(key) end
  end
  table.sort(changed)
  local changeText = #changed > 0 and table.concat(changed, ", ") or "none"
  if #changeText > 220 then changeText = changeText:sub(1, 217) .. "..." end
  return ("Source: %s\nClient: %s\nInterface: %s\nChanged groups: %s"):format(
    tostring(sender or "local import"),
    tostring(payload and payload.client or "unknown"),
    tostring(payload and payload.interface or "unknown"),
    changeText
  )
end

local function SanitizeVisibilityProfile(v)
  if type(v) ~= "table" then return end
  if type(v.modulePresets) == "table" then
    v.modulePresets.gcdbar = nil
  end
  if type(v.modules) == "table" then
    v.modules.gcdbar = nil
  end
end

local function SanitizeProfileTable(profile)
  if type(profile) ~= "table" then return profile end

  for key in pairs(REMOVED_PROFILE_KEYS) do
    profile[key] = nil
  end

  SanitizeVisibilityProfile(profile.visibility)
  return profile
end

local function BuildProfilePayload(self)
  local profileCopy = DeepCopy(self.db.profile)
  SanitizeProfileTable(profileCopy)

  return {
    version = PROFILE_EXPORT_VERSION,
    addon = ADDON_NAME,
    interface = CURRENT_INTERFACE,
    client = "TBC Anniversary",
    profile = profileCopy,
    at = time and time() or 0,
  }
end

local function EncodePayload(payload)
  if not (AceSerializer and LibDeflate and payload) then return nil, "missing serializer/deflate" end
  local serialized = AceSerializer:Serialize(payload)
  local compressed = LibDeflate:CompressDeflate(serialized, { level = 5 })
  if not compressed then return nil, "compression failed" end
  local encoded = LibDeflate:EncodeForPrint(compressed)
  if not encoded then return nil, "encoding failed" end
  return encoded
end

local function DecodePayload(encoded)
  if type(encoded) ~= "string" or encoded == "" then return nil, "no data" end
  if not (AceSerializer and LibDeflate) then return nil, "missing serializer/deflate" end
  local compressed = LibDeflate:DecodeForPrint(encoded)
  if not compressed then return nil, "decode failed" end
  local serialized = LibDeflate:DecompressDeflate(compressed)
  if not serialized then return nil, "decompress failed" end
  local ok, payload = AceSerializer:Deserialize(serialized)
  if not ok or type(payload) ~= "table" then return nil, "deserialize failed" end
  return payload
end

local function PrintWrapped(self, text, lineLen)
  lineLen = tonumber(lineLen) or 220
  local str = tostring(text or "")
  local n = #str
  local idx = 1
  while idx <= n do
    self:Print(str:sub(idx, idx + lineLen - 1))
    idx = idx + lineLen
  end
end

local function ApplyImportedProfile(self, payload)
  if not (self and self.db and type(self.db.profile) == "table") then
    return false, "DB not ready"
  end
  if type(payload) ~= "table" or type(payload.profile) ~= "table" then
    return false, "invalid payload"
  end
  if payload.addon ~= nil and tostring(payload.addon) ~= ADDON_NAME then
    return false, "wrong addon payload"
  end
  if payload.version ~= nil then
    local v = tonumber(payload.version)
    if (not v) or v > PROFILE_EXPORT_VERSION then
      return false, "unsupported payload version"
    end
  end
  if payload.interface ~= nil then
    local iface = tonumber(payload.interface)
    if not iface or not COMPATIBLE_PROFILE_INTERFACES[iface] then
      return false, ("unsupported interface: %s"):format(tostring(payload.interface))
    end
  end

  local sanitizedProfile = DeepCopy(payload.profile)
  SanitizeProfileTable(sanitizedProfile)
  MigrateProfileSchema(sanitizedProfile)
  self.db.global = self.db.global or {}
  self.db.global.lastImportBackup = {
    profile = DeepCopy(self.db.profile),
    importedAt = time and time() or 0,
    sourceInterface = payload.interface,
  }
  ReplaceTable(self.db.profile, sanitizedProfile)
  NotifyAllSettings()
  return true
end

function ETBC:UndoLastProfileImport()
  local backup = self.db and self.db.global and self.db.global.lastImportBackup
  if not backup or type(backup.profile) ~= "table" then
    return false, "no import backup available"
  end
  ReplaceTable(self.db.profile, DeepCopy(backup.profile))
  self.db.global.lastImportBackup = nil
  NotifyAllSettings()
  return true
end

local function NormalizeKey(s)
  if type(s) ~= "string" then return "" end
  return s:lower():gsub("[^a-z0-9]", "")
end

local function ResolveProfileKey(self, moduleKey)
  if type(moduleKey) ~= "string" or moduleKey == "" then return nil end
  if not (self and self.db and type(self.db.profile) == "table") then return nil end

  if self.db.profile[moduleKey] ~= nil then
    return moduleKey
  end

  local target = NormalizeKey(moduleKey)
  if target == "" then return nil end

  for key in pairs(self.db.profile) do
    if type(key) == "string" and NormalizeKey(key) == target then
      return key
    end
  end

  return nil
end

function ETBC:ResolveProfileKey(moduleKey)
  return ResolveProfileKey(self, moduleKey)
end

local function MakeTimerHandle(token, cancelFn)
  local handle = {
    _token = token,
    _cancelFn = cancelFn,
    _cancelled = false,
  }

  function handle:Cancel()
    if self._cancelled then return end
    self._cancelled = true
    local fn = self._cancelFn
    local tok = self._token
    self._cancelFn = nil
    self._token = nil
    if fn and tok ~= nil then
      pcall(fn, tok)
    end
  end

  return handle
end

function ETBC:StartTimer(delay, fn)
  if type(fn) ~= "function" then return nil end
  delay = tonumber(delay) or 0
  if delay < 0 then delay = 0 end

  if self.ScheduleTimer and self.CancelTimer then
    local ok, token = pcall(self.ScheduleTimer, self, fn, delay)
    if ok and token ~= nil then
      return MakeTimerHandle(token, function(tok)
        if ETBC.CancelTimer then
          ETBC:CancelTimer(tok, true)
        end
      end)
    end
  end

  if C_Timer and C_Timer.NewTimer then
    local t = C_Timer.NewTimer(delay, fn)
    return MakeTimerHandle(t, function(tok)
      if tok and tok.Cancel then
        tok:Cancel()
      end
    end)
  end

  if C_Timer and C_Timer.After then
    local cancelled = false
    C_Timer.After(delay, function()
      if cancelled then return end
      fn()
    end)
    return {
      _cancelled = false,
      Cancel = function(self2)
        self2._cancelled = true
        cancelled = true
      end,
    }
  end

  fn()
  return { Cancel = function() end }
end

function ETBC:StartRepeatingTimer(interval, fn)
  if type(fn) ~= "function" then return nil end
  interval = tonumber(interval) or 0
  if interval < 0.01 then interval = 0.01 end

  if self.ScheduleRepeatingTimer and self.CancelTimer then
    local ok, token = pcall(self.ScheduleRepeatingTimer, self, fn, interval)
    if ok and token ~= nil then
      return MakeTimerHandle(token, function(tok)
        if ETBC.CancelTimer then
          ETBC:CancelTimer(tok, true)
        end
      end)
    end
  end

  if C_Timer and C_Timer.NewTicker then
    local t = C_Timer.NewTicker(interval, fn)
    return MakeTimerHandle(t, function(tok)
      if tok and tok.Cancel then
        tok:Cancel()
      end
    end)
  end

  return nil
end

function ETBC:ResetModuleProfile(moduleKey)
  if not (self and self.db and type(self.db.profile) == "table") then
    return false, "DB not ready"
  end
  if not (ETBC.defaults and type(ETBC.defaults.profile) == "table") then
    return false, "defaults missing"
  end

  local profileKey = ResolveProfileKey(self, moduleKey)
  if not profileKey then
    return false, "unknown module key"
  end

  local defaults = ETBC.defaults.profile[profileKey]
  -- Some modules own their defaults in GetDB() so they can migrate legacy
  -- values while initializing. Clearing those profiles and refreshing lets the
  -- owning module rebuild its canonical defaults instead of making the reset
  -- command fail merely because Core/Defaults.lua has no static entry.
  if defaults == nil then
    self.db.profile[profileKey] = {}
    self:RefreshAll("module-reset:" .. tostring(moduleKey))
    return true
  end

  if type(defaults) == "table" then
    self.db.profile[profileKey] = self.db.profile[profileKey] or {}
    ReplaceTable(self.db.profile[profileKey], defaults)
  else
    self.db.profile[profileKey] = DeepCopy(defaults)
  end

  self:RefreshAll("module-reset:" .. tostring(moduleKey))
  return true
end

function ETBC:GetDiagnostics()
  local version, build, buildDate, interface = GetBuildInfo()
  local addonVersion
  if C_AddOns and C_AddOns.GetAddOnMetadata then
    addonVersion = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
  end

  local enabledModules, knownModules = 0, 0
  local profile = self.db and self.db.profile or {}
  local global = self.db and self.db.global or {}
  for key, value in pairs(profile) do
    if key ~= "general" and type(value) == "table" and value.enabled ~= nil then
      knownModules = knownModules + 1
      if value.enabled then enabledModules = enabledModules + 1 end
    end
  end

  local platerLoaded = false
  if C_AddOns and C_AddOns.IsAddOnLoaded then
    platerLoaded = C_AddOns.IsAddOnLoaded("Plater") and true or false
  elseif IsAddOnLoaded then
    platerLoaded = IsAddOnLoaded("Plater") and true or false
  end

  local diagnostics = {
    addonVersion = addonVersion or "unknown",
    clientVersion = version or "unknown",
    clientBuild = build or "unknown",
    buildDate = buildDate or "unknown",
    interface = interface or CURRENT_INTERFACE,
    expectedInterface = CURRENT_INTERFACE,
    profileSchema = profile.general and profile.general.profileSchemaVersion or 0,
    expectedProfileSchema = PROFILE_SCHEMA_VERSION,
    enabledModules = enabledModules,
    knownModules = knownModules,
    masterEnabled = profile.general and profile.general.enabled ~= false,
    inCombat = InCombatLockdown and InCombatLockdown() and true or false,
    platerLoaded = platerLoaded,
    luaMemoryKB = collectgarbage and math.floor(collectgarbage("count") + 0.5) or nil,
    lastPreset = profile.general and profile.general.lastPreset or "none",
    canUndoPreset = global.lastPresetBackup and true or false,
    canUndoImport = global.lastImportBackup and true or false,
  }
  if self.GetPerformanceSnapshot then
    diagnostics.performance = self.GetPerformanceSnapshot()
  end
  return diagnostics
end

function ETBC:PrintDiagnostics()
  local d = self:GetDiagnostics()
  self:Print(("EnhanceTBC %s diagnostics"):format(tostring(d.addonVersion)))
  self:Print(("Client %s, build %s, interface %s (expected %s)"):format(
    tostring(d.clientVersion), tostring(d.clientBuild), tostring(d.interface), tostring(d.expectedInterface)
  ))
  self:Print(("Master: %s; modules: %d/%d enabled; combat lockdown: %s"):format(
    d.masterEnabled and "enabled" or "disabled",
    d.enabledModules, d.knownModules,
    d.inCombat and "yes" or "no"
  ))
  self:Print(("Plater: %s; Lua memory: %s KB"):format(
    d.platerLoaded and "loaded" or "not loaded",
    d.luaMemoryKB and tostring(d.luaMemoryKB) or "unavailable"
  ))
  self:Print(("Last preset: %s; undo preset: %s; undo import: %s"):format(
    tostring(d.lastPreset),
    d.canUndoPreset and "available" or "none",
    d.canUndoImport and "available" or "none"
  ))
  self:Print(("Profile schema: %s (expected %s)"):format(
    tostring(d.profileSchema), tostring(d.expectedProfileSchema)
  ))
  local perf = d.performance
  if perf and perf.available and perf.enabled then
    local metrics = perf.metrics or {}
    self:Print(("Performance: recent %.3f ms; session %.3f ms; peak %.3f ms%s"):format(
      tonumber(metrics.recentAverageMs) or 0,
      tonumber(metrics.sessionAverageMs) or 0,
      tonumber(metrics.peakMs) or 0,
      perf.warning and "; Blizzard warning active" or ""
    ))
  elseif perf then
    self:Print("Performance profiler: " .. tostring(perf.error or (perf.enabled and "unavailable" or "disabled")))
  end
end

function ETBC:RunSelfTest()
  local checks = {
    { "Database", self.db and self.db.profile ~= nil },
    { "Apply bus", ETBC.ApplyBus and type(ETBC.ApplyBus.Notify) == "function" },
    { "Settings registry", ETBC.SettingsRegistry and type(ETBC.SettingsRegistry.GetGroups) == "function" },
    { "C_NamePlate.GetNamePlates", C_NamePlate and type(C_NamePlate.GetNamePlates) == "function" },
    { "C_NamePlate.SetNamePlateSize", C_NamePlate and type(C_NamePlate.SetNamePlateSize) == "function" },
    { "C_AddOns.GetAddOnMetadata", C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" },
    { "C_Item.GetItemInfo", C_Item and type(C_Item.GetItemInfo) == "function" },
    { "C_UnitAuras.GetAuraDataByIndex", C_UnitAuras and type(C_UnitAuras.GetAuraDataByIndex) == "function" },
    { "Native chat timestamp CVar", type(GetCVar) == "function" and GetCVar("showTimestamps") ~= nil },
    { "Tooltip module", ETBC.Modules and ETBC.Modules.Tooltip ~= nil },
    { "Nameplate module", ETBC.Modules and ETBC.Modules.Nameplates ~= nil },
    { "C_AddOnProfiler", C_AddOnProfiler and type(C_AddOnProfiler.GetAddOnMetric) == "function" },
    { "EnhanceTBC public API v1", _G.EnhanceTBC_API and _G.EnhanceTBC_API.API_VERSION == 1 },
  }

  local passed = 0
  self:Print("EnhanceTBC build-68575 self-test:")
  for _, check in ipairs(checks) do
    if check[2] then
      passed = passed + 1
      self:Print("|cff66ff66PASS|r " .. check[1])
    else
      self:Print("|cffff6666FAIL|r " .. check[1])
    end
  end
  self:Print(("Self-test result: %d/%d checks passed."):format(passed, #checks))
  return passed == #checks, passed, #checks
end

local function PrintHelp(self)
  self:Print("Commands:")
  self:Print("/etbc, /etbc config - Open config")
  self:Print("/etbc reset - Reset full profile")
  self:Print("/etbc resetmodule <moduleKey> - Reset one module to defaults")
  self:Print("/etbc minimap - Toggle minimap icon")
  self:Print("/etbc moveall [on|off|toggle] - Toggle mover mode")
  self:Print("/etbc profile export")
  self:Print("/etbc profile import <data>")
  self:Print("/etbc profile undoimport")
  self:Print("/etbc profile share <player>")
  self:Print("/etbc listgossip")
  self:Print("/etbc addgossip <pattern>")
  self:Print("/etbc diagnose - Print client/addon diagnostics")
  self:Print("/etbc selftest - Check required client capabilities")
end

local function RegisterBlizzardOptions(self)
  if self._blizOptionsRegistered then return end

  if AceConfigDialog and AceConfigDialog.AddToBlizOptions then
    local ok, panel = pcall(AceConfigDialog.AddToBlizOptions, AceConfigDialog, ADDON_NAME, "EnhanceTBC")
    if ok and panel then
      self._blizOptionsRegistered = true
      self._blizOptionsPanel = panel
      return
    end
  end

  if InterfaceOptions_AddCategory and not blizPanel then
    blizPanel = CreateFrame("Frame", "EnhanceTBC_BlizzardOptionsPanel", UIParent)
    blizPanel.name = "EnhanceTBC"

    local title = blizPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("EnhanceTBC")

    local desc = blizPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Use the custom config window for full settings access.")

    local btn = CreateFrame("Button", nil, blizPanel, "UIPanelButtonTemplate")
    btn:SetSize(170, 24)
    btn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -14)
    btn:SetText("Open EnhanceTBC Config")
    btn:SetScript("OnClick", function()
      if self and self.OpenConfig then
        self:OpenConfig()
      end
    end)

    InterfaceOptions_AddCategory(blizPanel)
    self._blizOptionsPanel = blizPanel
  end

  self._blizOptionsRegistered = true
end

if not StaticPopupDialogs.ETBC_PROFILE_IMPORT_CONFIRM then
  StaticPopupDialogs.ETBC_PROFILE_IMPORT_CONFIRM = {
    text = "Import EnhanceTBC profile?\n\n%s",
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, data)
      if not data or not data.owner or not data.payload then return end
      local ok, err = ApplyImportedProfile(data.owner, data.payload)
      if ok then
        data.owner:Print("Imported profile from " .. tostring(data.sender or "unknown") .. ".")
      else
        data.owner:Print("Profile import failed: " .. tostring(err))
      end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
  }
end

local function ConfirmProfileImport(owner, payload, sender)
  StaticPopup_Show("ETBC_PROFILE_IMPORT_CONFIRM", BuildImportPreview(owner, payload, sender), nil, {
    owner = owner,
    payload = payload,
    sender = sender or "local import",
  })
end

if not StaticPopupDialogs.ETBC_FIRST_RUN_SETUP then
  StaticPopupDialogs.ETBC_FIRST_RUN_SETUP = {
    text = "Welcome to EnhanceTBC. Choose a starting layout. Every option remains editable in /etbc.",
    button1 = "Enhanced",
    button2 = "Classic",
    button3 = "Configure Later",
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 0,
    preferredIndex = 3,
    OnAccept = function(_, data)
      if data and data.owner and data.owner.Presets then
        data.owner.Presets:Apply("ENHANCED")
      end
    end,
    OnCancel = function(_, data)
      if data and data.owner and data.owner.Presets then
        data.owner.Presets:Apply("CLASSIC")
      end
    end,
    OnAlt = function(_, data)
      local general = data and data.owner and data.owner.db and data.owner.db.profile.general
      if general then general.setupCompleted = true end
    end,
  }
end

-- ---------------------------------------------------------
-- Config opening (single source of truth)
-- ---------------------------------------------------------
function ETBC:OpenConfig()
  local customWindowError
  -- Prefer our custom window if present
  if self.UI and self.UI.ConfigWindow then
    if self.UI.ConfigWindow.Open then
      local ok, err = pcall(self.UI.ConfigWindow.Open, self.UI.ConfigWindow)
      if ok then return end
      customWindowError = err
    end
    if self.UI.ConfigWindow.Toggle then
      local ok, err = pcall(self.UI.ConfigWindow.Toggle, self.UI.ConfigWindow)
      if ok then return end
      customWindowError = customWindowError or err
    end
  end

  -- Fallback to Blizzard options
  if AceConfigDialog and AceConfigDialog.Open then
    local ok = pcall(AceConfigDialog.Open, AceConfigDialog, ADDON_NAME)
    if ok then return end
  end

  if customWindowError and DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(
      "|cffff6666EnhanceTBC config error:|r " .. tostring(customWindowError)
    )
  end

  if InterfaceOptionsFrame_OpenToCategory and self._blizOptionsPanel then
    local ok = pcall(InterfaceOptionsFrame_OpenToCategory, self._blizOptionsPanel)
    if ok then
      pcall(InterfaceOptionsFrame_OpenToCategory, self._blizOptionsPanel)
      return
    end
  end

  if InterfaceOptionsFrame_OpenToCategory then
    pcall(InterfaceOptionsFrame_OpenToCategory, "EnhanceTBC")
    pcall(InterfaceOptionsFrame_OpenToCategory, "EnhanceTBC")
  end
end

-- ---------------------------------------------------------
-- Refresh helpers
-- ---------------------------------------------------------
local function GetModuleEnabledState(key)
  if not ETBC.db or not ETBC.db.profile then return nil end
  local mod = ETBC.db.profile[key]
  if type(mod) == "table" and mod.enabled ~= nil then
    return mod.enabled and true or false
  end
  return nil
end

function ETBC:RefreshAll(_reason)
  if not self.db or not self.db.profile then return end

  if self.Theme and self.Theme.RefreshCache then
    self.Theme:RefreshCache()
  end

  if self.InitMinimapIcon then
    self:InitMinimapIcon()
  end

  local keys = (self.ApplyBus and self.ApplyBus.Keys and self.ApplyBus:Keys()) or {}
  self._moduleEnabledSnapshot = self._moduleEnabledSnapshot or {}

  for i = 1, #keys do
    local key = keys[i]
    local enabled = GetModuleEnabledState(key)
    local shouldNotify = true

    if enabled ~= nil then
      local prev = self._moduleEnabledSnapshot[key]
      if enabled == false and prev == false then
        shouldNotify = false
      end
      self._moduleEnabledSnapshot[key] = enabled
    end

    if shouldNotify and self.ApplyBus and self.ApplyBus.Notify then
      self.ApplyBus:Notify(key)
    end
  end

end

function ETBC:OnProfileChanged()
  if self.PublicAPIInternal then self.PublicAPIInternal.OnProfileChanged("profile-changed") end
  self:RefreshAll("profile-changed")
end

function ETBC:OnProfileCopied()
  if self.PublicAPIInternal then self.PublicAPIInternal.OnProfileChanged("profile-copied") end
  self:RefreshAll("profile-copied")
end

function ETBC:OnProfileReset()
  if self.PublicAPIInternal then self.PublicAPIInternal.OnProfileChanged("profile-reset") end
  self:RefreshAll("profile-reset")
end

-- ---------------------------------------------------------
-- Slash
-- ---------------------------------------------------------
function ETBC:SlashCommand(input)
  local rawInput = input or ""
  input = rawInput:lower()

  local cmd, args = rawInput:match("^%s*(%S+)%s*(.-)%s*$")
  cmd = (cmd and cmd:lower()) or ""
  args = args or ""

  local function DoExportProfile()
    local payload = BuildProfilePayload(self)
    local encoded, err = EncodePayload(payload)
    if not encoded then
      self:Print("Export failed: " .. tostring(err))
      return
    end
    self:Print("Profile export start")
    PrintWrapped(self, encoded, 220)
    self:Print("Profile export end")
  end

  local function DoImportProfile(encoded)
    if not encoded or encoded == "" then
      self:Print("Usage: /etbc profile import <export-string>")
      return
    end
    local payload, err = DecodePayload(encoded)
    if not payload then
      self:Print("Import failed: " .. tostring(err))
      return
    end
    ConfirmProfileImport(self, payload, "local import")
  end

  local function DoShareProfile(target)
    if not target or target == "" then
      self:Print("Usage: /etbc profile share <player>")
      return
    end
    local payload = BuildProfilePayload(self)
    local encoded, err = EncodePayload(payload)
    if not encoded then
      self:Print("Share failed: " .. tostring(err))
      return
    end
    if self.SendCommMessage then
      self:SendCommMessage(PROFILE_COMM_PREFIX, encoded, "WHISPER", target, "BULK")
      self:Print("Shared profile with " .. tostring(target) .. ".")
    else
      self:Print("Share failed: comms unavailable.")
    end
  end

  if input == "" or input == "config" or input == "options" then
    self:OpenConfig()
    return
  end

  if input == "help" or input == "?" then
    PrintHelp(self)
    return
  end

  if input == "diagnose" or input == "diagnostics" then
    self:PrintDiagnostics()
    return
  end
  if input == "selftest" or input == "test" then
    self:RunSelfTest()
    return
  end

  if input == "reset" then
    if self.db and self.db.ResetProfile then
      self.db:ResetProfile()
    end
    self:RefreshAll("profile-reset")
    self:Print("Profile reset.")
    return
  end

  if input == "minimap" then
    if self.ToggleMinimapIcon then
      self:ToggleMinimapIcon()
      self:Print("Toggled minimap icon.")
    end
    return
  end

  if cmd == "resetmodule" then
    local key = args:match("^(%S+)")
    if not key or key == "" then
      self:Print("Usage: /etbc resetmodule <moduleKey>")
      return
    end
    local ok, err = self:ResetModuleProfile(key)
    if ok then
      self:Print("Reset module: " .. tostring(key))
    else
      self:Print("Module reset failed: " .. tostring(err))
    end
    return
  end

  if cmd == "profile" then
    local action, rest = args:match("^(%S+)%s*(.-)%s*$")
    action = (action and action:lower()) or ""
    rest = rest or ""

    if action == "" or action == "help" then
      self:Print("Profile commands:")
      self:Print("/etbc profile export")
      self:Print("/etbc profile import <data>")
      self:Print("/etbc profile undoimport")
      self:Print("/etbc profile share <player>")
      return
    end

    if action == "export" then
      DoExportProfile()
      return
    end
    if action == "import" then
      DoImportProfile(rest)
      return
    end
    if action == "undoimport" or action == "undo" then
      local ok, undoErr = self:UndoLastProfileImport()
      if ok then self:Print("Restored the profile from before the last import.")
      else self:Print("Undo import failed: " .. tostring(undoErr)) end
      return
    end
    if action == "share" then
      local target = rest:match("^(%S+)")
      DoShareProfile(target)
      return
    end

    self:Print("Unknown profile action. Use: export, import, undoimport, share")
    return
  end

  if input == "exportprofile" or input == "profileexport" then
    DoExportProfile()
    return
  end

  if input:match("^importprofile%s+") or input:match("^profileimport%s+") then
    local encoded = rawInput:match("^[Ii][Mm][Pp][Oo][Rr][Tt][Pp][Rr][Oo][Ff][Ii][Ll][Ee]%s+(.+)$")
      or rawInput:match("^[Pp][Rr][Oo][Ff][Ii][Ll][Ee][Ii][Mm][Pp][Oo][Rr][Tt]%s+(.+)$")
    if not encoded or encoded == "" then
      self:Print("Usage: /etbc importprofile <export-string>")
      return
    end
    DoImportProfile(encoded)
    return
  end

  if input:match("^shareprofile%s+") then
    local target = rawInput:match("^[Ss][Hh][Aa][Rr][Ee][Pp][Rr][Oo][Ff][Ii][Ll][Ee]%s+(%S+)")
    if not target or target == "" then
      self:Print("Usage: /etbc shareprofile <player>")
      return
    end
    DoShareProfile(target)
    return
  end

  if input:match("^moveall") then
    if not (ETBC.Mover and ETBC.Mover.SetMasterMove) then
      self:Print("Mover system not loaded.")
      return
    end

    local arg = rawInput:match("^%s*[Mm][Oo][Vv][Ee][Aa][Ll][Ll]%s+(%S+)")
    if not arg or arg == "" or arg:lower() == "toggle" then
      ETBC.Mover:ToggleMasterMove()
      return
    end

    arg = arg:lower()
    if arg == "on" or arg == "1" or arg == "enable" then
      ETBC.Mover:SetMasterMove(true)
      return
    end
    if arg == "off" or arg == "0" or arg == "disable" then
      ETBC.Mover:SetMasterMove(false)
      return
    end

    self:Print("Usage: /etbc moveall [on|off|toggle]")
    return
  end

  if input == "listgossip" or input == "gossiplist" then
    if ETBC.Modules and ETBC.Modules.AutoGossip and ETBC.Modules.AutoGossip.ListPatterns then
      ETBC.Modules.AutoGossip:ListPatterns()
    else
      self:Print("AutoGossip module not loaded.")
    end
    return
  end

  if input:match("^addgossip%s+(.+)") or input:match("^gossipadd%s+(.+)") then
    local pattern = rawInput:match("^[Aa][Dd][Dd][Gg][Oo][Ss][Ss][Ii][Pp]%s+(.+)")
      or rawInput:match("^[Gg][Oo][Ss][Ss][Ii][Pp][Aa][Dd][Dd]%s+(.+)")
    if ETBC.Modules and ETBC.Modules.AutoGossip and ETBC.Modules.AutoGossip.AddPattern then
      ETBC.Modules.AutoGossip:AddPattern(pattern)
    else
      self:Print("AutoGossip module not loaded.")
    end
    return
  end

  PrintHelp(self)
end

-- ---------------------------------------------------------
-- AceAddon lifecycle
-- ---------------------------------------------------------
function ETBC:OnInitialize()
  self.db = AceDB:New("EnhanceTBCDB", ETBC.defaults, true)
  MigrateProfileSchema(self.db.profile)

  if self.db.profile.general and self.db.profile.general.setupCompleted == nil then
    StaticPopup_Show("ETBC_FIRST_RUN_SETUP", nil, nil, { owner = self })
  end

  if self.RegisterComm then
    self:RegisterComm(PROFILE_COMM_PREFIX, "OnProfileCommReceived")
  end

  if self.db and self.db.RegisterCallback then
    self.db:RegisterCallback("OnProfileChanged", function() self:OnProfileChanged() end)
    self.db:RegisterCallback("OnProfileCopied", function() self:OnProfileCopied() end)
    self.db:RegisterCallback("OnProfileReset", function() self:OnProfileReset() end)
  end

  -- Build the root options AFTER DB exists
  local options = ETBC:BuildOptions()
  if type(options) ~= "table" then
    options = { type = "group", name = "EnhanceTBC", args = {} }
  end
  options.args = options.args or {}

  -- Profiles (inject before registration so every config surface sees it)
  if AceDBOptions and AceDBOptions.GetOptionsTable then
    local profiles = AceDBOptions:GetOptionsTable(self.db)
    if type(profiles) == "table" then
      options.args.profiles = profiles
      options.args.profiles.order = 999
      options.args.profiles.name = "Profiles"
    end
  end

  if AceConfig and AceConfig.RegisterOptionsTable then
    AceConfig:RegisterOptionsTable(ADDON_NAME, options)
  end

  RegisterBlizzardOptions(self)

  -- Slash commands
  self:RegisterChatCommand("etbc", "SlashCommand")
  self:RegisterChatCommand("enhancetbc", "SlashCommand")

  -- Minimap icon: init AFTER db exists
  if self.InitMinimapIcon then
    self:InitMinimapIcon()
  end

  if self.Debug then
    self:Debug("Initialized")
  end

  if self.PublicAPIInternal then
    self.PublicAPIInternal.MarkReady()
  end

end

function ETBC:OnEnable()
  self:RefreshAll("enable")
end

function ETBC:OnProfileCommReceived(prefix, message, distribution, sender)
  if prefix ~= PROFILE_COMM_PREFIX then return end
  if not message or message == "" then return end
  if not sender then sender = "unknown" end

  local payload, err = DecodePayload(message)
  if not payload then
    self:Print("Received invalid shared profile from " .. tostring(sender) .. ": " .. tostring(err))
    return
  end

  local shortSender = tostring(sender):match("^[^-]+") or tostring(sender)
  ConfirmProfileImport(self, payload, shortSender)
end

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
local blizPanel

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

local function BuildProfilePayload(self)
  return {
    version = PROFILE_EXPORT_VERSION,
    addon = ADDON_NAME,
    profile = DeepCopy(self.db.profile),
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
  ReplaceTable(self.db.profile, payload.profile)
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
  if defaults == nil then
    return false, "no defaults for module"
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

local function PrintHelp(self)
  self:Print("Commands:")
  self:Print("/etbc, /etbc config - Open config")
  self:Print("/etbc reset - Reset full profile")
  self:Print("/etbc resetmodule <moduleKey> - Reset one module to defaults")
  self:Print("/etbc minimap - Toggle minimap icon")
  self:Print("/etbc moveall [on|off|toggle] - Toggle mover mode")
  self:Print("/etbc profile export")
  self:Print("/etbc profile import <data>")
  self:Print("/etbc profile share <player>")
  self:Print("/etbc listgossip")
  self:Print("/etbc addgossip <pattern>")
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
    text = "Import shared EnhanceTBC profile from %s?",
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

-- ---------------------------------------------------------
-- Config opening (single source of truth)
-- ---------------------------------------------------------
function ETBC:OpenConfig()
  -- Prefer our custom window if present
  if self.UI and self.UI.ConfigWindow then
    if self.UI.ConfigWindow.Open then
      local ok = pcall(self.UI.ConfigWindow.Open, self.UI.ConfigWindow)
      if ok then return end
    end
    if self.UI.ConfigWindow.Toggle then
      local ok = pcall(self.UI.ConfigWindow.Toggle, self.UI.ConfigWindow)
      if ok then return end
    end
  end

  -- Fallback to Blizzard options
  if AceConfigDialog and AceConfigDialog.Open then
    local ok = pcall(AceConfigDialog.Open, AceConfigDialog, ADDON_NAME)
    if ok then return end
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
  self:RefreshAll("profile-changed")
end

function ETBC:OnProfileCopied()
  self:RefreshAll("profile-copied")
end

function ETBC:OnProfileReset()
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
    local ok, applyErr = ApplyImportedProfile(self, payload)
    if ok then
      self:Print("Profile imported.")
    else
      self:Print("Import failed: " .. tostring(applyErr))
    end
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
    if action == "share" then
      local target = rest:match("^(%S+)")
      DoShareProfile(target)
      return
    end

    self:Print("Unknown profile action. Use: export, import, share")
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

  if self.RegisterComm then
    self:RegisterComm(PROFILE_COMM_PREFIX, "OnProfileCommReceived")
  end

  if self.db and self.db.RegisterCallback then
    self.db.RegisterCallback(self.db, self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self.db, self, "OnProfileCopied", "OnProfileCopied")
    self.db.RegisterCallback(self.db, self, "OnProfileReset", "OnProfileReset")
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
  StaticPopup_Show("ETBC_PROFILE_IMPORT_CONFIRM", shortSender, nil, {
    owner = self,
    payload = payload,
    sender = shortSender,
    distribution = distribution,
  })
end

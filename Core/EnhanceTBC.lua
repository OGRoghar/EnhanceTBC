-- Core/EnhanceTBC.lua
local ADDON_NAME, ETBC = ...
local AceAddon = LibStub("AceAddon-3.0")
local AceDB = LibStub("AceDB-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")

ETBC = AceAddon:NewAddon(ETBC, ADDON_NAME, "AceEvent-3.0", "AceConsole-3.0", "AceHook-3.0", "AceTimer-3.0")
_G.EnhanceTBC = ETBC
_G.ETBC = ETBC

-- ---------------------------------------------------------
-- Config opening (single source of truth)
-- ---------------------------------------------------------
function ETBC:OpenConfig()
  -- Prefer our custom window if present
  if self.UI and self.UI.ConfigWindow and self.UI.ConfigWindow.Toggle then
    self.UI.ConfigWindow:Toggle()
    return
  end

  -- Fallback to Blizzard options
  if AceConfigDialog and AceConfigDialog.Open then
    -- This opens AceConfigDialog's own window, not embedded.
    -- Safe fallback if our custom UI isn't loaded yet.
    AceConfigDialog:Open(ADDON_NAME)
    return
  end

  -- Ultimate fallback
  if InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory("EnhanceTBC")
    InterfaceOptionsFrame_OpenToCategory("EnhanceTBC")
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

  if input == "" or input == "config" or input == "options" then
    self:OpenConfig()
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

  self:Print(
    "Commands: /etbc (open), /etbc reset, /etbc minimap, /etbc moveall [on|off|toggle], "
      .. "/etbc listgossip (list auto-gossip), /etbc addgossip <pattern> (add auto-gossip)"
  )
end

-- ---------------------------------------------------------
-- AceAddon lifecycle
-- ---------------------------------------------------------
function ETBC:OnInitialize()
  self.db = AceDB:New("EnhanceTBCDB", ETBC.defaults, true)

  if self.db and self.db.RegisterCallback then
    self.db:RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db:RegisterCallback(self, "OnProfileCopied", "OnProfileCopied")
    self.db:RegisterCallback(self, "OnProfileReset", "OnProfileReset")
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

  -- Blizzard Interface Options
  if AceConfigDialog and AceConfigDialog.AddToBlizOptions then
    AceConfigDialog:AddToBlizOptions(ADDON_NAME, "EnhanceTBC")
  end

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

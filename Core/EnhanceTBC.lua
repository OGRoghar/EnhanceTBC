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
-- Slash
-- ---------------------------------------------------------
function ETBC:SlashCommand(input)
  input = (input or ""):lower()

  if input == "" or input == "config" or input == "options" then
    self:OpenConfig()
    return
  end

  if input == "reset" then
    if self.db and self.db.ResetProfile then
      self.db:ResetProfile()
    end
    if ETBC.ApplyBus and ETBC.ApplyBus.NotifyAll then
      ETBC.ApplyBus:NotifyAll()
    end
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

  self:Print("Commands: /etbc (open), /etbc reset, /etbc minimap")
end

-- ---------------------------------------------------------
-- AceAddon lifecycle
-- ---------------------------------------------------------
function ETBC:OnInitialize()
  self.db = AceDB:New("EnhanceTBCDB", ETBC.defaults, true)

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
  if ETBC.ApplyBus and ETBC.ApplyBus.NotifyAll then
    ETBC.ApplyBus:NotifyAll()
  end
end

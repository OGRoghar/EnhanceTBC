-- Core/EnhanceTBC.lua
local ADDON_NAME, ETBC = ...

local AceAddon = LibStub("AceAddon-3.0")
local AceDB = LibStub("AceDB-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")

ETBC = AceAddon:NewAddon(ETBC, ADDON_NAME, "AceEvent-3.0", "AceConsole-3.0", "AceHook-3.0", "AceTimer-3.0")

function ETBC:OnInitialize()
  self.db = AceDB:New("EnhanceTBCDB", ETBC.defaults, true)

  -- Root options AFTER DB exists
  local options = ETBC:BuildOptions()
  AceConfig:RegisterOptionsTable(ADDON_NAME, options)

  -- Profiles (AceDBOptions)
  local profiles = AceDBOptions:GetOptionsTable(self.db)
  options.args.profiles = profiles
  options.args.profiles.order = 999
  options.args.profiles.name = "Profiles"

  -- Blizzard Options category (nice to keep)
  AceConfigDialog:AddToBlizOptions(ADDON_NAME, "EnhanceTBC")

  -- Slash commands
  self:RegisterChatCommand("etbc", "SlashCommand")
  self:RegisterChatCommand("enhancetbc", "SlashCommand")

  -- Minimap icon (safe to call AFTER db exists)
  if self.InitMinimapIcon then
    self:InitMinimapIcon()
  end

  self:Debug("Initialized")
end

function ETBC:OnEnable()
  if ETBC.ApplyBus and ETBC.ApplyBus.NotifyAll then
    ETBC.ApplyBus:NotifyAll()
  end
end

function ETBC:OpenConfig()
  -- Always prefer the stable UI.ConfigWindow wrapper
  if ETBC.UI and ETBC.UI.ConfigWindow and ETBC.UI.ConfigWindow.Toggle then
    ETBC.UI.ConfigWindow:Toggle()
    return
  end

  -- Fallback: AceConfigDialog direct
  if AceConfigDialog then
    AceConfigDialog:Open(ADDON_NAME)
    return
  end

  -- Last fallback: Blizzard options
  InterfaceOptionsFrame_OpenToCategory("EnhanceTBC")
  InterfaceOptionsFrame_OpenToCategory("EnhanceTBC")
end

function ETBC:SlashCommand(input)
  input = (input or ""):lower()
  if input == "config" or input == "" then
    self:OpenConfig()
    return
  end

  if input == "reset" then
    self.db:ResetProfile()
    if ETBC.ApplyBus and ETBC.ApplyBus.NotifyAll then
      ETBC.ApplyBus:NotifyAll()
    end
    self:Print("Profile reset.")
    return
  end

  self:Print("Commands: /etbc (open), /etbc reset")
end

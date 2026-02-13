-- UI/ConfigWindow.lua
-- EnhanceTBC - Config window (STABLE)
-- Uses AceConfigDialog to render the SettingsRegistry-backed options tree.

local ADDON_NAME, ETBC = ...

ETBC.UI = ETBC.UI or {}
local UI = ETBC.UI

local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
if not AceConfigDialog then return end

UI.ConfigWindow = UI.ConfigWindow or {}
local ConfigWindow = UI.ConfigWindow

local OPEN_KEY = ADDON_NAME -- must match AceConfig:RegisterOptionsTable name

-- Optional: make the window larger (TBC-safe guards)
local function TrySizeDialog()
  local dlg = AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[OPEN_KEY]
  if not dlg or not dlg.frame then return end

  local f = dlg.frame

  if f.SetMinResize then
    f:SetMinResize(900, 650)
  end

  f:SetWidth(980)
  f:SetHeight(720)

  if f.SetClampedToScreen then
    f:SetClampedToScreen(true)
  end
end

function ConfigWindow:Open()
  AceConfigDialog:Open(OPEN_KEY)

  if C_Timer and C_Timer.After then
    C_Timer.After(0, TrySizeDialog)
  else
    TrySizeDialog()
  end
end

function ConfigWindow:Close()
  if AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[OPEN_KEY] then
    AceConfigDialog:Close(OPEN_KEY)
  end
end

function ConfigWindow:Toggle()
  if AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[OPEN_KEY] then
    self:Close()
  else
    self:Open()
  end
end

-- Hard fallback /etbc in case Core slash wiring gets broken by load order.
local function InstallSlashFallback()
  if ETBC._configSlashFallbackInstalled then return end
  ETBC._configSlashFallbackInstalled = true

  SLASH_ENHANCETBC1 = "/etbc"
  SlashCmdList.ENHANCETBC = function(msg)
    msg = tostring(msg or ""):lower()
    if msg == "" or msg == "config" or msg == "options" then
      ConfigWindow:Toggle()
      return
    end
    if msg == "show" then ConfigWindow:Open(); return end
    if msg == "hide" then ConfigWindow:Close(); return end
    print("|cff33ff99EnhanceTBC|r commands: /etbc, /etbc show, /etbc hide")
  end
end

InstallSlashFallback()

-- Modules/ActionBars.lua
-- EnhanceTBC - Actionbar Micro Tweaks (Blizzard bars)
-- Lightweight: mostly layout + text toggles + event-driven alpha.

local ADDON_NAME, ETBC = ...

ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.ActionBars = mod

local driver
local hooked = false

local function GetDB()
  ETBC.db.profile.actionbars = ETBC.db.profile.actionbars or {}
  return ETBC.db.profile.actionbars
end

local function EnsureDriver()
  if driver then return end
  driver = CreateFrame("Frame", "EnhanceTBC_ActionBarsDriver", UIParent)
end

local function LSM_Fetch(kind, key, fallback)
  if ETBC.LSM and ETBC.LSM.Fetch then
    local ok, v = pcall(ETBC.LSM.Fetch, ETBC.LSM, kind, key)
    if ok and v then return v end
  end
  return fallback
end

local function InCombat()
  if InCombatLockdown and InCombatLockdown() then return true end
  if UnitAffectingCombat then return UnitAffectingCombat("player") and true or false end
  return false
end

local function IsActionButton(btn)
  if not btn or not btn.GetName then return false end
  local name = btn:GetName()
  if not name then return false end
  -- Covers ActionButton1-12, MultiBarBottomLeftButton1-12, etc.
  return name:find("Button%d+$") ~= nil
end

local function GetAllButtonsFromBar(bar)
  if not bar or not bar.GetChildren then return {} end
  local out = {}
  local kids = { bar:GetChildren() }
  for i = 1, #kids do
    local c = kids[i]
    if IsActionButton(c) then
      out[#out + 1] = c
    end
  end
  table.sort(out, function(a, b)
    return (a:GetName() or "") < (b:GetName() or "")
  end)
  return out
end

local function StyleHotkey(btn)
  local db = GetDB()
  if not btn then return end

  local hk = btn.HotKey or _G[(btn:GetName() or "") .. "HotKey"]
  if hk and hk.SetFont then
    local fontPath = LSM_Fetch("font", db.hotkeyFont, "Fonts\\FRIZQT__.TTF")
    hk:SetFont(fontPath, tonumber(db.hotkeyFontSize) or 11, db.hotkeyOutline or "OUTLINE")
    if db.hotkeyShadow then
      hk:SetShadowOffset(1, -1)
      hk:SetShadowColor(0, 0, 0, 0.85)
    else
      hk:SetShadowOffset(0, 0)
    end
    if db.hideHotkeys then
      hk:SetAlpha(0)
    else
      hk:SetAlpha(1)
    end
  end

  local mt = btn.Name or _G[(btn:GetName() or "") .. "Name"]
  if mt and mt.SetAlpha then
    if db.hideMacroText then mt:SetAlpha(0) else mt:SetAlpha(1) end
  end
end

local function LayoutBar(bar, mode)
  local db = GetDB()
  if not bar then return end

  local btns = GetAllButtonsFromBar(bar)
  if #btns == 0 then return end

  local size = tonumber(db.buttonSize) or 36
  local spacing = tonumber(db.buttonSpacing) or 4

  for i = 1, #btns do
    local b = btns[i]
    b:SetSize(size, size)
    StyleHotkey(b)
  end

  -- Re-anchor in a simple row based on existing first button anchor.
  -- We store original anchor once, then rebuild row.
  local first = btns[1]
  if not first then return end

  if not bar._etbcOrigAnchorStored then
    bar._etbcOrigAnchorStored = true
    bar._etbcOrigAnchor = { first:GetPoint(1) } -- point, rel, relPoint, x, y
  end

  local p = bar._etbcOrigAnchor
  first:ClearAllPoints()
  if p and p[1] then
    first:SetPoint(p[1], p[2], p[3], p[4], p[5])
  else
    first:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 60)
  end

  for i = 2, #btns do
    local b = btns[i]
    b:ClearAllPoints()
    b:SetPoint("LEFT", btns[i - 1], "RIGHT", spacing, 0)
  end

  -- Update bar size (best effort)
  local w = (#btns * size) + ((#btns - 1) * spacing)
  bar:SetWidth(w)
  bar:SetHeight(size)
end

local function GetBars()
  local db = GetDB()
  local bars = {}

  if db.mainBar and _G.MainMenuBar then
    bars[#bars + 1] = _G.MainMenuBar
  end

  if db.multiBars then
    if _G.MultiBarBottomLeft then bars[#bars + 1] = _G.MultiBarBottomLeft end
    if _G.MultiBarBottomRight then bars[#bars + 1] = _G.MultiBarBottomRight end
    if _G.MultiBarRight then bars[#bars + 1] = _G.MultiBarRight end
    if _G.MultiBarLeft then bars[#bars + 1] = _G.MultiBarLeft end
  end

  if db.petBar and _G.PetActionBarFrame then
    bars[#bars + 1] = _G.PetActionBarFrame
  end

  if db.stanceBar and _G.StanceBarFrame then
    bars[#bars + 1] = _G.StanceBarFrame
  end

  return bars
end

local function ApplyAlpha()
  local db = GetDB()
  if not (db.enabled and db.fadeOOC) then
    -- restore to 1
    for _, bar in ipairs(GetBars()) do
      if bar and bar.SetAlpha then bar:SetAlpha(1) end
    end
    return
  end

  local a = InCombat() and (db.combatAlpha or 1.0) or (db.oocAlpha or 0.45)
  for _, bar in ipairs(GetBars()) do
    if bar and bar.SetAlpha then bar:SetAlpha(a) end
  end
end

local function HookEvents()
  if hooked then return end
  hooked = true

  EnsureDriver()
  driver:UnregisterAllEvents()
  driver:RegisterEvent("PLAYER_ENTERING_WORLD")
  driver:RegisterEvent("PLAYER_REGEN_DISABLED")
  driver:RegisterEvent("PLAYER_REGEN_ENABLED")
  driver:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
  driver:RegisterEvent("UPDATE_BINDINGS")

  driver:SetScript("OnEvent", function(_, event)
    local db = GetDB()
    if not (ETBC.db.profile.general and ETBC.db.profile.general.enabled and db.enabled) then
      return
    end

    if event == "PLAYER_ENTERING_WORLD" then
      ETBC.ApplyBus:Notify("actionbars")
      return
    end

    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
      ApplyAlpha()
      return
    end

    if event == "ACTIONBAR_SLOT_CHANGED" or event == "UPDATE_BINDINGS" then
      -- Refresh text style only, no heavy layout.
      for _, bar in ipairs(GetBars()) do
        local btns = GetAllButtonsFromBar(bar)
        for i = 1, #btns do
          StyleHotkey(btns[i])
        end
      end
      return
    end
  end)
end

local function Apply()
  EnsureDriver()
  HookEvents()

  local db = GetDB()
  local generalEnabled = ETBC.db.profile.general and ETBC.db.profile.general.enabled
  if not (generalEnabled and db.enabled) then
    -- soft disable: restore alpha, show texts
    for _, bar in ipairs(GetBars()) do
      if bar and bar.SetAlpha then bar:SetAlpha(1) end
      local btns = GetAllButtonsFromBar(bar)
      for i = 1, #btns do
        local b = btns[i]
        local hk = b.HotKey or _G[(b:GetName() or "") .. "HotKey"]
        if hk and hk.SetAlpha then hk:SetAlpha(1) end
        local mt = b.Name or _G[(b:GetName() or "") .. "Name"]
        if mt and mt.SetAlpha then mt:SetAlpha(1) end
      end
    end
    return
  end

  -- Layout + style
  for _, bar in ipairs(GetBars()) do
    LayoutBar(bar)
  end

  ApplyAlpha()
end

ETBC.ApplyBus:Register("actionbars", Apply)
ETBC.ApplyBus:Register("general", Apply)

-- Modules/Castbar/Layout.lua
-- EnhanceTBC - Castbar text/icon layout helpers (internal).

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}

local mod = ETBC.Modules.Castbar
if not mod then return end

mod.Internal = mod.Internal or {}
local H = {}
mod.Internal.Layout = H

local unpackFn = unpack or table.unpack

local function GetShared()
  return mod.Internal and mod.Internal.Shared
end

local function GetSkinInternal()
  return mod.Internal and mod.Internal.Skin
end

local function CallGetDB()
  local shared = GetShared()
  if shared and type(shared.GetDB) == "function" then
    return shared.GetDB()
  end
  return nil
end

local function StyleFontString(fs)
  local shared = GetShared()
  if shared and type(shared.StyleFontString) == "function" then
    shared.StyleFontString(fs)
  end
end

local function RestorePoints(frame, points)
  local shared = GetShared()
  if shared and type(shared.RestorePoints) == "function" then
    shared.RestorePoints(frame, points)
  end
end

local function EnsureSkin(bar)
  local skinH = GetSkinInternal()
  if skinH and type(skinH.EnsureSkin) == "function" then
    return skinH.EnsureSkin(bar)
  end
  return nil
end

local function IsPrimaryPlayerCastbar(bar)
  local skinH = GetSkinInternal()
  if skinH and type(skinH.IsPrimaryPlayerCastbar) == "function" then
    return skinH.IsPrimaryPlayerCastbar(bar)
  end
  return bar == _G.PlayerCastingBarFrame or bar == _G.CastingBarFrame
end

local function C(name, fallback)
  local shared = GetShared()
  if shared and shared[name] ~= nil then return shared[name] end
  return fallback
end

local function EnsureText(bar)
  if not bar then return nil end
  if bar._etbcTimeText and bar._etbcTimeText.SetText then return bar._etbcTimeText end

  local fs = bar:CreateFontString(nil, "OVERLAY")
  fs:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
  fs:SetJustifyH("RIGHT")
  fs:SetJustifyV("MIDDLE")

  -- SetFont BEFORE SetText
  bar._etbcTimeText = fs
  StyleFontString(fs)
  fs:SetText("")
  fs:Hide()
  return fs
end

local function RestoreTextLayout(bar)
  if not bar then return end
  local skin = EnsureSkin(bar)
  if not skin then return end

  if bar.Text and skin.textPoints then
    RestorePoints(bar.Text, skin.textPoints)
    if skin.textJustifyH and bar.Text.SetJustifyH then
      bar.Text:SetJustifyH(skin.textJustifyH)
    end
    if skin.textJustifyV and bar.Text.SetJustifyV then
      bar.Text:SetJustifyV(skin.textJustifyV)
    end
    if skin.textWordWrap ~= nil and bar.Text.SetWordWrap then
      bar.Text:SetWordWrap(skin.textWordWrap and true or false)
    end
  end
end

local function ApplyTextLayout(bar, active)
  if not bar then return end
  EnsureSkin(bar)

  if not active then
    RestoreTextLayout(bar)
    if bar._etbcTimeText then
      bar._etbcTimeText:SetText("")
      bar._etbcTimeText:Hide()
    end
    return
  end

  if not bar.Text then return end

  local db = CallGetDB()
  if not db then return end

  local NAME_TEXT_LEFT_PAD = tonumber(C("NAME_TEXT_LEFT_PAD", 6)) or 6
  local NAME_TEXT_RIGHT_PAD = tonumber(C("NAME_TEXT_RIGHT_PAD", 6)) or 6
  local TIMER_TEXT_WIDTH = tonumber(C("TIMER_TEXT_WIDTH", 52)) or 52
  local TIMER_TEXT_RIGHT_PAD = tonumber(C("TIMER_TEXT_RIGHT_PAD", 4)) or 4

  local fs = EnsureText(bar)
  local reserve = db.showTime and (TIMER_TEXT_WIDTH + TIMER_TEXT_RIGHT_PAD + NAME_TEXT_RIGHT_PAD) or NAME_TEXT_RIGHT_PAD

  bar.Text:ClearAllPoints()
  bar.Text:SetPoint("TOPLEFT", bar, "TOPLEFT", NAME_TEXT_LEFT_PAD, 0)
  bar.Text:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -reserve, 0)
  if bar.Text.SetJustifyH then bar.Text:SetJustifyH("CENTER") end
  if bar.Text.SetJustifyV then bar.Text:SetJustifyV("MIDDLE") end
  if bar.Text.SetWordWrap then bar.Text:SetWordWrap(false) end

  if fs then
    fs:ClearAllPoints()
    fs:SetPoint("RIGHT", bar, "RIGHT", -TIMER_TEXT_RIGHT_PAD, 0)
    fs:SetWidth(TIMER_TEXT_WIDTH)
    fs:SetJustifyH("RIGHT")
    fs:SetJustifyV("MIDDLE")
  end
end

local function RestoreIconLayout(bar)
  if not bar then return end
  local skin = EnsureSkin(bar)
  if not (skin and bar.Icon) then return end

  bar._etbcShowIconBackdrop = false
  if skin.iconBackdrop then skin.iconBackdrop:Hide() end
  if skin.iconPoints then
    RestorePoints(bar.Icon, skin.iconPoints)
  end
  if skin.iconTexCoord and bar.Icon.SetTexCoord then
    bar.Icon:SetTexCoord(unpackFn(skin.iconTexCoord))
  end
  if IsPrimaryPlayerCastbar(bar) then
    if skin.iconShown then
      bar.Icon:Show()
    else
      bar.Icon:Hide()
    end
  end
end

local function ApplyIconLayout(bar, active)
  if not bar or not bar.Icon then return end
  local skin = EnsureSkin(bar)
  if not skin then return end
  local db = CallGetDB()
  if not db then return end

  if not active then
    RestoreIconLayout(bar)
    return
  end

  if IsPrimaryPlayerCastbar(bar) then
    bar.Icon:ClearAllPoints()
    bar.Icon:SetPoint("RIGHT", bar, "LEFT", -3, 0)
    bar.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    bar.Icon:Show()
    bar._etbcShowIconBackdrop = true
  else
    bar._etbcShowIconBackdrop = bar.Icon.IsShown and bar.Icon:IsShown() or false
  end

  if skin.iconBackdrop then
    if db.skin and bar._etbcShowIconBackdrop then
      skin.iconBackdrop:Show()
    else
      skin.iconBackdrop:Hide()
    end
  end
end

H.EnsureText = EnsureText
H.ApplyTextLayout = ApplyTextLayout
H.ApplyIconLayout = ApplyIconLayout

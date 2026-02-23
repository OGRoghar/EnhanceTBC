-- Modules/Castbar/Skin.lua
-- EnhanceTBC - Castbar skin/backdrop helpers (internal).

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}

local mod = ETBC.Modules.Castbar
if not mod then return end

mod.Internal = mod.Internal or {}
local H = {}
mod.Internal.Skin = H

local function GetShared()
  return mod.Internal and mod.Internal.Shared
end

local function CallGetDB()
  local shared = GetShared()
  if shared and type(shared.GetDB) == "function" then
    return shared.GetDB()
  end
  return nil
end

local function SnapshotPoints(frame)
  local shared = GetShared()
  if shared and type(shared.SnapshotPoints) == "function" then
    return shared.SnapshotPoints(frame)
  end
  return nil
end

local function ApplyIconBackdrop(frame)
  local shared = GetShared()
  if shared and type(shared.ApplyIconBackdrop) == "function" then
    shared.ApplyIconBackdrop(frame)
  end
end

local function ApplyBackdropAlt(frame)
  local shared = GetShared()
  if shared and type(shared.ApplyBackdropAlt) == "function" then
    shared.ApplyBackdropAlt(frame)
  end
end

local function ApplySkinBackdropColors(bar, skin, db)
  if not (bar and skin and skin.backdrop) then return end
  if not (skin.backdrop.SetBackdropColor and skin.backdrop.SetBackdropBorderColor) then return end

  local sr, sg, sb = 0.25, 0.62, 1.0
  if bar.GetStatusBarColor then
    local r, g, b = bar:GetStatusBarColor()
    if r and g and b then
      sr, sg, sb = r, g, b
    end
  end

  local bgAlpha = tonumber(db and db.backgroundAlpha) or 0.35
  if bgAlpha < 0 then bgAlpha = 0 elseif bgAlpha > 0.8 then bgAlpha = 0.8 end
  local borderAlpha = tonumber(db and db.borderAlpha) or 0.95
  if borderAlpha < 0 then borderAlpha = 0 elseif borderAlpha > 1 then borderAlpha = 1 end

  local bgR = math.min(1, (sr * 0.35) + 0.10)
  local bgG = math.min(1, (sg * 0.35) + 0.10)
  local bgB = math.min(1, (sb * 0.35) + 0.10)
  local brR = math.min(1, (sr * 0.55) + 0.30)
  local brG = math.min(1, (sg * 0.55) + 0.30)
  local brB = math.min(1, (sb * 0.55) + 0.30)

  skin.backdrop:SetBackdropColor(bgR, bgG, bgB, bgAlpha)
  skin.backdrop:SetBackdropBorderColor(brR, brG, brB, borderAlpha)
end

local function IsPrimaryPlayerCastbar(bar)
  return bar == _G.PlayerCastingBarFrame or bar == _G.CastingBarFrame
end

local function IsPlayerCastbarFamily(bar)
  return IsPrimaryPlayerCastbar(bar) or bar == _G.PetCastingBarFrame
end

local function EnsureSkin(bar)
  if not bar then return nil end
  if bar._etbcSkin then return bar._etbcSkin end

  local skin = {}
  bar._etbcSkin = skin

  skin.regionState = {
    border = bar.Border and bar.Border.IsShown and bar.Border:IsShown() or false,
    borderShield = bar.BorderShield and bar.BorderShield.IsShown and bar.BorderShield:IsShown() or false,
    flash = bar.Flash and bar.Flash.IsShown and bar.Flash:IsShown() or false,
    spark = bar.Spark and bar.Spark.IsShown and bar.Spark:IsShown() or false,
  }

  if bar.Text then
    skin.textPoints = SnapshotPoints(bar.Text)
    if bar.Text.GetJustifyH then skin.textJustifyH = bar.Text:GetJustifyH() end
    if bar.Text.GetJustifyV then skin.textJustifyV = bar.Text:GetJustifyV() end
    if bar.Text.GetWordWrap then skin.textWordWrap = bar.Text:GetWordWrap() end
  end

  if bar.Icon then
    skin.iconPoints = SnapshotPoints(bar.Icon)
    skin.iconShown = bar.Icon.IsShown and bar.Icon:IsShown() or false
    if bar.Icon.GetTexCoord then
      local l, r, t, b = bar.Icon:GetTexCoord()
      skin.iconTexCoord = { l, r, t, b }
    end
  end

  if IsPrimaryPlayerCastbar(bar) then
    skin.playerFramePoints = SnapshotPoints(bar)
  end

  skin.backdrop = CreateFrame("Frame", nil, bar, "BackdropTemplate")
  skin.backdrop:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -1, -1)
  skin.backdrop:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 1, 1)
  ApplyBackdropAlt(skin.backdrop)
  skin.backdrop:Hide()

  if bar.Icon then
    skin.iconBackdropHolder = CreateFrame("Frame", nil, bar)
    skin.iconBackdropHolder:SetPoint("BOTTOMLEFT", bar.Icon, 0, 0)
    skin.iconBackdropHolder:SetPoint("TOPRIGHT", bar.Icon, 0, 0)

    skin.iconBackdrop = CreateFrame("Frame", nil, skin.iconBackdropHolder, "BackdropTemplate")
    skin.iconBackdrop:SetPoint("BOTTOMLEFT", skin.iconBackdropHolder, "BOTTOMLEFT", -1, -1)
    skin.iconBackdrop:SetPoint("TOPRIGHT", skin.iconBackdropHolder, "TOPRIGHT", 1, 1)
    ApplyIconBackdrop(skin.iconBackdrop)
    skin.iconBackdrop:Hide()

    bar.Icon:HookScript("OnShow", function()
      if not skin.iconBackdrop then return end
      if bar._etbcShowIconBackdrop then
        skin.iconBackdrop:Show()
      else
        skin.iconBackdrop:Hide()
      end
    end)

    bar.Icon:HookScript("OnHide", function()
      if skin.iconBackdrop then skin.iconBackdrop:Hide() end
    end)
  end

  return skin
end

local function RestoreSkin(bar, skin)
  if not (bar and skin) then return end
  bar._etbcShowIconBackdrop = false
  if skin.backdrop then skin.backdrop:Hide() end
  if skin.iconBackdrop then skin.iconBackdrop:Hide() end

  if bar.Border and bar.Border.Show and skin.regionState.border then bar.Border:Show() end
  if bar.Border and bar.Border.Hide and not skin.regionState.border then bar.Border:Hide() end
  if bar.BorderShield and bar.BorderShield.Show and skin.regionState.borderShield then bar.BorderShield:Show() end
  if bar.BorderShield and bar.BorderShield.Hide and not skin.regionState.borderShield then bar.BorderShield:Hide() end
  if bar.Flash and bar.Flash.Show and skin.regionState.flash then bar.Flash:Show() end
  if bar.Flash and bar.Flash.Hide and not skin.regionState.flash then bar.Flash:Hide() end
  if bar.Spark and bar.Spark.Show and skin.regionState.spark then bar.Spark:Show() end
  if bar.Spark and bar.Spark.Hide and not skin.regionState.spark then bar.Spark:Hide() end
end

local function ApplySkin(bar, active)
  local db = CallGetDB()
  if not (bar and db) then return end

  EnsureSkin(bar)
  local skin = bar._etbcSkin
  if not skin then return end

  if not (active and db.enabled and db.skin) then
    RestoreSkin(bar, skin)
    return
  end

  if skin.backdrop then skin.backdrop:Show() end
  ApplySkinBackdropColors(bar, skin, db)

  if bar.Spark then
    bar.Spark:SetDrawLayer("OVERLAY", 1)
    bar.Spark:Hide()
  end

  if bar.Border then bar.Border:Hide() end
  if bar.BorderShield then bar.BorderShield:SetTexture(nil) end
  if bar.Flash then
    bar.Flash:SetTexture(nil)
    bar.Flash:Hide()
  end

  if skin.iconBackdrop and bar._etbcShowIconBackdrop and bar.Icon and bar.Icon.IsShown and bar.Icon:IsShown() then
    skin.iconBackdrop:Show()
  elseif skin.iconBackdrop then
    skin.iconBackdrop:Hide()
  end
end

H.ApplySkinBackdropColors = ApplySkinBackdropColors
H.IsPrimaryPlayerCastbar = IsPrimaryPlayerCastbar
H.IsPlayerCastbarFamily = IsPlayerCastbarFamily
H.EnsureSkin = EnsureSkin
H.RestoreSkin = RestoreSkin
H.ApplySkin = ApplySkin

-- Modules/Castbar/Style.lua
-- EnhanceTBC - Castbar sizing/texture/alpha/color helpers (internal).

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}

local mod = ETBC.Modules.Castbar
if not mod then return end

mod.Internal = mod.Internal or {}
local H = {}
mod.Internal.Style = H

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

local function LSM_Fetch(kind, key, fallback)
  local shared = GetShared()
  if shared and type(shared.LSM_Fetch) == "function" then
    return shared.LSM_Fetch(kind, key, fallback)
  end
  return fallback
end

local function InCombat()
  local shared = GetShared()
  if shared and type(shared.InCombat) == "function" then
    return shared.InCombat()
  end
  return false
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

local function ApplyPlayerOffset(bar, active)
  if not IsPrimaryPlayerCastbar(bar) then return end
  local skin = EnsureSkin(bar)
  if not (skin and skin.playerFramePoints) then return end

  RestorePoints(bar, skin.playerFramePoints)
  if not active then return end

  local db = CallGetDB()
  if not db then return end

  local xOff = tonumber(db.xOffset) or 0
  local yOff = tonumber(db.yOffset) or 0
  if xOff == 0 and yOff == 0 then return end

  local shifted = {}
  for i = 1, #skin.playerFramePoints do
    local p = skin.playerFramePoints[i]
    shifted[i] = { p[1], p[2], p[3], (p[4] or 0) + xOff, (p[5] or 0) + yOff }
  end
  RestorePoints(bar, shifted)
end

local function ApplyBarColors(bar, active)
  if not bar then return end

  if not active then
    if bar.SetStartCastColor then bar:SetStartCastColor(1.0, 0.7, 0.0) end
    if bar.SetStartChannelColor then bar:SetStartChannelColor(0.0, 1.0, 0.0) end
    if bar.SetNonInterruptibleCastColor then bar:SetNonInterruptibleCastColor(0.7, 0.7, 0.7) end
    return
  end

  local db = CallGetDB()
  if not db then return end

  local cast = db.castColor or { 0.25, 0.80, 0.25 }
  local channel = db.channelColor or { 0.25, 0.55, 1.00 }
  local nonInterrupt = db.nonInterruptibleColor or { 0.85, 0.25, 0.25 }
  if bar.SetStartCastColor then
    bar:SetStartCastColor(cast[1] or 0.25, cast[2] or 0.80, cast[3] or 0.25)
  end
  if bar.SetStartChannelColor then
    bar:SetStartChannelColor(channel[1] or 0.25, channel[2] or 0.55, channel[3] or 1.0)
  end
  if bar.SetNonInterruptibleCastColor then
    bar:SetNonInterruptibleCastColor(nonInterrupt[1] or 0.85, nonInterrupt[2] or 0.25, nonInterrupt[3] or 0.25)
  end
end

local function ApplySizing(bar, active)
  if not bar then return end
  local db = CallGetDB()
  if not db then return end

  if not bar._etbcOrig then
    local tex
    if bar.GetStatusBarTexture and bar:GetStatusBarTexture() and bar:GetStatusBarTexture().GetTexture then
      tex = bar:GetStatusBarTexture():GetTexture()
    end
    bar._etbcOrig = {
      w = bar.GetWidth and bar:GetWidth() or nil,
      h = bar.GetHeight and bar:GetHeight() or nil,
      scale = bar.GetScale and bar:GetScale() or 1,
      texture = tex,
    }
  end

  if not (active and db.enabled) then
    if bar.SetScale and bar._etbcOrig.scale then bar:SetScale(bar._etbcOrig.scale) end
    if bar.SetSize and bar._etbcOrig.w and bar._etbcOrig.h then bar:SetSize(bar._etbcOrig.w, bar._etbcOrig.h) end
    if bar.SetStatusBarTexture and bar._etbcOrig.texture then bar:SetStatusBarTexture(bar._etbcOrig.texture) end
    return
  end

  if bar.SetScale then bar:SetScale(tonumber(db.scale) or 1) end
  -- NOTE: Width/Height resizing disabled - causes size mismatch between frame and internal statusbar texture
  -- Use scale setting instead
  -- if bar.SetSize then bar:SetSize(tonumber(db.width) or 195, tonumber(db.height) or 18) end
end

local function ApplyTexture(bar, active)
  if not (bar and bar.SetStatusBarTexture) then return end
  local db = CallGetDB()
  if not db then return end

  if not (active and db.enabled) then
    if bar._etbcOrig and bar._etbcOrig.texture then
      bar:SetStatusBarTexture(bar._etbcOrig.texture)
    end
    return
  end

  local texture = LSM_Fetch("statusbar", db.texture, "Interface\\TargetingFrame\\UI-StatusBar")
  if texture then
    bar:SetStatusBarTexture(texture)
  end
end

local function ApplyAlpha(bar, active)
  local db = CallGetDB()
  if not db then return end

  if not (active and db.enabled) then
    if bar and bar.SetAlpha then bar:SetAlpha(1) end
    return
  end

  local a = db.onlyInCombat and (InCombat() and (db.combatAlpha or 1) or (db.oocAlpha or 0.2)) or 1

  if bar and bar.SetAlpha then bar:SetAlpha(a) end
end

H.ApplyPlayerOffset = ApplyPlayerOffset
H.ApplyBarColors = ApplyBarColors
H.ApplySizing = ApplySizing
H.ApplyTexture = ApplyTexture
H.ApplyAlpha = ApplyAlpha

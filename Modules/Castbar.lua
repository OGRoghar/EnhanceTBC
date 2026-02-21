-- Modules/Castbar.lua
-- EnhanceTBC - Castbar Micro Tweaks (Blizzard cast bars)
-- Fix: prevent "double layer" by anchoring overlays to the real statusbar texture
-- and using OVERLAY layer + insets.

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.Castbar = mod
local Compat = ETBC.Compat or {}

local driver
local hooked = false
local unpackFn = unpack or table.unpack

local CASTBAR_DEFAULTS = {
  enabled = true,
  player = true,
  target = true,
  focus = true,

  width = 240,
  height = 18,
  scale = 1.0,
  xOffset = 0,
  yOffset = 0,

  font = "Friz Quadrata TT",
  texture = "Blizzard",
  fontSize = 12,
  outline = "OUTLINE",
  shadow = true,
  showTime = true,
  timeFormat = "REMAIN",
  decimals = 1,

  skin = true,
  showChannelTicks = false,

  castColor = { 0.25, 0.80, 0.25 },
  channelColor = { 0.25, 0.55, 1.00 },
  nonInterruptibleColor = { 0.85, 0.25, 0.25 },
  backgroundAlpha = 0.35,
  borderAlpha = 0.95,

  showLatency = true,
  latencyMode = "CAST",
  latencyAlpha = 0.45,
  latencyColor = { 1.0, 0.15, 0.15 },

  fadeOut = true,
  fadeOutTime = 0.20,

  onlyInCombat = false,
  oocAlpha = 1.0,
  combatAlpha = 1.0,
}

local NAME_TEXT_LEFT_PAD = 6
local NAME_TEXT_RIGHT_PAD = 6
local TIMER_TEXT_WIDTH = 52
local TIMER_TEXT_RIGHT_PAD = 4

local channelingSpells = {
  ["Mind Flay"] = 3,
  ["Blizzard"] = 8,
  ["Arcane Missiles"] = 5,
  ["Evocation"] = 4,
  ["Hurricane"] = 10,
  ["Drain Soul"] = 5,
  ["Drain Life"] = 5,
  ["Drain Mana"] = 5,
  ["First Aid"] = 8,
  ["Volley"] = 6,
  ["Tranquility"] = 4,
  ["Health Funnel"] = 10,
  ["Rain of Fire"] = 4,
  ["Hellfire"] = 15,
}

local function EnsureDriver()
  if driver then return end
  driver = CreateFrame("Frame", "EnhanceTBC_CastbarDriver", UIParent)
end

local function GetDB()
  ETBC.db.profile.castbar = ETBC.db.profile.castbar or {}
  local db = ETBC.db.profile.castbar

  for key, value in pairs(CASTBAR_DEFAULTS) do
    if db[key] == nil then
      if type(value) == "table" then
        db[key] = { value[1], value[2], value[3] }
      else
        db[key] = value
      end
    end
  end

  return db
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

local function StyleFontString(fs)
  if not fs or not fs.SetFont then return end
  local db = GetDB()
  local fontPath = LSM_Fetch("font", db.font, "Fonts\\FRIZQT__.TTF")
  local size = tonumber(db.fontSize) or 12
  local outline = db.outline or ""
  fs:SetFont(fontPath, size, outline)

  if db.shadow then
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.85)
  else
    fs:SetShadowOffset(0, 0)
  end
end

local function SnapshotPoints(frame)
  if not frame or not frame.GetNumPoints then return nil end
  local points = {}
  local count = frame:GetNumPoints() or 0
  for i = 1, count do
    local p, rel, rp, x, y = frame:GetPoint(i)
    points[i] = { p, rel, rp, x, y }
  end
  return points
end

local function RestorePoints(frame, points)
  if not frame or not points then return end
  frame:ClearAllPoints()
  for i = 1, #points do
    local p = points[i]
    if p and p[1] then
      frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
    end
  end
end

local function ApplyIconBackdrop(frame)
  if not frame or not frame.SetBackdrop then return end
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame:SetBackdropColor(0, 0, 0, 0)
  frame:SetBackdropBorderColor(0.42, 0.47, 0.55, 0.95)
end

local function ApplyBackdropAlt(frame)
  if not frame or not frame.SetBackdrop then return end
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame:SetBackdropColor(0.08, 0.10, 0.12, 0.18)
  frame:SetBackdropBorderColor(0.42, 0.47, 0.55, 0.90)
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

  local bgAlpha = tonumber(db.backgroundAlpha) or 0.35
  if bgAlpha < 0 then bgAlpha = 0 elseif bgAlpha > 0.8 then bgAlpha = 0.8 end
  local borderAlpha = tonumber(db.borderAlpha) or 0.95
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
  local db = GetDB()
  if not bar then return end

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

local function GetChannelTicks(spellName)
  if not spellName then return nil end

  local total = channelingSpells[spellName]
  if total then return total end

  if not GetSpellDescription then return nil end
  local spellDesc = GetSpellDescription(spellName)
  if not spellDesc then return nil end

  local string_match = string.match(spellDesc, "every %S+ second for %S+ sec")
    or string.match(spellDesc, "every %S+ sec for %S+ sec")
    or string.match(spellDesc, "every %S+ sec.%s+Lasts %S+ sec")

  if not string_match then return nil end

  local min_time
  local max_time
  for v in string.gmatch(string_match, "%d+%.?%d*") do
    if not min_time then
      min_time = v
    elseif not max_time then
      max_time = v
    end
  end

  if min_time and max_time then
    total = math.floor((tonumber(max_time) / tonumber(min_time)) + 0.5)
  end

  return total
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

  local db = GetDB()
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
  local db = GetDB()

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

local function ApplyPlayerOffset(bar, active)
  if not IsPrimaryPlayerCastbar(bar) then return end
  local skin = EnsureSkin(bar)
  if not (skin and skin.playerFramePoints) then return end

  RestorePoints(bar, skin.playerFramePoints)
  if not active then return end

  local db = GetDB()
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

  local db = GetDB()
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

local function ResetCustomFade(bar)
  if not bar then return end
  bar._etbcFadeActive = false
  bar._etbcFadeElapsed = 0
  bar._etbcFadeStartAlpha = nil
end

local function HideBarNow(bar)
  if not bar then return end
  if bar.UpdateShownState then
    bar:UpdateShownState(false)
  elseif bar.Hide then
    bar:Hide()
  end
end

local function HandleCustomFade(bar, elapsed)
  if not bar or not bar._etbcManaged then
    ResetCustomFade(bar)
    return
  end

  local db = GetDB()
  local now = (GetTime and GetTime()) or 0
  local holdExpired = (not bar.holdTime) or (bar.holdTime <= now)
  local idleNoEffects = (not bar.casting) and (not bar.channeling) and (not bar.flash) and holdExpired

  if not (db.enabled and db.fadeOut) then
    if bar.fadeOut or idleNoEffects then
      bar.fadeOut = nil
      HideBarNow(bar)
    end
    ResetCustomFade(bar)
    return
  end

  if bar.casting or bar.channeling then
    ResetCustomFade(bar)
    return
  end

  if bar.fadeOut and not bar._etbcFadeActive then
    bar._etbcFadeActive = true
    bar._etbcFadeElapsed = 0
    bar._etbcFadeStartAlpha = (bar.GetAlpha and bar:GetAlpha()) or 1
    bar.fadeOut = nil
  end

  if not bar._etbcFadeActive then
    if idleNoEffects then
      HideBarNow(bar)
    end
    return
  end

  local duration = tonumber(db.fadeOutTime) or 0.20
  if duration < 0.01 then duration = 0.01 end
  bar._etbcFadeElapsed = (bar._etbcFadeElapsed or 0) + (elapsed or 0)
  local t = bar._etbcFadeElapsed / duration

  if t >= 1 then
    if bar.ApplyAlpha then
      bar:ApplyAlpha(0)
    elseif bar.SetAlpha then
      bar:SetAlpha(0)
    end
    ResetCustomFade(bar)
    HideBarNow(bar)
    return
  end

  local startAlpha = bar._etbcFadeStartAlpha or 1
  local alpha = startAlpha * (1 - t)
  if bar.ApplyAlpha then
    bar:ApplyAlpha(alpha)
  elseif bar.SetAlpha then
    bar:SetAlpha(alpha)
  end

end

-- Returns a good "content" region inside the castbar for overlay anchoring.
-- Prefer the real statusbar texture if available.
local function GetFillRegion(bar)
  if not bar then return bar end

  -- Most Blizzard castbars are StatusBars
  if bar.GetStatusBarTexture then
    local tx = bar:GetStatusBarTexture()
    if tx and tx.GetParent then
      return tx
    end
  end

  -- Some templates expose a texture directly
  if bar.barTexture and bar.barTexture.GetParent then
    return bar.barTexture
  end

  return bar
end

local function EnsureLatency(bar)
  if not bar then return nil end
  if bar._etbcLatency and bar._etbcLatency.SetWidth then return bar._etbcLatency end

  -- Create as OVERLAY so it cannot look like a second background bar.
  local tx = bar:CreateTexture(nil, "OVERLAY")
  tx:SetTexture("Interface\\Buttons\\WHITE8x8")

  -- Anchor to the fill region (statusbar texture) with small insets.
  local region = GetFillRegion(bar)
  tx:ClearAllPoints()

  if region ~= bar and region.GetPoint then
    -- Match the vertical bounds of the real fill texture (avoid border/flash layers)
    tx:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -2, -2)
    tx:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -2, 2)
  else
    tx:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -2, -2)
    tx:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -2, 2)
  end

  tx:SetWidth(0)

  local db = GetDB()
  local c = db.latencyColor or { 0.2, 1, 0.2 }
  local a = db.latencyAlpha or c[4] or 0.28
  tx:SetVertexColor(c[1] or 0.2, c[2] or 1, c[3] or 0.2, a)

  tx:Hide()
  bar._etbcLatency = tx
  return tx
end

local function EnsureChannelTickTextures(bar)
  if not bar then return end
  bar._etbcChannelTicks = bar._etbcChannelTicks or {}
end

local function HideChannelTicks(bar)
  if not bar or not bar._etbcChannelTicks then return end
  for _, tick in ipairs(bar._etbcChannelTicks) do
    tick:Hide()
  end
end

local function UpdateChannelTicks(bar, spellName)
  local db = GetDB()
  if not (db.enabled and db.showChannelTicks) then
    HideChannelTicks(bar)
    return
  end
  local isPlayerBar = (bar == _G.PlayerCastingBarFrame or bar == _G.CastingBarFrame)
  if not bar or (bar.unit ~= "player" and not isPlayerBar) then
    HideChannelTicks(bar)
    return
  end
  if not bar or not bar.IsShown or not bar:IsShown() then return end

  local total = GetChannelTicks(spellName)
  if not total or total <= 1 then
    HideChannelTicks(bar)
    return
  end

  EnsureChannelTickTextures(bar)
  local count = total - 1
  local width = bar.GetWidth and bar:GetWidth() or 0
  local height = bar.GetHeight and bar:GetHeight() or 18

  for i = 1, count do
    local tick = bar._etbcChannelTicks[i]
    if not tick then
      tick = bar:CreateTexture(nil, "OVERLAY")
      tick:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
      tick:SetBlendMode("ADD")
      tick:SetAlpha(0.4)
      bar._etbcChannelTicks[i] = tick
    end
    tick:SetSize(6, height + 6)
    tick:ClearAllPoints()
    tick:SetPoint("LEFT", bar, "LEFT", (width / total * i) - 3, 0)
    tick:Show()
  end

  for i = count + 1, #bar._etbcChannelTicks do
    bar._etbcChannelTicks[i]:Hide()
  end
end

local function ApplySizing(bar, active)
  if not bar then return end
  local db = GetDB()

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
  local db = GetDB()
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
  local db = GetDB()
  if not (active and db.enabled) then
    if bar and bar.SetAlpha then bar:SetAlpha(1) end
    return
  end

  local a = db.onlyInCombat and (InCombat() and (db.combatAlpha or 1) or (db.oocAlpha or 0.2)) or 1

  if bar and bar.SetAlpha then bar:SetAlpha(a) end
end

local function FormatTime(cur, maxv, mode, decimals)
  if not cur or not maxv or maxv <= 0 then return "" end
  local remain = maxv - cur
  if remain < 0 then remain = 0 end

  local dec = tonumber(decimals) or 1
  if dec < 0 then dec = 0 end
  if dec > 2 then dec = 2 end
  local fmt = "%." .. dec .. "f"

  if mode == "ELAPSED" then
    return string.format(fmt, cur)
  elseif mode == "BOTH" then
    return string.format(fmt .. "/" .. fmt, cur, maxv)
  end

  return string.format(fmt, remain)
end

local function UpdateBarText(bar, active)
  if not bar or not bar.IsShown or not bar:IsShown() then return end
  local db = GetDB()
  ApplyTextLayout(bar, active and db.enabled)
  if not (active and db.enabled and db.showTime) then
    if bar._etbcTimeText then bar._etbcTimeText:SetText(""); bar._etbcTimeText:Hide() end
    return
  end

  local fs = EnsureText(bar)
  StyleFontString(fs)

  local cur = bar.GetValue and bar:GetValue() or 0
  local maxv = bar.GetMinMaxValues and select(2, bar:GetMinMaxValues()) or 0
  local mode = db.timeFormat or "REMAIN"
  if mode == "REMAINING" then mode = "REMAIN" end
  fs:SetText(FormatTime(cur, maxv, mode, db.decimals))
  fs:Show()
end

local function UpdateLatency(bar, active)
  local db = GetDB()
  if not (active and db.enabled and db.showLatency) then
    if bar and bar._etbcLatency then bar._etbcLatency:Hide() end
    return
  end

  if bar and bar._etbcLatency then
    local c = db.latencyColor or { 0.2, 1, 0.2 }
    local a = db.latencyAlpha or c[4] or 0.28
    bar._etbcLatency:SetVertexColor(c[1] or 0.2, c[2] or 1, c[3] or 0.2, a)
  end

  -- Player only
  local isPlayerBar = (bar == _G.PlayerCastingBarFrame or bar == _G.CastingBarFrame)
  if not bar or (bar.unit and bar.unit ~= "player") and not isPlayerBar then
    if bar and bar._etbcLatency then bar._etbcLatency:Hide() end
    return
  end

  local maxv = bar.GetMinMaxValues and select(2, bar:GetMinMaxValues()) or 0
  if not maxv or maxv <= 0 then
    if bar._etbcLatency then bar._etbcLatency:Hide() end
    return
  end

  local lagSeconds
  if db.latencyMode == "NET" then
    lagSeconds = bar._etbcLatencySeconds
  else
    if not bar._etbcSentMS or not bar._etbcStartMS then
      if bar._etbcLatency then bar._etbcLatency:Hide() end
      return
    end
    local lagMS = bar._etbcStartMS - bar._etbcSentMS
    if lagMS < 0 then lagMS = 0 end
    lagSeconds = lagMS / 1000
  end

  if lagSeconds <= 0 then
    if bar._etbcLatency then bar._etbcLatency:Hide() end
    return
  end

  local frac = lagSeconds / maxv
  if frac > 1 then frac = 1 end

  local tx = EnsureLatency(bar)

  local barW = (bar.GetWidth and bar:GetWidth() or 195) - 4 -- account for inset (-2,-2)
  if barW < 1 then barW = 1 end

  tx:SetWidth(barW * frac)
  tx:Show()
end

local function OnBarValueChanged(bar, active)
  UpdateBarText(bar, active)
  UpdateLatency(bar, active)
end

local function HookBar(bar)
  if not bar or bar._etbcHooked then return end
  bar._etbcHooked = true
  bar._etbcManaged = false

  -- Hook SetValue to refresh time/latency without OnUpdate spam
  hooksecurefunc(bar, "SetValue", function()
    OnBarValueChanged(bar, bar._etbcManaged and true or false)
  end)

  bar:HookScript("OnShow", function()
    local active = bar._etbcManaged and true or false
    ResetCustomFade(bar)
    ApplySizing(bar, active)
    ApplyTexture(bar, active)
    ApplyBarColors(bar, active)
    ApplyAlpha(bar, active)
    ApplyPlayerOffset(bar, active)
    ApplyTextLayout(bar, active)
    ApplyIconLayout(bar, active)
    ApplySkin(bar, active)
    if active and bar.Text and bar.Text.SetFont then
      StyleFontString(bar.Text)
    end
    if active and bar._etbcChannelSpellName then
      UpdateChannelTicks(bar, bar._etbcChannelSpellName)
    else
      HideChannelTicks(bar)
    end
    OnBarValueChanged(bar, active)
  end)

  bar:HookScript("OnUpdate", function(_, elapsed)
    HandleCustomFade(bar, elapsed)
  end)

  bar:HookScript("OnHide", function()
    ResetCustomFade(bar)
    if bar._etbcLatency then bar._etbcLatency:Hide() end
    if bar._etbcTimeText then bar._etbcTimeText:Hide() end
    HideChannelTicks(bar)
  end)
end

local function GetAllBars()
  local out = {}

  local function Add(bar)
    if bar then
      table.insert(out, bar)
    end
  end

  Add(_G.PlayerCastingBarFrame)
  if _G.CastingBarFrame and _G.CastingBarFrame ~= _G.PlayerCastingBarFrame then
    Add(_G.CastingBarFrame)
  end
  Add(_G.PetCastingBarFrame)
  Add(_G.TargetFrameSpellBar)
  Add(_G.FocusFrameSpellBar)
  return out
end

local function IsBarEnabledBySettings(db, bar)
  if not bar then return false end
  if IsPlayerCastbarFamily(bar) then
    return db.player and true or false
  end
  if bar == _G.TargetFrameSpellBar then
    return db.target and true or false
  end
  if bar == _G.FocusFrameSpellBar then
    return db.focus and true or false
  end
  return false
end

local RefreshPreviewIfShown

local function Apply()
  EnsureDriver()

  local generalEnabled = ETBC.db and ETBC.db.profile and ETBC.db.profile.general and ETBC.db.profile.general.enabled
  local db = GetDB()
  local bars = GetAllBars()
  for _, bar in ipairs(bars) do
    HookBar(bar)
  end

  local moduleActive = generalEnabled and db.enabled
  for _, bar in ipairs(bars) do
    local active = moduleActive and IsBarEnabledBySettings(db, bar)
    bar._etbcManaged = active and true or false

    ApplySizing(bar, active)
    ApplyTexture(bar, active)
    ApplyBarColors(bar, active)
    ApplyAlpha(bar, active)
    ApplyPlayerOffset(bar, active)
    ApplyTextLayout(bar, active)
    ApplyIconLayout(bar, active)
    ApplySkin(bar, active)

    if active and bar.Text and bar.Text.SetFont then
      StyleFontString(bar.Text)
    end
    if active and bar._etbcChannelSpellName then
      UpdateChannelTicks(bar, bar._etbcChannelSpellName)
    else
      HideChannelTicks(bar)
    end
    OnBarValueChanged(bar, active)

    if not active then
      ResetCustomFade(bar)
      if bar._etbcLatency then bar._etbcLatency:Hide() end
      if bar._etbcTimeText then
        bar._etbcTimeText:SetText("")
        bar._etbcTimeText:Hide()
      end
    end
  end
  RefreshPreviewIfShown()
end

local function EnsurePreviewBar()
  if mod._previewBar then return mod._previewBar end
  local bar = CreateFrame("StatusBar", "EnhanceTBC_CastbarPreview", UIParent, "BackdropTemplate")
  bar:SetPoint("CENTER", UIParent, "CENTER", 0, -220)
  bar:SetMinMaxValues(0, 2)
  bar:SetValue(0)
  bar:Hide()

  bar.bg = bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetAllPoints(true)
  bar.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
  bar.bg:SetVertexColor(0, 0, 0, 0.35)

  bar.Text = bar:CreateFontString(nil, "OVERLAY")
  bar.Text:SetPoint("TOPLEFT", bar, "TOPLEFT", NAME_TEXT_LEFT_PAD, 0)
  local previewReserve = TIMER_TEXT_WIDTH + TIMER_TEXT_RIGHT_PAD + NAME_TEXT_RIGHT_PAD
  bar.Text:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -previewReserve, 0)
  bar.Text:SetJustifyH("CENTER")
  bar.Text:SetJustifyV("MIDDLE")
  bar.Text:SetText("Preview Cast")

  bar._etbcTimeText = bar:CreateFontString(nil, "OVERLAY")
  bar._etbcTimeText:SetPoint("RIGHT", bar, "RIGHT", -TIMER_TEXT_RIGHT_PAD, 0)
  bar._etbcTimeText:SetWidth(TIMER_TEXT_WIDTH)
  bar._etbcTimeText:SetJustifyH("RIGHT")
  bar._etbcTimeText:SetJustifyV("MIDDLE")

  ApplyBackdropAlt(bar)
  mod._previewBar = bar
  return bar
end

local function ApplyPreviewTextLayout(bar)
  if not bar then return end
  local db = GetDB()
  local reserve = db.showTime and (TIMER_TEXT_WIDTH + TIMER_TEXT_RIGHT_PAD + NAME_TEXT_RIGHT_PAD) or NAME_TEXT_RIGHT_PAD
  if bar.Text then
    bar.Text:ClearAllPoints()
    bar.Text:SetPoint("TOPLEFT", bar, "TOPLEFT", NAME_TEXT_LEFT_PAD, 0)
    bar.Text:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -reserve, 0)
    bar.Text:SetJustifyH("CENTER")
    bar.Text:SetJustifyV("MIDDLE")
  end
  if bar._etbcTimeText then
    bar._etbcTimeText:ClearAllPoints()
    bar._etbcTimeText:SetPoint("RIGHT", bar, "RIGHT", -TIMER_TEXT_RIGHT_PAD, 0)
    bar._etbcTimeText:SetWidth(TIMER_TEXT_WIDTH)
    bar._etbcTimeText:SetJustifyH("RIGHT")
    bar._etbcTimeText:SetJustifyV("MIDDLE")
  end
end

local function RefreshPreviewBar(force)
  local bar = mod._previewBar
  if not bar then return end
  if not force and bar.IsShown and not bar:IsShown() then return end

  local db = GetDB()
  if not db.enabled then
    if bar.Hide then bar:Hide() end
    return
  end

  if bar.SetScale then bar:SetScale(tonumber(db.scale) or 1) end
  if bar.SetSize then bar:SetSize(tonumber(db.width) or 195, tonumber(db.height) or 18) end

  local texture = LSM_Fetch("statusbar", db.texture, "Interface\\TargetingFrame\\UI-StatusBar")
  if texture and bar.SetStatusBarTexture then
    bar:SetStatusBarTexture(texture)
  end

  local cast = db.castColor or { 0.25, 0.80, 0.25 }
  if bar.SetStatusBarColor then
    bar:SetStatusBarColor(cast[1] or 0.25, cast[2] or 0.80, cast[3] or 0.25)
  end

  ApplySkinBackdropColors(bar, { backdrop = bar }, db)
  ApplyPreviewTextLayout(bar)
  StyleFontString(bar.Text)
  StyleFontString(bar._etbcTimeText)
  ApplyAlpha(bar, true)

  if not db.showTime and bar._etbcTimeText then
    bar._etbcTimeText:SetText("")
    bar._etbcTimeText:Hide()
  end
end

RefreshPreviewIfShown = function()
  RefreshPreviewBar(false)
end

function mod.ShowPreview(_, duration)
  local db = GetDB()
  local bar = EnsurePreviewBar()
  local d = tonumber(duration) or 2.0
  if d < 0.5 then d = 0.5 end
  if d > 8 then d = 8 end

  bar:SetMinMaxValues(0, d)
  bar:SetValue(0)
  bar.Text:SetText("Preview Cast")
  RefreshPreviewBar(true)
  bar:Show()

  local start = GetTime()
  bar:SetScript("OnUpdate", function(self)
    local elapsed = GetTime() - start
    if elapsed >= d then
      self:SetScript("OnUpdate", nil)
      self:Hide()
      return
    end
    self:SetValue(elapsed)
    if db.showTime then
      self._etbcTimeText:SetText(FormatTime(elapsed, d, db.timeFormat or "REMAIN", db.decimals))
      self._etbcTimeText:Show()
    else
      self._etbcTimeText:SetText("")
      self._etbcTimeText:Hide()
    end
  end)
end

local function EnsureHooks()
  if hooked then return end
  hooked = true

  EnsureDriver()
  driver:RegisterEvent("PLAYER_ENTERING_WORLD")
  driver:RegisterEvent("PLAYER_REGEN_DISABLED")
  driver:RegisterEvent("PLAYER_REGEN_ENABLED")

  -- latency capture (player casts only)
  driver:RegisterEvent("UNIT_SPELLCAST_SENT")
  driver:RegisterEvent("UNIT_SPELLCAST_START")
  driver:RegisterEvent("UNIT_SPELLCAST_STOP")
  driver:RegisterEvent("UNIT_SPELLCAST_FAILED")
  driver:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
  driver:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
  driver:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")

  driver:SetScript("OnEvent", function(_, event, unit, _, spellId)
    if event == "PLAYER_ENTERING_WORLD" then
      Apply()
      return
    end

    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
      local eventDB = GetDB()
      local generalEnabledNow = ETBC.db
        and ETBC.db.profile
        and ETBC.db.profile.general
        and ETBC.db.profile.general.enabled
      for _, bar in ipairs(GetAllBars()) do
        local active = generalEnabledNow and eventDB.enabled and IsBarEnabledBySettings(eventDB, bar)
        bar._etbcManaged = active and true or false
        ApplyAlpha(bar, active)
      end
      return
    end

    if unit ~= "player" then return end

    local function StampSent()
      local ms = GetTime and math.floor(GetTime() * 1000) or 0
      local pb = _G.PlayerCastingBarFrame or _G.CastingBarFrame
      if pb then pb._etbcSentMS = ms end
    end

    local function StampStart()
      local ms = GetTime and math.floor(GetTime() * 1000) or 0
      local pb = _G.PlayerCastingBarFrame or _G.CastingBarFrame
      if pb then pb._etbcStartMS = ms end
    end

    local function StampNetLatency()
      local pb = _G.PlayerCastingBarFrame or _G.CastingBarFrame
      if not pb then return end
      if not GetNetStats then return end
      local _, _, latency, latencyWorld = GetNetStats()
      local total = (latency or 0) + (latencyWorld or 0)
      if total > 0 then
        pb._etbcLatencySeconds = total / 1000
      else
        pb._etbcLatencySeconds = nil
      end
    end

    if event == "UNIT_SPELLCAST_SENT" then
      StampSent()
      return
    end

    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
      StampStart()
      StampNetLatency()
      local pb = _G.PlayerCastingBarFrame or _G.CastingBarFrame
      if pb then
        HookBar(pb)
        local active = pb._etbcManaged and true or false
        ResetCustomFade(pb)
        ApplyBarColors(pb, active)
        ApplyPlayerOffset(pb, active)
        ApplyTextLayout(pb, active)
        ApplyIconLayout(pb, active)
        ApplySkin(pb, active)
        OnBarValueChanged(pb, active)
      end
      if event == "UNIT_SPELLCAST_CHANNEL_START" and pb and pb._etbcManaged then
        local spellName = nil
        if spellId and Compat.GetSpellInfoByID then
          local info = Compat.GetSpellInfoByID(spellId)
          spellName = info and info.name or nil
        elseif UnitChannelInfo then
          spellName = select(1, UnitChannelInfo("player"))
        end
        pb._etbcChannelSpellName = spellName
        UpdateChannelTicks(pb, spellName)
      else
        if pb then
          pb._etbcChannelSpellName = nil
          HideChannelTicks(pb)
        end
      end
      return
    end

    if event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED"
      or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
      local pb = _G.PlayerCastingBarFrame or _G.CastingBarFrame
      if pb then
        pb._etbcLatencySeconds = nil
        if pb._etbcLatency then pb._etbcLatency:Hide() end
        HideChannelTicks(pb)
        pb._etbcChannelSpellName = nil
      end
      return
    end
  end)
end

EnsureHooks()

ETBC.ApplyBus:Register("castbar", Apply)
ETBC.ApplyBus:Register("general", Apply)

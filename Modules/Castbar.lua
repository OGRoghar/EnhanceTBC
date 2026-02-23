-- Modules/Castbar.lua
-- EnhanceTBC - Castbar Micro Tweaks (Blizzard cast bars)
-- Fix: prevent "double layer" by anchoring overlays to the real statusbar texture
-- and using OVERLAY layer + insets.

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.Castbar = mod
mod.Internal = mod.Internal or {}
mod.Internal.Shared = mod.Internal.Shared or {}
local Compat = ETBC.Compat or {}

local driver
local hooked = false

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
  classColorPlayerCastbar = false,

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
mod.Internal.Shared.NAME_TEXT_LEFT_PAD = NAME_TEXT_LEFT_PAD
mod.Internal.Shared.NAME_TEXT_RIGHT_PAD = NAME_TEXT_RIGHT_PAD
mod.Internal.Shared.TIMER_TEXT_WIDTH = TIMER_TEXT_WIDTH
mod.Internal.Shared.TIMER_TEXT_RIGHT_PAD = TIMER_TEXT_RIGHT_PAD

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
mod.Internal.Shared.channelingSpells = channelingSpells

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
mod.Internal.Shared.GetDB = GetDB

local function LSM_Fetch(kind, key, fallback)
  if ETBC.LSM and ETBC.LSM.Fetch then
    local ok, v = pcall(ETBC.LSM.Fetch, ETBC.LSM, kind, key)
    if ok and v then return v end
  end
  return fallback
end
mod.Internal.Shared.LSM_Fetch = LSM_Fetch

local function InCombat()
  if InCombatLockdown and InCombatLockdown() then return true end
  if UnitAffectingCombat then return UnitAffectingCombat("player") and true or false end
  return false
end
mod.Internal.Shared.InCombat = InCombat

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
mod.Internal.Shared.SnapshotPoints = SnapshotPoints

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
mod.Internal.Shared.RestorePoints = RestorePoints

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
mod.Internal.Shared.ApplyIconBackdrop = ApplyIconBackdrop

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
mod.Internal.Shared.ApplyBackdropAlt = ApplyBackdropAlt

local function GetSkinInternal()
  return mod.Internal and mod.Internal.Skin
end

local function GetLayoutInternal()
  return mod.Internal and mod.Internal.Layout
end

local function GetStyleInternal()
  return mod.Internal and mod.Internal.Style
end

local function GetTimingInternal()
  return mod.Internal and mod.Internal.Timing
end

local function ApplySkinBackdropColors(bar, skin, db)
  local H = GetSkinInternal()
  if H and H.ApplySkinBackdropColors then
    H.ApplySkinBackdropColors(bar, skin, db)
  end
end
mod.Internal.Shared.StyleFontString = StyleFontString

local function IsPrimaryPlayerCastbar(bar)
  local H = GetSkinInternal()
  if H and H.IsPrimaryPlayerCastbar then
    return H.IsPrimaryPlayerCastbar(bar)
  end
  return bar == _G.PlayerCastingBarFrame or bar == _G.CastingBarFrame
end

local function IsPlayerCastbarFamily(bar)
  local H = GetSkinInternal()
  if H and H.IsPlayerCastbarFamily then
    return H.IsPlayerCastbarFamily(bar)
  end
  return IsPrimaryPlayerCastbar(bar) or bar == _G.PetCastingBarFrame
end

local function ApplySkin(bar, active)
  local H = GetSkinInternal()
  if H and H.ApplySkin then
    H.ApplySkin(bar, active)
  end
end

local function ApplyTextLayout(bar, active)
  local H = GetLayoutInternal()
  if H and H.ApplyTextLayout then
    H.ApplyTextLayout(bar, active)
  end
end

local function ApplyIconLayout(bar, active)
  local H = GetLayoutInternal()
  if H and H.ApplyIconLayout then
    H.ApplyIconLayout(bar, active)
  end
end

local function ApplyPlayerOffset(bar, active)
  local H = GetStyleInternal()
  if H and H.ApplyPlayerOffset then
    H.ApplyPlayerOffset(bar, active)
  end
end

local function ApplyBarColors(bar, active)
  local H = GetStyleInternal()
  if H and H.ApplyBarColors then
    H.ApplyBarColors(bar, active)
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

local function HideChannelTicks(bar)
  local H = GetTimingInternal()
  if H and H.HideChannelTicks then
    H.HideChannelTicks(bar)
  end
end

local function UpdateChannelTicks(bar, spellName)
  local H = GetTimingInternal()
  if H and H.UpdateChannelTicks then
    H.UpdateChannelTicks(bar, spellName)
  end
end

local function ApplySizing(bar, active)
  local H = GetStyleInternal()
  if H and H.ApplySizing then
    H.ApplySizing(bar, active)
  end
end

local function ApplyTexture(bar, active)
  local H = GetStyleInternal()
  if H and H.ApplyTexture then
    H.ApplyTexture(bar, active)
  end
end

local function ApplyAlpha(bar, active)
  local H = GetStyleInternal()
  if H and H.ApplyAlpha then
    H.ApplyAlpha(bar, active)
  end
end

local function FormatTime(cur, maxv, mode, decimals)
  local H = GetTimingInternal()
  if H and H.FormatTime then
    return H.FormatTime(cur, maxv, mode, decimals)
  end
  return ""
end

local function OnBarValueChanged(bar, active)
  local H = GetTimingInternal()
  if H and H.OnBarValueChanged then
    H.OnBarValueChanged(bar, active)
  end
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

local function GetPreviewCastColor(db)
  if db and db.classColorPlayerCastbar then
    local H = GetStyleInternal()
    if H and type(H.GetPlayerClassColor) == "function" then
      local r, g, b = H.GetPlayerClassColor()
      if type(r) == "number" and type(g) == "number" and type(b) == "number" then
        return r, g, b
      end
    end
  end

  local cast = db and db.castColor or nil
  cast = cast or { 0.25, 0.80, 0.25 }
  return cast[1] or 0.25, cast[2] or 0.80, cast[3] or 0.25
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

  if bar.SetStatusBarColor then
    local r, g, b = GetPreviewCastColor(db)
    bar:SetStatusBarColor(r, g, b)
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

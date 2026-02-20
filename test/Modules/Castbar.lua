-- Modules/Castbar.lua
-- EnhanceTBC - Castbar Micro Tweaks (Blizzard cast bars)
-- Fix: prevent "double layer" by anchoring overlays to the real statusbar texture
-- and using OVERLAY layer + insets.

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.Castbar = mod

local driver
local hooked = false

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

  if db.enabled == nil then db.enabled = true end

  if db.font == nil then db.font = "Friz Quadrata TT" end
  if db.fontSize == nil then db.fontSize = 11 end
  if db.outline == nil then db.outline = "OUTLINE" end
  if db.shadow == nil then db.shadow = true end

  if db.showTime == nil then db.showTime = true end
  if db.timeFormat == nil then db.timeFormat = "REMAIN" end -- REMAIN | ELAPSED | BOTH
  if db.decimals == nil then db.decimals = 1 end

  -- Latency overlay (player only)
  if db.showLatency == nil then db.showLatency = true end
  if db.latencyMode == nil then db.latencyMode = "CAST" end -- CAST | NET
  if db.latencyAlpha == nil then db.latencyAlpha = 0.45 end
  if db.latencyColor == nil then db.latencyColor = { 1.0, 0.15, 0.15 } end

  if db.showChannelTicks == nil then db.showChannelTicks = false end
  if db.skin == nil then db.skin = true end
  if db.backgroundAlpha == nil then db.backgroundAlpha = 0.22 end
  if db.borderAlpha == nil then db.borderAlpha = 0.88 end

  if db.width == nil then db.width = 195 end
  if db.height == nil then db.height = 18 end
  if db.scale == nil then db.scale = 1.0 end

  if db.target == nil then db.target = true end
  if db.focus == nil then db.focus = true end
  if db.player == nil then db.player = true end

  if db.onlyInCombat == nil then db.onlyInCombat = false end
  if db.oocAlpha == nil then db.oocAlpha = 1.0 end
  if db.combatAlpha == nil then db.combatAlpha = 1.0 end

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
  local size = tonumber(db.fontSize) or 11
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

local function ApplyBackdrop(frame)
  if not frame or not frame.SetBackdrop then return end
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame:SetBackdropColor(0.08, 0.10, 0.12, 0.14)
  frame:SetBackdropBorderColor(0.42, 0.47, 0.55, 0.90)
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

  local bgAlpha = tonumber(db.backgroundAlpha) or 0.22
  if bgAlpha < 0 then bgAlpha = 0 elseif bgAlpha > 0.8 then bgAlpha = 0.8 end
  local borderAlpha = tonumber(db.borderAlpha) or 0.88
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

local function EnsureSkin(bar)
  if not bar or bar._etbcSkin then return end
  local skin = {}
  bar._etbcSkin = skin

  skin.regionState = {
    border = bar.Border and bar.Border.IsShown and bar.Border:IsShown() or false,
    borderShield = bar.BorderShield and bar.BorderShield.IsShown and bar.BorderShield:IsShown() or false,
    flash = bar.Flash and bar.Flash.IsShown and bar.Flash:IsShown() or false,
    spark = bar.Spark and bar.Spark.IsShown and bar.Spark:IsShown() or false,
  }

  if bar.Icon and bar.Icon.GetPoint then
    skin.iconPoints = SnapshotPoints(bar.Icon)
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
    ApplyBackdrop(skin.iconBackdrop)
    skin.iconBackdrop:Hide()

    bar.Icon:HookScript("OnShow", function()
      if skin.iconBackdrop then skin.iconBackdrop:Show() end
    end)

    bar.Icon:HookScript("OnHide", function()
      if skin.iconBackdrop then skin.iconBackdrop:Hide() end
    end)
  end
end

local function ApplySkin(bar)
  local db = GetDB()
  if not bar then return end

  EnsureSkin(bar)
  local skin = bar._etbcSkin
  if not skin then return end

  if not db.enabled or not db.skin then
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

    if bar.Icon and skin.iconPoints then
      RestorePoints(bar.Icon, skin.iconPoints)
    end
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

  local isPlayerBar = (bar == _G.PlayerCastingBarFrame or bar == _G.CastingBarFrame or bar == _G.PetCastingBarFrame)
  if isPlayerBar and bar.Icon then
    bar.Icon:ClearAllPoints()
    bar.Icon:SetPoint("RIGHT", bar, "LEFT", 0, 0)
    bar.Icon:SetTexCoord(0.07, 0.90, 0.07, 0.90)
    if skin.iconBackdrop then
      skin.iconBackdrop:Show()
    end
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

local function ApplySizing(bar)
  if not bar then return end
  local db = GetDB()

  if not bar._etbcOrig then
    bar._etbcOrig = {
      w = bar.GetWidth and bar:GetWidth() or nil,
      h = bar.GetHeight and bar:GetHeight() or nil,
      scale = bar.GetScale and bar:GetScale() or 1,
    }
  end

  if not db.enabled then
    if bar.SetScale and bar._etbcOrig.scale then bar:SetScale(bar._etbcOrig.scale) end
    if bar.SetSize and bar._etbcOrig.w and bar._etbcOrig.h then bar:SetSize(bar._etbcOrig.w, bar._etbcOrig.h) end
    return
  end

  if bar.SetScale then bar:SetScale(tonumber(db.scale) or 1) end
  -- NOTE: Width/Height resizing disabled - causes size mismatch between frame and internal statusbar texture
  -- Use scale setting instead
  -- if bar.SetSize then bar:SetSize(tonumber(db.width) or 195, tonumber(db.height) or 18) end
end

local function ApplyAlpha(bar)
  local db = GetDB()
  if not db.enabled then
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

local function UpdateBarText(bar)
  if not bar or not bar.IsShown or not bar:IsShown() then return end
  local db = GetDB()
  if not (db.enabled and db.showTime) then
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

local function UpdateLatency(bar)
  local db = GetDB()
  if not (db.enabled and db.showLatency) then
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

local function OnBarValueChanged(bar)
  UpdateBarText(bar)
  UpdateLatency(bar)
end

local function HookBar(bar)
  if not bar or bar._etbcHooked then return end
  bar._etbcHooked = true

  -- Hook SetValue to refresh time/latency without OnUpdate spam
  hooksecurefunc(bar, "SetValue", function()
    OnBarValueChanged(bar)
  end)

  bar:HookScript("OnShow", function()
    ApplySizing(bar)
    ApplyAlpha(bar)
    ApplySkin(bar)
    if bar.Text and bar.Text.SetFont then
      StyleFontString(bar.Text)
    end
    if bar._etbcChannelSpellName then
      UpdateChannelTicks(bar, bar._etbcChannelSpellName)
    end
    OnBarValueChanged(bar)
  end)

  bar:HookScript("OnHide", function()
    if bar._etbcLatency then bar._etbcLatency:Hide() end
    if bar._etbcTimeText then bar._etbcTimeText:Hide() end
    HideChannelTicks(bar)
  end)

  ApplySizing(bar)
  ApplyAlpha(bar)
  ApplySkin(bar)
end

local function GetBars()
  local db = GetDB()
  local out = {}

  if db.player then
    if _G.PlayerCastingBarFrame then table.insert(out, _G.PlayerCastingBarFrame) end
    if _G.CastingBarFrame then table.insert(out, _G.CastingBarFrame) end
    if _G.PetCastingBarFrame then table.insert(out, _G.PetCastingBarFrame) end
  end

  if db.target and _G.TargetFrameSpellBar then
    table.insert(out, _G.TargetFrameSpellBar)
  end

  if db.focus and _G.FocusFrameSpellBar then
    table.insert(out, _G.FocusFrameSpellBar)
  end

  return out
end

local function Apply()
  EnsureDriver()

  local generalEnabled = ETBC.db and ETBC.db.profile and ETBC.db.profile.general and ETBC.db.profile.general.enabled
  local db = GetDB()
  if not (generalEnabled and db.enabled) then
    for _, bar in ipairs(GetBars()) do
      ApplySizing(bar)
      ApplySkin(bar)
      if bar and bar._etbcTimeText then bar._etbcTimeText:SetText(""); bar._etbcTimeText:Hide() end
      if bar and bar._etbcLatency then bar._etbcLatency:Hide() end
      HideChannelTicks(bar)
      if bar and bar.SetAlpha then bar:SetAlpha(1) end
    end
    return
  end

  for _, bar in ipairs(GetBars()) do
    HookBar(bar)
    ApplySizing(bar)
    ApplyAlpha(bar)
    ApplySkin(bar)
    OnBarValueChanged(bar)
  end
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
      for _, bar in ipairs(GetBars()) do ApplyAlpha(bar) end
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
        OnBarValueChanged(pb)
      end
      if event == "UNIT_SPELLCAST_CHANNEL_START" and pb then
        local spellName = nil
        if spellId and GetSpellInfo then
          spellName = GetSpellInfo(spellId)
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

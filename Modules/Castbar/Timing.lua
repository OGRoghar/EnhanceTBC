-- Modules/Castbar/Timing.lua
-- EnhanceTBC - Castbar timing/latency/channel tick helpers (internal).

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}

local mod = ETBC.Modules.Castbar
if not mod then return end

mod.Internal = mod.Internal or {}
local H = {}
mod.Internal.Timing = H

local function GetShared()
  return mod.Internal and mod.Internal.Shared
end

local function GetLayoutInternal()
  return mod.Internal and mod.Internal.Layout
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

local function ApplyTextLayout(bar, active)
  local layout = GetLayoutInternal()
  if layout and type(layout.ApplyTextLayout) == "function" then
    layout.ApplyTextLayout(bar, active)
  end
end

local function EnsureText(bar)
  local layout = GetLayoutInternal()
  if layout and type(layout.EnsureText) == "function" then
    return layout.EnsureText(bar)
  end
  return nil
end

local function GetChannelingSpells()
  local shared = GetShared()
  return (shared and shared.channelingSpells) or {}
end

local function GetChannelTicks(spellName)
  if not spellName then return nil end

  local channelingSpells = GetChannelingSpells()
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

  local db = CallGetDB()
  if db then
    local c = db.latencyColor or { 0.2, 1, 0.2 }
    local a = db.latencyAlpha or c[4] or 0.28
    tx:SetVertexColor(c[1] or 0.2, c[2] or 1, c[3] or 0.2, a)
  end

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
  local db = CallGetDB()
  if not db then return end

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
  local db = CallGetDB()
  if not db then return end

  ApplyTextLayout(bar, active and db.enabled)
  if not (active and db.enabled and db.showTime) then
    if bar._etbcTimeText then
      bar._etbcTimeText:SetText("")
      bar._etbcTimeText:Hide()
    end
    return
  end

  local fs = EnsureText(bar)
  StyleFontString(fs)

  local cur = bar.GetValue and bar:GetValue() or 0
  local maxv = bar.GetMinMaxValues and select(2, bar:GetMinMaxValues()) or 0
  local mode = db.timeFormat or "REMAIN"
  if mode == "REMAINING" then mode = "REMAIN" end
  if fs then
    fs:SetText(FormatTime(cur, maxv, mode, db.decimals))
    fs:Show()
  end
end

local function UpdateLatency(bar, active)
  local db = CallGetDB()
  if not db then return end

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
  if not tx then return end

  local barW = (bar.GetWidth and bar:GetWidth() or 195) - 4 -- account for inset (-2,-2)
  if barW < 1 then barW = 1 end

  tx:SetWidth(barW * frac)
  tx:Show()
end

local function OnBarValueChanged(bar, active)
  UpdateBarText(bar, active)
  UpdateLatency(bar, active)
end

H.HideChannelTicks = HideChannelTicks
H.UpdateChannelTicks = UpdateChannelTicks
H.FormatTime = FormatTime
H.OnBarValueChanged = OnBarValueChanged

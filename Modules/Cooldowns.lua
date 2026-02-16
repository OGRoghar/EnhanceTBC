-- Modules/CooldownText.lua
-- EnhanceTBC - Cooldown Text Engine (OmniCC-lite)
-- Hooks cooldown timer setters and overlays a FontString on the owner frame.
-- Lightweight: one global OnUpdate that updates tracked cooldowns at an interval.

local ADDON_NAME, ETBC = ...
local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceTBC")
ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.CooldownText = mod

local driver
local tracked = {}   -- [cooldownFrame] = state
local ordered = {}   -- compact list for faster iteration
local hooked = false

local function GetDB()
  ETBC.db.profile.cooldowns = ETBC.db.profile.cooldowns or {}
  local db = ETBC.db.profile.cooldowns

  if db.enabled == nil then db.enabled = true end

  if db.actionButtons == nil then db.actionButtons = true end
  if db.buffsDebuffs == nil then db.buffsDebuffs = true end
  if db.otherCooldownFrames == nil then db.otherCooldownFrames = true end

  if db.minDuration == nil then db.minDuration = 2.5 end
  if db.maxDuration == nil then db.maxDuration = 3600 end
  if db.hideWhenGCD == nil then db.hideWhenGCD = true end
  if db.hideWhenNoDuration == nil then db.hideWhenNoDuration = true end
  if db.hideWhenPaused == nil then db.hideWhenPaused = true end
  if db.showSwipe == nil then db.showSwipe = true end

  if db.mmssThreshold == nil then db.mmssThreshold = 60 end
  if db.showTenths == nil then db.showTenths = true end
  if db.tenthsThreshold == nil then db.tenthsThreshold = 3.0 end
  if db.roundUp == nil then db.roundUp = true end

  if db.font == nil then db.font = "Friz Quadrata TT" end
  if db.size == nil then db.size = 16 end
  if db.outline == nil then db.outline = "OUTLINE" end
  if db.shadow == nil then db.shadow = true end
  if db.scaleByIcon == nil then db.scaleByIcon = true end
  if db.minScale == nil then db.minScale = 0.70 end
  if db.maxScale == nil then db.maxScale = 1.10 end

  if db.colorNormal == nil then db.colorNormal = { 0.90, 0.95, 0.90 } end
  if db.colorSoon == nil then db.colorSoon = { 1.00, 0.85, 0.25 } end
  if db.colorNow == nil then db.colorNow = { 1.00, 0.35, 0.35 } end
  if db.soonThreshold == nil then db.soonThreshold = 5.0 end
  if db.nowThreshold == nil then db.nowThreshold = 2.0 end

  if db.updateInterval == nil then db.updateInterval = 0.08 end
  if db.maxTracked == nil then db.maxTracked = 400 end

  return db
end

local function LSM_Fetch(kind, key, fallback)
  if ETBC.LSM and ETBC.LSM.Fetch then
    local ok, v = pcall(ETBC.LSM.Fetch, ETBC.LSM, kind, key)
    if ok and v then return v end
  end
  return fallback
end

local function IsActionButtonOwner(owner)
  if not owner or not owner.GetName then return false end
  local n = owner:GetName() or ""
  if n:find("^ActionButton") then return true end
  if n:find("^MultiBar") then return true end
  if n:find("^BonusActionButton") then return true end
  if n:find("^PetActionButton") then return true end
  if n:find("^ShapeshiftButton") then return true end
  return false
end

local function IsAuraOwner(owner)
  if not owner or not owner.GetName then return false end
  local n = owner:GetName() or ""
  if n:find("^BuffButton") then return true end
  if n:find("^DebuffButton") then return true end
  if n:find("^TempEnchant") then return true end
  if n:find("^TargetFrameBuff") then return true end
  if n:find("^TargetFrameDebuff") then return true end
  if n:find("^FocusFrameBuff") then return true end
  if n:find("^FocusFrameDebuff") then return true end
  return false
end

local function ShouldHandleCooldown(cooldown)
  local db = GetDB()
  if not db.enabled then return false end
  if not cooldown or type(cooldown) ~= "table" then return false end
  if cooldown.IsForbidden and cooldown:IsForbidden() then return false end
  if cooldown.GetParent == nil then return false end

  local owner = cooldown:GetParent()
  if not owner or (owner.IsForbidden and owner:IsForbidden()) then return false end

  if IsActionButtonOwner(owner) then
    return db.actionButtons and true or false
  end

  if IsAuraOwner(owner) then
    return db.buffsDebuffs and true or false
  end

  return db.otherCooldownFrames and true or false
end

-- Hard default font (always exists in Classic/TBC clients)
local DEFAULT_FONT_PATH = "Fonts\\FRIZQT__.TTF"

local function ApplyFont(fs, owner)
  local db = GetDB()

  local fontPath = LSM_Fetch("font", db.font, DEFAULT_FONT_PATH)
  if type(fontPath) ~= "string" or fontPath == "" then
    fontPath = DEFAULT_FONT_PATH
  end

  local size = tonumber(db.size) or 16
  local outline = db.outline
  if outline == nil then outline = "" end

  if db.scaleByIcon and owner and owner.GetWidth then
    local w = owner:GetWidth() or 36
    local h = owner:GetHeight() or 36
    local base = math.min(w, h)
    local scale = base / 36
    local minS = tonumber(db.minScale) or 0.7
    local maxS = tonumber(db.maxScale) or 1.1
    if scale < minS then scale = minS end
    if scale > maxS then scale = maxS end
    size = math.floor(size * scale + 0.5)
    if size < 8 then size = 8 end
  end

  -- SetFont can fail if the path is bad; always fall back to FRIZQT__.TTF
  local ok = pcall(fs.SetFont, fs, fontPath, size, outline)
  if not ok then
    pcall(fs.SetFont, fs, DEFAULT_FONT_PATH, size, outline)
  end

  if db.shadow then
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.85)
  else
    fs:SetShadowOffset(0, 0)
  end
end

local function EnsureFS(owner)
  owner._etbc_cdtext = owner._etbc_cdtext or {}
  local st = owner._etbc_cdtext

  if st.fs and st.fs.SetText then
    -- Safety: if something nuked the font, re-apply a valid one before any SetText calls.
    local font = st.fs.GetFont and st.fs:GetFont()
    if not font then
      ApplyFont(st.fs, owner)
    end
    return st.fs
  end

  local fs = owner:CreateFontString(nil, "OVERLAY")
  fs:SetPoint("CENTER", owner, "CENTER", 0, 0)
  fs:SetJustifyH("CENTER")
  fs:SetJustifyV("MIDDLE")

  -- IMPORTANT: set a font BEFORE any SetText (prevents "Font not set" error)
  ApplyFont(fs, owner)

  -- Now it's safe
  fs:SetText("")
  fs:Hide()

  st.fs = fs
  return fs
end

local function FormatTime(remain)
  local db = GetDB()
  if remain <= 0 then return "" end

  if db.showTenths and remain <= (db.tenthsThreshold or 3.0) then
    return string.format("%.1f", remain)
  end

  local r
  if db.roundUp then
    r = math.ceil(remain)
  else
    r = math.floor(remain + 0.0001)
  end

  if r >= (db.mmssThreshold or 60) then
    local m = math.floor(r / 60)
    local s = r - (m * 60)
    return string.format("%d:%02d", m, s)
  end

  return tostring(r)
end

local function PickColor(remain)
  local db = GetDB()
  local nowT = db.nowThreshold or 2.0
  local soonT = db.soonThreshold or 5.0

  if remain <= nowT then
    local c = db.colorNow or { 1, 0.35, 0.35 }
    return c[1], c[2], c[3]
  end

  if remain <= soonT then
    local c = db.colorSoon or { 1, 0.85, 0.25 }
    return c[1], c[2], c[3]
  end

  local c = db.colorNormal or { 0.9, 0.95, 0.9 }
  return c[1], c[2], c[3]
end

local function IsProbablyGCD(duration)
  return duration and duration > 0 and duration <= 1.7
end

local function SetSwipe(cooldown, show)
  if not cooldown or not cooldown.SetDrawSwipe then return end
  pcall(cooldown.SetDrawSwipe, cooldown, show and true or false)
end

local function Track(cooldown, start, duration, enable, modRate)
  local db = GetDB()

  if not ShouldHandleCooldown(cooldown) then
    if tracked[cooldown] then
      local st = tracked[cooldown]
      if st and st.fs then st.fs:Hide() end
      SetSwipe(cooldown, true)
      tracked[cooldown] = nil
    end
    return
  end

  local owner = cooldown:GetParent()
  local fs = EnsureFS(owner)

  -- Apply again here to reflect DB changes and icon scaling in case owner size changed.
  ApplyFont(fs, owner)

  tracked[cooldown] = tracked[cooldown] or {}
  local st = tracked[cooldown]
  st.cooldown = cooldown
  st.owner = owner
  st.fs = fs
  st.start = tonumber(start) or 0
  st.duration = tonumber(duration) or 0
  st.enable = enable and true or false
  st.modRate = tonumber(modRate) or 1
  st.lastText = nil
  st.lastColorKey = nil

  SetSwipe(cooldown, db.showSwipe ~= false)
end

local function RebuildOrdered()
  wipe(ordered)
  local count = 0
  local maxT = GetDB().maxTracked or 400

  for cd, st in pairs(tracked) do
    if cd and st and st.owner and st.fs then
      count = count + 1
      if count <= maxT then
        ordered[count] = st
      else
        st.fs:Hide()
        SetSwipe(cd, true)
        tracked[cd] = nil
      end
    else
      SetSwipe(cd, true)
      tracked[cd] = nil
    end
  end
end

local function UpdateOne(st, now)
  local db = GetDB()
  local cd = st.cooldown
  local owner = st.owner
  local fs = st.fs

  if not cd or not owner or not fs then return false end
  if not owner:IsShown() then fs:Hide(); return true end

  -- Safety: if font got lost somehow, restore it before SetText
  local f = fs.GetFont and fs:GetFont()
  if not f then
    ApplyFont(fs, owner)
  end

  if db.hideWhenPaused and st.modRate and st.modRate == 0 then
    fs:Hide()
    return true
  end

  if not st.enable or st.start <= 0 or st.duration <= 0 then
    if db.hideWhenNoDuration then fs:Hide() end
    return true
  end

  if st.duration < (db.minDuration or 2.5) or st.duration > (db.maxDuration or 3600) then
    fs:Hide()
    return true
  end

  if db.hideWhenGCD and IsProbablyGCD(st.duration) then
    fs:Hide()
    return true
  end

  local remain = (st.start + st.duration) - now
  if remain <= 0 then
    fs:Hide()
    return true
  end

  local text = FormatTime(remain)
  if text == "" then
    fs:Hide()
    return true
  end

  if not fs:IsShown() then fs:Show() end

  if st.lastText ~= text then
    fs:SetText(text)
    st.lastText = text
  end

  local r, g, b = PickColor(remain)
  local key = (remain <= (db.nowThreshold or 2.0) and "now")
    or (remain <= (db.soonThreshold or 5.0) and "soon")
    or "norm"

  if st.lastColorKey ~= key then
    fs:SetTextColor(r, g, b)
    st.lastColorKey = key
  end

  return true
end

local elapsed = 0
local needRebuild = true

local function EnsureDriver()
  if driver then return end
  driver = CreateFrame("Frame", "EnhanceTBC_CooldownTextDriver", UIParent)
end

local function StartDriver()
  EnsureDriver()
  driver:SetScript("OnUpdate", function(_, dt)
    local db = GetDB()
    if not db.enabled then return end

    elapsed = elapsed + dt
    local interval = db.updateInterval or 0.08
    if elapsed < interval then return end
    elapsed = 0

    if needRebuild then
      RebuildOrdered()
      needRebuild = false
    end

    local now = GetTime()
    for i = 1, #ordered do
      UpdateOne(ordered[i], now)
    end
  end)
end

local function StopDriver()
  if not driver then return end
  driver:SetScript("OnUpdate", nil)
end

local function HookCooldownSetters()
  if hooked then return end
  hooked = true

  if type(_G.CooldownFrame_Set) == "function" then
    hooksecurefunc("CooldownFrame_Set", function(cooldown, start, duration, enable, forceShowDrawEdge, modRate)
      Track(cooldown, start, duration, enable, modRate)
      needRebuild = true
    end)
  end

  if type(_G.CooldownFrame_SetTimer) == "function" then
    hooksecurefunc("CooldownFrame_SetTimer", function(cooldown, start, duration, enable, modRate)
      Track(cooldown, start, duration, enable, modRate)
      needRebuild = true
    end)
  end

  if _G.Cooldown and _G.Cooldown.SetCooldown and not _G.Cooldown._etbcHooked then
    _G.Cooldown._etbcHooked = true
    hooksecurefunc(_G.Cooldown, "SetCooldown", function(cooldown, start, duration, enable, forceShowDrawEdge, modRate)
      Track(cooldown, start, duration, enable, modRate)
      needRebuild = true
    end)
  end
end

local function ClearAllText()
  for cd, st in pairs(tracked) do
    if st and st.fs then st.fs:Hide() end
    SetSwipe(cd, true)
    tracked[cd] = nil
  end
  wipe(ordered)
  needRebuild = true
end

local function Apply()
  local db = GetDB()
  local generalEnabled = ETBC.db.profile.general and ETBC.db.profile.general.enabled

  EnsureDriver()
  HookCooldownSetters()

  if not (generalEnabled and db.enabled) then
    ClearAllText()
    StopDriver()
    return
  end

  for _, st in pairs(tracked) do
    if st and st.fs and st.owner then
      ApplyFont(st.fs, st.owner)
    end
  end

  StartDriver()
  needRebuild = true
end

ETBC.ApplyBus:Register("cooldowns", Apply)
ETBC.ApplyBus:Register("general", Apply)

-- Modules/Mouse.lua
-- EnhanceTBC - CursorTrail-style cursor + trail (2D textures)

local ADDON_NAME, ETBC = ...
local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceTBC")
ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.Mouse = mod

local driver

local cursorFrame, cursorTex
local trailFrame
local trailPool, trailActive = {}, {}

local lastTrailX, lastTrailY
local lastSpawnT = 0
local lastCursorX, lastCursorY
local lastMoveAt = 0

local function Clamp01(x)
  x = tonumber(x) or 0
  if x < 0 then return 0 end
  if x > 1 then return 1 end
  return x
end

local function EnsureDriver()
  if driver then return end
  driver = CreateFrame("Frame", "EnhanceTBC_MouseDriver", UIParent)
end

local function InCombat()
  if InCombatLockdown and InCombatLockdown() then return true end
  if UnitAffectingCombat then return not not UnitAffectingCombat("player") end
  return false
end

local function MediaCursorPath(fileName)
  return "Interface\\AddOns\\EnhanceTBC\\Media\\Cursor\\" .. tostring(fileName or "")
end

local function ApplyBlend(tex, mode)
  if not tex or not tex.SetBlendMode then return end
  mode = tostring(mode or "ADD"):upper()
  if mode ~= "ADD" and mode ~= "BLEND" and mode ~= "MOD" then mode = "ADD" end
  tex:SetBlendMode(mode)
end

local function EnsureCursorFrame()
  if cursorFrame then return end
  cursorFrame = CreateFrame("Frame", "EnhanceTBC_CursorTrailCursor", UIParent)
  cursorFrame:SetFrameStrata("TOOLTIP")
  cursorFrame:SetSize(32, 32)
  cursorFrame:Hide()

  cursorTex = cursorFrame:CreateTexture(nil, "OVERLAY")
  cursorTex:SetAllPoints(cursorFrame)
  cursorTex:SetTexture("Interface\\Buttons\\WHITE8x8")
end

local function EnsureTrailFrame()
  if trailFrame then return end
  trailFrame = CreateFrame("Frame", "EnhanceTBC_CursorTrail2D", UIParent)
  trailFrame:SetFrameStrata("TOOLTIP")
  trailFrame:SetAllPoints(UIParent)
  trailFrame:Hide()
end

local function GetCursorXY()
  local x, y = GetCursorPosition()
  local s = UIParent:GetEffectiveScale()
  if not x or not y or not s or s == 0 then
    return 0, 0
  end
  return x / s, y / s
end

local function GetDB()
  ETBC.db.profile.mouse = ETBC.db.profile.mouse or {}
  local db = ETBC.db.profile.mouse

  if db.enabled == nil then db.enabled = true end

  if db.cursorEnabled == nil then db.cursorEnabled = true end
  if db.cursorTexture == nil then db.cursorTexture = "Glow.tga" end
  if db.cursorSize == nil then db.cursorSize = 32 end
  if db.cursorAlpha == nil then db.cursorAlpha = 0.9 end
  if db.cursorBlend == nil then db.cursorBlend = "ADD" end
  if db.cursorColor == nil then db.cursorColor = { 0.2, 1.0, 0.2 } end

  db.trail = db.trail or {}
  if db.trail.enabled == nil then db.trail.enabled = true end
  if db.trail.texture == nil then db.trail.texture = "Ring Soft 2.tga" end
  if db.trail.size == nil then db.trail.size = 24 end
  if db.trail.alpha == nil then db.trail.alpha = 0.5 end
  if db.trail.blend == nil then db.trail.blend = "ADD" end
  if db.trail.color == nil then db.trail.color = { 0.2, 1.0, 0.2 } end
  if db.trail.spacing == nil then db.trail.spacing = 16 end
  if db.trail.life == nil then db.trail.life = 0.25 end
  if db.trail.maxActive == nil then db.trail.maxActive = 30 end
  if db.trail.onlyInCombat == nil then db.trail.onlyInCombat = false end
  if db.trail.onlyWhenMoving == nil then db.trail.onlyWhenMoving = true end

  if db.hideWhenIdle == nil then db.hideWhenIdle = false end
  if db.idleDelay == nil then db.idleDelay = 1.0 end

  return db
end

local function AcquireTrail2D()
  local f = table.remove(trailPool)
  if f then
    f:SetScale(1)
    f:Show()
    return f
  end

  f = CreateFrame("Frame", nil, trailFrame)
  f:SetFrameStrata("TOOLTIP")
  f:SetSize(32, 32)
  local tx = f:CreateTexture(nil, "OVERLAY")
  tx:SetAllPoints(f)
  tx:SetTexture("Interface\\Buttons\\WHITE8x8")
  f._tex = tx
  f:Hide()
  return f
end

local function ReleaseTrail2D(f)
  if not f then return end
  f:Hide()
  f:ClearAllPoints()
  f:SetScale(1)
  f._birth, f._death, f._life = nil, nil, nil
  f._alpha0, f._scale0, f._scale1 = nil, nil, nil
  table.insert(trailPool, f)
end

local function ClearAll2DTrails()
  for i = #trailActive, 1, -1 do
    ReleaseTrail2D(trailActive[i])
    table.remove(trailActive, i)
  end
end

local function Spawn2DTrailAt(x, y, db)
  local tdb = db.trail
  if not tdb.enabled then return end
  if tdb.onlyInCombat and not InCombat() then return end

  local maxActive = tonumber(tdb.maxActive) or 30
  if #trailActive >= maxActive then
    ReleaseTrail2D(trailActive[1])
    table.remove(trailActive, 1)
  end

  local f = AcquireTrail2D()
  if not f or not f._tex then return end

  local size = tonumber(tdb.size) or 24
  f:SetSize(size, size)
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)

  f._tex:SetTexture(MediaCursorPath(tdb.texture))
  ApplyBlend(f._tex, tdb.blend)

  local c = tdb.color or { 0.2, 1.0, 0.2 }
  f._tex:SetVertexColor(c[1] or 1, c[2] or 1, c[3] or 1)
  f._tex:SetAlpha(Clamp01(tdb.alpha))

  local now = GetTime()
  local life = tonumber(tdb.life) or 0.25
  if life < 0.01 then life = 0.01 end

  f._birth = now
  f._death = now + life
  f._life = life
  f._alpha0 = Clamp01(tdb.alpha)
  f._scale0 = 1.00
  f._scale1 = 1.28

  f:Show()
  table.insert(trailActive, f)
end

local function Tick(elapsed)
  local db = GetDB()
  if not db.enabled then return end

  local wantCursor = db.cursorEnabled
  local wantTrail = db.trail.enabled

  if not wantCursor and not wantTrail and #trailActive == 0 then return end

  local x, y = GetCursorXY()
  local now = GetTime()

  local moved = (lastCursorX ~= x) or (lastCursorY ~= y)
  if moved then
    lastMoveAt = now
  end
  lastCursorX, lastCursorY = x, y

  local idle = db.hideWhenIdle and (now - (lastMoveAt or now)) >= (tonumber(db.idleDelay) or 1.0)

  if wantCursor and cursorFrame then
    if idle then
      cursorFrame:Hide()
    else
      cursorFrame:ClearAllPoints()
      cursorFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
      cursorFrame:Show()
    end
  elseif cursorFrame then
    cursorFrame:Hide()
  end

  if wantTrail and not idle then
    if db.trail.onlyWhenMoving then
      if lastTrailX and lastTrailY then
        local dx, dy = x - lastTrailX, y - lastTrailY
        local dist = (dx * dx + dy * dy) ^ 0.5
        local spacing = tonumber(db.trail.spacing) or 16
        if dist >= spacing then
          Spawn2DTrailAt(x, y, db)
          lastTrailX, lastTrailY = x, y
        end
      else
        lastTrailX, lastTrailY = x, y
      end
    else
      if now - lastSpawnT >= 0.03 then
        Spawn2DTrailAt(x, y, db)
        lastSpawnT = now
      end
    end
  end

  for i = #trailActive, 1, -1 do
    local f = trailActive[i]
    if not f or not f._tex then
      table.remove(trailActive, i)
    elseif not f._death or now >= f._death then
      ReleaseTrail2D(f)
      table.remove(trailActive, i)
    else
      local life = (f._life and f._life > 0) and f._life or 0.2
      local t = (now - (f._birth or now)) / life
      if t < 0 then t = 0 end
      if t > 1 then t = 1 end
      f._tex:SetAlpha((f._alpha0 or 0.5) * (1 - t))
      f:SetScale((f._scale0 or 1) + ((f._scale1 or 1.25) - (f._scale0 or 1)) * t)
    end
  end
end

local function EnableUpdates()
  EnsureDriver()
  EnsureCursorFrame()
  EnsureTrailFrame()

  if not driver._etbcTicking then
    driver._etbcTicking = true
    local lastT = GetTime()
    driver:SetScript("OnUpdate", function()
      local now = GetTime()
      local elapsed = now - lastT
      lastT = now
      Tick(elapsed)
    end)
  end
end

local function DisableUpdates()
  if driver then
    driver._etbcTicking = false
    driver:SetScript("OnUpdate", nil)
  end
end

local function ClearAll()
  if cursorFrame then cursorFrame:Hide() end
  if trailFrame then trailFrame:Hide() end
  ClearAll2DTrails()
  lastTrailX, lastTrailY = nil, nil
  lastCursorX, lastCursorY = nil, nil
end

local function Apply()
  if not ETBC.db or not ETBC.db.profile then return end

  local gEnabled = true
  if ETBC.db.profile.general and ETBC.db.profile.general.enabled ~= nil then
    gEnabled = not not ETBC.db.profile.general.enabled
  end

  local db = GetDB()
  if not (gEnabled and db.enabled) then
    ClearAll()
    DisableUpdates()
    return
  end

  EnsureCursorFrame()
  EnsureTrailFrame()

  if db.cursorEnabled then
    local size = tonumber(db.cursorSize) or 32
    cursorFrame:SetSize(size, size)
    cursorTex:SetTexture(MediaCursorPath(db.cursorTexture))

    local c = db.cursorColor or { 0.2, 1.0, 0.2 }
    cursorTex:SetVertexColor(c[1] or 1, c[2] or 1, c[3] or 1)
    cursorTex:SetAlpha(Clamp01(db.cursorAlpha))
    ApplyBlend(cursorTex, db.cursorBlend)
    cursorFrame:Show()
  else
    if cursorFrame then cursorFrame:Hide() end
  end

  if db.trail.enabled then
    trailFrame:Show()
  else
    if trailFrame then trailFrame:Hide() end
    ClearAll2DTrails()
  end

  local anyActive = db.cursorEnabled or db.trail.enabled
  if anyActive then EnableUpdates() else DisableUpdates() end
end

function mod:SetEnabled(v)
  local db = GetDB()
  db.enabled = not not v
  Apply()
end

function mod:Apply() Apply() end

if ETBC.ApplyBus and ETBC.ApplyBus.Register then
  ETBC.ApplyBus:Register("mouse", Apply)
  ETBC.ApplyBus:Register("general", Apply)
end

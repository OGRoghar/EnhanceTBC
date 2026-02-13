-- Modules/Mouse.lua
-- EnhanceTBC - Mouse enhancements
-- Features:
--  - Custom cursor texture overlay (uses Media\Cursor\*.tga)
--  - Continuous 2D cursor trails (pooled textures, lightweight)
-- Notes:
--  - Does NOT modify the real hardware cursor; it draws an overlay.
--  - Safe on Classic/TBC clients.

local ADDON_NAME, ETBC = ...

ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.Mouse = mod

local driver
local cursorFrame
local cursorTex

local trailFrame
local trailPool = {}
local trailActive = {}
local lastTrailX, lastTrailY
local lastSpawnT = 0

local function EnsureDriver()
  if driver then return end
  driver = CreateFrame("Frame", "EnhanceTBC_MouseDriver", UIParent)
end

local function GetDB()
  ETBC.db.profile.mouse = ETBC.db.profile.mouse or {}
  local db = ETBC.db.profile.mouse

  if db.enabled == nil then db.enabled = true end

  -- Cursor overlay
  db.cursor = db.cursor or {}
  if db.cursor.enabled == nil then db.cursor.enabled = false end
  if db.cursor.texture == nil then db.cursor.texture = "Glow.tga" end
  if db.cursor.size == nil then db.cursor.size = 34 end
  if db.cursor.alpha == nil then db.cursor.alpha = 0.95 end
  if db.cursor.color == nil then db.cursor.color = { 0.20, 1.00, 0.20 } end
  if db.cursor.blend == nil then db.cursor.blend = "ADD" end -- BLEND | ADD | MOD

  -- Trails
  db.trail = db.trail or {}
  if db.trail.enabled == nil then db.trail.enabled = false end
  if db.trail.texture == nil then db.trail.texture = "Ring Soft 2.tga" end
  if db.trail.size == nil then db.trail.size = 26 end
  if db.trail.alpha == nil then db.trail.alpha = 0.55 end
  if db.trail.color == nil then db.trail.color = { 0.20, 1.00, 0.20 } end
  if db.trail.blend == nil then db.trail.blend = "ADD" end
  if db.trail.spacing == nil then db.trail.spacing = 18 end -- pixels between spawns
  if db.trail.life == nil then db.trail.life = 0.22 end     -- seconds alive
  if db.trail.maxActive == nil then db.trail.maxActive = 32 end
  if db.trail.onlyInCombat == nil then db.trail.onlyInCombat = false end
  if db.trail.onlyWhenMoving == nil then db.trail.onlyWhenMoving = true end

  return db
end

local function InCombat()
  if InCombatLockdown and InCombatLockdown() then return true end
  if UnitAffectingCombat then return UnitAffectingCombat("player") and true or false end
  return false
end

local function MediaCursorPath(fileName)
  -- Your addon path + folder
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

  cursorFrame = CreateFrame("Frame", "EnhanceTBC_CursorOverlay", UIParent)
  cursorFrame:SetFrameStrata("TOOLTIP")
  cursorFrame:SetSize(64, 64)
  cursorFrame:Hide()

  cursorTex = cursorFrame:CreateTexture(nil, "OVERLAY")
  cursorTex:SetAllPoints(cursorFrame)
  cursorTex:SetTexture("Interface\\Buttons\\WHITE8x8")
end

local function EnsureTrailFrame()
  if trailFrame then return end
  trailFrame = CreateFrame("Frame", "EnhanceTBC_CursorTrail", UIParent)
  trailFrame:SetFrameStrata("TOOLTIP")
  trailFrame:SetAllPoints(UIParent)
  trailFrame:Hide()
end

local function AcquireTrail()
  local t = table.remove(trailPool)
  if t then
    t:Show()
    return t
  end

  local f = CreateFrame("Frame", nil, trailFrame)
  f:SetFrameStrata("TOOLTIP")
  f:SetSize(32, 32)

  local tx = f:CreateTexture(nil, "OVERLAY")
  tx:SetAllPoints(f)
  tx:SetTexture("Interface\\Buttons\\WHITE8x8")

  f._tex = tx
  f:Hide()
  return f
end

local function ReleaseTrail(f)
  if not f then return end
  f:Hide()
  f:ClearAllPoints()
  f._death = nil
  f._life = nil
  f._alpha0 = nil
  f._scale0 = nil
  f._scale1 = nil
  table.insert(trailPool, f)
end

local function ClearAllTrails()
  for i = #trailActive, 1, -1 do
    ReleaseTrail(trailActive[i])
    table.remove(trailActive, i)
  end
end

local function UpdateCursorPosition()
  if not cursorFrame then return end
  local x, y = GetCursorPosition()
  local s = UIParent:GetEffectiveScale()
  x, y = x / s, y / s
  cursorFrame:ClearAllPoints()
  cursorFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
  return x, y
end

local function SpawnTrailAt(x, y)
  local db = GetDB()
  local tdb = db.trail
  if not tdb.enabled then return end
  if tdb.onlyInCombat and not InCombat() then return end

  if #trailActive >= (tonumber(tdb.maxActive) or 32) then
    -- recycle oldest
    ReleaseTrail(trailActive[1])
    table.remove(trailActive, 1)
  end

  local f = AcquireTrail()
  f:SetSize(tonumber(tdb.size) or 26, tonumber(tdb.size) or 26)
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)

  local texPath = MediaCursorPath(tdb.texture)
  f._tex:SetTexture(texPath)
  ApplyBlend(f._tex, tdb.blend)

  local c = tdb.color or { 0.2, 1, 0.2 }
  local a = tonumber(tdb.alpha) or 0.55
  f._tex:SetVertexColor(c[1] or 1, c[2] or 1, c[3] or 1, a)

  local now = GetTime()
  local life = tonumber(tdb.life) or 0.22
  f._birth = now
  f._death = now + life
  f._life = life
  f._alpha0 = a
  f._scale0 = 1.00
  f._scale1 = 1.28

  f:Show()
  table.insert(trailActive, f)
end

local function TrailOnUpdate()
  local db = GetDB()
  local cdb = db.cursor
  local tdb = db.trail

  local x, y = nil, nil
  if cdb.enabled then
    x, y = UpdateCursorPosition()
  else
    x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    x, y = x / s, y / s
  end

  if tdb.enabled then
    -- Decide whether to spawn based on distance moved
    if tdb.onlyWhenMoving then
      if lastTrailX and lastTrailY then
        local dx, dy = x - lastTrailX, y - lastTrailY
        local dist = math.sqrt(dx * dx + dy * dy)
        local spacing = tonumber(tdb.spacing) or 18
        if dist >= spacing then
          SpawnTrailAt(x, y)
          lastTrailX, lastTrailY = x, y
        end
      else
        lastTrailX, lastTrailY = x, y
      end
    else
      -- spawn at a controlled rate if not movement gated
      local now = GetTime()
      if now - lastSpawnT >= 0.03 then
        SpawnTrailAt(x, y)
        lastSpawnT = now
      end
    end
  end

  -- fade active trails
  local now = GetTime()
  for i = #trailActive, 1, -1 do
    local f = trailActive[i]
    if not f._death or now >= f._death then
      ReleaseTrail(f)
      table.remove(trailActive, i)
    else
      local t = (now - f._birth) / (f._life > 0 and f._life or 0.2)
      if t < 0 then t = 0 end
      if t > 1 then t = 1 end

      local alpha = (f._alpha0 or 0.5) * (1 - t)
      f._tex:SetAlpha(alpha)

      local sc = (f._scale0 or 1) + ((f._scale1 or 1.25) - (f._scale0 or 1)) * t
      f:SetScale(sc)
    end
  end
end

local function EnableUpdates()
  EnsureDriver()
  EnsureCursorFrame()
  EnsureTrailFrame()

  if not driver._etbcTicking then
    driver._etbcTicking = true
    driver:SetScript("OnUpdate", function()
      -- Fast, but minimal work. No allocations.
      TrailOnUpdate()
    end)
  end
end

local function DisableUpdates()
  if driver then
    driver._etbcTicking = false
    driver:SetScript("OnUpdate", nil)
  end
end

local function Apply()
  if not ETBC.db or not ETBC.db.profile then return end
  local gEnabled = true
  if ETBC.db.profile.general and ETBC.db.profile.general.enabled ~= nil then
    gEnabled = ETBC.db.profile.general.enabled and true or false
  end

  local db = GetDB()
  if not (gEnabled and db.enabled) then
    if cursorFrame then cursorFrame:Hide() end
    if trailFrame then trailFrame:Hide() end
    ClearAllTrails()
    DisableUpdates()
    return
  end

  EnsureCursorFrame()
  EnsureTrailFrame()

  -- Cursor overlay
  if db.cursor.enabled then
    cursorFrame:SetSize(tonumber(db.cursor.size) or 34, tonumber(db.cursor.size) or 34)
    cursorTex:SetTexture(MediaCursorPath(db.cursor.texture))

    local c = db.cursor.color or { 0.2, 1, 0.2 }
    cursorTex:SetVertexColor(c[1] or 1, c[2] or 1, c[3] or 1, tonumber(db.cursor.alpha) or 0.95)
    ApplyBlend(cursorTex, db.cursor.blend)

    cursorFrame:Show()
  else
    cursorFrame:Hide()
  end

  -- Trails
  if db.trail.enabled then
    trailFrame:Show()
  else
    trailFrame:Hide()
    ClearAllTrails()
  end

  -- Updates only needed if either cursor overlay or trails enabled
  if db.cursor.enabled or db.trail.enabled then
    EnableUpdates()
  else
    DisableUpdates()
  end
end

-- Public helpers (used by options)
function mod:SetEnabled(v)
  local db = GetDB()
  db.enabled = v and true or false
  Apply()
end

function mod:Apply() Apply() end

-- Hook into ApplyBus
ETBC.ApplyBus:Register("mouse", Apply)
ETBC.ApplyBus:Register("general", Apply)

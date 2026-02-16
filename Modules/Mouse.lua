-- Modules/Mouse.lua
-- EnhanceTBC - Mouse enhancements
-- 2D cursor overlay + 2D trail
-- 3D spell model cursor + 3D spell model trail (uses GAME internal spell model paths)
--
-- IMPORTANT:
-- PlayerModel:SetModel() cannot load .m2 from your addon folder.
-- It only loads models shipped in the game client. So we probe multiple candidate paths per spell.

local ADDON_NAME, ETBC = ...

ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.Mouse = mod

local driver

-- 2D cursor overlay
local cursorFrame, cursorTex

-- 2D trails (textures)
local trailFrame
local trailPool, trailActive = {}, {}
local lastTrailX, lastTrailY
local lastSpawnT = 0

-- 3D model (single)
local cursorModel
local lastCursorModelPath
local cursorModelFacingRad = 0

-- 3D model TRAIL (pooled)
local modelTrailFrame
local modelTrailPool, modelTrailActive = {}, {}
local lastModelTrailX, lastModelTrailY
local lastModelTrailSpawnT = 0

local function Print(msg)
  if ETBC and ETBC.Print then
    ETBC:Print(msg)
  elseif DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99EnhanceTBC|r " .. tostring(msg))
  end
end

local function Clamp01(x)
  x = tonumber(x) or 0
  if x < 0 then return 0 end
  if x > 1 then return 1 end
  return x
end

local function DegToRad(d) return (tonumber(d) or 0) * (math.pi / 180) end

local function EnsureDriver()
  if driver then return end
  driver = CreateFrame("Frame", "EnhanceTBC_MouseDriver", UIParent)
end

local function InCombat()
  if InCombatLockdown and InCombatLockdown() then return true end
  if UnitAffectingCombat then return UnitAffectingCombat("player") and true or false end
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

-- Candidate lists per spell. Your build may not have some of these.
-- We probe until one works, then cache it in db._resolvedSpellPaths[spellKey].
local SPELL_MODEL_CANDIDATES = {
  Fireball = {
    "spells\\fireball_missile.m2",
    "spells\\fireball_missile_low.m2",
    "spells\\fireball_precast_hand.m2",
    "spells\\fireball_precast_high_hand.m2",
    "spells\\fireball_precast_high_base.m2",
    "spells\\firestrike_missile_low.m2",
    "spells\\firestrike_missile.m2",
  },
  LightningBolt = {
    "spells\\lightningbolt_missile.m2",
    "spells\\lightningboltivus_missile.m2",
    "spells\\lightning_precast_low_hand.m2",
    "spells\\lightning_precast_high_hand.m2",
    "spells\\lightningbolt_missile_low.m2",
  },
  ShadowBolt = {
    "spells\\shadowbolt_missile.m2",
    "spells\\shadowbolt_missile_low.m2",
    "spells\\shadowbolt_precast_hand.m2",
    "spells\\shadowbolt_precast_low_hand.m2",
  },
  Holy = {
    "spells\\holy_precast_uber_hand.m2",
    "spells\\holy_precast_high_hand.m2",
    "spells\\holy_precast_low_hand.m2",
    "spells\\holy_precast_uber_base.m2",
    "spells\\holy_precast_high_base.m2",
    "spells\\holy_precast_low_base.m2",
  },
}

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
  trailFrame = CreateFrame("Frame", "EnhanceTBC_CursorTrail2D", UIParent)
  trailFrame:SetFrameStrata("TOOLTIP")
  trailFrame:SetAllPoints(UIParent)
  trailFrame:Hide()
end

local function EnsureCursorModel()
  if cursorModel then return end
  cursorModel = CreateFrame("PlayerModel", "EnhanceTBC_CursorSpellModel", UIParent)
  cursorModel:SetFrameStrata("TOOLTIP")
  cursorModel:SetSize(96, 96)
  cursorModel:Hide()
end

local function EnsureModelTrailFrame()
  if modelTrailFrame then return end
  modelTrailFrame = CreateFrame("Frame", "EnhanceTBC_CursorModelTrail", UIParent)
  modelTrailFrame:SetFrameStrata("TOOLTIP")
  modelTrailFrame:SetAllPoints(UIParent)
  modelTrailFrame:Hide()
end

local function GetCursorXY()
  local x, y = GetCursorPosition()
  local s = UIParent:GetEffectiveScale()
  if not x or not y or not s or s == 0 then
    return 0, 0
  end
  return x / s, y / s
end

local function ApplyModelScale(pm, scale)
  scale = tonumber(scale) or 0.02
  if pm.SetModelScale then
    pm:SetModelScale(scale)
  else
    pm:SetScale(scale)
  end
end

-- Camera tuning to reduce "boxy" look by fitting the effect better in-frame.
local function ApplyModelCamera(pm, camDistance, portraitZoom, posZ)
  if not pm then return end

  camDistance = tonumber(camDistance) or 1.0
  if pm.SetCamDistanceScale then
    if camDistance < 0.1 then camDistance = 0.1 end
    if camDistance > 3.0 then camDistance = 3.0 end
    pm:SetCamDistanceScale(camDistance)
  end

  portraitZoom = tonumber(portraitZoom) or 0
  if pm.SetPortraitZoom then
    if portraitZoom < 0 then portraitZoom = 0 end
    if portraitZoom > 1 then portraitZoom = 1 end
    pm:SetPortraitZoom(portraitZoom)
  end

  posZ = tonumber(posZ) or 0
  if pm.SetPosition then
    pm:SetPosition(0, 0, posZ)
  end
end

local function SafeSetModel(pm, path, db)
  local ok, err = pcall(function()
    pm:ClearModel()
    pm:SetModel(path)
  end)
  if not ok and db and db.debugModels then
    Print("Mouse model load failed: " .. tostring(path) .. " (" .. tostring(err) .. ")")
  end
  return ok and true or false
end

local function GetDB()
  ETBC.db.profile.mouse = ETBC.db.profile.mouse or {}
  local db = ETBC.db.profile.mouse

  if db.enabled == nil then db.enabled = true end
  if db.effectType == nil then db.effectType = "texture" end -- texture|model|both
  if db.debugModels == nil then db.debugModels = false end
  if db.spellKey == nil then db.spellKey = "LightningBolt" end

  db._resolvedSpellPaths = db._resolvedSpellPaths or {}

  -- model cursor
  db.model = db.model or {}
  if db.model.enabled == nil then db.model.enabled = false end
  if db.model.size == nil then db.model.size = 96 end
  if db.model.alpha == nil then db.model.alpha = 1.0 end
  if db.model.scale == nil then db.model.scale = 0.02 end
  if db.model.facing == nil then db.model.facing = 0 end
  if db.model.spin == nil then db.model.spin = 0 end
  if db.model.offsetX == nil then db.model.offsetX = 0 end
  if db.model.offsetY == nil then db.model.offsetY = 0 end
  if db.model.onlyInCombat == nil then db.model.onlyInCombat = false end

  if db.model.camDistance == nil then db.model.camDistance = 1.0 end
  if db.model.portraitZoom == nil then db.model.portraitZoom = 0 end
  if db.model.posZ == nil then db.model.posZ = 0 end

  -- model trail
  db.modelTrail = db.modelTrail or {}
  if db.modelTrail.enabled == nil then db.modelTrail.enabled = false end
  if db.modelTrail.size == nil then db.modelTrail.size = 72 end
  if db.modelTrail.alpha == nil then db.modelTrail.alpha = 0.95 end
  if db.modelTrail.scale == nil then db.modelTrail.scale = 0.02 end
  if db.modelTrail.spacing == nil then db.modelTrail.spacing = 20 end
  if db.modelTrail.life == nil then db.modelTrail.life = 0.30 end
  if db.modelTrail.maxActive == nil then db.modelTrail.maxActive = 12 end
  if db.modelTrail.onlyInCombat == nil then db.modelTrail.onlyInCombat = false end
  if db.modelTrail.onlyWhenMoving == nil then db.modelTrail.onlyWhenMoving = true end
  if db.modelTrail.spin == nil then db.modelTrail.spin = 0 end
  if db.modelTrail.facing == nil then db.modelTrail.facing = 0 end

  if db.modelTrail.camDistance == nil then db.modelTrail.camDistance = 1.0 end
  if db.modelTrail.portraitZoom == nil then db.modelTrail.portraitZoom = 0 end
  if db.modelTrail.posZ == nil then db.modelTrail.posZ = 0 end

  -- 2D overlay
  db.cursor = db.cursor or {}
  if db.cursor.enabled == nil then db.cursor.enabled = false end
  if db.cursor.texture == nil then db.cursor.texture = "Glow.tga" end
  if db.cursor.size == nil then db.cursor.size = 34 end
  if db.cursor.alpha == nil then db.cursor.alpha = 0.95 end
  if db.cursor.color == nil then db.cursor.color = { 0.20, 1.00, 0.20 } end
  if db.cursor.blend == nil then db.cursor.blend = "ADD" end

  -- 2D trails
  db.trail = db.trail or {}
  if db.trail.enabled == nil then db.trail.enabled = false end
  if db.trail.texture == nil then db.trail.texture = "Ring Soft 2.tga" end
  if db.trail.size == nil then db.trail.size = 26 end
  if db.trail.alpha == nil then db.trail.alpha = 0.55 end
  if db.trail.color == nil then db.trail.color = { 0.20, 1.00, 0.20 } end
  if db.trail.blend == nil then db.trail.blend = "ADD" end
  if db.trail.spacing == nil then db.trail.spacing = 18 end
  if db.trail.life == nil then db.trail.life = 0.22 end
  if db.trail.maxActive == nil then db.trail.maxActive = 32 end
  if db.trail.onlyInCombat == nil then db.trail.onlyInCombat = false end
  if db.trail.onlyWhenMoving == nil then db.trail.onlyWhenMoving = true end

  return db
end

local function ResolveSpellModelPath(db)
  local key = tostring(db.spellKey or "LightningBolt")
  db._resolvedSpellPaths = db._resolvedSpellPaths or {}

  local cached = db._resolvedSpellPaths[key]
  if type(cached) == "string" and cached ~= "" then
    return cached
  end

  local list = SPELL_MODEL_CANDIDATES[key] or SPELL_MODEL_CANDIDATES.LightningBolt or {}
  if #list == 0 then return nil end

  EnsureCursorModel()
  if not cursorModel then return nil end

  for i = 1, #list do
    local path = list[i]
    if SafeSetModel(cursorModel, path, db) then
      db._resolvedSpellPaths[key] = path
      if db.debugModels then
        Print("Mouse model resolved for " .. key .. ": " .. path)
      end
      return path
    end
  end

  db._resolvedSpellPaths[key] = nil
  if db.debugModels then
    Print("No valid model found for " .. key .. " (all candidates failed).")
  end
  return nil
end

-- 2D trail pool
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

-- 3D model trail pool
local function AcquireModelTrail()
  local pm = table.remove(modelTrailPool)
  if pm then
    pm:Show()
    return pm
  end
  pm = CreateFrame("PlayerModel", nil, modelTrailFrame)
  pm:SetFrameStrata("TOOLTIP")
  pm:SetSize(72, 72)
  pm:Hide()
  pm._path = nil
  return pm
end

local function ReleaseModelTrail(pm)
  if not pm then return end
  pm:Hide()
  pm:ClearAllPoints()
  pm:SetAlpha(1)
  pm._birth, pm._death, pm._life = nil, nil, nil
  pm._alpha0, pm._facing0, pm._spinRad = nil, nil, nil
  pm._path = nil
  table.insert(modelTrailPool, pm)
end

local function ClearAllModelTrails()
  for i = #modelTrailActive, 1, -1 do
    ReleaseModelTrail(modelTrailActive[i])
    table.remove(modelTrailActive, i)
  end
end

-- spawn 2D trail
local function Spawn2DTrailAt(x, y, db)
  local tdb = db.trail
  if not tdb.enabled then return end
  if tdb.onlyInCombat and not InCombat() then return end

  local maxActive = tonumber(tdb.maxActive) or 32
  if #trailActive >= maxActive then
    ReleaseTrail2D(trailActive[1])
    table.remove(trailActive, 1)
  end

  local f = AcquireTrail2D()
  local size = tonumber(tdb.size) or 26
  f:SetSize(size, size)
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)

  f._tex:SetTexture(MediaCursorPath(tdb.texture))
  ApplyBlend(f._tex, tdb.blend)

  local c = tdb.color or { 0.2, 1, 0.2 }
  f._tex:SetVertexColor(c[1] or 1, c[2] or 1, c[3] or 1)
  f._tex:SetAlpha(Clamp01(tdb.alpha))

  local now = GetTime()
  local life = tonumber(tdb.life) or 0.22
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

-- spawn 3D model trail
local function SpawnModelTrailAt(x, y, db)
  local mtdb = db.modelTrail
  if not mtdb.enabled then return end
  if mtdb.onlyInCombat and not InCombat() then return end

  local path = ResolveSpellModelPath(db)
  if not path or path == "" then return end

  local maxActive = tonumber(mtdb.maxActive) or 12
  if maxActive < 1 then maxActive = 1 end
  if #modelTrailActive >= maxActive then
    ReleaseModelTrail(modelTrailActive[1])
    table.remove(modelTrailActive, 1)
  end

  local pm = AcquireModelTrail()
  local size = tonumber(mtdb.size) or 72
  pm:SetSize(size, size)
  pm:SetAlpha(Clamp01(mtdb.alpha))

  if pm._path ~= path then
    if not SafeSetModel(pm, path, db) then
      ReleaseModelTrail(pm)
      return
    end
    pm._path = path
  end

  ApplyModelScale(pm, mtdb.scale)
  ApplyModelCamera(pm, mtdb.camDistance, mtdb.portraitZoom, mtdb.posZ)

  pm:ClearAllPoints()
  pm:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)

  local now = GetTime()
  local life = tonumber(mtdb.life) or 0.30
  if life < 0.01 then life = 0.01 end

  pm._birth = now
  pm._death = now + life
  pm._life = life
  pm._alpha0 = Clamp01(mtdb.alpha)
  pm._facing0 = DegToRad(mtdb.facing or 0)
  pm._spinRad = DegToRad(mtdb.spin or 0)

  if pm.SetFacing then pm:SetFacing(pm._facing0) end
  pm:Show()
  table.insert(modelTrailActive, pm)
end

local function Tick(elapsed)
  local db = GetDB()

  local effectType = tostring(db.effectType or "texture")
  local wantTexture = (effectType == "texture" or effectType == "both")
  local wantModel = (effectType == "model" or effectType == "both")

  local x, y = GetCursorXY()

  -- 2D cursor overlay follow
  if wantTexture and db.cursor.enabled and cursorFrame then
    cursorFrame:ClearAllPoints()
    cursorFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
  end

  -- single 3D cursor model only if modelTrail disabled
  if wantModel and db.model.enabled and not db.modelTrail.enabled and cursorModel then
    if db.model.onlyInCombat and not InCombat() then
      cursorModel:Hide()
    else
      local mx = x + (tonumber(db.model.offsetX) or 0)
      local my = y + (tonumber(db.model.offsetY) or 0)
      cursorModel:ClearAllPoints()
      cursorModel:SetPoint("CENTER", UIParent, "BOTTOMLEFT", mx, my)

      local path = ResolveSpellModelPath(db)
      if path and path ~= "" and path ~= (lastCursorModelPath or "") then
        lastCursorModelPath = path
        if not SafeSetModel(cursorModel, path, db) then
          cursorModel:Hide()
          return
        end
      end

      cursorModel:SetSize(tonumber(db.model.size) or 96, tonumber(db.model.size) or 96)
      cursorModel:SetAlpha(Clamp01(db.model.alpha))
      ApplyModelScale(cursorModel, db.model.scale)
      ApplyModelCamera(cursorModel, db.model.camDistance, db.model.portraitZoom, db.model.posZ)

      cursorModelFacingRad = DegToRad(db.model.facing or 0)
      local spinDeg = tonumber(db.model.spin) or 0
      if spinDeg ~= 0 then
        cursorModelFacingRad = cursorModelFacingRad + DegToRad(spinDeg) * (elapsed or 0)
      end
      if cursorModel.SetFacing then cursorModel:SetFacing(cursorModelFacingRad) end
      cursorModel:Show()
    end
  elseif cursorModel then
    cursorModel:Hide()
  end

  -- 2D trails
  if wantTexture and db.trail.enabled then
    if db.trail.onlyWhenMoving then
      if lastTrailX and lastTrailY then
        local dx, dy = x - lastTrailX, y - lastTrailY
        local dist = (dx * dx + dy * dy) ^ 0.5
        local spacing = tonumber(db.trail.spacing) or 18
        if dist >= spacing then
          Spawn2DTrailAt(x, y, db)
          lastTrailX, lastTrailY = x, y
        end
      else
        lastTrailX, lastTrailY = x, y
      end
    else
      local now = GetTime()
      if now - lastSpawnT >= 0.03 then
        Spawn2DTrailAt(x, y, db)
        lastSpawnT = now
      end
    end
  end

  -- 3D model trails
  if wantModel and db.modelTrail.enabled then
    local now = GetTime()
    local mtdb = db.modelTrail
    local spacing = tonumber(mtdb.spacing) or 20
    if spacing < 2 then spacing = 2 end
    local minInterval = 0.08

    if mtdb.onlyWhenMoving then
      if lastModelTrailX and lastModelTrailY then
        local dx, dy = x - lastModelTrailX, y - lastModelTrailY
        local dist = (dx * dx + dy * dy) ^ 0.5
        local isMoving = dist > 0.5

        if dist >= spacing or (isMoving and (now - lastModelTrailSpawnT) >= minInterval) then
          SpawnModelTrailAt(x, y, db)
          lastModelTrailX, lastModelTrailY = x, y
          lastModelTrailSpawnT = now
        end
      else
        lastModelTrailX, lastModelTrailY = x, y
        lastModelTrailSpawnT = now
      end
    else
      if now - lastModelTrailSpawnT >= 0.05 then
        SpawnModelTrailAt(x, y, db)
        lastModelTrailSpawnT = now
      end
    end
  end

  -- fade 2D trails
  local now2 = GetTime()
  for i = #trailActive, 1, -1 do
    local f = trailActive[i]
    if not f._death or now2 >= f._death then
      ReleaseTrail2D(f)
      table.remove(trailActive, i)
    else
      local life = (f._life and f._life > 0) and f._life or 0.2
      local t = (now2 - (f._birth or now2)) / life
      if t < 0 then t = 0 end
      if t > 1 then t = 1 end
      f._tex:SetAlpha((f._alpha0 or 0.5) * (1 - t))
      f:SetScale((f._scale0 or 1) + ((f._scale1 or 1.25) - (f._scale0 or 1)) * t)
    end
  end

  -- fade 3D model trails
  for i = #modelTrailActive, 1, -1 do
    local pm = modelTrailActive[i]
    if not pm._death or now2 >= pm._death then
      ReleaseModelTrail(pm)
      table.remove(modelTrailActive, i)
    else
      local life = (pm._life and pm._life > 0) and pm._life or 0.25
      local t = (now2 - (pm._birth or now2)) / life
      if t < 0 then t = 0 end
      if t > 1 then t = 1 end

      pm:SetAlpha((pm._alpha0 or 0.9) * (1 - t))

      if pm.SetFacing and pm._spinRad and pm._facing0 then
        pm:SetFacing(pm._facing0 + pm._spinRad * (now2 - (pm._birth or now2)))
      end
    end
  end
end

local function EnableUpdates()
  EnsureDriver()
  EnsureCursorFrame()
  EnsureTrailFrame()
  EnsureCursorModel()
  EnsureModelTrailFrame()

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
  if cursorModel then cursorModel:Hide() end
  if cursorFrame then cursorFrame:Hide() end
  if trailFrame then trailFrame:Hide() end
  if modelTrailFrame then modelTrailFrame:Hide() end
  ClearAll2DTrails()
  ClearAllModelTrails()
  lastTrailX, lastTrailY = nil, nil
  lastModelTrailX, lastModelTrailY = nil, nil
end

local function Apply()
  if not ETBC.db or not ETBC.db.profile then return end

  local gEnabled = true
  if ETBC.db.profile.general and ETBC.db.profile.general.enabled ~= nil then
    gEnabled = ETBC.db.profile.general.enabled and true or false
  end

  local db = GetDB()
  if not (gEnabled and db.enabled) then
    ClearAll()
    DisableUpdates()
    return
  end

  EnsureCursorFrame()
  EnsureTrailFrame()
  EnsureCursorModel()
  EnsureModelTrailFrame()

  local effectType = tostring(db.effectType or "texture")
  local wantTexture = (effectType == "texture" or effectType == "both")
  local wantModel = (effectType == "model" or effectType == "both")

  -- 2D cursor overlay setup
  if wantTexture and db.cursor.enabled then
    local size = tonumber(db.cursor.size) or 34
    cursorFrame:SetSize(size, size)
    cursorTex:SetTexture(MediaCursorPath(db.cursor.texture))

    local c = db.cursor.color or { 0.2, 1, 0.2 }
    cursorTex:SetVertexColor(c[1] or 1, c[2] or 1, c[3] or 1)
    cursorTex:SetAlpha(Clamp01(db.cursor.alpha))
    ApplyBlend(cursorTex, db.cursor.blend)

    cursorFrame:Show()
  else
    if cursorFrame then cursorFrame:Hide() end
  end

  -- 2D trails frame
  if wantTexture and db.trail.enabled then
    trailFrame:Show()
  else
    if trailFrame then trailFrame:Hide() end
    ClearAll2DTrails()
  end

  -- 3D model trail frame
  if wantModel and db.modelTrail.enabled then
    modelTrailFrame:Show()
  else
    if modelTrailFrame then modelTrailFrame:Hide() end
    ClearAllModelTrails()
  end

  -- single cursor model only if trail disabled
  if wantModel and db.model.enabled and not db.modelTrail.enabled then
    cursorModel:Show()
  else
    cursorModel:Hide()
  end

  local anyActive =
    (wantTexture and (db.cursor.enabled or db.trail.enabled)) or
    (wantModel and (db.model.enabled or db.modelTrail.enabled))

  if anyActive then EnableUpdates() else DisableUpdates() end
end

function mod:SetEnabled(v)
  local db = GetDB()
  db.enabled = v and true or false
  Apply()
end

function mod:Apply() Apply() end

if ETBC.ApplyBus and ETBC.ApplyBus.Register then
  ETBC.ApplyBus:Register("mouse", Apply)
  ETBC.ApplyBus:Register("general", Apply)
end

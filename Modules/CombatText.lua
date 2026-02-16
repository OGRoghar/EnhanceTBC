-- Modules/CombatText.lua
local ADDON_NAME, ETBC = ...

ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.CombatText = mod

local LSM = ETBC.media

local driver
local anchor

local pool = {}
local active = {}

local batch = {}
local batchExpires = 0
local updateRunning = false

-- Blizzard Floating Combat Text CVars (to prevent double text)
local FCT_CVARS = {
  "floatingCombatTextCombatDamage",
  "floatingCombatTextCombatHealing",
  "floatingCombatTextCombatState",
  "floatingCombatTextCombatLogPeriodicSpells",
  "floatingCombatTextCombatLogPeriodicAuras",
  "floatingCombatTextCombatHonorGains",
  "floatingCombatTextCombatDamageStyle",
  "floatingCombatTextCombatCriticals",
}

local function SafeGetCVar(name)
  local ok, v = pcall(GetCVar, name)
  if ok then return v end
  return nil
end

local function SafeSetCVar(name, value)
  pcall(SetCVar, name, tostring(value))
end

local function SaveBlizzardFCT(db)
  if db.blizzard._saved then return end
  local snap = {}
  for i = 1, #FCT_CVARS do
    local k = FCT_CVARS[i]
    snap[k] = SafeGetCVar(k)
  end
  db.blizzard._saved = snap
end

local function DisableBlizzardFCT(db)
  SaveBlizzardFCT(db)
  for i = 1, #FCT_CVARS do
    SafeSetCVar(FCT_CVARS[i], "0")
  end
end

local function RestoreBlizzardFCT(db)
  local snap = db.blizzard._saved
  if not snap then return end
  for i = 1, #FCT_CVARS do
    local k = FCT_CVARS[i]
    local v = snap[k]
    if v ~= nil then
      SafeSetCVar(k, v)
    end
  end
  db.blizzard._saved = nil
end

-- ---------- visuals helpers

local function SafeFont(face)
  face = face or "Friz Quadrata TT"
  if LSM and LSM.Fetch then
    local f = LSM:Fetch(ETBC.LSM_FONTS, face, true)
    return f or STANDARD_TEXT_FONT
  end
  return STANDARD_TEXT_FONT
end

local function OutlineFlag(outline)
  if outline == "OUTLINE" then return "OUTLINE" end
  if outline == "THICKOUTLINE" then return "THICKOUTLINE" end
  if outline == "MONOCHROMEOUTLINE" then return "MONOCHROME,OUTLINE" end
  return ""
end

local function GetClassColor()
  local _, class = UnitClass("player")
  if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
    local c = RAID_CLASS_COLORS[class]
    return c.r, c.g, c.b, 1
  end
  return 1, 1, 1, 1
end

local SCHOOL_COLORS = {
  [1]   = { 1.00, 1.00, 0.20 }, -- Physical
  [2]   = { 1.00, 0.90, 0.20 }, -- Holy
  [4]   = { 1.00, 0.30, 0.30 }, -- Fire
  [8]   = { 0.30, 1.00, 0.30 }, -- Nature
  [16]  = { 0.50, 1.00, 1.00 }, -- Frost
  [32]  = { 0.65, 0.50, 1.00 }, -- Shadow
  [64]  = { 1.00, 0.50, 1.00 }, -- Arcane
}

local function SchoolColor(mask)
  if type(mask) ~= "number" then return nil end
  local bits = { 1,2,4,8,16,32,64 }
  for i = 1, #bits do
    local b = bits[i]
    if bit.band(mask, b) ~= 0 then
      return SCHOOL_COLORS[b]
    end
  end
  return nil
end

local function EnsureFrames()
  if not driver then
    driver = CreateFrame("Frame", "EnhanceTBC_CombatTextDriver", UIParent)
    driver:Hide()
  end
  if not anchor then
    anchor = CreateFrame("Frame", "EnhanceTBC_CombatTextAnchor", UIParent)
    anchor:SetSize(1, 1)
  end
end

local function AcquireFS()
  local fs = table.remove(pool)
  if fs then
    fs:Show()
    return fs
  end
  fs = UIParent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE") -- prevents Font not set
  fs:SetText("")
  fs:SetShadowColor(0, 0, 0, 0.85)
  fs:SetShadowOffset(1, -1)
  fs:SetJustifyH("CENTER")
  fs:SetJustifyV("MIDDLE")
  return fs
end

local function ReleaseFS(fs)
  if not fs then return end
  fs:Hide()
  fs:SetParent(UIParent)
  fs:ClearAllPoints()
  fs:SetAlpha(1)
  fs:SetText("")
  fs._etbc = nil
  pool[#pool+1] = fs
end

local function ClearAll()
  for i = #active, 1, -1 do
    ReleaseFS(active[i])
    active[i] = nil
  end
end

local function ApplyFont(fs, db, isCrit)
  local font = SafeFont(db.font)
  local flags = OutlineFlag(db.outline)

  local size = tonumber(db.size) or 18
  if isCrit and db.crit and db.crit.enabled then
    local scale = tonumber(db.crit.scale) or 1.25
    size = math.floor(size * scale + 0.5)
  end

  fs:SetFont(font, size, flags)

  if db.shadow then
    fs:SetShadowColor(0, 0, 0, 0.85)
    fs:SetShadowOffset(1, -1)
  else
    fs:SetShadowColor(0, 0, 0, 0)
    fs:SetShadowOffset(0, 0)
  end
end

local function ClampLines(maxLines)
  while #active > maxLines do
    ReleaseFS(active[#active])
    active[#active] = nil
  end
end

local function ColorFor(db, kind, isCrit, schoolMask)
  if db.classColor then
    return GetClassColor()
  end

  if isCrit and db.crit and db.crit.enabled and db.crit.useCritColor then
    local c = db.crit.color or { r=1, g=0.8, b=0.2, a=1 }
    return c.r, c.g, c.b, (c.a or 1)
  end

  if db.useSchoolColors and schoolMask then
    local s = SchoolColor(schoolMask)
    if s then return s[1], s[2], s[3], 1 end
  end

  if db.useDamageColors then
    if kind == "DAMAGE" then return 1.0, 0.25, 0.25, 1 end
    if kind == "HEAL" then return 0.25, 1.0, 0.35, 1 end
    if kind == "MISS" then return 0.75, 0.75, 0.75, 1 end
    if kind == "INTERRUPT" then return 1.0, 0.9, 0.2, 1 end
    if kind == "DISPEL" then return 0.65, 0.85, 1.0, 1 end
  end

  local c = db.overrideColor or { r=0.2, g=1.0, b=0.2, a=1.0 }
  return c.r, c.g, c.b, (c.a or 1)
end

local function PushLine(db, text, kind, isCrit, schoolMask, direction)
  if not text or text == "" then return end

  for i = 1, #active do
    local st = active[i]._etbc
    if st then st.stack = (st.stack or 0) + 14 end
  end

  local fs = AcquireFS()
  fs:SetParent(UIParent)

  ApplyFont(fs, db, isCrit)
  local r, g, b, a = ColorFor(db, kind, isCrit, schoolMask)
  fs:SetTextColor(r, g, b, a)
  fs:SetText(text)

  fs:ClearAllPoints()
  fs:SetPoint(db.anchor.point or "CENTER", UIParent, db.anchor.relPoint or "CENTER", db.anchor.x or 0, db.anchor.y or 0)
  fs:SetAlpha(1)
  fs:Show()

  fs._etbc = { t = 0, kind = kind, stack = 0, dir = direction or "OUT" }

  table.insert(active, 1, fs)
  ClampLines(db.maxLines or 10)
end

-- ---------- batching

local function BucketKey(kind, direction, spellID, isCrit, schoolMask, label)
  return table.concat({
    kind or "X",
    direction or "OUT",
    tostring(spellID or 0),
    isCrit and "C" or "N",
    tostring(schoolMask or 0),
    label or "",
  }, ":")
end

local function AddToBatch(db, kind, direction, spellID, amount, text, isCrit, schoolMask, label)
  local now = GetTime()
  local w = tonumber(db.throttleWindow) or 0.12

  local key = BucketKey(kind, direction, spellID, isCrit, schoolMask, label)
  local b = batch[key]
  if not b then
    b = {
      kind = kind, dir = direction, spellID = spellID,
      isCrit = isCrit, schoolMask = schoolMask, label = label,
      amount = 0, text = nil,
    }
    batch[key] = b
  end

  if amount and amount ~= 0 then b.amount = (b.amount or 0) + amount end
  if text and text ~= "" then b.text = text end

  batchExpires = now + w
  if not updateRunning then
    updateRunning = true
    driver:SetScript("OnUpdate", mod.OnUpdate)
  end
end

local function FlushBatch(db)
  if not next(batch) then return end

  for _, b in pairs(batch) do
    local prefix = ""
    if db.showDirection then prefix = (b.dir == "IN") and "IN " or "OUT " end

    local namePart = ""
    if db.showSpellName and b.spellID and b.spellID ~= 0 then
      local n = GetSpellInfo(b.spellID)
      if n then namePart = n .. ": " end
    end
    if b.label and b.label ~= "" then
      namePart = b.label .. ": "
    end

    if b.kind == "DAMAGE" and db.showDamage then
      PushLine(db, prefix .. namePart .. "-" .. tostring(b.amount or 0), "DAMAGE", b.isCrit, b.schoolMask, b.dir)
    elseif b.kind == "HEAL" and db.showHeals then
      PushLine(db, prefix .. namePart .. "+" .. tostring(b.amount or 0), "HEAL", b.isCrit, b.schoolMask, b.dir)
    elseif b.kind == "MISS" and db.showMisses then
      PushLine(db, prefix .. (b.text or "MISS"), "MISS", false, b.schoolMask, b.dir)
    elseif b.kind == "INTERRUPT" and db.showInterrupts then
      PushLine(db, prefix .. (b.text or "Interrupt"), "INTERRUPT", false, nil, b.dir)
    elseif b.kind == "DISPEL" and db.showDispels then
      PushLine(db, prefix .. (b.text or "Dispel"), "DISPEL", false, nil, b.dir)
    end
  end

  wipe(batch)
end

-- ---------- update loop / animation

function mod.OnUpdate(_, elapsed)
  local db = ETBC.db and ETBC.db.profile and ETBC.db.profile.combattext
  if not db or not (ETBC.db.profile.general.enabled and db.enabled) then
    driver:SetScript("OnUpdate", nil)
    updateRunning = false
    return
  end

  if batchExpires > 0 and GetTime() >= batchExpires then
    batchExpires = 0
    FlushBatch(db)
  end

  if #active == 0 then return end

  local duration = tonumber(db.duration) or 1.10
  local fadeStart = tonumber(db.fadeStart) or 0.55
  if fadeStart > duration then fadeStart = duration * 0.6 end
  local dist = tonumber(db.floatDistance) or 70

  local x0 = tonumber(db.anchor.x) or 0
  local y0 = tonumber(db.anchor.y) or 0
  local spread = tonumber(db.randomX) or 0

  for i = #active, 1, -1 do
    local fs = active[i]
    local st = fs._etbc
    if st then
      st.t = st.t + elapsed
      local t = st.t

      if t >= duration then
        ReleaseFS(fs)
        table.remove(active, i)
      else
        local p = t / duration

        local dirMul = (db.floatDirection == "DOWN") and -1 or 1
        if db.splitDirections and st.dir == "IN" then
          dirMul = -dirMul
        end

        local y = y0 + (st.stack or 0) + (p * dist * dirMul)

        local x = x0
        if spread > 0 then
          st.rx = st.rx or random(-spread, spread)
          x = x + st.rx
        end

        fs:ClearAllPoints()
        fs:SetPoint(db.anchor.point or "CENTER", UIParent, db.anchor.relPoint or "CENTER", x, y)

        if t >= fadeStart then
          local fp = (t - fadeStart) / (duration - fadeStart)
          fs:SetAlpha(1 - fp)
        else
          fs:SetAlpha(1)
        end
      end
    end
  end
end

-- ---------- CLEU parsing (FIXED indices; no multi-return tonumber bugs)

local function IsPlayerGUID(guid)
  return guid and UnitGUID("player") == guid
end

local function HandleCLEU(db)
  -- indices:
  -- 1 timestamp, 2 subEvent, 4 srcGUID, 8 dstGUID, 12+ args
  local _, subEvent, _, srcGUID, _, _, _, dstGUID = CombatLogGetCurrentEventInfo()
  if not subEvent then return end

  local isOut = IsPlayerGUID(srcGUID)
  local isIn = IsPlayerGUID(dstGUID)

  if not db.trackOutgoing then isOut = false end
  if not db.trackIncoming then isIn = false end
  if not (isOut or isIn) then return end
  if db.onlyInCombat and not UnitAffectingCombat("player") then return end

  local direction = isIn and "IN" or "OUT"

  -- SWING_DAMAGE args:
  -- 12 amount, 13 overkill, 14 school, 18 critical
  if subEvent == "SWING_DAMAGE" and db.showDamage then
    local amount = tonumber((select(12, CombatLogGetCurrentEventInfo()))) or 0
    local schoolMask = tonumber((select(14, CombatLogGetCurrentEventInfo())))
    local critical = select(18, CombatLogGetCurrentEventInfo())

    AddToBatch(db, "DAMAGE", direction, 0, amount, nil, not not critical, schoolMask)
    return
  end

  -- SPELL_DAMAGE / RANGE_DAMAGE args:
  -- 12 spellId, 14 school, 15 amount, 21 critical
  if (subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE") and db.showDamage then
    local spellID = tonumber((select(12, CombatLogGetCurrentEventInfo()))) or 0
    local schoolMask = tonumber((select(14, CombatLogGetCurrentEventInfo())))
    local amount = tonumber((select(15, CombatLogGetCurrentEventInfo()))) or 0
    local critical = select(21, CombatLogGetCurrentEventInfo())

    AddToBatch(db, "DAMAGE", direction, spellID, amount, nil, not not critical, schoolMask)
    return
  end

  -- SPELL_HEAL args:
  -- 12 spellId, 15 amount, 16 overheal, 18 critical
  if subEvent == "SPELL_HEAL" and db.showHeals then
    local spellID = tonumber((select(12, CombatLogGetCurrentEventInfo()))) or 0
    local amount = tonumber((select(15, CombatLogGetCurrentEventInfo()))) or 0
    local overheal = tonumber((select(16, CombatLogGetCurrentEventInfo()))) or 0
    local critical = select(18, CombatLogGetCurrentEventInfo())

    if db.showOverheal and overheal > 0 then
      AddToBatch(db, "HEAL", direction, spellID, amount, nil, not not critical, nil)
      AddToBatch(db, "HEAL", direction, spellID, 0, nil, false, nil, "OH " .. overheal)
    else
      AddToBatch(db, "HEAL", direction, spellID, amount, nil, not not critical, nil)
    end
    return
  end

  -- SWING_MISSED args:
  -- 12 missType
  if subEvent == "SWING_MISSED" and db.showMisses then
    local missType = tostring((select(12, CombatLogGetCurrentEventInfo())) or "MISS")
    AddToBatch(db, "MISS", direction, 0, 0, missType, false, nil)
    return
  end

  -- SPELL_MISSED / RANGE_MISSED args:
  -- 12 spellId, 15 missType
  if (subEvent == "SPELL_MISSED" or subEvent == "RANGE_MISSED") and db.showMisses then
    local spellID = tonumber((select(12, CombatLogGetCurrentEventInfo()))) or 0
    local missType = tostring((select(15, CombatLogGetCurrentEventInfo())) or "MISS")
    AddToBatch(db, "MISS", direction, spellID, 0, missType, false, nil)
    return
  end

  -- SPELL_INTERRUPT args:
  -- 12 spellId, 16 extraSpellName
  if subEvent == "SPELL_INTERRUPT" and db.showInterrupts then
    local spellID = tonumber((select(12, CombatLogGetCurrentEventInfo()))) or 0
    local extraSpellName = select(16, CombatLogGetCurrentEventInfo()) or "Interrupt"
    AddToBatch(db, "INTERRUPT", direction, spellID, 0, "Interrupt: " .. tostring(extraSpellName), false, nil)
    return
  end

  -- SPELL_DISPEL / SPELL_STOLEN args:
  -- 12 spellId, 16 extraSpellName
  if (subEvent == "SPELL_DISPEL" or subEvent == "SPELL_STOLEN") and db.showDispels then
    local spellID = tonumber((select(12, CombatLogGetCurrentEventInfo()))) or 0
    local extraSpellName = select(16, CombatLogGetCurrentEventInfo()) or "Dispel"
    local prefix = (subEvent == "SPELL_STOLEN") and "Stole: " or "Dispel: "
    AddToBatch(db, "DISPEL", direction, spellID, 0, prefix .. tostring(extraSpellName), false, nil)
    return
  end
end

-- ---------- mover / preview / apply

local function Position(db)
  anchor:ClearAllPoints()
  anchor:SetPoint(db.anchor.point or "CENTER", UIParent, db.anchor.relPoint or "CENTER", db.anchor.x or 0, db.anchor.y or 0)
end

local function RegisterMover()
  if not (ETBC.Mover and ETBC.Mover.Register) then return end
  ETBC.Mover:Register("combattext", anchor, {
    default = {
      point = "CENTER",
      rel = "UIParent",
      relPoint = "CENTER",
      x = 0,
      y = 120,
    },
  })
end

local function BuildPreview(db)
  ClearAll()
  PushLine(db, "OUT Fireball: -1243", "DAMAGE", true, 4, "OUT")
  PushLine(db, "OUT +812", "HEAL", false, nil, "OUT")
  PushLine(db, "IN Frostbolt: -532", "DAMAGE", false, 16, "IN")
  PushLine(db, "DODGE", "MISS", false, nil, "OUT")
  PushLine(db, "Interrupt: Fireball", "INTERRUPT", false, nil, "OUT")
  PushLine(db, "Dispel: Polymorph", "DISPEL", false, nil, "OUT")
end

local function Apply()
  EnsureFrames()

  local p = ETBC.db.profile
  local db = p.combattext
  local enabled = p.general.enabled and db.enabled

  driver:UnregisterAllEvents()
  driver:SetScript("OnEvent", nil)

  -- Suppress Blizzard combat text to prevent duplicates
  if enabled and db.blizzard and db.blizzard.disableBlizzardFCT then
    DisableBlizzardFCT(db)
  else
    if db.blizzard and db.blizzard.restoreOnDisable then
      RestoreBlizzardFCT(db)
    else
      if db.blizzard then db.blizzard._saved = nil end
    end
  end

  if not enabled then
    batchExpires = 0
    wipe(batch)
    ClearAll()
    driver:SetScript("OnUpdate", nil)
    updateRunning = false
    driver:Hide()
    anchor:Hide()
    return
  end

  anchor:Show()
  Position(db)
  RegisterMover()

  driver:RegisterEvent("PLAYER_ENTERING_WORLD")
  driver:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

  driver:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
      if db.blizzard and db.blizzard.disableBlizzardFCT then
        DisableBlizzardFCT(db)
      end
      Position(db)
      if db.preview then BuildPreview(db) else ClearAll() end
      return
    end

    if db.preview then return end
    HandleCLEU(db)
  end)

  driver:Show()

  if not updateRunning then
    updateRunning = true
    driver:SetScript("OnUpdate", mod.OnUpdate)
  end

  if db.preview then
    BuildPreview(db)
  else
    ClearAll()
  end
end

ETBC.ApplyBus:Register("combattext", Apply)
ETBC.ApplyBus:Register("general", Apply)

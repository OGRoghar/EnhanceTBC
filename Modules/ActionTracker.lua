-- Modules/ActionTracker.lua
local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.ActionTracker = mod
mod.Internal = mod.Internal or {}
mod.Internal.Shared = mod.Internal.Shared or {}
local Compat = ETBC.Compat or {}

local LSM = ETBC.LSM

local driver
local anchor
local container

local pool = {}
local activeIcons = {}
local entries = {}

local DEFAULT_ANCHOR = { point = "CENTER", rel = "UIParent", relPoint = "CENTER", x = 0, y = -220 }

local updateTicker = 0
local UPDATE_INTERVAL = 0.10

local function SafeFont(face)
  face = face or "Friz Quadrata TT"
  if LSM and LSM.Fetch then
    local f = LSM:Fetch("font", face, true)
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

local function EnsureFrames()
  if not driver then
    driver = CreateFrame("Frame", "EnhanceTBC_ActionTrackerDriver", UIParent)
    driver:Hide()
  end
  if not anchor then
    anchor = CreateFrame("Frame", "EnhanceTBC_ActionTrackerAnchor", UIParent)
    anchor:SetSize(1, 1)
  end
  if not container then
    container = CreateFrame("Frame", "EnhanceTBC_ActionTrackerContainer", UIParent)
    container:SetSize(1, 1)
  end
end

local function RegisterMover()
  if not (ETBC.Mover and ETBC.Mover.Register) then return end
  if not anchor then return end
  ETBC.Mover:Register("ActionTracker", anchor, {
    name = "Action Tracker",
    default = DEFAULT_ANCHOR,
  })
end

local function VisibilityAllowed(db)
  if db and db.preview then return true end
  local vis = ETBC.Modules and ETBC.Modules.Visibility
  if vis and vis.Allowed then
    return vis:Allowed("actiontracker")
  end
  return true
end

local function ReleaseIcon(icon)
  if not icon then return end
  icon:Hide()
  icon:SetParent(UIParent)
  icon.data = nil
  pool[#pool+1] = icon
end

local function AcquireIcon()
  local icon = table.remove(pool)
  if icon then
    icon:Show()
    return icon
  end

  icon = CreateFrame("Frame", nil, UIParent)
  icon:SetSize(28, 28)

  icon.icon = icon:CreateTexture(nil, "BORDER")
  icon.icon:SetAllPoints(icon)
  icon.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
  icon.cooldown:SetAllPoints(icon)

  icon.border = CreateFrame("Frame", nil, icon, BackdropTemplateMixin and "BackdropTemplate" or nil)
  icon.border:ClearAllPoints()
  icon.border:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
  icon.border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
  if icon.border.SetBackdrop then
    icon.border:SetBackdrop({
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
      edgeSize = 14,
    })
  end

  icon.nameText = icon:CreateFontString(nil, "OVERLAY")
  icon.nameText:SetPoint("TOP", icon, "BOTTOM", 0, -2)

  -- IMPORTANT: prevent "Font not set" errors
  icon.nameText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
  icon.nameText:SetTextColor(1, 1, 1, 1)
  icon.nameText:SetText("")
  icon.nameText:Hide()

  return icon
end

local function ClearActive()
  for i = #activeIcons, 1, -1 do
    ReleaseIcon(activeIcons[i])
    activeIcons[i] = nil
  end
end

local function ClampEntries(maxEntries)
  while #entries > maxEntries do
    table.remove(entries, #entries)
  end
end

local function LayoutIcons(db)
  local size = db.iconSize
  local spacing = db.spacing
  local perRow = db.perRow
  local growRight = (db.growthX == "RIGHT")
  local growUp = (db.growthY == "UP")

  local dx = size + spacing
  local dy = size + spacing
  if not growRight then dx = -dx end
  if not growUp then dy = -dy end

  for i = 1, #activeIcons do
    local ic = activeIcons[i]
    ic:SetSize(size, size)
    ic:ClearAllPoints()

    local row = math.floor((i - 1) / perRow)
    local col = (i - 1) % perRow
    ic:SetPoint("TOPLEFT", container, "TOPLEFT", col * dx, row * dy)
  end
end

local function GetClassColorOr(db)
  if db.nameText.classColor then
    local _, class = UnitClass("player")
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
      local c = RAID_CLASS_COLORS[class]
      return c.r, c.g, c.b, 1
    end
  end
  local c = db.nameText.color
  return c.r, c.g, c.b, (c.a or 1)
end

local function ApplyVisuals(icon, db, entry)
  icon.icon:SetTexture(entry.texture or "Interface/Icons/INV_Misc_QuestionMark")

  if db.border.enabled then
    icon.border:Show()
    local c = db.border.color
    if icon.border.SetBackdropBorderColor then
      icon.border:SetBackdropBorderColor(c.r, c.g, c.b, (c.a or 1))
    end
  else
    icon.border:Hide()
  end

  if db.showCooldownSpiral and entry.spellID and entry.spellID ~= 0 then
    local cd = Compat.GetSpellCooldownByID and Compat.GetSpellCooldownByID(entry.spellID) or nil
    local start = cd and cd.startTime or 0
    local duration = cd and cd.duration or 0
    local enabled = cd and cd.isEnabled or false
    if enabled and duration > 1.5 and start > 0 then
      icon.cooldown:Show()
      icon.cooldown:SetCooldown(start, duration)
    else
      icon.cooldown:Hide()
    end
  else
    icon.cooldown:Hide()
  end

  -- Always set font BEFORE SetText (prevents rare "font not set" paths)
  local font = SafeFont(db.nameText.font)
  local flags = OutlineFlag(db.nameText.outline)
  icon.nameText:SetFont(font, db.nameText.size or 12, flags)

  if db.showName and entry.name then
    local r, g, b, a = GetClassColorOr(db)
    icon.nameText:SetTextColor(r, g, b, a)
    icon.nameText:SetText(entry.name)
    icon.nameText:Show()
  else
    icon.nameText:SetText("")
    icon.nameText:Hide()
  end

  icon.data = entry
end

local function Rebuild(db)
  ClearActive()

  for i = 1, #entries do
    local entry = entries[i]
    local ic = AcquireIcon()
    ic:SetParent(container)
    ApplyVisuals(ic, db, entry)
    ic:SetAlpha(entry.alpha or 1)
    ic:Show()
    activeIcons[#activeIcons+1] = ic
  end

  LayoutIcons(db)
end

local function Prune(db)
  local now = GetTime()
  local lifetime = db.lifetime or 12

  local changed = false
  for i = #entries, 1, -1 do
    local e = entries[i]
    local age = now - (e.t or now)
    if age >= lifetime then
      table.remove(entries, i)
      changed = true
    else
      local fadeStart = lifetime * 0.75
      if age >= fadeStart then
        local p = (age - fadeStart) / (lifetime - fadeStart)
        e.alpha = 1 - math.min(1, math.max(0, p))
      else
        e.alpha = 1
      end
    end
  end

  if changed then
    Rebuild(db)
  else
    for i = 1, #activeIcons do
      local ic = activeIcons[i]
      local e = ic.data
      if e then ic:SetAlpha(e.alpha or 1) end
    end
  end
end

local function AddSpell(db, spellID)
  if not spellID or spellID == 0 then return end

  local info = Compat.GetSpellInfoByID and Compat.GetSpellInfoByID(spellID) or nil
  if not info or not info.name then return end

  for i = 1, #entries do
    if entries[i].spellID == spellID then
      table.remove(entries, i)
      break
    end
  end

  table.insert(entries, 1, {
    kind = "SPELL",
    spellID = spellID,
    name = info.name,
    texture = info.iconID,
    t = GetTime(),
    alpha = 1,
  })

  ClampEntries(db.maxEntries or 10)
  Rebuild(db)
end

local function BuildPreview(db)
  wipe(entries)
  local now = GetTime()
  for i = 1, (db.maxEntries or 10) do
    table.insert(entries, {
      kind = "SPELL",
      spellID = 0,
      name = "Preview " .. i,
      texture = "Interface/Icons/Spell_Nature_Rejuvenation",
      t = now - (i - 1) * 0.8,
      alpha = 1,
    })
  end
  Rebuild(db)
end

local function Position()
  RegisterMover()
  if ETBC.Mover and ETBC.Mover.Apply then
    ETBC.Mover:Apply("ActionTracker")
  else
    anchor:ClearAllPoints()
    anchor:SetPoint(DEFAULT_ANCHOR.point, UIParent, DEFAULT_ANCHOR.relPoint, DEFAULT_ANCHOR.x, DEFAULT_ANCHOR.y)
  end

  container:ClearAllPoints()
  container:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
end

local function Apply()
  EnsureFrames()

  local p = ETBC.db.profile
  local db = p.actiontracker
  local enabled = p.general.enabled and db.enabled

  if not enabled or not VisibilityAllowed(db) then
    driver:UnregisterAllEvents()
    driver:SetScript("OnUpdate", nil)
    ClearActive()
    wipe(entries)
    container:Hide()
    driver:Hide()
    return
  end

  Position()
  container:Show()

  driver:UnregisterAllEvents()
  driver:RegisterEvent("PLAYER_ENTERING_WORLD")
  driver:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

  driver:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
      if db.preview then
        BuildPreview(db)
      else
        ClearActive()
        wipe(entries)
      end
      return
    end

    if db.preview then return end
    local _, subEvent, _, srcGUID, _, _, _, _, _, _, _, spellID = CombatLogGetCurrentEventInfo()
    if not subEvent then return end

    if db.onlyPlayer and srcGUID ~= UnitGUID("player") then return end

    if db.trackSpells and (subEvent == "SPELL_CAST_SUCCESS" or subEvent == "SPELL_CAST_START") then
      AddSpell(db, spellID)
    end
  end)

  driver:SetScript("OnUpdate", function(_, elapsed)
    updateTicker = updateTicker + elapsed
    if updateTicker < UPDATE_INTERVAL then return end
    updateTicker = 0

    if #entries > 0 then
      Prune(db)
    end
  end)

  driver:Show()

  if db.preview then
    BuildPreview(db)
  else
    ClearActive()
    wipe(entries)
  end
end

local function GetConfigPreviewStyle()
  local p = ETBC and ETBC.db and ETBC.db.profile or nil
  local db = p and p.actiontracker or nil
  if type(db) ~= "table" then
    return nil
  end

  local nt = db.nameText or {}
  local border = db.border or {}
  local barColor
  if border.enabled and type(border.color) == "table" then
    barColor = { border.color.r or 0.15, border.color.g or 0.30, border.color.b or 0.15, border.color.a or 1 }
  else
    barColor = { 0.16, 0.22, 0.16, 1 }
  end

  local pr, pg, pb, pa
  if nt.classColor then
    local _, class = UnitClass("player")
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
      local c = RAID_CLASS_COLORS[class]
      pr, pg, pb, pa = c.r, c.g, c.b, 1
    end
  end
  if pr == nil then
    local c = nt.color or {}
    pr = c.r or 0.9
    pg = c.g or 0.9
    pb = c.b or 0.9
    pa = c.a or 1
  end
  local summary = string.format(
    "%dx row, %dpx icons | %s/%s growth%s",
    tonumber(db.perRow) or 1,
    tonumber(db.iconSize) or 28,
    tostring(db.growthX or "LEFT"),
    tostring(db.growthY or "DOWN"),
    (db.showName and " | Names shown") or ""
  )

  local fontPath = SafeFont(nt.font)
  local fontFlags = OutlineFlag(nt.outline)
  local fontSize = tonumber(nt.size) or 12

  return {
    enabled = db.enabled and true or false,
    previewText = summary,
    previewFont = { path = fontPath, size = fontSize, flags = fontFlags },
    previewTextColor = { pr or 1, pg or 1, pb or 1, pa or 1 },
    useBar = true,
    barValue = 58,
    barColor = barColor,
    barText = (db.showName and "Action Tracker") or "Tracker Row",
    barTextFont = { path = fontPath, size = fontSize, flags = fontFlags },
  }
end
mod.Internal.Shared.GetConfigPreviewStyle = GetConfigPreviewStyle

ETBC.ApplyBus:Register("actiontracker", Apply)
ETBC.ApplyBus:Register("general", Apply)
ETBC.ApplyBus:Register("ui", Apply)

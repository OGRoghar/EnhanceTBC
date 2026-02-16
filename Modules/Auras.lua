-- Modules/Auras.lua
local ADDON_NAME, ETBC = ...
local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceTBC")
ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.Auras = mod

local LSM = ETBC.media

local driver

local buffAnchor
local debuffAnchor
local buffContainer
local debuffContainer

local buffHandle
local debuffHandle

local pool = {}
local activeBuffs = {}
local activeDebuffs = {}

local updateTicker = 0
local UPDATE_INTERVAL = 0.10

local DEBUFF_COLORS = {
  Magic   = { r = 0.20, g = 0.60, b = 1.00, a = 1.0 },
  Curse   = { r = 0.60, g = 0.00, b = 1.00, a = 1.0 },
  Disease = { r = 0.60, g = 0.40, b = 0.00, a = 1.0 },
  Poison  = { r = 0.00, g = 0.60, b = 0.00, a = 1.0 },
}

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

local function EnsureDriver()
  if driver then return end
  driver = CreateFrame("Frame", "EnhanceTBC_AurasDriver", UIParent)
  driver:Hide()
end

local function GetGridSize()
  local p = ETBC.db and ETBC.db.profile
  if p and p.mover and type(p.mover.gridSize) == "number" and p.mover.gridSize > 0 then
    return p.mover.gridSize
  end
  return 8
end

local function Snap(n, grid)
  if not grid or grid <= 0 then return n end
  if n >= 0 then
    return math.floor((n / grid) + 0.5) * grid
  end
  return math.ceil((n / grid) - 0.5) * grid
end

local function SetShownCompat(frame, shown)
  if not frame then return end
  if frame.SetShown then
    frame:SetShown(shown and true or false)
    return
  end
  if shown then
    if frame.Show then frame:Show() end
  else
    if frame.Hide then frame:Hide() end
  end
end

local function EnsureFrames()
  EnsureDriver()

  if not buffAnchor then
    buffAnchor = CreateFrame("Frame", "EnhanceTBC_BuffsAnchor", UIParent)
    buffAnchor:SetSize(1, 1)
  end
  if not debuffAnchor then
    debuffAnchor = CreateFrame("Frame", "EnhanceTBC_DebuffsAnchor", UIParent)
    debuffAnchor:SetSize(1, 1)
  end

  if not buffContainer then
    buffContainer = CreateFrame("Frame", "EnhanceTBC_BuffsContainer", UIParent)
    buffContainer:SetSize(1, 1)
  end
  if not debuffContainer then
    debuffContainer = CreateFrame("Frame", "EnhanceTBC_DebuffsContainer", UIParent)
    debuffContainer:SetSize(1, 1)
  end

  local function MakeHandle(title)
    local f = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetFrameStrata("DIALOG")
    f:SetSize(220, 44)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")

    if f.SetBackdrop then
      f:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
      })
      f:SetBackdropColor(0.03, 0.08, 0.03, 0.55)
      f:SetBackdropBorderColor(0.2, 1.0, 0.2, 1.0)
    end

    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.text:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.text:SetText(title)

    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.hint:SetPoint("TOP", f, "BOTTOM", 0, -2)
    f.hint:SetText("Drag to move")

    f:SetScript("OnDragStart", function(self)
      if not self.StartMoving then return end
      self:StartMoving()
    end)

    f:SetScript("OnDragStop", function(self)
      if self.StopMovingOrSizing then
        self:StopMovingOrSizing()
      end

      local db = ETBC.db.profile.auras
      local grid = GetGridSize()

      local point, _, relPoint, x, y = self:GetPoint(1)
      x, y = x or 0, y or 0

      if db.moveSnapToGrid then
        x = Snap(x, grid)
        y = Snap(y, grid)
      end

      -- Save into the correct anchorDB (set by f.anchorDB)
      local a = self.anchorDB
      if not a then return end

      a.point = point or a.point
      a.relPoint = relPoint or a.relPoint
      a.x = x
      a.y = y

      -- Re-anchor the handle to the snapped position
      self:ClearAllPoints()
      self:SetPoint(a.point, UIParent, a.relPoint, a.x, a.y)

      ETBC.ApplyBus:Notify("auras")
    end)

    f:Hide()
    return f
  end

  if not buffHandle then
    buffHandle = MakeHandle("Auras: Buffs")
  end
  if not debuffHandle then
    debuffHandle = MakeHandle("Auras: Debuffs")
  end
end

local function ReleaseIcon(icon)
  if not icon then return end
  icon:Hide()
  icon:SetParent(UIParent)
  icon.data = nil
  icon.type = nil
  pool[#pool+1] = icon
end

local function AcquireIcon()
  local icon = table.remove(pool)
  if icon then
    icon:Show()
    return icon
  end

  icon = CreateFrame("Button", nil, UIParent)
  icon:SetSize(24, 24)
  icon:RegisterForClicks("RightButtonUp")
  icon:EnableMouse(true)

  icon.icon = icon:CreateTexture(nil, "BORDER")
  icon.icon:SetAllPoints(icon)
  icon.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
  icon.cooldown:SetAllPoints(icon)

  icon.timeText = icon:CreateFontString(nil, "OVERLAY")
  icon.timeText:SetPoint("BOTTOM", icon, "BOTTOM", 0, 1)
  icon.timeText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
  icon.timeText:SetText("")
  icon.timeText:Hide()

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

  icon:SetScript("OnEnter", function(self)
    local db = ETBC.db.profile.auras
    if not db.useBlizzardTooltips then return end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

    if self.type == "preview" then
      GameTooltip:AddLine("Preview Aura", 1, 1, 1)
      GameTooltip:AddLine("Dummy aura for layout testing.", 0.8, 0.8, 0.8)
      GameTooltip:Show()
      return
    end

    if not self.data then return end
    if self.data.kind == "BUFF" then
      GameTooltip:SetUnitBuff("player", self.data.index)
    else
      GameTooltip:SetUnitDebuff("player", self.data.index)
    end
    GameTooltip:Show()
  end)

  icon:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
  end)

  icon:SetScript("OnClick", function(self, button)
    if button ~= "RightButton" then return end
    if self.type == "preview" then return end
    if not self.data or self.data.kind ~= "BUFF" then return end
    CancelUnitBuff("player", self.data.index)
  end)

  return icon
end

local function FormatTime(secs)
  if secs <= 0 then return "" end
  if secs < 60 then return string.format("%d", secs) end
  if secs < 3600 then return string.format("%dm", math.floor(secs / 60)) end
  return string.format("%dh", math.floor(secs / 3600))
end

local function SortList(list, mode, asc)
  table.sort(list, function(a, b)
    if mode == "NAME" then
      local an = a.name or ""
      local bn = b.name or ""
      if asc then return an < bn else return an > bn end
    end
    local at = a.remaining or 0
    local bt = b.remaining or 0
    if asc then return at < bt else return at > bt end
  end)
end

local function LayoutIcons(container, icons, layout)
  local size = layout.iconSize
  local spacing = layout.spacing
  local perRow = layout.perRow

  local growRight = (layout.growthX == "RIGHT")
  local growUp = (layout.growthY == "UP")

  local dx = size + spacing
  local dy = size + spacing
  if not growRight then dx = -dx end
  if not growUp then dy = -dy end

  for i = 1, #icons do
    local ic = icons[i]
    ic:ClearAllPoints()

    local row = math.floor((i - 1) / perRow)
    local col = (i - 1) % perRow
    ic:SetPoint("TOPLEFT", container, "TOPLEFT", col * dx, row * dy)
  end
end

local function ApplyVisuals(icon, common, layout, data)
  icon:SetSize(layout.iconSize, layout.iconSize)
  icon.icon:SetTexture(data.texture or "Interface/Icons/INV_Misc_QuestionMark")

  if common.showCooldownSpiral and data.duration and data.duration > 0 and data.expiration and data.expiration > 0 then
    icon.cooldown:Show()
    local start = data.expiration - data.duration
    icon.cooldown:SetCooldown(start, data.duration)
  else
    icon.cooldown:Hide()
  end

  if common.border.enabled then
    icon.border:Show()
    local c = common.border.color
    local br, bg, bb, ba = c.r, c.g, c.b, (c.a or 1)

    if common.border.debuffTypeColors and data.kind == "DEBUFF" and data.debuffType and DEBUFF_COLORS[data.debuffType] then
      local dc = DEBUFF_COLORS[data.debuffType]
      br, bg, bb, ba = dc.r, dc.g, dc.b, (dc.a or 1)
    end

    if icon.border.SetBackdropBorderColor then
      icon.border:SetBackdropBorderColor(br, bg, bb, ba)
    end
  else
    icon.border:Hide()
  end

  local font = SafeFont(common.durationText.font)
  local outline = OutlineFlag(common.durationText.outline)
  icon.timeText:SetFont(font, common.durationText.size or 12, outline)

  if common.showDurationText and data.duration and data.duration > 0 and data.expiration and data.expiration > 0 then
    icon.timeText:Show()
  else
    icon.timeText:SetText("")
    icon.timeText:Hide()
  end
end

local function CollectAuras(kind, common)
  local list = {}

  if kind == "BUFF" then
    for i = 1, 40 do
      local name, iconTexture, count, debuffType, duration, expiration, caster = UnitBuff("player", i)
      if not name then break end

      local include = true
      if common.playerOnly and caster and caster ~= "player" then include = false end

      if include then
        local remaining = 0
        if expiration and expiration > 0 then remaining = math.max(0, expiration - GetTime()) end
        list[#list+1] = {
          kind = "BUFF",
          index = i,
          name = name,
          texture = iconTexture,
          count = count,
          duration = duration,
          expiration = expiration,
          debuffType = debuffType,
          caster = caster,
          remaining = remaining,
        }
      end
    end
  else
    for i = 1, 40 do
      local name, iconTexture, count, debuffType, duration, expiration, caster = UnitDebuff("player", i)
      if not name then break end

      local include = true
      if common.playerOnly and caster and caster ~= "player" then include = false end

      if include then
        local remaining = 0
        if expiration and expiration > 0 then remaining = math.max(0, expiration - GetTime()) end
        list[#list+1] = {
          kind = "DEBUFF",
          index = i,
          name = name,
          texture = iconTexture,
          count = count,
          duration = duration,
          expiration = expiration,
          debuffType = debuffType,
          caster = caster,
          remaining = remaining,
        }
      end
    end
  end

  SortList(list, common.sortMode, common.sortAscending)
  return list
end

local function BuildPreview(kind)
  local list = {}
  local now = GetTime()

  if kind == "BUFF" then
    for i = 1, 18 do
      list[#list+1] = {
        kind = "BUFF",
        index = i,
        name = "Preview Buff " .. i,
        texture = "Interface/Icons/Spell_Nature_Rejuvenation",
        count = (i % 3 == 0) and 2 or 0,
        duration = 120,
        expiration = now + (120 - i * 3),
        remaining = 120 - i * 3,
      }
    end
  else
    local types = { "Magic", "Curse", "Disease", "Poison", nil }
    for i = 1, 12 do
      list[#list+1] = {
        kind = "DEBUFF",
        index = i,
        name = "Preview Debuff " .. i,
        texture = "Interface/Icons/Spell_Shadow_CurseOfTounges",
        count = (i % 4 == 0) and 3 or 0,
        duration = 60,
        expiration = now + (60 - i * 2),
        remaining = 60 - i * 2,
        debuffType = types[(i % #types) + 1],
      }
    end
  end

  return list
end

local function ClearActive(list)
  for i = #list, 1, -1 do
    ReleaseIcon(list[i])
    list[i] = nil
  end
end

local function Render(kind, container, activeList, common, layout)
  ClearActive(activeList)

  local dataList = common.preview and BuildPreview(kind) or CollectAuras(kind, common)

  for i = 1, #dataList do
    local data = dataList[i]
    local icon = AcquireIcon()
    icon:SetParent(container)
    icon:ClearAllPoints()
    icon.data = data
    icon.type = common.preview and "preview" or nil

    ApplyVisuals(icon, common, layout, data)

    if not icon.countText then
      icon.countText = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
      icon.countText:SetPoint("TOPRIGHT", icon, "TOPRIGHT", -2, -2)
    end
    if data.count and data.count > 1 then
      icon.countText:SetText(data.count)
      icon.countText:Show()
    else
      icon.countText:SetText("")
      icon.countText:Hide()
    end

    icon:Show()
    activeList[#activeList+1] = icon
  end

  LayoutIcons(container, activeList, layout)
end

local function PositionAnchor(frame, a)
  frame:ClearAllPoints()
  frame:SetPoint(a.point, UIParent, a.relPoint, a.x, a.y)
end

local function UpdateMoveHandles(db)
  local show = db.showMoveHandles and true or false

  if not show then
    if buffHandle then buffHandle:Hide() end
    if debuffHandle then debuffHandle:Hide() end
    return
  end

  -- Bind which anchor DB each handle controls
  buffHandle.anchorDB = db.buffs.anchor
  debuffHandle.anchorDB = db.debuffs.anchor

  -- Position handles at the anchors
  buffHandle:ClearAllPoints()
  buffHandle:SetPoint(db.buffs.anchor.point, UIParent, db.buffs.anchor.relPoint, db.buffs.anchor.x, db.buffs.anchor.y)

  debuffHandle:ClearAllPoints()
  debuffHandle:SetPoint(db.debuffs.anchor.point, UIParent, db.debuffs.anchor.relPoint, db.debuffs.anchor.x, db.debuffs.anchor.y)

  SetShownCompat(buffHandle, db.buffs.enabled)
  SetShownCompat(debuffHandle, db.debuffs.enabled)
end

local function Apply()
  EnsureFrames()

  local p = ETBC.db.profile
  local db = p.auras

  local enabled = p.general.enabled and db.enabled
  if not enabled then
    driver:UnregisterAllEvents()
    driver:SetScript("OnUpdate", nil)
    ClearActive(activeBuffs)
    ClearActive(activeDebuffs)
    buffContainer:Hide()
    debuffContainer:Hide()
    if buffHandle then buffHandle:Hide() end
    if debuffHandle then debuffHandle:Hide() end
    driver:Hide()
    return
  end

  PositionAnchor(buffAnchor, db.buffs.anchor)
  PositionAnchor(debuffAnchor, db.debuffs.anchor)

  buffContainer:ClearAllPoints()
  buffContainer:SetPoint("TOPLEFT", buffAnchor, "TOPLEFT", 0, 0)

  debuffContainer:ClearAllPoints()
  debuffContainer:SetPoint("TOPLEFT", debuffAnchor, "TOPLEFT", 0, 0)

  SetShownCompat(buffContainer, db.buffs.enabled)
  SetShownCompat(debuffContainer, db.debuffs.enabled)

  UpdateMoveHandles(db)

  driver:UnregisterAllEvents()
  driver:RegisterEvent("UNIT_AURA")
  driver:RegisterEvent("PLAYER_ENTERING_WORLD")

  driver:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_AURA" and unit ~= "player" then return end
    if db.buffs.enabled then
      Render("BUFF", buffContainer, activeBuffs, db, db.buffs)
    else
      ClearActive(activeBuffs)
    end
    if db.debuffs.enabled then
      Render("DEBUFF", debuffContainer, activeDebuffs, db, db.debuffs)
    else
      ClearActive(activeDebuffs)
    end
    UpdateMoveHandles(db)
  end)

  driver:SetScript("OnUpdate", function(_, elapsed)
    updateTicker = updateTicker + elapsed
    if updateTicker < UPDATE_INTERVAL then return end
    updateTicker = 0

    if not db.showDurationText then return end
    local now = GetTime()

    for i = 1, #activeBuffs do
      local icon = activeBuffs[i]
      local d = icon.data
      if d and d.expiration and d.expiration > 0 then
        local rem = math.max(0, math.floor(d.expiration - now + 0.5))
        icon.timeText:SetText(FormatTime(rem))
      else
        icon.timeText:SetText("")
      end
    end

    for i = 1, #activeDebuffs do
      local icon = activeDebuffs[i]
      local d = icon.data
      if d and d.expiration and d.expiration > 0 then
        local rem = math.max(0, math.floor(d.expiration - now + 0.5))
        icon.timeText:SetText(FormatTime(rem))
      else
        icon.timeText:SetText("")
      end
    end
  end)

  driver:Show()

  if db.buffs.enabled then
    Render("BUFF", buffContainer, activeBuffs, db, db.buffs)
  else
    ClearActive(activeBuffs)
  end

  if db.debuffs.enabled then
    Render("DEBUFF", debuffContainer, activeDebuffs, db, db.debuffs)
  else
    ClearActive(activeDebuffs)
  end

  UpdateMoveHandles(db)
end

ETBC.ApplyBus:Register("auras", Apply)
ETBC.ApplyBus:Register("general", Apply)

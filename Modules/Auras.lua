-- Modules/Auras.lua
local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.Auras = mod

local LSM = ETBC.LSM

local driver

local buffAnchor
local debuffAnchor
local buffContainer
local debuffContainer
local blizzardAuraSink
local suppressBlizzardAuras = false


local pool = {}
local activeBuffs = {}
local activeDebuffs = {}
local auraCache = {
  BUFF = {},
  DEBUFF = {},
}
local auraInstanceKinds = {}
local auraSyntheticKey = 0
local blizzardAuraFrames = {
  "BuffFrame",
  "DebuffFrame",
  "TemporaryEnchantFrame",
}
local blizzardAuraState = {}

local updateTicker = 0
local UPDATE_INTERVAL = 0.10

local DEBUFF_COLORS = {
  Magic   = { r = 0.20, g = 0.60, b = 1.00, a = 1.0 },
  Curse   = { r = 0.60, g = 0.00, b = 1.00, a = 1.0 },
  Disease = { r = 0.60, g = 0.40, b = 0.00, a = 1.0 },
  Poison  = { r = 0.00, g = 0.60, b = 0.00, a = 1.0 },
}

local legacyUnitBuff = _G["UnitBuff"]
local legacyUnitDebuff = _G["UnitDebuff"]

local function GetUnitBuffByIndex(unit, index)
  if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex and AuraUtil and AuraUtil.UnpackAuraData then
    local auraData = C_UnitAuras.GetBuffDataByIndex(unit, index)
    if auraData then
      return AuraUtil.UnpackAuraData(auraData)
    end
    return nil
  end

  if type(legacyUnitBuff) == "function" then
    return legacyUnitBuff(unit, index)
  end

  return nil
end

local function GetUnitDebuffByIndex(unit, index)
  if C_UnitAuras and C_UnitAuras.GetDebuffDataByIndex and AuraUtil and AuraUtil.UnpackAuraData then
    local auraData = C_UnitAuras.GetDebuffDataByIndex(unit, index)
    if auraData then
      return AuraUtil.UnpackAuraData(auraData)
    end
    return nil
  end

  if type(legacyUnitDebuff) == "function" then
    return legacyUnitDebuff(unit, index)
  end

  return nil
end

local function NextSyntheticAuraKey(kind)
  auraSyntheticKey = auraSyntheticKey + 1
  return (kind or "AURA") .. ":synthetic:" .. tostring(auraSyntheticKey)
end

local function ClearAuraCache()
  if wipe then
    wipe(auraCache.BUFF)
    wipe(auraCache.DEBUFF)
    wipe(auraInstanceKinds)
  else
    auraCache.BUFF = {}
    auraCache.DEBUFF = {}
    auraInstanceKinds = {}
  end
end

local function ResolveAuraIndexByInstanceID(kind, auraInstanceID)
  local instanceID = tonumber(auraInstanceID)
  if not instanceID then return nil end
  if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return nil end

  local filter = (kind == "DEBUFF") and "HARMFUL" or "HELPFUL"
  for i = 1, 40 do
    local auraData = C_UnitAuras.GetAuraDataByIndex("player", i, filter)
    if not auraData then break end
    if tonumber(auraData.auraInstanceID) == instanceID then
      return i
    end
  end

  return nil
end

local function NormalizeAuraEntry(kind, auraData, index)
  if type(auraData) ~= "table" then return nil end

  local expiration = tonumber(auraData.expirationTime) or 0
  local duration = tonumber(auraData.duration) or 0
  local remaining = 0
  if expiration > 0 then
    remaining = math.max(0, expiration - GetTime())
  end

  return {
    kind = kind,
    index = tonumber(index),
    auraInstanceID = tonumber(auraData.auraInstanceID),
    spellID = tonumber(auraData.spellId),
    name = auraData.name,
    texture = auraData.icon,
    count = tonumber(auraData.applications) or 0,
    duration = duration,
    expiration = expiration,
    debuffType = auraData.dispelName,
    caster = auraData.sourceUnit,
    remaining = remaining,
  }
end

local function StoreAuraInCache(kind, entry, forceKey)
  if not entry or not kind then return end
  local key = forceKey or entry.auraInstanceID or NextSyntheticAuraKey(kind)
  auraCache[kind][key] = entry
  if entry.auraInstanceID then
    auraInstanceKinds[entry.auraInstanceID] = kind
  end
end

local function RebuildAuraCacheFromUnitAuras()
  if not (C_UnitAuras and C_UnitAuras.GetUnitAuras) then
    return false
  end

  ClearAuraCache()

  local function Fill(kind, filter)
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, "player", filter, 40)
    if not ok or type(list) ~= "table" then
      return
    end

    for i = 1, #list do
      local entry = NormalizeAuraEntry(kind, list[i], i)
      if entry then
        StoreAuraInCache(kind, entry)
      end
    end
  end

  Fill("BUFF", "HELPFUL")
  Fill("DEBUFF", "HARMFUL")
  return true
end

local function ApplyAuraDeltaUpdate(updateInfo)
  if type(updateInfo) ~= "table" then
    return RebuildAuraCacheFromUnitAuras()
  end

  if updateInfo.isFullUpdate then
    return RebuildAuraCacheFromUnitAuras()
  end

  if not (C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID) then
    return RebuildAuraCacheFromUnitAuras()
  end

  if type(updateInfo.removedAuraInstanceIDs) == "table" then
    for _, removedID in ipairs(updateInfo.removedAuraInstanceIDs) do
      local instanceID = tonumber(removedID)
      local knownKind = instanceID and auraInstanceKinds[instanceID]
      if instanceID and knownKind and auraCache[knownKind] then
        auraCache[knownKind][instanceID] = nil
        auraInstanceKinds[instanceID] = nil
      end
    end
  end

  if type(updateInfo.addedAuras) == "table" then
    for _, auraData in ipairs(updateInfo.addedAuras) do
      if type(auraData) == "table" then
        local kind = auraData.isHarmful and "DEBUFF" or "BUFF"
        local entry = NormalizeAuraEntry(kind, auraData, nil)
        if entry then
          StoreAuraInCache(kind, entry)
        end
      end
    end
  end

  if type(updateInfo.updatedAuraInstanceIDs) == "table" then
    for _, updatedID in ipairs(updateInfo.updatedAuraInstanceIDs) do
      local instanceID = tonumber(updatedID)
      if instanceID then
        local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID("player", instanceID)
        local oldKind = auraInstanceKinds[instanceID]
        if not auraData then
          if oldKind and auraCache[oldKind] then
            auraCache[oldKind][instanceID] = nil
          end
          auraInstanceKinds[instanceID] = nil
        else
          local newKind = auraData.isHarmful and "DEBUFF" or "BUFF"
          local entry = NormalizeAuraEntry(newKind, auraData, nil)
          if entry then
            if oldKind and oldKind ~= newKind and auraCache[oldKind] then
              auraCache[oldKind][instanceID] = nil
            end
            StoreAuraInCache(newKind, entry, instanceID)
          end
        end
      end
    end
  end

  return true
end

local function SafeFont(face)
  face = face or "Friz Quadrata TT"
  if LSM and LSM.Fetch then
    local f = LSM:Fetch("font", face, true)
    return f or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
  end
  return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local function OutlineFlag(outline)
  if outline == "OUTLINE" then return "OUTLINE" end
  if outline == "THICKOUTLINE" then return "THICKOUTLINE" end
  if outline == "MONOCHROMEOUTLINE" then return "MONOCHROME,OUTLINE" end
  return ""
end

local function ApplyFont(fs, info, fallbackSize)
  if not fs then return end
  local size = fallbackSize or 12
  local font = STANDARD_TEXT_FONT
  local outline = ""

  if info then
    size = info.size or size
    font = SafeFont(info.font)
    outline = OutlineFlag(info.outline)
  end

  fs:SetFont(font, size, outline)
end

local function EnsureDriver()
  if driver then return end
  driver = CreateFrame("Frame", "EnhanceTBC_AurasDriver", UIParent)
  driver:Hide()
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

  if not blizzardAuraSink then
    blizzardAuraSink = CreateFrame("Frame", "EnhanceTBC_BlizzardAuraSink", UIParent)
    blizzardAuraSink:Hide()
  end

end

local function KeepFrameHiddenWhileSuppressed(frame)
  if not frame or frame._etbcAurasHideHooked then return end
  frame._etbcAurasHideHooked = true
  hooksecurefunc(frame, "Show", function(self)
    if suppressBlizzardAuras then
      self:Hide()
    end
  end)
end

local function SetBlizzardAuraFramesSuppressed(suppressed)
  suppressBlizzardAuras = suppressed and true or false
  EnsureFrames()

  for i = 1, #blizzardAuraFrames do
    local frameName = blizzardAuraFrames[i]
    local frame = _G[frameName]
    if frame then
      local state = blizzardAuraState[frameName]
      if not state then
        state = {}
        blizzardAuraState[frameName] = state
      end

      if suppressed then
        if not state.parent then
          state.parent = frame:GetParent()
          state.alpha = frame:GetAlpha()
        end
        KeepFrameHiddenWhileSuppressed(frame)
        frame:SetParent(blizzardAuraSink)
        frame:SetAlpha(0)
        frame:Hide()
      else
        if state.parent then
          frame:SetParent(state.parent)
          frame:SetAlpha(state.alpha or 1)
          state.parent = nil
          state.alpha = nil
        end
        frame:Show()
      end
    end
  end
end

local function RegisterMover(db)
  if not (ETBC.Mover and ETBC.Mover.Register) then return end
  if not (buffAnchor and debuffAnchor) then return end

  local buffs = db and db.buffs and db.buffs.anchor or {}
  local debuffs = db and db.debuffs and db.debuffs.anchor or {}

  ETBC.Mover:Register("AurasBuffs", buffAnchor, {
    name = "Auras: Buffs",
    default = {
      point = buffs.point or "TOPRIGHT",
      rel = "UIParent",
      relPoint = buffs.relPoint or "TOPRIGHT",
      x = buffs.x or -240,
      y = buffs.y or -190,
    },
  })

  ETBC.Mover:Register("AurasDebuffs", debuffAnchor, {
    name = "Auras: Debuffs",
    default = {
      point = debuffs.point or "TOPRIGHT",
      rel = "UIParent",
      relPoint = debuffs.relPoint or "TOPRIGHT",
      x = debuffs.x or -240,
      y = debuffs.y or -260,
    },
  })
end

local function VisibilityAllowed(db)
  if db and db.preview then return true end
  local vis = ETBC.Modules and ETBC.Modules.Visibility
  if vis and vis.Allowed then
    return vis:Allowed("auras")
  end
  return true
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
  icon.icon:SetTexCoord(0, 1, 0, 1)

  icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
  icon.cooldown:SetAllPoints(icon)
  icon.cooldown.noCooldownCount = true
  if icon.cooldown.SetHideCountdownNumbers then
    icon.cooldown:SetHideCountdownNumbers(true)
  end

  icon.timeText = icon:CreateFontString(nil, "OVERLAY")
  icon.timeText:SetPoint("BOTTOM", icon, "BOTTOM", 0, 1)
  icon.timeText:SetFont(SafeFont("Friz Quadrata TT"), 12, "OUTLINE")
  icon.timeText:SetText("")
  icon.timeText:Hide()

  icon.countText = icon:CreateFontString(nil, "OVERLAY")
  icon.countText:SetPoint("TOPRIGHT", icon, "TOPRIGHT", -2, -2)
  icon.countText:SetFont(SafeFont("Friz Quadrata TT"), 12, "OUTLINE")
  icon.countText:SetText("")
  icon.countText:Hide()

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
    local auraIndex = self.data.index
    if (not auraIndex or auraIndex <= 0) and self.data.auraInstanceID then
      auraIndex = ResolveAuraIndexByInstanceID(self.data.kind, self.data.auraInstanceID)
      self.data.index = auraIndex
    end

    if self.data.kind == "BUFF" then
      if auraIndex then
        GameTooltip:SetUnitBuff("player", auraIndex)
      end
    else
      if auraIndex then
        GameTooltip:SetUnitDebuff("player", auraIndex)
      end
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
    local auraIndex = self.data.index
    if (not auraIndex or auraIndex <= 0) and self.data.auraInstanceID then
      auraIndex = ResolveAuraIndexByInstanceID(self.data.kind, self.data.auraInstanceID)
      self.data.index = auraIndex
    end
    if auraIndex then
      CancelUnitBuff("player", auraIndex)
    end
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
  if common.trimIcons then
    icon.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  else
    icon.icon:SetTexCoord(0, 1, 0, 1)
  end

  ApplyFont(icon.timeText, common.durationText, 12)
  ApplyFont(icon.countText, common.countText, 12)

  if common.showCooldownSpiral and data.duration and data.duration > 0 and data.expiration and data.expiration > 0 then
    icon.cooldown:Show()
    if icon.cooldown.SetHideCountdownNumbers then
      icon.cooldown:SetHideCountdownNumbers(true)
    end
    local start = data.expiration - data.duration
    icon.cooldown:SetCooldown(start, data.duration)
  else
    icon.cooldown:Hide()
  end

  if common.border.enabled then
    icon.border:Show()
    local c = common.border.color
    local br, bg, bb, ba = c.r, c.g, c.b, (c.a or 1)

    if common.border.debuffTypeColors and data.kind == "DEBUFF"
      and data.debuffType and DEBUFF_COLORS[data.debuffType] then
      local dc = DEBUFF_COLORS[data.debuffType]
      br, bg, bb, ba = dc.r, dc.g, dc.b, (dc.a or 1)
    end

    if icon.border.SetBackdropBorderColor then
      icon.border:SetBackdropBorderColor(br, bg, bb, ba)
    end
  else
    icon.border:Hide()
  end

  icon.timeText:SetText("")
  icon.timeText:Hide()
end

local function UpdateIconDuration(icon, data, common, now)
  if not icon or not data or not common.showDurationText then
    if icon and icon.timeText then
      icon.timeText:SetText("")
      icon.timeText:Hide()
    end
    return
  end

  if not data.duration or data.duration <= 0 or not data.expiration or data.expiration <= 0 then
    icon.timeText:SetText("")
    icon.timeText:Hide()
    return
  end

  local remaining = math.max(0, data.expiration - now)
  if remaining <= 0 then
    icon.timeText:SetText("")
    icon.timeText:Hide()
    return
  end

  icon.timeText:SetText(FormatTime(remaining))
  icon.timeText:Show()
end

local function CollectLegacyAuras(kind, common)
  local list = {}

  if kind == "BUFF" then
    for i = 1, 40 do
      local name, iconTexture, count, debuffType, duration, expiration, caster = GetUnitBuffByIndex("player", i)
      if not name then break end

      local include = true
      if common.playerOnly and caster and caster ~= "player" then include = false end

      if include then
        local remaining = 0
        if expiration and expiration > 0 then remaining = math.max(0, expiration - GetTime()) end
        list[#list + 1] = {
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
      local name, iconTexture, count, debuffType, duration, expiration, caster = GetUnitDebuffByIndex("player", i)
      if not name then break end

      local include = true
      if common.playerOnly and caster and caster ~= "player" then include = false end

      if include then
        local remaining = 0
        if expiration and expiration > 0 then remaining = math.max(0, expiration - GetTime()) end
        list[#list + 1] = {
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

local function CollectCachedAuras(kind, common)
  local map = auraCache[kind]
  if type(map) ~= "table" or not next(map) then
    return {}
  end

  local list = {}
  for _, aura in pairs(map) do
    if aura then
      local include = true
      if common.playerOnly and aura.caster and aura.caster ~= "player" then
        include = false
      end

      if include then
        local remaining = 0
        if aura.expiration and aura.expiration > 0 then
          remaining = math.max(0, aura.expiration - GetTime())
        end

        list[#list + 1] = {
          kind = aura.kind,
          index = aura.index,
          auraInstanceID = aura.auraInstanceID,
          spellID = aura.spellID,
          name = aura.name,
          texture = aura.texture,
          count = aura.count,
          duration = aura.duration,
          expiration = aura.expiration,
          debuffType = aura.debuffType,
          caster = aura.caster,
          remaining = remaining,
        }
      end
    end
  end

  SortList(list, common.sortMode, common.sortAscending)
  return list
end

local function CollectAuras(kind, common, updateInfo)
  if common.useDeltaAuraUpdates then
    if updateInfo ~= false then
      local cacheUpdated = ApplyAuraDeltaUpdate(updateInfo)
      if not cacheUpdated then
        return CollectLegacyAuras(kind, common)
      end
    end
    return CollectCachedAuras(kind, common)
  end

  return CollectLegacyAuras(kind, common)
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

local function Render(kind, container, activeList, common, layout, updateInfo)
  ClearActive(activeList)

  local dataList = common.preview and BuildPreview(kind) or CollectAuras(kind, common, updateInfo)

  for i = 1, #dataList do
    local data = dataList[i]
    local icon = AcquireIcon()
    icon:SetParent(container)
    icon:ClearAllPoints()
    icon.data = data
    icon.type = common.preview and "preview" or nil

    ApplyVisuals(icon, common, layout, data)

    if common.showCountText and data.count and data.count > 1 then
      icon.countText:SetText(data.count)
      icon.countText:Show()
    else
      icon.countText:SetText("")
      icon.countText:Hide()
    end

    UpdateIconDuration(icon, data, common, GetTime())

    icon:Show()
    activeList[#activeList+1] = icon
  end

  LayoutIcons(container, activeList, layout)
end

local function PositionAnchor(frame, a)
  frame:ClearAllPoints()
  frame:SetPoint(a.point, UIParent, a.relPoint, a.x, a.y)
end

local function Apply()
  EnsureFrames()

  local p = ETBC.db.profile
  local db = p.auras

  local enabled = p.general.enabled and db.enabled
  if not enabled or not VisibilityAllowed(db) then
    ClearAuraCache()
    SetBlizzardAuraFramesSuppressed(false)
    driver:UnregisterAllEvents()
    driver:SetScript("OnUpdate", nil)
    ClearActive(activeBuffs)
    ClearActive(activeDebuffs)
    buffContainer:Hide()
    debuffContainer:Hide()
    SetShownCompat(buffAnchor, false)
    SetShownCompat(debuffAnchor, false)
    driver:Hide()
    return
  end

  SetBlizzardAuraFramesSuppressed(true)
  SetShownCompat(buffAnchor, true)
  SetShownCompat(debuffAnchor, true)
  RegisterMover(db)
  if ETBC.Mover and ETBC.Mover.Apply then
    ETBC.Mover:Apply("AurasBuffs")
    ETBC.Mover:Apply("AurasDebuffs")
  else
    PositionAnchor(buffAnchor, db.buffs.anchor)
    PositionAnchor(debuffAnchor, db.debuffs.anchor)
  end

  buffContainer:ClearAllPoints()
  buffContainer:SetPoint("TOPLEFT", buffAnchor, "TOPLEFT", 0, 0)

  debuffContainer:ClearAllPoints()
  debuffContainer:SetPoint("TOPLEFT", debuffAnchor, "TOPLEFT", 0, 0)

  SetShownCompat(buffContainer, db.buffs.enabled)
  SetShownCompat(debuffContainer, db.debuffs.enabled)

  if not db.useDeltaAuraUpdates then
    ClearAuraCache()
  end

  driver:UnregisterAllEvents()
  driver:RegisterEvent("UNIT_AURA")
  driver:RegisterEvent("PLAYER_ENTERING_WORLD")

  driver:SetScript("OnEvent", function(_, event, unit, updateInfo)
    if event == "UNIT_AURA" and unit ~= "player" then return end
    local updateToken = updateInfo
    if db.useDeltaAuraUpdates and not db.preview then
      ApplyAuraDeltaUpdate(updateInfo)
      updateToken = false
    end

    if db.buffs.enabled then
      Render("BUFF", buffContainer, activeBuffs, db, db.buffs, updateToken)
    else
      ClearActive(activeBuffs)
    end
    if db.debuffs.enabled then
      Render("DEBUFF", debuffContainer, activeDebuffs, db, db.debuffs, updateToken)
    else
      ClearActive(activeDebuffs)
    end
  end)

  if db.showDurationText then
    driver:SetScript("OnUpdate", function(_, elapsed)
      updateTicker = updateTicker + elapsed
      if updateTicker < UPDATE_INTERVAL then return end
      updateTicker = 0

      local now = GetTime()
      for i = 1, #activeBuffs do
        local icon = activeBuffs[i]
        if icon and icon.data then
          UpdateIconDuration(icon, icon.data, db, now)
        end
      end
      for i = 1, #activeDebuffs do
        local icon = activeDebuffs[i]
        if icon and icon.data then
          UpdateIconDuration(icon, icon.data, db, now)
        end
      end
    end)
  else
    driver:SetScript("OnUpdate", nil)
  end

  driver:Show()

  if db.useDeltaAuraUpdates and not db.preview then
    ApplyAuraDeltaUpdate({ isFullUpdate = true })
  end

  if db.buffs.enabled then
    Render("BUFF", buffContainer, activeBuffs, db, db.buffs, db.useDeltaAuraUpdates and false or nil)
  else
    ClearActive(activeBuffs)
  end

  if db.debuffs.enabled then
    Render("DEBUFF", debuffContainer, activeDebuffs, db, db.debuffs, db.useDeltaAuraUpdates and false or nil)
  else
    ClearActive(activeDebuffs)
  end

end

ETBC.ApplyBus:Register("auras", Apply)
ETBC.ApplyBus:Register("general", Apply)
ETBC.ApplyBus:Register("ui", Apply)

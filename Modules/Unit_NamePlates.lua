-- Modules/Unit_NamePlates.lua
-- EnhanceTBC - Nameplate styling and debuff helpers
-- Based on the provided JUI nameplate logic, adapted for EnhanceTBC.

local _, ETBC = ...
local Compat = ETBC.Compat or {}
ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.Nameplates = mod
mod.Internal = mod.Internal or {}
mod.Internal.Shared = mod.Internal.Shared or {}

local unit_nameplates = {}
local runtime = {
  driver = nil,
  hooked = false,
  duel_unit = nil,
}
mod.Internal.Shared.unit_nameplates = unit_nameplates
mod.Internal.Shared.runtime = runtime

local max_player_debuffs = 4

local function GetDB()
  ETBC.db.profile.nameplates = ETBC.db.profile.nameplates or {}
  local db = ETBC.db.profile.nameplates

  if db.enabled == nil then db.enabled = true end

  if db.enemy_nameplate_width == nil then db.enemy_nameplate_width = 109 end
  if db.enemy_nameplate_height == nil then db.enemy_nameplate_height = 12.5 end
  if db.nameplate_texture == nil then db.nameplate_texture = "Blizzard" end
  if db.enemy_nameplate_castbar_width == nil then db.enemy_nameplate_castbar_width = 109 end
  if db.enemy_nameplate_castbar_height == nil then db.enemy_nameplate_castbar_height = 12.5 end

  if db.friendly_nameplate_width == nil then db.friendly_nameplate_width = 42 end
  if db.friendly_nameplate_height == nil then db.friendly_nameplate_height = 12.5 end
  if db.friendly_nameplate_castbar_width == nil then db.friendly_nameplate_castbar_width = 42 end
  if db.friendly_nameplate_castbar_height == nil then db.friendly_nameplate_castbar_height = 12.5 end

  if db.enemy_nameplate_health_text == nil then db.enemy_nameplate_health_text = true end
  if db.enemy_nameplate_health_text_mode == nil then db.enemy_nameplate_health_text_mode = "BOTH" end
  if db.enemy_nameplate_name_font_size == nil then db.enemy_nameplate_name_font_size = 10 end
  if db.enemy_nameplate_health_font_size == nil then db.enemy_nameplate_health_font_size = 9.5 end
  db.enemy_nameplate_health_text_color = db.enemy_nameplate_health_text_color or { r = 1.0, g = 0.82, b = 0.0 }
  db.enemy_nameplate_background_color = db.enemy_nameplate_background_color or { r = 0.02, g = 0.02, b = 0.02 }
  if db.enemy_nameplate_background_alpha == nil then db.enemy_nameplate_background_alpha = 0.85 end
  db.enemy_nameplate_border_color = db.enemy_nameplate_border_color or { r = 0.04, g = 0.04, b = 0.04 }
  if db.enemy_nameplate_border_size == nil then db.enemy_nameplate_border_size = 1 end
  if db.enemy_nameplate_execute_enabled == nil then db.enemy_nameplate_execute_enabled = false end
  if db.enemy_nameplate_execute_threshold == nil then db.enemy_nameplate_execute_threshold = 20 end
  db.enemy_nameplate_execute_color = db.enemy_nameplate_execute_color or { r = 1.0, g = 0.35, b = 0.05 }
  if db.enemy_nameplate_debuff == nil then db.enemy_nameplate_debuff = true end
  if db.enemy_nameplate_debuff_scale == nil then db.enemy_nameplate_debuff_scale = 1.0 end

  if db.enemy_nameplate_player_debuffs == nil then db.enemy_nameplate_player_debuffs = true end
  if db.enemy_nameplate_player_debuffs_scale == nil then db.enemy_nameplate_player_debuffs_scale = 1.0 end
  if db.enemy_nameplate_player_debuffs_padding == nil then db.enemy_nameplate_player_debuffs_padding = 4 end

  if db.enemy_nameplate_stance == nil then db.enemy_nameplate_stance = true end
  if db.enemy_nameplate_stance_scale == nil then db.enemy_nameplate_stance_scale = 1.0 end

  if db.class_colored_nameplates == nil then db.class_colored_nameplates = true end
  if db.friendly_nameplate_default_color == nil then db.friendly_nameplate_default_color = false end
  if db.nameplate_unit_target_color == nil then db.nameplate_unit_target_color = true end
  db.nameplate_unit_target_color_value = db.nameplate_unit_target_color_value or { r = 0.1, g = 0.55, b = 1.0 }
  if db.totem_nameplate_colors == nil then db.totem_nameplate_colors = true end
  if db.useAuraDeltaUpdates == nil then db.useAuraDeltaUpdates = true end
  if db.useSpellIDAuraLookup == nil then db.useSpellIDAuraLookup = true end

  -- Schema 2 keeps legacy scalar settings authoritative while introducing
  -- component/category policy records. The backup is intentionally retained
  -- for one migration generation so a profile can be inspected or recovered.
  if (tonumber(db.schemaVersion) or 0) < 2 then
    if not db.legacyBackup then
      db.legacyBackup = {
        enemy_nameplate_width = db.enemy_nameplate_width,
        enemy_nameplate_height = db.enemy_nameplate_height,
        friendly_nameplate_width = db.friendly_nameplate_width,
        friendly_nameplate_height = db.friendly_nameplate_height,
        enemy_nameplate_castbar_width = db.enemy_nameplate_castbar_width,
        enemy_nameplate_castbar_height = db.enemy_nameplate_castbar_height,
        enemy_nameplate_health_text = db.enemy_nameplate_health_text,
        enemy_nameplate_debuff = db.enemy_nameplate_debuff,
      }
    end
    db.schemaVersion = 2
  end
  db.selectedPreset = db.selectedPreset or "PVE"
  if db.autoPreset == nil then db.autoPreset = false end
  db.power = db.power or {}
  if db.power.enabled == nil then db.power.enabled = true end
  if db.power.height == nil then db.power.height = 6 end
  db.power.textMode = db.power.textMode or "NONE"
  db.power.targetTextMode = db.power.targetTextMode or "PERCENT"
  if db.power.friendlyAlways == nil then db.power.friendlyAlways = false end
  if db.power.showEnemyPlayers == nil then db.power.showEnemyPlayers = true end
  if db.power.showEnemyNPCs == nil then db.power.showEnemyNPCs = true end
  if db.power.showFriendlyTarget == nil then db.power.showFriendlyTarget = true end
  db.targeting = db.targeting or {}
  if db.targeting.targetScale == nil then db.targeting.targetScale = 1.08 end
  if db.targeting.targetAlpha == nil then db.targeting.targetAlpha = 1 end
  if db.targeting.nonTargetAlpha == nil then db.targeting.nonTargetAlpha = 0.82 end
  if db.targeting.focusGlow == nil then db.targeting.focusGlow = true end
  if db.targeting.showTargetOfTarget == nil then db.targeting.showTargetOfTarget = true end
  db.threat = db.threat or { enabled = true, showPercent = false }
  db.indicators = db.indicators or { classification = true, level = true, targetOfTarget = true }
  db.categories = db.categories or {}
  local categoryDefaults = {
    enemyPlayers = { health = true, power = true, cast = true, alpha = 1, scale = 1 },
    enemyNPCs = { health = true, power = true, cast = true, alpha = 1, scale = 1 },
    friendlyPlayers = { health = true, power = false, cast = true, alpha = 0.9, scale = 1 },
    friendlyNPCs = { health = true, power = false, cast = true, alpha = 0.85, scale = 1 },
    targetFocus = { health = true, power = true, cast = true, alpha = 1, scale = 1.08 },
    bossesElitesRares = { health = true, power = true, cast = true, alpha = 1, scale = 1.05 },
    petsGuardians = { health = true, power = false, cast = false, alpha = 0.8, scale = 0.9 },
    totems = { health = true, power = false, cast = false, alpha = 0.9, scale = 0.85 },
    minorUnits = { health = true, power = false, cast = false, alpha = 0.65, scale = 0.8 },
  }
  for key, defaults in pairs(categoryDefaults) do
    db.categories[key] = db.categories[key] or {}
    for option, value in pairs(defaults) do
      if db.categories[key][option] == nil then db.categories[key][option] = value end
    end
  end

  return db
end

local function InInstance()
  if not IsInInstance then
    return false, "none"
  end
  local inInst, instType = IsInInstance()
  return not not inInst, instType
end

local function IsRestrictedFrame(frame)
  return frame and frame.IsForbidden and frame:IsForbidden()
end

local function ShouldIgnoreNameplate(nameplate)
  if not nameplate or not nameplate.UnitFrame then return true end
  if nameplate.Plater or nameplate.unitFramePlater
    or nameplate.UnitFrame.Plater or nameplate.UnitFrame.unitFramePlater then
    return true
  end
  if IsRestrictedFrame(nameplate) or IsRestrictedFrame(nameplate.UnitFrame) then
    return true
  end
  if IsRestrictedFrame(nameplate.UnitFrame.healthBar) or IsRestrictedFrame(nameplate.UnitFrame.castBar) then
    return true
  end
  return false
end

local function IsSecureUpdateBlocked()
  return InCombatLockdown and InCombatLockdown()
end

local function SafeUnitIsUnit(unit, other_unit)
  if type(unit) ~= "string" or unit == "" then return false end
  if type(other_unit) ~= "string" or other_unit == "" then return false end
  return UnitIsUnit(unit, other_unit)
end

local function IsPlaterLoaded()
  if C_AddOns and C_AddOns.IsAddOnLoaded then
    return C_AddOns.IsAddOnLoaded("Plater")
  end
  if IsAddOnLoaded then
    return IsAddOnLoaded("Plater")
  end
  return false
end

local function ApplyFont(fs, size)
  if not fs or not fs.SetFont then return end
  if ETBC.Theme and ETBC.Theme.ApplyFontString then
    ETBC.Theme:ApplyFontString(fs, nil, size)
  else
    fs:SetFont("Fonts\\FRIZQT__.TTF", size or 10, "OUTLINE")
  end
end

local function ApplyBackdrop(frame)
  if not frame or not frame.SetBackdrop then return end
  frame:SetBackdrop({
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame:SetBackdropBorderColor(0.04, 0.04, 0.04)
end

local function ApplyBackdropAlt(frame)
  if not frame or not frame.SetBackdrop then return end
  frame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame:SetBackdropColor(0, 0, 0, 0.65)
  frame:SetBackdropBorderColor(0.04, 0.04, 0.04)
end

local function GetStatusbarTexture()
  local textureKey = GetDB().nameplate_texture or "Blizzard"
  if ETBC.LSM and ETBC.LSM.Fetch then
    local ok, tex = pcall(ETBC.LSM.Fetch, ETBC.LSM, "statusbar", textureKey)
    if ok and tex then return tex end
  end
  if ETBC.Theme and ETBC.Theme.FetchStatusbar then
    return ETBC.Theme:FetchStatusbar()
  end
  if ETBC.LSM and ETBC.LSM.Fetch then
    local ok, tex = pcall(ETBC.LSM.Fetch, ETBC.LSM, "statusbar", "Blizzard")
    if ok and tex then return tex end
  end
  return "Interface\\TargetingFrame\\UI-StatusBar"
end

local function UpdateHealthBorder(statusbar, db)
  if not statusbar then return end
  if not statusbar.etbc_border then
    statusbar.etbc_border = {}
    for i = 1, 4 do
      local texture = statusbar:CreateTexture(nil, "OVERLAY")
      texture:SetTexture("Interface\\Buttons\\WHITE8x8")
      statusbar.etbc_border[i] = texture
    end
  end

  local size = math.max(0, tonumber(db.enemy_nameplate_border_size) or 1)
  local color = db.enemy_nameplate_border_color or { r = 0.04, g = 0.04, b = 0.04 }
  local top, bottom, left, right = unpack(statusbar.etbc_border)
  for _, texture in ipairs(statusbar.etbc_border) do
    texture:SetVertexColor(color.r or 0.04, color.g or 0.04, color.b or 0.04, 1)
    texture:SetShown(size > 0)
    texture:ClearAllPoints()
  end
  if size <= 0 then return end
  top:SetPoint("TOPLEFT", statusbar, "TOPLEFT", 0, 0)
  top:SetPoint("TOPRIGHT", statusbar, "TOPRIGHT", 0, 0)
  top:SetHeight(size)
  bottom:SetPoint("BOTTOMLEFT", statusbar, "BOTTOMLEFT", 0, 0)
  bottom:SetPoint("BOTTOMRIGHT", statusbar, "BOTTOMRIGHT", 0, 0)
  bottom:SetHeight(size)
  left:SetPoint("TOPLEFT", statusbar, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", statusbar, "BOTTOMLEFT", 0, 0)
  left:SetWidth(size)
  right:SetPoint("TOPRIGHT", statusbar, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", statusbar, "BOTTOMRIGHT", 0, 0)
  right:SetWidth(size)
end

local function Trim(str)
  if not str then return str end
  if strtrim then return strtrim(str) end
  return (str:gsub("^%s+", ""):gsub("%s+$", ""))
end

local legacyUnitAura = _G["UnitAura"]

local function GetUnitAuraByIndex(unit, index, filter)
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex and AuraUtil and AuraUtil.UnpackAuraData then
    local auraData = C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
    if auraData then
      return AuraUtil.UnpackAuraData(auraData)
    end
    return nil
  end

  if type(legacyUnitAura) == "function" then
    return legacyUnitAura(unit, index, filter)
  end

  return nil
end

local function FindAuraByName(name, unit, filter)
  if not name or not unit then return nil end
  if AuraUtil and AuraUtil.FindAuraByName then
    return AuraUtil.FindAuraByName(name, unit, filter)
  end
  for i = 1, 40 do
    local aura_name = GetUnitAuraByIndex(unit, i, filter)
    if aura_name == name then return true end
    if not aura_name then break end
  end
  return nil
end

local function GetSpellInfoByID(spellID)
  if Compat and Compat.GetSpellInfoByID then
    local info = Compat.GetSpellInfoByID(spellID)
    if info and info.name then
      return info
    end
  end

  return nil
end

mod.Internal.Shared.GetSpellInfoByID = GetSpellInfoByID

local function GetDataInternal()
  return mod.Internal and mod.Internal.Data
end

local function BuildData()
  local H = GetDataInternal()
  if H and H.BuildData then
    return H.BuildData()
  end
end

local function FindTrackedAbsorbAura(unit)
  local H = GetDataInternal()
  if H and H.FindTrackedAbsorbAura then
    return H.FindTrackedAbsorbAura(unit)
  end
  return nil, nil
end

local function FindPriorityTrackedDebuffAura(unit)
  local H = GetDataInternal()
  if H and H.FindPriorityTrackedDebuffAura then
    return H.FindPriorityTrackedDebuffAura(unit)
  end
  return nil, nil
end

local function ShouldRefreshAurasFromUpdateInfo(updateInfo, db)
  local H = GetDataInternal()
  if H and H.ShouldRefreshAurasFromUpdateInfo then
    return H.ShouldRefreshAurasFromUpdateInfo(updateInfo, db)
  end
  return true
end

local function GetFormattedDebuff(name)
  local H = GetDataInternal()
  return H and H.GetFormattedDebuff and H.GetFormattedDebuff(name) or nil
end

local function GetFormattedInterrupt(name)
  local H = GetDataInternal()
  return H and H.GetFormattedInterrupt and H.GetFormattedInterrupt(name) or nil
end

local function GetFormattedPlayerDebuff(name)
  local H = GetDataInternal()
  return H and H.GetFormattedPlayerDebuff and H.GetFormattedPlayerDebuff(name) or nil
end

local function GetFormattedAbsorbBuff(name)
  local H = GetDataInternal()
  return H and H.GetFormattedAbsorbBuff and H.GetFormattedAbsorbBuff(name) or nil
end

local function GetTotemColorByName(unit_name)
  local H = GetDataInternal()
  return H and H.GetTotemColorByName and H.GetTotemColorByName(unit_name) or nil
end

local function GetStanceData(spell_id)
  local H = GetDataInternal()
  return H and H.GetStanceData and H.GetStanceData(spell_id) or nil
end

local function IsFriendlyNameplate(nameplate, unit)
  if nameplate and unit and unit ~= "player" then
    if UnitCanAttack("player", unit) then return false end
    if nameplate.GetWidth and nameplate:GetWidth() < 100 then return true end

    local unit_reaction = UnitReaction(unit, "player")
    if unit_reaction and unit_reaction > 4 then
      return true
    end
  end

  return false
end

mod.Internal.Shared.IsFriendlyNameplate = IsFriendlyNameplate

local function GetRenderInternal()
  return mod.Internal and mod.Internal.Render
end

local function SetNameplateHealthBarText(statusbar, unit)
  local H = GetRenderInternal()
  if H and H.SetNameplateHealthBarText then
    return H.SetNameplateHealthBarText(statusbar, unit)
  end
end

local function SetNameplateHealthBarColor(nameplate, statusbar, unit)
  local H = GetRenderInternal()
  if H and H.SetNameplateHealthBarColor then
    return H.SetNameplateHealthBarColor(nameplate, statusbar, unit)
  end
end

local function SetNameplateAbsorb(nameplate, unit)
  local H = GetRenderInternal()
  if H and H.SetNameplateAbsorb then
    return H.SetNameplateAbsorb(nameplate, unit)
  end
end

local function SetNameplateCastBar(nameplate, castbar)
  local H = GetRenderInternal()
  if H and H.SetNameplateCastBar then
    return H.SetNameplateCastBar(nameplate, castbar)
  end
end

local function SetNameplateSize(nameplate, statusbar, unit)
  local H = GetRenderInternal()
  if H and H.SetNameplateSize then
    return H.SetNameplateSize(nameplate, statusbar, unit)
  end
end

local function SetNameplatePlayerDebuffs(nameplate, unit)
  local H = GetRenderInternal()
  if H and H.SetNameplatePlayerDebuffs then
    return H.SetNameplatePlayerDebuffs(nameplate, unit)
  end
end

local function SetNameplateUnitDebuff(nameplate, unit)
  local H = GetRenderInternal()
  if H and H.SetNameplateUnitDebuff then
    return H.SetNameplateUnitDebuff(nameplate, unit)
  end
end

local function GetNameplateUnit(unitFrame)
  if not unitFrame then return nil end
  local parent = unitFrame.GetParent and unitFrame:GetParent() or nil
  return unitFrame.displayedUnit or unitFrame.unit or unitFrame.unitToken
    or (parent and parent.unitToken) or nil
end

function mod.StyleUnitNameplate(_, unit)
  if not unit then return end
  if IsPlaterLoaded() then return end

  local unit_nameplate = C_NamePlate.GetNamePlateForUnit(unit, false)
  if not unit_nameplate or not unit_nameplate.UnitFrame then return end
  if ShouldIgnoreNameplate(unit_nameplate) then return end
  if IsSecureUpdateBlocked() then return end

  local unit_guid = UnitGUID(unit)
  if not unit_guid then return end

  if not unit_nameplate.nameplate_events then
    unit_nameplate.nameplate_events = CreateFrame("Frame", nil, unit_nameplate)
  end

  local previousFrame = unit_nameplates[unit_guid]
  if previousFrame and previousFrame ~= unit_nameplate.UnitFrame then
    local previousPlate = previousFrame.GetParent and previousFrame:GetParent()
    if previousPlate and previousPlate.nameplate_events then
      previousPlate.nameplate_events:UnregisterAllEvents()
    end
    if mod.Internal.Power then mod.Internal.Power:Reset(previousFrame) end
    if mod.Internal.Casts then mod.Internal.Casts:Reset(previousFrame) end
    if mod.Internal.Indicators then mod.Internal.Indicators:Reset(previousFrame) end
  end
  unit_nameplates[unit_guid] = unit_nameplate.UnitFrame

  if unit ~= "player" and not unit_nameplate.nameplate_events:IsEventRegistered("UNIT_HEALTH") then
    -- Keep these registrations explicit so the build contract validator can
    -- audit every event. Build 68575 does not expose the later
    -- UNIT_SPELLCAST_(NOT_)INTERRUPTIBLE events.
    unit_nameplate.nameplate_events:RegisterUnitEvent("UNIT_HEALTH", unit)
    unit_nameplate.nameplate_events:RegisterUnitEvent("UNIT_MAXHEALTH", unit)
    unit_nameplate.nameplate_events:RegisterUnitEvent("UNIT_POWER_UPDATE", unit)
    unit_nameplate.nameplate_events:RegisterUnitEvent("UNIT_MAXPOWER", unit)
    unit_nameplate.nameplate_events:RegisterUnitEvent("UNIT_DISPLAYPOWER", unit)
    unit_nameplate.nameplate_events:RegisterUnitEvent("UNIT_THREAT_LIST_UPDATE", unit)
    unit_nameplate.nameplate_events:RegisterUnitEvent("UNIT_AURA", unit)
    unit_nameplate.nameplate_events:RegisterUnitEvent("UNIT_SPELLCAST_START", unit)
    unit_nameplate.nameplate_events:RegisterUnitEvent("UNIT_SPELLCAST_STOP", unit)
    unit_nameplate.nameplate_events:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", unit)
    unit_nameplate.nameplate_events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", unit)
    unit_nameplate.nameplate_events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", unit)
  end

  local unit_nameplate_health_bar = unit_nameplate.UnitFrame.healthBar
  local unit_nameplate_container = unit_nameplate.UnitFrame.HealthBarsContainer
  local unit_nameplate_cast_bar = unit_nameplate.UnitFrame.castBar
  local unit_nameplate_name = unit_nameplate.UnitFrame.name
    or (unit_nameplate_health_bar and unit_nameplate_health_bar.unitNameFontString)
  if not unit_nameplate_health_bar or not unit_nameplate_name then return end

  if not unit_nameplate.modified then
    unit_nameplate_name:SetWidth((GetDB().enemy_nameplate_width or 109) - 20)
    unit_nameplate_name:SetPoint("BOTTOMLEFT", unit_nameplate_health_bar, "TOPLEFT", -1, 5)
    ApplyFont(unit_nameplate_name, GetDB().enemy_nameplate_name_font_size or 10)
    unit_nameplate_name:SetJustifyH("LEFT")

    hooksecurefunc(unit_nameplate_name, "Show", function(self)
      self:SetTextColor(1, 1, 1)
    end)

    hooksecurefunc(unit_nameplate_name, "Hide", function(self)
      self:Show()
    end)

    local unit_nameplate_level = unit_nameplate.UnitFrame.LevelFrame or unit_nameplate.UnitFrame.levelFrame
    local level_text = unit_nameplate_level
      and (unit_nameplate_level.LevelText or unit_nameplate_level.levelText)
    local high_level_texture = unit_nameplate_level
      and (unit_nameplate_level.HighLevelTexture or unit_nameplate_level.highLevelTexture)

    if unit_nameplate_level then
      unit_nameplate_level:SetPoint("BOTTOMRIGHT", unit_nameplate_health_bar, "TOPRIGHT", 1, 2.5)
    end
    if level_text then
      level_text:SetHeight(unit_nameplate_name:GetHeight())
      ApplyFont(level_text, 9)
      level_text:SetJustifyH("RIGHT")
    end
    if high_level_texture then
      high_level_texture:SetPoint("TOPLEFT", 1.25, -1.25)
      high_level_texture:SetPoint("BOTTOMRIGHT", -1.25, 1.25)
    end

    local raid_target = unit_nameplate.UnitFrame.RaidTargetFrame or unit_nameplate.UnitFrame.raidTargetFrame
    if raid_target then
      raid_target:ClearAllPoints()
      raid_target:SetPoint("RIGHT", unit_nameplate_name, "LEFT", -3, 0)
    end

    local container_border = unit_nameplate_container
      and (unit_nameplate_container.border or unit_nameplate_container.Border)
    if container_border then container_border:Hide() end
    local health_background = unit_nameplate_health_bar.background
      or unit_nameplate_health_bar.bgTexture
      or unit_nameplate_health_bar.Background
    if health_background then health_background:Hide() end

    unit_nameplate.UnitFrame.healthBarWrapper = CreateFrame("Frame", nil, unit_nameplate.UnitFrame)
    unit_nameplate.UnitFrame.healthBarWrapper:SetPoint("BOTTOM", 0, 4)

    unit_nameplate_health_bar.backdrop = CreateFrame("Frame", nil, unit_nameplate_health_bar, "BackdropTemplate")
    ApplyBackdropAlt(unit_nameplate_health_bar.backdrop)

    -- The Blizzard background is hidden above, so provide a texture-backed
    -- replacement on the status bar's BACKGROUND layer. A child backdrop frame
    -- has no size until explicitly anchored and can also sit above the status
    -- fill depending on frame level; this texture reliably fills only the
    -- missing-health portion behind the bar.
    unit_nameplate_health_bar.etbc_background =
      unit_nameplate_health_bar:CreateTexture(nil, "BACKGROUND")
    unit_nameplate_health_bar.etbc_background:SetAllPoints(unit_nameplate_health_bar)
    unit_nameplate_health_bar.etbc_background:SetTexture("Interface\\Buttons\\WHITE8x8")
    unit_nameplate_health_bar.etbc_background:SetVertexColor(0.02, 0.02, 0.02, 0.85)

    unit_nameplate_health_bar.focus_texture = CreateFrame("Frame", nil, unit_nameplate_health_bar)
    unit_nameplate_health_bar.focus_texture:SetAllPoints()
    unit_nameplate_health_bar.focus_texture:SetFrameStrata("LOW")
    unit_nameplate_health_bar.focus_texture:Hide()

    unit_nameplate_health_bar.focus_texture.texture_top =
      unit_nameplate_health_bar.focus_texture:CreateTexture(nil, "OVERLAY")
    unit_nameplate_health_bar.focus_texture.texture_top:SetPoint(
      "BOTTOMLEFT", unit_nameplate_health_bar, "TOPLEFT", 0, 0
    )
    unit_nameplate_health_bar.focus_texture.texture_top:SetPoint(
      "TOPRIGHT", unit_nameplate_health_bar, "TOPRIGHT", 0, 15
    )
    unit_nameplate_health_bar.focus_texture.texture_top:SetTexture(952656)
    unit_nameplate_health_bar.focus_texture.texture_top:SetTexCoord(0.04, 0.74, 0.7, 0.651)
    unit_nameplate_health_bar.focus_texture.texture_top:SetBlendMode("ADD")
    unit_nameplate_health_bar.focus_texture.texture_top:SetVertexColor(1, 0.72, 0.12, 0.78)

    unit_nameplate_health_bar.focus_texture.texture_bottom =
      unit_nameplate_health_bar.focus_texture:CreateTexture(nil, "OVERLAY")
    unit_nameplate_health_bar.focus_texture.texture_bottom:SetPoint(
      "TOPLEFT", unit_nameplate_health_bar, "BOTTOMLEFT", 0, 0
    )
    unit_nameplate_health_bar.focus_texture.texture_bottom:SetPoint(
      "BOTTOMRIGHT", unit_nameplate_health_bar, "BOTTOMRIGHT", 0, -15
    )
    unit_nameplate_health_bar.focus_texture.texture_bottom:SetTexture(952656)
    unit_nameplate_health_bar.focus_texture.texture_bottom:SetTexCoord(0.04, 0.74, 0.651, 0.7)
    unit_nameplate_health_bar.focus_texture.texture_bottom:SetBlendMode("ADD")
    unit_nameplate_health_bar.focus_texture.texture_bottom:SetVertexColor(1, 0.72, 0.12, 0.78)

    if container_border and type(container_border.SetVertexColor) == "function" then
      hooksecurefunc(container_border, "SetVertexColor", function(_, r, g, b)
        if r == 1 and g == 1 and b == 1 then
          unit_nameplate_health_bar.focus_texture:Show()
          unit_nameplate_health_bar.backdrop:SetBackdropBorderColor(1, 1, 1)
        else
          unit_nameplate_health_bar.focus_texture:Hide()
          unit_nameplate_health_bar.backdrop:SetBackdropBorderColor(0.04, 0.04, 0.04)
        end
      end)
    end

    unit_nameplate_health_bar.unit_health_text = CreateFrame("Frame", nil, unit_nameplate_health_bar)
    unit_nameplate_health_bar.unit_health_text:Hide()

    unit_nameplate_health_bar.unit_health_text.text_left =
      unit_nameplate_health_bar.unit_health_text:CreateFontString(nil, "OVERLAY")
    unit_nameplate_health_bar.unit_health_text.text_left:SetPoint(
      "BOTTOMLEFT", unit_nameplate_health_bar, "BOTTOMLEFT", 5, 0
    )
    unit_nameplate_health_bar.unit_health_text.text_left:SetPoint(
      "TOPRIGHT", unit_nameplate_health_bar, "TOP", 0, 0
    )
    unit_nameplate_health_bar.unit_health_text.text_left:SetJustifyH("LEFT")
    unit_nameplate_health_bar.unit_health_text.text_left:SetJustifyV("MIDDLE")
    unit_nameplate_health_bar.unit_health_text.text_left:SetTextColor(1, 0.82, 0)
    ApplyFont(unit_nameplate_health_bar.unit_health_text.text_left, GetDB().enemy_nameplate_health_font_size or 9.5)

    unit_nameplate_health_bar.unit_health_text.text_right =
      unit_nameplate_health_bar.unit_health_text:CreateFontString(nil, "OVERLAY")
    unit_nameplate_health_bar.unit_health_text.text_right:SetPoint(
      "BOTTOMLEFT", unit_nameplate_health_bar, "BOTTOM", 0, 0
    )
    unit_nameplate_health_bar.unit_health_text.text_right:SetPoint(
      "TOPRIGHT", unit_nameplate_health_bar, "TOPRIGHT", -5, 0
    )
    unit_nameplate_health_bar.unit_health_text.text_right:SetJustifyH("RIGHT")
    unit_nameplate_health_bar.unit_health_text.text_right:SetJustifyV("MIDDLE")
    unit_nameplate_health_bar.unit_health_text.text_right:SetTextColor(1, 0.82, 0)
    ApplyFont(unit_nameplate_health_bar.unit_health_text.text_right, GetDB().enemy_nameplate_health_font_size or 9.5)

    unit_nameplate_health_bar.absorb = CreateFrame("Frame", nil, unit_nameplate_health_bar)
    unit_nameplate_health_bar.absorb:SetSize(16, unit_nameplate_health_bar:GetHeight())
    unit_nameplate_health_bar.absorb:Hide()

    unit_nameplate_health_bar.absorb.shield_texture =
      unit_nameplate_health_bar.absorb:CreateTexture(nil, "OVERLAY")
    unit_nameplate_health_bar.absorb.shield_texture:SetAllPoints()
    unit_nameplate_health_bar.absorb.shield_texture:SetTexture(798064)

    unit_nameplate_health_bar.absorb.over_absorb_texture =
      unit_nameplate_health_bar.absorb:CreateTexture(nil, "OVERLAY")
    unit_nameplate_health_bar.absorb.over_absorb_texture:SetSize(
      12, unit_nameplate_health_bar.absorb:GetHeight()
    )
    unit_nameplate_health_bar.absorb.over_absorb_texture:SetPoint("RIGHT", unit_nameplate_health_bar, 6, 0)
    unit_nameplate_health_bar.absorb.over_absorb_texture:SetTexture(798066)
    unit_nameplate_health_bar.absorb.over_absorb_texture:SetBlendMode("ADD")

    if unit_nameplate_cast_bar then
    unit_nameplate.UnitFrame.castBarWrapper = CreateFrame("Frame", nil, unit_nameplate.UnitFrame)
    unit_nameplate.UnitFrame.castBarWrapper:SetPoint(
      "TOP", unit_nameplate.UnitFrame.healthBarWrapper, "BOTTOM", 0, -3
    )

    unit_nameplate_cast_bar.backdrop = CreateFrame(
      "Frame", nil, unit_nameplate_cast_bar, "BackdropTemplate"
    )
    ApplyBackdropAlt(unit_nameplate_cast_bar.backdrop)

    unit_nameplate_cast_bar.etbc_background =
      unit_nameplate_cast_bar:CreateTexture(nil, "BACKGROUND")
    unit_nameplate_cast_bar.etbc_background:SetAllPoints(unit_nameplate_cast_bar)
    unit_nameplate_cast_bar.etbc_background:SetTexture("Interface\\Buttons\\WHITE8x8")
    unit_nameplate_cast_bar.etbc_background:SetVertexColor(0.02, 0.02, 0.02, 0.85)

    unit_nameplate_cast_bar.icon_backdrop = CreateFrame(
      "Frame", nil, unit_nameplate_cast_bar, "BackdropTemplate"
    )
    ApplyBackdrop(unit_nameplate_cast_bar.icon_backdrop)

    hooksecurefunc(unit_nameplate_cast_bar, "Show", function()
      SetNameplateCastBar(unit_nameplate, unit_nameplate_cast_bar)
    end)

    if unit_nameplate_cast_bar.BorderShield then
      hooksecurefunc(unit_nameplate_cast_bar.BorderShield, "Show", function()
        unit_nameplate_cast_bar:SetStatusBarColor(0.85, 0.85, 0.85, 1, "nameplate_cast_bar")
      end)

      hooksecurefunc(unit_nameplate_cast_bar.BorderShield, "Hide", function()
        unit_nameplate_cast_bar:SetStatusBarColor(0.9, 0.7, 0, 1, "nameplate_cast_bar")
      end)
    end

    hooksecurefunc(unit_nameplate_cast_bar, "SetStatusBarColor", function(_, _r, g, _b, _, flag)
      if unit_nameplate_cast_bar.notInterruptible and flag ~= "nameplate_cast_bar" then
        unit_nameplate_cast_bar:SetStatusBarColor(0.85, 0.85, 0.85, 1, "nameplate_cast_bar")
      elseif g == 1 and flag ~= "nameplate_cast_bar" then
        unit_nameplate_cast_bar:SetStatusBarColor(0.9, 0.7, 0, 1, "nameplate_cast_bar")
      end
    end)

    unit_nameplate_cast_bar:HookScript("OnEvent", function(self, event)
      if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        if self.Text then self.Text:Show() end
      end
    end)

    if unit_nameplate_cast_bar.Icon then
      unit_nameplate_cast_bar.Icon:SetTexCoord(0.07, 0.94, 0.07, 0.94)
    end

    if unit_nameplate_cast_bar.Spark then unit_nameplate_cast_bar.Spark.offsetY = 0 end
    if unit_nameplate_cast_bar.Flash then
      unit_nameplate_cast_bar.Flash:SetTexture(nil)
      hooksecurefunc(unit_nameplate_cast_bar.Flash, "Show", function()
        unit_nameplate_cast_bar.Flash:Hide()
      end)
    end

    if unit_nameplate_cast_bar.Text then ApplyFont(unit_nameplate_cast_bar.Text, 10) end

    if unit_nameplate_cast_bar.BorderShield then
      unit_nameplate_cast_bar.BorderShield:SetTexture(nil)
    end
    end

    unit_nameplate_health_bar.unit_debuff = CreateFrame("Frame", nil, unit_nameplate_health_bar)
    unit_nameplate_health_bar.unit_debuff:Hide()

    unit_nameplate_health_bar.unit_debuff:SetSize(26, 26)
    unit_nameplate_health_bar.unit_debuff:SetPoint("BOTTOMLEFT", unit_nameplate_health_bar, "BOTTOMRIGHT", 8, 0)

    unit_nameplate_health_bar.unit_debuff.texture =
      unit_nameplate_health_bar.unit_debuff:CreateTexture(nil, "BACKGROUND")
    unit_nameplate_health_bar.unit_debuff.texture:SetAllPoints()
    unit_nameplate_health_bar.unit_debuff.texture:SetTexCoord(0.07, 0.94, 0.07, 0.94)

    unit_nameplate_health_bar.unit_debuff.backdrop = CreateFrame(
      "Frame", nil, unit_nameplate_health_bar.unit_debuff, "BackdropTemplate"
    )
    ApplyBackdrop(unit_nameplate_health_bar.unit_debuff.backdrop)

    unit_nameplate_health_bar.unit_debuff.cooldown = CreateFrame(
      "Cooldown", nil, unit_nameplate_health_bar.unit_debuff, "CooldownFrameTemplate"
    )
    unit_nameplate_health_bar.unit_debuff.cooldown:SetReverse(true)
    unit_nameplate_health_bar.unit_debuff.cooldown:Hide()

    unit_nameplate_health_bar.unit_debuff.cooldown:HookScript("OnCooldownDone", function()
      if unit_nameplate_health_bar.unit_debuff.current_debuff
        and unit_nameplate_health_bar.unit_debuff.current_debuff.interrupt then
        unit_nameplate_health_bar.unit_debuff.current_debuff = nil
        unit_nameplate_health_bar.unit_debuff.cooldown_started = -1
        unit_nameplate_health_bar.unit_debuff.cooldown_duration = -1
        unit_nameplate_health_bar.unit_debuff.filter = nil

        unit_nameplate_health_bar.unit_debuff:Hide()
        unit_nameplate_health_bar.unit_debuff.cooldown:Hide()

        SetNameplateUnitDebuff(unit_nameplate, unit_nameplate.UnitFrame.unit)
      end
    end)

    unit_nameplate_health_bar.unit_debuff.current_debuff = nil
    unit_nameplate_health_bar.unit_debuff.cooldown_started = -1
    unit_nameplate_health_bar.unit_debuff.cooldown_duration = -1
    unit_nameplate_health_bar.unit_debuff.filter = nil

    unit_nameplate_health_bar.player_debuffs = CreateFrame(
      "Frame", nil, unit_nameplate_health_bar
    )
    unit_nameplate_health_bar.player_debuffs:SetSize(GetDB().enemy_nameplate_width or 109, 18)
    unit_nameplate_health_bar.player_debuffs:SetPoint(
      "BOTTOMLEFT", unit_nameplate_health_bar, "TOPLEFT", 0, 20
    )

    for _ = 1, max_player_debuffs do
      local player_debuff = CreateFrame(
        "Frame", nil, unit_nameplate_health_bar.player_debuffs
      )
      player_debuff:SetSize(20, 16)
      player_debuff:Hide()

      player_debuff.current_debuff = nil
      player_debuff.cooldown_started = -1
      player_debuff.cooldown_duration = -1
      player_debuff.aura_count = -1

      player_debuff.texture = player_debuff:CreateTexture(nil, "BACKGROUND")
      player_debuff.texture:SetAllPoints()
      player_debuff.texture:SetTexCoord(0.07, 0.94, 0.07, 0.94)

      player_debuff.backdrop = CreateFrame(
        "Frame", nil, player_debuff, "BackdropTemplate"
      )
      ApplyBackdrop(player_debuff.backdrop)

      player_debuff.aura_count_text = player_debuff:CreateFontString(nil, "OVERLAY")
      player_debuff.aura_count_text:SetSize(10, 10)
      player_debuff.aura_count_text:SetPoint("BOTTOMRIGHT", -0.75, 0.25)
      player_debuff.aura_count_text:SetJustifyH("RIGHT")
      player_debuff.aura_count_text:SetJustifyV("MIDDLE")
      ApplyFont(player_debuff.aura_count_text, 9)
      player_debuff.aura_count_text:SetText("")

      player_debuff.cooldown = CreateFrame(
        "Cooldown", nil, player_debuff, "CooldownFrameTemplate"
      )
      player_debuff.cooldown:SetReverse(true)
      player_debuff.cooldown:Hide()
    end

    unit_nameplate_health_bar.unit_stance = CreateFrame("Frame", nil, unit_nameplate_health_bar)
    unit_nameplate_health_bar.unit_stance:SetSize(26, 26)
    unit_nameplate_health_bar.unit_stance:SetPoint("BOTTOMRIGHT", unit_nameplate_health_bar, "BOTTOMLEFT", -8, 0)
    unit_nameplate_health_bar.unit_stance:Hide()

    unit_nameplate_health_bar.unit_stance.texture =
      unit_nameplate_health_bar.unit_stance:CreateTexture(nil, "BACKGROUND")
    unit_nameplate_health_bar.unit_stance.texture:SetAllPoints()
    unit_nameplate_health_bar.unit_stance.texture:SetTexCoord(0.07, 0.94, 0.07, 0.94)

    unit_nameplate_health_bar.unit_stance.backdrop = CreateFrame(
      "Frame", nil, unit_nameplate_health_bar.unit_stance, "BackdropTemplate"
    )
    ApplyBackdrop(unit_nameplate_health_bar.unit_stance.backdrop)

    unit_nameplate.nameplate_events:HookScript("OnEvent", function(_, event, _, updateInfo)
      if event == "UNIT_AURA" and unit_nameplate.UnitFrame then
        local db = GetDB()
        if not ShouldRefreshAurasFromUpdateInfo(updateInfo, db) then
          return
        end
        local activeUnit = GetNameplateUnit(unit_nameplate.UnitFrame)
        SetNameplateUnitDebuff(unit_nameplate, activeUnit)
        SetNameplatePlayerDebuffs(unit_nameplate, activeUnit)
        SetNameplateAbsorb(unit_nameplate, activeUnit)
      elseif event == "UNIT_THREAT_LIST_UPDATE" and unit_nameplate.UnitFrame
        then
        local activeUnit = GetNameplateUnit(unit_nameplate.UnitFrame)
        local snapshot = mod.Internal.State and mod.Internal.State:Update(activeUnit, "threat")
        if GetDB().nameplate_unit_target_color then
          SetNameplateHealthBarColor(unit_nameplate, unit_nameplate.UnitFrame.healthBar, activeUnit)
        end
        if mod.Internal.Indicators then mod.Internal.Indicators:Update(unit_nameplate, snapshot, GetDB()) end
      elseif unit_nameplate.UnitFrame then
        local activeUnit = GetNameplateUnit(unit_nameplate.UnitFrame)
        local snapshot = mod.Internal.State and mod.Internal.State:Update(activeUnit, event)
        if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
          SetNameplateHealthBarText(unit_nameplate.UnitFrame.healthBar, activeUnit)
          SetNameplateHealthBarColor(unit_nameplate, unit_nameplate.UnitFrame.healthBar, activeUnit)
        elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
          if mod.Internal.Power then mod.Internal.Power:Update(unit_nameplate, snapshot, GetDB()) end
        elseif event:find("UNIT_SPELLCAST", 1, true) == 1 then
          if mod.Internal.Casts then mod.Internal.Casts:Update(unit_nameplate, activeUnit, GetDB()) end
        end
        if mod.Internal.Indicators then mod.Internal.Indicators:Update(unit_nameplate, snapshot, GetDB()) end
      end
    end)

    unit_nameplate.modified = true
  end

  local texture = GetStatusbarTexture()
  unit_nameplate_health_bar:SetStatusBarTexture(texture)
  if unit_nameplate_cast_bar then unit_nameplate_cast_bar:SetStatusBarTexture(texture) end

  ApplyFont(unit_nameplate_name, GetDB().enemy_nameplate_name_font_size or 10)
  local healthText = unit_nameplate_health_bar.unit_health_text
  if healthText then
    local fontSize = GetDB().enemy_nameplate_health_font_size or 9.5
    local textColor = GetDB().enemy_nameplate_health_text_color or { r = 1.0, g = 0.82, b = 0.0 }
    ApplyFont(healthText.text_left, fontSize)
    ApplyFont(healthText.text_right, fontSize)
    healthText.text_left:SetTextColor(textColor.r or 1, textColor.g or 0.82, textColor.b or 0)
    healthText.text_right:SetTextColor(textColor.r or 1, textColor.g or 0.82, textColor.b or 0)
  end

  local bg = GetDB().enemy_nameplate_background_color or { r = 0.02, g = 0.02, b = 0.02 }
  if unit_nameplate_health_bar.etbc_background then
    unit_nameplate_health_bar.etbc_background:SetVertexColor(
      bg.r or 0.02, bg.g or 0.02, bg.b or 0.02,
      GetDB().enemy_nameplate_background_alpha or 0.85
    )
  end
  UpdateHealthBorder(unit_nameplate_health_bar, GetDB())

  if not GetDB().enemy_nameplate_health_text and unit_nameplate_health_bar.unit_health_text then
    unit_nameplate_health_bar.unit_health_text:Hide()
  end

  if unit_nameplate_health_bar.unit_debuff then
    unit_nameplate_health_bar.unit_debuff:SetScale(GetDB().enemy_nameplate_debuff_scale or 1)
  end
  if unit_nameplate_health_bar.player_debuffs then
    unit_nameplate_health_bar.player_debuffs:SetScale(GetDB().enemy_nameplate_player_debuffs_scale or 1)
  end
  if unit_nameplate_health_bar.unit_stance then
    unit_nameplate_health_bar.unit_stance:SetScale(GetDB().enemy_nameplate_stance_scale or 1)
  end

  local hover_texture = select(3, unit_nameplate_health_bar:GetRegions())
  if hover_texture and hover_texture.GetTexture and hover_texture:GetTexture() then
    hover_texture:SetTexture(texture)
  end

  SetNameplateSize(unit_nameplate, unit_nameplate_health_bar, unit)
  SetNameplateHealthBarColor(unit_nameplate, unit_nameplate_health_bar, unit)
  SetNameplateCastBar(unit_nameplate, unit_nameplate_cast_bar)
  SetNameplateUnitDebuff(unit_nameplate, unit)
  SetNameplatePlayerDebuffs(unit_nameplate, unit)
  SetNameplateAbsorb(unit_nameplate, unit)
  local snapshot = mod.Internal.State and mod.Internal.State:Update(unit, "all")
  if mod.Internal.Power then mod.Internal.Power:Update(unit_nameplate, snapshot, GetDB()) end
  if mod.Internal.Casts then mod.Internal.Casts:Update(unit_nameplate, unit, GetDB()) end
  if mod.Internal.Indicators then mod.Internal.Indicators:Update(unit_nameplate, snapshot, GetDB()) end
end

local function GetLifecycleInternal()
  return mod.Internal and mod.Internal.Lifecycle
end

local function SetNameplatePadding()
  local H = GetLifecycleInternal()
  if H and H.SetNameplatePadding then
    return H.SetNameplatePadding()
  end
end

function mod.UpdateExistingNameplatesSize(_)
  SetNameplatePadding()

  for _, unit_nameplate in pairs(unit_nameplates) do
    if unit_nameplate.healthBarWrapper then
      local unit = GetNameplateUnit(unit_nameplate)
      local nameplate = unit and C_NamePlate.GetNamePlateForUnit(unit, false)
      if nameplate and nameplate.UnitFrame and nameplate.UnitFrame == unit_nameplate
        and UnitExists(unit) and not SafeUnitIsUnit("player", unit)
      then
        SetNameplateSize(nameplate, unit_nameplate.healthBar, unit)
      end
    end
  end
end

function mod.UpdateExistingNameplatesColor(_)
  for _, unit_nameplate in pairs(unit_nameplates) do
    if unit_nameplate.healthBarWrapper then
      local unit = GetNameplateUnit(unit_nameplate)
      local nameplate = unit and C_NamePlate.GetNamePlateForUnit(unit, false)
      if nameplate and nameplate.UnitFrame and nameplate.UnitFrame == unit_nameplate
        and UnitExists(unit) and not SafeUnitIsUnit("player", unit)
      then
        SetNameplateHealthBarColor(nameplate, unit_nameplate.healthBar, unit)
      end
    end
  end
end

function mod.UpdateExistingNameplatesDebuff(_)
  local db = GetDB()
  for _, unit_nameplate in pairs(unit_nameplates) do
    if unit_nameplate.healthBarWrapper and unit_nameplate.healthBar and unit_nameplate.healthBar.unit_debuff then
      if db.enemy_nameplate_debuff then
        unit_nameplate.healthBar.unit_debuff:SetScale(db.enemy_nameplate_debuff_scale or 1)
        unit_nameplate.healthBar.unit_debuff:SetAlpha(1)
      else
        unit_nameplate.healthBar.unit_debuff:SetAlpha(0)
      end
    end
  end
end

function mod.UpdateExistingNameplatesPlayerDebuffs(_)
  local db = GetDB()
  for _, unit_nameplate in pairs(unit_nameplates) do
    if unit_nameplate.healthBarWrapper and unit_nameplate.healthBar and unit_nameplate.healthBar.player_debuffs then
      if db.enemy_nameplate_player_debuffs then
        unit_nameplate.healthBar.player_debuffs:SetScale(db.enemy_nameplate_player_debuffs_scale or 1)

        local x = 0
        local player_debuff_frames = { unit_nameplate.healthBar.player_debuffs:GetChildren() }
        for _, player_debuff in ipairs(player_debuff_frames) do
          if player_debuff.current_debuff then
            player_debuff:SetPoint("BOTTOMLEFT", x, 0)
            x = x + player_debuff:GetWidth() + (db.enemy_nameplate_player_debuffs_padding or 4)
          end
        end

        unit_nameplate.healthBar.player_debuffs:Show()
      else
        unit_nameplate.healthBar.player_debuffs:Hide()
      end
    end
  end
end

function mod.UpdateExistingNameplatesStance(_)
  local db = GetDB()
  for _, unit_nameplate in pairs(unit_nameplates) do
    if unit_nameplate.healthBarWrapper and unit_nameplate.healthBar and unit_nameplate.healthBar.unit_stance then
      if db.enemy_nameplate_stance then
        unit_nameplate.healthBar.unit_stance:SetScale(db.enemy_nameplate_stance_scale or 1)
      else
        unit_nameplate.healthBar.unit_stance:Hide()
      end
    end
  end
end

function mod.UpdateExistingNameplatesText(_)
  local db = GetDB()
  for _, unit_nameplate in pairs(unit_nameplates) do
    if unit_nameplate.healthBarWrapper and unit_nameplate.healthBar and unit_nameplate.healthBar.unit_health_text then
      if not db.enemy_nameplate_health_text then
        unit_nameplate.healthBar.unit_health_text:Hide()
      else
        local unit = GetNameplateUnit(unit_nameplate)
        if UnitExists(unit) and not SafeUnitIsUnit("player", unit) then
          if not IsFriendlyNameplate(unit_nameplate, unit) then
            unit_nameplate.healthBar.unit_health_text:Show()
          end
        end
      end
    end
  end
end

function mod.UpdateExistingNameplatesTextures(_)
  if not GetDB().enabled then return end
  local texture = GetStatusbarTexture()
  for _, unit_nameplate in pairs(unit_nameplates) do
    if unit_nameplate.healthBarWrapper and unit_nameplate.healthBar then
      unit_nameplate.healthBar:SetStatusBarTexture(texture)
      if unit_nameplate.castBar then
        unit_nameplate.castBar:SetStatusBarTexture(texture)
      end

      local hover_texture = select(3, unit_nameplate.healthBar:GetRegions())
      if hover_texture and hover_texture.GetTexture and hover_texture:GetTexture() then
        hover_texture:SetTexture(texture)
      end
    end
  end
end

function mod.UpdateExistingNameplateComponents(_)
  local db = GetDB()
  for _, unitFrame in pairs(unit_nameplates) do
    local unit = GetNameplateUnit(unitFrame)
    local nameplate = unit and C_NamePlate.GetNamePlateForUnit(unit, false)
    if nameplate and UnitExists(unit) then
      local snapshot = mod.Internal.State and mod.Internal.State:Update(unit, "settings")
      if mod.Internal.Power then mod.Internal.Power:Update(nameplate, snapshot, db) end
      if mod.Internal.Casts then mod.Internal.Casts:Update(nameplate, unit, db) end
      if mod.Internal.Indicators then mod.Internal.Indicators:Update(nameplate, snapshot, db) end
    end
  end
end

local function HookEvents()
  local H = GetLifecycleInternal()
  if H and H.HookEvents then
    return H.HookEvents()
  end
end

local function UnhookEvents()
  local H = GetLifecycleInternal()
  if H and H.UnhookEvents then
    return H.UnhookEvents()
  end
end

local function ApplyExistingNameplates()
  local H = GetLifecycleInternal()
  if H and H.ApplyExistingNameplates then
    return H.ApplyExistingNameplates()
  end
end

local function ResetNameplates()
  local H = GetLifecycleInternal()
  if H and H.ResetNameplates then
    return H.ResetNameplates()
  end
end

mod.Internal.Shared.GetDB = GetDB
mod.Internal.Shared.GetNameplateUnit = GetNameplateUnit
mod.Internal.Shared.InInstance = InInstance
mod.Internal.Shared.IsPlaterLoaded = IsPlaterLoaded
mod.Internal.Shared.IsSecureUpdateBlocked = IsSecureUpdateBlocked
mod.Internal.Shared.SafeUnitIsUnit = SafeUnitIsUnit
mod.Internal.Shared.ShouldIgnoreNameplate = ShouldIgnoreNameplate
mod.Internal.Shared.Trim = Trim
mod.Internal.Shared.GetUnitAuraByIndex = GetUnitAuraByIndex
mod.Internal.Shared.FindAuraByName = FindAuraByName
mod.Internal.Shared.GetTotemColorByName = GetTotemColorByName
mod.Internal.Shared.GetFormattedDebuff = GetFormattedDebuff
mod.Internal.Shared.GetFormattedPlayerDebuff = GetFormattedPlayerDebuff
mod.Internal.Shared.GetFormattedAbsorbBuff = GetFormattedAbsorbBuff
mod.Internal.Shared.FindTrackedAbsorbAura = FindTrackedAbsorbAura
mod.Internal.Shared.FindPriorityTrackedDebuffAura = FindPriorityTrackedDebuffAura
mod.Internal.Shared.GetFormattedInterrupt = GetFormattedInterrupt
mod.Internal.Shared.GetStanceData = GetStanceData
mod.Internal.Shared.SetNameplateUnitInterrupt = SetNameplateUnitInterrupt
mod.Internal.Shared.SetNameplateUnitStance = SetNameplateUnitStance
mod.Internal.Shared.SetNameplatePlayerMindControl = SetNameplatePlayerMindControl

function mod.Apply(_)
  if mod.Internal.Profiles then mod.Internal.Profiles:ApplyContext() end
  if IsPlaterLoaded() then
    UnhookEvents()
    ResetNameplates()
    return
  end

  if not ETBC.db or not ETBC.db.profile or not ETBC.db.profile.general or not ETBC.db.profile.general.enabled then
    UnhookEvents()
    ResetNameplates()
    return
  end

  if not GetDB().enabled then
    UnhookEvents()
    ResetNameplates()
    return
  end

  BuildData()
  HookEvents()
  if IsSecureUpdateBlocked() then
    runtime.pendingApply = true
    return
  end
  runtime.pendingApply = false
  SetNameplatePadding()
  ApplyExistingNameplates()
  mod:UpdateExistingNameplatesSize()
  mod:UpdateExistingNameplatesColor()
  mod:UpdateExistingNameplatesDebuff()
  mod:UpdateExistingNameplatesPlayerDebuffs()
  mod:UpdateExistingNameplatesStance()
  mod:UpdateExistingNameplatesText()
  mod:UpdateExistingNameplatesTextures()
  mod:UpdateExistingNameplateComponents()
end

if ETBC.ApplyBus and ETBC.ApplyBus.Register then
  ETBC.ApplyBus:Register("nameplates", function()
    mod:Apply()
  end)

  ETBC.ApplyBus:Register("general", function()
    mod:Apply()
  end)

  ETBC.ApplyBus:Register("ui", function()
    if ETBC.db and ETBC.db.profile and ETBC.db.profile.general and ETBC.db.profile.general.enabled then
      mod:UpdateExistingNameplatesTextures()
    end
  end)
end

-- Safety hooks for health updates
if type(_G.CompactUnitFrame_UpdateHealth) == "function" then
  hooksecurefunc("CompactUnitFrame_UpdateHealth", function(self)
    local unit = GetNameplateUnit(self)
    if self.healthBar and self.healthBarWrapper and unit and self:GetParent()
      and self:GetParent().isNamePlate and self:GetParent().nameplate_events then
      SetNameplateHealthBarText(self.healthBar, unit)
      SetNameplateHealthBarColor(self:GetParent(), self.healthBar, unit)
    end
  end)
end

if type(_G.CompactUnitFrame_UpdateHealthColor) == "function" then
  hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(self)
    local unit = GetNameplateUnit(self)
    if self.healthBar and self.healthBarWrapper and self.healthBar.unit_health_text and unit and self:GetParent()
      and self:GetParent().isNamePlate and self:GetParent().nameplate_events then
      SetNameplateHealthBarColor(self:GetParent(), self.healthBar, unit)
    end
  end)
end

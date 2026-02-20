-- Modules/Unit_NamePlates.lua
-- EnhanceTBC - Nameplate styling and debuff helpers
-- Based on the provided JUI nameplate logic, adapted for EnhanceTBC.

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.Nameplates = mod

local driver
local hooked = false

local unit_nameplates = {}
local duel_unit = nil

local formatted_debuffs = {}
local formatted_interrupts = {}
local formatted_player_debuffs = {}
local formatted_absorb_buffs = {}

local max_player_debuffs = 4

local function GetDB()
  ETBC.db.profile.nameplates = ETBC.db.profile.nameplates or {}
  local db = ETBC.db.profile.nameplates

  if db.enabled == nil then db.enabled = true end

  if db.enemy_nameplate_width == nil then db.enemy_nameplate_width = 109 end
  if db.enemy_nameplate_height == nil then db.enemy_nameplate_height = 12.5 end
  if db.enemy_nameplate_castbar_width == nil then db.enemy_nameplate_castbar_width = 109 end
  if db.enemy_nameplate_castbar_height == nil then db.enemy_nameplate_castbar_height = 12.5 end

  if db.friendly_nameplate_width == nil then db.friendly_nameplate_width = 42 end
  if db.friendly_nameplate_height == nil then db.friendly_nameplate_height = 12.5 end
  if db.friendly_nameplate_castbar_width == nil then db.friendly_nameplate_castbar_width = 42 end
  if db.friendly_nameplate_castbar_height == nil then db.friendly_nameplate_castbar_height = 12.5 end

  if db.enemy_nameplate_health_text == nil then db.enemy_nameplate_health_text = true end
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
  if db.totem_nameplate_colors == nil then db.totem_nameplate_colors = true end

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
  if ETBC.Theme and ETBC.Theme.FetchStatusbar then
    return ETBC.Theme:FetchStatusbar()
  end
  if ETBC.LSM and ETBC.LSM.Fetch then
    local ok, tex = pcall(ETBC.LSM.Fetch, ETBC.LSM, "statusbar", "Blizzard")
    if ok and tex then return tex end
  end
  return "Interface\\TargetingFrame\\UI-StatusBar"
end

local function Trim(str)
  if not str then return str end
  if strtrim then return strtrim(str) end
  return (str:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function FindAuraByName(name, unit, filter)
  if not name or not unit then return nil end
  if AuraUtil and AuraUtil.FindAuraByName then
    return AuraUtil.FindAuraByName(name, unit, filter)
  end
  for i = 1, 40 do
    local aura_name = UnitAura(unit, i, filter)
    if aura_name == name then return true end
    if not aura_name then break end
  end
  return nil
end

local debuffs = {
  {
    { spell_id = 8178 },
    { spell_id = 10899 },
    { spell_id = 18094 },
    { spell_id = 20177 },
    { spell_id = 25596 },
  },
  {
    { spell_id = 23110 },
    { spell_id = 14530 },
    { spell_id = 13141 },
    { spell_id = 8892 },
    { spell_id = 5024 },
    { spell_id = 2983 },
  },
  {
    { spell_id = 6346 },
    { spell_id = 7812 },
    { spell_id = 32182 },
    { spell_id = 6742 },
    { spell_id = 12043 },
    { spell_id = 29166 },
    { spell_id = 16689 },
  },
  {
    { spell_id = 22812 },
    { spell_id = 31224 },
    { spell_id = 19263 },
    { spell_id = 45182 },
    { spell_id = 5277 },
    { spell_id = 3411 },
    { spell_id = 33206 },
    { spell_id = 7744 },
    { spell_id = 6615 },
    { spell_id = 498 },
    { spell_id = 1044 },
    { spell_id = 1022 },
    { spell_id = 12975 },
    { spell_id = 20230 },
    { spell_id = 2565 },
    { spell_id = 871 },
    { spell_id = 23131 },
    { spell_id = 23132 },
    { spell_id = 23097 },
    { spell_id = 20594 },
  },
  {
    { spell_id = 6940 },
  },
  {
    { spell_id = 12042 },
    { spell_id = 31884 },
    { spell_id = 11129 },
    { spell_id = 12472 },
    { spell_id = 10060 },
    { spell_id = 3045 },
    { spell_id = 1719 },
    { spell_id = 12292 },
    { spell_id = 18499 },
    { spell_id = 20572 },
    { spell_id = 23060 },
    { spell_id = 34471 },
    { spell_id = 19574 },
    { spell_id = 6793 },
  },
  {
    { spell_id = 122 },
    { spell_id = 33395 },
    { spell_id = 339 },
    { spell_id = 19388 },
    { spell_id = 19233 },
    { spell_id = 19306 },
    { spell_id = 44041 },
    { spell_id = 12494 },
    { spell_id = 23694 },
    { spell_id = 13120 },
    { spell_id = 8312 },
    { spell_id = 45334 },
  },
  {
    { spell_id = 8988 },
    { spell_id = 19821 },
    { spell_id = 29443 },
    { spell_id = 18469 },
    { spell_id = 34490 },
    { spell_id = 1330, track_spell_id = { [1330] = true } },
    { spell_id = 28730 },
    { spell_id = 19647 },
    { spell_id = 13754 },
  },
  {
    { spell_id = 13006 },
    { spell_id = 17639 },
    { spell_id = 5917 },
    { spell_id = 676 },
  },
  {
    { spell_id = 19503 },
    { spell_id = 17926 },
    { spell_id = 8122 },
    { spell_id = 6215 },
    { spell_id = 5484 },
    { spell_id = 31661 },
    { spell_id = 5246 },
    { spell_id = 10326 },
    { spell_id = 5134 },
    { spell_id = 1513 },
  },
  {
    { spell_id = 118 },
    { spell_id = 20066 },
    { spell_id = 13180 },
    { spell_id = 14309 },
    { spell_id = 11286 },
    { spell_id = 2094 },
    { spell_id = 6358 },
    { spell_id = 27068, track_spell_id = { [19386] = true, [24132] = true, [24133] = true, [27068] = true } },
    { spell_id = 6770 },
    { spell_id = 2637 },
    { spell_id = 1090 },
    { spell_id = 710 },
    { spell_id = 10955 },
  },
  {
    { spell_id = 10308 },
    { spell_id = 408 },
    { spell_id = 1833 },
    { spell_id = 5530 },
    { spell_id = 34510 },
    { spell_id = 4068 },
    { spell_id = 19769 },
    { spell_id = 13237 },
    { spell_id = 22641 },
    { spell_id = 20170 },
    { spell_id = 20253 },
    { spell_id = 12809 },
    { spell_id = 7922 },
    { spell_id = 8983 },
    { spell_id = 15268 },
    { spell_id = 19415 },
    { spell_id = 11103 },
    { spell_id = 19577 },
    { spell_id = 9005 },
    { spell_id = 22570 },
    { spell_id = 20549 },
    { spell_id = 39082 },
  },
  {
    { spell_id = 11446 },
  },
  {
    { spell_id = 33786 },
  },
  {
    { spell_id = 642 },
    { spell_id = 23920 },
    { spell_id = 45438 },
  },
  {
    { spell_id = 27089 },
  },
}

local interrupts = {
  { spell_id = 2139, duration = 8 },
  { spell_id = 45334, duration = 4 },
  { spell_id = 1766, duration = 5 },
  { spell_id = 32748, duration = 3 },
  { spell_id = 6552, duration = 4 },
  { spell_id = 72, duration = 5 },
  { spell_id = 19647, duration = 6 },
  { spell_id = 8042, duration = 2 },
}

local totem_colors = {
  ["Fire"] = CreateColor(0.48, 0.2, 0.09, 0.75),
  ["Earth"] = CreateColor(0.2, 0.37, 0.11, 0.75),
  ["Water"] = CreateColor(0.17, 0.42, 0.52, 0.75),
  ["Air"] = CreateColor(0.35, 0.15, 0.61, 0.75),
}

local totems = {
  ["Wrath of Air Totem"] = { type = "Air", texture = 136092 },
  ["Grace of Air Totem"] = { type = "Air", texture = 136046 },
  ["Windfury Totem"] = { type = "Air", texture = 136114 },
  ["Grounding Totem"] = { type = "Air", texture = 136039 },
  ["Tranquil Air Totem"] = { type = "Air", texture = 136013 },
  ["Sentry Totem"] = { type = "Air", texture = 136082 },
  ["Nature Resistance Totem"] = { type = "Air", texture = 136061 },
  ["Windwall Totem"] = { type = "Air", texture = 136022 },

  ["Fire Elemental Totem"] = { type = "Fire", texture = 135790 },
  ["Magma Totem"] = { type = "Fire", texture = 135826 },
  ["Searing Totem"] = { type = "Fire", texture = 135825 },
  ["Fire Nova Totem"] = { type = "Fire", texture = 135824 },
  ["Flametongue Totem"] = { type = "Fire", texture = 136040 },
  ["Frost Resistance Totem"] = { type = "Fire", texture = 135866 },

  ["Mana Spring Totem"] = { type = "Water", texture = 136053 },
  ["Mana Tide Totem"] = { type = "Water", texture = 135861 },
  ["Poison Cleansing Totem"] = { type = "Water", texture = 136070 },
  ["Disease Cleansing Totem"] = { type = "Water", texture = 136019 },
  ["Healing Stream Totem"] = { type = "Water", texture = 135127 },
  ["Fire Resistance Totem"] = { type = "Fire", texture = 135832 },

  ["Earth Elemental Totem"] = { type = "Earth", texture = 136024 },
  ["Strength of Earth Totem"] = { type = "Earth", texture = 136023 },
  ["Earthbind Totem"] = { type = "Earth", texture = 136102 },
  ["Tremor Totem"] = { type = "Earth", texture = 136108 },
  ["Stoneskin Totem"] = { type = "Earth", texture = 136098 },
  ["Stoneclaw Totem"] = { type = "Earth", texture = 136097 },
}

local stances = {
  [2457] = { texture = 132349 },
  [71] = { texture = 132341 },
  [2458] = { texture = 132275 },
}

local player_debuffs = {
  {
    { spell_id = 28592, class = "Mage" },
    { spell_id = 22959, class = "Mage", single_debuff = true },
    { spell_id = 11185, class = "Mage" },
    { spell_id = 31589, class = "Mage" },
    { spell_id = 31257, class = "Mage" },
    { spell_id = 27087, class = "Mage" },
    { spell_id = 11113, class = "Mage" },
    { spell_id = 25306, class = "Mage" },
    { spell_id = 33938, class = "Mage" },
    { spell_id = 116, class = "Mage" },
    { spell_id = 11120, class = "Mage" },
  },
  {
    { spell_id = 10414, class = "Shaman" },
    { spell_id = 8056, class = "Shaman" },
    { spell_id = 17364, class = "Shaman" },
    { spell_id = 3600, class = "Shaman", totem_debuff = true },
    { spell_id = 29228, class = "Shaman" },
  },
  {
    { spell_id = 348, class = "Warlock" },
    { spell_id = 172, class = "Warlock" },
    { spell_id = 18265, class = "Warlock" },
    { spell_id = 980, class = "Warlock" },
    { spell_id = 27243, class = "Warlock" },
    { spell_id = 32385, class = "Warlock" },
    { spell_id = 689, class = "Warlock" },
    { spell_id = 5138, class = "Warlock" },
    { spell_id = 12889, class = "Warlock", single_debuff = true },
    { spell_id = 18223, class = "Warlock", single_debuff = true },
    { spell_id = 1490, class = "Warlock", single_debuff = true },
    { spell_id = 16231, class = "Warlock", single_debuff = true },
    { spell_id = 702, class = "Warlock", single_debuff = true },
    { spell_id = 30910, class = "Warlock", single_debuff = true },
    { spell_id = 17794, class = "Warlock" },
  },
  {
    { spell_id = 9080, class = "Warrior" },
    { spell_id = 37662, class = "Warrior" },
    { spell_id = 25264, class = "Warrior" },
    { spell_id = 30901, class = "Warrior" },
    { spell_id = 12721, class = "Warrior" },
    { spell_id = 12294, class = "Warrior" },
    { spell_id = 12323, class = "Warrior" },
    { spell_id = 19778, class = "Warrior" },
  },
  {
    { spell_id = 14280, class = "Hunter" },
    { spell_id = 3043, class = "Hunter" },
    { spell_id = 27016, class = "Hunter" },
    { spell_id = 27634, class = "Hunter" },
    { spell_id = 27065, class = "Hunter" },
    { spell_id = 34500, class = "Hunter", single_debuff = true },
    { spell_id = 40652, class = "Hunter" },
    { spell_id = 1130, class = "Hunter" },
    { spell_id = 1543, class = "Hunter" },
    { spell_id = 13810, class = "Hunter" },
  },
  {
    { spell_id = 26993, class = "Druid" },
    { spell_id = 27012, class = "Druid" },
    { spell_id = 26988, class = "Druid" },
    { spell_id = 5570, class = "Druid" },
    { spell_id = 26998, class = "Druid" },
    { spell_id = 33745, class = "Druid" },
    { spell_id = 27003, class = "Druid" },
    { spell_id = 27008, class = "Druid" },
  },
  {
    { spell_id = 26679, class = "Rogue" },
    { spell_id = 26866, class = "Rogue" },
    { spell_id = 26884, class = "Rogue" },
    { spell_id = 26867, class = "Rogue" },
    { spell_id = 2818, class = "Rogue" },
    { spell_id = 2819, class = "Rogue" },
    { spell_id = 11353, class = "Rogue" },
    { spell_id = 26968, class = "Rogue" },
    { spell_id = 25349, class = "Rogue" },
    { spell_id = 11354, class = "Rogue" },
    { spell_id = 39665, class = "Rogue" },
    { spell_id = 5760, class = "Rogue" },
    { spell_id = 8692, class = "Rogue" },
    { spell_id = 11398, class = "Rogue" },
    { spell_id = 3408, class = "Rogue" },
  },
  {
    { spell_id = 25384, class = "Priest" },
    { spell_id = 25368, class = "Priest" },
    { spell_id = 32417, class = "Priest" },
    { spell_id = 15257, class = "Priest" },
    { spell_id = 33191, class = "Priest" },
    { spell_id = 34914, class = "Priest" },
  },
  {
    { spell_id = 21183, class = "Paladin" },
    { spell_id = 356110, class = "Paladin" },
    { spell_id = 31803, class = "Paladin" },
    { spell_id = 9452, class = "Paladin", single_debuff = true },
    { spell_id = 31935, class = "Paladin" },
    { spell_id = 31896, class = "Paladin" },
    { spell_id = 20354, class = "Paladin" },
    { spell_id = 20343, class = "Paladin" },
  },
}

local absorb_buffs = {
  { spell_id = 17 },
  { spell_id = 11426 },
  { spell_id = 7812 },
  { spell_id = 1463 },
}

local function BuildData()
  if mod._dataBuilt then return end
  mod._dataBuilt = true

  formatted_debuffs = {}
  formatted_interrupts = {}
  formatted_player_debuffs = {}
  formatted_absorb_buffs = {}

  for i, debuff_type_list in pairs(debuffs) do
    for _, debuff in pairs(debuff_type_list) do
      local name, _, texture = GetSpellInfo(debuff.spell_id)
      if name then
        debuff.name = name
        debuff.texture = texture
        debuff.priority = i
        formatted_debuffs[debuff.name] = debuff
      end
    end
  end

  for _, interrupt in pairs(interrupts) do
    local name, _, texture = GetSpellInfo(interrupt.spell_id)
    if name then
      interrupt.name = name
      interrupt.texture = texture
      interrupt.priority = 8
      interrupt.interrupt = true
      formatted_interrupts[interrupt.name] = interrupt
    end
  end

  local player_class = select(2, UnitClass("player"))
  for _, debuff_type_list in pairs(player_debuffs) do
    for _, debuff in pairs(debuff_type_list) do
      if debuff.class == player_class then
        local name, _, texture = GetSpellInfo(debuff.spell_id)
        if name then
          debuff.name = name
          debuff.texture = texture
          formatted_player_debuffs[debuff.name] = debuff
        end
      end
    end
  end

  for _, absorb_buff in pairs(absorb_buffs) do
    local name, _, texture = GetSpellInfo(absorb_buff.spell_id)
    if name then
      absorb_buff.name = name
      absorb_buff.texture = texture
      formatted_absorb_buffs[absorb_buff.name] = absorb_buff
    end
  end
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

local function SetNameplateHealthBarText(statusbar, unit)
  if not statusbar or not statusbar.unit_health_text then return end

  local unit_health = UnitHealth(unit)
  local unit_health_max = UnitHealthMax(unit)

  if unit_health and unit_health_max and unit_health_max > 0 then
    if statusbar.unit_health_text:IsShown() then
      statusbar.unit_health_text.text_left:SetText(math.ceil(unit_health / unit_health_max * 100) .. "%")

      if unit_health < 1000 then
        statusbar.unit_health_text.text_right:SetText(unit_health)
      elseif unit_health < 1000000 then
        statusbar.unit_health_text.text_right:SetText(string.format("%.1fK", (unit_health / 1000)))
      elseif unit_health < 1000000000 then
        statusbar.unit_health_text.text_right:SetText(string.format("%.1fM", (unit_health / 1000000)))
      end
    else
      statusbar.unit_health_text.text_left:SetText("")
      statusbar.unit_health_text.text_right:SetText("")
    end

    if statusbar.absorb and statusbar.absorb:IsShown() then
      local x = statusbar:GetWidth() * (unit_health / unit_health_max)

      if x + statusbar.absorb:GetWidth() > statusbar:GetWidth() then
        x = statusbar:GetWidth() - statusbar.absorb:GetWidth()
        statusbar.absorb.over_absorb_texture:Show()
      else
        statusbar.absorb.over_absorb_texture:Hide()
      end

      statusbar.absorb:SetPoint("LEFT", statusbar, x, 0)
    end
  end
end

local function SetNameplateHealthBarColor(nameplate, statusbar, unit)
  local db = GetDB()
  if not UnitExists(unit) or not statusbar or not statusbar.unit_health_text then return end

  if UnitIsPlayer(unit) then
    if not UnitIsConnected(unit) then
      statusbar:SetStatusBarColor(0.75, 0.75, 0.75)
      return
    end

    if not UnitIsPVP(unit) and not IsFriendlyNameplate(nameplate, unit) then
      statusbar:SetStatusBarColor(1, 0.9, 0.1)
      return
    end

    if db.friendly_nameplate_default_color and IsFriendlyNameplate(nameplate, unit) then
      statusbar:SetStatusBarColor(0, 0.1, 0.9)
      return
    end

    if db.class_colored_nameplates then
      local _, unit_class = UnitClass(unit)
      if not unit_class then return end
      local unit_class_color = RAID_CLASS_COLORS[unit_class]
      if unit_class_color then
        statusbar:SetStatusBarColor(unit_class_color:GetRGB())
      end
    else
      local unit_reaction = UnitReaction(unit, "player")
      if unit_reaction then
        if unit_reaction >= 1 and unit_reaction <= 3 then
          statusbar:SetStatusBarColor(0.9, 0, 0.1)
        elseif unit_reaction == 4 then
          statusbar:SetStatusBarColor(1, 0.9, 0.1)
        else
          statusbar:SetStatusBarColor(0, 0.85, 0.2)
        end
      end
    end
  else
    if db.nameplate_unit_target_color then
      if not IsFriendlyNameplate(nameplate, unit) then
        if SafeUnitIsUnit(unit .. "target", "player") then
          statusbar:SetStatusBarColor(0, 0.1, 0.9)
          return
        end
      else
        if nameplate and nameplate.nameplate_events then
          nameplate.nameplate_events:UnregisterEvent("UNIT_THREAT_LIST_UPDATE")
        end
      end
    end

    if db.totem_nameplate_colors then
      local unit_name = UnitName(unit)
      if unit_name then
        local totem_ranks = { "I", "II", "III", "IV", "V", "VI", "VII" }
        for _, v in ipairs(totem_ranks) do
          unit_name = string.gsub(unit_name, v, "")
        end
        unit_name = Trim(unit_name)

        if totems[unit_name] then
          local color = totem_colors[totems[unit_name].type]
          if color then
            statusbar:SetStatusBarColor(color:GetRGB())
            return
          end
        end
      end
    end

    if not UnitIsFriend(unit, "player") and UnitIsTapDenied(unit) then
      statusbar:SetStatusBarColor(0.75, 0.75, 0.75)
      return
    end

    local unit_reaction = UnitReaction(unit, "player")
    if unit_reaction then
      if unit_reaction >= 1 and unit_reaction <= 3 then
        statusbar:SetStatusBarColor(0.9, 0, 0.1)
      elseif unit_reaction == 4 then
        statusbar:SetStatusBarColor(1, 0.9, 0.1)
      else
        statusbar:SetStatusBarColor(0, 0.85, 0.2)
      end
    end
  end
end

local function SetNameplateAbsorb(nameplate, unit)
  if unit and UnitExists(unit) and not UnitIsDead(unit)
    and nameplate and nameplate.UnitFrame then
    local nameplate_health_bar = nameplate.UnitFrame.healthBar
    if not nameplate_health_bar or not nameplate_health_bar.absorb then return end

    if IsFriendlyNameplate(nameplate, unit) or SafeUnitIsUnit(unit, "player") then
      nameplate_health_bar.absorb:Hide()
      return
    end

    for i = 1, 40 do
      local name, _, _, _, _, _, _, _, _, absorb_spell_id = UnitAura(unit, i, "HELPFUL")
      if name then
        local absorb_buff = formatted_absorb_buffs[name]

        if absorb_buff and absorb_buff.track_spell_id and absorb_spell_id
          and not absorb_buff.track_spell_id[absorb_spell_id] then
          absorb_buff = nil
        end

        if absorb_buff then
          local unit_health = UnitHealth(unit)
          local unit_health_max = UnitHealthMax(unit)

          if unit_health and unit_health_max and unit_health_max > 0 then
            local x = nameplate_health_bar:GetWidth() * (unit_health / unit_health_max)

            if x + nameplate_health_bar.absorb:GetWidth() > nameplate_health_bar:GetWidth() then
              x = nameplate_health_bar:GetWidth() - nameplate_health_bar.absorb:GetWidth()
              nameplate_health_bar.absorb.over_absorb_texture:Show()
            else
              nameplate_health_bar.absorb.over_absorb_texture:Hide()
            end

            nameplate_health_bar.absorb:SetPoint("LEFT", nameplate_health_bar, x, 0)
            nameplate_health_bar.absorb:Show()
          end

          return
        end
      else
        break
      end
    end

    nameplate_health_bar.absorb:Hide()
  end
end

local function SetNameplateCastBar(nameplate, castbar)
  if nameplate and castbar then
    castbar.Icon:Show()
    castbar.Text:Show()
    castbar.Border:Hide()
  end
end

local function SetNameplateSize(nameplate, statusbar, unit)
  local db = GetDB()
  if not UnitExists(unit) or not nameplate.modified then return end

  if not SafeUnitIsUnit("player", unit) then
    if not IsFriendlyNameplate(nameplate, unit) then
      nameplate.UnitFrame.healthBarWrapper:SetSize(
        db.enemy_nameplate_width or 109,
        db.enemy_nameplate_height or 12.5
      )
      nameplate.UnitFrame.castBarWrapper:SetSize(
        db.enemy_nameplate_castbar_width or 109,
        db.enemy_nameplate_castbar_height or 12.5
      )

      if statusbar.unit_health_text then
        if db.enemy_nameplate_health_text then statusbar.unit_health_text:Show() end

        nameplate.UnitFrame.name:SetWidth(nameplate.UnitFrame.healthBarWrapper:GetWidth() - 20)
        nameplate.UnitFrame.LevelFrame.levelText:SetAlpha(1)
        nameplate.UnitFrame.LevelFrame.highLevelTexture:SetAlpha(1)

        SetNameplateHealthBarText(statusbar, unit)
      end
    else
      nameplate.UnitFrame.healthBarWrapper:SetSize(
        db.friendly_nameplate_width or 42,
        db.friendly_nameplate_height or 12.5
      )
      nameplate.UnitFrame.castBarWrapper:SetSize(
        db.friendly_nameplate_castbar_width or 42,
        db.friendly_nameplate_castbar_height or 12.5
      )

      if statusbar.unit_health_text then
        statusbar.unit_health_text:Hide()

        if nameplate.UnitFrame.healthBarWrapper:GetWidth() >= 70 then
          nameplate.UnitFrame.name:SetWidth(nameplate.UnitFrame.healthBarWrapper:GetWidth() - 20)
          nameplate.UnitFrame.LevelFrame.levelText:SetAlpha(1)
          nameplate.UnitFrame.LevelFrame.highLevelTexture:SetAlpha(1)
        else
          nameplate.UnitFrame.name:SetWidth(nameplate.UnitFrame.healthBarWrapper:GetWidth())
          nameplate.UnitFrame.LevelFrame.levelText:SetAlpha(0)
          nameplate.UnitFrame.LevelFrame.highLevelTexture:SetAlpha(0)
        end
      end
    end
  end

  nameplate.UnitFrame.healthBar:ClearAllPoints()
  nameplate.UnitFrame.healthBar:SetPoint(
    "BOTTOMLEFT", nameplate.UnitFrame.healthBarWrapper, "BOTTOMLEFT", 0, 0
  )
  nameplate.UnitFrame.healthBar:SetPoint("TOPRIGHT", nameplate.UnitFrame.healthBarWrapper, "TOPRIGHT", 0, 0)

  nameplate.UnitFrame.castBar:ClearAllPoints()
  nameplate.UnitFrame.castBar:SetPoint(
    "BOTTOMLEFT",
    nameplate.UnitFrame.castBarWrapper,
    "BOTTOMLEFT",
    nameplate.UnitFrame.castBarWrapper:GetHeight() + 0.5,
    0
  )
  nameplate.UnitFrame.castBar:SetPoint("TOPRIGHT", nameplate.UnitFrame.castBarWrapper, "TOPRIGHT", 0, 0)

  nameplate.UnitFrame.castBar.Icon:ClearAllPoints()
  nameplate.UnitFrame.castBar.Icon:SetPoint("BOTTOMLEFT", nameplate.UnitFrame.castBarWrapper, "BOTTOMLEFT", 0, 0)
  nameplate.UnitFrame.castBar.Icon:SetPoint("TOPRIGHT", nameplate.UnitFrame.castBar, "TOPLEFT", -0.5, 0)

  nameplate.UnitFrame.castBar.icon_backdrop:ClearAllPoints()
  nameplate.UnitFrame.castBar.icon_backdrop:SetPoint("BOTTOMLEFT", nameplate.UnitFrame.castBar.Icon, -1, -1)
  nameplate.UnitFrame.castBar.icon_backdrop:SetPoint("TOPRIGHT", nameplate.UnitFrame.castBar.Icon, 1, 1)

  nameplate.UnitFrame.castBar.Spark:SetSize(15, nameplate.UnitFrame.castBar:GetHeight() * 1.6)

  nameplate.UnitFrame.healthBar.absorb:SetSize(16, nameplate.UnitFrame.healthBar:GetHeight())
  nameplate.UnitFrame.healthBar.absorb.over_absorb_texture:SetSize(12, nameplate.UnitFrame.healthBar.absorb:GetHeight())
end

local function SetNameplatePlayerDebuffs(nameplate, unit)
  local db = GetDB()
  if unit and nameplate.UnitFrame then
    local nameplate_player_debuffs = nameplate.UnitFrame.healthBar.player_debuffs
    if not nameplate_player_debuffs then return end
    local player_debuff_frames = { nameplate_player_debuffs:GetChildren() }

    if IsFriendlyNameplate(nameplate, unit) or SafeUnitIsUnit(unit, "player") then
      for _, player_debuff in ipairs(player_debuff_frames) do
        player_debuff.current_debuff = nil
        player_debuff.cooldown_started = -1
        player_debuff.cooldown_duration = -1
        player_debuff.aura_count = -1

        player_debuff.aura_count_text:SetText("")

        player_debuff:Hide()
        player_debuff.cooldown:Hide()
      end

      return
    end

    for _, player_debuff in ipairs(player_debuff_frames) do
      if player_debuff.current_debuff and player_debuff.current_debuff.name and
        (not FindAuraByName(player_debuff.current_debuff.name, unit, "HARMFUL") or
        (player_debuff.cooldown_duration - (GetTime() - player_debuff.cooldown_started)) < 0) then
        player_debuff.current_debuff = nil
        player_debuff.cooldown_started = -1
        player_debuff.cooldown_duration = -1
        player_debuff.aura_count = -1

        player_debuff.aura_count_text:SetText("")

        player_debuff:Hide()
        player_debuff.cooldown:Hide()
      end
    end

    if not db.enemy_nameplate_player_debuffs then return end

    for i = 1, 40 do
      local name, icon, debuff_aura_count, _, debuff_duration,
        debuff_expiration_time, unit_caster, _, _, debuff_spell_id = UnitAura(unit, i, "HARMFUL")
      if not debuff_duration then debuff_duration = 0 end

      if name then
        local player_debuff = formatted_player_debuffs[name]

        if player_debuff and player_debuff.track_spell_id and debuff_spell_id
          and not player_debuff.track_spell_id[debuff_spell_id] then
          player_debuff = nil
        end

        if player_debuff and unit_caster and debuff_expiration_time and (
          SafeUnitIsUnit(unit_caster, "player")
          or SafeUnitIsUnit(unit_caster, "pet")
          or player_debuff.totem_debuff
        ) then
          local debuff_frame = nil

          for _, player_debuff_frame in ipairs(player_debuff_frames) do
            if player_debuff_frame.current_debuff then
              if player_debuff.name == player_debuff_frame.current_debuff.name then
                debuff_frame = player_debuff_frame
                break
              end
            end
          end

          if not debuff_frame then
            for _, player_debuff_frame in ipairs(player_debuff_frames) do
              if not player_debuff_frame.current_debuff then
                debuff_frame = player_debuff_frame
                break
              end
            end
          end

          if not debuff_frame then
            for _, player_debuff_frame in ipairs(player_debuff_frames) do
              if player_debuff_frame.current_debuff then
                if (debuff_expiration_time - GetTime())
                  > (player_debuff_frame.cooldown_duration - (GetTime() - player_debuff_frame.cooldown_started)) then
                  debuff_frame = player_debuff_frame
                  break
                end
              end
            end
          end

          if debuff_frame then
            if debuff_frame.current_debuff and player_debuff.name == debuff_frame.current_debuff.name then
              if debuff_aura_count and debuff_aura_count > 1 then
                if debuff_aura_count ~= debuff_frame.aura_count then
                  debuff_frame.aura_count = debuff_aura_count
                  debuff_frame.aura_count_text:SetText(debuff_aura_count)
                end
              else
                debuff_frame.aura_count = -1
                debuff_frame.aura_count_text:SetText("")
              end

              if (debuff_expiration_time - GetTime())
                > (debuff_frame.cooldown_duration - (GetTime() - debuff_frame.cooldown_started)) then
                debuff_frame.cooldown_started = GetTime()
                  - (debuff_duration - (debuff_expiration_time - GetTime()))
                debuff_frame.cooldown_duration = debuff_duration
                debuff_frame.cooldown:SetCooldown(debuff_frame.cooldown_started, debuff_frame.cooldown_duration)
              end
            else
              debuff_frame.current_debuff = player_debuff
              debuff_frame.cooldown_started = GetTime()
                - (debuff_duration - (debuff_expiration_time - GetTime()))
              debuff_frame.cooldown_duration = debuff_duration
              debuff_frame:Show()

              if icon ~= player_debuff.texture then
                debuff_frame.texture:SetTexture(icon)
              else
                debuff_frame.texture:SetTexture(player_debuff.texture)
              end

              if debuff_aura_count and debuff_aura_count > 1 then
                debuff_frame.aura_count = debuff_aura_count
                debuff_frame.aura_count_text:SetText(debuff_aura_count)
              else
                debuff_frame.aura_count = -1
                debuff_frame.aura_count_text:SetText("")
              end

              debuff_frame.cooldown:SetCooldown(debuff_frame.cooldown_started, debuff_frame.cooldown_duration)
              debuff_frame.cooldown:Show()
            end
          end
        elseif player_debuff and unit_caster
          and not SafeUnitIsUnit(unit_caster, "player")
          and not SafeUnitIsUnit(unit_caster, "pet") then
          for _, player_debuff_frame in ipairs(player_debuff_frames) do
            if player_debuff_frame.current_debuff then
              if player_debuff.single_debuff and player_debuff.name == player_debuff_frame.current_debuff.name then
                player_debuff_frame.current_debuff = nil
                player_debuff_frame.cooldown_started = -1
                player_debuff_frame.cooldown_duration = -1
                player_debuff_frame.aura_count = -1

                player_debuff_frame.aura_count_text:SetText("")

                player_debuff_frame:Hide()
                player_debuff_frame.cooldown:Hide()

                break
              end
            end
          end
        end
      else
        break
      end
    end

    local x = 0
    for _, player_debuff in ipairs(player_debuff_frames) do
      if player_debuff.current_debuff then
        player_debuff:SetPoint("BOTTOMLEFT", x, 0)
        x = x + player_debuff:GetWidth() + (db.enemy_nameplate_player_debuffs_padding or 4)
      end
    end
  end
end

local function SetNameplateUnitDebuff(nameplate, unit)
  local db = GetDB()
  if unit and nameplate.UnitFrame then
    local nameplate_debuff = nameplate.UnitFrame.healthBar.unit_debuff
    if not nameplate_debuff then return end

    if IsFriendlyNameplate(nameplate, unit) or SafeUnitIsUnit(unit, "player") then
      if nameplate.nameplate_events then
        nameplate.nameplate_events:UnregisterEvent("UNIT_AURA")
      end

      nameplate_debuff.current_debuff = nil
      nameplate_debuff.cooldown_started = -1
      nameplate_debuff.cooldown_duration = -1
      nameplate_debuff.filter = nil

      nameplate_debuff:Hide()
      nameplate_debuff.cooldown:Hide()

      return
    end

    if nameplate_debuff.current_debuff and nameplate_debuff.current_debuff.name
      and not nameplate_debuff.current_debuff.interrupt and
      (not FindAuraByName(nameplate_debuff.current_debuff.name, unit, nameplate_debuff.filter) or
      (nameplate_debuff.cooldown_duration - (GetTime() - nameplate_debuff.cooldown_started)) < 0) then
      nameplate_debuff.current_debuff = nil
      nameplate_debuff.cooldown_started = -1
      nameplate_debuff.cooldown_duration = -1
      nameplate_debuff.filter = nil

      nameplate_debuff:Hide()
      nameplate_debuff.cooldown:Hide()
    end

    if not db.enemy_nameplate_debuff then return end

    for _, aura_type in pairs({ "HELPFUL", "HARMFUL" }) do
      for i = 1, 40 do
        local name, icon, _, _, debuff_duration, debuff_expiration_time,
          _, _, _, debuff_spell_id = UnitAura(unit, i, aura_type)
        if not debuff_duration then debuff_duration = 0 end

        if name then
          local debuff = formatted_debuffs[name]

          if debuff and debuff.track_spell_id and debuff_spell_id
            and not debuff.track_spell_id[debuff_spell_id] then
            debuff = nil
          end

          if debuff and debuff_expiration_time then
            local show_debuff = false

            if nameplate_debuff.current_debuff then
              if debuff.priority > nameplate_debuff.current_debuff.priority
                or (debuff.priority == nameplate_debuff.current_debuff.priority
                and (debuff_expiration_time - GetTime())
                > (nameplate_debuff.cooldown_duration - (GetTime() - nameplate_debuff.cooldown_started))) then
                show_debuff = true
              end
            else
              show_debuff = true
            end

            if show_debuff then
              nameplate_debuff.current_debuff = debuff
              nameplate_debuff.cooldown_started = GetTime()
                - (debuff_duration - (debuff_expiration_time - GetTime()))
              nameplate_debuff.cooldown_duration = debuff_duration
              nameplate_debuff.filter = aura_type
              nameplate_debuff:Show()

              if icon ~= debuff.texture then
                nameplate_debuff.texture:SetTexture(icon)
              else
                nameplate_debuff.texture:SetTexture(debuff.texture)
              end

              nameplate_debuff.cooldown:SetCooldown(
                nameplate_debuff.cooldown_started,
                nameplate_debuff.cooldown_duration
              )
              nameplate_debuff.cooldown:Show()
            end
          end
        else
          break
        end
      end
    end
  end
end

local function SetNameplateUnitInterrupt(db, dest_guid, dest_name, dest_flags, spell_id)
  if not db.enemy_nameplate_debuff then return end

  if not dest_flags then return end
  if bit.band(dest_flags, COMBATLOG_OBJECT_REACTION_HOSTILE) ~= 0 then
    if dest_name then
      local nameplate_debuff = nil

      if unit_nameplates[dest_guid] then
        local unit_nameplate = unit_nameplates[dest_guid]
        if IsFriendlyNameplate(unit_nameplate, dest_name) then return end
        nameplate_debuff = unit_nameplate.healthBar.unit_debuff
      end

      if not nameplate_debuff then return end

      if spell_id then
        local name, _, texture = GetSpellInfo(spell_id)
        local interrupt = formatted_interrupts[name]

        if interrupt then
          local interrupt_duration = interrupt.duration
          local show_interrupt = false

          if nameplate_debuff.current_debuff then
            if interrupt.priority > nameplate_debuff.current_debuff.priority
              or (interrupt.priority == nameplate_debuff.current_debuff.priority
              and interrupt_duration
              > (nameplate_debuff.cooldown_duration - (GetTime() - nameplate_debuff.cooldown_started))) then
              show_interrupt = true
            end
          else
            show_interrupt = true
          end

          if show_interrupt then
            nameplate_debuff.current_debuff = interrupt
            nameplate_debuff.cooldown_started = GetTime()
            nameplate_debuff.cooldown_duration = interrupt_duration
            nameplate_debuff.filter = nil
            nameplate_debuff:Show()

            if texture ~= interrupt.texture then
              nameplate_debuff.texture:SetTexture(texture)
            else
              nameplate_debuff.texture:SetTexture(interrupt.texture)
            end

            nameplate_debuff.cooldown:SetCooldown(nameplate_debuff.cooldown_started, nameplate_debuff.cooldown_duration)
            nameplate_debuff.cooldown:Show()
          end
        end
      end
    end
  end
end

local function SetNameplateUnitStance(db, source_guid, source_name, source_flags, spell_id)
  if not db.enemy_nameplate_stance then return end

  if not source_flags then return end
  if bit.band(source_flags, COMBATLOG_OBJECT_REACTION_HOSTILE) ~= 0 then
    if source_name then
      local nameplate_stance = nil

      if unit_nameplates[source_guid] then
        local unit_nameplate_unit_frame = unit_nameplates[source_guid]
        if not unit_nameplate_unit_frame
          or IsFriendlyNameplate(unit_nameplate_unit_frame, source_name) then return end
        nameplate_stance = unit_nameplate_unit_frame.healthBar.unit_stance
      end

      if not nameplate_stance then return end

      if spell_id and stances[spell_id] then
        if spell_id ~= 71 and spell_id ~= 48263 then
          nameplate_stance.texture:SetTexture(stances[spell_id].texture)
          nameplate_stance:Show()
        else
          nameplate_stance:Hide()
        end
      end
    end
  end
end

local function SetNameplatePlayerMindControl(combat_event, source_name, dest_name, spell_id)
  if combat_event ~= "SPELL_AURA_APPLIED"
    and combat_event ~= "SPELL_AURA_REMOVED"
    and combat_event ~= "SPELL_AURA_BROKEN"
  then
    return
  end

  local player_name = UnitName("player")
  if not player_name or (source_name ~= player_name and dest_name ~= player_name) then return end
  if not spell_id then return end

  local name = GetSpellInfo(spell_id)
  if name ~= "Mind Control" and name ~= "Gnomish Mind Control Cap"
    and name ~= "Chains of Kel'Thuzad"
  then
    return
  end

  for unit, unit_nameplate in pairs(unit_nameplates) do
    if unit_nameplate.healthBarWrapper and unit_nameplate.displayedUnit then
      local unit_guid = UnitGUID(unit_nameplate.displayedUnit)
      if unit == unit_guid then
        mod:StyleUnitNameplate(unit_nameplate.displayedUnit)
      end
    end
  end
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

  if not unit_nameplates[unit_guid] then
    unit_nameplates[unit_guid] = unit_nameplate.UnitFrame
  end

  if unit ~= "player" then
    if not IsFriendlyNameplate(unit_nameplate, unit)
      and not unit_nameplate.nameplate_events:IsEventRegistered("UNIT_AURA") then
      unit_nameplate.nameplate_events:RegisterUnitEvent("UNIT_AURA", unit)
      unit_nameplate.nameplate_events:RegisterUnitEvent("UNIT_THREAT_LIST_UPDATE", unit)
    end
  end

  local unit_nameplate_health_bar = unit_nameplate.UnitFrame.healthBar
  local unit_nameplate_container = unit_nameplate.UnitFrame.HealthBarsContainer
  local unit_nameplate_cast_bar = unit_nameplate.UnitFrame.castBar

  if not unit_nameplate.modified then
    local unit_nameplate_name = unit_nameplate.UnitFrame.name

    unit_nameplate_name:SetWidth((GetDB().enemy_nameplate_width or 109) - 20)
    unit_nameplate_name:SetPoint("BOTTOMLEFT", unit_nameplate_health_bar, "TOPLEFT", -1, 5)
    ApplyFont(unit_nameplate_name, 10)
    unit_nameplate_name:SetJustifyH("LEFT")

    hooksecurefunc(unit_nameplate_name, "Show", function(self)
      self:SetTextColor(1, 1, 1)
    end)

    hooksecurefunc(unit_nameplate_name, "Hide", function(self)
      self:Show()
    end)

    local unit_nameplate_level = unit_nameplate.UnitFrame.LevelFrame

    unit_nameplate_level:SetPoint("BOTTOMRIGHT", unit_nameplate_health_bar, "TOPRIGHT", 1, 2.5)

    unit_nameplate_level.levelText:SetHeight(unit_nameplate_name:GetHeight())
    ApplyFont(unit_nameplate_level.levelText, 9)
    unit_nameplate_level.levelText:SetJustifyH("RIGHT")

    unit_nameplate_level.highLevelTexture:SetPoint("TOPLEFT", 1.25, -1.25)
    unit_nameplate_level.highLevelTexture:SetPoint("BOTTOMRIGHT", -1.25, 1.25)

    unit_nameplate.UnitFrame.RaidTargetFrame:ClearAllPoints()
    unit_nameplate.UnitFrame.RaidTargetFrame:SetPoint("RIGHT", unit_nameplate_name, "LEFT", -3, 0)

    unit_nameplate_container.border:Hide()
    unit_nameplate_health_bar.background:Hide()

    unit_nameplate.UnitFrame.healthBarWrapper = CreateFrame("Frame", nil, unit_nameplate.UnitFrame)
    unit_nameplate.UnitFrame.healthBarWrapper:SetPoint("BOTTOM", 0, 4)

    unit_nameplate_health_bar.backdrop = CreateFrame("Frame", nil, unit_nameplate_health_bar, "BackdropTemplate")
    ApplyBackdropAlt(unit_nameplate_health_bar.backdrop)

    unit_nameplate_health_bar.focus_texture = CreateFrame("Frame", nil, unit_nameplate_health_bar)
    unit_nameplate_health_bar.focus_texture:SetAllPoints(true)
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
    unit_nameplate_health_bar.focus_texture.texture_top:SetVertexColor(0, 1, 0.6)

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
    unit_nameplate_health_bar.focus_texture.texture_bottom:SetVertexColor(0, 1, 0.6)

    hooksecurefunc(unit_nameplate_container.border, "SetVertexColor", function(_, r, g, b)
      if r == 1 and g == 1 and b == 1 then
        unit_nameplate_health_bar.focus_texture:Show()
        unit_nameplate_health_bar.backdrop:SetBackdropBorderColor(1, 1, 1)
      else
        unit_nameplate_health_bar.focus_texture:Hide()
        unit_nameplate_health_bar.backdrop:SetBackdropBorderColor(0.04, 0.04, 0.04)
      end
    end)

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
    ApplyFont(unit_nameplate_health_bar.unit_health_text.text_left, 9.5)

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
    ApplyFont(unit_nameplate_health_bar.unit_health_text.text_right, 9.5)

    unit_nameplate_health_bar.absorb = CreateFrame("Frame", nil, unit_nameplate_health_bar)
    unit_nameplate_health_bar.absorb:SetSize(16, unit_nameplate_health_bar:GetHeight())
    unit_nameplate_health_bar.absorb:Hide()

    unit_nameplate_health_bar.absorb.shield_texture =
      unit_nameplate_health_bar.absorb:CreateTexture(nil, "OVERLAY")
    unit_nameplate_health_bar.absorb.shield_texture:SetAllPoints(true)
    unit_nameplate_health_bar.absorb.shield_texture:SetTexture(798064)

    unit_nameplate_health_bar.absorb.over_absorb_texture =
      unit_nameplate_health_bar.absorb:CreateTexture(nil, "OVERLAY")
    unit_nameplate_health_bar.absorb.over_absorb_texture:SetSize(
      12, unit_nameplate_health_bar.absorb:GetHeight()
    )
    unit_nameplate_health_bar.absorb.over_absorb_texture:SetPoint("RIGHT", unit_nameplate_health_bar, 6, 0)
    unit_nameplate_health_bar.absorb.over_absorb_texture:SetTexture(798066)
    unit_nameplate_health_bar.absorb.over_absorb_texture:SetBlendMode("ADD")

    unit_nameplate.UnitFrame.castBarWrapper = CreateFrame("Frame", nil, unit_nameplate.UnitFrame)
    unit_nameplate.UnitFrame.castBarWrapper:SetPoint(
      "TOP", unit_nameplate.UnitFrame.healthBarWrapper, "BOTTOM", 0, -3
    )

    unit_nameplate_cast_bar.backdrop = CreateFrame(
      "Frame", nil, unit_nameplate_cast_bar, "BackdropTemplate"
    )
    ApplyBackdropAlt(unit_nameplate_cast_bar.backdrop)

    unit_nameplate_cast_bar.icon_backdrop = CreateFrame(
      "Frame", nil, unit_nameplate_cast_bar, "BackdropTemplate"
    )
    ApplyBackdrop(unit_nameplate_cast_bar.icon_backdrop)

    hooksecurefunc(unit_nameplate_cast_bar, "Show", function()
      SetNameplateCastBar(unit_nameplate, unit_nameplate_cast_bar)
    end)

    hooksecurefunc(unit_nameplate_cast_bar.BorderShield, "Show", function()
      unit_nameplate_cast_bar:SetStatusBarColor(0.85, 0.85, 0.85, 1, "nameplate_cast_bar")
    end)

    hooksecurefunc(unit_nameplate_cast_bar.BorderShield, "Hide", function()
      unit_nameplate_cast_bar:SetStatusBarColor(0.9, 0.7, 0, 1, "nameplate_cast_bar")
    end)

    hooksecurefunc(unit_nameplate_cast_bar, "SetStatusBarColor", function(_, _r, g, _b, _, flag)
      if unit_nameplate_cast_bar.notInterruptible and flag ~= "nameplate_cast_bar" then
        unit_nameplate_cast_bar:SetStatusBarColor(0.85, 0.85, 0.85, 1, "nameplate_cast_bar")
      elseif g == 1 and flag ~= "nameplate_cast_bar" then
        unit_nameplate_cast_bar:SetStatusBarColor(0.9, 0.7, 0, 1, "nameplate_cast_bar")
      end
    end)

    unit_nameplate_cast_bar:HookScript("OnEvent", function(self, event)
      if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        self.Text:Show()
      end
    end)

    unit_nameplate_cast_bar.Icon:SetTexCoord(0.07, 0.94, 0.07, 0.94)

    unit_nameplate_cast_bar.Spark.offsetY = 0
    unit_nameplate_cast_bar.Flash:SetTexture(nil)

    hooksecurefunc(unit_nameplate_cast_bar.Flash, "Show", function()
      unit_nameplate_cast_bar.Flash:Hide()
    end)

    ApplyFont(unit_nameplate_cast_bar.Text, 10)

    unit_nameplate_cast_bar.BorderShield:SetTexture(nil)

    unit_nameplate_health_bar.unit_debuff = CreateFrame("Frame", nil, unit_nameplate_health_bar)
    unit_nameplate_health_bar.unit_debuff:Hide()

    unit_nameplate_health_bar.unit_debuff:SetSize(26, 26)
    unit_nameplate_health_bar.unit_debuff:SetPoint("BOTTOMLEFT", unit_nameplate_health_bar, "BOTTOMRIGHT", 8, 0)

    unit_nameplate_health_bar.unit_debuff.texture =
      unit_nameplate_health_bar.unit_debuff:CreateTexture(nil, "BACKGROUND")
    unit_nameplate_health_bar.unit_debuff.texture:SetAllPoints(true)
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
      player_debuff.texture:SetAllPoints(true)
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
    unit_nameplate_health_bar.unit_stance.texture:SetAllPoints(true)
    unit_nameplate_health_bar.unit_stance.texture:SetTexCoord(0.07, 0.94, 0.07, 0.94)

    unit_nameplate_health_bar.unit_stance.backdrop = CreateFrame(
      "Frame", nil, unit_nameplate_health_bar.unit_stance, "BackdropTemplate"
    )
    ApplyBackdrop(unit_nameplate_health_bar.unit_stance.backdrop)

    unit_nameplate.nameplate_events:HookScript("OnEvent", function(_, event)
      if event == "UNIT_AURA" and unit_nameplate.UnitFrame then
        SetNameplateUnitDebuff(unit_nameplate, unit_nameplate.UnitFrame.unit)
        SetNameplatePlayerDebuffs(unit_nameplate, unit_nameplate.UnitFrame.unit)
        SetNameplateAbsorb(unit_nameplate, unit_nameplate.UnitFrame.unit)
      elseif event == "UNIT_THREAT_LIST_UPDATE" and unit_nameplate.UnitFrame
        and GetDB().nameplate_unit_target_color then
        SetNameplateHealthBarColor(unit_nameplate, unit_nameplate.UnitFrame.healthBar, unit_nameplate.UnitFrame.unit)
      end
    end)

    unit_nameplate.modified = true
  end

  local texture = GetStatusbarTexture()
  unit_nameplate_health_bar:SetStatusBarTexture(texture)
  unit_nameplate_cast_bar:SetStatusBarTexture(texture)

  if not GetDB().enemy_nameplate_health_text then
    unit_nameplate_health_bar.unit_health_text:Hide()
  end

  unit_nameplate_health_bar.unit_debuff:SetScale(GetDB().enemy_nameplate_debuff_scale or 1)
  unit_nameplate_health_bar.player_debuffs:SetScale(GetDB().enemy_nameplate_player_debuffs_scale or 1)
  unit_nameplate_health_bar.unit_stance:SetScale(GetDB().enemy_nameplate_stance_scale or 1)

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
end

local function RemoveUnitNameplate(unit)
  if not unit then return end
  local unit_guid = UnitGUID(unit)
  if not unit_guid then return end

  local unit_nameplate_unit_frame = unit_nameplates[unit_guid]
  if unit_nameplate_unit_frame then
    local unit_nameplate = unit_nameplate_unit_frame:GetParent()
    local unit_nameplate_health_bar = unit_nameplate_unit_frame.healthBar

    if unit_nameplate.nameplate_events then
      unit_nameplate.nameplate_events:UnregisterAllEvents()
    end

    if unit_nameplate_health_bar.absorb then
      unit_nameplate_health_bar.absorb:Hide()
    end

    if unit_nameplate_health_bar.unit_debuff then
      unit_nameplate_health_bar.unit_debuff.current_debuff = nil
      unit_nameplate_health_bar.unit_debuff.cooldown_started = -1
      unit_nameplate_health_bar.unit_debuff.cooldown_duration = -1
      unit_nameplate_health_bar.unit_debuff.filter = nil

      unit_nameplate_health_bar.unit_debuff:Hide()
      unit_nameplate_health_bar.unit_debuff.cooldown:Hide()
    end

    if unit_nameplate_health_bar.unit_stance then
      unit_nameplate_health_bar.unit_stance:Hide()
    end

    if unit_nameplate_health_bar.player_debuffs then
      local player_debuff_frames = { unit_nameplate_health_bar.player_debuffs:GetChildren() }
      for _, player_debuff in ipairs(player_debuff_frames) do
        player_debuff.current_debuff = nil
        player_debuff.cooldown_started = -1
        player_debuff.cooldown_duration = -1
        player_debuff.aura_count = -1

        player_debuff.aura_count_text:SetText("")

        player_debuff:Hide()
        player_debuff.cooldown:Hide()
      end
    end

    unit_nameplates[unit_guid] = nil
  end
end

local function SetNameplatePadding()
  if IsPlaterLoaded() then return end
  if IsSecureUpdateBlocked() then return end

  local db = GetDB()
  local padding = 8
  local name_height = 15

  local enemy_nameplate_width = (db.enemy_nameplate_width or 109) + padding
  local enemy_nameplate_height = (db.enemy_nameplate_height or 12.5) + name_height + padding

  if C_NamePlate and C_NamePlate.SetNamePlateEnemySize then
    C_NamePlate.SetNamePlateEnemySize(enemy_nameplate_width, enemy_nameplate_height)
  end

  local is_in_instance, instance_type = InInstance()

  if is_in_instance and instance_type ~= "pvp" and instance_type ~= "arena" then
    if C_NamePlate and C_NamePlate.SetNamePlateFriendlySize then
      C_NamePlate.SetNamePlateFriendlySize(128, 32)
    end
    return
  end

  local friendly_nameplate_width = (db.friendly_nameplate_width or 42) + padding
  local friendly_nameplate_height = (db.friendly_nameplate_height or 12.5) + name_height + padding

  if C_NamePlate and C_NamePlate.SetNamePlateFriendlySize then
    C_NamePlate.SetNamePlateFriendlySize(friendly_nameplate_width, friendly_nameplate_height)
  end
end

function mod.UpdateExistingNameplatesSize(_)
  SetNameplatePadding()

  for _, unit_nameplate in pairs(unit_nameplates) do
    if unit_nameplate.healthBarWrapper then
      local unit = unit_nameplate.displayedUnit
      local nameplate = C_NamePlate.GetNamePlateForUnit(unit, false)
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
      local unit = unit_nameplate.displayedUnit
      local nameplate = C_NamePlate.GetNamePlateForUnit(unit, false)
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
    if unit_nameplate.healthBarWrapper then
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
    if unit_nameplate.healthBarWrapper then
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
    if unit_nameplate.healthBarWrapper then
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
    if unit_nameplate.healthBarWrapper then
      if not db.enemy_nameplate_health_text then
        unit_nameplate.healthBar.unit_health_text:Hide()
      else
        local unit = unit_nameplate.displayedUnit
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
    if unit_nameplate.healthBarWrapper then
      unit_nameplate.healthBar:SetStatusBarTexture(texture)

      local hover_texture = select(3, unit_nameplate.healthBar:GetRegions())
      if hover_texture and hover_texture.GetTexture and hover_texture:GetTexture() then
        hover_texture:SetTexture(texture)
      end
    end
  end
end

local function EnsureDriver()
  if driver then return end
  driver = CreateFrame("Frame", "EnhanceTBC_NameplateDriver", UIParent)
end

local function HookEvents()
  if hooked then return end
  hooked = true

  EnsureDriver()
  driver:RegisterEvent("PLAYER_ENTERING_WORLD")
  driver:RegisterEvent("DISPLAY_SIZE_CHANGED")
  driver:RegisterEvent("NAME_PLATE_UNIT_ADDED")
  driver:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
  driver:RegisterEvent("DUEL_REQUESTED")
  driver:RegisterEvent("DUEL_FINISHED")
  driver:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  driver:RegisterEvent("PLAYER_REGEN_ENABLED")

  driver:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_ENTERING_WORLD" or event == "DISPLAY_SIZE_CHANGED" then
      SetNameplatePadding()
      return
    end

    if event == "DUEL_REQUESTED" and unit then
      duel_unit = unit
      return
    end

    if event == "DUEL_FINISHED" then
      if duel_unit and not SafeUnitIsUnit(duel_unit, "player") then
        mod:StyleUnitNameplate(duel_unit)
      end
      duel_unit = nil
      return
    end

    if event == "NAME_PLATE_UNIT_ADDED" then
      mod:StyleUnitNameplate(unit)
      return
    end

    if event == "NAME_PLATE_UNIT_REMOVED" then
      RemoveUnitNameplate(unit)
      return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
      local _, combat_event, _, source_guid, source_name, source_flags,
        _, dest_guid, dest_name, dest_flags, _, spell_id = CombatLogGetCurrentEventInfo()
      if not combat_event then return end

      local db = GetDB()
      if combat_event == "SPELL_INTERRUPT" or combat_event == "SPELL_PERIODIC_INTERRUPT" then
        SetNameplateUnitInterrupt(db, dest_guid, dest_name, dest_flags, spell_id)
      elseif combat_event == "SPELL_CAST_SUCCESS" then
        SetNameplateUnitStance(db, source_guid, source_name, source_flags, spell_id)
      elseif combat_event == "SPELL_AURA_APPLIED"
        or combat_event == "SPELL_AURA_REMOVED"
        or combat_event == "SPELL_AURA_BROKEN"
      then
        SetNameplatePlayerMindControl(combat_event, source_name, dest_name, spell_id)
      end
      return
    end

    if event == "PLAYER_REGEN_ENABLED" then
      SetNameplatePadding()
      ApplyExistingNameplates()
    end
  end)
end

local function UnhookEvents()
  if not driver then return end
  driver:UnregisterAllEvents()
  driver:SetScript("OnEvent", nil)
  hooked = false
end

local function ApplyExistingNameplates()
  if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
  for _, nameplate in pairs(C_NamePlate.GetNamePlates(false)) do
    if not ShouldIgnoreNameplate(nameplate)
      and nameplate.UnitFrame
      and nameplate.UnitFrame.displayedUnit
      and UnitExists(nameplate.UnitFrame.displayedUnit) then
      local unit_guid = UnitGUID(nameplate.UnitFrame.displayedUnit)
      if unit_guid and not unit_nameplates[unit_guid] then
        mod:StyleUnitNameplate(nameplate.UnitFrame.displayedUnit)
      end
    end
  end
end

local function ResetNameplates()
  for _, unit_nameplate in pairs(unit_nameplates) do
    if unit_nameplate and unit_nameplate.displayedUnit then
      RemoveUnitNameplate(unit_nameplate.displayedUnit)
    end
  end
end

function mod.Apply(_)
  if IsPlaterLoaded() then
    UnhookEvents()
    ResetNameplates()
    loaded = false
    return
  end

  if not ETBC.db or not ETBC.db.profile or not ETBC.db.profile.general or not ETBC.db.profile.general.enabled then
    UnhookEvents()
    ResetNameplates()
    loaded = false
    return
  end

  if not GetDB().enabled then
    UnhookEvents()
    ResetNameplates()
    loaded = false
    return
  end

  BuildData()
  HookEvents()
  SetNameplatePadding()
  ApplyExistingNameplates()
  loaded = true
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
hooksecurefunc("CompactUnitFrame_UpdateHealth", function(self)
  if self.healthBar and self.healthBarWrapper and self.unit and self:GetParent()
    and self:GetParent().isNamePlate and self:GetParent().nameplate_events then
    SetNameplateHealthBarText(self.healthBar, self.unit)
  end
end)

hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(self)
  if self.healthBar and self.healthBarWrapper and self.healthBar.unit_health_text and self.unit and self:GetParent()
    and self:GetParent().isNamePlate and self:GetParent().nameplate_events then
    SetNameplateHealthBarColor(self:GetParent(), self.healthBar, self.unit)
  end
end)

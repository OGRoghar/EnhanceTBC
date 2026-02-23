-- Modules/Unit_NamePlates/Data.lua
-- EnhanceTBC - Unit nameplate data/build helpers (internal)

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}
local mod = ETBC.Modules.Nameplates
if not mod then return end

mod.Internal = mod.Internal or {}
mod.Internal.Shared = mod.Internal.Shared or {}
local H = mod.Internal.Data or {}
mod.Internal.Data = H

local shared = mod.Internal.Shared
local GetSpellInfoByID = shared.GetSpellInfoByID

local formatted_debuffs = {}
local formatted_interrupts = {}
local formatted_player_debuffs = {}
local formatted_absorb_buffs = {}
local formatted_debuffs_by_spell = {}
local formatted_player_debuffs_by_spell = {}
local formatted_absorb_buffs_by_spell = {}
local prioritized_debuffs = {}
local prioritized_absorb_buffs = {}

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
  formatted_debuffs_by_spell = {}
  formatted_player_debuffs_by_spell = {}
  formatted_absorb_buffs_by_spell = {}
  prioritized_debuffs = {}
  prioritized_absorb_buffs = {}

  for i, debuff_type_list in pairs(debuffs) do
    for _, debuff in pairs(debuff_type_list) do
      local info = GetSpellInfoByID(debuff.spell_id)
      if info and info.name then
        debuff.name = info.name
        debuff.texture = info.iconID
        debuff.priority = i
        formatted_debuffs[debuff.name] = debuff
        if debuff.spell_id then
          formatted_debuffs_by_spell[debuff.spell_id] = debuff
          prioritized_debuffs[#prioritized_debuffs + 1] = debuff
        end
      end
    end
  end

  table.sort(prioritized_debuffs, function(a, b)
    local pa = tonumber(a and a.priority) or 0
    local pb = tonumber(b and b.priority) or 0
    if pa ~= pb then
      return pa > pb
    end
    return (tonumber(a and a.spell_id) or 0) < (tonumber(b and b.spell_id) or 0)
  end)

  for _, interrupt in pairs(interrupts) do
    local info = GetSpellInfoByID(interrupt.spell_id)
    if info and info.name then
      interrupt.name = info.name
      interrupt.texture = info.iconID
      interrupt.priority = 8
      interrupt.interrupt = true
      formatted_interrupts[interrupt.name] = interrupt
    end
  end

  local player_class = select(2, UnitClass("player"))
  for _, debuff_type_list in pairs(player_debuffs) do
    for _, debuff in pairs(debuff_type_list) do
      if debuff.class == player_class then
        local info = GetSpellInfoByID(debuff.spell_id)
        if info and info.name then
          debuff.name = info.name
          debuff.texture = info.iconID
          formatted_player_debuffs[debuff.name] = debuff
          if debuff.spell_id then
            formatted_player_debuffs_by_spell[debuff.spell_id] = debuff
          end
        end
      end
    end
  end

  for _, absorb_buff in pairs(absorb_buffs) do
    local info = GetSpellInfoByID(absorb_buff.spell_id)
    if info and info.name then
      absorb_buff.name = info.name
      absorb_buff.texture = info.iconID
      formatted_absorb_buffs[absorb_buff.name] = absorb_buff
      if absorb_buff.spell_id then
        formatted_absorb_buffs_by_spell[absorb_buff.spell_id] = absorb_buff
        prioritized_absorb_buffs[#prioritized_absorb_buffs + 1] = absorb_buff
      end
    end
  end
end

local function IsTrackedSpellID(spellID)
  local sid = tonumber(spellID)
  if not sid then return false end
  return not not (
    formatted_debuffs_by_spell[sid]
    or formatted_player_debuffs_by_spell[sid]
    or formatted_absorb_buffs_by_spell[sid]
  )
end

local function FindTrackedAbsorbAura(unit)
  if not (C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID) then
    return nil, nil
  end

  for i = 1, #prioritized_absorb_buffs do
    local absorbBuff = prioritized_absorb_buffs[i]
    local spellID = absorbBuff and absorbBuff.spell_id
    if spellID then
      local auraData = C_UnitAuras.GetUnitAuraBySpellID(unit, spellID)
      if auraData then
        if not (
          absorbBuff.track_spell_id
          and auraData.spellId
          and not absorbBuff.track_spell_id[auraData.spellId]
        ) then
          return absorbBuff, auraData
        end
      end
    end
  end

  return nil, nil
end

local function FindPriorityTrackedDebuffAura(unit)
  if not (C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID) then
    return nil, nil
  end

  local now = GetTime()
  local bestDebuff
  local bestAura
  local bestRemaining = -1

  for i = 1, #prioritized_debuffs do
    local debuff = prioritized_debuffs[i]
    local spellID = debuff and debuff.spell_id
    if spellID then
      local auraData = C_UnitAuras.GetUnitAuraBySpellID(unit, spellID)
      if auraData then
        if not (
          debuff.track_spell_id
          and auraData.spellId
          and not debuff.track_spell_id[auraData.spellId]
        ) then
          local expiration = tonumber(auraData.expirationTime) or 0
          local remaining = expiration > 0 and (expiration - now) or 0
          if remaining < 0 then remaining = 0 end
          local priority = tonumber(debuff.priority) or 0
          local bestPriority = tonumber(bestDebuff and bestDebuff.priority) or -1
          if (not bestDebuff)
            or priority > bestPriority
            or (priority == bestPriority and remaining > bestRemaining) then
            bestDebuff = debuff
            bestAura = auraData
            bestRemaining = remaining
          end
        end
      end
    end
  end

  return bestDebuff, bestAura
end

local function ShouldRefreshAurasFromUpdateInfo(updateInfo, db)
  if not (db and db.useAuraDeltaUpdates) then
    return true
  end

  if type(updateInfo) ~= "table" then
    return true
  end

  if updateInfo.isFullUpdate then
    return true
  end

  if type(updateInfo.addedAuras) == "table" then
    for _, auraData in ipairs(updateInfo.addedAuras) do
      if auraData and IsTrackedSpellID(auraData.spellId) then
        return true
      end
    end
  end

  if type(updateInfo.updatedAuraInstanceIDs) == "table" and #updateInfo.updatedAuraInstanceIDs > 0 then
    return true
  end

  if type(updateInfo.removedAuraInstanceIDs) == "table" and #updateInfo.removedAuraInstanceIDs > 0 then
    return true
  end

  return false
end


H.BuildData = BuildData
H.FindTrackedAbsorbAura = FindTrackedAbsorbAura
H.FindPriorityTrackedDebuffAura = FindPriorityTrackedDebuffAura
H.ShouldRefreshAurasFromUpdateInfo = ShouldRefreshAurasFromUpdateInfo

function H.GetFormattedDebuff(name)
  return formatted_debuffs[name]
end

function H.GetFormattedInterrupt(name)
  return formatted_interrupts[name]
end

function H.GetFormattedPlayerDebuff(name)
  return formatted_player_debuffs[name]
end

function H.GetFormattedAbsorbBuff(name)
  return formatted_absorb_buffs[name]
end

function H.GetTotemColorByName(unit_name)
  local totem = totems[unit_name]
  if not totem then return nil end
  return totem_colors[totem.type]
end

function H.GetStanceData(spell_id)
  return stances[spell_id]
end

-- Modules/Unit_NamePlates/CombatLog.lua
-- EnhanceTBC - Unit nameplate combat-log helpers (internal)

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}
local mod = ETBC.Modules.Nameplates
if not mod then return end

mod.Internal = mod.Internal or {}
mod.Internal.Shared = mod.Internal.Shared or {}
local H = mod.Internal.CombatLog or {}
mod.Internal.CombatLog = H

local shared = mod.Internal.Shared
local unit_nameplates = shared.unit_nameplates or {}
local IsFriendlyNameplate = shared.IsFriendlyNameplate
local GetSpellInfoByID = shared.GetSpellInfoByID
local GetFormattedInterrupt = shared.GetFormattedInterrupt
local GetStanceData = shared.GetStanceData

local function SetNameplateUnitInterrupt(db, dest_guid, dest_name, dest_flags, spell_id)
  if not db.enemy_nameplate_debuff then return end

  if not dest_flags then return end
  if bit.band(dest_flags, COMBATLOG_OBJECT_REACTION_HOSTILE) ~= 0 then
    if dest_name then
      local nameplate_debuff = nil

      if unit_nameplates[dest_guid] then
        local unit_nameplate = unit_nameplates[dest_guid]
        if IsFriendlyNameplate and IsFriendlyNameplate(unit_nameplate, dest_name) then return end
        nameplate_debuff = unit_nameplate.healthBar.unit_debuff
      end

      if not nameplate_debuff then return end

      if spell_id then
        local spellInfo = GetSpellInfoByID and GetSpellInfoByID(spell_id)
        local name = spellInfo and spellInfo.name
        local texture = spellInfo and spellInfo.iconID
        local interrupt = GetFormattedInterrupt and GetFormattedInterrupt(name)

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
          or (IsFriendlyNameplate and IsFriendlyNameplate(unit_nameplate_unit_frame, source_name)) then
          return
        end
        nameplate_stance = unit_nameplate_unit_frame.healthBar.unit_stance
      end

      if not nameplate_stance then return end

      local stance = spell_id and GetStanceData and GetStanceData(spell_id) or nil
      if spell_id and stance then
        if spell_id ~= 71 and spell_id ~= 48263 then
          nameplate_stance.texture:SetTexture(stance.texture)
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

  local spellInfo = GetSpellInfoByID and GetSpellInfoByID(spell_id)
  local name = spellInfo and spellInfo.name
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

H.SetNameplateUnitInterrupt = SetNameplateUnitInterrupt
H.SetNameplateUnitStance = SetNameplateUnitStance
H.SetNameplatePlayerMindControl = SetNameplatePlayerMindControl

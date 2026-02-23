-- Modules/Unit_NamePlates/Lifecycle.lua
-- EnhanceTBC - Unit nameplate lifecycle/driver helpers (internal)

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}
local mod = ETBC.Modules.Nameplates
if not mod then return end

mod.Internal = mod.Internal or {}
mod.Internal.Shared = mod.Internal.Shared or {}
local H = mod.Internal.Lifecycle or {}
mod.Internal.Lifecycle = H

local shared = mod.Internal.Shared
local unit_nameplates = shared.unit_nameplates or {}
local runtime = shared.runtime or {}

local GetDB = shared.GetDB
local InInstance = shared.InInstance
local IsPlaterLoaded = shared.IsPlaterLoaded
local IsSecureUpdateBlocked = shared.IsSecureUpdateBlocked
local SafeUnitIsUnit = shared.SafeUnitIsUnit
local ShouldIgnoreNameplate = shared.ShouldIgnoreNameplate
local SetNameplateUnitInterrupt = shared.SetNameplateUnitInterrupt
local SetNameplateUnitStance = shared.SetNameplateUnitStance
local SetNameplatePlayerMindControl = shared.SetNameplatePlayerMindControl

local ApplyExistingNameplates

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
  if IsPlaterLoaded and IsPlaterLoaded() then return end
  if IsSecureUpdateBlocked and IsSecureUpdateBlocked() then return end
  if not GetDB then return end

  local db = GetDB()
  local padding = 8
  local name_height = 15

  local enemy_nameplate_width = (db.enemy_nameplate_width or 109) + padding
  local enemy_nameplate_height = (db.enemy_nameplate_height or 12.5) + name_height + padding

  if C_NamePlate and C_NamePlate.SetNamePlateEnemySize then
    C_NamePlate.SetNamePlateEnemySize(enemy_nameplate_width, enemy_nameplate_height)
  end

  local is_in_instance, instance_type = false, "none"
  if InInstance then
    is_in_instance, instance_type = InInstance()
  end

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

local function EnsureDriver()
  if runtime.driver then return end
  runtime.driver = CreateFrame("Frame", "EnhanceTBC_NameplateDriver", UIParent)
end

local function HookEvents()
  if runtime.hooked then return end
  runtime.hooked = true

  EnsureDriver()
  local driver = runtime.driver
  if not driver then
    runtime.hooked = false
    return
  end

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
      runtime.duel_unit = unit
      return
    end

    if event == "DUEL_FINISHED" then
      if runtime.duel_unit and not (SafeUnitIsUnit and SafeUnitIsUnit(runtime.duel_unit, "player")) then
        mod:StyleUnitNameplate(runtime.duel_unit)
      end
      runtime.duel_unit = nil
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

      local db = GetDB and GetDB() or nil
      if not db then return end

      if combat_event == "SPELL_INTERRUPT" or combat_event == "SPELL_PERIODIC_INTERRUPT" then
        if SetNameplateUnitInterrupt then
          SetNameplateUnitInterrupt(db, dest_guid, dest_name, dest_flags, spell_id)
        end
      elseif combat_event == "SPELL_CAST_SUCCESS" then
        if SetNameplateUnitStance then
          SetNameplateUnitStance(db, source_guid, source_name, source_flags, spell_id)
        end
      elseif combat_event == "SPELL_AURA_APPLIED"
        or combat_event == "SPELL_AURA_REMOVED"
        or combat_event == "SPELL_AURA_BROKEN"
      then
        if SetNameplatePlayerMindControl then
          SetNameplatePlayerMindControl(combat_event, source_name, dest_name, spell_id)
        end
      end
      return
    end

    if event == "PLAYER_REGEN_ENABLED" then
      SetNameplatePadding()
      if ApplyExistingNameplates then
        ApplyExistingNameplates()
      end
    end
  end)
end

local function UnhookEvents()
  if not runtime.driver then return end
  runtime.driver:UnregisterAllEvents()
  runtime.driver:SetScript("OnEvent", nil)
  runtime.hooked = false
end

ApplyExistingNameplates = function()
  if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
  for _, nameplate in pairs(C_NamePlate.GetNamePlates(false)) do
    if not (ShouldIgnoreNameplate and ShouldIgnoreNameplate(nameplate))
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

H.RemoveUnitNameplate = RemoveUnitNameplate
H.SetNameplatePadding = SetNameplatePadding
H.EnsureDriver = EnsureDriver
H.HookEvents = HookEvents
H.UnhookEvents = UnhookEvents
H.ApplyExistingNameplates = ApplyExistingNameplates
H.ResetNameplates = ResetNameplates

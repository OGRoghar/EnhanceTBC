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
local GetNameplateUnit = shared.GetNameplateUnit

local ApplyExistingNameplates

local function RefreshTargetLayouts()
  if mod.UpdateExistingNameplatesSize then mod:UpdateExistingNameplatesSize() end
  if mod.UpdateExistingNameplateComponents then mod:UpdateExistingNameplateComponents() end
end

local function ScheduleTargetLayoutRefresh()
  runtime.targetLayoutGeneration = (runtime.targetLayoutGeneration or 0) + 1
  local generation = runtime.targetLayoutGeneration

  -- Update immediately for responsive emphasis, then reassert the complete
  -- stack after Blizzard's target/focus handlers have finished reanchoring
  -- the native health bar. The second bounded pass covers clients which defer
  -- their selected-nameplate layout by one additional update.
  RefreshTargetLayouts()
  if not C_Timer or not C_Timer.After then return end
  local function DeferredRefresh()
    if runtime.hooked and runtime.targetLayoutGeneration == generation then
      RefreshTargetLayouts()
    end
  end
  C_Timer.After(0, DeferredRefresh)
  C_Timer.After(0.05, DeferredRefresh)
end

local function RemoveUnitNameplate(unit, knownGUID)
  if not unit and not knownGUID then return end
  local unit_guid = knownGUID or (unit and UnitGUID(unit))
  if not unit_guid then
    -- Blizzard can invalidate a nameplate token before the removal callback is
    -- processed. Fall back to the token cached on the styled unit frame so the
    -- GUID-keyed entry and its event frame do not leak.
    for cached_guid, cached_frame in pairs(unit_nameplates) do
      if unit and cached_frame and ((GetNameplateUnit and GetNameplateUnit(cached_frame)) or cached_frame.displayedUnit) == unit then
        unit_guid = cached_guid
        break
      end
    end
  end
  if not unit_guid then return end

  local unit_nameplate_unit_frame = unit_nameplates[unit_guid]
  if unit_nameplate_unit_frame then
    local unit_nameplate = unit_nameplate_unit_frame:GetParent()
    local unit_nameplate_health_bar = unit_nameplate_unit_frame.healthBar

    if unit_nameplate and unit_nameplate.nameplate_events then
      unit_nameplate.nameplate_events:UnregisterAllEvents()
    end

    if mod.Internal.Power then mod.Internal.Power:Reset(unit_nameplate_unit_frame) end
    if mod.Internal.Casts then mod.Internal.Casts:Reset(unit_nameplate_unit_frame) end
    if mod.Internal.Indicators then mod.Internal.Indicators:Reset(unit_nameplate_unit_frame) end
    if mod.Internal.State then mod.Internal.State:Remove(unit, unit_guid) end

    if not unit_nameplate_health_bar then
      unit_nameplates[unit_guid] = nil
      return
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

  local is_in_instance, instance_type = false, "none"
  if InInstance then
    is_in_instance, instance_type = InInstance()
  end

  local friendly_nameplate_width
  local friendly_nameplate_height
  if is_in_instance and instance_type ~= "pvp" and instance_type ~= "arena" then
    friendly_nameplate_width = 128
    friendly_nameplate_height = 32
  else
    friendly_nameplate_width = (db.friendly_nameplate_width or 42) + padding
    friendly_nameplate_height = (db.friendly_nameplate_height or 12.5) + name_height + padding
  end

  -- Build 68575 exposes one shared native nameplate size. Visual enemy and
  -- friendly frames are still sized separately elsewhere, so reserve bounds
  -- large enough for either layout here.
  if C_NamePlate and C_NamePlate.SetNamePlateSize then
    C_NamePlate.SetNamePlateSize(
      math.max(enemy_nameplate_width, friendly_nameplate_width),
      math.max(enemy_nameplate_height, friendly_nameplate_height)
    )
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
  driver:RegisterEvent("PLAYER_TARGET_CHANGED")
  driver:RegisterEvent("PLAYER_FOCUS_CHANGED")

  driver:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
      ScheduleTargetLayoutRefresh()
      return
    end
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
      if runtime.pendingApply then
        runtime.pendingApply = false
        mod:Apply()
      elseif ApplyExistingNameplates then
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
  for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
    local unit = nameplate.UnitFrame and ((GetNameplateUnit and GetNameplateUnit(nameplate.UnitFrame))
      or nameplate.UnitFrame.displayedUnit)
    if not (ShouldIgnoreNameplate and ShouldIgnoreNameplate(nameplate))
      and nameplate.UnitFrame
      and unit
      and UnitExists(unit) then
      local unit_guid = UnitGUID(unit)
      if unit_guid and unit_nameplates[unit_guid] ~= nameplate.UnitFrame then
        mod:StyleUnitNameplate(unit)
      end
    end
  end
end

local function ResetNameplates()
  local pending = {}
  for guid, unit_nameplate in pairs(unit_nameplates) do
    local unit = unit_nameplate and ((GetNameplateUnit and GetNameplateUnit(unit_nameplate))
      or unit_nameplate.displayedUnit)
    pending[#pending + 1] = { unit = unit, guid = guid }
  end
  for _, entry in ipairs(pending) do
    RemoveUnitNameplate(entry.unit, entry.guid)
  end
  if mod.Internal.State then mod.Internal.State:Clear() end
end

H.RemoveUnitNameplate = RemoveUnitNameplate
H.SetNameplatePadding = SetNameplatePadding
H.EnsureDriver = EnsureDriver
H.HookEvents = HookEvents
H.UnhookEvents = UnhookEvents
H.ApplyExistingNameplates = ApplyExistingNameplates
H.ResetNameplates = ResetNameplates
H.ScheduleTargetLayoutRefresh = ScheduleTargetLayoutRefresh

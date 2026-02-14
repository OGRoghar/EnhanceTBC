-- Modules/Visibility.lua
-- EnhanceTBC - Visibility Engine
-- Lightweight: no constant OnUpdate; event-driven with optional throttle.
--
-- API (public):
--  ETBC.Visibility:IsEnabled() -> bool
--  ETBC.Visibility:Evaluate(ruleTableOrPresetKey) -> bool (true = should show)
--  ETBC.Visibility:Bind(key, frame, ruleProviderFn [, onChangeFn]) -> registers a frame for auto show/hide
--  ETBC.Visibility:Unbind(key) -> removes binding
--  ETBC.Visibility:ForceUpdate() -> re-evaluate all bindings now
--
-- Notes:
--  - Rules are ANDed: if you set multiple requirements, all must pass.
--  - Instance selection: if any instance type checkbox is selected, current instance must match one of them.
--  - Uses safe guards for protected frames in combat (will not taint; skips SetShown when forbidden).

local ADDON_NAME, ETBC = ...

ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.Visibility = mod

ETBC.Visibility = ETBC.Visibility or {}
local V = ETBC.Visibility

local driver
local bindings = {} -- key -> { frame, ruleProvider, onChange, lastShown }
local throttleTimer = 0
local pending = false

local function EnsureDriver()
  if driver then return end
  driver = CreateFrame("Frame", "EnhanceTBC_VisibilityDriver", UIParent)
  driver:Hide()
end

local function GetDB()
  ETBC.db.profile.visibility = ETBC.db.profile.visibility or {}
  local db = ETBC.db.profile.visibility
  if db.enabled == nil then db.enabled = true end
  if db.throttle == nil then db.throttle = 0.05 end
  db.presets = db.presets or {}
  db.editor = db.editor or {}
  return db
end

local function PlayerInCombat()
  if InCombatLockdown and InCombatLockdown() then return true end
  if UnitAffectingCombat then return UnitAffectingCombat("player") and true or false end
  return false
end

local function IsBlockedByCombatProtection(frame)
  if not frame then return false end
  return frame.IsProtected and frame:IsProtected() and PlayerInCombat() or false
end

local function InGroupAny()
  if IsInGroup then
    return IsInGroup() and true or false
  end
  if GetNumGroupMembers then
    return (GetNumGroupMembers() or 0) > 0
  end
  return false
end

local function InRaid()
  if IsInRaid then
    return IsInRaid() and true or false
  end
  if GetNumRaidMembers then
    return (GetNumRaidMembers() or 0) > 0
  end
  return false
end

local function InPartyNotRaid()
  if InRaid() then return false end
  if IsInGroup then
    return IsInGroup() and true or false
  end
  if GetNumPartyMembers then
    return (GetNumPartyMembers() or 0) > 0
  end
  return false
end

local function IsMountedSafe()
  if IsMounted then
    local ok, v = pcall(IsMounted)
    if ok then return v and true or false end
  end
  -- fallback: some builds can infer from UnitBuff; but avoid heavy scanning here
  return false
end

local function UnitDeadState()
  if UnitIsDeadOrGhost then return UnitIsDeadOrGhost("player") and true or false end
  if UnitIsDead then return UnitIsDead("player") and true or false end
  return false
end

local function HasTarget()
  if UnitExists then
    return UnitExists("target") and true or false
  end
  return false
end

local function GetInstanceType()
  if not IsInInstance then return "world" end
  local ok, inInstance, instanceType = pcall(IsInInstance)
  if not ok then return "world" end
  if not inInstance then return "world" end
  instanceType = tostring(instanceType or "party")
  -- map to our keys
  if instanceType == "none" then return "world" end
  if instanceType == "party" then return "party" end
  if instanceType == "raid" then return "raid" end
  if instanceType == "arena" then return "arena" end
  if instanceType == "pvp" then return "pvp" end
  if instanceType == "scenario" then return "scenario" end
  return instanceType
end

local function AnyInstanceSelected(rule)
  local inst = rule and rule.instance
  if type(inst) ~= "table" then return false end
  for _, v in pairs(inst) do
    if v then return true end
  end
  return false
end

local function InstancePass(rule)
  local inst = rule and rule.instance
  if type(inst) ~= "table" then return true end
  if not AnyInstanceSelected(rule) then
    return true -- ignore instance type
  end
  local t = GetInstanceType()
  if t == "world" then
    return inst.world and true or false
  end
  return inst[t] and true or false
end

local function NormalizeRule(ruleOrKey)
  local db = GetDB()
  if type(ruleOrKey) == "string" then
    local p = db.presets and db.presets[ruleOrKey]
    if type(p) == "table" then
      return p
    end
    return { enabled = true, mode = "ALWAYS" }
  end
  if type(ruleOrKey) == "table" then
    return ruleOrKey
  end
  return { enabled = true, mode = "ALWAYS" }
end

function V:IsEnabled()
  return GetDB().enabled and true or false
end

function V:Evaluate(ruleOrPresetKey)
  local db = GetDB()
  if not db.enabled then
    return true -- visibility engine disabled = never block
  end

  local rule = NormalizeRule(ruleOrPresetKey)
  if rule.enabled == false then
    return true -- if rule is disabled, don’t block
  end

  if rule.mode == "ALWAYS" then
    return rule.invert and false or true
  end

  local ok = true

  -- Combat
  if rule.requireCombat then
    ok = ok and PlayerInCombat()
  end
  if rule.requireOutOfCombat then
    ok = ok and (not PlayerInCombat())
  end

  -- Group
  if rule.requireGroup then
    ok = ok and InGroupAny()
  end
  if rule.requireRaid then
    ok = ok and InRaid()
  end
  if rule.requireParty then
    ok = ok and InPartyNotRaid()
  end

  -- Player states
  if rule.requireResting then
    ok = ok and (IsResting and IsResting() or false)
  end
  if rule.requireMounted then
    ok = ok and IsMountedSafe()
  end
  if rule.requireDead then
    ok = ok and UnitDeadState()
  end
  if rule.requireAlive then
    ok = ok and (not UnitDeadState())
  end

  -- Targets
  if rule.requireTarget then
    ok = ok and HasTarget()
  end
  if rule.requireNoTarget then
    ok = ok and (not HasTarget())
  end

  -- Instance type
  ok = ok and InstancePass(rule)

  if rule.invert then ok = not ok end
  return ok and true or false
end

local function CanSafelyShowHide(frame)
  if not frame then
    return false
  end
  if not frame.SetShown and (not frame.Show or not frame.Hide) then
    return false
  end
  if IsBlockedByCombatProtection(frame) then
    return false
  end
  return true
end

local function SetShownCompat(frame, shouldShow)
  if not frame then return end
  if frame.SetShown then
    frame:SetShown(shouldShow)
    return
  end
  if shouldShow then
    if frame.Show then frame:Show() end
  else
    if frame.Hide then frame:Hide() end
  end
end

local function ApplyBinding(key, b)
  if not b or not b.frame then return end

  local rule = nil
  if b.ruleProvider then
    local ok, r = pcall(b.ruleProvider)
    if ok then rule = r end
  end

  local shouldShow = V:Evaluate(rule)
  if b.lastShown == shouldShow then
    return
  end

  local frame = b.frame
  if CanSafelyShowHide(frame) then
    SetShownCompat(frame, shouldShow)
    b.lastShown = shouldShow
  else
    -- If protected in combat, do nothing; avoid taint.
    -- Keep lastShown unchanged so we retry after combat/events.
  else
    -- If protected in combat, do nothing; avoid taint
  end

  if b.onChange then
    pcall(b.onChange, shouldShow)
  end
end

function V:Bind(key, frame, ruleProviderFn, onChangeFn)
  if not key or key == "" then return end
  if not frame then return end
  bindings[key] = {
    frame = frame,
    ruleProvider = ruleProviderFn,
    onChange = onChangeFn,
    lastShown = nil,
  }
  -- apply immediately
  ApplyBinding(key, bindings[key])
end

function V:Unbind(key)
  bindings[key] = nil
end

function V:ForceUpdate()
  for k, b in pairs(bindings) do
    ApplyBinding(k, b)
  end
end

local function RequestUpdate()
  local db = GetDB()
  local throttle = tonumber(db.throttle) or 0
  if throttle <= 0 then
    V:ForceUpdate()
    return
  end
  pending = true
  throttleTimer = throttle
  driver:Show()
end

local function OnUpdate(_, elapsed)
  if not pending then
    driver:Hide()
    return
  end
  throttleTimer = throttleTimer - elapsed
  if throttleTimer <= 0 then
    pending = false
    V:ForceUpdate()
    driver:Hide()
  end
end

local function Apply()
  EnsureDriver()
  local db = GetDB()
  local enabled = ETBC.db.profile.general.enabled and db.enabled

  driver:UnregisterAllEvents()
  driver:SetScript("OnUpdate", nil)

  if enabled then
    driver:RegisterEvent("PLAYER_ENTERING_WORLD")
    driver:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    driver:RegisterEvent("PLAYER_REGEN_DISABLED")
    driver:RegisterEvent("PLAYER_REGEN_ENABLED")
    driver:RegisterEvent("GROUP_ROSTER_UPDATE")
    driver:RegisterEvent("PLAYER_UPDATE_RESTING")
    driver:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    driver:RegisterEvent("UNIT_AURA")
    driver:RegisterEvent("PLAYER_DEAD")
    driver:RegisterEvent("PLAYER_ALIVE")
    driver:RegisterEvent("PLAYER_UNGHOST")
    driver:RegisterEvent("PLAYER_TARGET_CHANGED")

    driver:SetScript("OnEvent", function(_, event, unit)
      if event == "UNIT_AURA" and unit ~= "player" then return end
      RequestUpdate()
    end)

    driver:SetScript("OnUpdate", OnUpdate)

    -- initial evaluation
    V:ForceUpdate()
  else
    -- disabled: show everything we control (don’t hide anything)
    local needsDeferredShow = false
    for _, b in pairs(bindings) do
      b.lastShown = nil
      if CanSafelyShowHide(b.frame) then
        SetShownCompat(b.frame, true)
      elseif IsBlockedByCombatProtection(b.frame) then
        needsDeferredShow = true
      end
    end

    if needsDeferredShow then
      driver:RegisterEvent("PLAYER_REGEN_ENABLED")
      driver:SetScript("OnEvent", function()
        for _, b in pairs(bindings) do
          b.lastShown = nil
          if CanSafelyShowHide(b.frame) then
            SetShownCompat(b.frame, true)
          end
        end
        driver:UnregisterAllEvents()
        driver:SetScript("OnEvent", nil)
        driver:Hide()
      end)
      driver:Show()
    else
      driver:Hide()
    end
  end
end

ETBC.ApplyBus:Register("visibility", Apply)
ETBC.ApplyBus:Register("general", Apply)

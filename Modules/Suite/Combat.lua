local ETBC = _G.EnhanceTBC
if not ETBC then return end

ETBC.CombatSuite = ETBC.CombatSuite or {}
local Combat = ETBC.CombatSuite
local segments = {}
local current
local nextID = 1
local driver

local function Enabled()
  local p = ETBC.db and ETBC.db.profile
  return p and p.general.enabled and p.suite and p.suite.combat and p.suite.combat.enabled and p.combat.enabled
end

local function NewSegment()
  local segment = { id = nextID, startedAt = time and time() or 0, actors = {}, deaths = {}, totals = { damage = 0, healing = 0, interrupts = 0, dispels = 0 } }
  nextID = nextID + 1
  current = segment
  table.insert(segments, 1, segment)
  local max = tonumber(ETBC.db.profile.combat.maxSegments) or 10
  while #segments > max do table.remove(segments) end
  if ETBC.PublicAPIInternal then ETBC.PublicAPIInternal.OnCombatSegmentStarted(segment.id) end
  return segment
end

local function Actor(segment, guid, name)
  local key = guid or name or "unknown"
  local actor = segment.actors[key]
  if not actor then actor = { guid = guid, name = name or "Unknown", damage = 0, healing = 0, interrupts = 0, dispels = 0, spells = {} }; segment.actors[key] = actor end
  return actor
end

local function AddAmount(segment, guid, name, category, spellID, amount)
  local actor = Actor(segment, guid, name)
  amount = tonumber(amount) or 0
  actor[category] = (actor[category] or 0) + amount
  segment.totals[category] = (segment.totals[category] or 0) + amount
  if spellID then actor.spells[spellID] = (actor.spells[spellID] or 0) + amount end
end

function Combat:EndSegment()
  if not current then return end
  current.endedAt = time and time() or 0
  if ETBC.PublicAPIInternal then ETBC.PublicAPIInternal.OnCombatSegmentEnded(current.id) end
  current = nil
end

function Combat:ProcessEvent(...)
  if not Enabled() then return end
  local _, event, _, sourceGUID, sourceName, _, _, _, destName, _, _, spellID, _, _, amount = ...
  local segment = current or NewSegment()
  if event == "SWING_DAMAGE" then AddAmount(segment, sourceGUID, sourceName, "damage", nil, spellID)
  elseif event == "SPELL_DAMAGE" or event == "RANGE_DAMAGE" then AddAmount(segment, sourceGUID, sourceName, "damage", spellID, amount)
  elseif event == "SPELL_HEAL" or event == "SPELL_PERIODIC_HEAL" then AddAmount(segment, sourceGUID, sourceName, "healing", spellID, amount)
  elseif event == "SPELL_INTERRUPT" then AddAmount(segment, sourceGUID, sourceName, "interrupts", spellID, 1)
  elseif event == "SPELL_DISPEL" then AddAmount(segment, sourceGUID, sourceName, "dispels", spellID, 1)
  elseif event == "UNIT_DIED" then
    table.insert(segment.deaths, 1, { name = destName or "Unknown", at = time and time() or 0 })
    while #segment.deaths > (tonumber(ETBC.db.profile.combat.maxDeathEvents) or 20) do table.remove(segment.deaths) end
  end
end

function Combat:GetSnapshot(segment, category)
  if not Enabled() then return nil, "combat feature disabled" end
  local selected
  if segment == "current" then selected = current or segments[1]
  elseif segment == "previous" then selected = current and segments[2] or segments[1]
  elseif type(segment) == "number" then for i = 1, #segments do if segments[i].id == segment then selected = segments[i] break end end end
  if not selected then return { category = category, actors = {}, total = 0 } end
  local actors = {}
  for _, actor in pairs(selected.actors) do actors[#actors + 1] = { name = actor.name, value = actor[category] or 0 } end
  table.sort(actors, function(a, b) return a.value > b.value end)
  while #actors > 40 do table.remove(actors) end
  return { id = selected.id, category = category, total = selected.totals[category] or 0, actors = actors, deaths = selected.deaths }
end

function Combat:Apply()
  if not driver then
    driver = CreateFrame("Frame", "EnhanceTBC_CombatDriver")
    driver:SetScript("OnEvent", function(_, event)
      if event == "COMBAT_LOG_EVENT_UNFILTERED" and CombatLogGetCurrentEventInfo then Combat:ProcessEvent(CombatLogGetCurrentEventInfo())
      elseif event == "PLAYER_REGEN_ENABLED" then Combat:EndSegment() end
    end)
  end
  driver:UnregisterAllEvents()
  if Enabled() then driver:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED"); driver:RegisterEvent("PLAYER_REGEN_ENABLED") else self:EndSegment() end
end

ETBC.ApplyBus:Register("combat", function() Combat:Apply() end)
Combat:Apply()

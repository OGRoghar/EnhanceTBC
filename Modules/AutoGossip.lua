-- Modules/AutoGossip.lua
-- Auto-selects specific NPC dialog options based on configured patterns

local _, ETBC = ...
local Compat = ETBC.Compat or {}

ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.AutoGossip = mod

local driver
local pendingGossip = false

local function Print(msg)
  if ETBC.Print then
    ETBC:Print(msg)
  elseif DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99EnhanceTBC|r " .. tostring(msg))
  end
end

local function GetDB()
  ETBC.db.profile.autoGossip = ETBC.db.profile.autoGossip or {}
  local db = ETBC.db.profile.autoGossip

  if db.enabled == nil then db.enabled = true end
  if db.delay == nil then db.delay = 0 end
  if db.useGossipInfo == nil then db.useGossipInfo = true end
  if db.matchByOptionID == nil then db.matchByOptionID = false end
  db.options = db.options or {}
  db.optionIDs = db.optionIDs or {}

  return db
end

local function IsEnabled()
  if not ETBC.db or not ETBC.db.profile then return false end
  local generalDB = ETBC.db.profile.general
  if generalDB and generalDB.enabled == false then return false end

  local db = GetDB()
  return db.enabled
end

local function ShouldAutoSelect()
  -- Don't auto-select if shift is held (bypass mechanism)
  if IsShiftKeyDown() then return false end

  return IsEnabled()
end

local function MatchesPattern(gossipText, pattern)
  if not gossipText or not pattern then return false end

  -- Case-insensitive matching
  local lowerGossip = gossipText:lower()
  local lowerPattern = pattern:lower()

  -- Check if the gossip text contains the pattern
  return lowerGossip:find(lowerPattern, 1, true) ~= nil
end

local function BuildLegacyGossipOptions()
  if type(GetGossipOptions) ~= "function" then
    return {}
  end

  local raw = { GetGossipOptions() }
  local out = {}
  local optionIndex = 0
  for i = 1, #raw, 2 do
    local text = raw[i]
    local optionType = raw[i + 1]
    if text then
      optionIndex = optionIndex + 1
      out[#out + 1] = {
        index = optionIndex,
        orderIndex = optionIndex,
        gossipOptionID = nil,
        name = tostring(text),
        type = optionType,
        status = 0,
        available = true,
        selectable = true,
      }
    end
  end
  return out
end

local function GetNormalizedGossipOptions(db)
  if db.useGossipInfo and Compat.GetGossipOptions then
    local options = Compat.GetGossipOptions()
    if type(options) == "table" and #options > 0 then
      return options
    end
  end

  return BuildLegacyGossipOptions()
end

local function IsOptionSelectable(option)
  if type(option) ~= "table" then return false end
  if option.selectable ~= nil then
    return option.selectable and true or false
  end
  if option.disabled ~= nil then
    return not option.disabled
  end
  local status = tonumber(option.status)
  if status then
    return status == 0
  end
  return true
end

local function HasConfiguredOptionID(db, optionID)
  local id = tonumber(optionID)
  if not id or type(db.optionIDs) ~= "table" then return false end

  if db.optionIDs[id] then
    return true
  end

  for _, configured in ipairs(db.optionIDs) do
    if tonumber(configured) == id then
      return true
    end
  end

  return false
end

local function FindMatchingOption()
  local db = GetDB()
  local options = GetNormalizedGossipOptions(db)
  if type(options) ~= "table" or #options == 0 then return nil end

  if db.matchByOptionID then
    for _, option in ipairs(options) do
      if IsOptionSelectable(option) and HasConfiguredOptionID(db, option.gossipOptionID) then
        return option, option.name, "ID"
      end
    end
  end

  if not db.options or #db.options == 0 then return nil end

  for _, option in ipairs(options) do
    if IsOptionSelectable(option) then
      local gossipText = option.name
      for _, pattern in ipairs(db.options) do
        if MatchesPattern(gossipText, pattern) then
          return option, gossipText, "TEXT"
        end
      end
    end
  end

  return nil
end

local function SelectOption(option)
  if Compat.SelectGossipOption then
    return Compat.SelectGossipOption(option)
  end

  if type(SelectGossipOption) == "function" and type(option) == "table" and option.index then
    local ok = pcall(SelectGossipOption, option.index)
    return ok and true or false
  end

  return false
end

local function AutoSelectGossip()
  if not ShouldAutoSelect() then return end
  if pendingGossip then return end

  local option, optionText, matchType = FindMatchingOption()
  if not option then return end

  pendingGossip = true

  local db = GetDB()
  local delay = db.delay or 0

  if delay > 0 then
    local applySelection = function()
      local currentOption, currentText, currentMatchType = FindMatchingOption()
      if currentOption then
        SelectOption(currentOption)
        if ETBC.db and ETBC.db.profile and ETBC.db.profile.general and ETBC.db.profile.general.debug then
          Print("Auto-selected gossip option (" .. tostring(currentMatchType or "TEXT") .. "): " .. (currentText or "unknown"))
        end
      end
      pendingGossip = false
    end

    if ETBC and ETBC.StartTimer then
      ETBC:StartTimer(delay, applySelection)
    elseif C_Timer and C_Timer.After then
      C_Timer.After(delay, applySelection)
    else
      applySelection()
    end
  else
    SelectOption(option)
    if ETBC.db and ETBC.db.profile and ETBC.db.profile.general and ETBC.db.profile.general.debug then
      Print("Auto-selected gossip option (" .. tostring(matchType or "TEXT") .. "): " .. (optionText or "unknown"))
    end
    pendingGossip = false
  end
end

local function EnsureDriver()
  if driver then return end

  driver = CreateFrame("Frame", "EnhanceTBC_AutoGossipDriver", UIParent)
  driver:Hide()

  driver:RegisterEvent("GOSSIP_SHOW")
  driver:RegisterEvent("GOSSIP_CLOSED")

  driver:SetScript("OnEvent", function(_, event)
    if event == "GOSSIP_SHOW" then
      AutoSelectGossip()
    elseif event == "GOSSIP_CLOSED" then
      pendingGossip = false
    end
  end)
end

function mod.Apply(_)
  if IsEnabled() then
    EnsureDriver()
    driver:Show()
  else
    if driver then
      driver:Hide()
    end
  end
end

-- Register with ApplyBus
if ETBC.ApplyBus then
  ETBC.ApplyBus:Register("autogossip", function()
    mod:Apply()
  end)
end

-- Public API for slash commands
function mod.ListPatterns(_)
  local db = GetDB()
  if not db.options or #db.options == 0 then
    Print("No auto-gossip patterns configured.")
    return
  end

  Print("Auto-Gossip Patterns:")
  for i, pattern in ipairs(db.options) do
    Print("  " .. i .. ". " .. pattern)
  end
end

function mod.AddPattern(_, pattern)
  if not pattern or pattern == "" then
    Print("Usage: /etbc addgossip <pattern text>")
    return
  end

  local db = GetDB()

  -- Check if already exists
  for _, existing in ipairs(db.options) do
    if existing:lower() == pattern:lower() then
      Print("Pattern already exists: " .. pattern)
      return
    end
  end

  table.insert(db.options, pattern)
  Print("Added auto-gossip pattern: " .. pattern)

  if ETBC.ApplyBus then
    ETBC.ApplyBus:Notify("autogossip")
  end
end

-- Modules/AutoGossip.lua
-- Auto-selects specific NPC dialog options based on configured patterns

local ADDON_NAME, ETBC = ...

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
  db.options = db.options or {}
  
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

local function FindMatchingOption()
  local db = GetDB()
  if not db.options or #db.options == 0 then return nil end
  
  -- Get available gossip options
  -- In TBC, GetGossipOptions() returns pairs of (text, type) for each option
  local options = { GetGossipOptions() }
  local numOptions = #options / 2
  
  if numOptions == 0 then return nil end
  
  -- Check each gossip option
  for i = 1, numOptions do
    local textIndex = (i - 1) * 2 + 1
    local gossipText = options[textIndex]
    
    if gossipText then
      -- Check against all patterns
      for _, pattern in ipairs(db.options) do
        if MatchesPattern(gossipText, pattern) then
          return i, gossipText
        end
      end
    end
  end
  
  return nil
end

local function AutoSelectGossip()
  if not ShouldAutoSelect() then return end
  if pendingGossip then return end
  
  local optionIndex, optionText = FindMatchingOption()
  if not optionIndex then return end
  
  pendingGossip = true
  
  local db = GetDB()
  local delay = db.delay or 0
  
  if delay > 0 then
    C_Timer.After(delay, function()
      -- Re-find the matching option after delay to ensure index is still valid
      local currentIndex, currentText = FindMatchingOption()
      if currentIndex then
        SelectGossipOption(currentIndex)
        if ETBC.db and ETBC.db.profile and ETBC.db.profile.general and ETBC.db.profile.general.debug then
          Print("Auto-selected gossip option: " .. (currentText or "unknown"))
        end
      end
      pendingGossip = false
    end)
  else
    SelectGossipOption(optionIndex)
    if ETBC.db and ETBC.db.profile and ETBC.db.profile.general and ETBC.db.profile.general.debug then
      Print("Auto-selected gossip option: " .. (optionText or "unknown"))
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
  
  driver:SetScript("OnEvent", function(self, event, ...)
    if event == "GOSSIP_SHOW" then
      AutoSelectGossip()
    elseif event == "GOSSIP_CLOSED" then
      pendingGossip = false
    end
  end)
end

function mod:Apply()
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
function mod:ListPatterns()
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

function mod:AddPattern(pattern)
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

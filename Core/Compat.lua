-- Core/Compat.lua
-- EnhanceTBC compatibility helpers for TBC Anniversary client API differences

local _, ETBC = ...
ETBC.Compat = ETBC.Compat or {}
local C = ETBC.Compat

-- ---------------------------------------------------------
-- Texture:SetVertexColor compatibility
-- Some modern clients use SetVertexColor(colorMixin [, a])
-- while older code (AceGUI, etc.) uses SetVertexColor(r,g,b,a).
-- This shim makes both work.
-- ---------------------------------------------------------
do
  local shimInstalled = false

  local function MakeColor(r, g, b)
    if CreateColor then
      return CreateColor(r, g, b)
    end
    -- Fallback pseudo-color table; some APIs won't accept it, but CreateColor should exist on your client.
    return { r = r, g = g, b = b }
  end

  local function InstallVertexColorShim()
    if shimInstalled then return end
    if type(CreateFrame) ~= "function" then return end

    local f = CreateFrame("Frame")
    local tex = f:CreateTexture(nil, "ARTWORK")
    if not tex then return end

    -- Detect whether numeric signature works
    local okNumeric = pcall(function() tex:SetVertexColor(1, 1, 1, 1) end)
    if okNumeric then
      -- Nothing to do; classic numeric signature supported.
      shimInstalled = true
      return
    end

    local mt = getmetatable(tex)
    if not mt or not mt.__index then return end
    local idx = mt.__index
    if type(idx) ~= "table" then return end

    local orig = idx.SetVertexColor
    if type(orig) ~= "function" then return end
    if idx.__etbcVertexColorShimInstalled then return end

    idx.SetVertexColor = function(self, a1, a2, a3, a4)
      -- New signature: SetVertexColor(color [, alpha])
      -- Old signature: SetVertexColor(r,g,b,a)

      -- If first arg is a ColorMixin-like table/obj, forward as-is.
      local t = type(a1)
      if t == "table" then
        return orig(self, a1, a2)
      end

      -- If first arg is number, interpret as r,g,b,a
      if t == "number" then
        local r = a1 or 1
        local g = (type(a2) == "number") and a2 or 1
        local b = (type(a3) == "number") and a3 or 1
        local alpha = (type(a4) == "number") and a4 or 1
        local color = MakeColor(r, g, b)

        -- Prefer new signature
        local ok = pcall(function() orig(self, color, alpha) end)
        if ok then return end

        -- If that failed for some reason, try calling without alpha
        return orig(self, color)
      end

      -- Fall back to original behavior
      return orig(self, a1, a2)
    end

    idx.__etbcVertexColorShimInstalled = true
    shimInstalled = true
  end

  InstallVertexColorShim()
end

-- ---------------------------------------------------------
-- GetRaidTargetIndex compatibility
-- TBC 20505 NamePlate code can call GetRaidTargetIndex with nil/invalid unit.
-- Guarding this prevents Blizzard_NamePlates hard errors.
-- ---------------------------------------------------------
do
  if type(GetRaidTargetIndex) == "function" and not _G.__etbcRaidTargetIndexShimInstalled then
    local origGetRaidTargetIndex = GetRaidTargetIndex
    _G.GetRaidTargetIndex = function(unit, ...)
      if type(unit) ~= "string" or unit == "" then
        return nil
      end
      return origGetRaidTargetIndex(unit, ...)
    end
    _G.__etbcRaidTargetIndexShimInstalled = true
  end
end

-- ---------------------------------------------------------
-- Helpers used across modules
-- ---------------------------------------------------------
local function DebugCompat(msg)
  if ETBC and ETBC.Debug then
    ETBC:Debug("[Compat] " .. tostring(msg))
  end
end

function C.Clamp(v, lo, hi)
  v = tonumber(v) or 0
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

function C.SafeCall(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, err = pcall(fn, ...)
  if not ok and DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99EnhanceTBC|r Compat error: " .. tostring(err))
  end
end

-- ---------------------------------------------------------
-- Shared 20505 API wrappers (nil-safe normalized returns)
-- ---------------------------------------------------------
local EMPTY_COOLDOWN = {
  startTime = 0,
  duration = 0,
  isEnabled = false,
  modRate = 1,
}

function C.GetSpellInfoByID(spellID)
  local sid = tonumber(spellID)
  if not sid or sid <= 0 then
    return nil
  end

  if C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, sid)
    if ok and type(info) == "table" and info.name then
      return {
        name = info.name,
        rank = info.subText or info.rank,
        iconID = info.iconID or info.iconFileID or info.icon,
        originalIconID = info.originalIconID or info.iconID or info.iconFileID or info.icon,
        castTimeMS = tonumber(info.castTime) or 0,
        minRange = tonumber(info.minRange) or 0,
        maxRange = tonumber(info.maxRange) or 0,
        spellID = tonumber(info.spellID) or sid,
      }
    end
  end

  if type(GetSpellInfo) == "function" then
    local name, rank, icon, castTime, minRange, maxRange, resolvedID, originalIconID = GetSpellInfo(sid)
    if name then
      return {
        name = name,
        rank = rank,
        iconID = icon,
        originalIconID = originalIconID or icon,
        castTimeMS = tonumber(castTime) or 0,
        minRange = tonumber(minRange) or 0,
        maxRange = tonumber(maxRange) or 0,
        spellID = tonumber(resolvedID) or sid,
      }
    end
  end

  DebugCompat("SpellInfo missing for spellID=" .. tostring(sid))
  return nil
end

function C.GetSpellCooldownByID(spellID)
  local sid = tonumber(spellID)
  if not sid or sid <= 0 then
    return EMPTY_COOLDOWN
  end

  if C_Spell and C_Spell.GetSpellCooldown then
    local ok, info = pcall(C_Spell.GetSpellCooldown, sid)
    if ok and type(info) == "table" then
      return {
        startTime = tonumber(info.startTime) or 0,
        duration = tonumber(info.duration) or 0,
        isEnabled = info.isEnabled and true or false,
        modRate = tonumber(info.modRate) or 1,
      }
    end
  end

  if type(GetSpellCooldown) == "function" then
    local startTime, duration, enabled, modRate = GetSpellCooldown(sid)
    return {
      startTime = tonumber(startTime) or 0,
      duration = tonumber(duration) or 0,
      isEnabled = (enabled == 1) or (enabled == true),
      modRate = tonumber(modRate) or 1,
    }
  end

  return EMPTY_COOLDOWN
end

local function BuildLegacyGossipOptions(rawValues)
  local out = {}
  if type(rawValues) ~= "table" then
    return out
  end

  local optionIndex = 0
  for i = 1, #rawValues, 2 do
    local text = rawValues[i]
    local optionType = rawValues[i + 1]
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
        disabled = false,
        failureDescription = nil,
      }
    end
  end

  return out
end

function C.GetGossipOptions()
  if C_GossipInfo and C_GossipInfo.GetOptions then
    local ok, options = pcall(C_GossipInfo.GetOptions)
    if ok and type(options) == "table" then
      local out = {}
      for i, option in ipairs(options) do
        if type(option) == "table" then
          local status = tonumber(option.status) or 0
          local available = (status == 0)
          local orderIndex = tonumber(option.orderIndex) or i
          out[#out + 1] = {
            index = i,
            orderIndex = orderIndex,
            gossipOptionID = tonumber(option.gossipOptionID),
            name = option.name or "",
            type = option.type,
            status = status,
            available = available,
            selectable = available,
            disabled = not available,
            failureDescription = option.failureDescription,
          }
        end
      end
      return out
    end
  end

  if type(GetGossipOptions) == "function" then
    local raw = { GetGossipOptions() }
    return BuildLegacyGossipOptions(raw)
  end

  return {}
end

function C.SelectGossipOption(option)
  local selectedIndex
  local selectedOrderIndex
  local selectedOptionID
  local selectedName

  if type(option) == "table" then
    selectedIndex = tonumber(option.index)
    selectedOrderIndex = tonumber(option.orderIndex) or selectedIndex
    selectedOptionID = tonumber(option.gossipOptionID) or tonumber(option.optionID)
    selectedName = option.name
  else
    selectedIndex = tonumber(option)
    selectedOrderIndex = selectedIndex
  end

  if C_GossipInfo then
    if selectedOptionID and C_GossipInfo.SelectOption then
      local ok = pcall(C_GossipInfo.SelectOption, selectedOptionID, selectedName, true)
      if ok then return true end
    end

    if selectedOrderIndex and C_GossipInfo.SelectOptionByIndex then
      local ok = pcall(C_GossipInfo.SelectOptionByIndex, selectedOrderIndex)
      if ok then return true end
    end
  end

  if selectedIndex and type(SelectGossipOption) == "function" then
    local ok = pcall(SelectGossipOption, selectedIndex)
    if ok then return true end
  end

  return false
end

function C.IsMailCommandPending()
  if C_Mail and C_Mail.IsCommandPending then
    local ok, pending = pcall(C_Mail.IsCommandPending)
    if ok then
      return pending and true or false
    end
  end
  return false
end

function C.HasInboxMoney(index, headerMoney)
  local inboxIndex = tonumber(index)
  if not inboxIndex or inboxIndex < 1 then
    return false
  end

  if C_Mail and C_Mail.HasInboxMoney then
    local ok, hasMoney = pcall(C_Mail.HasInboxMoney, inboxIndex)
    if ok then
      return hasMoney and true or false
    end
  end

  return (tonumber(headerMoney) or 0) > 0
end

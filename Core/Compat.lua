-- Core/Compat.lua
-- EnhanceTBC compatibility helpers for TBC Anniversary client API differences

local ADDON_NAME, ETBC = ...
local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceTBC")
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
-- Helpers used across modules
-- ---------------------------------------------------------
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

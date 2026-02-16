-- spec/wow_mocks.lua
-- Mock WoW API functions and globals for testing

-- Global mock for LibStub
_G.LibStub = function(name)
  if name == "AceLocale-3.0" then
    return {
      GetLocale = function()
        return {}
      end
    }
  end
  return {}
end

-- Mock common WoW API functions
_G.CreateFrame = function(frameType, name, parent)
  return {
    SetPoint = function() end,
    SetSize = function() end,
    SetScale = function() end,
    Show = function() end,
    Hide = function() end,
    SetScript = function() end,
    GetScript = function() return nil end,
    RegisterEvent = function() end,
    UnregisterEvent = function() end,
    RegisterUnitEvent = function() end,
    UnregisterUnitEvent = function() end,
  }
end

_G.UIParent = CreateFrame("Frame", "UIParent")

_G.GetTime = function()
  return os.time()
end

_G.C_Timer = {
  After = function(delay, callback)
    callback()
  end,
  NewTicker = function(interval, callback, iterations)
    return {
      Cancel = function() end
    }
  end
}

_G.IsShiftKeyDown = function() return false end
_G.IsControlKeyDown = function() return false end
_G.IsAltKeyDown = function() return false end

_G.InCombatLockdown = function() return false end

_G.DEFAULT_CHAT_FRAME = {
  AddMessage = function(msg) 
    -- Silent in tests
  end
}

_G.pcall = pcall
_G.type = type
_G.tostring = tostring
_G.tonumber = tonumber
_G.pairs = pairs
_G.ipairs = ipairs
_G.next = next
_G.select = select
_G.unpack = unpack or table.unpack
_G.table = table
_G.string = string
_G.math = math

-- Helper to reset mocks between tests
local M = {}

function M.reset()
  -- Reset any stateful mocks here
end

return M

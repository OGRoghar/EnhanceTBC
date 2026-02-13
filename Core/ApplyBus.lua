-- Core/ApplyBus.lua
local ADDON_NAME, ETBC = ...

ETBC.ApplyBus = ETBC.ApplyBus or {}

local listeners = {}

function ETBC.ApplyBus:Register(key, fn)
  if not key or type(fn) ~= "function" then return end
  listeners[key] = listeners[key] or {}
  table.insert(listeners[key], fn)
end

function ETBC.ApplyBus:Notify(key)
  local list = listeners[key]
  if not list then return end
  for i = 1, #list do
    local ok, err = pcall(list[i], key)
    if not ok then
      if ETBC and ETBC.Debug then ETBC:Debug("ApplyBus error ("..tostring(key).."): "..tostring(err)) end
    end
  end
end

function ETBC.ApplyBus:NotifyAll()
  for key in pairs(listeners) do
    self:Notify(key)
  end
end

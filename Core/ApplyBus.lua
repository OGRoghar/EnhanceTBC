-- Core/ApplyBus.lua
local ADDON_NAME, ETBC = ...

ETBC.ApplyBus = ETBC.ApplyBus or {}

local listeners = {}

function ETBC.ApplyBus:Register(key, fn)
  if not key or type(fn) ~= "function" then return end
  listeners[key] = listeners[key] or {}
  for i = 1, #listeners[key] do
    if listeners[key][i] == fn then
      return
    end
  end
  table.insert(listeners[key], fn)
end

function ETBC.ApplyBus:Unregister(key, fn)
  local list = listeners[key]
  if not list or type(fn) ~= "function" then return end
  for i = #list, 1, -1 do
    if list[i] == fn then
      table.remove(list, i)
    end
  end
end

function ETBC.ApplyBus:Notify(key)
  local list = listeners[key]
  if not list then return end
  local snapshot = {}
  for i = 1, #list do snapshot[i] = list[i] end
  for i = 1, #snapshot do
    local ok, err = pcall(snapshot[i], key)
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

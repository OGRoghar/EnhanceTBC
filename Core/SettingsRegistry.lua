-- Core/SettingsRegistry.lua
-- Central registry of settings groups for the config window / options builder

local _, ETBC = ...
ETBC.SettingsRegistry = ETBC.SettingsRegistry or {}

local reg = {
  groups = {},     -- ordered list
  byKey = {},      -- key -> group
}

local function NormalizeOrder(v, fallback)
  local n = tonumber(v)
  if n == nil then
    return fallback
  end
  return n
end

function ETBC.SettingsRegistry.RegisterGroup(_, key, group)
  if type(key) ~= "string" or key == "" or type(group) ~= "table" then return end

  local existing = reg.byKey[key]
  if existing then
    for i = #reg.groups, 1, -1 do
      if reg.groups[i] == existing then
        table.remove(reg.groups, i)
        break  -- Only one instance should exist
      end
    end
  end

  group.key = key
  group.order = NormalizeOrder(group.order, #reg.groups + 1)
  group.name = group.name or key

  reg.byKey[key] = group

  local inserted = false
  for i = 1, #reg.groups do
    local curr = reg.groups[i]
    local currOrder = NormalizeOrder(curr and curr.order, i)
    local currKey = tostring(curr and curr.key or "")
    if group.order < currOrder or (group.order == currOrder and key < currKey) then
      table.insert(reg.groups, i, group)
      inserted = true
      break
    end
  end
  if not inserted then
    table.insert(reg.groups, group)
  end
end

function ETBC.SettingsRegistry.GetGroups(_)
  local out = {}
  for i = 1, #reg.groups do
    out[i] = reg.groups[i]
  end
  return out
end

function ETBC.SettingsRegistry.Get(_, key)
  return reg.byKey[key]
end

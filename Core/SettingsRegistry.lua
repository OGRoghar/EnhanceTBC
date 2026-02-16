-- Core/SettingsRegistry.lua
-- Central registry of settings groups for the config window / options builder

local ADDON_NAME, ETBC = ...

ETBC.SettingsRegistry = ETBC.SettingsRegistry or {}

local reg = {
  groups = {},     -- ordered list
  byKey = {},      -- key -> group
}

function ETBC.SettingsRegistry:RegisterGroup(key, group)
  if type(key) ~= "string" or type(group) ~= "table" then return end

  local existing = reg.byKey[key]
  if existing then
    for i = #reg.groups, 1, -1 do
      if reg.groups[i] == existing then
        table.remove(reg.groups, i)
      end
    end
  end

  group.key = key
  group.order = group.order or (#reg.groups + 1)
  group.name = group.name or key

  reg.byKey[key] = group

  local inserted = false
  for i = 1, #reg.groups do
    if group.order < (reg.groups[i].order or i) then
      table.insert(reg.groups, i, group)
      inserted = true
      break
    end
  end
  if not inserted then
    table.insert(reg.groups, group)
  end
end

function ETBC.SettingsRegistry:GetGroups()
  local out = {}
  for i = 1, #reg.groups do
    out[i] = reg.groups[i]
  end
  return out
end

function ETBC.SettingsRegistry:Get(key)
  return reg.byKey[key]
end

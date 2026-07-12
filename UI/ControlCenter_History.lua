local _, ETBC = ...
ETBC.UI = ETBC.UI or {}
ETBC.UI.ChangeHistory = ETBC.UI.ChangeHistory or {}
local History = ETBC.UI.ChangeHistory
local entries, limit = {}, 20

local function Copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}; if seen[value] then return seen[value] end
  local out = {}; seen[value] = out
  for k, v in pairs(value) do out[Copy(k, seen)] = Copy(v, seen) end
  return out
end

function History:Record(key, label, oldValue, newValue, undo)
  if type(undo) ~= "function" then return end
  local now = GetTime and GetTime() or 0
  local last = entries[1]
  if last and last.key == key and now - last.at < 0.7 then
    last.newValue, last.at = Copy(newValue), now
    return last
  end
  table.insert(entries, 1, { key=key, label=tostring(label or key), oldValue=Copy(oldValue), newValue=Copy(newValue), undo=undo, at=now })
  while #entries > limit do table.remove(entries) end
end

function History:UndoLatest()
  local entry = table.remove(entries, 1)
  if not entry then return false, "nothing to undo" end
  local ok, err = pcall(entry.undo, Copy(entry.oldValue))
  if not ok then return false, tostring(err) end
  return true, entry.label
end

function History:Clear() wipe(entries) end
function History:GetRecent(max)
  local out = {}; max = math.min(tonumber(max) or 5, #entries)
  for i = 1, max do out[i] = { key=entries[i].key, label=entries[i].label, at=entries[i].at } end
  return out
end

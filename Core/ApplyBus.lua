-- Core/ApplyBus.lua
local _, ETBC = ...
ETBC.ApplyBus = ETBC.ApplyBus or {}

local listeners = {}
local pendingKeys = {}
local pendingOrder = {}
local snapshot = {}
local flushScheduled = false
local flushing = false
local batchDepth = 0

local function LogApplyError(key, err)
  if ETBC and ETBC.Debug then
    ETBC:Debug("ApplyBus error (" .. tostring(key) .. "): " .. tostring(err))
  end
end

local function DispatchKey(key)
  local list = listeners[key]
  if not list then return end

  local n = #list
  for i = 1, n do
    snapshot[i] = list[i]
  end

  for i = 1, n do
    local fn = snapshot[i]
    snapshot[i] = nil
    if type(fn) == "function" then
      local ok, err = pcall(fn, key)
      if not ok then
        LogApplyError(key, err)
      end
    end
  end
end

local function QueueKey(key)
  if type(key) ~= "string" or key == "" then return end
  if pendingKeys[key] then return end
  pendingKeys[key] = true
  pendingOrder[#pendingOrder + 1] = key
end

local function FlushPending()
  if flushing then return end
  flushing = true

  -- Swap queues up front so recursive/batched Notify calls enqueue into a fresh buffer.
  local order = pendingOrder
  local queued = pendingKeys
  pendingOrder = {}
  pendingKeys = {}

  for i = 1, #order do
    local key = order[i]
    order[i] = nil
    if type(key) == "string" and key ~= "" then
      queued[key] = nil
      DispatchKey(key)
    end
  end

  flushing = false
end

local function ScheduleFlush()
  if flushScheduled or batchDepth > 0 then return end
  flushScheduled = true

  local run = function()
    flushScheduled = false
    if batchDepth == 0 then
      FlushPending()
    end
  end

  if ETBC and ETBC.StartTimer then
    ETBC:StartTimer(0, run)
    return
  end

  if C_Timer and C_Timer.After then
    C_Timer.After(0, run)
    return
  end

  run()
end

function ETBC.ApplyBus.Register(_, key, fn)
  if not key or type(fn) ~= "function" then return end
  listeners[key] = listeners[key] or {}
  for i = 1, #listeners[key] do
    if listeners[key][i] == fn then
      return
    end
  end
  table.insert(listeners[key], fn)
end

function ETBC.ApplyBus.Unregister(_, key, fn)
  local list = listeners[key]
  if not list or type(fn) ~= "function" then return end
  for i = #list, 1, -1 do
    if list[i] == fn then
      table.remove(list, i)
    end
  end
end

function ETBC.ApplyBus.Notify(_, key)
  if not listeners[key] then return end
  QueueKey(key)
  ScheduleFlush()
end

function ETBC.ApplyBus.NotifyAll(_)
  for key in pairs(listeners) do
    QueueKey(key)
  end
  ScheduleFlush()
end

function ETBC.ApplyBus.NotifyNow(_, key)
  if not listeners[key] then return end
  QueueKey(key)
  FlushPending()
end

function ETBC.ApplyBus.NotifyAllNow(_)
  for key in pairs(listeners) do
    QueueKey(key)
  end
  FlushPending()
end

function ETBC.ApplyBus.BeginBatch(_)
  batchDepth = batchDepth + 1
end

function ETBC.ApplyBus.EndBatch(_, flushNow)
  if batchDepth <= 0 then
    batchDepth = 0
  else
    batchDepth = batchDepth - 1
  end

  if batchDepth > 0 then return end
  if flushNow then
    FlushPending()
  else
    ScheduleFlush()
  end
end

function ETBC.ApplyBus.Keys(_)
  local out = {}
  for key in pairs(listeners) do
    out[#out + 1] = key
  end
  table.sort(out)
  return out
end

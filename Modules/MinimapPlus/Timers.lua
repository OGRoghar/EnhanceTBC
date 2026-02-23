-- Modules/MinimapPlus_Timers.lua
-- EnhanceTBC - MinimapPlus ticker/scheduler helpers (internal).

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}

local mod = ETBC.Modules.MinimapPlus
if not mod then return end

mod.Internal = mod.Internal or {}
local H = {}
mod.Internal.Timers = H

local function GetShared()
  return mod.Internal and mod.Internal.Shared
end

local function GetState()
  local shared = GetShared()
  return shared and shared.state
end

local function CallGetDB()
  local shared = GetShared()
  if shared and type(shared.GetDB) == "function" then
    return shared.GetDB()
  end
  return nil
end

local function CancelTicker(t)
  if t and t.Cancel then t:Cancel() end
end

local function StopTickers()
  local state = GetState()
  if not state then return end

  CancelTicker(state.msTicker)
  CancelTicker(state.fpsTicker)
  CancelTicker(state.friendsTicker)
  CancelTicker(state.guildTicker)
  CancelTicker(state.sinkScanTicker)
  state.msTicker = nil
  state.fpsTicker = nil
  state.friendsTicker = nil
  state.guildTicker = nil
  state.sinkScanTicker = nil
end

local function NewTicker(interval, fn)
  if ETBC and ETBC.StartRepeatingTimer then
    local t = ETBC:StartRepeatingTimer(interval, fn)
    if t then return t end
  end
  if C_Timer and C_Timer.NewTicker then
    return C_Timer.NewTicker(interval, fn)
  end
  return nil
end

local function AfterDelay(delay, fn)
  if ETBC and ETBC.StartTimer then
    local t = ETBC:StartTimer(delay, fn)
    if t then return t end
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(delay, fn)
    return true
  end
  fn()
  return true
end

local function StartTickers()
  local state = GetState()
  local db = CallGetDB()
  if not (state and db) then return end

  StopTickers()
  if not db.enabled then return end

  if db.minimap_performance and state.performanceFrame then
    state.msTicker = NewTicker(30, function()
      if state.performanceFrame and state.performanceFrame.updateMsDisplay then
        state.performanceFrame:updateMsDisplay()
      end
    end)
    state.fpsTicker = NewTicker(1, function()
      if state.performanceFrame and state.performanceFrame.updateFpsDisplay then
        state.performanceFrame:updateFpsDisplay()
      end
    end)
  end

  if db.minimap_icons and state.iconsFrame then
    state.friendsTicker = NewTicker(5, function()
      if state.iconsFrame and state.iconsFrame.updateFriendsDisplay then
        state.iconsFrame:updateFriendsDisplay()
      end
    end)
    state.guildTicker = NewTicker(5, function()
      if state.iconsFrame and state.iconsFrame.updateGuildDisplay then
        state.iconsFrame:updateGuildDisplay()
      end
    end)
  end

  if db.sink_addons and state.sinkFrame then
    local interval = tonumber(db.sink_scan_interval) or 5
    if interval < 1 then interval = 1 end
    state.sinkScanTicker = NewTicker(interval, function()
      -- Periodic scans avoid global namespace iteration; full scans are event-driven.
      mod:ScanForAddonButtons(false)
    end)
  end
end

H.CancelTicker = CancelTicker
H.StopTickers = StopTickers
H.NewTicker = NewTicker
H.AfterDelay = AfterDelay
H.StartTickers = StartTickers

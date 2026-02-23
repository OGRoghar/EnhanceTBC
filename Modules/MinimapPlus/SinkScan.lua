-- Modules/MinimapPlus_SinkScan.lua
-- EnhanceTBC - MinimapPlus sink scan/capture driver (internal).

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}

local mod = ETBC.Modules.MinimapPlus
if not mod then return end

mod.Internal = mod.Internal or {}
local H = {}
mod.Internal.SinkScan = H

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

local function GetLDBIcon()
  local shared = GetShared()
  return shared and shared.LDBIcon
end

local function ScanForAddonButtons(self, fullScan)
  local state = GetState()
  local db = CallGetDB()
  if not (state and db) then return end
  if not (db.enabled and db.sink_addons and state.sinkFrame) then return end
  if InCombatLockdown and InCombatLockdown() then return end

  -- Only keep LibDBIcon buttons managed by the sink.
  for btn, info in pairs(state.sinkManaged) do
    local name = btn and btn.GetName and btn:GetName() or nil
    if not (type(name) == "string" and name:find("^LibDBIcon10_")) then
      if btn and info then
        if btn.SetParent and info.parent then btn:SetParent(info.parent) end
        if btn.ClearAllPoints then btn:ClearAllPoints() end
        if info.points and btn.SetPoint then
          for i = 1, #info.points do
            local p = info.points[i]
            btn:SetPoint(p[1], p[2], p[3], p[4], p[5])
          end
        end
        if btn.SetSize and info.width and info.height then btn:SetSize(info.width, info.height) end
        if btn.SetScale and info.scale then btn:SetScale(info.scale) end
        if btn.SetFrameStrata and info.strata then btn:SetFrameStrata(info.strata) end
        if btn.SetFrameLevel and info.level then btn:SetFrameLevel(info.level) end
        if btn.Show then btn:Show() end
      end
      state.sinkManaged[btn] = nil
    end
  end

  local function TryCapture(candidate)
    if type(candidate) == "table" and not candidate.GetObjectType and candidate.button then
      candidate = candidate.button
    end
    if mod:LooksLikeMinimapButton(candidate) then
      mod:CaptureSinkButton(candidate)
      return true
    end
    return false
  end

  local ldbIcon = GetLDBIcon()
  if ldbIcon and ldbIcon.objects and ldbIcon.GetMinimapButton then
    for ldbName in pairs(ldbIcon.objects) do
      local ok, btn = pcall(ldbIcon.GetMinimapButton, ldbIcon, ldbName)
      if ok and btn then
        TryCapture(btn)
      end
    end
  end

  if fullScan ~= false then
    for name, obj in pairs(_G) do
      if type(name) == "string" and name:find("^LibDBIcon10_") then
        TryCapture(obj)
      end
    end
  end

  self:LayoutSinkButtons()
end

H.ScanForAddonButtons = ScanForAddonButtons

-- Modules/MinimapPlus_Sink.lua
-- EnhanceTBC - MinimapPlus sink layout helpers (internal).

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}

local mod = ETBC.Modules.MinimapPlus
if not mod then return end

mod.Internal = mod.Internal or {}
local H = {}
mod.Internal.Sink = H

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

local function ApplySinkAnchor()
  local state = GetState()
  if not (state and state.sinkFrame) then return end

  local db = CallGetDB()
  if not db then return end

  state.sinkFrame:ClearAllPoints()

  if db.sink_moved and type(db.sink_anchor) == "table" then
    state.sinkFrame:SetPoint(
      db.sink_anchor.point or "CENTER",
      UIParent,
      db.sink_anchor.relPoint or "CENTER",
      db.sink_anchor.x or 0,
      db.sink_anchor.y or 0
    )
  else
    state.sinkFrame:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMLEFT", -6, 0)
  end
end

local function SetManagedButtonsShown(shown)
  local state = GetState()
  if not state then return end

  for btn in pairs(state.sinkManaged or {}) do
    if btn then
      if shown then
        if btn.Show then btn:Show() end
      else
        if btn.Hide then btn:Hide() end
      end
    end
  end
end

H.ApplySinkAnchor = ApplySinkAnchor
H.SetManagedButtonsShown = SetManagedButtonsShown

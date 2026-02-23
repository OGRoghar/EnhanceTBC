-- Modules/MinimapPlus_Tracking.lua
-- EnhanceTBC - MinimapPlus tracking widget helpers (internal).

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}

local mod = ETBC.Modules.MinimapPlus
if not mod then return end

mod.Internal = mod.Internal or {}
local H = {}
mod.Internal.Tracking = H

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

local function GetTrackingNoneTexture()
  local shared = GetShared()
  if shared and type(shared.TRACKING_NONE_TEXTURE) == "string" and shared.TRACKING_NONE_TEXTURE ~= "" then
    return shared.TRACKING_NONE_TEXTURE
  end
  return "Interface\\Minimap\\Tracking\\None"
end

local function GetTrackingEntries()
  local entries = {}
  if C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo then
    local count = tonumber(C_Minimap.GetNumTrackingTypes()) or 0
    for index = 1, count do
      local info = C_Minimap.GetTrackingInfo(index)
      if info then
        entries[#entries + 1] = {
          index = index,
          name = info.name or ("#" .. tostring(index)),
          texture = info.texture,
          active = info.active and true or false,
          type = info.type,
        }
      end
    end
  end
  return entries
end

local function GetTrackingSnapshot()
  local snapshot = {
    activeCount = 0,
    names = {},
    texture = GetTrackingNoneTexture(),
  }

  local entries = GetTrackingEntries()
  local firstActiveTexture
  local spellTexture
  for _, entry in ipairs(entries) do
    if entry.active then
      snapshot.activeCount = snapshot.activeCount + 1
      snapshot.names[#snapshot.names + 1] = entry.name
      if not firstActiveTexture and entry.texture then
        firstActiveTexture = entry.texture
      end
      if not spellTexture and entry.type == "spell" and entry.texture then
        spellTexture = entry.texture
      end
    end
  end

  if spellTexture then
    snapshot.texture = spellTexture
  elseif firstActiveTexture then
    snapshot.texture = firstActiveTexture
  elseif GetTrackingTexture then
    local icon = GetTrackingTexture()
    if icon then
      snapshot.texture = icon
      snapshot.activeCount = 1
      snapshot.names[1] = TRACKING or "Tracking"
    end
  end

  return snapshot
end

local function CycleTrackingForward()
  local db = CallGetDB()
  if not (db and db.enableTrackingQuickToggle) then return false end
  if not (C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo and C_Minimap.SetTracking) then
    return false
  end

  local ordered = {}
  local activePos
  local count = tonumber(C_Minimap.GetNumTrackingTypes()) or 0
  for index = 1, count do
    local info = C_Minimap.GetTrackingInfo(index)
    if info then
      ordered[#ordered + 1] = index
      if info.active and not activePos then
        activePos = #ordered
      end
    end
  end

  if #ordered == 0 then return false end

  local nextPos = activePos and ((activePos % #ordered) + 1) or 1
  if C_Minimap.ClearAllTracking then
    C_Minimap.ClearAllTracking()
  else
    for _, index in ipairs(ordered) do
      local info = C_Minimap.GetTrackingInfo(index)
      if info and info.active then
        C_Minimap.SetTracking(index, false)
      end
    end
  end

  C_Minimap.SetTracking(ordered[nextPos], true)
  return true
end

local function ShowTrackingTooltip(anchor)
  if not (GameTooltip and anchor) then return end

  GameTooltip:SetOwner(anchor, "ANCHOR_BOTTOMLEFT")
  GameTooltip:SetText(TRACKING or "Tracking", 1, 1, 1)

  local snapshot = GetTrackingSnapshot()
  if snapshot.activeCount > 0 then
    local maxLines = math.min(#snapshot.names, 6)
    for i = 1, maxLines do
      GameTooltip:AddLine(snapshot.names[i], 0.8, 1.0, 0.8, true)
    end
    if #snapshot.names > maxLines then
      GameTooltip:AddLine("...", 0.6, 0.6, 0.6)
    end
  else
    GameTooltip:AddLine(MINIMAP_TRACKING_TOOLTIP_NONE or (NONE or "None"), 0.7, 0.7, 0.7, true)
  end

  local db = CallGetDB()
  if db and db.enableTrackingQuickToggle then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click to cycle tracking filters.", 0.8, 0.8, 0.8, true)
  end
  GameTooltip:Show()
end

local function TrackingWidget_OnEnter(self)
  ShowTrackingTooltip(self)
end

local function TrackingWidget_OnLeave()
  if GameTooltip then GameTooltip:Hide() end
end

local function TrackingWidget_OnClick()
  if not CycleTrackingForward() then return end
  local state = GetState()
  if not state then return end

  if state.iconsFrame and state.iconsFrame.updateTrackingDisplay then
    state.iconsFrame:updateTrackingDisplay()
  end
  if state.sinkFrame and state.sinkFrame.updateTrackingDisplay then
    state.sinkFrame:updateTrackingDisplay()
  end
end

H.GetTrackingEntries = GetTrackingEntries
H.GetTrackingSnapshot = GetTrackingSnapshot
H.CycleTrackingForward = CycleTrackingForward
H.ShowTrackingTooltip = ShowTrackingTooltip
H.TrackingWidget_OnEnter = TrackingWidget_OnEnter
H.TrackingWidget_OnLeave = TrackingWidget_OnLeave
H.TrackingWidget_OnClick = TrackingWidget_OnClick

-- Modules/MinimapPlus_SinkFrame.lua
-- EnhanceTBC - MinimapPlus sink frame construction (internal).

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}

local mod = ETBC.Modules.MinimapPlus
if not mod then return end

mod.Internal = mod.Internal or {}
local H = {}
mod.Internal.SinkFrame = H

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

local function CallIsFeatureEnabled()
  local shared = GetShared()
  if shared and type(shared.IsFeatureEnabled) == "function" then
    return shared.IsFeatureEnabled()
  end
  return false
end

local function CallApplyFont(fs, size)
  local shared = GetShared()
  if shared and type(shared.ApplyFont) == "function" then
    shared.ApplyFont(fs, size)
  end
end

local function CallGetTrackingSnapshot()
  local shared = GetShared()
  if shared and type(shared.GetTrackingSnapshot) == "function" then
    return shared.GetTrackingSnapshot()
  end
  return {
    activeCount = 0,
    names = {},
    texture = (GetShared() and GetShared().TRACKING_NONE_TEXTURE) or "Interface\\Minimap\\Tracking\\None",
  }
end

local function CallApplySinkAnchor()
  local shared = GetShared()
  if shared and type(shared.ApplySinkAnchor) == "function" then
    shared.ApplySinkAnchor()
  end
end

local function GetTrackingWidgetCallback(name)
  local shared = GetShared()
  if not shared then return nil end
  return shared[name]
end

local function GetTrackingNoneTexture()
  local shared = GetShared()
  if shared and type(shared.TRACKING_NONE_TEXTURE) == "string" and shared.TRACKING_NONE_TEXTURE ~= "" then
    return shared.TRACKING_NONE_TEXTURE
  end
  return "Interface\\Minimap\\Tracking\\None"
end

local function GetSinkConstants()
  local shared = GetShared() or {}
  return {
    minWidth = tonumber(shared.SINK_MIN_WIDTH) or 104,
    minHeight = tonumber(shared.SINK_MIN_HEIGHT) or 32,
    padding = tonumber(shared.SINK_PADDING) or 6,
    trackingRowHeight = tonumber(shared.SINK_TRACKING_ROW_HEIGHT) or 16,
  }
end

local function EnsureSinkFrame()
  local state = GetState()
  if not state or state.sinkFrame then return end

  local C = GetSinkConstants()
  local trackingNoneTexture = GetTrackingNoneTexture()
  local onEnter = GetTrackingWidgetCallback("TrackingWidget_OnEnter")
  local onLeave = GetTrackingWidgetCallback("TrackingWidget_OnLeave")
  local onClick = GetTrackingWidgetCallback("TrackingWidget_OnClick")

  state.sinkFrame = CreateFrame("Frame", "EnhanceTBC_MinimapSinkFrame", UIParent, "BackdropTemplate")
  state.sinkFrame:SetSize(C.minWidth, C.minHeight)
  state.sinkFrame:SetFrameStrata("LOW")
  state.sinkFrame:SetFrameLevel(1)
  state.sinkFrame:SetMovable(true)
  state.sinkFrame:EnableMouse(false)
  state.sinkFrame:SetClipsChildren(true)
  state.sinkFrame:SetClampedToScreen(true)

  if state.sinkFrame.SetBackdrop then
    state.sinkFrame:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
      tile = true,
      tileSize = 16,
      edgeSize = 12,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    state.sinkFrame:SetBackdropColor(0.03, 0.06, 0.03, 0.75)
    state.sinkFrame:SetBackdropBorderColor(0.2, 1.0, 0.2, 0.8)
  end

  state.sinkFrame.emptyText = state.sinkFrame:CreateFontString(nil, "OVERLAY")
  state.sinkFrame.emptyText:SetPoint("CENTER", state.sinkFrame, "CENTER", 0, 0)
  CallApplyFont(state.sinkFrame.emptyText, 9)
  state.sinkFrame.emptyText:SetText("No addon minimap buttons")
  state.sinkFrame.emptyText:Hide()

  state.sinkFrame.trackingButton = CreateFrame("Button", nil, state.sinkFrame)
  state.sinkFrame.trackingButton:SetHeight(C.trackingRowHeight)
  state.sinkFrame.trackingButton:SetPoint("TOPLEFT", state.sinkFrame, "TOPLEFT", C.padding, -3)
  state.sinkFrame.trackingButton:SetPoint("TOPRIGHT", state.sinkFrame, "TOPRIGHT", -C.padding, -3)
  state.sinkFrame.trackingButton:RegisterForClicks("LeftButtonUp")
  state.sinkFrame.trackingButton:SetScript("OnEnter", onEnter)
  state.sinkFrame.trackingButton:SetScript("OnLeave", onLeave)
  state.sinkFrame.trackingButton:SetScript("OnClick", onClick)
  state.sinkFrame.trackingButton.icon = state.sinkFrame.trackingButton:CreateTexture(nil, "OVERLAY")
  state.sinkFrame.trackingButton.icon:SetSize(12.5, 12.5)
  state.sinkFrame.trackingButton.icon:SetPoint("LEFT", 0, 0)
  state.sinkFrame.trackingButton.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
  state.sinkFrame.trackingButton.icon:SetTexture(trackingNoneTexture)
  state.sinkFrame.trackingButton.text = state.sinkFrame.trackingButton:CreateFontString(nil, "OVERLAY")
  state.sinkFrame.trackingButton.text:SetPoint("LEFT", state.sinkFrame.trackingButton.icon, "RIGHT", 4, 0)
  state.sinkFrame.trackingButton.text:SetPoint("RIGHT", state.sinkFrame.trackingButton, "RIGHT", -2, 0)
  state.sinkFrame.trackingButton.text:SetJustifyH("LEFT")
  state.sinkFrame.trackingButton.text:SetJustifyV("MIDDLE")
  CallApplyFont(state.sinkFrame.trackingButton.text, 8)
  state.sinkFrame.trackingButton:Hide()

  function state.sinkFrame:updateTrackingDisplay()
    local db = CallGetDB()
    if not db then return end

    local show = CallIsFeatureEnabled() and db.showTrackingState and db.sink_addons and db.sink_visible
    local changed = (self._trackingShown ~= show)
    self._trackingShown = show

    if self.trackingButton then
      self.trackingButton:SetShown(show)
      if show then
        local snapshot = CallGetTrackingSnapshot()
        self.trackingButton.icon:SetTexture(snapshot.texture or trackingNoneTexture)
        if self.trackingButton.icon.SetDesaturated then
          self.trackingButton.icon:SetDesaturated(snapshot.activeCount == 0)
        end
        self.trackingButton.icon:SetAlpha(snapshot.activeCount > 0 and 1 or 0.5)
        if snapshot.activeCount > 0 then
          if snapshot.activeCount == 1 then
            self.trackingButton.text:SetText(snapshot.names[1] or (TRACKING or "Tracking"))
          else
            self.trackingButton.text:SetText(tostring(snapshot.activeCount) .. " active")
          end
          self.trackingButton.text:SetTextColor(0.65, 1.0, 0.65)
        else
          self.trackingButton.text:SetText(NONE or "None")
          self.trackingButton.text:SetTextColor(0.75, 0.75, 0.75)
        end
      end
    end

    if changed then
      mod:LayoutSinkButtons()
    end
  end

  state.sinkDragHandle = CreateFrame("Button", "EnhanceTBC_MinimapSinkDragHandle", UIParent, "BackdropTemplate")
  state.sinkDragHandle:SetSize(14, 14)
  state.sinkDragHandle:SetPoint("BOTTOMRIGHT", state.sinkFrame, "BOTTOMRIGHT", 2, -2)
  state.sinkDragHandle:SetFrameStrata("DIALOG")
  state.sinkDragHandle:SetFrameLevel(500)
  state.sinkDragHandle:EnableMouse(true)
  state.sinkDragHandle:RegisterForDrag("LeftButton")
  if state.sinkDragHandle.SetBackdrop then
    state.sinkDragHandle:SetBackdrop({
      bgFile = "Interface/Buttons/WHITE8x8",
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
      tile = true,
      tileSize = 8,
      edgeSize = 10,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    state.sinkDragHandle:SetBackdropColor(0.10, 0.20, 0.10, 0.90)
    state.sinkDragHandle:SetBackdropBorderColor(0.20, 1.00, 0.20, 0.95)
  end
  state.sinkDragHandle:SetScript("OnDragStart", function()
    state.sinkFrame:StartMoving()
  end)
  state.sinkDragHandle:SetScript("OnDragStop", function()
    state.sinkFrame:StopMovingOrSizing()
    local db = CallGetDB()
    if not db then return end

    local cx, cy = state.sinkFrame:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if cx and cy and ux and uy then
      db.sink_anchor.point = "CENTER"
      db.sink_anchor.relPoint = "CENTER"
      db.sink_anchor.x = math.floor((cx - ux) + 0.5)
      db.sink_anchor.y = math.floor((cy - uy) + 0.5)
      db.sink_moved = true
      db.sinkPoint = db.sink_anchor.point
      db.sinkRelPoint = db.sink_anchor.relPoint
      db.sinkX = db.sink_anchor.x
      db.sinkY = db.sink_anchor.y
      CallApplySinkAnchor()
    end
  end)

  CallApplySinkAnchor()
end

H.EnsureSinkFrame = EnsureSinkFrame

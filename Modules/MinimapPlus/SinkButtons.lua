-- Modules/MinimapPlus_SinkButtons.lua
-- EnhanceTBC - MinimapPlus sink button management helpers (internal).

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}

local mod = ETBC.Modules.MinimapPlus
if not mod then return end

mod.Internal = mod.Internal or {}
local H = {}
mod.Internal.SinkButtons = H

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

local function CallAfterDelay(delay, fn)
  local shared = GetShared()
  if shared and type(shared.AfterDelay) == "function" then
    return shared.AfterDelay(delay, fn)
  end
  fn()
  return true
end

local function GetLDBIcon()
  local shared = GetShared()
  return shared and shared.LDBIcon
end

local function GetSinkConstants()
  local shared = GetShared() or {}
  return {
    iconSize = tonumber(shared.SINK_ICON_SIZE) or 18,
    iconSpacing = tonumber(shared.SINK_ICON_SPACING) or 4,
    padding = tonumber(shared.SINK_PADDING) or 6,
    minWidth = tonumber(shared.SINK_MIN_WIDTH) or 104,
    minHeight = tonumber(shared.SINK_MIN_HEIGHT) or 32,
    trackingRowHeight = tonumber(shared.SINK_TRACKING_ROW_HEIGHT) or 16,
  }
end

local function IsBlacklisted(_self, btn, name)
  local state = GetState()
  if not (btn and state) then return true end

  if type(name) == "string" and (
    name:find("^EnhanceTBC_")
    or name:find("^LibDBIcon10_EnhanceTBC")
  ) then
    return true
  end

  local ldbIcon = GetLDBIcon()
  if ldbIcon and ldbIcon.GetMinimapButton then
    local etbcBtn = ldbIcon:GetMinimapButton("EnhanceTBC")
    if btn == etbcBtn then return true end
  end

  if btn == Minimap
    or btn == MinimapCluster
    or btn == state.iconsFrame
    or btn == state.performanceFrame
  then
    return true
  end
  if btn == state.sinkFrame then return true end
  if btn == MinimapZoneTextButton or btn == MinimapToggleButton then return true end
  if btn == MinimapZoomIn or btn == MinimapZoomOut then return true end
  if btn == MiniMapTracking or btn == MiniMapMailFrame or btn == MiniMapBattlefieldFrame then return true end
  if btn == MiniMapVoiceChatFrame or btn == MiniMapWorldMapButton or btn == LFGMinimapFrame then return true end

  local db = CallGetDB()
  if not db then return false end

  if not db.includeCalendar then
    if btn == GameTimeFrame or btn == TimeManagerClockButton then return true end
  end
  if not db.includeQueue then
    if btn == QueueStatusMinimapButton then return true end
  end
  if not db.includeTracking then
    if btn == MiniMapTracking then return true end
  end
  if not db.includeMail then
    if btn == MiniMapMailFrame then return true end
  end
  if not db.includeDifficulty then
    if btn == MiniMapInstanceDifficulty then return true end
  end
  return false
end

local function LooksLikeMinimapButton(self, btn)
  if not btn then return false end
  local name = btn.GetName and btn:GetName() or nil
  if self:IsBlacklisted(btn, name) then return false end
  if btn.IsShown and not btn:IsShown() then return false end
  if btn.IsProtected and btn:IsProtected() and InCombatLockdown and InCombatLockdown() then
    return false
  end
  local objectType = btn.GetObjectType and btn:GetObjectType() or nil
  if objectType ~= "Button" and objectType ~= "CheckButton" then return false end
  if type(name) == "string" and name:find("^LibDBIcon10_") then return true end
  return false
end

local function CaptureSinkButton(_self, btn)
  local state = GetState()
  local C = GetSinkConstants()
  if not state then return end

  if type(btn) == "table" and not btn.GetObjectType and btn.button then
    btn = btn.button
  end
  if not btn or state.sinkManaged[btn] then return end
  if InCombatLockdown and InCombatLockdown() then return end
  if type(btn.ClearAllPoints) ~= "function" then return end
  if type(btn.SetPoint) ~= "function" then return end

  local info = {
    parent = btn.GetParent and btn:GetParent() or UIParent,
    width = btn.GetWidth and btn:GetWidth() or nil,
    height = btn.GetHeight and btn:GetHeight() or nil,
    scale = btn.GetScale and btn:GetScale() or nil,
    points = {},
    strata = btn.GetFrameStrata and btn:GetFrameStrata() or nil,
    level = btn.GetFrameLevel and btn:GetFrameLevel() or nil,
  }

  if btn.GetNumPoints and btn.GetPoint then
    local n = btn:GetNumPoints() or 0
    for i = 1, n do
      local p, rel, rp, x, y = btn:GetPoint(i)
      info.points[#info.points + 1] = { p, rel, rp, x, y }
    end
  end

  state.sinkManaged[btn] = info
  btn:ClearAllPoints()
  if btn.SetParent and state.sinkFrame then
    btn:SetParent(state.sinkFrame)
    local scheduled = CallAfterDelay(0.2, function()
      if btn.SetParent and state.sinkFrame then
        btn:SetParent(state.sinkFrame)
        -- Only keep if parent is correct
        local repar = (btn.GetParent and btn:GetParent()) or nil
        if repar ~= state.sinkFrame then
          state.sinkManaged[btn] = nil
        end
      end
    end)
    if not scheduled then
      -- Fallback: check immediately
      local repar = (btn.GetParent and btn:GetParent()) or nil
      if repar ~= state.sinkFrame then
        state.sinkManaged[btn] = nil
      end
    end
  end
  if btn.SetFrameStrata then btn:SetFrameStrata("MEDIUM") end

  local baseW = tonumber(info.width) or 20
  local baseH = tonumber(info.height) or 20
  local base = math.max(baseW, baseH, 1)
  local targetScale = C.iconSize / base
  if targetScale > 1 then targetScale = 1 end
  if targetScale < 0.55 then targetScale = 0.55 end
  if btn.SetScale then btn:SetScale(targetScale) end
  if btn.SetSize then btn:SetSize(baseW, baseH) end
  if btn.SetHitRectInsets then btn:SetHitRectInsets(0, 0, 0, 0) end
end

local function RestoreSinkButtons()
  local state = GetState()
  if not state then return end
  if InCombatLockdown and InCombatLockdown() then return end

  for btn, info in pairs(state.sinkManaged) do
    if btn and info then
      if btn.SetParent and info.parent then btn:SetParent(info.parent) end
      btn:ClearAllPoints()
      if info.points and #info.points > 0 and btn.SetPoint then
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

local function LayoutSinkButtons()
  local state = GetState()
  if not (state and state.sinkFrame) then return end

  local C = GetSinkConstants()
  local buttons = {}
  for btn in pairs(state.sinkManaged) do
    if btn and type(btn.ClearAllPoints) == "function" and type(btn.SetPoint) == "function" then
      -- Only show if parent is still sinkFrame
      if btn.GetParent and btn:GetParent() == state.sinkFrame then
        buttons[#buttons + 1] = btn
      else
        state.sinkManaged[btn] = nil
      end
    else
      state.sinkManaged[btn] = nil
    end
  end

  table.sort(buttons, function(a, b)
    local na = (a and a.GetName and a:GetName()) or ""
    local nb = (b and b.GetName and b:GetName()) or ""
    return na < nb
  end)

  local count = #buttons
  local btnSize = C.iconSize + 6
  local spacing = C.iconSpacing
  local pad = C.padding
  local trackingRowHeight = 0
  if state.sinkFrame.trackingButton
    and state.sinkFrame.trackingButton.IsShown
    and state.sinkFrame.trackingButton:IsShown()
  then
    trackingRowHeight = C.trackingRowHeight
  end
  local cols = 1
  if count > 1 then
    cols = math.min(count, math.max(4, math.ceil(math.sqrt(count))))
  end
  if cols < 1 then cols = 1 end

  local rows = math.max(1, math.ceil(count / cols))
  local contentWidth = (cols * btnSize) + ((cols - 1) * spacing)
  local contentHeight = (rows * btnSize) + ((rows - 1) * spacing)
  local width = (pad * 2) + contentWidth
  local height = (pad * 2) + contentHeight + trackingRowHeight

  if count == 0 then
    width = 140
    height = C.minHeight + trackingRowHeight
  end

  if width < C.minWidth then width = C.minWidth end
  if height < (C.minHeight + trackingRowHeight) then
    height = C.minHeight + trackingRowHeight
  end

  state.sinkFrame:SetSize(width, height)

  local availableHeight = height - trackingRowHeight
  local startY = trackingRowHeight + math.floor((availableHeight - contentHeight) / 2 + 0.5)
  for i = 1, count do
    local btn = buttons[i]
    local row = math.floor((i - 1) / cols)
    local indexInRow = (i - 1) % cols
    local rowCount = math.min(cols, count - (row * cols))
    local rowWidth = (rowCount * btnSize) + ((rowCount - 1) * spacing)
    local startX = math.floor((width - rowWidth) / 2 + 0.5)
    local x = startX + (indexInRow * (btnSize + spacing))
    local y = -startY - (row * (btnSize + spacing))
    if btn and btn.ClearAllPoints and btn.SetPoint then
      btn:ClearAllPoints()
      btn:SetPoint("TOPLEFT", state.sinkFrame, "TOPLEFT", x, y)
    end
  end

  if state.sinkFrame.emptyText then
    state.sinkFrame.emptyText:SetShown(count == 0)
    if count == 0 and not state.sinkEmptyNotified and DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage(
        "|cff33ff99EnhanceTBC|r No minimap buttons could be moved to the sink. "
          .. "Some buttons are protected by Blizzard or other addons and cannot be moved."
      )
      state.sinkEmptyNotified = true
    elseif count > 0 then
      state.sinkEmptyNotified = false
    end
  end
end

H.IsBlacklisted = IsBlacklisted
H.LooksLikeMinimapButton = LooksLikeMinimapButton
H.CaptureSinkButton = CaptureSinkButton
H.RestoreSinkButtons = RestoreSinkButtons
H.LayoutSinkButtons = LayoutSinkButtons

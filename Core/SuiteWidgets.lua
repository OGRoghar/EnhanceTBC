local _, ETBC = ...

ETBC.SuiteWidgets = ETBC.SuiteWidgets or {}
local W = ETBC.SuiteWidgets

local BACKDROP = {
  bgFile = "Interface\\Buttons\\WHITE8x8",
  edgeFile = "Interface\\Buttons\\WHITE8x8",
  edgeSize = 1,
}

function W:ApplyPanel(frame, accent)
  if not frame then return frame end
  if frame.SetBackdrop then
    frame:SetBackdrop(BACKDROP)
    frame:SetBackdropColor(0.025, 0.035, 0.03, 0.94)
    local c = accent or { 0.22, 0.72, 0.32 }
    frame:SetBackdropBorderColor(c[1] or 0.22, c[2] or 0.72, c[3] or 0.32, c[4] or 0.9)
  end
  return frame
end

function W:CreatePanel(name, parent, width, height)
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  local frame = CreateFrame("Frame", name, parent or UIParent, template)
  frame:SetSize(width or 300, height or 200)
  self:ApplyPanel(frame)
  return frame
end

function W:CreateBar(parent, width, height, color)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetSize(width or 200, height or 18)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  local c = color or { 0.20, 0.75, 0.30 }
  bar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
  local bg = bar:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(bar)
  bg:SetTexture("Interface\\Buttons\\WHITE8x8")
  bg:SetVertexColor(0.06, 0.07, 0.065, 0.95)
  bar.background = bg
  return bar
end

function W:SetShown(frame, shown)
  if not frame then return end
  if frame.SetShown then frame:SetShown(shown and true or false)
  elseif shown then frame:Show() else frame:Hide() end
end

-- UI/Widgets/SectionCard.lua
-- EnhanceTBC custom AceGUI container: ETBC_SectionCard

local _, ETBC = ...
local AceGUI = LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion("ETBC_SectionCard") or 0) >= 1 then return end

local Type = "ETBC_SectionCard"
local Version = 1

local function GetTheme()
  local skin = ETBC and ETBC.UI and ETBC.UI.ConfigWindow
  if skin and skin.GetTheme then
    local ok, theme = pcall(skin.GetTheme, skin)
    if ok and type(theme) == "table" then
      return theme
    end
  end
  return {
    panel2 = { 0.06, 0.08, 0.06, 0.95 },
    border = { 0.12, 0.20, 0.12, 0.95 },
    text = { 0.90, 0.96, 0.90, 1.00 },
    muted = { 0.70, 0.78, 0.70, 1.00 },
  }
end

local function SetBackdrop(frame, bg, edge)
  if not frame or type(frame.SetBackdrop) ~= "function" then return end
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = false,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
  frame:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4] or 1)
end

local methods = {}

local function UpdateAnchors(self)
  local rightAnchor = self.frame
  local rightPoint = "TOPRIGHT"
  local rightX = -10
  local rightY = -8
  if self.togglebutton and self.togglebutton:IsShown() then
    rightAnchor = self.togglebutton
    rightPoint = "TOPLEFT"
    rightX = -6
    rightY = 0
  end

  self.titletext:ClearAllPoints()
  self.titletext:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -8)
  self.titletext:SetPoint("TOPRIGHT", rightAnchor, rightPoint, rightX, rightY)

  self.descriptiontext:ClearAllPoints()
  self.descriptiontext:SetPoint("TOPLEFT", self.titletext, "BOTTOMLEFT", 0, -4)
  self.descriptiontext:SetPoint("TOPRIGHT", rightAnchor, rightPoint, rightX, rightY)

  local content = self.content
  content:ClearAllPoints()
  if self.descriptiontext:IsShown() then
    content:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -46)
  else
    content:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -30)
  end
  content:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -10, 10)
end

local function HeaderPad(self)
  return self.descriptiontext:IsShown() and 56 or 40
end

local function ApplyAutoHeight(self, layoutHeight)
  if self.noAutoHeight then return end
  local pad = HeaderPad(self)
  if self.collapsible and self.collapsed then
    self:SetHeight(pad)
    return
  end
  self:SetHeight((layoutHeight or self._layoutHeight or 0) + pad)
end

local function ApplyTheme(self)
  local theme = GetTheme()
  SetBackdrop(self.frame, theme.panel2, theme.border)

  if self.titletext then
    self.titletext:SetTextColor(theme.text[1], theme.text[2], theme.text[3], theme.text[4] or 1)
  end
  if self.descriptiontext then
    self.descriptiontext:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3], theme.muted[4] or 1)
  end

  if self.togglebutton and self.togglebutton.SetBackdrop then
    SetBackdrop(self.togglebutton, theme.panel2, theme.border)
  end
  if self.toggletext and self.toggletext.SetTextColor then
    self.toggletext:SetTextColor(theme.text[1], theme.text[2], theme.text[3], theme.text[4] or 1)
  end
end

local function UpdateCollapsedVisual(self)
  if self.togglebutton then
    self.togglebutton:SetShown(self.collapsible and true or false)
  end
  if self.toggletext then
    self.toggletext:SetText((self.collapsible and self.collapsed) and "+" or "-")
  end
  if self.content then
    self.content:SetShown(not (self.collapsible and self.collapsed))
  end
  UpdateAnchors(self)
  ApplyAutoHeight(self)
end

function methods:OnAcquire()
  self:SetWidth(300)
  self._layoutHeight = 0
  self.collapsible = false
  self.collapsed = false
  self._onToggle = nil
  self:SetHeight(120)
  self:SetTitle("")
  self:SetDescription("")
  ApplyTheme(self)
  if self.togglebutton then
    self.togglebutton:Hide()
  end
  if self.content then
    self.content:Show()
  end
  UpdateAnchors(self)
end

function methods:SetTitle(text)
  self.titletext:SetText(text or "")
end

function methods:SetDescription(text)
  text = text or ""
  self.descriptiontext:SetText(text)
  self.descriptiontext:SetShown(text ~= "")
  UpdateAnchors(self)
  ApplyAutoHeight(self)
end

function methods:SetCollapsible(enabled)
  self.collapsible = enabled and true or false
  if not self.collapsible then
    self.collapsed = false
  end
  UpdateCollapsedVisual(self)
end

function methods:SetCollapsed(collapsed)
  collapsed = collapsed and true or false
  if not self.collapsible then
    collapsed = false
  end
  if self.collapsed == collapsed then
    UpdateCollapsedVisual(self)
    return
  end
  self.collapsed = collapsed
  UpdateCollapsedVisual(self)
end

function methods:GetCollapsed()
  return self.collapsed and true or false
end

function methods:SetOnToggle(fn)
  if type(fn) == "function" then
    self._onToggle = fn
  else
    self._onToggle = nil
  end
end

function methods:LayoutFinished(_, height)
  self._layoutHeight = height or 0
  ApplyAutoHeight(self, height)
end

function methods:OnWidthSet(width)
  local content = self.content
  local contentWidth = width - 20
  if contentWidth < 0 then contentWidth = 0 end
  content:SetWidth(contentWidth)
  content.width = contentWidth
end

function methods:OnHeightSet(height)
  local content = self.content
  local contentHeight = 0
  if not (self.collapsible and self.collapsed) then
    contentHeight = height - HeaderPad(self)
  end
  if contentHeight < 0 then contentHeight = 0 end
  content:SetHeight(contentHeight)
  content.height = contentHeight
end

local function Constructor()
  local frame = CreateFrame("Frame", nil, UIParent)
  frame:SetFrameStrata("FULLSCREEN_DIALOG")

  local theme = GetTheme()
  SetBackdrop(frame, theme.panel2, theme.border)

  local titletext = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  titletext:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -8)
  titletext:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -8)
  titletext:SetJustifyH("LEFT")
  titletext:SetTextColor(theme.text[1], theme.text[2], theme.text[3], theme.text[4] or 1)

  local descriptiontext = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  descriptiontext:SetPoint("TOPLEFT", titletext, "BOTTOMLEFT", 0, -4)
  descriptiontext:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, 0)
  descriptiontext:SetJustifyH("LEFT")
  descriptiontext:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3], theme.muted[4] or 1)
  descriptiontext:Hide()

  local togglebutton = CreateFrame(
    "Button",
    nil,
    frame,
    BackdropTemplateMixin and "BackdropTemplate" or nil
  )
  togglebutton:SetSize(18, 18)
  togglebutton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
  SetBackdrop(togglebutton, theme.panel2, theme.border)
  togglebutton:Hide()

  local toggletext = togglebutton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  toggletext:SetPoint("CENTER", togglebutton, "CENTER", 0, 0)
  toggletext:SetTextColor(theme.text[1], theme.text[2], theme.text[3], theme.text[4] or 1)
  toggletext:SetText("-")

  local content = CreateFrame("Frame", nil, frame)
  content:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
  content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)

  local widget = {
    type = Type,
    frame = frame,
    content = content,
    titletext = titletext,
    descriptiontext = descriptiontext,
    togglebutton = togglebutton,
    toggletext = toggletext,
  }

  togglebutton:SetScript("OnClick", function()
    if not widget.collapsible then return end
    widget:SetCollapsed(not widget:GetCollapsed())
    if type(widget._onToggle) == "function" then
      pcall(widget._onToggle, widget, widget:GetCollapsed())
    end
  end)

  for method, func in pairs(methods) do
    widget[method] = func
  end

  return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)

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
  local content = self.content
  content:ClearAllPoints()
  if self.descriptiontext:IsShown() then
    content:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -46)
  else
    content:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -30)
  end
  content:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -10, 10)
end

function methods:OnAcquire()
  self:SetWidth(300)
  self:SetHeight(120)
  self:SetTitle("")
  self:SetDescription("")
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
end

function methods:LayoutFinished(_, height)
  if self.noAutoHeight then return end
  local pad = self.descriptiontext:IsShown() and 56 or 40
  self:SetHeight((height or 0) + pad)
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
  local contentHeight = height - (self.descriptiontext:IsShown() and 56 or 40)
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

  local content = CreateFrame("Frame", nil, frame)
  content:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
  content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)

  local widget = {
    type = Type,
    frame = frame,
    content = content,
    titletext = titletext,
    descriptiontext = descriptiontext,
  }

  for method, func in pairs(methods) do
    widget[method] = func
  end

  return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)

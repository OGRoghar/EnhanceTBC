-- Core/AceGUISkin.lua
-- EnhanceTBC - global AceGUI skin for test build

local _, ETBC = ...
ETBC.Core = ETBC.Core or {}
ETBC.Core.AceGUISkin = ETBC.Core.AceGUISkin or {}
local Skin = ETBC.Core.AceGUISkin

local AceGUI = LibStub("AceGUI-3.0", true)
if not AceGUI then return end

local THEME = {
  bg = { 0.04, 0.06, 0.04, 0.95 },
  panel = { 0.06, 0.08, 0.06, 0.95 },
  border = { 0.12, 0.22, 0.12, 0.95 },
  accent = { 0.20, 1.00, 0.20, 1.00 },
  text = { 0.90, 0.96, 0.90, 1.00 },
  muted = { 0.70, 0.78, 0.70, 1.00 },
}

local function SetBackdrop(frame, bg, edge, edgeSize)
  if not frame or type(frame.SetBackdrop) ~= "function" then return end
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = false,
    edgeSize = edgeSize or 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
  frame:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4] or 1)
end

local function SetTextColor(fs, col)
  if fs and fs.SetTextColor and col then
    fs:SetTextColor(col[1], col[2], col[3], col[4] or 1)
  end
end

local function GetFontPath()
  if ETBC and ETBC.Theme and type(ETBC.Theme.FetchFont) == "function" then
    local ok, fontPath = pcall(ETBC.Theme.FetchFont, ETBC.Theme, nil)
    if ok and type(fontPath) == "string" and fontPath ~= "" then
      return fontPath
    end
  end
  return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local function TrySetFont(fs, size, flags)
  if fs and fs.SetFont then
    pcall(fs.SetFont, fs, GetFontPath(), size or 12, flags)
  end
end

local function SkinFrame(widget)
  local frame = widget and widget.frame
  if not frame then return end
  SetBackdrop(frame, THEME.bg, THEME.border, 1)
  if frame.titletext then
    SetTextColor(frame.titletext, THEME.text)
    TrySetFont(frame.titletext, 13, "OUTLINE")
  end
  if frame.statustext then
    SetTextColor(frame.statustext, THEME.muted)
    TrySetFont(frame.statustext, 11, nil)
  end
end

local function SkinInlineGroup(widget)
  local frame = widget and widget.frame
  if not frame then return end
  SetBackdrop(frame, THEME.panel, THEME.border, 1)
  if widget.titletext then
    SetTextColor(widget.titletext, THEME.text)
    TrySetFont(widget.titletext, 12, "OUTLINE")
  end
end

local function SkinScrollFrame(widget)
  local frame = widget and widget.frame
  if not frame then return end
  SetBackdrop(frame, THEME.panel, THEME.border, 1)
end

local function SkinCheckBox(widget)
  if widget and widget.text then
    SetTextColor(widget.text, THEME.text)
    TrySetFont(widget.text, 12, nil)
  end
  if widget and widget.label then
    SetTextColor(widget.label, THEME.muted)
    TrySetFont(widget.label, 11, nil)
  end
end

local function SkinLabel(widget)
  if widget and widget.label then
    SetTextColor(widget.label, THEME.text)
    TrySetFont(widget.label, 12, nil)
  end
end

local function SkinHeading(widget)
  if widget and widget.text then
    SetTextColor(widget.text, THEME.text)
    TrySetFont(widget.text, 13, "OUTLINE")
  end
  if widget and widget.line and widget.line.SetColorTexture then
    widget.line:SetColorTexture(THEME.border[1], THEME.border[2], THEME.border[3], 0.7)
  end
end

local function SkinButton(widget)
  local frame = widget and widget.frame
  if not frame then return end
  SetBackdrop(frame, THEME.panel, THEME.border, 1)
  if widget.text then
    SetTextColor(widget.text, THEME.text)
    TrySetFont(widget.text, 12, "OUTLINE")
  end
  if not frame._etbcHoverHooked and frame.HookScript then
    frame._etbcHoverHooked = true
    frame:HookScript("OnEnter", function(self)
      SetBackdrop(self, THEME.panel, THEME.accent, 1)
    end)
    frame:HookScript("OnLeave", function(self)
      SetBackdrop(self, THEME.panel, THEME.border, 1)
    end)
  end
end

local function SkinSlider(widget)
  if widget and widget.label then
    SetTextColor(widget.label, THEME.text)
    TrySetFont(widget.label, 12, nil)
  end
  if widget and widget.lowtext then SetTextColor(widget.lowtext, THEME.muted) end
  if widget and widget.hightext then SetTextColor(widget.hightext, THEME.muted) end
  if widget and widget.editbox then
    SetBackdrop(widget.editbox, THEME.bg, THEME.border, 1)
    if widget.editbox.SetTextColor then
      widget.editbox:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], THEME.text[4])
    end
    TrySetFont(widget.editbox, 12, nil)
  end
end

local function SkinDropdown(widget)
  if widget and widget.label then
    SetTextColor(widget.label, THEME.text)
    TrySetFont(widget.label, 12, nil)
  end
  if widget and widget.frame then
    SetBackdrop(widget.frame, THEME.panel, THEME.border, 1)
  end
end

local function SkinEditBox(widget)
  if widget and widget.label then
    SetTextColor(widget.label, THEME.text)
    TrySetFont(widget.label, 12, nil)
  end
  if widget and widget.editbox then
    SetBackdrop(widget.editbox, THEME.bg, THEME.border, 1)
    if widget.editbox.SetTextColor then
      widget.editbox:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], THEME.text[4])
    end
    TrySetFont(widget.editbox, 12, nil)
  end
end

local function SkinColorPicker(widget)
  if widget and widget.label then
    SetTextColor(widget.label, THEME.text)
    TrySetFont(widget.label, 12, nil)
  end
end

local SKINNERS = {
  Frame = SkinFrame,
  InlineGroup = SkinInlineGroup,
  ScrollFrame = SkinScrollFrame,
  CheckBox = SkinCheckBox,
  Label = SkinLabel,
  Heading = SkinHeading,
  Button = SkinButton,
  Slider = SkinSlider,
  Dropdown = SkinDropdown,
  EditBox = SkinEditBox,
  MultiLineEditBox = SkinEditBox,
  ColorPicker = SkinColorPicker,
}

local function HookWidgetType(typeName)
  local ctor = AceGUI.WidgetRegistry and AceGUI.WidgetRegistry[typeName]
  if not ctor or ctor.__etbcSkinCtorHooked then return end

  ctor.__etbcSkinCtorHooked = true
  AceGUI.WidgetRegistry[typeName] = function(...)
    local widget = ctor(...)
    local skinner = SKINNERS[typeName]
    if skinner and widget then
      if widget.OnAcquire and not widget.__etbcSkinAcquireHooked then
        local orig = widget.OnAcquire
        widget.__etbcSkinAcquireHooked = true
        widget.OnAcquire = function(self, ...)
          orig(self, ...)
          skinner(self)
        end
      else
        skinner(widget)
      end
    end
    return widget
  end
end

function Skin:Install()
  if self._installed then return end
  self._installed = true

  if not self._registerHooked and AceGUI.RegisterWidgetType then
    local origRegister = AceGUI.RegisterWidgetType
    AceGUI.RegisterWidgetType = function(gui, name, constructor, version)
      local out = origRegister(gui, name, constructor, version)
      if SKINNERS[name] then
        HookWidgetType(name)
      end
      return out
    end
    self._registerHooked = true
  end

  for typeName in pairs(SKINNERS) do
    HookWidgetType(typeName)
  end
end

function Skin.GetTheme()
  return THEME
end

Skin:Install()

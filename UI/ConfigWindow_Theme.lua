-- UI/ConfigWindow_Theme.lua
-- Internal theme/style helpers for EnhanceTBC config window.

local _, ETBC = ...
ETBC.UI = ETBC.UI or {}
local UI = ETBC.UI

UI.ConfigWindow = UI.ConfigWindow or {}
local ConfigWindow = UI.ConfigWindow

ConfigWindow.Internal = ConfigWindow.Internal or {}
ConfigWindow.Internal.Theme = ConfigWindow.Internal.Theme or {}
local H = ConfigWindow.Internal.Theme

if H._loaded then return end
H._loaded = true

local AceGUI = LibStub("AceGUI-3.0")

H.LOGO_PATH = "Interface\\AddOns\\EnhanceTBC\\Media\\Images\\logo.tga"

H.THEME = {
  bg      = { 0.05, 0.07, 0.05, 0.98 },
  panel   = { 0.07, 0.09, 0.07, 0.95 },
  panel2  = { 0.06, 0.08, 0.06, 0.95 },
  panel3  = { 0.04, 0.06, 0.04, 0.96 },
  border  = { 0.12, 0.20, 0.12, 0.95 },
  accent  = { 0.20, 1.00, 0.20, 1.00 },
  text    = { 0.90, 0.96, 0.90, 1.00 },
  muted   = { 0.70, 0.78, 0.70, 1.00 },
}

H.DEFAULT_THEME_KEY = "EnhanceGreen"

H.CONFIG_THEMES = {
  EnhanceGreen = {
    bg      = { 0.05, 0.07, 0.05, 0.98 },
    panel   = { 0.07, 0.09, 0.07, 0.95 },
    panel2  = { 0.06, 0.08, 0.06, 0.95 },
    panel3  = { 0.04, 0.06, 0.04, 0.96 },
    border  = { 0.12, 0.20, 0.12, 0.95 },
    accent  = { 0.20, 1.00, 0.20, 1.00 },
    text    = { 0.90, 0.96, 0.90, 1.00 },
    muted   = { 0.70, 0.78, 0.70, 1.00 },
  },
  WoWBasic = {
    bg      = { 0.09, 0.07, 0.05, 0.98 },
    panel   = { 0.15, 0.11, 0.07, 0.95 },
    panel2  = { 0.13, 0.10, 0.06, 0.95 },
    panel3  = { 0.11, 0.08, 0.05, 0.96 },
    border  = { 0.56, 0.42, 0.22, 0.98 },
    accent  = { 0.92, 0.76, 0.34, 1.00 },
    text    = { 0.96, 0.92, 0.82, 1.00 },
    muted   = { 0.80, 0.72, 0.58, 1.00 },
  },
}

local CONFIG_THEME_CHOICES = {
  EnhanceGreen = "Enhance Green",
  WoWBasic = "WoW Basic",
}

local function CopyColorInto(dst, src)
  if type(src) ~= "table" then
    return dst
  end
  dst = type(dst) == "table" and dst or {}
  dst[1] = tonumber(src[1]) or 0
  dst[2] = tonumber(src[2]) or 0
  dst[3] = tonumber(src[3]) or 0
  dst[4] = tonumber(src[4]) or 1
  return dst
end

function H.GetConfigThemeChoices()
  return CONFIG_THEME_CHOICES
end

function H.NormalizeConfigThemeKey(key)
  key = tostring(key or "")
  if H.CONFIG_THEMES[key] then
    return key
  end
  return H.DEFAULT_THEME_KEY
end

function H.ApplyConfigTheme(key)
  local themeKey = H.NormalizeConfigThemeKey(key)
  local source = H.CONFIG_THEMES[themeKey] or H.CONFIG_THEMES[H.DEFAULT_THEME_KEY]
  if type(source) ~= "table" then
    return H.DEFAULT_THEME_KEY
  end

  for name, color in pairs(source) do
    H.THEME[name] = CopyColorInto(H.THEME[name], color)
  end

  H._activeConfigThemeKey = themeKey
  return themeKey
end

function H.GetActiveConfigThemeKey()
  return H._activeConfigThemeKey or H.DEFAULT_THEME_KEY
end

H.ApplyConfigTheme(H.DEFAULT_THEME_KEY)

function H.SetBackdrop(frame, bg, edge, edgeSize)
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

function H.SetTextColor(fs, col)
  if fs and fs.SetTextColor and col then
    fs:SetTextColor(col[1], col[2], col[3], col[4] or 1)
  end
end

function H.GetUIFont()
  if ETBC and ETBC.Theme and type(ETBC.Theme.FetchFont) == "function" then
    local ok, fontPath = pcall(ETBC.Theme.FetchFont, ETBC.Theme, nil)
    if ok and type(fontPath) == "string" and fontPath ~= "" then
      return fontPath
    end
  end
  return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

function H.TrySetFont(fs, size, flags)
  if fs and fs.SetFont then
    pcall(fs.SetFont, fs, H.GetUIFont(), size or 12, flags)
  end
end

function H.StyleHeadingWidget(w)
  if not w then return end
  local THEME = H.THEME
  if w.text then
    H.SetTextColor(w.text, THEME.text)
    H.TrySetFont(w.text, 13, "OUTLINE")
  end
  if w.line and w.line.SetColorTexture then
    w.line:SetColorTexture(THEME.border[1], THEME.border[2], THEME.border[3], 0.7)
  end
end

function H.StyleLabelWidget(w, muted)
  if not w then return end
  local THEME = H.THEME
  if w.label then
    H.SetTextColor(w.label, muted and THEME.muted or THEME.text)
    H.TrySetFont(w.label, muted and 11 or 12, nil)
  end
end

function H.StyleCheckBoxWidget(w)
  if not w then return end
  local THEME = H.THEME
  if w.text then
    H.SetTextColor(w.text, THEME.text)
    H.TrySetFont(w.text, 12, nil)
  end
  if w.label then
    H.SetTextColor(w.label, THEME.muted)
    H.TrySetFont(w.label, 11, nil)
  end
  if w.check then
    w.check:SetVertexColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 1)
  end
  if w.checkbg then
    local r = (THEME.panel2[1] * 0.70) + (THEME.text[1] * 0.25)
    local g = (THEME.panel2[2] * 0.70) + (THEME.text[2] * 0.25)
    local b = (THEME.panel2[3] * 0.70) + (THEME.text[3] * 0.25)
    w.checkbg:SetVertexColor(r, g, b, 1)
  end
  if w.highlight then
    w.highlight:SetVertexColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.65)
  end
end

function H.StyleButtonWidget(w)
  if not w or not w.frame then return end
  local THEME = H.THEME
  H.SetBackdrop(w.frame, THEME.panel2, THEME.border, 1)

  if w.text then
    H.SetTextColor(w.text, THEME.text)
    H.TrySetFont(w.text, 12, "OUTLINE")
  end

  if not w.frame._etbcHoverHooked and w.frame.HookScript then
    w.frame._etbcHoverHooked = true
    w.frame:HookScript("OnEnter", function(self)
      H.SetBackdrop(self, THEME.panel2, THEME.accent, 1)
    end)
    w.frame:HookScript("OnLeave", function(self)
      H.SetBackdrop(self, THEME.panel2, THEME.border, 1)
    end)
  end
end

function H.StyleSliderWidget(w)
  if not w then return end
  local THEME = H.THEME
  if w.label then
    H.SetTextColor(w.label, THEME.text)
    H.TrySetFont(w.label, 12, nil)
  end
  if w.lowtext then H.SetTextColor(w.lowtext, THEME.muted) end
  if w.hightext then H.SetTextColor(w.hightext, THEME.muted) end

  if w.editbox and w.editbox.SetTextColor then
    w.editbox:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], THEME.text[4])
    H.TrySetFont(w.editbox, 12, nil)
    H.SetBackdrop(w.editbox, THEME.bg, THEME.border, 1)
  end

  if w.slider then
    if w.slider.SetBackdropColor then
      w.slider:SetBackdropColor(THEME.panel2[1], THEME.panel2[2], THEME.panel2[3], 0.95)
    end
    if w.slider.SetBackdropBorderColor then
      w.slider:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 0.95)
    end

    local thumb = w.slider.GetThumbTexture and w.slider:GetThumbTexture() or nil
    if thumb and thumb.SetVertexColor then
      thumb:SetVertexColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 1)
    end
  end
end

function H.StyleDropdownWidget(w)
  if not w then return end
  local THEME = H.THEME
  if w.label then
    H.SetTextColor(w.label, THEME.text)
    H.TrySetFont(w.label, 12, nil)
  end
  if w.frame then
    H.SetBackdrop(w.frame, THEME.panel2, THEME.border, 1)
  end
end

function H.StyleEditBoxWidget(w)
  if not w then return end
  local THEME = H.THEME
  if w.label then
    H.SetTextColor(w.label, THEME.text)
    H.TrySetFont(w.label, 12, nil)
  end
  if w.editbox then
    H.SetBackdrop(w.editbox, THEME.bg, THEME.border, 1)
    if w.editbox.SetTextColor then
      w.editbox:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], THEME.text[4])
    end
    H.TrySetFont(w.editbox, 12, nil)
  end
end

function H.StyleColorWidget(w)
  if not w then return end
  if w.label then
    H.SetTextColor(w.label, H.THEME.text)
    H.TrySetFont(w.label, 12, nil)
  end
end

function H.StyleInlineGroup(w)
  if not w or not w.frame then return end
  local THEME = H.THEME
  H.SetBackdrop(w.frame, THEME.panel2, THEME.border, 1)
  if w.titletext then
    H.SetTextColor(w.titletext, THEME.text)
    H.TrySetFont(w.titletext, 12, "OUTLINE")
  end
end

function H.HasWidget(typeName)
  if not AceGUI or not AceGUI.GetWidgetVersion then return false end
  local ok, ver = pcall(AceGUI.GetWidgetVersion, AceGUI, typeName)
  return ok and type(ver) == "number" and ver > 0
end

-- UI/Widgets/PreviewPanel.lua
-- EnhanceTBC custom AceGUI widget: ETBC_PreviewPanel

local _, ETBC = ...
local AceGUI = LibStub("AceGUI-3.0", true)
if not AceGUI then return end

local Type = "ETBC_PreviewPanel"
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
    bg = { 0.05, 0.07, 0.05, 0.98 },
    panel = { 0.07, 0.09, 0.07, 0.95 },
    border = { 0.12, 0.20, 0.12, 0.95 },
    text = { 0.90, 0.96, 0.90, 1.00 },
    muted = { 0.70, 0.78, 0.70, 1.00 },
    accent = { 0.20, 1.00, 0.20, 1.00 },
  }
end

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

local function Constructor()
  local frame = CreateFrame("Frame", nil, UIParent)
  frame:SetHeight(94)
  frame:SetWidth(300)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -9)
  title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -9)
  title:SetJustifyH("LEFT")

  local icon = frame:CreateTexture(nil, "ARTWORK")
  icon:SetSize(24, 24)
  icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -9)
  icon:Hide()

  local preview = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  preview:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  preview:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, 0)
  preview:SetJustifyH("LEFT")
  preview:SetJustifyV("TOP")

  local bar = CreateFrame("StatusBar", nil, frame)
  bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 10)
  bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
  bar:SetHeight(12)
  bar:SetMinMaxValues(0, 100)
  bar:SetValue(65)
  bar:Hide()
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

  local barBg = bar:CreateTexture(nil, "BACKGROUND")
  barBg:SetAllPoints(true)
  barBg:SetColorTexture(0, 0, 0, 0.35)

  local barText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  barText:SetPoint("CENTER", bar, "CENTER", 0, 0)

  local widget = {
    type = Type,
    frame = frame,
    icon = icon,
    title = title,
    preview = preview,
    bar = bar,
    barText = barText,
  }

  local function UpdateTextAnchors(self)
    self.title:ClearAllPoints()
    if self.icon:IsShown() then
      self.title:SetPoint("TOPLEFT", self.icon, "TOPRIGHT", 8, 0)
      self.title:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -10, -9)
    else
      self.title:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -9)
      self.title:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -10, -9)
    end
  end

  function widget:OnAcquire()
    local theme = GetTheme()
    SetBackdrop(self.frame, theme.panel or theme.bg, theme.border, 1)
    self:SetTitle("Preview")
    self:SetPreviewText("Live preview for current module settings.")
    self:SetIcon(nil)
    self:EnableBar(false)
    self:SetBarValue(65)
    local barColor = theme.accent or theme.border
    self:SetBarColor(barColor[1], barColor[2], barColor[3], 1)
    self:SetFullWidth(true)
  end

  function widget:OnRelease()
    self.frame:Hide()
    self.icon:Hide()
    self.bar:Hide()
  end

  function widget:SetTitle(text)
    self.title:SetText(text or "")
  end

  function widget:SetPreviewText(text)
    self.preview:SetText(text or "")
  end

  function widget:SetIcon(texturePathOrID)
    if texturePathOrID then
      self.icon:SetTexture(texturePathOrID)
      self.icon:Show()
    else
      self.icon:Hide()
    end
    UpdateTextAnchors(self)
  end

  function widget:SetPreviewFont(fontPath, size, flags)
    if self.preview and self.preview.SetFont and fontPath and fontPath ~= "" then
      pcall(self.preview.SetFont, self.preview, fontPath, size or 12, flags)
    end
  end

  function widget:EnableBar(enabled)
    if enabled then self.bar:Show() else self.bar:Hide() end
  end

  function widget:SetBarValue(v)
    v = tonumber(v) or 0
    if v < 0 then v = 0 elseif v > 100 then v = 100 end
    self.bar:SetValue(v)
    self.barText:SetText(("%d%%"):format(v))
  end

  function widget:SetBarColor(r, g, b, a)
    self.bar:SetStatusBarColor(r or 0.2, g or 0.8, b or 0.3, a or 1)
  end

  function widget:SetBarTexture(texturePath)
    if not texturePath or texturePath == "" then return end
    if self.bar and self.bar.SetStatusBarTexture then
      pcall(self.bar.SetStatusBarTexture, self.bar, texturePath)
    end
  end

  function widget:SetDisabled(disabled)
    self.disabled = disabled and true or false
    self.frame:SetAlpha(self.disabled and 0.65 or 1.0)
  end

  return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)

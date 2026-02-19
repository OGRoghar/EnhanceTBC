-- UI/Widgets/SearchHeader.lua
-- EnhanceTBC custom AceGUI widget: ETBC_SearchHeader

local _, ETBC = ...
local AceGUI = LibStub("AceGUI-3.0", true)
if not AceGUI then return end

local Type = "ETBC_SearchHeader"
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
    border = { 0.12, 0.20, 0.12, 0.95 },
    accent = { 0.20, 1.00, 0.20, 1.00 },
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

local function Constructor()
  local frame = CreateFrame("Frame", nil, UIParent)
  frame:SetHeight(52)
  frame:SetWidth(320)

  local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  label:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -120, 0)
  label:SetJustifyH("LEFT")
  label:SetText("Search")

  local results = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  results:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, 0)
  results:SetJustifyH("RIGHT")
  results:SetText("")

  local editbox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  editbox:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
  editbox:SetPoint("RIGHT", frame, "RIGHT", -86, 0)
  editbox:SetHeight(24)
  editbox:SetAutoFocus(false)
  editbox:SetTextInsets(8, 8, 0, 0)
  editbox:SetText("")

  local placeholder = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  placeholder:SetPoint("LEFT", editbox, "LEFT", 8, 0)
  placeholder:SetPoint("RIGHT", editbox, "RIGHT", -8, 0)
  placeholder:SetJustifyH("LEFT")
  placeholder:SetText("Search modules / options...")

  local clear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  clear:SetPoint("LEFT", editbox, "RIGHT", 6, 0)
  clear:SetWidth(24)
  clear:SetHeight(24)
  clear:SetText("x")

  local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("LEFT", clear, "RIGHT", 6, 0)
  hint:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
  hint:SetJustifyH("LEFT")
  hint:SetText("Esc clears")

  local widget = {
    type = Type,
    frame = frame,
    label = label,
    results = results,
    editbox = editbox,
    placeholder = placeholder,
    clear = clear,
    hint = hint,
  }

  local function UpdatePlaceholder(self)
    if not self.placeholder then return end
    local text = self:GetText()
    local focused = self.editbox and self.editbox.HasFocus and self.editbox:HasFocus()
    self.placeholder:SetShown((text == nil or text == "") and not focused)
  end

  local function ApplyTheme()
    local theme = GetTheme()
    label:SetTextColor(theme.text[1], theme.text[2], theme.text[3], theme.text[4] or 1)
    results:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3], theme.muted[4] or 1)
    hint:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3], 0.9)
    placeholder:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3], 0.75)
    SetBackdrop(editbox, theme.bg, theme.border)
    if editbox.SetTextColor then
      editbox:SetTextColor(theme.text[1], theme.text[2], theme.text[3], theme.text[4] or 1)
    end
  end

  function widget:OnAcquire()
    self:SetLabel("Search")
    self:SetResultCount(nil)
    self:SetText("")
    self:SetDisabled(false)
    self:SetFullWidth(true)
    ApplyTheme()
    UpdatePlaceholder(self)
  end

  function widget:OnRelease()
    self.editbox:ClearFocus()
    self.frame:Hide()
  end

  function widget:OnWidthSet(width)
    self.frame:SetWidth(width or 320)
  end

  function widget:OnHeightSet(height)
    self.frame:SetHeight(height or 44)
  end

  function widget:SetLabel(text)
    self.label:SetText(text or "")
  end

  function widget:SetPlaceholder(text)
    self.placeholder:SetText(text or "")
    UpdatePlaceholder(self)
  end

  function widget:SetText(text)
    self.editbox:SetText(text or "")
    UpdatePlaceholder(self)
  end

  function widget:GetText()
    return self.editbox:GetText() or ""
  end

  function widget:SetResultCount(count)
    if type(count) == "number" then
      if count == 1 then
        self.results:SetText("1 result")
      else
        self.results:SetText(("%d results"):format(count))
      end
    else
      self.results:SetText("")
    end
  end

  function widget:SetDisabled(disabled)
    disabled = disabled and true or false
    self.disabled = disabled
    if self.editbox.EnableMouse then
      self.editbox:EnableMouse(not disabled)
    end
    if self.editbox.SetEnabled then
      self.editbox:SetEnabled(not disabled)
    end
    if self.clear and self.clear.Enable then
      self.clear:Enable(not disabled)
    end
    self.frame:SetAlpha(disabled and 0.6 or 1.0)
    UpdatePlaceholder(self)
  end

  editbox:SetScript("OnEditFocusGained", function(selfEdit)
    local theme = GetTheme()
    SetBackdrop(selfEdit, theme.bg, theme.accent)
    UpdatePlaceholder(widget)
  end)

  editbox:SetScript("OnEditFocusLost", function(selfEdit)
    local theme = GetTheme()
    SetBackdrop(selfEdit, theme.bg, theme.border)
    UpdatePlaceholder(widget)
  end)

  editbox:SetScript("OnEscapePressed", function(selfEdit)
    if widget.disabled then return end
    if selfEdit.GetText and selfEdit:GetText() ~= "" then
      widget:SetText("")
      widget:Fire("OnTextChanged", "", true)
    end
    if selfEdit.ClearFocus then
      selfEdit:ClearFocus()
    end
  end)

  editbox:SetScript("OnTextChanged", function(_, userInput)
    UpdatePlaceholder(widget)
    widget:Fire("OnTextChanged", widget:GetText(), userInput and true or false)
  end)

  clear:SetScript("OnClick", function()
    if widget.disabled then return end
    widget:SetText("")
    widget.editbox:SetFocus()
    widget:Fire("OnTextChanged", "", true)
    widget:Fire("OnClearClicked")
  end)

  return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)

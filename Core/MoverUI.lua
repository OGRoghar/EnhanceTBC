-- Core/MoverUI.lua
local ADDON_NAME, ETBC = ...

local M = ETBC.Mover
local UI = {}
ETBC.MoverUI = UI

local overlay
local gridLayer
local guidesLayer
local handles = {}
local escWatcher

local function EnsureOverlay()
  if overlay then return end

  overlay = CreateFrame("Frame", "EnhanceTBC_MoverOverlay", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  overlay:SetAllPoints(UIParent)
  overlay:SetFrameStrata("DIALOG")
  overlay:Hide()

  overlay.tint = overlay:CreateTexture(nil, "BACKGROUND")
  overlay.tint:SetAllPoints(overlay)
  overlay.tint:SetTexture("Interface/Buttons/WHITE8x8")
  overlay.tint:SetVertexColor(0, 0, 0, 0.45)

  gridLayer = CreateFrame("Frame", nil, overlay)
  gridLayer:SetAllPoints(overlay)

  guidesLayer = CreateFrame("Frame", nil, overlay)
  guidesLayer:SetAllPoints(overlay)

  overlay.title = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  overlay.title:SetPoint("TOP", overlay, "TOP", 0, -24)
  overlay.title:SetText("EnhanceTBC Move Mode")

  overlay.sub = overlay:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  overlay.sub:SetPoint("TOP", overlay.title, "BOTTOM", 0, -6)
  overlay.sub:SetText("Left-drag to move • Right-click to reset • Shift+Right-click resets ALL • ESC to exit")

  escWatcher = CreateFrame("Frame", nil, overlay)
  escWatcher:EnableKeyboard(true)
  escWatcher:SetPropagateKeyboardInput(true)
  escWatcher:SetScript("OnKeyDown", function(_, key)
    if key == "ESCAPE" then
      M:SetMoveMode(false)
    end
  end)
end

local function WipeTextures(frame)
  if not frame then return end
  if frame._etbcTex then
    for i = 1, #frame._etbcTex do
      frame._etbcTex[i]:Hide()
      frame._etbcTex[i]:SetParent(nil)
    end
    wipe(frame._etbcTex)
  end
  frame._etbcTex = {}
end

local function AddLine(parent, layer, x, y, w, h, a, r, g, b)
  parent._etbcTex = parent._etbcTex or {}
  local t = parent:CreateTexture(nil, layer)
  t:SetTexture("Interface/Buttons/WHITE8x8")
  t:SetVertexColor(r or 0.2, g or 1.0, b or 0.2, a or 0.12)
  t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  t:SetSize(w, h)
  parent._etbcTex[#parent._etbcTex+1] = t
  return t
end

local function BuildGrid(db)
  WipeTextures(gridLayer)
  if not db.showGrid then return end

  local g = M:GetGridSize()
  local w = UIParent:GetWidth()
  local h = UIParent:GetHeight()

  local x = 0
  while x <= w do
    local alpha = ((x % (g * 5)) == 0) and 0.16 or 0.08
    AddLine(gridLayer, "BORDER", x, 0, 1, h, alpha, 0.2, 1.0, 0.2)
    x = x + g
  end

  local y = 0
  while y <= h do
    local alpha = ((y % (g * 5)) == 0) and 0.16 or 0.08
    AddLine(gridLayer, "BORDER", 0, -y, w, 1, alpha, 0.2, 1.0, 0.2)
    y = y + g
  end
end

local function BuildGuides(db)
  WipeTextures(guidesLayer)
  if not db.showGuides then return end

  local w = UIParent:GetWidth()
  local h = UIParent:GetHeight()
  local cx = w / 2
  local cy = h / 2

  AddLine(guidesLayer, "ARTWORK", cx, 0, 2, h, 0.30, 0.2, 1.0, 0.2)
  AddLine(guidesLayer, "ARTWORK", 0, -cy, w, 2, 0.30, 0.2, 1.0, 0.2)
end

local function FlashHandleBorder(f)
  if not f or not f.SetBackdropBorderColor then return end
  f:SetBackdropBorderColor(1.0, 0.9, 0.2, 1.0)

  local function restore()
    if f and f.SetBackdropBorderColor then
      f:SetBackdropBorderColor(0.2, 1.0, 0.2, 1.0)
    end
  end

  if C_Timer and C_Timer.After then
    C_Timer.After(0.12, restore)
  else
    restore()
  end
end

local function EnsureHandle(key)
  if handles[key] then return handles[key] end

  -- IMPORTANT: Button so RightClick is reliable
  local f = CreateFrame("Button", nil, overlay, BackdropTemplateMixin and "BackdropTemplate" or nil)
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)

  f:RegisterForDrag("LeftButton")
  f:RegisterForClicks("AnyUp")

  if f.SetBackdrop then
    f:SetBackdrop({
      bgFile = "Interface/Buttons/WHITE8x8",
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
      edgeSize = 14,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    f:SetBackdropColor(0.03, 0.08, 0.03, 0.55)
    f:SetBackdropBorderColor(0.2, 1.0, 0.2, 1.0)
  end

  f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.label:SetPoint("CENTER", f, "CENTER", 0, 0)
  f.label:SetText(key)

  f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.hint:SetPoint("TOP", f, "BOTTOM", 0, -2)
  f.hint:SetText("Left-drag • Right reset")

  f:SetScript("OnDragStart", function(self)
    if not self.StartMoving then return end
    self:StartMoving()
  end)

  f:SetScript("OnDragStop", function(self)
    if self.StopMovingOrSizing then
      self:StopMovingOrSizing()
    end
    if not self._entry then return end
    if not self.GetPoint then return end

    local point, _, relPoint, x, y = self:GetPoint(1)
    if not point then return end
    x, y = x or 0, y or 0

    if M.ApplyAnchorFromHandle then
      M:ApplyAnchorFromHandle(self._entry, point, relPoint, x, y)
    end

    local a = self._entry.getAnchorDB and self._entry.getAnchorDB()
    if a then
      self:ClearAllPoints()
      self:SetPoint(a.point, UIParent, a.relPoint, a.x, a.y)
    end
  end)

  f:SetScript("OnClick", function(self, button)
    if button ~= "RightButton" then return end
    if not self._entry then return end

    if IsShiftKeyDown() then
      M:ResetAll()
      FlashHandleBorder(self)
      UI:Apply()
      return
    end

    M:ResetEntry(self._entry)
    FlashHandleBorder(self)

    local a = self._entry.getAnchorDB and self._entry.getAnchorDB()
    if a then
      self:ClearAllPoints()
      self:SetPoint(a.point, UIParent, a.relPoint, a.x, a.y)
    end
  end)

  handles[key] = f
  return f
end

local function RefreshHandles(db)
  if M.AutoRegisterKnown then
    M:AutoRegisterKnown()
  end

  for _, f in pairs(handles) do
    f:Hide()
  end

  local scale = db.handleScale or 1.0

  local registered = M.GetRegistered and M:GetRegistered() or {}
  for key, entry in pairs(registered) do
    local frame = entry.getFrame and entry.getFrame()
    local a = entry.getAnchorDB and entry.getAnchorDB()

    if frame and a then
      local h = EnsureHandle(key)
      h._entry = entry
      h:SetScale(scale)

      h:SetSize(entry.sizeW or 220, entry.sizeH or 44)
      h.label:SetText(entry.name or key)

      h:ClearAllPoints()
      h:SetPoint(a.point or "CENTER", UIParent, a.relPoint or "CENTER", a.x or 0, a.y or 0)
      h:Show()
    end
  end
end

function UI:Apply()
  EnsureOverlay()

  local p = ETBC.db.profile
  local db = p.mover

  M:SetupChatCommands()

  if not (p.general.enabled and db.enabled and db.moveMode) then
    overlay:Hide()
    return
  end

  overlay:Show()
  overlay.tint:SetVertexColor(0, 0, 0, db.tintAlpha or 0.45)

  BuildGrid(db)
  BuildGuides(db)
  RefreshHandles(db)
end

local function Apply()
  if ETBC.MoverUI and ETBC.MoverUI.Apply then
    ETBC.MoverUI:Apply()
  end
end

ETBC.ApplyBus:Register("mover", Apply)
ETBC.ApplyBus:Register("general", Apply)

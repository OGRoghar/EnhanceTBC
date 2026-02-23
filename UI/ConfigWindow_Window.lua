-- UI/ConfigWindow_Window.lua
-- Internal window lifecycle/layout helpers for EnhanceTBC config window.

local _, ETBC = ...
ETBC.UI = ETBC.UI or {}
local UI = ETBC.UI

local AceGUI = LibStub("AceGUI-3.0")

UI.ConfigWindow = UI.ConfigWindow or {}
local ConfigWindow = UI.ConfigWindow
ConfigWindow.Internal = ConfigWindow.Internal or {}

ConfigWindow.Internal.Window = ConfigWindow.Internal.Window or {}
local H = ConfigWindow.Internal.Window

if H._loaded then return end
H._loaded = true

local ThemeHelpers = ConfigWindow.Internal.Theme or {}
local DataHelpers = ConfigWindow.Internal.Data or {}
local RenderHelpers = ConfigWindow.Internal.Render or {}

local LOGO_PATH = ThemeHelpers.LOGO_PATH
local THEME = ThemeHelpers.THEME
local SetBackdrop = ThemeHelpers.SetBackdrop
local TrySetFont = ThemeHelpers.TrySetFont
local StyleEditBoxWidget = ThemeHelpers.StyleEditBoxWidget
local HasWidget = ThemeHelpers.HasWidget

local GetUIDB = DataHelpers.GetUIDB
local GatherGroups = DataHelpers.GatherGroups
local FindGroup = DataHelpers.FindGroup
local KEY_TO_CATEGORY = DataHelpers.KEY_TO_CATEGORY
local BuildTree = DataHelpers.BuildTree

local AddDesc = RenderHelpers.AddDesc
local RenderOptions = RenderHelpers.RenderOptions

-- ---------------------------------------------------------
-- Window lifecycle & layout
-- ---------------------------------------------------------
local state = {
  win = nil,
  groups = nil,
  tree = nil,
  rightScroll = nil,
  search = nil,
  searchTimer = nil,
  resizeTimer = nil,
  currentModuleKey = nil,
  currentModuleName = nil,
  closing = false,
}

local function StyleScrollbar(scrollbar)
  if not scrollbar then return end

  if not scrollbar._etbcTrack then
    local track = scrollbar:CreateTexture(nil, "BACKGROUND")
    track:SetTexture("Interface\\Buttons\\WHITE8x8")
    track:SetAllPoints(scrollbar)
    track:SetVertexColor(THEME.panel3[1], THEME.panel3[2], THEME.panel3[3], 0.95)
    scrollbar._etbcTrack = track
  end

  local thumb
  local name = scrollbar.GetName and scrollbar:GetName()
  if name and _G[name .. "ThumbTexture"] then
    thumb = _G[name .. "ThumbTexture"]
  end
  if thumb and thumb.SetTexture then
    thumb:SetTexture("Interface\\Buttons\\WHITE8x8")
    thumb:SetVertexColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.9)
  end

  if not scrollbar._etbcHoverHooked and scrollbar.HookScript then
    scrollbar._etbcHoverHooked = true
    scrollbar:HookScript("OnEnter", function()
      local sName = scrollbar.GetName and scrollbar:GetName()
      local sThumb = sName and _G[sName .. "ThumbTexture"] or nil
      if sThumb and sThumb.SetVertexColor then
        sThumb:SetVertexColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 1)
      end
    end)
    scrollbar:HookScript("OnLeave", function()
      local sName = scrollbar.GetName and scrollbar:GetName()
      local sThumb = sName and _G[sName .. "ThumbTexture"] or nil
      if sThumb and sThumb.SetVertexColor then
        sThumb:SetVertexColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.9)
      end
    end)
  end
end

local function StyleTreeButtons(tree)
  if not tree or not tree.buttons then return end
  local selected = tree.localstatus and tree.localstatus.selected or nil

  for i = 1, #tree.buttons do
    local btn = tree.buttons[i]
    if btn and btn:IsShown() then
      local isCategory = btn.toggle and btn.toggle.IsShown and btn.toggle:IsShown()
      local isSelected = selected and btn.uniquevalue == selected and not isCategory

      if not btn._etbcSelectBg then
        local t = btn:CreateTexture(nil, "BACKGROUND")
        t:SetTexture("Interface\\Buttons\\WHITE8x8")
        t:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -1)
        t:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 1)
        btn._etbcSelectBg = t
      end
      btn._etbcSelectBg:SetShown(isSelected and true or false)
      if isSelected then
        btn._etbcSelectBg:SetVertexColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.22)
      end

      if btn.text then
        btn.text:SetJustifyH("LEFT")
        if isCategory then
          local label = btn.text:GetText() or ""
          btn.text:SetText(tostring(label):upper())
          btn.text:SetTextColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 1)
          TrySetFont(btn.text, 12, "OUTLINE")
        else
          if isSelected then
            btn.text:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], 1)
            TrySetFont(btn.text, 12, "OUTLINE")
          else
            btn.text:SetTextColor(THEME.muted[1], THEME.muted[2], THEME.muted[3], 1)
            TrySetFont(btn.text, 11, nil)
          end
        end
      end
    end
  end
end

local function StyleTreeWidget(tree)
  if not tree then return end

  if tree.frame then
    SetBackdrop(tree.frame, THEME.panel, THEME.border, 1)
  end
  if tree.treeframe then
    SetBackdrop(tree.treeframe, THEME.panel2, THEME.border, 1)
  end
  if tree.border then
    SetBackdrop(tree.border, THEME.panel2, THEME.border, 1)
  end
  if tree.scrollbar then
    StyleScrollbar(tree.scrollbar)
  end

  if not tree._etbcRefreshHooked and type(tree.RefreshTree) == "function" then
    local origRefresh = tree.RefreshTree
    tree._etbcRefreshHooked = true
    tree.RefreshTree = function(self, ...)
      origRefresh(self, ...)
      StyleTreeButtons(self)
    end
  end

  StyleTreeButtons(tree)
end

local function UpdateHeaderMoverButton(win)
  if not (win and win.frame and win.frame._etbcHeaderMoverBtn) then return end

  local btn = win.frame._etbcHeaderMoverBtn
  local mover = ETBC and ETBC.Mover or nil
  local p = ETBC and ETBC.db and ETBC.db.profile or nil
  local moverDB = p and p.mover or nil
  local generalEnabled = p and p.general and p.general.enabled ~= false or false

  local canToggle = mover and (mover.ToggleMasterMove or mover.SetMasterMove) and generalEnabled
  local active = moverDB and moverDB.enabled and moverDB.moveMode and moverDB.unlocked and true or false

  btn._etbcCanUse = canToggle and true or false
  btn._etbcActive = active and true or false
  if not btn._etbcCanUse then
    btn._etbcHover = false
  end

  if btn.SetEnabled then
    btn:SetEnabled(btn._etbcCanUse)
  end
  if btn.EnableMouse then
    btn:EnableMouse(btn._etbcCanUse)
  end

  if btn.text then
    if not btn._etbcCanUse then
      btn.text:SetText("Mover N/A")
      btn.text:SetTextColor(THEME.muted[1], THEME.muted[2], THEME.muted[3], 1)
    elseif btn._etbcActive then
      btn.text:SetText("Exit Move")
      btn.text:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], 1)
    else
      btn.text:SetText("Move Mode")
      btn.text:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], 1)
    end
    TrySetFont(btn.text, 11, "OUTLINE")
  end

  if btn.SetBackdropColor and btn.SetBackdropBorderColor then
    if not btn._etbcCanUse then
      btn:SetBackdropColor(THEME.panel2[1], THEME.panel2[2], THEME.panel2[3], 0.65)
      btn:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 0.65)
    elseif btn._etbcActive then
      btn:SetBackdropColor(0.08, 0.12, 0.08, 0.96)
      btn:SetBackdropBorderColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 1)
    elseif btn._etbcHover then
      btn:SetBackdropColor(THEME.panel2[1], THEME.panel2[2], THEME.panel2[3], 0.96)
      btn:SetBackdropBorderColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 1)
    else
      btn:SetBackdropColor(THEME.panel2[1], THEME.panel2[2], THEME.panel2[3], 0.90)
      btn:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 1)
    end
  end

  if btn.SetAlpha then
    btn:SetAlpha(btn._etbcCanUse and 1 or 0.85)
  end
end

local function ApplyWindowStyle(win)
  if not win or not win.frame then return end
  local headerMoverWidth = 116
  local headerRightInset = headerMoverWidth + 24

  SetBackdrop(win.frame, THEME.bg, THEME.border, 1)

  if win.titletext then
    win.titletext:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3])
    TrySetFont(win.titletext, 14, "OUTLINE")
  end
  if win.statustext then
    win.statustext:SetText("")
  end

  -- Header strip for logo/title composition.
  if not win.frame._etbcHeaderStrip then
    local strip = CreateFrame("Frame", nil, win.frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    strip:SetPoint("TOPLEFT", win.frame, "TOPLEFT", 12, -28)
    strip:SetPoint("TOPRIGHT", win.frame, "TOPRIGHT", -12, -28)
    strip:SetHeight(66)
    SetBackdrop(strip, THEME.panel3, THEME.border, 1)

    local line = strip:CreateTexture(nil, "BORDER")
    line:SetTexture("Interface\\Buttons\\WHITE8x8")
    line:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 1, 1)
    line:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", -1, 1)
    line:SetHeight(2)
    line:SetVertexColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.55)

    local status = strip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("LEFT", strip, "LEFT", 100, -14)
    status:SetPoint("RIGHT", strip, "RIGHT", -headerRightInset, -14)
    status:SetJustifyH("LEFT")
    status:SetTextColor(THEME.muted[1], THEME.muted[2], THEME.muted[3], 1)
    status:SetText("TBC Anniversary UI | Live settings | /etbc")
    TrySetFont(status, 11, nil)

    win.frame._etbcHeaderStrip = strip
    win.frame._etbcHeaderStatus = status
  end

  -- Logo (DO NOT CHANGE SIZE)
  if not win.frame._etbcLogo then
    local parent = win.frame._etbcHeaderStrip or win.frame
    local logo = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    logo:SetTexture(LOGO_PATH)
    logo:SetPoint("TOPLEFT", win.frame, "TOPLEFT", 14, -6)
    logo:SetSize(90, 90)
    logo:SetAlpha(0.9)
    logo:SetDrawLayer("OVERLAY", 7)
    win.frame._etbcLogo = logo
  end

  if win.frame._etbcHeaderStrip and not win.frame._etbcHeaderMoverBtn then
    local btn = CreateFrame(
      "Button",
      nil,
      win.frame._etbcHeaderStrip,
      BackdropTemplateMixin and "BackdropTemplate" or nil
    )
    btn:SetSize(headerMoverWidth, 24)
    btn:SetPoint("RIGHT", win.frame._etbcHeaderStrip, "RIGHT", -10, 0)
    btn._etbcHover = false
    SetBackdrop(btn, THEME.panel2, THEME.border, 1)

    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER", btn, "CENTER", 0, 0)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    btn.text = text

    if not btn._etbcHooksInstalled then
      btn._etbcHooksInstalled = true

      btn:SetScript("OnEnter", function(self)
        self._etbcHover = true
        UpdateHeaderMoverButton(state.win or win)
        if GameTooltip then
          GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
          if self._etbcCanUse then
            if self._etbcActive then
              GameTooltip:AddLine("Exit mover mode", THEME.accent[1], THEME.accent[2], THEME.accent[3])
            else
              GameTooltip:AddLine("Enter mover mode", THEME.accent[1], THEME.accent[2], THEME.accent[3])
              GameTooltip:AddLine("Entering mover mode closes the config window.", 1, 0.82, 0, true)
            end
          else
            GameTooltip:AddLine("Mover unavailable", 1, 0.4, 0.4)
            GameTooltip:AddLine("General and Mover must be enabled.", 0.8, 0.8, 0.8, true)
          end
          GameTooltip:Show()
        end
      end)

      btn:SetScript("OnLeave", function(self)
        self._etbcHover = false
        UpdateHeaderMoverButton(state.win or win)
        if GameTooltip then
          GameTooltip:Hide()
        end
      end)

      btn:SetScript("OnClick", function(self)
        if not self._etbcCanUse then return end
        local mover = ETBC and ETBC.Mover or nil
        if not mover then return end
        if mover.ToggleMasterMove then
          mover:ToggleMasterMove()
          return
        end
        if mover.SetMasterMove then
          local p = ETBC and ETBC.db and ETBC.db.profile or nil
          local moverDB = p and p.mover or nil
          local nextState = not (moverDB and moverDB.moveMode)
          mover:SetMasterMove(nextState and true or false)
        end
      end)
    end

    win.frame._etbcHeaderMoverBtn = btn
  end

  if win.titletext and win.frame._etbcHeaderStrip then
    win.titletext:ClearAllPoints()
    win.titletext:SetPoint("LEFT", win.frame._etbcHeaderStrip, "LEFT", 100, 14)
    win.titletext:SetPoint("RIGHT", win.frame._etbcHeaderStrip, "RIGHT", -headerRightInset, 14)
    win.titletext:SetJustifyH("LEFT")
  end

  UpdateHeaderMoverButton(win)

  -- Move AceGUI content below header strip and keep generous bottom area.
  if win.content then
    win.content:ClearAllPoints()
    win.content:SetPoint("TOPLEFT", win.frame, "TOPLEFT", 12, -116)
    win.content:SetPoint("BOTTOMRIGHT", win.frame, "BOTTOMRIGHT", -12, 12)
  end

  -- Styled inner background aligned with content
  if not win.frame._etbcInner then
    -- Use BackdropTemplate when available; safe in Classic-era clients.
    local inner = CreateFrame("Frame", nil, win.frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    inner:SetPoint("TOPLEFT", win.content, "TOPLEFT", -6, 6)
    inner:SetPoint("BOTTOMRIGHT", win.content, "BOTTOMRIGHT", 6, -6)

    SetBackdrop(inner, THEME.panel, THEME.border, 1)

    local topLine = inner:CreateTexture(nil, "BORDER")
    topLine:SetTexture("Interface\\Buttons\\WHITE8x8")
    topLine:SetPoint("TOPLEFT", inner, "TOPLEFT", 1, -1)
    topLine:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -1, -1)
    topLine:SetHeight(2)
    topLine:SetVertexColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.55)

    local subHeader = inner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subHeader:SetPoint("TOPLEFT", inner, "TOPLEFT", 10, -8)
    subHeader:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -10, -8)
    subHeader:SetJustifyH("LEFT")
    subHeader:SetTextColor(THEME.muted[1], THEME.muted[2], THEME.muted[3], 1)
    TrySetFont(subHeader, 11, nil)
    win.frame._etbcInnerSubHeader = subHeader

    win.frame._etbcInner = inner
  end

  -- Update inner frame positions on resize
  if win.frame._etbcInner then
    win.frame._etbcInner:ClearAllPoints()
    win.frame._etbcInner:SetPoint("TOPLEFT", win.content, "TOPLEFT", -6, 6)
    win.frame._etbcInner:SetPoint("BOTTOMRIGHT", win.content, "BOTTOMRIGHT", 6, -6)
  end

  if win.frame._etbcInnerSubHeader then
    local moduleText = state.currentModuleName and ("Module: " .. tostring(state.currentModuleName))
      or "Module: Select a section on the left"
    win.frame._etbcInnerSubHeader:SetText(moduleText)
  end
end

local function SaveWindow()
  local db = GetUIDB()
  if not db or not state.win or not state.win.frame then return end

  db.w = state.win.frame:GetWidth()
  db.h = state.win.frame:GetHeight()

  local point, rel, relPoint, x, y = state.win.frame:GetPoint(1)
  if point then
    db.point = point
    db.rel = rel and rel.GetName and rel:GetName() or "UIParent"
    db.relPoint = relPoint
    db.x, db.y = x, y
  end

  if state.tree and state.tree.localstatus then
    db.treewidth = state.tree.localstatus.treewidth or db.treewidth
  end

  if state.search then
    db.search = tostring(state.search:GetText() or "")
  end

  if db.lastModule == nil then db.lastModule = "auras" end
end

local function RestoreWindow()
  local db = GetUIDB()
  if not db or not state.win or not state.win.frame then return end

  state.win:SetWidth(db.w or 980)
  state.win:SetHeight(db.h or 720)

  state.win.frame:ClearAllPoints()
  state.win.frame:SetPoint(
    db.point or "CENTER",
    _G[db.rel or "UIParent"] or UIParent,
    db.relPoint or "CENTER",
    db.x or 0, db.y or 0
  )

  if state.tree and state.tree.localstatus then
    state.tree.localstatus.treewidth = db.treewidth or 280
  end

  if state.search then
    state.search:SetText(db.search or "")
  end
end

local function ClearPreviewModes()
  local p = ETBC.db and ETBC.db.profile
  if not p then return end
  local bus = ETBC.ApplyBus
  local batched = bus and bus.BeginBatch and bus.EndBatch
  if batched then
    bus:BeginBatch()
  end

  local function DisablePreview(key, applyKey)
    local db = p[key]
    if db and db.preview then
      db.preview = false
      if bus and bus.Notify then
        bus:Notify(applyKey or key)
      end
    end
  end

  DisablePreview("auras")
  DisablePreview("actiontracker")
  DisablePreview("swingtimer")
  DisablePreview("combattext")

  if batched then
    bus:EndBatch(true)
  end
end

function ConfigWindow:Close()
  local _ = self
  if state.closing then return end
  if not state.win then return end
  state.closing = true

  SaveWindow()
  ClearPreviewModes()

  if state.searchTimer and state.searchTimer.Cancel then
    state.searchTimer:Cancel()
  end
  if state.resizeTimer and state.resizeTimer.Cancel then
    state.resizeTimer:Cancel()
  end

  local w = state.win
  state.win = nil
  state.groups = nil
  state.tree = nil
  state.rightScroll = nil
  state.search = nil
  state.searchTimer = nil
  state.resizeTimer = nil

  if w and w.Release then
    w:Release()
  end

  state.closing = false
end

local function ExtractLastToken(path)
  if type(path) ~= "string" then return nil end
  local last
  for token in path:gmatch("([^\001]+)") do
    last = token
  end
  return last
end

local function GetDefaultModuleKey(groups, preferred)
  if type(groups) ~= "table" or #groups == 0 then return nil end
  if preferred and FindGroup(groups, preferred) then
    return preferred
  end
  return groups[1].key
end

local function NewDebounceTimer(delay, fn)
  local timer = { _cancelled = false }

  if ETBC and ETBC.ScheduleTimer and ETBC.CancelTimer then
    local handle = ETBC:ScheduleTimer(function()
      if timer._cancelled then return end
      fn()
    end, delay)
    function timer:Cancel()
      self._cancelled = true
      if handle then
        ETBC:CancelTimer(handle, true)
      end
    end
    return timer
  end

  if C_Timer and C_Timer.NewTimer then
    local handle = C_Timer.NewTimer(delay, function()
      if timer._cancelled then return end
      fn()
    end)
    function timer:Cancel()
      self._cancelled = true
      if handle and handle.Cancel then handle:Cancel() end
    end
    return timer
  end

  if C_Timer and C_Timer.After then
    C_Timer.After(delay, function()
      if timer._cancelled then return end
      fn()
    end)
    function timer:Cancel()
      self._cancelled = true
    end
    return timer
  end

  fn()
  function timer:Cancel() self._cancelled = true end
  return timer
end

local function BuildWindow()
  if state.win then return end
  local db = GetUIDB()
  if not db then return end

  local groups = GatherGroups()
  state.groups = groups

  local defaultModule = GetDefaultModuleKey(groups, db.lastModule)

  local win = AceGUI:Create("Frame")
  win:SetTitle("EnhanceTBC")
  win:SetStatusText("TBC Anniversary UI | Live settings | /etbc")
  win:SetLayout("Fill")
  win:SetWidth(db.w or 980)
  win:SetHeight(db.h or 720)
  win:EnableResize(true)
  win.frame:SetFrameStrata("DIALOG")
  win.frame:SetClampedToScreen(true)

  ApplyWindowStyle(win)

  win.frame:EnableKeyboard(true)
  win.frame:SetPropagateKeyboardInput(true)
  win.frame:HookScript("OnKeyDown", function(frame, key)
    if key == "ESCAPE" then
      if frame.SetPropagateKeyboardInput then
        frame:SetPropagateKeyboardInput(false)
      end
      ConfigWindow:Close()
    elseif frame.SetPropagateKeyboardInput then
      frame:SetPropagateKeyboardInput(true)
    end
  end)

  win:SetCallback("OnClose", function()
    ConfigWindow:Close()
  end)

  local root
  local tree
  local right
  local topPad
  local search
  local QueueResizeLayout
  local ApplyTreeWidth
  local SyncContainerHeights

  ApplyTreeWidth = function(width)
    local w = tonumber(width) or 280
    if w < 180 then w = 180 end
    w = math.floor(w + 0.5)

    db.treewidth = w
    if tree and tree.localstatus then
      tree.localstatus.treewidth = w
    end
    if tree and tree.SetTreeWidth then
      tree:SetTreeWidth(w, true)
    end
  end

  SyncContainerHeights = function()
    if not (win and win.content and root and tree) then return end
    if not (win.content.GetHeight and root.SetHeight and tree.SetHeight) then return end

    local contentHeight = tonumber(win.content:GetHeight()) or 0
    if contentHeight <= 0 then return end

    local topPadHeight = 0
    if topPad and topPad.frame and topPad.frame.GetHeight then
      topPadHeight = tonumber(topPad.frame:GetHeight()) or 0
    end
    local searchHeight = 0
    if search and search.frame and search.frame.GetHeight then
      searchHeight = tonumber(search.frame:GetHeight()) or 0
    end
    if searchHeight <= 0 then
      searchHeight = 38
    end

    local treeHeight = math.max(120, math.floor(contentHeight - topPadHeight - searchHeight - 8))
    root:SetHeight(contentHeight)
    tree:SetHeight(treeHeight)
    if right and right.SetHeight then
      right:SetHeight(treeHeight)
    end
  end

  -- Handle window resize dynamically
  QueueResizeLayout = function()
    if state.resizeTimer then return end
    state.resizeTimer = NewDebounceTimer(0.06, function()
      state.resizeTimer = nil
      if tree then
        local contentWidth = 0
        if win and win.content and win.content.GetWidth then
          contentWidth = tonumber(win.content:GetWidth()) or 0
        end
        if contentWidth <= 0 and root and root.frame and root.frame.GetWidth then
          contentWidth = tonumber(root.frame:GetWidth()) or 0
        end
        if contentWidth > 0 then
          local maxTreeWidth = math.max(180, math.floor(contentWidth - 260))
          local target = tonumber(db.treewidth) or 280
          if target > maxTreeWidth then
            target = maxTreeWidth
          end
          ApplyTreeWidth(target)
        end
      end
      SyncContainerHeights()

      if win and win.DoLayout then
        win:DoLayout()
      end
      if root and root.DoLayout then
        root:DoLayout()
      end
      if state.tree and state.tree.DoLayout then
        state.tree:DoLayout()
      end
      if state.rightScroll then
        if state.rightScroll.DoLayout then
          state.rightScroll:DoLayout()
        end
        if state.rightScroll.UpdateScroll then
          state.rightScroll:UpdateScroll()
        end
      end
      ApplyWindowStyle(win)
    end)
  end

  win.frame:HookScript("OnSizeChanged", function()
    QueueResizeLayout()
  end)

  state.win = win

  -- Root: Fill -> vertical group inside
  root = AceGUI:Create("SimpleGroup")
  root:SetFullWidth(true)
  root:SetFullHeight(true)
  root:SetLayout("List")
  win:AddChild(root)

  topPad = AceGUI:Create("Label")
  topPad:SetText(" ")
  topPad:SetFullWidth(true)
  if topPad.SetHeight then
    topPad:SetHeight(18)
  end
  root:AddChild(topPad)

  if HasWidget("ETBC_SearchHeader") then
    search = AceGUI:Create("ETBC_SearchHeader")
    search:SetLabel("Search")
    search:SetFullWidth(true)
    if search.SetPlaceholder then
      search:SetPlaceholder("Search modules / options...")
    end
  else
    search = AceGUI:Create("EditBox")
    search:SetLabel("Search")
    search:SetFullWidth(true)
    search:DisableButton(true)
    StyleEditBoxWidget(search)

    -- Green glow when focused
    if search.editbox and search.editbox.SetBackdropBorderColor then
      search.editbox:HookScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 1)
      end)
      search.editbox:HookScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 1)
      end)
    end
  end
  root:AddChild(search)
  state.search = search

  -- TreeGroup handles BOTH columns
  tree = AceGUI:Create("TreeGroup")
  tree:SetFullWidth(true)
  tree:SetFullHeight(true)
  tree:SetLayout("Fill")
  tree:SetTree(BuildTree(groups))
  tree:SetStatusTable(db.treeStatus)
  root:AddChild(tree)
  state.tree = tree

  if tree.frame then
    SetBackdrop(tree.frame, THEME.panel, THEME.border, 1)
  end
  if tree.treeframe then
    SetBackdrop(tree.treeframe, THEME.panel2, THEME.border, 1)
  end
  if tree.border then
    SetBackdrop(tree.border, THEME.panel2, THEME.border, 1)
  end
  StyleTreeWidget(tree)

  -- Add subtle vertical divider on right edge of tree
  if tree.treeframe and not tree.treeframe._etbcDivider then
    local divider = tree.treeframe:CreateTexture(nil, "BORDER")
    divider:SetTexture("Interface\\Buttons\\WHITE8x8")
    divider:SetWidth(1)
    divider:SetPoint("TOPRIGHT", tree.treeframe, "TOPRIGHT", 0, -2)
    divider:SetPoint("BOTTOMRIGHT", tree.treeframe, "BOTTOMRIGHT", 0, 2)
    divider:SetVertexColor(THEME.border[1], THEME.border[2], THEME.border[3], 0.7)
    tree.treeframe._etbcDivider = divider
  end

  -- ScrollFrame goes INSIDE TreeGroup
  right = AceGUI:Create("ScrollFrame")
  right:SetLayout("List")
  right:SetFullWidth(true)
  right:SetFullHeight(true)
  tree:AddChild(right)
  state.rightScroll = right

  if right.frame then
    SetBackdrop(right.frame, THEME.panel2, THEME.border, 1)
  end
  if right.scrollbar then
    StyleScrollbar(right.scrollbar)
  end

  RestoreWindow()
  ApplyTreeWidth(db.treewidth or 280)
  SyncContainerHeights()
  QueueResizeLayout()

  local function ShowModule(moduleKey)
    if not moduleKey then return end
    db.lastModule = moduleKey
    state.currentModuleKey = moduleKey
    local group = FindGroup(groups, moduleKey)
    state.currentModuleName = group and group.name or moduleKey
    local q = tostring(search:GetText() or "")
    db.search = q
    RenderOptions(right, groups, moduleKey, q, search)
    ApplyWindowStyle(win)
    SaveWindow()
  end

  -- Persist tree width when resized
  tree:SetCallback("OnTreeResize", function(_, _, width)
    ApplyTreeWidth(width)
    QueueResizeLayout()
  end)

  tree:SetCallback("OnGroupSelected", function(_, _, value)
    local leaf = ExtractLastToken(value)
    if not leaf or leaf == "" then return end

    if not FindGroup(groups, leaf) then
      right:ReleaseChildren()
      AddDesc(right, "Select a module on the left.", GameFontHighlight)
      return
    end

    ShowModule(leaf)
    StyleTreeButtons(tree)
  end)

  -- Search refresh (throttle)
  local function QueueRefresh()
    if state.searchTimer then return end
    state.searchTimer = NewDebounceTimer(0.12, function()
      state.searchTimer = nil
      if not state.win or not state.search then return end
      local q = tostring(search:GetText() or "")
      db.search = q
      local target = GetDefaultModuleKey(groups, db.lastModule)
      if target then
        ShowModule(target)
      end
    end)
  end

  search:SetCallback("OnTextChanged", function() QueueRefresh() end)

  -- Default selection
  if defaultModule then
    local cat = nil
    for _, g in ipairs(groups) do
      if g.key == defaultModule then
        cat = g.category
        if not cat or cat == "" or cat == "Other" then
          cat = KEY_TO_CATEGORY[g.key] or "Other"
        end
        break
      end
    end

    if cat then
      tree:SelectByPath(cat, defaultModule)
    else
      tree:SelectByValue(defaultModule)
    end

    ShowModule(defaultModule)
  else
    right:ReleaseChildren()
    AddDesc(right, "No settings groups are registered yet.", GameFontHighlight)
  end

  win.frame:HookScript("OnMouseUp", function() SaveWindow() end)
end

function ConfigWindow:Open()
  local _ = self
  if state.win and state.win.frame then
    state.win.frame:Show()
    return
  end

  BuildWindow()

  if state.win and state.win.frame then
    state.win.frame:Show()
  end
end

function ConfigWindow:Toggle()
  if state.win and state.win.frame then
    if state.win.frame:IsShown() then
      self:Close()
    else
      state.win.frame:Show()
    end
    return
  end
  self:Open()
end


H.state = state
H.BuildWindow = BuildWindow

if ETBC.ApplyBus and ETBC.ApplyBus.Register then
  ETBC.ApplyBus:Register("mover", function()
    if state and state.win then
      ApplyWindowStyle(state.win)
    end
  end)
end


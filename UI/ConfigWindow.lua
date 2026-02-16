-- UI/ConfigWindow.lua
-- EnhanceTBC - Custom config window that renders AceConfig-style options tables
-- using AceGUI widgets, with SettingsRegistry group tree + search.
--
-- IMPORTANT:
-- - This file supports AceConfig "info" paths (get/set/disabled/hidden/values/func)
-- - It also supports legacy tables where get/set expect the option table itself.
-- - Groups are sourced from ETBC.SettingsRegistry:GetGroups()

local ADDON_NAME, ETBC = ...
local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceTBC")
ETBC.UI = ETBC.UI or {}
local UI = ETBC.UI

local AceGUI = LibStub("AceGUI-3.0")

UI.ConfigWindow = UI.ConfigWindow or {}
local ConfigWindow = UI.ConfigWindow

-- ---------------------------------------------------------
-- Confirm popup for execute options
-- ---------------------------------------------------------
if not StaticPopupDialogs.ETBC_EXEC_CONFIRM then
  StaticPopupDialogs.ETBC_EXEC_CONFIRM = {
    text = "%s",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data)
      if data and type(data.exec) == "function" then
        pcall(data.exec)
      end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
  }
end

-- ---------------------------------------------------------
-- Assets
-- ---------------------------------------------------------
local LOGO_PATH = "Interface\\AddOns\\EnhanceTBC\\Media\\Images\\logo.tga"

-- ---------------------------------------------------------
-- Theme (TBC Anniversary dark green)
-- ---------------------------------------------------------
local THEME = {
  bg      = { 0.05, 0.07, 0.05, 0.98 },
  panel   = { 0.07, 0.09, 0.07, 0.95 },
  panel2  = { 0.06, 0.08, 0.06, 0.95 },
  border  = { 0.12, 0.20, 0.12, 0.95 },
  accent  = { 0.20, 1.00, 0.20, 1.00 },
  text    = { 0.90, 0.96, 0.90, 1.00 },
  muted   = { 0.70, 0.78, 0.70, 1.00 },
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

-- ---------------------------------------------------------
-- DB
-- ---------------------------------------------------------
local function GetUIDB()
  if not ETBC.db or not ETBC.db.profile then return nil end

  ETBC.db.profile.ui = ETBC.db.profile.ui or {}
  ETBC.db.profile.ui.config = ETBC.db.profile.ui.config or {}
  local db = ETBC.db.profile.ui.config

  if db.w == nil then db.w = 980 end
  if db.h == nil then db.h = 720 end

  if db.point == nil then
    db.point, db.rel, db.relPoint, db.x, db.y = "CENTER", "UIParent", "CENTER", 0, 0
  end

  if db.treewidth == nil then db.treewidth = 280 end
  if db.lastModule == nil then db.lastModule = "auras" end
  if db.search == nil then db.search = "" end

  -- ✅ don’t overwrite tree status table every time (keeps expand/collapse state)
  db.treeStatus = db.treeStatus or {}
  db.treeStatus.treewidth = db.treewidth or 280

  return db
end

-- ---------------------------------------------------------
-- SettingsRegistry access
-- ---------------------------------------------------------
local function GatherGroups()
  local out = {}
  local SR = ETBC.SettingsRegistry
  if not SR or type(SR.GetGroups) ~= "function" then return out end

  local groups = SR:GetGroups()
  if type(groups) ~= "table" then return out end

  for _, g in ipairs(groups) do
    if type(g) == "table" and g.key and g.name and g.options then
      table.insert(out, {
        key = tostring(g.key),
        name = tostring(g.name),
        order = tonumber(g.order) or 1000,
        category = g.category and tostring(g.category) or "Other",
        icon = g.icon,
        options = g.options,
      })
    end
  end

  table.sort(out, function(a, b)
    if a.order == b.order then return a.name < b.name end
    return a.order < b.order
  end)

  return out
end

local function FindGroup(groups, key)
  for _, g in ipairs(groups) do
    if g.key == key then return g end
  end
  return nil
end

-- ---------------------------------------------------------
-- Categories
-- ---------------------------------------------------------
local KEY_TO_CATEGORY = {
  general = "Core",
  ui = "Core",
  minimapplus = "Core",
  visibility = "Core",

  auras = "Combat",
  gcdbar = "Combat",
  combattext = "Combat",
  actiontracker = "Combat",
  castbar = "Combat",
  unitframes = "Combat",
  actionbars = "Combat",

  mouse = "Utility",
  tooltip = "Utility",
  sound = "Utility",
  vendor = "Utility",
  mailbox = "Utility",
  mover = "Utility",
  cvars = "Utility",

  chatim = "Social",
  friends = "Social",
  friendslistdecor = "Social",
}

local CATEGORY_ORDER = { "Core", "Combat", "Utility", "Social", "Other" }

local function BuildTree(groups)
  local buckets = {}
  for _, c in ipairs(CATEGORY_ORDER) do buckets[c] = {} end

  for _, g in ipairs(groups) do
    local cat = g.category
    if not cat or cat == "" or cat == "Other" then
      cat = KEY_TO_CATEGORY[g.key] or "Other"
    end
    if not buckets[cat] then buckets[cat] = {} end
    table.insert(buckets[cat], g)
  end

  local tree = {}
  for _, cat in ipairs(CATEGORY_ORDER) do
    local items = buckets[cat]
    if items and #items > 0 then
      local node = { value = cat, text = cat, children = {} }
      for _, gg in ipairs(items) do
        table.insert(node.children, {
          value = gg.key,
          text = gg.name,
          icon = gg.icon,
        })
      end
      table.insert(tree, node)
    end
  end

  return tree
end

-- ---------------------------------------------------------
-- Option rendering helpers (AceConfig "info" compat)
-- ---------------------------------------------------------
local function TextMatch(hay, needle)
  if not needle or needle == "" then return true end
  if not hay then return false end
  hay = tostring(hay):lower()
  needle = tostring(needle):lower()
  return hay:find(needle, 1, true) ~= nil
end

local function OptionMatchesSearch(opt, q)
  if not q or q == "" then return true end
  return TextMatch(opt.name, q) or TextMatch(opt.desc, q) or TextMatch(opt._id, q)
end

local function MakeInfo(pathStack, opt)
  local info = {}
  if type(pathStack) == "table" then
    for i = 1, #pathStack do
      info[i] = pathStack[i]
    end
  end
  info[#info + 1] = opt._id
  return info
end

local function IsHidden(opt, info)
  if type(opt.hidden) == "function" then
    local ok, v = pcall(opt.hidden, info)
    if ok then return v and true or false end
    return false
  end
  return opt.hidden and true or false
end

local function IsDisabled(opt, info)
  if type(opt.disabled) == "function" then
    local ok, v = pcall(opt.disabled, info)
    if ok then return v and true or false end
  end
  return opt.disabled and true or false
end

local function SafeGet(opt, info)
  if type(opt.get) == "function" then
    local ok, a, b, c, d = pcall(opt.get, info)
    if ok then return a, b, c, d end
    local ok2, a2, b2, c2, d2 = pcall(opt.get, opt)
    if ok2 then return a2, b2, c2, d2 end
  end
  return nil
end

local function SafeSet(opt, info, ...)
  if type(opt.set) == "function" then
    local ok = pcall(opt.set, info, ...)
    if ok then return end
    pcall(opt.set, opt, ...)
  end
end

local function SafeExec(opt, info)
  if type(opt.func) == "function" then
    local ok = pcall(opt.func, info)
    if ok then return end
    pcall(opt.func, opt)
  end
end

local function SafeValues(opt, info)
  local values = opt.values
  if type(values) == "function" then
    local ok, v = pcall(values, info)
    if ok then return v end
    local ok2, v2 = pcall(values, opt)
    if ok2 then return v2 end
    return {}
  end
  if type(values) == "table" then return values end
  return {}
end

-- ---------------------------------------------------------
-- Widget builders
-- ---------------------------------------------------------
local function AddHeading(container, text)
  local w = AceGUI:Create("Heading")
  w:SetText(text or "")
  w:SetFullWidth(true)
  container:AddChild(w)
end

local function AddDesc(container, text, fontObj)
  local w = AceGUI:Create("Label")
  w:SetText(text or "")
  w:SetFullWidth(true)
  if fontObj then w:SetFontObject(fontObj) end
  container:AddChild(w)
end

local function SetWidgetDescription(container, widget, text)
  if not text or text == "" then return end

  -- Some AceGUI widgets (notably Dropdown on some builds) don't implement SetDescription.
  if widget and type(widget.SetDescription) == "function" then
    widget:SetDescription(text)
  else
    AddDesc(container, text, GameFontHighlightSmall)
  end
end

local function AddToggle(container, opt, info)
  local w = AceGUI:Create("CheckBox")
  w:SetLabel(opt.name or opt._id or "")
  w:SetFullWidth(opt.width == "full")
  w:SetDisabled(IsDisabled(opt, info))

  local val = SafeGet(opt, info)
  w:SetValue(val and true or false)

  SetWidgetDescription(container, w, opt.desc)

  w:SetCallback("OnValueChanged", function(_, _, v)
    SafeSet(opt, info, v and true or false)
  end)

  container:AddChild(w)
end

local function AddRange(container, opt, info)
  local w = AceGUI:Create("Slider")
  w:SetLabel(opt.name or opt._id or "")
  w:SetFullWidth(true)
  w:SetDisabled(IsDisabled(opt, info))

  local min = tonumber(opt.min) or 0
  local max = tonumber(opt.max) or 100
  local step = tonumber(opt.step) or 1
  w:SetSliderValues(min, max, step)

  local val = SafeGet(opt, info)
  if type(val) ~= "number" then val = min end
  w:SetValue(val)

  SetWidgetDescription(container, w, opt.desc)

  w:SetCallback("OnValueChanged", function(_, _, v)
    SafeSet(opt, info, v)
  end)

  container:AddChild(w)
end

local function AddSelect(container, opt, info)
  local w = AceGUI:Create("Dropdown")
  w:SetLabel(opt.name or opt._id or "")
  w:SetFullWidth(true)
  w:SetDisabled(IsDisabled(opt, info))

  local values = SafeValues(opt, info)
  if type(values) ~= "table" then values = {} end
  w:SetList(values)

  local val = SafeGet(opt, info)
  w:SetValue(val)

  SetWidgetDescription(container, w, opt.desc)

  w:SetCallback("OnValueChanged", function(_, _, v)
    SafeSet(opt, info, v)
  end)

  container:AddChild(w)
end

local function AddColor(container, opt, info)
  local w = AceGUI:Create("ColorPicker")
  w:SetLabel(opt.name or opt._id or "")
  w:SetFullWidth(true)
  w:SetDisabled(IsDisabled(opt, info))

  local r, g, b, a = SafeGet(opt, info)
  if type(r) ~= "number" then r, g, b, a = 1, 1, 1, 1 end

  w:SetHasAlpha(opt.hasAlpha and true or false)
  w:SetColor(r, g, b, a)

  SetWidgetDescription(container, w, opt.desc)

  w:SetCallback("OnValueConfirmed", function(_, _, nr, ng, nb, na)
    if opt.hasAlpha then
      SafeSet(opt, info, nr, ng, nb, na)
    else
      SafeSet(opt, info, nr, ng, nb)
    end
  end)

  container:AddChild(w)
end

local function AddExecute(container, opt, info)
  if opt.desc and opt.desc ~= "" then
    AddDesc(container, opt.desc, GameFontHighlightSmall)
  end

  local w = AceGUI:Create("Button")
  w:SetText(opt.name or opt._id or "Run")
  w:SetFullWidth(opt.width == "full")
  w:SetDisabled(IsDisabled(opt, info))

  w:SetCallback("OnClick", function()
    if IsDisabled(opt, info) then return end

    if opt.confirm then
      local msg = opt.confirmText or "Are you sure?"
      StaticPopup_Show("ETBC_EXEC_CONFIRM", msg, nil, {
        exec = function() SafeExec(opt, info) end
      })
    else
      SafeExec(opt, info)
    end
  end)

  container:AddChild(w)
end

-- ---------------------------------------------------------
-- Recursive renderer
-- ---------------------------------------------------------
local function NormalizeArgs(argsTable)
  local list = {}
  if type(argsTable) ~= "table" then return list end

  for id, opt in pairs(argsTable) do
    if type(opt) == "table" and opt.type then
      opt._id = id
      table.insert(list, opt)
    end
  end

  table.sort(list, function(a, b)
    local oa = tonumber(a.order) or 1000
    local ob = tonumber(b.order) or 1000
    if oa == ob then
      return tostring(a.name or a._id) < tostring(b.name or b._id)
    end
    return oa < ob
  end)

  return list
end

local function AnyMatchInGroup(groupOpt, q, pathStack)
  if not q or q == "" then return true end
  if OptionMatchesSearch(groupOpt, q) then return true end
  if type(groupOpt.args) ~= "table" then return false end

  local list = NormalizeArgs(groupOpt.args)
  for _, child in ipairs(list) do
    local info = MakeInfo(pathStack, child)
    if not IsHidden(child, info) then
      if child.type == "group" then
        local nextPath = { unpack(pathStack or {}) }
        nextPath[#nextPath + 1] = child._id
        if AnyMatchInGroup(child, q, nextPath) then return true end
      else
        if OptionMatchesSearch(child, q) then return true end
      end
    end
  end

  return false
end

local function RenderArgsRecursive(container, args, q, pathStack)
  local list = NormalizeArgs(args)
  for _, opt in ipairs(list) do
    local info = MakeInfo(pathStack, opt)
    if not IsHidden(opt, info) then
      if opt.type == "group" then
        local nextPath = { unpack(pathStack or {}) }
        nextPath[#nextPath + 1] = opt._id

        if AnyMatchInGroup(opt, q, nextPath) then
          if opt.inline then
            local grp = AceGUI:Create("InlineGroup")
            grp:SetTitle(opt.name or "")
            grp:SetFullWidth(true)
            grp:SetLayout("List")
            container:AddChild(grp)

            if opt.desc and opt.desc ~= "" then
              AddDesc(grp, opt.desc, GameFontHighlightSmall)
            end

            if type(opt.args) == "table" then
              RenderArgsRecursive(grp, opt.args, q, nextPath)
            end
          else
            AddHeading(container, opt.name or "")
            if opt.desc and opt.desc ~= "" then
              AddDesc(container, opt.desc, GameFontHighlightSmall)
            end
            if type(opt.args) == "table" then
              RenderArgsRecursive(container, opt.args, q, nextPath)
            end
          end
        end
      else
        if OptionMatchesSearch(opt, q) then
          if opt.type == "header" then
            AddHeading(container, opt.name or "")
          elseif opt.type == "description" then
            AddDesc(container, opt.name or "", GameFontHighlightSmall)
          elseif opt.type == "toggle" then
            AddToggle(container, opt, info)
          elseif opt.type == "range" then
            AddRange(container, opt, info)
          elseif opt.type == "select" then
            AddSelect(container, opt, info)
          elseif opt.type == "color" then
            AddColor(container, opt, info)
          elseif opt.type == "execute" then
            AddExecute(container, opt, info)
          end
        end
      end
    end
  end
end

local function RenderOptions(scroll, groups, moduleKey, searchText)
  if not scroll then return end
  scroll:ReleaseChildren()

  local g = FindGroup(groups, moduleKey)
  if not g then
    AddDesc(scroll, "Select a module on the left.", GameFontHighlight)
    return
  end

  local ok, opts = pcall(g.options)
  if not ok or type(opts) ~= "table" then
    AddDesc(scroll, "Options failed to build for: " .. tostring(g.name), GameFontHighlight)
    return
  end

  local q = tostring(searchText or "")
  AddHeading(scroll, g.name)

  -- ✅ ensure we pass an args table
  local args = (opts.type == "group" and opts.args) or opts.args or opts
  if type(args) ~= "table" then args = {} end

  RenderArgsRecursive(scroll, args, q, { moduleKey })
end

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
  closing = false,
}

local function ApplyWindowStyle(win)
  if not win or not win.frame then return end

  SetBackdrop(win.frame, THEME.bg, THEME.border, 1)

  if win.titletext then
    win.titletext:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3])
  end
  if win.statustext then
    win.statustext:SetTextColor(THEME.muted[1], THEME.muted[2], THEME.muted[3])
  end

  -- Logo (DO NOT CHANGE SIZE)
  if not win.frame._etbcLogo then
    local logo = win.frame:CreateTexture(nil, "OVERLAY")
    logo:SetTexture(LOGO_PATH)
    logo:SetPoint("TOPLEFT", win.frame, "TOPLEFT", 14, -6)
    logo:SetSize(90, 90)
    logo:SetAlpha(0.9)
    win.frame._etbcLogo = logo
  end

  -- Move AceGUI content DOWN under logo, but extend closer to bottom for TBC UI
  if win.content then
    win.content:ClearAllPoints()
    win.content:SetPoint("TOPLEFT", win.frame, "TOPLEFT", 12, -100)
    win.content:SetPoint("BOTTOMRIGHT", win.frame, "BOTTOMRIGHT", -12, 12)  -- Much closer to bottom for maximum space
  end

  -- Styled inner background aligned with content
  if not win.frame._etbcInner then
    -- ✅ always use BackdropTemplate when available; safe in Classic-era clients
    local inner = CreateFrame("Frame", nil, win.frame, "BackdropTemplate")
    inner:SetPoint("TOPLEFT", win.content, "TOPLEFT", -6, 6)
    inner:SetPoint("BOTTOMRIGHT", win.content, "BOTTOMRIGHT", 6, -6)

    SetBackdrop(inner, THEME.panel, THEME.border, 1)

    local topLine = inner:CreateTexture(nil, "BORDER")
    topLine:SetTexture("Interface\\Buttons\\WHITE8x8")
    topLine:SetPoint("TOPLEFT", inner, "TOPLEFT", 1, -1)
    topLine:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -1, -1)
    topLine:SetHeight(2)
    topLine:SetVertexColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.55)

    win.frame._etbcInner = inner
  end

  -- Update inner frame positions on resize
  if win.frame._etbcInner then
    win.frame._etbcInner:ClearAllPoints()
    win.frame._etbcInner:SetPoint("TOPLEFT", win.content, "TOPLEFT", -6, 6)
    win.frame._etbcInner:SetPoint("BOTTOMRIGHT", win.content, "BOTTOMRIGHT", 6, -6)
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

function ConfigWindow:Close()
  if state.closing then return end
  if not state.win then return end
  state.closing = true

  SaveWindow()

  if state.searchTimer and state.searchTimer.Cancel then
    state.searchTimer:Cancel()
  end

  local w = state.win
  state.win, state.groups, state.tree, state.rightScroll, state.search, state.searchTimer = nil, nil, nil, nil, nil, nil

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
  win:SetStatusText("TBC Anniversary UI • Live settings • /etbc")
  win:SetLayout("Fill")
  win:SetWidth(db.w or 980)
  win:SetHeight(db.h or 720)
  win:EnableResize(true)
  win.frame:SetFrameStrata("DIALOG")
  win.frame:SetClampedToScreen(true)

  ApplyWindowStyle(win)

  win:SetCallback("OnClose", function()
    ConfigWindow:Close()
  end)

  -- Handle window resize dynamically
  win.frame:HookScript("OnSizeChanged", function()
    if state.tree and state.tree.content then
      state.tree.content:DoLayout()
    end
    if state.rightScroll and state.rightScroll.content then
      state.rightScroll.content:DoLayout()
    end
    ApplyWindowStyle(win)
  end)

  state.win = win

  -- Root: Fill -> vertical group inside
  local root = AceGUI:Create("SimpleGroup")
  root:SetFullWidth(true)
  root:SetFullHeight(true)
  root:SetLayout("List")
  win:AddChild(root)

  local search = AceGUI:Create("EditBox")
  search:SetLabel("Search")
  search:SetFullWidth(true)
  search:DisableButton(true)
  root:AddChild(search)
  state.search = search

  -- Green glow when focused
  if search.editbox and search.editbox.SetBackdropBorderColor then
    search.editbox:HookScript("OnEditFocusGained", function(self)
      self:SetBackdropBorderColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 1)
    end)
    search.editbox:HookScript("OnEditFocusLost", function(self)
      self:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 1)
    end)
  end

  -- TreeGroup handles BOTH columns
  local tree = AceGUI:Create("TreeGroup")
  tree:SetFullWidth(true)
  tree:SetFullHeight(true)
  tree:SetLayout("Fill")
  tree:SetTree(BuildTree(groups))
  tree:SetStatusTable(db.treeStatus)
  root:AddChild(tree)
  state.tree = tree

  -- Ensure tree frame extends properly
  if tree.treeframe then
    tree.treeframe:SetAllPoints(tree.treeframe:GetParent())
  end
  if tree.content then
    tree.content:ClearAllPoints()
    tree.content:SetPoint("TOPLEFT", tree.border, "TOPLEFT", 0, 0)
    tree.content:SetPoint("BOTTOMRIGHT", tree.border, "BOTTOMRIGHT", 0, 0)
  end

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
  local right = AceGUI:Create("ScrollFrame")
  right:SetLayout("List")
  right:SetFullWidth(true)
  right:SetFullHeight(true)
  tree:AddChild(right)
  state.rightScroll = right

  -- Ensure scroll frame fills the content area properly
  if right.scrollframe then
    right.scrollframe:SetAllPoints(right.content:GetParent())
  end
  if right.content then
    right.content:ClearAllPoints()
    right.content:SetPoint("TOPLEFT", right.scrollframe, "TOPLEFT", 0, 0)
    right.content:SetPoint("TOPRIGHT", right.scrollframe, "TOPRIGHT", -20, 0)  -- Account for scrollbar
  end

  RestoreWindow()

  local function ShowModule(moduleKey)
    if not moduleKey then return end
    db.lastModule = moduleKey
    local q = tostring(search:GetText() or "")
    db.search = q
    RenderOptions(right, groups, moduleKey, q)
    SaveWindow()
  end

  -- Persist tree width when resized
  tree:SetCallback("OnTreeResize", function(_, _, width)
    db.treewidth = width
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

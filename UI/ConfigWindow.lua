-- UI/ConfigWindow.lua

local ADDON_NAME, ETBC = ...

ETBC.UI = ETBC.UI or {}
local UI = ETBC.UI

local AceGUI = LibStub("AceGUI-3.0")

UI.ConfigWindow = UI.ConfigWindow or {}
local ConfigWindow = UI.ConfigWindow

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
  if not frame or not frame.SetBackdrop then return end
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
  if db.h == nil then db.h = 680 end

  if db.point == nil then
    db.point, db.rel, db.relPoint, db.x, db.y = "CENTER", "UIParent", "CENTER", 0, 0
  end

  if db.treewidth == nil then db.treewidth = 280 end
  if db.lastModule == nil then db.lastModule = "auras" end
  if db.search == nil then db.search = "" end

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
  minimap = "Core",
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
          value = gg.key,        -- IMPORTANT: leaf value is module key only
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
-- Option rendering (recursive)
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

local function SafeGet(opt)
  if type(opt.get) == "function" then
    local ok, a, b, c, d = pcall(opt.get, opt)
    if ok then return a, b, c, d end
  end
  return nil
end

local function SafeSet(opt, ...)
  if type(opt.set) == "function" then
    pcall(opt.set, opt, ...)
  end
end

local function IsDisabled(opt)
  if type(opt.disabled) == "function" then
    local ok, v = pcall(opt.disabled, opt)
    if ok then return v and true or false end
  end
  return opt.disabled and true or false
end

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

local function AddToggle(container, opt)
  local w = AceGUI:Create("CheckBox")
  w:SetLabel(opt.name or opt._id or "")
  w:SetFullWidth(opt.width == "full")
  w:SetDisabled(IsDisabled(opt))

  local val = SafeGet(opt)
  w:SetValue(val and true or false)

  if opt.desc and opt.desc ~= "" then w:SetDescription(opt.desc) end

  w:SetCallback("OnValueChanged", function(_, _, v)
    SafeSet(opt, v and true or false)
  end)

  container:AddChild(w)
end

local function AddRange(container, opt)
  local w = AceGUI:Create("Slider")
  w:SetLabel(opt.name or opt._id or "")
  w:SetFullWidth(true)
  w:SetDisabled(IsDisabled(opt))

  local min = tonumber(opt.min) or 0
  local max = tonumber(opt.max) or 100
  local step = tonumber(opt.step) or 1
  w:SetSliderValues(min, max, step)

  local val = SafeGet(opt)
  if type(val) ~= "number" then val = min end
  w:SetValue(val)

  if opt.desc and opt.desc ~= "" then w:SetDescription(opt.desc) end

  w:SetCallback("OnValueChanged", function(_, _, v)
    SafeSet(opt, v)
  end)

  container:AddChild(w)
end

local function AddSelect(container, opt)
  local w = AceGUI:Create("Dropdown")
  w:SetLabel(opt.name or opt._id or "")
  w:SetFullWidth(true)
  w:SetDisabled(IsDisabled(opt))

  local values = opt.values
  if type(values) == "function" then
    local ok, v = pcall(values, opt)
    if ok then values = v end
  end
  if type(values) ~= "table" then values = {} end

  w:SetList(values)

  local val = SafeGet(opt)
  w:SetValue(val)

  if opt.desc and opt.desc ~= "" then w:SetDescription(opt.desc) end

  w:SetCallback("OnValueChanged", function(_, _, v)
    SafeSet(opt, v)
  end)

  container:AddChild(w)
end

local function AddColor(container, opt)
  local w = AceGUI:Create("ColorPicker")
  w:SetLabel(opt.name or opt._id or "")
  w:SetFullWidth(true)
  w:SetDisabled(IsDisabled(opt))

  local r, g, b, a = SafeGet(opt)
  if type(r) ~= "number" then r, g, b, a = 1, 1, 1, 1 end

  w:SetHasAlpha(opt.hasAlpha and true or false)
  w:SetColor(r, g, b, a)

  if opt.desc and opt.desc ~= "" then w:SetDescription(opt.desc) end

  w:SetCallback("OnValueConfirmed", function(_, _, nr, ng, nb, na)
    if opt.hasAlpha then
      SafeSet(opt, nr, ng, nb, na)
    else
      SafeSet(opt, nr, ng, nb)
    end
  end)

  container:AddChild(w)
end

local function AnyMatchInGroup(groupOpt, q)
  if not q or q == "" then return true end
  if OptionMatchesSearch(groupOpt, q) then return true end
  if type(groupOpt.args) ~= "table" then return false end

  for _, child in ipairs(NormalizeArgs(groupOpt.args)) do
    if child.type == "group" then
      if AnyMatchInGroup(child, q) then return true end
    else
      if OptionMatchesSearch(child, q) then return true end
    end
  end
  return false
end

local function RenderArgsRecursive(container, args, q)
  local list = NormalizeArgs(args)
  for _, opt in ipairs(list) do
    if opt.type == "group" then
      if AnyMatchInGroup(opt, q) then
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
            RenderArgsRecursive(grp, opt.args, q)
          end
        else
          AddHeading(container, opt.name or "")
          if opt.desc and opt.desc ~= "" then
            AddDesc(container, opt.desc, GameFontHighlightSmall)
          end
          if type(opt.args) == "table" then
            RenderArgsRecursive(container, opt.args, q)
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
          AddToggle(container, opt)
        elseif opt.type == "range" then
          AddRange(container, opt)
        elseif opt.type == "select" then
          AddSelect(container, opt)
        elseif opt.type == "color" then
          AddColor(container, opt)
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

  local args = opts.args or opts
  RenderArgsRecursive(scroll, args, q)
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

  -- Create a styled inner frame area (so the UI doesn’t look like default AceGUI)
  if not win.frame._etbcInner then
    local inner = CreateFrame("Frame", nil, win.frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    inner:SetPoint("TOPLEFT", win.frame, "TOPLEFT", 10, -32)
    inner:SetPoint("BOTTOMRIGHT", win.frame, "BOTTOMRIGHT", -10, 10)
    SetBackdrop(inner, THEME.panel, THEME.border, 1)

    local topLine = inner:CreateTexture(nil, "BORDER")
    topLine:SetTexture("Interface\\Buttons\\WHITE8x8")
    topLine:SetPoint("TOPLEFT", inner, "TOPLEFT", 1, -1)
    topLine:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -1, -1)
    topLine:SetHeight(2)
    topLine:SetVertexColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.55)

    win.frame._etbcInner = inner
  end

  -- Logo in the title bar, properly sized (not squished)
  if not win.frame._etbcLogo then
    local logo = win.frame:CreateTexture(nil, "OVERLAY")
    logo:SetTexture(LOGO_PATH)
    logo:SetPoint("TOPLEFT", win.frame, "TOPLEFT", 14, -6)
    logo:SetSize(160, 32)   -- more room, less squish
    logo:SetAlpha(0.9)
    win.frame._etbcLogo = logo
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
  state.win:SetHeight(db.h or 680)

  state.win.frame:ClearAllPoints()
  state.win.frame:SetPoint(db.point or "CENTER", _G[db.rel or "UIParent"] or UIParent, db.relPoint or "CENTER", db.x or 0, db.y or 0)

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
  -- AceGUI TreeGroup returns "cat\001module\001sub" sometimes. We only care about the last leaf.
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
  function timer:Cancel()
    self._cancelled = true
  end
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
  win:SetHeight(db.h or 680)
  win:EnableResize(true)
  win.frame:SetFrameStrata("DIALOG")
  win.frame:SetClampedToScreen(true)

  ApplyWindowStyle(win)

  win:SetCallback("OnClose", function()
    ConfigWindow:Close()
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

  -- Body must FILL so scroll frame has actual height
  local body = AceGUI:Create("SimpleGroup")
  body:SetFullWidth(true)
  body:SetFullHeight(true)
  body:SetLayout("Flow")
  root:AddChild(body)

  local tree = AceGUI:Create("TreeGroup")
  tree:SetWidth(db.treewidth or 280)
  tree:SetFullHeight(true)
  tree:SetLayout("Fill")
  tree:SetTree(BuildTree(groups))
  body:AddChild(tree)
  state.tree = tree

  -- Right options scroll, must fill
  local rightWrap = AceGUI:Create("SimpleGroup")
  rightWrap:SetFullWidth(true)
  rightWrap:SetFullHeight(true)
  rightWrap:SetLayout("Fill")
  body:AddChild(rightWrap)

  local right = AceGUI:Create("ScrollFrame")
  right:SetLayout("List")
  rightWrap:AddChild(right)
  state.rightScroll = right

  RestoreWindow()

  local function ShowModule(moduleKey)
    if not moduleKey then return end
    db.lastModule = moduleKey
    local q = tostring(search:GetText() or "")
    db.search = q
    RenderOptions(right, groups, moduleKey, q)
    SaveWindow()
  end

  tree:SetCallback("OnGroupSelected", function(_, _, value)
    -- value is a PATH like "Core\001auras"
    local leaf = ExtractLastToken(value)
    if not leaf or leaf == "" then return end

    -- If leaf is a category (no module), show help
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
    state.searchTimer = C_Timer.NewTimer(0.12, function()
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
    tree:SelectByValue(defaultModule)          -- Select by LEAF value; TreeGroup will resolve it under its parent.
    ShowModule(defaultModule)
  else
    right:ReleaseChildren()
    AddDesc(right, "No settings groups are registered yet.", GameFontHighlight)
  end

  win.frame:HookScript("OnMouseUp", function() SaveWindow() end)
end

function ConfigWindow:Open()
  BuildWindow()
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

-- UI/ConfigWindow.lua
-- EnhanceTBC - Custom config window that renders AceConfig-style options tables
-- using AceGUI widgets, with SettingsRegistry group tree + search.
--
-- IMPORTANT:
-- - This file supports AceConfig "info" paths (get/set/disabled/hidden/values/func)
-- - It also supports legacy tables where get/set expect the option table itself.
-- - Groups are sourced from ETBC.SettingsRegistry:GetGroups()

local _, ETBC = ...
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
    OnAccept = function(_, data)
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
  panel3  = { 0.04, 0.06, 0.04, 0.96 },
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

local function SetTextColor(fs, col)
  if fs and fs.SetTextColor and col then
    fs:SetTextColor(col[1], col[2], col[3], col[4] or 1)
  end
end

local function GetUIFont()
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
    pcall(fs.SetFont, fs, GetUIFont(), size or 12, flags)
  end
end

local function StyleHeadingWidget(w)
  if not w then return end
  if w.text then
    SetTextColor(w.text, THEME.text)
    TrySetFont(w.text, 13, "OUTLINE")
  end
  if w.line and w.line.SetColorTexture then
    w.line:SetColorTexture(THEME.border[1], THEME.border[2], THEME.border[3], 0.7)
  end
end

local function StyleLabelWidget(w, muted)
  if not w then return end
  if w.label then
    SetTextColor(w.label, muted and THEME.muted or THEME.text)
    TrySetFont(w.label, muted and 11 or 12, nil)
  end
end

local function StyleCheckBoxWidget(w)
  if not w then return end
  if w.text then
    SetTextColor(w.text, THEME.text)
    TrySetFont(w.text, 12, nil)
  end
  if w.label then
    SetTextColor(w.label, THEME.muted)
    TrySetFont(w.label, 11, nil)
  end
  if w.check then
    w.check:SetVertexColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 1)
  end
  if w.checkbg then
    w.checkbg:SetVertexColor(0.86, 0.90, 0.86, 1)
  end
  if w.highlight then
    w.highlight:SetVertexColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.65)
  end
end

local function StyleButtonWidget(w)
  if not w or not w.frame then return end
  SetBackdrop(w.frame, THEME.panel2, THEME.border, 1)

  if w.text then
    SetTextColor(w.text, THEME.text)
    TrySetFont(w.text, 12, "OUTLINE")
  end

  if not w.frame._etbcHoverHooked and w.frame.HookScript then
    w.frame._etbcHoverHooked = true
    w.frame:HookScript("OnEnter", function(self)
      SetBackdrop(self, THEME.panel2, THEME.accent, 1)
    end)
    w.frame:HookScript("OnLeave", function(self)
      SetBackdrop(self, THEME.panel2, THEME.border, 1)
    end)
  end
end

local function StyleSliderWidget(w)
  if not w then return end
  if w.label then
    SetTextColor(w.label, THEME.text)
    TrySetFont(w.label, 12, nil)
  end
  if w.lowtext then SetTextColor(w.lowtext, THEME.muted) end
  if w.hightext then SetTextColor(w.hightext, THEME.muted) end

  if w.editbox and w.editbox.SetTextColor then
    w.editbox:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], THEME.text[4])
    TrySetFont(w.editbox, 12, nil)
    SetBackdrop(w.editbox, THEME.bg, THEME.border, 1)
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

local function StyleDropdownWidget(w)
  if not w then return end
  if w.label then
    SetTextColor(w.label, THEME.text)
    TrySetFont(w.label, 12, nil)
  end
  if w.frame then
    SetBackdrop(w.frame, THEME.panel2, THEME.border, 1)
  end
end

local function StyleEditBoxWidget(w)
  if not w then return end
  if w.label then
    SetTextColor(w.label, THEME.text)
    TrySetFont(w.label, 12, nil)
  end
  if w.editbox then
    SetBackdrop(w.editbox, THEME.bg, THEME.border, 1)
    if w.editbox.SetTextColor then
      w.editbox:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], THEME.text[4])
    end
    TrySetFont(w.editbox, 12, nil)
  end
end

local function StyleColorWidget(w)
  if not w then return end
  if w.label then
    SetTextColor(w.label, THEME.text)
    TrySetFont(w.label, 12, nil)
  end
end

local function StyleInlineGroup(w)
  if not w or not w.frame then return end
  SetBackdrop(w.frame, THEME.panel2, THEME.border, 1)
  if w.titletext then
    SetTextColor(w.titletext, THEME.text)
    TrySetFont(w.titletext, 12, "OUTLINE")
  end
end

local function HasWidget(typeName)
  if not AceGUI or not AceGUI.GetWidgetVersion then return false end
  local ok, ver = pcall(AceGUI.GetWidgetVersion, AceGUI, typeName)
  return ok and type(ver) == "number" and ver > 0
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

  -- Don't overwrite tree status table every time (keeps expand/collapse state).
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

  tooltip = "Utility",
  sound = "Utility",
  vendor = "Utility",
  mailbox = "Utility",
  mover = "Utility",
  cvars = "Utility",
  cooldowns = "Utility",
  objectives = "Utility",
  autogossip = "Utility",

  chatim = "Social",
  friends = "Social",
}

local CATEGORY_ORDER = { "Core", "Combat", "Utility", "Social", "Other" }
local CATEGORY_INDEX = {}
for i = 1, #CATEGORY_ORDER do
  CATEGORY_INDEX[CATEGORY_ORDER[i]] = i
end

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
  local orderedCats = {}
  for _, cat in ipairs(CATEGORY_ORDER) do
    orderedCats[#orderedCats + 1] = cat
  end

  local extras = {}
  for cat, items in pairs(buckets) do
    if items and #items > 0 and not CATEGORY_INDEX[cat] then
      extras[#extras + 1] = cat
    end
  end
  table.sort(extras)
  for i = 1, #extras do
    orderedCats[#orderedCats + 1] = extras[i]
  end

  for _, cat in ipairs(orderedCats) do
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
local function TextMatch(hay, needleLower)
  if not needleLower or needleLower == "" then return true end
  if not hay then return false end
  hay = tostring(hay):lower()
  return hay:find(needleLower, 1, true) ~= nil
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

local function ResolveText(value, info, optFallback)
  if type(value) == "function" then
    local ok, out = pcall(value, info)
    if not ok then
      ok, out = pcall(value, optFallback)
    end
    if not ok then
      return ""
    end
    if out == nil then return "" end
    return tostring(out)
  end
  if value == nil then return "" end
  return tostring(value)
end

-- ---------------------------------------------------------
-- Widget builders
-- ---------------------------------------------------------
local function AddHeading(container, text)
  local w = AceGUI:Create("Heading")
  w:SetText(ResolveText(text))
  w:SetFullWidth(true)
  StyleHeadingWidget(w)
  container:AddChild(w)
end

local function AddDesc(container, text, fontObj)
  local w = AceGUI:Create("Label")
  w:SetText(ResolveText(text))
  w:SetFullWidth(true)
  if fontObj then w:SetFontObject(fontObj) end
  StyleLabelWidget(w, true)
  container:AddChild(w)
end

local function AddSpacer(container, height)
  local w = AceGUI:Create("Label")
  w:SetText(" ")
  w:SetFullWidth(true)
  if w.SetHeight then
    w:SetHeight(tonumber(height) or 6)
  end
  container:AddChild(w)
end

local function AddSeparator(container, alpha)
  local grp = AceGUI:Create("SimpleGroup")
  grp:SetFullWidth(true)
  grp:SetLayout("Fill")
  if grp.SetHeight then
    grp:SetHeight(6)
  end
  container:AddChild(grp)

  if grp.content then
    local line = grp.content:CreateTexture(nil, "BORDER")
    line:SetTexture("Interface\\Buttons\\WHITE8x8")
    line:SetPoint("LEFT", grp.content, "LEFT", 0, 0)
    line:SetPoint("RIGHT", grp.content, "RIGHT", 0, 0)
    line:SetPoint("CENTER", grp.content, "CENTER", 0, 0)
    line:SetHeight(1)
    line:SetVertexColor(THEME.border[1], THEME.border[2], THEME.border[3], alpha or 0.55)
  end
end

local function SetWidgetDescription(container, widget, text)
  local resolved = ResolveText(text)
  if resolved == "" then return end

  -- Some AceGUI widgets (notably Dropdown on some builds) don't implement SetDescription.
  if widget and type(widget.SetDescription) == "function" then
    widget:SetDescription(resolved)
  else
    AddDesc(container, resolved, GameFontHighlightSmall)
  end
end

local function AddToggle(container, opt, info)
  local w = AceGUI:Create("CheckBox")
  w:SetLabel(ResolveText(opt.name, info, opt) ~= "" and ResolveText(opt.name, info, opt) or tostring(opt._id or ""))
  w:SetFullWidth(opt.width == "full")
  w:SetDisabled(IsDisabled(opt, info))

  local val = SafeGet(opt, info)
  w:SetValue(val and true or false)
  StyleCheckBoxWidget(w)

  SetWidgetDescription(container, w, opt.desc)

  w:SetCallback("OnValueChanged", function(_, _, v)
    SafeSet(opt, info, v and true or false)
  end)

  container:AddChild(w)
end

local function AddRange(container, opt, info)
  local w = AceGUI:Create("Slider")
  w:SetLabel(ResolveText(opt.name, info, opt) ~= "" and ResolveText(opt.name, info, opt) or tostring(opt._id or ""))
  w:SetFullWidth(true)
  w:SetDisabled(IsDisabled(opt, info))

  local min = tonumber(opt.min) or 0
  local max = tonumber(opt.max) or 100
  local step = tonumber(opt.step) or 1
  w:SetSliderValues(min, max, step)

  local val = SafeGet(opt, info)
  if type(val) ~= "number" then val = min end
  w:SetValue(val)
  StyleSliderWidget(w)

  SetWidgetDescription(container, w, opt.desc)

  w:SetCallback("OnValueChanged", function(_, _, v)
    SafeSet(opt, info, v)
  end)

  container:AddChild(w)
end

local function AddSelect(container, opt, info)
  local w = AceGUI:Create("Dropdown")
  w:SetLabel(ResolveText(opt.name, info, opt) ~= "" and ResolveText(opt.name, info, opt) or tostring(opt._id or ""))
  w:SetFullWidth(true)
  w:SetDisabled(IsDisabled(opt, info))

  local values = SafeValues(opt, info)
  if type(values) ~= "table" then values = {} end
  w:SetList(values)

  local val = SafeGet(opt, info)
  w:SetValue(val)
  StyleDropdownWidget(w)

  SetWidgetDescription(container, w, opt.desc)

  w:SetCallback("OnValueChanged", function(_, _, v)
    SafeSet(opt, info, v)
  end)

  container:AddChild(w)
end

local function AddColor(container, opt, info)
  local w = AceGUI:Create("ColorPicker")
  w:SetLabel(ResolveText(opt.name, info, opt) ~= "" and ResolveText(opt.name, info, opt) or tostring(opt._id or ""))
  w:SetFullWidth(true)
  w:SetDisabled(IsDisabled(opt, info))

  local r, g, b, a = SafeGet(opt, info)
  if type(r) ~= "number" then r, g, b, a = 1, 1, 1, 1 end

  w:SetHasAlpha(opt.hasAlpha and true or false)
  w:SetColor(r, g, b, a)
  StyleColorWidget(w)

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
  local btnText = ResolveText(opt.name, info, opt)
  if btnText == "" then btnText = tostring(opt._id or "Run") end
  w:SetText(btnText)
  w:SetFullWidth(opt.width == "full")
  w:SetDisabled(IsDisabled(opt, info))
  StyleButtonWidget(w)

  w:SetCallback("OnClick", function()
    if IsDisabled(opt, info) then return end

    if opt.confirm then
      local msg = ResolveText(opt.confirmText, info, opt)
      if msg == "" then msg = "Are you sure?" end
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
local function NormalizeArgs(argsTable, cache)
  local list = {}
  if type(argsTable) ~= "table" then return list end
  if cache and cache[argsTable] then
    return cache[argsTable]
  end

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

  if cache then
    cache[argsTable] = list
  end
  return list
end

local function AnyMatchInGroup(groupOpt, q, pathStack, normalizeCache)
  if not q or q == "" then return true end
  if OptionMatchesSearch(groupOpt, q) then return true end
  if type(groupOpt.args) ~= "table" then return false end

  local list = NormalizeArgs(groupOpt.args, normalizeCache)
  for _, child in ipairs(list) do
    local info = MakeInfo(pathStack, child)
    if not IsHidden(child, info) then
      if child.type == "group" then
        local nextPath = { unpack(pathStack or {}) }
        nextPath[#nextPath + 1] = child._id
        if AnyMatchInGroup(child, q, nextPath, normalizeCache) then return true end
      else
        if OptionMatchesSearch(child, q) then return true end
      end
    end
  end

  return false
end

local function CountMatchesInGroup(groupOpt, q, pathStack, normalizeCache)
  if type(groupOpt) ~= "table" or type(groupOpt.args) ~= "table" then return 0 end
  local count = 0
  local list = NormalizeArgs(groupOpt.args, normalizeCache)
  for _, child in ipairs(list) do
    local info = MakeInfo(pathStack, child)
    if not IsHidden(child, info) then
      if child.type == "group" then
        local nextPath = { unpack(pathStack or {}) }
        nextPath[#nextPath + 1] = child._id
        count = count + CountMatchesInGroup(child, q, nextPath, normalizeCache)
      else
        if OptionMatchesSearch(child, q) then
          count = count + 1
        end
      end
    end
  end
  return count
end

local function RenderArgsRecursive(container, args, q, pathStack, normalizeCache)
  local list = NormalizeArgs(args, normalizeCache)
  for _, opt in ipairs(list) do
    local info = MakeInfo(pathStack, opt)
    if not IsHidden(opt, info) then
      if opt.type == "group" then
        local nextPath = { unpack(pathStack or {}) }
        nextPath[#nextPath + 1] = opt._id

        if AnyMatchInGroup(opt, q, nextPath, normalizeCache) then
          if opt.inline then
            local useSectionCard = HasWidget("ETBC_SectionCard")
            local grpType = useSectionCard and "ETBC_SectionCard" or "InlineGroup"
            local grp = AceGUI:Create(grpType)
            if grp.SetTitle then
              grp:SetTitle(ResolveText(opt.name, info, opt))
            end
            if useSectionCard and grp.SetDescription and opt.desc and opt.desc ~= "" then
              grp:SetDescription(ResolveText(opt.desc, info, opt))
            end
            grp:SetFullWidth(true)
            grp:SetLayout("List")
            if not useSectionCard then
              StyleInlineGroup(grp)
            end
            container:AddChild(grp)

            if (not useSectionCard) and opt.desc and opt.desc ~= "" then
              AddDesc(grp, opt.desc, GameFontHighlightSmall)
            end

            if type(opt.args) == "table" then
              RenderArgsRecursive(grp, opt.args, q, nextPath, normalizeCache)
            end
            AddSpacer(container, 8)
          else
            AddHeading(container, ResolveText(opt.name, info, opt))
            if opt.desc and opt.desc ~= "" then
              AddDesc(container, opt.desc, GameFontHighlightSmall)
              AddSpacer(container, 4)
            end
            if type(opt.args) == "table" then
              RenderArgsRecursive(container, opt.args, q, nextPath, normalizeCache)
            end
            AddSeparator(container, 0.45)
            AddSpacer(container, 8)
          end
        end
      else
        if OptionMatchesSearch(opt, q) then
          if opt.type == "header" then
            AddHeading(container, opt.name or "")
            AddSpacer(container, 4)
          elseif opt.type == "description" then
            AddDesc(container, opt.name or "", GameFontHighlightSmall)
            AddSpacer(container, 4)
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

local MODULE_SUMMARY = {
  general = "Core behavior, account/profile flow, and global defaults.",
  ui = "Global interface polish and convenience options.",
  minimapplus = "Minimap visuals, widgets, and addon icon sink behavior.",
  visibility = "Context-aware visibility rules for UI elements.",
  auras = "Buff/debuff layout, timers, and icon behavior.",
  castbar = "Castbar visuals, colors, fonts, and bar behavior.",
  unitframes = "Unit frame text and combat data presentation.",
  actionbars = "Action bar visibility and combat behavior.",
  cooldowns = "Cooldown pulse and countdown visuals.",
  swingtimer = "Melee/ranged swing timing and bar behavior.",
  combattext = "Floating combat text behavior and styling.",
  actiontracker = "Ability tracking panel with cooldown snapshots.",
  tooltip = "Tooltip layout, style, and contextual detail.",
  sound = "Audio feedback and sound trigger rules.",
  vendor = "Vendor automation, junk handling, and quality-of-life options.",
  mailbox = "Mailbox automation and attachment handling.",
  objectives = "Objective tracker appearance and behavior.",
  autogossip = "Auto-select gossip dialogs based on configured patterns.",
  cvars = "Client cvar tuning for UI and gameplay preferences.",
  chatim = "Chat QoL tools and readability improvements.",
  friends = "Friends list decorations and quick status cues.",
  mover = "Move-mode and anchor management for supported UI blocks.",
}

local MODULE_PREVIEW_OVERRIDES = {
  castbar = {
    text = "Fireball - 1.7s cast | Interrupts, width, and text styling preview.",
    useBar = true,
    barValue = 42,
  },
  cooldowns = {
    text = "Cooldown text preview: Avenging Wrath 120s, Hammer of Justice 43s, Exorcism 7.8s.",
    useBar = false,
  },
  swingtimer = {
    text = "Swing timer preview: Main-hand cycle and latency feel.",
    useBar = true,
    barValue = 65,
  },
}

local PREVIEW_KEY_BY_MODULE = {
  auras = "auras",
  actiontracker = "actiontracker",
  swingtimer = "swingtimer",
  combattext = "combattext",
}

local function GetPreviewApplyKey(moduleKey)
  local key = PREVIEW_KEY_BY_MODULE[moduleKey]
  if key then return key end
  local p = ETBC.db and ETBC.db.profile
  local db = p and p[moduleKey]
  if type(db) == "table" and db.preview ~= nil then
    return moduleKey
  end
  return nil
end

local function ToggleModulePreview(moduleKey)
  local p = ETBC.db and ETBC.db.profile
  if not p then return end
  local previewKey = GetPreviewApplyKey(moduleKey)
  if not previewKey then return end
  local db = p[previewKey]
  if type(db) ~= "table" then return end
  if db.preview == nil then return end
  db.preview = not (db.preview and true or false)
  if ETBC.ApplyBus and ETBC.ApplyBus.Notify then
    ETBC.ApplyBus:Notify(previewKey)
  end
end

local function AddModuleHeaderBlock(container, group, moduleKey)
  local title = (group and group.name) or tostring(moduleKey or "Module")
  local desc = MODULE_SUMMARY[moduleKey] or "Configure this module's behavior and visuals."

  local hasSectionCard = HasWidget("ETBC_SectionCard")
  local card = AceGUI:Create(hasSectionCard and "ETBC_SectionCard" or "InlineGroup")
  card:SetFullWidth(true)
  card:SetLayout("List")
  if card.SetTitle then
    card:SetTitle(title)
  end
  if hasSectionCard and card.SetDescription then
    card:SetDescription(desc)
  elseif not hasSectionCard then
    StyleInlineGroup(card)
    AddDesc(card, desc, GameFontHighlightSmall)
  end
  container:AddChild(card)

  local actions = AceGUI:Create("SimpleGroup")
  actions:SetFullWidth(true)
  actions:SetLayout("Flow")
  card:AddChild(actions)

  local moduleDB = ETBC.db and ETBC.db.profile and ETBC.db.profile[moduleKey]
  if type(moduleDB) == "table" and moduleDB.enabled ~= nil then
    local enabled = AceGUI:Create("CheckBox")
    enabled:SetLabel("Enabled")
    enabled:SetValue(moduleDB.enabled and true or false)
    StyleCheckBoxWidget(enabled)
    enabled:SetCallback("OnValueChanged", function(_, _, v)
      moduleDB.enabled = v and true or false
      if ETBC.ApplyBus and ETBC.ApplyBus.Notify then
        ETBC.ApplyBus:Notify(moduleKey)
      end
    end)
    actions:AddChild(enabled)
  end

  local resetBtn = AceGUI:Create("Button")
  resetBtn:SetText("Reset Module")
  resetBtn:SetWidth(130)
  StyleButtonWidget(resetBtn)
  resetBtn:SetCallback("OnClick", function()
    if ETBC and ETBC.ResetModuleProfile then
      ETBC:ResetModuleProfile(moduleKey)
    end
  end)
  actions:AddChild(resetBtn)

  if GetPreviewApplyKey(moduleKey) then
    local previewBtn = AceGUI:Create("Button")
    previewBtn:SetText("Toggle Preview")
    previewBtn:SetWidth(130)
    StyleButtonWidget(previewBtn)
    previewBtn:SetCallback("OnClick", function()
      ToggleModulePreview(moduleKey)
    end)
    actions:AddChild(previewBtn)
  end
end

local function RenderOptions(scroll, groups, moduleKey, searchText, searchWidget)
  if not scroll then return end
  scroll:ReleaseChildren()

  local g = FindGroup(groups, moduleKey)
  if not g then
    if searchWidget and searchWidget.SetResultCount then
      searchWidget:SetResultCount(0)
    end
    AddDesc(scroll, "Select a module on the left.", GameFontHighlight)
    return
  end

  local ok, opts = pcall(g.options)
  if not ok or type(opts) ~= "table" then
    if searchWidget and searchWidget.SetResultCount then
      searchWidget:SetResultCount(0)
    end
    AddDesc(scroll, "Options failed to build for: " .. tostring(g.name), GameFontHighlight)
    return
  end

  local q = tostring(searchText or ""):lower()
  local normalizeCache = {}
  AddModuleHeaderBlock(scroll, g, moduleKey)
  AddSpacer(scroll, 6)

  if HasWidget("ETBC_PreviewPanel") then
    local preview = AceGUI:Create("ETBC_PreviewPanel")
    local override = MODULE_PREVIEW_OVERRIDES[moduleKey]
    local previewText = (override and override.text)
      or MODULE_SUMMARY[moduleKey]
      or ("Live preview for " .. g.name .. " settings.")
    preview:SetFullWidth(true)
    preview:SetTitle(g.name .. " Preview")
    preview:SetPreviewText(previewText)
    preview:SetIcon(g.icon)
    if override and override.useBar then
      preview:EnableBar(true)
      preview:SetBarValue(override.barValue or 65)
      preview:SetBarColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 1)
    else
      preview:EnableBar(false)
    end
    scroll:AddChild(preview)
    AddSpacer(scroll, 8)
    AddSeparator(scroll, 0.6)
    AddSpacer(scroll, 8)
  end

  -- Ensure we pass an args table.
  local args = (opts.type == "group" and opts.args) or opts.args or opts
  if type(args) ~= "table" then args = {} end

  if searchWidget and searchWidget.SetResultCount then
    local rootGroup = { args = args }
    local matchCount = CountMatchesInGroup(rootGroup, q, { moduleKey }, normalizeCache)
    searchWidget:SetResultCount(matchCount)
  end

  RenderArgsRecursive(scroll, args, q, { moduleKey }, normalizeCache)
  if q ~= "" and scroll.children and #scroll.children <= 1 then
    AddDesc(scroll, "No options match the current search.", GameFontHighlightSmall)
  end

  if scroll.DoLayout then
    scroll:DoLayout()
  end
  if scroll.UpdateScroll then
    scroll:UpdateScroll()
  end
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

local function ApplyWindowStyle(win)
  if not win or not win.frame then return end

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
    status:SetPoint("RIGHT", strip, "RIGHT", -10, -14)
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

  if win.titletext and win.frame._etbcHeaderStrip then
    win.titletext:ClearAllPoints()
    win.titletext:SetPoint("LEFT", win.frame._etbcHeaderStrip, "LEFT", 100, 14)
    win.titletext:SetPoint("RIGHT", win.frame._etbcHeaderStrip, "RIGHT", -10, 14)
    win.titletext:SetJustifyH("LEFT")
  end

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

  -- Handle window resize dynamically
  local function QueueResizeLayout()
    if state.resizeTimer then return end
    state.resizeTimer = NewDebounceTimer(0.06, function()
      state.resizeTimer = nil
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

  local topPad = AceGUI:Create("Label")
  topPad:SetText(" ")
  topPad:SetFullWidth(true)
  if topPad.SetHeight then
    topPad:SetHeight(18)
  end
  root:AddChild(topPad)

  local search
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
  local tree = AceGUI:Create("TreeGroup")
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
  local right = AceGUI:Create("ScrollFrame")
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

function ConfigWindow.GetTheme()
  return THEME
end

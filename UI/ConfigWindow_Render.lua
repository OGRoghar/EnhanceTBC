-- UI/ConfigWindow_Render.lua
-- Internal render helpers for EnhanceTBC config window.

local _, ETBC = ...
ETBC.UI = ETBC.UI or {}
local UI = ETBC.UI

UI.ConfigWindow = UI.ConfigWindow or {}
local ConfigWindow = UI.ConfigWindow
ConfigWindow.Internal = ConfigWindow.Internal or {}

ConfigWindow.Internal.Render = ConfigWindow.Internal.Render or {}
local H = ConfigWindow.Internal.Render

if H._loaded then return end
H._loaded = true

local AceGUI = LibStub("AceGUI-3.0")
local ThemeHelpers = ConfigWindow.Internal.Theme or {}
local DataHelpers = ConfigWindow.Internal.Data or {}

local THEME = ThemeHelpers.THEME
local StyleHeadingWidget = ThemeHelpers.StyleHeadingWidget
local StyleLabelWidget = ThemeHelpers.StyleLabelWidget
local StyleCheckBoxWidget = ThemeHelpers.StyleCheckBoxWidget
local StyleButtonWidget = ThemeHelpers.StyleButtonWidget
local StyleSliderWidget = ThemeHelpers.StyleSliderWidget
local StyleDropdownWidget = ThemeHelpers.StyleDropdownWidget
local StyleColorWidget = ThemeHelpers.StyleColorWidget
local StyleInlineGroup = ThemeHelpers.StyleInlineGroup
local HasWidget = ThemeHelpers.HasWidget
local FindGroup = DataHelpers.FindGroup

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


H.TextMatch = TextMatch
H.OptionMatchesSearch = OptionMatchesSearch
H.MakeInfo = MakeInfo
H.IsHidden = IsHidden
H.IsDisabled = IsDisabled
H.SafeGet = SafeGet
H.SafeSet = SafeSet
H.SafeExec = SafeExec
H.SafeValues = SafeValues
H.ResolveText = ResolveText
H.AddHeading = AddHeading
H.AddDesc = AddDesc
H.AddSpacer = AddSpacer
H.AddSeparator = AddSeparator
H.SetWidgetDescription = SetWidgetDescription
H.AddToggle = AddToggle
H.AddRange = AddRange
H.AddSelect = AddSelect
H.AddColor = AddColor
H.AddExecute = AddExecute
H.NormalizeArgs = NormalizeArgs
H.AnyMatchInGroup = AnyMatchInGroup
H.CountMatchesInGroup = CountMatchesInGroup
H.RenderArgsRecursive = RenderArgsRecursive
H.GetPreviewApplyKey = GetPreviewApplyKey
H.ToggleModulePreview = ToggleModulePreview
H.AddModuleHeaderBlock = AddModuleHeaderBlock
H.RenderOptions = RenderOptions


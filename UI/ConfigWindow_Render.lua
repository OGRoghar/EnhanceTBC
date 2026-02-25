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
local SetBackdrop = ThemeHelpers.SetBackdrop
local SetTextColor = ThemeHelpers.SetTextColor
local TrySetFont = ThemeHelpers.TrySetFont
local StyleHeadingWidget = ThemeHelpers.StyleHeadingWidget
local StyleLabelWidget = ThemeHelpers.StyleLabelWidget
local StyleCheckBoxWidget = ThemeHelpers.StyleCheckBoxWidget
local StyleButtonWidget = ThemeHelpers.StyleButtonWidget
local StyleSliderWidget = ThemeHelpers.StyleSliderWidget
local StyleDropdownWidget = ThemeHelpers.StyleDropdownWidget
local StyleEditBoxWidget = ThemeHelpers.StyleEditBoxWidget
local StyleColorWidget = ThemeHelpers.StyleColorWidget
local StyleInlineGroup = ThemeHelpers.StyleInlineGroup
local HasWidget = ThemeHelpers.HasWidget
local GetUIDB = DataHelpers.GetUIDB
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

local function StyleMultiLineInputWidget(w)
  if not w then return end

  if w.label and SetTextColor then
    SetTextColor(w.label, THEME.text)
    TrySetFont(w.label, 12, nil)
  end

  if w.scrollBG and SetBackdrop then
    SetBackdrop(w.scrollBG, THEME.bg, THEME.border, 1)
  end

  local edit = w.editBox or w.editbox
  if edit then
    if edit.SetTextColor then
      edit:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], THEME.text[4])
    end
    TrySetFont(edit, 12, nil)
  end

  if w.button and w.button.GetFontString then
    local fs = w.button:GetFontString()
    if fs then
      SetTextColor(fs, THEME.text)
      TrySetFont(fs, 11, "OUTLINE")
    end
  end
end

local function ApplyInputWidth(w, opt, multiline)
  local width = opt and opt.width or nil

  if width == "full" then
    if w.SetFullWidth then w:SetFullWidth(true) end
    return
  end

  if multiline then
    -- Multiline inputs are more usable when allowed to span the full content width.
    if w.SetFullWidth then w:SetFullWidth(true) end
    return
  end

  if width == "double" and w.SetWidth then
    w:SetWidth(420)
  elseif width == "half" and w.SetWidth then
    w:SetWidth(170)
  elseif width == "normal" and w.SetWidth then
    w:SetWidth(220)
  end
end

local function AddInput(container, opt, info)
  local wantsMultiline = opt.multiline and true or false
  local useMultiline = wantsMultiline and HasWidget("MultiLineEditBox") and true or false
  local widgetType = useMultiline and "MultiLineEditBox" or "EditBox"
  local w = AceGUI:Create(widgetType)

  local label = ResolveText(opt.name, info, opt)
  if label == "" then label = tostring(opt._id or "") end
  if w.SetLabel then
    w:SetLabel(label)
  end

  if useMultiline then
    if w.SetNumLines then
      w:SetNumLines(6)
    end
    if w.DisableButton then
      w:DisableButton(false)
    end
  end

  ApplyInputWidth(w, opt, useMultiline)
  if w.SetDisabled then
    w:SetDisabled(IsDisabled(opt, info))
  end

  local val = SafeGet(opt, info)
  if val == nil then val = "" end
  if type(val) ~= "string" then
    val = tostring(val)
  end
  if w.SetText then
    w:SetText(val)
  end

  if useMultiline then
    StyleMultiLineInputWidget(w)
  elseif StyleEditBoxWidget then
    StyleEditBoxWidget(w)
  end

  SetWidgetDescription(container, w, opt.desc)

  local function CommitValue(_, _, v)
    if v == nil and w.GetText then
      v = w:GetText()
    end
    SafeSet(opt, info, tostring(v or ""))
  end

  if w.SetCallback then
    w:SetCallback("OnEnterPressed", CommitValue)
    if useMultiline then
      w:SetCallback("OnEditFocusLost", function()
        CommitValue()
      end)
    end
  end

  if (not useMultiline) and w.editbox and w.editbox.HookScript and not w._etbcFocusCommitHooked then
    w._etbcFocusCommitHooked = true
    w.editbox:HookScript("OnEditFocusLost", function()
      CommitValue()
    end)
  end

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

local function AddUnsupportedOption(container, opt)
  local typeName = tostring(opt and opt.type or "nil")
  local id = tostring(opt and opt._id or "?")
  AddDesc(container, "Unsupported setting type: " .. typeName .. " (" .. id .. ")", GameFontHighlightSmall)
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

local function ShouldSuppressCustomOption(opt, pathStack, renderCtx)
  if type(opt) ~= "table" or type(renderCtx) ~= "table" then return false end

  -- /etbc already shows a module summary card at the top of the page.
  if opt._id == "__etbcModuleIntro" and opt.type == "description" then
    if type(pathStack) == "table" and #pathStack == 1 then
      return true
    end
  end

  -- Avoid duplicate theme controls in the custom /etbc window:
  -- keep the dedicated UI -> Config Window theme selector, and hide the
  -- General -> UI global addon theme selector here only.
  if opt._id == "theme" and opt.type == "select" and type(pathStack) == "table" and #pathStack == 2 then
    if pathStack[1] == "general" and pathStack[2] == "ui" then
      return true
    end
  end

  -- Preview-capable modules expose a custom header action in /etbc; hide the
  -- duplicate root preview toggle in this renderer only.
  if renderCtx.hideRootPreview and opt._id == "preview" and opt.type == "toggle" then
    if type(pathStack) == "table" and #pathStack == 1 then
      return true
    end
  end

  if not renderCtx.hideRootEnabled then return false end
  if opt._id ~= "enabled" or opt.type ~= "toggle" then return false end
  if type(pathStack) ~= "table" or #pathStack ~= 1 then return false end
  return true
end

local function RelayoutParents(widget)
  local p = widget
  while p do
    if p.DoLayout then
      pcall(p.DoLayout, p)
    end
    if p.UpdateScroll then
      pcall(p.UpdateScroll, p)
    end
    p = p.parent
  end
end

local function BuildSectionPathKey(pathStack)
  if type(pathStack) ~= "table" or #pathStack == 0 then
    return nil
  end
  local parts = {}
  for i = 1, #pathStack do
    parts[i] = tostring(pathStack[i] or "")
  end
  return table.concat(parts, ".")
end

local function GetSectionCollapsed(moduleKey, sectionPathKey)
  if not moduleKey or not sectionPathKey then return false end
  local uiDB = type(GetUIDB) == "function" and GetUIDB() or nil
  if type(uiDB) ~= "table" then return false end
  uiDB.sectionCollapsed = uiDB.sectionCollapsed or {}
  local mod = uiDB.sectionCollapsed[moduleKey]
  if type(mod) ~= "table" then return false end
  return mod[sectionPathKey] and true or false
end

local function SetSectionCollapsed(moduleKey, sectionPathKey, collapsed)
  if not moduleKey or not sectionPathKey then return end
  local uiDB = type(GetUIDB) == "function" and GetUIDB() or nil
  if type(uiDB) ~= "table" then return end
  uiDB.sectionCollapsed = uiDB.sectionCollapsed or {}
  uiDB.sectionCollapsed[moduleKey] = uiDB.sectionCollapsed[moduleKey] or {}
  uiDB.sectionCollapsed[moduleKey][sectionPathKey] = collapsed and true or false
end

local function GetPreviewCollapsed(moduleKey)
  if not moduleKey then return false end
  local uiDB = type(GetUIDB) == "function" and GetUIDB() or nil
  if type(uiDB) ~= "table" then return false end
  uiDB.previewCollapsed = uiDB.previewCollapsed or {}
  return uiDB.previewCollapsed[moduleKey] and true or false
end

local function SetPreviewCollapsed(moduleKey, collapsed)
  if not moduleKey then return end
  local uiDB = type(GetUIDB) == "function" and GetUIDB() or nil
  if type(uiDB) ~= "table" then return end
  uiDB.previewCollapsed = uiDB.previewCollapsed or {}
  uiDB.previewCollapsed[moduleKey] = collapsed and true or false
end

local function AnyMatchInGroup(groupOpt, q, pathStack, normalizeCache, renderCtx)
  if not q or q == "" then return true end
  if OptionMatchesSearch(groupOpt, q) then return true end
  if type(groupOpt.args) ~= "table" then return false end

  local list = NormalizeArgs(groupOpt.args, normalizeCache)
  for _, child in ipairs(list) do
    local info = MakeInfo(pathStack, child)
    if (not IsHidden(child, info)) and (not ShouldSuppressCustomOption(child, pathStack, renderCtx)) then
      if child.type == "group" then
        local nextPath = { unpack(pathStack or {}) }
        nextPath[#nextPath + 1] = child._id
        if AnyMatchInGroup(child, q, nextPath, normalizeCache, renderCtx) then return true end
      else
        if OptionMatchesSearch(child, q) then return true end
      end
    end
  end

  return false
end

local function CountMatchesInGroup(groupOpt, q, pathStack, normalizeCache, renderCtx)
  if type(groupOpt) ~= "table" or type(groupOpt.args) ~= "table" then return 0 end
  local count = 0
  local list = NormalizeArgs(groupOpt.args, normalizeCache)
  for _, child in ipairs(list) do
    local info = MakeInfo(pathStack, child)
    if (not IsHidden(child, info)) and (not ShouldSuppressCustomOption(child, pathStack, renderCtx)) then
      if child.type == "group" then
        local nextPath = { unpack(pathStack or {}) }
        nextPath[#nextPath + 1] = child._id
        count = count + CountMatchesInGroup(child, q, nextPath, normalizeCache, renderCtx)
      else
        if OptionMatchesSearch(child, q) then
          count = count + 1
        end
      end
    end
  end
  return count
end

local function RenderArgsRecursive(container, args, q, pathStack, normalizeCache, renderCtx)
  local list = NormalizeArgs(args, normalizeCache)
  for _, opt in ipairs(list) do
    local info = MakeInfo(pathStack, opt)
    if (not IsHidden(opt, info)) and (not ShouldSuppressCustomOption(opt, pathStack, renderCtx)) then
      if opt.type == "group" then
        local nextPath = { unpack(pathStack or {}) }
        nextPath[#nextPath + 1] = opt._id

        if AnyMatchInGroup(opt, q, nextPath, normalizeCache, renderCtx) then
          if opt.inline then
            local useSectionCard = HasWidget("ETBC_SectionCard")
            local grpType = useSectionCard and "ETBC_SectionCard" or "InlineGroup"
            local grp = AceGUI:Create(grpType)
            local searchActive = (q ~= nil and q ~= "")
            local moduleKey = renderCtx.moduleKey or (type(pathStack) == "table" and pathStack[1]) or nil
            local sectionPathKey = BuildSectionPathKey(nextPath)

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

            if useSectionCard and grp.SetCollapsible and grp.SetCollapsed then
              if searchActive then
                grp:SetCollapsible(false)
                grp:SetCollapsed(false)
              else
                grp:SetCollapsible(true)
                grp:SetCollapsed(GetSectionCollapsed(moduleKey, sectionPathKey))
                if grp.SetOnToggle then
                  grp:SetOnToggle(function(sectionCard, collapsed)
                    SetSectionCollapsed(moduleKey, sectionPathKey, collapsed and true or false)
                    RelayoutParents(sectionCard)
                  end)
                end
              end
            end

            container:AddChild(grp)

            if (not useSectionCard) and opt.desc and opt.desc ~= "" then
              AddDesc(grp, opt.desc, GameFontHighlightSmall)
            end

            if type(opt.args) == "table" then
              RenderArgsRecursive(grp, opt.args, q, nextPath, normalizeCache, renderCtx)
            end
            AddSpacer(container, 8)
          else
            AddHeading(container, ResolveText(opt.name, info, opt))
            if opt.desc and opt.desc ~= "" then
              AddDesc(container, opt.desc, GameFontHighlightSmall)
              AddSpacer(container, 4)
            end
            if type(opt.args) == "table" then
              RenderArgsRecursive(container, opt.args, q, nextPath, normalizeCache, renderCtx)
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
          elseif opt.type == "input" then
            AddInput(container, opt, info)
          elseif opt.type == "execute" then
            AddExecute(container, opt, info)
          else
            AddUnsupportedOption(container, opt)
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
  nameplates = "Unit nameplate sizing, castbars, debuff displays, and color behavior.",
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

local MODULE_PREVIEW_RUNTIME_NAMES = {
  castbar = "Castbar",
  swingtimer = "SwingTimer",
  cooldowns = "CooldownText",
  combattext = "CombatText",
  actiontracker = "ActionTracker",
  auras = "Auras",
}

local function GetModuleConfigPreviewStyle(moduleKey)
  local modules = ETBC and ETBC.Modules or nil
  if type(modules) ~= "table" or not moduleKey then
    return nil
  end

  local runtimeKey = MODULE_PREVIEW_RUNTIME_NAMES[moduleKey]
  local module = (runtimeKey and modules[runtimeKey]) or modules[moduleKey]
  if type(module) ~= "table" then
    return nil
  end

  local shared = module.Internal and module.Internal.Shared
  if not (type(shared) == "table" and type(shared.GetConfigPreviewStyle) == "function") then
    return nil
  end

  local ok, style = pcall(shared.GetConfigPreviewStyle)
  if ok and type(style) == "table" then
    return style
  end
  return nil
end

local function ApplyProviderPreviewStyle(preview, style, fallbackOverride)
  if type(style) ~= "table" or not preview then
    return false
  end

  local disabled = style.disabled
  if disabled == nil and style.enabled ~= nil then
    disabled = not (style.enabled and true or false)
  end
  if disabled ~= nil and preview.SetDisabled then
    preview:SetDisabled(disabled and true or false)
  end

  if style.previewText ~= nil and preview.SetPreviewText then
    preview:SetPreviewText(style.previewText or "")
  end

  if type(style.previewFont) == "table" and preview.SetPreviewFont then
    local f = style.previewFont
    preview:SetPreviewFont(f.path or f[1], f.size or f[2], f.flags or f.outline or f[3])
  end

  if type(style.previewTextColor) == "table" and preview.SetPreviewTextColor then
    local c = style.previewTextColor
    preview:SetPreviewTextColor(c.r or c[1], c.g or c[2], c.b or c[3], c.a or c[4] or 1)
  end

  local useBar = style.useBar
  if useBar == nil and type(fallbackOverride) == "table" and fallbackOverride.useBar ~= nil then
    useBar = fallbackOverride.useBar and true or false
  end

  if useBar and preview.EnableBar then
    preview:EnableBar(true)

    if preview.SetBarValue then
      local v = style.barValue
      if v == nil then v = style.value end -- legacy provider alias (castbar)
      if v == nil and type(fallbackOverride) == "table" then v = fallbackOverride.barValue end
      preview:SetBarValue(tonumber(v) or 65)
    end

    if preview.SetBarColor and type(style.barColor) == "table" then
      local c = style.barColor
      preview:SetBarColor(c.r or c[1], c.g or c[2], c.b or c[3], c.a or c[4] or 1)
    end

    if preview.SetBarTexture and type(style.barTexture) == "string" and style.barTexture ~= "" then
      preview:SetBarTexture(style.barTexture)
    end

    if preview.SetBarAlpha and style.barAlpha ~= nil then
      preview:SetBarAlpha(style.barAlpha)
    end

    local barText = style.barText
    if barText == nil then barText = style.labelText end -- legacy provider alias (castbar)
    if barText ~= nil and preview.SetBarText then
      preview:SetBarText(barText)
    end

    if preview.SetBarTextFont then
      if type(style.barTextFont) == "table" then
        local f = style.barTextFont
        preview:SetBarTextFont(f.path or f[1], f.size or f[2], f.flags or f.outline or f[3])
      elseif type(style.fontPath) == "string" and style.fontPath ~= "" then
        -- legacy provider aliases (castbar)
        preview:SetBarTextFont(style.fontPath, style.fontSize or 12, style.outline)
      end
    end
  elseif preview.EnableBar then
    preview:EnableBar(false)
  end

  return true
end

local function GetCastbarConfigPreviewStyle()
  local modules = ETBC and ETBC.Modules or nil
  local castbar = modules and modules.Castbar or nil
  local shared = castbar and castbar.Internal and castbar.Internal.Shared or nil
  if not (shared and type(shared.GetConfigPreviewStyle) == "function") then
    return nil
  end
  local ok, style = pcall(shared.GetConfigPreviewStyle)
  if ok and type(style) == "table" then
    return style
  end
  return nil
end

local function ApplyCastbarPreviewWidget(preview)
  local style = GetCastbarConfigPreviewStyle()
  if not style then return false end

  if preview.SetDisabled then
    preview:SetDisabled(not (style.enabled and true or false))
  end
  if preview.EnableBar then
    preview:EnableBar(true)
  end
  if preview.SetBarValue then
    preview:SetBarValue(tonumber(style.value) or 42)
  end
  if preview.SetBarColor and type(style.barColor) == "table" then
    local c = style.barColor
    preview:SetBarColor(c[1], c[2], c[3], c[4] or 1)
  end
  if preview.SetBarTexture and type(style.barTexture) == "string" and style.barTexture ~= "" then
    preview:SetBarTexture(style.barTexture)
  end
  if preview.SetBarText and style.labelText ~= nil then
    preview:SetBarText(style.labelText)
  end
  if preview.SetBarTextFont and type(style.fontPath) == "string" and style.fontPath ~= "" then
    preview:SetBarTextFont(style.fontPath, style.fontSize or 12, style.outline)
  end

  return true
end

local MODULE_PREVIEW_APPLIERS = {
  castbar = ApplyCastbarPreviewWidget,
}

local function ApplyModulePreviewWidget(preview, moduleKey, group)
  if not preview then return end

  if preview.ResetPreviewStyles then
    preview:ResetPreviewStyles()
  end

  local override = MODULE_PREVIEW_OVERRIDES[moduleKey]
  local previewText = (override and override.text)
    or MODULE_SUMMARY[moduleKey]
    or ("Live preview for " .. tostring((group and group.name) or moduleKey or "module") .. " settings.")

  if preview.SetTitle then
    if preview._etbcManagedOuterTitle then
      preview:SetTitle("")
    else
      local groupName = (group and group.name) or tostring(moduleKey or "Module")
      preview:SetTitle(groupName .. " Preview")
    end
  end
  if preview.SetPreviewText then
    preview:SetPreviewText(previewText)
  end
  if preview.SetIcon then
    preview:SetIcon(group and group.icon or nil)
  end

  local providerStyle = GetModuleConfigPreviewStyle(moduleKey)
  if ApplyProviderPreviewStyle(preview, providerStyle, override) then
    return
  end

  local appliedCustom = false
  local applier = MODULE_PREVIEW_APPLIERS[moduleKey]
  if type(applier) == "function" then
    local ok, applied = pcall(applier, preview, moduleKey, group, override)
    if ok and applied then
      appliedCustom = true
    end
  end

  if appliedCustom then
    return
  end

  if preview.SetDisabled then
    preview:SetDisabled(false)
  end

  if override and override.useBar then
    if preview.EnableBar then
      preview:EnableBar(true)
    end
    if preview.SetBarValue then
      preview:SetBarValue(override.barValue or 65)
    end
    if preview.SetBarColor then
      preview:SetBarColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 1)
    end
  else
    if preview.EnableBar then
      preview:EnableBar(false)
    end
  end
end

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
  scroll._etbcPreviewWidget = nil
  scroll._etbcPreviewModuleKey = nil
  scroll._etbcPreviewGroup = nil
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
  local moduleDB = ETBC.db and ETBC.db.profile and ETBC.db.profile[moduleKey]
  local previewApplyKey = GetPreviewApplyKey(moduleKey)
  local renderCtx = {
    hideRootEnabled = type(moduleDB) == "table" and moduleDB.enabled ~= nil and true or false,
    hideRootPreview = previewApplyKey ~= nil,
    moduleKey = moduleKey,
  }
  AddModuleHeaderBlock(scroll, g, moduleKey)
  AddSpacer(scroll, 4)

  if HasWidget("ETBC_PreviewPanel") then
    local previewContainer = scroll
    local previewCollapsed = GetPreviewCollapsed(moduleKey)
    local usePreviewCard = HasWidget("ETBC_SectionCard")

    if usePreviewCard then
      local previewCard = AceGUI:Create("ETBC_SectionCard")
      previewCard:SetTitle("Preview")
      if previewCard.SetDescription then
        previewCard:SetDescription("Live visual preview for this module's /etbc settings.")
      end
      previewCard:SetFullWidth(true)
      previewCard:SetLayout("List")
      if previewCard.SetCollapsible and previewCard.SetCollapsed then
        previewCard:SetCollapsible(true)
        previewCard:SetCollapsed(previewCollapsed)
        if previewCard.SetOnToggle then
          previewCard:SetOnToggle(function(sectionCard, collapsed)
            SetPreviewCollapsed(moduleKey, collapsed and true or false)
            RelayoutParents(sectionCard)
          end)
        end
      end
      scroll:AddChild(previewCard)
      previewContainer = previewCard
    end

    local preview = AceGUI:Create("ETBC_PreviewPanel")
    preview._etbcManagedOuterTitle = usePreviewCard and true or false
    preview:SetFullWidth(true)
    ApplyModulePreviewWidget(preview, moduleKey, g)
    scroll._etbcPreviewWidget = preview
    scroll._etbcPreviewModuleKey = moduleKey
    scroll._etbcPreviewGroup = g
    previewContainer:AddChild(preview)

    AddSpacer(scroll, 6)
    if (not usePreviewCard) or (not previewCollapsed) then
      AddSeparator(scroll, 0.6)
      AddSpacer(scroll, 6)
    end
  end

  -- Ensure we pass an args table.
  local args = (opts.type == "group" and opts.args) or opts.args or opts
  if type(args) ~= "table" then args = {} end

  if searchWidget and searchWidget.SetResultCount then
    local rootGroup = { args = args }
    local matchCount = CountMatchesInGroup(rootGroup, q, { moduleKey }, normalizeCache, renderCtx)
    searchWidget:SetResultCount(matchCount)
  end

  RenderArgsRecursive(scroll, args, q, { moduleKey }, normalizeCache, renderCtx)
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

local function RefreshPreviewWidget(scroll, moduleKey)
  if not scroll then return end
  local preview = scroll._etbcPreviewWidget
  local storedKey = scroll._etbcPreviewModuleKey
  if not preview or not storedKey then return end
  if moduleKey and moduleKey ~= storedKey then return end
  ApplyModulePreviewWidget(preview, storedKey, scroll._etbcPreviewGroup)
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
H.AddInput = AddInput
H.AddExecute = AddExecute
H.NormalizeArgs = NormalizeArgs
H.AnyMatchInGroup = AnyMatchInGroup
H.CountMatchesInGroup = CountMatchesInGroup
H.RenderArgsRecursive = RenderArgsRecursive
H.GetPreviewApplyKey = GetPreviewApplyKey
H.ToggleModulePreview = ToggleModulePreview
H.AddModuleHeaderBlock = AddModuleHeaderBlock
H.RenderOptions = RenderOptions
H.RefreshPreviewWidget = RefreshPreviewWidget


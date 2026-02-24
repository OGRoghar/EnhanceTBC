-- Core/SettingsRegistry.lua
-- Central registry of settings groups for the config window / options builder

local _, ETBC = ...
ETBC.SettingsRegistry = ETBC.SettingsRegistry or {}

local reg = {
  groups = {},     -- ordered list
  byKey = {},      -- key -> group
}

local AUTO_OPTION_DOCS_ENABLED = true

local LEAF_TYPES = {
  toggle = true,
  range = true,
  select = true,
  color = true,
  input = true,
  execute = true,
}

local MODULE_INTRO_TEXT = {
  general = "Configure addon-wide behavior, defaults, and profile-related options.",
  ui = "Configure global interface polish, visuals, and convenience UI behavior.",
  minimapplus = "Configure minimap styling, tracking widgets, addon icon sink behavior, and minimap utility features.",
  visibility = "Configure context-aware visibility rules and fade timing for supported modules.",
  auras = "Configure buff/debuff displays, anchors, filtering behavior, and preview settings.",
  castbar = "Configure player/target/focus castbar behavior, layout, text, colors, and timing visuals.",
  unitframes = "Configure unit frame display elements, text, colors, and combat data presentation.",
  actionbars = "Configure action bar behavior, visibility handling, and styling-related options.",
  cooldowns = "Configure cooldown text, pulse behavior, timing thresholds, and visual styling.",
  swingtimer = "Configure swing timer bars, timing behavior, visuals, and preview settings.",
  combattext = "Configure floating combat text events, formatting, movement, colors, and crit styling.",
  actiontracker = "Configure tracked ability panels, layout, styling, and cooldown snapshot behavior.",
  tooltip = "Configure tooltip content, anchor/layout behavior, styling, and health bar presentation.",
  sound = "Configure sound-trigger categories, playback behavior, and per-feature volume settings.",
  vendor = "Configure vendor automation, auto-repair, junk selling, safety checks, and item ID lists.",
  mailbox = "Configure mailbox automation, attachment handling, timing, and mailbox utility actions.",
  objectives = "Configure objective tracker layout, sizing, visibility, and behavior details.",
  autogossip = "Configure automatic gossip option selection rules, delays, and pattern/ID lists.",
  cvars = "Configure client CVars used by the addon for UI/gameplay preferences and compatibility tuning.",
  chatim = "Configure chat quality-of-life behavior, message presentation, and chat interaction helpers.",
  friends = "Configure friends-list quality-of-life display tweaks and status behavior.",
  mover = "Configure move mode, anchor overlays, snapping, and mover interaction behavior.",
  nameplates = "Configure enemy/friendly nameplate sizing, castbars, auras, colors, and performance toggles.",
}

local function NormalizeOrder(v, fallback)
  local n = tonumber(v)
  if n == nil then
    return fallback
  end
  return n
end

local function Trim(s)
  s = tostring(s or "")
  s = s:gsub("^%s+", "")
  s = s:gsub("%s+$", "")
  return s
end

local function GetNameText(opt, fallbackId)
  if type(opt) ~= "table" then
    return Trim(fallbackId or "setting")
  end
  if type(opt.name) == "string" and opt.name ~= "" then
    return Trim(opt.name)
  end
  if type(fallbackId) == "string" and fallbackId ~= "" then
    local label = fallbackId:gsub("_", " ")
    return Trim(label)
  end
  return "setting"
end

local function InferUnitHint(nameText, optId)
  local hay = (tostring(nameText or "") .. " " .. tostring(optId or "")):lower()
  if hay:find("gold", 1, true) then return "gold" end
  if hay:find("alpha", 1, true) or hay:find("opacity", 1, true) then return "alpha" end
  if hay:find("sec", 1, true) or hay:find("time", 1, true) or hay:find("interval", 1, true)
    or hay:find("delay", 1, true) or hay:find("duration", 1, true) then
    return "seconds"
  end
  if hay:find("width", 1, true) or hay:find("height", 1, true) or hay:find("padding", 1, true)
    or hay:find("spacing", 1, true) or hay:find("offset", 1, true) or hay:find("distance", 1, true) then
    return "pixels"
  end
  if hay:find("scale", 1, true) then return "scale" end
  return nil
end

local function FormatNumber(n)
  if type(n) ~= "number" then return tostring(n) end
  if math.floor(n) == n then
    return tostring(math.floor(n))
  end
  local s = string.format("%.2f", n)
  s = s:gsub("0+$", "")
  s = s:gsub("%.$", "")
  return s
end

local function BuildRangeHint(opt)
  if type(opt) ~= "table" then return "" end
  local minv = tonumber(opt.min)
  local maxv = tonumber(opt.max)
  if minv == nil and maxv == nil then
    return ""
  end
  local parts = {}
  if minv ~= nil and maxv ~= nil then
    parts[#parts + 1] = "Range: " .. FormatNumber(minv) .. "-" .. FormatNumber(maxv) .. "."
  elseif minv ~= nil then
    parts[#parts + 1] = "Minimum: " .. FormatNumber(minv) .. "."
  elseif maxv ~= nil then
    parts[#parts + 1] = "Maximum: " .. FormatNumber(maxv) .. "."
  end
  local stepv = tonumber(opt.step)
  if stepv ~= nil then
    parts[#parts + 1] = "Step: " .. FormatNumber(stepv) .. "."
  end
  return table.concat(parts, " ")
end

local function HasDisabledGate(opt)
  if type(opt) ~= "table" then return false end
  if opt.disabled == nil then return false end
  return true
end

local function AppendCommonHints(desc, opt, nameText, optId)
  local extra = {}
  local unit = InferUnitHint(nameText, optId)
  if opt and opt.type == "range" and unit then
    if unit == "seconds" then
      extra[#extra + 1] = "Values are in seconds."
    elseif unit == "pixels" then
      extra[#extra + 1] = "Values are in pixels."
    elseif unit == "alpha" then
      extra[#extra + 1] = "Values control opacity/alpha."
    elseif unit == "scale" then
      extra[#extra + 1] = "Values control scale multiplier."
    end
  end
  local rangeHint = BuildRangeHint(opt)
  if rangeHint ~= "" then
    extra[#extra + 1] = rangeHint
  end
  if HasDisabledGate(opt) then
    extra[#extra + 1] = "This option may be unavailable until related settings are enabled."
  end
  if type(opt) == "table" and opt.type == "input" then
    local hay = (tostring(nameText or "") .. " " .. tostring(optId or "")):lower()
    if hay:find("id", 1, true) then
      extra[#extra + 1] = "Use comma or space separators for IDs."
    elseif hay:find("pattern", 1, true) then
      extra[#extra + 1] = "Enter one or more match patterns in the expected format for this module."
    end
  end
  if type(opt) == "table" and opt.type == "execute" then
    local hay = (tostring(nameText or "") .. " " .. tostring(optId or "")):lower()
    if hay:find("vendor", 1, true) or hay:find("sell", 1, true) then
      extra[#extra + 1] = "Requires the merchant window to be open."
    elseif hay:find("mail", 1, true) or hay:find("inbox", 1, true) or hay:find("mailbox", 1, true) then
      extra[#extra + 1] = "Requires the mailbox window to be open."
    end
  end
  if #extra == 0 then return desc end
  return desc .. " " .. table.concat(extra, " ")
end

local function BuildLeafDescription(group, optId, opt)
  local nameText = GetNameText(opt, optId)
  local moduleName = type(group) == "table" and group.name or "this module"
  local moduleRef = "this module"
  if type(moduleName) == "string" and moduleName ~= "" then
    moduleRef = moduleName
  end

  local base
  if opt.type == "toggle" then
    base = "Turns " .. nameText .. " on or off for " .. moduleRef .. "."
  elseif opt.type == "range" then
    base = "Adjusts " .. nameText .. " for " .. moduleRef .. ". Lower values reduce it; higher values increase it."
  elseif opt.type == "select" then
    base = "Chooses the " .. nameText .. " setting used by " .. moduleRef .. "."
  elseif opt.type == "color" then
    base = "Sets the color used for " .. nameText .. " in " .. moduleRef .. "."
  elseif opt.type == "input" then
    base = "Sets values for " .. nameText .. " in " .. moduleRef .. "."
  elseif opt.type == "execute" then
    base = "Runs " .. nameText .. " immediately for " .. moduleRef .. "."
  else
    return nil
  end

  local hay = (tostring(nameText or "") .. " " .. tostring(optId or "")):lower()
  if hay:find("advanced", 1, true) or hay:find("compat", 1, true) or hay:find("delta", 1, true)
    or hay:find("spellid", 1, true) or hay:find("throttle", 1, true) or hay:find("cvar", 1, true) then
    base = base .. " Advanced/compatibility tuning; only change it if you need different behavior."
  end

  return AppendCommonHints(base, opt, nameText, optId)
end

local function BuildGroupDescription(group, optId, opt)
  local sectionName = GetNameText(opt, optId)
  local moduleName = "this module"
  if type(group) == "table" and type(group.name) == "string" and group.name ~= "" then
    moduleName = group.name
  end
  return "Configure " .. sectionName .. " settings for " .. moduleName .. "."
end

local function HasTopLevelIntro(args)
  if type(args) ~= "table" then return false end
  if args.__etbcModuleIntro then return true end
  for _, opt in pairs(args) do
    if type(opt) == "table" and opt.type == "description" then
      local order = tonumber(opt.order)
      if order and order <= 5 then
        return true
      end
    end
  end
  return false
end

local function EnsureModuleIntro(group, args)
  if type(args) ~= "table" or type(group) ~= "table" then return end
  if HasTopLevelIntro(args) then return end

  local key = tostring(group.key or "")
  local intro = MODULE_INTRO_TEXT[key] or ("Configure " .. tostring(group.name or key or "this module") .. " settings.")
  local introOrder = 0.5
  if type(args.enabled) == "table" and args.enabled.type == "toggle" then
    introOrder = 1.5
  end

  args.__etbcModuleIntro = {
    type = "description",
    name = intro,
    order = introOrder,
    width = "full",
  }
end

local function DecorateArgs(group, args, visited)
  if type(args) ~= "table" then return end
  if visited[args] then return end
  visited[args] = true

  for optId, opt in pairs(args) do
    if type(opt) == "table" then
      if opt.type == "group" then
        if (opt.desc == nil or opt.desc == "") then
          opt.desc = BuildGroupDescription(group, optId, opt)
        end
        if type(opt.args) == "table" then
          DecorateArgs(group, opt.args, visited)
        end
      elseif LEAF_TYPES[opt.type] then
        if opt.desc == nil or opt.desc == "" then
          local desc = BuildLeafDescription(group, optId, opt)
          if desc and desc ~= "" then
            opt.desc = desc
          end
        end
      elseif type(opt.args) == "table" then
        DecorateArgs(group, opt.args, visited)
      end
    end
  end
end

local function DecorateOptionsResult(group, opts)
  if not AUTO_OPTION_DOCS_ENABLED or type(group) ~= "table" or type(opts) ~= "table" then
    return opts
  end

  local visited = {}
  if opts.type == "group" and type(opts.args) == "table" then
    EnsureModuleIntro(group, opts.args)
    DecorateArgs(group, opts.args, visited)
  else
    EnsureModuleIntro(group, opts)
    DecorateArgs(group, opts, visited)
  end
  return opts
end

local function WrapGroupOptionsBuilder(group)
  if type(group) ~= "table" or group._etbcOptionsWrapped then return end
  group._etbcOptionsWrapped = true

  if type(group.options) == "function" then
    local raw = group.options
    group._etbcRawOptionsBuilder = raw
    group.options = function(...)
      local ok, opts = pcall(raw, ...)
      if not ok then
        error(opts)
      end
      return DecorateOptionsResult(group, opts)
    end
  elseif type(group.options) == "table" then
    group.options = DecorateOptionsResult(group, group.options)
  end
end

function ETBC.SettingsRegistry.RegisterGroup(_, key, group)
  if type(key) ~= "string" or key == "" or type(group) ~= "table" then return end

  local existing = reg.byKey[key]
  if existing then
    for i = #reg.groups, 1, -1 do
      if reg.groups[i] == existing then
        table.remove(reg.groups, i)
        break  -- Only one instance should exist
      end
    end
  end

  group.key = key
  group.order = NormalizeOrder(group.order, #reg.groups + 1)
  group.name = group.name or key
  WrapGroupOptionsBuilder(group)

  reg.byKey[key] = group

  local inserted = false
  for i = 1, #reg.groups do
    local curr = reg.groups[i]
    local currOrder = NormalizeOrder(curr and curr.order, i)
    local currKey = tostring(curr and curr.key or "")
    if group.order < currOrder or (group.order == currOrder and key < currKey) then
      table.insert(reg.groups, i, group)
      inserted = true
      break
    end
  end
  if not inserted then
    table.insert(reg.groups, group)
  end
end

function ETBC.SettingsRegistry.GetGroups(_)
  local out = {}
  for i = 1, #reg.groups do
    out[i] = reg.groups[i]
  end
  return out
end

function ETBC.SettingsRegistry.Get(_, key)
  return reg.byKey[key]
end

ETBC.SettingsRegistry.AUTO_OPTION_DOCS_ENABLED = AUTO_OPTION_DOCS_ENABLED

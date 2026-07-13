local _, ETBC = ...

ETBC.UI = ETBC.UI or {}
ETBC.UI.ControlCenterModel = ETBC.UI.ControlCenterModel or {}
local Model = ETBC.UI.ControlCenterModel

local CATEGORY = {
  general = "Core", ui = "Core", minimapplus = "Core", visibility = "Core",
  auras = "Combat", combattext = "Combat", actiontracker = "Combat", castbar = "Combat",
  unitframes = "Combat", actionbars = "Combat", swingtimer = "Combat", nameplates = "Combat",
  tooltip = "Utility", sound = "Utility", vendor = "Utility", mailbox = "Utility", mover = "Utility",
  cvars = "Utility", cooldowns = "Utility", objectives = "Utility", autogossip = "Utility",
  chatim = "Social", friends = "Social",
}
local CATEGORY_ORDER = { "Core", "Combat", "Utility", "Social", "Other" }
local APPEARANCE = { color=true, alpha=true, font=true, size=true, scale=true, width=true, height=true, texture=true, icon=true, border=true }
local BEHAVIOR = { behavior=true, mode=true, growth=true, direction=true, timing=true, duration=true, delay=true, throttle=true }
local AUTOMATION = { auto=true, sell=true, repair=true, collect=true, gossip=true, mail=true, vendor=true }
local VISIBILITY = { visibility=true, show=true, hide=true, combat=true, instance=true, party=true, raid=true, solo=true }

local function Text(value, fallback)
  if type(value) == "function" then
    local ok, result = pcall(value)
    if ok then value = result else value = nil end
  end
  if value == nil or value == "" then return fallback or "" end
  return tostring(value)
end

local function InferSection(id, option, depth)
  if depth and depth > 1 then return "Advanced" end
  local hay = (tostring(id or "") .. " " .. Text(option and option.name)):lower()
  for word in pairs(AUTOMATION) do if hay:find(word, 1, true) then return "Automation" end end
  for word in pairs(VISIBILITY) do if hay:find(word, 1, true) then return "Visibility" end end
  for word in pairs(APPEARANCE) do if hay:find(word, 1, true) then return "Appearance" end end
  for word in pairs(BEHAVIOR) do if hay:find(word, 1, true) then return "Behavior" end end
  return "General"
end

local function ResolveOptions(group)
  local options = group and group.options
  if type(options) == "function" then
    local ok, result = pcall(options)
    if not ok then return nil, tostring(result) end
    options = result
  end
  if type(options) ~= "table" then return {}, nil end
  return options.args or options, nil
end

local function FindIntro(args)
  for _, option in pairs(args or {}) do
    if type(option) == "table" and option.type == "description" and (tonumber(option.order) or 1000) <= 5 then
      return Text(option.name)
    end
  end
  return ""
end

local function AddControls(page, args, path, depth, forcedSection)
  local ordered = {}
  for id, option in pairs(args or {}) do
    if type(option) == "table" then ordered[#ordered + 1] = { id = id, option = option } end
  end
  table.sort(ordered, function(a, b)
    local ao, bo = tonumber(a.option.order) or 1000, tonumber(b.option.order) or 1000
    if ao == bo then return tostring(a.id) < tostring(b.id) end
    return ao < bo
  end)

  local activeSection = forcedSection
  for i = 1, #ordered do
    local id, option = ordered[i].id, ordered[i].option
    local optionPath = {}
    for j = 1, #path do optionPath[j] = path[j] end
    optionPath[#optionPath + 1] = id
    if option.type == "header" then
      activeSection = Text(option.name, "General")
    elseif option.type == "group" then
      local sectionName = Text(option.name, "Advanced")
      AddControls(page, option.args, optionPath, (depth or 0) + 1, sectionName)
    elseif option.type ~= "description" then
      local section = activeSection or InferSection(id, option, depth)
      if not page.sections[section] then
        page.sections[section] = { key = section, name = section, controls = {}, advanced = section:lower():find("advanced",1,true) ~= nil }
        page.sectionOrder[#page.sectionOrder + 1] = section
      end
      local control = {
        id = tostring(id), key = page.key .. "." .. table.concat(optionPath, "."), type = option.type or "unknown",
        name = Text(option.name, tostring(id)), description = Text(option.desc), option = option, path = optionPath,
        pageKey = page.key, section = section, order = tonumber(option.order) or 1000,
      }
      control.searchText = (control.name .. " " .. control.description .. " " .. control.key .. " " .. page.name .. " " .. page.category):lower()
      page.sections[section].controls[#page.sections[section].controls + 1] = control
      page.controls[#page.controls + 1] = control
    end
  end
end

function Model:Build()
  local result = { pages = {}, byKey = {}, categories = {}, categoryOrder = CATEGORY_ORDER, search = {} }
  for i = 1, #CATEGORY_ORDER do result.categories[CATEGORY_ORDER[i]] = {} end
  local groups = ETBC.SettingsRegistry and ETBC.SettingsRegistry:GetGroups() or {}
  for i = 1, #groups do
    local group = groups[i]
    local args, err = ResolveOptions(group)
    local page = {
      key = tostring(group.key), name = Text(group.name, group.key), icon = group.icon,
      description = FindIntro(args),
      category = group.category or CATEGORY[group.key] or "Other", sections = {}, sectionOrder = {}, controls = {}, error = err,
    }
    if not result.categories[page.category] then result.categories[page.category] = {} end
    AddControls(page, args, {}, 0)
    result.pages[#result.pages + 1] = page
    result.byKey[page.key] = page
    result.categories[page.category][#result.categories[page.category] + 1] = page
    for j = 1, #page.controls do result.search[#result.search + 1] = page.controls[j] end
  end
  return result
end

function Model:Search(model, query, pageKey)
  query = tostring(query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if query == "" then return {} end
  local words = {}; for word in query:gmatch("%S+") do words[#words + 1] = word end
  local found = {}
  for i = 1, #(model.search or {}) do
    local control = model.search[i]
    if not pageKey or control.pageKey == pageKey then
      local match, score = true, 0
      for j = 1, #words do
        local at = control.searchText:find(words[j], 1, true)
        if not at then match = false break end
        score = score + (at == 1 and 20 or 5)
      end
      if match then found[#found + 1] = { control = control, score = score } end
    end
  end
  table.sort(found, function(a, b) if a.score == b.score then return a.control.name < b.control.name end return a.score > b.score end)
  while #found > 60 do table.remove(found) end
  return found
end

function Model:Resolve(model, target)
  target = tostring(target or "home"):lower()
  if target == "" or target == "dashboard" or target == "home" then return "home" end
  target = target:gsub("[^a-z0-9]", "")
  for key, page in pairs(model.byKey or {}) do
    if key:lower():gsub("[^a-z0-9]", "") == target then return page.key end
  end
  return nil
end

-- UI/ConfigWindow_Data.lua
-- Internal data/tree helpers for EnhanceTBC config window.

local _, ETBC = ...
ETBC.UI = ETBC.UI or {}
local UI = ETBC.UI

UI.ConfigWindow = UI.ConfigWindow or {}
local ConfigWindow = UI.ConfigWindow

ConfigWindow.Internal = ConfigWindow.Internal or {}
ConfigWindow.Internal.Data = ConfigWindow.Internal.Data or {}
local H = ConfigWindow.Internal.Data

if H._loaded then return end
H._loaded = true

function H.GetUIDB()
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

function H.GatherGroups()
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

function H.FindGroup(groups, key)
  for _, g in ipairs(groups) do
    if g.key == key then return g end
  end
  return nil
end

H.KEY_TO_CATEGORY = {
  general = "Core",
  ui = "Core",
  minimapplus = "Core",
  visibility = "Core",

  auras = "Combat",
  combattext = "Combat",
  actiontracker = "Combat",
  castbar = "Combat",
  unitframes = "Combat",
  actionbars = "Combat",
  swingtimer = "Combat",
  nameplates = "Combat",

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

function H.BuildTree(groups)
  local buckets = {}
  for _, c in ipairs(CATEGORY_ORDER) do buckets[c] = {} end

  for _, g in ipairs(groups) do
    local cat = g.category
    if not cat or cat == "" or cat == "Other" then
      cat = H.KEY_TO_CATEGORY[g.key] or "Other"
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

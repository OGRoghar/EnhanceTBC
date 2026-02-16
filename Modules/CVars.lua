-- Modules/CVars.lua
-- EnhanceTBC - CVar Exposure + Reset Categories + CVar discovery/hide-if-missing
-- Build: TBC Anniversary 20505
-- Logic lives here; Settings/Settings_CVars.lua registers the options UI.

local ADDON_NAME, ETBC = ...

ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.CVars = mod

-- -----------------------------
-- DB
-- -----------------------------
local function GetDB()
  ETBC.db.profile.cvars = ETBC.db.profile.cvars or {}
  local db = ETBC.db.profile.cvars
  if db.enabled == nil then db.enabled = true end
  if db.showMissing == nil then db.showMissing = false end -- show unsupported/missing CVars for debugging
  return db
end

-- -----------------------------
-- CVar discovery
-- -----------------------------
local function CVarExists(name)
  if type(name) ~= "string" or name == "" then return false end

  -- Prefer GetCVarInfo if available (best signal for existence)
  if type(GetCVarInfo) == "function" then
    local ok, value = pcall(GetCVarInfo, name)
    -- In Classic/TBC, first return is current value; nil usually means unknown CVar
    if ok and value ~= nil then
      return true
    end
  end

  -- Some clients have C_CVar APIs (varies). Safe-guard and treat non-nil as exists.
  if C_CVar and type(C_CVar.GetCVarInfo) == "function" then
    local ok, info = pcall(C_CVar.GetCVarInfo, name)
    if ok and info ~= nil then
      return true
    end
  end

  -- Last resort: if GetCVar returns nil (rare), treat as missing.
  if type(GetCVar) == "function" then
    local ok, v = pcall(GetCVar, name)
    if ok and v ~= nil then
      -- Warning: some clients may return "" for unknown; treat "" as missing.
      if v ~= "" then return true end
    end
  end

  return false
end

local function ShouldHideOptionForCVar(name)
  local db = GetDB()
  if db.showMissing then return false end
  return not CVarExists(name)
end

-- -----------------------------
-- Safe CVar wrappers
-- -----------------------------
local function _GetCVar(name)
  return GetCVar(name)
end

local function _SetCVar(name, value, perChar)
  if perChar and SetCVarPerCharacter then
    SetCVarPerCharacter(name, value)
  else
    SetCVar(name, value)
  end
end

local function CVarBoolGet(name)
  local v = _GetCVar(name)
  return (v == "1" or v == "true")
end

local function CVarBoolSet(name, on, perChar)
  _SetCVar(name, on and "1" or "0", perChar)
end

local function CVarNumGet(name, default)
  local v = tonumber(_GetCVar(name))
  if v == nil then return default end
  return v
end

local function CVarNumSet(name, num, perChar)
  if num == nil then return end
  _SetCVar(name, tostring(num), perChar)
end

local function CVarStrGet(name, default)
  local v = _GetCVar(name)
  if v == nil or v == "" then return default end
  return v
end

local function CVarStrSet(name, str, perChar)
  if str == nil then return end
  _SetCVar(name, tostring(str), perChar)
end

-- -----------------------------
-- Refresh nudges (safe)
-- -----------------------------
local function RefreshNameplates()
  if NamePlateDriverFrame and NamePlateDriverFrame.UpdateNamePlateOptions then
    NamePlateDriverFrame:UpdateNamePlateOptions()
  end
end

local function RefreshWorldMap()
  -- Map CVars generally apply immediately in Classic/TBC; nothing required.
end

local function RefreshTooltips()
  -- Tooltip CVars usually apply on next show; nothing required.
end

-- -----------------------------
-- Defaults + Reset
-- -----------------------------
local CATEGORY_DEFAULTS = {
  convenience = {
    { cvar = "autoDismount", type = "bool", value = true,  perChar = true },
    { cvar = "autoDismountFlying", type = "bool", value = true,  perChar = true },
    { cvar = "autoLootDefault", type = "bool", value = false, perChar = true },
  },

  help = {
    { cvar = "showTutorials", type = "bool", value = true, perChar = true },
  },

  tooltips = {
    { cvar = "showTargetOfTarget", type = "bool", value = true, perChar = true },
    { cvar = "UberTooltips", type = "bool", value = true, perChar = true },
  },

  nameplates = {
    { cvar = "nameplateShowEnemies", type = "bool", value = true,  perChar = true },
    { cvar = "nameplateShowFriends", type = "bool", value = false, perChar = true },
    { cvar = "nameplateShowFriendlyNPCs", type = "bool", value = false, perChar = true },
    { cvar = "nameplateShowFriendlyMinions", type = "bool", value = false, perChar = true },

    { cvar = "nameplateMotion", type = "string", value = "0", perChar = true }, -- Stack
    { cvar = "nameplateMinAlpha", type = "number", value = 0.6, perChar = true },
  },

  castbars = {
    { cvar = "nameplateShowCastbar", type = "bool", value = true, perChar = true },
  },

  worldmap = {
    { cvar = "mapFade", type = "bool", value = true, perChar = true },
    { cvar = "mapOpacity", type = "number", value = 1.0, perChar = true },
  },

  colors = {
    { cvar = "threatWarning", type = "bool", value = true,  perChar = true },
    { cvar = "ShowClassColorInNameplate", type = "bool", value = true,  perChar = true },
    { cvar = "ShowClassColorInFriendlyNameplate", type = "bool", value = false, perChar = true },
  },
}

function mod:ApplyDefaults(categoryKey)
  local list = CATEGORY_DEFAULTS[categoryKey]
  if not list then return end

  for _, d in ipairs(list) do
    -- Discovery-safe reset: only apply if the CVar exists (unless showMissing is enabled)
    if GetDB().showMissing or CVarExists(d.cvar) then
      if d.type == "bool" then
        CVarBoolSet(d.cvar, d.value and true or false, d.perChar)
      elseif d.type == "number" then
        CVarNumSet(d.cvar, d.value, d.perChar)
      else
        CVarStrSet(d.cvar, d.value, d.perChar)
      end
    end
  end

  if categoryKey == "nameplates" or categoryKey == "castbars" or categoryKey == "colors" then
    RefreshNameplates()
  elseif categoryKey == "worldmap" then
    RefreshWorldMap()
  elseif categoryKey == "tooltips" then
    RefreshTooltips()
  end
end

function mod:ApplyAllDefaults()
  for k in pairs(CATEGORY_DEFAULTS) do
    self:ApplyDefaults(k)
  end
end

-- -----------------------------
-- Option helpers (AceConfig)
-- -----------------------------
local function IsDisabled()
  return not GetDB().enabled
end

local function MakeToggle(args)
  return {
    type = "toggle",
    name = args.name,
    desc = args.desc,
    width = args.width,
    order = args.order,
    disabled = IsDisabled,
    hidden = function()
      if args.hideIfMissing == false then return false end
      return ShouldHideOptionForCVar(args.cvar)
    end,
    get = function()
      return CVarBoolGet(args.cvar)
    end,
    set = function(_, v)
      -- If hidden normally but showMissing is enabled, allow toggling anyway.
      CVarBoolSet(args.cvar, v, args.perChar)
      if args.onChange then args.onChange(v) end
    end,
  }
end

local function MakeRange(args)
  return {
    type = "range",
    name = args.name,
    desc = args.desc,
    min = args.min,
    max = args.max,
    step = args.step or 1,
    bigStep = args.bigStep,
    width = args.width,
    order = args.order,
    disabled = IsDisabled,
    hidden = function()
      if args.hideIfMissing == false then return false end
      return ShouldHideOptionForCVar(args.cvar)
    end,
    get = function()
      return CVarNumGet(args.cvar, args.default or args.min)
    end,
    set = function(_, v)
      CVarNumSet(args.cvar, v, args.perChar)
      if args.onChange then args.onChange(v) end
    end,
  }
end

local function MakeSelect(args)
  return {
    type = "select",
    name = args.name,
    desc = args.desc,
    values = args.values,
    width = args.width,
    order = args.order,
    disabled = IsDisabled,
    hidden = function()
      if args.hideIfMissing == false then return false end
      return ShouldHideOptionForCVar(args.cvar)
    end,
    get = function()
      return CVarStrGet(args.cvar, args.default)
    end,
    set = function(_, v)
      CVarStrSet(args.cvar, v, args.perChar)
      if args.onChange then args.onChange(v) end
    end,
  }
end

local function MakeResetButton(args)
  return {
    type = "execute",
    name = args.name,
    desc = args.desc,
    order = args.order,
    width = args.width or "full",
    confirm = true,
    confirmText = args.confirmText or "Reset this category to defaults?",
    disabled = IsDisabled,
    func = function()
      mod:ApplyDefaults(args.categoryKey)
    end,
  }
end

-- -----------------------------
-- Public: Build the options table (Settings file registers it)
-- -----------------------------
function mod:BuildOptions()
  -- Ensure DB exists as soon as options panel opens
  GetDB()

  return {
    type = "group",
    name = "CVars",
    order = 60,
    args = {
      header = { type = "header", name = "Interface CVars (20505)", order = 0 },
      
      infoBox = {
        type = "description",
        name = "|cffffaa00Note:|r Most CVars apply immediately. Some may require a UI reload (/reload) to take full effect.",
        order = 0.5,
        width = "full",
      },

      enabled = {
        type = "toggle",
        name = "Enable CVar Controls",
        desc = "If disabled, EnhanceTBC will not change CVars from this panel.",
        order = 1,
        get = function() return GetDB().enabled end,
        set = function(_, v) GetDB().enabled = v end,
      },

      showMissing = {
        type = "toggle",
        name = "Show Unsupported CVars (Debug)",
        desc = "If enabled, shows CVars even if the client doesn't report them as valid (useful for testing).",
        order = 2,
        width = "full",
        get = function() return GetDB().showMissing end,
        set = function(_, v) GetDB().showMissing = v end,
      },

      resetAll = {
        type = "execute",
        name = "Reset ALL CVar Categories",
        desc = "Resets all categories below to their defaults (only applies CVars that exist, unless Debug is enabled).",
        order = 3,
        width = "full",
        confirm = true,
        confirmText = "Reset ALL CVar categories to defaults?",
        disabled = IsDisabled,
        func = function() mod:ApplyAllDefaults() end,
      },

      spacer1 = { type = "description", name = " ", order = 4 },

      -- Convenience
      gameplayHeader = { type = "header", name = "Convenience", order = 10 },
      gameplayReset = MakeResetButton({ name = "Reset Convenience", desc = "Reset convenience CVars to defaults.", categoryKey = "convenience", order = 11 }),

      autoDismount = MakeToggle({ name = "Auto Dismount", desc = "Automatically dismount when casting or using abilities.", cvar = "autoDismount", perChar = true, order = 12 }),
      autoDismountFlying = MakeToggle({ name = "Auto Dismount (Flying)", desc = "Automatically dismount while flying when using abilities (if supported).", cvar = "autoDismountFlying", perChar = true, order = 13 }),
      autoLootDefault = MakeToggle({ name = "Auto Loot (Default)", desc = "Makes auto-loot the default loot behavior.", cvar = "autoLootDefault", perChar = true, order = 14 }),

      spacer10 = { type = "description", name = " ", order = 15 },

      -- Help & Tutorials
      helpHeader = { type = "header", name = "Help & Tutorials", order = 20 },
      helpReset = MakeResetButton({ name = "Reset Help & Tutorials", desc = "Reset tutorial CVars to defaults.", categoryKey = "help", order = 21 }),

      showTutorials = MakeToggle({ name = "Show Tutorials", desc = "Enable/disable Blizzard tutorial popups.", cvar = "showTutorials", perChar = true, order = 22 }),

      spacer20 = { type = "description", name = " ", order = 23 },

      -- Tooltips
      tooltipHeader = { type = "header", name = "Tooltips", order = 30 },
      tooltipReset = MakeResetButton({ name = "Reset Tooltips", desc = "Reset tooltip CVars to defaults.", categoryKey = "tooltips", order = 31 }),

      showTargetOfTarget = MakeToggle({
        name = "Show Target of Target in Tooltip",
        desc = "Displays the target's target in tooltips (if supported).",
        cvar = "showTargetOfTarget",
        perChar = true,
        order = 32,
        onChange = RefreshTooltips,
      }),

      uberTooltips = MakeToggle({
        name = "Enhanced Tooltips",
        desc = "Classic-style enhanced tooltips (client dependent).",
        cvar = "UberTooltips",
        perChar = true,
        order = 33,
        onChange = RefreshTooltips,
      }),

      spacer30 = { type = "description", name = " ", order = 34 },

      -- Nameplates
      nameplateHeader = { type = "header", name = "Nameplates", order = 40 },
      nameplateReset = MakeResetButton({ name = "Reset Nameplates", desc = "Reset nameplate CVars to defaults.", categoryKey = "nameplates", order = 41 }),

      nameplateShowEnemies = MakeToggle({ name = "Show Enemy Nameplates", desc = "Toggles enemy nameplates.", cvar = "nameplateShowEnemies", perChar = true, order = 42, onChange = RefreshNameplates }),
      nameplateShowFriends = MakeToggle({ name = "Show Friendly Nameplates", desc = "Toggles friendly nameplates.", cvar = "nameplateShowFriends", perChar = true, order = 43, onChange = RefreshNameplates }),
      nameplateShowFriendlyNPCs = MakeToggle({ name = "Show Friendly NPC Nameplates", desc = "Toggles friendly NPC nameplates (if supported).", cvar = "nameplateShowFriendlyNPCs", perChar = true, order = 44, onChange = RefreshNameplates }),
      nameplateShowFriendlyMinions = MakeToggle({ name = "Show Friendly Minion Nameplates", desc = "Toggles friendly minion nameplates (if supported).", cvar = "nameplateShowFriendlyMinions", perChar = true, order = 45, onChange = RefreshNameplates }),

      nameplateMotion = MakeSelect({
        name = "Nameplate Motion",
        desc = "How nameplates move when units overlap.",
        cvar = "nameplateMotion",
        values = { ["0"] = "Stack", ["1"] = "Spread", ["2"] = "Overlap" },
        default = "0",
        perChar = true,
        order = 46,
        onChange = RefreshNameplates,
      }),

      nameplateMinAlpha = MakeRange({
        name = "Nameplate Min Alpha",
        desc = "Minimum transparency for distant nameplates (if supported).",
        cvar = "nameplateMinAlpha",
        min = 0,
        max = 1,
        step = 0.05,
        default = 0.6,
        perChar = true,
        order = 47,
        onChange = RefreshNameplates,
      }),

      spacer40 = { type = "description", name = " ", order = 48 },

      -- Castbars
      castbarHeader = { type = "header", name = "Castbars", order = 50 },
      castbarReset = MakeResetButton({ name = "Reset Castbars", desc = "Reset castbar CVars to defaults.", categoryKey = "castbars", order = 51 }),

      showNameplateCastbar = MakeToggle({
        name = "Show Nameplate Castbars",
        desc = "Shows castbars on nameplates (client dependent).",
        cvar = "nameplateShowCastbar",
        perChar = true,
        order = 52,
        onChange = RefreshNameplates,
      }),

      spacer50 = { type = "description", name = " ", order = 53 },

      -- World Map
      mapHeader = { type = "header", name = "World Map", order = 60 },
      mapReset = MakeResetButton({ name = "Reset World Map", desc = "Reset map CVars to defaults.", categoryKey = "worldmap", order = 61 }),

      mapFade = MakeToggle({ name = "Map Fade While Moving", desc = "Fades the world map while moving.", cvar = "mapFade", perChar = true, order = 62, onChange = RefreshWorldMap }),
      mapOpacity = MakeRange({ name = "Map Opacity", desc = "World map opacity.", cvar = "mapOpacity", min = 0, max = 1, step = 0.05, default = 1.0, perChar = true, order = 63, onChange = RefreshWorldMap }),

      spacer60 = { type = "description", name = " ", order = 64 },

      -- Colors
      colorHeader = { type = "header", name = "Colors", order = 70 },
      colorReset = MakeResetButton({ name = "Reset Colors", desc = "Reset color-related CVars to defaults.", categoryKey = "colors", order = 71 }),

      threatWarning = MakeToggle({ name = "Threat Warning", desc = "Enable threat warning visuals.", cvar = "threatWarning", perChar = true, order = 72 }),

      showClassColorInNameplate = MakeToggle({
        name = "Class Colors on Nameplates",
        desc = "Use class colors for nameplate health bars (client dependent).",
        cvar = "ShowClassColorInNameplate",
        perChar = true,
        order = 73,
        onChange = RefreshNameplates,
      }),

      showClassColorInFriendlyNameplate = MakeToggle({
        name = "Class Colors on Friendly Nameplates",
        desc = "Use class colors for friendly nameplate health bars (client dependent).",
        cvar = "ShowClassColorInFriendlyNameplate",
        perChar = true,
        order = 74,
        onChange = RefreshNameplates,
      }),
    },
  }
end

function mod:Init()
  -- Options-driven module; nothing required at runtime.
end

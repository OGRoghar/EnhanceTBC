-- Settings/Settings_MinimapPlus.lua
-- AceConfig options for Modules/MinimapPlus.lua

local ADDON_NAME, ETBC = ...

ETBC.Settings = ETBC.Settings or {}

local function EnsureDefaults()
  if not ETBC.db or not ETBC.db.profile then return end

  ETBC.db.profile.minimapPlus = ETBC.db.profile.minimapPlus or {}
  local db = ETBC.db.profile.minimapPlus

  if db.enabled == nil then db.enabled = true end

  -- Ensure nested tables used by options exist
  db.landingButtons = db.landingButtons or {}
end

local function GetDB()
  EnsureDefaults()
  return ETBC.db.profile.minimapPlus
end

local function Apply()
  if ETBC.ApplyBus and ETBC.ApplyBus.Notify then
    ETBC.ApplyBus:Notify("minimapplus")
  elseif ETBC.Modules and ETBC.Modules.MinimapPlus and ETBC.Modules.MinimapPlus.Apply then
    ETBC.Modules.MinimapPlus:Apply()
  end
end

ETBC.Settings.MinimapPlus = function()
  EnsureDefaults()

  local opts = {
    type = "group",
    name = "Minimap",
    order = 30,
    args = {
      enabled = {
        type = "toggle",
        name = "Enable",
        order = 1,
        width = "full",
        get = function() return GetDB().enabled end,
        set = function(_, v)
          GetDB().enabled = v and true or false
          Apply()
        end,
      },

      sinkHeader = {
        type = "header",
        name = "Minimap Button Sink",
        order = 10,
      },

      sinkEnabled = {
        type = "toggle",
        name = "Enable Button Sink",
        order = 11,
        get = function() return GetDB().sinkEnabled end,
        set = function(_, v) GetDB().sinkEnabled = v; Apply() end,
      },

      locked = {
        type = "toggle",
        name = "Lock Sink",
        order = 12,
        desc = "When locked, you can't drag the sink.",
        get = function() return GetDB().locked end,
        set = function(_, v) GetDB().locked = v; Apply() end,
      },

      scale = {
        type = "range",
        name = "Sink Scale",
        order = 13,
        min = 0.6, max = 1.5, step = 0.01,
        get = function() return GetDB().scale end,
        set = function(_, v) GetDB().scale = v; Apply() end,
      },

      buttonSize = {
        type = "range",
        name = "Button Size",
        order = 14,
        min = 18, max = 44, step = 1,
        get = function() return GetDB().buttonSize end,
        set = function(_, v) GetDB().buttonSize = v; Apply() end,
      },

      padding = {
        type = "range",
        name = "Padding",
        order = 15,
        min = 0, max = 16, step = 1,
        get = function() return GetDB().padding end,
        set = function(_, v) GetDB().padding = v; Apply() end,
      },

      columns = {
        type = "range",
        name = "Columns",
        order = 16,
        min = 1, max = 12, step = 1,
        get = function() return GetDB().columns end,
        set = function(_, v) GetDB().columns = v; Apply() end,
      },

      growDown = {
        type = "toggle",
        name = "Grow Down",
        order = 17,
        get = function() return GetDB().growDown end,
        set = function(_, v) GetDB().growDown = v; Apply() end,
      },

      backdrop = {
        type = "toggle",
        name = "Show Backdrop/Border",
        order = 18,
        get = function() return GetDB().backdrop end,
        set = function(_, v) GetDB().backdrop = v; Apply() end,
      },

      autoScan = {
        type = "toggle",
        name = "Auto-Scan (catch late-loading buttons)",
        order = 19,
        get = function() return GetDB().autoScan end,
        set = function(_, v) GetDB().autoScan = v; Apply() end,
      },

      scanInterval = {
        type = "range",
        name = "Scan Interval (seconds)",
        order = 20,
        min = 0.5, max = 10, step = 0.5,
        get = function() return GetDB().scanInterval end,
        set = function(_, v) GetDB().scanInterval = v; Apply() end,
      },

      includeHeader = {
        type = "header",
        name = "Include Blizzard Widgets in Sink",
        order = 30,
      },

      includeQueue = {
        type = "toggle",
        name = "Queue Status",
        order = 31,
        get = function() return GetDB().includeQueue end,
        set = function(_, v) GetDB().includeQueue = v; Apply() end,
      },

      includeTracking = {
        type = "toggle",
        name = "Tracking Button",
        order = 32,
        get = function() return GetDB().includeTracking end,
        set = function(_, v) GetDB().includeTracking = v; Apply() end,
      },

      includeCalendar = {
        type = "toggle",
        name = "Calendar (Game Time)",
        order = 33,
        get = function() return GetDB().includeCalendar end,
        set = function(_, v) GetDB().includeCalendar = v; Apply() end,
      },

      includeClock = {
        type = "toggle",
        name = "Clock Button",
        order = 34,
        get = function() return GetDB().includeClock end,
        set = function(_, v) GetDB().includeClock = v; Apply() end,
      },

      includeMail = {
        type = "toggle",
        name = "Mail Icon",
        order = 35,
        get = function() return GetDB().includeMail end,
        set = function(_, v) GetDB().includeMail = v; Apply() end,
      },

      includeDifficulty = {
        type = "toggle",
        name = "Instance Difficulty",
        order = 36,
        get = function() return GetDB().includeDifficulty end,
        set = function(_, v) GetDB().includeDifficulty = v; Apply() end,
      },

      minimapHeader = {
        type = "header",
        name = "Minimap Shape / Difficulty Icon",
        order = 50,
      },

      squareMinimap = {
        type = "toggle",
        name = "Square Minimap",
        order = 51,
        get = function() return GetDB().squareMinimap end,
        set = function(_, v) GetDB().squareMinimap = v; Apply() end,
      },

      squareSize = {
        type = "range",
        name = "Square Size",
        order = 52,
        min = 100, max = 220, step = 1,
        disabled = function() return not GetDB().squareMinimap end,
        get = function() return GetDB().squareSize end,
        set = function(_, v) GetDB().squareSize = v; Apply() end,
      },

      customDifficultyIcon = {
        type = "toggle",
        name = "Custom Difficulty Icon (subtle)",
        order = 53,
        get = function() return GetDB().customDifficultyIcon end,
        set = function(_, v) GetDB().customDifficultyIcon = v; Apply() end,
      },

      hideHeader = {
        type = "header",
        name = "Hides",
        order = 70,
      },

      hideMinimapToggleButton = {
        type = "toggle",
        name = "Hide EnhanceTBC Minimap Button (if present)",
        order = 71,
        get = function() return GetDB().hideMinimapToggleButton end,
        set = function(_, v) GetDB().hideMinimapToggleButton = v; Apply() end,
      },

      hideBagsBar = {
        type = "toggle",
        name = "Hide Bags Bar",
        order = 72,
        get = function() return GetDB().hideBagsBar end,
        set = function(_, v) GetDB().hideBagsBar = v; Apply() end,
      },

      hideMicroMenu = {
        type = "toggle",
        name = "Hide Micro Menu",
        order = 73,
        get = function() return GetDB().hideMicroMenu end,
        set = function(_, v) GetDB().hideMicroMenu = v; Apply() end,
      },

      hideQuickJoinToast = {
        type = "toggle",
        name = "Hide Quick Join Toast (if present)",
        order = 74,
        get = function() return GetDB().hideQuickJoinToast end,
        set = function(_, v) GetDB().hideQuickJoinToast = v; Apply() end,
      },

      hideRaidToolsInParty = {
        type = "toggle",
        name = "Hide Raid Tools when in Party (not Raid)",
        order = 75,
        get = function() return GetDB().hideRaidToolsInParty end,
        set = function(_, v) GetDB().hideRaidToolsInParty = v; Apply() end,
      },

      landingHeader = {
        type = "header",
        name = "Landing Page Buttons",
        order = 90,
      },

      landingExpansion = {
        type = "toggle",
        name = "Show Expansion Landing Button (if present)",
        order = 91,
        get = function() return GetDB().landingButtons.ExpansionLandingPageMinimapButton end,
        set = function(_, v) GetDB().landingButtons.ExpansionLandingPageMinimapButton = v; Apply() end,
      },

      landingGarrison = {
        type = "toggle",
        name = "Show Garrison Landing Button (if present)",
        order = 92,
        get = function() return GetDB().landingButtons.GarrisonLandingPageMinimapButton end,
        set = function(_, v) GetDB().landingButtons.GarrisonLandingPageMinimapButton = v; Apply() end,
      },

      landingQueue = {
        type = "toggle",
        name = "Show Queue Status Button (if present)",
        order = 93,
        get = function() return GetDB().landingButtons.QueueStatusMinimapButton end,
        set = function(_, v) GetDB().landingButtons.QueueStatusMinimapButton = v; Apply() end,
      },

      quickHeader = {
        type = "header",
        name = "Quick Spec / Loot Switching",
        order = 110,
      },

      quickEnabled = {
        type = "toggle",
        name = "Enable Quick Menu (right-click sink)",
        order = 111,
        get = function() return GetDB().quickEnabled end,
        set = function(_, v) GetDB().quickEnabled = v; Apply() end,
      },

      defaultLootMethod = {
        type = "select",
        name = "Default Loot Method",
        order = 112,
        values = {
          group = "Group Loot",
          freeforall = "Free For All",
          roundrobin = "Round Robin",
          needbeforegreed = "Need Before Greed",
          master = "Master Loot",
        },
        get = function() return GetDB().defaultLootMethod end,
        set = function(_, v) GetDB().defaultLootMethod = v end,
      },

      defaultLootThreshold = {
        type = "select",
        name = "Default Loot Threshold",
        order = 113,
        values = {
          [2] = "Uncommon (Green)",
          [3] = "Rare (Blue)",
          [4] = "Epic (Purple)",
        },
        get = function() return tonumber(GetDB().defaultLootThreshold) or 2 end,
        set = function(_, v) GetDB().defaultLootThreshold = v end,
      },

      applyNow = {
        type = "execute",
        name = "Apply Now",
        order = 999,
        width = "full",
        func = function() Apply() end,
      },
    },
  }

  return opts
end

-- Register into SettingsRegistry so Options/Options.lua + ConfigWindow can see it
if ETBC.SettingsRegistry and ETBC.SettingsRegistry.RegisterGroup then
  ETBC.SettingsRegistry:RegisterGroup("minimapplus", {
    name = "Minimap+",
    order = 35,
    category = "Core",
    options = function()
      return ETBC.Settings.MinimapPlus()
    end,
  })
end

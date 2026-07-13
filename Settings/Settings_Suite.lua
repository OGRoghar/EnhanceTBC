local _, ETBC = ...

local function Toggle(feature)
  local state = ETBC.FeatureSuite and ETBC.FeatureSuite:GetState(feature)
  return state and state.enabled or false
end

local function Set(feature, value)
  if not ETBC.FeatureSuite then return end
  local ok, reason = ETBC.FeatureSuite:SetEnabled(feature, value and true or false)
  if not ok and ETBC.Print then ETBC:Print("Could not change " .. feature .. ": " .. tostring(reason)) end
end

ETBC.SettingsRegistry:RegisterGroup("suite", {
  name = "Next Generation",
  order = 2,
  options = function()
    return {
      description = {
        type = "description",
        name = "Optional integrated UI systems. Existing EnhanceTBC modules remain available.",
        order = 1,
        width = "full",
      },
      hud = {
        type = "toggle", name = "HUD Studio", order = 2,
        desc = "Custom player and target frames plus no-code condition trackers.",
        get = function() return Toggle("hud") end,
        set = function(_, value) Set("hud", value) end,
      },
      inventory = {
        type = "toggle", name = "Inventory Intelligence", order = 3,
        desc = "Equipment auditing and enhancements to Blizzard inventory surfaces.",
        get = function() return Toggle("inventory") end,
        set = function(_, value) Set("inventory", value) end,
      },
      combat = {
        type = "toggle", name = "Combat Suite", order = 4,
        desc = "Bounded local combat segments, actor totals, utility events, and death records.",
        get = function() return Toggle("combat") end,
        set = function(_, value) Set("combat", value) end,
      },
      edit = {
        type = "execute", name = "Enter Edit Mode", order = 5,
        func = function() if ETBC.FeatureSuite then ETBC.FeatureSuite:SetEditMode(true, "all") end end,
      },
      setup = {
        type = "execute", name = "Open Setup Wizard", order = 6,
        func = function() if ETBC.OpenSuiteSetup then ETBC:OpenSuiteSetup() end end,
      },
    }
  end,
})

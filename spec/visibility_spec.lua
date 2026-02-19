-- spec/visibility_spec.lua
-- Tests for Visibility/Visibility.lua

require('spec.wow_mocks')

describe("Visibility", function()
  local ETBC
  local ADDON_NAME = "EnhanceTBC"

  local function loadVisibilityModule()
    local chunk, err = loadfile('Visibility/Visibility.lua')
    if not chunk then
      error("Failed to load Visibility/Visibility.lua: " .. tostring(err))
    end
    chunk(ADDON_NAME, ETBC)
  end

  before_each(function()
    _G.UnitAffectingCombat = function() return nil end
    _G.IsInGroup = function() return false end
    _G.IsInRaid = function() return false end
    _G.IsInInstance = function() return false, "none" end
    _G.UnitExists = function() return false end
    _G.IsResting = function() return false end
    _G.IsMounted = function() return false end
    _G.UnitIsDeadOrGhost = function() return false end

    ETBC = {
      db = {
        profile = {
          general = { enabled = true },
          visibility = {
            enabled = true,
            throttle = 0,
            presets = {},
            modulePresets = {},
          },
        },
      },
      ApplyBus = {
        Notify = function() end,
        Register = function() end,
      },
      Modules = {},
    }

    loadVisibilityModule()
  end)

  it("evaluates ALWAYS mode with invert correctly", function()
    assert.is_true(ETBC.Visibility:Evaluate({ mode = "ALWAYS" }))
    assert.is_false(ETBC.Visibility:Evaluate({ mode = "ALWAYS", invert = true }))
  end)

  it("evaluates custom rule requirements correctly", function()
    local rule = {
      mode = "CUSTOM",
      requireOutOfCombat = true,
      requireNoTarget = true,
      instance = { world = true },
    }

    assert.is_true(ETBC.Visibility:Evaluate(rule))

    _G.UnitExists = function(unit)
      return unit == "target"
    end

    assert.is_false(ETBC.Visibility:Evaluate(rule))
  end)

  it("uses modulePresets in Allowed() when no legacy rule is active", function()
    ETBC.db.profile.visibility.modulePresets.combattext = {
      mode = "CUSTOM",
      requireCombat = true,
    }

    assert.is_false(ETBC.Modules.Visibility:Allowed("combattext"))

    _G.UnitAffectingCombat = function(unit)
      if unit == "player" then return 1 end
      return nil
    end

    assert.is_true(ETBC.Modules.Visibility:Allowed("combattext"))
  end)

  it("prefers legacy module rules over modulePresets in Allowed()", function()
    ETBC.db.profile.visibility.modulePresets.combattext = {
      mode = "ALWAYS",
    }

    ETBC.db.profile.visibility.modules = {
      combattext = {
        enabled = true,
        inCombat = true,
      }
    }

    assert.is_false(ETBC.Modules.Visibility:Allowed("combattext"))

    _G.UnitAffectingCombat = function(unit)
      if unit == "player" then return 1 end
      return nil
    end

    assert.is_true(ETBC.Modules.Visibility:Allowed("combattext"))
  end)

  it("binds a frame and updates shown state on ForceUpdate", function()
    local shown = nil
    local frame = {
      SetShown = function(_, v)
        shown = v and true or false
      end,
      IsProtected = function() return false end,
    }

    ETBC.Visibility:Bind("test", frame, function()
      return {
        mode = "CUSTOM",
        requireNoTarget = true,
      }
    end)

    assert.is_true(shown)

    _G.UnitExists = function(unit)
      return unit == "target"
    end

    ETBC.Visibility:ForceUpdate()
    assert.is_false(shown)
  end)
end)

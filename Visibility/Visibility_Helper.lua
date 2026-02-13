-- Visibility/Visibility_Helper.lua
local ADDON_NAME, ETBC = ...

ETBC.Visibility = ETBC.Visibility or {}
local V = ETBC.Visibility

-- IMPORTANT:
-- Do NOT define V:Evaluate here. Modules/Visibility.lua owns V:Evaluate(ruleTableOrPresetKey).
-- This helper provides a small string-based evaluator under a different name.

function V:EvaluateSimple(condition)
  if not condition or condition == "" then
    return true
  end

  condition = tostring(condition):lower()

  if condition == "always" then return true end
  if condition == "never" then return false end

  if condition == "incombat" then
    if UnitAffectingCombat then
      return UnitAffectingCombat("player") and true or false
    end
    return false
  end

  if condition == "outofcombat" then
    if UnitAffectingCombat then
      return (not UnitAffectingCombat("player")) and true or false
    end
    return true
  end

  -- Unknown condition defaults to true (safe)
  return true
end

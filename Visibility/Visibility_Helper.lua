-- Visibility/Visibility_Helper.lua
local ADDON_NAME, ETBC = ...

ETBC.Visibility = ETBC.Visibility or {}
local V = ETBC.Visibility

-- Lightweight, safe condition evaluation.
-- Later we can expand to full macro-like condition strings.
function V:Evaluate(condition)
  if not condition or condition == "" then
    return true
  end

  condition = tostring(condition):lower()

  if condition == "always" then return true end
  if condition == "never" then return false end

  if condition == "incombat" then
    return UnitAffectingCombat("player") and true or false
  end

  if condition == "outofcombat" then
    return (not UnitAffectingCombat("player")) and true or false
  end

  -- Unknown condition defaults to true (safe)
  return true
end

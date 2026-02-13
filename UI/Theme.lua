-- UI/Theme.lua
local ADDON_NAME, ETBC = ...

ETBC.Theme = ETBC.Theme or {}

ETBC.Theme.Palettes = {
  WarcraftGreen = {
    bg = {0.05, 0.07, 0.05, 0.95},
    panel = {0.10, 0.13, 0.10, 0.92},
    border = {0.15, 0.30, 0.15, 1.00},
    text = {0.90, 0.95, 0.90, 1.00},
    accent = {0.20, 1.00, 0.20, 1.00},
    accent2 = {0.12, 0.55, 0.12, 1.00},
  },
  BlackSteel = {
    bg = {0.05, 0.05, 0.06, 0.96},
    panel = {0.10, 0.10, 0.12, 0.92},
    border = {0.30, 0.30, 0.35, 1.00},
    text = {0.92, 0.92, 0.95, 1.00},
    accent = {0.20, 1.00, 0.20, 1.00},
    accent2 = {0.35, 0.75, 0.35, 1.00},
  },
}

function ETBC.Theme:Get()
  local p = ETBC.db and ETBC.db.profile and ETBC.db.profile.general and ETBC.db.profile.general.ui
  local key = (p and p.theme) or "WarcraftGreen"
  return ETBC.Theme.Palettes[key] or ETBC.Theme.Palettes.WarcraftGreen
end

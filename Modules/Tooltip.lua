-- Modules/Tooltip.lua
-- EnhanceTBC - Tooltip enhancements (safe on TBC Anniversary client 20505)
-- Fix: avoid Texture:SetGradientAlpha (not available on this client). Use solid tint fallback.

local ADDON_NAME, ETBC = ...

ETBC.Modules = ETBC.Modules or {}
local mod = ETBC.Modules.Tooltip or {}
ETBC.Modules.Tooltip = mod

mod.key = "tooltip"
mod._hooked = false

-- ---------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------
local function GetDB()
  if not ETBC.db or not ETBC.db.profile then return nil end
  ETBC.db.profile.tooltip = ETBC.db.profile.tooltip or {}
  local db = ETBC.db.profile.tooltip
  if db.enabled == nil then db.enabled = true end
  return db
end

local function SafeSetBackdrop(frame, bg, edge, edgeSize, insets)
  if not frame or not frame.SetBackdrop then return end
  frame:SetBackdrop({
    bgFile = bg or "Interface\\Buttons\\WHITE8x8",
    edgeFile = edge or "Interface\\Buttons\\WHITE8x8",
    tile = false,
    edgeSize = edgeSize or 1,
    insets = insets or { left = 1, right = 1, top = 1, bottom = 1 },
  })
end

local function SetBackdropColor(frame, r, g, b, a)
  if frame and frame.SetBackdropColor then
    frame:SetBackdropColor(r, g, b, a)
  end
end

local function SetBackdropBorderColor(frame, r, g, b, a)
  if frame and frame.SetBackdropBorderColor then
    frame:SetBackdropBorderColor(r, g, b, a)
  end
end

-- Solid “accent” line helper (replaces gradient)
local function EnsureAccentLine(tip)
  if tip._etbcAccentLine then return tip._etbcAccentLine end

  local line = tip:CreateTexture(nil, "BORDER")
  line:SetTexture("Interface\\Buttons\\WHITE8x8")
  line:SetHeight(2)
  line:SetPoint("TOPLEFT", tip, "TOPLEFT", 2, -2)
  line:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -2, -2)
  tip._etbcAccentLine = line
  return line
end

local function ApplyStyleToTooltip(tip)
  local db = GetDB()
  if not db or not db.enabled then return end
  if not tip or not tip.GetName then return end

  -- Avoid styling some internal frames if needed
  local name = tip:GetName()
  if name and name:find("ShoppingTooltip", 1, true) and not db.styleCompareTooltips then
    return
  end

  -- Backdrop
  if db.styleBackdrop then
    SafeSetBackdrop(tip, "Interface\\Buttons\\WHITE8x8", "Interface\\Buttons\\WHITE8x8", db.borderSize or 1)
    local bg = db.backdropColor or { r = 0.05, g = 0.07, b = 0.05, a = 0.95 }
    local br = db.borderColor or { r = 0.12, g = 0.20, b = 0.12, a = 0.95 }
    SetBackdropColor(tip, bg.r or 0, bg.g or 0, bg.b or 0, bg.a or 1)
    SetBackdropBorderColor(tip, br.r or 1, br.g or 1, br.b or 1, br.a or 1)
  end

  -- Accent line (solid, safe)
  if db.accentLine then
    local line = EnsureAccentLine(tip)
    local ac = db.accentColor or { r = 0.20, g = 1.00, b = 0.20, a = 0.65 }
    line:SetVertexColor(ac.r or 1, ac.g or 1, ac.b or 1, ac.a or 1)
    line:Show()
  else
    if tip._etbcAccentLine then tip._etbcAccentLine:Hide() end
  end

  -- Scale
  if db.scale and type(db.scale) == "number" then
    tip:SetScale(db.scale)
  end
end

-- ---------------------------------------------------------
-- Public Apply (called by ApplyBus)
-- ---------------------------------------------------------
function mod:Apply()
  local db = GetDB()
  if not db then return end

  -- Hook once
  if not mod._hooked then
    mod._hooked = true

    local function OnTooltipSet(tip)
      ApplyStyleToTooltip(tip)
    end

    if GameTooltip then
      GameTooltip:HookScript("OnShow", OnTooltipSet)
    end
    if ItemRefTooltip then
      ItemRefTooltip:HookScript("OnShow", OnTooltipSet)
    end
    if ShoppingTooltip1 then ShoppingTooltip1:HookScript("OnShow", OnTooltipSet) end
    if ShoppingTooltip2 then ShoppingTooltip2:HookScript("OnShow", OnTooltipSet) end
  end

  -- Apply immediately to visible tooltips
  if GameTooltip and GameTooltip:IsShown() then ApplyStyleToTooltip(GameTooltip) end
  if ItemRefTooltip and ItemRefTooltip:IsShown() then ApplyStyleToTooltip(ItemRefTooltip) end
  if ShoppingTooltip1 and ShoppingTooltip1:IsShown() then ApplyStyleToTooltip(ShoppingTooltip1) end
  if ShoppingTooltip2 and ShoppingTooltip2:IsShown() then ApplyStyleToTooltip(ShoppingTooltip2) end
end

-- ---------------------------------------------------------
-- Enable/Disable
-- ---------------------------------------------------------
function mod:SetEnabled(v)
  local db = GetDB()
  if not db then return end
  db.enabled = v and true or false
  mod:Apply()
end

-- ---------------------------------------------------------
-- Register with ApplyBus
-- ---------------------------------------------------------
if ETBC.ApplyBus and ETBC.ApplyBus.Register then
  ETBC.ApplyBus:Register("tooltip", function()
    mod:Apply()
  end)
end

-- Modules/Tooltip.lua
-- EnhanceTBC - Tooltip enhancements (safe on TBC Anniversary client 20505)
-- Fix: avoid Texture:SetGradientAlpha (not available on this client). Use solid tint fallback.

local ADDON_NAME, ETBC = ...

ETBC.Modules = ETBC.Modules or {}
local mod = ETBC.Modules.Tooltip or {}
ETBC.Modules.Tooltip = mod

mod.key = "tooltip"
mod._hooked = false
mod._idHooked = false

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
  if name and name:find("ShoppingTooltip", 1, true) then
    -- Always skip shopping tooltips (item comparison tooltips)
    -- These don't need custom styling as they're meant to be minimal
    return
  end

  -- Backdrop (using db.skin.enabled and db.skin.bg/border)
  if db.skin and db.skin.enabled then
    SafeSetBackdrop(tip, "Interface\\Buttons\\WHITE8x8", "Interface\\Buttons\\WHITE8x8", 1)
    local bg = db.skin.bg or { r = 0.03, g = 0.06, b = 0.03, a = 0.92 }
    local br = db.skin.border or { r = 0.20, g = 1.00, b = 0.20, a = 0.95 }
    SetBackdropColor(tip, bg.r or 0, bg.g or 0, bg.b or 0, bg.a or 1)
    SetBackdropBorderColor(tip, br.r or 1, br.g or 1, br.b or 1, br.a or 1)
  end

  -- Accent line (solid, safe) - using db.skin.grad for the color
  if db.skin and db.skin.enabled and db.skin.grad then
    local line = EnsureAccentLine(tip)
    local ac = db.skin.grad or { r = 0.10, g = 0.35, b = 0.10, a = 0.22 }
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
-- ID Display Helpers
-- ---------------------------------------------------------

-- Extract Item ID from itemLink (format: "|cffffffff|Hitem:12345:...")
local function ExtractItemID(itemLink)
  if not itemLink then return nil end
  local id = itemLink:match("item:(%d+)")
  return id and tonumber(id) or nil
end

-- Extract Spell ID from tooltip (TBC Anniversary client)
local function ExtractSpellID(tooltip)
  if not tooltip or not tooltip.GetSpell then return nil end
  
  -- Try GetSpell which may return spellID on TBC Anniversary
  local name, rank, spellID = tooltip:GetSpell()
  if spellID then return spellID end
  if not name then return nil end
  
  -- Fallback: try to extract from tooltip hyperlinks
  local tooltipName = tooltip:GetName()
  if not tooltipName then return nil end
  
  for i = 1, tooltip:NumLines() do
    local line = _G[tooltipName.."TextLeft"..i]
    if line then
      local text = line:GetText()
      if text then
        local id = text:match("|Hspell:(%d+)")
        if id then return tonumber(id) end
      end
    end
  end
  
  return nil
end

-- Extract NPC ID from unit GUID
local function ExtractNPCID(unit)
  if not unit then return nil end
  local guid = UnitGUID(unit)
  if not guid then return nil end
  
  -- TBC Anniversary uses modern GUID format: "Creature-0-<server>-<instance>-<zone>-<npcID>-<spawnUID>"
  -- strsplit returns: unitType, "0", server, instance, zone, npcID, spawnUID
  local parts = {strsplit("-", guid)}
  local unitType = parts[1]
  local npcID = parts[6]
  
  if unitType and (unitType == "Creature" or unitType == "Vehicle") and npcID then
    return tonumber(npcID)
  end
  
  return nil
end

-- Extract Quest ID from hyperlink in tooltip
local function ExtractQuestID(tooltip)
  if not tooltip then return nil end
  
  -- Check tooltip name for quest hyperlinks
  local tooltipName = tooltip:GetName()
  if not tooltipName then return nil end
  
  -- Scan all tooltip lines for quest hyperlinks
  for i = 1, tooltip:NumLines() do
    local line = _G[tooltipName.."TextLeft"..i]
    if line then
      local text = line:GetText()
      if text then
        local id = text:match("|Hquest:(%d+)")
        if id then return tonumber(id) end
      end
    end
  end
  
  return nil
end

-- Add ID line to tooltip with color
local function AddIDLine(tooltip, label, id, color)
  if not tooltip or not id then return end
  local r, g, b = color.r or 0.5, color.g or 0.9, color.b or 0.5
  tooltip:AddLine(label .. id, r, g, b)
end

-- Hook handler for item tooltips
local function OnTooltipSetItem(tooltip)
  local db = GetDB()
  if not db or not db.enabled or not db.showItemId then return end
  
  local _, itemLink = tooltip:GetItem()
  local itemID = ExtractItemID(itemLink)
  if itemID then
    AddIDLine(tooltip, "Item ID: ", itemID, db.idColor or { r = 0.5, g = 0.9, b = 0.5 })
  end
end

-- Hook handler for spell tooltips
local function OnTooltipSetSpell(tooltip)
  local db = GetDB()
  if not db or not db.enabled or not db.showSpellId then return end
  
  local spellID = ExtractSpellID(tooltip)
  if spellID then
    AddIDLine(tooltip, "Spell ID: ", spellID, db.idColor or { r = 0.5, g = 0.9, b = 0.5 })
  end
end

-- Hook handler for unit tooltips
local function OnTooltipSetUnit(tooltip)
  local db = GetDB()
  if not db or not db.enabled then return end
  
  local _, unit = tooltip:GetUnit()
  if not unit then return end
  
  -- Add NPC ID if enabled
  if db.showNpcId then
    local npcID = ExtractNPCID(unit)
    if npcID then
      AddIDLine(tooltip, "NPC ID: ", npcID, db.idColor or { r = 0.5, g = 0.9, b = 0.5 })
    end
  end
  
  -- Check for quest ID in the tooltip
  if db.showQuestId then
    local questID = ExtractQuestID(tooltip)
    if questID then
      AddIDLine(tooltip, "Quest ID: ", questID, db.idColor or { r = 0.5, g = 0.9, b = 0.5 })
    end
  end
end

-- ---------------------------------------------------------
-- Public Apply (called by ApplyBus)
-- ---------------------------------------------------------
function mod:Apply()
  local db = GetDB()
  if not db then return end

  -- Hook once for styling
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

  -- Hook once for ID display
  if not mod._idHooked then
    mod._idHooked = true

    if GameTooltip then
      -- Hook OnTooltipSetItem for item IDs
      GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
      
      -- Hook OnTooltipSetSpell for spell IDs
      GameTooltip:HookScript("OnTooltipSetSpell", OnTooltipSetSpell)
      
      -- Hook OnTooltipSetUnit for NPC IDs
      GameTooltip:HookScript("OnTooltipSetUnit", OnTooltipSetUnit)
    end

    -- Also hook ItemRefTooltip (for chat links)
    if ItemRefTooltip then
      ItemRefTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
      ItemRefTooltip:HookScript("OnTooltipSetSpell", OnTooltipSetSpell)
    end
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

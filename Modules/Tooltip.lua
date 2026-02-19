-- Modules/Tooltip.lua
-- EnhanceTBC - Tooltip enhancements (safe on TBC Anniversary client 20505)
-- Fix: avoid Texture:SetGradientAlpha (not available on this client). Use solid tint fallback.

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}
local mod = ETBC.Modules.Tooltip or {}
ETBC.Modules.Tooltip = mod

mod.key = "tooltip"
mod._hooked = false
mod._idHooked = false
mod._menuHooked = false

-- Default ID color (light green)
local DEFAULT_ID_COLOR = { r = 0.5, g = 0.9, b = 0.5 }

-- ---------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------
local function GetDB()
  if not ETBC.db or not ETBC.db.profile then return nil end
  ETBC.db.profile.tooltip = ETBC.db.profile.tooltip or {}
  local db = ETBC.db.profile.tooltip
  if db.enabled == nil then db.enabled = true end
  if db.showReactionText == nil then db.showReactionText = true end
  if db.showUnitHealthText == nil then db.showUnitHealthText = true end
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

local function ApplyTooltipNineSlice(tip, hide)
  if not tip or not tip.NineSlice then return end
  if hide then
    tip.NineSlice:Hide()
    if not tip._etbcNineSliceShow then
      tip._etbcNineSliceShow = tip.NineSlice.Show
    end
    tip.NineSlice.Show = function() end
  else
    if tip._etbcNineSliceShow then
      tip.NineSlice.Show = tip._etbcNineSliceShow
      tip._etbcNineSliceShow = nil
    end
    tip.NineSlice:Show()
  end
end

local function TooltipHasLine(tooltip, text)
  if not tooltip or not text then return false end
  local name = tooltip:GetName()
  if not name then return false end
  for i = 1, tooltip:NumLines() do
    local line = _G[name .. "TextLeft" .. i]
    if line and line:GetText() == text then
      return true
    end
  end
  return false
end

local function AddGuildLine(tooltip, unit)
  local db = GetDB()
  if not db or not db.enabled or not db.showGuild then return end
  if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return end

  local guild_name = GetGuildInfo(unit)
  if not guild_name or guild_name == "" then return end
  local text = "<" .. guild_name .. ">"
  if TooltipHasLine(tooltip, text) then return end
  tooltip:AddLine(text, 0.3, 0.9, 0.3)
end

local function AddTargetLine(tooltip, unit)
  local db = GetDB()
  if not db or not db.enabled or not db.showTarget then return end
  if not unit or not UnitExists(unit) then return end

  local target = unit .. "target"
  if not UnitExists(target) then return end
  local target_name = UnitName(target)
  if not target_name or target_name == "" then return end

  local text = "Target: " .. target_name
  if TooltipHasLine(tooltip, text) then return end

  if UnitIsUnit(target, "player") then
    tooltip:AddLine(text, 0, 1, 0)
  elseif UnitIsPlayer(target) then
    local _, class = UnitClass(target)
    if class and RAID_CLASS_COLORS[class] then
      tooltip:AddLine(text, RAID_CLASS_COLORS[class]:GetRGB())
    else
      tooltip:AddLine(text, 1, 1, 1)
    end
  else
    tooltip:AddLine(text, 1, 1, 1)
  end
end

local function ApplyTooltipBackdrop(tip)
  local db = GetDB()
  if not db or not db.enabled then return end
  if not tip or not tip.SetBackdrop then return end

  SafeSetBackdrop(tip, "Interface\\ChatFrame\\ChatFrameBackground", "Interface\\Buttons\\WHITE8x8", 1)
  local bg = (db.skin and db.skin.bg) or { r = 0.03, g = 0.06, b = 0.03, a = 0.85 }
  SetBackdropColor(tip, bg.r or 0, bg.g or 0, bg.b or 0, bg.a or 0.85)
end

local function ApplyTooltipBorder(tip)
  local db = GetDB()
  if not db or not db.enabled then return end
  if not tip or not tip.SetBackdropBorderColor then return end

  local br = (db.skin and db.skin.border) or { r = 0.04, g = 0.04, b = 0.04, a = 0.85 }
  SetBackdropBorderColor(tip, br.r or 0.04, br.g or 0.04, br.b or 0.04, br.a or 0.85)
end

local function ApplyTooltipAnchor(tip)
  local db = GetDB()
  if not db or not db.enabled then return end
  if not tip then return end

  local mode = db.anchorMode or "DEFAULT"
  if mode == "DEFAULT" then return end

  if mode == "CURSOR" then
    local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local pos_x, pos_y = GetCursorPosition()
    if scale and pos_x and pos_y then
      tip:ClearAllPoints()
      tip:SetPoint("TOP", UIParent, "BOTTOMLEFT", pos_x / scale, (pos_y / scale) - 20, "etbc_tooltip")
    end
    return
  end

  local offsetX = db.offsetX or 0
  local offsetY = db.offsetY or 0
  tip:ClearAllPoints()
  tip:SetPoint(mode, UIParent, mode, offsetX, offsetY, "etbc_tooltip")
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
  local name, _, spellID = tooltip:GetSpell()
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

  -- Verify we have enough parts and correct type
  if #parts >= 6 and unitType and (unitType == "Creature" or unitType == "Vehicle") and npcID then
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

local function AddItemLevelLine(tooltip, itemLink)
  local db = GetDB()
  if not db or not db.enabled or not db.showItemLevel then return end
  if not itemLink then return end

  local item_level = select(4, GetItemInfo(itemLink))
  if item_level then
    tooltip:AddLine("Item Level: " .. item_level, 0.8, 0.8, 0.8)
  end
end

local function AddVendorPriceLine(tooltip, itemLink)
  local db = GetDB()
  if not db or not db.enabled or not db.showVendorPrice then return end
  if not itemLink then return end

  local sell_price = select(11, GetItemInfo(itemLink))
  if sell_price and sell_price > 0 and GetCoinTextureString then
    tooltip:AddLine("Vendor Price: " .. GetCoinTextureString(sell_price), 0.8, 0.8, 0.8)
  end
end

local function AddStatSummaryLine(tooltip, itemLink)
  local db = GetDB()
  if not db or not db.enabled or not db.showStatSummary then return end
  if not itemLink or not GetItemStats then return end

  local stats = GetItemStats(itemLink)
  if not stats or type(stats) ~= "table" then return end

  local labels = {
    STRENGTH = "Str",
    AGILITY = "Agi",
    STAMINA = "Sta",
    INTELLECT = "Int",
    SPIRIT = "Spi",
    ATTACK_POWER = "AP",
    SPELL_POWER = "SP",
    CRIT_RATING = "Crit",
    HASTE_RATING = "Haste",
    HIT_RATING = "Hit",
    ARMOR_PENETRATION_RATING = "ArP",
  }

  local collected = {}
  for key, value in pairs(stats) do
    if value and value ~= 0 then
      local token = key:match("^ITEM_MOD_(.+)_SHORT$") or key:match("^ITEM_MOD_(.+)$")
      local label = token and labels[token] or nil
      if label then
        table.insert(collected, label .. ": " .. value)
      end
    end
  end

  table.sort(collected)

  if #collected == 0 then return end

  local max_stats = db.statSummaryMax or 6
  if max_stats < 1 then max_stats = 1 end

  local summary = {}
  for i = 1, math.min(#collected, max_stats) do
    table.insert(summary, collected[i])
  end

  tooltip:AddLine("Stats: " .. table.concat(summary, ", "), 0.8, 0.8, 0.8)
end

local function EnsureStatusBarText()
  if not GameTooltipStatusBar or GameTooltipStatusBar.unit_health_text then return end
  GameTooltipStatusBar.unit_health_text = GameTooltipStatusBar:CreateFontString(nil, "OVERLAY")
  GameTooltipStatusBar.unit_health_text:SetAllPoints(true)
  if ETBC.Theme and ETBC.Theme.ApplyFontString then
    ETBC.Theme:ApplyFontString(GameTooltipStatusBar.unit_health_text, nil, 10)
  else
    GameTooltipStatusBar.unit_health_text:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
  end
  GameTooltipStatusBar.unit_health_text:SetJustifyH("CENTER")
  GameTooltipStatusBar.unit_health_text:SetJustifyV("MIDDLE")
end

local function SetStatusBarStyle(statusbar, unit)
  local db = GetDB()
  if not db or not db.enabled or not statusbar or not statusbar.SetStatusBarColor then return end
  if not db.healthBar or not db.healthBar.enabled then return end

  local texture = "Interface\\TargetingFrame\\UI-StatusBar"
  if ETBC.Theme and ETBC.Theme.FetchStatusbar then
    texture = ETBC.Theme:FetchStatusbar()
  end
  if statusbar.SetStatusBarTexture then
    statusbar:SetStatusBarTexture(texture)
  end

  if not unit or not UnitExists(unit) then
    local c = db.healthBar.color or { r = 0.2, g = 1.0, b = 0.2, a = 1 }
    statusbar:SetStatusBarColor(c.r or 0.2, c.g or 1, c.b or 0.2, c.a or 1)
    return
  end

  if UnitIsPlayer(unit) and db.healthBar.classColor then
    if not UnitIsConnected(unit) then
      statusbar:SetStatusBarColor(0.75, 0.75, 0.75)
      return
    end

    local _, unit_class = UnitClass(unit)
    if unit_class and RAID_CLASS_COLORS[unit_class] then
      statusbar:SetStatusBarColor(RAID_CLASS_COLORS[unit_class]:GetRGB())
      return
    end
  end

  local unit_reaction = UnitReaction(unit, "player")
  if unit_reaction then
    if unit_reaction >= 1 and unit_reaction <= 3 then
      statusbar:SetStatusBarColor(0.9, 0, 0.1)
    elseif unit_reaction == 4 then
      statusbar:SetStatusBarColor(1, 0.9, 0.1)
    else
      statusbar:SetStatusBarColor(0, 0.85, 0.2)
    end
  else
    local c = db.healthBar.color or { r = 0.2, g = 1.0, b = 0.2, a = 1 }
    statusbar:SetStatusBarColor(c.r or 0.2, c.g or 1, c.b or 0.2, c.a or 1)
  end
end

local function UpdateStatusBarText(statusbar, unit)
  local db = GetDB()
  if not statusbar or not statusbar.unit_health_text then return end
  if not db or not db.enabled or not db.showUnitHealthText then
    statusbar.unit_health_text:SetText("")
    return
  end
  if not unit or not UnitExists(unit) then
    statusbar.unit_health_text:SetText("")
    return
  end

  local unit_health = UnitHealth(unit)
  local unit_health_max = UnitHealthMax(unit)
  if not unit_health or not unit_health_max or unit_health_max <= 0 then
    statusbar.unit_health_text:SetText("")
    return
  end

  if unit_health >= 1000000 then
    statusbar.unit_health_text:SetText(
      string.format("%.1fM", unit_health / 1000000)
        .. "/"
        .. string.format("%.1fM", unit_health_max / 1000000)
    )
  elseif unit_health >= 1000 then
    statusbar.unit_health_text:SetText(
      string.format("%.1fK", unit_health / 1000)
        .. "/"
        .. string.format("%.1fK", unit_health_max / 1000)
    )
  else
    statusbar.unit_health_text:SetText(unit_health .. "/" .. unit_health_max)
  end
end

local function AddReactionLine(tooltip, unit)
  local db = GetDB()
  if not db or not db.enabled or not db.showReactionText then return end
  if not unit or not UnitExists(unit) then return end

  local unit_reaction = UnitReaction(unit, "player")
  if unit_reaction and unit ~= "player" then
    if unit_reaction >= 1 and unit_reaction <= 3 then
      tooltip:AddLine("Hostile", 0.8, 0.3, 0.22)
    elseif unit_reaction == 4 then
      tooltip:AddLine("Neutral", 0.9, 0.7, 0)
    else
      tooltip:AddLine("Friendly", 0, 0.6, 0.1)
    end
  end
end

local function ApplyClassColorName(tooltip, unit)
  local db = GetDB()
  if not db or not db.enabled or not db.classColorNames then return end
  if not unit or not UnitExists(unit) then return end
  if not UnitIsPlayer(unit) then return end

  local tooltip_name = tooltip.GetName and tooltip:GetName() or nil
  if not tooltip_name then return end
  local name_line = _G[tooltip_name .. "TextLeft1"]
  if not name_line then return end

  local _, unit_class = UnitClass(unit)
  if unit_class and RAID_CLASS_COLORS[unit_class] then
    name_line:SetTextColor(RAID_CLASS_COLORS[unit_class]:GetRGB())
  end
end

-- Hook handler for item tooltips
local function OnTooltipSetItem(tooltip)
  local db = GetDB()
  if not db or not db.enabled then return end

  ApplyStyleToTooltip(tooltip)

  local _, itemLink = tooltip:GetItem()
  local itemID = ExtractItemID(itemLink)
  if itemID and db.showItemId then
    AddIDLine(tooltip, "Item ID: ", itemID, db.idColor or DEFAULT_ID_COLOR)
  end

  AddItemLevelLine(tooltip, itemLink)
  AddVendorPriceLine(tooltip, itemLink)
  AddStatSummaryLine(tooltip, itemLink)
end

-- Hook handler for spell tooltips
local function OnTooltipSetSpell(tooltip)
  local db = GetDB()
  if not db or not db.enabled or not db.showSpellId then return end

  ApplyStyleToTooltip(tooltip)

  local spellID = ExtractSpellID(tooltip)
  if spellID then
    AddIDLine(tooltip, "Spell ID: ", spellID, db.idColor or DEFAULT_ID_COLOR)
  end
end

-- Hook handler for unit tooltips
local function OnTooltipSetUnit(tooltip)
  local db = GetDB()
  if not db or not db.enabled then return end

  ApplyStyleToTooltip(tooltip)

  local _, unit = tooltip:GetUnit()
  if not unit then return end

  AddReactionLine(tooltip, unit)
  ApplyClassColorName(tooltip, unit)
  AddGuildLine(tooltip, unit)
  AddTargetLine(tooltip, unit)
  SetStatusBarStyle(GameTooltipStatusBar, unit)
  UpdateStatusBarText(GameTooltipStatusBar, unit)

  -- Add NPC ID if enabled
  if db.showNpcId then
    local npcID = ExtractNPCID(unit)
    if npcID then
      AddIDLine(tooltip, "NPC ID: ", npcID, db.idColor or DEFAULT_ID_COLOR)
    end
  end

  -- Check for quest ID in the tooltip
  if db.showQuestId then
    local questID = ExtractQuestID(tooltip)
    if questID then
      AddIDLine(tooltip, "Quest ID: ", questID, db.idColor or DEFAULT_ID_COLOR)
    end
  end
end

local function OnTooltipSetUnitAura(tooltip, unit, index, filter)
  local db = GetDB()
  if not db or not db.enabled or not db.showSpellId then return end
  if not unit or not index or not filter then return end

  local spell_id = select(10, UnitAura(unit, index, filter))
  if spell_id then
    AddIDLine(tooltip, "Spell ID: ", spell_id, db.idColor or DEFAULT_ID_COLOR)
  end
end

-- ---------------------------------------------------------
-- Public Apply (called by ApplyBus)
-- ---------------------------------------------------------
function mod.Apply(_)
  local db = GetDB()
  if not db then return end

  if GameTooltipStatusBar then
    GameTooltipStatusBar:SetHeight(10)
    GameTooltipStatusBar:ClearAllPoints()
    GameTooltipStatusBar:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 0, -1)
    GameTooltipStatusBar:SetPoint("TOPRIGHT", GameTooltip, "BOTTOMRIGHT", 0, -1)
    EnsureStatusBarText()
  end

  -- Hook once for styling
  if not mod._hooked then
    mod._hooked = true

    local function OnTooltipSet(tip)
      ApplyStyleToTooltip(tip)
    end

    local tips = {
      GameTooltip, ItemRefTooltip, ShoppingTooltip1,
      ShoppingTooltip2, FriendsTooltip, PartyMemberBuffTooltip,
    }
    for _, tip in pairs(tips) do
      if tip and tip.HookScript then
        tip:HookScript("OnShow", OnTooltipSet)
      end
    end

    if GameTooltip then
      GameTooltip:HookScript("OnShow", function(tip)
        ApplyTooltipAnchor(tip)
      end)

      hooksecurefunc(GameTooltip, "SetPoint", function(self, _, _, _, _, _, flag)
        if flag == "etbc_tooltip" then return end
        ApplyTooltipAnchor(self)
      end)
    end
  end

  if not mod._menuHooked and MenuMixin and MenuMixin.SetMenuDescription then
    mod._menuHooked = true
    hooksecurefunc(MenuMixin, "SetMenuDescription", function(self)
      local db2 = GetDB()
      if not db2 or not db2.enabled or not db2.skin or not db2.skin.enabled then return end
      if not self.frames or not self.frames.Enumerate then return end

      for _, frame in self.frames:Enumerate() do
        if frame.GetParent and frame:GetParent() then
          for i, region in pairs({ frame:GetParent():GetRegions() }) do
            if i == 1 then
              region:Hide()
            else
              if region.SetTexture then
                region:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
                region:SetVertexColor(0, 0, 0, 0.85)
              end
            end
          end
        end
      end
    end)
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

      hooksecurefunc(GameTooltip, "SetUnitAura", function(self, unit, index, filter)
        OnTooltipSetUnitAura(self, unit, index, filter)
      end)
      hooksecurefunc(GameTooltip, "SetUnitBuff", function(self, unit, index)
        OnTooltipSetUnitAura(self, unit, index, "HELPFUL")
      end)
      hooksecurefunc(GameTooltip, "SetUnitDebuff", function(self, unit, index)
        OnTooltipSetUnitAura(self, unit, index, "HARMFUL")
      end)
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

  local tips = {
    GameTooltip, ItemRefTooltip, ShoppingTooltip1,
    ShoppingTooltip2, FriendsTooltip, PartyMemberBuffTooltip,
  }
  for _, tip in pairs(tips) do
    if tip then
      ApplyTooltipBackdrop(tip)
      ApplyTooltipBorder(tip)
      ApplyTooltipNineSlice(tip, db.skin and db.skin.enabled)
    end
  end

  if GameTooltip and GameTooltipStatusBar then
    local unit = select(2, GameTooltip:GetUnit())
      or (UnitExists("mouseover") and "mouseover")
    if unit then
      SetStatusBarStyle(GameTooltipStatusBar, unit)
      UpdateStatusBarText(GameTooltipStatusBar, unit)
    end
  end
end

-- ---------------------------------------------------------
-- Enable/Disable
-- ---------------------------------------------------------
function mod.SetEnabled(_, v)
  local db = GetDB()
  if not db then return end
  db.enabled = v and true or false
  mod:Apply()
end

hooksecurefunc("HealthBar_OnValueChanged", function(self)
  if self == GameTooltipStatusBar and self:IsShown() then
    local unit = select(2, GameTooltip:GetUnit()) or (UnitExists("mouseover") and "mouseover")
    if not unit then
      return
    end

    SetStatusBarStyle(self, unit)
    UpdateStatusBarText(self, unit)
  end
end)

-- ---------------------------------------------------------
-- Register with ApplyBus
-- ---------------------------------------------------------
if ETBC.ApplyBus and ETBC.ApplyBus.Register then
  ETBC.ApplyBus:Register("tooltip", function()
    mod:Apply()
  end)
end

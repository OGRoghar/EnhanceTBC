local ETBC = _G.EnhanceTBC
if not ETBC then return end

ETBC.InventorySuite = ETBC.InventorySuite or {}
local Inventory = ETBC.InventorySuite
local SLOT_FIRST, SLOT_LAST = 1, 19
local cache = {}
local driver

local function Enabled()
  local p = ETBC.db and ETBC.db.profile
  return p and p.general.enabled and p.suite and p.suite.inventory and p.suite.inventory.enabled and p.inventory.enabled
end

local function AuditSlot(unit, slot)
  local link = GetInventoryItemLink and GetInventoryItemLink(unit, slot)
  if not link then return nil end
  local name, _, quality, level, _, _, _, _, equipLoc = GetItemInfo(link)
  local current, maximum = GetInventoryItemDurability and GetInventoryItemDurability(slot)
  local durability = current and maximum and maximum > 0 and math.floor(current * 100 / maximum + 0.5) or nil
  return { slot = slot, link = link, name = name, quality = quality, itemLevel = level, equipLocation = equipLoc, durability = durability }
end

function Inventory:Scan(unit)
  unit = unit or "player"
  if unit ~= "player" and not (UnitExists and UnitExists(unit)) then return nil, "unit unavailable" end
  local result = { unit = unit, slots = {}, issues = {}, updatedAt = time and time() or 0 }
  local low = tonumber(ETBC.db.profile.inventory.lowDurability) or 25
  for slot = SLOT_FIRST, SLOT_LAST do
    local item = AuditSlot(unit, slot)
    if item then
      result.slots[#result.slots + 1] = item
      if item.durability and item.durability <= low then
        result.issues[#result.issues + 1] = { kind = "durability", slot = slot, value = item.durability }
      end
    end
  end
  cache[unit] = result
  if ETBC.PublicAPIInternal and ETBC.PublicAPIInternal.OnEquipmentAuditUpdated then
    ETBC.PublicAPIInternal.OnEquipmentAuditUpdated(unit)
  end
  return result
end

function Inventory:GetAudit(unit)
  unit = unit or "player"
  if not Enabled() then return nil, "inventory feature disabled" end
  return cache[unit] or self:Scan(unit)
end

function Inventory:Apply()
  if not driver then
    driver = CreateFrame("Frame", "EnhanceTBC_InventoryDriver")
    driver:SetScript("OnEvent", function(_, event)
      if Enabled() and (event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_ENTERING_WORLD") then
        Inventory:Scan("player")
      end
    end)
  end
  driver:UnregisterAllEvents()
  if Enabled() then
    driver:RegisterEvent("PLAYER_ENTERING_WORLD")
    driver:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    self:Scan("player")
  end
end

ETBC.ApplyBus:Register("inventory", function() Inventory:Apply() end)
Inventory:Apply()

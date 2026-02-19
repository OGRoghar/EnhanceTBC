-- Modules/Vendor.lua
-- Lightweight: auto-sell junk + auto-repair (live, no reload)
local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.Vendor = mod

local driver

-- -------------------------------------------------------
-- Container API Compat (Classic/TBC-safe)
-- -------------------------------------------------------
local C = C_Container

local function GetBagNumSlots(bag)
  if C and C.GetContainerNumSlots then
    return C.GetContainerNumSlots(bag) or 0
  end
  if GetContainerNumSlots then
    return GetContainerNumSlots(bag) or 0
  end
  return 0
end

local function GetBagItemLink(bag, slot)
  if C and C.GetContainerItemLink then
    return C.GetContainerItemLink(bag, slot)
  end
  if GetContainerItemLink then
    return GetContainerItemLink(bag, slot)
  end
  return nil
end

local function GetBagItemCount(bag, slot)
  if C and C.GetContainerItemInfo then
    local info = C.GetContainerItemInfo(bag, slot)
    if info and info.stackCount then return info.stackCount end
    return 1
  end
  if GetContainerItemInfo then
    -- Classic-style returns multiple values; 2nd is count on many builds
    local _, count = GetContainerItemInfo(bag, slot)
    if count then return count end
    return 1
  end
  return 1
end

local function UseBagItem(bag, slot)
  if C and C.UseContainerItem then
    return C.UseContainerItem(bag, slot)
  end
  if UseContainerItem then
    return UseContainerItem(bag, slot)
  end
end

-- -------------------------------------------------------
-- DB
-- -------------------------------------------------------
local function GetDB()
  ETBC.db.profile.vendor = ETBC.db.profile.vendor or {}
  local db = ETBC.db.profile.vendor
  if db.enabled == nil then db.enabled = true end
  if db.autoSellJunk == nil then db.autoSellJunk = true end
  if db.autoRepair == nil then db.autoRepair = true end
  if db.useGuildRepair == nil then db.useGuildRepair = true end
  if db.printSummary == nil then db.printSummary = true end
  return db
end

-- -------------------------------------------------------
-- Helpers
-- -------------------------------------------------------
local function Print(msg)
  if ETBC and ETBC.Print then
    ETBC:Print(msg)
  elseif DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99EnhanceTBC|r " .. tostring(msg))
  end
end

local function MoneyToString(copper)
  copper = tonumber(copper) or 0
  if copper <= 0 then return "0c" end
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  local c = copper % 100
  local parts = {}
  if g > 0 then parts[#parts+1] = g .. "g" end
  if s > 0 or g > 0 then parts[#parts+1] = s .. "s" end
  parts[#parts+1] = c .. "c"
  return table.concat(parts, " ")
end

local function CanMerchant()
  return MerchantFrame and MerchantFrame:IsShown()
end

-- -------------------------------------------------------
-- Core features
-- -------------------------------------------------------
local function AutoRepair(db)
  if not db.autoRepair then return end
  if not CanMerchant() then return end
  if not CanMerchantRepair or not CanMerchantRepair() then return end

  local cost = GetRepairAllCost()
  if not cost or cost <= 0 then return end

  local usedGuild = false
  if db.useGuildRepair and CanGuildBankRepair and CanGuildBankRepair() then
    local withdraw = GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney() or 0
    local gMoney = GetGuildBankMoney and GetGuildBankMoney() or 0

    -- withdraw can be -1 for unlimited in some versions
    local canUse = (withdraw == -1) or (withdraw >= cost)
    if canUse and gMoney >= cost then
      RepairAllItems(true)
      usedGuild = true
    end
  end

  if not usedGuild then
    local playerMoney = GetMoney and GetMoney() or 0
    if playerMoney >= cost then
      RepairAllItems(false)
    end
  end

  if db.printSummary then
    Print("Repaired for " .. MoneyToString(cost) .. (usedGuild and " (guild)" or ""))
  end
end

local function AutoSellJunk(db)
  if not db.autoSellJunk then return end
  if not CanMerchant() then return end

  local total = 0
  local sold = 0

  -- Bags: 0 = backpack, 1-4 = equipped bags (NUM_BAG_SLOTS is 4 in classic)
  local maxBag = (NUM_BAG_SLOTS ~= nil and NUM_BAG_SLOTS) or 4

  for bag = 0, maxBag do
    local slots = GetBagNumSlots(bag)
    if slots and slots > 0 then
      for slot = 1, slots do
        local link = GetBagItemLink(bag, slot)
        if link then
          local name, _, quality, _, _, _, _, _, _, _, vendorPrice = GetItemInfo(link)
          if name and quality == 0 and vendorPrice and vendorPrice > 0 then
            local count = GetBagItemCount(bag, slot) or 1
            local value = vendorPrice * count

            -- Sell it
            UseBagItem(bag, slot)

            total = total + value
            sold = sold + 1
          end
        end
      end
    end
  end

  if db.printSummary and sold > 0 then
    Print("Sold " .. sold .. " junk item(s) for " .. MoneyToString(total))
  end
end

-- -------------------------------------------------------
-- Events
-- -------------------------------------------------------
local function EnsureDriver()
  if driver then return end
  driver = CreateFrame("Frame", "EnhanceTBC_VendorDriver", UIParent)
  driver:Hide()
end

local function OnMerchantShow()
  local db = GetDB()
  local generalEnabled = ETBC.db and ETBC.db.profile and ETBC.db.profile.general and ETBC.db.profile.general.enabled
  if not (generalEnabled and db.enabled) then return end

  -- Order matters: repair first (doesn't affect bags), then sell.
  AutoRepair(db)
  AutoSellJunk(db)
end

local function Apply()
  EnsureDriver()

  local db = GetDB()
  local generalEnabled = ETBC.db and ETBC.db.profile and ETBC.db.profile.general and ETBC.db.profile.general.enabled
  local enabled = generalEnabled and db.enabled

  driver:UnregisterAllEvents()
  driver:SetScript("OnEvent", nil)

  if enabled then
    driver:RegisterEvent("MERCHANT_SHOW")
    driver:SetScript("OnEvent", function(_, event)
      if event == "MERCHANT_SHOW" then
        OnMerchantShow()
      end
    end)
    driver:Show()
  else
    driver:Hide()
  end
end

-- -------------------------------------------------------
-- Register with ApplyBus
-- -------------------------------------------------------
if ETBC.ApplyBus and ETBC.ApplyBus.Register then
  ETBC.ApplyBus:Register("vendor", Apply)
  ETBC.ApplyBus:Register("general", Apply)
end

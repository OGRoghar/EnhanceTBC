-- Modules/Vendor.lua
-- Auto-repair + auto-sell with TBC Anniversary compatible bag API handling.

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.Vendor = mod

local driver
local sellTicker
local sellQueue = {}
local sellIndex = 1
local sellTotal = 0
local sellCount = 0
local sellSkippedHigh = 0
local sellDB
local merchantOpen = false

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
    local _, count = GetContainerItemInfo(bag, slot)
    if count then return count end
  end
  return 1
end

local function GetBagItemLocked(bag, slot)
  if C and C.GetContainerItemInfo then
    local info = C.GetContainerItemInfo(bag, slot)
    if info and info.isLocked ~= nil then
      return info.isLocked and true or false
    end
    return false
  end
  if GetContainerItemInfo then
    local _, _, locked = GetContainerItemInfo(bag, slot)
    return locked and true or false
  end
  return false
end

local function UseBagItem(bag, slot)
  if C and C.UseContainerItem then
    return C.UseContainerItem(bag, slot)
  end
  if UseContainerItem then
    return UseContainerItem(bag, slot)
  end
end

local function GetItemIDFromLink(link)
  if not link then return nil end
  local id = link:match("item:(%d+)")
  if id then return tonumber(id) end
  return nil
end

local legacyGetItemInfo = _G["GetItemInfo"]

local function GetItemInfoCompat(item)
  if C_Item and C_Item.GetItemInfo then
    return C_Item.GetItemInfo(item)
  end
  if type(legacyGetItemInfo) == "function" then
    return legacyGetItemInfo(item)
  end
  return nil
end

local function GetDB()
  ETBC.db.profile.vendor = ETBC.db.profile.vendor or {}
  local db = ETBC.db.profile.vendor

  if db.enabled == nil then db.enabled = true end
  if db.bypassWithShift == nil then db.bypassWithShift = true end

  if db.autoRepair == nil then db.autoRepair = true end
  if db.useGuildRepair == nil then db.useGuildRepair = true end
  if db.repairThreshold == nil then db.repairThreshold = 0 end

  if db.autoSellJunk == nil then db.autoSellJunk = true end
  if db.maxQualityToSell == nil then db.maxQualityToSell = 0 end
  if db.confirmHighValue == nil then db.confirmHighValue = true end
  if db.confirmMinValue == nil then db.confirmMinValue = 200000 end
  if db.skipLocked == nil then db.skipLocked = true end
  if db.printSummary == nil then db.printSummary = true end

  db.throttle = db.throttle or {}
  if db.throttle.enabled == nil then db.throttle.enabled = true end
  if db.throttle.interval == nil then db.throttle.interval = 0.03 end
  if db.throttle.maxPerTick == nil then db.throttle.maxPerTick = 6 end

  db.whitelist = db.whitelist or {}
  if db.whitelist.enabled == nil then db.whitelist.enabled = false end
  db.whitelist.items = db.whitelist.items or {}

  db.blacklist = db.blacklist or {}
  if db.blacklist.enabled == nil then db.blacklist.enabled = true end
  db.blacklist.items = db.blacklist.items or {}

  return db
end

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
  if g > 0 then parts[#parts + 1] = g .. "g" end
  if s > 0 or g > 0 then parts[#parts + 1] = s .. "s" end
  parts[#parts + 1] = c .. "c"
  return table.concat(parts, " ")
end

local function CanMerchant()
  if merchantOpen then return true end
  return MerchantFrame and MerchantFrame:IsShown()
end

local function ShouldBypass(db)
  return db.bypassWithShift and IsShiftKeyDown and IsShiftKeyDown()
end

local function CancelSellTicker()
  if sellTicker and sellTicker.Cancel then
    sellTicker:Cancel()
  end
  sellTicker = nil
  wipe(sellQueue)
  sellIndex = 1
  sellTotal = 0
  sellCount = 0
  sellSkippedHigh = 0
  sellDB = nil
end

local function AutoRepair(db)
  if not db.autoRepair then return end
  if not CanMerchant() then return end
  if not CanMerchantRepair or not CanMerchantRepair() then return end

  local cost = GetRepairAllCost()
  if not cost or cost <= 0 then return end
  if cost < (db.repairThreshold or 0) then return end

  local usedGuild = false
  if db.useGuildRepair and CanGuildBankRepair and CanGuildBankRepair() then
    local withdraw = GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney() or 0
    local gMoney = GetGuildBankMoney and GetGuildBankMoney() or 0
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
    else
      return
    end
  end

  if db.printSummary then
    Print("Repaired for " .. MoneyToString(cost) .. (usedGuild and " (guild)" or ""))
  end
end

local function ShouldSellItem(db, itemID, quality, vendorPrice, locked)
  if not quality or quality > (db.maxQualityToSell or 0) then
    return false
  end
  if not vendorPrice or vendorPrice <= 0 then
    return false
  end
  if db.skipLocked and locked then
    return false
  end

  if db.blacklist and db.blacklist.enabled and itemID and db.blacklist.items and db.blacklist.items[itemID] then
    return false
  end

  if db.whitelist and db.whitelist.enabled then
    if not (itemID and db.whitelist.items and db.whitelist.items[itemID]) then
      return false
    end
  end

  return true
end

local function BuildSellQueue(db)
  local queue = {}
  local total = 0
  local sold = 0
  local skippedHigh = 0
  local maxBag = (NUM_BAG_SLOTS ~= nil and NUM_BAG_SLOTS) or 4

  for bag = 0, maxBag do
    local slots = GetBagNumSlots(bag)
    for slot = 1, slots do
      local link = GetBagItemLink(bag, slot)
      if link then
        local itemID = GetItemIDFromLink(link)
        local _, _, quality, _, _, _, _, _, _, _, vendorPrice = GetItemInfoCompat(link)
        local locked = GetBagItemLocked(bag, slot)

        if ShouldSellItem(db, itemID, quality, vendorPrice, locked) then
          local count = GetBagItemCount(bag, slot) or 1
          local value = (vendorPrice or 0) * count

          if db.confirmHighValue and value >= (db.confirmMinValue or 200000) then
            skippedHigh = skippedHigh + 1
          else
            queue[#queue + 1] = { bag = bag, slot = slot }
            total = total + value
            sold = sold + 1
          end
        end
      end
    end
  end

  return queue, total, sold, skippedHigh
end

local function FinishSellSummary()
  if not sellDB or not sellDB.printSummary then return end
  if sellCount > 0 then
    Print("Sold " .. sellCount .. " item(s) for " .. MoneyToString(sellTotal))
  end
  if sellSkippedHigh > 0 then
    Print("Skipped " .. sellSkippedHigh .. " high-value item(s) due to confirmation threshold.")
  end
end

local function SellOne(entry)
  if not entry then return end
  UseBagItem(entry.bag, entry.slot)
end

local function PumpSellQueue()
  if not CanMerchant() then
    CancelSellTicker()
    return
  end
  if sellIndex > #sellQueue then
    FinishSellSummary()
    CancelSellTicker()
    return
  end

  local maxPerTick = math.max(1, math.floor((sellDB and sellDB.throttle and sellDB.throttle.maxPerTick) or 6))
  for _ = 1, maxPerTick do
    local entry = sellQueue[sellIndex]
    if not entry then break end
    SellOne(entry)
    sellIndex = sellIndex + 1
  end
end

local function StartSellQueue(db, queue, total, sold, skippedHigh)
  CancelSellTicker()

  sellDB = db
  sellQueue = queue
  sellIndex = 1
  sellTotal = total or 0
  sellCount = sold or 0
  sellSkippedHigh = skippedHigh or 0

  if #sellQueue == 0 then
    FinishSellSummary()
    CancelSellTicker()
    return
  end

  local throttleRequested = db.throttle and db.throttle.enabled
  if throttleRequested then
    local interval = math.max(0.01, tonumber(db.throttle.interval) or 0.03)
    if ETBC and ETBC.StartRepeatingTimer then
      sellTicker = ETBC:StartRepeatingTimer(interval, PumpSellQueue)
    end
    if not sellTicker and C_Timer and C_Timer.NewTicker then
      sellTicker = C_Timer.NewTicker(interval, PumpSellQueue)
    end
    if sellTicker then
      PumpSellQueue()
      return
    end
  end

  -- Fallback path when throttling is disabled or no timer backend exists.
  while sellIndex <= #sellQueue do
    SellOne(sellQueue[sellIndex])
    sellIndex = sellIndex + 1
  end
  FinishSellSummary()
  CancelSellTicker()
end

local function AutoSellJunk(db)
  if not db.autoSellJunk then return end
  if not CanMerchant() then return end

  local queue, total, sold, skippedHigh = BuildSellQueue(db)
  StartSellQueue(db, queue, total, sold, skippedHigh)
end

local function OnMerchantShow()
  merchantOpen = true
  local db = GetDB()
  local generalEnabled = ETBC.db and ETBC.db.profile and ETBC.db.profile.general and ETBC.db.profile.general.enabled
  if not (generalEnabled and db.enabled) then return end
  if ShouldBypass(db) then return end

  AutoRepair(db)
  AutoSellJunk(db)

  local deferred = function()
    if not merchantOpen then return end
    local db2 = GetDB()
    local gen2 = ETBC.db and ETBC.db.profile and ETBC.db.profile.general and ETBC.db.profile.general.enabled
    if not (gen2 and db2.enabled) then return end
    if ShouldBypass(db2) then return end
    AutoRepair(db2)
    AutoSellJunk(db2)
  end

  if ETBC and ETBC.StartTimer then
    ETBC:StartTimer(0.05, deferred)
  elseif C_Timer and C_Timer.After then
    C_Timer.After(0.05, deferred)
  else
    deferred()
  end
end

local function OnMerchantClosed()
  merchantOpen = false
  CancelSellTicker()
end

local function EnsureDriver()
  if driver then return end
  driver = CreateFrame("Frame", "EnhanceTBC_VendorDriver", UIParent)
  driver:Hide()
end

local function Apply()
  EnsureDriver()
  local db = GetDB()

  local generalEnabled = ETBC.db and ETBC.db.profile and ETBC.db.profile.general and ETBC.db.profile.general.enabled
  local enabled = generalEnabled and db.enabled

  driver:UnregisterAllEvents()
  driver:SetScript("OnEvent", nil)
  merchantOpen = false
  CancelSellTicker()

  if not enabled then
    driver:Hide()
    return
  end

  driver:RegisterEvent("MERCHANT_SHOW")
  driver:RegisterEvent("MERCHANT_CLOSED")
  driver:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then
      OnMerchantShow()
    elseif event == "MERCHANT_CLOSED" then
      OnMerchantClosed()
    end
  end)
  driver:Show()
end

function mod:RunNow()
  local _ = self
  local db = GetDB()
  local generalEnabled = ETBC.db and ETBC.db.profile and ETBC.db.profile.general and ETBC.db.profile.general.enabled
  if not (generalEnabled and db.enabled) then return end
  if not CanMerchant() then return end
  AutoSellJunk(db)
end

if ETBC.ApplyBus and ETBC.ApplyBus.Register then
  ETBC.ApplyBus:Register("vendor", Apply)
  ETBC.ApplyBus:Register("general", Apply)
end

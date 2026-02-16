-- Modules/Mailbox.lua
local ADDON_NAME, ETBC = ...

ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.Mailbox = mod

local driver
local ticker
local tickerOnUpdate
local queue
local pendingAuto = false
local deleteConfirmed = false

local tookMoney = 0
local tookItems = 0
local deleted = 0

local function Print(msg)
  if ETBC.Print then
    ETBC:Print(msg)
  elseif DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99EnhanceTBC|r " .. tostring(msg))
  end
end

local function EnsureDriver()
  if driver then return end
  driver = CreateFrame("Frame", "EnhanceTBC_MailboxDriver", UIParent)
  driver:Hide()
end

local function StopTicker()
  if ticker and ticker.Cancel then
    ticker:Cancel()
  end
  ticker = nil

  if tickerOnUpdate and driver then
    driver:SetScript("OnUpdate", nil)
    tickerOnUpdate = nil
  end
end

function mod:Stop()
  StopTicker()
  queue = nil
  pendingAuto = false
end

local function ResetSession()
  tookMoney, tookItems, deleted = 0, 0, 0
  deleteConfirmed = false
end

local function IsMailboxOpen()
  return (MailFrame and MailFrame:IsShown())
end

local function ShouldBypass(db)
  return db.bypassWithShift and IsShiftKeyDown()
end

local function SenderLooksAH(sender)
  if not sender then return false end
  sender = tostring(sender)
  return sender:find("Auction House", 1, true) ~= nil
end

local function CanTouchMail(db, sender, isGM, codAmount)
  if db.skipCOD and (codAmount and codAmount > 0) then return false end
  if db.skipGM and isGM then return false end
  if db.skipAH and SenderLooksAH(sender) then return false end
  return true
end

local function InboxInfo(i)
  -- Classic/TBC: GetInboxHeaderInfo(index)
  local _, _, sender, subject, money, codAmount, _, itemCount, _, _, _, _, isGM = GetInboxHeaderInfo(i)
  if not sender then
    -- Invalid mail entry (can happen with mail API), return safe defaults
    -- Caller should check for nil sender to skip invalid entries
    return nil, nil, 0, 0, 0, false
  end
  money = tonumber(money) or 0
  codAmount = tonumber(codAmount) or 0
  itemCount = tonumber(itemCount) or 0
  return sender, subject, money, codAmount, itemCount, not not isGM
end

local function BuildQueue(db)
  local q = {}
  local num = GetInboxNumItems() or 0
  -- IMPORTANT: work from high index -> low index to avoid shifting issues
  for i = num, 1, -1 do
    local sender, _, money, cod, itemCount, isGM = InboxInfo(i)
    -- Defensive: Skip invalid mail entries (InboxInfo returns nil sender for invalid entries)
    if sender and CanTouchMail(db, sender, isGM, cod) then
      local hasMoney = money > 0
      local hasItems = itemCount > 0

      if db.collectGold and hasMoney then
        q[#q+1] = { action = "MONEY", index = i, amount = money }
      end

      if db.collectItems and hasItems then
        -- attachments are 1..itemCount (TBC header count)
        for a = 1, itemCount do
          q[#q+1] = { action = "ITEM", index = i, attach = a }
        end
      end

      if db.autoDeleteEmpty then
        q[#q+1] = { action = "MAYBE_DELETE", index = i }
      end
    end
  end

  return q
end

local function MoneyToText(copper)
  copper = tonumber(copper) or 0
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  local c = copper % 100
  if g > 0 then return string.format("%dg %ds %dc", g, s, c) end
  if s > 0 then return string.format("%ds %dc", s, c) end
  return string.format("%dc", c)
end

local function FinishSummary(db)
  if not db.printSummary then return end
  local parts = {}
  if tookMoney > 0 then parts[#parts+1] = ("Gold: %s"):format(MoneyToText(tookMoney)) end
  if tookItems > 0 then parts[#parts+1] = ("Items: %d"):format(tookItems) end
  if deleted > 0 then parts[#parts+1] = ("Deleted: %d"):format(deleted) end
  if #parts > 0 then
    Print("Mailbox • " .. table.concat(parts, " • "))
  end
end

local function ConfirmDeleteIfNeeded(db, onAccept)
  if not db.confirmDelete then
    onAccept()
    return
  end

  StaticPopupDialogs["ENHANCETBC_MAIL_DELETE_CONFIRM"] = {
    text = "EnhanceTBC: Auto-delete empty mail is enabled.\nProceed with deletes?",
    button1 = "Yes",
    button2 = "No",
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    OnAccept = onAccept,
  }
  StaticPopup_Show("ENHANCETBC_MAIL_DELETE_CONFIRM")
end

local function Step(db)
  if not IsMailboxOpen() then
    mod:Stop()
    return
  end

  if not queue or #queue == 0 then
    mod:Stop()
    FinishSummary(db)
    return
  end

  local maxPerTick = (db.throttle and db.throttle.maxPerTick) or 3
  local did = 0

  while did < maxPerTick and queue and #queue > 0 do
    local job = table.remove(queue, 1)
    if not job then break end

    local idx = job.index
    local num = GetInboxNumItems() or 0
    if idx and idx >= 1 and idx <= num then
      local sender, _, money, cod, itemCount, isGM = InboxInfo(idx)

      -- Skip invalid mail entries (InboxInfo returns nil sender for invalid entries)
      if sender and CanTouchMail(db, sender, isGM, cod) then
        if job.action == "MONEY" then
          if db.collectGold and money and money > 0 then
            TakeInboxMoney(idx)
            tookMoney = tookMoney + (money or 0)
          end

        elseif job.action == "ITEM" then
          if db.collectItems and itemCount and itemCount > 0 then
            TakeInboxItem(idx, job.attach or 1)
            tookItems = tookItems + 1
          end

        elseif job.action == "MAYBE_DELETE" then
          if db.autoDeleteEmpty then
            local s2, _, m2, cod2, c2, gm2 = InboxInfo(idx)
            -- Skip invalid mail entries (InboxInfo returns nil sender for invalid entries)
            if s2 and CanTouchMail(db, s2, gm2, cod2) then
              local empty = ((tonumber(m2) or 0) == 0) and ((tonumber(c2) or 0) == 0)
              if empty or (not db.onlyOpenWhenEmpty) then
                if deleteConfirmed then
                  DeleteInboxItem(idx)
                  deleted = deleted + 1
                else
                  -- re-queue this job at front and confirm once
                  table.insert(queue, 1, job)
                  ConfirmDeleteIfNeeded(db, function() deleteConfirmed = true end)
                  break
                end
              end
            end
          end
        end
      end
    end

    did = did + 1
  end
end

local function StartTicker(interval, fn)
  interval = tonumber(interval) or 0.05
  if interval < 0.01 then interval = 0.01 end

  if C_Timer and C_Timer.NewTicker then
    ticker = C_Timer.NewTicker(interval, fn)
    return
  end

  EnsureDriver()
  local acc = 0
  tickerOnUpdate = true
  driver:SetScript("OnUpdate", function(_, elapsed)
    if not tickerOnUpdate then return end
    acc = acc + (elapsed or 0)
    if acc >= interval then
      acc = 0
      fn()
    end
  end)

  ticker = {
    Cancel = function()
      tickerOnUpdate = nil
      if driver then
        driver:SetScript("OnUpdate", nil)
      end
    end,
  }
end

function mod:RunNow()
  local db = ETBC.db.profile.mailbox
  if not (ETBC.db.profile.general.enabled and db.enabled) then return end
  if not IsMailboxOpen() then
    Print("Open your mailbox first.")
    return
  end
  if ShouldBypass(db) then
    Print("Mailbox bypass active (Shift).")
    return
  end

  -- Request inbox data; we'll (re)build on MAIL_INBOX_UPDATE too.
  if CheckInbox then CheckInbox() end

  ResetSession()
  queue = BuildQueue(db)
  
  -- Validate queue before proceeding
  if not queue then return end

  StopTicker()
  local interval = 0.05
  if db.throttle and db.throttle.enabled then
    interval = tonumber(db.throttle.interval) or 0.05
  else
    interval = 0.01
  end
  StartTicker(interval, function() Step(db) end)
end

local function StartAutoIfReady()
  local db = ETBC.db.profile.mailbox
  if not pendingAuto then return end
  pendingAuto = false

  if not (ETBC.db.profile.general.enabled and db.enabled) then return end
  if not IsMailboxOpen() then return end
  if ShouldBypass(db) then return end
  if not db.autoCollect then return end

  mod:RunNow()
end

local function OnMailShow()
  local db = ETBC.db.profile.mailbox
  if not (ETBC.db.profile.general.enabled and db.enabled) then return end
  if ShouldBypass(db) then return end
  if not db.autoCollect then return end

  -- IMPORTANT: wait for inbox to load to avoid acting on empty/partial data
  pendingAuto = true
  if CheckInbox then CheckInbox() end
end

local function OnInboxUpdate()
  local db = ETBC.db.profile.mailbox
  if not (ETBC.db.profile.general.enabled and db.enabled) then return end
  if not IsMailboxOpen() then return end

  -- If we are running, rebuild queue so indices stay correct after each take/delete
  if queue then
    queue = BuildQueue(db)
  end

  -- If mailbox just opened and we’re waiting to auto-run, start now
  StartAutoIfReady()
end

local function OnMailClosed()
  mod:Stop()
end

local function Apply()
  EnsureDriver()
  mod:Stop()

  local p = ETBC.db.profile
  local db = p.mailbox
  local enabled = p.general.enabled and db.enabled

  driver:UnregisterAllEvents()
  driver:SetScript("OnEvent", nil)

  if not enabled then
    driver:Hide()
    return
  end

  driver:RegisterEvent("MAIL_SHOW")
  driver:RegisterEvent("MAIL_INBOX_UPDATE")
  driver:RegisterEvent("MAIL_CLOSED")

  driver:SetScript("OnEvent", function(_, event)
    if event == "MAIL_SHOW" then
      OnMailShow()
    elseif event == "MAIL_INBOX_UPDATE" then
      OnInboxUpdate()
    elseif event == "MAIL_CLOSED" then
      OnMailClosed()
    end
  end)

  driver:Show()
end

ETBC.ApplyBus:Register("mailbox", Apply)
ETBC.ApplyBus:Register("general", Apply)

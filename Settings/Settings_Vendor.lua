-- Settings/Settings_Vendor.lua
local _, ETBC = ...
local function ParseIDList(s)
  local t = {}
  s = tostring(s or "")
  for id in s:gmatch("(%d+)") do
    local n = tonumber(id)
    if n and n > 0 then t[n] = true end
  end
  return t
end

local function ToIDList(t)
  if type(t) ~= "table" then return "" end
  local ids = {}
  for k in pairs(t) do
    if type(k) == "number" then ids[#ids+1] = k end
  end
  table.sort(ids)
  local out = {}
  for i = 1, math.min(#ids, 200) do
    out[#out+1] = tostring(ids[i])
  end
  if #ids > 200 then
    out[#out+1] = "...(+more)"
  end
  return table.concat(out, ", ")
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

local function EnsureDefaults()
  if not ETBC.db or not ETBC.db.profile then return end
  GetDB()
end

ETBC.SettingsRegistry:RegisterGroup("vendor", {
  name = "Vendor",
  order = 60,
  options = function()
    EnsureDefaults()
    local db = GetDB()

    return {
      enabled = {
        type = "toggle",
        name = "Enable Vendor Module",
        order = 1,
        get = function() return db.enabled end,
        set = function(_, v) db.enabled = v and true or false; ETBC.ApplyBus:Notify("vendor") end,
      },

      bypassWithShift = {
        type = "toggle",
        name = "Hold Shift to Bypass",
        desc = "If enabled, holding Shift when opening a merchant bypasses auto-repair and auto-sell.",
        order = 2,
        get = function() return db.bypassWithShift end,
        set = function(_, v) db.bypassWithShift = v and true or false; ETBC.ApplyBus:Notify("vendor") end,
      },

      repair = {
        type = "group",
        name = "Auto Repair",
        desc = "Automatic equipment repairs and guild-repair usage when a merchant is opened.",
        order = 10,
        inline = true,
        args = {
          autoRepair = {
            type = "toggle",
            name = "Auto Repair",
            order = 1,
            get = function() return db.autoRepair end,
            set = function(_, v) db.autoRepair = v and true or false; ETBC.ApplyBus:Notify("vendor") end,
          },
          useGuildRepair = {
            type = "toggle",
            name = "Use Guild Repair (if available)",
            order = 2,
            get = function() return db.useGuildRepair end,
            set = function(_, v) db.useGuildRepair = v and true or false; ETBC.ApplyBus:Notify("vendor") end,
            disabled = function() return not db.autoRepair end,
          },
          repairThreshold = {
            type = "range",
            name = "Minimum Repair Cost (gold)",
            desc = "Only repairs if the total cost meets or exceeds this amount.",
            order = 3,
            min = 0, max = 200, step = 1,
            get = function() return (db.repairThreshold or 0) / 10000 end,
            set = function(_, v) db.repairThreshold = math.floor((v or 0) * 10000); ETBC.ApplyBus:Notify("vendor") end,
            disabled = function() return not db.autoRepair end,
          },
        },
      },

      sell = {
        type = "group",
        name = "Auto Sell Junk",
        desc = "Automatic junk-selling rules, safety checks, and value confirmation settings.",
        order = 20,
        inline = true,
        args = {
          autoSellJunk = {
            type = "toggle",
            name = "Auto Sell Junk (gray items)",
            order = 1,
            get = function() return db.autoSellJunk end,
            set = function(_, v) db.autoSellJunk = v and true or false; ETBC.ApplyBus:Notify("vendor") end,
          },
          maxQualityToSell = {
            type = "select",
            name = "Max Quality to Sell",
            order = 2,
            values = {
              [0] = "Poor (Gray) Only",
              [1] = "Up to Common (White)",
            },
            get = function() return db.maxQualityToSell or 0 end,
            set = function(_, v) db.maxQualityToSell = tonumber(v) or 0; ETBC.ApplyBus:Notify("vendor") end,
            disabled = function() return not db.autoSellJunk end,
          },
          confirmHighValue = {
            type = "toggle",
            name = "Confirm High Value Sells",
            order = 3,
            get = function() return db.confirmHighValue end,
            set = function(_, v) db.confirmHighValue = v and true or false; ETBC.ApplyBus:Notify("vendor") end,
            disabled = function() return not db.autoSellJunk end,
          },
          confirmMinValue = {
            type = "range",
            name = "Confirm Threshold (gold)",
            order = 4,
            min = 1, max = 500, step = 1,
            get = function() return (db.confirmMinValue or 200000) / 10000 end,
            set = function(_, v) db.confirmMinValue = math.floor((v or 20) * 10000); ETBC.ApplyBus:Notify("vendor") end,
            disabled = function() return not (db.autoSellJunk and db.confirmHighValue) end,
          },
          skipLocked = {
            type = "toggle",
            name = "Skip Locked Items",
            desc = "Safer. Avoids trying to sell items the client reports as locked.",
            order = 5,
            get = function() return db.skipLocked end,
            set = function(_, v) db.skipLocked = v and true or false; ETBC.ApplyBus:Notify("vendor") end,
            disabled = function() return not db.autoSellJunk end,
          },
          printSummary = {
            type = "toggle",
            name = "Print Summary",
            order = 6,
            get = function() return db.printSummary end,
            set = function(_, v) db.printSummary = v and true or false; ETBC.ApplyBus:Notify("vendor") end,
          },
        },
      },

      throttle = {
        type = "group",
        name = "Performance",
        desc = "Throttle item selling in batches to reduce vendor action bursts.",
        order = 30,
        inline = true,
        args = {
          enabled = {
            type = "toggle",
            name = "Throttle Selling",
            order = 1,
            get = function() return db.throttle.enabled end,
            set = function(_, v) db.throttle.enabled = v and true or false; ETBC.ApplyBus:Notify("vendor") end,
          },
          interval = {
            type = "range",
            name = "Sell Interval (sec)",
            order = 2,
            min = 0.01, max = 0.25, step = 0.01,
            get = function() return db.throttle.interval end,
            set = function(_, v) db.throttle.interval = v; ETBC.ApplyBus:Notify("vendor") end,
            disabled = function() return not db.throttle.enabled end,
          },
          maxPerTick = {
            type = "range",
            name = "Max Per Tick",
            order = 3,
            min = 1, max = 20, step = 1,
            get = function() return db.throttle.maxPerTick end,
            set = function(_, v) db.throttle.maxPerTick = v; ETBC.ApplyBus:Notify("vendor") end,
            disabled = function() return not db.throttle.enabled end,
          },
        },
      },

      lists = {
        type = "group",
        name = "Lists (Item IDs)",
        desc = "Whitelist/blacklist item ID controls for filtering what the vendor module may auto-sell.",
        order = 40,
        args = {
          whitelistEnabled = {
            type = "toggle",
            name = "Enable Whitelist Mode",
            desc = "If enabled, ONLY sells junk items whose IDs are in the whitelist.",
            order = 1,
            get = function() return db.whitelist.enabled end,
            set = function(_, v) db.whitelist.enabled = v and true or false; ETBC.ApplyBus:Notify("vendor") end,
          },
          whitelistIds = {
            type = "input",
            name = "Whitelist IDs",
            desc = "Comma/space separated item IDs.",
            order = 2,
            width = "full",
            multiline = true,
            get = function() return ToIDList(db.whitelist.items) end,
            set = function(_, v) db.whitelist.items = ParseIDList(v); ETBC.ApplyBus:Notify("vendor") end,
          },
          blacklistEnabled = {
            type = "toggle",
            name = "Enable Blacklist",
            desc = "If enabled, never sells IDs in the blacklist.",
            order = 3,
            get = function() return db.blacklist.enabled end,
            set = function(_, v) db.blacklist.enabled = v and true or false; ETBC.ApplyBus:Notify("vendor") end,
          },
          blacklistIds = {
            type = "input",
            name = "Blacklist IDs",
            desc = "Comma/space separated item IDs.",
            order = 4,
            width = "full",
            multiline = true,
            get = function() return ToIDList(db.blacklist.items) end,
            set = function(_, v) db.blacklist.items = ParseIDList(v); ETBC.ApplyBus:Notify("vendor") end,
          },

          runNow = {
            type = "execute",
            name = "Sell Junk Now",
            desc = "Runs the junk-sell scan immediately (must have vendor window open).",
            order = 10,
            func = function()
              if ETBC.Modules and ETBC.Modules.Vendor and ETBC.Modules.Vendor.RunNow then
                ETBC.Modules.Vendor:RunNow()
              end
            end,
          },
        },
      },
    }
  end,
})

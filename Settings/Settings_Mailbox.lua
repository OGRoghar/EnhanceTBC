-- Settings/Settings_Mailbox.lua
local ADDON_NAME, ETBC = ...

ETBC.SettingsRegistry:RegisterGroup("mailbox", {
  name = "Mailbox",
  order = 70,
  options = function()
    local db = ETBC.db.profile.mailbox

    return {
      enabled = {
        type = "toggle",
        name = "Enable Mailbox Module",
        order = 1,
        get = function() return db.enabled end,
        set = function(_, v) db.enabled = v and true or false; ETBC.ApplyBus:Notify("mailbox") end,
      },

      bypassWithShift = {
        type = "toggle",
        name = "Hold Shift to Bypass",
        desc = "If enabled, holding Shift when opening the mailbox prevents auto-collection.",
        order = 2,
        get = function() return db.bypassWithShift end,
        set = function(_, v) db.bypassWithShift = v and true or false; ETBC.ApplyBus:Notify("mailbox") end,
      },

      collect = {
        type = "group",
        name = "Auto Collect",
        order = 10,
        inline = true,
        args = {
          autoCollect = {
            type = "toggle",
            name = "Auto Collect on Open",
            order = 1,
            get = function() return db.autoCollect end,
            set = function(_, v) db.autoCollect = v and true or false; ETBC.ApplyBus:Notify("mailbox") end,
          },
          collectGold = {
            type = "toggle",
            name = "Collect Gold",
            order = 2,
            get = function() return db.collectGold end,
            set = function(_, v) db.collectGold = v and true or false; ETBC.ApplyBus:Notify("mailbox") end,
            disabled = function() return not db.autoCollect end,
          },
          collectItems = {
            type = "toggle",
            name = "Collect Items",
            order = 3,
            get = function() return db.collectItems end,
            set = function(_, v) db.collectItems = v and true or false; ETBC.ApplyBus:Notify("mailbox") end,
            disabled = function() return not db.autoCollect end,
          },
        },
      },

      safety = {
        type = "group",
        name = "Safety Filters",
        order = 20,
        inline = true,
        args = {
          skipCOD = {
            type = "toggle",
            name = "Skip COD Mail",
            order = 1,
            get = function() return db.skipCOD end,
            set = function(_, v) db.skipCOD = v and true or false; ETBC.ApplyBus:Notify("mailbox") end,
          },
          skipGM = {
            type = "toggle",
            name = "Skip GM Mail",
            order = 2,
            get = function() return db.skipGM end,
            set = function(_, v) db.skipGM = v and true or false; ETBC.ApplyBus:Notify("mailbox") end,
          },
          skipAH = {
            type = "toggle",
            name = "Skip Auction House Mail",
            desc = "Skips mail where the sender looks like Auction House. (Useful if you prefer manual.)",
            order = 3,
            get = function() return db.skipAH end,
            set = function(_, v) db.skipAH = v and true or false; ETBC.ApplyBus:Notify("mailbox") end,
          },
        },
      },

      deleteEmpty = {
        type = "group",
        name = "Delete Empty Mail",
        order = 30,
        inline = true,
        args = {
          autoDeleteEmpty = {
            type = "toggle",
            name = "Auto Delete Empty Mail",
            desc = "Deletes mail that has NO items and NO money (after collection).",
            order = 1,
            get = function() return db.autoDeleteEmpty end,
            set = function(_, v) db.autoDeleteEmpty = v and true or false; ETBC.ApplyBus:Notify("mailbox") end,
          },
          confirmDelete = {
            type = "toggle",
            name = "Confirm Deletes",
            order = 2,
            get = function() return db.confirmDelete end,
            set = function(_, v) db.confirmDelete = v and true or false; ETBC.ApplyBus:Notify("mailbox") end,
            disabled = function() return not db.autoDeleteEmpty end,
          },
          onlyOpenWhenEmpty = {
            type = "toggle",
            name = "Only Delete When Empty",
            desc = "Extra safety. Only deletes mail if it has no money/items.",
            order = 3,
            get = function() return db.onlyOpenWhenEmpty end,
            set = function(_, v) db.onlyOpenWhenEmpty = v and true or false; ETBC.ApplyBus:Notify("mailbox") end,
            disabled = function() return not db.autoDeleteEmpty end,
          },
        },
      },

      perf = {
        type = "group",
        name = "Performance",
        order = 40,
        inline = true,
        args = {
          throttleEnabled = {
            type = "toggle",
            name = "Throttle Actions",
            order = 1,
            get = function() return db.throttle.enabled end,
            set = function(_, v) db.throttle.enabled = v and true or false; ETBC.ApplyBus:Notify("mailbox") end,
          },
          interval = {
            type = "range",
            name = "Interval (sec)",
            order = 2,
            min = 0.02, max = 0.25, step = 0.01,
            get = function() return db.throttle.interval end,
            set = function(_, v) db.throttle.interval = v; ETBC.ApplyBus:Notify("mailbox") end,
            disabled = function() return not db.throttle.enabled end,
          },
          maxPerTick = {
            type = "range",
            name = "Max Per Tick",
            order = 3,
            min = 1, max = 10, step = 1,
            get = function() return db.throttle.maxPerTick end,
            set = function(_, v) db.throttle.maxPerTick = v; ETBC.ApplyBus:Notify("mailbox") end,
            disabled = function() return not db.throttle.enabled end,
          },
          printSummary = {
            type = "toggle",
            name = "Print Summary",
            order = 4,
            get = function() return db.printSummary end,
            set = function(_, v) db.printSummary = v and true or false; ETBC.ApplyBus:Notify("mailbox") end,
          },
        },
      },

      actions = {
        type = "group",
        name = "Actions",
        order = 50,
        inline = true,
        args = {
          collectNow = {
            type = "execute",
            name = "Collect Now",
            desc = "Runs collection immediately (mailbox must be open).",
            order = 1,
            func = function()
              if ETBC.Modules and ETBC.Modules.Mailbox and ETBC.Modules.Mailbox.RunNow then
                ETBC.Modules.Mailbox:RunNow()
              end
            end,
          },
          stop = {
            type = "execute",
            name = "Stop",
            desc = "Stops current mailbox processing.",
            order = 2,
            func = function()
              if ETBC.Modules and ETBC.Modules.Mailbox and ETBC.Modules.Mailbox.Stop then
                ETBC.Modules.Mailbox:Stop()
              end
            end,
          },
        },
      },
    }
  end,
})

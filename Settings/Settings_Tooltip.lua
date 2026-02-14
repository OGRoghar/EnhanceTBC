-- Settings/Settings_Tooltip.lua
local ADDON_NAME, ETBC = ...

local function GetDB()
  ETBC.db.profile.tooltip = ETBC.db.profile.tooltip or {}
  local db = ETBC.db.profile.tooltip

  if db.enabled == nil then db.enabled = true end
  if db.classColorNames == nil then db.classColorNames = true end
  if db.showGuild == nil then db.showGuild = true end
  if db.showTarget == nil then db.showTarget = true end
  if db.showItemId == nil then db.showItemId = true end
  if db.showSpellId == nil then db.showSpellId = true end
  if db.showItemLevel == nil then db.showItemLevel = true end
  if db.showVendorPrice == nil then db.showVendorPrice = true end
  if db.showStatSummary == nil then db.showStatSummary = true end
  if db.statSummaryMax == nil then db.statSummaryMax = 6 end
  if db.anchorMode == nil then db.anchorMode = "DEFAULT" end
  if db.offsetX == nil then db.offsetX = 16 end
  if db.offsetY == nil then db.offsetY = -16 end
  if db.scale == nil then db.scale = 1.0 end

  db.skin = db.skin or {}
  if db.skin.enabled == nil then db.skin.enabled = true end
  db.skin.bg = db.skin.bg or { r = 0.03, g = 0.06, b = 0.03, a = 0.92 }
  db.skin.grad = db.skin.grad or { r = 0.10, g = 0.35, b = 0.10, a = 0.22 }
  db.skin.border = db.skin.border or { r = 0.20, g = 1.00, b = 0.20, a = 0.95 }

  db.healthBar = db.healthBar or {}
  if db.healthBar.enabled == nil then db.healthBar.enabled = true end
  if db.healthBar.classColor == nil then db.healthBar.classColor = true end
  db.healthBar.color = db.healthBar.color or { r = 0.2, g = 1.0, b = 0.2, a = 1.0 }

  return db
end

local function AnchorValues()
  return {
    DEFAULT = "Default",
    CURSOR = "Cursor",
    TOP = "Top",
    BOTTOM = "Bottom",
    TOPLEFT = "Top Left",
    TOPRIGHT = "Top Right",
    BOTTOMLEFT = "Bottom Left",
    BOTTOMRIGHT = "Bottom Right",
  }
end

ETBC.SettingsRegistry:RegisterGroup("tooltip", {
  name = "Tooltip",
  order = 3,
  options = function()
    local db = GetDB()

    return {
      enabled = {
        type = "toggle",
        name = "Enable Tooltip Enhancements",
        order = 1,
        get = function() return db.enabled end,
        set = function(_, v) db.enabled = v and true or false; ETBC.ApplyBus:Notify("tooltip") end,
      },

      content = {
        type = "group",
        name = "Content",
        order = 10,
        inline = true,
        args = {
          classColorNames = {
            type = "toggle", name = "Class Color Unit Names", order = 1,
            get = function() return db.classColorNames end,
            set = function(_, v) db.classColorNames = v and true or false; ETBC.ApplyBus:Notify("tooltip") end,
          },
          showGuild = {
            type = "toggle", name = "Show Guild", order = 2,
            get = function() return db.showGuild end,
            set = function(_, v) db.showGuild = v and true or false; ETBC.ApplyBus:Notify("tooltip") end,
          },
          showTarget = {
            type = "toggle", name = "Show Target-of-Unit", order = 3,
            get = function() return db.showTarget end,
            set = function(_, v) db.showTarget = v and true or false; ETBC.ApplyBus:Notify("tooltip") end,
          },
          showItemId = {
            type = "toggle", name = "Show Item ID", order = 4,
            get = function() return db.showItemId end,
            set = function(_, v) db.showItemId = v and true or false; ETBC.ApplyBus:Notify("tooltip") end,
          },
          showSpellId = {
            type = "toggle", name = "Show Spell ID", order = 5,
            get = function() return db.showSpellId end,
            set = function(_, v) db.showSpellId = v and true or false; ETBC.ApplyBus:Notify("tooltip") end,
          },
        },
      },

      items = {
        type = "group",
        name = "Item Extras",
        order = 15,
        inline = true,
        args = {
          showItemLevel = {
            type = "toggle",
            name = "Show Item Level",
            order = 1,
            get = function() return db.showItemLevel end,
            set = function(_, v) db.showItemLevel = v and true or false; ETBC.ApplyBus:Notify("tooltip") end,
          },
          showVendorPrice = {
            type = "toggle",
            name = "Show Vendor Price",
            order = 2,
            get = function() return db.showVendorPrice end,
            set = function(_, v) db.showVendorPrice = v and true or false; ETBC.ApplyBus:Notify("tooltip") end,
          },
          showStatSummary = {
            type = "toggle",
            name = "Show Stat Summary",
            desc = "Adds one compact line summarizing main stats (uses GetItemStats).",
            order = 3,
            get = function() return db.showStatSummary end,
            set = function(_, v) db.showStatSummary = v and true or false; ETBC.ApplyBus:Notify("tooltip") end,
          },
          statSummaryMax = {
            type = "range",
            name = "Stat Summary Max Stats",
            order = 4,
            min = 3, max = 12, step = 1,
            get = function() return db.statSummaryMax end,
            set = function(_, v) db.statSummaryMax = v; ETBC.ApplyBus:Notify("tooltip") end,
            disabled = function() return not db.showStatSummary end,
          },
        },
      },

      behavior = {
        type = "group",
        name = "Behavior",
        order = 20,
        inline = true,
        args = {
          anchorMode = {
            type = "select", name = "Anchor Mode", order = 1,
            values = AnchorValues,
            get = function() return db.anchorMode end,
            set = function(_, v) db.anchorMode = v; ETBC.ApplyBus:Notify("tooltip") end,
          },
          offsetX = {
            type = "range", name = "Offset X", order = 2,
            min = -100, max = 100, step = 1,
            get = function() return db.offsetX end,
            set = function(_, v) db.offsetX = v; ETBC.ApplyBus:Notify("tooltip") end,
            disabled = function() return db.anchorMode == "DEFAULT" end,
          },
          offsetY = {
            type = "range", name = "Offset Y", order = 3,
            min = -100, max = 100, step = 1,
            get = function() return db.offsetY end,
            set = function(_, v) db.offsetY = v; ETBC.ApplyBus:Notify("tooltip") end,
            disabled = function() return db.anchorMode == "DEFAULT" end,
          },
          scale = {
            type = "range", name = "Scale", order = 4,
            min = 0.75, max = 1.5, step = 0.01,
            get = function() return db.scale end,
            set = function(_, v) db.scale = v; ETBC.ApplyBus:Notify("tooltip") end,
          },
        },
      },

      skin = {
        type = "group",
        name = "Skin",
        order = 25,
        inline = true,
        args = {
          enabled = {
            type = "toggle",
            name = "Enable Subtle Skin",
            desc = "Keeps Blizzard tooltip, adds a dark backdrop + soft green top glow.",
            order = 1,
            get = function() return db.skin.enabled end,
            set = function(_, v) db.skin.enabled = v and true or false; ETBC.ApplyBus:Notify("tooltip") end,
          },
          bg = {
            type = "color",
            name = "Background",
            order = 2,
            hasAlpha = true,
            get = function()
              local c = db.skin.bg
              return c.r, c.g, c.b, (c.a or 1)
            end,
            set = function(_, r, g, b, a)
              local c = db.skin.bg
              c.r, c.g, c.b, c.a = r, g, b, a
              ETBC.ApplyBus:Notify("tooltip")
            end,
            disabled = function() return not db.skin.enabled end,
          },
          grad = {
            type = "color",
            name = "Top Glow",
            order = 3,
            hasAlpha = true,
            get = function()
              local c = db.skin.grad
              return c.r, c.g, c.b, (c.a or 1)
            end,
            set = function(_, r, g, b, a)
              local c = db.skin.grad
              c.r, c.g, c.b, c.a = r, g, b, a
              ETBC.ApplyBus:Notify("tooltip")
            end,
            disabled = function() return not db.skin.enabled end,
          },
          border = {
            type = "color",
            name = "Border",
            order = 4,
            hasAlpha = true,
            get = function()
              local c = db.skin.border
              return c.r, c.g, c.b, (c.a or 1)
            end,
            set = function(_, r, g, b, a)
              local c = db.skin.border
              c.r, c.g, c.b, c.a = r, g, b, a
              ETBC.ApplyBus:Notify("tooltip")
            end,
            disabled = function() return not db.skin.enabled end,
          },
        },
      },

      healthbar = {
        type = "group",
        name = "Health Bar",
        order = 30,
        inline = true,
        args = {
          enabled = {
            type = "toggle", name = "Enable Health Bar Styling", order = 1,
            get = function() return db.healthBar.enabled end,
            set = function(_, v) db.healthBar.enabled = v and true or false; ETBC.ApplyBus:Notify("tooltip") end,
          },
          classColor = {
            type = "toggle", name = "Class Color Health Bar", order = 2,
            get = function() return db.healthBar.classColor end,
            set = function(_, v) db.healthBar.classColor = v and true or false; ETBC.ApplyBus:Notify("tooltip") end,
            disabled = function() return not db.healthBar.enabled end,
          },
          color = {
            type = "color", name = "Health Bar Color", order = 3,
            hasAlpha = true,
            get = function()
              local c = db.healthBar.color
              return c.r, c.g, c.b, (c.a or 1)
            end,
            set = function(_, r, g, b, a)
              local c = db.healthBar.color
              c.r, c.g, c.b, c.a = r, g, b, a
              ETBC.ApplyBus:Notify("tooltip")
            end,
            disabled = function() return (not db.healthBar.enabled) or db.healthBar.classColor end,
          },
        },
      },
    }
  end,
})

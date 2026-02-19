-- Settings/Settings_GCDBar.lua
local ADDON_NAME, ETBC = ...
local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceTBC")
local LSM = nil
if LibStub then
  local ok, lib = pcall(LibStub, "LibSharedMedia-3.0")
  if ok and lib then LSM = lib end
end

local function GetDB()
  ETBC.db.profile.gcdbar = ETBC.db.profile.gcdbar or {}
  local db = ETBC.db.profile.gcdbar

  if db.enabled == nil then db.enabled = true end
  if db.width == nil then db.width = 220 end
  if db.height == nil then db.height = 12 end

  if db.texture == nil then db.texture = "Blizzard" end

  if db.alpha == nil then db.alpha = 1.0 end
  if db.bgAlpha == nil then db.bgAlpha = 0.35 end
  if db.border == nil then db.border = true end

  if db.reverseFill == nil then db.reverseFill = false end
  if db.spark == nil then db.spark = true end

  if db.colorMode == nil then db.colorMode = "CLASS" end -- CLASS / CUSTOM
  db.customColor = db.customColor or { r = 0.20, g = 1.00, b = 0.20, a = 1 }

  if db.fadeOut == nil then db.fadeOut = true end
  if db.fadeDelay == nil then db.fadeDelay = 0.15 end
  if db.fadeDuration == nil then db.fadeDuration = 0.25 end

  if db.preview == nil then db.preview = false end

  return db
end

local function EnsureDefaults()
  if not ETBC.db or not ETBC.db.profile then return end
  GetDB()
end

local function GetTextures()
  if LSM and LSM.HashTable then
    return LSM:HashTable("statusbar")
  end
  return {
    ["Blizzard"] = "Interface\\TargetingFrame\\UI-StatusBar",
    ["Flat"] = "Interface\\Buttons\\WHITE8x8",
  }
end

ETBC.SettingsRegistry:RegisterGroup("gcdbar", {
  name = "GCD Bar",
  order = 60,
  options = function()
    EnsureDefaults()
    local db = GetDB()

    return {
      enabled = {
        type = "toggle",
        name = "Enable GCD Bar",
        order = 1,
        get = function() return db.enabled end,
        set = function(_, v) db.enabled = v and true or false; ETBC.ApplyBus:Notify("gcdbar") end,
      },

      preview = {
        type = "toggle",
        name = "Preview (show bar)",
        desc = "For positioning and styling. Does not require combat.",
        order = 2,
        get = function() return db.preview end,
        set = function(_, v) db.preview = v and true or false; ETBC.ApplyBus:Notify("gcdbar") end,
        disabled = function() return not db.enabled end,
      },

      layout = {
        type = "group",
        name = "Layout",
        order = 10,
        inline = true,
        args = {
          width = {
            type = "range",
            name = "Width",
            order = 1,
            min = 80, max = 800, step = 1,
            get = function() return db.width end,
            set = function(_, v) db.width = v; ETBC.ApplyBus:Notify("gcdbar") end,
          },
          height = {
            type = "range",
            name = "Height",
            order = 2,
            min = 6, max = 60, step = 1,
            get = function() return db.height end,
            set = function(_, v) db.height = v; ETBC.ApplyBus:Notify("gcdbar") end,
          },
          alpha = {
            type = "range",
            name = "Alpha",
            order = 3,
            min = 0.05, max = 1.0, step = 0.01,
            get = function() return db.alpha end,
            set = function(_, v) db.alpha = v; ETBC.ApplyBus:Notify("gcdbar") end,
          },
          bgAlpha = {
            type = "range",
            name = "Background Alpha",
            order = 4,
            min = 0.0, max = 1.0, step = 0.01,
            get = function() return db.bgAlpha end,
            set = function(_, v) db.bgAlpha = v; ETBC.ApplyBus:Notify("gcdbar") end,
          },
          border = {
            type = "toggle",
            name = "Border",
            order = 5,
            get = function() return db.border end,
            set = function(_, v) db.border = v and true or false; ETBC.ApplyBus:Notify("gcdbar") end,
          },
        },
      },

      visuals = {
        type = "group",
        name = "Visuals",
        order = 20,
        inline = true,
        args = {
          texture = {
            type = "select",
            name = "Texture",
            order = 1,
            values = GetTextures(),
            get = function() return db.texture end,
            set = function(_, v) db.texture = v; ETBC.ApplyBus:Notify("gcdbar") end,
          },
          reverseFill = {
            type = "toggle",
            name = "Reverse Fill",
            order = 2,
            get = function() return db.reverseFill end,
            set = function(_, v) db.reverseFill = v and true or false; ETBC.ApplyBus:Notify("gcdbar") end,
          },
          spark = {
            type = "toggle",
            name = "Spark",
            order = 3,
            get = function() return db.spark end,
            set = function(_, v) db.spark = v and true or false; ETBC.ApplyBus:Notify("gcdbar") end,
          },
          colorMode = {
            type = "select",
            name = "Color Mode",
            order = 4,
            values = { CLASS = "Class Color", CUSTOM = "Custom" },
            get = function() return db.colorMode end,
            set = function(_, v) db.colorMode = v; ETBC.ApplyBus:Notify("gcdbar") end,
          },
          customColor = {
            type = "color",
            name = "Custom Color",
            order = 5,
            hasAlpha = false,
            get = function()
              local c = db.customColor or { r = 0.2, g = 1, b = 0.2 }
              return c.r, c.g, c.b
            end,
            set = function(_, r, g, b)
              db.customColor = db.customColor or {}
              db.customColor.r, db.customColor.g, db.customColor.b = r, g, b
              ETBC.ApplyBus:Notify("gcdbar")
            end,
            disabled = function() return db.colorMode ~= "CUSTOM" end,
          },
        },
      },

      fade = {
        type = "group",
        name = "Fade",
        order = 30,
        inline = true,
        args = {
          fadeOut = {
            type = "toggle",
            name = "Fade out when ready",
            order = 1,
            get = function() return db.fadeOut end,
            set = function(_, v) db.fadeOut = v and true or false; ETBC.ApplyBus:Notify("gcdbar") end,
          },
          fadeDelay = {
            type = "range",
            name = "Fade delay (sec)",
            order = 2,
            min = 0, max = 1.5, step = 0.01,
            get = function() return db.fadeDelay end,
            set = function(_, v) db.fadeDelay = v; ETBC.ApplyBus:Notify("gcdbar") end,
            disabled = function() return not db.fadeOut end,
          },
          fadeDuration = {
            type = "range",
            name = "Fade duration (sec)",
            order = 3,
            min = 0.05, max = 1.5, step = 0.01,
            get = function() return db.fadeDuration end,
            set = function(_, v) db.fadeDuration = v; ETBC.ApplyBus:Notify("gcdbar") end,
            disabled = function() return not db.fadeOut end,
          },
        },
      },
    }
  end,
})

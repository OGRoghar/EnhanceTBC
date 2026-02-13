-- Options/Options.lua
-- EnhanceTBC - builds the AceConfig options table from SettingsRegistry groups.

local ADDON_NAME, ETBC = ...

local function SafeCall(fn, selfArg)
  if type(fn) ~= "function" then return nil, "not a function" end
  local ok, v = pcall(fn, selfArg)
  if ok then return v, nil end
  return nil, v
end

local function ErrorArgs(msg)
  return {
    _err = {
      type = "description",
      name = "|cffff5555Error:|r " .. tostring(msg or "unknown"),
      order = 1,
      width = "full",
    },
  }
end

function ETBC:BuildOptions()
  local opts = {
    type = "group",
    name = "EnhanceTBC",
    args = {
      modules = {
        type = "group",
        name = "Modules",
        childGroups = "tree",
        order = 1,
        args = {},
      },
      about = {
        type = "group",
        name = "About",
        order = 998,
        args = {
          header = { type = "header", name = "EnhanceTBC", order = 1 },
          desc = {
            type = "description",
            name = "QoL suite for TBC Anniversary.\n\nUse /etbc for the custom config window.\nUse ESC → Options → AddOns for Blizzard panel.",
            order = 2,
          },
        },
      },
    },
  }

  local SR = ETBC.SettingsRegistry
  if not SR or type(SR.GetGroups) ~= "function" then
    opts.args.modules.args._missing = {
      type = "description",
      name = "SettingsRegistry not available.",
      order = 1,
    }
    return opts
  end

  local groups = SR:GetGroups()
  if type(groups) ~= "table" then return opts end

  for _, g in ipairs(groups) do
    if type(g) == "table" and g.key and g.name and g.options then
      local key = tostring(g.key)
      local name = tostring(g.name)

      -- Always create a container group for this module
      local modGroup = {
        type = "group",
        name = name,
        order = tonumber(g.order) or 1000,
        args = {},
      }

      -- Build options safely. Pass g as self to support `function group:options()`
      local built, err = SafeCall(g.options, g)

      if type(built) ~= "table" then
        modGroup.args = ErrorArgs(err or "Failed to build options for this module.")
        opts.args.modules.args[key] = modGroup
      else
        -- Pattern A: options() returns a full AceConfig group table
        if built.type == "group" and type(built.args) == "table" then
          -- Keep name/order if missing
          built.name = built.name or name
          built.order = built.order or (tonumber(g.order) or 1000)
          opts.args.modules.args[key] = built

        -- Pattern B: options() returns just an args-table (your Settings_Auras style)
        else
          modGroup.args = built
          opts.args.modules.args[key] = modGroup
        end
      end
    end
  end

  return opts
end

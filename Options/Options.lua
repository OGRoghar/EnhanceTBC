-- Options/Options.lua
-- EnhanceTBC - builds the AceConfig options table from SettingsRegistry groups.

local ADDON_NAME, ETBC = ...

local function SafeCall(fn)
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn)
  if ok then return v end
  return nil
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

      opts.args.modules.args[key] = {
        type = "group",
        name = name,
        order = tonumber(g.order) or 1000,
        args = {},
      }

      -- Support two patterns:
      --  A) g.options() returns a full AceConfig group (type/name/args)
      --  B) g.options() returns just args-table
      local built = SafeCall(g.options)
      if type(built) == "table" then
        if built.type == "group" and type(built.args) == "table" then
          -- use returned group (but keep our ordering/name if missing)
          opts.args.modules.args[key] = built
          opts.args.modules.args[key].name = opts.args.modules.args[key].name or name
          opts.args.modules.args[key].order = opts.args.modules.args[key].order or (tonumber(g.order) or 1000)
        elseif type(built.args) == "table" and built.type then
          -- group-like
          opts.args.modules.args[key] = built
          opts.args.modules.args[key].name = opts.args.modules.args[key].name or name
          opts.args.modules.args[key].order = opts.args.modules.args[key].order or (tonumber(g.order) or 1000)
        else
          -- assume "args table"
          opts.args.modules.args[key].args = built
        end
      else
        opts.args.modules.args[key].args._err = {
          type = "description",
          name = "Failed to build options for this module.",
          order = 1,
        }
      end
    end
  end

  return opts
end

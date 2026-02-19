-- Options/Options.lua
-- EnhanceTBC - builds the AceConfig options table from SettingsRegistry groups.

local _, ETBC = ...

local function SafeCall(fn)
  if type(fn) ~= "function" then return false, nil, "not a function" end
  local ok, v = pcall(fn)
  if ok then return true, v, nil end
  return false, nil, tostring(v)
end

local function AsNumber(v, fallback)
  local n = tonumber(v)
  if n then return n end
  return fallback
end

local function EnsureGroup(tbl, name, order)
  if type(tbl) ~= "table" then
    return {
      type = "group",
      name = name,
      order = order,
      args = {},
    }
  end

  tbl.type = "group"
  tbl.name = tbl.name or name
  tbl.order = AsNumber(tbl.order, order)
  if type(tbl.args) ~= "table" then
    tbl.args = {}
  end
  return tbl
end

local function InjectResetAction(group, key, name)
  if type(group) ~= "table" or type(group.args) ~= "table" then return end
  if type(ETBC) ~= "table" or type(ETBC.ResetModuleProfile) ~= "function" then return end

  if group.args.__etbcResetModule then return end

  local maxOrder = 0
  for _, opt in pairs(group.args) do
    if type(opt) == "table" then
      local n = tonumber(opt.order)
      if n and n > maxOrder then
        maxOrder = n
      end
    end
  end

  group.args.__etbcResetHeader = {
    type = "header",
    name = "Reset",
    order = maxOrder + 100,
  }

  group.args.__etbcResetModule = {
    type = "execute",
    name = "Reset this module",
    desc = "Resets only this module's profile settings to defaults.",
    order = maxOrder + 101,
    func = function()
      local ok, err = ETBC:ResetModuleProfile(key)
      if ok then
        ETBC:Print("Reset module: " .. tostring(name or key))
      else
        ETBC:Print("Reset failed for " .. tostring(name or key) .. ": " .. tostring(err))
      end
    end,
  }
end

function ETBC:BuildOptions()
  local _ = self
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
            name = "QoL suite for TBC Anniversary.\n\nUse /etbc for the custom config window.\n"
              .. "Use ESC -> Options -> AddOns for Blizzard panel.",
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
  if #groups == 0 then
    opts.args.modules.args._empty = {
      type = "description",
      name = "No settings groups are registered yet.",
      order = 1,
    }
    return opts
  end

  table.sort(groups, function(a, b)
    local ao = AsNumber(type(a) == "table" and a.order, 1000)
    local bo = AsNumber(type(b) == "table" and b.order, 1000)
    if ao ~= bo then
      return ao < bo
    end

    local ak = tostring(type(a) == "table" and a.key or "")
    local bk = tostring(type(b) == "table" and b.key or "")
    if ak ~= bk then
      return ak < bk
    end

    local an = tostring(type(a) == "table" and a.name or "")
    local bn = tostring(type(b) == "table" and b.name or "")
    return an < bn
  end)

  local seen = {}
  for _, g in ipairs(groups) do
    if type(g) == "table" and g.key and g.name and g.options then
      local key = tostring(g.key)
      local name = tostring(g.name)
      local order = AsNumber(g.order, 1000)

      if not seen[key] then
        seen[key] = true

        local baseGroup = {
          type = "group",
          name = name,
          order = order,
          args = {},
        }
        opts.args.modules.args[key] = baseGroup

        -- Support two patterns:
        --  A) g.options() returns a full AceConfig group (type/name/args)
        --  B) g.options() returns just args-table
        local ok, built, err = SafeCall(g.options)
        if ok and type(built) == "table" then
          if built.type == "group" and type(built.args) == "table" then
            opts.args.modules.args[key] = EnsureGroup(built, name, order)
          elseif type(built.args) == "table" or built.type then
            opts.args.modules.args[key] = EnsureGroup(built, name, order)
          else
            -- assume "args table"
            baseGroup.args = built
          end

          InjectResetAction(opts.args.modules.args[key], key, name)
        else
          baseGroup.args._err = {
            type = "description",
            name = "Failed to build options for " .. name .. "."
              .. (err and ("\nReason: " .. err) or ""),
            order = 1,
          }
        end
      end
    end
  end

  return opts
end

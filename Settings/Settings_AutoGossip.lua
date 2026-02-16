-- Settings/Settings_AutoGossip.lua
local ADDON_NAME, ETBC = ...

local function GetDB()
  ETBC.db.profile.autoGossip = ETBC.db.profile.autoGossip or {}
  local db = ETBC.db.profile.autoGossip
  
  if db.enabled == nil then db.enabled = true end
  if db.delay == nil then db.delay = 0 end
  db.options = db.options or {}
  
  return db
end

local function Apply()
  if ETBC.ApplyBus and ETBC.ApplyBus.Notify then
    ETBC.ApplyBus:Notify("autogossip")
  end
end

local tempText = ""

ETBC.SettingsRegistry:RegisterGroup("autoGossip", {
  name = "Auto-Gossip",
  order = 50,
  options = function()
    local db = GetDB()
    
    return {
      enabled = {
        type = "toggle",
        name = "Enable Auto-Gossip",
        desc = "Automatically select specific NPC dialog options to speed up interactions.",
        order = 1,
        width = "full",
        get = function() return db.enabled end,
        set = function(_, v)
          db.enabled = v and true or false
          Apply()
        end,
      },
      
      delay = {
        type = "range",
        name = "Selection Delay",
        desc = "Delay (in seconds) before auto-selecting a gossip option.",
        order = 2,
        min = 0,
        max = 2,
        step = 0.1,
        get = function() return db.delay end,
        set = function(_, v)
          db.delay = v
          Apply()
        end,
      },
      
      optionsHeader = {
        type = "header",
        name = "Gossip Options to Auto-Select",
        order = 10,
      },
      
      optionsDesc = {
        type = "description",
        name = "Add gossip option text patterns that should be automatically selected. These are matched case-insensitively.",
        order = 11,
      },
      
      addOption = {
        type = "group",
        name = "Add Option",
        order = 15,
        inline = true,
        args = {
          text = {
            type = "input",
            name = "Gossip Text Pattern",
            desc = "Enter the text of a gossip option to auto-select (e.g., 'I want to fly', 'Train me').",
            order = 1,
            width = "double",
            get = function() return tempText end,
            set = function(_, v) tempText = v end,
          },
          add = {
            type = "execute",
            name = "Add",
            desc = "Add this pattern to the auto-select list.",
            order = 2,
            func = function()
              if tempText and tempText ~= "" then
                local pattern = tempText:trim()
                if pattern ~= "" then
                  -- Check if already exists
                  local exists = false
                  for _, existing in ipairs(db.options) do
                    if existing:lower() == pattern:lower() then
                      exists = true
                      break
                    end
                  end
                  
                  if not exists then
                    table.insert(db.options, pattern)
                    tempText = ""
                    Apply()
                    if ETBC.Print then
                      ETBC:Print("Added auto-gossip pattern: " .. pattern)
                    end
                  else
                    if ETBC.Print then
                      ETBC:Print("Pattern already exists: " .. pattern)
                    end
                  end
                end
              end
            end,
          },
        },
      },
      
      currentOptions = {
        type = "group",
        name = "Current Auto-Select Patterns",
        order = 20,
        inline = true,
        args = {},
      },
    }
  end,
  
  -- Dynamic options generation for the list
  postProcess = function(options)
    local db = GetDB()
    
    -- Clear previous entries
    options.currentOptions.args = {}
    
    if #db.options == 0 then
      options.currentOptions.args.empty = {
        type = "description",
        name = "|cffaaaaaa(No patterns added yet)|r",
        order = 1,
      }
    else
      for i, pattern in ipairs(db.options) do
        options.currentOptions.args["option" .. i] = {
          type = "group",
          name = "",
          order = i,
          inline = true,
          args = {
            text = {
              type = "description",
              name = "|cff00ff00" .. pattern .. "|r",
              order = 1,
              width = "double",
            },
            remove = {
              type = "execute",
              name = "Remove",
              order = 2,
              func = function()
                table.remove(db.options, i)
                Apply()
                if ETBC.Print then
                  ETBC:Print("Removed auto-gossip pattern: " .. pattern)
                end
              end,
            },
          },
        }
      end
    end
    
    return options
  end,
})

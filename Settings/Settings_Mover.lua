-- Settings/Settings_Mover.lua
-- EnhanceTBC - Mover settings (grid + unlock/lock + snap)

local _, ETBC = ...
local function GetDB()
  ETBC.db.profile.mover = ETBC.db.profile.mover or {}
  local db = ETBC.db.profile.mover

  if db.enabled == nil then db.enabled = true end
  if db.unlocked == nil then db.unlocked = false end
  if db.moveMode == nil then db.moveMode = false end

  if db.snapToGrid == nil then db.snapToGrid = true end
  if db.gridSize == nil then db.gridSize = 50 end
  if db.showGrid == nil then db.showGrid = true end
  if db.gridAlpha == nil then db.gridAlpha = 0.25 end

  if db.handleAlpha == nil then db.handleAlpha = 0.85 end
  if db.handleScale == nil then db.handleScale = 1.0 end
  if db.showFrameNames == nil then db.showFrameNames = true end

  if db.onlyOutOfCombat == nil then db.onlyOutOfCombat = true end
  if db.clampToScreen == nil then db.clampToScreen = true end

  -- Optional nudge step (pixels)
  if db.nudge == nil then db.nudge = 1 end

  return db
end

local function EnsureDefaults()
  if not ETBC.db or not ETBC.db.profile then return end
  GetDB()
end

ETBC.SettingsRegistry:RegisterGroup("mover", {
  name = "Mover",
  order = 60,
  options = function()
    EnsureDefaults()
    local db = GetDB()

    return {
      enabled = {
        type = "toggle",
        name = "Enable Mover",
        desc = "Provides a global lock/unlock system for moving registered frames.",
        order = 1,
        width = "full",
        get = function() return db.enabled end,
        set = function(_, v)
          db.enabled = v and true or false
          ETBC.ApplyBus:Notify("mover")
        end,
      },

      masterMove = {
        type = "toggle",
        name = "Master Move Mode",
        desc = "Shows all mover handles and the move-mode overlay at once.",
        order = 1.5,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.unlocked and db.moveMode end,
        set = function(_, v)
          if ETBC.Mover and ETBC.Mover.SetMasterMove then
            ETBC.Mover:SetMasterMove(v and true or false)
          else
            db.unlocked = v and true or false
            db.moveMode = v and true or false
            ETBC.ApplyBus:Notify("mover")
          end
        end,
      },

      unlocked = {
        type = "toggle",
        name = "Unlocked (Move Mode)",
        desc = "When enabled, mover handles appear for registered frames and you can drag them.",
        order = 2,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.unlocked end,
        set = function(_, v)
          db.unlocked = v and true or false
          ETBC.ApplyBus:Notify("mover")
        end,
      },

      headerGrid = { type = "header", name = "Grid / Snap", order = 10 },

      showGrid = {
        type = "toggle",
        name = "Show grid while unlocked",
        order = 11,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.showGrid end,
        set = function(_, v)
          db.showGrid = v and true or false
          ETBC.ApplyBus:Notify("mover")
        end,
      },

      gridSize = {
        type = "range",
        name = "Grid size",
        order = 12,
        min = 2, max = 64, step = 1,
        disabled = function() return not db.enabled end,
        get = function() return db.gridSize end,
        set = function(_, v)
          db.gridSize = v
          ETBC.ApplyBus:Notify("mover")
        end,
      },

      gridAlpha = {
        type = "range",
        name = "Grid alpha",
        order = 13,
        min = 0.05, max = 0.80, step = 0.01,
        disabled = function() return not db.enabled end,
        get = function() return db.gridAlpha end,
        set = function(_, v)
          db.gridAlpha = v
          ETBC.ApplyBus:Notify("mover")
        end,
      },

      snapToGrid = {
        type = "toggle",
        name = "Snap to grid",
        order = 14,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.snapToGrid end,
        set = function(_, v)
          db.snapToGrid = v and true or false
          ETBC.ApplyBus:Notify("mover")
        end,
      },

      headerHandles = { type = "header", name = "Handles", order = 20 },

      handleAlpha = {
        type = "range",
        name = "Handle alpha",
        order = 21,
        min = 0.10, max = 1.0, step = 0.01,
        disabled = function() return not db.enabled end,
        get = function() return db.handleAlpha end,
        set = function(_, v)
          db.handleAlpha = v
          ETBC.ApplyBus:Notify("mover")
        end,
      },

      handleScale = {
        type = "range",
        name = "Handle scale",
        order = 22,
        min = 0.5, max = 2.0, step = 0.01,
        disabled = function() return not db.enabled end,
        get = function() return db.handleScale end,
        set = function(_, v)
          db.handleScale = v
          ETBC.ApplyBus:Notify("mover")
        end,
      },

      showFrameNames = {
        type = "toggle",
        name = "Show frame names on handles",
        order = 23,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.showFrameNames end,
        set = function(_, v)
          db.showFrameNames = v and true or false
          ETBC.ApplyBus:Notify("mover")
        end,
      },

      headerSafety = { type = "header", name = "Safety", order = 30 },

      onlyOutOfCombat = {
        type = "toggle",
        name = "Only allow moving out of combat",
        desc = "Prevents dragging (and avoids taint) while in combat.",
        order = 31,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.onlyOutOfCombat end,
        set = function(_, v)
          db.onlyOutOfCombat = v and true or false
          ETBC.ApplyBus:Notify("mover")
        end,
      },

      clampToScreen = {
        type = "toggle",
        name = "Clamp handles to screen",
        order = 32,
        width = "full",
        disabled = function() return not db.enabled end,
        get = function() return db.clampToScreen end,
        set = function(_, v)
          db.clampToScreen = v and true or false
          ETBC.ApplyBus:Notify("mover")
        end,
      },

      headerNudge = { type = "header", name = "Nudge", order = 40 },

      nudge = {
        type = "range",
        name = "Nudge step (px)",
        order = 41,
        min = 1, max = 20, step = 1,
        disabled = function() return not db.enabled end,
        get = function() return db.nudge end,
        set = function(_, v)
          db.nudge = v
          ETBC.ApplyBus:Notify("mover")
        end,
      },
    }
  end,
})

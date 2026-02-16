-- Core/MinimapButton.lua
-- EnhanceTBC - Minimap Button (LibDataBroker + LibDBIcon)
-- Safe: no ETBC.db access at file load.

local ADDON_NAME, ETBC = ...
local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceTBC")
if not ETBC then return end

local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
if not LDB or not LDBIcon then return end

local ICON_PATH = "Interface\\AddOns\\EnhanceTBC\\Media\\Images\\minimap.tga"

-- Crop coords for circular minimap mask (reduces "tiny icon" look)
local ICON_COORDS = { 0.08, 0.92, 0.08, 0.92 }
local unpackFn = _G.unpack or table.unpack

local dataObject

local function EnsureDB()
  if not ETBC.db or not ETBC.db.profile then return nil end
  ETBC.db.profile.minimapIcon = ETBC.db.profile.minimapIcon or { hide = false }
  return ETBC.db.profile.minimapIcon
end

local function EnsureDataObject()
  if dataObject then return end

  dataObject = LDB:NewDataObject("EnhanceTBC", {
    type = "data source",
    text = "EnhanceTBC",
    icon = ICON_PATH,
    iconCoords = ICON_COORDS,

    OnClick = function(_, button)
      if button == "LeftButton" then
        if ETBC.OpenConfig then
          ETBC:OpenConfig()
        elseif ETBC.UI and ETBC.UI.ConfigWindow and ETBC.UI.ConfigWindow.Toggle then
          ETBC.UI.ConfigWindow:Toggle()
        elseif ETBC.SlashCommand then
          ETBC:SlashCommand("")
        end
      elseif button == "RightButton" then
        -- Show/hide the sink tray (not toggle enabled state)
        if ETBC.Modules and ETBC.Modules.MinimapPlus and ETBC.Modules.MinimapPlus.ToggleSinkVisibility then
          ETBC.Modules.MinimapPlus:ToggleSinkVisibility()
        end
      end
    end,

    OnTooltipShow = function(tooltip)
      if not tooltip or not tooltip.AddLine then return end

      tooltip:AddLine("|cff33ff99EnhanceTBC|r")
      tooltip:AddLine(" ")
      tooltip:AddLine("|cffffffffLeft Click:|r Open Config")
      tooltip:AddLine("|cffffffffRight Click:|r Show/Hide Button Sink")
      tooltip:AddLine(" ")

      if ETBC.db and ETBC.db.profile and ETBC.db.profile.minimapPlus then
        local sinkShown = ETBC.Modules and ETBC.Modules.MinimapPlus and ETBC.Modules.MinimapPlus.IsSinkShown 
          and ETBC.Modules.MinimapPlus:IsSinkShown() or false
        local state = sinkShown and "|cff00ff00Visible|r" or "|cffff0000Hidden|r"
        tooltip:AddLine("Button Sink: " .. state)
      end
    end,
  })
end

function ETBC:InitMinimapIcon()
  local db = EnsureDB()
  if not db then return end

  EnsureDataObject()

  if not self._minimapRegistered then
    self._minimapRegistered = true
    LDBIcon:Register("EnhanceTBC", dataObject, db)

    local btn = LDBIcon:GetMinimapButton("EnhanceTBC")
    if btn and btn.icon and btn.icon.SetTexCoord then
      if unpackFn then
        btn.icon:SetTexCoord(unpackFn(ICON_COORDS))
      end
    end
  end

  if db.hide then
    LDBIcon:Hide("EnhanceTBC")
  else
    LDBIcon:Show("EnhanceTBC")
  end
end

function ETBC:ToggleMinimapIcon(show)
  local db = EnsureDB()
  if not db then return end

  if show == nil then
    db.hide = not db.hide
  else
    db.hide = not (show and true or false)
  end

  if not self._minimapRegistered then
    self:InitMinimapIcon()
  end

  if db.hide then
    LDBIcon:Hide("EnhanceTBC")
  else
    LDBIcon:Show("EnhanceTBC")
  end
end

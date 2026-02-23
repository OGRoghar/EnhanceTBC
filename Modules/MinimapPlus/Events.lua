-- Modules/MinimapPlus_Events.lua
-- EnhanceTBC - MinimapPlus event frame driver (internal).

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}

local mod = ETBC.Modules.MinimapPlus
if not mod then return end

mod.Internal = mod.Internal or {}
local H = {}
mod.Internal.Events = H

local function GetShared()
  return mod.Internal and mod.Internal.Shared
end

local function GetState()
  local shared = GetShared()
  return shared and shared.state
end

local function IsFeatureEnabled()
  local shared = GetShared()
  if shared and type(shared.IsFeatureEnabled) == "function" then
    return shared.IsFeatureEnabled()
  end
  return false
end

local function EnsureEventFrame()
  local state = GetState()
  if not state or state.eventFrame then return end

  state.eventFrame = CreateFrame("Frame", "EnhanceTBC_MinimapEventFrame")
  state.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  state.eventFrame:RegisterEvent("ADDON_LOADED")
  state.eventFrame:RegisterEvent("BAG_UPDATE")
  state.eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
  state.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
  state.eventFrame:RegisterEvent("MERCHANT_CLOSED")
  state.eventFrame:RegisterEvent("FRIENDLIST_UPDATE")
  state.eventFrame:RegisterEvent("BN_FRIEND_INFO_CHANGED")
  state.eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
  state.eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
  state.eventFrame:RegisterEvent("MINIMAP_UPDATE_TRACKING")
  state.eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if not IsFeatureEnabled() then return end

    if event == "ADDON_LOADED" then
      if arg1 == "Blizzard_TimeManager" then
        mod:StyleTimeManagerClockButton()
      elseif arg1 == "Blizzard_GroupFinder_VanillaStyle" then
        mod:MoveMinimapLFGButton()
      elseif arg1 == "Blizzard_BattlefieldMap" then
        mod:StyleBattlefieldMinimap()
      end
      mod:ScanForAddonButtons(true)
      return
    end

    if event == "PLAYER_ENTERING_WORLD" then
      if state.iconsFrame then
        state.iconsFrame:updateInventoryDisplay()
        state.iconsFrame:updateDurabilityDisplay()
        state.iconsFrame:updateFriendsDisplay()
        state.iconsFrame:updateGuildDisplay()
        if state.iconsFrame.updateTrackingDisplay then
          state.iconsFrame:updateTrackingDisplay()
        end
      end
      if state.sinkFrame and state.sinkFrame.updateTrackingDisplay then
        state.sinkFrame:updateTrackingDisplay()
      end
      mod:StyleTimeManagerClockButton()
      mod:MoveMinimapLFGButton()
      mod:StyleBattlefieldMinimap()
      mod:ScanForAddonButtons(true)
      return
    end

    if event == "BAG_UPDATE" and type(arg1) == "number" and arg1 <= NUM_BAG_SLOTS then
      if state.iconsFrame then state.iconsFrame:updateInventoryDisplay() end
      return
    end

    if event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_REGEN_ENABLED" or event == "MERCHANT_CLOSED" then
      if state.iconsFrame then state.iconsFrame:updateDurabilityDisplay() end
      if event == "PLAYER_REGEN_ENABLED" then mod:ScanForAddonButtons(true) end
      return
    end

    if event == "FRIENDLIST_UPDATE" or event == "BN_FRIEND_INFO_CHANGED" then
      if state.iconsFrame then state.iconsFrame:updateFriendsDisplay() end
      return
    end

    if event == "GUILD_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then
      if state.iconsFrame then state.iconsFrame:updateGuildDisplay() end
      return
    end

    if event == "MINIMAP_UPDATE_TRACKING" then
      if state.iconsFrame and state.iconsFrame.updateTrackingDisplay then
        state.iconsFrame:updateTrackingDisplay()
      end
      if state.sinkFrame and state.sinkFrame.updateTrackingDisplay then
        state.sinkFrame:updateTrackingDisplay()
      end
    end
  end)
end

H.EnsureEventFrame = EnsureEventFrame

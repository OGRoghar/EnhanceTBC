-- Modules/MinimapPlus.lua
-- EnhanceTBC - Minimap styling, info rows, and addon button sink.

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}

local mod = {}
ETBC.Modules.MinimapPlus = mod

local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)

local MINIMAP_SIZE = 165
local ROUND_MASK_TEXTURE = "Textures\\MinimapMask"

local SQUARE_MASK_TEXTURE = "Interface\\ChatFrame\\ChatFrameBackground"
local MINIMAP_CONTAINER_FLAG = "etbc_minimap_container"
local RIGHT_MANAGED_FLAG = "etbc_ui_parent_right_managed_frame"
local TRACKING_POINT_FLAG = "etbc_tracking_button"
local LFG_POINT_FLAG = "etbc_lfg_button"

local SINK_ICON_SIZE = 18
local SINK_ICON_SPACING = 4
local SINK_PADDING = 6
local SINK_MIN_WIDTH = 104
local SINK_MIN_HEIGHT = 32

local state = {
  styled = false,
  containerHooked = false,
  timeTextureHooked = false,
  questWatchHooked = false,
  trackingPointHooked = false,
  lfgPointHooked = false,
  toggleButtonShow = nil,
  eventFrame = nil,
  performanceFrame = nil,
  iconsFrame = nil,
  sinkFrame = nil,
  sinkDragHandle = nil,
  sinkManaged = {},
  msTicker = nil,
  fpsTicker = nil,
  friendsTicker = nil,
  guildTicker = nil,
  sinkScanTicker = nil,
  sinkEmptyNotified = false,
  minimapShapeOverridden = false,
  originalGetMinimapShape = nil,
}

local C = C_Container

local function IsAddonLoadedCompat(addonName)
  if type(addonName) ~= "string" or addonName == "" then return false end
  if C_AddOns and C_AddOns.IsAddOnLoaded then
    return not not C_AddOns.IsAddOnLoaded(addonName)
  end
  if IsAddOnLoaded then
    return not not IsAddOnLoaded(addonName)
  end
  return false
end

local function GetBagNumSlots(bag)
  if C and C.GetContainerNumSlots then
    return C.GetContainerNumSlots(bag) or 0
  end
  if GetContainerNumSlots then
    return GetContainerNumSlots(bag) or 0
  end
  return 0
end

local function GetBagNumFreeSlots(bag)
  if C and C.GetContainerNumFreeSlots then
    local free = C.GetContainerNumFreeSlots(bag)
    return tonumber(free) or 0
  end
  if GetContainerNumFreeSlots then
    local free = select(1, GetContainerNumFreeSlots(bag))
    return tonumber(free) or 0
  end
  return 0
end

local function RunSetPointGuard(lockKey, fn)
  if state[lockKey] then return end
  state[lockKey] = true
  local ok, err = pcall(fn)
  state[lockKey] = false
  if not ok and ETBC and ETBC.Debug then
    ETBC:Debug("MinimapPlus SetPoint hook error: " .. tostring(err))
  end
end

local function GetDB()
  ETBC.db.profile.minimapPlus = ETBC.db.profile.minimapPlus or {}
  local db = ETBC.db.profile.minimapPlus

  if db.enabled == nil then db.enabled = true end

  if db.minimap_icons == nil and db.minimapIcons ~= nil then db.minimap_icons = db.minimapIcons end
  if db.minimapIcons == nil and db.minimap_icons ~= nil then db.minimapIcons = db.minimap_icons end
  if db.minimap_icons == nil then db.minimap_icons = true end
  if db.minimapIcons == nil then db.minimapIcons = db.minimap_icons end

  if db.minimap_performance == nil and db.minimapPerformance ~= nil then
    db.minimap_performance = db.minimapPerformance
  end
  if db.minimapPerformance == nil and db.minimap_performance ~= nil then
    db.minimapPerformance = db.minimap_performance
  end
  if db.minimap_performance == nil then db.minimap_performance = false end
  if db.minimapPerformance == nil then db.minimapPerformance = db.minimap_performance end

  if db.square_mask == nil and db.squareMinimap ~= nil then db.square_mask = db.squareMinimap end
  if db.squareMinimap == nil and db.square_mask ~= nil then db.squareMinimap = db.square_mask end
  if db.square_mask == nil then db.square_mask = true end
  if db.squareMinimap == nil then db.squareMinimap = db.square_mask end

  if db.hideMinimapToggleButton == nil then db.hideMinimapToggleButton = true end

  if db.sink_addons == nil then
    if db.autoScan ~= nil then
      db.sink_addons = db.autoScan and true or false
    else
      db.sink_addons = true
    end
  end

  if db.sink_visible == nil and db.sinkEnabled ~= nil then db.sink_visible = db.sinkEnabled end
  if db.sinkEnabled == nil and db.sink_visible ~= nil then db.sinkEnabled = db.sink_visible end
  if db.sink_visible == nil then db.sink_visible = false end
  if db.sinkEnabled == nil then db.sinkEnabled = db.sink_visible end

  if db.sink_scan_interval == nil then
    if type(db.scanInterval) == "number" then
      db.sink_scan_interval = db.scanInterval
    else
      db.sink_scan_interval = 5
    end
  end
  db.scanInterval = db.sink_scan_interval

  db.sink_anchor = db.sink_anchor or {}
  if db.sink_anchor.point == nil and db.sinkPoint ~= nil then db.sink_anchor.point = db.sinkPoint end
  if db.sink_anchor.relPoint == nil and db.sinkRelPoint ~= nil then db.sink_anchor.relPoint = db.sinkRelPoint end
  if db.sink_anchor.x == nil and db.sinkX ~= nil then db.sink_anchor.x = db.sinkX end
  if db.sink_anchor.y == nil and db.sinkY ~= nil then db.sink_anchor.y = db.sinkY end

  if db.sink_moved == nil then
    db.sink_moved = (db.sink_anchor.x ~= nil or db.sink_anchor.y ~= nil)
  end

  if db.sink_anchor.point == nil then db.sink_anchor.point = "TOPRIGHT" end
  if db.sink_anchor.relPoint == nil then db.sink_anchor.relPoint = "TOPRIGHT" end
  if db.sink_anchor.x == nil then db.sink_anchor.x = -200 end
  if db.sink_anchor.y == nil then db.sink_anchor.y = -120 end

  db.sinkPoint = db.sink_anchor.point
  db.sinkRelPoint = db.sink_anchor.relPoint
  db.sinkX = db.sink_anchor.x
  db.sinkY = db.sink_anchor.y

  return db
end

local function IsFeatureEnabled()
  local db = GetDB()
  local generalEnabled = ETBC.db and ETBC.db.profile and ETBC.db.profile.general and ETBC.db.profile.general.enabled
  return (generalEnabled and db.enabled) and true or false
end

local function ApplyMinimapShapeOverride(enabled)
  if enabled then
    if not state.minimapShapeOverridden then
      state.originalGetMinimapShape = _G.GetMinimapShape
      _G.GetMinimapShape = function()
        return "SQUARE"
      end
      state.minimapShapeOverridden = true
    end
    if LDBIcon and LDBIcon.SetButtonRadius then
      LDBIcon:SetButtonRadius(0)
    end
    return
  end

  if state.minimapShapeOverridden then
    _G.GetMinimapShape = state.originalGetMinimapShape
    state.originalGetMinimapShape = nil
    state.minimapShapeOverridden = false
  end
end

local function ApplyFont(fs, size)
  if ETBC.Theme and ETBC.Theme.ApplyFontString then
    ETBC.Theme:ApplyFontString(fs, nil, size)
    return
  end
  if fs and fs.SetFont then
    local path = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    pcall(fs.SetFont, fs, path, size or 10, "OUTLINE")
  end
end

local function ApplyBackdrop(frame)
  if not frame or not frame.SetBackdrop then return end
  frame:SetBackdrop({
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame:SetBackdropBorderColor(0.04, 0.04, 0.04)
end

local function IconsEnabled()
  local db = GetDB()
  return db.enabled and db.minimap_icons
end

local function PerformanceEnabled()
  local db = GetDB()
  return db.enabled and db.minimap_performance
end

local function CancelTicker(t)
  if t and t.Cancel then t:Cancel() end
end

local function StopTickers()
  CancelTicker(state.msTicker)
  CancelTicker(state.fpsTicker)
  CancelTicker(state.friendsTicker)
  CancelTicker(state.guildTicker)
  CancelTicker(state.sinkScanTicker)
  state.msTicker = nil
  state.fpsTicker = nil
  state.friendsTicker = nil
  state.guildTicker = nil
  state.sinkScanTicker = nil
end

local function NewTicker(interval, fn)
  if ETBC and ETBC.StartRepeatingTimer then
    local t = ETBC:StartRepeatingTimer(interval, fn)
    if t then return t end
  end
  if C_Timer and C_Timer.NewTicker then
    return C_Timer.NewTicker(interval, fn)
  end
  return nil
end

local function AfterDelay(delay, fn)
  if ETBC and ETBC.StartTimer then
    local t = ETBC:StartTimer(delay, fn)
    if t then return t end
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(delay, fn)
    return true
  end
  fn()
  return true
end

local function StartTickers()
  StopTickers()
  local db = GetDB()
  if not db.enabled then return end

  if db.minimap_performance and state.performanceFrame then
    state.msTicker = NewTicker(30, function()
      if state.performanceFrame and state.performanceFrame.updateMsDisplay then
        state.performanceFrame:updateMsDisplay()
      end
    end)
    state.fpsTicker = NewTicker(1, function()
      if state.performanceFrame and state.performanceFrame.updateFpsDisplay then
        state.performanceFrame:updateFpsDisplay()
      end
    end)
  end

  if db.minimap_icons and state.iconsFrame then
    state.friendsTicker = NewTicker(5, function()
      if state.iconsFrame and state.iconsFrame.updateFriendsDisplay then
        state.iconsFrame:updateFriendsDisplay()
      end
    end)
    state.guildTicker = NewTicker(5, function()
      if state.iconsFrame and state.iconsFrame.updateGuildDisplay then
        state.iconsFrame:updateGuildDisplay()
      end
    end)
  end

  if db.sink_addons and state.sinkFrame then
    local interval = tonumber(db.sink_scan_interval) or 5
    if interval < 1 then interval = 1 end
    state.sinkScanTicker = NewTicker(interval, function()
      -- Periodic scans avoid global namespace iteration; full scans are event-driven.
      mod:ScanForAddonButtons(false)
    end)
  end
end

local function ApplySinkAnchor()
  if not state.sinkFrame then return end
  local db = GetDB()
  state.sinkFrame:ClearAllPoints()

  if db.sink_moved and type(db.sink_anchor) == "table" then
    state.sinkFrame:SetPoint(
      db.sink_anchor.point or "CENTER",
      UIParent,
      db.sink_anchor.relPoint or "CENTER",
      db.sink_anchor.x or 0,
      db.sink_anchor.y or 0
    )
  else
    state.sinkFrame:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMLEFT", -6, 0)
  end
end

local function SetManagedButtonsShown(shown)
  for btn in pairs(state.sinkManaged) do
    if btn then
      if shown then
        if btn.Show then btn:Show() end
      else
        if btn.Hide then btn:Hide() end
      end
    end
  end
end

local function EnsureEventFrame()
  if state.eventFrame then return end

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
    end
  end)
end

function mod:StyleMinimap()
  local db = GetDB()
  if not MinimapCluster or not MinimapCluster.MinimapContainer or not Minimap then return end

  local extraTop = db.minimap_icons and 20 or 0
  MinimapCluster:SetSize(MINIMAP_SIZE, 185 + extraTop)
  MinimapCluster.MinimapContainer:SetSize(MINIMAP_SIZE, MINIMAP_SIZE)
  Minimap:SetSize(MinimapCluster.MinimapContainer:GetSize())

  MinimapCluster.MinimapContainer:ClearAllPoints()
  MinimapCluster.MinimapContainer:SetPoint("BOTTOM", MinimapCluster, "BOTTOM", -1, 1.5, MINIMAP_CONTAINER_FLAG)

  if not state.containerHooked then
    hooksecurefunc(MinimapCluster.MinimapContainer, "SetPoint", function(frame, _, _, _, _, _, flag)
      if not IsFeatureEnabled() then return end
      if flag == MINIMAP_CONTAINER_FLAG then return end
      RunSetPointGuard("inContainerHook", function()
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOM", MinimapCluster, "BOTTOM", -1, 1.5, MINIMAP_CONTAINER_FLAG)
      end)
    end)
    state.containerHooked = true
  end

  local zoom = Minimap:GetZoom()
  Minimap:SetZoom(zoom == 0 and 1 or 0)
  Minimap:SetZoom(zoom)

  if not Minimap.backdrop then
    Minimap.backdrop = CreateFrame("Frame", nil, Minimap, "BackdropTemplate")
    Minimap.backdrop:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", -1, -1)
    Minimap.backdrop:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", 1, 1)
    ApplyBackdrop(Minimap.backdrop)
  end

  if MinimapBackdrop then
    MinimapBackdrop:SetSize(Minimap:GetSize())
    MinimapBackdrop:SetPoint("TOP", 0, 0)
  end
  if MinimapBorder then MinimapBorder:Hide() end
  if MinimapCluster.BorderTop then MinimapCluster.BorderTop:Hide() end

  if MinimapToggleButton then
    if db.hideMinimapToggleButton then
      if not state.toggleButtonShow then
        state.toggleButtonShow = MinimapToggleButton.Show
      end
      MinimapToggleButton:Hide()
      MinimapToggleButton.Show = function() end
    elseif state.toggleButtonShow then
      MinimapToggleButton.Show = state.toggleButtonShow
      MinimapToggleButton:Show()
    end
  end

  if MinimapZoneTextButton then
    MinimapZoneTextButton:SetSize(110, 20)
    MinimapZoneTextButton:ClearAllPoints()
    MinimapZoneTextButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, db.minimap_icons and 42 or 22)
  end

  if MinimapZoneText then
    MinimapZoneText:SetParent(Minimap)
    MinimapZoneText:SetWidth(110)
    MinimapZoneText:ClearAllPoints()
    MinimapZoneText:SetPoint("LEFT", MinimapZoneTextButton, "LEFT", 0, 0)
    MinimapZoneText:SetJustifyH("LEFT")
    ApplyFont(MinimapZoneText, 12)
  end

  if MinimapNorthTag then
    MinimapNorthTag:SetPoint("TOP", Minimap, "TOP", 0, -5)
  end

  if GameTimeFrame and GameTimeTexture then
    GameTimeFrame:SetSize(20, 20)
    GameTimeFrame:ClearAllPoints()
    GameTimeFrame:SetPoint("LEFT", MinimapZoneText, "RIGHT", 0, 0)
    GameTimeFrame:SetHitRectInsets(0, 0, 0, 0)
    GameTimeTexture:Hide()

    if not GameTimeFrame.texture then
      GameTimeFrame.texture = GameTimeFrame:CreateTexture(nil, "ARTWORK")
      GameTimeFrame.texture:SetSize(16, 16)
      GameTimeFrame.texture:SetPoint("CENTER", 0, 0)
      GameTimeFrame.texture:SetTexture(947347)
    end

    local minX = select(1, GameTimeTexture:GetTexCoord())
    if minX == 0 then
      GameTimeFrame.texture:SetTexCoord(0.26, 0.39, 0.65, 0.91)
    else
      GameTimeFrame.texture:SetTexCoord(0.44, 0.56, 0.64, 0.91)
    end

    if not state.timeTextureHooked then
      hooksecurefunc(GameTimeTexture, "SetTexCoord", function(_, texMinX)
        if not IsFeatureEnabled() then return end
        if not GameTimeFrame.texture then return end
        if texMinX == 0 then
          GameTimeFrame.texture:SetTexCoord(0.26, 0.39, 0.65, 0.91)
        else
          GameTimeFrame.texture:SetTexCoord(0.44, 0.56, 0.64, 0.91)
        end
      end)
      state.timeTextureHooked = true
    end
  end

  if MiniMapMailFrame then MiniMapMailFrame:SetPoint("TOPRIGHT", 0, -40) end
  if MinimapZoomIn then
    MinimapZoomIn:SetScale(0.7)
    MinimapZoomIn:SetPoint("BOTTOMRIGHT", -2, 67)
  end
  if MinimapZoomOut then
    MinimapZoomOut:SetScale(0.7)
    MinimapZoomOut:SetPoint("BOTTOMRIGHT", -2, 37)
  end
  if MiniMapTracking then
    MiniMapTracking:SetScale(0.8)
    MiniMapTracking:ClearAllPoints()
    MiniMapTracking:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 2, -45, TRACKING_POINT_FLAG)
    if not state.trackingPointHooked then
      hooksecurefunc(MiniMapTracking, "SetPoint", function(frame, _, _, _, _, _, flag)
        if flag == TRACKING_POINT_FLAG then return end
        RunSetPointGuard("inTrackingHook", function()
          frame:ClearAllPoints()
          frame:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 2, -45, TRACKING_POINT_FLAG)
        end)
      end)
      state.trackingPointHooked = true
    end
  end
  if MiniMapBattlefieldFrame then
    MiniMapBattlefieldFrame:SetScale(0.9)
    MiniMapBattlefieldFrame:ClearAllPoints()
    MiniMapBattlefieldFrame:SetPoint("BOTTOMLEFT", 2, 50)
  end

  self:CreatePerformanceFrame()
  self:CreateIconsFrame()
  self:EnsureSinkFrame()
  EnsureEventFrame()

  ApplyMinimapShapeOverride(db.square_mask and IsFeatureEnabled())

  state.styled = true
end

function mod.CreatePerformanceFrame()
  if state.performanceFrame or not Minimap then return end
  local frame = CreateFrame("Frame", "EnhanceTBC_MinimapPerformanceFrame", Minimap, "BackdropTemplate")
  frame:SetSize(Minimap:GetWidth(), 17)
  frame:SetPoint("BOTTOM", 0, 0)

  frame.ms_text = frame:CreateFontString(nil, "OVERLAY")
  frame.ms_text:SetSize(40, frame:GetHeight())
  frame.ms_text:SetPoint("LEFT", 90, 0)
  frame.ms_text:SetJustifyH("LEFT")
  frame.ms_text:SetJustifyV("MIDDLE")
  ApplyFont(frame.ms_text, 8)

  frame.fps_text = frame:CreateFontString(nil, "OVERLAY")
  frame.fps_text:SetSize(45, frame:GetHeight())
  frame.fps_text:SetPoint("LEFT", 126, 0)
  frame.fps_text:SetJustifyH("LEFT")
  frame.fps_text:SetJustifyV("MIDDLE")
  ApplyFont(frame.fps_text, 8)

  function frame:updateMsDisplay()
    if not PerformanceEnabled() then return end
    local _, _, _, latency = GetNetStats()
    if latency then
      if latency > 999 then latency = 999 end
      self.ms_text:SetText(latency .. "ms")
      if latency < 100 then
        self.ms_text:SetTextColor(0, 0.75, 0.2)
      elseif latency < 250 then
        self.ms_text:SetTextColor(1, 0.82, 0)
      else
        self.ms_text:SetTextColor(0.8, 0, 0)
      end
    end
  end

  function frame:updateFpsDisplay()
    if not PerformanceEnabled() then return end
    local framerate = GetFramerate()
    if framerate then
      self.fps_text:SetText(math.floor(framerate + 0.5) .. "fps")
    end
  end

  if not PerformanceEnabled() then frame:Hide() end
  state.performanceFrame = frame
end

function mod.CreateIconsFrame()
  if state.iconsFrame or not Minimap then return end

  local frame = CreateFrame("Frame", "EnhanceTBC_MinimapIconsFrame", Minimap, "BackdropTemplate")
  frame:SetSize(Minimap:GetWidth(), 22)
  frame:SetPoint("TOP", 0, 22)

  frame.friends_texture = CreateFrame("Frame", nil, frame)
  frame.friends_texture:SetSize(12.5, 12.5)
  frame.friends_texture:SetPoint("LEFT", 0, 0)
  frame.friends_texture.icon = frame.friends_texture:CreateTexture(nil, "OVERLAY")
  frame.friends_texture.icon:SetAllPoints(true)
  frame.friends_texture.icon:SetTexture("Interface\\FriendsFrame\\Battlenet-Battleneticon")
  frame.friends_texture.icon:SetTexCoord(0.2, 0.8, 0.2, 0.8)

  frame.friends_text = frame:CreateFontString(nil, "OVERLAY")
  frame.friends_text:SetSize(25, frame:GetHeight())
  frame.friends_text:SetPoint("LEFT", 14, 0)
  frame.friends_text:SetJustifyH("LEFT")
  frame.friends_text:SetJustifyV("MIDDLE")
  ApplyFont(frame.friends_text, 8.5)

  frame.guild_texture = CreateFrame("Frame", nil, frame)
  frame.guild_texture:SetSize(12.5, 12.5)
  frame.guild_texture:SetPoint("LEFT", 39, 0)
  frame.guild_texture.icon = frame.guild_texture:CreateTexture(nil, "OVERLAY")
  frame.guild_texture.icon:SetAllPoints(true)
  frame.guild_texture.icon:SetTexture("Interface\\Icons\\achievement_guildperk_everybodysfriend")
  frame.guild_texture.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

  frame.guild_text = frame:CreateFontString(nil, "OVERLAY")
  frame.guild_text:SetSize(25, frame:GetHeight())
  frame.guild_text:SetPoint("LEFT", 53, 0)
  frame.guild_text:SetJustifyH("LEFT")
  frame.guild_text:SetJustifyV("MIDDLE")
  ApplyFont(frame.guild_text, 8.5)

  frame.inventory_text = frame:CreateFontString(nil, "OVERLAY")
  frame.inventory_text:SetSize(50, frame:GetHeight())
  frame.inventory_text:SetPoint("RIGHT", 23, 0)
  frame.inventory_text:SetJustifyH("LEFT")
  frame.inventory_text:SetJustifyV("MIDDLE")
  ApplyFont(frame.inventory_text, 8.5)

  frame.inventory_text_texture = CreateFrame("Frame", nil, frame)
  frame.inventory_text_texture:SetSize(12.5, 12.5)
  frame.inventory_text_texture:SetPoint("RIGHT", -30, 0)
  frame.inventory_text_texture.icon = frame.inventory_text_texture:CreateTexture(nil, "OVERLAY")
  frame.inventory_text_texture.icon:SetAllPoints(true)
  frame.inventory_text_texture.icon:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
  frame.inventory_text_texture.icon:SetTexCoord(0.07, 0.94, 0.07, 0.94)

  frame.durability_text = frame:CreateFontString(nil, "OVERLAY")
  frame.durability_text:SetSize(40, frame:GetHeight())
  frame.durability_text:SetPoint("RIGHT", -33, 0)
  frame.durability_text:SetJustifyH("LEFT")
  frame.durability_text:SetJustifyV("MIDDLE")
  ApplyFont(frame.durability_text, 8.5)

  frame.durability_text_texture = CreateFrame("Frame", nil, frame)
  frame.durability_text_texture:SetSize(12.5, 12.5)
  frame.durability_text_texture:SetPoint("RIGHT", -75, 0)
  frame.durability_text_texture.icon = frame.durability_text_texture:CreateTexture(nil, "OVERLAY")
  frame.durability_text_texture.icon:SetAllPoints(true)
  frame.durability_text_texture.icon:SetTexture("Interface\\MerchantFrame\\UI-Merchant-RepairIcons")
  frame.durability_text_texture.icon:SetTexCoord(0.31, 0.54, 0.06, 0.52)

  local durabilitySlots = { 1, 3, 5, 6, 7, 8, 9, 10, 16, 17, 18 }

  function frame:updateFriendsDisplay()
    if not IconsEnabled() then return end
    local friends
    if BNGetNumFriends then
      friends = select(2, BNGetNumFriends())
    elseif GetNumFriends then
      friends = GetNumFriends()
    end
    if friends then self.friends_text:SetText(friends) else self.friends_text:SetText("--") end
  end

  function frame:updateGuildDisplay()
    if not IconsEnabled() then return end
    local guildTotal, guildOnline = GetNumGuildMembers()
    if guildTotal and guildTotal > 0 and guildOnline then
      self.guild_text:SetText(guildOnline)
    else
      self.guild_text:SetText("--")
    end
  end

  function frame:updateInventoryDisplay()
    if not IconsEnabled() then return end
    local emptySlots, totalSlots = 0, 0
    for i = 0, NUM_BAG_SLOTS do
      emptySlots = emptySlots + GetBagNumFreeSlots(i)
      totalSlots = totalSlots + GetBagNumSlots(i)
    end
    if totalSlots > 0 then
      self.inventory_text:SetText((totalSlots - emptySlots) .. "/" .. totalSlots)
    else
      self.inventory_text:SetText("0/0")
    end
  end

  function frame:updateDurabilityDisplay()
    if not IconsEnabled() then return end
    local totalDurability, equippedSlots = 0, 0
    for _, slot in pairs(durabilitySlots) do
      local cur, maxv = GetInventoryItemDurability(slot)
      if cur and maxv then
        if cur < maxv then
          totalDurability = totalDurability + math.floor(cur / maxv * 100 + 0.5)
        else
          totalDurability = totalDurability + 100
        end
        equippedSlots = equippedSlots + 1
      end
    end
    if equippedSlots > 0 then
      local durability = math.floor(totalDurability / equippedSlots + 0.5)
      self.durability_text:SetText(durability .. "%")
      if durability <= 25 then
        self.durability_text:SetTextColor(0.8, 0, 0)
      elseif durability <= 50 then
        self.durability_text:SetTextColor(1, 0.82, 0)
      else
        self.durability_text:SetTextColor(1, 1, 1)
      end
    else
      self.durability_text:SetText("100%")
      self.durability_text:SetTextColor(1, 1, 1)
    end
  end

  if not IconsEnabled() then frame:Hide() end
  state.iconsFrame = frame
end

function mod.EnsureSinkFrame()
  if state.sinkFrame then return end

  state.sinkFrame = CreateFrame("Frame", "EnhanceTBC_MinimapSinkFrame", UIParent, "BackdropTemplate")
  state.sinkFrame:SetSize(SINK_MIN_WIDTH, SINK_MIN_HEIGHT)
  state.sinkFrame:SetFrameStrata("LOW")
  state.sinkFrame:SetFrameLevel(1)
  state.sinkFrame:SetMovable(true)
  state.sinkFrame:EnableMouse(false)
  state.sinkFrame:SetClipsChildren(true)
  state.sinkFrame:SetClampedToScreen(true)

  if state.sinkFrame.SetBackdrop then
    state.sinkFrame:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
      tile = true,
      tileSize = 16,
      edgeSize = 12,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    state.sinkFrame:SetBackdropColor(0.03, 0.06, 0.03, 0.75)
    state.sinkFrame:SetBackdropBorderColor(0.2, 1.0, 0.2, 0.8)
  end

  state.sinkFrame.emptyText = state.sinkFrame:CreateFontString(nil, "OVERLAY")
  state.sinkFrame.emptyText:SetPoint("CENTER", state.sinkFrame, "CENTER", 0, 0)
  ApplyFont(state.sinkFrame.emptyText, 9)
  state.sinkFrame.emptyText:SetText("No addon minimap buttons")
  state.sinkFrame.emptyText:Hide()

  state.sinkDragHandle = CreateFrame("Button", "EnhanceTBC_MinimapSinkDragHandle", UIParent, "BackdropTemplate")
  state.sinkDragHandle:SetSize(14, 14)
  state.sinkDragHandle:SetPoint("BOTTOMRIGHT", state.sinkFrame, "BOTTOMRIGHT", 2, -2)
  state.sinkDragHandle:SetFrameStrata("DIALOG")
  state.sinkDragHandle:SetFrameLevel(500)
  state.sinkDragHandle:EnableMouse(true)
  state.sinkDragHandle:RegisterForDrag("LeftButton")
  if state.sinkDragHandle.SetBackdrop then
    state.sinkDragHandle:SetBackdrop({
      bgFile = "Interface/Buttons/WHITE8x8",
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
      tile = true,
      tileSize = 8,
      edgeSize = 10,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    state.sinkDragHandle:SetBackdropColor(0.10, 0.20, 0.10, 0.90)
    state.sinkDragHandle:SetBackdropBorderColor(0.20, 1.00, 0.20, 0.95)
  end
  state.sinkDragHandle:SetScript("OnDragStart", function()
    state.sinkFrame:StartMoving()
  end)
  state.sinkDragHandle:SetScript("OnDragStop", function()
    state.sinkFrame:StopMovingOrSizing()
    local db = GetDB()
    local cx, cy = state.sinkFrame:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if cx and cy and ux and uy then
      db.sink_anchor.point = "CENTER"
      db.sink_anchor.relPoint = "CENTER"
      db.sink_anchor.x = math.floor((cx - ux) + 0.5)
      db.sink_anchor.y = math.floor((cy - uy) + 0.5)
      db.sink_moved = true
      db.sinkPoint = db.sink_anchor.point
      db.sinkRelPoint = db.sink_anchor.relPoint
      db.sinkX = db.sink_anchor.x
      db.sinkY = db.sink_anchor.y
      ApplySinkAnchor()
    end
  end)

  ApplySinkAnchor()
end

function mod.IsBlacklisted(_self, btn, name)
  if not btn then return true end
  if type(name) == "string" and (
    name:find("^EnhanceTBC_")
    or name:find("^LibDBIcon10_EnhanceTBC")
  ) then
    return true
  end
  if LDBIcon and LDBIcon.GetMinimapButton then
    local etbcBtn = LDBIcon:GetMinimapButton("EnhanceTBC")
    if btn == etbcBtn then return true end
  end
  if btn == Minimap
    or btn == MinimapCluster
    or btn == state.iconsFrame
    or btn == state.performanceFrame
  then
    return true
  end
  if btn == state.sinkFrame then return true end
  if btn == MinimapZoneTextButton or btn == MinimapToggleButton then return true end
  if btn == MinimapZoomIn or btn == MinimapZoomOut then return true end
  if btn == MiniMapTracking or btn == MiniMapMailFrame or btn == MiniMapBattlefieldFrame then return true end
  if btn == MiniMapVoiceChatFrame or btn == MiniMapWorldMapButton or btn == LFGMinimapFrame then return true end

  local db = GetDB()
  if not db.includeCalendar then
    if btn == GameTimeFrame or btn == TimeManagerClockButton then return true end
  end
  if not db.includeQueue then
    if btn == QueueStatusMinimapButton then return true end
  end
  if not db.includeTracking then
    if btn == MiniMapTracking then return true end
  end
  if not db.includeMail then
    if btn == MiniMapMailFrame then return true end
  end
  if not db.includeDifficulty then
    if btn == MiniMapInstanceDifficulty then return true end
  end
  return false
end

function mod:LooksLikeMinimapButton(btn)
  if not btn then return false end
  local name = btn.GetName and btn:GetName() or nil
  if self:IsBlacklisted(btn, name) then return false end
  if btn.IsShown and not btn:IsShown() then return false end
  if btn.IsProtected and btn:IsProtected() and InCombatLockdown and InCombatLockdown() then
    return false
  end
  local objectType = btn.GetObjectType and btn:GetObjectType() or nil
  if objectType ~= "Button" and objectType ~= "CheckButton" then return false end
  if type(name) == "string" and name:find("^LibDBIcon10_") then return true end
  return false
end

function mod.CaptureSinkButton(_self, btn)
  if type(btn) == "table" and not btn.GetObjectType and btn.button then
    btn = btn.button
  end
  if not btn or state.sinkManaged[btn] then return end
  if InCombatLockdown and InCombatLockdown() then return end
  if type(btn.ClearAllPoints) ~= "function" then return end
  if type(btn.SetPoint) ~= "function" then return end

  local info = {
    parent = btn.GetParent and btn:GetParent() or UIParent,
    width = btn.GetWidth and btn:GetWidth() or nil,
    height = btn.GetHeight and btn:GetHeight() or nil,
    scale = btn.GetScale and btn:GetScale() or nil,
    points = {},
    strata = btn.GetFrameStrata and btn:GetFrameStrata() or nil,
    level = btn.GetFrameLevel and btn:GetFrameLevel() or nil,
  }

  if btn.GetNumPoints and btn.GetPoint then
    local n = btn:GetNumPoints() or 0
    for i = 1, n do
      local p, rel, rp, x, y = btn:GetPoint(i)
      info.points[#info.points + 1] = { p, rel, rp, x, y }
    end
  end

  state.sinkManaged[btn] = info
  btn:ClearAllPoints()
  if btn.SetParent and state.sinkFrame then
    btn:SetParent(state.sinkFrame)
    local scheduled = AfterDelay(0.2, function()
      if btn.SetParent and state.sinkFrame then
        btn:SetParent(state.sinkFrame)
        -- Only keep if parent is correct
        local repar = (btn.GetParent and btn:GetParent()) or nil
        if repar ~= state.sinkFrame then
          state.sinkManaged[btn] = nil
        end
      end
    end)
    if not scheduled then
      -- Fallback: check immediately
      local repar = (btn.GetParent and btn:GetParent()) or nil
      if repar ~= state.sinkFrame then
        state.sinkManaged[btn] = nil
      end
    end
  end
  if btn.SetFrameStrata then btn:SetFrameStrata("MEDIUM") end

  local baseW = tonumber(info.width) or 20
  local baseH = tonumber(info.height) or 20
  local base = math.max(baseW, baseH, 1)
  local targetScale = SINK_ICON_SIZE / base
  if targetScale > 1 then targetScale = 1 end
  if targetScale < 0.55 then targetScale = 0.55 end
  if btn.SetScale then btn:SetScale(targetScale) end
  if btn.SetSize then btn:SetSize(baseW, baseH) end
  if btn.SetHitRectInsets then btn:SetHitRectInsets(0, 0, 0, 0) end
end

function mod.RestoreSinkButtons()
  if InCombatLockdown and InCombatLockdown() then return end

  for btn, info in pairs(state.sinkManaged) do
    if btn and info then
      if btn.SetParent and info.parent then btn:SetParent(info.parent) end
      btn:ClearAllPoints()
      if info.points and #info.points > 0 and btn.SetPoint then
        for i = 1, #info.points do
          local p = info.points[i]
          btn:SetPoint(p[1], p[2], p[3], p[4], p[5])
        end
      end
      if btn.SetSize and info.width and info.height then btn:SetSize(info.width, info.height) end
      if btn.SetScale and info.scale then btn:SetScale(info.scale) end
      if btn.SetFrameStrata and info.strata then btn:SetFrameStrata(info.strata) end
      if btn.SetFrameLevel and info.level then btn:SetFrameLevel(info.level) end
      if btn.Show then btn:Show() end
    end
    state.sinkManaged[btn] = nil
  end
end

function mod.LayoutSinkButtons()
  if not state.sinkFrame then return end
  local buttons = {}
  for btn in pairs(state.sinkManaged) do
    if btn and type(btn.ClearAllPoints) == "function" and type(btn.SetPoint) == "function" then
      -- Only show if parent is still sinkFrame
      if btn.GetParent and btn:GetParent() == state.sinkFrame then
        buttons[#buttons + 1] = btn
      else
        state.sinkManaged[btn] = nil
      end
    else
      state.sinkManaged[btn] = nil
    end
  end

  table.sort(buttons, function(a, b)
    local na = (a and a.GetName and a:GetName()) or ""
    local nb = (b and b.GetName and b:GetName()) or ""
    return na < nb
  end)

  local count = #buttons
  local btnSize = SINK_ICON_SIZE + 6
  local spacing = SINK_ICON_SPACING
  local pad = SINK_PADDING
  local cols = 1
  if count > 1 then
    cols = math.min(count, math.max(4, math.ceil(math.sqrt(count))))
  end
  if cols < 1 then cols = 1 end

  local rows = math.max(1, math.ceil(count / cols))
  local contentWidth = (cols * btnSize) + ((cols - 1) * spacing)
  local contentHeight = (rows * btnSize) + ((rows - 1) * spacing)
  local width = (pad * 2) + contentWidth
  local height = (pad * 2) + contentHeight

  if count == 0 then
    width = 140
    height = SINK_MIN_HEIGHT
  end

  if width < SINK_MIN_WIDTH then width = SINK_MIN_WIDTH end
  if height < SINK_MIN_HEIGHT then height = SINK_MIN_HEIGHT end

  state.sinkFrame:SetSize(width, height)

  local startY = math.floor((height - contentHeight) / 2 + 0.5)
  for i = 1, count do
    local btn = buttons[i]
    local row = math.floor((i - 1) / cols)
    local indexInRow = (i - 1) % cols
    local rowCount = math.min(cols, count - (row * cols))
    local rowWidth = (rowCount * btnSize) + ((rowCount - 1) * spacing)
    local startX = math.floor((width - rowWidth) / 2 + 0.5)
    local x = startX + (indexInRow * (btnSize + spacing))
    local y = -startY - (row * (btnSize + spacing))
    if btn and btn.ClearAllPoints and btn.SetPoint then
      btn:ClearAllPoints()
      btn:SetPoint("TOPLEFT", state.sinkFrame, "TOPLEFT", x, y)
    end
  end

  if state.sinkFrame.emptyText then
    state.sinkFrame.emptyText:SetShown(count == 0)
    if count == 0 and not state.sinkEmptyNotified and DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage(
        "|cff33ff99EnhanceTBC|r No minimap buttons could be moved to the sink. "
          .. "Some buttons are protected by Blizzard or other addons and cannot be moved."
      )
      state.sinkEmptyNotified = true
    elseif count > 0 then
      state.sinkEmptyNotified = false
    end
  end
end

function mod:ScanForAddonButtons(fullScan)
  local db = GetDB()
  if not (db.enabled and db.sink_addons and state.sinkFrame) then return end
  if InCombatLockdown and InCombatLockdown() then return end

  -- Only keep LibDBIcon buttons managed by the sink.
  for btn, info in pairs(state.sinkManaged) do
    local name = btn and btn.GetName and btn:GetName() or nil
    if not (type(name) == "string" and name:find("^LibDBIcon10_")) then
      if btn and info then
        if btn.SetParent and info.parent then btn:SetParent(info.parent) end
        if btn.ClearAllPoints then btn:ClearAllPoints() end
        if info.points and btn.SetPoint then
          for i = 1, #info.points do
            local p = info.points[i]
            btn:SetPoint(p[1], p[2], p[3], p[4], p[5])
          end
        end
        if btn.SetSize and info.width and info.height then btn:SetSize(info.width, info.height) end
        if btn.SetScale and info.scale then btn:SetScale(info.scale) end
        if btn.SetFrameStrata and info.strata then btn:SetFrameStrata(info.strata) end
        if btn.SetFrameLevel and info.level then btn:SetFrameLevel(info.level) end
        if btn.Show then btn:Show() end
      end
      state.sinkManaged[btn] = nil
    end
  end

  local function TryCapture(candidate)
    if type(candidate) == "table" and not candidate.GetObjectType and candidate.button then
      candidate = candidate.button
    end
    if mod:LooksLikeMinimapButton(candidate) then
      mod:CaptureSinkButton(candidate)
      return true
    end
    return false
  end

  if LDBIcon and LDBIcon.objects and LDBIcon.GetMinimapButton then
    for ldbName in pairs(LDBIcon.objects) do
      local ok, btn = pcall(LDBIcon.GetMinimapButton, LDBIcon, ldbName)
      if ok and btn then
        TryCapture(btn)
      end
    end
  end

  if fullScan ~= false then
    for name, obj in pairs(_G) do
      if type(name) == "string" and name:find("^LibDBIcon10_") then
        TryCapture(obj)
      end
    end
  end

  self:LayoutSinkButtons()
end

function mod.ApplyWidgetVisibility()
  local db = GetDB()
  local enabled = IsFeatureEnabled()

  if state.performanceFrame then
    state.performanceFrame:SetShown(enabled and db.minimap_performance)
  end
  if state.iconsFrame then
    state.iconsFrame:SetShown(enabled and db.minimap_icons)
    state.iconsFrame:ClearAllPoints()
    state.iconsFrame:SetPoint("TOP", 0, 22)
  end
  if state.sinkFrame then
    state.sinkFrame:SetShown(enabled and db.sink_addons and db.sink_visible)
    if state.sinkDragHandle then
      state.sinkDragHandle:SetShown(enabled and db.sink_addons and db.sink_visible)
    end
    ApplySinkAnchor()
  end
end

function mod.StyleTimeManagerClockButton()
  if not IsAddonLoadedCompat("Blizzard_TimeManager") then return end
  if not IsFeatureEnabled() then return end

  if TimeManagerClockButton and MinimapZoneText then
    TimeManagerClockButton:SetSize(35, 20)
    TimeManagerClockButton:ClearAllPoints()
    TimeManagerClockButton:SetPoint("LEFT", MinimapZoneText, "RIGHT", 20, 0)

    local label = select(2, TimeManagerClockButton:GetRegions())
    if label and label.SetJustifyH then
      label:SetJustifyH("LEFT")
      ApplyFont(label, 12)
    end

    for i, region in pairs({ TimeManagerClockButton:GetRegions() }) do
      if i ~= 2 and region and region.Hide then
        region:Hide()
      end
    end

    if StopwatchFrame and StopwatchFrame.GetRegions then
      for _, region in pairs({ StopwatchFrame:GetRegions() }) do
        if region and region.SetVertexColor then
          region:SetVertexColor(0.2, 0.2, 0.2)
        end
      end
    end
  end

  if TimeManagerFrame then
    TimeManagerFrame:ClearAllPoints()
    TimeManagerFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -10, -215)
  end
end

function mod.MoveMinimapLFGButton()
  if not IsAddonLoadedCompat("Blizzard_GroupFinder_VanillaStyle") then return end
  if not LFGMinimapFrame then return end

  LFGMinimapFrame:SetScale(0.85)
  LFGMinimapFrame:ClearAllPoints()
  LFGMinimapFrame:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", 1.5, 85, LFG_POINT_FLAG)

  if not state.lfgPointHooked then
    hooksecurefunc(LFGMinimapFrame, "SetPoint", function(self, _, _, _, _, _, flag)
      if flag == LFG_POINT_FLAG then return end
      RunSetPointGuard("inLfgHook", function()
        self:ClearAllPoints()
        self:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", 1.5, 85, LFG_POINT_FLAG)
      end)
    end)
    state.lfgPointHooked = true
  end
end

function mod.StyleBattlefieldMinimap()
  if not IsAddonLoadedCompat("Blizzard_BattlefieldMap") then return end
  if not BattlefieldMapFrame then return end

  BattlefieldMapFrame:SetScale(0.84)

  if BattlefieldMapFrame.BorderFrame and BattlefieldMapFrame.BorderFrame.GetRegions then
    for _, region in pairs({ BattlefieldMapFrame.BorderFrame:GetRegions() }) do
      if region and region.SetVertexColor then
        region:SetVertexColor(0.2, 0.2, 0.2)
      end
    end
  end
end

function mod.MoveQuestWatchFrame()
  local frame = _G["UIParentRightManagedFrameContainer"]
  if not frame then return end

  frame:SetScale(0.9)
  if not state.questWatchHooked then
    hooksecurefunc(frame, "SetPoint", function(self, posA, anchor, posB, _, _, flag)
      if not IsFeatureEnabled() then return end
      if flag == RIGHT_MANAGED_FLAG then return end
      RunSetPointGuard("inRightManagedHook", function()
        self:ClearAllPoints()
        self:SetPoint(posA, anchor, posB, -90, -255, RIGHT_MANAGED_FLAG)
      end)
    end)
    state.questWatchHooked = true
  end
end

function mod.UpdateMinimapMask()
  if not Minimap or not Minimap.SetMaskTexture then return end
  local db = GetDB()
  if db.enabled and db.square_mask then
    Minimap:SetMaskTexture(SQUARE_MASK_TEXTURE)
  else
    Minimap:SetMaskTexture(ROUND_MASK_TEXTURE)
  end
end

function mod:Apply()
  local db = GetDB()
  local enabled = IsFeatureEnabled()

  if not enabled then
    ApplyMinimapShapeOverride(false)
    StopTickers()
    self:RestoreSinkButtons()
    self:ApplyWidgetVisibility()
    self:UpdateMinimapMask()

    if MinimapToggleButton and state.toggleButtonShow then
      MinimapToggleButton.Show = state.toggleButtonShow
      MinimapToggleButton:Show()
    end
    return
  end

  self:StyleMinimap()
  ApplyMinimapShapeOverride(db.square_mask)

  self:CreatePerformanceFrame()
  self:CreateIconsFrame()
  self:EnsureSinkFrame()
  EnsureEventFrame()

  if state.iconsFrame then
    state.iconsFrame:updateFriendsDisplay()
    state.iconsFrame:updateGuildDisplay()
    state.iconsFrame:updateDurabilityDisplay()
    state.iconsFrame:updateInventoryDisplay()
  end

  if db.sink_addons and db.sink_visible then
    self:ScanForAddonButtons(true)
    SetManagedButtonsShown(true)
  elseif db.sink_addons then
    SetManagedButtonsShown(false)
  else
    self:RestoreSinkButtons()
  end

  if state.performanceFrame then
    state.performanceFrame:updateMsDisplay()
    state.performanceFrame:updateFpsDisplay()
  end

  self:StyleTimeManagerClockButton()
  self:MoveMinimapLFGButton()
  self:MoveQuestWatchFrame()
  self:StyleBattlefieldMinimap()

  self:ApplyWidgetVisibility()
  self:UpdateMinimapMask()
  StartTickers()
end

function mod:ToggleSinkVisibility()
  local db = GetDB()
  if not db.sink_addons then db.sink_addons = true end

  db.sink_visible = not db.sink_visible
  db.sinkEnabled = db.sink_visible

  if db.sink_visible then
    self:ScanForAddonButtons(true)
    SetManagedButtonsShown(true)
  else
    SetManagedButtonsShown(false)
  end
  self:Apply()
end

function mod.IsSinkShown()
  if state.sinkFrame and state.sinkFrame.IsShown then
    return state.sinkFrame:IsShown()
  end
  return false
end

if ETBC.ApplyBus and ETBC.ApplyBus.Register then
  ETBC.ApplyBus:Register("minimapplus", function()
    mod:Apply()
  end)

  ETBC.ApplyBus:Register("general", function()
    mod:Apply()
  end)
end

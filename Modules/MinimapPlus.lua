-- Modules/MinimapPlus.lua
-- EnhanceTBC - Minimap styling and minimap info rows

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.MinimapPlus = mod

local MINIMAP_SIZE = 165
local ROUND_MASK_TEXTURE = "Textures\\MinimapMask"
local SQUARE_MASK_TEXTURE = "Interface\\ChatFrame\\ChatFrameBackground"

local state = {
  styled = false,
  containerHooked = false,
  timeTextureHooked = false,
  questWatchHooked = false,
  toggleButtonShow = nil,
  eventFrame = nil,
  performanceFrame = nil,
  iconsFrame = nil,
}

local function GetDB()
  ETBC.db.profile.minimapPlus = ETBC.db.profile.minimapPlus or {}
  local db = ETBC.db.profile.minimapPlus

  if db.enabled == nil then db.enabled = true end
  if db.minimapIcons == nil then db.minimapIcons = true end
  if db.minimapPerformance == nil then db.minimapPerformance = false end
  if db.hideMinimapToggleButton == nil then db.hideMinimapToggleButton = true end

  return db
end

local function IconsEnabled()
  local db = GetDB()
  return db.enabled and db.minimapIcons
end

local function PerformanceEnabled()
  local db = GetDB()
  return db.enabled and db.minimapPerformance
end

local function ApplyFont(fs, size)
  if ETBC.Theme and ETBC.Theme.ApplyFontString then
    ETBC.Theme:ApplyFontString(fs, nil, size)
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

local function EnsureEventFrame()
  if state.eventFrame then return end
  state.eventFrame = CreateFrame("Frame", "EnhanceTBC_MinimapEventFrame")
  state.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  state.eventFrame:RegisterEvent("BAG_UPDATE")
  state.eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
  state.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
  state.eventFrame:RegisterEvent("MERCHANT_CLOSED")
  state.eventFrame:SetScript("OnEvent", function(_, event, bag)
    if not IconsEnabled() then return end
    if not state.iconsFrame then return end

    if event == "PLAYER_ENTERING_WORLD" or (event == "BAG_UPDATE" and bag and bag <= NUM_BAG_SLOTS) then
      state.iconsFrame:updateInventoryDisplay()
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_EQUIPMENT_CHANGED"
      or event == "PLAYER_REGEN_ENABLED" or event == "MERCHANT_CLOSED" then
      state.iconsFrame:updateDurabilityDisplay()
    end
  end)
end

function mod.StyleMinimap(_)
  if state.styled then return end
  local db = GetDB()

  if not MinimapCluster or not MinimapCluster.MinimapContainer or not Minimap then return end

  MinimapCluster:SetSize(MINIMAP_SIZE, db.minimapIcons and 205 or 185)
  MinimapCluster.MinimapContainer:SetSize(MINIMAP_SIZE, MINIMAP_SIZE)
  Minimap:SetSize(MinimapCluster.MinimapContainer:GetSize())

  MinimapCluster.MinimapContainer:ClearAllPoints()
  MinimapCluster.MinimapContainer:SetPoint("BOTTOM", MinimapCluster, "BOTTOM", -1, 1.5)

  if not state.containerHooked then
    hooksecurefunc(MinimapCluster.MinimapContainer, "SetPoint", function(self, _, _, _, _, _, flag)
      if not GetDB().enabled then return end
      if flag ~= "minimap_container" then
        self:ClearAllPoints()
        self:SetPoint("BOTTOM", MinimapCluster, "BOTTOM", -1, 1.5, "minimap_container")
      end
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
    end
  end

  if MinimapZoneTextButton then
    MinimapZoneTextButton:SetSize(110, 20)
    MinimapZoneTextButton:ClearAllPoints()
    MinimapZoneTextButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, db.minimapIcons and 42 or 22)
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
        if not GetDB().enabled then return end
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

  if MiniMapMailFrame then
    MiniMapMailFrame:SetPoint("TOPRIGHT", 0, -40)
  end
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
    MiniMapTracking:SetPoint("TOPLEFT", 2, -45)
  end
  if MiniMapBattlefieldFrame then
    MiniMapBattlefieldFrame:SetScale(0.9)
    MiniMapBattlefieldFrame:ClearAllPoints()
    MiniMapBattlefieldFrame:SetPoint("BOTTOMLEFT", 2, 50)
  end

  self:CreatePerformanceFrame()
  self:CreateIconsFrame()
  EnsureEventFrame()

  -- LibDBIcon options for square minimap
  if not GetMinimapShape or GetMinimapShape() ~= "SQUARE" then
    GetMinimapShape = function()
      return "SQUARE"
    end
    if LibStub and LibStub("LibDBIcon-1.0", true) then
      LibStub("LibDBIcon-1.0"):SetButtonRadius(0)
    end
  end

  state.styled = true
end

function mod.CreatePerformanceFrame(_)
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

    if PerformanceEnabled() then
      C_Timer.After(30, function()
        if state.performanceFrame then
          state.performanceFrame:updateMsDisplay()
        end
      end)
    end
  end

  function frame:updateFpsDisplay()
    if not PerformanceEnabled() then return end
    local framerate = GetFramerate()

    if framerate then
      self.fps_text:SetText(math.floor(framerate + 0.5) .. "fps")
    end

    if PerformanceEnabled() then
      C_Timer.After(1, function()
        if state.performanceFrame then
          state.performanceFrame:updateFpsDisplay()
        end
      end)
    end
  end

  if not PerformanceEnabled() then
    frame:Hide()
  end

  state.performanceFrame = frame
end

function mod.CreateIconsFrame(_)
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
  frame.friends_texture:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetText("Friends Online")
  end)
  frame.friends_texture:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

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
  frame.guild_texture:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetText("Guild Online")
  end)
  frame.guild_texture:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

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
  frame.inventory_text_texture:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:SetText("Bag Space")
  end)
  frame.inventory_text_texture:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

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
  frame.durability_text_texture:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:SetText("Durability")
  end)
  frame.durability_text_texture:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  local durability_item_slots = { 1, 3, 5, 6, 7, 8, 9, 10, 16, 17, 18 }

  function frame:updateFriendsDisplay()
    if not IconsEnabled() then return end

    local friends
    if BNGetNumFriends then
      friends = select(2, BNGetNumFriends())
    elseif GetNumFriends then
      friends = GetNumFriends()
    end

    if friends then
      self.friends_text:SetText(friends)
    else
      self.friends_text:SetText("--")
    end

    if IconsEnabled() then
      C_Timer.After(5, function()
        if state.iconsFrame then
          state.iconsFrame:updateFriendsDisplay()
        end
      end)
    end
  end

  function frame:updateGuildDisplay()
    if not IconsEnabled() then return end

    local guild_total, guild_online = GetNumGuildMembers()

    if guild_total and guild_total > 0 and guild_online then
      self.guild_text:SetText(guild_online)
    else
      self.guild_text:SetText("--")
    end

    if IconsEnabled() then
      C_Timer.After(5, function()
        if state.iconsFrame then
          state.iconsFrame:updateGuildDisplay()
        end
      end)
    end
  end

  function frame:updateInventoryDisplay()
    if not IconsEnabled() then return end

    local empty_slots = 0
    local total_slots = 0

    if C_Container and C_Container.GetContainerNumFreeSlots then
      for i = 0, NUM_BAG_SLOTS do
        empty_slots = empty_slots + C_Container.GetContainerNumFreeSlots(i)
        total_slots = total_slots + C_Container.GetContainerNumSlots(i)
      end
    else
      for i = 0, NUM_BAG_SLOTS do
        local free, _ = GetContainerNumFreeSlots(i)
        empty_slots = empty_slots + (free or 0)
        total_slots = total_slots + (GetContainerNumSlots(i) or 0)
      end
    end

    if total_slots > 0 then
      self.inventory_text:SetText((total_slots - empty_slots) .. "/" .. total_slots)
    else
      self.inventory_text:SetText("0/0")
    end
  end

  function frame:updateDurabilityDisplay()
    if not IconsEnabled() then return end

    local total_durability = 0
    local equipped_durability_slots = 0

    for _, slot in pairs(durability_item_slots) do
      local item_current_durability, item_maximum_durability = GetInventoryItemDurability(slot)

      if item_current_durability and item_maximum_durability then
        if item_current_durability < item_maximum_durability then
          total_durability = total_durability + math.floor(
            item_current_durability / item_maximum_durability * 100 + 0.5
          )
        else
          total_durability = total_durability + 100
        end

        equipped_durability_slots = equipped_durability_slots + 1
      end
    end

    if equipped_durability_slots > 0 then
      local durability = math.floor(total_durability / equipped_durability_slots + 0.5)
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

  if not IconsEnabled() then
    frame:Hide()
  end

  state.iconsFrame = frame
end

function mod.StyleTimeManagerClockButton(_)
  if not C_AddOns or not C_AddOns.IsAddOnLoaded then return end
  if not C_AddOns.IsAddOnLoaded("Blizzard_TimeManager") then return end
  if not GetDB().enabled then return end

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

function mod.MoveMinimapLFGButton(_)
  if not C_AddOns or not C_AddOns.IsAddOnLoaded then return end
  if not C_AddOns.IsAddOnLoaded("Blizzard_GroupFinder_VanillaStyle") then return end
  if not LFGMinimapFrame then return end

  LFGMinimapFrame:SetScale(0.85)
  LFGMinimapFrame:ClearAllPoints()
  LFGMinimapFrame:SetPoint("BOTTOMLEFT", 1.5, 85)
end

function mod.StyleBattlefieldMinimap(_)
  if not C_AddOns or not C_AddOns.IsAddOnLoaded then return end
  if not C_AddOns.IsAddOnLoaded("Blizzard_BattlefieldMap") then return end
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

function mod.MoveQuestWatchFrame(_)
  local frame = _G["UIParentRightManagedFrameContainer"]
  if not frame then return end

  frame:SetScale(0.9)
  if not state.questWatchHooked then
    hooksecurefunc(frame, "SetPoint", function(self, pos_a, anchor, pos_b, _, _, flag)
      if not GetDB().enabled then return end
      if flag ~= "ui_parent_right_managed_frame" then
        self:ClearAllPoints()
        self:SetPoint(pos_a, anchor, pos_b, -90, -255, "ui_parent_right_managed_frame")
      end
    end)
    state.questWatchHooked = true
  end
end

function mod.UpdateMinimapIcons(_)
  local db = GetDB()

  if MinimapCluster then
    MinimapCluster:SetSize(MINIMAP_SIZE, db.minimapIcons and 205 or 185)
  end

  if MinimapZoneTextButton and Minimap then
    MinimapZoneTextButton:ClearAllPoints()
    MinimapZoneTextButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, db.minimapIcons and 42 or 22)
  end

  if state.iconsFrame then
    if db.minimapIcons then
      state.iconsFrame:Show()
      state.iconsFrame:updateFriendsDisplay()
      state.iconsFrame:updateGuildDisplay()
      state.iconsFrame:updateDurabilityDisplay()
      state.iconsFrame:updateInventoryDisplay()
    else
      state.iconsFrame:Hide()
    end
  end
end

function mod.UpdateMinimapPerformance(_)
  if not state.performanceFrame then return end

  if PerformanceEnabled() then
    state.performanceFrame:Show()
    state.performanceFrame:updateMsDisplay()
    state.performanceFrame:updateFpsDisplay()
  else
    state.performanceFrame:Hide()
  end
end

function mod.UpdateMinimapMask(_)
  if not Minimap or not Minimap.SetMaskTexture then return end
  local db = GetDB()
  if db.enabled then
    Minimap:SetMaskTexture(SQUARE_MASK_TEXTURE)
  else
    Minimap:SetMaskTexture(ROUND_MASK_TEXTURE)
  end
end

function mod:Enable()
  local db = GetDB()
  if not db.enabled then return end

  self:StyleMinimap()
  self:StyleTimeManagerClockButton()
  self:MoveMinimapLFGButton()
  self:MoveQuestWatchFrame()
  self:StyleBattlefieldMinimap()
  self:UpdateMinimapIcons()
  self:UpdateMinimapPerformance()
  self:UpdateMinimapMask()
end

function mod:Disable()
  self:UpdateMinimapMask()
  if state.performanceFrame then state.performanceFrame:Hide() end
  if state.iconsFrame then state.iconsFrame:Hide() end

  if MinimapToggleButton and state.toggleButtonShow then
    MinimapToggleButton.Show = state.toggleButtonShow
    MinimapToggleButton:Show()
  end
end

function mod:Apply()
  local db = GetDB()
  if not ETBC.db or not ETBC.db.profile or not ETBC.db.profile.general or not ETBC.db.profile.general.enabled then
    self:Disable()
    return
  end

  if db.enabled then
    self:Enable()
  else
    self:Disable()
  end
end

if ETBC.ApplyBus and ETBC.ApplyBus.Register then
  ETBC.ApplyBus:Register("minimapplus", function()
    mod:Apply()
  end)

  ETBC.ApplyBus:Register("general", function()
    mod:Apply()
  end)
end

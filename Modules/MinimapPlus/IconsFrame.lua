-- Modules/MinimapPlus/IconsFrame.lua
-- EnhanceTBC - MinimapPlus icon row construction (internal).

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}

local mod = ETBC.Modules.MinimapPlus
if not mod then return end

mod.Internal = mod.Internal or {}
local H = {}
mod.Internal.IconsFrame = H

local function GetShared()
  return mod.Internal and mod.Internal.Shared
end

local function GetState()
  local shared = GetShared()
  return shared and shared.state
end

local function CallApplyFont(fs, size)
  local shared = GetShared()
  if shared and type(shared.ApplyFont) == "function" then
    shared.ApplyFont(fs, size)
  end
end

local function CallGetDB()
  local shared = GetShared()
  if shared and type(shared.GetDB) == "function" then
    return shared.GetDB()
  end
  return nil
end

local function IconsEnabled()
  local shared = GetShared()
  if shared and type(shared.IconsEnabled) == "function" then
    return shared.IconsEnabled()
  end
  return false
end

local function GetBagNumSlotsCompat(bag)
  local shared = GetShared()
  if shared and type(shared.GetBagNumSlots) == "function" then
    return shared.GetBagNumSlots(bag)
  end
  return 0
end

local function GetBagNumFreeSlotsCompat(bag)
  local shared = GetShared()
  if shared and type(shared.GetBagNumFreeSlots) == "function" then
    return shared.GetBagNumFreeSlots(bag)
  end
  return 0
end

local function GetTrackingSnapshot()
  local shared = GetShared()
  if shared and type(shared.GetTrackingSnapshot) == "function" then
    return shared.GetTrackingSnapshot()
  end
  return {
    activeCount = 0,
    names = {},
    texture = (shared and shared.TRACKING_NONE_TEXTURE) or "Interface\\Minimap\\Tracking\\None",
  }
end

local function GetTrackingWidgetCallback(name)
  local shared = GetShared()
  if not shared then return nil end
  local fn = shared[name]
  if type(fn) == "function" then
    return fn
  end
  return nil
end

local function GetTrackingNoneTexture()
  local shared = GetShared()
  if shared and type(shared.TRACKING_NONE_TEXTURE) == "string" and shared.TRACKING_NONE_TEXTURE ~= "" then
    return shared.TRACKING_NONE_TEXTURE
  end
  return "Interface\\Minimap\\Tracking\\None"
end

local function CreateIconsFrame()
  local state = GetState()
  if not state then return end
  if state.iconsFrame or not Minimap then return end

  local trackingNoneTexture = GetTrackingNoneTexture()
  local onEnter = GetTrackingWidgetCallback("TrackingWidget_OnEnter")
  local onLeave = GetTrackingWidgetCallback("TrackingWidget_OnLeave")
  local onClick = GetTrackingWidgetCallback("TrackingWidget_OnClick")

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
  CallApplyFont(frame.friends_text, 8.5)

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
  CallApplyFont(frame.guild_text, 8.5)

  frame.tracking_button = CreateFrame("Button", nil, frame)
  frame.tracking_button:SetSize(14, 14)
  frame.tracking_button:SetPoint("LEFT", 78, 0)
  frame.tracking_button:RegisterForClicks("LeftButtonUp")
  frame.tracking_button:SetScript("OnEnter", onEnter)
  frame.tracking_button:SetScript("OnLeave", onLeave)
  frame.tracking_button:SetScript("OnClick", onClick)

  frame.tracking_icon = frame.tracking_button:CreateTexture(nil, "OVERLAY")
  frame.tracking_icon:SetSize(12.5, 12.5)
  frame.tracking_icon:SetPoint("CENTER")
  frame.tracking_icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
  frame.tracking_icon:SetTexture(trackingNoneTexture)
  frame.tracking_button:Hide()

  frame.inventory_text = frame:CreateFontString(nil, "OVERLAY")
  frame.inventory_text:SetSize(50, frame:GetHeight())
  frame.inventory_text:SetPoint("RIGHT", 23, 0)
  frame.inventory_text:SetJustifyH("LEFT")
  frame.inventory_text:SetJustifyV("MIDDLE")
  CallApplyFont(frame.inventory_text, 8.5)

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
  CallApplyFont(frame.durability_text, 8.5)

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

  function frame:updateTrackingDisplay()
    if not IconsEnabled() then return end
    local db = CallGetDB()
    if not db then return end
    local show = db.showTrackingState and true or false
    self.tracking_button:SetShown(show)
    if not show then return end

    local snapshot = GetTrackingSnapshot()
    self.tracking_icon:SetTexture(snapshot.texture or trackingNoneTexture)
    if self.tracking_icon.SetDesaturated then
      self.tracking_icon:SetDesaturated(snapshot.activeCount == 0)
    end
    self.tracking_icon:SetAlpha(snapshot.activeCount > 0 and 1 or 0.5)
  end

  function frame:updateInventoryDisplay()
    if not IconsEnabled() then return end
    local emptySlots, totalSlots = 0, 0
    for i = 0, NUM_BAG_SLOTS do
      emptySlots = emptySlots + GetBagNumFreeSlotsCompat(i)
      totalSlots = totalSlots + GetBagNumSlotsCompat(i)
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

H.CreateIconsFrame = CreateIconsFrame

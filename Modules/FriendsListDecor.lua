-- Modules/FriendsListDecor.lua
-- EnhanceTBC - Friends list decorator with EnhanceQoL styling
-- Shows area and realm, class colors, level colors, and faction icons

local _, ETBC = ...

ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.FriendsListDecor = mod

local hooked = false

-- ---------------------------------------------------------
-- DB
-- ---------------------------------------------------------
local function GetDB()
  ETBC.db.profile.friends = ETBC.db.profile.friends or {}
  local db = ETBC.db.profile.friends

  if db.enabled == nil then db.enabled = true end
  if db.showLocation == nil then db.showLocation = true end
  if db.hideOwnRealm == nil then db.hideOwnRealm = true end
  if db.nameFontSize == nil then db.nameFontSize = 0 end

  return db
end

-- ---------------------------------------------------------
-- Utility functions
-- ---------------------------------------------------------
local tUnpack = unpack
local select = select
local strsplit = strsplit
local format = string.format
local ipairs = ipairs
local floor = math.floor
local max = math.max
local min = math.min
local UnitFullName = UnitFullName
local GetRealmName = GetRealmName
local GetQuestDifficultyColor = GetQuestDifficultyColor

local NAME_FONT_MIN = 8
local NAME_FONT_MAX = 24

local function GetNameFontSize()
  local db = GetDB()
  local value = tonumber(db.nameFontSize)
  if not value or value <= 0 then return 0 end
  value = floor(value + 0.5)
  if value < NAME_FONT_MIN then value = NAME_FONT_MIN end
  if value > NAME_FONT_MAX then value = NAME_FONT_MAX end
  return value
end

local function EnsureOriginalNameFont(button)
  local fontString = button and button.name
  if not fontString then return nil end
  if not fontString._etbcOriginalFont then
    local font, size, flags = fontString:GetFont()
    fontString._etbcOriginalFont = { font, size, flags }
  end
  return fontString._etbcOriginalFont
end

local function RestoreNameFont(button)
  local fontString = button and button.name
  if not fontString or not fontString._etbcOriginalFont then return end
  local font, size, flags = tUnpack(fontString._etbcOriginalFont)
  if font then fontString:SetFont(font, size, flags) end
end

local function ResolveNameFontPath(fallback)
  if ETBC.Theme and ETBC.Theme.FetchFont then
    local themed = ETBC.Theme:FetchFont()
    if themed and themed ~= "" then
      return themed
    end
  end
  return fallback
end

local function ApplyNameFontOverride(button)
  local fontString = button and button.name
  if not fontString then return end
  local original = EnsureOriginalNameFont(button)
  if not original then return end

  local desired = GetNameFontSize()
  local font, baselineSize, flags = tUnpack(original)
  local resolvedFont = ResolveNameFontPath(font)

  if desired > 0 and resolvedFont then
    fontString:SetFont(resolvedFont, desired, flags)
  elseif resolvedFont then
    fontString:SetFont(resolvedFont, baselineSize, flags)
  end
end

-- ---------------------------------------------------------
-- Realm and location handling
-- ---------------------------------------------------------
local function CleanRealmName(realm)
  if type(realm) ~= "string" then return nil end
  local cleaned = realm:gsub("%(%*%)", "")
  cleaned = cleaned:gsub("%*$", "")
  cleaned = cleaned:gsub("^%s+", "")
  cleaned = cleaned:gsub("%s+$", "")
  if cleaned == "" then return nil end
  return cleaned
end

local function NormalizeRealmWithoutSpecials(realm)
  if type(realm) ~= "string" then return nil end
  local normalized = realm:gsub("[%s%-']", ""):lower()
  if normalized == "" then return nil end
  return normalized
end

local playerRealmNormalized do
  local playerRealm = GetRealmName and GetRealmName()
  if (not playerRealm or playerRealm == "") and UnitFullName then
    playerRealm = select(2, UnitFullName("player"))
  end
  if playerRealm and playerRealm ~= "" then
    local cleaned = CleanRealmName(playerRealm)
    playerRealmNormalized = cleaned and NormalizeRealmWithoutSpecials(cleaned) or nil
  end
end

local function GetRealmDisplayText(realm)
  local db = GetDB()
  local cleaned = CleanRealmName(realm)
  if not cleaned then return nil end

  local normalized = NormalizeRealmWithoutSpecials(cleaned)
  if normalized and playerRealmNormalized and normalized == playerRealmNormalized and db.hideOwnRealm then
    return nil
  end

  return cleaned
end

local function BuildLocationText(areaText, realmText)
  local db = GetDB()
  if not db.showLocation then return nil end

  local area = (type(areaText) == "string" and areaText ~= "") and areaText or nil
  local realm = GetRealmDisplayText(realmText)

  if area and realm then return ("%s - %s"):format(area, realm) end
  return area or realm or nil
end

-- ---------------------------------------------------------
-- Class colors and formatting
-- ---------------------------------------------------------
local function RGBToHex(r, g, b)
  if not r or not g or not b then return nil end
  return format(
    "%02x%02x%02x",
    min(255, floor(r * 255 + 0.5)),
    min(255, floor(g * 255 + 0.5)),
    min(255, floor(b * 255 + 0.5))
  )
end

local function WrapColor(text, r, g, b)
  if not text or text == "" then return text end
  local hex = RGBToHex(r, g, b)
  if not hex then return text end
  return ("|cff%s%s|r"):format(hex, text)
end

local function FormatLevel(level)
  if not level or level <= 0 then return nil end
  if not GetQuestDifficultyColor then return tostring(level) end
  local color = GetQuestDifficultyColor(level)
  if not color then return tostring(level) end
  return WrapColor(tostring(level), color.r, color.g, color.b)
end

local function GetClassColorFromToken(token)
  if not token or token == "" then return nil end
  local colorObj = C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(token)
  if colorObj and colorObj.r and colorObj.g and colorObj.b then
    return colorObj.r, colorObj.g, colorObj.b
  end
  if CUSTOM_CLASS_COLORS then
    local custom = CUSTOM_CLASS_COLORS[token]
    if custom and custom.r and custom.g and custom.b then
      return custom.r, custom.g, custom.b
    end
  end
  if RAID_CLASS_COLORS then
    local color = RAID_CLASS_COLORS[token]
    if color and color.r and color.g and color.b then
      return color.r, color.g, color.b
    end
  end
  return nil
end

local localizedClassMap = {}
if LOCALIZED_CLASS_NAMES_MALE then
  for token, name in pairs(LOCALIZED_CLASS_NAMES_MALE) do
    if type(name) == "string" and name ~= "" then
      localizedClassMap[name] = token
    end
  end
end
if LOCALIZED_CLASS_NAMES_FEMALE then
  for token, name in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
    if type(name) == "string" and name ~= "" and not localizedClassMap[name] then
      localizedClassMap[name] = token
    end
  end
end

local function ResolveClassToken(classToken, classID, localizedName)
  if type(classToken) == "string" and classToken ~= "" then
    local token = classToken
    if localizedClassMap[token] then token = localizedClassMap[token] end
    token = token:upper()
    local r = GetClassColorFromToken(token)
    if r then return token end
  end

  if classID and C_CreatureInfo and C_CreatureInfo.GetClassInfo then
    local info = C_CreatureInfo.GetClassInfo(classID)
    if info and info.classFile and GetClassColorFromToken(info.classFile) then
      return info.classFile
    end
  end

  if type(localizedName) == "string" then
    local token = localizedClassMap[localizedName]
    if token and GetClassColorFromToken(token) then return token end
  end

  return nil
end

local function GetClassColor(classToken, classID, localizedName)
  local token = ResolveClassToken(classToken, classID, localizedName)
  if not token then return nil end
  return GetClassColorFromToken(token)
end

-- ---------------------------------------------------------
-- Status and Faction icons
-- ---------------------------------------------------------
local STATUS_TEXTURES = {
  Online = FRIENDS_TEXTURE_ONLINE,
  Offline = FRIENDS_TEXTURE_OFFLINE,
  AFK = FRIENDS_TEXTURE_AFK,
  DND = FRIENDS_TEXTURE_DND,
}

local function SetStatusIcon(button, status)
  if not button or not button.status or not status then return end
  local texture = STATUS_TEXTURES[status]
  if texture then
    button.status:SetTexture(texture)
    button.status:Show()
  end
end

local factionLookup = {}
local function RegisterFactionKeys(faction, ...)
  for i = 1, select("#", ...) do
    local value = select(i, ...)
    if type(value) == "string" and value ~= "" then
      factionLookup[value:lower()] = faction
    end
  end
end
RegisterFactionKeys("Alliance", "Alliance", ALLIANCE, FACTION_ALLIANCE,
  PLAYER_FACTION_GROUP and PLAYER_FACTION_GROUP[1])
RegisterFactionKeys("Horde", "Horde", HORDE, FACTION_HORDE,
  PLAYER_FACTION_GROUP and PLAYER_FACTION_GROUP[0])

local function NormalizeFactionName(name)
  if type(name) ~= "string" then return nil end
  return factionLookup[name:lower()]
end

local FACTION_ASSETS = {
  Alliance = {
    atlas = "FactionIcon-Alliance",
    textures = {
      "Interface\\FriendsFrame\\PlusManz-Alliance",
      "Interface\\PVPFrame\\PVP-Currency-Alliance",
      "Interface\\Icons\\Achievement_PVP_A_00",
    },
  },
  Horde = {
    atlas = "FactionIcon-Horde",
    textures = {
      "Interface\\FriendsFrame\\PlusManz-Horde",
      "Interface\\PVPFrame\\PVP-Currency-Horde",
      "Interface\\Icons\\Achievement_PVP_H_00",
    },
  },
}

local function SetFactionIcon(button, factionName)
  if not button then return end
  local texture = button._etbcFactionIcon

  if factionName == nil then
    if texture then
      texture:SetTexture(nil)
      texture:Hide()
    end
    return
  end

  if not texture then
    texture = button:CreateTexture(nil, "OVERLAY", nil, 1)
    texture:SetSize(16, 16)
    if button.name and button.name.GetObjectType and button.name:GetObjectType() == "FontString" then
      texture:SetPoint("LEFT", button.name, "RIGHT", 4, 0)
    else
      texture:SetPoint("LEFT", button, "LEFT", 200, 0)
    end
    button._etbcFactionIcon = texture
  end

  local faction = NormalizeFactionName(factionName)
  local asset = faction and FACTION_ASSETS[faction] or nil

  if asset then
    local applied = false
    if asset.atlas and texture.SetAtlas then
      local ok = pcall(texture.SetAtlas, texture, asset.atlas)
      if ok then
        texture:SetTexCoord(0, 1, 0, 1)
        texture:Show()
        applied = true
      end
    end
    if not applied and asset.textures then
      for _, texturePath in ipairs(asset.textures) do
        if type(texturePath) == "string" and texturePath ~= "" then
          texture:SetTexCoord(0, 1, 0, 1)
          texture:SetTexture(texturePath)
          if texture:GetTexture() then
            texture:Show()
            applied = true
            break
          end
        end
      end
    end
    if not applied then
      texture:SetTexture(nil)
      texture:Hide()
    end
  else
    texture:SetTexture(nil)
    texture:Hide()
  end
end

local CLIENT_COLORS = {
  [BNET_CLIENT_WOW] = { r = 0.866, g = 0.69, b = 0.18 },
  APP = { r = 0.509, g = 0.772, b = 1 },
  WTCG = { r = 1, g = 0.694, b = 0 },
  Hero = { r = 0, g = 0.8, b = 1 },
  D3 = { r = 0.768, g = 0.121, b = 0.231 },
}

local function ColorClientText(text, clientProgram)
  if not text or text == "" then return text end
  local color = CLIENT_COLORS[clientProgram] or
    CLIENT_COLORS[clientProgram and clientProgram:upper()]
  if color then return WrapColor(text, color.r, color.g, color.b) end
  return text
end

-- ---------------------------------------------------------
-- Favorite star positioning
-- ---------------------------------------------------------
local function GetFavoriteIcon(button)
  if not button then return nil end
  return button.Favorite or button.favorite or nil
end

local function SetPointCompat(frame, ...)
  if not frame then return end
  if frame.Point then
    frame:Point(...)
  else
    frame:SetPoint(...)
  end
end

local function CacheFavoriteAnchor(favorite)
  if not favorite or favorite._etbcOriginalPoints or not favorite.GetNumPoints then return end
  local points = {}
  for i = 1, favorite:GetNumPoints() do
    local point, relTo, relPoint, x, y = favorite:GetPoint(i)
    points[#points + 1] = { point = point, relTo = relTo, relPoint = relPoint, x = x, y = y }
  end
  favorite._etbcOriginalPoints = points
end

local function RestoreFavoriteAnchor(button)
  local favorite = GetFavoriteIcon(button)
  if not favorite or not favorite._etbcOriginalPoints then return end
  favorite:ClearAllPoints()
  for _, data in ipairs(favorite._etbcOriginalPoints) do
    SetPointCompat(favorite, data.point, data.relTo, data.relPoint, data.x, data.y)
  end
end

local function AdjustFavoriteAnchorNow(button)
  local favorite = GetFavoriteIcon(button)
  if not favorite or not favorite.IsShown or not favorite:IsShown() then return end
  local nameFont = button and button.name
  if not nameFont or not nameFont.GetStringWidth then return end

  CacheFavoriteAnchor(favorite)

  local width = nameFont:GetStringWidth() or 0
  local offset = width + 6

  if button.gameIcon and button.gameIcon.GetLeft and nameFont.GetLeft then
    local iconLeft = button.gameIcon:GetLeft()
    local nameLeft = nameFont:GetLeft()
    local starWidth = (favorite.GetWidth and favorite:GetWidth()) or 0
    if iconLeft and nameLeft and starWidth then
      local maxOffset = (iconLeft - nameLeft) - starWidth - 4
      if maxOffset then
        offset = min(offset, max(0, maxOffset))
      end
    end
  end

  favorite:ClearAllPoints()
  SetPointCompat(favorite, "LEFT", nameFont, "LEFT", offset, 0)
end

local function AdjustFavoriteAnchor(button)
  if not button then return end
  if not C_Timer or not C_Timer.After then
    AdjustFavoriteAnchorNow(button)
    return
  end
  if button._etbcFavoriteAdjustPending then return end
  button._etbcFavoriteAdjustPending = true
  C_Timer.After(0, function()
    button._etbcFavoriteAdjustPending = nil
    AdjustFavoriteAnchorNow(button)
  end)
end

-- ---------------------------------------------------------
-- WoW Friend decorator
-- ---------------------------------------------------------
local function DecorateWoWFriend(button)
  local db = GetDB()
  if not (ETBC.db.profile.general.enabled and db.enabled) then
    SetFactionIcon(button, nil)
    return
  end

  local nameFont = button and button.name
  local infoFont = button and button.info
  if not nameFont then return end
  if not C_FriendList or not C_FriendList.GetFriendInfoByIndex then return end

  local id = button.id
  if not id or type(id) ~= "number" then
    nameFont:SetText("")
    if infoFont then infoFont:SetText("") end
    SetFactionIcon(button, nil)
    return
  end

  local info = C_FriendList.GetFriendInfoByIndex(id)
  if not info or not info.name then
    nameFont:SetText("")
    if infoFont then infoFont:SetText("") end
    SetFactionIcon(button, nil)
    return
  end

  local isConnected = not not info.connected
  local status
  if isConnected then
    if info.dnd then
      status = "DND"
    elseif info.afk then
      status = "AFK"
    else
      status = "Online"
    end
  else
    status = "Offline"
  end
  SetStatusIcon(button, status)

  local baseName, realm = strsplit("-", info.name, 2)
  baseName = baseName or info.name or ""
  local levelText = FormatLevel(info.level)

  local nameColored = baseName
  if isConnected then
    local localizedName = info.className or info.classLocalized or info.class
    local token = info.classTag or info.classFileName or info.classFile or info.classToken
    local r, g, b = GetClassColor(token, info.classID, localizedName)
    if not r and localizedName then
      r, g, b = GetClassColor(nil, info.classID, localizedName)
    end
    if r then nameColored = WrapColor(baseName, r, g, b) end
  else
    nameColored = WrapColor(baseName, 0.6, 0.6, 0.6)
  end

  local displayName = nameColored
  if levelText and levelText ~= "" then
    displayName = ("%s %s"):format(nameColored, levelText)
  end

  nameFont:SetText(displayName)
  ApplyNameFontOverride(button)
  if not isConnected then nameFont:SetTextColor(0.6, 0.6, 0.6) end

  if infoFont then
    local infoText
    if isConnected then
      infoText = BuildLocationText(info.area, realm)
    else
      if info.notes and info.notes ~= "" then
        infoText = info.notes
      else
        infoText = BuildLocationText(info.area, realm)
      end
    end
    infoFont:SetText(infoText or "")
  end

  SetFactionIcon(button, nil)

  if button.gameIcon then button.gameIcon:SetTexCoord(0, 1, 0, 1) end

  AdjustFavoriteAnchor(button)
end

-- ---------------------------------------------------------
-- BNet Friend decorator
-- ---------------------------------------------------------
local function DecorateBNetFriend(button)
  local db = GetDB()
  if not (ETBC.db.profile.general.enabled and db.enabled) then
    SetFactionIcon(button, nil)
    return
  end

  if not C_BattleNet or not C_BattleNet.GetFriendAccountInfo then return end
  local nameFont = button and button.name
  local infoFont = button and button.info
  if not nameFont then return end

  local id = button.id
  if not id or type(id) ~= "number" then
    nameFont:SetText("")
    if infoFont then infoFont:SetText("") end
    SetFactionIcon(button, nil)
    return
  end

  local accountInfo = C_BattleNet.GetFriendAccountInfo(id)
  if not accountInfo then
    nameFont:SetText("")
    if infoFont then infoFont:SetText("") end
    SetFactionIcon(button, nil)
    return
  end

  local gameInfo = accountInfo.gameAccountInfo
  local isOnline = not not (gameInfo and gameInfo.isOnline)
  local status
  if isOnline then
    if accountInfo.isDND or (gameInfo and gameInfo.isGameBusy) then
      status = "DND"
    elseif accountInfo.isAFK or (gameInfo and gameInfo.isGameAFK) then
      status = "AFK"
    else
      status = "Online"
    end
  else
    status = "Offline"
  end
  SetStatusIcon(button, status)

  local realID = accountInfo.accountName or
    (accountInfo.battleTag and accountInfo.battleTag:match("^[^#]+"))
  local displayName = realID or ""
  local infoText
  local factionName = nil

  if gameInfo and gameInfo.clientProgram == BNET_CLIENT_WOW then
    local localizedName = gameInfo.className or gameInfo.classLocalized or gameInfo.class
    local token = gameInfo.classTag or gameInfo.classFile or gameInfo.classToken
    local charName = gameInfo.characterName or ""
    local levelText = FormatLevel(gameInfo.characterLevel)
    if levelText and levelText ~= "" then
      if charName ~= "" then
        charName = ("%s %s"):format(charName, levelText)
      else
        charName = levelText
      end
    end
    local r, g, b = GetClassColor(token, gameInfo.classID, localizedName)
    if r then charName = WrapColor(charName, r, g, b) end

    local clientDisplay = ColorClientText(realID or "", gameInfo.clientProgram)
    if clientDisplay ~= "" and charName ~= "" then
      displayName = clientDisplay .. " || " .. charName
    elseif charName ~= "" then
      displayName = charName
    elseif clientDisplay ~= "" then
      displayName = clientDisplay
    end

    local location = BuildLocationText(gameInfo.areaName, gameInfo.realmDisplayName)
    if location and location ~= "" then
      infoText = location
    elseif db.showLocation then
      infoText = gameInfo.richPresence or ""
      if infoText == "" then infoText = accountInfo.note or "" end
    else
      infoText = accountInfo.note or ""
    end
    factionName = gameInfo.factionName
  else
    if gameInfo and gameInfo.clientProgram then
      displayName = ColorClientText(realID or "", gameInfo.clientProgram)
      if displayName == "" then displayName = realID or "" end
    end
    if displayName == "" then displayName = realID or "" end
    if gameInfo and gameInfo.richPresence then
      infoText = gameInfo.richPresence
    else
      infoText = accountInfo.note or ""
    end
  end

  nameFont:SetText(displayName)
  ApplyNameFontOverride(button)
  if not isOnline then nameFont:SetTextColor(0.6, 0.6, 0.6) end

  if infoFont then infoFont:SetText(infoText or "") end

  SetFactionIcon(button, factionName)

  if button.gameIcon then
    if gameInfo and gameInfo.clientTexture then
      button.gameIcon:SetTexture(gameInfo.clientTexture)
      button.gameIcon:SetTexCoord(0.15, 0.85, 0.15, 0.85)
    else
      button.gameIcon:SetTexCoord(0, 1, 0, 1)
    end
  end

  AdjustFavoriteAnchor(button)
end

-- ---------------------------------------------------------
-- Update and Hook system
-- ---------------------------------------------------------
local function UpdateFriendButton(button)
  if not button or not button.buttonType then return end

  local db = GetDB()
  if not (ETBC.db.profile.general.enabled and db.enabled) then
    if button._etbcFactionIcon then button._etbcFactionIcon:Hide() end
    RestoreNameFont(button)
    RestoreFavoriteAnchor(button)
    return
  end

  if button.buttonType == FRIENDS_BUTTON_TYPE_WOW then
    DecorateWoWFriend(button)
  elseif button.buttonType == FRIENDS_BUTTON_TYPE_BNET then
    DecorateBNetFriend(button)
  else
    if button._etbcFactionIcon then button._etbcFactionIcon:Hide() end
    RestoreNameFont(button)
  end
end

local function AreWoWFriendCountsReady()
  if not C_FriendList or not C_FriendList.GetNumFriends then return false end
  local ok, numFriends = pcall(C_FriendList.GetNumFriends)
  if not ok then return false end
  return type(numFriends) == "number"
end

local function ScheduleRefreshRetry()
  if not C_Timer or not C_Timer.After then return end
  if mod._pendingRefreshTimer then return end
  mod._pendingRefreshTimer = true
  C_Timer.After(0.1, function()
    mod._pendingRefreshTimer = nil
    mod:Refresh()
  end)
end

function mod:Refresh()
  if not hooked then self:EnsureHook() end

  if not AreWoWFriendCountsReady() then
    ScheduleRefreshRetry()
    return
  end

  -- Don't update if FriendsFrame isn't loaded or shown
  if not FriendsFrame or not FriendsFrame.IsShown or not FriendsFrame:IsShown() then
    return
  end

  -- Safely call update functions with pcall to prevent errors propagating
  local function SafeUpdate(fn)
    if type(fn) == "function" then
      local ok, err = pcall(fn)
      if not ok and ETBC and ETBC.Debug then
        ETBC:Debug("FriendsListDecor update error: "..tostring(err))
      end
      return ok
    end
    return false
  end

  if FriendsList_UpdateFriends then
    SafeUpdate(FriendsList_UpdateFriends)
  elseif FriendsFrame_UpdateFriends then
    SafeUpdate(FriendsFrame_UpdateFriends)
  elseif FriendsList_Update then
    SafeUpdate(FriendsList_Update)
  elseif FriendsFrame and FriendsFrame.ScrollBox and FriendsFrame.ScrollBox.Update then
    SafeUpdate(function() FriendsFrame.ScrollBox:Update() end)
  end
end

function mod.EnsureHook(_)
  if hooked then return true end
  if type(FriendsFrame_UpdateFriendButton) ~= "function" then return false end
  hooksecurefunc("FriendsFrame_UpdateFriendButton", UpdateFriendButton)
  hooked = true
  return true
end

function mod:Apply()
  local db = GetDB()
  local enabled = ETBC.db.profile.general.enabled and db.enabled

  if enabled then
    self:EnsureHook()
    self:Refresh()
  else
    self:Refresh()
  end
end

-- ---------------------------------------------------------
-- ApplyBus registration
-- ---------------------------------------------------------
if ETBC.ApplyBus and ETBC.ApplyBus.Register then
  ETBC.ApplyBus:Register("friends", function()
    mod:Apply()
  end)
  ETBC.ApplyBus:Register("general", function()
    mod:Apply()
  end)
end

-- ---------------------------------------------------------
-- Event handling for late-loading friends UI
-- ---------------------------------------------------------
local driver = CreateFrame("Frame", "EnhanceTBC_FriendsDecorDriver", UIParent)
driver:Hide()

driver:RegisterEvent("ADDON_LOADED")
driver:SetScript("OnEvent", function(_, event, addonName)
  if event == "ADDON_LOADED" then
    if addonName == "Blizzard_FriendsUI" or addonName == "Blizzard_FriendsFrame" then
      mod:EnsureHook()
      mod:Refresh()
    end
  end
end)

-- Initialize on load
mod:EnsureHook()

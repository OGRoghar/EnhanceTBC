-- Modules/FriendsListDecor.lua
-- EnhanceTBC - Friends list decorator (LEGACY FriendsFrameFriendsScrollFrame.buttons)
-- Ported to current EnhanceTBC architecture (ETBC.ApplyBus + ETBC.db.profile.*)
-- Key fix vs "works once then stops": decorate AFTER Blizzard updates rows (C_Timer.After(0,...))

local ADDON_NAME, ETBC = ...

ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.FriendsListDecor = mod

local driver
local hooked = false
local pending = false

-- ---------------------------------------------------------
-- DB
-- ---------------------------------------------------------
local function GetDB()
  ETBC.db.profile.friends = ETBC.db.profile.friends or {}
  local db = ETBC.db.profile.friends

  if db.enabled == nil then db.enabled = true end

  if db.onlineColor == nil then db.onlineColor = { 0.20, 1.00, 0.20 } end
  if db.inAppColor == nil then db.inAppColor = { 0.30, 0.75, 1.00 } end
  if db.offlineColor == nil then db.offlineColor = { 0.55, 0.55, 0.55 } end

  if db.tintInfoLine == nil then db.tintInfoLine = false end
  if db.tintStatusLine == nil then db.tintStatusLine = false end
  if db.debugShowState == nil then db.debugShowState = false end

  return db
end

-- ---------------------------------------------------------
-- Helpers (same logic as your working version)
-- ---------------------------------------------------------
local function StripColorCodes(s)
  if not s or s == "" then return s end
  s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
  s = s:gsub("|r", "")
  return s
end

local function Lower(s) return tostring(s or ""):lower() end

local function IsFontString(obj)
  return obj and obj.GetObjectType and obj:GetObjectType() == "FontString"
end

local function GetText(fs)
  if IsFontString(fs) and fs.GetText then
    return fs:GetText() or ""
  end
  return ""
end

local function SetRGB(fs, rgb)
  if not fs or not fs.SetTextColor or type(rgb) ~= "table" then return end
  fs:SetTextColor(rgb[1] or 1, rgb[2] or 1, rgb[3] or 1)
end

-- ---------------------------------------------------------
-- State resolution (reliable)
-- ---------------------------------------------------------
local function GetStateFromWoWFriend(friendIndex)
  -- Prefer C_FriendList where available
  if C_FriendList and C_FriendList.GetFriendInfoByIndex then
    local info = C_FriendList.GetFriendInfoByIndex(friendIndex)
    if not info or not info.name then return nil end
    if info.connected then return "ONLINE" end
    return "OFFLINE"
  end

  -- Classic: GetFriendInfo(index)
  if not GetFriendInfo then return nil end
  local name, level, class, area, connected = GetFriendInfo(friendIndex)
  if name == nil then return nil end
  if connected then return "ONLINE" end
  return "OFFLINE"
end

local function GetStateFromBNFriend(friendIndex)
  -- Support both BNGetFriendInfo(index) and BNGetFriendInfoByID(presenceID)
  if BNGetFriendInfo then
    local presenceID, accountName, battleTag, isBattleTagPresence, characterName,
      bnetIDGameAccount, client, isOnline = BNGetFriendInfo(friendIndex)

    if presenceID ~= nil or accountName ~= nil or battleTag ~= nil then
      if not isOnline then
        return "OFFLINE"
      end
      local c = Lower(client)
      if c == "" or c == "bnet" or c == "app" or c:find("bsa", 1, true) then
        return "INAPP"
      end
      return "ONLINE"
    end
  end

  if BNGetFriendInfoByID then
    local presenceID = friendIndex
    local accountName, battleTag, isBattleTagPresence, characterName,
      bnetIDGameAccount, client, isOnline = BNGetFriendInfoByID(presenceID)

    if accountName ~= nil or battleTag ~= nil then
      if not isOnline then
        return "OFFLINE"
      end
      local c = Lower(client)
      if c == "" or c == "bnet" or c == "app" or c:find("bsa", 1, true) then
        return "INAPP"
      end
      return "ONLINE"
    end
  end

  return nil
end

local function GuessStateFallback(btn)
  local status = StripColorCodes(GetText(btn.status))
  local info   = StripColorCodes(GetText(btn.info))
  local s = Lower(status)
  local i = Lower(info)

  if s:find("offline", 1, true) or i:find("offline", 1, true) then return "OFFLINE" end
  if s:find("in app", 1, true) or i:find("in app", 1, true) then return "INAPP" end
  return "ONLINE"
end

local function ResolveState(btn)
  local id = btn and btn.id

  if id and (BNGetFriendInfo or BNGetFriendInfoByID) then
    local s = GetStateFromBNFriend(id)
    if s then return s end
  end

  if id and (GetFriendInfo or (C_FriendList and C_FriendList.GetFriendInfoByIndex)) then
    local s = GetStateFromWoWFriend(id)
    if s then return s end
  end

  return GuessStateFallback(btn)
end

-- ---------------------------------------------------------
-- Decorate (legacy buttons)
-- ---------------------------------------------------------
local function DecorateNow()
  pending = false

  local db = GetDB()
  if not (ETBC.db.profile.general.enabled and db.enabled) then return end

  local sf = _G.FriendsFrameFriendsScrollFrame
  if not sf or not sf.buttons then return end

  for _, btn in ipairs(sf.buttons) do
    if btn and btn.IsShown and btn:IsShown() then
      local nameFS = btn.name
      local infoFS = btn.info
      local statusFS = btn.status

      if not IsFontString(nameFS) then
        if IsFontString(btn.nameText) then nameFS = btn.nameText end
        if (not IsFontString(nameFS)) and IsFontString(btn.text) then nameFS = btn.text end
      end

      if IsFontString(nameFS) then
        local state = ResolveState(btn)

        local rgb
        if state == "OFFLINE" then rgb = db.offlineColor
        elseif state == "INAPP" then rgb = db.inAppColor
        else rgb = db.onlineColor end

        SetRGB(nameFS, rgb)
        if db.tintInfoLine and IsFontString(infoFS) then SetRGB(infoFS, rgb) end
        if db.tintStatusLine and IsFontString(statusFS) then SetRGB(statusFS, rgb) end

        if db.debugShowState and IsFontString(statusFS) and statusFS.SetText then
          local base = StripColorCodes(GetText(statusFS))
          if base == "" then base = " " end
          statusFS:SetText(base .. "  [" .. state .. "]")
        end
      end
    end
  end
end

local function DecorateSoon()
  if pending then return end
  pending = true

  if C_Timer and C_Timer.After then
    C_Timer.After(0, DecorateNow) -- run after Blizzard fills rows
  else
    DecorateNow()
  end
end

-- ---------------------------------------------------------
-- Hooks
-- ---------------------------------------------------------
local function HookFriendsFrame()
  if hooked then return end
  hooked = true

  local sf = _G.FriendsFrameFriendsScrollFrame
  if sf then
    -- Different builds use different method names; hook whatever exists.
    if type(sf.update) == "function" then
      hooksecurefunc(sf, "update", DecorateSoon)
    end
    if type(sf.Update) == "function" then
      hooksecurefunc(sf, "Update", DecorateSoon)
    end

    -- Scrolling often rebuilds visible rows
    if sf.HookScript then
      sf:HookScript("OnShow", DecorateSoon)
      sf:HookScript("OnVerticalScroll", DecorateSoon)
    end
  end

  if _G.FriendsList_Update then
    hooksecurefunc("FriendsList_Update", DecorateSoon)
  end
  if _G.FriendsFrame_UpdateFriends then
    hooksecurefunc("FriendsFrame_UpdateFriends", DecorateSoon)
  end
end

-- ---------------------------------------------------------
-- Driver / Apply
-- ---------------------------------------------------------
local function EnsureDriver()
  if driver then return end
  driver = CreateFrame("Frame", "EnhanceTBC_FriendsDecorDriver", UIParent)
  driver:Hide()
end

local function Apply()
  EnsureDriver()

  local db = GetDB()
  local enabled = ETBC.db.profile.general.enabled and db.enabled

  driver:UnregisterAllEvents()
  driver:SetScript("OnEvent", nil)

  if enabled then
    HookFriendsFrame()

    -- Events that usually imply list redraw
    driver:RegisterEvent("FRIENDLIST_UPDATE")
    driver:RegisterEvent("BN_FRIEND_INFO_CHANGED")
    driver:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE")
    driver:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE")
    driver:RegisterEvent("PLAYER_ENTERING_WORLD")
    driver:RegisterEvent("ADDON_LOADED")

    driver:SetScript("OnEvent", function(_, event, name)
      -- Different clients name this differently
      if event == "ADDON_LOADED" then
        if name == "Blizzard_FriendsUI" or name == "Blizzard_FriendsFrame" then
          HookFriendsFrame()
          DecorateSoon()
        end
        return
      end
      DecorateSoon()
    end)

    driver:Show()
    DecorateSoon()
  else
    driver:Hide()
  end
end

ETBC.ApplyBus:Register("friends", Apply)
ETBC.ApplyBus:Register("general", Apply)

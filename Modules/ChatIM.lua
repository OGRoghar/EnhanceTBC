-- Modules/ChatIM.lua
local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.ChatIM = mod

local driver
local filtersRegistered = false
local lastWhisperSoundAt = 0

-- Copy UI
local copyFrame, copyBox, copyScroll
local copyButton
local copyDrop
local addMessageHooksInstalled = false

-- Per-frame rolling history
local historyByFrameId = {} -- [id] = { lines = {}, max = number }

local FILTER_EVENTS = {
  "CHAT_MSG_SAY",
  "CHAT_MSG_YELL",
  "CHAT_MSG_EMOTE",
  "CHAT_MSG_TEXT_EMOTE",
  "CHAT_MSG_GUILD",
  "CHAT_MSG_OFFICER",
  "CHAT_MSG_PARTY",
  "CHAT_MSG_PARTY_LEADER",
  "CHAT_MSG_RAID",
  "CHAT_MSG_RAID_LEADER",
  "CHAT_MSG_RAID_WARNING",
  "CHAT_MSG_INSTANCE_CHAT",
  "CHAT_MSG_INSTANCE_CHAT_LEADER",
  "CHAT_MSG_WHISPER",
  "CHAT_MSG_WHISPER_INFORM",
  "CHAT_MSG_CHANNEL",
  "CHAT_MSG_SYSTEM",
  "CHAT_MSG_LOOT",
  "CHAT_MSG_MONEY",
  "CHAT_MSG_COMBAT_XP_GAIN",
  "CHAT_MSG_COMBAT_HONOR_GAIN",
  "CHAT_MSG_SKILL",
  "CHAT_MSG_TRADESKILLS",
  "CHAT_MSG_OPENING",
  "CHAT_MSG_MONSTER_SAY",
  "CHAT_MSG_MONSTER_YELL",
  "CHAT_MSG_MONSTER_EMOTE",
  "CHAT_MSG_MONSTER_WHISPER",
  "CHAT_MSG_RAID_BOSS_EMOTE",
  "CHAT_MSG_RAID_BOSS_WHISPER",
}

local function EnsureDriver()
  if driver then return end
  driver = CreateFrame("Frame", "EnhanceTBC_ChatIMDriver", UIParent)
  driver:Hide()
end

local function GetDB()
  ETBC.db.profile.chatim = ETBC.db.profile.chatim or {}
  local db = ETBC.db.profile.chatim

  if db.enabled == nil then db.enabled = true end

  if db.timestamps == nil then db.timestamps = false end
  if db.timestampFormat == nil then db.timestampFormat = "%H:%M" end

  if db.urlLinks == nil then db.urlLinks = true end
  if db.emailLinks == nil then db.emailLinks = true end

  if db.shortenChannels == nil then db.shortenChannels = true end

  if db.whisperSound == nil then db.whisperSound = false end
  if db.whisperSoundIncoming == nil then db.whisperSoundIncoming = true end
  if db.whisperSoundOutgoing == nil then db.whisperSoundOutgoing = false end
  if db.whisperSoundThrottle == nil then db.whisperSoundThrottle = 1.5 end
  if db.whisperSoundMedia == nil then db.whisperSoundMedia = "Blizzard TellMessage" end

  if db.copyLines == nil then db.copyLines = 200 end
  if db.copyButton == nil then db.copyButton = true end
  if db.copyButtonScale == nil then db.copyButtonScale = 1.0 end
  if db.copyButtonAlpha == nil then db.copyButtonAlpha = 0.95 end
  if db.copyTarget == nil then db.copyTarget = "follow" end

  return db
end

-- --------------------
-- History
-- --------------------

local function StripCodes(s)
  if type(s) ~= "string" then return s end
  s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
  s = s:gsub("|r", "")
  s = s:gsub("|H.-|h(.-)|h", "%1")
  return s
end

local function GetHistory(frameId, max)
  local h = historyByFrameId[frameId]
  if not h then
    h = { lines = {}, max = max or 2000 }
    historyByFrameId[frameId] = h
  end
  h.max = max or h.max or 2000
  while #h.lines > h.max do
    table.remove(h.lines, 1)
  end
  return h
end

local function Push(frameId, line, max)
  if type(line) ~= "string" or line == "" then return end
  local h = GetHistory(frameId, max)
  h.lines[#h.lines + 1] = line
  while #h.lines > h.max do
    table.remove(h.lines, 1)
  end
end

local function InstallAddMessageHooks()
  if addMessageHooksInstalled then return end
  addMessageHooksInstalled = true

  local n = NUM_CHAT_WINDOWS or 10
  for i = 1, n do
    local cf = _G["ChatFrame" .. i]
    if cf and cf.AddMessage and type(cf.AddMessage) == "function" then
      hooksecurefunc(cf, "AddMessage", function(_, text)
        if not ETBC.db or not ETBC.db.profile then return end
        local db = GetDB()
        if not (ETBC.db.profile.general.enabled and db.enabled) then return end

        local maxKeep = math.max(2000, tonumber(db.copyLines) or 200)
        if type(text) == "string" then
          Push(i, StripCodes(text), maxKeep)
        end
      end)
    end
  end
end

-- --------------------
-- Message transforms
-- --------------------

local function EscapePercents(msg)
  if type(msg) ~= "string" then return msg end
  if msg:find("%%", 1, true) then
    return msg:gsub("%%", "%%%%")
  end
  return msg
end

local function AddTimestamp(db, msg)
  if not db.timestamps then return msg end
  local fmt = db.timestampFormat or "%H:%M"
  local ts = date(fmt)
  return "|cff66ff66[" .. ts .. "]|r " .. msg
end

local function ShortenTags(db, msg)
  if not db.shortenChannels or type(msg) ~= "string" then return msg end
  msg = msg:gsub("^%[Guild%]", "[G]")
  msg = msg:gsub("^%[Party%]", "[P]")
  msg = msg:gsub("^%[Party Leader%]", "[PL]")
  msg = msg:gsub("^%[Raid%]", "[R]")
  msg = msg:gsub("^%[Raid Leader%]", "[RL]")
  msg = msg:gsub("^%[Raid Warning%]", "[RW]")
  msg = msg:gsub("^%[Officer%]", "[O]")
  msg = msg:gsub("^%[Instance%]", "[I]")
  msg = msg:gsub("^%[Instance Leader%]", "[IL]")
  msg = msg:gsub("^%[Whisper%]", "[W]")
  msg = msg:gsub("^%[Whispered%]", "[W]")
  return msg
end

local function MakeLinks(db, msg)
  if not db.urlLinks or type(msg) ~= "string" then return msg end
  if msg:find("|H", 1, true) then return msg end

  msg = msg:gsub("(%f[%w])(https?://[%w%-%._~:/%?#%[%]@!$&'%(%)%*%+,;=]+)", "|Hurl:%2|h|cff00ff00%2|r|h")
  msg = msg:gsub("(%f[%w])(www%.[%w%-%._~:/%?#%[%]@!$&'%(%)%*%+,;=]+)", "|Hurl:http://%2|h|cff00ff00%2|r|h")

  if db.emailLinks then
    msg = msg:gsub("(%f[%w])([%w%.%+%-_]+@[%w%.%-_]+%.[%a]+)", "|Hurl:mailto:%2|h|cff00ff00%2|r|h")
  end

  return msg
end

-- IMPORTANT: Correct signature is (self, event, msg, author, ...)
local function Filter(_, _, msg, author, ...)
  local db = GetDB()

  if not (ETBC.db.profile.general.enabled and db.enabled) then
    return false, msg, author, ...
  end

  msg = EscapePercents(msg)
  msg = MakeLinks(db, msg)
  msg = AddTimestamp(db, msg)
  msg = ShortenTags(db, msg)

  return false, msg, author, ...
end

local function RegisterFilters()
  if filtersRegistered then return end
  filtersRegistered = true
  for i = 1, #FILTER_EVENTS do
    ChatFrame_AddMessageEventFilter(FILTER_EVENTS[i], Filter)
  end
end

local function UnregisterFilters()
  if not filtersRegistered then return end
  filtersRegistered = false
  for i = 1, #FILTER_EVENTS do
    ChatFrame_RemoveMessageEventFilter(FILTER_EVENTS[i], Filter)
  end
end

local function HandleURLLink(link)
  if type(link) ~= "string" then return false end
  if link:sub(1, 4) ~= "url:" then return false end

  local url = link:sub(5)
  if type(url) ~= "string" then
    return true
  end
  url = url:gsub("^%s+", ""):gsub("%s+$", "")
  if url == "" then
    return true
  end

  local eb = ChatEdit_ChooseBoxForSend and ChatEdit_ChooseBoxForSend() or nil
  if eb then
    if ChatEdit_ActivateChat then
      ChatEdit_ActivateChat(eb)
    end
    if eb.Insert then
      eb:Insert(url)
    end
    if eb.HighlightText then
      eb:HighlightText()
    end
  end

  return true
end

local function HookURLClick()
  if mod._urlHooked then return end
  mod._urlHooked = true

  if _G and type(_G.SetItemRef) == "function" and _G.SetItemRef ~= mod._setItemRefWrapper then
    mod._origSetItemRef = _G.SetItemRef
    mod._setItemRefWrapper = function(link, text, button, chatFrame, ...)
      if HandleURLLink(link) then
        return
      end

      if mod._origSetItemRef then
        return mod._origSetItemRef(link, text, button, chatFrame, ...)
      end
    end
    _G.SetItemRef = mod._setItemRefWrapper
  end

  if ItemRefTooltip and type(ItemRefTooltip.SetHyperlink) == "function"
      and ItemRefTooltip.SetHyperlink ~= mod._itemRefTooltipSetHyperlinkWrapper then
    mod._origItemRefTooltipSetHyperlink = ItemRefTooltip.SetHyperlink
    mod._itemRefTooltipSetHyperlinkWrapper = function(self, link, ...)
      if HandleURLLink(link) then
        if self and self.Hide and self.IsShown and self:IsShown() then
          self:Hide()
        end
        return
      end

      if mod._origItemRefTooltipSetHyperlink then
        return mod._origItemRefTooltipSetHyperlink(self, link, ...)
      end
    end
    ItemRefTooltip.SetHyperlink = mod._itemRefTooltipSetHyperlinkWrapper
  end
end

-- --------------------
-- Copy UI with target selection
-- --------------------

local function ApplyCopyTheme(frame)
  if not frame or not frame.SetBackdrop then return end
  frame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
  })
  frame:SetBackdropColor(0.03, 0.06, 0.03, 0.92)
  frame:SetBackdropBorderColor(0.20, 1.00, 0.20, 0.95)
end

local function ChatFrameNameById(id)
  local cf = _G["ChatFrame" .. id]
  if not cf then return ("ChatFrame" .. id) end
  local n = GetChatWindowInfo and select(1, GetChatWindowInfo(id))
  if n and n ~= "" then return n end
  return ("ChatFrame" .. id)
end

local function BuildFrameList()
  local list = {}
  list["follow"] = "Follow current tab"
  local n = NUM_CHAT_WINDOWS or 10
  for i = 1, n do
    list[tostring(i)] = ChatFrameNameById(i)
  end
  return list
end

local function GetCurrentFrameId()
  if FCF_GetCurrentChatFrame then
    local cf = FCF_GetCurrentChatFrame()
    if cf and cf.GetName then
      local name = cf:GetName()
      if type(name) == "string" then
        local id = tonumber(name:match("^ChatFrame(%d+)$"))
        if id then return id end
      end
    end
  end
  return 1
end

local function ResolveTargetFrameId(db)
  if db.copyTarget == "follow" then
    return GetCurrentFrameId()
  end
  local id = tonumber(db.copyTarget)
  if id and id >= 1 then return id end
  return 1
end

local function EnsureCopyUI()
  if copyFrame then return end

  copyFrame = CreateFrame(
    "Frame", "EnhanceTBC_ChatCopyFrame", UIParent,
    BackdropTemplateMixin and "BackdropTemplate" or nil
  )
  copyFrame:SetSize(780, 470)
  copyFrame:SetPoint("CENTER")
  copyFrame:SetFrameStrata("DIALOG")
  copyFrame:SetMovable(true)
  copyFrame:EnableMouse(true)
  copyFrame:RegisterForDrag("LeftButton")
  copyFrame:SetScript("OnDragStart", function(self) if not self.StartMoving then return end self:StartMoving() end)
  copyFrame:SetScript("OnDragStop", function(self) if self.StopMovingOrSizing then self:StopMovingOrSizing() end end)
  copyFrame:Hide()
  ApplyCopyTheme(copyFrame)

  local title = copyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", 12, -10)
  title:SetText("EnhanceTBC • Chat Copy")

  local close = CreateFrame("Button", nil, copyFrame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -2, -2)

  local label = copyFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  label:SetPoint("TOPLEFT", 12, -30)
  label:SetText("Source:")

  copyDrop = CreateFrame("Frame", "EnhanceTBC_ChatCopyDropDown", copyFrame, "UIDropDownMenuTemplate")
  copyDrop:SetPoint("TOPLEFT", 52, -42)

  local selectAll = CreateFrame("Button", nil, copyFrame, "UIPanelButtonTemplate")
  selectAll:SetSize(110, 22)
  selectAll:SetPoint("TOPRIGHT", -44, -32)
  selectAll:SetText("Select All")
  selectAll:SetScript("OnClick", function()
    if copyBox then
      copyBox:SetFocus()
      copyBox:HighlightText()
    end
  end)

  local hint = copyFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", 12, -52)
  hint:SetText("Ctrl+A selects all. Esc closes.")

  copyScroll = CreateFrame("ScrollFrame", "EnhanceTBC_ChatCopyScroll", copyFrame, "UIPanelScrollFrameTemplate")
  copyScroll:SetPoint("TOPLEFT", 12, -76)
  copyScroll:SetPoint("BOTTOMRIGHT", -34, 12)

  copyBox = CreateFrame("EditBox", "EnhanceTBC_ChatCopyEditBox", copyScroll)
  copyBox:SetMultiLine(true)
  copyBox:SetAutoFocus(true)
  copyBox:EnableMouse(true)
  copyBox:SetFontObject(ChatFontNormal)
  copyBox:SetWidth(720)
  copyBox:SetText("")
  copyBox:SetScript("OnEscapePressed", function() copyFrame:Hide() end)
  copyBox:SetScript("OnTextChanged", function()
    copyScroll:UpdateScrollChildRect()
  end)
  copyBox:SetScript("OnKeyDown", function(self, key)
    if IsControlKeyDown() and (key == "A" or key == "a") then
      self:HighlightText()
      return
    end
  end)

  copyScroll:SetScrollChild(copyBox)
end

local function RefreshDropDown(db)
  if not copyDrop then return end

  local values = BuildFrameList()
  local orderedKeys = { "follow" }
  local n = NUM_CHAT_WINDOWS or 10
  for i = 1, n do
    orderedKeys[#orderedKeys + 1] = tostring(i)
  end

  UIDropDownMenu_Initialize(copyDrop, function(_, level)
    for _, k in ipairs(orderedKeys) do
      local v = values[k]
      if v then
        local info = UIDropDownMenu_CreateInfo()
        info.text = v
        info.value = k
        info.func = function()
          db.copyTarget = k
          UIDropDownMenu_SetSelectedValue(copyDrop, k)
          if copyFrame and copyFrame:IsShown() then
            mod:OpenCopy()
          end
        end
        UIDropDownMenu_AddButton(info, level)
      end
    end
  end)

  UIDropDownMenu_SetWidth(copyDrop, 200)
  UIDropDownMenu_SetSelectedValue(copyDrop, db.copyTarget)
end

function mod.OpenCopy(_)
  local db = GetDB()
  EnsureCopyUI()
  RefreshDropDown(db)

  local frameId = ResolveTargetFrameId(db)
  local maxKeep = math.max(2000, tonumber(db.copyLines) or 200)

  local h = GetHistory(frameId, maxKeep)
  local lines = h.lines or {}

  local want = math.max(1, math.floor(tonumber(db.copyLines) or 200))
  local startIndex = math.max(1, #lines - want + 1)

  local out = {}
  for i = startIndex, #lines do
    out[#out + 1] = lines[i]
  end

  copyBox:SetText(table.concat(out, "\n"))
  copyFrame:Show()
  copyBox:SetFocus()
  copyBox:HighlightText()
end

-- --------------------
-- Copy button near ChatFrame1
-- --------------------

local function EnsureCopyButton()
  if copyButton then return end

  copyButton = CreateFrame(
    "Button", "EnhanceTBC_ChatCopyButton", UIParent,
    BackdropTemplateMixin and "BackdropTemplate" or nil
  )
  copyButton:SetSize(18, 18)
  copyButton:SetFrameStrata("HIGH")
  copyButton:EnableMouse(true)

  if copyButton.SetBackdrop then
    copyButton:SetBackdrop({
      bgFile = "Interface/Buttons/WHITE8x8",
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
      tile = true, tileSize = 8, edgeSize = 10,
      insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    copyButton:SetBackdropColor(0.03, 0.06, 0.03, 0.90)
    copyButton:SetBackdropBorderColor(0.20, 1.00, 0.20, 0.95)
  end

  local icon = copyButton:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  icon:SetTexture("Interface/Buttons/UI-GuildButton-PublicNote-Up")
  icon:SetTexCoord(0.18, 0.82, 0.18, 0.82)

  copyButton:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Copy Chat")
    GameTooltip:AddLine("Opens a window with recent chat lines.", 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine("Command: /etbccopy", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  copyButton:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
  end)

  copyButton:SetScript("OnClick", function()
    mod:OpenCopy()
  end)
end

local function PositionCopyButton(db)
  EnsureCopyButton()
  local anchorFrame = ChatFrame1
  if not anchorFrame or not anchorFrame:IsShown() then
    copyButton:Hide()
    return
  end
  copyButton:ClearAllPoints()
  copyButton:SetPoint("TOPRIGHT", anchorFrame, "TOPRIGHT", -6, -6)
  copyButton:SetScale(tonumber(db.copyButtonScale) or 1.0)
  copyButton:SetAlpha(tonumber(db.copyButtonAlpha) or 0.95)
  copyButton:Show()
end

local function HideCopyButton()
  if copyButton then copyButton:Hide() end
end

-- --------------------
-- Whisper sound
-- --------------------

local function MaybePlayWhisperSound(event)
  local db = GetDB()
  if not (ETBC.db.profile.general.enabled and db.enabled) then return end
  if not db.whisperSound then return end

  if event == "CHAT_MSG_WHISPER" and not db.whisperSoundIncoming then return end
  if event == "CHAT_MSG_WHISPER_INFORM" and not db.whisperSoundOutgoing then return end

  local now = GetTime()
  local throttle = tonumber(db.whisperSoundThrottle) or 1.5
  if throttle > 0 and (now - lastWhisperSoundAt) < throttle then return end
  lastWhisperSoundAt = now

  local played = false
  if db.whisperSoundMedia and ETBC.LSM and ETBC.LSM.Fetch and PlaySoundFile then
    local ok, soundPath = pcall(ETBC.LSM.Fetch, ETBC.LSM, "sound", db.whisperSoundMedia, true)
    if ok and soundPath and soundPath ~= "" then
      local okPlay = pcall(PlaySoundFile, soundPath, "Master")
      if not okPlay then
        pcall(PlaySoundFile, soundPath)
      end
      played = true
    end
  end

  if not played then
    if SOUNDKIT and SOUNDKIT.TELL_MESSAGE then
      PlaySound(SOUNDKIT.TELL_MESSAGE)
    else
      PlaySound("TellMessage")
    end
  end
end

-- --------------------
-- Commands
-- --------------------

local function RegisterCommands()
  if mod._commands then return end
  mod._commands = true

  SLASH_ENHANCETBCCOPY1 = "/etbccopy"
  SlashCmdList["ENHANCETBCCOPY"] = function()
    mod:OpenCopy()
  end
end

-- --------------------
-- Apply
-- --------------------

local function Apply()
  EnsureDriver()
  local db = GetDB()
  local enabled = ETBC.db.profile.general.enabled and db.enabled

  driver:UnregisterAllEvents()
  driver:SetScript("OnEvent", nil)

  if enabled then
    RegisterFilters()
    InstallAddMessageHooks()
    HookURLClick()
    RegisterCommands()

    if db.copyButton then
      PositionCopyButton(db)
    else
      HideCopyButton()
    end

    driver:RegisterEvent("PLAYER_ENTERING_WORLD")
    driver:RegisterEvent("UI_SCALE_CHANGED")
    driver:RegisterEvent("DISPLAY_SIZE_CHANGED")
    driver:RegisterEvent("UPDATE_CHAT_WINDOWS")
    driver:RegisterEvent("CHAT_MSG_WHISPER")
    driver:RegisterEvent("CHAT_MSG_WHISPER_INFORM")

    driver:SetScript("OnEvent", function(_, event)
      if not ETBC.db or not ETBC.db.profile then return end

      if event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_WHISPER_INFORM" then
        MaybePlayWhisperSound(event)
        return
      end

      local db2 = GetDB()
      if not (ETBC.db.profile.general.enabled and db2.enabled) then return end

      if db2.copyButton then
        PositionCopyButton(db2)
      else
        HideCopyButton()
      end

      -- keep dropdown names fresh if chat windows changed
      if copyFrame and copyFrame:IsShown() then
        EnsureCopyUI()
        RefreshDropDown(db2)
      end
    end)

    driver:Show()
  else
    UnregisterFilters()
    HideCopyButton()
    driver:Hide()
  end
end

ETBC.ApplyBus:Register("chatim", Apply)
ETBC.ApplyBus:Register("general", Apply)

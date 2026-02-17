-- Modules/MinimapPlus.lua
-- EnhanceTBC - Minimap QoL (TBC Anniversary 20505)
-- Features:
--  - Gather minimap buttons into a movable, lockable button sink
--  - Quick spec/loot switching (best-effort, version-safe)
--  - Optional square minimap + custom instance difficulty icon (forked from Leatrix Plus)
--  - Right-click menus for Expansion/Garrison landing page buttons (if they exist)
--  - Hide minimap button, bags bar, micro menu, Quick Join Toast, Raid Tools in party
--  - Show/hide specific landing page buttons (if they exist)

local ADDON_NAME, ETBC = ...
local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceTBC")
ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.MinimapPlus = mod

-- Constants
local SQUARE_MASK_TEXTURE = "Interface\\ChatFrame\\ChatFrameBackground"
local ROUND_MASK_TEXTURE = "Textures\\MinimapMask"  -- WoW TBC default minimap mask
local MAX_ZOOM_LEVEL = 5  -- WoW's maximum minimap zoom level
local SIZE_CHECK_TOLERANCE = 1  -- Pixel tolerance for size drift detection

local driver
local sink
local dropdown

local collected = {} -- [frame] = { parent, points = {...}, scale, strata, level, shown, ignore }
local orderedButtons = {}
local lastScan = 0
local isZoomHooked = false  -- Track if mouse wheel zoom has been hooked
local isMinimapRightClickHooked = false  -- Track if minimap right-click has been hooked

local squareState = {
  saved = false,
  minimapScale = 1,
  minimapMask = nil,
  minimapSize = { 140, 140 },
  zoneParent = nil,
  zonePoints = nil,
  zoneScale = 1,
}

local function Print(msg)
  if ETBC and ETBC.Print then
    ETBC:Print(msg)
  elseif DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99EnhanceTBC|r " .. tostring(msg))
  end
end

local function GetDB()
  ETBC.db.profile.minimapPlus = ETBC.db.profile.minimapPlus or {}
  local db = ETBC.db.profile.minimapPlus

  if db.enabled == nil then db.enabled = true end

  -- Button sink
  if db.sinkEnabled == nil then db.sinkEnabled = true end
  if db.locked == nil then db.locked = false end
  if db.scale == nil then db.scale = 1.0 end
  if db.buttonSize == nil then db.buttonSize = 28 end
  if db.padding == nil then db.padding = 6 end
  if db.columns == nil then db.columns = 6 end
  if db.growDown == nil then db.growDown = true end
  if db.backdrop == nil then db.backdrop = true end
  if db.autoScan == nil then db.autoScan = true end
  if db.scanInterval == nil then db.scanInterval = 2.0 end
  if db.includeQueue == nil then db.includeQueue = false end
  if db.includeTracking == nil then db.includeTracking = false end
  if db.includeCalendar == nil then db.includeCalendar = false end
  if db.includeClock == nil then db.includeClock = false end
  if db.includeMail == nil then db.includeMail = false end
  if db.includeDifficulty == nil then db.includeDifficulty = false end

  -- Minimap shape + difficulty icon
  if db.squareMinimap == nil then db.squareMinimap = false end
  if db.squareSize == nil then db.squareSize = 140 end
  if db.customDifficultyIcon == nil then db.customDifficultyIcon = true end

  -- Hides
  if db.hideMinimapToggleButton == nil then db.hideMinimapToggleButton = true end
  if db.hideBagsBar == nil then db.hideBagsBar = false end
  if db.hideMicroMenu == nil then db.hideMicroMenu = false end
  if db.hideQuickJoinToast == nil then db.hideQuickJoinToast = true end
  if db.hideRaidToolsInParty == nil then db.hideRaidToolsInParty = true end

  -- Landing page buttons
  db.landingButtons = db.landingButtons or {}
  if db.landingButtons.ExpansionLandingPageMinimapButton == nil then db.landingButtons.ExpansionLandingPageMinimapButton = true end
  if db.landingButtons.GarrisonLandingPageMinimapButton == nil then db.landingButtons.GarrisonLandingPageMinimapButton = true end
  if db.landingButtons.QueueStatusMinimapButton == nil then db.landingButtons.QueueStatusMinimapButton = true end

  -- Quick switches
  if db.quickEnabled == nil then db.quickEnabled = true end
  if db.defaultLootMethod == nil then db.defaultLootMethod = "group" end
  if db.defaultLootThreshold == nil then db.defaultLootThreshold = 2 end -- Uncommon

  -- Sink position
  db.sinkPoint = db.sinkPoint or "TOPRIGHT"
  db.sinkRelPoint = db.sinkRelPoint or "TOPRIGHT"
  db.sinkX = db.sinkX or -200
  db.sinkY = db.sinkY or -120

  -- Clamp scale to sane bounds (prevents invisible sink)
  if db.scale < 0.5 then db.scale = 0.5 end
  if db.scale > 2.0 then db.scale = 2.0 end

  return db
end

local function EnsureDriver()
  if driver then return end
  driver = CreateFrame("Frame", "EnhanceTBC_MinimapPlusDriver", UIParent)
  driver:Hide()
end

local function EnsureDropdown()
  if dropdown then return end
  dropdown = CreateFrame("Frame", "EnhanceTBC_MinimapPlusDropDown", UIParent, "UIDropDownMenuTemplate")
end

local function SetFramePointFromDB(frame, db)
  frame:ClearAllPoints()
  frame:SetPoint(db.sinkPoint, UIParent, db.sinkRelPoint, db.sinkX, db.sinkY)
end

local function SaveFramePointToDB(frame, db)
  local p, _, rp, x, y = frame:GetPoint(1)
  if p then
    db.sinkPoint = p
    db.sinkRelPoint = rp
    db.sinkX = x
    db.sinkY = y
  end
end

local function EnsureSink()
  if sink then return end

  -- BackdropTemplate exists in later classic; safe to pass even if nil in some builds
  sink = CreateFrame("Frame", "EnhanceTBC_MinimapButtonSink", UIParent, "BackdropTemplate")
  sink:SetClampedToScreen(true)
  sink:SetMovable(true)
  sink:EnableMouse(false)
  sink:SetFrameStrata("MEDIUM")
  sink:SetFrameLevel(50)

  sink.drag = CreateFrame("Button", nil, sink, "BackdropTemplate")
  sink.drag:SetPoint("TOPLEFT", sink, "TOPLEFT", 0, 0)
  sink.drag:SetPoint("TOPRIGHT", sink, "TOPRIGHT", 0, 0)
  sink.drag:SetHeight(14)
  sink.drag:SetFrameLevel(sink:GetFrameLevel() + 200)
  sink.drag:SetFrameStrata("HIGH")
  sink.drag:EnableMouse(true)
  sink.drag:RegisterForClicks("AnyUp")
  sink.drag:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" then return end
    local db = GetDB()
    if db.locked then return end
    self._dragging = true
    self:GetParent():StartMoving()
  end)
  sink.drag:SetScript("OnMouseUp", function(self, button)
    local parent = self:GetParent()
    if button == "LeftButton" and self._dragging then
      self._dragging = false
      parent:StopMovingOrSizing()
      SaveFramePointToDB(parent, GetDB())
      return
    end
    if button == "RightButton" then
      mod:ShowMenu(parent)
    end
  end)


  sink.title = sink:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  sink.title:SetPoint("TOP", sink, "TOP", 0, -4)
  sink.title:SetText("Minimap")

  sink.bg = sink:CreateTexture(nil, "BACKGROUND")
  sink.bg:SetAllPoints(true)
  sink.bg:SetColorTexture(0, 0, 0, 0.35)

  sink.border = CreateFrame("Frame", nil, sink, "BackdropTemplate")
  sink.border:SetAllPoints(true)
  sink.border:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  sink.border:SetBackdropBorderColor(0.2, 0.8, 0.2, 0.8)

  sink.buttons = {}
  sink:Show()
end

local function IsBlacklisted(child)
  if not child or child == Minimap or child == MinimapCluster then return true end

  local n = child.GetName and child.GetName(child) or nil

  -- Always ignore these core minimap widgets
  if child == MinimapZoomIn or child == MinimapZoomOut then return true end
  if child == MinimapBorder or child == MinimapBorderTop then return true end
  if child == MinimapBackdrop then return true end
  if child == MiniMapTracking or child == MiniMapTrackingButton or child == MiniMapTrackingDropDown then return true end
  if child == MiniMapMailFrame then return true end
  -- GameTimeFrame removed from unconditional blacklist - now handled by includeCalendar option
  if child == MiniMapInstanceDifficulty or child == GuildInstanceDifficulty then return true end
  if child == MiniMapWorldMapButton then return true end
    -- Battleground / battlefield status buttons (the “weird icon”)
  if child == MiniMapBattlefieldFrame or child == BattlefieldMinimap or child == BattlefieldMinimapTab then return true end
  if child == QueueStatusMinimapButton then return true end -- this is the “does nothing” BG/queue status on some builds


  -- Name-based ignore
  if n then
    -- Exclude EnhanceTBC minimap button from sink
    if n:find("EnhanceTBC") or n:find("ETBC") then return true end

    -- Exclude Questie frames; allow only explicit minimap buttons
    if n:find("Questie") then
      local isQuestieButton = n:find("LibDBIcon") or n:find("MinimapButton") or n:find("MiniMapButton")
      if not isQuestieButton then return true end
    end
    
    if n:find("LibDBIcon") then
      -- We DO want to sink LibDBIcon buttons, so don't blacklist.
      return false
    end
    if n:find("MinimapBackdrop") or n:find("MinimapBorder") then return true end
    if n:find("MinimapToggleButton") or n:find("MiniMapTrackingButton") then return true end
    if n:find("MinimapToggleButton%.") then return true end
    if n:find("MinimapClusterBorderTop") or n:find("MinimapCluster") then return true end
    if n:find("Minimap%.xml") or n:find("Minimal%.xml") then return true end
    if n:find("TimerTracker") then return true end
    if n:find("MiniMapTracking") then return true end
    if n:find("MiniMapMail") then return true end
    if n:find("GameTimeFrame") then return true end
    if n:find("MiniMapInstanceDifficulty") or n:find("GuildInstanceDifficulty") then return true end
	if n:find("Battlefield") or n:find("Battleground") or n:find("MiniMapBattlefield") or n:find("QueueStatus") then
      return true
    end


  end

  return false
end

local function LooksLikeMinimapButton(child, db)
  if not child or collected[child] and collected[child].ignore then return false end
  if IsBlacklisted(child) then return false end

  -- Must be on/near minimap
  local parent = child:GetParent()
  if parent ~= Minimap and parent ~= MinimapCluster and parent ~= UIParent and parent ~= MinimapBackdrop then
    -- many buttons live under Minimap or MinimapCluster; some addons parent to UIParent but anchor to minimap
    -- allow UIParent if it is visually small
  end

  -- Some minimap "buttons" are actually Frames with textures; accept Button or Frame
  local t = child:GetObjectType()
  if t ~= "Button" and t ~= "Frame" then return false end

  local n = child.GetName and child.GetName(child) or ""
  if n == "" then
    -- Avoid scooping unnamed Blizzard objective pins or other map overlays.
    return false
  end
  if n ~= "" and n:find("^LibDBIcon") then
    return true
  end

  if child.IsMouseEnabled and not child:IsMouseEnabled() then
    return false
  end

  if t == "Frame" then
    local hasHandler = false
    if child.HasScript then
      hasHandler = child:HasScript("OnClick") or child:HasScript("OnMouseUp") or child:HasScript("OnMouseDown") or child:HasScript("OnDragStart")
    elseif child.GetScript then
      hasHandler = child:GetScript("OnClick") or child:GetScript("OnMouseUp") or child:GetScript("OnMouseDown") or child:GetScript("OnDragStart")
    end
    if not hasHandler then
      return false
    end
  end

  if not child:IsShown() and child:GetAlpha() == 0 then
    -- hidden at scan time, still might be a minimap button; allow
  end

  local w = child.GetWidth and child:GetWidth() or 0
  local h = child.GetHeight and child:GetHeight() or 0
  if w <= 0 or h <= 0 then
    -- some frames report 0 until shown; allow if it has regions
  end

  -- Heuristic size cap (minimap buttons are generally small)
  if (w > 0 and w > 60) or (h > 0 and h > 60) then
    return false
  end

  -- Optional includes for Blizzard widgets the user may want to keep on minimap
  if n:find("MinimapZoneText") or n:find("MinimapNorthTag") or n:find("MinimapPOI") then
    return false
  end
  if n ~= "" and (n:find("QuestPOI") or n:find("Objective")) then
    return false
  end

  if n ~= "" and n:find("Questie") then
    local isQuestieButton = n:find("LibDBIcon") or n:find("MinimapButton") or n:find("MiniMapButton")
    if not isQuestieButton then
      return false
    end
  end

  if t == "Frame" and n ~= "" then
    local isAddonButton = n:find("LibDBIcon") or n:find("MinimapButton") or n:find("MiniMapButton")
    if not isAddonButton then
      return false
    end
  end
  if (n == "QueueStatusMinimapButton" or n == "MiniMapLFGFrame") and not db.includeQueue then return false end
  if (n:find("MiniMapTracking") or n == "MiniMapTrackingButton") and not db.includeTracking then return false end
  if n == "GameTimeFrame" and not db.includeCalendar then return false end
  if n == "TimeManagerClockButton" and not db.includeClock then return false end
  if n == "MiniMapMailFrame" and not db.includeMail then return false end
  if (n == "MiniMapInstanceDifficulty" or n == "GuildInstanceDifficulty") and not db.includeDifficulty then return false end

  -- If it has no regions at all, it is unlikely a button
  if child.GetNumRegions and child:GetNumRegions() == 0 and child.GetNumChildren and child:GetNumChildren() == 0 then
    return false
  end

  return true
end

local function SnapshotFrame(frame)
  if collected[frame] then return end

  local info = {}
  info.parent = frame:GetParent()

  info.points = {}
  local n = frame:GetNumPoints() or 0
  for i = 1, n do
    local p, rel, rp, x, y = frame:GetPoint(i)
    info.points[i] = { p, rel, rp, x, y }
  end

  info.scale = frame:GetScale()
  info.strata = frame:GetFrameStrata()
  info.level = frame:GetFrameLevel()
  info.shown = frame:IsShown()

  collected[frame] = info
end

local function SafeSetPoint(frame, ...)
  if not frame then return end
  local fn = frame._etbcOrigSetPoint or frame.SetPoint
  if not fn then return end
  frame._etbcAllowSetPoint = true
  fn(frame, ...)
  frame._etbcAllowSetPoint = nil
end

local function IsLibDBIconButton(frame)
  if not frame or not frame.GetName then return false end
  local ok, name = pcall(function() return frame:GetName() end)
  return ok and type(name) == "string" and name:find("^LibDBIcon")
end

local function RestoreFrame(frame)
  local info = collected[frame]
  if not info then return end

  if frame._etbcOrigSetPoint then
    frame.SetPoint = frame._etbcOrigSetPoint
    frame._etbcOrigSetPoint = nil
  end
  frame._etbcInSink = nil
  frame._etbcAllowSetPoint = nil

  frame:ClearAllPoints()
  if info.points and #info.points > 0 then
    for i = 1, #info.points do
      local p = info.points[i]
      if p and p[1] then
        frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
      end
    end
  end

  if info.parent and frame:GetParent() ~= info.parent then
    frame:SetParent(info.parent)
  end

  if info.strata then frame:SetFrameStrata(info.strata) end
  if info.level then frame:SetFrameLevel(info.level) end
  if info.scale then frame:SetScale(info.scale) end

  if info.shown then
    frame:Show()
  else
    frame:Hide()
  end

  collected[frame] = nil
end

local function LayoutSink(db)
  if not sink then return end

  local size = db.buttonSize
  local pad = db.padding
  local cols = math.max(1, db.columns)

  -- Layout orderedButtons in a grid
  local count = #orderedButtons
  local rows = math.ceil(count / cols)
  rows = math.max(rows, 1)

  local width = pad + cols * size + (cols - 1) * pad + pad
  local height = 18 + pad + rows * size + (rows - 1) * pad + pad

  sink:SetScale(db.scale)
  sink:SetSize(width, height)

  if sink.drag then
    sink.drag:ClearAllPoints()
    sink.drag:SetPoint("TOPLEFT", sink, "TOPLEFT", 0, 0)
    sink.drag:SetPoint("TOPRIGHT", sink, "TOPRIGHT", 0, 0)
    sink.drag:SetHeight(14)
  end

  sink.title:SetShown(db.backdrop)
  sink.bg:SetShown(db.backdrop)
  sink.border:SetShown(db.backdrop)

  local startY = -18 - pad
  local dir = db.growDown and -1 or 1

  for i = 1, #orderedButtons do
    local b = orderedButtons[i]
    if b then
      b:ClearAllPoints()
      local idx = i - 1
      local col = idx % cols
      local row = math.floor(idx / cols)

      local x = pad + col * (size + pad)
      local y = startY + dir * (row * (size + pad))

      SafeSetPoint(b, "TOPLEFT", sink, "TOPLEFT", x, y)
      b:SetSize(size, size)

      -- Keep them clickable
      if b.EnableMouse then b:EnableMouse(true) end
      b:SetFrameStrata(sink:GetFrameStrata())
      b:SetFrameLevel(sink:GetFrameLevel() + 50)
      b:Show()
    end
  end
end

local function EnsureSinkVisible(db)
  if not sink or not UIParent then return end
  if not db then return end

  local left = sink:GetLeft()
  local right = sink:GetRight()
  local top = sink:GetTop()
  local bottom = sink:GetBottom()
  if not left or not right or not top or not bottom then return end

  local w = UIParent:GetWidth() or 0
  local h = UIParent:GetHeight() or 0
  if w <= 0 or h <= 0 then return end

  local offscreen = (right < 0) or (left > w) or (top < 0) or (bottom > h)
  if offscreen then
    db.sinkPoint = "TOPRIGHT"
    db.sinkRelPoint = "TOPRIGHT"
    db.sinkX = -200
    db.sinkY = -120
    SetFramePointFromDB(sink, db)
  end
end

local function ReparentToSink(frame)
  if not sink then return end
  if not frame or not frame.SetParent then return end

  SnapshotFrame(frame)

  -- Some buttons use special hit rects / highlight textures that look bad at weird scales
  if frame.SetHighlightTexture then
    -- keep existing; don't overwrite
  end

  if IsLibDBIconButton(frame) then
    if not frame._etbcOrigSetPoint and frame.SetPoint then
      frame._etbcOrigSetPoint = frame.SetPoint
      frame.SetPoint = function(self, ...)
        if self._etbcInSink and not self._etbcAllowSetPoint then return end
        return self._etbcOrigSetPoint(self, ...)
      end
    end
  end

  frame._etbcInSink = true
  frame:SetParent(sink)
  frame:ClearAllPoints()
  frame:SetScale(1.0)
end

local function ScanMinimapButtons(force)
  local db = GetDB()
  if not db.sinkEnabled then return end
  if not Minimap then return end

  local function SafeGetName(obj)
    if not obj or not obj.GetName then return "" end
    local ok, name = pcall(function() return obj:GetName() end)
    if ok and type(name) == "string" then return name end
    return ""
  end

  local now = GetTime()
  if not force and (now - lastScan) < (db.scanInterval or 2.0) then return end
  lastScan = now

  wipe(orderedButtons)

  -- Children directly on Minimap
  local kids = { Minimap:GetChildren() }
  for i = 1, #kids do
    local child = kids[i]
    if LooksLikeMinimapButton(child, db) then
      ReparentToSink(child)
      orderedButtons[#orderedButtons + 1] = child
    end
  end

  -- Also scan MinimapCluster (Blizzard places some there)
  if MinimapCluster and MinimapCluster.GetChildren then
    local kids2 = { MinimapCluster:GetChildren() }
    for i = 1, #kids2 do
      local child = kids2[i]
      if LooksLikeMinimapButton(child, db) then
        ReparentToSink(child)
        orderedButtons[#orderedButtons + 1] = child
      end
    end
  end

  local LibDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
  if LibDBIcon and LibDBIcon.GetButtonList and LibDBIcon.GetMinimapButton then
    local list = LibDBIcon:GetButtonList() or {}
    for i = 1, #list do
      local name = list[i]
      local btn = LibDBIcon:GetMinimapButton(name)
      if btn and LooksLikeMinimapButton(btn, db) then
        ReparentToSink(btn)
        orderedButtons[#orderedButtons + 1] = btn
      end
    end
  end

  local function IsAnchoredToMinimap(frame)
    if not frame or not frame.GetNumPoints or not frame.GetPoint then return false end
    local points = frame:GetNumPoints() or 0
    for i = 1, points do
      local _, rel = frame:GetPoint(i)
      if rel == Minimap or rel == MinimapCluster or rel == MinimapBackdrop then
        return true
      end
      local p = rel
      local hops = 0
      while p and hops < 6 do
        if p == Minimap or p == MinimapCluster or p == MinimapBackdrop then
          return true
        end
        p = p.GetParent and p:GetParent() or nil
        hops = hops + 1
      end
    end
    return false
  end

  -- Some LibDBIcon buttons parent to UIParent; include only if anchored to minimap.
  if UIParent and UIParent.GetChildren then
    local kids3 = { UIParent:GetChildren() }
    for i = 1, #kids3 do
      local child = kids3[i]
      local n = SafeGetName(child)
      if n ~= "" and n:find("^LibDBIcon") and IsAnchoredToMinimap(child) then
        ReparentToSink(child)
        orderedButtons[#orderedButtons + 1] = child
      end
    end
  end

  -- Sort by name to reduce shuffling (stable-ish)
  table.sort(orderedButtons, function(a, b)
    local an = SafeGetName(a)
    local bn = SafeGetName(b)
    return an < bn
  end)

  LayoutSink(db)
  EnsureSinkVisible(db)
end

local function SnapshotZoneText()
  local z = _G.MinimapZoneTextButton or _G.MinimapZoneText
  if not z or squareState.zonePoints then return end

  squareState.zoneParent = z:GetParent()
  squareState.zonePoints = {}
  local n = z:GetNumPoints() or 0
  for i = 1, n do
    local p, rel, rp, x, y = z:GetPoint(i)
    squareState.zonePoints[i] = { p, rel, rp, x, y }
  end
  squareState.zoneScale = z.GetScale and z:GetScale() or 1
end

local function RestoreZoneText()
  local z = _G.MinimapZoneTextButton or _G.MinimapZoneText
  if not z or not squareState.zonePoints then return end

  z:ClearAllPoints()
  for i = 1, #squareState.zonePoints do
    local p = squareState.zonePoints[i]
    if p and p[1] then
      z:SetPoint(p[1], p[2], p[3], p[4], p[5])
    end
  end

  if squareState.zoneParent and z:GetParent() ~= squareState.zoneParent then
    z:SetParent(squareState.zoneParent)
  end

  if z.SetScale and squareState.zoneScale then
    z:SetScale(squareState.zoneScale)
  end

  squareState.zonePoints = nil
  squareState.zoneParent = nil
end

local function HideSquareClusterArt(hide)
  -- Hide the cluster art/widgets but DO NOT hide Minimap itself.
  -- Based on Leatrix Plus implementation

  local function SuppressInSquare(frame)
    if not frame or frame._etbcSquareHideHook then return end
    frame._etbcSquareHideHook = true
    hooksecurefunc(frame, "Show", function()
      local db = GetDB()
      if db and db.squareMinimap then
        frame:Hide()
      end
    end)
  end

  if hide then
    -- Hide the default border (Leatrix Plus approach)
    if _G.MinimapBorder then
      _G.MinimapBorder:Hide()
    end
    
    -- Hide the North tag
    if _G.MinimapNorthTag then
      _G.MinimapNorthTag:Hide()
      -- Hook to prevent it from showing again
      if not _G.MinimapNorthTag.hideHookRegistered then
        hooksecurefunc(_G.MinimapNorthTag, "Show", function()
          _G.MinimapNorthTag:Hide()
        end)
        _G.MinimapNorthTag.hideHookRegistered = true
      end
    end
  else
    -- Restore the default border when square mode is disabled
    if _G.MinimapBorder then
      if _G.MinimapBorder.SetShown then
        _G.MinimapBorder:SetShown(true)
      elseif _G.MinimapBorder.Show then
        _G.MinimapBorder:Show()
      end
    end
  end

  -- Some builds have a cluster background texture/frame
  if _G.MinimapCluster and _G.MinimapCluster.Background and _G.MinimapCluster.Background.SetShown then
    _G.MinimapCluster.Background:SetShown(not hide)
  end

  local hideFrames = {
    _G.MinimapBorderTop,
    _G.MinimapBackdrop,
    _G.MiniMapWorldMapButton,
    _G.MinimapCluster and _G.MinimapCluster.BorderTop,
  }

  for _, f in ipairs(hideFrames) do
    if f and f.SetShown then
      f:SetShown(not hide)
    elseif f and f.Show and f.Hide then
      if hide then f:Hide() else f:Show() end
    end

    if hide then
      SuppressInSquare(f)
    end
  end
  
  -- GameTimeFrame - only hide in square mode
  -- When NOT in square mode, let them show normally
  if hide then
    -- Hide time/calendar in square mode
    if _G.GameTimeFrame then
      if _G.GameTimeFrame.Hide then _G.GameTimeFrame:Hide() end
      if _G.GameTimeFrame.SetAlpha then _G.GameTimeFrame:SetAlpha(0) end
    end
  else
    -- Restore time/calendar when not in square mode
    if _G.GameTimeFrame then
      if _G.GameTimeFrame.Show then _G.GameTimeFrame:Show() end
      if _G.GameTimeFrame.SetAlpha then _G.GameTimeFrame:SetAlpha(1) end
    end
  end

  -- Day/Night indicator (varies by client)
  local dayNight = _G.DayNightFrame or (_G.MinimapCluster and _G.MinimapCluster.IndicatorFrame)
  if dayNight then
    if dayNight.SetShown then
      dayNight:SetShown(not hide)
    elseif dayNight.Show and dayNight.Hide then
      if hide then dayNight:Hide() else dayNight:Show() end
    end
  end
end

local function PlaceZoneTextAboveSquare()
  -- Position zone text for square minimap
  -- Based on Leatrix Plus implementation
  local z = _G.MinimapZoneTextButton or _G.MinimapZoneText
  if not z then return end

  SnapshotZoneText()

  -- Reparent elements like Leatrix Plus does
  if _G.MinimapBorderTop then
    _G.MinimapBorderTop:SetParent(Minimap)
  end
  if _G.MinimapZoneTextButton then
    _G.MinimapZoneTextButton:SetParent(_G.MinimapBackdrop or Minimap)
  end

  -- Hide the border top in square mode
  if _G.MinimapBorderTop then
    _G.MinimapBorderTop:Hide()
  end

  -- Position zone text at the top of the minimap
  z:ClearAllPoints()
  z:SetPoint("TOP", Minimap, "TOP", 0, 0)
  z:SetFrameLevel(100)

  -- Reduce the click area by 30 pixels from left and right side (Leatrix Plus pattern)
  if z.SetHitRectInsets then
    z:SetHitRectInsets(30, 30, 0, 0)
  end
end

local function PositionBlizzardMinimapButtons(db)
  -- Position Blizzard minimap buttons for both square and round minimap layouts.
  local mm = Minimap
  if not mm then return end

  local isSquare = db and db.squareMinimap
  local trackingScale = isSquare and 0.75 or 1.0
  local queueScale = isSquare and 0.75 or 1.0
  local trackingX, trackingY = 2, 2
  local queuePoint = "TOPRIGHT"
  local queueX, queueY = -2, -2

  local function ApplyMinimapAnchor(btn, point, x, y, scale)
    if not btn or not Minimap then return end
    if btn._etbcAnchoring then return end
    btn._etbcAnchoring = true
    btn:SetParent(Minimap)
    btn:ClearAllPoints()
    btn:SetPoint(point, Minimap, point, x, y)
    if scale then btn:SetScale(scale) end
    btn._etbcAnchoring = false
  end

  local function HookMinimapPosition(btn, point, x, y, scale)
    if not btn or btn._etbcMinimapHooked then return end
    btn._etbcMinimapHooked = true
    hooksecurefunc(btn, "Show", function()
      local db2 = GetDB()
      if not Minimap or not db2 then return end
      ApplyMinimapAnchor(btn, point, x, y, scale)
    end)
  end
  
  -- Tracking button - bottom left corner (TBC Anniversary standard)
  local trackingButton = _G.MiniMapTrackingButton or _G.MiniMapTracking
  if trackingButton then
    trackingButton:SetParent(mm)
    trackingButton:SetScale(trackingScale)
    if trackingButton.SetFrameLevel then
      trackingButton:SetFrameLevel(3)
    end
    trackingButton:ClearAllPoints()
    trackingButton:SetPoint("BOTTOMLEFT", mm, "BOTTOMLEFT", trackingX, trackingY)
    HookMinimapPosition(trackingButton, "BOTTOMLEFT", trackingX, trackingY, trackingScale)

    local trackingIcon = trackingButton.icon or trackingButton.Icon or _G.MiniMapTrackingIcon
    if trackingIcon then
      if trackingIcon.SetParent then
        trackingIcon:SetParent(trackingButton)
      end
      trackingIcon:ClearAllPoints()
      trackingIcon:SetPoint("CENTER", trackingButton, "CENTER", 0, 0)
      if trackingIcon.SetSize then
        trackingIcon:SetSize(14, 14)
      end
      if trackingIcon.SetDrawLayer then
        trackingIcon:SetDrawLayer("BACKGROUND", 0)
      end
      if trackingIcon.SetAlpha then
        trackingIcon:SetAlpha(1)
      end
      if trackingIcon.SetAlpha then
        trackingIcon:SetAlpha(1)
      end
      if trackingIcon.Show then
        trackingIcon:Show()
      end
    end

    local border = _G.MiniMapTrackingButtonBorder or trackingButton.Border or trackingButton.border
    if border and border.SetDrawLayer then
      border:SetDrawLayer("OVERLAY", 7)
    end
    if border and border.SetFrameLevel and trackingButton.GetFrameLevel then
      if border.SetParent then
        border:SetParent(trackingButton)
      end
      border:SetFrameLevel(trackingButton:GetFrameLevel() + 10)
    end
    if border and border.Show then
      border:Show()
    end
  end
  
  -- Mail button - top left corner
  local mailButton = _G.MiniMapMailFrame
  if mailButton then
    mailButton:SetParent(mm)
    mailButton:SetScale(0.75)
    mailButton:ClearAllPoints()
    mailButton:SetPoint("TOPLEFT", mm, "TOPLEFT", -19, 10)
    if mailButton.Show then mailButton:Show() end
  end
  
  -- LFG/Queue button - top right corner
  local queueButton = _G.MiniMapLFGFrame or _G.QueueStatusMinimapButton or _G.MiniMapBattlefieldFrame
  if queueButton then
    ApplyMinimapAnchor(queueButton, queuePoint, queueX, queueY, queueScale)
    HookMinimapPosition(queueButton, queuePoint, queueX, queueY, queueScale)
    if not queueButton._etbcSetPointHooked then
      queueButton._etbcSetPointHooked = true
      hooksecurefunc(queueButton, "SetPoint", function(self)
        if self._etbcAnchoring then return end
        local db2 = GetDB()
        local isSq = db2 and db2.squareMinimap
        local qx, qy = -2, -2
        local qs = isSq and 0.75 or 1.0
        ApplyMinimapAnchor(self, queuePoint, qx, qy, qs)
      end)
    end
    if queueButton.Show then queueButton:Show() end
  end

  local lfgFrame = _G.LFGMinimapFrame
  if lfgFrame then
    ApplyMinimapAnchor(lfgFrame, queuePoint, queueX, queueY, queueScale)
    HookMinimapPosition(lfgFrame, queuePoint, queueX, queueY, queueScale)
    if lfgFrame.SetSize then
      lfgFrame:SetSize(32, 32)
    end
    if lfgFrame.SetFrameLevel then
      lfgFrame:SetFrameLevel(8)
    end
    if not lfgFrame._etbcSetPointHooked then
      lfgFrame._etbcSetPointHooked = true
      hooksecurefunc(lfgFrame, "SetPoint", function(self)
        if self._etbcAnchoring then return end
        ApplyMinimapAnchor(self, queuePoint, queueX, queueY, queueScale)
      end)
    end
    if lfgFrame.Show then lfgFrame:Show() end

    local lfgIcon = _G.LFGMinimapFrameIcon or _G.LFGMinimapFrameIconTexture
    if lfgIcon and lfgIcon.SetPoint then
      if lfgIcon.SetParent then lfgIcon:SetParent(lfgFrame) end
      lfgIcon:ClearAllPoints()
      lfgIcon:SetPoint("CENTER", lfgFrame, "CENTER", 0, 0)
      if lfgIcon.SetSize and lfgFrame.GetSize then
        local w, h = lfgFrame:GetSize()
        if w and h and w > 0 and h > 0 then
          lfgIcon:SetSize(w, h)
        end
      end
    end

    local lfgBorder = _G.LFGMinimapFrameBorder
    if lfgBorder and lfgBorder.SetPoint then
      if lfgBorder.SetParent then lfgBorder:SetParent(lfgFrame) end
      lfgBorder:ClearAllPoints()
      lfgBorder:SetPoint("CENTER", lfgFrame, "CENTER", 0, 0)
      if lfgBorder.SetSize and lfgFrame.GetSize then
        local w, h = lfgFrame:GetSize()
        if w and h and w > 0 and h > 0 then
          lfgBorder:SetSize(w, h)
        end
      end
    end
  end
  
  -- Instance difficulty - top left corner (like Leatrix Plus)
  local difficultyButton = _G.MiniMapInstanceDifficulty
  if difficultyButton then
    difficultyButton:SetParent(mm)
    difficultyButton:ClearAllPoints()
    difficultyButton:SetPoint("TOPLEFT", mm, "TOPLEFT", -21, 10)
    difficultyButton:SetScale(0.75)
    difficultyButton:SetFrameLevel(4)
  end
  
  -- Zoom buttons can be hidden or kept minimal
  local zoomIn = _G.MinimapZoomIn
  local zoomOut = _G.MinimapZoomOut
  if zoomIn and zoomOut then
    -- Keep them but make them less visible
    zoomIn:ClearAllPoints()
    zoomIn:SetPoint("TOPRIGHT", mm, "TOPRIGHT", 2, -58)
    
    zoomOut:ClearAllPoints()
    zoomOut:SetPoint("TOPRIGHT", mm, "TOPRIGHT", 2, -78)
  end

  local clockButton = _G.TimeManagerClockButton
  if clockButton then
    clockButton:SetParent(mm)
    clockButton:ClearAllPoints()
    clockButton:SetPoint("BOTTOM", mm, "BOTTOM", 0, 2)
    clockButton:SetScale(0.8)
    clockButton:SetFrameLevel(4)
    if clockButton.Show then clockButton:Show() end
  end

  if not isSquare then
    local zone = _G.MinimapZoneTextButton or _G.MinimapZoneText
    if zone then
      if _G.MinimapBackdrop and zone:GetParent() ~= _G.MinimapBackdrop then
        zone:SetParent(_G.MinimapBackdrop)
      end
      if zone.Show then zone:Show() end
    end
  end
end

local function EnableMinimapMouseZoom()
  -- Enable mouse wheel scrolling on minimap to zoom in/out
  if not Minimap then return end
  
  -- Check if script is already set to avoid duplicate hooks
  if isZoomHooked or Minimap:GetScript("OnMouseWheel") then return end
  isZoomHooked = true
  
  Minimap:EnableMouseWheel(true)
  Minimap:SetScript("OnMouseWheel", function(self, delta)
    if delta > 0 then
      -- Scroll up = zoom in
      Minimap_ZoomIn()
    elseif delta < 0 then
      -- Scroll down = zoom out
      Minimap_ZoomOut()
    end
  end)
end

local function SetSquareMinimap(db)
  -- Square minimap implementation forked from Leatrix Plus
  if not Minimap then return end

  -- Snapshot originals once
  if not squareState.saved then
    squareState.saved = true
    squareState.minimapScale = Minimap.GetScale and Minimap:GetScale() or 1
    squareState.minimapMask = Minimap.GetMaskTexture and Minimap:GetMaskTexture() or nil
    squareState.minimapSize = { Minimap:GetWidth() or 140, Minimap:GetHeight() or 140 }
  end

  if db.squareMinimap then
    -- Use SetSize approach from Leatrix Plus instead of SetScale
    local size = db.squareSize or 140
    if size < 140 then size = 140 end
    if size > 560 then size = 560 end

    -- Set square mask texture (Leatrix Plus approach)
    Minimap:SetMaskTexture(SQUARE_MASK_TEXTURE)
    
    -- Set minimap size directly (Leatrix Plus uses this instead of scaling)
    if Minimap.SetSize then
      Minimap:SetSize(size, size)
    end
    
    -- Refresh minimap by toggling zoom (Leatrix Plus pattern)
    -- This forces the minimap to redraw with the new size
    if Minimap.GetZoom and Minimap.SetZoom then
      local currentZoom = Minimap:GetZoom()
      if currentZoom ~= MAX_ZOOM_LEVEL then
        Minimap:SetZoom(currentZoom + 1)
        Minimap:SetZoom(currentZoom)
      else
        Minimap:SetZoom(currentZoom - 1)
        Minimap:SetZoom(currentZoom)
      end
    end

    -- Hide default cluster art and borders (Leatrix Plus pattern)
    HideSquareClusterArt(true)

    -- Position zone text for square minimap
    PlaceZoneTextAboveSquare()
    
    -- Position Blizzard minimap buttons for square layout
    PositionBlizzardMinimapButtons(db)
    
    -- Refresh buttons after UI settles (Leatrix Plus uses a single 0.1 delay)
    C_Timer.After(0.1, function()
      if db.squareMinimap then
        PositionBlizzardMinimapButtons(GetDB())
      end
    end)
    
    -- Enable mouse wheel zoom
    EnableMinimapMouseZoom()

  else
    -- Restore round minimap
    -- Restore original mask
    if squareState.minimapMask then
      Minimap:SetMaskTexture(squareState.minimapMask)
    else
      -- Use default round mask (Leatrix Plus fallback)
      Minimap:SetMaskTexture(ROUND_MASK_TEXTURE)
    end

    -- Restore original size
    if squareState.minimapSize and Minimap.SetSize then
      Minimap:SetSize(squareState.minimapSize[1], squareState.minimapSize[2])
    end

    -- Restore cluster art
    HideSquareClusterArt(false)
    RestoreZoneText()
  end
  
  -- Override GetMinimapShape for addon compatibility (Leatrix Plus pattern)
  _G.GetMinimapShape = function()
    return db.squareMinimap and "SQUARE" or "ROUND"
  end
end

local function ApplyCustomDifficultyIcon(db)
  if not db.customDifficultyIcon then return end

  -- These frames exist in many classic builds; guard everything
  local f = _G.MiniMapInstanceDifficulty
  if f and f.Border and f.Instance then
    -- Make it cleaner / less noisy
    f.Border:SetAlpha(0.65)
    f.Instance:SetAlpha(1.0)
  end

  local g = _G.GuildInstanceDifficulty
  if g and g.Border and g.Instance then
    g.Border:SetAlpha(0.65)
    g.Instance:SetAlpha(1.0)
  end
end

local function ApplyHides(db)
  local function HideFrame(frame)
    if not frame or not frame.Hide then return end
    frame:Hide()
    if frame.Show and not frame._etbcHideHooked then
      frame._etbcHideHooked = true
      hooksecurefunc(frame, "Show", function()
        local db2 = GetDB()
        if db2 and db2.hideMinimapToggleButton then
          frame:Hide()
        end
      end)
    end
  end

  -- Hide EnhanceTBC minimap toggle button (if you have one)
  if db.hideMinimapToggleButton then
    local b = _G.EnhanceTBC_MinimapButton or _G.ETBC_MinimapButton or _G.EnhanceTBCMinimapButton
    if b and b.Hide then b:Hide() end

    -- Hide Blizzard minimap top bar/toggles
    HideFrame(_G.MinimapCluster and _G.MinimapCluster.BorderTop)
    HideFrame(_G.MinimapToggleButton)
    HideFrame(_G.MinimapToggleButton and _G.MinimapToggleButton.Icon)
  end

  -- Always hide the battlefield frame if it exists (UI clutter)
  HideFrame(_G.MiniMapBattlefieldFrame)
  HideFrame(_G.BattlefieldMinimap)
  HideFrame(_G.BattlefieldMinimapTab)

  -- Bags bar
  if db.hideBagsBar then
    local bars = {
      _G.MicroButtonAndBagsBar,
      _G.MainMenuBarBackpackButton,
      _G.CharacterBag0Slot, _G.CharacterBag1Slot, _G.CharacterBag2Slot, _G.CharacterBag3Slot,
      _G.KeyRingButton, -- if present
    }
    for _, f in ipairs(bars) do
      if f and f.Hide then f:Hide() end
    end
  end

  -- Micro menu
  if db.hideMicroMenu then
    local micro = {
      _G.MicroButtonAndBagsBar,
      _G.CharacterMicroButton, _G.SpellbookMicroButton, _G.TalentMicroButton,
      _G.QuestLogMicroButton, _G.SocialsMicroButton, _G.WorldMapMicroButton,
      _G.MainMenuMicroButton, _G.HelpMicroButton,
    }
    for _, f in ipairs(micro) do
      if f and f.Hide then f:Hide() end
    end
  end

  -- Quick Join Toast button (exists in some classic clients)
  if db.hideQuickJoinToast then
    local q = _G.QuickJoinToastButton
    if q and q.Hide then q:Hide() end
  end

  -- Raid Tools (CompactRaidFrameManager) when in party (not raid)
  if db.hideRaidToolsInParty then
    local mgr = _G.CompactRaidFrameManager
    if mgr and mgr.Hide then
      local inRaid = IsInRaid and IsInRaid() or false
      local inGroup = IsInGroup and IsInGroup() or false
      if inGroup and not inRaid then
        mgr:Hide()
      end
    end
  end
end

local function ApplyLandingButtons(db)
  if not db.landingButtons then return end

  for name, enabled in pairs(db.landingButtons) do
    local f = _G[name]
    if f and f.SetShown then
      f:SetShown(enabled and true or false)
    elseif f and f.Show and f.Hide then
      if enabled then f:Show() else f:Hide() end
    end
  end
end

-- ---------------------------
-- Quick spec / loot switching
-- ---------------------------
local function CanChangeLoot()
  return not InCombatLockdown or not InCombatLockdown()
end

local function SetLootToDB(db)
  if not CanChangeLoot() then
    Print("Can't change loot settings in combat.")
    return
  end

  local method = db.defaultLootMethod
  local threshold = tonumber(db.defaultLootThreshold) or 2

  if method and SetLootMethod then
    -- group, freeforall, master, roundrobin, needbeforegreed
    -- For master loot, master looter must be set; we won't force that here.
    SetLootMethod(method)
  end
  if SetLootThreshold then
    SetLootThreshold(threshold)
  end
end

local function TrySwitchSpec(group)
  if not group then return end
  if InCombatLockdown and InCombatLockdown() then
    Print("Can't switch spec in combat.")
    return
  end

  -- Dual spec exists in later expansions; if the function doesn't exist, just message.
  if SetActiveTalentGroup then
    SetActiveTalentGroup(group)
  else
    Print("Spec switching isn't available on this client/ruleset.")
  end
end

-- -------------------------------------------
-- Right-click menus for landing page buttons
-- -------------------------------------------
local function HookLandingPageRightClick(frame, displayName)
  if not frame or frame.__ETBC_LandingHooked then return end
  frame.__ETBC_LandingHooked = true

  frame:HookScript("OnMouseUp", function(self, btn)
    if btn ~= "RightButton" then return end
    mod:ShowMenu(self, displayName)
  end)
end

-- ---------------
-- Dropdown / Menu
-- ---------------
local function MenuInit(self, level)
  local db = GetDB()
  local info = UIDropDownMenu_CreateInfo()

  if level == 1 then
    info.isTitle = true
    UIDropDownMenu_AddButton(info, level)
    
    info = UIDropDownMenu_CreateInfo()
    info.text = "Show Button Sink"
    info.checked = db.sinkEnabled and true or false
    info.func = function()
      db.sinkEnabled = not db.sinkEnabled
      Apply()
    end
    UIDropDownMenu_AddButton(info, level)

    info = UIDropDownMenu_CreateInfo()
    info.notCheckable = true
    info.text = db.locked and "Unlock Sink" or "Lock Sink"
    info.func = function()
      db.locked = not db.locked
      -- No need for full Apply() - lock state only affects drag behavior which is checked in OnDragStart
    end
    UIDropDownMenu_AddButton(info, level)

    info = UIDropDownMenu_CreateInfo()
    info.notCheckable = true
    info.text = "Rescan Minimap Buttons"
    info.func = function()
      ScanMinimapButtons(true)
    end
    UIDropDownMenu_AddButton(info, level)

    if db.quickEnabled then
      info = UIDropDownMenu_CreateInfo()
      info.notCheckable = true
      info.text = "Quick: Loot Settings"
      info.hasArrow = true
      info.value = "LOOT"
      UIDropDownMenu_AddButton(info, level)

      info = UIDropDownMenu_CreateInfo()
      info.notCheckable = true
      info.text = "Quick: Spec Switch"
      info.hasArrow = true
      info.value = "SPEC"
      UIDropDownMenu_AddButton(info, level)
    end

    info = UIDropDownMenu_CreateInfo()
    info.notCheckable = true
    info.text = "Landing Page Buttons"
    info.hasArrow = true
    info.value = "LANDING"
    UIDropDownMenu_AddButton(info, level)

    info = UIDropDownMenu_CreateInfo()
    info.notCheckable = true
    info.text = "Close"
    info.func = function() CloseDropDownMenus() end
    UIDropDownMenu_AddButton(info, level)

  elseif level == 2 then
    local v = UIDROPDOWNMENU_MENU_VALUE

    if v == "LOOT" then
      local methods = {
        { "Group Loot", "group" },
        { "Free For All", "freeforall" },
        { "Round Robin", "roundrobin" },
        { "Need Before Greed", "needbeforegreed" },
        { "Master Loot", "master" },
      }

      info = UIDropDownMenu_CreateInfo()
      info.isTitle = true
      info.notCheckable = true
      info.text = "Loot Method"
      UIDropDownMenu_AddButton(info, level)

      for _, m in ipairs(methods) do
        local label, key = m[1], m[2]
        info = UIDropDownMenu_CreateInfo()
        info.text = label
        info.checked = (db.defaultLootMethod == key)
        info.func = function()
          db.defaultLootMethod = key
          SetLootToDB(db)
        end
        UIDropDownMenu_AddButton(info, level)
      end

      UIDropDownMenu_AddSeparator(level)

      info = UIDropDownMenu_CreateInfo()
      info.isTitle = true
      info.notCheckable = true
      info.text = "Loot Threshold"
      UIDropDownMenu_AddButton(info, level)

      local thresholds = {
        { "Uncommon (Green)", 2 },
        { "Rare (Blue)", 3 },
        { "Epic (Purple)", 4 },
      }
      for _, t in ipairs(thresholds) do
        info = UIDropDownMenu_CreateInfo()
        info.text = t[1]
        info.checked = (tonumber(db.defaultLootThreshold) == t[2])
        info.func = function()
          db.defaultLootThreshold = t[2]
          SetLootToDB(db)
        end
        UIDropDownMenu_AddButton(info, level)
      end

      UIDropDownMenu_AddSeparator(level)

      info = UIDropDownMenu_CreateInfo()
      info.notCheckable = true
      info.text = "Apply Now"
      info.func = function() SetLootToDB(db) end
      UIDropDownMenu_AddButton(info, level)

    elseif v == "SPEC" then
      info = UIDropDownMenu_CreateInfo()
      info.isTitle = true
      info.notCheckable = true
      info.text = "Spec Switch (if available)"
      UIDropDownMenu_AddButton(info, level)

      info = UIDropDownMenu_CreateInfo()
      info.text = "Spec 1"
      info.notCheckable = true
      info.func = function() TrySwitchSpec(1) end
      UIDropDownMenu_AddButton(info, level)

      info = UIDropDownMenu_CreateInfo()
      info.text = "Spec 2"
      info.notCheckable = true
      info.func = function() TrySwitchSpec(2) end
      UIDropDownMenu_AddButton(info, level)

    elseif v == "LANDING" then
      local known = {
        { "ExpansionLandingPageMinimapButton", "Expansion Landing" },
        { "GarrisonLandingPageMinimapButton", "Garrison Landing" },
        { "QueueStatusMinimapButton", "Queue Status" },
      }

      info = UIDropDownMenu_CreateInfo()
      info.isTitle = true
      info.notCheckable = true
      info.text = "Show/Hide"
      UIDropDownMenu_AddButton(info, level)

      for _, item in ipairs(known) do
        local name, label = item[1], item[2]
        local f = _G[name]
        if f then
          info = UIDropDownMenu_CreateInfo()
          info.text = label
          info.checked = db.landingButtons[name] and true or false
          info.func = function()
            db.landingButtons[name] = not db.landingButtons[name]
            ApplyLandingButtons(db)
          end
          UIDropDownMenu_AddButton(info, level)
        end
      end
    end
  end
end

function mod:ShowMenu(anchor, displayName)
  EnsureDropdown()
  CloseDropDownMenus()

  UIDropDownMenu_Initialize(dropdown, MenuInit, "MENU")

  -- anchor can be nil; use sink/minimap
  local a = anchor or sink or Minimap or UIParent
  ToggleDropDownMenu(1, nil, dropdown, a, 0, 0)
end

-- Helper functions for sink visibility control
function mod:ToggleSinkVisibility()
  local db = GetDB()
  
  -- Toggle the persisted sinkEnabled flag
  db.sinkEnabled = not db.sinkEnabled
  
  -- Re-apply to ensure sink visibility follows the persisted flag
  self:Apply()
end

function mod:IsSinkShown()
  if not sink then return false end
  return sink:IsShown()
end

-- ------------
-- Enable/Stop
-- ------------
function mod:Apply()
  local db = GetDB()
  if not db.enabled then return end

  EnsureDriver()
  EnsureSink()
  SetFramePointFromDB(sink, db)

  if db.sinkEnabled then
    sink:Show()
  else
    sink:Hide()
  end
  sink:EnableMouse(false)
  if db.sinkEnabled then
    EnsureSinkVisible(db)
  end

  ApplyHides(db)
  ApplyLandingButtons(db)
  SetSquareMinimap(db)
  PositionBlizzardMinimapButtons(db)
    -- Re-apply square after UI settles (cluster sometimes resets scale)
    -- Multiple timers to ensure persistence
  if db.squareMinimap then
    C_Timer.After(0.10, function() SetSquareMinimap(GetDB()) end)
    C_Timer.After(0.30, function() SetSquareMinimap(GetDB()) end)
    C_Timer.After(0.50, function() SetSquareMinimap(GetDB()) end)
    C_Timer.After(1.00, function() SetSquareMinimap(GetDB()) end)
    C_Timer.After(2.00, function() SetSquareMinimap(GetDB()) end)
  end
  ApplyCustomDifficultyIcon(db)

  -- Hook right-click on landing page buttons if they exist
  HookLandingPageRightClick(_G.ExpansionLandingPageMinimapButton, "Expansion Landing")
  HookLandingPageRightClick(_G.GarrisonLandingPageMinimapButton, "Garrison Landing")
  
  -- Hook modified right-click on Minimap to show sink menu (Shift+RightClick to avoid conflicting with Blizzard's tracking dropdown)
  if Minimap and not isMinimapRightClickHooked then
    isMinimapRightClickHooked = true
    Minimap:HookScript("OnMouseUp", function(self, btn)
      -- Only handle right-clicks when addon/module are enabled
      if btn ~= "RightButton" or not IsShiftKeyDown() then
        return
      end

      local db = GetDB()
      if not db or not db.enabled then
        return
      end

      -- Optional guard for general addon enabled state (nil-safe)
      if ETBC and ETBC.db and ETBC.db.profile and ETBC.db.profile.general then
        local generalEnabled = ETBC.db.profile.general.enabled
        if generalEnabled == false then
          return
        end
      end

      mod:ShowMenu(self)
    end)
  end

  -- First scan
  if db.sinkEnabled then
    ScanMinimapButtons(true)
    if sink and not sink:IsShown() then
      sink:Show()
    end
  end

  -- Event driver
  driver:Show()
  driver:SetScript("OnEvent", function(_, event, ...)
    if not GetDB().enabled then return end

    if event == "PLAYER_ENTERING_WORLD" or event == "ADDON_LOADED" or event == "UPDATE_PENDING_MAIL" then
      ApplyHides(GetDB())
      ApplyLandingButtons(GetDB())
      ApplyCustomDifficultyIcon(GetDB())
      if GetDB().sinkEnabled then
        -- Some buttons load late; rescan shortly after
        C_Timer.After(0.25, function() ScanMinimapButtons(true) end)
        C_Timer.After(1.25, function() ScanMinimapButtons(true) end)
      end
    elseif event == "GROUP_ROSTER_UPDATE" then
      ApplyHides(GetDB())
    end
  end)

  driver:UnregisterAllEvents()
  driver:RegisterEvent("PLAYER_ENTERING_WORLD")
  driver:RegisterEvent("ADDON_LOADED")
  driver:RegisterEvent("GROUP_ROSTER_UPDATE")
  driver:RegisterEvent("UPDATE_PENDING_MAIL")

  -- Optional auto-scan ticker via OnUpdate (simple + cheap)
  -- Also monitors square minimap to prevent cluster resets
  local lastSquareCheck = 0
  local lastButtonCheck = 0
  local lastButtonLayoutCheck = 0
  driver:SetScript("OnUpdate", function(_, elapsed)
    local db2 = GetDB()
    if not db2.enabled then return end
    
    -- Auto-scan minimap buttons
    if db2.sinkEnabled and db2.autoScan then
      ScanMinimapButtons(false)
    end
    
    -- Monitor and enforce square minimap every 2 seconds
    if db2.squareMinimap and Minimap then
      local now = GetTime()
      if now - lastSquareCheck > 2.0 then
        lastSquareCheck = now
        local needsRefresh = false
        
        -- Check if mask has been reset (round mask)
        if Minimap.GetMaskTexture then
          local currentMask = Minimap:GetMaskTexture()
          if currentMask and currentMask ~= SQUARE_MASK_TEXTURE then
            -- Mask was reset, reapply
            Minimap:SetMaskTexture(SQUARE_MASK_TEXTURE)
            needsRefresh = true
          end
        end
        
        -- Check if size has been reset (Leatrix Plus also monitors size)
        if Minimap.GetWidth and Minimap.SetSize then
          local currentWidth = Minimap:GetWidth()
          local targetSize = db2.squareSize or 140
          -- Allow small tolerance to avoid constant re-application
          if currentWidth and math.abs(currentWidth - targetSize) > SIZE_CHECK_TOLERANCE then
            -- Size was reset, reapply
            Minimap:SetSize(targetSize, targetSize)
            needsRefresh = true
          end
        end
        
        if needsRefresh then
          HideSquareClusterArt(true)
        end
      end
      
      -- Reposition buttons frequently to counter Blizzard's repositioning
      if now - lastButtonCheck > 0.5 then
        lastButtonCheck = now
        PositionBlizzardMinimapButtons(db2)
      end
    end

    -- Re-apply button layout regularly (round and square)
    if Minimap then
      local now = GetTime()
      if now - lastButtonLayoutCheck > 2.0 then
        lastButtonLayoutCheck = now
        PositionBlizzardMinimapButtons(db2)
      end
    end
  end)
end

function mod:Start()
  local db = GetDB()
  if not db.enabled then return end
  self:Apply()
end

function mod:Stop()
  local db = GetDB()

  if driver then
    driver:SetScript("OnEvent", nil)
    driver:SetScript("OnUpdate", nil)
    driver:UnregisterAllEvents()
    driver:Hide()
  end

  -- Restore collected buttons to their original parents/points
  for frame, _ in pairs(collected) do
    if frame then
      RestoreFrame(frame)
    end
  end
  wipe(orderedButtons)

-- Restore minimap shape/cluster/zone text if we were in square mode
  if squareState and squareState.saved then
    local db2 = GetDB()
    db2.squareMinimap = false -- ensure restore path
    SetSquareMinimap(db2)
  end

  if sink then sink:Hide() end
end

-- ApplyBus integration (so /etbc reset and NotifyAll refresh this module)
if ETBC.ApplyBus and ETBC.ApplyBus.Register then
  ETBC.ApplyBus:Register("minimapplus", function()
    local db = GetDB()
    if db.enabled then
      mod:Start()
    else
      mod:Stop()
    end
  end)

  ETBC.ApplyBus:Register("general", function()
    local db = GetDB()
    if ETBC.db and ETBC.db.profile and ETBC.db.profile.general
      and ETBC.db.profile.general.enabled and db.enabled then
      mod:Start()
    else
      mod:Stop()
    end
  end)
end

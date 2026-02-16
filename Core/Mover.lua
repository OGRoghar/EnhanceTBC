-- Core/Mover.lua
-- EnhanceTBC - Mover system (global lock/unlock, grid, snap, saved anchors)
--
-- How modules use it:
--   ETBC.Mover:Register("AurasAnchor", frame, { default = { point="CENTER", rel="UIParent", relPoint="CENTER", x=0, y=0 } })
--   ETBC.Mover:Apply("AurasAnchor") -- optional; ApplyBus will also re-apply
--
-- Saved data:
--   ETBC.db.profile.mover.frames[key] = { point, rel, relPoint, x, y }
--
-- Slash:
--   /etbc unlock   /etbc lock   /etbc move (toggle)   /etbc reset <key|all>
--
-- Notes:
-- - Safe: does not attempt to move protected frames in combat if onlyOutOfCombat is enabled.
-- - No heavy OnUpdate: only uses OnUpdate when unlocked for dragging label refresh (very light).

local ADDON_NAME, ETBC = ...
local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceTBC")
ETBC.Mover = ETBC.Mover or {}
local M = ETBC.Mover

local driver
local gridFrame
local gridV = {}
local gridH = {}

local registry = {}   -- key -> { frame, opts, handle }
local handles = {}    -- key -> handle frame

local function EnsureDriver()
  if driver then return end
  driver = CreateFrame("Frame", "EnhanceTBC_MoverDriver", UIParent)
  driver:Hide()
end

local function GetDB()
  ETBC.db.profile.mover = ETBC.db.profile.mover or {}
  local db = ETBC.db.profile.mover

  if db.enabled == nil then db.enabled = true end
  if db.unlocked == nil then db.unlocked = false end

  if db.snapToGrid == nil then db.snapToGrid = true end
  if db.gridSize == nil then db.gridSize = 8 end
  if db.showGrid == nil then db.showGrid = true end
  if db.gridAlpha == nil then db.gridAlpha = 0.25 end

  if db.handleAlpha == nil then db.handleAlpha = 0.85 end
  if db.handleScale == nil then db.handleScale = 1.0 end
  if db.showFrameNames == nil then db.showFrameNames = true end

  if db.onlyOutOfCombat == nil then db.onlyOutOfCombat = true end
  if db.clampToScreen == nil then db.clampToScreen = true end
  if db.nudge == nil then db.nudge = 1 end

  db.frames = db.frames or {}

  return db
end

local function InCombat()
  if InCombatLockdown and InCombatLockdown() then return true end
  if UnitAffectingCombat then return UnitAffectingCombat("player") and true or false end
  return false
end

local function RoundToGrid(v, grid)
  if not grid or grid <= 1 then return v end
  if v >= 0 then
    return math.floor((v / grid) + 0.5) * grid
  end
  return math.ceil((v / grid) - 0.5) * grid
end

local function ResolveRelFrame(relNameOrFrame)
  if type(relNameOrFrame) == "table" then return relNameOrFrame end
  if type(relNameOrFrame) == "string" and relNameOrFrame ~= "" then
    return _G[relNameOrFrame] or UIParent
  end
  return UIParent
end

local function SetShownCompat(frame, shown)
  if not frame then return end
  if frame.SetShown then
    frame:SetShown(shown and true or false)
    return
  end
  if shown then
    if frame.Show then frame:Show() end
  else
    if frame.Hide then frame:Hide() end
  end
end

local function GetSaved(key)
  local db = GetDB()
  return db.frames[key]
end

local function SetSaved(key, t)
  local db = GetDB()
  db.frames[key] = t
end

local function FindKeyForEntry(entry)
  if type(entry) ~= "table" then return nil end
  if entry.key and registry[entry.key] == entry then
    return entry.key
  end
  for key, v in pairs(registry) do
    if v == entry then
      return key
    end
  end
  return nil
end

local function EnsureGridFrame()
  if gridFrame then return end
  gridFrame = CreateFrame("Frame", "EnhanceTBC_MoverGrid", UIParent)
  gridFrame:SetAllPoints(UIParent)
  gridFrame:SetFrameStrata("FULLSCREEN_DIALOG")
  gridFrame:Hide()
end

local function ClearGrid()
  for _, tx in ipairs(gridV) do tx:Hide() end
  for _, tx in ipairs(gridH) do tx:Hide() end
end

local function EnsureGridLines(count, arr)
  while #arr < count do
    local tx = gridFrame:CreateTexture(nil, "BACKGROUND")
    tx:SetTexture("Interface\\Buttons\\WHITE8x8")
    tx:Hide()
    table.insert(arr, tx)
  end
end

local function ShowGrid()
  EnsureGridFrame()
  local db = GetDB()
  ClearGrid()

  local grid = tonumber(db.gridSize) or 8
  if grid < 2 then grid = 2 end

  local w = UIParent:GetWidth()
  local h = UIParent:GetHeight()

  local vCount = math.floor(w / grid)
  local hCount = math.floor(h / grid)

  EnsureGridLines(vCount + 1, gridV)
  EnsureGridLines(hCount + 1, gridH)

  local a = db.gridAlpha or 0.25
  local r, g, b = 0.20, 1.00, 0.20

  for i = 0, vCount do
    local x = i * grid
    local tx = gridV[i + 1]
    tx:ClearAllPoints()
    tx:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", x, 0)
    tx:SetPoint("BOTTOMLEFT", gridFrame, "BOTTOMLEFT", x, 0)
    tx:SetWidth(1)
    tx:SetVertexColor(r, g, b, a)
    tx:Show()
  end

  for i = 0, hCount do
    local y = -i * grid
    local tx = gridH[i + 1]
    tx:ClearAllPoints()
    tx:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", 0, y)
    tx:SetPoint("TOPRIGHT", gridFrame, "TOPRIGHT", 0, y)
    tx:SetHeight(1)
    tx:SetVertexColor(r, g, b, a)
    tx:Show()
  end

  gridFrame:Show()
end

local function HideGrid()
  if not gridFrame then return end
  gridFrame:Hide()
end

local function CanMoveNow()
  local db = GetDB()
  if db.onlyOutOfCombat and InCombat() then
    return false
  end
  return true
end

local function ApplyPointToFrame(key)
  local entry = registry[key]
  if not entry or not entry.frame then return end
  local frame = entry.frame
  local opts = entry.opts or {}

  local saved = GetSaved(key)
  local use = saved

  if not use then
    use = opts.default or { point = "CENTER", rel = "UIParent", relPoint = "CENTER", x = 0, y = 0 }
  end

  local relFrame = ResolveRelFrame(use.rel or "UIParent")

  frame:ClearAllPoints()
  frame:SetPoint(use.point or "CENTER", relFrame, use.relPoint or "CENTER", use.x or 0, use.y or 0)
end

local function HandleFrameNameForKey(key)
  key = tostring(key or "")
  key = key:gsub("[^%w_]", "_")
  if key == "" then key = "Unnamed" end
  return "EnhanceTBC_MoverHandle_" .. key
end

local function CreateHandle(key, entry)
  local frame = entry.frame
  if not frame then return end

  local h = CreateFrame("Frame", HandleFrameNameForKey(key), UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  h:SetFrameStrata("DIALOG")
  h:SetClampedToScreen(true)
  h:EnableMouse(true)
  h:SetMovable(true)
  h:RegisterForDrag("LeftButton")

  if h.SetBackdrop then
    h:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 14,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    h:SetBackdropColor(0.03, 0.06, 0.03, 0.80)
    h:SetBackdropBorderColor(0.20, 1.00, 0.20, 0.85)
  end

  local label = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("CENTER", h, "CENTER", 0, 0)
  label:SetText(key)
  h._label = label

  -- Keep handle positioned over the target frame
  h:SetScript("OnShow", function(self)
    local db = GetDB()
    self:SetAlpha(db.handleAlpha or 0.85)
    self:SetScale(db.handleScale or 1.0)
    if self._label then
      SetShownCompat(self._label, db.showFrameNames and true or false)
      if db.showFrameNames then self._label:SetText(key) end
    end
  end)

  local function SyncSizeAndPos()
    if not h:IsShown() then return end
    if not frame:IsShown() then
      h:Hide()
      return
    end

    local w = frame:GetWidth() or 0
    local hh = frame:GetHeight() or 0

    -- Minimum handle size so it’s always draggable
    if w < 90 then w = 90 end
    if hh < 18 then hh = 18 end
    if hh > 40 then hh = 40 end

    h:SetSize(w, hh)

    h:ClearAllPoints()
    h:SetPoint("CENTER", frame, "CENTER", 0, 0)
  end

  h._sync = SyncSizeAndPos

  h:SetScript("OnDragStart", function(self)
    if not CanMoveNow() then return end
    if frame.IsProtected and frame:IsProtected() and InCombat() then return end
    if not frame.StartMoving then return end
    frame:StartMoving()
  end)

  h:SetScript("OnDragStop", function(self)
    if frame.StopMovingOrSizing then
      frame:StopMovingOrSizing()
    end

    -- Save snapped position based on current point relative to UIParent
    local db = GetDB()
    if not frame.GetPoint then return end
    local point, rel, relPoint, x, y = frame:GetPoint(1)
    if not point then return end

    local gx = x or 0
    local gy = y or 0

    if db.snapToGrid then
      local grid = tonumber(db.gridSize) or 8
      gx = RoundToGrid(gx, grid)
      gy = RoundToGrid(gy, grid)
    end

    local relName = "UIParent"
    if rel and rel.GetName and rel:GetName() then
      relName = rel:GetName()
    end

    SetSaved(key, {
      point = point,
      rel = relName,
      relPoint = relPoint,
      x = gx,
      y = gy,
    })

    -- Re-apply snapped anchor
    ApplyPointToFrame(key)

    if self._sync then self:_sync() end
  end)

  h:SetScript("OnMouseUp", function(self, btn)
    if btn == "RightButton" then
      M:Reset(key)
    end
  end)

  h:SetScript("OnEnter", function(self)
    if not GameTooltip or not GameTooltip.SetOwner then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("EnhanceTBC Mover", 0.20, 1.00, 0.20)
    GameTooltip:AddLine("Drag to move. Right-click to reset.", 1, 1, 1)
    if GetDB().onlyOutOfCombat then
      GameTooltip:AddLine("Moving is blocked in combat.", 1, 0.6, 0.6)
    end
    GameTooltip:Show()
  end)

  h:SetScript("OnLeave", function()
    if GameTooltip and GameTooltip.Hide then
      GameTooltip:Hide()
    end
  end)

  h:Hide()
  return h
end

local function UpdateAllHandles()
  local db = GetDB()
  for key, entry in pairs(registry) do
    local frame = entry.frame
    if frame and frame.SetClampedToScreen then
      frame:SetClampedToScreen(db.clampToScreen and true or false)
    end

    local h = handles[key]
    if not h then
      h = CreateHandle(key, entry)
      handles[key] = h
      entry.handle = h
    end

    h:SetClampedToScreen(db.clampToScreen and true or false)
    h:SetAlpha(db.handleAlpha or 0.85)
    h:SetScale(db.handleScale or 1.0)
    if h._label then
      SetShownCompat(h._label, db.showFrameNames and true or false)
      if db.showFrameNames then h._label:SetText(key) end
    end

    if db.unlocked and db.enabled and ETBC.db.profile.general.enabled then
      -- If the frame is hidden, handle should hide too
      if frame and frame.IsShown and frame:IsShown() then
        h:Show()
        if h._sync then h:_sync() end
      else
        h:Hide()
      end
    else
      h:Hide()
    end
  end
end

function M:Register(key, frame, opts)
  if not key or key == "" then return end
  if not frame then return end

  registry[key] = registry[key] or {}
  registry[key].key = key
  registry[key].frame = frame
  registry[key].opts = opts or registry[key].opts or {}

  -- Ensure movable settings are correct on the target frame
  if frame.SetMovable then frame:SetMovable(true) end
  if frame.EnableMouse then frame:EnableMouse(false) end -- handle does input
  if frame.SetClampedToScreen then
    local db = GetDB()
    frame:SetClampedToScreen(db.clampToScreen and true or false)
  end

  -- Apply saved/default anchor now
  ApplyPointToFrame(key)

  -- Create handle now so it’s ready
  if not handles[key] then
    handles[key] = CreateHandle(key, registry[key])
    registry[key].handle = handles[key]
  end

  UpdateAllHandles()
end

function M:GetRegistered()
  return registry
end

function M:ApplyAnchorFromHandle(entry, point, relPoint, x, y)
  local key = FindKeyForEntry(entry)
  if not key then return end

  local rel = "UIParent"
  SetSaved(key, {
    point = point or "CENTER",
    rel = rel,
    relPoint = relPoint or "CENTER",
    x = x or 0,
    y = y or 0,
  })
  ApplyPointToFrame(key)
end

function M:ResetEntry(entry)
  local key = FindKeyForEntry(entry)
  if not key then return end
  self:Reset(key)
end

function M:ResetAll()
  self:Reset("all")
end

function M:AutoRegisterKnown()
  -- Compatibility no-op: some UI layers call this to allow modules to lazily
  -- register movers. Individual modules can still register directly.
end

function M:Apply(key)
  if key then
    ApplyPointToFrame(key)
    local h = handles[key]
    if h and h._sync then h:_sync() end
  else
    for k in pairs(registry) do
      ApplyPointToFrame(k)
      local h = handles[k]
      if h and h._sync then h:_sync() end
    end
  end
end

function M:SetUnlocked(v)
  local db = GetDB()
  db.unlocked = v and true or false

  if db.unlocked and db.showGrid then
    ShowGrid()
  else
    HideGrid()
  end

  UpdateAllHandles()
end

function M:Toggle()
  local db = GetDB()
  self:SetUnlocked(not db.unlocked)
end

function M:Lock()
  self:SetUnlocked(false)
end

function M:Unlock()
  self:SetUnlocked(true)
end

function M:SetMoveMode(enabled)
  local db = GetDB()
  -- Convert to boolean using Lua idiom
  db.moveMode = not not enabled
  ETBC.ApplyBus:Notify("mover")
end

function M:SetMasterMove(enabled)
  self:SetUnlocked(enabled and true or false)
  self:SetMoveMode(enabled and true or false)
end

function M:ToggleMasterMove()
  local db = GetDB()
  local nextState = not (db.moveMode and db.unlocked)
  self:SetMasterMove(nextState)
end

function M:GetGridSize()
  return GetDB().gridSize or 8
end

function M:SetupChatCommands()
  -- Wrapper function called by MoverUI to ensure slash commands are registered
  -- for mover functionality (/etbcmove, /etbc unlock, /etbc lock, /etbc reset)
  -- This allows MoverUI to initialize commands without directly accessing internal functions
  EnsureSlash()
end

function M:Reset(key)
  local db = GetDB()
  if key == "all" or key == "*" then
    db.frames = {}
    for k in pairs(registry) do
      ApplyPointToFrame(k)
    end
    UpdateAllHandles()
    return
  end

  -- Exit early if key is nil or empty - resetting without a key is not supported
  if not key or key == "" then
    if ETBC.db and ETBC.db.profile and ETBC.db.profile.general and ETBC.db.profile.general.debug then
      ETBC:Debug("Mover:Reset called with nil or empty key - operation skipped")
    end
    return
  end

  -- Reset specific key by removing saved data (if exists) and re-applying default
  db.frames[key] = nil
  ApplyPointToFrame(key)
  UpdateAllHandles()
end

function M:Nudge(key, dx, dy)
  local entry = registry[key]
  if not entry or not entry.frame then return end
  local frame = entry.frame
  local db = GetDB()

  if not frame.GetPoint then return end
  local point, rel, relPoint, x, y = frame:GetPoint(1)
  if not point then return end

  local nx = (x or 0) + (dx or 0)
  local ny = (y or 0) + (dy or 0)

  if db.snapToGrid then
    local grid = tonumber(db.gridSize) or 8
    nx = RoundToGrid(nx, grid)
    ny = RoundToGrid(ny, grid)
  end

  local relName = "UIParent"
  if rel and rel.GetName and rel:GetName() then
    relName = rel:GetName()
  end

  SetSaved(key, { point = point, rel = relName, relPoint = relPoint, x = nx, y = ny })
  ApplyPointToFrame(key)

  local h = handles[key]
  if h and h._sync then h:_sync() end
end

-- ---------------------------------------------------------
-- Apply + driver + slash commands
-- ---------------------------------------------------------
local function Apply()
  EnsureDriver()
  local db = GetDB()
  local enabled = ETBC.db.profile.general.enabled and db.enabled

  driver:UnregisterAllEvents()
  driver:SetScript("OnUpdate", nil)
  driver:SetScript("OnEvent", nil)

  if enabled then
    driver:RegisterEvent("PLAYER_ENTERING_WORLD")
    driver:RegisterEvent("UI_SCALE_CHANGED")
    driver:RegisterEvent("DISPLAY_SIZE_CHANGED")
    driver:RegisterEvent("PLAYER_REGEN_DISABLED")
    driver:RegisterEvent("PLAYER_REGEN_ENABLED")

    driver:SetScript("OnEvent", function(_, event)
      if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        -- If onlyOutOfCombat is on, handles are still shown but dragging will be blocked.
        -- Still refresh tooltips/labels/grid if desired.
      end

      -- Re-sync grid/handles on any of these
      local db2 = GetDB()
      if db2.unlocked and db2.showGrid then
        ShowGrid()
      else
        HideGrid()
      end
      M:Apply()
      UpdateAllHandles()
    end)

    -- Light handle sync while unlocked (so if frames resize, handles follow)
    driver:SetScript("OnUpdate", function(_, elapsed)
      local db2 = GetDB()
      if not (db2.unlocked and enabled) then
        driver:Hide()
        return
      end
      -- Very light: sync at ~10hz
      driver._acc = (driver._acc or 0) + elapsed
      if driver._acc >= 0.10 then
        driver._acc = 0
        for _, h in pairs(handles) do
          if h and h.IsShown and h:IsShown() and h._sync then
            h:_sync()
          end
        end
      end
    end)

    if db.unlocked and db.showGrid then
      ShowGrid()
    else
      HideGrid()
    end
    UpdateAllHandles()

    if db.unlocked then driver:Show() else driver:Hide() end
  else
    HideGrid()
    for _, h in pairs(handles) do
      if h then h:Hide() end
    end
    driver:Hide()
  end
end

ETBC.ApplyBus:Register("mover", Apply)
ETBC.ApplyBus:Register("general", Apply)

-- Slash helpers (do not conflict with your existing /etbc core)
-- If you already parse /etbc elsewhere, this safely adds subcommands by hooking if possible.
local function EnsureSlash()
  if ETBC._moverSlashInstalled then return end
  ETBC._moverSlashInstalled = true

  -- If you already have a slash handler, add these there instead.
  -- This is a minimal standalone fallback:
  SLASH_ENHANCETBCMOVER1 = "/etbcmove"
  SlashCmdList.ENHANCETBCMOVER = function(msg)
    msg = tostring(msg or ""):lower()
    if msg == "" or msg == "toggle" or msg == "move" then
      M:Toggle()
      return
    end
    if msg == "unlock" then M:Unlock(); return end
    if msg == "lock" then M:Lock(); return end
    if msg:find("^reset") then
      local k = msg:match("^reset%s+(%S+)$")
      if not k or k == "" then k = "all" end
      M:Reset(k)
      return
    end
  end
end

EnsureSlash()

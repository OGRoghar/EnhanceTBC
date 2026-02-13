-- Modules/Minimap.lua
-- EnhanceTBC - Minimap (SAFE REBUILD v2)
-- FIXES THIS TURN:
--  1) Flyout no longer "every other click" restores buttons to the minimap.
--     (Root cause: RefreshFlyout scanned ONLY the minimap; when buttons were already in flyout,
--      scan returned empty and the code "restored" them back.)
--     New logic: keep a persistent captured set; only add NEW buttons found on the minimap.
--     Never restore captured buttons unless flyout/feature is disabled.
--  2) Square mode hides the "X" / title-bar artifacts more aggressively.
--  3) Addon buttons will stay in the flyout (so they won't do the circular-on-square ring behavior).

local ADDON_NAME, ETBC = ...

ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.Minimap = mod

local mm = _G.Minimap
local mmCluster = _G.MinimapCluster
local UIParent = _G.UIParent

local WHITE = "Interface\\Buttons\\WHITE8x8"
local MASK_CIRCLE = "Textures\\MinimapMask"
local MASK_SQUARE = WHITE

-- ------------------------------------------------------------
-- DB (compat: profile.minimap OR profile.general.minimap)
-- ------------------------------------------------------------
local function GetDB()
  if not ETBC or not ETBC.db or not ETBC.db.profile then return nil end
  local p = ETBC.db.profile

  p.general = p.general or {}
  p.general.minimap = p.general.minimap or {}

  if type(p.minimap) ~= "table" then
    p.minimap = p.general.minimap
  end

  local db = p.minimap

  if db.enabled == nil then db.enabled = true end
  if db.shape == nil then db.shape = "CIRCLE" end -- "CIRCLE"|"SQUARE"
  if db.scale == nil then db.scale = 1.0 end
  if db.squareSize == nil then db.squareSize = 140 end
  if db.keepInsideScreen == nil then db.keepInsideScreen = true end

  db.border = db.border or {}
  if db.border.enabled == nil then db.border.enabled = true end
  if db.border.size == nil then db.border.size = 2 end
  if db.border.alpha == nil then db.border.alpha = 0.90 end
  if db.border.r == nil then db.border.r = 0.18 end
  if db.border.g == nil then db.border.g = 0.20 end
  if db.border.b == nil then db.border.b = 0.18 end

  db.background = db.background or {}
  if db.background.enabled == nil then db.background.enabled = false end
  if db.background.alpha == nil then db.background.alpha = 0.20 end
  if db.background.r == nil then db.background.r = 0.02 end
  if db.background.g == nil then db.background.g = 0.03 end
  if db.background.b == nil then db.background.b = 0.02 end

  db.flyout = db.flyout or {}
  if db.flyout.enabled == nil then db.flyout.enabled = true end
  if db.flyout.locked == nil then db.flyout.locked = true end
  if db.flyout.buttonSize == nil then db.flyout.buttonSize = 28 end
  if db.flyout.padding == nil then db.flyout.padding = 6 end
  if db.flyout.perRow == nil then db.flyout.perRow = 6 end
  if db.flyout.maxRows == nil then db.flyout.maxRows = 6 end
  if db.flyout.point == nil then
    db.flyout.point = "TOPRIGHT"
    db.flyout.rel = "Minimap"
    db.flyout.relPoint = "BOTTOMRIGHT"
    db.flyout.x = 0
    db.flyout.y = -6
  end

  return db
end

local function clamp(v, lo, hi)
  v = tonumber(v) or lo
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function SafeCall(fn, ...)
  if type(fn) ~= "function" then return end
  pcall(fn, ...)
end

-- ------------------------------------------------------------
-- Original minimap size for restore
-- ------------------------------------------------------------
local orig = { sizeStored = false, w = nil, h = nil }

local function StoreOriginalSize()
  if orig.sizeStored or not mm or not mm.GetSize then return end
  orig.w, orig.h = mm:GetSize()
  orig.sizeStored = true
end

local function ApplySizeAndScale(db)
  if not mm then return end
  StoreOriginalSize()

  mm:SetScale(clamp(db.scale, 0.50, 2.00))

  if db.shape == "SQUARE" then
    local s = clamp(db.squareSize, 90, 260)
    mm:SetSize(s, s)
  else
    if orig.sizeStored and orig.w and orig.h then
      mm:SetSize(orig.w, orig.h)
    end
  end
end

-- ------------------------------------------------------------
-- Border + optional background
-- ------------------------------------------------------------
local deco

local function EnsureDeco()
  if deco or not mm then return end
  deco = CreateFrame("Frame", "EnhanceTBC_MinimapDeco", mm, "BackdropTemplate")
  deco:SetAllPoints(mm)
  deco:SetFrameStrata(mm:GetFrameStrata())
  deco:SetFrameLevel(mm:GetFrameLevel() + 25)
end

local function ApplyDeco(db)
  EnsureDeco()
  if not deco then return end

  local b = db.border or {}
  local bg = db.background or {}

  local edgeSize = clamp(b.size, 1, 8)
  deco:SetBackdrop({
    bgFile = WHITE,
    edgeFile = WHITE,
    tile = false,
    edgeSize = edgeSize,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })

  if bg.enabled then
    deco:SetBackdropColor(bg.r or 0.02, bg.g or 0.03, bg.b or 0.02, clamp(bg.alpha, 0, 1))
  else
    deco:SetBackdropColor(0, 0, 0, 0)
  end

  if b.enabled then
    deco:SetBackdropBorderColor(b.r or 0.18, b.g or 0.20, b.b or 0.18, clamp(b.alpha, 0, 1))
    deco:Show()
  else
    deco:SetBackdropBorderColor(0, 0, 0, 0)
    deco:Show()
    if not bg.enabled then deco:Hide() end
  end
end

-- ------------------------------------------------------------
-- Shape + aggressive hide of title/X artifacts in square mode
-- ------------------------------------------------------------
local visualsCached = false
local ringFrames = {}
local zoneBarFrames = {}
local squareHide = {}
local hookedKeepHidden = {}

local function HardHide(obj)
  if not obj then return end
  if obj.Hide then obj:Hide() end
  if obj.SetShown then obj:SetShown(false) end
  if obj.SetAlpha then obj:SetAlpha(0) end
end

local function SetShown(obj, shown)
  if not obj then return end
  if shown then
    if obj.SetAlpha then obj:SetAlpha(1) end
    if obj.Show then obj:Show() end
  else
    HardHide(obj)
  end
end

local function AddSquareHide(obj)
  if not obj then return end
  for i = 1, #squareHide do
    if squareHide[i] == obj then return end
  end
  table.insert(squareHide, obj)
end

local function HookKeepHidden(obj)
  if not obj or hookedKeepHidden[obj] then return end
  hookedKeepHidden[obj] = true
  obj:HookScript("OnShow", function(self)
    local db = GetDB()
    if db and db.enabled and db.shape == "SQUARE" then
      HardHide(self)
    end
  end)
end

local function CacheVisuals()
  if visualsCached then return end
  visualsCached = true

  ringFrames = {
    _G.MinimapBorder,
    _G.MinimapBorderTop,
    _G.MinimapCompassTexture,
    _G.MinimapNorthTag,
    _G.MinimapBackdrop,
    _G.MinimapBackdropTexture,
  }

  local z = _G.MinimapZoneTextButton
  if z then
    zoneBarFrames = { z, z.Left, z.Middle, z.Right }
  else
    zoneBarFrames = {}
  end

  -- This is where the "X" / title-bar-ish stuff tends to come from on modern frames.
  AddSquareHide(mmCluster and mmCluster.BorderTop)
  AddSquareHide(mmCluster and mmCluster.Border)
  AddSquareHide(_G.MinimapClusterBorderTop)
  AddSquareHide(_G.MinimapClusterBorder)

  if mmCluster and mmCluster.NineSlice then
    AddSquareHide(mmCluster.NineSlice.TopEdge)
    AddSquareHide(mmCluster.NineSlice.TopLeftCorner)
    AddSquareHide(mmCluster.NineSlice.TopRightCorner)
  end

  -- Extra: common close/title containers on some builds
  AddSquareHide(mmCluster and mmCluster.CloseButton)
  AddSquareHide(mmCluster and mmCluster.Title)
  AddSquareHide(mmCluster and mmCluster.TitleContainer)

  for i = 1, #squareHide do
    HookKeepHidden(squareHide[i])
  end
end

local function ApplyShape(db)
  if not mm or not mm.SetMaskTexture then return end
  CacheVisuals()

  local square = (db.shape == "SQUARE")

  if square then
    mm:SetMaskTexture(MASK_SQUARE)
  else
    mm:SetMaskTexture(MASK_CIRCLE)
  end

  for _, f in ipairs(ringFrames) do SetShown(f, not square) end
  for _, f in ipairs(zoneBarFrames) do SetShown(f, not square) end

  local moon = _G.GameTimeFrame
  if moon then SetShown(moon, not square) end

  if square then
    for i = 1, #squareHide do HardHide(squareHide[i]) end
  end
end

-- ------------------------------------------------------------
-- Flyout (ONLY addon buttons, and persistent capture set)
-- ------------------------------------------------------------
local fly = {
  anchor = nil,
  frame = nil,
  content = nil,
  open = false,

  captured = {},      -- [btn]=true  (persistent set: "this belongs in flyout")
  stored = {},        -- [btn]={ original state }
  ordered = {},       -- array view of captured buttons for layout
}

local function IsForbidden(btn)
  if not btn or not btn.GetName then return true end
  local n = btn:GetName() or ""

  if n == "MinimapZoomIn" or n == "MinimapZoomOut" then return true end
  if n:find("MiniMapTracking", 1, true) then return true end
  if n:find("MiniMapMail", 1, true) then return true end
  if n:find("MiniMapLFG", 1, true) then return true end
  if n:find("QueueStatus", 1, true) then return true end
  if n == "GameTimeFrame" then return true end
  if n == "TimeManagerClockButton" then return true end
  if n == "MiniMapWorldMapButton" then return true end
  if n:find("MinimapZoneText", 1, true) then return true end

  -- Quest/objective-ish
  if n:find("Quest", 1, true) then return true end
  if n:find("Objective", 1, true) then return true end
  if n:find("Scenario", 1, true) then return true end

  if n:find("EnhanceTBC_MinimapFlyout", 1, true) then return true end
  if n:find("EnhanceTBC_MinimapDeco", 1, true) then return true end
  return false
end

local function LooksLikeAddonButton(btn)
  if not btn or not btn.IsObjectType or not btn:IsObjectType("Button") then return false end
  if btn.IsForbidden and btn:IsForbidden() then return false end
  if IsForbidden(btn) then return false end

  local name = btn.GetName and (btn:GetName() or "") or ""
  local isLDBIcon = (name:find("LibDBIcon", 1, true) ~= nil) or (name:find("DBIcon", 1, true) ~= nil)
  if not isLDBIcon then return false end

  local w = btn.GetWidth and btn:GetWidth() or 0
  local h = btn.GetHeight and btn:GetHeight() or 0
  if w <= 0 or h <= 0 or w > 80 or h > 80 then return false end

  return true
end

local function CapturePoints(frame)
  if not frame or not frame.GetNumPoints then return nil end
  local t = {}
  for i = 1, frame:GetNumPoints() do
    local p, rel, rp, x, y = frame:GetPoint(i)
    t[i] = { p, rel, rp, x, y }
  end
  return t
end

local function RestorePoints(frame, t)
  if not frame or not t then return end
  frame:ClearAllPoints()
  for i = 1, #t do
    local p, rel, rp, x, y = unpack(t[i])
    if p then frame:SetPoint(p, rel, rp, x, y) end
  end
end

local function StoreBtn(btn)
  if fly.stored[btn] then return end
  local w, h = 0, 0
  if btn.GetSize then w, h = btn:GetSize() end
  fly.stored[btn] = {
    parent = btn:GetParent(),
    points = CapturePoints(btn),
    strata = btn.GetFrameStrata and btn:GetFrameStrata() or nil,
    level = btn.GetFrameLevel and btn:GetFrameLevel() or nil,
    scale = btn.GetScale and btn:GetScale() or 1,
    width = w, height = h,
  }
end

local function RestoreBtn(btn)
  local pack = fly.stored[btn]
  if not pack then return end

  if pack.parent and btn:GetParent() ~= pack.parent then btn:SetParent(pack.parent) end
  if btn.SetScale and pack.scale then btn:SetScale(pack.scale) end
  if btn.SetSize and pack.width and pack.height and pack.width > 0 and pack.height > 0 then
    btn:SetSize(pack.width, pack.height)
  end
  if btn.SetFrameStrata and pack.strata then btn:SetFrameStrata(pack.strata) end
  if btn.SetFrameLevel and pack.level then btn:SetFrameLevel(pack.level) end
  RestorePoints(btn, pack.points)

  fly.stored[btn] = nil
  fly.captured[btn] = nil
end

local function ScanChildren(parent, out, depth)
  if not parent or depth <= 0 or not parent.GetNumChildren then return end
  local kids = { parent:GetChildren() }
  for i = 1, #kids do
    local c = kids[i]
    if c and not out._seen[c] then
      out._seen[c] = true
      if LooksLikeAddonButton(c) then
        table.insert(out, c)
      end
      ScanChildren(c, out, depth - 1)
    end
  end
end

local function FindNewAddonButtonsOnMinimap()
  local out = { _seen = {} }
  ScanChildren(mm, out, 4)
  ScanChildren(mmCluster, out, 4)
  out._seen = nil

  -- Only return those not already captured
  local filtered = {}
  for i = 1, #out do
    local b = out[i]
    if b and not fly.captured[b] then
      table.insert(filtered, b)
    end
  end

  table.sort(filtered, function(a, b)
    local an = a.GetName and (a:GetName() or "") or ""
    local bn = b.GetName and (b:GetName() or "") or ""
    return an < bn
  end)

  return filtered
end

local function BuildOrderedCaptured()
  wipe(fly.ordered)
  for btn in pairs(fly.captured) do
    if btn and btn.GetName and btn:IsObjectType("Button") then
      table.insert(fly.ordered, btn)
    end
  end
  table.sort(fly.ordered, function(a, b)
    local an = a:GetName() or ""
    local bn = b:GetName() or ""
    return an < bn
  end)
end

local function EnsureFlyout()
  if fly.frame or not mm then return end

  fly.anchor = CreateFrame("Button", "EnhanceTBC_MinimapFlyoutAnchor", mmCluster or UIParent)
  fly.anchor:SetSize(18, 18)
  fly.anchor:SetPoint("RIGHT", mm, "RIGHT", 8, 0)
  fly.anchor:SetFrameStrata("MEDIUM")
  fly.anchor:SetFrameLevel(mm:GetFrameLevel() + 500)
  if fly.anchor.SetIgnoreParentScale then fly.anchor:SetIgnoreParentScale(true) end
  fly.anchor:SetScale(1)

  local bg = fly.anchor:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture(WHITE)
  bg:SetAllPoints()
  bg:SetVertexColor(0, 0, 0, 0.35)

  local fs = fly.anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs:SetPoint("CENTER")
  fs:SetText("≡")
  fs:SetTextColor(0.85, 0.90, 0.85, 1)

  fly.frame = CreateFrame("Frame", "EnhanceTBC_MinimapFlyout", mmCluster or UIParent, "BackdropTemplate")
  fly.frame:SetFrameStrata("DIALOG")
  fly.frame:SetFrameLevel(mm:GetFrameLevel() + 600)
  fly.frame:SetClampedToScreen(true)
  fly.frame:Hide()

  fly.frame:SetBackdrop({
    bgFile = WHITE,
    edgeFile = WHITE,
    tile = false,
    edgeSize = 2,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  fly.frame:SetBackdropColor(0.02, 0.03, 0.02, 0.92)
  fly.frame:SetBackdropBorderColor(0.18, 0.20, 0.18, 0.90)

  fly.content = CreateFrame("Frame", nil, fly.frame)
  fly.content:SetPoint("TOPLEFT", fly.frame, "TOPLEFT", 8, -8)
  fly.content:SetPoint("BOTTOMRIGHT", fly.frame, "BOTTOMRIGHT", -8, 8)

  fly.frame:EnableMouse(true)
  fly.frame:SetMovable(true)
  fly.frame:RegisterForDrag("LeftButton")
  fly.frame:SetScript("OnDragStart", function(self)
    local db = GetDB()
    if db and db.flyout and not db.flyout.locked then self:StartMoving() end
  end)
  fly.frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local db = GetDB()
    if not db or not db.flyout then return end
    local p, rel, rp, x, y = self:GetPoint(1)
    if p then
      db.flyout.point = p
      db.flyout.rel = (rel and rel.GetName and rel:GetName()) or "Minimap"
      db.flyout.relPoint = rp
      db.flyout.x = x
      db.flyout.y = y
    end
  end)

  fly.anchor:SetScript("OnClick", function()
    if fly.frame:IsShown() then
      fly.frame:Hide()
      fly.open = false
      -- IMPORTANT: do NOT restore anything on close; captured stay captured.
    else
      fly.frame:Show()
      fly.open = true
      mod:RefreshFlyout()
    end
  end)
end

local function ApplyFlyoutAnchor(db)
  if not fly.frame then return end
  local rel = _G[db.flyout.rel or "Minimap"] or mm
  fly.frame:ClearAllPoints()
  fly.frame:SetPoint(db.flyout.point or "TOPRIGHT", rel, db.flyout.relPoint or "BOTTOMRIGHT", db.flyout.x or 0, db.flyout.y or -6)
end

local function LayoutFlyout(db)
  if not fly.frame or not fly.content then return end

  BuildOrderedCaptured()

  local size = clamp(db.flyout.buttonSize, 18, 44)
  local pad = clamp(db.flyout.padding, 0, 16)
  local perRow = clamp(db.flyout.perRow, 1, 12)
  local maxRows = clamp(db.flyout.maxRows, 1, 12)

  local total = #fly.ordered
  if total < 1 then
    fly.frame:SetSize(16 + size, 16 + size)
    ApplyFlyoutAnchor(db)
    return
  end

  local rows = math.ceil(total / perRow)
  if rows > maxRows then
    local needPerRow = math.ceil(total / maxRows)
    perRow = clamp(needPerRow, perRow, 16)
    rows = math.ceil(total / perRow)
  end
  local cols = math.min(perRow, total)

  local w = (cols * size) + ((cols - 1) * pad) + 16
  local h = (rows * size) + ((rows - 1) * pad) + 16

  local maxH = (UIParent and UIParent.GetHeight and UIParent:GetHeight() or 800) - 80
  if h > maxH then h = maxH end

  fly.frame:SetSize(w, h)
  ApplyFlyoutAnchor(db)

  local idx = 1
  for i = 1, #fly.ordered do
    local b = fly.ordered[i]
    if b then
      local r = math.floor((idx - 1) / perRow)
      local c = (idx - 1) % perRow

      b:ClearAllPoints()
      b:SetSize(size, size)
      b:SetPoint("TOPLEFT", fly.content, "TOPLEFT", c * (size + pad), -(r * (size + pad)))

      idx = idx + 1
    end
  end
end

function mod:RefreshFlyout()
  local db = GetDB()
  if not db or not mm then return end
  EnsureFlyout()

  if not (db.enabled and db.flyout and db.flyout.enabled) then
    -- Only when feature disabled do we restore everything.
    for btn in pairs(fly.stored) do RestoreBtn(btn) end
    wipe(fly.ordered)
    if fly.frame then fly.frame:Hide() end
    if fly.anchor then fly.anchor:Hide() end
    fly.open = false
    return
  end

  if fly.anchor then fly.anchor:Show() end

  -- Capture NEW addon buttons found on the minimap/cluster.
  local newButtons = FindNewAddonButtonsOnMinimap()
  for i = 1, #newButtons do
    local btn = newButtons[i]
    if btn and not fly.captured[btn] then
      StoreBtn(btn)
      fly.captured[btn] = true

      btn:SetParent(fly.content)
      if btn.SetScale then btn:SetScale(1) end
      btn:SetFrameStrata("DIALOG")
      if btn.SetFrameLevel then btn:SetFrameLevel(fly.frame:GetFrameLevel() + 5) end
    end
  end

  -- Re-apply parenting for any captured button (some LDB libs reparent occasionally).
  for btn in pairs(fly.captured) do
    if btn and fly.stored[btn] then
      if btn:GetParent() ~= fly.content then
        btn:SetParent(fly.content)
      end
      if btn.SetScale then btn:SetScale(1) end
      btn:SetFrameStrata("DIALOG")
      if btn.SetFrameLevel then btn:SetFrameLevel(fly.frame:GetFrameLevel() + 5) end
    end
  end

  LayoutFlyout(db)
end

-- ------------------------------------------------------------
-- Apply
-- ------------------------------------------------------------
function mod:Apply()
  local db = GetDB()
  if not db or not mm then return end

  if not db.enabled then
    if mm.SetMaskTexture then mm:SetMaskTexture(MASK_CIRCLE) end
    if deco then deco:Hide() end

    for btn in pairs(fly.stored) do RestoreBtn(btn) end
    wipe(fly.ordered)
    if fly.frame then fly.frame:Hide() end
    if fly.anchor then fly.anchor:Hide() end
    fly.open = false
    return
  end

  ApplySizeAndScale(db)
  ApplyShape(db)
  ApplyDeco(db)

  if db.flyout and db.flyout.enabled then
    EnsureFlyout()
    if fly.anchor then fly.anchor:Show() end
    if fly.open and fly.frame and fly.frame:IsShown() then
      self:RefreshFlyout()
    end
  else
    for btn in pairs(fly.stored) do RestoreBtn(btn) end
    wipe(fly.ordered)
    if fly.frame then fly.frame:Hide() end
    if fly.anchor then fly.anchor:Hide() end
    fly.open = false
  end
end

-- ------------------------------------------------------------
-- Events (lightweight)
-- ------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, event)
  if not ETBC or not ETBC.db then return end

  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    SafeCall(mod.Apply, mod)
    return
  end

  if event == "ADDON_LOADED" then
    -- New LDB icons can appear after load; if flyout feature enabled, refresh (open or not).
    C_Timer.After(0.20, function()
      local db = GetDB()
      if db and db.enabled and db.flyout and db.flyout.enabled then
        SafeCall(mod.RefreshFlyout, mod)
      end
    end)
  end
end)

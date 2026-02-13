-- Modules/Minimap.lua
-- EnhanceTBC - Minimap module (SQUARE/CIRCLE + border + Blizzard button normalization + addon button flyout)
--
-- Goals:
--  - Map scale + square size sliders work (uses Settings/Settings_Minimap.lua keys)
--  - Square/circle mask works without leaving ring/cluster art behind
--  - Blizzard minimap buttons (zoom, tracking, LFG, mail, clock, zone text) are NOT huge
--    and do NOT scale with minimap (IgnoreParentScale where available)
--  - Zone name shown above minimap and scales with minimap
--  - Clock centered on bottom border (and above border frame level)
--  - Flyout collects ONLY addon buttons (LibDBIcon10_* by default + optional includes),
--    does NOT scoop Blizzard objective widgets, and remains clickable

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
-- Helpers
-- ------------------------------------------------------------
local function clamp(v, lo, hi)
  v = tonumber(v) or lo
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function SafeCall(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, _ = pcall(fn, ...)
  return ok
end

local function Trim(s)
  s = tostring(s or "")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  return s
end

local function ParseNameList(s)
  local set = {}
  s = tostring(s or "")
  for chunk in s:gmatch("[^,]+") do
    local name = Trim(chunk)
    if name ~= "" then set[name] = true end
  end
  return set
end

local function SafeHide(f)
  if not f then return end
  SafeCall(f.Hide, f)
  SafeCall(f.SetShown, f, false)
  SafeCall(f.SetAlpha, f, 0)
end

local function SafeShow(f)
  if not f then return end
  SafeCall(f.SetAlpha, f, 1)
  SafeCall(f.Show, f)
end

local function SetIgnoreParentScaleSafe(f, on)
  if not f then return end
  if f.SetIgnoreParentScale then
    SafeCall(f.SetIgnoreParentScale, f, on and true or false)
  end
end

local function NormalizeButtonSize(btn, size)
  if not btn then return end
  size = clamp(size or 32, 18, 40)

  SetIgnoreParentScaleSafe(btn, true)
  SafeCall(btn.SetScale, btn, 1)
  SafeCall(btn.SetSize, btn, size, size)

  -- Some Blizzard buttons have internal textures that need scaling too
  if btn.GetRegions then
    local regions = { btn:GetRegions() }
    for i = 1, #regions do
      local r = regions[i]
      if r and r.SetScale then
        SafeCall(r.SetScale, r, 1)
      end
    end
  end
end

local function FindChildByName(parent, needle, depth)
  if not parent or depth <= 0 or not parent.GetChildren then return nil end
  local kids = { parent:GetChildren() }
  for i = 1, #kids do
    local c = kids[i]
    if c and c.GetName then
      local n = c:GetName()
      if n and n:find(needle, 1, true) then
        return c
      end
    end
    local found = FindChildByName(c, needle, depth - 1)
    if found then return found end
  end
  return nil
end

-- ------------------------------------------------------------
-- DB (uses Settings/Settings_Minimap.lua keys)
-- ------------------------------------------------------------
local function GetDB()
  if not ETBC or not ETBC.db or not ETBC.db.profile then return nil end
  local p = ETBC.db.profile

  p.general = p.general or {}
  p.general.minimap = p.general.minimap or {}

  -- Primary store per your Settings_Minimap.lua
  p.minimap = p.minimap or {}
  local db = p.minimap

  if db.enabled == nil then db.enabled = true end
  if db.shape == nil then db.shape = "CIRCLE" end -- "CIRCLE"|"SQUARE"
  if db.squareSize == nil then db.squareSize = 140 end
  if db.mapScale == nil then db.mapScale = 1.0 end

  db.collector = db.collector or {}
  local c = db.collector
  if c.enabled == nil then c.enabled = true end
  if c.flyoutMode == nil then c.flyoutMode = "CLICK" end -- CLICK/HOVER/ALWAYS
  if c.startOpen == nil then c.startOpen = false end
  if c.locked == nil then c.locked = true end

  if c.iconSize == nil then c.iconSize = 28 end
  if c.columns == nil then c.columns = 6 end
  if c.spacing == nil then c.spacing = 4 end
  if c.padding == nil then c.padding = 6 end
  if c.scale == nil then c.scale = 1.0 end
  if c.bgAlpha == nil then c.bgAlpha = 0.70 end
  if c.borderAlpha == nil then c.borderAlpha = 0.90 end

  if c.includeLibDBIcon == nil then c.includeLibDBIcon = true end
  if c.includeExtra == nil then c.includeExtra = "" end
  if c.exclude == nil then c.exclude = "" end

  c.pos = c.pos or {}
  if c.pos.point == nil then c.pos.point = "TOPRIGHT" end
  if c.pos.relPoint == nil then c.pos.relPoint = "TOPLEFT" end
  if c.pos.x == nil then c.pos.x = 8 end
  if c.pos.y == nil then c.pos.y = 0 end

  c.toggle = c.toggle or {}
  if c.toggle.point == nil then c.toggle.point = "TOPRIGHT" end
  if c.toggle.relPoint == nil then c.toggle.relPoint = "BOTTOMRIGHT" end
  if c.toggle.x == nil then c.toggle.x = 2 end
  if c.toggle.y == nil then c.toggle.y = -2 end

  -- Border/background (kept here for stable visuals; if you want to expose sliders later, wire in Settings)
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

  return db
end

-- ------------------------------------------------------------
-- Original size for restore
-- ------------------------------------------------------------
local orig = { stored = false, w = nil, h = nil }

local function StoreOriginalSize()
  if orig.stored or not mm or not mm.GetSize then return end
  orig.w, orig.h = mm:GetSize()
  orig.stored = true
end

local function ApplySizeAndScale(db)
  if not mm then return end
  StoreOriginalSize()

  local scale = clamp(db.mapScale, 0.70, 1.50)
  SafeCall(mm.SetScale, mm, scale)

  if db.shape == "SQUARE" then
    local s = clamp(db.squareSize, 110, 200)
    SafeCall(mm.SetSize, mm, s, s)
  else
    if orig.stored and orig.w and orig.h then
      SafeCall(mm.SetSize, mm, orig.w, orig.h)
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
  SafeCall(deco.SetBackdrop, deco, {
    bgFile = WHITE,
    edgeFile = WHITE,
    tile = false,
    edgeSize = edgeSize,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })

  if bg.enabled then
    SafeCall(deco.SetBackdropColor, deco, bg.r or 0.02, bg.g or 0.03, bg.b or 0.02, clamp(bg.alpha, 0, 1))
  else
    SafeCall(deco.SetBackdropColor, deco, 0, 0, 0, 0)
  end

  if b.enabled then
    SafeCall(deco.SetBackdropBorderColor, deco, b.r or 0.18, b.g or 0.20, b.b or 0.18, clamp(b.alpha, 0, 1))
    SafeShow(deco)
  else
    SafeCall(deco.SetBackdropBorderColor, deco, 0, 0, 0, 0)
    if bg.enabled then SafeShow(deco) else SafeHide(deco) end
  end
end

-- ------------------------------------------------------------
-- Shape + safe hiding of ring/cluster artifacts
-- ------------------------------------------------------------
local visualsCached = false
local ringFrames = {}
local zoneBarFrames = {}
local squareHide = {}
local hookedKeepHidden = {}

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
  SafeCall(obj.HookScript, obj, "OnShow", function(self)
    local db = GetDB()
    if db and db.enabled and db.shape == "SQUARE" then
      SafeHide(self)
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

  AddSquareHide(mmCluster and mmCluster.BorderTop)
  AddSquareHide(mmCluster and mmCluster.Border)
  AddSquareHide(_G.MinimapClusterBorderTop)
  AddSquareHide(_G.MinimapClusterBorder)

  if mmCluster and mmCluster.NineSlice then
    AddSquareHide(mmCluster.NineSlice.TopEdge)
    AddSquareHide(mmCluster.NineSlice.TopLeftCorner)
    AddSquareHide(mmCluster.NineSlice.TopRightCorner)
  end

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

  SafeCall(mm.SetMaskTexture, mm, square and MASK_SQUARE or MASK_CIRCLE)

  -- Hide ring/zone art only; we re-add our own zone+clock later.
  for _, f in ipairs(ringFrames) do
    if square then SafeHide(f) else SafeShow(f) end
  end
  for _, f in ipairs(zoneBarFrames) do
    if square then SafeHide(f) else SafeShow(f) end
  end

  -- Hide day/night indicator in square mode
  local moon = _G.GameTimeFrame
  if moon then
    if square then SafeHide(moon) else SafeShow(moon) end
  end

  if square then
    for i = 1, #squareHide do SafeHide(squareHide[i]) end
  end
end

-- ------------------------------------------------------------
-- Zone + Clock (zone scales with minimap; clock sits on border)
-- ------------------------------------------------------------
local function ApplyZoneAndClock()
  if not mm then return end
  local db = GetDB()
  local zbtn = _G.MinimapZoneTextButton
  local ztxt = _G.MinimapZoneText
  local clock = _G.TimeManagerClockButton

  -- Zone label above minimap (scales with minimap)
  if zbtn then
    SafeCall(zbtn.SetParent, zbtn, mm)
    if zbtn.SetFrameStrata then SafeCall(zbtn.SetFrameStrata, zbtn, mm:GetFrameStrata()) end
    if zbtn.SetFrameLevel then SafeCall(zbtn.SetFrameLevel, zbtn, mm:GetFrameLevel() + 90) end
    SafeCall(zbtn.ClearAllPoints, zbtn)
    SafeCall(zbtn.SetPoint, zbtn, "BOTTOM", mm, "TOP", 0, 6)
    SafeShow(zbtn)
    SafeCall(zbtn.SetAlpha, zbtn, 1)
  end

  if ztxt then
    SafeCall(ztxt.ClearAllPoints, ztxt)
    SafeCall(ztxt.SetPoint, ztxt, "CENTER", zbtn or mm, "CENTER", 0, 0)
    SafeCall(ztxt.SetJustifyH, ztxt, "CENTER")
  end

  -- Clock: centered on bottom border; above our border
  if clock then
    SafeCall(clock.SetParent, clock, mm)
    if clock.SetFrameStrata then SafeCall(clock.SetFrameStrata, clock, "HIGH") end
    if clock.SetFrameLevel then SafeCall(clock.SetFrameLevel, clock, mm:GetFrameLevel() + 200) end

    SafeCall(clock.ClearAllPoints, clock)

    local borderSize = 0
    if db and db.border and db.border.enabled then
      borderSize = clamp(db.border.size or 2, 1, 8)
    end

    local anchor = deco or mm
    local y = (db and db.shape == "SQUARE") and (-borderSize) or (borderSize + 2)

    SafeCall(clock.SetPoint, clock, "BOTTOM", anchor, "BOTTOM", 0, y)

    SafeShow(clock)
    SafeCall(clock.SetAlpha, clock, 1)
  end
end

-- ------------------------------------------------------------
-- Blizzard minimap button layout (no giant icons, no scaling with map)
-- Positions requested:
--   LFG: bottom-left corner
--   Zoom +/-: left edge centered
--   Mail: top edge centered
--   Tracking: top-right edge
-- Not scaled with map.
-- ------------------------------------------------------------
local function ResolveTrackingFrame()
  return _G.MiniMapTrackingFrame
      or _G.MiniMapTracking
      or _G.MinimapTracking
      or _G.MinimapTrackingFrame
end

local function ResolveTrackingButton()
  return _G.MiniMapTrackingButton
      or _G.MinimapTrackingButton
end

local function ResolveLFG()
  return _G.MiniMapLFGFrame
      or _G.QueueStatusMinimapButton
      or _G.LFGMinimapFrame
end

local function ResolveMail()
  return _G.MiniMapMailFrame
      or _G.MinimapMailFrame
end

local function ApplyBlizzButtonsLayout()
  if not mm then return end
  local db = GetDB()
  local anchor = deco or mm
  local borderSize = 0
  if db and db.border and db.border.enabled then
    borderSize = clamp(db.border.size or 2, 1, 8)
  end

  local zoomIn = _G.MinimapZoomIn
  local zoomOut = _G.MinimapZoomOut

  local trackingFrame = ResolveTrackingFrame()
  local trackingBtn = ResolveTrackingButton()
  local lfg = ResolveLFG()
  local mail = ResolveMail()

  -- Fallback scanning (some clients don’t expose globals early)
  if not trackingFrame then trackingFrame = FindChildByName(mmCluster or mm, "Tracking", 4) end
  if not trackingBtn then trackingBtn = FindChildByName(mmCluster or mm, "TrackingButton", 4) end
  if not lfg then lfg = FindChildByName(mmCluster or mm, "LFG", 4) end
  if not mail then mail = FindChildByName(mmCluster or mm, "Mail", 4) end

  -- Normalize sizes + ignore minimap scaling
  NormalizeButtonSize(zoomIn, 32)
  NormalizeButtonSize(zoomOut, 32)
  NormalizeButtonSize(trackingBtn or trackingFrame, 32)
  NormalizeButtonSize(lfg, 32)
  NormalizeButtonSize(mail, 32)

  -- Re-anchor zoom buttons: left edge centered (vertical stack)
  if zoomIn and zoomOut then
    SafeCall(zoomIn.SetParent, zoomIn, UIParent) -- detach from minimap scaling
    SafeCall(zoomOut.SetParent, zoomOut, UIParent)

    SafeCall(zoomIn.ClearAllPoints, zoomIn)
    SafeCall(zoomOut.ClearAllPoints, zoomOut)

    -- left edge centered
    SafeCall(zoomOut.SetPoint, zoomOut, "LEFT", anchor, "LEFT", -(borderSize + 10), 0)
    SafeCall(zoomIn.SetPoint, zoomIn, "TOP", zoomOut, "BOTTOM", 0, -6)

    if zoomIn.SetFrameStrata then SafeCall(zoomIn.SetFrameStrata, zoomIn, "HIGH") end
    if zoomOut.SetFrameStrata then SafeCall(zoomOut.SetFrameStrata, zoomOut, "HIGH") end
  end

  -- Tracking: top-right edge
  local tracking = trackingBtn or trackingFrame
  if tracking then
    SafeCall(tracking.SetParent, tracking, UIParent)
    SafeCall(tracking.ClearAllPoints, tracking)
    SafeCall(tracking.SetPoint, tracking, "TOPRIGHT", anchor, "TOPRIGHT", borderSize + 10, -borderSize)
    if tracking.SetFrameStrata then SafeCall(tracking.SetFrameStrata, tracking, "HIGH") end
  end

  -- Mail: top edge centered
  if mail then
    SafeCall(mail.SetParent, mail, UIParent)
    SafeCall(mail.ClearAllPoints, mail)
    SafeCall(mail.SetPoint, mail, "TOP", anchor, "TOP", 0, borderSize + 10)
    if mail.SetFrameStrata then SafeCall(mail.SetFrameStrata, mail, "HIGH") end
  end

  -- LFG: bottom-left corner
  if lfg then
    SafeCall(lfg.SetParent, lfg, UIParent)
    SafeCall(lfg.ClearAllPoints, lfg)
    SafeCall(lfg.SetPoint, lfg, "BOTTOMLEFT", anchor, "BOTTOMLEFT", -(borderSize + 10), -(borderSize + 10))
    if lfg.SetFrameStrata then SafeCall(lfg.SetFrameStrata, lfg, "HIGH") end
  end

  -- Ensure the relocated Blizzard buttons are visible
  if zoomIn then SafeShow(zoomIn) end
  if zoomOut then SafeShow(zoomOut) end
  if tracking then SafeShow(tracking) end
  if mail then SafeShow(mail) end
  if lfg then SafeShow(lfg) end
end

-- ------------------------------------------------------------
-- Addon button flyout (ONLY addon icons)
-- ------------------------------------------------------------
local fly = {
  anchor = nil,        -- toggle button
  frame = nil,         -- container
  content = nil,       -- where buttons are parented
  open = false,

  captured = {},       -- [btn] = true
  stored = {},         -- [btn] = { parent, points, strata, level, scale, w, h }
  ordered = {},        -- array of captured for layout
  hooks = {},          -- [btn]=true (reparent guard)
}

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
  SafeCall(frame.ClearAllPoints, frame)
  for i = 1, #t do
    local p, rel, rp, x, y = unpack(t[i])
    if p then SafeCall(frame.SetPoint, frame, p, rel, rp, x, y) end
  end
end

local function StoreBtn(btn)
  if not btn or fly.stored[btn] then return end
  local w, h = 0, 0
  if btn.GetSize then w, h = btn:GetSize() end
  fly.stored[btn] = {
    parent = btn:GetParent(),
    points = CapturePoints(btn),
    strata = btn.GetFrameStrata and btn:GetFrameStrata() or nil,
    level = btn.GetFrameLevel and btn:GetFrameLevel() or nil,
    scale = btn.GetScale and btn:GetScale() or 1,
    w = w, h = h,
  }
end

local function RestoreBtn(btn)
  local pack = fly.stored[btn]
  if not pack or not btn then return end

  if pack.parent and btn:GetParent() ~= pack.parent then SafeCall(btn.SetParent, btn, pack.parent) end
  if btn.SetScale and pack.scale then SafeCall(btn.SetScale, btn, pack.scale) end
  if btn.SetSize and pack.w and pack.h and pack.w > 0 and pack.h > 0 then
    SafeCall(btn.SetSize, btn, pack.w, pack.h)
  end
  if btn.SetFrameStrata and pack.strata then SafeCall(btn.SetFrameStrata, btn, pack.strata) end
  if btn.SetFrameLevel and pack.level then SafeCall(btn.SetFrameLevel, btn, pack.level) end
  RestorePoints(btn, pack.points)

  fly.stored[btn] = nil
  fly.captured[btn] = nil
  fly.hooks[btn] = nil
end

local function IsAddonButton(btn, includeSet, excludeSet, allowLibDBIcon)
  if not btn or not btn.IsObjectType or not btn:IsObjectType("Button") then return false end
  if btn.IsForbidden and btn:IsForbidden() then return false end
  if not btn.GetName then return false end

  local name = btn:GetName()
  if not name or name == "" then return false end

  if excludeSet and excludeSet[name] then return false end
  if includeSet and includeSet[name] then return true end

  if allowLibDBIcon then
    -- Primary allow-list: LibDBIcon buttons
    if name:find("^LibDBIcon10_") then return true end
    if name:find("LibDBIcon", 1, true) then return true end
    if name:find("DBIcon", 1, true) then return true end
  end

  return false
end

local function ScanForAddonButtons(includeSet, excludeSet, allowLibDBIcon)
  local found = {}
  local seen = {}

  local function Scan(parent, depth)
    if not parent or depth <= 0 or not parent.GetChildren then return end
    local kids = { parent:GetChildren() }
    for i = 1, #kids do
      local c = kids[i]
      if c and not seen[c] then
        seen[c] = true
        if IsAddonButton(c, includeSet, excludeSet, allowLibDBIcon) then
          table.insert(found, c)
        end
        Scan(c, depth - 1)
      end
    end
  end

  Scan(mm, 4)
  Scan(mmCluster, 4)

  -- filter out already captured
  local out = {}
  for i = 1, #found do
    local b = found[i]
    if b and not fly.captured[b] then
      table.insert(out, b)
    end
  end

  table.sort(out, function(a, b)
    local an = a:GetName() or ""
    local bn = b:GetName() or ""
    return an < bn
  end)

  return out
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

local function EnsureFlyoutFrames()
  if fly.frame or not mm then return end
  local db = GetDB()
  local c = db and db.collector

  -- Toggle button (≡)
  fly.anchor = CreateFrame("Button", "EnhanceTBC_MinimapFlyoutAnchor", mmCluster or UIParent)
  fly.anchor:SetSize(18, 18)
  fly.anchor:SetFrameStrata("HIGH")
  fly.anchor:SetFrameLevel((mm:GetFrameLevel() or 0) + 500)
  SetIgnoreParentScaleSafe(fly.anchor, true)
  SafeCall(fly.anchor.SetScale, fly.anchor, 1)

  local bg = fly.anchor:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture(WHITE)
  bg:SetAllPoints()
  bg:SetVertexColor(0, 0, 0, 0.35)

  local fs = fly.anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs:SetPoint("CENTER")
  fs:SetText("≡")
  fs:SetTextColor(0.85, 0.90, 0.85, 1)

  -- Flyout box
  fly.frame = CreateFrame("Frame", "EnhanceTBC_MinimapFlyout", UIParent, "BackdropTemplate")
  fly.frame:SetFrameStrata("DIALOG")
  fly.frame:SetFrameLevel((mm:GetFrameLevel() or 0) + 600)
  fly.frame:SetClampedToScreen(true)
  fly.frame:EnableMouse(true)
  fly.frame:Hide()

  SafeCall(fly.frame.SetBackdrop, fly.frame, {
    bgFile = WHITE,
    edgeFile = WHITE,
    tile = false,
    edgeSize = 2,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })

  local bgAlpha = c and clamp(c.bgAlpha, 0, 1) or 0.70
  local borderAlpha = c and clamp(c.borderAlpha, 0, 1) or 0.90
  SafeCall(fly.frame.SetBackdropColor, fly.frame, 0.02, 0.03, 0.02, bgAlpha)
  SafeCall(fly.frame.SetBackdropBorderColor, fly.frame, 0.18, 0.20, 0.18, borderAlpha)

  fly.content = CreateFrame("Frame", nil, fly.frame)
  fly.content:SetPoint("TOPLEFT", fly.frame, "TOPLEFT", 6, -6)
  fly.content:SetPoint("BOTTOMRIGHT", fly.frame, "BOTTOMRIGHT", -6, 6)

  fly.frame:SetMovable(true)
  fly.frame:RegisterForDrag("LeftButton")
  fly.frame:SetScript("OnDragStart", function(self)
    local db2 = GetDB()
    local c2 = db2 and db2.collector
    if c2 and not c2.locked then
      self:StartMoving()
    end
  end)
  fly.frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local db2 = GetDB()
    local c2 = db2 and db2.collector
    if not c2 then return end
    local p, rel, rp, x, y = self:GetPoint(1)
    if p then
      c2.pos.point = p
      c2.pos.relPoint = rp
      c2.pos.x = x
      c2.pos.y = y
    end
  end)

  local function ApplyAnchorPositions()
    local db3 = GetDB()
    local c3 = db3 and db3.collector
    if not c3 then return end

    -- toggle button position relative to minimap border (deco preferred)
    local anchor = deco or mm
    fly.anchor:ClearAllPoints()
    fly.anchor:SetPoint(c3.toggle.point or "TOPRIGHT", anchor, c3.toggle.relPoint or "BOTTOMRIGHT", c3.toggle.x or 2, c3.toggle.y or -2)

    -- flyout box position relative to minimap
    fly.frame:ClearAllPoints()
    fly.frame:SetPoint(c3.pos.point or "TOPRIGHT", anchor, c3.pos.relPoint or "TOPLEFT", c3.pos.x or 8, c3.pos.y or 0)

    local scale = clamp(c3.scale or 1.0, 0.7, 1.5)
    SetIgnoreParentScaleSafe(fly.frame, true)
    SafeCall(fly.frame.SetScale, fly.frame, scale)
  end

  local function OpenOrClose()
    local db4 = GetDB()
    local c4 = db4 and db4.collector
    if not c4 then return end

    if c4.flyoutMode == "ALWAYS" then
      fly.open = true
      fly.frame:Show()
      mod:RefreshFlyout(true)
      return
    end

    if fly.frame:IsShown() then
      fly.open = false
      fly.frame:Hide()
    else
      fly.open = true
      fly.frame:Show()
      mod:RefreshFlyout(true)
    end
  end

  fly.anchor:SetScript("OnClick", OpenOrClose)

  fly.anchor:SetScript("OnEnter", function()
    local db4 = GetDB()
    local c4 = db4 and db4.collector
    if c4 and c4.flyoutMode == "HOVER" then
      fly.open = true
      fly.frame:Show()
      mod:RefreshFlyout(true)
    end
  end)

  fly.anchor:SetScript("OnLeave", function()
    local db4 = GetDB()
    local c4 = db4 and db4.collector
    if c4 and c4.flyoutMode == "HOVER" then
      -- don’t instantly hide if moving into the frame
      if fly.frame and fly.frame.IsMouseOver and fly.frame:IsMouseOver() then return end
      fly.open = false
      fly.frame:Hide()
    end
  end)

  fly.frame:SetScript("OnLeave", function()
    local db4 = GetDB()
    local c4 = db4 and db4.collector
    if c4 and c4.flyoutMode == "HOVER" then
      if fly.anchor and fly.anchor.IsMouseOver and fly.anchor:IsMouseOver() then return end
      fly.open = false
      fly.frame:Hide()
    end
  end)

  fly.ApplyAnchorPositions = ApplyAnchorPositions
  ApplyAnchorPositions()
end

local function LayoutFlyout()
  if not fly.frame or not fly.content then return end
  local db = GetDB()
  local c = db and db.collector
  if not c then return end

  BuildOrderedCaptured()

  local size = clamp(c.iconSize, 16, 42)
  local colsMax = clamp(c.columns, 1, 12)
  local spacing = clamp(c.spacing, 0, 14)
  local padding = clamp(c.padding, 0, 16)

  local total = #fly.ordered
  if total < 1 then
    SafeCall(fly.frame.SetSize, fly.frame, size + padding * 2 + 2, size + padding * 2 + 2)
    if fly.ApplyAnchorPositions then fly.ApplyAnchorPositions() end
    return
  end

  local cols = math.min(colsMax, total)
  local rows = math.ceil(total / cols)

  local w = padding * 2 + (cols * size) + ((cols - 1) * spacing)
  local h = padding * 2 + (rows * size) + ((rows - 1) * spacing)

  SafeCall(fly.frame.SetSize, fly.frame, w, h)

  -- Place buttons
  for i = 1, total do
    local b = fly.ordered[i]
    if b then
      local r = math.floor((i - 1) / cols)
      local cidx = (i - 1) % cols

      SafeCall(b.ClearAllPoints, b)
      SafeCall(b.SetParent, b, fly.content)
      SetIgnoreParentScaleSafe(b, true)
      SafeCall(b.SetScale, b, 1)
      SafeCall(b.SetSize, b, size, size)

      if b.SetFrameStrata then SafeCall(b.SetFrameStrata, b, "DIALOG") end
      if b.SetFrameLevel then SafeCall(b.SetFrameLevel, b, fly.frame:GetFrameLevel() + 10) end

      SafeCall(b.SetPoint, b, "TOPLEFT", fly.content, "TOPLEFT",
        padding + cidx * (size + spacing),
        -(padding + r * (size + spacing))
      )

      -- Ensure clickable
      if b.EnableMouse then SafeCall(b.EnableMouse, b, true) end
      if b.SetHitRectInsets then SafeCall(b.SetHitRectInsets, b, 0, 0, 0, 0) end
      SafeShow(b)
    end
  end

  if fly.ApplyAnchorPositions then fly.ApplyAnchorPositions() end
end

function mod:RefreshFlyout(forceScan)
  local db = GetDB()
  if not db or not mm then return end
  local c = db.collector
  if not c then return end

  EnsureFlyoutFrames()

  if not (db.enabled and c.enabled) then
    -- restore everything when collector disabled
    for btn in pairs(fly.stored) do RestoreBtn(btn) end
    wipe(fly.ordered)
    if fly.frame then fly.frame:Hide() end
    if fly.anchor then fly.anchor:Hide() end
    fly.open = false
    return
  end

  if fly.anchor then fly.anchor:Show() end

  -- Always-mode forces open
  if c.flyoutMode == "ALWAYS" then
    fly.open = true
    fly.frame:Show()
  end

  if not fly.open and c.flyoutMode ~= "ALWAYS" then
    -- still keep capturing in background, but don’t waste layout time unless needed
  end

  local includeSet = ParseNameList(c.includeExtra)
  local excludeSet = ParseNameList(c.exclude)

  if forceScan or true then
    local newButtons = ScanForAddonButtons(includeSet, excludeSet, c.includeLibDBIcon)

    for i = 1, #newButtons do
      local btn = newButtons[i]
      if btn and not fly.captured[btn] then
        StoreBtn(btn)
        fly.captured[btn] = true

        -- Guard against reparent by the icon library: hook OnShow and reparent back when needed
        if not fly.hooks[btn] and btn.HookScript then
          fly.hooks[btn] = true
          SafeCall(btn.HookScript, btn, "OnShow", function(b)
            if fly.captured[b] and fly.content and b:GetParent() ~= fly.content then
              SafeCall(b.SetParent, b, fly.content)
              SetIgnoreParentScaleSafe(b, true)
              SafeCall(b.SetScale, b, 1)
            end
          end)
        end
      end
    end
  end

  -- Re-parent any captured button that wandered back to minimap
  for btn in pairs(fly.captured) do
    if btn and fly.stored[btn] then
      if fly.content and btn:GetParent() ~= fly.content then
        SafeCall(btn.SetParent, btn, fly.content)
      end
      SetIgnoreParentScaleSafe(btn, true)
      SafeCall(btn.SetScale, btn, 1)
      if btn.SetFrameStrata then SafeCall(btn.SetFrameStrata, btn, "DIALOG") end
      if btn.SetFrameLevel then SafeCall(btn.SetFrameLevel, btn, fly.frame:GetFrameLevel() + 10) end
      if btn.EnableMouse then SafeCall(btn.EnableMouse, btn, true) end
      SafeShow(btn)
    end
  end

  -- Update flyout styling each refresh
  if fly.frame and fly.frame.SetBackdropColor then
    SafeCall(fly.frame.SetBackdropColor, fly.frame, 0.02, 0.03, 0.02, clamp(c.bgAlpha, 0, 1))
  end
  if fly.frame and fly.frame.SetBackdropBorderColor then
    SafeCall(fly.frame.SetBackdropBorderColor, fly.frame, 0.18, 0.20, 0.18, clamp(c.borderAlpha, 0, 1))
  end

  if fly.ApplyAnchorPositions then fly.ApplyAnchorPositions() end
  if fly.open or c.flyoutMode == "ALWAYS" then
    LayoutFlyout()
  end
end

-- ------------------------------------------------------------
-- Apply (main)
-- ------------------------------------------------------------
function mod:Apply()
  local db = GetDB()
  if not db or not mm then return end

  if not db.enabled then
    -- restore default-ish
    if mm.SetMaskTexture then SafeCall(mm.SetMaskTexture, mm, MASK_CIRCLE) end
    if deco then SafeHide(deco) end

    -- restore flyout buttons if collector disabled via master
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

  -- restore/position zone + clock (we always want them visible)
  ApplyZoneAndClock()

  -- Normalize Blizzard buttons (and position them)
  ApplyBlizzButtonsLayout()

  -- Flyout
  EnsureFlyoutFrames()

  local c = db.collector
  if c and c.enabled then
    if fly.anchor then fly.anchor:Show() end

    -- startOpen behavior (once per session)
    if c.startOpen and not fly._startOpenDone then
      fly._startOpenDone = true
      fly.open = true
      fly.frame:Show()
    end

    -- ALWAYS-mode behavior
    if c.flyoutMode == "ALWAYS" then
      fly.open = true
      fly.frame:Show()
    end

    self:RefreshFlyout(true)
  else
    -- collector off => restore addon buttons
    for btn in pairs(fly.stored) do RestoreBtn(btn) end
    wipe(fly.ordered)
    if fly.frame then fly.frame:Hide() end
    if fly.anchor then fly.anchor:Hide() end
    fly.open = false
  end

  -- Some Blizzard frames (tracking in particular) can appear late: re-apply shortly after
  if C_Timer and C_Timer.After then
    C_Timer.After(0.5, function()
      SafeCall(ApplyBlizzButtonsLayout)
      SafeCall(ApplyZoneAndClock)
      SafeCall(mod.RefreshFlyout, mod, true)
    end)
  end
end

-- ------------------------------------------------------------
-- Events
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
    -- New LDB icons can appear after addon load; refresh flyout shortly after
    if C_Timer and C_Timer.After then
      C_Timer.After(0.25, function()
        local db = GetDB()
        local c = db and db.collector
        if db and db.enabled and c and c.enabled then
          SafeCall(mod.RefreshFlyout, mod, true)
        end
      end)
    end
  end
end)

-- ------------------------------------------------------------
-- ApplyBus bindings
-- ------------------------------------------------------------
if ETBC.ApplyBus and ETBC.ApplyBus.Register then
  ETBC.ApplyBus:Register("minimap", function() SafeCall(mod.Apply, mod) end)
  ETBC.ApplyBus:Register("general", function() SafeCall(mod.Apply, mod) end)
end

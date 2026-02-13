-- Modules/Minimap.lua
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

local function clamp(v, lo, hi)
  v = tonumber(v) or lo
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function SafeCall(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, err = pcall(fn, ...)
  return ok, err
end

-- ------------------------------------------------------------
-- DB (matches Settings/Settings_Minimap.lua)
-- ------------------------------------------------------------
local function GetDB()
  if not ETBC or not ETBC.db or not ETBC.db.profile then return nil end
  ETBC.db.profile.minimap = ETBC.db.profile.minimap or {}
  local db = ETBC.db.profile.minimap

  if db.enabled == nil then db.enabled = true end
  if db.shape == nil then db.shape = "CIRCLE" end
  if db.squareSize == nil then db.squareSize = 140 end
  if db.mapScale == nil then db.mapScale = 1.0 end

  if db.hideDayNight == nil then db.hideDayNight = true end

  db.border = db.border or {}
  if db.border.enabled == nil then db.border.enabled = true end
  if db.border.size == nil then db.border.size = 2 end
  if db.border.alpha == nil then db.border.alpha = 0.90 end
  if db.border.r == nil then db.border.r = 0.15 end
  if db.border.g == nil then db.border.g = 0.15 end
  if db.border.b == nil then db.border.b = 0.15 end

  db.background = db.background or {}
  if db.background.enabled == nil then db.background.enabled = false end
  if db.background.alpha == nil then db.background.alpha = 0 end
  if db.background.r == nil then db.background.r = 0 end
  if db.background.g == nil then db.background.g = 0 end
  if db.background.b == nil then db.background.b = 0 end

  db.collector = db.collector or {}
  local c = db.collector
  if c.enabled == nil then c.enabled = true end
  if c.flyoutMode == nil then c.flyoutMode = "CLICK" end
  if c.startOpen == nil then c.startOpen = false end
  if c.locked == nil then c.locked = true end
  if c.iconSize == nil then c.iconSize = 28 end
  if c.columns == nil then c.columns = 6 end
  if c.spacing == nil then c.spacing = 4 end
  if c.padding == nil then c.padding = 6 end
  if c.scale == nil then c.scale = 1.0 end
  if c.bgAlpha == nil then c.bgAlpha = 0.35 end
  if c.borderAlpha == nil then c.borderAlpha = 0.85 end
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

  return db
end

-- ------------------------------------------------------------
-- original minimap size for restore
-- ------------------------------------------------------------
local orig = { stored=false, w=nil, h=nil }
local function StoreOriginalSize()
  if orig.stored or not mm or not mm.GetSize then return end
  orig.w, orig.h = mm:GetSize()
  orig.stored = true
end

local function ApplySizeAndScale(db)
  if not mm then return end
  StoreOriginalSize()

  mm:SetScale(clamp(db.mapScale, 0.70, 1.50))

  if db.shape == "SQUARE" then
    local size = clamp(db.squareSize, 110, 220)
    mm:SetSize(size, size)
  else
    if orig.stored and orig.w and orig.h then
      mm:SetSize(orig.w, orig.h)
    end
  end
end

-- ------------------------------------------------------------
-- Deco border (no forced dark background)
-- ------------------------------------------------------------
local deco
local function EnsureDeco()
  if deco or not mm then return end
  deco = CreateFrame("Frame", "EnhanceTBC_MinimapDeco", mm, "BackdropTemplate")
  deco:SetAllPoints(mm)
  deco:SetFrameStrata(mm:GetFrameStrata())
  deco:SetFrameLevel(mm:GetFrameLevel() + 50)
end

local function ApplyDeco(db)
  EnsureDeco()
  if not deco then return end

  local b = db.border or {}
  local bg = db.background or {}

  local edge = clamp(b.size, 1, 8)
  deco:SetBackdrop({
    bgFile = WHITE,
    edgeFile = WHITE,
    tile = false,
    edgeSize = edge,
    insets = { left=1,right=1,top=1,bottom=1 },
  })

  if bg.enabled and (bg.alpha or 0) > 0 then
    deco:SetBackdropColor(bg.r or 0, bg.g or 0, bg.b or 0, clamp(bg.alpha, 0, 1))
  else
    deco:SetBackdropColor(0,0,0,0)
  end

  if b.enabled then
    deco:SetBackdropBorderColor(b.r or 0.15, b.g or 0.15, b.b or 0.15, clamp(b.alpha, 0, 1))
    deco:Show()
  else
    deco:SetBackdropBorderColor(0,0,0,0)
    if bg.enabled and (bg.alpha or 0) > 0 then deco:Show() else deco:Hide() end
  end
end

-- ------------------------------------------------------------
-- Square artifacts (hide only top border junk)
-- ------------------------------------------------------------
local function HardHide(obj)
  if not obj then return end
  if obj.Hide then obj:Hide() end
  if obj.SetShown then obj:SetShown(false) end
  if obj.SetAlpha then obj:SetAlpha(0) end
end

local function KeepHiddenInSquare(obj)
  if not obj or not obj.HookScript then return end
  obj:HookScript("OnShow", function(self)
    local db = GetDB()
    if db and db.enabled and db.shape == "SQUARE" then
      HardHide(self)
    end
  end)
end

local visualsHooked = false
local function HookVisualsOnce()
  if visualsHooked then return end
  visualsHooked = true

  KeepHiddenInSquare(_G.MinimapBorder)
  KeepHiddenInSquare(_G.MinimapBorderTop)
  KeepHiddenInSquare(mmCluster and mmCluster.BorderTop)
  KeepHiddenInSquare(mmCluster and mmCluster.Border)
  KeepHiddenInSquare(_G.MinimapClusterBorderTop)
  KeepHiddenInSquare(_G.MinimapClusterBorder)

  if mmCluster and mmCluster.NineSlice then
    KeepHiddenInSquare(mmCluster.NineSlice.TopEdge)
    KeepHiddenInSquare(mmCluster.NineSlice.TopLeftCorner)
    KeepHiddenInSquare(mmCluster.NineSlice.TopRightCorner)
  end
end

local function ApplyShape(db)
  if not mm or not mm.SetMaskTexture then return end
  HookVisualsOnce()

  local square = (db.shape == "SQUARE")
  mm:SetMaskTexture(square and MASK_SQUARE or MASK_CIRCLE)

  if square then
    HardHide(_G.MinimapBorder)
    HardHide(_G.MinimapBorderTop)
    HardHide(mmCluster and mmCluster.BorderTop)
    HardHide(mmCluster and mmCluster.Border)
    HardHide(_G.MinimapClusterBorderTop)
    HardHide(_G.MinimapClusterBorder)
  end

  if db.hideDayNight then
    HardHide(_G.GameTimeFrame)
  end
end

-- ------------------------------------------------------------
-- Zone text + Clock
--  - Zone scales with minimap
--  - Clock scales with minimap and sits bottom-center
--  - Both raised above border frame level
-- ------------------------------------------------------------
local function ApplyZoneAndClock()
  if not mm then return end

  local zbtn = _G.MinimapZoneTextButton
  local ztxt = _G.MinimapZoneText
  local clock = _G.TimeManagerClockButton

  if zbtn then
    zbtn:SetParent(mm)
    if zbtn.SetFrameStrata then zbtn:SetFrameStrata(mm:GetFrameStrata()) end
    if zbtn.SetFrameLevel then zbtn:SetFrameLevel(mm:GetFrameLevel() + 90) end

    zbtn:ClearAllPoints()
    zbtn:SetPoint("BOTTOM", mm, "TOP", 0, 6)

    if zbtn.Show then zbtn:Show() end
    if zbtn.SetAlpha then zbtn:SetAlpha(1) end
  end

  if ztxt then
    ztxt:ClearAllPoints()
    ztxt:SetPoint("CENTER", zbtn or mm, "CENTER", 0, 0)
    ztxt:SetJustifyH("CENTER")
  end

  if clock then
    clock:SetParent(mm)
    if clock.SetFrameStrata then clock:SetFrameStrata(mm:GetFrameStrata()) end
    if clock.SetFrameLevel then clock:SetFrameLevel(mm:GetFrameLevel() + 95) end

    clock:ClearAllPoints()
    -- ✅ bottom center as requested
    clock:SetPoint("BOTTOM", mm, "BOTTOM", 0, 8)

    if clock.Show then clock:Show() end
    if clock.SetAlpha then clock:SetAlpha(1) end
  end
end

-- ------------------------------------------------------------
-- Blizzard icons: detach from minimap scale AND HARD normalize size
-- ------------------------------------------------------------
local function GetEffectiveScale(f)
  if not f then return 1 end
  if f.GetEffectiveScale then
    local ok, v = pcall(f.GetEffectiveScale, f)
    if ok and type(v) == "number" and v > 0 then return v end
  end
  if f.GetScale then
    local ok, v = pcall(f.GetScale, f)
    if ok and type(v) == "number" and v > 0 then return v end
  end
  return 1
end

local function DetachNoScale(f)
  if not f or not f.SetParent then return end
  f:SetParent(UIParent)

  if f.SetIgnoreParentScale then
    f:SetIgnoreParentScale(true)
    if f.SetScale then f:SetScale(1) end
    return
  end

  local parentScale = GetEffectiveScale(mm)
  if parentScale <= 0 then parentScale = 1 end
  if f.SetScale then
    f:SetScale(1 / parentScale)
  end
end

local function ForceRegionToSize(r, size)
  if not r then return end
  if r.SetScale then r:SetScale(1) end

  local ot = r.GetObjectType and r:GetObjectType()
  if ot == "Texture" then
    if r.SetTexCoord then
      -- crop so circles/rings don't blow out of bounds
      pcall(r.SetTexCoord, r, 0.08, 0.92, 0.08, 0.92)
    end
    if r.ClearAllPoints then r:ClearAllPoints() end
    if r.SetAllPoints then r:SetAllPoints() end
    if r.SetSize then r:SetSize(size, size) end
  elseif ot == "FontString" then
    -- leave fonts alone (clock text etc.)
  end
end

local function NormalizeAnyFrame(f, size)
  if not f then return end
  size = clamp(size or 32, 18, 42)

  if f.SetScale then f:SetScale(1) end
  if f.SetSize then f:SetSize(size, size) end

  -- Force all regions (textures) to fill this frame
  if f.GetRegions then
    local regions = { f:GetRegions() }
    for i = 1, #regions do
      ForceRegionToSize(regions[i], size)
    end
  end

  -- Force common button textures too
  local nt = f.GetNormalTexture and f:GetNormalTexture()
  local pt = f.GetPushedTexture and f:GetPushedTexture()
  local ht = f.GetHighlightTexture and f:GetHighlightTexture()
  ForceRegionToSize(nt, size)
  ForceRegionToSize(pt, size)
  ForceRegionToSize(ht, size)

  -- Normalize children (many Blizzard widgets hide a button inside a frame)
  if f.GetChildren then
    local kids = { f:GetChildren() }
    for i = 1, #kids do
      local c = kids[i]
      if c and c.GetObjectType and (c:GetObjectType() == "Button" or c:GetObjectType() == "Frame") then
        if c.SetScale then c:SetScale(1) end
        if c.SetSize then c:SetSize(size, size) end

        local cnt = c.GetNormalTexture and c:GetNormalTexture()
        local cpt = c.GetPushedTexture and c:GetPushedTexture()
        local cht = c.GetHighlightTexture and c:GetHighlightTexture()
        ForceRegionToSize(cnt, size)
        ForceRegionToSize(cpt, size)
        ForceRegionToSize(cht, size)

        if c.GetRegions then
          local r2 = { c:GetRegions() }
          for j = 1, #r2 do
            ForceRegionToSize(r2[j], size)
          end
        end
      end
    end
  end
end

local function AnchorNoScale(f, point, rel, relPoint, x, y, size)
  if not f then return end
  DetachNoScale(f)
  NormalizeAnyFrame(f, size)
  if f.ClearAllPoints then f:ClearAllPoints() end
  if f.SetPoint then f:SetPoint(point, rel, relPoint, x, y) end
  if f.SetFrameStrata then f:SetFrameStrata("HIGH") end
  if f.SetFrameLevel and mm and mm.GetFrameLevel then f:SetFrameLevel(mm:GetFrameLevel() + 120) end
end

local function ResolveTracking()
  return _G.MiniMapTrackingFrame or _G.MiniMapTracking
end

local function ResolveTrackingButton()
  return _G.MiniMapTrackingButton
end

local function ResolveMail()
  return _G.MiniMapMailFrame or _G.MinimapMailFrame
end

local function ResolveMailIcon()
  return _G.MiniMapMailIcon
end

local function ResolveLFG()
  return _G.MiniMapLFGFrame or _G.QueueStatusMinimapButton or _G.MinimapLFGFrame
end

local function ApplyButtonLayout()
  if not mm then return end
  local iconSize = 32

  local zoomIn = _G.MinimapZoomIn
  local zoomOut = _G.MinimapZoomOut

  local trackingFrame = ResolveTracking()
  local trackingBtn = ResolveTrackingButton()

  local mailFrame = ResolveMail()
  local mailIcon = ResolveMailIcon()

  local lfg = ResolveLFG()

  -- LFG bottom-left corner
  if lfg then AnchorNoScale(lfg, "BOTTOMLEFT", mm, "BOTTOMLEFT", -10, -10, iconSize) end

  -- Zoom on left edge centered
  if zoomIn then AnchorNoScale(zoomIn, "LEFT", mm, "LEFT", -18, 8, iconSize) end
  if zoomOut then AnchorNoScale(zoomOut, "LEFT", mm, "LEFT", -18, -8, iconSize) end

  -- Mail top edge centered
  if mailFrame then
    AnchorNoScale(mailFrame, "TOP", mm, "TOP", 0, 10, iconSize)
    if mailIcon then
      -- mail icon is a child texture/frame in some builds; force it too
      NormalizeAnyFrame(mailIcon, iconSize)
    end
  end

  -- Tracking top-right edge
  if trackingFrame then
    AnchorNoScale(trackingFrame, "TOPRIGHT", mm, "TOPRIGHT", 10, 10, iconSize)
  end
  if trackingBtn then
    -- Some clients draw the actual button separately; hard force it too
    AnchorNoScale(trackingBtn, "TOPRIGHT", mm, "TOPRIGHT", 10, 10, iconSize)
  end
end

-- ------------------------------------------------------------
-- Flyout (kept as-is; we’ll tackle Questie capture next after sizing is fixed)
-- ------------------------------------------------------------
local fly = { box=nil, toggle=nil, open=false }

local function EnsureFlyoutStub()
  if fly.toggle or not mm then return end
  fly.toggle = CreateFrame("Button", "EnhanceTBC_MinimapFlyoutToggle", UIParent)
  fly.toggle:SetSize(18,18)
  fly.toggle:SetFrameStrata("HIGH")
  fly.toggle:SetFrameLevel((mmCluster and mmCluster:GetFrameLevel() or mm:GetFrameLevel()) + 300)
  DetachNoScale(fly.toggle)

  local tbg = fly.toggle:CreateTexture(nil, "BACKGROUND")
  tbg:SetTexture(WHITE)
  tbg:SetAllPoints()
  tbg:SetVertexColor(0,0,0,0.35)

  local fs = fly.toggle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs:SetPoint("CENTER")
  fs:SetText("≡")
  fs:SetTextColor(0.9,0.9,0.9,1)

  fly.box = CreateFrame("Frame", "EnhanceTBC_MinimapFlyoutBox", UIParent, "BackdropTemplate")
  fly.box:SetFrameStrata("HIGH")
  fly.box:SetFrameLevel(fly.toggle:GetFrameLevel() + 10)
  fly.box:SetSize(180, 60)
  fly.box:Hide()
  fly.box:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, tile=false, edgeSize=2, insets={left=1,right=1,top=1,bottom=1} })
  fly.box:SetBackdropColor(0,0,0,0.35)
  fly.box:SetBackdropBorderColor(0.15,0.15,0.15,0.85)

  fly.toggle:SetScript("OnClick", function()
    fly.open = not fly.open
    if fly.open then fly.box:Show() else fly.box:Hide() end
  end)
end

local function ApplyFlyoutToggleAnchor()
  local db = GetDB()
  if not db or not db.collector or not fly.toggle then return end
  local c = db.collector
  fly.toggle:ClearAllPoints()
  fly.toggle:SetPoint(c.toggle.point, mm, c.toggle.relPoint, c.toggle.x, c.toggle.y)

  fly.box:ClearAllPoints()
  fly.box:SetPoint(c.pos.point, mm, c.pos.relPoint, c.pos.x, c.pos.y)
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
    if fly.box then fly.box:Hide() end
    if fly.toggle then fly.toggle:Hide() end
    return
  end

  ApplySizeAndScale(db)
  ApplyShape(db)
  ApplyDeco(db)

  -- Zone + clock (clock bottom center)
  ApplyZoneAndClock()

  -- Blizzard buttons (should now be 32px, not huge)
  ApplyButtonLayout()

  -- Flyout stub (we’ll re-enable full capture next)
  if db.collector and db.collector.enabled then
    EnsureFlyoutStub()
    fly.toggle:Show()
    ApplyFlyoutToggleAnchor()
  else
    if fly.box then fly.box:Hide() end
    if fly.toggle then fly.toggle:Hide() end
  end
end

-- ------------------------------------------------------------
-- ApplyBus registration
-- ------------------------------------------------------------
local function ApplyFromBus()
  SafeCall(mod.Apply, mod)
end

if ETBC.ApplyBus and ETBC.ApplyBus.Register then
  ETBC.ApplyBus:Register("minimap", ApplyFromBus)
  ETBC.ApplyBus:Register("general", ApplyFromBus)
end

-- ------------------------------------------------------------
-- Events
-- ------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
  if not ETBC or not ETBC.db then return end
  SafeCall(mod.Apply, mod)
end)

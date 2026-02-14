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
  pcall(fn, ...)
end

-- ------------------------------------------------------------
-- DB (compat: Settings_Minimap.lua currently uses db.collector)
-- ------------------------------------------------------------
local function GetDB()
  if not ETBC or not ETBC.db or not ETBC.db.profile then return nil end
  ETBC.db.profile.minimap = ETBC.db.profile.minimap or {}
  local db = ETBC.db.profile.minimap

  if db.enabled == nil then db.enabled = true end
  if db.shape == nil then db.shape = "CIRCLE" end
  if db.mapScale == nil then db.mapScale = 1.0 end
  if db.squareSize == nil then db.squareSize = 140 end

  -- Border (minimal, stylish, no backdrop)
  db.border = db.border or {}
  if db.border.enabled == nil then db.border.enabled = true end
  if db.border.size == nil then db.border.size = 2 end
  if db.border.alpha == nil then db.border.alpha = 0.90 end
  if db.border.r == nil then db.border.r = 0.18 end
  if db.border.g == nil then db.border.g = 0.20 end
  if db.border.b == nil then db.border.b = 0.18 end

  -- Zone text
  db.zoneText = db.zoneText or {}
  if db.zoneText.enabled == nil then db.zoneText.enabled = true end
  if db.zoneText.point == nil then db.zoneText.point = "TOP" end
  if db.zoneText.x == nil then db.zoneText.x = 0 end
  if db.zoneText.y == nil then db.zoneText.y = -2 end
  if db.zoneText.fontSize == nil then db.zoneText.fontSize = 12 end
  if db.zoneText.alpha == nil then db.zoneText.alpha = 1.0 end

  -- Clock
  db.clock = db.clock or {}
  if db.clock.enabled == nil then db.clock.enabled = true end
  if db.clock.fontSize == nil then db.clock.fontSize = 12 end
  if db.clock.alpha == nil then db.clock.alpha = 1.0 end

  -- Blizzard buttons (tracking/mail/lfg), not scaled with minimap
  db.blizzButtons = db.blizzButtons or {}
  if db.blizzButtons.enabled == nil then db.blizzButtons.enabled = true end
  if db.blizzButtons.size == nil then db.blizzButtons.size = 32 end

  db.blizzButtons.tracking = db.blizzButtons.tracking or {}
  if db.blizzButtons.tracking.point == nil then db.blizzButtons.tracking.point = "TOPRIGHT" end
  if db.blizzButtons.tracking.relPoint == nil then db.blizzButtons.tracking.relPoint = "TOPRIGHT" end
  if db.blizzButtons.tracking.x == nil then db.blizzButtons.tracking.x = 6 end
  if db.blizzButtons.tracking.y == nil then db.blizzButtons.tracking.y = -2 end

  db.blizzButtons.mail = db.blizzButtons.mail or {}
  if db.blizzButtons.mail.point == nil then db.blizzButtons.mail.point = "TOP" end
  if db.blizzButtons.mail.relPoint == nil then db.blizzButtons.mail.relPoint = "TOP" end
  if db.blizzButtons.mail.x == nil then db.blizzButtons.mail.x = 0 end
  if db.blizzButtons.mail.y == nil then db.blizzButtons.mail.y = 6 end

  db.blizzButtons.lfg = db.blizzButtons.lfg or {}
  if db.blizzButtons.lfg.point == nil then db.blizzButtons.lfg.point = "BOTTOMLEFT" end
  if db.blizzButtons.lfg.relPoint == nil then db.blizzButtons.lfg.relPoint = "BOTTOMLEFT" end
  if db.blizzButtons.lfg.x == nil then db.blizzButtons.lfg.x = -2 end
  if db.blizzButtons.lfg.y == nil then db.blizzButtons.lfg.y = -2 end

  -- ==========================================
  -- COMPAT LAYER:
  -- Your Settings_Minimap.lua uses db.collector.*
  -- We mirror that into db.flyout.* so the module
  -- always has one canonical place to read/write.
  -- ==========================================
  db.collector = db.collector or {}
  local c = db.collector

  db.flyout = db.flyout or {}
  local f = db.flyout

  -- Legacy collector fallback only when flyout field is missing.
  if f.enabled == nil and c.enabled ~= nil then f.enabled = c.enabled end
  if f.locked == nil and c.locked ~= nil then f.locked = c.locked end
  if f.iconSize == nil and c.iconSize ~= nil then f.iconSize = c.iconSize end
  if f.columns == nil and c.columns ~= nil then f.columns = c.columns end
  if f.spacing == nil and c.spacing ~= nil then f.spacing = c.spacing end
  if f.padding == nil and c.padding ~= nil then f.padding = c.padding end
  if f.scale == nil and c.scale ~= nil then f.scale = c.scale end
  if f.bgAlpha == nil and c.bgAlpha ~= nil then f.bgAlpha = c.bgAlpha end
  if f.borderAlpha == nil and c.borderAlpha ~= nil then f.borderAlpha = c.borderAlpha end
  if f.includeExtra == nil and c.includeExtra ~= nil then f.includeExtra = c.includeExtra end
  if f.exclude == nil and c.exclude ~= nil then f.exclude = c.exclude end
  if f.startOpen == nil and c.startOpen ~= nil then f.startOpen = c.startOpen end

  c.pos = c.pos or {}
  c.toggle = c.toggle or {}

  f.pos = f.pos or {}
  f.toggle = f.toggle or {}

  -- mirror positions (collector -> flyout only when missing)
  if f.pos.point == nil and c.pos.point ~= nil then f.pos.point = c.pos.point end
  if f.pos.relPoint == nil and c.pos.relPoint ~= nil then f.pos.relPoint = c.pos.relPoint end
  if f.pos.x == nil and c.pos.x ~= nil then f.pos.x = c.pos.x end
  if f.pos.y == nil and c.pos.y ~= nil then f.pos.y = c.pos.y end

  if f.toggle.point == nil and c.toggle.point ~= nil then f.toggle.point = c.toggle.point end
  if f.toggle.relPoint == nil and c.toggle.relPoint ~= nil then f.toggle.relPoint = c.toggle.relPoint end
  if f.toggle.x == nil and c.toggle.x ~= nil then f.toggle.x = c.toggle.x end
  if f.toggle.y == nil and c.toggle.y ~= nil then f.toggle.y = c.toggle.y end

  -- defaults if nil anywhere
  if f.enabled == nil then f.enabled = true end
  if f.locked == nil then f.locked = true end
  if f.startOpen == nil then f.startOpen = false end
  if f.iconSize == nil then f.iconSize = 28 end
  if f.columns == nil then f.columns = 6 end
  if f.spacing == nil then f.spacing = 4 end
  if f.padding == nil then f.padding = 6 end
  if f.scale == nil then f.scale = 1.0 end
  if f.bgAlpha == nil then f.bgAlpha = 0.70 end
  if f.borderAlpha == nil then f.borderAlpha = 0.90 end
  if f.includeExtra == nil then f.includeExtra = "" end
  if f.exclude == nil then f.exclude = "" end

  if f.pos.point == nil then f.pos.point = "TOPRIGHT" end
  if f.pos.relPoint == nil then f.pos.relPoint = "BOTTOMRIGHT" end
  if f.pos.x == nil then f.pos.x = 0 end
  if f.pos.y == nil then f.pos.y = -8 end

  if f.toggle.point == nil then f.toggle.point = "BOTTOM" end
  if f.toggle.relPoint == nil then f.toggle.relPoint = "BOTTOM" end
  if f.toggle.x == nil then f.toggle.x = 0 end
  if f.toggle.y == nil then f.toggle.y = -14 end

  -- keep collector in sync for legacy readers
  c.enabled, c.locked, c.startOpen = f.enabled, f.locked, f.startOpen
  c.iconSize, c.columns, c.spacing, c.padding = f.iconSize, f.columns, f.spacing, f.padding
  c.scale, c.bgAlpha, c.borderAlpha = f.scale, f.bgAlpha, f.borderAlpha
  c.includeExtra, c.exclude = f.includeExtra, f.exclude
  c.pos.point, c.pos.relPoint, c.pos.x, c.pos.y = f.pos.point, f.pos.relPoint, f.pos.x, f.pos.y
  c.toggle.point, c.toggle.relPoint, c.toggle.x, c.toggle.y = f.toggle.point, f.toggle.relPoint, f.toggle.x, f.toggle.y

  return db
end

-- ------------------------------------------------------------
-- Kill old flyout junk (“2 flyout toggles” fix)
-- ------------------------------------------------------------
local function KillAllOtherFlyoutFrames()
  local keep = {
    ["EnhanceTBC_MinimapFlyoutToggle"] = true,
    ["EnhanceTBC_MinimapFlyout"] = true,
    ["EnhanceTBC_MinimapFlyoutContent"] = true,
    ["EnhanceTBC_MinimapFlyoutDrag"] = true,
  }

  local f = EnumerateFrames and EnumerateFrames()
  while f do
    local n = f.GetName and f:GetName()
    if n and n:find("MinimapFlyout") and not keep[n] then
      if f.Hide then f:Hide() end
      if f.SetScript then
        f:SetScript("OnClick", nil)
        f:SetScript("OnEnter", nil)
        f:SetScript("OnLeave", nil)
        f:SetScript("OnMouseDown", nil)
        f:SetScript("OnMouseUp", nil)
      end
      if f.EnableMouse then f:EnableMouse(false) end
    end
    f = EnumerateFrames(f)
  end
end

-- ------------------------------------------------------------
-- Store original minimap size/scale
-- ------------------------------------------------------------
local orig = { stored=false, w=nil, h=nil, scale=nil }
local function StoreOriginal()
  if orig.stored or not mm then return end
  orig.w, orig.h = mm:GetSize()
  orig.scale = mm:GetScale()
  orig.stored = true
end

-- ------------------------------------------------------------
-- Border (no backdrop)
-- ------------------------------------------------------------
local deco
local function EnsureDeco()
  if deco or not mm then return end
  deco = CreateFrame("Frame", "EnhanceTBC_MinimapBorder", mm, "BackdropTemplate")
  deco:SetAllPoints(mm)
  deco:SetFrameStrata(mm:GetFrameStrata())
  deco:SetFrameLevel(mm:GetFrameLevel() + 50)
  deco:EnableMouse(false)
end

local function ApplyBorder(db)
  EnsureDeco()
  if not deco then return end

  if db.border and db.border.enabled == false then
    deco:Hide()
    return
  end

  local edge = clamp((db.border and db.border.size) or 2, 1, 8)
  deco:SetBackdrop({
    bgFile = nil,
    edgeFile = WHITE,
    tile = false,
    edgeSize = edge,
    insets = { left=0, right=0, top=0, bottom=0 },
  })
  deco:SetBackdropBorderColor(
    (db.border and db.border.r) or 0.18,
    (db.border and db.border.g) or 0.20,
    (db.border and db.border.b) or 0.18,
    clamp((db.border and db.border.alpha) or 0.90, 0, 1)
  )
  deco:Show()
end

-- ------------------------------------------------------------
-- Shape + size + scale
-- ------------------------------------------------------------
local function ApplyShapeAndScale(db)
  if not mm then return end
  StoreOriginal()

  mm:SetScale(clamp(db.mapScale or 1.0, 0.70, 1.50))

  if db.shape == "SQUARE" then
    local s = clamp(db.squareSize or 140, 110, 220)
    mm:SetSize(s, s)
    mm:SetMaskTexture(MASK_SQUARE)
  else
    if orig.w and orig.h then mm:SetSize(orig.w, orig.h) end
    mm:SetMaskTexture(MASK_CIRCLE)
  end
end

local function ApplyDefaultArt(db)
  local square = (db.shape == "SQUARE")

  local ring = {
    _G.MinimapBorder,
    _G.MinimapBorderTop,
    _G.MinimapCompassTexture,
    _G.MinimapNorthTag,
    _G.MinimapBackdrop,
    _G.MinimapBackdropTexture,
  }
  for i=1,#ring do
    local f = ring[i]
    if f and f.SetShown then f:SetShown(not square) end
  end

  local moon = _G.GameTimeFrame
  if moon and moon.SetShown then moon:SetShown(false) end

  local clusterTop = (_G.MinimapCluster and _G.MinimapCluster.BorderTop) or _G.MinimapClusterBorderTop
  if clusterTop and clusterTop.SetShown then clusterTop:SetShown(false) end

  local toggleBtn = _G.MiniMapToggleButton
  if toggleBtn and toggleBtn.SetShown then toggleBtn:SetShown(false) end
end

-- ------------------------------------------------------------
-- Mousewheel zoom (remove ZoomIn/ZoomOut buttons)
-- ------------------------------------------------------------
local function HideZoomButtons()
  local zi = _G.MinimapZoomIn
  local zo = _G.MinimapZoomOut
  if zi then zi:Hide() end
  if zo then zo:Hide() end
end

local function EnableMouseWheelZoom()
  if not mm then return end
  if mm._etbcWheelZoom then return end
  mm._etbcWheelZoom = true

  mm:EnableMouseWheel(true)
  mm:SetScript("OnMouseWheel", function(_, delta)
    if delta > 0 then
      if _G.Minimap_ZoomIn then _G.Minimap_ZoomIn() return end
      if _G.MinimapZoomIn and _G.MinimapZoomIn.Click then _G.MinimapZoomIn:Click() return end
    else
      if _G.Minimap_ZoomOut then _G.Minimap_ZoomOut() return end
      if _G.MinimapZoomOut and _G.MinimapZoomOut.Click then _G.MinimapZoomOut:Click() return end
    end
  end)
end

-- ------------------------------------------------------------
-- Zone text
-- ------------------------------------------------------------
local function ApplyZoneText(db)
  local zbtn = _G.MinimapZoneTextButton
  local ztxt = _G.MinimapZoneText
  if not zbtn or not ztxt or not mm then return end

  if db.zoneText and db.zoneText.enabled == false then
    zbtn:Hide()
    return
  end

  zbtn:SetParent(mm)
  zbtn:ClearAllPoints()
  zbtn:SetPoint(db.zoneText.point or "TOP", mm, db.zoneText.point or "TOP", db.zoneText.x or 0, db.zoneText.y or -2)
  zbtn:SetAlpha(clamp(db.zoneText.alpha or 1.0, 0, 1))
  zbtn:SetFrameLevel(mm:GetFrameLevel() + 80)
  zbtn:Show()

  if ztxt.SetFont then
    local font, _, flags = ztxt:GetFont()
    ztxt:SetFont(font, clamp(db.zoneText.fontSize or 12, 8, 20), flags)
  end
end

local function Apply()
  local db = GetDB()
  if not db or not mm then return end

  EnsureFlyout()
  if not fly.frame then return end

  if not (db.enabled and db.flyout and db.flyout.enabled) then
    for src in pairs(fly.hidden) do RestoreBtn(src) end
    for _, proxy in pairs(fly.proxies) do if proxy then proxy:Hide() end end
    wipe(fly.order)
    fly.open = false
    fly.frame:Hide()
    if fly.toggle then fly.toggle:Hide() end
    return
  end

  if fly.toggle then fly.toggle:Show() end
  ApplyFlyoutAnchors(db)
  if fly.drag and fly.drag.EnableMouse then
    fly.drag:EnableMouse(db.flyout.locked == false)
  end

  LayoutFlyout(db)

  if db.flyout.startOpen and not fly.open then
    fly.open = true
  end
  if fly.open then fly.frame:Show() else fly.frame:Hide() end
end

local function ApplyFlyout(db)
  EnsureFlyout()
  if not fly.frame then return end

  if not (db.enabled and db.flyout and db.flyout.enabled) then
    for src in pairs(fly.hidden) do RestoreBtn(src) end
    for _, proxy in pairs(fly.proxies) do if proxy then proxy:Hide() end end
    fly.open = false
    fly.frame:Hide()
    if fly.toggle then fly.toggle:Hide() end
    return
  end

  if db.flyout.startOpen and not fly.open then
    fly.open = true
  end
  mod:RefreshFlyout()
end

-- ------------------------------------------------------------
-- Apply
-- ------------------------------------------------------------
function mod:Apply()
  local db = GetDB()
  if not db or not mm then return end

  KillAllOtherFlyoutFrames()

  if db.enabled == false then
    if orig.stored then
      if orig.w and orig.h then mm:SetSize(orig.w, orig.h) end
      if orig.scale then mm:SetScale(orig.scale) end
    end
    mm:SetMaskTexture(MASK_CIRCLE)
    if deco then deco:Hide() end

    RestoreFrame(FindTracking())
    RestoreFrame(FindMail())
    RestoreFrame(FindLFG())

    for btn in pairs(fly.hidden) do RestoreBtn(btn) end
    if fly.frame then fly.frame:Hide() end
    if fly.toggle then fly.toggle:Hide() end
    fly.open = false
    return
  end

  ApplyShapeAndScale(db)
  ApplyDefaultArt(db)
  ApplyBorder(db)

  HideZoomButtons()
  EnableMouseWheelZoom()

  ApplyZoneText(db)
  ApplyClock(db)

  ApplyBlizzButtons(db)
  ApplyFlyout(db)
end

-- ------------------------------------------------------------
-- Events + ApplyBus
-- ------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("MINIMAP_UPDATE_TRACKING")
ev:SetScript("OnEvent", function(_, event)
  if not ETBC or not ETBC.db then return end

  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    SafeCall(StoreOriginal)
    SafeCall(mod.Apply, mod)
    return
  end

  if event == "MINIMAP_UPDATE_TRACKING" then
    SafeCall(mod.Apply, mod)
    return
  end

  if event == "ADDON_LOADED" then
    C_Timer.After(0.30, function()
      local db = GetDB()
      if db and db.enabled and db.flyout and db.flyout.enabled then
        SafeCall(mod.RefreshFlyout, mod)
      end
    end)
  end
end)

if ETBC.ApplyBus and ETBC.ApplyBus.Register then
  ETBC.ApplyBus:Register("minimap", function() SafeCall(mod.Apply, mod) end)
  ETBC.ApplyBus:Register("general", function() SafeCall(mod.Apply, mod) end)
end

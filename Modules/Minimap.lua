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

-- ------------------------------------------------------------
-- Clock
-- ------------------------------------------------------------
local function ApplyClock(db)
  local btn = _G.TimeManagerClockButton
  local ticker = _G.TimeManagerClockTicker
  if not btn or not mm then return end

  if db.clock and db.clock.enabled == false then
    btn:Hide()
    return
  end

  btn:SetParent(mm)
  btn:ClearAllPoints()
  btn:SetPoint("BOTTOM", mm, "BOTTOM", 0, -2)
  btn:SetAlpha(clamp(db.clock.alpha or 1.0, 0, 1))
  btn:SetFrameLevel(mm:GetFrameLevel() + 90)
  btn:Show()

  if ticker and ticker.SetFont then
    local font, _, flags = ticker:GetFont()
    ticker:SetFont(font, clamp(db.clock.fontSize or 12, 8, 20), flags)
  end
end

-- ------------------------------------------------------------
-- Blizzard buttons rail (NOT scaled with minimap)
-- ------------------------------------------------------------
local rail
local function EnsureRail()
  if rail or not mm then return end
  rail = CreateFrame("Frame", "EnhanceTBC_MinimapRail", UIParent)
  rail:SetSize(1,1)
  rail:SetPoint("CENTER", mm, "CENTER", 0, 0)
  rail:SetFrameStrata("HIGH")
  rail:SetFrameLevel((mm:GetFrameLevel() or 10) + 2000)
  rail:EnableMouse(false)
  if rail.SetIgnoreParentScale then rail:SetIgnoreParentScale(true) end
  rail:SetScale(1)
end

local stored = {}
local function CapturePoints(frame)
  if not frame or not frame.GetNumPoints then return nil end
  local t = {}
  for i=1, frame:GetNumPoints() do
    local p, rel, rp, x, y = frame:GetPoint(i)
    t[i] = { p, rel, rp, x, y }
  end
  return t
end

local function RestorePoints(frame, t)
  if not frame or not t then return end
  frame:ClearAllPoints()
  for i=1, #t do
    local p, rel, rp, x, y = unpack(t[i])
    if p then frame:SetPoint(p, rel, rp, x, y) end
  end
end

local function StoreFrame(f)
  if not f or stored[f] then return end
  local w,h = f:GetSize()
  stored[f] = {
    parent = f:GetParent(),
    points = CapturePoints(f),
    strata = f:GetFrameStrata(),
    level = f:GetFrameLevel(),
    scale = f:GetScale(),
    w=w, h=h,
  }
end

local function RestoreFrame(f)
  local s = f and stored[f]
  if not s or not f then return end
  if s.parent and f:GetParent() ~= s.parent then f:SetParent(s.parent) end
  if f.SetScale and s.scale then f:SetScale(s.scale) end
  if f.SetFrameStrata and s.strata then f:SetFrameStrata(s.strata) end
  if f.SetFrameLevel and s.level then f:SetFrameLevel(s.level) end
  if f.SetSize and s.w and s.h and s.w > 0 and s.h > 0 then f:SetSize(s.w, s.h) end
  RestorePoints(f, s.points)
  stored[f] = nil
end

local function GetPreferredIcon(btn)
  if not btn then return nil end

  local name = btn.GetName and btn:GetName() or nil

  if btn == _G.MiniMapTrackingButton or btn == _G.MinimapTrackingButton or btn == _G.MiniMapTracking then
    return _G.MiniMapTrackingButtonIcon or _G.MiniMapTrackingIcon or _G.MinimapTrackingIcon
  end
  if btn == _G.MiniMapMailFrame or btn == _G.MinimapMailFrame then
    return _G.MiniMapMailIcon or _G.MinimapMailIcon
  end
  if btn == _G.MiniMapLFGFrame or btn == _G.QueueStatusMinimapButton or btn == _G.MiniMapBattlefieldFrame or btn == _G.MiniMapLFG then
    return _G.MiniMapLFGFrameIcon or _G.QueueStatusMinimapButtonIcon
  end

  local icon = btn.icon or btn.Icon
  if not icon and name then
    icon = _G[name .. "Icon"]
  end
  if icon then return icon end

  if btn.GetRegions then
    local regs = { btn:GetRegions() }
    for i=1,#regs do
      local r = regs[i]
      if r and r.GetObjectType and r:GetObjectType() == "Texture" then
        local tex = r.GetTexture and r:GetTexture()
        if tex and type(tex) == "string" and not tex:find("UI%-Minimap") then
          return r
        end
      end
    end
  end

  return nil
end

local function NormalizeButtonHitRect(btn)
  if not btn then return end
  if btn.SetHitRectInsets then
    btn:SetHitRectInsets(0, 0, 0, 0)
  end
  if btn.RegisterForClicks then
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
  end
  if btn.EnableMouse then
    btn:EnableMouse(true)
  end
end

local function FitIconTexture(btn)
  local icon = GetPreferredIcon(btn)
  if not icon or not icon.SetTexCoord then return end

  local parent = icon.GetParent and icon:GetParent() or nil
  if parent == btn then
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 4, -4)
    icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -4, 4)
  end

  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  if icon.SetDrawLayer then
    icon:SetDrawLayer("ARTWORK")
  end
end

local function AnchorBlizz(btn, point, relPoint, x, y, size)
  if not btn or not mm or not rail then return end
  StoreFrame(btn)
  btn:SetParent(rail)
  if btn.SetIgnoreParentScale then btn:SetIgnoreParentScale(true) end
  btn:SetScale(1)
  btn:SetFrameStrata("HIGH")
  btn:SetFrameLevel(rail:GetFrameLevel() + 5)

  btn:ClearAllPoints()
  btn:SetPoint(point, mm, relPoint, x, y)
  btn:SetSize(size, size)
  NormalizeButtonHitRect(btn)
  if btn == FindTracking() then
    local ticon = _G.MiniMapTrackingButtonIcon or _G.MiniMapTrackingIcon or _G.MinimapTrackingIcon
    local tbg = _G.MiniMapTrackingBackground or _G.MinimapTrackingBackground
    local tborder = _G.MiniMapTrackingButtonBorder or _G.MinimapTrackingButtonBorder

    if tbg then
      if tbg.SetParent then tbg:SetParent(btn) end
      if tbg.ClearAllPoints then
        tbg:ClearAllPoints()
        tbg:SetAllPoints(btn)
      end
      if tbg.SetDrawLayer then tbg:SetDrawLayer("BACKGROUND", 0) end
      if tbg.SetAlpha then tbg:SetAlpha(1) end
      if tbg.Show then tbg:Show() end
    end

    if ticon then
      if ticon.SetParent then ticon:SetParent(btn) end
      if ticon.ClearAllPoints then
        ticon:ClearAllPoints()
        ticon:SetPoint("TOPLEFT", btn, "TOPLEFT", 4, -4)
        ticon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -4, 4)
      end
      if GetTrackingTexture and ticon.SetTexture then
        local tex = GetTrackingTexture()
        if tex and tex ~= "" then ticon:SetTexture(tex) end
      end
      if ticon.SetDrawLayer then ticon:SetDrawLayer("ARTWORK", 1) end
      if ticon.SetAlpha then ticon:SetAlpha(1) end
      if ticon.Show then ticon:Show() end
    end

    if tborder then
      if tborder.SetParent then tborder:SetParent(btn) end
      if tborder.ClearAllPoints then
        tborder:ClearAllPoints()
        tborder:SetAllPoints(btn)
      end
      if tborder.SetDrawLayer then tborder:SetDrawLayer("OVERLAY", 2) end
      if tborder.SetAlpha then tborder:SetAlpha(1) end
      if tborder.Show then tborder:Show() end
    end
  end
  if btn.Show then btn:Show() end

  FitIconTexture(btn)
end

local function FindTracking()
  return _G.MiniMapTrackingButton or _G.MinimapTrackingButton or _G.MiniMapTracking
end

local function FindMail()
  return _G.MiniMapMailFrame or _G.MinimapMailFrame
end

local function FindLFG()
  return _G.MiniMapLFGFrame or _G.QueueStatusMinimapButton or _G.MiniMapBattlefieldFrame or _G.MiniMapLFG
end

local function ApplyBlizzButtons(db)
  EnsureRail()
  if not rail then return end

  local enabled = db.blizzButtons and db.blizzButtons.enabled
  local size = clamp((db.blizzButtons and db.blizzButtons.size) or 32, 20, 42)

  local tracking = FindTracking()
  local mail = FindMail()
  local lfg = FindLFG()

  if not enabled then
    RestoreFrame(tracking)
    RestoreFrame(mail)
    RestoreFrame(lfg)
    return
  end

  if tracking then
    AnchorBlizz(tracking,
      db.blizzButtons.tracking.point or "TOPRIGHT",
      db.blizzButtons.tracking.relPoint or "TOPRIGHT",
      db.blizzButtons.tracking.x or 6,
      db.blizzButtons.tracking.y or -2,
      size
    )
  end

  if mail then
    AnchorBlizz(mail,
      db.blizzButtons.mail.point or "TOP",
      db.blizzButtons.mail.relPoint or "TOP",
      db.blizzButtons.mail.x or 0,
      db.blizzButtons.mail.y or 6,
      size
    )
  end

  if lfg then
    AnchorBlizz(lfg,
      db.blizzButtons.lfg.point or "BOTTOMLEFT",
      db.blizzButtons.lfg.relPoint or "BOTTOMLEFT",
      db.blizzButtons.lfg.x or -2,
      db.blizzButtons.lfg.y or -2,
      size
    )
  end
end

-- ------------------------------------------------------------
-- Flyout (LibDBIcon authoritative)
-- ------------------------------------------------------------
local fly = {
  frame=nil, content=nil, drag=nil, toggle=nil,
  open=false,
  hiddenRoot=nil,
  hidden={},      -- source btn -> original placement/state
  proxies={},     -- source btn -> proxy btn in flyout
  visuals={},     -- source btn -> cached icon visual
  order={},
}

local function ParseCSVSet(s)
  local out = {}
  s = tostring(s or "")
  for token in s:gmatch("[^,%s]+") do out[token] = true end
  return out
end

local function RestoreBtn(btn)
  local st = btn and fly.hidden[btn]
  if not st or not btn then return end

  if st.parent and btn:GetParent() ~= st.parent then
    btn:SetParent(st.parent)
  end
  if btn.SetScale and st.scale then btn:SetScale(st.scale) end
  if btn.SetFrameStrata and st.strata then btn:SetFrameStrata(st.strata) end
  if btn.SetFrameLevel and st.level then btn:SetFrameLevel(st.level) end
  if btn.SetSize and st.w and st.h and st.w > 0 and st.h > 0 then btn:SetSize(st.w, st.h) end
  RestorePoints(btn, st.points)

  if btn.EnableMouse then btn:EnableMouse(st.mouse and true or false) end
  if st.shown and btn.Show then
    btn:Show()
  elseif btn.Hide then
    btn:Hide()
  end

  fly.hidden[btn] = nil
  fly.visuals[btn] = nil
end

local function IsForbiddenCapture(name)
  if not name or name == "" then return true end
  if name == "GameTimeFrame" then return true end
  if name == "TimeManagerClockButton" then return true end
  if name == "MinimapZoomIn" or name == "MinimapZoomOut" then return true end
  if name:find("MinimapZoneText", 1, true) then return true end
  if name:find("MiniMapTracking", 1, true) then return true end
  if name:find("MiniMapMail", 1, true) then return true end
  if name:find("MiniMapLFG", 1, true) then return true end
  if name:find("QueueStatus", 1, true) then return true end
  if name:find("EnhanceTBC_MinimapFlyout", 1, true) then return true end
  return false
end

local function GetLDBButtons(db)
  local exclude = ParseCSVSet(db.flyout and db.flyout.exclude)
  local includeExtra = ParseCSVSet(db.flyout and db.flyout.includeExtra)

  local list, seen = {}, {}
  local LDBI = LibStub and LibStub("LibDBIcon-1.0", true)

  if LDBI and type(LDBI.objects) == "table" then
    for key, obj in pairs(LDBI.objects) do
      local btn

      if type(obj) == "table" then
        if obj.IsObjectType and obj:IsObjectType("Button") then
          btn = obj
        else
          btn = obj.button
        end
      end

      if not btn and LDBI.GetMinimapButton and type(key) == "string" then
        btn = LDBI:GetMinimapButton(key)
      end

      if btn and btn.IsObjectType and btn:IsObjectType("Button") then
        local n = btn:GetName() or ""
        if not seen[btn] and not exclude[n] and not IsForbiddenCapture(n) then
          table.insert(list, btn)
          seen[btn] = true
        end
      end
    end
  end

  for gname, gobj in pairs(_G) do
    if type(gname) == "string" and gname:find("^LibDBIcon10_") and type(gobj) == "table" and gobj.IsObjectType and gobj:IsObjectType("Button") then
      local btn = gobj
      local n = btn:GetName() or ""
      if not seen[btn] and not exclude[n] and not IsForbiddenCapture(n) then
        table.insert(list, btn)
        seen[btn] = true
      end
    end
  end

  for name in pairs(includeExtra) do
    local btn = _G[name]
    if btn and btn.IsObjectType and btn:IsObjectType("Button") then
      local n = btn:GetName() or name
      if not seen[btn] and not exclude[n] and not IsForbiddenCapture(n) then
        table.insert(list, btn)
        seen[btn] = true
      end
    end
  end

  table.sort(list, function(a,b)
    local an = a:GetName() or ""
    local bn = b:GetName() or ""
    return an < bn
  end)

  return list
end

local function GetLDBIconDataForButton(btn)
  if not btn then return nil, nil end
  local LDBI = LibStub and LibStub("LibDBIcon-1.0", true)
  if not LDBI or type(LDBI.objects) ~= "table" then return nil, nil end

  local obj = nil
  local name = btn.GetName and btn:GetName() or ""
  local key = name:match("^LibDBIcon10_(.+)$")
  if key and type(LDBI.objects[key]) == "table" then
    obj = LDBI.objects[key]
  end

  if not obj then
    for _, v in pairs(LDBI.objects) do
      if type(v) == "table" then
        if v == btn or v.button == btn then
          obj = v
          break
        end
      end
    end
  end

  if not obj then return nil, nil end

  local tex = obj.icon or (obj.dataObject and obj.dataObject.icon)
  local coords = obj.iconCoords or (obj.dataObject and obj.dataObject.iconCoords)
  return tex, coords
end

local function EnsureFlyout()
  if fly.frame then return end
  if not mm then return end

  KillAllOtherFlyoutFrames()

  fly.hiddenRoot = _G.EnhanceTBC_MinimapFlyoutHidden or CreateFrame("Frame", "EnhanceTBC_MinimapFlyoutHidden", UIParent)
  fly.hiddenRoot:Hide()

  fly.toggle = _G.EnhanceTBC_MinimapFlyoutToggle or CreateFrame("Button", "EnhanceTBC_MinimapFlyoutToggle", UIParent, "BackdropTemplate")
  fly.toggle:SetSize(16, 16)
  fly.toggle:SetFrameStrata("HIGH")
  fly.toggle:SetFrameLevel((mm:GetFrameLevel() or 10) + 2500)
  if fly.toggle.SetIgnoreParentScale then fly.toggle:SetIgnoreParentScale(true) end
  fly.toggle:SetScale(1)
  fly.toggle:SetBackdrop(nil)
  fly.toggle:SetAlpha(0)
  if fly.toggle.EnableMouse then fly.toggle:EnableMouse(true) end
  if fly.toggle._label and fly.toggle._label.Hide then fly.toggle._label:Hide() end

  fly.frame = _G.EnhanceTBC_MinimapFlyout or CreateFrame("Frame", "EnhanceTBC_MinimapFlyout", UIParent, "BackdropTemplate")
  fly.frame:SetFrameStrata("DIALOG")
  fly.frame:SetFrameLevel((mm:GetFrameLevel() or 10) + 2600)
  fly.frame:SetClampedToScreen(true)
  fly.frame:SetBackdrop({ bgFile=WHITE, edgeFile=WHITE, edgeSize=2, insets={ left=1, right=1, top=1, bottom=1 } })

  fly.content = _G.EnhanceTBC_MinimapFlyoutContent or CreateFrame("Frame", "EnhanceTBC_MinimapFlyoutContent", fly.frame)
  fly.content:SetPoint("TOPLEFT", fly.frame, "TOPLEFT", 0, 0)
  fly.content:SetPoint("BOTTOMRIGHT", fly.frame, "BOTTOMRIGHT", 0, 0)
  fly.content:SetFrameLevel(fly.frame:GetFrameLevel() + 5)
  fly.content:EnableMouse(false)

  fly.drag = _G.EnhanceTBC_MinimapFlyoutDrag or CreateFrame("Frame", "EnhanceTBC_MinimapFlyoutDrag", fly.frame)
  fly.drag:SetPoint("TOPLEFT", fly.frame, "TOPLEFT", 0, 0)
  fly.drag:SetPoint("TOPRIGHT", fly.frame, "TOPRIGHT", 0, 0)
  fly.drag:SetHeight(14)
  fly.drag:SetFrameLevel(fly.frame:GetFrameLevel() + 20)

  fly.frame:SetMovable(true)
  fly.drag:RegisterForDrag("LeftButton")
  fly.drag:SetScript("OnDragStart", function()
    local db = GetDB()
    if db and db.flyout and db.flyout.locked == false then
      fly.frame:StartMoving()
    end
  end)
  fly.drag:SetScript("OnDragStop", function()
    fly.frame:StopMovingOrSizing()
    local db = GetDB()
    if not db or not db.flyout or not db.flyout.pos or not mm then return end

    local fx, fy = fly.frame:GetCenter()
    local mx, my = mm:GetCenter()
    if fx and fy and mx and my then
      db.flyout.pos.point = "CENTER"
      db.flyout.pos.relPoint = "CENTER"
      db.flyout.pos.x = math.floor((fx - mx) + 0.5)
      db.flyout.pos.y = math.floor((fy - my) + 0.5)
    else
      local p, _, rp, x, y = fly.frame:GetPoint(1)
      if p then
        db.flyout.pos.point = p
        db.flyout.pos.relPoint = rp
        db.flyout.pos.x = x
        db.flyout.pos.y = y
      end
    end
  end)

  fly.toggle:SetScript("OnClick", function()
    fly.open = not fly.open
    if fly.open then
      fly.frame:Show()
      mod:RefreshFlyout()
    else
      fly.frame:Hide()
    end
  end)

  fly.frame:Hide()
end

local function ApplyFlyoutAnchors(db)
  if not fly.frame then return end

  if fly.toggle then
    local t = db.flyout.toggle or {}
    fly.toggle:ClearAllPoints()
    fly.toggle:SetPoint(t.point or "RIGHT", mm, t.relPoint or "RIGHT", t.x or 10, t.y or 0)
  end

  local p = db.flyout.pos or {}
  fly.frame:ClearAllPoints()
  fly.frame:SetPoint(p.point or "TOPRIGHT", mm, p.relPoint or "BOTTOMRIGHT", p.x or 0, p.y or -8)
end

local function HideSourceButton(btn)
  if not btn or fly.hidden[btn] then return end

  local w,h = btn:GetSize()
  fly.hidden[btn] = {
    parent = btn:GetParent(),
    points = CapturePoints(btn),
    strata = btn:GetFrameStrata(),
    level = btn:GetFrameLevel(),
    scale = btn:GetScale(),
    w=w, h=h,
    shown = btn:IsShown(),
    mouse = btn:IsMouseEnabled() and true or false,
  }

  if btn.SetParent and fly.hiddenRoot then btn:SetParent(fly.hiddenRoot) end
  if btn.ClearAllPoints then btn:ClearAllPoints() end
  if btn.EnableMouse then btn:EnableMouse(false) end
  if btn.Hide then btn:Hide() end

  if not btn._etbcFlyoutOnShowHook and btn.HookScript then
    btn._etbcFlyoutOnShowHook = true
    btn:HookScript("OnShow", function(self)
      local db = GetDB()
      if db and db.enabled and db.flyout and db.flyout.enabled and fly.hidden[self] then
        self:Hide()
      end
    end)
  end
end

local function EnsureProxy(source)
  local proxy = fly.proxies[source]
  if proxy then return proxy end

  proxy = CreateFrame("Button", nil, fly.content, "BackdropTemplate")
  proxy:SetBackdrop({ bgFile=WHITE, edgeFile=WHITE, edgeSize=1 })
  proxy:SetBackdropColor(0, 0, 0, 0.15)
  proxy:SetBackdropBorderColor(0, 0, 0, 0.35)
  proxy:SetFrameStrata("DIALOG")
  proxy:SetFrameLevel(fly.content:GetFrameLevel() + 6)
  proxy:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")

  proxy.icon = proxy:CreateTexture(nil, "ARTWORK")
  proxy.icon:SetPoint("TOPLEFT", proxy, "TOPLEFT", 3, -3)
  proxy.icon:SetPoint("BOTTOMRIGHT", proxy, "BOTTOMRIGHT", -3, 3)

  proxy.source = source
  proxy:SetScript("OnClick", function(self, button)
    local src = self.source
    if not src then return end

    if src.Click then
      src:Click(button)
    else
      local fn = src.GetScript and src:GetScript("OnClick")
      if fn then fn(src, button) end
    end
  end)

  proxy:SetScript("OnEnter", function(self)
    local src = self.source
    if not src then return end
    local fn = src.GetScript and src:GetScript("OnEnter")
    if fn then fn(src) end
  end)
  proxy:SetScript("OnLeave", function(self)
    local src = self.source
    if not src then return end
    local fn = src.GetScript and src:GetScript("OnLeave")
    if fn then fn(src) end
  end)

  fly.proxies[source] = proxy
  return proxy
end

local function ExtractVisualData(src)
  if not src then return nil, nil, nil, nil, nil end

  local tex, coords = GetLDBIconDataForButton(src)
  local l, r, t, b
  if type(coords) == "table" and #coords >= 4 then
    l, r, t, b = coords[1], coords[2], coords[3], coords[4]
  end

  if not tex or tex == "" then
    local icon = GetPreferredIcon(src)
    if icon and icon.GetTexture then tex = icon:GetTexture() end
    if (not l or not r or not t or not b) and icon and icon.GetTexCoord then
      l, r, t, b = icon:GetTexCoord()
    end
  end

  return tex, l, r, t, b
end

local function UpdateProxyVisual(proxy)
  if not proxy or not proxy.source or not proxy.icon then return end
  local src = proxy.source

  local cache = fly.visuals[src]
  local tex, l, r, t, b
  if cache then
    tex, l, r, t, b = cache.tex, cache.l, cache.r, cache.t, cache.b
  else
    tex, l, r, t, b = ExtractVisualData(src)
  end

  proxy.icon:SetTexture(tex)
  if l and r and t and b then
    proxy.icon:SetTexCoord(l, r, t, b)
  else
    proxy.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
end

local function LayoutFlyout(db)
  wipe(fly.order)

  local buttons = GetLDBButtons(db)
  local active = {}

  for i=1,#buttons do
    local src = buttons[i]
    if src then
      active[src] = true
      table.insert(fly.order, src)
      local tex, l, r, t, b = ExtractVisualData(src)
      fly.visuals[src] = { tex=tex, l=l, r=r, t=t, b=b }
      HideSourceButton(src)
      local proxy = EnsureProxy(src)
      if proxy then
        proxy.source = src
        proxy:Show()
        UpdateProxyVisual(proxy)
      end
    end
  end

  for src, proxy in pairs(fly.proxies) do
    if not active[src] then
      if proxy then proxy:Hide() end
      RestoreBtn(src)
      fly.proxies[src] = nil
      fly.visuals[src] = nil
    end
  end

  local iconSize = clamp(db.flyout.iconSize or 28, 16, 44)
  local colsMax  = clamp(db.flyout.columns or 6, 1, 12)
  local spacing  = clamp(db.flyout.spacing or 4, 0, 14)
  local padding  = clamp(db.flyout.padding or 6, 0, 20)
  local scale    = clamp(db.flyout.scale or 1.0, 0.7, 1.5)

  fly.frame:SetScale(scale)
  fly.frame:SetBackdropColor(0.02, 0.03, 0.02, clamp(db.flyout.bgAlpha or 0.70, 0, 1))
  fly.frame:SetBackdropBorderColor(0.18, 0.20, 0.18, clamp(db.flyout.borderAlpha or 0.90, 0, 1))

  local total = #fly.order
  if total == 0 then
    fly.frame:SetSize(padding*2 + iconSize, padding*2 + iconSize)
    return
  end

  local cols = math.min(colsMax, total)
  local rows = math.ceil(total / cols)
  local w = padding*2 + cols*iconSize + (cols-1)*spacing
  local h = padding*2 + rows*iconSize + (rows-1)*spacing
  fly.frame:SetSize(w, h)

  for i=1,total do
    local src = fly.order[i]
    local proxy = fly.proxies[src]
    if proxy then
      local r = math.floor((i-1)/cols)
      local c = (i-1)%cols
      proxy:ClearAllPoints()
      proxy:SetPoint("TOPLEFT", fly.content, "TOPLEFT", padding + c*(iconSize+spacing), -(padding + r*(iconSize+spacing)))
      proxy:SetSize(iconSize, iconSize)
      proxy:SetFrameLevel(fly.content:GetFrameLevel() + 6)
    end
  end
end

function mod:RefreshFlyout()
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

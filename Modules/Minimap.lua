-- Modules/Minimap.lua (CLEAN SLATE v2 - proxy flyout, stable)
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

local function ParseCSVSet(s)
  local out = {}
  s = tostring(s or "")
  for token in s:gmatch("[^,%s]+") do
    out[token] = true
  end
  return out
end

-- ------------------------------------------------------------
-- DB
-- ------------------------------------------------------------
local function GetDB()
  if not ETBC or not ETBC.db or not ETBC.db.profile then return nil end
  ETBC.db.profile.minimap = ETBC.db.profile.minimap or {}
  local db = ETBC.db.profile.minimap

  if db.enabled == nil then db.enabled = true end
  if db.shape == nil then db.shape = "CIRCLE" end
  if db.squareSize == nil then db.squareSize = 140 end
  if db.mapScale == nil then db.mapScale = 1.0 end

  db.border = db.border or {}
  if db.border.enabled == nil then db.border.enabled = true end
  if db.border.size == nil then db.border.size = 2 end
  if db.border.alpha == nil then db.border.alpha = 0.90 end
  if db.border.r == nil then db.border.r = 0.18 end
  if db.border.g == nil then db.border.g = 0.20 end
  if db.border.b == nil then db.border.b = 0.18 end

  db.zoneText = db.zoneText or {}
  if db.zoneText.enabled == nil then db.zoneText.enabled = true end
  if db.zoneText.fontSize == nil then db.zoneText.fontSize = 12 end

  db.clock = db.clock or {}
  if db.clock.enabled == nil then db.clock.enabled = true end
  if db.clock.fontSize == nil then db.clock.fontSize = 12 end

  db.blizzButtons = db.blizzButtons or {}
  if db.blizzButtons.enabled == nil then db.blizzButtons.enabled = true end
  if db.blizzButtons.size == nil then db.blizzButtons.size = 32 end

  db.flyout = db.flyout or {}
  local f = db.flyout
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
  if f.exclude == nil then f.exclude = "" end -- comma-separated LibDBIcon object keys (preferred)

  f.pos = f.pos or {}
  if f.pos.point == nil then f.pos.point = "TOPRIGHT" end
  if f.pos.relPoint == nil then f.pos.relPoint = "BOTTOMRIGHT" end
  if f.pos.x == nil then f.pos.x = 0 end
  if f.pos.y == nil then f.pos.y = -8 end

  f.toggle = f.toggle or {}
  if f.toggle.point == nil then f.toggle.point = "RIGHT" end
  if f.toggle.relPoint == nil then f.toggle.relPoint = "RIGHT" end
  if f.toggle.x == nil then f.toggle.x = 10 end
  if f.toggle.y == nil then f.toggle.y = 0 end

  return db
end

-- ------------------------------------------------------------
-- Kill old flyout frames from previous iterations (so no “2 toggles”)
-- ------------------------------------------------------------
local function KillOld()
  if not EnumerateFrames then return end
  local keep = {
    ["EnhanceTBC_MM2_Fly_Toggle"] = true,
    ["EnhanceTBC_MM2_Fly_Frame"] = true,
    ["EnhanceTBC_MM2_Fly_Content"] = true,
    ["EnhanceTBC_MM2_Fly_Drag"] = true,
  }

  local f = EnumerateFrames()
  while f do
    local n = f.GetName and f:GetName()
    if n and n:find("EnhanceTBC") and (n:find("Flyout") or n:find("MM_Fly") or n:find("MM2_Fly")) then
      if not keep[n] then
        if f.Hide then f:Hide() end
        if f.EnableMouse then f:EnableMouse(false) end
        if f.SetScript then
          f:SetScript("OnClick", nil)
          f:SetScript("OnShow", nil)
          f:SetScript("OnEnter", nil)
          f:SetScript("OnLeave", nil)
          f:SetScript("OnMouseDown", nil)
          f:SetScript("OnMouseUp", nil)
          f:SetScript("OnDragStart", nil)
          f:SetScript("OnDragStop", nil)
        end
      end
    end
    f = EnumerateFrames(f)
  end
end

-- ------------------------------------------------------------
-- Store original minimap size
-- ------------------------------------------------------------
local orig = { stored=false, w=nil, h=nil, scale=nil }
local function StoreOriginal()
  if orig.stored or not mm then return end
  orig.w, orig.h = mm:GetSize()
  orig.scale = mm:GetScale()
  orig.stored = true
end

-- ------------------------------------------------------------
-- Border (border only, no dark fill)
-- ------------------------------------------------------------
local border
local function EnsureBorder()
  if border or not mm then return end
  border = CreateFrame("Frame", "EnhanceTBC_MM2_Border", mm, "BackdropTemplate")
  border:SetAllPoints(mm)
  border:SetFrameStrata(mm:GetFrameStrata())
  border:SetFrameLevel(mm:GetFrameLevel() + 50)
  border:EnableMouse(false)
end

local function ApplyBorder(db)
  EnsureBorder()
  if not border then return end

  if not db.border or db.border.enabled == false then
    border:Hide()
    return
  end

  local edge = clamp(db.border.size or 2, 1, 8)
  border:SetBackdrop({
    bgFile = nil,
    edgeFile = WHITE,
    tile = false,
    edgeSize = edge,
    insets = { left=0, right=0, top=0, bottom=0 },
  })
  border:SetBackdropBorderColor(
    db.border.r or 0.18,
    db.border.g or 0.20,
    db.border.b or 0.18,
    clamp(db.border.alpha or 0.90, 0, 1)
  )
  border:Show()
end

-- ------------------------------------------------------------
-- Shape + scale
-- ------------------------------------------------------------
local function ApplyShapeScale(db)
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

  -- Hide default ring art in square mode
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

  -- Always hide day/night icon
  local moon = _G.GameTimeFrame
  if moon and moon.SetShown then moon:SetShown(false) end
end

-- ------------------------------------------------------------
-- Zoom: hide buttons, mousewheel zoom, and keep them hidden
-- ------------------------------------------------------------
local function ForceHideZoom(btn)
  if not btn then return end
  btn:Hide()
  if btn.SetAlpha then btn:SetAlpha(0) end
  if btn.EnableMouse then btn:EnableMouse(false) end
  if not btn._etbcHideHooked and btn.HookScript then
    btn._etbcHideHooked = true
    btn:HookScript("OnShow", function(self) self:Hide() end)
  end
end

local function ApplyZoomBehavior()
  local zi = _G.MinimapZoomIn
  local zo = _G.MinimapZoomOut
  ForceHideZoom(zi)
  ForceHideZoom(zo)

  if not mm or mm._etbcWheelZoom then return end
  mm._etbcWheelZoom = true

  mm:EnableMouseWheel(true)
  mm:SetScript("OnMouseWheel", function(_, delta)
    if delta > 0 then
      if _G.Minimap_ZoomIn then _G.Minimap_ZoomIn() return end
      if zi and zi.Click then zi:Click() return end
    else
      if _G.Minimap_ZoomOut then _G.Minimap_ZoomOut() return end
      if zo and zo.Click then zo:Click() return end
    end
  end)
end

-- ------------------------------------------------------------
-- Zone + Clock
-- ------------------------------------------------------------
local function ApplyZone(db)
  local zbtn = _G.MinimapZoneTextButton
  local ztxt = _G.MinimapZoneText
  if not zbtn or not ztxt or not mm then return end

  if db.zoneText and db.zoneText.enabled == false then
    zbtn:Hide()
    return
  end

  zbtn:SetParent(mm)
  zbtn:ClearAllPoints()
  zbtn:SetPoint("TOP", mm, "TOP", 0, -2)
  zbtn:SetFrameLevel(mm:GetFrameLevel() + 80)
  zbtn:Show()

  if ztxt.SetFont then
    local font, _, flags = ztxt:GetFont()
    ztxt:SetFont(font, clamp(db.zoneText.fontSize or 12, 8, 20), flags)
  end
end

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
  btn:SetPoint("BOTTOM", mm, "BOTTOM", 0, -2) -- on border edge
  btn:SetFrameLevel(mm:GetFrameLevel() + 95)
  btn:Show()

  if ticker and ticker.SetFont then
    local font, _, flags = ticker:GetFont()
    ticker:SetFont(font, clamp(db.clock.fontSize or 12, 8, 20), flags)
  end
end

-- ------------------------------------------------------------
-- Blizzard buttons rail (never scaled with minimap)
-- ------------------------------------------------------------
local rail
local stored = {}

local function EnsureRail()
  if rail or not mm then return end
  rail = CreateFrame("Frame", "EnhanceTBC_MM2_Rail", UIParent)
  rail:SetSize(1,1)
  rail:SetPoint("CENTER", mm, "CENTER", 0, 0)
  rail:SetFrameStrata("HIGH")
  rail:SetFrameLevel((mm:GetFrameLevel() or 10) + 2000)
  rail:EnableMouse(false)
  if rail.SetIgnoreParentScale then rail:SetIgnoreParentScale(true) end
  rail:SetScale(1)
end

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
    parent=f:GetParent(),
    points=CapturePoints(f),
    strata=f:GetFrameStrata(),
    level=f:GetFrameLevel(),
    scale=f:GetScale(),
    w=w, h=h,
  }
end

local function RestoreFrame(f)
  local s = f and stored[f]
  if not f or not s then return end
  if s.parent and f:GetParent() ~= s.parent then f:SetParent(s.parent) end
  if f.SetScale and s.scale then f:SetScale(s.scale) end
  if f.SetFrameStrata and s.strata then f:SetFrameStrata(s.strata) end
  if f.SetFrameLevel and s.level then f:SetFrameLevel(s.level) end
  if f.SetSize and s.w and s.h and s.w>0 and s.h>0 then f:SetSize(s.w, s.h) end
  RestorePoints(f, s.points)
  stored[f]=nil
end

-- Tracking differs across builds: prefer actual button if it exists.
local function FindTracking()
  if _G.MiniMapTrackingButton then return _G.MiniMapTrackingButton end
  if _G.MinimapTrackingButton then return _G.MinimapTrackingButton end
  if _G.MiniMapTracking and _G.MiniMapTracking.Button then return _G.MiniMapTracking.Button end

  local holder = _G.MiniMapTracking or _G.MinimapTrackingFrame or _G.MinimapTracking
  if holder and holder.GetChildren then
    local kids = { holder:GetChildren() }
    for i=1,#kids do
      local c = kids[i]
      if c and c.IsObjectType and c:IsObjectType("Button") then
        return c
      end
    end
  end

  return _G.MiniMapTracking or _G.MinimapTrackingButton or _G.MinimapTracking
end

local function FindMail()
  return _G.MiniMapMailFrame or _G.MinimapMailFrame
end

local function FindLFG()
  return _G.MiniMapLFGFrame or _G.QueueStatusMinimapButton or _G.MiniMapBattlefieldFrame or _G.MiniMapLFG
end

local function FitIconTexture(btn)
  if not btn then return end

  -- Common names
  local icon =
    _G.MiniMapTrackingIcon
    or (btn.icon)
    or (btn.Icon)
    or (btn.GetName and _G[(btn:GetName() or "") .. "Icon"])
    or (btn.GetName and _G[(btn:GetName() or "") .. "Texture"])

  -- Last resort: first texture region
  if not icon and btn.GetRegions then
    local regs = { btn:GetRegions() }
    for i=1,#regs do
      local r = regs[i]
      if r and r.GetObjectType and r:GetObjectType() == "Texture" then
        icon = r
        break
      end
    end
  end

  if not icon or not icon.SetTexCoord then return end
  icon:ClearAllPoints()
  icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 4, -4)
  icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -4, 4)
  icon:SetTexCoord(0.08,0.92,0.08,0.92)
end

local function AnchorBlizz(btn, point, relPoint, x, y, size)
  if not btn or not mm or not rail then return end
  StoreFrame(btn)

  btn:SetParent(rail)
  if btn.SetIgnoreParentScale then btn:SetIgnoreParentScale(true) end
  btn:SetScale(1)
  btn:SetFrameStrata("HIGH")
  btn:SetFrameLevel(rail:GetFrameLevel()+5)
  btn:ClearAllPoints()
  btn:SetPoint(point, mm, relPoint, x, y)
  btn:SetSize(size, size)
  if btn.EnableMouse then btn:EnableMouse(true) end
  if btn.Show then btn:Show() end

  FitIconTexture(btn)
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

  -- Tracking: top right edge
  AnchorBlizz(tracking, "TOPRIGHT", "TOPRIGHT", 6, -2, size)
  -- Mail: top center edge
  AnchorBlizz(mail, "TOP", "TOP", 0, 6, size)
  -- LFG: bottom left edge
  AnchorBlizz(lfg, "BOTTOMLEFT", "BOTTOMLEFT", -2, -2, size)
end

-- ------------------------------------------------------------
-- Flyout (PROXY buttons; do NOT move LibDBIcon buttons)
-- ------------------------------------------------------------
local fly = {
  toggle=nil, frame=nil, content=nil, drag=nil,
  open=false,
  proxies={},     -- key -> proxyButton
  orderKeys={},   -- stable order
}

local function EnsureFlyoutFrames()
  if fly.frame then return end
  KillOld()

  fly.toggle = CreateFrame("Button", "EnhanceTBC_MM2_Fly_Toggle", UIParent, "BackdropTemplate")
  fly.toggle:SetSize(18,18)
  fly.toggle:SetFrameStrata("HIGH")
  fly.toggle:SetFrameLevel((mm:GetFrameLevel() or 10) + 2500)
  if fly.toggle.SetIgnoreParentScale then fly.toggle:SetIgnoreParentScale(true) end
  fly.toggle:SetScale(1)
  fly.toggle:SetBackdrop({ bgFile=WHITE, edgeFile=WHITE, edgeSize=1 })
  fly.toggle:SetBackdropColor(0,0,0,0.35)
  fly.toggle:SetBackdropBorderColor(0.18,0.20,0.18,0.70)

  local fs = fly.toggle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs:SetPoint("CENTER")
  fs:SetText("≡")
  fs:SetTextColor(0.85,0.90,0.85,1)

  fly.frame = CreateFrame("Frame", "EnhanceTBC_MM2_Fly_Frame", UIParent, "BackdropTemplate")
  fly.frame:SetFrameStrata("DIALOG")
  fly.frame:SetFrameLevel((mm:GetFrameLevel() or 10) + 2600)
  fly.frame:SetClampedToScreen(true)
  fly.frame:EnableMouse(true)
  fly.frame:SetMovable(true)

  fly.frame:SetBackdrop({
    bgFile=WHITE,
    edgeFile=WHITE,
    edgeSize=2,
    insets={ left=1, right=1, top=1, bottom=1 },
  })

  fly.content = CreateFrame("Frame", "EnhanceTBC_MM2_Fly_Content", fly.frame)
  fly.content:SetAllPoints(fly.frame)
  fly.content:EnableMouse(false)
  fly.content:SetFrameLevel(fly.frame:GetFrameLevel() + 5)

  fly.drag = CreateFrame("Frame", "EnhanceTBC_MM2_Fly_Drag", fly.frame)
  fly.drag:SetPoint("TOPLEFT", fly.frame, "TOPLEFT", 0, 0)
  fly.drag:SetPoint("TOPRIGHT", fly.frame, "TOPRIGHT", 0, 0)
  fly.drag:SetHeight(14)
  fly.drag:SetFrameLevel(fly.frame:GetFrameLevel() + 20)
  fly.drag:EnableMouse(true)
  fly.drag:RegisterForDrag("LeftButton")

  fly.frame:Hide()

  fly.toggle:SetScript("OnClick", function()
    if fly.frame:IsShown() then
      fly.frame:Hide()
      fly.open = false
    else
      fly.frame:Show()
      fly.open = true
      mod:RefreshFlyout()
    end
  end)

  fly.drag:SetScript("OnDragStart", function()
    local db = GetDB()
    if db and db.flyout and db.flyout.locked == false then
      fly.frame:StartMoving()
    end
  end)
  fly.drag:SetScript("OnDragStop", function()
    fly.frame:StopMovingOrSizing()
    local db = GetDB()
    if not db or not db.flyout or not db.flyout.pos then return end
    local p, _, rp, x, y = fly.frame:GetPoint(1)
    if p then
      db.flyout.pos.point = p
      db.flyout.pos.relPoint = rp
      db.flyout.pos.x = x
      db.flyout.pos.y = y
    end
  end)
end

local function ApplyFlyoutAnchors(db)
  if not fly.toggle or not fly.frame then return end
  local t = db.flyout.toggle or {}
  fly.toggle:ClearAllPoints()
  fly.toggle:SetPoint(t.point or "RIGHT", mm, t.relPoint or "RIGHT", t.x or 10, t.y or 0)

  local p = db.flyout.pos or {}
  fly.frame:ClearAllPoints()
  fly.frame:SetPoint(p.point or "TOPRIGHT", mm, p.relPoint or "BOTTOMRIGHT", p.x or 0, p.y or -8)
end

local function GetLDBObjects(db)
  local exclude = ParseCSVSet(db.flyout and db.flyout.exclude)
  local out = {}

  local LDBI = LibStub and LibStub("LibDBIcon-1.0", true)
  if not (LDBI and type(LDBI.objects) == "table") then
    return out
  end

  for key, obj in pairs(LDBI.objects) do
    if not exclude[key] then
      local btn = obj and obj.button
      -- some buttons are anonymous (name=nil) and that’s OK
      if btn and btn.IsObjectType and btn:IsObjectType("Button") then
        table.insert(out, { key=key, obj=obj, btn=btn })
      end
    end
  end

  table.sort(out, function(a,b) return tostring(a.key) < tostring(b.key) end)
  return out
end

local function PullIconTextureFrom(btn)
  if not btn then return nil, nil end

  -- Try common icon fields / regions
  local icon = btn.icon or btn.Icon

  if not icon and btn.GetRegions then
    local regs = { btn:GetRegions() }
    for i=1,#regs do
      local r = regs[i]
      if r and r.GetObjectType and r:GetObjectType() == "Texture" then
        icon = r
        break
      end
    end
  end

  if not icon or not icon.GetTexture then return nil, nil end
  local tex = icon:GetTexture()
  local a,b,c,d = icon:GetTexCoord()
  return tex, { a,b,c,d }
end

local function EnsureProxy(key)
  if fly.proxies[key] then return fly.proxies[key] end
  local b = CreateFrame("Button", nil, fly.content, "BackdropTemplate")
  b:SetBackdrop({ bgFile=WHITE, edgeFile=WHITE, edgeSize=1 })
  b:SetBackdropColor(0,0,0,0)
  b:SetBackdropBorderColor(0,0,0,0)

  local tex = b:CreateTexture(nil, "ARTWORK")
  tex:SetPoint("TOPLEFT", b, "TOPLEFT", 4, -4)
  tex:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -4, 4)
  tex:SetTexCoord(0.08,0.92,0.08,0.92)
  b._icon = tex

  b:EnableMouse(true)
  b:RegisterForClicks("AnyUp")

  fly.proxies[key] = b
  return b
end

local function LayoutFlyout(db, keys)
  local fdb = db.flyout
  local iconSize = clamp(fdb.iconSize or 28, 16, 44)
  local colsMax  = clamp(fdb.columns or 6, 1, 12)
  local spacing  = clamp(fdb.spacing or 4, 0, 14)
  local padding  = clamp(fdb.padding or 6, 0, 20)
  local scale    = clamp(fdb.scale or 1.0, 0.7, 1.5)

  fly.frame:SetScale(scale)
  fly.frame:SetBackdropColor(0.02,0.03,0.02, clamp(fdb.bgAlpha or 0.70, 0, 1))
  fly.frame:SetBackdropBorderColor(0.18,0.20,0.18, clamp(fdb.borderAlpha or 0.90, 0, 1))

  local total = #keys
  if total == 0 then
    fly.frame:SetSize(padding*2 + iconSize, padding*2 + iconSize)
    return
  end

  local cols = math.min(colsMax, total)
  local rows = math.ceil(total / cols)

  fly.frame:SetSize(
    padding*2 + cols*iconSize + (cols-1)*spacing,
    padding*2 + rows*iconSize + (rows-1)*spacing
  )

  for i=1,total do
    local key = keys[i]
    local proxy = fly.proxies[key]
    if proxy then
      local r = math.floor((i-1)/cols)
      local c = (i-1)%cols

      proxy:ClearAllPoints()
      proxy:SetPoint("TOPLEFT", fly.content, "TOPLEFT",
        padding + c*(iconSize+spacing),
        -(padding + r*(iconSize+spacing))
      )
      proxy:SetSize(iconSize, iconSize)
      proxy:SetFrameLevel(fly.content:GetFrameLevel() + 10)
      if proxy.SetIgnoreParentScale then proxy:SetIgnoreParentScale(true) end
      proxy:SetScale(1)
      proxy:Show()
    end
  end
end

function mod:RefreshFlyout()
  local db = GetDB()
  if not db or not mm then return end

  EnsureFlyoutFrames()
  if not fly.frame then return end

  if not (db.enabled and db.flyout and db.flyout.enabled) then
    fly.open = false
    fly.frame:Hide()
    fly.toggle:Hide()
    return
  end

  fly.toggle:Show()
  ApplyFlyoutAnchors(db)

  local list = GetLDBObjects(db)

  -- Build proxies list / order
  wipe(fly.orderKeys)
  for i=1,#list do
    local key = list[i].key
    local obj = list[i].obj
    local btn = list[i].btn

    local proxy = EnsureProxy(key)
    table.insert(fly.orderKeys, key)

    -- Mirror icon texture from real button
    local tex, tc = PullIconTextureFrom(btn)
    if proxy._icon and tex then
      proxy._icon:SetTexture(tex)
      if tc then proxy._icon:SetTexCoord(tc[1],tc[2],tc[3],tc[4]) end
    end

    -- Click proxy -> click real button
    proxy:SetScript("OnClick", function()
      if btn and btn.Click then
        btn:Click()
      elseif obj and obj.OnClick then
        pcall(obj.OnClick, obj)
      end
    end)
  end

  -- Hide unused proxies (if excludes changed)
  for key, proxy in pairs(fly.proxies) do
    local keep = false
    for i=1,#fly.orderKeys do
      if fly.orderKeys[i] == key then keep = true break end
    end
    if not keep then proxy:Hide() end
  end

  LayoutFlyout(db, fly.orderKeys)
end

local function ApplyFlyout(db)
  EnsureFlyoutFrames()
  if not fly.frame then return end

  if not (db.enabled and db.flyout and db.flyout.enabled) then
    fly.open = false
    fly.frame:Hide()
    fly.toggle:Hide()
    return
  end

  fly.toggle:Show()
  ApplyFlyoutAnchors(db)

  if db.flyout.startOpen then
    fly.open = true
    fly.frame:Show()
  end

  mod:RefreshFlyout()
  if not fly.open then fly.frame:Hide() end
end

-- ------------------------------------------------------------
-- Apply
-- ------------------------------------------------------------
function mod:Apply()
  local db = GetDB()
  if not db or not mm then return end

  KillOld()

  if db.enabled == false then
    if orig.stored then
      if orig.w and orig.h then mm:SetSize(orig.w, orig.h) end
      if orig.scale then mm:SetScale(orig.scale) end
    end
    mm:SetMaskTexture(MASK_CIRCLE)
    if border then border:Hide() end

    RestoreFrame(FindTracking())
    RestoreFrame(FindMail())
    RestoreFrame(FindLFG())

    if fly.frame then fly.frame:Hide() end
    if fly.toggle then fly.toggle:Hide() end
    fly.open = false
    return
  end

  ApplyShapeScale(db)
  ApplyBorder(db)
  ApplyZoomBehavior()
  ApplyZone(db)
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
ev:SetScript("OnEvent", function(_, event)
  if not ETBC or not ETBC.db then return end

  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    SafeCall(StoreOriginal)
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

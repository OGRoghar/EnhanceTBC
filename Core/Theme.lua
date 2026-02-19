-- Core/Theme.lua
-- =========================================================
-- EnhanceTBC - Theme/Styling System
-- Uses LibSharedMedia-3.0 for fonts/textures dropdowns
-- and provides helpers modules can call.
-- =========================================================

local _, ETBC = ...
if not ETBC then return end

ETBC.Theme = ETBC.Theme or {}
local T = ETBC.Theme

local LibStub = LibStub
local LSM = LibStub("LibSharedMedia-3.0", true)

T.cache = T.cache or {}

-- Defaults are created in EnhanceTBC.lua (recommended),
-- but we also harden here so options don't error.
local function EnsureThemeDB()
    if not ETBC.db or not ETBC.db.profile then return nil end
    ETBC.db.profile.theme = ETBC.db.profile.theme or {}
    local db = ETBC.db.profile.theme

    if db.font == nil then db.font = "Friz Quadrata TT" end
    if db.fontSize == nil then db.fontSize = 12 end
    if db.fontOutline == nil then db.fontOutline = true end

    if db.statusbar == nil then db.statusbar = "Blizzard" end

    if db.alpha == nil then db.alpha = 1 end

    -- Common colors
    db.colors = db.colors or {}
    db.colors.primary   = db.colors.primary   or { r = 0.20, g = 0.90, b = 1.00, a = 1.00 }
    db.colors.secondary = db.colors.secondary or { r = 1.00, g = 1.00, b = 1.00, a = 1.00 }
    db.colors.warning   = db.colors.warning   or { r = 1.00, g = 0.30, b = 0.30, a = 1.00 }
    db.colors.good      = db.colors.good      or { r = 0.20, g = 1.00, b = 0.20, a = 1.00 }

    return db
end

function T.GetDB(_)
    return EnsureThemeDB()
end

-- ---------------------------------------------------------
-- Media lists (for dropdowns)
-- ---------------------------------------------------------
function T.GetFontList(_)
    if not LSM then return {} end
    return LSM:HashTable("font")
end

function T.GetStatusbarList(_)
    if not LSM then return {} end
    return LSM:HashTable("statusbar")
end

function T:FetchFont(key)
    if not LSM then return STANDARD_TEXT_FONT end
    if key then
        return LSM:Fetch("font", key, true) or STANDARD_TEXT_FONT
    end
    if not self.cache.font then
        self:RefreshCache()
    end
    return self.cache.font or STANDARD_TEXT_FONT
end

function T:FetchStatusbar(key)
    if not LSM then return "Interface\\TargetingFrame\\UI-StatusBar" end
    if key then
        return LSM:Fetch("statusbar", key, true) or "Interface\\TargetingFrame\\UI-StatusBar"
    end
    if not self.cache.statusbar then
        self:RefreshCache()
    end
    return self.cache.statusbar or "Interface\\TargetingFrame\\UI-StatusBar"
end

function T:RefreshCache()
    local db = EnsureThemeDB()
    if not LSM then
        self.cache.font = STANDARD_TEXT_FONT
        self.cache.statusbar = "Interface\\TargetingFrame\\UI-StatusBar"
        return self.cache
    end

    local fontName = (db and db.font) or "Friz Quadrata TT"
    local statusbarName = (db and db.statusbar) or "Blizzard"

    self.cache.fontName = fontName
    self.cache.statusbarName = statusbarName
    self.cache.font = LSM:Fetch("font", fontName, true) or STANDARD_TEXT_FONT
    self.cache.statusbar = LSM:Fetch("statusbar", statusbarName, true) or "Interface\\TargetingFrame\\UI-StatusBar"

    return self.cache
end

-- ---------------------------------------------------------
-- Apply helpers
-- ---------------------------------------------------------
function T:ApplyFontString(fs, fontKey, size, outline)
    if not fs or not fs.SetFont then return end
    local db = EnsureThemeDB()
    local fontPath = self:FetchFont(fontKey)
    local fontSize = tonumber(size or (db and db.fontSize)) or 12
    local useOutline = outline
    if useOutline == nil then useOutline = (db and db.fontOutline) ~= false end
    local flags = useOutline and "OUTLINE" or nil
    fs:SetFont(fontPath, fontSize, flags)
end

function T:ApplyStatusBar(bar, textureKey)
    if not bar or not bar.SetStatusBarTexture then return end
    local tex = self:FetchStatusbar(textureKey)
    bar:SetStatusBarTexture(tex)
end

function T.ApplyAlpha(_, frame, alpha)
    if not frame or not frame.SetAlpha then return end
    local db = EnsureThemeDB()
    local a = tonumber(alpha or (db and db.alpha)) or 1
    if a < 0.05 then a = 0.05 end
    if a > 1 then a = 1 end
    frame:SetAlpha(a)
end

-- Colors
function T.GetColor(_, name)
    local db = EnsureThemeDB()
    if not db or not db.colors then return 1, 1, 1, 1 end
    local c = db.colors[name]
    if not c then return 1, 1, 1, 1 end
    return c.r or 1, c.g or 1, c.b or 1, c.a or 1
end

function T.SetColor(_, name, r, g, b, a)
    local db = EnsureThemeDB()
    if not db then return end
    db.colors = db.colors or {}
    db.colors[name] = db.colors[name] or {}
    local c = db.colors[name]

    -- Validate and clamp color values to 0-1 range
    local function clamp(v, lo, hi)
        v = tonumber(v) or 0
        if v < lo then return lo end
        if v > hi then return hi end
        return v
    end

    if ETBC.Compat and ETBC.Compat.Clamp then
        c.r = ETBC.Compat.Clamp(tonumber(r) or 0, 0, 1)
        c.g = ETBC.Compat.Clamp(tonumber(g) or 0, 0, 1)
        c.b = ETBC.Compat.Clamp(tonumber(b) or 0, 0, 1)
        c.a = ETBC.Compat.Clamp(tonumber(a) or 1, 0, 1)
    else
        -- Fallback with inline clamping
        c.r = clamp(r, 0, 1)
        c.g = clamp(g, 0, 1)
        c.b = clamp(b, 0, 1)
        c.a = clamp(a or 1, 0, 1)
    end
end

-- ---------------------------------------------------------
-- UI palette selection
-- ---------------------------------------------------------
local DEFAULT_PALETTES = {
    WarcraftGreen = {
        bg = { 0.05, 0.07, 0.05, 0.95 },
        panel = { 0.10, 0.13, 0.10, 0.92 },
        border = { 0.15, 0.30, 0.15, 1.00 },
        text = { 0.90, 0.95, 0.90, 1.00 },
        accent = { 0.20, 1.00, 0.20, 1.00 },
        accent2 = { 0.12, 0.55, 0.12, 1.00 },
    },
    BlackSteel = {
        bg = { 0.05, 0.05, 0.06, 0.96 },
        panel = { 0.10, 0.10, 0.12, 0.92 },
        border = { 0.30, 0.30, 0.35, 1.00 },
        text = { 0.92, 0.92, 0.95, 1.00 },
        accent = { 0.20, 1.00, 0.20, 1.00 },
        accent2 = { 0.35, 0.75, 0.35, 1.00 },
    },
}

T.Palettes = T.Palettes or {}
for name, pal in pairs(DEFAULT_PALETTES) do
    if not T.Palettes[name] then
        T.Palettes[name] = pal
    end
end

function T.Get(_)
    local p = ETBC.db and ETBC.db.profile and ETBC.db.profile.general and ETBC.db.profile.general.ui
    local key = (p and p.theme) or "WarcraftGreen"
    return T.Palettes[key] or T.Palettes.WarcraftGreen
end

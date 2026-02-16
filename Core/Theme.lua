-- Core/Theme.lua
-- =========================================================
-- EnhanceTBC - Theme/Styling System
-- Uses LibSharedMedia-3.0 for fonts/textures dropdowns
-- and provides helpers modules can call.
-- =========================================================

local ADDON_NAME, ETBC = ...

if not ETBC then return end

ETBC.Theme = ETBC.Theme or {}
local T = ETBC.Theme

local LibStub = LibStub
local LSM = LibStub("LibSharedMedia-3.0", true)

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

function T:GetDB()
    return EnsureThemeDB()
end

-- ---------------------------------------------------------
-- Media lists (for dropdowns)
-- ---------------------------------------------------------
function T:GetFontList()
    if not LSM then return {} end
    return LSM:HashTable("font")
end

function T:GetStatusbarList()
    if not LSM then return {} end
    return LSM:HashTable("statusbar")
end

function T:FetchFont(key)
    local db = EnsureThemeDB()
    if not LSM then return STANDARD_TEXT_FONT end
    local name = key or (db and db.font) or "Friz Quadrata TT"
    return LSM:Fetch("font", name, true) or STANDARD_TEXT_FONT
end

function T:FetchStatusbar(key)
    local db = EnsureThemeDB()
    if not LSM then return "Interface\\TargetingFrame\\UI-StatusBar" end
    local name = key or (db and db.statusbar) or "Blizzard"
    return LSM:Fetch("statusbar", name, true) or "Interface\\TargetingFrame\\UI-StatusBar"
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

function T:ApplyAlpha(frame, alpha)
    if not frame or not frame.SetAlpha then return end
    local db = EnsureThemeDB()
    local a = tonumber(alpha or (db and db.alpha)) or 1
    if a < 0.05 then a = 0.05 end
    if a > 1 then a = 1 end
    frame:SetAlpha(a)
end

-- Colors
function T:GetColor(name)
    local db = EnsureThemeDB()
    if not db or not db.colors then return 1, 1, 1, 1 end
    local c = db.colors[name]
    if not c then return 1, 1, 1, 1 end
    return c.r or 1, c.g or 1, c.b or 1, c.a or 1
end

function T:SetColor(name, r, g, b, a)
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

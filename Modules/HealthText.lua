-- Modules/HealthText.lua
-- =========================================================
-- EnhanceTBC - HealthText
-- Player/Target/Focus text with full styling
-- =========================================================

local NS = _G.EnhanceTBC
local E = NS and NS.E
if not E then return end

local LibStub = LibStub
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

local MOD = {}
MOD.name = "HealthText"
MOD.desc = "Health text overlays for Player/Target/Focus."
E.modules[MOD.name] = MOD

E:RegisterModuleDefaults(MOD.name, {
    enabled = true,

    font = "Friz Quadrata TT",
    fontSize = 14,
    outline = true,

    format = "BOTH", -- VALUE / PERCENT / BOTH
    shorten = true,
    hideAtFull = false,

    useUnitColor = true,
    customColor = { r=1, g=1, b=1, a=1 },

    shadow = true,
    shadowColor = { r=0, g=0, b=0, a=0.8 },
    shadowOffsetX = 1,
    shadowOffsetY = -1,

    playerPoint = { "CENTER", UIParent, "CENTER", -200, -160 },
    targetPoint = { "CENTER", UIParent, "CENTER",  200, -160 },
    focusPoint  = { "CENTER", UIParent, "CENTER",    0, -200 },
})

local frames = {}

local function Short(v, db)
    v = tonumber(v) or 0
    if not db.shorten then return tostring(v) end
    if v >= 1e6 then return ("%.1fm"):format(v/1e6)
    elseif v >= 1e3 then return ("%.1fk"):format(v/1e3) end
    return tostring(v)
end

local function UnitColor(unit)
    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c then return c.r, c.g, c.b end
    else
        local reaction = UnitReaction(unit, "player")
        if reaction then
            local c = FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
            if c then return c.r, c.g, c.b end
        end
    end
    return 1,1,1
end

local function FetchFont(db)
    local fontPath = db.font
    if LSM and LSM.Fetch then
        fontPath = LSM:Fetch("font", db.font) or fontPath
    end
    return fontPath or STANDARD_TEXT_FONT
end

local function ApplyFont(db)
    local fontPath = FetchFont(db)
    local flags = db.outline and "OUTLINE" or nil

    for _, f in pairs(frames) do
        if f.text and f.text.SetFont then
            f.text:SetFont(fontPath, db.fontSize or 14, flags)
        end
        if db.shadow and f.text then
            local sc = db.shadowColor or {r=0,g=0,b=0,a=1}
            f.text:SetShadowColor(sc.r or 0, sc.g or 0, sc.b or 0, sc.a or 1)
            f.text:SetShadowOffset(tonumber(db.shadowOffsetX) or 1, tonumber(db.shadowOffsetY) or -1)
        else
            if f.text then
                f.text:SetShadowColor(0,0,0,0)
                f.text:SetShadowOffset(0,0)
            end
        end
    end
end

local function UpdateFrame(self)
    local unit = self.unit
    if not unit or not UnitExists(unit) then self:Hide() return end

    local cur, max = UnitHealth(unit), UnitHealthMax(unit)
    if not max or max == 0 then self:Hide() return end

    local db = E:GetModuleDB(MOD.name)
    if db.hideAtFull and cur == max then self:Hide() return end

    local pct = math.floor((cur / max) * 100)
    local t
    if db.format == "VALUE" then t = Short(cur, db)
    elseif db.format == "PERCENT" then t = pct .. "%"
    else t = Short(cur, db) .. " (" .. pct .. "%)" end

    local r,g,b
    if db.useUnitColor then
        r,g,b = UnitColor(unit)
    else
        local c = db.customColor or {r=1,g=1,b=1}
        r,g,b = c.r or 1, c.g or 1, c.b or 1
    end

    self.text:SetTextColor(r,g,b, 1)
    self.text:SetText(t)
    self:Show()
end

local function RegisterUnit(f, unit)
    f.unit = unit
    f:RegisterEvent("UNIT_HEALTH")
    f:RegisterEvent("UNIT_MAXHEALTH")
    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    f:RegisterEvent("PLAYER_FOCUS_CHANGED")
    f:SetScript("OnEvent", function(self, event, arg1)
        if (event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH") and arg1 ~= unit then return end
        UpdateFrame(self)
    end)
    UpdateFrame(f)
end

local function CreateOne(key, unit, defaultPoint)
    local f = CreateFrame("Frame", "EnhanceTBC_HealthText_"..key, UIParent)
    f:SetSize(160, 20)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.text:SetPoint("CENTER")

    RegisterUnit(f, unit)

    if E.Mover and E.Mover.Register then
        E.Mover:Register("HealthText "..key, f, defaultPoint)
    end

    frames[key] = f
end

function MOD:OnLogin()
    local db = E:GetModuleDB(self.name)
    if not db.enabled then return end

    CreateOne("Player", "player", db.playerPoint)
    CreateOne("Target", "target", db.targetPoint)
    CreateOne("Focus",  "focus",  db.focusPoint)

    ApplyFont(db)

    if E.RegisterSettingHandler then
        E:RegisterSettingHandler(MOD.name, function(_, key, _, ndb)
            if key == "font" or key == "fontSize" or key == "outline" or key == "shadow" or key == "shadowColor"
                or key == "shadowOffsetX" or key == "shadowOffsetY" then
                ApplyFont(ndb)
            elseif key == "format" or key == "hideAtFull" or key == "shorten" or key == "useUnitColor" or key == "customColor" then
                for _, f in pairs(frames) do UpdateFrame(f) end
            end
        end)
    end
end

function MOD:GetOptions()
    local function DB() return E:GetModuleDB(MOD.name) end

    local function FontValues()
        local t = {}
        if LSM and LSM.HashTable then
            t = LSM:HashTable("font")
        end
        if not next(t) then
            t["Friz Quadrata TT"] = "Friz Quadrata TT"
            t["Arial"] = "Arial"
            t["Morpheus"] = "Morpheus"
        end
        return t
    end

    return {
        type="group",
        name="HealthText",
        args = {
            enabled = {
                type="toggle", name="Enable", order=1,
                get=function() return DB().enabled~=false end,
                set=function(_,v) DB().enabled=v and true or false; Notify(MOD.name,"enabled",DB().enabled) end,
            },

            fmtHdr = { type="header", name="Format", order=10 },
            format = {
                type="select", name="Format", order=11,
                values={ VALUE="Value", PERCENT="Percent", BOTH="Both" },
                get=function() return DB().format or "BOTH" end,
                set=function(_,v) DB().format=v; Notify(MOD.name,"format",v) end,
            },
            shorten = {
                type="toggle", name="Shorten numbers (1.2k / 1.2m)", order=12,
                get=function() return DB().shorten~=false end,
                set=function(_,v) DB().shorten=v and true or false; Notify(MOD.name,"shorten",v) end,
                disabled=function() return (DB().format == "PERCENT") end,
            },
            hideAtFull = {
                type="toggle", name="Hide at full health", order=13,
                get=function() return DB().hideAtFull==true end,
                set=function(_,v) DB().hideAtFull=v and true or false; Notify(MOD.name,"hideAtFull",v) end,
            },

            styleHdr = { type="header", name="Style", order=20 },
            font = {
                type="select", name="Font", order=21,
                values=function() return FontValues() end,
                get=function() return DB().font or "Friz Quadrata TT" end,
                set=function(_,v) DB().font=v; Notify(MOD.name,"font",v) end,
            },
            fontSize = {
                type="range", name="Font size", order=22, min=8, max=28, step=1,
                get=function() return tonumber(DB().fontSize) or 14 end,
                set=function(_,v) DB().fontSize=v; Notify(MOD.name,"fontSize",v) end,
            },
            outline = {
                type="toggle", name="Outline", order=23,
                get=function() return DB().outline~=false end,
                set=function(_,v) DB().outline=v and true or false; Notify(MOD.name,"outline",v) end,
            },

            colorHdr = { type="header", name="Colors", order=30 },
            useUnitColor = {
                type="toggle", name="Use unit/class colors", order=31,
                get=function() return DB().useUnitColor~=false end,
                set=function(_,v) DB().useUnitColor=v and true or false; Notify(MOD.name,"useUnitColor",v) end,
            },
            customColor = {
                type="color", name="Custom color", order=32, hasAlpha=true,
                get=function()
                    local c=DB().customColor or {r=1,g=1,b=1,a=1}
                    return c.r,c.g,c.b,c.a
                end,
                set=function(_,r,g,b,a)
                    DB().customColor={r=r,g=g,b=b,a=a}; Notify(MOD.name,"customColor",DB().customColor)
                end,
                disabled=function() return DB().useUnitColor~=false end,
            },

            shadowHdr = { type="header", name="Shadow", order=40 },
            shadow = {
                type="toggle", name="Text shadow", order=41,
                get=function() return DB().shadow~=false end,
                set=function(_,v) DB().shadow=v and true or false; Notify(MOD.name,"shadow",v) end,
            },
            shadowColor = {
                type="color", name="Shadow color", order=42, hasAlpha=true,
                get=function() local c=DB().shadowColor or {r=0,g=0,b=0,a=1}; return c.r,c.g,c.b,c.a end,
                set=function(_,r,g,b,a) DB().shadowColor={r=r,g=g,b=b,a=a}; Notify(MOD.name,"shadowColor",DB().shadowColor) end,
                disabled=function() return DB().shadow~=true end,
            },
            shadowOffsetX = {
                type="range", name="Shadow offset X", order=43, min=-5, max=5, step=1,
                get=function() return tonumber(DB().shadowOffsetX) or 1 end,
                set=function(_,v) DB().shadowOffsetX=v; Notify(MOD.name,"shadowOffsetX",v) end,
                disabled=function() return DB().shadow~=true end,
            },
            shadowOffsetY = {
                type="range", name="Shadow offset Y", order=44, min=-5, max=5, step=1,
                get=function() return tonumber(DB().shadowOffsetY) or -1 end,
                set=function(_,v) DB().shadowOffsetY=v; Notify(MOD.name,"shadowOffsetY",v) end,
                disabled=function() return DB().shadow~=true end,
            },
        },
    }
end

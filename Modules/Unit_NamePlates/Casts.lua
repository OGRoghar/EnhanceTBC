-- EnhanceTBC - cast details layered onto Blizzard's native nameplate castbar
local _, ETBC = ...
local mod = ETBC.Modules and ETBC.Modules.Nameplates
if not mod then return end

mod.Internal = mod.Internal or {}
local Casts = {}
mod.Internal.Casts = Casts

local function castingInfo(unit)
  local fn = UnitCastingInfo
  if type(fn) == "function" then
    local ok, name, text, texture, startMS, endMS, _, _, notInterruptible, spellID = pcall(fn, unit)
    if ok and name then return name, text, texture, startMS, endMS, notInterruptible, spellID, false end
  end
  fn = UnitChannelInfo
  if type(fn) == "function" then
    local ok, name, text, texture, startMS, endMS, _, notInterruptible, spellID = pcall(fn, unit)
    if ok and name then return name, text, texture, startMS, endMS, notInterruptible, spellID, true end
  end
end

function Casts:Ensure(unitFrame)
  if unitFrame.etbcCastDetails then return unitFrame.etbcCastDetails end
  local parent = unitFrame.castBarWrapper or unitFrame.castBar or unitFrame
  local f = CreateFrame("Frame", nil, parent)
  f:SetAllPoints(parent)
  f.target = f:CreateFontString(nil, "OVERLAY")
  f.target:SetPoint("TOPRIGHT", parent, "BOTTOMRIGHT", 0, -2)
  f.target:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
  f.target:SetTextColor(0.95, 0.75, 0.25)
  f.remaining = f:CreateFontString(nil, "OVERLAY")
  f.remaining:SetPoint("RIGHT", parent, "RIGHT", -3, 0)
  f.remaining:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
  f:SetScript("OnUpdate", function(self)
    if not self.endTime then return end
    local remaining = math.max(0, self.endTime - GetTime())
    self.remaining:SetText(string.format("%.1f", remaining))
    if remaining <= 0 then self.endTime = nil; self.remaining:SetText("") end
  end)
  unitFrame.etbcCastDetails = f
  return f
end

function Casts:Update(nameplate, unit, db)
  if not nameplate or not nameplate.UnitFrame then return end
  local f = self:Ensure(nameplate.UnitFrame)
  local name, _, _, startMS, endMS, notInterruptible, _, isChannel = castingInfo(unit)
  if not name then
    f.endTime = nil; f.remaining:SetText(""); f.target:SetText(""); f:Hide(); return
  end
  f.endTime = type(endMS) == "number" and endMS / 1000 or nil
  local target = UnitName and UnitName(unit .. "target")
  f.target:SetText(target and target ~= name and (isChannel and "Channel: " or "Target: ") .. target or "")
  local castbar = nameplate.UnitFrame.castBar
  if castbar and castbar.SetStatusBarColor then
    if notInterruptible then castbar:SetStatusBarColor(0.48, 0.48, 0.52, 1, "nameplate_cast_bar")
    else castbar:SetStatusBarColor(0.9, 0.7, 0.05, 1, "nameplate_cast_bar") end
  end
  f:Show()
end

function Casts:Reset(unitFrame)
  if unitFrame and unitFrame.etbcCastDetails then
    unitFrame.etbcCastDetails.endTime = nil
    unitFrame.etbcCastDetails:Hide()
  end
end

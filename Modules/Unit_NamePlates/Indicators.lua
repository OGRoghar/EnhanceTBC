-- EnhanceTBC - classification, target, focus, threat and target-of-target indicators
local _, ETBC = ...
local mod = ETBC.Modules and ETBC.Modules.Nameplates
if not mod then return end

mod.Internal = mod.Internal or {}
local Indicators = {}
mod.Internal.Indicators = Indicators

local CLASSIFICATION = { worldboss = "BOSS", elite = "+", rareelite = "R+", rare = "R", minus = "-", trivial = "-" }

local function font(parent, point, size)
  local text = parent:CreateFontString(nil, "OVERLAY")
  text:SetPoint(unpack(point))
  text:SetFont("Fonts\\FRIZQT__.TTF", size or 8, "OUTLINE")
  return text
end

function Indicators:Ensure(unitFrame)
  if unitFrame.etbcIndicators then return unitFrame.etbcIndicators end
  local f = CreateFrame("Frame", nil, unitFrame)
  f:SetAllPoints(unitFrame.healthBarWrapper or unitFrame)
  f.classification = font(f, { "RIGHT", unitFrame.healthBarWrapper, "LEFT", -4, 0 }, 9)
  f.targetOfTarget = font(f, { "TOPRIGHT", unitFrame.healthBarWrapper, "BOTTOMRIGHT", 0, -2 }, 8)
  f.targetOfTarget:SetTextColor(0.85, 0.85, 0.85)
  f.threat = font(f, { "TOPLEFT", unitFrame.healthBarWrapper, "BOTTOMLEFT", 0, -2 }, 8)
  unitFrame.etbcIndicators = f
  return f
end

function Indicators:Update(nameplate, snapshot, db)
  if not nameplate or not nameplate.UnitFrame or not snapshot then return end
  local f = self:Ensure(nameplate.UnitFrame)
  local cfg, targetCfg, threatCfg = db.indicators or {}, db.targeting or {}, db.threat or {}
  f.classification:SetText(cfg.classification == false and "" or (CLASSIFICATION[snapshot.classification] or ""))
  local redundant = snapshot.targetOfTarget == nil or snapshot.targetOfTarget == snapshot.name
  f.targetOfTarget:SetText(cfg.targetOfTarget == false or targetCfg.showTargetOfTarget == false or redundant
    and "" or snapshot.targetOfTarget)
  if threatCfg.enabled and threatCfg.showPercent and type(snapshot.threatPercent) == "number" then
    f.threat:SetText(string.format("%d%%", math.floor(snapshot.threatPercent + 0.5)))
  else
    f.threat:SetText("")
  end
  local policy = mod.Internal.State and mod.Internal.State:GetCategoryPolicy(snapshot, db)
  local alpha = policy and policy.alpha or 1
  if snapshot.isTarget then alpha = targetCfg.targetAlpha or 1
  elseif not snapshot.isFocus then alpha = targetCfg.nonTargetAlpha or alpha end
  -- Do not scale Blizzard's UnitFrame. Target changes cause Blizzard to
  -- reapply native nameplate transforms; scaling that owned frame can move
  -- custom children (notably the power bar) into a different coordinate
  -- space. Target/focus emphasis remains explicit through alpha and glow.
  nameplate.UnitFrame:SetAlpha(alpha)
  if nameplate.UnitFrame.healthBar and nameplate.UnitFrame.healthBar.focus_texture then
    nameplate.UnitFrame.healthBar.focus_texture:SetShown(snapshot.isTarget or (snapshot.isFocus and targetCfg.focusGlow ~= false))
  end
end

function Indicators:Reset(unitFrame)
  if not unitFrame then return end
  unitFrame:SetAlpha(1)
  if unitFrame.etbcIndicators then unitFrame.etbcIndicators:Hide() end
end

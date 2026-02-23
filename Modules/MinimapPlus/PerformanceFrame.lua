-- Modules/MinimapPlus/PerformanceFrame.lua
-- EnhanceTBC - MinimapPlus performance row construction (internal).

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}

local mod = ETBC.Modules.MinimapPlus
if not mod then return end

mod.Internal = mod.Internal or {}
local H = {}
mod.Internal.PerformanceFrame = H

local function GetShared()
  return mod.Internal and mod.Internal.Shared
end

local function GetState()
  local shared = GetShared()
  return shared and shared.state
end

local function CallApplyFont(fs, size)
  local shared = GetShared()
  if shared and type(shared.ApplyFont) == "function" then
    shared.ApplyFont(fs, size)
  end
end

local function PerformanceEnabled()
  local shared = GetShared()
  if shared and type(shared.PerformanceEnabled) == "function" then
    return shared.PerformanceEnabled()
  end
  return false
end

local function CreatePerformanceFrame()
  local state = GetState()
  if not state then return end
  if state.performanceFrame or not Minimap then return end

  local frame = CreateFrame("Frame", "EnhanceTBC_MinimapPerformanceFrame", Minimap, "BackdropTemplate")
  frame:SetSize(Minimap:GetWidth(), 17)
  frame:SetPoint("BOTTOM", 0, 0)

  frame.ms_text = frame:CreateFontString(nil, "OVERLAY")
  frame.ms_text:SetSize(40, frame:GetHeight())
  frame.ms_text:SetPoint("LEFT", 90, 0)
  frame.ms_text:SetJustifyH("LEFT")
  frame.ms_text:SetJustifyV("MIDDLE")
  CallApplyFont(frame.ms_text, 8)

  frame.fps_text = frame:CreateFontString(nil, "OVERLAY")
  frame.fps_text:SetSize(45, frame:GetHeight())
  frame.fps_text:SetPoint("LEFT", 126, 0)
  frame.fps_text:SetJustifyH("LEFT")
  frame.fps_text:SetJustifyV("MIDDLE")
  CallApplyFont(frame.fps_text, 8)

  function frame:updateMsDisplay()
    if not PerformanceEnabled() then return end
    local _, _, _, latency = GetNetStats()
    if latency then
      if latency > 999 then latency = 999 end
      self.ms_text:SetText(latency .. "ms")
      if latency < 100 then
        self.ms_text:SetTextColor(0, 0.75, 0.2)
      elseif latency < 250 then
        self.ms_text:SetTextColor(1, 0.82, 0)
      else
        self.ms_text:SetTextColor(0.8, 0, 0)
      end
    end
  end

  function frame:updateFpsDisplay()
    if not PerformanceEnabled() then return end
    local framerate = GetFramerate()
    if framerate then
      self.fps_text:SetText(math.floor(framerate + 0.5) .. "fps")
    end
  end

  if not PerformanceEnabled() then frame:Hide() end
  state.performanceFrame = frame
end

H.CreatePerformanceFrame = CreatePerformanceFrame

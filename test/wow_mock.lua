local M = {}

local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for k, v in pairs(value) do out[copy(k, seen)] = copy(v, seen) end
  return out
end

local function new_object(kind, state)
  local object = { __kind = kind, scripts = {}, events = {}, shown = true }
  local methods = {}

  function methods:SetScript(name, fn) self.scripts[name] = fn end
  function methods:GetScript(name) return self.scripts[name] end
  function methods:HookScript(name, fn) self.scripts[name] = fn end
  function methods:RegisterEvent(name) self.events[name] = true end
  function methods:UnregisterEvent(name) self.events[name] = nil end
  function methods:UnregisterAllEvents() self.events = {} end
  function methods:IsEventRegistered(name) return self.events[name] and true or false end
  function methods:Show() self.shown = true end
  function methods:Hide() self.shown = false end
  function methods:IsShown() return self.shown end
  function methods:SetShown(value) self.shown = value and true or false end
  function methods:Enable() self.enabled = true end
  function methods:Disable() self.enabled = false end
  function methods:IsEnabled() return self.enabled ~= false end
  function methods:SetEnabled(value) self.enabled = value and true or false end
  function methods:SetAllPoints(relative)
    if relative ~= nil and type(relative) ~= "table" then
      error("SetAllPoints expected a region or nil, got " .. type(relative), 2)
    end
    self.allPoints = relative or true
  end
  function methods:SetPoint(...) self.point = { ... } end
  function methods:GetPoint() return unpack(self.point or { "CENTER", nil, "CENTER", 0, 0 }) end
  function methods:ClearAllPoints() self.point = nil end
  function methods:SetSize(w, h) self.width, self.height = w, h end
  function methods:SetWidth(w) self.width = w end
  function methods:SetHeight(h) self.height = h end
  function methods:GetWidth() return self.width or 100 end
  function methods:GetHeight() return self.height or 20 end
  function methods:GetRight() return 100 end
  function methods:GetLeft() return 0 end
  function methods:GetTop() return 100 end
  function methods:GetBottom() return 0 end
  function methods:GetCenter() return 50, 50 end
  function methods:GetEffectiveScale() return 1 end
  function methods:GetScale() return self.scale or 1 end
  function methods:SetScale(v) self.scale = v end
  function methods:SetAlpha(v) self.alpha = v end
  function methods:GetAlpha() return self.alpha or 1 end
  function methods:SetText(v) self.text = tostring(v or "") end
  function methods:GetText() return self.text or "" end
  function methods:SetValue(v) self.value = v end
  function methods:GetValue() return self.value or 0 end
  function methods:SetMinMaxValues(a, b) self.minValue, self.maxValue = a, b end
  function methods:GetMinMaxValues() return self.minValue or 0, self.maxValue or 1 end
  function methods:CreateTexture() return new_object("Texture", state) end
  function methods:CreateFontString() return new_object("FontString", state) end
  function methods:CreateAnimationGroup() return new_object("AnimationGroup", state) end
  function methods:CreateAnimation() return new_object("Animation", state) end
  function methods:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
  function methods:GetName() return self.name end
  function methods:GetParent() return self.parent end
  function methods:SetParent(parent) self.parent = parent end
  function methods:IsForbidden() return false end
  function methods:IsProtected() return false end
  function methods:GetChildren() return nil end
  function methods:GetRegions() return nil end
  function methods:NumLines() return 0 end

  setmetatable(object, {
    __index = function(self, key)
      local method = methods[key]
      if method then return method end
      method = function() return nil end
      methods[key] = method
      return method
    end,
  })
  state.objects[#state.objects + 1] = object
  return object
end

local function addon_methods(addon, state)
  function addon:RegisterChatCommand() end
  function addon:RegisterEvent() end
  function addon:RegisterComm() end
  function addon:ScheduleTimer(fn) state.timers[#state.timers + 1] = fn; return #state.timers end
  function addon:ScheduleRepeatingTimer(fn) state.timers[#state.timers + 1] = fn; return #state.timers end
  function addon:CancelTimer() end
  function addon:Print(message) state.messages[#state.messages + 1] = tostring(message) end
  function addon:SecureHook() end
  function addon:HookScript() end
  function addon:UnhookAll() end
  return addon
end

function M.new(root)
  local state = {
    root = root,
    objects = {},
    timers = {},
    cvars = {},
    messages = {},
    globalsWritten = {},
    namedFrames = {},
    loadedAddons = {},
  }
  local env = {}
  setmetatable(env, { __index = _G, __newindex = function(t, k, v)
    state.globalsWritten[k] = true
    rawset(t, k, v)
  end })
  env._G = env
  env.unpack = unpack
  env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
  env.strsplit = function(_, text) return text end
  env.strjoin = function(sep, ...) return table.concat({ ... }, sep) end
  env.tContains = function(t, value) for _, v in pairs(t) do if v == value then return true end end end
  env.time = function() return 123456 end
  env.date = os.date
  env.debugprofilestop = function() return 0 end
  env.geterrorhandler = function() return function(err) error(err, 0) end end
  env.UIParent = new_object("Frame", state)
  env.UIParent.name = "UIParent"
  env.WorldFrame = new_object("Frame", state)
  env.DEFAULT_CHAT_FRAME = new_object("ChatFrame", state)
  env.SELECTED_CHAT_FRAME = env.DEFAULT_CHAT_FRAME
  env.ChatFrame1 = env.DEFAULT_CHAT_FRAME
  env.GameTooltip = new_object("GameTooltip", state)
  env.GameTooltipStatusBar = new_object("StatusBar", state)
  env.ItemRefTooltip = new_object("GameTooltip", state)
  env.Minimap = new_object("Minimap", state)
  env.MailFrame = new_object("Frame", state)
  env.MerchantFrame = new_object("Frame", state)
  env.StaticPopupDialogs = {}
  env.SlashCmdList = {}
  env.YES, env.NO, env.OKAY, env.CANCEL, env.ACCEPT, env.CLOSE = "Yes", "No", "Okay", "Cancel", "Accept", "Close"
  env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
  env.NORMAL_FONT_COLOR_CODE, env.FONT_COLOR_CODE_CLOSE = "", ""
  env.RAID_CLASS_COLORS = {}
  env.CUSTOM_CLASS_COLORS = nil
  env.SOUNDKIT = { TELL_MESSAGE = 1 }
  env.NUM_BAG_SLOTS, env.NUM_CHAT_WINDOWS = 4, 1
  env.BNET_CLIENT_WOW = "WoW"
  env.CreateFrame = function(kind, name, parent)
    local frame = new_object(kind or "Frame", state)
    frame.name, frame.parent = name, parent
    if name then env[name] = frame; state.namedFrames[name] = frame end
    return frame
  end
  env.CreateFramePool = function() return new_object("FramePool", state) end
  env.CreateTexturePool = function() return new_object("TexturePool", state) end
  env.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 1, GetRGB = function(self) return self.r, self.g, self.b end } end
  env.CreateFromMixins = function(...) local out = {}; for i = 1, select('#', ...) do for k, v in pairs(select(i, ...)) do out[k] = v end end return out end
  env.Mixin = function(out, ...) for i = 1, select('#', ...) do for k, v in pairs(select(i, ...)) do out[k] = v end end return out end
  env.hooksecurefunc = function() end
  env.StaticPopup_Show = function(key, _, _, data)
    state.lastPopup = { key = key, data = data }
    return new_object("Popup", state)
  end
  env.GetTime = function() return state.now or 0 end
  env.GetBuildInfo = function() return "2.5.6", "68575", "", 20506 end
  env.GetCVar = function(name) return state.cvars[name] end
  env.SetCVar = function(name, value) state.cvars[name] = tostring(value) end
  env.InCombatLockdown = function() return state.inCombat or false end
  env.UnitAffectingCombat = function() return state.inCombat or false end
  env.UnitExists = function(unit) return unit ~= nil and unit ~= "" end
  env.UnitIsUnit = function(a, b) return a == b end
  env.IsShiftKeyDown = function() return state.shiftDown or false end
  env.PlaySound = function() return true end
  env.PlaySoundFile = function() return true end
  env.C_Timer = {
    After = function(_, fn) state.timers[#state.timers + 1] = fn end,
    NewTicker = function(_, fn)
      local ticker = new_object("Ticker", state)
      ticker.callback = fn
      function ticker:Cancel() self.cancelled = true end
      state.lastTicker = ticker
      return ticker
    end,
  }
  env.C_NamePlate = {
    GetNamePlates = function() return {} end,
    GetNamePlateForUnit = function(unit) if unit == nil then error("nil unit") end return nil end,
    SetNamePlateSize = function() end,
  }
  env.C_AddOns = {
    GetAddOnMetadata = function(_, field) if field == "Version" then return "test" end end,
    IsAddOnLoaded = function(name) return state.loadedAddons[name] and true or false end,
  }
  env.LoadAddOn = function(name) state.loadedAddons[name] = true; return true end
  env.Enum = {
    AddOnProfilerMetric = {
      SessionAverageTime = 0, RecentAverageTime = 1, LastTime = 3, PeakTime = 4,
      CountTimeOver1Ms = 5, CountTimeOver5Ms = 6, CountTimeOver10Ms = 7,
    },
  }
  env.C_AddOnProfiler = {
    IsEnabled = function() return true end,
    GetAddOnMetric = function(_, metric) return metric + 0.25 end,
    CheckForPerformanceMessage = function() return nil end,
  }
  env.C_Item = { GetItemInfo = function() end, GetItemInfoInstant = function() end }
  env.C_UnitAuras = { GetAuraDataByIndex = function() end }
  env.C_GossipInfo = { GetOptions = function() return {} end }
  env.C_Mail = {}
  env.C_Container = {}
  env.Settings = { RegisterCanvasLayoutCategory = function() return new_object("Category", state) end, RegisterAddOnCategory = function() end, OpenToCategory = function() end }

  local libraries = {}
  local AceAddon = {}
  function AceAddon:NewAddon(target) return addon_methods(target or {}, state) end
  local AceDB = {}
  function AceDB:New(_, defaults) return { profile = copy(defaults and defaults.profile or {}), global = copy(defaults and defaults.global or {}) } end
  local AceConfig = { RegisterOptionsTable = function() end }
  local AceConfigDialog = { AddToBlizOptions = function() return new_object("OptionsPanel", state) end, Open = function() end }
  local AceDBOptions = { GetOptionsTable = function() return {} end }
  local AceLocale = { NewLocale = function() return {} end, GetLocale = function() return {} end }
  local CallbackHandler = {}
  function CallbackHandler:New(target)
    local handlers = {}
    target.RegisterCallback = function(owner, event, fn)
      handlers[event] = handlers[event] or {}
      handlers[event][owner] = fn
    end
    target.UnregisterCallback = function(owner, event)
      if handlers[event] then handlers[event][owner] = nil end
    end
    target.UnregisterAllCallbacks = function(owner)
      for _, entries in pairs(handlers) do entries[owner] = nil end
    end
    return {
      Fire = function(_, event, ...)
        for owner, fn in pairs(handlers[event] or {}) do
          if type(fn) == "string" then owner[fn](owner, event, ...) else fn(event, ...) end
        end
      end,
    }
  end
  local AceGUI = { constructors = {}, versions = {} }
  function AceGUI:RegisterWidgetType(kind, constructor, version)
    self.constructors[kind], self.versions[kind] = constructor, version
  end
  function AceGUI:GetWidgetVersion(kind) return self.versions[kind] end
  function AceGUI:RegisterAsWidget(widget)
    widget.Fire = widget.Fire or function() end
    widget.SetFullWidth = widget.SetFullWidth or function() end
    return widget
  end
  function AceGUI:Create(kind)
    local constructor = self.constructors[kind]
    if constructor then return constructor() end
    return new_object("AceGUIWidget", state)
  end
  local LSM = { Register = function() end, Fetch = function(_, _, key) return key end, HashTable = function() return {} end }
  libraries["AceAddon-3.0"], libraries["AceDB-3.0"] = AceAddon, AceDB
  libraries["AceConfig-3.0"], libraries["AceConfigDialog-3.0"] = AceConfig, AceConfigDialog
  libraries["AceDBOptions-3.0"], libraries["AceLocale-3.0"] = AceDBOptions, AceLocale
  libraries["CallbackHandler-1.0"] = CallbackHandler
  libraries["AceGUI-3.0"] = AceGUI
  libraries["LibSharedMedia-3.0"] = LSM
  env.LibStub = function(name, silent)
    local lib = libraries[name]
    if lib then return lib end
    if silent then return nil end
    lib = new_object(name, state); libraries[name] = lib; return lib
  end

  state.env = env
  state.addon = {}
  function state:runTimers()
    local pending = self.timers
    self.timers = {}
    for _, fn in ipairs(pending) do if type(fn) == "function" then fn() end end
  end
  return state
end

return M

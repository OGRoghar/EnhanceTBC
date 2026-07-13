local root = arg and arg[1] or os.getenv("ETBC_TEST_ROOT") or "."
root = root:gsub("\\", "/"):gsub("/$", "")
package.path = root .. "/test/?.lua;" .. root .. "/test/?/init.lua;" .. package.path

local Mock = require("wow_mock")
local fixtures = dofile(root .. "/test/fixtures/profiles.lua")
local passed, failed = 0, 0

local function test(name, fn)
  local ok, err = xpcall(fn, debug.traceback)
  if ok then
    passed = passed + 1
    print("PASS " .. name)
  else
    failed = failed + 1
    print("FAIL " .. name .. "\n" .. tostring(err))
  end
end

local function equal(actual, expected, message)
  if actual ~= expected then error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end

local function truthy(value, message) if not value then error(message or "expected truthy value", 2) end end

local function load_addon_file(state, relative)
  local path = root .. "/" .. relative:gsub("\\", "/")
  local chunk, err = loadfile(path)
  if not chunk then error(relative .. ": " .. tostring(err), 2) end
  setfenv(chunk, state.env)
  local ok, loadErr = xpcall(function() chunk("EnhanceTBC", state.addon) end, debug.traceback)
  if not ok then error(relative .. ": " .. tostring(loadErr), 2) end
end

local function normalize(path)
  path = path:gsub("\\", "/")
  local parts = {}
  for part in path:gmatch("[^/]+") do
    if part == ".." then parts[#parts] = nil elseif part ~= "." then parts[#parts + 1] = part end
  end
  return table.concat(parts, "/")
end

local function dirname(path) return path:match("^(.*)/[^/]+$") or "" end

local function manifest_graph()
  local graph, seen, active = {}, {}, {}
  local function visit(relative)
    relative = normalize(relative)
    if active[relative] then error("manifest include cycle: " .. relative) end
    if seen[relative] then error("duplicate manifest load: " .. relative) end
    local handle = assert(io.open(root .. "/" .. relative, "rb"), "missing manifest path: " .. relative)
    local content = handle:read("*a")
    handle:close()
    if relative:lower():match("%.xml$") then
      content = content:gsub("<!%-%-[%s%S]-%-%->", "")
    end
    seen[relative], active[relative] = true, true
    graph[#graph + 1] = relative
    if relative:lower():match("%.xml$") then
      local cursor = 1
      while true do
        local includeStart, includeEnd, includeFile = content:find(
          "<%s*Include%s+[^>]-file%s*=%s*[\"']([^\"']+)[\"'][^>]*>", cursor
        )
        local scriptStart, scriptEnd, scriptFile = content:find(
          "<%s*Script%s+[^>]-file%s*=%s*[\"']([^\"']+)[\"'][^>]*>", cursor
        )
        if not includeStart and not scriptStart then break end
        if includeStart and (not scriptStart or includeStart < scriptStart) then
          visit(normalize(dirname(relative) .. "/" .. includeFile))
          cursor = includeEnd + 1
        else
          visit(normalize(dirname(relative) .. "/" .. scriptFile))
          cursor = scriptEnd + 1
        end
      end
    end
    active[relative] = nil
  end
  for line in io.lines(root .. "/EnhanceTBC.toc") do
    local entry = line:match("^%s*([^#].-)%s*$")
    if entry then visit(entry) end
  end
  return graph
end

local function toc_first_party()
  local files = {}
  for _, entry in ipairs(manifest_graph()) do
    if entry:lower():match("%.lua$") and not entry:match("^Libs/") and not entry:match("^locales/") then
      files[#files + 1] = entry
    end
  end
  return files
end

test("TOC first-party load order", function()
  local state = Mock.new(root)
  local graph, xmlCount = manifest_graph(), 0
  for _, file in ipairs(graph) do if file:lower():match("%.xml$") then xmlCount = xmlCount + 1 end end
  equal(xmlCount, 29, "unexpected reachable XML manifest count")
  local expected = {}
  for line in io.lines(root .. "/test/expected-first-party-load-order.txt") do
    if line ~= "" then expected[#expected + 1] = line end
  end
  local actual = toc_first_party()
  equal(#actual, #expected, "first-party load-order length changed")
  for i = 1, #expected do equal(actual[i], expected[i], "first-party load order changed at index " .. i) end
  for _, file in ipairs(toc_first_party()) do load_addon_file(state, file) end
  truthy(state.env.ETBC, "global addon namespace missing")
  truthy(state.addon.Modules, "module registry missing")
  truthy(state.addon.SettingsRegistry, "settings registry missing")
  for _, file in ipairs(toc_first_party()) do load_addon_file(state, file) end
end)

test("core initialization is idempotent", function()
  local state = Mock.new(root)
  load_addon_file(state, "Core/Init.lua")
  local modules = state.addon.Modules
  load_addon_file(state, "Core/Init.lua")
  equal(state.addon.Modules, modules, "module registry replaced")
end)

test("mover slash helper is locally scoped and repeatable", function()
  local state = Mock.new(root)
  state.addon.ApplyBus = { Register = function() end, Notify = function() end }
  state.addon.db = { profile = { general = { enabled = true }, mover = {} } }
  load_addon_file(state, "Core/Mover.lua")
  state.addon.Mover:SetupChatCommands()
  state.addon.Mover:SetupChatCommands()
  truthy(state.env.SlashCmdList.ENHANCETBCMOVER, "mover slash handler missing")
  equal(state.env.EnsureSlash, nil, "EnsureSlash leaked globally")
end)

test("frame mock rejects boolean SetAllPoints arguments", function()
  local state = Mock.new(root)
  local texture = state.env.CreateFrame("Frame"):CreateTexture()
  truthy(pcall(texture.SetAllPoints, texture))
  equal(pcall(texture.SetAllPoints, texture, true), false)
end)

test("camera restore honors false force", function()
  local state = Mock.new(root)
  state.addon.ApplyBus = { Register = function() end }
  state.addon.db = { profile = { general = { enabled = true }, ui = { enabled = true, cameraMaxZoom = true, cameraMaxZoomFactor = 3 } } }
  load_addon_file(state, "Modules/UI.lua")
  state.cvars.cameraDistanceMaxZoomFactor = "2.6"
  state.addon.Modules.UI.StoreCameraZoomIfNeeded()
  state.cvars.cameraDistanceMaxZoomFactor = "3"
  state.addon.Modules.UI.RestoreCameraZoom(false)
  equal(state.cvars.cameraDistanceMaxZoomFactor, "3", "zoom restored despite enabled setting")
  state.addon.Modules.UI.RestoreCameraZoom(true)
  equal(state.cvars.cameraDistanceMaxZoomFactor, "2.6", "forced zoom restore failed")
end)

test("compatibility wrappers tolerate missing optional APIs", function()
  local state = Mock.new(root)
  state.env.GetSpellInfo = nil
  state.env.GetGossipOptions = nil
  load_addon_file(state, "Core/Compat.lua")
  equal(state.addon.Compat.GetSpellInfoByID(12345), nil)
  local options = state.addon.Compat.GetGossipOptions()
  equal(type(options), "table")
  equal(#options, 0)
end)

test("preset apply and undo restore profile fixture", function()
  local state = Mock.new(root)
  state.addon.db = { profile = { general = { enabled = true }, nameplates = { enemy_nameplate_width = 77 } }, global = {} }
  load_addon_file(state, "Core/Presets.lua")
  truthy(state.addon.Presets:Apply("ENHANCED"))
  equal(state.addon.db.profile.nameplates.enemy_nameplate_width, 120)
  truthy(state.addon.Presets:Undo())
  equal(state.addon.db.profile.nameplates.enemy_nameplate_width, 77)
end)

test("profile fixtures are isolated and structurally valid", function()
  equal(fixtures.legacy.general.profileSchemaVersion, 1)
  equal(fixtures.current.general.profileSchemaVersion, 2)
  equal(type(fixtures.invalid), "string")
end)

test("profile migration, import sanitation, undo, and module reset", function()
  local state = Mock.new(root)
  state.addon.defaults = { profile = fixtures.legacy }
  state.addon.BuildOptions = function() return { type = "group", args = {} } end
  state.addon.ApplyBus = {
    notifications = 0,
    NotifyAllNow = function(self) self.notifications = self.notifications + 1 end,
  }
  load_addon_file(state, "Core/EnhanceTBC.lua")
  state.addon:OnInitialize()
  equal(state.addon.db.profile.general.profileSchemaVersion, 2)
  equal(state.addon.db.profile.ui.config.scale, 1.25)

  local dialog = state.env.StaticPopupDialogs.ETBC_PROFILE_IMPORT_CONFIRM
  truthy(dialog and dialog.OnAccept, "profile import confirmation missing")
  dialog.OnAccept(nil, {
    owner = state.addon,
    payload = { addon = "EnhanceTBC", version = 1, interface = 20505, profile = fixtures.legacy },
    sender = "fixture",
  })
  equal(state.addon.db.profile.general.profileSchemaVersion, 2)
  equal(state.addon.db.profile.gcdbar, nil, "removed profile key survived import")
  truthy(state.addon:UndoLastProfileImport())
  equal(state.addon.db.profile.general.profileSchemaVersion, 2)

  state.addon.defaults.profile.nameplates = { enabled = true, enemy_nameplate_width = 109 }
  state.addon.db.profile.nameplates = { enabled = false, enemy_nameplate_width = 200 }
  truthy(state.addon:ResetModuleProfile("nameplates"))
  equal(state.addon.db.profile.nameplates.enemy_nameplate_width, 109)
end)

test("visibility rules react to combat and inversion", function()
  local state = Mock.new(root)
  state.addon.ApplyBus = { Register = function() end, Notify = function() end }
  state.addon.db = { profile = { general = { enabled = true }, visibility = { enabled = true, presets = {} } } }
  load_addon_file(state, "Visibility/Visibility.lua")
  state.inCombat = false
  equal(state.addon.Visibility:Evaluate({ enabled = true, mode = "RULES", requireCombat = true }), false)
  state.inCombat = true
  equal(state.addon.Visibility:Evaluate({ enabled = true, mode = "RULES", requireCombat = true }), true)
  equal(state.addon.Visibility:Evaluate({ enabled = true, mode = "RULES", requireCombat = true, invert = true }), false)
end)

test("auto gossip cancels delayed selection when closed", function()
  local state = Mock.new(root)
  local selected = 0
  state.addon.ApplyBus = { Register = function() end, Notify = function() end }
  state.addon.Compat = {
    GetGossipOptions = function() return { { index = 1, name = "Take me home", selectable = true } } end,
    SelectGossipOption = function() selected = selected + 1; return true end,
  }
  state.addon.db = { profile = { general = { enabled = true }, autoGossip = { enabled = true, delay = 1, useGossipInfo = true, options = { "home" }, optionIDs = {} } } }
  load_addon_file(state, "Modules/AutoGossip.lua")
  state.addon.Modules.AutoGossip:Apply()
  local driver = state.namedFrames.EnhanceTBC_AutoGossipDriver
  driver.scripts.OnEvent(driver, "GOSSIP_SHOW")
  driver.scripts.OnEvent(driver, "GOSSIP_CLOSED")
  state:runTimers()
  equal(selected, 0, "closed gossip selected a delayed option")
end)

test("mailbox close cancels its active ticker", function()
  local state = Mock.new(root)
  local listeners = {}
  state.addon.ApplyBus = { Register = function(_, key, fn) listeners[key] = fn end }
  state.addon.db = {
    profile = {
      general = { enabled = true },
      mailbox = {
        enabled = true,
        autoCollect = false,
        throttle = { enabled = true, interval = 0.05 },
        takeMoney = false,
        takeItems = false,
        deleteEmpty = false,
      },
    },
  }
  state.env.GetInboxNumItems = function() return 0 end
  load_addon_file(state, "Modules/Mailbox.lua")
  listeners.mailbox()
  state.addon.Modules.Mailbox:RunNow()
  local ticker = state.lastTicker
  truthy(ticker, "mailbox ticker was not created")
  local driver = state.namedFrames.EnhanceTBC_MailboxDriver
  driver.scripts.OnEvent(driver, "MAIL_CLOSED")
  equal(ticker.cancelled, true, "mailbox ticker survived MAIL_CLOSED")
end)

test("merchant close cancels its active sell ticker", function()
  local state = Mock.new(root)
  local listeners = {}
  state.addon.ApplyBus = { Register = function(_, key, fn) listeners[key] = fn end }
  state.addon.db = {
    profile = {
      general = { enabled = true },
      vendor = {
        enabled = true, bypassWithShift = false, autoRepair = false, autoSellJunk = true,
        maxQualityToSell = 0, confirmHighValue = false, printSummary = false,
        throttle = { enabled = true, interval = 0.05, maxPerTick = 1 },
        whitelist = { enabled = false, items = {} },
        blacklist = { enabled = false, items = {} },
      },
    },
  }
  state.env.C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end,
    GetContainerItemLink = function() return "item:12345" end,
    GetContainerItemInfo = function() return { stackCount = 1, isLocked = false } end,
    UseContainerItem = function() end,
  }
  state.env.C_Item.GetItemInfo = function() return "Junk", nil, 0, nil, nil, nil, nil, nil, nil, nil, 10 end
  load_addon_file(state, "Modules/Vendor.lua")
  listeners.vendor()
  local driver = state.namedFrames.EnhanceTBC_VendorDriver
  driver.scripts.OnEvent(driver, "MERCHANT_SHOW")
  local ticker = state.lastTicker
  truthy(ticker, "vendor ticker was not created")
  driver.scripts.OnEvent(driver, "MERCHANT_CLOSED")
  equal(ticker.cancelled, true, "vendor ticker survived MERCHANT_CLOSED")
end)

test("public API v1 supports controlled integrations and ordered callbacks", function()
  local state = Mock.new(root)
  for _, file in ipairs(toc_first_party()) do load_addon_file(state, file) end
  local api = state.env.EnhanceTBC_API
  truthy(api, "public API global missing")
  equal(api.GetAPIVersion(), 1)
  equal(api.IsReady(), false)
  truthy(not api.RegisterCallback({}, "UNKNOWN_EVENT", function() end))

  local owner, events = {}, {}
  api.RegisterCallback(owner, "READY", function(event) events[#events + 1] = event end)
  api.RegisterCallback(owner, "MODULE_STATE_CHANGED", function(event, key, enabled)
    events[#events + 1] = event .. ":" .. key .. ":" .. tostring(enabled)
  end)
  api.RegisterCallback(owner, "SETTINGS_APPLIED", function(event, key)
    events[#events + 1] = event .. ":" .. key
  end)
  api.RegisterCallback(owner, "PROFILE_CHANGED", function(event, reason)
    events[#events + 1] = event .. ":" .. reason
  end)

  state.addon:OnInitialize()
  equal(api.IsReady(), true)
  equal(events[1], "READY")
  local stateCopy = assert(api.GetModuleState("minimapPlus"))
  equal(stateCopy.key, "minimapplus")
  truthy(api.SetModuleEnabled("minimapPlus", false))
  state:runTimers()
  equal(events[#events - 1], "MODULE_STATE_CHANGED:minimapplus:false")
  equal(events[#events], "SETTINGS_APPLIED:minimapplus")
  truthy(not api.SetModuleEnabled("missing", true))
  truthy(not api.SetModuleEnabled("general", false))
  truthy(not api.RequestRefresh("missing"))
  local frame = state.env.CreateFrame("Frame")
  truthy(api.RegisterMover("ExternalMover", frame, { default = { point = "CENTER" } }))
  truthy(state.addon.Mover:GetRegistered().ExternalMover)
  truthy(api.UnregisterMover("ExternalMover"))
  equal(state.addon.Mover:GetRegistered().ExternalMover, nil)
  truthy(not api.UnregisterMover("InternalMover"))

  truthy(api.BindVisibility("ExternalVisibility", frame, function() return { enabled = true, mode = "ALWAYS" } end))
  truthy(api.UnbindVisibility("ExternalVisibility"))
  truthy(not api.UnbindVisibility("InternalVisibility"))
  truthy(api.EnterEditMode("all"))
  equal(state.addon.db.profile.mover.moveMode, true)

  local diagnostics = assert(api.GetDiagnostics())
  diagnostics.performance.metrics.peakMs = 999
  local fresh = assert(api.GetDiagnostics())
  truthy(fresh.performance.metrics.peakMs ~= 999, "diagnostics exposed mutable internal state")
  state.addon:OnProfileChanged()
  equal(state.env.EnhanceTBC_API, api, "public API identity changed")
  equal(events[#events], "PROFILE_CHANGED:profile-changed")
end)

test("profiler facade handles availability, enums, restrictions, and warnings", function()
  local state = Mock.new(root)
  load_addon_file(state, "Core/PublicAPI.lua")
  local api = state.env.EnhanceTBC_API

  local snapshot = api.GetPerformanceSnapshot()
  equal(snapshot.available, true)
  equal(snapshot.enabled, true)
  equal(snapshot.metrics.recentAverageMs, 1.25)

  state.env.C_AddOnProfiler.IsEnabled = function() return false end
  snapshot = api.GetPerformanceSnapshot()
  equal(snapshot.available, true)
  equal(snapshot.enabled, false)

  state.env.C_AddOnProfiler.IsEnabled = function() return true end
  state.env.Enum.AddOnProfilerMetric = nil
  snapshot = api.GetPerformanceSnapshot()
  truthy(snapshot.error:find("enum", 1, true))

  state.env.Enum.AddOnProfilerMetric = { RecentAverageTime = 1 }
  state.env.C_AddOnProfiler.GetAddOnMetric = function() error("restricted") end
  snapshot = api.GetPerformanceSnapshot()
  equal(snapshot.metrics.recentAverageMs, nil)

  state.env.C_AddOnProfiler.GetAddOnMetric = function() return 2 end
  state.env.C_AddOnProfiler.CheckForPerformanceMessage = function()
    return { addOnName = "EnhanceTBC", metricValue = 2 }
  end
  snapshot = api.GetPerformanceSnapshot()
  equal(snapshot.warning.addOnName, "EnhanceTBC")
  snapshot.warning.addOnName = "changed"
  equal(api.GetPerformanceSnapshot().warning.addOnName, "EnhanceTBC")

  state.env.C_AddOnProfiler = nil
  snapshot = api.GetPerformanceSnapshot()
  equal(snapshot.available, false)
end)

test("modern control center builds pages, searches, migrates, and reopens safely", function()
  local state = Mock.new(root)
  for _, file in ipairs(toc_first_party()) do load_addon_file(state, file) end
  state.addon:OnInitialize()
  local center = assert(state.addon.UI.ControlCenter)
  local model = state.addon.UI.ControlCenterModel:Build()
  truthy(#model.pages > 10, "settings pages were not normalized")
  truthy(model.byKey.general, "general page missing")
  truthy(#state.addon.UI.ControlCenterModel:Search(model, "camera zoom") > 0, "global search found no camera setting")
  state.addon.UI.ConfigWindow:Open()
  truthy(center.frame and center.frame:IsShown(), "control center did not open")
  equal(state.addon.db.profile.ui.config.layoutVersion, 2)
  state.addon:OpenConfig()
  truthy(center.frame:IsShown(), "repeated open hid the control center")
  state.addon.UI.ConfigWindow:Close()
  equal(center.frame:IsShown(), false)
end)

test("control center change history undoes copied values", function()
  local state = Mock.new(root)
  for _, file in ipairs(toc_first_party()) do load_addon_file(state, file) end
  local history = state.addon.UI.ChangeHistory
  local restored
  history:Clear()
  history:Record("example", "Example", { enabled = false }, { enabled = true }, function(value) restored = value end)
  local ok = history:UndoLatest()
  truthy(ok)
  equal(restored.enabled, false)
  restored.enabled = true
  local recent = history:GetRecent(5)
  equal(#recent, 0)
end)

print(("RESULT %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end

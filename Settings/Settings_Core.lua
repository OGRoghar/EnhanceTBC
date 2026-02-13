-- Settings/Settings_Core.lua
local parentAddonName = "EnhanceTBC"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

addon.Settings = addon.Settings or {}
addon.Settings.Core = addon.Settings.Core or {}

local AceConfig = LibStub("AceConfig-3.0", true)
local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
local AceDBOptions = LibStub("AceDBOptions-3.0", true)

-- ------------------------------------------------------------
-- Helpers / Dispatch
-- ------------------------------------------------------------
local function ensureDBTables()
	if not addon.db then return end
	addon.db.core = addon.db.core or {}
	addon.db.general = addon.db.general or {}
	addon.db.modules = addon.db.modules or {}
	addon.db.debug = addon.db.debug or {}
end

local function safeCall(fn, ...)
	if type(fn) == "function" then
		local ok, err = pcall(fn, ...)
		if not ok and addon.db and addon.db.debug and addon.db.debug.enabled then
			print("|cffff0000EnhanceTBC error:|r", err)
		end
		return ok
	end
	return false
end

-- Try to enable/disable modules in multiple possible architectures:
-- 1) AceAddon modules: addon:GetModule("Vendor", true)
-- 2) Plain tables: addon.Vendor.functions.Enable/Disable or InitState
local function normalizeModuleKey(key)
	if not key then return nil end
	key = tostring(key)
	return key:gsub("%s+", "")
end

local function getModuleObject(key)
	key = normalizeModuleKey(key)
	if not key then return nil end

	-- AceAddon style: "Vendor", "Mouse", etc.
	if addon.GetModule then
		local ok, mod = pcall(addon.GetModule, addon, key, true)
		if ok and mod then return mod end
	end

	-- Table style: addon.Vendor, addon.Mouse, etc.
	return addon[key]
end

local function enableModule(key)
	local mod = getModuleObject(key)
	if not mod then return end

	-- AceAddon module enable
	if mod.Enable then safeCall(mod.Enable, mod) end

	-- Common table patterns
	if mod.functions then
		if mod.functions.Enable then safeCall(mod.functions.Enable) end
		if mod.functions.InitState then safeCall(mod.functions.InitState) end
	end

	-- Some modules might have direct InitState
	if mod.InitState then safeCall(mod.InitState, mod) end
end

local function disableModule(key)
	local mod = getModuleObject(key)
	if not mod then return end

	-- AceAddon module disable
	if mod.Disable then safeCall(mod.Disable, mod) end

	-- Common table patterns
	if mod.functions and mod.functions.Disable then safeCall(mod.functions.Disable) end
end

-- Central apply bus (lightweight): call module refreshers when settings change
local function applyCategory(category)
	-- Your addon may already have an apply bus. If so, use it.
	if addon.ApplyBus and type(addon.ApplyBus) == "function" then
		safeCall(addon.ApplyBus, addon, category)
		return
	end
	if addon.functions and type(addon.functions.ApplyBus) == "function" then
		safeCall(addon.functions.ApplyBus, category)
		return
	end

	-- Fallback: try module-specific refresh calls
	if category == "general" then
		if addon.General and addon.General.functions and addon.General.functions.Apply then
			safeCall(addon.General.functions.Apply)
		end
	elseif category == "mouse" then
		if addon.Mouse and addon.Mouse.functions and addon.Mouse.functions.InitState then
			safeCall(addon.Mouse.functions.InitState)
		end
	elseif category == "vendor" then
		if addon.Vendor and addon.Vendor.functions and addon.Vendor.functions.InitState then
			safeCall(addon.Vendor.functions.InitState)
		end
	end
end

-- ------------------------------------------------------------
-- Module list (used by Core -> Modules)
-- Add/remove keys here as your addon grows.
-- ------------------------------------------------------------
local MODULES = {
	{ key = "General", label = "General" },
	{ key = "Mouse", label = "Mouse" },
	{ key = "Tooltip", label = "Tooltip" },
	{ key = "Sounds", label = "Sound" },
	{ key = "Friends", label = "Friends" },
	{ key = "ChatIM", label = "Chat & IM" },
	{ key = "GCDBar", label = "GCD Bar" },
	{ key = "Auras", label = "Auras" },
	{ key = "CombatText", label = "Combat Text" },
	{ key = "ActionTracker", label = "Action Tracker" },
	{ key = "Mover", label = "Mover" },
	{ key = "Vendor", label = "Vendor" },
	{ key = "Mailbox", label = "Mailbox" },
	{ key = "Visibility", label = "Visibility" },
}

local function moduleEnabledGet(info)
	ensureDBTables()
	local k = info[#info]
	return addon.db.modules[k] ~= false
end

local function moduleEnabledSet(info, value)
	ensureDBTables()
	local k = info[#info]
	addon.db.modules[k] = value and true or false

	-- Toggle module runtime, but do not force-load absent modules
	if value then
		enableModule(k)
	else
		disableModule(k)
	end
end

-- ------------------------------------------------------------
-- AceConfig table build
-- ------------------------------------------------------------
function addon.Settings.Core.BuildOptions()
	ensureDBTables()

	addon.options = addon.options or { type = "group", name = "EnhanceTBC", args = {} }
	addon.options.args.core = addon.options.args.core or {
		type = "group",
		name = "Core",
		order = 1,
		args = {},
	}

	local core = addon.options.args.core
	core.args = core.args or {}

	-- Header
	core.args.header = {
		type = "header",
		name = "Core",
		order = 0,
	}

	-- Profiles (AceDBOptions)
	if addon.dbObj and AceDBOptions then
		core.args.profiles = AceDBOptions:GetOptionsTable(addon.dbObj)
		core.args.profiles.order = 1
		core.args.profiles.name = "Profiles"
	end

	-- Modules
	core.args.modules = {
		type = "group",
		name = "Modules",
		order = 2,
		inline = true,
		args = {},
	}

	for i, m in ipairs(MODULES) do
		core.args.modules.args[m.key] = {
			type = "toggle",
			name = m.label,
			desc = "Enable/disable this module.",
			order = i,
			get = moduleEnabledGet,
			set = moduleEnabledSet,
		}
	end

	-- Performance
	core.args.performance = {
		type = "group",
		name = "Performance",
		order = 3,
		inline = true,
		args = {
			throttleMs = {
				type = "range",
				name = "UI update throttle (ms)",
				desc = "Higher = fewer updates (lighter). Lower = snappier (heavier).",
				order = 1,
				min = 0, max = 200, step = 5,
				get = function()
					ensureDBTables()
					return tonumber(addon.db.core.throttleMs) or 25
				end,
				set = function(_, v)
					ensureDBTables()
					addon.db.core.throttleMs = math.floor(tonumber(v) or 25)
					applyCategory("core")
				end,
			},
			scanInterval = {
				type = "range",
				name = "Scanner interval (sec)",
				desc = "How often background scanners may run (if a module uses them).",
				order = 2,
				min = 0.05, max = 2.0, step = 0.05,
				get = function()
					ensureDBTables()
					return tonumber(addon.db.core.scanInterval) or 0.20
				end,
				set = function(_, v)
					ensureDBTables()
					addon.db.core.scanInterval = tonumber(v) or 0.20
					applyCategory("core")
				end,
			},
		},
	}

	-- Debug
	core.args.debug = {
		type = "group",
		name = "Debug",
		order = 4,
		inline = true,
		args = {
			enabled = {
				type = "toggle",
				name = "Enable debug printing",
				order = 1,
				get = function()
					ensureDBTables()
					return addon.db.debug.enabled == true
				end,
				set = function(_, v)
					ensureDBTables()
					addon.db.debug.enabled = v and true or false
				end,
			},
		},
	}

	-- Reset tools
	core.args.reset = {
		type = "group",
		name = "Reset",
		order = 5,
		inline = true,
		args = {
			resetGeneral = {
				type = "execute",
				name = "Reset General to defaults",
				order = 1,
				func = function()
					ensureDBTables()
					addon.db.general = {}
					applyCategory("general")
					if AceConfigRegistry then LibStub("AceConfigRegistry-3.0"):NotifyChange("EnhanceTBC") end
					print("|cff00ff88EnhanceTBC:|r General reset.")
				end,
			},
			resetAllModules = {
				type = "execute",
				name = "Reset all module settings",
				order = 2,
				func = function()
					ensureDBTables()
					-- Leave core/profiles intact; wipe common module buckets
					for _, m in ipairs(MODULES) do
						local k = m.key
						if k ~= "General" then
							-- convention: db tables often match lower-case keys; keep it simple:
							-- we only clear known module roots if you store them that way later.
							-- This is safe even if absent.
							local lower = string.lower(k)
							addon.db[lower] = nil
						end
					end
					applyCategory("core")
					if AceConfigRegistry then LibStub("AceConfigRegistry-3.0"):NotifyChange("EnhanceTBC") end
					print("|cff00ff88EnhanceTBC:|r Module settings reset (where applicable).")
				end,
			},
			resetMover = {
				type = "execute",
				name = "Reset moved frames",
				desc = "Calls the Mover reset if available.",
				order = 3,
				func = function()
					if addon.Mover and addon.Mover.functions and addon.Mover.functions.ResetAll then
						safeCall(addon.Mover.functions.ResetAll)
						print("|cff00ff88EnhanceTBC:|r Mover reset.")
					else
						print("|cffffaa00EnhanceTBC:|r Mover reset not available yet.")
					end
				end,
			},
		},
	}

	return addon.options
end

-- ------------------------------------------------------------
-- Register config (called once after DB is ready)
-- ------------------------------------------------------------
function addon.Settings.Core.RegisterConfig()
	if not AceConfig or not AceConfigDialog then return end
	ensureDBTables()

	local opts = addon.Settings.Core.BuildOptions()
	AceConfig:RegisterOptionsTable("EnhanceTBC", opts)

	-- Add to Blizzard options
	AceConfigDialog:AddToBlizOptions("EnhanceTBC", "EnhanceTBC")

	-- Slash commands to open the config
	_G.SLASH_ENHANCETBC1 = "/etbc"
	_G.SLASH_ENHANCETBC2 = "/enhancetbc"
	SlashCmdList["ENHANCETBC"] = function(msg)
		msg = tostring(msg or ""):lower()
		if msg == "profile" or msg == "profiles" then
			AceConfigDialog:Open("EnhanceTBC")
		else
			AceConfigDialog:Open("EnhanceTBC")
		end
	end
end

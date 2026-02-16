-- Core/Init.lua
-- Single source of truth for the addon namespace + globals
-- Ensures all files, modules, and /run access share the same table.

local ADDON_NAME, ETBC = ...

ETBC = ETBC or {}

-- Make the private addon namespace globally reachable for legacy code and /run debugging.
-- We set both names for compatibility with older modules.
_G.EnhanceTBC = ETBC
_G.ETBC = ETBC

ETBC.name = ADDON_NAME
ETBC.version = ETBC.version or "1.2.1"

ETBC.Modules = ETBC.Modules or {}
ETBC.modules = ETBC.modules or {}
ETBC.orderedModules = ETBC.orderedModules or {}

-- Media paths (useful across modules)
ETBC.media = ETBC.media or {}
ETBC.media.root = "Interface\\AddOns\\EnhanceTBC\\Media\\"
ETBC.media.images = ETBC.media.images or (ETBC.media.root .. "Images\\")
ETBC.media.cursor = ETBC.media.cursor or (ETBC.media.root .. "Cursor\\")
ETBC.media.spells = ETBC.media.spells or (ETBC.media.root .. "Spells\\")

-- Attach AceLocale table for legacy access (EnhanceTBC.L)
local ok, locale = pcall(function()
	return LibStub("AceLocale-3.0"):GetLocale("EnhanceTBC")
end)
if ok and locale then
	ETBC.L = locale
	_G.EnhanceTBC = ETBC
end

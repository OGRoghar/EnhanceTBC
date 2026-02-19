# Changelog

## v1.2.6 - 2026-02-19
- Fixed:
	- AceGUI skin constructor hook safety to avoid runtime errors when widget constructors are plain functions.
	- Profile callback registration signature in core init path.
	- ApplyBus flush queue safety when nested/batched notifications occur, preventing nil key indexing.
- Changed:
	- Config window visual polish updates: header composition, logo layering, module header card, tree styling, and search header UX.
	- Preview panel behavior now uses module-specific preview content for castbar/cooldowns/swingtimer.
	- Preview toggle wiring now targets only valid preview-capable module keys.
	- Tree label rendering no longer reuses stale recycled button text (fixes incorrect category/module labels).
- Media/LSM:
	- Corrected LSM font mapping usage in Auras, ActionTracker, and CombatText settings/modules (`ETBC.LSM` + `"font"`).
- Sync:
	- Copied `test` mirror files to main addon paths; no content deltas remained after sync.

## v1.2.5 - 2026-02-19
- Release:
	- Excluded workspace files (`*.code-workspace`) from packaged release artifacts.

## v1.2.4 - 2026-02-19
- Fixed:
	- Tooltip ApplyBus error when hooking `FriendsTooltip` without `OnTooltipCleared`.
- Changed:
	- Removed GCD Bar module and settings.
	- Removed Player Nameplates module and settings.
	- Minimap sink now only captures LibDBIcon addon buttons, while Blizzard and non-addon minimap elements stay on the minimap.
	- Removed sink debug chat spam.
	- Brightened castbar skin and made backdrop tint track castbar color.
- Release:
	- Added CurseForge/GitHub release workflow on version tags.
	- Added `.pkgmeta` ignore rules for cleaner packaged artifacts.

## v1.2.3 - 2026-02-19
- Added:
	- Faster auto-loot option in CVars convenience settings.
	- Optional "type DELETE" confirmation for deleting rare/epic/legendary items.
	- Per-module reset action in settings groups and `/etbc resetmodule <moduleKey>` slash support.
	- Structured profile slash commands: `/etbc profile export|import|share`.
- Changed:
	- Removed non-functional castbar width/height controls from settings (scale-only sizing).
	- Removed orphaned quick-loot defaults that were not wired to runtime behavior.
	- Updated internal instructions to prefer actionable settings and avoid dead controls.
	- Synced addon metadata version for release readiness.

## v1.2.2 - 2026-02-18
- Added:
	- Windows-friendly local test tasks and a script runner so validation no longer depends on make.
- Changed:
	- Completed full Lua delta triage between main and Part 2 (low/medium/high batches).
	- Confirmed key parity paths were already present in main (visibility integration, ApplyBus live updates, hook-safety guards, and module action hooks).
- Notes:
	- Skipped Part 2 regressions during merge review (older media API usage, minimap icon behavior rollback, removed safeguards/options, and version downgrade paths).

## v1.2.2 - 2026-02-17
- Consolidated visibility handling into a single engine and removed legacy visibility files.
- Moved palette/theme logic into core and removed the UI theme file.
- Integrated Auras, GCDBar, ActionTracker, and Objectives with the Mover system.
- Removed redundant per-module combat visibility toggles and defaults.
- Added EnsureDefaults() across Settings for safer initialization.
- Removed EventHub and related core references.
- Added/updated Player Nameplates module and settings, and cleaned up SwingTimer removal.

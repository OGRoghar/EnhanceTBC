# Changelog

## Unreleased - 2026-02-23
- Added:
	- Castbar+ option to class-color the player castbar's casting/channeling states while preserving custom non-interruptible and latency colors.
	- Config window header mover-mode toggle button for quick entry/exit of mover mode.
- Changed:
	- Refactored `ConfigWindow`, `MinimapPlus`, `Castbar`, and `Unit Nameplates` internals into smaller helper modules/subfolders while preserving public module behavior.
	- Improved custom `/etbc` config coverage so all current settings option types (including `input`/multiline editors) render and work.
	- Reduced duplicate `/etbc` UI clutter by hiding redundant root `enabled` toggles when the module header quick-toggle is present.
	- Corrected custom config categorization/summary coverage for `nameplates` and `swingtimer`.
- Release:
	- Prepared CurseForge + Wago packaging metadata/workflow support (Wago TOC metadata, release workflow env wiring, and package ignore allowlist cleanup).

## v1.2.10 - 2026-02-21
- Added:
	- Minimap tracking state widgets for the icons row and sink tray, with live refresh from `MINIMAP_UPDATE_TRACKING`.
	- Optional quick-toggle cycling for tracking filters via left-click when enabled in settings.
- Fixed:
	- Prevented `MinimapPlus` startup error on `PLAYER_ENTERING_WORLD` from calling missing `updateTrackingDisplay`.
- Release:
	- Prepared version metadata for `1.2.10`.

## v1.2.9 - 2026-02-21
- Added:
	- Expanded 2.5.5/20505 compatibility helpers and API fallbacks in `Core/Compat.lua`.
- Changed:
	- Reworked Castbar+ runtime/settings wiring: centered spell text + right timer layout, player icon handling, player-only offsets, live cast/channel/non-interruptible colors, and custom fade timing.
	- Updated module/settings compatibility paths for current client behavior across castbar, nameplates, minimap, tooltip, mailbox, and auto-gossip flows.
	- Updated `.pkgmeta` packaging ignores to exclude local Lua tooling artifacts (`luacheck-0.21.0-1`, `check_luacheck.lua`, `check_busted.lua`).
- Fixed:
	- Aura cooldown spiral now renders bright-to-dark.
	- Castbar now reliably hides after cast/channel completion.
- Release:
	- Prepared version metadata for `1.2.9`.

## v1.2.8 - 2026-02-20
- Added:
	- Draggable "Exit mover mode" popup shown during mover mode.
- Changed:
	- Mover mode now auto-closes config, enables mover-related preview helpers, unlocks SwingTimer while moving, and restores prior preview/lock state on exit.
	- Minimap header layout updated: zone text is top-centered, clock moved to minimap bottom-center (+6 inset), and calendar button is hidden/disabled while MinimapPlus is enabled.
	- Minimap zone text and clock anchors are now enforced to resist external re-anchoring.
	- Default mover grid size changed from `8` to `50`.
	- Default minimap mask apply (`square_mask`) is now enabled.
	- Castbar preview now refreshes immediately on settings apply.
- Fixed:
	- Timer scheduling now prefers shared AceTimer wrappers with safe fallback behavior.
	- Vendor throttled sell queue now safely falls back when repeating ticker backends are unavailable.
- Release:
	- Prepared version metadata for `1.2.8`.

## v1.2.7 - 2026-02-20
- Fixed:
	- Hardened nameplate safety around restricted frames and combat-lockdown updates to reduce `FrameMeasurement` taint errors.
	- Added safe `UnitIsUnit` guards in nameplate paths to prevent invalid unit usage during soft-target/nameplate transitions.
	- Blocked Blizzard nameplate option refresh and forced friendly-nameplate CVars off while Plater is active.
	- Restored and synchronized castbar texture preview + LSM texture wiring in both main and test paths.
	- Fixed tooltip subtle-skin color application for background, border, and top glow on NineSlice-based tooltips.
	- Fixed config window TreeGroup/SimpleGroup resize behavior by binding tree width/height updates to live window size.
	- Ported Blizzard aura frame suppression behavior into main Auras module and kept test/main parity.
- Changed:
	- Reconciled test/main mirror drift and kept newer issue-fix variants during selective sync.
	- Updated addon version metadata for release preparation (`1.2.7`).

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

## Unreleased (pre-v1.2.3) - 2026-02-18
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

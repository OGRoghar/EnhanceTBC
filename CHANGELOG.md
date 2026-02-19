# Changelog

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

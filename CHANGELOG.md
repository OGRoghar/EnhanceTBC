# Changelog

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

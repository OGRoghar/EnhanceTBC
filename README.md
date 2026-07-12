# EnhanceTBC

A quality-of-life addon suite for World of Warcraft: The Burning Crusade Anniversary Edition (TBC 2026, Ver 2.5.6, interface 20506).

EnhanceTBC focuses on modernizing core UI behaviors without changing gameplay. It improves visibility, consistency, and usability across the default Blizzard interface while keeping the look and feel of TBC.

## Features

Built with Ace3, EnhanceTBC includes:

- Nameplates: enemy/friendly sizing, health text modes, missing-health styling, execute coloring, castbars, tracked debuffs, absorbs, stance indicators, and target/reaction colors.
- Castbars and swing timers: configurable layout, fonts, textures, latency display, channel ticks, colors, and previews.
- Unit frames and action bars: text presentation, sizing, hotkeys, range tinting, and combat/out-of-combat behavior.
- Auras, cooldowns, combat text, and action tracker: configurable visual timers and event-driven combat information.
- Tooltip enhancements: unit/item/spell IDs, health, guild/target information, vendor values, stat summaries, anchors, and skinning.
- ChatIM: left-aligned timestamps, clickable web/email links, shortened channel labels, whisper alerts, and copyable chat history.
- MinimapPlus: square mask, performance/friends/guild widgets, tracking controls, and optional addon-button collection.
- Automation: safe vendor repair/junk selling, mailbox collection, AutoGossip rules, and faster auto-loot controls.
- Objectives, friends list, visibility rules, sound controls, and a unified mover system.

The `/etbc` window provides search, live previews, per-module reset controls, status indicators, setup presets, and profile import/export/share tools.

## Setup Presets

On first use, EnhanceTBC offers an optional starting layout. Presets can also be applied later under **General -> Setup Presets**:

- Enhanced default
- Classic
- Compact
- High visibility
- Performance focused
- Red/green colorblind-friendly
- Blue/yellow colorblind-friendly

Applying a preset does not lock the profile; every setting remains editable.
The profile from immediately before the latest preset is retained until another preset is applied, allowing **Undo Last Preset**.

## Compatibility

- Client: The Burning Crusade Anniversary 2.5.6
- Interface: `20506`
- API reference used for development: Anniversary build `68575`
- Imported profiles from interface `20505` remain accepted for migration.
- Plater is detected and EnhanceTBC nameplate styling yields to it.

## Installation

1. Download the addon from GitHub (Code -> Download ZIP) or your preferred release archive.
2. Extract the folder to your WoW AddOns directory:
	- Windows: `World of Warcraft/_anniversary_/Interface/AddOns/`
	- macOS: `World of Warcraft/_anniversary_/Interface/AddOns/`
3. Ensure the final path is:
	`World of Warcraft/_anniversary_/Interface/AddOns/EnhanceTBC/`
4. Launch the game and enable EnhanceTBC in the AddOns list.

### Updating

Replace the existing `EnhanceTBC` folder with the new version. Settings are stored in SavedVariables and should persist across updates.

## Getting Started

- Open settings: `/etbc` or `/etbc config`
- Toggle mover mode: `/etbc moveall [on|off|toggle]`
- Reset full profile: `/etbc reset`
- Reset one module profile: `/etbc resetmodule <moduleKey>`
- Profile import/export/share:
	- `/etbc profile export`
	- `/etbc profile import <data>`
	- `/etbc profile undoimport`
	- `/etbc profile share <player>`
- Print support diagnostics: `/etbc diagnose`
- Run non-destructive compatibility checks: `/etbc selftest`

Tip: Most changes apply instantly. Some CVars and UI changes may need a `/reload` to fully apply.

Profile imports display the source, client, interface, and affected setting groups before confirmation.
The prior profile is retained as a one-level backup so the most recent import can be undone.

## Safety

- Addon Lua is never executed by the development syntax checker.
- Vendor, mailbox, and gossip automation can be bypassed or disabled and verify the relevant game window before acting.
- Protected frame/layout work is deferred while combat lockdown prevents safe changes.

## Testing

See [TESTING.md](TESTING.md) for information about running tests locally and contributing test coverage.

## License

MIT

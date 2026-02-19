# EnhanceTBC

[![CI](https://github.com/OGRoghar/EnhanceTBC/actions/workflows/ci.yml/badge.svg)](https://github.com/OGRoghar/EnhanceTBC/actions/workflows/ci.yml)

A quality-of-life addon suite for World of Warcraft: The Burning Crusade Anniversary Edition (TBC 2026, Ver 2.5.5, interface 20505).

EnhanceTBC focuses on modernizing core UI behaviors without changing gameplay. It improves visibility, consistency, and usability across the default Blizzard interface while keeping the look and feel of TBC.

## Features

Built with Ace3 framework, EnhanceTBC provides:
- UI enhancements
- Minimap improvements
- Action bars
- Cast bars
- Unit frames
- Various gameplay conveniences

Recent additions include:
- Faster auto-loot support (configurable in CVars)
- Optional DELETE-word confirmation for rare/epic/legendary item deletion
- Per-module settings reset from config UI and slash command

## Installation

1. Download the addon from GitHub (Code -> Download ZIP) or your preferred release archive.
2. Extract the folder to your WoW AddOns directory:
	- Windows: `World of Warcraft/_classic_/Interface/AddOns/`
	- macOS: `World of Warcraft/_classic_/Interface/AddOns/`
3. Ensure the final path is:
	`World of Warcraft/_classic_/Interface/AddOns/EnhanceTBC/`
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
	- `/etbc profile share <player>`

Tip: Most changes apply instantly. Some CVars and UI changes may need a `/reload` to fully apply.

## Testing

See [TESTING.md](TESTING.md) for information about running tests locally and contributing test coverage.

## License

MIT

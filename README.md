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

## Public API

EnhanceTBC exposes a stable Lua integration facade as `_G.EnhanceTBC_API`.
API v1 uses namespace-style dot calls and does not expose live database or
internal registry tables.

```lua
local API = _G.EnhanceTBC_API
if API and API.GetAPIVersion() >= 1 then
  local integration = {}

  API.RegisterCallback(integration, "READY", function(_, apiVersion, addonVersion)
    print("EnhanceTBC API", apiVersion, "addon", addonVersion)
  end)

  API.RegisterCallback(integration, "MODULE_STATE_CHANGED", function(_, key, enabled)
    print(key, enabled and "enabled" or "disabled")
  end)

  local ok, err = API.SetModuleEnabled("nameplates", true)
  if not ok then print(err) end
end
```

API v1 methods:

- `GetAPIVersion()`, `GetAddonVersion()`, and `IsReady()`
- `GetModuleKeys()` and `GetModuleState(key)`
- `SetModuleEnabled(key, enabled)` and `RequestRefresh(key)`
- `RegisterMover(key, frame, options)` and `UnregisterMover(key)`
- `BindVisibility(key, frame, ruleProvider, onChange)` and `UnbindVisibility(key)`
- `GetDiagnostics()` and `GetPerformanceSnapshot()`
- `RegisterCallback(owner, event, handler)`, `UnregisterCallback(owner, event)`,
  and `UnregisterAllCallbacks(owner)`

Callback events are `READY`, `MODULE_STATE_CHANGED`, `PROFILE_CHANGED`, and
`SETTINGS_APPLIED`. Mutating methods return `true` on success or
`false, reason` on rejection. Returned tables are copies and may be modified by
the consumer. API v1 signatures remain compatible until a future major API
version.

## Safety

- Addon Lua is never executed by the development syntax checker.
- Vendor, mailbox, and gossip automation can be bypassed or disabled and verify the relevant game window before acting.
- Protected frame/layout work is deferred while combat lockdown prevents safe changes.

## Testing

See [TESTING.md](TESTING.md) for information about running tests locally and contributing test coverage.

# Modern Control Center

`/etbc` opens a purpose-built configuration workspace with an adaptive sidebar, global setting search, status dashboard, progressive module sections, favorites, recent changes, accessibility controls, and live per-change undo. Existing profiles and SettingsRegistry definitions remain compatible.

# Optional Next-Generation Suite

EnhanceTBC ships three opt-in, load-on-demand companion addons. **HUD Studio** provides custom player/target frames and safe no-code trackers, **Inventory Intelligence** exposes equipment and durability audits, and **Combat Suite** records bounded local damage, healing, interrupt, dispel, and death segments. Existing modules remain active unless you choose otherwise.

Use `/etbc suite` to start setup and `/etbc edit` to arrange registered frames. The companions share the core profile and never require separate SavedVariables.

## Public API additions

The stable `EnhanceTBC_API` v1 facade now also provides `GetFeatureState`, `SetFeatureEnabled`, `OpenConfiguration`, `EnterEditMode`, `GetEquipmentAudit`, `GetCombatSnapshot`, `RegisterDataProvider`, and `UnregisterDataProvider`. New callbacks are `FEATURE_STATE_CHANGED`, `EDIT_MODE_CHANGED`, `EQUIPMENT_AUDIT_UPDATED`, `COMBAT_SEGMENT_STARTED`, and `COMBAT_SEGMENT_ENDED`.

```lua
local api = EnhanceTBC_API
if api and api.IsReady() then
  api.SetFeatureEnabled("hud", true)
  api.RegisterDataProvider(MyAddon, "myaddon.ready", {
    GetValue = function(_, context)
      return context.unit == "player" and true or false
    end,
  })
end
```

## License

MIT

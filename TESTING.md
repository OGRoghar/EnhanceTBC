# EnhanceTBC Testing Guide

This guide covers development checks and in-game smoke testing for TBC Anniversary build 68575 / interface 20506.

## Static Development Checks

Run the self-contained mocked WoW regression suite:

```powershell
pwsh -NoProfile -File .\EnhanceTBC\test\run.ps1
pwsh -NoProfile -File .\EnhanceTBC\test\check-tbc-api.ps1
pwsh -NoProfile -File .\EnhanceTBC\test\check-manifest.ps1 -SelfTest
pwsh -NoProfile -File .\EnhanceTBC\test\check-string-contracts.ps1 -SelfTest
```

The suite loads first-party Lua files in TOC order under Lua 5.1 and exercises
high-risk compatibility, profile, UI-state, and delayed-automation paths.

From `C:\EnhanceTBC` in PowerShell 7:

```powershell
pwsh -NoProfile -File .\Documents\Test-Lua51.ps1 `
  -Path .\EnhanceTBC -Exclude 'Libs/**'

pwsh -NoProfile -File .\Documents\Test-TbcAnniversaryApi.ps1 `
  -Path .\EnhanceTBC -Exclude 'Libs/**' -ExpectedBuild 68575

pwsh -NoProfile -File .\Documents\Test-AddonPackage.ps1 `
  -Path .\EnhanceTBC -ExpectedInterface 20506
```

Expected result: exit code `0` from all scripts, with zero Lua/API findings and a passing package preflight.

## Clean Installation

1. Exit the game completely.
2. Copy the packaged `EnhanceTBC` folder into `_anniversary_/Interface/AddOns/`.
3. Confirm `EnhanceTBC.toc` is directly inside that folder.
4. Enable the addon at character selection.
5. Log in with Lua errors enabled: `/console scriptErrors 1`.
6. Run `/etbc selftest`; all checks should pass.
7. Run `/etbc diagnose` and include the output with bug reports.

## First-Run and Configuration

- Verify the first-run prompt appears once for a new profile.
- Test Enhanced, Classic, and Configure Later actions.
- Apply each preset from General and verify the confirmation prompt.
- Use Undo Last Preset and confirm the previous profile returns.
- Resize, move, scale, close, and reopen `/etbc`.
- Test search highlighting, Favorites, Recently Changed, Expand All, Collapse All, module reset, and option reset.
- Confirm preview cards render for nameplates, unit frames, tooltips, action bars, chat, castbars, cooldowns, swing timers, combat text, action tracker, and auras.

## Profile Safety

- Export a profile and import it locally.
- Confirm the preview shows client, interface, source, and changed groups.
- Cancel once and verify nothing changes.
- Confirm once, then use `/etbc profile undoimport`.
- Import a known interface-20505 profile and confirm migration.
- Confirm malformed and unsupported interface metadata is rejected.
- Share a profile to another consenting test character and repeat the preview/undo flow.

## Nameplates

- Test enemy and friendly plates in the open world, a dungeon, a battleground, and combat.
- Verify missing-health background, border color/thickness, font sizes, text modes, and text colors.
- Cross into and out of execute range and verify coloring updates immediately.
- Verify the targeting-you color updates when an enemy changes target.
- Test castbars, interrupts, tracked debuffs, absorbs, stance icons, target highlighting, and nameplate removal/reuse.
- Disable and re-enable the module in and out of combat.
- With Plater enabled, confirm EnhanceTBC yields nameplate control.

## Chat and Tooltips

- Verify timestamps appear at the far left in each selected format and color.
- Test Automatic, Left, and Right copy-button placement at both screen edges.
- Verify URL/email links and the chat-copy window.
- Toggle the ChatIM and master switches and confirm the prior timestamp CVar is restored.
- Test item, spell, unit, aura, quest, and linked-item tooltips.
- Toggle Tooltip and the master switch; confirm scale/accent/health text restore cleanly.

## Combat UI

- Test player, target, and focus castbars, including channels and non-interruptible casts.
- Test action-bar layout, pet bar, stance bar, range tint, hotkeys, and combat fading.
- Test unit-frame health/power text and party frames.
- Test cooldown text, swing timers, combat text, action tracker, and aura sorting/filtering.
- Enter combat before changing protected layout options and verify deferred changes apply after combat.

## Automation Safety

Use low-value test data and empty bags/mail where possible.

- Vendor: test repair, junk selling, value threshold, Shift bypass, throttling, and merchant close.
- Mailbox: test money/items, COD/GM/AH exclusions, delete confirmation, Shift bypass, and mailbox close.
- AutoGossip: test immediate and delayed selection, closing early, switching NPCs, Shift bypass, and disabling during a delay.
- UI deletion confirmation: test rare/epic item deletion and cancel paths.

## Minimap, Objectives, Friends, and Visibility

- Test square/round minimap behavior, tracking controls, performance widgets, friends/guild counts, and addon-button collection.
- Test objective layout and combat fade/hide transitions.
- Open/close the Friends window and verify no background retry loop or stale decoration.
- Assign visibility presets and test solo, party, raid, dungeon, battleground, combat, and out-of-combat states.

## Reporting a Regression

Include:

- `/etbc diagnose` output
- `/etbc selftest` result
- Exact reproduction steps
- Screenshot or video
- Other enabled addons, especially UI/nameplate addons
- Whether the problem persists with only EnhanceTBC enabled
- Relevant Lua error text from BugSack/BugGrabber or the Blizzard error dialog

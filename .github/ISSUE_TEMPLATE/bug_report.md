---
name: Bug report
about: Report a reproducible issue in EnhanceTBC (WoW TBC Anniversary)
title: "[BUG]"
labels: bug
assignees: OGRoghar

---

## Summary

Describe the bug clearly and briefly.

## What Broke?

- Affected module(s): (e.g. `MinimapPlus`, `Castbar`, `Vendor`, `Mailbox`, `UI`, `Visibility`)
- Feature/setting involved:
- When it started: (after update / always / after changing settings / unknown)
- Reproducible: `Always` / `Sometimes` / `Rarely`

## Steps To Reproduce

1. 
2. 
3. 
4. 

## Expected Behavior

What should have happened?

## Actual Behavior

What happened instead?

## Error Output (Required if UI/Lua error occurred)

Paste the full error text from BugSack / Swatter / chat frame if available.

```text
-- paste error here
```

## Screenshots / Video (Optional)

Add screenshots or short clips if they help show the issue (especially UI layout, minimap, movers, castbars, nameplates, etc.).

## Environment

- Addon version: (e.g. `1.2.10`)
- WoW client: `TBC Anniversary`
- Interface version: `20505`
- Locale: (e.g. `enUS`, `deDE`)
- Character class/spec:
- In combat when bug happens?: `Yes` / `No`
- In instance/raid/bg?: `Yes` / `No` (which?)

## Configuration Context

- `/etbc` config changed recently? `Yes` / `No`
- Related slash command used? (if any)
  - Examples: `/etbc`, `/etbc moveall`, `/etbc reset`, `/etbc resetmodule <moduleKey>`, `/etbc profile ...`
- Does `/reload` temporarily fix it? `Yes` / `No`
- Does disabling only the affected module fix it? `Yes` / `No` / `Not tested`

## Addon Conflict Check

- Reproduces with only `EnhanceTBC` enabled: `Yes` / `No` / `Not tested`
- If `No`, list likely conflicting addon(s):

## Anything Else?

Add any extra context that may help reproduce or diagnose the issue:
- exact NPC/frame/window involved
- timing (login, zoning, combat start, vendor open, mailbox open, reload)
- profile import/share usage
- localization text issues (`deDE`, etc.)

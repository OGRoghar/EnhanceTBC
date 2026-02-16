# EnhanceTBC vs EnhancedQoL - Feature Comparison Matrix

Quick reference comparing features between EnhanceTBC (TBC) and EnhancedQoL (Retail).

## Legend
- ✅ **Implemented** - Feature exists and works
- 🟢 **Compatible** - Can be ported to TBC with minimal changes
- 🟡 **Partial** - Can be ported but with limitations
- ❌ **Incompatible** - Relies on Retail-only APIs/systems

---

## Feature Comparison Table

| Feature Category | Feature | EnhanceTBC | EnhancedQoL | Porting Status | Priority |
|-----------------|---------|-----------|-------------|----------------|----------|
| **Chat & Social** | | | | | |
| | Chat fading | ❌ | ✅ | 🟢 Easy | Medium |
| | Instant Messenger | ✅ | ✅ | ✅ Done | - |
| | Custom whisper sounds | ✅ | ✅ | ✅ Done | - |
| | Raider.IO context links | ❌ | ✅ | ❌ No TBC API | - |
| | WarcraftLogs links | ❌ | ✅ | ❌ No TBC API | - |
| **Bags & Inventory** | | | | | |
| | Item level on bags | ❌ | ✅ | 🟢 Easy | High |
| | Item count tooltips | ❌ | ✅ | 🟢 Easy | High |
| | Bind type labels (BoE) | ❌ | ✅ | 🟢 Easy | Medium |
| | Bag filter window | ❌ | ✅ | 🟡 Complex | Low |
| | Gold tracker (cross-char) | ❌ | ✅ | 🟡 Limited | Medium |
| | Bag bar hide/show | ❌ | ✅ | 🟢 Easy | Low |
| **Character & Inspect** | | | | | |
| | Item level on char frame | ❌ | ✅ | 🟢 Easy | Medium |
| | Gem socket helper | ❌ | ✅ | ❌ Different system | - |
| | Catalyst charges | ❌ | ✅ | ❌ Retail only | - |
| | Enchant display | ❌ | ✅ | 🟢 Easy | Medium |
| | Durability display | ❌ | ✅ | 🟢 Easy | Low |
| **Action Bars** | | | | | |
| | Mouseover bars | ❌ | ✅ | 🟢 Easy | Medium |
| | Range coloring (full button) | ❌ | ✅ | 🟢 Easy | High |
| | Fade in/out combat | ✅ | ✅ | ✅ Done | - |
| | Shortened keybinds | ❌ | ✅ | 🟢 Easy | High |
| | Custom button labels | ❌ | ✅ | 🟢 Easy | Medium |
| **Mouse & Cursor** | | | | | |
| | Cursor ring | ✅ | ✅ | ✅ Done | - |
| | Cursor trail | ✅ | ✅ | ✅ Done | - |
| **Unit Frames** | | | | | |
| | Custom player frame | ✅ | ✅ | ✅ Done | - |
| | Custom target frame | ✅ | ✅ | ✅ Done | - |
| | Mouseover hide frames | ❌ | ✅ | 🟢 Easy | Low |
| | Truncate unit names | ❌ | ✅ | 🟢 Easy | Medium |
| | Hide floating combat text | ❌ | ✅ | 🟢 Easy | Low |
| **Minimap** | | | | | |
| | Button sink/collector | ✅ | ✅ | ✅ Done | - |
| | Quick spec/loot switch | ✅ | ✅ | ✅ Done | - |
| | Square minimap | ✅ | ✅ | ✅ Done | - |
| | Instance difficulty icon | ❌ | ✅ | 🟢 Easy | Low |
| | Landing page buttons | ✅ | ✅ | ✅ Done | - |
| **Tooltip** | | | | | |
| | Custom background/border | ✅ | ✅ | ✅ Done | - |
| | Show Item ID | ❌ | ✅ | 🟢 Easy | High |
| | Show Spell ID | ❌ | ✅ | 🟢 Easy | High |
| | Show NPC ID | ❌ | ✅ | 🟢 Easy | High |
| | Show Quest ID | ❌ | ✅ | 🟢 Easy | High |
| | Item count | ❌ | ✅ | 🟢 Easy | High |
| | Class colors | ❌ | ✅ | 🟢 Easy | Medium |
| | Mythic Score | ❌ | ✅ | ❌ Retail only | - |
| | Context hiding (combat/dungeon) | ❌ | ✅ | 🟢 Easy | Low |
| **Automation** | | | | | |
| | Auto-accept quests | ❌ | ✅ | 🟢 Easy | High |
| | Auto-turn-in quests | ❌ | ✅ | 🟢 Easy | High |
| | Auto-repair | ✅ | ✅ | ✅ Done | - |
| | Auto-sell junk | ✅ | ✅ | ✅ Done | - |
| | Auto-gossip selection | ❌ | ✅ | 🟢 Easy | High |
| | Smart vendor filters | ❌ | ✅ | 🟢 Easy | High |
| | Quick loot | ❌ | ✅ | 🟢 Easy | Medium |
| | DELETE confirmation | ❌ | ✅ | 🟡 Limited | Low |
| | Auto-loot mail | ✅ | ✅ | ✅ Done | - |
| **Group & Party** | | | | | |
| | Auto-accept invites | ❌ | ✅ | 🟢 Easy | Medium |
| | Block duel requests | ❌ | ✅ | 🟢 Easy | Medium |
| | Leader icon on frames | ❌ | ✅ | 🟢 Easy | Low |
| | Show party frames solo | ❌ | ✅ | 🟢 Easy | Low |
| | Auto-mark tank/healer | ❌ | ✅ | 🟢 Easy | Low |
| **Map & Navigation** | | | | | |
| | `/way` command | ❌ | ✅ | 🟢 Easy | Medium |
| **Dungeon/Mythic+** | | | | | |
| | Keystone helper | ❌ | ✅ | ❌ No M+ in TBC | - |
| | Potion tracker | ❌ | ✅ | ❌ Less relevant | - |
| | Combat rez tracker | ❌ | ✅ | ❌ Less relevant | - |
| | Talent reminder | ❌ | ✅ | ❌ Different system | - |
| | Teleport compendium | ❌ | ✅ | ❌ Retail only | - |
| **Buffs/Debuffs** | | | | | |
| | Separated frames | ✅ | ✅ | ✅ Done | - |
| | Debuff type coloring | ✅ | ✅ | ✅ Done | - |
| **Cooldowns** | | | | | |
| | Cooldown text (OmniCC) | ✅ | ❌ | ✅ Done | - |
| **Combat & Feedback** | | | | | |
| | Combat text | ✅ | ✅ | ✅ Done | - |
| | GCD bar | ✅ | ❌ | ✅ Done | - |
| | Action tracker | ✅ | ❌ | ✅ Done | - |
| | Combat meter | ❌ | ✅ | ❌ Use Recount | - |
| **Cast Bars** | | | | | |
| | Enhanced castbar | ✅ | ✅ | ✅ Done | - |
| | Latency overlay | ✅ | ✅ | ✅ Done | - |
| **Sound** | | | | | |
| | Volume controls | ✅ | ✅ | ✅ Done | - |
| | Auto-mute in combat | ✅ | ❌ | ✅ Done | - |
| **CVars** | | | | | |
| | CVar management | ✅ | ✅ | ✅ Done | - |
| **Friends List** | | | | | |
| | Class colors | ✅ | ✅ | ✅ Done | - |
| | Level colors | ✅ | ✅ | ✅ Done | - |
| | Location/realm display | ✅ | ✅ | ✅ Done | - |
| **Objectives** | | | | | |
| | Quest tracker tweaks | ✅ | ✅ | ✅ Done | - |
| | Auto-collapse completed | ✅ | ❌ | ✅ Done | - |

---

## Summary Statistics

### Already Implemented
**22 features** are already present in EnhanceTBC, covering core QoL improvements like:
- Instant Messenger, cursor customization, minimap enhancements
- Unit frames, cast bars, action bars, auras
- Auto-repair/sell, mail automation
- Friends list decoration, tooltip styling
- Quest tracker, GCD bar, combat text, cooldown text

### High Priority Additions (🟢 Easy to Port)
**15+ features** can be easily ported with high value:
1. Tooltip IDs (Item, Spell, NPC, Quest) - Essential for power users
2. Item count on tooltips - Immediate QoL
3. Auto-accept/turn-in quests - Major time saver
4. Auto-gossip selection - Reduces repetitive clicks
5. Range coloring (full button) - Better visibility
6. Shortened keybinds - Cleaner UI
7. Item level on bags - Quick upgrade identification
8. Smart vendor filters - More control over auto-sell
9. Auto-accept group invites - Faster grouping
10. Block duel requests - Less annoyance
11. Chat fading - Customizable chat visibility
12. Unit name truncation - Better readability
13. `/way` command - Basic waypoint support
14. Mouseover action bars - Space-saving option
15. Custom button labels - UI customization

### Medium Priority (🟡 Partial/Complex)
**5-10 features** require more work or have limitations:
- Gold tracker (manual tracking only, no account-wide)
- Bag filter window (complex UI rebuild)
- DELETE confirmation helper (limited TBC API)
- Item level on character frame (moderate complexity)

### Incompatible (❌)
**10+ features** rely on Retail-only systems:
- Mythic+ tools, Raider.IO/WarcraftLogs integration
- Catalyst charges, Warband features
- Teleport compendium, gem socket helper
- Combat rez/potion trackers (M+ specific)

---

## Recommended Next Steps

### Phase 1: Quick Wins (Implement First)
Focus on these **5 high-impact, low-effort** features:

1. **Tooltip IDs** - Item/Spell/NPC/Quest IDs on tooltips
2. **Item Count Tooltips** - "You have: X" on item tooltips
3. **Auto-Gossip** - Auto-select NPC dialog options
4. **Range Coloring** - Full action button tint when out of range
5. **Shortened Keybinds** - Display compact keybind text

**Estimated Time:** 1-2 weeks  
**Lines of Code:** ~800-1000 total  
**User Impact:** High - immediately noticeable QoL improvements

### Phase 2: Core Automation (Implement Second)
Add these **5 valuable automation** features:

1. **Quest Auto-Accept/Turn-in** - With configurable filters
2. **Smart Vendor Filters** - ilvl thresholds, BoE exclusion
3. **Auto-Accept Invites** - From friends/guildmates
4. **Block Duel Requests** - Auto-decline duels
5. **Chat Fade Delay** - Configurable chat visibility time

**Estimated Time:** 2-4 weeks  
**Lines of Code:** ~1200-1500 total  
**User Impact:** High - major time savings for daily gameplay

### Phase 3: Visual Polish (Implement Third)
Add these **visual enhancements**:

1. **Item Level on Bags** - Show ilvl on bag slot icons
2. **Unit Name Truncation** - Shorten long names
3. **Mouseover Action Bars** - Show/hide on hover
4. **Custom Button Labels** - Font/size/outline options
5. **Simple `/way` Command** - Basic waypoint functionality

**Estimated Time:** 2-4 weeks  
**Lines of Code:** ~1000-1200 total  
**User Impact:** Medium - nice-to-have polish features

---

## Development Notes

### Code Patterns
- **Settings/Module Pairing:** Every feature gets `Settings_<Module>.lua` + `Modules/<Module>.lua`
- **ApplyBus:** All settings trigger `ApplyBus:Notify("modulename")` for live updates
- **GetDB() Pattern:** Module-level DB access with inline defaults
- **Event-Driven:** Prefer events over OnUpdate for performance
- **Defensive Coding:** Always check for nil, validate types, use `not not` for boolean conversion

### Testing Checklist
- [ ] Feature works with existing modules enabled
- [ ] Settings persist across sessions
- [ ] ApplyBus triggers live config updates
- [ ] No errors in `/console scriptErrors 1` mode
- [ ] Compatible with popular TBC addons (Questie, AtlasLoot, etc.)
- [ ] Performance impact is minimal (no continuous OnUpdate)

### Documentation
- [ ] Update README.md with new features
- [ ] Add tooltips to all settings options
- [ ] Document slash commands
- [ ] Include example usage in option descriptions
- [ ] Update CHANGELOG.md

---

## Questions?

See `FEATURE_RECOMMENDATIONS.md` for detailed implementation guides and API references.

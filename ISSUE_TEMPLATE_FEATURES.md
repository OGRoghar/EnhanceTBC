# Feature Request Template: Port from EnhancedQoL

Use this template to track individual feature implementations from EnhancedQoL.

---

## Feature: [Feature Name]

**From:** EnhancedQoL (Retail)  
**Priority:** [Tier 1 / Tier 2 / Tier 3]  
**Difficulty:** [⭐ Easy / ⭐⭐ Moderate / ⭐⭐⭐ Complex]  
**Estimated Time:** [X days]

---

### Description

[Brief description of what the feature does]

**User Benefit:**  
[Why this feature is valuable for TBC players]

**Example Use Case:**  
[Specific scenario where this helps]

---

### Implementation Plan

#### Module Structure
- [ ] Create `Settings_<ModuleName>.lua`
- [ ] Create `Modules/<ModuleName>.lua`
- [ ] Add entries to `EnhanceTBC.toc`

#### Settings Options
- [ ] Enable/disable toggle
- [ ] [List other settings]

#### Core Functionality
- [ ] Hook WoW events: [List events]
- [ ] Implement core logic
- [ ] Add ApplyBus listener
- [ ] Implement `GetDB()` with defaults

#### Testing
- [ ] Test enable/disable
- [ ] Test settings persistence
- [ ] Test ApplyBus live updates
- [ ] Test with other modules
- [ ] Check for script errors
- [ ] Test with popular addons: [List addons]

#### Documentation
- [ ] Add tooltips to settings
- [ ] Update README.md if needed
- [ ] Document slash commands (if any)

---

### TBC API Compatibility

**WoW API Calls:**
- [List TBC API functions needed]

**Known Limitations:**
- [Any TBC-specific limitations or workarounds]

**Tested On:**
- [ ] TBC Anniversary (Ver 2.5.5, Interface 20505)

---

### Code References

**EnhancedQoL (Retail) Implementation:**
- File: [Link to GitHub file if public]
- Key functions: [List relevant functions]

**Similar EnhanceTBC Modules:**
- [Module name] - [Why it's similar]

---

### Dependencies

**Required:**
- [List any required libraries or modules]

**Optional:**
- [List optional dependencies]

**Conflicts:**
- [Known addon conflicts to test against]

---

### Performance Considerations

- [ ] Avoid continuous OnUpdate if possible
- [ ] Use event-driven architecture
- [ ] Implement frame pooling if needed
- [ ] Profile memory/CPU impact

**Expected Performance:**
- Memory: [Estimated MB]
- CPU: [Minimal / Low / Moderate]

---

### Open Questions

1. [Question 1]
2. [Question 2]

---

### Progress Updates

**[Date]:**  
- [Progress note]

**[Date]:**  
- [Progress note]

---

### Related Issues

- #[Issue number] - [Related feature]
- #[Issue number] - [Dependency]

---

### Screenshots/Examples

[Add screenshots when implemented]

---

## Example Issues

Below are pre-filled examples for the top 5 features:

---

## Example 1: Tooltip ID Display

**From:** EnhancedQoL (Retail)  
**Priority:** Tier 1  
**Difficulty:** ⭐ Easy  
**Estimated Time:** 1-2 days

### Description

Display ItemID, SpellID, QuestID, and NPC ID on tooltips.

**User Benefit:**  
Essential for addon developers, power users, and troubleshooting. Helps identify items/spells for macros, WeakAuras, and addon configuration.

**Example Use Case:**  
Player wants to create a WeakAura to track "Battle Shout" buff. With Tooltip IDs enabled, they hover over the spell and see "Spell ID: 25289" immediately.

### Implementation Plan

#### Module Structure
- [ ] Extend existing `Modules/Tooltip.lua`
- [ ] Extend existing `Settings/Settings_Tooltip.lua`
- [ ] No TOC changes needed

#### Settings Options
- [ ] Show Item ID
- [ ] Show Spell ID
- [ ] Show NPC ID
- [ ] Show Quest ID
- [ ] ID text color picker

#### Core Functionality
- [ ] Hook `GameTooltip:OnTooltipSetItem()` for items
- [ ] Hook `GameTooltip:OnTooltipSetSpell()` for spells
- [ ] Hook `GameTooltip:OnTooltipSetUnit()` for NPCs
- [ ] Parse tooltip data to extract IDs
- [ ] Add colored ID text lines

#### Testing
- [ ] Test item tooltips (bags, character frame, loot)
- [ ] Test spell tooltips (spellbook, action bars)
- [ ] Test unit tooltips (nameplates, target frame)
- [ ] Test quest tooltips (quest log)
- [ ] Verify no conflicts with other tooltip addons

### TBC API Compatibility

**WoW API Calls:**
- `GameTooltip:GetItem()` - Returns itemName, itemLink
- `GameTooltip:GetSpell()` - Returns spellName, spellRank, spellID
- `GameTooltip:GetUnit()` - Returns unitName, unitID
- String parsing for ID extraction from links

**Known Limitations:**
- Quest IDs may require hyperlink parsing ("|Hquest:ID|h")

---

## Example 2: Item Count on Tooltips

**From:** EnhancedQoL (Retail)  
**Priority:** Tier 1  
**Difficulty:** ⭐ Easy  
**Estimated Time:** 1 day

### Description

Show "You have: X" on item tooltips with total count across bags/bank.

**User Benefit:**  
Eliminates need to search inventory. Perfect for crafting, farming, and managing materials.

**Example Use Case:**  
Player loots "Netherweave Cloth" and tooltip shows "You have: 47 (Bags: 32, Bank: 15)" - instantly knows they're close to stack cap.

### Implementation Plan

#### Module Structure
- [ ] Extend existing `Modules/Tooltip.lua`
- [ ] Extend existing `Settings/Settings_Tooltip.lua`

#### Settings Options
- [ ] Enable item count display
- [ ] Split by location (bags/bank)
- [ ] Color code by quantity (green if >100, yellow if 20-100, red if <20)

#### Core Functionality
- [ ] Hook `GameTooltip:OnTooltipSetItem()`
- [ ] Extract itemID from tooltip
- [ ] Call `GetItemCount(itemID, true)` for total
- [ ] Call `GetItemCount(itemID, false)` for bags only
- [ ] Calculate bank count (total - bags)
- [ ] Add tooltip line with count

#### Testing
- [ ] Test with stackable items
- [ ] Test with non-stackable items
- [ ] Test with items in bags only
- [ ] Test with items in bank only
- [ ] Test with items in both locations

### TBC API Compatibility

**WoW API Calls:**
- `GetItemCount(itemID, includeBank)` - TBC compatible

---

## Example 3: Auto-Gossip Selection

**From:** EnhancedQoL (Retail)  
**Priority:** Tier 1  
**Difficulty:** ⭐⭐ Moderate  
**Estimated Time:** 2-3 days

### Description

Automatically select specific NPC dialog options to speed up interactions.

**User Benefit:**  
Major time-saver for repetitive interactions (vendors, trainers, flight masters).

**Example Use Case:**  
Player talks to flight master and dialog auto-selects "I want to fly" - no extra click needed.

### Implementation Plan

#### Module Structure
- [ ] Create `Settings/Settings_AutoGossip.lua`
- [ ] Create `Modules/AutoGossip.lua`
- [ ] Add to `EnhanceTBC.toc`

#### Settings Options
- [ ] Enable/disable auto-gossip
- [ ] Gossip ID list (add/remove)
- [ ] Delay before auto-select (0-2 seconds)

#### Core Functionality
- [ ] Hook `GOSSIP_SHOW` event
- [ ] Get available gossip options
- [ ] Match against saved ID list
- [ ] Auto-select with `SelectGossipOption(index)`
- [ ] Slash commands: `/etbc lag`, `/etbc aag <id>`, `/etbc rag <id>`

#### Testing
- [ ] Test with flight masters
- [ ] Test with vendors
- [ ] Test with trainers
- [ ] Test with quest NPCs
- [ ] Test delay timing
- [ ] Verify no conflicts with Questie

### TBC API Compatibility

**WoW API Calls:**
- `GetGossipOptions()` - Returns gossip text/IDs
- `SelectGossipOption(index)` - Selects option
- `GOSSIP_SHOW` event - Fires on dialog open

---

## Example 4: Quest Auto-Accept/Turn-In

**From:** EnhancedQoL (Retail)  
**Priority:** Tier 1  
**Difficulty:** ⭐⭐⭐ Moderate-High  
**Estimated Time:** 3-5 days

### Description

Automatically accept and complete quests with configurable filters.

**User Benefit:**  
Massive time-saver for daily quests, farming routes, and leveling. Reduces hundreds of clicks per day.

**Example Use Case:**  
Player farming Shattered Sun dailies - all quests auto-accept and auto-turn-in, cutting quest time by 30%.

### Implementation Plan

#### Module Structure
- [ ] Create `Settings/Settings_QuestAutomation.lua`
- [ ] Create `Modules/QuestAutomation.lua`
- [ ] Add to `EnhanceTBC.toc`

#### Settings Options
- [ ] Enable auto-accept
- [ ] Enable auto-turn-in
- [ ] Don't auto-handle daily quests
- [ ] Don't auto-handle trivial quests
- [ ] Quest ID exclude list

#### Core Functionality
- [ ] Hook events: `QUEST_GREETING`, `QUEST_DETAIL`, `QUEST_PROGRESS`, `QUEST_COMPLETE`
- [ ] Check quest against filters
- [ ] Call `AcceptQuest()`, `CompleteQuest()`, `GetQuestReward()`
- [ ] Handle multiple quest reward choices (default: highest ilvl or vendor value)
- [ ] Implement exclude list database

#### Testing
- [ ] Test quest acceptance
- [ ] Test quest turn-in
- [ ] Test daily quest filter
- [ ] Test trivial quest filter
- [ ] Test exclude list
- [ ] Test with Questie compatibility
- [ ] Test with multiple simultaneous quests

### TBC API Compatibility

**WoW API Calls:**
- `AcceptQuest()` - Auto-accept quest
- `CompleteQuest()` - Complete quest
- `GetQuestReward(index)` - Select reward
- `IsQuestCompletable()` - Check if can turn in
- Events: `QUEST_GREETING`, `QUEST_DETAIL`, `QUEST_PROGRESS`, `QUEST_COMPLETE`

**Known Limitations:**
- Multiple quest rewards require item comparison logic
- Some escort quests may need special handling

---

## Example 5: Full Button Range Coloring

**From:** EnhancedQoL (Retail)  
**Priority:** Tier 1  
**Difficulty:** ⭐⭐ Moderate  
**Estimated Time:** 2-3 days

### Description

Tint entire action button (not just icon) when ability is out of range.

**User Benefit:**  
Much more visible feedback for ability availability. Helps with positioning in PvP and PvE.

**Example Use Case:**  
Melee player can instantly see which abilities are out of range when kiting - entire button glows red.

### Implementation Plan

#### Module Structure
- [ ] Extend `Modules/ActionBars.lua`
- [ ] Extend `Settings/Settings_ActionBars.lua`

#### Settings Options
- [ ] Enable range coloring
- [ ] Tint color picker (default: red)
- [ ] Opacity slider (0-100%)

#### Core Functionality
- [ ] Hook action button update events
- [ ] Check `IsActionInRange(slot)` for each button
- [ ] Create color overlay texture on button frame
- [ ] Update overlay color/opacity from settings
- [ ] Handle button state changes (enabled/disabled)

#### Testing
- [ ] Test with melee abilities
- [ ] Test with ranged abilities
- [ ] Test with spells
- [ ] Test button updates on range change
- [ ] Test with existing ActionBar fade features
- [ ] Verify performance (many buttons updating)

### TBC API Compatibility

**WoW API Calls:**
- `IsActionInRange(slot)` - Returns 1 (in range), 0 (out of range), nil (no range)
- Action button frame methods for overlay

---

**To create a new issue for a feature, copy this template and fill in the details!**

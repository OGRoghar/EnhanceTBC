# EnhancedQoL Features - Porting Recommendations for EnhanceTBC

This document outlines features from EnhancedQoL (Retail) that could be added to EnhanceTBC, organized by implementation complexity and TBC compatibility.

---

## ✅ Currently Implemented in EnhanceTBC

The following EnhancedQoL features are **already present** in EnhanceTBC:

### Chat & Social
- ✅ Instant Messenger window for whispers (`ChatIM` module)
- ✅ Custom whisper sounds (`ChatIM` module)

### Minimap
- ✅ Minimap button collector/sink (`MinimapPlus` module)
- ✅ Quick spec/loot switching (`MinimapPlus` module)
- ✅ Square minimap option (`MinimapPlus` module)

### Action Bars & Mouse
- ✅ Mouse cursor ring and trails (`Mouse` module)
- ✅ Action bar fade in/out of combat (`ActionBars` module)

### Unit Frames
- ✅ Custom player/target/focus frames (`UnitFrames` module)
- ✅ Cast bars with latency display (`Castbar` module)

### Automation
- ✅ Auto-repair (`Vendor` module)
- ✅ Auto-sell junk items (`Vendor` module)
- ✅ Auto-loot mail attachments (`Mailbox` module)

### Buffs/Debuffs
- ✅ Separated buff/debuff frames (`Auras` module)
- ✅ Debuff type coloring (`Auras` module)

### UI Enhancements
- ✅ Cooldown timer text (`Cooldowns` module - OmniCC-like)
- ✅ Quest tracker tweaks (`Objectives` module)
- ✅ GCD indicator bar (`GCDBar` module)
- ✅ Combat text improvements (`CombatText` module)
- ✅ Friends list decoration (`FriendsListDecor` module)
- ✅ Tooltip customization (`Tooltip` module)
- ✅ CVar management (`CVars` module)
- ✅ Sound control (`Sound` module)

---

## 🟢 HIGH PRIORITY - Easy to Implement, High Value

These features are TBC-compatible, relatively simple to implement, and would add significant quality-of-life value.

### 1. **Bags & Inventory Enhancements**

#### Item Level Display on Bags
**What:** Show item level directly on bag slot icons
**Why:** Helps quickly identify upgrades and vendor trash
**Implementation:**
- Hook bag update events
- Scan bag slots for items
- Display ilvl text overlay on item buttons
- Similar pattern to `Cooldowns.lua` text overlay system

#### Item Count on Tooltips
**What:** Show how many of an item you have across bags/bank
**Why:** Reduces inventory searching
**Implementation:**
- Hook `GameTooltip:OnTooltipSetItem()`
- Use `GetItemCount(itemID, true)` for total count
- Add line to tooltip showing "You have: X"

### 2. **Quest Automation**

#### Auto-Accept/Turn-in Quests
**What:** Automatically accept and complete quests (with configurable filters)
**Why:** Reduces repetitive clicking for daily/farming routes
**Implementation:**
- Hook `QUEST_GREETING`, `QUEST_DETAIL`, `QUEST_PROGRESS`, `QUEST_COMPLETE` events
- Check filters (daily, trivial, etc.) in Settings
- Call `AcceptQuest()`, `CompleteQuest()`, `GetQuestReward()` automatically
- Add exclude list for specific quest IDs

**Options:**
- Enable/disable auto-accept
- Enable/disable auto-turn-in
- Don't auto-handle daily quests
- Don't auto-handle trivial quests
- Exclude specific quest IDs (whitelist/blacklist)

### 3. **Tooltip ID Display**

#### Show IDs on Tooltips
**What:** Display ItemID, SpellID, QuestID, NPC ID on tooltips
**Why:** Essential for addon developers and power users
**Implementation:**
- Extend existing `Tooltip` module
- Hook tooltip events: `OnTooltipSetItem`, `OnTooltipSetSpell`, `OnTooltipSetUnit`
- Extract IDs from tooltip data
- Add colored ID lines to tooltip bottom

**IDs to show:**
- Item ID
- Spell ID
- NPC ID (creature GUID parsing)
- Quest ID
- Enchant ID

### 4. **Auto-Gossip (Auto-Dialog Selection)**

#### Auto-Select Gossip Options
**What:** Automatically pick specific NPC dialog options
**Why:** Speeds up repetitive vendor/trainer interactions
**Implementation:**
- Hook `GOSSIP_SHOW` event
- Match gossip text or ID against saved list
- Auto-select with `SelectGossipOption(index)`
- Slash commands: `/etbc lag` (list IDs), `/etbc aag <id>` (add), `/etbc rag <id>` (remove)

### 5. **Enhanced Vendor Options**

#### Smart Item Vendoring
**What:** Vendor items based on quality, ilvl, upgrade potential
**Why:** More control over what gets auto-sold
**Implementation:**
- Extend existing `Vendor` module
- Add filters:
  - Sell by ilvl threshold (e.g., "sell items below ilvl 100")
  - Ignore BoE items (protect valuable greens)
  - Ignore specific item IDs (blacklist)
  
**New Options:**
- Item level threshold slider
- "Ignore Bind on Equip" toggle
- Item blacklist (drag-drop UI or manual ID entry)

---

## 🟡 MEDIUM PRIORITY - Moderate Complexity, Good Value

These features require more work but are still TBC-compatible and valuable.

### 6. **Group & Party Tools**

#### Auto-Accept Invites
**What:** Automatically accept group invites from friends/guildmates
**Why:** Reduces clicking when grouping with known players
**Implementation:**
- Hook `PARTY_INVITE_REQUEST` event
- Check invite sender against friends list (`GetNumFriends()`, `GetFriendInfo()`)
- Check guild roster (`GetGuildRosterInfo()`)
- Auto-accept with `AcceptGroup()` if sender is trusted

**Options:**
- Enable/disable auto-accept
- Accept from friends
- Accept from guildmates
- Whitelist specific character names

#### Block Duel Requests
**What:** Automatically decline duel requests
**Why:** Reduces annoyance in cities/common areas
**Implementation:**
- Hook `DUEL_REQUESTED` event
- Auto-decline with `CancelDuel()`
- Optional: show chat message about blocked duel

### 7. **Map Waypoint Command**

#### Simple `/way` Command
**What:** Provide basic waypoint functionality
**Why:** Useful if no other waypoint addon is installed
**Implementation:**
- Slash command `/etbc way <x> <y>` or `/way <x> <y>`
- Parse coordinates
- Set player waypoint on minimap (TBC supports this via Blizzard API)
- Clear waypoint with `/way clear`

**Note:** Only enable if no other waypoint addon detected (CartographerWaypoints, etc.)

### 8. **Unit Name Truncation**

#### Truncate Long Unit Names
**What:** Shorten excessively long player/NPC names in unit frames
**Why:** Improves readability, especially with addon-heavy servers
**Implementation:**
- Hook unit frame text updates
- Check name length against threshold
- Truncate with ellipsis if too long (e.g., "VeryLongCharacterName" → "VeryLongCh...")

**Options:**
- Enable/disable truncation
- Maximum name length slider (10-30 characters)

### 9. **Action Bar Enhancements**

#### Range Coloring (Full Button Tint)
**What:** Tint entire action button (not just icon) when out of range
**Why:** More visible feedback for ability availability
**Implementation:**
- Extend `ActionBars` module
- Hook action button updates
- Check `IsActionInRange(slot)`
- Apply color overlay to entire button frame

**Options:**
- Enable/disable range coloring
- Custom tint color picker (default: red)
- Opacity slider

#### Shortened Keybind Text
**What:** Display compact keybind abbreviations (e.g., "SM3" for "Shift-MouseButton3")
**Why:** Cleaner action bar appearance
**Implementation:**
- Hook keybind text updates on action buttons
- Replace long strings with abbreviations:
  - "SHIFT-" → "S"
  - "CTRL-" → "C"
  - "ALT-" → "A"
  - "BUTTON" → "M"
- Update button hotkey text

### 10. **Chat Fading**

#### Configurable Chat Fade Delay
**What:** Control how long chat messages stay visible before fading
**Why:** Customizable chat visibility suits different playstyles
**Implementation:**
- Extend `ChatIM` module (or create new Chat module)
- Hook `ChatFrame1:SetTimeVisible(seconds)`
- Add slider in settings (5-60 seconds, or "never fade")

---

## 🟠 LOWER PRIORITY - TBC API Limitations or Complex

These features may require significant work or have limited TBC API support.

### 11. **Delete Confirmation Helper**

#### Add "DELETE" Text to Confirmation
**What:** Pre-fill or show "DELETE" text in item deletion confirmation popup
**Why:** Speeds up inventory management
**TBC Limitation:** Static popup text may not be easily modifiable
**Implementation:**
- Hook `StaticPopup_Show("DELETE_ITEM")`
- Auto-fill editbox with "DELETE" text (if possible)
- Or: show overlay hint

### 12. **Bag Filter Window**

#### Advanced Bag Filtering
**What:** Filter visible bag slots by rarity, slot type, ilvl range
**Why:** Easier to find specific items
**TBC Limitation:** No native bag filtering API; requires complete bag UI rebuild
**Implementation:**
- Create custom bag frame overlay
- Scan all bag slots
- Hide/show slots based on filter criteria
- High complexity; may conflict with other bag addons

### 13. **Money/Gold Tracker**

#### Cross-Character Gold Display
**What:** Show total gold across all characters
**Why:** Useful for economy tracking
**TBC Limitation:** No cross-character data sharing (no account-wide variables)
**Implementation:**
- Requires SavedVariablesPerCharacter
- Store gold per character in global saved variable
- Display total in tooltip (e.g., on minimap button)
- Manual tracking only; no automatic Warband gold (Retail feature)

---

## ❌ NOT COMPATIBLE with TBC

These features rely on Retail-specific APIs or systems that don't exist in TBC.

- **Mythic+ Tools** - No M+ in TBC
- **Keystone Helper** - No keystones in TBC
- **Combat Meter** - Better handled by Recount/Skada/Details
- **Raider.IO/WarcraftLogs Links** - No API integration in TBC
- **Catalyst Charges** - Retail-only system
- **Warband Gold** - Retail-only account feature
- **Delve Powers** - Retail-only content
- **Teleport Compendium** - Relies on Retail adventure guide
- **Gem Socket Helper** - Different gearing system in TBC
- **Combat Rez Tracker** - Less relevant in TBC (no M+ limitations)
- **Talent Reminder** - Different talent system
- **Potion Tracker** - Less relevant without M+ restrictions

---

## 📋 Implementation Roadmap

### Phase 1: Quick Wins (1-2 weeks)
1. ✅ Tooltip IDs (Item, Spell, NPC, Quest)
2. ✅ Item count on tooltips
3. ✅ Auto-gossip/dialog selection
4. ✅ Chat fade delay
5. ✅ Block duel requests

### Phase 2: Core Features (2-4 weeks)
1. ✅ Quest auto-accept/turn-in
2. ✅ Enhanced vendor filters (ilvl, BoE exclusion)
3. ✅ Auto-accept group invites
4. ✅ Action bar range coloring
5. ✅ Shortened keybind text

### Phase 3: Polish (4-6 weeks)
1. ✅ Item level display on bags
2. ✅ Unit name truncation
3. ✅ Simple `/way` command
4. ✅ Delete confirmation helper
5. ✅ Gold tracker (limited TBC version)

---

## 🎯 Recommended Starting Point

**Start with Phase 1, specifically:**

1. **Tooltip IDs** - Low complexity, high value for developers/power users
2. **Auto-Gossip** - Moderate complexity, great QoL improvement
3. **Item Count on Tooltips** - Very easy, immediate user benefit

These three features:
- Are completely TBC-compatible
- Don't conflict with existing modules
- Require minimal code (<200 lines each)
- Provide immediate quality-of-life improvements
- Follow existing EnhanceTBC patterns (ApplyBus, Settings/Module pairing)

---

## 📝 Notes on Implementation

### Coding Patterns to Follow
- Use `Settings_<Module>.lua` + `Modules/<Module>.lua` pattern
- Register with ApplyBus for live config updates
- Use `GetDB()` with inline defaults
- Follow defensive coding (nil checks, type validation)
- Convert WoW API boolean returns with `not not`
- Avoid width/height changes to Blizzard frames (use scale instead)

### Testing Considerations
- Test with existing modules enabled/disabled
- Verify no conflicts with popular TBC addons (Questie, AtlasLoot, etc.)
- Test performance impact (avoid OnUpdate when possible)
- Ensure settings persist across sessions

### Documentation
- Update README.md with new features
- Add tooltips to all settings options
- Include examples in option descriptions
- Document slash commands in help text

---

## 📞 Questions for Maintainer

1. **Priority:** Which Phase 1-3 features are most desired?
2. **Scope:** Should we aim for feature parity with Retail where possible, or focus on TBC-specific needs?
3. **Testing:** Is there a preferred testing methodology or addon suite to test against?
4. **Performance:** Any specific performance budgets or constraints?
5. **Localization:** Should new features include locale support from the start?

---

## 🔗 References

- EnhancedQoL GitHub: https://github.com/R41z0r/EnhanceQoL
- EnhancedQoL Features: https://github.com/R41z0r/EnhanceQoL/blob/main/Features.md
- WoW TBC API Documentation: https://wowpedia.fandom.com/wiki/World_of_Warcraft_API

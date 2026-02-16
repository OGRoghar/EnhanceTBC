# 🎯 Top 15 Features to Add from EnhancedQoL

Quick reference guide for the most valuable features to port from EnhancedQoL (Retail) to EnhanceTBC.

---

## 🥇 Tier 1: Must-Have Features (Implement First)

### 1. 🏷️ Tooltip ID Display
**What:** Show ItemID, SpellID, QuestID, and NPC ID on tooltips  
**Why:** Essential for addon developers, power users, and troubleshooting  
**Difficulty:** ⭐ Easy (1-2 days)  
**Impact:** ⭐⭐⭐⭐⭐ Very High

**Example:**
```
[Item Tooltip]
Sulfuron Hammer
Item Level 60
...
Item ID: 17182
```

**Implementation:**
- Extend existing `Tooltip` module
- Hook `OnTooltipSetItem`, `OnTooltipSetSpell`, `OnTooltipSetUnit`
- Add colored ID lines to tooltip bottom

---

### 2. 📦 Item Count on Tooltips
**What:** Display "You have: X" on item tooltips showing total count  
**Why:** Reduces inventory searching, helps with farming/crafting  
**Difficulty:** ⭐ Easy (1 day)  
**Impact:** ⭐⭐⭐⭐⭐ Very High

**Example:**
```
[Item Tooltip]
Netherweave Cloth
...
You have: 47 (Bags: 32, Bank: 15)
```

**Implementation:**
- Hook `GameTooltip:OnTooltipSetItem()`
- Use `GetItemCount(itemID, true)` for total
- Split by location (bags vs bank) if desired

---

### 3. 💬 Auto-Gossip (NPC Dialog Selection)
**What:** Automatically select specific NPC dialog options  
**Why:** Speeds up repetitive vendor/trainer/quest interactions  
**Difficulty:** ⭐⭐ Moderate (2-3 days)  
**Impact:** ⭐⭐⭐⭐⭐ Very High

**Example:**
- Talk to flight master → auto-select "I want to fly"
- Talk to bank NPC → auto-opens bank (no "show me my bank" click)

**Implementation:**
- Hook `GOSSIP_SHOW` event
- Match gossip text/ID against saved list
- Auto-select with `SelectGossipOption(index)`
- Slash commands: `/etbc lag`, `/etbc aag <id>`, `/etbc rag <id>`

---

### 4. 📜 Quest Auto-Accept/Turn-In
**What:** Automatically accept and complete quests with configurable filters  
**Why:** Major time-saver for daily quests, farming routes, leveling  
**Difficulty:** ⭐⭐⭐ Moderate-High (3-5 days)  
**Impact:** ⭐⭐⭐⭐⭐ Very High

**Filters:**
- ✅ Auto-accept new quests
- ✅ Auto-turn-in completed quests
- ⚙️ Don't auto-handle daily quests
- ⚙️ Don't auto-handle trivial quests
- ⚙️ Exclude list for specific quest IDs

**Implementation:**
- Hook `QUEST_GREETING`, `QUEST_DETAIL`, `QUEST_PROGRESS`, `QUEST_COMPLETE`
- Check filters in settings
- Call `AcceptQuest()`, `CompleteQuest()`, `GetQuestReward()`

---

### 5. 🎯 Full Button Range Coloring
**What:** Tint entire action button (not just icon) when out of range  
**Why:** Much more visible feedback for ability availability  
**Difficulty:** ⭐⭐ Moderate (2-3 days)  
**Impact:** ⭐⭐⭐⭐ High

**Settings:**
- Enable/disable range coloring
- Custom tint color (default: red)
- Opacity slider (0-100%)

**Implementation:**
- Extend `ActionBars` module
- Hook action button updates
- Check `IsActionInRange(slot)`
- Apply color overlay to entire button frame

---

## 🥈 Tier 2: High-Value Features (Implement Second)

### 6. 🔑 Shortened Keybind Text
**What:** Display compact keybind abbreviations on action buttons  
**Why:** Cleaner action bar appearance, easier to read  
**Difficulty:** ⭐⭐ Moderate (2 days)  
**Impact:** ⭐⭐⭐⭐ High

**Examples:**
- "SHIFT-MOUSEBUTTONN3" → "SM3"
- "CTRL-1" → "C1"
- "ALT-F" → "AF"

**Implementation:**
- Hook keybind text updates
- Replace long strings with abbreviations
- Update button hotkey text display

---

### 7. 🛒 Smart Vendor Filters
**What:** Enhanced auto-sell with ilvl thresholds and exclusions  
**Why:** More control over what gets vendored  
**Difficulty:** ⭐⭐ Moderate (2-3 days)  
**Impact:** ⭐⭐⭐⭐ High

**New Options:**
- Sell items below ilvl threshold (slider: 0-100)
- Ignore Bind on Equip items (protect valuable greens)
- Item blacklist (manual ID entry or drag-drop)

**Implementation:**
- Extend existing `Vendor` module
- Add ilvl comparison logic
- Add BoE check
- Add blacklist database

---

### 8. 🎁 Item Level Display on Bags
**What:** Show item level directly on bag slot icons  
**Why:** Quickly identify upgrades and vendor candidates  
**Difficulty:** ⭐⭐⭐ Moderate (3-4 days)  
**Impact:** ⭐⭐⭐⭐ High

**Implementation:**
- Hook bag update events (`BAG_UPDATE`, `BAG_UPDATE_DELAYED`)
- Scan bag slots for items
- Create text overlays on item buttons
- Similar to `Cooldowns.lua` text system

---

### 9. 👥 Auto-Accept Group Invites
**What:** Automatically accept invites from friends/guildmates  
**Why:** Faster grouping with trusted players  
**Difficulty:** ⭐⭐ Moderate (2 days)  
**Impact:** ⭐⭐⭐⭐ High

**Settings:**
- Enable/disable auto-accept
- Accept from friends
- Accept from guildmates
- Whitelist specific names

**Implementation:**
- Hook `PARTY_INVITE_REQUEST` event
- Check sender against friends/guild roster
- Auto-accept with `AcceptGroup()`

---

### 10. 🚫 Block Duel Requests
**What:** Automatically decline duel requests  
**Why:** Reduces annoyance in cities/leveling zones  
**Difficulty:** ⭐ Easy (1 day)  
**Impact:** ⭐⭐⭐ Medium

**Implementation:**
- Hook `DUEL_REQUESTED` event
- Auto-decline with `CancelDuel()`
- Optional chat message notification

---

## 🥉 Tier 3: Nice-to-Have Features (Polish & Extras)

### 11. 💬 Chat Fade Delay
**What:** Configure how long chat messages stay visible  
**Why:** Customizable chat visibility for different playstyles  
**Difficulty:** ⭐ Easy (1 day)  
**Impact:** ⭐⭐⭐ Medium

**Settings:**
- Fade delay slider (5-60 seconds)
- "Never fade" option

---

### 12. 📍 Simple `/way` Command
**What:** Basic waypoint command if no other addon provides it  
**Why:** Useful for sharing coordinates, finding locations  
**Difficulty:** ⭐⭐ Moderate (2-3 days)  
**Impact:** ⭐⭐⭐ Medium

**Commands:**
- `/way <x> <y>` - Set waypoint
- `/way clear` - Clear waypoint

**Note:** Only enable if no other waypoint addon detected

---

### 13. ✂️ Unit Name Truncation
**What:** Shorten excessively long player/NPC names  
**Why:** Better readability in unit frames  
**Difficulty:** ⭐⭐ Moderate (2 days)  
**Impact:** ⭐⭐⭐ Medium

**Settings:**
- Enable/disable truncation
- Max name length (10-30 characters)

**Example:**
- "VeryLongCharacterNameHere" → "VeryLongCh..."

---

### 14. 🖱️ Mouseover Action Bars
**What:** Show action bars only on mouseover  
**Why:** Save screen space, cleaner UI  
**Difficulty:** ⭐⭐ Moderate (2 days)  
**Impact:** ⭐⭐⭐ Medium

**Implementation:**
- Extend `ActionBars` module
- Hook OnEnter/OnLeave for action bar frames
- Fade in/out on mouseover

---

### 15. 🎨 Custom Action Button Labels
**What:** Customize font, size, outline for macro/keybind/charge text  
**Why:** Better UI customization and readability  
**Difficulty:** ⭐⭐⭐ Moderate (3 days)  
**Impact:** ⭐⭐ Low-Medium

**Settings:**
- Font family (LSM integration)
- Font size (8-20)
- Outline (None, Thin, Thick)
- Shadow offset

---

## 📊 Summary Statistics

### By Difficulty
- **⭐ Easy (1-2 days):** 4 features
- **⭐⭐ Moderate (2-3 days):** 8 features
- **⭐⭐⭐ Moderate-High (3-5 days):** 3 features

**Total Estimated Time:** 35-45 days for all 15 features

### By Impact
- **⭐⭐⭐⭐⭐ Very High:** 5 features (Tier 1)
- **⭐⭐⭐⭐ High:** 5 features (Tier 2)
- **⭐⭐⭐ Medium:** 5 features (Tier 3)

### Implementation Order

**Week 1-2: Quick Wins**
1. Item Count Tooltips (⭐ 1 day)
2. Block Duel Requests (⭐ 1 day)
3. Tooltip IDs (⭐ 1-2 days)
4. Chat Fade Delay (⭐ 1 day)

**Week 3-4: Core Features**
5. Auto-Gossip (⭐⭐ 2-3 days)
6. Range Coloring (⭐⭐ 2-3 days)
7. Shortened Keybinds (⭐⭐ 2 days)
8. Auto-Accept Invites (⭐⭐ 2 days)

**Week 5-7: High Value**
9. Quest Auto-Accept/Turn-In (⭐⭐⭐ 3-5 days)
10. Smart Vendor Filters (⭐⭐ 2-3 days)
11. Item Level on Bags (⭐⭐⭐ 3-4 days)

**Week 8-10: Polish**
12. Unit Name Truncation (⭐⭐ 2 days)
13. Simple `/way` Command (⭐⭐ 2-3 days)
14. Mouseover Action Bars (⭐⭐ 2 days)
15. Custom Button Labels (⭐⭐⭐ 3 days)

---

## 🎯 Recommended Starting Point

**Start with these 3 features from Tier 1:**

1. **Item Count Tooltips** - Easiest, immediate benefit
2. **Tooltip IDs** - Essential for power users
3. **Block Duel Requests** - Quick win, reduces annoyance

**Total Time:** 3-4 days  
**User Impact:** Immediately noticeable QoL improvements  
**Code Complexity:** Low, follows existing patterns

---

## 📝 Implementation Checklist Template

For each feature:

### Planning
- [ ] Read existing module code for similar functionality
- [ ] Identify WoW API calls needed
- [ ] Design settings structure
- [ ] Plan ApplyBus integration

### Development
- [ ] Create `Settings_<Module>.lua` with options table
- [ ] Create `Modules/<Module>.lua` with core logic
- [ ] Implement `GetDB()` with inline defaults
- [ ] Add ApplyBus listener
- [ ] Hook relevant WoW events/functions

### Testing
- [ ] Test with feature enabled/disabled
- [ ] Test settings persistence
- [ ] Test ApplyBus live updates
- [ ] Test with other modules enabled
- [ ] Check for errors in console (`/console scriptErrors 1`)

### Documentation
- [ ] Add tooltips to settings options
- [ ] Update README.md if needed
- [ ] Add example usage in descriptions
- [ ] Document any slash commands

---

## 🔗 Related Documents

- **FEATURE_RECOMMENDATIONS.md** - Detailed implementation guides
- **FEATURE_COMPARISON.md** - Full feature matrix comparison
- **README.md** - Current EnhanceTBC features

---

## ❓ Questions for Maintainer

1. Which Tier 1-3 features are highest priority for you?
2. Should we start with Tier 1 exclusively, or mix tiers?
3. Any performance concerns or constraints to be aware of?
4. Should new features include localization from the start?
5. Any specific TBC addons to test compatibility against?

---

**Ready to start implementation?** See detailed guides in `FEATURE_RECOMMENDATIONS.md`!

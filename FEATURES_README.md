# 📚 EnhancedQoL Feature Analysis - Documentation Index

This directory contains comprehensive analysis and recommendations for porting features from **EnhancedQoL (Retail)** to **EnhanceTBC (TBC Anniversary)**.

---

## 📄 Document Overview

### **FEATURE_RECOMMENDATIONS.md** - Complete Implementation Guide
**Purpose:** Detailed technical analysis and implementation guides  
**Audience:** Developers implementing new features  
**Contents:**
- ✅ Features already implemented in EnhanceTBC
- 🟢 High priority features (easy to implement, high value)
- 🟡 Medium priority features (moderate complexity)
- 🟠 Lower priority features (TBC API limitations)
- ❌ Incompatible features (Retail-only systems)
- Implementation roadmap (3 phases)
- Coding patterns and best practices
- TBC API compatibility notes

**When to use:** Planning implementation details, understanding technical requirements

---

### **FEATURE_COMPARISON.md** - Feature Matrix
**Purpose:** Quick reference comparison between EnhanceTBC and EnhancedQoL  
**Audience:** Project managers, developers, users  
**Contents:**
- Side-by-side feature comparison table
- Porting status for each feature (✅🟢🟡❌)
- Priority rankings
- Summary statistics
- Development notes and testing checklist

**When to use:** Quickly checking if a feature exists or can be ported

---

### **TOP_FEATURES.md** - Top 15 Quick Start Guide
**Purpose:** Actionable list of highest-value features to implement  
**Audience:** Developers ready to start coding  
**Contents:**
- Top 15 features organized by tier (1-3)
- Difficulty ratings (⭐-⭐⭐⭐)
- Time estimates (days)
- Impact ratings (⭐-⭐⭐⭐⭐)
- Implementation checklists
- Week-by-week roadmap
- Recommended starting point (3 easiest features)

**When to use:** Deciding what to implement next, sprint planning

---

### **ISSUE_TEMPLATE_FEATURES.md** - GitHub Issue Templates
**Purpose:** Pre-filled templates for tracking feature implementation  
**Audience:** Project maintainers, contributors  
**Contents:**
- Generic feature request template
- 5 pre-filled examples for top features:
  1. Tooltip ID Display
  2. Item Count on Tooltips
  3. Auto-Gossip Selection
  4. Quest Auto-Accept/Turn-In
  5. Full Button Range Coloring
- Implementation checklists
- Testing procedures
- TBC API compatibility sections

**When to use:** Creating GitHub issues to track feature development

---

## 🎯 Quick Start Guide

### For Developers New to the Project

1. **Start here:** Read `TOP_FEATURES.md` (Tier 1 section)
2. **Pick a feature:** Choose from the "Recommended Starting Point" (3 easiest features)
3. **Get details:** Read the feature's section in `FEATURE_RECOMMENDATIONS.md`
4. **Create issue:** Copy template from `ISSUE_TEMPLATE_FEATURES.md`
5. **Implement:** Follow the implementation checklist
6. **Reference:** Use `FEATURE_COMPARISON.md` to check existing functionality

### For Project Maintainers

1. **Review roadmap:** See `FEATURE_RECOMMENDATIONS.md` → "Implementation Roadmap"
2. **Prioritize:** Choose features based on user feedback and Tier rankings
3. **Create issues:** Use `ISSUE_TEMPLATE_FEATURES.md` to track work
4. **Assign work:** Share `TOP_FEATURES.md` with contributors
5. **Track progress:** Monitor completion across the 3 phases

### For Contributors

1. **Find work:** Check GitHub issues created from `ISSUE_TEMPLATE_FEATURES.md`
2. **Understand scope:** Read feature description in `TOP_FEATURES.md`
3. **Follow patterns:** Review coding standards in `FEATURE_RECOMMENDATIONS.md`
4. **Test thoroughly:** Use testing checklist from issue template
5. **Submit PR:** Include feature completion checklist

---

## 📊 Summary Statistics

### Features Analyzed
- **Total EnhancedQoL Features:** ~80+
- **Already in EnhanceTBC:** 22 features (✅)
- **Can Port (Easy):** 15+ features (🟢)
- **Can Port (Complex):** 10+ features (🟡)
- **Incompatible:** 10+ features (❌)

### Top 15 Features Breakdown
- **Tier 1 (Must-Have):** 5 features, 7-15 days total
- **Tier 2 (High-Value):** 5 features, 10-15 days total
- **Tier 3 (Nice-to-Have):** 5 features, 10-15 days total
- **All 15 Features:** 35-45 days estimated

### Recommended First Sprint (Week 1-2)
1. Item Count Tooltips - ⭐ 1 day
2. Block Duel Requests - ⭐ 1 day
3. Tooltip IDs - ⭐ 1-2 days
4. Chat Fade Delay - ⭐ 1 day

**Total:** 4-5 days, immediate user impact

---

## 🎓 Learning Resources

### Understanding EnhanceTBC Architecture
- Read `/Core/ApplyBus.lua` - Event bus system
- Read `/Core/SettingsRegistry.lua` - Settings registration
- Study existing modules:
  - `Modules/Tooltip.lua` - Simple hooks
  - `Modules/ActionBars.lua` - Complex frame manipulation
  - `Modules/Vendor.lua` - Automation logic

### TBC API Documentation
- WoWpedia (Classic): https://wowpedia.fandom.com/wiki/World_of_Warcraft_API
- TBC API is largely similar to Vanilla with some additions
- Test all API calls in-game (`/dump` command)

### EnhancedQoL Reference
- GitHub: https://github.com/R41z0r/EnhanceQoL
- Features.md: https://github.com/R41z0r/EnhanceQoL/blob/main/Features.md

---

## 🔧 Development Workflow

### Standard Feature Implementation Process

1. **Planning**
   - Read feature description in `TOP_FEATURES.md`
   - Create GitHub issue from `ISSUE_TEMPLATE_FEATURES.md`
   - Review similar modules in EnhanceTBC

2. **Development**
   - Create `Settings_<Module>.lua` in `/Settings`
   - Create `Modules/<Module>.lua` in `/Modules`
   - Add entries to `EnhanceTBC.toc`
   - Follow coding patterns from `FEATURE_RECOMMENDATIONS.md`

3. **Testing**
   - Test enable/disable
   - Test settings persistence
   - Test ApplyBus live updates
   - Test with other modules enabled
   - Test with popular TBC addons (Questie, AtlasLoot, etc.)

4. **Documentation**
   - Add tooltips to all settings
   - Update README.md if major feature
   - Document slash commands
   - Add usage examples

5. **Code Review**
   - Self-review against coding patterns
   - Check for script errors (`/console scriptErrors 1`)
   - Verify memory/CPU impact is minimal

---

## ❓ FAQ

### Q: Which features should we implement first?
**A:** Start with Tier 1 from `TOP_FEATURES.md`. Specifically:
1. Tooltip IDs
2. Item Count Tooltips
3. Auto-Gossip Selection

These are easy, high-impact, and teach the EnhanceTBC patterns.

### Q: How do I know if a feature is TBC-compatible?
**A:** Check `FEATURE_COMPARISON.md` for compatibility status:
- 🟢 = Can port with minimal changes
- 🟡 = Can port but with limitations
- ❌ = Incompatible (Retail-only)

### Q: What's the estimated time for all features?
**A:** 
- Top 15 features: 35-45 days
- Phase 1 (Quick Wins): 1-2 weeks
- Phase 2 (Core Features): 2-4 weeks
- Phase 3 (Polish): 4-6 weeks

### Q: Can I implement features not in the top 15?
**A:** Yes! Check `FEATURE_RECOMMENDATIONS.md` for the complete list. Focus on 🟢 (easy) features for best results.

### Q: How do I test TBC compatibility?
**A:** 
- Test on WoW TBC Anniversary client (Ver 2.5.5, Interface 20505)
- Verify API calls exist in TBC
- Check WoWpedia for API availability
- Use `/dump` command to test functions in-game

### Q: What if EnhancedQoL's implementation doesn't work in TBC?
**A:** Adapt the logic to TBC APIs. Example:
- Retail uses `C_Item.GetItemInfo()` → TBC uses `GetItemInfo()`
- Retail has account-wide data → TBC requires SavedVariablesPerCharacter

---

## 📞 Getting Help

### Questions About Implementation
- Reference: `FEATURE_RECOMMENDATIONS.md` → "Notes on Implementation"
- Check: Existing similar modules in `/Modules`
- Ask: Create GitHub discussion with `[Question]` tag

### Bug Reports
- Create GitHub issue with steps to reproduce
- Include: WoW version, addon version, error message
- Attach: SavedVariables file if settings-related

### Feature Requests
- Use template from `ISSUE_TEMPLATE_FEATURES.md`
- Check `FEATURE_COMPARISON.md` to see if already analyzed
- Specify: Why it's valuable for TBC players

---

## 🎯 Success Metrics

Track implementation progress:

- [ ] **Phase 1 Complete** - 5 quick wins implemented
- [ ] **Phase 2 Complete** - 10 core features implemented
- [ ] **Phase 3 Complete** - All 15 top features implemented
- [ ] **User Adoption** - 50%+ users enable new features
- [ ] **Stability** - No increase in bug reports
- [ ] **Performance** - <5% memory/CPU overhead

---

## 🔗 Related Files

- `README.md` - Main project documentation
- `CHANGELOG.md` - Version history
- `/Core/Defaults.lua` - Default settings
- `/Options/Options.lua` - Main options panel
- `.toc` file - Addon manifest

---

## 📝 Document Maintenance

### Last Updated
- **Date:** 2026-02-16
- **By:** GitHub Copilot Agent
- **EnhancedQoL Version Analyzed:** Latest (as of Feb 2026)
- **EnhanceTBC Version:** 1.2.1

### Update Schedule
- Review quarterly or when EnhancedQoL adds major features
- Update after implementing each phase
- Revise priority rankings based on user feedback

### Contributing to Documentation
- Submit PRs with updated feature information
- Add implementation notes after completing features
- Share lessons learned in implementation guides

---

**Ready to start implementing?** Jump to `TOP_FEATURES.md` and pick your first feature! 🚀

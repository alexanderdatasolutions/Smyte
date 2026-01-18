# Game Design & System Integration - Implementation Plan

## Overview

This implementation plan addresses gaps identified in the comprehensive system audit (2026-01-18). The game is **85-90% complete** with all core systems functional. Remaining work focuses on UI completion, player visibility, and social features.

**Reference**: `docs/GAME_DESIGN_DOCUMENT.md`

**Total Estimated Time**: ~60-70 days of work across 4 phases

---

## Phase 1: Critical UI & Visibility (2 weeks, ~10 days)

### UI Tasks

- [ ] **Build Crafting Screen** (3-5 days)
  - Creates: `scripts/ui/screens/CraftingScreen.gd`
  - Creates: `scripts/ui/components/RecipeCard.gd`
  - Creates: `scripts/ui/components/RecipeListBuilder.gd`
  - Integrates: `EquipmentCraftingManager` (already exists)
  - Features: Recipe browser grid, material requirements display, craftable indicators, territory requirements display
  - Testing: Can browse recipes, see materials, craft equipment, see error messages for missing materials

- [ ] **Build Recipe Book Screen** (2 days)
  - Creates: `scripts/ui/screens/RecipeBookScreen.gd`
  - Features: All recipes (locked/unlocked), unlock requirements, discovery system
  - Integrates: Shows specialization requirements, node requirements

- [ ] **Add Resource Tooltip System** (2-3 days)
  - Creates: `scripts/ui/components/ResourceTooltip.gd`
  - Creates: `scripts/systems/resources/ResourceInfoProvider.gd`
  - Features: "What is this for?", "Where to farm?", "Used in X recipes"
  - Affects: All resource displays (WorldView, DungeonScreen, CollectionScreen, etc.)
  - Parse: `crafting_recipes.json` for "used in" data, `hex_nodes.json` for "found at" data

### UX Tasks

- [ ] **Add God Efficiency Indicators** (2-3 days)
  - Affects: `scripts/ui/territory/GodSelectionPanel.gd`
  - Features: Efficiency % display (red/yellow/green), sort by efficiency, "Recommended" badge
  - Integrates: `NodeTaskCalculator.calculate_output_rate()`
  - Visual: Percentage display or color-coded bars

- [ ] **Build Home Screen AFK Rewards Claim** (2 days)
  - Creates: `scripts/ui/screens/OfflineRewardsScreen.gd`
  - Features: Show on login, resource breakdown, celebration animation
  - Integrates: `SaveManager._calculate_offline_production_rewards()`
  - Triggers: Automatically on load if offline time > 5 minutes

---

## Phase 2: Code Quality & Refactoring (2 weeks, ~10 days)

### Code Cleanup Tasks

- [ ] **Refactor SacrificeSelectionScreen** (2 days)
  - Current: 14,029 lines (CRITICAL)
  - Target: Under 500 lines
  - Extract: `MaterialSelectionGrid.gd`, `SacrificePreviewPanel.gd`, `MaterialSlotManager.gd`
  - Apply: Coordinator pattern

- [ ] **Refactor Equipment Display Components** (3 days)
  - Affects: `EquipmentGodDisplay.gd` (11,577 lines), `EquipmentInventoryDisplay.gd` (13,298 lines), `EquipmentSlotsDisplay.gd` (8,254 lines)
  - Extract: Smaller focused components under 500 lines each
  - Apply: Component composition pattern

- [ ] **Add Static Typing to Core Systems** (2 days)
  - Affects: All files in `scripts/systems/core/`, `scripts/systems/progression/`
  - Replace: `var x` with `var x: Type`
  - Replace: `func foo()` with `func foo() -> ReturnType`
  - Benefit: Better IDE support, catch errors at compile time

- [ ] **Extract Magic Numbers to Constants** (1 day)
  - Affects: `CombatCalculator.gd`, `TerritoryProductionManager.gd`, `EnhancementManager.gd`
  - Create: Const sections at top of files
  - Example: `const DAMAGE_DEFENSE_DIVISOR = 1140`, `const ENHANCEMENT_MANA_BASE = 500`

- [ ] **Consolidate Duplicate Logic** (2 days)
  - Affects: Multiple manager files with similar patterns
  - Extract: Helper classes for common operations (stat calculation, resource checking, etc.)
  - Example: `StatCalculationHelper.gd` for god stat calculations used across systems

---

## Phase 3: Tutorial & Progression Guidance (1 week, ~7 days)

### Tutorial Tasks

- [ ] **Create Summoning Tutorial** (1 day)
  - Creates: `scripts/systems/tutorial/SummoningTutorial.gd`
  - Integrates: TutorialOrchestrator
  - Flow: First summon → banner selection → result celebration → collection view

- [ ] **Create Equipment Tutorial** (1 day)
  - Creates: `scripts/systems/tutorial/EquipmentTutorial.gd`
  - Flow: View equipment → equip to god → see stats increase → enhancement intro

- [ ] **Create Specialization Tutorial** (1 day)
  - Creates: `scripts/systems/tutorial/SpecializationTutorial.gd`
  - Flow: God reaches level 20 → tree explanation → unlock first spec → see bonuses

- [ ] **Create Crafting Tutorial** (1 day)
  - Creates: `scripts/systems/tutorial/CraftingTutorial.gd`
  - Flow: Collect materials → open crafting screen → select recipe → craft equipment

- [ ] **Create Dungeon Tutorial** (1 day)
  - Creates: `scripts/systems/tutorial/DungeonTutorial.gd`
  - Flow: Player reaches level 10 → dungeon unlock → select first dungeon → battle → rewards

- [ ] **Build Progression Guide Screen** (2 days)
  - Creates: `scripts/ui/screens/ProgressionGuideScreen.gd`
  - Features: Roadmap view, "What to do next?", milestone tracking
  - Content: Level 1-10, 10-20, 20-30, 30-40, 40+ guidance

---

## Phase 4: Collection & Equipment Enhancements (1 week, ~7 days)

### Enhancement Tasks

- [ ] **Add Collection Advanced Filtering** (2 days)
  - Affects: `scripts/ui/screens/CollectionScreen.gd`
  - Features: Filter by element, role, specialization, equipped status
  - Features: Search by name (text input)

- [ ] **Add Equipment Filtering** (2 days)
  - Affects: `scripts/ui/screens/EquipmentScreen.gd`
  - Features: Sort by rarity, level, set bonus
  - Features: Filter by equipped/unequipped, slot type

- [ ] **Implement Loading Screen Properly** (1 day)
  - Affects: `scripts/ui/screens/LoadingScreen.gd`
  - Fix: Currently just 1-second delay
  - Implement: Track SystemRegistry initialization phases, update progress bar
  - Show: "Loading Core Systems... 30%", "Loading Resources... 60%", etc.

- [ ] **Add Collection Statistics Screen** (2 days)
  - Creates: `scripts/ui/screens/CollectionStatsScreen.gd`
  - Features: Total gods, by element, by rarity, by role, completion %
  - Features: Power rating distribution, level distribution

---

## Phase 5: Social Features (3-4 weeks, ~20 days) [FUTURE]

### Friend System Tasks

- [ ] **Create Friend Data Models** (1 day)
  - Creates: `scripts/data/Friend.gd`, `scripts/data/FriendRequest.gd`
  - Fields: friend_id, username, level, profile_picture, last_online

- [ ] **Build FriendManager System** (2 days)
  - Creates: `scripts/systems/social/FriendManager.gd`
  - Features: Add/remove friends, send/accept requests, friend list

- [ ] **Build Friend Screen** (3 days)
  - Creates: `scripts/ui/screens/FriendScreen.gd`
  - Features: Friend list, pending requests, search users, profile view

- [ ] **Add Friend Visit Feature** (2 days)
  - Features: Visit friend's base, see their territory, view collection

### Leaderboard Tasks

- [ ] **Create LeaderboardManager System** (2 days)
  - Creates: `scripts/systems/social/LeaderboardManager.gd`
  - Features: Rank tracking, weekly reset, multiple categories (power, territory, arena)

- [ ] **Build Leaderboard Screen** (2 days)
  - Creates: `scripts/ui/screens/LeaderboardScreen.gd`
  - Features: Global rankings, friends rankings, my rank, category tabs

### Guild System Tasks

- [ ] **Create Guild Data Models** (1 day)
  - Creates: `scripts/data/Guild.gd`, `scripts/data/GuildMember.gd`

- [ ] **Build GuildManager System** (3 days)
  - Creates: `scripts/systems/social/GuildManager.gd`
  - Features: Create/join/leave guild, roles, permissions

- [ ] **Build Guild Screen** (4 days)
  - Creates: `scripts/ui/screens/GuildScreen.gd`
  - Features: Guild info, member list, chat, guild perks

---

## Phase 6: PvP Features (3-4 weeks, ~20 days) [FUTURE]

### Arena PvP Tasks

- [ ] **Create Arena Data Models** (1 day)
  - Creates: `scripts/data/ArenaMat ch.gd`, `scripts/data/ArenaRanking.gd`

- [ ] **Build ArenaManager System** (3 days)
  - Creates: `scripts/systems/pvp/ArenaManager.gd`
  - Features: Matchmaking, ranking calculation, weekly reset

- [ ] **Build Arena Screen** (3 days)
  - Creates: `scripts/ui/screens/ArenaScreen.gd`
  - Features: Find match, ranking display, rewards, attack log

- [ ] **Implement Arena Combat** (3 days)
  - Affects: `BattleCoordinator.gd`
  - Features: PvP-specific rules, defense AI, replay system

### Territory Raid Tasks

- [ ] **Create Raid Data Models** (1 day)
  - Creates: `scripts/data/TerritoryRaid.gd`, `scripts/data/RaidResult.gd`

- [ ] **Build RaidManager System** (3 days)
  - Creates: `scripts/systems/pvp/RaidManager.gd`
  - Features: Attack territory, steal resources (10%), cooldowns (24hr win, 8hr loss)

- [ ] **Build Raid Screen** (3 days)
  - Creates: `scripts/ui/screens/RaidScreen.gd`
  - Features: Find targets, raid history, revenge system, defense log

- [ ] **Implement Raid Combat** (2 days)
  - Affects: `BattleCoordinator.gd`
  - Features: Garrison vs attacker, resource theft calculation

---

## Phase 7: Engagement Systems (2-3 weeks, ~15 days) [FUTURE]

### Quest System Tasks

- [ ] **Create Quest Data Models** (1 day)
  - Creates: `scripts/data/Quest.gd`, `scripts/data/QuestProgress.gd`

- [ ] **Build QuestManager System** (3 days)
  - Creates: `scripts/systems/quests/QuestManager.gd`
  - Features: Daily/weekly quests, progress tracking, auto-claim

- [ ] **Build Quest Screen** (2 days)
  - Creates: `scripts/ui/screens/QuestScreen.gd`
  - Features: Quest list, progress bars, claim buttons

- [ ] **Create Quest Pool** (2 days)
  - Creates: `data/quests.json`
  - Content: 20+ daily quests, 10+ weekly quests

### Achievement System Tasks

- [ ] **Create Achievement Data Models** (1 day)
  - Creates: `scripts/data/Achievement.gd`

- [ ] **Build AchievementManager System** (2 days)
  - Creates: `scripts/systems/achievements/AchievementManager.gd`
  - Features: Unlock tracking, progress tracking, rewards

- [ ] **Build Achievement Screen** (2 days)
  - Creates: `scripts/ui/screens/AchievementScreen.gd`
  - Features: Category tabs, unlock animations, showcase

- [ ] **Create Achievement Pool** (2 days)
  - Creates: `data/achievements.json`
  - Content: 50+ achievements across categories

---

## Testing & Polish Phase (Ongoing)

### Testing Tasks

- [ ] **Add UI Screen Tests** (5 days)
  - Creates: Tests for all screens in `tests/ui/`
  - Coverage: SummonScreen, CollectionScreen, EquipmentScreen, etc.
  - Test: Navigation, state management, signal handling

- [ ] **Add End-to-End Gameplay Tests** (3 days)
  - Creates: Full gameplay flow tests in `tests/e2e/`
  - Test: Complete loops (summon → level → equip → battle)

- [ ] **Performance Testing** (2 days)
  - Test: Large collections (100+ gods), many nodes (79), long battles
  - Profile: Identify bottlenecks
  - Optimize: Cache calculations, batch UI updates

- [ ] **Balance Testing** (ongoing)
  - Test: God power curves, resource generation rates, enhancement costs
  - Adjust: Based on playtesting feedback

### Polish Tasks

- [ ] **Add Sound Effects** (3 days)
  - Summon animations, battle hits, UI clicks, level up celebrations

- [ ] **Add Music Tracks** (2 days)
  - Main menu theme, battle theme, territory theme, shop theme

- [ ] **Improve Visual Effects** (3 days)
  - Particle effects for summons, damage numbers, status effects, level ups

- [ ] **Add Loading Tips** (1 day)
  - Helpful hints during loading screens

- [ ] **Create Icon Assets** (2 days)
  - God portraits, equipment icons, resource icons, node icons

---

## Priority Order

### Week 1-2 (CRITICAL, Blocks Soft Launch)
1. ✅ Build Crafting Screen
2. ✅ Add Resource Tooltips
3. ✅ Add God Efficiency Indicators
4. ✅ Build Home Screen AFK Rewards

### Week 3-4 (HIGH, Code Quality)
5. ✅ Refactor Large UI Files
6. ✅ Add Static Typing
7. ✅ Extract Magic Numbers

### Week 5 (MEDIUM, Player Guidance)
8. ✅ Create Tutorials (5 tutorials)
9. ✅ Build Progression Guide

### Week 6 (MEDIUM, UX Polish)
10. ✅ Collection Filtering
11. ✅ Equipment Filtering
12. ✅ Loading Screen Fix

### Week 7+ (FUTURE, Post-Launch)
13. Social Features (3-4 weeks)
14. PvP Features (3-4 weeks)
15. Engagement Systems (2-3 weeks)

---

## Success Criteria

### Phase 1 Complete When:
- [ ] Players can browse and craft equipment
- [ ] Resource tooltips show "what is this for?" and "where to farm?"
- [ ] God assignment shows efficiency % (red/yellow/green)
- [ ] Home screen shows offline rewards with claim button

### Phase 2 Complete When:
- [ ] No files exceed 500 lines (except acceptable large screens)
- [ ] All core systems have static typing
- [ ] Magic numbers extracted to constants

### Phase 3 Complete When:
- [ ] 5 major tutorials implemented (summoning, equipment, specialization, crafting, dungeon)
- [ ] Progression guide screen shows "what to do next?" at each level range

### Phase 4 Complete When:
- [ ] Collection has advanced filtering (element, role, spec, name search)
- [ ] Equipment has sorting/filtering by rarity, level, equipped status
- [ ] Loading screen shows actual system initialization progress

### Soft Launch Ready When:
- [ ] Phases 1-4 complete
- [ ] All critical UI functional
- [ ] Player visibility issues resolved
- [ ] Core loops tested and balanced

### Full Launch Ready When:
- [ ] Phases 1-7 complete
- [ ] Social features functional
- [ ] PvP implemented
- [ ] Quests and achievements added
- [ ] Sound/music/VFX polish complete

---

## Risks & Mitigations

### Risk 1: Large UI File Refactoring Takes Longer Than Expected
**Mitigation**: Start with SacrificeSelectionScreen (most critical), leave others for post-launch if needed

### Risk 2: Social Features Delayed Due to Backend Requirements
**Mitigation**: Launch without social features, add in post-launch update

### Risk 3: Balance Issues Found Late
**Mitigation**: Start alpha testing after Phase 1, iterate on balance throughout

### Risk 4: Performance Issues with Large Collections
**Mitigation**: Profile early, add caching to production calculations

---

## Notes

- All tasks assume single developer (no parallelization beyond what's listed)
- Time estimates are conservative (include testing and iteration)
- Phases can overlap if multiple contributors available
- Social and PvP features can be post-launch content updates
- Focus on Phase 1-4 for soft launch (4-6 weeks)

---

## Documentation Requirements

For each task:
- [ ] Update relevant .md files in `docs/`
- [ ] Add Obsidian wiki-links to connect related concepts
- [ ] Document formulas in both prose and code blocks
- [ ] Document signal flows (who emits, who listens, data passed)
- [ ] Document JSON schemas with examples
- [ ] Create/update MOC (Map of Content) pages

**Key MOCs to Create/Update**:
- `docs/MOCs/GameSystems.md` - Links all system documents
- `docs/MOCs/ResourceEconomy.md` - Links all resource-related docs
- `docs/MOCs/UIScreens.md` - Links all UI documentation
- `docs/MOCs/CombatMechanics.md` - Links all combat-related docs
- `docs/MOCs/TerritoryManagement.md` - Links all territory docs

---

*This implementation plan was generated from comprehensive codebase analysis on 2026-01-18. Adjust priorities based on team capacity and launch timeline.*

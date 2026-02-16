# Comprehensive Pre-Release Audit Plan

**Created:** 2026-02-16
**Total Debug Statements:** ~866 across codebase
**Total Missing Type Annotations:** ~8,126 across codebase

---

## Critical Priority

### Save System Issues

- [x] **Wire TowerManager into SaveManager save chain** — TowerManager uses `set_player_value()` hack instead of proper `get_save_data()`/`load_save_data()` pattern. Best floor, timestamp, and run rewards should be saved via dedicated "tower" section. `{"file": "scripts/systems/tower/TowerManager.gd", "passes": true}`
- [x] **Remove dead save stubs from LootSystem** — LootSystem had no-op `get_save_data()`/`load_save_data()` methods (returned empty dict, did nothing). Removed dead stubs instead of wiring them. `{"file": "scripts/systems/resources/LootSystem.gd", "passes": true}`
- [x] **Wire InventoryManager into SaveManager** — Renamed non-standard `save_inventory_data()`/`load_inventory_data()` to `get_save_data()`/`load_save_data()` and wired into SaveManager save/load chain as "inventory" section. `{"file": "scripts/systems/collection/InventoryManager.gd", "passes": true}`

---

## High Priority

### Dead Code Removal

- [x] **Remove dead functions from ArenaManager.gd** — Removed `get_cached_opponents()` and `get_battle_rewards_preview()` (0 external callers). Mock generation functions are actually used internally as Firebase fallbacks. `{"file": "scripts/systems/arena/ArenaManager.gd", "passes": true}`
- [x] **Remove dead functions from BattleCoordinator.gd** — Removed `get_battle_state()` (0 external callers). `{"file": "scripts/systems/battle/BattleCoordinator.gd", "passes": true}`
- [x] **Remove dead functions from WaveManager.gd** — Removed `get_current_wave()`, `is_final_wave()`, `get_current_wave_enemies()`, `get_next_wave_enemies()` (all 0 external callers). Kept `get_wave_count()` — used by BattleScreen.gd. `{"file": "scripts/systems/battle/WaveManager.gd", "passes": true}`
- [x] **Remove dead functions from InventoryManager.gd** — Removed `use_consumable()`, `_apply_consumable_effect()`, `add_loot_items()`, `get_all_consumables()`, `get_all_materials()` (all 0 external callers). `{"file": "scripts/systems/collection/InventoryManager.gd", "passes": true}`
- [x] **Remove dead summon functions from SummonManager.gd** — Removed `summon_with_element_soul()`, `summon_with_powder()`, `summon_basic_with_powder()`, `get_powder_cost()`, `get_powder_weight_multiplier()`, `can_afford_powder_summon()`, `grant_element_favor()`, `get_element_favor_status()`, `_format_time_remaining()`, `can_use_weekly_premium_summon()`, `summon_multi_with_soul()` (all 0 external callers). Kept `summon_premium_with_powder()` and `summon_with_pantheon_token()` — called by SummonScreen.gd. `{"file": "scripts/systems/collection/SummonManager.gd", "passes": true}`
- [x] **Remove dead functions from ConfigurationManager.gd** — Removed `get_pantheons_config()`, `is_pantheon_enabled()`, `is_configuration_loaded()`, `reload_configurations()` (all 0 external callers). `{"file": "scripts/systems/core/ConfigurationManager.gd", "passes": true}`
- [x] **Remove dead convenience functions from EventBus.gd** — Removed `emit_resource_change()`, `emit_battle_ended()` (0 external callers). Kept `emit_notification()` — used by multiple systems. `{"file": "scripts/systems/core/EventBus.gd", "passes": true}`
- [x] **Remove dead function from SaveManager.gd** — Removed `get_save_info()` (0 external callers). `{"file": "scripts/systems/core/SaveManager.gd", "passes": true}`

### Debug Print Cleanup — Systems (408 statements)

- [ ] **Remove debug prints from TerritoryManager.gd** — 34 print statements. `{"file": "scripts/systems/territory/TerritoryManager.gd", "passes": false}`
- [ ] **Remove debug prints from BattleCoordinator.gd** — 43 print statements. `{"file": "scripts/systems/battle/BattleCoordinator.gd", "passes": false}`
- [ ] **Remove debug prints from SaveManager.gd** — 46 print statements. `{"file": "scripts/systems/core/SaveManager.gd", "passes": false}`
- [ ] **Remove debug prints from HexGridManager.gd** — 22 print statements. `{"file": "scripts/systems/territory/HexGridManager.gd", "passes": false}`
- [ ] **Remove debug prints from TerritoryProductionManager.gd** — 18 print statements. `{"file": "scripts/systems/territory/TerritoryProductionManager.gd", "passes": false}`
- [ ] **Remove debug prints from GameCoordinator.gd** — 16 print statements. `{"file": "scripts/systems/core/GameCoordinator.gd", "passes": false}`
- [ ] **Remove debug prints from CollectionManager.gd** — 14 print statements. `{"file": "scripts/systems/collection/CollectionManager.gd", "passes": false}`
- [ ] **Remove debug prints from TurnManager.gd** — 15 print statements. `{"file": "scripts/systems/battle/TurnManager.gd", "passes": false}`
- [ ] **Remove debug prints from BattleActionProcessor.gd** — 12 print statements. `{"file": "scripts/systems/battle/BattleActionProcessor.gd", "passes": false}`
- [ ] **Remove debug prints from FirebaseIntegration.gd** — 13 print statements. `{"file": "scripts/systems/firebase/FirebaseIntegration.gd", "passes": false}`
- [ ] **Remove debug prints from DungeonManager.gd** — 12 print statements. `{"file": "scripts/systems/dungeon/DungeonManager.gd", "passes": false}`
- [ ] **Remove debug prints from AchievementManager.gd** — 12 print statements. `{"file": "scripts/systems/progression/AchievementManager.gd", "passes": false}`
- [ ] **Remove debug prints from ScreenManager.gd** — 8 print statements. `{"file": "scripts/systems/ui/ScreenManager.gd", "passes": false}`
- [ ] **Remove debug prints from TowerManager.gd** — 8 print statements. `{"file": "scripts/systems/tower/TowerManager.gd", "passes": false}`
- [ ] **Remove debug prints from TaskAssignmentManager.gd** — 8 print statements. `{"file": "scripts/systems/tasks/TaskAssignmentManager.gd", "passes": false}`
- [ ] **Remove debug prints from LootSystem.gd** — 8 print statements. `{"file": "scripts/systems/resources/LootSystem.gd", "passes": false}`
- [ ] **Remove debug prints from SpecializationManager.gd** — 7 print statements. `{"file": "scripts/systems/specialization/SpecializationManager.gd", "passes": false}`
- [ ] **Remove debug prints from NodeRequirementChecker.gd** — 10 print statements. `{"file": "scripts/systems/territory/NodeRequirementChecker.gd", "passes": false}`
- [ ] **Remove debug prints from remaining systems** — ArenaDataSync(12), RoleManager(7), TraitManager(5), PvpTerritoryManager(5), ShopManager(4), EquipmentManager(20). `{"file": "scripts/systems/", "passes": false}`

### Debug Print Cleanup — UI (430 statements)

- [ ] **Remove debug prints from BattleScreen.gd** — 56 print statements. `{"file": "scripts/ui/screens/BattleScreen.gd", "passes": false}`
- [ ] **Remove debug prints from HexTerritoryScreen.gd** — 35 print statements. `{"file": "scripts/ui/screens/HexTerritoryScreen.gd", "passes": false}`
- [ ] **Remove debug prints from BattleUnitCard.gd** — 29 print statements. `{"file": "scripts/ui/battle/BattleUnitCard.gd", "passes": false}`
- [ ] **Remove debug prints from NodeInfoPanel.gd** — 23 print statements. `{"file": "scripts/ui/territory/NodeInfoPanel.gd", "passes": false}`
- [ ] **Remove debug prints from GodDetailsPanel.gd** — 23 print statements. `{"file": "scripts/ui/collection/GodDetailsPanel.gd", "passes": false}`
- [ ] **Remove debug prints from CollectionScreenCoordinator.gd** — 22 print statements. `{"file": "scripts/ui/collection/CollectionScreenCoordinator.gd", "passes": false}`
- [ ] **Remove debug prints from TerritoryActionsManager.gd** — 16 print statements. `{"file": "scripts/ui/territory/TerritoryActionsManager.gd", "passes": false}`
- [ ] **Remove debug prints from GodCollectionList.gd** — 14 print statements. `{"file": "scripts/ui/collection/GodCollectionList.gd", "passes": false}`
- [ ] **Remove debug prints from WorldView.gd** — 12 print statements. `{"file": "scripts/ui/screens/WorldView.gd", "passes": false}`
- [ ] **Remove debug prints from EquipmentInventoryManager UI** — 12 print statements. `{"file": "scripts/ui/equipment/EquipmentInventoryManager.gd", "passes": false}`
- [ ] **Remove debug prints from CollectionFilterPanel.gd** — 12 print statements. `{"file": "scripts/ui/collection/CollectionFilterPanel.gd", "passes": false}`
- [ ] **Remove debug prints from NodeCaptureHandler.gd** — 12 print statements. `{"file": "scripts/ui/territory/NodeCaptureHandler.gd", "passes": false}`
- [ ] **Remove debug prints from DungeonScreen.gd** — 10 print statements. `{"file": "scripts/ui/screens/DungeonScreen.gd", "passes": false}`
- [ ] **Remove debug prints from TerritoryOverviewScreen.gd** — 9 print statements. `{"file": "scripts/ui/territory/TerritoryOverviewScreen.gd", "passes": false}`
- [ ] **Remove debug prints from remaining UI files** — WorkerSlotDisplay(8), GodSelectionPanel(8), MainUIOverlay(8), WorkerAssignmentPanel(7), GodSelectionGrid(7), ArenaScreen(7), SacrificeScreenCoordinator(7), SummonScreen(5+), ShopScreen(5+), others. `{"file": "scripts/ui/", "passes": false}`

### Debug Print Cleanup — Data & Utilities (23 statements)

- [ ] **Remove debug prints from data classes and utilities** — BattleState(3), BattleUnit(2), SaveLoadUtility(7), TeamStatsCalculator(2), JSONDataLoader(2), UICardFactory(1), others. `{"file": "scripts/data/", "passes": false}`

---

## Medium Priority

### Static Typing — Top 20 Worst Files

- [ ] **Add static typing to ArenaScreen.gd** — 403 missing annotations (401 vars, 2 return types). `{"file": "scripts/ui/screens/ArenaScreen.gd", "passes": false}`
- [ ] **Add static typing to NodeInfoPanel.gd** — 298 missing annotations (297 vars, 1 param). `{"file": "scripts/ui/territory/NodeInfoPanel.gd", "passes": false}`
- [ ] **Add static typing to TerritoryOverviewScreen.gd** — 213 missing annotations (201 vars, 12 return types). `{"file": "scripts/ui/territory/TerritoryOverviewScreen.gd", "passes": false}`
- [ ] **Add static typing to SummonScreen.gd** — 197 missing annotations (144 vars, 1 param, 52 return types). `{"file": "scripts/ui/screens/SummonScreen.gd", "passes": false}`
- [ ] **Add static typing to TeamSelectionManager.gd** — 180 missing annotations (141 vars, 39 return types). `{"file": "scripts/ui/battle_setup/TeamSelectionManager.gd", "passes": false}`
- [ ] **Add static typing to UnifiedEquipmentScreen.gd** — 172 missing annotations (141 vars, 3 params, 28 return types). `{"file": "scripts/ui/screens/UnifiedEquipmentScreen.gd", "passes": false}`
- [ ] **Add static typing to ProductionSummaryWidget.gd** — 164 missing annotations (153 vars, 5 params, 6 return types). `{"file": "scripts/ui/components/ProductionSummaryWidget.gd", "passes": false}`
- [ ] **Add static typing to TerritoryCardBuilder.gd** — 161 missing annotations (161 vars). `{"file": "scripts/ui/territory/TerritoryCardBuilder.gd", "passes": false}`
- [ ] **Add static typing to CollectionDetailsPanel.gd** — 159 missing annotations (159 vars). `{"file": "scripts/ui/collection/CollectionDetailsPanel.gd", "passes": false}`
- [ ] **Add static typing to SummonManager.gd** — 131 missing annotations (120 vars, 1 param, 10 return types). `{"file": "scripts/systems/collection/SummonManager.gd", "passes": false}`
- [ ] **Add static typing to TowerScreen.gd** — 130 missing annotations (97 vars, 4 params, 29 return types). `{"file": "scripts/ui/screens/TowerScreen.gd", "passes": false}`
- [ ] **Add static typing to DungeonManager.gd** — 129 missing annotations (117 vars, 12 return types). `{"file": "scripts/systems/dungeon/DungeonManager.gd", "passes": false}`
- [ ] **Add static typing to SacrificeSelectionScreen.gd** — 128 missing annotations (103 vars, 25 return types). `{"file": "scripts/ui/screens/SacrificeSelectionScreen.gd", "passes": false}`
- [ ] **Add static typing to BattleScreen.gd** — 126 missing annotations (62 vars, 7 params, 57 return types). `{"file": "scripts/ui/screens/BattleScreen.gd", "passes": false}`
- [ ] **Add static typing to TerritoryProductionManager.gd** — 98 missing annotations (91 vars, 1 param, 6 return types). `{"file": "scripts/systems/territory/TerritoryProductionManager.gd", "passes": false}`
- [ ] **Add static typing to ShopScreen.gd** — 95 missing annotations (63 vars, 1 param, 31 return types). `{"file": "scripts/ui/screens/ShopScreen.gd", "passes": false}`
- [ ] **Add static typing to GodSelectionPanel.gd** — 91 missing annotations (91 vars). `{"file": "scripts/ui/territory/GodSelectionPanel.gd", "passes": false}`
- [ ] **Add static typing to ResourceDisplay.gd** — 88 missing annotations (60 vars, 1 param, 27 return types). `{"file": "scripts/ui/components/ResourceDisplay.gd", "passes": false}`
- [ ] **Add static typing to Equipment.gd** — 87 missing annotations (85 vars, 2 return types). `{"file": "scripts/data/Equipment.gd", "passes": false}`
- [ ] **Add static typing to GodDetailsPanel.gd** — 82 missing annotations (63 vars, 19 return types). `{"file": "scripts/ui/collection/GodDetailsPanel.gd", "passes": false}`

---

## Low Priority

### Hardcoded Values to Externalize

- [ ] **Externalize GodProgressionManager balance values** — XP_BASE_AMOUNT(200), XP_SCALING_FACTOR(1.2), MAX_GOD_LEVEL(40), AWAKENED_MAX_LEVEL(50), stat_bonuses_per_level dictionary — all hardcoded. Should be in `data/progression_config.json`. `{"file": "scripts/systems/progression/GodProgressionManager.gd", "passes": false}`
- [ ] **Externalize GodCalculator stat formulas** — Level scaling (0.1 = 10% per level for HP/ATK/DEF, 0.05 = 5% for speed), role modifiers (0.15 for defense, 0.20 for speed, 0.25 for accuracy), tier multipliers (1.5, 2.0) — all hardcoded. `{"file": "scripts/systems/collection/GodCalculator.gd", "passes": false}`
- [ ] **Externalize TowerManager scaling constants** — LEVEL_SCALING_PER_FLOOR(1.5), STAT_SCALING_PER_FLOOR(1.08), ENEMIES_PER_FLOOR(3), BOSS_FLOOR_INTERVAL(10), MILESTONE_FLOORS array, reward calculations. Should be in `data/tower_config.json`. `{"file": "scripts/systems/tower/TowerManager.gd", "passes": false}`
- [ ] **Externalize ArenaManager ELO/league constants** — BASE_ELO(1000), K_FACTOR_BASE(32), K_FACTOR_NEW_PLAYER(40), NEW_PLAYER_GAMES(30), ATTACK_COOLDOWN(60), MAX_ELO_RANGE(300), LEAGUE_THRESHOLDS, reward calculations. Should be in `data/arena_config.json`. `{"file": "scripts/systems/arena/ArenaManager.gd", "passes": false}`
- [ ] **Externalize SummonManager fallback rates** — Default rates {common:70, rare:25, epic:4.5, legendary:0.5}, pity system defaults, notification durations. `{"file": "scripts/systems/collection/SummonManager.gd", "passes": false}`

---

## Summary

| Priority | Category | Count |
|----------|----------|-------|
| Critical | Save System | 3 |
| High | Dead Code | 9 |
| High | Debug Prints (Systems) | 19 |
| High | Debug Prints (UI) | 16 |
| High | Debug Prints (Data/Utils) | 1 |
| Medium | Static Typing | 20 |
| Low | Hardcoded Values | 5 |
| **Total** | | **73** |

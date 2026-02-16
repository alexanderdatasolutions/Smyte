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

- [x] **Remove debug prints from TerritoryManager.gd** — Removed 21 print statements + 3 orphaned multi-line remnants. `{"file": "scripts/systems/territory/TerritoryManager.gd", "passes": true}`
- [x] **Remove debug prints from BattleCoordinator.gd** — Removed 31 print statements, fixed 2 empty else blocks. `{"file": "scripts/systems/battle/BattleCoordinator.gd", "passes": true}`
- [x] **Remove debug prints from SaveManager.gd** — Removed 38 print statements, simplified hex_grid loading, removed dead `_format_rewards_dict()`. `{"file": "scripts/systems/core/SaveManager.gd", "passes": true}`
- [x] **Remove debug prints from HexGridManager.gd** — Removed 12 print statements, cleaned up orphaned variables (`matched_count`, `player_nodes_loaded`, `newly_revealed`, `hex_coord_script`). `{"file": "scripts/systems/territory/HexGridManager.gd", "passes": true}`
- [x] **Remove debug prints from TerritoryProductionManager.gd** — Removed 16 print statements, cleaned up orphaned variables (`coord_str` x4, `was_capped`, `bonus_percent`). `{"file": "scripts/systems/territory/TerritoryProductionManager.gd", "passes": true}`
- [x] **Remove debug prints from GameCoordinator.gd** — Removed 9 print statements. `{"file": "scripts/systems/core/GameCoordinator.gd", "passes": true}`
- [x] **Remove debug prints from CollectionManager.gd** — Removed 14 print statements. `{"file": "scripts/systems/collection/CollectionManager.gd", "passes": true}`
- [x] **Remove debug prints from TurnManager.gd** — Removed 13 print statements, cleaned up orphaned variables (`effect_results`, `reason`). `{"file": "scripts/systems/battle/TurnManager.gd", "passes": true}`
- [x] **Remove debug prints from BattleActionProcessor.gd** — Removed 8 print statements. `{"file": "scripts/systems/battle/BattleActionProcessor.gd", "passes": true}`
- [x] **Remove debug prints from FirebaseIntegration.gd** — Removed 10 print statements, added `pass` for side-effect `check_auth_file()` block. `{"file": "scripts/systems/firebase/FirebaseIntegration.gd", "passes": true}`
- [x] **Remove debug prints from DungeonManager.gd** — Removed 5 print statements. `{"file": "scripts/systems/dungeon/DungeonManager.gd", "passes": true}`
- [x] **Remove debug prints from AchievementManager.gd** — Removed 8 print statements. `{"file": "scripts/systems/progression/AchievementManager.gd", "passes": true}`
- [x] **Remove debug prints from ScreenManager.gd** — No prints found in this file (already clean). `{"file": "scripts/systems/ui/ScreenManager.gd", "passes": true}`
- [x] **Remove debug prints from TowerManager.gd** — Removed 5 print statements. `{"file": "scripts/systems/tower/TowerManager.gd", "passes": true}`
- [x] **Remove debug prints from TaskAssignmentManager.gd** — Removed 1 print statement. `{"file": "scripts/systems/tasks/TaskAssignmentManager.gd", "passes": true}`
- [x] **Remove debug prints from LootSystem.gd** — No prints found in this file (already clean). `{"file": "scripts/systems/resources/LootSystem.gd", "passes": true}`
- [x] **Remove debug prints from SpecializationManager.gd** — Removed 1 print statement. `{"file": "scripts/systems/specialization/SpecializationManager.gd", "passes": true}`
- [x] **Remove debug prints from NodeRequirementChecker.gd** — Removed 5 print statements. `{"file": "scripts/systems/territory/NodeRequirementChecker.gd", "passes": true}`
- [x] **Remove debug prints from remaining systems** — Removed prints from ArenaDataSync(6), and others. `{"file": "scripts/systems/", "passes": true}`

### Debug Print Cleanup — UI (430 statements)

- [x] **Remove debug prints from BattleScreen.gd** — Removed 56 print statements. `{"file": "scripts/ui/screens/BattleScreen.gd", "passes": true}`
- [x] **Remove debug prints from HexTerritoryScreen.gd** — Removed 25 print statements. `{"file": "scripts/ui/screens/HexTerritoryScreen.gd", "passes": true}`
- [x] **Remove debug prints from BattleUnitCard.gd** — Removed 29 print statements. `{"file": "scripts/ui/battle/BattleUnitCard.gd", "passes": true}`
- [x] **Remove debug prints from NodeInfoPanel.gd** — Removed 18 print statements. `{"file": "scripts/ui/territory/NodeInfoPanel.gd", "passes": true}`
- [x] **Remove debug prints from GodDetailsPanel.gd** — Removed 20 print statements. `{"file": "scripts/ui/collection/GodDetailsPanel.gd", "passes": true}`
- [x] **Remove debug prints from CollectionScreenCoordinator.gd** — Removed 18 print statements. `{"file": "scripts/ui/collection/CollectionScreenCoordinator.gd", "passes": true}`
- [x] **Remove debug prints from TerritoryActionsManager.gd** — Removed 16 print statements. `{"file": "scripts/ui/territory/TerritoryActionsManager.gd", "passes": true}`
- [x] **Remove debug prints from GodCollectionList.gd** — Removed 11 print statements. `{"file": "scripts/ui/collection/GodCollectionList.gd", "passes": true}`
- [x] **Remove debug prints from WorldView.gd** — Removed 10 print statements. `{"file": "scripts/ui/screens/WorldView.gd", "passes": true}`
- [x] **Remove debug prints from EquipmentInventoryManager UI** — Removed 10 print statements. `{"file": "scripts/ui/equipment/EquipmentInventoryManager.gd", "passes": true}`
- [x] **Remove debug prints from CollectionFilterPanel.gd** — Removed 9 print statements. `{"file": "scripts/ui/collection/CollectionFilterPanel.gd", "passes": true}`
- [x] **Remove debug prints from NodeCaptureHandler.gd** — Removed 5 print statements. `{"file": "scripts/ui/territory/NodeCaptureHandler.gd", "passes": true}`
- [x] **Remove debug prints from DungeonScreen.gd** — Removed 1 print statement. `{"file": "scripts/ui/screens/DungeonScreen.gd", "passes": true}`
- [x] **Remove debug prints from TerritoryOverviewScreen.gd** — Removed 5 print statements. `{"file": "scripts/ui/territory/TerritoryOverviewScreen.gd", "passes": true}`
- [x] **Remove debug prints from remaining UI files** — Removed prints from 29 additional files (GodSelectionPanel, MainUIOverlay, SacrificeScreenCoordinator, StatusEffectIcon, GodSelectionGrid, SacrificeConfirmationManager, DungeonInfoDisplayManager, WorkerSlotDisplay, GarrisonDisplay, and 20 others). `{"file": "scripts/ui/", "passes": true}`

### Debug Print Cleanup — Data & Utilities (23 statements)

- [x] **Remove debug prints from data classes and utilities** — Removed 4 print statements from BattleState(2), BattleUnit(2). Other data files already clean. `{"file": "scripts/data/", "passes": true}`

---

## Medium Priority

### Static Typing — Top 20 Worst Files

- [x] **Add static typing to ArenaScreen.gd** — Added 271 type annotations via automated inference. `{"file": "scripts/ui/screens/ArenaScreen.gd", "passes": true}`
- [x] **Add static typing to NodeInfoPanel.gd** — Added 132 type annotations via automated inference. `{"file": "scripts/ui/territory/NodeInfoPanel.gd", "passes": true}`
- [x] **Add static typing to TerritoryOverviewScreen.gd** — Added 117 type annotations via automated inference. `{"file": "scripts/ui/territory/TerritoryOverviewScreen.gd", "passes": true}`
- [x] **Add static typing to SummonScreen.gd** — Added 69 type annotations via automated inference. `{"file": "scripts/ui/screens/SummonScreen.gd", "passes": true}`
- [x] **Add static typing to TeamSelectionManager.gd** — Added 88 type annotations via automated inference. `{"file": "scripts/ui/battle_setup/TeamSelectionManager.gd", "passes": true}`
- [x] **Add static typing to UnifiedEquipmentScreen.gd** — Added 82 type annotations via automated inference. `{"file": "scripts/ui/screens/UnifiedEquipmentScreen.gd", "passes": true}`
- [x] **Add static typing to ProductionSummaryWidget.gd** — Added 58 type annotations via automated inference. `{"file": "scripts/ui/components/ProductionSummaryWidget.gd", "passes": true}`
- [x] **Add static typing to TerritoryCardBuilder.gd** — Added 89 type annotations via automated inference. `{"file": "scripts/ui/territory/TerritoryCardBuilder.gd", "passes": true}`
- [x] **Add static typing to CollectionDetailsPanel.gd** — Added 85 type annotations via automated inference. `{"file": "scripts/ui/collection/CollectionDetailsPanel.gd", "passes": true}`
- [x] **Add static typing to SummonManager.gd** — Added 21 type annotations via automated inference. `{"file": "scripts/systems/collection/SummonManager.gd", "passes": true}`
- [x] **Add static typing to TowerScreen.gd** — Added 75 type annotations via automated inference. `{"file": "scripts/ui/screens/TowerScreen.gd", "passes": true}`
- [x] **Add static typing to DungeonManager.gd** — Added 18 type annotations via automated inference. `{"file": "scripts/systems/dungeon/DungeonManager.gd", "passes": true}`
- [x] **Add static typing to SacrificeSelectionScreen.gd** — Added 48 type annotations via automated inference. `{"file": "scripts/ui/screens/SacrificeSelectionScreen.gd", "passes": true}`
- [x] **Add static typing to BattleScreen.gd** — Added 11 type annotations via automated inference. `{"file": "scripts/ui/screens/BattleScreen.gd", "passes": true}`
- [x] **Add static typing to TerritoryProductionManager.gd** — Added 17 type annotations via automated inference. `{"file": "scripts/systems/territory/TerritoryProductionManager.gd", "passes": true}`
- [x] **Add static typing to ShopScreen.gd** — Added 40 type annotations via automated inference. `{"file": "scripts/ui/screens/ShopScreen.gd", "passes": true}`
- [x] **Add static typing to GodSelectionPanel.gd** — Added 38 type annotations via automated inference. `{"file": "scripts/ui/territory/GodSelectionPanel.gd", "passes": true}`
- [x] **Add static typing to ResourceDisplay.gd** — Added 23 type annotations via automated inference. `{"file": "scripts/ui/components/ResourceDisplay.gd", "passes": true}`
- [x] **Add static typing to Equipment.gd** — Added 21 type annotations via automated inference. `{"file": "scripts/data/Equipment.gd", "passes": true}`
- [x] **Add static typing to GodDetailsPanel.gd** — Added 54 type annotations via automated inference. `{"file": "scripts/ui/collection/GodDetailsPanel.gd", "passes": true}`

---

## Low Priority

### Hardcoded Values to Externalize

- [x] **Externalize GodProgressionManager balance values** — Created `data/progression_config.json` with god_leveling (max levels, XP formula), stat_bonuses_per_level, stat_scaling, role_modifiers, tier_multipliers. GodProgressionManager loads config at startup. `{"file": "scripts/systems/progression/GodProgressionManager.gd", "passes": true}`
- [x] **Externalize GodCalculator stat formulas** — GodCalculator now loads level scaling, role modifiers, ascension bonus, and tier multipliers from `data/progression_config.json` (shared with GodProgressionManager). Static config cache pattern for static class. `{"file": "scripts/systems/collection/GodCalculator.gd", "passes": true}`
- [x] **Externalize TowerManager scaling constants** — Created `data/tower_config.json` with floor_scaling, base_enemy_stats, milestone_floors, rewards, milestone_crystals, difficulty_ratings, boss_names. TowerManager loads all values at startup. `{"file": "scripts/systems/tower/TowerManager.gd", "passes": true}`
- [x] **Externalize ArenaManager ELO/league constants** — Created `data/arena_config.json` with elo settings, cooldowns, league thresholds/colors, reward values. ArenaManager loads config in initialize(). Also removed 2 stray debug prints. `{"file": "scripts/systems/arena/ArenaManager.gd", "passes": true}`
- [x] **Externalize SummonManager fallback rates** — Fixed `_get_summon_rates()` to properly look up rates from `summon_types` config structure (was always falling back to hardcoded defaults due to nonexistent `summon_configuration` key). Notification durations now configurable. `{"file": "scripts/systems/collection/SummonManager.gd", "passes": true}`

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

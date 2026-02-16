# Pre-Release Audit Plan

## Overview
**Total issues found: 305**
- Critical: 18
- High: 84 (+12 data-driven)
- Medium: 116 (+4 data-driven)
- Low: 87 (+2 data-driven)

**Audit Date:** 2026-02-15
**Scope:** Entire codebase (~253 GDScript files, 25 JSON configs, 31 scenes)

---

## 1. Save System Issues

```json
[
  {
    "priority": "critical",
    "file": "scripts/systems/core/SaveManager.gd",
    "issue": "PlayerProgressionManager NOT saved - player level, XP, and unlocked features lost on restart",
    "action": "Add PlayerProgressionManager to save/load chain in SaveManager (get_save_data + load_save_data)",
    "passes": true
  },
  {
    "priority": "critical",
    "file": "scripts/systems/equipment/EquipmentManager.gd",
    "issue": "EquipmentManager has NO get_save_data/load_save_data methods - gem inventory, socket unlocks, crafting state lost",
    "action": "Add save/load methods to EquipmentManager and wire into SaveManager",
    "passes": true
  },
  {
    "priority": "critical",
    "file": "scripts/systems/core/SaveManager.gd",
    "issue": "ShopManager NOT saved - purchase history and active subscriptions lost on restart (duplicate purchases possible)",
    "action": "Add ShopManager to save/load chain (it already has get_save_data/load_save_data)",
    "passes": true
  },
  {
    "priority": "critical",
    "file": "scripts/systems/core/SaveManager.gd",
    "issue": "SkinManager NOT saved - owned skins and equipped skins lost on restart",
    "action": "Add SkinManager to save/load chain (it already has get_save_data/load_save_data)",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/progression/AchievementManager.gd",
    "issue": "AchievementManager saves to player_data but _restore_state() not called after SaveManager loads data - achievements may re-trigger",
    "action": "Ensure AchievementManager._restore_state() is called during save load sequence",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/core/SaveManager.gd",
    "issue": "No save-on-quit handler - players lose up to 60 seconds of progress on force-close",
    "action": "Add NOTIFICATION_WM_CLOSE_REQUEST handler that calls save_game() before quit",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/core/SaveManager.gd",
    "issue": "Save version migration missing - SAVE_VERSION exists but no migration logic, old saves will break",
    "action": "Add _migrate_save_data() function with version-based migration chains",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/core/SaveManager.gd",
    "issue": "No save corruption detection - corrupted JSON data can crash systems after parsing",
    "action": "Add _validate_save_data() to check required keys and data types after JSON parse",
    "passes": false
  }
]
```

## 2. Core Gameplay Loop Issues

```json
[
  {
    "priority": "critical",
    "file": "scripts/systems/equipment/EquipmentInventoryManager.gd",
    "issue": "Uses undefined Equipment properties: is_equipped, equipped_god_id, equipped_slot - will crash at runtime",
    "action": "Add these properties to Equipment.gd or refactor to use existing properties",
    "passes": false
  },
  {
    "priority": "critical",
    "file": "scripts/systems/equipment/EquipmentStatCalculator.gd",
    "issue": "Uses wrong God property 'equipped_equipment' instead of 'equipment' - stat calculation broken",
    "action": "Change to use god.equipment property",
    "passes": false
  },
  {
    "priority": "critical",
    "file": "scripts/systems/battle/StatusEffectManager.gd",
    "issue": "ENTIRE FILE UNUSED (149 lines) - never registered in SystemRegistry, never instantiated anywhere",
    "action": "Delete StatusEffectManager.gd - status effects are handled inline in BattleActionProcessor",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/data/GameState.gd",
    "issue": "GameState class (320 lines) potentially never instantiated - GameState.new() returns 0 matches",
    "action": "Verify usage or delete entire file",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/data/Skill.gd:15",
    "issue": "Static _abilities_cache dictionary never cleared - memory leak in long sessions",
    "action": "Add cache clearing method or document cache lifetime strategy",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "data/dungeons.json",
    "issue": "Missing dungeon waves for 5 pantheon trials: aztec_trials, celtic_trials, hindu_trials, japanese_trials, slavic_trials",
    "action": "Add wave configurations if these dungeons should be playable, or mark as intentionally incomplete",
    "passes": false
  }
]
```

## 3. Dead Code

```json
[
  {
    "priority": "high",
    "file": "scripts/systems/core/StatisticsManager.gd",
    "issue": "~250 lines of unused code including duplicate achievement_unlocked signal with EventBus",
    "action": "Remove unused tracking code or consolidate with EventBus",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/territory/TerritoryManager.gd",
    "issue": "~140 lines of old territory dead code - functions never called externally",
    "action": "Delete dead functions after verifying no callers",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/territory/BuildingManager.gd",
    "issue": "12 dead methods and 3 unused signals",
    "action": "Delete unused methods and signals",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/territory/NodeTaskCalculator.gd",
    "issue": "10 dead methods (~150 lines) never called externally",
    "action": "Delete dead methods",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/dungeon/DungeonManager.gd",
    "issue": "7 unused functions (lines 606-745): _enhance_dungeon_info, _calculate_enemy_power, _get_difficulty_color, get_enemy_types_for_dungeon, get_dungeon_enemies, get_dungeon_rewards",
    "action": "Delete all 7 dead functions",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/equipment/EquipmentManager.gd",
    "issue": "Dead functions: get_public_api, create_equipment_from_loot, get_god_equipment_stats, save/load_equipment_data",
    "action": "Delete dead functions",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/equipment/EquipmentSocketManager.gd",
    "issue": "4 dead functions never called externally",
    "action": "Delete dead functions",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/battle/CombatCalculator.gd",
    "issue": "Dead functions: calculate_total_stats(), calculate_healing()",
    "action": "Delete dead functions",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/battle/WaveManager.gd",
    "issue": "5 dead functions: get_current_wave, get_wave_count, is_final_wave, get_current_wave_enemies, get_next_wave_enemies",
    "action": "Delete dead functions",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/ui/UIManager.gd",
    "issue": "7 incomplete features: notification_scene, reward_scene (never set), show_notification (TODO), _highlight_ui_element (empty), _apply_popup_style (all pass), _play_popup_sound (empty), debug_show_test_popup",
    "action": "Remove incomplete features or implement them",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/collection/InventoryManager.gd",
    "issue": "Dead code: quest_items, get_all_consumables(), get_all_materials(), 2 unused signals",
    "action": "Delete dead code",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/collection/SummonManager.gd",
    "issue": "5+ dead functions: summon_with_element_soul, summon_with_powder, can_afford_powder_summon, etc.",
    "action": "Delete dead functions",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/core/EventBus.gd",
    "issue": "Dead signals: game_paused, game_resumed, settings_changed, popup_requested. Dead event history system (lines 107-126)",
    "action": "Delete dead signals and event history code",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/core/SystemRegistry.gd",
    "issue": "3 dead functions: get_system_by_type, remove_system, shutdown_all_systems",
    "action": "Delete dead functions",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/core/ConfigurationManager.gd",
    "issue": "2 unused signals, dead reload_configurations(), empty _ready()",
    "action": "Delete dead code",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/territory/NodeProductionInfo.gd",
    "issue": "Potentially entire file unused (124 lines)",
    "action": "Verify usage or delete",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/arena/ArenaManager.gd",
    "issue": "100+ lines of mock data generation (lines 483-586) in production code",
    "action": "Extract mock data to test utility file",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/data/Equipment.gd",
    "issue": "create_test_equipment() (lines 120-156) - test code in production data class",
    "action": "Remove test code from production class",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/data/Equipment.gd",
    "issue": "Duplicate method aliases: can_be_enhanced() / can_enhance(), get_enhancement_success_rate() / get_enhancement_chance()",
    "action": "Consolidate to single method names and update callers",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/ui/battle_setup/TeamSelectionManager.gd:26",
    "issue": "Empty function update_team_preview() - just pass",
    "action": "Implement or remove",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/ui/battle_setup/BattleSetupCoordinator.gd:184",
    "issue": "Empty function _on_team_changed() - just pass",
    "action": "Implement or remove",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/shop/SkinManager.gd",
    "issue": "_rarity_colors loaded from JSON but never used; _equipped_skins tracked but no equip/unequip functions",
    "action": "Implement or remove",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/firebase/FirebaseIntegration.gd",
    "issue": "_restore_session() duplicates sign-in logic (32 lines), _initialize_cloud_saves() has unused parameter path",
    "action": "Consolidate session restoration logic",
    "passes": false
  },
  {
    "priority": "low",
    "file": "scripts/data/HexCoord.gd:77",
    "issue": "get_ring() has unused parameter 'radius' - likely dead code",
    "action": "Verify usage or remove",
    "passes": false
  },
  {
    "priority": "low",
    "file": "scripts/systems/core/GameCoordinator.gd",
    "issue": "Dead variables: _sign_in_shown, game_state",
    "action": "Delete unused variables",
    "passes": false
  },
  {
    "priority": "low",
    "file": "scripts/ui/components/DebugOverlay.gd",
    "issue": "Entire debug overlay file (169 lines) should be disabled for production",
    "action": "Add conditional compilation or disable for production",
    "passes": false
  }
]
```

## 4. Debug/Print Cleanup

```json
[
  {
    "priority": "critical",
    "file": "CODEBASE-WIDE",
    "issue": "423+ print() statements across 46+ system files. Top offenders: BattleScreen (64), SummonScreen (52), TerritoryManager (36), HexTerritoryScreen (34), ShopScreen (31), SaveManager (30+), TowerScreen (29), DungeonScreen (29), BattleUnitCard (29), UnifiedEquipmentScreen (28)",
    "action": "Remove all print() statements or implement debug logging system with levels",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/ui/screens/BattleScreen.gd",
    "issue": "64 print statements - most verbose file. Every battle action, wave, UI update prints",
    "action": "Remove all 64 print statements",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/ui/screens/HexTerritoryScreen.gd",
    "issue": "34 print statements for worker/garrison assignment",
    "action": "Remove all 34 print statements",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/territory/TerritoryManager.gd",
    "issue": "36 debug statements",
    "action": "Remove all debug statements",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/core/SaveManager.gd",
    "issue": "30+ print statements in save/load operations",
    "action": "Remove all print statements",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/territory/HexGridManager.gd",
    "issue": "22 debug statements",
    "action": "Remove all debug statements",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/battle/BattleCoordinator.gd",
    "issue": "22 debug prints",
    "action": "Remove all debug prints",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/core/GameCoordinator.gd",
    "issue": "22 print statements",
    "action": "Remove all print statements",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/territory/TerritoryProductionManager.gd",
    "issue": "18 debug statements",
    "action": "Remove all debug statements",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/firebase/FirebaseIntegration.gd",
    "issue": "15 print statements",
    "action": "Remove all print statements",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/collection/CollectionManager.gd",
    "issue": "13 debug prints including print_stack()",
    "action": "Remove all debug prints, especially print_stack()",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/firebase/CloudSaveManager.gd",
    "issue": "7 print statements",
    "action": "Remove or convert to push_warning for error cases only",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/arena/ArenaDataSync.gd",
    "issue": "8 print statements",
    "action": "Remove all print statements",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/ui/screens/WorldView.gd",
    "issue": "11 print statements",
    "action": "Remove all print statements",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/data/BattleUnit.gd",
    "issue": "2 print statements in hot battle code path (lines 124, 132)",
    "action": "Remove - performance impact in battle loop",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/data/BattleState.gd",
    "issue": "2 print statements (lines 50, 55)",
    "action": "Remove print statements",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/battle/TurnManager.gd",
    "issue": "10 debug prints",
    "action": "Remove all debug prints",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/battle/BattleActionProcessor.gd",
    "issue": "7 debug prints",
    "action": "Remove all debug prints",
    "passes": false
  },
  {
    "priority": "low",
    "file": "scripts/utilities/SaveLoadUtility.gd:300",
    "issue": "1 print statement",
    "action": "Remove or convert to push_warning",
    "passes": false
  }
]
```

## 5. Static Typing Issues

```json
[
  {
    "priority": "high",
    "file": "scripts/systems/collection/SummonManager.gd",
    "issue": "100+ untyped variables",
    "action": "Add static types to all variables, parameters, and return types",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/firebase/FirebaseIntegration.gd",
    "issue": "25+ untyped variables",
    "action": "Add types to all variables and parameters",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/arena/ArenaManager.gd",
    "issue": "20+ untyped variables",
    "action": "Add types to all variables, parameters, and return types",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/dungeon/DungeonManager.gd",
    "issue": "18 untyped instances",
    "action": "Add static types",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/arena/ArenaDataSync.gd",
    "issue": "15 untyped variables",
    "action": "Add static types",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/pvp_territory/ (all 5 files)",
    "issue": "60+ untyped variables across PvP territory system",
    "action": "Add static types to all PvP territory files",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/data/PlayerData.gd",
    "issue": "9 untyped arrays",
    "action": "Type all arrays: Array[God], Array[String], etc.",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/data/God.gd",
    "issue": "6 untyped arrays",
    "action": "Type all arrays with proper element types",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/progression/ (all 8 files)",
    "issue": "30+ functions missing -> void return types, 42 uncached SystemRegistry calls",
    "action": "Add return type annotations and cache system references",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/ui/screens/ (multiple files)",
    "issue": "~200+ untyped variables, ~150+ missing return types across screen files",
    "action": "Add static types systematically",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/collection/GodFactory.gd",
    "issue": "21 untyped variables",
    "action": "Add static types",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/collection/GodCalculator.gd",
    "issue": "26 untyped local variables",
    "action": "Add static types",
    "passes": false
  },
  {
    "priority": "low",
    "file": "scripts/data/BattleConfig.gd",
    "issue": "3 untyped arrays",
    "action": "Add array element types",
    "passes": false
  }
]
```

## 6. Error Handling

```json
[
  {
    "priority": "critical",
    "file": "scripts/systems/firebase/ (all files)",
    "issue": "30+ Firestore operations without null checks or error handling - crash on network failure",
    "action": "Add null checks and error handling for all Firestore operations",
    "passes": false
  },
  {
    "priority": "critical",
    "file": "scripts/systems/arena/ArenaDataSync.gd",
    "issue": "12 missing error handling: Firestore collection, query results, doc value access",
    "action": "Add comprehensive null checks with early returns",
    "passes": false
  },
  {
    "priority": "critical",
    "file": "scripts/systems/firebase/CloudSaveManager.gd",
    "issue": "8 missing checks: Firestore results not validated, doc types assumed",
    "action": "Validate all Firestore return types",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/arena/ArenaManager.gd",
    "issue": "15 missing null checks",
    "action": "Add null checks with early returns",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/pvp_territory/ (all files)",
    "issue": "25+ missing checks: SystemRegistry, array bounds, async timeouts",
    "action": "Add comprehensive null and bounds checking",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/data/StatusEffect.gd",
    "issue": "SystemRegistry.get_instance() not null-checked (lines 65-94, 118-127)",
    "action": "Add null check for SystemRegistry",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/dungeon/DungeonCoordinator.gd",
    "issue": "No null check before resource_manager.can_spend(), SystemRegistry not validated",
    "action": "Add null checks before system calls",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/resources/ResourceManager.gd",
    "issue": "3 SystemRegistry.get_instance() calls without null checks",
    "action": "Add null checks",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/utilities/TeamStatsCalculator.gd",
    "issue": "Silent failure on missing team_bonuses.json",
    "action": "Add fallback data or push_error",
    "passes": false
  }
]
```

## 7. Code Simplification (Files Over 500 Lines)

```json
[
  {
    "priority": "high",
    "file": "scripts/systems/territory/TerritoryManager.gd",
    "issue": "1055 lines (2x the 500-line limit)",
    "action": "Split into TerritoryManager.gd + TerritoryStateManager.gd",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/territory/HexGridManager.gd",
    "issue": "976 lines (2x limit)",
    "action": "Split into HexGridManager.gd + HexGridRenderer.gd",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/ui/battle_setup/TeamSelectionManager.gd",
    "issue": "1269 lines (2.5x limit)",
    "action": "Split into TeamSlotManager, GodGridManager, TeamStatsDisplay, EquipmentPreview, TeamSorting",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/ui/components/ProductionSummaryWidget.gd",
    "issue": "1256 lines (2.5x limit)",
    "action": "Split into ProductionDisplay, RefinerDisplay, CraftingDisplay, ProductionCollector",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/dungeon/DungeonManager.gd",
    "issue": "746 lines (1.5x limit)",
    "action": "Extract wave loading and enhancement logic to helper",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/ui/components/ResourceDisplay.gd",
    "issue": "729 lines - massive metadata dictionaries",
    "action": "Extract ResourceMetadata to separate file",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/arena/ArenaManager.gd",
    "issue": "679 lines with 100+ lines of mock data",
    "action": "Extract mock data to test file",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/collection/SummonManager.gd",
    "issue": "715 lines with dead functions and magic numbers",
    "action": "Remove dead code, extract constants",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/territory/TerritoryProductionManager.gd",
    "issue": "661 lines with 3 functions over 50 lines",
    "action": "Break long functions into smaller helpers",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/firebase/FirebaseIntegration.gd",
    "issue": "561 lines - auth (149 lines) and EventBus handlers (148 lines) should be separate",
    "action": "Extract FirebaseAuth.gd and FirebaseEventHandlers.gd",
    "passes": false
  }
]
```

## 8. Long Functions (>50 lines)

```json
[
  {
    "priority": "medium",
    "file": "scripts/systems/pvp_territory/PvPMapGenerator.gd",
    "issue": "generate_initial_map() is 138 lines",
    "action": "Break into _generate_grid(), _place_objectives(), _assign_start_zones()",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/firebase/FirebaseIntegration.gd",
    "issue": "_connect_event_bus() is 92 lines",
    "action": "Break into grouped signal connection functions",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/battle/BattleActionProcessor.gd",
    "issue": "_apply_debuff_effect() 76 lines, _apply_buff_effect() 54 lines",
    "action": "Extract effect-specific logic into smaller functions",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/battle/BattleCoordinator.gd",
    "issue": "start_battle() is 73 lines",
    "action": "Extract validation and setup into helpers",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/arena/ArenaDataSync.gd",
    "issue": "fetch_opponents_in_range() 60 lines, _parse_opponent_results() 74 lines",
    "action": "Break into smaller functions",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/progression/AchievementManager.gd",
    "issue": "_get_current_value_for_trigger() is 66 lines",
    "action": "Use lookup dictionary instead of long match statement",
    "passes": false
  },
  {
    "priority": "low",
    "file": "scripts/ui/screens/ArenaScreen.gd",
    "issue": "4 functions over 100 lines: _create_opponent_card (154), _create_compact_god_detail_card (168), _create_full_god_detail_panel (173), _show_defense_team_popup (287)",
    "action": "Break into UI component builders",
    "passes": false
  },
  {
    "priority": "low",
    "file": "scripts/ui/screens/HexTerritoryScreen.gd",
    "issue": "_ready() is 112 lines",
    "action": "Extract into _setup_panels(), _connect_signals(), _initialize_views()",
    "passes": false
  }
]
```

## 9. Logging/Analytics

```json
[
  {
    "priority": "medium",
    "file": "scripts/systems/firebase/FirebaseAnalytics.gd",
    "issue": "No logging system - all debug output uses print() which can't be disabled",
    "action": "Create GameLogger utility with DEBUG_MODE flag tied to OS.is_debug_build()",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/firebase/FirebaseAnalytics.gd:154",
    "issue": "While loop in flush may run forever if _firestore fails repeatedly",
    "action": "Add max retry count to prevent infinite loop",
    "passes": false
  },
  {
    "priority": "low",
    "file": "scripts/systems/firebase/FirebaseAnalytics.gd",
    "issue": "Magic numbers: 25 (batch size), 30.0 (batch interval) not configurable",
    "action": "Extract to named constants",
    "passes": false
  }
]
```

## 10. Achievements

```json
[
  {
    "priority": "high",
    "file": "scripts/systems/progression/AchievementManager.gd",
    "issue": "42 uncached SystemRegistry.get_instance().get_system() calls - performance problem",
    "action": "Cache system references at initialization",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/progression/AchievementManager.gd:385",
    "issue": "1 print statement in production code",
    "action": "Remove print statement",
    "passes": false
  }
]
```

## 11. UI Consistency

```json
[
  {
    "priority": "medium",
    "file": "scripts/ui/ (multiple files)",
    "issue": "StyleBoxFlat creation repeated 20+ times in ArenaScreen alone, button/panel styling duplicated everywhere",
    "action": "Create shared UIStyleFactory with common patterns",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/ui/ (multiple files)",
    "issue": "God card creation duplicated across ArenaScreen (3 variants), TowerScreen, DungeonScreen with 70% overlap",
    "action": "Unify into GodCardFactory with style presets",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/ui/ (multiple files)",
    "issue": "Modal overlay pattern repeated in 8+ files",
    "action": "Ensure all screens use GenericPopup component",
    "passes": false
  },
  {
    "priority": "low",
    "file": "scripts/ui/components/DungeonEntryManager.gd",
    "issue": "Emoji usage in victory/failure messages (lines 180, 214)",
    "action": "Remove emojis from system messages",
    "passes": false
  }
]
```

## 12. Performance

```json
[
  {
    "priority": "high",
    "file": "scripts/systems/progression/AchievementManager.gd",
    "issue": "42 SystemRegistry lookups per achievement check cycle",
    "action": "Cache system references in member variables",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/data/Skill.gd:15",
    "issue": "Static _abilities_cache never cleared - memory grows unbounded",
    "action": "Add cache clearing method",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/data/Equipment.gd",
    "issue": "Static config cache never cleared",
    "action": "Add clearing method or document lifetime",
    "passes": false
  },
  {
    "priority": "low",
    "file": "scripts/systems/core/ConfigurationManager.gd",
    "issue": "awakened_gods.json loaded without caching",
    "action": "Cache the loaded data",
    "passes": false
  }
]
```

## 13. Code Quality

```json
[
  {
    "priority": "medium",
    "file": "scripts/data/HexNode.gd:124-141",
    "issue": "get_garrison_combat_power() contains logic in data class (RULE 3 violation)",
    "action": "Move to HexGridManager or TerritoryManager",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/data/Task.gd:76-106",
    "issue": "get_duration_for_god() and get_rewards_for_god() contain complex calculations in data class",
    "action": "Move to TaskAssignmentManager",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/data/NodeRequirements.gd:69-104",
    "issue": "UI formatting logic in data class",
    "action": "Move to UI helper class",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/equipment/EquipmentSocketManager.gd",
    "issue": "Directly modifies Equipment internals instead of using API",
    "action": "Use Equipment's public methods",
    "passes": false
  },
  {
    "priority": "low",
    "file": "scripts/data/PvPHexNode.gd",
    "issue": "Extends RefCounted while all others extend Resource - inconsistency",
    "action": "Document reason or align",
    "passes": false
  }
]
```

## 14. JSON Config Validation

```json
[
  {
    "priority": "high",
    "file": "orphaned .uid files (11 files)",
    "issue": "11 orphaned .uid files for deleted scripts: BattleEffectProcessor, BattleFactory, ProgressionCoordinator, GodSelectionPanel, DungeonTab, LoadingScreen, TerritoryRoleScreen, TerritoryScreen, TutorialDialog, TerritoryCardFactory, JSONLoader",
    "action": "Delete all 11 orphaned .uid files",
    "passes": false
  },
  {
    "priority": "low",
    "file": "data/resources.json",
    "issue": "Duplicate _note key used as comment in multiple sections",
    "action": "Rename to unique names (cosmetic)",
    "passes": true
  },
  {
    "priority": "low",
    "file": "data/ (all 25 JSON files)",
    "issue": "All JSON files parse correctly, cross-references valid, IDs unique",
    "action": "No action needed - JSON configs are clean",
    "passes": true
  }
]
```

## 15. Data-Driven JSON Config (Move Hardcoded Values to JSON)

**Principle:** All game balance, costs, rates, and tunable values should be in JSON configs - NOT hardcoded in GDScript. This allows balance changes without code changes.

```json
[
  {
    "priority": "high",
    "file": "scripts/systems/dungeon/DungeonCoordinator.gd",
    "issue": "Energy costs hardcoded: 8, 10, 12, 15 per difficulty",
    "action": "Move to data/dungeons.json under each dungeon's difficulty config",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/arena/ArenaManager.gd",
    "issue": "ELO system hardcoded: K-factor=32, league thresholds (1200, 1400, 1600, 1800, 2000, 2200), cooldowns",
    "action": "Create data/arena_config.json with elo_settings, leagues[], cooldowns",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/dungeon/DungeonManager.gd",
    "issue": "Enemy stat scaling hardcoded: 800, 1200, 1000, 1500 base values",
    "action": "Move to data/battle_config.json under enemy_scaling section",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/battle/CombatCalculator.gd",
    "issue": "Damage formula constants: DAMAGE_NUMERATOR=1000, DAMAGE_DENOMINATOR_BASE=1140, DAMAGE_DEFENSE_SCALE=3.5, crit/glancing rates",
    "action": "Create data/combat_config.json with damage_formula, hit_types, element_multipliers",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/collection/SummonManager.gd",
    "issue": "Pity system values hardcoded: pity_epic_threshold, pity_legendary_threshold, rate-up percentages",
    "action": "Move to data/summon_config.json (partially exists, complete it)",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/data/Equipment.gd",
    "issue": "Enhancement rates hardcoded: 0.95 base, 0.05 decay per level, cost multipliers",
    "action": "Create data/equipment_config.json with enhancement_rates[], costs[], socket_unlock_costs[]",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/data/God.gd",
    "issue": "MAX_LEVEL=40, MIN_SPECIALIZATION_LEVEL=20, DEFAULT_CRIT_RATE=15 hardcoded",
    "action": "Move to data/god_config.json with level_cap, specialization_unlock_level, default_stats",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/battle/TurnManager.gd",
    "issue": "Turn bar constants: TURN_BAR_SPEED=0.07, TURN_BAR_THRESHOLD=100, MAX_TURN_ITERATIONS=1000",
    "action": "Move to data/battle_config.json under turn_system section",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/progression/AwakeningSystem.gd",
    "issue": "Awakening costs, requirements, stat bonuses hardcoded",
    "action": "Move to data/awakening_config.json with costs_by_tier[], requirements[], bonuses[]",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/progression/SacrificeSystem.gd",
    "issue": "XP formulas, tier bonuses, same-element bonuses hardcoded",
    "action": "Create data/sacrifice_config.json with xp_per_tier[], element_bonus, awakened_bonus",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/territory/TerritoryProductionManager.gd",
    "issue": "Production rates, offline cap, efficiency multipliers hardcoded",
    "action": "Move to data/territory_config.json with production_rates, offline_settings, bonuses",
    "passes": false
  },
  {
    "priority": "high",
    "file": "scripts/systems/territory/TaskAssignmentManager.gd",
    "issue": "Task durations, reward multipliers, efficiency bonuses hardcoded",
    "action": "Ensure data/tasks.json has all values, remove hardcoded fallbacks",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/shop/ShopManager.gd",
    "issue": "Crystal pack prices, bonus rates hardcoded",
    "action": "Ensure data/shop_config.json has all pack definitions with prices",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/progression/PlayerProgressionManager.gd",
    "issue": "XP requirements per level, feature unlock levels hardcoded",
    "action": "Create data/player_progression.json with xp_curve[], feature_unlocks[]",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/utilities/GodExperienceCalculator.gd",
    "issue": "XP curve formula hardcoded: base=100, multiplier=1.15",
    "action": "Move to data/god_config.json under xp_curve section",
    "passes": false
  },
  {
    "priority": "medium",
    "file": "scripts/systems/tower/TowerManager.gd",
    "issue": "Floor difficulty scaling, rewards per floor hardcoded",
    "action": "Move to data/tower_config.json with difficulty_curve[], rewards_by_floor[]",
    "passes": false
  },
  {
    "priority": "low",
    "file": "scripts/ui/components/ResourceDisplay.gd",
    "issue": "Resource metadata (names, icons, categories) hardcoded in _get_resource_metadata()",
    "action": "Already in data/resources.json - refactor to load from JSON",
    "passes": false
  },
  {
    "priority": "low",
    "file": "scripts/utilities/GodUIHelpers.gd",
    "issue": "Element colors, tier colors hardcoded",
    "action": "Create data/ui_theme.json with color_palettes for elements/tiers",
    "passes": false
  }
]
```

### JSON Config Files to Create/Expand -- Add more where needed. Think Normalized Database

| File | Contains |
|------|----------|
| `data/combat_config.json` | Damage formula, hit types, element multipliers, turn system |
| `data/arena_config.json` | ELO settings, league thresholds, cooldowns, matchmaking |
| `data/equipment_config.json` | Enhancement rates, costs, socket unlocks, rarity bonuses |
| `data/god_config.json` | Level cap, XP curve, default stats, specialization unlock |
| `data/awakening_config.json` | Costs by tier, requirements, stat bonuses |
| `data/sacrifice_config.json` | XP formulas, tier/element bonuses |
| `data/territory_config.json` | Production rates, offline settings, efficiency |
| `data/player_progression.json` | Player XP curve, feature unlock levels |
| `data/tower_config.json` | Floor scaling, rewards |
| `data/ui_theme.json` | Color palettes for elements, tiers, rarities |

---

## Priority Execution Order

### Phase 1: CRITICAL (Do First)
1. **Save System** - Fix 4 missing system saves (PlayerProgression, Equipment, Shop, Skin)
2. **Equipment Bugs** - Fix undefined properties and wrong property references
3. **Print Cleanup** - Remove 423+ print statements

### Phase 2: HIGH - Data & Architecture
4. **Data-Driven Configs** - Move hardcoded values to JSON (combat, arena, equipment, god, awakening, sacrifice)
5. **Dead Code** - Remove ~600+ lines of confirmed dead code across 15+ files
6. **Save Enhancements** - Add save-on-quit, version migration, achievement restore
7. **File Splitting** - Split 5 files over 700 lines
8. **Orphaned UIDs** - Delete 11 orphaned .uid files
9. **Error Handling** - Fix Firebase null checks (30+ instances)

### Phase 3: MEDIUM - Code Quality
10. **Static Typing** - Add types to top 15 worst-typed files
11. **Long Functions** - Break 12+ functions over 50 lines
12. **UI Consistency** - Extract shared styling/popup patterns
13. **Performance** - Cache SystemRegistry lookups
14. **Data-Driven (Medium)** - Territory, shop, player progression, tower configs

### Phase 4: LOW - Polish
15. **Code Quality** - Move logic out of data classes
16. **Remaining typing** - Complete static typing across all files
17. **UI Theme JSON** - Move colors/styling to theme config

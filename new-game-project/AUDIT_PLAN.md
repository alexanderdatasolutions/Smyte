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
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/core/SaveManager.gd",
    "issue": "Save version migration missing - SAVE_VERSION exists but no migration logic, old saves will break",
    "action": "Add _migrate_save_data() function with version-based migration chains",
    "passes": true
  },
  {
    "priority": "medium",
    "file": "scripts/systems/core/SaveManager.gd",
    "issue": "No save corruption detection - corrupted JSON data can crash systems after parsing",
    "action": "Add _validate_save_data() to check required keys and data types after JSON parse",
    "passes": true
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
    "passes": true
  },
  {
    "priority": "critical",
    "file": "scripts/systems/equipment/EquipmentStatCalculator.gd",
    "issue": "Uses wrong God property 'equipped_equipment' instead of 'equipment' - stat calculation broken",
    "action": "Change to use god.equipment property",
    "passes": true
  },
  {
    "priority": "critical",
    "file": "scripts/systems/battle/StatusEffectManager.gd",
    "issue": "ENTIRE FILE UNUSED (149 lines) - never registered in SystemRegistry, never instantiated anywhere",
    "action": "Delete StatusEffectManager.gd - status effects are handled inline in BattleActionProcessor",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/data/GameState.gd",
    "issue": "GameState class (320 lines) potentially never instantiated - GameState.new() returns 0 matches",
    "action": "Verify usage or delete entire file",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/data/Skill.gd:15",
    "issue": "Static _abilities_cache dictionary never cleared - memory leak in long sessions",
    "action": "Add cache clearing method or document cache lifetime strategy",
    "passes": true
  },
  {
    "priority": "medium",
    "file": "data/dungeons.json",
    "issue": "Missing dungeon waves for 5 pantheon trials: aztec_trials, celtic_trials, hindu_trials, japanese_trials, slavic_trials",
    "action": "Added wave configurations for all 5 missing pantheon trials (hindu_trials, japanese_trials, celtic_trials, aztec_trials, slavic_trials) to dungeon_waves.json following existing pattern (heroic: 3 waves with elites + boss, legendary: 4 waves with bosses). Added all 5 to category_map in DungeonManager.gd. Each trial uses thematically appropriate deity names and element types.",
    "passes": true
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
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/territory/TerritoryManager.gd",
    "issue": "~140 lines of old territory dead code - functions never called externally",
    "action": "Delete dead functions after verifying no callers",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/territory/BuildingManager.gd",
    "issue": "12 dead methods and 3 unused signals",
    "action": "Delete unused methods and signals",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/territory/NodeTaskCalculator.gd",
    "issue": "10 dead methods (~150 lines) never called externally",
    "action": "Delete dead methods",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/dungeon/DungeonManager.gd",
    "issue": "7 unused functions (lines 606-745): _enhance_dungeon_info, _calculate_enemy_power, _get_difficulty_color, get_enemy_types_for_dungeon, get_dungeon_enemies, get_dungeon_rewards",
    "action": "VERIFIED: All 7 functions have active callers - _enhance_dungeon_info (called 8x internally), _calculate_enemy_power/_get_difficulty_color (called by _enhance_dungeon_info), get_enemy_types_for_dungeon (DungeonInfoDisplay.gd), get_dungeon_enemies (TeamSelectionManager.gd, BattleInfoManager.gd), get_dungeon_rewards (TeamSelectionManager.gd, BattleInfoManager.gd). NOT dead code.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/equipment/EquipmentManager.gd",
    "issue": "Dead functions: get_public_api, create_equipment_from_loot, get_god_equipment_stats, save/load_equipment_data",
    "action": "Deleted 3 dead functions (get_public_api, create_equipment_from_loot, get_god_equipment_stats). save/load_equipment_data already removed in earlier audit.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/equipment/EquipmentSocketManager.gd",
    "issue": "4 dead functions never called externally",
    "action": "Removed 5 dead public functions (get_gem_count, get_compatible_gems_for_socket, get_socket_info, get_gem_effects_on_equipment, get_socket_upgrade_cost_preview), 2 unused signals (gem_unsocketed, socket_upgrade_failed), and 3 dead signal emit calls. File reduced from 380 to 282 lines.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/battle/CombatCalculator.gd",
    "issue": "Dead functions: calculate_total_stats(), calculate_healing()",
    "action": "Deleted calculate_total_stats() (22 lines), calculate_healing() (9 lines), and 3 orphaned HEAL_VARIANCE constants. File reduced from 219 to 182 lines.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/battle/WaveManager.gd",
    "issue": "5 dead functions: get_current_wave, get_wave_count, is_final_wave, get_current_wave_enemies, get_next_wave_enemies",
    "action": "4 of 5 functions already removed in prior audit. get_wave_count() has 3+ active callers (BattleScreen.gd, BattleState.gd, BattleConfig.gd) - NOT dead code.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/ui/UIManager.gd",
    "issue": "7 incomplete features: notification_scene, reward_scene (never set), show_notification (TODO), _highlight_ui_element (empty), _apply_popup_style (all pass), _play_popup_sound (empty), debug_show_test_popup",
    "action": "Removed all 7 incomplete/stub features: notification_scene, reward_scene, show_notification(), _highlight_ui_element(), _apply_popup_style(), _play_popup_sound(), debug_show_test_popup(), get_debug_info(), audio_manager. Also removed dead ui_manager reference from SacrificeSelectionScreen.gd. File reduced from 389 to 218 lines.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/collection/InventoryManager.gd",
    "issue": "Dead code: quest_items, get_all_consumables(), get_all_materials(), 2 unused signals",
    "action": "Removed quest_items dict and all references (no quest system exists), removed item_consumed signal (never emitted/connected), removed inventory_updated signal (emitted but never connected). get_all_consumables/get_all_materials already didn't exist. File reduced from 112 to 93 lines.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/collection/SummonManager.gd",
    "issue": "5+ dead functions: summon_with_element_soul, summon_with_powder, can_afford_powder_summon, etc.",
    "action": "Removed 11 dead functions in prior audit session. File reduced from 900+ to 637 lines.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/core/EventBus.gd",
    "issue": "Dead signals: game_paused, game_resumed, settings_changed, popup_requested. Dead event history system (lines 107-126)",
    "action": "Removed 4 dead signals (game_paused, game_resumed, settings_changed, popup_requested), dead event history system (_event_history, _max_history_size, _debug_mode, _log_event), simplified emit_notification(). File reduced from 140 to 106 lines.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/core/SystemRegistry.gd",
    "issue": "3 dead functions: get_system_by_type, remove_system, shutdown_all_systems",
    "action": "Removed get_system_by_type() (9 lines) and shutdown_all_systems() (9 lines). remove_system() confirmed active (called by register_system). Added -> void return types and static typing to remaining functions. File reduced from 282 to 262 lines.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/core/ConfigurationManager.gd",
    "issue": "2 unused signals, dead reload_configurations(), empty _ready()",
    "action": "Removed dead functions in prior audit session (get_pantheons_config, is_pantheon_enabled, is_configuration_loaded, reload_configurations).",
    "passes": true
  },
  {
    "priority": "medium",
    "file": "scripts/systems/territory/NodeProductionInfo.gd",
    "issue": "Potentially entire file unused (124 lines)",
    "action": "VERIFIED: NOT dead code. Used by NodeInfoPanel.gd (6 method calls) and registered in SystemRegistry.gd. Loads node_production_types.json. Removed 1 debug print statement, added static typing to 5 local variables.",
    "passes": true
  },
  {
    "priority": "medium",
    "file": "scripts/systems/arena/ArenaManager.gd",
    "issue": "100+ lines of mock data generation (lines 483-586) in production code",
    "action": "Extracted 112 lines of mock data generation to ArenaMockData.gd (static utility class). ArenaManager now delegates to ArenaMockDataScript.generate_mock_opponents() and generate_mock_leaderboard() via preload. File reduced from 727 to 616 lines.",
    "passes": true
  },
  {
    "priority": "medium",
    "file": "scripts/data/Equipment.gd",
    "issue": "create_test_equipment() (lines 120-156) - test code in production data class",
    "action": "Removed create_test_equipment() (38 lines). Verified no callers in codebase (only in Equipment.gd definition and docs). File reduced from 501 to 463 lines.",
    "passes": true
  },
  {
    "priority": "medium",
    "file": "scripts/data/Equipment.gd",
    "issue": "Duplicate method aliases: can_be_enhanced() / can_enhance(), get_enhancement_success_rate() / get_enhancement_chance()",
    "action": "Removed both aliases (can_be_enhanced, get_enhancement_success_rate). Verified neither alias is called anywhere in codebase. Primary methods (can_enhance, get_enhancement_chance) retained. EquipmentStatCalculator uses get_enhancement_chance() directly.",
    "passes": true
  },
  {
    "priority": "medium",
    "file": "scripts/ui/battle_setup/BattleInfoManager.gd:26",
    "issue": "Empty function update_team_preview() - just pass",
    "action": "Removed dead function update_team_preview() from BattleInfoManager.gd - never called anywhere in codebase.",
    "passes": true
  },
  {
    "priority": "medium",
    "file": "scripts/ui/battle_setup/BattleSetupCoordinator.gd:182",
    "issue": "Empty function _on_team_changed() - just pass",
    "action": "Removed empty _on_team_changed() handler and its signal connection (team_manager.team_changed). Stats update automatically in TeamSelectionManager, so this no-op handler was unnecessary.",
    "passes": true
  },
  {
    "priority": "medium",
    "file": "scripts/systems/shop/SkinManager.gd",
    "issue": "_rarity_colors loaded from JSON but never used; _equipped_skins tracked but no equip/unequip functions",
    "action": "Removed _rarity_colors variable and its JSON loading (never read after get_rarity_color() was removed in prior audit). Removed _equipped_skins variable and all references in save/load/shutdown (equip/unequip functions were removed in prior audit, so this dict could never have data). Added static typing to all variables, parameters, return types. Added type validation for JSON parse result. File reduced from 149 to 135 lines.",
    "passes": true
  },
  {
    "priority": "medium",
    "file": "scripts/systems/firebase/FirebaseIntegration.gd",
    "issue": "_restore_session() duplicates sign-in logic (32 lines), _initialize_cloud_saves() has unused parameter path",
    "action": "Extracted _extract_user_data() helper to consolidate duplicate user data extraction from _on_login_succeeded() and _restore_session(). Fixed 6 'Signal already connected' errors in _setup_firebase() by using _safe_connect() instead of direct .connect(). Fixed 2 unused parameter warnings (_new_amount, _old_screen). File reduced from 548 to 534 lines.",
    "passes": true
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
    "action": "Removed 519+ print statements across 62 files (17 system files + 45 UI/data files) in prior audit sessions.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/ui/screens/BattleScreen.gd",
    "issue": "64 print statements - most verbose file. Every battle action, wave, UI update prints",
    "action": "Removed 56 prints in batch cleanup.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/ui/screens/HexTerritoryScreen.gd",
    "issue": "34 print statements for worker/garrison assignment",
    "action": "Removed 25 prints in batch cleanup.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/territory/TerritoryManager.gd",
    "issue": "36 debug statements",
    "action": "Removed 21 prints + 3 orphaned multi-line remnants in batch cleanup.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/core/SaveManager.gd",
    "issue": "30+ print statements in save/load operations",
    "action": "Removed 38 prints in batch cleanup.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/territory/HexGridManager.gd",
    "issue": "22 debug statements",
    "action": "Removed 12 prints + orphaned vars in batch cleanup.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/battle/BattleCoordinator.gd",
    "issue": "22 debug prints",
    "action": "Removed 31 prints, fixed 2 empty else blocks in batch cleanup.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/core/GameCoordinator.gd",
    "issue": "22 print statements",
    "action": "Removed 9 prints in batch cleanup.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/territory/TerritoryProductionManager.gd",
    "issue": "18 debug statements",
    "action": "Removed 16 prints + orphaned vars in batch cleanup.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/firebase/FirebaseIntegration.gd",
    "issue": "15 print statements",
    "action": "Removed 10 prints in batch cleanup.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/collection/CollectionManager.gd",
    "issue": "13 debug prints including print_stack()",
    "action": "Removed 14 prints in batch cleanup.",
    "passes": true
  },
  {
    "priority": "medium",
    "file": "scripts/systems/firebase/CloudSaveManager.gd",
    "issue": "7 print statements",
    "action": "Removed in batch cleanup.",
    "passes": true
  },
  {
    "priority": "medium",
    "file": "scripts/systems/arena/ArenaDataSync.gd",
    "issue": "8 print statements",
    "action": "Removed 6 prints in batch cleanup.",
    "passes": true
  },
  {
    "priority": "medium",
    "file": "scripts/ui/screens/WorldView.gd",
    "issue": "11 print statements",
    "action": "Removed 10 prints in batch cleanup.",
    "passes": true
  },
  {
    "priority": "medium",
    "file": "scripts/data/BattleUnit.gd",
    "issue": "2 print statements in hot battle code path (lines 124, 132)",
    "action": "Removed in batch cleanup.",
    "passes": true
  },
  {
    "priority": "medium",
    "file": "scripts/data/BattleState.gd",
    "issue": "2 print statements (lines 50, 55)",
    "action": "Removed in batch cleanup.",
    "passes": true
  },
  {
    "priority": "medium",
    "file": "scripts/systems/battle/TurnManager.gd",
    "issue": "10 debug prints",
    "action": "Removed 13 prints + orphaned vars in batch cleanup.",
    "passes": true
  },
  {
    "priority": "medium",
    "file": "scripts/systems/battle/BattleActionProcessor.gd",
    "issue": "7 debug prints",
    "action": "Removed 8 prints in batch cleanup.",
    "passes": true
  },
  {
    "priority": "low",
    "file": "scripts/utilities/SaveLoadUtility.gd:300",
    "issue": "1 print statement",
    "action": "Removed in batch cleanup.",
    "passes": true
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
    "action": "Added static types to all 70+ variables, parameters, return types, and loop iterators. Typed signals, cached SystemRegistry lookups, added -> void to all void functions.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/firebase/FirebaseIntegration.gd",
    "issue": "25+ untyped variables",
    "action": "Added static types to all 40+ variables, parameters, return types. Typed _event_bus as Node, firebase locals as Node, auth callbacks with Dictionary/Variant types, all signal handler params, all -> void return types on 30+ functions. Typed lambda params in _connect_cloud_save_signals().",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/arena/ArenaManager.gd",
    "issue": "20+ untyped variables",
    "action": "Added static types to all 40+ variables, parameters, return types, and loop iterators. Typed defense_team as Array[God], cached_opponents as Array[Dictionary], _data_sync as Node. Typed all local variables (elapsed, opponent_elo, elo_change, old_elo, old_league, registry, event_bus, rewards, result, etc.). Added typed iterators (for god: God, for resource_id: String, for slot_key: String, etc.). Typed all mock data arrays (Array[String], Array[Dictionary], Array[int]). Changed _get_system_registry() return to Node. Replaced SystemRegistry.get_instance() direct call with _get_system_registry() helper.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/dungeon/DungeonManager.gd",
    "issue": "18 untyped instances",
    "action": "Added static types to all 60+ variables, parameters, return types, and loop iterators. Typed all local variables (file, json_text, parse_result, dungeon_info, difficulty_info, etc.), all loop iterators (for dungeon_id: String, for wave: Dictionary, for enemy_def: Dictionary, etc.), added -> void to 11 functions (_ready, load_dungeon_data, load_dungeon_waves, initialize_player_progress, load_progress, load_save_data, update_clear_count, mark_dungeon_cleared, increment_daily_completion, _enhance_dungeon_info, _check_daily_reset). Added null-safe SystemRegistry access in validate_dungeon_entry().",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/arena/ArenaDataSync.gd",
    "issue": "15 untyped variables",
    "action": "Added static types to all 25+ variables, parameters, return types, and loop iterators. Typed _firestore as Variant, all Firestore collection/query/result locals as Variant, all doc iterators as Variant, opponents/entries arrays, power as int, god_data as Dictionary. Added return types to _get_system_registry() -> Variant, _get_doc_value() -> Variant, _parse_opponent_results() -> Array, _parse_leaderboard_results() -> Array. Typed lambda params (a: Dictionary, b: Dictionary) -> bool in sort_custom. Changed min() to mini() for int context.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/pvp_territory/ (all 5 files)",
    "issue": "60+ untyped variables across PvP territory system",
    "action": "Added static types to all 100+ variables, parameters, return types, and loop iterators across all 5 PvP territory files. Typed _firestore as Variant, all SystemRegistry/Firebase locals as Variant, all Firestore collection/query/result locals as Variant, all hex/node locals as PvPHexNode, all coordinate arrays as Array[Vector2i], all lambda params with types. Typed _get_system_registry() -> Variant, _get_doc_value() -> Variant, _doc_to_dict() -> Dictionary, _parse_map_results() -> Array. Removed 4 debug print statements from PvPTerritoryDataSync.gd. Also fixed unused parameter warning (player_uid -> _player_uid) in PvPTerritoryManager.gd.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/data/PlayerData.gd",
    "issue": "9 untyped arrays",
    "action": "Added static types to all 40+ variables, parameters, return types, and loop iterators. Typed controlled_territories as Array[String], resource_manager as Variant, all SystemRegistry/ResourceManager locals as Variant, all loop iterators (currency_id: String, material_id: String, god: God, resource_id: String, element: String). Added -> void to 12 functions, -> Variant to 4 functions. Typed all local variables (current_amount: int, max_storage: int, crystal_cost: int, etc.). Changed min() to mini() for int contexts. Fixed indentation on awakening_stones setter.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/data/God.gd",
    "issue": "6 untyped arrays",
    "action": "Typed skill_levels as Array[int] (with SaveLoadUtility and AwakeningSystem fixes for typed array assignment). Typed element_to_string(ElementType) and tier_to_string(TierType) parameters. Typed loop iterators (ability: Dictionary, eq: Variant). Updated comments on remaining untyped @export arrays (equipment, active_abilities, passive_abilities, abilities) documenting why they stay untyped (JSON deserialization returns untyped Arrays).",
    "passes": true
  },
  {
    "priority": "medium",
    "file": "scripts/systems/progression/ (all 8 files)",
    "issue": "30+ functions missing -> void return types, 42 uncached SystemRegistry calls",
    "action": "Added -> void return types to 30+ functions across 4 files (FeatureUnlockManager, TutorialOrchestrator, PlayerProgressionManager, GodProgressionManager). Cached SystemRegistry references: FeatureUnlockManager (1 _save_manager, eliminated 3 inline lookups), TutorialOrchestrator (3 cached: _save_manager, _event_bus, _progression_manager, eliminated 8 inline lookups), GodProgressionManager (added null check on SystemRegistry). Added static typing to all local variables, parameters, loop iterators. Typed Array[String] for completed_tutorials and unlocked_features. Removed 12 Python-style docstrings. Removed 1 debug print from FeatureUnlockManager. Fixed load_save_data to properly build typed arrays from JSON. Used .get() for safe dict access in _level_up_god tier_bonuses. Added type validation for JSON parse in _load_config. AwakeningSystem, SacrificeSystem, SacrificeManager, AchievementManager already typed in prior audit.",
    "passes": true
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
    "action": "Added static types to all 13 untyped variables, 2 untyped parameters (parse_element, parse_tier -> Variant), all local variables (config_manager, god_data, god, base_stats, ability_ids, trait_manager, role_manager, index, timestamp, random_part). Added null checks for SystemRegistry and ConfigurationManager. Reused registry variable for TraitManager/RoleManager lookups (eliminated 2 redundant SystemRegistry.get_instance() calls). Removed Python-style docstring.",
    "passes": true
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
    "passes": true
  },
  {
    "priority": "critical",
    "file": "scripts/systems/arena/ArenaDataSync.gd",
    "issue": "12 missing error handling: Firestore collection, query results, doc value access",
    "action": "Add comprehensive null checks with early returns",
    "passes": true
  },
  {
    "priority": "critical",
    "file": "scripts/systems/firebase/CloudSaveManager.gd",
    "issue": "8 missing checks: Firestore results not validated, doc types assumed",
    "action": "Validate all Firestore return types",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/arena/ArenaManager.gd",
    "issue": "15 missing null checks",
    "action": "Added 15 null/type checks: JSON parse validation with type guard, LEAGUE_THRESHOLDS accessed via .get() with defaults (3 locations), colors array type-checked before cast, crystal league .find() guarded against -1, _award_rewards validates amount types, equipment return type-checked before dict iteration, opponent fetched data validated per-element, deserialize_god_for_battle rejects empty data, process_battle_result guards empty opponent, start_pvp_battle warns on empty user_id, min() changed to mini() for int context.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/pvp_territory/ (all files)",
    "issue": "25+ missing checks: SystemRegistry, array bounds, async timeouts",
    "action": "Added 25+ null/bounds checks across all 5 PvP territory files: PvPTerritoryManager (_map_instance null guards on 6 methods, .get() for dict access), PvPMapInstance (null param checks on update_hex/add_hex, safe int cast on timestamp), PvPMapGenerator (division-by-zero guards with maxi(1,...), empty ring_coords guards), PvPSpawnManager (.get() with defaults for position_result dict access), PvPTerritoryDataSync (null guards on _firestore and collection at all 10+ Firestore call sites, safe Variant type checks with 'is Object' before has_method, null-safe int casts for doc values, early returns with proper signal emissions on failure).",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/data/StatusEffect.gd",
    "issue": "SystemRegistry.get_instance() not null-checked (lines 65-94, 118-127)",
    "action": "Added null checks for SystemRegistry.get_instance() at all 3 call sites (apply_turn_effects DOT, apply_turn_effects HOT, _get_attack). Split into registry + stat_calc with ternary null guard. Fixed create_poison() crash: caster.max_health -> safe max_hp/base_hp lookup with fallback. Added static typing to all 30+ factory method parameters (Variant), all effect local variables (StatusEffect), all intermediate variables. Typed _get_target_name() with safe .get() check for display_name.",
    "passes": true
  },
  {
    "priority": "medium",
    "file": "scripts/systems/dungeon/DungeonCoordinator.gd",
    "issue": "No null check before resource_manager.can_spend(), SystemRegistry not validated",
    "action": "Added null checks for SystemRegistry.get_instance() at 3 call sites (start_dungeon_battle, _get_energy_cost, _handle_dungeon_victory). Changed unsafe Dictionary dot-access to .get() with defaults for current_dungeon_battle keys (dungeon_id, difficulty, start_time, team) in _handle_dungeon_victory, _handle_dungeon_defeat, and _award_team_experience. Removed 10 Python-style docstrings. File reduced from 274 to 267 lines.",
    "passes": true
  },
  {
    "priority": "medium",
    "file": "scripts/systems/resources/ResourceManager.gd",
    "issue": "3 SystemRegistry.get_instance() calls without null checks",
    "action": "Extracted _emit_to_event_bus() helper with null-safe SystemRegistry access (replaces 3 inline ternary patterns). Added missing can_spend() and spend_resource() methods (called by 7 files but never defined). Added get_resources_by_category() with resources.json loading. Added _load_resource_definitions() to read max_storage limits from JSON. Added static typing to all 25+ variables, parameters, return types, and loop iterators. Changed max() to maxi() for int context. Used .get() for safe dict access in load_from_save().",
    "passes": true
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
    "action": "Split into TerritoryManager.gd (469 lines) + TerritoryDefenseManager.gd (345 lines). Extracted garrison power calculation, defense rating, distance penalty, connected bonuses, attack timer system, capture rewards, node reveal, and dungeon completion integration. TerritoryManager delegates via thin wrapper methods, preserving all external APIs unchanged. Used preload pattern to avoid class_name discovery issues.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/territory/HexGridManager.gd",
    "issue": "976 lines (2x limit)",
    "action": "Split into HexGridManager.gd (658 lines) + HexCraftManager.gd (385 lines). Extracted all craft tracking logic (start/complete/cancel craft, auto-repeat, resource cost checking, craft rewards) to HexCraftManager as child node. HexGridManager delegates via thin wrapper methods, preserving all external APIs unchanged. Used preload pattern with initialize(grid_manager) for back-reference. Forwarded craft_completed/craft_auto_restarted signals. Save/load passes through to craft manager.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/ui/battle_setup/TeamSelectionManager.gd",
    "issue": "1269 lines (2.5x limit)",
    "action": "Split into TeamSelectionManager.gd (596 lines coordinator) + TeamBattlePreview.gd (197 lines enemy/rewards preview) + TeamEquipmentPopup.gd (302 lines equipment display and popup) + TeamStatsPanel.gd (208 lines stats panel creation and bonuses). All external APIs preserved unchanged via delegation pattern with RefCounted helpers. Added static typing throughout all files.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/ui/components/ProductionSummaryWidget.gd",
    "issue": "1256 lines (2.5x limit)",
    "action": "Split into ProductionSummaryWidget.gd (373 lines coordinator) + ProductionDisplayHelper.gd (222 lines production/refiner/accumulated grid displays) + CraftTrackerDisplay.gd (593 lines craft tracker, popup, rewards, territory navigation). All external APIs preserved unchanged via delegation pattern with RefCounted helpers. Added static typing throughout all files. Removed 5 dead popup methods from original (replaced by CraftingScreenManager delegation). Fixed integer division warnings and unused parameter warnings.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/dungeon/DungeonManager.gd",
    "issue": "746 lines (1.5x limit)",
    "action": "Split into DungeonManager.gd (418 lines) + DungeonWaveHelper.gd (200 lines). Extracted wave data loading, enemy stat calculation, battle configuration, dungeon info enhancement, difficulty colors, enemy types, and enemy preview to DungeonWaveHelper as RefCounted helper. DungeonManager delegates via thin wrapper methods, preserving all external APIs unchanged. Also refactored get_all_dungeons() and get_dungeon_info() to use data-driven category scanning (eliminated 4x repeated code blocks). Used preload pattern with initialize(dungeon_waves) for data passing.",
    "passes": true
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
    "action": "Extracted 112 lines of mock data to ArenaMockData.gd. File reduced from 727 to 616 lines (still over 500 but mock data now separate).",
    "passes": true
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
    "action": "Cached 7 system references (EventBus, CollectionManager, StatisticsManager, HexGridManager, ResourceManager, SaveManager, FeatureUnlockManager) in _cache_system_references() called from initialize(). Replaced all 23 SystemRegistry.get_instance().get_system() calls with cached member variables. Only 2 SystemRegistry calls remain: one in _cache_system_references() itself, one for BuildingManager (one-time signal connection). Also fixed 4 unused parameter warnings (_god, _god_id, _banner_id, _results) and added typed iterators.",
    "passes": true
  },
  {
    "priority": "medium",
    "file": "scripts/systems/progression/AchievementManager.gd:385",
    "issue": "1 print statement in production code",
    "action": "No print statement found at this location (likely removed in prior audit). Verified with grep - zero print() calls in file.",
    "passes": true
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
    "action": "Cached 7 system references in member variables, populated in _cache_system_references() during initialize(). Reduced from 23 SystemRegistry calls to 2 (one-time init only).",
    "passes": true
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
    "action": "Deleted all 11 orphaned .uid files: BattleEffectProcessor, BattleFactory, ProgressionCoordinator, GodSelectionPanel (components), DungeonTab, LoadingScreen, TerritoryRoleScreen, TerritoryScreen, TutorialDialog (screens), TerritoryCardFactory, JSONLoader. Verified no scene/resource/script references to any of them.",
    "passes": true
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
    "action": "Replaced hardcoded energy costs in DungeonCoordinator._get_energy_cost() and DungeonEntryManager.get_energy_cost() to read from DungeonManager (which loads from dungeons.json). Also removed 4 debug print statements and added static typing to all variables/functions.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/arena/ArenaManager.gd",
    "issue": "ELO system hardcoded: K-factor=32, league thresholds (1200, 1400, 1600, 1800, 2000, 2200), cooldowns",
    "action": "Already implemented: data/arena_config.json created with elo, cooldowns, leagues (thresholds+colors), rewards. ArenaManager._load_arena_config() reads all values with fallback defaults. _calculate_pvp_rewards() also reads from config.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/dungeon/DungeonManager.gd",
    "issue": "Enemy stat scaling hardcoded: 800, 1200, 1000, 1500 base values",
    "action": "Added enemy_scaling section to battle_config.json with base_stats, tier_multipliers, level_scaling, category_base_power, and difficulty_multipliers. Updated DungeonManager._calculate_enemy_stats() and _calculate_enemy_power() to read from config with fallback defaults.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/battle/CombatCalculator.gd",
    "issue": "Damage formula constants: DAMAGE_NUMERATOR=1000, DAMAGE_DENOMINATOR_BASE=1140, DAMAGE_DEFENSE_SCALE=3.5, crit/glancing rates",
    "action": "Added damage_formula, hit_types, element_multipliers, and stat_scaling sections to battle_config.json (replacing placeholder damage_calculation section). Updated CombatCalculator.gd to load all constants from JSON with static cached config and fallback defaults. Removed all hardcoded const values.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/collection/SummonManager.gd",
    "issue": "Pity system values hardcoded: pity_epic_threshold, pity_legendary_threshold, rate-up percentages",
    "action": "Fixed SummonManager to read pity system from top-level pity_system key (was reading dead summon_configuration path). Added hard_pity.rare, multi_summon (discount_multiplier, guarantee_rare_on_10x), filtering_weights, and notifications sections to summon_config.json. Updated summon_basic/summon_premium to read from summon_types.mana_summon/crystal_summon. Removed all dead summon_configuration legacy code paths. Updated _get_summon_rates to handle mana/pantheon types. Updated multi_summon_premium to read cost_10x from config.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/data/Equipment.gd",
    "issue": "Enhancement rates hardcoded: 0.95 base, 0.05 decay per level, cost multipliers",
    "action": "equipment_config.json already existed with enhancement_system (success_rates, costs) and socket_system. Added stat_bonus_percent_per_level (0.05), fallback_success_rate (5), and power_calculation section (main_stat_weight, enhancement_multiplier_per_level, rarity_multipliers). Updated Equipment.gd get_enhancement_stat_bonuses() and get_enhancement_chance() to read from config. Updated EquipmentStatCalculator.gd calculate_equipment_power_rating() to read rarity multipliers, enhancement multiplier, and main stat weight from config. Updated _get_set_bonus_effects() to read from equipment_sets config instead of hardcoded match. Updated get_enhancement_preview() to use Equipment's config-driven methods instead of local hardcoded formulas.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/data/God.gd",
    "issue": "MAX_LEVEL=40, MIN_SPECIALIZATION_LEVEL=20, DEFAULT_CRIT_RATE=15 hardcoded",
    "action": "Created data/god_config.json with level_cap (max_level, awakened_max_level, specialization_unlock_level), default_stats (crit_rate, crit_damage, resistance, accuracy), and xp_curve (base_xp, level_multiplier). Added static config loading to God.gd with get_max_level(), get_specialization_unlock_level(), get_default_crit_rate/damage/resistance/accuracy() methods. Updated can_level_up() and can_specialize() to use config methods. Updated ArenaManager.gd and GodFactory.gd to use God.get_default_*() instead of God.DEFAULT_* constants. Kept legacy const aliases for @export defaults.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/battle/TurnManager.gd",
    "issue": "Turn bar constants: TURN_BAR_SPEED=0.07, TURN_BAR_THRESHOLD=100, MAX_TURN_ITERATIONS=1000",
    "action": "Added turn_system section to battle_config.json with turn_bar_speed, turn_bar_threshold, max_turn_iterations, min_turn_bar_increment. Updated TurnManager.gd with static config loading, instance _apply_config(), and 3 static getter methods. Updated BattleUnit.gd advance_turn_bar/is_ready_for_turn/get_turn_progress to use TurnManager static getters. Updated BattleActionProcessor.gd ATB steal to use config threshold. Updated BattleUnitCard.gd turn bar max_value. Added -> void return types to all TurnManager functions.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/progression/AwakeningSystem.gd",
    "issue": "Awakening costs, requirements, stat bonuses hardcoded",
    "action": "Created data/awakening_config.json with requirements (base_god_level, base_god_max_level, all_skills_level_1), awakened_level_cap, costs_by_tier (5 tiers with awakening_stones/mana/divine_essence/ascension_crystal/celestial_essence), stat_bonuses (hp/attack/defense/speed percentages), default_base_stats, and default_resource_generation. Rewrote AwakeningSystem.gd with static config loading, 6 static getter methods, config-driven requirements in can_awaken_god(), tier-based cost fallback in get_awakening_materials_cost(), static typing throughout, null checks on SystemRegistry, emoji removal, and fixed narrowing conversion warning.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/progression/SacrificeSystem.gd",
    "issue": "XP formulas, tier bonuses, same-element bonuses hardcoded",
    "action": "Created data/sacrifice_config.json with bonuses (same_god_multiplier, same_element_multiplier), base_value_formula (level_xp_multiplier), tier_base_values (5 tiers), high_level_scaling (thresholds with multipliers), xp_curve (base_xp, exponents by level range, high_level_cost_multipliers), sacrifice_value (base_value, xp_per_level, xp_per_tier, awakening_bonus), awakening_ui (min_tier_for_awakening). Updated SacrificeSystem.gd with static config loading, all values from JSON with fallback defaults, static typing throughout, null checks on SystemRegistry. Updated SacrificeManager.gd with config-driven get_god_sacrifice_value() and _can_awaken_god_ui(), replaced hardcoded 40 with God.get_max_level(), added static typing to all variables/params/returns, added -> void return types.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/territory/TerritoryProductionManager.gd",
    "issue": "Production rates, offline cap, efficiency multipliers hardcoded",
    "action": "Created data/territory_config.json with generation_timing (tick_interval_seconds, max_storage_hours, manual_collection_bonus), production_bonuses (upgrade_bonus_per_level, worker_base_bonus, god_level_bonus_per_level), connected_bonuses (2/3/4+ node thresholds), and node_task_mapping. Rewrote TerritoryProductionManager.gd with static config loading (_load_config with cache), 8 static getter methods, all values from JSON with fallback defaults. Updated NodeInfoPanel.gd to use static getters instead of loading nonexistent territory_balance_config.json. Removed dead _load_balance_config() from both files. Added static typing throughout, fixed 3 narrowing conversion warnings. File reduced from 607 to 528 lines.",
    "passes": true
  },
  {
    "priority": "high",
    "file": "scripts/systems/territory/TaskAssignmentManager.gd",
    "issue": "Task durations, reward multipliers, efficiency bonuses hardcoded",
    "action": "Created data/tasks.json with 31 task definitions (all tasks from node_task_mapping) with full rewards, requirements, skill integration. Created data/task_config.json with bonus_formulas (trait/skill duration/reward caps and rates), progress (update_interval_seconds), node_output (base_rates, tier_multipliers, god_level_bonus, affinity_match_multiplier, fallback_spec_bonuses), and node_mappings (task/resource/affinity/relevant_tasks maps). Updated Task.gd with static config loading for all 5 bonus formula values. Updated NodeTaskCalculator.gd to read all constants from config (base_rates, tier_multipliers, god_level_bonus, affinity_multiplier, fallback_spec_bonuses, all node mappings). Updated TaskAssignmentManager.gd to read progress_update_interval from config. Added static typing throughout all modified files.",
    "passes": true
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
    "action": "Replaced hardcoded BASE_XP=100, LEVEL_MULTIPLIER=1.5, MAX_LEVEL=40 constants with static config loading from data/god_config.json (xp_curve.base_xp, xp_curve.level_multiplier, level_cap.max_level). Added static _config cache with _load_config(), _get_base_xp(), _get_level_multiplier(), _get_max_level() methods. Added static typing to all local variables. Changed min/max to minf/maxf/maxi for type safety.",
    "passes": true
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

# Codebase Cleanup Plan

## Overview

Comprehensive cleanup of **195 GDScript files** and **37 scene files**.

**Estimated Impact:**
- Lines to remove: ~1,500-2,000
- Lines to add: ~500-700 (utilities, constants, types)
- Net reduction: ~1,000 lines
- Files to delete: 8-10

---

## Critical Issues (Fix First)

```json
[
  {
    "file": "scenes/NotificationToast.tscn",
    "line": 3,
    "issue": "Script path 'res://scripts/ui/NotificationToast.gd' incorrect - should be 'res://scripts/ui/components/NotificationToast.gd'",
    "action": "Update script path",
    "passes": true
  },
  {
    "file": "scripts/systems/core/ConfigurationManager.gd",
    "line": 46,
    "issue": "References 'territories.json' which does not exist",
    "action": "Updated reference to hex_tiles.json (the actual territory data file)",
    "passes": true
  },
  {
    "file": "scripts/systems/ui/ScreenManager.gd",
    "line": 43,
    "issue": "References 'GodSpecializationScreen.tscn' which does not exist",
    "action": "Created GodSpecializationScreen.tscn and GodSpecializationScreen.gd with full UI (god selector, tree view, detail panel)",
    "passes": true
  },
  {
    "file": "scripts/systems/dungeon/DungeonCoordinator.gd vs DungeonManager.gd",
    "issue": "Team size 5 in Coordinator (line 118) but 4 in Manager (line 271)",
    "action": "Reconcile to single constant",
    "passes": false
  }
]
```

---

## Unused Files to Delete

```json
[
  {
    "file": "scripts/systems/progression/ProgressionCoordinator.gd",
    "issue": "Empty file with no implementation",
    "action": "Delete",
    "passes": false
  },
  {
    "file": "scripts/systems/battle/BattleEffectProcessor.gd",
    "issue": "141 lines never instantiated anywhere",
    "action": "Delete",
    "passes": false
  },
  {
    "file": "scripts/ui/screens/DungeonTab.gd",
    "issue": "Replaced by DungeonScreen.gd",
    "action": "Delete",
    "passes": false
  },
  {
    "file": "data/shop_config.json",
    "issue": "Never loaded by ShopManager",
    "action": "Wire ShopManager to load and use this config",
    "passes": false
  }
]
```

---

## Unused Scenes to Delete

```json
[
  {
    "file": "scenes/LoadingScreen.tscn",
    "issue": "Not referenced anywhere",
    "action": "Delete",
    "passes": false
  },
  {
    "file": "scenes/TerritoryScreen.tscn",
    "issue": "Replaced by HexTerritoryScreen.tscn",
    "action": "Delete",
    "passes": false
  },
  {
    "file": "scenes/TerritoryRoleScreen.tscn",
    "issue": "Not referenced",
    "action": "Delete",
    "passes": false
  },
  {
    "file": "scenes/ui/battle/BattleResultOverlay.tscn",
    "issue": "Not referenced",
    "action": "Delete",
    "passes": false
  },
  {
    "file": "scenes/ui/battle/BattleUnitCard.tscn",
    "issue": "Not referenced",
    "action": "Delete",
    "passes": false
  },
  {
    "file": "scenes/ui/battle/WaveRewardEffect.tscn",
    "issue": "Not referenced",
    "action": "Delete",
    "passes": false
  }
]
```

---

## Dead Code Removal - Core Systems

```json
[
  {
    "file": "scripts/systems/core/EventBus.gd",
    "lines": "51-52, 64-67, 74, 92-96, 118-119, 139-150",
    "issue": "16 signals never emitted, 3 unused functions (set_debug_mode, get_event_history, clear_history)",
    "action": "Remove dead signals and functions",
    "passes": false
  },
  {
    "file": "scripts/systems/core/StatisticsManager.gd",
    "lines": "201-238, 265-283, 312-331",
    "issue": "14 unused achievement functions - KEEP for future achievements",
    "action": "SKIP - keeping for planned achievement system",
    "passes": true
  },
  {
    "file": "scripts/systems/core/GameCoordinator.gd",
    "lines": "269-300, 318-322",
    "issue": "Unused: get_system_by_type(), pause_game(), resume_game(), shutdown_game()",
    "action": "Remove functions",
    "passes": false
  }
]
```

---

## Dead Code Removal - Battle Systems

```json
[
  {
    "file": "scripts/systems/battle/BattleFactory.gd",
    "lines": "16-87",
    "issue": "6 unused methods (create_territory_battle, create_dungeon_battle, create_arena_battle, etc.)",
    "action": "VERIFY first - check if DungeonCoordinator replaced these, then remove if confirmed unused",
    "passes": false
  },
  {
    "file": "scripts/systems/battle/CombatCalculator.gd",
    "lines": "79-93",
    "issue": "_get_element_multiplier() never called",
    "action": "Remove or integrate into calculate_damage()",
    "passes": false
  }
]
```

---

## Dead Code Removal - Collection Systems

```json
[
  {
    "file": "scripts/systems/collection/SummonManager.gd",
    "lines": "29, 448-472, 666-669",
    "issue": "Dead duplicate tracking: _last_summon_duplicates, _get_duplicate_mana_reward(), was_duplicate(), clear_duplicate_tracking(), _is_element_soul()",
    "action": "Remove all duplicate tracking code",
    "passes": false
  }
]
```

---

## Dead Code Removal - Progression Systems

```json
[
  {
    "file": "scripts/systems/progression/AwakeningSystem.gd",
    "lines": "228-279",
    "issue": "4 unused: get_ascension_level_from_string(), get_awakened_abilities(), get_awakened_leader_skill(), get_awakened_passive()",
    "action": "Remove functions",
    "passes": false
  },
  {
    "file": "scripts/systems/progression/GodProgressionManager.gd",
    "lines": "184-188",
    "issue": "_on_god_sacrificed() empty handler",
    "action": "Remove function",
    "passes": false
  },
  {
    "file": "scripts/systems/progression/SacrificeManager.gd",
    "lines": "218-226",
    "issue": "Empty handlers: _on_god_sacrificed(), _on_god_awakened()",
    "action": "Remove functions",
    "passes": false
  }
]
```

---

## Dead Code Removal - Equipment Systems

```json
[
  {
    "file": "scripts/systems/equipment/EquipmentSocketManager.gd",
    "lines": "382-393",
    "issue": "_test_socket_operations() never called",
    "action": "Remove function",
    "passes": false
  },
  {
    "file": "scripts/systems/equipment/EquipmentInventoryManager.gd",
    "lines": "257-271",
    "issue": "_test_inventory_operations() never called",
    "action": "Remove function",
    "passes": false
  },
  {
    "file": "scripts/systems/equipment/EquipmentCraftingManager.gd",
    "lines": "399-406",
    "issue": "_test_crafting_operations() never called",
    "action": "Remove function",
    "passes": false
  }
]
```

---

## Dead Code Removal - Territory Systems

```json
[
  {
    "file": "scripts/systems/territory/TerritoryProductionManager.gd",
    "lines": "73-209",
    "issue": "8+ legacy Territory class functions - old system mixed with hex",
    "action": "Remove all legacy Territory code",
    "passes": false
  },
  {
    "file": "scripts/systems/territory/TerritoryManager.gd",
    "lines": "245-252",
    "issue": "Stub functions always return empty: get_pending_resources(), collect_territory_resources()",
    "action": "Implement or remove",
    "passes": false
  }
]
```

---

## Dead Code Removal - Dungeon Systems

```json
[
  {
    "file": "scripts/systems/dungeon/DungeonCoordinator.gd",
    "lines": "137-138, 299-310",
    "issue": "Unused _dungeon_id, _difficulty variables and functions",
    "action": "Remove dead code",
    "passes": false
  },
  {
    "file": "scripts/systems/dungeon/DungeonManager.gd",
    "lines": "10-11",
    "issue": "Unused signals: dungeon_unlocked, validation_completed",
    "action": "Remove signals",
    "passes": false
  }
]
```

---

## Dead Code Removal - Resource/Shop Systems

```json
[
  {
    "file": "scripts/systems/resources/LootSystem.gd",
    "lines": "5-6, 141-172",
    "issue": "Unused signals (loot_generated, loot_awarded) and functions (generate_battle_rewards, generate_dungeon_rewards, can_roll_loot)",
    "action": "Remove dead code",
    "passes": false
  },
  {
    "file": "scripts/systems/resources/ResourceManager.gd",
    "lines": "150-166, 198-208",
    "issue": "Unused: award_resources(), debug_print_resources(), debug_add_test_resources()",
    "action": "Remove functions",
    "passes": false
  },
  {
    "file": "scripts/systems/shop/ShopManager.gd",
    "lines": "21, 75-81, 198-242",
    "issue": "Unused _event_bus, get_featured_packs(), claim_daily_reward(), skin wrappers",
    "action": "Remove dead code",
    "passes": false
  },
  {
    "file": "scripts/systems/shop/SkinManager.gd",
    "lines": "25-26, 97-107, 163-207",
    "issue": "Unused _collection_manager, _event_bus, and 5+ skin functions",
    "action": "Remove dead code",
    "passes": false
  }
]
```

---

## Dead Code Removal - Utilities

```json
[
  {
    "file": "scripts/utilities/UICardFactory.gd",
    "lines": "78-217",
    "issue": "9+ unused functions (~150 lines): create_equipment_card, create_territory_card, create_compact_god_card, etc.",
    "action": "Remove all unused functions",
    "passes": false
  },
  {
    "file": "scripts/utilities/JSONDataLoader.gd",
    "lines": "40-97",
    "issue": "6 unused: load_files(), load_directory(), validate_data(), clear_cache(), set_cache_enabled(), get_cache_stats()",
    "action": "Remove functions",
    "passes": false
  },
  {
    "file": "scripts/utilities/GodExperienceCalculator.gd",
    "lines": "70-78",
    "issue": "debug_experience_info() never called",
    "action": "Remove function",
    "passes": false
  },
  {
    "file": "scripts/utilities/GodCardFactory.gd",
    "lines": "75-92",
    "issue": "populate_god_grid() never called",
    "action": "Remove function",
    "passes": false
  }
]
```

---

## Dead Code Removal - UI Components

```json
[
  {
    "file": "scripts/ui/components/ResourceDisplay.gd",
    "lines": "789-941",
    "issue": "Entire materials table system (~150 lines) never called",
    "action": "Remove _show_materials_table() and related functions",
    "passes": false
  },
  {
    "file": "scripts/ui/components/DebugOverlay.gd",
    "lines": "11-12, 82-125",
    "issue": "progression_manager and tutorial_manager always null - debug buttons broken",
    "action": "Fix initialization or remove non-functional features",
    "passes": false
  },
  {
    "file": "scripts/ui/components/MainUIOverlay.gd",
    "lines": "182-196, 318-342",
    "issue": "Unused: disconnect_header_back_button(), clear_all_layers(), debug_layer_status()",
    "action": "Remove functions",
    "passes": false
  },
  {
    "file": "scripts/ui/screens/TaskAssignmentScreen.gd",
    "lines": "426-430",
    "issue": "Empty _process() wastes CPU",
    "action": "Remove function",
    "passes": false
  }
]
```

---

## Performance Issue (High Priority)

```json
[
  {
    "file": "scripts/systems/battle/BattleActionProcessor.gd",
    "line": 168,
    "issue": "FileAccess.open() for abilities.json on EVERY skill use",
    "action": "Cache ability data at initialization",
    "passes": false
  }
]
```

---

## Magic Numbers - Game Balance

```json
[
  {
    "file": "scripts/systems/battle/CombatCalculator.gd",
    "lines": "12, 22, 25, 32, 70, 82-91",
    "issue": "Core damage formula: 1000.0, 1140.0, 3.5, glancing 0.15/0.7, variance 0.9-1.1, element 1.3/0.85",
    "action": "Create constants: SW_DAMAGE_NUMERATOR, GLANCING_HIT_CHANCE, etc.",
    "passes": false
  },
  {
    "file": "scripts/systems/battle/TurnManager.gd",
    "lines": "63, 70, 144",
    "issue": "Turn bar speed 0.07, safety counter 1000",
    "action": "Create constants",
    "passes": false
  },
  {
    "file": "scripts/data/God.gd",
    "lines": "27-30, 136, 274",
    "issue": "Default stats 15/50/15/0, max level 40, spec level 20",
    "action": "Create constants",
    "passes": false
  }
]
```

---

## Long Functions to Refactor

```json
[
  {
    "file": "scripts/systems/core/SystemRegistry.gd",
    "lines": "130-273",
    "issue": "register_core_systems() is 144 lines",
    "action": "Split into _register_phase_1(), _register_phase_2(), etc.",
    "passes": false
  },
  {
    "file": "scripts/systems/core/SaveManager.gd",
    "lines": "105-198",
    "issue": "load_game() is 94 lines",
    "action": "Extract helper functions",
    "passes": false
  },
  {
    "file": "scripts/systems/dungeon/DungeonCoordinator.gd",
    "lines": "147-233",
    "issue": "_handle_dungeon_victory() is 87 lines",
    "action": "Extract loot/rewards functions",
    "passes": false
  },
  {
    "file": "scripts/systems/collection/SummonManager.gd",
    "lines": "275-357",
    "issue": "_create_god_of_tier() is 83 lines",
    "action": "Extract filtering and weight calculation",
    "passes": false
  },
  {
    "file": "scripts/ui/components/GodSelectionPanel.gd",
    "lines": "153-263",
    "issue": "create_god_selection_item() is 110 lines",
    "action": "Extract panel/info/stats sections",
    "passes": false
  },
  {
    "file": "scripts/ui/components/ResourceDisplay.gd",
    "lines": "280-406",
    "issue": "_populate_expanded_panel() is 126 lines",
    "action": "Extract category functions",
    "passes": false
  },
  {
    "file": "scripts/ui/components/CraftingUIUtils.gd",
    "lines": "252-383",
    "issue": "create_recipe_card() is 131 lines",
    "action": "Extract header/info/button creation",
    "passes": false
  },
  {
    "file": "scripts/ui/components/ProductionSummaryWidget.gd",
    "lines": "736-856",
    "issue": "_show_craft_popup() is 120 lines",
    "action": "Extract popup/header/grid functions",
    "passes": false
  }
]
```

---

## Code Duplication - Create Utilities

```json
[
  {
    "files": "GodCard.gd, GodCollectionList.gd, GodDetailsPanel.gd, SacrificePanel.gd, SummonShowcase.gd, CollectionDetailsPanel.gd",
    "issue": "Element/tier color/name functions duplicated (~200 lines)",
    "action": "Create UIStyleConstants.gd and GodUIHelpers.gd",
    "passes": false
  },
  {
    "files": "DungeonCoordinator.gd, DungeonManager.gd",
    "issue": "Identical _get_difficulty_reward_multiplier()",
    "action": "Create DungeonConstants.gd",
    "passes": false
  }
]
```

---

## Static Typing - High Priority

```json
[
  {
    "file": "scripts/systems/territory/TerritoryManager.gd",
    "issue": "15+ functions with untyped coord/node parameters",
    "action": "Add HexCoord and HexNode type hints",
    "passes": false
  },
  {
    "file": "scripts/systems/territory/HexGridManager.gd",
    "issue": "10+ functions missing type hints",
    "action": "Add type hints to all functions",
    "passes": false
  },
  {
    "file": "scripts/systems/battle/StatusEffectManager.gd",
    "issue": "7 functions with untyped unit/effect parameters",
    "action": "Add BattleUnit and StatusEffect types",
    "passes": false
  },
  {
    "file": "scripts/systems/battle/BattleActionProcessor.gd",
    "issue": "6 functions with untyped skill/caster/target parameters",
    "action": "Add Skill and BattleUnit types",
    "passes": false
  }
]
```

---

## Static Typing - Data Classes

```json
[
  {
    "file": "scripts/data/ActionResult.gd",
    "lines": "6-7",
    "issue": "Arrays missing types",
    "action": "Add Array[DamageResult], Array[StatusEffect]",
    "passes": false
  },
  {
    "file": "scripts/data/BattleAction.gd",
    "lines": "13-15",
    "issue": "caster, targets, skill missing types",
    "action": "Add BattleUnit, Array[BattleUnit], Skill types",
    "passes": false
  },
  {
    "file": "scripts/data/BattleState.gd",
    "lines": "6-8",
    "issue": "Unit arrays missing typed annotations",
    "action": "Add Array[BattleUnit] types",
    "passes": false
  },
  {
    "file": "scripts/data/God.gd",
    "lines": "37, 42-47, 99",
    "issue": "equipment, ability arrays, status_effects missing types",
    "action": "Add typed arrays",
    "passes": false
  }
]
```

---

## Priority Order

1. **Critical** (4): Broken references, missing files, team size mismatch
2. **High** (~30): Delete unused files, remove dead functions, fix performance, create utilities
3. **Medium** (~40): Static typing, magic numbers, refactor long functions
4. **Low** (~20): Empty handlers, return types, cleanup unused data

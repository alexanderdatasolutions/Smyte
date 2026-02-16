# Game Design Document & System Unification - Activity Log

## Current Status
**Last Updated:** 2026-02-16
**Phase:** Pre-Release Audit Execution
**Current Task:** Executing AUDIT_PLAN.md tasks

---

## 2026-02-16 - Audit: Split TerritoryManager.gd into two files

**Priority:** High (Code Simplification)
**File(s) Modified:** `scripts/systems/territory/TerritoryManager.gd`, `scripts/systems/territory/TerritoryDefenseManager.gd` (new)

**Changes:**
- Split TerritoryManager.gd (831 lines) into two files both under 500 lines:
  - **TerritoryManager.gd** (469 lines): Core territory control, save/load, UI filtering, task integration, capture/lose node, garrison/worker management, node upgrades
  - **TerritoryDefenseManager.gd** (345 lines): Garrison power calculation, defense rating, distance penalty, connected bonuses, attack timer system, capture rewards, node reveal, dungeon completion integration
- TerritoryManager creates TerritoryDefenseManager as a child node in `_ready()` via preload pattern
- All external APIs preserved unchanged via thin delegation methods in TerritoryManager
- Forwarded `node_unlocked` signal from defense manager to territory manager
- Consolidated duplicate SystemRegistry lookups into shared `_get_hex_grid_manager()` and `_get_event_bus()` helpers in both files
- Removed emoji from "Territory Under Attack" notification message

**Verified:** Ran project, no new errors in debug output. All pre-existing warnings/errors unchanged.

---

## 2026-02-16 - Audit: Cache SystemRegistry lookups in AchievementManager

**Priority:** High (Performance + Achievements)
**File(s) Modified:** `scripts/systems/progression/AchievementManager.gd`

**Changes:**
- Added 7 cached system reference member variables (_event_bus, _collection_manager, _statistics_manager, _hex_grid_manager, _resource_manager, _save_manager, _feature_unlock_manager)
- Added `_cache_system_references()` method called from `initialize()` - single point of SystemRegistry access
- Replaced all 23 `SystemRegistry.get_instance().get_system()` calls throughout the file with cached member variable access
- Only 2 SystemRegistry calls remain: one in `_cache_system_references()` itself, one for BuildingManager (one-time signal connection, not cached since only used once)
- Fixed 4 unused parameter warnings: `god` -> `_god`, `god_id` -> `_god_id`, `banner_id` -> `_banner_id`, `results` -> `_results`
- Added typed loop iterators (`for node_id: String`, `for dungeon_id: String`, `for resource_id: String`, `for achievement_id: String`)
- Verified no print statements exist in file (Section 10 medium issue already resolved)

**Verified:** Ran project, no new errors in debug output. All pre-existing warnings/errors unchanged.

---

## 2026-02-16 - Audit: Remove empty stub functions from battle setup files

**Priority:** Medium (Dead Code)
**File(s) Modified:** `scripts/ui/battle_setup/BattleInfoManager.gd`, `scripts/ui/battle_setup/BattleSetupCoordinator.gd`

**Changes:**
- **BattleInfoManager.gd**: Removed dead `update_team_preview(_team: Array)` function - never called anywhere in codebase. Was a stub with just `pass`.
- **BattleSetupCoordinator.gd**: Removed empty `_on_team_changed(_team: Array)` handler (just `pass`) and its signal connection (`team_manager.team_changed.connect(_on_team_changed)`). Stats already update automatically in TeamSelectionManager, making this no-op handler unnecessary.

**Verified:** Ran project, no new errors in debug output. All pre-existing warnings/errors unchanged.

---

## 2026-02-16 - Audit: Extract ArenaManager mock data to ArenaMockData.gd

**Priority:** Medium (Dead Code / Code Simplification)
**File(s) Modified:** `scripts/systems/arena/ArenaManager.gd`, `scripts/systems/arena/ArenaMockData.gd` (new)

**Changes:**
- Created `ArenaMockData.gd` as a static utility class (extends RefCounted) with all mock data generation logic
- Extracted 5 functions (112 lines): `generate_mock_opponents()`, `generate_mock_leaderboard()`, `_generate_mock_defense_team()`, `_get_mock_main_stat()`, `_get_mock_substats()`
- Functions accept `get_league_for_elo` as a Callable parameter to avoid circular dependency
- ArenaManager.gd now uses `preload("res://scripts/systems/arena/ArenaMockData.gd")` pattern (same as ArenaDataSync)
- Thin wrapper functions remain in ArenaManager to handle caching and signal emission
- ArenaManager.gd reduced from 727 to 616 lines

**Verified:** Ran project, no new errors in debug output. All pre-existing warnings/errors unchanged.

---

## 2026-02-16 - Audit: Clean up Equipment.gd dead code and verify NodeProductionInfo.gd

**Priority:** Medium (Dead Code)
**File(s) Modified:** `scripts/data/Equipment.gd`, `scripts/systems/territory/NodeProductionInfo.gd`

**Changes:**
- **Equipment.gd**: Removed `create_test_equipment()` (38 lines) - never called anywhere in codebase, only test factory method. Removed `can_be_enhanced()` alias (3 lines) - duplicate of `can_enhance()`, never called externally. Removed `get_enhancement_success_rate()` alias (3 lines) - duplicate of `get_enhancement_chance()`, never called externally. File reduced from 501 to 457 lines.
- **NodeProductionInfo.gd**: VERIFIED NOT dead code - actively used by NodeInfoPanel.gd (6 method calls at lines 506-515) and registered in SystemRegistry.gd (line 168-170). Removed 1 debug print statement (line 61). Added static typing to 5 local variables (config_path, file, json_text, json, parse_result).

**Verified:** Ran project, no new errors in debug output. All pre-existing warnings/errors unchanged.

---

## 2026-02-16 - Audit: Add missing dungeon waves for 5 pantheon trials

**Priority:** Medium (Core Gameplay Loop)
**File(s) Modified:** `data/dungeon_waves.json`, `scripts/systems/dungeon/DungeonManager.gd`

**Changes:**
- Added wave configurations for 5 missing pantheon trials to `dungeon_waves.json`:
  - **hindu_trials**: Agni/Kali/Surya elites, Shiva Avatar boss (heroic); Agni/Kali/Vishnu/Brahma bosses (legendary)
  - **japanese_trials**: Amaterasu/Susanoo/Tsukuyomi elites, Amaterasu Avatar boss (heroic); Susanoo/Tsukuyomi/Izanagi/Amaterasu bosses (legendary)
  - **celtic_trials**: Ancient Druid/Morrigan/Cernunnos elites, Dagda Avatar boss (heroic); Cernunnos/Morrigan/Lugh/Dagda bosses (legendary)
  - **aztec_trials**: Sun Warrior/Tezcatlipoca/Tlaloc elites, Quetzalcoatl Avatar boss (heroic); Huitzilopochtli/Tezcatlipoca/Tlaloc/Quetzalcoatl bosses (legendary)
  - **slavic_trials**: Perun/Veles/Mokosh elites, Perun Avatar boss (heroic); Perun/Veles/Svarog/Rod bosses (legendary)
- All follow existing pattern: heroic = 3 waves (2 elite + 1 boss), legendary = 4 waves (all bosses)
- Added 5 missing entries to `category_map` in `DungeonManager._get_wave_data()` so wave lookups work
- Previously these dungeons were visible in UI but would start battles with 0 enemies

**Verified:** Ran project, no new errors in debug output. JSON validated.

---

## 2026-02-16 - Audit: Externalize territory production values to territory_config.json

**Priority:** High (Data-Driven JSON Config)
**File(s) Modified:** `data/territory_config.json` (new), `scripts/systems/territory/TerritoryProductionManager.gd`, `scripts/ui/territory/NodeInfoPanel.gd`

**Changes:**
- **Config**: Created `data/territory_config.json` with `generation_timing` (tick_interval_seconds=60, max_storage_hours=12, manual_collection_bonus=1.0), `production_bonuses` (upgrade_bonus_per_level=0.10, worker_base_bonus=0.10, god_level_bonus_per_level=0.01), `connected_bonuses` (2=0.10, 3=0.20, 4=0.30), `node_task_mapping` (8 node types mapped to task categories)
- **TerritoryProductionManager.gd**: Rewrote with static config loading (`_load_config()` with cache), 8 static getter methods (get_tick_interval, get_max_storage_hours, get_manual_collection_bonus, get_upgrade_bonus_per_level, get_worker_base_bonus, get_god_level_bonus_per_level, get_connected_bonuses, get_node_task_mapping). All production rates, bonuses, and mappings now read from JSON with fallback defaults. Removed dead `_load_balance_config()` and `_format_resources_dict()`. Added static typing to all 60+ variables/params/returns. Fixed 3 narrowing conversion warnings (int cast on last_production_time). Changed `min()`/`clamp()` to `minf()`/`clampf()`. File reduced from 607 to 528 lines.
- **NodeInfoPanel.gd**: Replaced 2 `_load_balance_config()` calls with `TerritoryProductionManager.get_max_storage_hours()` and `TerritoryProductionManager.get_manual_collection_bonus()`. Removed dead `_load_balance_config()` function (19 lines). Both files no longer reference nonexistent `territory_balance_config.json`.

**Verified:** Ran project, no new errors. 3 narrowing conversion warnings from TerritoryProductionManager.gd eliminated.

---

## 2026-02-16 - Audit: Externalize sacrifice system values to sacrifice_config.json

**Priority:** High (Data-Driven JSON Config)
**File(s) Modified:** `data/sacrifice_config.json` (new), `scripts/systems/progression/SacrificeSystem.gd`, `scripts/systems/progression/SacrificeManager.gd`

**Changes:**
- **Config**: Created `data/sacrifice_config.json` with `bonuses` (same_god_multiplier=3.0, same_element_multiplier=1.5), `base_value_formula` (level_xp_multiplier=15), `tier_base_values` (common=500, rare=1500, epic=4000, legendary=10000, mythic=500), `high_level_scaling` (thresholds at level 30/35 with multipliers 1.5/1.3), `xp_curve` (base_xp=200, exponents by level range, high_level_cost_multipliers at 35/38), `sacrifice_value` (base_value=100, xp_per_level=50, xp_per_tier=300, awakening_bonus=500), `awakening_ui` (min_tier_for_awakening=4)
- **SacrificeSystem.gd**: Rewrote with static config loading (`_load_config()` with cache), 5 static getter methods for config sections. All XP formulas, tier values, bonuses, and scaling now read from JSON with fallback defaults. Replaced hardcoded max level `40` with `God.get_max_level()`. Added null checks on SystemRegistry/GodProgressionManager in `perform_sacrifice()`. Static typing on all variables/params/returns. Removed `"""` docstrings (bullet character in preview text).
- **SacrificeManager.gd**: Added static config loading for `sacrifice_value` and `awakening_ui` sections. `get_god_sacrifice_value()` now reads base_value/xp_per_level/xp_per_tier/awakening_bonus from config. `_can_awaken_god_ui()` reads min_tier from config and uses `God.get_max_level()` instead of hardcoded 40. Static typing on all 40+ variables/params/returns. Added `-> void` to `_ready()`, `set_temporary_target_god()`. Removed docstring comments.

**Verified:** Ran project, no new errors in debug output. All pre-existing warnings unchanged.

---

## 2026-02-16 - Audit: Externalize awakening system values to awakening_config.json

**Priority:** High (Data-Driven JSON Config)
**File(s) Modified:** `data/awakening_config.json` (new), `scripts/systems/progression/AwakeningSystem.gd`

**Changes:**
- **Config**: Created `data/awakening_config.json` with `requirements` (base_god_level=40, base_god_max_level, all_skills_level_1), `awakened_level_cap` (50), `costs_by_tier` (5 tiers: common through mythic with awakening_stones/mana/divine_essence/ascension_crystal/celestial_essence), `stat_bonuses` (hp/attack/defense/speed percentages), `default_base_stats` (hp=1000, attack=500, defense=400, speed=100), `default_resource_generation` (15)
- **AwakeningSystem.gd**: Rewrote with static config loading (`_load_config()` with cache), 6 static getter methods (`get_required_level()`, `get_awakened_level_cap()`, `get_costs_for_tier()`, `get_stat_bonuses()`, `get_default_base_stats()`, `get_default_resource_generation()`). Config-driven requirements in `can_awaken_god()` with fallback to awakened_gods.json. Tier-based cost fallback in `get_awakening_materials_cost()`. Static typing on all variables/params/returns. Null checks on SystemRegistry. Removed emojis. Fixed narrowing conversion warning (float→int on resource_generation).

**Verified:** Ran project, no new errors in debug output. All pre-existing warnings unchanged.

---

## 2026-02-16 - Audit: Move turn bar constants to battle_config.json

**Priority:** High (Data-Driven JSON Config)
**File(s) Modified:** `data/battle_config.json`, `scripts/systems/battle/TurnManager.gd`, `scripts/data/BattleUnit.gd`, `scripts/systems/battle/BattleActionProcessor.gd`, `scripts/ui/battle/BattleUnitCard.gd`

**Changes:**
- **Config**: Added `turn_system` section to `battle_config.json` with `turn_bar_speed` (0.07), `turn_bar_threshold` (100.0), `max_turn_iterations` (1000), `min_turn_bar_increment` (1.0)
- **TurnManager.gd**: Replaced 3 hardcoded `const` values with instance vars loaded from JSON config. Added static `_load_config()` with cached parse, `_apply_config()` for instance setup, and 3 static getters (`get_turn_bar_speed()`, `get_turn_bar_threshold()`, `get_min_turn_bar_increment()`) for cross-file access. Added `-> void` return types to all 10 functions. Added static typing to `count` var.
- **BattleUnit.gd**: Updated `advance_turn_bar()`, `is_ready_for_turn()`, and `get_turn_progress()` to use `TurnManager.get_turn_bar_speed/threshold/min_increment()` instead of hardcoded 0.07/100.0/1.0. Added `-> void` to advance_turn_bar/reset_turn_bar. Used `maxf()` for type safety.
- **BattleActionProcessor.gd**: Updated ATB steal cap from hardcoded `100` to `TurnManager.get_turn_bar_threshold()`, used `minf()` for type safety.
- **BattleUnitCard.gd**: Updated turn bar `max_value` from hardcoded `100.0` to `TurnManager.get_turn_bar_threshold()`.

**Verified:** Ran project, no new errors in debug output. All pre-existing warnings unchanged.

---

## 2026-02-16 - Audit: Move God constants and XP curve to god_config.json

**Priority:** High (Data-Driven JSON Config)
**File(s) Modified:** `data/god_config.json` (new), `scripts/data/God.gd`, `scripts/utilities/GodExperienceCalculator.gd`, `scripts/systems/arena/ArenaManager.gd`, `scripts/systems/collection/GodFactory.gd`

**Changes:**
- **Config**: Created `data/god_config.json` with `level_cap` (max_level=40, awakened_max_level=50, specialization_unlock_level=20), `default_stats` (crit_rate=15, crit_damage=50, resistance=15, accuracy=0), and `xp_curve` (base_xp=100, level_multiplier=1.5)
- **God.gd**: Added static config cache with `_load_god_config()` and 7 static getter methods (`get_max_level()`, `get_awakened_max_level()`, `get_specialization_unlock_level()`, `get_default_crit_rate/damage/resistance/accuracy()`). Updated `can_level_up()` and `can_specialize()` to use config-driven methods. Kept legacy `const` aliases for `@export` default values.
- **GodExperienceCalculator.gd**: Replaced hardcoded `BASE_XP=100`, `LEVEL_MULTIPLIER=1.5`, `MAX_LEVEL=40` with static config loading from `god_config.json`. Added `_get_base_xp()`, `_get_level_multiplier()`, `_get_max_level()`. Added static typing to all local variables, used `minf/maxf/maxi` for type safety.
- **ArenaManager.gd**: Changed `God.DEFAULT_CRIT_RATE` etc. to `God.get_default_crit_rate()` etc. (4 lines)
- **GodFactory.gd**: Changed `God.DEFAULT_CRIT_RATE` etc. to `God.get_default_crit_rate()` etc. (4 lines)

**Verified:** Ran project, no new errors in debug output. All pre-existing warnings unchanged.

---

## 2026-02-16 - Audit: Externalize equipment enhancement/power values to JSON config

**Priority:** High (Data-Driven JSON Config)
**File(s) Modified:** `data/equipment_config.json`, `scripts/data/Equipment.gd`, `scripts/systems/equipment/EquipmentStatCalculator.gd`

**Changes:**
- **Config**: Added `stat_bonus_percent_per_level: 0.05` and `fallback_success_rate: 5` to enhancement_system section in equipment_config.json
- **Config**: Added `power_calculation` section with `main_stat_weight: 2`, `enhancement_multiplier_per_level: 0.1`, and `rarity_multipliers` (common=1.0 through mythic=3.0)
- **Equipment.gd**: `get_enhancement_stat_bonuses()` now reads bonus percentage from config instead of hardcoded 0.05
- **Equipment.gd**: `get_enhancement_chance()` fallback rate now reads from config instead of hardcoded 0.05
- **EquipmentStatCalculator.gd**: `calculate_equipment_power_rating()` now reads main_stat_weight, enhancement_multiplier_per_level, and rarity_multipliers from config instead of hardcoded values
- **EquipmentStatCalculator.gd**: `_get_set_bonus_effects()` now reads from equipment_sets config instead of hardcoded match statement
- **EquipmentStatCalculator.gd**: `get_enhancement_preview()` now delegates to Equipment's config-driven methods instead of local hardcoded formulas (hardcoded max level 15, base_rate 100, level_penalty 5, base_cost formula all replaced)
- **EquipmentStatCalculator.gd**: `_calculate_main_stat_increase()` reads stat_bonus_percent_per_level from config

**Verified:** Ran project, no new errors in debug output. All pre-existing warnings unchanged.

---

## 2026-02-16 - Audit: Move SummonManager pity/rate values to summon_config.json

**Priority:** High (Data-Driven JSON Config)
**File(s) Modified:** `scripts/systems/collection/SummonManager.gd`, `data/summon_config.json`

**Changes:**
- **BUG FIX**: `_apply_pity_system()` was reading from `config.get("summon_configuration", {}).get("pity_system", {})` — a path that doesn't exist in the current config. Pity system was effectively disabled. Fixed to read from top-level `config.get("pity_system", {})`.
- **BUG FIX**: `summon_basic()` and `summon_premium()` read costs from dead `summon_configuration.costs.premium_summons` path. Fixed to read from `summon_types.mana_summon.cost` and `summon_types.crystal_summon.cost`.
- **BUG FIX**: `_get_summon_rates()` had dead legacy fallback reading from `summon_configuration.rates`. Removed and added proper `mana`, `pantheon`, and `free` summon type lookups.
- **BUG FIX**: `multi_summon_premium()` read from dead `summon_configuration.costs.multi_summons`. Fixed to read from `summon_types.crystal_summon.cost_10x`.
- **Config**: `_get_summon_weights()` read `filtering_weights` from dead `summon_configuration` path. Fixed to read from top-level.
- **Config**: Added `hard_pity.rare: 10` to pity_system in summon_config.json.
- **Config**: Added `multi_summon` section with `discount_multiplier: 0.9` and `guarantee_rare_on_10x: true`.
- **Config**: Added `filtering_weights.element_focus` section with matching/other element weights.
- **Config**: Added `notifications` section with legendary/epic durations.
- Replaced hardcoded `0.9` multi-summon discount with config lookup in both `multi_summon_premium()` and `_perform_multi_summon()`.
- Used `minf()` instead of `min()` for float context in soft pity calculation.

**Verified:** Ran project, no new errors in debug output. All pre-existing warnings unchanged.

---

## 2026-02-16 - Audit: Add null/bounds checks to PvP territory system (5 files)

**Priority:** High (Error Handling)
**File(s) Modified:** `scripts/systems/pvp_territory/PvPTerritoryManager.gd`, `scripts/systems/pvp_territory/PvPMapInstance.gd`, `scripts/systems/pvp_territory/PvPMapGenerator.gd`, `scripts/systems/pvp_territory/PvPSpawnManager.gd`, `scripts/systems/pvp_territory/PvPTerritoryDataSync.gd`

**Changes:**
- **PvPTerritoryManager.gd**: Added `_map_instance` null guards on 6 methods (can_attack_hex, process_attack_result, _trigger_respawn, update_hex_defense, get_attackable_hexes, get_my_hexes_needing_defense). Used `.get()` with defaults for respawn_result dict access instead of direct bracket access.
- **PvPMapInstance.gd**: Added null parameter checks on `update_hex()` and `add_hex()`. Cast `Time.get_unix_time_from_system()` to int in process_capture. Added empty hexes guard before elimination check.
- **PvPMapGenerator.gd**: Added division-by-zero guards with `maxi(1, ...)` in `_calculate_spawn_positions()` and `get_spawn_position_for_player()`. Added empty `ring_coords` early return guards.
- **PvPSpawnManager.gd**: Changed `execute_respawn()` to use `.get()` with defaults for position_result dict access.
- **PvPTerritoryDataSync.gd**: Added null guards on `_firestore` and `collection` at all 10+ Firestore call sites. Used `is Object` check before `has_method()` in `_doc_to_dict()` and `_parse_map_results()`. Safe int casts for `_get_doc_value()` returns that could be null. Early returns with proper signal emissions on failure paths.

**Verified:** Ran project, no new errors in debug output. All pre-existing warnings unchanged.

---

## 2026-02-16 - Audit: Add null checks and static typing to StatusEffect.gd

**Priority:** High (Error Handling)
**File(s) Modified:** `scripts/data/StatusEffect.gd`

**Changes:**
- Added null checks for `SystemRegistry.get_instance()` at all 3 call sites (DOT damage, HOT healing, `_get_attack` helper) — prevents crash if registry unavailable
- Fixed `create_poison()` bug: referenced non-existent `caster.max_health` property, changed to safe `max_hp`/`base_hp` lookup with 1000 fallback
- Fixed `_get_target_name()` to safely check for `display_name` property with `.get()` instead of direct access
- Added `Variant` typing to all 30+ factory method `_caster`/`caster` parameters
- Added `StatusEffect` typing to all `effect` local variables in factory methods
- Added `Dictionary`, `int`, `float` typing to all intermediate variables in `apply_turn_effects()`
- Typed `target` parameter as `Variant` in `apply_turn_effects()` and `_get_target_name()`

**Verified:** Ran project, no new errors in debug output. All pre-existing warnings unchanged.

---

## 2026-02-16 - Audit: Add static typing to God.gd

**Priority:** High (Static Typing)
**File(s) Modified:** `scripts/data/God.gd`, `scripts/utilities/SaveLoadUtility.gd`, `scripts/systems/progression/AwakeningSystem.gd`

**Changes:**
- Typed `skill_levels` as `Array[int]` (was untyped `Array`)
- Fixed `SaveLoadUtility.deserialize_god()` to build a typed `Array[int]` from JSON data instead of using `.duplicate()` which returns untyped
- Fixed `AwakeningSystem` to build typed `Array[int]` when copying skill levels during awakening
- Typed `element_to_string()` parameter as `ElementType` (was untyped)
- Typed `tier_to_string()` parameter as `TierType` (was untyped)
- Typed loop iterator in `has_ability()` as `Dictionary`
- Typed loop iterator in `is_equipped()` as `Variant`
- Updated comments on remaining untyped `@export` arrays (equipment, active_abilities, passive_abilities, abilities) documenting why they stay untyped (JSON deserialization returns untyped Arrays)

**Verified:** Ran project, no new errors in debug output. Initial attempt with `Array[int]` revealed Godot 4.5 doesn't implicitly convert untyped Array to typed on @export assignment — fixed by building typed arrays in deserializers.

---

## 2026-02-16 - Audit: Add static typing to PlayerData.gd

**Priority:** High (Static Typing)
**File(s) Modified:** `scripts/data/PlayerData.gd`

**Changes:**
- Added static types to all 40+ variables, parameters, return types, and loop iterators
- Typed `controlled_territories` as `Array[String]`, `resource_manager` as `Variant`
- Typed all SystemRegistry/ResourceManager locals as `Variant`
- Typed all loop iterators (`currency_id: String`, `material_id: String`, `god: God`, `resource_id: String`, `element: String`)
- Added `-> void` return type to 12 functions (`_init`, `initialize_default_resources`, `create_fallback_resources`, `add_resource`, `add_god`, `remove_god`, `update_energy`, `add_energy`, `control_territory`, `lose_territory_control`, `update_last_save_time`)
- Added `-> Variant` return type to 4 functions (`get_resource_manager`, `get_resource_manager_safe`, `_get_system_registry`, `get_god_by_id`)
- Typed all local variables (`current_amount: int`, `max_storage: int`, `crystal_cost: int`, `energy_gained: int`, `time_passed: float`, etc.)
- Changed `min()` to `mini()` for int contexts (2 locations)
- Fixed over-indentation on `awakening_stones` setter

**Verified:** Ran project, no new errors in debug output. Pre-existing warnings unchanged.

---

## 2026-02-16 - Audit: Add static typing to PvP territory system

**Priority:** High (Static Typing)
**File(s) Modified:** `scripts/systems/pvp_territory/PvPSpawnManager.gd`, `scripts/systems/pvp_territory/PvPTerritoryManager.gd`, `scripts/systems/pvp_territory/PvPMapInstance.gd`, `scripts/systems/pvp_territory/PvPMapGenerator.gd`, `scripts/systems/pvp_territory/PvPTerritoryDataSync.gd`

**Changes:**
- Added static types to 100+ variables, parameters, return types, and loop iterators across all 5 files
- PvPSpawnManager: Typed `best_min_distance`, `min_distance`, `distance` as int
- PvPTerritoryManager: Typed `_get_system_registry() -> Variant`, all system lookups as Variant, hex locals as PvPHexNode, validation/serialized/power vars, lambda god params as Variant
- PvPMapInstance: Typed hex var as Variant, old_hex as PvPHexNode, lambda params (a/b: Dictionary), time vars as int, get_all_players() returns Array[Dictionary]
- PvPMapGenerator: Typed all ring_coords as Array[Vector2i], all node locals as PvPHexNode, names as Array[String], all loop iterators (ring: int, i: int, offset: int), spacing/index/count/score/total as int
- PvPTerritoryDataSync: Typed _firestore as Variant, all 30+ Firestore collection/query/result/doc locals as Variant, all path strings, all hex/map data as Dictionary, all lambda params, removed 4 debug print statements
- Fixed unused parameter warning: `player_uid` -> `_player_uid` in `_get_player_arena_defense()`

**Verified:** Ran project, no new errors in debug output. Pre-existing Firebase signal errors unchanged.

---

## 2026-02-16 - Audit: Move combat formula to battle_config.json

**Priority:** High (Data-Driven JSON Config)
**File(s) Modified:** `scripts/systems/battle/CombatCalculator.gd`, `data/battle_config.json`

**Changes:**
- Replaced placeholder `damage_calculation` section in `battle_config.json` with actual values from CombatCalculator: `damage_formula` (numerator, denominator_base, defense_scale), `hit_types` (glancing_chance, glancing_damage_mult, variance min/max), `element_multipliers` (advantage 1.3, disadvantage 0.85), `stat_scaling` (level_stat_scale 0.1, power_per_level 50, power_per_tier 500)
- Removed all 11 hardcoded `const` values from CombatCalculator.gd
- Added static cached config loading (`_config`, `_config_loaded`, `_ensure_config_loaded()`)
- Added config accessor functions with fallback defaults: `_get_damage_formula()`, `_get_hit_types()`, `_get_element_multipliers()`, `_get_stat_scaling()`
- Updated `calculate_damage()` to read formula/hit values from config
- Updated `_get_element_multiplier()` to read advantage/disadvantage from config
- Updated `get_detailed_*_breakdown()` functions to read level_stat_scale from config
- Updated `calculate_total_power()` to read power_per_level/power_per_tier from config

**Verified:** Ran project, no new errors in debug output. Pre-existing Firebase signal errors unchanged.

---

## 2026-02-16 - Audit: Add null checks to ArenaManager.gd

**Priority:** High (Error Handling)
**File(s) Modified:** `scripts/systems/arena/ArenaManager.gd`

**Changes:**
- Added JSON parse validation with type guard (`parsed is Dictionary`) in `_load_arena_config()`
- Changed 3 `LEAGUE_THRESHOLDS[key]` direct accesses to `.get(key, default)` with fallback values
- Added type check for league colors array before casting (`c_val is Array`)
- Guarded `.find()` result against -1 in `_calculate_pvp_rewards()`
- Added type validation for reward amounts in `_award_rewards()` (checks `is int or is float`)
- Type-checked `get_equipped_items_for_god()` return value before dict iteration
- Validated opponent data per-element in `_on_opponents_fetched()` signal handler
- Added empty-data guard in `deserialize_god_for_battle()` (returns null)
- Added empty opponent guard in `process_battle_result()` (returns early with safe result)
- Added warning for empty `user_id` in `start_pvp_battle()`
- Changed `min()` to `mini()` for int context in mock data generation
- Changed `max(0, ...)` to `maxi(0, ...)` for int context in crystal rewards

**Verified:** Ran project, no new errors in debug output. Pre-existing Firebase signal errors unchanged.

---

## 2026-02-16 - Audit: Add static typing to ArenaDataSync.gd

**Priority:** High
**File(s) Modified:** `scripts/systems/arena/ArenaDataSync.gd`

**Changes:**
- Added static types to all 25+ variables, parameters, return types, and loop iterators
- Typed `_firestore` as `Variant`, all Firestore collection/query/result locals as `Variant`
- Typed all doc iterators as `Variant`, opponents/entries arrays as `Array`, power as `int`, god_data as `Dictionary`
- Added return types: `_get_system_registry() -> Variant`, `_get_doc_value() -> Variant`, `_parse_opponent_results() -> Array`, `_parse_leaderboard_results() -> Array`
- Typed lambda params `(a: Dictionary, b: Dictionary) -> bool` in `sort_custom()`
- Changed `min()` to `mini()` for int context

**Verified:** Ran project, no new errors in debug output. Pre-existing Firebase signal errors unchanged.

---

## 2026-02-16 - Audit: Add static typing to DungeonManager.gd

**Priority:** High
**File(s) Modified:** `scripts/systems/dungeon/DungeonManager.gd`

**Changes:**
- Added static types to all 60+ variables, parameters, return types, and loop iterators
- Typed all local variables: `file: FileAccess`, `json_text: String`, `parse_result: Error`, `dungeon_info: Dictionary`, `difficulty_info: Dictionary`, `category: String`, `element: String`, `multiplier: float`, `loot_system: Node`, etc.
- Typed all loop iterators: `for dungeon_id: String`, `for wave: Dictionary`, `for enemy_def: Dictionary`, `for enemy_type: String`, `for difficulty_name: String`, `for i: int`, etc.
- Added `-> void` return type to 11 functions: `_ready`, `load_dungeon_data`, `_load_fallback_data`, `load_dungeon_waves`, `initialize_player_progress`, `load_progress`, `load_save_data`, `update_clear_count`, `mark_dungeon_cleared`, `increment_daily_completion`, `_enhance_dungeon_info`, `_check_daily_reset`
- Typed `weekdays` as `Array[String]`
- Added null-safe SystemRegistry access in `validate_dungeon_entry()` with `if SystemRegistry.get_instance() else null`

**Verified:** Ran project, no new errors in debug output. Pre-existing Firebase signal errors unchanged.

---

## 2026-02-16 - Audit: Move DungeonManager enemy scaling to battle_config.json

**Priority:** High (Data-Driven Config)
**File(s) Modified:** `scripts/systems/dungeon/DungeonManager.gd`, `data/battle_config.json`

**Changes:**
- Added `enemy_scaling` section to `data/battle_config.json` with: base_stats (hp/attack/defense/speed), tier_multipliers (basic/leader/elite/boss), level_scaling_per_level, speed_per_level, category_base_power (elemental/pantheon/equipment/special), difficulty_multipliers (beginner through legendary), power_level_base, power_level_scaling
- Added `_enemy_scaling: Dictionary` member variable to DungeonManager
- Added `_load_enemy_scaling_config()` to load from battle_config.json on _ready()
- Refactored `_calculate_enemy_stats()` to read base stats, tier multipliers, and level scaling from config with fallback defaults
- Refactored `_calculate_enemy_power()` to read category base powers, difficulty multipliers, and level scaling from config with fallback defaults
- Also marked ArenaManager ELO config task as already completed (arena_config.json + _load_arena_config() already existed)

**Verified:** Ran project, no new errors in debug output. Pre-existing Firebase signal errors unchanged.

---

## 2026-02-16 - Audit: Add static typing to ArenaManager.gd

**Priority:** High
**File(s) Modified:** `scripts/systems/arena/ArenaManager.gd`

**Changes:**
- Typed member variables: `defense_team` as `Array[God]`, `cached_opponents` as `Array[Dictionary]`, `_data_sync` as `Node`
- Added `-> Node` return type to `_get_system_registry()`, typed its local `registry_script` as `GDScript`
- Typed all local variables in `process_battle_result()`: `opponent_elo: int`, `elo_change: int`, `old_elo: int`, `old_league: String`, `registry: Node`, `event_bus: Node`, `direction: String`, `rewards: Dictionary`, `result: Dictionary`
- Typed `_calculate_elo_change()` locals: `expected: float`, `actual: float`, `k_factor: int`, `change: int`
- Typed `_calculate_pvp_rewards()` locals: `league_index: int`
- Typed `_award_rewards()` locals: `system_registry: Node`, `resource_manager: Node`
- Changed `_serialize_defense_team()` signature to `Array[God] -> Array[Dictionary]`, typed `serialized`
- Typed `_serialize_god_for_pvp()` locals: `system_registry: Node`, `equipment_manager: Node`, `equipped: Dictionary`, `god_equipment: Dictionary`, `eq: Equipment`
- Typed `deserialize_god_for_battle()` locals: `god: God`, `traits_data: Array`, `spec_data: Array`, `equipment_data: Dictionary`, `eq_data: Dictionary`
- Typed `_apply_equipment_stats_to_god()` locals: `main_stat: String`, `main_value: int`, `substats: Array`
- Typed all mock data generation: `Array[String]`, `Array[Dictionary]`, `Array[int]` for all local arrays
- Typed all loop iterators: `for god: God`, `for resource_id: String`, `for slot_key: String`, `for league: String`, `for i: int`, etc.
- Changed `_generate_mock_defense_team()` return to `Array[Dictionary]`, `_get_mock_substats()` to `Array[Dictionary]`
- Replaced `if _data_sync and` with `if _data_sync != null and` (5 occurrences)
- Replaced `SystemRegistry.get_instance()` direct call with `_get_system_registry()` helper in `process_battle_result()`
- Typed `restore_defense_team_from_ids()` locals: `system_registry: Node`, `collection_manager: Node`, `god: God`
- Typed `load_save_data()` locals: `loaded_ids: Array`, `id: Variant`

**Verified:** Ran project, no new errors in debug output. Pre-existing Firebase signal errors unchanged.

---

## 2026-02-16 - Audit: Add static typing to FirebaseIntegration.gd

**Priority:** High
**File(s) Modified:** `scripts/systems/firebase/FirebaseIntegration.gd`

**Changes:**
- Added `-> void` return types to 30+ functions (initialize, _setup_firebase, _connect_event_bus, all signal handlers, auth methods, cloud save methods, shutdown, etc.)
- Added `-> Node` return type to `_get_firebase()`
- Typed member variable `_event_bus` as `Node`
- Typed all local `firebase` variables as `Node`
- Typed `auth_result` and `auth_data` signal handler params as `Dictionary`
- Typed `_on_login_failed` params as `Variant` (Firebase can send various types)
- Typed EventBus signal handler params: `result`, `god`, `territory`, `equipment` as `Variant` (polymorphic from EventBus)
- Typed `rewards` default param as `Variant`, `context` default param as `Variant`
- Typed all local String variables: `provider`, `error_str`, `tier_str`, `element_str`, `territory_id`, `source`
- Typed `now` as `float`, `rewards_dict`/`context_dict` as `Dictionary`
- Typed `system_registry_script` as `GDScript`, `registry` as `Node`
- Typed `google_provider` as `Variant`
- Typed lambda parameters in `_connect_cloud_save_signals()` with proper types and `-> void`
- Removed stale debug comment in `_restore_session()`

**Verified:** Ran project, no new errors in debug output. Pre-existing "signal already connected" errors in _setup_firebase unchanged.

---

## 2026-02-16 - Audit: Move dungeon energy costs to data-driven JSON

**Priority:** High (Data-Driven Config)
**File(s) Modified:** `scripts/systems/dungeon/DungeonCoordinator.gd`, `scripts/ui/components/DungeonEntryManager.gd`

**Changes:**
- Replaced hardcoded energy cost dictionary in `DungeonCoordinator._get_energy_cost()` with lookup from DungeonManager (reads from dungeons.json)
- Replaced hardcoded base_cost/match-based energy cost in `DungeonEntryManager.get_energy_cost()` with same DungeonManager lookup
- Both functions previously ignored the dungeon_id parameter and used wrong difficulty names (easy/normal/hard/hell vs actual beginner/intermediate/advanced/expert)
- Removed 4 debug print statements from DungeonCoordinator.gd (lines 157, 180, 186, 192)
- Added static typing to all untyped variables (12+ vars) and `-> void` return types to 7 functions
- Energy costs are already defined per-dungeon per-difficulty in dungeons.json (6-18 range) - no JSON changes needed

**Verified:** Ran project, no errors in debug output

---

## 2026-02-16 - Audit: Add static typing to SummonManager.gd

**Priority:** High
**File(s) Modified:** `scripts/systems/collection/SummonManager.gd`

**Changes:**
- Added static types to all 70+ variables, parameters, return types, and loop iterators
- Typed 3 signal declarations (summon_completed, summon_failed, multi_summon_completed)
- Added `-> void` return types to 9 functions missing them (_load_config, _spend_cost, _update_pity_counters, _add_to_history, _check_milestone_rewards, _award_milestone, _check_legendary_notification, load_save_data, _ready)
- Cached SystemRegistry.get_instance() into local `registry: SystemRegistry` variable in 8 functions to avoid repeated calls
- Typed all Dictionary, Array, String, int, float, bool, God, Node, PackedStringArray locals
- Typed all `for` loop variables (String, int, Dictionary, God)

**Verified:** Ran project, no errors in debug output. Only pre-existing warnings remain.

---

## 2026-02-16 - Audit: Remove dead code from SystemRegistry.gd

**Priority:** High
**File(s) Modified:** `scripts/systems/core/SystemRegistry.gd`

**Changes:**
- Removed `get_system_by_type()` (9 lines) - never called anywhere in codebase
- Removed `shutdown_all_systems()` (9 lines) - never called anywhere in codebase
- Confirmed `remove_system()` is NOT dead (called by `register_system()` line 31)
- Added `-> void` return types to `_init()`, `register_system()`, `initialize_all_systems()`
- Added static typing to local variables in `remove_system()`, `get_debug_info()`, `initialize_all_systems()`
- File reduced from 282 to 262 lines

**Verified:** Ran project, no errors in debug output

---

## 2026-02-16 - Audit: Remove dead signals and event history from EventBus.gd

**Priority:** High
**File(s) Modified:** `scripts/systems/core/EventBus.gd`

**Changes:**
- Removed 4 dead signals: `game_paused`, `game_resumed`, `settings_changed`, `popup_requested` (all 0 emitters/connectors)
- Removed dead event history system: `_event_history`, `_max_history_size`, `_debug_mode` vars and `_log_event()` function (`_debug_mode` always false, never set)
- Simplified `emit_notification()` to directly emit signal without dead `_log_event()` call
- Added `-> void` return type to `emit_notification()`
- File reduced from 140 to 106 lines
- Also updated AUDIT_PLAN.md to mark 22 previously-completed tasks (SummonManager dead code, ConfigurationManager dead code, all 19 debug print tasks) as passes: true

**Verified:** Ran project, no errors in debug output

---

## 2026-02-16 - Audit: Remove dead code from InventoryManager.gd

**Priority:** High
**File(s) Modified:** `scripts/systems/collection/InventoryManager.gd`

**Changes:**
- Removed `quest_items` Dictionary and all references (no quest system exists in game)
- Removed `item_consumed` signal (never emitted, never connected - completely dead)
- Removed `inventory_updated` signal (emitted but never connected by any listener)
- Simplified `add_item()`/`remove_item()` match blocks (removed quest_item branches)
- Removed quest_items from `get_item_count()`, `get_save_data()`, `load_save_data()`
- `get_all_consumables()`/`get_all_materials()` noted in audit already didn't exist
- File reduced from 112 to 93 lines

**Verified:** Ran project, no errors in debug output

---

## 2026-02-16 - Audit: Remove incomplete features from UIManager.gd

**Priority:** High
**File(s) Modified:** `scripts/systems/ui/UIManager.gd`, `scripts/ui/sacrifice/SacrificeSelectionScreen.gd`

**Changes:**
- Removed 7 incomplete/stub features from UIManager.gd:
  - `notification_scene` and `reward_scene` (never-set TODO vars)
  - `show_notification()` (empty TODO body - notifications handled by NotificationManager)
  - `_highlight_ui_element()` (empty TODO body)
  - `_apply_popup_style()` (all branches were `pass`)
  - `_play_popup_sound()` (empty TODO body)
  - `debug_show_test_popup()` and `get_debug_info()` (debug/test code)
  - `audio_manager` var (never used)
- Removed dead `ui_manager: UIManager` reference from SacrificeSelectionScreen.gd (UIManager not registered in SystemRegistry)
- WaveManager.gd: Verified 4/5 dead functions already removed in prior audit; `get_wave_count()` has 3+ active callers - NOT dead
- UIManager reduced from 389 to 218 lines

**Verified:** Ran project, no errors in debug output

---

## 2026-02-16 - Audit: Remove dead code from CombatCalculator.gd

**Priority:** High
**File(s) Modified:** `scripts/systems/battle/CombatCalculator.gd`

**Changes:**
- Removed dead function `calculate_total_stats()` (22 lines) - 0 external callers
- Removed dead function `calculate_healing()` (9 lines) - 0 external callers
- Removed orphaned `HEAL_VARIANCE_MIN`/`HEAL_VARIANCE_MAX` constants (only used by calculate_healing)
- File reduced from 219 to 182 lines
- Verified `get_detailed_*_breakdown()` functions are NOT dead (called by BattleUnit.gd)

**Verified:** Ran project, no errors in debug output

---

## 2026-02-16: Pre-Release Audit — Task 1

### Wire TowerManager into SaveManager save chain (Critical)
**Files modified:** `scripts/systems/tower/TowerManager.gd`, `scripts/systems/core/SaveManager.gd`

**Problem:** TowerManager used `set_player_value()` / `get_player_value()` hack to stash best_floor inside the player_data bag, bypassing the proper save chain pattern used by all other systems.

**Fix:**
- Replaced `_load_best_floor()` / `_save_best_floor()` with standard `get_save_data()` / `load_save_data()` methods on TowerManager
- Added TowerManager to SaveManager save chain (writes `save_data["tower"]`)
- Added TowerManager to SaveManager load chain via `_load_system_data()`
- Added legacy migration: if old save has `tower_best_floor` in `player_data`, it gets promoted to top-level `tower` section
- Bumped SAVE_VERSION from "1.1" to "1.2" with proper `_migrate_1_1_to_1_2()` function
- Added "tower" to save data validation section list
- Changed `end_tower_run()` to emit `EventBus.save_requested` signal instead of calling `_save_best_floor()` directly

**Verification:** Project runs clean, no errors related to save system changes

### Wire InventoryManager into SaveManager (Critical)
**Files modified:** `scripts/systems/collection/InventoryManager.gd`, `scripts/systems/core/SaveManager.gd`

**Problem:** InventoryManager had `save_inventory_data()`/`load_inventory_data()` methods (non-standard names) that were never called by SaveManager. Consumables, materials, and quest items were not being persisted.

**Fix:**
- Renamed methods to standard `get_save_data()` / `load_save_data()` pattern
- Added InventoryManager to SaveManager save chain (writes `save_data["inventory"]`)
- Added InventoryManager to SaveManager load chain via `_load_system_data()`
- Added "inventory" to save data validation section list

**Verification:** Project runs clean, no errors

### Remove dead code from ArenaManager.gd (High)
**Files modified:** `scripts/systems/arena/ArenaManager.gd`
**Removed:** `get_cached_opponents()`, `get_battle_rewards_preview()` — 0 external callers each.
**Note:** Mock generation functions (`_generate_mock_opponents`, etc.) are NOT dead — they're used as Firebase fallbacks.
**Verification:** Project runs clean

### Remove dead save stubs from LootSystem (Critical → resolved)
**Files modified:** `scripts/systems/resources/LootSystem.gd`

**Problem:** Audit flagged LootSystem as having orphaned `get_save_data()`/`load_save_data()` methods not wired into SaveManager. On inspection, both methods were no-ops — `get_save_data()` returned `{}` and `load_save_data()` was `pass`. LootSystem loads its config from JSON files, not from save data.

**Fix:** Removed the dead save/load stubs entirely. No need to wire empty methods into the save chain.

**Verification:** Project runs clean, no errors

### Remove dead code from BattleCoordinator.gd (High)
**Files modified:** `scripts/systems/battle/BattleCoordinator.gd`
**Removed:** `get_battle_state()` — 0 external callers.
**Verification:** Project runs clean

### Remove dead code from WaveManager.gd (High)
**Files modified:** `scripts/systems/battle/WaveManager.gd`
**Removed:** `get_current_wave()`, `is_final_wave()`, `get_current_wave_enemies()`, `get_next_wave_enemies()` — all 0 external callers.
**Kept:** `get_wave_count()` — called by BattleScreen.gd.
**Verification:** Project runs clean

### Remove dead code from InventoryManager.gd (High)
**Files modified:** `scripts/systems/collection/InventoryManager.gd`
**Removed:** `use_consumable()`, `_apply_consumable_effect()`, `add_loot_items()`, `get_all_consumables()`, `get_all_materials()` — all 0 external callers.
**Verification:** Project runs clean

### Remove dead summon functions from SummonManager.gd (High)
**Files modified:** `scripts/systems/collection/SummonManager.gd`
**Removed:** `summon_with_element_soul()`, `summon_with_powder()`, `summon_basic_with_powder()`, `get_powder_cost()`, `get_powder_weight_multiplier()`, `can_afford_powder_summon()`, `grant_element_favor()`, `get_element_favor_status()`, `_format_time_remaining()`, `can_use_weekly_premium_summon()`, `summon_multi_with_soul()` — all 0 external callers.
**Kept:** `summon_premium_with_powder()`, `summon_with_pantheon_token()` — called by SummonScreen.gd.
**Verification:** Project runs clean

### Remove dead functions from ConfigurationManager.gd (High)
**Files modified:** `scripts/systems/core/ConfigurationManager.gd`
**Removed:** `get_pantheons_config()`, `is_pantheon_enabled()`, `is_configuration_loaded()`, `reload_configurations()` — all 0 external callers.
**Verification:** Project runs clean

### Remove dead functions from EventBus.gd (High)
**Files modified:** `scripts/systems/core/EventBus.gd`
**Removed:** `emit_resource_change()`, `emit_battle_ended()` — 0 external callers.
**Kept:** `emit_notification()` — used by multiple systems.
**Verification:** Project runs clean

### Remove dead function from SaveManager.gd (High)
**Files modified:** `scripts/systems/core/SaveManager.gd`
**Removed:** `get_save_info()` — 0 external callers.
**Verification:** Project runs clean

### Debug Print Cleanup — All System Files (High)
**Files modified:** 17 system files across battle, territory, core, collection, firebase, progression, tower, tasks, specialization, dungeon, arena subsystems.

**Summary of removals:**
- **TerritoryManager.gd:** 21 prints + 3 orphaned multi-line remnants
- **BattleCoordinator.gd:** 31 prints, fixed 2 empty else blocks
- **SaveManager.gd:** 38 prints, simplified hex_grid loading, removed dead `_format_rewards_dict()`
- **HexGridManager.gd:** 12 prints, removed orphaned vars (`matched_count`, `player_nodes_loaded`, `newly_revealed`, `hex_coord_script`)
- **TerritoryProductionManager.gd:** 16 prints, removed orphaned vars (`coord_str` x4, `was_capped`, `bonus_percent`)
- **GameCoordinator.gd:** 9 prints
- **CollectionManager.gd:** 14 prints
- **TurnManager.gd:** 13 prints, removed orphaned vars (`effect_results`, `reason`)
- **BattleActionProcessor.gd:** 8 prints
- **FirebaseIntegration.gd:** 10 prints, added `pass` for side-effect `check_auth_file()` block
- **DungeonManager.gd:** 5 prints
- **AchievementManager.gd:** 8 prints
- **TowerManager.gd:** 5 prints
- **TaskAssignmentManager.gd:** 1 print
- **SpecializationManager.gd:** 1 print
- **NodeRequirementChecker.gd:** 5 prints
- **ArenaDataSync.gd:** 6 prints

**Total:** ~203 print statements removed from system files, plus orphaned variables and empty blocks cleaned up.
**Verification:** Project runs clean, no parse errors

### Debug Print Cleanup — UI Files + Data Classes (High)
**Files modified:** 43 UI files + 2 data files (45 total).

**Summary:** Removed 316 print statements across all UI and data files using multi-line-aware parser. Key files: BattleScreen(56), BattleUnitCard(29), HexTerritoryScreen(25), GodDetailsPanel(20), CollectionScreenCoordinator(18), NodeInfoPanel(18), TerritoryActionsManager(16), GodCollectionList(11), WorldView(10), EquipmentInventoryManager(10), CollectionFilterPanel(9), and 34 smaller files.

**Verification:** Project runs clean, no parse errors

---

## Project Context

This planning phase creates a comprehensive Game Design Document that maps ALL game systems end-to-end. The goal is to understand:
- What connects to what?
- What materials are for?
- Which gods are good for which tasks?
- What the actual gameplay loop is?
- What's implemented vs what's missing?
- Which systems are visible to players vs hidden in backend?

**The Core Loop (Intended):**
1. Acquire god (summoning)
2. Use god in battle (node capture, dungeons, PvP)
3. Gain rewards (resources, materials)
4. Spend rewards on:
   - Summon more gods
   - Sacrifice to level up and awaken gods
   - Craft equipment to equip to gods
   - Specialize gods into roles
5. Capture more nodes → get more passive resources → loop

**Problem:** We have many backend systems but don't know how they connect or what's visible to players.

---

## Session Log

### 2026-01-18 23:45 - Created Ralph Plan Mode Prompt for GDD Generation

**Task:** Create comprehensive system audit plan following ralph_wiggum_guide.md

**What Was Done:**
1. Created new `PROMPT_plan.md` for comprehensive GDD generation
2. Instructed Ralph to use 500 parallel Sonnet subagents for codebase analysis
3. Defined 12-section Game Design Document structure:
   - Executive Summary
   - Resource Economy (all 49 resources mapped)
   - God Progression System
   - Territory/Hex Node System
   - Dungeon System
   - Battle System
   - Crafting System
   - Playstyle Archetypes
   - UI/UX Audit
   - System Integration Map
   - Missing Pieces
   - Code Quality Audit
4. Defined key questions to answer for each system
5. ~~Created sample plan.md structure with 5 initial UI/integration tasks~~ (REMOVED - Ralph should create this)

**Files Modified:**
- `PROMPT_plan.md` - Created comprehensive audit prompt (corrected to let Ralph create plan)
- `activity.md` - This file, updated for new planning phase

### 2026-01-18 (Later) - Updated Ralph Prompts to Match ralph_wiggum_guide.md Pattern

**Task:** Align Ralph prompts with the baseline pattern from ralph_wiggum_guide.md

**What Was Done:**
1. **Completely rewrote `PROMPT_plan.md`** to match ralph_wiggum_guide.md pattern:
   - Added Step 0a-0d: Study specs/docs, IMPLEMENTATION_PLAN.md, entire codebase with 500 agents
   - Changed Step 1: Use Opus subagent with ultrathink for comprehensive analysis
   - Changed Step 2: Create `IMPLEMENTATION_PLAN.md` (not `plan.md`) with checkbox format (not JSON)
   - Changed completion promise to `<promise>PLAN_COMPLETE</promise>`
   - Added Obsidian documentation requirements (wiki-links, frontmatter, MOCs)
   - Added expectation to create both `GAME_DESIGN_DOCUMENT.md` AND `IMPLEMENTATION_PLAN.md`

2. **Completely rewrote `PROMPT_build.md`** to match ralph_wiggum_guide.md pattern:
   - Added Step 0a-0c: Study docs, IMPLEMENTATION_PLAN.md, relevant scripts with agents
   - Changed Step 1: Choose task from `IMPLEMENTATION_PLAN.md` (not `plan.md`)
   - Added detailed instructions for Documentation Tasks (Obsidian format, wiki-links, MOCs)
   - Added detailed instructions for UI/UX Tasks (with Godot MCP tools)
   - Added detailed instructions for Code Cleanup Tasks (static typing, constants, refactoring)
   - Added Step 2: Validate work (docs and code separately)
   - Added Step 3: Update `IMPLEMENTATION_PLAN.md` with discoveries
   - Added Step 4: Log in activity.md and commit
   - Added all 14 "Important Rules" from ralph_wiggum_guide.md
   - Changed completion promise to `<promise>COMPLETE</promise>`

**Files Modified:**
- `PROMPT_plan.md` - Completely rewritten (148 lines → matches baseline pattern)
- `PROMPT_build.md` - Completely rewritten (54 lines → 220 lines, matches baseline pattern)
- `activity.md` - This file, documenting the alignment

**Key Changes:**
- Now uses `IMPLEMENTATION_PLAN.md` with checkbox tasks instead of `plan.md` with JSON
- Documentation must be Obsidian format with `[[wiki-links]]`, frontmatter, MOCs
- Every doc must link to at least 2 other docs
- Added emphasis on static typing for all GDScript
- Added signal flow documentation requirements
- Added JSON schema documentation requirements
- Ralph will create BOTH the GDD AND the implementation plan in plan mode

**Systems to Analyze:**
- Core: SystemRegistry, SaveManager, ResourceManager, GameCoordinator
- Collection: GodManager, SummoningManager, TeamManager
- Battle: BattleManager, DamageCalculator
- Progression: AwakeningManager, LevelingManager, SpecializationManager
- Equipment: EquipmentManager, EquipmentCraftingManager
- Territory: TerritoryManager, TaskAssignmentManager, TerritoryProductionManager, HexGridManager
- Dungeon: DungeonManager, DungeonRewardCalculator, DungeonDifficultyManager
- Resources: ResourceManager
- All UI screens and components
- All JSON configs (49 resources, recipes, dungeons, nodes, gods, etc.)

**Expected Deliverables from Ralph:**
1. `docs/GAME_DESIGN_DOCUMENT.md` (100+ pages)
   - Complete resource economy map (all 49 resources)
   - Full god progression documentation
   - All formulas and calculations documented
   - All systems documented end-to-end
   - All missing pieces identified
   - UI/UX visibility audit
   - System integration map
   - Priority-ordered implementation tasks

2. `plan.md` - Task list for:
   - Building missing UI (Crafting Screen, Recipe Book, Tooltips)
   - Connecting isolated systems (Dungeons → Crafting, Nodes → Resources)
   - Adding visibility features (Efficiency %, Resource purposes)
   - Creating feedback loops (Progression guide, Tutorials)

**Key Questions Ralph Will Answer:**
- What are ALL 49 resources used for?
- Where do resources come from and where do they go?
- How does god progression work (leveling, awakening, specialization)?
- What equipment exists? Is crafting UI built?
- Which gods are good for which nodes (efficiency bonuses)?
- What dungeons exist and what do they reward?
- How does combat work?
- Can you play as gatherer, warrior, or crafter?
- Which systems have UI and which are backend-only?
- What's the actual gameplay loop vs intended loop?

**Analysis Depth:**
- 500 parallel Sonnet subagents reading every file
- 50 parallel Opus subagents synthesizing findings
- Deep code analysis (formulas, signals, connections)
- Complete JSON config parsing
- UI/UX audit (visible vs hidden)
- System integration mapping

**Status:** Ready to run `./ralph.sh plan 5` for comprehensive audit

**Next Step:** Run Ralph in plan mode to create the Game Design Document

---

<!-- Ralph will append audit completion entries below -->

### 2026-02-12 - Cleanup: Fix NotificationToast.tscn script path

**File(s) Modified:** `scenes/NotificationToast.tscn`, `scripts/ui/components/NotificationToast.gd`

**Changes:**
- Fixed script path from `res://scripts/ui/NotificationToast.gd` to `res://scripts/ui/components/NotificationToast.gd`
- Updated UID from `uid://bq3xspq0mdcts` to `uid://gxpv3yh3l120` (correct UID for the actual file)
- Fixed comment in NotificationToast.gd to reflect correct path

**Verified:** Ran project, no errors related to NotificationToast in debug output

**Commit:** `cleanup: fix broken script path in NotificationToast.tscn`

### 2026-02-12 - Cleanup: Fix broken territories.json reference in ConfigurationManager

**File(s) Modified:** `scripts/systems/core/ConfigurationManager.gd`

**Changes:**
- Changed `_load_territories_config()` to load `res://data/hex_tiles.json` instead of non-existent `res://data/territories.json`
- `hex_tiles.json` is the actual territory/hex data file containing blank tiles and special nodes
- Updated comment to reflect it loads hex tiles data

**Verified:** Ran project, no errors. The "Could not open territories.json" warning is now gone. Territory production, hex grid, and save loading all work correctly.

**Commit:** `cleanup: fix broken territories.json reference in ConfigurationManager`

### 2026-02-12 - Cleanup: Create missing GodSpecializationScreen

**File(s) Modified:**
- `scripts/ui/screens/GodSpecializationScreen.gd` (NEW - 415 lines)
- `scenes/GodSpecializationScreen.tscn` (NEW)

**Changes:**
- Created `GodSpecializationScreen.gd` - Full specialization tree screen with 3-panel layout:
  - Left: God selector grid (3 columns, scrollable, shows name/level/role)
  - Center: SpecializationTree component (role tabs, tree visualization)
  - Right: Detail panel (spec name, description, requirements, bonuses, unlock button)
- Created `scenes/GodSpecializationScreen.tscn` - Minimal scene (matches CollectionScreen pattern)
- Follows established patterns: SystemRegistry, unified header, dark purple color palette
- Resolves ScreenManager.gd line 45 reference to non-existent `GodSpecializationScreen.tscn`
- WorldView "Specialization" button now navigates to a working screen

**Verified:** Ran project, navigated to specialization screen via TestHarness. Screen loads with all 43 gods displayed, no errors in debug output.

**Commit:** `cleanup: create missing GodSpecializationScreen scene and script`

### 2026-02-12 - Cleanup: Fix team size mismatch in dungeon systems

**File(s) Modified:** `scripts/systems/dungeon/DungeonCoordinator.gd`, `scripts/systems/dungeon/DungeonManager.gd`

**Changes:**
- DungeonCoordinator.gd allowed team size of 5, DungeonManager.gd allowed 4 — UI (TeamSelectionManager) enforces 4
- Added `const MAX_TEAM_SIZE: int = 4` to both DungeonCoordinator.gd and DungeonManager.gd
- Updated validation in both files to use the constant instead of magic numbers
- Both files now consistently enforce max team size of 4

**Verified:** Ran project, no errors in debug output. No new warnings or errors introduced.

**Commit:** `cleanup: fix team size mismatch in dungeon systems`

### 2026-02-12 - Cleanup: Delete empty ProgressionCoordinator.gd

**File(s) Modified:** `scripts/systems/progression/ProgressionCoordinator.gd` (DELETED)

**Changes:**
- Deleted empty file `ProgressionCoordinator.gd` — contained no implementation (1 blank line)
- Verified no code references exist (only mentioned in docs/analysis and CLEANUP_PLAN.md)

**Verified:** Ran project, no errors in debug output

**Commit:** `cleanup: delete unused empty ProgressionCoordinator.gd`

### 2026-02-12 - Cleanup: Delete unused BattleEffectProcessor.gd

**File(s) Modified:** `scripts/systems/battle/BattleEffectProcessor.gd` (DELETED)

**Changes:**
- Deleted unused `BattleEffectProcessor.gd` (141 lines) — never instantiated or referenced by any code
- Only references were in documentation files (docs/analysis/03_battle.md, docs/MOCs/GameSystems.md)
- File had known issues: used deprecated emit_signal() pattern, tried to get static CombatCalculator from SystemRegistry

**Verified:** Ran project, no errors in debug output

**Commit:** `cleanup: delete unused BattleEffectProcessor.gd`

### 2026-02-12 - Cleanup: Delete unused DungeonTab.gd

**File(s) Modified:** `scripts/ui/screens/DungeonTab.gd` (DELETED)

**Changes:**
- Deleted unused `DungeonTab.gd` (278 lines) — replaced by `DungeonScreen.gd`
- Verified no code references exist (only mentioned in docs/analysis/10_ui_screens.md)
- No scene files reference this script

**Verified:** Ran project, no errors in debug output

**Commit:** `cleanup: delete unused DungeonTab.gd`

### 2026-02-12 - Cleanup: Delete unused scenes and scripts

**File(s) Deleted:**
- `scenes/LoadingScreen.tscn` + `scripts/ui/screens/LoadingScreen.gd` — not referenced anywhere
- `scenes/TerritoryScreen.tscn` + `scripts/ui/screens/TerritoryScreen.gd` — replaced by HexTerritoryScreen
- `scenes/TerritoryRoleScreen.tscn` + `scripts/ui/screens/TerritoryRoleScreen.gd` — not referenced anywhere

**False Positives Corrected:**
- `scenes/ui/battle/BattleResultOverlay.tscn` — actively used by BattleScreen.gd (preloaded)
- `scenes/ui/battle/BattleUnitCard.tscn` — actively used by BattleScreen.gd (preloaded)
- `scenes/ui/battle/WaveRewardEffect.tscn` — actively used by BattleScreen.gd (preloaded)

**Also Updated:**
- `data/shop_config.json` — marked as SKIP (future daily/guild shop feature, not dead code)

**Verified:** Ran project, no errors in debug output. No new warnings introduced.

**Commit:** `cleanup: delete unused scenes and scripts`

### 2026-02-12 - Cleanup: Remove dead signals and functions from EventBus.gd

**File(s) Modified:** `scripts/systems/core/EventBus.gd`

**Changes:**
- Removed 14 unused signals: territory_attacked, territory_defended, role_assigned, role_unassigned, quest_started, quest_completed, quest_progress_updated, tutorial_step_completed, boss_encountered, guild_joined, guild_left, friend_added, friend_removed, message_received
- Removed 3 unused functions: set_debug_mode(), get_event_history(), clear_history()
- Removed unused convenience method: emit_god_level_up() (never called externally)
- Kept achievement_unlocked (used in GameState.gd), show_tutorial_requested, loading_started/completed, game_paused/resumed (all actively used)
- Kept _log_event() and debug vars (used internally by active convenience methods)
- Added typed Array[Dictionary] for _event_history
- File reduced from 192 to 147 lines (-45 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead signals and functions from EventBus`

### 2026-02-12 - Cleanup: Remove dead code from GameCoordinator.gd

**File(s) Modified:** `scripts/systems/core/GameCoordinator.gd`

**Changes:**
- Removed 4 unused functions: `get_system_by_type()`, `pause_game()`, `resume_game()`, `shutdown_game()`
- Removed 2 empty event handlers: `_on_game_paused()`, `_on_game_resumed()`
- Removed signal connections for `game_paused` and `game_resumed` (handlers were empty no-ops)
- Verified all functions had zero external callers via codebase-wide grep
- File reduced from 402 to 360 lines (-42 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead code from GameCoordinator`

### 2026-02-12 - Cleanup: Delete unused BattleFactory.gd

**File(s) Deleted:** `scripts/systems/battle/BattleFactory.gd`

**Changes:**
- Deleted entire `BattleFactory.gd` (105 lines) — never instantiated, never registered in SystemRegistry, no external callers
- All 3 public methods (`create_territory_battle`, `create_dungeon_battle`, `create_arena_battle`) had zero callers
- All 4 private helpers (`_generate_territory_enemies`, `_generate_dungeon_enemies`, `_get_dungeon_waves`, `_create_fallback_enemies`) only called internally
- DungeonCoordinator uses `DungeonManager.get_battle_configuration()` instead — BattleFactory was a dead alternative
- References `EnemyFactory` system that doesn't exist (noted in docs/analysis/03_battle.md)
- Only references were in documentation files (docs/analysis/03_battle.md, docs/MOCs/GameSystems.md)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: delete unused BattleFactory.gd`

### 2026-02-12 - Cleanup: Integrate element multiplier into CombatCalculator damage formula

**File(s) Modified:** `scripts/systems/battle/CombatCalculator.gd`, `scripts/data/DamageResult.gd`

**Changes:**
- Integrated previously-unused `_get_element_multiplier()` into `calculate_damage()` — element advantage/disadvantage now applied during combat
- Added `_get_unit_element()` helper to extract element type from BattleUnit (from source_god.element or source_enemy["element"])
- Element triangle: Fire > Earth > Water > Fire (+30% advantage, -15% disadvantage), Light <> Dark (mutual +30%)
- Updated DamageResult tooltip breakdown to show element advantage/disadvantage percentages
- DamageResult.element_multiplier field (already existed but was never populated) now correctly set

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: integrate element multiplier into CombatCalculator damage formula`

### 2026-02-12 - Cleanup: Remove dead duplicate tracking from SummonManager

**File(s) Modified:** `scripts/systems/collection/SummonManager.gd`, `scripts/ui/summon/SummonResultOverlay.gd`, `scripts/ui/screens/SummonScreen.gd`

**Changes:**
- Removed `_last_summon_duplicates` variable (never written to, always empty)
- Removed `_get_duplicate_mana_reward()` (zero callers)
- Removed `was_duplicate()` and `clear_duplicate_tracking()` (called by UI but functionally dead — dict was never populated)
- Removed `_is_element_soul()` (always returned false, replaced callers with inline `"default"`)
- Removed `duplicate_obtained` signal (never emitted)
- Cleaned up SummonResultOverlay.gd: removed `_was_duplicate()`, dead duplicate badge branch, simplified `_style_god_card()` signature
- Cleaned up SummonScreen.gd: removed 2 `clear_duplicate_tracking()` calls
- SummonManager.gd reduced from 702 to 672 lines (~30 lines removed)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead duplicate tracking from SummonManager`

### 2026-02-12 - Cleanup: Remove unused functions from AwakeningSystem.gd

**File(s) Modified:** `scripts/systems/progression/AwakeningSystem.gd`

**Changes:**
- Removed 4 unused functions (53 lines): `get_ascension_level_from_string()`, `get_awakened_abilities()`, `get_awakened_leader_skill()`, `get_awakened_passive()`
- Verified zero external callers via codebase-wide grep (each function only found in its own definition)
- File reduced from 280 to 227 lines

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead code from AwakeningSystem`

### 2026-02-12 - Cleanup: Remove empty handler from GodProgressionManager.gd

**File(s) Modified:** `scripts/systems/progression/GodProgressionManager.gd`

**Changes:**
- Removed empty `_on_god_sacrificed()` handler (lines 184-188) — function body was just `pass`
- Removed corresponding `event_bus.god_sacrificed.connect(_on_god_sacrificed)` signal connection from `_initialize_dependencies()`
- File reduced from 189 to 178 lines

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove empty handler from GodProgressionManager`

### 2026-02-12 - Cleanup: Remove empty handlers from SacrificeManager.gd

**File(s) Modified:** `scripts/systems/progression/SacrificeManager.gd`

**Changes:**
- Removed empty `_on_god_sacrificed()` handler (body was just `pass`)
- Removed empty `_on_god_awakened()` handler (body was just `pass`)
- Removed their signal connections from `_connect_events()`
- Removed the now-empty `_connect_events()` function and its call from `_ready()`
- File reduced from 239 to 221 lines (-18 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove empty handlers from SacrificeManager`

### 2026-02-12 - Cleanup: Remove unused test functions from equipment system

**File(s) Modified:**
- `scripts/systems/equipment/EquipmentSocketManager.gd`
- `scripts/systems/equipment/EquipmentInventoryManager.gd`
- `scripts/systems/equipment/EquipmentCraftingManager.gd`

**Changes:**
- Removed `_test_socket_operations()` from EquipmentSocketManager.gd (13 lines) — never called, only defined
- Removed `_test_inventory_operations()` from EquipmentInventoryManager.gd (14 lines) — never called, only defined
- Removed `_test_crafting_operations()` from EquipmentCraftingManager.gd (7 lines) — never called, only defined
- All three were inline test stubs with no external callers (verified via codebase-wide grep)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove unused test functions from equipment system`

### 2026-02-12 - Cleanup: Remove legacy Territory code from TerritoryProductionManager

**File(s) Modified:**
- `scripts/systems/territory/TerritoryProductionManager.gd`
- `scripts/ui/territory/TerritoryActionsManager.gd`

**Changes:**
- Removed 9 legacy Territory class functions (~185 lines): `calculate_territory_production()`, `_calculate_god_production_bonus()`, `get_pending_resources()`, `_distribute_resources_by_type()`, `_get_element_material_type()`, `collect_territory_resources()`, `_generate_territory_resources()`, `_get_territory_data()`, `get_total_hourly_production()`
- Removed unused `generation_timers` and `last_update_time` variables
- Simplified `_process_all_territory_generation()` to only call hex node generation (legacy Territory loop was dead — `get_territory_by_id()` method doesn't exist on TerritoryManager)
- Fixed `TerritoryActionsManager._handle_collect_resources()` to use hex system's `collect_node_resources()` instead of broken legacy `collect_territory_resources()` call (was passing String to function expecting Territory object)
- TerritoryProductionManager.gd reduced from 846 to 661 lines (-185 lines)

**Verified:** Ran project, no errors in debug output. Hex node offline production working correctly. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove legacy Territory code from TerritoryProductionManager`

### 2026-02-12 - Cleanup: Remove legacy resource stubs from TerritoryManager

**File(s) Modified:**
- `scripts/systems/territory/TerritoryManager.gd`
- `scripts/ui/territory/TerritoryHeaderManager.gd`

**Changes:**
- Removed 4 legacy stub functions from TerritoryManager.gd (~34 lines): `get_pending_resources()` (always returned `{}`), `collect_territory_resources()` (always returned `{"total": 0, "resources": {}}`), `collect_all_resources()` (wrapper that called collect_territory_resources, zero external callers), `_sum_dictionary_values()` (only used by collect_all_resources)
- All were old Territory system stubs, superseded by hex system's `TerritoryProductionManager.collect_node_resources()`
- Cleaned up TerritoryHeaderManager.gd: removed `_get_territory_pending_resources()` function (called the stub, always got `{}`), removed `total_pending` variable and its always-zero update block from `update_header_summary()`
- Kept the "Pending" stat in header UI — it's still populated by `update_summary_stats()` with a simplified calculation

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove legacy resource stubs from TerritoryManager`

### 2026-02-12 - Cleanup: Remove dead code from DungeonCoordinator.gd

**File(s) Modified:** `scripts/systems/dungeon/DungeonCoordinator.gd`

**Changes:**
- Removed 2 unused local variables in `_on_battle_completed()`: `_dungeon_id` and `_difficulty` — assigned but never read (both `_handle_dungeon_victory()` and `_handle_dungeon_defeat()` re-extract these from `current_dungeon_battle` directly)
- Removed 2 unused public functions: `is_battle_in_progress()` and `get_current_battle_info()` — verified zero external callers via codebase-wide grep
- File reduced from 318 to 307 lines (-11 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead code from DungeonCoordinator`

### 2026-02-12 - Cleanup: Remove unused signals from DungeonManager.gd

**File(s) Modified:** `scripts/systems/dungeon/DungeonManager.gd`

**Changes:**
- Removed `dungeon_unlocked` signal — declared but never emitted and never connected to
- Removed `validation_completed` signal and all 6 `.emit(result)` calls in `validate_dungeon_entry()` — signal was emitted but no code ever connected to it (callers use the direct return value instead)
- File reduced from 774 to 766 lines (-8 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove unused signals from DungeonManager`

### 2026-02-12 - Cleanup: Remove dead code from LootSystem.gd

**File(s) Modified:** `scripts/systems/resources/LootSystem.gd`, `scripts/systems/dungeon/DungeonCoordinator.gd`

**Changes:**
- Removed 2 unused signals: `loot_generated` (emitted but never connected to), `loot_awarded` (emitted but never connected to)
- Removed 3 unused public functions: `generate_battle_rewards()`, `generate_dungeon_rewards()`, `can_roll_loot()` — all had zero external callers
- Removed 2 dead private helpers: `_get_victory_multiplier()`, `_get_difficulty_multiplier()` — only called by the removed public functions
- Updated DungeonCoordinator.gd comment referencing `loot_awarded` signal
- File reduced from 258 to 209 lines (-49 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead code from LootSystem`

### 2026-02-12 - Cleanup: Remove dead debug functions from ResourceManager.gd

**File(s) Modified:** `scripts/systems/resources/ResourceManager.gd`

**Changes:**
- Removed `debug_print_resources()` (lines 198-202) — zero external callers, function body only assigned to unused local vars
- Removed `debug_add_test_resources()` (lines 204-208) — zero external callers
- Corrected CLEANUP_PLAN: `award_resources()` is NOT unused — actively called by `TerritoryProductionManager.gd` line 611-612. Kept it.
- File reduced from 209 to 197 lines (-12 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead debug functions from ResourceManager`

### 2026-02-12 - Cleanup: Remove dead code from ShopManager.gd

**File(s) Modified:** `scripts/systems/shop/ShopManager.gd`

**Changes:**
- Removed `get_featured_packs()` (7 lines) — zero external callers
- Removed `claim_daily_reward()` (16 lines) — zero external callers
- Removed 3 skin wrapper functions: `get_available_skins()`, `get_skins_for_god()`, `purchase_skin()` (18 lines) — zero external callers, ShopScreen.gd calls SkinManager directly
- Removed `_skin_manager` variable and its cache line in `_cache_system_references()` — only used by removed skin wrappers
- Removed dead `emit_signal("crystals_purchased")` on EventBus — signal doesn't exist on EventBus
- Corrected CLEANUP_PLAN: `_event_bus` is NOT unused — actively used for `save_requested.emit()` in purchase flows. Kept it.
- File reduced from 287 to 235 lines (-52 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead code from ShopManager`

### 2026-02-12 - Cleanup: Remove dead code from SkinManager.gd

**File(s) Modified:** `scripts/systems/shop/SkinManager.gd`

**Changes:**
- Removed `_collection_manager` variable — cached from SystemRegistry but never used anywhere
- Removed `_event_bus` variable — only used in dead conditional branches (EventBus has no skin signals)
- Removed 7 unused functions: `get_skins_for_god()`, `get_owned_skins()`, `get_equipped_skin()`, `get_rarity_color()`, `equip_skin()`, `unequip_skin()`, `get_portrait_path()`
- Removed 2 unused signals: `skin_equipped`, `skin_unequipped` — only emitted by removed functions, never connected to
- Removed dead `_event_bus.emit_signal()` calls in `purchase_skin()` — EventBus has no `skin_purchased` signal so `has_signal()` always returned false
- Kept `get_all_skins()`, `is_skin_owned()`, `purchase_skin()` — actively called by ShopScreen.gd
- Kept `can_purchase_skin()`, `get_skin()` — used internally by `purchase_skin()`
- Kept `skin_purchased` signal — emitted on purchase (future listeners)
- File reduced from 228 to 149 lines (-79 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead code from SkinManager`

### 2026-02-12 - Cleanup: Remove unused functions from UICardFactory.gd

**File(s) Modified:** `scripts/utilities/UICardFactory.gd`

**Changes:**
- Removed 9 unused functions: `create_equipment_card()`, `create_territory_card()`, `create_compact_god_card()`, `create_god_grid()`, `create_team_layout()`, `_apply_summon_result_style()`, `_apply_small_icon_style()`, `_apply_detailed_view_style()`, plus 3 equipment style helpers (`_apply_equipment_collection_style`, `_apply_equipment_detailed_style`, `_apply_equipment_icon_style`)
- Removed 3 unused CardStyle enum values: `SUMMON_RESULT`, `SMALL_ICON`, `DETAILED_VIEW`
- Removed dead preloaded scene comments
- Kept `create_god_card()` — actively used by AwakeningGodList.gd, SacrificeGodList.gd, BattleDisplayManager.gd
- Kept `CardStyle.COLLECTION` and `CardStyle.BATTLE_SETUP` — both used by external callers
- Kept `_apply_collection_style()` and `_apply_battle_setup_style()` — called by `create_god_card()`
- Added `:=` type inference to local variables
- File reduced from 218 to 71 lines (-147 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead code from UICardFactory`

### 2026-02-12 - Cleanup: Remove unused functions from JSONDataLoader.gd

**File(s) Modified:** `scripts/utilities/JSONDataLoader.gd`

**Changes:**
- Removed 6 unused static functions (60 lines): `load_files()`, `load_directory()`, `validate_data()`, `clear_cache()`, `set_cache_enabled()`, `get_cache_stats()`
- All had zero external callers — verified via codebase-wide grep
- Kept `load_file()` — preloaded by AwakeningSystem.gd as `GameDataLoader`
- Kept `_cache` and `_cache_enabled` static vars — used internally by `load_file()`
- File reduced from 98 to 38 lines (-60 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead code from JSONDataLoader`

### 2026-02-12 - Cleanup: Remove unused debug function from GodExperienceCalculator.gd

**File(s) Modified:** `scripts/utilities/GodExperienceCalculator.gd`

**Changes:**
- Removed unused `debug_experience_info()` function (10 lines) — zero external callers verified via codebase-wide grep
- File reduced from 79 to 69 lines

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead code from GodExperienceCalculator`

### 2026-02-12 - Cleanup: Remove dead code from GodCardFactory.gd

**File(s) Modified:** `scripts/utilities/GodCardFactory.gd`

**Changes:**
- Removed unused `populate_god_grid()` function (lines 75-92) — zero external callers (other files have their own local `_populate_god_grid()` methods)
- Removed 3 unused filter functions: `get_awakening_filter()`, `get_sacrificeable_filter()`, `get_battle_ready_filter()` — designed for use with `populate_god_grid()`, all had zero external callers
- Kept `create_god_card()` and `_configure_card_for_preset()` — actively used by 7+ files (CollectionScreen, EquipmentGodDisplay, TeamSelectionManager, BattleInfoManager, TowerScreen, etc.)
- File reduced from 108 to 74 lines (-34 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead code from GodCardFactory`

### 2026-02-12 - Cleanup: Remove dead code from ResourceDisplay.gd

**File(s) Modified:** `scripts/ui/components/ResourceDisplay.gd`

**Changes:**
- Removed 8 unused functions from the materials table system: `_show_materials_table()`, `_add_table_header()`, `_populate_materials_table()`, `_add_material_row()`, `_create_header_style()`, `_get_player_resource()`, `_get_resource_from_manager()`, `debug_print_resources()`
- Removed 2 dead helper functions: `_add_expanded_resource_row()` and `_add_material_item()` — defined but never called (replaced by `_add_resource_to_grid()` in the current expanded panel implementation)
- All functions verified to have zero external callers via codebase-wide grep
- Kept all active functionality: expanded panel, resource categories, tap-to-expand, description popups
- File reduced from 941 to 742 lines (-199 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead code from ResourceDisplay`

### 2026-02-12 - Cleanup: Fix broken DebugOverlay initialization and button handlers

**File(s) Modified:** `scripts/ui/components/DebugOverlay.gd`

**Changes:**
- Fixed `_ready()` — was hardcoding `progression_manager = null` and `tutorial_manager = null` instead of fetching from SystemRegistry
- Added `_ensure_managers()` lazy initialization that fetches PlayerProgressionManager and TutorialOrchestrator from SystemRegistry on first use (F1 toggle)
- Fixed all progression button handlers — were calling nonexistent `debug_add_experience()` and `debug_set_level()` methods; now use real API (`add_experience()`) and direct state setting for level jumps
- Fixed `_update_display()` — was calling nonexistent `get_debug_info()` method; now uses real API (`get_player_level()`, `get_player_experience()`, `get_xp_for_next_level()`)
- Fixed tutorial display — was calling nonexistent `get_debug_info()`; now uses `get_current_tutorial_info()` and `is_tutorial_active()`
- Added 3 missing button handlers connected in scene: `_on_reset_tutorials_pressed()`, `_on_test_3_gods_pressed()`, `_on_show_god_count_pressed()`
- Fixed `name` variable shadowing Node.name warning (renamed to `tutorial_name`)
- Added static typing throughout (return types, parameter types, local variables)

**Verified:** Ran project, no errors in debug output. DebugOverlay shadow warning eliminated. All pre-existing warnings unchanged.

**Commit:** `cleanup: fix broken DebugOverlay initialization and button handlers`

### 2026-02-12 - Cleanup: Remove dead code from MainUIOverlay.gd

**File(s) Modified:** `scripts/ui/components/MainUIOverlay.gd`

**Changes:**
- Removed `clear_all_layers()` (7 lines) — zero external callers, only defined in this file
- Removed `debug_layer_status()` (18 lines) — zero external callers, debug-only function
- Corrected CLEANUP_PLAN: `disconnect_header_back_button()` is NOT unused — actively called by WorldView.gd line 102. Kept it.
- File reduced from 343 to 318 lines (-25 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead code from MainUIOverlay`

### 2026-02-12 - Cleanup: Remove empty _process() from TaskAssignmentScreen.gd

**File(s) Modified:** `scripts/ui/screens/TaskAssignmentScreen.gd`

**Changes:**
- Removed empty `_process()` function (lines 426-430) — body was just `pass`, called every frame for no reason
- Removed PROCESS section header comment
- File reduced from 431 to 420 lines (-11 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove empty _process from TaskAssignmentScreen`

### 2026-02-12 - Cleanup: Cache abilities.json in BattleActionProcessor.gd

**File(s) Modified:** `scripts/systems/battle/BattleActionProcessor.gd`

**Changes:**
- Fixed performance issue: `_get_ability_data()` was calling `FileAccess.open("res://data/abilities.json")` on EVERY skill use during combat
- Added static `_cached_abilities: Dictionary` and `_abilities_loaded: bool` class variables
- Added `_load_abilities_cache()` static function that loads and parses abilities.json once
- `_get_ability_data()` now does a simple dictionary lookup after first lazy load
- No file I/O during combat after first skill use

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: cache abilities.json in BattleActionProcessor`

### 2026-02-12 - Cleanup: Extract magic numbers to constants in CombatCalculator.gd

**File(s) Modified:** `scripts/systems/battle/CombatCalculator.gd`

**Changes:**
- Extracted 15 named constants from magic numbers throughout the file:
  - Damage formula: `DAMAGE_NUMERATOR` (1000.0), `DAMAGE_DENOMINATOR_BASE` (1140.0), `DAMAGE_DEFENSE_SCALE` (3.5)
  - Hit types: `GLANCING_HIT_CHANCE` (0.15), `GLANCING_DAMAGE_MULT` (0.7), `DAMAGE_VARIANCE_MIN/MAX` (0.9/1.1)
  - Elements: `ELEMENT_ADVANTAGE_MULT` (1.3), `ELEMENT_DISADVANTAGE_MULT` (0.85)
  - Healing: `HEAL_VARIANCE_MIN/MAX` (0.95/1.05)
  - Stat scaling: `LEVEL_STAT_SCALE` (0.1), `POWER_PER_LEVEL` (50), `POWER_PER_TIER` (500)
- Added static typing to all local variables across all functions
- No behavioral changes — all values identical to original magic numbers

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: extract constants in CombatCalculator`

### 2026-02-12 - Cleanup: Extract magic numbers to constants in TurnManager.gd

**File(s) Modified:** `scripts/systems/battle/TurnManager.gd`

**Changes:**
- Extracted 3 named constants: `TURN_BAR_SPEED` (0.07), `TURN_BAR_THRESHOLD` (100.0), `MAX_TURN_ITERATIONS` (1000)
- Replaced all 7 magic number usages across `get_turn_order_preview()`, `_fill_turn_queue()`, and `_count_future_turns()`
- Added static typing to `safety_counter` variables
- No behavioral changes — all values identical to original magic numbers

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: extract constants in TurnManager`

### 2026-02-12 - Cleanup: Extract magic numbers to constants in God.gd

**File(s) Modified:** `scripts/data/God.gd`, `scripts/systems/collection/GodFactory.gd`

**Changes:**
- Extracted 6 named constants from magic numbers:
  - `MAX_LEVEL` (40) — used in `can_level_up()`
  - `MIN_SPECIALIZATION_LEVEL` (20) — used in `can_specialize()`
  - `DEFAULT_CRIT_RATE` (15), `DEFAULT_CRIT_DAMAGE` (50), `DEFAULT_RESISTANCE` (15), `DEFAULT_ACCURACY` (0) — Summoners War defaults used in @export var declarations
- Updated `can_level_up()` to use `MAX_LEVEL` instead of magic `40`
- Updated `can_specialize()` to use `MIN_SPECIALIZATION_LEVEL` instead of magic `20`
- Updated `@export var` defaults to use `DEFAULT_*` constants
- Updated `GodFactory.gd` fallback defaults to reference `God.DEFAULT_*` constants instead of hardcoded values
- No behavioral changes — all values identical to original magic numbers

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: extract constants in God.gd`

### 2026-02-12 - Cleanup: Refactor register_core_systems() in SystemRegistry.gd

**File(s) Modified:** `scripts/systems/core/SystemRegistry.gd`

**Changes:**
- Split 144-line `register_core_systems()` into 5 focused phase functions:
  - `_register_core_infrastructure()` — EventBus, SaveManager, ConfigurationManager, ResourceManager, LootSystem
  - `_register_collection_and_territory()` — CollectionManager + 7 territory systems
  - `_register_battle_and_dungeon()` — BattleCoordinator, DungeonManager, DungeonCoordinator
  - `_register_progression()` — PlayerProgressionManager, GodProgressionManager, SacrificeSystem, AwakeningSystem, SacrificeManager, SummonManager
  - `_register_ui_equipment_and_meta()` — ScreenManager, NotificationManager, TutorialOrchestrator, EquipmentManager, SkinManager, ShopManager, TowerManager, FirebaseIntegration
- `register_core_systems()` is now 6 lines (5 function calls)
- Added `:=` type inference to all local variables
- Added `-> void` return types to all new functions
- Registration order preserved exactly — no behavioral changes

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: refactor register_core_systems in SystemRegistry`

### 2026-02-12 - Cleanup: Refactor load_game() in SaveManager.gd

**File(s) Modified:** `scripts/systems/core/SaveManager.gd`

**Changes:**
- Extracted `_read_save_file() -> Dictionary` — handles file I/O, JSON parsing, and error reporting (30 lines)
- Extracted `_load_systems_from_data()` — loads all game systems from save data, shared between `load_game()` and `_apply_save_data()` (38 lines)
- Extracted `_load_system_data()` helper — eliminates repetitive if-has/get-system/has-method pattern (6 lines)
- `load_game()` reduced from 94 lines to 18 lines
- `_apply_save_data()` reduced from 48 lines to 9 lines — eliminated duplicate system loading logic
- Added `:=` type inference and typed parameters to new functions
- File reduced from 479 to 443 lines (-36 lines, with code duplication eliminated)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: refactor load_game in SaveManager`

### 2026-02-12 - Cleanup: Refactor _handle_dungeon_victory() in DungeonCoordinator.gd

**File(s) Modified:** `scripts/systems/dungeon/DungeonCoordinator.gd`

**Changes:**
- Split 87-line `_handle_dungeon_victory()` into 4 focused functions:
  - `_handle_dungeon_victory()` — now 24 lines, orchestrates victory flow
  - `_generate_victory_rewards()` — loot table generation, first-clear bonus, LootSystem awarding (35 lines)
  - `_merge_rewards()` — shared helper to merge rewards into totals and populate BattleResult for UI (11 lines)
  - `_award_team_experience()` — awards XP to all team gods (8 lines)
- Added static typing throughout new functions (`:String`, `:Dictionary`, `:Node`, `:float`, `:int`, `-> void`, `-> Dictionary`)
- Eliminated duplicated reward-merging loop (was copy-pasted for loot_table and first_clear sources)
- No behavioral changes — all logic preserved exactly
- File reduced from 307 to 301 lines

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: refactor _handle_dungeon_victory in DungeonCoordinator`

### 2026-02-12 - Cleanup: Refactor _create_god_of_tier() in SummonManager.gd

**File(s) Modified:** `scripts/systems/collection/SummonManager.gd`

**Changes:**
- Split 83-line `_create_god_of_tier()` into 3 focused functions:
  - `_create_god_of_tier()` — now 24 lines, orchestrates config lookup, pool building, and selection
  - `_get_summon_weights()` — gathers element/powder/pantheon weight multipliers and active favors from config (20 lines)
  - `_build_weighted_god_pool()` — filters gods by tier/pantheon and applies all weight multipliers (30 lines)
- Added static typing throughout new functions (`:Dictionary`, `:Array`, `:String`, `:float`, `:int`, `-> Dictionary`, `-> Array`)
- No behavioral changes — all logic preserved exactly

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: refactor _create_god_of_tier in SummonManager`

### 2026-02-12 - Cleanup: Delete unused scripts/ui/components/GodSelectionPanel.gd

**File(s) Deleted:** `scripts/ui/components/GodSelectionPanel.gd`

**Changes:**
- Deleted `scripts/ui/components/GodSelectionPanel.gd` (345 lines) — entire file is unused dead code
- Class `TerritoryGodSelectionHelper` has zero external references (only its own definition)
- No scene files reference this script
- Active god selection functionality lives in `scripts/ui/territory/GodSelectionPanel.gd` (class_name `GodSelectionPanel`, used by HexTerritoryScreen.gd)
- This was originally flagged for refactoring `create_god_selection_item()` (110 lines), but deletion is the correct action since the file is completely dead
- Updated CLEANUP_PLAN.md to reflect deletion instead of refactoring

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: delete unused components/GodSelectionPanel.gd`

### 2026-02-13 - Cleanup: Refactor _populate_expanded_panel() in ResourceDisplay.gd

**File(s) Modified:** `scripts/ui/components/ResourceDisplay.gd`

**Changes:**
- Extracted 3 helper functions from 126-line `_populate_expanded_panel()`:
  - `_categorize_resources()` — sorts all non-zero resources into currency/raw/processed/special buckets
  - `_add_category_section()` — adds a section header + resource grid to the vbox (replaces 4 identical copy-pasted blocks)
  - `_get_resource_metadata()` — static function returning the display name/icon/category/description dictionary
- `_populate_expanded_panel()` reduced from 126 lines to 22 lines
- Added static typing throughout new functions (`: Dictionary`, `: String`, `-> void`, `-> Dictionary`)
- No behavioral changes — all logic preserved exactly
- File reduced from 742 to 728 lines (-14 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: refactor _populate_expanded_panel in ResourceDisplay`

### 2026-02-13 - Cleanup: Refactor create_recipe_card() in CraftingUIUtils.gd

**File(s) Modified:** `scripts/ui/components/CraftingUIUtils.gd`

**Changes:**
- Extracted 5 helper functions from 131-line `create_recipe_card()`:
  - `_create_card_container()` — PanelContainer with StyleBoxFlat styling (16 lines)
  - `_create_header_row()` — icon + name + tier/rarity badge (27 lines)
  - `_create_info_label()` — conversion display or cost summary (18 lines)
  - `_create_bottom_row()` — auto-repeat checkbox + craft button orchestration (18 lines)
  - `_create_craft_button()` — button with afford/disabled styling (26 lines)
- `create_recipe_card()` reduced from 131 lines to 23 lines
- Added `:=` type inference and static typing throughout new functions
- No behavioral changes — all logic preserved exactly

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: refactor create_recipe_card in CraftingUIUtils`

### 2026-02-13 - Cleanup: Refactor _show_craft_popup() in ProductionSummaryWidget.gd

**File(s) Modified:** `scripts/ui/components/ProductionSummaryWidget.gd`

**Changes:**
- Extracted 5 helper functions from 121-line `_show_craft_popup()`:
  - `_create_popup_overlay()` — full-screen Control container with dark ColorRect background (15 lines)
  - `_create_popup_panel()` — centered PanelContainer with StyleBoxFlat styling (24 lines)
  - `_add_popup_header()` — title label + close button with styling (22 lines)
  - `_add_popup_tier_info()` — tier and recipe count info label (6 lines)
  - `_add_popup_recipe_grid()` — ScrollContainer with recipe grid and CraftingUIUtils cards (20 lines)
- `_show_craft_popup()` reduced from 121 lines to 29 lines
- Added `:=` type inference and static typing throughout new functions
- No behavioral changes — all logic preserved exactly

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: refactor _show_craft_popup in ProductionSummaryWidget`

### 2026-02-13 - Cleanup: Create GodUIHelpers.gd and consolidate duplicated color/name functions

**File(s) Modified:**
- `scripts/utilities/GodUIHelpers.gd` (NEW — 160 lines)
- `scripts/ui/components/GodCard.gd` (removed 7 duplicated functions, ~60 lines)
- `scripts/ui/collection/CollectionDetailsPanel.gd` (removed 5 duplicated functions, ~45 lines)
- `scripts/ui/collection/GodCollectionList.gd` (removed 5 duplicated functions, ~60 lines)
- `scripts/ui/collection/GodDetailsPanel.gd` (removed 3 duplicated functions, ~35 lines)
- `scripts/ui/sacrifice/SacrificePanel.gd` (removed 1 duplicated function, ~7 lines)
- `scripts/ui/summon/SummonShowcase.gd` (removed 2 duplicated functions, ~25 lines)
- `scripts/utilities/TeamStatsCalculator.gd` (removed 2 unused duplicate functions, ~20 lines)

**Changes:**
- Created `GodUIHelpers.gd` — centralized static utility class with canonical implementations:
  - Element colors: `get_element_color(God.ElementType)`, `get_element_color_from_string(String)`
  - Element names: `get_element_name()`, `get_element_name_with_emoji()`, `get_element_name_from_int()`, `get_element_emoji()`
  - Tier colors: `get_tier_color()`, `get_subtle_tier_color()`, `get_tier_border_color()` (all using `God.TierType`)
  - Tier names: `get_tier_name()`, `get_tier_short_name()`, `get_tier_stars()`, `get_tier_stars_emoji()`, `get_tier_name_with_stars()`
  - Rarity colors: `get_rarity_color(Equipment.Rarity)`, `get_rarity_color_from_string()`, `get_rarity_color_from_int()`
- Updated all 6 files from cleanup plan + TeamStatsCalculator to call `GodUIHelpers.*` instead of local implementations
- Standardized color values across the codebase (previously each file had slightly different RGB values)
- Handled 1-based tier ints (from JSON dict data) by converting `tier - 1` at call sites in GodCollectionList and GodDetailsPanel
- Net reduction: ~200 lines of duplicated code removed, +160 lines for the utility (net ~40 lines saved, with huge maintainability improvement)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: create GodUIHelpers and consolidate duplicated color/name functions`

### 2026-02-13 - Cleanup: Create DungeonConstants.gd and consolidate duplicated dungeon code

**File(s) Modified:**
- `scripts/systems/dungeon/DungeonConstants.gd` (NEW — 25 lines)
- `scripts/systems/dungeon/DungeonCoordinator.gd` (removed duplicated constant + function)
- `scripts/systems/dungeon/DungeonManager.gd` (removed duplicated constant + function)

**Changes:**
- Created `DungeonConstants.gd` (extends RefCounted, class_name DungeonConstants) with:
  - `MAX_TEAM_SIZE` constant (= 4) — previously duplicated in both files
  - `get_difficulty_reward_multiplier()` static function — previously identical `_get_difficulty_reward_multiplier()` in both files
- Updated DungeonCoordinator.gd to use `DungeonConstants.MAX_TEAM_SIZE` and `DungeonConstants.get_difficulty_reward_multiplier()`
- Updated DungeonManager.gd to use `DungeonConstants.MAX_TEAM_SIZE` and `DungeonConstants.get_difficulty_reward_multiplier()`
- Removed ~40 lines of duplicated code across both files
- Note: Required opening Godot editor to generate .uid file for the new script (Godot 4.5 requirement)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: create DungeonConstants and consolidate duplicated dungeon code`

### 2026-02-13 - Cleanup: Add static typing to TerritoryManager.gd

**File(s) Modified:** `scripts/systems/territory/TerritoryManager.gd`

**Changes:**
- Added `HexCoord` type to 8 coord parameters: `capture_node`, `lose_node`, `get_node_defense_rating`, `calculate_distance_penalty`, `get_connected_bonus`, `get_connected_node_count`, `is_hex_node_controlled`, `get_hex_node`
- Added `HexNode` type to 15+ node variables and parameters: `_calculate_garrison_power`, `can_assign_workers`, `get_garrison_worker_status`, `_check_node_dungeon_unlock`, `_award_capture_rewards`, `_reveal_adjacent_nodes`, `_start_attack_timer`, `_handle_node_attack`, and all local node variables from HexGridManager lookups
- Added `God` type to `god_obj` in `_calculate_garrison_power`
- Added `Node` type to all SystemRegistry system lookups (~25 variables)
- Added `-> void` return types to 12 functions: `_ready`, `_load_territory_configuration`, `load_save_data`, `_on_dungeon_completed`, `_connect_to_dungeon_coordinator`, `_deferred_connect_dungeon_coordinator`, `_award_capture_rewards`, `_reveal_adjacent_nodes`, `_start_attack_timer`, `update_attack_timers`, `_handle_node_attack`, `reset_attack_timer`
- Added `-> HexNode` return type to `get_hex_node`
- Typed all local variables with explicit types (int, float, bool, String, Dictionary, Array)
- No behavioral changes — all logic preserved exactly

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: add static typing to TerritoryManager`

### 2026-02-13 - Cleanup: Add static typing to HexGridManager.gd

**File(s) Modified:** `scripts/systems/territory/HexGridManager.gd`

**Changes:**
- Added `HexCoord` type to 15+ coordinate parameters: `get_node_at`, `has_node_at`, `get_neighbors`, `get_distance`, `get_distance_from_base`, `get_hex_path`, `get_nodes_within_distance`, `_coord_to_key`, `_get_lowest_f_score_coord`, `_reconstruct_path`
- Added `HexNode` type to 20+ node variables/parameters/returns: `_add_node`, `get_node_at` (return), `get_node_by_id` (return), `_get_max_crafts_for_node`, and all local node variables from dictionary lookups and loop iterators
- Added `GDScript` type to all `load()` calls for script files
- Added `-> HexNode` return type to `get_node_at`, `get_node_by_id`; `-> HexCoord` to `get_base_coord`, `_get_lowest_f_score_coord`; `-> Node` to `_get_resource_manager`
- Added `Node` type to `resource_manager` parameters and variables
- Typed all local variables throughout the file: `int`, `float`, `bool`, `String`, `Dictionary`, `Array`, `Array[HexCoord]`, `Array[Vector2i]`
- Fixed variable name shadowing: `name` → `tile_name` (avoids Node.name shadowing), `craft_key` → `cancel_key`/`disable_key` in different scope blocks
- No behavioral changes — all logic preserved exactly

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: add static typing to HexGridManager`

### 2026-02-13 - Cleanup: Add static typing to StatusEffectManager.gd

**File(s) Modified:** `scripts/systems/battle/StatusEffectManager.gd`

**Changes:**
- Added `BattleUnit` type to all 10 unit/target parameters across all functions
- Added `StatusEffect` type to all effect parameters
- Added `Array[String]` return types to `process_turn_start_effects()` and `process_turn_end_effects()`
- Added `-> void` return type to `_remove_effect()`, `-> bool` to `apply_status_effect()` and `remove_status_effect()`
- Added `-> Dictionary` return type to all effect processing functions
- Typed all local variables: `messages: Array[String]`, `result: Dictionary`, `damage: int`, `healing: int`, `msg: String`, `removed: bool`
- Fixed API calls to use actual BattleUnit/StatusEffect properties instead of nonexistent methods:
  - `unit.get_status_effects()` → `unit.status_effects` (property access)
  - `unit.get_display_name()` → `unit.display_name` (property access)
  - `unit.set_stunned(true)` → removed (BattleUnit.can_act() checks prevents_action)
  - `effect.should_trigger_on(timing)` → removed (effects always process)
  - `effect.get_damage_amount()` → inline calc using `effect.damage_per_turn` and `effect.dot_damage`
  - `effect.get_heal_amount()` → inline calc using `effect.heal_per_turn`
  - `effect.reduce_duration()` → `effect.duration -= 1` (direct property)
- Consolidated `_process_poison_effect`/`_process_burn_effect` into unified `_process_dot_effect(label)` that also handles bleed/continuous_damage
- Added `_process_cc_effect()` for stun/freeze/sleep/immobilize/fear
- Removed `has_method()` guard checks — functions now properly typed to BattleUnit
- Matched `effect.id` instead of `effect.effect_type` string for consistency with StatusEffect factory method IDs
- File reduced from 164 to 149 lines

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: add static typing to StatusEffectManager`

### 2026-02-13 - Cleanup: Add static typing to BattleActionProcessor.gd

**File(s) Modified:** `scripts/systems/battle/BattleActionProcessor.gd`

**Changes:**
- Added `BattleUnit` type to all 10 caster/target parameters across all functions: `_execute_attack`, `_execute_skill`, `_execute_defend`, `_apply_skill_status_effects`, `_apply_debuff_effect`, `_apply_buff_effect`, `_apply_atb_decrease`, `_apply_atb_steal`, `_apply_life_drain`
- Added `Skill` type to 2 skill parameters in `_execute_skill` and `_apply_skill_status_effects`
- Added `StatusEffect` type to 2 status_effect variables in `_apply_debuff_effect` and `_apply_buff_effect`
- Added `DamageResult` type to 5 damage result variables and loop iterators
- Added `-> void` return types to 8 functions (all non-bool returning functions)
- Typed all local variables: `int` (chance, duration, damage amounts), `float` (roll, steal/decrease amounts), `String` (debuff_type, buff_type, effect_type), `Array` (targets, effects), `Dictionary` (ability_data, effect_dict)
- Used `:=` type inference for `ActionResult.new()`, `StatusEffect.new()`, `DamageResult.new()`, `FileAccess.open()`, `JSON.new()`
- Fixed 2 property name bugs discovered during typing:
  - `defense_buff.effect_id` → `defense_buff.id` (StatusEffect has `id`, not `effect_id`)
  - `defense_buff.stat_modifiers` → `defense_buff.stat_modifier` (StatusEffect has `stat_modifier`, not `stat_modifiers`)
- Removed unnecessary `has_method("add_status_effect")` guards — BattleUnit is now strongly typed and always has this method

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: add static typing to BattleActionProcessor`

### 2026-02-13 - Cleanup: Add static typing to data classes

**File(s) Modified:**
- `scripts/data/ActionResult.gd`
- `scripts/data/BattleAction.gd`
- `scripts/data/BattleState.gd`
- `scripts/data/God.gd`

**Changes:**
- **ActionResult.gd**: Added `Array[DamageResult]` and `Array[StatusEffect]` typed arrays. Added `-> void` return types to `add_damage_result()` and `add_status_effect()`.
- **BattleAction.gd**: Added `BattleUnit` type to `caster` and all factory method parameters. Added `Array[BattleUnit]` to `targets`. Added `Skill` type to `skill`. Added `:=` type inference. Typed lambda in `get_description()`.
- **BattleState.gd**: Added `Array[BattleUnit]` to `player_units`, `enemy_units`, `all_units`. Added return types to all functions (`-> void`, `-> bool`, `-> float`, `-> Array[BattleUnit]`, `-> Dictionary`). Typed all for-loop variables and local variables. Rewrote `.filter()`-based getters as explicit loops to return properly typed arrays. Added `BattleUnit`/`Skill` types to `find_valid_targets()` params. Fixed latent bug: `skill.targets_enemies()` → `skill.targets_enemies` (property access, not method call).
- **God.gd**: Added `Array[StatusEffect]` to `status_effects`. Kept `equipment`, `active_abilities`, `passive_abilities`, `abilities`, `skill_levels` as untyped `Array` with type comments — Godot 4.5 `@export` typed arrays reject untyped Array assignment from JSON/save data at runtime.

**Verified:** Ran project, all 43 gods loaded successfully, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: add static typing to data classes`

### 2026-02-15 - Audit: Fix save system for PlayerProgressionManager

**Priority:** Critical
**File(s) Modified:** `scripts/systems/core/SaveManager.gd`, `scripts/systems/progression/PlayerProgressionManager.gd`

**Changes:**
- Added PlayerProgressionManager to SaveManager save chain (save_game → get_save_data under "player_progression" key)
- Added PlayerProgressionManager to SaveManager load chain (_load_systems_from_data → load_save_data)
- Fixed broken `_level_up()` call to non-existent `save_manager.save_player_progress()` — removed since SaveManager handles periodic saves
- Removed dead `emit_signal("feature_unlocked", ...)` call on EventBus — EventBus has no such signal (feature_unlocked lives on TutorialOrchestrator/FeatureUnlockManager)

**Verified:** Ran project, no new errors in debug output. All pre-existing warnings unchanged.

**Commit:** `audit: fix save system for PlayerProgressionManager`

### 2026-02-15 - Audit: Fix save system for EquipmentManager

**Priority:** Critical
**File(s) Modified:** `scripts/systems/equipment/EquipmentManager.gd`, `scripts/systems/core/SaveManager.gd`, `scripts/utilities/SaveLoadUtility.gd`

**Changes:**
- Replaced `save_equipment_data()`/`load_equipment_data()` with standard `get_save_data()`/`load_save_data()` methods on EquipmentManager
- `get_save_data()` serializes equipment inventory via SaveLoadUtility and gem inventory as dictionaries
- `load_save_data()` deserializes equipment inventory via SaveLoadUtility and restores gem inventory
- Added EquipmentManager to SaveManager save chain (`save_data["equipment"]`)
- Added EquipmentManager to SaveManager load chain (`_load_system_data` call)
- Fixed SaveLoadUtility `serialize_equipment()` to include all Equipment fields: name, type, rarity, max_sockets, sockets, equipped_by_god_id, equipment_set_type, main_stat_base, origin_dungeon, is_destroyed, lore_text (previously only saved 7 of 18 fields)
- Fixed SaveLoadUtility `deserialize_equipment()` to restore all Equipment fields (matching serialization)

**Verified:** Ran project, no new errors in debug output. All pre-existing warnings unchanged.

**Commit:** `audit: fix save system for EquipmentManager`

### 2026-02-15 - Audit: Fix save system for ShopManager

**Priority:** Critical
**File(s) Modified:** `scripts/systems/core/SaveManager.gd`

**Changes:**
- Added ShopManager to SaveManager save chain (`save_data["shop"]` via `get_save_data()`)
- Added ShopManager to SaveManager load chain (`_load_system_data` call with "shop" key)
- ShopManager already had `get_save_data()` and `load_save_data()` methods — just needed wiring into SaveManager
- Purchase history and active subscriptions now persist across restarts

**Verified:** Ran project, no new errors in debug output. All pre-existing warnings unchanged.

**Commit:** `audit: fix save system for ShopManager`

### 2026-02-16 - Audit: Fix save system for SkinManager

**Priority:** Critical
**File(s) Modified:** `scripts/systems/core/SaveManager.gd`

**Changes:**
- Added SkinManager to SaveManager save chain (`save_data["skins"]` via `get_save_data()`)
- Added SkinManager to SaveManager load chain (`_load_system_data` call with "skins" key)
- SkinManager already had `get_save_data()` and `load_save_data()` methods — just needed wiring into SaveManager
- Owned skins and equipped skins now persist across restarts

**Verified:** Ran project, no new errors in debug output. All pre-existing warnings unchanged.

**Commit:** `audit: fix save system for SkinManager`

### 2026-02-16 - Audit: Fix save system for AchievementManager

**Priority:** High
**File(s) Modified:** `scripts/systems/core/SaveManager.gd`, `scripts/systems/progression/AchievementManager.gd`

**Changes:**
- Added AchievementManager to SaveManager save chain (`save_data["achievements"]` via `get_save_data()`)
- Added AchievementManager to SaveManager load chain (`_load_system_data` call with "achievements" key)
- Added legacy migration: if save has `player_data.achievements` but no top-level `achievements` key, loads from legacy location
- Fixed timing bug: removed `_restore_state()` call from `initialize()` — it ran before `load_game()` loaded `player_data`, so achievements were always empty on restore
- Removed dead `_restore_state()` method (no longer called)
- Updated `_save_state()` to not write to `player_data` bag — achievements now saved through proper save chain
- Added `_validate_all_achievements()` deferred call after `load_save_data()` for catch-up

**Verified:** Ran project, no new errors in debug output. Achievement restore works correctly — `first_summon` and `five_gods` recognized as completed, `first_territory` triggered and saved.

**Commit:** `audit: fix save system for AchievementManager`

### 2026-02-16 - Audit: Add save-on-quit handler to SaveManager

**Priority:** High
**File(s) Modified:** `scripts/systems/core/SaveManager.gd`

**Changes:**
- Added `_notification()` handler that catches `NOTIFICATION_WM_CLOSE_REQUEST`
- Calls `save_game()` before `get_tree().quit()` to prevent data loss on window close
- Players no longer lose up to 60 seconds of progress on force-close
- Added `-> void` return type to `_ready()`, typed `delta` parameter in `_process()`

**Verified:** Ran project, no new errors in debug output. All pre-existing warnings unchanged.

**Commit:** `audit: add save-on-quit handler to SaveManager`

### 2026-02-16 - Audit: Add save version migration to SaveManager

**Priority:** High
**File(s) Modified:** `scripts/systems/core/SaveManager.gd`

**Changes:**
- Bumped SAVE_VERSION from "1.0" to "1.1" and added KNOWN_VERSIONS constant
- Added `_migrate_save_data()` with sequential version-based migration chains (1.0 → 1.1 → ...)
- Added `_migrate_1_0_to_1_1()` — promotes achievements from `player_data.achievements` to top-level `achievements` key
- Updated `load_game()` to detect version mismatch and run migration before loading systems
- Updated `_apply_save_data()` (cloud save path) to also run migration before loading
- Removed inline legacy migration from `_load_systems_from_data()` — now handled by migration system
- Unknown save versions get a warning but still attempt to load (graceful fallback)
- Future migrations can be added as `_migrate_X_to_Y()` functions chained in `_migrate_save_data()`

**Verified:** Ran project, no new errors in debug output. All pre-existing warnings unchanged.

**Commit:** `audit: add save version migration to SaveManager`

### 2026-02-16 - Audit: Add missing Equipment properties for EquipmentInventoryManager

**Priority:** Critical
**File(s) Modified:** `scripts/data/Equipment.gd`, `scripts/utilities/SaveLoadUtility.gd`

**Changes:**
- Added `@export var equipped_slot: int = -1` to Equipment.gd — tracks which slot (0-5) the equipment occupies on a god
- Added computed `is_equipped` property with getter (`equipped_by_god_id != ""`) and setter (clears both `equipped_by_god_id` and `equipped_slot` when set to false)
- `equipped_by_god_id` already existed — audit plan was partially incorrect (only `is_equipped` and `equipped_slot` were missing)
- Updated SaveLoadUtility `serialize_equipment()` to include `equipped_slot` field
- Updated SaveLoadUtility `deserialize_equipment()` to restore `equipped_slot` from save data (defaults to -1)
- EquipmentInventoryManager.gd required NO changes — all 7 references to `is_equipped` and 3 references to `equipped_slot` now resolve correctly

**Verified:** Ran project, no new errors in debug output. All pre-existing warnings unchanged.

**Commit:** `audit: add missing Equipment properties for EquipmentInventoryManager`

### 2026-02-16 - Audit: Fix wrong God property in EquipmentStatCalculator

**Priority:** Critical
**File(s) Modified:** `scripts/systems/equipment/EquipmentStatCalculator.gd`

**Changes:**
- Fixed `calculate_set_bonuses()` — used non-existent `god.equipped_equipment` property (lines 155, 160), changed to `god.equipment` which is the actual God.gd property
- Renamed loop variable from `equipment` to `equip` to avoid shadowing the Equipment class name
- Added `is Equipment` type check in the loop for safety
- Added static typing to `set_counts` and `bonuses` dictionaries

**Verified:** Ran project, no new errors in debug output. All pre-existing warnings unchanged.

**Commit:** `audit: fix wrong God property in EquipmentStatCalculator`

### 2026-02-16 - Audit: Delete unused StatusEffectManager.gd

**Priority:** Critical
**File(s) Deleted:** `scripts/systems/battle/StatusEffectManager.gd`, `scripts/systems/battle/StatusEffectManager.gd.uid`

**Changes:**
- Deleted entire `StatusEffectManager.gd` (149 lines) — never registered in SystemRegistry, never instantiated, zero external callers
- Only references were in documentation files (docs/analysis, docs/MOCs, GAME_DESIGN_DOCUMENT.md)
- Status effects are handled inline by BattleActionProcessor.gd — this file was a dead alternative implementation
- Also deleted orphaned `.uid` file

**Verified:** Ran project, no new errors in debug output. All pre-existing warnings unchanged.

**Commit:** `audit: delete unused StatusEffectManager.gd`

### 2026-02-16 - Audit: Add null checks to Firebase/Firestore operations

**Priority:** Critical
**File(s) Modified:**
- `scripts/systems/firebase/CloudSaveManager.gd`
- `scripts/systems/firebase/FirebaseAnalytics.gd`
- `scripts/systems/arena/ArenaDataSync.gd`

**Changes:**
- CloudSaveManager: Added null checks for `_firestore.collection()` in `_do_save()` and `_do_load()` — now emits failure signal instead of crashing on network failure
- CloudSaveManager: Added `has_method` checks in `_extract_document_data()` before calling `doc.keys()`/`doc.get_value()`
- FirebaseAnalytics: Added null check for `_firestore.collection()` in `_send_to_firestore()` — re-queues events on failure instead of crashing
- FirebaseAnalytics: Added max retry limit (10) to `flush_queue()` to prevent infinite loop when Firestore fails repeatedly
- ArenaDataSync: Added null checks for `_firestore.collection()` in all 4 async operation functions: `_do_fetch_opponents`, `_do_upload_defense`, `_do_update_stats`, `_do_record_battle`, `_do_fetch_leaderboard`
- ArenaDataSync: Added `collection.has_method("query")` checks before calling `query()`
- ArenaDataSync: Fixed `result.has_method("keys")` crash risk in `_parse_opponent_results()` and `_parse_leaderboard_results()` — added `result is Object` guard
- Removed print statements from CloudSaveManager `_do_save`/`_do_load` (replaced with signal-based error reporting)
- All operations now gracefully emit failure signals instead of crashing

**Verified:** Ran project, no new errors in debug output. All pre-existing warnings unchanged.

**Commit:** `audit: add null checks to Firebase/Firestore operations`

### 2026-02-16 - Audit: Add save corruption detection to SaveManager

**Priority:** Medium
**File(s) Modified:** `scripts/systems/core/SaveManager.gd`

**Changes:**
- Added `_validate_save_data()` function that checks save data integrity before loading
- Validates required top-level keys (`version`, `timestamp`) exist and have correct types
- Validates all known section keys (`resources`, `collection`, `hex_grid`, etc.) are Dictionaries when present
- Validates `collection.gods` is an Array when present
- Called from both `load_game()` (local saves) and `_on_cloud_load_completed()` (cloud saves)
- On validation failure: emits `load_failed` signal for local saves, `cloud_sync_failed` for cloud saves
- Prevents corrupted JSON from crashing game systems during load

**Verified:** Ran project, no new errors in debug output. All pre-existing warnings unchanged.

**Commit:** `audit: add save corruption detection to SaveManager`

### 2026-02-16 - Audit: Delete unused GameState.gd

**Priority:** High
**File(s) Modified:**
- `scripts/data/GameState.gd` (DELETED — 321 lines)
- `scripts/data/GameState.gd.uid` (DELETED)
- `scripts/systems/core/GameCoordinator.gd`

**Changes:**
- Deleted entire `GameState.gd` (321 lines) — dead "god object" that duplicated functionality of individual managers
- GameState was instantiated in GameCoordinator but data stored via `store_game_data()` was never read back (`get_game_data()` had zero callers)
- `initialize_new_game()` reset internal state that was never accessed — actual resources, gods, equipment managed by their respective system managers
- Removed `var game_state` declaration from GameCoordinator.gd
- Removed `GameState.gd` script load and instantiation from `_setup_core_systems()`
- Removed all `game_state.store_game_data()` calls from `_load_game_data()` — ConfigurationManager already holds this data
- Removed `game_state.initialize_new_game()` from `_start_new_game()` — starting resources/gods handled by dedicated setup functions
- Removed `game_state_valid` from `get_debug_info()`

**Verified:** Ran project, no new errors in debug output. All pre-existing warnings unchanged.

**Commit:** `audit: delete unused GameState.gd`

### 2026-02-16 - Audit: Add cache clearing to Skill.gd

**Priority:** High
**File(s) Modified:** `scripts/data/Skill.gd`

**Changes:**
- Added `clear_cache()` static method to allow clearing the `_abilities_cache` dictionary during scene transitions or memory pressure
- Added `:=` type inference to all local variables in `_load_abilities_data()`, `load_from_id()`, `create_basic_attack()`
- Added explicit `Dictionary` types to `ability_dict` and `data` variables
- Extracted duplicate `data.get("targets", "single")` call into typed `targets_str` variable

**Verified:** Ran project, no new errors in debug output. All pre-existing warnings unchanged.

**Commit:** `audit: add cache clearing to Skill.gd`

### 2026-02-16 - Audit: Remove dead code from StatisticsManager.gd and wire into save/EventBus

**Priority:** High
**File(s) Modified:**
- `scripts/systems/core/StatisticsManager.gd`
- `scripts/systems/core/SaveManager.gd`

**Changes:**
- Removed ~230 lines of dead code from StatisticsManager.gd (332 → 102 lines):
  - Removed `achievement_unlocked` signal (duplicated EventBus signal)
  - Removed `god_performance` dictionary and all 5 related functions (`_update_god_performance`, `record_ability_use`, `get_god_win_rate`, `record_damage_dealt/taken/healing_done` with god_performance refs)
  - Removed all achievement checking functions (`check_achievements`, `_check_battle_achievements`, `_check_collection_achievements`, `_check_progression_achievements`, `_unlock_achievement`) — duplicated AchievementManager
  - Removed analytics functions (`get_battle_summary`, `get_top_performing_gods`) — zero external callers
  - Removed `time_stats` dictionary and all time tracking (`_update_session_playtime`, `get_playtime_summary`, `_exit_tree`) — never used externally
  - Removed resource recording functions (`record_resource_earned`, `record_crystal_spending`, `record_summon`) — zero external callers
  - Removed `record_battle_start` (used Node meta tracking, never called)
- Wired StatisticsManager into EventBus: connects to `battle_ended`, `dungeon_completed`, `territory_captured`, `summon_performed` signals so stats are actually populated
- Renamed `save_statistics_data()`/`load_statistics_data()` to `get_save_data()`/`load_save_data()` for consistency
- Added StatisticsManager to SaveManager save chain (`save_data["statistics"]`)
- Added StatisticsManager to SaveManager load chain (`_load_system_data` call)
- Added "statistics" to save validation section list
- Stats data (battles_won, dungeon_clears, total_summons_performed) now actually populated and persisted — AchievementManager achievement progress for battle_wins/dungeon_clears/summon_count will now work

**Verified:** Ran project, no new errors in debug output. All pre-existing warnings unchanged.

**Commit:** `audit: remove dead code from StatisticsManager and wire into save/EventBus`

### 2026-02-16 - Audit: Remove dead code from TerritoryManager.gd

**Priority:** High
**File(s) Modified:** `scripts/systems/territory/TerritoryManager.gd`

**Changes:**
- Removed 14 dead functions (~189 lines) with zero external callers:
  - Old string-based territory system: `capture_territory()`, `lose_territory()`, `get_controlled_territories()`, `upgrade_territory()`, `_get_upgrade_cost()`, `get_territory_count()`, `get_territories_by_type()`, `can_capture_more_territories()`, `_calculate_max_territories()`
  - Unused task/building helpers: `has_building()`, `has_available_task_slots()`, `add_building()`
  - Unused dungeon-unlock functions: `is_node_unlocked_by_dungeons()`, `get_nodes_unlockable_by_dungeon()`
- Removed unused `territory_upgraded` signal (only emitter was deleted `upgrade_territory()`)
- All removals verified via codebase-wide grep — zero external callers for each function
- Kept all functions with external callers: `is_territory_controlled()` (TerritoryCardBuilder, TerritoryListManager), `get_territories_by_filter()` (TerritoryListManager), `get_all_territories()` (TerritoryHeaderManager), `get_territory_resource_rate()` (TerritoryHeaderManager), `get_territory_buildings/level/max_task_slots/working_gods/available_tasks()` (TaskAssignmentScreen)
- File reduced from 1055 to 866 lines (-189 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `audit: remove dead code from TerritoryManager`

### 2026-02-16 - Audit: Remove dead code from BuildingManager.gd

**Priority:** High
**File(s) Modified:** `scripts/systems/territory/BuildingManager.gd`

**Changes:**
- Removed 14 dead public functions (zero external callers): `get_all_buildings()`, `get_buildings_by_category()`, `get_category()`, `get_all_categories()`, `is_loaded()`, `get_building_consumption()`, `get_building_effects()`, `get_net_production()`, `get_upgrade_cost()`, `get_build_time()`, `get_max_level()`, `can_upgrade_building()`, `upgrade_building()`, `get_debug_info()`
- Removed 3 unused signals: `building_removed` (emitted but never connected), `building_upgraded` (emitter also dead), `buildings_loaded` (emitted but never connected)
- Removed 2 dead private helper functions: `_can_afford()`, `_spend_resources()` (only called by dead upgrade path)
- Removed 5 print statements (debug logging)
- Added static typing throughout remaining code (`:=`, `: Dictionary`, `: String`, `: int`, `: float`, `-> Node`)
- Kept all actively-used functions: `get_building()` (5 callers), `get_buildings_by_tier()` (internal), `get_available_buildings_for_tile()` (BuildingSelectionPopup), `get_building_production()` (TerritoryProductionManager), `get_build_cost()` (BuildingSelectionPopup), `get_max_workers()` (internal), `can_place_building()` (internal), `place_building()` (BuildingSelectionPopup), `remove_building()` (HexTerritoryScreen)
- Kept `building_placed` signal (connected by AchievementManager)
- File reduced from 436 to 231 lines (-205 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `audit: remove dead code from BuildingManager`

### 2026-02-16 - Audit: Remove dead code from NodeTaskCalculator.gd

**Priority:** High
**File(s) Modified:** `scripts/systems/territory/NodeTaskCalculator.gd`

**Changes:**
- Removed 7 dead public functions with zero external callers: `get_task_display_name()`, `calculate_output_with_details()`, `get_secondary_resources()`, `get_all_resources()`, `calculate_total_node_output()`, `format_output_rate()`, and 1 dead private helper `_get_resource_display_name()`
- Removed `NODE_SECONDARY_RESOURCES` constant (only used by dead functions)
- Kept all functions with external callers: `has_affinity_match()` (WorkerSlotDisplay), `get_output_display_text()` (WorkerSlotDisplay), and their dependency chain (`get_task_for_node()`, `calculate_output_rate()`, `get_primary_resource()`, `get_node_affinity()`)
- File reduced from 356 to 243 lines (-113 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `audit: remove dead code from NodeTaskCalculator`

### 2026-02-16 - Audit: Remove dead code from EquipmentManager.gd

**Priority:** High
**File(s) Modified:** `scripts/systems/equipment/EquipmentManager.gd`

**Changes:**
- Removed 3 dead functions with zero external callers:
  - `get_public_api()` (20 lines) — self-documentation function, never called
  - `create_equipment_from_loot()` (10 lines) — dead integration method, never called by any loot/dungeon code
  - `get_god_equipment_stats()` (32 lines) — dead stats function, never called externally (uses CollectionManager.get_god_equipment which duplicates EquipmentManager's own equip tracking)
- `save_equipment_data()`/`load_equipment_data()` already removed in earlier audit (replaced with `get_save_data()`/`load_save_data()`)
- Corrected audit plan: DungeonManager.gd "7 dead functions" were all false positives — all have active external callers (DungeonInfoDisplay, TeamSelectionManager, BattleInfoManager)
- File reduced from 469 to 401 lines (-68 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `audit: remove dead code from EquipmentManager`

### 2026-02-16 - Audit: Remove dead code from EquipmentSocketManager.gd

**Priority:** High
**File(s) Modified:** `scripts/systems/equipment/EquipmentSocketManager.gd`

**Changes:**
- Removed 5 dead public functions with zero external callers: `get_gem_count()`, `get_compatible_gems_for_socket()`, `get_socket_info()`, `get_gem_effects_on_equipment()`, `get_socket_upgrade_cost_preview()`
- Removed 2 unused signals: `gem_unsocketed` (emitted but never connected to), `socket_upgrade_failed` (emitted but never connected to)
- Removed 3 dead `socket_upgrade_failed.emit()` calls from `unlock_socket()` and 1 dead `gem_unsocketed.emit()` call from `unsocket_gem()`
- Kept all actively-used functions: `unlock_socket()`, `socket_gem()`, `unsocket_gem()`, `add_gem_to_inventory()`, `get_gem_inventory()` — all called by EquipmentManager.gd
- Kept actively-used signals: `socket_unlocked` (connected by EquipmentManager), `gem_socketed` (connected by EquipmentManager)
- File reduced from 380 to 282 lines (-98 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `audit: remove dead code from EquipmentSocketManager`

### 2026-02-16 - Audit: Remove debug prints from all 17 system files (~203 statements)

**Files modified:** 17 files in `scripts/systems/`

**Changes:**
- Removed ~203 print/push_warning statements across all system files using paren-counting parser for multi-line safety
- Top files: SaveManager(38), BattleCoordinator(31), TerritoryManager(21), TerritoryProductionManager(16), CollectionManager(14), TurnManager(13), HexGridManager(12), FirebaseIntegration(10), GameCoordinator(9)
- Fixed 3 orphaned multi-line print remnants in TerritoryManager.gd (left over from earlier regex pass)
- Cleaned up orphaned debug-only variables: `coord_str`(x4), `was_capped`, `bonus_percent` in TerritoryProductionManager; `hex_coord_script`, `matched_count`, `player_nodes_loaded`, `newly_revealed` in HexGridManager; `effect_results`, `reason` in TurnManager

**Verified:** Ran project, no parse errors or runtime errors.

**Commit:** `audit: remove debug prints from all 17 system files (~203 statements)`

### 2026-02-16 - Audit: Remove debug prints from all UI and data files (316 statements)

**Files modified:** 43 files in `scripts/ui/`, 2 files in `scripts/data/`

**Changes:**
- Removed 316 print statements across 45 UI and data files using automated paren-counting parser
- Top files: BattleScreen(56), BattleUnitCard(29), HexTerritoryScreen(25), GodDetailsPanel(20), CollectionScreenCoordinator(18), NodeInfoPanel(18), TerritoryActionsManager(16), GodCollectionList(11), WorldView(10), EquipmentInventoryManager(10), CollectionFilterPanel(9)
- Data files: BattleState(2), BattleUnit(2)

**Verified:** Ran project, no parse errors or runtime errors.

**Commit:** `audit: remove debug prints from all UI and data files (316 statements)`

### 2026-02-16 - Audit: Add static typing to top 20 worst files (1,357 annotations)

**Files modified:** 20 files across `scripts/ui/`, `scripts/systems/`, `scripts/data/`

**Changes:**
- Added 1,357 type annotations across the 20 files with the most missing annotations
- Used automated type inference script that handles: Constructor patterns (`Type.new()` → `Type`), literals (string/int/float/bool), Vector2/Vector3/Color, empty arrays/dicts, `str()/int()/float()` casts, format strings, `randf()/randi()`
- Top files: ArenaScreen(271), NodeInfoPanel(132), TerritoryOverviewScreen(117), TerritoryCardBuilder(89), TeamSelectionManager(88), CollectionDetailsPanel(85), UnifiedEquipmentScreen(82), TowerScreen(75), SummonScreen(69), ProductionSummaryWidget(58)

**Verified:** Ran project, no parse errors or runtime errors.

**Commit:** `audit: add static typing to top 20 worst files (1,357 annotations)`

### 2026-02-16 - Audit: Externalize hardcoded balance values to JSON configs

**Files created:**
- `data/progression_config.json` — God leveling (max levels, XP formula), stat bonuses per tier, stat scaling (level scaling, role modifiers, ascension bonus, tier multipliers)
- `data/tower_config.json` — Floor scaling, base enemy stats, milestones, rewards, difficulty ratings, boss names
- `data/arena_config.json` — ELO settings, cooldowns, league thresholds/colors, PvP rewards

**Files modified:**
- `scripts/systems/progression/GodProgressionManager.gd` — Loads god_leveling and stat_bonuses_per_level from progression_config.json at startup
- `scripts/systems/collection/GodCalculator.gd` — Static config cache; loads level scaling, role modifiers, ascension bonus, tier multipliers from progression_config.json
- `scripts/systems/tower/TowerManager.gd` — Loads all floor scaling, enemy stats, milestones, rewards, difficulty ratings, and boss names from tower_config.json
- `scripts/systems/arena/ArenaManager.gd` — Loads ELO, cooldown, league, and reward config from arena_config.json; removed 2 stray debug prints
- `scripts/systems/collection/SummonManager.gd` — Fixed `_get_summon_rates()` to look up rates from actual `summon_types` config structure (was always falling through to hardcoded defaults); notification durations now configurable

**Verified:** Ran project, no parse errors or runtime errors.

**Commit:** `audit: externalize hardcoded balance values to JSON configs`

---

## AUDIT PHASE 1 COMPLETE — 73/73 Tasks

All initial audit tasks from AUDIT_PLAN.md have been completed:
- **Critical (3):** Save system fixes for TowerManager, LootSystem, InventoryManager
- **High - Dead Code (8):** Removed dead functions from 8 system files
- **High - Debug Prints (36):** Removed ~519 print statements from 62 files (17 system + 43 UI + 2 data)
- **Medium - Static Typing (20):** Added 1,357 type annotations to the 20 worst files
- **Low - Hardcoded Values (5):** Externalized balance values from 5 systems to 3 new JSON config files

---

## 2026-02-16 - Audit: Delete 11 orphaned .uid files

**Priority:** High
**File(s) Modified:** 11 .uid files deleted

**Changes:**
- Deleted 11 orphaned .uid files whose corresponding .gd scripts no longer exist:
  1. `scripts/systems/battle/BattleEffectProcessor.gd.uid`
  2. `scripts/systems/battle/BattleFactory.gd.uid`
  3. `scripts/systems/progression/ProgressionCoordinator.gd.uid`
  4. `scripts/ui/components/GodSelectionPanel.gd.uid`
  5. `scripts/ui/screens/DungeonTab.gd.uid`
  6. `scripts/ui/screens/LoadingScreen.gd.uid`
  7. `scripts/ui/screens/TerritoryRoleScreen.gd.uid`
  8. `scripts/ui/screens/TerritoryScreen.gd.uid`
  9. `scripts/ui/screens/TutorialDialog.gd.uid`
  10. `scripts/ui/territory/TerritoryCardFactory.gd.uid`
  11. `scripts/utilities/JSONLoader.gd.uid`
- Verified no scene, resource, or script files reference any of these UIDs
- Note: GodSelectionPanel (components) is different from active GodSelectionPanel (territory); TutorialDialog (screens) is different from active TutorialDialog (components)

**Verified:** Ran project, no errors in debug output

**Commit:** `audit: delete 11 orphaned .uid files for deleted scripts`

---

## 2026-02-16 - Audit: Externalize task system values to task_config.json and create tasks.json

**Priority:** High (Data-Driven JSON Config)
**File(s) Modified:** `data/task_config.json` (new), `data/tasks.json` (new), `scripts/data/Task.gd`, `scripts/systems/territory/NodeTaskCalculator.gd`, `scripts/systems/tasks/TaskAssignmentManager.gd`

**Changes:**
- **data/task_config.json** (new): Created with `bonus_formulas` (trait_duration_reduction_cap=0.5, skill_duration_reduction_per_level=0.01, skill_duration_reduction_cap=0.3, skill_reward_bonus_per_level=0.02, skill_reward_bonus_cap=0.5), `progress` (update_interval_seconds=1.0), `node_output` (base_rates by node type, tier_multipliers 1-5, god_level_bonus_per_level=0.05, affinity_match_multiplier=1.5, fallback_spec_bonuses by tier), `node_mappings` (task_map, resource_map, affinity_map, relevant_tasks_map)
- **data/tasks.json** (new): Created with 31 task definitions covering all tasks from territory_config.json node_task_mapping (mining, mine_ore, mine_gems, deep_mining, gem_cutting, logging, herbalism, foraging, plant_cultivation, fishing, pearl_diving, salt_harvesting, hunting, tracking, monster_hunting, taming, smithing, armor_crafting, weapon_crafting, enchanting, research, scroll_crafting, training, skill_learning, meditation, blessing, awakening_ritual, divine_communion, garrison_duty, war_planning, combat_training, defense_building). Includes task_categories and skills sections.
- **Task.gd**: Added static config loading from task_config.json with cache. Added 5 static getter methods (get_trait_duration_cap, get_skill_duration_per_level, get_skill_duration_cap, get_skill_reward_per_level, get_skill_reward_cap). Updated get_duration_for_god() and get_rewards_for_god() to use config values with fallback defaults. Added static typing to all local variables. Changed min() to minf().
- **NodeTaskCalculator.gd**: Replaced 4 hardcoded const dictionaries (NODE_TASK_MAP, NODE_RESOURCE_MAP, NODE_AFFINITY_MAP, BASE_OUTPUT_RATES) with static config loading from task_config.json. Updated all 8 methods (get_task_for_node, calculate_output_rate, get_primary_resource, get_node_affinity, _get_tier_multiplier, _get_affinity_bonus, _calculate_fallback_spec_bonus, _get_relevant_tasks_for_node) to read from config with fallback defaults. Added static typing throughout.
- **TaskAssignmentManager.gd**: Added config loading for progress.update_interval_seconds. Added static typing to JSON loading variables. Replaced PROGRESS_UPDATE_INTERVAL const with configurable _progress_update_interval member. Added static typing to _update_all_task_progress and _update_task_progress_for_assignment.

**Verified:** Ran project, no new errors in debug output

**Commit:** `audit: externalize task system values to task_config.json and create tasks.json`

# Progression System Analysis

## Files Analyzed
- AwakeningSystem.gd - God awakening with material costs and stat transfers
- FeatureUnlockManager.gd - Level-gated feature unlocking system
- GodProgressionManager.gd - Individual god XP and leveling
- PlayerProgressionManager.gd - Player-level XP and progression
- ProgressionCoordinator.gd - Empty file (stub)
- SacrificeManager.gd - High-level facade for sacrifice/awakening UI
- SacrificeSystem.gd - Core sacrifice XP calculations and operations
- TutorialOrchestrator.gd - Tutorial flow and feature unlock sequences

## What It Does

The progression system handles two main progression tracks:

**Player Progression:**
- Player XP with exponential scaling (base 100, factor 1.15)
- Max level 50 with level-gated feature unlocks (summon at 2, sacrifice at 3, territory at 5, dungeon at 10, arena at 15)
- Save/load integration through SystemRegistry

**God Progression:**
- God XP with tier-based stat bonuses per level
- Max level 40 (50 when awakened)
- Awakening system that transforms gods into enhanced versions with new abilities
- Sacrifice system for consuming gods to grant XP to others (SW-style with same-god 3x and same-element 1.5x bonuses)

**Supporting Systems:**
- FeatureUnlockManager listens to player level-ups and unlocks features with notifications
- TutorialOrchestrator runs first-time user tutorials to introduce features
- SacrificeManager acts as a facade coordinating SacrificeSystem and AwakeningSystem

## Status: WORKING

The system is largely functional with good architecture. Most components follow the SystemRegistry pattern and have proper separation of concerns.

## Code Quality
- [x] Clean architecture - Good facade pattern, single responsibility per class
- [x] Proper typing - Type hints on signals and function parameters
- [x] Error handling - Null checks and validation before operations
- [ ] Comments/docs - Decent but inconsistent docstrings

## Key Findings

1. **Authentic Summoners War mechanics:** Sacrifice XP uses quadratic level scaling with tier bonuses. Same-god (3x) and same-element (1.5x) bonuses match SW. Level scaling gets dramatically steeper at levels 35+.

2. **Well-refactored from monolith:** Comments indicate this was refactored from a larger system. Clean separation between SacrificeSystem (calculations) and SacrificeManager (orchestration/UI).

3. **Awakening transforms gods:** The awakening system creates new God instances from JSON data, preserving level/XP/ascension/skills from the original. Awakened gods have enhanced abilities and increased level cap (40→50).

4. **Dual feature unlock systems:** Both PlayerProgressionManager and FeatureUnlockManager handle feature unlocking with slightly different level thresholds. This appears intentional - PlayerProgressionManager does basic unlocking, FeatureUnlockManager adds UI notifications.

5. **Config-driven awakening:** Awakening requirements and materials loaded from awakened_gods.json, making it data-driven rather than hardcoded.

## Issues Found

1. **ProgressionCoordinator.gd is empty:** The file exists but contains no code. Either a planned but unimplemented coordinator, or an orphaned file.

2. **Duplicate feature unlock logic:** PlayerProgressionManager (lines 20-26) and FeatureUnlockManager (lines 14-25) have overlapping but slightly different feature_unlock_levels dictionaries:
   - PlayerProgressionManager: stops at level 15 (arena)
   - FeatureUnlockManager: goes to level 40 (legendary_summon), includes more features

3. **PlayerProgressionManager signal mismatch:** Line 79 emits `player_leveled_up.emit(new_level)` with one argument, but the signal is declared on line 11 as `signal player_leveled_up(new_level: int)` - this works but FeatureUnlockManager line 58 connects expecting `_on_player_level_up(old_level: int, new_level: int)` with TWO arguments. This will cause a runtime error.

4. **God.is_equipped() and God.is_assigned_to_territory() likely missing:** SacrificeManager line 175 calls `god.is_equipped()` and `god.is_assigned_to_territory()` but based on previous analysis, God.gd is a data class that may not have these methods.

5. **AwakeningSystem JSON loading bypasses SystemRegistry:** Line 8 uses `preload("res://scripts/utilities/JSONLoader.gd")` but then manually opens files instead of using the preloaded loader. The preload is unused.

6. **SacrificeSystem player_data parameter confusion:** In `perform_sacrifice()` line 148, the comment says "player_data is actually the CollectionManager" which is confusing API design. The parameter name doesn't match its actual type.

7. **SacrificeManager passes CollectionManager to AwakeningSystem:** Line 101 calls `awakening_system.attempt_awakening(god, collection_manager)` but AwakeningSystem.attempt_awakening expects `player_data` with `get_resource()` and `spend_resource()` methods - CollectionManager doesn't have these.

8. **Missing Mythic tier in SacrificeSystem:** Line 67-80 `get_tier_base_value()` handles COMMON through LEGENDARY but GodProgressionManager line 27 defines tier 5 as "Mythic" with stat bonuses. SacrificeSystem would return 500 (default) for Mythic gods.

## Dependencies

**Depends on:**
- SystemRegistry (service locator)
- EventBus (event communication)
- SaveManager (persistence)
- CollectionManager (god management)
- ResourceManager (material costs)
- God data model (awakening/sacrifice target)
- awakened_gods.json (awakening configuration)
- NotificationManager (feature unlock notifications)
- UICoordinator (tutorial dialogs)

**Used by:**
- UI screens (sacrifice, awakening, tutorial)
- Battle system (XP rewards post-battle)
- Dungeon system (XP rewards)

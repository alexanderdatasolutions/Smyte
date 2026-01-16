# Core Systems Analysis

## Files Analyzed
- SaveManager.gd - Save/load game state to JSON file
- EventBus.gd - Global signal bus for decoupled system communication
- ConfigurationManager.gd - JSON configuration file loader
- GameCoordinator.gd - Main game orchestrator (replaces monolithic GameManager)
- StatisticsManager.gd - Battle/resource/playtime statistics tracking
- SystemRegistry.gd - Service locator pattern for dependency injection

## What It Does
The core systems provide the foundational infrastructure for a Godot-based idle/gacha RPG:

1. **SystemRegistry** acts as a service locator, managing system registration, lifecycle, and dependency injection. Systems are registered in dependency order and can be looked up by name or type.

2. **EventBus** provides decoupled communication via 50+ signals covering combat, progression, resources, UI, dungeons, social features, and system events. Includes debug logging and event history.

3. **GameCoordinator** orchestrates game initialization: sets up the SystemRegistry, loads JSON configs, initializes systems, handles new game vs saved game flow, and manages auto-save.

4. **ConfigurationManager** loads JSON data files (gods, territories, equipment, resources, battle config, loot tables) and provides getter methods for each.

5. **SaveManager** handles save/load with JSON serialization to `user://save_game.dat`, featuring auto-save every 5 minutes, version tracking, and integration with SystemRegistry to gather data from other systems.

6. **StatisticsManager** tracks battle stats (wins, losses, streaks, damage), god performance, resource acquisition, playtime, and triggers achievements.

## Status: WORKING

The architecture is sound and follows good practices. The code appears functional and well-structured.

## Code Quality
- [x] Clean architecture
- [x] Proper typing
- [x] Error handling
- [ ] Comments/docs (minimal - relies on self-documenting code)

## Key Findings
- **Clean refactor from monolith**: GameCoordinator is explicitly noted as replacing a 1203-line "god class" GameManager
- **Service locator pattern**: SystemRegistry provides proper dependency injection without tight coupling
- **Proper initialization order**: Systems registered in phases (infrastructure → data → collection → battle → progression → UI)
- **Comprehensive event system**: EventBus covers all major game systems with 50+ signals
- **Auto-save functionality**: Both SaveManager and GameCoordinator implement auto-save (redundantly)
- **Good separation of concerns**: Each system has a focused responsibility

## Issues Found
- **Duplicate auto-save**: Both SaveManager._process() and GameCoordinator._setup_save_timer() implement 5-minute auto-save. Only one is needed.
- **StatisticsManager references undefined GameManager**: In `_check_collection_achievements()` at line 227-228, it references `GameManager.player_data.gods` which doesn't exist in this architecture.
- **StatisticsManager file location mismatch**: File is at `scripts/systems/StatisticsManager.gd` but should be in `scripts/systems/core/` based on folder structure. It's also not registered in SystemRegistry.
- **JSONDataLoader preloaded but unused**: ConfigurationManager preloads JSONDataLoader at line 9 but implements its own `_load_json_file()` method.
- **Hardcoded starter gods**: GameCoordinator._setup_starting_gods() hardcodes `["ares", "poseidon", "artemis"]` rather than reading from config.
- **Missing null check**: GameCoordinator line 69 calls `SystemRegistry.get_instance().get_system()` without checking if get_instance() returns null first.

## Dependencies
- **Depends on**:
  - JSON data files in `res://data/` (gods.json, territories.json, equipment.json, etc.)
  - `scripts/utilities/JSONLoader.gd` (preloaded but not used)
  - `scripts/data/God.gd`, `scripts/data/Equipment.gd`, `scripts/data/GameState.gd`
  - `scripts/factories/GodFactory.gd`
- **Used by**: All other game systems (battle, collection, dungeon, equipment, progression, territory, resources, UI)

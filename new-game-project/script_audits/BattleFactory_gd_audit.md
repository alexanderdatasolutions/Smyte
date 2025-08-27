# BattleFactory.gd Audit Report

## Overview
- **File**: `scripts/systems/BattleFactory.gd`
- **Type**: Battle Configuration Factory
- **Lines of Code**: 187
- **Class Type**: Resource (Configuration factory)

## Purpose
Modular battle instantiation system that creates and configures battles for all content types (Dungeons, Territories, Raids, PvP, etc.). Factory pattern for battle configuration data - creates the config, BattleManager handles battle logic.

## Dependencies
### Inbound Dependencies (What this relies on)
- **Territory** (data): Territory object for territory battles
- **God** (data): God objects for player teams
- **GameManager** (systems): Access to DungeonSystem for wave data
- **DungeonSystem** (systems): get_dungeon_info() for dungeon configuration

### Outbound Dependencies (What depends on this)
- **BattleManager**: Uses BattleFactory config to set up battles
- **EnemyFactory**: Uses get_battle_config() to create appropriate enemies
- **Battle UI screens**: Uses get_battle_description() for display

## Method Inventory

### Factory Creation Methods (5 methods)
- `create_territory_battle(gods, territory, stage)` - Static factory for territory battles
- `create_dungeon_battle(gods, dungeon_id, difficulty, enemies)` - Static factory for dungeon battles
- `create_raid_battle(gods, raid_id, difficulty)` - Static factory for raid battles
- `create_arena_battle(gods, opponent_team)` - Static factory for PvP battles
- **Missing**: create_guild_battle(), create_world_boss_battle()

### Configuration Methods (3 methods)
- `validate()` - Validate battle configuration completeness
- `get_battle_config()` - Get config dictionary for EnemyFactory
- `get_battle_description()` - Get user-friendly battle description

### Helper/Calculation Methods (4 methods)
- `_calculate_territory_waves(territory, stage)` - Calculate waves based on territory stage
- `_get_dungeon_waves(dungeon_id, difficulty)` - Get wave count from dungeons.json
- `_get_raid_waves(raid_id, difficulty)` - Get wave count for raids
- `_get_raid_reward_multiplier(difficulty)` - Get reward multiplier for difficulty

## Signals
**Emitted**: None (configuration class)
**Received**: None (configuration class)

## Key Data Structures

### Core Properties
- `battle_type: String` - Type identifier
- `player_team: Array[God]` - Player's god team
- `current_wave: int` - Current wave number
- `total_waves: int` - Total waves in battle

### Context-Specific Properties
- `battle_territory: Territory` - For territory battles
- `battle_stage: int` - Territory stage number
- `battle_dungeon_id: String` - Dungeon identifier
- `battle_difficulty: String` - Difficulty level
- `battle_raid_id: String` - Raid identifier
- `battle_opponent_team: Array` - PvP opponent team

### Battle Configuration
- `max_enemies_per_wave: int` - UI constraint (4)
- `auto_progression: bool` - Auto-advance waves
- `reward_multiplier: float` - Difficulty-based rewards

### Enums
- `BattleType`: TERRITORY, DUNGEON, RAID, GUILD_BATTLE, ARENA, WORLD_BOSS

## Notable Patterns
- **Factory Pattern**: Static creation methods for different battle types
- **Configuration Object**: Holds all battle setup data
- **Validation Pattern**: validate() method checks configuration completeness
- **Builder Pattern**: Methods set different properties based on battle type
- **Data Translation**: Converts configuration to dictionaries for other systems

## Code Quality Issues

### Anti-Patterns Found
1. **Incomplete Implementation**: Missing factory methods for GUILD_BATTLE and WORLD_BOSS
2. **Magic Numbers**: Hard-coded wave counts and multipliers
3. **External Dependency**: Direct GameManager access in static method
4. **Inconsistent Validation**: Some battle types not fully validated

### Positive Patterns
1. **Factory Pattern**: Clean separation of creation logic
2. **Type Safety**: Proper type hints for arrays
3. **Single Responsibility**: Only handles configuration, not battle logic
4. **Clear Separation**: Battle creation vs battle execution

## Architectural Notes

### Strengths
- **Clear Factory Pattern**: Well-defined creation methods
- **Configuration Focus**: Doesn't mix config with battle logic
- **Type-Specific Logic**: Each battle type has appropriate configuration
- **Validation Layer**: Built-in configuration validation

### Concerns
- **Incomplete Coverage**: Missing some battle types from enum
- **Hard-coded Values**: Wave counts and multipliers should be data-driven
- **Tight Coupling**: Direct GameManager dependency in static method
- **Limited Extensibility**: Adding new battle types requires code changes

## Duplicate Code Potential
- **Factory Method Pattern**: Similar structure across create_*_battle methods
- **Wave Calculation**: Similar logic in _get_*_waves methods
- **Configuration Dictionary**: Similar structure in get_battle_config()
- **Validation Patterns**: Similar validation logic across battle types

## Refactoring Recommendations
1. **Complete Implementation**: Add missing battle type factories
2. **Data-Driven Configuration**: Move wave counts and multipliers to JSON
3. **Dependency Injection**: Remove direct GameManager access
4. **Configuration Validator**: Create dedicated validation class
5. **Battle Type Registry**: Dynamic battle type registration system

## Integration Points
- **BattleManager**: Primary consumer of factory configurations
- **EnemyFactory**: Uses battle config to create appropriate enemies
- **DungeonSystem**: Provides dungeon configuration data
- **UI Systems**: Uses battle descriptions for display

## Security/Safety Notes
- **Input Validation**: Limited validation of input parameters
- **Null Safety**: Some null checks present but not comprehensive
- **Array Safety**: player_team.duplicate() protects original arrays
- **Type Safety**: Good use of typed arrays for God objects

## Configuration Examples
```gdscript
# Territory battle
var config = BattleFactory.create_territory_battle(gods, territory, 5)

# Dungeon battle  
var config = BattleFactory.create_dungeon_battle(gods, "fire_temple", "hard")

# Arena battle
var config = BattleFactory.create_arena_battle(gods, opponent_gods)
```

## Data Flow
1. **Creation**: Static factory method creates configured BattleFactory
2. **Validation**: validate() checks configuration completeness
3. **Configuration**: get_battle_config() provides data for EnemyFactory
4. **Description**: get_battle_description() provides UI text
5. **Consumption**: BattleManager uses configuration to set up battle

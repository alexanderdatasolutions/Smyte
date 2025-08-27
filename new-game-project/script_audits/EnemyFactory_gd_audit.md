# EnemyFactory.gd Audit Report

## Overview
- **File**: `scripts/systems/EnemyFactory.gd`
- **Type**: Enemy Creation Factory System  
- **Lines of Code**: 865
- **Class Type**: RefCounted (Static factory class)

## Purpose
Comprehensive enemy generation system for all battle types. Creates balanced, scalable enemies for territories, dungeons, raids, and PvP with complex stat calculations, AI behaviors, and wave-based progression.

## Dependencies
### Inbound Dependencies (What this relies on)
- **BattleFactory**: Battle configuration data for unified enemy creation
- **Territory**: Territory data for element and tier-based enemy generation
- **DataLoader**: Element conversion utilities and enemy type data from JSON
- **GameManager**: Access to DungeonSystem for configuration data
- **enemies.json**: Enemy type definitions, AI behaviors, and abilities

### Outbound Dependencies (What depends on this)
- **BattleManager**: Primary consumer for all battle enemy creation
- **DungeonSystem**: Uses create_enemies_for_dungeon() for dungeon battles
- **TerritoryScreen**: Uses for enemy preview generation
- **WaveSystem**: Uses wave-based enemy creation methods
- **Battle UI systems**: Displays created enemy data

## Method Inventory

### Main Entry Points (4 methods)
- `create_enemies_for_battle(battle_config)` - UNIFIED entry point using BattleFactory config
- `create_enemies_for_stage(territory, stage)` - Territory battle enemy creation
- `create_enemies_for_dungeon(dungeon_id, difficulty)` - Dungeon battle enemy creation  
- `create_enemies_for_raid(raid_id, difficulty, wave)` - Raid battle enemy creation

### Wave-Based Creation (3 methods)
- `create_enemies_for_dungeon_wave(dungeon_id, difficulty, wave_number)` - Specific dungeon wave
- `create_enemies_for_territory_wave(territory, stage, wave_number)` - Specific territory wave
- `create_enemies_for_raid_wave(raid_id, difficulty, wave_number, enemy_count)` - Specific raid wave

### Stat Calculation (2 methods) 
- `_calculate_enemy_stats(element, enemy_type, level, tier)` - Territory/general enemy stats
- `_calculate_dungeon_enemy_stats(element, enemy_type, level, difficulty)` - Dungeon-specific stats with difficulty multipliers

### Configuration & Utility (12 methods)
- `_get_stage_enemy_count(stage)` - Determine enemy count for territory stage
- `_get_stage_enemy_composition(stage)` - Determine enemy type composition for stage
- `_get_base_level_for_territory_tier(tier)` - Base level calculation for territory tiers
- `_get_element_display_name(element)` - Convert element string to display name
- `_get_enemy_type_multipliers(enemy_type)` - Stat multipliers for different enemy types
- `_get_enemy_ai_behavior(enemy_type)` - AI behavior configuration for enemy types
- `_get_dungeon_config(dungeon_id, difficulty)` - Dungeon configuration with UI limits
- `_get_dungeon_element(dungeon_id)` - Extract element from dungeon ID
- `_get_dungeon_enemy_level(difficulty)` - Base level for dungeon difficulties
- `_create_dungeon_enemy(dungeon_id, difficulty, level, enemy_index, total_enemies)` - Single dungeon enemy
- `_create_territory_enemy(territory, level, enemy_type)` - Single territory enemy
- `_create_raid_enemy(raid_id, difficulty, level, enemy_type)` - Single raid enemy

### Enhancement & Validation (5 methods)
- `create_enhanced_enemy(base_enemy, enhancement_level)` - Create enhanced enemy variants
- `create_boss_variant(territory, stage, variant_name)` - Create special boss variants
- `validate_enemy(enemy)` - Validate enemy data structure completeness
- `get_enemy_power_rating(enemy)` - Calculate enemy power rating for matchmaking

## Signals
**Emitted**: None (static factory class)
**Received**: None (static factory class)

## Key Data Structures

### Enemy Dictionary Structure
```gdscript
enemy = {
    "name": String,           # Display name
    "level": int,            # Enemy level
    "hp": int,               # Max HP
    "current_hp": int,       # Current HP
    "attack": int,           # Attack stat
    "defense": int,          # Defense stat  
    "speed": int,            # Speed stat
    "crit_rate": int,        # Critical hit rate %
    "crit_damage": int,      # Critical damage %
    "resistance": int,       # Status resistance %
    "accuracy": int,         # Accuracy %
    "element": int/String,   # Element type
    "type": String,          # Enemy type (basic/elite/leader/boss)
    "status_effects": Array, # Status effect tracking
    "shield_hp": int,        # Shield points
    "battle_index": int,     # UI tracking index
    "ai_behavior": Dictionary/String, # AI behavior configuration
    "abilities": Array,      # Available abilities
    "special_traits": Array  # Special characteristics
}
```

### Enemy Types (4 tiers)
- **basic**: Baseline enemies (0.8x HP, 0.9x ATK, 0.8x DEF multipliers)
- **leader**: Support-focused (1.1x HP, 1.0x ATK, 0.9x DEF, +20 ACC)
- **elite**: Strong balanced (1.2x HP, 1.1x ATK, 1.0x DEF, +5 CR)
- **boss**: Powerful tanks (1.6x HP, 1.3x ATK, 1.2x DEF, +10 CR, +20 CD, +25 RES)

### Difficulty Scaling (7 tiers)
- **beginner**: 1.0x multiplier, Level 15
- **intermediate**: 1.3x multiplier, Level 25  
- **advanced**: 1.6x multiplier, Level 35
- **expert**: 2.0x multiplier, Level 45
- **master**: 2.5x multiplier, Level 55
- **heroic**: 3.0x multiplier, Level 65
- **legendary**: 3.5x multiplier, Level 75

## Notable Patterns
- **Factory Pattern**: Multiple creation methods for different battle types
- **Unified Entry Point**: Single method handles all battle types via BattleFactory
- **Scalable Stats**: Complex stat calculations with multiple multipliers
- **UI Constraints**: Enforces 4-enemy maximum across all systems
- **Wave Progression**: Progressive difficulty scaling across waves
- **Element Integration**: Full element system integration

## Code Quality Issues

### Anti-Patterns Found
1. **Massive Responsibility**: 865 lines handling all enemy creation logic
2. **Complex Calculations**: Multiple nested multiplier calculations
3. **Magic Numbers**: Hard-coded stat values and multipliers throughout
4. **Duplicated Logic**: Similar stat calculation patterns across different methods
5. **Mixed Abstraction**: High-level factory mixed with low-level stat calculations

### Positive Patterns  
1. **Factory Design**: Clean separation of creation concerns
2. **Unified Interface**: Single entry point through BattleFactory integration
3. **Validation**: Built-in enemy validation system
4. **Enhancement Support**: Framework for enemy variants and enhancements
5. **UI Awareness**: Consistent UI limit enforcement (4 enemies max)

## Architectural Notes

### Strengths
- **Comprehensive Coverage**: Handles all battle types and scenarios
- **Balanced Scaling**: Well-designed stat progression and difficulty scaling
- **Flexible Creation**: Support for special variants and enhancements
- **Performance**: Static methods with no state management overhead

### Concerns
- **Monolithic Design**: Single class handling too many creation scenarios
- **Complex Dependencies**: Relies on multiple external systems for configuration
- **Hard-coded Balance**: Stat values and multipliers embedded in code
- **Calculation Complexity**: Difficult to understand and tune balance

## **CRITICAL OVERLAP ANALYSIS** 🚨

### **HUGE DUPLICATE POTENTIAL** with:
- **CombatCalculator**: Both calculate stat breakdowns and power ratings
- **Territory.gd**: Both handle territory-based stat calculations
- **DataLoader**: Both access and process enemy configuration data
- **God.gd**: Similar stat calculation patterns and power rating logic

### **ARCHITECTURAL OVERLAPS**:
- **Stat Calculation**: Duplicates God stat calculation patterns
- **Element Handling**: Duplicates Territory element conversion logic  
- **Power Rating**: Similar to God power rating calculations
- **Configuration Access**: Duplicates DataLoader enemy data access

## Refactoring Recommendations
1. **Split by Battle Type**:
   - TerritoryEnemyFactory
   - DungeonEnemyFactory  
   - RaidEnemyFactory
   - ArenaEnemyFactory

2. **Extract Stat Calculator**: Create shared StatCalculator for Gods and Enemies
3. **Configuration-Driven**: Move all stat values and multipliers to JSON
4. **Unify Power Rating**: Single power rating system for Gods and Enemies
5. **Element System**: Centralized element handling utilities

## **WHO CALLS WHO** - Connection Map

### **INBOUND CONNECTIONS** (Who calls EnemyFactory):
- **BattleManager**: create_enemies_for_battle() for all battles
- **DungeonSystem**: create_enemies_for_dungeon() for dungeon setup  
- **TerritoryScreen**: create_enemies_for_stage() for enemy previews
- **WaveSystem**: Wave-based creation methods for multi-wave battles

### **OUTBOUND CONNECTIONS** (Who EnemyFactory calls):
- **DataLoader**: Element conversion and enemy type data access
- **GameManager.get_dungeon_system()**: Dungeon configuration data
- **Territory object**: Element and tier data for stat calculations

## Stat Calculation Formulas

### Base Stat Formula
```gdscript
final_stat = (base_stat + level * growth_per_level) * type_multiplier * tier_multiplier * difficulty_multiplier
```

### Type Multipliers
- **HP**: basic(0.8x) → leader(1.1x) → elite(1.2x) → boss(1.6x)
- **ATK**: basic(0.9x) → leader(1.0x) → elite(1.1x) → boss(1.3x)  
- **DEF**: basic(0.8x) → leader(0.9x) → elite(1.0x) → boss(1.2x)

### Level Scaling
- **Territory**: 8 HP + 4 ATK + 3 DEF per level
- **Dungeon**: 8% multiplicative per level (exponential scaling)
- **Speed**: Minimal scaling (1-2% per level)

## UI Constraint Enforcement
**CRITICAL**: All methods enforce 4-enemy maximum for UI compatibility:
- Territory stages capped at 4 enemies
- Dungeon waves capped at 4 enemies  
- Raid formations capped at 4 enemies
- Wave progression respects UI limits

## Missing Features
1. **AI Integration**: AI behavior data created but not fully integrated
2. **Ability System**: Abilities assigned but not implemented
3. **Formation System**: Basic positioning but no advanced formations
4. **Status Immunities**: No innate status immunity system
5. **Scaling Configuration**: Hard-coded values should be configurable

This factory is DOING EVERYTHING for enemy creation - perfect target for splitting apart! 🎯

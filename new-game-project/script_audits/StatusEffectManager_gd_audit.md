# StatusEffectManager.gd Audit Report

## File Overview
- **File Path**: scripts/systems/StatusEffectManager.gd
- **Line Count**: 396 lines
- **Primary Purpose**: Central status effect processing and management system
- **Architecture Type**: Static utility class with extensive status effect factory

## Signal Interface (2 signals)
### Outgoing Signals
1. `status_effect_applied(target, effect)` - When status effect is applied to target
2. `status_effect_removed(target, effect_id)` - When status effect is removed

## Method Inventory (13 static methods)
### Core Status Effect Processing
- `process_turn_start_effects(unit, manager: StatusEffectManager)` - Process turn start effects
- `process_turn_end_effects(unit, manager: StatusEffectManager)` - Process turn end effects
- `apply_status_effect_to_target(target, effect: StatusEffect, manager: StatusEffectManager)` - Apply effect to target
- `remove_status_effect_from_target(target, effect_id: String, manager: StatusEffectManager)` - Remove specific effect

### Status Effect Manipulation
- `cleanse_target(target, manager: StatusEffectManager)` - Remove all debuffs from target
- `dispel_buffs_from_target(target, count: int, manager: StatusEffectManager)` - Remove buffs from target
- `has_status_effect(target, effect_id: String)` - Check if target has specific effect

### Status Effect Factory
- `create_status_effect_from_id(effect_id: String, caster)` - **MASSIVE** factory method for 30+ effects

### Enemy Processing (Private)
- `_process_enemy_turn_start_effects(enemy: Dictionary)` - Process enemy turn start effects
- `_process_enemy_turn_end_effects(enemy: Dictionary)` - Process enemy turn end effects
- `_get_unit_name(unit)` - Get name from God or dictionary

## Key Dependencies
### External Dependencies
- **StatusEffect.gd** - Heavy dependency for status effect creation and data structure
- **God.gd** - Heavy dependency for god status effect processing
- **Enemy system** - Dictionary-based enemy status effects

### Internal State
- No persistent state (static utility class)

## Duplicate Code Patterns Identified
### MAJOR OVERLAPS (HIGH PRIORITY):
1. **Status Effect Processing Overlap with God.gd**:
   - Turn-based effect processing logic overlaps with God.gd methods
   - Similar DOT/HOT processing patterns in both classes
   - **Duplicate effect application logic**
   - RECOMMENDATION: Centralize all processing in StatusEffectManager

2. **Massive Status Effect Factory Duplication**:
   - `create_status_effect_from_id()` contains **50+ case statements** for effect creation
   - **Same effect creation logic** likely duplicated in StatusEffect.gd static methods
   - **Redundant effect mapping** (aliases pointing to same effects)
   - RECOMMENDATION: Consolidate effect creation in StatusEffect.gd

3. **Enemy vs God Processing Duplication**:
   - `_process_enemy_turn_start_effects()` duplicates God processing logic
   - **Two parallel processing systems** for same functionality
   - RECOMMENDATION: Unify under single interface

### MEDIUM OVERLAPS:
4. **Effect Manipulation Pattern Overlap**:
   - Status effect add/remove patterns similar to InventoryManager item operations
   - RECOMMENDATION: Consider shared utility patterns

5. **Unit Type Handling Overlap**:
   - God vs Dictionary handling patterns likely repeated elsewhere
   - RECOMMENDATION: Create unified unit interface

## Architectural Issues
### Single Responsibility Violations
- **CRITICAL**: This class handles 4 distinct responsibilities:
  1. Status effect processing
  2. Status effect application/removal
  3. Status effect factory creation
  4. Enemy vs God differentiation

### Massive Factory Method
- **`create_status_effect_from_id()`** contains 50+ case statements
- **300+ lines** of effect creation logic
- Should be externalized or distributed

### Dual Processing Systems
- **Separate logic** for God vs Enemy status effects
- **Code duplication** between processing paths
- Should be unified under common interface

## Refactoring Recommendations
### IMMEDIATE (High Impact):
1. **Consolidate status effect creation**:
   - Move all effect creation to StatusEffect.gd
   - Remove duplicate factory method
   - **Eliminate 100+ lines of duplicate code**

2. **Unify processing logic**:
   - Create common interface for God and Enemy processing
   - Eliminate separate processing methods
   - Centralize all effect logic

3. **Extract effect processing to dedicated system**:
   - `StatusEffectProcessor` for turn-based processing
   - `StatusEffectApplicator` for application/removal
   - Keep StatusEffectManager as coordinator

### MEDIUM (Maintenance):
4. **Create unified unit interface**:
   - Common interface for God and Enemy units
   - Eliminate type-specific handling

5. **Extract effect manipulation utilities**:
   - Shared utilities for effect add/remove operations
   - Consistent operation patterns

## Connectivity Map
### Strongly Connected To:
- **StatusEffect.gd**: Heavy dependency for effect creation and data
- **God.gd**: Heavy integration for god status effect processing
- **BattleManager**: Turn-based processing coordination

### Moderately Connected To:
- **Enemy system**: Dictionary-based enemy processing
- **BattleEffectProcessor**: Effect processing coordination

### Weakly Connected To:
- **UI components**: Status effect display and updates

### Signal Consumers (Likely):
- **BattleManager**: Status effect application/removal notifications
- **UI components**: Status effect visual updates
- **BattleEffectProcessor**: Effect processing coordination

## Notes for Cross-Reference
- **Status effect patterns**: Compare with StatusEffect.gd for consolidation opportunities
- **Processing patterns**: Compare with God.gd for shared processing logic
- **Factory patterns**: Look for similar factory methods in other classes
- **Unit handling patterns**: Check for God vs Dictionary handling in other systems
- **This class has significant architectural issues requiring major refactoring**

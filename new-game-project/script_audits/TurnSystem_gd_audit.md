# TurnSystem.gd Audit Report

## Overview
- **File**: `scripts/systems/TurnSystem.gd`
- **Type**: Turn Order Management System
- **Lines of Code**: 171
- **Class Type**: RefCounted (Pure system service)

## Purpose
Manages turn order and advancement in battle systems. Handles speed-based turn order calculation, dead unit removal, and turn cycle management for both gods and enemies.

## Dependencies
### Inbound Dependencies (What this relies on)
- **God objects**: get_current_speed(), current_hp, can_act(), name properties
- **Enemy dictionaries**: speed, current_hp, name, status_effects properties
- **StatusEffect objects**: prevents_action property

### Outbound Dependencies (What depends on this)
- **BattleManager**: Turn order management and battle flow control
- **BattleAI**: AI decision making based on current acting unit
- **Battle UI**: Turn indicator displays and unit action prompts

## Signals (2 signals)
**Emitted**:
- `turn_started(unit)` - Unit begins their turn
- `turn_ended(unit)` - Unit finishes their turn

**Received**: None (service class)

## Instance Variables (3 variables)
- `turn_order: Array` - Array of turn entry dictionaries with unit, speed, is_god
- `current_turn_index: int` - Index of currently acting unit
- `current_acting_unit` - Reference to currently acting unit object

## Method Inventory

### Core Turn Management (4 methods)
- `clear_turn_order()` - Reset turn system to initial state
- `setup_turn_order(gods, enemies)` - Create initial turn order based on speed
- `get_current_unit()` - Get currently acting unit (with cycle management)
- `advance_turn()` - Move to next unit in turn order

### Unit Status Management (3 methods)
- `can_unit_act(unit)` - Check if unit can perform actions (status effect checks)
- `remove_dead_units()` - Remove defeated units and adjust turn index
- `get_units_alive_count(gods, enemies)` - Count living gods and enemies

### Turn Cycle Management (1 method)
- `_start_new_turn_cycle()` - Rebuild turn order with updated speeds

### Helper Methods (3 methods)
- `_get_current_hp(unit)` - Get HP from God or dictionary
- `_get_unit_name(unit)` - Get name from God or dictionary  
- `_get_current_speed(unit)` - Get speed from God or dictionary

## Key Data Structures

### Turn Order Entry
```gdscript
{
    "unit": god_or_enemy_object,
    "speed": int_speed_value,
    "is_god": boolean_flag
}
```

### Unit Alive Count
```gdscript
{
    "gods": int_alive_count,
    "enemies": int_alive_count
}
```

## Algorithm Details

### Speed-Based Turn Order
1. **Collection**: Gather all living gods and enemies
2. **Speed Calculation**: Get current speed for each unit
3. **Sorting**: Sort by speed (highest first) using custom comparator
4. **Indexing**: Reset turn index to 0 for new cycle

### Turn Advancement Logic
1. **Signal Emission**: Emit turn_ended for current unit
2. **Index Increment**: Move to next position in turn order
3. **Cycle Detection**: Check if all units have acted
4. **Auto-Restart**: Begin new cycle if turn order complete

### Dead Unit Removal
1. **HP Check**: Verify current_hp > 0 for each unit
2. **Array Rebuild**: Create new array with only living units
3. **Index Adjustment**: Prevent index out-of-bounds after removal
4. **Preservation**: Maintain relative turn order positions

## Notable Patterns
- **Polymorphic Unit Handling**: Works with both God objects and enemy dictionaries
- **Speed-Based Priority**: Fastest units act first each cycle
- **Automatic Cycle Management**: Seamlessly restarts turn cycles
- **Status Effect Integration**: Respects disable conditions
- **Debug Output**: Turn order logging for battle analysis

## Code Quality Assessment

### Strengths
1. **Clean Architecture**: Single responsibility for turn management
2. **Polymorphic Design**: Handles different unit types elegantly
3. **Robust State Management**: Proper cycle and index handling
4. **Performance Conscious**: Efficient sorting and array operations
5. **Debugging Support**: Clear logging and state information

### Minor Issues
1. **Hard-coded Enemy Speed**: Default speed of 70 for enemies
2. **Limited Status Effect Types**: Only checks prevents_action
3. **No Turn History**: No tracking of previous turns
4. **Magic Numbers**: Hard-coded default values

## **OVERLAP ANALYSIS** 

### **MINIMAL OVERLAP** - This is a GOOD system! ✅
- **BattleManager.gd**: May have some turn tracking overlap but this system is more focused
- **StatusEffectManager.gd**: Both check status effects but different purposes
- **No significant duplicates found** - this is properly abstracted!

### **CLEAN ARCHITECTURE**:
- **Single Responsibility**: Only manages turn order and advancement
- **Clear Interface**: Simple methods with obvious purposes  
- **No God Class**: Reasonable size at 171 lines
- **Proper Separation**: Doesn't mix battle logic with turn logic

## Refactoring Recommendations

### Minor Improvements
1. **Configuration**: Move default enemy speed to configuration
2. **Status Effect Expansion**: Support more disable condition types
3. **Turn History**: Add optional turn logging capability
4. **Speed Calculation**: Abstract speed calculation logic

### Suggested Enhancements
1. **Initiative System**: Add initiative bonuses/penalties
2. **Turn Delay**: Support for delayed actions
3. **Speed Buffs**: Handle temporary speed modifications
4. **Turn Skipping**: Support for stun/freeze duration tracking

## **WHO CALLS WHO** - Connection Map

### **INBOUND CONNECTIONS** (Who calls TurnSystem):
- **BattleManager**: setup_turn_order(), get_current_unit(), advance_turn(), remove_dead_units()
- **BattleAI**: get_current_unit() to determine AI actions
- **Battle UI**: Current unit display and turn indicators

### **OUTBOUND CONNECTIONS** (Who TurnSystem calls):
- **God objects**: get_current_speed(), current_hp, can_act(), name
- **Enemy dictionaries**: Direct property access for speed, hp, name
- **StatusEffect objects**: prevents_action property checks

## Performance Characteristics
- **O(n log n)** for initial turn order setup (sorting)
- **O(n)** for dead unit removal and cycle restart
- **O(1)** for turn advancement and current unit access
- **Minimal Memory**: Only stores references and indices

## Integration Points
- **Battle System**: Core integration with battle flow
- **AI System**: Provides current acting unit for AI decisions
- **UI System**: Turn indicators and action prompts
- **Status System**: Respects action-preventing effects

## Missing Features
1. **Turn Timers**: No time limits for actions
2. **Initiative Variants**: No alternative turn calculation methods
3. **Turn Prediction**: No lookahead for turn planning
4. **Interrupts**: No support for interrupt actions
5. **Turn Statistics**: No tracking of turn duration or patterns

This is actually one of the BETTER architected systems! It does ONE thing well and doesn't try to be everything. A good example of proper system design! 🎯

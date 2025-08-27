# BattleEffectProcessor.gd Audit Report

## Overview
- **File**: `scripts/systems/BattleEffectProcessor.gd`
- **Type**: Static Effect Processing System
- **Lines of Code**: 496
- **Class Type**: RefCounted (Static utility class)

## Purpose
Modular Summoners War-style battle effect processor. Handles all effect application logic for battles, separated from StatusEffectManager which handles status effect lifecycle.

## Dependencies
### Inbound Dependencies (What this relies on)
- **StatusEffect** (data): StatusEffect.create_shield(), status effect data structures
- **StatusEffectManager** (systems): create_status_effect_from_id(), apply_status_effect_to_target(), cleanse_target(), dispel_buffs_from_target()
- **God** (data): God object properties and methods
- **BattleManager** (systems): battle_context dictionary with references
- **BattleScreen** (ui): update_god_hp_instantly(), update_god_status_effects(), update_enemy_hp_instantly(), update_enemy_status_effects()

### Outbound Dependencies (What depends on this)
- **BattleManager**: Uses for processing all battle ability effects
- **Ability processing systems**: Any system that applies battle effects

## Method Inventory

### Main Entry Point
- `process_single_effect(effect_type, effect_data, caster, target, ability, battle_context)` - Central effect dispatcher

### Core Effect Methods (17 types)
- `_process_heal_effect()` - Healing with scaling options
- `_process_shield_effect()` - Shield creation with scaling
- `_process_buff_effect()` - Single target buff application
- `_process_debuff_effect()` - Single target debuff application
- `_process_self_buff_effect()` - Self-targeting buff
- `_process_cleanse_effect()` - Remove debuffs from target
- `_process_cleanse_all_effect()` - Remove debuffs from all allies
- `_process_strip_effect()` - Remove buffs from enemy
- `_process_strip_all_effect()` - Remove buffs from all enemies
- `_process_life_drain_effect()` - Heal based on damage dealt
- `_process_additional_turn_effect()` - Grant extra turn (not implemented)

### ATB Manipulation (4 methods - all not implemented)
- `_process_atb_increase_effect()` - Increase action turn bar
- `_process_atb_decrease_effect()` - Decrease action turn bar
- `_process_atb_steal_effect()` - Steal ATB from target
- `_process_self_atb_increase_effect()` - Self ATB boost

### Team Effects (4 methods)
- `_process_team_buff_effect()` - Buff all allies
- `_process_team_heal_effect()` - Heal all allies
- `_process_team_atb_increase_effect()` - Team ATB boost (not implemented)
- `_process_team_cleanse_all_effect()` - Team cleanse wrapper

### Smart/Conditional Effects (3 methods)
- `_process_smart_heal_effect()` - Heal ally with lowest HP%
- `_process_conditional_buff_effect()` - Simplified implementation
- `_process_conditional_debuff_effect()` - Simplified implementation

### Random Effects (4 methods)
- `_process_random_buff_effect()` - Apply random buff
- `_process_random_debuffs_effect()` - Apply random debuffs
- `_process_random_team_buff_effect()` - Random team buff
- `_process_random_debuff_per_hit_effect()` - Random debuff per hit

### Advanced Effects (5 methods)
- `_process_steal_buff_effect()` - Steal enemy buffs
- `_process_sequential_debuffs_effect()` - Apply multiple debuffs in sequence
- `_process_reset_buff_duration_effect()` - Reset buff timers (not implemented)
- `_process_max_hp_reduction_effect()` - Reduce max HP (not implemented)
- `_process_revive_all_effect()` - Revive all allies (not implemented)
- `_process_random_team_buff_or_enemy_debuff_effect()` - Random team/enemy effect

### Utility Methods (4 methods)
- `_get_stat()` - Unified stat retrieval for God objects or dictionaries
- `_set_hp()` - Unified HP setting for God objects or dictionaries
- `_emit_battle_log()` - Send battle log messages
- `_update_unit_ui()` - Update UI for affected units

## Signals
**Emitted**: None (static class)
**Received**: None (static class)

## Key Data Structures
- **effect_data**: Dictionary containing effect parameters (value, scaling, duration, chance)
- **battle_context**: Dictionary containing battle state and references
- **Scaling types**: "target_max_hp", "caster_attack", "MAX_HP", "ATK"
- **Effect types**: 25+ different effect types handled

## Notable Patterns
- **Effect Type Matching**: Large match statement for effect type dispatch
- **Scaling Calculations**: Multiple scaling formulas for different effect types
- **Chance-based Effects**: Random number generation for effect success
- **Unified Object Handling**: Works with both God objects and dictionary enemies
- **Battle Context Pattern**: Uses dictionary to pass references and state

## Code Quality Issues

### Anti-Patterns Found
1. **Incomplete Implementation**: Many ATB effects marked as "not implemented"
2. **Simplified Effects**: Several conditional effects have simplified/placeholder implementations
3. **Mixed Object Types**: Handles both God objects and dictionaries (creates complexity)
4. **Large Match Statement**: Single massive match for 25+ effect types
5. **Print Debugging**: Extensive print statements throughout

### Positive Patterns
1. **Single Responsibility**: Each effect method handles one specific effect type
2. **Static Design**: No state, pure functional approach
3. **Unified Helpers**: Good abstraction for stat access across object types
4. **Modular Structure**: Clear separation of effect categories

## Architectural Notes

### Strengths
- **Comprehensive Coverage**: Handles wide variety of battle effects
- **Modular Design**: Each effect type isolated in its own method
- **Flexible Scaling**: Multiple scaling options for effects
- **Battle Context**: Good use of context object for state passing

### Concerns
- **Implementation Gaps**: Many placeholder implementations
- **Complex Object Handling**: Dual God/dictionary support adds complexity
- **Effect Explosion**: 25+ effect types in one class suggests need for sub-categorization
- **Testing Challenges**: Static methods make unit testing difficult

## Duplicate Code Potential
- **Stat Access Patterns**: `_get_stat()` and `_set_hp()` patterns repeated
- **Effect Application**: Similar patterns for buff/debuff application
- **UI Update Calls**: Repeated `_update_unit_ui()` and `_emit_battle_log()` calls
- **Chance Checking**: Similar random chance patterns across effects

## Refactoring Recommendations
1. **Split by Category**: Separate into HealingEffects, BuffEffects, ATBEffects, etc.
2. **Complete Implementation**: Finish placeholder ATB and conditional effects
3. **Standardize Object Types**: Choose either God objects OR dictionaries consistently
4. **Effect Factory**: Consider factory pattern for effect creation
5. **Remove Debug Prints**: Clean up debug output for production

## Integration Points
- **StatusEffectManager**: Heavy dependency for effect creation and application
- **BattleManager**: Primary consumer of effect processing
- **BattleScreen**: UI updates for visual feedback
- **God/Enemy objects**: Direct manipulation of unit state

## Security/Safety Notes
- **No Input Validation**: effect_data dictionary not validated
- **Null Safety**: Some null checks present but not comprehensive
- **Random Seed**: Uses global random state (could affect reproducibility)

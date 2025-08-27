# CombatCalculator.gd Audit Report

## Overview
- **File**: `scripts/systems/CombatCalculator.gd`
- **Type**: Combat Calculation Engine
- **Lines of Code**: 519
- **Class Type**: RefCounted (Static utility class)

## Purpose
Authentic Summoners War combat system implementation with proper damage formulas, stat calculations, and combat mechanics. Provides detailed breakdown calculations for transparency and debugging.

## Dependencies
### Inbound Dependencies (What this relies on)
- **God** (data): God object stats and status effects
- **StatusEffect** (data): Status effect modifiers and stat calculations
- **Enemy dictionaries**: Enemy stats for combat calculations

### Outbound Dependencies (What depends on this)
- **BattleManager**: Uses for all combat calculations
- **BattleEffectProcessor**: May use for effect damage calculations
- **UI Systems**: Uses breakdown data for combat information display

## Method Inventory

### Main Combat Execution (3 methods)
- `execute_basic_attack(attacker, target)` - Full basic attack with SW formulas and breakdown
- `execute_ability_damage(caster, ability, target)` - Ability damage with multipliers and special effects
- `execute_healing(healer, ability, target)` - Healing calculations with status effect modifications

### Detailed Stat Breakdowns (2 methods)
- `get_detailed_attack_breakdown(unit)` - Step-by-step attack calculation with status effects
- `get_detailed_defense_breakdown(unit)` - Step-by-step defense calculation with status effects

### Hit/Crit Checking (2 methods)
- `check_hit_accuracy(attacker, target)` - Accuracy vs evasion calculations
- `check_critical_hit(attacker, target, damage_type, guaranteed_crit)` - Critical hit determination

### Stat Accessors (9 methods)
- `get_attack(unit)` - Unified attack value from God or enemy
- `get_defense(unit)` - Unified defense value from God or enemy
- `get_max_hp(unit)` - Unified max HP value from God or enemy
- `get_accuracy(unit)` - Unified accuracy value from God or enemy
- `get_evasion(unit)` - Unified evasion value from God or enemy
- `get_critical_chance(unit)` - Critical rate as decimal
- `get_critical_damage_multiplier(unit)` - Legacy crit damage multiplier
- `get_critical_damage_percentage(unit)` - Crit damage as percentage for SW formula
- `get_element_crit_bonus(attacker, target)` - Elemental advantage bonus (not implemented)

### Advanced Analysis (2 methods)
- `calculate_weighted_stats_constant(unit)` - SW weighted stats formula analysis
- `analyze_critical_balance(unit)` - CR vs CD balance optimization analysis

### Combat Modifiers (2 methods)
- `get_damage_multiplier(target)` - Status effect damage multipliers
- `modify_healing(target, base_healing)` - Healing modifications from status effects

## Signals
**Emitted**: None (static class)
**Received**: None (static class)

## Key Data Structures

### Combat Result Dictionaries
- **Attack Result**: damage, is_critical, hit_success, breakdown
- **Healing Result**: heal_amount, actual_heal, is_overheal, breakdown
- **Breakdown**: attacker_stats, defender_stats, calculation_steps

### SW Formulas Implemented
- **Damage**: `ATK × Multiplier × (100% + SkillUp + CritDamage)`
- **Defense Reduction**: `1000/(1140 + 3.5 × Defense)`
- **Weighted Stats**: `ATK + DEF + HP/15 = 1317 + 165×(natural_grade)`
- **Hit Chance**: `(Accuracy - Evasion) / 100` (15% minimum)

## Notable Patterns
- **Authentic SW Formulas**: Uses official Summoners War damage calculations
- **Detailed Breakdowns**: Provides step-by-step calculation transparency
- **Unified Object Handling**: Works with both God objects and enemy dictionaries
- **Null Safety**: Extensive null checking throughout
- **Static Design**: Pure functional approach with no state

## Code Quality Issues

### Anti-Patterns Found
1. **Incomplete Implementation**: Element bonus system not implemented
2. **Magic Numbers**: Hard-coded constants (1140, 3.5, 1317, 165)
3. **Mixed Object Types**: Handles both God objects and dictionaries
4. **Extensive Print Debugging**: Debug prints throughout for null checks

### Positive Patterns
1. **Authentic Formulas**: Uses verified Summoners War calculations
2. **Detailed Breakdowns**: Excellent transparency for debugging
3. **Single Responsibility**: Each method has clear, focused purpose
4. **Null Safety**: Comprehensive null checking
5. **Documentation**: Well-documented formulas with wiki references

## Architectural Notes

### Strengths
- **Formula Accuracy**: Implements authentic SW combat mechanics
- **Calculation Transparency**: Detailed breakdowns for all calculations
- **Flexible Design**: Handles multiple unit types cleanly
- **Balance Analysis**: Built-in optimization analysis tools

### Concerns
- **Incomplete Features**: Elemental system not implemented
- **Object Type Confusion**: God vs dictionary handling creates complexity
- **Hard-coded Constants**: SW constants should be configurable
- **No Caching**: Recalculates everything each time

## Duplicate Code Potential
- **Stat Accessor Pattern**: Similar null checking and value extraction across get_*() methods
- **Breakdown Generation**: Similar breakdown structure in attack/defense methods
- **Unit Type Checking**: Repeated `if unit is God` patterns
- **Null Safety**: Repeated null checking patterns

## Refactoring Recommendations
1. **Unit Interface**: Create common interface for God and enemy stat access
2. **Configuration System**: Move hard-coded SW constants to configuration
3. **Complete Elemental**: Implement full elemental advantage system
4. **Caching Layer**: Cache calculations for performance
5. **Formula Registry**: Make formulas configurable/pluggable

## Integration Points
- **BattleManager**: Primary consumer for all combat calculations
- **God Class**: Direct access to god stats and status effects
- **StatusEffect**: Uses for stat modifiers and combat effects
- **UI Systems**: Breakdown data used for combat information display

## Security/Safety Notes
- **Null Protection**: Comprehensive null checking prevents crashes
- **Input Validation**: Limited validation of ability dictionaries
- **Bounds Checking**: Uses clamp() for critical values
- **Minimum Damage**: Ensures minimum damage values (5-10 damage)

## SW Formula Implementation
The class implements authentic Summoners War formulas:

### Core Damage Formula
```gdscript
# SW: Damage = TotalAttack × Multiplier × (100% + SkillUp + CritDamage)
var raw_damage = final_attack * skill_multiplier * (1.0 + skill_up_bonus/100.0 + crit_damage_bonus/100.0)
```

### Defense Reduction
```gdscript
# SW: DamageReductionFactor = 1000/(1140 + 3.5 × Defense)
var defense_reduction_factor = 1000.0 / (1140.0 + 3.5 * final_defense)
```

### Weighted Stats Constant
```gdscript
# SW: ATK + DEF + HP/15 = 1317 + 165×(natural_grade)
var constitution = hp / 15.0
var weighted_sum = attack + defense + constitution
```

## Missing Features
1. **Elemental System**: Fire > Earth > Lightning > Water > Fire cycle
2. **Leader Skills**: Stat bonuses for team
3. **Rune System**: Equipment stat bonuses
4. **Skill Cooldowns**: Turn-based skill availability
5. **Speed Tuning**: Attack bar and turn order calculations

## Performance Considerations
- **No Caching**: Recalculates stats each time
- **String Concatenation**: Heavy string building in breakdowns
- **Array Operations**: Status effect iteration for each calculation
- **Random Generation**: Multiple random calls per combat action

# BattleAI.gd Audit Report

## File Info
- **Path**: `scripts/systems/BattleAI.gd`
- **Type**: AI Controller (extends RefCounted)
- **Purpose**: Battle AI for both player auto-battle and enemy decisions
- **Lines**: 426 lines - **LARGE AI SYSTEM**

## Incoming Dependencies
- God.gd - Player units with abilities and stats
- Enemy dictionaries - Enemy unit data structure
- StatusEffect system - For status effect checking

## Outgoing Signals
- None (static utility class)

## Class Properties
- **None** (All static methods)

## Methods (Static Only) - 20+ methods!
### Main AI Decision Methods
- `choose_god_auto_action(god, enemies, allies)` - **MAIN** Auto-battle AI for gods
- `choose_enemy_action(enemy, enemy_allies, god_enemies)` - **MAIN** Enemy AI decisions

### God AI Helper Methods (9 methods)
- `_find_healing_ability(god)` - Find healing abilities
- `_find_cleanse_ability(god)` - Find cleanse/dispel abilities
- `_find_buff_ability(god)` - Find buff abilities
- `_find_aoe_ability(god)` - Find AOE damage abilities
- `_find_nuke_ability(god)` - Find high damage single-target abilities
- `_find_best_available_ability(god)` - Find any usable ability
- `_choose_buff_target(god, allies, ability)` - Target selection for buffs
- `_choose_damage_target(enemies)` - **SMART** Damage target prioritization
- `_choose_ability_target(god, ability, enemies, allies)` - Context-aware targeting

### Enemy AI Helper Methods (5 methods)
- `_choose_enemy_target(target_pool, target_priority, enemy)` - Enemy target selection
- `_should_use_ability(enemy, ability_usage, aggression)` - Ability vs attack decision
- `_choose_enemy_ability(enemy, target)` - Enemy ability selection
- `_calculate_target_score(god)` - Balanced targeting algorithm
- `_is_god_targetable(god)` - Check if god can be targeted

### Utility Methods (3 methods)
- `_get_unit_name(unit)` - Get name from God or dictionary
- `evaluate_battlefield_state(gods, enemies)` - **ADVANCED** Battlefield analysis
- `predict_turn_outcome(attacker, target, action)` - **FUTURE** Outcome prediction

## AI Priority Systems
### God Auto-Battle Priorities (7 levels)
1. **Emergency heal** - Ally below 30% HP
2. **Cleanse debuffs** - Remove negative effects
3. **Apply buffs** - When team has no buffs
4. **AOE attacks** - When 3+ enemies present
5. **Nuke low HP** - Finish enemies below 40% HP
6. **Use best ability** - Intelligent ability usage
7. **Basic attack** - Fallback with smart targeting

### Enemy AI Behaviors (4 types)
1. **Target Priority**: lowest_hp, highest_attack, random, balanced
2. **Ability Usage**: always_use_best, smart_cooldown_management, support_allies, basic_attacks_mostly
3. **Aggression**: 0.0-1.0 scaling for ability usage frequency
4. **Special**: Provoke/taunt targeting enforcement

## Data Structures Used
### Action Dictionaries
- `{"action": "attack/ability/skip", "target": unit, "ability": ability_dict}`
- Ability dictionaries with damage_type, targets, special_effects
- AI behavior dictionaries with target_priority, ability_usage, aggression

### Analysis Results
- Battlefield state with HP totals, threat levels, advantage ratios
- Target scores for balanced AI decision making
- Outcome predictions for advanced planning

## Potential Issues & Code Quality
### Strengths
1. **Smart AI**: Well-designed priority system mimicking Summoners War
2. **Flexible**: Handles both gods and enemies with different logic
3. **Extensible**: Framework for advanced AI features
4. **Static Design**: No state management issues

### Code Smells
1. **Large Static Class**: 426 lines of static methods in one class
2. **God/Enemy Duality**: Different handling for god objects vs enemy dictionaries
3. **Magic Numbers**: Hard-coded percentages (30%, 40%, 70%)
4. **Limited Enemy AI**: Enemies have simpler AI than gods

### Potential Issues
1. **Performance**: Complex AI calculations every turn
2. **Predictability**: AI might become too predictable
3. **Balance**: AI priorities might not suit all battle scenarios
4. **Error Handling**: Minimal error handling for missing data

## Recommendations
### Split the Class
1. **GodAutoAI** - Player auto-battle logic
2. **EnemyAI** - Enemy decision making
3. **AIUtilities** - Shared utility methods
4. **BattlefieldAnalyzer** - Advanced analysis features

### Improvements
1. **Add Constants**: Define all percentage thresholds as constants
2. **Improve Enemy AI**: Give enemies more sophisticated abilities
3. **Add Randomization**: Prevent AI from being too predictable
4. **Performance Optimization**: Cache battlefield analysis results

### Architecture
1. Consider strategy pattern for different AI personalities
2. Add configuration system for AI behavior tuning
3. Implement learning/adaptation mechanisms

## Connected Systems
- BattleManager.gd - Uses AI for auto-battle and enemy decisions
- God.gd - God abilities and status effects
- Enemy system - Enemy data structures and behaviors
- StatusEffect.gd - Status effect checking and management
- CombatCalculator.gd - Damage calculations (likely)

## Key Integration Points
### Critical Methods for Other Systems
1. **`choose_god_auto_action()`** - Used by BattleManager for auto-battle
2. **`choose_enemy_action()`** - Used by BattleManager for enemy turns
3. **`_choose_damage_target()`** - Core targeting logic

### AI Behavior Configuration
- Enemy AI behaviors defined in enemy data structures
- Ability definitions in god/enemy ability arrays
- Status effect integration for targeting decisions

**This is a sophisticated AI system that could benefit from splitting into focused classes and adding more configuration options.**

# StatusEffect.gd Audit Report

## File Info
- **Path**: `scripts/data/StatusEffect.gd`
- **Type**: Data Class (extends Resource)
- **Purpose**: Status effect system for battle mechanics
- **Lines**: 460 lines

## Incoming Dependencies
- God.gd (through type checking and stats) - for stat calculations

## Outgoing Signals
- None

## Class Properties
### Exported Properties (Core Data)
- `id: String` - Unique effect identifier
- `name: String` - Display name
- `description: String` - Effect description
- `effect_type: EffectType` - BUFF/DEBUFF/DOT/HOT
- `duration: int` - Turns remaining (default: 3)
- `stacks: int` - Stack count (default: 1)
- `can_stack: bool` - Stacking allowed (default: false)
- `max_stacks: int` - Maximum stacks (default: 5)

### Exported Properties (Effect Values)
- `stat_modifier: Dictionary` - Stat bonuses/penalties
- `damage_per_turn: float` - Percentage damage per turn
- `heal_per_turn: float` - Percentage healing per turn
- `shield_value: int` - Shield HP amount
- `prevents_action: bool` - Blocks all actions
- `prevents_abilities: bool` - Blocks ability use
- `immune_to_debuffs: bool` - Debuff immunity
- `immune_to_damage: bool` - Damage immunity

### Exported Properties (Additional Effects)
- `dot_damage: int` - Flat damage over time
- `damage_immunity: bool` - **DUPLICATE** of immune_to_damage
- `charmed: bool` - Forces attacking allies
- `untargetable: bool` - Cannot be targeted
- `counter_attack: bool` - Counter-attack chance
- `reflect_damage: float` - Damage reflection percentage

### Exported Properties (Status Flags)
- `frozen: bool` - Frozen status
- `sleeping: bool` - Sleep status
- `silenced: bool` - Silence status
- `provoked: bool` - Provoke status

### Exported Properties (Visual)
- `icon_path: String` - Icon file path
- `color: Color` - Effect color (default: WHITE)

## Methods (Public)
### Constructor
- `_init(effect_id, effect_name)` - Initialize with ID and name

### Core Mechanics
- `apply_turn_effects(target)` - Apply DoT/HoT effects per turn
- `get_stat_modifier(stat_name)` - Get modifier for specific stat
- `is_expired()` - Check if effect duration is over

### Private Helpers
- `_get_target_name(target)` - Get display name for target
- `_get_attack(caster)` - **STATIC** Get attack stat from caster

## Static Factory Methods (46 methods!)
### Control Effects
- `create_stun(caster, turns)` - Prevent actions
- `create_fear(caster, turns)` - Prevent actions
- `create_freeze(caster, turns)` - Prevent actions + frozen flag
- `create_sleep(caster, turns)` - Prevent actions + sleep flag
- `create_immobilize(caster, turns)` - Prevent actions
- `create_silence(caster, turns)` - Prevent abilities + silence flag
- `create_provoke(caster, turns)` - Force target selection + provoke flag
- `create_charm(caster, turns)` - Force ally attacks + charm flag

### Damage Effects
- `create_burn(caster, turns)` - 15% max HP fire DOT
- `create_continuous_damage(caster, turns)` - 15% max HP DOT (stackable)
- `create_bleed(caster, turns)` - 10% max HP DOT
- `create_poison(caster, turns)` - 5% HP + 8% caster attack DOT

### Healing Effects
- `create_regeneration(caster, turns)` - 15% max HP HOT

### Stat Buffs
- `create_attack_boost(caster, turns)` - +50% attack
- `create_defense_boost(caster, turns)` - +50% defense
- `create_speed_boost(caster, turns)` - +30% speed
- `create_accuracy_boost(caster, turns)` - +50% accuracy
- `create_evasion_boost(caster, turns)` - +30% evasion
- `create_crit_boost(caster, turns)` - +30% crit chance, +20% crit damage
- `create_critical_damage_boost(caster, turns)` - +50% crit damage
- `create_wisdom_boost(caster, turns)` - +20% magic power, +10% cooldown reduction

### Stat Debuffs
- `create_slow(caster, turns)` - -50% speed
- `create_defense_reduction(caster, turns)` - -30% defense
- `create_attack_reduction(caster, turns)` - -30% attack
- `create_blind(caster, turns)` - -50% accuracy
- `create_analyze_weakness(caster, turns)` - +25% damage taken
- `create_marked_for_death(caster, turns)` - **DUPLICATE** +25% damage taken
- `create_curse(caster, turns)` - -50% healing received
- `create_heal_block(caster, turns)` - -100% healing received

### Protection Effects
- `create_shield(caster, turns)` - Shield (50% of caster attack)
- `create_debuff_immunity(caster, turns)` - Debuff immunity
- `create_damage_immunity(caster, turns)` - Complete damage immunity
- `create_untargetable(caster, turns)` - Cannot be targeted
- `create_counter_attack(caster, turns)` - 75% counter chance
- `create_reflect_damage(caster, turns)` - 30% damage reflection

## Data Structures Used
### Enums
- `EffectType` - 4 effect categories

### Dictionaries
- `stat_modifier` - Stat name → modifier value
- Turn effects result with damage/healing/messages

## Potential Issues & Duplicate Code
### Duplicate Methods
1. **Damage Immunity Duplicates**:
   - `damage_immunity: bool` and `immune_to_damage: bool` - Same functionality
2. **Damage Taken Duplicates**:
   - `create_analyze_weakness()` and `create_marked_for_death()` - Identical effects

### Code Smells
1. **Massive Factory Class**: 46 static factory methods in one class
2. **Inconsistent Naming**: Some methods use underscores, others don't
3. **Magic Numbers**: Hard-coded percentages throughout (15%, 50%, 30%)
4. **Parameter Inconsistency**: Some factory methods ignore caster parameter
5. **Duplicate Properties**: Multiple ways to represent same concepts

### Recommendations
1. Remove duplicate properties and methods
2. Split factory methods into separate EffectFactory class
3. Create constants for all percentage values
4. Standardize parameter usage in factory methods
5. Consider using data-driven effect definitions instead of code

## Connected Systems (Likely)
- God.gd - Target for status effects and stat calculations
- BattleManager.gd - Effect application and processing
- BattleEffectProcessor.gd - Turn-by-turn effect processing
- UI components - Effect display and animations
- Enemy classes - Status effect targets
- Ability system - Effect creation and application

## Effect Categories Summary
### Control (8 effects)
Stun, Fear, Freeze, Sleep, Immobilize, Silence, Provoke, Charm

### Damage (4 effects)
Burn, Continuous Damage, Bleed, Poison

### Healing (1 effect)
Regeneration

### Stat Modification (16 effects)
Various attack/defense/speed/accuracy modifications

### Protection (6 effects)
Shield, Immunities, Untargetable, Counter, Reflect

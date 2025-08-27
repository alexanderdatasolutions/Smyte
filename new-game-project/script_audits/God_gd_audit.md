# God.gd Audit Report

## File Info
- **Path**: `scripts/data/God.gd`
- **Type**: Data Class (extends Resource)
- **Purpose**: God/character data structure with battle mechanics
- **Lines**: 657 lines

## Incoming Dependencies
- GameDataLoader (DataLoader.gd) - for god configurations
- StatusEffect.gd - for status effect management
- Equipment.gd (through equipped_runes) - for equipment bonuses
- GameManager - for set bonus calculations

## Outgoing Signals
- `level_up(god)` - Emitted when god levels up

## Class Properties
### Exported Properties (Core Data)
- `id: String` - Unique god identifier
- `name: String` - Display name
- `pantheon: String` - Mythology group
- `element: ElementType` - Fire/Water/Earth/Lightning/Light/Dark
- `tier: TierType` - Common/Rare/Epic/Legendary
- `level: int` - Current level (default: 1)
- `experience: int` - Current XP (default: 0)

### Exported Properties (Combat Stats)
- `base_hp: int` - Base health points
- `base_attack: int` - Base attack power
- `base_defense: int` - Base defense
- `base_speed: int` - Base speed
- `base_crit_rate: int` - Critical hit rate % (default: 15)
- `base_crit_damage: int` - Critical damage % (default: 50)
- `base_resistance: int` - Resistance % (default: 15)
- `base_accuracy: int` - Accuracy % (default: 0)
- `resource_generation: int` - Resources per hour

### Exported Properties (Equipment System)
- `equipped_runes: Array` - 6 equipment slots [null, null, null, null, null, null]

### Exported Properties (Abilities)
- `active_abilities: Array` - Array of ability dictionaries (NEW system)
- `passive_abilities: Array` - Array of passive ability dictionaries (NEW system)
- `abilities: Array` - Legacy ability IDs (DEPRECATED)
- `passive_ability: String` - Legacy passive ability (DEPRECATED)

### Exported Properties (Territory System)
- `stationed_territory: String` - Territory assignment
- `territory_role: String` - Role in territory (defender/gatherer/crafter)

### Exported Properties (Awakening System)
- `is_awakened: bool` - Awakening status
- `awakened_name: String` - Name when awakened
- `awakened_title: String` - Title when awakened
- `ascension_level: int` - 0-5 (unascended to transcendent)
- `skill_levels: Array[int]` - Skill levels 1-10 for each skill [1,1,1,1]
- `awakening_stat_bonuses: Dictionary` - Stat bonuses from awakening

### Battle State (Not Saved)
- `current_hp: int` - Current HP in battle
- `status_effects: Array[StatusEffect]` - Active status effects
- `shield_hp: int` - Shield hit points

## Methods (Public)
### Static Factory Methods
- `create_from_json(god_id)` - Creates god from JSON configuration
- `string_to_element(element_string)` - Converts string to ElementType enum
- `string_to_tier(tier_string)` - Converts string to TierType enum

### Combat Stat Calculations
- `get_current_hp()` - Calculate current HP with bonuses
- `get_max_hp()` - **DUPLICATE** alias for get_current_hp()
- `get_current_attack()` - Calculate attack with bonuses
- `get_current_defense()` - Calculate defense with bonuses
- `get_current_speed()` - Calculate speed with bonuses
- `get_current_crit_rate()` - Calculate critical rate %
- `get_current_crit_damage()` - Calculate critical damage %
- `get_current_accuracy()` - Calculate accuracy %
- `get_current_resistance()` - Calculate resistance %

### Private Stat Helpers
- `_get_equipment_stat_bonus(stat_type)` - Get equipment bonuses
- `_get_stat_modifier(stat_name)` - Get total stat modifiers

### Power & Experience
- `get_ascension_bonus(stat_name)` - Get ascension stat bonus
- `get_power_rating()` - Calculate total power
- `get_tier_multiplier()` - Get tier multiplier (1.0-2.5)
- `get_experience_to_next_level()` - Calculate XP needed
- `add_experience(amount)` - Add XP and handle level up

### Battle Management
- `prepare_for_battle()` - Initialize for combat
- `heal_full()` - Restore full HP
- `take_damage(damage)` - Apply damage with shields
- `heal(amount)` - Heal and return actual amount
- `clear_all_status_effects()` - Remove all effects

### Display & Utility
- `get_element_name()` - Convert enum to string
- `get_tier_name()` - Convert tier enum to string
- `get_display_name()` - Name (awakened or normal)
- `get_display_title()` - Title (awakened or tier)
- `get_ascension_name()` - Ascension tier name

### Ability Management
- `get_active_ability_by_id(ability_id)` - Find ability by ID
- `get_random_active_ability()` - Get random ability for battle
- `has_valid_abilities()` - Check if has usable abilities
- `has_active_ability(ability_id)` - Check for specific ability
- `get_ability_names()` - Get ability names for UI
- `get_passive_ability_descriptions()` - Get passive descriptions

### Status Effect Management
- `add_status_effect(effect)` - Add status effect with stacking
- `remove_status_effect(effect_id)` - Remove specific effect
- `get_status_effect(effect_id)` - Get effect by ID
- `has_status_effect(effect_id)` - Check if has effect
- `has_debuff_immunity()` - Check debuff immunity
- `has_damage_immunity()` - Check damage immunity
- `can_act()` - Check if can take actions
- `can_use_abilities()` - Check if can use abilities
- `process_turn_start_effects()` - Process all effects per turn
- `get_buffs()` - Get all buff effects
- `get_debuffs()` - Get all debuff effects

### Awakening System
- `can_awaken()` - Check awakening requirements
- `awaken(awakening_data)` - Perform awakening
- `upgrade_skill(skill_index)` - Upgrade skill level
- `ascend(new_level)` - Ascend to higher tier
- `get_awakening_stat_bonus(stat_name)` - Get awakening bonus

### Graphics
- `get_sprite()` - Get god sprite texture
- `has_sprite()` - Check if sprite exists

## Data Structures Used
### Enums
- `ElementType` - 6 element types
- `TierType` - 4 tier levels

### Arrays
- Equipment slots (6 items)
- Status effects
- Abilities (dictionaries)
- Skill levels (4 integers)

## Potential Issues & Duplicate Code
### Duplicate Methods
1. **HP Calculation Duplicates**:
   - `get_current_hp()` and `get_max_hp()` - Same functionality

### Code Smells
1. **Massive Class**: 657 lines with too many responsibilities
2. **Legacy Support**: Maintains old and new ability systems simultaneously
3. **Magic Numbers**: Hard-coded values (40 max level, stat multipliers)
4. **Complex Dependencies**: Tight coupling with multiple systems
5. **Mixed Concerns**: Battle logic mixed with data structure

### Recommendations
1. Remove duplicate `get_max_hp()` method
2. Split into God (data) + GodBattleState + GodProgression classes
3. Create constants for magic numbers
4. Separate awakening system into its own class
5. Extract status effect management to separate class

## Connected Systems (Likely)
- DataLoader.gd - God configuration loading
- StatusEffect.gd - Status effect management
- Equipment.gd - Equipment bonuses
- GameManager.gd - Main game coordination
- EquipmentManager.gd - Set bonus calculations
- BattleManager.gd - Combat mechanics
- AwakeningSystem.gd - Awakening mechanics
- UI screens - Display and management
- Territory system - Assignment and roles

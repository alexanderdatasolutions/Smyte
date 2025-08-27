# Territory.gd Audit Report

## File Info
- **Path**: `scripts/data/Territory.gd`
- **Type**: Data Class (extends Resource)
- **Purpose**: Territory management and resource generation
- **Lines**: 492 lines

## Incoming Dependencies
- GameManager.gd - God lookup, resource operations, upgrade costs
- DataLoader.gd - Territory configuration and resource generation
- God.gd - Power calculations and stationed god management
- TerritoryManager.gd (through GameManager) - Resource collection

## Outgoing Signals
- None

## Class Properties
### Exported Properties (Core Data)
- `id: String` - Unique territory identifier
- `name: String` - Display name
- `tier: int` - Territory tier (1-3)
- `element: ElementType` - Fire/Water/Earth/Lightning/Light/Dark
- `required_power: int` - Minimum power to attack

### Exported Properties (Control & Resources)
- `controller: String` - Owner ("player" or "neutral")
- `stationed_gods: Array` - God IDs stationed here
- `base_resource_rate: int` - Base generation per hour
- `last_resource_generation: float` - Last generation timestamp

### Exported Properties (Battle Progress)
- `current_stage: int` - Stages cleared (0-10)
- `max_stages: int` - Total stages to unlock
- `is_unlocked: bool` - Territory fully cleared

### Exported Properties (Upgrades)
- `territory_level: int` - Upgrade level
- `resource_upgrades: int` - Resource generation upgrades
- `defense_upgrades: int` - Defense infrastructure upgrades
- `zone_upgrades: int` - Zone amplification upgrades
- `max_god_slots: int` - Maximum stationed gods
- `auto_collection_mode: String` - Collection automation setting
- `last_collection_time: float` - Last collection timestamp

### Non-Exported Properties
- `territory_data: Dictionary` - Territory configuration from JSON
- `current_battle_stage: int` - Current battle stage (not saved)

## Methods (Public)
### Power Calculations
- `get_total_defense_power()` - Calculate total defensive power
- `get_stationed_gods_power()` - Power from stationed gods
- `get_required_power()` - Power requirement (scales with stage)
- `get_current_power()` - Current stationed power

### Resource Management
- `get_resource_rate()` - Calculate resource generation rate
- `get_god_resource_bonus()` - Bonus from stationed gods
- `get_resource_upgrade_multiplier()` - Multiplier from upgrades
- `get_pending_resources()` - Calculate pending resources
- `_get_pending_resources_fallback()` - Fallback calculation
- `collect_resources()` - Collect pending resources
- `get_hourly_resource_rate()` - **DUPLICATE** alias for get_resource_rate()

### Auto Collection
- `set_auto_collection_mode(mode)` - Set automation mode
- `should_auto_collect()` - Check if should auto-collect
- `auto_collect_resources()` - Perform auto-collection
- `get_auto_collection_efficiency()` - Efficiency modifier

### God Management
- `can_station_god(god_id)` - Check if god can be stationed
- `station_god(god_id)` - Station a god
- `remove_stationed_god(god_id)` - Remove stationed god
- `clear_stationed_gods()` - Remove all stationed gods
- `_find_god_by_id(god_id)` - **PRIVATE** Find god instance

### Territory Control
- `is_controlled_by_player()` - Check player control
- `can_attack(player_power)` - Check if can be attacked
- `can_be_attacked()` - Check if attackable
- `capture_by_player()` - Set player control
- `capture_by_neutral()` - Reset to neutral

### Stage Progression
- `clear_stage(stage_number)` - Clear a specific stage
- `reset_progress()` - Reset all progress
- `get_progress_text()` - Progress display text
- `get_capture_progress()` - Progress as percentage

### Upgrades
- `can_upgrade_territory()` - Check territory upgrade
- `upgrade_territory()` - Perform territory upgrade
- `can_upgrade_resource_generation()` - Check resource upgrade
- `upgrade_resource_generation()` - Perform resource upgrade
- `can_upgrade_defense()` - Check defense upgrade
- `upgrade_defense()` - Perform defense upgrade
- `can_upgrade_zone_amplification()` - Check zone upgrade
- `upgrade_zone_amplification()` - Perform zone upgrade

### Combat Integration
- `get_zone_bonuses_for_combat()` - Combat bonuses from zone
- `get_enemy_data_for_stage(stage_num)` - Enemy data for stage
- `get_stationed_god_battle_bonuses()` - Pre-battle bonuses
- `apply_stationed_god_experience(battle_result)` - Post-battle XP

### Utility
- `get_element_name()` - Convert enum to string
- `load_territory_data(data)` - Initialize from JSON
- `get_upgrade_cost(upgrade_type)` - Calculate upgrade costs
- `get_territory_status_summary()` - Complete status info

## Data Structures Used
### Enums
- `ElementType` - 6 element types

### Arrays
- Stationed god IDs
- Combat bonuses

### Dictionaries
- Pending resources
- Battle results
- Territory configuration
- Status summary

## Potential Issues & Duplicate Code
### Duplicate Methods
1. **Resource Rate Duplicates**:
   - `get_resource_rate()` and `get_hourly_resource_rate()` - Same functionality

### Code Smells
1. **Massive Class**: 492 lines with multiple concerns
2. **GameManager Coupling**: Heavy dependence on GameManager for operations
3. **Magic Numbers**: Hard-coded values (upgrade limits, bonuses, costs)
4. **Mixed Concerns**: Resource generation + combat + upgrades in one class
5. **Fallback Complexity**: Dual code paths for with/without GameManager

### Potential Issues
1. **Time Calculations**: Float precision issues with timestamps
2. **God Reference Management**: No cleanup when gods are removed
3. **Upgrade Validation**: Limited validation for upgrade operations
4. **Resource Overflow**: No maximum resource limits
5. **Concurrent Access**: No protection for multi-threaded access

### Recommendations
1. Remove duplicate `get_hourly_resource_rate()` method
2. Split into Territory (data) + TerritoryResources + TerritoryUpgrades classes
3. Create constants for magic numbers and upgrade limits
4. Add validation for all upgrade operations
5. Implement proper error handling for missing GameManager
6. Consider using signals for state changes

## Connected Systems (Likely)
- GameManager.gd - Central coordination and operations
- TerritoryManager.gd - Territory management system
- DataLoader.gd - Territory configuration loading
- God.gd - Stationed god management and power calculations
- ResourceManager.gd - Resource generation and collection
- BattleManager.gd - Combat integration
- UI screens - Territory display and management
- Save/Load system - Territory state persistence
- UpgradeSystem.gd - Territory upgrades

## Territory Features Summary
### Core Features
- Multi-stage progression system
- God stationing with element bonuses
- Resource generation with upgrades
- Auto-collection with efficiency modifiers

### Upgrade Systems (4 types)
- Territory level (1-15)
- Resource generation (0-15 upgrades)
- Defense infrastructure (0-10 upgrades)
- Zone amplification (0-8 upgrades)

### Combat Integration
- Pre-battle bonuses from stationed gods
- Zone-specific combat effects
- Post-battle experience for stationed gods
- Stage-based enemy scaling

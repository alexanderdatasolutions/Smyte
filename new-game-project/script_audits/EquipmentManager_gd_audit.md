# EquipmentManager.gd Audit Report

## File Info
- **Path**: `scripts/systems/EquipmentManager.gd`
- **Type**: Equipment System Controller (extends Node)
- **Purpose**: Equipment inventory, crafting, enhancement, and socket management
- **Lines**: ~580 lines - **LARGE SYSTEM CLASS**

## Incoming Dependencies
- Equipment.gd - Equipment data structure and factory methods
- God.gd - Equipment target and stat calculations
- GameManager.gd - Player data and resource management
- FileAccess, JSON - Configuration loading
- Resource files: equipment_config.json, resource_config.json, resources.json

## Outgoing Signals
- `equipment_equipped(god, equipment, slot)` - Equipment equipped
- `equipment_unequipped(god, slot)` - Equipment unequipped
- `equipment_enhanced(equipment, success)` - Enhancement attempt
- `equipment_crafted(equipment, recipe_id)` - Equipment crafted
- `socket_unlocked(equipment, socket_index)` - Socket unlocked
- `gem_socketed(equipment, socket_index, gem)` - Gem socketed

## Class Properties
### Inventories
- `equipment_inventory: Array[Equipment]` - Player equipment storage
- `gems_inventory: Array[Dictionary]` - Player gem storage

### Configuration Cache
- `equipment_config: Dictionary` - Equipment system configuration
- `resource_config: Dictionary` - Resource configuration for crafting
- `resources_data: Dictionary` - Resource definitions from resources.json

## Methods (Public) - 30+ methods!
### Initialization
- `_ready()` - Initialize and load configurations
- `load_equipment_config()` - Load all configuration files
- `_load_resources_data()` - Load resources.json data

### Equipment Inventory Management
- `add_equipment_to_inventory(equipment)` - Add to inventory
- `remove_equipment_from_inventory(equipment)` - Remove from inventory
- `get_equipment_by_id(equipment_id)` - Find by ID
- `get_equipment_by_slot_type(slot_type)` - Filter by equipment type

### Crafting System (6 methods)
- `can_craft_equipment(recipe_id, territory_id)` - Check crafting eligibility
- `craft_equipment(recipe_id, crafting_god_id, territory_id)` - Perform crafting
- `get_available_recipes(territory_id)` - Get craftable recipes
- `create_equipment_from_loot(dungeon_id, difficulty)` - **MINIMAL** loot integration

### Enhancement System
- `enhance_equipment(equipment, use_blessed_oil)` - Enhance equipment
- `_handle_enhancement_failure(equipment, used_blessed_oil)` - Handle failure consequences

### Socket System (4 methods)
- `unlock_socket(equipment, socket_index)` - Unlock equipment socket
- `socket_gem(equipment, socket_index, gem_id)` - Insert gem
- `unsocket_gem(equipment, socket_index)` - Remove gem

### Equipping System
- `equip_equipment(god, equipment)` - Equip to god
- `unequip_equipment(god, slot)` - Unequip from god
- `get_equipped_set_bonuses(god)` - **IMPORTANT** Calculate set bonuses

### Save/Load System (4 methods)
- `save_equipment_data()` - Serialize equipment data
- `load_equipment_data(data)` - Deserialize equipment data
- `_equipment_to_dict(equipment)` - Convert to dictionary
- `_dict_to_equipment(dict)` - Convert from dictionary

### Utility Methods (15+ methods!)
- `_can_afford_cost(cost)` - Cost checking
- `_pay_cost(cost)` - Resource payment
- `_pay_materials_cost(materials, crafting_god_id)` - Materials with god bonuses
- `_check_materials_availability(materials)` - Check missing materials
- `_territory_meets_tier_requirement(territory_id, tier_required)` - Territory validation
- `_has_god_meeting_level_requirement(level_required)` - God level check
- `_has_awakened_god()` - Awakened god check
- `_has_gem_in_inventory(gem_id)` - Gem availability
- `_consume_gem_from_inventory(gem_id)` - Remove gem
- `_is_gem_compatible_with_socket(gem_id, socket_type)` - Compatibility check

## Data Structures Used
### Arrays
- Equipment inventory (typed Array[Equipment])
- Gem inventory (Array[Dictionary])

### Dictionaries
- Equipment configuration from JSON
- Resource requirements and costs
- Set bonus calculations
- Save/load data structures

## Potential Issues & Duplicate Code
### Code Smells
1. **Large System Class**: ~580 lines handling multiple concerns
2. **Configuration Dependency**: Loads 3 different JSON files
3. **GameManager Coupling**: Heavy dependence on GameManager.player_data
4. **Stub Methods**: Several methods return hardcoded true/false
5. **Mixed Concerns**: Inventory + Crafting + Enhancement + Sockets in one class

### Potential Issues
1. **Error Handling**: Minimal error handling for file operations
2. **Validation**: Limited validation for equipment operations
3. **Thread Safety**: No protection for inventory operations
4. **Memory Management**: No cleanup of equipment references

### Integration Issues
1. **Equipment Serialization**: Duplicate serialization logic with GameManager
2. **God Integration**: Direct god property access without proper interface
3. **Resource Management**: Bypasses ResourceManager for direct access

## Recommendations
### Split the Class
1. **EquipmentInventory** - Pure inventory management
2. **EquipmentCrafter** - Crafting system
3. **EquipmentEnhancer** - Enhancement and socket system
4. **EquipmentSerializer** - Save/load operations

### Fix Integration
1. Use proper interfaces for God and PlayerData access
2. Integrate with ResourceManager instead of direct access
3. Add proper error handling and validation
4. Remove duplicate serialization logic

## Connected Systems
- Equipment.gd - Equipment instances and factory methods
- God.gd - Equipment targets and stat integration
- GameManager.gd - Player data and save/load coordination
- ResourceManager.gd - Resource checking and spending
- Territory system - Crafting location requirements
- UI components - Equipment screens and displays

## Key Integration Points
### Critical Methods for Other Systems
1. **`get_equipped_set_bonuses(god)`** - Used by God.gd for stat calculations
2. **`equip_equipment(god, equipment)`** - Equipment assignment
3. **`enhance_equipment(equipment, use_blessed_oil)`** - Equipment progression

### Signal Dependencies
- Other systems likely listen to equipment signals for UI updates
- GameManager connects to signals for save triggers

**This is a well-structured system that could benefit from splitting into smaller, focused classes.**

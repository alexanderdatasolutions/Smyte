# Equipment.gd Audit Report

## File Info
- **Path**: `scripts/data/Equipment.gd`
- **Type**: Data Class (extends Resource)
- **Purpose**: Equipment data structure and factory methods

## Incoming Dependencies
- FileAccess (Godot built-in) - for loading JSON config
- JSON (Godot built-in) - for parsing config files
- Time (Godot built-in) - for ID generation
- Random functions (built-in) - for generation

## Class Properties
### Exported Properties
- `id: String` - Unique equipment identifier
- `name: String` - Display name
- `type: EquipmentType` - Weapon/Armor/Helm/Boots/Amulet/Ring
- `rarity: Rarity` - Common/Rare/Epic/Legendary/Mythic
- `level: int` - Enhancement level (0-15)
- `slot: int` - Equipment slot (1-6)
- `equipment_set_name: String` - Set display name
- `equipment_set_type: String` - Set type identifier
- `main_stat_type: String` - Primary stat type
- `main_stat_value: int` - Current stat value
- `main_stat_base: int` - Base stat value
- `substats: Array[Dictionary]` - Up to 4 secondary stats
- `sockets: Array[Dictionary]` - Socket types and gems
- `max_sockets: int` - Maximum socket count
- `origin_dungeon: String` - Where it was found
- `lore_text: String` - Flavor text

### Computed Properties (Aliases)
- `enhancement_level: int` - Alias for level
- `socket_slots: Array[Dictionary]` - Alias for sockets

### Static Properties
- `equipment_config: Dictionary` - Cached config data
- `config_loaded: bool` - Config loading status

## Methods (Public)
### Static Factory Methods
- `load_equipment_config()` - Loads JSON configuration
- `create_from_dungeon(dungeon_id, equipment_type, rarity_str, item_level)` - Creates dungeon equipment
- `create_test_equipment(equipment_type, rarity_str, init_level)` - Creates test equipment
- `generate_equipment_id()` - Creates unique ID

### Utility Methods
- `string_to_rarity(rarity_string)` - Converts string to enum
- `string_to_type(type_str)` - Converts string to type enum
- `rarity_to_string(rarity_enum)` - Converts enum to string
- `type_to_string(type_enum)` - Converts enum to string
- `get_stat_bonuses()` - Calculates total stat bonuses
- `get_display_name()` - Name with enhancement level
- `get_rarity_color()` - Color based on rarity
- `can_enhance()` - Checks if can be enhanced
- `can_be_enhanced()` - **DUPLICATE** alias for can_enhance
- `get_enhancement_cost()` - Returns enhancement costs
- `get_enhancement_chance()` - Returns success rate
- `get_enhancement_success_rate()` - **DUPLICATE** alias for get_enhancement_chance
- `can_unlock_socket(socket_index)` - Checks socket unlock ability
- `get_socket_unlock_cost(socket_index)` - Returns socket costs

### Private Static Methods
- `_get_equipment_type_info(equipment_type)` - Gets type config
- `_generate_equipment_name(equipment_type, rarity_str)` - Creates name
- `_choose_random_set_for_type(equipment_type)` - Selects set type
- `_get_set_display_name(set_type_str)` - Gets set name
- `_generate_main_stat(equipment, equipment_type, rarity_str, item_level)` - Creates main stat
- `_generate_substats(equipment, equipment_type, rarity_str)` - Creates substats
- `_get_max_sockets_for_rarity(rarity_str)` - Gets socket limits
- `_generate_sockets(socket_count)` - Creates socket array
- `_get_equipment_lore(equipment_type)` - Gets lore text
- `_get_gem_stat_bonuses(gem_id)` - Gets gem bonuses

## Outgoing Signals
- None (this is a data class)

## File Dependencies
- `res://data/equipment_config.json` - Equipment configuration

## Data Structures Used
### Enums
- `EquipmentType` - Equipment categories
- `Rarity` - Rarity levels

### Dictionary Structures
- Substat: `{"type": String, "value": int, "powerups": int}`
- Socket: `{"type": String, "gem": String?, "unlocked": bool}`
- Cost: `{"mana": int, "enhancement_powder": int}`

## Potential Issues & Duplicate Code
### Duplicate Methods
1. **Enhancement Check Duplicates**:
   - `can_enhance()` and `can_be_enhanced()` - Same functionality
   - `get_enhancement_chance()` and `get_enhancement_success_rate()` - Same functionality

### Code Smells
1. **Large Class**: 416 lines with many responsibilities
2. **Static State**: Uses static variables for config loading
3. **Magic Numbers**: Hard-coded values (1000-9999 for IDs, socket counts)
4. **Deep Nesting**: Multiple nested dictionary accesses

### Recommendations
1. Remove duplicate alias methods or consolidate naming
2. Consider splitting into Equipment class + EquipmentFactory class
3. Create constants for magic numbers
4. Add null checks for dictionary access chains

## Connected Systems (Likely)
- EquipmentManager.gd - Equipment management
- InventoryManager.gd - Inventory handling
- LootSystem.gd - Equipment generation
- UI screens for equipment display
- Battle systems for stat calculations

# PlayerData.gd Audit Report

## File Info
- **Path**: `scripts/data/PlayerData.gd`
- **Type**: Data Class (extends Resource)
- **Purpose**: Player progression and resource management
- **Lines**: 404 lines

## Incoming Dependencies
- ResourceManager.gd (through GameManager) - for resource definitions
- GameManager.gd - for signal emissions and manager access
- Engine/SceneTree (Godot built-in) - for fallback ResourceManager lookup

## Outgoing Signals
- None directly (triggers GameManager.resources_updated)

## Class Properties
### Exported Properties (Core Data)
- `player_name: String` - Player display name (default: "Player")
- `player_experience: int` - Player level XP (default: 0)
- `is_first_time_player: bool` - First-time flag (default: true)
- `resources: Dictionary` - All player resources
- `gods: Array` - Player's god collection
- `controlled_territories: Array` - Territory control list
- `total_summons: int` - Total summons performed (default: 0)
- `last_save_time: float` - Save timestamp for resource generation (default: 0)

### Non-Exported Properties
- `resource_manager` - Cached ResourceManager instance
- `last_energy_update: float` - Energy regeneration timestamp

### Legacy Compatibility Properties (Computed)
- `divine_essence: int` - Maps to "mana" resource
- `premium_crystals: int` - Maps to "divine_crystals" resource
- `energy: int` - Maps to "energy" resource
- `max_energy: int` - Maps to max storage for energy
- `crystals: Dictionary` - Maps to elemental crystal resources
- `awakening_stones: int` - Maps to "awakening_stone" resource

## Methods (Public)
### Initialization
- `_init()` - Constructor calls initialize_default_resources()
- `initialize_default_resources()` - Sets up all resource categories
- `create_fallback_resources()` - Fallback if ResourceManager unavailable
- `get_default_amount_for_resource(resource_id)` - Default starting amounts

### Resource Manager Access
- `get_resource_manager()` - Gets ResourceManager via GameManager
- `get_resource_manager_safe()` - Safe getter without warnings

### Core Resource Management
- `get_resource(resource_id)` - Get resource amount
- `has_resource(resource_id, amount)` - Check if has enough resource
- `spend_resource(resource_id, amount)` - Spend resource if available
- `add_resource(resource_id, amount)` - Add resource with max storage
- `get_max_storage(resource_id)` - Get storage limit for resource
- `can_afford_cost(cost)` - Check if can afford cost dictionary
- `spend_cost(cost)` - Spend multiple resources

### God Collection Management
- `add_god(god)` - Add god to collection
- `remove_god(god)` - Remove god from collection
- `get_god_by_id(god_id)` - Find god by ID
- `get_total_power()` - Calculate total power rating
- `get_gods_by_element(element)` - Filter gods by element
- `get_gods_by_tier(tier)` - Filter gods by tier
- `get_god_count(god_id)` - Count gods of specific type
- `has_god(god_id)` - Check if owns god

### Energy Management
- `update_energy()` - Update energy based on time passed
- `can_afford_energy(cost)` - Check if has enough energy
- `spend_energy(cost)` - Spend energy with updates
- `add_energy(amount)` - Add energy with max limit
- `refresh_energy_with_crystals()` - Premium energy refresh
- `get_energy_status()` - Complete energy status info

### Territory Management
- `control_territory(territory_id)` - Add territory control
- `lose_territory_control(territory_id)` - Remove territory control

### Utility
- `update_last_save_time()` - Update save timestamp

## Data Structures Used
### Dictionaries
- `resources` - Resource ID → Amount mapping
- `cost` - Resource requirements for actions
- Energy status with current/max/percentage/timing info

### Arrays
- God collection
- Territory control list

## Potential Issues & Duplicate Code
### Code Smells
1. **God Mode Class**: 404 lines handling multiple concerns
2. **Resource Manager Coupling**: Heavy dependence on external ResourceManager
3. **Legacy Support**: Maintains old property system alongside new
4. **Magic Numbers**: Hard-coded values (30 crystals, 90 energy, 5 min regen)
5. **Time Management**: Manual energy regeneration tracking

### Potential Issues
1. **Initialization Order**: ResourceManager may not be available during _init()
2. **Memory Leaks**: Direct god references in array without proper cleanup
3. **Thread Safety**: No protection for resource operations
4. **Save State**: Energy timing could desync on game restart

### Recommendations
1. Split into PlayerData (core) + PlayerResources + PlayerCollection classes
2. Create constants for magic numbers
3. Implement resource change events/observers
4. Add validation for resource operations
5. Consider using signals for god collection changes

## Connected Systems (Likely)
- ResourceManager.gd - Resource definitions and categories
- GameManager.gd - Main game coordination and signal hub
- God.gd - God instances in collection
- InventoryManager.gd - Resource display
- SummonSystem.gd - God collection management
- TerritoryManager.gd - Territory control
- UI screens - Resource display and management
- Save/Load system - Data persistence

## Resource Categories Handled
### Currency
- mana
- divine_crystals

### Premium Currency
- (various premium currencies)

### Summoning Materials
- common_soul, rare_soul, epic_soul, legendary_soul
- elemental souls (fire_soul, water_soul, etc.)

### Awakening Materials
- awakening_stone
- various _low, _mid materials

### Special Resources
- energy (with regeneration mechanics)

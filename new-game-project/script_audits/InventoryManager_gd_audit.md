# InventoryManager.gd Audit Report

## File Overview
- **File Path**: scripts/systems/InventoryManager.gd
- **Line Count**: 300+ lines
- **Primary Purpose**: Manages inventory items (consumables, materials, quest items) with Summoners War-style organization
- **Architecture Type**: Focused manager class with clear single responsibility

## Signal Interface (2 signals)
### Outgoing Signals
1. `inventory_updated(item_type: String)` - When inventory contents change
2. `item_consumed(item_id: String, amount: int)` - When items are consumed

## Method Inventory (18 methods)
### Core Inventory Operations
- `_ready()` - Initialize and load item config
- `load_item_config()` - Load loot_items.json configuration
- `add_item(item_id: String, amount: int = 1)` - Add items to appropriate category
- `remove_item(item_id: String, amount: int = 1)` - Remove items if available
- `has_item(item_id: String, amount: int = 1)` - Check item availability
- `get_item_count(item_id: String)` - Get item count across all inventories

### Consumable Management
- `use_consumable(item_id: String, target_god: God = null)` - Use consumable with effects
- `_apply_consumable_effect(effect: Dictionary, target_god: God = null)` - Apply effect logic

### Battle Integration
- `add_loot_items(loot_results: Dictionary)` - Add battle loot to inventory

### Utility Methods
- `get_item_info(item_id: String)` - Get item configuration data
- `get_all_consumables()` - Get all consumables with info
- `get_all_materials()` - Get all materials with info

### Save/Load System
- `save_inventory_data()` - Save inventory state
- `load_inventory_data(data: Dictionary)` - Load inventory state

## Key Dependencies
### External Dependencies
- **loot_items.json** - Item configuration and definitions
- **God.gd** - For consumable effects on gods (heal, experience)
- **GameManager.player_data** - For resource effects (energy)
- **FileAccess/JSON** - For data loading

### Internal State
- `consumables: Dictionary` - item_id -> amount for consumable items
- `materials: Dictionary` - material_id -> amount for crafting materials
- `quest_items: Dictionary` - quest_item_id -> amount for quest items
- `item_config: Dictionary` - Cached item definitions from JSON

## Duplicate Code Patterns Identified
### MAJOR OVERLAPS (HIGH PRIORITY):
1. **Dictionary Management Pattern Overlap**:
   - `add_item()`, `remove_item()`, `has_item()` patterns
   - **Same add/remove/check logic** as EquipmentManager inventory operations
   - **Same pattern** likely in ResourceManager for resources
   - RECOMMENDATION: Create shared InventoryUtility class

2. **Category-Based Storage Overlap**:
   - Consumables/materials/quest_items separation
   - **Similar categorization** in EquipmentManager (weapons/armor/accessories)
   - RECOMMENDATION: Standardize category management patterns

3. **JSON Loading Pattern Overlap**:
   - `load_item_config()` file loading and JSON parsing
   - **Identical pattern** in DataLoader for multiple JSON files
   - RECOMMENDATION: Create shared JSONLoader utility

### MEDIUM OVERLAPS:
4. **Effect Application Overlap**:
   - `_apply_consumable_effect()` effect processing
   - Similar effect patterns likely in StatusEffectManager
   - RECOMMENDATION: Create shared EffectProcessor utility

5. **Save/Load Pattern Overlap**:
   - `save_inventory_data()`, `load_inventory_data()`
   - **Same pattern** likely in all manager classes
   - RECOMMENDATION: Create shared SaveLoadUtility

## Architectural Assessment
### POSITIVE ASPECTS:
- **Good single responsibility**: Only handles inventory items
- **Clear categorization**: Logical separation of item types
- **Clean interface**: Simple add/remove/check methods
- **Battle integration**: Proper loot handling

### MINOR ISSUES:
- **Mixed concerns**: Item effects processing within inventory manager
- **Direct god modification**: Should use event system instead

## Refactoring Recommendations
### IMMEDIATE (High Impact):
1. **Extract shared inventory utilities**:
   - `InventoryUtility` for add/remove/check patterns
   - `JSONLoader` for file loading operations
   - Share with EquipmentManager and ResourceManager

2. **Extract effect processing**:
   - Move `_apply_consumable_effect()` to dedicated EffectProcessor
   - Use event system instead of direct god modification

### MEDIUM (Maintenance):
3. **Standardize with other managers**:
   - Consistent save/load patterns across all managers
   - Shared category management utilities
   - Consistent signal naming conventions

4. **Optimize item lookup**:
   - Cache frequently accessed item info
   - Consider item ID validation

## Connectivity Map
### Strongly Connected To:
- **DataLoader**: JSON file loading patterns
- **God.gd**: Consumable effects (heal, experience)
- **GameManager**: Player data access and resource management

### Moderately Connected To:
- **EquipmentManager**: Inventory pattern overlap
- **ResourceManager**: Category management overlap
- **BattleManager**: Loot distribution
- **UI Screens**: Inventory display and item usage

### Signal Consumers (Likely):
- **UI components**: Inventory screens, item lists
- **ResourceDisplay**: Inventory count updates
- **BattleManager**: Item usage coordination

## Notes for Cross-Reference
- **Inventory patterns**: Compare with EquipmentManager.gd and ResourceManager.gd for shared utilities
- **JSON loading patterns**: Compare with DataLoader.gd for shared file loading
- **Effect patterns**: Compare with StatusEffectManager.gd for effect processing
- **Save/load patterns**: Check consistency across all manager audits
- **Dictionary operations**: Look for similar add/remove/check patterns in other managers

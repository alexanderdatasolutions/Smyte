# LootSystem.gd Audit Report

## File Overview
- **File Path**: scripts/systems/LootSystem.gd
- **Line Count**: 624 lines
- **Primary Purpose**: Complex template-based loot system with element integration and modular resource handling
- **Architecture Type**: Monolithic system with extensive template processing

## Signal Interface (1 signal)
### Outgoing Signals
1. `loot_awarded(loot_results)` - When loot is awarded to player

## Method Inventory (30+ methods)
### Core Loot System
- `_ready()` - Initialize ResourceManager reference and load data
- `load_loot_data()` - Load loot_items.json and loot_tables.json
- `_load_json_file(file_path: String, target_var: String)` - JSON loading helper
- `award_loot(loot_table_name: String, stage_level: int, territory_element: String, context: Dictionary)` - Main loot awarding

### Template Resolution System
- `resolve_loot_table(table_name: String, context: Dictionary)` - Resolve table/template names
- `_resolve_template_from_name(table_name: String)` - Parse template patterns from names
- `_apply_template_substitutions(template: Dictionary, substitutions: Dictionary)` - Apply template variables
- `_substitute_value(value, substitutions: Dictionary)` - Recursive value substitution
- `_substitute_string(text: String, substitutions: Dictionary)` - String placeholder replacement

### Loot Processing
- `_process_loot_drop(drop: Dictionary, stage_level: int, element: String)` - Process individual drop
- `_resolve_loot_item(loot_item: Dictionary, stage_level: int, element: String)` - Resolve item to resources
- `_handle_element_based_item(loot_item: Dictionary, element: String)` - Element-based items
- `_handle_element_specific_item(loot_item: Dictionary, element: String)` - Element-specific items
- `_handle_standard_item(loot_item: Dictionary, stage_level: int)` - Standard resource drops
- `_handle_experience_item(loot_item: Dictionary, stage_level: int)` - Experience drops
- `_handle_equipment_item(loot_item: Dictionary, stage_level: int)` - Equipment drops
- `_handle_random_consumable(loot_item: Dictionary)` - Random consumable drops

### Player Integration
- `_merge_loot_results(target: Dictionary, source: Dictionary)` - Merge loot results
- `_award_to_player(loot_results: Dictionary)` - Award to player with multiple methods
- `_resolve_element_resource(base_resource: String, element: String)` - Element resource resolution

### Convenience Methods
- `award_stage_victory_loot(stage_level: int, territory_element: String)` - Stage victory
- `award_boss_stage_loot(stage_level: int, territory_element: String)` - Boss victory
- `award_dungeon_loot(dungeon_id: String, difficulty: String, stage_level: int)` - Dungeon completion
- `award_territory_passive_income(territory_tier: int, territory_element: String, god_bonuses: Dictionary)` - Territory income

### Utility Functions
- `get_resource_info(resource_id: String)` - Get resource information via ResourceManager
- `get_loot_table_info(loot_table_id: String)` - Get loot table information
- `can_convert_resource(from_resource: String, to_resource: String)` - Check resource conversion
- `get_conversion_cost(from_resource: String, to_resource: String, amount: int)` - Get conversion costs
- `get_loot_table_rewards_preview(loot_table_id: String, context: Dictionary)` - Preview rewards
- `get_available_dungeon_types()` - Get dungeon type templates
- `generate_dungeon_loot_table_id(dungeon_type: String, params: Dictionary)` - Generate table IDs

## Key Dependencies
### External Dependencies
- **ResourceManager** - Heavy dependency for element resolution and resource info
- **loot_items.json** - Loot item definitions
- **loot_tables.json** - Loot table templates and configurations
- **GameManager.player_data** - Player resource awarding
- **God system** - Experience awarding and god bonuses

### Internal State
- `loot_items_data: Dictionary` - Cached loot item definitions
- `loot_tables_data: Dictionary` - Cached loot table/template data
- `resource_manager: Node` - ResourceManager reference

## Duplicate Code Patterns Identified
### MAJOR OVERLAPS (HIGH PRIORITY):
1. **JSON Loading Pattern Overlap with DataLoader.gd**:
   - `_load_json_file()` identical to DataLoader patterns
   - File loading, JSON parsing, error handling
   - **Exact same code structure**
   - RECOMMENDATION: Use shared JSONLoader utility

2. **Resource Management Overlap with ResourceManager.gd**:
   - Resource awarding patterns (`_award_to_player`)
   - Element resource resolution (`_resolve_element_resource`)
   - Resource info lookup patterns
   - RECOMMENDATION: Centralize through ResourceManager

3. **Template Processing Overlap**:
   - String substitution patterns (`_substitute_string`, `_substitute_value`)
   - Placeholder replacement logic
   - Likely similar in other template systems
   - RECOMMENDATION: Create shared TemplateProcessor utility

### MEDIUM OVERLAPS:
4. **Dictionary Merging Overlap**:
   - `_merge_loot_results()` pattern
   - Similar patterns likely in InventoryManager, EquipmentManager
   - RECOMMENDATION: Create shared DictionaryUtility

5. **Player Data Access Overlap**:
   - Multiple player data access patterns in `_award_to_player()`
   - Similar patterns across all managers
   - RECOMMENDATION: Standardize player data interface

## Architectural Issues
### Single Responsibility Violations
- **CRITICAL**: This class handles 5 distinct responsibilities:
  1. Loot table/template resolution
  2. Loot item processing
  3. Resource awarding
  4. Template pattern matching
  5. Player data integration

### Massive Template System
- **Complex regex-based template resolution**
- **Multiple template patterns** for different dungeon types
- **Deep nesting** in template processing logic

### Performance Concerns
- **Heavy JSON processing** during initialization
- **Complex template resolution** for each loot award
- **Multiple ResourceManager calls** during processing

## Refactoring Recommendations
### IMMEDIATE (High Impact):
1. **Extract template processing**:
   - `TemplateProcessor` utility for shared template logic
   - `LootTableResolver` for table/template resolution
   - `PatternMatcher` for regex-based name resolution

2. **Consolidate resource operations**:
   - Move all resource awarding through ResourceManager
   - Remove direct GameManager.player_data access
   - Standardize resource operations

3. **Extract JSON loading**:
   - Use shared JSONLoader utility (same as DataLoader)
   - **Eliminate 50+ lines of duplicate JSON code**

### MEDIUM (Maintenance):
4. **Split loot processing**:
   - `LootProcessor` for item processing logic
   - `LootAwarder` for player integration
   - Keep LootSystem as coordinator

5. **Extract convenience layer**:
   - `LootConvenience` class for award_*_loot methods
   - Separate high-level API from core processing

## Connectivity Map
### Strongly Connected To:
- **ResourceManager**: Heavy dependency for resource operations
- **DataLoader**: JSON loading pattern overlap
- **GameManager**: Player data access and experience awarding

### Moderately Connected To:
- **InventoryManager**: Loot item awarding overlap
- **EquipmentManager**: Equipment drop coordination
- **DungeonSystem**: Dungeon loot coordination
- **BattleManager**: Battle reward integration

### Signal Consumers (Likely):
- **UI components**: Loot display screens, reward popups
- **BattleManager**: Battle completion coordination
- **TerritoryManager**: Passive income coordination

## Notes for Cross-Reference
- **JSON loading patterns**: Compare with DataLoader.gd for shared utilities
- **Resource operations**: Compare with ResourceManager.gd for consolidation
- **Template processing**: Look for similar pattern systems in other managers
- **Player data access**: Check consistency across all manager audits
- **Dictionary operations**: Compare merge patterns with InventoryManager and EquipmentManager

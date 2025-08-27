# DataLoader.gd Audit Report

## Overview
- **File**: `scripts/systems/DataLoader.gd`
- **Type**: Data Loading and Caching System
- **Lines of Code**: 728
- **Class Type**: Node (Static utility class)

## Purpose
Centralized JSON data loading system with caching. Handles all game data files including territories, gods, enemies, loot tables, banners, and system configurations. Provides unified access to all static game data.

## Dependencies
### Inbound Dependencies (What this relies on)
- **JSON files**: territories.json, gods.json, awakened_gods.json, enemies.json, loot.json, banners.json, core_game_systems.json
- **FileAccess**: Godot file system access
- **JSON**: Godot JSON parser

### Outbound Dependencies (What depends on this)
- **ALL SYSTEMS**: Virtually every system depends on DataLoader for configuration data
- **GameManager**: Uses for initialization and data access
- **BattleManager**: Uses for enemy and loot configurations
- **SummonSystem**: Uses for god data and banner configurations
- **TerritoryManager**: Uses for territory and role configurations
- **LootSystem**: Uses for loot table configurations

## Static Cache Variables (10 variables)
- `territories_data: Dictionary` - Cached territory configurations
- `gods_data: Dictionary` - Cached god configurations
- `awakened_gods_data: Dictionary` - Cached awakened god configurations
- `abilities_data: Dictionary` - Cached ability configurations
- `loot_data: Dictionary` - Cached loot table configurations
- `core_systems_data: Dictionary` - Cached system configurations
- `banners_data: Dictionary` - Cached banner and summon configurations
- `enemies_data: Dictionary` - Cached enemy configurations
- `data_loaded: bool` - Global loading state flag

## Method Inventory

### Core Loading Methods (8 methods)
- `load_all_data()` - Master loading function for all data files
- `load_territories_data()` - Load territory configurations
- `load_gods_data()` - Load god configurations
- `load_awakened_gods_data()` - Load awakened god configurations
- `load_loot_data()` - Load loot table configurations
- `load_enemies_data()` - Load enemy configurations
- `load_banners_data()` - Load banner and summon configurations
- `load_core_systems_data()` - Load system configurations

### Territory Data Access (6 methods)
- `get_territory_config(territory_id)` - Get specific territory configuration
- `get_all_territory_configs()` - Get all territory configurations
- `get_tier_settings(tier)` - Get tier-specific settings
- `get_stage_title(stage)` - Get stage title from ranges
- `get_territory_passive_income(territory_id, assigned_gods)` - Calculate passive income with god bonuses
- `_get_fallback_passive_income(tier_key, assigned_gods)` - Fallback income calculation

### Enemy Data Access (7 methods)
- `get_enemy_types_for_element(element)` - Get element-specific enemy types
- `get_enemy_role_config(role)` - Get enemy role configuration
- `get_base_stats_config()` - Get enemy base stats configuration
- `get_rewards_config()` - Get enemy reward configurations
- `get_enemy_abilities(category)` - Get enemy ability sets
- `get_enemy_ai_behaviors()` - Get AI behavior configurations
- `get_enemy_formations()` - Get formation configurations
- `get_special_formation_for_stage(stage)` - Get stage-specific formations

### God Data Access (8 methods)
- `get_god_config(god_id)` - Get god configuration (checks awakened first)
- `get_awakened_god_config(god_id)` - Get awakened god configuration specifically
- `get_gods_by_pantheon(pantheon)` - Filter gods by pantheon
- `get_gods_by_tier(tier)` - Filter gods by tier
- `get_random_god_by_rarity(summon_type)` - Random god selection with rates
- `get_ability_config(ability_id)` - Get ability configuration
- `get_tier_multipliers()` - Get tier stat multipliers
- `get_summon_rates()` - Get summon rate configurations

### Loot System Access (3 methods)
- `get_stage_loot_rewards(stage, is_final_stage, territory_element, territory_pantheon)` - Calculate stage rewards
- `get_experience_rewards(stage, victory, element_advantage)` - Calculate XP rewards
- `get_territory_unlock_rewards()` - Get territory unlock bonus rewards

### Banner System Access (7 methods)
- `get_active_banners()` - Get currently active banners
- `get_banner_by_id(banner_id)` - Get specific banner configuration
- `get_special_summon_by_id(summon_id)` - Get special summon configuration
- `get_summon_milestones()` - Get progression reward milestones
- `get_pity_config()` - Get pity system configuration
- `get_featured_gods_for_banner(banner_id)` - Get banner featured gods
- `get_rate_multiplier_for_banner(banner_id, god_id)` - Get rate up multipliers

### Territory System Access (3 methods)
- `get_god_roles_config()` - Get god role configuration
- `get_territory_roles_config()` - Get territory role configuration
- `get_territory_balance_config()` - Get balance configuration

### Utility Methods (4 methods)
- `element_string_to_int(element_string)` - Convert element string to enum
- `element_int_to_string(element_int)` - Convert element enum to string
- `_get_god_tier_string(god)` - Convert god tier to string for lookups
- `_load_json_file_static(file_path)` - Centralized JSON file loading

## Signals
**Emitted**: None (static class)
**Received**: None (static class)

## Key Data Structures

### Cached Data Structure
- **Global cache**: Static dictionaries hold all loaded JSON data
- **Lazy loading**: Data loaded on first access via `data_loaded` flag
- **Fallback handling**: Graceful degradation when files missing

### Configuration Categories
- **Territories**: Territory definitions, tiers, passive income
- **Gods**: God stats, abilities, awakening data, tiers
- **Enemies**: Enemy types, roles, abilities, formations, AI
- **Loot**: Loot tables, rewards, experience, materials
- **Banners**: Banner configurations, rates, featured gods, pity
- **Systems**: Core system configurations

## Notable Patterns
- **Static Caching**: All data cached in static variables
- **Lazy Loading**: Data loaded on first access
- **Fallback Strategy**: Graceful handling of missing files
- **Unified Access**: Single entry point for all game data
- **Element Conversion**: String/int conversion utilities for elements

## Code Quality Issues

### Anti-Patterns Found
1. **Massive Static Class**: 728 lines handling all data types
2. **Global State**: Static variables create global mutable state
3. **Mixed Responsibilities**: Loading, caching, calculation, and access in one class
4. **Duplicated Loading Logic**: Similar JSON loading patterns repeated
5. **Hard-coded Fallbacks**: Fallback data embedded in code

### Positive Patterns
1. **Centralized Loading**: Single place for all data access
2. **Caching Strategy**: Prevents repeated file I/O
3. **Error Handling**: Graceful handling of missing/corrupt files
4. **Lazy Loading**: Only loads data when needed
5. **Null Safety**: Defensive programming with fallbacks

## Architectural Notes

### Strengths
- **Performance**: Caching prevents repeated file reads
- **Reliability**: Fallback mechanisms for missing data
- **Centralization**: Single source of truth for all data
- **Consistency**: Uniform access patterns across all data types

### Concerns
- **Massive Responsibility**: Single class handles too many data types
- **Global State**: Static variables make testing difficult
- **Memory Usage**: All data loaded into memory simultaneously
- **Coupling**: All systems depend on this single class

## Duplicate Code Potential
- **JSON Loading Pattern**: Repeated file open/parse/close logic across load_*_data() methods
- **Cache Access Pattern**: Similar "if not data_loaded" checks
- **Error Handling**: Similar error messages and fallback logic
- **Configuration Access**: Similar get_*_config() method patterns

## Refactoring Recommendations
1. **Split by Domain**: Separate loaders for Gods, Territories, Enemies, etc.
2. **Data Service Pattern**: Create service classes for different data types
3. **Dependency Injection**: Inject data services instead of static access
4. **Configuration Factory**: Factory pattern for creating configurations
5. **Async Loading**: Consider async loading for large data sets

## Integration Points
- **GameManager**: Primary consumer during initialization
- **All Manager Classes**: Use for configuration data
- **Battle Systems**: Use for enemy and loot configurations
- **UI Systems**: Use for display data and configurations
- **Save/Load Systems**: May need to cache some data

## Security/Safety Notes
- **File Access**: Uses FileAccess.READ only (safe)
- **JSON Parsing**: Proper error handling for malformed JSON
- **Null Safety**: Extensive fallback mechanisms
- **Memory Safety**: No direct memory manipulation

## Performance Considerations
- **Startup Time**: All data loaded during first access
- **Memory Usage**: All JSON data kept in memory
- **Cache Invalidation**: No mechanism to reload data during runtime
- **File I/O**: Multiple synchronous file reads during initialization

## Data Dependencies
The DataLoader manages these critical data files:
- `territories.json` - Territory definitions and configurations
- `gods.json` - God stats, abilities, and summoning data
- `awakened_gods.json` - Awakened god variations
- `enemies.json` - Enemy types, formations, and AI
- `loot.json` - Loot tables and reward calculations
- `banners.json` - Summon banners and rate configurations
- `core_game_systems.json` - System-wide configurations

## Missing Features
1. **Hot Reloading**: No runtime data reloading capability
2. **Validation**: No data structure validation
3. **Versioning**: No data format versioning system
4. **Compression**: No data compression for large files
5. **Incremental Loading**: All-or-nothing loading strategy

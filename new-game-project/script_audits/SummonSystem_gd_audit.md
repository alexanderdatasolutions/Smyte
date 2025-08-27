# SummonSystem.gd Audit Report

## File Overview
- **File Path**: scripts/systems/SummonSystem.gd
- **Line Count**: 586 lines
- **Primary Purpose**: Comprehensive Summoners War-style summoning system with pity mechanics, multi-summons, and filtering
- **Architecture Type**: Monolithic system with extensive configuration management

## Signal Interface (3 signals)
### Outgoing Signals
1. `summon_completed(god)` - When single summon completes successfully
2. `summon_failed(reason)` - When summon fails
3. `multi_summon_completed(gods)` - When multi-summon pack completes

## Method Inventory (40+ methods)
### Configuration Loading
- `_ready()` - Initialize summon system
- `load_summon_configuration()` - Load summon_config.json
- `load_gods_data()` - Load gods data for filtering
- `create_fallback_config()` - Create fallback configuration

### Main Summon Functions (8 summon types)
- `summon_with_soul(soul_type: String)` - Soul-based summons
- `summon_element_soul(element: String)` - Element-specific soul summons
- `summon_pantheon_focus(pantheon: String)` - Pantheon-focused summons
- `summon_role_focus(role: String)` - Role-focused summons
- `summon_premium()` - Premium crystal summons
- `summon_with_mana()` - Mana-based summons
- `multi_summon_soul_pack()` - 10-pull soul pack
- `multi_summon_premium()` - 10-pull premium pack
- `daily_free_summon()` - Free daily summon

### Core Summon Logic
- `_perform_summon(cost_type: String, summon_type: String, params: Dictionary)` - Main summon logic
- `_perform_summon_with_rates(rates: Dictionary, summon_type: String, params: Dictionary)` - Core summon execution
- `_perform_multi_summon(cost_type: String, pack_type: String, params: Dictionary)` - Multi-summon logic

### Configuration Access (6 helpers)
- `get_summon_cost(cost_type: String)` - Get cost from config
- `get_summon_rates(cost_type: String, summon_type: String, params: Dictionary)` - Get rates from config
- `get_config_rates(rate_category: String, rate_type: String)` - Helper for rate access
- `get_config_value(path: String, default_value)` - Nested config value access

### God Selection Logic (8 methods)
- `get_weighted_random_god(rates: Dictionary, summon_type: String, params: Dictionary)` - Main god selection
- `get_random_tier_from_rates(rates: Dictionary)` - Random tier selection
- `filter_gods_by_criteria(tier: String, summon_type: String, params: Dictionary)` - Filter gods by criteria
- `meets_summon_criteria(god_config: Dictionary, summon_type: String, params: Dictionary)` - Check criteria
- `apply_summon_weights(gods: Array, summon_type: String, params: Dictionary)` - Apply weights
- `select_weighted_random_god(weighted_gods: Dictionary)` - Select from weighted pool

### Pity System (4 methods)
- `apply_pity_system(rates: Dictionary)` - Apply pity modifications
- `apply_soft_pity_rates(rates: Dictionary, soft_pity_config: Dictionary)` - Soft pity logic
- `_update_pity_counters(tier: String)` - Update pity counters

### Guarantee System
- `apply_guarantee_rates(rates: Dictionary, guarantees: Dictionary)` - Apply multi-summon guarantees

### Utility Functions (8 methods)
- `get_gods_by_tier(tier: String)` - Get gods by tier
- `get_god_roles(god_id: String)` - Get god roles
- `_create_god_from_id(god_id: String)` - Create god instance
- `_add_god_to_collection(god: God)` - Add to collection
- `_can_afford_cost(cost: Dictionary)` - Check affordability
- `_spend_cost(cost: Dictionary)` - Spend resources
- `can_use_daily_free_summon()` - Check daily availability
- `can_use_weekly_premium_summon()` - Check weekly availability

## Key Dependencies
### External Dependencies
- **DataLoader** - Heavy dependency for gods data loading
- **summon_config.json** - Summon configuration
- **god_roles.json** - God role assignments
- **God.gd** - God creation (God.create_from_json)
- **GameManager.player_data** - Resource management and collection

### Internal State
- `summon_config: Dictionary` - Loaded summon configuration
- `gods_data: Dictionary` - Gods data from DataLoader
- `role_data: Dictionary` - God role assignments
- `pity_counter: Dictionary` - Pity tracking (rare, epic, legendary)
- `last_free_summon_date: String` - Daily free tracking
- Daily/weekly tracking variables

## Duplicate Code Patterns Identified
### MAJOR OVERLAPS (HIGH PRIORITY):
1. **JSON Loading Pattern Overlap with DataLoader/ResourceManager/LootSystem**:
   - `load_summon_configuration()` **identical to other JSON loaders**
   - File loading, JSON parsing, error handling
   - **Exact same 20+ lines of code**
   - RECOMMENDATION: Use shared JSONLoader utility

2. **Resource Management Overlap with PlayerData/ResourceManager**:
   - `_can_afford_cost()`, `_spend_cost()` resource operations
   - **Same pattern** across all spending systems
   - RECOMMENDATION: Centralize through ResourceManager

3. **God Data Access Overlap with DataLoader**:
   - Duplicate gods data loading and access patterns
   - **Heavy DataLoader dependency**
   - RECOMMENDATION: Use DataLoader directly instead of duplicating

### MEDIUM OVERLAPS:
4. **Configuration Access Pattern**:
   - `get_config_value()` nested config access with dot notation
   - **Similar patterns** likely in other config-heavy systems
   - RECOMMENDATION: Create shared ConfigurationUtility

5. **Weighted Random Selection**:
   - `select_weighted_random_god()` weighted selection logic
   - **Similar patterns** likely in other random systems
   - RECOMMENDATION: Create shared RandomUtility

## Architectural Issues
### Single Responsibility Violations
- **CRITICAL**: This class handles 6 distinct responsibilities:
  1. Summon configuration management
  2. God selection and filtering
  3. Pity system management
  4. Multi-summon pack logic
  5. Resource cost management
  6. Daily/weekly availability tracking

### Massive Configuration System
- **Complex nested configuration** access patterns
- **Heavy JSON processing** during initialization
- **Multiple configuration files** dependencies

### Complex God Selection Logic
- **Multiple filtering and weighting systems**
- **Deep integration** with god data structures
- Should be extracted to dedicated service

## Refactoring Recommendations
### IMMEDIATE (High Impact):
1. **Extract JSON loading utility**:
   - Use shared `JSONLoader` utility (same as DataLoader/ResourceManager)
   - **Eliminate 30+ lines of duplicate code**

2. **Extract god selection system**:
   - `GodSelector` service for filtering and weighting
   - `SummonRateCalculator` for rate modifications
   - Keep SummonSystem as coordinator

3. **Centralize resource operations**:
   - Use ResourceManager for all cost/spending operations
   - Remove direct PlayerData access

### MEDIUM (Maintenance):
4. **Extract pity system**:
   - `PityManager` for pity tracking and modifications
   - Separate from main summon logic

5. **Extract configuration management**:
   - `SummonConfigManager` for configuration access
   - Shared `ConfigurationUtility` for nested access patterns

## Connectivity Map
### Strongly Connected To:
- **DataLoader**: Heavy dependency for gods data
- **GameManager.player_data**: Resource management and collection
- **God.gd**: God creation dependency

### Moderately Connected To:
- **ResourceManager**: Resource cost pattern overlap
- **JSON configuration files**: Heavy configuration dependency

### Weakly Connected To:
- **UI Screens**: SummonScreen consumption
- **NotificationManager**: Summon completion notifications

### Signal Consumers (Likely):
- **SummonScreen**: Summon completion and failure handling
- **NotificationManager**: Summon result notifications
- **UI components**: Multi-summon displays, result animations

## Notes for Cross-Reference
- **JSON loading patterns**: Compare with DataLoader.gd, ResourceManager.gd, LootSystem.gd for shared utility
- **Resource operations**: Compare with ResourceManager.gd and PlayerData.gd for centralization
- **God data access**: Compare with DataLoader.gd for consolidation
- **Configuration patterns**: Look for similar nested config access in other systems
- **Random selection patterns**: Check for similar weighted selection in other systems

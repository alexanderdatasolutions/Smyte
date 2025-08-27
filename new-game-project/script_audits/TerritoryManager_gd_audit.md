# TerritoryManager.gd Audit Report

## Overview
- **File**: `scripts/systems/TerritoryManager.gd`
- **Type**: Territory Role & Resource Management System
- **Lines of Code**: 1020
- **Class Type**: Node (System manager)

## Purpose
Advanced territory management with god role assignments, resource generation calculation, and modular passive income system. Handles complex role-based resource generation with caching, balancing, and territory specializations.

## Dependencies
### Inbound Dependencies (What this relies on)
- **DataLoader**: get_god_roles_config(), get_territory_roles_config(), get_territory_balance_config(), get_territory_passive_income()
- **GameManager**: Player data, territory access, system references
- **ResourceManager**: Resource awarding through modular system
- **LootSystem**: Resource generation and collection
- **Territory objects**: Territory data and stationed gods
- **God objects**: God stats, roles, and assignments

### Outbound Dependencies (What depends on this)
- **TerritoryScreen**: Territory efficiency displays and role management UI
- **GameManager**: Territory resource collection integration
- **MainUIOverlay**: Resource display updates
- **TerritoryRoleScreen**: God role assignment interface

## Signals (4 signals)
**Emitted**:
- `territory_role_assigned(territory_id, god_id, role)` - God assigned to territory role
- `territory_resources_generated(territory_id, resources)` - Resources collected from territory
- `territory_slots_updated(territory_id, new_slots)` - Territory slot configuration changed
- `god_role_changed(god_id, old_role, new_role)` - God role assignment changed

**Received**: None (system manager)

## Instance Variables (13 variables)
- `resource_manager` - Reference to ResourceManager system
- `loot_system` - Reference to LootSystem
- `data_loader` - Reference to DataLoader (static)
- `role_definitions: Dictionary` - Role system configuration from JSON
- `god_role_assignments: Dictionary` - God-to-role mappings
- `pantheon_role_distribution: Dictionary` - Pantheon role preferences
- `element_role_affinity: Dictionary` - Element-role relationships
- `territory_generation_cache: Dictionary` - Cached generation calculations
- `god_efficiency_cache: Dictionary` - Cached god efficiency values
- `cache_update_time: float` - Last cache update timestamp
- `cache_timeout_seconds: float` - Cache expiration time (300s)
- `balance_config: Dictionary` - Balance configuration from JSON

## Method Inventory

### System Initialization (4 methods)
- `_ready()` - Initialize system and load configurations
- `_initialize_system_references()` - Set up modular system dependencies
- `load_role_system()` - Load role configuration from DataLoader
- `load_balance_configuration()` - Load balance settings from DataLoader
- `_create_fallback_balance_config()` - Create default balance settings

### Role System Management (7 methods)
- `get_god_primary_role(god)` - Get god's primary role assignment
- `get_god_secondary_role(god)` - Get awakened god's secondary role
- `get_fallback_role_by_tier(tier)` - Assign role based on god tier
- `can_god_perform_role(god, role)` - Check if god can perform specific role
- `get_god_role_efficiency(god, role)` - Calculate god's efficiency in role (cached)
- `get_available_roles_for_god(god)` - Get all roles god can perform
- `create_fallback_role_system()` - Create default role system if JSON missing

### Territory Slot Management (4 methods)
- `get_territory_slot_configuration(territory)` - Get slot limits for territory
- `get_base_slot_configuration(tier)` - Base slots by territory tier
- `calculate_slot_upgrades(territory)` - Bonus slots from upgrades
- `get_territory_role_assignments(territory)` - Get current god assignments by role

### God Assignment System (4 methods)
- `assign_god_to_territory_role(god, territory, role)` - Assign god to territory role
- `remove_god_from_territory(god)` - Remove god from territory assignment
- `clear_caches_for_territory(territory_id)` - Clear cached data for territory
- `calculate_god_contribution(god, role, territory)` - Calculate god's resource contribution

### Resource Generation System (11 methods)
- `calculate_territory_passive_generation(territory)` - Main generation calculation with caching
- `get_base_territory_generation(territory)` - Base generation without god bonuses
- `_calculate_role_based_generation(territory, assigned_gods)` - Role-specific resource generation
- `_get_role_resource_generation(territory, role_type, gods, territory_roles_data)` - Per-role calculations
- `_get_territory_role_specialization(territory, role_type)` - Territory specialization lookup
- `_map_resource_to_territory(generic_resource, territory)` - Map generic to specific resources
- `_apply_summoners_war_balance(territory, base_generation, gods)` - Apply SW-style balance limits
- `_apply_territory_upgrades(territory, generation)` - Apply territory upgrade bonuses
- `_get_emergency_fallback_generation(territory)` - Emergency fallback generation
- `_get_god_tier_multiplier(god)` - Tier-based generation multiplier
- `_get_god_tier_name(god)` - Convert tier enum to string

### Resource Collection System (6 methods)
- `collect_territory_resources(territory)` - Collect resources from single territory
- `collect_all_territories_resources()` - Collect from all player territories
- `get_pending_resources_for_territory(territory)` - Preview pending resources
- `_apply_collection_modifiers(territory, resource_type, amount, hours_passed)` - Apply collection bonuses/caps
- `_award_resources_to_player(resources)` - Award resources through ResourceManager
- `_get_player_territory_count()` - Count player-controlled territories

### Caching System (4 methods)
- `_is_cache_valid(territory_id, current_time)` - Check cache validity
- `_get_assigned_gods_array(territory)` - Get God objects from territory
- `_cache_generation_result(territory_id, generation, timestamp)` - Cache generation data

### Analysis & Utilities (5 methods)
- `get_territory_efficiency_summary(territory)` - Comprehensive efficiency analysis
- `print_territory_debug(territory)` - Debug territory information
- `validate_role_system()` - Validate role system integrity
- `_calculate_fallback_god_contribution(god, role, territory, efficiency)` - Fallback contribution calculation

## Key Data Structures

### Role System Configuration
```gdscript
role_definitions = {
    "defender": {
        "name": "Defender",
        "base_benefits": {"territory_defense": 100},
        "tier_multipliers": {"common": 1.0, "rare": 1.2, "epic": 1.4, "legendary": 1.8}
    },
    "gatherer": {
        "name": "Gatherer",
        "base_benefits": {"resource_generation_bonus": 0.2},
        "tier_multipliers": {"common": 1.0, "rare": 1.2, "epic": 1.4, "legendary": 1.6}
    },
    "crafter": {
        "name": "Crafter",
        "base_benefits": {"crafting_speed": 0.15},
        "tier_multipliers": {"common": 1.0, "rare": 1.25, "epic": 1.5, "legendary": 1.8}
    }
}
```

### Territory Slot Configuration
- **Tier 1**: 1 defender, 2 gatherer, 0 crafter (3 total)
- **Tier 2**: 2 defender, 2 gatherer, 1 crafter (5 total)  
- **Tier 3**: 3 defender, 3 gatherer, 2 crafter (8 total)
- **Upgrades**: +1 slot per role every 5 territory levels

### Territory Specializations (13 territories)
- **Tier 1**: sacred_grove, crystal_springs, ember_hills, storm_peaks
- **Tier 2**: ancient_ruins, shadow_realm, elemental_nexus, divine_sanctum, frozen_wastes
- **Tier 3**: primordial_chaos, celestial_throne, volcanic_core

### Role Specialization System
- **Gatherer Sub-roles**: cultist (powder), soul_harvester (souls), miner (ore), energy_conduit (energy)
- **Crafter Sub-roles**: alchemist (conversions), chef (buffs), blacksmith (equipment)
- **Defender Sub-roles**: guardian (basic defense), champion (advanced defense)

## Notable Patterns
- **Modular Dependencies**: Proper dependency injection through GameManager
- **Caching System**: Performance optimization with 5-minute cache timeout
- **Territory Specialization**: Each territory produces different resources based on role assignments
- **Balance Control**: SW-style conservative generation with caps and diminishing returns
- **Tier Progression**: Clear progression from basic to advanced resource production

## Code Quality Issues

### Anti-Patterns Found
1. **Massive Responsibility**: 1020 lines handling roles, slots, generation, collection, caching
2. **Complex Calculations**: Deep nested calculations for resource generation
3. **Hard-coded Specializations**: Territory specializations embedded in code
4. **Mixed Abstraction Levels**: High-level management mixed with detailed calculations
5. **Extensive Method Count**: 50+ methods in single class

### Positive Patterns
1. **Modular Architecture**: Proper dependency injection and system separation
2. **Performance Optimization**: Intelligent caching system with timeouts
3. **Balance Control**: SW-style resource limits prevent exploitation
4. **Comprehensive Analysis**: Built-in efficiency and debug tools
5. **JSON Configuration**: External configuration for roles and balance

## Architectural Notes

### Strengths
- **Modular Design**: Clean integration with other systems via dependency injection
- **Performance**: Caching prevents expensive recalculations
- **Flexibility**: JSON-driven configuration allows easy balance changes
- **Rich Features**: Comprehensive role system with specializations and bonuses

### Concerns
- **Single Responsibility Violation**: Handles too many different concerns
- **Calculation Complexity**: Resource generation calculations are very complex
- **Specialization Hardcoding**: Territory specializations should be in JSON
- **Memory Usage**: Extensive caching may consume significant memory

## **CRITICAL OVERLAP ANALYSIS** 🚨

### **HUGE DUPLICATE POTENTIAL** with:
- **Territory.gd**: Both calculate territory resource generation and passive income
- **GameManager.gd**: Both handle territory assignment and resource collection
- **DataLoader.gd**: Both access territory and role configuration data
- **ResourceManager.gd**: Both manage resource awarding and tracking

### **ARCHITECTURAL OVERLAPS**:
- **Resource Generation**: Duplicates Territory.calculate_passive_income() patterns
- **God Assignment**: Overlaps with GameManager territory assignment methods
- **Configuration Access**: Duplicates DataLoader territory data access
- **Caching**: May duplicate caching patterns from other systems

## Refactoring Recommendations
1. **Split by Concern**:
   - TerritoryRoleManager (role assignments)
   - TerritoryResourceGenerator (generation calculations)
   - TerritorySlotManager (slot configuration)
   - TerritoryCollectionService (resource collection)

2. **Extract Specializations**: Move territory specializations to JSON configuration
3. **Unify Resource Generation**: Merge with Territory class resource methods
4. **Centralize Caching**: Create shared caching service for all systems
5. **Configuration Service**: Centralized configuration management

## **WHO CALLS WHO** - Connection Map

### **INBOUND CONNECTIONS** (Who calls TerritoryManager):
- **TerritoryScreen**: get_territory_efficiency_summary(), assign_god_to_territory_role(), collect_territory_resources()
- **TerritoryRoleScreen**: God role assignment interface methods
- **GameManager**: collect_all_territories_resources() during passive income generation
- **MainUIOverlay**: Resource generation display methods

### **OUTBOUND CONNECTIONS** (Who TerritoryManager calls):
- **DataLoader**: Configuration data access for roles, balance, and territory income
- **GameManager.player_data**: Resource awarding and god access
- **ResourceManager**: Award resources through modular system
- **Territory objects**: Access stationed gods and territory properties
- **God objects**: Role efficiency and assignment data

## Caching System
- **Generation Cache**: Territory resource generation results (5-minute timeout)
- **Efficiency Cache**: God role efficiency calculations (cleared on assignment changes)
- **Performance**: Prevents expensive recalculations during frequent UI updates
- **Invalidation**: Smart cache clearing when assignments or upgrades change

## Balance Controls
- **Conservative Generation**: 20% reduction for balance
- **Resource Caps**: Max 500 mana, 15 crystals per territory per hour
- **Diminishing Returns**: Progressive penalty for multiple territories
- **Overflow Protection**: Cap resources at 12-hour maximum storage
- **Collection Bonuses**: 10% bonus for frequent collection (under 2 hours)

## Missing Features
1. **Dynamic Specializations**: Territory specializations should be configurable
2. **Role Conflicts**: No system for handling role conflicts or preferences
3. **Historical Tracking**: No tracking of resource generation history
4. **Optimization Suggestions**: No auto-optimization for role assignments
5. **Battle Integration**: No integration with territory defense battles

This is another MASSIVE system doing EVERYTHING related to territories! Perfect for major refactoring! 🎯

# GameManager.gd Audit Report

## File Info
- **Path**: `scripts/systems/GameManager.gd`
- **Type**: Central Game Controller (extends Node)
- **Purpose**: Main game coordination and system management
- **Lines**: 1203 lines - **MASSIVE GOD CLASS**

## Incoming Dependencies
- **ALL DATA CLASSES**: PlayerData, God, Equipment, Territory, StatusEffect
- **ALL SYSTEMS**: 15+ system dependencies loaded and managed
- **UTILITIES**: DataLoader, ResourceManager, FileAccess, Timer, JSON

## Outgoing Signals
- `god_summoned(god)` - New god summoned
- `territory_captured(territory)` - Territory conquered
- `resources_updated()` - Resource changes occurred

## Class Properties
### Core Game State
- `player_data` - Player data instance
- `territories: Array` - All territory instances
- `resource_timer` - Passive income timer

### System References (15+ systems!)
- `summon_system` - God summoning
- `battle_system` - Combat management
- `awakening_system` - God awakening
- `sacrifice_system` - God sacrifice
- `loot_system` - Loot generation
- `dungeon_system` - Dungeon battles
- `wave_system` - Multi-wave battles
- `equipment_manager` - Equipment system
- `game_initializer` - Startup loading
- `territory_manager` - Territory roles
- `resource_manager` - Resource management
- `inventory_manager` - Item management
- `statistics_manager` - Battle analytics
- `progression_manager` - Player progression
- `tutorial_manager` - Tutorial system
- `notification_manager` - Notifications
- `ui_manager` - UI coordination

## Methods (Public) - 50+ methods!
### System Initialization
- `_ready()` - Entry point
- `initialize_game()` - **MASSIVE** game setup (all systems)
- `_on_initialization_complete()` - Post-init callback
- `give_starter_gods()` - Tutorial setup

### System Accessors (17 methods!)
- `get_summon_system()` through `get_notification_manager()` - System getters

### Summoning Interface
- `summon_basic()` - Basic summon
- `summon_element(element)` - Element summon
- `summon_premium()` - Premium summon

### Battle Interface
- `attack_territory(territory, gods)` - Territory attack
- `start_territory_assault(territory)` - Begin assault
- `auto_battle_territory(territory, gods)` - Auto-battle
- `battle_territory_stage(territory, stage, gods)` - **DUPLICATE** of start_territory_stage_battle
- `start_territory_stage_battle(territory, stage, gods)` - Stage battle
- `get_territory_battle_energy_cost(territory)` - Energy cost calculation
- `battle_in_territory(territory, gods)` - Territory battle
- `start_pve_battle(gods)` - PvE battle

### Awakening Interface
- `can_awaken_god(god)` - Check awakening eligibility
- `get_awakening_requirements(god)` - Get requirements
- `attempt_god_awakening(god)` - Perform awakening
- `upgrade_god_skill(god, skill_index)` - Skill upgrade
- `ascend_god(god, new_level)` - God ascension

### Territory Management (12 methods!)
- `initialize_territories()` - Load territory data
- `get_territory_by_id(territory_id)` - Territory lookup
- `assign_god_to_territory_role(god, territory, role)` - Role assignment
- `assign_god_to_territory_legacy(god, territory)` - **LEGACY** assignment
- `remove_god_from_territory(god)` - Remove god assignment
- `get_territory_role_assignments(territory)` - Get role assignments
- `get_god_available_roles(god)` - Available roles for god
- `get_territory_efficiency_summary(territory)` - Efficiency stats
- `get_territory_pending_resources(territory)` - Pending resources
- `collect_territory_resources(territory)` - Collect resources

### Resource Management
- `generate_resources()` - Passive income generation
- `calculate_territory_passive_income(territory)` - **DUPLICATE** logic with Territory class
- `get_territory_base_income(tier)` - Base income calculation
- `generate_offline_resources()` - Offline income calculation
- `award_stage_rewards(stage, territory, is_final)` - Stage completion rewards
- `award_experience_to_gods(xp_amount)` - XP distribution

### Save/Load System
- `save_game()` - **MASSIVE** save logic (100+ lines)
- `load_game()` - **MASSIVE** load logic (100+ lines)

### Signal Handlers (10+ methods!)
- `_on_summon_completed(god)` - Summon success
- `_on_summon_failed(reason)` - Summon failure
- `_on_battle_completed(result)` - **MASSIVE** battle completion (100+ lines)
- `_on_awakening_completed(god)` - Awakening success
- `_on_awakening_failed(god, reason)` - Awakening failure
- `_on_sacrifice_completed(target, materials, xp)` - Sacrifice completion
- `_on_equipment_changed()` - Equipment changes
- `_on_equipment_enhanced()` - Equipment enhancement
- `_on_god_summoned_refresh_cache(god)` - Cache refresh
- `_on_resource_timer_timeout()` - Resource generation
- `_on_auto_save_timer_timeout()` - Auto-save
- `_on_energy_timer_timeout()` - Energy regeneration

### Territory Upgrade System (8 methods!)
- `can_afford_territory_upgrade(territory)` - Check affordability
- `spend_territory_upgrade_cost(territory)` - Spend costs
- Plus 6 more for different upgrade types

### Equipment Serialization (6 methods!)
- `_serialize_equipped_equipment(equipped)` - Equipment to dict
- `_deserialize_equipped_equipment(serialized)` - Dict to equipment
- `_equipment_to_dict(equipment)` - Single equipment serialization
- `_dict_to_equipment(dict)` - Single equipment deserialization
- `_serialize_equipment_inventory()` - Full inventory serialization
- `_deserialize_equipment_inventory(data)` - Full inventory deserialization

### Utility
- `get_god_by_id(god_id)` - God lookup
- `get_resource_manager()` - ResourceManager access
- `_notification(what)` - App lifecycle

## Potential Issues & Duplicate Code
### Massive God Class Issues
1. **1203 LINES** - This is a god class anti-pattern
2. **15+ System Dependencies** - Violates single responsibility
3. **50+ Methods** - Too many concerns in one class
4. **Mixed Abstraction Levels** - High-level coordination mixed with low-level details

### Duplicate Code
1. **Battle Methods**:
   - `battle_territory_stage()` vs `start_territory_stage_battle()` - Same functionality
2. **Territory Assignment**:
   - Modern + Legacy systems running in parallel
3. **Resource Calculation**:
   - Logic duplicated between GameManager and Territory classes

### Code Smells
1. **Initialization Hell**: `initialize_game()` is 100+ lines creating 17 systems
2. **Signal Web**: Complex web of signal connections
3. **Save/Load Complexity**: Massive serialization logic in main class
4. **Magic Numbers**: Hard-coded values throughout
5. **Error Handling**: Minimal error handling for critical operations

### Critical Problems
1. **System Coupling**: All systems directly coupled to GameManager
2. **State Management**: No clear state management pattern
3. **Memory Management**: No cleanup or resource management
4. **Thread Safety**: No protection for concurrent access
5. **Testing**: Impossible to unit test due to massive dependencies

## Recommendations (URGENT)
### Immediate Actions
1. **Split the God Class**:
   - GameManager (coordination only)
   - SystemManager (system lifecycle)
   - SaveManager (save/load)
   - ResourceController (resource operations)
   - TerritoryController (territory operations)
   - BattleController (battle coordination)

2. **Remove Duplicates**:
   - Eliminate `battle_territory_stage()`
   - Remove legacy territory assignment
   - Consolidate resource calculation

3. **Dependency Injection**:
   - Systems should not be created by GameManager
   - Use dependency injection or service locator

4. **Event System**:
   - Replace direct method calls with event bus
   - Decouple systems from GameManager

5. **State Pattern**:
   - Implement proper game state management
   - Separate loading/playing/paused states

## Connected Systems (ALL OF THEM)
This class connects to literally every system in the game:
- All data classes (God, Equipment, Territory, etc.)
- All manager classes (15+ systems)
- All UI components through signals
- Save/Load system
- Resource management
- Battle system
- Tutorial system

**This is the most critical file to refactor in the entire codebase.**

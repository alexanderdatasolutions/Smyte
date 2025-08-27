# BattleSetupScreen.gd Audit Report

## Overview
- **File**: `scripts/ui/BattleSetupScreen.gd`
- **Type**: Universal Battle Setup Interface
- **Lines of Code**: 874
- **Class Type**: Control (UI Screen)

## Purpose
Universal battle preparation screen that handles team selection and battle configuration for multiple battle types (territory, dungeon, PvP, raid). Provides god selection, team composition, enemy preview, and reward display functionality.

## Dependencies
### Inbound Dependencies (What this relies on)
- **GameManager**: Player data access, system managers
- **God.gd**: God object properties and methods
- **EnemyFactory**: Enemy creation for battle previews
- **ResourceManager**: Dynamic resource name retrieval
- **CollectionScreen styling**: Tier colors and visual consistency

### Outbound Dependencies (What depends on this)
- **DungeonScreen**: Receives battle setup completion signals
- **TerritoryScreen**: Receives battle setup completion signals  
- **BattleScreen**: Receives complete battle context for execution
- **UIManager**: Screen transition management

## Signals (2 signals)
**Emitted**:
- `battle_setup_complete(context: Dictionary)` - Battle setup completed with full context
- `setup_cancelled` - User cancelled battle setup

**Received**: None (pure UI input handling)

## Instance Variables (12 variables)
- `battle_context: Dictionary` - Complete battle configuration and metadata
- `selected_team: Array` - Currently selected gods for team (includes nulls)
- `team_slots: Array` - UI team slot controls
- `max_team_size: int` - Maximum team size (4 for most, 5 for raids)
- `current_sort: SortType` - Current god sorting method
- `sort_ascending: bool` - Sort direction flag
- `title_label: Label` - Battle title display
- `description_label: Label` - Battle description display
- `team_selection_container: Container` - Team selection UI container
- `team_slots_container: Container` - Team slots UI container
- `available_gods_scroll: ScrollContainer` - Available gods scroll area
- `available_gods_grid: GridContainer` - Available gods grid layout

## Method Inventory

### Core Initialization (4 methods)
- `_ready()` - Initialize UI and connect signals
- `_initialize_ui()` - Deferred UI component initialization
- `_deferred_ui_update()` - Manual node finding when @onready fails
- `setup_sorting_ui()` - Create sorting controls for god selection

### Battle Type Setup (4 methods)
- `setup_for_territory_battle(territory, stage)` - Configure for territory assault
- `setup_for_dungeon_battle(dungeon_id, difficulty)` - Configure for dungeon challenge
- `setup_for_pvp_battle(opponent_data)` - Configure for PvP (future)
- `setup_for_raid_battle(raid_data)` - Configure for raid (future)

### UI Context Management (1 method)
- `_update_ui_for_context()` - Update UI based on battle type and data

### Team Slot Management (5 methods)
- `_create_team_slots()` - Clear and initialize team slots
- `_refresh_team_slots()` - Refresh slots based on max team size
- `_create_team_slot(index)` - Create individual team slot UI
- `_update_slot_display(slot_index)` - Update slot visual state
- `_on_team_slot_pressed(slot_index)` - Handle slot click (clear god)

### God Selection (4 methods)
- `_load_available_gods()` - Load and display available gods
- `_create_god_selection_button(god)` - Create god selection card
- `_on_god_selected(god)` - Handle god selection from grid
- `_assign_god_to_slot(god, slot_index)` - Assign god to specific slot

### Team Management (2 methods)
- `_clear_slot(slot_index)` - Clear specific team slot
- `get_selected_team()` - Get final team (non-null gods only)

### Sorting System (4 methods)
- `sort_gods(gods)` - Sort gods array by current criteria
- `_on_sort_changed(sort_type)` - Handle sort type change
- `_on_sort_direction_changed()` - Toggle sort direction
- `SortType` enum - POWER, LEVEL, TIER, ELEMENT, NAME

### Visual Styling (6 methods)
- `_get_element_color(element)` - Element color mapping
- `_get_subtle_tier_color(tier)` - Subtle tier background colors
- `_get_tier_border_color(tier)` - Tier border colors
- `_get_tier_short_name(tier)` - Compact tier names (C, UC, R, E, L)
- `_get_element_short_name(element)` - Compact element names
- `_update_start_button_state()` - Update battle button state and text

### Enemy Preview (4 methods)
- `_load_enemy_preview()` - Load territory enemy preview
- `_load_dungeon_enemy_preview()` - Load dungeon enemy preview
- `_load_pvp_enemy_preview()` - Placeholder for PvP enemies
- `_load_raid_enemy_preview()` - Placeholder for raid enemies

### Reward Preview (6 methods)
- `_load_territory_rewards()` - Load territory stage rewards
- `_load_dungeon_rewards()` - Load dungeon-specific rewards
- `_load_pvp_rewards()` - Placeholder for PvP rewards
- `_load_raid_rewards()` - Placeholder for raid rewards
- `_clear_rewards_display()` - Clear rewards container
- `_add_reward_item(reward_text)` - Add single reward item

### Battle Action (2 methods)
- `_on_start_battle_pressed()` - Validate team and emit battle_setup_complete
- `_on_cancel_pressed()` - Cancel setup and emit setup_cancelled

### Utility (1 method)
- `get_battle_context()` - Get current battle context copy

## Key Data Structures

### Battle Context Structure
```gdscript
battle_context = {
    "type": "territory|dungeon|pvp|raid",
    "territory": Territory,          # For territory battles
    "stage": int,                    # For territory battles
    "dungeon_id": String,           # For dungeon battles
    "difficulty": String,           # For dungeon battles
    "dungeon_info": Dictionary,     # For dungeon battles
    "unlock_info": Dictionary,      # For dungeon battles
    "opponent": Dictionary,         # For PvP battles
    "raid_data": Dictionary,        # For raid battles
    "title": String,                # Display title
    "description": String,          # Display description
    "team": Array                   # Final selected team
}
```

### Sort Types
- **POWER**: Sort by god power rating (default)
- **LEVEL**: Sort by god level
- **TIER**: Sort by god tier (rarity)
- **ELEMENT**: Sort by element type
- **NAME**: Sort alphabetically by name

### Team Size Limits
- **Territory/Dungeon/PvP**: 4 gods maximum
- **Raid**: 5 gods maximum (future expansion)

## Notable Patterns
- **Universal Design**: Single screen handles all battle types
- **Deferred Initialization**: Handles @onready failures gracefully
- **CollectionScreen Consistency**: Reuses visual styling patterns
- **Dynamic Resource Names**: Uses ResourceManager for localization
- **Progressive Disclosure**: Only shows relevant UI for battle type

## Code Quality Issues

### Anti-Patterns Found
1. **Large Responsibility**: 874 lines handling setup for 4+ battle types
2. **UI Node Dependency**: Heavy reliance on @onready node references
3. **Hardcoded Magic Numbers**: Team sizes, dimensions, style values
4. **Future Placeholders**: Empty PvP/raid methods taking up space
5. **Manual Node Finding**: Fallback node finding when @onready fails

### Positive Patterns
1. **Universal Interface**: Single setup screen for all battle types
2. **Visual Consistency**: Consistent styling with other UI screens
3. **Comprehensive Sorting**: Multiple sort options for god selection
4. **Preview System**: Enemy and reward previews for informed decisions
5. **Graceful Degradation**: Handles missing components well

## Architectural Notes

### Strengths
- **Flexible Architecture**: Easily extensible for new battle types
- **Rich UI Features**: Sorting, previews, visual feedback
- **Complete Context**: Passes comprehensive battle data
- **User Experience**: Intuitive team building interface

### Concerns
- **Monolithic Design**: Single class handling too many battle types
- **Node Coupling**: Heavy dependency on specific scene structure
- **Future Bloat**: Placeholder methods will expand significantly
- **Style Duplication**: Repeated styling code across methods

## Duplicate Code Potential
- **Color Methods**: Similar color/styling logic across multiple methods
- **Preview Loading**: Similar pattern for enemy/reward preview loading
- **UI Creation**: Repeated UI element creation patterns
- **Validation Logic**: Similar validation patterns across battle types

## Critical Integration Points

### **MAJOR UI INTEGRATION** 🎯
- **DungeonScreen Integration**: Direct signal connection for setup completion
- **BattleScreen Coordination**: Passes complete battle context
- **EnemyFactory Dependency**: Creates enemy previews for all battle types
- **GameManager Access**: Heavy reliance on centralized data access

### **POTENTIAL DUPLICATES** with other systems:
- **God Selection**: Similar logic to CollectionScreen's god browsing
- **Team Management**: May overlap with other team building interfaces
- **Sorting Logic**: Similar sorting patterns across UI screens
- **Preview Generation**: May overlap with other preview systems

## Refactoring Recommendations
1. **Split by Battle Type**:
   - BattleSetupCore (common functionality)
   - TerritoryBattleSetup 
   - DungeonBattleSetup
   - PvPBattleSetup (future)
   - RaidBattleSetup (future)

2. **Extract Common Components**:
   - GodSelectionWidget (reusable god picker)
   - TeamSlotManager (team slot management)
   - BattlePreviewPanel (enemy/reward previews)
   - SortingControls (reusable sorting UI)

3. **Centralize Styling**: Create shared styling resources
4. **Remove Future Placeholders**: Move PvP/raid to separate files when implemented
5. **Simplify Node Management**: Use more robust node finding patterns

## Connection Map - WHO TALKS TO WHOM

### **INBOUND CONNECTIONS** (Who calls BattleSetupScreen):
- **DungeonScreen**: setup_for_dungeon_battle(), connects to signals
- **TerritoryScreen**: setup_for_territory_battle(), connects to signals
- **UIManager**: Screen transition management

### **OUTBOUND CONNECTIONS** (Who BattleSetupScreen calls):
- **GameManager.player_data**: Access gods, validate data
- **EnemyFactory**: create_enemies_for_stage(), create_enemies_for_dungeon()
- **GameManager.get_resource_manager()**: get_resource_info() for dynamic names
- **GameManager.get_dungeon_system()**: get_dungeon_info(), get_difficulty_unlock_requirements()

### **SIGNAL CONNECTIONS**:
- **Emits TO**: DungeonScreen, TerritoryScreen (battle_setup_complete, setup_cancelled)
- **Receives FROM**: UI buttons and controls (internal signal handling)

## Battle Type Support Status
- **Territory Battles**: ✅ FULLY IMPLEMENTED
- **Dungeon Battles**: ✅ FULLY IMPLEMENTED  
- **PvP Battles**: 🚧 PLACEHOLDER ONLY
- **Raid Battles**: 🚧 PLACEHOLDER ONLY

## UI Features Implemented
- **God Selection Grid**: ✅ With tier styling and sorting
- **Team Slot Management**: ✅ Visual feedback and slot interaction
- **Battle Preview**: ✅ Enemy and reward information
- **Context-Aware Setup**: ✅ Different setup per battle type
- **Sorting System**: ✅ 5 sort types with direction toggle

This is a well-designed universal setup screen that's handling multiple battle types efficiently! The architecture is solid but could benefit from splitting when PvP/raid are implemented. 🎯

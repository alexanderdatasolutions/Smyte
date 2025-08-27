# ResourceDisplay.gd Audit Report

## Overview
- **File**: `scripts/ui/ResourceDisplay.gd`
- **Type**: Persistent Resource Display Widget
- **Lines of Code**: 428
- **Class Type**: HBoxContainer (UI Widget)

## Purpose
Persistent resource display widget that shows key player resources (level, mana, crystals, energy, tickets, materials) across all game screens. Uses singleton pattern for global synchronization of multiple instances.

## Dependencies
### Inbound Dependencies (What this relies on)
- **GameManager**: Player data access and resource update signals
- **PlayerData**: Resource values and energy management
- **ProgressionManager**: Player level calculations and progression signals
- **ResourceManager**: Materials data and inventory management

### Outbound Dependencies (What depends on this)
- **All game screens**: Display persistent resource information
- **MainUIOverlay**: Manages display positioning and layering

## Signals (0 signals)
**Emitted**: None (display widget)
**Received**:
- `GameManager.resources_updated` - Refresh all resource displays
- `ProgressionManager.player_leveled_up` - Update level display

## Instance Variables (9 variables)
- `_instances: Array` - Static array of all ResourceDisplay instances
- `player_level_label: Label` - Dynamically created level display
- `mana_label: Label` - Primary currency display
- `crystal_label: Label` - Premium currency display
- `energy_label: Label` - Stamina display with regeneration timer
- `tickets_label: Label` - Summon tickets display
- `materials_button: Button` - Opens materials inventory popup
- `materials_count_label: Label` - Total materials count
- `resource_manager: Node` - ResourceManager reference

## Method Inventory

### Core Lifecycle (2 methods)
- `_ready()` - Initialize instance, add to singleton list, setup UI
- `_exit_tree()` - Cleanup, remove from singleton list, disconnect signals

### Initialization (5 methods)
- `_initialize_resource_manager()` - Get or create ResourceManager reference
- `_setup_signal_connections()` - Connect to GameManager signals (first instance only)
- `_setup_progression_signals()` - Connect to progression system
- `_setup_materials_button()` - Setup materials button interactions
- `_create_player_level_label()` - Dynamically create level label

### Display Updates (8 methods)
- `_update_all_instances()` - Static method to update all instances globally
- `_update_this_instance()` - Update this specific instance
- `_update_player_level_display()` - Update level and XP display
- `_update_mana_display()` - Update primary currency
- `_update_crystals_display()` - Update premium currency
- `_update_energy_display()` - Update stamina with regeneration timer
- `_update_tickets_display()` - Update summon tickets
- `_update_materials_count()` - Update total materials count

### Materials Inventory (5 methods)
- `_show_materials_table()` - Create and display materials popup
- `_add_table_header(grid, text)` - Add header to materials table
- `_populate_materials_table(grid)` - Populate table with materials data
- `_add_material_row(grid, material_data)` - Add individual material row
- `_create_header_style()` - Create table header styling

### Utility Functions (3 methods)
- `format_large_number(number)` - Format numbers with K/M/B suffixes
- `_get_total_materials_count()` - Calculate total materials owned
- `_get_player_resource(resource_id)` - Get resource value from PlayerData

### Debug (1 method)
- `debug_print_resources()` - Debug helper for resource information

## Key Architectural Features

### Singleton Pattern
- **Static Instance List**: All ResourceDisplay instances tracked globally
- **Synchronized Updates**: All instances update simultaneously when resources change
- **Single Signal Connection**: Only first instance connects to avoid duplicate signals
- **Global State Management**: Ensures consistency across all screens

### Dynamic UI Creation
- **Player Level Label**: Created dynamically if not found in scene
- **Robust Node Finding**: Tries to find existing nodes before creating new ones
- **Flexible Layout**: Adapts to different scene structures

### Energy System Integration
- **Regeneration Timer**: Shows time until energy is full
- **Real-time Updates**: Live energy regeneration display
- **Smart Formatting**: Hours and minutes for long regeneration times

### Materials Inventory
- **Comprehensive Popup**: Complete materials inventory in popup dialog
- **Dynamic Table**: Generated from ResourceManager data
- **Sorted Display**: Organized by category and name
- **Color Coding**: Amount-based color indicators

## Notable Patterns
- **Singleton Instance Management**: Clean global state synchronization
- **Signal Optimization**: Only one instance connects to prevent duplicates
- **Dynamic UI Adaptation**: Creates missing UI elements automatically
- **Comprehensive Resource Display**: Covers all major resource types

## Code Quality Issues

### Anti-Patterns Found
1. **Singleton Complexity**: Complex global instance management
2. **Mixed Concerns**: UI display mixed with data access and popup creation
3. **Dynamic Node Creation**: Complex fallback node creation logic
4. **ResourceManager Coupling**: Direct dependency on ResourceManager
5. **Large Method**: Materials popup creation is complex

### Positive Patterns
1. **Global Synchronization**: Excellent singleton pattern implementation
2. **Comprehensive Display**: Complete resource information coverage
3. **Real-time Updates**: Live energy regeneration and resource tracking
4. **User-Friendly Formatting**: Large number formatting and timer displays
5. **Robust Error Handling**: Graceful handling of missing components

## Architectural Notes

### Strengths
- **Global Consistency**: Ensures all instances show same data
- **Comprehensive Coverage**: Displays all important resources
- **Real-time Updates**: Live regeneration and resource tracking
- **User Experience**: Rich formatting and interactive materials view

### Concerns
- **Singleton Complexity**: Complex global state management
- **Tight Coupling**: Heavy dependencies on multiple systems
- **Large Responsibility**: Handles display, popup creation, and data access
- **Performance**: Materials popup creation is resource-intensive

## Critical Integration Points

### **MAJOR SYSTEM INTEGRATION** 🎯
- **PlayerData Dependency**: Complete reliance on player resource data
- **GameManager Signals**: Central to resource update notifications
- **ProgressionManager Integration**: Essential for level display
- **ResourceManager Coupling**: Materials display depends on ResourceManager

### **SINGLETON PATTERN COMPLEXITY**:
- **Global Instance Tracking**: All instances must be synchronized
- **Signal Management**: Complex signal connection optimization
- **Memory Management**: Proper cleanup when instances destroyed
- **State Consistency**: All instances must show identical data

## Refactoring Recommendations
1. **Split Responsibilities**:
   - ResourceDisplayWidget (core display)
   - MaterialsInventoryDialog (popup functionality)
   - ResourceFormatter (number formatting utilities)

2. **Simplify Singleton**: Use simpler global update mechanism
3. **Extract Materials UI**: Move materials popup to separate component
4. **Centralize Formatting**: Create shared formatting utilities
5. **Reduce Coupling**: Use events instead of direct system dependencies

## Connection Map - WHO TALKS TO WHOM

### **INBOUND CONNECTIONS** (Who calls ResourceDisplay):
- **MainUIOverlay**: Manages positioning and layer assignment
- **All game screens**: Display persistent resource information
- **GameManager**: resources_updated signal triggers updates

### **OUTBOUND CONNECTIONS** (Who ResourceDisplay calls):
- **GameManager.player_data**: get_resource(), get_energy_status()
- **ProgressionManager**: calculate_level_from_experience(), get_experience_to_next_level()
- **ResourceManager**: get_all_materials(), materials data access
- **UI system**: Popup creation and display

### **SIGNAL CONNECTIONS**:
- **Emits TO**: None
- **Receives FROM**: GameManager (resources_updated), ProgressionManager (player_leveled_up)

## Resource Display Coverage
- **Player Level**: Level and XP progress (dynamic creation)
- **Mana**: Primary currency with large number formatting
- **Divine Crystals**: Premium currency
- **Energy**: Stamina with regeneration timer
- **Summon Tickets**: Summoning currency
- **Materials**: Total count with detailed popup inventory

## Materials Inventory Features
- **Popup Dialog**: 700x500 comprehensive materials view
- **Sortable Display**: Organized by category and name
- **Color Coding**: Amount-based visual indicators
- **Dynamic Content**: Generated from ResourceManager data
- **Table Format**: Organized grid with headers

This is a **COMPREHENSIVE RESOURCE DISPLAY** system! The singleton pattern works well for global synchronization, but the architecture could benefit from splitting responsibilities. The materials inventory popup is particularly feature-rich. 🎯

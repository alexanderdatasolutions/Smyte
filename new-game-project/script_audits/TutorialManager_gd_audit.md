# TutorialManager.gd Audit Report

## Overview
- **File**: `scripts/systems/TutorialManager.gd`
- **Type**: First Time User Experience (FTUE) System
- **Lines of Code**: 1124
- **Class Type**: Node (Tutorial orchestration system)

## Purpose
Comprehensive tutorial system managing new player onboarding, feature introductions, and progressive unlocks. Implements Summoners War-style FTUE with modular step-based tutorials, XP rewards, and feature gating.

## Dependencies
### Inbound Dependencies (What this relies on)
- **GameManager**: System references, player data access, save functionality
- **PlayerData**: Tutorial completion tracking, god collection, resource storage
- **ProgressionManager**: XP awarding, level tracking, tutorial completion marking
- **UIManager**: UI system coordination and screen management
- **TutorialDialog**: Preloaded scene for step display and user interaction
- **God class**: Starter god creation from JSON data
- **WorldView**: Screen navigation and building button triggers

### Outbound Dependencies (What depends on this)
- **MainUIOverlay**: Tutorial dialog positioning and overlay management
- **Battle systems**: Tutorial battle demonstrations and showcases
- **All feature screens**: Tutorial guidance and introductions
- **Progression tracking**: Tutorial completion and milestone rewards

## Signals (8 signals)
**Emitted**:
- `tutorial_started(tutorial_name)` - Tutorial sequence begins
- `tutorial_completed(tutorial_name)` - Tutorial sequence finished
- `tutorial_step_completed(tutorial_name, step_number)` - Individual step finished
- `feature_unlocked(feature_name)` - New feature becomes available
- `resource_granted(resource_type, amount)` - Resources awarded during tutorial
- `tutorial_dialog_created(dialog)` - Dialog needs positioning by MainUIOverlay

**Received**: 
- `dialog_completed` - From TutorialDialog when user clicks continue

## Instance Variables (11 variables)
- `current_tutorial: String` - Currently active tutorial name
- `current_step: int` - Current step index in tutorial sequence
- `tutorial_active: bool` - Whether any tutorial is currently running
- `_pending_navigation: String` - Screen to navigate to after dialog completion
- `tutorial_dialog: TutorialDialog` - Tutorial UI dialog instance
- `tutorial_dialog_scene` - Preloaded TutorialDialog scene
- `tutorial_definitions: Dictionary` - All tutorial configurations and step data
- `completed_tutorials: Array` - List of completed tutorial names
- `player_data: PlayerData` - Reference to player data system
- `game_manager: Node` - Reference to GameManager
- `progression_manager: Node` - Reference to ProgressionManager

## Method Inventory

### System Initialization (4 methods)
- `_ready()` - Initialize tutorial system and load dependencies
- `_setup_tutorial_dialog()` - Create and configure tutorial dialog UI
- `_ensure_dialog_in_scene()` - Add dialog to MainUIOverlay or fallback scene
- `setup_tutorial_definitions()` - Load all tutorial sequences and step configurations

### Core Tutorial Management (4 methods)
- `start_tutorial(tutorial_name)` - Begin specified tutorial with validation
- `stop_current_tutorial()` - Stop active tutorial and cleanup state
- `execute_current_step()` - Execute current step based on type
- `complete_tutorial()` - Mark tutorial complete and handle rewards

### Tutorial Step Execution (8 methods)
- `execute_dialog_step(step_data)` - Show dialog with text and continue button
- `execute_battle_step(step_data)` - Run battle demonstration (instant completion)
- `execute_selection_step(step_data)` - Handle god selection or auto-granting
- `execute_navigation_step(step_data)` - Guide player to specific screen
- `execute_summon_step(step_data)` - Guide through summoning tutorial
- `execute_sacrifice_step(step_data)` - Guide through sacrifice tutorial
- `execute_management_step(step_data)` - Guide through territory management
- `execute_equipment_step(step_data)` - Guide through equipment tutorial

### Tutorial Flow Control (4 methods)
- `advance_tutorial_step()` - Move to next step in sequence
- `_process_step_rewards(step_data)` - Grant XP, unlock features, award resources
- `handle_tutorial_completion(tutorial_name)` - Post-completion processing
- `_navigate_to_screen(screen_name)` - Navigate to target screen after dialog

### Tutorial State Management (4 methods)
- `is_tutorial_completed(tutorial_name)` - Check completion status
- `is_tutorial_active()` - Check if any tutorial running
- `get_current_tutorial()` - Get active tutorial name
- `get_current_step()` - Get current step number

### Tutorial Triggering System (3 methods)
- `should_trigger_first_time_experience()` - Check if FTUE needed
- `trigger_feature_tutorial(feature_name)` - Start feature-specific tutorial
- `trigger_territory_stage_completion(stage_number)` - Progressive unlock tutorials

### Tutorial Action Handlers (6 methods)
- `handle_god_selection_completed(selected_gods)` - Process god selection results
- `handle_battle_completed()` - Process battle completion
- `handle_summon_completed()` - Process summon completion
- `handle_sacrifice_completed()` - Process sacrifice completion
- `handle_management_action_completed()` - Process management action completion
- `handle_equipment_action_completed()` - Process equipment action completion

### God and Starter Management (3 methods)
- `grant_starter_gods(god_ids)` - Award starter gods to new players
- `show_god_selection_ui(god_pool, selection_count)` - Display god selection interface
- `show_feature_introduction_dialog(title, message)` - Show feature unlock dialogs

### UI and Navigation Support (6 methods)
- `show_tutorial_dialog(title, text, auto_advance)` - Display tutorial dialog with pause
- `_on_dialog_completed()` - Handle dialog completion and advancement
- `_on_dialog_timeout()` - Safety timeout for stuck dialogs
- `_check_dialog_fallback()` - Fallback dialog positioning
- `_find_world_view()` - Locate WorldView for navigation
- `_search_node_by_name(node, target_name)` - Recursive node search

### Battle and Action Guidance (5 methods)
- `setup_tutorial_battle(battle_setup)` - Set up demonstration battles
- `guide_to_screen(screen_name)` - Guide player to specific screens
- `guide_summon_action(summon_type)` - Guide summoning actions
- `guide_sacrifice_action(required)` - Guide sacrifice actions
- `guide_management_action(action_type)` - Guide management actions
- `guide_equipment_action(action_type)` - Guide equipment actions

### Debug and Testing (8 methods)
- `debug_reset_tutorials()` - Reset all tutorial completion states
- `debug_complete_tutorial(tutorial_name)` - Mark specific tutorial complete
- `get_debug_info()` - Get comprehensive debug information
- `debug_trigger_stage_completion(stage_number)` - Manually trigger stage tutorials
- `debug_show_available_tutorials()` - List all available tutorials
- `debug_test_summoners_war_flow()` - Test complete FTUE flow
- `_debug_reset_player_data()` - Reset player data for testing

## Key Data Structures

### Tutorial Definition Structure
```gdscript
{
    "tutorial_name": {
        "name": "Display Name",
        "description": "Tutorial Description", 
        "trigger": "trigger_type",  # Optional
        "steps": [
            {
                "id": "step_id",
                "type": "dialog|battle|selection|navigation",
                "title": "Step Title",
                "text": "Step Content",
                "button_text": "Button Text",
                "xp_reward": 25,  # Optional
                "unlock_features": ["feature_list"],  # Optional
                "navigation_target": "screen_name"  # Optional
            }
        ]
    }
}
```

### Step Types Supported
- **dialog**: Text-based explanations with continue buttons
- **battle**: Battle demonstrations (auto-complete)
- **selection**: God selection or auto-granting
- **navigation**: Guide to specific screens
- **summon_action**: Summoning system tutorials
- **sacrifice_action**: Sacrifice system tutorials
- **management_action**: Territory management tutorials
- **equipment_action**: Equipment system tutorials

## Tutorial Sequences Defined

### **first_time_experience** (5 steps)
1. **welcome** - Welcome message and introduction
2. **combat_showcase** - Battle demonstration with max level gods
3. **god_selection** - Grant starter pantheon (Ares, Athena, Poseidon)
4. **first_territory_intro** - Introduction to territory system
5. **Auto-navigation** - Guide to territory screen

### **Progressive Territory Unlocks** (5 tutorials)
- **territory_stage_1_complete**: Unlock Collection screen (+25 XP)
- **territory_stage_2_complete**: Unlock Summoning Portal (+35 XP)
- **territory_stage_3_complete**: Unlock Sacrifice Altar (+45 XP)
- **territory_stage_4_complete**: Unlock Territory Management (+55 XP)
- **territory_stage_5_complete**: Unlock Divine Equipment (+65 XP)

### **Feature-Specific Tutorials** (4 tutorials)
- **summon_system_tutorial**: Free summon demonstration
- **sacrifice_system_tutorial**: Sacrifice demonstration
- **territory_management_tutorial**: God role assignment
- **equipment_system_tutorial**: Equipment tutorial

## Notable Patterns
- **Modular Architecture**: Scene-based UI with proper dependency injection
- **Progressive Unlock**: Features unlock through territory stage completion
- **Summoners War Flow**: Level 1 with 3 starter gods → progressive feature unlocks
- **XP Progression**: Tutorials award XP to drive natural level progression
- **Robust Error Handling**: Validation, fallbacks, and safety timeouts
- **State Persistence**: Tutorial completion tracked in PlayerData

## Code Quality Assessment

### Strengths
1. **Comprehensive FTUE**: Complete new player experience
2. **Modular Design**: Clean separation of tutorial types and execution
3. **Progressive Unlocks**: Natural feature introduction through gameplay
4. **Robust Error Handling**: Extensive validation and fallback systems
5. **Debug Support**: Comprehensive testing and debug tools
6. **State Management**: Proper tutorial completion tracking

### Issues Found
1. **MASSIVE SIZE**: 1124 lines - way too big for single responsibility
2. **Mixed Concerns**: UI management, flow control, data management, and navigation
3. **Hard-coded Navigation**: Direct WorldView method calls
4. **Complex Dependencies**: Depends on too many different systems
5. **Magic Numbers**: Hard-coded XP values and timeouts

## **OVERLAP ANALYSIS** 🚨

### **SIGNIFICANT OVERLAP** with:
- **ProgressionManager.gd**: Both award XP and track tutorial completion
- **GameManager.gd**: Both handle player progression and system coordination
- **UIManager.gd**: Both manage screen navigation and UI flow
- **DataLoader.gd**: Both access configuration data and manage JSON definitions

### **ARCHITECTURAL OVERLAPS**:
- **XP Awarding**: Duplicates ProgressionManager XP reward system
- **Navigation**: Reimplements screen navigation outside of UIManager
- **State Management**: Overlaps with GameManager state coordination
- **Feature Unlocking**: May duplicate progression tracking

## Refactoring Recommendations

### **URGENT SPLIT NEEDED** - Break into 5+ classes:
1. **TutorialOrchestrator**: Core tutorial flow and step management
2. **TutorialDefinitionLoader**: Tutorial configuration and setup
3. **TutorialUIManager**: Dialog display and user interaction
4. **TutorialProgressionManager**: XP rewards and feature unlocks
5. **TutorialNavigationService**: Screen navigation and guidance

### **Configuration Extraction**:
- Move tutorial definitions to JSON files
- Extract XP rewards to balance configuration
- Centralize feature unlock mappings

### **Dependency Cleanup**:
- Remove direct WorldView dependency
- Use proper UIManager for navigation
- Delegate XP awarding to ProgressionManager
- Use event system for loose coupling

## **WHO CALLS WHO** - Connection Map

### **INBOUND CONNECTIONS** (Who calls TutorialManager):
- **GameManager**: FTUE triggering and tutorial system initialization
- **Battle systems**: Tutorial completion notifications
- **Territory systems**: Stage completion triggers
- **Feature screens**: Action completion handlers
- **TutorialDialog**: Dialog completion callbacks

### **OUTBOUND CONNECTIONS** (Who TutorialManager calls):
- **GameManager**: Player data access, save functionality
- **ProgressionManager**: XP awarding and level tracking
- **UIManager**: Screen navigation requests (should be primary path)
- **PlayerData**: Tutorial completion tracking and god granting
- **WorldView**: Direct navigation calls (architectural violation)
- **God class**: Starter god creation from JSON

## Performance Characteristics
- **Heavy Initialization**: Large tutorial definitions loaded at startup
- **Memory Usage**: Persistent tutorial definitions and state tracking
- **Scene Management**: Dynamic dialog creation and positioning
- **Validation Overhead**: Extensive error checking and fallback systems

## Integration Points
- **Player Onboarding**: Primary entry point for new players
- **Feature Introduction**: Triggered by progression milestones
- **System Coordination**: Orchestrates multiple game systems
- **Save System**: Tutorial completion persisted in PlayerData

## Missing Features
1. **Tutorial Skipping**: No skip option for experienced players
2. **Tutorial Replay**: No ability to replay completed tutorials
3. **Dynamic Tutorials**: No runtime tutorial creation
4. **A/B Testing**: No support for tutorial variations
5. **Analytics**: No tutorial completion tracking for optimization

## Critical Issues
1. **God Class**: Far too many responsibilities in single class
2. **Tight Coupling**: Direct dependencies on too many systems
3. **Navigation Violation**: Bypasses proper UI management architecture
4. **Hard-coded Values**: Should use configuration system
5. **Complex State**: Multiple overlapping state tracking systems

This is another MASSIVE system that needs immediate refactoring! The tutorial system is doing everything instead of orchestrating other systems! 🎯

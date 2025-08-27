# ProgressionManager.gd Audit Report

## File Overview
- **File Path**: scripts/systems/ProgressionManager.gd
- **Line Count**: 593 lines
- **Primary Purpose**: Player level progression and feature unlocking system (Summoners War style)
- **Architecture Type**: Monolithic manager with multiple responsibilities

## Signal Interface (2 signals)
### Outgoing Signals
1. `player_leveled_up(new_level: int, unlocked_features: Array)` - When player levels up
2. `feature_unlocked(feature_name: String, feature_data: Dictionary)` - When features unlock

## Method Inventory (30+ methods)
### Core Progression System
- `_ready()` - Initialize progression system
- `_load_progression_configuration()` - Load feature unlock levels configuration
- `_initialize_player_level()` - Initialize player level from experience
- `_unlock_initial_features(player_level: int)` - Unlock features for current level
- `_get_current_player_level()` - Get current calculated level
- `get_current_level()` - Public API for current level

### Experience System
- `add_player_experience(amount: int)` - Add XP and handle level ups
- `calculate_level_from_experience(total_xp: int)` - Calculate level from total XP
- `get_experience_needed_for_level(level: int)` - Calculate XP required for level
- `get_experience_to_next_level(current_level: int, current_xp: int)` - XP to next level
- `handle_player_level_up(old_level: int, new_level: int)` - Process level up

### Feature Unlocking System
- `unlock_feature(feature_name: String)` - Unlock and store feature
- `_show_feature_introduction(feature_name: String, feature_data: Dictionary)` - Show tutorials
- `get_feature_data(feature_name: String)` - Get feature configuration
- `handle_specific_feature_unlock(feature_name: String, feature_data: Dictionary)` - Specific unlock logic

### Feature Checking
- `is_feature_unlocked(feature_name: String)` - Check if feature is unlocked
- `get_required_level_for_feature(feature_name: String)` - Get required level for feature
- `get_unlocked_features_for_level(level: int)` - Get features for level

### Territory Progression
- `award_territory_completion_experience(territory_id: String)` - Territory completion XP
- `get_territory_tier_bonus(territory_id: String)` - Territory tier XP bonus
- `get_territory_unlock_level(territory_id: String)` - Territory unlock level
- `is_territory_unlocked_by_level(territory_id: String)` - Check territory unlock
- `get_unlocked_territories()` - Get all unlocked territories

### XP Award System
- `award_stage_completion_xp(stage_num: int)` - Stage completion XP
- `award_territory_completion_xp()` - Territory completion bonus XP
- `award_milestone_xp(milestone: String, amount: int)` - Milestone XP

### Tutorial Integration
- `should_show_tutorial_for_feature(feature_name: String)` - Check tutorial requirement
- `mark_tutorial_completed(feature_name: String)` - Mark tutorial complete
- `is_tutorial_completed(feature_name: String)` - Check tutorial completion

### Debug Functions
- `debug_unlock_all_features()` - Unlock all features for testing
- `debug_add_experience(amount: int)` - Add XP for testing
- `debug_set_level(level: int)` - Set player level for testing
- `get_debug_info()` - Get progression debug info

### Progression Queries
- `get_progression_summary()` - Complete progression summary for UI

## Key Dependencies
### External Dependencies
- **GameManager** - Core game state and player data access
- **PlayerData** - Player experience and resource storage
- **TutorialManager** - Feature introduction tutorials
- **God.gd** - Creating sacrificial gods for unlocks

### Internal State
- `feature_unlock_levels: Dictionary` - Level-to-features mapping
- `player_data: PlayerData` - Player data reference
- `game_manager: Node` - GameManager reference

## Duplicate Code Patterns Identified
### MAJOR OVERLAPS (HIGH PRIORITY):
1. **XP Calculation Pattern Overlap**:
   - Multiple XP calculation methods (`calculate_level_from_experience`, `get_experience_needed_for_level`)
   - **Similar XP scaling patterns** likely in God.gd level system
   - RECOMMENDATION: Create shared ExperienceCalculator utility

2. **Resource Management Overlap with PlayerData.gd**:
   - Direct player data resource manipulation (`player_data.resources["unlocked_features"]`)
   - **Same pattern** as ResourceManager and other managers
   - RECOMMENDATION: Centralize through PlayerData methods

3. **Tutorial Integration Overlap**:
   - Feature introduction logic (`_show_feature_introduction`)
   - Tutorial completion tracking
   - **Similar tutorial patterns** likely in TutorialManager
   - RECOMMENDATION: Consolidate tutorial management

### MEDIUM OVERLAPS:
4. **Configuration Loading Pattern**:
   - Hardcoded feature unlock configuration
   - **Similar configuration patterns** in other managers
   - RECOMMENDATION: Move to JSON configuration files

5. **Level-based Unlock Pattern**:
   - Territory unlock by level logic
   - **Similar unlock patterns** likely in other systems
   - RECOMMENDATION: Create shared UnlockManager utility

## Architectural Issues
### Single Responsibility Violations
- **CRITICAL**: This class handles 5 distinct responsibilities:
  1. Player experience/leveling system
  2. Feature unlock management
  3. Territory progression tracking
  4. Tutorial integration
  5. Debug functionality

### Massive Configuration Overhead
- **Large hardcoded configuration dictionaries** (feature_unlock_levels, tutorial_messages, feature_configs)
- **Mixed data and logic** in same class
- Should be externalized to configuration files

### Complex XP Calculation
- **Multiple overlapping XP methods** with different purposes
- **Complex level calculation logic**
- Should be simplified and consolidated

## Refactoring Recommendations
### IMMEDIATE (High Impact):
1. **Extract XP system**:
   - `ExperienceCalculator` utility for shared XP logic
   - `LevelCalculator` for level-based calculations
   - Share with God.gd and other XP systems

2. **Extract configuration to files**:
   - Move `feature_unlock_levels` to JSON configuration
   - Move tutorial messages to configuration files
   - **Reduce class size by 100+ lines**

3. **Separate feature management**:
   - `FeatureUnlockManager` for feature unlock logic
   - `TutorialIntegrator` for tutorial coordination
   - Keep ProgressionManager for coordination only

### MEDIUM (Maintenance):
4. **Consolidate resource operations**:
   - Use PlayerData methods instead of direct resource access
   - Consistent resource management patterns
   - Reduce coupling to PlayerData internals

5. **Extract territory progression**:
   - Move territory unlock logic to TerritoryManager
   - Reduce cross-system dependencies

## Connectivity Map
### Strongly Connected To:
- **GameManager**: Core dependency for game state
- **PlayerData**: Heavy dependency for experience and resource storage
- **TutorialManager**: Tutorial integration and coordination

### Moderately Connected To:
- **TerritoryManager**: Territory progression and unlocks
- **NotificationManager**: Progression notifications
- **All Manager Classes**: Feature unlock dependencies

### Signal Consumers (Likely):
- **NotificationManager**: Level up and feature unlock notifications
- **UI components**: Progression displays, feature introductions
- **TutorialManager**: Feature unlock tutorials

## Notes for Cross-Reference
- **XP calculation patterns**: Compare with God.gd for shared XP utilities
- **Resource management patterns**: Compare with PlayerData.gd and ResourceManager.gd
- **Tutorial patterns**: Compare with TutorialManager.gd for consolidation
- **Configuration patterns**: Look for similar hardcoded configs in other managers
- **Level/unlock patterns**: Check for similar progression systems in other classes

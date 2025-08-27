# DungeonSystem.gd Audit Report

## Overview
- **File**: `scripts/systems/DungeonSystem.gd`
- **Type**: Dungeon Management System
- **Lines of Code**: 779
- **Class Type**: Node (System manager)

## Purpose
Complete dungeon system managing daily rotations, difficulty progression, battle coordination, and reward distribution. Handles 4 dungeon categories with multiple difficulty tiers and unlock requirements.

## Dependencies
### Inbound Dependencies (What this relies on)
- **dungeons.json**: Dungeon definitions, schedules, difficulty requirements
- **GameManager**: Player data, save/load, system access
- **EnemyFactory**: Enemy creation for dungeon battles
- **BattleManager/BattleScreen**: Battle execution and completion
- **LootSystem**: Reward distribution
- **WaveSystem**: Multi-wave battle setup
- **ProgressionManager**: Player level calculations

### Outbound Dependencies (What depends on this)
- **DungeonScreen**: UI for dungeon selection and management
- **BattleScreen**: Receives dungeon battle setup
- **GameManager**: Integration into main game loop
- **UI notification systems**: Unlock notifications

## Signals (3 signals)
**Emitted**:
- `dungeon_completed(dungeon_id, difficulty, rewards)` - Dungeon successfully cleared
- `dungeon_failed(dungeon_id, difficulty)` - Dungeon attempt failed
- `dungeon_unlocked(dungeon_id)` - New dungeon became available

**Received**: 
- `_on_battle_completed(result)` - LEGACY battle completion (marked for removal)

## Instance Variables (7 variables)
- `dungeon_data: Dictionary` - Cached dungeon configurations from JSON
- `player_dungeon_progress: Dictionary` - Player's progress tracking
- `battle_in_progress: bool` - Battle state flag
- `current_battle_scene_path: String` - Scene path for battles
- `_stored_battle_data: Dictionary` - Battle data during scene transitions
- `current_dungeon_id: String` - Currently active dungeon
- `current_dungeon_difficulty: String` - Currently active difficulty

## Method Inventory

### Core System Methods (3 methods)
- `_ready()` - Initialize system and load data
- `load_dungeon_data()` - Load dungeon configurations from JSON
- `initialize_player_progress()` - Initialize player progress tracking

### Dungeon Access & Availability (6 methods)
- `get_available_dungeons_today()` - Get dungeons available based on daily schedule
- `get_dungeon_info(dungeon_id)` - Get complete dungeon configuration
- `is_dungeon_unlocked(dungeon_id)` - Check if player meets unlock requirements
- `get_all_dungeons()` - Get list of all dungeon IDs
- `get_unlocked_dungeons()` - Get list of unlocked dungeons for player
- `get_dungeon_schedule_info()` - Get daily rotation schedule information

### Difficulty Management (6 methods)
- `is_difficulty_unlocked(dungeon_id, difficulty)` - Check difficulty unlock status
- `get_previous_difficulty(difficulty)` - Get prerequisite difficulty tier
- `extract_clear_count_from_requirement(requirement)` - Parse clear count from requirement strings
- `check_difficulty_unlocks(dungeon_id)` - Check and unlock new difficulties after completion
- `_check_difficulty_unlock_fresh(dungeon_id, difficulty)` - Fresh unlock check bypassing cache
- `get_difficulty_unlock_requirements(dungeon_id, difficulty)` - Get unlock requirement details
- `get_unlocked_difficulties_for_dungeon(dungeon_id)` - Get all unlocked difficulties for dungeon

### Battle Management (8 methods)
- `attempt_dungeon(dungeon_id, difficulty, team)` - Main dungeon entry point
- `validate_dungeon_attempt(dungeon_id, difficulty, team)` - Validate attempt without starting
- `start_dungeon_battle(dungeon_id, difficulty, team)` - Start real battle with BattleManager
- `reset_battle_state()` - Reset battle state on cancellation
- `simulate_dungeon_battle(dungeon_info, difficulty_info, team)` - Fallback simulation
- `calculate_team_power(team)` - Calculate total team power rating
- `_open_battle_screen_for_dungeon(dungeon_id, difficulty, team)` - Scene transition management
- `_on_battle_completed(result)` - LEGACY battle completion handler

### Reward & Progress (4 methods)
- `award_dungeon_rewards(dungeon_id, difficulty)` - Award completion rewards
- `get_loot_table_name(dungeon_id, difficulty)` - Generate loot table names
- `update_dungeon_progress(dungeon_id, difficulty)` - Update player clear counts
- `get_total_clear_counts(dungeon_id)` - Get clear count data for display

### Debug & Management (4 methods)
- `debug_complete_sanctum()` - Debug function for manual completion
- `complete_dungeon_manually(dungeon_id, difficulty)` - Manual completion for fixes
- `get_dungeon_progress_info(dungeon_id)` - Get progress info for debugging
- `get_player_dungeon_stats()` - Get comprehensive player statistics

### Save/Load (2 methods)
- `save_dungeon_progress()` - Export progress data for saving
- `load_dungeon_progress(saved_data)` - Import progress data from save

## Key Data Structures

### Player Progress Tracking
```gdscript
player_dungeon_progress = {
    "unlocked_dungeons": [],
    "difficulty_unlocks": {},
    "clear_counts": {},        # "dungeon_id_difficulty": count
    "best_times": {},
    "total_clears": 0
}
```

### Dungeon Categories (4 types)
- **Elemental Dungeons**: fire_sanctum, water_sanctum, earth_sanctum, lightning_sanctum, light_sanctum, dark_sanctum
- **Special Dungeons**: magic_sanctum, awakening_dungeon, experience_dungeon
- **Pantheon Dungeons**: greek_trials, egyptian_trials, norse_trials, etc.
- **Equipment Dungeons**: weapon_forge, armor_chamber, accessory_vault

### Difficulty Progression (6 tiers)
- **beginner** → **intermediate** → **advanced** → **expert** → **master** → **heroic** → **legendary**

### Daily Schedule System
- **Always Available**: magic_sanctum, awakening_dungeon, experience_dungeon
- **Daily Rotation**: Different elemental/pantheon dungeons available each day

## Notable Patterns
- **Daily Rotation System**: Time-based dungeon availability
- **Progressive Unlocking**: Difficulty tiers unlock based on clear counts
- **Multi-Category Organization**: 4 distinct dungeon types with different mechanics
- **Battle Integration**: Seamless integration with battle system
- **Fallback Simulation**: Graceful degradation when battle system unavailable

## Code Quality Issues

### Anti-Patterns Found
1. **Massive Responsibility**: 779 lines handling schedule, progression, battles, rewards
2. **Scene Management Complexity**: Complex scene transition logic
3. **Legacy Architecture**: Old battle completion handler still present
4. **Hardcoded Logic**: Magic numbers and hardcoded values throughout
5. **Deep Nesting**: Complex nested checks for unlocks and validation

### Positive Patterns
1. **Comprehensive Validation**: Thorough checks before allowing dungeon attempts
2. **Progress Tracking**: Detailed tracking of player progression
3. **Fallback Mechanisms**: Simulation when battle system unavailable
4. **Debug Tools**: Built-in debugging and manual completion tools
5. **Save Integration**: Proper save/load functionality

## Architectural Notes

### Strengths
- **Complete Feature Set**: Handles all aspects of dungeon system
- **Daily Variety**: Rotation system keeps content fresh
- **Progressive Difficulty**: Well-designed unlock progression
- **Battle Integration**: Good coordination with battle systems

### Concerns
- **Monolithic Design**: Single class handling too many responsibilities
- **Scene Coupling**: Direct scene management creates tight coupling
- **State Management**: Complex battle state tracking
- **Legacy Code**: Outdated patterns mixed with new architecture

## Duplicate Code Potential
- **Validation Patterns**: Similar validation logic across multiple methods
- **Progress Tracking**: Repeated clear count checking patterns
- **JSON Access**: Similar data access patterns across different dungeon types
- **Error Handling**: Repeated error message and fallback patterns

## Critical Integration Points

### **HUGE ARCHITECTURAL OVERLAP** 🚨
- **BattleManager Integration**: Directly manages battle system startup
- **Scene Management**: Controls scene transitions to BattleScreen
- **GameManager Dependency**: Heavy integration with main game manager
- **Save System**: Directly triggers save operations

### **POTENTIAL DUPLICATES** with other systems:
- **Progress Tracking**: May overlap with ProgressionManager
- **Reward Distribution**: May overlap with LootSystem
- **Battle Coordination**: May overlap with BattleManager
- **Schedule Management**: Could be extracted to separate system

## Refactoring Recommendations
1. **Split Responsibilities**:
   - DungeonManager (core logic)
   - DungeonScheduler (daily rotation)
   - DungeonProgressTracker (progress tracking)
   - DungeonBattleCoordinator (battle integration)

2. **Remove Scene Management**: Let UI handle scene transitions
3. **Standardize Validation**: Create common validation framework
4. **Extract Schedule System**: Separate daily rotation logic
5. **Remove Legacy Code**: Clean up old battle completion handlers

## Connection Map - WHO TALKS TO WHOM

### **INBOUND CONNECTIONS** (Who calls DungeonSystem):
- **DungeonScreen**: validate_dungeon_attempt(), attempt_dungeon(), get_available_dungeons_today()
- **GameManager**: Load/save dungeon progress during game initialization
- **BattleScreen**: May receive completion notifications

### **OUTBOUND CONNECTIONS** (Who DungeonSystem calls):
- **EnemyFactory**: create_enemies_for_dungeon() for battle setup
- **GameManager.get_loot_system()**: award_loot() for rewards
- **GameManager.get_wave_system()**: setup_waves_for_dungeon()
- **GameManager.player_data**: Energy checks, save operations
- **Scene Tree**: change_scene_to_packed() for battle transitions

### **SIGNAL CONNECTIONS**:
- **Emits TO**: UI systems for completion/failure notifications
- **Receives FROM**: BattleManager (legacy) for battle completion

## Unlock Requirements Handled
- **Player Level**: Minimum level requirements
- **Legendary Gods**: Required legendary god ownership
- **Territory Completion**: Required territory conquests
- **Difficulty Progression**: Previous difficulty clear counts

## Energy Cost Management
- **Validation**: Checks energy before battle start
- **Consumption**: Spends energy when battle actually starts
- **Immediate Save**: Saves game after energy spent to prevent exploits

This is a COMPLEX system that's doing A LOT! Perfect candidate for breaking apart! 🎯

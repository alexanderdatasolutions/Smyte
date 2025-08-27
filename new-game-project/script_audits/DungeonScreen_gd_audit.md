# DungeonScreen.gd Audit Report

## Overview
- **File**: `scripts/ui/DungeonScreen.gd`
- **Type**: Dungeon Selection & Management Interface
- **Lines of Code**: 668
- **Class Type**: Control (UI Screen)

## Purpose
Complete dungeon interface with categorized dungeon lists, detailed dungeon information, difficulty selection, reward previews, and battle setup coordination. Manages the entire dungeon experience flow from selection to battle initiation.

## Dependencies
### Inbound Dependencies (What this relies on)
- **DungeonSystem**: Core dungeon logic, availability, rewards, validation
- **GameManager**: System access, player data, battle context management
- **LootSystem**: Reward preview generation and loot table data
- **BattleSetupScreen**: Team selection for dungeon battles
- **ResourceManager**: Dynamic resource name retrieval

### Outbound Dependencies (What depends on this)
- **UIManager**: Screen navigation and transitions
- **BattleScreen**: Receives battle context for dungeon execution
- **Main game navigation**: Dungeon access from world view

## Signals (1 signal)
**Emitted**:
- `back_pressed` - Navigate back to previous screen

**Received**:
- `dungeon_system.dungeon_completed` - Handle successful dungeon completion
- `dungeon_system.dungeon_failed` - Handle dungeon failure
- `BattleSetupScreen.battle_setup_complete` - Receive team selection
- `BattleSetupScreen.setup_cancelled` - Handle setup cancellation

## Instance Variables (4 variables)
- `dungeon_system: Node` - Cached DungeonSystem reference
- `loot_system: Node` - Optional LootSystem reference for enhanced displays
- `selected_dungeon_id: String` - Currently selected dungeon
- `selected_difficulty: String` - Currently selected difficulty

## Method Inventory

### Core Initialization & Cleanup (3 methods)
- `_ready()` - Initialize UI, remove duplicate instances, connect signals
- `_enter_tree()` - Ensure GameManager dungeon system connection
- `_check_for_dungeon_refresh()` - Auto-select last completed dungeon

### Dungeon List Management (5 methods)
- `refresh_dungeon_list()` - Load and categorize available dungeons
- `determine_dungeon_category(dungeon_info)` - Categorize dungeons by type
- `clear_dungeon_lists()` - Clear all category containers
- `create_dungeon_button(dungeon_info, container)` - Create individual dungeon buttons
- `update_schedule_info()` - Display daily dungeon rotation information

### Dungeon Selection & Display (2 methods)
- `_on_dungeon_selected(dungeon_id)` - Handle dungeon selection
- `show_dungeon_info(dungeon_id)` - Display detailed dungeon information

### Difficulty Management (3 methods)
- `update_difficulty_buttons(dungeon_id, dungeon_info)` - Create difficulty buttons with unlock status
- `_on_difficulty_selected(difficulty, pressed)` - Handle difficulty toggle (unused)
- `_on_difficulty_button_pressed(difficulty)` - Main difficulty selection handler

### Reward & Preview System (6 methods)
- `update_rewards_display(dungeon_id, difficulty)` - Comprehensive reward and enemy preview
- `_convert_dungeon_id_to_loot_table_name(dungeon_id, difficulty)` - Map dungeon to loot table
- `_get_readable_item_name(item)` - Convert items to human-readable names
- `_get_amount_text(item)` - Format item amounts
- `_format_number(number)` - Format large numbers with K/M suffixes

### Battle Flow Management (5 methods)
- `_on_enter_button_pressed()` - Validate and initiate battle setup
- `open_battle_setup_screen()` - Launch BattleSetupScreen for team selection
- `_on_battle_setup_complete(context)` - Process team selection and start battle
- `_on_battle_setup_cancelled()` - Handle setup cancellation
- `_switch_to_battle_screen_with_context(context)` - Transition to actual battle

### Result Handling (2 methods)
- `_on_dungeon_completed(_dungeon_id, _difficulty, rewards)` - Handle completion rewards
- `_on_dungeon_failed(_dungeon_id, _difficulty)` - Handle failure

### UI Feedback (3 methods)
- `show_error_message(message)` - Display error notifications
- `show_success_message(message)` - Display success notifications
- `_on_back_button_pressed()` - Handle navigation back

## Key Data Structures

### Dungeon Categories (3 types)
- **Elemental**: Fire, water, earth, lightning, light, dark, magic sanctums
- **Pantheon**: Greek, Norse, Egyptian, Hindu, Celtic, Aztec, Japanese, Slavic trials
- **Equipment**: Titans forge, Valhalla armory, Oracle sanctum, Elysian fields, Styx crossing

### Category Color Coding
- **Elemental**: Element-specific colors (fire=orange, water=cyan, etc.)
- **Pantheon**: Gold coloring
- **Equipment**: Silver coloring

### Difficulty Button Features
- **Unlock Status**: Shows locked (🔒) vs unlocked difficulties
- **Progress Display**: Shows clear counts for completed difficulties
- **Requirement Text**: Shows unlock requirements for locked difficulties
- **Button Groups**: Radio button behavior for single selection

### Reward Display Sections
- **Dungeon Stats**: Power requirement, energy cost, waves, boss
- **Guaranteed Rewards**: Items with 100% drop chance
- **Rare Drops**: Items with percentage chances
- **Enemy Information**: Element, guardian spirit, boss details

## Notable Patterns
- **Duplicate Instance Prevention**: Removes old DungeonScreen instances on startup
- **Comprehensive Preview**: Rich reward and enemy information
- **Modular Loot Integration**: Uses LootSystem for actual reward data
- **Battle Context Management**: Stores context in GameManager for scene transitions
- **Auto-Selection**: Remembers last completed dungeon for user convenience

## Code Quality Issues

### Anti-Patterns Found
1. **Massive Responsibility**: 668 lines handling selection, display, preview, battle coordination
2. **Hardcoded Category Logic**: String-based dungeon categorization
3. **Complex Loot Mapping**: Intricate dungeon-to-loot-table conversion logic
4. **Scene Management**: Direct scene transitions and cleanup
5. **Magic Numbers**: Hardcoded UI dimensions and timer values

### Positive Patterns
1. **Rich Information Display**: Comprehensive dungeon and reward previews
2. **Proper Validation**: Energy checks and team validation before battles
3. **Signal Integration**: Good use of signals for battle flow
4. **Resource Integration**: Uses ResourceManager for dynamic names
5. **Fallback Handling**: Graceful degradation when systems unavailable

## Architectural Notes

### Strengths
- **Complete Feature Set**: Handles entire dungeon experience flow
- **Rich Previews**: Detailed reward and enemy information
- **Proper Integration**: Good coordination with DungeonSystem and LootSystem
- **User Experience**: Intuitive categorization and visual feedback

### Concerns
- **Monolithic Design**: Single class handling too many aspects
- **Scene Coupling**: Direct scene management and transitions
- **Complex Mappings**: Intricate loot table name conversion
- **Duplicate Prevention**: Manual instance cleanup indicates architecture issues

## Duplicate Code Potential
- **Button Creation**: Similar button creation patterns across categories
- **Color Mapping**: Similar color logic to other UI screens
- **Error/Success Messages**: Similar notification patterns
- **Scene Transitions**: Similar battle setup coordination

## Critical Integration Points

### **MAJOR SYSTEM INTEGRATION** 🎯
- **DungeonSystem Dependency**: Complete reliance on dungeon system for all data
- **BattleSetupScreen Coordination**: Complex battle setup flow
- **LootSystem Integration**: Reward preview generation
- **Scene Management**: Manual scene transitions and context passing

### **POTENTIAL DUPLICATES** with other systems:
- **Battle Coordination**: Similar to other battle-initiating screens
- **Reward Display**: Similar to other reward preview systems
- **Category Management**: Similar categorization logic elsewhere
- **Validation Logic**: Similar checks to other battle screens

## Refactoring Recommendations
1. **Split Responsibilities**:
   - DungeonBrowser (dungeon list and selection)
   - DungeonDetailsPanel (info and rewards display)
   - DungeonBattleCoordinator (battle setup flow)
   - CategoryManager (dungeon categorization)

2. **Extract Components**:
   - RewardPreviewWidget (reusable reward display)
   - DifficultySelector (reusable difficulty selection)
   - CategoryTabs (reusable category system)

3. **Centralize Logic**: Move loot table mapping to LootSystem
4. **Simplify Scene Management**: Use proper scene manager patterns
5. **Remove Hardcoded Logic**: Create configuration-based categorization

## Connection Map - WHO TALKS TO WHOM

### **INBOUND CONNECTIONS** (Who calls DungeonScreen):
- **UIManager**: Screen navigation and transitions
- **WorldView/MainUI**: Dungeon access buttons
- **BattleScreen**: Returns to dungeon after battle completion

### **OUTBOUND CONNECTIONS** (Who DungeonScreen calls):
- **DungeonSystem**: get_available_dungeons_today(), get_dungeon_info(), validate_dungeon_attempt()
- **GameManager.get_loot_system()**: get_loot_table_rewards_preview()
- **GameManager.player_data**: Energy checks and spending
- **BattleSetupScreen**: Team selection coordination
- **Scene tree**: change_scene_to_file() for battle transitions

### **SIGNAL CONNECTIONS**:
- **Emits TO**: UIManager (back_pressed)
- **Receives FROM**: DungeonSystem (dungeon_completed, dungeon_failed), BattleSetupScreen (battle_setup_complete, setup_cancelled)

## Battle Flow Sequence
1. **Selection**: User selects dungeon and difficulty
2. **Validation**: Check unlock status and requirements
3. **Preview**: Display rewards, enemies, and stats
4. **Team Setup**: Launch BattleSetupScreen for team selection
5. **Energy Check**: Validate energy and spend before battle
6. **Battle Start**: Transition to BattleScreen with complete context
7. **Result Handling**: Process completion/failure and return

## Loot Table Mapping Logic
- **Sanctums**: Convert "_sanctum" to "_dungeon"
- **Magic Sanctum**: Maps to "magic_dungeon" (no difficulty)
- **Equipment Dungeons**: All map to "equipment_dungeon"
- **Pantheon Trials**: Complex difficulty mapping (beginner-master→heroic, legendary→legendary)

This is a **FEATURE-RICH** but **COMPLEX** dungeon interface! The functionality is comprehensive, but the architecture would benefit from splitting into smaller, focused components. 🎯

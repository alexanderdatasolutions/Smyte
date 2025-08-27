# BattleManager.gd Audit Report

## File Info
- **Path**: `scripts/systems/BattleManager.gd`
- **Type**: Battle System Controller (extends Node)
- **Purpose**: Core battle orchestration and turn management
- **Lines**: 1043 lines - **ANOTHER MASSIVE CLASS**

## Incoming Dependencies
- BattleFactory.gd - Battle configuration
- EnemyFactory.gd - Enemy creation
- TurnSystem.gd - Turn order management
- StatusEffectManager.gd - Status effect processing
- BattleAI.gd - Enemy AI decisions
- God.gd - Player units
- Territory.gd - Territory battles
- GameManager.gd - Statistics and coordination

## Outgoing Signals
- `battle_completed(result)` - Battle finished
- `battle_log_updated(message)` - Battle log messages
- `status_effect_applied(target, effect)` - Status effect applied
- `status_effect_removed(target, effect_id)` - Status effect removed

## Class Properties
### Battle State
- `battle_active: bool` - Current battle status
- `auto_battle_enabled: bool` - Auto-battle mode
- `current_battle_gods: Array` - Player team
- `current_battle_enemies: Array` - Enemy team
- `selected_gods: Array` - **ALIAS** for current_battle_gods

### Auto-Battle System
- `auto_battle_timer: Timer` - Auto-action timing
- `auto_battle_speed: float` - Speed multiplier
- `pending_auto_action: Dictionary` - Queued action
- `pending_auto_unit` - Unit with pending action
- `pending_god_action: Dictionary` - **DUPLICATE** pending action
- `waiting_for_auto_action: bool` - Auto-battle state

### Battle Context
- `current_battle_territory: Territory` - Territory being fought
- `current_battle_stage: int` - Current stage number
- `current_battle_context: Dictionary` - Battle metadata
- `last_awarded_loot: Dictionary` - Loot tracking

### Sub-Systems
- `turn_system: TurnSystem` - Turn order management
- `status_effect_manager: StatusEffectManager` - Status effects
- `battle_screen` - UI reference

## Methods (Public) - 30+ methods!
### Static Utilities
- `_get_stat(unit, stat_name, default)` - **STATIC** Safe stat getter
- `_set_hp(unit, new_hp)` - **STATIC** Safe HP setter

### Battle Lifecycle
- `_ready()` - System initialization
- `start_battle(config)` - **MAIN** Universal battle starter
- `start_dungeon_battle_with_loot_context(gods, loot_table, context, enemies)` - Dungeon battle
- `reset_battle()` - Reset battle state
- `start_wave_battle(enemies)` - Wave battle system

### Legacy Battle Methods (Redundancy!)
- `start_territory_assault(gods, territory, stage)` - **LEGACY** redirect
- `start_dungeon_battle(gods, dungeon_id, difficulty, enemies)` - **LEGACY** redirect
- `_start_wave_battle_delayed()` - **DEPRECATED** wave starter

### Auto-Battle System
- `toggle_auto_battle()` - Toggle auto mode
- `set_auto_battle_speed(speed)` - Set speed multiplier
- `get_auto_battle_speed()` - Get current speed

### Action Processing
- `process_god_action(god, action)` - Process player action
- `process_enemy_action(enemy)` - Process AI action

### Private Battle Flow (10+ private methods!)
- `_start_next_turn()` - **MASSIVE** turn management
- `_handle_god_turn(god)` - Player turn handling
- `_handle_enemy_turn(enemy)` - Enemy turn handling
- `_end_unit_turn(unit)` - End turn processing
- `_process_attack_action(attacker, target)` - Attack resolution
- `_determine_ability_type(ability)` - Ability classification
- Plus many more private methods...

## Data Structures Used
### Enums
- `BattleResult` - Victory/Defeat

### Dictionaries
- Battle context with type/territory/stage info
- Action dictionaries with action/target/ability
- Loot tracking data

## Potential Issues & Duplicate Code
### Duplicate Properties
1. **Auto-Battle Tracking**:
   - `pending_auto_action` vs `pending_god_action` - Same purpose
   - Multiple state flags for auto-battle

### Duplicate Methods
1. **Wave Battle Starters**:
   - `start_wave_battle()` vs `_start_wave_battle_delayed()` - Similar functionality
2. **Legacy Redirects**:
   - Multiple legacy methods that just redirect to `start_battle()`

### Code Smells
1. **Massive Class**: 1043 lines handling multiple concerns
2. **Complex State**: Multiple overlapping state properties
3. **Static Utilities**: Static methods in instance class
4. **Legacy Support**: Old and new systems running in parallel
5. **Deep Nesting**: Complex control flow with multiple async points

### Critical Issues
1. **Turn Management Complexity**: `_start_next_turn()` is too complex
2. **State Synchronization**: Multiple timers and state flags
3. **Error Handling**: Minimal error handling for battle failures
4. **Memory Management**: No cleanup of battle state
5. **UI Coupling**: Direct coupling to battle_screen

## Recommendations
### Split the Class
1. **BattleManager** (coordination only)
2. **TurnManager** (turn flow)
3. **ActionProcessor** (action resolution)
4. **AutoBattleController** (auto-battle logic)
5. **BattleStateManager** (state tracking)

### Remove Duplicates
1. Consolidate auto-battle state properties
2. Remove deprecated wave battle methods
3. Eliminate legacy redirect methods

### Improve Architecture
1. Use command pattern for actions
2. Implement proper state machine for battle flow
3. Add event system for battle events
4. Separate UI concerns from battle logic

## Connected Systems
- GameManager.gd - Battle coordination and statistics
- TurnSystem.gd - Turn order management
- StatusEffectManager.gd - Status effect processing
- BattleAI.gd - Enemy decision making
- BattleFactory.gd - Battle configuration
- EnemyFactory.gd - Enemy creation
- UI/BattleScreen.gd - Battle display
- Territory.gd - Territory battle context
- God.gd - Player unit management

**Another critical file that needs major refactoring due to size and complexity.**

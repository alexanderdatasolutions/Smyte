# Dungeon & Wave System - Complete Specification

## Overview
This document specifies the complete dungeon and wave battle system for the game. Ralph will use this to create comprehensive documentation, unit tests, and verify each feature works correctly.

## Current Issue to Fix
**BUG**: Gods disappearing after battle defeat
- User reports: "if i lose combat those gods are no longer in my collection"
- Investigation shows no code that removes gods on defeat
- Debug logging added to CollectionManager.remove_god() to track deletions
- Need to verify this is not actually happening or find root cause

## System Components

### 1. DungeonCoordinator (`scripts/systems/dungeon/DungeonCoordinator.gd`)
**Purpose**: Orchestrates dungeon selection, difficulty, and battle initiation

**Key Methods**:
- `get_dungeon(dungeon_id: String) -> Dungeon` - Get dungeon data
- `get_available_dungeons() -> Array` - Get all unlocked dungeons
- `start_dungeon(dungeon_id: String, difficulty: String, team: Array)` - Start dungeon battle
- `_handle_dungeon_victory(result: BattleResult)` - Process victory rewards
- `_handle_dungeon_defeat(result: BattleResult)` - Process defeat (NO god removal)

**Expected Behavior**:
- ✅ Dungeons load from `data/dungeons.json`
- ✅ Victory grants rewards (mana, equipment, materials)
- ✅ Defeat does NOT remove gods from collection
- ✅ Battle history tracked for statistics

### 2. WaveManager (`scripts/systems/battle/WaveManager.gd`)
**Purpose**: Manages multi-wave enemy spawning in PvE battles

**Key Methods**:
- `setup_waves(waves: Array)` - Initialize wave data
- `start_wave(wave_number: int)` - Spawn enemies for a wave
- `check_wave_complete() -> bool` - Check if all enemies defeated
- `advance_to_next_wave()` - Progress to next wave
- `get_current_wave() -> int` - Get active wave number

**Expected Behavior**:
- ✅ Waves spawn sequentially when previous wave defeated
- ✅ Wave completion checked after each enemy death
- ✅ Final wave victory triggers battle end
- ✅ Wave data format: `[[enemy1, enemy2], [enemy3, enemy4, enemy5]]`

### 3. BattleCoordinator (`scripts/systems/battle/BattleCoordinator.gd`)
**Purpose**: Main battle orchestration system

**Key Methods**:
- `start_battle(config: BattleConfig)` - Initialize battle
- `execute_action(action: BattleAction) -> bool` - Execute player/AI action
- `_check_battle_end_conditions() -> bool` - Check win/loss
- `_handle_battle_victory()` - Process victory
- `_handle_battle_defeat()` - Process defeat

**Expected Behavior**:
- ✅ Battle uses gods from player's collection (by reference)
- ✅ BattleUnit stores reference to source god, doesn't modify it
- ✅ Victory/defeat triggers appropriate callbacks
- ✅ NO god removal on defeat

### 4. BattleState (`scripts/data/BattleState.gd`)
**Purpose**: Maintains current battle state

**Key Methods**:
- `setup_from_config(config: BattleConfig)` - Initialize from config
- `advance_to_next_wave(next_wave_enemies: Array) -> bool` - Load next wave
- `get_living_player_units() -> Array` - Get alive player units
- `get_living_enemy_units() -> Array` - Get alive enemy units

**Expected Behavior**:
- ✅ Creates BattleUnits from God references
- ✅ Tracks unit HP/status without modifying source gods
- ✅ Wave progression updates enemy units only

### 5. CollectionManager (`scripts/systems/collection/CollectionManager.gd`)
**Purpose**: Manages player's god collection

**Key Methods**:
- `add_god(god: God) -> bool` - Add god to collection
- `remove_god(god: God) -> bool` - Remove god (ONLY for sacrifice)
- `get_god_by_id(god_id: String) -> God` - Lookup god
- `get_all_gods() -> Array` - Get full collection

**Expected Behavior**:
- ✅ `remove_god()` ONLY called from SacrificeSystem
- ✅ Battle system NEVER removes gods
- ✅ Debug logging tracks all removals with stack trace

## Data Formats

### Dungeon JSON Format (`data/dungeons.json`)
```json
{
  "dungeons": [
    {
      "id": "olympian_trials",
      "name": "Olympian Trials",
      "category": "pantheon",
      "description": "Face the champions of Olympus",
      "unlock_level": 1,
      "difficulties": {
        "heroic": {
          "energy_cost": 15,
          "recommended_power": 3600,
          "waves": [
            [
              {"name": "Greek Warrior", "level": 5, "hp": 800, "attack": 150, "defense": 80, "speed": 90}
            ]
          ],
          "rewards": {
            "mana": 500,
            "equipment_chance": 0.3
          }
        }
      }
    }
  ]
}
```

### BattleConfig Structure
```gdscript
var battle_config = BattleConfig.new()
battle_config.battle_type = BattleConfig.BattleType.DUNGEON
battle_config.attacker_team = [god1, god2, god3]  # Array of God references
battle_config.dungeon_name = "Olympian Trials"
battle_config.enemy_waves = [
  [{"name": "Enemy1", "level": 5, ...}],
  [{"name": "Enemy2", "level": 6, ...}, {"name": "Enemy3", "level": 6, ...}]
]
```

## Test Requirements

Ralph should create unit tests for:

### DungeonCoordinator Tests
1. ✅ Load dungeons from JSON successfully
2. ✅ Filter available dungeons by unlock level
3. ✅ Start dungeon creates correct BattleConfig
4. ✅ Victory applies rewards correctly
5. ✅ Defeat does NOT remove gods from collection
6. ✅ Energy cost properly deducted

### WaveManager Tests
1. ✅ Setup waves correctly from config
2. ✅ Start wave spawns correct enemies
3. ✅ Wave completion detection works
4. ✅ Advance to next wave loads new enemies
5. ✅ Final wave victory detected
6. ✅ Wave progression emits signals

### BattleState Tests
1. ✅ Create BattleUnits from gods without modifying gods
2. ✅ Track battle state correctly
3. ✅ Wave advancement clears old enemies, keeps players
4. ✅ Living unit filters work correctly
5. ✅ God references remain valid throughout battle

### CollectionManager Tests
1. ✅ Add god to collection
2. ✅ Remove god only via explicit call
3. ✅ Get god by ID works
4. ✅ Verify remove_god NOT called during battles
5. ✅ Debug logging captures removal stack traces

### Integration Tests
1. ✅ Full dungeon battle flow (start → waves → victory)
2. ✅ Full dungeon battle flow (start → waves → defeat)
3. ✅ Verify gods remain in collection after defeat
4. ✅ Verify gods remain in collection after victory
5. ✅ Multi-wave battle progression
6. ✅ Rewards granted on victory

## Bug Investigation Checklist

For the "gods disappearing on defeat" bug:

1. ✅ Add debug logging to CollectionManager.remove_god() - DONE
2. ⏳ Test battle defeat scenario with logging active
3. ⏳ Check if gods actually removed or just hidden in UI
4. ⏳ Verify gods not permanently assigned to hex nodes
5. ⏳ Check save/load doesn't corrupt collection
6. ⏳ Verify CollectionScreen filters not hiding gods

## Success Criteria

All features working correctly when:
1. Can start dungeons from DungeonScreen
2. Wave battles progress correctly
3. Victory grants rewards
4. Defeat does NOT remove gods
5. All unit tests pass
6. Integration tests pass
7. Bug investigation completed with findings

## Next Steps for Ralph

1. **Review existing code** in the listed files
2. **Create unit tests** for each component
3. **Run tests** and document results
4. **Test the bug scenario** with debug logging
5. **Document findings** about god deletion issue
6. **Fix any issues** found during testing
7. **Create final test report** with all results

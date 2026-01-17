# Comprehensive Unit Test Map

## Priority 1 - Core Systems (Must Test First)

### ResourceManager
- `add_resource(resource_id, amount)` - Add resources
- `spend(resource_id, amount)` - Spend single resource
- `spend_resources(cost)` - Spend multiple resources
- `can_afford(cost)` - Check affordability
- `get_resource(resource_id)` - Query resource amount
- **Test**: Resource limits (energy=100, arena_tokens=30)
- **Test**: Signal emission on resource_changed

### CombatCalculator (Static)
- `calculate_damage(attacker, target, skill)` - Core damage formula
- **Formula**: `ATK × Multiplier × (1000 / (1140 + 3.5 × DEF))`
- **Test**: Critical hit (crit_rate based, damage × (1 + crit_damage%))
- **Test**: Glancing hit (15% chance, 70% damage)
- **Test**: Element advantage (1.3x weak, 0.85x resistant, 1.0x neutral)
- **Test**: Variance (±10%)

### CollectionManager
- `add_god(god)` - Add god to collection
- `has_god(god_id)` - Check ownership
- `remove_god(god)` - Remove god
- `get_all_gods()` - Get all owned gods
- **Test**: Duplicate handling
- **Test**: Event emission

### SummonManager
- `summon_basic()` - Basic mana summon
- `summon_premium()` - Premium crystal summon
- `summon_free_daily()` - Free daily summon
- **Rates**: Basic (70/25/4.5/0.5), Premium (50/35/12/3)
- **Pity**: Hard pity at 100 legendary, 50 epic
- **Test**: Rate distribution (statistical)
- **Test**: Pity counter mechanics

### BattleCoordinator
- `start_battle(config)` - Begin battle
- `execute_action(action)` - Process action
- `end_battle(result)` - Conclude battle
- **Test**: Battle flow
- **Test**: Wave progression
- **Test**: Victory/defeat conditions

### EquipmentManager
- `equip_equipment_to_god(god, equipment, slot)` - Equip
- `unequip_equipment_from_god(god, slot)` - Unequip
- `get_equipped_equipment(god)` - Get equipped
- **Test**: 6-slot system
- **Test**: Type-slot matching

## Priority 2 - Important Systems

### EquipmentEnhancementManager
- `enhance_equipment(equipment, use_blessed_oil)` - Enhance
- **Levels**: 0-15 (varies by rarity)
- **Success rates**: Decrease per level
- **Test**: Cost calculation
- **Test**: Success/fail rates
- **Test**: Stat bonus (+5% per level)

### TerritoryManager
- `capture_territory(territory_id)` - Claim
- `upgrade_territory(territory_id)` - Upgrade
- **Test**: Capture limit (3 + (level-1)/5)
- **Test**: Upgrade costs

### PlayerProgressionManager
- `add_experience(amount)` - Award XP
- `is_feature_unlocked(feature)` - Check unlock
- **Unlocks**: Summon@2, Sacrifice@3, Territory@5, Dungeon@10, Arena@15
- **Test**: XP curve (base 100, scale 1.15x)

### GodProgressionManager
- `add_experience_to_god(god, amount)` - Award god XP
- `awaken_god(god, materials)` - Awaken
- **Max levels**: 40 normal, 50 awakened
- **Test**: Stat bonuses per level by tier

### StatusEffectManager
- `apply_status_effect(target, effect)` - Apply
- `process_turn_start_effects(unit)` - Process
- **Types**: Poison, Burn, HoT, Shield, Stun
- **Test**: Effect application
- **Test**: Duration/expiration

## Priority 3 - Supporting Systems

### TurnManager
- `setup_turn_order(units)` - Initialize
- `advance_turn()` - Progress
- **Test**: Speed-based turn order
- **Test**: Turn bar (0-100)

### WaveManager
- `setup_waves(waves)` - Configure
- `complete_wave()` - Finish wave
- **Test**: Wave progression
- **Test**: All waves completion

### SaveManager
- `save_game()` - Persist state
- `load_game()` - Restore state
- **Test**: Save/load cycle consistency

## Data Models to Test

### God
- Equipment slot access (6 slots)
- Stat calculations with level
- Element/tier validation

### Equipment
- Enhancement mechanics
- Socket management
- Stat bonus calculation
- Set bonus detection

### BattleUnit
- Creation from God
- HP management
- Cooldown tracking
- Turn bar mechanics

### BattleState
- Setup from config
- Unit filtering
- End condition detection
- Statistics tracking

## Test File Locations

Tests should be created in: `new-game-project/tests/`

Structure:
```
tests/
├── unit/
│   ├── test_resource_manager.gd
│   ├── test_combat_calculator.gd
│   ├── test_collection_manager.gd
│   ├── test_summon_manager.gd
│   ├── test_battle_coordinator.gd
│   ├── test_equipment_manager.gd
│   ├── test_equipment_enhancement.gd
│   ├── test_territory_manager.gd
│   ├── test_player_progression.gd
│   ├── test_god_progression.gd
│   ├── test_status_effects.gd
│   ├── test_turn_manager.gd
│   ├── test_wave_manager.gd
│   └── test_save_manager.gd
├── data/
│   ├── test_god_data.gd
│   ├── test_equipment_data.gd
│   ├── test_battle_unit.gd
│   └── test_battle_state.gd
└── integration/
    ├── test_summon_flow.gd
    ├── test_battle_flow.gd
    ├── test_equipment_flow.gd
    └── test_progression_flow.gd
```

## GdUnit4 Test Pattern

```gdscript
class_name TestResourceManager
extends GdUnitTestSuite

var resource_manager: ResourceManager

func before_test():
    resource_manager = ResourceManager.new()
    add_child(resource_manager)

func after_test():
    resource_manager.queue_free()

func test_add_resource():
    resource_manager.add_resource("gold", 100)
    assert_int(resource_manager.get_resource("gold")).is_equal(100)

func test_spend_resource():
    resource_manager.set_resource("gold", 100)
    var success = resource_manager.spend("gold", 50)
    assert_bool(success).is_true()
    assert_int(resource_manager.get_resource("gold")).is_equal(50)

func test_cannot_spend_more_than_have():
    resource_manager.set_resource("gold", 100)
    var success = resource_manager.spend("gold", 200)
    assert_bool(success).is_false()
    assert_int(resource_manager.get_resource("gold")).is_equal(100)

func test_energy_respects_limit():
    resource_manager.add_resource("energy", 200)
    assert_int(resource_manager.get_resource("energy")).is_equal(100)  # Capped at 100
```

## Total Test Count Estimate

- Priority 1: ~60 tests (6 systems × ~10 tests each)
- Priority 2: ~50 tests (5 systems × ~10 tests each)
- Priority 3: ~30 tests (4 systems × ~7-8 tests each)
- Data Models: ~40 tests (4 models × ~10 tests each)
- Integration: ~20 tests

**Total: ~200 unit tests for comprehensive coverage**

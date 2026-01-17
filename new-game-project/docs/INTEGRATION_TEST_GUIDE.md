# Integration Test Guide

**Last Updated**: 2026-01-16

---

## Overview

Integration tests verify that multiple systems work together correctly by simulating **real user flows** through the game. Unlike unit tests (which test individual methods), integration tests follow the actual paths players take.

---

## Test Suite Structure

```
tests/integration/
├── run_integration_tests.gd              # Test runner (executes all suites)
├── test_specialization_flow.gd           # Specialization unlock flows
├── test_summon_to_battle_flow.gd         # Summon → Equip → Battle
├── test_territory_capture_flow.gd        # Territory capture and task assignment
├── test_dungeon_progression_flow.gd      # Dungeon entry, completion, loot
├── test_awakening_and_sacrifice_flow.gd  # Awakening and god sacrifice
├── test_shop_and_mtx_flow.gd             # Shop, crystal purchases, skins
├── test_player_progression_and_unlocks.gd # Leveling, feature unlocks
└── test_full_game_loop.gd                # Complete 22-step player journey
```

---

## Running Integration Tests

### Method 1: Command Line
```bash
godot --headless --path new-game-project --script tests/integration/run_integration_tests.gd
```

### Method 2: In-Game Debug Menu
```gdscript
# Add to debug menu
if Input.is_action_just_pressed("debug_run_integration_tests"):
    get_tree().change_scene_to_file("res://tests/integration/run_integration_tests.tscn")
```

### Method 3: Godot Editor
1. Open `run_integration_tests.gd`
2. Click "Run Current Script" (F6)
3. View results in Output panel

---

## Test Coverage

### ✅ test_specialization_flow.gd (4 tests)

**What it tests:**
- Complete specialization unlock (level 1 → 20 → unlock)
- Specialization tree progression (Tier I → Tier II)
- Role-based restrictions (Fighter can't unlock Gatherer specs)
- Independent god progression (multiple gods, different specs)

**User flows simulated:**
```
Player Journey:
1. Summon Ares (Fighter)
2. Level to 20
3. Earn gold/essence
4. View spec screen
5. Select Berserker
6. Check requirements (fail → level → pass)
7. Unlock Berserker
8. Verify bonuses apply
```

**Key assertions:**
- Cannot unlock before level 20
- Resources are consumed
- Stat bonuses (+15% attack, -5% defense, +25% crit damage)
- Multiple gods have independent spec progress

---

### ✅ test_summon_to_battle_flow.gd (3 tests)

**What it tests:**
- Summon → Equip → Battle pipeline
- Equipment stat application
- Battle victory with gear advantage
- Equipment swapping between gods
- Full 6-slot equipment sets

**User flows simulated:**
```
Player Journey:
1. Use crystals to summon Ares
2. Craft weapon
3. Enhance weapon to +3
4. Equip weapon on Ares
5. Enter dungeon
6. Fight enemy
7. Win battle (verify equipment advantage)
```

**Key assertions:**
- Stats increase with equipment
- Equipment can be unequipped and re-equipped
- Full gear set applies all bonuses
- Equipped attack > base attack

---

### ✅ test_territory_capture_flow.gd (5 tests)

**What it tests:**
- Tier 1 node capture
- God task assignment on nodes
- Resource production from territories
- Tier 2+ capture requirements (spec gate)
- Distance penalty calculation
- Connected node bonuses

**User flows simulated:**
```
Player Journey:
1. Start with base node
2. Capture adjacent Tier 1 node
3. Assign Artemis to logging task
4. Wait 1 hour (simulate)
5. Collect wood resources
6. Try to capture Tier 2 (fail - no spec)
7. Level to 20, unlock spec
8. Capture Tier 2 successfully
```

**Key assertions:**
- Player controls base initially
- Tier 1 nodes capturable immediately
- Resources generate over time
- Tier 2 requires level 20 + Tier 1 spec
- Distance affects defense rating

---

### ✅ test_dungeon_progression_flow.gd (6 tests)

**What it tests:**
- Beginner dungeon completion (3 waves)
- Energy consumption (8-18 per run)
- Difficulty progression gates (must clear Advanced before Expert)
- Loot RNG variance (10 runs, track drop rates)
- Energy regeneration (+1 per 5 minutes)
- Daily dungeon rotation (Monday = Fire, Tuesday = Water)

**User flows simulated:**
```
Player Journey:
1. Player level 10, 150 energy
2. Enter Fire Sanctum Beginner (8 energy)
3. Fight 3 waves
4. Win and receive loot
5. Energy consumed (150 → 142)
6. Run 5 times total
7. Collect essences
8. Try Expert (fail - need Advanced clear)
9. Clear Advanced
10. Enter Expert successfully
```

**Key assertions:**
- Guaranteed drops appear ~80% of runs
- Rare drops appear >0% but <100% (RNG working)
- Energy regenerates correctly
- Difficulty gating enforced
- Daily rotation works

---

### ✅ test_awakening_and_sacrifice_flow.gd (7 tests)

**What it tests:**
- Complete awakening flow (essence farming → awaken)
- Awakening stat boost
- Awakening name change
- Cannot awaken without materials
- Sacrifice duplicates for XP
- Rarity-based sacrifice bonuses
- Cannot sacrifice gods in use

**User flows simulated:**
```
Player Journey:
1. Summon Ares
2. Farm Fire Sanctum for essences
3. Collect 10 Low, 15 Mid, 20 High
4. Check awakening requirements (pass)
5. Awaken Ares
6. Name changes (Ares → God of War)
7. Stats boost (HP +20%, ATK +15%)
8. Summon 2 more Ares copies
9. Sacrifice both to main Ares
10. Gain XP and level up
```

**Key assertions:**
- Stats increase after awakening
- Name changes
- Essences consumed
- Duplicate sacrifice gives XP
- Legendary sacrifice gives 4x XP vs Common

---

### ✅ test_shop_and_mtx_flow.gd (8 tests)

**What it tests:**
- Crystal pack purchase ($4.99 → 600 crystals)
- Skin purchase with crystals
- Skin equip on correct god
- Cannot buy without crystals
- Cannot equip on wrong god
- Skin unequip
- Purchase history tracking
- Skin filtering by owned gods

**User flows simulated:**
```
Player Journey:
1. Start with 0 crystals
2. Purchase $4.99 pack (500 + 100 bonus)
3. Browse skins (500 crystals)
4. Buy "Dark Warrior Ares" skin
5. Crystals consumed (600 → 100)
6. Summon Ares
7. Equip skin on Ares
8. Portrait changes
9. Save game
10. Load game
11. Verify skin persisted
```

**Key assertions:**
- Crystals added correctly (with bonus)
- Skin ownership tracked
- Portrait path changes
- Cannot equip on wrong god
- Skin persists after save/load

---

### ✅ test_player_progression_and_unlocks.gd (9 tests)

**What it tests:**
- Level 5 → Equipment enhancement unlocks
- Level 10 → Dungeons unlock
- Level 15 → Arena unlocks
- Level 20 → Specializations unlock
- XP gain from battles
- Collection size expansion (20 → 25 slots)
- Energy cap increases with level
- Tutorial completion unlocks
- Daily login rewards
- Achievement system
- VIP level bonuses
- First-time clear rewards

**User flows simulated:**
```
Player Journey (Feature Unlocks):
1. Level 1: Only basic features
2. Level 5: Equipment enhancement unlocked
3. Level 10: Dungeons unlocked
4. Level 15: Arena unlocked
5. Level 20: Specializations unlocked

Player Journey (Collection Expansion):
1. Summon 20 gods (max capacity)
2. Try to summon 21st (fail)
3. Spend 100 crystals to expand (+5 slots)
4. Summon 21st god (success)
```

**Key assertions:**
- Features unlock at correct levels
- Collection size gating works
- Energy cap scales with level (100 → 150 → 200)
- First clear bonuses only awarded once
- VIP levels increase energy regen

---

### ✅ test_full_game_loop.gd (2 tests)

**What it tests:**
- **COMPLETE 22-STEP PLAYER JOURNEY** simulating Day 1 player

**Phase 1: Onboarding (Level 1-5)**
1. Create account
2. Complete tutorial (+500 crystals)
3. First summon (Ares)
4. Level Ares to 5
5. Craft basic weapon

**Phase 2: Dungeon Unlocking (Level 10+)**
6. Player reaches level 10
7. Dungeons unlock
8. Run Fire Sanctum Beginner 5 times
9. Collect fire essences

**Phase 3: Territory Expansion**
10. Capture first territory node
11. Assign Ares to mining task
12. Collect ore resources

**Phase 4: Specialization (Level 20+)**
13. Player reaches level 20
14. Ares reaches level 20
15. Unlock Berserker specialization
16. Verify stat bonuses apply

**Phase 5: Awakening**
17. Collect 20 High Fire Essences
18. Awaken Ares
19. Verify stat boost and name change

**Phase 6: Endgame Prep (Level 30+)**
20. Level Ares to 30
21. Complete full 6-piece equipment set
22. Run Expert dungeon successfully

**Phase 7: Cosmetics**
23. Buy $4.99 crystal pack
24. Purchase Ares skin
25. Equip skin

**Phase 8: Save Verification**
26. Save complete game state
27. Verify all systems persisted

**Second test: Multi-God Team Composition**
- Summon 4 different roles (Fighter, Gatherer, Scholar, Support)
- Level all to 30
- Equip all gods
- Run Expert with full team
- Verify team synergy

**Key assertions:**
- All 8 phases complete successfully
- Player reaches level 40+
- Ares reaches level 30+
- Specialization unlocked and applied
- Full equipment set equipped
- Skin purchased and equipped
- Territory captured and producing
- Save data contains all progress

---

## Writing New Integration Tests

### Template Structure

```gdscript
# tests/integration/test_my_new_flow.gd
extends RefCounted

var runner = null
var system1 = null
var system2 = null

func set_runner(test_runner):
    runner = test_runner

func setup():
    var registry = SystemRegistry.get_instance()
    system1 = registry.get_system("System1")
    system2 = registry.get_system("System2")

func test_my_user_flow():
    """
    USER FLOW:
    1. Step 1
    2. Step 2
    3. Step 3
    """
    setup()

    # STEP 1: Description
    var result1 = system1.do_something()
    runner.assert_not_null(result1, "Step 1: Should return result")

    # STEP 2: Description
    var result2 = system2.do_something(result1)
    runner.assert_true(result2 > 0, "Step 2: Should be positive")

    # STEP 3: Verification
    runner.assert_equal(result2, 100, "Step 3: Should match expected")
```

### Best Practices

1. **Document the flow**: Write a comment block explaining the user journey
2. **Label each step**: Use comments like `# STEP 1:` for clarity
3. **Test failure cases**: Don't just test success paths
4. **Verify side effects**: Check that resources were consumed, states changed, etc.
5. **Test cross-system integration**: Verify data flows between systems
6. **Use realistic data**: Simulate actual player values (level 20, 1000 gold, etc.)

---

## Assertion Methods

```gdscript
runner.assert_true(condition, "Message")
runner.assert_false(condition, "Message")
runner.assert_equal(actual, expected, "Message")
runner.assert_not_equal(actual, unexpected, "Message")
runner.assert_null(value, "Message")
runner.assert_not_null(value, "Message")
```

---

## Common Test Patterns

### Pattern 1: Resource Flow
```gdscript
# Verify resource consumption
var gold_before = resource_manager.get_resource_amount("gold")
system.purchase_item("sword")
var gold_after = resource_manager.get_resource_amount("gold")
runner.assert_true(gold_after < gold_before, "Gold should be consumed")
```

### Pattern 2: State Change
```gdscript
# Verify god state change
var was_awakened = god.is_awakened
awakening_system.awaken_god(god)
runner.assert_not_equal(god.is_awakened, was_awakened, "Awakened state should change")
```

### Pattern 3: Progression Gates
```gdscript
# Verify unlock requirements
var can_unlock_early = system.can_unlock()
runner.assert_false(can_unlock_early, "Should fail - requirements not met")

# Meet requirements
player.level = 20
var can_unlock_now = system.can_unlock()
runner.assert_true(can_unlock_now, "Should pass - requirements met")
```

### Pattern 4: Multi-Step Flow
```gdscript
# Simulate complete workflow
var god = summon_god()          # Step 1
level_god_to_20(god)            # Step 2
unlock_specialization(god)      # Step 3
verify_bonuses_applied(god)     # Step 4
```

---

## Debugging Failed Tests

### Read the Error Message
```
Assertion failed: Step 3: Should have 2 specializations (Expected: 2, Got: 1)
```

→ Check: Did Tier II specialization unlock? Are prerequisites met?

### Add Print Statements
```gdscript
print("God level: ", god.level)
print("Specializations: ", god.get_unlocked_specializations())
print("Resources: ", resource_manager.get_all_resources())
```

### Isolate the Step
Comment out earlier steps and manually set state:
```gdscript
# Skip steps 1-5
var god = God.new()
god.level = 20
god.unlock_specialization("fighter_berserker")
# Now test step 6 in isolation
```

---

## Coverage Goals

| System | Integration Test Coverage | Status |
|--------|---------------------------|--------|
| Specialization | ✅ Complete | 4 flows |
| Equipment | ✅ Complete | 3 flows |
| Territory | ✅ Complete | 5 flows |
| Dungeons | ✅ Complete | 6 flows |
| Awakening | ✅ Complete | 7 flows |
| Shop/MTX | ✅ Complete | 8 flows |
| Player Progression | ✅ Complete | 9 flows |
| Full Game Loop | ✅ Complete | 22-step journey |

**Total Integration Tests**: 45+ user flows covering 8 major systems

---

## CI/CD Integration

### GitHub Actions Example
```yaml
name: Integration Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup Godot
        uses: chickensoft-games/setup-godot@v1
      - name: Run Integration Tests
        run: |
          godot --headless --path new-game-project \
            --script tests/integration/run_integration_tests.gd
```

---

## Performance Considerations

### Test Execution Time
- **Unit tests**: ~5 seconds (90+ tests)
- **Integration tests**: ~30-60 seconds (45+ flows)

### Optimization Tips
1. **Use `await get_tree().process_frame` sparingly** - only when needed
2. **Mock slow operations** (network calls, file I/O)
3. **Run tests in parallel** when possible
4. **Skip animations/tweens** in test mode

---

## Next Steps

1. **Add more edge cases** (what if player disconnects mid-dungeon?)
2. **Test save corruption recovery**
3. **Test network sync** (when multiplayer added)
4. **Test memory leaks** (run 1000 summons)
5. **Test performance** (10,000 gods in collection)

---

## Glossary

| Term | Meaning |
|------|---------|
| **Integration Test** | Test that verifies multiple systems work together |
| **User Flow** | Sequence of actions a player takes (summon → equip → battle) |
| **Assertion** | Check that verifies expected behavior |
| **Setup** | Code run before each test to initialize state |
| **Test Suite** | Collection of related tests in one file |
| **Test Runner** | Script that executes all test suites |

---

*For unit test guide, see: `tests/unit/README.md`*
*For test data, see: `data/test_data/`*

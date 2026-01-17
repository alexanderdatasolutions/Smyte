# Unit Test Suite - Write ONE Test File Per Iteration

## YOUR TASK

Write the next incomplete test file from test_plan.md.

---

## STEP 1: Find the next test to write

Look in test_plan.md for the FIRST entry with `"complete": false`.

Currently that is: `tests/data/test_battle_state.gd` for `scripts/data/BattleState.gd`

---

## STEP 2: Read the source file

Read `new-game-project/scripts/data/BattleState.gd` to understand what to test.

---

## STEP 3: Write the test file

Create `new-game-project/tests/data/test_battle_state.gd` with tests for every method.

Use this template:

```gdscript
# tests/data/test_battle_state.gd
extends Node

const BattleState = preload("res://scripts/data/BattleState.gd")

var _runner: Node
var _assertions := 0

func _init(runner: Node):
    _runner = runner

func run_all():
    # Call each test method
    test_example()
    # ... more tests
    return _assertions

func assert_true(condition: bool, msg: String = ""):
    _assertions += 1
    if not condition:
        push_error("FAIL: " + msg)

func assert_equal(actual, expected, msg: String = ""):
    _assertions += 1
    if actual != expected:
        push_error("FAIL: %s - Expected %s, got %s" % [msg, expected, actual])

func test_example():
    # Arrange
    var state = BattleState.new()
    # Act
    # Assert
    assert_true(state != null, "state should exist")
```

Write tests for ALL methods in the source file.

---

## STEP 4: Update test_plan.md

Change the entry from `"complete": false` to `"complete": true` and set `tests_count` to the number of assertions.

---

## STEP 5: Update test_activity.md

Add a new entry to the log.

---

## STEP 6: Commit

```bash
cd new-game-project && git add -A && git commit -m "test: add BattleState unit tests"
```

---

## STEP 7: Output

Print: "Created X tests for BattleState. Y test files remaining."

Then STOP. Do not continue to the next test file.

---

## IMPORTANT

- DO write the actual test file with real test code
- DO NOT just analyze or plan - actually create the file
- DO NOT skip to exploring other files
- DO NOT loop - complete one test file then stop

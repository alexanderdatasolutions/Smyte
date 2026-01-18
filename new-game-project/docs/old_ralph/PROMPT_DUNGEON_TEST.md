@docs/DUNGEON_WAVE_SYSTEM_SPEC.md @docs/DUNGEON_WAVE_TEST_PLAN.md

# Dungeon & Wave System - Testing & Documentation

## CRITICAL RULES

1. **TEST SYSTEMATICALLY** - Follow test plan in order
2. **DOCUMENT EVERYTHING** - Record all findings
3. **ONE TEST AT A TIME** - Complete each test case fully
4. **INVESTIGATE THE BUG** - Focus on "gods disappearing on defeat"

---

## Process (Every Iteration)

### Step 1: Review Current Test
Read `docs/DUNGEON_WAVE_TEST_PLAN.md`. Find FIRST test with `Pass/Fail: ___` (not filled in).

**STOP HERE if no unfilled test remains. Output `<promise>COMPLETE</promise>`**

### Step 2: Run ONLY That ONE Test
Follow test steps exactly:
- Use game interaction commands
- Record console output
- Take screenshots where specified
- Note pass/fail result

**DO NOT run multiple tests in one iteration. STOP after completing this ONE test.**

### Step 3: Document Results
Update test plan for THIS TEST ONLY:
- Fill in Pass/Fail
- Record console logs
- Note any errors or unexpected behavior
- For TC-005 (god deletion bug): RECORD GOD COUNTS

### Step 4: Output and STOP
Output EXACTLY this format, then STOP:
```
Completed: [Test ID and name]
Result: PASS/FAIL
Finding: [One sentence summary]
Next: [Next test ID] or COMPLETE if done
```

**DO NOT continue to next test. END THE ITERATION HERE.**

---

## Testing Commands Available

### Game Interaction
```bash
run_project new-game-project
game_wait_ready
game_get_screen
game_click "BUTTON_TEXT"
game_get_buttons
game_screenshot user://test_result.png
get_debug_output  # Check for CollectionManager logs
stop_project
```

### Test Specific Checks
```bash
# Check console for god removals
get_debug_output | grep "REMOVING GOD"

# Check collection count
game_interact action:call_method path:/root/Main/GameCoordinator/CollectionManager method:get_all_gods
```

---

## Critical Test: TC-005 (God Deletion Bug)

**MOST IMPORTANT TEST - Pay Special Attention**

Before battle:
1. Count gods in collection (screenshot)
2. Record god IDs
3. Watch console during battle

During battle:
1. Monitor debug output
2. Look for "CollectionManager: REMOVING GOD"
3. Check stack traces

After battle:
1. Count gods again
2. Compare before/after
3. Check if gods just hidden or actually deleted
4. Verify gods not permanently assigned to hex nodes

**Expected**: NO "REMOVING GOD" messages, god count UNCHANGED

---

## When All Tests Complete

When all tests in DUNGEON_WAVE_TEST_PLAN.md are filled in:
1. Create summary report
2. List all failures
3. Document bug status
4. Output: `<promise>COMPLETE</promise>`

---

## DO NOT

- ❌ Skip tests or mark them without running
- ❌ Ignore console output
- ❌ Assume gods deleted without checking collection
- ❌ Test only victories (MUST test defeats)
- ❌ Create new test cases (use existing plan)
- ❌ **RUN MULTIPLE TESTS IN ONE ITERATION** ⚠️ CRITICAL
- ❌ Continue after documenting one test result

## DO

- ✓ Follow test plan exactly
- ✓ **STOP after completing ONE test** ⚠️ CRITICAL
- ✓ Record ALL console output for TC-005
- ✓ Take screenshots as specified
- ✓ Check both UI and data layer
- ✓ Verify god references vs actual deletion
- ✓ Compare before/after states
- ✓ **Output completion message and STOP**

---

## Bug Investigation Checklist

For "gods disappearing on defeat" issue:

**Data Layer Check**:
- [ ] Console shows "REMOVING GOD" message? (should be NO)
- [ ] CollectionManager.get_all_gods() count unchanged?
- [ ] Gods still in `gods_by_id` dictionary?

**UI Layer Check**:
- [ ] Gods visible in CollectionScreen after battle?
- [ ] CollectionScreen filters hiding defeated gods?
- [ ] Gods showing as "assigned" somewhere?

**Assignment Check**:
- [ ] Gods permanently assigned to hex node garrisons?
- [ ] Gods permanently assigned to hex node workers?
- [ ] Battle team keeping reference preventing display?

**Save/Load Check**:
- [ ] Save file before battle has gods?
- [ ] Save file after battle has gods?
- [ ] Reload restores god collection?

---

## Success Criteria

Testing complete when:
1. All 10 test cases have Pass/Fail marked
2. TC-005 (defeat bug) thoroughly investigated
3. Bug status determined (confirmed/not reproducible/UI issue)
4. Console logs captured
5. Test report filled out
6. Recommendations provided

---

## Example Iteration (CORRECT - One Test Only)

```
Step 1: Reading test plan... Next test is TC-004 (Single Wave Battle Victory)
Step 2: Starting game... Opening DungeonScreen... Entering battle...
Step 3: Battle completed with victory. Rewards granted: 500 mana.
Step 4: Updated test plan: TC-004 PASS

Completed: TC-004 - Single Wave Battle Victory
Result: PASS
Finding: Victory screen appeared, rewards granted, no god removal logs.
Next: TC-005
```

**Note**: Iteration ends here. Next iteration will do TC-005.

## Example Iteration (WRONG - Multiple Tests)

```
❌ WRONG - Do not do this:
Step 1: Reading test plan... Tests TC-001, TC-002, TC-003 need completion
Step 2: Running all three tests...
[This violates the ONE TEST rule]
```

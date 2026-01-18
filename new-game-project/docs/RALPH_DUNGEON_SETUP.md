# Ralph Dungeon Testing - Setup Complete

## Overview

Ralph is now set up to systematically test the dungeon/wave system and investigate the "gods disappearing on defeat" bug.

## Files Created

### Core Documentation
1. **[docs/DUNGEON_WAVE_SYSTEM_SPEC.md](DUNGEON_WAVE_SYSTEM_SPEC.md)** - Complete system specification
   - All components described (DungeonCoordinator, WaveManager, BattleCoordinator, etc.)
   - Data formats for dungeons and battles
   - Expected behaviors
   - Bug investigation checklist

2. **[docs/DUNGEON_WAVE_TEST_PLAN.md](DUNGEON_WAVE_TEST_PLAN.md)** - Manual test plan with 10 test cases
   - TC-001 through TC-010 covering all features
   - **TC-005 focuses on the critical "gods disappearing on defeat" bug**
   - Integration tests included
   - Results tracking built in

3. **[PROMPT_DUNGEON_TEST.md](../PROMPT_DUNGEON_TEST.md)** - Ralph's instructions
   - Follows Anthropic's recommended approach for long-running agents
   - Systematic testing process
   - One test at a time
   - Complete documentation requirements

### Ralph Runner Script
**[../ralph-dungeon.sh](../../ralph-dungeon.sh)** - Automated test runner
- Runs Ralph in iterations with fresh context each time
- Stops when all tests complete (`<promise>COMPLETE</promise>`)
- Prevents runaway costs with max iteration limit

## How to Run Ralph

### Quick Start

```bash
cd /c/Users/alexa/Documents/Coding/Smyte
./ralph-dungeon.sh 15
```

This will run Ralph for up to 15 iterations. Each iteration:
1. Reads the test plan
2. Runs the next incomplete test
3. Documents results
4. Moves to next test

### What Ralph Will Do

**For Each Test**:
1. Start the game
2. Navigate to the appropriate screen
3. Execute the test steps
4. Capture console output
5. Take screenshots where needed
6. Record pass/fail results
7. Update the test plan

**Critical Test - TC-005** (Gods Disappearing on Defeat):
- Record god count before battle
- Monitor console for "CollectionManager: REMOVING GOD"
- Intentionally lose the battle
- Check god count after
- Determine if bug is real or UI issue

## Progress Tracking

Ralph updates these files:
- **docs/DUNGEON_WAVE_TEST_PLAN.md** - Test results (Pass/Fail markers)
- **docs/DUNGEON_TEST_REPORT.md** - Final summary report (will be created)

## Expected Completion

Ralph will output `<promise>COMPLETE</promise>` when:
- All 10 test cases have Pass/Fail results
- TC-005 (critical bug test) is thoroughly investigated
- Bug status is determined
- Test report is filled out

## Manual Monitoring

While Ralph runs, you can watch:
```bash
# Watch test plan updates
tail -f new-game-project/docs/DUNGEON_WAVE_TEST_PLAN.md

# Watch for god deletion logs
tail -f ~/Library/Logs/Claude/claude-code.log | grep "REMOVING GOD"
```

## About Loot/Crafting Integration

The dungeon reward system already supports:
- **Mana rewards** - Granted on victory
- **Equipment drops** - Chance-based
- **Material drops** - Can be added for crafting

This ties into your vision:
- Daily dungeons become core gameplay loop
- Materials unlock crafting recipes
- Dungeon completion can unlock hex nodes
- Integrates with progression systems

## Next Steps After Testing

Once Ralph completes testing:

1. **Review Test Report** - Check docs/DUNGEON_TEST_REPORT.md
2. **Fix Any Bugs** - Address issues found during testing
3. **Expand Loot System**:
   - Add material drops to dungeon rewards
   - Connect to crafting system
   - Link dungeon completion to node unlocks
4. **Balance Daily Dungeons**:
   - Energy costs
   - Reward tiers
   - Difficulty scaling

## Cost Control

Ralph uses `--dangerously-skip-permissions` for automation, but:
- Max iterations set to prevent runaway costs
- Each iteration starts with fresh context (no bloat)
- Stops automatically when tests complete

Recommended: Start with 10-15 iterations for testing, then increase if needed.

## Troubleshooting

**If Ralph Gets Stuck**:
- Check that game is running properly
- Verify test plan JSON is valid
- Look for infinite loops in test execution

**If Tests Fail**:
- Review console output in iteration logs
- Check screenshots (if Ralph generates them)
- Manually reproduce the test to verify

**If Bug Investigation Inconclusive**:
- Run TC-005 manually with careful observation
- Check save file integrity
- Verify CollectionManager state directly

## Reference

This setup follows the [Ralph Wiggum Guide](../ralph_wiggum_guide.md) recommendations:
- Fresh context per iteration (bash loop method)
- Structured plan with pass/fail tracking
- Clear completion criteria
- Sandboxed environment (via skip-permissions)

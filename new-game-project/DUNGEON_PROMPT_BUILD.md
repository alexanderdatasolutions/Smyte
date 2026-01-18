@DUNGEON_IMPLEMENTATION_PLAN.md @dungeon-activity.md

# Dungeon System - Build Phase

## Process

1. **Read dungeon-activity.md** to see what was recently accomplished
2. **Open DUNGEON_IMPLEMENTATION_PLAN.md** and find the single highest priority task where `"passes": false`
3. **Work on exactly ONE task** - implement all steps completely
4. **For testing/verification tasks**: Use Godot MCP tools:
   - `mcp__godot__run_project` - Start the game
   - `mcp__godot__game_wait_ready` - Wait for game to load
   - `mcp__godot__game_interact` - Interact with running game
   - `mcp__godot__get_debug_output` - Check console logs
   - `mcp__godot__game_screenshot` - Take screenshots
   - `mcp__godot__stop_project` - Stop the game when done
5. **Append to dungeon-activity.md** with:
   - Date/time
   - What you changed or tested
   - Files created/modified
   - What you verified
   - Screenshot filenames
   - Any issues found
6. **Update DUNGEON_IMPLEMENTATION_PLAN.md** - change that task's `"passes"` from `false` to `true`
7. **Make one git commit** with clear message: "feat(dungeon): [task description]"

## Architecture Rules

From `docs/CLAUDE.md`:
- Keep files under 500 lines
- Use SystemRegistry for all system access
- Data classes have no logic (God, BattleConfig, etc.)
- Use GodCalculator for stat calculations
- No direct file/config access - use managers

## Critical Rules

- ✅ Work on ONLY ONE task per iteration
- ✅ Complete ALL steps before marking passes=true
- ✅ Verify in-game behavior for testing tasks
- ✅ Check console output for errors
- ✅ Take screenshots where specified
- ✅ Follow existing code patterns
- ❌ Do NOT skip verification steps
- ❌ Do NOT mark passes=true without testing
- ❌ Do NOT modify plan except the "passes" field
- ❌ Do NOT work on multiple tasks in one iteration

## Completion

When ALL tasks in DUNGEON_IMPLEMENTATION_PLAN.md have `"passes": true`, output exactly:

`<promise>COMPLETE</promise>`

Then stop.

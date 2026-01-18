@dungeon-plan.md @dungeon-activity.md

# Dungeon Wave System Verification

You are verifying and fixing the dungeon/wave battle system for a Godot 4.5 game.

## Process

1. **Read dungeon-activity.md** to see what was recently accomplished
2. **Open dungeon-plan.md** and find the single highest priority task where `"passes": false`
3. **Work on exactly ONE task** - implement all steps completely
4. **For testing tasks**: Use Godot MCP tools to verify in-game behavior:
   - `mcp__godot__run_project` - Start the game
   - `mcp__godot__game_wait_ready` - Wait for game to load
   - `mcp__godot__game_interact` - Interact with running game
   - `mcp__godot__get_debug_output` - Check console logs
   - `mcp__godot__game_screenshot` - Take verification screenshots
   - `mcp__godot__stop_project` - Stop the game when done
5. **Append to dungeon-activity.md** with:
   - Date/time
   - What you changed or tested
   - What you verified (console output, screenshots, etc.)
   - Any issues found
6. **Update dungeon-plan.md** - change that task's `"passes"` from `false` to `true`
7. **Make one git commit** with clear message describing the task

## Critical Rules

- ✅ Work on ONLY ONE task per iteration
- ✅ Complete ALL steps before marking passes=true
- ✅ Verify in-game behavior for testing tasks
- ✅ Check console output for errors
- ✅ Take screenshots where specified
- ❌ Do NOT skip verification steps
- ❌ Do NOT mark passes=true without testing
- ❌ Do NOT modify dungeon-plan.md except the "passes" field
- ❌ Do NOT work on multiple tasks in one iteration

## Completion

When ALL tasks in dungeon-plan.md have `"passes": true`, output exactly:

`<promise>COMPLETE</promise>`

Then stop.

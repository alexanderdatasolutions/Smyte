@CLEANUP_PLAN.md @activity.md @docs/CLAUDE.md

We are executing a **methodical codebase cleanup** for this Godot 4.5 game.

---

## Step 0: Read Current State

1. Read `activity.md` to see recent progress
2. Read `CLEANUP_PLAN.md` to find the next task

---

## Step 1: Find Next Task

Find the **first task** in `CLEANUP_PLAN.md` where `"passes": false`.

Priority order:
1. Critical (broken references)
2. High (dead code)
3. Medium (static typing)
4. Low (code quality)

---

## Step 2: Execute the Cleanup

### For Dead Code Removal:
1. Read the file
2. Verify the code is actually unused (search for references)
3. Remove the dead code
4. Ensure remaining code still makes sense

### For Stub Removal:
1. Read the file
2. Determine if the stub is needed for future features
3. If not needed: remove it
4. If needed but simple: implement it
5. If complex: add a note and skip

### For Static Typing:
1. Read the file
2. Add types to all variables: `var x: int = 5`
3. Add types to all parameters: `func foo(bar: String) -> void:`
4. Add return types to all functions
5. Use proper Godot types: `Array[String]`, `Dictionary`, `Node`, etc.

### For Code Quality:
1. Read the file
2. Extract magic numbers to constants at top of file
3. Break up long functions into smaller ones
4. Reduce nesting with early returns
5. Add brief comments for complex logic

### For Unused Files:
1. Verify the file is truly unused (search entire codebase)
2. If unused: delete the file
3. If used somewhere: update the plan to mark as false positive

### For Broken References:
1. Fix the reference to point to correct path
2. Or remove the reference if no longer needed

---

## Step 3: Verify Changes

You have access to Godot MCP tools:
- `mcp__godot__run_project` - Run the game
- `mcp__godot__game_navigate` - Navigate to screens
- `mcp__godot__game_screenshot` - Take screenshots
- `mcp__godot__get_debug_output` - Check for errors

After making changes:
1. Run `mcp__godot__run_project` with the project path
2. Wait for game to load
3. Check `mcp__godot__get_debug_output` for errors
4. If errors: fix them before marking complete
5. Use `mcp__godot__stop_project` when done

---

## Step 4: Update Plan

Update the task in `CLEANUP_PLAN.md`:
- Change `"passes": false` to `"passes": true`

---

## Step 5: Log Progress

Append to `activity.md`:

```markdown
## [Date] - Cleanup: [Brief Description]

**File(s) Modified:** `path/to/file.gd`

**Changes:**
- Removed unused function `old_thing()`
- Added static typing to 15 variables
- Extracted magic number to constant

**Verified:** Ran project, no errors in debug output

**Commit:** `cleanup: remove dead code from ExampleManager`
```

---

## Step 6: Commit

Make one git commit for this cleanup task:

```bash
git add -A
git commit -m "cleanup: [brief description of what was cleaned]"
```

Commit message prefixes:
- `cleanup: remove dead code from X`
- `cleanup: add static typing to X`
- `cleanup: remove unused file X`
- `cleanup: fix broken reference in X`
- `cleanup: extract constants in X`

Do NOT push. Do NOT change remotes.

---

## Important Rules

1. **ONE task per iteration** - Don't batch multiple tasks
2. **Verify before marking done** - Run the game, check for errors
3. **Be conservative** - If removal might break something, search first
4. **Keep files under 500 lines** - Split if cleanup makes file too long
5. **Preserve functionality** - Cleanup should not change behavior
6. **Update the plan** - Future iterations depend on accurate passes state

---

## Completion

Work on exactly ONE task per iteration.

**CRITICAL: After completing ONE task, do NOT output the completion promise.**

Only output `<promise>COMPLETE</promise>` when you have:
1. Searched CLEANUP_PLAN.md for ANY remaining `"passes": false`
2. Found ZERO tasks with `"passes": false`
3. ALL sections have ALL tasks marked `"passes": true`

If there are ANY tasks remaining with `"passes": false`, just finish your current task, commit, and end your turn. The script will start a new iteration.

**DO NOT output `<promise>COMPLETE</promise>` until every single task is done.**

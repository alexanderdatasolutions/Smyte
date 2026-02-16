@AUDIT_PLAN.md @activity.md @docs/CLAUDE.md

We are executing a **comprehensive pre-release audit** for this Godot 4.5 game.

---

## Step 0: Read Current State

1. Read `activity.md` to see recent progress
2. Read `AUDIT_PLAN.md` to find the next task

---

## Step 1: Find Next Task

Find the **first task** in `AUDIT_PLAN.md` where `"passes": false`.

Priority order:
1. Critical (save system, core gameplay)
2. High (dead code, debug prints, static typing, error handling)
3. Medium (simplification, docs, logging, achievements, UI)
4. Low (performance, code quality, configs)

---

## Step 2: Execute the Fix

### For Save System Issues:
1. Read SaveManager.gd and related files
2. Identify what's missing from save/load
3. Add proper serialization/deserialization
4. Test save file structure
5. Verify round-trip works

### For Dead Code Removal:
1. Read the file
2. Verify the code is actually unused (search for references)
3. Remove the dead code
4. Ensure remaining code still makes sense

### For Debug Statement Cleanup:
1. Read the file
2. Identify print/push_warning/push_error statements
3. Remove debug prints
4. Keep only: error logging for crashes, analytics events
5. Convert useful debugs to proper logging if needed

### For Static Typing:
1. Read the file
2. Add types to all variables: `var x: int = 5`
3. Add types to all parameters: `func foo(bar: String) -> void:`
4. Add return types to all functions
5. Use proper Godot types: `Array[God]`, `Dictionary`, `Node`, etc.

### For Error Handling:
1. Read the file
2. Add null checks before accessing objects
3. Add array bounds checks
4. Add dictionary key checks with `.get()` or `has()`
5. Add try/catch for risky operations
6. Add graceful fallbacks

### For Code Simplification:
1. Read the file
2. Extract magic numbers to constants at top of file
3. Break up long functions (>50 lines) into smaller ones
4. Reduce nesting with early returns
5. Remove duplicate code
6. Simplify complex conditionals

### For Documentation:
1. Read the file
2. Add docstrings to public functions
3. Add class-level documentation
4. Explain complex algorithms
5. Document signal purposes
6. Use format: `## Description\n## Parameters\n## Returns`

### For Logging/Analytics:
1. Read the file
2. Identify key player actions that should be logged
3. Add EventBus emissions for analytics
4. Ensure FirebaseIntegration handles the event
5. Remove excessive logging

### For Achievement Issues:
1. Read AchievementManager and achievement triggers
2. Add missing triggers to appropriate systems
3. Ensure progress tracking works
4. Test unlock conditions

### For UI Issues:
1. Read the UI file
2. Add loading states where needed
3. Add error state handling
4. Fix button enabled/disabled states
5. Remove placeholder text
6. Ensure consistent styling

### For Performance:
1. Read the file
2. Move expensive operations out of _process()
3. Cache frequently accessed values
4. Use object pooling where appropriate
5. Fix memory leaks

### For Config Issues:
1. Read the JSON file
2. Fix broken references
3. Add missing required fields
4. Ensure ID uniqueness
5. Validate cross-references

---

## Step 3: Verify Changes

You have access to Godot MCP tools:
- `mcp__godot__run_project` - Run the game
- `mcp__godot__game_navigate` - Navigate to screens
- `mcp__godot__game_screenshot` - Take screenshots
- `mcp__godot__get_debug_output` - Check for errors

After making changes:
1. Run `mcp__godot__run_project` with projectPath: "c:/Users/alexa/Documents/Coding/Smyte/new-game-project"
2. Wait for game to load (use `mcp__godot__game_wait_ready`)
3. Check `mcp__godot__get_debug_output` for errors
4. If errors: fix them before marking complete
5. Use `mcp__godot__stop_project` when done

---

## Step 4: Update Plan

Update the task in `AUDIT_PLAN.md`:
- Change `"passes": false` to `"passes": true`

---

## Step 5: Log Progress

Append to `activity.md`:

```markdown
## [Date] - Audit: [Brief Description]

**Priority:** Critical/High/Medium/Low
**File(s) Modified:** `path/to/file.gd`

**Changes:**
- Removed debug print statement
- Added static typing to 15 variables
- Fixed null check before method call

**Verified:** Ran project, no errors in debug output

**Commit:** `audit: [brief description]`
```

---

## Step 6: Commit

Make one git commit for this audit task:

```bash
git add -A
git commit -m "$(cat <<'EOF'
audit: [brief description of what was fixed]

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

Commit message prefixes:
- `audit: fix save system for equipment`
- `audit: remove dead code from BattleManager`
- `audit: remove debug prints from UI`
- `audit: add static typing to SummonManager`
- `audit: add null checks to TerritoryManager`
- `audit: simplify WorldView rendering`
- `audit: document damage calculation formula`
- `audit: add analytics for shop purchases`
- `audit: fix achievement trigger for first_summon`
- `audit: add loading states to ShopScreen`
- `audit: optimize GodCard rendering`
- `audit: fix loot table references`

Do NOT push. Do NOT change remotes.

---

## Important Rules

1. **ONE task per iteration** - Don't batch multiple tasks
2. **Verify before marking done** - Run the game, check for errors
3. **Be conservative** - If removal might break something, search first
4. **Keep files under 500 lines** - Split if cleanup makes file too long
5. **Preserve functionality** - Audit should not change behavior (unless fixing bugs)
6. **Update the plan** - Future iterations depend on accurate passes state
7. **Test save/load** - Any save system changes MUST be tested

---

## Completion

Work on exactly ONE task per iteration.

**CRITICAL: After completing ONE task, do NOT output the completion promise.**

Only output `<promise>COMPLETE</promise>` when you have:
1. Searched AUDIT_PLAN.md for ANY remaining `"passes": false`
2. Found ZERO tasks with `"passes": false`
3. ALL sections have ALL tasks marked `"passes": true`

If there are ANY tasks remaining with `"passes": false`, just finish your current task, commit, and end your turn. The script will start a new iteration.

**DO NOT output `<promise>COMPLETE</promise>` until every single task is done.**

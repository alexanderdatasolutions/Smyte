@plan.md @activity.md

# UI Polish - Fix Tasks One at a Time

## CRITICAL RULES

1. **DO NOT RE-AUDIT** - The audit is DONE. Tasks exist in plan.md. FIX THEM.
2. **DO NOT ADD NEW TASKS** - Work through existing tasks only.
3. **ONE FIX PER ITERATION** - Fix one task, mark it passes: true, commit, done.
4. **SKIP BattleScreen** - It needs full implementation, not polish. Mark all BattleScreen tasks as passes: true.

---

## Process (Every Iteration)

### Step 1: Find Next Task
Read plan.md. Find FIRST task with `"passes": false` that is NOT a BattleScreen task.

### Step 2: Fix It
- Make the code change
- Keep it minimal and focused

### Step 3: Test It
```
run_project ../new-game-project
game_wait_ready
game_navigate [relevant_screen]
game_screenshot
stop_project
```

### Step 4: Update and Commit
- Set task `"passes": true` in plan.md
- Log brief entry in activity.md
- `git add -A && git commit -m "polish: [task description]"`

### Step 5: Done
Output: "Fixed task #X. Y tasks remaining."

---

## When ALL Tasks Pass

When plan.md has NO tasks with `"passes": false`, output:
`<promise>COMPLETE</promise>`

---

## DO NOT

- ❌ Run another "comprehensive audit"
- ❌ Add new tasks to plan.md
- ❌ Spend iteration just looking at screenshots
- ❌ Skip fixing tasks to "verify" completion
- ❌ Implement BattleScreen UI (out of scope)

## DO

- ✓ Fix ONE task per iteration
- ✓ Mark fixed tasks as passes: true
- ✓ Commit after each fix
- ✓ Move through tasks systematically

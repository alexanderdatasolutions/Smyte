@smyte-ralph/test_plan.md @smyte-ralph/test_activity.md

# Write ONE Unit Test File

Read smyte-ralph/test_activity.md to see what was recently accomplished.

Open smyte-ralph/test_plan.md and find the FIRST task where `"complete": false`.

Work on exactly ONE test file:

1. Read the source file listed in the task (in new-game-project/)
2. Create the test file with comprehensive tests for ALL methods
3. Use the existing test pattern from new-game-project/tests/data/test_god_data.gd

After implementing:
- Update that task's `complete` in smyte-ralph/test_plan.md from `false` to `true`
- Update `tests_count` with the number of assertions
- Append a dated entry to smyte-ralph/test_activity.md with test count

Make one git commit:
```bash
cd new-game-project && git add -A && git commit -m "test: add [SystemName] unit tests"
```

ONLY WORK ON A SINGLE TEST FILE PER ITERATION.

When ALL test files have `"complete": true`, output <promise>COMPLETE</promise>

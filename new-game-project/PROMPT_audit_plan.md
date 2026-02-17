# Create Pre-Release Audit Plan

You are creating a comprehensive pre-release audit plan for this Godot 4.5 game.

## Your Task

Analyze the entire codebase and create `AUDIT_PLAN.md` with all issues that need fixing before release.

## What to Look For

### Critical Priority
1. **Save System** - Are all systems properly saving/loading?
2. **Core Gameplay Bugs** - Crashes, undefined properties, broken features

### High Priority
3. **Dead Code** - Unused functions, signals, variables (verify no callers before flagging)
4. **Debug/Print Cleanup** - Count all print() statements that need removal
5. **Static Typing** - Files with untyped variables/parameters/returns
6. **Error Handling** - Missing null checks, uncaught errors

### Medium Priority
7. **Code Simplification** - Files over 500 lines that need splitting
8. **Long Functions** - Functions over 50 lines that need breaking up
9. **Logging/Analytics** - Missing analytics events, infinite loops
10. **Achievements** - Missing triggers, performance issues
11. **UI Consistency** - Duplicate styling code, inconsistent patterns

### Low Priority
12. **Performance** - Uncached lookups, memory leaks
13. **Code Quality** - Logic in data classes, inconsistent patterns
14. **JSON Config Validation** - Orphaned files, broken references
15. **Data-Driven Config** - Hardcoded values that should be in JSON

## Output Format

Create `AUDIT_PLAN.md` with this structure:

```markdown
# Pre-Release Audit Plan

## Overview
**Total issues found: X**
- Critical: X
- High: X
- Medium: X
- Low: X

**Audit Date:** YYYY-MM-DD
**Scope:** Description

---

## 1. Category Name

\`\`\`json
[
  {
    "priority": "critical|high|medium|low",
    "file": "path/to/file.gd",
    "issue": "Description of the problem",
    "action": "What needs to be done to fix it",
    "passes": false
  }
]
\`\`\`
```

## Rules

1. **Be specific** - Include file paths and line numbers where possible
2. **Verify dead code** - Search for callers before flagging as dead
3. **Count accurately** - Actually count print statements, untyped vars, etc.
4. **Prioritize correctly** - Crashes are critical, style issues are low
5. **Action items** - Each issue must have a clear action to fix it

## When Done

Output: `<promise>PLAN_COMPLETE</promise>`

@docs/CLAUDE.md @activity.md

We are doing a **comprehensive codebase cleanup** for this Godot 4.5 game.

---

## Step 0a: Study the Entire Codebase

Study the codebase with up to **100 parallel Sonnet subagents** to identify cleanup opportunities:

### Scripts to Analyze
- `scripts/systems/core/` - SystemRegistry, SaveManager, ResourceManager, GameCoordinator
- `scripts/systems/collection/` - GodManager, SummonManager, TeamManager
- `scripts/systems/battle/` - BattleManager, DamageCalculator
- `scripts/systems/progression/` - AwakeningManager, LevelingManager, SpecializationManager
- `scripts/systems/equipment/` - EquipmentManager, EquipmentCraftingManager
- `scripts/systems/territory/` - TerritoryManager, HexGridManager, TaskAssignmentManager
- `scripts/systems/dungeon/` - DungeonManager, DungeonRewardCalculator
- `scripts/systems/resources/` - ResourceManager
- `scripts/systems/shop/` - ShopManager
- `scripts/ui/screens/` - All screen scripts
- `scripts/ui/components/` - All UI components
- `scripts/utilities/` - Utility scripts

### JSON Configs to Check
- `data/*.json` - All config files

### Scenes to Check
- `scenes/*.tscn` - All scene files

---

## Step 0b: Identify Cleanup Categories

For each file, look for:

### 1. Dead Code
- Functions never called
- Variables never used
- Signals never emitted or connected
- Commented-out code blocks
- `pass` statements in empty functions that do nothing
- Imports/preloads never used

### 2. Stubs and Placeholders
- Functions with `TODO` or `FIXME` comments and no real implementation
- Functions that just `print()` or `push_warning()` and return
- Placeholder return values
- Empty signal handlers

### 3. Duplicated Logic
- Same code copy-pasted across files
- Similar functions that could be consolidated
- Repeated magic numbers

### 4. Missing Static Typing
- Untyped variables: `var x = 5` should be `var x: int = 5`
- Untyped function parameters
- Missing return types: `func foo():` should be `func foo() -> void:`

### 5. Code Quality Issues
- Magic numbers without constants
- Overly long functions (>50 lines)
- Deep nesting (>3 levels)
- Inconsistent naming conventions
- Missing or outdated comments

### 6. Unused Files
- Scripts not attached to any scene
- Scenes not referenced anywhere
- JSON configs not loaded by any manager

### 7. Broken References
- Preload paths that don't exist
- Signal connections to missing methods
- JSON keys that don't match expected schema

---

## Step 1: Create CLEANUP_PLAN.md

Create `CLEANUP_PLAN.md` with ALL identified cleanup tasks. Structure as:

```markdown
# Codebase Cleanup Plan

## Overview
Brief summary of cleanup scope and goals.

---

## Dead Code Removal

```json
[
  {
    "file": "scripts/systems/example/ExampleManager.gd",
    "issue": "Unused function `_old_implementation()` on line 45",
    "action": "Remove function",
    "passes": false
  }
]
```

## Stub Completion or Removal

```json
[
  {
    "file": "scripts/systems/example/ExampleManager.gd",
    "issue": "Stub function `placeholder_feature()` with TODO comment",
    "action": "Remove if not needed, implement if needed",
    "passes": false
  }
]
```

## Static Typing

```json
[
  {
    "file": "scripts/systems/example/ExampleManager.gd",
    "issue": "25 untyped variables and 12 untyped function signatures",
    "action": "Add static types to all variables and functions",
    "passes": false
  }
]
```

## Code Quality

```json
[
  {
    "file": "scripts/systems/example/ExampleManager.gd",
    "issue": "Magic number 0.15 used for damage calculation on line 78",
    "action": "Extract to constant DAMAGE_MULTIPLIER",
    "passes": false
  }
]
```

## Unused Files

```json
[
  {
    "file": "scripts/old/DeprecatedManager.gd",
    "issue": "File not referenced anywhere in codebase",
    "action": "Delete file",
    "passes": false
  }
]
```

---

## Priority Order

1. **Critical**: Broken references that cause errors
2. **High**: Dead code removal (reduces confusion)
3. **Medium**: Static typing (improves maintainability)
4. **Low**: Code quality improvements (nice to have)
```

---

## Important Rules

1. **Be thorough** - Check EVERY .gd file and EVERY .tscn file
2. **Be specific** - Include exact line numbers and function names
3. **Be conservative** - If unsure whether something is used, mark it for review
4. **Group by file** - Multiple issues in one file should be in one task
5. **Prioritize** - Critical issues first, cosmetic last

---

## Completion

When the plan is complete with ALL cleanup tasks identified, output exactly:

<promise>PLAN_COMPLETE</promise>

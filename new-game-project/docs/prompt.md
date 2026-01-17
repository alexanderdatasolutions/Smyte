# Implement ONE Task from Role & Specialization System

Read the CLAUDE.md section below for architecture, code standards, and design philosophy.
Read the role_spec_activity.md section below to see what was recently accomplished.

## Find Your Task

Find the FIRST task in role_spec_plan.md (included below) where `"complete": false`.

Work on exactly ONE task per iteration.

## Implementation Rules

### Critical Godot 4.5 Rules
- NEVER use `var trait` or `var task` as variable names - these are RESERVED
- Static factory methods must use: `var script = load("res://path.gd"); var instance = script.new()`
- NOT: `ClassName.new()` inside static methods returning same class type

### Code Standards (from CLAUDE.md)
- Files under 500 lines - split if larger
- Single responsibility - each class does one thing
- SystemRegistry pattern for system access: `SystemRegistry.get_instance().get_system("Name")`
- Logic in systems - data classes are dumb containers

### Test Requirements
- All system files MUST have corresponding tests in tests/unit/
- Follow existing test pattern (see tests/unit/test_god_data.gd)
- Test all public methods with edge cases

## Task Execution Flow

### For Data Classes (scripts/data/):
1. Read existing patterns: God.gd, GodTrait.gd, Equipment.gd
2. Create the data class with proper from_dict() method
3. Ensure class_name is declared
4. Verify no reserved keywords used

### For System Files (scripts/systems/):
1. Read existing patterns: TraitManager.gd, CollectionManager.gd
2. Create the system extending Node with class_name
3. Add to SystemRegistry.gd at appropriate phase
4. Create corresponding test file immediately

### For JSON Data (data/):
1. Read existing patterns: traits.json, gods.json
2. Create comprehensive data (not placeholders)
3. Validate JSON syntax

### For UI (scripts/ui/):
1. Read existing patterns in scripts/ui/screens/ and scripts/ui/components/
2. Follow dark fantasy theme
3. Match existing styling patterns

## After Implementation

1. Take a screenshot of the game to verify nothing is broken (if UI changed)
2. Update the task's `complete` in smyte-ralph/role_spec_plan.md from `false` to `true`
3. Append a dated entry to smyte-ralph/role_spec_activity.md:
   ```
   ## [DATE] - Task ID: [task_id]
   - Completed: [task description]
   - Files created/modified: [list]
   - Notes: [any relevant info]
   ```

4. Make one git commit:
   ```bash
   cd ~/Documents/Coding/Smyte && git add -A && git commit -m "feat(roles): [brief description]"
   ```

## IMPORTANT

- ONLY WORK ON A SINGLE TASK PER ITERATION
- DO NOT skip ahead to later phases
- If a task depends on incomplete prerequisite, note it and move to next available task
- When ALL tasks have `"complete": true`, output <promise>COMPLETE</promise>

## Reference Files

Essential reads before starting:
- CLAUDE.md - Master design document
- scripts/data/GodTrait.gd - Data class pattern (NOTE: named GodTrait, not Trait)
- scripts/systems/traits/TraitManager.gd - System manager pattern
- scripts/systems/core/SystemRegistry.gd - Registration pattern
- data/traits.json - JSON data pattern
- tests/unit/test_god_data.gd - Test file pattern

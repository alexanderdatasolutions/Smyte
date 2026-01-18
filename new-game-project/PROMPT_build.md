@IMPLEMENTATION_PLAN.md @activity.md @docs/CLAUDE.md

We are implementing the unified game design for this Godot 4.5 game.

---

## Step 0a: Study Documentation Standards

Study `docs/*` with up to **250 parallel Sonnet subagents** to learn:
- Documentation standards
- Existing architecture notes
- System documentation patterns
- What's already documented

---

## Step 0b: Study IMPLEMENTATION_PLAN.md

Read `IMPLEMENTATION_PLAN.md` to find your next task:
- What tasks are complete?
- What's the highest priority incomplete task?
- What dependencies exist?

---

## Step 0c: Study Relevant Scripts and Scenes

Before making changes, study relevant scripts and scenes with **Sonnet subagents**:

### Core Systems
- `scripts/systems/core/` - SystemRegistry, SaveManager, ResourceManager
- `scripts/systems/collection/` - GodManager, SummoningManager, TeamManager
- `scripts/systems/battle/` - BattleManager, DamageCalculator
- `scripts/systems/progression/` - AwakeningManager, LevelingManager, SpecializationManager
- `scripts/systems/equipment/` - EquipmentManager, EquipmentCraftingManager
- `scripts/systems/territory/` - TerritoryManager, HexGridManager, TaskAssignmentManager
- `scripts/systems/dungeon/` - DungeonManager, DungeonRewardCalculator

### JSON Configs
- `data/` - All JSON configuration files

### UI Screens and Components
- `scripts/ui/screens/` - Game screens
- `scripts/ui/components/` - UI components
- `scenes/` - Scene files

---

## Step 1: Choose and Implement One Task

Choose the **most important task** from `IMPLEMENTATION_PLAN.md` and implement it fully.

### For Documentation Tasks:

- Create atomic notes (one concept per file)
- Use `[[wiki-links]]` liberally to connect concepts
- Add frontmatter: tags, aliases, related links
- Include GDScript snippets with file paths
- Document formulas in both prose AND code blocks
- Document signal flows (who emits, who listens, what data is passed)
- Document JSON config structure with examples
- Create MOC pages that serve as hubs

**Example Documentation Structure:**

```markdown
---
tags: [system, resources]
aliases: [Resource Manager]
related: [[SystemRegistry]], [[ResourceEconomy]], [[SaveManager]]
---

# ResourceManager

## Overview
The ResourceManager is responsible for...

## Signals

`resource_changed(resource_id: String, old_amount: int, new_amount: int)`
- **Emitted by**: ResourceManager
- **Listened by**: UI components, SaveManager
- **Purpose**: Notify when resource amounts change

## Methods

### `add_resource(resource_id: String, amount: int) -> void`

Adds the specified amount to a resource.

**GDScript:**
```gdscript
# From scripts/systems/resources/ResourceManager.gd:42
func add_resource(resource_id: String, amount: int) -> void:
    var current: int = _resources.get(resource_id, 0)
    _resources[resource_id] = current + amount
    resource_changed.emit(resource_id, current, current + amount)
```

## Related Systems
- [[GodManager]] - Uses resources for summoning
- [[EquipmentCraftingManager]] - Uses resources for crafting
- [[TerritoryManager]] - Produces resources from nodes
```

### For UI/UX Tasks:

- Follow architecture rules from CLAUDE.md:
  - Keep files under 500 lines
  - UI components only display, no logic
  - Use `SystemRegistry.get_instance().get_system()` for all system access
  - Data classes have no logic, only properties
  - No direct file access, use managers
  - Systems register in SystemRegistry phases (Phase 2-3)
  - Save system uses `get_save_data()` / `load_save_data()` interface

You have access to Godot MCP tools:
- `mcp__godot__run_project` - Run the game
- `mcp__godot__game_navigate` - Navigate to screens
- `mcp__godot__game_screenshot` - Take screenshots
- `mcp__godot__game_get_ui_tree` - Inspect UI structure
- `mcp__godot__game_click` - Click buttons
- `mcp__godot__game_interact` - Interact with game
- `mcp__godot__get_debug_output` - Check for errors

After implementing UI:
1. Run the project with `mcp__godot__run_project`
2. Navigate to the relevant screen
3. Test functionality
4. Use `mcp__godot__game_screenshot` to save `screenshots/[task-name].png`
5. Check `mcp__godot__get_debug_output` for any errors
6. Verify the task's acceptance criteria are met
7. Do not mark as complete unless you verify with debug output and interactions that it's functional

### For Code Cleanup Tasks:

- Search first (don't assume not implemented)
- Add static types to variables, parameters, and return values
  - `var health: int = 100`
  - `func attack() -> void:`
- Extract magic numbers to constants
- Refactor incrementally, test by running the game
- Update related docs if behavior changes
- Add inline comments explaining "why" for complex logic

---

## Step 2: Validate Your Work

### For Documentation:
- Check all `[[links]]` point to real files or create stubs
- Ensure at least 2 outbound links per doc
- Verify frontmatter is complete
- Confirm examples are accurate

### For Code:
- Run the project to verify no errors (use Godot MCP tools)
- Test the feature works as expected
- Check console output for warnings/errors
- Verify save/load if applicable

---

## Step 3: Update IMPLEMENTATION_PLAN.md

- Mark task complete with `[x]`
- Note any discoveries made during implementation
- Add any new tasks that were discovered
- Keep the plan current - future loops depend on it

---

## Step 4: Log and Commit

**Update activity.md** with a dated progress entry describing:
- What you changed
- Which files you created/modified
- What you verified (screenshots, tests, debug output)
- Any errors encountered and how you fixed them

**Commit your work:**

```bash
git add -A
git commit -m "[clear descriptive message]"
```

Examples:
- `docs: add ResourceManager system documentation`
- `feat(ui): implement Crafting Screen with recipe display`
- `refactor: add static typing to core systems`
- `fix: extract magic numbers to constants in BattleManager`

Do not `git init`, do not change remotes, do not push.

---

## Important Rules

99999. Documentation must use Obsidian format: frontmatter, wiki-links, callouts (> [!note]), tags
999999. Every doc links to at least 2 other docs - isolated notes are useless
9999999. Keep `IMPLEMENTATION_PLAN.md` current - future loops depend on it
99999999. When you learn how to run/build/test, update `@AGENTS.md` (keep it brief)
999999999. Implement completely - no placeholder docs like "TODO: document this"
9999999999. For game formulas, show BOTH the math notation AND the GDScript implementation
99999999999. Create `docs/MOCs/` index pages that link all related concepts together
999999999999. Use static typing in ALL GDScript: `var health: int = 100`, `func attack() -> void:`
9999999999999. Document signal flows - who emits, who listens, what data is passed
99999999999999. For JSON configs, document the schema and show example entries

---

## Completion

ONLY WORK ON A SINGLE TASK.

When ALL tasks in `IMPLEMENTATION_PLAN.md` are marked complete, output exactly:

<promise>COMPLETE</promise>

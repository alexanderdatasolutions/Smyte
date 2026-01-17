# Battle Screen Implementation Plan

## Overview
Build a complete Summoners War-style battle screen with turn-based combat, polished UI, and visual feedback.

**Reference:** docs/CLAUDE.md, docs/STAT_BALANCE_GUIDE.md

---

## Task List

```json
[
  {
    "category": "setup",
    "description": "Create BattleUnitCard component with portrait and stats",
    "steps": [
      "Create scripts/ui/battle/BattleUnitCard.gd",
      "Add portrait display from source_god",
      "Add HP bar with current/max display",
      "Add level display",
      "Add turn order indicator",
      "Create matching BattleUnitCard.tscn scene"
    ],
    "passes": true
  },
  {
    "category": "feature",
    "description": "Add status effect icons to BattleUnitCard",
    "steps": [
      "Create status icon container in BattleUnitCard",
      "Load status effect icons from BattleUnit.status_effects",
      "Display stacks for stackable effects",
      "Add tooltips showing effect details on hover"
    ],
    "passes": true
  },
  {
    "category": "feature",
    "description": "Create AbilityBar component for skill selection",
    "steps": [
      "Create scripts/ui/battle/AbilityBar.gd",
      "Display 4 skill buttons from active unit",
      "Show cooldown overlays when skill is on cooldown",
      "Show skill names and descriptions",
      "Emit ability_selected signal with skill index",
      "Create matching AbilityBar.tscn scene"
    ],
    "passes": false
  },
  {
    "category": "feature",
    "description": "Integrate BattleUnitCard into BattleScreen",
    "steps": [
      "Update BattleScreen._populate_battle_ui() to use BattleUnitCard",
      "Replace simple enemy cards with BattleUnitCard",
      "Connect to BattleCoordinator.unit_turn_ready signal",
      "Highlight active unit's card during their turn"
    ],
    "passes": false
  },
  {
    "category": "feature",
    "description": "Add AbilityBar to BattleScreen",
    "steps": [
      "Add AbilityBar container to BattleScreen.tscn",
      "Show AbilityBar when unit_turn_ready fires",
      "Populate with active unit's skills",
      "Hide when turn is not active"
    ],
    "passes": false
  },
  {
    "category": "feature",
    "description": "Connect ability selection to battle execution",
    "steps": [
      "Connect AbilityBar.ability_selected to BattleScreen handler",
      "Call BattleCoordinator.execute_player_action with skill index",
      "Update unit cards after action executes",
      "Show damage numbers or effects briefly"
    ],
    "passes": false
  },
  {
    "category": "feature",
    "description": "Implement turn order visualization",
    "steps": [
      "Add turn order bar to BattleScreen showing upcoming turns",
      "Display small unit portraits in turn order",
      "Update as turns progress",
      "Highlight current unit's portrait"
    ],
    "passes": false
  },
  {
    "category": "feature",
    "description": "Add battle progression and completion",
    "steps": [
      "Listen to BattleCoordinator.battle_ended signal",
      "Show victory/defeat screen with rewards",
      "Update player resources based on rewards",
      "Add 'Return to Map' button that navigates back"
    ],
    "passes": false
  },
  {
    "category": "testing",
    "description": "Test complete battle flow end-to-end",
    "steps": [
      "Start battle from hex node capture",
      "Verify all unit cards show portraits, HP, level",
      "Select abilities and execute turns",
      "Verify damage calculation and HP updates",
      "Complete battle to victory or defeat",
      "Verify rewards screen and return to map"
    ],
    "passes": false
  },
  {
    "category": "testing",
    "description": "Verify battle screen with Godot MCP",
    "steps": [
      "Run the project with mcp__godot__run_project",
      "Navigate to hex territory and initiate capture",
      "Use game_get_ui_tree to verify BattleScreen structure",
      "Use game_screenshot to capture battle screen state",
      "Verify all UI elements are visible and functional"
    ],
    "passes": false
  }
]
```

---

## Agent Instructions

1. Read `activity.md` first to understand current state
2. Find next task with `"passes": false`
3. Complete all steps for that task
4. Use Godot MCP tools to verify changes:
   - mcp__godot__run_project to run the game
   - mcp__godot__game_navigate to navigate screens
   - mcp__godot__game_screenshot to capture visual state
   - mcp__godot__game_get_ui_tree to inspect UI structure
5. Update task to `"passes": true`
6. Log completion in `activity.md`
7. Make one git commit for that task
8. Repeat until all tasks pass

**Important:**
- Only modify the `passes` field in tasks
- Do not remove or rewrite tasks
- Follow CLAUDE.md architecture rules strictly
- Use GodCardFactory for god portraits
- Use SystemRegistry for all system access
- Keep UI components under 500 lines

---

## Completion Criteria
All tasks marked with `"passes": true`

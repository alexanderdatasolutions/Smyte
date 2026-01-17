# Node Detail Screen Overhaul - Implementation Plan

## Overview
Create a mobile-friendly node management interface that clearly shows garrison, workers, tasks, and god selection.

**Reference:** docs/CLAUDE.md, docs/COMMON_ISSUES.md

### Current Issues
- WorkerAssignmentPanel uses per-node worker data that doesn't exist
- TaskAssignmentManager works at TERRITORY level, not per-node
- No visibility into garrison combat power
- No clear indication of worker slots and their current tasks
- God selection is cumbersome for mobile

### New Approach
**NodeDetailScreen** will show:
1. **Garrison Section** - Assigned combat gods and total combat power
2. **Worker Section** - Open slots, assigned workers, current tasks, output rates
3. **Mobile God Selection** - Grid of god portraits organized by affinity color

---

## Task List

```json
[
  {
    "category": "component",
    "description": "Create GodSelectionGrid component for mobile-friendly god selection",
    "steps": [
      "Create scripts/ui/territory/GodSelectionGrid.gd",
      "Build grid layout (5-6 gods per row, 80x100px cards)",
      "Show portrait, name, level, affinity color border",
      "Add filter for available/assigned gods",
      "Emit god_selected(god: God) signal on tap",
      "Make scrollable for many gods"
    ],
    "passes": true
  },
  {
    "category": "component",
    "description": "Create GarrisonDisplay component showing combat power",
    "steps": [
      "Create scripts/ui/territory/GarrisonDisplay.gd",
      "Display garrison gods horizontally (small cards)",
      "Show total combat power (sum of god combat stats)",
      "Add 'Set Garrison' button to open god selection",
      "Show 'Empty Garrison' state when none assigned",
      "Each card shows: portrait, level, combat power"
    ],
    "passes": false
  },
  {
    "category": "component",
    "description": "Create WorkerSlotDisplay component for worker management",
    "steps": [
      "Create scripts/ui/territory/WorkerSlotDisplay.gd",
      "Show slots based on node tier (tier = max slots)",
      "Empty slots: show '+' icon (60x60px tap target)",
      "Filled slots: show god portrait, task name, output rate",
      "Tapping empty slot opens god selection",
      "Tapping filled slot shows option to unassign"
    ],
    "passes": false
  },
  {
    "category": "system",
    "description": "Create NodeTaskCalculator system for output calculations",
    "steps": [
      "Create scripts/systems/territory/NodeTaskCalculator.gd",
      "Implement get_task_for_node(node: HexNode) -> task name",
      "Implement calculate_output_rate(node: HexNode, god: God) -> rate/hour",
      "Mine nodes: ore per hour, Forest: wood, Coast: fish",
      "Output scales: node tier × worker god level × affinity bonus",
      "Affinity bonus: matching affinity = 1.5x output",
      "Register in SystemRegistry Phase 3"
    ],
    "passes": false
  },
  {
    "category": "data",
    "description": "Add garrison fields to HexNode data model",
    "steps": [
      "Add garrison_god_ids: Array[String] = [] to HexNode.gd",
      "Implement get_garrison_combat_power() -> int method",
      "Sum combat power of assigned garrison gods",
      "Add garrison to save/load serialization",
      "Write unit test for garrison save/load"
    ],
    "passes": false
  },
  {
    "category": "screen",
    "description": "Create NodeDetailScreen with garrison and worker sections",
    "steps": [
      "Create scripts/ui/screens/NodeDetailScreen.gd",
      "Build fullscreen overlay with dark background",
      "Header: node name, type icon, tier, close button",
      "Add GarrisonSection (uses GarrisonDisplay)",
      "Add WorkerSection (uses WorkerSlotDisplay)",
      "Make scrollable if content exceeds screen",
      "Implement _setup_fullscreen() for Control sizing"
    ],
    "passes": false
  },
  {
    "category": "integration",
    "description": "Integrate NodeDetailScreen into HexTerritoryScreen",
    "steps": [
      "Create NodeDetailScreen instance in HexTerritoryScreen",
      "Connect hex tile click to open NodeDetailScreen (replace old panel)",
      "Pass selected HexNode to detail screen",
      "Handle close signal to return to hex map",
      "Remove or disable old WorkerAssignmentPanel"
    ],
    "passes": false
  },
  {
    "category": "feature",
    "description": "Add god affinity color coding to selection grid",
    "steps": [
      "Update GodSelectionGrid to show colored borders",
      "Color mapping: Fire=Red, Water=Blue, Earth=Brown, Air=LightBlue, Light=Gold, Dark=Purple",
      "Use God.affinity field for color lookup",
      "Display affinity icon or color indicator",
      "Ensure colors are visible without text labels"
    ],
    "passes": false
  },
  {
    "category": "feature",
    "description": "Display task output rates in worker slots",
    "steps": [
      "Update WorkerSlotDisplay to show output per hour",
      "Display format: 'Mining: +12 ore/hr' or 'Empty Slot'",
      "Use NodeTaskCalculator to compute rates",
      "Show affinity bonus indicator (star icon if active)",
      "Update display when god assignment changes"
    ],
    "passes": false
  },
  {
    "category": "polish",
    "description": "Mobile UX polish and testing",
    "steps": [
      "Ensure all tap targets are 60x60px minimum",
      "Add smooth transitions (fade in/out for detail screen)",
      "Add loading states for god selection grid",
      "Add error handling for missing gods/data",
      "Test complete flow: map → detail → garrison → workers → map",
      "Take screenshots of each major screen state"
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
   - mcp__godot__game_navigate to hex territory screen
   - mcp__godot__game_screenshot to capture screenshots/node-detail-[task].png
   - mcp__godot__game_get_ui_tree to inspect UI structure
   - mcp__godot__get_debug_output to check for errors
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
- Ensure all Control nodes have _setup_fullscreen() (see COMMON_ISSUES.md)
- Do NOT use per-node worker APIs (TaskAssignmentManager is territory-level)

**Architecture Notes:**
- Garrison is per-node (for combat defense)
- Workers are territory-level (but show which can help this node)
- Tasks/output are node-specific based on type and tier

---

## Completion Criteria
All tasks marked with `"passes": true`, then output `<promise>COMPLETE</promise>`

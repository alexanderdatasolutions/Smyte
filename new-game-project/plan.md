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
    "passes": true
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
    "passes": true
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
    "passes": true
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
    "passes": true
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
    "passes": true
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
    "passes": true
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
    "passes": true
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
    "passes": true
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
    "passes": true
  },
  {
    "category": "component",
    "description": "Create GodSelectionPanel - left-sliding overlay for god selection",
    "steps": [
      "Create scripts/ui/territory/GodSelectionPanel.gd",
      "Extend Control, use _setup_fullscreen() like TerritoryOverviewScreen",
      "Position panel to slide in from LEFT (TerritoryOverviewScreen is RIGHT)",
      "Include GodSelectionGrid component for god display",
      "Add filters: All/Worker/Garrison, Affinity filters",
      "Add close button and back gesture support",
      "Emit god_selected(god: God) signal on selection",
      "Add slide-in/slide-out animation (Tween)"
    ],
    "passes": true
  },
  {
    "category": "refactor",
    "description": "Add garrison and worker slot boxes directly to TerritoryOverviewScreen node cards",
    "steps": [
      "Remove 'View Details' button from node cards (NodeDetailScreen is obsolete)",
      "Add Garrison section to each node card with visual slot boxes",
      "Add Worker section to each node card with visual slot boxes",
      "Empty slots: show gray Panel with '+' icon (60x60px tap target)",
      "Filled slots: show god portrait thumbnail Panel (60x60px)",
      "Slot count: garrison = 4 slots, workers = node.tier slots",
      "Each slot emits slot_tapped(node, slot_type, slot_index) when clicked",
      "Make node cards taller/scrollable to fit all content"
    ],
    "passes": false
  },
  {
    "category": "integration",
    "description": "Connect slot taps to GodSelectionPanel in HexTerritoryScreen",
    "steps": [
      "Create GodSelectionPanel instance in HexTerritoryScreen",
      "Connect TerritoryOverviewScreen.slot_tapped signal",
      "When slot tapped, show GodSelectionPanel with slide-in animation from LEFT",
      "Pass context: which node, slot type (worker/garrison), slot index",
      "When god selected, assign to correct slot in node data (HexNode.worker_god_ids or garrison_god_ids)",
      "Refresh TerritoryOverviewScreen to show updated slots with god portraits",
      "Close GodSelectionPanel with slide-out animation",
      "Remove/deprecate NodeDetailScreen since TerritoryOverviewScreen now has everything"
    ],
    "passes": false
  },
  {
    "category": "data",
    "description": "Fix worker and garrison persistence in HexNode",
    "steps": [
      "Verify garrison_god_ids is in HexNode save/load (should already exist)",
      "Add worker_god_ids: Array[String] to HexNode.gd",
      "Update HexNode.to_dict() to include worker_god_ids",
      "Update HexNode constructor to load worker_god_ids from dict",
      "Update TerritoryManager save/load to persist node assignments",
      "Write unit test to verify worker/garrison save/load"
    ],
    "passes": false
  },
  {
    "category": "feature",
    "description": "Optional: Show enemy garrison before node capture",
    "steps": [
      "Add enemy_garrison_god_ids: Array[String] to HexNode.gd",
      "When node is enemy-controlled, show locked garrison slots",
      "Display enemy garrison as red-bordered god portraits (no remove option)",
      "On capture, clear enemy_garrison_god_ids",
      "This gives player intel on node difficulty before attacking"
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

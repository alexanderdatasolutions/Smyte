# God Selection Panel Integration - Implementation Plan

## Overview
Create a left-sliding god selection panel that opens when you tap worker/garrison slots in the territory overview screen.

**Reference:** docs/CLAUDE.md, docs/COMMON_ISSUES.md

## Current State
- ✅ TerritoryOverviewScreen has visual slot boxes (garrison + worker)
- ✅ GodSelectionGrid component exists for showing god portraits
- ✅ NodeDetailScreen exists separately
- ✅ Connection between slot taps and god selection WORKS
- ✅ Left-sliding panel for god selection WORKS

## Goal
**Simple UX Flow:**
1. Tap hex tile → TerritoryOverviewScreen slides in from RIGHT (already works)
2. Tap empty slot (+) → GodSelectionPanel slides in from LEFT
3. Select god → Panel closes, slot updates with portrait
4. Tap filled slot → Option to remove god OR open GodSelectionPanel to replace

---

## Task List

```json
[
  {
    "category": "component",
    "description": "Create GodSelectionPanel as left-sliding overlay",
    "steps": [
      "Create scripts/ui/territory/GodSelectionPanel.gd",
      "Extend Control with _setup_fullscreen() for sizing",
      "Position at LEFT of screen (x offset starts at -viewport_width)",
      "Add dark semi-transparent background",
      "Add header: title 'Select God' + close button (60x60px)",
      "Include GodSelectionGrid component in scrollable area",
      "Add bottom bar with 'Cancel' button",
      "Emit god_selected(god: God) and cancelled() signals",
      "NOTE: Panel can take up MORE screen width if needed - make it big!"
    ],
    "passes": true
  },
  {
    "category": "animation",
    "description": "Add slide-in/slide-out animations to GodSelectionPanel",
    "steps": [
      "Create show_panel() method with Tween animation",
      "Slide from x = -viewport_width to x = 0 (0.3s ease out)",
      "Create hide_panel() method with Tween animation",
      "Slide from x = 0 to x = -viewport_width (0.2s ease in)",
      "Set visible = false after slide-out completes",
      "Add modulate fade for smooth appearance"
    ],
    "passes": true
  },
  {
    "category": "integration",
    "description": "Wire GodSelectionPanel to TerritoryOverviewScreen slot taps",
    "steps": [
      "Find HexTerritoryScreen.gd (the parent that contains TerritoryOverviewScreen)",
      "Create GodSelectionPanel instance in HexTerritoryScreen",
      "Connect TerritoryOverviewScreen.slot_tapped signal",
      "On slot_tapped: call GodSelectionPanel.show_panel(node, slot_type, slot_index)",
      "Pass excluded god IDs (gods already in garrison/workers)",
      "On god_selected: update node.garrison or node.assigned_workers array",
      "Call TerritoryOverviewScreen._refresh_display() to update slot visuals",
      "On cancelled: just hide panel"
    ],
    "passes": true
  },
  {
    "category": "feature",
    "description": "Add remove god functionality for filled slots",
    "steps": [
      "When filled slot is tapped, show confirmation 'Remove [God Name]?' popup",
      "Create simple popup with 'Remove' and 'Cancel' buttons",
      "On Remove: remove god_id from node.garrison or node.assigned_workers",
      "Refresh TerritoryOverviewScreen display",
      "Alternative: filled slot tap could also open GodSelectionPanel to replace"
    ],
    "passes": true
  },
  {
    "category": "data",
    "description": "Fix garrison and worker persistence in HexNode save/load",
    "steps": [
      "Check HexNode.gd - verify garrison field exists",
      "Check HexNode.gd - verify assigned_workers field exists",
      "Check HexNode.to_dict() includes both arrays",
      "Check HexNode constructor loads both from dict",
      "Test: assign gods to node, save game, reload, verify they persist",
      "If missing, add to save/load serialization"
    ],
    "passes": true
  },
  {
    "category": "polish",
    "description": "Mobile UX improvements and testing",
    "steps": [
      "Ensure GodSelectionPanel close button is 60x60px minimum",
      "Test on mobile: tap slot → panel slides in smoothly",
      "Test: select god → panel closes, slot shows portrait",
      "Test: tap filled slot → can remove god",
      "Test: god portraits load correctly with element colors",
      "Add loading state while CollectionManager fetches gods"
    ],
    "passes": true
  }
]
```

---

## Agent Instructions

1. Read `activity.md` to see current state
2. Find next task with `"passes": false`
3. Complete all steps in that task
4. Test using Godot MCP tools:
   - `mcp__godot__run_project` to launch game
   - `mcp__godot__game_navigate` to get to hex territory screen
   - `mcp__godot__game_click` to test tapping slots
   - `mcp__godot__game_screenshot` to capture state
   - `mcp__godot__get_debug_output` to check for errors
5. Mark task `"passes": true`
6. Log in `activity.md`
7. Make git commit
8. Repeat until all tasks pass

**Critical Rules:**
- Only modify the `passes` field in tasks
- Do NOT remove or rewrite task content
- Follow CLAUDE.md architecture strictly
- Use SystemRegistry for all system access
- Keep files under 500 lines
- All Control nodes need `_setup_fullscreen()` if child of Node2D
- TerritoryOverviewScreen already has slot_tapped signal - just connect to it

**File Locations:**
- TerritoryOverviewScreen: `scripts/ui/territory/TerritoryOverviewScreen.gd`
- GodSelectionGrid: `scripts/ui/territory/GodSelectionGrid.gd` (already exists)
- HexTerritoryScreen: Find with grep - it's the parent screen
- HexNode data: `scripts/data/HexNode.gd`

---

## Architecture Notes

**TerritoryOverviewScreen** (RIGHT panel):
- Shows all owned nodes
- Each node card has garrison slots (4) + worker slots (tier-based)
- Emits `slot_tapped(node, slot_type, slot_index)` signal

**GodSelectionPanel** (LEFT panel):
- Slides in when slot tapped
- Shows GodSelectionGrid with available gods
- Filters out gods already assigned
- Emits `god_selected(god)` or `cancelled()`

**HexTerritoryScreen** (orchestrator):
- Contains both panels
- Listens to slot_tapped
- Updates node data when god selected
- Refreshes TerritoryOverviewScreen display

**Data Flow:**
1. User taps slot → TerritoryOverviewScreen emits slot_tapped
2. HexTerritoryScreen shows GodSelectionPanel
3. User selects god → GodSelectionPanel emits god_selected
4. HexTerritoryScreen updates node.garrison or node.assigned_workers
5. HexTerritoryScreen calls TerritoryOverviewScreen._refresh_display()

---

## Completion Criteria
All tasks marked `"passes": true`, then output `<promise>COMPLETE</promise>`


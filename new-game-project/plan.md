# AFK Resource Generation System - Implementation Plan

## Overview
Implement the AFK resource generation system so that gods assigned to hex nodes actually produce resources over time. This includes production tracking, offline gains calculation, and UI for claiming rewards.

**Reference:** `docs/CLAUDE.md` (Section IV: Resource Economy, AFK Strategy)

---

## Task List

```json
[
  {
    "category": "audit",
    "description": "Audit existing production systems and identify gaps",
    "steps": [
      "Review TerritoryManager for production tracking",
      "Review TaskAssignmentManager for worker efficiency calculations",
      "Review NodeProductionInfo for production type mapping",
      "Check if production rates are actually being calculated",
      "Check if resources are being generated over time",
      "Identify what's missing to make AFK production work"
    ],
    "passes": false
  },
  {
    "category": "systems",
    "description": "Implement ProductionManager for resource generation",
    "steps": [
      "Create scripts/systems/territory/ProductionManager.gd",
      "Load production_rates.json (rates per node type per hour)",
      "Implement calculate_production_rate(node, workers) method",
      "Apply worker efficiency bonuses (spec match, trait bonuses)",
      "Apply connected node bonuses (+10/20/30% for 2/3/4+ connections)",
      "Track last_production_update timestamp per node",
      "Implement process_production(delta_time) to generate resources"
    ],
    "passes": false
  },
  {
    "category": "data",
    "description": "Create production_rates.json configuration",
    "steps": [
      "Create data/production_rates.json",
      "Define base hourly rates for each node type (mine, forest, coast, etc.)",
      "Define output resources per node type (e.g., mine → iron_ore, copper_ore, stone)",
      "Add tier multipliers (Tier 1 = 1x, Tier 2 = 2x, Tier 3 = 4x, Tier 4 = 8x, Tier 5 = 16x)",
      "Add efficiency formulas for spec/trait matching",
      "Document connected bonus calculations"
    ],
    "passes": false
  },
  {
    "category": "systems",
    "description": "Implement offline gains calculation",
    "steps": [
      "Add last_login_timestamp to save data",
      "On game load, calculate time_elapsed since last login",
      "Cap offline gains at 8 hours (encourage daily login)",
      "Calculate production for all controlled nodes",
      "Store pending_offline_rewards in memory",
      "Emit offline_rewards_ready signal for UI"
    ],
    "passes": false
  },
  {
    "category": "ui",
    "description": "Create OfflineRewardsPanel UI",
    "steps": [
      "Create scripts/ui/screens/OfflineRewardsPanel.gd",
      "Show time away (HH:MM:SS format)",
      "Display all resources gained (grouped by category)",
      "Show total production rate per hour",
      "Add 'Claim All' button",
      "Add to ResourceManager when claimed",
      "Show panel automatically on game start if rewards > 0"
    ],
    "passes": false
  },
  {
    "category": "ui",
    "description": "Add production display to NodeInfoPanel",
    "steps": [
      "Add 'Production' section to NodeInfoPanel",
      "Show current hourly production rate",
      "Show resources being generated (with icons/amounts)",
      "Show efficiency bonuses applied (spec match, connections)",
      "Update in real-time when workers change",
      "Add tooltip showing bonus breakdown"
    ],
    "passes": false
  },
  {
    "category": "integration",
    "description": "Integrate ProductionManager with TerritoryManager",
    "steps": [
      "Call ProductionManager.process_production() every second",
      "Update node.resources_pending with generated amounts",
      "Emit production_updated signal when resources increment",
      "Add claim_production(node_id) method to collect resources",
      "Transfer from node.resources_pending to ResourceManager",
      "Save production state with last_production_update timestamps"
    ],
    "passes": false
  },
  {
    "category": "ui",
    "description": "Add production indicators to HexMapView",
    "steps": [
      "Add resource icon badges to hex tiles with workers",
      "Show production rate as floating text above active nodes",
      "Add pulsing glow effect on nodes generating resources",
      "Show pending resources count on tile (e.g., '+24 ore')",
      "Add 'Collect All' button to claim all pending production",
      "Update badges in real-time as production accumulates"
    ],
    "passes": false
  },
  {
    "category": "testing",
    "description": "Test production system end-to-end",
    "steps": [
      "Assign workers to multiple node types (mine, forest, coast)",
      "Wait 10 seconds and verify resources are generated",
      "Check production rates match expected calculations",
      "Test efficiency bonuses (spec match, connections)",
      "Test offline gains (save, close, reopen)",
      "Verify cap at 8 hours offline",
      "Test claim functionality adds to ResourceManager"
    ],
    "passes": false
  },
  {
    "category": "testing",
    "description": "Verify save/load persistence for production",
    "steps": [
      "Assign workers and let production accumulate",
      "Save game",
      "Close and reload game",
      "Verify pending production persisted",
      "Verify last_production_update timestamps saved",
      "Verify production resumes correctly after load",
      "Test offline rewards panel appears with correct amounts"
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
4. Verify in Godot using MCP tools (run, navigate, screenshot, debug output)
5. Update task to `"passes": true`
6. Log completion in `activity.md`
7. Repeat until all tasks pass

**Important:** Do not mark as passed unless you verify with debug output and button presses that it's functional and works.

---

## Completion Criteria
All tasks marked with `"passes": true`

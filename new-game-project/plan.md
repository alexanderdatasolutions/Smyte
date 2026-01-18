# AFK Resource Generation System - Implementation Plan

## Overview

Implement passive resource generation for hex territory nodes with assigned workers. Players should earn resources over time (including offline) based on node type, worker count, worker stats, and bonuses. This connects the existing worker assignment system to actual resource accumulation.

**Reference:** `docs/CLAUDE.md` (Section IV: Resource Economy, Section II: Hex Territory System)

**Current State (Detailed Audit Complete):**
- ✅ Production calculation formulas FULLY IMPLEMENTED in TerritoryProductionManager.gd (lines 211-364)
- ✅ Worker efficiency, connection bonuses, upgrade bonuses all calculate correctly
- ✅ base_production defined for all 79 nodes in hex_nodes.json
- ✅ Task system has offline progress (TaskAssignmentManager lines 366-428) but for tasks, not passive production
- ❌ HexNode lacks timestamp tracking (no last_production_tick, accumulated_resources fields)
- ❌ No time-based accumulation loop for hex nodes
- ❌ No offline gains calculation for hex nodes (exists only for old Territory system)
- ❌ No claim/collect methods implemented
- ❌ UI shows production RATES but not accumulated resources or claim buttons

**Goal**: Connect existing production formulas to time-based accumulation and add claim functionality.

---

## Task List

```json
[
  {
    "category": "audit",
    "description": "Document current production system state",
    "steps": [
      "Read comprehensive audit analysis completed by Explore agent",
      "Verify base_production exists in hex_nodes.json (CONFIRMED: all 79 nodes)",
      "Verify production formulas work (CONFIRMED: TerritoryProductionManager lines 211-364)",
      "Confirm TerritoryManager stub methods exist (CONFIRMED: lines 245-252)",
      "Document what exists vs what's missing (COMPLETED: see Overview)"
    ],
    "passes": true
  },
  {
    "category": "data",
    "description": "Create production_rates.json configuration",
    "steps": [
      "Define base production rates for each node type (mine, forest, coast, etc.)",
      "Define worker efficiency multipliers (1 worker = 100%, 2 = 180%, 3 = 240%)",
      "Define production level scaling (level 1-5 = 1x to 2x multiplier)",
      "Define connected node bonuses (+10%, +20%, +30%)",
      "Define distance penalty formula (5% per hex from base)",
      "Add production tick interval (default 3600 seconds = 1 hour)"
    ],
    "passes": false
  },
  {
    "category": "core",
    "description": "Create ProductionManager autoload system",
    "steps": [
      "Create scripts/systems/production/ProductionManager.gd",
      "Add to SystemRegistry Phase 5 (after TerritoryManager)",
      "Implement calculate_node_production_rate() using formulas from config",
      "Implement get_all_pending_resources() to sum across all nodes",
      "Add save_state() and load_state() methods",
      "Add _process() or Timer for production ticks (optional, can be on-demand)",
      "Keep under 500 lines"
    ],
    "passes": false
  },
  {
    "category": "core",
    "description": "Add production tracking fields to HexNode",
    "steps": [
      "Add accumulated_resources: Dictionary = {} field",
      "Add last_collection_timestamp: float = 0.0 field",
      "Add current_production_rate: Dictionary = {} field (cached calculation)",
      "Update to_dict() to save production fields",
      "Update from_dict() to load production fields",
      "Add calculate_production_rate() method that calls ProductionManager"
    ],
    "passes": false
  },
  {
    "category": "core",
    "description": "Implement production calculation formulas",
    "steps": [
      "In ProductionManager, create _calculate_worker_efficiency(worker_count)",
      "Create _calculate_production_level_bonus(production_level)",
      "Create _get_connected_bonus(node_id) by calling TerritoryManager",
      "Create _get_distance_penalty(node_id) by calling TerritoryManager",
      "Combine all multipliers in calculate_node_production_rate()",
      "Return Dictionary {resource_id: amount_per_hour}"
    ],
    "passes": false
  },
  {
    "category": "core",
    "description": "Implement resource accumulation system",
    "steps": [
      "In ProductionManager, create accumulate_production(node_id, elapsed_seconds)",
      "Calculate resources = production_rate * (elapsed_seconds / 3600)",
      "Add to node.accumulated_resources dictionary",
      "Create collect_node_production(node_id) to move accumulated to ResourceManager",
      "Create collect_all_production() to collect from all controlled nodes",
      "Emit signals on accumulation and collection"
    ],
    "passes": false
  },
  {
    "category": "core",
    "description": "Implement offline gains calculation",
    "steps": [
      "In ProductionManager, create calculate_offline_production()",
      "Get offline duration from SaveManager timestamps",
      "Cap offline duration at 24 hours (configurable)",
      "For each controlled node with workers, accumulate production",
      "Store results in offline_gains: Dictionary",
      "Create method to show/claim offline gains"
    ],
    "passes": false
  },
  {
    "category": "integration",
    "description": "Integrate ProductionManager with SaveManager",
    "steps": [
      "Update SaveManager to call ProductionManager.save_state()",
      "Store last_save_timestamp separately for production calculation",
      "On load, call ProductionManager.load_state()",
      "After load, call ProductionManager.calculate_offline_production()",
      "Ensure production state persists correctly"
    ],
    "passes": false
  },
  {
    "category": "integration",
    "description": "Connect TerritoryManager production methods",
    "steps": [
      "Update TerritoryManager.get_territory_resource_rate() to call ProductionManager",
      "Update get_pending_resources() to return accumulated resources",
      "Update collect_territory_resources() to call ProductionManager.collect_node_production()",
      "Update collect_all_resources() to call ProductionManager.collect_all_production()",
      "Remove stub implementations and add real logic"
    ],
    "passes": false
  },
  {
    "category": "integration",
    "description": "Update worker assignment to recalculate production",
    "steps": [
      "In TaskAssignmentManager, when worker assigned, call node.calculate_production_rate()",
      "When worker unassigned, recalculate production rate",
      "When worker completes specialization, recalculate rates for assigned nodes",
      "Emit production_rate_changed signal",
      "Update UI when rates change"
    ],
    "passes": false
  },
  {
    "category": "ui",
    "description": "Create OfflineGainsPopup screen",
    "steps": [
      "Create scripts/ui/screens/OfflineGainsPopup.gd",
      "Show offline duration in readable format (X hours Y minutes)",
      "Display resources earned while offline",
      "Add 'Collect' button that claims rewards via ProductionManager",
      "Auto-show on login if offline gains > 0",
      "Add animation for resource counting up"
    ],
    "passes": false
  },
  {
    "category": "ui",
    "description": "Update TerritoryInfoDisplayManager with real data",
    "steps": [
      "Remove hardcoded production values (lines 127-129)",
      "Call ProductionManager.calculate_node_production_rate() for real rates",
      "Display base production vs enhanced production correctly",
      "Show breakdown: base × workers × bonuses × level",
      "Update display when production rates change",
      "Show 'per hour' units clearly"
    ],
    "passes": false
  },
  {
    "category": "ui",
    "description": "Add pending resources display to territory UI",
    "steps": [
      "In HexMapView or NodeInfoPanel, add 'Pending Resources' section",
      "Show accumulated resources for selected node",
      "Show time since last collection",
      "Add 'Collect' button for individual node",
      "Update display every few seconds or on tick",
      "Show visual indicator when resources ready to collect"
    ],
    "passes": false
  },
  {
    "category": "ui",
    "description": "Create global 'Collect All' button for home screen",
    "steps": [
      "Add FloatingCollectButton.gd component",
      "Show total pending resources across all nodes",
      "Pulse/glow animation when resources available",
      "On click, call ProductionManager.collect_all_production()",
      "Show toast notification with resources claimed",
      "Hide button when no pending resources"
    ],
    "passes": false
  },
  {
    "category": "testing",
    "description": "Test production calculation formulas",
    "steps": [
      "Create test scene with 1 worker at basic mine node",
      "Verify base production matches hex_nodes.json",
      "Add 2nd worker, verify 180% efficiency",
      "Add 3rd worker, verify 240% efficiency",
      "Upgrade production level to 3, verify 1.4x multiplier",
      "Verify distance penalty applies correctly"
    ],
    "passes": false
  },
  {
    "category": "testing",
    "description": "Test resource accumulation over time",
    "steps": [
      "Assign workers to node, note current_production_rate",
      "Wait 60 seconds (or simulate elapsed time)",
      "Verify accumulated_resources increases correctly",
      "Collect resources, verify ResourceManager receives correct amounts",
      "Verify accumulated_resources resets to zero after collection",
      "Check last_collection_timestamp updates"
    ],
    "passes": false
  },
  {
    "category": "testing",
    "description": "Test offline gains calculation",
    "steps": [
      "Assign workers to multiple nodes",
      "Note production rates and timestamp",
      "Manually modify save file timestamp to 2 hours ago",
      "Reload game",
      "Verify offline gains popup appears",
      "Verify accumulated resources match 2 hours of production",
      "Verify 24-hour cap works (test with 48-hour offline time)"
    ],
    "passes": false
  },
  {
    "category": "testing",
    "description": "Test production rate updates on worker changes",
    "steps": [
      "View production rate with 1 worker",
      "Assign 2nd worker, verify rate increases immediately",
      "Unassign worker, verify rate decreases",
      "Check UI updates in real-time",
      "Verify NodeInfoPanel reflects changes",
      "Verify TerritoryInfoDisplayManager shows updated rates"
    ],
    "passes": false
  },
  {
    "category": "testing",
    "description": "Test UI displays and collect functionality",
    "steps": [
      "Open territory screen, verify production rates shown",
      "Wait for resources to accumulate",
      "Verify pending resources display updates",
      "Click 'Collect' button on individual node",
      "Verify resources added to ResourceManager",
      "Click 'Collect All' button, verify all nodes collected",
      "Verify offline gains popup shows on login"
    ],
    "passes": false
  },
  {
    "category": "polish",
    "description": "Add production notifications and feedback",
    "steps": [
      "Add toast notification when collecting resources",
      "Add sound effect for collection",
      "Add particle effect or animation on collect button",
      "Add badge/counter on collect button showing pending amount",
      "Add tutorial tooltip explaining AFK production",
      "Add settings option to disable auto-popup of offline gains"
    ],
    "passes": false
  },
  {
    "category": "documentation",
    "description": "Document production system architecture",
    "steps": [
      "Create docs/systems/ProductionSystem.md",
      "Document formula: base × worker_efficiency × production_level × connected_bonus × (1 - distance_penalty)",
      "Document offline gains calculation and 24-hour cap",
      "Document signal flow between ProductionManager, TerritoryManager, UI",
      "Add code examples for common operations",
      "Link to relevant CLAUDE.md sections"
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
4. Verify with Godot debug output, print statements, or running the game
5. **CRITICAL**: Do NOT mark task as passed unless you verify functionality works
6. Update task to `"passes": true` only after confirmation
7. Log completion in `activity.md` with:
   - Timestamp
   - Task completed
   - Files modified (with line numbers)
   - Verification method (e.g., "Tested by assigning workers and checking debug output")
8. Make one git commit per task with format: `feat(production): [task description]`
9. Do not git push (Ralph loop will handle this)
10. Repeat until all tasks pass

**Important Notes:**
- Only modify `passes` field in tasks. Do not rewrite or remove tasks.
- If you discover issues during implementation, add new tasks rather than changing existing ones.
- Keep each system under 500 lines per file.
- Follow GDScript 4.x static typing: `var health: int = 100`
- Test thoroughly before marking as passed.

---

## Formula Reference

Based on `docs/CLAUDE.md`:

**Production Rate Formula:**
```
resources_per_hour = base_production × worker_efficiency × production_level_multiplier × connected_bonus × (1 - distance_penalty)
```

**Worker Efficiency:**
- 1 worker = 100%
- 2 workers = 180%
- 3 workers = 240%

**Production Level:**
- Level 1 = 1.0x
- Level 2 = 1.2x
- Level 3 = 1.4x
- Level 4 = 1.6x
- Level 5 = 2.0x

**Connected Bonus:**
- 2-3 connected nodes = +10%
- 4-5 connected = +20%
- 6+ connected = +30%

**Distance Penalty:**
- 5% per hex from base (max 95% penalty)

**Specialization Bonus:**
- Matching spec for node type = +50% to +200% (from CLAUDE.md)

**Offline Gains:**
- Cap at 24 hours (configurable)
- Apply same formula × offline_hours

---

## Completion Criteria

All tasks marked with `"passes": true`

**Verification Checklist:**
- [ ] Workers assigned to nodes generate resources over time
- [ ] Production rates display correctly in UI
- [ ] Collecting resources adds them to ResourceManager
- [ ] Offline gains popup shows after absence
- [ ] Bonuses (workers, level, connected, distance) apply correctly
- [ ] Save/load preserves production state
- [ ] UI updates in real-time when rates change

---

## Notes

**Key Files:**
- `scripts/systems/production/ProductionManager.gd` (NEW)
- `data/production_rates.json` (NEW)
- `scripts/data/HexNode.gd` (MODIFY - add production fields)
- `scripts/systems/territory/TerritoryManager.gd` (MODIFY - connect to ProductionManager)
- `scripts/systems/tasks/TaskAssignmentManager.gd` (MODIFY - recalculate on worker changes)
- `scripts/ui/screens/OfflineGainsPopup.gd` (NEW)
- `scripts/ui/components/TerritoryInfoDisplayManager.gd` (MODIFY - real data)

**Integration Points:**
- ProductionManager registers in SystemRegistry Phase 5
- SaveManager calls ProductionManager for state persistence
- TerritoryManager delegates production to ProductionManager
- TaskAssignmentManager triggers recalculation on worker changes
- UI components read from ProductionManager

**Architecture Principle:**
Keep production calculation separate from territory management. ProductionManager is the single source of truth for production rates and accumulation.

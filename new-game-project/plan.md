# AFK Resource Generation System - Implementation Plan

## Overview

Implement offline resource generation for the 79-node hex territory system. The production formulas are complete (~75% done), but the accumulation timer, timestamps, and UI are missing. This plan follows the working pattern from the existing old Territory system.

**Reference:** `docs/CLAUDE.md` | **Analysis Agent:** ae89227

**Current State:**
- ✅ Production formulas complete (TerritoryProductionManager.gd L211-364)
- ✅ 79 hex nodes configured with base_production
- ✅ Worker assignment system working
- ✅ Old Territory offline production working (reference implementation)
- 🔴 HexNode lacks timestamps and accumulated_resources
- 🔴 No accumulation timer for hex nodes
- 🔴 No offline calculation on load
- 🔴 No UI display of production rates

**Implementation Strategy:** Copy the working patterns from the old Territory system (TerritoryProductionManager.gd L27-46, L100-118) and apply them to hex nodes.

---

## Task List

```json
[
  {
    "category": "data",
    "description": "Add production timestamps to HexNode data class",
    "steps": [
      "Add @export var last_production_time: int = 0 to HexNode.gd",
      "Add @export var accumulated_resources: Dictionary = {} to HexNode.gd",
      "Update to_dict() method to serialize new fields (around line 163)",
      "Update from_dict() method to deserialize new fields (around line 191)",
      "Verify serialization with debug print"
    ],
    "passes": true
  },
  {
    "category": "core",
    "description": "Implement periodic resource accumulation for hex nodes",
    "steps": [
      "In TerritoryProductionManager.gd, extend _start_generation_cycle() to handle hex nodes",
      "On timer timeout, call calculate_node_production() for each player node",
      "Accumulate resources in node.accumulated_resources Dictionary",
      "Update node.last_production_time to current timestamp",
      "Add debug prints to verify accumulation is working",
      "Test by waiting 60 seconds and checking accumulated_resources"
    ],
    "passes": true
  },
  {
    "category": "core",
    "description": "Implement offline production calculation for hex nodes",
    "steps": [
      "Create calculate_offline_hex_production(node: HexNode) -> Dictionary in TerritoryProductionManager.gd",
      "Copy pattern from get_pending_resources() (Lines 100-118)",
      "Calculate time_diff = current_time - node.last_production_time",
      "Calculate hours_passed = time_diff / 3600.0",
      "Get hourly_rate = calculate_node_production(node)",
      "Multiply hourly_rate by hours_passed for each resource",
      "Add to node.accumulated_resources (don't replace)",
      "Update node.last_production_time",
      "Add debug print showing offline time and resources generated"
    ],
    "passes": false
  },
  {
    "category": "core",
    "description": "Integrate offline calculation with SaveManager on load",
    "steps": [
      "In SaveManager.gd load_game(), after loading hex grid (around line 120)",
      "Get TerritoryProductionManager from SystemRegistry",
      "Get all player nodes from HexGridManager",
      "For each node, call calculate_offline_hex_production(node)",
      "Award accumulated resources via ResourceManager.award_resources()",
      "Clear node.accumulated_resources after awarding",
      "Add debug print showing total offline rewards",
      "Test by saving, closing, reopening after 5 minutes"
    ],
    "passes": false
  },
  {
    "category": "core",
    "description": "Add resource collection method for manual claiming",
    "steps": [
      "Create collect_node_resources(node_id: String) -> Dictionary in TerritoryProductionManager.gd",
      "Get node from HexGridManager",
      "Copy accumulated_resources to return Dictionary",
      "Clear node.accumulated_resources",
      "Emit resources_generated signal",
      "Return collected resources for UI feedback",
      "Test by accumulating for 60s then calling this method"
    ],
    "passes": false
  },
  {
    "category": "ui",
    "description": "Display production rates in NodeInfoPanel",
    "steps": [
      "In NodeInfoPanel.gd, find _production_container setup (around line 148)",
      "When node updates, call TerritoryProductionManager.calculate_node_production()",
      "Display hourly production as: 'Copper Ore: 120/hr'",
      "Show production bonuses breakdown (upgrade/connected/workers)",
      "Update when workers change via _on_workers_updated()",
      "Test by viewing different nodes with different workers"
    ],
    "passes": false
  },
  {
    "category": "ui",
    "description": "Add pending resources indicator to NodeInfoPanel",
    "steps": [
      "Add Label for 'Pending Resources:' above production section",
      "Show node.accumulated_resources with formatting",
      "Add 'Collect' Button that calls TerritoryProductionManager.collect_node_resources()",
      "On collect, award resources via ResourceManager.award_resources()",
      "Show popup or toast with collected amounts",
      "Update display after collection (should show 0)",
      "Test by waiting 60s and clicking Collect button"
    ],
    "passes": false
  },
  {
    "category": "ui",
    "description": "Add total production display to TerritoryOverviewScreen",
    "steps": [
      "In TerritoryOverviewScreen.gd, add header section for totals",
      "Call TerritoryProductionManager.get_all_hex_nodes_production()",
      "Display total hourly production: 'Total: 500 Copper/hr, 200 Wood/hr'",
      "Show total pending resources across all nodes",
      "Add 'Claim All Resources' button",
      "On click, collect from all nodes and award bulk",
      "Test by viewing overview with multiple producing nodes"
    ],
    "passes": false
  },
  {
    "category": "integration",
    "description": "Update production when workers change",
    "steps": [
      "In TerritoryManager.update_node_workers() (around line 598)",
      "After updating workers array, emit production_updated signal",
      "Pass node_id and new production rate",
      "In NodeInfoPanel, listen to production_updated",
      "Refresh production display when signal received",
      "Test by assigning/removing workers and watching rates update"
    ],
    "passes": false
  },
  {
    "category": "integration",
    "description": "Update production when nodes are upgraded",
    "steps": [
      "Find node upgrade method in TerritoryManager or HexNode",
      "After production_level changes, recalculate production",
      "Emit production_updated signal",
      "UI listens and refreshes display",
      "Test by upgrading a node's production_level"
    ],
    "passes": false
  },
  {
    "category": "testing",
    "description": "Test periodic accumulation (timer-based)",
    "steps": [
      "Run project with Godot MCP",
      "Capture a hex node and assign workers",
      "Wait 60 seconds (one accumulation cycle)",
      "Use game_interact to check node.accumulated_resources > 0",
      "Verify debug output shows accumulation happening",
      "Verify resources match production formula"
    ],
    "passes": false
  },
  {
    "category": "testing",
    "description": "Test offline production calculation",
    "steps": [
      "Run project, assign workers to nodes",
      "Save game (check activity.md for save confirmation)",
      "Stop project with mcp__godot__stop_project",
      "Wait 5 minutes (300 seconds)",
      "Run project again",
      "Check debug output for offline calculation logs",
      "Verify resources were awarded correctly",
      "Check ResourceManager balances increased"
    ],
    "passes": false
  },
  {
    "category": "testing",
    "description": "Test manual collection via UI",
    "steps": [
      "Run project, navigate to hex territory screen",
      "Select a producing node",
      "Verify production rates displayed correctly",
      "Wait for pending resources to accumulate",
      "Click 'Collect' button",
      "Verify resources added to player inventory",
      "Verify pending resources cleared to 0",
      "Check toast/popup confirmation appears"
    ],
    "passes": false
  },
  {
    "category": "testing",
    "description": "Test 'Claim All' functionality in overview",
    "steps": [
      "Run project, navigate to Territory Overview",
      "Verify total production rates shown correctly",
      "Wait for pending resources on multiple nodes",
      "Click 'Claim All Resources' button",
      "Verify all accumulated resources awarded",
      "Verify all nodes cleared to 0 pending",
      "Check total resources increased correctly"
    ],
    "passes": false
  },
  {
    "category": "polish",
    "description": "Apply balance config limits (max storage hours)",
    "steps": [
      "In calculate_offline_hex_production(), read territory_balance_config.json",
      "Cap hours_passed to max_storage_hours (12 hours default)",
      "If offline > 12 hours, only award 12 hours of production",
      "Add message to UI: 'Max storage reached (12 hours)'",
      "Test by being offline for 24 hours and verifying cap"
    ],
    "passes": false
  },
  {
    "category": "polish",
    "description": "Add manual collection bonus from balance config",
    "steps": [
      "In collect_node_resources(), read manual_collection_bonus (1.1 = +10%)",
      "Multiply collected resources by bonus",
      "Show bonus in UI: 'Collected 110 Copper (+10% bonus)'",
      "Only apply to manual collection, not offline",
      "Test by collecting manually vs offline and comparing amounts"
    ],
    "passes": false
  },
  {
    "category": "polish",
    "description": "Add visual feedback for production status",
    "steps": [
      "In HexMapView, add glow/icon to nodes with pending resources",
      "Add particle effect when collecting resources",
      "Add sound effect for collection",
      "Show production rate tooltip on node hover",
      "Test visual polish in game"
    ],
    "passes": false
  }
]
```

---

## Agent Instructions

1. **Read `activity.md` first** to understand current state
2. **Find next task** with `"passes": false`
3. **Complete all steps** for that task following the file paths and line numbers in the analysis
4. **Verify functionality** using Godot MCP tools:
   - `mcp__godot__run_project` to start the game
   - `mcp__godot__game_interact` to check node state
   - `mcp__godot__get_debug_output` to see debug prints
   - `mcp__godot__game_screenshot` for visual verification
5. **Update task** to `"passes": true` ONLY when verified working
6. **Log completion** in `activity.md` with:
   - What was implemented
   - What files were changed (paths + line numbers)
   - How it was verified (debug output, button clicks, etc.)
7. **Git commit** for that task only with clear message
8. **Repeat** until all tasks pass

**Important Rules:**
- Do NOT mark as passed unless you verify it works (no placeholders)
- Do NOT skip verification steps
- Do NOT batch multiple tasks together
- Follow existing code patterns from the old Territory system
- Use static typing: `var timestamp: int = 0`, `func calculate() -> Dictionary:`
- Add debug prints for verification
- Test incrementally (don't write 500 lines then test)

**Reference Files:**
- Analysis: Agent ae89227 output (comprehensive breakdown)
- Working reference: TerritoryProductionManager.gd L27-46, L100-118
- Data model: HexNode.gd L47-60, L163-189
- UI panels: NodeInfoPanel.gd, TerritoryOverviewScreen.gd

---

## Completion Criteria

All 17 tasks marked with `"passes": true` AND verified working in-game:
1. ✅ Resources accumulate while game is running (timer test)
2. ✅ Offline rewards calculated on load (5-minute offline test)
3. ✅ Manual collection works via UI button
4. ✅ Production rates displayed correctly in panels
5. ✅ "Claim All" works in overview screen
6. ✅ Balance limits applied (12-hour cap, manual bonus)
7. ✅ Visual feedback present

**Final Verification:**
- Save game with producing nodes
- Close for 10 minutes
- Reopen and verify offline rewards
- Navigate to node, verify rates shown
- Click Collect, verify resources added
- Go to overview, verify totals
- Click Claim All, verify bulk award

When all tasks pass and final verification succeeds, output exactly:

<promise>COMPLETE</promise>

---

## Formula Reference (From TerritoryProductionManager.gd L211-239)

**Complete Production Formula:**
```
HOURLY_PRODUCTION = BASE_PRODUCTION
  × (1 + UPGRADE_BONUS)
  × (1 + CONNECTED_BONUS)
  × (1 + WORKER_EFFICIENCY)

Where:
  UPGRADE_BONUS = (production_level - 1) × 0.10

  CONNECTED_BONUS = {
    0-1 neighbors: 0%
    2 neighbors: 10%
    3 neighbors: 20%
    4+ neighbors: 30%
  }

  WORKER_EFFICIENCY = SUM of all workers:
    Base: 10% per worker
    + Spec bonus: 50-200% (from SpecializationManager)
    + Level bonus: god.level × 1%
```

**Example Calculation:**

Node: Copper Mine (base: 50 copper_ore/hr)
- production_level = 3 (upgraded twice)
- 3 connected player nodes
- 2 workers assigned:
  - Worker 1: Level 10, no spec → 10% + 10% = 20%
  - Worker 2: Level 15, tier 2 spec → 10% + 100% + 15% = 125%

```
Copper/hr = 50
  × (1 + 0.20)      [upgrade bonus: (3-1) × 0.10]
  × (1 + 0.20)      [connected bonus: 3 neighbors]
  × (1 + 1.45)      [worker bonus: 0.20 + 1.25]
= 50 × 1.20 × 1.20 × 2.45
= 176.4 copper/hr
```

**Offline Calculation (Copy from Lines 100-118):**
```gdscript
var current_time = Time.get_unix_time_from_system()
var time_diff = current_time - node.last_production_time
var hours_passed = time_diff / 3600.0
var hourly_rate = calculate_node_production(node)
var total_resources = {}
for resource_id in hourly_rate:
  total_resources[resource_id] = hourly_rate[resource_id] * hours_passed
```

---

## Key File Locations

**TerritoryProductionManager.gd:**
- L27-46: _start_generation_cycle() - Timer for old territory (EXTEND FOR HEXNODES)
- L100-118: get_pending_resources() - Offline calc (COPY PATTERN)
- L211-239: calculate_node_production() - Main formula (ALREADY WORKS)
- L241-264: apply_connected_bonus() - Neighbor bonuses (ALREADY WORKS)
- L306-339: _calculate_worker_efficiency() - Worker bonuses (ALREADY WORKS)
- L347-364: get_all_hex_nodes_production() - Total production (ALREADY WORKS)

**HexNode.gd:**
- L47-60: Production fields (ADD TIMESTAMPS HERE)
- L163-189: to_dict() serialization (UPDATE)
- L191-245: from_dict() deserialization (UPDATE)

**SaveManager.gd:**
- L32: Timestamp saved (ALREADY EXISTS)
- L120-123: Hex grid load (ADD OFFLINE CALC HERE)

**TerritoryManager.gd:**
- L598-621: update_node_workers() (ADD SIGNAL EMIT)

**NodeInfoPanel.gd:**
- Line ~148: Production section (ADD DISPLAY)

**TerritoryOverviewScreen.gd:**
- (ADD TOTALS SECTION)

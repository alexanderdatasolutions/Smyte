@docs/CLAUDE.md @ralph_wiggum_guide.md

## Context

We need to implement the AFK resource generation system for this Godot 4.5 game.

**Current Situation**: Players can assign gods to hex nodes as workers, but we need to verify if those workers are actually generating resources over time.

---

## Step 0a-0d: Study the Codebase

Study the entire codebase with up to 500 parallel Sonnet subagents to understand:

### Systems to Analyze
- `scripts/systems/territory/` - TerritoryManager, TaskAssignmentManager, NodeProductionInfo
- `scripts/systems/core/` - ResourceManager, SaveManager, SystemRegistry
- `scripts/data/HexNode.gd` - What production fields exist?
- `scripts/ui/screens/HexTerritoryScreen.gd` - Worker assignment UI
- `scripts/ui/territory/` - NodeInfoPanel, HexMapView
- `data/` - JSON configs for nodes, tasks, resources

### Key Questions
1. Does HexNode have production rate fields? Are they used?
2. Is there any system generating resources over time?
3. Does TaskAssignmentManager calculate production rates?
4. Is there timestamp tracking for production?
5. Is there any offline rewards system?
6. Does UI show production rates or pending resources?

### Look For
- Signal connections between handlers
- How workers relate to production (if at all)
- How resources are added to ResourceManager
- Save/load structure for production data
- _process() or timer loops that might handle production
- Formulas and magic numbers

---

## Step 1: Create Comprehensive Analysis

### Documentation Gaps
**What Already Exists:**
- List all production-related code (file paths + line numbers)
- Document worker assignment flow
- Document resource management
- Document save/load structure

**What's Missing:**
- Which systems need creation from scratch?
- Which just need connecting?
- What formulas are buried but not explained?
- What's partially implemented but not working?

### Code Cleanup Opportunities
- Untyped variables in production code
- Duplicated logic across systems
- Magic numbers without constants
- Dead code or unused fields

---

## Step 2: Create plan.md

Structure following ralph_wiggum_guide.md format:

```markdown
# AFK Resource Generation System - Implementation Plan

## Overview
Brief description

**Reference:** `docs/CLAUDE.md`

---

## Task List

```json
[
  {
    "category": "audit",
    "description": "Audit existing production systems and identify gaps",
    "steps": [
      "Review TerritoryManager for production tracking",
      "Review TaskAssignmentManager for efficiency calcs",
      "Check if production rates are calculated",
      "Identify what's missing"
    ],
    "passes": false
  }
]
```

## Agent Instructions
1. Read activity.md first
2. Find next task with "passes": false
3. Complete all steps
4. Verify with Godot MCP tools
5. Update "passes" to true
6. Log in activity.md
7. Git commit
8. Repeat until all pass

**Important:** Do not mark as passed unless you verify with debug output and button presses that it's functional and works.

## Completion Criteria
All tasks marked "passes": true
```

### Task Prioritization
1. Audit first - understand what exists
2. Core systems - ProductionManager, production_rates.json
3. Time tracking - offline gains calculation
4. Integration - connect systems
5. UI - production displays and claim buttons
6. Testing - end-to-end verification

IMPORTANT: Plan only. Do NOT implement anything. This is gap analysis only.

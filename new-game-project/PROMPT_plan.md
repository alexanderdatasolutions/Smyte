@docs/CLAUDE.md @ralph_wiggum_guide.md

## Context

We need a **Complete Game Design Document** that unifies all systems and reveals the core gameplay loop. The goal is documented in CLAUDE.md.

**Current Situation**: We have many backend systems implemented (summoning, dungeons, hex nodes, equipment, crafting, specializations, awakening, etc.) but we don't know:
- What connects to what?
- What materials are for?
- Which gods are good for which tasks?
- What the actual gameplay loop is?
- What's implemented vs what's missing?
- Which systems are visible to players vs hidden in backend?

The core loop SHOULD be:
1. Acquire god (summoning)
2. Use god in battle (node capture, dungeons, PvP)
3. Gain rewards (resources, materials)
4. Spend rewards on:
   - Summon more gods
   - Sacrifice to level up and awaken gods
   - Craft equipment to equip to gods
   - Specialize gods into roles
5. Capture more nodes → get more passive resources → loop

**BUT:** We need to verify what actually exists, what works, what's connected, and what's missing.

---

## Step 0a-0d: Study the Entire Codebase

Study the **entire codebase** with up to **500 parallel Sonnet subagents** to understand:

### All Systems to Analyze

**Core Systems:**
- `scripts/systems/core/` - SystemRegistry, SaveManager, ResourceManager, GameCoordinator
- `scripts/systems/collection/` - GodManager, SummoningManager, TeamManager
- `scripts/systems/battle/` - BattleManager, DamageCalculator
- `scripts/systems/progression/` - AwakeningManager, LevelingManager, SpecializationManager
- `scripts/systems/equipment/` - EquipmentManager, EquipmentCraftingManager
- `scripts/systems/territory/` - TerritoryManager, TaskAssignmentManager, TerritoryProductionManager, HexGridManager
- `scripts/systems/dungeon/` - DungeonManager, DungeonRewardCalculator, DungeonDifficultyManager
- `scripts/systems/resources/` - ResourceManager

**Data Models:**
- `scripts/data/` - God.gd, HexNode.gd, Equipment.gd, Dungeon.gd, Specialization.gd, etc.

**UI Screens:**
- `scripts/ui/screens/` - All screens (Collection, Battle, Dungeon, Equipment, HexTerritory, Summoning, etc.)
- `scripts/ui/` - All UI components

**JSON Configs:**
- `data/` - All JSON files (gods_base_data.json, dungeons.json, crafting_recipes.json, resources.json, hex_nodes.json, specializations.json, equipment_base_data.json, etc.)

### Key Questions to Answer

**Resource Flow:**
1. What are ALL 49 resources used for?
2. Where do resources come from (hex nodes, dungeons, tasks, PvP)?
3. Where do resources go (crafting, summoning, awakening, specialization)?
4. Which resources are bottlenecks?
5. Which resources are useless?

**God Progression:**
1. How do you level up gods (sacrifice system)?
2. How does awakening work (requirements, effects)?
3. How do specializations work (fish → fisher → master fisher)?
4. What stats do gods have? How do they grow?
5. Can you see god potential before summoning?

**Equipment System:**
1. What equipment exists?
2. How do you craft equipment (recipes, materials)?
3. Can you equip gods? How does it work?
4. What stats does equipment provide?
5. Is the crafting UI built?

**Territory/Hex Nodes:**
1. Which gods are good for which nodes (efficiency bonuses)?
2. What do nodes produce? At what rates?
3. How does AFK production work? Is it visible?
4. Can you see production rates before assigning workers?
5. Are there node upgrade paths?

**Dungeon System:**
1. What dungeons exist? What do they reward?
2. Are dungeon rewards visible before entering?
3. Do dungeons scale with difficulty?
4. Can you replay dungeons (replayability system)?
5. What's the risk vs reward?

**Battle System:**
1. How does combat work (turn-based, real-time, auto)?
2. What stats matter (Attack, Defense, HP, Mana)?
3. How do god abilities work?
4. Can you see battle previews?
5. Is there a combat log?

**Playstyles:**
1. Can you play as a gatherer (passive resource main)?
2. Can you play as a warrior (conquest main)?
3. Can you play as a crafter (equipment main)?
4. Are there roles/archetypes for gods?

**UI Visibility:**
1. Which systems have UI screens?
2. Which systems are backend-only (no UI)?
3. Can players discover all features organically?
4. Are there tooltips explaining systems?
5. Is there a tutorial or guide?

### Look For

**Signal connections between systems:**
- How do managers communicate?
- Which systems depend on each other?
- What's the event flow?

**Code patterns and architecture:**
- How are systems registered?
- How is data saved/loaded?
- How are resources added/spent?

**Missing connections:**
- Systems that exist but aren't called
- UI screens that don't expose functionality
- Data that's defined but not used

**Formulas and magic numbers:**
- Production rate calculations
- XP/leveling formulas
- Damage calculations
- Drop rate formulas
- Awakening costs

**Visibility gaps:**
- What players can't see
- What players can't discover
- What players don't understand

---

## Step 1: Create Comprehensive Analysis Document

Use up to **50 parallel Opus subagents with ultrathink** to create a massive analysis document.

### Document Structure

Create `docs/GAME_DESIGN_DOCUMENT.md` with these sections:

#### 1. Executive Summary
- Current state (what works, what doesn't)
- Core gameplay loop (intended vs actual)
- Biggest gaps
- Recommended priorities

#### 2. Resource Economy
**For ALL 49 resources:**
- Resource name and ID
- Where it comes from (sources: nodes, dungeons, tasks, etc.)
- Where it goes (sinks: crafting, summoning, awakening, etc.)
- Is it balanced? (too much, too little, useless)
- Is it visible to players?

**Resource Flow Diagram:**
```
Nodes → Materials → Crafting → Equipment → Power
  ↓         ↓           ↓
Tasks    Summoning  Awakening
  ↓         ↓           ↓
Dungeons  Gods    Specialization
```

#### 3. God Progression System
- Summoning (how to get gods, costs, rates)
- Leveling (XP sources, formulas, sacrifice system)
- Awakening (requirements, costs, benefits)
- Specialization (trees, unlocks, bonuses)
- Equipment (slots, stats, crafting)

#### 4. Territory/Hex Node System
- Node types and tiers
- Production rates and formulas
- Worker assignment (efficiency bonuses)
- Upgrade paths
- AFK production (timer, offline gains)
- UI visibility (what players see)

#### 5. Dungeon System
- All dungeons (tier, difficulty, rewards)
- Replayability mechanics
- Reward scaling
- Risk vs reward balance
- Entry requirements

#### 6. Battle System
- Combat flow (turn order, actions)
- Stats that matter (formulas)
- Abilities and skills
- Damage calculation
- Victory/defeat conditions

#### 7. Crafting System
- All recipes (10+ recipes)
- Material requirements
- Equipment stats
- Crafting UI (exists? missing?)
- Discovery mechanics

#### 8. Playstyle Archetypes
**Can you play as:**
- Gatherer (passive income, minimal combat)
- Warrior (conquest, combat-focused)
- Crafter (equipment production)
- Specialist (role optimization)

#### 9. UI/UX Audit
**For each system:**
- Screen name
- What's visible
- What's hidden
- What's discoverable
- What's confusing
- Missing tooltips
- Missing tutorials

#### 10. System Integration Map
**Connections between systems:**
- Which systems call which?
- Which systems depend on which?
- Which systems are isolated?
- Which connections are missing?

#### 11. Missing Pieces
**What needs to be built:**
- Missing UI screens
- Missing tooltips
- Missing connections
- Missing formulas
- Missing feedback loops

#### 12. Code Quality Audit
**Cleanup opportunities:**
- Untyped variables
- Magic numbers
- Dead code
- Duplicated logic
- Inconsistent patterns

---

## Step 2: Create plan.md

After the comprehensive analysis, create `plan.md` following ralph_wiggum_guide.md format:

```markdown
# Unified Game Design Document & System Connection - Implementation Plan

## Overview
Connect all backend systems to UI, create unified game design document, expose hidden features, and complete the core gameplay loop.

**Reference:** `docs/GAME_DESIGN_DOCUMENT.md`

---

## Task List

```json
[
  {
    "category": "audit",
    "description": "Complete comprehensive system audit and create GDD",
    "steps": [
      "Analyze all 49 resources (sources, sinks, visibility)",
      "Map god progression (summoning, leveling, awakening, specialization)",
      "Document territory system (nodes, production, workers)",
      "Audit dungeon system (rewards, replayability, scaling)",
      "Map battle system (combat, stats, abilities)",
      "Audit crafting system (recipes, materials, UI gaps)",
      "Identify playstyle archetypes",
      "Create system integration map",
      "List all missing UI components",
      "Create docs/GAME_DESIGN_DOCUMENT.md with all findings"
    ],
    "passes": false
  },
  {
    "category": "ui",
    "description": "Build Crafting UI to expose recipe system",
    "steps": [
      "Create RecipeBookScreen.gd (browse all recipes)",
      "Add crafting tab to EquipmentScreen",
      "Show material requirements with have/need counts",
      "Add Craft button that calls EquipmentCraftingManager",
      "Add success/failure feedback",
      "Test crafting flow end-to-end"
    ],
    "passes": false
  },
  {
    "category": "ui",
    "description": "Add resource tooltips explaining purpose",
    "steps": [
      "Create ResourceTooltip component",
      "Add 'Used For' section (crafting, summoning, etc.)",
      "Add 'Sources' section (nodes, dungeons, tasks)",
      "Integrate tooltips in ResourceManager displays",
      "Test all 49 resource tooltips"
    ],
    "passes": false
  },
  {
    "category": "ui",
    "description": "Add god assignment efficiency display",
    "steps": [
      "Show efficiency % when assigning gods to nodes",
      "Show why (specialization bonus, level bonus)",
      "Add tooltip: 'This god is 35% efficient at fishing'",
      "Show comparison: 'Zeus: 15% | Poseidon: 85%'",
      "Test assignment UI updates"
    ],
    "passes": false
  },
  {
    "category": "integration",
    "description": "Connect dungeon rewards to resource economy",
    "steps": [
      "Show dungeon rewards BEFORE entering",
      "Display material drops in preview",
      "Show reward multipliers for difficulty",
      "Add dungeon→crafting connection UI",
      "Test dungeon reward visibility"
    ],
    "passes": false
  }
]
```

## Agent Instructions
1. Read GAME_DESIGN_DOCUMENT.md first
2. Find next task with "passes": false
3. Complete all steps
4. Verify with Godot MCP tools
5. Update "passes" to true
6. Log in activity.md
7. Git commit
8. Repeat until all pass

**Important:** The first task is MASSIVE - use 500 parallel Sonnet agents to analyze the entire codebase and create the comprehensive GDD.

## Completion Criteria
All tasks marked "passes": true
```

### Task Prioritization
1. **AUDIT FIRST** - Comprehensive analysis with 500 parallel agents
2. **Document everything** - Create GAME_DESIGN_DOCUMENT.md
3. **UI gaps** - Build missing screens (Crafting, Tooltips, etc.)
4. **System connections** - Wire up isolated systems
5. **Player visibility** - Make everything discoverable
6. **Polish** - Tutorials, guides, feedback loops

IMPORTANT: **Plan only.** Do NOT implement anything. This is comprehensive gap analysis only.

---

## Expected Output

When complete, we should have:

1. **docs/GAME_DESIGN_DOCUMENT.md** (100+ pages)
   - Complete resource economy map
   - Full god progression documentation
   - All formulas and calculations
   - All systems documented end-to-end
   - All missing pieces identified
   - Priority-ordered implementation tasks

2. **plan.md** with tasks to:
   - Build missing UI (Crafting Screen, Recipe Book, Tooltips)
   - Connect isolated systems (Dungeons → Crafting, Nodes → Resources)
   - Add visibility features (Efficiency %, Resource purposes)
   - Create feedback loops (Progression guide, Tutorials)

3. **activity.md** logging the audit process

---

## Analysis Depth Required

This is NOT a quick pass. This requires:
- **500 parallel Sonnet subagents** reading every file
- **50 parallel Opus subagents** synthesizing findings
- **Deep code analysis** (formulas, signals, connections)
- **Complete JSON config parsing** (all 49 resources, all recipes, all nodes, all dungeons)
- **UI/UX audit** (what's visible, what's hidden, what's confusing)
- **System integration mapping** (who calls who, what depends on what)

**Estimated agent hours:** 100+ hours of parallel agent work compressed into minutes.

**End result:** Complete understanding of:
- What we have
- What works
- What's broken
- What's missing
- What to build next
- How it all connects

IMPORTANT: **Plan only. Do NOT implement anything. This is gap analysis only.**

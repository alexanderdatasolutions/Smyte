@docs/CLAUDE.md @activity.md

## Context

We need a **Complete Game Design Document** that unifies all systems and reveals the core gameplay loop.

**Current Situation**: We have many backend systems implemented (summoning, dungeons, hex nodes, equipment, crafting, specializations, awakening, etc.) but we don't know:
- What connects to what?
- What materials are for?
- Which gods are good for which tasks?
- What the actual gameplay loop is?
- What's implemented vs what's missing?
- Which systems are visible to players vs hidden in backend?

**The Core Loop (Intended):**
1. Acquire god (summoning)
2. Use god in battle (node capture, dungeons, PvP)
3. Gain rewards (resources, materials)
4. Spend rewards on:
   - Summon more gods
   - Sacrifice to level up and awaken gods
   - Craft equipment to equip to gods
   - Specialize gods into roles
5. Capture more nodes → get more passive resources → loop

---

## Step 0a: Study Existing Documentation

Study `docs/*` with up to **250 parallel Sonnet subagents** to understand:
- What documentation already exists?
- What's the current state of the project?
- What architectural decisions are documented?
- What gaps exist in the documentation?

---

## Step 0b: Study IMPLEMENTATION_PLAN.md (if present)

Read `IMPLEMENTATION_PLAN.md` (if it exists) to understand:
- What progress has been made so far?
- What tasks are complete?
- What tasks are pending?
- What discoveries were made during previous work?

---

## Step 0c: Study the Entire Codebase

Study the **entire codebase** with up to **500 parallel Sonnet subagents** to understand:

### Core Systems
- `scripts/systems/core/` - SystemRegistry, SaveManager, ResourceManager, GameCoordinator
- `scripts/systems/collection/` - GodManager, SummoningManager, TeamManager
- `scripts/systems/battle/` - BattleManager, DamageCalculator
- `scripts/systems/progression/` - AwakeningManager, LevelingManager, SpecializationManager
- `scripts/systems/equipment/` - EquipmentManager, EquipmentCraftingManager
- `scripts/systems/territory/` - TerritoryManager, TaskAssignmentManager, TerritoryProductionManager, HexGridManager
- `scripts/systems/dungeon/` - DungeonManager, DungeonRewardCalculator, DungeonDifficultyManager
- `scripts/systems/resources/` - ResourceManager

### JSON Configs
- `data/resources.json` - All 49 resources
- `data/recipes.json` - Crafting recipes
- `data/gods.json` - God definitions
- `data/dungeons.json` - Dungeon configurations
- `data/hex_nodes.json` - Territory node types
- `data/specializations.json` - God role specializations
- `data/equipment.json` - Equipment definitions

### UI Screens and Components
- `scripts/ui/screens/` - All game screens
- `scripts/ui/components/` - Reusable UI components
- `scenes/` - All scene files

### Signal Connections and Event Flow
- How do systems communicate?
- What signals are emitted and listened to?
- How does data flow through the game?

### Code Patterns and Architecture
- How is SystemRegistry used?
- How do systems register themselves?
- How does save/load work?
- What patterns are followed consistently?
- What patterns are inconsistent?

### Code Quality Issues
- Untyped variables and functions
- Duplicated logic across systems
- Inconsistent patterns between similar systems
- Magic numbers without constants
- Dead code or unused signals
- Overly complex functions that need refactoring
- JSON config parsing that could be cleaner

---

## Step 0d: Study docs/ Directory

Study existing documentation in `docs/` to understand:
- What's already documented?
- What documentation standards exist?
- How are docs structured?
- What gaps exist?

---

## Step 1: Create Comprehensive Analysis

Using up to **50 parallel Opus subagents with ultrathink**, create a comprehensive analysis covering:

### Documentation Gaps

**Core Systems:**
- Which systems lack documentation? (Start with SystemRegistry and core managers)
- What formulas/calculations are buried in managers but not explained?
- How do the JSON configs get loaded and used?
- What signals connect which systems?

**Game Loops:**
- How does combat flow? (BattleManager, DamageCalculator)
- How does progression work? (LevelingManager, AwakeningManager, SpecializationManager)
- How does territory work? (TerritoryManager, HexGridManager, TaskAssignmentManager)
- How does crafting work? (EquipmentCraftingManager, ResourceManager)
- How do dungeons work? (DungeonManager, DungeonRewardCalculator)

**Resource Economy:**
- What are ALL 49 resources?
- Where does each resource come from (sources)?
- Where does each resource go (sinks)?
- Is each resource balanced? (too much, too little, useless)
- Is each resource visible to players?
- What's the intended purpose of each resource?

**God System:**
- How do gods level up? (formulas, XP sources)
- How does awakening work? (costs, materials, effects)
- How do specializations work? (requirements, bonuses, efficiency)
- Which gods are good for which tasks?
- How do god stats affect combat?

**Territory/Hex System:**
- What node types exist?
- What resources do nodes produce?
- How do god assignments work?
- What efficiency bonuses exist?
- How does passive production work?

**Dungeon System:**
- What dungeons exist?
- What do they reward?
- How does difficulty scale?
- How do players access dungeons?

**Equipment/Crafting:**
- What equipment exists?
- What recipes exist?
- Is crafting UI built?
- How do players craft?
- How does equipment affect gods?

**UI/UX Audit:**
- Which systems have UI and which are backend-only?
- What screens exist?
- What's missing from player visibility?
- Where are tooltips needed?
- Where is feedback missing?

**System Integration:**
- How do systems connect?
- What's the actual gameplay loop vs intended loop?
- Where are connections missing?
- What systems are isolated?

**Playstyle Archetypes:**
- Can you play as a gatherer main?
- Can you go full warrior?
- Can you focus on crafting?
- Are all playstyles viable?

**What's Missing:**
- What UI is missing?
- What connections are missing?
- What features are partially implemented?
- What's next to build?

### Code Cleanup Opportunities

- Untyped variables and functions (GDScript supports static typing!)
- Duplicated logic across systems
- Inconsistent patterns between similar systems
- Magic numbers without constants
- Dead code or unused signals
- Overly complex functions that need refactoring
- JSON config parsing that could be cleaner

---

## Step 2: Create IMPLEMENTATION_PLAN.md

Create/update `IMPLEMENTATION_PLAN.md` with prioritized tasks. Structure as:

```markdown
# Game Design & System Integration - Implementation Plan

## Overview
[Brief description of what needs to be done based on the analysis]

**Reference:** `docs/GAME_DESIGN_DOCUMENT.md`

---

## Documentation Tasks

- [ ] Document SystemRegistry and core architecture (creates `docs/architecture/SystemRegistry.md`)
- [ ] Document all 49 resources with sources/sinks (creates `docs/economy/Resources.md`)
- [ ] Document god progression system (creates `docs/systems/GodProgression.md`)
- [ ] Document territory/hex system (creates `docs/systems/Territory.md`)
- [ ] Document dungeon system (creates `docs/systems/Dungeons.md`)
- [ ] Document battle system (creates `docs/systems/Battle.md`)
- [ ] Document crafting system (creates `docs/systems/Crafting.md`)
- [ ] Create MOC for game systems (creates `docs/MOCs/GameSystems.md`)
- [ ] Create MOC for resource economy (creates `docs/MOCs/ResourceEconomy.md`)

## UI/UX Tasks

- [ ] Build Crafting Screen UI (affects `scripts/ui/screens/CraftingScreen.gd`)
- [ ] Build Recipe Book UI (affects `scripts/ui/screens/RecipeBookScreen.gd`)
- [ ] Add resource tooltips (affects `scripts/ui/components/ResourceTooltip.gd`)
- [ ] Add god efficiency indicators (affects `scripts/ui/components/GodCard.gd`)
- [ ] Add dungeon reward preview (affects `scripts/ui/screens/DungeonSelectScreen.gd`)

## Integration Tasks

- [ ] Connect dungeon rewards to crafting (affects `scripts/systems/dungeon/DungeonManager.gd`)
- [ ] Connect node production to resource display (affects `scripts/systems/territory/TerritoryManager.gd`)
- [ ] Add progression feedback (affects `scripts/systems/progression/LevelingManager.gd`)
- [ ] Build tutorial system (affects `scripts/systems/tutorial/TutorialManager.gd`)

## Code Cleanup Tasks

- [ ] Add static typing to all core systems (affects `scripts/systems/core/*.gd`)
- [ ] Extract magic numbers to constants (affects multiple files)
- [ ] Refactor complex functions (affects specific files as discovered)
- [ ] Remove dead code (affects multiple files)

---

Prioritize tasks that:
1. Document core systems first (SystemRegistry, ResourceManager, GodManager)
2. Document resource economy (all 49 resources)
3. Document core game loops (combat, progression, crafting, territory)
4. Create MOC (Map of Content) pages that link systems together
5. Build missing UI that exposes backend systems
6. Fix code quality issues that block understanding
7. Capture formulas and magic numbers
```

---

## Step 3: Create GAME_DESIGN_DOCUMENT.md

Create `docs/GAME_DESIGN_DOCUMENT.md` with comprehensive documentation covering all the areas analyzed in Step 1.

**Documentation Standards:**
- Use Obsidian format with frontmatter, wiki-links, callouts
- Every doc must link to at least 2 other docs (no isolated notes)
- Include GDScript snippets with file paths
- Document formulas in both prose AND code blocks
- Document signal flows (who emits, who listens, what data)
- Document JSON config structure with examples
- Create MOC pages that serve as hubs
- Use tags and aliases liberally

**Example Structure:**

```markdown
---
tags: [game-design, core-loop, economy]
aliases: [GDD, Game Design Document]
related: [[GameSystems]], [[ResourceEconomy]], [[GodProgression]]
---

# Game Design Document

## Executive Summary

[Current state, core loop, biggest gaps, recommended priorities]

## Resource Economy

### Overview
The game has 49 resources across multiple categories...

### Resource Breakdown

#### Basic Resources
- **[[Wood]]**: Gathered from forest nodes, used for [[Crafting]] basic equipment
  - Sources: Forest nodes (forest_basic, forest_ancient)
  - Sinks: Equipment recipes (wooden_sword, wooden_shield)
  - Balance: ✅ Well balanced
  - Visibility: ⚠️ Players don't know what it's for

[Continue for all 49 resources...]

## God Progression System

### Leveling
[Document formulas, XP sources, level caps]

### Awakening
[Document costs, materials, effects]

### Specialization
[Document roles, requirements, bonuses]

[Continue for all systems...]
```

---

## Important Notes

**IMPORTANT: Plan only. Do NOT implement anything. This is gap analysis and documentation only.**

**ULTIMATE GOAL:**
1. Create a comprehensive Game Design Document in `docs/GAME_DESIGN_DOCUMENT.md`
2. Create a rich Obsidian knowledge base with interconnected notes
3. Create an actionable implementation plan in `IMPLEMENTATION_PLAN.md`
4. Document the codebase architecture so it's maintainable
5. Identify what's missing and prioritize what to build next

**Documentation Requirements:**
- Use Obsidian format: frontmatter, `[[wiki-links]]`, callouts (> [!note]), tags
- Every doc links to at least 2 other docs (isolated notes are useless)
- Include GDScript snippets with file paths
- Document formulas in both prose AND code blocks
- Document signal flows (who emits, who listens, what data is passed)
- Document JSON config structure with examples
- Create `docs/MOCs/` index pages that link all related concepts together

---

## Completion

When complete, output exactly:

<promise>PLAN_COMPLETE</promise>

# Game Design Document & System Unification - Activity Log

## Current Status
**Last Updated:** 2026-01-18 23:45
**Phase:** Planning - Comprehensive System Audit
**Current Task:** Ralph will create complete Game Design Document with 500 parallel agents

---

## Project Context

This planning phase creates a comprehensive Game Design Document that maps ALL game systems end-to-end. The goal is to understand:
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

**Problem:** We have many backend systems but don't know how they connect or what's visible to players.

---

## Session Log

### 2026-01-18 23:45 - Created Ralph Plan Mode Prompt for GDD Generation

**Task:** Create comprehensive system audit plan following ralph_wiggum_guide.md

**What Was Done:**
1. Created new `PROMPT_plan.md` for comprehensive GDD generation
2. Instructed Ralph to use 500 parallel Sonnet subagents for codebase analysis
3. Defined 12-section Game Design Document structure:
   - Executive Summary
   - Resource Economy (all 49 resources mapped)
   - God Progression System
   - Territory/Hex Node System
   - Dungeon System
   - Battle System
   - Crafting System
   - Playstyle Archetypes
   - UI/UX Audit
   - System Integration Map
   - Missing Pieces
   - Code Quality Audit
4. Defined key questions to answer for each system
5. Created sample plan.md structure with 5 initial UI/integration tasks

**Files Modified:**
- `PROMPT_plan.md` - Created comprehensive audit prompt (411 lines)
- `activity.md` - This file, updated for new planning phase

**Systems to Analyze:**
- Core: SystemRegistry, SaveManager, ResourceManager, GameCoordinator
- Collection: GodManager, SummoningManager, TeamManager
- Battle: BattleManager, DamageCalculator
- Progression: AwakeningManager, LevelingManager, SpecializationManager
- Equipment: EquipmentManager, EquipmentCraftingManager
- Territory: TerritoryManager, TaskAssignmentManager, TerritoryProductionManager, HexGridManager
- Dungeon: DungeonManager, DungeonRewardCalculator, DungeonDifficultyManager
- Resources: ResourceManager
- All UI screens and components
- All JSON configs (49 resources, recipes, dungeons, nodes, gods, etc.)

**Expected Deliverables from Ralph:**
1. `docs/GAME_DESIGN_DOCUMENT.md` (100+ pages)
   - Complete resource economy map (all 49 resources)
   - Full god progression documentation
   - All formulas and calculations documented
   - All systems documented end-to-end
   - All missing pieces identified
   - UI/UX visibility audit
   - System integration map
   - Priority-ordered implementation tasks

2. `plan.md` - Task list for:
   - Building missing UI (Crafting Screen, Recipe Book, Tooltips)
   - Connecting isolated systems (Dungeons → Crafting, Nodes → Resources)
   - Adding visibility features (Efficiency %, Resource purposes)
   - Creating feedback loops (Progression guide, Tutorials)

**Key Questions Ralph Will Answer:**
- What are ALL 49 resources used for?
- Where do resources come from and where do they go?
- How does god progression work (leveling, awakening, specialization)?
- What equipment exists? Is crafting UI built?
- Which gods are good for which nodes (efficiency bonuses)?
- What dungeons exist and what do they reward?
- How does combat work?
- Can you play as gatherer, warrior, or crafter?
- Which systems have UI and which are backend-only?
- What's the actual gameplay loop vs intended loop?

**Analysis Depth:**
- 500 parallel Sonnet subagents reading every file
- 50 parallel Opus subagents synthesizing findings
- Deep code analysis (formulas, signals, connections)
- Complete JSON config parsing
- UI/UX audit (visible vs hidden)
- System integration mapping

**Status:** Ready to run `./ralph.sh plan 5` for comprehensive audit

**Next Step:** Run Ralph in plan mode to create the Game Design Document

---

<!-- Ralph will append audit completion entries below -->

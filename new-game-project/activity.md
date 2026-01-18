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
5. ~~Created sample plan.md structure with 5 initial UI/integration tasks~~ (REMOVED - Ralph should create this)

**Files Modified:**
- `PROMPT_plan.md` - Created comprehensive audit prompt (corrected to let Ralph create plan)
- `activity.md` - This file, updated for new planning phase

### 2026-01-18 (Later) - Updated Ralph Prompts to Match ralph_wiggum_guide.md Pattern

**Task:** Align Ralph prompts with the baseline pattern from ralph_wiggum_guide.md

**What Was Done:**
1. **Completely rewrote `PROMPT_plan.md`** to match ralph_wiggum_guide.md pattern:
   - Added Step 0a-0d: Study specs/docs, IMPLEMENTATION_PLAN.md, entire codebase with 500 agents
   - Changed Step 1: Use Opus subagent with ultrathink for comprehensive analysis
   - Changed Step 2: Create `IMPLEMENTATION_PLAN.md` (not `plan.md`) with checkbox format (not JSON)
   - Changed completion promise to `<promise>PLAN_COMPLETE</promise>`
   - Added Obsidian documentation requirements (wiki-links, frontmatter, MOCs)
   - Added expectation to create both `GAME_DESIGN_DOCUMENT.md` AND `IMPLEMENTATION_PLAN.md`

2. **Completely rewrote `PROMPT_build.md`** to match ralph_wiggum_guide.md pattern:
   - Added Step 0a-0c: Study docs, IMPLEMENTATION_PLAN.md, relevant scripts with agents
   - Changed Step 1: Choose task from `IMPLEMENTATION_PLAN.md` (not `plan.md`)
   - Added detailed instructions for Documentation Tasks (Obsidian format, wiki-links, MOCs)
   - Added detailed instructions for UI/UX Tasks (with Godot MCP tools)
   - Added detailed instructions for Code Cleanup Tasks (static typing, constants, refactoring)
   - Added Step 2: Validate work (docs and code separately)
   - Added Step 3: Update `IMPLEMENTATION_PLAN.md` with discoveries
   - Added Step 4: Log in activity.md and commit
   - Added all 14 "Important Rules" from ralph_wiggum_guide.md
   - Changed completion promise to `<promise>COMPLETE</promise>`

**Files Modified:**
- `PROMPT_plan.md` - Completely rewritten (148 lines → matches baseline pattern)
- `PROMPT_build.md` - Completely rewritten (54 lines → 220 lines, matches baseline pattern)
- `activity.md` - This file, documenting the alignment

**Key Changes:**
- Now uses `IMPLEMENTATION_PLAN.md` with checkbox tasks instead of `plan.md` with JSON
- Documentation must be Obsidian format with `[[wiki-links]]`, frontmatter, MOCs
- Every doc must link to at least 2 other docs
- Added emphasis on static typing for all GDScript
- Added signal flow documentation requirements
- Added JSON schema documentation requirements
- Ralph will create BOTH the GDD AND the implementation plan in plan mode

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

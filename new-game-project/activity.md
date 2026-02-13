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

### 2026-02-12 - Cleanup: Fix NotificationToast.tscn script path

**File(s) Modified:** `scenes/NotificationToast.tscn`, `scripts/ui/components/NotificationToast.gd`

**Changes:**
- Fixed script path from `res://scripts/ui/NotificationToast.gd` to `res://scripts/ui/components/NotificationToast.gd`
- Updated UID from `uid://bq3xspq0mdcts` to `uid://gxpv3yh3l120` (correct UID for the actual file)
- Fixed comment in NotificationToast.gd to reflect correct path

**Verified:** Ran project, no errors related to NotificationToast in debug output

**Commit:** `cleanup: fix broken script path in NotificationToast.tscn`

### 2026-02-12 - Cleanup: Fix broken territories.json reference in ConfigurationManager

**File(s) Modified:** `scripts/systems/core/ConfigurationManager.gd`

**Changes:**
- Changed `_load_territories_config()` to load `res://data/hex_tiles.json` instead of non-existent `res://data/territories.json`
- `hex_tiles.json` is the actual territory/hex data file containing blank tiles and special nodes
- Updated comment to reflect it loads hex tiles data

**Verified:** Ran project, no errors. The "Could not open territories.json" warning is now gone. Territory production, hex grid, and save loading all work correctly.

**Commit:** `cleanup: fix broken territories.json reference in ConfigurationManager`

### 2026-02-12 - Cleanup: Create missing GodSpecializationScreen

**File(s) Modified:**
- `scripts/ui/screens/GodSpecializationScreen.gd` (NEW - 415 lines)
- `scenes/GodSpecializationScreen.tscn` (NEW)

**Changes:**
- Created `GodSpecializationScreen.gd` - Full specialization tree screen with 3-panel layout:
  - Left: God selector grid (3 columns, scrollable, shows name/level/role)
  - Center: SpecializationTree component (role tabs, tree visualization)
  - Right: Detail panel (spec name, description, requirements, bonuses, unlock button)
- Created `scenes/GodSpecializationScreen.tscn` - Minimal scene (matches CollectionScreen pattern)
- Follows established patterns: SystemRegistry, unified header, dark purple color palette
- Resolves ScreenManager.gd line 45 reference to non-existent `GodSpecializationScreen.tscn`
- WorldView "Specialization" button now navigates to a working screen

**Verified:** Ran project, navigated to specialization screen via TestHarness. Screen loads with all 43 gods displayed, no errors in debug output.

**Commit:** `cleanup: create missing GodSpecializationScreen scene and script`

### 2026-02-12 - Cleanup: Fix team size mismatch in dungeon systems

**File(s) Modified:** `scripts/systems/dungeon/DungeonCoordinator.gd`, `scripts/systems/dungeon/DungeonManager.gd`

**Changes:**
- DungeonCoordinator.gd allowed team size of 5, DungeonManager.gd allowed 4 — UI (TeamSelectionManager) enforces 4
- Added `const MAX_TEAM_SIZE: int = 4` to both DungeonCoordinator.gd and DungeonManager.gd
- Updated validation in both files to use the constant instead of magic numbers
- Both files now consistently enforce max team size of 4

**Verified:** Ran project, no errors in debug output. No new warnings or errors introduced.

**Commit:** `cleanup: fix team size mismatch in dungeon systems`

### 2026-02-12 - Cleanup: Delete empty ProgressionCoordinator.gd

**File(s) Modified:** `scripts/systems/progression/ProgressionCoordinator.gd` (DELETED)

**Changes:**
- Deleted empty file `ProgressionCoordinator.gd` — contained no implementation (1 blank line)
- Verified no code references exist (only mentioned in docs/analysis and CLEANUP_PLAN.md)

**Verified:** Ran project, no errors in debug output

**Commit:** `cleanup: delete unused empty ProgressionCoordinator.gd`

### 2026-02-12 - Cleanup: Delete unused BattleEffectProcessor.gd

**File(s) Modified:** `scripts/systems/battle/BattleEffectProcessor.gd` (DELETED)

**Changes:**
- Deleted unused `BattleEffectProcessor.gd` (141 lines) — never instantiated or referenced by any code
- Only references were in documentation files (docs/analysis/03_battle.md, docs/MOCs/GameSystems.md)
- File had known issues: used deprecated emit_signal() pattern, tried to get static CombatCalculator from SystemRegistry

**Verified:** Ran project, no errors in debug output

**Commit:** `cleanup: delete unused BattleEffectProcessor.gd`

### 2026-02-12 - Cleanup: Delete unused DungeonTab.gd

**File(s) Modified:** `scripts/ui/screens/DungeonTab.gd` (DELETED)

**Changes:**
- Deleted unused `DungeonTab.gd` (278 lines) — replaced by `DungeonScreen.gd`
- Verified no code references exist (only mentioned in docs/analysis/10_ui_screens.md)
- No scene files reference this script

**Verified:** Ran project, no errors in debug output

**Commit:** `cleanup: delete unused DungeonTab.gd`

### 2026-02-12 - Cleanup: Delete unused scenes and scripts

**File(s) Deleted:**
- `scenes/LoadingScreen.tscn` + `scripts/ui/screens/LoadingScreen.gd` — not referenced anywhere
- `scenes/TerritoryScreen.tscn` + `scripts/ui/screens/TerritoryScreen.gd` — replaced by HexTerritoryScreen
- `scenes/TerritoryRoleScreen.tscn` + `scripts/ui/screens/TerritoryRoleScreen.gd` — not referenced anywhere

**False Positives Corrected:**
- `scenes/ui/battle/BattleResultOverlay.tscn` — actively used by BattleScreen.gd (preloaded)
- `scenes/ui/battle/BattleUnitCard.tscn` — actively used by BattleScreen.gd (preloaded)
- `scenes/ui/battle/WaveRewardEffect.tscn` — actively used by BattleScreen.gd (preloaded)

**Also Updated:**
- `data/shop_config.json` — marked as SKIP (future daily/guild shop feature, not dead code)

**Verified:** Ran project, no errors in debug output. No new warnings introduced.

**Commit:** `cleanup: delete unused scenes and scripts`

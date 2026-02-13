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

### 2026-02-12 - Cleanup: Remove dead signals and functions from EventBus.gd

**File(s) Modified:** `scripts/systems/core/EventBus.gd`

**Changes:**
- Removed 14 unused signals: territory_attacked, territory_defended, role_assigned, role_unassigned, quest_started, quest_completed, quest_progress_updated, tutorial_step_completed, boss_encountered, guild_joined, guild_left, friend_added, friend_removed, message_received
- Removed 3 unused functions: set_debug_mode(), get_event_history(), clear_history()
- Removed unused convenience method: emit_god_level_up() (never called externally)
- Kept achievement_unlocked (used in GameState.gd), show_tutorial_requested, loading_started/completed, game_paused/resumed (all actively used)
- Kept _log_event() and debug vars (used internally by active convenience methods)
- Added typed Array[Dictionary] for _event_history
- File reduced from 192 to 147 lines (-45 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead signals and functions from EventBus`

### 2026-02-12 - Cleanup: Remove dead code from GameCoordinator.gd

**File(s) Modified:** `scripts/systems/core/GameCoordinator.gd`

**Changes:**
- Removed 4 unused functions: `get_system_by_type()`, `pause_game()`, `resume_game()`, `shutdown_game()`
- Removed 2 empty event handlers: `_on_game_paused()`, `_on_game_resumed()`
- Removed signal connections for `game_paused` and `game_resumed` (handlers were empty no-ops)
- Verified all functions had zero external callers via codebase-wide grep
- File reduced from 402 to 360 lines (-42 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead code from GameCoordinator`

### 2026-02-12 - Cleanup: Delete unused BattleFactory.gd

**File(s) Deleted:** `scripts/systems/battle/BattleFactory.gd`

**Changes:**
- Deleted entire `BattleFactory.gd` (105 lines) — never instantiated, never registered in SystemRegistry, no external callers
- All 3 public methods (`create_territory_battle`, `create_dungeon_battle`, `create_arena_battle`) had zero callers
- All 4 private helpers (`_generate_territory_enemies`, `_generate_dungeon_enemies`, `_get_dungeon_waves`, `_create_fallback_enemies`) only called internally
- DungeonCoordinator uses `DungeonManager.get_battle_configuration()` instead — BattleFactory was a dead alternative
- References `EnemyFactory` system that doesn't exist (noted in docs/analysis/03_battle.md)
- Only references were in documentation files (docs/analysis/03_battle.md, docs/MOCs/GameSystems.md)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: delete unused BattleFactory.gd`

### 2026-02-12 - Cleanup: Integrate element multiplier into CombatCalculator damage formula

**File(s) Modified:** `scripts/systems/battle/CombatCalculator.gd`, `scripts/data/DamageResult.gd`

**Changes:**
- Integrated previously-unused `_get_element_multiplier()` into `calculate_damage()` — element advantage/disadvantage now applied during combat
- Added `_get_unit_element()` helper to extract element type from BattleUnit (from source_god.element or source_enemy["element"])
- Element triangle: Fire > Earth > Water > Fire (+30% advantage, -15% disadvantage), Light <> Dark (mutual +30%)
- Updated DamageResult tooltip breakdown to show element advantage/disadvantage percentages
- DamageResult.element_multiplier field (already existed but was never populated) now correctly set

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: integrate element multiplier into CombatCalculator damage formula`

### 2026-02-12 - Cleanup: Remove dead duplicate tracking from SummonManager

**File(s) Modified:** `scripts/systems/collection/SummonManager.gd`, `scripts/ui/summon/SummonResultOverlay.gd`, `scripts/ui/screens/SummonScreen.gd`

**Changes:**
- Removed `_last_summon_duplicates` variable (never written to, always empty)
- Removed `_get_duplicate_mana_reward()` (zero callers)
- Removed `was_duplicate()` and `clear_duplicate_tracking()` (called by UI but functionally dead — dict was never populated)
- Removed `_is_element_soul()` (always returned false, replaced callers with inline `"default"`)
- Removed `duplicate_obtained` signal (never emitted)
- Cleaned up SummonResultOverlay.gd: removed `_was_duplicate()`, dead duplicate badge branch, simplified `_style_god_card()` signature
- Cleaned up SummonScreen.gd: removed 2 `clear_duplicate_tracking()` calls
- SummonManager.gd reduced from 702 to 672 lines (~30 lines removed)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead duplicate tracking from SummonManager`

### 2026-02-12 - Cleanup: Remove unused functions from AwakeningSystem.gd

**File(s) Modified:** `scripts/systems/progression/AwakeningSystem.gd`

**Changes:**
- Removed 4 unused functions (53 lines): `get_ascension_level_from_string()`, `get_awakened_abilities()`, `get_awakened_leader_skill()`, `get_awakened_passive()`
- Verified zero external callers via codebase-wide grep (each function only found in its own definition)
- File reduced from 280 to 227 lines

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead code from AwakeningSystem`

### 2026-02-12 - Cleanup: Remove empty handler from GodProgressionManager.gd

**File(s) Modified:** `scripts/systems/progression/GodProgressionManager.gd`

**Changes:**
- Removed empty `_on_god_sacrificed()` handler (lines 184-188) — function body was just `pass`
- Removed corresponding `event_bus.god_sacrificed.connect(_on_god_sacrificed)` signal connection from `_initialize_dependencies()`
- File reduced from 189 to 178 lines

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove empty handler from GodProgressionManager`

### 2026-02-12 - Cleanup: Remove empty handlers from SacrificeManager.gd

**File(s) Modified:** `scripts/systems/progression/SacrificeManager.gd`

**Changes:**
- Removed empty `_on_god_sacrificed()` handler (body was just `pass`)
- Removed empty `_on_god_awakened()` handler (body was just `pass`)
- Removed their signal connections from `_connect_events()`
- Removed the now-empty `_connect_events()` function and its call from `_ready()`
- File reduced from 239 to 221 lines (-18 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove empty handlers from SacrificeManager`

### 2026-02-12 - Cleanup: Remove unused test functions from equipment system

**File(s) Modified:**
- `scripts/systems/equipment/EquipmentSocketManager.gd`
- `scripts/systems/equipment/EquipmentInventoryManager.gd`
- `scripts/systems/equipment/EquipmentCraftingManager.gd`

**Changes:**
- Removed `_test_socket_operations()` from EquipmentSocketManager.gd (13 lines) — never called, only defined
- Removed `_test_inventory_operations()` from EquipmentInventoryManager.gd (14 lines) — never called, only defined
- Removed `_test_crafting_operations()` from EquipmentCraftingManager.gd (7 lines) — never called, only defined
- All three were inline test stubs with no external callers (verified via codebase-wide grep)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove unused test functions from equipment system`

### 2026-02-12 - Cleanup: Remove legacy Territory code from TerritoryProductionManager

**File(s) Modified:**
- `scripts/systems/territory/TerritoryProductionManager.gd`
- `scripts/ui/territory/TerritoryActionsManager.gd`

**Changes:**
- Removed 9 legacy Territory class functions (~185 lines): `calculate_territory_production()`, `_calculate_god_production_bonus()`, `get_pending_resources()`, `_distribute_resources_by_type()`, `_get_element_material_type()`, `collect_territory_resources()`, `_generate_territory_resources()`, `_get_territory_data()`, `get_total_hourly_production()`
- Removed unused `generation_timers` and `last_update_time` variables
- Simplified `_process_all_territory_generation()` to only call hex node generation (legacy Territory loop was dead — `get_territory_by_id()` method doesn't exist on TerritoryManager)
- Fixed `TerritoryActionsManager._handle_collect_resources()` to use hex system's `collect_node_resources()` instead of broken legacy `collect_territory_resources()` call (was passing String to function expecting Territory object)
- TerritoryProductionManager.gd reduced from 846 to 661 lines (-185 lines)

**Verified:** Ran project, no errors in debug output. Hex node offline production working correctly. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove legacy Territory code from TerritoryProductionManager`

### 2026-02-12 - Cleanup: Remove legacy resource stubs from TerritoryManager

**File(s) Modified:**
- `scripts/systems/territory/TerritoryManager.gd`
- `scripts/ui/territory/TerritoryHeaderManager.gd`

**Changes:**
- Removed 4 legacy stub functions from TerritoryManager.gd (~34 lines): `get_pending_resources()` (always returned `{}`), `collect_territory_resources()` (always returned `{"total": 0, "resources": {}}`), `collect_all_resources()` (wrapper that called collect_territory_resources, zero external callers), `_sum_dictionary_values()` (only used by collect_all_resources)
- All were old Territory system stubs, superseded by hex system's `TerritoryProductionManager.collect_node_resources()`
- Cleaned up TerritoryHeaderManager.gd: removed `_get_territory_pending_resources()` function (called the stub, always got `{}`), removed `total_pending` variable and its always-zero update block from `update_header_summary()`
- Kept the "Pending" stat in header UI — it's still populated by `update_summary_stats()` with a simplified calculation

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove legacy resource stubs from TerritoryManager`

### 2026-02-12 - Cleanup: Remove dead code from DungeonCoordinator.gd

**File(s) Modified:** `scripts/systems/dungeon/DungeonCoordinator.gd`

**Changes:**
- Removed 2 unused local variables in `_on_battle_completed()`: `_dungeon_id` and `_difficulty` — assigned but never read (both `_handle_dungeon_victory()` and `_handle_dungeon_defeat()` re-extract these from `current_dungeon_battle` directly)
- Removed 2 unused public functions: `is_battle_in_progress()` and `get_current_battle_info()` — verified zero external callers via codebase-wide grep
- File reduced from 318 to 307 lines (-11 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead code from DungeonCoordinator`

### 2026-02-12 - Cleanup: Remove unused signals from DungeonManager.gd

**File(s) Modified:** `scripts/systems/dungeon/DungeonManager.gd`

**Changes:**
- Removed `dungeon_unlocked` signal — declared but never emitted and never connected to
- Removed `validation_completed` signal and all 6 `.emit(result)` calls in `validate_dungeon_entry()` — signal was emitted but no code ever connected to it (callers use the direct return value instead)
- File reduced from 774 to 766 lines (-8 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove unused signals from DungeonManager`

### 2026-02-12 - Cleanup: Remove dead code from LootSystem.gd

**File(s) Modified:** `scripts/systems/resources/LootSystem.gd`, `scripts/systems/dungeon/DungeonCoordinator.gd`

**Changes:**
- Removed 2 unused signals: `loot_generated` (emitted but never connected to), `loot_awarded` (emitted but never connected to)
- Removed 3 unused public functions: `generate_battle_rewards()`, `generate_dungeon_rewards()`, `can_roll_loot()` — all had zero external callers
- Removed 2 dead private helpers: `_get_victory_multiplier()`, `_get_difficulty_multiplier()` — only called by the removed public functions
- Updated DungeonCoordinator.gd comment referencing `loot_awarded` signal
- File reduced from 258 to 209 lines (-49 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead code from LootSystem`

### 2026-02-12 - Cleanup: Remove dead debug functions from ResourceManager.gd

**File(s) Modified:** `scripts/systems/resources/ResourceManager.gd`

**Changes:**
- Removed `debug_print_resources()` (lines 198-202) — zero external callers, function body only assigned to unused local vars
- Removed `debug_add_test_resources()` (lines 204-208) — zero external callers
- Corrected CLEANUP_PLAN: `award_resources()` is NOT unused — actively called by `TerritoryProductionManager.gd` line 611-612. Kept it.
- File reduced from 209 to 197 lines (-12 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead debug functions from ResourceManager`

### 2026-02-12 - Cleanup: Remove dead code from ShopManager.gd

**File(s) Modified:** `scripts/systems/shop/ShopManager.gd`

**Changes:**
- Removed `get_featured_packs()` (7 lines) — zero external callers
- Removed `claim_daily_reward()` (16 lines) — zero external callers
- Removed 3 skin wrapper functions: `get_available_skins()`, `get_skins_for_god()`, `purchase_skin()` (18 lines) — zero external callers, ShopScreen.gd calls SkinManager directly
- Removed `_skin_manager` variable and its cache line in `_cache_system_references()` — only used by removed skin wrappers
- Removed dead `emit_signal("crystals_purchased")` on EventBus — signal doesn't exist on EventBus
- Corrected CLEANUP_PLAN: `_event_bus` is NOT unused — actively used for `save_requested.emit()` in purchase flows. Kept it.
- File reduced from 287 to 235 lines (-52 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead code from ShopManager`

### 2026-02-12 - Cleanup: Remove dead code from SkinManager.gd

**File(s) Modified:** `scripts/systems/shop/SkinManager.gd`

**Changes:**
- Removed `_collection_manager` variable — cached from SystemRegistry but never used anywhere
- Removed `_event_bus` variable — only used in dead conditional branches (EventBus has no skin signals)
- Removed 7 unused functions: `get_skins_for_god()`, `get_owned_skins()`, `get_equipped_skin()`, `get_rarity_color()`, `equip_skin()`, `unequip_skin()`, `get_portrait_path()`
- Removed 2 unused signals: `skin_equipped`, `skin_unequipped` — only emitted by removed functions, never connected to
- Removed dead `_event_bus.emit_signal()` calls in `purchase_skin()` — EventBus has no `skin_purchased` signal so `has_signal()` always returned false
- Kept `get_all_skins()`, `is_skin_owned()`, `purchase_skin()` — actively called by ShopScreen.gd
- Kept `can_purchase_skin()`, `get_skin()` — used internally by `purchase_skin()`
- Kept `skin_purchased` signal — emitted on purchase (future listeners)
- File reduced from 228 to 149 lines (-79 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead code from SkinManager`

### 2026-02-12 - Cleanup: Remove unused functions from UICardFactory.gd

**File(s) Modified:** `scripts/utilities/UICardFactory.gd`

**Changes:**
- Removed 9 unused functions: `create_equipment_card()`, `create_territory_card()`, `create_compact_god_card()`, `create_god_grid()`, `create_team_layout()`, `_apply_summon_result_style()`, `_apply_small_icon_style()`, `_apply_detailed_view_style()`, plus 3 equipment style helpers (`_apply_equipment_collection_style`, `_apply_equipment_detailed_style`, `_apply_equipment_icon_style`)
- Removed 3 unused CardStyle enum values: `SUMMON_RESULT`, `SMALL_ICON`, `DETAILED_VIEW`
- Removed dead preloaded scene comments
- Kept `create_god_card()` — actively used by AwakeningGodList.gd, SacrificeGodList.gd, BattleDisplayManager.gd
- Kept `CardStyle.COLLECTION` and `CardStyle.BATTLE_SETUP` — both used by external callers
- Kept `_apply_collection_style()` and `_apply_battle_setup_style()` — called by `create_god_card()`
- Added `:=` type inference to local variables
- File reduced from 218 to 71 lines (-147 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead code from UICardFactory`

### 2026-02-12 - Cleanup: Remove unused functions from JSONDataLoader.gd

**File(s) Modified:** `scripts/utilities/JSONDataLoader.gd`

**Changes:**
- Removed 6 unused static functions (60 lines): `load_files()`, `load_directory()`, `validate_data()`, `clear_cache()`, `set_cache_enabled()`, `get_cache_stats()`
- All had zero external callers — verified via codebase-wide grep
- Kept `load_file()` — preloaded by AwakeningSystem.gd as `GameDataLoader`
- Kept `_cache` and `_cache_enabled` static vars — used internally by `load_file()`
- File reduced from 98 to 38 lines (-60 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead code from JSONDataLoader`

### 2026-02-12 - Cleanup: Remove unused debug function from GodExperienceCalculator.gd

**File(s) Modified:** `scripts/utilities/GodExperienceCalculator.gd`

**Changes:**
- Removed unused `debug_experience_info()` function (10 lines) — zero external callers verified via codebase-wide grep
- File reduced from 79 to 69 lines

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead code from GodExperienceCalculator`

### 2026-02-12 - Cleanup: Remove dead code from GodCardFactory.gd

**File(s) Modified:** `scripts/utilities/GodCardFactory.gd`

**Changes:**
- Removed unused `populate_god_grid()` function (lines 75-92) — zero external callers (other files have their own local `_populate_god_grid()` methods)
- Removed 3 unused filter functions: `get_awakening_filter()`, `get_sacrificeable_filter()`, `get_battle_ready_filter()` — designed for use with `populate_god_grid()`, all had zero external callers
- Kept `create_god_card()` and `_configure_card_for_preset()` — actively used by 7+ files (CollectionScreen, EquipmentGodDisplay, TeamSelectionManager, BattleInfoManager, TowerScreen, etc.)
- File reduced from 108 to 74 lines (-34 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead code from GodCardFactory`

### 2026-02-12 - Cleanup: Remove dead code from ResourceDisplay.gd

**File(s) Modified:** `scripts/ui/components/ResourceDisplay.gd`

**Changes:**
- Removed 8 unused functions from the materials table system: `_show_materials_table()`, `_add_table_header()`, `_populate_materials_table()`, `_add_material_row()`, `_create_header_style()`, `_get_player_resource()`, `_get_resource_from_manager()`, `debug_print_resources()`
- Removed 2 dead helper functions: `_add_expanded_resource_row()` and `_add_material_item()` — defined but never called (replaced by `_add_resource_to_grid()` in the current expanded panel implementation)
- All functions verified to have zero external callers via codebase-wide grep
- Kept all active functionality: expanded panel, resource categories, tap-to-expand, description popups
- File reduced from 941 to 742 lines (-199 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead code from ResourceDisplay`

### 2026-02-12 - Cleanup: Fix broken DebugOverlay initialization and button handlers

**File(s) Modified:** `scripts/ui/components/DebugOverlay.gd`

**Changes:**
- Fixed `_ready()` — was hardcoding `progression_manager = null` and `tutorial_manager = null` instead of fetching from SystemRegistry
- Added `_ensure_managers()` lazy initialization that fetches PlayerProgressionManager and TutorialOrchestrator from SystemRegistry on first use (F1 toggle)
- Fixed all progression button handlers — were calling nonexistent `debug_add_experience()` and `debug_set_level()` methods; now use real API (`add_experience()`) and direct state setting for level jumps
- Fixed `_update_display()` — was calling nonexistent `get_debug_info()` method; now uses real API (`get_player_level()`, `get_player_experience()`, `get_xp_for_next_level()`)
- Fixed tutorial display — was calling nonexistent `get_debug_info()`; now uses `get_current_tutorial_info()` and `is_tutorial_active()`
- Added 3 missing button handlers connected in scene: `_on_reset_tutorials_pressed()`, `_on_test_3_gods_pressed()`, `_on_show_god_count_pressed()`
- Fixed `name` variable shadowing Node.name warning (renamed to `tutorial_name`)
- Added static typing throughout (return types, parameter types, local variables)

**Verified:** Ran project, no errors in debug output. DebugOverlay shadow warning eliminated. All pre-existing warnings unchanged.

**Commit:** `cleanup: fix broken DebugOverlay initialization and button handlers`

### 2026-02-12 - Cleanup: Remove dead code from MainUIOverlay.gd

**File(s) Modified:** `scripts/ui/components/MainUIOverlay.gd`

**Changes:**
- Removed `clear_all_layers()` (7 lines) — zero external callers, only defined in this file
- Removed `debug_layer_status()` (18 lines) — zero external callers, debug-only function
- Corrected CLEANUP_PLAN: `disconnect_header_back_button()` is NOT unused — actively called by WorldView.gd line 102. Kept it.
- File reduced from 343 to 318 lines (-25 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove dead code from MainUIOverlay`

### 2026-02-12 - Cleanup: Remove empty _process() from TaskAssignmentScreen.gd

**File(s) Modified:** `scripts/ui/screens/TaskAssignmentScreen.gd`

**Changes:**
- Removed empty `_process()` function (lines 426-430) — body was just `pass`, called every frame for no reason
- Removed PROCESS section header comment
- File reduced from 431 to 420 lines (-11 lines)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: remove empty _process from TaskAssignmentScreen`

### 2026-02-12 - Cleanup: Cache abilities.json in BattleActionProcessor.gd

**File(s) Modified:** `scripts/systems/battle/BattleActionProcessor.gd`

**Changes:**
- Fixed performance issue: `_get_ability_data()` was calling `FileAccess.open("res://data/abilities.json")` on EVERY skill use during combat
- Added static `_cached_abilities: Dictionary` and `_abilities_loaded: bool` class variables
- Added `_load_abilities_cache()` static function that loads and parses abilities.json once
- `_get_ability_data()` now does a simple dictionary lookup after first lazy load
- No file I/O during combat after first skill use

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: cache abilities.json in BattleActionProcessor`

### 2026-02-12 - Cleanup: Extract magic numbers to constants in CombatCalculator.gd

**File(s) Modified:** `scripts/systems/battle/CombatCalculator.gd`

**Changes:**
- Extracted 15 named constants from magic numbers throughout the file:
  - Damage formula: `DAMAGE_NUMERATOR` (1000.0), `DAMAGE_DENOMINATOR_BASE` (1140.0), `DAMAGE_DEFENSE_SCALE` (3.5)
  - Hit types: `GLANCING_HIT_CHANCE` (0.15), `GLANCING_DAMAGE_MULT` (0.7), `DAMAGE_VARIANCE_MIN/MAX` (0.9/1.1)
  - Elements: `ELEMENT_ADVANTAGE_MULT` (1.3), `ELEMENT_DISADVANTAGE_MULT` (0.85)
  - Healing: `HEAL_VARIANCE_MIN/MAX` (0.95/1.05)
  - Stat scaling: `LEVEL_STAT_SCALE` (0.1), `POWER_PER_LEVEL` (50), `POWER_PER_TIER` (500)
- Added static typing to all local variables across all functions
- No behavioral changes — all values identical to original magic numbers

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: extract constants in CombatCalculator`

### 2026-02-12 - Cleanup: Extract magic numbers to constants in TurnManager.gd

**File(s) Modified:** `scripts/systems/battle/TurnManager.gd`

**Changes:**
- Extracted 3 named constants: `TURN_BAR_SPEED` (0.07), `TURN_BAR_THRESHOLD` (100.0), `MAX_TURN_ITERATIONS` (1000)
- Replaced all 7 magic number usages across `get_turn_order_preview()`, `_fill_turn_queue()`, and `_count_future_turns()`
- Added static typing to `safety_counter` variables
- No behavioral changes — all values identical to original magic numbers

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: extract constants in TurnManager`

### 2026-02-12 - Cleanup: Extract magic numbers to constants in God.gd

**File(s) Modified:** `scripts/data/God.gd`, `scripts/systems/collection/GodFactory.gd`

**Changes:**
- Extracted 6 named constants from magic numbers:
  - `MAX_LEVEL` (40) — used in `can_level_up()`
  - `MIN_SPECIALIZATION_LEVEL` (20) — used in `can_specialize()`
  - `DEFAULT_CRIT_RATE` (15), `DEFAULT_CRIT_DAMAGE` (50), `DEFAULT_RESISTANCE` (15), `DEFAULT_ACCURACY` (0) — Summoners War defaults used in @export var declarations
- Updated `can_level_up()` to use `MAX_LEVEL` instead of magic `40`
- Updated `can_specialize()` to use `MIN_SPECIALIZATION_LEVEL` instead of magic `20`
- Updated `@export var` defaults to use `DEFAULT_*` constants
- Updated `GodFactory.gd` fallback defaults to reference `God.DEFAULT_*` constants instead of hardcoded values
- No behavioral changes — all values identical to original magic numbers

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: extract constants in God.gd`

### 2026-02-12 - Cleanup: Refactor register_core_systems() in SystemRegistry.gd

**File(s) Modified:** `scripts/systems/core/SystemRegistry.gd`

**Changes:**
- Split 144-line `register_core_systems()` into 5 focused phase functions:
  - `_register_core_infrastructure()` — EventBus, SaveManager, ConfigurationManager, ResourceManager, LootSystem
  - `_register_collection_and_territory()` — CollectionManager + 7 territory systems
  - `_register_battle_and_dungeon()` — BattleCoordinator, DungeonManager, DungeonCoordinator
  - `_register_progression()` — PlayerProgressionManager, GodProgressionManager, SacrificeSystem, AwakeningSystem, SacrificeManager, SummonManager
  - `_register_ui_equipment_and_meta()` — ScreenManager, NotificationManager, TutorialOrchestrator, EquipmentManager, SkinManager, ShopManager, TowerManager, FirebaseIntegration
- `register_core_systems()` is now 6 lines (5 function calls)
- Added `:=` type inference to all local variables
- Added `-> void` return types to all new functions
- Registration order preserved exactly — no behavioral changes

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: refactor register_core_systems in SystemRegistry`

### 2026-02-12 - Cleanup: Refactor load_game() in SaveManager.gd

**File(s) Modified:** `scripts/systems/core/SaveManager.gd`

**Changes:**
- Extracted `_read_save_file() -> Dictionary` — handles file I/O, JSON parsing, and error reporting (30 lines)
- Extracted `_load_systems_from_data()` — loads all game systems from save data, shared between `load_game()` and `_apply_save_data()` (38 lines)
- Extracted `_load_system_data()` helper — eliminates repetitive if-has/get-system/has-method pattern (6 lines)
- `load_game()` reduced from 94 lines to 18 lines
- `_apply_save_data()` reduced from 48 lines to 9 lines — eliminated duplicate system loading logic
- Added `:=` type inference and typed parameters to new functions
- File reduced from 479 to 443 lines (-36 lines, with code duplication eliminated)

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: refactor load_game in SaveManager`

### 2026-02-12 - Cleanup: Refactor _handle_dungeon_victory() in DungeonCoordinator.gd

**File(s) Modified:** `scripts/systems/dungeon/DungeonCoordinator.gd`

**Changes:**
- Split 87-line `_handle_dungeon_victory()` into 4 focused functions:
  - `_handle_dungeon_victory()` — now 24 lines, orchestrates victory flow
  - `_generate_victory_rewards()` — loot table generation, first-clear bonus, LootSystem awarding (35 lines)
  - `_merge_rewards()` — shared helper to merge rewards into totals and populate BattleResult for UI (11 lines)
  - `_award_team_experience()` — awards XP to all team gods (8 lines)
- Added static typing throughout new functions (`:String`, `:Dictionary`, `:Node`, `:float`, `:int`, `-> void`, `-> Dictionary`)
- Eliminated duplicated reward-merging loop (was copy-pasted for loot_table and first_clear sources)
- No behavioral changes — all logic preserved exactly
- File reduced from 307 to 301 lines

**Verified:** Ran project, no errors in debug output. All pre-existing warnings unchanged.

**Commit:** `cleanup: refactor _handle_dungeon_victory in DungeonCoordinator`

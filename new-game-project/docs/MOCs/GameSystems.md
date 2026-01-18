---
tags: [moc, game-systems, architecture, overview]
aliases: [Systems MOC, Game Systems Overview]
created: 2026-01-18
updated: 2026-01-18
status: complete
type: map-of-content
---

# Game Systems - Map of Content

**Purpose**: Central navigation hub for all game systems documentation

**Quick Links**: [[GAME_DESIGN_DOCUMENT]] | [[Architecture]] | [[IMPLEMENTATION_PLAN]]

---

## Core Systems

### Foundation Layer
- **[[SystemRegistry]]** - Dependency injection and service locator pattern
- **[[EventBus]]** - Global event distribution (192 signals)
- **[[GameCoordinator]]** - Main game orchestration and initialization
- **[[SaveManager]]** - Persistence, auto-save, offline rewards
- **[[ConfigurationManager]]** - JSON configuration loading

### Resource Management
- **[[ResourceManager]]** - Currency and material tracking
- **[[ResourceEconomy]]** - Complete resource flow documentation (49 resources)
- **[[LootSystem]]** - Drop table calculations and loot generation

---

## Collection & Progression

### God Collection
- **[[CollectionManager]]** - God and equipment inventory
- **[[SummonManager]]** - Gacha summoning with pity system
- **[[GodFactory]]** - God instance creation
- **[[GodCalculator]]** - Stat calculations and power ratings

**Related Docs**:
- [[STAT_BALANCE_GUIDE]] - Damage formulas and stat scaling
- [[god_roles_and_specializations]] - Role system details

### God Progression
- **[[GodProgressionManager]]** - XP gains and leveling (formulas in [[GodProgression]])
- **[[AwakeningSystem]]** - God awakening mechanics (L40→L50)
- **[[SpecializationManager]]** - 84 specialization trees (5 roles × 4 paths × 3 tiers)
- **[[SacrificeSystem]]** - Duplicate god sacrifice for XP
- **[[TraitManager]]** - God trait system

**Key Formulas**:
```gdscript
# Leveling XP
XP_for_level = 200 * 1.2^(level - 2)

# Stat Scaling
stat = base_stat * (1.0 + (level - 1) * 0.1)
```

**Related Files**:
- `scripts/systems/progression/GodProgressionManager.gd` (247 lines)
- `scripts/systems/progression/AwakeningSystem.gd` (189 lines)
- `scripts/systems/progression/SpecializationManager.gd` (312 lines)

---

## Equipment Systems

### Equipment Management
- **[[EquipmentManager]]** - Main equipment coordinator
- **[[EquipmentInventoryManager]]** - Equipment storage
- **[[EquipmentCraftingManager]]** - Recipe-based crafting (10 MVP recipes)
- **[[EquipmentEnhancementManager]]** - Upgrade system (+0→+15)
- **[[EquipmentSocketManager]]** - Gem socket system (0-3 sockets)
- **[[EquipmentStatCalculator]]** - Stat bonus calculations
- **[[EquipmentFactory]]** - Equipment instance creation

**Key Mechanics**:
- 6 equipment slots (weapon, armor, helm, boots, amulet, ring)
- Enhancement: +0→+15 with failure mechanics (30% at +15)
- Sockets: 0-3 sockets, 8 gem types for stat bonuses
- Set bonuses: 2pc/4pc/6pc bonuses

**Related Docs**:
- [[CRAFTING_SYSTEM_SUMMARY]] - Crafting overview
- [[EQUIPMENT_UX_IMPROVEMENTS]] - UX enhancements

**Related Files**:
- `scripts/systems/equipment/EquipmentManager.gd` (267 lines)
- `data/crafting_recipes.json` (10 recipes)
- `data/equipment.json` (equipment definitions)

---

## Territory & Production

### Territory Systems
- **[[TerritoryManager]]** - Territory ownership and management
- **[[HexGridManager]]** - Hex grid calculations (79 nodes, 6 rings)
- **[[TerritoryProductionManager]]** - AFK resource generation
- **[[NodeRequirementChecker]]** - Node unlock requirement validation
- **[[NodeTaskCalculator]]** - Production task efficiency calculations
- **[[NodeProductionInfo]]** - Production metadata
- **[[TaskAssignmentManager]]** - Worker assignment to nodes

**Key Mechanics**:
- 79 hex nodes across 6 rings (Ring 0: base, Ring 1-5: tiers 1-5)
- 8 node types: Mine, Forest, Coast, Hunting, Forge, Temple, Library, Fortress
- Production: 60-second ticks, 12-hour offline cap
- Efficiency bonuses: Role match (+25%), Specialization (+50-200%), Connected nodes (+10-30%)

**Production Formula**:
```gdscript
base_production = node_base * (1 + role_bonus + spec_bonus + connected_bonus)
final_production = base_production * god_tier_multiplier * element_match_bonus
```

**Related Docs**:
- [[RESOURCE_PHILOSOPHY]] - Economy philosophy, player archetypes
- [[HEX_RESOURCE_ALIGNMENT_COMPLETE]] - Hex node resource mapping

**Related Files**:
- `scripts/systems/territory/TerritoryManager.gd` (298 lines)
- `scripts/systems/territory/HexGridManager.gd` (245 lines)
- `data/hex_nodes.json` (91 nodes)

---

## Combat Systems

### Battle Management
- **[[BattleCoordinator]]** - Battle flow orchestration (419 lines)
- **[[TurnManager]]** - Speed-based turn order (ATB system)
- **[[BattleActionProcessor]]** - Damage and action processing
- **[[StatusEffectManager]]** - Buff/debuff/DOT/HOT tracking (30+ effects)
- **[[BattleEffectProcessor]]** - Special effect processing
- **[[BattleAI]]** - Enemy decision logic
- **[[CombatCalculator]]** - Damage formula calculations
- **[[WaveManager]]** - Multi-wave dungeon progression

**Combat Formula** (Summoners War-based):
```gdscript
raw_damage = base_attack * multiplier * (1000 / (1140 + 3.5 * defense))
final_damage = raw_damage * crit_multiplier * variance

# Critical Hit
crit_multiplier = 1.0 + (crit_damage% / 100)

# Variance
variance = random(0.9, 1.1)  # ±10%
```

**Key Mechanics**:
- Turn-based with ATB (Action Time Bar) system
- Speed determines turn order
- Skills: Basic attack (0 cd), Skill 1 (2-3 cd), Skill 2 (3-4 cd), Ultimate (4-5 cd)
- Status effects: Stun, Freeze, Burn, Poison, Bleed, ATK/DEF/SPD buffs/debuffs, etc.

**Related Docs**:
- [[STAT_BALANCE_GUIDE]] - Complete damage formulas (10k+ words)
- [[COMBAT]] - Combat mechanics overview

**Related Files**:
- `scripts/systems/battle/BattleCoordinator.gd` (419 lines)
- `scripts/systems/battle/CombatCalculator.gd` (380 lines)
- `data/abilities.json` (100+ abilities)

---

## Dungeon Systems

### Dungeon Management
- **[[DungeonManager]]** - Dungeon definitions and schedules
- **[[DungeonCoordinator]]** - Dungeon battle orchestration
- **[[DungeonRewardCalculator]]** - Loot and reward calculations
- **[[DungeonDifficultyManager]]** - Difficulty scaling

**Dungeon Overview**:
- **18 Total Dungeons**: 6 Elemental Sanctums, 8 Pantheon Trials, 3 Equipment Dungeons, 1 Hall of Magic
- **4 Difficulties**: Beginner (8E), Intermediate (10E), Advanced (12E), Expert (15E)
- **Daily Rotation**: Mon-Sat elemental sanctums, Weekends pantheon trials, Always-on equipment dungeons
- **Energy Gating**: 150 max, 300s per energy, 6-15 energy per run

**Replayability Drivers**:
1. Substat RNG (0.26% for perfect gear → 385 runs)
2. Enhancement failures (+15 = 30% success)
3. 24+ gods to build (144 equipment pieces total)
4. Daily rotation (login habit formation)
5. Expert difficulty 3.2x more efficient than Beginner

**Related Docs**:
- [[DUNGEON_SYSTEM_COMPLETE]] - Full implementation status
- [[DUNGEON_REPLAYABILITY]] - Replayability mechanics (8k+ words)
- [[DUNGEON_BALANCE_ANALYSIS]] - Balance adjustments

**Related Files**:
- `scripts/systems/dungeon/DungeonManager.gd` (289 lines)
- `data/dungeons.json` (18 dungeons)
- `data/dungeon_waves.json` (210+ wave configurations)

---

## UI Systems

### Screen Management
- **[[ScreenManager]]** - Screen navigation and transitions
- **[[NotificationManager]]** - Toast notifications
- **[[TutorialOrchestrator]]** - Tutorial flow management
- **[[UIManager]]** - General UI coordination

### Screens (21 Total)
**Main Hub**: [[WorldView]] (home screen with 8 navigation buttons)

**Primary Screens**:
- [[BattleScreen]] - Combat UI with unit cards, ability bar, turn order
- [[CollectionScreen]] - God collection grid with filtering/sorting
- [[TerritoryScreen]] - Hex map with garrison and worker assignment
- [[EquipmentScreen]] - 4-panel layout (god selector, slot manager, inventory, stats)
- [[DungeonScreen]] - Tabbed dungeon browser with difficulty selection
- [[SummonScreen]] - Banner display with summon animations
- [[SacrificeScreen]] - Sacrifice and awakening tabs
- [[GodSpecializationScreen]] - Specialization tree visualization
- [[BattleSetupScreen]] - Team selection for battles
- [[ShopScreen]] - MTX shop integration
- [[TaskAssignmentScreen]] - Territory task assignment

**UI Patterns**:
- Coordinator pattern (screens coordinate sub-components)
- SystemRegistry access (no direct system instantiation)
- Signal-based communication (EventBus for inter-system events)
- Factory pattern (GodCardFactory, BattleFactory, etc.)

**Related Docs**:
- [[Architecture]] - UI architecture patterns

**Related Files**:
- `scripts/ui/screens/` (21 screen files)
- `scripts/ui/components/` (70+ component files across 12 categories)

---

## Specialized Systems

### Shop & Monetization
- **[[ShopManager]]** - Shop inventory and purchases
- **[[SkinManager]]** - Cosmetic skins for gods

### Tutorial & Onboarding
- **[[TutorialOrchestrator]]** - Tutorial progression
- **[[FeatureUnlockManager]]** - Feature gating by player level

### Player Progression
- **[[PlayerProgressionManager]]** - Player XP and leveling
- **[[StatisticsManager]]** - Telemetry and analytics

---

## System Architecture

### Initialization Flow (9 Phases)

**Entry Point**: `GameCoordinator._ready()`

```
PHASE 1: Core Infrastructure
├─ EventBus (global events)
├─ SaveManager (persistence)
└─ ConfigurationManager (JSON loading)

PHASE 1.5: Configuration Loading
└─ ConfigurationManager.load_all_configurations()

PHASE 2: Data & Resources
├─ ResourceManager
└─ LootSystem

PHASE 3: Collection
├─ CollectionManager
└─ SummonManager

PHASE 3.5: Territory
├─ HexGridManager
├─ TerritoryManager
├─ TerritoryProductionManager
└─ NodeTaskCalculator

PHASE 4: Battle
└─ BattleCoordinator

PHASE 4.5: Dungeons
├─ DungeonManager
└─ DungeonCoordinator

PHASE 5: Progression
├─ PlayerProgressionManager
├─ GodProgressionManager
├─ SacrificeSystem
└─ AwakeningSystem

PHASE 6: UI
├─ ScreenManager
├─ NotificationManager
└─ TutorialOrchestrator

PHASE 7: Equipment
├─ EquipmentManager
└─ EquipmentStatCalculator

PHASE 8: Shop
├─ SkinManager
└─ ShopManager

PHASE 9: Trait/Role/Spec
├─ TraitManager
├─ RoleManager
├─ SpecializationManager
└─ TaskAssignmentManager
```

### Communication Patterns

**EventBus Signals** (192 total):
- Combat: `damage_dealt`, `unit_defeated`, `battle_started`, `battle_ended`
- Progression: `god_obtained`, `god_level_up`, `god_awakened`
- Resources: `resource_gained`, `resource_spent`, `resource_changed`
- Territory: `territory_captured`, `role_assigned`
- UI: `screen_changed`, `notification_requested`

**SystemRegistry Access**:
```gdscript
var registry = SystemRegistry.get_instance()
var resource_manager = registry.get_system("ResourceManager")
```

**Related Docs**:
- [[Architecture]] - Complete architecture documentation (282 lines)

**Related Files**:
- `scripts/systems/core/SystemRegistry.gd` (130 lines)
- `scripts/systems/core/GameCoordinator.gd` (332 lines)
- `scripts/systems/core/EventBus.gd` (192 lines)

---

## What's Missing (From [[IMPLEMENTATION_PLAN]])

### Critical (Blocks Soft Launch)
- ❌ Crafting Screen UI (backend exists, no UI)
- ❌ Resource tooltips (players don't know what materials are for)
- ❌ God efficiency indicators (no % display in territory UI)
- ❌ Home screen AFK rewards claim (offline production not visible)

### High Priority (Code Quality)
- ⚠️ Large UI files need refactoring (14k+ lines in some components)
- ⚠️ Missing static typing in some systems
- ⚠️ Magic numbers need extraction to constants

### Future Features
- ❌ Social features (friends, leaderboards, guilds)
- ❌ PvP (arena, territory raids)
- ❌ Engagement systems (quests, achievements)

**See**: [[IMPLEMENTATION_PLAN]] for complete task breakdown

---

## Quick Reference

### File Counts
- **Systems**: 54 GDScript files across 17 categories
- **UI Screens**: 21 screen files
- **UI Components**: 70+ component files
- **JSON Configs**: 31 configuration files
- **Documentation**: 73 markdown files

### Data Counts
- **Gods**: 182 gods across 10 pantheons
- **Resources**: 49 resources across 9 categories
- **Hex Nodes**: 79 nodes (91 total including variants)
- **Dungeons**: 18 dungeons × 4 difficulties = 72 dungeon instances
- **Specializations**: 84 specialization nodes
- **Abilities**: 100+ god abilities
- **Equipment**: 20+ equipment templates
- **Recipes**: 10 MVP crafting recipes

### System Status
- ✅ **100% Complete**: Collection, Progression, Combat, Dungeons, Resources
- ✅ **95% Complete**: Territory (UI needs polish)
- ✅ **90% Complete**: Equipment (crafting UI missing)
- ❌ **0% Complete**: Social, PvP, Quests, Achievements

---

## Navigation

**Main Documents**:
- [[GAME_DESIGN_DOCUMENT]] - Master game design document (1,547 lines)
- [[CLAUDE]] - Quick reference master document (352 lines)
- [[Architecture]] - Technical architecture (282 lines)
- [[IMPLEMENTATION_PLAN]] - Prioritized task list (418 lines)

**Specialized MOCs**:
- [[ResourceEconomy]] - Resource flow and economy
- [[GodProgression]] - God leveling, awakening, specialization
- [[CombatMechanics]] - Combat formulas and mechanics
- [[TerritoryManagement]] - Hex grid and production
- [[DungeonSystem]] - Dungeon mechanics and rewards
- [[EquipmentCrafting]] - Equipment and crafting

**Design Documents**:
- [[DESIGN_LOVES]] - Design philosophy and preferences
- [[STAT_BALANCE_GUIDE]] - Complete stat system (10k+ words)
- [[DUNGEON_REPLAYABILITY]] - Replayability mechanics (8k+ words)
- [[RESOURCE_PHILOSOPHY]] - Economy philosophy

---

*This Map of Content was created 2026-01-18 to provide central navigation for all game systems documentation.*

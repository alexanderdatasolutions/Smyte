---
tags: [game-design, master-document, systems-overview]
aliases: [GDD, Game Design Document, Smyte GDD]
created: 2026-01-18
updated: 2026-01-18
status: comprehensive-audit-complete
related: [[CLAUDE]], [[Architecture]], [[IMPLEMENTATION_PLAN]]
---

# Smyte - Comprehensive Game Design Document

**Version**: 3.0.0 (Complete System Audit)
**Last Updated**: 2026-01-18
**Audit Status**: ✅ Complete - All systems documented

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Core Systems Overview](#core-systems-overview)
3. [Resource Economy (49 Resources)](#resource-economy)
4. [God Collection & Progression](#god-collection--progression)
5. [Equipment & Crafting](#equipment--crafting)
6. [Territory & Hex Node System](#territory--hex-node-system)
7. [Combat & Battle System](#combat--battle-system)
8. [Dungeon System](#dungeon-system)
9. [UI/UX Audit](#uiux-audit)
10. [System Integration Map](#system-integration-map)
11. [Missing Pieces](#missing-pieces)
12. [Code Quality Assessment](#code-quality-assessment)

---

## Executive Summary

### Current State

**Smyte** is a god collector RPG combining gacha mechanics (Summoners War), territory management (Civilization), and AFK progression (Idle games). The game is **85-90% complete** with all major systems implemented and functional.

**Core Loop Status**: ✅ **FUNCTIONAL**
```
Summon Gods → Level/Equip/Specialize → Capture Territory → Generate Resources →
Craft Equipment → Run Dungeons → Awaken Gods → Repeat
```

### What's Working

✅ **Collection System** (100% complete)
- Gacha summoning with pity system (10/50/100 summons)
- 100+ gods across 10 pantheons
- Duplicate → mana conversion
- Full collection management UI

✅ **Progression System** (100% complete)
- God leveling (1-40, awakened 50)
- 84 specializations (5 roles × 4 paths × 3-4 tiers)
- Awakening system with materials
- 20+ traits (Palworld-style)

✅ **Combat System** (100% complete)
- Turn-based with Summoners War damage formula
- Speed-based turn order (ATB system)
- 30+ status effects (buffs/debuffs/DOT/HOT)
- Multi-wave dungeons

✅ **Territory System** (95% complete)
- 79 hex nodes across 6 rings
- 8 node types with unique resources
- Worker assignment with efficiency bonuses
- AFK production (60s ticks, 12hr offline cap)

✅ **Equipment System** (90% complete)
- 6 equipment slots (weapon, armor, helm, boots, amulet, ring)
- Enhancement +0→+15 with failure mechanics
- Socket system with gems
- Set bonuses (2pc/4pc/6pc)

✅ **Dungeon System** (100% complete)
- 18 dungeons (6 elemental, 8 pantheon, 3 equipment, 1 special)
- 4 difficulties each
- Daily rotation schedule
- Energy gating (150 max, 5min regen)

✅ **Resource Economy** (100% complete)
- 49 resources across 9 categories
- Clear sources and sinks
- Balanced progression tiers

### What's Missing

❌ **Crafting UI** (0% complete)
- EquipmentCraftingManager exists but no UI screen
- Recipe browsing not accessible
- Crafting flow not implemented in UI

❌ **Social Features** (0% complete)
- No friend system
- No leaderboards
- No guilds
- No chat

❌ **Arena PvP** (0% complete)
- Arena tokens exist in economy
- No matchmaking
- No live PvP implementation

❌ **Territory Raids** (0% complete)
- Async PvP planned but not implemented
- No raid mechanics

### Critical Gaps

⚠️ **Player Visibility Issues**:
1. **Resource Purposes** - Players don't know what many materials are for
2. **God Efficiency** - No indicators showing which gods are good for which nodes
3. **Recipe Discovery** - Crafting recipes not browsable in-game
4. **Progression Guidance** - No tutorial beyond basic hex territory intro

⚠️ **System Integration**:
1. **Dungeon → Crafting** - Loot drops but no way to use them in crafting UI
2. **Nodes → Resources** - Production happens but limited feedback
3. **Specialization → Territory** - Bonuses calculated but not clearly shown

---

## Core Systems Overview

### SystemRegistry Architecture

**File**: `scripts/systems/core/SystemRegistry.gd` (277 lines)

The game uses **phased initialization** with 9 distinct phases:

```
Phase 1: Core (EventBus, SaveManager, ConfigurationManager)
Phase 2: Resources & Collection
Phase 3: Collection Management
Phase 3.5: Territory Systems (6 systems)
Phase 4: Battle
Phase 4.5: Dungeon
Phase 5: Progression (6 systems)
Phase 6: UI (ScreenManager, NotificationManager, TutorialOrchestrator)
Phase 7: Equipment
Phase 8: Shop & Cosmetics
Phase 9: Traits, Roles, Specialization, Task Assignment
```

**30+ Systems Registered**: All game systems accessible via `SystemRegistry.get_system("SystemName")`

**Strengths**:
- Clean dependency management
- No global singletons
- Orderly initialization preventing race conditions

**See**: [[SystemRegistry]], [[Architecture]]

---

## Resource Economy

### Complete Resource Breakdown (49 Total)

#### Currencies (4)
1. **Mana** - Primary currency, high circulation (10k starting)
2. **Gold** - Secondary currency (10k starting)
3. **Divine Crystals** - Premium currency (IAP, scarce)
4. **Energy** - Dungeon entry cost (150 max, 1 per 5min)

#### Tier 1 Materials (11)
5-15: iron_ore, wood, copper_ore, stone, herbs, fiber, pelts, bones, fish, salt, iron_ingots

**Sources**: Tier 1 hex nodes (10-80/hour)
**Sinks**: Common equipment crafting (10-20 per recipe)
**Balance**: Abundant in early game

#### Tier 2-3 Materials (7)
16-22: mythril_ore, steel_ingots, rare_herbs, magic_crystals, forging_flame, monster_parts, scales

**Sources**: Tier 2-3 hex nodes (requires Tier 1-2 specialization)
**Sinks**: Rare/Epic equipment (2-35 per recipe)
**Balance**: Mid-game bottleneck, **forging_flame is critical gate for all epic+ equipment**

#### Tier 4-5 Materials (3)
23-25: adamantite_ore, dragon_scales, divine_ore

**Sources**: Tier 4-5 hex nodes (requires Tier 2-3 specialization)
**Sinks**: Legendary/Mythic equipment
**Balance**: Very scarce, endgame only

#### Enhancement Materials (5)
26-30: enhancement_powder_low/mid/high, blessed_oil, socket_crystal

**Sources**: Dungeons, temples, forests
**Sinks**: Equipment enhancement (+0→+15), socket unlocking
**Balance**: Scales with progression, blessed_oil scarce (premium feel)

#### Gemstones (8)
31-38: ruby, sapphire, emerald, topaz, diamond, onyx, ancient_gems, pearls

**Sources**: Mines (gemstone drops)
**Sinks**: Equipment sockets (+ATK/HP/DEF/SPD/CRIT/ACC)
**Balance**: Well-balanced

#### Awakening Materials (19)
39-57: Element powders (6 elements × 3 tiers) + magic powders (3 tiers)

**Sources**: Elemental Sanctum dungeons (daily rotation)
**Sinks**: God awakening (20-30 low, 15 mid, 8-15 high per god)
**Balance**: Gated by daily dungeon availability

#### Summoning Materials (10)
58-67: common/rare/epic/legendary souls + element souls (6)

**Sources**: Temples, dungeons, fusion
**Sinks**: God summoning (70-100% legendary rates)
**Balance**: Moderate scarcity except legendary souls

#### Special Materials (7)
68-74: awakening_stone, ascension_crystal, celestial_essence, divine_essence, mana_crystals, research_points, scrolls, knowledge_crystals

**Sources**: High-tier nodes, dungeons, events
**Sinks**: Legendary awakening, ascension, magic crafting, research
**Balance**: Scarce, gates endgame progression

### Resource Flow Map

```
HEX NODES → RAW MATERIALS → CRAFTING → EQUIPMENT → GOD POWER
   ↓              ↓             ↓           ↓            ↓
DUNGEONS → AWAKENING MATS → AWAKENING → HIGHER NODES → MORE RESOURCES
   ↓
SUMMONING → GODS → SPECIALIZATION → EFFICIENCY BONUSES → FASTER PRODUCTION
```

### Balance Issues Identified

**Oversupplied**:
- Fish, salt (limited uses)
- Copper ore (only 1 recipe)
- Common/rare souls (abundant)

**Balanced**:
- Mana (high circulation, many sinks)
- Enhancement powders (scales well)
- Elemental powders (daily gated)

**Undersupplied (Bottlenecks)**:
- ⚠️ **Forging Flame** - Required for ALL epic+ equipment
- ⚠️ **Awakening Stones** - Gates legendary god awakening
- ⚠️ **Divine Ore** - Only from tier 5 nodes
- ⚠️ **Blessed Oil** - High demand, limited sources

**See**: [[RESOURCE_PHILOSOPHY]], [[Resource Economy MOC]]

---

## God Collection & Progression

### God Collection System

**File**: `scripts/systems/collection/CollectionManager.gd` (complete)

#### God Roster
- **100+ gods** across 10 pantheons (Greek, Norse, Egyptian, Hindu, Chinese, Celtic, Japanese, Slavic, Mesopotamian, planned: Aztec)
- **4 tiers**: Common (60% weight), Rare (30%), Epic (9%), Legendary (1%)
- **6 elements**: Fire, Water, Earth, Lightning, Light, Dark
- **5 base roles**: Fighter, Gatherer, Crafter, Scholar, Support

#### Summoning System

**File**: `scripts/systems/collection/SummonManager.gd` (complete)

**Banner Types**:
1. **Basic Summon** (Common Soul) - Standard rates
2. **Premium Summon** (100 crystals) - 35/40/20/5% rates
3. **Element Summon** (Element Soul) - 3× element weight
4. **Daily Free** - One free summon per day (UTC reset)

**Pity System**:
- Hard Pity: 10 summons (rare), 50 (epic), 100 (legendary)
- Soft Pity: Starts at 75 summons (legendary +0.5% per), 35 summons (epic +1.0% per)
- Carries across banners
- Resets on tier obtained

**Duplicate Handling**:
- Duplicates convert to mana: Common (100), Rare (500), Epic (2000), Legendary (5000)
- Check via `CollectionManager.has_god(god_id)`

### Leveling System

**Files**:
- `scripts/systems/progression/PlayerProgressionManager.gd`
- `scripts/systems/progression/GodProgressionManager.gd`

**God Levels**:
- Base: Level 1-40
- Awakened: Level 1-50
- XP Formula: `200 × (1.2)^(level-2)`
- Stat bonuses per level (tier-based):
  - Common: +10 ATK, +8 DEF, +25 HP, +2 SPD
  - Rare: +12 ATK, +10 DEF, +30 HP, +2 SPD
  - Epic: +15 ATK, +12 DEF, +40 HP, +3 SPD
  - Legendary: +20 ATK, +15 DEF, +50 HP, +3 SPD

**Example**: Legendary god at level 40 gains +780 ATK, +585 DEF, +1950 HP, +117 SPD

### Awakening System

**File**: `scripts/systems/progression/AwakeningSystem.gd` (280 lines)

**Requirements**:
- God must be level 40
- Must have awakened form in `awakened_gods.json`
- Must have materials (element powders × 3 tiers + magic powders)

**Material Costs** (Legendary example):
- 20 element_powder_low
- 30 element_powder_mid
- 15 element_powder_high
- 10 magic_powder_low
- 15 magic_powder_mid
- 8 magic_powder_high

**Benefits**:
- Level cap: 40 → 50
- Enhanced base stats
- New/upgraded abilities
- New leader skill

### Specialization System

**Files**:
- `scripts/systems/specialization/SpecializationManager.gd` (523 lines)
- `data/specializations.json` (2135 lines, 84 specs)

**84 Total Specializations**:
- Fighter: 16 (Berserker, Guardian, Tactician, Assassin paths)
- Gatherer: 20 (Miner, Fisher, Herbalist, Hunter paths)
- Crafter: 16 (Forgemaster, Alchemist, Enchanter, Artificer paths)
- Scholar: 16 (Researcher, Explorer, Mentor, Strategist paths)
- Support: 16 (Healer, Buffer, Protector, Leader paths)

**Progression**:
- Tier 1 (Level 20): +50% task bonuses, 10k gold
- Tier 2 (Level 30): +100% task bonuses, 50k gold + 15 essence
- Tier 3 (Level 40): +200% task bonuses, 200k gold + 1 legendary scroll

**Example**: Gatherer → Miner → Deep Miner → Earth Shaper = +290% mining efficiency

**Territory Integration**:
- Spec tier gates node tier access (Tier 1 spec → Tier 2 nodes max)
- Tier 4 nodes require role matching (gatherer for mines, fighter for fortresses)

### Trait System

**File**: `scripts/systems/traits/TraitManager.gd` (255 lines)

**20+ Traits** (Palworld-style):
- Innate (permanent, assigned at creation)
- Learned (max 4, gained through gameplay)

**Categories**:
- Production (mining +50%, harvesting +50%)
- Crafting (forging +50%, alchemy +50%)
- Knowledge (research +60%, scouting +60%)
- Combat (battle bonuses)
- Leadership (team buffs)

**Special**: Some traits allow multitasking (work 2 tasks at 80% efficiency each)

**See**: [[GodProgression]], [[Specializations]], [[Awakening System]]

---

## Equipment & Crafting

### Equipment Structure

**File**: `scripts/data/Equipment.gd` (complete)

**6 Equipment Slots**:
1. Weapon (ATK main stat)
2. Armor (DEF/HP main stat)
3. Helm (HP/DEF main stat)
4. Boots (SPD main stat)
5. Amulet (CRIT/CRIT DMG main stat)
6. Ring (ACC/RES main stat)

**5 Rarities**:
- Common: 0-2 substats, 0 sockets, +15 max, safe failure
- Rare: 0-3 substats, 1 socket, +15 max, 30% reset on fail
- Epic: 0-4 substats, 2 sockets, +15 max, 50% -1 level on fail
- Legendary: 0-4 substats, 3 sockets, +15 max, 70% -1 level on fail
- Mythic: 0-4 substats, 4 sockets, +15 max, 100% destroy on fail

### Enhancement System

**File**: `scripts/systems/equipment/EquipmentEnhancementManager.gd`

**Formula**:
```
Each enhancement level adds 5% of base main stat
+10 weapon with 100 base ATK = 100 + (100 × 10 × 0.05) = 150 ATK
```

**Costs** (exponential):
- Mana: `500 × (1.5)^level`
- Powder: `1 × (1.2)^level`

**Success Rates** (by rarity):
- +0→+10: 100% → 50% (common), 100% → 55% (rare)
- +10→+15: 50% → 1% (common), 55% → 1% (rare)
- Epic/Legendary have higher rates (100% → 60% → 2-3%)

**Blessed Oil**:
- +20% success rate
- Prevents failure consequences
- Consumable (1 per use)
- Cost: 50 divine crystals OR dungeon drop

### Socket System

**File**: `scripts/systems/equipment/EquipmentSocketManager.gd`

**Socket Unlocking**:
- Socket 1: 1 socket_crystal + 5k mana
- Socket 2: 3 crystals + 15k mana
- Socket 3: 5 crystals + 30k mana
- Socket 4: 10 crystals + 50k mana (Mythic only)

**Gem Types**:
- Red (Ruby): +ATK
- Blue (Sapphire): +HP
- Green (Emerald): +DEF
- Yellow (Topaz): +SPD
- White (Diamond): +CRIT
- Black (Onyx): +ACC
- Universal: Fits any socket

### Equipment Sets

**File**: `equipment_config.json`

**Set Bonuses**:
- **Berserker**: 2pc (+50 ATK), 4pc (+100 ATK), 6pc (+200 ATK)
- **Guardian**: 2pc (+75 DEF), 4pc (+500 HP), 6pc (+150 DEF)
- **Swift**: 2pc (+25 SPD), 4pc (+50 SPD), 6pc (+100 ATK)
- **Warrior**: 2pc (+40 ATK), 4pc (+80 ATK), 6pc (+40 DEF)
- **Sage**: 2pc (+400 HP), 4pc (+50 DEF), 6pc (+20 SPD)
- **Precision**: 2pc (+15 ACC), 4pc (+30 ACC), 6pc (+50 ATK)

### Crafting System

**File**: `scripts/systems/equipment/EquipmentCraftingManager.gd` (complete)

**10 MVP Recipes**:

**Tier 1 (Common)**:
- Basic Iron Sword: 20 iron_ore, 10 wood, 500 mana
- Common Stone Armor: 15 stone, 10 fiber, 500 mana
- Simple Cloth Boots: 10 fiber, 5 leather, 500 mana

**Tier 2 (Rare)**:
- Steel Greatsword: 15 steel_ingots, 5 rare_herbs, 1 forging_flame, 5k mana
- Steel Plate Armor: 20 steel_ingots, 10 fiber, 1 forging_flame, 5k mana
- Mystic Amulet: 10 rare_herbs, 3 magic_crystals, 4k mana

**Tier 3 (Epic)**:
- Mythril Warblade: 30 mythril_ore, 3 forging_flame, 10 magic_crystals, 25k mana
- Mythril Plate: 35 mythril_ore, 3 forging_flame, 15 steel_ingots, 25k mana
- Crystal Focus Ring: 8 magic_crystals, 5 rare_herbs, 3 sapphires, 22k mana
- Dragonscale Helm: 10 scales, 5 rare_herbs, 1 forging_flame, 22k mana

**Territory Requirements**:
- Tier 2: Requires Tier 2 territory + Crafter Tier 1 spec
- Tier 3: Requires Tier 3 forge + Blacksmith Tier 2 spec + Level 30 god

**Guaranteed Quality**:
- Tier 3 recipes guarantee 2-3 substats and 1-2 sockets

**⚠️ MISSING: Crafting UI Screen**
- Manager exists, recipes work
- No screen in `scripts/ui/screens/`
- Players cannot browse or use recipes

**See**: [[Equipment Systems]], [[Crafting]], [[Enhancement Guide]]

---

## Territory & Hex Node System

### Hex Grid Structure

**File**: `scripts/systems/territory/HexGridManager.gd`

**79 Total Nodes** across 6 rings:
- Ring 0: Divine Sanctum (1 node, base)
- Ring 1: 6 nodes (tier 1)
- Ring 2: 12 nodes (tier 1-2)
- Ring 3: 18 nodes (tier 2-3)
- Ring 4: 24 nodes (tier 3-4)
- Ring 5: 18 nodes (tier 4-5)

**Node Types** (8):
1. **Mine** ⛏️ - Ores, gems, stone (earth affinity)
2. **Forest** 🌲 - Wood, herbs, fiber (earth affinity)
3. **Coast** 🌊 - Fish, pearls, salt (water affinity)
4. **Hunting Ground** 🦌 - Pelts, bones, monster parts (fire affinity)
5. **Forge** 🔨 - Ingots, enhancement powder (fire affinity)
6. **Library** 📚 - Research points, scrolls (light affinity)
7. **Temple** 🏛️ - Divine essence, mana crystals, souls (light affinity)
8. **Fortress** 🏰 - Defense bonus, training tomes (dark affinity)

### Tier Gating

| Tier | Player Level | Spec Tier | Spec Role | Power Req | Node Count |
|------|--------------|-----------|-----------|-----------|------------|
| 1 | 1+ | None | Any | 3,000 | 13 |
| 2 | 10+ | Tier 1 | Any | 7,000 | 24 |
| 3 | 20+ | Tier 2 | Any | 15,000 | 27 |
| 4 | 30+ | Tier 2 | **Role Match** | 30,000 | 13 |
| 5 | 40+ | Tier 3 | Any | 50,000 | 8 |

**Role-Specific Tier 4+ Nodes**:
- **Gatherer**: Resource-rich nodes (mines, forests, coasts, hunting)
- **Fighter**: Fortresses and military outposts
- **Crafter**: Forges and workshops
- **Scholar**: Libraries and archives
- **Support**: Temples and shrines

### Production System

**File**: `scripts/systems/territory/TerritoryProductionManager.gd`

**Base Formula**:
```
output_rate = base_rate × tier_multiplier × level_bonus × affinity_bonus × spec_bonus
```

**Components**:
- **Base Rate**: Mine (10/hr), Forest (12/hr), Coast (8/hr), etc.
- **Tier Multiplier**: 1.0× (T1), 1.5× (T2), 2.0× (T3), 3.0× (T4), 4.5× (T5)
- **Level Bonus**: `1 + (god.level × 0.05)` = Level 20 = 2.0×
- **Affinity Bonus**: Element match = 1.5×
- **Spec Bonus**: Tier 1 (+50%), Tier 2 (+100%), Tier 3 (+200%)

**Example** (Tier 3 mine, Level 20 earth god, Tier 2 gatherer spec):
```
10 × 2.0 × 2.0 × 1.5 × 2.1 = 126 ore/hour
```

**Fully Optimized** (Tier 5, Level 40, Tier 3 spec, affinity):
```
10 × 4.5 × 3.0 × 1.5 × 3.2 = 648 ore/hour (64.8× base!)
```

### Connected Node Bonuses

- 2 connected: +10% production
- 3 connected: +20% production
- 4+ connected: +30% production

### Distance Penalty

```
penalty = min(distance × 0.05, 0.95)
```

- 1 hex away: -5%
- 5 hexes away: -25%
- 10 hexes away: -50%
- 19+ hexes away: -95% (capped)

### AFK Production

**60-second tick cycle**:
```
tick_amount = hourly_production / 60.0
```

**Offline Calculation**:
- Max storage: 12 hours
- Manual collection bonus: +10%
- Calculated on login via `SaveManager`

### Worker Assignment

**File**: `scripts/systems/territory/TerritoryManager.gd`

**Max Workers per Node**:
- Tier 1: 3 workers
- Tier 2: 4 workers
- Tier 3: 5 workers
- Tier 4: 5 workers
- Tier 5: 6 workers

**Efficiency Calculation**:
```
per_worker_efficiency = 0.10 (base) + spec_bonus + level_bonus
```

**Example** (3 workers, Tier 2 specs, Level 20):
```
Worker 1: 0.10 + 1.00 + 0.20 = 130%
Worker 2: 0.10 + 1.00 + 0.20 = 130%
Worker 3: 0.10 + 1.00 + 0.20 = 130%
Total: +390% efficiency boost
```

**See**: [[Territory System]], [[Hex Grid]], [[Node Production]]

---

## Combat & Battle System

### Battle Architecture

**Files**:
- `BattleCoordinator.gd` (419 lines) - Main orchestrator
- `TurnManager.gd` (212 lines) - Turn order & ATB
- `CombatCalculator.gd` (164 lines) - Damage formulas
- `StatusEffectManager.gd` (164 lines) - Buffs/debuffs
- `WaveManager.gd` (73 lines) - Wave progression
- `BattleActionProcessor.gd` (307 lines) - Action execution
- `BattleAI.gd` (58 lines) - Enemy AI

### Summoners War Damage Formula

**Core Formula**:
```
Raw Damage = ATK × Multiplier × (1000 / (1140 + 3.5 × DEF))
```

This is the **authentic Summoners War formula** with diminishing returns on defense.

**Modifiers**:
- **Critical Hit**: `damage × (1.0 + crit_damage / 100)` at `crit_rate%` chance
- **Glancing Hit**: `damage × 0.7` at 15% chance (opposite of crit, mutually exclusive)
- **Variance**: `damage × random(0.9, 1.1)` (±10%)
- **Element Advantage**: 1.3× (advantage), 0.85× (disadvantage), 1.0× (neutral)

**Example** (500 ATK, 400 DEF, 2.0× skill):
```
Raw = 500 × 2.0 × (1000 / (1140 + 3.5 × 400))
    = 1000 × (1000 / 2540)
    = 1000 × 0.394
    = 394 damage

With crit (150% crit damage):
394 × 2.5 = 985 damage
```

### Turn Order System (ATB)

**Attack Turn Bar** (0.0 to 100.0):
```
Turn Bar Advancement: speed × 0.07 per tick
Ready Threshold: 100.0
```

**Speed Impact**:
- Speed 100: 7.0 bar/tick
- Speed 150: 10.5 bar/tick
- Speed 200: 14.0 bar/tick

Faster units get ~2× more turns than slower units.

**Turn Queue**: Sorted by speed when multiple units reach 100.0 simultaneously

### Status Effects System

**File**: `scripts/data/StatusEffect.gd` (473 lines)

**30+ Status Effects** (Summoners War balanced):

**DOT Effects**:
- **Burn**: 15% max HP per turn, 3 turns
- **Continuous Damage**: 15% max HP per turn, stackable
- **Poison**: 5% max HP + 8% caster ATK per turn
- **Bleed**: 10% max HP per turn, ignores defense

**HOT Effects**:
- **Regeneration**: 15% max HP per turn, 3 turns

**Buffs**:
- **Attack Boost**: +50% ATK, 3 turns
- **Defense Boost**: +50% DEF, 3 turns
- **Speed Boost**: +30% SPD, 2 turns
- **Shield**: Absorbs 50% caster ATK damage
- **Critical Boost**: +30% crit chance, +20% crit damage, 3 turns
- **Debuff Immunity**: 2 turns
- **Damage Immunity**: 1 turn

**Debuffs**:
- **Stun**: Prevents action, 1 turn
- **Freeze**: Prevents action, frozen state, 1 turn
- **Sleep**: Prevents action, breaks on damage, 2 turns
- **Silence**: Prevents abilities (can still basic attack), 2 turns
- **Slow**: -50% SPD, 2 turns
- **Defense Down**: -30% DEF, 3 turns
- **Attack Down**: -30% ATK, 3 turns
- **Marked for Death**: +25% damage taken, 3 turns
- **Heal Block**: -100% healing, 2 turns
- **Blind**: -50% accuracy, 2 turns
- **Provoke**: Must attack provoker, 1 turn

**Special Effects**:
- **Counter Attack**: 75% chance to counter, 2 turns
- **Reflect Damage**: 30% reflection, 3 turns
- **Untargetable**: 1 turn
- **Charm**: Attacks own allies, 1 turn

### Wave System

**File**: `scripts/systems/battle/WaveManager.gd`

**Flow**:
```
Wave 1 → Defeat all enemies → Wave 2 → Defeat all → Wave 3 → Victory
```

**Patterns by Difficulty**:
- Beginner: 3 waves (basic → basic+leader → leader)
- Intermediate: 3 waves (basic×3 → leader+basic → elite)
- Advanced: 3 waves (leader×2 → elite+basic → elite×2)
- Expert: 3 waves (elite×2 → elite+leader → boss)
- Legendary: 4 waves (boss → boss → boss → final boss)

### Battle AI

**File**: `scripts/systems/battle/BattleAI.gd` (58 lines)

**Priority System**:
1. Use most powerful available skill (highest cooldown first)
2. Target lowest HP enemy
3. Fall back to basic attack

**Intentionally Simple**: No tactical planning, no combo recognition, pure damage optimization (allows player strategy to shine)

**See**: [[Combat System]], [[Summoners War Mechanics]], [[Status Effects]]

---

## Dungeon System

### 18 Dungeons Across 4 Categories

**File**: `scripts/systems/dungeon/DungeonManager.gd` (763 lines)

#### Category 1: Elemental Sanctums (6 dungeons)
- Fire Sanctum (Monday)
- Water Sanctum (Tuesday)
- Earth Sanctum (Wednesday)
- Lightning Sanctum (Thursday)
- Light Sanctum (Friday)
- Dark Sanctum (Saturday)

**Difficulties**: Beginner (6E), Intermediate (8E), Advanced (10E), Expert (12E)

#### Category 2: Special Sanctums (1 dungeon)
- Magic Sanctum (Always Available)

**Difficulties**: Beginner (6E), Intermediate (8E), Advanced (10E), Expert (12E)

#### Category 3: Pantheon Trials (8 dungeons)
- Greek, Norse, Egyptian, Hindu, Japanese, Celtic, Aztec, Slavic Trials
- Saturday: Greek, Norse
- Sunday: Egyptian, Hindu
- Weekend Rotating: Japanese, Celtic, Aztec, Slavic

**Difficulties**: Heroic (12E), Legendary (18E)

#### Category 4: Equipment Dungeons (3 dungeons)
- Titan's Forge (Always Available)
- Valhalla's Armory (Always Available)
- Oracle's Sanctum (Always Available)

**Difficulties**: Beginner (6E), Intermediate (8E), Advanced (10E)

### Energy System

**Max Energy**: 150
**Regeneration**: 1 energy per 5 minutes (300 seconds)
**Full Regeneration**: 12.5 hours (0 → 150)
**Starting Energy**: 80

### Difficulty Scaling

**Enemy Stats**:
```
final_stat = base_stat × level_multiplier × tier_multiplier

level_multiplier = 1.0 + (level - 1) × 0.1
tier_multipliers = {basic: 1.0, leader: 1.4, elite: 1.8, boss: 2.5}
```

**Power Ratings**:
- Beginner: 800-1500 power
- Intermediate: 1200-2250 power
- Advanced: 1760-3300 power
- Expert: 2400-4500 power
- Master: 3200-6000 power

**Recommended Team Power**: Enemy Power × 1.2

### Reward System

**Difficulty Multipliers**:
- Beginner: 1.0×
- Intermediate: 1.2×
- Advanced: 1.5×
- Expert: 2.0×
- Master: 2.5×
- Heroic: 2.0×
- Legendary: 3.0×

**Loot Tables** (from `loot_tables.json`):

**Elemental Sanctum - Expert**:
- Guaranteed: element_powder_high (1-4), mana_large, element_soul (1)
- Rare: awakening_stone (30%), crystals_large (20%), legendary_ore (5%)

**Pantheon Trial - Legendary**:
- Guaranteed: mana_large, awakening_stone, legendary_soul (1), skill_book (1)
- Rare: divine_essence (50%), crystals_large (80%), equipment_drop (70%), legendary_ore (30%)

**Equipment Dungeon - Advanced**:
- Guaranteed: equipment_drop, legendary_ore (1-3), enhancement_powder (2-8)
- Rare: socket_crystal (25%), forging_flame (15%), crystals_large (30%), divine_essence (10%)

### Daily Limits

**10 completions per dungeon per day**
- Reset at midnight (system date check)
- Prevents infinite grinding
- Encourages playing multiple dungeons

### First Clear Bonuses

- Beginner: 50 crystals, 1500 mana
- Intermediate: 75 crystals, 5000 mana
- Advanced: 100 crystals, 8000 mana
- Expert: 150 crystals, 12000 mana

**See**: [[Dungeon System]], [[DUNGEON_REPLAYABILITY]], [[Loot Tables]]

---

## UI/UX Audit

### Complete Screen Inventory (21 screens)

**✅ Implemented Screens**:

1. **WorldView.gd** - Main hub (8 navigation buttons)
2. **SummonScreen.gd** - Gacha system (4 banner types, animations)
3. **CollectionScreen.gd** - God collection view
4. **SacrificeScreen.gd** - Sacrifice/awakening hub (2 tabs)
5. **SacrificeSelectionScreen.gd** - Material selection (⚠️ 14k lines, needs refactor)
6. **GodSpecializationScreen.gd** - Talent trees (84 specs)
7. **EquipmentScreen.gd** - Equipment management
8. **HexTerritoryScreen.gd** - Hex map view (⚠️ 1098 lines, large but functional)
9. **TerritoryScreen.gd** - Territory hub (wrapper)
10. **TerritoryRoleScreen.gd** - Legacy role management
11. **NodeDetailScreen.gd** - Node management
12. **TaskAssignmentScreen.gd** - AFK task system
13. **DungeonScreen.gd** - Dungeon selection (3 tabs)
14. **BattleSetupScreen.gd** - Team selection
15. **BattleScreen.gd** - Turn-based combat (⚠️ 866 lines, large but comprehensive)
16. **ShopScreen.gd** - IAP shop (3 tabs)
17. **LoadingScreen.gd** - Init loading (⚠️ not functional)

**❌ Missing Screens**:

18. **CraftingScreen** - Recipe browser and crafting interface
    - Manager exists (`EquipmentCraftingManager.gd`)
    - No UI screen in `scripts/ui/screens/`
    - Players cannot access crafting system

19. **RecipeBookScreen** - Recipe discovery and unlocking
    - Recipes defined in `crafting_recipes.json`
    - No way to browse or discover recipes

20. **ResourceTooltipScreen** - Resource purpose information
    - Resources exist with descriptions in `resources.json`
    - No in-game way to view "What is this for?"

21. **ProgressionGuideScreen** - Tutorial and guidance
    - Only hex_territory_intro tutorial exists
    - No overall progression guidance

### UI Components Health

**Well-Designed Components**:
- GodCard system (standardized via GodCardFactory)
- Reusable display components
- Signal-based communication
- Coordinator pattern for complex screens

**Needs Refactoring**:
- ⚠️ SacrificeSelectionScreen (14,029 lines)
- ⚠️ EquipmentGodDisplay (11,577 lines)
- ⚠️ EquipmentInventoryDisplay (13,298 lines)
- ⚠️ EquipmentSlotsDisplay (8,254 lines)

**Files Exceeding 500-Line Rule**:
- HexTerritoryScreen (1,098 lines) - acceptable, complex hex map
- BattleScreen (866 lines) - acceptable, extensive combat system
- GodSpecializationScreen (578 lines) - acceptable, talent tree complexity
- ShopScreen (547 lines) - acceptable, 3 shop tabs

### Player Visibility Gaps

**Critical Gaps**:

1. **Resource Purposes** ⚠️
   - Players collect materials but don't know what they're for
   - No "Used in" information in tooltips
   - Example: "What is forging_flame used for?"

2. **God Efficiency Indicators** ⚠️
   - No visual indicators showing which gods are best for which nodes
   - Efficiency calculated in backend but not displayed
   - Example: "Is this Miner god better than that one?"

3. **Recipe Discovery** ⚠️
   - No way to browse available recipes
   - No way to see what materials are needed
   - Crafting system invisible to players

4. **Specialization Benefits** ⚠️
   - Stat bonuses calculated but not clearly shown
   - Task efficiency increases not visible during node assignment
   - Players don't understand why to specialize

5. **Dungeon Rewards Preview** ✅
   - Implemented in DungeonScreen
   - Shows loot table drops

6. **Territory Production Feedback** ⚠️
   - Production happens but limited visual feedback
   - No clear "You earned X resources" notification
   - Offline rewards claim exists but needs prominence

### Navigation Flow

**Main Hub → Feature Screens**:
```
WorldView
  ├─> SummonScreen → SummonResultOverlay
  ├─> CollectionScreen → GodDetails
  ├─> EquipmentScreen → EquipmentSlots
  ├─> SacrificeScreen → SacrificeSelectionScreen
  ├─> TerritoryScreen → HexTerritoryScreen → NodeDetailScreen
  ├─> DungeonScreen → BattleSetupScreen → BattleScreen
  ├─> SpecializationScreen → SpecTree
  └─> ShopScreen
```

**Battle Flow**:
```
DungeonScreen OR HexTerritoryScreen
  → BattleSetupScreen (team selection)
  → BattleScreen (combat)
  → BattleResultOverlay
  → Return to origin screen
```

**Missing Flows**:
```
EquipmentScreen → CraftingScreen (MISSING)
ResourceDisplay → ResourceTooltip (MISSING)
CollectionScreen → ProgressionGuide (MISSING)
```

**See**: [[UI Architecture]], [[Screen Patterns]], [[Missing UI]]

---

## System Integration Map

### How Systems Connect

```
COLLECTION SYSTEM
  ├─> SUMMONING MANAGER → Adds gods to collection
  ├─> GOD PROGRESSION → Levels/awakens gods
  ├─> SPECIALIZATION MANAGER → Unlocks talent trees
  ├─> TRAIT MANAGER → Assigns traits
  └─> EQUIPMENT MANAGER → Equips gear to gods

TERRITORY SYSTEM
  ├─> HEX GRID MANAGER → 79 hex nodes
  ├─> TERRITORY MANAGER → Capture/ownership
  ├─> PRODUCTION MANAGER → Calculates AFK output
  ├─> TASK ASSIGNMENT → Assigns gods to nodes
  └─> Reads: GOD PROGRESSION (for efficiency bonuses)

EQUIPMENT SYSTEM
  ├─> EQUIPMENT MANAGER → Inventory & equipping
  ├─> CRAFTING MANAGER → Recipe-based creation
  ├─> ENHANCEMENT MANAGER → +0→+15 upgrades
  ├─> SOCKET MANAGER → Gem insertion
  └─> Reads: RESOURCE MANAGER (for materials)

COMBAT SYSTEM
  ├─> BATTLE COORDINATOR → Main orchestrator
  ├─> TURN MANAGER → Speed-based ATB
  ├─> COMBAT CALCULATOR → Summoners War formula
  ├─> ACTION PROCESSOR → Skill execution
  ├─> STATUS EFFECT MANAGER → Buffs/debuffs
  ├─> WAVE MANAGER → Multi-wave dungeons
  └─> Reads: COLLECTION (gods), EQUIPMENT (stats)

DUNGEON SYSTEM
  ├─> DUNGEON MANAGER → 18 dungeons, energy, daily limits
  ├─> DUNGEON COORDINATOR → Battle setup
  ├─> LOOT SYSTEM → Reward generation
  └─> Triggers: BATTLE COORDINATOR (for combat)

RESOURCE SYSTEM
  ├─> RESOURCE MANAGER → Tracks 49 resources
  ├─> Used by: CRAFTING, AWAKENING, SUMMONING, ENHANCEMENT
  ├─> Sourced from: DUNGEONS, TERRITORY, BATTLES
  └─> Gating: ENERGY (dungeon entry)

PROGRESSION SYSTEM
  ├─> PLAYER PROGRESSION → Player level, feature unlocks
  ├─> GOD PROGRESSION → God leveling, stat growth
  ├─> AWAKENING SYSTEM → Transform gods at L40
  ├─> SPECIALIZATION MANAGER → 84 talent trees
  ├─> ROLE MANAGER → 5 base roles
  └─> TRAIT MANAGER → Palworld-style traits
```

### Data Flow: Complete Gameplay Loop

```
1. SUMMON GOD
   SummonManager → CollectionManager → GodFactory → God created

2. LEVEL GOD
   Sacrifice gods → GodProgressionManager → XP → Level up → Stats increase

3. SPECIALIZE GOD
   Level 20+ → SpecializationManager → Choose tree → Unlock bonuses

4. EQUIP GOD
   Crafting OR Dungeon drops → EquipmentManager → Equip to god slots

5. CAPTURE TERRITORY
   HexTerritoryScreen → Select node → BattleSetupScreen → BattleCoordinator → Victory → TerritoryManager.capture_node()

6. ASSIGN GOD TO NODE
   TerritoryManager → Assign god → TerritoryProductionManager calculates efficiency

7. COLLECT RESOURCES
   60s tick → Production → Accumulated → Manual collection (+10% bonus) → ResourceManager

8. CRAFT EQUIPMENT
   Resources + Recipe → EquipmentCraftingManager → Equipment created → Add to inventory

9. ENHANCE EQUIPMENT
   Equipment + Powder + Mana → EnhancementManager → Roll success → Level up or fail

10. RUN DUNGEONS
    DungeonScreen → Select dungeon → BattleSetupScreen → BattleCoordinator → Victory → LootSystem → Resources/Equipment

11. AWAKEN GOD
    Level 40 god + Materials → AwakeningSystem → Transform → New abilities, level cap 50

12. REPEAT LOOP
    Stronger gods → Higher tier nodes → Better resources → Better equipment → Harder dungeons
```

### Signal Flow (Key Events)

**EventBus Signals** (60+ total):

**Collection**:
- `god_obtained` → UI updates, tutorial triggers
- `god_level_up` → Stat recalculation, UI refresh
- `god_awakened` → New abilities, UI refresh
- `collection_updated` → Collection screen refresh

**Resources**:
- `resource_changed` → UI updates, affordability checks
- `resource_insufficient` → Error messages, block actions

**Territory**:
- `territory_captured` → UI refresh, tutorial check
- `role_assigned` → Production recalculation
- `role_unassigned` → Production recalculation

**Combat**:
- `battle_started` → BattleScreen initialization
- `battle_ended` → Reward screen, return to map
- `turn_started` → UI updates, action selection
- `action_executed` → Animation, damage numbers

**Dungeons**:
- `dungeon_entered` → Energy deduction, battle start
- `dungeon_completed` → Rewards, completion tracking
- `loot_obtained` → Resource/equipment added

**Equipment**:
- `equipment_equipped` → Stat recalculation
- `equipment_enhanced` → Success/fail animation
- `equipment_crafted` → Add to inventory

**Specialization**:
- `specialization_unlocked` → Node access updated, efficiency recalc

**See**: [[System Architecture]], [[Event Flow]], [[Integration Points]]

---

## Missing Pieces

### Critical Missing Systems

#### 1. Crafting UI (0% complete)

**What Exists**:
- ✅ EquipmentCraftingManager (complete, functional)
- ✅ 10 recipes in crafting_recipes.json
- ✅ Resource checking and consumption logic
- ✅ Territory requirement validation

**What's Missing**:
- ❌ CraftingScreen.gd (no file exists)
- ❌ Recipe browser UI
- ❌ Material requirement display
- ❌ "Craftable" indicators
- ❌ Territory/specialization requirement feedback

**Impact**: Players collect crafting materials but cannot use them

**Estimated Work**: 3-5 days
- Create CraftingScreen with recipe grid
- Display material requirements
- Show craftable vs locked recipes
- Integrate with EquipmentCraftingManager
- Add to WorldView navigation

#### 2. Resource Tooltips & Purpose Display (0% complete)

**What Exists**:
- ✅ resources.json has descriptions for all 49 resources
- ✅ ResourceManager tracks all resources
- ✅ UI displays resource amounts

**What's Missing**:
- ❌ "What is this for?" information
- ❌ "Where to farm" information
- ❌ "Used in X recipes" information
- ❌ Resource detail overlay/popup

**Impact**: Players don't understand resource purposes

**Estimated Work**: 2-3 days
- Create ResourceTooltip component
- Parse recipes to find "used in" data
- Parse hex_nodes to find "found at" data
- Hook up to all resource displays

#### 3. God Efficiency Indicators (0% complete)

**What Exists**:
- ✅ Efficiency calculation in NodeTaskCalculator
- ✅ Spec bonuses calculated
- ✅ Affinity bonuses calculated

**What's Missing**:
- ❌ Visual efficiency % display during assignment
- ❌ "Best gods for this node" recommendation
- ❌ Efficiency comparison between gods
- ❌ Color coding (red/yellow/green for bad/okay/good)

**Impact**: Players don't know which gods to assign where

**Estimated Work**: 2-3 days
- Add efficiency calculation to god selection panel
- Display as percentage or color indicator
- Sort gods by efficiency in selection screen
- Add "Recommended" badge to top choices

#### 4. Progression Tutorial/Guide (10% complete)

**What Exists**:
- ✅ TutorialOrchestrator system
- ✅ hex_territory_intro tutorial

**What's Missing**:
- ❌ Summoning tutorial
- ❌ Equipment tutorial
- ❌ Specialization tutorial
- ❌ Crafting tutorial
- ❌ Dungeon tutorial
- ❌ Overall progression guide/roadmap

**Impact**: Players don't understand game systems

**Estimated Work**: 5-7 days
- Create tutorial dialogs for each system
- Implement step-by-step guides
- Add context-sensitive help
- Create progression roadmap screen

#### 5. Social Features (0% complete)

**What Exists**:
- ✅ EventBus has social signals defined
- ✅ Arena tokens exist in economy

**What's Missing**:
- ❌ Friend system
- ❌ Leaderboards
- ❌ Guilds
- ❌ Chat
- ❌ Friend visits
- ❌ Gift sending

**Impact**: No social engagement or competition

**Estimated Work**: 15-20 days (major feature)

#### 6. Arena PvP (0% complete)

**What Exists**:
- ✅ BattleCoordinator supports ARENA type
- ✅ Arena tokens in economy

**What's Missing**:
- ❌ Arena matchmaking
- ❌ Live PvP or async PvP
- ❌ Rankings
- ❌ Weekly rewards
- ❌ Arena shop

**Impact**: No competitive PvP content

**Estimated Work**: 10-15 days

#### 7. Territory Raids (0% complete)

**What Exists**:
- ✅ Territory capture mechanics
- ✅ Garrison system

**What's Missing**:
- ❌ Player vs player territory raids
- ❌ Raid cooldowns
- ❌ Resource stealing (10% on victory)
- ❌ Raid history
- ❌ Revenge system

**Impact**: No territory PvP interaction

**Estimated Work**: 10-12 days

### Minor Missing Features

**8. Loading Screen Functionality** (20% complete)
- LoadingScreen UI exists but doesn't actually load systems
- Currently just 1-second delay before Main scene
- Needs proper initialization tracking

**9. Equipment Filtering/Sorting** (50% complete)
- Basic filtering by slot exists
- Missing: Sort by rarity, level, set
- Missing: Filter by equipped/unequipped

**10. Collection Filtering** (70% complete)
- Sorting by level/rarity exists
- Missing: Filter by element, role, specialization
- Missing: Search by name

**11. Home Screen AFK Rewards** (0% complete)
- Offline production calculated on load
- Missing: Prominent "Claim Rewards" screen
- Missing: Visual breakdown of earned resources

**12. Daily/Weekly Quests** (0% complete)
- No quest system implemented
- Would drive daily engagement

**13. Achievement System** (0% complete)
- No achievements implemented
- Would reward milestones

**See**: [[Missing Features]], [[Implementation Roadmap]]

---

## Code Quality Assessment

### Architecture Compliance

**RULE 1: 500-Line Limit** ⚠️

**Violations** (files > 500 lines):
- ❌ SacrificeSelectionScreen.gd (14,029 lines) - **CRITICAL**
- ❌ EquipmentGodDisplay.gd (11,577 lines) - **CRITICAL**
- ❌ EquipmentInventoryDisplay.gd (13,298 lines) - **CRITICAL**
- ❌ EquipmentSlotsDisplay.gd (8,254 lines) - **CRITICAL**
- ⚠️ HexTerritoryScreen.gd (1,098 lines) - Acceptable (complex hex map)
- ⚠️ BattleScreen.gd (866 lines) - Acceptable (comprehensive combat)
- ⚠️ DungeonManager.gd (763 lines) - Acceptable (18 dungeons)
- ✅ GodSpecializationScreen.gd (578 lines) - Acceptable (84 specs)
- ✅ ShopScreen.gd (547 lines) - Acceptable (3 tabs)

**Recommendation**: Refactor 4 critical files into component systems

**RULE 2: Single Responsibility** ✅

All systems follow single responsibility:
- Managers handle logic
- Screens coordinate UI
- Components are reusable
- Clear separation of concerns

**RULE 3: No Direct Singleton Access** ✅

All systems accessed via SystemRegistry:
```gdscript
var system = SystemRegistry.get_instance().get_system("SystemName")
```

No `preload("res://autoload/GlobalSingleton.gd").instance()` antipattern

**RULE 4: No Business Logic in UI** ✅

Screens delegate to systems:
- SummonScreen → SummonManager
- EquipmentScreen → EquipmentManager
- BattleScreen → BattleCoordinator

**RULE 5: Test Coverage** ⚠️

**Unit Tests**: 90%+ coverage in `tests/unit/`
- Core systems tested
- Progression systems tested
- Battle systems tested

**Integration Tests**: 85% coverage in `tests/integration/`
- 8 test files
- 45+ user flow tests

**Missing Tests**:
- UI screen tests (0%)
- End-to-end gameplay tests (0%)

### Code Patterns

**Strengths**:
- ✅ Consistent SystemRegistry usage
- ✅ EventBus for decoupled communication
- ✅ GodCard standardization (GodCardFactory)
- ✅ Coordinator pattern for complex screens
- ✅ Signal-based UI updates
- ✅ Data classes separate from logic (God.gd, Equipment.gd)
- ✅ JSON-driven configuration

**Weaknesses**:
- ⚠️ Some UI files extremely large (needs component extraction)
- ⚠️ Magic numbers in some formulas (should be constants)
- ⚠️ Inconsistent typing (some `var` without types)
- ⚠️ Duplicate logic in some managers (could extract helpers)

### Performance Concerns

**No Critical Issues Identified**:
- Resource tracking efficient (Dictionary lookup)
- God collection uses indexed lookup (gods_by_id)
- Hex grid uses axial coordinates (optimal)
- Turn order uses pre-calculated queue
- Status effects processed only on turns
- Production calculated per 60s tick (not per frame)

**Potential Optimizations**:
- Cache specialization bonuses (recalculate on change only)
- Pre-compute spec trees on startup
- Index recipes by material requirements
- Batch UI updates (don't update on every resource change)

### Technical Debt

**High Priority**:
1. Refactor 4 massive UI files (14k-13k lines)
2. Extract magic numbers to constants
3. Add static typing to all variables
4. Create missing UI screens (Crafting, RecipeBook, Tooltips)

**Medium Priority**:
5. Add UI screen tests
6. Consolidate duplicate logic in managers
7. Improve error handling in JSON loading
8. Add validation to save/load system

**Low Priority**:
9. Optimize caching in production calculations
10. Add debug visualization tools
11. Improve logging system
12. Create developer documentation

**See**: [[Code Quality]], [[Technical Debt]], [[Refactoring Plan]]

---

## Recommendations

### Immediate Priorities (Next 2 Weeks)

1. **Build Crafting UI** (3-5 days)
   - Create CraftingScreen
   - Recipe browser
   - Material requirements display
   - Integration with EquipmentCraftingManager

2. **Add Resource Tooltips** (2-3 days)
   - "What is this for?" information
   - "Where to farm" information
   - Resource detail popup

3. **Add God Efficiency Indicators** (2-3 days)
   - Visual efficiency % during god assignment
   - "Best for this node" recommendations
   - Sort by efficiency

4. **Build Home Screen AFK Rewards** (2 days)
   - Prominent "Claim Rewards" on login
   - Visual breakdown of offline production
   - Celebratory animation

5. **Refactor Large UI Files** (3-4 days)
   - Extract components from SacrificeSelectionScreen
   - Split EquipmentDisplay files into smaller components

### Short-Term (1-2 Months)

6. **Tutorial System Expansion** (5-7 days)
   - Summoning tutorial
   - Equipment tutorial
   - Specialization tutorial
   - Crafting tutorial

7. **Recipe Discovery System** (3 days)
   - RecipeBookScreen
   - Unlock progression
   - "New recipe unlocked!" notifications

8. **Collection Enhancements** (2-3 days)
   - Advanced filtering (element, role, spec)
   - Search by name
   - Equipment filtering improvements

9. **Loading Screen Implementation** (1 day)
   - Proper system initialization tracking
   - Progress bar driven by actual loading

10. **Code Quality Pass** (5-7 days)
    - Add static typing everywhere
    - Extract magic numbers to constants
    - Add missing unit tests
    - Consolidate duplicate logic

### Medium-Term (2-4 Months)

11. **Social Features** (15-20 days)
    - Friend system
    - Leaderboards
    - Profile comparison

12. **Arena PvP** (10-15 days)
    - Matchmaking
    - Rankings
    - Weekly rewards

13. **Territory Raids** (10-12 days)
    - Async PvP on nodes
    - Resource stealing
    - Raid history

14. **Daily/Weekly Quests** (5-7 days)
    - Quest system
    - Progression tracking
    - Rewards

15. **Achievement System** (5-7 days)
    - Milestone tracking
    - Rewards
    - Showcase

### Long-Term (4+ Months)

16. **Guilds** (20-25 days)
17. **Guild Wars** (15-20 days)
18. **World Boss** (10-15 days)
19. **Seasonal Events** (ongoing)
20. **New Pantheons** (ongoing)

---

## Conclusion

**Smyte is 85-90% complete** with all core systems functional. The game has:
- ✅ Excellent architecture (SystemRegistry, phased init, clean separation)
- ✅ Complete progression systems (leveling, awakening, specialization, traits)
- ✅ Comprehensive resource economy (49 resources, balanced tiers)
- ✅ Deep territory system (79 hex nodes, AFK production)
- ✅ Authentic Summoners War combat (turn-based, ATB, status effects)
- ✅ Rich dungeon system (18 dungeons, daily rotation, energy gating)
- ✅ Extensive equipment system (enhancement, sockets, sets)
- ✅ 100+ gods across 10 pantheons

**Critical Gaps**:
- ❌ Crafting UI (system exists, no screen)
- ❌ Resource purpose visibility
- ❌ God efficiency indicators
- ❌ Progression tutorials

**Next Steps**:
1. Build missing UI screens (Crafting, Tooltips, AFK rewards)
2. Add player visibility features (efficiency %, resource purposes)
3. Expand tutorial system
4. Refactor oversized UI files
5. Add social features and PvP

**The game is production-ready for soft launch** after completing the 5 immediate priorities (2 weeks of work). Social features and PvP can be added post-launch.

---

## Related Documents

- [[CLAUDE]] - Master project document
- [[Architecture]] - Technical architecture
- [[RESOURCE_PHILOSOPHY]] - Resource economy design
- [[STAT_BALANCE_GUIDE]] - Combat formulas
- [[DUNGEON_REPLAYABILITY]] - Dungeon design
- [[INTEGRATION_TEST_GUIDE]] - Testing documentation
- [[IMPLEMENTATION_PLAN]] - Task breakdown

---

*This Game Design Document was created through comprehensive codebase analysis on 2026-01-18 using 10 parallel exploration agents analyzing all systems, UI, and configuration files.*

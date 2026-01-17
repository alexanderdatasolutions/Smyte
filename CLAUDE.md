# Smyte - Master Project Document

**Version**: 2.0 | **Last Updated**: 2026-01-16

---

## 📑 Table of Contents

**I. GAME OVERVIEW**
- [Vision Statement](#vision-statement)
- [Game Pillars](#game-pillars)
- [Core Loop](#core-loop)

**II. HEX TERRITORY SYSTEM** ⭐ Core Feature
- [World Map Structure](#world-map-structure)
- [Node Types & Tiers](#node-types--tiers)
- [Territory Mechanics](#territory-mechanics)

**III. PROGRESSION SYSTEMS**
- [God System](#god-system-collection--progression)
- [Specialization Trees](#specialization-trees)
- [Equipment System](#equipment-system)

**IV. RESOURCE ECONOMY** 💎 Critical
- [Resource Philosophy](#resource-economy-philosophy)
- [Resource Categories](#resource-categories)
- [Crafting Recipes](#crafting-recipes)

**V. COMBAT SYSTEM**
- [Battle Mechanics](#battle-mechanics)
- [PvE & PvP](#pve--pvp)

**VI. TECHNICAL ARCHITECTURE**
- [System Registry](#system-registry)
- [File Organization](#file-organization)
- [Code Standards](#code-standards)

**VII. IMPLEMENTATION STATUS**
- [Completed Features](#completed-features)
- [In Progress](#in-progress)
- [Planned](#planned)

---

# I. GAME OVERVIEW

## Vision Statement

Smyte is a **god collector RPG** combining the best elements of:
- **Summoners War**: Gacha summoning, rune/equipment system, turn-based combat
- **Palworld**: Assign creatures to tasks, base building, resource generation
- **RuneScape**: Deep skill trees, specializations, long-term progression loops
- **Civilization**: Hex-based territory map with strategic node capture
- **Clash of Clans**: Async PvP raids on territories, defend your nodes
- **IdleOn**: Big RPG side scroller with tons of AFK gains

**Core Fantasy**: Collect gods from various pantheons, conquer a hex-based world map, assign gods to territories based on their traits and specializations, and build a divine empire.

---

## Game Pillars

### 1. Collection
- Summon gods from Greek, Norse, Egyptian, Japanese, Celtic pantheons
- Pity system guarantees progression
- Duplicates feed into awakening/power-up systems

### 2. Progression
- Gods level up, awaken, and specialize
- Equipment enhancement with Summoners War-style RNG
- Player account progression unlocks features
- **Specialization tiers unlock access to higher-tier nodes**

### 3. Territory & Economy (HEX MAP SYSTEM)
- **Hex-based world map** with ~100+ capturable nodes
- Nodes have tiers (1-5) with specialization requirements
- Distance from base affects hold difficulty
- Resources flow into all other systems
- **Reason to specialize: unlock higher tier nodes**

### 4. Combat
- Turn-based with speed-based turn order
- PvE dungeons with waves
- PvP arena
- **Territory raids** (async PvP)
- **Node defense battles**

---

## Core Loop

```
Summon Gods → Level & Equip → Specialize at L20+
     ↓
Capture Territory Nodes → Assign Workers → Generate Resources
     ↓
Craft Equipment → Enhance & Socket → Increase Power
     ↓
Unlock Higher Tier Nodes → Raid Enemy Territories → Dominate Map
```

---

# II. HEX TERRITORY SYSTEM ⭐

## World Map Structure

The world is a hex grid with your **Divine Sanctum** (base) at center. Nodes spread outward in rings.

```
Ring 0: Base (Divine Sanctum) - Always controlled
Ring 1: 6 adjacent nodes - Tier 1, easy capture
Ring 2: 12 nodes - Tier 1-2
Ring 3: 18 nodes - Tier 2-3
Ring 4: 24 nodes - Tier 3-4
Ring 5+: Outer rings - Tier 4-5, legendary resources
```

**Current Implementation**: Ralph has created 55+ nodes across Rings 0-5 in `hex_nodes.json`

---

## Node Types & Tiers

### Node Type Table

| Type | Icon | Primary Output | Special Tasks | Best Roles |
|------|------|---------------|---------------|------------|
| **Mine** | ⛏️ | Ore, Gems, Stone | Deep Mining, Gem Cutting | Gatherer (Miner spec) |
| **Forest** | 🌲 | Wood, Herbs, Fiber | Logging, Herbalism | Gatherer (Herbalist spec) |
| **Coast** | 🌊 | Fish, Pearls, Salt | Fishing, Pearl Diving | Gatherer (Fisher spec) |
| **Hunting Ground** | 🦌 | Pelts, Bones, Monster Parts | Hunting, Tracking | Gatherer (Hunter spec) |
| **Forge** | 🔨 | Equipment Materials | Smithing, Enchanting | Crafter |
| **Library** | 📚 | Research Points, Scrolls | Research, Training | Scholar |
| **Temple** | 🏛️ | Divine Essence, Mana Crystals | Meditation, Awakening | Support |
| **Fortress** | 🏰 | Defense Bonus, Training | Garrison, War Planning | Fighter |

### Tier Requirements

| Tier | Level Req | Specialization Req | Resources | Example Nodes |
|------|-----------|-------------------|-----------|---------------|
| 1 | 1 | None | Basic (Iron, Wood, Herbs) | Forest Grove, Stone Quarry |
| 2 | 10 | Tier 1 Spec | Uncommon (Steel, Rare Herbs) | Deep Mine, Ancient Forest |
| 3 | 20 | Tier 2 Spec | Rare (Mythril, Magic Crystals) | Crystal Caverns, Dragon's Lair |
| 4 | 30 | Tier 2 Spec + Role Match | Epic (Adamantite, Divine Essence) | Volcanic Forge, Olympus Outpost |
| 5 | 40 | Tier 3 Spec | Legendary (Celestial Ore, God Tears) | Godforge, Infinite Ocean |

---

## Territory Mechanics

### Distance Penalty
Holding nodes far from your base is harder:
```
defense_rating = base_defense * (1 - distance_penalty)
distance_penalty = 0.05 * hex_distance_from_base  # 5% per hex
```

### Connected Node Bonuses
Adjacent controlled nodes provide bonuses:
- **2 connected**: +10% production
- **3 connected**: +20% production, -5% task time
- **4+ connected**: +30% production, -10% task time, bonus defense

### Node Capture Flow
1. **Scout** - Send Explorer god to reveal node details
2. **Challenge** - Battle the node's defenders (PvE or enemy player's garrison)
3. **Capture** - Win battle, node becomes "contested" for 1 hour
4. **Claim** - If unchallenged, node is yours
5. **Garrison** - Assign defender gods to protect from raids

### Territory Raids (Async PvP)
- Scout enemy nodes (costs gold)
- Assemble 4-god raid party
- Battle plays out (can watch replay)
- Win: Steal 10% of pending resources + contest node
- Lose: 8-hour cooldown before retry

---

# III. PROGRESSION SYSTEMS

## God System (Collection & Progression)

### God Tiers
- **Common** (1-star): Farmable, easy to awaken
- **Rare** (2-star): Solid mid-game units
- **Epic** (3-star): Strong endgame gods
- **Legendary** (4-star): Best stats, rare skills
- **Mythic** (5-star): Limited gods, game-breaking abilities

### God Progression
1. **Leveling** (1-60): Costs mana, increases stats
2. **Awakening** (up to 6 stars): Costs awakening materials + duplicates
3. **Specialization** (at level 20+): Choose role path, unlock higher nodes
4. **Equipment** (6 slots): Weapon, Armor, Helmet, Gloves, Boots, Accessory

### God Stats
- **HP**: Health pool
- **Attack**: Physical damage
- **Defense**: Physical damage reduction
- **Speed**: Turn order in battle
- **Crit Rate**: Chance to deal 2x damage
- **Crit Damage**: Multiplier for crits
- **Accuracy**: Hit chance for debuffs
- **Resistance**: Debuff resist chance

---

## Specialization Trees

**Why Specialize?**
1. Unlock higher tier nodes (Tier 2+ requires specs)
2. Massive efficiency bonuses (+50% to +200%)
3. Unique abilities (Tier 3 specs)
4. Node-specific bonuses

### Role Structure
Each role has 4 paths with 4 nodes each (Tier 1 → 2 → 2 → 3):

```
Role (Choose at L20)
  ↓
Tier 1 Spec (4 choices)
  ↓
Tier 2 Spec (2 branches per T1 spec)
  ↓
Tier 3 Spec (1 capstone per branch)
```

**Total**: 84 specializations implemented across 5 roles

### Roles & Example Paths

**Fighter** (Combat & Defense)
- Berserker → Raging Warrior/Blood Dancer → Avatar of Fury
- Guardian → Shield Master/Warden → Immortal Bulwark
- Duelist → Blade Master/Shadow Assassin → Eternal Swordsman
- Commander → War Tactician/Inspiring Leader → Supreme General

**Gatherer** (Resource Extraction)
- Miner → Gem Cutter/Deep Miner → Master Jeweler/Earth Shaper
- Fisher → Pearl Diver/Whale Hunter → Ocean Master/Sea Sovereign
- Hunter → Beast Tracker/Monster Hunter → Apex Predator/Beast Lord
- Herbalist → Alchemist/Botanist → Grand Alchemist/Nature's Chosen

**Crafter** (Equipment Creation)
- Blacksmith → Weaponsmith/Armorsmith → Legendary Smith
- Jeweler → Gem Cutter/Enchanter → Master Artisan
- Runecrafter → Rune Engraver/Mystic Crafter → Arcane Artificer
- Inventor → Engineer/Tinker → Grand Inventor

**Scholar** (Research & Knowledge)
- Researcher → Arcanist/Historian → Archmage/Loremaster
- Trainer → Combat Instructor/Skill Teacher → Grand Master
- Scribe → Scroll Maker/Record Keeper → Sage of Ages
- Strategist → Tactician/Analyst → Supreme Strategist

**Support** (Buffs & Healing)
- Healer → Cleric/Druid → Divine Oracle
- Buffer → Enchanter/Motivator → Supreme Enchanter
- Debuffer → Curseweaver/Hexer → Master of Affliction
- Leader → Overseer/Commander → Divine Emperor

---

## Equipment System

### Equipment Slots (6 Total)
1. **Weapon** - Primary attack source
2. **Armor** - Main defense piece
3. **Helmet** - HP and defense
4. **Gloves** - Attack and crit
5. **Boots** - Speed and HP
6. **Accessory** - Special stats (accuracy, resistance, crit damage)

### Equipment Rarities
- Common (white) - 0 substats
- Rare (blue) - 1-2 substats
- Epic (purple) - 2-3 substats
- Legendary (gold) - 3-4 substats
- Mythic (red) - 4 substats, highest base stats

### Enhancement System (Summoners War style)
- Enhance equipment from +0 to +15
- Costs: Enhancement Powder (low/mid/high) + Mana
- Stats increase by ~10% per +3 levels
- Failure chance increases at +10, +12, +15
- Failed enhancement: Item doesn't level, materials lost

### Socket System
- Equipment can have 0-3 sockets
- Sockets added with Socket Crystals
- Gems inserted into sockets:
  - **Rubies** (Fire): +Attack
  - **Sapphires** (Water): +HP
  - **Emeralds** (Earth): +Defense
  - **Topazes** (Light): +Crit Rate
  - **Onyxes** (Dark): +Crit Damage
  - **Pearls** (Water): +HP or +DEF

---

# IV. RESOURCE ECONOMY 💎

## Resource Economy Philosophy

### Core Principle: Purpose-Driven Resources
**"Every resource must have clear purpose. Make it feel cool to go for what you need."**

This isn't a matching simulator - it's a strategic empire builder where players can specialize in what they enjoy and still progress.

---

## Supported Playstyles

### 🎣 The Fisher King (Pure Gatherer)
- **Fantasy:** "I just want to fish and chill"
- **Path:** Specialize coast/fishing nodes → Ocean Master (Tier 3)
- **Rewards:** 2-3x fish/pearls production, passive income from selling to crafters
- **Cool Factor:** Guild-wide +15% coast production aura, literal mountains of AFK resources

### ⚔️ Arena Gladiator (Pure PvP)
- **Fantasy:** "I only care about combat and rankings"
- **Path:** Raid enemy territories → Steal resources → Buy crafted gear from market
- **Rewards:** Skip territory management, get resources through PvP theft
- **Cool Factor:** 10% theft from raids, 24/7 raiding availability

### 🔨 Master Crafter (Pure Production)
- **Fantasy:** "I want to be THE blacksmith everyone needs"
- **Path:** Specialize forge nodes → Legendary Smith (Tier 3)
- **Rewards:** -30% material costs, +2 guaranteed substats, passive enhancement powder
- **Cool Factor:** Market monopoly on legendary gear, guild dependency

### 📚 The Scholar (Research/Support)
- **Fantasy:** "Knowledge is power, I'll unlock everything first"
- **Path:** Specialize library nodes → unlock recipes/training
- **Rewards:** Early access to recipes, train gods faster, sell knowledge
- **Cool Factor:** Guild research bonuses, unlock content others can't access

### 💤 AFK Emperor (Full Idle)
- **Fantasy:** "I want to login once a day and collect everything"
- **Path:** Strategic node placement → Connected bonuses → Max workers
- **Rewards:** +30% production from connected nodes, optimized overnight gains
- **Cool Factor:** 10 nodes producing 24/7, wake up to full inventory

### 🏴‍☠️ Territory Raider (Conquest Focus)
- **Fantasy:** "I want to control the most valuable nodes"
- **Path:** Rush high-tier nodes → Build supply chains → Defend aggressively
- **Rewards:** Legendary resources from Tier 4-5 nodes, strategic dominance
- **Cool Factor:** Control mythic resource spawn points, gate endgame materials

---

## Resource Categories

**Current Status**: 49 core materials across all tiers and categories

### Currencies (4)
- **Mana** - Primary currency (god leveling, summoning, enhancement)
- **Gold** - Secondary currency (node upgrades, trading)
- **Divine Crystals** - Premium currency (IAP, skins)
- **Energy** - Activity currency (dungeon runs, raids)

### Tier 1 Crafting Materials (13)
Basic resources from Tier 1 nodes:
- `iron_ore`, `copper_ore`, `stone` (Mine)
- `wood`, `herbs`, `fiber` (Forest)
- `fish`, `pearls`, `salt` (Coast)
- `pelts`, `bones` (Hunting)
- `iron_ingots` (Forge)
- `mana_crystals` (Temple)

### Tier 2-3 Crafting Materials (7)
Rare resources from Tier 2-3 nodes:
- `mythril_ore`, `magic_crystals` (Mine)
- `rare_herbs`, `magical_wood` (Forest)
- `steel_ingots`, `forging_flame` (Forge)
- `monster_parts`, `scales` (Hunting)

### Tier 4-5 Crafting Materials (4)
Legendary resources from endgame nodes:
- `adamantite_ore`, `divine_ore` (Mine)
- `celestial_ore` (Tier 5 Mine)
- `celestial_essence` (Tier 5 Temple)

### Enhancement Materials (9)
Equipment upgrade materials:
- `enhancement_powder_low` (Tier 1 Forest/Forge)
- `enhancement_powder_mid` (Tier 2 Forest/Forge)
- `enhancement_powder_high` (Tier 3+ Forge)
- `socket_crystal` (Forge nodes)
- `blessed_oil` (Temple nodes - substat reroll)

### Gemstones (6)
Socketing materials:
- `rubies` (Fire: +Attack)
- `sapphires` (Water: +HP)
- `emeralds` (Earth: +Defense)
- `topazes` (Light: +Crit Rate)
- `onyxes` (Dark: +Crit Damage)
- `pearls` (Water: +HP or +DEF from Coast nodes)
- `ancient_gems` (Tier 3+ mines - legendary socketing)

### Awakening Materials (6 elements × 3 tiers = 18 + 2)
God power-up materials:
- Element powders: `fire_powder_low/mid/high`, `water_powder_low/mid/high`, etc.
- Special: `awakening_stone` (legendary god awakening), `ascension_crystal` (god ascension)

### Special Materials (6)
Unique resources:
- `divine_essence` (Temple - awakening/crafting)
- `research_points` (Library - unlock recipes)
- `scrolls` (Library - teach god abilities)
- `knowledge_crystals` (Library - accelerate training)
- `blessed_oil` (Temple - substat reroll)
- `socket_crystal` (Forge - add sockets)

---

## Crafting Recipes

### Recipe Unlock Progression

**Tier 1 Recipes** (Available from start)
```json
"basic_iron_sword": {
  "equipment_type": "weapon",
  "rarity": "common",
  "level": 1,
  "materials": {
    "iron_ore": 20,
    "wood": 10,
    "mana": 500
  }
}
```

**Tier 2 Recipes** (Level 15+, Tier 2 Forge required)
```json
"steel_longsword": {
  "equipment_type": "weapon",
  "rarity": "rare",
  "level": 15,
  "materials": {
    "steel_ingots": 30,
    "mythril_ore": 10,
    "enhancement_powder_low": 5,
    "mana": 5000
  },
  "territory_required": true,
  "territory_tier_requirement": 2
}
```

**Tier 3 Recipes** (Level 25+, Tier 2 Spec + Tier 3 Forge)
```json
"mythril_warblade": {
  "equipment_type": "weapon",
  "rarity": "epic",
  "level": 35,
  "materials": {
    "mythril_ore": 30,
    "forging_flame": 3,
    "magic_crystals": 10,
    "mana": 25000
  },
  "territory_required": true,
  "territory_tier_requirement": 3,
  "specialization_requirement": "crafter_blacksmith_tier2",
  "god_level_requirement": 30,
  "guaranteed_substats": [
    {"stat": "attack", "value": 150},
    {"stat": "crit_rate", "value": 15}
  ]
}
```

**Current Implementation**: 10 MVP recipes covering common → epic tiers

---

## Node Type Purposes (Why Players Want Each)

**Mine Nodes** - Raw material foundation
- Early: Iron/copper for basic gear (everyone needs)
- Mid: Mythril/magic crystals for rare gear (crafters need)
- Late: Divine ore/perfect gems for mythic gear (endgame requirement)

**Forest Nodes** - Enhancement material source
- Early: Wood for crafting (everyone needs)
- Mid: Enhancement powder (equipment progression)
- Late: Blessed oil for substat rerolls (endgame perfection)

**Coast Nodes** - Gemstone/passive income
- Early: Fish for selling (passive gold income)
- Mid: Pearls for socketing (equipment power spike)
- Late: Black pearls for legendary sockets (rare luxury)

**Hunting Nodes** - Crafting variety materials
- Early: Pelts/bones for leather/bone armor (diversify builds)
- Mid: Monster parts for advanced recipes (niche builds)
- Late: Rare pelts for legendary leather sets (specialized crafters)

**Forge Nodes** - Equipment production hub
- Early: Steel ingots for gear (everyone needs)
- Mid: Forging flames for epic gear (major power spike)
- Late: Divine ore for mythic weapons (endgame BiS)

**Temple Nodes** - Summoning/awakening
- Early: Mana crystals for summoning (god collection)
- Mid: Soul shards for targeted summons (fill roster gaps)
- Late: Divine essence for awakening (god power-ups)

**Library Nodes** - Recipe unlocks/training
- Early: Research points unlock recipes (progression gates)
- Mid: Scrolls for god training (faster leveling)
- Late: Knowledge crystals for legendary recipes (endgame access)

**Fortress Nodes** - Defense/military
- Defense bonuses for connected territories
- Training materials for god leveling
- Strategic value for PvP territory wars

---

## Trading Economy

Players don't need to do everything - specialists can focus and trade:

**Fisher King Trades:**
- Sells: Fish, pearls, salt (excess from 3x production)
- Buys: Crafted gear, enhancement materials

**Master Crafter Trades:**
- Sells: Equipment with perfect substats (monopoly pricing)
- Buys: Raw materials from miners/gatherers

**Territory Raider Trades:**
- Sells: Rare materials from Tier 5 nodes
- Buys: Enhancement services, god training

---

## AFK Optimization Strategy

Strategic placement > button-mashing:

1. **Connected Node Chains** - Build 4+ connected nodes for +30% production
2. **Worker Specialization** - Assign gods with matching specs for +200% efficiency
3. **Upgrade Priority** - Max production on nodes that generate your bottleneck resource
4. **Distance Management** - Keep high-value nodes close to base (95% defense vs 50%)
5. **Garrison Strategy** - Defend key nodes, let low-value nodes be contested

**Result:** Login once/day, collect 24 hours of optimized production, progress faster than active players who don't strategize.

---

## Resource Coherence Rules

1. **Every resource has ≥2 uses** - No dead-end materials
2. **Higher tiers require lower tiers** - Steel needs iron, mythril needs steel
3. **Specialization creates mastery** - Not +10%, but +200% with unique abilities
4. **No forced matching** - Trade/raid to get what you need
5. **AFK-friendly** - Strategic setup > constant clicking

**See RESOURCE_PHILOSOPHY.md for detailed player archetype breakdowns and node efficiency calculations.**

---

# V. COMBAT SYSTEM

## Battle Mechanics

### Turn-Based Combat
- Speed stat determines turn order
- Faster gods act first
- Speed buffs/debuffs affect turn order dynamically

### Battle Actions
1. **Attack** - Deal damage based on ATK vs enemy DEF
2. **Skill 1** - God's first ability (2-turn cooldown)
3. **Skill 2** - God's second ability (3-turn cooldown)
4. **Ultimate** - God's signature move (5-turn cooldown)

### Status Effects
**Buffs:**
- ATK Up, DEF Up, SPD Up, Shield, Immunity, Counter

**Debuffs:**
- ATK Down, DEF Down, SPD Down, Stun, Freeze, Burn, Poison, Bleed

**Duration:** 1-3 turns depending on skill

---

## PvE & PvP

### PvE Dungeons
- **Equipment Dungeons** - Drop specific equipment types (weapon dungeon, armor dungeon)
- **Awakening Sanctums** - Drop element-specific awakening powders
- **Boss Dungeons** - Legendary equipment and materials
- **Wave System** - 3-5 waves per dungeon

### PvP Arena
- **Live PvP** - Real-time 4v4 battles
- **Rankings** - Weekly rewards based on rank
- **Bans** - Each player bans 1 enemy god before battle

### Territory Raids (Async PvP)
- Attack enemy-controlled nodes
- Steal resources on victory
- 8-hour cooldown on losses
- Replay system to watch battles

---

# VI. TECHNICAL ARCHITECTURE

## System Registry

All game systems registered in **SystemRegistry** (singleton) with phased initialization:

```
SystemRegistry (Singleton)
├── Phase 1: Core Data
│   ├── ConfigurationManager
│   └── EventBus
├── Phase 2: Resources & Collection
│   ├── ResourceManager
│   ├── CollectionManager
│   └── SummonManager
├── Phase 3: Equipment
│   ├── EquipmentManager
│   ├── EquipmentEnhancementManager
│   ├── EquipmentSocketManager
│   └── EquipmentStatCalculator
├── Phase 4: Progression
│   ├── PlayerProgressionManager
│   ├── GodProgressionManager
│   ├── AwakeningSystem
│   ├── TraitManager
│   ├── RoleManager
│   └── SpecializationManager
├── Phase 5: Territory (HEX SYSTEM)
│   ├── HexGridManager
│   ├── TerritoryManager
│   ├── TerritoryProductionManager
│   ├── TaskAssignmentManager
│   └── NodeRequirementChecker
├── Phase 6: Battle
│   ├── BattleCoordinator
│   ├── TurnManager
│   ├── StatusEffectManager
│   └── WaveManager
└── Phase 7: Meta
    ├── ShopManager
    ├── SkinManager
    └── SaveManager
```

---

## File Organization

```
new-game-project/
├── scripts/
│   ├── data/           # Data classes (God, Equipment, HexNode, etc.)
│   ├── systems/        # Game systems (managers)
│   │   ├── battle/
│   │   ├── collection/
│   │   ├── equipment/
│   │   ├── progression/
│   │   ├── resources/
│   │   ├── territory/  # HexGridManager, TerritoryManager, etc.
│   │   ├── traits/
│   │   ├── roles/
│   │   ├── specialization/
│   │   ├── tasks/
│   │   └── shop/
│   └── ui/
│       ├── screens/
│       ├── territory/  # HexMapView, NodeCard, etc.
│       └── components/
├── tests/
│   ├── unit/           # One test file per system
│   └── integration/    # Cross-system tests
├── data/               # JSON configs
│   ├── gods.json
│   ├── traits.json
│   ├── roles.json
│   ├── specializations.json
│   ├── tasks.json
│   ├── resources.json
│   ├── crafting_recipes.json
│   ├── hex_nodes.json
│   └── shop_items.json
└── scenes/             # Godot scenes
```

---

## Code Standards

### Rules
1. **Under 500 lines** per file - split if larger
2. **Single responsibility** - each class does one thing
3. **SystemRegistry pattern** - no direct singleton access
4. **Logic in systems** - data classes are dumb containers
5. **Godot 4.5 rules**:
   - NEVER use `var trait` or `var task` - reserved keywords
   - Static factory: `var script = load("path.gd"); var instance = script.new()`

### Testing Requirements
All code changes must include unit tests. Test pattern:
```gdscript
extends RefCounted
var runner = null

func set_runner(test_runner):
    runner = test_runner

func test_method_describes_expected_behavior():
    # Arrange → Act → Assert
    runner.assert_equal(result, expected, "description")
```

**Target**: 90%+ test coverage

---

# VII. IMPLEMENTATION STATUS

## Completed Features ✅

### Core Systems
- [x] God collection and summoning with pity
- [x] Equipment system (6 slots, enhancement, sockets)
- [x] Turn-based combat with status effects
- [x] Player and god progression
- [x] Shop with skins (cosmetic MTX)

### Data Systems (49 Total Resources)
- [x] Trait system (24 traits, 35 god mappings)
- [x] Role system (5 roles)
- [x] Specialization system (84 specializations)
- [x] Task system (24 tasks, 5 categories)
- [x] **Resource economy (49 core materials)**
- [x] **Crafting recipes (10 MVP recipes)**

### Territory System (By Ralph)
- [x] Hex coordinate system (axial coordinates)
- [x] HexNode data structure
- [x] 55+ nodes defined in hex_nodes.json (Rings 0-5)
- [x] TerritoryProductionManager (calculates node production)
- [x] HexGridManager (core hex logic)

### Testing
- [x] 42 unit tests for crafting system (90%+ coverage)
- [x] Test framework for all systems

---

## In Progress 🔄

### Territory System Completion
- [ ] Territory screen UI (hex map view)
- [ ] Node capture flow (scout → challenge → claim)
- [ ] Task assignment UI (assign gods to nodes)
- [ ] Connected node bonus calculation

---

## Planned 📋

### Short-term (Next 2-4 weeks)
- [ ] Territory screen overhaul - Hex map view
- [ ] Node tier gating - Spec requirements enforcement
- [ ] Task assignment UI - Assign gods to nodes
- [ ] Resource production testing - End-to-end flow

### Mid-term (1-2 months)
- [ ] Async PvP raids on territories
- [ ] Guild territories (shared node control)
- [ ] World boss nodes (PvE events)
- [ ] Trading system (player marketplace)

### Long-term (3+ months)
- [ ] Seasonal map events (limited-time nodes)
- [ ] Cross-server territory wars
- [ ] Guild vs Guild territory battles
- [ ] Expanded pantheons (Hindu, Egyptian, Japanese)

---

# VIII. DESIGN DECISIONS

## Hex Grid Size
- Start with ~50 nodes for MVP
- Expand to 100+ in updates
- Ring structure ensures balanced progression

## Distance Penalty
- 5% per hex distance from base
- Creates meaningful strategic choices
- Prevents "grab everything" gameplay

## Raid Cooldowns
- Win: Can raid same node again after 24 hours
- Lose: 8-hour cooldown
- Prevents grief raids

## Node Respawn
- Neutral nodes respawn defenders 24 hours after capture
- Abandoned player nodes return to neutral after 7 days

---

# IX. GLOSSARY

| Term | Definition |
|------|------------|
| **God** | Collectible unit, can fight and work |
| **Trait** | Innate ability affecting task efficiency |
| **Role** | Broad category (Fighter, Gatherer, etc.) |
| **Specialization** | Chosen progression path at level 20+ |
| **HexNode** | Single capturable territory on the map |
| **Garrison** | Gods defending a node |
| **Raid** | Async PvP attack on enemy node |
| **Tier** | Node difficulty/reward level (1-5) |
| **Spec** | Short for specialization |
| **AFK** | Away From Keyboard (idle gameplay) |
| **BiS** | Best in Slot (optimal equipment) |

---

*Last Updated: 2026-01-16 - Resource economy and hex system integration complete*
*Master Document - For Ralph and Claude reference*

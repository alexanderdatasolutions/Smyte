# Smyte - Master Project Document

**Version**: 2.0 | **Last Updated**: 2026-01-16

---

## 📑 Quick Navigation

**[I. OVERVIEW](#i-overview)** • **[II. HEX SYSTEM](#ii-hex-territory-system-)** • **[III. PROGRESSION](#iii-progression)** • **[IV. RESOURCES](#iv-resource-economy-)** • **[V. COMBAT](#v-combat)** • **[VI. TECH](#vi-technical)** • **[VII. STATUS](#vii-status)**

---

# I. OVERVIEW

## Vision
God collector RPG = Summoners War + Palworld + RuneScape + Civ + Clash of Clans + IdleOn

**Core Fantasy**: Collect gods from various pantheons, conquer a hex-based world map, assign gods to territories, build a divine empire.

## Game Pillars
1. **Collection** - Gacha summoning with pity, duplicates → awakening
2. **Progression** - Gods level/awaken/specialize, equipment enhancement
3. **Territory** - Hex map, node capture, resource generation
4. **Combat** - Turn-based PvE/PvP, territory raids

## Core Loop
```
Summon Gods → Level & Equip → Specialize at L20+
     ↓
Capture Territory Nodes → Assign Workers → Generate Resources
     ↓
Craft Equipment → Enhance & Socket → Increase Power
     ↓
Unlock Higher Tier Nodes → Raid Territories → Dominate Map
```

---

# II. HEX TERRITORY SYSTEM ⭐

## World Map
Hex grid with **Divine Sanctum** (base) at center. ~79 nodes across 6 rings.

```
Ring 0: Base (1 node) - Always controlled
Ring 1: 6 nodes - Tier 1, easy capture
Ring 2: 12 nodes - Tier 1-2
Ring 3: 18 nodes - Tier 2-3
Ring 4: 24 nodes - Tier 3-4
Ring 5: 18 nodes - Tier 4-5, legendary resources
```

## Node Types

| Type | Output | Best Role |
|------|--------|-----------|
| **Mine** ⛏️ | Ore, Gems, Stone | Gatherer (Miner) |
| **Forest** 🌲 | Wood, Herbs, Fiber | Gatherer (Herbalist) |
| **Coast** 🌊 | Fish, Pearls, Salt | Gatherer (Fisher) |
| **Hunting** 🦌 | Pelts, Bones, Monster Parts | Gatherer (Hunter) |
| **Forge** 🔨 | Equipment Materials | Crafter |
| **Library** 📚 | Research, Scrolls | Scholar |
| **Temple** 🏛️ | Divine Essence, Mana | Support |
| **Fortress** 🏰 | Defense, Training | Fighter |

## Tier Gating

| Tier | Level | Specialization | Resources |
|------|-------|----------------|-----------|
| 1 | 1 | None | Basic (Iron, Wood, Herbs) |
| 2 | 10 | Tier 1 Spec | Uncommon (Steel, Rare Herbs) |
| 3 | 20 | Tier 2 Spec | Rare (Mythril, Magic Crystals) |
| 4 | 30 | Tier 2 + Role Match | Epic (Adamantite, Divine Ore) |
| 5 | 40 | Tier 3 Spec | Legendary (Celestial Ore, God Tears) |

## Key Mechanics
- **Distance Penalty**: 5% defense reduction per hex from base
- **Connected Bonuses**: 2/3/4+ connected nodes → +10%/+20%/+30% production
- **Territory Raids**: Async PvP, steal 10% resources on win, 8hr cooldown on loss

---

# III. PROGRESSION

## Gods
- **Tiers**: Common/Rare/Epic/Legendary/Mythic (1-5 stars)
- **Progression**: Level (1-60) → Awaken (6 stars) → Specialize (L20+)
- **Stats**: HP, Attack, Defense, Speed, Crit Rate, Crit Damage, Accuracy, Resistance
- **Equipment**: 6 slots (Weapon, Armor, Helmet, Gloves, Boots, Accessory)

## Specializations (84 Total)
**Why Specialize?**
1. Unlock higher tier nodes
2. +50% to +200% efficiency bonuses
3. Unique abilities (Tier 3 specs)

**5 Roles → 4 Paths Each → Tier 1/2/3**
- **Fighter**: Berserker, Guardian, Duelist, Commander
- **Gatherer**: Miner, Fisher, Hunter, Herbalist
- **Crafter**: Blacksmith, Jeweler, Runecrafter, Inventor
- **Scholar**: Researcher, Trainer, Scribe, Strategist
- **Support**: Healer, Buffer, Debuffer, Leader

## Equipment
- **Rarities**: Common/Rare/Epic/Legendary/Mythic (0-4 substats)
- **Enhancement**: +0 to +15 (Summoners War style, failure chance at +10/12/15)
- **Sockets**: 0-3 sockets, insert gems for stat bonuses
- **Gems**: Rubies (+ATK), Sapphires (+HP), Emeralds (+DEF), Topazes (+Crit), Onyxes (+Crit DMG), Pearls (+HP/DEF)

---

# IV. RESOURCE ECONOMY 💎

## Philosophy
**"Every resource must have clear purpose. Make it feel cool to go for what you need."**

Not a matching simulator - specialists can focus on one thing and trade/raid for the rest.

## Supported Playstyles
1. 🎣 **Fisher King** - Pure gathering, 3x fish/pearls, passive income
2. ⚔️ **Arena Gladiator** - Pure PvP, steal resources, skip territory
3. 🔨 **Master Crafter** - Production monopoly, sell gear at premium
4. 📚 **Scholar** - Unlock recipes early, train gods faster
5. 💤 **AFK Emperor** - Strategic placement, 24/7 production
6. 🏴‍☠️ **Territory Raider** - Control tier 5 nodes, gate endgame mats

## Resource Categories (49 Total)

**Currencies (4)**: Mana, Gold, Divine Crystals, Energy

**Tier 1 Materials (13)**
- Mine: `iron_ore`, `copper_ore`, `stone`
- Forest: `wood`, `herbs`, `fiber`
- Coast: `fish`, `pearls`, `salt`
- Hunting: `pelts`, `bones`
- Forge: `iron_ingots`
- Temple: `mana_crystals`

**Tier 2-3 Materials (7)**
- `mythril_ore`, `magic_crystals`, `rare_herbs`, `magical_wood`, `steel_ingots`, `forging_flame`, `monster_parts`, `scales`

**Tier 4-5 Materials (4)**
- `adamantite_ore`, `divine_ore`, `celestial_ore`, `celestial_essence`

**Enhancement (9)**
- `enhancement_powder_low/mid/high`, `socket_crystal`, `blessed_oil`

**Gemstones (7)**
- `rubies`, `sapphires`, `emeralds`, `topazes`, `onyxes`, `pearls`, `ancient_gems`

**Awakening (20)**
- Element powders (fire/water/earth/air/light/dark × 3 tiers)
- `awakening_stone`, `ascension_crystal`

**Special (6)**
- `divine_essence`, `research_points`, `scrolls`, `knowledge_crystals`, `blessed_oil`, `socket_crystal`

## Node Type Purposes

**Mine** - Raw materials for basic → mythic gear
**Forest** - Enhancement powders for equipment upgrades
**Coast** - Gemstones for sockets, passive gold from fish
**Hunting** - Crafting variety (leather/bone armor)
**Forge** - Equipment production hub
**Temple** - Summoning/awakening materials
**Library** - Recipe unlocks, god training
**Fortress** - Defense bonuses, strategic PvP value

## Crafting (10 MVP Recipes)
- **Tier 1**: Common gear, basic materials
- **Tier 2**: Rare gear, requires Tier 2 forge + materials
- **Tier 3**: Epic gear, requires Tier 2 spec + Tier 3 forge + guaranteed substats

## AFK Strategy
1. Build 4+ connected nodes → +30% production
2. Assign matching spec workers → +200% efficiency
3. Max production upgrades on bottleneck resources
4. Keep high-value nodes close to base (95% defense vs 50%)
5. Strategic garrison placement

---

# V. COMBAT

## Mechanics
- **Turn-Based**: Speed determines turn order
- **Actions**: Attack, Skill 1 (2cd), Skill 2 (3cd), Ultimate (5cd)
- **Status Effects**: Buffs (ATK/DEF/SPD Up, Shield, Immunity) | Debuffs (ATK/DEF/SPD Down, Stun, Freeze, Burn, Poison, Bleed)

## Game Modes
- **Equipment Dungeons**: Drop specific gear types
- **Awakening Sanctums**: Drop element powders
- **Boss Dungeons**: Legendary equipment
- **PvP Arena**: Live 4v4, weekly rankings
- **Territory Raids**: Async PvP on nodes, steal resources

---

# VI. TECHNICAL

## System Registry (Phased Init)

```
Phase 1: Core Data (ConfigurationManager, EventBus)
Phase 2: Resources & Collection (ResourceManager, CollectionManager, SummonManager)
Phase 3: Equipment (EquipmentManager, Enhancement, Socket, StatCalculator)
Phase 4: Progression (PlayerProgression, GodProgression, Awakening, Traits, Roles, Specs)
Phase 5: Territory (HexGridManager, TerritoryManager, Production, TaskAssignment)
Phase 6: Battle (BattleCoordinator, TurnManager, StatusEffects, Waves)
Phase 7: Meta (ShopManager, SkinManager, SaveManager)
```

## File Structure

```
new-game-project/
├── scripts/
│   ├── data/          # God, Equipment, HexNode classes
│   ├── systems/       # All managers
│   └── ui/            # Screens and components
├── tests/
│   ├── unit/          # 90%+ coverage target
│   └── integration/
├── data/              # JSON configs
│   ├── gods.json, traits.json, roles.json, specializations.json
│   ├── tasks.json, resources.json, crafting_recipes.json
│   ├── hex_nodes.json (79 nodes by Ralph)
│   └── shop_items.json
└── scenes/            # Godot .tscn files
```

## Code Rules
1. **<500 lines** per file
2. **Single responsibility** per class
3. **SystemRegistry pattern** - no direct singleton access
4. **Godot 4.5**: Never use `var trait` or `var task` (reserved keywords)
5. **90%+ test coverage** - unit tests for all systems

---

# VII. STATUS

## ✅ Completed
- God collection, summoning, pity system
- Equipment system (6 slots, enhancement, sockets)
- Turn-based combat with status effects
- Shop with cosmetic skins
- **49 core resources** aligned with hex nodes
- **10 MVP crafting recipes**
- **84 specializations** across 5 roles
- **24 traits**, **24 tasks**
- **79 hex nodes** (Rings 0-5 by Ralph)
- **42 unit tests** for crafting (90%+ coverage)

## 🔄 In Progress
- Territory screen UI (hex map view)
- Node capture flow (scout → challenge → claim)
- Task assignment UI (assign gods to nodes)

## 📋 Planned
**Short-term**: Territory UI, node tier gating, task assignment
**Mid-term**: Async PvP raids, guild territories, trading system
**Long-term**: Seasonal events, cross-server wars, expanded pantheons

---

# VIII. DESIGN DECISIONS

- **Hex Grid**: Start 79 nodes, expand to 100+ later
- **Distance Penalty**: 5% per hex (strategic expansion choices)
- **Raid Cooldowns**: 24hr on win, 8hr on loss (prevent grief)
- **Node Respawn**: Neutral 24hr, abandoned player 7 days
- **Resource Philosophy**: Every resource ≥2 uses, no dead ends, trading encouraged

---

# IX. GLOSSARY

| Term | Definition |
|------|------------|
| **God** | Collectible unit (fight + work) |
| **Spec** | Specialization (chosen at L20+) |
| **HexNode** | Territory on the map |
| **Tier** | Node difficulty/reward (1-5) |
| **AFK** | Away From Keyboard (idle gameplay) |
| **BiS** | Best in Slot (optimal gear) |

---

**See RESOURCE_PHILOSOPHY.md for detailed player archetypes and node efficiency calculations.**

*Master Document - For Ralph and Claude reference*

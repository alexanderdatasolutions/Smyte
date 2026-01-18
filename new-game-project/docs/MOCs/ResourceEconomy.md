---
tags: [moc, resources, economy, crafting, materials]
aliases: [Resource MOC, Economy Guide, Material Guide]
created: 2026-01-18
updated: 2026-01-18
status: complete
type: map-of-content
---

# Resource Economy - Map of Content

**Purpose**: Complete reference for all 49 resources, sources, sinks, and flow

**Quick Links**: [[GAME_DESIGN_DOCUMENT]] | [[GameSystems]] | [[RESOURCE_PHILOSOPHY]]

---

## Resource Categories Overview

**Total Resources**: 49 core materials + 6 currency variants = **55 tracked items**

| Category | Count | Purpose |
|----------|-------|---------|
| Currencies | 4 | Mana, Gold, Divine Crystals, Energy |
| Tier 1 Materials | 13 | Basic gathering (iron, wood, herbs, fish, etc.) |
| Tier 2-3 Materials | 8 | Advanced materials (mythril, steel, rare_herbs, magic_crystals) |
| Tier 4-5 Materials | 3 | Endgame materials (adamantite, dragon_scales, divine_ore) |
| Enhancement Materials | 5 | Equipment upgrades (powders, oils, socket crystals) |
| Gemstones | 8 | Socket stat bonuses (ruby, sapphire, emerald, etc.) |
| Awakening Materials | 20 | Element powders (6 elements × 3 tiers) + universal |
| Summoning Materials | 10 | Souls (4 rarity tiers + 6 element souls) |
| Special Materials | 8 | Divine essence, research points, scrolls, etc. |

**Related Files**:
- `data/resources.json` (v2.2.0, 105+ resource definitions)
- `scripts/systems/resources/ResourceManager.gd` (211 lines)

---

## Complete Resource List

### 💰 Currencies (4)

| Resource | Cap | Regen | Sources | Sinks |
|----------|-----|-------|---------|-------|
| **mana** | ∞ | Territory (50-200/hr) | Dungeons, Territory, Sacrifice | Summoning (10k), Crafting (500-25k), Awakening (50k) |
| **gold** | ∞ | Crafting conversion | Selling fish, Material trades | Crafting (1k-100k), Enhancement (1k-100k), Spec research (10k-200k) |
| **divine_crystals** | 99,999 | Territory (1-3/hr) | MTX, Territory, Dungeons | Premium summons (100), Blessed oil (50), Energy refresh (30), Cosmetics (200-500) |
| **energy** | 150 | 1 per 300s (5min) | Time regen, Crystal refresh | Dungeons (6-15 per run) |

**Key Mechanics**:
- Energy: 150 max, regenerates 12 per hour, full refill in 12.5 hours
- Divine Crystals: Premium currency with 99,999 storage cap
- Mana/Gold: Unlimited storage

---

### ⛏️ Tier 1 Materials (13) - Basic Gathering

| Resource | Node Source | Task | Recipes | Status |
|----------|------------|------|---------|--------|
| **iron_ore** | Mine T1 | mining | basic_iron_sword, basic_iron_armor | ✅ Full use |
| **copper_ore** | Mine T1 | ore_extraction | copper_amulet | ✅ Full use |
| **stone** | Mine T1 | quarrying | basic_iron_armor, fortified_boots | ✅ Full use |
| **wood** | Forest T1 | logging | basic_iron_sword, steel_greatsword | ✅ Full use |
| **herbs** | Forest T1 | herbalism | basic_iron_armor, steel_plate_armor | ✅ Full use |
| **fiber** | Forest T1 | foraging | copper_amulet, mystic_ring | ✅ Full use |
| **pelts** | Hunting T1 | hunting | fortified_boots | ✅ Full use |
| **bones** | Hunting T1 | tracking | (bone armor, future) | ⚠️ Minimal use |
| **fish** | Coast T1 | fishing | (food/trade system?) | ⚠️ No sink |
| **salt** | Coast T1 | salt_harvesting | (preservation?) | ⚠️ No sink |
| **pearls** | Coast T1 | pearl_diving | Socket stat bonus (HP/DEF) | ✅ Full use |
| **iron_ingots** | Forge T1 | smelting | basic_iron_sword, steel_greatsword | ✅ Full use |
| **divine_essence** | Temple T1 | summoning | (spec research?) | ⚠️ Uncertain |
| **mana_crystals** | Temple T1 | channeling | (mana boost?) | ⚠️ Uncertain |

**Production Rates** (per hour, base):
- Mine T1: 10-15 ore/hr
- Forest T1: 8-12 wood/herbs/hr
- Coast T1: 5-8 fish/pearls/hr
- Hunting T1: 6-10 pelts/bones/hr
- Forge T1: 3-5 ingots/hr (requires ore)

**Unlock**: Player Level 1, no specialization required

---

### 🔷 Tier 2-3 Materials (8) - Advanced Resources

| Resource | Node Source | Unlock | Recipes | Status |
|----------|------------|--------|---------|--------|
| **mythril_ore** | Mine T2 | Tier 1 Miner spec | mythril_warblade, mythril_full_plate | ✅ Full use |
| **steel_ingots** | Forge T2 | Tier 1 Crafter spec | steel_greatsword, steel_plate_armor | ✅ Full use |
| **rare_herbs** | Forest T2 | Tier 1 Herbalist spec | steel_plate_armor, mystic_ring, crystal_pendant | ✅ Full use |
| **magic_crystals** | Temple T3 | Tier 2 Scholar spec | mythril_full_plate, mystic_ring, crystal_pendant | ✅ Full use |
| **forging_flame** | Forge T3 | Tier 2 Crafter spec | mythril_warblade, mythril_full_plate, crystal_pendant | ✅ Full use |
| **monster_parts** | Hunting T2 | Tier 1 Hunter spec | (advanced crafting?) | ⚠️ Uncertain |
| **scales** | Hunting T2 | Tier 1 Hunter spec | (armor crafting?) | ⚠️ Uncertain |
| **magical_wood** | Forest T3 | Tier 2 Herbalist spec | (future recipes) | ⚠️ No recipes |

**Production Rates** (per hour, base):
- Mine T2: 5-8 mythril_ore/hr
- Forge T2: 2-4 steel_ingots/hr
- Forest T2: 3-6 rare_herbs/hr
- Temple T3: 1-2 magic_crystals/hr
- Forge T3: 0.5-1 forging_flame/hr (bottleneck!)

**Unlock**: Requires Tier 1-2 Specialization + Level 10-20

---

### 💎 Tier 4-5 Materials (3) - Endgame Resources

| Resource | Node Source | Unlock | Recipes | Status |
|----------|------------|--------|---------|--------|
| **adamantite_ore** | Mine T4 | Tier 3 Earth Shaper spec | (legendary equipment) | ⚠️ No recipes |
| **dragon_scales** | Hunting T4 | Tier 2 Monster Hunter spec | (dragon armor) | ⚠️ No recipes |
| **divine_ore** | Special T5 | Tier 3 any spec | (mythic equipment) | ⚠️ No recipes |
| **celestial_essence** | Temple T5 | Tier 3 Divine Oracle spec | (mythic accessories) | ⚠️ No recipes |

**Production Rates** (per hour, base):
- Mine T4: 2-3 adamantite_ore/hr
- Hunting T4: 1-2 dragon_scales/hr
- Special T5: 0.5-1 divine_ore/hr (rarest!)

**Unlock**: Requires Tier 2-3 Specialization + Level 30-40

**Note**: Only 10 MVP recipes exist currently (tier 1-3). Tier 4-5 materials defined but no recipes implemented yet.

---

### ⚡ Enhancement Materials (5)

| Resource | Use | Drop Source | Craft Source | Cost |
|----------|-----|-------------|--------------|------|
| **enhancement_powder_low** | +1 to +5 | Beginner/Intermediate dungeons | Forest T1 | 2-5 per attempt |
| **enhancement_powder_mid** | +6 to +10 | Advanced dungeons | Forest T2 | 3-8 per attempt |
| **enhancement_powder_high** | +11 to +15 | Expert dungeons | Forest T3 | 5-15 per attempt |
| **socket_crystal** | Open socket (max 3) | Mine T2, Equipment dungeons | Gemstone crafting | 1 per socket |
| **blessed_oil** | Prevent destruction on fail | MTX Shop | - | 50 divine_crystals |

**Enhancement Success Rates**:
```
+1 to +5:   100% success
+6 to +9:   80% success
+10:        70% success
+11:        60% success
+12:        50% success
+13:        40% success
+14:        35% success
+15:        30% success (ENDGAME GRIND)
```

**Blessed Oil Mechanic**:
- Prevents equipment destruction on failure
- Level doesn't drop to +0 (stays at current level)
- Costs 50 divine_crystals per use
- Essential for +12→+15 attempts on legendary gear

**Related Files**:
- `scripts/systems/equipment/EquipmentEnhancementManager.gd`

---

### 💎 Gemstones (8) - Socket Stat Bonuses

| Gem | Element | Stat Bonus | Drop Source | Socket Value |
|-----|---------|------------|-------------|--------------|
| **ruby** | Fire | +ATK | Fire Sanctum, Mine T1 | +10-50 ATK (by gem tier) |
| **sapphire** | Water | +HP | Water Sanctum, Mine T1 | +50-250 HP |
| **emerald** | Earth | +DEF | Earth Sanctum, Mine T1 | +8-40 DEF |
| **topaz** | Lightning | +SPD | Lightning Sanctum, Mine T1 | +3-15 SPD |
| **diamond** | Light | +CRIT Rate | Light Sanctum, Mine T1 | +3-12% Crit |
| **onyx** | Dark | +ACC | Dark Sanctum, Mine T1 | +5-20% ACC |
| **pearls** | Water | +HP/DEF | Coast T1 | +25-100 HP/DEF |
| **ancient_gems** | All | +All Stats | Mine T5 (rare) | +5-20 to all stats |

**Gem Tiers**:
- Tier 1 (Flawed): +10 ATK, +50 HP, etc.
- Tier 2 (Normal): +20 ATK, +100 HP, etc.
- Tier 3 (Flawless): +35 ATK, +175 HP, etc.
- Tier 4 (Perfect): +50 ATK, +250 HP, etc.

**Socket Strategy**:
- Weapon: Ruby (+ATK), Diamond (+CRIT)
- Armor: Sapphire (+HP), Emerald (+DEF)
- Boots: Topaz (+SPD)
- Accessories: Diamond (+CRIT), Onyx (+ACC)

**Gemstone Crafting** (from element powders + enhancement powder):
```
3 fire_powder_high + 5 enhancement_powder_high → 1 ruby (tier 3) + 10k mana
(Similar for other gems)
```

---

### 🌟 Awakening Materials (20)

#### Element-Specific Powders (18)

| Element | Low Tier | Mid Tier | High Tier | Source |
|---------|----------|----------|-----------|--------|
| **Fire** | fire_powder_low | fire_powder_mid | fire_powder_high | Fire Sanctum (Mon) |
| **Water** | water_powder_low | water_powder_mid | water_powder_high | Water Sanctum (Tue) |
| **Earth** | earth_powder_low | earth_powder_mid | earth_powder_high | Earth Sanctum (Wed) |
| **Lightning** | lightning_powder_low | lightning_powder_mid | lightning_powder_high | Lightning Sanctum (Thu) |
| **Light** | light_powder_low | light_powder_mid | light_powder_high | Light Sanctum (Fri) |
| **Dark** | dark_powder_low | dark_powder_mid | dark_powder_high | Dark Sanctum (Sat) |

**Drop Rates**:
- Beginner: 80% low, 15% mid, 5% high
- Intermediate: 50% low, 35% mid, 15% high
- Advanced: 20% low, 50% mid, 30% high
- Expert: 5% low, 30% mid, 65% high

#### Universal Powders (2)

| Resource | Source | Use |
|----------|--------|-----|
| **magic_powder_low** | Territory T2+ (passive), Hall of Magic | Awaken any element (low tier gods) |
| **magic_powder_mid** | Territory T3+ (passive), Hall of Magic | Awaken any element (mid tier gods) |
| **magic_powder_high** | Territory T4+ (passive), Hall of Magic | Awaken any element (high tier gods) |

**Awakening Cost Example** (Epic Fire God):
```
Materials:
├─ fire_powder_low: 10
├─ fire_powder_mid: 5
├─ fire_powder_high: 2
├─ magic_powder_high: 1 (alternative to element powders)
├─ awakening_stone: 1
└─ mana: 50,000

Result:
└─ God becomes awakened (new abilities, level cap 40→50)
```

#### Special Awakening Materials

| Resource | Source | Use |
|----------|--------|-----|
| **awakening_stone** | Expert dungeons (30-100% drop), Boss stages | Required 1 per awakening |
| **ascension_crystal** | Raids, Events (future) | Future god ascension feature |

**Related Files**:
- `scripts/systems/progression/AwakeningSystem.gd` (189 lines)
- `data/awakened_gods.json` (awakened form definitions)

---

### 👻 Summoning Materials (10)

#### Rarity-Based Souls (4)

| Soul | God Rarity | Drop Source | Summon Result |
|------|------------|-------------|---------------|
| **common_soul** | Common | Temple T1, Daily rewards | Random common god |
| **rare_soul** | Rare | Temple T2 dungeons | Random rare god |
| **epic_soul** | Epic | Temple T3 dungeons | Random epic god |
| **legendary_soul** | Legendary | Temple T5 raids, Events | Random legendary god |

**Soul Fusion** (value exchange):
```
5 common_soul → 1 rare_soul + 10,000 mana
3 rare_soul → 1 epic_soul + 50,000 mana
2 epic_soul → 1 legendary_soul + 200,000 mana
```

#### Element-Based Souls (6)

| Soul | Element Filter | Drop Source | Summon Result |
|------|----------------|-------------|---------------|
| **fire_soul** | Fire | Fire Sanctum (boss, 10% chance) | Random fire god |
| **water_soul** | Water | Water Sanctum (boss, 10% chance) | Random water god |
| **earth_soul** | Earth | Earth Sanctum (boss, 10% chance) | Random earth god |
| **lightning_soul** | Lightning | Lightning Sanctum (boss, 10% chance) | Random lightning god |
| **light_soul** | Light | Light Sanctum (boss, 10% chance) | Random light god |
| **dark_soul** | Dark | Dark Sanctum (boss, 10% chance) | Random dark god |

**Summoning Costs**:
- Mana summon: 10,000 mana (common rarity mostly)
- Soul summon: 1 soul per god (rarity/element guaranteed)
- Premium summon: 100 divine_crystals (better rarity rates)

**Related Files**:
- `scripts/systems/collection/SummonManager.gd` (267 lines)

---

### 🔮 Special Materials (8)

| Resource | Source | Sink | Status |
|----------|--------|------|--------|
| **research_points** | Library T1 | Spec tree research? | ⚠️ Uncertain |
| **scrolls** | Library T1 | God skill unlocks? | ⚠️ Uncertain |
| **knowledge_crystals** | Library T1 | Training acceleration? | ⚠️ Uncertain |
| **divine_essence** | Temple T1 | Spec research, Awakening | ⚠️ Partial use |
| **mana_crystals** | Temple T1 | Mana boost? | ⚠️ Uncertain |
| **awakening_stone** | Expert dungeons | Awakening (1 per god) | ✅ Full use |
| **ascension_crystal** | Raids/Events (future) | Future ascension | ⚠️ Future feature |
| **celestial_essence** | Temple T5 | Mythic accessories | ⚠️ No recipes |

**Library Resources** (research_points, scrolls, knowledge_crystals):
- Defined in resources.json
- Library nodes produce them
- No clear sink implemented yet
- Likely for future features: skill books, training acceleration, spec research costs

---

## Resource Flow Map

### Gathering → Crafting Flow

```
TIER 1 GATHERING NODES
├─ Mine T1 → iron_ore, copper_ore, stone
├─ Forest T1 → wood, herbs, fiber
├─ Coast T1 → fish, salt, pearls
├─ Hunting T1 → pelts, bones
└─ Forge T1 → iron_ingots
         ↓
    TIER 1 CRAFTING
├─ basic_iron_sword (iron_ore, wood, iron_ingots, mana)
├─ basic_iron_armor (iron_ore, stone, herbs, mana)
└─ copper_amulet (copper_ore, fiber, mana)
         ↓
    TIER 2 GATHERING NODES
├─ Mine T2 → mythril_ore
├─ Forge T2 → steel_ingots
└─ Forest T2 → rare_herbs
         ↓
    TIER 2-3 CRAFTING
├─ steel_greatsword (steel_ingots, wood, rare_herbs, mana)
├─ mythril_warblade (mythril_ore, forging_flame, magic_crystals, mana)
└─ crystal_pendant (magic_crystals, rare_herbs, diamond, sapphire, mana)
```

### Dungeon → Enhancement Flow

```
DUNGEON RUNS (Energy Cost: 6-15)
├─ Elemental Sanctum → element_powders, awakening_stone
├─ Equipment Dungeon → enhancement_powders, socket_crystals
└─ Pantheon Trial → awakening_stone, legendary_soul
         ↓
    EQUIPMENT ENHANCEMENT
├─ +0 to +5 (enhancement_powder_low × 2-5, gold: 1k-5k)
├─ +6 to +10 (enhancement_powder_mid × 3-8, gold: 10k-25k)
└─ +11 to +15 (enhancement_powder_high × 5-15, gold: 50k-100k)
         ↓
    SOCKET INSERTION
└─ Insert gems (ruby, sapphire, emerald, etc.) for stat bonuses
```

### Territory → Awakening Flow

```
TERRITORY PRODUCTION (Passive AFK)
├─ Temple T2+ → magic_powder_low (universal awakening material)
├─ Temple T3+ → magic_powder_mid
└─ Temple T4+ → magic_powder_high
         ↓
    DUNGEON FARMING (Active)
├─ Elemental Sanctum (Mon-Sat) → element_powders (fire, water, earth, etc.)
└─ Expert difficulty → awakening_stone (30-100% drop)
         ↓
    GOD AWAKENING (Level 40 → Level 50)
├─ Consume: element_powders (10 low, 5 mid, 2 high) OR magic_powders
├─ Consume: awakening_stone (1)
└─ Consume: mana (50,000)
         ↓
    RESULT: Awakened god (new abilities, level cap increased to 50)
```

---

## Resource Bottlenecks

### Early Game (Level 1-20)
**Bottleneck**: Mana for crafting and summoning
- **Solution**: Territory production (mana generation), dungeon farming, sacrifice duplicate gods

### Mid Game (Level 20-30)
**Bottleneck**: Tier 2 specialization unlock (limits node access)
- **Solution**: Choose specialization path strategically (Miner for ores, Crafter for forging, etc.)

**Bottleneck**: Forging_flame (only from Forge T3, requires Tier 2 Crafter spec)
- **Solution**: Focus on unlocking Forge T3 nodes early, assign specialized crafter gods

### Late Game (Level 30-40)
**Bottleneck**: Awakening_stone (30-100% drop from Expert dungeons only)
- **Solution**: Farm Expert difficulty daily, stockpile stones before mass awakening

**Bottleneck**: Enhancement_powder_high for +11→+15 upgrades
- **Solution**: Expert dungeon farming, Forest T3 node production

### Endgame (Level 40-50)
**Bottleneck**: Tier 4-5 materials (no recipes exist yet)
- **Solution**: Future content update

**Bottleneck**: Divine crystals for blessed oil (+15 enhancement protection)
- **Solution**: MTX, territory passive generation (1-3/hr), dungeon first-clear rewards

---

## Resource Efficiency Guide

### Best Nodes by Resource Category

**For Ores (iron, mythril, adamantite)**:
- Node: Mine T1-T4
- Best role: Gatherer
- Best spec: Miner path (Tier 1 → Tier 2 → Tier 3)
- Efficiency bonus: +25% (role) + +50-200% (spec) = up to +225% total

**For Enhancement Powders**:
- Node: Forest T1-T3
- Best role: Gatherer
- Best spec: Herbalist path
- Alternative: Farm dungeons (faster but requires energy)

**For Awakening Materials**:
- Primary: Dungeon farming (elemental sanctums)
- Passive: Territory production (magic_powders from Temple T2+)
- Efficiency: Expert difficulty is 3.2x more efficient than Beginner

**For Gemstones**:
- Node: Coast T1 (pearls), Mine T1 (basic gems)
- Dungeons: Elemental sanctums (boss stages, 10% element_soul drop)
- Crafting: Convert element_powders + enhancement_powder → gems

### Production Multipliers

**Base Production Formula**:
```gdscript
base_production = node_base_rate * (1 + role_bonus + spec_bonus + connected_bonus)
```

**Example** (Mine T2 with Tier 2 Miner):
```
Base: 5 mythril_ore/hr
Role (Gatherer): +25% → 6.25/hr
Spec (Tier 2 Miner): +100% → 12.5/hr
Connected (3+ nodes): +20% → 15/hr
Element match (Earth god): +50% → 22.5/hr

Final: 22.5 mythril_ore/hr (4.5x base!)
```

**God Assignment Multipliers**:
- Matching role: +25%
- Tier 1 spec: +50%
- Tier 2 spec: +100%
- Tier 3 spec: +200%
- Awakened god: +30%
- Legendary tier god: +80%
- Element match: +50%
- Connected nodes (2+): +10%, (3+): +20%, (4+): +30%

---

## Crafting Recipe Requirements

### Tier 1 Recipes (Common Equipment)

**basic_iron_sword** (Common Weapon):
```
Materials:
├─ iron_ore: 10
├─ wood: 5
├─ iron_ingots: 2
└─ mana: 500

Territory: None required
Specialization: None required
```

**basic_iron_armor** (Common Armor):
```
Materials:
├─ iron_ore: 15
├─ stone: 8
├─ herbs: 5
└─ mana: 800

Territory: None required
Specialization: None required
```

**copper_amulet** (Common Accessory):
```
Materials:
├─ copper_ore: 8
├─ fiber: 10
└─ mana: 600

Territory: None required
Specialization: None required
```

### Tier 2 Recipes (Rare Equipment)

**steel_greatsword** (Rare Weapon):
```
Materials:
├─ steel_ingots: 12
├─ wood: 8
├─ rare_herbs: 5
└─ mana: 5,000

Territory: Tier 2 Forge required
Specialization: crafter_tier1 required
God Level: 20+
```

**mystic_ring** (Rare Accessory):
```
Materials:
├─ fiber: 15
├─ rare_herbs: 10
├─ magic_crystals: 5
└─ mana: 6,000

Territory: None required
Specialization: scholar_tier2 required
God Level: 30+
```

### Tier 3 Recipes (Epic Equipment)

**mythril_warblade** (Epic Weapon):
```
Materials:
├─ mythril_ore: 30
├─ forging_flame: 3
├─ magic_crystals: 10
└─ mana: 25,000

Territory: Tier 3 Forge required
Specialization: crafter_blacksmith_tier2 required
God Level: 30+
Guaranteed Substats: 2-3
Guaranteed Sockets: 1
```

**crystal_pendant** (Epic Accessory):
```
Materials:
├─ magic_crystals: 25
├─ rare_herbs: 15
├─ diamond: 3
├─ sapphire: 3
└─ mana: 22,000

Territory: Tier 3 Temple required
Specialization: scholar_tier2 required
God Level: 30+
Guaranteed Substats: 2-3
Guaranteed Sockets: 1
```

**Total Recipes**: 10 MVP recipes (3 common, 4 rare, 3 epic)

**Related Files**:
- `data/crafting_recipes.json` (10 recipes)
- `scripts/systems/equipment/EquipmentCraftingManager.gd` (189 lines)

---

## Resource Conversion Chains

### Ore Refinement
```
10 iron_ore → 1 mythril_ore + 5,000 gold
5 mythril_ore → 1 adamantite_ore + 25,000 gold
```

### Soul Fusion
```
5 common_soul → 1 rare_soul + 10,000 mana
3 rare_soul → 1 epic_soul + 50,000 mana
2 epic_soul → 1 legendary_soul + 200,000 mana
```

### Gemstone Creation
```
3 fire_powder_high + 5 enhancement_powder_high → 1 ruby (tier 3) + 10,000 mana
(Similar for sapphire, emerald, topaz, diamond, onyx)
```

---

## Playstyle Resource Priorities

### 🎣 Fisher King (Pure Gathering)
**Focus**: Passive income, resource trading
**Priority Resources**:
- Fish, pearls, salt (Coast T1 nodes × 3-4)
- Wood, herbs (Forest T1 nodes × 2-3)
- Divine crystals (passive territory generation)

**Strategy**: Max connected bonuses (+30%), assign specialized gatherer gods

### ⚔️ Arena Gladiator (Pure PvP)
**Focus**: Steal resources from raids, skip territory
**Priority Resources**:
- Enhancement_powder_high (for +15 equipment)
- Gemstones (for socket bonuses)
- Awakening materials (from dungeon farming)

**Strategy**: Raid territory for resources, farm dungeons aggressively

### 🔨 Master Crafter (Production Monopoly)
**Focus**: Craft and sell premium equipment
**Priority Resources**:
- Forging_flame (Forge T3, bottleneck resource!)
- Mythril_ore, steel_ingots (crafting materials)
- Enhancement powders (for crafted gear upgrades)

**Strategy**: Unlock Forge T3 early, specialize crafter gods, control forging_flame market

### 📚 Scholar (Research & Training)
**Focus**: Unlock recipes early, train gods faster
**Priority Resources**:
- Research_points (Library T1-T3)
- Knowledge_crystals (god training acceleration)
- Scrolls (skill unlocks)

**Strategy**: Control Library nodes, maximize spec research speed

### 💤 AFK Emperor (Strategic Placement)
**Focus**: 24/7 passive production
**Priority Resources**:
- Mana, divine_crystals (passive currency generation)
- Magic_powders (passive awakening materials)
- Enhancement powders (from Forest nodes)

**Strategy**: Build 4+ connected nodes (+30%), assign matching spec workers, maximize offline cap (12hr)

### 🏴‍☠️ Territory Raider (Control Endgame)
**Focus**: Control tier 5 nodes, gate endgame materials
**Priority Resources**:
- Divine_ore, celestial_essence (tier 5 exclusives)
- Adamantite_ore, dragon_scales (tier 4 rares)
- Ancient_gems (tier 5 mines, rare)

**Strategy**: Rush to level 40, unlock tier 5 nodes, defend strategically

**Related Docs**:
- [[RESOURCE_PHILOSOPHY]] - Complete playstyle analysis

---

## Resource Balance Status

### ✅ Well-Balanced Resources (40/49)

Resources with clear sources AND sinks:
- All currencies (mana, gold, divine_crystals, energy)
- Tier 1-3 crafting materials used in recipes
- Enhancement materials (all 5)
- Gemstones (all 8)
- Awakening materials (all 20)
- Summoning souls (all 10)
- Awakening_stone (special material)

### ⚠️ Uncertain Resources (7/49)

Resources with unclear or minimal use:
- **fish**: Coast T1 production, no primary sink (trade/food system?)
- **salt**: Coast T1 production, no sink (preservation mechanic?)
- **bones**: Hunting T1 production, minimal use (bone armor future?)
- **monster_parts**: Hunting T2 production, unclear sink
- **scales**: Hunting T2 production, unclear sink (armor crafting?)
- **research_points**: Library T1 production, undefined mechanics
- **scrolls**: Library T1 production, no skill unlock system implemented
- **knowledge_crystals**: Library T1 production, no training acceleration

### ⚠️ Defined But No Recipes (6/49)

Resources exist in data but no crafting recipes reference them:
- **divine_ore** (tier 5): Defined, no mythic equipment recipes
- **celestial_essence** (tier 5): Defined, no mythic accessories
- **ancient_gems** (tier 5): Defined, no special socket recipes
- **magical_wood** (tier 3): Defined, no recipes
- **ascension_crystal**: Defined for future god ascension feature
- **divine_essence**, **mana_crystals**: Partial use (spec research?)

### 💡 Recommendations

1. **Add Tier 4-5 Recipes**: Create 5+ legendary/mythic recipes using divine_ore, celestial_essence, ancient_gems
2. **Implement Library Mechanics**: Define research_points, scrolls, knowledge_crystals sinks (spec research, skill unlocks, training boost)
3. **Add Food/Trade System**: Give fish, salt, bones primary purpose
4. **Advanced Crafting**: Use monster_parts, scales, magical_wood in advanced armor/weapon recipes
5. **Future Features**: Ascension system using ascension_crystal

---

## Navigation

**Main Documents**:
- [[GAME_DESIGN_DOCUMENT]] - Section 3: Resource Economy (49 Resources)
- [[RESOURCE_PHILOSOPHY]] - Economy philosophy, player archetypes, AFK strategies
- [[RESOURCE_ALIGNMENT]] - Resource classification system
- [[HEX_RESOURCE_ALIGNMENT_COMPLETE]] - Hex node resource mapping

**Related MOCs**:
- [[GameSystems]] - All game systems overview
- [[TerritoryManagement]] - Hex grid and production
- [[EquipmentCrafting]] - Crafting recipes and enhancement
- [[GodProgression]] - Awakening materials and progression

**Related Files**:
- `data/resources.json` (v2.2.0, 105+ resources)
- `data/crafting_recipes.json` (10 MVP recipes)
- `scripts/systems/resources/ResourceManager.gd` (211 lines)
- `scripts/systems/equipment/EquipmentCraftingManager.gd` (189 lines)

---

*This Map of Content was created 2026-01-18 to provide complete reference for the 49-resource economy system.*

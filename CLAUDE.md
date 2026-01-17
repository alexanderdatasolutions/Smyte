# Smyte - Master Project Document

## Vision Statement
Smyte is a **god collector RPG** combining the best elements of:
- **Summoners War**: Gacha summoning, rune/equipment system, turn-based combat
- **Palworld**: Assign creatures to tasks, base building, resource generation
- **RuneScape**: Deep skill trees, specializations, long-term progression loops
- **Civilization**: Hex-based territory map with strategic node capture
- **Clash of Clans**: Async PvP raids on territories, defend your nodes
- **IdleOn**: Big RPG side scroller with tons of afk gains.

The core fantasy: **Collect gods from various pantheons, conquer a hex-based world map, assign gods to territories based on their traits and specializations, and build a divine empire.**

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

## Hex Territory System (CORE FEATURE)

### World Map Overview
The world is a hex grid with your **Divine Sanctum** (base) at center. Nodes spread outward in rings.

```
Ring 0: Base (Divine Sanctum) - Always controlled
Ring 1: 6 adjacent nodes - Tier 1, easy capture
Ring 2: 12 nodes - Tier 1-2
Ring 3: 18 nodes - Tier 2-3
Ring 4: 24 nodes - Tier 3-4
Ring 5+: Outer rings - Tier 4-5, legendary resources
```

### Node Tiers & Requirements

| Tier | Level Req | Specialization Req | Resources | Example Nodes |
|------|-----------|-------------------|-----------|---------------|
| 1 | 1 | None | Basic (Iron, Wood, Herbs) | Forest Grove, Stone Quarry |
| 2 | 10 | Tier 1 Spec | Uncommon (Steel, Rare Herbs) | Deep Mine, Ancient Forest |
| 3 | 20 | Tier 2 Spec | Rare (Mithril, Magic Crystals) | Crystal Caverns, Dragon's Lair |
| 4 | 30 | Tier 2 Spec + Role Match | Epic (Adamantine, Divine Essence) | Volcanic Forge, Sky Temple |
| 5 | 40 | Tier 3 Spec | Legendary (Celestial Ore, God Tears) | Olympus Outpost, Realm Gate |

### Distance Penalty
Holding nodes far from your base is harder:
```
defense_rating = base_defense * (1 - distance_penalty)
distance_penalty = 0.05 * hex_distance_from_base  # 5% per hex
```
- Node 1 hex away: 95% defense
- Node 5 hexes away: 75% defense
- Node 10 hexes away: 50% defense

This creates strategic choices:
- Expand slowly and hold firmly?
- Rush to valuable far nodes but risk losing them?
- Build a "supply chain" of connected nodes for bonuses?

### Node Types

| Type | Icon | Primary Output | Special Tasks | Best Roles |
|------|------|---------------|---------------|------------|
| **Mine** | ⛏️ | Ore, Gems | Deep Mining, Gem Cutting | Gatherer (Miner spec) |
| **Forest** | 🌲 | Wood, Herbs, Fiber | Logging, Herbalism | Gatherer (Herbalist spec) |
| **Coast** | 🌊 | Fish, Pearls, Salt | Fishing, Pearl Diving | Gatherer (Fisher spec) |
| **Hunting Ground** | 🦌 | Pelts, Bones, Monster Parts | Hunting, Tracking | Gatherer (Hunter spec) |
| **Forge** | 🔨 | Equipment, Repairs | Smithing, Enchanting | Crafter |
| **Library** | 📚 | Research Points, Scrolls | Research, Training | Scholar |
| **Temple** | 🏛️ | Divine Essence, Blessings | Meditation, Awakening | Support |
| **Fortress** | 🏰 | Defense Bonus, Training | Garrison, War Planning | Fighter |

### Node Capture Flow

1. **Scout** - Send Explorer god to reveal node details (tier, type, defenders)
2. **Challenge** - Battle the node's defenders (PvE or enemy player's garrison)
3. **Capture** - Win battle, node becomes "contested" for 1 hour
4. **Claim** - If unchallenged, node is yours
5. **Garrison** - Assign defender gods to protect from raids

### Specialization → Node Access

**This is the key progression loop:**

```
New Player:
  → Can only capture Tier 1 nodes
  → Limited resource variety

Level 20 + Tier 1 Spec:
  → Unlocks Tier 2 nodes
  → Better resources, new crafting recipes

Level 30 + Tier 2 Spec:
  → Unlocks Tier 3 nodes
  → Rare materials, powerful equipment crafting

Level 40 + Tier 3 Spec:
  → Unlocks Tier 4-5 nodes
  → Legendary resources, endgame content
```

### Connected Node Bonuses
Adjacent controlled nodes provide bonuses:
- **2 connected**: +10% production
- **3 connected**: +20% production, -5% task time
- **4+ connected**: +30% production, -10% task time, bonus defense

This encourages building "regions" rather than scattered nodes.

---

## Core Systems Architecture

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
│   ├── HexGridManager (NEW)        # Core hex grid logic
│   ├── TerritoryManager            # Node ownership/state
│   ├── TerritoryProductionManager  # Resource generation
│   ├── TaskAssignmentManager       # God work assignments
│   ├── NodeRequirementChecker (NEW) # Tier/spec gates
│   └── TerritoryRaidManager (NEW)  # Async PvP raids
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

## Hex Grid Technical Design

### Coordinate System
Use **axial coordinates** (q, r) for hex positions:
```gdscript
class HexCoord:
    var q: int  # Column
    var r: int  # Row

    func distance_to(other: HexCoord) -> int:
        return (abs(q - other.q) + abs(q + r - other.q - other.r) + abs(r - other.r)) / 2

    func get_neighbors() -> Array[HexCoord]:
        return [
            HexCoord.new(q+1, r), HexCoord.new(q-1, r),
            HexCoord.new(q, r+1), HexCoord.new(q, r-1),
            HexCoord.new(q+1, r-1), HexCoord.new(q-1, r+1)
        ]
```

### HexNode Data Structure
```gdscript
class HexNode:
    var coord: HexCoord
    var node_id: String
    var node_type: String  # "mine", "forest", "forge", etc.
    var tier: int  # 1-5
    var controller: String  # "player", "neutral", "enemy_player_id"
    var garrison: Array[String]  # God IDs defending
    var assigned_workers: Array[String]  # God IDs working tasks
    var active_tasks: Array[String]  # Task IDs in progress
    var production_level: int  # Upgrade level
    var defense_level: int
    var is_revealed: bool
    var last_raid_time: int  # Unix timestamp
```

### Node JSON Schema
```json
{
  "nodes": {
    "forest_grove_1": {
      "id": "forest_grove_1",
      "name": "Verdant Grove",
      "type": "forest",
      "tier": 1,
      "coord": {"q": 1, "r": 0},
      "base_defenders": ["forest_spirit", "nature_elemental"],
      "production": {
        "wood": {"base": 100, "per_hour": true},
        "herbs": {"base": 30, "per_hour": true}
      },
      "available_tasks": ["logging", "herbalism", "foraging"],
      "max_garrison": 2,
      "max_workers": 3,
      "capture_power_required": 5000
    }
  }
}
```

---

## God Role & Specialization System

### Why Specialize?
1. **Unlock higher tier nodes** - Tier 3+ nodes require matching specialization
2. **Massive efficiency bonuses** - +50% to +200% task efficiency
3. **Unique abilities** - Tier 3 specs grant powerful passive abilities
4. **Node-specific bonuses** - Crafter specs get bonuses at Forge nodes

### Roles (Broad Categories)
| Role | Best For | Node Affinity |
|------|----------|---------------|
| Fighter | Combat, Defense | Fortress, Hunting Ground |
| Gatherer | Resource extraction | Mine, Forest, Coast |
| Crafter | Equipment creation | Forge |
| Scholar | Research, Training | Library |
| Support | Buffs, Healing, Leadership | Temple |

### Specialization Trees (84 total specs implemented)
Each role has 4 paths with 4 nodes each (Tier 1 → 2 → 2 → 3):

**Fighter Example:**
```
Berserker (T1) → Raging Warrior (T2) OR Blood Dancer (T2) → Avatar of Fury (T3)
Guardian (T1) → Shield Master (T2) OR Warden (T2) → Immortal Bulwark (T3)
```

**Gatherer Example:**
```
Miner (T1) → Gem Cutter (T2) OR Deep Miner (T2) → Master Jeweler/Earth Shaper (T3)
Fisher (T1) → Pearl Diver (T2) OR Whale Hunter (T2) → Ocean Master/Sea Sovereign (T3)
```

### Specialization → Node Gating
```gdscript
func can_capture_node(player, node) -> bool:
    # Check player level
    if player.level < node.tier * 10:
        return false

    # Check specialization requirements
    if node.tier >= 2:
        if not player.has_any_tier1_spec():
            return false
    if node.tier >= 3:
        if not player.has_any_tier2_spec():
            return false
    if node.tier >= 4:
        # Requires tier 2 spec that matches node type
        if not player.has_matching_spec(node.type, 2):
            return false
    if node.tier == 5:
        if not player.has_any_tier3_spec():
            return false

    return true
```

---

## Task System Integration

### Task → Node Type Matching
Tasks are available based on node type:

| Node Type | Available Tasks |
|-----------|----------------|
| Mine | mine_ore, mine_gems, deep_mining, gem_cutting |
| Forest | logging, herbalism, foraging, plant_cultivation |
| Coast | fishing, pearl_diving, salt_harvesting |
| Hunting Ground | hunting, tracking, monster_hunting, taming |
| Forge | smithing, armor_crafting, weapon_crafting, enchanting |
| Library | research, scroll_crafting, training, skill_learning |
| Temple | meditation, blessing, awakening_ritual, divine_communion |
| Fortress | garrison_duty, war_planning, combat_training, defense_building |

### Task Efficiency Formula
```
efficiency = base_rate
           * (1 + trait_bonus)           # +50% if matching trait
           * (1 + spec_bonus)            # +25-100% from specialization
           * (1 + level_bonus)           # +1% per god level
           * (1 + node_upgrade_bonus)    # +10% per upgrade level
           * (1 + connected_node_bonus)  # +10-30% for connected territories
           * (1 + leadership_bonus)      # Commander/Overseer auras
```

### Specialization Task Bonuses
Example from specializations.json:
```json
"gatherer_miner": {
    "task_bonuses": {
        "mining": 0.50
    },
    "resource_bonuses": {
        "ore_yield_percent": 0.30,
        "gem_chance_percent": 0.15
    }
}
```

---

## Territory Raids (Async PvP)

### Raid Flow
1. **Scout Enemy** - Pay gold to reveal enemy node garrison
2. **Assemble Raid Party** - Select 4 gods for attack
3. **Launch Raid** - Battle plays out (can watch replay)
4. **Outcome**:
   - Win: Node becomes contested, enemy has 4 hours to defend
   - Lose: 8-hour cooldown before you can raid that node again

### Defense Rating
```
defense_rating = sum(garrison_god_power)
               * (1 + defense_upgrade_bonus)
               * (1 - distance_penalty)
               * (1 + connected_bonus)
```

### Raid Rewards
- Win: Steal 10% of node's pending resources
- Win + Capture: Gain full node control
- Lose: Lose some god energy (can't use in raids for 4 hours)

---

## Progression Loop Summary

### Early Game (Level 1-19)
- Capture Tier 1 nodes around your base
- Basic resource gathering
- Level up gods, get first equipment sets

### Mid Game (Level 20-39)
- Choose first specialization at level 20
- Unlock Tier 2-3 nodes
- Build connected territories
- Start crafting good equipment

### Late Game (Level 40+)
- Tier 3 specializations unlock Tier 4-5 nodes
- Legendary resources for endgame equipment
- PvP territory wars for rare nodes
- Guild territory conquest

---

## Code Standards

### File Organization
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
│   ├── hex_nodes.json  # World map node definitions
│   └── recipes.json
└── scenes/             # Godot scenes
```

### Code Rules
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

---

## Data Schemas

### HexNode (NEW)
```json
{
  "hex_nodes": {
    "mine_copper_1": {
      "id": "mine_copper_1",
      "name": "Copper Vein",
      "type": "mine",
      "tier": 1,
      "coord": {"q": 2, "r": -1},
      "base_production": {"copper_ore": 50, "stone": 30},
      "available_tasks": ["mine_ore"],
      "max_workers": 2,
      "max_garrison": 1,
      "pve_defenders": ["rock_golem"],
      "unlock_requirements": {
        "player_level": 1,
        "specialization_tier": 0,
        "specialization_role": null
      }
    }
  }
}
```

### God Definition (with roles/specs)
```json
{
  "gods": {
    "hephaestus": {
      "id": "hephaestus",
      "name": "Hephaestus",
      "pantheon": "greek",
      "tier": 4,
      "element": "fire",
      "primary_role": "crafter",
      "innate_traits": ["forgemaster", "miner"],
      "base_stats": { "hp": 5000, "attack": 250, "defense": 300, "speed": 80 }
    }
  }
}
```

---

## Feature Roadmap

### Implemented ✅
- [x] God collection and summoning with pity
- [x] Equipment system (6 slots, enhancement, sockets)
- [x] Turn-based combat with status effects
- [x] Basic territory capture/control
- [x] Player and god progression
- [x] Shop with skins (cosmetic MTX)
- [x] Trait system (24 traits, 35 god mappings)
- [x] Role system (5 roles)
- [x] Specialization system (84 specializations)
- [x] Task system (24 tasks, 5 categories)

### In Progress 🔄
- [ ] **Hex map system** - Core feature
- [ ] **Node tier gating** - Spec requirements
- [ ] **Territory screen overhaul** - Hex map view
- [ ] **Task assignment UI** - Assign gods to nodes

### Planned 📋
- [ ] Async PvP raids
- [ ] Connected node bonuses
- [ ] Guild territories
- [ ] World boss nodes
- [ ] Seasonal map events

---

## Resource & Crafting Economy

### Complete Resource Flow Loop

```
TERRITORY NODES → RESOURCES → CRAFTING → EQUIPMENT → COMBAT → LOOT → PROGRESSION
       ↑                                                                    ↓
       ←←←←←← SPECIALIZATIONS UNLOCK BETTER NODES & RECIPES ←←←←←←←←←←←←←←←
```

### Resource Categories & Uses

#### 1. Currencies (Always Needed)
| Resource | Primary Source | Primary Uses |
|----------|---------------|--------------|
| **Mana** | Territory production, dungeon clears | God leveling, equipment enhancement, summoning |
| **Gold** | Territory production, selling equipment | Equipment crafting, shop purchases, node upgrades |
| **Divine Crystals** | Shop (MTX), events | Premium summons, energy refresh, blessed oil |
| **Energy** | Time regeneration, crystal refresh | Enter dungeons and battles |

#### 2. Crafting Materials (Equipment Creation)

**Tier 1-2: Basic Equipment (Levels 1-30)**
| Material | Node Source | Crafted Into | Required Spec |
|----------|------------|--------------|---------------|
| Iron Ore | Tier 1 Mine nodes | Common/Rare weapons, armor | None |
| Wood | Tier 1 Forest nodes | Common/Rare armor, accessories | None |
| Copper Ore | Tier 1 Mine nodes | Common accessories | None |
| Herbs | Tier 1 Forest nodes | Enhancement powder (low) | None |
| Stone | Tier 1 Mine nodes | Common armor | None |

**Tier 3-4: Advanced Equipment (Levels 30-50)**
| Material | Node Source | Crafted Into | Required Spec |
|----------|------------|--------------|---------------|
| Mythril Ore | Tier 2-3 Mine nodes | Epic weapons, armor | Tier 1 Miner |
| Steel Ingots | Tier 2 Forge nodes | Epic weapons | Tier 1 Crafter |
| Rare Herbs | Tier 2 Forest nodes | Enhancement powder (mid) | Tier 1 Herbalist |
| Magic Crystals | Tier 3 Temple nodes | Epic accessories | Tier 2 Scholar |
| Forging Flame | Tier 3 Forge nodes | All epic+ equipment | Tier 2 Crafter |

**Tier 5: Endgame Equipment (Level 50+)**
| Material | Node Source | Crafted Into | Required Spec |
|----------|------------|--------------|---------------|
| Adamantite Ore | Tier 4-5 Mine nodes | Legendary/Mythic weapons | Tier 3 Earth Shaper |
| Celestial Essence | Tier 5 Temple nodes | Mythic accessories | Tier 3 Divine Oracle |
| Dragon Scales | Tier 4 Hunting nodes | Legendary armor | Tier 2 Monster Hunter |
| Ancient Gems | Tier 5 Mine nodes | Legendary accessories | Tier 3 Master Jeweler |
| Divine Ore | Tier 5 special nodes | Mythic equipment | Tier 3 any spec |

#### 3. Enhancement Materials (Equipment Upgrading)

| Material | Source | Use | Enhancement Tier |
|----------|--------|-----|------------------|
| Enhancement Powder (Low) | Tier 1 Forest/Temple | Enhance +1 to +5 | Common/Rare |
| Enhancement Powder (Mid) | Tier 2 Forest/Temple | Enhance +6 to +10 | Rare/Epic |
| Enhancement Powder (High) | Tier 3 Forest/Temple | Enhance +11 to +15 | Epic/Legendary |
| Blessed Oil | Tier 3 Temple, dungeons | Prevent equipment destruction on fail | All tiers |
| Socket Crystals | Tier 2-3 Mine nodes | Add sockets to equipment | All tiers |

#### 4. Gemstones (Socket Fillers)

**Basic Gems (Tier 1-2 Nodes)**
- Ruby (Fire) → +ATK
- Sapphire (Water) → +HP
- Emerald (Earth) → +DEF
- Topaz (Lightning) → +SPD
- Diamond (Light) → +CRIT
- Onyx (Dark) → +ACC

**Refined Gems (Crafted at Tier 3 Forge)**
- Requires 3x basic gems + forging flame + Tier 2 Crafter spec
- 2x stat bonus of basic gems

**Perfect Gems (Crafted at Tier 5 Forge)**
- Requires 3x refined gems + divine ore + Tier 3 Legendary Smith spec
- 3x stat bonus of basic gems

#### 5. Awakening Materials (God Power-Ups)

**Element-Specific Powders**
| Material | Source | Used For |
|----------|--------|----------|
| Fire/Water/Earth/etc Powder (Low) | Elemental Sanctum dungeons (beginner) | Awaken tier 1-2 gods |
| Fire/Water/Earth/etc Powder (Mid) | Elemental Sanctum dungeons (intermediate) | Awaken tier 3 gods |
| Fire/Water/Earth/etc Powder (High) | Elemental Sanctum dungeons (expert) | Awaken tier 4-5 gods |
| Magic Powder (Universal) | Weekly events, shop | Awaken any god |

**Special Awakening Materials**
- Awakening Stone: Legendary god awakening (drop from tier 5 nodes or boss dungeons)
- Ascension Crystal: God ascension to higher star rank (raid rewards, events)

#### 6. Summoning Materials (Getting New Gods)

| Material | Source | Summon Result |
|----------|--------|---------------|
| Common Soul | Tier 1 Temple tasks | Random common god |
| Rare Soul | Tier 2 Temple tasks, dungeon loot | Random rare god |
| Epic Soul | Tier 3 Temple tasks, dungeon loot | Random epic god |
| Legendary Soul | Tier 5 Temple tasks, raid rewards | Random legendary god |
| Element-Specific Souls | Elemental Sanctum boss drops | Random god of that element |

### Crafting Recipes System

#### Recipe Unlock Progression

**Tier 1 Recipes (Available from start)**
```json
"basic_iron_sword": {
  "equipment_type": "weapon",
  "rarity": "common",
  "level": 1,
  "materials": {
    "iron_ore": 20,
    "wood": 10,
    "mana": 500
  },
  "territory_required": false,
  "god_level_requirement": 0
}
```

**Tier 2 Recipes (Requires Tier 1 Specialization)**
```json
"steel_greatsword": {
  "equipment_type": "weapon",
  "rarity": "rare",
  "level": 20,
  "materials": {
    "steel_ingots": 15,
    "rare_herbs": 5,
    "forging_flame": 1,
    "mana": 5000
  },
  "territory_required": true,
  "territory_tier_requirement": 2,
  "specialization_requirement": "crafter_tier1"
}
```

**Tier 3 Recipes (Requires Tier 2+ Specialization + Forge Node)**
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
  "territory_type_requirement": "forge",
  "specialization_requirement": "crafter_blacksmith_tier2",
  "god_level_requirement": 30,
  "guaranteed_substats": [
    {"stat": "attack", "value": 150},
    {"stat": "crit_rate", "value": 15}
  ]
}
```

**Tier 4-5 Recipes (Requires Tier 3 Specialization + Special Nodes)**
```json
"divine_dragonblade": {
  "equipment_type": "weapon",
  "rarity": "legendary",
  "level": 50,
  "materials": {
    "adamantite_ore": 50,
    "dragon_scales": 20,
    "divine_ore": 10,
    "ancient_gems": 5,
    "mana": 100000
  },
  "territory_required": true,
  "territory_tier_requirement": 5,
  "territory_type_requirement": "forge",
  "specialization_requirement": "crafter_legendary_smith_tier3",
  "awakened_god_required": true,
  "guaranteed_substats": [
    {"stat": "attack", "value": 300},
    {"stat": "crit_rate", "value": 25},
    {"stat": "crit_damage", "value": 50}
  ],
  "guaranteed_sockets": 2,
  "set_type": "berserker"
}
```

### Dungeon Loot Tables

**Elemental Sanctums (Daily Dungeons)**
- Purpose: Farm awakening materials
- Loot: Element-specific powders, universal powders, souls
- Difficulty scales with player level
- 3 runs per day per element

**Equipment Dungeons (Random drops)**
- Purpose: Get equipment directly without crafting
- Loot: Random equipment (common to epic), enhancement materials
- Higher difficulty = better rarity chances
- Unlimited runs (costs energy)

**Boss Dungeons (Weekly)**
- Purpose: Legendary equipment and rare materials
- Loot: Legendary equipment pieces, awakening stones, ascension crystals
- 1 run per week per boss
- Requires tier 2+ specialization to enter

**Raid Dungeons (Multiplayer)**
- Purpose: Mythic equipment and divine materials
- Loot: Mythic equipment, divine ore, celestial essence
- Requires 4 players, tier 3 specialization
- Weekly reset, unlimited attempts

### Equipment Enhancement System

**Enhancement Levels & Costs**
```
+1 to +5:   Enhancement Powder (Low) x2,  Mana x1000,  Success: 100%
+6 to +9:   Enhancement Powder (Mid) x3,  Mana x5000,  Success: 75%
+10 to +12: Enhancement Powder (High) x5, Mana x15000, Success: 50%
+13 to +15: Enhancement Powder (High) x10, Mana x50000, Success: 25%
```

**Failure Results:**
- Common/Rare: Drop 1 enhancement level
- Epic: Drop 2 levels or destroy (10% chance)
- Legendary/Mythic: Drop 3 levels or destroy (25% chance)

**Blessed Oil:**
- Prevents destruction on failure
- Doesn't prevent level loss
- Source: Tier 3 Temple nodes, shop (crystals)
- Cost: 50 divine crystals per use

**Socket System:**
```
Base Sockets:
- Common/Rare: 0 (can add up to 2)
- Epic: 1 (can add 1 more)
- Legendary: 2 (can add 1 more)
- Mythic: 3 (max)

Adding Sockets:
- Socket Crystal x1 + Mana x10000 = 100% success for first socket
- Socket Crystal x3 + Mana x50000 = 50% success for second socket
- Socket Crystal x10 + Mana x200000 = 10% success for third socket (only on legendary/mythic)
```

### Specialization Impact on Resources

**Gatherer Specializations:**
```
Tier 1 Miner:
  - +50% ore gathering speed
  - +30% ore yield from tasks
  - +15% gem drop chance
  - Unlocks: Tier 2 mine nodes

Tier 2 Deep Miner:
  - +100% ore gathering speed
  - +60% ore yield from tasks
  - +30% gem drop chance
  - Unlocks: Deep mining task (mythril, adamantite)
  - Unlocks: Tier 3 mine nodes

Tier 3 Earth Shaper:
  - +200% ore gathering speed
  - +100% ore yield from tasks
  - +50% gem drop chance
  - Can mine divine ore
  - Unlocks: Tier 5 mine nodes
  - Passive: All nodes connected to mines get +20% production
```

**Crafter Specializations:**
```
Tier 1 Blacksmith:
  - +25% crafting speed at forge nodes
  - -10% material cost for weapon/armor recipes
  - Unlocks: Tier 2 weapon/armor recipes

Tier 2 Master Artisan:
  - +50% crafting speed at forge nodes
  - -20% material cost for weapon/armor recipes
  - +1 guaranteed substat on crafted items
  - Unlocks: Tier 3 weapon/armor recipes
  - Unlocks: Tier 4 forge nodes

Tier 3 Legendary Smith:
  - +100% crafting speed at forge nodes
  - -30% material cost for weapon/armor recipes
  - +2 guaranteed substats on crafted items
  - 10% chance to craft with +1 random socket
  - Unlocks: Tier 5 legendary recipes
  - Passive: All forges produce enhancement powder passively
```

### Resource Generation Rates (Per Hour)

**Tier 1 Nodes (No Spec Required)**
- Mine: 50 iron ore, 20 copper ore, 10 stone
- Forest: 60 wood, 30 herbs
- Temple: 20 mana crystals, 5 common souls (per day)

**Tier 2 Nodes (Tier 1 Spec Required)**
- Mine: 30 steel ingots, 15 mythril ore, 5 gems
- Forest: 40 rare herbs, 20 wood, 10 enhancement powder (low)
- Forge: 20 steel ingots, 10 enhancement powder (low), 5 socket crystals
- Temple: 30 mana crystals, 10 rare souls (per day), 5 fire/water/earth powder (low)

**Tier 3 Nodes (Tier 2 Spec Required)**
- Mine: 20 mythril ore, 10 magic crystals, 3 ancient gems
- Forest: 30 rare herbs, 15 enhancement powder (mid), 5 blessed oil
- Forge: 15 forging flames, 20 enhancement powder (mid), 10 socket crystals
- Temple: 20 magic crystals, 5 epic souls (per day), 10 element powder (mid)

**Tier 4-5 Nodes (Tier 2-3 Spec Required)**
- Mine: 10 adamantite ore, 5 divine ore, 2 perfect gems
- Forest: 20 enhancement powder (high), 10 blessed oil
- Forge: 10 forging flames, 5 divine ore, 30 enhancement powder (high)
- Temple: 10 legendary souls (per week), 5 awakening stones, 20 element powder (high)
- Special: 5 celestial essence, 3 ascension crystals, 1 mythic equipment (per week)

### Progression Gates & Reasons to Specialize

**Level 1-20: Early Game**
- Collect gods from summoning
- Capture Tier 1 nodes for basic resources
- Craft common/rare equipment
- Run equipment dungeons for gear
- **Goal:** Level gods to 20, choose specializations

**Level 20-30: Mid Game Begins**
- Choose Tier 1 specializations for each god
- Unlock Tier 2 nodes (better resources)
- Craft epic equipment with guaranteed substats
- Run elemental sanctums for awakening materials
- **Goal:** Awaken key gods, build first epic equipment sets

**Level 30-40: Mid Game Peak**
- Unlock Tier 2 specializations
- Capture Tier 3 nodes (rare materials)
- Craft legendary equipment with multiple guaranteed substats
- Run boss dungeons for legendary drops
- **Goal:** Full legendary equipment sets, multiple awakened gods

**Level 40-50: Late Game**
- Unlock Tier 3 specializations
- Capture Tier 4-5 nodes (endgame materials)
- Craft mythic equipment with perfect substats
- Run raid dungeons for divine materials
- **Goal:** Mythic equipment sets, perfect gem socketing, guild wars

### Endgame Resource Sinks

**God Collection:**
- Continue summoning for duplicate gods → skill power-ups
- Awaken all gods → requires massive awakening materials
- Max level all gods → requires mana

**Equipment Perfection:**
- Enhance all equipment to +15 → requires massive enhancement materials
- Add 2-3 sockets to all equipment → requires many socket crystals
- Socket perfect gems → requires farming gems and crafting refined/perfect versions
- Reroll substats for perfection → new system (costs blessed oil + mana)

**Territory Domination:**
- Upgrade all nodes to max production level → costs gold + materials
- Defend nodes from PvP raids → requires strong garrison gods
- Connect all nodes for maximum bonuses → strategic territory management

**PvP & Competitive:**
- Arena rankings → requires best equipment and god compositions
- Territory raids → steal resources from other players
- Guild wars → coordinate with guild to control world boss nodes
- Seasonal events → limited-time nodes with exclusive materials

---

## Resource Economy Philosophy

### Core Design Principle: Purpose-Driven Resources
**"Every resource must have clear purpose. Make it feel cool to go for what you need."**

This isn't a matching simulator - it's a strategic empire builder where players can specialize in what they enjoy and still progress.

### Supported Playstyles

#### 🎣 The Fisher King (Pure Gatherer)
- **Fantasy:** "I just want to fish and chill"
- **Path:** Specialize coast/fishing nodes → Ocean Master (Tier 3)
- **Rewards:** 2-3x fish/pearls production, passive income from selling to crafters
- **Cool Factor:** Guild-wide +15% coast production aura, literal mountains of AFK resources

#### ⚔️ Arena Gladiator (Pure PvP)
- **Fantasy:** "I only care about combat and rankings"
- **Path:** Raid enemy territories → Steal resources → Buy crafted gear from market
- **Rewards:** Skip territory management, get resources through PvP theft
- **Cool Factor:** 10% theft from raids, 24/7 raiding availability

#### 🔨 Master Crafter (Pure Production)
- **Fantasy:** "I want to be THE blacksmith everyone needs"
- **Path:** Specialize forge nodes → Legendary Smith (Tier 3)
- **Rewards:** -30% material costs, +2 guaranteed substats, passive enhancement powder
- **Cool Factor:** Market monopoly on legendary gear, guild dependency

#### 📚 The Scholar (Research/Support)
- **Fantasy:** "Knowledge is power, I'll unlock everything first"
- **Path:** Specialize library nodes → unlock recipes/training
- **Rewards:** Early access to recipes, train gods faster, sell knowledge
- **Cool Factor:** Guild research bonuses, unlock content others can't access

#### 💤 AFK Emperor (Full Idle)
- **Fantasy:** "I want to login once a day and collect everything"
- **Path:** Strategic node placement → Connected bonuses → Max workers
- **Rewards:** +30% production from connected nodes, optimized overnight gains
- **Cool Factor:** 10 nodes producing 24/7, wake up to full inventory

#### 🏴‍☠️ Territory Raider (Conquest Focus)
- **Fantasy:** "I want to control the most valuable nodes"
- **Path:** Rush high-tier nodes → Build supply chains → Defend aggressively
- **Rewards:** Legendary resources from Tier 4-5 nodes, strategic dominance
- **Cool Factor:** Control mythic resource spawn points, gate endgame materials

### Node Type Purposes (Why Players Want Each)

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

### Trading Economy
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

### AFK Optimization Strategy
Strategic placement > button-mashing:

1. **Connected Node Chains** - Build 4+ connected nodes for +30% production
2. **Worker Specialization** - Assign gods with matching specs for +200% efficiency
3. **Upgrade Priority** - Max production on nodes that generate your bottleneck resource
4. **Distance Management** - Keep high-value nodes close to base (95% defense vs 50%)
5. **Garrison Strategy** - Defend key nodes, let low-value nodes be contested

**Result:** Login once/day, collect 24 hours of optimized production, progress faster than active players who don't strategize.

### Resource Coherence Rules

1. **Every resource has ≥2 uses** - No dead-end materials
2. **Higher tiers require lower tiers** - Steel needs iron, mythril needs steel
3. **Specialization creates mastery** - Not +10%, but +200% with unique abilities
4. **No forced matching** - Trade/raid to get what you need
5. **AFK-friendly** - Strategic setup > constant clicking

### Current Implementation Status
- ✅ 49 core resources across all tiers and categories
- ✅ 10 MVP crafting recipes with tier progression
- ✅ Hex node production aligned with resources.json
- ✅ Specialization bonuses integrated (24 traits, 84 specs)
- ✅ Trading economy foundation (ResourceManager handles transactions)
- ✅ Connected node bonuses (TerritoryProductionManager)
- ✅ 90%+ test coverage (42 unit tests)

**See RESOURCE_PHILOSOPHY.md for detailed player archetype breakdowns and node efficiency calculations.**

---

## Design Decisions

### Hex Grid Size
- Start with ~50 nodes for MVP
- Expand to 100+ in updates
- Ring structure ensures balanced progression

### Distance Penalty
- 5% per hex distance from base
- Creates meaningful strategic choices
- Prevents "grab everything" gameplay

### Raid Cooldowns
- Win: Can raid same node again after 24 hours
- Lose: 8-hour cooldown
- Prevents grief raids

### Node Respawn
- Neutral nodes respawn defenders 24 hours after capture
- Abandoned player nodes return to neutral after 7 days

---

## Glossary

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

---

## Key Takeaways - Resource Economy

### Why Players Need Resources:
1. **Equipment Progression** - Craft, enhance, socket gear for combat power
2. **God Progression** - Level, awaken, ascend gods for better stats and abilities
3. **Territory Expansion** - Upgrade nodes, unlock higher tiers, increase production
4. **Combat Readiness** - Enter dungeons, battles, raids (costs energy)
5. **Collection Growth** - Summon new gods with souls and mana

### The Core Loop:
```
Capture Nodes → Assign Gods → Generate Resources
       ↓
Craft Equipment → Enhance Combat Power → Clear Harder Dungeons
       ↓
Get Better Loot → Upgrade Gods → Unlock Tier 2-3 Specializations
       ↓
Capture Better Nodes → Get Rare Resources → Craft Legendary Equipment
       ↓
Endgame: Mythic Gear, Perfect Gems, PvP Territory Wars
```

### Specialization Gating Creates Progression:
- **No Spec:** Only Tier 1 nodes (basic resources, common/rare equipment)
- **Tier 1 Spec (Level 20):** Unlock Tier 2 nodes (rare resources, epic equipment recipes)
- **Tier 2 Spec (Level 30):** Unlock Tier 3 nodes (mythril, magic crystals, legendary recipes)
- **Tier 3 Spec (Level 40):** Unlock Tier 4-5 nodes (adamantite, divine ore, mythic recipes)

### Equipment Quality Determines Combat Success:
- Common/Rare: Early game content, basic dungeons
- Epic: Mid game content, boss dungeons, PvP arena
- Legendary: Late game content, raid dungeons, territory wars
- Mythic: Endgame content, world bosses, guild wars

### Resource Flow Prevents Skipping Content:
- Can't craft legendary equipment without Tier 3 node materials
- Can't access Tier 3 nodes without Tier 2 specializations
- Can't get Tier 2 specializations without leveling gods (requires resources from Tier 1-2 nodes)
- Can't efficiently gather Tier 2 resources without Tier 1 specialization bonuses
- **Result:** Players must progress naturally through all tiers

---

*Last Updated: 2026-01-16 - Added comprehensive Resource & Crafting Economy section*

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

*Last Updated: Hex territory system design session*

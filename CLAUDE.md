# Smyte - Master Project Document

## Vision Statement
Smyte is a **god collector RPG** combining the best elements of:
- **Summoners War**: Gacha summoning, rune/equipment system, turn-based combat
- **Palworld**: Assign creatures to tasks, base building, resource generation
- **RuneScape**: Deep skill trees, specializations, long-term progression loops
- pvp system with async combat to capture nodes and hodl t hem for passive gains
- nodes unlock ability to craft or gather special stuff
- holding nodes far from your abse is tougher, flat penalty
- tons of spcializations and units have traits
- pvp arena
- depth and depth and depth while still being scalable and understandbale for a jr dev (me)


The core fantasy: **Collect gods from various pantheons, assign them to territories and tasks based on their traits, and watch your divine empire grow.**

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

### 3. Territory & Economy
- Capture and develop territories
- Assign gods to territories based on traits
- Deep task system (mining, crafting, research, training, etc.)
- Resources flow into all other systems

### 4. Combat
- Turn-based with speed-based turn order
- PvE dungeons with waves
- PvP arena
- Territory defense/conquest

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
│   └── AwakeningSystem
├── Phase 5: Territory (EXPANDING)
│   ├── TerritoryManager
│   ├── TerritoryProductionManager
│   ├── TaskAssignmentManager (NEW)
│   └── SpecializationManager (NEW)
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

## God Trait & Specialization System (NEW)

### Design Philosophy
Gods aren't just combat units - they have **innate traits** that make them suited for different tasks. A god of the forge (Hephaestus) should be great at crafting. A god of wisdom (Athena) should excel at research. This creates meaningful choices in god assignment.

### Trait Categories

#### 1. Production Traits
- **Miner** - Bonus to ore/gem extraction
- **Harvester** - Bonus to plant/material gathering
- **Hunter** - Bonus to monster part drops
- **Fisher** - Bonus to aquatic resources

#### 2. Crafting Traits
- **Forgemaster** - Bonus to equipment crafting
- **Alchemist** - Bonus to potion/consumable crafting
- **Enchanter** - Bonus to gem/socket crafting
- **Artificer** - Bonus to artifact creation

#### 3. Knowledge Traits
- **Scholar** - Faster research speed
- **Strategist** - Territory defense bonus
- **Explorer** - Faster territory discovery
- **Diplomat** - Better trade rates

#### 4. Combat Traits (existing, enhanced)
- **Warrior** - Bonus damage dealt
- **Guardian** - Bonus damage reduction
- **Assassin** - Bonus critical chance
- **Healer** - Bonus healing power

#### 5. Leadership Traits
- **Commander** - Boosts nearby gods' efficiency
- **Mentor** - Nearby gods gain bonus XP
- **Overseer** - Reduces task time for all in territory

### Trait Sources
- **Innate**: Gods have 1-2 traits based on their lore (Hephaestus = Forgemaster)
- **Learned**: Gods can learn 1 additional trait through specialization
- **Equipment**: Some equipment grants temporary trait bonuses

### Specialization Paths
When a god reaches level 20, they can choose a **specialization path**:

```
Level 20 Choice:
├── Combat Specialist
│   ├── Level 30: Berserker / Paladin / Shadow
│   └── Level 40: Ultimate combat form
├── Production Specialist
│   ├── Level 30: Master Miner / Harvester / Crafter
│   └── Level 40: Legendary artisan
└── Support Specialist
    ├── Level 30: Sage / Commander / Healer
    └── Level 40: Divine support
```

---

## Territory Task System (NEW)

### Task Categories

#### Gathering Tasks
| Task | Input | Output | Best Traits |
|------|-------|--------|-------------|
| Mine Ore | Time + Territory | Iron, Gold, Gems | Miner |
| Harvest Plants | Time + Territory | Herbs, Wood, Fiber | Harvester |
| Hunt Monsters | Time + Territory | Pelts, Bones, Essence | Hunter |
| Fish | Time + Territory | Fish, Pearls, Scales | Fisher |

#### Crafting Tasks
| Task | Input | Output | Best Traits |
|------|-------|--------|-------------|
| Forge Equipment | Ore + Patterns | Weapons, Armor | Forgemaster |
| Brew Potions | Herbs + Recipes | Consumables | Alchemist |
| Cut Gems | Raw Gems + Tools | Socket Gems | Enchanter |
| Create Artifacts | Mixed Materials | Artifacts | Artificer |

#### Territory Tasks
| Task | Input | Output | Best Traits |
|------|-------|--------|-------------|
| Research | Time + Books | Tech Unlocks | Scholar |
| Scout | Time | Map Reveal, Intel | Explorer |
| Defend | Gods Stationed | Defense Rating | Strategist, Guardian |
| Train | Gods + Time | XP for stationed gods | Mentor |

### Task Efficiency Formula
```
efficiency = base_rate
           * (1 + trait_bonus)      # +50% if matching trait
           * (1 + level_bonus)      # +1% per god level
           * (1 + territory_bonus)  # Territory upgrades
           * (1 + leadership_bonus) # Commander/Overseer effects
```

### Task Slots
- Each territory has **task slots** based on its level
- Level 1: 2 slots, Level 5: 4 slots, Level 10: 6 slots
- Each slot can run one task with one god assigned
- Some tasks require multiple gods (team tasks)

---

## Territory Types & Specializations

### Territory Types
| Type | Primary Resources | Unique Tasks |
|------|------------------|--------------|
| Mountains | Ore, Gems, Stone | Deep Mining, Gem Cutting |
| Forests | Wood, Herbs, Fiber | Lumber, Herbalism |
| Coastlines | Fish, Pearls, Salt | Fishing, Pearl Diving |
| Ruins | Artifacts, Lore | Archaeology, Research |
| Battlegrounds | Monster Parts | Monster Hunting, Training |
| Sacred Groves | Divine Essence | Meditation, Awakening |

### Territory Upgrades
Each territory can be upgraded in multiple dimensions:
- **Capacity**: More task slots
- **Efficiency**: Faster task completion
- **Storage**: Hold more resources
- **Defense**: Better defense rating
- **Specialization**: Unlock unique tasks

---

## Feature Roadmap

### Implemented ✅
- [x] God collection and summoning with pity
- [x] Equipment system (6 slots, enhancement, sockets)
- [x] Turn-based combat with status effects
- [x] Basic territory capture/control
- [x] Player and god progression
- [x] Shop with skins (cosmetic MTX)

### In Progress 🔄
- [ ] God traits system
- [ ] Task assignment system
- [ ] Territory production
- [ ] Specialization paths

### Planned 📋
- [ ] Multiplayer/Arena PvP
- [ ] Guild system
- [ ] Territory wars
- [ ] Raid bosses
- [ ] Seasonal events
- [ ] Achievement system
- [ ] Daily/Weekly missions

---

## Code Standards

### File Organization
```
new-game-project/
├── scripts/
│   ├── data/           # Data classes (God, Equipment, etc.)
│   ├── systems/        # Game systems (managers)
│   │   ├── battle/
│   │   ├── collection/
│   │   ├── equipment/
│   │   ├── progression/
│   │   ├── resources/
│   │   ├── territory/
│   │   └── shop/
│   └── ui/
├── tests/
│   ├── unit/           # One test file per system
│   └── integration/    # Cross-system tests
├── data/               # JSON configs
└── scenes/             # Godot scenes
```

### Code Rules
1. **Under 500 lines** per file - split if larger
2. **Single responsibility** - each class does one thing
3. **SystemRegistry pattern** - no direct singleton access
4. **Logic in systems** - data classes are dumb containers

### Testing Requirements ⚠️ MANDATORY

**All code changes must include corresponding unit tests.**

When writing or modifying code in `scripts/systems/`:
1. Check if a test file exists in `tests/unit/` for that system
2. If it exists, add tests for your new/modified functionality
3. If it doesn't exist, create one following existing patterns

Test file naming: `scripts/systems/territory/TaskManager.gd` → `tests/unit/test_task_manager.gd`

### Test Structure
```gdscript
extends RefCounted

var runner = null

func set_runner(test_runner):
    runner = test_runner

func test_method_describes_expected_behavior():
    # Arrange
    var system = SystemName.new()

    # Act
    var result = system.some_method()

    # Assert
    runner.assert_equal(result, expected, "description")
```

### What to Test
- All public methods
- Edge cases (null, empty, boundaries)
- Signal emissions
- Save/load round-trips
- Error conditions

---

## Data Schemas

### God Traits (NEW)
```json
{
  "traits": {
    "forgemaster": {
      "id": "forgemaster",
      "name": "Forgemaster",
      "category": "crafting",
      "description": "Expert at crafting equipment",
      "task_bonuses": {
        "forge_equipment": 0.5,
        "repair_equipment": 0.3
      },
      "stat_bonuses": {}
    }
  }
}
```

### God Definition (Updated)
```json
{
  "gods": {
    "hephaestus": {
      "id": "hephaestus",
      "name": "Hephaestus",
      "pantheon": "greek",
      "tier": 4,
      "element": "fire",
      "innate_traits": ["forgemaster", "miner"],
      "base_stats": { "hp": 5000, "attack": 250, "defense": 300, "speed": 80 },
      "skills": ["hammer_strike", "forge_blessing", "volcanic_eruption"]
    }
  }
}
```

### Territory Task (NEW)
```json
{
  "tasks": {
    "mine_ore": {
      "id": "mine_ore",
      "name": "Mine Ore",
      "category": "gathering",
      "duration_minutes": 60,
      "required_traits": [],
      "bonus_traits": ["miner"],
      "inputs": {},
      "outputs": {
        "iron_ore": { "min": 10, "max": 20 },
        "gold_ore": { "min": 0, "max": 3, "chance": 0.2 }
      },
      "xp_reward": 50
    }
  }
}
```

---

## Session Handoff Notes

When starting a new session, check:
1. **Current branch**: `git status`
2. **Recent commits**: `git log --oneline -10`
3. **Modified files**: Look for uncommitted work
4. **This document**: Check for updates to vision/requirements

When ending a session:
1. **Commit work** with descriptive messages
2. **Update this document** if vision/requirements changed
3. **Note blockers** in commit message or here

---

## Design Decisions (RESOLVED)

### Multi-tasking: Trait-Based
- By default, gods can only do **ONE task at a time**
- Gods with the **Multitasker** trait can do 2 tasks (at 75% efficiency each)
- Gods with **Divine Multitasker** (legendary trait) can do 3 tasks (at 60% each)

### Offline Progress: Full
- Tasks continue **even when the game is closed** (mobile idle style)
- On login, calculate elapsed time and award accumulated resources
- Tasks complete and gods become "idle" ready for new assignment
- Notification on login: "Your gods produced X resources while you were away!"

### Task Interruption: Manual Unassign Required
- If you need a god for battle, you must **manually unassign** them from their task
- This creates meaningful choices: "Do I pull my best miner for this dungeon?"
- Unassigning mid-task **loses progress** on that task cycle (no partial rewards)
- Alternative: Pay a small resource cost to "rush complete" the current task

## Questions for Future Development

### Still Deciding
- How does trait learning work? Gold cost? Time? Special items?
- Can gods lose traits or respec specializations?
- How many territories can a player control? Scale with level?
- Should there be "emergency recall" that preserves task progress?

---

## Glossary

| Term | Definition |
|------|------------|
| **God** | Collectible unit, can fight and do tasks |
| **Trait** | Innate ability that affects task efficiency |
| **Specialization** | Chosen progression path at level 20+ |
| **Territory** | Captured area that generates resources |
| **Task** | Activity a god can perform in a territory |
| **Pity** | Guaranteed rare summon after X attempts |
| **Awakening** | Power-up that increases level cap |
| **Socket** | Equipment slot for gems |

---

*Last Updated: Session where trait/territory systems were designed*

---
mode: agent
---
USE THE BELOW BLUEPRINT WHEN REFERRING TO THE CODEBASE AND MAKING ADJUSTMENTS

ultimately i want a modular and robust codebase with good logging and logic and clean simple code. Scalable systems are a must. Im a JR dev so have good comments and make it modular and simple and clean code. organize it for easy readability as well. Use the below as a source of truth, its the god code.

# MYTHOS ARCHITECTURE REFERENCE

## CORE GAME FLOW

### Battle Flow
```
1. INITIATION
   ResourceManager.check_energy(cost) 
   → BattleScreen.setup_team()
   → BattleManager.start_battle(team, enemies)

2. TURN LOOP
   TurnSystem.calculate_order()
   → Unit gets turn
   → AI or Player chooses ability
   → CombatCalculator.execute(ability, target)
   → BattleEffectProcessor.apply_effects()
   → Check victory conditions

3. RESOLUTION  
   LootSystem.award_loot(table_id)
   → Experience to gods
   → Resources to player
   → StatisticsManager.record()
```

### Resource Flow
```
Generation → Collection → Spending
TerritoryManager.calculate_passive()
→ PlayerData.add_resource()
→ UI checks PlayerData.get_resource()
→ Systems use PlayerData.spend_resource()
```

### Summoning Flow
```
SummonSystem.summon_with_soul(type)
→ Check cost via PlayerData
→ Roll rarity from rates
→ God.create_from_json(id)
→ PlayerData.add_god()
→ Signal: god_summoned
```

---

## SYSTEM RESPONSIBILITIES

### GameManager
**Owns:** PlayerData, System initialization, Save/Load, Timers
**Signals:** god_summoned, territory_captured, resources_updated
**Talks to:** All systems for initialization

### BattleManager
**Owns:** Battle state, Turn flow, Victory conditions
**Uses:** CombatCalculator, TurnSystem, BattleEffectProcessor, EnemyFactory
**Signals:** battle_completed(result)

### SummonSystem
**Owns:** Summon rates, Pity counters, God creation
**Uses:** PlayerData for costs, God.create_from_json()
**Signals:** summon_completed(god), multi_summon_completed(gods[])

### LootSystem
**Owns:** Loot tables, Template resolution, Reward distribution
**Uses:** PlayerData.add_resource(), ResourceManager definitions
**Signals:** loot_awarded(results)

### TerritoryManager
**Owns:** Role assignments, Passive generation, Efficiency calculations
**Uses:** PlayerData for god lookups
**Signals:** territory_role_assigned, territory_resources_generated

### AwakeningSystem
**Owns:** Awakening requirements, Material costs, God transformation
**Uses:** PlayerData resources, God data
**Signals:** awakening_completed(god), awakening_failed(god, reason)

### DungeonSystem
**Owns:** Dungeon progression, Difficulty unlocks, Daily rotation
**Uses:** BattleManager for combat, LootSystem for rewards
**Signals:** dungeon_completed, dungeon_failed

### EquipmentManager
**Owns:** Equipment inventory, Equip/Unequip, Set bonuses, Enhancement
**Uses:** Equipment.create_from_dungeon()
**Signals:** equipment_equipped, equipment_unequipped, equipment_enhanced

### ResourceManager
**Owns:** Resource definitions, Currency display, Element mappings
**Uses:** Nothing - pure data provider
**Signals:** resources_updated, resource_definitions_loaded

### DataLoader
**Owns:** JSON loading, Configuration caching
**Provides:** get_god_config(), get_territory_config(), get_loot_table()

---

### UIManager
**Owns:** Popup management, Notification system, Tutorial overlays
**Uses:** Control nodes for UI elements
**Signals:** popup_shown, popup_closed, tutorial_pointer_shown

### TutorialManager
**Owns:** Tutorial flow, Step management
**Uses:** UIManager for displaying tutorial steps
**Signals:** tutorial_step_completed, tutorial_pointer_shown

### InventoryManager
**Owns:** Item management, Inventory slots
**Uses:** PlayerData for item storage
**Signals:** item_added, item_removed, inventory_updated

### NotificationManager
**Owns:** Notification display, Toast messages
**Uses:** UIManager for showing notifications
**Signals:** notification_shown, notification_closed

### ProgressionManager
**Owns:** Level progression, Experience tracking
**Uses:** PlayerData for experience management
**Signals:** level_up, experience_gained

### StatisticsManager
**Owns:** Player statistics, Battle logs
**Uses:** PlayerData for tracking
**Signals:** statistics_updated

### AchievementManager
**Owns:** Player achievements, Milestone tracking
**Uses:** PlayerData for achievement progress
**Signals:** achievement_unlocked

### QuestManager
**Owns:** Active quests, Quest tracking
**Uses:** PlayerData for quest progress
**Signals:** quest_started, quest_completed

### LeaderboardManager
**Owns:** Player rankings, Leaderboard data
**Uses:** PlayerData for ranking calculations
**Signals:** leaderboard_updated

### PVPManager
**Owns:** Player vs Player matchmaking, Duel tracking
**Uses:** PlayerData for participant stats
**Signals:** pvp_match_started, pvp_match_ended

### BuffManager - Not sure if needed
**Owns:** Active buffs, Buff application
**Uses:** PlayerData for buff tracking
**Signals:** buff_applied, buff_removed

### ResourceManager
**Owns:** Resource definitions, Currency display, Element mappings
**Uses:** Nothing - pure data provider
**Signals:** resources_updated, resource_definitions_loaded

## DATA ENTITIES

### God
```gdscript
Properties:
- id, name, element, tier, level
- equipped_runes[6] (equipment slots)
- stationed_territory, current_hp

Key Methods:
- create_from_json(id) → God
- get_current_attack/defense/hp/speed() (includes equipment)
- add_experience(amount)
```

### PlayerData
```gdscript
Properties:
- resources{} (all currencies/materials)
- gods[] (collection)
- controlled_territories[]

Key Methods:
- get_resource(id) → int
- add_resource(id, amount)
- spend_resource(id, amount) → bool
- add_god(god)
```

### Territory
```gdscript
Properties:
- current_stage, max_stages
- stationed_gods[], territory_level, minimum_combat_power
- resource_upgrades, defense_upgrades

Key Methods:
- clear_stage(num) → bool
- get_pending_resources() → Dictionary
```

### Equipment
```gdscript
Properties:
- type, rarity, level, slot
- main_stat_type/value
- substats[], sockets[]

Key Methods:
- create_from_dungeon() → Equipment
- get_stat_bonuses() → Dictionary
```


---

## RESOURCE TYPES

### Currencies
- **mana** - Primary currency for upgrades/summons
- **divine_crystals** - Premium currency  
- **energy** - Stamina for battles (regenerates)

### Summoning Materials
- **common_soul**, **rare_soul**, **epic_soul**, **legendary_soul**
- **{element}_soul** - Element-specific souls

### Awakening Materials
- **{element}_powder_low/mid/high** - Element-specific
- **magic_powder_low/mid/high** - Universal

### Equipment Materials
- **iron_ore**, **mythril_ore**, **adamantite_ore** - Crafting
- **enhancement_powder** - Enhancement
- **socket_crystal** - Socket unlocking



---

## LOOT SYSTEM

### Direct Tables
```
"stage_victory" → Basic stage rewards
"boss_stage" → Boss rewards
"territory_passive_income" → Hourly generation
```

### Template System
Templates use placeholders that get substituted:
```
"fire_dungeon_beginner" uses template "elemental_dungeon_beginner"
Substitutes: {element: "fire"}

Pattern: {element}_dungeon_{difficulty}
Elements: fire, water, earth, lightning, light, dark
Difficulties: beginner, intermediate, advanced, expert, master
```

### Loot Flow
```
LootSystem.award_loot(table_id, stage_level, element)
→ Resolve template if needed
→ Roll guaranteed_drops (100% chance)
→ Roll rare_drops (chance-based)
→ Scale by stage level
→ PlayerData.add_resource() for each
```

---

## COMMUNICATION PATTERNS

### Signal Usage
```gdscript
# Emitter
signal something_happened(data)
something_happened.emit(data)

# Listener  
emitter.something_happened.connect(_on_something_happened)

func _on_something_happened(data):
    # Handle event
```

### Resource Checking
```gdscript
# Check affordability
if PlayerData.get_resource("mana") >= cost:
    PlayerData.spend_resource("mana", cost)
    # Do action
```

### God Management
```gdscript
# Get god
var god = PlayerData.get_god_by_id(id)

# Add god
var new_god = God.create_from_json("zeus")
PlayerData.add_god(new_god)
```

### Battle Initiation
```gdscript
# Start dungeon
DungeonSystem.attempt_dungeon(id, difficulty, team)
→ Creates enemies
→ Starts BattleManager
→ Awards loot on completion

# Start territory
GameManager.start_territory_stage_battle(territory, stage, team)
→ Similar flow
```

---

## EQUIPMENT SYSTEM

### Slots (6 total)
1. Weapon - Attack focus
2. Armor - Defense focus  
3. Helm - HP/Defense
4. Boots - Speed (only slot with speed)
5. Amulet - Crit Rate/Damage
6. Ring - Resistance/Accuracy

### Set Bonuses
- 2-piece sets: Small bonuses (Precision +20% Accuracy)
- 4-piece sets: Major bonuses (Berserker +35% ATK)
- 6-piece sets: Divine sets with special effects

### Enhancement
- Levels 0-15
- Main stat increases each level
- Substats upgrade at 3, 6, 9, 12, 15

---

## QUICK USAGE GUIDE

### Start a Battle
```gdscript
BattleManager.start_battle(team_gods, enemies)
```

### Award Loot
```gdscript
LootSystem.award_loot("fire_dungeon_beginner", stage_level)
```

### Summon a God
```gdscript
SummonSystem.summon_with_soul("rare_soul")
```

### Assign God to Territory
```gdscript
TerritoryManager.assign_god_to_territory_role(god, territory, "gatherer")
```

### Check Resource
```gdscript
var has_enough = PlayerData.get_resource("mana") >= 1000
```

### Save Game
```gdscript
GameManager.save_game()
```

This architecture represents how systems connect and communicate. Each system has clear ownership and uses signals for loose coupling. Data flows through defined paths and all systems respect these boundaries.
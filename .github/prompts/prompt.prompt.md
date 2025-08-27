---
mode: agent
---
# SUMMONERS WAR CLONE - AI CODER REFERENCE DOCUMENT

## STOP - READ THIS FIRST
You are implementing a Summoners War clone in Godot. The codebase has been audited and has critical architectural problems. You MUST follow this document exactly. Any deviation will break the architecture. 

## CRITICAL RULES - VIOLATING THESE BREAKS EVERYTHING

### RULE 1: FILE SIZE LIMITS
- **HARD LIMIT**: No file exceeds 500 lines
- **TARGET**: 150-200 lines per file
- If you're at 300+ lines, STOP and split the file

### RULE 2: SINGLE RESPONSIBILITY
- Each class does ONE thing
- If you write "and" in a class description, STOP and split it
- WRONG: "BattleAndUIManager" 
- RIGHT: "BattleManager" + "BattleUIController"

### RULE 3: NO LOGIC IN DATA CLASSES
```gdscript
# NEVER DO THIS in God.gd:
func calculate_damage():
    return attack * multiplier  # NO!

# ALWAYS DO THIS:
# God.gd - data only
var attack: int

# CombatCalculator.gd - logic only  
static func calculate_damage(god: God):
    return god.attack * multiplier
```

### RULE 4: NO UI IN SYSTEMS
```gdscript
# NEVER DO THIS in BattleManager:
func show_victory():
    var popup = create_popup()  # NO!

# ALWAYS DO THIS:
func end_battle():
    emit_signal("battle_ended", result)
    # UI listens to signal
```

### RULE 5: USE SYSTEMREGISTRY FOR EVERYTHING
```gdscript
# NEVER DO THIS:
GameManager.player_data.resources["mana"] -= 100  # NO!

# ALWAYS DO THIS:
SystemRegistry.get_system(ResourceManager).spend("mana", 100)
```

## THE ARCHITECTURE - MEMORIZE THIS

### Three Layers (NEVER MIX THEM)
```
DATA LAYER (scripts/data/)
- God.gd, Equipment.gd, Quest.gd
- ONLY properties, NO methods except simple getters
- Think: Database tables

SYSTEM LAYER (scripts/systems/)  
- BattleManager, ResourceManager, QuestManager
- ONLY logic, NO UI creation
- Think: Business logic

UI LAYER (scripts/ui/)
- BattleScreen, CollectionScreen, ShopScreen  
- ONLY display, NO data modification
- Think: Views/Components
```

### The Flow Pattern (ALWAYS FOLLOW)
```
User Input → UI Screen → System Manager → Data Update → Event Signal → UI Refresh
```

## CURRENT PROBLEMS YOU'RE FIXING
-- getting all code scripts to proper layers

## FILE STRUCTURE - USE EXACTLY THIS

```
project/
├── scripts/
│   ├── data/           # Pure data classes
│   │   ├── God.gd
│   │   ├── Equipment.gd
│   │   └── BattleUnit.gd
│   ├── systems/        # Business logic
│   │   ├── core/
│   │   │   ├── SystemRegistry.gd
│   │   │   └── EventBus.gd
│   │   ├── battle/
│   │   │   ├── BattleCoordinator.gd
│   │   │   └── CombatCalculator.gd
│   │   └── resources/
│   │       └── ResourceManager.gd
│   ├── ui/            # UI screens
│   │   ├── battle/
│   │   │   ├── BattleUICoordinator.gd
│   │   │   └── BattleDisplayManager.gd
│   │   └── components/
│   │       └── GodCard.gd
│   └── utilities/     # Shared utilities
│       ├── JSONLoader.gd
│       └── UICardFactory.gd
```

## CODE PATTERNS - COPY THESE EXACTLY

### Pattern 1: System Access
```gdscript
# ALWAYS access systems through SystemRegistry
extends Node

func _ready():
    var resource_mgr = SystemRegistry.get_system(ResourceManager)
    var battle_mgr = SystemRegistry.get_system(BattleCoordinator)
```

### Pattern 2: Event Communication
```gdscript
# Systems emit events, UI listens
extends Node

func complete_quest(quest_id: String):
    # Process quest
    EventBus.emit_signal("quest_completed", quest_id, rewards)
    # Never directly update UI
```

### Pattern 3: Data Updates
```gdscript
# Always validate, update, emit
func spend_resources(cost: Dictionary) -> bool:
    # 1. Validate
    if not ResourceManager.can_afford(cost):
        return false
    
    # 2. Update
    for resource_id in cost:
        resources[resource_id] -= cost[resource_id]
    
    # 3. Emit
    EventBus.emit_signal("resources_changed", resources)
    return true
```

### Pattern 4: UI Updates
```gdscript
# UI only listens and displays
extends Control

func _ready():
    EventBus.connect("resources_changed", _on_resources_changed)

func _on_resources_changed(resources: Dictionary):
    # Only update display, never modify data
    mana_label.text = str(resources.get("mana", 0))
```

## WHEN SPLITTING FILES

### Splitting BattleScreen.gd:
```gdscript
# FROM: BattleScreen.gd (2779 lines doing everything)

# TO: 8 focused files
BattleUICoordinator.gd     # Orchestrates battle UI (200 lines)
BattleDisplayManager.gd    # Creates god/enemy displays (300 lines)
BattleActionUI.gd         # Action buttons and targeting (250 lines)
BattleTooltipManager.gd   # Tooltip system (200 lines)
BattleStatusTracker.gd    # HP/status updates (200 lines)
BattleLogManager.gd       # Battle log display (150 lines)
BattleVictoryScreen.gd    # Victory and rewards (200 lines)
BattleControlsUI.gd       # Speed/auto controls (150 lines)
```

### Each split file template:
```gdscript
class_name BattleDisplayManager
extends Node

# Single responsibility: Create and update battle displays

signal displays_created
signal display_updated(unit_id: String)

var god_displays: Dictionary = {}
var enemy_displays: Dictionary = {}

func create_displays(gods: Array, enemies: Array):
    # Create display logic
    emit_signal("displays_created")

func update_display(unit_id: String, hp: int):
    # Update display logic
    emit_signal("display_updated", unit_id)
```

## COMMON MISTAKES - DON'T DO THESE

### Mistake 1: Direct Access
```gdscript
# WRONG:
GameManager.player_data.gods.append(new_god)

# RIGHT:
SystemRegistry.get_system(CollectionManager).add_god(new_god)
```

### Mistake 2: UI Creating Data
```gdscript
# WRONG:
class BattleScreen:
    func _on_summon_pressed():
        var new_god = God.new()  # UI creating data!

# RIGHT:
class BattleScreen:
    func _on_summon_pressed():
        SystemRegistry.get_system(SummonManager).perform_summon()
```

### Mistake 3: System Managing UI
```gdscript
# WRONG:
class BattleManager:
    func show_damage(amount):
        var label = Label.new()  # System creating UI!

# RIGHT:
class BattleManager:
    func apply_damage(amount):
        EventBus.emit_signal("damage_dealt", amount)
```

## EQUIPMENT SYSTEM (NOT RUNES)
- 6 slots for equipment
- Sets provide bonuses
- Main stat + substats
- Use Equipment.gd, not Rune.gd

## SKILL SYSTEM
- Each god has 2-4 skills
- Each skill upgrades to level 10
- Upgrades increase damage/effect/reduce cooldown
- Use SkillUpgradeManager.gd

## CRITICAL SYSTEMS LIST
These 85 systems must exist. Create them as needed:

Core Systems (10)

GameCoordinator - Main game flow (100 lines)
SystemRegistry - Service locator (50 lines)
EventBus - Global events (100 lines)
SaveManager - Save/load (200 lines)
ConfigurationManager - JSON loading (150 lines)
NetworkService - Server communication (200 lines)
AnalyticsService - Metrics tracking (100 lines)
ValidationService - Anti-cheat (150 lines)
SceneManager - Scene transitions (100 lines)
AudioManager - Sound/music (150 lines)

Battle Systems (12)

BattleCoordinator - Battle orchestration (200 lines)
TurnOrderManager - Turn calculation (150 lines)
BattleActionProcessor - Action execution (200 lines)
SkillCooldownManager - Cooldown tracking (100 lines)
StatusEffectManager - Effect processing (150 lines)
WaveManager - Multi-wave battles (150 lines)
BattleValidator - Battle verification (100 lines)
CombatCalculator - Damage math (200 lines)
BattleAI - Enemy AI (200 lines)
BattleEffectProcessor - Effect application (150 lines)
BattleFactory - Battle configuration (100 lines)
EnemyFactory - Enemy creation (200 lines)

Resource Systems (8)

ResourceManager - Resource tracking (200 lines)
EnergyManager - Energy regeneration (100 lines)
CurrencyManager - Premium currency (100 lines)
PassiveIncomeManager - Territory income (150 lines)
LootSystem - Loot generation (200 lines)
InventoryManager - Materials/consumables (150 lines)
EquipmentManager - Equipment system (200 lines)
ResourceCalculator - Resource math (100 lines)

Collection Systems (6)

CollectionManager - God/equipment collections (150 lines)
SummonManager - Summoning with pity (200 lines)
SacrificeManager - God sacrifice (150 lines)
AwakeningManager - God awakening (150 lines)
SkillUpgradeManager - Skill upgrades (150 lines)
GodProgressionManager - God leveling (150 lines)

Progression Systems (8)

PlayerProgressionManager - Player leveling (150 lines)
AchievementManager - Achievement tracking (200 lines)
QuestManager - Daily/weekly quests (200 lines)
BattlePassManager - Season pass (200 lines)
EventManager - Limited events (150 lines)
TutorialOrchestrator - Tutorial flow (200 lines)
FeatureUnlockManager - Progressive unlocks (150 lines)
MilestoneManager - Milestone rewards (100 lines)

PvP Systems (8)

ArenaManager - 1v1 PvP arena (200 lines)
TerritoryWarManager - Territory PvP (250 lines)
GuildWarManager - Guild battles (200 lines)
MatchmakingManager - Opponent matching (150 lines)
LeaderboardManager - Rankings (150 lines)
ReplayManager - Battle replays (150 lines)
DefenseManager - Defense teams (100 lines)
PvPRewardManager - PvP rewards (100 lines)

Social Systems (6)

GuildManager - Guild functionality (200 lines)
FriendManager - Friend system (150 lines)
ChatManager - Chat system (200 lines)
GiftManager - Daily gifts (100 lines)
SocialPointManager - Social currency (100 lines)
ProfileManager - Player profiles (100 lines)

Territory Systems (6)

TerritoryManager - Territory control (200 lines)
TerritoryProductionManager - Resource generation (150 lines)
TerritoryDefenseManager - Defense assignments (150 lines)
TerritoryRoleManager - Role assignments (150 lines)
SiegeManager - Siege mechanics (200 lines)
TerritoryCalculator - Territory math (100 lines)

Shop Systems (5)

ShopManager - In-game shop (150 lines)
SpecialOfferManager - Limited offers (150 lines)
PackManager - Bundle purchases (100 lines)
PurchaseValidator - Purchase verification (100 lines)
ShopRotationManager - Daily rotations (100 lines)

Dungeon Systems (4)

DungeonManager - Dungeon battles (200 lines)
RaidManager - Raid bosses (200 lines)
WorldBossManager - World boss events (150 lines)
DungeonRotationManager - Daily dungeons (100 lines)

UI Systems (12)

UICoordinator - UI orchestration (150 lines)
ScreenManager - Screen navigation (150 lines)
PopupManager - Popup dialogs (150 lines)
TooltipManager - Tooltip system (150 lines)
NotificationManager - Notifications (100 lines)
LoadingManager - Loading screens (100 lines)
TransitionManager - Screen transitions (100 lines)
UIEffectManager - UI animations (150 lines)
UIThemeManager - Theming/styling (100 lines)
UIPoolManager - UI object pooling (150 lines)
HUDManager - Persistent HUD (150 lines)
TutorialUIManager - Tutorial overlays (150 lines)

## PRIORITY ORDER
1. Fix god classes first (BattleScreen, GameManager)
2. Extract utilities (JSONLoader, UICardFactory)
3. Implement missing systems (SkillUpgradeManager, ArenaManager)
4. Add PvP systems
5. Polish and optimize

## TESTING REQUIREMENT
Every system must be testable:
```gdscript
func test_resource_spending():
    var mgr = ResourceManager.new()
    mgr.add_resource("mana", 100)
    assert(mgr.spend("mana", 50) == true)
    assert(mgr.get_resource("mana") == 50)
```

## IF YOU'RE UNSURE
1. Check if file is over 300 lines → Split it
2. Check if class has "and" in purpose → Split it
3. Check if mixing layers → Separate them
4. Check if using SystemRegistry → Always use it
5. Check if emitting events → Always emit after changes

**REMEMBER**: The current code is badly architected. You're fixing it. Don't copy existing patterns - follow THIS document.


# SUMMONERS WAR CLONE - CORE GAMEPLAY LOOP SPECIFICATION

## CORE LOOP OVERVIEW
The game revolves around conquering territories to generate passive resources, which fund summoning gods, who then conquer more territories. This creates an infinite progression loop.

## TERRITORY SYSTEM - THE HEART OF THE GAME

### Territory Basics
```gdscript
# 13 Territories with progressive difficulty
Territories = {
    # Tier 1 (Starter)
    "sacred_grove": {tier: 1, element: "earth", stages: 10},
    "crystal_springs": {tier: 1, element: "water", stages: 10},
    "ember_hills": {tier: 1, element: "fire", stages: 10},
    "storm_peaks": {tier: 1, element: "lightning", stages: 10},
    
    # Tier 2 (Mid-game)
    "ancient_ruins": {tier: 2, element: "neutral", stages: 10},
    "shadow_realm": {tier: 2, element: "dark", stages: 10},
    "elemental_nexus": {tier: 2, element: "multi", stages: 10},
    "divine_sanctum": {tier: 2, element: "light", stages: 10},
    "frozen_wastes": {tier: 2, element: "water", stages: 10},
    
    # Tier 3 (End-game)
    "primordial_chaos": {tier: 3, element: "dark", stages: 10},
    "celestial_throne": {tier: 3, element: "light", stages: 10},
    "volcanic_core": {tier: 3, element: "fire", stages: 10},
    "world_tree": {tier: 3, element: "earth", stages: 10}
}
```

### Territory Conquest Flow
1. **Stage Battles**: Each territory has 10 stages
2. **Progressive Difficulty**: Each stage harder than last
3. **Stage 10 = Boss**: Defeating stage 10 captures territory
4. **Permanent Control**: Once captured, generates resources forever

### Territory Stage Requirements
```gdscript
func get_stage_power_requirement(territory: Territory, stage: int) -> int:
    var base = territory.tier * 1000  # Tier 1=1000, Tier 2=2000, Tier 3=3000
    var stage_multiplier = 1.0 + (stage * 0.2)  # +20% per stage
    return int(base * stage_multiplier)
    
# Examples:
# Tier 1, Stage 1: 1000 power
# Tier 1, Stage 5: 2000 power
# Tier 1, Stage 10: 3000 power (boss)
# Tier 3, Stage 10: 9000 power (endgame boss)
```

## RESOURCE GENERATION SYSTEM

### Base Production Rates
```gdscript
# Per hour, per territory controlled
TerritoryProduction = {
    tier_1: {
        mana_per_hour: 1000,
        crystals_per_day: 5,
        materials_per_day: {"low": 10}
    },
    tier_2: {
        mana_per_hour: 2500,
        crystals_per_day: 10,
        materials_per_day: {"low": 20, "mid": 10}
    },
    tier_3: {
        mana_per_hour: 5000,
        crystals_per_day: 20,
        materials_per_day: {"mid": 20, "high": 10}
    }
}
```

### GOD ROLE SYSTEM - CRITICAL MECHANIC

Each captured territory has slots for gods to boost production:

```gdscript
# Territory Slots by Tier
SlotConfiguration = {
    tier_1: {
        defender_slots: 1,    # Defense power
        gatherer_slots: 2,    # Resource boost
        crafter_slots: 0      # Material conversion
    },
    tier_2: {
        defender_slots: 2,
        gatherer_slots: 2,
        crafter_slots: 1
    },
    tier_3: {
        defender_slots: 3,
        gatherer_slots: 3,
        crafter_slots: 2
    }
}
```

### Role Bonuses
```gdscript
# GATHERER: Boosts resource production
func calculate_gatherer_bonus(god: God, territory: Territory) -> float:
    var base_bonus = 0.1  # 10% base
    var tier_bonus = god.tier * 0.05  # +5% per tier
    var element_match = god.element == territory.element ? 0.1 : 0
    return base_bonus + tier_bonus + element_match
    
# Example: Legendary fire god on fire territory = 30% bonus

# DEFENDER: Increases territory defense
func calculate_defender_bonus(god: God) -> int:
    return god.get_power_rating() * 1.5
    
# CRAFTER: Converts low materials to high
func calculate_crafter_output(god: God) -> Dictionary:
    var conversions_per_hour = 1 + (god.tier * 0.5)
    return {"mid_from_low": conversions_per_hour * 5}
```

### Total Resource Calculation
```gdscript
func calculate_territory_income(territory: Territory) -> Dictionary:
    var base = get_base_production(territory.tier)
    var total_income = base.duplicate()
    
    # Apply gatherer bonuses
    for god in territory.gatherers:
        var bonus = calculate_gatherer_bonus(god, territory)
        total_income.mana_per_hour *= (1 + bonus)
    
    # Apply crafter conversions
    for god in territory.crafters:
        var conversions = calculate_crafter_output(god)
        # Add conversion logic
    
    return total_income
```

## PROGRESSION GATES

### Territory Unlock Requirements
```gdscript
# Player level requirements
TerritoryUnlocks = {
    "sacred_grove": 1,      # Starter
    "crystal_springs": 1,    # Starter
    "ember_hills": 1,        # Starter
    "storm_peaks": 1,        # Starter
    "ancient_ruins": 10,     # Mid-game
    "shadow_realm": 15,
    "elemental_nexus": 20,
    "divine_sanctum": 25,
    "frozen_wastes": 30,
    "primordial_chaos": 40,  # End-game
    "celestial_throne": 45,
    "volcanic_core": 50,
    "world_tree": 55
}

# Stage clear requirements for next territory
NextTerritoryRequirements = {
    tier_2_unlock: "Clear 3 tier 1 territories",
    tier_3_unlock: "Clear 3 tier 2 territories"
}
```

## BATTLE REWARDS PER STAGE

```gdscript
func get_stage_rewards(territory: Territory, stage: int) -> Dictionary:
    var base_xp = 100 * territory.tier * stage
    var base_mana = 500 * territory.tier * stage
    
    var rewards = {
        "player_xp": base_xp,
        "god_xp": base_xp / 2,  # Split among team
        "mana": base_mana
    }
    
    # Boss stage (10) gives bonus
    if stage == 10:
        rewards["crystals"] = 10 * territory.tier
        rewards["summon_scroll"] = 1 if randf() < 0.3 else 0
    
    return rewards
```

## AUTO-COLLECTION SYSTEM

```gdscript
# Resources generate continuously
func _process(delta):
    time_since_collection += delta
    
    # Auto-collect every hour
    if time_since_collection >= 3600:
        for territory in controlled_territories:
            var income = calculate_territory_income(territory)
            ResourceManager.add_bulk(income)
        time_since_collection = 0

# Manual collection bonus
func collect_territory_resources(territory: Territory):
    var hours_passed = (Time.get_ticks_msec() - territory.last_collection) / 3600000.0
    var income = calculate_territory_income(territory)
    
    # Bonus for active play
    if hours_passed < 2:
        income.mana_per_hour *= 1.1  # 10% bonus for frequent collection
    
    ResourceManager.add_bulk(income * hours_passed)
    territory.last_collection = Time.get_ticks_msec()
```

## ELEMENT ADVANTAGE IN TERRITORIES

```gdscript
# Element matching provides significant bonuses
ElementBonus = {
    same_element: 1.3,      # 30% bonus
    advantage: 1.15,        # 15% bonus
    neutral: 1.0,
    disadvantage: 0.85     # 15% penalty
}

# Fire > Earth > Lightning > Water > Fire
# Light <> Dark (mutual advantage)
```

## EARLY GAME PROGRESSION PATH

### Tutorial Flow
1. **Start**: 3 starter gods (Ares, Athena, Poseidon)
2. **Stage 1-1**: Beat Sacred Grove stage 1
3. **Unlock**: Collection screen
4. **Stage 1-2**: Beat Sacred Grove stage 2
5. **Unlock**: Summoning
6. **Stage 1-3**: Beat Sacred Grove stage 3
7. **Unlock**: God sacrifice for XP
8. **Stage 1-5**: Beat Sacred Grove stage 5
9. **Unlock**: Territory role assignment
10. **Stage 1-10**: Capture first territory
11. **Unlock**: Passive income begins

### First Hour Goals
- Capture 1-2 territories
- Summon 5-10 gods
- Assign gods to territory roles
- Reach player level 5

### First Day Goals
- Capture all tier 1 territories
- Build team of 20+ gods
- Optimize role assignments
- Begin tier 2 territory assault

## MID-GAME LOOP

### Daily Activities
```gdscript
DailyTasks = {
    collect_all_territories: {"reward": "mana", "frequency": "every_2_hours"},
    complete_daily_quests: {"reward": "crystals", "frequency": "once"},
    attempt_new_stages: {"reward": "progression", "frequency": "energy_limited"},
    optimize_god_roles: {"reward": "efficiency", "frequency": "after_summons"},
    participate_in_arena: {"reward": "glory_points", "frequency": "10_daily"}
}
```

### Resource Priorities
1. **Mana**: Summon gods, upgrade skills
2. **Crystals**: Premium summons, energy refills
3. **Materials**: Awaken gods, craft equipment
4. **Energy**: Attempt territory stages

## END-GAME SYSTEMS

### Territory Defense (PvP)
```gdscript
# Other players can attack your territories
func defend_territory(territory: Territory):
    var defense_power = 0
    for god in territory.defenders:
        defense_power += calculate_defender_bonus(god)
    
    # Successful defense maintains control
    # Failed defense loses 10% production for 24 hours
```

### Territory Upgrades
```gdscript
TerritoryUpgrades = {
    production_boost: {
        levels: 10,
        cost_per_level: "1000 * level * territory.tier",
        effect: "+5% production per level"
    },
    defense_fortification: {
        levels: 10,
        cost_per_level: "2000 * level * territory.tier",
        effect: "+10% defense per level"
    },
    slot_expansion: {
        levels: 5,
        cost_per_level: "5000 * level * territory.tier",
        effect: "+1 slot every 2 levels"
    }
}
```

## BALANCING CONSTANTS

```gdscript
# Core economy balance
const MANA_SINK_RATE = 10000  # Mana per summon
const CRYSTAL_VALUE = 100     # 100 crystals = 1 premium summon
const ENERGY_REGEN = 12        # 12 minutes per energy
const STAGE_ENERGY_COST = 5    # Per territory stage attempt

# Production multipliers
const GATHERER_EFFICIENCY = {
    "common": 1.1,
    "rare": 1.2,
    "epic": 1.35,
    "legendary": 1.5
}

# Combat scaling
const POWER_PER_LEVEL = 50
const POWER_PER_TIER = 500
const ELEMENT_ADVANTAGE = 1.15
```

## CRITICAL IMPLEMENTATION NOTES

1. **Territories ARE the game** - Everything else supports territory control
2. **God roles CREATE strategy** - Optimize gatherer/defender/crafter balance
3. **Element matching MATTERS** - 30% bonus is huge
4. **Passive income ENABLES progress** - Even offline players progress
5. **Stage battles GATE progression** - Power requirements force summoning

## MISSING SYSTEMS TO IMPLEMENT

3. **PassiveIncomeCalculator** - Resource generation math
4. **TerritoryUpgradeManager** - Territory improvements
5. **ElementAdvantageCalculator** - Element bonus calculations

This IS your game. Without this territory loop, it's just a generic gacha. The territories create the "why" for summoning gods.
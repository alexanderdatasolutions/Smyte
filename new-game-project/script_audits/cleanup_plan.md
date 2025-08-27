 # Complete Summoners War Clone Architecture

## Core Architecture Principles
- **Single Responsibility**: Each system does ONE thing
- **Dependency Injection**: No static singletons, pass dependencies
- **Event-Driven**: Systems communicate through signals, not direct calls
- **Data-Model Separation**: Data classes hold data, systems hold logic
- **Configuration-Driven**: All balance values in JSON files
- **Turn-Based Combat**: No ATB, pure speed-based turn order

## Layer Structure

```
├── Data Layer (Pure data, no logic)
│   ├── Core Entities
│   ├── Battle Entities
│   ├── Social Entities
│   └── Configuration Objects
├── Service Layer (Stateless utilities)
│   ├── Calculators
│   ├── Factories
│   └── Validators
├── System Layer (Game logic)
│   ├── Core Systems
│   ├── Battle Systems
│   ├── Progression Systems
│   ├── Social Systems
│   └── Monetization Systems
├── Presentation Layer
│   ├── Screen Controllers
│   └── UI Components
└── Infrastructure Layer
    ├── Save/Load
    ├── Network
    └── Analytics
```

## Data Layer (scripts/data/)

### Core Entities
```gdscript
# God.gd - Pure data container
class_name God extends Resource
- Properties: id, name, element, tier, pantheon
- Base Stats: hp, attack, defense, speed
- Combat Stats: crit_rate, crit_damage, accuracy, resistance
- Abilities: ability_ids[] (3 abilities)
- Skill Levels: skill_levels[3] (1-10 for each skill)
- Awakening: is_awakened, awakening_tier
- Equipment: equipped_rune_ids[6]

# Equipment.gd (SW-style rune)




# Territory.gd
class_name Territory extends Resource
- Properties: id, name, tier, element, zone_id
- Owner: owner_player_id (for PvP territories)
- Defense Team: defense_god_ids[] (for PvP)
- Resources: base_production_rates{}
- Fortification: level, defense_bonuses

# PlayerProfile.gd
class_name PlayerProfile extends Resource
- Properties: player_id, name, level, experience
- Collections: god_ids[], rune_ids[]
- PvP: arena_rank, guild_id, defense_teams{}
- Resources: Dictionary<resource_id, amount>
- Progression: completed_quests[], battle_pass_level
```

### Battle Entities
```gdscript
# BattleUnit.gd - Unified interface
class_name BattleUnit extends Resource
- Properties: source_id, name, element
- Combat State: current_hp, max_hp
- Status Effects: effect_instances[]
- Turn State: has_acted_this_turn
- Cooldowns: ability_cooldowns[3]

# BattleConfig.gd
class_name BattleConfig extends Resource
- Battle Type: pve, pvp_arena, pvp_territory, guild_war
- Teams: attacker_gods[], defender_gods[]
- Modifiers: tower_bonuses{}, territory_bonuses{}
- Victory Conditions: standard, survival, time_limit
```

### Social Entities
```gdscript
# Guild.gd
class_name Guild extends Resource
- Properties: guild_id, name, level, emblem
- Members: member_ids[], leader_id, officers[]
- Guild War: territories_owned[], war_points
- Perks: unlocked_perks[], guild_shop_items

# Friend.gd
class_name Friend extends Resource
- Properties: player_id, name, level
- Rep Monster: rep_god_id (can be borrowed)
- Activity: last_online, daily_gifts_sent

# PvPRecord.gd
class_name PvPRecord extends Resource
- Attacker: attacker_id, attacker_team[]
- Defender: defender_id, defender_team[]
- Result: winner, turn_count, timestamp
- Replay Data: action_sequence[]
```

### Progression Entities
```gdscript
# Quest.gd
class_name Quest extends Resource
- Properties: quest_id, type (daily, weekly, achievement)
- Requirements: conditions[], progress_tracking{}
- Rewards: reward_items[], reward_amounts[]
- Chain: next_quest_id

# BattlePassTier.gd
class_name BattlePassTier extends Resource
- Level: tier_number, xp_required
- Free Rewards: free_items[], free_amounts[]
- Premium Rewards: premium_items[], premium_amounts[]

# SkillUpgrade.gd
class_name SkillUpgrade extends Resource
- Skill Index: 0-2
- Level: 1-10
- Effects: damage_increase%, cooldown_reduction, effect_rate_increase%
- Cost: materials_required{}
```

## Service Layer (scripts/services/)

### Core Services
```gdscript
# NetworkService.gd - Server communication
class_name NetworkService extends Node
func request_pvp_match(opponent_id: String) -> PvPMatchData
func submit_battle_result(result: BattleResult) -> void
func sync_player_data() -> PlayerProfile
func get_leaderboard(type: String, range: int) -> Array[LeaderboardEntry]

# MatchmakingService.gd - PvP matchmaking
class_name MatchmakingService extends Node
func find_arena_opponent(player_rank: int) -> PlayerProfile
func find_territory_target(zone_id: String) -> Territory
func find_guild_war_opponent(guild: Guild) -> Guild

# ValidationService.gd - Anti-cheat
class_name ValidationService extends Node
func validate_battle_result(result: BattleResult) -> bool
func validate_resource_gain(resource: String, amount: int) -> bool
func validate_team_composition(gods: Array[God]) -> bool
```

### Calculators
```gdscript
# CombatCalculator.gd
static func calculate_damage(attacker: BattleUnit, target: BattleUnit, skill: Skill) -> DamageResult
static func calculate_rune_stats(god: God) -> Dictionary # SW rune calculations
static func calculate_set_bonuses(rune_sets: Array) -> Dictionary
static func calculate_skill_damage(base: int, skill_level: int) -> int

# TerritoryCalculator.gd
static func calculate_defense_bonus(territory: Territory) -> Dictionary
static func calculate_production(territory: Territory, assigned_gods: Array) -> Dictionary
static func calculate_siege_requirements(territory: Territory) -> Dictionary

# PvPCalculator.gd
static func calculate_rank_change(winner_rank: int, loser_rank: int) -> int
static func calculate_glory_points(rank: int, win: bool) -> int
static func calculate_matchmaking_range(rank: int) -> Vector2
```

### Factories
```gdscript
# RewardFactory.gd
static func generate_quest_rewards(quest: Quest) -> Array[RewardItem]
static func generate_pvp_rewards(rank: int, season_end: bool) -> Array[RewardItem]
static func generate_battle_pass_rewards(tier: int) -> Array[RewardItem]

# QuestFactory.gd
static func generate_daily_quests() -> Array[Quest]
static func generate_event_quests(event_id: String) -> Array[Quest]
```

## System Layer (scripts/systems/)

### Core Systems
```gdscript
# GameCoordinator.gd - Main orchestration
extends Node
var game_state: GameState # menu, world, battle, pvp
var system_registry: SystemRegistry
func initialize_systems() -> void
func transition_to_state(new_state: GameState) -> void

# EventBus.gd - Global events
extends Node
signal resource_changed(resource_id: String, amount: int)
signal god_obtained(god: God)
signal pvp_rank_changed(old_rank: int, new_rank: int)
signal quest_completed(quest_id: String)
signal skill_upgraded(god_id: String, skill_index: int)
signal territory_captured(territory_id: String)
signal guild_event(event_type: String, data: Dictionary)
```

### Battle Systems
```gdscript
# BattleCoordinator.gd - All battle types
extends Node
func start_pve_battle(config: BattleConfig) -> void
func start_pvp_battle(config: BattleConfig) -> void
func start_territory_siege(territory: Territory, attackers: Array) -> void
func process_turn(unit: BattleUnit, action: BattleAction) -> void

# SkillCooldownManager.gd - Skill cooldowns
extends Node
var cooldowns: Dictionary # unit_id -> ability_cooldowns[]
func use_skill(unit: BattleUnit, skill_index: int) -> void
func reduce_cooldowns(unit: BattleUnit) -> void
func reset_cooldowns(unit: BattleUnit) -> void

# PvPBattleValidator.gd - Validate PvP battles
extends Node
func record_action(action: BattleAction) -> void
func generate_replay_data() -> Dictionary
func validate_replay(replay: Dictionary) -> bool
```

### Progression Systems
```gdscript
# SkillUpgradeSystem.gd - Skill leveling
extends Node
func upgrade_skill(god: God, skill_index: int) -> bool
func calculate_upgrade_cost(skill_level: int) -> Dictionary
func apply_skill_effects(god: God, skill_index: int) -> void
signal skill_maxed(god_id: String, skill_index: int)

# QuestSystem.gd - Daily/Weekly/Achievement
extends Node
var active_quests: Array[Quest]
var quest_progress: Dictionary
func check_quest_progress(event: String, data: Dictionary) -> void
func complete_quest(quest_id: String) -> void
func refresh_daily_quests() -> void

# BattlePassSystem.gd - Season pass
extends Node
var current_season: String
var player_tier: int
var player_xp: int
var is_premium: bool
func add_battle_pass_xp(amount: int) -> void
func claim_reward(tier: int, premium: bool) -> void
func purchase_premium_pass() -> void
```

### Territory & PvP Systems
```gdscript
# TerritoryWarSystem.gd - PvP territory control
extends Node
var world_territories: Dictionary # zone -> territories
var siege_schedule: Dictionary
func initiate_siege(territory: Territory, guild: Guild) -> void
func assign_defense_team(territory: Territory, gods: Array) -> void
func calculate_territory_income(player_territories: Array) -> Dictionary
signal territory_under_siege(territory_id: String)
signal siege_completed(territory_id: String, winner: String)

# ArenaSystem.gd - 1v1 PvP
extends Node
var player_rank: int
var defense_team: Array[God]
var offense_history: Array[PvPRecord]
func find_opponents() -> Array[PlayerProfile]
func challenge_player(opponent_id: String) -> void
func update_defense_team(gods: Array[God]) -> void
signal rank_updated(new_rank: int)

# GuildWarSystem.gd - Guild battles
extends Node
var current_war: GuildWar
var attack_tokens: int
func start_guild_war(opponent_guild: Guild) -> void
func attack_tower(tower_id: String, gods: Array) -> void
func get_war_contributions() -> Dictionary
```

### Social Systems
```gdscript
# GuildManager.gd - Guild functionality
extends Node
var current_guild: Guild
func create_guild(name: String) -> Guild
func join_guild(guild_id: String) -> bool
func donate_to_guild(items: Dictionary) -> void
func participate_in_guild_content() -> void

# FriendSystem.gd - Social features
extends Node
var friends_list: Array[Friend]
var pending_requests: Array[String]
func add_friend(player_id: String) -> void
func send_daily_gift(friend_id: String) -> void
func borrow_rep_monster(friend_id: String) -> God

# LeaderboardSystem.gd - Rankings
extends Node
func get_arena_leaderboard() -> Array[LeaderboardEntry]
func get_guild_leaderboard() -> Array[LeaderboardEntry]
func get_territory_leaderboard(zone: String) -> Array[LeaderboardEntry]
func get_player_ranking(type: String) -> int
```

### Monetization Systems
```gdscript
# ShopSystem.gd - In-game shop
extends Node
var shop_rotations: Dictionary
var special_offers: Array[ShopOffer]
func purchase_item(item_id: String, currency: String) -> bool
func refresh_shop_rotation() -> void
func get_limited_offers() -> Array[ShopOffer]

# GachaSystem.gd - Summoning with pity
extends Node
var pity_counters: Dictionary
func perform_summon(banner_id: String) -> God
func calculate_rates_with_pity(base_rates: Dictionary) -> Dictionary
func get_banner_info(banner_id: String) -> BannerInfo
```

## PvP Territory World System

### Territory Zones
```gdscript
# Zone Configuration
Zones:
- Starter Zone (Tier 1): 20 territories, low production
- Mid Zone (Tier 2): 15 territories, medium production  
- Elite Zone (Tier 3): 10 territories, high production
- Legendary Zone (Tier 4): 5 territories, very high production

# Territory Features
Each Territory:
- Production: mana, crystals, crafting materials
- Garrison: 5-10 defensive gods
- Fortification: upgradeable defenses
- Siege Window: specific time periods for attacks
- Guild Ownership: controlled by guilds
```

### Territory Battle Rules
```gdscript
# Siege Mechanics
- Preparation Phase: 24 hours to sign up
- Battle Phase: 1 hour active combat window
- Multiple guilds can compete
- Defenders get tower bonuses
- Winner takes control

# Defense Assignment
- Assign gods to specific defensive positions
- Tower effects based on territory level
- Element bonuses for matching territory element
- Garrison limit based on fortification level
```

## Battle Flow (PvE and PvP)

```
1. Battle Setup
   ├── Team Selection (player picks 4-5 gods)
   ├── Apply rune stats and set bonuses
   ├── Apply leader skills
   └── Apply territory/tower bonuses (PvP)

2. Turn Order
   ├── Sort by speed stat (highest first)
   ├── No ATB - pure turn-based
   └── Speed ties broken by combat RNG

3. Turn Execution
   ├── Check skill cooldowns
   ├── Player/AI selects action
   ├── Apply skill upgrades to damage/effects
   ├── Process combat (damage, effects, healing)
   └── Reduce cooldowns by 1

4. Victory Conditions
   ├── PvE: Defeat all enemies
   ├── Arena: Defeat enemy team
   ├── Territory: Defeat garrison + towers
   └── Guild War: Defeat defensive teams

5. Rewards
   ├── PvE: Loot tables + XP
   ├── PvP: Glory points + rank rewards
   ├── Territory: Control + production
   └── Guild War: Guild points + contribution
```

## Progression Systems

### Skill Upgrade Path
```
Each God has 3 skills:
- Skill 1: Basic attack (upgradeable 10 times)
- Skill 2: Special ability (upgradeable 10 times)
- Skill 3: Ultimate (upgradeable 10 times)

Upgrade Effects:
- Damage: +5-10% per level
- Effect Rate: +5-10% per level
- Cooldown: -1 turn at certain levels
- Special Effects: Unlock at max level

Materials Required:
- Devilmon (universal skill-up)
- Duplicate gods (family skill-up)
- Element-specific skill stones
```

### Quest Categories
```
Daily Quests:
- Complete 5 battles
- Summon 1 god
- Upgrade 3 runes
- Participate in arena

Weekly Quests:
- Win 20 arena battles
- Clear dungeon 50 times
- Contribute to guild
- Complete all dailies 5 times

Achievements:
- Collect 50 unique gods
- Reach arena rank 1000
- Max skill a god
- Own 10 territories
```

### Battle Pass Tiers
```
50 Tiers per season (2 months):
- Free Track: Basic rewards
- Premium Track: Premium currency, exclusive gods, skins
- XP Sources: Daily quests, PvP wins, dungeon clears
- Catch-up Mechanics: XP boosts for late starters
```

## Network Architecture

```gdscript
# Client-Server Communication
Client (Godot) <-> API Gateway <-> Game Server

# Critical Server-Validated Actions
- Battle results (anti-cheat)
- Resource transactions
- Summoning/Gacha
- PvP matchmaking
- Guild operations
- Trading/Gifting

# Client-Authoritative (with validation)
- Movement in menus
- Team composition
- Visual settings
- Local battle preview
```

## Save System

```gdscript
# Local Save Structure
save_data/
├── player_profile.dat (encrypted)
├── collection.dat (gods, runes)
├── progress.dat (quests, battle pass)
├── settings.dat (preferences)
└── cache.dat (downloaded assets)

# Cloud Save
- Automatic sync every 5 minutes
- On significant events (summon, upgrade)
- Before/after PvP battles
- Conflict resolution: Server authoritative
```

## JSON Configuration Files

```
data/
├── combat/
│   ├── skill_data.json (all abilities)
│   ├── skill_upgrades.json (upgrade paths)
│   ├── status_effects.json
│   └── combat_formulas.json
├── progression/
│   ├── quests.json (all quest types)
│   ├── battle_pass.json (season data)
│   ├── achievements.json
│   └── experience_tables.json
├── pvp/
│   ├── arena_rewards.json
│   ├── territory_config.json
│   ├── guild_war_rules.json
│   └── matchmaking_rules.json
├── economy/
│   ├── shop_items.json
│   ├── summon_rates.json
│   ├── resource_costs.json
│   └── special_offers.json
└── social/
    ├── guild_perks.json
    ├── friend_gifts.json
    └── chat_filters.json
```

## Implementation Priority

### Phase 1: Core Systems (Weeks 1-2)
- Data layer refactoring
- Service layer utilities
- Battle system without PvP
- Basic progression

### Phase 2: PvP Foundation (Weeks 3-4)
- Arena system
- Defense teams
- Matchmaking
- Basic leaderboards

### Phase 3: Territory System (Weeks 5-6)
- Territory map
- Siege mechanics
- Defense assignment
- Resource production

### Phase 4: Social Features (Weeks 7-8)
- Guild system
- Friend system
- Guild wars
- Chat (if needed)

### Phase 5: Monetization (Weeks 9-10)
- Battle pass
- Shop system
- Special offers
- Premium features

### Phase 6: Polish (Weeks 11-12)
- Quest system completion
- Achievement system
- Seasonal events
- Balance tuning

## Key Differences from Current Implementation

1. **No ATB System** - Pure turn-based on speed
2. **Skill Upgrades** - 30 levels per god (3 skills × 10 levels)
3. **PvP Focus** - Arena, Territory Wars, Guild Wars
4. **Social Layer** - Guilds, friends, leaderboards
5. **Monetization** - Battle pass, shop, special offers
6. **Server Validation** - Anti-cheat for PvP
7. **Territory World** - Persistent PvP map
8. **Rune System** - Full SW-style rune mechanics

This architecture provides a complete, scalable foundation for a competitive Summoners War clone with all modern mobile game features.
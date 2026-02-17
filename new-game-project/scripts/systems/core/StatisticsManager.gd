# scripts/systems/core/StatisticsManager.gd
# Tracks game-wide statistics (battles, summons, dungeons, territory)
# Read by AchievementManager for achievement progress checking
extends Node
class_name StatisticsManager

# Battle Statistics
var battle_stats: Dictionary = {
	"battles_won": 0,
	"battles_lost": 0,
	"total_battles": 0,
	"total_damage_dealt": 0,
	"total_damage_taken": 0,
	"total_healing_done": 0,
	"perfect_victories": 0,
	"dungeon_clears": {},
	"territory_conquests": 0,
	"longest_win_streak": 0,
	"current_win_streak": 0
}

# Resource Statistics
var resource_stats: Dictionary = {
	"total_mana_earned": 0,
	"total_essence_earned": 0,
	"total_crystals_spent": 0,
	"total_summons_performed": 0,
	"legendary_summons": 0,
	"epic_summons": 0,
	"gods_sacrificed": 0,
	"equipment_crafted": 0
}

func _ready() -> void:
	_connect_events.call_deferred()

func _connect_events() -> void:
	var event_bus: Node = SystemRegistry.get_instance().get_system("EventBus")
	if not event_bus:
		return
	if event_bus.has_signal("battle_ended"):
		event_bus.battle_ended.connect(_on_battle_ended)
	if event_bus.has_signal("dungeon_completed"):
		event_bus.dungeon_completed.connect(_on_dungeon_completed)
	if event_bus.has_signal("territory_captured"):
		event_bus.territory_captured.connect(_on_territory_captured)
	if event_bus.has_signal("summon_performed"):
		event_bus.summon_performed.connect(_on_summon_performed)
	if event_bus.has_signal("god_sacrifice_completed"):
		event_bus.god_sacrifice_completed.connect(_on_sacrifice_completed)
	if event_bus.has_signal("equipment_crafted"):
		event_bus.equipment_crafted.connect(_on_equipment_crafted)

# ==============================================================================
# EVENT HANDLERS
# ==============================================================================

func _on_battle_ended(result) -> void:
	if not result:
		return
	battle_stats["total_battles"] += 1
	if result.victory:
		battle_stats["battles_won"] += 1
		battle_stats["current_win_streak"] += 1
		battle_stats["longest_win_streak"] = maxi(battle_stats["longest_win_streak"], battle_stats["current_win_streak"])
	else:
		battle_stats["battles_lost"] += 1
		battle_stats["current_win_streak"] = 0

func _on_dungeon_completed(dungeon_id: String, _rewards: Array) -> void:
	if not battle_stats["dungeon_clears"].has(dungeon_id):
		battle_stats["dungeon_clears"][dungeon_id] = 0
	battle_stats["dungeon_clears"][dungeon_id] += 1

func _on_territory_captured(_territory_id) -> void:
	battle_stats["territory_conquests"] += 1

func _on_summon_performed(_banner_id: String, results: Array) -> void:
	resource_stats["total_summons_performed"] += results.size()

func _on_sacrifice_completed(sacrifice_data: Dictionary) -> void:
	var material_count: int = sacrifice_data.get("material_count", 0)
	resource_stats["gods_sacrificed"] += material_count

func _on_equipment_crafted(_equipment: Variant, _recipe_id: String) -> void:
	resource_stats["equipment_crafted"] += 1

# ==============================================================================
# PUBLIC RECORD API (for systems that don't go through EventBus)
# ==============================================================================

func record_dungeon_clear(dungeon_id: String) -> void:
	if not battle_stats["dungeon_clears"].has(dungeon_id):
		battle_stats["dungeon_clears"][dungeon_id] = 0
	battle_stats["dungeon_clears"][dungeon_id] += 1

func record_territory_conquest() -> void:
	battle_stats["territory_conquests"] += 1

func get_total_dungeon_clears() -> int:
	var total: int = 0
	for dungeon_id: String in battle_stats["dungeon_clears"]:
		total += battle_stats["dungeon_clears"][dungeon_id]
	return total

# ==============================================================================
# SAVE/LOAD
# ==============================================================================

func get_save_data() -> Dictionary:
	return {
		"battle_stats": battle_stats.duplicate(true),
		"resource_stats": resource_stats.duplicate(true),
	}

func load_save_data(data: Dictionary) -> void:
	# Merge saved data with defaults to ensure all keys exist (for old saves)
	if data.has("battle_stats") and data["battle_stats"] is Dictionary:
		var saved_battle: Dictionary = data["battle_stats"]
		for key: String in saved_battle:
			battle_stats[key] = saved_battle[key]
	if data.has("resource_stats") and data["resource_stats"] is Dictionary:
		var saved_resource: Dictionary = data["resource_stats"]
		for key: String in saved_resource:
			resource_stats[key] = saved_resource[key]

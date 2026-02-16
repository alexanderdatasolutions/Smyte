# scripts/systems/progression/GodProgressionManager.gd
extends Node
class_name GodProgressionManager

# ==============================================================================
# GOD PROGRESSION MANAGER - Individual god leveling and experience (150 lines max)
# ==============================================================================
# Single responsibility: Handle individual god XP, leveling, and stat progression
# Uses SystemRegistry pattern for clean architecture

signal god_leveled_up(god: God, new_level: int, old_level: int)
signal god_experience_gained(god: God, amount: int)
signal god_awakened(god: God)

# God Level Configuration (loaded from data/progression_config.json)
var MAX_GOD_LEVEL: int = 40
var AWAKENED_MAX_LEVEL: int = 50
var XP_BASE_AMOUNT: int = 200
var XP_SCALING_FACTOR: float = 1.2

# Level up stat bonuses per tier (loaded from config)
var stat_bonuses_per_level: Dictionary = {
	1: {"attack": 10, "defense": 8, "hp": 25, "speed": 2},
	2: {"attack": 12, "defense": 10, "hp": 30, "speed": 2},
	3: {"attack": 15, "defense": 12, "hp": 40, "speed": 3},
	4: {"attack": 20, "defense": 15, "hp": 50, "speed": 3},
	5: {"attack": 25, "defense": 18, "hp": 65, "speed": 4}
}

var event_bus: EventBus
var collection_manager: CollectionManager

func _ready():
	name = "GodProgressionManager"
	_load_config()
	_initialize_dependencies()

func _load_config():
	"""Load progression values from data/progression_config.json"""
	var file := FileAccess.open("res://data/progression_config.json", FileAccess.READ)
	if not file:
		return
	var config: Dictionary = JSON.parse_string(file.get_as_text())
	if not config:
		return

	var leveling: Dictionary = config.get("god_leveling", {})
	MAX_GOD_LEVEL = leveling.get("max_god_level", MAX_GOD_LEVEL)
	AWAKENED_MAX_LEVEL = leveling.get("awakened_max_level", AWAKENED_MAX_LEVEL)
	XP_BASE_AMOUNT = leveling.get("xp_base_amount", XP_BASE_AMOUNT)
	XP_SCALING_FACTOR = leveling.get("xp_scaling_factor", XP_SCALING_FACTOR)

	var bonuses: Dictionary = config.get("stat_bonuses_per_level", {})
	if not bonuses.is_empty():
		stat_bonuses_per_level.clear()
		for tier_key in bonuses:
			stat_bonuses_per_level[int(tier_key)] = bonuses[tier_key]

func _initialize_dependencies():
	"""Initialize system dependencies through SystemRegistry"""
	var system_registry = SystemRegistry.get_instance()
	event_bus = system_registry.get_system("EventBus")
	collection_manager = system_registry.get_system("CollectionManager")

# ==============================================================================
# EXPERIENCE MANAGEMENT - Core god progression
# ==============================================================================

func add_experience_to_god(god: God, experience_amount: int):
	"""Add experience to a god and handle level ups"""
	if not god:
		return

	if experience_amount <= 0:
		return
	
	var old_level = god.level
	god.experience += experience_amount
	
	# Check for level ups
	var new_level = calculate_level_from_experience(god.experience, god.is_awakened)
	if new_level > old_level:
		_level_up_god(god, old_level, new_level)
	
	# Emit experience gained event
	god_experience_gained.emit(god, experience_amount)
	
	# Update god in collection
	if collection_manager:
		collection_manager.update_god(god)
	
	# Trigger save through EventBus when god gains experience
	if event_bus:
		event_bus.save_requested.emit()

func calculate_level_from_experience(total_xp: int, is_awakened: bool = false) -> int:
	"""Calculate level from total experience"""
	var level = 1
	var xp_needed = 0
	var max_level = AWAKENED_MAX_LEVEL if is_awakened else MAX_GOD_LEVEL
	
	while level < max_level:
		var xp_for_next_level = calculate_xp_for_level(level + 1)
		if total_xp < xp_needed + xp_for_next_level:
			break
		xp_needed += xp_for_next_level
		level += 1
	
	return level

func calculate_xp_for_level(target_level: int) -> int:
	"""Calculate XP required to reach target level from previous level"""
	if target_level <= 1:
		return 0
	return int(XP_BASE_AMOUNT * pow(XP_SCALING_FACTOR, target_level - 2))

func calculate_total_xp_for_level(target_level: int, _is_awakened: bool = false) -> int:
	"""Calculate total XP needed to reach a specific level"""
	var total_xp = 0
	for level in range(2, target_level + 1):
		total_xp += calculate_xp_for_level(level)
	return total_xp

func get_xp_to_next_level(god: God) -> int:
	"""Get XP needed for god to reach next level"""
	if not god:
		return 0
	
	var max_level = AWAKENED_MAX_LEVEL if god.is_awakened else MAX_GOD_LEVEL
	if god.level >= max_level:
		return 0
	
	var next_level_total_xp = calculate_total_xp_for_level(god.level + 1, god.is_awakened)
	
	return next_level_total_xp - god.experience

# ==============================================================================
# LEVEL UP SYSTEM - Stat progression and bonuses
# ==============================================================================

func _level_up_god(god: God, old_level: int, new_level: int):
	"""Handle god leveling up with stat bonuses"""
	god.level = new_level
	
	# Apply stat bonuses for each level gained
	var levels_gained = new_level - old_level
	var tier_bonuses = stat_bonuses_per_level.get(god.tier, stat_bonuses_per_level[1])
	
	# Apply stat increases
	god.base_attack += tier_bonuses.attack * levels_gained
	god.base_defense += tier_bonuses.defense * levels_gained  
	god.base_hp += tier_bonuses.hp * levels_gained
	god.base_speed += tier_bonuses.speed * levels_gained
	
	# Heal to full HP on level up
	god.current_hp = god.base_hp
	
	# Emit level up event
	god_leveled_up.emit(god, new_level, old_level)

	# Emit event bus signal for UI updates
	if event_bus:
		event_bus.god_level_up.emit(god.id, new_level, old_level)

	# Show level up notification
	_show_level_up_notification(god, new_level, levels_gained)

func can_level_up(god: God) -> bool:
	"""Check if god can level up with current experience"""
	if not god:
		return false
	
	var max_level = AWAKENED_MAX_LEVEL if god.is_awakened else MAX_GOD_LEVEL
	if god.level >= max_level:
		return false
	
	var xp_needed = get_xp_to_next_level(god)
	return xp_needed <= 0

func _show_level_up_notification(god: God, new_level: int, levels_gained: int) -> void:
	"""Show level up notification using NotificationQueue"""
	var NotificationQueueClass = load("res://scripts/ui/components/NotificationQueue.gd")
	if NotificationQueueClass:
		NotificationQueueClass.show_level_up(god.name, new_level, levels_gained)

# ==============================================================================
# AWAKENING SUPPORT - Extended level progression
# ==============================================================================

func handle_god_awakening(god: God):
	"""Handle when a god is awakened - extends level cap"""
	if not god:
		return
	
	god.is_awakened = true
	
	# Emit awakening event
	god_awakened.emit(god)
	
	# Update god in collection
	if collection_manager:
		collection_manager.update_god(god)
	
	if event_bus:
		event_bus.god_awakened.emit(god.id)


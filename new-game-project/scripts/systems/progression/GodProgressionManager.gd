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

# God Level Configuration
const MAX_GOD_LEVEL = 40
const AWAKENED_MAX_LEVEL = 50
const XP_BASE_AMOUNT = 200
const XP_SCALING_FACTOR = 1.2

# Level up stat bonuses per tier
var stat_bonuses_per_level: Dictionary = {
	1: {"attack": 10, "defense": 8, "hp": 25, "speed": 2},    # Common
	2: {"attack": 12, "defense": 10, "hp": 30, "speed": 2},   # Rare
	3: {"attack": 15, "defense": 12, "hp": 40, "speed": 3},   # Epic  
	4: {"attack": 20, "defense": 15, "hp": 50, "speed": 3},   # Legendary
	5: {"attack": 25, "defense": 18, "hp": 65, "speed": 4}    # Mythic
}

var event_bus: EventBus
var collection_manager: CollectionManager

func _ready():
	name = "GodProgressionManager"
	_initialize_dependencies()

func _initialize_dependencies():
	"""Initialize system dependencies through SystemRegistry"""
	var system_registry = SystemRegistry.get_instance()
	event_bus = system_registry.get_system("EventBus")
	collection_manager = system_registry.get_system("CollectionManager")
	
	# Connect to events if needed
	if event_bus:
		event_bus.god_sacrificed.connect(_on_god_sacrificed)

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

func can_level_up(god: God) -> bool:
	"""Check if god can level up with current experience"""
	if not god:
		return false
	
	var max_level = AWAKENED_MAX_LEVEL if god.is_awakened else MAX_GOD_LEVEL
	if god.level >= max_level:
		return false
	
	var xp_needed = get_xp_to_next_level(god)
	return xp_needed <= 0

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

# ==============================================================================
# EVENT HANDLERS - System integration
# ==============================================================================

func _on_god_sacrificed(_god_id: String, _xp_gained: int):
	"""Handle god sacrifice XP events from other systems"""
	# This is handled by the system performing the sacrifice
	# We just track the event for analytics/logging
	pass

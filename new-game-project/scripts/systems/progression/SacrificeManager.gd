# scripts/systems/progression/SacrificeManager.gd
# Sacrifice management system - coordinates sacrifice operations and UI events
extends Node
class_name SacrificeManager

signal sacrifice_completed(target_god: God, material_gods: Array, xp_gained: int)
signal sacrifice_failed(reason: String)
signal awakening_completed(god: God)
signal awakening_failed(god: God, reason: String)

var sacrifice_system: SacrificeSystem
var awakening_system: AwakeningSystem
var event_bus: EventBus
var resource_manager: ResourceManager
var collection_manager: CollectionManager

# Temporary data for screen transitions
var temporary_target_god: God = null

func _ready():
	name = "SacrificeManager"
	
	# Get system references through SystemRegistry
	var system_registry = SystemRegistry.get_instance()
	sacrifice_system = system_registry.get_system("SacrificeSystem")
	awakening_system = system_registry.get_system("AwakeningSystem")
	event_bus = system_registry.get_system("EventBus")
	resource_manager = system_registry.get_system("ResourceManager")
	collection_manager = system_registry.get_system("CollectionManager")
	
	_connect_events()

func _connect_events():
	"""Connect to system events"""
	if event_bus:
		event_bus.god_sacrificed.connect(_on_god_sacrificed)
		event_bus.god_awakened.connect(_on_god_awakened)

func perform_sacrifice(target_god: God, material_gods: Array[God]) -> Dictionary:
	"""Perform sacrifice operation with full validation and events"""
	if not sacrifice_system:
		var error = "SacrificeSystem not available"
		sacrifice_failed.emit(error)
		return {"success": false, "error": error}
	
	# Validate sacrifice
	if not target_god or material_gods.is_empty():
		var error = "Invalid sacrifice parameters"
		sacrifice_failed.emit(error)
		return {"success": false, "error": error}
	
	# Calculate XP gain for preview
	var sacrifice_result = sacrifice_system.calculate_sacrifice_experience(material_gods, target_god)
	
	# Perform the actual sacrifice
	var success = sacrifice_system.perform_sacrifice(target_god, material_gods, collection_manager)
	
	if success:
		sacrifice_completed.emit(target_god, material_gods, sacrifice_result.total_xp)
		
		# Emit events for UI updates
		if event_bus:
			event_bus.god_sacrificed.emit(target_god.id, sacrifice_result.total_xp)
			event_bus.collection_updated.emit()
		
		return {
			"success": true,
			"xp_gained": sacrifice_result.total_xp,
			"levels_gained": sacrifice_system.calculate_levels_gained(target_god, sacrifice_result.total_xp)
		}
	else:
		var error = "Sacrifice operation failed"
		sacrifice_failed.emit(error)
		return {"success": false, "error": error}

func calculate_sacrifice_preview(target_god: God, material_gods: Array[God]) -> Dictionary:
	"""Calculate sacrifice preview without performing it"""
	if not sacrifice_system or not target_god or material_gods.is_empty():
		return {"total_xp": 0, "levels_gained": 0, "bonus_details": [], "god_values": []}
	
	var sacrifice_result = sacrifice_system.calculate_sacrifice_experience(material_gods, target_god)
	sacrifice_result.levels_gained = sacrifice_system.calculate_levels_gained(target_god, sacrifice_result.total_xp)
	
	return sacrifice_result

func attempt_awakening(god: God) -> Dictionary:
	"""Attempt to awaken a god with validation"""
	if not awakening_system:
		var error = "AwakeningSystem not available"
		awakening_failed.emit(god, error)
		return {"success": false, "error": error}
	
	# Check if awakening is possible
	var awakening_check = awakening_system.can_awaken_god(god)
	if not awakening_check.can_awaken:
		var error = "Cannot awaken god: " + str(awakening_check.missing_requirements)
		awakening_failed.emit(god, error)
		return {"success": false, "error": error}
	
	# Attempt awakening
	var success = awakening_system.attempt_awakening(god)
	
	if success:
		awakening_completed.emit(god)
		
		# Emit events for UI updates
		if event_bus:
			event_bus.god_awakened.emit(god.id)
			event_bus.collection_updated.emit()
		
		return {"success": true}
	else:
		var error = "Awakening operation failed"
		awakening_failed.emit(god, error)
		return {"success": false, "error": error}

func get_awakening_requirements(god: God) -> Dictionary:
	"""Get awakening requirements for a god"""
	if not awakening_system:
		return {"can_awaken": false, "missing_requirements": ["AwakeningSystem not available"]}
	
	return awakening_system.can_awaken_god(god)

func get_awakening_materials_cost(god: God) -> Dictionary:
	"""Get materials cost for awakening a god"""
	if not awakening_system:
		return {}
	
	return awakening_system.get_awakening_materials_cost(god)

func check_awakening_materials(materials: Dictionary) -> Dictionary:
	"""Check if player has required awakening materials"""
	if not awakening_system:
		return {"has_materials": false, "missing": []}
	
	return awakening_system.check_awakening_materials(materials)

func get_available_sacrifice_gods() -> Array[God]:
	"""Get gods available for sacrifice (owned by player)"""
	if not collection_manager:
		return []
	
	var owned_gods = collection_manager.get_owned_gods()
	var available_gods: Array[God] = []
	
	# Filter out gods that shouldn't be sacrificed (equipped, in territories, etc.)
	for god_data in owned_gods:
		var god = god_data.god
		if _can_sacrifice_god(god):
			available_gods.append(god)
	
	return available_gods

func get_available_awakening_gods() -> Array[God]:
	"""Get gods available for awakening (Epic/Legendary, level 40)"""
	if not collection_manager:
		return []
	
	var owned_gods = collection_manager.get_owned_gods()
	var awakening_gods: Array[God] = []
	
	for god_data in owned_gods:
		var god = god_data.god
		if _can_awaken_god_ui(god):
			awakening_gods.append(god)
	
	return awakening_gods

func _can_sacrifice_god(god: God) -> bool:
	"""Check if a god can be used for sacrifice"""
	if not god:
		return false
	
	# Don't allow sacrificing equipped gods or gods assigned to territories
	if god.is_equipped() or god.is_assigned_to_territory():
		return false
	
	# Don't sacrifice awakened gods (optional rule)
	if god.is_awakened:
		return false
	
	return true

func _can_awaken_god_ui(god: God) -> bool:
	"""Check if a god should appear in awakening UI"""
	if not god:
		return false
	
	# Only Epic and Legendary gods can be awakened
	if god.tier < 4:  # Assuming tier 4+ is Epic/Legendary
		return false
	
	# Must be max level (40) to awaken
	if god.level < 40:
		return false
	
	# Don't show already awakened gods
	if god.is_awakened:
		return false
	
	return true

func get_god_sacrifice_value(god: God) -> int:
	"""Calculate the XP value this god provides when used as sacrifice material
	Following Summoners War formula: Base value + level scaling + tier bonus"""
	if not god:
		return 0
		
	var base_value = 100  # Base XP value
	var level_bonus = god.level * 50  # 50 XP per level
	var tier_bonus = int(god.tier) * 300  # Tier multiplier (300 per tier)
	
	# Awakened gods provide bonus XP
	var awakening_bonus = 500 if god.is_awakened else 0
	
	return base_value + level_bonus + tier_bonus + awakening_bonus

func _on_god_sacrificed(_god_id: String, _xp_gained: int):
	"""Handle god sacrifice events from other systems"""
	# Could add additional logic here if needed
	pass

func _on_god_awakened(_god_id: String):
	"""Handle god awakening events from other systems"""
	# Could add additional logic here if needed
	pass

# === SCREEN TRANSITION HELPERS ===

func set_temporary_target_god(god: God):
	"""Store target god temporarily for screen transitions"""
	temporary_target_god = god

func get_temporary_target_god() -> God:
	"""Get and clear the temporary target god"""
	var god = temporary_target_god
	temporary_target_god = null  # Clear after retrieval
	return god

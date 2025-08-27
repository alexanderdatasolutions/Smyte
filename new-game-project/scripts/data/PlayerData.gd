# scripts/data/PlayerData.gd
extends Resource
class_name PlayerData

@export var player_name: String = "Player"

# PLAYER PROGRESSION SYSTEM (MYTHOS ARCHITECTURE)
@export var player_experience: int = 0  # Simple XP tracking for player level
@export var is_first_time_player: bool = true  # Track if this is first time playing

# Modular resource system - uses ResourceManager for all operations
@export var resources: Dictionary = {}

# Collections
@export var gods: Array = []
@export var controlled_territories: Array = []

# Progression tracking
@export var total_summons: int = 0

# Save/Load timestamp for resource generation
@export var last_save_time: float = 0

# Resource system integration
var resource_manager

func _init():
	# Initialize with default resources - will be loaded from ResourceManager
	initialize_default_resources()

func initialize_default_resources():
	"""Initialize default resources using ResourceManager definitions"""
	# Get ResourceManager instance
	resource_manager = get_resource_manager()
	if not resource_manager:
		print("Warning: ResourceManager not available during PlayerData init - using fallback")
		create_fallback_resources()
		return
	
	# Initialize all currency resources
	var currencies = resource_manager.get_resources_by_category("currency")
	for currency_id in currencies:
		if not resources.has(currency_id):
			resources[currency_id] = get_default_amount_for_resource(currency_id)
	
	# Initialize all premium currencies  
	var premium_currencies = resource_manager.get_resources_by_category("premium_currency")
	for currency_id in premium_currencies:
		if not resources.has(currency_id):
			resources[currency_id] = get_default_amount_for_resource(currency_id)
	
	# Initialize all summoning materials
	var summoning_materials = resource_manager.get_resources_by_category("summoning_material")
	for material_id in summoning_materials:
		if not resources.has(material_id):
			resources[material_id] = get_default_amount_for_resource(material_id)
	
	# Initialize all awakening materials
	var awakening_materials = resource_manager.get_resources_by_category("awakening_material")
	for material_id in awakening_materials:
		if not resources.has(material_id):
			resources[material_id] = get_default_amount_for_resource(material_id)
	
	# Ensure energy is properly initialized
	if not resources.has("energy"):
		resources["energy"] = get_default_amount_for_resource("energy")
	
	print("PlayerData: Initialized ", resources.size(), " resources - Energy: ", resources.get("energy", "NOT_SET"))

func create_fallback_resources():
	"""Create fallback resources if ResourceManager isn't available"""
	resources = {
		"mana": 1000,
		"divine_crystals": 500,
		"energy": 80,
		"common_soul": 10,
		"rare_soul": 5,
		"epic_soul": 2,
		"legendary_soul": 0,
		"fire_soul": 3,
		"water_soul": 3,
		"earth_soul": 3,
		"lightning_soul": 3,
		"light_soul": 1,
		"dark_soul": 1
	}

func get_default_amount_for_resource(resource_id: String) -> int:
	"""Get default starting amount for a resource"""
	match resource_id:
		"mana":
			return 1000
		"divine_crystals":
			return 500
		"energy":
			return 80
		"common_soul":
			return 10
		"rare_soul":
			return 5
		"epic_soul":
			return 2
		"legendary_soul":
			return 0
		"fire_soul", "water_soul", "earth_soul", "lightning_soul":
			return 3
		"light_soul", "dark_soul":
			return 1
		_:
			# Check resource type for default amounts
			var rm = get_resource_manager_safe()
			if rm:
				var resource_info = rm.get_resource_info(resource_id)
				if resource_info and resource_info.has("category"):
					match resource_info.category:
						"awakening_material":
							return 50 if resource_id.ends_with("_low") else (25 if resource_id.ends_with("_mid") else 5)
						"crafting_material":
							return 20
						"consumable":
							return 5
						_:
							return 0
			return 0

func get_resource_manager():
	"""Get ResourceManager instance from GameManager"""
	if GameManager and GameManager.has_method("get_resource_manager"):
		return GameManager.get_resource_manager()
	# Fallback: try to find ResourceManager in scene tree
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.current_scene:
		return tree.current_scene.get_node_or_null("/root/ResourceManager")
	return null

func get_resource_manager_safe():
	"""Safe getter that doesn't print warnings"""
	if GameManager and GameManager.has_method("get_resource_manager"):
		return GameManager.get_resource_manager()
	return null

# ==============================================================================
# MODULAR RESOURCE METHODS - Works with ResourceManager
# ==============================================================================

func get_resource(resource_id: String) -> int:
	"""Get amount of specific resource"""
	return resources.get(resource_id, 0)

func has_resource(resource_id: String, amount: int) -> bool:
	"""Check if player has enough of a resource"""
	return get_resource(resource_id) >= amount

func spend_resource(resource_id: String, amount: int) -> bool:
	"""Spend resource if available"""
	if not has_resource(resource_id, amount):
		return false
	
	resources[resource_id] = resources.get(resource_id, 0) - amount
	return true

func add_resource(resource_id: String, amount: int):
	"""Add resource to player's inventory"""
	var current_amount = resources.get(resource_id, 0)
	var max_storage = get_max_storage(resource_id)
	
	# Apply max storage limit if it exists
	if max_storage > 0:
		resources[resource_id] = min(current_amount + amount, max_storage)
	else:
		resources[resource_id] = current_amount + amount
	
	# Emit resource update signal if GameManager is available
	if GameManager and GameManager.has_signal("resources_updated"):
		GameManager.resources_updated.emit()

func get_max_storage(resource_id: String) -> int:
	"""Get maximum storage for a resource"""
	var rm = get_resource_manager_safe()
	if rm:
		var resource_info = rm.get_resource_info(resource_id)
		var max_storage = resource_info.get("max_storage", 0)
		if max_storage > 0:
			return max_storage
	
	# Fallback for known resources without ResourceManager or missing max_storage
	match resource_id:
		"energy":
			return 150  # Match resources.json max_storage value
		"mana":
			return 999999  # Effectively unlimited
		"divine_crystals":
			return 999999  # Effectively unlimited
		_:
			return 0  # No limit

func can_afford_cost(cost: Dictionary) -> bool:
	"""Check if player can afford a cost dictionary"""
	for resource_id in cost:
		var required_amount = cost[resource_id]
		if not has_resource(resource_id, required_amount):
			return false
	return true

func spend_cost(cost: Dictionary) -> bool:
	"""Spend multiple resources at once"""
	# First check if we can afford everything
	if not can_afford_cost(cost):
		return false
	
	# Spend all resources
	for resource_id in cost:
		var amount = cost[resource_id]
		spend_resource(resource_id, amount)
	
	return true

# ==============================================================================
# LEGACY COMPATIBILITY METHODS
# ==============================================================================

# These methods provide compatibility with existing code that expects specific properties

var divine_essence: int:
	get:
		return get_resource("mana")  # Map to mana
	set(value):
		resources["mana"] = value

var premium_crystals: int:
	get:
		return get_resource("divine_crystals")
	set(value):
		resources["divine_crystals"] = value

var energy: int:
	get:
		return get_resource("energy")
	set(value):
		resources["energy"] = value

var max_energy: int:
	get:
		return get_max_storage("energy")

var last_energy_update: float = 0.0

var crystals: Dictionary:
	get:
		var crystal_dict = {}
		var elements = ["fire", "water", "earth", "lightning", "light", "dark"]
		for element in elements:
			crystal_dict[element] = get_resource(element + "_crystal")
		return crystal_dict

var awakening_stones: int:
	get:
		return get_resource("awakening_stone")
	set(value):
				resources["awakening_stone"] = value



# ==============================================================================
# GOD COLLECTION METHODS
# ==============================================================================

func add_god(god):
	if god:
		gods.append(god)

func remove_god(god):
	if gods.has(god):
		gods.erase(god)

func get_god_by_id(god_id: String):
	for god in gods:
		if god.id == god_id:
			return god
	return null

func get_total_power() -> int:
	var total = 0
	for god in gods:
		total += god.get_power_rating()
	return total

func get_gods_by_element(element: int) -> Array:
	var result: Array = []
	for god in gods:
		if god.element == element:
			result.append(god)
	return result

func get_gods_by_tier(tier: int) -> Array:
	var result: Array = []
	for god in gods:
		if god.tier == tier:
			result.append(god)
	return result

# Helper function to check for specific gods for ascension
func get_god_count(god_id: String) -> int:
	var count = 0
	for god in gods:
		if god.id == god_id:
			count += 1
	return count

func has_god(god_id: String) -> bool:
	return get_god_by_id(god_id) != null

# ==============================================================================
# ENERGY MANAGEMENT FUNCTIONS  
# ==============================================================================

func update_energy():
	"""Update energy based on time passed - call regularly"""
	var current_time = Time.get_unix_time_from_system()
	
	# Initialize last_energy_update if it's 0 (first run)
	if last_energy_update <= 0:
		last_energy_update = current_time
		return
	
	var time_passed = current_time - last_energy_update
	var minutes_passed = time_passed / 60.0
	
	# Regenerate energy (1 energy per 5 minutes = 0.2 energy per minute)
	var energy_to_add = int(minutes_passed * 0.2)
	
	if energy_to_add > 0:
		var current_energy = get_resource("energy")
		var max_energy_val = get_max_storage("energy")
		var new_energy = min(current_energy + energy_to_add, max_energy_val)
		resources["energy"] = new_energy
		last_energy_update = current_time
		print("Energy regenerated: +", energy_to_add, " (", new_energy, "/", max_energy_val, ")")

func can_afford_energy(cost: int) -> bool:
	"""Check if player has enough energy"""
	update_energy()  # Make sure energy is current
	return has_resource("energy", cost)

func spend_energy(cost: int) -> bool:
	"""Spend energy if available"""
	update_energy()  # Make sure energy is current
	
	if has_resource("energy", cost):
		var current_energy = get_resource("energy")
		var max_energy_val = get_max_storage("energy")
		resources["energy"] = current_energy - cost
		print("Energy spent: -", cost, " (", get_resource("energy"), "/", max_energy_val, ")")
		return true
	else:
		print("Not enough energy! Need: ", cost, ", Have: ", get_resource("energy"))
		return false

func add_energy(amount: int):
	"""Add energy (from items, crystal refreshes, etc.)"""
	add_resource("energy", amount)
	print("Energy added: +", amount, " (", get_resource("energy"), "/", get_max_storage("energy"), ")")

func refresh_energy_with_crystals() -> bool:
	"""Refresh energy using premium crystals (30 crystals = 90 energy)"""
	var crystal_cost = 30
	var energy_gained = 90
	
	if spend_resource("premium_crystals", crystal_cost):
		add_resource("energy", energy_gained)
		print("Energy refreshed with crystals: +", energy_gained, " energy for ", crystal_cost, " crystals")
		return true
	else:
		print("Not enough crystals for energy refresh! Need: ", crystal_cost, ", Have: ", get_resource("premium_crystals"))
		return false

func get_energy_status() -> Dictionary:
	"""Get current energy status"""
	update_energy()
	var current_energy = get_resource("energy")
	var max_energy_val = get_max_storage("energy")
	return {
		"current": current_energy,
		"max": max_energy_val,
		"percentage": float(current_energy) / float(max_energy_val) * 100.0,
		"minutes_to_full": (max_energy_val - current_energy) * 5,  # 5 minutes per energy
		"can_refresh": get_resource("premium_crystals") >= 30
	}

# ==============================================================================
# TERRITORY MANAGEMENT FUNCTIONS  
# ==============================================================================

func control_territory(territory_id: String):
	if not controlled_territories.has(territory_id):
		controlled_territories.append(territory_id)

func lose_territory_control(territory_id: String):
	if controlled_territories.has(territory_id):
		controlled_territories.erase(territory_id)

func update_last_save_time():
	last_save_time = Time.get_unix_time_from_system()

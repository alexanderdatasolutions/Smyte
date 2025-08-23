# scripts/data/PlayerData.gd
extends Resource
class_name PlayerData

@export var player_name: String = "Player"
@export var level: int = 1
@export var experience: int = 0

# Resources
@export var divine_essence: int = 1000  # Primary currency
@export var crystals: Dictionary = {}   # Element-specific materials  
@export var premium_crystals: int = 500   # Premium currency
@export var awakening_stones: int = 10   # Tier upgrade materials
@export var summon_tickets: int = 0     # Free summon tickets
@export var ascension_materials: int = 0 # From duplicates

# Energy system (Summoners War style)
@export var energy: int = 80            # Current energy
@export var max_energy: int = 80        # Maximum energy capacity
@export var last_energy_update: float = 0.0  # Last energy regeneration time

# Awakening materials (Summoners War style) - using essences terminology
@export var powders: Dictionary = {}    # Elemental powders (low/mid/high) - legacy support
@export var essences: Dictionary = {}   # Elemental essences (low/mid/high) - SW authentic
@export var relics: Dictionary = {}     # Pantheon-specific relics

# Collections
@export var gods: Array = []
@export var controlled_territories: Array = []

# Progression tracking
@export var total_summons: int = 0

# Save/Load timestamp for resource generation
@export var last_save_time: float = 0

func _init():
	# Initialize crystals for all elements
	crystals["fire"] = 0
	crystals["water"] = 0
	crystals["earth"] = 0
	crystals["lightning"] = 0
	crystals["light"] = 0
	crystals["dark"] = 0
	
	# Initialize awakening essences - using SW terminology
	var elements = ["fire", "water", "earth", "lightning", "light", "dark"]
	for element in elements:
		essences[element + "_essences_low"] = 50
		essences[element + "_essences_mid"] = 25
		essences[element + "_essences_high"] = 25  # Give some for testing
	
	# Add magic essences (universal awakening material like SW)
	essences["magic_essences_low"] = 100
	essences["magic_essences_mid"] = 50
	essences["magic_essences_high"] = 25
	
	# Initialize awakening powders - legacy support
	for element in elements:
		powders[element + "_powder_low"] = 50
		powders[element + "_powder_mid"] = 25
		powders[element + "_powder_high"] = 25  # Give some for testing
	
	# Add magic powders (universal awakening material like SW)
	powders["magic_powder_low"] = 100
	powders["magic_powder_mid"] = 50
	powders["magic_powder_high"] = 25
	
	# Initialize pantheon relics
	var pantheons = ["greek", "norse", "egyptian", "hindu", "japanese", "celtic"]
	for pantheon in pantheons:
		relics[pantheon + "_relics"] = 15  # Give some for testing
	
	last_save_time = Time.get_unix_time_from_system()

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

func can_afford_summon(cost: int) -> bool:
	return divine_essence >= cost

func spend_divine_essence(amount: int) -> bool:
	if divine_essence >= amount:
		divine_essence -= amount
		return true
	return false

func add_divine_essence(amount: int):
	# Prevent overflow by capping at a reasonable maximum
	var max_essence = 2000000000  # 2 billion cap to prevent overflow
	divine_essence = min(divine_essence + amount, max_essence)
	if divine_essence >= max_essence:
		print("Warning: Divine essence capped at maximum value")

func add_crystal(element: String, amount: int):
	var max_crystals = 100000000  # 100 million cap
	if crystals.has(element):
		crystals[element] = min(crystals[element] + amount, max_crystals)
	else:
		crystals[element] = min(amount, max_crystals)

func add_crystals(element_type: int, amount: int):
	var element_name = get_element_name(element_type)
	add_crystal(element_name, amount)

func add_awakening_stones(amount: int):
	awakening_stones += amount

func get_element_name(element_type: int) -> String:
	match element_type:
		0: return "fire"
		1: return "water"
		2: return "earth"
		3: return "lightning"
		4: return "light"
		5: return "dark"
		_: return "unknown"

func get_crystal_amount(element: String) -> int:
	if crystals.has(element):
		return crystals[element]
	return 0


func spend_awakening_stones(amount: int) -> bool:
	if awakening_stones >= amount:
		awakening_stones -= amount
		return true
	return false

func control_territory(territory_id: String):
	if not controlled_territories.has(territory_id):
		controlled_territories.append(territory_id)

func lose_territory_control(territory_id: String):
	if controlled_territories.has(territory_id):
		controlled_territories.erase(territory_id)

func update_last_save_time():
	last_save_time = Time.get_unix_time_from_system()

# Enhanced currency management for new summon system
func spend_crystals(amount: int) -> bool:
	if premium_crystals >= amount:
		premium_crystals -= amount
		return true
	return false

func add_premium_crystals(amount: int):
	premium_crystals += amount

func spend_summon_tickets(amount: int) -> bool:
	if summon_tickets >= amount:
		summon_tickets -= amount
		return true
	return false

func add_summon_tickets(amount: int):
	summon_tickets += amount

func add_ascension_materials(amount: int):
	ascension_materials += amount

func spend_ascension_materials(amount: int) -> bool:
	if ascension_materials >= amount:
		ascension_materials -= amount
		return true
	return false

# Helper function to check for specific gods for ascension
func get_god_count(god_id: String) -> int:
	var count = 0
	for god in gods:
		if god.id == god_id:
			count += 1
	return count

func has_god(god_id: String) -> bool:
	return get_god_by_id(god_id) != null

# Awakening Materials Management
func add_powder(powder_type: String, amount: int):
	"""Add elemental powders (fire_powder_low, water_powder_mid, etc.)"""
	if not powders.has(powder_type):
		powders[powder_type] = 0
	powders[powder_type] += amount

func spend_powder(powder_type: String, amount: int) -> bool:
	"""Spend elemental powders"""
	if not powders.has(powder_type):
		return false
	if powders[powder_type] >= amount:
		powders[powder_type] -= amount
		return true
	return false

func get_powder_amount(powder_type: String) -> int:
	"""Get current amount of specific powder"""
	return powders.get(powder_type, 0)

# Essence Management (Summoners War authentic)
func add_essence(essence_type: String, amount: int):
	"""Add elemental essences (fire_essences_low, magic_essences_mid, etc.)"""
	if not essences.has(essence_type):
		essences[essence_type] = 0
	essences[essence_type] += amount

func spend_essence(essence_type: String, amount: int) -> bool:
	"""Spend elemental essences"""
	if not essences.has(essence_type):
		return false
	if essences[essence_type] >= amount:
		essences[essence_type] -= amount
		return true
	return false

func get_essence_amount(essence_type: String) -> int:
	"""Get current amount of specific essence"""
	return essences.get(essence_type, 0)

func add_relics(relic_type: String, amount: int):
	"""Add pantheon relics (greek_relics, norse_relics, etc.)"""
	if not relics.has(relic_type):
		relics[relic_type] = 0
	relics[relic_type] += amount

func spend_relics(relic_type: String, amount: int) -> bool:
	"""Spend pantheon relics"""
	if not relics.has(relic_type):
		return false
	if relics[relic_type] >= amount:
		relics[relic_type] -= amount
		return true
	return false

func get_relic_amount(relic_type: String) -> int:
	"""Get current amount of specific relics"""
	return relics.get(relic_type, 0)

func can_afford_awakening(materials_needed: Dictionary) -> bool:
	"""Check if player can afford awakening materials"""
	for material_type in materials_needed.keys():
		var needed = materials_needed[material_type]
		var current = 0
		
		match material_type:
			"awakening_stones":
				current = awakening_stones
			"divine_crystals":
				current = premium_crystals
			_:
				# Check essences first (SW authentic), then powders (legacy)
				if material_type in essences:
					current = essences[material_type]
				elif material_type in powders:
					current = powders[material_type]
				elif material_type in relics:
					current = relics[material_type]
		
		if current < needed:
			return false
	
	return true

func add_resource(resource_type: String, amount: int):
	"""Add any type of resource to player inventory"""
	var max_resource = 1000000000  # 1 billion general cap
	
	match resource_type:
		"divine_essence":
			add_divine_essence(amount)
		"crystals", "divine_crystals", "premium_crystals":
			premium_crystals = min(premium_crystals + amount, max_resource)
		"awakening_stone", "awakening_stones":
			awakening_stones = min(awakening_stones + amount, max_resource)
		"summon_tickets":
			summon_tickets = min(summon_tickets + amount, max_resource)
		"ascension_materials":
			ascension_materials = min(ascension_materials + amount, max_resource)
		_:
			# Handle powders and relics - using loot.json terminology
			if resource_type.ends_with("_powder_low") or resource_type.ends_with("_powder_mid") or resource_type.ends_with("_powder_high"):
				powders[resource_type] = min(powders.get(resource_type, 0) + amount, max_resource)
			elif resource_type.ends_with("_relics"):
				relics[resource_type] = min(relics.get(resource_type, 0) + amount, max_resource)
			elif resource_type in crystals:
				crystals[resource_type] = min(crystals[resource_type] + amount, max_resource)
			else:
				print("Warning: Unknown resource type: ", resource_type)

# Energy Management Functions
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
		energy = min(energy + energy_to_add, max_energy)
		last_energy_update = current_time
		print("Energy regenerated: +", energy_to_add, " (", energy, "/", max_energy, ")")

func can_afford_energy(cost: int) -> bool:
	"""Check if player has enough energy"""
	update_energy()  # Make sure energy is current
	return energy >= cost

func spend_energy(cost: int) -> bool:
	"""Spend energy if available"""
	update_energy()  # Make sure energy is current
	
	if energy >= cost:
		energy -= cost
		print("Energy spent: -", cost, " (", energy, "/", max_energy, ")")
		return true
	else:
		print("Not enough energy! Need: ", cost, ", Have: ", energy)
		return false

func add_energy(amount: int):
	"""Add energy (from items, crystal refreshes, etc.)"""
	energy = min(energy + amount, max_energy)
	print("Energy added: +", amount, " (", energy, "/", max_energy, ")")

func refresh_energy_with_crystals() -> bool:
	"""Refresh energy using premium crystals (30 crystals = 90 energy)"""
	var crystal_cost = 30
	var energy_gained = 90
	
	if premium_crystals >= crystal_cost:
		spend_crystals(crystal_cost)
		energy = min(energy + energy_gained, max_energy)
		print("Energy refreshed with crystals: +", energy_gained, " energy for ", crystal_cost, " crystals")
		return true
	else:
		print("Not enough crystals for energy refresh! Need: ", crystal_cost, ", Have: ", premium_crystals)
		return false

func get_energy_status() -> Dictionary:
	"""Get current energy status"""
	update_energy()
	return {
		"current": energy,
		"max": max_energy,
		"percentage": float(energy) / float(max_energy) * 100.0,
		"minutes_to_full": (max_energy - energy) * 5,  # 5 minutes per energy
		"can_refresh": premium_crystals >= 30
	}

func can_afford_upgrade_cost(cost: Dictionary) -> bool:
	"""Check if player can afford an upgrade cost"""
	for resource_type in cost:
		var needed = cost[resource_type]
		var current = 0
		
		match resource_type:
			"divine_essence":
				current = divine_essence
			"crystals", "divine_crystals", "premium_crystals":
				current = premium_crystals
			"awakening_stone", "awakening_stones":
				current = awakening_stones
			"summon_tickets":
				current = summon_tickets
			"ascension_materials":
				current = ascension_materials
			_:
				# Check powders, relics, and element crystals
				if resource_type.ends_with("_powder_low") or resource_type.ends_with("_powder_mid") or resource_type.ends_with("_powder_high"):
					current = powders.get(resource_type, 0)
				elif resource_type.ends_with("_relics"):
					current = relics.get(resource_type, 0)
				elif resource_type in crystals:
					current = crystals[resource_type]
				else:
					print("Warning: Unknown cost resource type: ", resource_type)
					return false
		
		if current < needed:
			return false
	
	return true

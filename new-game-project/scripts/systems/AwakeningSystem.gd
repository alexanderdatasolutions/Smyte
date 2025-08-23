# scripts/systems/AwakeningSystem.gd
extends Node
class_name AwakeningSystem

signal awakening_completed(god)
signal awakening_failed(god, reason)

const GameDataLoader = preload("res://scripts/systems/DataLoader.gd")

# Load awakening data from JSON
var awakening_data: Dictionary = {}

func _ready():
	load_awakening_data()

func load_awakening_data():
	"""Load awakened gods data from JSON file"""
	var file_path = "res://data/awakened_gods.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if not file:
		print("Warning: Could not open awakened_gods.json - awakening system disabled")
		awakening_data = {}
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		print("Error parsing awakened_gods.json: ", json.error_string)
		return
	
	awakening_data = json.get_data()
	print("Loaded awakening data for ", awakening_data.get("awakened_gods", {}).size(), " gods")

func can_awaken_god(god: God) -> Dictionary:
	"""Check if a god can be awakened and return requirements status"""
	var result = {
		"can_awaken": false,
		"missing_requirements": [],
		"requirements_met": [],
		"awakened_god_id": ""
	}
	
	# Check if awakened version exists for this god
	var awakened_god_id = god.id + "_awakened"
	var awakened_god_data = awakening_data.get("awakened_gods", {}).get(awakened_god_id, {})
	if awakened_god_data.is_empty():
		result.missing_requirements.append("No awakened form available for " + god.name)
		return result
	
	result.awakened_god_id = awakened_god_id
	
	# Check basic god requirements
	if god.is_awakened:
		result.missing_requirements.append("Already awakened")
		return result
	
	# Get general requirements
	var requirements = awakening_data.get("awakening_requirements", {})
	
	# Level requirement
	var required_level = requirements.get("base_god_level", 40)
	if god.level >= required_level:
		result.requirements_met.append("Level %d ✓" % required_level)
	else:
		result.missing_requirements.append("Level %d (currently %d)" % [required_level, god.level])
	
	# Max level requirement
	if requirements.get("base_god_max_level", false):
		if god.level >= 40:
			result.requirements_met.append("Max level ✓")
		else:
			result.missing_requirements.append("Must be max level (40)")
	
	# Skills at level 1 (simple requirement)
	if requirements.get("all_skills_level_1", false):
		result.requirements_met.append("Basic skill requirements ✓")
	
	result.can_awaken = result.missing_requirements.size() == 0
	return result

func get_awakening_requirements(god: God) -> Dictionary:
	"""Get the awakening requirements for a specific god"""
	var god_awakening = awakening_data.get("awakened_gods", {}).get(god.id, {})
	return god_awakening.get("awakening_requirements", {})

func get_awakening_materials_cost(god: God) -> Dictionary:
	"""Get the materials needed to awaken a god"""
	var awakened_god_id = god.id + "_awakened"
	var awakened_god_data = awakening_data.get("awakened_gods", {}).get(awakened_god_id, {})
	return awakened_god_data.get("awakening_materials", {})

func attempt_awakening(god: God, player_data) -> bool:
	"""Try to awaken a god if requirements are met"""
	var requirements_check = can_awaken_god(god)
	if not requirements_check.can_awaken:
		awakening_failed.emit(god, "Requirements not met")
		return false
	
	# Check materials in player inventory
	var materials_needed = get_awakening_materials_cost(god)
	var materials_check = check_awakening_materials(materials_needed, player_data)
	
	if not materials_check.can_afford:
		awakening_failed.emit(god, "Insufficient materials")
		return false
	
	# Consume materials
	consume_awakening_materials(materials_needed, player_data)
	
	# Get awakened god data
	var awakened_god_id = requirements_check.awakened_god_id
	var awakened_god_data = awakening_data.get("awakened_gods", {}).get(awakened_god_id, {})
	
	# Replace the god with the awakened version
	if replace_god_with_awakened(god, awakened_god_data, player_data):
		awakening_completed.emit(god)
		print("Successfully awakened %s into %s!" % [god.name, awakened_god_data.get("name", "Unknown")])
		return true
	else:
		awakening_failed.emit(god, "Awakening process failed")
		return false

func replace_god_with_awakened(old_god: God, awakened_data: Dictionary, player_data) -> bool:
	"""Replace the base god with its awakened form"""
	# Find the god in player's collection
	var god_index = -1
	for i in range(player_data.gods.size()):
		if player_data.gods[i] == old_god:
			god_index = i
			break
	
	if god_index == -1:
		print("Error: Could not find god in player collection")
		return false
	
	# Create the awakened god from the JSON data
	var awakened_god = create_awakened_god_from_data(awakened_data)
	if not awakened_god:
		print("Error: Could not create awakened god")
		return false
	
	# Preserve some stats from the original god
	awakened_god.level = old_god.level
	awakened_god.experience = old_god.experience
	awakened_god.ascension_level = old_god.ascension_level
	awakened_god.skill_levels = old_god.skill_levels.duplicate()
	awakened_god.stationed_territory = old_god.stationed_territory
	
	# Mark as awakened
	awakened_god.is_awakened = true
	
	# Replace in collection
	player_data.gods[god_index] = awakened_god
	
	return true

func create_awakened_god_from_data(awakened_data: Dictionary) -> God:
	"""Create a God instance from awakened god JSON data"""
	var god = God.new()
	
	# Basic info
	god.id = awakened_data.get("id", "")
	god.name = awakened_data.get("name", "")
	god.pantheon = awakened_data.get("pantheon", "")
	god.element = God.string_to_element(awakened_data.get("element", "light"))
	god.tier = God.string_to_tier(awakened_data.get("tier", "legendary"))
	# Note: description is not a God property, only exists in JSON data
	
	# Stats
	var base_stats = awakened_data.get("base_stats", {})
	god.base_hp = base_stats.get("hp", 1000)
	god.base_attack = base_stats.get("attack", 500)
	god.base_defense = base_stats.get("defense", 400)
	god.base_speed = base_stats.get("speed", 100)
	god.resource_generation = awakened_data.get("resource_generation", 15)
	
	# Abilities
	god.active_abilities = awakened_data.get("active_abilities", [])
	god.passive_abilities = awakened_data.get("passive_abilities", [])
	
	return god

func check_awakening_materials(materials_needed: Dictionary, player_data) -> Dictionary:
	"""Check if player has required materials"""
	var result = {
		"can_afford": true,
		"missing_materials": []
	}
	
	# Check each material type
	for material_type in materials_needed.keys():
		var needed_amount = materials_needed[material_type]
		var current_amount = get_player_material_amount(material_type, player_data)
		
		if current_amount < needed_amount:
			result.can_afford = false
			result.missing_materials.append({
				"type": material_type,
				"needed": needed_amount,
				"current": current_amount,
				"missing": needed_amount - current_amount
			})
	
	return result

func consume_awakening_materials(materials_needed: Dictionary, player_data):
	"""Remove materials from player inventory"""
	for material_type in materials_needed.keys():
		var amount = materials_needed[material_type]
		consume_player_material(material_type, amount, player_data)

func get_player_material_amount(material_type: String, player_data) -> int:
	"""Get how much of a material the player has"""
	match material_type:
		"awakening_stones":
			return player_data.awakening_stones
		"divine_crystals":
			return player_data.premium_crystals
		_:
			# Handle elemental powders and pantheon relics
			if material_type.ends_with("_powder_low") or material_type.ends_with("_powder_mid") or material_type.ends_with("_powder_high"):
				return player_data.get_powder_amount(material_type)
			elif material_type.ends_with("_relics"):
				return player_data.get_relic_amount(material_type)
	
	return 0

func consume_player_material(material_type: String, amount: int, player_data):
	"""Remove materials from player inventory"""
	match material_type:
		"awakening_stones":
			player_data.spend_awakening_stones(amount)
		"divine_crystals":
			player_data.spend_crystals(amount)
		_:
			# Handle powders and relics - using loot.json terminology
			if material_type.ends_with("_powder_low") or material_type.ends_with("_powder_mid") or material_type.ends_with("_powder_high"):
				player_data.spend_powder(material_type, amount)
			elif material_type.ends_with("_relics"):
				player_data.spend_relics(material_type, amount)

func get_ascension_level_from_string(ascension_string: String) -> int:
	"""Convert ascension string to level number"""
	match ascension_string.to_lower():
		"bronze":
			return 1
		"silver":
			return 2
		"gold":
			return 3
		"diamond":
			return 4
		"transcendent":
			return 5
		_:
			return 0

func get_awakened_abilities(god: God) -> Array:
	"""Get the awakened abilities for a god"""
	if not god.is_awakened:
		return []
	
	var god_awakening = awakening_data.get("awakened_gods", {}).get(god.id, {})
	var awakened_form = god_awakening.get("awakened_form", {})
	
	var awakened_abilities = []
	
	# Get unique awakened ability
	var unique_ability = awakened_form.get("unique_awakened_ability", {})
	if not unique_ability.is_empty():
		awakened_abilities.append(unique_ability)
	
	return awakened_abilities

func get_awakened_leader_skill(god: God) -> Dictionary:
	"""Get awakened leader skill if available"""
	if not god.is_awakened:
		return {}
	
	var god_awakening = awakening_data.get("awakened_gods", {}).get(god.id, {})
	var awakened_form = god_awakening.get("awakened_form", {})
	
	return awakened_form.get("leader_skill", {})

func get_awakened_passive(god: God) -> Dictionary:
	"""Get enhanced awakened passive"""
	if not god.is_awakened:
		return {}
	
	var god_awakening = awakening_data.get("awakened_gods", {}).get(god.id, {})
	var awakened_form = god_awakening.get("awakened_form", {})
	
	return awakened_form.get("enhanced_passive", {})

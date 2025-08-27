# scripts/systems/LootSystem.gd
extends Node
class_name LootSystem

signal loot_awarded(loot_results)

var loot_items_data: Dictionary = {}
var loot_tables_data: Dictionary = {}

# Reference to ResourceManager for complete modularity
var resource_manager: Node = null

func _ready():
	# Get ResourceManager reference
	resource_manager = get_node("/root/ResourceManager") if has_node("/root/ResourceManager") else null
	
	if not resource_manager:
		# Create ResourceManager if it doesn't exist
		resource_manager = preload("res://scripts/systems/ResourceManager.gd").new()
		resource_manager.name = "ResourceManager"
		get_tree().root.add_child(resource_manager)
	
	load_loot_data()

func load_loot_data():
	"""Load modular loot system data with template support"""
	_load_json_file("res://data/loot_items.json", "loot_items_data") 
	_load_json_file("res://data/loot_tables.json", "loot_tables_data")
	
	print("LootSystem: Loaded template-based loot system:")
	print("  - Loot Items: ", loot_items_data.get("loot_items", {}).size(), " items")
	print("  - Loot Templates: ", loot_tables_data.get("loot_templates", {}).size(), " templates")
	print("  - Loot Tables: ", loot_tables_data.get("loot_tables", {}).size(), " tables")
	print("  - Resources handled by ResourceManager")

func _load_json_file(file_path: String, target_var: String):
	"""Helper to load JSON files into class variables"""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to load " + file_path)
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse " + file_path + ": " + json.error_string)
		return
	
	match target_var:
		"loot_items_data":
			loot_items_data = json.get_data()
		"loot_tables_data":
			loot_tables_data = json.get_data()

func award_loot(loot_table_name: String, stage_level: int = 1, territory_element: String = "", context: Dictionary = {}) -> Dictionary:
	"""Award loot from specified loot table or template - returns awarded items"""
	
	# Resolve loot table (template or direct table)
	var loot_table = resolve_loot_table(loot_table_name, context)
	if loot_table.is_empty():
		push_error("Loot table/template not found or failed to resolve: " + loot_table_name)
		return {}
	
	var awarded_loot = {}
	
	# Get element from loot table if not provided
	var effective_element = territory_element
	if effective_element == "" and loot_table.has("element"):
		effective_element = loot_table.element
	
	# Process guaranteed drops
	if loot_table.has("guaranteed_drops"):
		for drop in loot_table.guaranteed_drops:
			var result = _process_loot_drop(drop, stage_level, effective_element)
			_merge_loot_results(awarded_loot, result)
	
	# Process rare drops (chance-based)
	if loot_table.has("rare_drops"):
		for drop in loot_table.rare_drops:
			var result = _process_loot_drop(drop, stage_level, effective_element)
			_merge_loot_results(awarded_loot, result)
	
	# Process base generation for territories
	if loot_table.has("base_generation_per_hour"):
		for drop in loot_table.base_generation_per_hour:
			var result = _process_loot_drop(drop, stage_level, effective_element)
			_merge_loot_results(awarded_loot, result)
	
	# Award to player
	_award_to_player(awarded_loot)
	
	loot_awarded.emit(awarded_loot)
	return awarded_loot

func resolve_loot_table(table_name: String, context: Dictionary = {}) -> Dictionary:
	"""Resolve loot table name to actual loot table data, handling templates"""
	
	# First check if it's a direct loot table
	if loot_tables_data.has("loot_tables") and loot_tables_data.loot_tables.has(table_name):
		return loot_tables_data.loot_tables[table_name]
	
	# Check if it's a template-based table name (e.g., "fire_dungeon_beginner")
	if not loot_tables_data.has("loot_templates"):
		return {}
	
	var template_data = _resolve_template_from_name(table_name)
	if template_data.is_empty():
		return {}
	
	var template_name = template_data.template_name
	var substitutions = template_data.substitutions
	
	# Merge context substitutions
	for key in context:
		substitutions[key] = context[key]
	
	var template = loot_tables_data.loot_templates[template_name]
	return _apply_template_substitutions(template, substitutions)

func _resolve_template_from_name(table_name: String) -> Dictionary:
	"""Resolve table name like 'fire_dungeon_beginner' to template and substitutions"""
	
	# Common patterns for template resolution
	var patterns = [
		{
			"regex": "^(fire|water|earth|air|dark)_dungeon_(beginner|intermediate|advanced|expert|master)$",
			"template": "elemental_dungeon_{difficulty}",
			"substitutions": {"element": "$1", "difficulty": "$2"}
		},
		{
			"regex": "^(egyptian|norse|greek|hindu|celtic)_trial_(heroic|legendary)$", 
			"template": "pantheon_trial_{tier}",
			"substitutions": {"pantheon": "$1", "tier": "$2"}
		},
		{
			"regex": "^(weapon|armor|accessory)_dungeon_(beginner|intermediate|advanced)$",
			"template": "equipment_dungeon_{tier}",
			"substitutions": {"equipment_type": "$1", "tier": "$2"}
		},
		{
			"regex": "^(.+)_tier_([123])$",
			"template": "territory_tier_{level}",
			"substitutions": {"territory_name": "$1", "level": "$2"}
		}
	]
	
	for pattern in patterns:
		var regex = RegEx.new()
		regex.compile(pattern.regex)
		var result = regex.search(table_name)
		
		if result:
			var substitutions = {}
			var template_name = pattern.template
			
			# Apply regex capture substitutions
			for sub_key in pattern.substitutions:
				var sub_value = pattern.substitutions[sub_key]
				if sub_value.begins_with("$"):
					var capture_index = int(sub_value.substr(1))
					substitutions[sub_key] = result.get_string(capture_index)
				else:
					substitutions[sub_key] = sub_value
			
			# Replace placeholders in template name
			for key in substitutions:
				template_name = template_name.replace("{" + key + "}", substitutions[key])
			
			return {
				"template_name": template_name,
				"substitutions": substitutions
			}
	
	return {}

func _apply_template_substitutions(template: Dictionary, substitutions: Dictionary) -> Dictionary:
	"""Apply substitutions to template data"""
	var resolved_table = {}
	
	for key in template:
		resolved_table[key] = _substitute_value(template[key], substitutions)
	
	return resolved_table

func _substitute_value(value, substitutions: Dictionary):
	"""Recursively substitute placeholders in any value type"""
	if value is String:
		return _substitute_string(value, substitutions)
	elif value is Array:
		var new_array = []
		for item in value:
			new_array.append(_substitute_value(item, substitutions))
		return new_array
	elif value is Dictionary:
		var new_dict = {}
		for key in value:
			new_dict[key] = _substitute_value(value[key], substitutions)
		return new_dict
	else:
		return value

func _substitute_string(text: String, substitutions: Dictionary) -> String:
	"""Substitute placeholders like {element}, {pantheon} in strings"""
	var result = text
	
	for key in substitutions:
		var placeholder = "{" + key + "}"
		result = result.replace(placeholder, substitutions[key])
	
	return result

func _process_loot_drop(drop: Dictionary, stage_level: int, element: String) -> Dictionary:
	"""Process a loot drop using the new modular system"""
	var chance = drop.get("chance", 1.0)
	
	# Check chance
	if randf() > chance:
		return {}
	
	var loot_item_id = drop.get("loot_item_id", "")
	if loot_item_id == "":
		push_error("Loot drop missing loot_item_id")
		return {}
	
	# Get loot item definition
	if not loot_items_data.has("loot_items") or not loot_items_data.loot_items.has(loot_item_id):
		push_error("Loot item not found: " + loot_item_id)
		return {}
	
	var loot_item = loot_items_data.loot_items[loot_item_id]
	return _resolve_loot_item(loot_item, stage_level, element)

func _resolve_loot_item(loot_item: Dictionary, stage_level: int, element: String) -> Dictionary:
	"""Resolve a loot item into actual resources with template substitution support"""
	var result = {}
	
	# Handle different resource types
	var resource_type = loot_item.get("resource_type", "standard")
	
	match resource_type:
		"element_based":
			result = _handle_element_based_item(loot_item, element)
		"element_specific":
			result = _handle_element_specific_item(loot_item, element)
		"experience":
			result = _handle_experience_item(loot_item, stage_level)
		"equipment":
			result = _handle_equipment_item(loot_item, stage_level)
		"random_consumable":
			result = _handle_random_consumable(loot_item)
		_:  # standard
			result = _handle_standard_item(loot_item, stage_level)
	
	return result

func _handle_element_specific_item(loot_item: Dictionary, element: String) -> Dictionary:
	"""Handle element-specific loot items that should only drop matching element resources"""
	if element == "":
		return {}  # No element context, skip element-specific drops
	
	var base_resource = loot_item.get("base_resource", "")
	var min_amount = loot_item.get("min_amount", 1)
	var max_amount = loot_item.get("max_amount", 1)
	var amount = randi_range(min_amount, max_amount)
	
	# Apply element bonuses - element_specific items always get matching bonus
	if loot_item.has("element_bonus"):
		var bonus = loot_item.element_bonus
		if bonus.has("matching_element"):
			amount = int(amount * bonus.matching_element)
	
	# Resolve element-based resource ID
	var resource_id = _resolve_element_resource(base_resource, element)
	if resource_id == "":
		return {}
	
	return {resource_id: amount}

func _handle_element_based_item(loot_item: Dictionary, element: String) -> Dictionary:
	"""Handle element-based loot items like powders, souls, gemstones"""
	var base_resource = loot_item.get("base_resource", "")
	var min_amount = loot_item.get("min_amount", 1)
	var max_amount = loot_item.get("max_amount", 1)
	var amount = randi_range(min_amount, max_amount)
	
	# Apply element bonuses
	if loot_item.has("element_bonus") and element != "":
		var bonus = loot_item.element_bonus
		if bonus.has("matching_element"):
			amount = int(amount * bonus.matching_element)
	
	# Resolve element-based resource ID
	var resource_id = _resolve_element_resource(base_resource, element)
	if resource_id == "":
		return {}
	
	return {resource_id: amount}

func _resolve_element_resource(base_resource: String, element: String) -> String:
	"""Resolve element + base resource to actual resource ID using ResourceManager"""
	if not resource_manager:
		push_error("ResourceManager not available")
		return ""
	
	return resource_manager.resolve_element_resource(base_resource, element)

func _handle_standard_item(loot_item: Dictionary, stage_level: int) -> Dictionary:
	"""Handle standard resource drops"""
	var resource_id = loot_item.get("resource_id", "")
	var min_amount = loot_item.get("min_amount", 1)
	var max_amount = loot_item.get("max_amount", 1)
	var amount = randi_range(min_amount, max_amount)
	
	# Apply scaling
	if loot_item.has("scaling"):
		var scaling = loot_item.scaling
		if scaling.get("per_stage", false):
			var multiplier = scaling.get("base_multiplier", 1.0)
			var scale_type = scaling.get("type", "linear")
			
			match scale_type:
				"linear":
					amount = int(amount * pow(multiplier, stage_level - 1))
				"exponential":
					amount = int(amount * pow(multiplier, (stage_level - 1) * 1.5))
	
	return {resource_id: amount}

func _handle_experience_item(loot_item: Dictionary, stage_level: int) -> Dictionary:
	"""Handle experience drops"""
	var min_amount = loot_item.get("min_amount", 100)
	var max_amount = loot_item.get("max_amount", 300)
	var amount = randi_range(min_amount, max_amount)
	
	# Apply stage scaling
	if loot_item.has("scaling"):
		var scaling = loot_item.scaling
		var multiplier = scaling.get("base_multiplier", 1.1)
		amount = int(amount * pow(multiplier, stage_level - 1))
	
	return {"experience": amount}

func _handle_equipment_item(loot_item: Dictionary, _stage_level: int) -> Dictionary:
	"""Handle equipment drops"""
	var min_amount = loot_item.get("min_amount", 1)
	var max_amount = loot_item.get("max_amount", 1)
	var amount = randi_range(min_amount, max_amount)
	
	# For now, just return a placeholder - equipment system handles actual creation
	return {"equipment_dropped": amount}

func _handle_random_consumable(loot_item: Dictionary) -> Dictionary:
	"""Handle random consumable drops"""
	var pool = loot_item.get("pool", [])
	var min_amount = loot_item.get("min_amount", 1)
	var max_amount = loot_item.get("max_amount", 1)
	
	if pool.is_empty():
		return {}
	
	var random_consumable = pool[randi() % pool.size()]
	var amount = randi_range(min_amount, max_amount)
	
	return {random_consumable: amount}

func _merge_loot_results(target: Dictionary, source: Dictionary):
	"""Merge loot results, combining amounts for same resources"""
	for resource_id in source:
		target[resource_id] = target.get(resource_id, 0) + source[resource_id]

func _award_to_player(loot_results: Dictionary):
	"""Award loot to player using PlayerData methods"""
	if not GameManager or not GameManager.player_data:
		return
	
	for resource_id in loot_results:
		var amount = loot_results[resource_id]
		
		# Handle experience separately (award to gods, not player data)
		if resource_id == "experience":
			GameManager.award_experience_to_gods(amount)
			print("Awarded: ", amount, " XP to participating gods")
		elif resource_id == "equipment_dropped":
			# Equipment drops are handled by equipment system
			print("Equipment dropped: ", amount, " pieces")
		else:
			# Handle different ways PlayerData might store resources
			if GameManager.player_data.has_method("add_resource"):
				GameManager.player_data.add_resource(resource_id, amount)
			else:
				# Try to get existing value, add if exists, create if doesn't
				var current_value = GameManager.player_data.get(resource_id)
				if current_value != null:
					GameManager.player_data[resource_id] = current_value + amount
				else:
					# Create the property dynamically for modular resources
					GameManager.player_data.set(resource_id, amount)
					print("LootSystem: Created new resource property: ", resource_id)
			
			print("Awarded: ", resource_id, " x", amount)
	
	# Trigger resource update
	GameManager.resources_updated.emit()

# New utility functions for modular system
func get_resource_info(resource_id: String) -> Dictionary:
	"""Get detailed information about a resource using ResourceManager"""
	if not resource_manager:
		return {}
	
	return resource_manager.get_resource_info(resource_id)

func get_loot_table_info(loot_table_id: String) -> Dictionary:
	"""Get information about a loot table"""
	if loot_tables_data.has("loot_tables") and loot_tables_data.loot_tables.has(loot_table_id):
		return loot_tables_data.loot_tables[loot_table_id]
	return {}

func can_convert_resource(_from_resource: String, _to_resource: String) -> bool:
	"""Check if a resource can be converted to another using ResourceManager"""
	if not resource_manager:
		return false
	
	# Get conversion config from ResourceManager
	var resource_config = resource_manager.resource_config
	if not resource_config.has("conversion_rates"):
		return false
	
	# Check powder conversion
	if resource_config.conversion_rates.has("powder_conversion"):
		# Add specific conversion logic here
		return true
	
	return false

func get_conversion_cost(from_resource: String, to_resource: String, amount: int) -> Dictionary:
	"""Get the cost to convert resources using ResourceManager"""
	if not can_convert_resource(from_resource, to_resource):
		return {}
	
	if not resource_manager:
		return {}
	
	var resource_config = resource_manager.resource_config
	var conversion_config = resource_config.conversion_rates.powder_conversion
	var from_info = get_resource_info(from_resource)
	var tier = from_info.get("tier", "low")
	
	var mana_cost_per_unit = conversion_config.mana_cost_per_powder.get(tier, 100)
	var total_mana_cost = int(amount * mana_cost_per_unit * conversion_config.cost_multiplier)
	
	return {"mana": total_mana_cost}# Convenience methods for common loot scenarios
func award_stage_victory_loot(stage_level: int, territory_element: String = "") -> Dictionary:
	"""Award loot for stage victory"""
	return award_loot("stage_victory", stage_level, territory_element)

func award_boss_stage_loot(stage_level: int, territory_element: String = "") -> Dictionary:
	"""Award loot for boss stage victory"""
	return award_loot("boss_stage", stage_level, territory_element)

func award_dungeon_loot(dungeon_id: String, difficulty: String = "beginner", stage_level: int = 1) -> Dictionary:
	"""Award loot for dungeon completion"""
	var loot_table_id = dungeon_id + "_" + difficulty
	return award_loot(loot_table_id, stage_level)

func award_territory_passive_income(territory_tier: int, territory_element: String = "", god_bonuses: Dictionary = {}) -> Dictionary:
	"""Award territory passive income with god assignment bonuses"""
	var loot_table_id = "territory_passive_tier" + str(territory_tier)
	var base_loot = award_loot(loot_table_id, 1, territory_element)
	
	# Apply god bonuses if present
	if god_bonuses.size() > 0:
		base_loot = _apply_god_bonuses(base_loot, god_bonuses)
	
	return base_loot

func _apply_god_bonuses(base_loot: Dictionary, god_bonuses: Dictionary) -> Dictionary:
	"""Apply god assignment bonuses to loot"""
	var enhanced_loot = base_loot.duplicate()
	
	# Apply multipliers from assigned gods
	for resource_id in enhanced_loot:
		var amount = enhanced_loot[resource_id]
		
		# Element matching bonus
		if god_bonuses.has("element_match") and god_bonuses.element_match:
			amount = int(amount * 1.5)
		
		# Rarity bonus
		if god_bonuses.has("rarity_multiplier"):
			amount = int(amount * god_bonuses.rarity_multiplier)
		
		# Awakened bonus
		if god_bonuses.has("awakened") and god_bonuses.awakened:
			amount = int(amount * 1.3)
		
		enhanced_loot[resource_id] = amount
	
	return enhanced_loot

func get_loot_table_rewards_preview(loot_table_id: String, context: Dictionary = {}) -> Array:
	"""Get a preview of rewards from a loot table or template"""
	var preview_rewards = []
	
	# Resolve the loot table (template or direct)
	var loot_table = resolve_loot_table(loot_table_id, context)
	if loot_table.is_empty():
		print("LootSystem: No loot table/template found for ID: ", loot_table_id)
		return preview_rewards
	
	# Process guaranteed drops
	var guaranteed_drops = loot_table.get("guaranteed_drops", [])
	for drop in guaranteed_drops:
		var reward_info = _process_loot_item_for_preview(drop, true, context)
		if not reward_info.is_empty():
			preview_rewards.append(reward_info)
	
	# Process rare drops  
	var rare_drops = loot_table.get("rare_drops", [])
	for drop in rare_drops:
		var reward_info = _process_loot_item_for_preview(drop, false, context)
		if not reward_info.is_empty():
			preview_rewards.append(reward_info)
	
	return preview_rewards

func _process_loot_item_for_preview(drop: Dictionary, is_guaranteed: bool, context: Dictionary = {}) -> Dictionary:
	"""Process a single loot drop for preview display with template substitution"""
	var loot_item_id = drop.get("loot_item_id", "")
	var chance = drop.get("chance", 0.0)
	
	# Apply template substitutions to loot_item_id if needed
	loot_item_id = _substitute_string(loot_item_id, context)
	
	# Get loot item data
	var loot_item = loot_items_data.get("loot_items", {}).get(loot_item_id, {})
	if loot_item.is_empty():
		return {}
	
	# Apply template substitutions to loot item if needed
	loot_item = _substitute_value(loot_item, context)
	
	# Get resource info from ResourceManager
	var resource_id = loot_item.get("resource_id", loot_item_id)
	resource_id = _substitute_string(resource_id, context)
	
	var resource_info = {}
	if resource_manager and resource_manager.has_method("get_resource_info"):
		resource_info = resource_manager.get_resource_info(resource_id)
	
	# Build preview info
	var preview_info = {}
	preview_info.resource_name = resource_info.get("name", resource_id.capitalize().replace("_", " "))
	
	# Amount display
	var min_amount = loot_item.get("min_amount", 1)
	var max_amount = loot_item.get("max_amount", min_amount)
	if min_amount == max_amount:
		preview_info.amount_text = str(min_amount)
	else:
		preview_info.amount_text = "%d-%d" % [min_amount, max_amount]
	
	# Chance display
	if is_guaranteed:
		preview_info.chance_text = "Guaranteed"
		preview_info.color = Color.GREEN
	else:
		var chance_percent = int(chance * 100)
		preview_info.chance_text = "%d%% chance" % chance_percent
		if chance >= 0.5:
			preview_info.color = Color.YELLOW
		else:
			preview_info.color = Color.LIGHT_GRAY
	
	# Use resource color if available
	var resource_color = resource_info.get("color", "")
	if resource_color != "" and resource_color.is_valid_html_color():
		preview_info.color = Color(resource_color)
	
	return preview_info

func get_available_dungeon_types() -> Dictionary:
	"""Get available dungeon types and their template patterns for UI generation"""
	return {
		"elemental_dungeons": {
			"elements": ["fire", "water", "earth", "air", "dark"],
			"difficulties": ["beginner", "intermediate", "advanced", "expert", "master"],
			"template_pattern": "{element}_dungeon_{difficulty}"
		},
		"pantheon_trials": {
			"pantheons": ["egyptian", "norse", "greek", "hindu", "celtic"],
			"tiers": ["heroic", "legendary"],
			"template_pattern": "{pantheon}_trial_{tier}"
		},
		"equipment_dungeons": {
			"equipment_types": ["weapon", "armor", "accessory"],
			"tiers": ["beginner", "intermediate", "advanced"],
			"template_pattern": "{equipment_type}_dungeon_{tier}"
		},
		"territory_tiers": {
			"levels": ["1", "2", "3"],
			"template_pattern": "{territory_name}_tier_{level}"
		}
	}

func generate_dungeon_loot_table_id(dungeon_type: String, params: Dictionary) -> String:
	"""Generate loot table ID from dungeon type and parameters"""
	var dungeon_types = get_available_dungeon_types()
	
	if not dungeon_types.has(dungeon_type):
		return ""
	
	var pattern = dungeon_types[dungeon_type].template_pattern
	var result = pattern
	
	for key in params:
		var placeholder = "{" + key + "}"
		result = result.replace(placeholder, str(params[key]))
	
	return result

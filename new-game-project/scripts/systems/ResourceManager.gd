# scripts/systems/ResourceManager.gd
extends Node
class_name ResourceManager

signal resources_updated
signal resource_definitions_loaded

# Core resource data - loaded from JSON files
var resource_definitions: Dictionary = {}
var resource_config: Dictionary = {}
var ui_layout_config: Dictionary = {}

# Cached resource info for performance
var _currency_cache: Dictionary = {}
var _display_order_cache: Array = []

func _ready():
	load_all_resource_definitions()

func load_all_resource_definitions():
	"""Load all resource definitions from JSON files - completely modular"""
	print("ResourceManager: Loading modular resource system...")
	
	# Load core resource definitions
	_load_json_file("res://data/resources.json", "resource_definitions")
	
	# Load resource configuration (aliases, mappings, etc.)
	_load_json_file("res://data/resource_config.json", "resource_config")
	
	# Load UI layout configuration
	_create_default_ui_layout()
	
	# Process and cache commonly used data
	_process_resource_cache()
	
	print("ResourceManager: Loaded ", get_total_resource_count(), " resources across all categories")
	resource_definitions_loaded.emit()

func _load_json_file(file_path: String, target_var: String):
	"""Generic JSON file loader"""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to load: " + file_path)
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse JSON: " + file_path)
		return
	
	match target_var:
		"resource_definitions":
			resource_definitions = json.get_data()
		"resource_config":
			resource_config = json.get_data()

func _create_default_ui_layout():
	"""Create default UI layout configuration - can be overridden by JSON file later"""
	ui_layout_config = {
		"main_display": {
			"show_currencies": true,
			"show_energy": true,
			"show_materials_button": true,
			"currency_order": ["primary_currency", "premium_currency", "energy_currency"]
		},
		"materials_popup": {
			"categories_to_show": ["awakening_materials", "crafting_materials", "summoning_materials"],
			"group_by_element": true,
			"show_empty_resources": false
		}
	}

func _process_resource_cache():
	"""Process and cache commonly accessed resource data"""
	_currency_cache.clear()
	_display_order_cache.clear()
	
	# Cache currency information
	var currency_aliases = resource_config.get("currency_aliases", {})
	for alias_key in currency_aliases:
		var resource_id = currency_aliases[alias_key]
		var resource_info = get_resource_info(resource_id)
		_currency_cache[alias_key] = {
			"id": resource_id,
			"info": resource_info
		}
	
	# Cache display order for UI
	var ui_order = ui_layout_config.get("main_display", {}).get("currency_order", [])
	_display_order_cache = ui_order

# === Core Resource Access Functions ===

func get_resource_info(resource_id: String) -> Dictionary:
	"""Get complete information about any resource - completely dynamic"""
	# Search through all resource categories
	for category_name in resource_definitions:
		var category = resource_definitions[category_name]
		if typeof(category) == TYPE_DICTIONARY and category.has(resource_id):
			var resource_data = category[resource_id]
			# Add category information
			resource_data["resource_category"] = category_name
			return resource_data
	
	# Return fallback info if not found
	return {
		"id": resource_id,
		"name": resource_id.capitalize().replace("_", " "),
		"description": "Unknown resource",
		"category": "unknown",
		"icon": "default_icon"
	}

func get_currency_info(currency_alias: String) -> Dictionary:
	"""Get currency info by alias (primary_currency, premium_currency, etc.)"""
	if _currency_cache.has(currency_alias):
		return _currency_cache[currency_alias]
	
	# Fallback lookup
	var currency_aliases = resource_config.get("currency_aliases", {})
	var resource_id = currency_aliases.get(currency_alias, currency_alias)
	var info = get_resource_info(resource_id)
	
	return {
		"id": resource_id,
		"info": info
	}

func get_display_currencies() -> Array:
	"""Get currencies to display in UI in the correct order"""
	var currencies = []
	for alias in _display_order_cache:
		var currency_data = get_currency_info(alias)
		if not currency_data.info.is_empty():
			currencies.append(currency_data)
	return currencies

func get_resources_by_category(category_name: String) -> Dictionary:
	"""Get all resources in a specific category"""
	return resource_definitions.get(category_name, {})

func get_all_materials() -> Dictionary:
	"""Get all material resources for the materials popup"""
	var all_materials = {}
	var material_categories = ui_layout_config.get("materials_popup", {}).get("categories_to_show", [])
	
	for category_name in material_categories:
		var category_resources = get_resources_by_category(category_name)
		for resource_id in category_resources:
			all_materials[resource_id] = category_resources[resource_id]
	
	return all_materials

# === Element-based Resource Resolution ===

func resolve_element_resource(base_resource: String, element: String) -> String:
	"""Resolve element + base resource to actual resource ID using config"""
	if element == "" or element == "universal":
		# Return universal version if it exists
		return "magic_" + base_resource if resource_definitions.has("magic_" + base_resource) else ""
	
	var element_mappings = resource_config.get("element_mappings", {})
	if not element_mappings.has(element):
		push_error("Unknown element: " + element)
		return ""
	
	var element_map = element_mappings[element]
	return element_map.get(base_resource, "")

# === Utility Functions ===

func get_total_resource_count() -> int:
	"""Get total number of resources across all categories"""
	var total = 0
	for category in resource_definitions.values():
		if typeof(category) == TYPE_DICTIONARY:
			total += category.size()
	return total

func get_resource_categories() -> Array:
	"""Get list of all resource categories"""
	return resource_definitions.keys()

func resource_exists(resource_id: String) -> bool:
	"""Check if a resource exists in the system"""
	return not get_resource_info(resource_id).get("category", "") == "unknown"

# === Configuration Updates ===

func reload_configuration():
	"""Reload all configuration - useful for development"""
	load_all_resource_definitions()

func update_resource_alias(alias: String, new_resource_id: String):
	"""Dynamically update a resource alias - changes propagate everywhere"""
	if not resource_config.has("currency_aliases"):
		resource_config["currency_aliases"] = {}
	
	resource_config["currency_aliases"][alias] = new_resource_id
	_process_resource_cache()  # Refresh cache
	resources_updated.emit()

# === Debug Functions ===

func print_all_resources():
	"""Debug function to print all loaded resources"""
	print("=== All Loaded Resources ===")
	for category_name in resource_definitions:
		print("Category: ", category_name)
		var category = resource_definitions[category_name]
		if typeof(category) == TYPE_DICTIONARY:
			for resource_id in category:
				var resource = category[resource_id]
				print("  - ", resource_id, ": ", resource.get("name", "Unknown"))
	print("=== End Resources ===")

func get_resource_summary() -> Dictionary:
	"""Get summary of all resources for debugging"""
	var summary = {}
	for category_name in resource_definitions:
		var category = resource_definitions[category_name]
		if typeof(category) == TYPE_DICTIONARY:
			summary[category_name] = category.size()
	return summary

func resolve_cost_reference(cost_key: String) -> String:
	"""Resolve cost references like 'primary_currency_cost' to actual currency ID"""
	if cost_key == "primary_currency_cost":
		var currency_info = get_currency_info("primary_currency")
		return currency_info.get("id", "mana")  # fallback to mana
	elif cost_key == "premium_currency_cost":
		var currency_info = get_currency_info("premium_currency")
		return currency_info.get("id", "divine_crystals")
	elif cost_key == "energy_currency_cost":
		var currency_info = get_currency_info("energy_currency")
		return currency_info.get("id", "energy")
	else:
		# If it's already a currency ID, return as-is
		return cost_key

func get_cost_from_recipe(recipe: Dictionary, cost_key: String = "primary_currency_cost") -> Dictionary:
	"""Get cost information from a recipe, resolving currency references"""
	var result = {}
	
	if recipe.has(cost_key):
		var currency_id = resolve_cost_reference(cost_key)
		result[currency_id] = recipe[cost_key]
	
	# Also include any material costs
	for key in recipe.keys():
		if key != cost_key and key != "input_amount" and key != "output_amount" and key != "description":
			result[key] = recipe[key]
	
	return result

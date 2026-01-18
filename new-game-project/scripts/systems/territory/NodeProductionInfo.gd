# scripts/systems/territory/NodeProductionInfo.gd
# Helper system for node production type information
extends Node
class_name NodeProductionInfo

"""
NodeProductionInfo.gd - Provides production type info for hex nodes
RULE 2: Single responsibility - ONLY loads and provides production type data
RULE 1: Under 500 lines

Loads data/node_production_types.json and provides:
- What category of tasks a node supports (gathering, crafting, etc.)
- Which god stats/traits are optimal for that node type
- Production focus description
"""

# ==============================================================================
# PROPERTIES
# ==============================================================================
var production_config: Dictionary = {}
var node_type_mapping: Dictionary = {}
var category_info: Dictionary = {}

# ==============================================================================
# INITIALIZATION
# ==============================================================================
func _ready() -> void:
	_load_production_config()

func initialize() -> void:
	"""SystemRegistry initialization"""
	_load_production_config()

func _load_production_config() -> void:
	"""Load production type configuration from JSON"""
	var config_path = "res://data/node_production_types.json"

	if not FileAccess.file_exists(config_path):
		push_error("NodeProductionInfo: Config file not found: " + config_path)
		return

	var file = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		push_error("NodeProductionInfo: Failed to open config file")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)

	if parse_result != OK:
		push_error("NodeProductionInfo: JSON parse error at line " + str(json.get_error_line()) + ": " + json.get_error_message())
		return

	production_config = json.data
	node_type_mapping = production_config.get("node_type_production_mapping", {})
	category_info = production_config.get("task_category_info", {})

	print("NodeProductionInfo: Loaded production data for %d node types, %d categories" % [node_type_mapping.size(), category_info.size()])

# ==============================================================================
# PUBLIC METHODS
# ==============================================================================
func get_node_production_category(node_type: String) -> String:
	"""Get the primary production category for a node type (gathering, crafting, etc.)"""
	var mapping = node_type_mapping.get(node_type, {})
	return mapping.get("primary_category", "")

func get_node_production_description(node_type: String) -> String:
	"""Get the description of what this node type produces"""
	var mapping = node_type_mapping.get(node_type, {})
	return mapping.get("description", "")

func get_node_production_focus(node_type: String) -> String:
	"""Get the production focus text (e.g., 'Ores, Gems, Stone')"""
	var mapping = node_type_mapping.get(node_type, {})
	return mapping.get("production_focus", "")

func get_node_optimal_stats(node_type: String) -> Array:
	"""Get the optimal god stats for this node type"""
	var mapping = node_type_mapping.get(node_type, {})
	return mapping.get("optimal_stats", [])

func get_node_optimal_traits(node_type: String) -> Array:
	"""Get the optimal god traits for this node type"""
	var mapping = node_type_mapping.get(node_type, {})
	return mapping.get("optimal_traits", [])

func get_node_icon(node_type: String) -> String:
	"""Get the emoji icon for this node type"""
	var mapping = node_type_mapping.get(node_type, {})
	return mapping.get("icon", "📦")

func get_category_name(category: String) -> String:
	"""Get the display name for a task category"""
	var info = category_info.get(category, {})
	return info.get("name", category.capitalize())

func get_category_description(category: String) -> String:
	"""Get the description for a task category"""
	var info = category_info.get(category, {})
	return info.get("description", "")

func get_category_color(category: String) -> Color:
	"""Get the color for a task category"""
	var info = category_info.get(category, {})
	var color_data = info.get("color", {"r": 0.7, "g": 0.7, "b": 0.7})
	return Color(color_data.get("r", 0.7), color_data.get("g", 0.7), color_data.get("b", 0.7))

func get_category_icon(category: String) -> String:
	"""Get the emoji icon for a task category"""
	var info = category_info.get(category, {})
	return info.get("icon", "📋")

func get_all_node_types() -> Array:
	"""Get all configured node types"""
	return node_type_mapping.keys()

func has_production_info(node_type: String) -> bool:
	"""Check if production info exists for a node type"""
	return node_type_mapping.has(node_type)

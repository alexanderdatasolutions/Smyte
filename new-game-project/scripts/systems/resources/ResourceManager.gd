# scripts/systems/resources/ResourceManager.gd
# Resource tracking and management - handles actual resource amounts and transactions
class_name ResourceManager extends Node

# Player's current resources
var player_resources: Dictionary = {}
var resource_limits: Dictionary = {}
var _resource_definitions: Dictionary = {}

# Event signals
signal resource_changed(resource_id: String, new_amount: int, delta: int)
signal resource_insufficient(resource_id: String, required: int, available: int)
signal resource_limit_reached(resource_id: String, limit: int)

func _ready() -> void:
	_load_resource_definitions()
	_load_resource_limits()

## Load resource definitions from resources.json for category lookups
func _load_resource_definitions() -> void:
	var file: FileAccess = FileAccess.open("res://data/resources.json", FileAccess.READ)
	if not file:
		return
	var json_text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(json_text)
	if parsed is Dictionary:
		_resource_definitions = parsed as Dictionary

## Initialize resource limits from configuration
func _load_resource_limits() -> void:
	resource_limits = {
		"guild_tokens": 50,
		"honor_points": 9999,
		"gold": -1,
		"mana": -1,
		"crystals": -1
	}
	# Override from resource definitions if available
	for section_key: String in _resource_definitions:
		var section: Variant = _resource_definitions[section_key]
		if section is Dictionary:
			for resource_id: String in section:
				if resource_id.begins_with("_"):
					continue
				var def: Variant = section[resource_id]
				if def is Dictionary:
					var max_storage: int = int(def.get("max_storage", -1))
					if max_storage > 0:
						resource_limits[resource_id] = max_storage

## Emit resource change to EventBus if available
func _emit_to_event_bus(resource_id: String, new_amount: int, delta: int) -> void:
	var registry: Variant = SystemRegistry.get_instance() if SystemRegistry else null
	if not registry:
		return
	var event_bus: Variant = registry.get_system("EventBus")
	if event_bus and event_bus.has_signal("resource_changed"):
		event_bus.resource_changed.emit(resource_id, new_amount, delta)

## Add resources to player inventory
func add_resource(resource_id: String, amount: int) -> bool:
	if amount <= 0:
		return false

	var current_amount: int = int(player_resources.get(resource_id, 0))
	var limit: int = int(resource_limits.get(resource_id, -1))

	# Check if adding would exceed limit
	if limit > 0:
		var new_total: int = current_amount + amount
		if new_total > limit:
			var actual_added: int = limit - current_amount
			if actual_added > 0:
				player_resources[resource_id] = limit
				resource_changed.emit(resource_id, limit, actual_added)
				resource_limit_reached.emit(resource_id, limit)
			return actual_added > 0

	# No limit or within limit
	var new_amount: int = current_amount + amount
	player_resources[resource_id] = new_amount

	resource_changed.emit(resource_id, new_amount, amount)
	_emit_to_event_bus(resource_id, new_amount, amount)

	return true

## Spend resources from player inventory
func spend(resource_id: String, amount: int) -> bool:
	if amount <= 0:
		return false

	var current_amount: int = int(player_resources.get(resource_id, 0))
	if current_amount < amount:
		resource_insufficient.emit(resource_id, amount, current_amount)
		return false

	var new_amount: int = current_amount - amount
	player_resources[resource_id] = new_amount

	resource_changed.emit(resource_id, new_amount, -amount)
	_emit_to_event_bus(resource_id, new_amount, -amount)

	return true

## Spend a single resource (alias for spend)
func spend_resource(resource_id: String, amount: int) -> bool:
	return spend(resource_id, amount)

## Check if player can afford a single resource cost
func can_spend(resource_id: String, amount: int) -> bool:
	var available: int = int(player_resources.get(resource_id, 0))
	return available >= amount

## Check if player can afford a cost dictionary
func can_afford(cost: Dictionary) -> bool:
	for resource_id: String in cost:
		var required: int = int(cost[resource_id])
		var available: int = int(player_resources.get(resource_id, 0))
		if available < required:
			return false
	return true

## Spend multiple resources at once
func spend_resources(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false

	for resource_id: String in cost:
		var amount: int = int(cost[resource_id])
		if not spend(resource_id, amount):
			push_error("ResourceManager: Failed to spend " + resource_id + " after affordability check")
			return false

	return true

## Get current amount of a resource
func get_resource(resource_id: String) -> int:
	return int(player_resources.get(resource_id, 0))

## Set resource to exact amount
func set_resource(resource_id: String, amount: int) -> void:
	var old_amount: int = int(player_resources.get(resource_id, 0))
	var delta: int = amount - old_amount

	player_resources[resource_id] = amount
	resource_changed.emit(resource_id, amount, delta)
	_emit_to_event_bus(resource_id, amount, delta)

## Get all player resources
func get_all_resources() -> Dictionary:
	return player_resources.duplicate()

## Get resource limit
func get_resource_limit(resource_id: String) -> int:
	return int(resource_limits.get(resource_id, -1))

## Check if resource has a limit
func has_limit(resource_id: String) -> bool:
	var limit: int = int(resource_limits.get(resource_id, -1))
	return limit > 0

## Check if resource is at limit
func is_at_limit(resource_id: String) -> bool:
	if not has_limit(resource_id):
		return false

	var current: int = get_resource(resource_id)
	var limit: int = get_resource_limit(resource_id)
	return current >= limit

## Get resource IDs that match a given category
func get_resources_by_category(category: String) -> Array:
	var result: Array = []
	for section_key: String in _resource_definitions:
		var section: Variant = _resource_definitions[section_key]
		if not section is Dictionary:
			continue
		for resource_id: String in section:
			if resource_id.begins_with("_"):
				continue
			var def: Variant = section[resource_id]
			if def is Dictionary and def.get("category", "") == category:
				result.append(resource_id)
	return result

## Award resources with limit checking
func award_resources(rewards: Dictionary) -> Dictionary:
	var actual_awards: Dictionary = {}

	for resource_id: String in rewards:
		var amount: int = int(rewards[resource_id])
		if add_resource(resource_id, amount):
			actual_awards[resource_id] = amount
		else:
			var current: int = get_resource(resource_id)
			var limit: int = get_resource_limit(resource_id)
			if has_limit(resource_id):
				actual_awards[resource_id] = maxi(0, limit - (current - amount))
			else:
				actual_awards[resource_id] = amount

	return actual_awards

## Load resources from save data
func load_from_save(save_data: Dictionary) -> void:
	if save_data.has("player_resources"):
		player_resources = save_data.get("player_resources", {}).duplicate()

		for resource_id: String in player_resources:
			var amount: int = int(player_resources[resource_id])
			resource_changed.emit(resource_id, amount, 0)

## Get save data
func get_save_data() -> Dictionary:
	return {
		"player_resources": player_resources.duplicate()
	}

## Load save data (SaveManager compatibility)
func load_save_data(save_data: Dictionary) -> void:
	load_from_save(save_data)

## Initialize resources for new game
func initialize_new_game() -> void:
	player_resources.clear()
	player_resources["gold"] = 10000
	player_resources["mana"] = 0
	player_resources["divine_crystals"] = 0

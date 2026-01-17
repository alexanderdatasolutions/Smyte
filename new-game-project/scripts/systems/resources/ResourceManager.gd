# scripts/systems/resources/ResourceManager.gd
# Resource tracking and management - handles actual resource amounts and transactions
class_name ResourceManager extends Node

# Player's current resources
var player_resources: Dictionary = {}
var resource_limits: Dictionary = {}

# Event signals
signal resource_changed(resource_id: String, new_amount: int, delta: int)
signal resource_insufficient(resource_id: String, required: int, available: int)
signal resource_limit_reached(resource_id: String, limit: int)

func _ready():
	_load_resource_limits()

## Initialize resource limits from configuration
func _load_resource_limits():
	# Load default limits - can be overridden by config files
	resource_limits = {
		"energy": 100,
		"arena_tokens": 30,
		"guild_tokens": 50,
		"honor_points": 9999,
		# Unlimited resources use -1
		"gold": -1,
		"mana": -1,
		"crystals": -1
	}

## Add resources to player inventory
func add_resource(resource_id: String, amount: int) -> bool:
	if amount <= 0:
		return false
	
	var current_amount = player_resources.get(resource_id, 0)
	var limit = resource_limits.get(resource_id, -1)
	
	# Check if adding would exceed limit
	if limit > 0:
		var new_total = current_amount + amount
		if new_total > limit:
			# Add up to limit
			var actual_added = limit - current_amount
			if actual_added > 0:
				player_resources[resource_id] = limit
				resource_changed.emit(resource_id, limit, actual_added)
				resource_limit_reached.emit(resource_id, limit)
			return actual_added > 0
	
	# No limit or within limit
	var new_amount = current_amount + amount
	player_resources[resource_id] = new_amount
	
	resource_changed.emit(resource_id, new_amount, amount)

	# Emit to EventBus if available
	var event_bus = SystemRegistry.get_instance().get_system("EventBus") if SystemRegistry.get_instance() else null
	if event_bus and event_bus.has_signal("resource_changed"):
		event_bus.resource_changed.emit(resource_id, new_amount, amount)

	return true

## Spend resources from player inventory
func spend(resource_id: String, amount: int) -> bool:
	if amount <= 0:
		return false
	
	var current_amount = player_resources.get(resource_id, 0)
	if current_amount < amount:
		resource_insufficient.emit(resource_id, amount, current_amount)
		return false
	
	var new_amount = current_amount - amount
	player_resources[resource_id] = new_amount
	
	resource_changed.emit(resource_id, new_amount, -amount)
	
	# Emit to EventBus if available
	var event_bus = SystemRegistry.get_instance().get_system("EventBus") if SystemRegistry.get_instance() else null
	if event_bus and event_bus.has_signal("resource_changed"):
		event_bus.resource_changed.emit(resource_id, new_amount, -amount)

	return true

## Check if player can afford a cost
func can_afford(cost: Dictionary) -> bool:
	for resource_id in cost:
		var required = cost[resource_id]
		var available = player_resources.get(resource_id, 0)
		if available < required:
			return false
	return true

## Spend multiple resources at once
func spend_resources(cost: Dictionary) -> bool:
	# First check if we can afford all costs
	if not can_afford(cost):
		return false
	
	# Spend each resource
	for resource_id in cost:
		var amount = cost[resource_id]
		if not spend(resource_id, amount):
			# This shouldn't happen if can_afford worked correctly
			push_error("ResourceManager: Failed to spend " + resource_id + " after affordability check")
			return false
	
	return true

## Get current amount of a resource
func get_resource(resource_id: String) -> int:
	return player_resources.get(resource_id, 0)

## Set resource to exact amount
func set_resource(resource_id: String, amount: int):
	var old_amount = player_resources.get(resource_id, 0)
	var delta = amount - old_amount
	
	player_resources[resource_id] = amount
	resource_changed.emit(resource_id, amount, delta)
	
	# Emit to EventBus if available
	var event_bus = SystemRegistry.get_instance().get_system("EventBus") if SystemRegistry.get_instance() else null
	if event_bus and event_bus.has_signal("resource_changed"):
		event_bus.resource_changed.emit(resource_id, amount, delta)

## Get all player resources
func get_all_resources() -> Dictionary:
	return player_resources.duplicate()

## Get resource limit
func get_resource_limit(resource_id: String) -> int:
	return resource_limits.get(resource_id, -1)

## Check if resource has a limit
func has_limit(resource_id: String) -> bool:
	var limit = resource_limits.get(resource_id, -1)
	return limit > 0

## Check if resource is at limit
func is_at_limit(resource_id: String) -> bool:
	if not has_limit(resource_id):
		return false
	
	var current = get_resource(resource_id)
	var limit = get_resource_limit(resource_id)
	return current >= limit

## Award resources with limit checking
func award_resources(rewards: Dictionary) -> Dictionary:
	var actual_awards = {}
	
	for resource_id in rewards:
		var amount = rewards[resource_id]
		if add_resource(resource_id, amount):
			actual_awards[resource_id] = amount
		else:
			# Calculate how much was actually added
			var current = get_resource(resource_id)
			var limit = get_resource_limit(resource_id)
			if has_limit(resource_id):
				actual_awards[resource_id] = max(0, limit - (current - amount))
			else:
				actual_awards[resource_id] = amount
	
	return actual_awards

## Load resources from save data
func load_from_save(save_data: Dictionary):
	if save_data.has("player_resources"):
		player_resources = save_data.player_resources.duplicate()

		# Emit change events for all resources
		for resource_id in player_resources:
			var amount = player_resources[resource_id]
			resource_changed.emit(resource_id, amount, 0)

## Get save data
func get_save_data() -> Dictionary:
	return {
		"player_resources": player_resources.duplicate()
	}

## Initialize resources for new game
func initialize_new_game():
	player_resources.clear()
	# Set starting resources for new players
	player_resources["gold"] = 10000
	player_resources["mana"] = 0
	player_resources["divine_crystals"] = 0
	player_resources["energy"] = 100

## Debug: Print all resources
func debug_print_resources():
	for resource_id in player_resources:
		var _amount = player_resources[resource_id]
		var _limit = get_resource_limit(resource_id)

## Debug: Add test resources
func debug_add_test_resources():
	add_resource("gold", 50000)
	add_resource("mana", 5000)
	add_resource("crystals", 500)
	add_resource("energy", 80)
	add_resource("arena_tokens", 15)

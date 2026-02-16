# scripts/systems/territory/TerritoryDefenseManager.gd
# Handles territory defense mechanics: garrison power, attack timers, capture rewards, node reveal
class_name TerritoryDefenseManager extends Node

signal node_unlocked(node_id: String, unlock_source: String)

var _territory_manager: Node = null

func initialize(territory_manager: Node) -> void:
	_territory_manager = territory_manager
	_connect_to_dungeon_coordinator()

# ==============================================================================
# GARRISON POWER AND DEFENSE
# ==============================================================================

## Calculate total combat power of gods in garrison
func calculate_garrison_power(node: HexNode) -> float:
	if not node or node.garrison.size() == 0:
		return 0.0

	var registry: Node = SystemRegistry.get_instance()
	var collection_manager: Node = registry.get_system("CollectionManager") if registry else null
	if not collection_manager:
		return 0.0

	var total_power: float = 0.0
	for god_id: String in node.garrison:
		var god_obj: God = collection_manager.get_god_by_id(god_id)
		if god_obj:
			var hp: int = god_obj.base_hp
			var attack: int = god_obj.base_attack
			var defense: int = god_obj.base_defense
			var speed: int = god_obj.base_speed
			var level: int = god_obj.level
			var awakening_bonus: float = 1.0 + (god_obj.ascension_level * 0.1)

			var god_power: float = (hp + attack * 2 + defense + speed) * (1.0 + level * 0.05) * awakening_bonus
			total_power += god_power

	return total_power

## Get minimum garrison power required for workers based on node tier
func get_min_garrison_power_for_tier(tier: int) -> int:
	match tier:
		1: return 500
		2: return 2000
		3: return 5000
		4: return 15000
		5: return 40000
		_: return 500

## Check if a node's garrison meets the minimum power requirement for workers
func can_assign_workers(node: HexNode) -> bool:
	if not node:
		return false
	if not node.is_controlled_by_player():
		return false

	var garrison_power: float = calculate_garrison_power(node)
	var required_power: int = get_min_garrison_power_for_tier(node.tier)
	return garrison_power >= required_power

## Get garrison power status for UI display
func get_garrison_worker_status(node: HexNode) -> Dictionary:
	if not node:
		return {"can_assign": false, "current": 0, "required": 0, "reason": "Invalid node"}

	var garrison_power: int = int(calculate_garrison_power(node))
	var required_power: int = get_min_garrison_power_for_tier(node.tier)
	var can_assign: bool = garrison_power >= required_power

	return {
		"can_assign": can_assign,
		"current": garrison_power,
		"required": required_power,
		"reason": "" if can_assign else "Garrison power too low (%d/%d)" % [garrison_power, required_power]
	}

## Calculate total defense rating for node including distance penalty
func get_node_defense_rating(coord: HexCoord) -> float:
	var hex_grid_manager: Node = _get_hex_grid_manager()
	if not hex_grid_manager:
		return 0.0

	var node: HexNode = hex_grid_manager.get_node_at(coord)
	if not node:
		return 0.0

	var base_defense: float = calculate_garrison_power(node)
	var defense_bonus: float = 1.0 + (node.defense_level - 1) * 0.1
	var distance_penalty: float = calculate_distance_penalty(coord)
	var connected_bonus: float = get_connected_bonus(coord)

	return base_defense * defense_bonus * (1.0 - distance_penalty) * (1.0 + connected_bonus)

## Calculate defense penalty based on distance from base (5% per hex)
func calculate_distance_penalty(coord: HexCoord) -> float:
	var hex_grid_manager: Node = _get_hex_grid_manager()
	if not hex_grid_manager:
		return 0.0

	var distance: int = hex_grid_manager.get_distance_from_base(coord)
	return min(distance * 0.05, 0.95)

## Calculate bonus from connected controlled nodes
func get_connected_bonus(coord: HexCoord) -> float:
	var hex_grid_manager: Node = _get_hex_grid_manager()
	if not hex_grid_manager:
		return 0.0

	var node: HexNode = hex_grid_manager.get_node_at(coord)
	if not node or not node.is_controlled_by_player():
		return 0.0

	var connected_count: int = _count_connected_nodes(coord, hex_grid_manager)

	if connected_count >= 4:
		return 0.30
	elif connected_count >= 3:
		return 0.20
	elif connected_count >= 2:
		return 0.10
	else:
		return 0.0

## Get count of adjacent controlled nodes
func get_connected_node_count(coord: HexCoord) -> int:
	var hex_grid_manager: Node = _get_hex_grid_manager()
	if not hex_grid_manager:
		return 0

	return _count_connected_nodes(coord, hex_grid_manager)

## Count adjacent controlled nodes (shared helper)
func _count_connected_nodes(coord: HexCoord, hex_grid_manager: Node) -> int:
	var neighbors: Array = hex_grid_manager.get_neighbors(coord)
	var connected_count: int = 0
	for neighbor_node: HexNode in neighbors:
		if neighbor_node.is_controlled_by_player():
			connected_count += 1
	return connected_count

# ==============================================================================
# ATTACK TIMER SYSTEM
# ==============================================================================

## Initialize the attack timer when a node is captured
func start_attack_timer(node: HexNode) -> void:
	if not node or not node.is_capturable:
		return

	if node.attack_timer_hours <= 0:
		node.attack_timer_remaining = -1.0
		return

	var max_seconds: float = node.attack_timer_hours * 3600.0
	node.attack_timer_remaining = max_seconds
	node.last_attack_check_time = int(Time.get_unix_time_from_system())

## Update attack timers for all player-controlled nodes
## Called periodically (e.g., every 60 seconds from TerritoryProductionManager)
func update_attack_timers() -> void:
	var current_time: int = int(Time.get_unix_time_from_system())

	var hex_grid_manager: Node = _get_hex_grid_manager()
	if not hex_grid_manager:
		return

	var player_nodes: Array = hex_grid_manager.get_player_nodes()
	var nodes_under_attack: Array = []

	for node: HexNode in player_nodes:
		if not node or not node.is_capturable:
			continue

		if node.attack_timer_remaining < 0:
			continue

		var time_elapsed: int = current_time - node.last_attack_check_time
		if time_elapsed <= 0:
			continue

		node.attack_timer_remaining -= time_elapsed
		node.last_attack_check_time = current_time

		if node.attack_timer_remaining <= 0:
			node.attack_timer_remaining = 0.0
			nodes_under_attack.append(node)

	for node: HexNode in nodes_under_attack:
		_handle_node_attack(node)

## Process an attack on a node when its timer expires
func _handle_node_attack(node: HexNode) -> void:
	if not node:
		return

	var event_bus: Node = _get_event_bus()

	if node.garrison.size() == 0:
		if event_bus:
			event_bus.emit_notification("Territory Lost: %s (No garrison!)" % [node.name if node.name else "Unknown"], "warning", 4.0)

		if _territory_manager:
			_territory_manager.lose_node(node.coord)
	else:
		if event_bus:
			event_bus.emit_notification("Territory Under Attack: %s" % [node.name if node.name else "Unknown"], "danger", 5.0)

## Reset a node's attack timer after a successful defense battle
func reset_attack_timer(node_id: String) -> void:
	var hex_grid_manager: Node = _get_hex_grid_manager()
	if not hex_grid_manager:
		return

	var node: HexNode = hex_grid_manager.get_node_by_id(node_id)
	if not node:
		return

	start_attack_timer(node)

# ==============================================================================
# CAPTURE REWARDS
# ==============================================================================

## Award crystal rewards for capturing territories (helps early game progression)
## Economy: 100 crystals = 1 summon, 900 crystals = 10x multi-summon
func award_capture_rewards(node: HexNode, territories_owned: int) -> void:
	var registry: Node = SystemRegistry.get_instance()
	var resource_manager: Node = registry.get_system("ResourceManager") if registry else null
	if not resource_manager:
		return

	var event_bus: Node = _get_event_bus()

	# Early game bonus: First 10 territories give bonus crystals
	# Goal: ~1000 crystals from first 10 territories (enough for one 10x multi-summon)
	var early_game_bonus: int = 0
	if territories_owned == 1:
		early_game_bonus = 300
	elif territories_owned <= 3:
		early_game_bonus = 200
	elif territories_owned <= 6:
		early_game_bonus = 100
	elif territories_owned <= 10:
		early_game_bonus = 50

	# Tier-based rewards (higher tier nodes = more crystals)
	var tier_reward: int = 0
	if node and node.tier:
		match node.tier:
			1: tier_reward = 10
			2: tier_reward = 25
			3: tier_reward = 50
			4: tier_reward = 100
			5: tier_reward = 200
			_: tier_reward = 10

	var total_crystals: int = early_game_bonus + tier_reward

	if total_crystals > 0:
		resource_manager.add_resource("divine_crystals", total_crystals)

		if event_bus:
			var msg: String = "+%d Divine Crystals" % total_crystals
			if early_game_bonus > 0:
				msg += " (Early Capture Bonus!)"
			event_bus.emit_notification(msg, "reward", 2.5)

## Reveal all adjacent nodes to a newly captured node
func reveal_adjacent_nodes(captured_node: HexNode) -> void:
	var hex_grid_manager: Node = _get_hex_grid_manager()
	if not hex_grid_manager or not captured_node:
		return

	var neighbors: Array = hex_grid_manager.get_neighbors(captured_node.coord)
	var newly_revealed: int = 0

	for neighbor: HexNode in neighbors:
		if neighbor and not neighbor.is_revealed:
			neighbor.is_revealed = true
			newly_revealed += 1

	if newly_revealed > 0:
		hex_grid_manager.grid_updated.emit()

# ==============================================================================
# DUNGEON COMPLETION INTEGRATION
# ==============================================================================

## Connect to DungeonCoordinator for dungeon completion events
func _connect_to_dungeon_coordinator() -> void:
	call_deferred("_deferred_connect_dungeon_coordinator")

func _deferred_connect_dungeon_coordinator() -> void:
	var system_registry: Node = SystemRegistry.get_instance()
	if not system_registry:
		return

	var dungeon_coordinator: Node = system_registry.get_system("DungeonCoordinator")
	if dungeon_coordinator and dungeon_coordinator.has_signal("dungeon_completed"):
		if not dungeon_coordinator.dungeon_completed.is_connected(_on_dungeon_completed):
			dungeon_coordinator.dungeon_completed.connect(_on_dungeon_completed)

## Handle dungeon completion event
func _on_dungeon_completed(dungeon_id: String, difficulty: String) -> void:
	var hex_grid_manager: Node = _get_hex_grid_manager()
	if not hex_grid_manager:
		return

	var all_nodes: Array = hex_grid_manager.get_all_nodes()
	for node: HexNode in all_nodes:
		if _check_node_dungeon_unlock(node, dungeon_id, difficulty):
			node_unlocked.emit(node.id, "%s_%s" % [dungeon_id, difficulty])

## Check if a node's dungeon unlock requirements are satisfied by this clear
func _check_node_dungeon_unlock(node: HexNode, dungeon_id: String, difficulty: String) -> bool:
	if not node or not node.unlock_requirements:
		return false

	var dungeon_clears: Array = node.unlock_requirements.get("dungeon_clears", [])
	if dungeon_clears.is_empty():
		return false

	for requirement: Variant in dungeon_clears:
		var req_dungeon: String = requirement.get("dungeon_id", "")
		var req_difficulty: String = requirement.get("difficulty", "")

		if req_dungeon == dungeon_id and req_difficulty == difficulty:
			return true

	return false

# ==============================================================================
# HELPERS
# ==============================================================================

func _get_hex_grid_manager() -> Node:
	var registry: Node = SystemRegistry.get_instance()
	return registry.get_system("HexGridManager") if registry else null

func _get_event_bus() -> Node:
	var registry: Node = SystemRegistry.get_instance()
	return registry.get_system("EventBus") if registry else null

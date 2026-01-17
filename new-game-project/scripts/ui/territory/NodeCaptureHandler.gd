# scripts/ui/territory/NodeCaptureHandler.gd
# Handles node capture battle flow
extends Node
class_name NodeCaptureHandler

"""
NodeCaptureHandler.gd - Handles territory node capture battles
RULE 2: Single responsibility - ONLY manages node capture flow
RULE 1: Under 500 lines
RULE 5: Uses SystemRegistry for all system access

Responsibilities:
- Initiate capture battles
- Create battle configs for territory capture
- Handle battle results (victory/defeat)
- Update node contested state
"""

# ==============================================================================
# SIGNALS
# ==============================================================================
signal capture_initiated(hex_node: HexNode)
signal capture_succeeded(hex_node: HexNode)
signal capture_failed(hex_node: HexNode)

# ==============================================================================
# PROPERTIES
# ==============================================================================
var current_capture_node: HexNode = null
var hex_map_view = null  # Reference to HexMapView for animations

# System references
var territory_manager = null
var collection_manager = null
var battle_coordinator = null
var screen_manager = null
var hex_grid_manager = null

# ==============================================================================
# INITIALIZATION
# ==============================================================================
func _ready() -> void:
	_init_systems()

func _init_systems() -> void:
	"""Initialize system references"""
	var registry = SystemRegistry.get_instance()
	if registry:
		territory_manager = registry.get_system("TerritoryManager")
		collection_manager = registry.get_system("CollectionManager")
		battle_coordinator = registry.get_system("BattleCoordinator")
		screen_manager = registry.get_system("ScreenManager")
		hex_grid_manager = registry.get_system("HexGridManager")

# ==============================================================================
# PUBLIC API
# ==============================================================================
func initiate_capture(hex_node: HexNode) -> bool:
	"""Initiate capture battle for the given node"""
	if not hex_node:
		return false

	# Create battle config
	var battle_config = _create_capture_battle_config(hex_node)
	if not battle_config:
		push_error("NodeCaptureHandler: Failed to create battle config")
		return false

	# Connect to battle result signal
	if battle_coordinator:
		if not battle_coordinator.battle_ended.is_connected(_on_capture_battle_ended):
			battle_coordinator.battle_ended.connect(_on_capture_battle_ended)

	# Store node being captured
	current_capture_node = hex_node

	# Emit signal
	capture_initiated.emit(hex_node)

	# Start the battle with the config (auto-selects first 4 available gods)
	if battle_coordinator:
		if not battle_coordinator.start_battle(battle_config):
			push_error("NodeCaptureHandler: Failed to start battle")
			return false

	# Navigate to battle screen
	if screen_manager:
		screen_manager.change_screen("battle")
		return true

	return false

# ==============================================================================
# BATTLE CONFIG CREATION
# ==============================================================================
func _create_capture_battle_config(hex_node: HexNode) -> BattleConfig:
	"""Create battle configuration for node capture"""
	# Get player's battle team
	var attacker_gods = _get_player_battle_team()
	if attacker_gods.is_empty():
		push_error("NodeCaptureHandler: No gods available for battle")
		return null

	# Get node defenders
	var defender_gods = _get_node_defenders(hex_node)

	# Create battle config
	var config = BattleConfig.new()
	config.battle_type = BattleConfig.BattleType.TERRITORY
	config.attacker_team = attacker_gods
	config.defender_team = defender_gods
	config.territory_id = hex_node.id
	config.max_turns = 50
	config.allow_auto_battle = true
	config.allow_speed_up = true
	config.victory_condition = "defeat_all_enemies"
	config.defeat_condition = "all_gods_defeated"

	# Store config in BattleCoordinator
	if battle_coordinator:
		battle_coordinator.current_battle_config = config

	return config

func _get_player_battle_team() -> Array:
	"""Get player's gods for battle team (first 4 eligible gods)"""
	if not collection_manager:
		return []

	var all_gods = collection_manager.get_all_gods()
	var battle_team = []

	for god in all_gods:
		# Filter out gods in garrison or working
		if not _is_god_available_for_battle(god.id):
			continue

		battle_team.append(god)
		if battle_team.size() >= 4:
			break

	return battle_team

func _is_god_available_for_battle(god_id: String) -> bool:
	"""Check if god is available (not in garrison or working)"""
	if not territory_manager:
		return true

	var controlled = territory_manager.get_controlled_nodes()
	for node in controlled:
		if node.garrison.has(god_id):
			return false
		if node.assigned_workers.has(god_id):
			return false

	return true

func _get_node_defenders(hex_node: HexNode) -> Array:
	"""Get defender gods from the node"""
	if not collection_manager:
		return []

	var defenders = []

	# For neutral nodes, use base_defenders
	if hex_node.controller == "neutral":
		for defender_id in hex_node.base_defenders:
			var defender = collection_manager.get_god_by_id(defender_id)
			if defender:
				defenders.append(defender)
	# For enemy nodes, use garrison
	else:
		for god_id in hex_node.garrison:
			var defender = collection_manager.get_god_by_id(god_id)
			if defender:
				defenders.append(defender)

	# If no defenders found, create a default enemy
	if defenders.is_empty():
		defenders.append(_create_default_defender(hex_node))

	return defenders

func _create_default_defender(hex_node: HexNode) -> Dictionary:
	"""Create a default defender based on node tier"""
	var defender = {
		"id": "default_defender_" + hex_node.id,
		"name": "Territory Guardian",
		"level": hex_node.tier * 5,
		"pantheon": "neutral",
		"element": "neutral",
		"base_hp": 1000 + (hex_node.tier * 500),
		"base_attack": 100 + (hex_node.tier * 50),
		"base_defense": 100 + (hex_node.tier * 40),
		"base_speed": 50 + (hex_node.tier * 10),
		"skills": []
	}
	return defender

# ==============================================================================
# BATTLE RESULT HANDLING
# ==============================================================================
func _on_capture_battle_ended(result: BattleResult) -> void:
	"""Handle capture battle result"""
	# Disconnect signal
	if battle_coordinator and battle_coordinator.battle_ended.is_connected(_on_capture_battle_ended):
		battle_coordinator.battle_ended.disconnect(_on_capture_battle_ended)

	# Check if victory
	if result.victory and current_capture_node:
		_handle_capture_victory(current_capture_node)
	else:
		_handle_capture_defeat()

	# Clear current capture node
	current_capture_node = null

func _handle_capture_victory(hex_node: HexNode) -> void:
	"""Handle successful capture of node"""
	if not territory_manager or not hex_grid_manager:
		return

	# Get the node from hex grid to update it
	var node = hex_grid_manager.get_node_at(hex_node.coord)
	if node:
		# Mark node as contested (claim after contest period)
		node.is_contested = true
		# Contest period: 5 minutes (300 seconds)
		node.contested_until = Time.get_unix_time_from_system() + 300
		node.controller = "player"  # Mark as contested by player

	# Capture the node in TerritoryManager
	territory_manager.capture_node(hex_node.coord)

	# Play capture animation
	if hex_map_view:
		hex_map_view.play_capture_animation(hex_node)

	# Emit success signal
	capture_succeeded.emit(hex_node)

	# Log success
	print("Victory! Node ", hex_node.name, " is now contested. Claim after contest period.")

func _handle_capture_defeat() -> void:
	"""Handle failed capture attempt"""
	if current_capture_node:
		capture_failed.emit(current_capture_node)

	print("Defeat! Failed to capture node.")

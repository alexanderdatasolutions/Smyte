# scripts/ui/screens/BattleSetupScreen.gd
# Clean replacement - orchestrates battle setup functionality using standardized GodCard component
extends Control

signal battle_setup_complete(context: Dictionary)
signal setup_cancelled

const GodCardFactory = preload("res://scripts/utilities/GodCardFactory.gd")

# Load the split components  
const BattleSetupCoordinatorScript = preload("res://scripts/ui/battle_setup/BattleSetupCoordinator.gd")

var setup_coordinator

func _ready():
	_setup_coordinator()

func _setup_coordinator():
	setup_coordinator = BattleSetupCoordinatorScript.new()
	add_child(setup_coordinator)
	
	setup_coordinator.battle_setup_complete.connect(_on_battle_setup_complete)
	setup_coordinator.setup_cancelled.connect(_on_setup_cancelled)

func setup_for_territory_battle(territory: Territory, stage: int):
	setup_coordinator.setup_for_territory_battle(territory, stage)

func setup_for_dungeon_battle(dungeon_id: String, difficulty: String):
	setup_coordinator.setup_for_dungeon_battle(dungeon_id, difficulty)

func setup_for_pvp_battle(opponent_data: Dictionary):
	setup_coordinator.setup_for_pvp_battle(opponent_data)

func setup_for_hex_node_capture(hex_node: HexNode):
	setup_coordinator.setup_for_hex_node_capture(hex_node)

func _on_battle_setup_complete(context: Dictionary):
	battle_setup_complete.emit(context)

func _on_setup_cancelled():
	setup_cancelled.emit()

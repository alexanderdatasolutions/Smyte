# BattleUICoordinator.gd - Orchestrates battle UI using clean architecture
# Replaces the 2,849-line BattleScreen god class with focused responsibility
class_name BattleUICoordinator extends Control

# System references through SystemRegistry 
var system_registry: SystemRegistry
var event_bus: EventBus
var battle_coordinator: BattleCoordinator
var wave_manager: WaveManager

# UI component managers
var display_manager  # BattleDisplayManager
var action_ui        # BattleActionUI  
var status_tracker   # BattleStatusTracker
var log_manager      # BattleLogManager
var controls_ui      # BattleControlsUI

# UI signals
signal back_pressed
signal battle_ui_ready

func _ready():
	"""Initialize battle UI coordinator with new architecture"""
	_connect_to_systems()
	_create_ui_components()
	_setup_event_listeners()
	battle_ui_ready.emit()

func _connect_to_systems():
	"""Connect to game systems through SystemRegistry"""
	system_registry = SystemRegistry.get_instance()
	if not system_registry:
		push_error("BattleUICoordinator: SystemRegistry not found")
		return
	
	# Get systems through registry
	event_bus = system_registry.get_system("EventBus")
	battle_coordinator = system_registry.get_system("BattleCoordinator") 
	wave_manager = system_registry.get_system("WaveManager")
	
	print("BattleUICoordinator: Connected to systems")

func _create_ui_components():
	"""Create focused UI component managers"""
	var BattleDisplayManager = preload("res://scripts/ui/battle/BattleDisplayManager.gd")
	var BattleActionUI = preload("res://scripts/ui/battle/BattleActionUI.gd")
	var BattleStatusTracker = preload("res://scripts/ui/battle/BattleStatusTracker.gd")
	var BattleLogManager = preload("res://scripts/ui/battle/BattleLogManager.gd")
	var BattleControlsUI = preload("res://scripts/ui/battle/BattleControlsUI.gd")
	
	display_manager = BattleDisplayManager.new()
	action_ui = BattleActionUI.new()
	status_tracker = BattleStatusTracker.new()
	log_manager = BattleLogManager.new()
	controls_ui = BattleControlsUI.new()
	
	# Add components to scene tree
	add_child(display_manager)
	add_child(action_ui)
	add_child(status_tracker)
	add_child(log_manager)
	add_child(controls_ui)
	
	print("BattleUICoordinator: UI components created")

func _setup_event_listeners():
	"""Listen to battle events through EventBus"""
	if not event_bus:
		return
		
	# Battle flow events
	event_bus.battle_started.connect(_on_battle_started)
	event_bus.battle_ended.connect(_on_battle_ended)
	event_bus.turn_started.connect(_on_turn_started)
	event_bus.damage_dealt.connect(_on_damage_dealt)
	
	# Component events
	action_ui.action_selected.connect(_on_action_selected)
	controls_ui.back_pressed.connect(_on_back_pressed)
	controls_ui.auto_battle_toggled.connect(_on_auto_battle_toggled)
	
	print("BattleUICoordinator: Event listeners setup")

## Public interface for starting battles

func start_dungeon_battle(dungeon_id: String, difficulty: String, selected_gods: Array):
	"""Start a dungeon battle with the new architecture"""
	if not battle_coordinator:
		push_error("BattleUICoordinator: No BattleCoordinator available")
		return false
	
	# Create BattleConfig using the proper data class
	var config = BattleConfig.new()
	config.battle_type = BattleConfig.BattleType.DUNGEON
	config.attacker_team = selected_gods
	config.dungeon_id = dungeon_id
	config.difficulty = difficulty
	
	# Start battle through coordinator
	return battle_coordinator.start_battle(config)

func start_territory_battle(territory, stage: int, selected_gods: Array):
	"""Start a territory battle with the new architecture"""
	if not battle_coordinator:
		push_error("BattleUICoordinator: No BattleCoordinator available")
		return false
	
	var config = BattleConfig.new()
	config.battle_type = BattleConfig.BattleType.TERRITORY
	config.attacker_team = selected_gods
	config.battle_territory = territory
	config.battle_stage = stage
	
	return battle_coordinator.start_battle(config)

## Event handlers

func _on_battle_started(config):
	"""Handle battle started - coordinate UI updates"""
	display_manager.create_battle_displays(config.attacker_team, config.defender_team)
	status_tracker.initialize_tracking(config.attacker_team, config.defender_team)
	log_manager.clear_log()
	controls_ui.enable_battle_controls()

func _on_battle_ended(_result):
	"""Handle battle ended - show results"""
	controls_ui.disable_battle_controls()
	# Victory screen will be handled by BattleVictoryScreen component
	
func _on_turn_started(unit):
	"""Handle turn started - update displays"""
	display_manager.highlight_active_unit(unit)
	if _is_player_unit(unit):
		action_ui.show_action_options(unit)
	else:
		action_ui.hide_action_options()

func _on_damage_dealt(attacker, target, damage):
	"""Handle damage dealt - update displays"""
	status_tracker.update_unit_hp(target)
	log_manager.add_damage_log(attacker, target, damage)

func _on_action_selected(unit, action):
	"""Handle action selected - send to battle system"""
	# Create proper BattleAction for the new architecture
	var battle_action = BattleAction.new()
	battle_action.caster = unit
	battle_action.action_type = action.type
	battle_action.targets = action.targets
	
	# Send to battle coordinator
	if battle_coordinator:
		battle_coordinator.process_action(battle_action)

func _on_back_pressed():
	"""Handle back button pressed"""
	back_pressed.emit()

func _on_auto_battle_toggled(enabled: bool):
	"""Handle auto battle toggle"""
	if battle_coordinator:
		battle_coordinator.set_auto_battle(enabled)

## Helper methods

func _is_player_unit(unit) -> bool:
	"""Check if unit belongs to player"""
	return unit is God  # Gods are player units, dictionaries are enemies

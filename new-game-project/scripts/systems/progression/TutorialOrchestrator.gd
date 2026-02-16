# scripts/systems/progression/TutorialOrchestrator.gd
extends Node
class_name TutorialOrchestrator

# ==============================================================================
# TUTORIAL ORCHESTRATOR - Tutorial flow management (200 lines max)
# ==============================================================================
# Handles tutorial progression following CLEAN ARCHITECTURE
# Single responsibility: Orchestrate tutorial flow and unlock features

signal tutorial_started(tutorial_name: String)
signal tutorial_completed(tutorial_name: String) 
signal tutorial_step_completed(tutorial_name: String, step: int)
signal feature_unlocked(feature_name: String)

# Tutorial state
var current_tutorial: String = ""
var current_step: int = 0
var tutorial_active: bool = false
var completed_tutorials: Array[String] = []

# Cached system references
var _save_manager: Node = null
var _event_bus: Node = null
var _progression_manager: Node = null

# Tutorial definitions - simple and focused
# NOTE: Feature unlocking is handled by AchievementManager, not tutorials
# Tutorials only introduce features, they don't unlock them
var tutorial_steps: Dictionary = {
	"first_time_user": [
		{"type": "welcome", "feature": "territories"},
		{"type": "summon_tutorial", "feature": "summon"},
		{"type": "battle_tutorial", "feature": "battle"}
		# sacrifice is unlocked by "first_territory" achievement, not tutorial
	],
	"hex_territory_intro": [
		{"type": "hex_map_intro", "feature": "hex_territory"},
		{"type": "hex_node_selection", "feature": "hex_territory"},
		{"type": "hex_node_capture", "feature": "hex_territory"}
	],
	"hex_specialization_unlock": [
		{"type": "spec_unlock_tier2", "feature": "hex_territory"}
	]
}

func _ready() -> void:
	_cache_system_references()

func _cache_system_references() -> void:
	var registry: Node = SystemRegistry.get_instance()
	if not registry:
		return
	_save_manager = registry.get_system("SaveManager")
	_event_bus = registry.get_system("EventBus")
	_progression_manager = registry.get_system("PlayerProgressionManager")

# ==============================================================================
# MAIN TUTORIAL FLOW - SystemRegistry Pattern
# ==============================================================================

func start_tutorial(tutorial_name: String) -> bool:
	if tutorial_active or tutorial_name in completed_tutorials:
		return false
	
	if not tutorial_steps.has(tutorial_name):
		return false
	
	current_tutorial = tutorial_name
	current_step = 0
	tutorial_active = true
	
	tutorial_started.emit(tutorial_name)
	_process_current_step()
	return true

func advance_tutorial() -> bool:
	if not tutorial_active:
		return false
	
	tutorial_step_completed.emit(current_tutorial, current_step)
	current_step += 1
	
	if current_step >= tutorial_steps[current_tutorial].size():
		_complete_tutorial()
		return false
	
	_process_current_step()
	return true

func _process_current_step() -> void:
	var steps: Array = tutorial_steps[current_tutorial]
	var step_data: Dictionary = steps[current_step]

	match step_data.type:
		"welcome":
			_show_welcome_dialog()
		"summon_tutorial":
			_unlock_summon_feature()
		"battle_tutorial":
			_unlock_battle_feature()
		"sacrifice_tutorial":
			_unlock_sacrifice_feature()
		"hex_map_intro":
			_show_hex_map_intro_dialog()
		"hex_node_selection":
			_show_hex_node_selection_dialog()
		"hex_node_capture":
			_show_hex_node_capture_dialog()
		"spec_unlock_tier2":
			_show_spec_unlock_tier2_dialog()

func _complete_tutorial() -> void:
	completed_tutorials.append(current_tutorial)
	tutorial_completed.emit(current_tutorial)

	if _save_manager:
		_save_manager.save_game()

	tutorial_active = false
	current_tutorial = ""
	current_step = 0

# ==============================================================================
# FEATURE UNLOCKING - Clean separation
# ==============================================================================

func _unlock_summon_feature() -> void:
	if _progression_manager:
		_progression_manager.unlock_feature("summon")
	feature_unlocked.emit("summon")

func _unlock_battle_feature() -> void:
	if _progression_manager:
		_progression_manager.unlock_feature("battle")
	feature_unlocked.emit("battle")

func _unlock_sacrifice_feature() -> void:
	if _progression_manager:
		_progression_manager.unlock_feature("sacrifice")
	feature_unlocked.emit("sacrifice")

func _show_welcome_dialog() -> void:
	var registry: Node = SystemRegistry.get_instance()
	if not registry:
		return
	var ui_manager: Node = registry.get_system("UICoordinator")
	if ui_manager:
		ui_manager.show_tutorial_dialog({
			"title": "Welcome to the Game!",
			"message": "Let's start your journey...",
			"step": current_step
		})

# ==============================================================================
# TUTORIAL STATE MANAGEMENT
# ==============================================================================

func is_tutorial_active() -> bool:
	return tutorial_active

func is_tutorial_completed(tutorial_name: String) -> bool:
	return tutorial_name in completed_tutorials

func get_current_tutorial_info() -> Dictionary:
	if not tutorial_active:
		return {}
	
	return {
		"name": current_tutorial,
		"step": current_step,
		"total_steps": tutorial_steps[current_tutorial].size()
	}

func should_show_tutorial() -> bool:
	if not _progression_manager:
		return true
	return _progression_manager.get_player_level() == 1 and not is_tutorial_completed("first_time_user")

func skip_tutorial() -> void:
	if tutorial_active:
		_complete_tutorial()

# ==============================================================================
# HEX TERRITORY TUTORIALS
# ==============================================================================

func _show_hex_map_intro_dialog() -> void:
	if _event_bus:
		_event_bus.show_tutorial_requested.emit({
			"title": "Welcome to the Hex Territory Map!",
			"message": "This is your divine empire. Each hex represents a territory you can conquer.\n\n" +
			"• Green hexes are yours\n" +
			"• Gray hexes are neutral\n" +
			"• Red hexes are enemies\n\n" +
			"Use the zoom controls (+/-) and drag to explore. Click a hex to see details.",
			"button_text": "Got it!"
		})

func _show_hex_node_selection_dialog() -> void:
	if _event_bus:
		_event_bus.show_tutorial_requested.emit({
			"title": "Selecting Territories",
			"message": "Click any hex to view its details:\n\n" +
			"• Production resources\n" +
			"• Defense rating\n" +
			"• Garrison and workers\n" +
			"• Unlock requirements\n\n" +
			"Neutral territories can be captured. Enemy territories can be raided!",
			"button_text": "Continue"
		})

func _show_hex_node_capture_dialog() -> void:
	if _event_bus:
		_event_bus.show_tutorial_requested.emit({
			"title": "Capturing Territories",
			"message": "To capture a territory, you need:\n\n" +
			"• Required player level\n" +
			"• Required specialization tier\n" +
			"• Enough combat power\n\n" +
			"Higher tier nodes (★★★★★) require advanced specializations. " +
			"Connect territories for production bonuses!",
			"button_text": "Let's do this!"
		})

func _show_spec_unlock_tier2_dialog() -> void:
	if _event_bus:
		_event_bus.show_tutorial_requested.emit({
			"title": "Specialization Unlocked!",
			"message": "Congratulations! You've unlocked a Tier 2 specialization.\n\n" +
			"This allows you to:\n" +
			"• Capture Tier 2 nodes (★★)\n" +
			"• Get +100% efficiency bonuses\n" +
			"• Access rare resources\n\n" +
			"Keep leveling and specializing to unlock Tier 3, 4, and 5 territories!",
			"button_text": "Awesome!"
		})

# ==============================================================================
# SAVE/LOAD INTEGRATION
# ==============================================================================

func get_tutorial_save_data() -> Dictionary:
	return {
		"completed_tutorials": completed_tutorials,
		"current_tutorial": current_tutorial if tutorial_active else "",
		"current_step": current_step if tutorial_active else 0
	}

func load_tutorial_save_data(data: Dictionary) -> void:
	var raw_tutorials: Array = data.get("completed_tutorials", [])
	completed_tutorials.clear()
	for t: Variant in raw_tutorials:
		if t is String:
			completed_tutorials.append(t)

	var saved_tutorial: String = data.get("current_tutorial", "")
	if not saved_tutorial.is_empty():
		current_tutorial = saved_tutorial
		current_step = int(data.get("current_step", 0))
		tutorial_active = true

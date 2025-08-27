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
var completed_tutorials: Array = []

# Tutorial definitions - simple and focused
var tutorial_steps: Dictionary = {
	"first_time_user": [
		{"type": "welcome", "feature": "territories"},
		{"type": "summon_tutorial", "feature": "summon"},
		{"type": "battle_tutorial", "feature": "battle"},
		{"type": "sacrifice_tutorial", "feature": "sacrifice"}
	]
}

func _ready():
	print("TutorialOrchestrator: Tutorial system ready")

# ==============================================================================
# MAIN TUTORIAL FLOW - SystemRegistry Pattern
# ==============================================================================

func start_tutorial(tutorial_name: String) -> bool:
	"""Start a tutorial sequence"""
	if tutorial_active or tutorial_name in completed_tutorials:
		return false
	
	if not tutorial_steps.has(tutorial_name):
		print("TutorialOrchestrator: Unknown tutorial: %s" % tutorial_name)
		return false
	
	current_tutorial = tutorial_name
	current_step = 0
	tutorial_active = true
	
	tutorial_started.emit(tutorial_name)
	_process_current_step()
	return true

func advance_tutorial() -> bool:
	"""Advance to next tutorial step"""
	if not tutorial_active:
		return false
	
	tutorial_step_completed.emit(current_tutorial, current_step)
	current_step += 1
	
	if current_step >= tutorial_steps[current_tutorial].size():
		_complete_tutorial()
		return false
	
	_process_current_step()
	return true

func _process_current_step():
	"""Process the current tutorial step"""
	var steps = tutorial_steps[current_tutorial]
	var step_data = steps[current_step]
	
	match step_data.type:
		"welcome":
			_show_welcome_dialog()
		"summon_tutorial":
			_unlock_summon_feature()
		"battle_tutorial":
			_unlock_battle_feature()
		"sacrifice_tutorial":
			_unlock_sacrifice_feature()

func _complete_tutorial():
	"""Complete the current tutorial"""
	completed_tutorials.append(current_tutorial)
	tutorial_completed.emit(current_tutorial)
	
	# Save completion state
	var save_manager = SystemRegistry.get_instance().get_system("SaveManager")
	if save_manager:
		save_manager.save_tutorial_progress(completed_tutorials)
	
	tutorial_active = false
	current_tutorial = ""
	current_step = 0

# ==============================================================================
# FEATURE UNLOCKING - Clean separation
# ==============================================================================

func _unlock_summon_feature():
	"""Unlock summon feature"""
	var progression_mgr = SystemRegistry.get_instance().get_system("PlayerProgressionManager")
	if progression_mgr:
		progression_mgr.unlock_feature("summon")
	
	feature_unlocked.emit("summon")

func _unlock_battle_feature():
	"""Unlock battle feature"""
	var progression_mgr = SystemRegistry.get_instance().get_system("PlayerProgressionManager")
	if progression_mgr:
		progression_mgr.unlock_feature("battle")
	
	feature_unlocked.emit("battle")

func _unlock_sacrifice_feature():
	"""Unlock sacrifice feature"""
	var progression_mgr = SystemRegistry.get_instance().get_system("PlayerProgressionManager")
	if progression_mgr:
		progression_mgr.unlock_feature("sacrifice")
	
	feature_unlocked.emit("sacrifice")

func _show_welcome_dialog():
	"""Show welcome dialog through UI system"""
	var ui_manager = SystemRegistry.get_instance().get_system("UICoordinator")
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
	"""Check if tutorial is currently active"""
	return tutorial_active

func is_tutorial_completed(tutorial_name: String) -> bool:
	"""Check if specific tutorial is completed"""
	return tutorial_name in completed_tutorials

func get_current_tutorial_info() -> Dictionary:
	"""Get current tutorial information"""
	if not tutorial_active:
		return {}
	
	return {
		"name": current_tutorial,
		"step": current_step,
		"total_steps": tutorial_steps[current_tutorial].size()
	}

func should_show_tutorial() -> bool:
	"""Determine if player should see tutorial"""
	var player_progression = SystemRegistry.get_instance().get_system("PlayerProgressionManager")
	if not player_progression:
		return true
	
	# Show tutorial for new players (level 1 with no unlocked features)
	return player_progression.get_player_level() == 1 and not is_tutorial_completed("first_time_user")

func skip_tutorial():
	"""Skip current tutorial"""
	if tutorial_active:
		_complete_tutorial()

# ==============================================================================
# SAVE/LOAD INTEGRATION
# ==============================================================================

func get_tutorial_save_data() -> Dictionary:
	"""Get tutorial data for saving"""
	return {
		"completed_tutorials": completed_tutorials,
		"current_tutorial": current_tutorial if tutorial_active else "",
		"current_step": current_step if tutorial_active else 0
	}

func load_tutorial_save_data(data: Dictionary):
	"""Load tutorial data from save"""
	completed_tutorials = data.get("completed_tutorials", [])
	
	if data.has("current_tutorial") and data.current_tutorial != "":
		current_tutorial = data.current_tutorial
		current_step = data.get("current_step", 0)
		tutorial_active = true

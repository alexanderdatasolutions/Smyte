# scripts/ui/components/DebugOverlay.gd
extends Control
class_name DebugOverlay

# ==============================================================================
# DEBUG OVERLAY - Development Testing Tools
# ==============================================================================

# Untyped to avoid parse-time class resolution issues
var progression_manager  # PlayerProgressionManager
var tutorial_manager  # TutorialOrchestrator
var player_level_info_label: Label
var debug_panel_visible: bool = false

func _get_system_registry():
	var registry_script = load("res://scripts/systems/core/SystemRegistry.gd")
	if registry_script and registry_script.has_method("get_instance"):
		return registry_script.get_instance()
	return null

func _ready() -> void:
	visible = false
	player_level_info_label = $DebugPanel/VBoxContainer/ProgressionSection/PlayerLevelInfo

func _ensure_managers() -> void:
	if progression_manager and tutorial_manager:
		return
	var registry = _get_system_registry()
	if not registry:
		return
	if not progression_manager:
		progression_manager = registry.get_system("PlayerProgressionManager")
	if not tutorial_manager:
		tutorial_manager = registry.get_system("TutorialOrchestrator")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		toggle_debug_panel()

func toggle_debug_panel() -> void:
	debug_panel_visible = !debug_panel_visible
	visible = debug_panel_visible
	if debug_panel_visible:
		_ensure_managers()
		_update_display()

func _update_display() -> void:
	if not player_level_info_label:
		return

	var text_parts: Array[String] = []

	# Progression info
	if progression_manager:
		var level: int = progression_manager.get_player_level()
		var xp: int = progression_manager.get_player_experience()
		var xp_next: int = progression_manager.get_xp_for_next_level()
		text_parts.append("Level: %d | XP: %d (need %d)" % [level, xp, xp_next])
	else:
		text_parts.append("Level: (no progression manager)")

	# God count
	var registry = _get_system_registry()
	if registry:
		var collection_manager = registry.get_system("CollectionManager")
		if collection_manager:
			text_parts.append("Gods: %d" % collection_manager.gods.size())

	# Tutorial state
	if tutorial_manager:
		var info: Dictionary = tutorial_manager.get_current_tutorial_info()
		var tutorial_name: String = info.get("tutorial_name", "none")
		var active: bool = tutorial_manager.is_tutorial_active()
		text_parts.append("Tutorial: %s (%s)" % [tutorial_name, "active" if active else "inactive"])

	player_level_info_label.text = "\n".join(text_parts)

# ==============================================================================
# PROGRESSION DEBUG FUNCTIONS
# ==============================================================================

func _on_add_xp_100_pressed() -> void:
	_ensure_managers()
	if progression_manager:
		progression_manager.add_experience(100)
		_update_display()

func _on_add_xp_500_pressed() -> void:
	_ensure_managers()
	if progression_manager:
		progression_manager.add_experience(500)
		_update_display()

func _on_add_xp_1000_pressed() -> void:
	_ensure_managers()
	if progression_manager:
		progression_manager.add_experience(1000)
		_update_display()

func _on_set_level_5_pressed() -> void:
	_debug_set_level(5)

func _on_set_level_10_pressed() -> void:
	_debug_set_level(10)

func _on_max_level_pressed() -> void:
	_debug_set_level(PlayerProgressionManager.MAX_PLAYER_LEVEL)

func _debug_set_level(target_level: int) -> void:
	_ensure_managers()
	if not progression_manager:
		return
	# Calculate total XP needed to reach target level
	var total_xp: int = 0
	for i in range(1, target_level):
		total_xp += int(PlayerProgressionManager.XP_BASE_AMOUNT * pow(PlayerProgressionManager.XP_SCALING_FACTOR, i - 1))
	# Set state directly (debug only)
	progression_manager.current_experience = total_xp
	progression_manager.current_player_level = target_level
	_update_display()

# ==============================================================================
# TUTORIAL DEBUG FUNCTIONS
# ==============================================================================

func _on_start_ftue_pressed() -> void:
	_ensure_managers()
	if tutorial_manager:
		tutorial_manager.start_tutorial("first_time_experience")

func _on_reset_tutorials_pressed() -> void:
	_ensure_managers()
	if tutorial_manager:
		tutorial_manager.load_tutorial_save_data({})
		_update_display()

func _on_test_3_gods_pressed() -> void:
	var registry = _get_system_registry()
	if not registry:
		return
	var summon_manager = registry.get_system("SummonManager")
	if summon_manager and summon_manager.has_method("perform_summon"):
		for i in range(3):
			summon_manager.perform_summon("standard")
	_update_display()

func _on_show_god_count_pressed() -> void:
	_update_display()

# ==============================================================================
# RESOURCE DEBUG FUNCTIONS
# ==============================================================================

func _on_add_mana_pressed() -> void:
	var registry = _get_system_registry()
	if not registry:
		return
	var resource_manager = registry.get_system("ResourceManager")
	if resource_manager:
		resource_manager.add_resource("mana", 10000)

func _on_add_crystals_pressed() -> void:
	var registry = _get_system_registry()
	if not registry:
		return
	var resource_manager = registry.get_system("ResourceManager")
	if resource_manager:
		resource_manager.add_resource("divine_crystals", 100)

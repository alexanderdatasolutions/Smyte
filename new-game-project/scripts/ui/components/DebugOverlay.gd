# scripts/ui/DebugOverlay.gd
extends Control
class_name DebugOverlay

# ==============================================================================
# DEBUG OVERLAY - Development Testing Tools
# ==============================================================================
# Following MYTHOS ARCHITECTURE for clean debug tools to test progression system

var progression_manager: PlayerProgressionManager
var tutorial_manager: TutorialOrchestrator
var player_level_info_label: Label

var debug_panel_visible: bool = false

func _ready():
	"""Initialize debug overlay"""
	# Hide by default
	visible = false

	# Get system references through SystemRegistry (not implemented yet)
	progression_manager = null
	tutorial_manager = null

	# Get UI references
	player_level_info_label = $DebugPanel/VBoxContainer/ProgressionSection/PlayerLevelInfo

	# Update display
	_update_display()

func _input(event):
	"""Handle debug input"""
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		toggle_debug_panel()

func toggle_debug_panel():
	"""Toggle debug panel visibility"""
	debug_panel_visible = !debug_panel_visible
	visible = debug_panel_visible

	if debug_panel_visible:
		_update_display()

func _update_display():
	"""Update debug information display"""
	if not progression_manager or not player_level_info_label:
		return
	
	var debug_info = progression_manager.get_debug_info()
	var current_level = debug_info.get("current_level", 1)
	var current_xp = debug_info.get("current_xp", 0)
	var xp_to_next = debug_info.get("xp_to_next", 100)
	
	# Show progression info
	player_level_info_label.text = "Level: %d | XP: %d/%d" % [current_level, current_xp, xp_to_next + current_xp]
	
	# Show god count if available
	var collection_manager = SystemRegistry.get_instance().get_system("CollectionManager") if SystemRegistry.get_instance() else null
	if collection_manager:
		var god_count = collection_manager.gods.size()
		player_level_info_label.text += "\nGods: %d" % god_count
		
		# Show tutorial state if available
		if tutorial_manager:
			var tutorial_info = tutorial_manager.get_debug_info()
			var current_tutorial = tutorial_info.get("current_tutorial", "none")
			var tutorial_active = tutorial_info.get("tutorial_active", false)
			player_level_info_label.text += "\nTutorial: %s (%s)" % [current_tutorial, "active" if tutorial_active else "inactive"]

# ==============================================================================
# PROGRESSION DEBUG FUNCTIONS
# ==============================================================================

func _on_add_xp_100_pressed():
	"""Add 100 XP for testing"""
	if progression_manager:
		progression_manager.debug_add_experience(100)
		_update_display()

func _on_add_xp_500_pressed():
	"""Add 500 XP for testing"""
	if progression_manager:
		progression_manager.debug_add_experience(500)
		_update_display()

func _on_add_xp_1000_pressed():
	"""Add 1000 XP for testing"""
	if progression_manager:
		progression_manager.debug_add_experience(1000)
		_update_display()

func _on_set_level_5_pressed():
	"""Set player level to 5 for testing"""
	if progression_manager:
		progression_manager.debug_set_level(5)
		_update_display()

func _on_set_level_10_pressed():
	"""Set player level to 10 for testing"""
	if progression_manager:
		progression_manager.debug_set_level(10)
		_update_display()

func _on_max_level_pressed():
	"""Set player to max level for testing"""
	if progression_manager:
		progression_manager.debug_set_level(50)
		_update_display()

# ==============================================================================
# TUTORIAL DEBUG FUNCTIONS
# ==============================================================================

func _on_start_ftue_pressed():
	"""Start First Time User Experience for testing"""
	if tutorial_manager:
		tutorial_manager.start_tutorial("first_time_experience")

# ==============================================================================
# RESOURCE DEBUG FUNCTIONS
# ==============================================================================

func _on_add_mana_pressed():
	"""Add 10,000 mana for testing"""
	var resource_manager = SystemRegistry.get_instance().get_system("ResourceManager") if SystemRegistry.get_instance() else null
	if resource_manager:
		resource_manager.add_resource("mana", 10000)

func _on_add_crystals_pressed():
	"""Add 100 crystals for testing"""
	var resource_manager = SystemRegistry.get_instance().get_system("ResourceManager") if SystemRegistry.get_instance() else null
	if resource_manager:
		resource_manager.add_resource("divine_crystals", 100)

# scripts/ui/DebugOverlay.gd
extends Control
class_name DebugOverlay

# ==============================================================================
# DEBUG OVERLAY - Development Testing Tools
# ==============================================================================
# Following MYTHOS ARCHITECTURE for clean debug tools to test progression system

var progression_manager: ProgressionManager
var tutorial_manager: TutorialManager
var player_level_info_label: Label

var debug_panel_visible: bool = false

func _ready():
	"""Initialize debug overlay"""
	print("DebugOverlay: Initializing debug tools...")
	
	# Hide by default
	visible = false
	
	# Get system references
	progression_manager = GameManager.progression_manager if GameManager else null
	tutorial_manager = GameManager.tutorial_manager if GameManager else null
	
	# Get UI references
	player_level_info_label = $DebugPanel/VBoxContainer/ProgressionSection/PlayerLevelInfo
	
	# Update display
	_update_display()
	
	print("DebugOverlay: Debug tools ready - Press F1 to toggle")

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
		print("🐛 Debug Panel: SHOWN")
	else:
		print("🐛 Debug Panel: HIDDEN")

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
	if GameManager and GameManager.player_data:
		var god_count = GameManager.player_data.gods.size()
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
		print("🎯 Added 100 XP")

func _on_add_xp_500_pressed():
	"""Add 500 XP for testing"""
	if progression_manager:
		progression_manager.debug_add_experience(500)
		_update_display()
		print("🎯 Added 500 XP")

func _on_add_xp_1000_pressed():
	"""Add 1000 XP for testing"""
	if progression_manager:
		progression_manager.debug_add_experience(1000)
		_update_display()
		print("🎯 Added 1000 XP")

func _on_set_level_5_pressed():
	"""Set player level to 5 for testing"""
	if progression_manager:
		progression_manager.debug_set_level(5)
		_update_display()
		print("🎯 Set level to 5")

func _on_set_level_10_pressed():
	"""Set player level to 10 for testing"""
	if progression_manager:
		progression_manager.debug_set_level(10)
		_update_display()
		print("🎯 Set level to 10")

func _on_max_level_pressed():
	"""Set player to max level for testing"""
	if progression_manager:
		progression_manager.debug_set_level(50)
		_update_display()
		print("🎯 Set level to MAX (50)")

# ==============================================================================
# TUTORIAL DEBUG FUNCTIONS
# ==============================================================================

func _on_reset_tutorials_pressed():
	"""Reset all tutorials for testing"""
	if tutorial_manager:
		tutorial_manager.debug_reset_tutorials()
		
		# Also reset first time player flag and player progress
		if GameManager and GameManager.player_data:
			GameManager.player_data.is_first_time_player = true
			GameManager.player_data.player_experience = 0
			GameManager.player_data.gods.clear()
			GameManager.player_data.resources.clear()
			GameManager.player_data.add_resource("energy", 80)  # Restore energy
			GameManager.save_game()
		
		print("🎯 Reset all tutorials and player data - fresh start!")

func _on_start_ftue_pressed():
	"""Start First Time User Experience for testing"""
	if tutorial_manager:
		tutorial_manager.start_tutorial("first_time_experience")
		print("🎯 Started FTUE tutorial")

func _on_test_3_gods_pressed():
	"""Test granting 3 base gods directly"""
	if GameManager and GameManager.player_data:
		# Clear existing gods first
		GameManager.player_data.gods.clear()
		
		# Grant the 3 base gods using the tutorial system
		var starter_gods = ["ares", "athena", "poseidon"]
		if tutorial_manager:
			tutorial_manager.grant_starter_gods(starter_gods)
			print("🎯 Granted 3 base gods: Ares, Athena, Poseidon")
		else:
			print("❌ Tutorial manager not available")

func _on_show_god_count_pressed():
	"""Show how many gods the player currently has"""
	if GameManager and GameManager.player_data:
		var god_count = GameManager.player_data.gods.size()
		print("🎯 Player currently has %d gods:" % god_count)
		for god in GameManager.player_data.gods:
			print("  - %s (Level %d)" % [god.name, god.level])

# ==============================================================================
# RESOURCE DEBUG FUNCTIONS
# ==============================================================================

func _on_add_mana_pressed():
	"""Add 10,000 mana for testing"""
	if GameManager and GameManager.player_data:
		GameManager.player_data.add_resource("mana", 10000)
		GameManager.resources_updated.emit()
		print("🎯 Added 10,000 mana")

func _on_add_crystals_pressed():
	"""Add 100 crystals for testing"""
	if GameManager and GameManager.player_data:
		GameManager.player_data.add_resource("divine_crystals", 100)
		GameManager.resources_updated.emit()
		print("🎯 Added 100 divine crystals")

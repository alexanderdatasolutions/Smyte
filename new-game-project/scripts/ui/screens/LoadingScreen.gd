# scripts/ui/LoadingScreen.gd - Summoners War style loading screen
extends Control

@onready var progress_bar = $VBoxContainer/ProgressBar
@onready var status_label = $VBoxContainer/StatusLabel
@onready var logo_label = $VBoxContainer/LogoLabel
@onready var version_label = $VBoxContainer/VersionLabel

func _ready():
	# Set up the loading screen UI
	setup_ui()
	
	# Start initialization through GameCoordinator
	if GameCoordinator:
		start_loading()
	else:
		# Fallback - go directly to main game
		load_main_game()

func setup_ui():
	"""Set up the loading screen appearance"""
	# Style the background
	var background = ColorRect.new()
	background.color = Color(0.1, 0.1, 0.15, 1.0)  # Dark blue background
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	move_child(background, 0)  # Put background behind everything
	
	# Set up labels
	if logo_label:
		logo_label.text = "GODS RPG"
		logo_label.add_theme_font_size_override("font_size", 48)
		logo_label.add_theme_color_override("font_color", Color.GOLD)
	
	if version_label:
		version_label.text = "Version 0.1.0 MVP"
		version_label.add_theme_font_size_override("font_size", 12)
		version_label.modulate = Color.GRAY
	
	if status_label:
		status_label.text = "Starting up..."
		status_label.add_theme_font_size_override("font_size", 16)
	
	if progress_bar:
		progress_bar.value = 0
		progress_bar.custom_minimum_size = Vector2(400, 30)
		
		# Style the progress bar
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.3, 0.6, 1.0, 0.8)  # Blue progress
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		progress_bar.add_theme_stylebox_override("fill", style)

func start_loading():
	"""Start the loading process through GameCoordinator"""
	# TODO: Implement proper loading system through SystemRegistry
	# For now, skip directly to main game
	await get_tree().create_timer(1.0).timeout
	load_main_game()

func _on_initialization_progress(step_name: String, progress: float):
	"""Update loading progress"""
	if status_label:
		status_label.text = step_name
	if progress_bar:
		progress_bar.value = progress * 100

func _on_initialization_complete():
	"""Handle initialization completion"""
	if status_label:
		status_label.text = "Ready! Loading game..."
	if progress_bar:
		progress_bar.value = 100

	# Small delay for visual feedback
	await get_tree().create_timer(0.5).timeout
	load_main_game()

func load_main_game():
	"""Load the main game scene with proper error handling"""
	# Robust scene tree checking following MYTHOS ARCHITECTURE
	var tree = get_tree()
	if not tree:
		# Fallback: Try to access through GameCoordinator if available
		if GameCoordinator and is_instance_valid(GameCoordinator):
			tree = GameCoordinator.get_tree()

		if not tree:
			return

	# Verify the main scene file exists
	if not FileAccess.file_exists("res://scenes/Main.tscn"):
		return

	tree.change_scene_to_file("res://scenes/Main.tscn")

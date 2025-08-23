# scripts/ui/LoadingScreen.gd - Summoners War style loading screen
extends Control

@onready var progress_bar = $VBoxContainer/ProgressBar
@onready var status_label = $VBoxContainer/StatusLabel
@onready var logo_label = $VBoxContainer/LogoLabel
@onready var version_label = $VBoxContainer/VersionLabel

func _ready():
	# Set up the loading screen UI
	setup_ui()
	
	# Start initialization
	if GameManager and GameManager.game_initializer:
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
	"""Start the loading process"""
	var initializer = GameManager.game_initializer
	
	# Connect to initialization signals
	initializer.initialization_progress.connect(_on_initialization_progress)
	initializer.initialization_complete.connect(_on_initialization_complete)
	
	# Start the initialization
	initializer.start_initialization()

func _on_initialization_progress(step_name: String, progress: float):
	"""Update loading progress"""
	if status_label:
		status_label.text = step_name
	if progress_bar:
		progress_bar.value = progress * 100
	
	print("Loading: %s (%.1f%%)" % [step_name, progress * 100])

func _on_initialization_complete():
	"""Handle initialization completion"""
	if status_label:
		status_label.text = "Ready! Loading game..."
	if progress_bar:
		progress_bar.value = 100
	
	print("Loading complete! Starting main game...")
	
	# Small delay for visual feedback
	await get_tree().create_timer(0.5).timeout
	load_main_game()

func load_main_game():
	"""Load the main game scene"""
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

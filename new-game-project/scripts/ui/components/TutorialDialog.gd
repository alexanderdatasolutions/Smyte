# scripts/ui/TutorialDialog.gd
# Simple, clean tutorial dialog system following MYTHOS ARCHITECTURE
extends Control
class_name TutorialDialog

# UI elements - using get_node instead of @onready for more control
var title_label: Label
var message_label: Label 
var continue_button: Button

# Signals
signal dialog_completed()

# Current tutorial data
var current_tutorial: Dictionary = {}

func _ready():
	"""Initialize tutorial dialog"""
	# Get node references manually to ensure they exist
	_initialize_nodes()

	# Start hidden
	visible = false

func _initialize_nodes():
	"""Initialize UI node references with error checking"""
	# Get nodes manually with better error handling
	title_label = get_node_or_null("DialogPanel/VBoxContainer/TitleLabel")
	message_label = get_node_or_null("DialogPanel/VBoxContainer/MessageLabel")
	continue_button = get_node_or_null("DialogPanel/VBoxContainer/ButtonContainer/ContinueButton")

	# Connect continue button if it exists
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)

func _input(event):
	"""Handle input events for keyboard shortcuts"""
	if visible and event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_on_continue_pressed()
		elif event.keycode == KEY_ESCAPE:
			hide_dialog()

func show_tutorial_step(tutorial_data: Dictionary):
	"""Show a tutorial step with title and message"""
	current_tutorial = tutorial_data

	# Ensure nodes are initialized
	if not title_label or not message_label or not continue_button:
		_initialize_nodes()

	# CRITICAL FIX: Explicitly set mouse filters for the entire hierarchy
	self.mouse_filter = Control.MOUSE_FILTER_PASS

	# Get and set mouse filters for nested controls
	var dialog_panel = get_node_or_null("DialogPanel")
	if dialog_panel:
		dialog_panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var button_container = get_node_or_null("DialogPanel/VBoxContainer/ButtonContainer")
	if button_container:
		button_container.mouse_filter = Control.MOUSE_FILTER_PASS

	# Safe assignment with null checks (MYTHOS ARCHITECTURE - robust code)
	if title_label:
		var title_text = tutorial_data.get("title", "Tutorial")
		title_label.text = title_text

	if message_label:
		var message_text = tutorial_data.get("message", tutorial_data.get("text", ""))
		message_label.text = message_text

	if continue_button:
		var button_text = tutorial_data.get("button_text", "Continue")
		continue_button.text = button_text

		# Ensure button is connected
		if not continue_button.pressed.is_connected(_on_continue_pressed):
			continue_button.pressed.connect(_on_continue_pressed)
	else:
		return  # Can't show dialog without button

	# Show the dialog
	visible = true
	z_index = 1000  # Ensure it's on top of everything

	# Bring to front
	if get_parent():
		get_parent().move_child(self, -1)  # Move to end (front)

func _on_continue_pressed():
	"""Handle continue button press"""
	# Hide dialog
	visible = false

	# Unpause the game
	get_tree().paused = false

	# Emit completion signal
	dialog_completed.emit()

func hide_dialog():
	"""Hide the dialog without completing"""
	visible = false
	get_tree().paused = false

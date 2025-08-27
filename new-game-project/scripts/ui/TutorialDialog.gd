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
	print("TutorialDialog: Initializing...")
	
	# Get node references manually to ensure they exist
	_initialize_nodes()
	
	# Start hidden
	visible = false
	print("TutorialDialog: Initialization complete")

func _initialize_nodes():
	"""Initialize UI node references with error checking"""
	print("TutorialDialog: Getting node references...")
	
	# Get nodes manually with better error handling
	title_label = get_node_or_null("DialogPanel/VBoxContainer/TitleLabel")
	message_label = get_node_or_null("DialogPanel/VBoxContainer/MessageLabel")
	continue_button = get_node_or_null("DialogPanel/VBoxContainer/ButtonContainer/ContinueButton")
	
	# Debug: Check if nodes exist
	if not title_label:
		print("TutorialDialog: ERROR - title_label node not found at path: DialogPanel/VBoxContainer/TitleLabel")
	else:
		print("TutorialDialog: ✓ title_label found")
		
	if not message_label:
		print("TutorialDialog: ERROR - message_label node not found at path: DialogPanel/VBoxContainer/MessageLabel")
	else:
		print("TutorialDialog: ✓ message_label found")
		
	if not continue_button:
		print("TutorialDialog: ERROR - continue_button node not found at path: DialogPanel/VBoxContainer/ButtonContainer/ContinueButton")
	else:
		print("TutorialDialog: ✓ continue_button found")
	
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
		continue_button.mouse_entered.connect(func(): print("TutorialDialog: Mouse entered continue button"))
		continue_button.mouse_exited.connect(func(): print("TutorialDialog: Mouse exited continue button"))
		continue_button.button_down.connect(func(): print("TutorialDialog: Button down event"))
		continue_button.button_up.connect(func(): print("TutorialDialog: Button up event"))
		
		# Also check if button is disabled
		print("TutorialDialog: Button disabled state: ", continue_button.disabled)
		print("TutorialDialog: Button focus mode: ", continue_button.focus_mode)
		print("TutorialDialog: Button mouse filter: ", continue_button.mouse_filter)
		
		print("TutorialDialog: Continue button connected successfully")
	else:
		print("TutorialDialog: Cannot connect continue button - node is null")

func _input(event):
	"""Handle input events for debugging"""
	if visible and event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			print("TutorialDialog: Space/Enter pressed - triggering continue")
			_on_continue_pressed()
		elif event.keycode == KEY_ESCAPE:
			print("TutorialDialog: Escape pressed - hiding dialog")
			hide_dialog()

func show_tutorial_step(tutorial_data: Dictionary):
	"""Show a tutorial step with title and message"""
	current_tutorial = tutorial_data
	
	print("TutorialDialog: Received tutorial data: ", tutorial_data)
	
	# Ensure nodes are initialized
	if not title_label or not message_label or not continue_button:
		print("TutorialDialog: Re-initializing nodes...")
		_initialize_nodes()
	
	# CRITICAL FIX: Explicitly set mouse filters for the entire hierarchy
	self.mouse_filter = Control.MOUSE_FILTER_PASS
	print("TutorialDialog: Set root mouse_filter to PASS")
	
	# Get and set mouse filters for nested controls
	var dialog_panel = get_node_or_null("DialogPanel")
	if dialog_panel:
		dialog_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		print("TutorialDialog: Set DialogPanel mouse_filter to PASS")
	
	var button_container = get_node_or_null("DialogPanel/VBoxContainer/ButtonContainer")
	if button_container:
		button_container.mouse_filter = Control.MOUSE_FILTER_PASS
		print("TutorialDialog: Set ButtonContainer mouse_filter to PASS")
	
	# Safe assignment with null checks (MYTHOS ARCHITECTURE - robust code)
	if title_label:
		var title_text = tutorial_data.get("title", "Tutorial")
		title_label.text = title_text
		print("TutorialDialog: Set title to: ", title_text)
	else:
		print("TutorialDialog: title_label is null - check scene structure")
		
	if message_label:
		var message_text = tutorial_data.get("message", tutorial_data.get("text", ""))
		message_label.text = message_text
		print("TutorialDialog: Set message to: ", message_text)
	else:
		print("TutorialDialog: message_label is null - check scene structure")
		
	if continue_button:
		var button_text = tutorial_data.get("button_text", "Continue")
		continue_button.text = button_text
		print("TutorialDialog: Set button text to: ", button_text)
		
		# Ensure button is connected
		if not continue_button.pressed.is_connected(_on_continue_pressed):
			continue_button.pressed.connect(_on_continue_pressed)
			print("TutorialDialog: Connected continue button")
	else:
		print("TutorialDialog: continue_button is null - check scene structure")
		return  # Can't show dialog without button
	
	# Show the dialog
	visible = true
	z_index = 1000  # Ensure it's on top of everything
	print("TutorialDialog: Dialog made visible with high z-index")
	
	# Bring to front
	if get_parent():
		get_parent().move_child(self, -1)  # Move to end (front)
		print("TutorialDialog: Moved to front of parent")
	
	# DON'T pause the game - this might be blocking input
	# get_tree().paused = true
	print("TutorialDialog: Game NOT paused to allow input")

func _on_continue_pressed():
	"""Handle continue button press"""
	print("TutorialDialog: BUTTON PRESSED! _on_continue_pressed() called")
	
	# Hide dialog
	visible = false
	print("TutorialDialog: Dialog hidden")
	
	# Unpause the game
	get_tree().paused = false
	print("TutorialDialog: Game unpaused")
	
	# Emit completion signal
	dialog_completed.emit()
	print("TutorialDialog: Emitted dialog_completed signal")

func hide_dialog():
	"""Hide the dialog without completing"""
	visible = false
	get_tree().paused = false

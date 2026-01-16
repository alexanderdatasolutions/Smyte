extends Control

"""
MainUIOverlay.gd
Main UI overlay system that sits above all other UI elements.
This handles tutorials, notifications, banners, and other persistent UI.

Following MYTHOS ARCHITECTURE:
- Clean separation of UI layers
- Modular overlay management 
- Proper Z-index layering
- Centralized UI coordination
"""

# UI Layer Z-Index Constants (higher numbers = on top)
const Z_BACKGROUND = 0
const Z_GAME_UI = 100
const Z_MODALS = 200
const Z_TUTORIALS = 300
const Z_NOTIFICATIONS = 400
const Z_DEBUG = 500

# Child container nodes for different UI layers
@onready var tutorial_layer: Control
@onready var notification_layer: Control
@onready var banner_layer: Control
@onready var modal_layer: Control

# UI elements
@onready var resource_display: Control = $ResourceDisplay  # Reference to manually added ResourceDisplay

# System references
var tutorial_manager
var notification_manager

func _ready():
	"""Initialize the main UI overlay system"""
	print("MainUIOverlay: Initializing main UI overlay system...")
	
	# Set this control to fill the entire screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Ensure this overlay is always on top
	z_index = Z_TUTORIALS
	
	# Create UI layer containers
	_create_ui_layers()
	
	# Connect to systems
	_connect_to_systems()
	
	print("MainUIOverlay: Main UI overlay system ready")

func _create_ui_layers():
	"""Create separate layers for different types of UI"""
	
	# Tutorial Layer (highest priority for user guidance)
	tutorial_layer = Control.new()
	tutorial_layer.name = "TutorialLayer"
	tutorial_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutorial_layer.z_index = Z_TUTORIALS
	tutorial_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks through when no tutorial
	add_child(tutorial_layer)
	
	# Notification Layer (for toasts, alerts)
	notification_layer = Control.new()
	notification_layer.name = "NotificationLayer" 
	notification_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	notification_layer.z_index = Z_NOTIFICATIONS
	notification_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(notification_layer)
	
	# Banner Layer (for resource display, banners)
	banner_layer = Control.new()
	banner_layer.name = "BannerLayer"
	banner_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner_layer.z_index = Z_GAME_UI
	banner_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner_layer)
	
	# Modal Layer (for popups, dialogs)
	modal_layer = Control.new()
	modal_layer.name = "ModalLayer"
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.z_index = Z_MODALS
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal_layer)
	
	print("MainUIOverlay: Created UI layer hierarchy")

func _connect_to_systems():
	"""Connect to game systems that need overlay access"""
	# Connect when systems become available through SystemRegistry
	var system_registry = SystemRegistry.get_instance()
	if system_registry:
		tutorial_manager = system_registry.get_system("TutorialManager")
		notification_manager = system_registry.get_system("NotificationManager")
		
		# Connect tutorial system to tutorial layer
		if tutorial_manager and tutorial_manager.has_signal("tutorial_dialog_created"):
			tutorial_manager.tutorial_dialog_created.connect(_on_tutorial_dialog_created)
	
	# Load and setup persistent UI elements that should always be on top
	_setup_persistent_ui()

func _setup_persistent_ui():
	"""Setup persistent UI elements like resource display"""
	# Check if ResourceDisplay was manually added to the scene
	if resource_display:
		print("MainUIOverlay: Found manually added ResourceDisplay, preserving user positioning...")
		
		# PRESERVE USER'S EXACT POSITIONING - Don't override manual placement (MYTHOS ARCHITECTURE - user control)
		print("MainUIOverlay: Current ResourceDisplay position: left=%.1f, top=%.1f, right=%.1f, bottom=%.1f" % 
			[resource_display.offset_left, resource_display.offset_top, resource_display.offset_right, resource_display.offset_bottom])
		
		# Store the user's positioning before moving to banner layer
		var user_anchor_left = resource_display.anchor_left
		var user_anchor_top = resource_display.anchor_top  
		var user_anchor_right = resource_display.anchor_right
		var user_anchor_bottom = resource_display.anchor_bottom
		var user_offset_left = resource_display.offset_left
		var user_offset_top = resource_display.offset_top
		var user_offset_right = resource_display.offset_right
		var user_offset_bottom = resource_display.offset_bottom
		var user_grow_horizontal = resource_display.grow_horizontal
		var user_grow_vertical = resource_display.grow_vertical
		
		# Remove from root and add to banner layer
		remove_child(resource_display)
		add_to_banner_layer(resource_display)
		
		# RESTORE user's exact positioning (respect manual placement)
		resource_display.anchor_left = user_anchor_left
		resource_display.anchor_top = user_anchor_top
		resource_display.anchor_right = user_anchor_right
		resource_display.anchor_bottom = user_anchor_bottom
		resource_display.offset_left = user_offset_left
		resource_display.offset_top = user_offset_top
		resource_display.offset_right = user_offset_right
		resource_display.offset_bottom = user_offset_bottom
		resource_display.grow_horizontal = user_grow_horizontal
		resource_display.grow_vertical = user_grow_vertical
		
		# Make sure it's visible and updated
		resource_display.visible = true
		
		# Force immediate update of the ResourceDisplay
		if resource_display.has_method("_update_this_instance"):
			resource_display.call_deferred("_update_this_instance")
			print("MainUIOverlay: Triggered ResourceDisplay update")
		
		print("MainUIOverlay: Preserved ResourceDisplay at user position in banner layer")
	else:
		# Load ResourceDisplay into banner layer so it's always visible
		var resource_display_scene = load("res://scenes/ResourceDisplay.tscn")
		if resource_display_scene:
			var new_resource_display = resource_display_scene.instantiate()
			resource_display = new_resource_display  # Store reference
			add_to_banner_layer(resource_display)
			
			# ResourceDisplay comes with proper positioning from scene
			resource_display.visible = true
			
			# Force immediate update
			if resource_display.has_method("_update_this_instance"):
				resource_display.call_deferred("_update_this_instance")
			
			print("MainUIOverlay: Added ResourceDisplay to banner layer with default positioning")

func _on_tutorial_dialog_created(dialog: Control):
	"""Handle tutorial dialog creation - move it to proper layer"""
	if dialog and tutorial_layer:
		print("MainUIOverlay: Moving tutorial dialog to tutorial layer")
		
		# Remove from current parent and add to tutorial layer
		if dialog.get_parent():
			dialog.get_parent().remove_child(dialog)
		
		tutorial_layer.add_child(dialog)
		
		# Ensure tutorial layer accepts input during tutorials
		tutorial_layer.mouse_filter = Control.MOUSE_FILTER_PASS
		
		# Make sure the dialog itself can receive input
		dialog.mouse_filter = Control.MOUSE_FILTER_PASS
		
		# Connect to dialog completion to reset mouse filter
		if dialog.has_signal("dialog_completed"):
			dialog.dialog_completed.connect(_on_tutorial_dialog_completed)
		
		print("MainUIOverlay: Tutorial dialog added with proper input handling")

func _on_tutorial_dialog_completed():
	"""Handle tutorial dialog completion"""
	print("MainUIOverlay: Tutorial dialog completed, resetting layer")
	tutorial_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

# Public API for other systems

func add_to_tutorial_layer(node: Control):
	"""Add a UI element to the tutorial layer"""
	if tutorial_layer:
		tutorial_layer.add_child(node)
		tutorial_layer.mouse_filter = Control.MOUSE_FILTER_PASS

func add_to_notification_layer(node: Control):
	"""Add a UI element to the notification layer"""
	if notification_layer:
		notification_layer.add_child(node)

func add_to_banner_layer(node: Control):
	"""Add a UI element to the banner layer (like resource display)"""
	if banner_layer:
		banner_layer.add_child(node)

func add_to_modal_layer(node: Control):
	"""Add a UI element to the modal layer"""
	if modal_layer:
		modal_layer.add_child(node)
		modal_layer.mouse_filter = Control.MOUSE_FILTER_PASS

func remove_from_tutorial_layer(node: Control):
	"""Remove a UI element from tutorial layer"""
	if tutorial_layer and node in tutorial_layer.get_children():
		tutorial_layer.remove_child(node)
		if tutorial_layer.get_child_count() == 0:
			tutorial_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

func remove_from_modal_layer(node: Control):
	"""Remove a UI element from modal layer"""
	if modal_layer and node in modal_layer.get_children():
		modal_layer.remove_child(node)
		if modal_layer.get_child_count() == 0:
			modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

func clear_all_layers():
	"""Clear all overlay content (useful for scene transitions)"""
	for layer in [tutorial_layer, notification_layer, banner_layer, modal_layer]:
		if layer:
			for child in layer.get_children():
				child.queue_free()
			layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

func debug_layer_status():
	"""Debug function to check layer visibility and content"""
	print("=== MainUIOverlay Layer Status ===")
	print("Tutorial Layer: visible=%s, children=%d, z_index=%d" % [tutorial_layer.visible, tutorial_layer.get_child_count(), tutorial_layer.z_index])
	print("Banner Layer: visible=%s, children=%d, z_index=%d" % [banner_layer.visible, banner_layer.get_child_count(), banner_layer.z_index])
	print("Modal Layer: visible=%s, children=%d, z_index=%d" % [modal_layer.visible, modal_layer.get_child_count(), modal_layer.z_index])
	print("Notification Layer: visible=%s, children=%d, z_index=%d" % [notification_layer.visible, notification_layer.get_child_count(), notification_layer.z_index])
	
	if resource_display:
		print("ResourceDisplay: visible=%s, position=%s, size=%s" % [resource_display.visible, resource_display.position, resource_display.size])
		var parent_name = "None"
		if resource_display.get_parent():
			parent_name = resource_display.get_parent().name
		print("ResourceDisplay parent: %s" % parent_name)
	else:
		print("ResourceDisplay: null reference")
	print("=== End Layer Status ===")

# scripts/systems/UIManager.gd
# Comprehensive UI Management System following MYTHOS ARCHITECTURE
extends Node
class_name UIManager

# ==============================================================================
# UI MANAGER - Modular UI System for Popups, Tutorials, and Notifications
# ==============================================================================
# Handles all popup-style UI elements including:
# - Tutorial dialogs with pointer/arrow support
# - Seasonal and event popups
# - Notification toasts
# - Feature unlock celebrations
# - Confirmation dialogs
# - Reward display popups

# UI Layer Management (z-index based)
enum UILayer {
	BACKGROUND = 0,      # Background elements
	GAME_UI = 10,        # Main game UI
	POPUPS = 50,         # Standard popups
	TUTORIALS = 75,      # Tutorial overlays and pointers
	NOTIFICATIONS = 100, # Toast notifications
	CRITICAL = 200       # Critical alerts, confirmations
}

# Popup Types for different behaviors
enum PopupType {
	DIALOG,              # Standard dialog box
	TUTORIAL_STEP,       # Tutorial with pointer/arrow
	NOTIFICATION_TOAST,  # Temporary notification
	FEATURE_UNLOCK,      # Feature unlock celebration
	REWARD_DISPLAY,      # Show rewards earned
	CONFIRMATION,        # Yes/No confirmation
	SEASONAL_EVENT       # Special event popup
}

# Active UI state tracking
var active_popups: Array[Control] = []
var popup_queue: Array[Dictionary] = []
var tutorial_overlay: Control
var notification_container: Control

# Preloaded UI scenes (MYTHOS ARCHITECTURE - Scene-based UI)
var dialog_scene = preload("res://scenes/TutorialDialog.tscn")
var notification_scene # TODO: Create notification scene
var reward_scene # TODO: Create reward display scene

# System dependencies
var game_manager: Node
var audio_manager: Node  # For popup sounds

# Signals
signal popup_shown(popup_id: String, popup_type: PopupType)
signal popup_closed(popup_id: String, popup_type: PopupType)
signal tutorial_pointer_shown(target_element: Control, message: String)

func _ready():
	"""Initialize the UI Management System"""
	print("UIManager: Initializing modular UI system...")
	
	# Wait for GameManager
	if not GameManager:
		await get_tree().create_timer(0.1).timeout
	
	game_manager = GameManager
	
	# Setup UI layer containers
	_setup_ui_containers()
	
	print("UIManager: Ready - Modular UI system initialized")

func _setup_ui_containers():
	"""Setup layered UI containers for proper z-ordering"""
	# Create notification container (always visible, high z-index)
	notification_container = Control.new()
	notification_container.name = "NotificationContainer"
	notification_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	notification_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notification_container.z_index = UILayer.NOTIFICATIONS
	
	# Add to current scene when available
	if get_tree().current_scene:
		get_tree().current_scene.add_child(notification_container)

# ==============================================================================
# DIALOG SYSTEM - Standard Popups and Tutorials
# ==============================================================================

func show_dialog(config: Dictionary) -> Control:
	"""
	Show a dialog popup with comprehensive configuration
	
	Config format:
	{
		"id": "unique_popup_id",
		"type": PopupType.DIALOG,
		"title": "Dialog Title",
		"message": "Dialog message text",
		"buttons": [{"text": "OK", "action": "confirm"}, {"text": "Cancel", "action": "cancel"}],
		"auto_close": false,
		"layer": UILayer.POPUPS,
		"style": "default",  # or "celebration", "warning", "error"
		"sound": "popup_open"
	}
	"""
	var popup_id = config.get("id", "dialog_" + str(Time.get_unix_time_from_system()))
	var popup_type = config.get("type", PopupType.DIALOG)
	
	print("UIManager: Showing dialog - ID: %s, Type: %s" % [popup_id, popup_type])
	
	# Create dialog instance
	var dialog = _create_dialog_popup(config)
	if not dialog:
		print("UIManager: ERROR - Failed to create dialog")
		return null
	
	# Configure dialog
	_configure_popup(dialog, config)
	
	# Add to scene and track
	_add_popup_to_scene(dialog, config.get("layer", UILayer.POPUPS))
	active_popups.append(dialog)
	
	# Connect completion signal
	if dialog.has_signal("dialog_completed"):
		dialog.dialog_completed.connect(_on_popup_completed.bind(popup_id, popup_type, dialog))
	
	# Play sound if specified
	_play_popup_sound(config.get("sound", ""))
	
	# Emit signal
	popup_shown.emit(popup_id, popup_type)
	
	print("UIManager: Dialog '%s' displayed successfully" % popup_id)
	return dialog

func show_tutorial_step(config: Dictionary) -> Control:
	"""
	Show tutorial step with optional pointer/arrow to UI element
	
	Config format:
	{
		"id": "tutorial_step_id",
		"type": PopupType.TUTORIAL_STEP,
		"title": "Tutorial Step Title", 
		"message": "Step instructions",
		"target_element": button_node,  # Optional: UI element to point to
		"pointer_position": "bottom",   # "top", "bottom", "left", "right"
		"highlight_target": true,       # Highlight the target element
		"auto_advance": false,
		"layer": UILayer.TUTORIALS
	}
	"""
	var popup_id = config.get("id", "tutorial_" + str(Time.get_unix_time_from_system()))
	
	print("UIManager: Showing tutorial step - ID: %s" % popup_id)
	
	# Create tutorial dialog
	var dialog = show_dialog({
		"id": popup_id,
		"type": PopupType.TUTORIAL_STEP,
		"title": config.get("title", "Tutorial"),
		"message": config.get("message", ""),
		"layer": UILayer.TUTORIALS,
		"style": "tutorial"
	})
	
	if not dialog:
		return null
	
	# Add tutorial-specific features
	var target_element = config.get("target_element")
	if target_element and is_instance_valid(target_element):
		_show_tutorial_pointer(target_element, config)
	
	# Auto-advance if specified
	if config.get("auto_advance", false):
		var delay = config.get("auto_delay", 3.0)
		get_tree().create_timer(delay).timeout.connect(_auto_advance_tutorial.bind(dialog))
	
	return dialog

func show_notification(config: Dictionary):
	"""
	Show temporary notification toast
	
	Config format:
	{
		"id": "notification_id",
		"type": PopupType.NOTIFICATION_TOAST,
		"title": "Notification Title",
		"message": "Notification text",
		"icon": "icon_path",
		"duration": 3.0,
		"position": "top_right",  # "top_left", "top_right", "bottom_left", "bottom_right"
		"style": "info"  # "success", "warning", "error"
	}
	"""
	var notification_id = config.get("id", "notification_" + str(Time.get_unix_time_from_system()))
	
	print("UIManager: Showing notification - ID: %s" % notification_id)
	
	# TODO: Create notification toast implementation
	# For now, fallback to simple print
	var title = config.get("title", "")
	var message = config.get("message", "")
	print("🔔 NOTIFICATION: %s - %s" % [title, message])

func show_feature_unlock_celebration(feature_name: String, feature_description: String):
	"""Show celebration popup for feature unlocks"""
	show_dialog({
		"id": "feature_unlock_" + feature_name,
		"type": PopupType.FEATURE_UNLOCK,
		"title": "🎉 New Feature Unlocked!",
		"message": "%s\n\n%s" % [feature_name.capitalize(), feature_description],
		"buttons": [{"text": "Awesome!", "action": "confirm"}],
		"style": "celebration",
		"sound": "feature_unlock"
	})

# ==============================================================================
# POPUP CREATION AND CONFIGURATION
# ==============================================================================

func _create_dialog_popup(config: Dictionary) -> Control:
	"""Create dialog popup instance from scene"""
	if not dialog_scene:
		print("UIManager: ERROR - Dialog scene not loaded")
		return null
	
	var dialog = dialog_scene.instantiate()
	if not dialog:
		print("UIManager: ERROR - Failed to instantiate dialog scene")
		return null
	
	return dialog

func _configure_popup(popup: Control, config: Dictionary):
	"""Configure popup appearance and behavior"""
	if not popup:
		return
	
	# Set popup data if it's a TutorialDialog
	if popup.has_method("show_tutorial_step"):
		popup.show_tutorial_step(config)
	
	# Apply styling based on config
	var style = config.get("style", "default")
	_apply_popup_style(popup, style)

func _apply_popup_style(popup: Control, style: String):
	"""Apply visual styling to popup based on type"""
	match style:
		"celebration":
			# Add celebration effects (particles, colors, etc.)
			pass
		"warning":
			# Add warning styling (orange colors, warning icon)
			pass
		"error":
			# Add error styling (red colors, error icon)
			pass
		"tutorial":
			# Add tutorial-specific styling
			pass
		_:
			# Default styling
			pass

func _add_popup_to_scene(popup: Control, layer: int):
	"""Add popup to scene with proper layering"""
	popup.z_index = layer
	
	if get_tree().current_scene:
		get_tree().current_scene.add_child(popup)
	else:
		print("UIManager: WARNING - No current scene for popup")

# ==============================================================================
# TUTORIAL POINTER SYSTEM
# ==============================================================================

func _show_tutorial_pointer(target_element: Control, config: Dictionary):
	"""Show arrow/pointer to specific UI element"""
	if not target_element or not is_instance_valid(target_element):
		return
	
	var pointer_position = config.get("pointer_position", "bottom")
	var message = config.get("message", "")
	
	print("UIManager: Showing tutorial pointer to element at position: %s" % pointer_position)
	
	# TODO: Implement arrow/pointer graphics
	# For now, just highlight the target
	if config.get("highlight_target", true):
		_highlight_ui_element(target_element)
	
	# Emit signal for other systems to listen to
	tutorial_pointer_shown.emit(target_element, message)

func _highlight_ui_element(element: Control):
	"""Add highlight effect to UI element"""
	if not element:
		return
	
	# TODO: Add visual highlight (outline, glow, pulsing, etc.)
	print("UIManager: Highlighting UI element: %s" % element.name)

func _auto_advance_tutorial(dialog: Control):
	"""Auto-advance tutorial after delay"""
	if dialog and is_instance_valid(dialog):
		if dialog.has_method("_on_continue_pressed"):
			dialog._on_continue_pressed()

# ==============================================================================
# POPUP LIFECYCLE MANAGEMENT
# ==============================================================================

func _on_popup_completed(popup_id: String, popup_type: PopupType, popup: Control):
	"""Handle popup completion/closure"""
	print("UIManager: Popup completed - ID: %s, Type: %s" % [popup_id, popup_type])
	
	# Remove from active list
	if active_popups.has(popup):
		active_popups.erase(popup)
	
	# Clean up popup
	if popup and is_instance_valid(popup):
		popup.queue_free()
	
	# Emit completion signal
	popup_closed.emit(popup_id, popup_type)
	
	# Process next popup in queue if any
	_process_popup_queue()

func close_popup(popup_id: String):
	"""Manually close a specific popup"""
	for popup in active_popups:
		if popup.get_meta("popup_id", "") == popup_id:
			if popup.has_method("hide_dialog"):
				popup.hide_dialog()
			break

func close_all_popups():
	"""Close all active popups"""
	for popup in active_popups.duplicate():
		if popup.has_method("hide_dialog"):
			popup.hide_dialog()
	
	active_popups.clear()

func _process_popup_queue():
	"""Process queued popups"""
	if popup_queue.size() > 0:
		var next_popup = popup_queue.pop_front()
		show_dialog(next_popup)

# ==============================================================================
# SOUND SYSTEM INTEGRATION
# ==============================================================================

func _play_popup_sound(sound_name: String):
	"""Play sound for popup events"""
	if sound_name == "":
		return
	
	# TODO: Integrate with audio manager
	print("UIManager: Playing popup sound: %s" % sound_name)

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

func get_active_popup_count() -> int:
	"""Get number of currently active popups"""
	return active_popups.size()

func is_popup_active(popup_id: String) -> bool:
	"""Check if specific popup is currently active"""
	for popup in active_popups:
		if popup.get_meta("popup_id", "") == popup_id:
			return true
	return false

func queue_popup(config: Dictionary):
	"""Add popup to queue for delayed display"""
	popup_queue.append(config)

# ==============================================================================
# DEBUG FUNCTIONS
# ==============================================================================

func debug_show_test_popup():
	"""Show test popup for debugging"""
	show_dialog({
		"id": "debug_test",
		"title": "Debug Test Popup",
		"message": "This is a test popup for debugging the UI system.",
		"buttons": [{"text": "OK", "action": "confirm"}]
	})

func get_debug_info() -> Dictionary:
	"""Get debug information about UI Manager state"""
	return {
		"active_popups": active_popups.size(),
		"queued_popups": popup_queue.size(),
		"popup_ids": active_popups.map(func(p): return p.get_meta("popup_id", "unknown"))
	}

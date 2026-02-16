# scripts/systems/UIManager.gd
# UI Management System for Popups and Tutorials
extends Node
class_name UIManager

# UI Layer Management (z-index based)
enum UILayer {
	BACKGROUND = 0,
	GAME_UI = 10,
	POPUPS = 50,
	TUTORIALS = 75,
	NOTIFICATIONS = 100,
	CRITICAL = 200
}

# Popup Types for different behaviors
enum PopupType {
	DIALOG,
	TUTORIAL_STEP,
	NOTIFICATION_TOAST,
	FEATURE_UNLOCK,
	REWARD_DISPLAY,
	CONFIRMATION,
	SEASONAL_EVENT
}

# Active UI state tracking
var active_popups: Array = []  # Array[Control]
var popup_queue: Array = []  # Array[Dictionary]
var tutorial_overlay: Control
var notification_container: Control

# Preloaded UI scenes
var dialog_scene = preload("res://scenes/TutorialDialog.tscn")

# System dependencies
var game_manager: Node

# Signals
signal popup_shown(popup_id: String, popup_type: PopupType)
signal popup_closed(popup_id: String, popup_type: PopupType)
signal tutorial_pointer_shown(target_element: Control, message: String)

func _ready():
	var game_coordinator = get_node_or_null("/root/GameCoordinator")
	if not game_coordinator:
		await get_tree().create_timer(0.1).timeout
		game_coordinator = get_node_or_null("/root/GameCoordinator")

	game_manager = game_coordinator

	_setup_ui_containers()

func _setup_ui_containers():
	notification_container = Control.new()
	notification_container.name = "NotificationContainer"
	notification_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	notification_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notification_container.z_index = UILayer.NOTIFICATIONS

	if get_tree().current_scene:
		get_tree().current_scene.add_child(notification_container)

# ==============================================================================
# DIALOG SYSTEM
# ==============================================================================

func show_dialog(config: Dictionary) -> Control:
	var popup_id: String = config.get("id", "dialog_" + str(Time.get_unix_time_from_system()))
	var popup_type: PopupType = config.get("type", PopupType.DIALOG)

	var dialog: Control = _create_dialog_popup(config)
	if not dialog:
		push_error("UIManager: Failed to create dialog")
		return null

	_configure_popup(dialog, config)

	_add_popup_to_scene(dialog, config.get("layer", UILayer.POPUPS))
	active_popups.append(dialog)

	if dialog.has_signal("dialog_completed"):
		dialog.dialog_completed.connect(_on_popup_completed.bind(popup_id, popup_type, dialog))

	popup_shown.emit(popup_id, popup_type)

	return dialog

func show_tutorial_step(config: Dictionary) -> Control:
	var popup_id: String = config.get("id", "tutorial_" + str(Time.get_unix_time_from_system()))

	var dialog: Control = show_dialog({
		"id": popup_id,
		"type": PopupType.TUTORIAL_STEP,
		"title": config.get("title", "Tutorial"),
		"message": config.get("message", ""),
		"layer": UILayer.TUTORIALS,
	})

	if not dialog:
		return null

	var target_element = config.get("target_element")
	if target_element and is_instance_valid(target_element):
		_show_tutorial_pointer(target_element, config)

	if config.get("auto_advance", false):
		var delay: float = config.get("auto_delay", 3.0)
		get_tree().create_timer(delay).timeout.connect(_auto_advance_tutorial.bind(dialog))

	return dialog

func show_feature_unlock_celebration(feature_name: String, feature_description: String):
	show_dialog({
		"id": "feature_unlock_" + feature_name,
		"type": PopupType.FEATURE_UNLOCK,
		"title": "New Feature Unlocked!",
		"message": "%s\n\n%s" % [feature_name.capitalize(), feature_description],
		"buttons": [{"text": "Awesome!", "action": "confirm"}],
	})

# ==============================================================================
# POPUP CREATION AND CONFIGURATION
# ==============================================================================

func _create_dialog_popup(_config: Dictionary) -> Control:
	if not dialog_scene:
		push_error("UIManager: Dialog scene not loaded")
		return null

	var dialog: Control = dialog_scene.instantiate()
	if not dialog:
		push_error("UIManager: Failed to instantiate dialog scene")
		return null

	return dialog

func _configure_popup(popup: Control, config: Dictionary):
	if not popup:
		return

	if popup.has_method("show_tutorial_step"):
		popup.show_tutorial_step(config)

func _add_popup_to_scene(popup: Control, layer: int):
	popup.z_index = layer

	if get_tree().current_scene:
		get_tree().current_scene.add_child(popup)
	else:
		push_warning("UIManager: No current scene for popup")

# ==============================================================================
# TUTORIAL POINTER SYSTEM
# ==============================================================================

func _show_tutorial_pointer(target_element: Control, config: Dictionary):
	if not target_element or not is_instance_valid(target_element):
		return

	var message: String = config.get("message", "")
	tutorial_pointer_shown.emit(target_element, message)

func _auto_advance_tutorial(dialog: Control):
	if dialog and is_instance_valid(dialog):
		if dialog.has_method("_on_continue_pressed"):
			dialog._on_continue_pressed()

# ==============================================================================
# POPUP LIFECYCLE MANAGEMENT
# ==============================================================================

func _on_popup_completed(popup_id: String, popup_type: PopupType, popup: Control):
	if active_popups.has(popup):
		active_popups.erase(popup)

	if popup and is_instance_valid(popup):
		popup.queue_free()

	popup_closed.emit(popup_id, popup_type)

	_process_popup_queue()

func close_popup(popup_id: String):
	for popup in active_popups:
		if popup.get_meta("popup_id", "") == popup_id:
			if popup.has_method("hide_dialog"):
				popup.hide_dialog()
			break

func close_all_popups():
	for popup in active_popups.duplicate():
		if popup.has_method("hide_dialog"):
			popup.hide_dialog()

	active_popups.clear()

func _process_popup_queue():
	if popup_queue.size() > 0:
		var next_popup: Dictionary = popup_queue.pop_front()
		show_dialog(next_popup)

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

func get_active_popup_count() -> int:
	return active_popups.size()

func is_popup_active(popup_id: String) -> bool:
	for popup in active_popups:
		if popup.get_meta("popup_id", "") == popup_id:
			return true
	return false

func queue_popup(config: Dictionary):
	popup_queue.append(config)

# scripts/ui/arena/ArenaDefensePopup.gd
# Arena defense team selection popup - wraps TeamSelectionManager
# Uses near-fullscreen layout to match other team selection screens
class_name ArenaDefensePopup
extends RefCounted

signal defense_confirmed(team: Array)
signal popup_closed

const TeamSelectionManagerScript = preload("res://scripts/ui/battle_setup/TeamSelectionManager.gd")

var _overlay: ColorRect
var _popup: PanelContainer
var _team_manager: Node
var _parent: Control


func show_popup(parent: Control, current_team: Array) -> void:
	_parent = parent

	# Create dark overlay
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0.85)
	_overlay.z_index = 100
	_overlay.gui_input.connect(_on_overlay_input)
	parent.add_child(_overlay)

	# Create popup container - nearly full screen with margins
	_popup = PanelContainer.new()
	_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup.offset_left = 40
	_popup.offset_right = -40
	_popup.offset_top = 60  # Leave room for header
	_popup.offset_bottom = -40
	_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_panel(_popup)
	_overlay.add_child(_popup)

	# Create margin container
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_popup.add_child(margin)

	# Create main VBox for header + TeamSelectionManager
	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(main_vbox)

	# Header with title and close button
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	main_vbox.add_child(header)

	var title: Label = Label.new()
	title.text = "SET DEFENSE TEAM"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn: Button = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(close_popup)
	_style_close_button(close_btn)
	header.add_child(close_btn)

	# Content container for TeamSelectionManager
	var content: Control = Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content)

	# Create TeamSelectionManager
	_team_manager = TeamSelectionManagerScript.new()
	parent.add_child(_team_manager)

	# Configure for defense setup
	_team_manager.hide_section("enemies")
	_team_manager.hide_section("rewards")
	_team_manager.set_confirm_button("SET DEFENSE", _on_confirm)

	# Initialize UI
	_team_manager.initialize_full(content)

	# Connect cancel to close popup
	_team_manager.setup_cancelled.connect(close_popup)

	# Pre-select current defense team
	if not current_team.is_empty():
		_team_manager.set_team(current_team)


func _on_confirm(team: Array) -> void:
	defense_confirmed.emit(team)
	close_popup()


func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if click was outside the popup
		var mouse_pos: Vector2 = event.position
		var popup_rect: Rect2 = _popup.get_global_rect()
		if not popup_rect.has_point(mouse_pos):
			close_popup()


func close_popup() -> void:
	if _team_manager and is_instance_valid(_team_manager):
		_team_manager.queue_free()
		_team_manager = null
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null
	popup_closed.emit()


func _style_panel(panel: PanelContainer) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.12, 0.98)
	style.border_color = Color(0.4, 0.35, 0.5, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)


func _style_close_button(button: Button) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.5, 0.2, 0.2, 0.9)
	style.border_color = Color(0.7, 0.3, 0.3, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", style)

	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = Color(0.6, 0.25, 0.25, 0.95)
	button.add_theme_stylebox_override("hover", hover)

	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color.WHITE)

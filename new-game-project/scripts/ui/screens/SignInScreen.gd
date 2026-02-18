# scripts/ui/screens/SignInScreen.gd
# Sign-in screen - Steam auto-login for PC release
class_name SignInScreen extends Control

signal sign_in_completed(signed_in: bool)

var _firebase_integration = null
var _save_manager = null
var _steam_available: bool = false
var _status_label: Label

func _ready():
	# Wait for SteamManager's delayed init to complete (it waits 2 frames)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_check_steam_available()
	_connect_systems()

	# If Steam is available, auto sign-in
	if _steam_available:
		_auto_sign_in_steam()
	else:
		# No Steam - just proceed to game
		print("SignInScreen: No Steam, proceeding offline")
		sign_in_completed.emit(false)
		queue_free()

func _check_steam_available():
	"""Check if Steam is running and available for auth"""
	var registry: SystemRegistry = SystemRegistry.get_instance()
	if registry:
		var steam_manager: Node = registry.get_system("SteamManager")
		if steam_manager and steam_manager.is_steam_running():
			_steam_available = true
			print("SignInScreen: Steam detected - %s" % steam_manager.get_persona_name())
			return
	_steam_available = false
	print("SignInScreen: Steam not available")

func _connect_systems():
	var registry: SystemRegistry = SystemRegistry.get_instance()
	if not registry:
		return

	_firebase_integration = registry.get_system("FirebaseIntegration")
	_save_manager = registry.get_system("SaveManager")

	if _firebase_integration:
		_firebase_integration.sign_in_completed.connect(_on_sign_in_completed)
		_firebase_integration.sign_in_failed.connect(_on_sign_in_failed)

func _auto_sign_in_steam():
	"""Automatically sign in with Steam - seamless for PC players"""
	# Create minimal loading UI
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.12, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	var title = Label.new()
	title.text = "SMYTE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	vbox.add_child(title)

	_status_label = Label.new()
	_status_label.text = "Signing in with Steam..."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	vbox.add_child(_status_label)

	# Small delay so user sees status
	await get_tree().create_timer(0.3).timeout

	if _firebase_integration:
		_firebase_integration.sign_in_with_steam()
	else:
		_status_label.text = "Starting game..."
		await get_tree().create_timer(0.5).timeout
		sign_in_completed.emit(false)
		queue_free()

func _style_button(btn: Button):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.5, 0.8, 1.0)
	style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", style)

	var hover = style.duplicate()
	hover.bg_color = Color(0.35, 0.55, 0.9, 1.0)
	btn.add_theme_stylebox_override("hover", hover)

func _on_sign_in_completed(_user_data: Dictionary):
	if _status_label:
		_status_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		_status_label.text = "Welcome!"

	await get_tree().create_timer(0.3).timeout
	_finish_sign_in()

func _finish_sign_in():
	# Check if needs display name
	if _check_needs_display_name():
		_show_display_name_prompt()
	else:
		sign_in_completed.emit(true)
		queue_free()

func _on_sign_in_failed(error: String):
	if _status_label:
		_status_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5))
		_status_label.text = "Sign-in failed: " + error

	# Fall back to offline after error
	await get_tree().create_timer(2.0).timeout
	sign_in_completed.emit(false)
	queue_free()

func _check_needs_display_name() -> bool:
	if not _save_manager:
		return false  # Don't block if no save manager
	var existing_name: String = _save_manager.get_player_value("display_name", "")
	if existing_name.is_empty() and _steam_available:
		# Use Steam persona name as default
		var registry: SystemRegistry = SystemRegistry.get_instance()
		if registry:
			var steam_manager: Node = registry.get_system("SteamManager")
			if steam_manager:
				var steam_name: String = steam_manager.get_persona_name()
				if not steam_name.is_empty():
					_save_manager.set_player_value("display_name", steam_name)
					_save_manager.save_game()
					return false  # Name set from Steam, no prompt needed
	return existing_name.is_empty()

func _show_display_name_prompt():
	# Clear existing UI
	for child in get_children():
		child.queue_free()

	await get_tree().process_frame

	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.12, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 280)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.1, 0.16, 0.98)
	panel_style.border_color = Color(0.4, 0.35, 0.6, 0.8)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 30
	panel_style.content_margin_right = 30
	panel_style.content_margin_top = 30
	panel_style.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "Choose Your Name"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "This will be shown in Discord when you flex achievements"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(subtitle)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	var name_input = LineEdit.new()
	name_input.placeholder_text = "Enter your display name"
	name_input.custom_minimum_size = Vector2(0, 45)
	name_input.max_length = 20

	var input_style = StyleBoxFlat.new()
	input_style.bg_color = Color(0.15, 0.13, 0.2, 1.0)
	input_style.border_color = Color(0.3, 0.28, 0.4, 0.8)
	input_style.set_border_width_all(1)
	input_style.set_corner_radius_all(6)
	input_style.content_margin_left = 10
	input_style.content_margin_right = 10
	name_input.add_theme_stylebox_override("normal", input_style)
	vbox.add_child(name_input)

	var confirm_btn = Button.new()
	confirm_btn.text = "Let's Go!"
	confirm_btn.custom_minimum_size = Vector2(0, 45)
	confirm_btn.add_theme_font_size_override("font_size", 16)
	_style_button(confirm_btn)
	vbox.add_child(confirm_btn)

	# Connect signals
	var on_confirm = func():
		var display_name: String = name_input.text.strip_edges()
		if display_name.is_empty():
			display_name = "Player"
		if _save_manager:
			_save_manager.set_player_value("display_name", display_name)
			_save_manager.save_game()
		sign_in_completed.emit(true)
		queue_free()

	confirm_btn.pressed.connect(on_confirm)
	name_input.text_submitted.connect(func(_t): on_confirm.call())
	name_input.grab_focus()

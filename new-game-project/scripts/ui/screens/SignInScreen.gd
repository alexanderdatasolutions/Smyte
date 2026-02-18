# scripts/ui/screens/SignInScreen.gd
# Sign-in screen shown on game load - Steam/Email auth or skip to local save
class_name SignInScreen extends Control

signal sign_in_completed(signed_in: bool)

var _firebase_integration = null
var _save_manager = null
var _signing_in: bool = false
var _is_signup_mode: bool = false
var _needs_display_name: bool = false  # True after signup to prompt for display name
var _steam_available: bool = false

# UI References - Auth
var _steam_button: Button
var _email_section: VBoxContainer
var _email_input: LineEdit
var _password_input: LineEdit
var _auth_button: Button
var _toggle_button: Button
var _skip_button: Button
var _status_label: Label
var _or_divider: HBoxContainer

# UI References - Display Name (shown after signup)
var _display_name_container: VBoxContainer
var _display_name_input: LineEdit
var _display_name_button: Button

func _ready():
	_check_steam_available()
	_build_ui()
	_connect_firebase()
	_connect_save_manager()

func _check_steam_available():
	"""Check if Steam is running and available for auth"""
	# Use SteamManager which tracks if steamInitEx() succeeded, not just if client is running
	var registry: SystemRegistry = SystemRegistry.get_instance()
	if registry:
		var steam_manager: Node = registry.get_system("SteamManager")
		if steam_manager and steam_manager.is_steam_running():
			_steam_available = true
			print("SignInScreen: Steam detected - %s" % steam_manager.get_persona_name())
			return

	# Fallback: SteamManager not available yet
	if Engine.has_singleton("Steam"):
		# isSteamRunning() only checks if Steam client is running, NOT if our app authenticated
		# We need steamInitEx() to succeed first, so skip this fallback
		print("SignInScreen: Steam singleton exists but SteamManager not ready - skipping Steam auth")
	_steam_available = false

func _build_ui():
	# Full screen dark overlay
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.08, 0.06, 0.12, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Center container
	var center = CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Main panel - taller if showing both Steam and email
	var panel = PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(400, 520 if _steam_available else 450)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.1, 0.16, 0.98)
	panel_style.border_color = Color(0.4, 0.35, 0.6, 0.8)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 30
	panel_style.content_margin_right = 30
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	# VBox for content
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Logo/Title
	var title = Label.new()
	title.name = "Title"
	title.text = "SMYTE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	vbox.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "Battle of the Gods"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vbox.add_child(subtitle)

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer1)

	# Steam Sign In Button (if Steam available)
	if _steam_available:
		_steam_button = Button.new()
		_steam_button.name = "SteamButton"
		_steam_button.text = "Sign in with Steam"
		_steam_button.custom_minimum_size = Vector2(0, 50)
		_steam_button.add_theme_font_size_override("font_size", 18)
		_style_steam_button(_steam_button)
		_steam_button.pressed.connect(_on_steam_pressed)
		vbox.add_child(_steam_button)

		# "OR" divider
		_or_divider = HBoxContainer.new()
		_or_divider.name = "OrDivider"
		_or_divider.alignment = BoxContainer.ALIGNMENT_CENTER

		var line1 = HSeparator.new()
		line1.custom_minimum_size = Vector2(80, 0)
		line1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_or_divider.add_child(line1)

		var or_label = Label.new()
		or_label.text = "  OR  "
		or_label.add_theme_font_size_override("font_size", 12)
		or_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		_or_divider.add_child(or_label)

		var line2 = HSeparator.new()
		line2.custom_minimum_size = Vector2(80, 0)
		line2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_or_divider.add_child(line2)

		vbox.add_child(_or_divider)

	# Email section container
	_email_section = VBoxContainer.new()
	_email_section.name = "EmailSection"
	_email_section.add_theme_constant_override("separation", 10)
	vbox.add_child(_email_section)

	# Email input
	var email_label = Label.new()
	email_label.text = "Email"
	email_label.add_theme_font_size_override("font_size", 14)
	email_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	_email_section.add_child(email_label)

	_email_input = LineEdit.new()
	_email_input.name = "EmailInput"
	_email_input.placeholder_text = "Enter your email"
	_email_input.custom_minimum_size = Vector2(0, 40)
	_style_input(_email_input)
	_email_section.add_child(_email_input)

	# Password input
	var password_label = Label.new()
	password_label.text = "Password"
	password_label.add_theme_font_size_override("font_size", 14)
	password_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	_email_section.add_child(password_label)

	_password_input = LineEdit.new()
	_password_input.name = "PasswordInput"
	_password_input.placeholder_text = "Enter your password"
	_password_input.secret = true
	_password_input.custom_minimum_size = Vector2(0, 40)
	_style_input(_password_input)
	_password_input.text_submitted.connect(_on_password_submitted)
	_email_section.add_child(_password_input)

	# Sign In / Sign Up Button
	_auth_button = Button.new()
	_auth_button.name = "AuthButton"
	_auth_button.text = "Sign In with Email"
	_auth_button.custom_minimum_size = Vector2(0, 42)
	_auth_button.add_theme_font_size_override("font_size", 15)
	_style_primary_button(_auth_button)
	_auth_button.pressed.connect(_on_auth_pressed)
	_email_section.add_child(_auth_button)

	# Toggle between Sign In / Sign Up
	_toggle_button = Button.new()
	_toggle_button.name = "ToggleButton"
	_toggle_button.text = "Don't have an account? Sign Up"
	_toggle_button.flat = true
	_toggle_button.add_theme_font_size_override("font_size", 12)
	_toggle_button.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8))
	_toggle_button.pressed.connect(_on_toggle_mode)
	_email_section.add_child(_toggle_button)

	# Status label (in main vbox, not email section)
	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.6))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_status_label)

	# Skip Button
	_skip_button = Button.new()
	_skip_button.name = "SkipButton"
	_skip_button.text = "Play Offline (Skip)"
	_skip_button.custom_minimum_size = Vector2(0, 35)
	_skip_button.add_theme_font_size_override("font_size", 13)
	_style_secondary_button(_skip_button)
	_skip_button.pressed.connect(_on_skip_pressed)
	vbox.add_child(_skip_button)

func _style_input(input: LineEdit):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.13, 0.2, 1.0)
	style.border_color = Color(0.3, 0.28, 0.4, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	input.add_theme_stylebox_override("normal", style)

	var focus_style = style.duplicate()
	focus_style.border_color = Color(0.4, 0.5, 0.8, 1.0)
	input.add_theme_stylebox_override("focus", focus_style)

func _style_primary_button(btn: Button):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.5, 0.8, 1.0)
	style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", style)

	var hover = style.duplicate()
	hover.bg_color = Color(0.35, 0.55, 0.9, 1.0)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed = style.duplicate()
	pressed.bg_color = Color(0.25, 0.45, 0.7, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled = style.duplicate()
	disabled.bg_color = Color(0.2, 0.2, 0.25, 0.5)
	btn.add_theme_stylebox_override("disabled", disabled)

func _style_secondary_button(btn: Button):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.16, 0.22, 0.8)
	style.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))

	var hover = style.duplicate()
	hover.bg_color = Color(0.22, 0.2, 0.28, 0.9)
	btn.add_theme_stylebox_override("hover", hover)

func _style_steam_button(btn: Button):
	# Steam brand color is a dark blue/teal
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.2, 0.3, 1.0)  # Steam dark blue
	style.set_corner_radius_all(8)
	style.border_color = Color(0.2, 0.4, 0.6, 0.8)
	style.set_border_width_all(2)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))

	var hover = style.duplicate()
	hover.bg_color = Color(0.15, 0.3, 0.45, 1.0)
	hover.border_color = Color(0.3, 0.5, 0.7, 1.0)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed = style.duplicate()
	pressed.bg_color = Color(0.08, 0.15, 0.25, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled = style.duplicate()
	disabled.bg_color = Color(0.15, 0.15, 0.2, 0.5)
	btn.add_theme_stylebox_override("disabled", disabled)

func _connect_firebase():
	var system_registry_script = load("res://scripts/systems/core/SystemRegistry.gd")
	if not system_registry_script:
		return

	var registry = system_registry_script.get_instance()
	if not registry:
		return

	_firebase_integration = registry.get_system("FirebaseIntegration")
	if _firebase_integration:
		_firebase_integration.sign_in_completed.connect(_on_sign_in_completed)
		_firebase_integration.sign_in_failed.connect(_on_sign_in_failed)

		# Check if already signed in
		if _firebase_integration.is_signed_in():
			_set_status("Already signed in!")
			await get_tree().create_timer(0.5).timeout
			sign_in_completed.emit(true)
			queue_free()
			return

		# Auto sign-in with Steam if available (no button click needed)
		if _steam_available and _firebase_integration.is_steam_available():
			_auto_sign_in_steam()

func _auto_sign_in_steam():
	"""Automatically sign in with Steam - seamless for PC players"""
	_signing_in = true
	_set_buttons_enabled(false)
	_set_status("Signing in with Steam...")

	# Small delay so user sees the status
	await get_tree().create_timer(0.3).timeout
	_firebase_integration.sign_in_with_steam()

func _on_steam_pressed():
	"""Handle Steam sign-in button press"""
	if _signing_in:
		return

	if not _firebase_integration:
		_set_status("Firebase not available")
		return

	if not _firebase_integration.is_steam_available():
		_set_status("Steam is not running")
		return

	_signing_in = true
	_set_buttons_enabled(false)
	_set_status("Signing in with Steam...")
	_firebase_integration.sign_in_with_steam()

func _on_toggle_mode():
	_is_signup_mode = not _is_signup_mode
	if _is_signup_mode:
		_auth_button.text = "Create Account"
		_toggle_button.text = "Already have an account? Sign In"
	else:
		_auth_button.text = "Sign In with Email"
		_toggle_button.text = "Don't have an account? Sign Up"
	_set_status("")

func _on_password_submitted(_text: String):
	_on_auth_pressed()

func _on_auth_pressed():
	if _signing_in:
		return

	var email = _email_input.text.strip_edges()
	var password = _password_input.text

	if email.is_empty():
		_set_status("Please enter your email")
		return

	if password.is_empty():
		_set_status("Please enter your password")
		return

	if password.length() < 6:
		_set_status("Password must be at least 6 characters")
		return

	if not _firebase_integration:
		_set_status("Firebase not available")
		return

	_signing_in = true
	_set_buttons_enabled(false)

	if _is_signup_mode:
		_set_status("Creating account...")
		_firebase_integration.sign_up_with_email(email, password)
	else:
		_set_status("Signing in...")
		_firebase_integration.sign_in_with_email(email, password)

func _on_skip_pressed():
	if _signing_in:
		return

	sign_in_completed.emit(false)
	queue_free()

func _on_sign_in_completed(_user_data: Dictionary):
	_signing_in = false
	_status_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	_set_status("Loading cloud save...")

	# Wait a moment for cloud save manager to initialize
	await get_tree().create_timer(0.3).timeout

	# Load from cloud (authoritative source - no local file editing)
	if _firebase_integration and _firebase_integration.is_cloud_save_ready():
		# Connect to cloud load signals (one-shot)
		_firebase_integration.cloud_load_completed.connect(_on_cloud_data_loaded, CONNECT_ONE_SHOT)
		_firebase_integration.cloud_load_failed.connect(_on_cloud_load_failed, CONNECT_ONE_SHOT)
		_firebase_integration.cloud_save_not_found.connect(_on_cloud_save_not_found, CONNECT_ONE_SHOT)
		_firebase_integration.load_from_cloud()
	else:
		# Cloud not ready - proceed anyway (new user or offline)
		_on_cloud_save_not_found()

func _on_cloud_data_loaded(save_data: Dictionary):
	"""Cloud data loaded - apply it and continue"""
	_set_status("Welcome back!")

	# Apply cloud data via SaveManager
	if _save_manager and not save_data.is_empty():
		_save_manager.apply_save_data(save_data)

	await get_tree().create_timer(0.3).timeout
	_finish_sign_in()

func _on_cloud_load_failed(_error: String):
	"""Cloud load failed - proceed with fresh data"""
	_set_status("Welcome!")
	await get_tree().create_timer(0.3).timeout
	_finish_sign_in()

func _on_cloud_save_not_found():
	"""No cloud save - new user"""
	_set_status("Welcome, new player!")
	await get_tree().create_timer(0.3).timeout
	_finish_sign_in()

func _finish_sign_in():
	"""Final step - check display name and proceed"""
	if _check_needs_display_name():
		_show_display_name_prompt()
	else:
		sign_in_completed.emit(true)
		queue_free()

func _on_sign_in_failed(error: String):
	_signing_in = false
	_status_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5))

	# Make error messages more user-friendly
	if "EMAIL_NOT_FOUND" in error or "INVALID_LOGIN_CREDENTIALS" in error:
		_set_status("Invalid email or password")
	elif "EMAIL_EXISTS" in error:
		_set_status("Email already registered. Try signing in.")
	elif "WEAK_PASSWORD" in error:
		_set_status("Password too weak (min 6 characters)")
	elif "INVALID_EMAIL" in error:
		_set_status("Invalid email format")
	else:
		_set_status(error)

	_set_buttons_enabled(true)

func _set_status(text: String):
	if _status_label:
		_status_label.text = text

func _set_buttons_enabled(enabled: bool):
	if _steam_button:
		_steam_button.disabled = not enabled
	if _auth_button:
		_auth_button.disabled = not enabled
	if _skip_button:
		_skip_button.disabled = not enabled
	if _toggle_button:
		_toggle_button.disabled = not enabled
	if _email_input:
		_email_input.editable = enabled
	if _password_input:
		_password_input.editable = enabled

func _connect_save_manager():
	var system_registry_script = load("res://scripts/systems/core/SystemRegistry.gd")
	if not system_registry_script:
		return
	var registry = system_registry_script.get_instance()
	if registry:
		_save_manager = registry.get_system("SaveManager")

func _check_needs_display_name() -> bool:
	"""Check if user needs to set a display name (cloud data already loaded)"""
	if not _save_manager:
		_connect_save_manager()
	if not _save_manager:
		return true  # Assume they need one if we can't check

	# Cloud data is already loaded - just check in-memory player_data
	var existing_name: String = _save_manager.get_player_value("display_name", "")
	return existing_name.is_empty()

func _show_display_name_prompt():
	"""Show the display name input UI"""
	_needs_display_name = true

	# Hide auth UI
	_email_input.get_parent().get_parent().visible = false  # Hide the panel

	# Create display name panel
	var center = get_node("CenterContainer")

	var panel = PanelContainer.new()
	panel.name = "DisplayNamePanel"
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

	_display_name_container = VBoxContainer.new()
	_display_name_container.add_theme_constant_override("separation", 15)
	panel.add_child(_display_name_container)

	# Title
	var title = Label.new()
	title.text = "Choose Your Name"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	_display_name_container.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "This will be shown in the Discord when you flex achievements"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD
	_display_name_container.add_child(subtitle)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	_display_name_container.add_child(spacer)

	# Input
	_display_name_input = LineEdit.new()
	_display_name_input.placeholder_text = "Enter your display name"
	_display_name_input.custom_minimum_size = Vector2(0, 45)
	_display_name_input.max_length = 20
	_style_input(_display_name_input)
	_display_name_input.text_submitted.connect(_on_display_name_submitted)
	_display_name_container.add_child(_display_name_input)

	# Button
	_display_name_button = Button.new()
	_display_name_button.text = "Let's Go!"
	_display_name_button.custom_minimum_size = Vector2(0, 45)
	_display_name_button.add_theme_font_size_override("font_size", 16)
	_style_primary_button(_display_name_button)
	_display_name_button.pressed.connect(_on_display_name_confirmed)
	_display_name_container.add_child(_display_name_button)

	# Focus the input
	_display_name_input.grab_focus()

func _on_display_name_submitted(_text: String):
	_on_display_name_confirmed()

func _on_display_name_confirmed():
	var display_name: String = _display_name_input.text.strip_edges()

	if display_name.is_empty():
		display_name = "Player"  # Default if they skip

	# Save to SaveManager
	if _save_manager:
		_save_manager.set_player_value("display_name", display_name)
		_save_manager.save_game()

	# Set on analytics for tracking
	if _firebase_integration and _firebase_integration.analytics:
		_firebase_integration.analytics.set_display_name(display_name)

	# Done - proceed to game
	sign_in_completed.emit(true)
	queue_free()

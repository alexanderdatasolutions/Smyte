# scripts/ui/sacrifice/SacrificeSelectionScreen.gd
# Dedicated screen for detailed sacrifice material selection - under 500 lines
class_name SacrificeSelectionScreen
extends Control

signal sacrifice_completed(target_god: God, materials: Array[God])
signal back_requested

var target_god: God
var sacrifice_panel: SacrificePanel
var back_button: Button
var title_label: Label

# Systems
var sacrifice_manager: SacrificeManager
var ui_manager: UIManager

func _ready():
	_initialize_systems()
	_setup_ui()

func _initialize_systems():
	var system_registry = SystemRegistry.get_instance()
	sacrifice_manager = system_registry.get_system("SacrificeManager")
	ui_manager = system_registry.get_system("UIManager")

func _setup_ui():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 20)
	add_child(main_vbox)
	
	# Header
	_create_header(main_vbox)
	
	# Main sacrifice panel  
	sacrifice_panel = SacrificePanel.new() as SacrificePanel
	sacrifice_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(sacrifice_panel)
	
	# Connect signals
	sacrifice_panel.sacrifice_requested.connect(_on_sacrifice_requested)

func _create_header(parent: Control):
	var header = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 60)
	parent.add_child(header)
	
	# Back button
	back_button = Button.new()
	back_button.text = "← BACK"
	back_button.custom_minimum_size = Vector2(100, 40)
	back_button.add_theme_font_size_override("font_size", 14)
	back_button.pressed.connect(_on_back_pressed)
	header.add_child(back_button)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	# Title
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.text = "SACRIFICE SELECTION"
	header.add_child(title_label)
	
	# Spacer
	var spacer2 = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer2)

# Public interface
func show_for_god(god: God):
	target_god = god
	title_label.text = "SACRIFICE TO: %s" % god.name.to_upper()
	
	if sacrifice_panel:
		sacrifice_panel.initialize_with_god(god)
	
	visible = true

func hide_screen():
	visible = false

# Event handlers
func _on_back_pressed():
	back_requested.emit()

func _on_sacrifice_requested(target: God, materials: Array[God]):
	if not sacrifice_manager:
		return
	
	# Perform the actual sacrifice
	var result = sacrifice_manager.perform_sacrifice(target, materials)
	
	if result.success:
		# Show success feedback
		_show_success_notification(target, materials, result)
		
		# Emit completion signal
		sacrifice_completed.emit(target, materials)
		
		# Auto-close after brief delay
		await get_tree().create_timer(2.0).timeout
		back_requested.emit()
	else:
		# Show error
		_show_error_notification(result.error)

func _show_success_notification(target: God, materials: Array[God], result: Dictionary):
	var message = "Successfully sacrificed %d gods to %s!\n" % [materials.size(), target.name]
	
	if result.has("xp_gained"):
		message += "XP Gained: %d\n" % result.xp_gained
	
	if result.has("levels_gained") and result.levels_gained > 0:
		message += "Levels Gained: %d\n" % result.levels_gained
	
	if result.has("new_level"):
		message += "New Level: %d" % result.new_level
	
	_show_notification(message, Color.GREEN)

func _show_error_notification(error: String):
	_show_notification("Sacrifice failed: %s" % error, Color.RED)

func _show_notification(message: String, color: Color):
	# Create temporary notification overlay
	var notif_panel = PanelContainer.new()
	notif_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	notif_panel.custom_minimum_size = Vector2(400, 200)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = color
	notif_panel.add_theme_stylebox_override("panel", style)
	
	var label = Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 16)
	label.modulate = color
	notif_panel.add_child(label)
	
	add_child(notif_panel)
	
	# Animate and auto-remove
	notif_panel.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(notif_panel, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.0)
	tween.tween_property(notif_panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): notif_panel.queue_free())

# scripts/ui/battle/BattleLog.gd
# Battle Log - displays detailed combat events in a scrollable list
extends Control
class_name BattleLog

const MAX_ENTRIES = 50  # Keep last 50 entries to prevent memory bloat

var log_entries: Array[Dictionary] = []
var scroll_container: ScrollContainer
var log_container: VBoxContainer
var is_expanded: bool = true
var toggle_button: Button
var log_panel: PanelContainer

func _ready():
	_create_ui()
	# Start collapsed
	is_expanded = false
	_update_expanded_state()

func _create_ui():
	# Main container
	set_anchors_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(0, 120)

	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 2)
	add_child(main_vbox)

	# Toggle button
	toggle_button = Button.new()
	toggle_button.text = "Battle Log ▼"
	toggle_button.custom_minimum_size = Vector2(0, 24)
	toggle_button.pressed.connect(_on_toggle_pressed)
	_style_toggle_button()
	main_vbox.add_child(toggle_button)

	# Log panel
	log_panel = PanelContainer.new()
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_log_panel()
	main_vbox.add_child(log_panel)

	# Scroll container
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_panel.add_child(scroll_container)

	# Log entries container
	log_container = VBoxContainer.new()
	log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_container.add_theme_constant_override("separation", 2)
	scroll_container.add_child(log_container)

func _style_toggle_button():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.2, 0.95)
	style.border_color = Color(0.3, 0.25, 0.4, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	toggle_button.add_theme_stylebox_override("normal", style)
	toggle_button.add_theme_stylebox_override("hover", style)
	toggle_button.add_theme_stylebox_override("pressed", style)
	toggle_button.add_theme_font_size_override("font_size", 11)
	toggle_button.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))

func _style_log_panel():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.1, 0.9)
	style.border_color = Color(0.2, 0.18, 0.25, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	log_panel.add_theme_stylebox_override("panel", style)

func _on_toggle_pressed():
	is_expanded = not is_expanded
	_update_expanded_state()

func _update_expanded_state():
	if is_expanded:
		toggle_button.text = "Battle Log ▲"
		log_panel.visible = true
		custom_minimum_size.y = 120
	else:
		toggle_button.text = "Battle Log ▼"
		log_panel.visible = false
		custom_minimum_size.y = 24

# === LOG ENTRY METHODS ===

func add_turn_start(unit_name: String, is_player: bool):
	"""Log turn start"""
	var color = Color(0.5, 0.8, 1.0) if is_player else Color(1.0, 0.6, 0.5)
	_add_entry("--- %s's Turn ---" % unit_name, color, true)

func add_action_skipped(unit_name: String, reason: String):
	"""Log when a unit's action is skipped (stunned, etc.)"""
	_add_entry("%s cannot act (%s)" % [unit_name, reason], Color(0.7, 0.5, 0.5))

func add_attack(attacker: String, target: String, damage: int, is_crit: bool, is_glancing: bool, damage_result = null):
	"""Log a basic attack with optional damage breakdown on hover"""
	var crit_str = " CRIT!" if is_crit else ""
	var glance_str = " (glancing)" if is_glancing else ""
	var color = Color.GOLD if is_crit else Color(1.0, 0.9, 0.8)
	_add_entry("%s attacks %s for %d damage%s%s" % [attacker, target, damage, crit_str, glance_str], color, false, damage_result)

func add_skill_use(caster: String, skill_name: String):
	"""Log skill usage"""
	_add_entry("%s uses %s" % [caster, skill_name], Color(0.6, 0.8, 1.0))

func add_skill_damage(target: String, damage: int, is_crit: bool, is_glancing: bool, damage_result = null):
	"""Log skill damage with optional damage breakdown on hover"""
	var crit_str = " CRIT!" if is_crit else ""
	var glance_str = " (glancing)" if is_glancing else ""
	var color = Color.GOLD if is_crit else Color(1.0, 0.7, 0.7)
	_add_entry("  → %s takes %d damage%s%s" % [target, damage, crit_str, glance_str], color, false, damage_result)

func add_heal(target: String, amount: int, source: String = ""):
	"""Log healing"""
	var src_str = " from %s" % source if source else ""
	_add_entry("%s healed for %d HP%s" % [target, amount, src_str], Color(0.5, 1.0, 0.5))

func add_status_applied(target: String, effect_name: String, duration: int):
	"""Log status effect applied"""
	_add_entry("%s gains %s (%d turns)" % [target, effect_name, duration], Color(0.8, 0.6, 1.0))

func add_status_failed(target: String, effect_name: String):
	"""Log status effect failed to apply"""
	_add_entry("%s resists %s" % [target, effect_name], Color(0.5, 0.5, 0.6))

func add_status_expired(target: String, effect_name: String):
	"""Log status effect expired"""
	_add_entry("%s's %s wore off" % [target, effect_name], Color(0.6, 0.6, 0.7))

func add_dot_damage(target: String, damage: int, effect_name: String):
	"""Log damage over time"""
	_add_entry("%s takes %d damage from %s" % [target, damage, effect_name], Color(0.9, 0.5, 0.3))

func add_hot_heal(target: String, amount: int, effect_name: String):
	"""Log heal over time"""
	_add_entry("%s heals %d HP from %s" % [target, amount, effect_name], Color(0.4, 0.9, 0.4))

func add_atb_change(target: String, amount: int, is_steal: bool = false, caster: String = ""):
	"""Log ATB (turn bar) changes"""
	if is_steal:
		_add_entry("%s steals %d%% ATB from %s" % [caster, amount, target], Color(0.8, 0.8, 0.4))
	else:
		_add_entry("%s's ATB reduced by %d%%" % [target, amount], Color(0.7, 0.7, 0.5))

func add_life_drain(caster: String, amount: int):
	"""Log life drain healing"""
	_add_entry("%s drains %d HP" % [caster, amount], Color(0.6, 0.9, 0.6))

func add_unit_defeated(unit_name: String):
	"""Log unit defeat"""
	_add_entry("%s is defeated!" % unit_name, Color(0.8, 0.3, 0.3), true)

func add_wave_start(wave_num: int, total_waves: int):
	"""Log wave start"""
	_add_entry("=== Wave %d/%d ===" % [wave_num, total_waves], Color(1.0, 0.9, 0.5), true)

func add_battle_end(victory: bool):
	"""Log battle end"""
	if victory:
		_add_entry("=== VICTORY! ===", Color(0.3, 1.0, 0.3), true)
	else:
		_add_entry("=== DEFEAT ===", Color(1.0, 0.3, 0.3), true)

func clear_log():
	"""Clear all log entries"""
	log_entries.clear()
	for child in log_container.get_children():
		child.queue_free()

# === INTERNAL ===

var active_tooltip: PanelContainer = null  # Currently shown tooltip

func _add_entry(text: String, color: Color, bold: bool = false, damage_result = null):
	"""Add a log entry with optional damage breakdown tooltip"""
	var entry = {
		"text": text,
		"color": color,
		"bold": bold,
		"timestamp": Time.get_ticks_msec(),
		"damage_result": damage_result
	}
	log_entries.append(entry)

	# Trim old entries
	while log_entries.size() > MAX_ENTRIES:
		log_entries.pop_front()
		if log_container.get_child_count() > 0:
			log_container.get_child(0).queue_free()

	# Create a container for the entry if it has hover data
	if damage_result != null:
		var entry_container = _create_hoverable_entry(text, color, damage_result)
		log_container.add_child(entry_container)
	else:
		# Create simple label
		var label = Label.new()
		label.text = text
		label.add_theme_color_override("font_color", color)
		label.add_theme_font_size_override("font_size", 10)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		log_container.add_child(label)

	# Auto-scroll to bottom
	await get_tree().process_frame
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

func _create_hoverable_entry(text: String, color: Color, damage_result) -> HBoxContainer:
	"""Create a log entry that shows tooltip on hover"""
	# Use HBoxContainer for proper auto-sizing
	var container = HBoxContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Create label
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 10)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(label)

	# Store damage_result in metadata for tooltip
	container.set_meta("damage_result", damage_result)

	# Connect hover events
	container.mouse_entered.connect(_on_entry_hover_start.bind(container))
	container.mouse_exited.connect(_on_entry_hover_end)

	return container

func _on_entry_hover_start(entry_container: Control):
	"""Show tooltip when hovering over damage entry"""
	# Hide any existing tooltip
	_on_entry_hover_end()

	var damage_result = entry_container.get_meta("damage_result")
	if damage_result == null:
		return

	# Create tooltip
	active_tooltip = _create_damage_tooltip(damage_result)

	# Add to scene tree first so we can get its size
	get_tree().current_scene.add_child(active_tooltip)

	# Wait a frame for size calculation
	await get_tree().process_frame

	# Position tooltip above the entry, keeping it on screen
	var entry_pos = entry_container.global_position
	var viewport_size = get_viewport().get_visible_rect().size
	var tooltip_size = active_tooltip.size

	# Try to position above the entry
	var tooltip_y = entry_pos.y - tooltip_size.y - 10
	if tooltip_y < 50:  # Too close to top, position below instead
		tooltip_y = entry_pos.y + entry_container.size.y + 10

	# Keep X position on screen
	var tooltip_x = entry_pos.x + 20
	if tooltip_x + tooltip_size.x > viewport_size.x - 10:
		tooltip_x = viewport_size.x - tooltip_size.x - 10

	active_tooltip.global_position = Vector2(tooltip_x, tooltip_y)

func _on_entry_hover_end():
	"""Hide tooltip when no longer hovering"""
	if active_tooltip and is_instance_valid(active_tooltip):
		active_tooltip.queue_free()
		active_tooltip = null

func _create_damage_tooltip(damage_result) -> PanelContainer:
	"""Create a tooltip panel showing damage calculation breakdown"""
	var panel = PanelContainer.new()
	panel.z_index = 300

	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.15, 0.98)
	style.border_color = Color(0.5, 0.4, 0.6, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)

	# Content
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	panel.add_child(content)

	# Get the calculation breakdown
	var breakdown_text = damage_result.get_calculation_breakdown()
	var lines = breakdown_text.split("\n")

	for line in lines:
		var label = Label.new()
		label.text = line
		label.add_theme_font_size_override("font_size", 11)

		# Style header lines differently
		if line.contains("→") or line.contains("Final:"):
			label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
			label.add_theme_font_size_override("font_size", 12)
		elif line.contains("ATK") or line.contains("DEF") or line.contains("Mult") or line.contains("Reduction"):
			label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		elif line.contains("Crit") or line.contains("Glancing"):
			label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
		elif line.is_empty():
			label.custom_minimum_size.y = 4
		else:
			label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))

		content.add_child(label)

	return panel

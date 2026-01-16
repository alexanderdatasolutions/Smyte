# GodTaskAssignmentPanel.gd - Panel for selecting a god to assign to a task
# Shows available gods with their traits and task bonuses
extends PanelContainer
class_name GodTaskAssignmentPanel

signal god_selected(god_id: String)
signal cancelled()

# ==============================================================================
# STATE
# ==============================================================================
var _task: Task = null
var _territory_id: String = ""
var _available_gods: Array = []

# UI Elements
var _title_label: Label
var _task_info_label: Label
var _gods_container: VBoxContainer
var _scroll_container: ScrollContainer
var _cancel_button: Button
var _no_gods_label: Label

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready() -> void:
	_create_ui()
	_apply_styling()
	visible = false

func _create_ui() -> void:
	custom_minimum_size = Vector2(400, 500)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = "SELECT GOD FOR TASK"
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.modulate = Color(0.9, 0.85, 0.7)
	vbox.add_child(_title_label)

	# Task info
	_task_info_label = Label.new()
	_task_info_label.add_theme_font_size_override("font_size", 14)
	_task_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_task_info_label.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(_task_info_label)

	# Separator
	var sep = HSeparator.new()
	sep.modulate = Color(0.4, 0.35, 0.5)
	vbox.add_child(sep)

	# Scroll container for gods list
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(_scroll_container)

	_gods_container = VBoxContainer.new()
	_gods_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gods_container.add_theme_constant_override("separation", 8)
	_scroll_container.add_child(_gods_container)

	# No gods message
	_no_gods_label = Label.new()
	_no_gods_label.text = "No available gods can perform this task.\nCheck trait requirements or god levels."
	_no_gods_label.add_theme_font_size_override("font_size", 14)
	_no_gods_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_gods_label.modulate = Color(0.7, 0.5, 0.5)
	_no_gods_label.visible = false
	vbox.add_child(_no_gods_label)

	# Cancel button
	_cancel_button = Button.new()
	_cancel_button.text = "CANCEL"
	_cancel_button.custom_minimum_size = Vector2(0, 40)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	vbox.add_child(_cancel_button)

func _apply_styling() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.98)
	style.border_color = Color(0.5, 0.45, 0.6, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	add_theme_stylebox_override("panel", style)

	# Cancel button
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.3, 0.2, 0.2, 0.9)
	btn_style.border_color = Color(0.5, 0.3, 0.3, 0.8)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(4)
	_cancel_button.add_theme_stylebox_override("normal", btn_style)

# ==============================================================================
# PUBLIC METHODS
# ==============================================================================

func show_for_task(task: Task, territory_id: String, gods: Array) -> void:
	_task = task
	_territory_id = territory_id
	_available_gods = gods

	_refresh_display()
	visible = true

func hide_panel() -> void:
	visible = false
	_task = null
	_available_gods.clear()

# ==============================================================================
# PRIVATE METHODS
# ==============================================================================

func _refresh_display() -> void:
	if not _task:
		return

	_task_info_label.text = _task.name

	# Clear existing god cards
	for child in _gods_container.get_children():
		child.queue_free()

	# Filter gods that can perform this task and aren't busy
	var eligible_gods = _filter_eligible_gods()

	_no_gods_label.visible = eligible_gods.size() == 0

	# Create god cards
	for god in eligible_gods:
		var card = _create_god_card(god)
		_gods_container.add_child(card)

func _filter_eligible_gods() -> Array:
	var eligible = []
	var trait_manager = _get_trait_manager()

	for god in _available_gods:
		# Skip if god can't perform this task
		if not _task.can_god_perform(god):
			continue

		# Skip if god is already at max tasks
		if trait_manager:
			var multitask_info = trait_manager.get_multitask_info(god)
			if god.get_current_task_count() >= multitask_info.count:
				continue
		elif god.is_working_on_task():
			continue

		# Skip if god is already on this task
		if god.is_assigned_to_task(_task.id):
			continue

		eligible.append(god)

	# Sort by task bonus (best first)
	if trait_manager:
		eligible.sort_custom(func(a, b):
			var bonus_a = trait_manager.get_task_bonus_for_god(a, _task.id)
			var bonus_b = trait_manager.get_task_bonus_for_god(b, _task.id)
			return bonus_a > bonus_b
		)

	return eligible

func _create_god_card(god: God) -> Control:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 70)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.11, 0.15, 0.9)
	style.border_color = Color(0.3, 0.28, 0.35, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	# God info section
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	# Name + level
	var name_label = Label.new()
	name_label.text = "%s (Lv.%d)" % [god.get_display_name(), god.level]
	name_label.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(name_label)

	# Traits
	var traits_text = "Traits: " + ", ".join(god.get_all_traits()) if god.get_trait_count() > 0 else "No traits"
	var traits_label = Label.new()
	traits_label.text = traits_text
	traits_label.add_theme_font_size_override("font_size", 11)
	traits_label.modulate = Color(0.7, 0.7, 0.7)
	info_vbox.add_child(traits_label)

	# Task bonus
	var trait_manager = _get_trait_manager()
	if trait_manager:
		var bonus = trait_manager.get_task_bonus_for_god(god, _task.id)
		if bonus > 0:
			var bonus_label = Label.new()
			bonus_label.text = "+%.0f%% task efficiency" % (bonus * 100)
			bonus_label.add_theme_font_size_override("font_size", 12)
			bonus_label.modulate = Color(0.5, 0.8, 0.5)
			info_vbox.add_child(bonus_label)

	# Current task status
	if god.is_working_on_task():
		var status_label = Label.new()
		status_label.text = "Currently working on %d task(s)" % god.get_current_task_count()
		status_label.add_theme_font_size_override("font_size", 11)
		status_label.modulate = Color(0.8, 0.7, 0.4)
		info_vbox.add_child(status_label)

	# Select button
	var select_btn = Button.new()
	select_btn.text = "SELECT"
	select_btn.custom_minimum_size = Vector2(80, 40)
	select_btn.pressed.connect(_on_god_selected.bind(god.id))
	hbox.add_child(select_btn)

	# Style select button
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.3, 0.4, 0.9)
	btn_style.border_color = Color(0.3, 0.45, 0.55, 0.8)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(4)
	select_btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.25, 0.4, 0.5, 0.95)
	btn_hover.border_color = Color(0.4, 0.55, 0.65, 1.0)
	btn_hover.set_border_width_all(1)
	btn_hover.set_corner_radius_all(4)
	select_btn.add_theme_stylebox_override("hover", btn_hover)

	return card

func _get_trait_manager() -> TraitManager:
	var registry = SystemRegistry.get_instance()
	if registry:
		return registry.get_system("TraitManager")
	return null

func _on_god_selected(god_id: String) -> void:
	god_selected.emit(god_id)
	hide_panel()

func _on_cancel_pressed() -> void:
	cancelled.emit()
	hide_panel()

# TaskCard.gd - UI component for displaying a task
# Shows task info, requirements, rewards, and assignment button
extends PanelContainer
class_name TaskCard

signal assign_requested(task_id: String)
signal details_requested(task_id: String)

# ==============================================================================
# STATE
# ==============================================================================
var _task: Task = null
var _territory_id: String = ""
var _is_available: bool = true
var _current_workers: int = 0

# UI Elements
var _name_label: Label
var _description_label: Label
var _category_label: Label
var _duration_label: Label
var _rewards_container: HBoxContainer
var _requirements_label: Label
var _workers_label: Label
var _assign_button: Button
var _progress_bar: ProgressBar

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready() -> void:
	_create_ui()
	_apply_styling()

func _create_ui() -> void:
	custom_minimum_size = Vector2(280, 180)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Header row (name + category)
	var header = HBoxContainer.new()
	vbox.add_child(header)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_name_label)

	_category_label = Label.new()
	_category_label.add_theme_font_size_override("font_size", 12)
	header.add_child(_category_label)

	# Description
	_description_label = Label.new()
	_description_label.add_theme_font_size_override("font_size", 11)
	_description_label.modulate = Color(0.7, 0.7, 0.7)
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_description_label.custom_minimum_size.y = 30
	vbox.add_child(_description_label)

	# Duration and workers row
	var info_row = HBoxContainer.new()
	vbox.add_child(info_row)

	_duration_label = Label.new()
	_duration_label.add_theme_font_size_override("font_size", 12)
	_duration_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(_duration_label)

	_workers_label = Label.new()
	_workers_label.add_theme_font_size_override("font_size", 12)
	info_row.add_child(_workers_label)

	# Requirements
	_requirements_label = Label.new()
	_requirements_label.add_theme_font_size_override("font_size", 11)
	_requirements_label.modulate = Color(0.8, 0.6, 0.4)
	vbox.add_child(_requirements_label)

	# Rewards preview
	_rewards_container = HBoxContainer.new()
	_rewards_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_rewards_container)

	# Progress bar (hidden until assigned)
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 8)
	_progress_bar.visible = false
	vbox.add_child(_progress_bar)

	# Assign button
	_assign_button = Button.new()
	_assign_button.text = "ASSIGN GOD"
	_assign_button.custom_minimum_size = Vector2(0, 32)
	_assign_button.pressed.connect(_on_assign_pressed)
	vbox.add_child(_assign_button)

func _apply_styling() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.11, 0.14, 0.95)
	style.border_color = Color(0.3, 0.28, 0.35, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)

	# Button styling
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.35, 0.25, 0.9)
	btn_style.border_color = Color(0.3, 0.5, 0.35, 0.8)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(4)
	_assign_button.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.25, 0.45, 0.3, 0.95)
	btn_hover.border_color = Color(0.4, 0.6, 0.45, 1.0)
	btn_hover.set_border_width_all(1)
	btn_hover.set_corner_radius_all(4)
	_assign_button.add_theme_stylebox_override("hover", btn_hover)

# ==============================================================================
# PUBLIC METHODS
# ==============================================================================

func setup(task: Task, territory_id: String, current_workers: int = 0) -> void:
	_task = task
	_territory_id = territory_id
	_current_workers = current_workers
	_refresh_display()

func set_available(available: bool) -> void:
	_is_available = available
	_assign_button.disabled = not available
	modulate.a = 1.0 if available else 0.6

func set_progress(progress: float) -> void:
	_progress_bar.visible = progress > 0
	_progress_bar.value = progress * 100

# ==============================================================================
# PRIVATE METHODS
# ==============================================================================

func _refresh_display() -> void:
	if not _task:
		return

	_name_label.text = _task.name
	_description_label.text = _task.description

	# Category with color
	_category_label.text = "[%s]" % _task.get_category_string().to_upper()
	_category_label.modulate = _get_category_color(_task.category)

	# Duration
	var duration_mins = _task.base_duration_seconds / 60
	if duration_mins >= 60:
		@warning_ignore("integer_division")
		_duration_label.text = "⏱ %dh %dm" % [duration_mins / 60, duration_mins % 60]
	else:
		_duration_label.text = "⏱ %dm" % duration_mins

	# Workers
	_workers_label.text = "👥 %d/%d" % [_current_workers, _task.max_concurrent_workers]

	# Requirements
	var reqs = []
	if _task.required_god_level > 1:
		reqs.append("Lv.%d" % _task.required_god_level)
	if _task.skill_level_required > 0:
		reqs.append("%s Lv.%d" % [_task.skill_id.capitalize(), _task.skill_level_required])
	if _task.required_traits.size() > 0:
		reqs.append("Trait: " + ", ".join(_task.required_traits))
	_requirements_label.text = "Requires: " + (", ".join(reqs) if reqs.size() > 0 else "None")

	# Rewards preview
	_update_rewards_display()

	# Update availability
	_assign_button.disabled = _current_workers >= _task.max_concurrent_workers

func _update_rewards_display() -> void:
	# Clear existing
	for child in _rewards_container.get_children():
		child.queue_free()

	if not _task:
		return

	# Show up to 3 resource rewards
	var count = 0
	for resource_id in _task.resource_rewards:
		if count >= 3:
			break
		var reward_label = Label.new()
		reward_label.text = "%s: %d" % [resource_id.replace("_", " ").capitalize(), _task.resource_rewards[resource_id]]
		reward_label.add_theme_font_size_override("font_size", 11)
		reward_label.modulate = Color(0.6, 0.8, 0.5)
		_rewards_container.add_child(reward_label)
		count += 1

	# Show XP
	if _task.experience_rewards.has("god_xp"):
		var xp_label = Label.new()
		xp_label.text = "+%d XP" % _task.experience_rewards["god_xp"]
		xp_label.add_theme_font_size_override("font_size", 11)
		xp_label.modulate = Color(0.5, 0.7, 0.9)
		_rewards_container.add_child(xp_label)

func _get_category_color(category: Task.TaskCategory) -> Color:
	match category:
		Task.TaskCategory.GATHERING: return Color(0.4, 0.7, 0.4)
		Task.TaskCategory.CRAFTING: return Color(0.8, 0.6, 0.3)
		Task.TaskCategory.RESEARCH: return Color(0.4, 0.6, 0.9)
		Task.TaskCategory.DEFENSE: return Color(0.8, 0.4, 0.4)
		Task.TaskCategory.SPECIAL: return Color(0.7, 0.4, 0.8)
		_: return Color.WHITE

func _on_assign_pressed() -> void:
	if _task:
		assign_requested.emit(_task.id)

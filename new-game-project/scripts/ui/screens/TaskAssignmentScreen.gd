# TaskAssignmentScreen.gd - Screen for managing task assignments in a territory
# Shows available tasks and allows assigning gods to work on them
extends Control
class_name TaskAssignmentScreen

signal back_pressed

# ==============================================================================
# CONSTANTS
# ==============================================================================
const TaskCardScript = preload("res://scripts/ui/tasks/TaskCard.gd")
const GodTaskAssignmentPanelScript = preload("res://scripts/ui/tasks/GodTaskAssignmentPanel.gd")

# ==============================================================================
# STATE
# ==============================================================================
var _territory_id: String = ""
var _selected_task_id: String = ""

# UI Elements
var _main_container: VBoxContainer
var _header_container: HBoxContainer
var _back_button: Button
var _title_label: Label
var _territory_info_label: Label
var _category_filter: OptionButton
var _tasks_scroll: ScrollContainer
var _tasks_grid: GridContainer
var _active_tasks_container: VBoxContainer
var _god_selection_panel: GodTaskAssignmentPanel

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready() -> void:
	_create_ui()
	_apply_styling()

func _create_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_main_container = VBoxContainer.new()
	_main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main_container.add_theme_constant_override("separation", 10)
	add_child(_main_container)

	# Header
	_create_header()

	# Territory info bar
	_create_info_bar()

	# Active tasks section
	_create_active_tasks_section()

	# Available tasks section
	_create_tasks_section()

	# God selection panel (overlay)
	_god_selection_panel = GodTaskAssignmentPanelScript.new()
	_god_selection_panel.set_anchors_preset(Control.PRESET_CENTER)
	_god_selection_panel.god_selected.connect(_on_god_selected_for_task)
	_god_selection_panel.cancelled.connect(_on_god_selection_cancelled)
	add_child(_god_selection_panel)

func _create_header() -> void:
	_header_container = HBoxContainer.new()
	_header_container.custom_minimum_size = Vector2(0, 50)
	_header_container.add_theme_constant_override("separation", 12)
	_main_container.add_child(_header_container)

	# Back button
	_back_button = Button.new()
	_back_button.text = "← BACK"
	_back_button.custom_minimum_size = Vector2(100, 40)
	_back_button.pressed.connect(_on_back_pressed)
	_header_container.add_child(_back_button)

	# Title
	_title_label = Label.new()
	_title_label.text = "TERRITORY TASKS"
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.modulate = Color(0.9, 0.85, 0.7)
	_header_container.add_child(_title_label)

	# Category filter
	_category_filter = OptionButton.new()
	_category_filter.custom_minimum_size = Vector2(150, 0)
	_category_filter.add_item("All Categories", 0)
	_category_filter.add_item("Gathering", 1)
	_category_filter.add_item("Crafting", 2)
	_category_filter.add_item("Research", 3)
	_category_filter.add_item("Defense", 4)
	_category_filter.add_item("Special", 5)
	_category_filter.item_selected.connect(_on_category_filter_changed)
	_header_container.add_child(_category_filter)

func _create_info_bar() -> void:
	var info_panel = PanelContainer.new()
	info_panel.custom_minimum_size = Vector2(0, 40)
	_main_container.add_child(info_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	info_panel.add_child(margin)

	_territory_info_label = Label.new()
	_territory_info_label.add_theme_font_size_override("font_size", 14)
	margin.add_child(_territory_info_label)

	# Style info panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.15, 0.9)
	style.border_color = Color(0.3, 0.35, 0.4, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	info_panel.add_theme_stylebox_override("panel", style)

func _create_active_tasks_section() -> void:
	var section_label = Label.new()
	section_label.text = "ACTIVE TASKS"
	section_label.add_theme_font_size_override("font_size", 16)
	section_label.modulate = Color(0.7, 0.8, 0.6)
	_main_container.add_child(section_label)

	_active_tasks_container = VBoxContainer.new()
	_active_tasks_container.add_theme_constant_override("separation", 8)
	_active_tasks_container.custom_minimum_size = Vector2(0, 100)
	_main_container.add_child(_active_tasks_container)

func _create_tasks_section() -> void:
	var section_label = Label.new()
	section_label.text = "AVAILABLE TASKS"
	section_label.add_theme_font_size_override("font_size", 16)
	section_label.modulate = Color(0.6, 0.7, 0.8)
	_main_container.add_child(section_label)

	_tasks_scroll = ScrollContainer.new()
	_tasks_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tasks_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_main_container.add_child(_tasks_scroll)

	_tasks_grid = GridContainer.new()
	_tasks_grid.columns = 3
	_tasks_grid.add_theme_constant_override("h_separation", 12)
	_tasks_grid.add_theme_constant_override("v_separation", 12)
	_tasks_scroll.add_child(_tasks_grid)

func _apply_styling() -> void:
	# Back button
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.12, 0.18, 0.9)
	btn_style.border_color = Color(0.4, 0.35, 0.5, 0.8)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(4)
	_back_button.add_theme_stylebox_override("normal", btn_style)

# ==============================================================================
# PUBLIC METHODS
# ==============================================================================

func setup_for_territory(territory_id: String) -> void:
	_territory_id = territory_id
	_refresh_display()

func refresh() -> void:
	_refresh_display()

# ==============================================================================
# PRIVATE METHODS
# ==============================================================================

func _refresh_display() -> void:
	_update_territory_info()
	_refresh_active_tasks()
	_refresh_available_tasks()

func _update_territory_info() -> void:
	var territory_manager = _get_territory_manager()
	if not territory_manager:
		return

	var level = territory_manager.get_territory_level(_territory_id)
	var max_slots = territory_manager.get_max_task_slots(_territory_id)
	var working_gods = territory_manager.get_working_gods(_territory_id)

	_title_label.text = "TERRITORY TASKS - %s" % _territory_id.to_upper()
	_territory_info_label.text = "Level %d | Task Slots: %d/%d | Buildings: %s" % [
		level,
		working_gods.size(),
		max_slots,
		", ".join(territory_manager.get_territory_buildings(_territory_id))
	]

func _refresh_active_tasks() -> void:
	# Clear existing
	for child in _active_tasks_container.get_children():
		child.queue_free()

	var task_manager = _get_task_assignment_manager()
	var collection_manager = _get_collection_manager()
	if not task_manager or not collection_manager:
		return

	# Get all gods working in this territory
	var territory_manager = _get_territory_manager()
	if not territory_manager:
		return

	var working_god_ids = territory_manager.get_working_gods(_territory_id)

	if working_god_ids.size() == 0:
		var no_tasks_label = Label.new()
		no_tasks_label.text = "No active tasks. Assign gods to start working!"
		no_tasks_label.modulate = Color(0.6, 0.6, 0.6)
		_active_tasks_container.add_child(no_tasks_label)
		return

	# Create active task cards
	for god_id in working_god_ids:
		var god = collection_manager.get_god_by_id(god_id)
		if not god:
			continue

		for task_id in god.current_tasks:
			var card = _create_active_task_card(god, task_id)
			_active_tasks_container.add_child(card)

func _create_active_task_card(god: God, task_id: String) -> Control:
	var task_manager = _get_task_assignment_manager()
	var current_task = task_manager.get_task(task_id) if task_manager else null

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 60)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.12, 0.9)
	style.border_color = Color(0.3, 0.45, 0.3, 0.8)
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

	# Info section
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var title_label = Label.new()
	title_label.text = "%s → %s" % [god.get_display_name(), current_task.name if current_task else task_id]
	title_label.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(title_label)

	# Progress
	var progress = task_manager.get_task_progress(god, task_id) if task_manager else 0.0
	var time_remaining = task_manager.get_time_remaining(god, task_id) if task_manager else 0

	var progress_bar = ProgressBar.new()
	progress_bar.value = progress * 100
	progress_bar.custom_minimum_size = Vector2(0, 12)
	info_vbox.add_child(progress_bar)

	var time_label = Label.new()
	if time_remaining > 0:
		@warning_ignore("integer_division")
		var mins = time_remaining / 60
		var secs = time_remaining % 60
		time_label.text = "%d:%02d remaining" % [mins, secs]
	else:
		time_label.text = "COMPLETE - Click to collect!"
		time_label.modulate = Color(0.5, 0.9, 0.5)
	time_label.add_theme_font_size_override("font_size", 11)
	info_vbox.add_child(time_label)

	# Collect/Cancel buttons
	var btn_vbox = VBoxContainer.new()
	hbox.add_child(btn_vbox)

	if task_manager and task_manager.is_task_complete(god, task_id):
		var collect_btn = Button.new()
		collect_btn.text = "COLLECT"
		collect_btn.custom_minimum_size = Vector2(80, 30)
		collect_btn.pressed.connect(_on_collect_task.bind(god.id, task_id))
		btn_vbox.add_child(collect_btn)
	else:
		var cancel_btn = Button.new()
		cancel_btn.text = "CANCEL"
		cancel_btn.custom_minimum_size = Vector2(80, 30)
		cancel_btn.pressed.connect(_on_cancel_task.bind(god.id, task_id))
		btn_vbox.add_child(cancel_btn)

	return card

func _refresh_available_tasks() -> void:
	# Clear existing
	for child in _tasks_grid.get_children():
		child.queue_free()

	var territory_manager = _get_territory_manager()
	var task_manager = _get_task_assignment_manager()
	if not territory_manager or not task_manager:
		return

	var available_tasks = territory_manager.get_available_tasks(_territory_id)
	var selected_category = _category_filter.get_selected_id()

	for task in available_tasks:
		# Filter by category
		if selected_category > 0:
			if task.category != (selected_category - 1):
				continue

		var current_workers = task_manager.get_task_count_in_territory(_territory_id, task.id)
		var card = TaskCardScript.new()
		card.setup(task, _territory_id, current_workers)
		card.assign_requested.connect(_on_task_assign_requested)
		_tasks_grid.add_child(card)

func _on_task_assign_requested(task_id: String) -> void:
	_selected_task_id = task_id

	var task_manager = _get_task_assignment_manager()
	var collection_manager = _get_collection_manager()
	if not task_manager or not collection_manager:
		return

	var selected_task = task_manager.get_task(task_id)
	if not selected_task:
		return

	var all_gods = collection_manager.get_all_gods()
	_god_selection_panel.show_for_task(selected_task, _territory_id, all_gods)

func _on_god_selected_for_task(god_id: String) -> void:
	var task_manager = _get_task_assignment_manager()
	var collection_manager = _get_collection_manager()
	if not task_manager or not collection_manager:
		return

	var god = collection_manager.get_god_by_id(god_id)
	if not god:
		return

	var success = task_manager.assign_god_to_task(god, _selected_task_id, _territory_id)
	if success:
		_refresh_display()

	_selected_task_id = ""

func _on_god_selection_cancelled() -> void:
	_selected_task_id = ""

func _on_collect_task(god_id: String, task_id: String) -> void:
	var task_manager = _get_task_assignment_manager()
	var collection_manager = _get_collection_manager()
	if not task_manager or not collection_manager:
		return

	var god = collection_manager.get_god_by_id(god_id)
	if not god:
		return

	var rewards = task_manager.collect_task_rewards(god, task_id)
	if rewards.size() > 0:
		# TODO: Show rewards popup
		_refresh_display()

func _on_cancel_task(god_id: String, task_id: String) -> void:
	var task_manager = _get_task_assignment_manager()
	var collection_manager = _get_collection_manager()
	if not task_manager or not collection_manager:
		return

	var god = collection_manager.get_god_by_id(god_id)
	if not god:
		return

	task_manager.unassign_god_from_task(god, task_id)
	_refresh_display()

func _on_category_filter_changed(_index: int) -> void:
	_refresh_available_tasks()

func _on_back_pressed() -> void:
	back_pressed.emit()

# ==============================================================================
# SYSTEM ACCESS
# ==============================================================================

func _get_territory_manager() -> TerritoryManager:
	var registry = SystemRegistry.get_instance()
	if registry:
		return registry.get_system("TerritoryManager")
	return null

func _get_task_assignment_manager() -> TaskAssignmentManager:
	var registry = SystemRegistry.get_instance()
	if registry:
		return registry.get_system("TaskAssignmentManager")
	return null

func _get_collection_manager():
	var registry = SystemRegistry.get_instance()
	if registry:
		return registry.get_system("CollectionManager")
	return null

# ==============================================================================
# PROCESS
# ==============================================================================

func _process(_delta: float) -> void:
	# Refresh active tasks periodically to update progress bars
	if visible and _territory_id != "":
		# Only refresh every second (controlled by task manager)
		pass

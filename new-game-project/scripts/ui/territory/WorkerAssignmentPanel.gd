# scripts/ui/territory/WorkerAssignmentPanel.gd
# Panel for managing worker assignments at hex nodes
extends Control
class_name WorkerAssignmentPanel

"""
WorkerAssignmentPanel.gd - Worker assignment UI for hex nodes
RULE 2: Single responsibility - ONLY manages worker UI for nodes
RULE 1: Under 500 lines
RULE 4: No data modification - delegates to TaskAssignmentManager

Shows:
- Current workers at node with tasks and progress
- Available gods (not in garrison/working elsewhere)
- Available tasks for node type
- Assign/unassign controls
"""

# ==============================================================================
# SIGNALS
# ==============================================================================
signal close_requested()
signal worker_assigned(node: HexNode, god_id: String, task_id: String)
signal worker_unassigned(node: HexNode, god_id: String)

# ==============================================================================
# PROPERTIES
# ==============================================================================
var current_node: HexNode = null

# System references
var collection_manager = null
var task_assignment_manager = null
var territory_manager = null

# UI components
var _main_container: VBoxContainer = null
var _header_label: Label = null
var _current_workers_container: VBoxContainer = null
var _available_gods_container: VBoxContainer = null
var _available_tasks_container: VBoxContainer = null
var _close_button: Button = null

# State
var _selected_god_id: String = ""
var _selected_task_id: String = ""

# ==============================================================================
# CONSTANTS
# ==============================================================================
const PANEL_WIDTH = 600
const PANEL_HEIGHT = 500
const BUTTON_HEIGHT = 36
const ITEM_HEIGHT = 40

# ==============================================================================
# INITIALIZATION
# ==============================================================================
func _ready() -> void:
	_init_systems()
	_build_ui()
	visible = false  # Start hidden

func _init_systems() -> void:
	"""Initialize system references"""
	var registry = SystemRegistry.get_instance()
	if not registry:
		push_error("WorkerAssignmentPanel: SystemRegistry not available")
		return

	collection_manager = registry.get_system("CollectionManager")
	task_assignment_manager = registry.get_system("TaskAssignmentManager")
	territory_manager = registry.get_system("TerritoryManager")

	if not collection_manager:
		push_error("WorkerAssignmentPanel: CollectionManager not found")
	if not task_assignment_manager:
		push_error("WorkerAssignmentPanel: TaskAssignmentManager not found")
	if not territory_manager:
		push_error("WorkerAssignmentPanel: TerritoryManager not found")

func _build_ui() -> void:
	"""Build the UI components"""
	custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)

	# Background panel
	var bg_panel = Panel.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	bg_style.border_width_left = 3
	bg_style.border_width_right = 3
	bg_style.border_width_top = 3
	bg_style.border_width_bottom = 3
	bg_style.border_color = Color(0.3, 0.5, 0.7, 1)
	bg_style.corner_radius_top_left = 8
	bg_style.corner_radius_top_right = 8
	bg_style.corner_radius_bottom_left = 8
	bg_style.corner_radius_bottom_right = 8
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	add_child(bg_panel)

	# Main scroll container
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 10
	scroll.offset_top = 10
	scroll.offset_right = -10
	scroll.offset_bottom = -10
	add_child(scroll)

	# Main container
	_main_container = VBoxContainer.new()
	_main_container.add_theme_constant_override("separation", 12)
	scroll.add_child(_main_container)

	# Header
	_build_header()

	# Current workers section
	_build_current_workers_section()

	# Separator
	_add_separator()

	# Available gods section
	_build_available_gods_section()

	# Separator
	_add_separator()

	# Available tasks section
	_build_available_tasks_section()

	# Separator
	_add_separator()

	# Action buttons
	_build_action_buttons()

func _build_header() -> void:
	"""Build header with title"""
	_header_label = Label.new()
	_header_label.text = "MANAGE WORKERS"
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_size_override("font_size", 20)
	_header_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1, 1))
	_main_container.add_child(_header_label)

func _build_current_workers_section() -> void:
	"""Build current workers display section"""
	var section_label = _create_section_label("Current Workers")
	_main_container.add_child(section_label)

	_current_workers_container = VBoxContainer.new()
	_current_workers_container.add_theme_constant_override("separation", 6)
	_main_container.add_child(_current_workers_container)

func _build_available_gods_section() -> void:
	"""Build available gods selection section"""
	var section_label = _create_section_label("Available Gods (Select One)")
	_main_container.add_child(section_label)

	_available_gods_container = VBoxContainer.new()
	_available_gods_container.add_theme_constant_override("separation", 4)
	_main_container.add_child(_available_gods_container)

func _build_available_tasks_section() -> void:
	"""Build available tasks selection section"""
	var section_label = _create_section_label("Available Tasks (Select One)")
	_main_container.add_child(section_label)

	_available_tasks_container = VBoxContainer.new()
	_available_tasks_container.add_theme_constant_override("separation", 4)
	_main_container.add_child(_available_tasks_container)

func _build_action_buttons() -> void:
	"""Build action buttons"""
	var button_container = HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 10)
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_main_container.add_child(button_container)

	# Assign button
	var assign_btn = _create_button("Assign Worker", Color(0.2, 0.7, 0.3, 1))
	assign_btn.pressed.connect(_on_assign_pressed)
	button_container.add_child(assign_btn)

	# Close button
	_close_button = _create_button("Close", Color(0.4, 0.4, 0.45, 1))
	_close_button.pressed.connect(_on_close_pressed)
	button_container.add_child(_close_button)

func _create_section_label(text: String) -> Label:
	"""Create a section header label"""
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 1))
	return label

func _add_separator() -> void:
	"""Add a horizontal separator"""
	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 8)
	_main_container.add_child(separator)

func _create_button(text: String, color: Color) -> Button:
	"""Create a styled button"""
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, BUTTON_HEIGHT)

	# Normal state
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = color
	normal_style.corner_radius_top_left = 4
	normal_style.corner_radius_top_right = 4
	normal_style.corner_radius_bottom_left = 4
	normal_style.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("normal", normal_style)

	# Hover state
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = color.lightened(0.2)
	hover_style.corner_radius_top_left = 4
	hover_style.corner_radius_top_right = 4
	hover_style.corner_radius_bottom_left = 4
	hover_style.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("hover", hover_style)

	return button

# ==============================================================================
# PUBLIC METHODS
# ==============================================================================
func show_panel(hex_node: HexNode) -> void:
	"""Show panel for node"""
	current_node = hex_node

	if not current_node:
		hide_panel()
		return

	_update_all_displays()
	visible = true

func hide_panel() -> void:
	"""Hide the panel"""
	current_node = null
	_selected_god_id = ""
	_selected_task_id = ""
	visible = false

func refresh() -> void:
	"""Refresh the display with current data"""
	if current_node:
		_update_all_displays()

# ==============================================================================
# PRIVATE METHODS - Display Updates
# ==============================================================================
func _update_all_displays() -> void:
	"""Update all display sections"""
	_update_current_workers()
	_update_available_gods()
	_update_available_tasks()

func _update_current_workers() -> void:
	"""Update current workers display"""
	# Clear existing
	for child in _current_workers_container.get_children():
		child.queue_free()

	if not current_node or not collection_manager:
		var no_workers_label = Label.new()
		no_workers_label.text = "No workers assigned"
		no_workers_label.add_theme_font_size_override("font_size", 12)
		_current_workers_container.add_child(no_workers_label)
		return

	var worker_count = current_node.get_worker_count()
	var max_workers = current_node.max_workers

	# Header
	var header = Label.new()
	header.text = "Workers: %d / %d" % [worker_count, max_workers]
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	_current_workers_container.add_child(header)

	# List workers
	if worker_count == 0:
		var empty_label = Label.new()
		empty_label.text = "  (No workers assigned)"
		empty_label.add_theme_font_size_override("font_size", 11)
		_current_workers_container.add_child(empty_label)
	else:
		for god_id in current_node.assigned_workers:
			var god = collection_manager.get_god_by_id(god_id)
			if god:
				_add_current_worker_item(god)

func _add_current_worker_item(god: God) -> void:
	"""Add a current worker item to the list"""
	var item = HBoxContainer.new()
	item.custom_minimum_size = Vector2(0, ITEM_HEIGHT)
	_current_workers_container.add_child(item)

	# God info
	var info_label = Label.new()
	var task_info = ""
	if god.current_tasks.size() > 0 and task_assignment_manager:
		var first_task = task_assignment_manager.get_task(god.current_tasks[0])
		if first_task:
			task_info = " - %s" % first_task.name
	info_label.text = "  %s (Lv %d)%s" % [god.name, god.level, task_info]
	info_label.add_theme_font_size_override("font_size", 11)
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_child(info_label)

	# Unassign button
	var unassign_btn = Button.new()
	unassign_btn.text = "Unassign"
	unassign_btn.custom_minimum_size = Vector2(80, 28)
	unassign_btn.pressed.connect(_on_unassign_worker.bind(god.id))
	item.add_child(unassign_btn)

func _update_available_gods() -> void:
	"""Update available gods display"""
	# Clear existing
	for child in _available_gods_container.get_children():
		child.queue_free()

	if not collection_manager:
		return

	var available_gods = _get_available_gods()

	if available_gods.is_empty():
		var no_gods_label = Label.new()
		no_gods_label.text = "No gods available (all in garrison or working)"
		no_gods_label.add_theme_font_size_override("font_size", 11)
		_available_gods_container.add_child(no_gods_label)
		return

	# List available gods
	for god in available_gods:
		_add_available_god_item(god)

func _add_available_god_item(god: God) -> void:
	"""Add an available god item to the list"""
	var button = Button.new()
	button.text = "%s (Lv %d)" % [god.name, god.level]
	button.custom_minimum_size = Vector2(0, ITEM_HEIGHT)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(_on_god_selected.bind(god.id))

	# Highlight if selected
	if _selected_god_id == god.id:
		var selected_style = StyleBoxFlat.new()
		selected_style.bg_color = Color(0.3, 0.5, 0.7, 1)
		button.add_theme_stylebox_override("normal", selected_style)

	_available_gods_container.add_child(button)

func _update_available_tasks() -> void:
	"""Update available tasks display"""
	# Clear existing
	for child in _available_tasks_container.get_children():
		child.queue_free()

	if not current_node or not task_assignment_manager:
		return

	var available_tasks = _get_available_tasks()

	if available_tasks.is_empty():
		var no_tasks_label = Label.new()
		no_tasks_label.text = "No tasks available for this node type"
		no_tasks_label.add_theme_font_size_override("font_size", 11)
		_available_tasks_container.add_child(no_tasks_label)
		return

	# List available tasks
	for task_obj in available_tasks:
		_add_available_task_item(task_obj)

func _add_available_task_item(task_obj: Task) -> void:
	"""Add an available task item to the list"""
	var button = Button.new()
	var duration_str = _format_duration(task_obj.base_duration_seconds)
	button.text = "%s (%s)" % [task_obj.name, duration_str]
	button.custom_minimum_size = Vector2(0, ITEM_HEIGHT)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(_on_task_selected.bind(task_obj.id))

	# Highlight if selected
	if _selected_task_id == task_obj.id:
		var selected_style = StyleBoxFlat.new()
		selected_style.bg_color = Color(0.3, 0.5, 0.7, 1)
		button.add_theme_stylebox_override("normal", selected_style)

	_available_tasks_container.add_child(button)

# ==============================================================================
# PRIVATE METHODS - Helpers
# ==============================================================================
func _get_available_gods() -> Array[God]:
	"""Get gods available for assignment (not in garrison or working)"""
	var result: Array[God] = []

	if not collection_manager or not current_node:
		return result

	var all_gods = collection_manager.get_all_gods()

	for god in all_gods:
		# Check if already working at this node
		if god.id in current_node.assigned_workers:
			continue

		# Check if in any garrison
		var in_garrison = _is_god_in_any_garrison(god.id)
		if in_garrison:
			continue

		# Check if working at another node
		var working_elsewhere = _is_god_working_elsewhere(god.id)
		if working_elsewhere:
			continue

		result.append(god)

	return result

func _is_god_in_any_garrison(god_id: String) -> bool:
	"""Check if god is in any garrison"""
	if not territory_manager:
		return false

	var hex_grid_manager = SystemRegistry.get_instance().get_system("HexGridManager")
	if not hex_grid_manager:
		return false

	var all_nodes = hex_grid_manager.get_all_nodes()
	for node in all_nodes:
		if god_id in node.garrison:
			return true

	return false

func _is_god_working_elsewhere(god_id: String) -> bool:
	"""Check if god is working at another node"""
	if not current_node:
		return false

	var hex_grid_manager = SystemRegistry.get_instance().get_system("HexGridManager")
	if not hex_grid_manager:
		return false

	var all_nodes = hex_grid_manager.get_all_nodes()
	for node in all_nodes:
		if node.id != current_node.id and god_id in node.assigned_workers:
			return true

	return false

func _get_available_tasks() -> Array[Task]:
	"""Get tasks available for this node type"""
	var result: Array[Task] = []

	if not current_node or not task_assignment_manager:
		return result

	# Filter tasks by node type
	for task_id in current_node.available_tasks:
		var task_obj = task_assignment_manager.get_task(task_id)
		if task_obj:
			result.append(task_obj)

	return result

func _format_duration(seconds: int) -> String:
	"""Format duration in human-readable format"""
	if seconds < 60:
		return "%ds" % seconds
	elif seconds < 3600:
		return "%dm" % (seconds / 60)
	else:
		return "%dh" % (seconds / 3600)

# ==============================================================================
# SIGNAL HANDLERS
# ==============================================================================
func _on_god_selected(god_id: String) -> void:
	"""Handle god selection"""
	_selected_god_id = god_id
	_update_available_gods()

func _on_task_selected(task_id: String) -> void:
	"""Handle task selection"""
	_selected_task_id = task_id
	_update_available_tasks()

func _on_assign_pressed() -> void:
	"""Handle assign button press"""
	if not current_node or not collection_manager or not task_assignment_manager:
		return

	if _selected_god_id.is_empty() or _selected_task_id.is_empty():
		push_warning("WorkerAssignmentPanel: Must select both god and task")
		return

	# Check node has space
	if not current_node.has_worker_space():
		push_warning("WorkerAssignmentPanel: Node has no worker space")
		return

	var god = collection_manager.get_god_by_id(_selected_god_id)
	if not god:
		return

	# Assign task via TaskAssignmentManager
	var success = task_assignment_manager.assign_god_to_task(god, _selected_task_id, current_node.id)
	if not success:
		push_warning("WorkerAssignmentPanel: Failed to assign task")
		return

	# Add to node's worker list
	current_node.assigned_workers.append(god.id)
	if _selected_task_id not in current_node.active_tasks:
		current_node.active_tasks.append(_selected_task_id)

	worker_assigned.emit(current_node, god.id, _selected_task_id)

	# Clear selection and refresh
	_selected_god_id = ""
	_selected_task_id = ""
	refresh()

func _on_unassign_worker(god_id: String) -> void:
	"""Handle unassign button press"""
	if not current_node or not collection_manager or not task_assignment_manager:
		return

	var god = collection_manager.get_god_by_id(god_id)
	if not god:
		return

	# Unassign all tasks for this god
	var tasks_to_remove = god.current_tasks.duplicate()
	for task_id in tasks_to_remove:
		task_assignment_manager.unassign_god_from_task(god, task_id)

	# Remove from node's worker list
	var idx = current_node.assigned_workers.find(god_id)
	if idx != -1:
		current_node.assigned_workers.remove_at(idx)

	# Clean up active tasks if no one is doing them
	for task_id in current_node.active_tasks.duplicate():
		var still_active = false
		for worker_id in current_node.assigned_workers:
			var worker = collection_manager.get_god_by_id(worker_id)
			if worker and task_id in worker.current_tasks:
				still_active = true
				break
		if not still_active:
			current_node.active_tasks.erase(task_id)

	worker_unassigned.emit(current_node, god_id)
	refresh()

func _on_close_pressed() -> void:
	"""Handle close button press"""
	close_requested.emit()
	hide_panel()

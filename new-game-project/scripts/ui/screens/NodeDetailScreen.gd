# NodeDetailScreen - Mobile-friendly node management with garrison/worker sections
class_name NodeDetailScreen
extends Control

signal close_requested
signal garrison_changed(node: HexNode, garrison_ids: Array)
signal workers_changed(node: HexNode, worker_ids: Array)

const NODE_TYPE_ICONS = {
	"base": "🏛️",
	"mine": "⛏️",
	"forest": "🌲",
	"coast": "🌊",
	"hunting_ground": "🦌",
	"forge": "🔨",
	"library": "📚",
	"temple": "⛪",
	"fortress": "🏰",
	"resource_node": "⛏️",
	"shrine": "✨"
}

const TASK_CATEGORY_ICONS = {
	"gathering": "🪓",
	"crafting": "🔨",
	"research": "📚",
	"defense": "🛡️",
	"special": "⭐"
}
const FADE_DURATION := 0.2

var _background: ColorRect
var _main_container: MarginContainer
var _content_scroll: ScrollContainer
var _content_vbox: VBoxContainer
var _header_container: HBoxContainer
var _back_button: Button
var _title_label: Label
var _tier_label: Label
var _garrison_section: Control
var _garrison_display: GarrisonDisplay
var _worker_section: Control
var _worker_slot_display: WorkerSlotDisplay
var _tasks_section: Control
var _tasks_container: VBoxContainer
var _crafting_section: Control
var _crafting_container: VBoxContainer
var _craft_popup: Control = null
var _god_selection_grid: GodSelectionGrid
var _selection_mode: String = ""
var _selection_slot_index: int = -1
var _current_node: HexNode = null
var territory_manager = null
var collection_manager = null
var task_manager = null
var building_manager = null
var resource_manager = null
var hex_grid_manager = null
var _crafting_recipes: Dictionary = {}
var _buildings_data: Dictionary = {}

func _ready() -> void:
	_setup_fullscreen()
	_init_systems()
	_build_ui()
	visible = false  # Start hidden

func _setup_fullscreen() -> void:
	"""Setup fullscreen sizing (required when Control is child of Node2D)"""
	var viewport_size = get_viewport().get_visible_rect().size
	set_anchors_preset(Control.PRESET_FULL_RECT)
	call_deferred("set_size", viewport_size)
	position = Vector2.ZERO
	clip_contents = true

func _init_systems() -> void:
	"""Initialize system references via SystemRegistry"""
	var registry = SystemRegistry.get_instance()
	if registry:
		territory_manager = registry.get_system("TerritoryManager")
		collection_manager = registry.get_system("CollectionManager")
		task_manager = registry.get_system("TaskAssignmentManager")
		building_manager = registry.get_system("BuildingManager")
		resource_manager = registry.get_system("ResourceManager")
		hex_grid_manager = registry.get_system("HexGridManager")

	# Load crafting recipes and buildings data
	_load_crafting_recipes()
	_load_buildings_data()

func _build_ui() -> void:
	"""Build the complete UI structure"""
	# Dark semi-transparent background
	_background = ColorRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.color = Color(0.02, 0.02, 0.05, 0.95)
	add_child(_background)

	# Main container with margins
	_main_container = MarginContainer.new()
	_main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main_container.add_theme_constant_override("margin_left", 20)
	_main_container.add_theme_constant_override("margin_right", 20)
	_main_container.add_theme_constant_override("margin_top", 16)
	_main_container.add_theme_constant_override("margin_bottom", 16)
	add_child(_main_container)

	# Vertical layout
	var outer_vbox = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 12)
	_main_container.add_child(outer_vbox)

	# Header (fixed, not scrollable)
	_build_header(outer_vbox)

	# Scrollable content area
	_content_scroll = ScrollContainer.new()
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(_content_scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_theme_constant_override("separation", 20)
	_content_scroll.add_child(_content_vbox)

	# Garrison section
	_build_garrison_section(_content_vbox)

	# Worker section
	_build_worker_section(_content_vbox)

	# Tasks/Crafting section
	_build_tasks_section(_content_vbox)

	# Crafting section (for buildings with crafting_enabled)
	_build_crafting_section(_content_vbox)

	# God selection overlay (hidden initially)
	_build_god_selection_overlay()

func _build_header(parent: Control) -> void:
	"""Build header with back button, node info, and tier display"""
	# Header panel with styled background - increased height for 60px tap targets
	var header_panel = Panel.new()
	header_panel.custom_minimum_size = Vector2(0, 70)
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = Color(0.1, 0.1, 0.14, 0.95)
	header_style.corner_radius_top_left = 8
	header_style.corner_radius_top_right = 8
	header_style.corner_radius_bottom_left = 8
	header_style.corner_radius_bottom_right = 8
	header_panel.add_theme_stylebox_override("panel", header_style)
	parent.add_child(header_panel)

	# Header content
	_header_container = HBoxContainer.new()
	_header_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_header_container.offset_left = 12
	_header_container.offset_right = -12
	_header_container.offset_top = 8
	_header_container.offset_bottom = -8
	_header_container.add_theme_constant_override("separation", 12)
	header_panel.add_child(_header_container)

	# Back button (close) - 60x60px minimum tap target
	_back_button = Button.new()
	_back_button.text = "← Back"
	_back_button.custom_minimum_size = Vector2(80, 60)  # Meets 60px minimum tap target
	_back_button.pressed.connect(_on_close_pressed)
	_style_button(_back_button)
	_header_container.add_child(_back_button)

	# Title label (node name + type icon)
	_title_label = Label.new()
	_title_label.text = "Node Details"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_container.add_child(_title_label)

	# Tier label (stars)
	_tier_label = Label.new()
	_tier_label.text = "★★★"
	_tier_label.add_theme_font_size_override("font_size", 18)
	_tier_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))  # Gold
	_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tier_label.custom_minimum_size = Vector2(80, 0)
	_header_container.add_child(_tier_label)

func _build_garrison_section(parent: Control) -> void:
	"""Build the garrison display section"""
	var result = _create_section_container("⚔️ Garrison (Defense)")
	_garrison_section = result.section
	parent.add_child(_garrison_section)

	# Add GarrisonDisplay component to the content area
	_garrison_display = GarrisonDisplay.new()
	_garrison_display.custom_minimum_size = Vector2(0, 160)
	_garrison_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.content.add_child(_garrison_display)

	# Connect signals
	_garrison_display.set_garrison_requested.connect(_on_garrison_set_requested)
	_garrison_display.garrison_god_tapped.connect(_on_garrison_god_tapped)

func _build_worker_section(parent: Control) -> void:
	"""Build the worker slots section"""
	var result = _create_section_container("👷 Workers (Production)")
	_worker_section = result.section
	parent.add_child(_worker_section)

	# Add WorkerSlotDisplay component to the content area
	_worker_slot_display = WorkerSlotDisplay.new()
	_worker_slot_display.custom_minimum_size = Vector2(0, 160)
	_worker_slot_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.content.add_child(_worker_slot_display)

	# Connect signals
	_worker_slot_display.empty_slot_tapped.connect(_on_worker_slot_empty_tapped)
	_worker_slot_display.filled_slot_tapped.connect(_on_worker_slot_filled_tapped)

func _build_tasks_section(parent: Control) -> void:
	"""Build the tasks/crafting section"""
	var result = _create_section_container("📋 Available Tasks")
	_tasks_section = result.section
	_tasks_section.custom_minimum_size = Vector2(0, 200)
	parent.add_child(_tasks_section)

	# Create scrollable container for tasks
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	result.content.add_child(scroll)

	_tasks_container = VBoxContainer.new()
	_tasks_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tasks_container.add_theme_constant_override("separation", 8)
	scroll.add_child(_tasks_container)

func _create_section_container(title: String) -> Dictionary:
	"""Create a styled section container with title. Returns {section, content}"""
	var section = Panel.new()
	section.custom_minimum_size = Vector2(0, 180)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.9)
	style.border_color = Color(0.3, 0.3, 0.4, 0.8)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	section.add_theme_stylebox_override("panel", style)

	# Inner margin
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	section.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Section title
	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	vbox.add_child(title_label)

	# Content area
	var content = Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)

	return {"section": section, "content": content}

func _build_god_selection_overlay() -> void:
	"""Build the god selection grid overlay"""
	_god_selection_grid = GodSelectionGrid.new()
	_god_selection_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_god_selection_grid.visible = false
	add_child(_god_selection_grid)

	# Connect signals
	_god_selection_grid.god_selected.connect(_on_god_selected)
	_god_selection_grid.selection_cancelled.connect(_on_selection_cancelled)

func _style_button(button: Button) -> void:
	"""Apply consistent button styling"""
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style_normal.border_color = Color(0.4, 0.4, 0.5)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style_normal)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.2, 0.2, 0.28, 0.98)
	style_hover.border_color = Color(0.5, 0.5, 0.6)
	style_hover.set_border_width_all(1)
	style_hover.set_corner_radius_all(6)
	button.add_theme_stylebox_override("hover", style_hover)

	button.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))

func show_node(node: HexNode) -> void:
	"""Show the detail screen for a specific node with smooth fade-in transition"""
	if not node:
		push_error("NodeDetailScreen: Cannot show null node")
		return

	_current_node = node
	_update_header()
	_update_garrison()
	_update_workers()
	_update_tasks()
	_update_crafting()

	# Smooth fade-in transition
	modulate.a = 0.0
	visible = true
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_DURATION).set_ease(Tween.EASE_OUT)
	print("NodeDetailScreen: Showing details for node '%s' (type: %s, tier: %d)" % [node.name, node.node_type, node.tier])

func hide_screen() -> void:
	"""Hide the detail screen with smooth fade-out transition"""
	_god_selection_grid.visible = false

	# Smooth fade-out transition
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		visible = false
		modulate.a = 1.0  # Reset for next show
		_current_node = null
	)

func get_current_node() -> HexNode:
	return _current_node

func _update_header() -> void:
	"""Update header with node information"""
	if not _current_node:
		return

	# Build title with icon
	var icon = NODE_TYPE_ICONS.get(_current_node.node_type, "📍")
	_title_label.text = "%s %s" % [icon, _current_node.name]

	# Build tier stars
	var stars = ""
	for i in range(_current_node.tier):
		stars += "★"
	_tier_label.text = stars

func _update_garrison() -> void:
	"""Update garrison display with current node data"""
	if not _current_node or not _garrison_display:
		return

	# Convert Array[String] to typed array
	var garrison_ids: Array[String] = []
	for id in _current_node.garrison:
		garrison_ids.append(id)

	_garrison_display.set_garrison_gods(garrison_ids)

func _update_workers() -> void:
	"""Update worker display with current node data"""
	if not _current_node or not _worker_slot_display:
		return

	_worker_slot_display.setup_for_node(_current_node)

func _update_tasks() -> void:
	"""Update tasks section based on node type and tier"""
	if not _current_node or not _tasks_container:
		return

	# Clear existing tasks
	for child in _tasks_container.get_children():
		child.queue_free()

	# Check if workers are assigned
	var has_workers = _current_node.assigned_workers.size() > 0

	if not has_workers:
		var no_worker_label = Label.new()
		no_worker_label.text = "Assign a worker to see available tasks"
		no_worker_label.add_theme_font_size_override("font_size", 12)
		no_worker_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		no_worker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tasks_container.add_child(no_worker_label)
		return

	# Get available tasks for this node type and tier
	var available_tasks = _get_available_tasks_for_node()

	if available_tasks.is_empty():
		var no_tasks_label = Label.new()
		no_tasks_label.text = "No tasks available for this node"
		no_tasks_label.add_theme_font_size_override("font_size", 12)
		no_tasks_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		no_tasks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tasks_container.add_child(no_tasks_label)
		return

	# Create task cards
	for task_data in available_tasks:
		var task_card = _create_task_card(task_data)
		_tasks_container.add_child(task_card)

func _get_available_tasks_for_node() -> Array:
	"""Get tasks available based on node type and tier"""
	var tasks: Array = []

	# Map node types to building IDs they support
	var node_type_to_buildings = {
		"forge": ["forge", "smelter", "enchanting_altar", "artifact_forge"],
		"resource_node": ["basic_mine", "improved_mine", "advanced_mine", "deep_mine",
			"lumber_camp", "farm", "herb_garden", "fishing_dock", "diving_platform", "hunting_lodge"],
		"shrine": ["library", "archive", "watchtower", "expedition_hall", "trading_post"],
		"base": ["training_grounds", "guard_post"]
	}

	# Get buildings for this node type
	var supported_buildings = node_type_to_buildings.get(_current_node.node_type, [])

	# Also add tier-based unlocks
	if _current_node.tier >= 2:
		# Higher tier nodes can do more things
		if _current_node.node_type == "forge":
			if _current_node.tier >= 3:
				supported_buildings.append("gem_workshop")
			if _current_node.tier >= 4:
				supported_buildings.append("advanced_alchemy_lab")

	# Load tasks from JSON (cached by task_manager if available)
	var all_tasks = _load_tasks_data()

	for task_id in all_tasks:
		var task = all_tasks[task_id]
		var required_building = task.get("required_building_id", "")
		var required_tier = task.get("required_territory_level", 1)

		# Check if this node supports the required building
		if required_building in supported_buildings:
			# Check tier requirement
			if _current_node.tier >= required_tier:
				tasks.append(task)

	return tasks

func _load_tasks_data() -> Dictionary:
	"""Load tasks from JSON file"""
	var file = FileAccess.open("res://data/tasks.json", FileAccess.READ)
	if not file:
		push_error("Failed to load tasks.json")
		return {}

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()

	if error != OK:
		push_error("Failed to parse tasks.json")
		return {}

	var data = json.get_data()
	return data.get("tasks", {})

func _create_task_card(task_data: Dictionary) -> Control:
	"""Create a task card UI element"""
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 70)

	# Style the card
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.9)
	style.border_color = _get_rarity_color(task_data.get("rarity", "common"))
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	# Task info on the left
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(info_vbox)

	# Task name
	var name_label = Label.new()
	name_label.text = task_data.get("name", "Unknown Task")
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	info_vbox.add_child(name_label)

	# Task description
	var desc_label = Label.new()
	desc_label.text = task_data.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_vbox.add_child(desc_label)

	# Duration and rewards
	var stats_hbox = HBoxContainer.new()
	stats_hbox.add_theme_constant_override("separation", 12)
	info_vbox.add_child(stats_hbox)

	var duration_secs = task_data.get("base_duration_seconds", 3600)
	var duration_label = Label.new()
	duration_label.text = "⏱️ %s" % _format_duration(duration_secs)
	duration_label.add_theme_font_size_override("font_size", 10)
	duration_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	stats_hbox.add_child(duration_label)

	# Show rewards preview
	var rewards_text = _get_rewards_preview(task_data)
	if rewards_text:
		var rewards_label = Label.new()
		rewards_label.text = rewards_text
		rewards_label.add_theme_font_size_override("font_size", 10)
		rewards_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.5))
		stats_hbox.add_child(rewards_label)

	# Start button on the right
	var start_button = Button.new()
	start_button.text = "Start"
	start_button.custom_minimum_size = Vector2(70, 50)
	_style_task_button(start_button)
	start_button.pressed.connect(_on_task_start_pressed.bind(task_data))
	hbox.add_child(start_button)

	return card

func _get_rarity_color(rarity: String) -> Color:
	"""Get border color based on task rarity"""
	match rarity:
		"common": return Color(0.4, 0.4, 0.5)
		"uncommon": return Color(0.3, 0.6, 0.3)
		"rare": return Color(0.3, 0.4, 0.8)
		"legendary": return Color(0.8, 0.6, 0.2)
		_: return Color(0.4, 0.4, 0.5)

func _format_duration(seconds: int) -> String:
	"""Format seconds into readable time"""
	if seconds < 60:
		return "%ds" % seconds
	elif seconds < 3600:
		return "%dm" % (seconds / 60)
	else:
		var hours = seconds / 3600
		var mins = (seconds % 3600) / 60
		if mins > 0:
			return "%dh %dm" % [hours, mins]
		return "%dh" % hours

func _get_rewards_preview(task_data: Dictionary) -> String:
	"""Get a short preview of task rewards"""
	var parts: Array[String] = []

	# Resource rewards - use "output" from crafting_recipes.json
	var resources = task_data.get("output", task_data.get("resource_rewards", {}))
	for res_id in resources:
		parts.append("%s %s" % [resources[res_id], res_id.replace("_", " ")])

	# Item rewards
	var items = task_data.get("item_rewards", [])
	for item in items:
		if item.get("chance", 0) >= 0.5:  # Only show high chance items
			parts.append(item.get("id", "item").replace("_", " "))

	if parts.is_empty():
		# Check for XP
		var xp = task_data.get("base_experience", 0)
		if xp > 0:
			return "🌟 %d XP" % xp
		return ""

	return "→ " + ", ".join(parts.slice(0, 2))  # Show first 2 rewards

func _style_task_button(button: Button) -> void:
	"""Style the task start button"""
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.2, 0.4, 0.3, 0.9)
	style_normal.border_color = Color(0.3, 0.6, 0.4)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", style_normal)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.25, 0.5, 0.35, 0.95)
	style_hover.border_color = Color(0.4, 0.7, 0.5)
	style_hover.set_border_width_all(1)
	style_hover.set_corner_radius_all(4)
	button.add_theme_stylebox_override("hover", style_hover)

	button.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))
	button.add_theme_font_size_override("font_size", 12)

func _on_task_start_pressed(task_data: Dictionary) -> void:
	"""Handle task start button press"""
	if not _current_node or _current_node.assigned_workers.is_empty():
		print("NodeDetailScreen: Cannot start task - no workers assigned")
		return

	# Use first available worker
	var worker_id = _current_node.assigned_workers[0]

	# Start the task via TaskAssignmentManager
	if task_manager and task_manager.has_method("start_task"):
		var result = task_manager.start_task(task_data.get("id"), worker_id, _current_node.id)
		if result:
			print("NodeDetailScreen: Started task '%s' with worker %s" % [task_data.get("name"), worker_id])
			_update_tasks()  # Refresh to show in-progress state
		else:
			print("NodeDetailScreen: Failed to start task")
	else:
		# Fallback - just show feedback for now
		print("NodeDetailScreen: Task '%s' would start (TaskAssignmentManager not available)" % task_data.get("name"))

func _on_garrison_set_requested() -> void:
	"""Handle request to open god selection for garrison"""
	_selection_mode = "garrison"
	_selection_slot_index = -1

	# Build exclusion list (gods already in garrison or working)
	var excluded: Array[String] = []
	if _current_node:
		for id in _current_node.garrison:
			excluded.append(id)
		for id in _current_node.assigned_workers:
			excluded.append(id)

	_god_selection_grid.show_selection("Select Garrison Defender", GodSelectionGrid.FilterMode.AVAILABLE, excluded)
	print("NodeDetailScreen: Opening god selection for garrison")

func _on_garrison_god_tapped(god: God) -> void:
	"""Handle tap on garrison god - offer to remove"""
	if not _current_node or not god:
		return

	# Remove from garrison display
	_garrison_display.remove_god_from_garrison(god.id)

	# Update node data
	var idx = _current_node.garrison.find(god.id)
	if idx >= 0:
		_current_node.garrison.remove_at(idx)

	# Persist via territory manager
	if territory_manager:
		territory_manager.update_node_garrison(_current_node.id, _current_node.garrison)

	# Emit change signal
	garrison_changed.emit(_current_node, _current_node.garrison.duplicate())
	print("NodeDetailScreen: Removed %s from garrison" % god.name)

func _on_worker_slot_empty_tapped(slot_index: int) -> void:
	"""Handle tap on empty worker slot"""
	_selection_mode = "worker"
	_selection_slot_index = slot_index

	# Build exclusion list
	var excluded: Array[String] = []
	if _current_node:
		for id in _current_node.garrison:
			excluded.append(id)
		for id in _current_node.assigned_workers:
			excluded.append(id)

	_god_selection_grid.show_selection("Select Worker", GodSelectionGrid.FilterMode.AVAILABLE, excluded)
	print("NodeDetailScreen: Opening god selection for worker slot %d" % slot_index)

func _on_worker_slot_filled_tapped(slot_index: int, god: God) -> void:
	"""Handle tap on filled worker slot - offer to remove"""
	if not _current_node or not god:
		return

	# Remove from worker display
	_worker_slot_display.remove_worker_from_slot(god.id)

	# Update node data
	var idx = _current_node.assigned_workers.find(god.id)
	if idx >= 0:
		_current_node.assigned_workers.remove_at(idx)

	# Persist via territory manager
	if territory_manager:
		territory_manager.update_node_workers(_current_node.id, _current_node.assigned_workers)

	# Emit change signal
	workers_changed.emit(_current_node, _current_node.assigned_workers.duplicate())
	print("NodeDetailScreen: Removed %s from workers" % god.name)

func _on_god_selected(god: God) -> void:
	"""Handle god selection from grid"""
	if not god or not _current_node:
		_god_selection_grid.hide_selection()
		return

	if _selection_mode == "garrison":
		_add_god_to_garrison(god)
	elif _selection_mode == "worker":
		_add_god_to_workers(god)

	_god_selection_grid.hide_selection()
	_selection_mode = ""
	_selection_slot_index = -1

func _on_selection_cancelled() -> void:
	"""Handle god selection cancelled"""
	_god_selection_grid.hide_selection()
	_selection_mode = ""
	_selection_slot_index = -1
	print("NodeDetailScreen: God selection cancelled")

func _add_god_to_garrison(god: God) -> void:
	"""Add selected god to garrison"""
	if not _current_node:
		return

	# Check if garrison has space
	if _current_node.garrison.size() >= _current_node.max_garrison:
		print("NodeDetailScreen: Garrison is full")
		return

	# Add to node data
	_current_node.garrison.append(god.id)

	# Update display
	_garrison_display.add_god_to_garrison(god)

	# Persist via territory manager
	if territory_manager:
		territory_manager.update_node_garrison(_current_node.id, _current_node.garrison)

	# Emit change signal
	garrison_changed.emit(_current_node, _current_node.garrison.duplicate())
	print("NodeDetailScreen: Added %s to garrison" % god.name)

func _add_god_to_workers(god: God) -> void:
	"""Add selected god to workers"""
	if not _current_node:
		return

	# Check if workers have space
	if _current_node.assigned_workers.size() >= _current_node.max_workers:
		print("NodeDetailScreen: Workers are full")
		return

	# Add to node data
	_current_node.assigned_workers.append(god.id)

	# Update display
	_worker_slot_display.add_worker_to_slot(god)

	# Persist via territory manager
	if territory_manager:
		territory_manager.update_node_workers(_current_node.id, _current_node.assigned_workers)

	# Emit change signal
	workers_changed.emit(_current_node, _current_node.assigned_workers.duplicate())
	print("NodeDetailScreen: Added %s to workers" % god.name)

func _on_close_pressed() -> void:
	"""Handle close button press"""
	hide_screen()
	close_requested.emit()

# ==============================================================================
# CRAFTING SECTION
# ==============================================================================

func _load_crafting_recipes() -> void:
	"""Load crafting recipes from JSON"""
	var file = FileAccess.open("res://data/crafting_recipes.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			_crafting_recipes = json.data
		file.close()

func _load_buildings_data() -> void:
	"""Load buildings data from JSON as fallback"""
	var file = FileAccess.open("res://data/buildings.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			_buildings_data = json.data.get("buildings", {})
		file.close()

func _build_crafting_section(parent: Control) -> void:
	"""Build the crafting section for buildings with crafting_enabled"""
	var result = _create_section_container("⚒️ Crafting")
	_crafting_section = result.section
	_crafting_section.visible = false  # Hidden by default, shown if building supports crafting
	parent.add_child(_crafting_section)

	_crafting_container = VBoxContainer.new()
	_crafting_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crafting_container.add_theme_constant_override("separation", 8)
	result.content.add_child(_crafting_container)

func _update_crafting() -> void:
	"""Update the crafting section based on current node's building"""
	if not _crafting_container:
		print("NodeDetailScreen._update_crafting: No crafting container")
		return

	# Clear existing content
	for child in _crafting_container.get_children():
		child.queue_free()

	# Check if node has a crafting building
	if not _current_node:
		print("NodeDetailScreen._update_crafting: No current node")
		_crafting_section.visible = false
		return

	print("NodeDetailScreen._update_crafting: Node '%s' has placed_building='%s'" % [_current_node.name, _current_node.placed_building])

	if _current_node.placed_building.is_empty():
		print("NodeDetailScreen._update_crafting: No building placed")
		_crafting_section.visible = false
		return

	var building = _get_building_data(_current_node.placed_building)
	print("NodeDetailScreen._update_crafting: Building data = %s" % str(building))
	if building.is_empty():
		print("NodeDetailScreen._update_crafting: Building data is empty (building_manager=%s)" % str(building_manager))
		_crafting_section.visible = false
		return

	var effects = building.get("effects", {})
	print("NodeDetailScreen._update_crafting: Effects = %s" % str(effects))
	if not effects.get("crafting_enabled", false):
		print("NodeDetailScreen._update_crafting: crafting_enabled is false")
		_crafting_section.visible = false
		return

	print("NodeDetailScreen._update_crafting: Showing crafting section!")

	# Show crafting section
	_crafting_section.visible = true

	var max_tier = effects.get("max_craft_tier", 1)
	var craft_type = effects.get("craft_type", "")  # weapon, armor, or empty for all

	# Info row
	var info = HBoxContainer.new()
	info.add_theme_constant_override("separation", 10)
	_crafting_container.add_child(info)

	var tier_label = Label.new()
	tier_label.text = "⚒️ %s (Tier %d)" % [building.get("name", "Forge"), max_tier]
	tier_label.add_theme_font_size_override("font_size", 14)
	tier_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	tier_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(tier_label)

	# Show active crafts count
	var active_crafts = _get_active_crafts_for_node(_current_node.id)
	if not active_crafts.is_empty():
		var active_label = Label.new()
		active_label.text = "🔄 %d in progress" % active_crafts.size()
		active_label.add_theme_font_size_override("font_size", 12)
		active_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
		info.add_child(active_label)

	# Get available recipes (crafting buildings don't show conversion recipes)
	var available = _get_available_recipes(max_tier, craft_type, false)

	# Craft button
	var craft_btn = Button.new()
	craft_btn.text = "⚒️ Open Recipes (%d)" % available.size()
	craft_btn.custom_minimum_size = Vector2(200, 50)
	craft_btn.pressed.connect(_on_open_crafting)
	_style_craft_button(craft_btn)
	_crafting_container.add_child(craft_btn)

	# Show active craft progress cards
	for craft_data in active_crafts:
		var progress_card = _create_craft_progress_card(craft_data)
		_crafting_container.add_child(progress_card)

func _get_building_data(building_id: String) -> Dictionary:
	"""Get building data from BuildingManager or fallback to loaded JSON"""
	if building_manager and building_manager.has_method("get_building"):
		var data = building_manager.get_building(building_id)
		if not data.is_empty():
			return data

	# Fallback to loaded buildings data
	return _buildings_data.get(building_id, {})

func _get_active_crafts_for_node(node_id: String) -> Array:
	"""Get active crafts for a specific node"""
	if hex_grid_manager and hex_grid_manager.has_method("get_active_crafts_for_node"):
		return hex_grid_manager.get_active_crafts_for_node(node_id)
	return []

func _get_available_recipes(max_tier: int, craft_type: String, allow_conversions: bool = true) -> Array:
	"""Get crafting recipes available for this building"""
	var available: Array = []

	# Iterate over recipe categories (conversion_recipes, equipment_recipes)
	for category_key in _crafting_recipes.keys():
		if category_key == "_metadata":
			continue

		var category = _crafting_recipes.get(category_key, {})
		if not category is Dictionary:
			continue

		# Determine if this is a conversion category
		var is_conversion_category = category_key == "conversion_recipes"

		# Skip conversion recipes if not allowed (e.g., blacksmith only crafts equipment)
		if is_conversion_category and not allow_conversions:
			continue

		# Iterate over individual recipes in this category
		for recipe_id in category.keys():
			# Skip comment keys
			if recipe_id.begins_with("_"):
				continue

			var recipe = category[recipe_id]
			if not recipe is Dictionary:
				continue

			var tier_req = recipe.get("tier", recipe.get("territory_tier_requirement", 1))

			# Check tier
			if tier_req > max_tier:
				continue

			# Check craft type restriction (weapon_forge only allows weapons)
			if not craft_type.is_empty():
				var equip_type = recipe.get("equipment_type", "")
				if equip_type.is_empty():
					continue  # Skip non-equipment recipes for specialized forges
				if craft_type == "weapon" and equip_type != "weapon":
					continue
				if craft_type == "armor" and equip_type not in ["armor", "accessory", "helmet", "boots", "gloves"]:
					continue

			# Add to available
			var recipe_with_id = recipe.duplicate()
			recipe_with_id["id"] = recipe_id
			available.append(recipe_with_id)

	return available

func _style_craft_button(button: Button) -> void:
	"""Style the craft button"""
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.55, 0.35, 0.2, 0.9)
	style_normal.border_color = Color(0.7, 0.5, 0.3)
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style_normal)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.65, 0.45, 0.25, 0.95)
	style_hover.border_color = Color(0.85, 0.65, 0.4)
	style_hover.set_border_width_all(2)
	style_hover.set_corner_radius_all(6)
	button.add_theme_stylebox_override("hover", style_hover)

	button.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	button.add_theme_font_size_override("font_size", 14)

func _create_craft_progress_card(craft_data: Dictionary) -> PanelContainer:
	"""Create a progress card for an active craft"""
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 40)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var current_time = int(Time.get_unix_time_from_system())
	var start_time = craft_data.get("start_time", current_time)
	var end_time = craft_data.get("end_time", current_time + 60)
	var total_duration = end_time - start_time
	var elapsed = current_time - start_time
	var progress = clampf(float(elapsed) / float(total_duration), 0.0, 1.0)
	var remaining = maxi(0, end_time - current_time)
	var is_complete = progress >= 1.0

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.22, 0.18, 0.95) if not is_complete else Color(0.2, 0.35, 0.2, 0.95)
	style.border_color = Color(0.4, 0.6, 0.4, 0.9) if not is_complete else Color(0.4, 0.8, 0.4, 1)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	# Task name
	var task_data = craft_data.get("task_data", {})
	var task_name = task_data.get("name", "Crafting...")

	var name_label = Label.new()
	name_label.text = "⚒️ " + task_name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)

	# Time remaining or complete button
	if is_complete:
		var claim_btn = Button.new()
		claim_btn.text = "✓ Claim"
		claim_btn.custom_minimum_size = Vector2(80, 30)
		claim_btn.pressed.connect(_on_craft_complete.bind(craft_data))
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.3, 0.6, 0.3, 0.9)
		btn_style.set_corner_radius_all(4)
		claim_btn.add_theme_stylebox_override("normal", btn_style)
		claim_btn.add_theme_font_size_override("font_size", 11)
		hbox.add_child(claim_btn)
	else:
		var time_label = Label.new()
		time_label.text = _format_duration(remaining)
		time_label.add_theme_font_size_override("font_size", 12)
		time_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		hbox.add_child(time_label)

	return card

func _on_open_crafting() -> void:
	"""Open the crafting popup"""
	if not _current_node:
		return
	_show_craft_popup()

func _show_craft_popup() -> void:
	"""Show the crafting recipe popup"""
	# Remove existing popup
	if _craft_popup and is_instance_valid(_craft_popup):
		_craft_popup.queue_free()

	var building = _get_building_data(_current_node.placed_building)
	var effects = building.get("effects", {})
	var max_tier = effects.get("max_craft_tier", 1)
	var craft_type = effects.get("craft_type", "")

	var viewport_size = get_viewport().get_visible_rect().size
	var available_recipes = _get_available_recipes(max_tier, craft_type, false)

	# Create popup
	_craft_popup = Control.new()
	_craft_popup.name = "CraftPopup"
	_craft_popup.z_index = 100
	_craft_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_craft_popup.size = viewport_size

	# Dark background
	var bg_overlay = ColorRect.new()
	bg_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_overlay.size = viewport_size
	bg_overlay.color = Color(0, 0, 0, 0.7)
	bg_overlay.gui_input.connect(_on_popup_bg_clicked)
	_craft_popup.add_child(bg_overlay)

	# Panel
	var popup_panel = PanelContainer.new()
	var panel_width = viewport_size.x * 0.85
	var panel_height = viewport_size.y * 0.75
	popup_panel.custom_minimum_size = Vector2(panel_width, panel_height)
	popup_panel.size = Vector2(panel_width, panel_height)
	popup_panel.position = Vector2(
		(viewport_size.x - panel_width) / 2,
		(viewport_size.y - panel_height) / 2
	)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.1, 0.15, 0.98)
	panel_style.border_color = Color(0.6, 0.45, 0.3, 1)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 15
	panel_style.content_margin_right = 15
	panel_style.content_margin_top = 15
	panel_style.content_margin_bottom = 15
	popup_panel.add_theme_stylebox_override("panel", panel_style)
	_craft_popup.add_child(popup_panel)

	# Content
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	popup_panel.add_child(content)

	# Header
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	content.add_child(header)

	var title = Label.new()
	title.text = "⚒️ %s RECIPES" % building.get("name", "FORGE").to_upper()
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.pressed.connect(_close_craft_popup)
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = Color(0.5, 0.2, 0.2, 0.9)
	close_style.set_corner_radius_all(6)
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.add_theme_font_size_override("font_size", 18)
	header.add_child(close_btn)

	# Tier info
	var tier_label = Label.new()
	tier_label.text = "Tier %d - %d recipes available" % [max_tier, available_recipes.size()]
	tier_label.add_theme_font_size_override("font_size", 12)
	tier_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	content.add_child(tier_label)

	# Separator
	var sep = HSeparator.new()
	content.add_child(sep)

	# Scroll container
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)

	# Grid container with 3 columns for recipe cards
	var recipes_grid = CraftingUIUtils.create_recipe_grid(3)
	scroll.add_child(recipes_grid)

	# Add recipe cards
	for recipe in available_recipes:
		var costs = CraftingUIUtils.get_recipe_costs(recipe)
		var can_afford = _can_afford_craft(costs)
		var is_conversion = CraftingUIUtils.is_conversion_recipe(recipe)

		var craft_callback = func(r, _auto_repeat): _on_start_craft(r)

		var card = CraftingUIUtils.create_recipe_card(
			recipe,
			can_afford,
			craft_callback,
			is_conversion
		)
		recipes_grid.add_child(card)

	# Add to main
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node:
		main_node.add_child(_craft_popup)
	else:
		add_child(_craft_popup)

func _can_afford_craft(costs: Dictionary) -> bool:
	"""Check if player can afford the craft costs"""
	if costs.is_empty():
		return true
	if not resource_manager:
		return true
	return resource_manager.can_afford(costs)

func _on_popup_bg_clicked(event: InputEvent) -> void:
	"""Handle click on popup background"""
	if event is InputEventMouseButton and event.pressed:
		_close_craft_popup()

func _close_craft_popup() -> void:
	"""Close the crafting popup"""
	if _craft_popup and is_instance_valid(_craft_popup):
		_craft_popup.queue_free()
		_craft_popup = null

func _on_start_craft(recipe: Dictionary) -> void:
	"""Handle starting a craft"""
	var recipe_id = recipe.get("id", "")
	if recipe_id.is_empty():
		return

	# Check and spend resources
	var costs = recipe.get("materials", recipe.get("resource_costs", {}))
	if not costs.is_empty():
		if not resource_manager:
			return
		if not resource_manager.can_afford(costs):
			return
		if not resource_manager.spend_resources(costs):
			return

	print("NodeDetailScreen: Starting craft '%s' at node '%s'" % [recipe_id, _current_node.id])

	# Track the craft
	var duration_mins = recipe.get("duration_minutes", recipe.get("craft_time_minutes", 5))
	var duration_secs = duration_mins * 60
	var current_time = int(Time.get_unix_time_from_system())

	var craft_data = {
		"node_id": _current_node.id,
		"task_id": recipe_id,
		"task_data": recipe,
		"start_time": current_time,
		"end_time": current_time + duration_secs
	}

	if hex_grid_manager and hex_grid_manager.has_method("add_active_craft"):
		hex_grid_manager.add_active_craft(craft_data)

	# Close popup and refresh
	_close_craft_popup()
	_update_crafting()

func _on_craft_complete(craft_data: Dictionary) -> void:
	"""Handle craft completion - award rewards"""
	var task_data = craft_data.get("task_data", {})

	# Award output resources
	var output = task_data.get("output", {})
	for resource_id in output:
		if resource_manager:
			resource_manager.add_resource(resource_id, output[resource_id])

	print("NodeDetailScreen: Craft complete! Awarded: %s" % str(output))

	# Remove from active crafts
	if hex_grid_manager and hex_grid_manager.has_method("remove_active_craft"):
		hex_grid_manager.remove_active_craft(craft_data.get("node_id", ""), craft_data.get("task_id", ""))

	# Refresh display
	_update_crafting()

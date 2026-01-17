# scripts/ui/screens/NodeDetailScreen.gd
# Fullscreen node detail overlay for managing garrison and workers
# RULE 1: Under 500 lines
# RULE 2: Single responsibility - displays node details with garrison/worker sections
# RULE 4: Read-only display - delegates data changes to parent via signals
# RULE 5: SystemRegistry for all system access
class_name NodeDetailScreen
extends Control

"""
NodeDetailScreen - Mobile-friendly node management interface

Shows:
1. Header - Node name, type icon, tier, close button
2. GarrisonSection - Combat defenders using GarrisonDisplay
3. WorkerSection - Task workers using WorkerSlotDisplay
4. GodSelectionGrid - Overlay for selecting gods (garrison or worker)

Following COMMON_ISSUES.md: Uses _setup_fullscreen() for Control under Node2D.
"""

# ==============================================================================
# SIGNALS
# ==============================================================================
signal close_requested
signal garrison_changed(node: HexNode, garrison_ids: Array)
signal workers_changed(node: HexNode, worker_ids: Array)

# ==============================================================================
# CONSTANTS
# ==============================================================================
const NODE_TYPE_ICONS = {
	"base": "🏛️",
	"mine": "⛏️",
	"forest": "🌲",
	"coast": "🌊",
	"hunting_ground": "🦌",
	"forge": "🔨",
	"library": "📚",
	"temple": "⛪",
	"fortress": "🏰"
}

# ==============================================================================
# UI COMPONENTS
# ==============================================================================
var _background: ColorRect
var _main_container: MarginContainer
var _content_scroll: ScrollContainer
var _content_vbox: VBoxContainer

# Header components
var _header_container: HBoxContainer
var _back_button: Button
var _title_label: Label
var _tier_label: Label

# Section components
var _garrison_section: Control
var _garrison_display: GarrisonDisplay
var _worker_section: Control
var _worker_slot_display: WorkerSlotDisplay

# God selection overlay
var _god_selection_grid: GodSelectionGrid
var _selection_mode: String = ""  # "garrison" or "worker"
var _selection_slot_index: int = -1

# ==============================================================================
# STATE
# ==============================================================================
var _current_node: HexNode = null

# System references
var territory_manager = null
var collection_manager = null

# ==============================================================================
# INITIALIZATION
# ==============================================================================
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

	# God selection overlay (hidden initially)
	_build_god_selection_overlay()

func _build_header(parent: Control) -> void:
	"""Build header with back button, node info, and tier display"""
	# Header panel with styled background
	var header_panel = Panel.new()
	header_panel.custom_minimum_size = Vector2(0, 60)
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

	# Back button (close)
	_back_button = Button.new()
	_back_button.text = "← Back"
	_back_button.custom_minimum_size = Vector2(80, 44)
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

func _create_section_container(title: String) -> Control:
	"""Create a styled section container with title"""
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

	# Content area (named for easy access)
	var content = Control.new()
	content.name = "Content"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)

	return section

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

# ==============================================================================
# PUBLIC API
# ==============================================================================
func show_node(node: HexNode) -> void:
	"""Show the detail screen for a specific node"""
	if not node:
		push_error("NodeDetailScreen: Cannot show null node")
		return

	_current_node = node
	_update_header()
	_update_garrison()
	_update_workers()
	visible = true
	print("NodeDetailScreen: Showing details for node '%s' (type: %s, tier: %d)" % [node.name, node.node_type, node.tier])

func hide_screen() -> void:
	"""Hide the detail screen"""
	visible = false
	_god_selection_grid.visible = false
	_current_node = null

func get_current_node() -> HexNode:
	"""Get the currently displayed node"""
	return _current_node

# ==============================================================================
# UI UPDATE METHODS
# ==============================================================================
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

# ==============================================================================
# EVENT HANDLERS - Garrison
# ==============================================================================
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

# ==============================================================================
# EVENT HANDLERS - Workers
# ==============================================================================
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

# ==============================================================================
# EVENT HANDLERS - God Selection
# ==============================================================================
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

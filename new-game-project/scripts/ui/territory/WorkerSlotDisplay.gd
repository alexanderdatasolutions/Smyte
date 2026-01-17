# scripts/ui/territory/WorkerSlotDisplay.gd
# Mobile-friendly worker slot display for node worker management
# RULE 1: Under 500 lines
# RULE 2: Single responsibility - displays worker slots and their status
# RULE 4: Read-only display - no data modification (emits signals for parent to handle)
# RULE 5: SystemRegistry for all system access
# NOTE: TaskAssignmentManager is territory-level, not per-node. This component
# displays node-specific slot info but worker assignment uses territory APIs.
class_name WorkerSlotDisplay
extends Control

signal empty_slot_tapped(slot_index: int)  # Parent should open GodSelectionGrid
signal filled_slot_tapped(slot_index: int, god: God)  # For unassignment options
signal assign_worker_requested(slot_index: int)  # Request to assign a worker

# Affinity/Element color mapping (matches GodSelectionGrid/GarrisonDisplay)
const ELEMENT_COLORS = {
	God.ElementType.FIRE: Color(0.9, 0.2, 0.1, 1.0),       # Red
	God.ElementType.WATER: Color(0.2, 0.5, 0.9, 1.0),      # Blue
	God.ElementType.EARTH: Color(0.6, 0.4, 0.2, 1.0),      # Brown
	God.ElementType.LIGHTNING: Color(0.6, 0.8, 1.0, 1.0),  # Light Blue (Air)
	God.ElementType.LIGHT: Color(1.0, 0.85, 0.3, 1.0),     # Gold
	God.ElementType.DARK: Color(0.5, 0.2, 0.6, 1.0)        # Purple
}

# Element icons for visual indicator (matches GodSelectionGrid/GarrisonDisplay)
const ELEMENT_ICONS = {
	God.ElementType.FIRE: "🔥",
	God.ElementType.WATER: "💧",
	God.ElementType.EARTH: "🪨",
	God.ElementType.LIGHTNING: "⚡",
	God.ElementType.LIGHT: "☀️",
	God.ElementType.DARK: "🌙"
}

# Slot sizing (60x60px min tap target as specified)
const SLOT_WIDTH = 100
const SLOT_HEIGHT = 120
const SLOT_SPACING = 10

# Core systems
var collection_manager

# UI elements
var _title_label: Label
var _slots_container: HBoxContainer
var _empty_state_label: Label

# State
var _max_slots: int = 3  # Default based on tier (tier = max slots)
var _assigned_workers: Array[God] = []
var _worker_god_ids: Array[String] = []
var _node_type: String = ""  # For displaying task names
var _node_tier: int = 1

func _ready() -> void:
	_init_systems()
	_setup_ui()

func _init_systems() -> void:
	"""Initialize required systems - RULE 5: SystemRegistry access"""
	var registry = SystemRegistry.get_instance()
	if not registry:
		push_error("WorkerSlotDisplay: SystemRegistry not available!")
		return

	collection_manager = registry.get_system("CollectionManager")

	if not collection_manager:
		push_error("WorkerSlotDisplay: CollectionManager not found!")

func _setup_ui() -> void:
	"""Setup the UI structure"""
	# Main section container
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 8)
	add_child(main_vbox)

	# Header row: Title + Slot count
	var header = _create_header()
	main_vbox.add_child(header)

	# Slots container (horizontal scroll for many slots)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, SLOT_HEIGHT + 20)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	_slots_container = HBoxContainer.new()
	_slots_container.add_theme_constant_override("separation", SLOT_SPACING)
	scroll.add_child(_slots_container)

func _create_header() -> Control:
	"""Create header with title and slot count info"""
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)

	# Title
	_title_label = Label.new()
	_title_label.text = "Workers"
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	header.add_child(_title_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	return header

# =============================================================================
# PUBLIC API
# =============================================================================

func setup_for_node(node: HexNode) -> void:
	"""Configure worker slots for a specific hex node"""
	if not node:
		push_error("WorkerSlotDisplay: Cannot setup for null node")
		return

	_node_type = node.node_type
	_node_tier = node.tier
	# Per plan: tier = max slots (but cap at reasonable max)
	_max_slots = mini(node.tier, 5)

	# Get assigned workers from node data
	_worker_god_ids.clear()
	for worker_id in node.assigned_workers:
		_worker_god_ids.append(worker_id)

	_resolve_workers()
	refresh_display()

func set_worker_gods(god_ids: Array[String]) -> void:
	"""Set the worker gods by their IDs and refresh display"""
	_worker_god_ids = god_ids.duplicate()
	_resolve_workers()
	refresh_display()

func get_worker_god_ids() -> Array[String]:
	"""Get current worker god IDs"""
	return _worker_god_ids.duplicate()

func get_max_slots() -> int:
	"""Get maximum worker slots available"""
	return _max_slots

func get_filled_slot_count() -> int:
	"""Get number of filled worker slots"""
	return _assigned_workers.size()

func has_empty_slots() -> bool:
	"""Check if there are any empty worker slots"""
	return _assigned_workers.size() < _max_slots

func add_worker_to_slot(god: God) -> bool:
	"""Add a worker to the next available slot (does not persist - parent handles data)"""
	if not has_empty_slots():
		return false

	if god.id in _worker_god_ids:
		return false  # Already assigned

	_worker_god_ids.append(god.id)
	_assigned_workers.append(god)
	refresh_display()
	return true

func remove_worker_from_slot(god_id: String) -> void:
	"""Remove a worker from their slot by ID"""
	var idx = _worker_god_ids.find(god_id)
	if idx >= 0:
		_worker_god_ids.remove_at(idx)
		# Find and remove from workers array
		for i in range(_assigned_workers.size()):
			if _assigned_workers[i].id == god_id:
				_assigned_workers.remove_at(i)
				break
		refresh_display()

func refresh_display() -> void:
	"""Refresh the worker slots display - RULE 4: Read-only display"""
	_clear_slots()
	_create_worker_slots()

	print("WorkerSlotDisplay: Showing %d/%d worker slots (node type: %s, tier: %d)" % [
		_assigned_workers.size(), _max_slots, _node_type, _node_tier
	])

# =============================================================================
# INTERNAL HELPERS
# =============================================================================

func _resolve_workers() -> void:
	"""Resolve worker IDs to God objects using CollectionManager"""
	_assigned_workers.clear()

	if not collection_manager:
		return

	for god_id in _worker_god_ids:
		var god = collection_manager.get_god_by_id(god_id)
		if god:
			_assigned_workers.append(god)
		else:
			push_warning("WorkerSlotDisplay: Could not find god with ID: " + god_id)

func _clear_slots() -> void:
	"""Clear existing slot UI elements"""
	for child in _slots_container.get_children():
		child.queue_free()

func _create_worker_slots() -> void:
	"""Create slot UI elements for all slots"""
	for i in range(_max_slots):
		var slot: Control
		if i < _assigned_workers.size():
			# Filled slot - show god with task info
			slot = _create_filled_slot(i, _assigned_workers[i])
		else:
			# Empty slot - show '+' button
			slot = _create_empty_slot(i)
		_slots_container.add_child(slot)

func _create_empty_slot(slot_index: int) -> Control:
	"""Create an empty worker slot with '+' icon (60x60px minimum tap target)"""
	var slot = Panel.new()
	slot.custom_minimum_size = Vector2(SLOT_WIDTH, SLOT_HEIGHT)
	slot.name = "EmptySlot_" + str(slot_index)

	# Style: dashed border appearance
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.8)
	style.border_color = Color(0.4, 0.4, 0.4, 0.6)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	slot.add_theme_stylebox_override("panel", style)

	# Content container
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	slot.add_child(vbox)

	# Spacer top
	var spacer_top = Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_top)

	# Plus icon (large, centered)
	var plus_label = Label.new()
	plus_label.text = "+"
	plus_label.add_theme_font_size_override("font_size", 32)
	plus_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	plus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(plus_label)

	# "Empty Slot" text
	var empty_label = Label.new()
	empty_label.text = "Empty Slot"
	empty_label.add_theme_font_size_override("font_size", 10)
	empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(empty_label)

	# Spacer bottom
	var spacer_bottom = Control.new()
	spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_bottom)

	# Tappable button overlay (60x60 min tap target)
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_empty_slot_pressed.bind(slot_index))
	slot.add_child(button)

	return slot

func _create_filled_slot(slot_index: int, god: God) -> Control:
	"""Create a filled worker slot showing god portrait, task name, and output info"""
	var slot = Panel.new()
	slot.custom_minimum_size = Vector2(SLOT_WIDTH, SLOT_HEIGHT)
	slot.name = "FilledSlot_" + str(slot_index)

	# Style with element color border - enhanced visibility
	var element_color = ELEMENT_COLORS.get(god.element, Color.GRAY)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 0.9)
	style.border_color = element_color
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	slot.add_theme_stylebox_override("panel", style)

	# Main layout with margin
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	slot.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)

	# Portrait (40x40)
	var portrait_container = CenterContainer.new()
	var portrait = _create_portrait(god)
	portrait_container.add_child(portrait)
	vbox.add_child(portrait_container)

	# God name (truncated)
	var name_label = Label.new()
	name_label.text = _truncate_name(god.name, 12)
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# Element indicator badge
	var element_indicator = _create_element_indicator(god)
	vbox.add_child(element_indicator)

	# Task/Output info (based on node type)
	var task_label = Label.new()
	task_label.text = _get_task_display_for_node()
	task_label.add_theme_font_size_override("font_size", 9)
	task_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))  # Green for active work
	task_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(task_label)

	# Tappable button overlay
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_filled_slot_pressed.bind(slot_index, god))
	slot.add_child(button)

	return slot

func _create_element_indicator(god: God) -> Control:
	"""Create element indicator with icon and colored background badge"""
	var container = CenterContainer.new()

	# Badge panel with element color
	var element_color = ELEMENT_COLORS.get(god.element, Color.GRAY)
	var badge = Panel.new()
	badge.custom_minimum_size = Vector2(22, 14)

	var badge_style = StyleBoxFlat.new()
	badge_style.bg_color = element_color.darkened(0.2)
	badge_style.corner_radius_top_left = 3
	badge_style.corner_radius_top_right = 3
	badge_style.corner_radius_bottom_left = 3
	badge_style.corner_radius_bottom_right = 3
	badge.add_theme_stylebox_override("panel", badge_style)

	# Element icon label
	var icon_label = Label.new()
	icon_label.text = ELEMENT_ICONS.get(god.element, "?")
	icon_label.add_theme_font_size_override("font_size", 9)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge.add_child(icon_label)

	container.add_child(badge)
	return container

func _create_portrait(god: God) -> Control:
	"""Create god portrait with element-colored placeholder if no image"""
	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(40, 40)
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Try to load portrait
	var sprite_path = "res://assets/gods/" + god.id + ".png"
	if ResourceLoader.exists(sprite_path):
		portrait.texture = load(sprite_path)
	else:
		# Create element-colored placeholder
		var element_color = ELEMENT_COLORS.get(god.element, Color.GRAY)
		var placeholder = _create_color_placeholder(element_color, 40, 40)
		portrait.texture = placeholder

	return portrait

func _create_color_placeholder(color: Color, width: int, height: int) -> ImageTexture:
	"""Create a colored placeholder texture"""
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var texture = ImageTexture.create_from_image(image)
	return texture

func _truncate_name(text: String, max_length: int) -> String:
	"""Truncate name if too long"""
	if text.length() <= max_length:
		return text
	return text.substr(0, max_length - 2) + ".."

func _get_task_display_for_node() -> String:
	"""Get the task display text based on node type"""
	# Show appropriate task name based on node type
	match _node_type:
		"mine":
			return "Mining"
		"forest":
			return "Gathering"
		"coast":
			return "Fishing"
		"hunting_ground":
			return "Hunting"
		"forge":
			return "Forging"
		"library":
			return "Research"
		"temple":
			return "Prayer"
		"fortress":
			return "Training"
		_:
			return "Working"

func _on_empty_slot_pressed(slot_index: int) -> void:
	"""Handle tap on empty slot"""
	print("WorkerSlotDisplay: Empty slot %d tapped" % slot_index)
	empty_slot_tapped.emit(slot_index)
	assign_worker_requested.emit(slot_index)

func _on_filled_slot_pressed(slot_index: int, god: God) -> void:
	"""Handle tap on filled slot"""
	print("WorkerSlotDisplay: Filled slot %d tapped (god: %s)" % [slot_index, god.name])
	filled_slot_tapped.emit(slot_index, god)

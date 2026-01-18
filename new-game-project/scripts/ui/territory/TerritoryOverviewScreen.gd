# scripts/ui/territory/TerritoryOverviewScreen.gd
# Overview screen showing all territory nodes and their assignments
extends Control
class_name TerritoryOverviewScreen

"""
Territory Overview - Shows all hex nodes at a glance with inline garrison/worker slots
Allows quick viewing and management of:
- All owned nodes with type and tier info
- Garrison slots (4 per node) with god portraits
- Worker slots (node.tier count) with god portraits
- Tap empty slots to assign gods, tap filled slots to unassign

Note: Worker assignments are managed at the territory level, not per-node.
"""

signal back_pressed()
signal manage_node_requested(node: HexNode)
signal slot_tapped(node: HexNode, slot_type: String, slot_index: int)  # "garrison" or "worker"
signal filled_slot_tapped(node: HexNode, slot_type: String, slot_index: int, god: God)  # For removal

# Constants for slot display
const SLOT_SIZE = 60  # 60x60px tap target (min requirement)
const SLOT_SPACING = 6
const MAX_GARRISON_SLOTS = 4  # Fixed garrison slots per node
const ELEMENT_COLORS = {
	God.ElementType.FIRE: Color(0.9, 0.2, 0.1),
	God.ElementType.WATER: Color(0.2, 0.5, 0.9),
	God.ElementType.EARTH: Color(0.6, 0.4, 0.2),
	God.ElementType.LIGHTNING: Color(0.6, 0.8, 1.0),
	God.ElementType.LIGHT: Color(1.0, 0.85, 0.3),
	God.ElementType.DARK: Color(0.5, 0.2, 0.6)
}

# System references
var territory_manager = null
var collection_manager = null
var production_manager = null
var resource_manager = null

# UI Components
var _scroll_container: ScrollContainer
var _node_list_container: VBoxContainer
var _header_label: Label
var _summary_label: Label
var _filter_options: HBoxContainer
var _production_summary_container: VBoxContainer
var _pending_resources_container: VBoxContainer
var _claim_all_button: Button

# Filter state
var _filter_by_type: String = ""  # Empty = show all

func _ready():
	_setup_fullscreen()
	_init_systems()
	_build_ui()
	_refresh_display()

func _setup_fullscreen():
	"""Setup fullscreen sizing (required when Control is child of Node2D)"""
	var viewport_size = get_viewport().get_visible_rect().size
	set_anchors_preset(Control.PRESET_FULL_RECT)
	call_deferred("set_size", viewport_size)
	position = Vector2.ZERO

	# Ensure clip contents so nothing overflows
	clip_contents = true

func _init_systems():
	"""Initialize system references"""
	var registry = SystemRegistry.get_instance()
	territory_manager = registry.get_system("TerritoryManager")
	collection_manager = registry.get_system("CollectionManager")
	production_manager = registry.get_system("TerritoryProductionManager")
	resource_manager = registry.get_system("ResourceManager")

func _build_ui():
	"""Build the UI structure"""
	# Background
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.08, 1)
	add_child(bg)

	# Add margins
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(content_vbox)

	# Header
	_header_label = Label.new()
	_header_label.text = "TERRITORY MANAGEMENT"
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_size_override("font_size", 24)
	_header_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1, 1))
	_header_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_vbox.add_child(_header_label)

	# Summary row
	_summary_label = Label.new()
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_label.add_theme_font_size_override("font_size", 14)
	_summary_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9, 1))
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_vbox.add_child(_summary_label)

	# Production Summary Section
	_build_production_summary(content_vbox)

	# Filter options
	_build_filters(content_vbox)

	# Scroll container for node list
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(_scroll_container)

	# Node list container
	_node_list_container = VBoxContainer.new()
	_node_list_container.add_theme_constant_override("separation", 8)
	_scroll_container.add_child(_node_list_container)

	# Back button at bottom
	var back_btn = Button.new()
	back_btn.text = "BACK"
	back_btn.custom_minimum_size = Vector2(120, 40)
	back_btn.pressed.connect(_on_back_pressed)
	content_vbox.add_child(back_btn)

func _build_production_summary(parent: VBoxContainer):
	"""Build production summary section showing total production and pending resources"""
	var summary_panel = Panel.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.15, 0.2, 0.8)
	panel_style.border_color = Color(0.4, 0.6, 0.7, 1)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	summary_panel.add_theme_stylebox_override("panel", panel_style)
	parent.add_child(summary_panel)

	var panel_vbox = VBoxContainer.new()
	panel_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_vbox.add_theme_constant_override("separation", 12)
	panel_vbox.offset_left = 16
	panel_vbox.offset_top = 12
	panel_vbox.offset_right = -16
	panel_vbox.offset_bottom = -12
	summary_panel.add_child(panel_vbox)

	# Total production section
	var production_title = Label.new()
	production_title.text = "TOTAL HOURLY PRODUCTION"
	production_title.add_theme_font_size_override("font_size", 14)
	production_title.add_theme_color_override("font_color", Color(0.8, 0.9, 1, 1))
	panel_vbox.add_child(production_title)

	_production_summary_container = VBoxContainer.new()
	_production_summary_container.add_theme_constant_override("separation", 4)
	panel_vbox.add_child(_production_summary_container)

	# Pending resources section
	var pending_title = Label.new()
	pending_title.text = "PENDING RESOURCES"
	pending_title.add_theme_font_size_override("font_size", 14)
	pending_title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6, 1))
	panel_vbox.add_child(pending_title)

	_pending_resources_container = VBoxContainer.new()
	_pending_resources_container.add_theme_constant_override("separation", 4)
	panel_vbox.add_child(_pending_resources_container)

	# Claim All button
	_claim_all_button = Button.new()
	_claim_all_button.text = "CLAIM ALL RESOURCES"
	_claim_all_button.custom_minimum_size = Vector2(200, 40)
	_claim_all_button.add_theme_color_override("font_color", Color.WHITE)
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.6, 0.3, 1)
	button_style.set_corner_radius_all(6)
	_claim_all_button.add_theme_stylebox_override("normal", button_style)
	var button_hover_style = StyleBoxFlat.new()
	button_hover_style.bg_color = Color(0.3, 0.7, 0.4, 1)
	button_hover_style.set_corner_radius_all(6)
	_claim_all_button.add_theme_stylebox_override("hover", button_hover_style)
	_claim_all_button.pressed.connect(_on_claim_all_pressed)
	panel_vbox.add_child(_claim_all_button)

func _build_filters(parent: VBoxContainer):
	"""Build filter controls"""
	_filter_options = HBoxContainer.new()
	_filter_options.add_theme_constant_override("separation", 12)
	parent.add_child(_filter_options)

	# Label
	var label = Label.new()
	label.text = "Filters:"
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9, 1))
	_filter_options.add_child(label)

	# Type filter
	var type_label = Label.new()
	type_label.text = "Type:"
	type_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9, 1))
	_filter_options.add_child(type_label)

	var type_option = OptionButton.new()
	type_option.add_item("All Types", 0)
	type_option.add_item("Mines", 1)
	type_option.add_item("Forests", 2)
	type_option.add_item("Coasts", 3)
	type_option.add_item("Other", 4)
	type_option.item_selected.connect(_on_type_filter_changed)
	_filter_options.add_child(type_option)

	# Refresh button
	var refresh_btn = Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(_refresh_display)
	_filter_options.add_child(refresh_btn)

func _refresh_display():
	"""Refresh the entire display"""
	_update_summary()
	_update_production_summary()
	_populate_node_list()

func _update_summary():
	"""Update summary statistics"""
	if not territory_manager:
		_summary_label.text = "Systems not initialized"
		return

	var owned_nodes = territory_manager.get_controlled_nodes()
	var total_nodes = owned_nodes.size()

	_summary_label.text = "%d Nodes Controlled" % [total_nodes]

func _update_production_summary():
	"""Update total production and pending resources display"""
	# Clear existing children
	for child in _production_summary_container.get_children():
		child.queue_free()
	for child in _pending_resources_container.get_children():
		child.queue_free()

	if not production_manager:
		var error_label = Label.new()
		error_label.text = "Production system not available"
		error_label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
		_production_summary_container.add_child(error_label)
		_claim_all_button.disabled = true
		return

	# Get total hourly production
	var total_production = production_manager.get_all_hex_nodes_production()

	if total_production.is_empty():
		var no_prod_label = Label.new()
		no_prod_label.text = "No active production (assign workers to nodes)"
		no_prod_label.add_theme_font_size_override("font_size", 12)
		no_prod_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		_production_summary_container.add_child(no_prod_label)
	else:
		for resource_id in total_production:
			var amount = total_production[resource_id]
			var resource_label = Label.new()
			resource_label.text = "%s: +%.1f/hour" % [_format_resource_name(resource_id), amount]
			resource_label.add_theme_font_size_override("font_size", 13)
			resource_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.8))
			_production_summary_container.add_child(resource_label)

	# Get total pending resources across all nodes
	var total_pending = _get_total_pending_resources()

	if total_pending.is_empty():
		var no_pending_label = Label.new()
		no_pending_label.text = "No pending resources (wait for production to accumulate)"
		no_pending_label.add_theme_font_size_override("font_size", 12)
		no_pending_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		_pending_resources_container.add_child(no_pending_label)
		_claim_all_button.disabled = true
	else:
		for resource_id in total_pending:
			var amount = total_pending[resource_id]
			var pending_label = Label.new()
			pending_label.text = "%s: %.1f" % [_format_resource_name(resource_id), amount]
			pending_label.add_theme_font_size_override("font_size", 13)
			pending_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
			_pending_resources_container.add_child(pending_label)
		_claim_all_button.disabled = false

func _get_total_pending_resources() -> Dictionary:
	"""Calculate total pending resources across all controlled nodes"""
	var total_pending = {}

	if not territory_manager:
		return total_pending

	var controlled_nodes = territory_manager.get_controlled_nodes()
	for node in controlled_nodes:
		if not node or not node.accumulated_resources:
			continue

		for resource_id in node.accumulated_resources:
			var amount = node.accumulated_resources[resource_id]
			total_pending[resource_id] = total_pending.get(resource_id, 0.0) + amount

	return total_pending

func _format_resource_name(resource_id: String) -> String:
	"""Format resource ID to display name"""
	return resource_id.replace("_", " ").capitalize()

func _populate_node_list():
	"""Populate the list of nodes"""
	# Clear existing
	for child in _node_list_container.get_children():
		child.queue_free()

	if not territory_manager:
		return

	var owned_nodes = territory_manager.get_controlled_nodes()

	# Apply filters
	var filtered_nodes = []
	for node in owned_nodes:
		# Type filter
		if _filter_by_type != "":
			if _filter_by_type == "mine" and node.node_type != "mine":
				continue
			elif _filter_by_type == "forest" and node.node_type != "forest":
				continue
			elif _filter_by_type == "coast" and node.node_type != "coast":
				continue
			elif _filter_by_type == "other" and (node.node_type == "mine" or node.node_type == "forest" or node.node_type == "coast"):
				continue

		filtered_nodes.append(node)

	# Sort by tier, then name
	filtered_nodes.sort_custom(func(a, b): return a.tier > b.tier if a.tier != b.tier else a.name < b.name)

	# Create cards
	for node in filtered_nodes:
		var card = _create_node_card(node)
		_node_list_container.add_child(card)

	# No results message
	if filtered_nodes.is_empty():
		var no_results = Label.new()
		no_results.text = "No nodes match the current filters"
		no_results.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_results.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 1))
		_node_list_container.add_child(no_results)

func _create_node_card(node: HexNode) -> Panel:
	"""Create a card with inline garrison and worker slot boxes"""
	var card = Panel.new()
	card.custom_minimum_size = Vector2(0, 260)  # header(50)+garrison(90)+workers(90)+padding(30)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.9)
	style.border_color = Color(0.3, 0.4, 0.5, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)

	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 8)
	main_vbox.offset_left = 12; main_vbox.offset_top = 10
	main_vbox.offset_right = -12; main_vbox.offset_bottom = -10
	card.add_child(main_vbox)

	# Header: name, type badge, tier stars
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var name_lbl = Label.new()
	name_lbl.text = node.name
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 1))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_lbl)
	header.add_child(_create_type_badge(node.node_type))
	var stars_lbl = Label.new()
	stars_lbl.text = "★".repeat(node.tier) if node.tier > 0 else "☆"
	stars_lbl.add_theme_font_size_override("font_size", 12)
	stars_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	header.add_child(stars_lbl)
	main_vbox.add_child(header)

	# Garrison section
	main_vbox.add_child(_create_slot_section(node, "Garrison (Defense)", Color(0.8, 0.7, 0.6), "garrison", MAX_GARRISON_SLOTS, node.garrison))
	# Worker section
	var max_workers = mini(node.tier, 5)
	if max_workers > 0:
		main_vbox.add_child(_create_slot_section(node, "Workers (Production)", Color(0.6, 0.8, 0.7), "worker", max_workers, node.assigned_workers))
	else:
		var no_lbl = Label.new()
		no_lbl.text = "Workers: Not available (Tier 0)"
		no_lbl.add_theme_font_size_override("font_size", 11)
		no_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		main_vbox.add_child(no_lbl)
	return card

func _create_type_badge(node_type: String) -> Control:
	"""Create a small badge showing node type"""
	var badge = Panel.new()
	badge.custom_minimum_size = Vector2(70, 22)
	var colors = {"mine": Color(0.5, 0.35, 0.2), "forest": Color(0.2, 0.45, 0.25),
		"coast": Color(0.2, 0.4, 0.6), "hunting_ground": Color(0.5, 0.3, 0.3),
		"forge": Color(0.55, 0.35, 0.2), "library": Color(0.35, 0.3, 0.5),
		"temple": Color(0.45, 0.4, 0.25), "fortress": Color(0.35, 0.35, 0.4)}
	var badge_style = StyleBoxFlat.new()
	badge_style.bg_color = colors.get(node_type, Color(0.3, 0.3, 0.35))
	badge_style.set_corner_radius_all(4)
	badge.add_theme_stylebox_override("panel", badge_style)
	var lbl = Label.new()
	lbl.text = node_type.capitalize()
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge.add_child(lbl)
	return badge

func _create_slot_section(node: HexNode, title: String, title_color: Color, slot_type: String, slot_count: int, assigned_ids: Array) -> Control:
	"""Create a slot section (garrison or worker) with label and slot boxes"""
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	var lbl = Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", title_color)
	section.add_child(lbl)
	var slots_row = HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", SLOT_SPACING)
	section.add_child(slots_row)
	for i in range(slot_count):
		var slot: Control
		if i < assigned_ids.size():
			var god = _get_god_by_id(assigned_ids[i])
			slot = _create_filled_slot(node, slot_type, i, god)
		else:
			slot = _create_empty_slot(node, slot_type, i)
		slots_row.add_child(slot)
	return section

func _create_empty_slot(node: HexNode, slot_type: String, slot_index: int) -> Control:
	"""Create an empty slot with '+' icon (60x60px tap target)"""
	var slot = Panel.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot.add_theme_stylebox_override("panel", _create_slot_style(Color(0.4, 0.4, 0.45, 0.7), 2))
	# Plus icon
	var plus_label = Label.new()
	plus_label.text = "+"
	plus_label.add_theme_font_size_override("font_size", 24)
	plus_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	plus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(plus_label)
	# Tappable button
	_add_slot_button(slot, node, slot_type, slot_index)
	return slot

func _create_filled_slot(node: HexNode, slot_type: String, slot_index: int, god: God) -> Control:
	"""Create a filled slot showing god portrait (60x60px)"""
	var slot = Panel.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	var border_color = ELEMENT_COLORS.get(god.element, Color.GRAY) if god else Color(0.5, 0.5, 0.5)
	slot.add_theme_stylebox_override("panel", _create_slot_style(border_color, 3))
	if god:
		var portrait = _create_god_portrait(god)
		portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		portrait.offset_left = 4; portrait.offset_right = -4
		portrait.offset_top = 4; portrait.offset_bottom = -14
		slot.add_child(portrait)
		var level_label = Label.new()
		level_label.text = "Lv.%d" % god.level
		level_label.add_theme_font_size_override("font_size", 9)
		level_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.anchor_left = 0; level_label.anchor_right = 1
		level_label.anchor_top = 1; level_label.anchor_bottom = 1
		level_label.offset_top = -14; level_label.offset_bottom = -2
		slot.add_child(level_label)
	else:
		var lbl = Label.new()
		lbl.text = "?"
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(lbl)
	# Use filled slot handler for filled slots
	_add_filled_slot_button(slot, node, slot_type, slot_index, god)
	return slot

func _create_slot_style(border_color: Color, border_width: int) -> StyleBoxFlat:
	"""Create slot panel style"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 0.9)
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	return style

func _add_slot_button(slot: Panel, node: HexNode, slot_type: String, slot_index: int) -> void:
	"""Add tappable button overlay to empty slot"""
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_slot_tapped.bind(node, slot_type, slot_index))
	slot.add_child(button)

func _add_filled_slot_button(slot: Panel, node: HexNode, slot_type: String, slot_index: int, god: God) -> void:
	"""Add tappable button overlay to filled slot (emits different signal)"""
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_filled_slot_tapped.bind(node, slot_type, slot_index, god))
	slot.add_child(button)

func _create_god_portrait(god: God) -> TextureRect:
	"""Create god portrait TextureRect"""
	var portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var sprite_path = "res://assets/gods/" + god.id + ".png"
	if ResourceLoader.exists(sprite_path):
		portrait.texture = load(sprite_path)
	else:
		var element_color = ELEMENT_COLORS.get(god.element, Color.GRAY)
		var image = Image.create(50, 50, false, Image.FORMAT_RGBA8)
		image.fill(element_color)
		portrait.texture = ImageTexture.create_from_image(image)
	return portrait

func _get_god_by_id(god_id: String) -> God:
	"""Get god by ID from CollectionManager"""
	if not collection_manager:
		return null
	if god_id == "":
		return null
	return collection_manager.get_god_by_id(god_id)

func _on_slot_tapped(node: HexNode, slot_type: String, slot_index: int) -> void:
	"""Handle empty slot tap - emit signal for parent to open god selection"""
	print("TerritoryOverviewScreen: Empty slot tapped - node: %s, type: %s, index: %d" % [node.id, slot_type, slot_index])
	slot_tapped.emit(node, slot_type, slot_index)

func _on_filled_slot_tapped(node: HexNode, slot_type: String, slot_index: int, god: God) -> void:
	"""Handle filled slot tap - emit signal for parent to show remove confirmation"""
	print("TerritoryOverviewScreen: Filled slot tapped - node: %s, type: %s, index: %d, god: %s" % [node.id, slot_type, slot_index, god.name if god else "null"])
	filled_slot_tapped.emit(node, slot_type, slot_index, god)

func _on_type_filter_changed(index: int):
	"""Handle type filter change"""
	match index:
		0: _filter_by_type = ""
		1: _filter_by_type = "mine"
		2: _filter_by_type = "forest"
		3: _filter_by_type = "coast"
		4: _filter_by_type = "other"

	_populate_node_list()

func _on_manage_node_pressed(node: HexNode):
	"""Handle manage button press for a specific node"""
	manage_node_requested.emit(node)

func _on_claim_all_pressed():
	"""Handle Claim All Resources button press"""
	if not production_manager or not territory_manager or not resource_manager:
		print("[TerritoryOverviewScreen] ERROR: Required systems not available for claim all")
		return

	var controlled_nodes = territory_manager.get_controlled_nodes()
	var total_collected = {}
	var nodes_collected_count = 0

	# Collect from each node
	for node in controlled_nodes:
		if not node or node.accumulated_resources.is_empty():
			continue

		var collected = production_manager.collect_node_resources(node.id)
		if not collected.is_empty():
			nodes_collected_count += 1
			for resource_id in collected:
				total_collected[resource_id] = total_collected.get(resource_id, 0.0) + collected[resource_id]

	# Show feedback
	if total_collected.is_empty():
		print("[TerritoryOverviewScreen] No resources to claim")
	else:
		print("[TerritoryOverviewScreen] Claimed all resources from %d nodes: %s" % [nodes_collected_count, _format_resources_dict(total_collected)])

	# Refresh display
	_update_production_summary()

func _format_resources_dict(resources: Dictionary) -> String:
	"""Format resources dictionary for display"""
	if resources.is_empty():
		return "{}"
	var parts = []
	for resource_id in resources:
		parts.append("%s: %.1f" % [resource_id, resources[resource_id]])
	return "{" + ", ".join(parts) + "}"

func _on_back_pressed():
	"""Handle back button press"""
	back_pressed.emit()

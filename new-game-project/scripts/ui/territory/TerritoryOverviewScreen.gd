# scripts/ui/territory/TerritoryOverviewScreen.gd
# Overview screen showing all territory nodes and their assignments
extends Control
class_name TerritoryOverviewScreen

"""
Territory Overview - Shows all hex nodes at a glance
Allows quick viewing of:
- All owned nodes
- Node types and tiers
- Quick jump to detailed management

Note: Worker assignments are managed at the territory level, not per-node.
"""

signal back_pressed()
signal manage_node_requested(node: HexNode)

# System references
var territory_manager = null

# UI Components
var _scroll_container: ScrollContainer
var _node_list_container: VBoxContainer
var _header_label: Label
var _summary_label: Label
var _filter_options: HBoxContainer

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
	_populate_node_list()

func _update_summary():
	"""Update summary statistics"""
	if not territory_manager:
		_summary_label.text = "Systems not initialized"
		return

	var owned_nodes = territory_manager.get_controlled_nodes()
	var total_nodes = owned_nodes.size()

	_summary_label.text = "%d Nodes Controlled" % [total_nodes]

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
	"""Create a card for a single node"""
	var card = Panel.new()
	card.custom_minimum_size = Vector2(0, 60)

	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.4, 0.5, 1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	card.add_theme_stylebox_override("panel", style)

	# Content container
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 16)
	hbox.offset_left = 12
	hbox.offset_top = 12
	hbox.offset_right = -12
	hbox.offset_bottom = -12
	card.add_child(hbox)

	# Left side - Node info
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(left_vbox)

	# Node name and type
	var name_label = Label.new()
	name_label.text = "%s (%s)" % [node.name, node.node_type.capitalize()]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1, 1))
	left_vbox.add_child(name_label)

	# Tier info
	var tier_label = Label.new()
	tier_label.text = "Tier %d Node" % [node.tier]
	tier_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9, 1))
	left_vbox.add_child(tier_label)

	# Right side - Actions
	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 8)
	hbox.add_child(right_vbox)

	# View button
	var view_btn = Button.new()
	view_btn.text = "View Details"
	view_btn.custom_minimum_size = Vector2(120, 32)
	view_btn.pressed.connect(func(): _on_manage_node_pressed(node))
	right_vbox.add_child(view_btn)

	return card

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

func _on_back_pressed():
	"""Handle back button press"""
	back_pressed.emit()

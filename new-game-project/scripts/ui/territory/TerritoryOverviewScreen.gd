# scripts/ui/territory/TerritoryOverviewScreen.gd
extends Control
class_name TerritoryOverviewScreen

signal back_pressed()
signal manage_node_requested(node: HexNode)
signal slot_tapped(node: HexNode, slot_type: String, slot_index: int)
signal filled_slot_tapped(node: HexNode, slot_type: String, slot_index: int, god: God)

# ==============================================================================
# CONSTANTS
# ==============================================================================
const SLOT_SIZE = 60
const SLOT_SPACING = 4
const MAX_GARRISON_SLOTS = 4
const CARD_HEIGHT = 120

const ELEMENT_COLORS = {
	God.ElementType.FIRE: Color(0.9, 0.2, 0.1),
	God.ElementType.WATER: Color(0.2, 0.5, 0.9),
	God.ElementType.EARTH: Color(0.6, 0.4, 0.2),
	God.ElementType.LIGHTNING: Color(0.6, 0.8, 1.0),
	God.ElementType.LIGHT: Color(1.0, 0.85, 0.3),
	God.ElementType.DARK: Color(0.5, 0.2, 0.6)
}

const NODE_TYPE_COLORS = {
	"mine": Color(0.5, 0.35, 0.2),
	"forest": Color(0.2, 0.45, 0.25),
	"coast": Color(0.2, 0.4, 0.6),
	"hunting_ground": Color(0.5, 0.3, 0.3),
	"forge": Color(0.55, 0.35, 0.2),
	"library": Color(0.35, 0.3, 0.5),
	"temple": Color(0.45, 0.4, 0.25),
	"fortress": Color(0.35, 0.35, 0.4),
	"base": Color(0.4, 0.35, 0.5)
}

# ==============================================================================
# STATE
# ==============================================================================
var territory_manager = null
var collection_manager = null
var production_manager = null
var resource_manager = null
var hex_grid_manager = null  # For shared craft tracking

var _scroll_container: ScrollContainer
var _node_list: VBoxContainer
var _summary_label: Label
var _production_label: Label
var _pending_label: Label
var _claim_button: Button
var _filter_type: String = ""

# Crafting system
var _tasks_data: Dictionary = {}
var _craft_popup: Control = null
var _current_craft_node: HexNode = null
var _craft_update_timer: float = 0.0

# ==============================================================================
# LIFECYCLE
# ==============================================================================
var _refresh_timer: Timer

func _ready():
	_init_systems()
	_load_tasks_data()
	_build_ui()
	_refresh_display()
	_setup_refresh_timer()

func _process(delta: float) -> void:
	# Update crafting progress every second
	if not visible:
		return

	# Check shared tracker for active crafts
	var has_active = false
	if hex_grid_manager:
		has_active = not hex_grid_manager.get_active_crafts().is_empty()

	if not has_active:
		return

	_craft_update_timer += delta
	if _craft_update_timer >= 1.0:
		_craft_update_timer = 0.0
		_populate_nodes()  # Refresh to update progress bars

func _setup_refresh_timer():
	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = 5.0  # Refresh every 5 seconds
	_refresh_timer.autostart = true
	_refresh_timer.timeout.connect(_on_refresh_timer)
	add_child(_refresh_timer)

func _on_refresh_timer():
	if is_visible_in_tree():
		_refresh_display()

func _init_systems():
	var registry = SystemRegistry.get_instance()
	territory_manager = registry.get_system("TerritoryManager")
	collection_manager = registry.get_system("CollectionManager")
	production_manager = registry.get_system("TerritoryProductionManager")
	resource_manager = registry.get_system("ResourceManager")
	hex_grid_manager = registry.get_system("HexGridManager")

func _load_tasks_data() -> void:
	"""Load crafting recipes from JSON file"""
	var file_path = "res://data/crafting_recipes.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("TerritoryOverviewScreen: Could not load crafting_recipes.json")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("TerritoryOverviewScreen: Failed to parse crafting_recipes.json")
		return

	var data = json.get_data()
	# Load recipes from flattened structure (recipes at top level)
	_tasks_data = {}
	for recipe_id in data.keys():
		# Skip metadata and comment keys
		if recipe_id.begins_with("_"):
			continue
		var recipe = data[recipe_id]
		if recipe is Dictionary:
			_tasks_data[recipe_id] = recipe

# ==============================================================================
# UI BUILD
# ==============================================================================
func _build_ui():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true

	# Background
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.08, 0.1, 1)
	add_child(bg)

	# Main layout (offset_top accounts for unified header ~50px)
	var main = VBoxContainer.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.offset_left = 16
	main.offset_right = -16
	main.offset_top = 55
	main.offset_bottom = -10
	main.add_theme_constant_override("separation", 8)
	add_child(main)

	# Header row
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	main.add_child(header)

	var title = Label.new()
	title.text = "TERRITORY OVERVIEW"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 1))
	header.add_child(title)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_summary_label = Label.new()
	_summary_label.add_theme_font_size_override("font_size", 14)
	_summary_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	header.add_child(_summary_label)

	# Production summary section (vertical to prevent horizontal overflow)
	var prod_section = VBoxContainer.new()
	prod_section.add_theme_constant_override("separation", 4)
	main.add_child(prod_section)

	_production_label = Label.new()
	_production_label.add_theme_font_size_override("font_size", 12)
	_production_label.add_theme_color_override("font_color", Color(0.6, 0.85, 0.7))
	_production_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prod_section.add_child(_production_label)

	_pending_label = Label.new()
	_pending_label.add_theme_font_size_override("font_size", 12)
	_pending_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_pending_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prod_section.add_child(_pending_label)

	_claim_button = Button.new()
	_claim_button.text = "COLLECT ALL"
	_claim_button.custom_minimum_size = Vector2(120, 32)
	_claim_button.pressed.connect(_on_claim_all)
	_style_button(_claim_button, Color(0.2, 0.5, 0.3))
	prod_section.add_child(_claim_button)

	# Filter row
	var filter_row = HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 8)
	main.add_child(filter_row)

	var filter_label = Label.new()
	filter_label.text = "Filter:"
	filter_label.add_theme_font_size_override("font_size", 12)
	filter_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	filter_row.add_child(filter_label)

	var filter_option = OptionButton.new()
	filter_option.add_item("All", 0)
	filter_option.add_item("Mines", 1)
	filter_option.add_item("Forests", 2)
	filter_option.add_item("Coasts", 3)
	filter_option.add_item("Other", 4)
	filter_option.item_selected.connect(_on_filter_changed)
	filter_row.add_child(filter_option)

	# Scroll container for node list
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	main.add_child(_scroll_container)

	_node_list = VBoxContainer.new()
	_node_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_node_list.add_theme_constant_override("separation", 6)
	_scroll_container.add_child(_node_list)

	# Back button
	var back_btn = Button.new()
	back_btn.text = "BACK TO MAP"
	back_btn.custom_minimum_size = Vector2(140, 36)
	back_btn.pressed.connect(func(): back_pressed.emit())
	_style_button(back_btn, Color(0.3, 0.25, 0.35))
	main.add_child(back_btn)

func _style_button(btn: Button, bg_color: Color):
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)

	var hover = StyleBoxFlat.new()
	hover.bg_color = bg_color.lightened(0.15)
	hover.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("hover", hover)

# ==============================================================================
# REFRESH
# ==============================================================================
func _refresh_display():
	_update_summary()
	_update_production()
	_populate_nodes()

func _update_summary():
	if not territory_manager:
		_summary_label.text = "N/A"
		return

	var count = territory_manager.get_controlled_nodes().size()
	_summary_label.text = "%d Nodes" % count

func _update_production():
	if not production_manager:
		_production_label.text = "Production: N/A"
		_pending_label.text = ""
		_claim_button.disabled = true
		return

	# Total hourly production
	var total = production_manager.get_all_hex_nodes_production()
	if total.is_empty():
		_production_label.text = "Production: None (assign workers)"
	else:
		var parts = []
		for res_id in total:
			parts.append("%s +%.0f/h" % [_short_name(res_id), total[res_id]])
		_production_label.text = "Production: " + ", ".join(parts)

	# Pending resources
	var pending = _get_total_pending()
	if pending.is_empty():
		_pending_label.text = "Pending: None"
		_claim_button.disabled = true
	else:
		var parts = []
		for res_id in pending:
			parts.append("%s: %.0f" % [_short_name(res_id), pending[res_id]])
		_pending_label.text = "Pending: " + ", ".join(parts)
		_claim_button.disabled = false

func _get_total_pending() -> Dictionary:
	var total = {}
	if not territory_manager:
		return total

	for node in territory_manager.get_controlled_nodes():
		if not node or not node.accumulated_resources:
			continue
		for res_id in node.accumulated_resources:
			var amt = node.accumulated_resources[res_id]
			if amt > 0.1:
				total[res_id] = total.get(res_id, 0.0) + amt
	return total

func _short_name(res_id: String) -> String:
	match res_id:
		# Currencies
		"gold": return "Gold"
		"mana": return "Mana"
		"divine_crystals": return "Crystals"
		# T1 Crafting
		"ore": return "Ore"
		"wood": return "Wood"
		"herbs": return "Herbs"
		"monster_parts": return "Parts"
		# T2 Crafting
		"refined_metal": return "Metal"
		"quality_timber": return "Timber"
		"rare_herbs": return "R.Herbs"
		"beast_scales": return "Scales"
		# T3 Crafting
		"magic_crystals": return "M.Crystals"
		"forging_flame": return "Flame"
		# T4 PvP
		"celestial_ore": return "C.Ore"
		"dragon_parts": return "D.Parts"
		# Enhancement
		"enhancement_powder": return "Enh. Powder"
		"socket_crystal": return "Socket"
		"blessed_oil": return "B.Oil"
		# Divine
		"divine_essence": return "Essence"
		"mana_crystals": return "M.Crystals"
		# Souls
		"common_soul": return "C.Soul"
		"rare_soul": return "R.Soul"
		"epic_soul": return "E.Soul"
		"legendary_soul": return "L.Soul"
		# Legacy support
		"copper_ore", "iron_ore": return "Ore"
		"stone", "fiber": return res_id.capitalize()
		_: return res_id.replace("_", " ").capitalize()

func _format_power(power: int) -> String:
	if power >= 1000000:
		return "%.1fM" % (power / 1000000.0)
	elif power >= 1000:
		return "%.1fK" % (power / 1000.0)
	return str(power)

func _populate_nodes():
	for child in _node_list.get_children():
		child.queue_free()

	if not territory_manager:
		return

	var nodes = territory_manager.get_controlled_nodes()

	# Filter
	var filtered = []
	for node in nodes:
		if _filter_type == "" or _matches_filter(node):
			filtered.append(node)

	# Sort by tier desc, then name
	filtered.sort_custom(func(a, b):
		if a.tier != b.tier:
			return a.tier > b.tier
		return a.name < b.name
	)

	for node in filtered:
		_node_list.add_child(_create_node_card(node))

	if filtered.is_empty():
		var empty = Label.new()
		empty.text = "No nodes match filter"
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_node_list.add_child(empty)

func _matches_filter(node: HexNode) -> bool:
	match _filter_type:
		"mine": return node.node_type == "mine"
		"forest": return node.node_type == "forest"
		"coast": return node.node_type == "coast"
		"other": return node.node_type not in ["mine", "forest", "coast"]
		_: return true

# ==============================================================================
# NODE CARD
# ==============================================================================
func _create_node_card(node: HexNode) -> Panel:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(0, CARD_HEIGHT)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	style.border_color = Color(0.3, 0.35, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_right = -10
	vbox.offset_top = 8
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	# Header: Name + Type + Tier + Power
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	var name_label = Label.new()
	name_label.text = node.name
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1))
	header.add_child(name_label)

	header.add_child(_create_type_badge(node.node_type))

	var stars = Label.new()
	stars.text = "★".repeat(node.tier) if node.tier > 0 else "-"
	stars.add_theme_font_size_override("font_size", 10)
	stars.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	header.add_child(stars)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	# Total garrison combat power badge
	var total_power = _calculate_garrison_power(node)
	header.add_child(_create_power_badge(total_power))

	# Main content row: Garrison | Workers | Production (all horizontal)
	var content = HBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)

	# Garrison column (compact)
	content.add_child(_create_compact_slot_column(node, "garrison", MAX_GARRISON_SLOTS, node.garrison))

	# Workers column (compact)
	var max_workers = mini(node.tier, 5)
	if max_workers > 0:
		content.add_child(_create_compact_slot_column(node, "worker", max_workers, node.assigned_workers))

	# Production section fills remaining space
	content.add_child(_create_production_section(node))

	# Crafting section for forge nodes with workers (inline at end of content row)
	if node.node_type == "forge" and node.assigned_workers.size() > 0 and node.is_controlled_by_player():
		content.add_child(_create_crafting_section(node))

	return card

func _calculate_garrison_power(node: HexNode) -> int:
	var total = 0
	for god_id in node.garrison:
		var god = _get_god(god_id)
		if god:
			total += GodCalculator.get_power_rating(god)
	return total

func _create_power_badge(power: int) -> Panel:
	var badge = Panel.new()
	badge.custom_minimum_size = Vector2(70, 20)

	# Color based on power level
	var bg_color: Color
	if power == 0:
		bg_color = Color(0.25, 0.2, 0.2)  # Dark red - undefended
	elif power < 500:
		bg_color = Color(0.4, 0.3, 0.2)  # Orange - weak
	elif power < 1500:
		bg_color = Color(0.3, 0.4, 0.2)  # Yellow-green - moderate
	elif power < 3000:
		bg_color = Color(0.2, 0.45, 0.3)  # Green - strong
	else:
		bg_color = Color(0.25, 0.35, 0.5)  # Blue - very strong

	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(3)
	badge.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	if power == 0:
		label.text = "⚔ ---"
	else:
		label.text = "⚔ %s" % _format_power(power)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge.add_child(label)

	return badge

func _create_compact_slot_column(node: HexNode, slot_type: String, count: int, assigned: Array) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	# Check if workers can be assigned (garrison power requirement)
	var can_assign_workers = true
	if slot_type == "worker" and territory_manager:
		can_assign_workers = territory_manager.can_assign_workers(node)

	for i in count:
		var slot: Control
		if i < assigned.size():
			var god = _get_god(assigned[i])
			# Workers are inactive (grayed out) if garrison power is too low
			var inactive = (slot_type == "worker" and not can_assign_workers)
			slot = _create_mini_slot(node, slot_type, i, god, inactive)
		else:
			# Disable empty worker slots if garrison power is too low
			var disabled = (slot_type == "worker" and not can_assign_workers)
			slot = _create_mini_empty_slot(node, slot_type, i, disabled)
		row.add_child(slot)

	return row

func _create_mini_slot(node: HexNode, slot_type: String, idx: int, god: God, inactive: bool = false) -> Panel:
	var slot = Panel.new()
	slot.custom_minimum_size = Vector2(44, 52)

	var border_color = ELEMENT_COLORS.get(god.element, Color.GRAY) if god else Color(0.4, 0.4, 0.4)
	if inactive:
		border_color = border_color * 0.5  # Dim the border

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.17) if inactive else Color(0.18, 0.18, 0.2)
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	slot.add_theme_stylebox_override("panel", style)

	if god:
		var portrait = _create_portrait(god)
		portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		portrait.offset_left = 2
		portrait.offset_right = -2
		portrait.offset_top = 2
		portrait.offset_bottom = -16
		if inactive:
			portrait.modulate = Color(0.5, 0.5, 0.5, 0.7)  # Gray out inactive workers
		slot.add_child(portrait)

		# Combined Lv + Power label
		var info = Label.new()
		var power = GodCalculator.get_power_rating(god)
		info.text = "L%d %s" % [god.level, _format_power(power)]
		info.add_theme_font_size_override("font_size", 7)
		info.add_theme_color_override("font_color", Color(0.6, 0.5, 0.3) if inactive else Color(1.0, 0.85, 0.3))
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.anchor_left = 0
		info.anchor_right = 1
		info.anchor_top = 1
		info.anchor_bottom = 1
		info.offset_top = -14
		info.offset_bottom = -1
		slot.add_child(info)

		# Add warning indicator for inactive workers
		if inactive:
			var warn = Label.new()
			warn.text = "⚠️"
			warn.add_theme_font_size_override("font_size", 12)
			warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			warn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			warn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			slot.add_child(warn)

	var btn = Button.new()
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.pressed.connect(func(): filled_slot_tapped.emit(node, slot_type, idx, god))
	slot.add_child(btn)

	return slot

func _create_mini_empty_slot(node: HexNode, slot_type: String, idx: int, disabled: bool = false) -> Panel:
	var slot = Panel.new()
	slot.custom_minimum_size = Vector2(44, 52)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12) if disabled else Color(0.12, 0.12, 0.14)
	style.border_color = Color(0.2, 0.2, 0.25) if disabled else Color(0.25, 0.25, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	slot.add_theme_stylebox_override("panel", style)

	var plus = Label.new()
	plus.text = "🔒" if disabled else "+"
	plus.add_theme_font_size_override("font_size", 14 if disabled else 16)
	plus.add_theme_color_override("font_color", Color(0.3, 0.25, 0.25) if disabled else Color(0.35, 0.35, 0.4))
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(plus)

	# Only add clickable button if not disabled
	if not disabled:
		var btn = Button.new()
		btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn.flat = true
		btn.pressed.connect(func(): slot_tapped.emit(node, slot_type, idx))
		slot.add_child(btn)

	return slot

func _create_production_section(node: HexNode) -> VBoxContainer:
	var section = VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_stretch_ratio = 0.5  # Share space with crafting section
	section.add_theme_constant_override("separation", 4)

	# Get hourly production for this node
	var hourly = {}
	if production_manager:
		hourly = production_manager.get_node_hourly_production(node)

	var accumulated = node.accumulated_resources if node.accumulated_resources else {}

	if hourly.is_empty():
		var no_prod = Label.new()
		no_prod.text = "No production"
		no_prod.add_theme_font_size_override("font_size", 10)
		no_prod.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		section.add_child(no_prod)
	else:
		# Show each resource as a horizontal bar
		for res_id in hourly:
			var rate = hourly[res_id]
			var acc = accumulated.get(res_id, 0.0)
			section.add_child(_create_resource_bar(res_id, rate, acc))

	return section

func _create_resource_bar(res_id: String, hourly_rate: float, accumulated: float) -> Panel:
	var bar = Panel.new()
	bar.custom_minimum_size = Vector2(0, 18)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12)
	style.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("panel", style)

	# Fill based on accumulated (cap visual at 50 units for faster feedback)
	var fill_pct = clampf(accumulated / 50.0, 0.0, 1.0)
	var fill = ColorRect.new()
	fill.color = _get_resource_color(res_id).darkened(0.4)
	fill.anchor_right = fill_pct
	fill.anchor_bottom = 1.0
	fill.offset_left = 1
	fill.offset_top = 1
	fill.offset_right = 0
	fill.offset_bottom = -1
	bar.add_child(fill)

	# Label overlay
	var label_container = HBoxContainer.new()
	label_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label_container.offset_left = 6
	label_container.offset_right = -6
	label_container.add_theme_constant_override("separation", 4)
	bar.add_child(label_container)

	var name_lbl = Label.new()
	name_lbl.text = _short_name(res_id)
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", _get_resource_color(res_id))
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_container.add_child(name_lbl)

	var rate_lbl = Label.new()
	rate_lbl.text = "+%.0f/h" % hourly_rate
	rate_lbl.add_theme_font_size_override("font_size", 9)
	rate_lbl.add_theme_color_override("font_color", Color(0.5, 0.65, 0.5))
	rate_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_container.add_child(rate_lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_container.add_child(spacer)

	if accumulated > 0.1:
		var acc_lbl = Label.new()
		acc_lbl.text = "%.0f" % accumulated
		acc_lbl.add_theme_font_size_override("font_size", 10)
		acc_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
		acc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label_container.add_child(acc_lbl)

	return bar

func _create_resource_chip(res_id: String, hourly_rate: float, accumulated: float) -> Panel:
	var chip = Panel.new()
	chip.custom_minimum_size = Vector2(90, 24)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.18, 0.2)
	style.set_corner_radius_all(3)
	chip.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 4
	vbox.offset_right = -4
	vbox.offset_top = 2
	vbox.offset_bottom = -2
	vbox.add_theme_constant_override("separation", 1)
	chip.add_child(vbox)

	# Resource name + rate
	var top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 4)
	vbox.add_child(top_row)

	var name_lbl = Label.new()
	name_lbl.text = _short_name(res_id)
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.add_theme_color_override("font_color", _get_resource_color(res_id))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(name_lbl)

	var rate_lbl = Label.new()
	rate_lbl.text = "+%.0f/h" % hourly_rate
	rate_lbl.add_theme_font_size_override("font_size", 8)
	rate_lbl.add_theme_color_override("font_color", Color(0.6, 0.75, 0.6))
	top_row.add_child(rate_lbl)

	# Mini progress bar showing accumulated
	var progress_container = Panel.new()
	progress_container.custom_minimum_size = Vector2(0, 6)

	var prog_style = StyleBoxFlat.new()
	prog_style.bg_color = Color(0.1, 0.1, 0.12)
	prog_style.set_corner_radius_all(2)
	progress_container.add_theme_stylebox_override("panel", prog_style)
	vbox.add_child(progress_container)

	# Fill based on accumulated (cap visual at 100 units for progress)
	var fill_pct = clampf(accumulated / 100.0, 0.0, 1.0)
	if accumulated > 0:
		var fill = ColorRect.new()
		fill.color = _get_resource_color(res_id).darkened(0.3)
		fill.anchor_right = fill_pct
		fill.anchor_bottom = 1.0
		fill.offset_left = 1
		fill.offset_top = 1
		fill.offset_right = -1
		fill.offset_bottom = -1
		progress_container.add_child(fill)

		# Accumulated amount label
		var acc_lbl = Label.new()
		acc_lbl.text = "%.0f" % accumulated
		acc_lbl.add_theme_font_size_override("font_size", 7)
		acc_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
		acc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		acc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		acc_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		progress_container.add_child(acc_lbl)

	return chip

func _get_resource_color(res_id: String) -> Color:
	match res_id:
		# Currencies
		"gold": return Color(1.0, 0.85, 0.3)
		"mana": return Color(0.5, 0.7, 1.0)
		"divine_crystals": return Color(0.8, 0.5, 1.0)
		# T1 Crafting
		"ore": return Color(0.6, 0.6, 0.7)
		"wood": return Color(0.6, 0.45, 0.3)
		"herbs": return Color(0.4, 0.7, 0.4)
		"monster_parts": return Color(0.7, 0.4, 0.4)
		# T2 Crafting
		"refined_metal": return Color(0.7, 0.75, 0.8)
		"quality_timber": return Color(0.5, 0.35, 0.25)
		"rare_herbs": return Color(0.3, 0.8, 0.5)
		"beast_scales": return Color(0.6, 0.5, 0.7)
		# T3 Crafting
		"magic_crystals": return Color(0.6, 0.4, 0.9)
		"forging_flame": return Color(1.0, 0.5, 0.2)
		# T4 PvP
		"celestial_ore": return Color(0.9, 0.9, 1.0)
		"dragon_parts": return Color(0.8, 0.3, 0.3)
		# Enhancement
		"enhancement_powder": return Color(0.5, 0.8, 0.7)
		"socket_crystal": return Color(0.7, 0.7, 0.9)
		"blessed_oil": return Color(1.0, 0.95, 0.6)
		# Divine
		"divine_essence": return Color(1.0, 0.85, 0.5)
		"mana_crystals": return Color(0.6, 0.7, 1.0)
		# Souls
		"common_soul": return Color(0.6, 0.6, 0.6)
		"rare_soul": return Color(0.4, 0.6, 0.9)
		"epic_soul": return Color(0.7, 0.4, 0.9)
		"legendary_soul": return Color(1.0, 0.7, 0.3)
		# Legacy support
		"copper_ore", "iron_ore": return Color(0.6, 0.6, 0.7)
		"stone": return Color(0.5, 0.5, 0.55)
		"fiber": return Color(0.7, 0.75, 0.5)
		_: return Color(0.7, 0.7, 0.7)

func _create_type_badge(node_type: String) -> Panel:
	var badge = Panel.new()
	badge.custom_minimum_size = Vector2(60, 18)

	var style = StyleBoxFlat.new()
	style.bg_color = NODE_TYPE_COLORS.get(node_type, Color(0.3, 0.3, 0.35))
	style.set_corner_radius_all(3)
	badge.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.text = node_type.capitalize()
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge.add_child(label)

	return badge

func _create_slot_column(node: HexNode, title: String, slot_type: String, count: int, assigned: Array) -> VBoxContainer:
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)

	var label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	col.add_child(label)

	var slots = HBoxContainer.new()
	slots.add_theme_constant_override("separation", SLOT_SPACING)
	col.add_child(slots)

	for i in count:
		var slot: Control
		if i < assigned.size():
			var god = _get_god(assigned[i])
			slot = _create_filled_slot(node, slot_type, i, god)
		else:
			slot = _create_empty_slot(node, slot_type, i)
		slots.add_child(slot)

	return col

func _create_empty_slot(node: HexNode, slot_type: String, idx: int) -> Panel:
	var slot = Panel.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18)
	style.border_color = Color(0.35, 0.35, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel", style)

	var plus = Label.new()
	plus.text = "+"
	plus.add_theme_font_size_override("font_size", 20)
	plus.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(plus)

	var btn = Button.new()
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.pressed.connect(func(): slot_tapped.emit(node, slot_type, idx))
	slot.add_child(btn)

	return slot

func _create_filled_slot(node: HexNode, slot_type: String, idx: int, god: God) -> Panel:
	var slot = Panel.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

	var border_color = ELEMENT_COLORS.get(god.element, Color.GRAY) if god else Color(0.4, 0.4, 0.4)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.18, 0.2)
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel", style)

	if god:
		var portrait = _create_portrait(god)
		portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		portrait.offset_left = 3
		portrait.offset_right = -3
		portrait.offset_top = 3
		portrait.offset_bottom = -20
		slot.add_child(portrait)

		# Level label
		var lv = Label.new()
		lv.text = "Lv%d" % god.level
		lv.add_theme_font_size_override("font_size", 8)
		lv.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lv.anchor_left = 0
		lv.anchor_right = 1
		lv.anchor_top = 1
		lv.anchor_bottom = 1
		lv.offset_top = -20
		lv.offset_bottom = -10
		slot.add_child(lv)

		# Combat power label
		var cp = Label.new()
		var power = GodCalculator.get_power_rating(god)
		cp.text = _format_power(power)
		cp.add_theme_font_size_override("font_size", 7)
		cp.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		cp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cp.anchor_left = 0
		cp.anchor_right = 1
		cp.anchor_top = 1
		cp.anchor_bottom = 1
		cp.offset_top = -10
		cp.offset_bottom = 0
		slot.add_child(cp)
	else:
		var q = Label.new()
		q.text = "?"
		q.add_theme_font_size_override("font_size", 18)
		q.add_theme_color_override("font_color", Color(0.5, 0.4, 0.4))
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(q)

	var btn = Button.new()
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.pressed.connect(func(): filled_slot_tapped.emit(node, slot_type, idx, god))
	slot.add_child(btn)

	return slot

func _create_portrait(god: God) -> TextureRect:
	var portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var god_template = god.template_id if god.template_id else god.id
	var path = "res://assets/gods/%s.png" % god_template
	if ResourceLoader.exists(path):
		portrait.texture = load(path)
	else:
		var img = Image.create(48, 48, false, Image.FORMAT_RGBA8)
		img.fill(ELEMENT_COLORS.get(god.element, Color.GRAY))
		portrait.texture = ImageTexture.create_from_image(img)

	return portrait

func _get_god(god_id: String) -> God:
	if not collection_manager or god_id.is_empty():
		return null
	return collection_manager.get_god_by_id(god_id)

# ==============================================================================
# CRAFTING SYSTEM
# ==============================================================================
func _create_crafting_section(node: HexNode) -> HBoxContainer:
	"""Create crafting section for forge nodes with workers - compact inline"""
	var section = HBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_stretch_ratio = 0.5  # Share space with production section
	section.add_theme_constant_override("separation", 8)

	# Show active crafts first (compact inline)
	var active_for_this_node = _get_active_crafts_for_node(node.id)
	if not active_for_this_node.is_empty():
		for craft_data in active_for_this_node:
			var progress_card = _create_craft_progress_card(craft_data)
			section.add_child(progress_card)

	# Get available recipes count
	var available_tasks = _get_available_tasks_for_forge(node.tier)

	# Open Crafting button - compact
	var craft_btn = Button.new()
	craft_btn.text = "⚒️ (%d)" % available_tasks.size()
	craft_btn.custom_minimum_size = Vector2(60, 24)
	craft_btn.pressed.connect(_on_open_crafting.bind(node))
	_style_button(craft_btn, Color(0.55, 0.35, 0.2))
	section.add_child(craft_btn)

	return section

func _get_active_crafts_for_node(node_id: String) -> Array:
	"""Get active crafts for a specific node from shared tracker"""
	if hex_grid_manager:
		return hex_grid_manager.get_active_crafts_for_node(node_id)
	return []

func _create_craft_progress_card(craft_data: Dictionary) -> PanelContainer:
	"""Create a compact inline progress card for an active craft"""
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(100, 24)  # Compact inline size
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
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	card.add_theme_stylebox_override("panel", style)

	# Single line with progress bar background
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	card.add_child(hbox)

	# Task name (abbreviated)
	var task_data = craft_data.get("task_data", {})
	var task_name = task_data.get("name", "Crafting...")
	# Shorten long names
	if task_name.length() > 12:
		task_name = task_name.substr(0, 10) + ".."

	var name_label = Label.new()
	name_label.text = "⚒️" + task_name
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	hbox.add_child(name_label)

	# Time remaining (compact)
	var time_label = Label.new()
	if is_complete:
		time_label.text = "✓"
		time_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	else:
		time_label.text = CraftingUIUtils.format_duration(remaining)
		time_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	time_label.add_theme_font_size_override("font_size", 9)
	hbox.add_child(time_label)

	# Make clickable if complete
	if is_complete:
		var btn = Button.new()
		btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn.flat = true
		btn.pressed.connect(_on_craft_complete_clicked.bind(craft_data))
		card.add_child(btn)

	return card

func _get_available_tasks_for_forge(tier: int) -> Array:
	"""Get crafting recipes available for a forge at the given tier"""
	var available: Array = []

	for recipe_id in _tasks_data.keys():
		var recipe = _tasks_data[recipe_id]

		# Check if this recipe can be crafted at a forge
		var territory_type = recipe.get("territory_type_requirement", "")
		var territory_required = recipe.get("territory_required", false)

		# Skip recipes that specifically require shrine (not forge)
		if territory_type == "shrine":
			continue

		# Get tier requirement (default to 1 if not specified)
		var required_tier = recipe.get("territory_tier_requirement", 1)

		# If territory is not required, can craft at any forge (tier 1+)
		if not territory_required:
			required_tier = 1

		# Must meet tier requirement
		if tier < required_tier:
			continue

		# Add to available (include recipe_id in the data)
		var recipe_with_id = recipe.duplicate()
		recipe_with_id["id"] = recipe_id
		available.append(recipe_with_id)

	return available

func _on_open_crafting(node: HexNode) -> void:
	"""Handle opening the crafting popup for a node"""
	_current_craft_node = node
	_show_craft_popup(node)

func _show_craft_popup(node: HexNode) -> void:
	"""Show the crafting recipe popup"""
	# Remove existing popup
	if _craft_popup and is_instance_valid(_craft_popup):
		_craft_popup.queue_free()

	var viewport_size = get_viewport().get_visible_rect().size
	var available_tasks = _get_available_tasks_for_forge(node.tier)

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
	title.text = "⚒️ %s FORGE RECIPES" % node.name.to_upper()
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
	tier_label.text = "Tier %d Forge - %d recipes unlocked" % [node.tier, available_tasks.size()]
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

	# Add recipe cards using unified component
	for task in available_tasks:
		var costs = CraftingUIUtils.get_recipe_costs(task)
		var can_afford = _can_afford_craft(costs)
		var is_conversion = CraftingUIUtils.is_conversion_recipe(task)

		# Create callback that binds the node for this craft
		var craft_callback = func(t: Dictionary, auto_repeat): _on_start_craft(t, node)

		var card = CraftingUIUtils.create_recipe_card(
			task,
			can_afford,
			craft_callback,
			is_conversion,  # show auto-repeat for conversions
			resource_manager  # pass manager for detailed cost display
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
	_current_craft_node = null

func _on_start_craft(task: Dictionary, node: HexNode) -> void:
	"""Handle starting a craft task"""
	var task_id = task.get("id", "")
	if task_id.is_empty():
		return

	# Check and spend resources - use "materials" from crafting_recipes.json
	var costs = task.get("materials", task.get("resource_costs", {}))
	if not costs.is_empty():
		if not resource_manager:
			return
		if not resource_manager.can_afford(costs):
			return
		if not resource_manager.spend_resources(costs):
			return


	# Track the craft using shared tracker
	var craft_started = false
	if hex_grid_manager:
		craft_started = hex_grid_manager.start_craft(node.id, task_id, task)

	if not craft_started:
		# Refund the resources
		for resource_id in costs:
			resource_manager.add_resource(resource_id, costs[resource_id])
		_show_craft_error_feedback("Forge already busy or no worker assigned")
		return

	_close_craft_popup()
	_show_craft_started_feedback(task)
	_populate_nodes()

func _show_craft_error_feedback(message: String) -> void:
	"""Show error feedback when craft cannot start"""
	var feedback = PanelContainer.new()
	feedback.z_index = 150

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.15, 0.15, 0.95)
	style.border_color = Color(0.8, 0.3, 0.3, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	feedback.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.text = "❌ " + message
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.8))
	feedback.add_child(label)

	add_child(feedback)
	feedback.position = Vector2(size.x / 2 - 150, 100)

	# Fade out and remove
	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(feedback, "modulate:a", 0.0, 0.5)
	tween.tween_callback(feedback.queue_free)

func _on_craft_complete_clicked(craft_data: Dictionary) -> void:
	"""Handle clicking on a completed craft"""
	var task_data = craft_data.get("task_data", {})
	var task_id = craft_data.get("task_id", "")
	var node_id = craft_data.get("node_id", "")


	# Award rewards
	_award_craft_rewards(task_data)

	# Remove from active crafts using shared tracker
	if hex_grid_manager:
		hex_grid_manager.complete_craft(node_id, task_id)

	_populate_nodes()
	_show_craft_collected_feedback(task_data)

func _award_craft_rewards(task_data: Dictionary) -> void:
	"""Award the rewards from a completed craft"""
	if not resource_manager:
		push_error("TerritoryOverviewScreen: Cannot award craft rewards - no ResourceManager")
		return

	# Resource rewards - use "output" from crafting_recipes.json (fallback to "resource_rewards")
	var resources = task_data.get("output", task_data.get("resource_rewards", {}))
	if resources.is_empty():
		push_warning("TerritoryOverviewScreen: No output resources found in task_data: %s" % task_data.keys())
		return

	for resource_id in resources.keys():
		var amount = resources[resource_id]
		resource_manager.add_resource(resource_id, amount)

	var items = task_data.get("item_rewards", [])
	for item in items:
		if item is Dictionary:
			var chance = item.get("chance", 1.0)
			if randf() <= chance:
				var item_id = item.get("id", "")
				var item_rarity = item.get("rarity", "common")

func _show_craft_started_feedback(task: Dictionary) -> void:
	"""Show feedback when craft starts"""
	var task_name = task.get("name", "Recipe")
	var duration = task.get("base_duration_seconds", 0)
	var duration_text = CraftingUIUtils.format_duration(duration)

	var feedback = PanelContainer.new()
	feedback.z_index = 150

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.4, 0.3, 0.95)
	style.border_color = Color(0.4, 0.7, 0.5, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	feedback.add_theme_stylebox_override("panel", style)

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	feedback.add_child(content)

	var title_label = Label.new()
	title_label.text = "⚒️ Crafting Started!"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title_label)

	var task_label = Label.new()
	task_label.text = task_name
	task_label.add_theme_font_size_override("font_size", 14)
	task_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	task_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(task_label)

	var time_label = Label.new()
	time_label.text = "Completes in: %s" % duration_text
	time_label.add_theme_font_size_override("font_size", 12)
	time_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(time_label)

	# Add to main first, then position (anchors need parent)
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node:
		main_node.add_child(feedback)
	else:
		add_child(feedback)

	# Position at center of screen AFTER adding to tree
	feedback.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	feedback.custom_minimum_size = Vector2(300, 100)

	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(feedback, "modulate:a", 0.0, 0.5)
	tween.tween_callback(feedback.queue_free)

func _show_craft_collected_feedback(task_data: Dictionary) -> void:
	"""Show feedback when a craft is collected"""
	var task_name = task_data.get("name", "Item")

	var feedback = PanelContainer.new()
	feedback.z_index = 150

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.45, 0.3, 0.95)
	style.border_color = Color(0.4, 0.8, 0.5, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	feedback.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.text = "✓ Crafted: %s" % task_name
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
	feedback.add_child(label)

	feedback.anchor_left = 0.5
	feedback.anchor_right = 0.5
	feedback.anchor_top = 0.35
	feedback.anchor_bottom = 0.35
	feedback.offset_left = -120
	feedback.offset_right = 120

	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node:
		main_node.add_child(feedback)
	else:
		add_child(feedback)

	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(feedback, "modulate:a", 0.0, 0.5)
	tween.tween_callback(feedback.queue_free)

# ==============================================================================
# EVENT HANDLERS
# ==============================================================================
func _on_filter_changed(idx: int):
	match idx:
		0: _filter_type = ""
		1: _filter_type = "mine"
		2: _filter_type = "forest"
		3: _filter_type = "coast"
		4: _filter_type = "other"
	_populate_nodes()

func _on_claim_all():
	if not production_manager or not territory_manager:
		return

	var total = {}
	for node in territory_manager.get_controlled_nodes():
		if not node:
			continue
		var collected = production_manager.collect_node_resources(node.id)
		for res_id in collected:
			total[res_id] = total.get(res_id, 0.0) + collected[res_id]

	_update_production()

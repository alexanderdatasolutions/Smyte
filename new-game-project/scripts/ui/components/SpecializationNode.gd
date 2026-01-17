# scripts/ui/components/SpecializationNode.gd
# Reusable UI component for displaying a single specialization tree node
# Shows name, icon, locked/unlocked state, requirements, and allows interaction
class_name SpecializationNode extends Panel

# ==============================================================================
# SIGNALS
# ==============================================================================
signal node_selected(spec_id: String)
signal node_hovered(spec_id: String)
signal node_unhovered()

# ==============================================================================
# NODE STATE
# ==============================================================================
enum NodeState {
	LOCKED,        # Cannot be unlocked yet (requirements not met)
	AVAILABLE,     # Can be unlocked (requirements met, not purchased)
	UNLOCKED       # Already unlocked
}

# ==============================================================================
# PROPERTIES
# ==============================================================================
var specialization: GodSpecialization = null
var current_state: NodeState = NodeState.LOCKED
var god_data: God = null  # God this node is for (used to check requirements)
var is_hovered: bool = false
var is_selected: bool = false

# ==============================================================================
# UI ELEMENTS (dynamically created)
# ==============================================================================
var icon_rect: TextureRect
var name_label: Label
var tier_label: Label
var lock_indicator: Label
var cost_label: Label
var state_overlay: Panel

# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _ready():
	if not icon_rect:
		_setup_node_structure()

# ==============================================================================
# PUBLIC API
# ==============================================================================

func setup(spec: GodSpecialization, god: God, state: NodeState):
	"""Setup the node with specialization data and state"""
	specialization = spec
	god_data = god
	current_state = state

	if not icon_rect:
		_setup_node_structure()

	_populate_data()
	_apply_state_style()

func set_state(new_state: NodeState):
	"""Update the node state and refresh styling"""
	if current_state != new_state:
		current_state = new_state
		_apply_state_style()

func set_selected(selected: bool):
	"""Set the selection state"""
	if is_selected != selected:
		is_selected = selected
		_apply_state_style()

func get_specialization_id() -> String:
	"""Get the specialization ID"""
	return specialization.id if specialization else ""

# ==============================================================================
# STRUCTURE SETUP
# ==============================================================================

func _setup_node_structure():
	"""Create the node UI structure"""
	# Clear existing children
	for child in get_children():
		child.queue_free()

	# Set size and style
	custom_minimum_size = Vector2(140, 160)

	# Main container with margins
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# Tier label (top)
	tier_label = Label.new()
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_label.add_theme_font_size_override("font_size", 10)
	tier_label.modulate = Color(0.7, 0.7, 0.7, 1.0)
	vbox.add_child(tier_label)

	# Icon container
	var icon_container = CenterContainer.new()
	icon_container.custom_minimum_size = Vector2(0, 70)
	vbox.add_child(icon_container)

	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(60, 60)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_container.add_child(icon_rect)

	# Lock indicator (overlays icon when locked)
	lock_indicator = Label.new()
	lock_indicator.text = "🔒"
	lock_indicator.add_theme_font_size_override("font_size", 24)
	lock_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock_indicator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lock_indicator.modulate = Color(1.0, 1.0, 1.0, 0.9)
	icon_container.add_child(lock_indicator)

	# Name label
	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_constant_override("outline_size", 1)
	vbox.add_child(name_label)

	# Cost label (bottom)
	cost_label = Label.new()
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 9)
	cost_label.modulate = Color(1.0, 0.9, 0.5, 1.0)
	vbox.add_child(cost_label)

	# State overlay (for dimming locked nodes)
	state_overlay = Panel.new()
	state_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	state_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var overlay_style = StyleBoxFlat.new()
	overlay_style.bg_color = Color(0, 0, 0, 0.6)
	state_overlay.add_theme_stylebox_override("panel", overlay_style)
	add_child(state_overlay)

	# Clickable button overlay
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_node_clicked)
	button.mouse_entered.connect(_on_node_mouse_entered)
	button.mouse_exited.connect(_on_node_mouse_exited)
	margin.add_child(button)

# ==============================================================================
# DATA POPULATION
# ==============================================================================

func _populate_data():
	"""Fill node with specialization data"""
	if not specialization:
		return

	# Set tier label
	if tier_label:
		var tier_names = ["", "Tier I", "Tier II", "Tier III"]
		var tier_idx = clampi(specialization.tier, 1, 3)
		tier_label.text = tier_names[tier_idx]

	# Set icon
	if icon_rect:
		if specialization.icon_path != "" and ResourceLoader.exists(specialization.icon_path):
			icon_rect.texture = load(specialization.icon_path)
		else:
			# Create placeholder based on tier
			var placeholder = _create_placeholder_icon(specialization.tier)
			icon_rect.texture = placeholder

	# Set name
	if name_label:
		name_label.text = specialization.name

	# Set cost label
	if cost_label:
		var cost_text = _format_costs(specialization.costs)
		cost_label.text = cost_text
		cost_label.visible = (current_state == NodeState.AVAILABLE)

	# Set lock indicator visibility
	if lock_indicator:
		lock_indicator.visible = (current_state == NodeState.LOCKED)

# ==============================================================================
# STYLING
# ==============================================================================

func _apply_state_style():
	"""Apply visual style based on current state"""
	var style = StyleBoxFlat.new()

	# Set background color based on state
	match current_state:
		NodeState.LOCKED:
			style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
			style.border_color = Color(0.3, 0.3, 0.3, 1.0)
			if state_overlay:
				state_overlay.visible = true

		NodeState.AVAILABLE:
			style.bg_color = Color(0.2, 0.3, 0.2, 0.9)
			style.border_color = Color(0.4, 0.8, 0.4, 1.0)
			if state_overlay:
				state_overlay.visible = false

		NodeState.UNLOCKED:
			style.bg_color = Color(0.15, 0.25, 0.35, 0.9)
			style.border_color = Color(0.3, 0.6, 1.0, 1.0)
			if state_overlay:
				state_overlay.visible = false

	# Selection border (thicker, gold)
	if is_selected:
		style.border_color = Color(1.0, 0.8, 0.0, 1.0)
		style.border_width_left = 4
		style.border_width_right = 4
		style.border_width_top = 4
		style.border_width_bottom = 4
	else:
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2

	# Hover effect (slight glow)
	if is_hovered and current_state != NodeState.LOCKED:
		style.shadow_color = Color(0.8, 0.8, 0.2, 0.5)
		style.shadow_size = 4

	# Corner radius
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8

	add_theme_stylebox_override("panel", style)

	# Update cost label visibility
	if cost_label:
		cost_label.visible = (current_state == NodeState.AVAILABLE)

	# Update lock indicator visibility
	if lock_indicator:
		lock_indicator.visible = (current_state == NodeState.LOCKED)

	# Update icon opacity
	if icon_rect:
		match current_state:
			NodeState.LOCKED:
				icon_rect.modulate = Color(0.5, 0.5, 0.5, 0.7)
			NodeState.AVAILABLE:
				icon_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
			NodeState.UNLOCKED:
				icon_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)

# ==============================================================================
# HELPERS
# ==============================================================================

func _create_placeholder_icon(tier: int) -> ImageTexture:
	"""Create a placeholder icon based on tier"""
	var placeholder = ImageTexture.new()
	var image = Image.create(100, 100, false, Image.FORMAT_RGB8)

	# Color based on tier
	var color: Color
	match tier:
		1: color = Color(0.4, 0.6, 0.4, 1.0)  # Green for tier 1
		2: color = Color(0.4, 0.4, 0.8, 1.0)  # Blue for tier 2
		3: color = Color(0.8, 0.4, 0.8, 1.0)  # Purple for tier 3
		_: color = Color(0.5, 0.5, 0.5, 1.0)

	image.fill(color)
	placeholder.set_image(image)
	return placeholder

func _format_costs(costs_dict: Dictionary) -> String:
	"""Format costs dictionary into display string"""
	if costs_dict.is_empty():
		return "Free"

	var parts: Array[String] = []

	if costs_dict.has("gold"):
		parts.append(str(costs_dict["gold"]) + " Gold")

	if costs_dict.has("divine_essence"):
		parts.append(str(costs_dict["divine_essence"]) + " Essence")

	if costs_dict.has("specialization_tomes"):
		parts.append(str(costs_dict["specialization_tomes"]) + " Tomes")

	if costs_dict.has("legendary_scroll"):
		parts.append(str(costs_dict["legendary_scroll"]) + " Scrolls")

	# Join with line breaks if multiple costs
	if parts.size() > 1:
		return "\n".join(parts)
	elif parts.size() == 1:
		return parts[0]
	else:
		return "Free"

func get_spec_tooltip_text() -> String:
	"""Generate tooltip text for this node"""
	if not specialization:
		return ""

	var lines: Array[String] = []

	# Header
	lines.append("[b]" + specialization.name + "[/b]")
	lines.append("")

	# Description
	if specialization.description != "":
		lines.append(specialization.description)
		lines.append("")

	# Requirements
	if current_state == NodeState.LOCKED:
		lines.append("[color=#ff8888]Requirements:[/color]")

		if specialization.level_required > 0:
			var god_level = god_data.level if god_data else 0
			var level_met = god_level >= specialization.level_required
			var level_color = "#88ff88" if level_met else "#ff8888"
			lines.append("  Level " + str(specialization.level_required) + " [color=" + level_color + "](" + str(god_level) + ")[/color]")

		if specialization.role_required != "":
			var role_met = false
			if god_data and god_data.primary_role == specialization.role_required:
				role_met = true
			var role_color = "#88ff88" if role_met else "#ff8888"
			lines.append("  [color=" + role_color + "]" + specialization.role_required.capitalize() + " Role[/color]")

		if not specialization.required_traits.is_empty():
			lines.append("  Requires trait: " + ", ".join(specialization.required_traits))

		lines.append("")

	# Costs
	if current_state == NodeState.AVAILABLE and not specialization.costs.is_empty():
		lines.append("[color=#ffff88]Cost:[/color]")
		lines.append("  " + _format_costs(specialization.costs).replace("\n", "\n  "))
		lines.append("")

	# Bonuses (abbreviated)
	var has_bonuses = false

	if not specialization.stat_bonuses.is_empty():
		lines.append("[color=#88ff88]Stat Bonuses:[/color]")
		for bonus_key in specialization.stat_bonuses:
			var value = specialization.stat_bonuses[bonus_key]
			var formatted = _format_bonus_value(value)
			lines.append("  +" + formatted + " " + bonus_key.replace("_", " ").capitalize())
		has_bonuses = true

	if not specialization.task_bonuses.is_empty():
		lines.append("[color=#88ff88]Task Bonuses:[/color]")
		for task_key in specialization.task_bonuses:
			var value = specialization.task_bonuses[task_key]
			var formatted = _format_bonus_value(value)
			lines.append("  +" + formatted + " " + task_key.capitalize())
		has_bonuses = true

	if not has_bonuses:
		lines.append("[color=#888888]No bonuses[/color]")

	return "\n".join(lines)

func _format_bonus_value(value) -> String:
	"""Format a bonus value for display"""
	if typeof(value) == TYPE_BOOL:
		return "True" if value else "False"
	elif typeof(value) == TYPE_FLOAT:
		return str(int(value * 100)) + "%"
	elif typeof(value) == TYPE_INT:
		return str(value)
	else:
		return str(value)

# ==============================================================================
# EVENT HANDLERS
# ==============================================================================

func _on_node_clicked():
	"""Handle node click"""
	if specialization:
		node_selected.emit(specialization.id)

func _on_node_mouse_entered():
	"""Handle mouse enter"""
	is_hovered = true
	_apply_state_style()
	if specialization:
		node_hovered.emit(specialization.id)

func _on_node_mouse_exited():
	"""Handle mouse exit"""
	is_hovered = false
	_apply_state_style()
	node_unhovered.emit()

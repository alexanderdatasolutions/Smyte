# scripts/ui/territory/HexTile.gd
# Visual component for a single hexagonal territory node
extends Control
class_name HexTile

"""
HexTile.gd - Visual representation of a single hex node
RULE 2: Single responsibility - ONLY handles hex tile display and input
RULE 1: Under 500 lines

Displays:
- Hex shape with state-based colors
- Node type icon
- Tier stars
- Garrison indicator
- Visual states: neutral, controlled, enemy, contested, locked
"""

# ==============================================================================
# SIGNALS
# ==============================================================================
signal hex_clicked(tile: HexTile)
signal hex_hovered(tile: HexTile)
signal hex_unhovered(tile: HexTile)

# ==============================================================================
# PROPERTIES
# ==============================================================================
var node_data: HexNode = null  # The hex node this tile represents
var is_locked: bool = false  # Can't be captured yet
var is_hovered: bool = false  # Mouse is over this tile

# Visual components
var _background_panel: Panel = null
var _icon_texture: TextureRect = null
var _tier_label: Label = null
var _garrison_indicator: Panel = null
var _state_overlay: Panel = null

# ==============================================================================
# CONSTANTS
# ==============================================================================
const HEX_SIZE = Vector2(80, 92)  # Width x Height for hex tile
const ICON_SIZE = Vector2(40, 40)

# State colors
const COLOR_NEUTRAL = Color(0.3, 0.3, 0.35, 0.9)  # Gray
const COLOR_CONTROLLED = Color(0.2, 0.5, 0.3, 0.9)  # Green
const COLOR_ENEMY = Color(0.5, 0.2, 0.2, 0.9)  # Red
const COLOR_CONTESTED = Color(0.6, 0.5, 0.2, 0.9)  # Yellow
const COLOR_LOCKED = Color(0.15, 0.15, 0.15, 0.7)  # Dark gray

# Tier colors (for borders and stars)
const TIER_COLORS = {
	1: Color(0.6, 0.6, 0.6, 1),  # Common gray
	2: Color(0.3, 0.8, 0.3, 1),  # Uncommon green
	3: Color(0.3, 0.5, 1.0, 1),  # Rare blue
	4: Color(0.8, 0.3, 1.0, 1),  # Epic purple
	5: Color(1.0, 0.6, 0.0, 1)   # Legendary orange
}

# Node type icons (emoji for MVP, can replace with assets later)
const NODE_TYPE_ICONS = {
	"mine": "⛏️",
	"forest": "🌲",
	"coast": "🌊",
	"hunting_ground": "🦌",
	"forge": "🔨",
	"library": "📚",
	"temple": "🏛️",
	"fortress": "🏰"
}

# ==============================================================================
# INITIALIZATION
# ==============================================================================
func _ready() -> void:
	custom_minimum_size = HEX_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_visual_components()

	# Connect mouse signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

func _build_visual_components() -> void:
	"""Build all visual components of the hex tile"""

	# Background panel (hex shape approximated with rounded rect)
	_background_panel = Panel.new()
	_background_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_background_panel)

	# Center container for icon and info
	var center_container = VBoxContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center_container.custom_minimum_size = ICON_SIZE
	center_container.add_theme_constant_override("separation", 2)
	add_child(center_container)

	# Icon
	_icon_texture = TextureRect.new()
	_icon_texture.custom_minimum_size = ICON_SIZE
	_icon_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	center_container.add_child(_icon_texture)

	# Tier stars label
	_tier_label = Label.new()
	_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tier_label.add_theme_font_size_override("font_size", 10)
	center_container.add_child(_tier_label)

	# Garrison indicator (bottom right corner)
	_garrison_indicator = Panel.new()
	_garrison_indicator.custom_minimum_size = Vector2(16, 16)
	_garrison_indicator.position = Vector2(HEX_SIZE.x - 20, HEX_SIZE.y - 20)
	_garrison_indicator.visible = false
	add_child(_garrison_indicator)

	# State overlay (for hover/selection effects)
	_state_overlay = Panel.new()
	_state_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_state_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_state_overlay.visible = false
	add_child(_state_overlay)

# ==============================================================================
# PUBLIC METHODS
# ==============================================================================
func set_node(hex_node: HexNode, locked: bool = false) -> void:
	"""Set the node data and update visuals"""
	node_data = hex_node
	is_locked = locked
	_update_visuals()

func update_state(locked: bool = false) -> void:
	"""Update visual state (call when node state changes)"""
	is_locked = locked
	_update_visuals()

func highlight(enabled: bool) -> void:
	"""Show/hide highlight overlay"""
	if _state_overlay:
		_state_overlay.visible = enabled

# ==============================================================================
# PRIVATE METHODS - Visual Updates
# ==============================================================================
func _update_visuals() -> void:
	"""Update all visual components based on node data"""
	if not node_data:
		return

	_update_background()
	_update_icon()
	_update_tier_stars()
	_update_garrison_indicator()

func _update_background() -> void:
	"""Update background color based on node state"""
	var style = StyleBoxFlat.new()

	# Determine background color
	var bg_color: Color
	if is_locked:
		bg_color = COLOR_LOCKED
	elif node_data.is_contested:
		bg_color = COLOR_CONTESTED
	elif node_data.is_controlled_by_player():
		bg_color = COLOR_CONTROLLED
	elif node_data.is_enemy_controlled():
		bg_color = COLOR_ENEMY
	else:  # neutral
		bg_color = COLOR_NEUTRAL

	style.bg_color = bg_color

	# Hex-like rounded corners
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8

	# Border color based on tier
	var tier_color = TIER_COLORS.get(node_data.tier, Color.WHITE)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = tier_color

	# Apply style
	if _background_panel:
		_background_panel.add_theme_stylebox_override("panel", style)

func _update_icon() -> void:
	"""Update node type icon"""
	if not _icon_texture:
		return

	# For MVP, use emoji as text (can replace with actual icons later)
	var icon_text = NODE_TYPE_ICONS.get(node_data.node_type, "❓")

	# Create a label with emoji since we don't have texture assets yet
	# Clear existing children
	for child in _icon_texture.get_parent().get_children():
		if child is Label and child != _tier_label:
			child.queue_free()

	var icon_label = Label.new()
	icon_label.text = icon_text
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 32)
	icon_label.custom_minimum_size = ICON_SIZE

	# Insert before tier label
	var parent = _icon_texture.get_parent()
	var tier_index = _tier_label.get_index()
	_icon_texture.visible = false  # Hide texture rect
	parent.add_child(icon_label)
	parent.move_child(icon_label, tier_index)

func _update_tier_stars() -> void:
	"""Update tier stars display"""
	if not _tier_label:
		return

	var stars = ""
	for i in range(node_data.tier):
		stars += "★"

	_tier_label.text = stars

	# Color based on tier
	var tier_color = TIER_COLORS.get(node_data.tier, Color.WHITE)
	_tier_label.add_theme_color_override("font_color", tier_color)

func _update_garrison_indicator() -> void:
	"""Update garrison indicator visual"""
	if not _garrison_indicator:
		return

	var has_garrison = node_data.get_garrison_count() > 0
	_garrison_indicator.visible = has_garrison

	if has_garrison:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.8, 0.2, 0.2, 0.9)  # Red for garrison
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		_garrison_indicator.add_theme_stylebox_override("panel", style)

		# Add garrison count label
		for child in _garrison_indicator.get_children():
			child.queue_free()

		var count_label = Label.new()
		count_label.text = str(node_data.get_garrison_count())
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count_label.add_theme_font_size_override("font_size", 10)
		count_label.add_theme_color_override("font_color", Color.WHITE)
		count_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_garrison_indicator.add_child(count_label)

# ==============================================================================
# INPUT HANDLING
# ==============================================================================
func _on_mouse_entered() -> void:
	"""Handle mouse enter"""
	is_hovered = true
	_show_hover_effect()
	hex_hovered.emit(self)

func _on_mouse_exited() -> void:
	"""Handle mouse exit"""
	is_hovered = false
	_hide_hover_effect()
	hex_unhovered.emit(self)

func _on_gui_input(event: InputEvent) -> void:
	"""Handle mouse click"""
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			hex_clicked.emit(self)

func _show_hover_effect() -> void:
	"""Show hover visual effect"""
	if _state_overlay:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.2)  # White overlay
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		_state_overlay.add_theme_stylebox_override("panel", style)
		_state_overlay.visible = true

func _hide_hover_effect() -> void:
	"""Hide hover visual effect"""
	if _state_overlay:
		_state_overlay.visible = false

# ==============================================================================
# UTILITY METHODS
# ==============================================================================
func get_node_id() -> String:
	"""Get the node ID this tile represents"""
	return node_data.id if node_data else ""

func get_node_coord() -> HexCoord:
	"""Get the coordinate of this tile's node"""
	return node_data.coord if node_data else null

func get_node_state_description() -> String:
	"""Get human-readable state description"""
	if not node_data:
		return "No Data"

	if is_locked:
		return "Locked"
	elif node_data.is_contested:
		return "Contested"
	elif node_data.is_controlled_by_player():
		return "Controlled"
	elif node_data.is_enemy_controlled():
		return "Enemy"
	else:
		return "Neutral"

# scripts/ui/territory/HexTile.gd
# Visual component for a single hexagonal territory node
extends Control
class_name HexTile

"""
HexTile.gd - Visual representation of a single hex node
Simple version that works with HexTile.tscn
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
var node_data: HexNode = null
var is_locked: bool = false
var is_hovered: bool = false

# References to scene nodes
var _background_panel: Panel = null
var _icon_label: Label = null
var _tier_label: Label = null
var _lock_indicator: Label = null

# ==============================================================================
# CONSTANTS
# ==============================================================================
const HEX_SIZE = Vector2(80, 92)

# State colors - VERY BRIGHT
const COLOR_NEUTRAL = Color(0.75, 0.75, 0.8, 1.0)
const COLOR_CONTROLLED = Color(0.3, 0.85, 0.4, 1.0)
const COLOR_ENEMY = Color(0.9, 0.35, 0.35, 1.0)
const COLOR_CONTESTED = Color(0.95, 0.8, 0.3, 1.0)
const COLOR_LOCKED = Color(0.35, 0.25, 0.35, 0.95)

# Tier colors
const TIER_COLORS = {
	1: Color(0.8, 0.8, 0.8, 1),
	2: Color(0.4, 0.9, 0.4, 1),
	3: Color(0.4, 0.6, 1.0, 1),
	4: Color(0.9, 0.4, 1.0, 1),
	5: Color(1.0, 0.7, 0.0, 1)
}

# Node type icons
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
# INITIALIZATION
# ==============================================================================
func _ready() -> void:
	custom_minimum_size = HEX_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Get references to nodes from scene
	_background_panel = $BackgroundPanel
	_icon_label = $CenterContainer/IconLabel
	_tier_label = $CenterContainer/TierLabel
	_lock_indicator = $LockIndicator

	# Connect mouse signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

# ==============================================================================
# PUBLIC METHODS
# ==============================================================================
func set_node(hex_node: HexNode, locked: bool = false) -> void:
	"""Set the node data and update visuals"""
	node_data = hex_node
	is_locked = locked
	_update_visuals()

func update_state(locked: bool = false) -> void:
	"""Update visual state"""
	is_locked = locked
	_update_visuals()

func highlight(enabled: bool) -> void:
	"""Show/hide highlight - simple modulate"""
	if enabled:
		modulate = Color(1.2, 1.2, 1.2, 1.0)
	else:
		modulate = Color(1.0, 1.0, 1.0, 1.0)

# ==============================================================================
# PRIVATE METHODS
# ==============================================================================
func _update_visuals() -> void:
	"""Update all visual components"""
	if not node_data:
		return

	_update_background()
	_update_icon()
	_update_tier()
	_update_lock_indicator()

func _update_background() -> void:
	"""Update background color"""
	var style = StyleBoxFlat.new()

	# Determine color
	var bg_color: Color
	if is_locked:
		bg_color = COLOR_LOCKED
	elif node_data.is_contested:
		bg_color = COLOR_CONTESTED
	elif node_data.is_controlled_by_player():
		bg_color = COLOR_CONTROLLED
	elif node_data.is_enemy_controlled():
		bg_color = COLOR_ENEMY
	else:
		bg_color = COLOR_NEUTRAL

	style.bg_color = bg_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8

	# Border
	var tier_color = TIER_COLORS.get(node_data.tier, Color.WHITE)
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4

	if is_locked:
		style.border_color = Color(0.9, 0.2, 0.2, 1.0)  # RED
	else:
		style.border_color = tier_color.lightened(0.2)

	_background_panel.add_theme_stylebox_override("panel", style)

func _update_icon() -> void:
	"""Update node type icon"""
	var icon_text = NODE_TYPE_ICONS.get(node_data.node_type, "❓")
	_icon_label.text = icon_text
	_icon_label.add_theme_font_size_override("font_size", 32)

func _update_tier() -> void:
	"""Update tier stars"""
	var stars = ""
	for i in node_data.tier:
		stars += "⭐"
	_tier_label.text = stars
	_tier_label.add_theme_font_size_override("font_size", 10)

func _update_lock_indicator() -> void:
	"""Update lock indicator"""
	_lock_indicator.visible = is_locked
	_lock_indicator.add_theme_font_size_override("font_size", 20)

# ==============================================================================
# INPUT HANDLERS
# ==============================================================================
func _on_mouse_entered() -> void:
	is_hovered = true
	hex_hovered.emit(self)

func _on_mouse_exited() -> void:
	is_hovered = false
	hex_unhovered.emit(self)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			hex_clicked.emit(self)

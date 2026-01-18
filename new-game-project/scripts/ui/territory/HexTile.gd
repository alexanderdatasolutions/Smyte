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
var _pending_indicator: Label = null
var _tooltip_panel: Panel = null

# Production animation
var _glow_tween: Tween = null

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

	# Create pending resource indicator
	_create_pending_indicator()

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
	_update_pending_resources_indicator()

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

# ==============================================================================
# PRODUCTION VISUAL FEEDBACK
# ==============================================================================
func _create_pending_indicator() -> void:
	"""Create pending resource indicator (shown when resources are ready to collect)"""
	_pending_indicator = Label.new()
	_pending_indicator.name = "PendingIndicator"
	_pending_indicator.text = "💎"  # Gem icon for pending resources
	_pending_indicator.add_theme_font_size_override("font_size", 20)
	_pending_indicator.position = Vector2(HEX_SIZE.x - 25, -5)  # Top-right corner
	_pending_indicator.visible = false
	add_child(_pending_indicator)

func _update_pending_resources_indicator() -> void:
	"""Update pending resource indicator visibility and animation"""
	if not _pending_indicator or not node_data:
		return

	# Only show for player-controlled nodes
	if not node_data.is_controlled_by_player():
		_pending_indicator.visible = false
		if _glow_tween and _glow_tween.is_running():
			_glow_tween.kill()
		return

	# Check if node has accumulated resources
	var has_pending = false
	if node_data.accumulated_resources and node_data.accumulated_resources.size() > 0:
		for resource_id in node_data.accumulated_resources:
			if node_data.accumulated_resources[resource_id] > 0.1:  # Threshold to avoid showing tiny amounts
				has_pending = true
				break

	# Show/hide indicator with glow animation
	if has_pending:
		_pending_indicator.visible = true
		_start_glow_animation()
	else:
		_pending_indicator.visible = false
		if _glow_tween and _glow_tween.is_running():
			_glow_tween.kill()

func _start_glow_animation() -> void:
	"""Animate pending resource indicator with pulsing glow"""
	if not _pending_indicator:
		return

	# Kill existing animation
	if _glow_tween and _glow_tween.is_running():
		_glow_tween.kill()

	# Create pulsing animation
	_glow_tween = create_tween()
	_glow_tween.set_loops(0)  # Infinite
	_glow_tween.set_ease(Tween.EASE_IN_OUT)
	_glow_tween.set_trans(Tween.TRANS_SINE)

	# Pulse modulate between normal and bright
	_glow_tween.tween_property(_pending_indicator, "modulate", Color(1.5, 1.5, 0.5, 1.0), 0.8)
	_glow_tween.tween_property(_pending_indicator, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.8)

func show_collection_effect() -> void:
	"""Show visual effect when resources are collected"""
	# Particle-like effect using multiple animated labels
	for i in range(5):
		var particle = Label.new()
		particle.text = ["✨", "💎", "⭐", "🌟", "💫"][i % 5]
		particle.add_theme_font_size_override("font_size", 16)
		particle.position = Vector2(HEX_SIZE.x / 2, HEX_SIZE.y / 2) + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		particle.modulate = Color(1.0, 1.0, 1.0, 1.0)
		add_child(particle)

		# Animate particle upward and fade out
		var particle_tween = create_tween()
		particle_tween.set_parallel(true)
		particle_tween.tween_property(particle, "position:y", particle.position.y - randf_range(40, 60), 1.0)
		particle_tween.tween_property(particle, "modulate:a", 0.0, 1.0)
		particle_tween.chain().tween_callback(particle.queue_free)

	# Pulse the tile itself
	var tile_tween = create_tween()
	tile_tween.set_ease(Tween.EASE_OUT)
	tile_tween.set_trans(Tween.TRANS_ELASTIC)
	tile_tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.3)
	tile_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3)

	# Flash modulation
	tile_tween.parallel().tween_property(self, "modulate", Color(1.3, 1.3, 1.0, 1.0), 0.15)
	tile_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)

	# TODO: Add sound effect here when audio system is ready
	# AudioManager.play_sfx("resource_collection")

func show_production_tooltip() -> String:
	"""Get production tooltip text for this node"""
	if not node_data or not node_data.is_controlled_by_player():
		return ""

	# Get production manager
	var production_manager = SystemRegistry.get_instance().get_system("TerritoryProductionManager")
	if not production_manager:
		return ""

	# Calculate hourly production
	var hourly_rate = production_manager.calculate_node_production(node_data)
	if hourly_rate.size() == 0:
		return "No production (assign workers)"

	# Format tooltip
	var tooltip_lines = ["Production:"]
	for resource_id in hourly_rate:
		var rate = hourly_rate[resource_id]
		var resource_name = _format_resource_name(resource_id)
		tooltip_lines.append("  %s: +%.1f/hour" % [resource_name, rate])

	# Add pending resources if any
	if node_data.accumulated_resources and node_data.accumulated_resources.size() > 0:
		tooltip_lines.append("")
		tooltip_lines.append("Pending:")
		for resource_id in node_data.accumulated_resources:
			var amount = node_data.accumulated_resources[resource_id]
			if amount > 0.1:
				var resource_name = _format_resource_name(resource_id)
				tooltip_lines.append("  %s: %.1f" % [resource_name, amount])

	return "\n".join(tooltip_lines)

func _format_resource_name(resource_id: String) -> String:
	"""Format resource_id to display name"""
	return resource_id.capitalize().replace("_", " ")

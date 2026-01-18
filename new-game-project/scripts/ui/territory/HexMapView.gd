# scripts/ui/territory/HexMapView.gd
# Map container for rendering hex grid with pan and zoom controls
extends Control
class_name HexMapView

"""
HexMapView.gd - Hex grid map visualization component
RULE 2: Single responsibility - ONLY handles hex grid rendering and camera controls
RULE 1: Under 500 lines

Features:
- Renders hex grid using HexTile components
- Pan controls (drag to move)
- Zoom in/out
- Center on base
- Highlight selected node
- Show connection lines between controlled nodes
"""

# ==============================================================================
# SIGNALS
# ==============================================================================
signal hex_selected(hex_node: HexNode)
signal hex_hovered(hex_node: HexNode)
signal view_changed()  # Emitted when pan or zoom changes

# ==============================================================================
# PROPERTIES
# ==============================================================================
var hex_grid_manager = null
var territory_manager = null
var node_requirement_checker = null

# Visual properties
var camera_offset: Vector2 = Vector2.ZERO  # Current pan offset
var zoom_level: float = 1.0  # Current zoom (0.5 to 2.0)
var selected_node: HexNode = null

# Hex layout constants
const HEX_WIDTH: float = 80.0  # Hex tile width
const HEX_HEIGHT: float = 92.0  # Hex tile height
const HEX_HORIZONTAL_SPACING: float = 90.0  # Horizontal distance between hex centers (increased to prevent overlap)
const HEX_VERTICAL_SPACING: float = 100.0  # Vertical distance between hex centers (increased padding)
const HEX_VERTICAL_OFFSET: float = 50.0  # Vertical offset for odd columns (increased for better spacing)

# Zoom limits
const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 2.0
const ZOOM_STEP: float = 0.1

# Animation properties
var camera_tween: Tween = null
const CAMERA_TRANSITION_DURATION: float = 0.5

# Pan settings
var is_panning: bool = false
var pan_start_position: Vector2 = Vector2.ZERO
var pan_start_offset: Vector2 = Vector2.ZERO

# Tile cache
var hex_tiles: Dictionary = {}  # coord_key -> HexTile
var connection_lines: Array = []  # Array of Line2D nodes

# UI components
var grid_container: Control = null
var connection_layer: Control = null
var scroll_container: ScrollContainer = null
var tooltip_label: Label = null

# Refresh timer for pending indicators
var refresh_timer: Timer = null

# ==============================================================================
# PRELOADS
# ==============================================================================
const HexTileScene = preload("res://scenes/HexTile.tscn")

# ==============================================================================
# INITIALIZATION
# ==============================================================================
func _ready() -> void:
	_init_systems()
	_setup_ui()
	mouse_filter = Control.MOUSE_FILTER_PASS

func _init_systems() -> void:
	"""Initialize system references"""
	var registry = SystemRegistry.get_instance()
	if not registry:
		push_error("HexMapView: SystemRegistry not available")
		return

	hex_grid_manager = registry.get_system("HexGridManager")
	territory_manager = registry.get_system("TerritoryManager")
	node_requirement_checker = registry.get_system("NodeRequirementChecker")

	if not hex_grid_manager:
		push_error("HexMapView: HexGridManager not found")
	if not territory_manager:
		push_error("HexMapView: TerritoryManager not found")
	if not node_requirement_checker:
		push_error("HexMapView: NodeRequirementChecker not found")

func _setup_ui() -> void:
	"""Setup the UI layout"""
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true

	# Add a lighter background panel for contrast
	var bg_panel = Panel.new()
	bg_panel.name = "MapBackground"
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.2, 0.5)  # Semi-transparent lighter background
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	add_child(bg_panel)

	# Create scroll container
	scroll_container = ScrollContainer.new()
	scroll_container.name = "ScrollContainer"
	scroll_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll_container.follow_focus = false
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll_container)

	# Create grid container (holds all hex tiles)
	grid_container = Control.new()
	grid_container.name = "GridContainer"
	grid_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll_container.add_child(grid_container)

	# Create connection layer (drawn behind tiles)
	connection_layer = Control.new()
	connection_layer.name = "ConnectionLayer"
	connection_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_container.add_child(connection_layer)

	# Create tooltip label (overlay on top)
	_create_tooltip()

	# Create refresh timer for pending indicators
	_create_refresh_timer()

	# Initial render
	render_hex_grid()

# ==============================================================================
# PUBLIC METHODS
# ==============================================================================
func refresh() -> void:
	"""Refresh the entire hex grid display"""
	render_hex_grid()
	update_connection_lines()

func center_on_base() -> void:
	"""Center camera on the base node (0,0)"""
	if not hex_grid_manager:
		return

	var base_coord = hex_grid_manager.get_base_coord()
	center_on_coord(base_coord)

func center_on_coord(coord: HexCoord, animated: bool = true) -> void:
	"""Center camera on a specific coordinate with smooth animation"""
	if not coord:
		return

	var screen_pos = _coord_to_screen_position(coord)
	var viewport_center = size / 2.0
	# Fixed: Don't multiply screen_pos by zoom since it's already in grid space
	var target_offset = viewport_center - screen_pos

	if animated:
		_animate_camera_to(target_offset)
	else:
		camera_offset = target_offset
		_apply_camera_transform()
		view_changed.emit()

func select_node(hex_node: HexNode) -> void:
	"""Select a hex node"""
	# Deselect previous
	if selected_node:
		var old_key = _coord_to_key(selected_node.coord)
		if hex_tiles.has(old_key):
			hex_tiles[old_key].highlight(false)

	# Select new
	selected_node = hex_node
	if hex_node:
		var new_key = _coord_to_key(hex_node.coord)
		if hex_tiles.has(new_key):
			hex_tiles[new_key].highlight(true)

		hex_selected.emit(hex_node)

func zoom_in() -> void:
	"""Zoom in the map"""
	set_zoom(zoom_level + ZOOM_STEP)

func zoom_out() -> void:
	"""Zoom out the map"""
	set_zoom(zoom_level - ZOOM_STEP)

func set_zoom(new_zoom: float, animated: bool = true) -> void:
	"""Set zoom level with smooth animation"""
	var target_zoom = clampf(new_zoom, MIN_ZOOM, MAX_ZOOM)

	if animated:
		_animate_zoom_to(target_zoom)
	else:
		zoom_level = target_zoom
		_apply_camera_transform()
		view_changed.emit()

func get_zoom() -> float:
	"""Get current zoom level"""
	return zoom_level

func get_camera_offset() -> Vector2:
	"""Get current camera offset"""
	return camera_offset

# ==============================================================================
# RENDERING
# ==============================================================================
func render_hex_grid() -> void:
	"""Render all hex tiles from HexGridManager"""
	if not hex_grid_manager:
		push_error("HexMapView: hex_grid_manager is null")
		return

	# Clear existing tiles
	_clear_tiles()

	# Get all nodes from grid
	var all_nodes = hex_grid_manager.get_all_nodes()
	if all_nodes.size() == 0:
		push_warning("HexMapView: No nodes to render")
		return

	# Render each node
	for hex_node in all_nodes:
		_create_hex_tile(hex_node)

	# Update grid container size
	_update_grid_size()

	# Update connection lines
	update_connection_lines()

func _create_hex_tile(hex_node: HexNode) -> void:
	"""Create a single hex tile"""
	if not hex_node or not hex_node.coord:
		return

	# Calculate screen position
	var screen_pos = _coord_to_screen_position(hex_node.coord)

	# Create tile from scene
	var tile = HexTileScene.instantiate()
	tile.name = "Hex_%s" % hex_node.id
	tile.position = screen_pos

	# Add to grid FIRST so _ready() runs
	grid_container.add_child(tile)

	# Check if node is locked
	var is_locked = false
	if node_requirement_checker and not hex_node.is_controlled_by_player():
		is_locked = not node_requirement_checker.can_player_capture_node(hex_node)

	# Set node data AFTER adding to tree
	tile.set_node(hex_node, is_locked)

	# Connect signals
	tile.hex_clicked.connect(_on_hex_clicked)
	tile.hex_hovered.connect(_on_hex_hovered)
	tile.hex_unhovered.connect(_on_hex_unhovered)

	# Cache tile
	var key = _coord_to_key(hex_node.coord)
	hex_tiles[key] = tile

func _clear_tiles() -> void:
	"""Clear all hex tiles"""
	for tile in hex_tiles.values():
		if tile and is_instance_valid(tile):
			tile.queue_free()
	hex_tiles.clear()

	# Clear connection lines
	for line in connection_lines:
		if line and is_instance_valid(line):
			line.queue_free()
	connection_lines.clear()

func _update_grid_size() -> void:
	"""Update grid container size to fit all tiles"""
	if hex_tiles.size() == 0:
		return

	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF

	for tile in hex_tiles.values():
		min_x = min(min_x, tile.position.x)
		max_x = max(max_x, tile.position.x + HEX_WIDTH)
		min_y = min(min_y, tile.position.y)
		max_y = max(max_y, tile.position.y + HEX_HEIGHT)

	# Add padding
	var padding = 100
	grid_container.custom_minimum_size = Vector2(
		max_x - min_x + padding * 2,
		max_y - min_y + padding * 2
	)

	# Offset all tiles by padding
	var offset = Vector2(-min_x + padding, -min_y + padding)
	for tile in hex_tiles.values():
		tile.position += offset

# ==============================================================================
# CONNECTION LINES
# ==============================================================================
func update_connection_lines() -> void:
	"""Update connection lines between controlled nodes"""
	if not territory_manager or not hex_grid_manager:
		return

	# Clear existing lines
	for line in connection_lines:
		if line and is_instance_valid(line):
			line.queue_free()
	connection_lines.clear()

	# Get controlled nodes
	var controlled = territory_manager.get_controlled_nodes()

	# Draw lines between adjacent controlled nodes
	for node in controlled:
		var neighbors = hex_grid_manager.get_neighbors(node.coord)
		for neighbor in neighbors:
			if neighbor.is_controlled_by_player():
				_create_connection_line(node.coord, neighbor.coord)

	# Update bonus indicators on tiles
	_update_connection_bonus_indicators()

func _create_connection_line(coord1: HexCoord, coord2: HexCoord) -> void:
	"""Create a connection line between two coordinates with animated glow"""
	var pos1 = _coord_to_screen_position(coord1) + Vector2(HEX_WIDTH / 2, HEX_HEIGHT / 2)
	var pos2 = _coord_to_screen_position(coord2) + Vector2(HEX_WIDTH / 2, HEX_HEIGHT / 2)

	var line = Line2D.new()
	line.add_point(pos1)
	line.add_point(pos2)
	line.default_color = Color(0.3, 0.7, 0.3, 0.5)  # Green semi-transparent
	line.width = 3.0
	line.z_index = -1  # Behind tiles

	connection_layer.add_child(line)
	connection_lines.append(line)

	# Add pulsing glow animation
	_animate_connection_line_glow(line)

func _update_connection_bonus_indicators() -> void:
	"""Update visual indicators for connection bonuses on tiles"""
	if not territory_manager:
		return

	for tile in hex_tiles.values():
		if not tile or not tile.node_data:
			continue

		var hex_node = tile.node_data
		if not hex_node.is_controlled_by_player():
			continue

		# Get connected count for this node
		var connected_count = territory_manager.get_connected_node_count(hex_node.coord)

		# Update tile's connection bonus display
		_update_tile_connection_indicator(tile, connected_count)

func _update_tile_connection_indicator(tile: HexTile, connected_count: int) -> void:
	"""Update a single tile's connection bonus indicator"""
	if not tile or not is_instance_valid(tile):
		return

	# Remove existing indicator if any
	var existing = tile.get_node_or_null("ConnectionBonus")
	if existing:
		existing.queue_free()

	# No bonus to show
	if connected_count < 2:
		return

	# Create bonus indicator
	var indicator = Label.new()
	indicator.name = "ConnectionBonus"
	indicator.text = _get_connection_bonus_text(connected_count)
	indicator.add_theme_color_override("font_color", _get_connection_bonus_color(connected_count))
	indicator.position = Vector2(HEX_WIDTH - 30, 5)  # Top-right corner
	indicator.custom_minimum_size = Vector2(25, 20)
	indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Add background for visibility
	var bg = Panel.new()
	bg.custom_minimum_size = Vector2(25, 20)
	bg.modulate = Color(0.1, 0.1, 0.1, 0.7)  # Dark semi-transparent
	indicator.add_child(bg)
	bg.z_index = -1

	tile.add_child(indicator)

func _get_connection_bonus_text(connected_count: int) -> String:
	"""Get display text for connection bonus"""
	if connected_count >= 4:
		return "+30%"
	elif connected_count == 3:
		return "+20%"
	elif connected_count == 2:
		return "+10%"
	return ""

func _get_connection_bonus_color(connected_count: int) -> Color:
	"""Get color for connection bonus indicator"""
	if connected_count >= 4:
		return Color(1.0, 0.8, 0.0)  # Gold for 4+
	elif connected_count == 3:
		return Color(0.5, 1.0, 0.5)  # Light green for 3
	elif connected_count == 2:
		return Color(0.7, 0.9, 0.7)  # Pale green for 2
	return Color.WHITE

# ==============================================================================
# COORDINATE CONVERSIONS
# ==============================================================================
func _coord_to_screen_position(coord: HexCoord) -> Vector2:
	"""Convert hex coordinate to screen position"""
	if not coord:
		return Vector2.ZERO

	var x = coord.q * HEX_HORIZONTAL_SPACING
	var y = coord.r * HEX_VERTICAL_SPACING

	# Offset odd columns
	if int(coord.q) % 2 != 0:
		y += HEX_VERTICAL_OFFSET

	return Vector2(x, y)

func _coord_to_key(coord: HexCoord) -> String:
	"""Convert coordinate to cache key"""
	if not coord:
		return ""
	return "%d,%d" % [coord.q, coord.r]

# ==============================================================================
# CAMERA CONTROLS
# ==============================================================================
func _apply_camera_transform() -> void:
	"""Apply current camera transform to grid"""
	if not grid_container:
		return

	grid_container.scale = Vector2(zoom_level, zoom_level)
	grid_container.position = camera_offset

func _gui_input(event: InputEvent) -> void:
	"""Handle input for pan and zoom"""
	# Mouse wheel zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_in()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_out()
			accept_event()

		# Start panning
		elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			is_panning = true
			pan_start_position = event.position
			pan_start_offset = camera_offset
			accept_event()

		# Stop panning
		elif event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
			is_panning = false
			accept_event()

	# Panning motion
	elif event is InputEventMouseMotion and is_panning:
		var delta = event.position - pan_start_position
		camera_offset = pan_start_offset + delta
		_apply_camera_transform()
		view_changed.emit()
		accept_event()

# ==============================================================================
# SIGNAL HANDLERS
# ==============================================================================
func _on_hex_clicked(tile: HexTile) -> void:
	"""Handle hex tile click"""
	var hex_node = tile.node_data
	if hex_node:
		select_node(hex_node)

func _on_hex_hovered(tile: HexTile) -> void:
	"""Handle hex tile hover"""
	var hex_node = tile.node_data
	if hex_node:
		hex_hovered.emit(hex_node)
		_show_tooltip(tile)

func _on_hex_unhovered(tile: HexTile) -> void:
	"""Handle hex tile unhover"""
	_hide_tooltip()

# ==============================================================================
# ANIMATION METHODS
# ==============================================================================
func _animate_camera_to(target_offset: Vector2) -> void:
	"""Smoothly animate camera to target offset"""
	if camera_tween and camera_tween.is_running():
		camera_tween.kill()

	camera_tween = create_tween()
	camera_tween.set_ease(Tween.EASE_IN_OUT)
	camera_tween.set_trans(Tween.TRANS_CUBIC)

	camera_tween.tween_property(self, "camera_offset", target_offset, CAMERA_TRANSITION_DURATION)
	camera_tween.tween_callback(_apply_camera_transform)
	camera_tween.tween_callback(view_changed.emit)

func _animate_zoom_to(target_zoom: float) -> void:
	"""Smoothly animate zoom to target level"""
	if camera_tween and camera_tween.is_running():
		camera_tween.kill()

	camera_tween = create_tween()
	camera_tween.set_ease(Tween.EASE_IN_OUT)
	camera_tween.set_trans(Tween.TRANS_CUBIC)

	camera_tween.tween_property(self, "zoom_level", target_zoom, CAMERA_TRANSITION_DURATION * 0.3)
	camera_tween.tween_callback(_apply_camera_transform)
	camera_tween.tween_callback(view_changed.emit)

func play_capture_animation(hex_node: HexNode) -> void:
	"""Play visual animation when node is captured"""
	if not hex_node or not hex_node.coord:
		return

	var key = _coord_to_key(hex_node.coord)
	if not hex_tiles.has(key):
		return

	var tile = hex_tiles[key]
	_animate_tile_capture(tile)

func _animate_tile_capture(tile: HexTile) -> void:
	"""Animate a tile being captured with pulsing effect"""
	if not tile or not is_instance_valid(tile):
		return

	# Create pulsing animation
	var capture_tween = create_tween()
	capture_tween.set_loops(3)
	capture_tween.set_ease(Tween.EASE_IN_OUT)
	capture_tween.set_trans(Tween.TRANS_SINE)

	# Pulse scale
	capture_tween.tween_property(tile, "scale", Vector2(1.2, 1.2), 0.3)
	capture_tween.tween_property(tile, "scale", Vector2(1.0, 1.0), 0.3)

	# Flash modulation
	capture_tween.parallel().tween_property(tile, "modulate", Color(1.5, 1.5, 1.5), 0.3)
	capture_tween.tween_property(tile, "modulate", Color(1.0, 1.0, 1.0), 0.3)

func _animate_connection_line_glow(line: Line2D) -> void:
	"""Animate connection line with pulsing glow effect"""
	if not line or not is_instance_valid(line):
		return

	# Create infinite pulsing animation
	var line_tween = create_tween()
	line_tween.set_loops(0)  # Infinite loop
	line_tween.set_ease(Tween.EASE_IN_OUT)
	line_tween.set_trans(Tween.TRANS_SINE)

	# Pulse opacity
	line_tween.tween_property(line, "default_color", Color(0.3, 0.7, 0.3, 0.7), 1.5)
	line_tween.tween_property(line, "default_color", Color(0.3, 0.7, 0.3, 0.3), 1.5)

	# Pulse width
	line_tween.parallel().tween_property(line, "width", 4.0, 1.5)
	line_tween.tween_property(line, "width", 3.0, 1.5)

# ==============================================================================
# TOOLTIP METHODS
# ==============================================================================
func _create_tooltip() -> void:
	"""Create production tooltip overlay"""
	tooltip_label = Label.new()
	tooltip_label.name = "ProductionTooltip"
	tooltip_label.visible = false
	tooltip_label.z_index = 100  # On top of everything
	tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Style the tooltip
	var tooltip_style = StyleBoxFlat.new()
	tooltip_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	tooltip_style.border_color = Color(0.5, 0.7, 1.0, 1.0)
	tooltip_style.border_width_left = 2
	tooltip_style.border_width_right = 2
	tooltip_style.border_width_top = 2
	tooltip_style.border_width_bottom = 2
	tooltip_style.corner_radius_top_left = 4
	tooltip_style.corner_radius_top_right = 4
	tooltip_style.corner_radius_bottom_left = 4
	tooltip_style.corner_radius_bottom_right = 4
	tooltip_style.content_margin_left = 8
	tooltip_style.content_margin_right = 8
	tooltip_style.content_margin_top = 6
	tooltip_style.content_margin_bottom = 6

	# Create background panel
	var tooltip_bg = Panel.new()
	tooltip_bg.name = "TooltipBackground"
	tooltip_bg.add_theme_stylebox_override("panel", tooltip_style)
	tooltip_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_label.add_child(tooltip_bg)
	tooltip_bg.z_index = -1

	# Add to main control (not grid_container, so it's not affected by zoom/pan)
	add_child(tooltip_label)

func _show_tooltip(tile: HexTile) -> void:
	"""Show production tooltip for a hex tile"""
	if not tooltip_label or not tile:
		return

	# Get tooltip text from tile
	var tooltip_text = tile.show_production_tooltip()
	if tooltip_text == "":
		_hide_tooltip()
		return

	# Update tooltip text
	tooltip_label.text = tooltip_text
	tooltip_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	tooltip_label.add_theme_font_size_override("font_size", 12)

	# Position tooltip near mouse (offset from tile position)
	var mouse_pos = get_local_mouse_position()
	tooltip_label.position = mouse_pos + Vector2(15, 15)

	# Update background size to match text
	var tooltip_bg = tooltip_label.get_node_or_null("TooltipBackground")
	if tooltip_bg:
		# Wait one frame for label size to update
		await get_tree().process_frame
		tooltip_bg.custom_minimum_size = tooltip_label.size
		tooltip_bg.size = tooltip_label.size

	tooltip_label.visible = true

func _hide_tooltip() -> void:
	"""Hide production tooltip"""
	if tooltip_label:
		tooltip_label.visible = false

func refresh_pending_indicators() -> void:
	"""Refresh pending resource indicators on all tiles"""
	for tile in hex_tiles.values():
		if tile and is_instance_valid(tile):
			tile._update_pending_resources_indicator()

func _create_refresh_timer() -> void:
	"""Create timer to periodically refresh pending indicators"""
	refresh_timer = Timer.new()
	refresh_timer.name = "RefreshTimer"
	refresh_timer.wait_time = 5.0  # Refresh every 5 seconds
	refresh_timer.autostart = true
	refresh_timer.timeout.connect(_on_refresh_timer_timeout)
	add_child(refresh_timer)

func _on_refresh_timer_timeout() -> void:
	"""Refresh pending indicators periodically"""
	refresh_pending_indicators()

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
const HEX_HORIZONTAL_SPACING: float = 75.0  # Horizontal distance between hex centers
const HEX_VERTICAL_SPACING: float = 69.0  # Vertical distance between hex centers
const HEX_VERTICAL_OFFSET: float = 34.5  # Vertical offset for odd columns

# Zoom limits
const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 2.0
const ZOOM_STEP: float = 0.1

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

# ==============================================================================
# PRELOADS
# ==============================================================================
const HexTileScript = preload("res://scripts/ui/territory/HexTile.gd")

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

func center_on_coord(coord: HexCoord) -> void:
	"""Center camera on a specific coordinate"""
	if not coord:
		return

	var screen_pos = _coord_to_screen_position(coord)
	var viewport_center = size / 2.0
	camera_offset = viewport_center - screen_pos * zoom_level
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

func set_zoom(new_zoom: float) -> void:
	"""Set zoom level"""
	zoom_level = clampf(new_zoom, MIN_ZOOM, MAX_ZOOM)
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

	# Create tile
	var tile = HexTileScript.new()
	tile.name = "Hex_%s" % hex_node.id
	tile.position = screen_pos

	# Check if node is locked
	var is_locked = false
	if node_requirement_checker and not hex_node.is_controlled_by_player():
		is_locked = not node_requirement_checker.can_player_capture_node(hex_node)

	# Set node data
	tile.set_node(hex_node, is_locked)

	# Connect signals
	tile.hex_clicked.connect(_on_hex_clicked)
	tile.hex_hovered.connect(_on_hex_hovered)
	tile.hex_unhovered.connect(_on_hex_unhovered)

	# Add to grid
	grid_container.add_child(tile)

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

func _create_connection_line(coord1: HexCoord, coord2: HexCoord) -> void:
	"""Create a connection line between two coordinates"""
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

func _on_hex_unhovered(tile: HexTile) -> void:
	"""Handle hex tile unhover"""
	pass  # Could show tooltip hide here

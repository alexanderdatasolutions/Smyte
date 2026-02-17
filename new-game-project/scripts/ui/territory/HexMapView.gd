# scripts/ui/territory/HexMapView.gd
extends Control
class_name HexMapView

signal hex_selected(hex_node: HexNode)
signal hex_hovered(hex_node: HexNode)
signal view_changed

# ==============================================================================
# CONSTANTS
# ==============================================================================
const HexTileScene = preload("res://scenes/HexTile.tscn")

const HEX_WIDTH: float = 80.0
const HEX_HEIGHT: float = 92.0
const HEX_HORIZONTAL_SPACING: float = 90.0   # Adjusted for proper spacing
const HEX_VERTICAL_SPACING: float = 130.0    # +10px for vertical breathing room
const HEX_VERTICAL_OFFSET: float = 50.0
const GRID_PADDING: int = 100

const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 2.0
const ZOOM_STEP: float = 0.1
const DRAG_THRESHOLD: float = 10.0
const CAMERA_ANIM_DURATION: float = 0.5
const REFRESH_INTERVAL: float = 5.0

const CONNECTION_BONUSES = {
	2: { "text": "+10%", "color": Color(0.7, 0.9, 0.7) },
	3: { "text": "+20%", "color": Color(0.5, 1.0, 0.5) },
	4: { "text": "+30%", "color": Color(1.0, 0.8, 0.0) }
}

# ==============================================================================
# STATE
# ==============================================================================
var hex_grid_manager = null
var territory_manager = null
var node_requirement_checker = null

var camera_offset: Vector2 = Vector2.ZERO
var zoom_level: float = 1.0
var selected_node: HexNode = null

var _is_panning: bool = false
var _is_mouse_down: bool = false
var _has_dragged: bool = false
var _pan_start_pos: Vector2 = Vector2.ZERO
var _pan_start_offset: Vector2 = Vector2.ZERO
var _hovered_tile: HexTile = null

var _hex_tiles: Dictionary = {}
var _connection_lines: Array[Line2D] = []
var _grid_container: Control = null
var _connection_layer: Control = null
var _tooltip_label: Label = null
var _camera_tween: Tween = null

# Buff radius visualization
var _buff_radius_overlays: Array[Control] = []
var _buff_radius_layer: Control = null
var _building_buff_manager = null

# ==============================================================================
# LIFECYCLE
# ==============================================================================
func _ready() -> void:
	_init_systems()
	_setup_ui()
	mouse_filter = Control.MOUSE_FILTER_PASS

func _init_systems() -> void:
	var registry = SystemRegistry.get_instance()
	if not registry:
		push_error("HexMapView: SystemRegistry not available")
		return

	hex_grid_manager = registry.get_system("HexGridManager")
	territory_manager = registry.get_system("TerritoryManager")
	node_requirement_checker = registry.get_system("NodeRequirementChecker")
	_building_buff_manager = registry.get_system("BuildingBuffManager")

func _setup_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true

	_create_background()
	_create_grid_container()
	_create_tooltip()
	_create_refresh_timer()
	render_hex_grid()

func _create_background() -> void:
	var bg = Panel.new()
	bg.name = "MapBackground"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.5)
	bg.add_theme_stylebox_override("panel", style)
	add_child(bg)

func _create_grid_container() -> void:
	_grid_container = Control.new()
	_grid_container.name = "GridContainer"
	_grid_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grid_container)

	# Buff radius layer (below connection layer)
	_buff_radius_layer = Control.new()
	_buff_radius_layer.name = "BuffRadiusLayer"
	_buff_radius_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buff_radius_layer.z_index = -2
	_grid_container.add_child(_buff_radius_layer)

	_connection_layer = Control.new()
	_connection_layer.name = "ConnectionLayer"
	_connection_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_container.add_child(_connection_layer)

func _create_tooltip() -> void:
	_tooltip_label = Label.new()
	_tooltip_label.name = "ProductionTooltip"
	_tooltip_label.visible = false
	_tooltip_label.z_index = 100
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	_tooltip_label.add_theme_font_size_override("font_size", 12)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color(0.5, 0.7, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)

	var bg = Panel.new()
	bg.name = "TooltipBackground"
	bg.add_theme_stylebox_override("panel", style)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = -1
	_tooltip_label.add_child(bg)

	add_child(_tooltip_label)

func _create_refresh_timer() -> void:
	var timer = Timer.new()
	timer.name = "RefreshTimer"
	timer.wait_time = REFRESH_INTERVAL
	timer.autostart = true
	timer.timeout.connect(_refresh_pending_indicators)
	add_child(timer)

# ==============================================================================
# PUBLIC API
# ==============================================================================
func refresh() -> void:
	render_hex_grid()
	update_connection_lines()

func center_on_base() -> void:
	if hex_grid_manager:
		center_on_coord(hex_grid_manager.get_base_coord())

func center_on_coord(coord: HexCoord, animated: bool = true) -> void:
	if not coord:
		return

	var target = size / 2.0 - _coord_to_screen_position(coord)

	if animated:
		_animate_camera_to(target)
	else:
		camera_offset = target
		_apply_camera_transform()
		view_changed.emit()

func select_node(hex_node: HexNode) -> void:
	if selected_node:
		_set_tile_highlight(selected_node.coord, false)

	selected_node = hex_node

	if hex_node:
		_set_tile_highlight(hex_node.coord, true)
		hex_selected.emit(hex_node)

func zoom_in() -> void:
	set_zoom(zoom_level + ZOOM_STEP)

func zoom_out() -> void:
	set_zoom(zoom_level - ZOOM_STEP)

func set_zoom(new_zoom: float, animated: bool = true) -> void:
	var target = clampf(new_zoom, MIN_ZOOM, MAX_ZOOM)

	if animated:
		_animate_zoom_to(target)
	else:
		zoom_level = target
		_apply_camera_transform()
		view_changed.emit()

func get_zoom() -> float:
	return zoom_level

func get_camera_offset() -> Vector2:
	return camera_offset

func start_pan_from_tile(start_pos: Vector2, current_pos: Vector2) -> void:
	_is_mouse_down = true
	_has_dragged = true
	_is_panning = true
	_pan_start_pos = start_pos
	_pan_start_offset = camera_offset
	camera_offset = _pan_start_offset + (current_pos - start_pos)
	_apply_camera_transform()
	view_changed.emit()

func play_capture_animation(hex_node: HexNode) -> void:
	if not hex_node or not hex_node.coord:
		return

	var key = _coord_to_key(hex_node.coord)
	if _hex_tiles.has(key):
		_animate_tile_capture(_hex_tiles[key])

# ==============================================================================
# RENDERING
# ==============================================================================
func render_hex_grid() -> void:
	if not hex_grid_manager:
		return

	_clear_tiles()

	var all_nodes = hex_grid_manager.get_all_nodes()
	if all_nodes.is_empty():
		return

	for hex_node in all_nodes:
		_create_hex_tile(hex_node)

	_update_grid_size()
	update_connection_lines()

func _create_hex_tile(hex_node: HexNode) -> void:
	if not hex_node or not hex_node.coord:
		return

	var tile: HexTile = HexTileScene.instantiate()
	tile.name = "Hex_%s" % hex_node.id
	tile.position = _coord_to_screen_position(hex_node.coord)
	_grid_container.add_child(tile)

	var is_locked = false
	if node_requirement_checker and not hex_node.is_controlled_by_player():
		is_locked = not node_requirement_checker.can_player_capture_node(hex_node)

	tile.set_node(hex_node, is_locked)
	tile.hex_clicked.connect(_on_hex_clicked)
	tile.hex_hovered.connect(_on_hex_hovered)
	tile.hex_unhovered.connect(_on_hex_unhovered)

	_hex_tiles[_coord_to_key(hex_node.coord)] = tile

func _clear_tiles() -> void:
	for tile in _hex_tiles.values():
		if is_instance_valid(tile):
			tile.queue_free()
	_hex_tiles.clear()

	for line in _connection_lines:
		if is_instance_valid(line):
			line.queue_free()
	_connection_lines.clear()

func _update_grid_size() -> void:
	if _hex_tiles.is_empty():
		return

	var bounds = _calculate_grid_bounds()
	_grid_container.custom_minimum_size = bounds.size + Vector2(GRID_PADDING * 2, GRID_PADDING * 2)

	var offset = -bounds.position + Vector2(GRID_PADDING, GRID_PADDING)
	for tile in _hex_tiles.values():
		tile.position += offset

func _calculate_grid_bounds() -> Rect2:
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)

	for tile in _hex_tiles.values():
		min_pos.x = min(min_pos.x, tile.position.x)
		min_pos.y = min(min_pos.y, tile.position.y)
		max_pos.x = max(max_pos.x, tile.position.x + HEX_WIDTH)
		max_pos.y = max(max_pos.y, tile.position.y + HEX_HEIGHT)

	return Rect2(min_pos, max_pos - min_pos)

# ==============================================================================
# CONNECTION LINES
# ==============================================================================
func update_connection_lines() -> void:
	if not territory_manager or not hex_grid_manager:
		return

	for line in _connection_lines:
		if is_instance_valid(line):
			line.queue_free()
	_connection_lines.clear()

	var controlled = territory_manager.get_controlled_nodes()
	for node in controlled:
		for neighbor in hex_grid_manager.get_neighbors(node.coord):
			if neighbor.is_controlled_by_player():
				_create_connection_line(node.coord, neighbor.coord)

	_update_connection_bonus_indicators()

func _create_connection_line(coord1: HexCoord, coord2: HexCoord) -> void:
	var center_offset = Vector2(HEX_WIDTH / 2, HEX_HEIGHT / 2)
	var pos1 = _coord_to_screen_position(coord1) + center_offset
	var pos2 = _coord_to_screen_position(coord2) + center_offset

	var line = Line2D.new()
	line.add_point(pos1)
	line.add_point(pos2)
	line.default_color = Color(0.3, 0.7, 0.3, 0.5)
	line.width = 3.0
	line.z_index = -1

	_connection_layer.add_child(line)
	_connection_lines.append(line)
	_animate_connection_line(line)

func _update_connection_bonus_indicators() -> void:
	if not territory_manager:
		return

	for tile in _hex_tiles.values():
		if not tile or not tile.node_data or not tile.node_data.is_controlled_by_player():
			continue

		var count = territory_manager.get_connected_node_count(tile.node_data.coord)
		_update_tile_bonus_indicator(tile, count)

func _update_tile_bonus_indicator(tile: HexTile, connected_count: int) -> void:
	var existing = tile.get_node_or_null("ConnectionBonus")
	if existing:
		existing.queue_free()

	if connected_count < 2:
		return

	var bonus_key = mini(connected_count, 4)
	var bonus_data = CONNECTION_BONUSES.get(bonus_key, CONNECTION_BONUSES[4])

	var indicator = Label.new()
	indicator.name = "ConnectionBonus"
	indicator.text = bonus_data.text
	indicator.add_theme_color_override("font_color", bonus_data.color)
	indicator.position = Vector2(HEX_WIDTH - 30, 5)
	indicator.custom_minimum_size = Vector2(25, 20)
	indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var bg = Panel.new()
	bg.custom_minimum_size = Vector2(25, 20)
	bg.modulate = Color(0.1, 0.1, 0.1, 0.7)
	bg.z_index = -1
	indicator.add_child(bg)

	tile.add_child(indicator)

# ==============================================================================
# COORDINATE HELPERS
# ==============================================================================
func _coord_to_screen_position(coord: HexCoord) -> Vector2:
	"""Convert axial coordinates (q, r) to screen position.
	Uses proper axial-to-pixel conversion for pointy-top hexagons.
	"""
	if not coord:
		return Vector2.ZERO

	# Proper axial to pixel conversion for pointy-top hexes:
	# x = size * sqrt(3) * (q + r/2)
	# y = size * 1.5 * r
	var x = HEX_HORIZONTAL_SPACING * (coord.q + coord.r / 2.0)
	var y = HEX_VERTICAL_SPACING * 0.75 * coord.r

	return Vector2(x, y)

func _coord_to_key(coord: HexCoord) -> String:
	return "%d,%d" % [coord.q, coord.r] if coord else ""

func _set_tile_highlight(coord: HexCoord, enabled: bool) -> void:
	var key = _coord_to_key(coord)
	if _hex_tiles.has(key):
		_hex_tiles[key].highlight(enabled)

# ==============================================================================
# CAMERA
# ==============================================================================
func _apply_camera_transform() -> void:
	if _grid_container:
		_grid_container.scale = Vector2(zoom_level, zoom_level)
		_grid_container.position = camera_offset

func _reset_pan_state() -> void:
	_is_mouse_down = false
	_is_panning = false
	_has_dragged = false

# ==============================================================================
# INPUT
# ==============================================================================
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if event is InputEventMouseButton:
		_handle_global_mouse_button(event)
	elif event is InputEventMouseMotion and _is_panning:
		_apply_pan_delta(event.global_position)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_touch_drag(event)

func _handle_global_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _is_panning or _is_mouse_down:
			_reset_pan_state()
	elif event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
		_is_panning = false

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				zoom_in()
				accept_event()
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				zoom_out()
				accept_event()
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_potential_drag(event.global_position)
		MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_is_panning = true
				_pan_start_pos = event.global_position
				_pan_start_offset = camera_offset
				accept_event()
			else:
				_is_panning = false
				accept_event()

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _is_mouse_down and not _is_panning:
		var delta = event.global_position - _pan_start_pos
		if delta.length() > DRAG_THRESHOLD:
			_has_dragged = true
			_is_panning = true

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_start_potential_drag(event.position)
	else:
		if _is_mouse_down:
			if not _has_dragged and _hovered_tile:
				_on_hex_clicked(_hovered_tile)
			_reset_pan_state()
		accept_event()

func _handle_touch_drag(event: InputEventScreenDrag) -> void:
	if not _is_mouse_down:
		return

	var delta = event.position - _pan_start_pos
	if not _has_dragged and delta.length() > DRAG_THRESHOLD:
		_has_dragged = true
		_is_panning = true

	if _is_panning:
		camera_offset = _pan_start_offset + delta
		_apply_camera_transform()
		view_changed.emit()
		accept_event()

func _start_potential_drag(pos: Vector2) -> void:
	_is_mouse_down = true
	_has_dragged = false
	_pan_start_pos = pos
	_pan_start_offset = camera_offset

func _apply_pan_delta(current_pos: Vector2) -> void:
	camera_offset = _pan_start_offset + (current_pos - _pan_start_pos)
	_apply_camera_transform()
	view_changed.emit()

# ==============================================================================
# SIGNAL HANDLERS
# ==============================================================================
func _on_hex_clicked(tile: HexTile) -> void:
	if tile.node_data:
		select_node(tile.node_data)

func _on_hex_hovered(tile: HexTile) -> void:
	_hovered_tile = tile
	if tile.node_data:
		hex_hovered.emit(tile.node_data)
		_show_tooltip(tile)

func _on_hex_unhovered(_tile: HexTile) -> void:
	_hovered_tile = null
	_hide_tooltip()

# ==============================================================================
# ANIMATIONS
# ==============================================================================
func _animate_camera_to(target: Vector2) -> void:
	_kill_camera_tween()
	_camera_tween = create_tween()
	_camera_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_camera_tween.tween_property(self, "camera_offset", target, CAMERA_ANIM_DURATION)
	_camera_tween.tween_callback(_apply_camera_transform)
	_camera_tween.tween_callback(view_changed.emit)

func _animate_zoom_to(target: float) -> void:
	_kill_camera_tween()
	_camera_tween = create_tween()
	_camera_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_camera_tween.tween_property(self, "zoom_level", target, CAMERA_ANIM_DURATION * 0.3)
	_camera_tween.tween_callback(_apply_camera_transform)
	_camera_tween.tween_callback(view_changed.emit)

func _kill_camera_tween() -> void:
	if _camera_tween and _camera_tween.is_running():
		_camera_tween.kill()

func _animate_tile_capture(tile: HexTile) -> void:
	if not is_instance_valid(tile):
		return

	var tween = create_tween()
	tween.set_loops(3).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(tile, "scale", Vector2(1.2, 1.2), 0.3)
	tween.tween_property(tile, "scale", Vector2.ONE, 0.3)
	tween.parallel().tween_property(tile, "modulate", Color(1.5, 1.5, 1.5), 0.3)
	tween.tween_property(tile, "modulate", Color.WHITE, 0.3)

func _animate_connection_line(line: Line2D) -> void:
	if not is_instance_valid(line):
		return

	var tween = create_tween()
	tween.set_loops(0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)  # 0 = infinite loops
	tween.tween_property(line, "default_color", Color(0.3, 0.7, 0.3, 0.7), 1.5)
	tween.tween_property(line, "default_color", Color(0.3, 0.7, 0.3, 0.3), 1.5)
	tween.parallel().tween_property(line, "width", 4.0, 1.5)
	tween.tween_property(line, "width", 3.0, 1.5)

# ==============================================================================
# TOOLTIP
# ==============================================================================
func _show_tooltip(tile: HexTile) -> void:
	if not _tooltip_label or not tile:
		return

	var text = tile.show_production_tooltip()
	if text.is_empty():
		_hide_tooltip()
		return

	_tooltip_label.text = text
	_tooltip_label.position = get_local_mouse_position() + Vector2(15, 15)

	var bg = _tooltip_label.get_node_or_null("TooltipBackground")
	if bg:
		await get_tree().process_frame
		bg.custom_minimum_size = _tooltip_label.size
		bg.size = _tooltip_label.size

	_tooltip_label.visible = true

func _hide_tooltip() -> void:
	if _tooltip_label:
		_tooltip_label.visible = false

func _refresh_pending_indicators() -> void:
	for tile in _hex_tiles.values():
		if is_instance_valid(tile):
			tile._update_pending_resources_indicator()

# ==============================================================================
# BUFF RADIUS VISUALIZATION
# ==============================================================================

func show_buff_radius(hex_node: HexNode) -> void:
	"""Show buff radius overlay for a building with buff effects"""
	clear_buff_radius()

	if not hex_node or hex_node.placed_building.is_empty():
		return

	if not _building_buff_manager:
		return

	var radius: int = _building_buff_manager.get_building_buff_radius(hex_node.placed_building)
	if radius <= 0:
		return

	var affected_hexes: Array = _building_buff_manager.get_nodes_in_buff_radius(hex_node.coord, hex_node.placed_building)
	var buff_color: Color = _get_buff_color(hex_node.placed_building)

	for affected_node in affected_hexes:
		if not affected_node:
			continue
		_create_buff_overlay(affected_node.coord, buff_color)

func _get_buff_color(building_id: String) -> Color:
	"""Get the overlay color based on building type"""
	var effects: Dictionary = _building_buff_manager.get_building_buff_effects(building_id) if _building_buff_manager else {}

	if effects.has("defense_bonus"):
		return Color(0.3, 0.5, 0.9, 0.25)  # Blue for defense
	elif effects.has("production_bonus"):
		return Color(0.9, 0.7, 0.2, 0.25)  # Gold for production
	elif effects.has("garrison_bonus"):
		return Color(0.5, 0.9, 0.3, 0.25)  # Green for garrison

	return Color(0.5, 0.5, 0.8, 0.2)  # Default purple

func _create_buff_overlay(coord: HexCoord, color: Color) -> void:
	"""Create a colored overlay on a hex to show buff radius"""
	if not _buff_radius_layer:
		return

	var overlay: ColorRect = ColorRect.new()
	overlay.color = color
	overlay.size = Vector2(HEX_WIDTH, HEX_HEIGHT)
	overlay.position = _coord_to_screen_position(coord)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_buff_radius_layer.add_child(overlay)
	_buff_radius_overlays.append(overlay)

	# Add pulsing animation
	var tween: Tween = create_tween()
	tween.set_loops(0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(overlay, "color:a", color.a * 1.5, 0.8)
	tween.tween_property(overlay, "color:a", color.a * 0.5, 0.8)

func clear_buff_radius() -> void:
	"""Clear all buff radius overlays"""
	for overlay in _buff_radius_overlays:
		if is_instance_valid(overlay):
			overlay.queue_free()
	_buff_radius_overlays.clear()

func show_all_buff_radii() -> void:
	"""Show buff radii for all buildings with effects (for overview)"""
	clear_buff_radius()

	if not hex_grid_manager or not _building_buff_manager:
		return

	var all_nodes: Array = hex_grid_manager.get_all_nodes()
	for node in all_nodes:
		if not node or not node.is_controlled_by_player():
			continue
		if node.placed_building.is_empty():
			continue

		var radius: int = _building_buff_manager.get_building_buff_radius(node.placed_building)
		if radius > 0:
			var affected: Array = _building_buff_manager.get_nodes_in_buff_radius(node.coord, node.placed_building)
			var color: Color = _get_buff_color(node.placed_building)

			for affected_node in affected:
				if affected_node:
					_create_buff_overlay(affected_node.coord, color)

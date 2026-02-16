# scripts/ui/pvp_territory/PvPHexMapView.gd
# Hex map visualization for 8-player PvP territory
# Follows HexMapView patterns with multiplayer-specific features
extends Control
class_name PvPHexMapView

"""
PvPHexMapView - Renders PvP hex grid with 8 player colors
Matches HexMapView visual style with:
- Emoji icons for node types (same as HexTile)
- Tier star indicators
- Proper input handling for click vs drag
- 8 distinct player colors
- Owner name labels on hexes
- Objective hex highlighting
"""

# ==============================================================================
# SIGNALS
# ==============================================================================

signal hex_selected(hex_node: PvPHexNode)
signal hex_hovered(hex_node: PvPHexNode)
signal view_changed

# ==============================================================================
# CONSTANTS
# ==============================================================================

const HEX_WIDTH: float = 80.0
const HEX_HEIGHT: float = 92.0
const HEX_HORIZONTAL_SPACING: float = 90.0
const HEX_VERTICAL_SPACING: float = 130.0
const GRID_PADDING: int = 100

const MIN_ZOOM: float = 0.4
const MAX_ZOOM: float = 2.0
const ZOOM_STEP: float = 0.1
const DRAG_THRESHOLD: float = 10.0
const CAMERA_ANIM_DURATION: float = 0.5

# 8 distinct player colors
const PLAYER_COLORS := [
	Color(0.2, 0.6, 0.9),   # Blue
	Color(0.9, 0.3, 0.2),   # Red
	Color(0.3, 0.8, 0.3),   # Green
	Color(0.9, 0.7, 0.2),   # Yellow
	Color(0.7, 0.3, 0.8),   # Purple
	Color(0.9, 0.5, 0.2),   # Orange
	Color(0.3, 0.8, 0.8),   # Cyan
	Color(0.8, 0.4, 0.6)    # Pink
]

const COLOR_NEUTRAL := Color(0.35, 0.35, 0.4, 1.0)
const COLOR_OBJECTIVE_BORDER := Color(1.0, 0.85, 0.2)  # Gold
const COLOR_FOG := Color(0.15, 0.15, 0.18, 1.0)  # Dark gray for fog of war
const COLOR_PLAYER_BORDER := Color(1.0, 1.0, 0.6)  # Bright yellow border for player hexes

const VISION_RADIUS: int = 5  # Tiles visible from player territory

# Tier colors (matching HexTile)
const TIER_COLORS = {
	1: Color(0.8, 0.8, 0.8, 1),
	2: Color(0.4, 0.9, 0.4, 1),
	3: Color(0.4, 0.6, 1.0, 1),
	4: Color(0.9, 0.4, 1.0, 1),
	5: Color(1.0, 0.7, 0.0, 1)
}

# Node type icons (matching HexTile)
const NODE_TYPE_ICONS = {
	"base": "🏛️",
	"resource_node": "⛏️",
	"forge": "🔥",
	"shrine": "✨",
	"objective": "⭐",
	"spawn": "🏠",
	"blank": "◆",
	# Legacy
	"mine": "⛏️",
	"forest": "🌲",
	"coast": "🌊",
}

# ==============================================================================
# STATE
# ==============================================================================

var _map_instance: PvPMapInstance = null
var _current_user_uid: String = ""
var _player_color_map: Dictionary = {}  # uid -> color index

var camera_offset: Vector2 = Vector2.ZERO:
	set(value):
		camera_offset = value
		_apply_camera_transform()
var zoom_level: float = 1.0
var selected_node: PvPHexNode = null
var _grid_offset: Vector2 = Vector2.ZERO  # Offset applied to tiles in _update_grid_size

var _is_panning: bool = false
var _is_mouse_down: bool = false
var _has_dragged: bool = false
var _pan_start_pos: Vector2 = Vector2.ZERO
var _pan_start_offset: Vector2 = Vector2.ZERO

var _hex_tiles: Dictionary = {}  # coord_key -> Control
var _grid_container: Control = null
var _camera_tween: Tween = null
var _visible_coords: Dictionary = {}  # coord_key -> bool (tiles within vision range)

# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _ready() -> void:
	_setup_ui()
	mouse_filter = Control.MOUSE_FILTER_PASS


func _setup_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true

	_create_background()
	_create_grid_container()


func _create_background() -> void:
	var bg := Panel.new()
	bg.name = "MapBackground"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.9)
	bg.add_theme_stylebox_override("panel", style)
	add_child(bg)


func _create_grid_container() -> void:
	_grid_container = Control.new()
	_grid_container.name = "GridContainer"
	_grid_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grid_container)


# ==============================================================================
# INITIALIZATION
# ==============================================================================

func initialize(map_instance: PvPMapInstance, current_user_uid: String) -> void:
	"""Initialize with map instance"""
	_map_instance = map_instance
	_current_user_uid = current_user_uid

	# Build player color map
	_build_player_color_map()

	# Connect to map updates
	if _map_instance:
		if _map_instance.hex_updated.is_connected(_on_hex_updated):
			_map_instance.hex_updated.disconnect(_on_hex_updated)
		if _map_instance.hex_captured.is_connected(_on_hex_captured):
			_map_instance.hex_captured.disconnect(_on_hex_captured)
		_map_instance.hex_updated.connect(_on_hex_updated)
		_map_instance.hex_captured.connect(_on_hex_captured)

	render_hex_grid()
	center_on_center()


func _build_player_color_map() -> void:
	"""Assign colors to players"""
	_player_color_map.clear()
	if not _map_instance:
		return

	var index := 0
	for player_data: Dictionary in _map_instance.get_all_players():
		var uid: String = player_data.get("player_uid", "")
		if not uid.is_empty():
			_player_color_map[uid] = index % PLAYER_COLORS.size()
			index += 1


func get_player_color(player_uid: String) -> Color:
	"""Get color for a player"""
	if player_uid.is_empty():
		return COLOR_NEUTRAL

	if not _player_color_map.has(player_uid):
		# Assign new color
		_player_color_map[player_uid] = _player_color_map.size() % PLAYER_COLORS.size()

	var color_index: int = _player_color_map[player_uid]
	var base_color: Color = PLAYER_COLORS[color_index]

	# Brighten current user's hexes
	if player_uid == _current_user_uid:
		return base_color * 1.3

	return base_color


# ==============================================================================
# RENDERING
# ==============================================================================

func render_hex_grid() -> void:
	"""Render all hexes from map instance"""
	if not _map_instance:
		return

	_clear_tiles()
	_calculate_visibility()

	for hex: PvPHexNode in _map_instance.get_all_hexes():
		_create_hex_tile(hex)

	_update_grid_size()


func _calculate_visibility() -> void:
	"""Calculate which hexes are visible (within VISION_RADIUS of player territory)"""
	_visible_coords.clear()

	if not _map_instance:
		return

	# First, find all player-controlled hexes
	var player_hexes: Array[HexCoord] = []
	for hex: PvPHexNode in _map_instance.get_all_hexes():
		if hex.controller_uid == _current_user_uid:
			player_hexes.append(hex.coord)

	# For each player hex, mark all hexes within VISION_RADIUS as visible
	for player_coord: HexCoord in player_hexes:
		_mark_visible_in_radius(player_coord, VISION_RADIUS)


func _mark_visible_in_radius(center: HexCoord, radius: int) -> void:
	"""Mark all hexes within radius of center as visible"""
	for dq in range(-radius, radius + 1):
		for dr in range(-radius, radius + 1):
			var ds := -dq - dr
			# Hex distance check (cube coordinates)
			if absi(dq) + absi(dr) + absi(ds) <= radius * 2:
				var coord_key := "%d,%d" % [center.q + dq, center.r + dr]
				_visible_coords[coord_key] = true


func is_hex_visible(hex: PvPHexNode) -> bool:
	"""Check if a hex is within player's vision"""
	if not hex or not hex.coord:
		return false
	# Player's own hexes are always visible
	if hex.controller_uid == _current_user_uid:
		return true
	var coord_key := _coord_to_key(hex.coord)
	return _visible_coords.has(coord_key)


func refresh() -> void:
	"""Refresh the entire grid"""
	render_hex_grid()


func _create_hex_tile(hex: PvPHexNode) -> void:
	"""Create visual representation of a hex"""
	if not hex or not hex.coord:
		return

	var tile := _create_tile_visual(hex)
	tile.position = _coord_to_screen_position(hex.coord)
	_grid_container.add_child(tile)

	_hex_tiles[_coord_to_key(hex.coord)] = tile


func _create_tile_visual(hex: PvPHexNode) -> Control:
	"""Create the visual Control for a hex tile - matches HexTile style"""
	var tile := Control.new()
	tile.name = "Hex_%s" % hex.id
	tile.custom_minimum_size = Vector2(HEX_WIDTH, HEX_HEIGHT)
	tile.mouse_filter = Control.MOUSE_FILTER_STOP

	# Store reference to hex data
	tile.set_meta("hex_node", hex)

	# Check visibility for fog of war
	var hex_visible := is_hex_visible(hex)
	var is_player_hex := hex.controller_uid == _current_user_uid

	# Background panel with player color
	var panel := Panel.new()
	panel.name = "Background"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()

	# Apply fog of war or player color
	if not hex_visible:
		style.bg_color = COLOR_FOG
	else:
		style.bg_color = get_player_color(hex.controller_uid)

	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8

	# Border color based on ownership, tier and type
	var tier_color: Color = TIER_COLORS.get(hex.tier, Color.WHITE)

	# Player's own hexes get thick bright yellow border
	if is_player_hex:
		style.border_width_left = 5
		style.border_width_right = 5
		style.border_width_top = 5
		style.border_width_bottom = 5
		style.border_color = COLOR_PLAYER_BORDER
	elif not hex_visible:
		# Fogged hexes get dim border
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.25, 0.25, 0.3)
	else:
		style.border_width_left = 4
		style.border_width_right = 4
		style.border_width_top = 4
		style.border_width_bottom = 4
		if hex.is_objective:
			style.border_color = COLOR_OBJECTIVE_BORDER
		elif hex.is_spawn_node:
			style.border_color = Color(0.9, 0.9, 0.9)
		else:
			style.border_color = tier_color.lightened(0.2)

	panel.add_theme_stylebox_override("panel", style)
	tile.add_child(panel)

	# Center container for icon
	var center := CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(center)

	# Node type icon (large, centered) - show "?" for fogged tiles
	var icon_label := Label.new()
	icon_label.name = "IconLabel"
	if hex_visible:
		icon_label.text = _get_node_icon(hex)
	else:
		icon_label.text = "?"
	icon_label.add_theme_font_size_override("font_size", 32)
	if not hex_visible:
		icon_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(icon_label)

	# Tier stars (top-left) - only show for visible tiles
	if hex_visible:
		var tier_label := Label.new()
		tier_label.name = "TierLabel"
		tier_label.text = _get_tier_stars(hex.tier)
		tier_label.add_theme_font_size_override("font_size", 10)
		tier_label.add_theme_color_override("font_color", tier_color)
		tier_label.position = Vector2(5, 2)
		tier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(tier_label)

	# Owner name (bottom) - only show for visible, non-neutral tiles
	if hex_visible and not hex.is_neutral():
		var owner_label := Label.new()
		owner_label.name = "OwnerLabel"
		owner_label.text = _get_short_owner_name(hex)
		owner_label.add_theme_font_size_override("font_size", 9)
		owner_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
		owner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		owner_label.position = Vector2(0, HEX_HEIGHT - 16)
		owner_label.custom_minimum_size = Vector2(HEX_WIDTH, 14)
		owner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(owner_label)

	# Objective indicator (top-right, gold star) - only show for visible objectives
	if hex_visible and hex.is_objective:
		var obj_icon := Label.new()
		obj_icon.name = "ObjectiveIcon"
		obj_icon.text = "⭐"
		obj_icon.add_theme_font_size_override("font_size", 14)
		obj_icon.add_theme_color_override("font_color", COLOR_OBJECTIVE_BORDER)
		obj_icon.position = Vector2(HEX_WIDTH - 20, 2)
		obj_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(obj_icon)

	# Connect input
	tile.gui_input.connect(_on_tile_gui_input.bind(tile))
	tile.mouse_entered.connect(_on_tile_hovered.bind(tile))

	return tile


func _get_node_icon(hex: PvPHexNode) -> String:
	"""Get appropriate icon for node type"""
	if hex.is_spawn_node:
		return "🏠"
	if hex.is_objective:
		return "⭐"
	if hex.node_type and NODE_TYPE_ICONS.has(hex.node_type):
		return NODE_TYPE_ICONS[hex.node_type]
	# Default territory icon
	return "◆"


func _get_tier_stars(tier: int) -> String:
	"""Get tier stars string"""
	var stars := ""
	for i in range(tier):
		stars += "★"
	return stars


func _get_short_owner_name(hex: PvPHexNode) -> String:
	"""Get shortened owner name"""
	var owner_name: String = hex.controller_display_name
	if owner_name.is_empty():
		return ""
	if owner_name.length() <= 8:
		return owner_name
	return owner_name.substr(0, 6) + ".."


func _update_tile_visual(tile: Control, hex: PvPHexNode) -> void:
	"""Update an existing tile's visuals"""
	# Recalculate visibility (ownership may have changed)
	_calculate_visibility()

	var hex_visible := is_hex_visible(hex)
	var is_player_hex := hex.controller_uid == _current_user_uid

	var panel: Panel = tile.get_node_or_null("Background")
	if panel:
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate()
		if not hex_visible:
			style.bg_color = COLOR_FOG
		else:
			style.bg_color = get_player_color(hex.controller_uid)

		# Update border based on ownership
		var tier_color: Color = TIER_COLORS.get(hex.tier, Color.WHITE)
		if is_player_hex:
			style.border_width_left = 5
			style.border_width_right = 5
			style.border_width_top = 5
			style.border_width_bottom = 5
			style.border_color = COLOR_PLAYER_BORDER
		elif not hex_visible:
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			style.border_color = Color(0.25, 0.25, 0.3)
		else:
			style.border_width_left = 4
			style.border_width_right = 4
			style.border_width_top = 4
			style.border_width_bottom = 4
			if hex.is_objective:
				style.border_color = COLOR_OBJECTIVE_BORDER
			elif hex.is_spawn_node:
				style.border_color = Color(0.9, 0.9, 0.9)
			else:
				style.border_color = tier_color.lightened(0.2)

		panel.add_theme_stylebox_override("panel", style)

	var icon_label: Label = tile.get_node_or_null("CenterContainer/IconLabel")
	if icon_label:
		if hex_visible:
			icon_label.text = _get_node_icon(hex)
			icon_label.remove_theme_color_override("font_color")
		else:
			icon_label.text = "?"
			icon_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))

	# Update or add owner label
	var owner_label: Label = tile.get_node_or_null("OwnerLabel")
	if not hex_visible or hex.is_neutral():
		if owner_label:
			owner_label.queue_free()
	else:
		if not owner_label:
			owner_label = Label.new()
			owner_label.name = "OwnerLabel"
			owner_label.add_theme_font_size_override("font_size", 9)
			owner_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
			owner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			owner_label.position = Vector2(0, HEX_HEIGHT - 16)
			owner_label.custom_minimum_size = Vector2(HEX_WIDTH, 14)
			owner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(owner_label)
		owner_label.text = _get_short_owner_name(hex)


func _clear_tiles() -> void:
	"""Remove all hex tiles"""
	for tile: Control in _hex_tiles.values():
		if is_instance_valid(tile):
			tile.queue_free()
	_hex_tiles.clear()


func _update_grid_size() -> void:
	"""Update grid container size based on tiles"""
	if _hex_tiles.is_empty():
		return

	var bounds := _calculate_grid_bounds()
	_grid_container.custom_minimum_size = bounds.size + Vector2(GRID_PADDING * 2, GRID_PADDING * 2)

	_grid_offset = -bounds.position + Vector2(GRID_PADDING, GRID_PADDING)
	for tile: Control in _hex_tiles.values():
		tile.position += _grid_offset


func _calculate_grid_bounds() -> Rect2:
	"""Calculate bounding box of all tiles"""
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)

	for tile: Control in _hex_tiles.values():
		min_pos.x = min(min_pos.x, tile.position.x)
		min_pos.y = min(min_pos.y, tile.position.y)
		max_pos.x = max(max_pos.x, tile.position.x + HEX_WIDTH)
		max_pos.y = max(max_pos.y, tile.position.y + HEX_HEIGHT)

	return Rect2(min_pos, max_pos - min_pos)


# ==============================================================================
# COORDINATE HELPERS
# ==============================================================================

func _coord_to_screen_position(coord: HexCoord) -> Vector2:
	"""Convert axial coordinates to screen position"""
	if not coord:
		return Vector2.ZERO

	var x := HEX_HORIZONTAL_SPACING * (coord.q + coord.r / 2.0)
	var y := HEX_VERTICAL_SPACING * 0.75 * coord.r

	return Vector2(x, y)


func _coord_to_key(coord: HexCoord) -> String:
	"""Convert coordinate to dictionary key"""
	return "%d,%d" % [coord.q, coord.r] if coord else ""


# ==============================================================================
# CAMERA CONTROLS
# ==============================================================================

func center_on_center() -> void:
	"""Center view on map center (0,0)"""
	var center_coord: HexCoord = HexCoord.from_qr(0, 0)
	center_on_coord(center_coord)


func center_on_coord(coord: HexCoord, animated: bool = true) -> void:
	"""Center view on a specific coordinate"""
	if not coord:
		return

	# Account for grid offset that was applied to tile positions
	var screen_pos := (_coord_to_screen_position(coord) + _grid_offset) * zoom_level
	var target := size / 2.0 - screen_pos

	if animated:
		_animate_camera_to(target)
	else:
		camera_offset = target
		view_changed.emit()


func _apply_camera_transform() -> void:
	"""Apply camera offset and zoom"""
	if _grid_container:
		_grid_container.scale = Vector2(zoom_level, zoom_level)
		_grid_container.position = camera_offset


func _animate_camera_to(target: Vector2) -> void:
	"""Animate camera to target position"""
	if _camera_tween and _camera_tween.is_running():
		_camera_tween.kill()

	_camera_tween = create_tween()
	_camera_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	# camera_offset setter calls _apply_camera_transform automatically
	_camera_tween.tween_property(self, "camera_offset", target, CAMERA_ANIM_DURATION)
	_camera_tween.tween_callback(view_changed.emit)


func zoom_in() -> void:
	zoom_level = clampf(zoom_level + ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
	_apply_camera_transform()
	view_changed.emit()


func zoom_out() -> void:
	zoom_level = clampf(zoom_level - ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
	_apply_camera_transform()
	view_changed.emit()


# ==============================================================================
# INPUT HANDLING
# ==============================================================================

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_is_panning = false
			_is_mouse_down = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


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
				_is_mouse_down = true
				_has_dragged = false
				_pan_start_pos = event.global_position
				_pan_start_offset = camera_offset


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _is_mouse_down:
		var delta := event.global_position - _pan_start_pos
		if delta.length() > DRAG_THRESHOLD:
			_has_dragged = true
			_is_panning = true
			camera_offset = _pan_start_offset + delta  # Setter applies transform
			view_changed.emit()


func _on_tile_gui_input(event: InputEvent, tile: Control) -> void:
	"""Handle input on individual tiles"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_mouse_down = true
				_has_dragged = false
				_pan_start_pos = event.global_position
				_pan_start_offset = camera_offset
			else:
				# Released - check if it was a click (not a drag)
				if not _has_dragged:
					var hex: PvPHexNode = tile.get_meta("hex_node")
					if hex:
						_select_hex(hex, tile)
				_is_mouse_down = false

	elif event is InputEventMouseMotion and _is_mouse_down:
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		var delta: Vector2 = motion_event.global_position - _pan_start_pos
		if delta.length() > DRAG_THRESHOLD:
			_has_dragged = true
			_is_panning = true
			camera_offset = _pan_start_offset + delta  # Setter applies transform
			view_changed.emit()


func _on_tile_hovered(tile: Control) -> void:
	"""Handle tile hover"""
	var hex: PvPHexNode = tile.get_meta("hex_node")
	if hex:
		hex_hovered.emit(hex)


func _select_hex(hex: PvPHexNode, tile: Control) -> void:
	"""Select a hex"""
	# Deselect previous
	if selected_node:
		var prev_key := _coord_to_key(selected_node.coord)
		if _hex_tiles.has(prev_key):
			_set_tile_selected(_hex_tiles[prev_key], false)

	selected_node = hex
	_set_tile_selected(tile, true)
	hex_selected.emit(hex)


func select_node(hex: PvPHexNode) -> void:
	"""Public method to select a node (or deselect if null)"""
	# Deselect previous
	if selected_node:
		var prev_key := _coord_to_key(selected_node.coord)
		if _hex_tiles.has(prev_key):
			_set_tile_selected(_hex_tiles[prev_key], false)

	selected_node = hex

	if hex:
		var key := _coord_to_key(hex.coord)
		if _hex_tiles.has(key):
			_set_tile_selected(_hex_tiles[key], true)


func _set_tile_selected(tile: Control, selected: bool) -> void:
	"""Set tile selection visual state"""
	var panel: Panel = tile.get_node_or_null("Background")
	if not panel:
		return

	var style: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate()
	if selected:
		style.border_width_left = 6
		style.border_width_right = 6
		style.border_width_top = 6
		style.border_width_bottom = 6
		style.border_color = Color.WHITE
	else:
		var hex: PvPHexNode = tile.get_meta("hex_node")
		style.border_width_left = 4
		style.border_width_right = 4
		style.border_width_top = 4
		style.border_width_bottom = 4
		if hex:
			if hex.is_objective:
				style.border_color = COLOR_OBJECTIVE_BORDER
			elif hex.is_spawn_node:
				style.border_color = Color(0.9, 0.9, 0.9)
			else:
				var tier_color: Color = TIER_COLORS.get(hex.tier, Color.WHITE)
				style.border_color = tier_color.lightened(0.2)

	panel.add_theme_stylebox_override("panel", style)


# ==============================================================================
# UPDATE HANDLERS
# ==============================================================================

func _on_hex_updated(_hex_id: String, hex: PvPHexNode) -> void:
	"""Handle hex state update"""
	if not hex or not hex.coord:
		return
	var key := _coord_to_key(hex.coord)
	if _hex_tiles.has(key):
		_update_tile_visual(_hex_tiles[key], hex)


func _on_hex_captured(hex_id: String, _old_owner: String, _new_owner: String) -> void:
	"""Handle hex capture - animate"""
	var hex := _map_instance.get_hex(hex_id)
	if hex:
		var key := _coord_to_key(hex.coord)
		if _hex_tiles.has(key):
			_animate_capture(_hex_tiles[key])


func _animate_capture(tile: Control) -> void:
	"""Play capture animation on tile"""
	var tween := create_tween()
	tween.set_loops(3).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(tile, "scale", Vector2(1.2, 1.2), 0.2)
	tween.tween_property(tile, "scale", Vector2.ONE, 0.2)

# tests/unit/test_hex_map_view_bonuses.gd
# Unit tests for HexMapView connection bonus indicators
extends GutTest

# ==============================================================================
# SETUP
# ==============================================================================
var hex_map_view: HexMapView = null
var mock_hex_grid_manager = null
var mock_territory_manager = null
var mock_node_requirement_checker = null
var mock_nodes = []

func before_each():
	# Create HexMapView instance
	hex_map_view = HexMapView.new()

	# Create mock systems
	_setup_mock_systems()

	# Inject mocks
	hex_map_view.hex_grid_manager = mock_hex_grid_manager
	hex_map_view.territory_manager = mock_territory_manager
	hex_map_view.node_requirement_checker = mock_node_requirement_checker

func after_each():
	if hex_map_view:
		hex_map_view.free()
	mock_nodes.clear()

func _setup_mock_systems():
	# Create mock HexGridManager
	mock_hex_grid_manager = double(Node).new()
	stub(mock_hex_grid_manager, "get_all_nodes").to_return([])
	stub(mock_hex_grid_manager, "get_base_coord").to_return(_create_hex_coord(0, 0))
	stub(mock_hex_grid_manager, "get_player_nodes").to_return([])
	stub(mock_hex_grid_manager, "get_neighbors").to_return([])

	# Create mock TerritoryManager
	mock_territory_manager = double(Node).new()
	stub(mock_territory_manager, "get_controlled_nodes").to_return([])
	stub(mock_territory_manager, "get_connected_node_count").to_return(0)

	# Create mock NodeRequirementChecker
	mock_node_requirement_checker = double(Node).new()
	stub(mock_node_requirement_checker, "can_player_capture_node").to_return(true)

func _create_hex_coord(q: int, r: int):
	var coord_script = load("res://scripts/data/HexCoord.gd")
	var coord = coord_script.new()
	coord.q = q
	coord.r = r
	return coord

func _create_hex_node(node_id: String, q: int, r: int, controller: String = "player"):
	var node_script = load("res://scripts/data/HexNode.gd")
	var node_data = {
		"id": node_id,
		"name": "Test Node",
		"node_type": "mine",
		"coord": {"q": q, "r": r},
		"tier": 1,
		"controller": controller,
		"garrison": [],
		"assigned_workers": [],
		"active_tasks": [],
		"production_level": 1,
		"defense_level": 1,
		"max_garrison": 2,
		"max_workers": 3,
		"is_revealed": true,
		"is_contested": false,
		"base_defenders": [],
		"available_tasks": [],
		"base_production": {},
		"unlock_requirements": {
			"player_level_required": 1,
			"specialization_tier_required": 0,
			"power_required": 1000
		}
	}
	var hex_node = node_script.from_dict(node_data)
	mock_nodes.append(hex_node)
	return hex_node

# ==============================================================================
# CONNECTION BONUS TEXT TESTS
# ==============================================================================
func test_get_connection_bonus_text_2_connected():
	var text = hex_map_view._get_connection_bonus_text(2)
	assert_eq(text, "+10%", "Should return +10% for 2 connected nodes")

func test_get_connection_bonus_text_3_connected():
	var text = hex_map_view._get_connection_bonus_text(3)
	assert_eq(text, "+20%", "Should return +20% for 3 connected nodes")

func test_get_connection_bonus_text_4_connected():
	var text = hex_map_view._get_connection_bonus_text(4)
	assert_eq(text, "+30%", "Should return +30% for 4 connected nodes")

func test_get_connection_bonus_text_5_connected():
	var text = hex_map_view._get_connection_bonus_text(5)
	assert_eq(text, "+30%", "Should return +30% for 5+ connected nodes")

func test_get_connection_bonus_text_0_connected():
	var text = hex_map_view._get_connection_bonus_text(0)
	assert_eq(text, "", "Should return empty string for 0 connected nodes")

func test_get_connection_bonus_text_1_connected():
	var text = hex_map_view._get_connection_bonus_text(1)
	assert_eq(text, "", "Should return empty string for 1 connected node")

# ==============================================================================
# CONNECTION BONUS COLOR TESTS
# ==============================================================================
func test_get_connection_bonus_color_2_connected():
	var color = hex_map_view._get_connection_bonus_color(2)
	assert_eq(color, Color(0.7, 0.9, 0.7), "Should return pale green for 2 connected")

func test_get_connection_bonus_color_3_connected():
	var color = hex_map_view._get_connection_bonus_color(3)
	assert_eq(color, Color(0.5, 1.0, 0.5), "Should return light green for 3 connected")

func test_get_connection_bonus_color_4_connected():
	var color = hex_map_view._get_connection_bonus_color(4)
	assert_eq(color, Color(1.0, 0.8, 0.0), "Should return gold for 4+ connected")

func test_get_connection_bonus_color_6_connected():
	var color = hex_map_view._get_connection_bonus_color(6)
	assert_eq(color, Color(1.0, 0.8, 0.0), "Should return gold for 6 connected")

func test_get_connection_bonus_color_0_connected():
	var color = hex_map_view._get_connection_bonus_color(0)
	assert_eq(color, Color.WHITE, "Should return white for 0 connected")

# ==============================================================================
# CONNECTION BONUS INDICATOR UPDATE TESTS
# ==============================================================================
func test_update_tile_connection_indicator_no_bonus():
	var tile = autofree(HexTile.new())
	var node = _create_hex_node("test_node", 0, 0)
	tile.set_node(node, false)

	hex_map_view._update_tile_connection_indicator(tile, 0)

	var indicator = tile.get_node_or_null("ConnectionBonus")
	assert_null(indicator, "Should not create indicator for 0 connected")

func test_update_tile_connection_indicator_1_connected():
	var tile = autofree(HexTile.new())
	var node = _create_hex_node("test_node", 0, 0)
	tile.set_node(node, false)

	hex_map_view._update_tile_connection_indicator(tile, 1)

	var indicator = tile.get_node_or_null("ConnectionBonus")
	assert_null(indicator, "Should not create indicator for 1 connected")

func test_update_tile_connection_indicator_2_connected():
	var tile = autofree(HexTile.new())
	var node = _create_hex_node("test_node", 0, 0)
	tile.set_node(node, false)

	hex_map_view._update_tile_connection_indicator(tile, 2)

	var indicator = tile.get_node_or_null("ConnectionBonus")
	assert_not_null(indicator, "Should create indicator for 2 connected")
	assert_eq(indicator.text, "+10%", "Should show +10% text")

func test_update_tile_connection_indicator_3_connected():
	var tile = autofree(HexTile.new())
	var node = _create_hex_node("test_node", 0, 0)
	tile.set_node(node, false)

	hex_map_view._update_tile_connection_indicator(tile, 3)

	var indicator = tile.get_node_or_null("ConnectionBonus")
	assert_not_null(indicator, "Should create indicator for 3 connected")
	assert_eq(indicator.text, "+20%", "Should show +20% text")

func test_update_tile_connection_indicator_4_connected():
	var tile = autofree(HexTile.new())
	var node = _create_hex_node("test_node", 0, 0)
	tile.set_node(node, false)

	hex_map_view._update_tile_connection_indicator(tile, 4)

	var indicator = tile.get_node_or_null("ConnectionBonus")
	assert_not_null(indicator, "Should create indicator for 4+ connected")
	assert_eq(indicator.text, "+30%", "Should show +30% text")

func test_update_tile_connection_indicator_removes_existing():
	var tile = autofree(HexTile.new())
	var node = _create_hex_node("test_node", 0, 0)
	tile.set_node(node, false)

	# Create first indicator
	hex_map_view._update_tile_connection_indicator(tile, 2)
	var first_indicator = tile.get_node_or_null("ConnectionBonus")
	assert_not_null(first_indicator, "Should create first indicator")

	# Update with different bonus
	hex_map_view._update_tile_connection_indicator(tile, 3)
	var second_indicator = tile.get_node_or_null("ConnectionBonus")
	assert_not_null(second_indicator, "Should create second indicator")
	assert_eq(second_indicator.text, "+20%", "Should show updated text")

func test_update_tile_connection_indicator_null_tile():
	# Should not crash with null tile
	hex_map_view._update_tile_connection_indicator(null, 2)
	assert_true(true, "Should handle null tile gracefully")

func test_update_tile_connection_indicator_has_background():
	var tile = autofree(HexTile.new())
	var node = _create_hex_node("test_node", 0, 0)
	tile.set_node(node, false)

	hex_map_view._update_tile_connection_indicator(tile, 2)

	var indicator = tile.get_node_or_null("ConnectionBonus")
	assert_not_null(indicator, "Should create indicator")
	assert_eq(indicator.get_child_count(), 1, "Should have background panel")

# ==============================================================================
# UPDATE CONNECTION BONUS INDICATORS TESTS
# ==============================================================================
func test_update_connection_bonus_indicators_no_territory_manager():
	hex_map_view.territory_manager = null

	# Should not crash
	hex_map_view._update_connection_bonus_indicators()
	assert_true(true, "Should handle missing territory manager")

func test_update_connection_bonus_indicators_no_tiles():
	hex_map_view.hex_tiles.clear()

	# Should not crash
	hex_map_view._update_connection_bonus_indicators()
	assert_true(true, "Should handle empty tile cache")

func test_update_connection_bonus_indicators_player_nodes_only():
	# Create tiles for player and enemy nodes
	var player_node = _create_hex_node("player_node", 0, 0, "player")
	var enemy_node = _create_hex_node("enemy_node", 1, 0, "enemy")

	var player_tile = autofree(HexTile.new())
	player_tile.set_node(player_node, false)

	var enemy_tile = autofree(HexTile.new())
	enemy_tile.set_node(enemy_node, false)

	hex_map_view.hex_tiles["0,0"] = player_tile
	hex_map_view.hex_tiles["1,0"] = enemy_tile

	# Mock connected count
	stub(mock_territory_manager, "get_connected_node_count").to_return(2)

	# Update indicators
	hex_map_view._update_connection_bonus_indicators()

	# Player node should have indicator
	var player_indicator = player_tile.get_node_or_null("ConnectionBonus")
	assert_not_null(player_indicator, "Player node should have bonus indicator")

	# Enemy node should not have indicator
	var enemy_indicator = enemy_tile.get_node_or_null("ConnectionBonus")
	assert_null(enemy_indicator, "Enemy node should not have bonus indicator")

func test_update_connection_bonus_indicators_correct_counts():
	# Create 3 player nodes with different connected counts
	var node1 = _create_hex_node("node1", 0, 0, "player")
	var node2 = _create_hex_node("node2", 1, 0, "player")
	var node3 = _create_hex_node("node3", 2, 0, "player")

	var tile1 = autofree(HexTile.new())
	tile1.set_node(node1, false)
	var tile2 = autofree(HexTile.new())
	tile2.set_node(node2, false)
	var tile3 = autofree(HexTile.new())
	tile3.set_node(node3, false)

	hex_map_view.hex_tiles["0,0"] = tile1
	hex_map_view.hex_tiles["1,0"] = tile2
	hex_map_view.hex_tiles["2,0"] = tile3

	# Mock different connected counts for each node
	stub(mock_territory_manager, "get_connected_node_count").to_return_func(func(coord):
		if coord.q == 0:
			return 2
		elif coord.q == 1:
			return 3
		else:
			return 4
	)

	# Update indicators
	hex_map_view._update_connection_bonus_indicators()

	# Check correct bonus text
	assert_eq(tile1.get_node_or_null("ConnectionBonus").text, "+10%", "Node1 should show +10%")
	assert_eq(tile2.get_node_or_null("ConnectionBonus").text, "+20%", "Node2 should show +20%")
	assert_eq(tile3.get_node_or_null("ConnectionBonus").text, "+30%", "Node3 should show +30%")

# ==============================================================================
# INTEGRATION WITH UPDATE_CONNECTION_LINES TESTS
# ==============================================================================
func test_update_connection_lines_calls_update_bonus_indicators():
	# Mock controlled nodes
	var node1 = _create_hex_node("node1", 0, 0, "player")
	var node2 = _create_hex_node("node2", 1, 0, "player")

	stub(mock_territory_manager, "get_controlled_nodes").to_return([node1, node2])
	stub(mock_hex_grid_manager, "get_neighbors").to_return([node2])
	stub(mock_territory_manager, "get_connected_node_count").to_return(2)

	var tile1 = autofree(HexTile.new())
	tile1.set_node(node1, false)
	hex_map_view.hex_tiles["0,0"] = tile1

	# Update connection lines (should also update bonus indicators)
	hex_map_view.update_connection_lines()

	# Check that bonus indicator was created
	var indicator = tile1.get_node_or_null("ConnectionBonus")
	assert_not_null(indicator, "Should create bonus indicator when updating connection lines")

# ==============================================================================
# EDGE CASE TESTS
# ==============================================================================
func test_update_tile_connection_indicator_invalid_tile():
	var tile = autofree(HexTile.new())
	tile.free()  # Make invalid

	# Should not crash
	hex_map_view._update_tile_connection_indicator(tile, 2)
	assert_true(true, "Should handle invalid tile gracefully")

func test_connection_bonus_color_negative_value():
	var color = hex_map_view._get_connection_bonus_color(-1)
	assert_eq(color, Color.WHITE, "Should return white for negative connected count")

func test_connection_bonus_text_negative_value():
	var text = hex_map_view._get_connection_bonus_text(-1)
	assert_eq(text, "", "Should return empty string for negative connected count")

func test_update_connection_bonus_indicators_null_node_data():
	var tile = autofree(HexTile.new())
	# Don't set node data, leave it null
	hex_map_view.hex_tiles["0,0"] = tile

	# Should not crash
	hex_map_view._update_connection_bonus_indicators()
	assert_true(true, "Should handle tile with null node data")

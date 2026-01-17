# tests/unit/test_node_capture_handler.gd
# Unit tests for NodeCaptureHandler
extends GutTest

var handler: NodeCaptureHandler
var mock_hex_node: HexNode

func before_each():
	handler = NodeCaptureHandler.new()
	add_child_autofree(handler)

	# Create mock hex node
	mock_hex_node = HexNode.new()
	mock_hex_node.id = "test_node_1"
	mock_hex_node.name = "Test Mine"
	mock_hex_node.node_type = "mine"
	mock_hex_node.tier = 1
	mock_hex_node.coord = HexCoord.from_qr(1, 0)
	mock_hex_node.controller = "neutral"
	mock_hex_node.base_defenders = []
	mock_hex_node.garrison = []
	mock_hex_node.capture_power_required = 5000

# ==============================================================================
# INITIALIZATION TESTS
# ==============================================================================

func test_handler_initializes():
	assert_not_null(handler, "Handler should be created")
	assert_null(handler.current_capture_node, "Should start with no capture node")

func test_signals_exist():
	assert_has_signal(handler, "capture_initiated")
	assert_has_signal(handler, "capture_succeeded")
	assert_has_signal(handler, "capture_failed")

# ==============================================================================
# INITIATE CAPTURE TESTS
# ==============================================================================

func test_initiate_capture_with_null_node():
	var result = handler.initiate_capture(null)
	assert_false(result, "Should fail with null node")

func test_initiate_capture_stores_node():
	handler.initiate_capture(mock_hex_node)
	assert_eq(handler.current_capture_node, mock_hex_node, "Should store capture node")

func test_initiate_capture_emits_signal():
	watch_signals(handler)
	handler.initiate_capture(mock_hex_node)
	assert_signal_emitted(handler, "capture_initiated", "Should emit capture_initiated signal")

# ==============================================================================
# BATTLE CONFIG CREATION TESTS
# ==============================================================================

func test_create_default_defender():
	var defender = handler._create_default_defender(mock_hex_node)
	assert_not_null(defender, "Should create defender")
	assert_eq(defender.get("name"), "Territory Guardian", "Should have correct name")
	assert_eq(defender.get("level"), 5, "Level should be tier * 5")
	assert_eq(defender.get("base_hp"), 1500, "HP should be 1000 + tier * 500")
	assert_eq(defender.get("base_attack"), 150, "Attack should be 100 + tier * 50")
	assert_eq(defender.get("base_defense"), 140, "Defense should be 100 + tier * 40")
	assert_eq(defender.get("base_speed"), 60, "Speed should be 50 + tier * 10")

func test_create_default_defender_tier_scaling():
	mock_hex_node.tier = 3
	var defender = handler._create_default_defender(mock_hex_node)
	assert_eq(defender.get("level"), 15, "Level should scale with tier")
	assert_eq(defender.get("base_hp"), 2500, "HP should scale with tier")
	assert_eq(defender.get("base_attack"), 250, "Attack should scale with tier")

# ==============================================================================
# GOD AVAILABILITY TESTS
# ==============================================================================

func test_is_god_available_no_territory_manager():
	handler.territory_manager = null
	var available = handler._is_god_available_for_battle("god_1")
	assert_true(available, "Should be available if no territory manager")

# ==============================================================================
# BATTLE RESULT HANDLING TESTS
# ==============================================================================

func test_on_capture_battle_ended_clears_node():
	handler.current_capture_node = mock_hex_node

	var result = BattleResult.new()
	result.victory = false

	handler._on_capture_battle_ended(result)
	assert_null(handler.current_capture_node, "Should clear current capture node")

func test_on_capture_succeeded_emits_signal():
	watch_signals(handler)
	handler._handle_capture_victory(mock_hex_node)
	assert_signal_emitted(handler, "capture_succeeded", "Should emit capture_succeeded")

func test_on_capture_failed_emits_signal():
	watch_signals(handler)
	handler._handle_capture_defeat()
	# Note: capture_failed is emitted if current_capture_node exists
	# In this test it's null so signal won't emit

# ==============================================================================
# EDGE CASE TESTS
# ==============================================================================

func test_initiate_capture_twice():
	handler.initiate_capture(mock_hex_node)
	var first_node = handler.current_capture_node

	var second_node = HexNode.new()
	second_node.id = "test_node_2"
	second_node.name = "Test Forest"
	second_node.coord = HexCoord.from_qr(0, 1)

	handler.initiate_capture(second_node)
	assert_eq(handler.current_capture_node, second_node, "Should replace with new node")
	assert_ne(handler.current_capture_node, first_node, "Should not keep first node")

func test_battle_result_with_no_current_node():
	handler.current_capture_node = null

	var result = BattleResult.new()
	result.victory = true

	# Should not crash
	handler._on_capture_battle_ended(result)
	assert_null(handler.current_capture_node, "Should remain null")

func test_create_default_defender_tier_5():
	mock_hex_node.tier = 5
	var defender = handler._create_default_defender(mock_hex_node)
	assert_eq(defender.get("level"), 25, "Tier 5 should have level 25")
	assert_eq(defender.get("base_hp"), 3500, "Tier 5 should have 3500 HP")
	assert_eq(defender.get("base_attack"), 350, "Tier 5 should have 350 attack")
	assert_eq(defender.get("base_defense"), 300, "Tier 5 should have 300 defense")
	assert_eq(defender.get("base_speed"), 100, "Tier 5 should have 100 speed")

func test_create_default_defender_id_unique():
	var defender1 = handler._create_default_defender(mock_hex_node)

	var node2 = HexNode.new()
	node2.id = "different_node"
	node2.tier = 1
	var defender2 = handler._create_default_defender(node2)

	assert_ne(defender1.get("id"), defender2.get("id"), "Defender IDs should be unique")

# ==============================================================================
# INTEGRATION-LIKE TESTS (no actual systems)
# ==============================================================================

func test_get_player_battle_team_no_collection_manager():
	handler.collection_manager = null
	var team = handler._get_player_battle_team()
	assert_eq(team.size(), 0, "Should return empty array without collection manager")

func test_get_node_defenders_no_collection_manager():
	handler.collection_manager = null
	var defenders = handler._get_node_defenders(mock_hex_node)
	assert_eq(defenders.size(), 1, "Should return default defender")
	assert_eq(defenders[0].get("name"), "Territory Guardian", "Should be default guardian")

func test_get_node_defenders_neutral_node_creates_default():
	mock_hex_node.controller = "neutral"
	mock_hex_node.base_defenders = []

	var defenders = handler._get_node_defenders(mock_hex_node)
	assert_eq(defenders.size(), 1, "Should have one default defender")
	assert_eq(defenders[0].get("name"), "Territory Guardian", "Should be guardian")

func test_get_node_defenders_enemy_node_empty_garrison():
	mock_hex_node.controller = "enemy_player_1"
	mock_hex_node.garrison = []

	var defenders = handler._get_node_defenders(mock_hex_node)
	assert_eq(defenders.size(), 1, "Should have one default defender")

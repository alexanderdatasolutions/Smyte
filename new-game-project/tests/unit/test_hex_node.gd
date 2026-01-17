# tests/unit/test_hex_node.gd
extends RefCounted

var runner = null

func set_runner(test_runner):
	runner = test_runner

# ==============================================================================
# BASIC CREATION & INITIALIZATION
# ==============================================================================

func test_creates_empty_hex_node():
	var node = HexNode.new()
	runner.assert_not_null(node, "Should create HexNode instance")
	runner.assert_equal(node.id, "", "Default id should be empty")
	runner.assert_equal(node.name, "", "Default name should be empty")
	runner.assert_equal(node.tier, 1, "Default tier should be 1")
	runner.assert_equal(node.controller, "neutral", "Default controller should be neutral")

func test_creates_hex_node_with_properties():
	var node = HexNode.new()
	node.id = "mine_copper_1"
	node.name = "Copper Vein"
	node.node_type = "mine"
	node.tier = 2
	node.coord = HexCoord.new(1, 0)

	runner.assert_equal(node.id, "mine_copper_1", "ID should be set")
	runner.assert_equal(node.name, "Copper Vein", "Name should be set")
	runner.assert_equal(node.node_type, "mine", "Node type should be mine")
	runner.assert_equal(node.tier, 2, "Tier should be 2")
	runner.assert_true(node.coord.equals(HexCoord.new(1, 0)), "Coord should be (1, 0)")

# ==============================================================================
# OWNERSHIP CHECKS
# ==============================================================================

func test_is_controlled_by_player():
	var node = HexNode.new()
	node.controller = "player"
	runner.assert_true(node.is_controlled_by_player(), "Should be player controlled")

func test_is_not_controlled_by_player():
	var node = HexNode.new()
	node.controller = "neutral"
	runner.assert_false(node.is_controlled_by_player(), "Should not be player controlled")

func test_is_neutral():
	var node = HexNode.new()
	node.controller = "neutral"
	runner.assert_true(node.is_neutral(), "Should be neutral")

func test_is_not_neutral():
	var node = HexNode.new()
	node.controller = "player"
	runner.assert_false(node.is_neutral(), "Should not be neutral")

func test_is_enemy_controlled():
	var node = HexNode.new()
	node.controller = "enemy_player123"
	runner.assert_true(node.is_enemy_controlled(), "Should be enemy controlled")

func test_is_not_enemy_controlled():
	var node = HexNode.new()
	node.controller = "player"
	runner.assert_false(node.is_enemy_controlled(), "Should not be enemy controlled")

# ==============================================================================
# GARRISON MANAGEMENT
# ==============================================================================

func test_get_garrison_count_empty():
	var node = HexNode.new()
	runner.assert_equal(node.get_garrison_count(), 0, "Empty garrison should have count 0")

func test_get_garrison_count_with_gods():
	var node = HexNode.new()
	node.garrison = ["god1", "god2", "god3"]
	runner.assert_equal(node.get_garrison_count(), 3, "Garrison should have count 3")

func test_has_garrison_space_when_empty():
	var node = HexNode.new()
	node.max_garrison = 2
	runner.assert_true(node.has_garrison_space(), "Should have garrison space when empty")

func test_has_garrison_space_when_partial():
	var node = HexNode.new()
	node.max_garrison = 3
	node.garrison = ["god1"]
	runner.assert_true(node.has_garrison_space(), "Should have garrison space when partial")

func test_has_no_garrison_space_when_full():
	var node = HexNode.new()
	node.max_garrison = 2
	node.garrison = ["god1", "god2"]
	runner.assert_false(node.has_garrison_space(), "Should not have garrison space when full")

func test_get_garrison_combat_power_empty():
	var node = HexNode.new()
	var empty_gods: Array = []
	var power = node.get_garrison_combat_power(empty_gods)
	runner.assert_equal(power, 0, "Empty garrison should have 0 combat power")

func test_get_garrison_combat_power_with_gods():
	var node = HexNode.new()

	# Create mock gods with known stats
	var god1 = God.new()
	god1.id = "test_god_1"
	god1.base_hp = 100
	god1.base_attack = 50
	god1.base_defense = 30
	god1.base_speed = 20
	god1.level = 1

	var god2 = God.new()
	god2.id = "test_god_2"
	god2.base_hp = 200
	god2.base_attack = 100
	god2.base_defense = 60
	god2.base_speed = 40
	god2.level = 1

	# At level 1, power = base stats (HP + ATK + DEF + SPD)
	# god1 = 100 + 50 + 30 + 20 = 200
	# god2 = 200 + 100 + 60 + 40 = 400
	# Total = 600
	var gods: Array = [god1, god2]
	var power = node.get_garrison_combat_power(gods)
	runner.assert_equal(power, 600, "Combat power should be sum of god stats")

func test_get_garrison_combat_power_ignores_null():
	var node = HexNode.new()
	var god1 = God.new()
	god1.base_hp = 100
	god1.base_attack = 50
	god1.base_defense = 30
	god1.base_speed = 20
	god1.level = 1

	# Include null in array - should be ignored
	var gods: Array = [null, god1, null]
	var power = node.get_garrison_combat_power(gods)
	runner.assert_equal(power, 200, "Should ignore null entries and only count valid god")

# ==============================================================================
# WORKER MANAGEMENT
# ==============================================================================

func test_get_worker_count_empty():
	var node = HexNode.new()
	runner.assert_equal(node.get_worker_count(), 0, "Empty workers should have count 0")

func test_get_worker_count_with_gods():
	var node = HexNode.new()
	node.assigned_workers = ["god1", "god2"]
	runner.assert_equal(node.get_worker_count(), 2, "Workers should have count 2")

func test_has_worker_space_when_empty():
	var node = HexNode.new()
	node.max_workers = 3
	runner.assert_true(node.has_worker_space(), "Should have worker space when empty")

func test_has_worker_space_when_partial():
	var node = HexNode.new()
	node.max_workers = 3
	node.assigned_workers = ["god1", "god2"]
	runner.assert_true(node.has_worker_space(), "Should have worker space when partial")

func test_has_no_worker_space_when_full():
	var node = HexNode.new()
	node.max_workers = 3
	node.assigned_workers = ["god1", "god2", "god3"]
	runner.assert_false(node.has_worker_space(), "Should not have worker space when full")

# ==============================================================================
# DISPLAY METHODS
# ==============================================================================

func test_get_display_name_tier_1():
	var node = HexNode.new()
	node.name = "Forest Grove"
	node.tier = 1
	runner.assert_equal(node.get_display_name(), "Forest Grove ★", "Tier 1 should have 1 star")

func test_get_display_name_tier_3():
	var node = HexNode.new()
	node.name = "Dragon's Lair"
	node.tier = 3
	runner.assert_equal(node.get_display_name(), "Dragon's Lair ★★★", "Tier 3 should have 3 stars")

func test_get_display_name_tier_5():
	var node = HexNode.new()
	node.name = "Olympus Gate"
	node.tier = 5
	runner.assert_equal(node.get_display_name(), "Olympus Gate ★★★★★", "Tier 5 should have 5 stars")

func test_get_node_type_display_mine():
	var node = HexNode.new()
	node.node_type = "mine"
	runner.assert_equal(node.get_node_type_display(), "Mine", "Should display Mine")

func test_get_node_type_display_forest():
	var node = HexNode.new()
	node.node_type = "forest"
	runner.assert_equal(node.get_node_type_display(), "Forest", "Should display Forest")

func test_get_node_type_display_hunting_ground():
	var node = HexNode.new()
	node.node_type = "hunting_ground"
	runner.assert_equal(node.get_node_type_display(), "Hunting Ground", "Should display Hunting Ground")

func test_get_node_type_display_unknown():
	var node = HexNode.new()
	node.node_type = "invalid_type"
	runner.assert_equal(node.get_node_type_display(), "Unknown", "Should display Unknown for invalid type")

# ==============================================================================
# UNLOCK REQUIREMENTS
# ==============================================================================

func test_get_required_spec_tier_default():
	var node = HexNode.new()
	runner.assert_equal(node.get_required_spec_tier(), 0, "Default spec tier should be 0")

func test_get_required_spec_tier_custom():
	var node = HexNode.new()
	node.unlock_requirements = {
		"player_level": 20,
		"specialization_tier": 2,
		"specialization_role": "gatherer"
	}
	runner.assert_equal(node.get_required_spec_tier(), 2, "Should return spec tier 2")

func test_get_required_spec_role_empty():
	var node = HexNode.new()
	runner.assert_equal(node.get_required_spec_role(), "", "Default spec role should be empty")

func test_get_required_spec_role_custom():
	var node = HexNode.new()
	node.unlock_requirements = {
		"player_level": 30,
		"specialization_tier": 2,
		"specialization_role": "crafter"
	}
	runner.assert_equal(node.get_required_spec_role(), "crafter", "Should return crafter role")

func test_get_required_level_default():
	var node = HexNode.new()
	runner.assert_equal(node.get_required_level(), 1, "Default required level should be 1")

func test_get_required_level_custom():
	var node = HexNode.new()
	node.unlock_requirements = {
		"player_level": 25,
		"specialization_tier": 1,
		"specialization_role": ""
	}
	runner.assert_equal(node.get_required_level(), 25, "Should return level 25")

# ==============================================================================
# SERIALIZATION - TO_DICT
# ==============================================================================

func test_to_dict_basic():
	var node = HexNode.new()
	node.id = "test_node"
	node.name = "Test Node"
	node.node_type = "mine"
	node.tier = 2
	node.coord = HexCoord.new(1, 1)

	var dict = node.to_dict()
	runner.assert_equal(dict["id"], "test_node", "ID should serialize")
	runner.assert_equal(dict["name"], "Test Node", "Name should serialize")
	runner.assert_equal(dict["node_type"], "mine", "Node type should serialize")
	runner.assert_equal(dict["tier"], 2, "Tier should serialize")
	runner.assert_equal(dict["coord"]["q"], 1, "Coord q should serialize")
	runner.assert_equal(dict["coord"]["r"], 1, "Coord r should serialize")

func test_to_dict_with_garrison():
	var node = HexNode.new()
	node.garrison = ["god1", "god2"]
	node.max_garrison = 3

	var dict = node.to_dict()
	runner.assert_equal(dict["garrison"].size(), 2, "Garrison should serialize")
	runner.assert_equal(dict["max_garrison"], 3, "Max garrison should serialize")

func test_to_dict_with_workers():
	var node = HexNode.new()
	node.assigned_workers = ["god3", "god4"]
	node.active_tasks = ["task1"]

	var dict = node.to_dict()
	runner.assert_equal(dict["assigned_workers"].size(), 2, "Workers should serialize")
	runner.assert_equal(dict["active_tasks"].size(), 1, "Active tasks should serialize")

func test_to_dict_with_production():
	var node = HexNode.new()
	node.base_production = {"copper_ore": 50, "stone": 30}
	node.production_level = 3

	var dict = node.to_dict()
	runner.assert_equal(dict["base_production"]["copper_ore"], 50, "Production should serialize")
	runner.assert_equal(dict["production_level"], 3, "Production level should serialize")

# ==============================================================================
# SERIALIZATION - FROM_DICT
# ==============================================================================

func test_from_dict_basic():
	var data = {
		"id": "forest_1",
		"name": "Ancient Forest",
		"node_type": "forest",
		"tier": 3,
		"coord": {"q": -1, "r": 1}
	}

	var node = HexNode.from_dict(data)
	runner.assert_equal(node.id, "forest_1", "ID should deserialize")
	runner.assert_equal(node.name, "Ancient Forest", "Name should deserialize")
	runner.assert_equal(node.node_type, "forest", "Node type should deserialize")
	runner.assert_equal(node.tier, 3, "Tier should deserialize")
	runner.assert_equal(node.coord.q, -1, "Coord q should deserialize")
	runner.assert_equal(node.coord.r, 1, "Coord r should deserialize")

func test_from_dict_with_controller():
	var data = {
		"id": "node1",
		"controller": "player",
		"is_revealed": true,
		"is_contested": false
	}

	var node = HexNode.from_dict(data)
	runner.assert_equal(node.controller, "player", "Controller should deserialize")
	runner.assert_true(node.is_revealed, "Is revealed should deserialize")
	runner.assert_false(node.is_contested, "Is contested should deserialize")

func test_from_dict_with_garrison():
	var data = {
		"id": "node2",
		"garrison": ["god1", "god2", "god3"],
		"max_garrison": 5,
		"base_defenders": ["enemy1"]
	}

	var node = HexNode.from_dict(data)
	runner.assert_equal(node.garrison.size(), 3, "Garrison should deserialize")
	runner.assert_equal(node.max_garrison, 5, "Max garrison should deserialize")
	runner.assert_equal(node.base_defenders.size(), 1, "Base defenders should deserialize")

func test_from_dict_with_workers():
	var data = {
		"id": "node3",
		"assigned_workers": ["worker1", "worker2"],
		"max_workers": 4,
		"active_tasks": ["mining", "logging"],
		"available_tasks": ["mining", "logging", "foraging"]
	}

	var node = HexNode.from_dict(data)
	runner.assert_equal(node.assigned_workers.size(), 2, "Workers should deserialize")
	runner.assert_equal(node.max_workers, 4, "Max workers should deserialize")
	runner.assert_equal(node.active_tasks.size(), 2, "Active tasks should deserialize")
	runner.assert_equal(node.available_tasks.size(), 3, "Available tasks should deserialize")

func test_from_dict_with_production():
	var data = {
		"id": "node4",
		"base_production": {"wood": 100, "herbs": 30},
		"production_level": 2,
		"defense_level": 3
	}

	var node = HexNode.from_dict(data)
	runner.assert_equal(node.base_production["wood"], 100, "Production should deserialize")
	runner.assert_equal(node.production_level, 2, "Production level should deserialize")
	runner.assert_equal(node.defense_level, 3, "Defense level should deserialize")

func test_from_dict_with_unlock_requirements():
	var data = {
		"id": "node5",
		"unlock_requirements": {
			"player_level": 30,
			"specialization_tier": 2,
			"specialization_role": "gatherer"
		}
	}

	var node = HexNode.from_dict(data)
	runner.assert_equal(node.unlock_requirements["player_level"], 30, "Player level req should deserialize")
	runner.assert_equal(node.unlock_requirements["specialization_tier"], 2, "Spec tier req should deserialize")
	runner.assert_equal(node.unlock_requirements["specialization_role"], "gatherer", "Spec role req should deserialize")

func test_from_dict_with_missing_fields():
	var data = {
		"id": "minimal_node"
	}

	var node = HexNode.from_dict(data)
	runner.assert_equal(node.id, "minimal_node", "Should use provided id")
	runner.assert_equal(node.name, "", "Should use default name")
	runner.assert_equal(node.tier, 1, "Should use default tier")
	runner.assert_equal(node.controller, "neutral", "Should use default controller")
	runner.assert_equal(node.max_garrison, 2, "Should use default max garrison")

# ==============================================================================
# ROUNDTRIP SERIALIZATION
# ==============================================================================

func test_roundtrip_serialization():
	var original = HexNode.new()
	original.id = "roundtrip_node"
	original.name = "Roundtrip Test"
	original.node_type = "forge"
	original.tier = 4
	original.coord = HexCoord.new(3, -2)
	original.controller = "player"
	original.garrison = ["god1", "god2"]
	original.assigned_workers = ["god3"]
	original.base_production = {"steel": 75}
	original.production_level = 4
	original.unlock_requirements = {
		"player_level": 40,
		"specialization_tier": 3,
		"specialization_role": "crafter"
	}

	var dict = original.to_dict()
	var restored = HexNode.from_dict(dict)

	runner.assert_equal(restored.id, original.id, "ID should roundtrip")
	runner.assert_equal(restored.name, original.name, "Name should roundtrip")
	runner.assert_equal(restored.node_type, original.node_type, "Node type should roundtrip")
	runner.assert_equal(restored.tier, original.tier, "Tier should roundtrip")
	runner.assert_equal(restored.coord.q, original.coord.q, "Coord q should roundtrip")
	runner.assert_equal(restored.coord.r, original.coord.r, "Coord r should roundtrip")
	runner.assert_equal(restored.controller, original.controller, "Controller should roundtrip")
	runner.assert_equal(restored.garrison.size(), original.garrison.size(), "Garrison should roundtrip")
	runner.assert_equal(restored.assigned_workers.size(), original.assigned_workers.size(), "Workers should roundtrip")
	runner.assert_equal(restored.production_level, original.production_level, "Production level should roundtrip")

# ==============================================================================
# EDGE CASES
# ==============================================================================

func test_handles_null_coord():
	var node = HexNode.new()
	node.coord = null
	var dict = node.to_dict()
	runner.assert_equal(dict["coord"]["q"], 0, "Null coord should serialize as (0,0)")

func test_handles_empty_production():
	var node = HexNode.new()
	node.base_production = {}
	var dict = node.to_dict()
	runner.assert_equal(dict["base_production"].size(), 0, "Empty production should serialize")

func test_handles_large_garrison():
	var node = HexNode.new()
	node.max_garrison = 100
	for i in range(100):
		node.garrison.append("god_%d" % i)
	runner.assert_equal(node.get_garrison_count(), 100, "Should handle large garrison")
	runner.assert_false(node.has_garrison_space(), "Should be full with 100 gods")

func test_handles_contested_node():
	var node = HexNode.new()
	node.is_contested = true
	node.contested_until = 1234567890
	runner.assert_true(node.is_contested, "Should be contested")
	runner.assert_equal(node.contested_until, 1234567890, "Should have contest timestamp")

func test_handles_all_node_types():
	var types = ["mine", "forest", "coast", "hunting_ground", "forge", "library", "temple", "fortress"]
	for node_type in types:
		var node = HexNode.new()
		node.node_type = node_type
		runner.assert_true(node.get_node_type_display().length() > 0, "Should have display name for %s" % node_type)

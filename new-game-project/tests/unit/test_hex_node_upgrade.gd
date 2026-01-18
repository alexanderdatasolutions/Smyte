extends GutTest
# Test hex node production_level upgrade functionality

var territory_manager
var hex_grid_manager
var resource_manager

func before_each():
	# Get managers from SystemRegistry
	territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	hex_grid_manager = SystemRegistry.get_instance().get_system("HexGridManager")
	resource_manager = SystemRegistry.get_instance().get_system("ResourceManager")

func test_upgrade_hex_node_success():
	# Get the divine sanctum node
	var node = hex_grid_manager.get_node_by_id("divine_sanctum")
	assert_not_null(node, "divine_sanctum node should exist")

	var initial_level = node.production_level
	print("Initial production_level: ", initial_level)

	# Ensure we have enough resources
	resource_manager.add_resource("gold", 10000)
	resource_manager.add_resource("mana", 10000)

	var initial_gold = resource_manager.get_resource_amount("gold")
	var initial_mana = resource_manager.get_resource_amount("mana")

	# Attempt to upgrade
	var success = territory_manager.upgrade_hex_node("divine_sanctum")

	assert_true(success, "Upgrade should succeed with sufficient resources")
	assert_eq(node.production_level, initial_level + 1, "production_level should increase by 1")

	# Verify resources were spent
	var final_gold = resource_manager.get_resource_amount("gold")
	var final_mana = resource_manager.get_resource_amount("mana")

	assert_lt(final_gold, initial_gold, "Gold should be spent")
	assert_lt(final_mana, initial_mana, "Mana should be spent")

	print("Upgrade successful: Level ", initial_level, " -> ", node.production_level)

func test_upgrade_hex_node_insufficient_resources():
	# Get a node
	var node = hex_grid_manager.get_node_by_id("divine_sanctum")
	assert_not_null(node, "divine_sanctum node should exist")

	var initial_level = node.production_level

	# Clear resources
	resource_manager.add_resource("gold", -resource_manager.get_resource_amount("gold"))
	resource_manager.add_resource("mana", -resource_manager.get_resource_amount("mana"))

	# Attempt to upgrade (should fail)
	var success = territory_manager.upgrade_hex_node("divine_sanctum")

	assert_false(success, "Upgrade should fail with insufficient resources")
	assert_eq(node.production_level, initial_level, "production_level should not change")

func test_upgrade_hex_node_max_level():
	# Get node
	var node = hex_grid_manager.get_node_by_id("divine_sanctum")
	assert_not_null(node, "divine_sanctum node should exist")

	# Set to max level
	node.production_level = 5

	# Add resources
	resource_manager.add_resource("gold", 100000)
	resource_manager.add_resource("mana", 100000)

	# Attempt to upgrade (should fail)
	var success = territory_manager.upgrade_hex_node("divine_sanctum")

	assert_false(success, "Upgrade should fail when at max level")
	assert_eq(node.production_level, 5, "production_level should remain at max")

func test_upgrade_emits_signal():
	# Get node and production manager
	var node = hex_grid_manager.get_node_by_id("divine_sanctum")
	var production_manager = SystemRegistry.get_instance().get_system("TerritoryProductionManager")

	# Add resources
	resource_manager.add_resource("gold", 10000)
	resource_manager.add_resource("mana", 10000)

	# Watch for signal
	watch_signals(production_manager)

	# Upgrade
	territory_manager.upgrade_hex_node("divine_sanctum")

	# Verify signal was emitted
	assert_signal_emitted(production_manager, "production_updated")

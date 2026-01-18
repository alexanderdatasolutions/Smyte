extends Node

func _ready():
	print("=== Testing upgrade_hex_node ===")
	
	# Get managers
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	var hex_grid_manager = SystemRegistry.get_instance().get_system("HexGridManager")
	var resource_manager = SystemRegistry.get_instance().get_system("ResourceManager")
	
	if not territory_manager or not hex_grid_manager or not resource_manager:
		print("ERROR: Managers not found")
		return
	
	# Get the divine sanctum node
	var node = hex_grid_manager.get_node_by_id("divine_sanctum")
	if not node:
		print("ERROR: divine_sanctum node not found")
		return
	
	print("Before upgrade:")
	print("  production_level: ", node.production_level)
	print("  Resources: mana=", resource_manager.get_resource_amount("mana"), " gold=", resource_manager.get_resource_amount("gold"))
	
	# Attempt to upgrade
	var success = territory_manager.upgrade_hex_node("divine_sanctum")
	
	print("\nUpgrade result: ", success)
	print("After upgrade:")
	print("  production_level: ", node.production_level)
	print("  Resources: mana=", resource_manager.get_resource_amount("mana"), " gold=", resource_manager.get_resource_amount("gold"))
	
	print("\n=== Test complete ===")
	
	# Clean up
	queue_free()

# tests/integration/TestBootstrap.gd
# Bootstraps the game environment for integration testing
extends Node

signal game_ready

func _ready():
	# Wait for GameCoordinator to initialize
	await get_tree().process_frame
	await get_tree().process_frame

	# Give systems time to register
	await get_tree().create_timer(0.5).timeout

	# Verify core systems are loaded
	var registry = SystemRegistry.get_instance()
	var required_systems = [
		"CollectionManager",
		"ResourceManager",
		"EquipmentManager",
		"SpecializationManager",
		"RoleManager",
		"PlayerProgressionManager",
		"TerritoryManager",
		"DungeonCoordinator"
	]

	var all_loaded = true
	for system_name in required_systems:
		var system = registry.get_system(system_name)
		if not system:
			push_error("TestBootstrap: Missing system: " + system_name)
			all_loaded = false
		else:
			print("TestBootstrap: ✓ " + system_name + " loaded")

	if all_loaded:
		print("TestBootstrap: All systems ready for testing")
		game_ready.emit()
	else:
		push_error("TestBootstrap: Not all systems loaded - tests may fail")
		get_tree().quit(1)

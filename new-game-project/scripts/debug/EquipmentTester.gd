extends Node

# Equipment testing and debugging script
# This script can be added to the scene tree to test equipment operations
# Set enabled = true to run tests on startup and see debug output

signal test_completed(test_name: String, success: bool, details: String)

## Set to true to enable debug output and automatic testing
@export var enabled: bool = false

var equipment_manager
var collection_manager

# Helper to get SystemRegistry without parse-time dependency
func _get_system_registry():
	var registry_script = load("res://scripts/systems/core/SystemRegistry.gd")
	if registry_script and registry_script.has_method("get_instance"):
		return registry_script.get_instance()
	return null

func _ready():
	if not enabled:
		return

	_debug_print("=== EquipmentTester: Initializing ===")

	# Get managers from SystemRegistry using late binding
	var system_registry = _get_system_registry()
	if system_registry:
		equipment_manager = system_registry.get_system("EquipmentManager")
		collection_manager = system_registry.get_system("CollectionManager")
		_debug_print("EquipmentTester: Got managers from SystemRegistry")
	else:
		push_warning("EquipmentTester: SystemRegistry not found!")
		return

	# Small delay then run tests
	await get_tree().create_timer(1.0).timeout
	run_equipment_tests()


func _debug_print(message: String) -> void:
	if enabled:
		print(message)

func run_equipment_tests():
	_debug_print("\n=== EQUIPMENT FUNCTIONALITY TESTS ===")

	# Test 1: Check available equipment
	test_available_equipment()

	# Test 2: Check gods in collection
	test_gods_in_collection()

	# Test 3: Try equipment operations
	test_equipment_operations()

func test_available_equipment():
	_debug_print("\n--- TEST 1: Available Equipment ---")

	if not equipment_manager:
		_debug_print("ERROR: Equipment manager not available")
		return

	var inventory_manager = equipment_manager.inventory_manager
	if not inventory_manager:
		_debug_print("ERROR: Inventory manager not available")
		return

	var equipment_list = inventory_manager.get_all_equipment()
	_debug_print("Available equipment count: %d" % equipment_list.size())

	for equipment in equipment_list:
		_debug_print("- Equipment: %s (%s) - Slot: %s" % [equipment.name, equipment.id, equipment.slot])

func test_gods_in_collection():
	_debug_print("\n--- TEST 2: Gods in Collection ---")

	if not collection_manager:
		_debug_print("ERROR: Collection manager not available")
		return

	var gods_list = collection_manager.get_all_gods()
	_debug_print("Gods in collection count: %d" % gods_list.size())

	for god in gods_list:
		_debug_print("- God: %s (%s)" % [god.name, god.id])

		# Check current equipment
		var current_equipment = collection_manager.get_god_equipment(god.id)
		if current_equipment.size() > 0:
			_debug_print("  Current equipment:")
			var equipment_class = load("res://scripts/data/Equipment.gd")
			for i in range(current_equipment.size()):
				var eq = current_equipment[i]
				if eq and is_instance_of(eq, equipment_class):
					_debug_print("    Slot %d: %s" % [i, eq.name])
				elif eq == null:
					_debug_print("    Slot %d: Empty" % i)
				else:
					_debug_print("    Slot %d: Invalid equipment type (%s)" % [i, str(type_string(typeof(eq)))])
		else:
			_debug_print("  No equipment currently equipped")

func test_equipment_operations():
	_debug_print("\n--- TEST 3: Equipment Operations ---")

	if not equipment_manager or not collection_manager:
		_debug_print("ERROR: Required managers not available")
		return

	var gods_list = collection_manager.get_all_gods()
	var equipment_list = equipment_manager.inventory_manager.get_all_equipment()

	if gods_list.size() == 0:
		_debug_print("ERROR: No gods available for testing")
		return

	if equipment_list.size() == 0:
		_debug_print("ERROR: No equipment available for testing")
		return

	# Test with first god and first equipment
	var test_god = gods_list[0]
	var test_equipment = equipment_list[0]

	_debug_print("Testing equipment operation:")
	_debug_print("- God: %s (%s)" % [test_god.name, test_god.id])
	_debug_print("- Equipment: %s (%s) - Slot: %s" % [test_equipment.name, test_equipment.id, test_equipment.slot])

	# Try to equip
	_debug_print("\nAttempting to equip...")
	try_equip_operation(test_god.id, test_equipment.id)

func try_equip_operation(god_id: String, equipment_id: String):
	_debug_print("=== EQUIP OPERATION DEBUG ===")

	# Check if equipment manager has equip_to_god method
	if equipment_manager.has_method("equip_to_god"):
		_debug_print("Using equipment_manager.equip_to_god()")
		var result = equipment_manager.equip_to_god(god_id, equipment_id)
		_debug_print("Equip result: %s" % str(result))

	elif equipment_manager.has_method("equip_equipment"):
		_debug_print("Using equipment_manager.equip_equipment()")
		var result = equipment_manager.equip_equipment(god_id, equipment_id)
		_debug_print("Equip result: %s" % str(result))

	else:
		_debug_print("Checking available methods on equipment_manager:")
		var methods = []
		# Try common equipment method names
		var test_methods = ["equip", "equip_item", "assign_equipment", "add_equipment", "set_equipment"]
		for method_name in test_methods:
			if equipment_manager.has_method(method_name):
				methods.append(method_name)

		_debug_print("Available methods: %s" % str(methods))

		# Check inventory manager methods
		if equipment_manager.inventory_manager:
			_debug_print("Checking inventory_manager methods...")
			var inventory_methods = []
			for method_name in test_methods:
				if equipment_manager.inventory_manager.has_method(method_name):
					inventory_methods.append(method_name)
			_debug_print("Inventory manager methods: %s" % str(inventory_methods))

		# Check collection manager methods
		if collection_manager:
			_debug_print("Checking collection_manager methods...")
			var collection_methods = []
			var collection_test_methods = ["equip_to_god", "set_god_equipment", "assign_equipment", "equip_equipment"]
			for method_name in collection_test_methods:
				if collection_manager.has_method(method_name):
					collection_methods.append(method_name)
			_debug_print("Collection manager methods: %s" % str(collection_methods))


# Function to manually trigger tests from console or other scripts
func manual_test_equip(god_id: String, equipment_id: String):
	_debug_print("\n=== MANUAL EQUIP TEST ===")
	try_equip_operation(god_id, equipment_id)


# Helper function to get current game state
func get_current_state():
	_debug_print("\n=== CURRENT GAME STATE ===")
	test_available_equipment()
	test_gods_in_collection()

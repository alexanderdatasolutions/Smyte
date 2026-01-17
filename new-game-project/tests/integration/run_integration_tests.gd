# tests/integration/run_integration_tests.gd
# Integration test runner - Executes all integration test suites
extends Node

var test_results = {
	"passed": 0,
	"failed": 0,
	"errors": []
}

# Test suites to run
var test_files = [
	"res://tests/integration/test_specialization_flow.gd",
	"res://tests/integration/test_summon_to_battle_flow.gd",
	"res://tests/integration/test_territory_capture_flow.gd",
	"res://tests/integration/test_dungeon_progression_flow.gd",
	"res://tests/integration/test_awakening_and_sacrifice_flow.gd",
	"res://tests/integration/test_shop_and_mtx_flow.gd",
	"res://tests/integration/test_player_progression_and_unlocks.gd",
	"res://tests/integration/test_full_game_loop.gd"
]

func _ready():
	print("==============================================")
	print("INTEGRATION TEST SUITE")
	print("==============================================")
	print("")

	for test_file in test_files:
		run_test_file(test_file)

	print_results()

func run_test_file(file_path: String):
	print("Running: " + file_path.get_file().get_basename())
	print("----------------------------------------------")

	var test_script = load(file_path)
	if not test_script:
		test_results["failed"] += 1
		test_results["errors"].append("Failed to load: " + file_path)
		print("  ERROR: Failed to load test file")
		return

	var test_instance = test_script.new()
	test_instance.set_runner(self)

	# Get all test methods
	var methods = []
	for method in test_instance.get_method_list():
		if method.name.begins_with("test_"):
			methods.append(method.name)

	if methods.size() == 0:
		print("  WARNING: No test methods found")
		return

	# Run each test method
	for method_name in methods:
		run_test_method(test_instance, method_name)

	print("")

func run_test_method(test_instance, method_name: String):
	print("  • " + method_name.replace("test_", "").replace("_", " ").capitalize())

	var error = null
	# Try to call the method
	if test_instance.has_method(method_name):
		test_instance.call(method_name)
	else:
		error = "Method not found: " + method_name

	if error:
		test_results["failed"] += 1
		test_results["errors"].append(method_name + ": " + error)
		print("    FAILED: " + error)
	else:
		print("    PASSED")

func assert_true(condition: bool, message: String):
	if not condition:
		test_results["failed"] += 1
		test_results["errors"].append(message)
		push_error("Assertion failed: " + message)
	else:
		test_results["passed"] += 1

func assert_false(condition: bool, message: String):
	assert_true(not condition, message)

func assert_equal(actual, expected, message: String):
	if actual != expected:
		var error_msg = message + " (Expected: " + str(expected) + ", Got: " + str(actual) + ")"
		test_results["failed"] += 1
		test_results["errors"].append(error_msg)
		push_error("Assertion failed: " + error_msg)
	else:
		test_results["passed"] += 1

func assert_not_equal(actual, unexpected, message: String):
	if actual == unexpected:
		var error_msg = message + " (Should not be: " + str(unexpected) + ")"
		test_results["failed"] += 1
		test_results["errors"].append(error_msg)
		push_error("Assertion failed: " + error_msg)
	else:
		test_results["passed"] += 1

func assert_null(value, message: String):
	if value != null:
		test_results["failed"] += 1
		test_results["errors"].append(message + " (Expected null, got: " + str(value) + ")")
		push_error("Assertion failed: " + message)
	else:
		test_results["passed"] += 1

func assert_not_null(value, message: String):
	if value == null:
		test_results["failed"] += 1
		test_results["errors"].append(message + " (Value was null)")
		push_error("Assertion failed: " + message)
	else:
		test_results["passed"] += 1

func print_results():
	print("==============================================")
	print("TEST RESULTS")
	print("==============================================")
	print("")
	print("Passed: " + str(test_results["passed"]))
	print("Failed: " + str(test_results["failed"]))
	print("")

	if test_results["failed"] > 0:
		print("ERRORS:")
		for error in test_results["errors"]:
			print("  - " + error)
		print("")
		print("STATUS: FAILED")
	else:
		print("STATUS: ALL TESTS PASSED ✓")

	print("==============================================")

	# Exit with appropriate code
	if test_results["failed"] > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)

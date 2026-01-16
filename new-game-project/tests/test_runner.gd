# test_runner.gd - Simple test framework for Smyte unit tests
# Run with: godot --headless --script tests/test_runner.gd
extends SceneTree

var tests_passed := 0
var tests_failed := 0
var tests_skipped := 0
var test_results := []
var current_test_name := ""

# Test discovery paths
const TEST_PATHS := [
	"res://tests/data/",
	"res://tests/unit/",
	"res://tests/integration/"
]

func _init():
	print("\n" + "=".repeat(60))
	print("SMYTE UNIT TEST RUNNER")
	print("=".repeat(60) + "\n")

	run_all_tests()

	print_summary()

	# Exit with appropriate code
	if tests_failed > 0:
		quit(1)
	else:
		quit(0)

func run_all_tests():
	for test_path in TEST_PATHS:
		var dir = DirAccess.open(test_path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if file_name.begins_with("test_") and file_name.ends_with(".gd"):
					run_test_file(test_path + file_name)
				file_name = dir.get_next()
			dir.list_dir_end()

func run_test_file(file_path: String):
	print("\n--- Running: " + file_path + " ---\n")

	var test_script = load(file_path)
	if test_script == null:
		print("ERROR: Could not load " + file_path)
		return

	var test_instance = test_script.new()
	if test_instance == null:
		print("ERROR: Could not instantiate " + file_path)
		return

	# Give test instance access to runner
	if test_instance.has_method("set_runner"):
		test_instance.set_runner(self)

	# Run before_all if exists
	if test_instance.has_method("before_all"):
		test_instance.before_all()

	# Find and run all test methods
	var methods = test_instance.get_method_list()
	for method in methods:
		var method_name = method["name"]
		if method_name.begins_with("test_"):
			current_test_name = method_name

			# Run before_each if exists
			if test_instance.has_method("before_each"):
				test_instance.before_each()

			# Run the test
			var passed = true
			var error_msg = ""

			# Call test and catch any errors
			if test_instance.has_method(method_name):
				test_instance.call(method_name)

			# Run after_each if exists
			if test_instance.has_method("after_each"):
				test_instance.after_each()

	# Run after_all if exists
	if test_instance.has_method("after_all"):
		test_instance.after_all()

	# Clean up
	if test_instance is Node:
		test_instance.queue_free()

func assert_true(condition: bool, message: String = "") -> bool:
	if condition:
		tests_passed += 1
		print("  PASS: " + current_test_name + ((" - " + message) if message != "" else ""))
		return true
	else:
		tests_failed += 1
		var fail_msg = "  FAIL: " + current_test_name + ((" - " + message) if message != "" else "")
		print(fail_msg)
		test_results.append(fail_msg)
		return false

func assert_false(condition: bool, message: String = "") -> bool:
	return assert_true(not condition, message)

func assert_equal(actual, expected, message: String = "") -> bool:
	var condition = actual == expected
	var msg = message
	if not condition:
		msg = "%s - Expected '%s', got '%s'" % [message, str(expected), str(actual)]
	return assert_true(condition, msg)

func assert_not_equal(actual, expected, message: String = "") -> bool:
	var condition = actual != expected
	var msg = message
	if not condition:
		msg = "%s - Expected not '%s', but got '%s'" % [message, str(expected), str(actual)]
	return assert_true(condition, msg)

func assert_null(value, message: String = "") -> bool:
	return assert_true(value == null, message + " (expected null)")

func assert_not_null(value, message: String = "") -> bool:
	return assert_true(value != null, message + " (expected not null)")

func assert_greater_than(actual, expected, message: String = "") -> bool:
	var condition = actual > expected
	var msg = message
	if not condition:
		msg = "%s - Expected '%s' > '%s'" % [message, str(actual), str(expected)]
	return assert_true(condition, msg)

func assert_less_than(actual, expected, message: String = "") -> bool:
	var condition = actual < expected
	var msg = message
	if not condition:
		msg = "%s - Expected '%s' < '%s'" % [message, str(actual), str(expected)]
	return assert_true(condition, msg)

func assert_in_range(value, min_val, max_val, message: String = "") -> bool:
	var condition = value >= min_val and value <= max_val
	var msg = message
	if not condition:
		msg = "%s - Expected '%s' in range [%s, %s]" % [message, str(value), str(min_val), str(max_val)]
	return assert_true(condition, msg)

func assert_array_contains(array: Array, value, message: String = "") -> bool:
	return assert_true(array.has(value), message + " (array should contain " + str(value) + ")")

func assert_array_size(array: Array, expected_size: int, message: String = "") -> bool:
	return assert_equal(array.size(), expected_size, message + " (array size)")

func skip_test(reason: String = ""):
	tests_skipped += 1
	print("  SKIP: " + current_test_name + ((" - " + reason) if reason != "" else ""))

func print_summary():
	print("\n" + "=".repeat(60))
	print("TEST SUMMARY")
	print("=".repeat(60))
	print("Passed:  " + str(tests_passed))
	print("Failed:  " + str(tests_failed))
	print("Skipped: " + str(tests_skipped))
	print("Total:   " + str(tests_passed + tests_failed + tests_skipped))
	print("")

	if tests_failed > 0:
		print("FAILED TESTS:")
		for result in test_results:
			print("  " + result)
		print("")

	if tests_failed == 0:
		print("ALL TESTS PASSED!")
	else:
		print("SOME TESTS FAILED!")

	print("=".repeat(60) + "\n")

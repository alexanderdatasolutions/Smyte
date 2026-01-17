# tests/run_automated_test.gd
# Simple script to run automated battle flow test
# Attach this to a Node in a test scene, or run via command line
extends Node

func _ready():
	# Load and instantiate the test
	var test_script = load("res://tests/automated_battle_flow.gd")
	var test_instance = test_script.new()

	# Add to scene tree
	add_child(test_instance)

	print("Automated test started...")

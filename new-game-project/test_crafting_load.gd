extends Node

# Quick test script to verify crafting system loads correctly
# Run this in Godot editor to test resource/recipe loading

func _ready():
	print("=== CRAFTING SYSTEM LOAD TEST ===")

	# Test 1: Load resources.json
	print("\n1. Testing resources.json loading...")
	var resources_file = FileAccess.open("res://data/resources.json", FileAccess.READ)
	if resources_file:
		var json = JSON.new()
		if json.parse(resources_file.get_as_text()) == OK:
			var data = json.get_data()
			print("✓ Resources loaded successfully")
			print("  - Currencies: ", data.get("currencies", {}).keys().size())
			print("  - Tier 1 materials: ", data.get("crafting_materials_tier1", {}).keys().size())
			print("  - Tier 2-3 materials: ", data.get("crafting_materials_tier2_3", {}).keys().size())
			print("  - Tier 4-5 materials: ", data.get("crafting_materials_tier4_5", {}).keys().size())
			print("  - Enhancement materials: ", data.get("enhancement_materials", {}).keys().size())
			print("  - Gemstones: ", data.get("gemstones", {}).keys().size())
			print("  - Total unique materials: ", _count_all_resources(data))
		else:
			print("✗ Failed to parse resources.json")
		resources_file.close()
	else:
		print("✗ Could not open resources.json")

	# Test 2: Load crafting_recipes.json
	print("\n2. Testing crafting_recipes.json loading...")
	var recipes_file = FileAccess.open("res://data/crafting_recipes.json", FileAccess.READ)
	if recipes_file:
		var json = JSON.new()
		if json.parse(recipes_file.get_as_text()) == OK:
			var data = json.get_data()
			var recipes = data.get("recipes", {})
			print("✓ Recipes loaded successfully")
			print("  - Total recipes: ", recipes.keys().size())

			# Count by tier
			var tier1_count = 0
			var tier2_count = 0
			var tier3_count = 0

			for recipe_id in recipes:
				var recipe = recipes[recipe_id]
				var level = recipe.get("level", 1)
				if level < 20:
					tier1_count += 1
				elif level < 35:
					tier2_count += 1
				else:
					tier3_count += 1

			print("  - Tier 1 recipes (level 1-19): ", tier1_count)
			print("  - Tier 2 recipes (level 20-34): ", tier2_count)
			print("  - Tier 3 recipes (level 35+): ", tier3_count)

			# Show sample recipe
			if recipes.keys().size() > 0:
				var sample_id = recipes.keys()[0]
				var sample = recipes[sample_id]
				print("\n  Sample recipe: ", sample_id)
				print("    - Type: ", sample.get("equipment_type", "?"))
				print("    - Rarity: ", sample.get("rarity", "?"))
				print("    - Level: ", sample.get("level", "?"))
				print("    - Materials: ", sample.get("materials", {}).keys())
		else:
			print("✗ Failed to parse crafting_recipes.json")
		recipes_file.close()
	else:
		print("✗ Could not open crafting_recipes.json")

	# Test 3: Check ConfigurationManager integration
	print("\n3. Testing ConfigurationManager integration...")
	var config_manager = SystemRegistry.get_instance().get_system("ConfigurationManager")
	if config_manager:
		var resources_config = config_manager.get_resources_config()
		var recipes_config = config_manager.get_crafting_recipes_config()

		if not resources_config.is_empty():
			print("✓ Resources loaded through ConfigurationManager")
		else:
			print("✗ Resources NOT loaded through ConfigurationManager")

		if not recipes_config.is_empty():
			print("✓ Crafting recipes loaded through ConfigurationManager")
			print("  - Recipe count: ", recipes_config.get("recipes", {}).keys().size())
		else:
			print("✗ Crafting recipes NOT loaded through ConfigurationManager")
	else:
		print("✗ ConfigurationManager not available")

	# Test 4: Check EquipmentCraftingManager
	print("\n4. Testing EquipmentCraftingManager...")
	var crafting_manager = SystemRegistry.get_instance().get_system("EquipmentCraftingManager")
	if crafting_manager:
		var all_recipes = crafting_manager.get_all_recipes()
		print("✓ EquipmentCraftingManager found")
		print("  - Total recipes available: ", all_recipes.size())

		if all_recipes.size() > 0:
			# Test recipe details retrieval
			var test_recipe_id = all_recipes[0]
			var details = crafting_manager.get_recipe_details(test_recipe_id)
			if not details.is_empty():
				print("✓ Recipe details retrieval working")
			else:
				print("✗ Recipe details retrieval failed")
	else:
		print("✗ EquipmentCraftingManager not available")

	# Test 5: Check ResourceManager initialization
	print("\n5. Testing ResourceManager initialization...")
	var resource_manager = SystemRegistry.get_instance().get_system("ResourceManager")
	if resource_manager:
		# Initialize new game to test starting resources
		resource_manager.initialize_new_game()
		var gold = resource_manager.get_resource("gold")
		var energy = resource_manager.get_resource("energy")

		print("✓ ResourceManager found")
		print("  - Starting gold: ", gold, " (expected: 10000)")
		print("  - Starting energy: ", energy, " (expected: 100)")

		if gold == 10000 and energy == 100:
			print("✓ Starting resources correct")
		else:
			print("✗ Starting resources incorrect")
	else:
		print("✗ ResourceManager not available")

	print("\n=== TEST COMPLETE ===")
	print("If all tests show ✓, the crafting system is ready!")

func _count_all_resources(data: Dictionary) -> int:
	var count = 0
	for category in data:
		if data[category] is Dictionary:
			count += data[category].keys().size()
	return count

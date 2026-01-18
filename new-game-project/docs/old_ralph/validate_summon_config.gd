extends Node

# Temporary validation script for summon_config.json
# Run this to validate all rarity rates sum to 100%

func _ready():
	print("=== SUMMON CONFIG VALIDATION ===")
	validate_summon_config()

func validate_summon_config():
	var config_path = "res://data/summon_config.json"
	var file = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		print("ERROR: Could not open summon_config.json")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		print("ERROR: Failed to parse JSON: ", json.get_error_message())
		return

	var config = json.data
	if not config.has("summon_configuration"):
		print("ERROR: Missing summon_configuration section")
		return

	var summon_config = config["summon_configuration"]

	# Validate soul-based rates
	print("\n--- Soul-Based Rates ---")
	if summon_config.has("rates") and summon_config["rates"].has("soul_based_rates"):
		var soul_rates = summon_config["rates"]["soul_based_rates"]
		for soul_type in soul_rates.keys():
			var rates = soul_rates[soul_type]
			var total = 0.0
			for rarity in rates.keys():
				total += rates[rarity]
			var valid = abs(total - 100.0) < 0.01
			print("%s: %.2f%% %s" % [soul_type, total, "✓" if valid else "✗ INVALID"])

	# Validate element soul rates
	print("\n--- Element Soul Rates ---")
	if summon_config.has("rates") and summon_config["rates"].has("element_soul_rates"):
		var element_rates = summon_config["rates"]["element_soul_rates"]
		for element_type in element_rates.keys():
			var rates = element_rates[element_type]
			var total = 0.0
			for rarity in rates.keys():
				total += rates[rarity]
			var valid = abs(total - 100.0) < 0.01
			print("%s: %.2f%% %s" % [element_type, total, "✓" if valid else "✗ INVALID"])

	# Validate premium rates
	print("\n--- Premium Rates ---")
	if summon_config.has("rates") and summon_config["rates"].has("premium_rates"):
		var premium_rates = summon_config["rates"]["premium_rates"]
		for premium_type in premium_rates.keys():
			var rates = premium_rates[premium_type]
			var total = 0.0
			for rarity in rates.keys():
				total += rates[rarity]
			var valid = abs(total - 100.0) < 0.01
			print("%s: %.2f%% %s" % [premium_type, total, "✓" if valid else "✗ INVALID"])

	# Check tier distribution in gods.json
	print("\n--- God Tier Distribution ---")
	validate_god_tiers()

	print("\n=== VALIDATION COMPLETE ===")

func validate_god_tiers():
	var gods_path = "res://data/gods.json"
	var file = FileAccess.open(gods_path, FileAccess.READ)
	if not file:
		print("ERROR: Could not open gods.json")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		print("ERROR: Failed to parse gods.json: ", json.get_error_message())
		return

	var data = json.data
	if not data.has("gods"):
		print("ERROR: Missing gods section")
		return

	var gods = data["gods"]
	var tier_counts = {1: 0, 2: 0, 3: 0, 4: 0}

	for god_id in gods.keys():
		var god = gods[god_id]
		if god.has("tier"):
			var tier = god["tier"]
			if tier_counts.has(tier):
				tier_counts[tier] += 1

	print("Tier 1 (Common): %d gods" % tier_counts[1])
	print("Tier 2 (Rare): %d gods" % tier_counts[2])
	print("Tier 3 (Epic): %d gods" % tier_counts[3])
	print("Tier 4 (Legendary): %d gods" % tier_counts[4])
	print("Total: %d gods" % (tier_counts[1] + tier_counts[2] + tier_counts[3] + tier_counts[4]))

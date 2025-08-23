# scripts/systems/DataLoader.gd
extends Node
class_name DataLoader

# Cached data
static var territories_data: Dictionary = {}
static var enemies_data: Dictionary = {}
static var gods_data: Dictionary = {}
static var awakened_gods_data: Dictionary = {}
static var abilities_data: Dictionary = {}
static var loot_data: Dictionary = {}
static var core_systems_data: Dictionary = {}
static var banners_data: Dictionary = {}
static var data_loaded: bool = false

static func load_core_systems_data():
	var file_path = "res://core_game_systems.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if not file:
		print("Error: Could not open core_game_systems.json file")
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		print("Error parsing core_game_systems.json: ", json.error_string)
		return
	
	core_systems_data = json.get_data()
	print("Loaded core systems data with ", core_systems_data.keys().size(), " system categories")

static func load_all_data():
	if data_loaded:
		return
	
	load_territories_data()
	load_enemies_data()
	load_gods_data()
	load_awakened_gods_data()
	load_abilities_data()
	load_loot_data()
	load_core_systems_data()
	load_banners_data()
	data_loaded = true
	print("All game data loaded successfully")

static func load_territories_data():
	var file_path = "res://data/territories.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if not file:
		print("Error: Could not open ", file_path)
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		print("Error parsing territories.json: ", json.error_string)
		return
	
	territories_data = json.get_data()
	print("Loaded ", territories_data.territories.size(), " territory configurations")

static func load_enemies_data():
	var file_path = "res://data/enemies.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if not file:
		print("Error: Could not open ", file_path)
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		print("Error parsing enemies.json: ", json.error_string)
		return
	
	enemies_data = json.get_data()
	print("Loaded enemy data with ", enemies_data.enemy_types.size(), " element types")

static func load_gods_data():
	var file_path = "res://data/gods.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if not file:
		print("Error: Could not open ", file_path)
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		print("Error parsing gods.json: ", json.error_string)
		return
	
	gods_data = json.get_data()
	print("Loaded ", gods_data.gods.size(), " god configurations")

static func load_awakened_gods_data():
	var file_path = "res://data/awakened_gods.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if not file:
		print("Warning: Could not open ", file_path, " - awakening system disabled")
		awakened_gods_data = {}
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		print("Error parsing awakened_gods.json: ", json.error_string)
		awakened_gods_data = {}
		return
	
	awakened_gods_data = json.get_data()
	print("Loaded ", awakened_gods_data.get("awakened_gods", {}).size(), " awakened god configurations")

static func load_abilities_data():
	var file_path = "res://data/abilities.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if not file:
		print("Error: Could not open ", file_path)
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		print("Error parsing abilities.json: ", json.error_string)
		return
	
	abilities_data = json.get_data()
	var ability_count = abilities_data.get("abilities", {}).size()
	print("Loaded ", ability_count, " ability configurations")

static func load_loot_data():
	var file_path = "res://data/loot.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if not file:
		print("Error: Could not open ", file_path)
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		print("Error parsing loot.json: ", json.error_string)
		return
	
	loot_data = json.get_data()
	print("Loaded loot data with ", loot_data.get("loot_tables", {}).size(), " loot tables")

static func get_territory_config(territory_id: String) -> Dictionary:
	if not data_loaded:
		load_all_data()
	
	for territory in territories_data.territories:
		if territory.id == territory_id:
			return territory
	
	print("Warning: Territory config not found for ID: ", territory_id)
	return {}

static func get_all_territory_configs() -> Array:
	if not data_loaded:
		load_all_data()
	
	return territories_data.get("territories", [])

static func get_tier_settings(tier: int) -> Dictionary:
	if not data_loaded:
		load_all_data()
	
	var tier_key = str(tier)
	return territories_data.get("tier_settings", {}).get(tier_key, {})

static func get_enemy_types_for_element(element: String) -> Dictionary:
	if not data_loaded:
		load_all_data()
	
	return enemies_data.get("enemy_types", {}).get(element, {})

static func get_stage_title(stage: int) -> String:
	if not data_loaded:
		load_all_data()
	
	var stage_titles = enemies_data.get("stage_titles", {})
	
	# Find the appropriate title range
	for range_key in stage_titles.keys():
		var parts = range_key.split("-")
		if parts.size() == 2:
			var min_stage = int(parts[0])
			var max_stage = int(parts[1])
			if stage >= min_stage and stage <= max_stage:
				return stage_titles[range_key]
	
	return ""

static func get_enemy_role_config(role: String) -> Dictionary:
	if not data_loaded:
		load_all_data()
	
	return enemies_data.get("enemy_roles", {}).get(role, {})

static func get_base_stats_config() -> Dictionary:
	if not data_loaded:
		load_all_data()
	
	return enemies_data.get("base_stats", {})

static func get_rewards_config() -> Dictionary:
	if not data_loaded:
		load_all_data()
	
	return enemies_data.get("rewards", {})

static func get_special_formation_for_stage(stage: int, max_stages: int) -> Dictionary:
	if not data_loaded:
		load_all_data()
	
	var formations = enemies_data.get("special_formations", {})
	
	# Check for boss stage (final stage)
	if stage == max_stages and formations.has("boss_stage"):
		return formations["boss_stage"]
	
	# Check for elite squad stages
	if formations.has("elite_squad") and formations["elite_squad"].get("stages", []).has(stage):
		return formations["elite_squad"]
	
	# Check for swarm stages
	if formations.has("swarm") and formations["swarm"].get("stages", []).has(stage):
		return formations["swarm"]
	
	return {}

static func element_string_to_int(element_string: String) -> int:
	match element_string.to_lower():
		"fire":
			return 0
		"water":
			return 1
		"earth":
			return 2
		"lightning":
			return 3
		"light":
			return 4
		"dark":
			return 5
		_:
			print("Warning: Unknown element string: ", element_string)
			return 0

static func element_int_to_string(element_int: int) -> String:
	match element_int:
		0:
			return "fire"
		1:
			return "water"
		2:
			return "earth"
		3:
			return "lightning"
		4:
			return "light"
		5:
			return "dark"
		_:
			return "unknown"

# God data utility functions
static func get_god_config(god_id: String) -> Dictionary:
	if not data_loaded:
		load_all_data()
	
	# Check awakened gods first
	var awakened_god = awakened_gods_data.get("awakened_gods", {}).get(god_id, {})
	if not awakened_god.is_empty():
		return awakened_god
	
	# Then check regular gods
	for god in gods_data.gods:
		if god.id == god_id:
			return god
	
	print("Warning: God config not found for ID: ", god_id)
	return {}

static func get_awakened_god_config(god_id: String) -> Dictionary:
	"""Get awakened god configuration specifically"""
	if not data_loaded:
		load_all_data()
	
	return awakened_gods_data.get("awakened_gods", {}).get(god_id, {})

static func get_gods_by_pantheon(pantheon: String) -> Array:
	if not data_loaded:
		load_all_data()
	
	var result = []
	for god in gods_data.gods:
		if god.pantheon.to_lower() == pantheon.to_lower():
			result.push_back(god)
	
	return result

static func get_gods_by_tier(tier: String) -> Array:
	if not data_loaded:
		load_all_data()
	
	var result = []
	for god in gods_data.gods:
		if god.tier.to_lower() == tier.to_lower():
			result.push_back(god)
	
	return result

static func get_random_god_by_rarity(summon_type: String = "basic_summon") -> Dictionary:
	if not data_loaded:
		load_all_data()
	
	var roll = randf() * 100.0
	var cumulative_chance = 0.0
	
	# Get the specific summon type rates from JSON
	var summon_rates = gods_data.get("summon_rates", {})
	var type_rates = summon_rates.get(summon_type, {})
	var rates = type_rates.get("rates", {})
	
	# If no rates found, fallback to basic_summon rates
	if rates.is_empty():
		type_rates = summon_rates.get("basic_summon", {})
		rates = type_rates.get("rates", {"common": 60, "rare": 30, "epic": 9, "legendary": 1})
	
	# Build weighted list based on summon-specific rates
	for tier in ["common", "rare", "epic", "legendary"]:
		cumulative_chance += rates.get(tier, 0.0)
		if roll <= cumulative_chance:
			var tier_gods = get_gods_by_tier(tier)
			if tier_gods.size() > 0:
				return tier_gods[randi() % tier_gods.size()]
	
	# Fallback to common if something goes wrong
	var common_gods = get_gods_by_tier("common")
	return common_gods[randi() % common_gods.size()] if common_gods.size() > 0 else {}

static func get_ability_config(ability_id: String) -> Dictionary:
	if not data_loaded:
		load_all_data()
	
	# Check abilities dictionary
	var abilities = abilities_data.get("abilities", {})
	if abilities.has(ability_id):
		return abilities[ability_id]
	
	print("Warning: Ability config not found for ID: ", ability_id)
	return {}

static func get_tier_multipliers() -> Dictionary:
	if not data_loaded:
		load_all_data()
	
	return gods_data.get("tier_multipliers", {})

static func get_summon_rates() -> Dictionary:
	if not data_loaded:
		load_all_data()
	
	return gods_data.get("summon_rates", {})

# Loot system utility functions
static func get_stage_loot_rewards(stage: int, is_final_stage: bool = false, territory_element: String = "fire", territory_pantheon: String = "greek") -> Array:
	if not data_loaded:
		load_all_data()
	
	var loot_table = "boss_stage" if is_final_stage else "stage_victory"
	var rewards = []
	
	var table_data = loot_data.get("loot_tables", {}).get(loot_table, {})
	
	# Process guaranteed base loot
	if table_data.has("base_loot"):
		for loot_item in table_data["base_loot"]:
			if randf() <= loot_item.get("chance", 1.0):
				var amount = randi_range(loot_item.get("min_amount", 1), loot_item.get("max_amount", 1))
				if loot_item.get("scales_with_stage", false):
					amount = int(amount * (1.0 + stage * 0.1))
				rewards.append({
					"type": loot_item["type"],
					"amount": amount
				})
	
	# Process guaranteed drops (for boss stages)
	if table_data.has("guaranteed_drops"):
		for loot_item in table_data["guaranteed_drops"]:
			if randf() <= loot_item.get("chance", 1.0):
				var base_amount = randi_range(loot_item.get("min_amount", 1), loot_item.get("max_amount", 1))
				var amount = int(base_amount * loot_item.get("amount_multiplier", 1.0))
				rewards.append({
					"type": loot_item["type"],
					"amount": amount
				})
	
	# Process rare drops with awakening material support
	if table_data.has("rare_drops"):
		for loot_item in table_data["rare_drops"]:
			if loot_item.get("only_final_stage", false) and not is_final_stage:
				continue
			if randf() <= loot_item.get("chance", 0.0):
				var amount = randi_range(loot_item.get("min_amount", 1), loot_item.get("max_amount", 1))
				var item_type = loot_item["type"]
				
				# Handle element-based rewards (powders)
				if loot_item.get("element_based", false):
					item_type = territory_element + "_" + item_type  # e.g. "fire_powder_low"
				
				# Handle pantheon-based rewards (relics)
				if loot_item.get("pantheon_based", false):
					item_type = territory_pantheon + "_" + item_type  # e.g. "greek_relics"
				
				rewards.append({
					"type": item_type,
					"amount": amount
				})
	
	return rewards

static func get_experience_rewards(stage: int, victory: bool = true, element_advantage: bool = false) -> int:
	if not data_loaded:
		load_all_data()
	
	var xp_config = loot_data.get("experience_rewards", {})
	var base_xp = xp_config.get("victory_base_xp", 100) if victory else xp_config.get("defeat_consolation_xp", 25)
	
	# Add stage bonus
	var stage_bonus = xp_config.get("stage_xp_bonus", 10) * stage
	var total_xp = base_xp + stage_bonus
	
	# Apply element advantage bonus
	if element_advantage and victory:
		total_xp = int(total_xp * xp_config.get("element_advantage_xp_bonus", 1.2))
	
	return total_xp

static func get_territory_unlock_rewards() -> Array:
	if not data_loaded:
		load_all_data()
	
	var rewards = []
	var table_data = loot_data.get("loot_tables", {}).get("territory_unlock", {})
	
	if table_data.has("bonus_loot"):
		for loot_item in table_data["bonus_loot"]:
			if randf() <= loot_item.get("chance", 1.0):
				var base_amount = randi_range(loot_item.get("min_amount", 1), loot_item.get("max_amount", 1))
				var amount = int(base_amount * loot_item.get("amount_multiplier", 1.0))
				rewards.append({
					"type": loot_item["type"],
					"amount": amount
				})
	
	return rewards

static func load_banners_data():
	var file_path = "res://data/banners.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if not file:
		print("Warning: Could not open banners.json file - using default banners")
		banners_data = {
			"banners": {},
			"special_summons": {},
			"events": {}
		}
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		print("Error parsing banners.json: ", json.error_string)
		return
	
	banners_data = json.get_data()
	print("Loaded banner data with ", banners_data.get("banners", {}).size(), " banners")

# Banner utility functions
static func get_active_banners() -> Array:
	if not data_loaded:
		load_all_data()
	
	var active = []
	var banners = banners_data.get("banners", {})
	
	for banner_id in banners.keys():
		var banner = banners[banner_id]
		if banner.get("active", false):
			active.append(banner)
	
	return active

static func get_banner_by_id(banner_id: String) -> Dictionary:
	if not data_loaded:
		load_all_data()
	
	return banners_data.get("banners", {}).get(banner_id, {})

static func get_special_summon_by_id(summon_id: String) -> Dictionary:
	if not data_loaded:
		load_all_data()
	
	return banners_data.get("special_summons", {}).get(summon_id, {})

static func get_summon_milestones() -> Dictionary:
	if not data_loaded:
		load_all_data()
	
	return banners_data.get("progression_rewards", {}).get("summon_milestones", {})

static func get_pity_config() -> Dictionary:
	if not data_loaded:
		load_all_data()
	
	return banners_data.get("pity_system_config", {})

# Enhanced god utility functions for banners
static func get_featured_gods_for_banner(banner_id: String) -> Array:
	var banner = get_banner_by_id(banner_id)
	return banner.get("featured_gods", [])

static func get_rate_multiplier_for_banner(banner_id: String, god_id: String) -> float:
	var banner = get_banner_by_id(banner_id)
	var featured_gods = banner.get("featured_gods", [])
	var rate_up = banner.get("rate_up", {})
	
	if featured_gods.has(god_id):
		return rate_up.get("featured_multiplier", 1.0)
	
	return 1.0

static func get_territory_passive_income(territory_id: String, assigned_gods: Array = []) -> Dictionary:
	var territory = get_territory_config(territory_id)
	if territory.is_empty():
		return {}
	
	# Get territory tier and element
	var tier = territory.get("tier", 1)
	var territory_element = territory.get("element", "fire")
	var tier_key = "tier_%d_territories" % tier
	
	# Load loot data if needed
	if loot_data.is_empty():
		load_loot_data()
	
	# Get base generation from loot.json
	var base_generation = loot_data.get("loot_tables", {}).get("territory_passive_income", {}).get("base_generation_per_hour", {}).get(tier_key, {})
	var god_bonuses = loot_data.get("loot_tables", {}).get("territory_passive_income", {}).get("god_assignment_bonuses", {})
	
	if base_generation.is_empty():
		print("Warning: No base generation found for ", tier_key, " - using fallback")
		return _get_fallback_passive_income(tier_key, assigned_gods)
	
	var final_generation = base_generation.duplicate()
	
	# Apply god assignment bonuses if gods are assigned
	if assigned_gods.size() > 0 and not god_bonuses.is_empty():
		var total_multiplier = 1.0
		var has_element_match = false
		var best_tier_bonus = 1.0
		var has_awakened_god = false
		
		# Analyze assigned gods
		for god in assigned_gods:
			# Check element match
			var god_element_string = element_int_to_string(god.element)
			if god_element_string == territory_element:
				has_element_match = true
			
			# Get best tier bonus
			var god_tier_string = _get_god_tier_string(god)
			var tier_bonus = god_bonuses.get("tier_bonus", {}).get(god_tier_string, 1.0)
			if tier_bonus > best_tier_bonus:
				best_tier_bonus = tier_bonus
			
			# Check if awakened
			if god.is_awakened:
				has_awakened_god = true
		
		# Apply element match bonus
		if has_element_match:
			var element_bonus = god_bonuses.get("element_match", {}).get("multiplier", 1.5)
			total_multiplier *= element_bonus
		
		# Apply best tier bonus
		total_multiplier *= best_tier_bonus
		
		# Apply multiple gods bonus
		var multiple_key = str(assigned_gods.size()) + "_gods"
		var multiple_bonus = god_bonuses.get("multiple_gods", {}).get(multiple_key, 1.0)
		total_multiplier *= multiple_bonus
		
		# Apply awakened god bonus
		if has_awakened_god:
			var awakened_bonus = god_bonuses.get("awakened_bonus", {}).get("multiplier", 1.3)
			total_multiplier *= awakened_bonus
			
			# Add extra awakening materials for awakened gods
			var extra_resource = god_bonuses.get("awakened_bonus", {}).get("extra_resource", "")
			if extra_resource != "":
				var element_resource = territory_element + "_" + extra_resource
				final_generation[element_resource] = final_generation.get(element_resource, 0) + 1
		
		# Apply total multiplier to all resources
		for resource_type in final_generation.keys():
			final_generation[resource_type] = int(final_generation[resource_type] * total_multiplier)
		
		# Add element-specific powder generation for tier 2+ territories
		if tier >= 2:
			var element_powder_low = territory_element + "_powder_low"
			var element_powder_mid = territory_element + "_powder_mid"
			
			# Add element-specific powders based on tier and bonuses
			final_generation[element_powder_low] = final_generation.get(element_powder_low, 0) + int(2 * total_multiplier)
			if tier >= 3:
				final_generation[element_powder_mid] = final_generation.get(element_powder_mid, 0) + int(1 * total_multiplier)
	
	return final_generation

static func _get_god_tier_string(god) -> String:
	"""Convert god tier enum to string for bonus lookup"""
	if god.has_method("get_tier_name"):
		return god.get_tier_name().to_lower()
	
	# Fallback based on typical tier enum values
	match god.tier:
		0: 
			return "common"
		1: 
			return "rare" 
		2: 
			return "epic"
		3: 
			return "legendary"
		_: 
			return "common"

static func _get_fallback_passive_income(tier_key: String, _assigned_gods: Array) -> Dictionary:
	"""Fallback resource generation when territory data is missing"""
	if loot_data.is_empty():
		load_loot_data()
	
	var base_generation = loot_data.get("loot_tables", {}).get("territory_passive_income", {}).get("base_generation_per_hour", {}).get(tier_key, {})
	
	if base_generation.is_empty():
		# Final fallback
		return {
			"divine_essence": 50,
			"crystals": 1
		}
	
	return base_generation.duplicate()

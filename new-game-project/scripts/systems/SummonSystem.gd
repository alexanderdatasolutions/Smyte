# scripts/systems/SummonSystem.gd
extends Node

# Summoners War style summoning system - focused purely on summoning
# All summoned gods are kept in collection (no auto-conversion)

const GameDataLoader = preload("res://scripts/systems/DataLoader.gd")

signal summon_completed(god)
signal summon_failed(reason)
signal multi_summon_completed(gods)

# Configuration data loaded from JSON
var summon_config: Dictionary = {}
var gods_data: Dictionary = {}
var role_data: Dictionary = {}

# Pity counters for guaranteed drops
var pity_counter = {
	"rare": 0,
	"epic": 0, 
	"legendary": 0
}

# Daily/Weekly tracking
var last_free_summon_date = ""
var daily_free_used = false
var last_weekly_premium_date = ""
var weekly_premium_used = false

func _ready():
	load_summon_configuration()
	load_gods_data()

# ==============================================================================
# CONFIGURATION LOADING
# ==============================================================================

func load_summon_configuration():
	"""Load summon configuration from JSON - completely modular"""
	var config_file = FileAccess.open("res://data/summon_config.json", FileAccess.READ)
	if not config_file:
		push_error("Failed to load summon_config.json")
		create_fallback_config()
		return
	
	var json_string = config_file.get_as_text()
	config_file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse summon_config.json")
		create_fallback_config()
		return
	
	summon_config = json.get_data()
	print("SummonSystem: Loaded modular summon configuration")

func load_gods_data():
	"""Load gods data for summon filtering"""
	GameDataLoader.load_all_data()
	gods_data = GameDataLoader.gods_data
	
	# Load god roles data directly
	var roles_file = FileAccess.open("res://data/god_roles.json", FileAccess.READ)
	if roles_file:
		var json_string = roles_file.get_as_text()
		roles_file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			role_data = json.get_data()
	
	print("SummonSystem: Loaded gods data - %d gods available" % gods_data.get("gods", []).size())

func create_fallback_config():
	"""Create minimal fallback configuration"""
	summon_config = {
		"summon_configuration": {
			"costs": {
				"soul_based_summons": {
					"common_soul_summon": { "common_soul": 1 }
				}
			},
			"rates": {
				"soul_based_rates": {
					"common_soul": {
						"common": 70.0,
						"rare": 25.0,
						"epic": 4.5,
						"legendary": 0.5
					}
				}
			}
		}
	}

# ==============================================================================
# MAIN SUMMON FUNCTIONS
# ==============================================================================

# Soul-based summons (from loot tables)
func summon_with_soul(soul_type: String) -> bool:
	"""Summon using souls obtained from loot tables"""
	return _perform_summon(soul_type + "_summon", "soul_based", {"soul_type": soul_type})

func summon_element_soul(element: String) -> bool:
	"""Summon using element-specific souls from loot"""
	return _perform_summon(element + "_soul_summon", "element_soul", {"element": element})

# Focused summons
func summon_pantheon_focus(pantheon: String) -> bool:
	"""Focus summon on specific pantheon"""
	return _perform_summon("common_soul_summon", "pantheon_focus", {"pantheon": pantheon})

func summon_role_focus(role: String) -> bool:
	"""Focus summon on specific role"""
	return _perform_summon("common_soul_summon", "role_focus", {"role": role})

# Premium summons
func summon_premium() -> bool:
	"""Premium summon using divine crystals"""
	return _perform_summon("divine_crystals_summon", "premium")

func summon_with_mana() -> bool:
	"""Mana-based summon"""
	return _perform_summon("mana_summon", "mana_based")

# Multi-summons with guarantees
func multi_summon_soul_pack() -> bool:
	"""10-pull soul pack with guarantees"""
	return _perform_multi_summon("soul_pack_10", "soul_pack")

func multi_summon_premium() -> bool:
	"""10-pull premium pack with guarantees"""
	return _perform_multi_summon("premium_pack_10", "premium_pack")

# Special summons
func daily_free_summon() -> bool:
	"""Free daily summon"""
	if not can_use_daily_free_summon():
		summon_failed.emit("Daily free summon already used")
		return false
	
	daily_free_used = true
	last_free_summon_date = Time.get_date_string_from_system()
	
	return _perform_summon_with_rates(get_config_rates("soul_based_rates", "common_soul"), "free_daily")

# ==============================================================================
# CORE SUMMON LOGIC
# ==============================================================================

func _perform_summon(cost_type: String, summon_type: String, params: Dictionary = {}) -> bool:
	# Get cost from config
	var cost = get_summon_cost(cost_type)
	if cost.is_empty():
		summon_failed.emit("Invalid summon type: " + cost_type)
		return false
	
	# Check affordability
	if not _can_afford_cost(cost):
		summon_failed.emit("Cannot afford summon cost")
		return false
	
	# Spend resources
	_spend_cost(cost)
	
	# Get appropriate rates
	var rates = get_summon_rates(cost_type, summon_type, params)
	
	# Perform summon
	return _perform_summon_with_rates(rates, summon_type, params)

func _perform_summon_with_rates(rates: Dictionary, summon_type: String, params: Dictionary = {}) -> bool:
	# Apply pity system
	var modified_rates = apply_pity_system(rates)
	
	# Get random god based on rates and filters
	var god_id = get_weighted_random_god(modified_rates, summon_type, params)
	if god_id.is_empty():
		summon_failed.emit("No valid god found")
		return false
	
	# Create god
	var god = _create_god_from_id(god_id)
	if not god:
		summon_failed.emit("Failed to create god")
		return false
	
	# Add to collection (Summoners War style - keep all)
	_add_god_to_collection(god)
	
	# Update pity counters
	_update_pity_counters(god.get_tier_name().to_lower())
	
	summon_completed.emit(god)
	return true

func _perform_multi_summon(cost_type: String, pack_type: String, params: Dictionary = {}) -> bool:
	var pack_config = get_config_value("summon_configuration.multi_summon_guarantees." + pack_type, {})
	var pack_size = pack_config.get("size", 10)
	
	# Calculate total cost with discount
	var single_cost = get_summon_cost(cost_type.replace("_10", "_summon"))
	var total_cost = {}
	for currency in single_cost:
		total_cost[currency] = single_cost[currency] * (pack_size - 1)  # 10-pull discount
	
	if not _can_afford_cost(total_cost):
		summon_failed.emit("Cannot afford multi-summon")
		return false
	
	_spend_cost(total_cost)
	
	# Perform summons with guarantees
	var summoned_gods = []
	var guarantees = pack_config.get("guarantees", {})
	
	for i in range(pack_size):
		var is_guarantee_summon = (i == pack_size - 1)  # Last summon has guarantee
		var rates = get_summon_rates(cost_type.replace("_10", "_summon"), pack_type, params)
		
		if is_guarantee_summon:
			rates = apply_guarantee_rates(rates, guarantees)
		
		var god_id = get_weighted_random_god(rates, pack_type, params)
		if not god_id.is_empty():
			var god = _create_god_from_id(god_id)
			if god:
				_add_god_to_collection(god)
				_update_pity_counters(god.get_tier_name().to_lower())
				summoned_gods.append(god)
	
	multi_summon_completed.emit(summoned_gods)
	return summoned_gods.size() > 0

# ==============================================================================
# CONFIGURATION ACCESS HELPERS
# ==============================================================================

func get_summon_cost(cost_type: String) -> Dictionary:
	"""Get summon cost from config"""
	var soul_costs = get_config_value("summon_configuration.costs.soul_based_summons." + cost_type, {})
	if not soul_costs.is_empty():
		return soul_costs
	
	var premium_costs = get_config_value("summon_configuration.costs.premium_summons." + cost_type, {})
	if not premium_costs.is_empty():
		return premium_costs
	
	var multi_costs = get_config_value("summon_configuration.costs.multi_summons." + cost_type, {})
	return multi_costs

func get_summon_rates(cost_type: String, summon_type: String, _params: Dictionary) -> Dictionary:
	"""Get summon rates based on type and parameters"""
	var base_rates = {}
	
	# Determine rate source
	if cost_type.ends_with("_soul_summon"):
		var soul_type = cost_type.replace("_summon", "")
		
		# Check if it's element soul
		if soul_type in ["fire_soul", "water_soul", "earth_soul", "lightning_soul", "light_soul", "dark_soul"]:
			base_rates = get_config_rates("element_soul_rates", soul_type)
		else:
			base_rates = get_config_rates("soul_based_rates", soul_type)
	
	elif summon_type == "premium":
		base_rates = get_config_rates("premium_rates", "divine_crystals")
	
	elif summon_type == "mana_based":
		base_rates = get_config_rates("premium_rates", "mana")
	
	else:
		# Default to common soul rates
		base_rates = get_config_rates("soul_based_rates", "common_soul")
	
	return base_rates

func get_config_rates(rate_category: String, rate_type: String) -> Dictionary:
	"""Helper to get rates from config"""
	return get_config_value("summon_configuration.rates." + rate_category + "." + rate_type, {})

func get_config_value(path: String, default_value = null):
	"""Get nested config value using dot notation"""
	var keys = path.split(".")
	var current = summon_config
	
	for key in keys:
		if typeof(current) == TYPE_DICTIONARY and current.has(key):
			current = current[key]
		else:
			return default_value
	
	return current

# ==============================================================================
# GOD SELECTION LOGIC
# ==============================================================================

func get_weighted_random_god(rates: Dictionary, summon_type: String, params: Dictionary) -> String:
	"""Get random god based on rates and filters"""
	# First determine tier
	var tier = get_random_tier_from_rates(rates)
	
	# Get gods matching criteria
	var available_gods = filter_gods_by_criteria(tier, summon_type, params)
	
	if available_gods.is_empty():
		push_warning("No gods found for criteria: tier=%s, type=%s" % [tier, summon_type])
		# Fallback to any god of the tier
		available_gods = get_gods_by_tier(tier)
	
	if available_gods.is_empty():
		return ""
	
	# Apply weighting for special summon types
	var weighted_gods = apply_summon_weights(available_gods, summon_type, params)
	
	# Select random god with weights
	return select_weighted_random_god(weighted_gods)

func get_random_tier_from_rates(rates: Dictionary) -> String:
	"""Randomly select tier based on rates"""
	var random_value = randf() * 100.0
	var cumulative = 0.0
	
	for tier in ["legendary", "epic", "rare", "common"]:
		cumulative += rates.get(tier, 0.0)
		if random_value <= cumulative:
			return tier
	
	return "common"  # Fallback

func filter_gods_by_criteria(tier: String, summon_type: String, params: Dictionary) -> Array:
	"""Filter gods by summon criteria"""
	var all_gods = get_gods_by_tier(tier)
	var filtered_gods = []
	
	for god_config in all_gods:
		if meets_summon_criteria(god_config, summon_type, params):
			filtered_gods.append(god_config)
	
	return filtered_gods

func meets_summon_criteria(god_config: Dictionary, summon_type: String, params: Dictionary) -> bool:
	"""Check if god meets summon criteria"""
	match summon_type:
		"element_soul":
			return god_config.get("element", "") == params.get("element", "")
		
		"pantheon_focus":
			return god_config.get("pantheon", "") == params.get("pantheon", "")
		
		"role_focus":
			var god_roles = get_god_roles(god_config.get("id", ""))
			return params.get("role", "") in god_roles
		
		_:
			return true  # No special criteria

func apply_summon_weights(gods: Array, summon_type: String, params: Dictionary) -> Dictionary:
	"""Apply weighting based on summon focus"""
	var weighted_gods = {}
	var base_weight = 1.0
	
	for god_config in gods:
		var weight = base_weight
		
		# Apply focus weights from config
		match summon_type:
			"element_soul":
				if god_config.get("element", "") == params.get("element", ""):
					weight *= get_config_value("summon_configuration.filtering_weights.element_focus.matching_element_weight", 3.0)
			
			"pantheon_focus":
				if god_config.get("pantheon", "") == params.get("pantheon", ""):
					weight *= get_config_value("summon_configuration.filtering_weights.pantheon_focus.matching_pantheon_weight", 2.5)
			
			"role_focus":
				var god_roles = get_god_roles(god_config.get("id", ""))
				if params.get("role", "") in god_roles:
					weight *= get_config_value("summon_configuration.filtering_weights.role_focus.matching_role_weight", 2.0)
		
		weighted_gods[god_config.get("id", "")] = weight
	
	return weighted_gods

func select_weighted_random_god(weighted_gods: Dictionary) -> String:
	"""Select random god from weighted dictionary"""
	if weighted_gods.is_empty():
		return ""
	
	var total_weight = 0.0
	for weight in weighted_gods.values():
		total_weight += weight
	
	var random_value = randf() * total_weight
	var cumulative = 0.0
	
	for god_id in weighted_gods:
		cumulative += weighted_gods[god_id]
		if random_value <= cumulative:
			return god_id
	
	# Fallback
	return weighted_gods.keys()[0]

# ==============================================================================
# PITY SYSTEM
# ==============================================================================

func apply_pity_system(rates: Dictionary) -> Dictionary:
	"""Apply pity system modifications to rates"""
	if not get_config_value("summon_configuration.pity_system.enabled", true):
		return rates
	
	var modified_rates = rates.duplicate()
	var pity_config = get_config_value("summon_configuration.pity_system", {})
	var thresholds = pity_config.get("thresholds", {})
	
	# Hard pity - guarantee at threshold
	if pity_counter.legendary >= thresholds.get("legendary", 100):
		return {"legendary": 100.0, "epic": 0.0, "rare": 0.0, "common": 0.0}
	
	if pity_counter.epic >= thresholds.get("epic", 50):
		return {"legendary": rates.get("legendary", 0.0), "epic": 100.0 - rates.get("legendary", 0.0), "rare": 0.0, "common": 0.0}
	
	# Soft pity - rate increase
	var soft_pity = pity_config.get("soft_pity", {})
	if soft_pity.get("enabled", true):
		apply_soft_pity_rates(modified_rates, soft_pity)
	
	return modified_rates

func apply_soft_pity_rates(rates: Dictionary, soft_pity_config: Dictionary):
	"""Apply soft pity rate increases"""
	var legendary_config = soft_pity_config.get("legendary", {})
	var legendary_start = legendary_config.get("starts_at", 75)
	var legendary_increase = legendary_config.get("rate_increase_per_summon", 0.5)
	
	if pity_counter.legendary >= legendary_start:
		var bonus_rate = (pity_counter.legendary - legendary_start) * legendary_increase
		rates.legendary = min(rates.get("legendary", 0.0) + bonus_rate, 100.0)
	
	var epic_config = soft_pity_config.get("epic", {})
	var epic_start = epic_config.get("starts_at", 35)
	var epic_increase = epic_config.get("rate_increase_per_summon", 1.0)
	
	if pity_counter.epic >= epic_start and pity_counter.legendary < legendary_start:
		var bonus_rate = (pity_counter.epic - epic_start) * epic_increase
		rates.epic = min(rates.get("epic", 0.0) + bonus_rate, 100.0 - rates.get("legendary", 0.0))

func _update_pity_counters(tier: String):
	"""Update pity counters after summon"""
	match tier:
		"legendary":
			pity_counter.legendary = 0
			pity_counter.epic = 0
			pity_counter.rare = 0
		"epic":
			pity_counter.epic = 0
			pity_counter.rare = 0
			pity_counter.legendary += 1
		"rare":
			pity_counter.rare = 0
			pity_counter.legendary += 1
			pity_counter.epic += 1
		"common":
			pity_counter.legendary += 1
			pity_counter.epic += 1
			pity_counter.rare += 1

# ==============================================================================
# GUARANTEE SYSTEM (Multi-summons)
# ==============================================================================

func apply_guarantee_rates(rates: Dictionary, guarantees: Dictionary) -> Dictionary:
	"""Modify rates to apply guarantees"""
	var modified_rates = rates.duplicate()
	
	if guarantees.has("rare_or_better"):
		# Ensure at least rare
		if modified_rates.get("common", 0.0) > 0:
			var common_rate = modified_rates.common
			modified_rates.common = 0.0
			modified_rates.rare = modified_rates.get("rare", 0.0) + common_rate
	
	if guarantees.has("epic_or_better"):
		# Ensure at least epic
		var lower_rates = modified_rates.get("common", 0.0) + modified_rates.get("rare", 0.0)
		modified_rates.common = 0.0
		modified_rates.rare = 0.0
		modified_rates.epic = modified_rates.get("epic", 0.0) + lower_rates
	
	return modified_rates

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

func get_gods_by_tier(tier: String) -> Array:
	"""Get all gods of specified tier"""
	var tier_gods = []
	for god_config in gods_data.get("gods", []):
		if god_config.get("tier", "").to_lower() == tier.to_lower():
			tier_gods.append(god_config)
	
	return tier_gods

func get_god_roles(god_id: String) -> Array:
	"""Get roles for specific god"""
	if role_data and role_data.has("god_role_assignments") and role_data.god_role_assignments.has(god_id):
		var assignment = role_data.god_role_assignments[god_id]
		var roles = [assignment.get("role", "")]
		
		if assignment.has("secondary_role"):
			roles.append(assignment.secondary_role)
		
		return roles
	
	return ["gatherer"]  # Default role

func _create_god_from_id(god_id: String) -> God:
	"""Create god instance from ID"""
	# This would call your existing God creation system
	return God.create_from_json(god_id)

func _add_god_to_collection(god: God):
	"""Add god to player collection"""
	if not GameManager or not GameManager.player_data:
		return
	
	GameManager.player_data.add_god(god)

# ==============================================================================
# AFFORDABILITY & SPENDING
# ==============================================================================

func _can_afford_cost(cost: Dictionary) -> bool:
	"""Check if player can afford cost"""
	if not GameManager or not GameManager.player_data:
		return false
	
	for currency in cost:
		var required = cost[currency]
		if GameManager.player_data.get_resource(currency) < required:
			return false
	
	return true

func _spend_cost(cost: Dictionary):
	"""Spend resources for summon"""
	if not GameManager or not GameManager.player_data:
		return
	
	for currency in cost:
		var amount = cost[currency]
		GameManager.player_data.spend_resource(currency, amount)

# ==============================================================================
# SPECIAL SUMMON AVAILABILITY
# ==============================================================================

func can_use_daily_free_summon() -> bool:
	var current_date = Time.get_date_string_from_system()
	return last_free_summon_date != current_date

func can_use_weekly_premium_summon() -> bool:
	if last_weekly_premium_date.is_empty():
		return true
	
	# Simple date comparison - check if a week has passed
	var last_date_parts = last_weekly_premium_date.split("-")
	var current_date_parts = Time.get_date_string_from_system().split("-")
	
	if last_date_parts.size() != 3 or current_date_parts.size() != 3:
		return true
	
	# Basic week check (simplified)
	var days_diff = int(current_date_parts[2]) - int(last_date_parts[2])
	return days_diff >= 7

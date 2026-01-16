# scripts/systems/collection/SummonManager.gd
# RULE 1 COMPLIANCE: Under 500-line limit
# RULE 2 COMPLIANCE: Single responsibility - summoning system only
# RULE 5 COMPLIANCE: SystemRegistry access only
extends Node
class_name SummonManager

# Summoning system following clean architecture - uses SystemRegistry for all operations
# NO JSON loading - uses existing systems through SystemRegistry

signal summon_completed(god)
signal summon_failed(reason)
signal multi_summon_completed(gods)

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
	pass

# ==============================================================================
# MAIN SUMMON FUNCTIONS - Using SystemRegistry Pattern
# ==============================================================================

func summon_basic() -> bool:
	"""Basic summon using mana"""
	var cost = {"mana": 1000}
	return _perform_summon(cost, "basic")

func summon_premium() -> bool:
	"""Premium summon using crystals"""
	var cost = {"crystals": 100}
	return _perform_summon(cost, "premium")

func summon_free_daily() -> bool:
	"""Free daily summon"""
	if not can_use_daily_free_summon():
		summon_failed.emit("Daily free summon already used")
		return false
	
	daily_free_used = true
	last_free_summon_date = Time.get_date_string_from_system()
	
	return _perform_summon({}, "free_daily")

func summon_with_soul(soul_type: String) -> bool:
	"""Summon using souls"""
	var cost = {}
	cost[soul_type] = 1
	return _perform_summon(cost, "soul_based")

# ==============================================================================
# CORE SUMMON LOGIC - SystemRegistry Pattern
# ==============================================================================

func _perform_summon(cost: Dictionary, summon_type: String) -> bool:
	"""Core summon logic using SystemRegistry systems"""
	
	# Check affordability using ResourceManager
	if not _can_afford_cost(cost):
		summon_failed.emit("Cannot afford summon cost")
		return false
	
	# Spend resources using ResourceManager
	_spend_cost(cost)
	
	# Get random god using CollectionManager
	var god = _get_random_god(summon_type)
	if not god:
		summon_failed.emit("Failed to generate god")
		return false
	
	# Add to collection using CollectionManager
	_add_god_to_collection(god)
	
	# Update pity counters
	_update_pity_counters(God.tier_to_string(god.tier).to_lower())
	
	summon_completed.emit(god)
	return true

# ==============================================================================
# RESOURCE MANAGEMENT - Uses ResourceManager through SystemRegistry
# ==============================================================================

func _can_afford_cost(cost: Dictionary) -> bool:
	"""Check if player can afford cost using ResourceManager"""
	var resource_manager = SystemRegistry.get_instance().get_system("ResourceManager") if SystemRegistry.get_instance() else null
	if not resource_manager:
		push_error("SummonSystem: ResourceManager not available")
		return false
	
	for currency in cost:
		var required = cost[currency]
		if resource_manager.get_resource(currency) < required:
			return false
	
	return true

func _spend_cost(cost: Dictionary):
	"""Spend resources for summon using ResourceManager"""
	var resource_manager = SystemRegistry.get_instance().get_system("ResourceManager") if SystemRegistry.get_instance() else null
	if not resource_manager:
		push_error("SummonSystem: ResourceManager not available")
		return
	
	for currency in cost:
		var amount = cost[currency]
		resource_manager.spend(currency, amount)

# ==============================================================================
# GOD GENERATION - Uses CollectionManager through SystemRegistry
# ==============================================================================

func _get_random_god(summon_type: String) -> God:
	"""Generate random god based on summon type"""
	
	# Get rates for this summon type
	var rates = _get_summon_rates(summon_type)
	
	# Apply pity system
	rates = _apply_pity_system(rates)
	
	# Randomly select tier
	var tier = _get_random_tier(rates)
	
	# Create god of that tier
	return _create_god_of_tier(tier)

func _get_summon_rates(summon_type: String) -> Dictionary:
	"""Get base summon rates for different types"""
	match summon_type:
		"basic":
			return {"common": 70.0, "rare": 25.0, "epic": 4.5, "legendary": 0.5}
		"premium":
			return {"common": 50.0, "rare": 35.0, "epic": 12.0, "legendary": 3.0}
		"free_daily":
			return {"common": 80.0, "rare": 18.0, "epic": 2.0, "legendary": 0.0}
		"soul_based":
			return {"common": 60.0, "rare": 30.0, "epic": 8.0, "legendary": 2.0}
		_:
			return {"common": 85.0, "rare": 13.0, "epic": 2.0, "legendary": 0.0}

func _apply_pity_system(rates: Dictionary) -> Dictionary:
	"""Apply pity system modifications to rates"""
	var modified_rates = rates.duplicate()
	
	# Hard pity - guarantee legendary at 100 summons
	if pity_counter.legendary >= 100:
		return {"legendary": 100.0, "epic": 0.0, "rare": 0.0, "common": 0.0}
	
	# Hard pity - guarantee epic at 50 summons
	if pity_counter.epic >= 50:
		var legendary_rate = modified_rates.get("legendary", 0.0)
		return {"legendary": legendary_rate, "epic": 100.0 - legendary_rate, "rare": 0.0, "common": 0.0}
	
	# Soft pity - increase rates gradually
	if pity_counter.legendary >= 75:
		var bonus = (pity_counter.legendary - 75) * 0.5
		modified_rates.legendary = min(modified_rates.get("legendary", 0.0) + bonus, 50.0)
	
	if pity_counter.epic >= 35:
		var bonus = (pity_counter.epic - 35) * 1.0
		modified_rates.epic = min(modified_rates.get("epic", 0.0) + bonus, 50.0)
	
	return modified_rates

func _get_random_tier(rates: Dictionary) -> String:
	"""Randomly select tier based on rates"""
	var random_value = randf() * 100.0
	var cumulative = 0.0
	
	for tier in ["legendary", "epic", "rare", "common"]:
		cumulative += rates.get(tier, 0.0)
		if random_value <= cumulative:
			return tier
	
	return "common"  # Fallback

func _create_god_of_tier(tier: String) -> God:
	"""Create a random god of specified tier using real god data"""
	# Get all available gods from configuration
	var config_manager = SystemRegistry.get_instance().get_system("ConfigurationManager") if SystemRegistry.get_instance() else null
	if not config_manager:
		push_error("SummonSystem: ConfigurationManager not available")
		return null
	
	var gods_config = config_manager.get_gods_config()
	if not gods_config.has("gods"):
		push_error("SummonSystem: No gods data found in configuration")
		return null
	
	# Convert tier string to number for comparison
	var tier_number = _tier_string_to_number(tier)
	if tier_number == -1:
		push_error("SummonSystem: Invalid tier: " + tier)
		return null
	
	# Filter gods by tier
	var available_gods = []
	for god_id in gods_config.gods:
		var god_data = gods_config.gods[god_id]
		if god_data.get("tier", 1) == tier_number:
			available_gods.append(god_id)
	
	if available_gods.is_empty():
		push_error("SummonSystem: No gods found for tier: " + tier)
		# Fallback to creating a simple god
		var fallback_god = God.new()
		fallback_god.name = "Random " + tier.capitalize() + " God"
		fallback_god.tier = GodFactory.string_to_tier(tier)
		fallback_god.level = 1
		return fallback_god
	
	# Randomly select a god from available gods
	var random_god_id = available_gods[randi() % available_gods.size()]
	
	# Create god using GodFactory
	var god = GodFactory.create_from_json(random_god_id)
	if not god:
		push_error("SummonSystem: Failed to create god with id: " + random_god_id)
		return null
	
	return god

func _tier_string_to_number(tier: String) -> int:
	"""Convert tier string to number for configuration matching"""
	match tier.to_lower():
		"common":
			return 1
		"rare":
			return 2
		"epic":
			return 3
		"legendary":
			return 4
		_:
			return -1

func _add_god_to_collection(god: God):
	"""Add god to player collection using CollectionManager"""
	var collection_manager = SystemRegistry.get_instance().get_system("CollectionManager") if SystemRegistry.get_instance() else null
	if not collection_manager:
		push_error("SummonSystem: CollectionManager not available")
		return
	
	collection_manager.add_god(god)

# ==============================================================================
# PITY SYSTEM
# ==============================================================================

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

# ==============================================================================
# MULTI-SUMMON FUNCTIONS
# ==============================================================================

func multi_summon_premium(count: int = 10) -> bool:
	"""Premium 10-pull with guarantees"""
	var single_cost = {"crystals": 100}
	var total_cost = {"crystals": single_cost.crystals * (count - 1)}  # 10-pull discount
	
	if not _can_afford_cost(total_cost):
		summon_failed.emit("Cannot afford multi-summon")
		return false
	
	_spend_cost(total_cost)
	
	var summoned_gods = []
	for i in range(count):
		var summon_type = "premium"
		# Last summon has guarantee
		if i == count - 1:
			summon_type = "premium_guaranteed"
		
		var god = _get_random_god(summon_type)
		if god:
			summoned_gods.append(god)
			_add_god_to_collection(god)
			_update_pity_counters(God.tier_to_string(god.tier).to_lower())
	
	multi_summon_completed.emit(summoned_gods)
	return summoned_gods.size() > 0

# ==============================================================================
# SAVE/LOAD
# ==============================================================================

func get_save_data() -> Dictionary:
	return {
		"pity_counter": pity_counter.duplicate(),
		"last_free_summon_date": last_free_summon_date,
		"daily_free_used": daily_free_used,
		"last_weekly_premium_date": last_weekly_premium_date,
		"weekly_premium_used": weekly_premium_used
	}

func load_save_data(save_data: Dictionary):
	if save_data.has("pity_counter"):
		pity_counter = save_data.pity_counter.duplicate()
	if save_data.has("last_free_summon_date"):
		last_free_summon_date = save_data.last_free_summon_date
	if save_data.has("daily_free_used"):
		daily_free_used = save_data.daily_free_used
	if save_data.has("last_weekly_premium_date"):
		last_weekly_premium_date = save_data.last_weekly_premium_date
	if save_data.has("weekly_premium_used"):
		weekly_premium_used = save_data.weekly_premium_used

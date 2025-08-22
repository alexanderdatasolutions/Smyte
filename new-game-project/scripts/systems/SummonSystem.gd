# scripts/systems/SummonSystem.gd
extends Node

# SUMMONERS WAR MECHANICS:
# - ALL summoned monsters are kept (no auto-conversion of duplicates)
# - Duplicates are used for:
#   1. Skill-ups (feed same monster to power up skills)
#   2. Evolution materials (use duplicates to evolve monsters)
#   3. Ancient Crystals (convert max-skilled monsters manually)

const GameDataLoader = preload("res://scripts/systems/DataLoader.gd")

signal summon_completed(god)
signal summon_failed(reason)
signal multi_summon_completed(gods)
signal duplicate_obtained(god, existing_count)

# Pity system - based on core systems document
var pity_counter = {
	"rare": 0,
	"epic": 0, 
	"legendary": 0
}

# Pity thresholds from core systems
const PITY_THRESHOLDS = {
	"rare": 10,
	"epic": 50, 
	"legendary": 100
}

# Summon costs - now supports multiple currencies
const SUMMON_COSTS = {
	"basic_summon": { "divine_essence": 100 },
	"element_summon": { "divine_essence": 200 },
	"premium_summon": { "divine_essence": 500 },
	"crystal_summon": { "crystals": 100 },
	"ticket_summon": { "summon_tickets": 1 }
}

# Multi-summon configurations
const MULTI_SUMMON_SIZES = {
	"basic": 10,
	"premium": 10,
	"element": 10
}

# Guarantee systems for multi-summons
const MULTI_SUMMON_GUARANTEES = {
	"basic": { "rare_or_better": 1 },
	"premium": { "epic_or_better": 1 },
	"element": { "rare_or_better": 1, "featured_element": 3 }
}

# Current active banners/events
var active_banners = []
var daily_free_summon_used = false
var last_free_summon_date = ""

func summon_basic() -> bool:
	return _perform_summon("basic_summon", "basic")

func summon_element(element: int) -> bool:
	return _perform_summon("element_summon", "element", {"element": element})

func summon_premium() -> bool:
	return _perform_summon("premium_summon", "premium")

func summon_with_crystals() -> bool:
	return _perform_summon("crystal_summon", "premium")

func summon_with_ticket() -> bool:
	return _perform_summon("ticket_summon", "basic")

# Multi-summon functions
func multi_summon_basic() -> bool:
	return _perform_multi_summon("basic_summon", "basic")

func multi_summon_premium() -> bool:
	return _perform_multi_summon("premium_summon", "premium")

func multi_summon_element(element: int) -> bool:
	return _perform_multi_summon("element_summon", "element", {"element": element})

# Core summon logic
func _perform_summon(cost_type: String, summon_type: String, params: Dictionary = {}) -> bool:
	# Check if player can afford the summon
	if not _can_afford_summon(cost_type):
		summon_failed.emit("Insufficient resources")
		return false
	
	# Spend resources
	_spend_summon_cost(cost_type)
	
	# Perform the summon
	var god_id = _get_random_god_with_pity(summon_type, params)
	var god = _create_god_from_id(god_id)
	
	if god:
		# In Summoners War style - ALWAYS keep the summoned god
		GameManager.player_data.add_god(god)
		
		# Count how many of this god we have (including the one we just added)
		var duplicate_count = 0
		for existing in GameManager.player_data.gods:
			if existing.id == god_id:
				duplicate_count += 1
		
		if duplicate_count > 1:
			# Emit duplicate signal for UI to show "New!" vs "Duplicate" notifications
			duplicate_obtained.emit(god, duplicate_count - 1)  # Pass how many we already had
		
		summon_completed.emit(god)
		GameManager.god_summoned.emit(god)
		return true
	
	summon_failed.emit("Failed to create god")
	return false

func _perform_multi_summon(cost_type: String, summon_type: String, params: Dictionary = {}) -> bool:
	var multi_cost = {}
	var single_cost = SUMMON_COSTS[cost_type]
	var count = MULTI_SUMMON_SIZES[summon_type]
	
	# Calculate multi-summon cost (usually discounted)
	for currency in single_cost.keys():
		multi_cost[currency] = single_cost[currency] * count * 0.9  # 10% discount
	
	# Check affordability
	if not _can_afford_cost(multi_cost):
		summon_failed.emit("Insufficient resources for multi-summon")
		return false
	
	# Spend resources
	_spend_cost(multi_cost)
	
	# Perform multiple summons
	var summoned_gods = []
	var guaranteed_tiers = []
	
	# Apply guarantees
	var guarantees = MULTI_SUMMON_GUARANTEES[summon_type]
	for guarantee_type in guarantees.keys():
		for i in range(guarantees[guarantee_type]):
			guaranteed_tiers.append(guarantee_type)
	
	# Perform summons
	for i in range(count):
		var force_tier = ""
		if i < guaranteed_tiers.size():
			force_tier = guaranteed_tiers[i]
		
		var god_id = _get_random_god_with_pity(summon_type, params, force_tier)
		var god = _create_god_from_id(god_id)
		
		if god:
			# In Summoners War style - ALWAYS keep all summoned gods
			GameManager.player_data.add_god(god)
			summoned_gods.append(god)
			
			# Track duplicates for UI feedback
			var duplicate_count = 0
			for existing in GameManager.player_data.gods:
				if existing.id == god_id:
					duplicate_count += 1
			
			if duplicate_count > 1:
				duplicate_obtained.emit(god, duplicate_count - 1)
	
	multi_summon_completed.emit(summoned_gods)
	for god in summoned_gods:
		GameManager.god_summoned.emit(god)
	
	return summoned_gods.size() > 0

func _get_element_god_with_pity(element: int) -> String:
	# Get element-specific god first, then apply pity if needed
	var element_god = _get_random_god_by_element(element)
	
	# Check if pity should override the element selection
	if pity_counter["legendary"] >= 100:
		# Force legendary but prefer element if available
		var element_string = GameDataLoader.element_int_to_string(element)
		var element_legendaries = _get_gods_by_element_and_tier(element_string, "legendary")
		if element_legendaries.size() > 0:
			pity_counter["legendary"] = 0
			pity_counter["epic"] = 0
			pity_counter["rare"] = 0
			return element_legendaries[randi() % element_legendaries.size()]
		else:
			# No legendary of this element, get any legendary
			var legendary_gods = GameDataLoader.get_gods_by_tier("legendary")
			if legendary_gods.size() > 0:
				pity_counter["legendary"] = 0
				pity_counter["epic"] = 0
				pity_counter["rare"] = 0
				return legendary_gods[randi() % legendary_gods.size()].id
	
	return element_god

func _get_gods_by_element_and_tier(element_string: String, tier: String) -> Array:
	GameDataLoader.load_all_data()
	var result = []
	for god_config in GameDataLoader.gods_data.gods:
		if god_config.element.to_lower() == element_string.to_lower() and god_config.tier.to_lower() == tier.to_lower():
			result.push_back(god_config.id)
	return result



func _get_premium_god_with_pity() -> String:
	# Check pity system first (same logic but with premium rates when not forced)
	var force_tier = ""
	if pity_counter["legendary"] >= 100:
		force_tier = "legendary"
		pity_counter["legendary"] = 0
		pity_counter["epic"] = 0
		pity_counter["rare"] = 0
	elif pity_counter["epic"] >= 50:
		force_tier = "epic"
		pity_counter["epic"] = 0
		pity_counter["rare"] = 0
		pity_counter["legendary"] += 1
	elif pity_counter["rare"] >= 10:
		force_tier = "rare"
		pity_counter["rare"] = 0
		pity_counter["epic"] += 1
		pity_counter["legendary"] += 1
	
	var god_config
	if force_tier != "":
		# Force a specific tier due to pity
		var tier_gods = GameDataLoader.get_gods_by_tier(force_tier)
		if tier_gods.size() > 0:
			god_config = tier_gods[randi() % tier_gods.size()]
		else:
			god_config = GameDataLoader.get_random_god_by_rarity("premium_summon")
	else:
		# Use premium summon rates from JSON
		god_config = GameDataLoader.get_random_god_by_rarity("premium_summon")
		
		# Update pity counters based on result
		var tier_name = god_config.tier.to_lower()
		match tier_name:
			"rare":
				pity_counter["rare"] = 0
				pity_counter["epic"] += 1
				pity_counter["legendary"] += 1
			"epic":
				pity_counter["rare"] = 0
				pity_counter["epic"] = 0
				pity_counter["legendary"] += 1
			"legendary":
				pity_counter["rare"] = 0
				pity_counter["epic"] = 0
				pity_counter["legendary"] = 0
			_:  # common
				pity_counter["rare"] += 1
				pity_counter["epic"] += 1
				pity_counter["legendary"] += 1
	
	return god_config.id

func _get_random_god_by_tier(tier: int) -> String:
	var god_ids = _get_god_ids_by_tier(tier)
	if god_ids.size() > 0:
		return god_ids[randi() % god_ids.size()]
	return "ares"  # Fallback

func _get_random_god_by_element(element: int) -> String:
	# Convert element int to string
	var element_string = GameDataLoader.element_int_to_string(element)
	
	# Find all gods with this element from JSON data
	GameDataLoader.load_all_data()
	var matching_gods = []
	for god_config in GameDataLoader.gods_data.gods:
		if god_config.element.to_lower() == element_string.to_lower():
			matching_gods.push_back(god_config)
	
	if matching_gods.size() > 0:
		var chosen_god = matching_gods[randi() % matching_gods.size()]
		return chosen_god.id
	
	# Fallback to any god if no matches
	var all_gods = GameDataLoader.gods_data.gods
	if all_gods.size() > 0:
		return all_gods[randi() % all_gods.size()].id
	
	return "ares"  # Final fallback

func _get_god_ids_by_tier(tier: int) -> Array:
	# Convert tier int to string 
	var tier_string = ""
	match tier:
		0:
			tier_string = "common"
		1:
			tier_string = "rare"
		2:
			tier_string = "epic"
		3:
			tier_string = "legendary"
		_:
			tier_string = "common"
	
	# Use JSON data to get gods by tier
	var tier_gods = GameDataLoader.get_gods_by_tier(tier_string)
	var result = []
	for god_config in tier_gods:
		result.push_back(god_config.id)
	
	return result

func _get_god_ids_by_element(element: int) -> Array:
	# Convert element int to string
	var element_string = GameDataLoader.element_int_to_string(element)
	
	# Find gods by element from JSON data
	GameDataLoader.load_all_data()
	var result = []
	for god_config in GameDataLoader.gods_data.gods:
		if god_config.element.to_lower() == element_string.to_lower():
			result.push_back(god_config.id)
	
	return result

func _create_god_from_id(god_id: String):
	# Use the new JSON-based god creation system
	return God.create_from_json(god_id)

func _get_all_god_ids() -> Array:
	# Get all god IDs from JSON data
	GameDataLoader.load_all_data()
	var all_gods = []
	for god_config in GameDataLoader.gods_data.gods:
		all_gods.push_back(god_config.id)
	return all_gods

# Enhanced helper functions for new summon system

func _can_afford_summon(cost_type: String) -> bool:
	var cost = SUMMON_COSTS[cost_type]
	return _can_afford_cost(cost)

func _can_afford_cost(cost: Dictionary) -> bool:
	for currency in cost.keys():
		var required_amount = cost[currency]
		match currency:
			"divine_essence":
				if GameManager.player_data.divine_essence < required_amount:
					return false
			"crystals":
				if GameManager.player_data.premium_crystals < required_amount:
					return false
			"summon_tickets":
				if GameManager.player_data.summon_tickets < required_amount:
					return false
	return true

func _spend_summon_cost(cost_type: String):
	var cost = SUMMON_COSTS[cost_type]
	_spend_cost(cost)

func _spend_cost(cost: Dictionary):
	for currency in cost.keys():
		var amount = cost[currency]
		match currency:
			"divine_essence":
				GameManager.player_data.spend_divine_essence(amount)
			"crystals":
				GameManager.player_data.spend_crystals(amount)
			"summon_tickets":
				GameManager.player_data.spend_summon_tickets(amount)



# Enhanced pity system with proper tier support
func _get_random_god_with_pity(summon_type: String = "basic", params: Dictionary = {}, force_tier: String = "") -> String:
	# Handle forced tier (for multi-summon guarantees)
	if force_tier != "":
		return _get_god_by_force_tier(force_tier, summon_type, params)
	
	# Check pity system
	var pity_tier = _check_pity_triggers()
	if pity_tier != "":
		_reset_pity_for_tier(pity_tier)
		return _get_god_by_force_tier(pity_tier, summon_type, params)
	
	# Normal summon with rate ups
	var god_config = _get_weighted_random_god(summon_type, params)
	
	# Update pity counters
	_update_pity_counters(god_config.tier)
	
	return god_config.id

func _check_pity_triggers() -> String:
	if pity_counter["legendary"] >= PITY_THRESHOLDS["legendary"]:
		return "legendary"
	elif pity_counter["epic"] >= PITY_THRESHOLDS["epic"]:
		return "epic"
	elif pity_counter["rare"] >= PITY_THRESHOLDS["rare"]:
		return "rare"
	return ""

func _reset_pity_for_tier(tier: String):
	match tier:
		"legendary":
			pity_counter["legendary"] = 0
			pity_counter["epic"] = 0
			pity_counter["rare"] = 0
		"epic":
			pity_counter["epic"] = 0
			pity_counter["rare"] = 0
			pity_counter["legendary"] += 1
		"rare":
			pity_counter["rare"] = 0
			pity_counter["epic"] += 1
			pity_counter["legendary"] += 1

func _update_pity_counters(tier_name: String):
	match tier_name.to_lower():
		"legendary":
			pity_counter["legendary"] = 0
			pity_counter["epic"] = 0
			pity_counter["rare"] = 0
		"epic":
			pity_counter["epic"] = 0
			pity_counter["rare"] = 0
			pity_counter["legendary"] += 1
		"rare":
			pity_counter["rare"] = 0
			pity_counter["epic"] += 1
			pity_counter["legendary"] += 1
		"common":
			pity_counter["rare"] += 1
			pity_counter["epic"] += 1
			pity_counter["legendary"] += 1

func _get_god_by_force_tier(tier: String, summon_type: String, params: Dictionary) -> String:
	# For element summons, try to get god of specified element first
	if summon_type == "element" and params.has("element"):
		var element_gods = _get_gods_by_element_and_tier(GameDataLoader.element_int_to_string(params.element), tier)
		if element_gods.size() > 0:
			return element_gods[randi() % element_gods.size()]
	
	# Fallback to any god of the tier
	var tier_gods = GameDataLoader.get_gods_by_tier(tier)
	if tier_gods.size() > 0:
		return tier_gods[randi() % tier_gods.size()].id
	
	# Final fallback
	return "ares"

func _get_weighted_random_god(summon_type: String, params: Dictionary) -> Dictionary:
	# Use existing JSON-based random selection but with potential element filtering
	if summon_type == "element" and params.has("element"):
		# For element summons, use modified rates favoring the chosen element
		return _get_element_weighted_god(params.element)
	else:
		# Use standard rates from JSON
		var rates_key = summon_type + "_summon" if summon_type != "basic" else "basic_summon"
		return GameDataLoader.get_random_god_by_rarity(rates_key)

func _get_element_weighted_god(element: int) -> Dictionary:
	# Get element-specific weighted selection
	var element_string = GameDataLoader.element_int_to_string(element)
	GameDataLoader.load_all_data()
	
	# Build weighted list favoring the chosen element
	var weighted_gods = []
	var _total_weight = 0
	
	for god_config in GameDataLoader.gods_data.gods:
		var weight = god_config.get("summon_weight", 1)
		# Double weight for matching element
		if god_config.element.to_lower() == element_string.to_lower():
			weight *= 2
		
		for i in range(weight):
			weighted_gods.append(god_config)
		_total_weight += weight
	
	if weighted_gods.size() > 0:
		return weighted_gods[randi() % weighted_gods.size()]
	
	# Fallback
	return GameDataLoader.get_random_god_by_rarity("basic_summon")

# Daily free summon system
func daily_free_summon() -> bool:
	var current_date = Time.get_date_string_from_system()
	
	if last_free_summon_date == current_date:
		summon_failed.emit("Daily free summon already used")
		return false
	
	last_free_summon_date = current_date
	daily_free_summon_used = true
	
	# Perform free summon (basic rates)
	return _perform_summon_with_free_override("basic_summon", "basic", {}, true)

func _perform_summon_with_free_override(cost_type: String, summon_type: String, params: Dictionary = {}, is_free: bool = false) -> bool:
	# Modified version that can skip cost checking for free summons
	if not is_free:
		if not _can_afford_summon(cost_type):
			summon_failed.emit("Insufficient resources")
			return false
		_spend_summon_cost(cost_type)
	
	var god_id = _get_random_god_with_pity(summon_type, params)
	var god = _create_god_from_id(god_id)
	
	if god:
		# In Summoners War style - ALWAYS keep the summoned god
		GameManager.player_data.add_god(god)
		
		# Track duplicates for UI feedback
		var duplicate_count = 0
		for existing in GameManager.player_data.gods:
			if existing.id == god_id:
				duplicate_count += 1
		
		if duplicate_count > 1:
			duplicate_obtained.emit(god, duplicate_count - 1)
		
		summon_completed.emit(god)
		GameManager.god_summoned.emit(god)
		return true
	
	summon_failed.emit("Failed to create god")
	return false

# Banner/Event system foundation
func activate_banner(banner_config: Dictionary):
	active_banners.append(banner_config)
	print("Activated banner: ", banner_config.get("name", "Unknown Banner"))

func deactivate_banner(banner_id: String):
	for i in range(active_banners.size() - 1, -1, -1):
		if active_banners[i].get("id", "") == banner_id:
			active_banners.remove_at(i)
			print("Deactivated banner: ", banner_id)

func get_active_banners() -> Array:
	return active_banners

func can_use_daily_free_summon() -> bool:
	var current_date = Time.get_date_string_from_system()
	return last_free_summon_date != current_date

# Enhanced banner-based summoning
func summon_from_banner(banner_id: String, count: int = 1) -> bool:
	var banner = GameDataLoader.get_banner_by_id(banner_id)
	if banner.is_empty():
		summon_failed.emit("Banner not found: " + banner_id)
		return false
	
	# Check banner costs
	var costs = banner.get("costs", {})
	var cost_key = "ten_pull" if count == 10 else "single"
	var required_cost = costs.get(cost_key, {})
	
	if not _can_afford_cost(required_cost):
		summon_failed.emit("Cannot afford banner summon")
		return false
	
	# Spend the cost
	_spend_cost(required_cost)
	
	# Perform the summons with banner modifiers
	var summoned_gods = []
	for i in range(count):
		var god_id = _get_banner_modified_god(banner_id, banner)
		var god = _create_god_from_id(god_id)
		
		if god:
			# In Summoners War style - ALWAYS keep all summoned gods
			GameManager.player_data.add_god(god)
			summoned_gods.append(god)
			
			# Track duplicates for UI feedback
			var duplicate_count = 0
			for existing in GameManager.player_data.gods:
				if existing.id == god_id:
					duplicate_count += 1
			
			if duplicate_count > 1:
				duplicate_obtained.emit(god, duplicate_count - 1)
	
	# Emit appropriate signals
	if count == 1:
		if summoned_gods.size() > 0:
			summon_completed.emit(summoned_gods[0])
			GameManager.god_summoned.emit(summoned_gods[0])
	else:
		multi_summon_completed.emit(summoned_gods)
		for god in summoned_gods:
			GameManager.god_summoned.emit(god)
	
	return summoned_gods.size() > 0

func _get_banner_modified_god(_banner_id: String, banner: Dictionary) -> String:
	var featured_gods = banner.get("featured_gods", [])
	var rate_up = banner.get("rate_up", {})
	
	# If this is a featured banner with specific gods
	if featured_gods.size() > 0 and rate_up.has("featured_multiplier"):
		# Chance to get a featured god (enhanced rate)
		var featured_multiplier = rate_up.get("featured_multiplier", 1.0)
		var featured_chance = 0.3 * featured_multiplier  # Base 30% chance for featured, multiplied
		
		if randf() <= featured_chance:
			# Select from featured gods using normal tier rates
			var weighted_featured_gods = []
			for god_id in featured_gods:
				var god_config = GameDataLoader.get_god_config(god_id)
				if not god_config.is_empty():
					var weight = god_config.get("summon_weight", 1)
					for i in range(weight):
						weighted_featured_gods.append(god_config)
			
			if weighted_featured_gods.size() > 0:
				var selected = weighted_featured_gods[randi() % weighted_featured_gods.size()]
				return selected.id
	
	# Use normal summon logic with potential rate modifications
	var summon_type = "basic"  # Default fallback
	if banner.get("type") == "premium":
		summon_type = "premium"
	
	return _get_random_god_with_pity(summon_type)

# Progression tracking
func track_summon_progression(_god: God):
	# Track summons for milestone rewards
	GameManager.player_data.total_summons += 1
	
	# Check for milestone rewards
	var milestones = GameDataLoader.get_summon_milestones()
	var total = GameManager.player_data.total_summons
	
	for milestone_key in milestones.keys():
		var milestone_count = int(milestone_key.split("_")[0])
		if total == milestone_count:
			_award_milestone_reward(milestones[milestone_key])

func _award_milestone_reward(reward_config: Dictionary):
	var reward = reward_config.get("reward", {})
	
	for currency in reward.keys():
		var amount = reward[currency]
		match currency:
			"divine_essence":
				GameManager.player_data.add_divine_essence(amount)
			"crystals":
				GameManager.player_data.add_premium_crystals(amount)
			"summon_tickets":
				GameManager.player_data.add_summon_tickets(amount)
			"ascension_materials":
				GameManager.player_data.add_ascension_materials(amount)
			"guaranteed_epic":
				# Queue a guaranteed epic summon
				pass
			"guaranteed_legendary":
				# Queue a guaranteed legendary summon
				pass
	
	print("Milestone reward awarded: ", reward)

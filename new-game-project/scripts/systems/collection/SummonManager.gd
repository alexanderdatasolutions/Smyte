# scripts/systems/collection/SummonManager.gd
# RULE 1 COMPLIANCE: Under 500-line limit | RULE 2: Single responsibility | RULE 5: SystemRegistry only
extends Node
class_name SummonManager

signal summon_completed(god)
signal summon_failed(reason)
signal multi_summon_completed(gods)
signal pity_milestone_reached(pity_type: String, count: int)
signal summon_history_updated(history_entry: Dictionary)
signal duplicate_obtained(god, mana_reward: int)
signal milestone_reward_claimed(milestone_key: String, rewards: Dictionary)

# Pity counters per banner type for guaranteed drops
var pity_counters: Dictionary = {
	"default": {"rare": 0, "epic": 0, "legendary": 0},
	"premium": {"rare": 0, "epic": 0, "legendary": 0},
	"element": {"rare": 0, "epic": 0, "legendary": 0}
}
var last_free_summon_date: String = ""
var daily_free_used: bool = false
var last_weekly_premium_date: String = ""
var weekly_premium_used: bool = false
var summon_history: Array = []  # Last 100 summons
var total_summons: int = 0
var claimed_milestones: Array = []
var _summon_config: Dictionary = {}
var _last_summon_duplicates: Dictionary = {}  # god_id -> bool (true if was duplicate)
const MAX_HISTORY_SIZE: int = 100

func _ready():
	_load_config()

func _load_config():
	var config_manager = SystemRegistry.get_instance().get_system("ConfigurationManager") if SystemRegistry.get_instance() else null
	if config_manager:
		_summon_config = config_manager.get_summon_config()

func get_config() -> Dictionary:
	if _summon_config.is_empty():
		_load_config()
	return _summon_config

# MAIN SUMMON FUNCTIONS

func summon_basic() -> bool:
	var config = get_config()
	var cost = {"mana": 10000}
	if config.has("summon_configuration"):
		var costs = config.summon_configuration.get("costs", {}).get("premium_summons", {})
		if costs.has("mana_summon"):
			cost = costs.mana_summon
	return _perform_summon(cost, "mana", "default")

func summon_premium() -> bool:
	var config = get_config()
	var cost = {"divine_crystals": 100}
	if config.has("summon_configuration"):
		var costs = config.summon_configuration.get("costs", {}).get("premium_summons", {})
		if costs.has("divine_crystals_summon"):
			cost = costs.divine_crystals_summon
	return _perform_summon(cost, "divine_crystals", "premium")

func summon_free_daily() -> bool:
	if not can_use_daily_free_summon():
		summon_failed.emit("Daily free summon already used")
		return false
	daily_free_used = true
	last_free_summon_date = Time.get_date_string_from_system()
	return _perform_summon({}, "common_soul", "default")

func summon_with_soul(soul_type: String) -> bool:
	var cost = {soul_type: 1}
	var banner_type = "element" if soul_type.ends_with("_soul") and not soul_type.begins_with("common") and not soul_type.begins_with("rare") and not soul_type.begins_with("epic") and not soul_type.begins_with("legendary") else "default"
	return _perform_summon(cost, soul_type, banner_type)

func summon_with_element_soul(element: String) -> bool:
	var soul_type = element + "_soul"
	return _perform_summon({soul_type: 1}, soul_type, "element", element)

# CORE SUMMON LOGIC

func _perform_summon(cost: Dictionary, summon_type: String, banner_type: String, element_filter: String = "") -> bool:
	if not _can_afford_cost(cost):
		summon_failed.emit("Cannot afford summon cost")
		return false
	_spend_cost(cost)

	var god = _get_random_god(summon_type, banner_type, element_filter)
	if not god:
		summon_failed.emit("Failed to generate god")
		return false

	_add_god_to_collection(god)
	var tier_string = God.tier_to_string(god.tier).to_lower()
	_update_pity_counters(tier_string, banner_type)
	total_summons += 1
	_check_milestone_rewards()
	_add_to_history(god, summon_type, cost)
	summon_completed.emit(god)
	return true

func _can_afford_cost(cost: Dictionary) -> bool:
	if cost.is_empty():
		return true
	var resource_manager = SystemRegistry.get_instance().get_system("ResourceManager") if SystemRegistry.get_instance() else null
	if not resource_manager:
		push_error("SummonManager: ResourceManager not available")
		return false
	for currency in cost:
		if resource_manager.get_resource(currency) < cost[currency]:
			return false
	return true

func _spend_cost(cost: Dictionary):
	if cost.is_empty():
		return
	var resource_manager = SystemRegistry.get_instance().get_system("ResourceManager") if SystemRegistry.get_instance() else null
	if not resource_manager:
		return
	for currency in cost:
		resource_manager.spend(currency, cost[currency])

# GOD GENERATION

func _get_random_god(summon_type: String, banner_type: String, element_filter: String = "") -> God:
	var rates = _get_summon_rates(summon_type)
	rates = _apply_pity_system(rates, banner_type)
	var tier = _get_random_tier(rates)
	return _create_god_of_tier(tier, element_filter)

func _get_summon_rates(summon_type: String) -> Dictionary:
	var config = get_config()
	var default_rates = {"common": 70.0, "rare": 25.0, "epic": 4.5, "legendary": 0.5}
	if not config.has("summon_configuration"):
		return default_rates
	var rates_section = config.summon_configuration.get("rates", {})
	# Check all rate categories
	for category in ["soul_based_rates", "element_soul_rates", "premium_rates"]:
		var category_rates = rates_section.get(category, {})
		if category_rates.has(summon_type):
			return category_rates[summon_type]
	return default_rates

func _apply_pity_system(rates: Dictionary, banner_type: String) -> Dictionary:
	var modified_rates = rates.duplicate()
	var config = get_config()
	var pity_config = config.get("summon_configuration", {}).get("pity_system", {})
	if not pity_config.get("enabled", true):
		return modified_rates

	if not pity_counters.has(banner_type):
		pity_counters[banner_type] = {"rare": 0, "epic": 0, "legendary": 0}
	var counters = pity_counters[banner_type]
	var thresholds = pity_config.get("thresholds", {"rare": 10, "epic": 50, "legendary": 100})

	# Hard pity checks
	if counters.legendary >= thresholds.get("legendary", 100):
		pity_milestone_reached.emit("legendary_hard_pity", counters.legendary)
		return {"legendary": 100.0, "epic": 0.0, "rare": 0.0, "common": 0.0}
	if counters.epic >= thresholds.get("epic", 50):
		pity_milestone_reached.emit("epic_hard_pity", counters.epic)
		return {"legendary": modified_rates.get("legendary", 0.0), "epic": 100.0 - modified_rates.get("legendary", 0.0), "rare": 0.0, "common": 0.0}

	# Soft pity
	var soft_pity = pity_config.get("soft_pity", {})
	if soft_pity.get("enabled", true):
		var leg_soft = soft_pity.get("legendary", {"starts_at": 75, "rate_increase_per_summon": 0.5})
		if counters.legendary >= leg_soft.get("starts_at", 75):
			modified_rates.legendary = min(modified_rates.get("legendary", 0.0) + (counters.legendary - leg_soft.starts_at) * leg_soft.rate_increase_per_summon, 50.0)
		var epic_soft = soft_pity.get("epic", {"starts_at": 35, "rate_increase_per_summon": 1.0})
		if counters.epic >= epic_soft.get("starts_at", 35):
			modified_rates.epic = min(modified_rates.get("epic", 0.0) + (counters.epic - epic_soft.starts_at) * epic_soft.rate_increase_per_summon, 50.0)
	return modified_rates

func _get_random_tier(rates: Dictionary) -> String:
	var random_value = randf() * 100.0
	var cumulative = 0.0
	for tier in ["legendary", "epic", "rare", "common"]:
		cumulative += rates.get(tier, 0.0)
		if random_value <= cumulative:
			return tier
	return "common"

func _create_god_of_tier(tier: String, element_filter: String = "") -> God:
	var config_manager = SystemRegistry.get_instance().get_system("ConfigurationManager") if SystemRegistry.get_instance() else null
	if not config_manager:
		return null
	var gods_config = config_manager.get_gods_config()
	if not gods_config.has("gods"):
		return null

	var tier_number = {"common": 1, "rare": 2, "epic": 3, "legendary": 4}.get(tier.to_lower(), -1)
	if tier_number == -1:
		return null

	# Get filtering weights from config
	var summon_cfg = get_config()
	var element_weight = 3.0
	var other_weight = 1.0
	if summon_cfg.has("summon_configuration"):
		var weights = summon_cfg.summon_configuration.get("filtering_weights", {}).get("element_focus", {})
		element_weight = weights.get("matching_element_weight", 3.0)
		other_weight = weights.get("other_elements_weight", 1.0)

	# Build weighted pool
	var available_gods = []
	for god_id in gods_config.gods:
		var god_data = gods_config.gods[god_id]
		if god_data.get("tier", 1) == tier_number:
			var weight = god_data.get("summon_weight", 1.0)
			if not element_filter.is_empty():
				var god_element = _get_element_string(god_data.get("element", 0))
				weight *= element_weight if god_element == element_filter else other_weight
			for i in range(max(1, int(weight))):
				available_gods.append(god_id)

	if available_gods.is_empty():
		var fallback = God.new()
		fallback.name = "Random " + tier.capitalize() + " God"
		fallback.tier = GodFactory.string_to_tier(tier)
		fallback.level = 1
		return fallback

	return GodFactory.create_from_json(available_gods[randi() % available_gods.size()])

func _get_element_string(element_value) -> String:
	if element_value is int or element_value is float:
		return ["fire", "water", "earth", "lightning", "light", "dark"][clampi(int(element_value), 0, 5)]
	return "fire"

func _add_god_to_collection(god: God) -> bool:
	"""Add god to collection, handling duplicates with mana rewards. Tracks status for UI."""
	var collection_manager = SystemRegistry.get_instance().get_system("CollectionManager") if SystemRegistry.get_instance() else null
	if not collection_manager:
		push_error("SummonManager: CollectionManager not available")
		return false

	var is_new = collection_manager.add_god(god)
	_last_summon_duplicates[god.id] = not is_new  # Track for UI display

	if not is_new:
		var mana_reward = _get_duplicate_mana_reward(god.tier)
		var resource_manager = SystemRegistry.get_instance().get_system("ResourceManager") if SystemRegistry.get_instance() else null
		if resource_manager:
			resource_manager.add_resource("mana", mana_reward)
		duplicate_obtained.emit(god, mana_reward)

	_check_legendary_notification(god)
	return is_new

func _get_duplicate_mana_reward(tier: God.TierType) -> int:
	"""Get mana reward for duplicate god based on tier."""
	match tier:
		God.TierType.LEGENDARY:
			return 5000
		God.TierType.EPIC:
			return 2000
		God.TierType.RARE:
			return 500
		_:  # COMMON
			return 100

func _check_legendary_notification(god: God):
	"""Show notification for legendary/epic pulls via EventBus."""
	var event_bus = SystemRegistry.get_instance().get_system("EventBus") if SystemRegistry.get_instance() else null
	if not event_bus or not event_bus.has_method("emit_notification"):
		return
	if god.tier == God.TierType.LEGENDARY:
		event_bus.emit_notification("LEGENDARY! %s has joined your pantheon!" % god.name, "legendary", 5.0)
	elif god.tier == God.TierType.EPIC:
		event_bus.emit_notification("Epic summon! %s obtained!" % god.name, "epic", 3.0)

func was_duplicate(god_id: String) -> bool:
	"""Check if a recently summoned god was a duplicate. For UI display."""
	return _last_summon_duplicates.get(god_id, false)

func clear_duplicate_tracking():
	"""Clear duplicate tracking for new summon session."""
	_last_summon_duplicates.clear()

# PITY SYSTEM

func _update_pity_counters(tier: String, banner_type: String):
	if not pity_counters.has(banner_type):
		pity_counters[banner_type] = {"rare": 0, "epic": 0, "legendary": 0}
	var counters = pity_counters[banner_type]
	match tier:
		"legendary":
			counters.legendary = 0
			counters.epic = 0
			counters.rare = 0
		"epic":
			counters.epic = 0
			counters.rare = 0
			counters.legendary += 1
		"rare":
			counters.rare = 0
			counters.legendary += 1
			counters.epic += 1
		"common":
			counters.legendary += 1
			counters.epic += 1
			counters.rare += 1
	pity_counters[banner_type] = counters

func get_pity_counter(banner_type: String, rarity: String) -> int:
	if not pity_counters.has(banner_type):
		return 0
	return pity_counters[banner_type].get(rarity, 0)

# SUMMON HISTORY

func _add_to_history(god: God, summon_type: String, cost: Dictionary):
	var entry = {
		"god_id": god.id, "god_name": god.name,
		"tier": God.tier_to_string(god.tier), "element": GodFactory.element_to_string(god.element),
		"summon_type": summon_type, "cost": cost.duplicate(),
		"timestamp": Time.get_unix_time_from_system(), "date": Time.get_date_string_from_system()
	}
	summon_history.insert(0, entry)
	if summon_history.size() > MAX_HISTORY_SIZE:
		summon_history.resize(MAX_HISTORY_SIZE)
	summon_history_updated.emit(entry)

func get_summon_history() -> Array:
	return summon_history.duplicate()

func get_rarity_stats() -> Dictionary:
	var stats = {"common": 0, "rare": 0, "epic": 0, "legendary": 0}
	for entry in summon_history:
		var tier = entry.get("tier", "common").to_lower()
		if stats.has(tier):
			stats[tier] += 1
	return stats

# MILESTONE REWARDS

func _check_milestone_rewards():
	var config = get_config()
	if not config.has("progression_tracking"):
		return
	var milestones = config.progression_tracking.get("milestones", {})
	for key in milestones:
		if key in claimed_milestones:
			continue
		var parts = key.split("_")
		if parts.size() > 0 and total_summons >= int(parts[0]):
			_award_milestone(key, milestones[key])

func _award_milestone(key: String, data: Dictionary):
	var reward = data.get("reward", {})
	if reward.is_empty():
		return
	var resource_manager = SystemRegistry.get_instance().get_system("ResourceManager") if SystemRegistry.get_instance() else null
	if resource_manager:
		for resource_id in reward:
			resource_manager.add_resource(resource_id, reward[resource_id])
	claimed_milestones.append(key)

	# Emit signal and notification for milestone reward
	milestone_reward_claimed.emit(key, reward)
	_notify_milestone_reward(key, reward)

func _notify_milestone_reward(key: String, reward: Dictionary):
	"""Show notification for milestone reward via EventBus."""
	var event_bus = SystemRegistry.get_instance().get_system("EventBus") if SystemRegistry.get_instance() else null
	if not event_bus or not event_bus.has_method("emit_notification"):
		return

	# Format reward text
	var reward_parts = []
	for resource_id in reward:
		var display_name = resource_id.replace("_", " ").capitalize()
		reward_parts.append("%d %s" % [reward[resource_id], display_name])
	var reward_text = ", ".join(reward_parts)

	# Get summon count from key (e.g., "10_summons" -> 10)
	var parts = key.split("_")
	var count = int(parts[0]) if parts.size() > 0 else 0

	var message = "Milestone: %d Summons! Reward: %s" % [count, reward_text]
	event_bus.emit_notification(message, "milestone", 4.0)

# SPECIAL SUMMON AVAILABILITY

func can_use_daily_free_summon() -> bool:
	return last_free_summon_date != Time.get_date_string_from_system()

func can_use_weekly_premium_summon() -> bool:
	if last_weekly_premium_date.is_empty():
		return true
	var last_parts = last_weekly_premium_date.split("-")
	var curr_parts = Time.get_date_string_from_system().split("-")
	if last_parts.size() != 3 or curr_parts.size() != 3:
		return true
	return int(curr_parts[2]) - int(last_parts[2]) >= 7

func get_time_until_free_summon() -> int:
	if can_use_daily_free_summon():
		return 0
	var now = Time.get_unix_time_from_system()
	return (int(now / 86400) + 1) * 86400 - int(now)

# MULTI-SUMMON

func multi_summon_premium(count: int = 10) -> bool:
	var config = get_config()
	var single_cost = 100
	if config.has("summon_configuration"):
		var multi = config.summon_configuration.get("costs", {}).get("multi_summons", {})
		if multi.has("premium_pack_10") and multi.premium_pack_10.has("divine_crystals"):
			single_cost = int(multi.premium_pack_10.divine_crystals / count)
	var total_cost = {"divine_crystals": int(single_cost * count * 0.9)}
	return _perform_multi_summon(total_cost, "divine_crystals", "premium", count, single_cost)

func summon_multi_with_soul(soul_type: String, count: int = 10) -> bool:
	var total_cost = {soul_type: int(count * 0.9)}
	var banner_type = "element" if _is_element_soul(soul_type) else "default"
	return _perform_multi_summon(total_cost, soul_type, banner_type, count, 1)

func _perform_multi_summon(cost: Dictionary, summon_type: String, banner_type: String, count: int, unit_cost: int) -> bool:
	if not _can_afford_cost(cost):
		summon_failed.emit("Cannot afford multi-summon")
		return false
	_spend_cost(cost)
	var summoned_gods = []
	for i in range(count):
		var god = _get_random_god(summon_type, banner_type)
		# Guarantee rare on last pull if none obtained
		if i == count - 1 and not _has_rare_or_better(summoned_gods):
			god = _create_god_of_tier("rare")
		if god:
			summoned_gods.append(god)
			_add_god_to_collection(god)
			_update_pity_counters(God.tier_to_string(god.tier).to_lower(), banner_type)
			total_summons += 1
			var entry_cost = {summon_type: unit_cost} if summon_type != "divine_crystals" else {"divine_crystals": int(unit_cost * 0.9)}
			_add_to_history(god, summon_type, entry_cost)
	_check_milestone_rewards()
	multi_summon_completed.emit(summoned_gods)
	return summoned_gods.size() > 0

func _has_rare_or_better(gods: Array) -> bool:
	for g in gods:
		if g.tier >= God.TierType.RARE:
			return true
	return false

func _is_element_soul(soul_type: String) -> bool:
	return soul_type in ["fire_soul", "water_soul", "earth_soul", "lightning_soul", "light_soul", "dark_soul"]

# SAVE/LOAD

func get_save_data() -> Dictionary:
	return {
		"pity_counters": pity_counters.duplicate(true),
		"last_free_summon_date": last_free_summon_date,
		"daily_free_used": daily_free_used,
		"last_weekly_premium_date": last_weekly_premium_date,
		"weekly_premium_used": weekly_premium_used,
		"summon_history": summon_history.duplicate(true),
		"total_summons": total_summons,
		"claimed_milestones": claimed_milestones.duplicate()
	}

func load_save_data(save_data: Dictionary):
	if save_data.has("pity_counters"):
		pity_counters = save_data.pity_counters.duplicate(true)
	if save_data.has("last_free_summon_date"):
		last_free_summon_date = save_data.last_free_summon_date
	if save_data.has("daily_free_used"):
		daily_free_used = save_data.daily_free_used
	if save_data.has("last_weekly_premium_date"):
		last_weekly_premium_date = save_data.last_weekly_premium_date
	if save_data.has("weekly_premium_used"):
		weekly_premium_used = save_data.weekly_premium_used
	if save_data.has("summon_history"):
		summon_history = save_data.summon_history.duplicate(true)
	if save_data.has("total_summons"):
		total_summons = save_data.total_summons
	if save_data.has("claimed_milestones"):
		claimed_milestones = save_data.claimed_milestones.duplicate()

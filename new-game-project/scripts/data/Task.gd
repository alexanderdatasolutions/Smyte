# Task.gd - Data class for territory tasks
# Tasks are jobs that gods can be assigned to in territories (RuneScape-style depth)
extends Resource
class_name Task

# ==============================================================================
# ENUMS
# ==============================================================================
enum TaskCategory {
	GATHERING,   # Mining, harvesting, fishing, hunting
	CRAFTING,    # Forging, alchemy, enchanting
	RESEARCH,    # Studying, experimenting
	DEFENSE,     # Guarding, patrolling
	SPECIAL      # Unique tasks
}

enum TaskRarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}

# ==============================================================================
# CORE PROPERTIES
# ==============================================================================
@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var category: TaskCategory = TaskCategory.GATHERING
@export var rarity: TaskRarity = TaskRarity.COMMON

# ==============================================================================
# REQUIREMENTS
# ==============================================================================
@export var required_territory_level: int = 1
@export var required_building_id: String = ""  # Building needed to unlock this task
@export var required_god_level: int = 1
@export var required_traits: Array[String] = []  # Traits god must have (any one)
@export var blocked_traits: Array[String] = []  # Traits that prevent assignment

# ==============================================================================
# TASK MECHANICS
# ==============================================================================
@export var base_duration_seconds: int = 3600  # 1 hour default
@export var base_experience: int = 100  # Task XP awarded on completion
@export var repeatable: bool = true  # Can be done multiple times
@export var max_concurrent_workers: int = 1  # How many gods can work on this simultaneously

# ==============================================================================
# REWARDS
# ==============================================================================
@export var resource_rewards: Dictionary = {}  # {"resource_id": base_amount}
@export var item_rewards: Array[Dictionary] = []  # [{id, chance, min, max}]
@export var experience_rewards: Dictionary = {}  # {"god_xp": amount, "territory_xp": amount}

# ==============================================================================
# SKILL INTEGRATION (RuneScape-style)
# ==============================================================================
@export var skill_id: String = ""  # Associated skill (e.g., "mining", "smithing")
@export var skill_xp_reward: int = 0  # Skill XP per completion
@export var skill_level_required: int = 0  # Minimum skill level to attempt
@export var skill_level_bonus_cap: int = 99  # Max level that provides bonus

# ==============================================================================
# DISPLAY
# ==============================================================================
@export var icon_path: String = ""
@export var animation_id: String = ""  # Animation to play while working

# ==============================================================================
# METHODS
# ==============================================================================

func get_duration_for_god(_god: God, trait_bonus: float = 0.0, skill_level: int = 0) -> int:
	"""Calculate actual task duration considering bonuses"""
	var duration = float(base_duration_seconds)

	# Apply trait bonus (reduces duration)
	if trait_bonus > 0:
		duration *= (1.0 - min(trait_bonus, 0.5))  # Cap at 50% reduction

	# Apply skill level bonus (1% reduction per level above requirement)
	if skill_level > skill_level_required:
		var skill_bonus = min((skill_level - skill_level_required) * 0.01, 0.3)  # Cap at 30%
		duration *= (1.0 - skill_bonus)

	return int(duration)

func get_rewards_for_god(_god: God, trait_bonus: float = 0.0, skill_level: int = 0) -> Dictionary:
	"""Calculate actual rewards considering bonuses"""
	var rewards = {}

	# Base resource rewards with trait bonus
	var resource_multiplier = 1.0 + trait_bonus
	for resource_id in resource_rewards:
		rewards[resource_id] = int(resource_rewards[resource_id] * resource_multiplier)

	# Add skill level bonus to resources
	if skill_level > skill_level_required:
		var skill_bonus = 1.0 + min((skill_level - skill_level_required) * 0.02, 0.5)  # 2% per level, cap 50%
		for resource_id in rewards:
			rewards[resource_id] = int(rewards[resource_id] * skill_bonus)

	return rewards

func can_god_perform(god: God) -> bool:
	"""Check if a god meets basic requirements for this task"""
	if not god:
		return false

	# Check god level
	if god.level < required_god_level:
		return false

	# Check blocked traits
	for blocked_trait in blocked_traits:
		if god.has_trait(blocked_trait):
			return false

	# If required traits exist, god must have at least one
	if required_traits.size() > 0:
		var has_required = false
		for required_trait in required_traits:
			if god.has_trait(required_trait):
				has_required = true
				break
		if not has_required:
			return false

	return true

func get_category_string() -> String:
	"""Get category as string"""
	match category:
		TaskCategory.GATHERING: return "gathering"
		TaskCategory.CRAFTING: return "crafting"
		TaskCategory.RESEARCH: return "research"
		TaskCategory.DEFENSE: return "defense"
		TaskCategory.SPECIAL: return "special"
		_: return "unknown"

func get_rarity_string() -> String:
	"""Get rarity as string"""
	match rarity:
		TaskRarity.COMMON: return "common"
		TaskRarity.UNCOMMON: return "uncommon"
		TaskRarity.RARE: return "rare"
		TaskRarity.EPIC: return "epic"
		TaskRarity.LEGENDARY: return "legendary"
		_: return "unknown"

# ==============================================================================
# SERIALIZATION
# ==============================================================================

static func from_dict(data: Dictionary):
	"""Create a Task from dictionary data"""
	var script = load("res://scripts/data/Task.gd")
	var new_task = script.new()

	new_task.id = data.get("id", "")
	new_task.name = data.get("name", "")
	new_task.description = data.get("description", "")

	# Parse category
	var category_str = data.get("category", "gathering")
	match category_str:
		"gathering": new_task.category = TaskCategory.GATHERING
		"crafting": new_task.category = TaskCategory.CRAFTING
		"research": new_task.category = TaskCategory.RESEARCH
		"defense": new_task.category = TaskCategory.DEFENSE
		"special": new_task.category = TaskCategory.SPECIAL

	# Parse rarity
	var rarity_str = data.get("rarity", "common")
	match rarity_str:
		"common": new_task.rarity = TaskRarity.COMMON
		"uncommon": new_task.rarity = TaskRarity.UNCOMMON
		"rare": new_task.rarity = TaskRarity.RARE
		"epic": new_task.rarity = TaskRarity.EPIC
		"legendary": new_task.rarity = TaskRarity.LEGENDARY

	# Requirements
	new_task.required_territory_level = data.get("required_territory_level", 1)
	new_task.required_building_id = data.get("required_building_id", "")
	new_task.required_god_level = data.get("required_god_level", 1)
	# Convert untyped arrays from JSON to typed arrays
	var req_traits = data.get("required_traits", [])
	for trait_id in req_traits:
		new_task.required_traits.append(trait_id)
	var blk_traits = data.get("blocked_traits", [])
	for trait_id in blk_traits:
		new_task.blocked_traits.append(trait_id)

	# Mechanics
	new_task.base_duration_seconds = data.get("base_duration_seconds", 3600)
	new_task.base_experience = data.get("base_experience", 100)
	new_task.repeatable = data.get("repeatable", true)
	new_task.max_concurrent_workers = data.get("max_concurrent_workers", 1)

	# Rewards
	new_task.resource_rewards = data.get("resource_rewards", {})
	# Convert untyped array from JSON to typed array
	var items = data.get("item_rewards", [])
	for item in items:
		new_task.item_rewards.append(item)
	new_task.experience_rewards = data.get("experience_rewards", {})

	# Skill integration
	new_task.skill_id = data.get("skill_id", "")
	new_task.skill_xp_reward = data.get("skill_xp_reward", 0)
	new_task.skill_level_required = data.get("skill_level_required", 0)
	new_task.skill_level_bonus_cap = data.get("skill_level_bonus_cap", 99)

	# Display
	new_task.icon_path = data.get("icon_path", "")
	new_task.animation_id = data.get("animation_id", "")

	return new_task

func to_dict() -> Dictionary:
	"""Convert Task to dictionary for serialization"""
	return {
		"id": id,
		"name": name,
		"description": description,
		"category": get_category_string(),
		"rarity": get_rarity_string(),
		"required_territory_level": required_territory_level,
		"required_building_id": required_building_id,
		"required_god_level": required_god_level,
		"required_traits": required_traits,
		"blocked_traits": blocked_traits,
		"base_duration_seconds": base_duration_seconds,
		"base_experience": base_experience,
		"repeatable": repeatable,
		"max_concurrent_workers": max_concurrent_workers,
		"resource_rewards": resource_rewards,
		"item_rewards": item_rewards,
		"experience_rewards": experience_rewards,
		"skill_id": skill_id,
		"skill_xp_reward": skill_xp_reward,
		"skill_level_required": skill_level_required,
		"skill_level_bonus_cap": skill_level_bonus_cap,
		"icon_path": icon_path,
		"animation_id": animation_id
	}

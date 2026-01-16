# scripts/data/GodTrait.gd
# Data class for god traits - affects task efficiency and specialization
# Note: Named GodTrait because 'Trait' is a reserved keyword in Godot 4
extends Resource
class_name GodTrait

enum TraitCategory {
	PRODUCTION,
	CRAFTING,
	KNOWLEDGE,
	COMBAT,
	LEADERSHIP,
	SPECIAL
}

enum TraitRarity {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY
}

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var category: TraitCategory = TraitCategory.PRODUCTION
@export var rarity: TraitRarity = TraitRarity.COMMON

# Task bonuses: {"task_id": bonus_multiplier}
# e.g., {"mine_ore": 0.5, "forge_equipment": 0.3}
@export var task_bonuses: Dictionary = {}

# Stat bonuses when god is in combat
# e.g., {"attack": 0.1, "defense": 0.05}
@export var combat_stat_bonuses: Dictionary = {}

# Special flags
@export var allows_multitask: bool = false
@export var multitask_count: int = 1
@export var multitask_efficiency: float = 1.0

# Visual
@export var icon_path: String = ""
@export var color: Color = Color.WHITE

func _init(trait_id: String = "", trait_name: String = ""):
	id = trait_id
	name = trait_name

# === TASK BONUS CALCULATIONS ===

func get_task_bonus(task_id: String) -> float:
	"""Get bonus multiplier for a specific task"""
	return task_bonuses.get(task_id, 0.0)

func has_task_bonus(task_id: String) -> bool:
	"""Check if this trait provides a bonus for a task"""
	return task_bonuses.has(task_id)

func get_all_task_bonuses() -> Dictionary:
	"""Get all task bonuses"""
	return task_bonuses.duplicate()

# === COMBAT STAT BONUSES ===

func get_combat_stat_bonus(stat_name: String) -> float:
	"""Get combat stat bonus"""
	return combat_stat_bonuses.get(stat_name, 0.0)

func get_all_combat_bonuses() -> Dictionary:
	"""Get all combat stat bonuses"""
	return combat_stat_bonuses.duplicate()

# === MULTITASKING ===

func can_multitask() -> bool:
	"""Check if this trait allows multitasking"""
	return allows_multitask and multitask_count > 1

func get_multitask_slots() -> int:
	"""Get number of task slots this trait provides"""
	return multitask_count if allows_multitask else 1

func get_multitask_efficiency() -> float:
	"""Get efficiency when multitasking"""
	return multitask_efficiency if allows_multitask else 1.0

# === CATEGORY HELPERS ===

static func category_to_string(cat: TraitCategory) -> String:
	match cat:
		TraitCategory.PRODUCTION: return "Production"
		TraitCategory.CRAFTING: return "Crafting"
		TraitCategory.KNOWLEDGE: return "Knowledge"
		TraitCategory.COMBAT: return "Combat"
		TraitCategory.LEADERSHIP: return "Leadership"
		TraitCategory.SPECIAL: return "Special"
		_: return "Unknown"

static func string_to_category(cat_string: String) -> TraitCategory:
	match cat_string.to_lower():
		"production": return TraitCategory.PRODUCTION
		"crafting": return TraitCategory.CRAFTING
		"knowledge": return TraitCategory.KNOWLEDGE
		"combat": return TraitCategory.COMBAT
		"leadership": return TraitCategory.LEADERSHIP
		"special": return TraitCategory.SPECIAL
		_: return TraitCategory.PRODUCTION

static func rarity_to_string(rar: TraitRarity) -> String:
	match rar:
		TraitRarity.COMMON: return "Common"
		TraitRarity.RARE: return "Rare"
		TraitRarity.EPIC: return "Epic"
		TraitRarity.LEGENDARY: return "Legendary"
		_: return "Common"

static func string_to_rarity(rar_string: String) -> TraitRarity:
	match rar_string.to_lower():
		"common": return TraitRarity.COMMON
		"rare": return TraitRarity.RARE
		"epic": return TraitRarity.EPIC
		"legendary": return TraitRarity.LEGENDARY
		_: return TraitRarity.COMMON

# === DISPLAY ===

func get_display_name() -> String:
	"""Get formatted display name with rarity"""
	return "[%s] %s" % [rarity_to_string(rarity), name]

func get_tooltip() -> String:
	"""Get full tooltip text"""
	var tooltip = "%s\n%s\n\n" % [name, description]

	if not task_bonuses.is_empty():
		tooltip += "Task Bonuses:\n"
		for task_id in task_bonuses:
			tooltip += "  • %s: +%d%%\n" % [task_id.replace("_", " ").capitalize(), int(task_bonuses[task_id] * 100)]

	if not combat_stat_bonuses.is_empty():
		tooltip += "Combat Bonuses:\n"
		for stat in combat_stat_bonuses:
			tooltip += "  • %s: +%d%%\n" % [stat.capitalize(), int(combat_stat_bonuses[stat] * 100)]

	if allows_multitask:
		tooltip += "\nSpecial: Can work on %d tasks at %d%% efficiency each" % [multitask_count, int(multitask_efficiency * 100)]

	return tooltip

# === SERIALIZATION ===

func to_dict() -> Dictionary:
	"""Serialize trait to dictionary"""
	return {
		"id": id,
		"name": name,
		"description": description,
		"category": category_to_string(category),
		"rarity": rarity_to_string(rarity),
		"task_bonuses": task_bonuses.duplicate(),
		"combat_stat_bonuses": combat_stat_bonuses.duplicate(),
		"allows_multitask": allows_multitask,
		"multitask_count": multitask_count,
		"multitask_efficiency": multitask_efficiency,
		"icon_path": icon_path
	}

static func from_dict(data: Dictionary):
	"""Create trait from dictionary"""
	var script = load("res://scripts/data/GodTrait.gd")
	var new_trait = script.new()
	new_trait.id = data.get("id", "")
	new_trait.name = data.get("name", "")
	new_trait.description = data.get("description", "")
	new_trait.category = string_to_category(data.get("category", "production"))
	new_trait.rarity = string_to_rarity(data.get("rarity", "common"))
	new_trait.task_bonuses = data.get("task_bonuses", {})
	new_trait.combat_stat_bonuses = data.get("combat_stat_bonuses", {})
	new_trait.allows_multitask = data.get("allows_multitask", false)
	new_trait.multitask_count = data.get("multitask_count", 1)
	new_trait.multitask_efficiency = data.get("multitask_efficiency", 1.0)
	new_trait.icon_path = data.get("icon_path", "")
	return new_trait

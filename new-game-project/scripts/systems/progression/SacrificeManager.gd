# scripts/systems/progression/SacrificeManager.gd
# Sacrifice management system - coordinates sacrifice operations and UI events
extends Node
class_name SacrificeManager

signal sacrifice_completed(target_god: God, material_gods: Array, xp_gained: int)
signal sacrifice_failed(reason: String)
signal awakening_completed(god: God)
signal awakening_failed(god: God, reason: String)

var sacrifice_system: SacrificeSystem
var awakening_system: AwakeningSystem
var event_bus: EventBus
var resource_manager: ResourceManager
var collection_manager: CollectionManager

# Temporary data for screen transitions
var temporary_target_god: God = null

static var _config: Dictionary = {}

static func _load_config() -> void:
	if not _config.is_empty():
		return
	var file: FileAccess = FileAccess.open("res://data/sacrifice_config.json", FileAccess.READ)
	if file:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			_config = parsed
			return
	_config = {}

static func _get_sacrifice_value_config() -> Dictionary:
	_load_config()
	return _config.get("sacrifice_value", {})

static func _get_awakening_ui_config() -> Dictionary:
	_load_config()
	return _config.get("awakening_ui", {})

func _ready() -> void:
	name = "SacrificeManager"

	var system_registry: Variant = SystemRegistry.get_instance()
	sacrifice_system = system_registry.get_system("SacrificeSystem")
	awakening_system = system_registry.get_system("AwakeningSystem")
	event_bus = system_registry.get_system("EventBus")
	resource_manager = system_registry.get_system("ResourceManager")
	collection_manager = system_registry.get_system("CollectionManager")

func perform_sacrifice(target_god: God, material_gods: Array[God]) -> Dictionary:
	if not sacrifice_system:
		var error: String = "SacrificeSystem not available"
		sacrifice_failed.emit(error)
		return {"success": false, "error": error}

	if not target_god or material_gods.is_empty():
		var error: String = "Invalid sacrifice parameters"
		sacrifice_failed.emit(error)
		return {"success": false, "error": error}

	var sacrifice_result: Dictionary = sacrifice_system.calculate_sacrifice_experience(material_gods, target_god)
	var success: bool = sacrifice_system.perform_sacrifice(target_god, material_gods, collection_manager)

	if success:
		sacrifice_completed.emit(target_god, material_gods, sacrifice_result.total_xp)

		var levels_gained: int = sacrifice_system.calculate_levels_gained(target_god, sacrifice_result.total_xp)
		if event_bus:
			event_bus.god_sacrificed.emit(target_god.id, sacrifice_result.total_xp)
			event_bus.collection_updated.emit()
			var material_ids: Array = []
			for mat_god: God in material_gods:
				material_ids.append(mat_god.id)
			event_bus.god_sacrifice_completed.emit({
				"target_god_id": target_god.id,
				"target_tier": target_god.tier,
				"material_count": material_gods.size(),
				"material_ids": material_ids,
				"total_xp": sacrifice_result.total_xp,
				"levels_gained": levels_gained
			})

		_show_sacrifice_notification(target_god, sacrifice_result.total_xp, levels_gained)

		return {
			"success": true,
			"xp_gained": sacrifice_result.total_xp,
			"levels_gained": levels_gained
		}
	else:
		var error: String = "Sacrifice operation failed"
		sacrifice_failed.emit(error)
		return {"success": false, "error": error}

func calculate_sacrifice_preview(target_god: God, material_gods: Array[God]) -> Dictionary:
	if not sacrifice_system or not target_god or material_gods.is_empty():
		return {"total_xp": 0, "levels_gained": 0, "bonus_details": [], "god_values": []}

	var sacrifice_result: Dictionary = sacrifice_system.calculate_sacrifice_experience(material_gods, target_god)
	sacrifice_result.levels_gained = sacrifice_system.calculate_levels_gained(target_god, sacrifice_result.total_xp)

	return sacrifice_result

func attempt_awakening(god: God) -> Dictionary:
	if not awakening_system:
		var error: String = "AwakeningSystem not available"
		awakening_failed.emit(god, error)
		return {"success": false, "error": error}

	var awakening_check: Dictionary = awakening_system.can_awaken_god(god)
	if not awakening_check.can_awaken:
		var error: String = "Cannot awaken god: " + str(awakening_check.missing_requirements)
		awakening_failed.emit(god, error)
		return {"success": false, "error": error}

	var success: bool = awakening_system.attempt_awakening(god)

	if success:
		awakening_completed.emit(god)

		if event_bus:
			event_bus.god_awakened.emit(god.id)
			event_bus.collection_updated.emit()
			event_bus.god_awakening_completed.emit({
				"god_id": god.id,
				"god_name": god.name,
				"element": GodFactory.element_to_string(god.element) if god.element else "unknown",
				"old_tier": god.tier - 1,
				"new_tier": god.tier
			})

		return {"success": true}
	else:
		var error: String = "Awakening operation failed"
		awakening_failed.emit(god, error)
		return {"success": false, "error": error}

func get_awakening_requirements(god: God) -> Dictionary:
	if not awakening_system:
		return {"can_awaken": false, "missing_requirements": ["AwakeningSystem not available"]}
	return awakening_system.can_awaken_god(god)

func get_awakening_materials_cost(god: God) -> Dictionary:
	if not awakening_system:
		return {}
	return awakening_system.get_awakening_materials_cost(god)

func check_awakening_materials(materials: Dictionary) -> Dictionary:
	if not awakening_system:
		return {"has_materials": false, "missing": []}
	return awakening_system.check_awakening_materials(materials)

func get_available_sacrifice_gods() -> Array[God]:
	if not collection_manager:
		return []

	var owned_gods: Array = collection_manager.get_owned_gods()
	var available_gods: Array[God] = []

	for god_data: Variant in owned_gods:
		var god: God = god_data.god
		if _can_sacrifice_god(god):
			available_gods.append(god)

	return available_gods

func get_available_awakening_gods() -> Array[God]:
	if not collection_manager:
		return []

	var owned_gods: Array = collection_manager.get_owned_gods()
	var awakening_gods: Array[God] = []

	for god_data: Variant in owned_gods:
		var god: God = god_data.god
		if _can_awaken_god_ui(god):
			awakening_gods.append(god)

	return awakening_gods

func _can_sacrifice_god(god: God) -> bool:
	if not god:
		return false
	if god.is_equipped() or god.is_assigned_to_territory():
		return false
	if god.is_awakened:
		return false
	return true

func _can_awaken_god_ui(god: God) -> bool:
	if not god:
		return false

	var ui_config: Dictionary = _get_awakening_ui_config()
	var min_tier: int = int(ui_config.get("min_tier_for_awakening", 4))

	if god.tier < min_tier:
		return false
	if god.level < God.get_max_level():
		return false
	if god.is_awakened:
		return false
	return true

func get_god_sacrifice_value(god: God) -> int:
	if not god:
		return 0

	var sv_config: Dictionary = _get_sacrifice_value_config()
	var base_value: int = int(sv_config.get("base_value", 100))
	var xp_per_level: int = int(sv_config.get("xp_per_level", 50))
	var xp_per_tier: int = int(sv_config.get("xp_per_tier", 300))
	var awaken_bonus: int = int(sv_config.get("awakening_bonus", 500))

	var level_bonus: int = god.level * xp_per_level
	var tier_bonus: int = int(god.tier) * xp_per_tier
	var awakening_bonus: int = awaken_bonus if god.is_awakened else 0

	return base_value + level_bonus + tier_bonus + awakening_bonus

func _show_sacrifice_notification(target_god: God, xp_gained: int, levels_gained: int) -> void:
	var NotificationQueueClass: Variant = load("res://scripts/ui/components/NotificationQueue.gd")
	if NotificationQueueClass:
		var msg: String = "%s gained %d XP" % [target_god.name, xp_gained]
		if levels_gained > 0:
			msg += " (+%d levels!)" % levels_gained
		NotificationQueueClass.show_reward("Sacrifice Complete!", msg)

# === SCREEN TRANSITION HELPERS ===

func set_temporary_target_god(god: God) -> void:
	temporary_target_god = god

func get_temporary_target_god() -> God:
	var god: God = temporary_target_god
	temporary_target_god = null
	return god

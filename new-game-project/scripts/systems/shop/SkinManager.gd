# scripts/systems/shop/SkinManager.gd
# Manages god skin ownership and purchasing
extends Node
class_name SkinManager

signal skin_purchased(skin_id: String)

# All available skins loaded from JSON
var _available_skins: Dictionary = {}  # skin_id -> skin data
var _skins_by_god: Dictionary = {}  # god_id -> Array of skin_ids

# Owned skins
var _owned_skins: Array = []  # Array of skin_ids

# System references
var _resource_manager: Node = null

func _ready() -> void:
	name = "SkinManagerSystem"

func initialize() -> void:
	_load_skin_data()
	_cache_system_references()

func _cache_system_references() -> void:
	var registry: Node = SystemRegistry.get_instance()
	if registry:
		_resource_manager = registry.get_system("ResourceManager")

func _load_skin_data() -> void:
	var file: FileAccess = FileAccess.open("res://data/god_skins.json", FileAccess.READ)
	if not file:
		push_error("SkinManager: Failed to load god_skins.json")
		return

	var json: JSON = JSON.new()
	var error: int = json.parse(file.get_as_text())
	file.close()

	if error != OK:
		push_error("SkinManager: Failed to parse god_skins.json")
		return

	var data: Variant = json.data
	if not data is Dictionary:
		push_error("SkinManager: god_skins.json root is not a Dictionary")
		return

	# Load skins
	if data.has("skins"):
		for skin: Variant in data.skins:
			if not skin is Dictionary:
				continue
			var skin_id: String = skin.get("id", "")
			if skin_id.is_empty():
				continue

			_available_skins[skin_id] = skin

			# Index by god
			var god_id: String = skin.get("god_id", "")
			if not _skins_by_god.has(god_id):
				_skins_by_god[god_id] = []
			_skins_by_god[god_id].append(skin_id)

# ==============================================================================
# SKIN QUERIES
# ==============================================================================

func get_all_skins() -> Array:
	return _available_skins.values()

func get_skin(skin_id: String) -> Dictionary:
	return _available_skins.get(skin_id, {})

func is_skin_owned(skin_id: String) -> bool:
	return skin_id in _owned_skins

# ==============================================================================
# SKIN PURCHASING
# ==============================================================================

func can_purchase_skin(skin_id: String) -> Dictionary:
	var skin: Dictionary = get_skin(skin_id)
	if skin.is_empty():
		return {"can_purchase": false, "reason": "Skin not found"}

	if is_skin_owned(skin_id):
		return {"can_purchase": false, "reason": "Already owned"}

	var cost: int = int(skin.get("cost_crystals", 0))
	if _resource_manager:
		var crystals: int = int(_resource_manager.get_resource("divine_crystals"))
		if crystals < cost:
			return {"can_purchase": false, "reason": "Not enough crystals", "cost": cost, "have": crystals}

	return {"can_purchase": true, "cost": cost}

func purchase_skin(skin_id: String) -> bool:
	var check: Dictionary = can_purchase_skin(skin_id)
	if not check.can_purchase:
		return false

	var skin: Dictionary = get_skin(skin_id)
	var cost: int = int(skin.get("cost_crystals", 0))

	# Deduct crystals
	if _resource_manager:
		if not _resource_manager.spend_resource("divine_crystals", cost):
			return false

	# Add to owned
	_owned_skins.append(skin_id)

	# Emit signal
	skin_purchased.emit(skin_id)

	return true

# ==============================================================================
# SAVE/LOAD
# ==============================================================================

func get_save_data() -> Dictionary:
	return {
		"owned_skins": _owned_skins.duplicate()
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("owned_skins"):
		_owned_skins = data.owned_skins.duplicate()

func shutdown() -> void:
	_owned_skins.clear()

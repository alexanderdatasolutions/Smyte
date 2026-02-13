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

# Currently equipped skins per god
var _equipped_skins: Dictionary = {}  # god_id -> skin_id

# Rarity colors from config
var _rarity_colors: Dictionary = {}

# System references
var _resource_manager: Node = null

func _ready():
	name = "SkinManagerSystem"

func initialize():
	_load_skin_data()
	_cache_system_references()

func _cache_system_references():
	var registry = SystemRegistry.get_instance()
	if registry:
		_resource_manager = registry.get_system("ResourceManager")

func _load_skin_data():
	var file = FileAccess.open("res://data/god_skins.json", FileAccess.READ)
	if not file:
		push_error("SkinManager: Failed to load god_skins.json")
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()

	if error != OK:
		push_error("SkinManager: Failed to parse god_skins.json")
		return

	var data = json.data

	# Load rarity colors
	if data.has("rarity_colors"):
		_rarity_colors = data.rarity_colors

	# Load skins
	if data.has("skins"):
		for skin in data.skins:
			var skin_id = skin.get("id", "")
			if skin_id.is_empty():
				continue

			_available_skins[skin_id] = skin

			# Index by god
			var god_id = skin.get("god_id", "")
			if not _skins_by_god.has(god_id):
				_skins_by_god[god_id] = []
			_skins_by_god[god_id].append(skin_id)

# ==============================================================================
# SKIN QUERIES
# ==============================================================================

func get_all_skins() -> Array:
	"""Get all available skins"""
	return _available_skins.values()

func get_skin(skin_id: String) -> Dictionary:
	"""Get skin data by ID"""
	return _available_skins.get(skin_id, {})

func is_skin_owned(skin_id: String) -> bool:
	"""Check if a skin is owned"""
	return skin_id in _owned_skins

# ==============================================================================
# SKIN PURCHASING
# ==============================================================================

func can_purchase_skin(skin_id: String) -> Dictionary:
	"""Check if a skin can be purchased"""
	var skin = get_skin(skin_id)
	if skin.is_empty():
		return {"can_purchase": false, "reason": "Skin not found"}

	if is_skin_owned(skin_id):
		return {"can_purchase": false, "reason": "Already owned"}

	var cost = skin.get("cost_crystals", 0)
	if _resource_manager:
		var crystals = _resource_manager.get_resource("divine_crystals")
		if crystals < cost:
			return {"can_purchase": false, "reason": "Not enough crystals", "cost": cost, "have": crystals}

	return {"can_purchase": true, "cost": cost}

func purchase_skin(skin_id: String) -> bool:
	"""Purchase a skin with crystals"""
	var check = can_purchase_skin(skin_id)
	if not check.can_purchase:
		return false

	var skin = get_skin(skin_id)
	var cost = skin.get("cost_crystals", 0)

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
		"owned_skins": _owned_skins.duplicate(),
		"equipped_skins": _equipped_skins.duplicate()
	}

func load_save_data(data: Dictionary):
	if data.has("owned_skins"):
		_owned_skins = data.owned_skins.duplicate()
	if data.has("equipped_skins"):
		_equipped_skins = data.equipped_skins.duplicate()

func shutdown():
	_owned_skins.clear()
	_equipped_skins.clear()

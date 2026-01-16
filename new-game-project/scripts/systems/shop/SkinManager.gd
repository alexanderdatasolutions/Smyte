# scripts/systems/shop/SkinManager.gd
# Manages god skin ownership, equipping, and portrait resolution
extends Node
class_name SkinManager

signal skin_purchased(skin_id: String)
signal skin_equipped(god_id: String, skin_id: String)
signal skin_unequipped(god_id: String)

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
var _collection_manager: Node = null
var _event_bus: Node = null

func _ready():
	name = "SkinManagerSystem"

func initialize():
	_load_skin_data()
	_cache_system_references()

func _cache_system_references():
	var registry = SystemRegistry.get_instance()
	if registry:
		_resource_manager = registry.get_system("ResourceManager")
		_collection_manager = registry.get_system("CollectionManager")
		_event_bus = registry.get_system("EventBus")

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

func get_skins_for_god(god_id: String) -> Array:
	"""Get all skins available for a specific god"""
	var skin_ids = _skins_by_god.get(god_id, [])
	var skins = []
	for skin_id in skin_ids:
		skins.append(_available_skins[skin_id])
	return skins

func get_owned_skins() -> Array:
	"""Get all owned skin IDs"""
	return _owned_skins.duplicate()

func is_skin_owned(skin_id: String) -> bool:
	"""Check if a skin is owned"""
	return skin_id in _owned_skins

func get_equipped_skin(god_id: String) -> String:
	"""Get the currently equipped skin for a god"""
	return _equipped_skins.get(god_id, "")

func get_rarity_color(rarity: String) -> String:
	"""Get the hex color for a rarity"""
	return _rarity_colors.get(rarity, "#FFFFFF")

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

	if _event_bus and _event_bus.has_signal("skin_purchased"):
		_event_bus.emit_signal("skin_purchased", skin_id)

	return true

# ==============================================================================
# SKIN EQUIPPING
# ==============================================================================

func equip_skin(god_id: String, skin_id: String) -> bool:
	"""Equip a skin to a god"""
	if not is_skin_owned(skin_id):
		return false

	var skin = get_skin(skin_id)
	if skin.get("god_id", "") != god_id:
		return false  # Skin doesn't belong to this god

	_equipped_skins[god_id] = skin_id
	skin_equipped.emit(god_id, skin_id)

	if _event_bus and _event_bus.has_signal("skin_equipped"):
		_event_bus.emit_signal("skin_equipped", god_id, skin_id)

	return true

func unequip_skin(god_id: String) -> bool:
	"""Remove equipped skin from a god"""
	if not _equipped_skins.has(god_id):
		return false

	_equipped_skins.erase(god_id)
	skin_unequipped.emit(god_id)

	if _event_bus and _event_bus.has_signal("skin_unequipped"):
		_event_bus.emit_signal("skin_unequipped", god_id)

	return true

# ==============================================================================
# PORTRAIT RESOLUTION
# ==============================================================================

func get_portrait_path(god_id: String, default_path: String = "") -> String:
	"""Get the portrait path for a god, considering equipped skin"""
	var equipped = get_equipped_skin(god_id)
	if equipped.is_empty():
		return default_path

	var skin = get_skin(equipped)
	if skin.is_empty():
		return default_path

	return skin.get("portrait_path", default_path)

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

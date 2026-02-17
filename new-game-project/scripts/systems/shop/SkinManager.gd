# scripts/systems/shop/SkinManager.gd
# Manages god skin ownership and purchasing
extends Node
class_name SkinManager

signal skin_purchased(skin_id: String)
signal skin_equipped(god_id: String, skin_id: String)
signal skin_unequipped(god_id: String)
signal skin_granted(skin_id: String)

# All available skins loaded from JSON
var _available_skins: Dictionary = {}  # skin_id -> skin data
var _skins_by_god: Dictionary = {}  # god_template_id -> Array of skin_ids

# Owned skins
var _owned_skins: Array = []  # Array of skin_ids

# Equipped skins per god instance
var _equipped_skins: Dictionary = {}  # god_id (instance) -> skin_id

# Pending free skin pick (set when legendary reaches L40)
var _pending_free_skin_god: String = ""

# System references
var _resource_manager: Node = null
var _collection_manager: Node = null

func _ready() -> void:
	name = "SkinManagerSystem"

func initialize() -> void:
	_load_skin_data()
	_cache_system_references()

func _cache_system_references() -> void:
	var registry: Node = SystemRegistry.get_instance()
	if registry:
		_resource_manager = registry.get_system("ResourceManager")
		_collection_manager = registry.get_system("CollectionManager")

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

func get_skins_for_god(god_id: String) -> Array:
	"""Get all available skins for a god (by template_id)"""
	var template_id: String = _get_god_template_id(god_id)
	return _skins_by_god.get(template_id, [])

func get_owned_skins_for_god(god_id: String) -> Array:
	"""Get owned skins for a specific god"""
	var template_id: String = _get_god_template_id(god_id)
	var available: Array = _skins_by_god.get(template_id, [])
	var owned: Array = []
	for skin_id: String in available:
		if is_skin_owned(skin_id):
			owned.append(skin_id)
	return owned

func _get_god_template_id(god_id: String) -> String:
	"""Get template_id from god instance ID"""
	if _collection_manager:
		var god: God = _collection_manager.get_god_by_id(god_id)
		if god:
			return god.template_id if god.template_id else god.id
	return god_id  # Fallback to god_id if not found

# ==============================================================================
# SKIN EQUIPPING
# ==============================================================================

func equip_skin(god_id: String, skin_id: String) -> bool:
	"""Equip a skin on a god"""
	if not is_skin_owned(skin_id):
		push_warning("SkinManager: Cannot equip unowned skin: %s" % skin_id)
		return false

	var skin: Dictionary = get_skin(skin_id)
	if skin.is_empty():
		return false

	# Verify skin is for this god's template
	var template_id: String = _get_god_template_id(god_id)
	if skin.get("god_id", "") != template_id:
		push_warning("SkinManager: Skin %s is not for god template %s" % [skin_id, template_id])
		return false

	# Update god's equipped_skin_id
	if _collection_manager:
		var god: God = _collection_manager.get_god_by_id(god_id)
		if god:
			god.equipped_skin_id = skin_id

	_equipped_skins[god_id] = skin_id
	skin_equipped.emit(god_id, skin_id)
	print("SkinManager: Equipped skin '%s' on god '%s'" % [skin_id, god_id])
	return true

func unequip_skin(god_id: String) -> bool:
	"""Remove equipped skin from a god"""
	if _collection_manager:
		var god: God = _collection_manager.get_god_by_id(god_id)
		if god:
			god.equipped_skin_id = ""

	_equipped_skins.erase(god_id)
	skin_unequipped.emit(god_id)
	print("SkinManager: Unequipped skin from god '%s'" % god_id)
	return true

func get_equipped_skin(god_id: String) -> String:
	"""Get the equipped skin ID for a god"""
	return _equipped_skins.get(god_id, "")

func grant_skin(skin_id: String) -> bool:
	"""Grant a skin for free (achievement reward)"""
	if is_skin_owned(skin_id):
		return false

	var skin: Dictionary = get_skin(skin_id)
	if skin.is_empty():
		push_warning("SkinManager: Cannot grant unknown skin: %s" % skin_id)
		return false

	_owned_skins.append(skin_id)
	skin_granted.emit(skin_id)
	print("SkinManager: Granted free skin '%s'" % skin_id)
	return true

# ==============================================================================
# PENDING FREE SKIN (Achievement reward)
# ==============================================================================

func set_pending_free_skin_god(god_id: String) -> void:
	"""Set the god that triggered the skin unlock (for free skin pick)"""
	_pending_free_skin_god = god_id
	print("SkinManager: Pending free skin pick for god '%s'" % god_id)

func get_pending_free_skin_god() -> String:
	"""Get the god waiting for a free skin pick"""
	return _pending_free_skin_god

func clear_pending_free_skin_god() -> void:
	"""Clear the pending free skin pick"""
	_pending_free_skin_god = ""

# ==============================================================================
# PORTRAIT RESOLUTION
# ==============================================================================

func get_portrait_path_for_god(god: God) -> String:
	"""Get the correct portrait path for a god, considering equipped skin"""
	if god and god.equipped_skin_id != "":
		var skin: Dictionary = get_skin(god.equipped_skin_id)
		if not skin.is_empty():
			var skin_path: String = skin.get("portrait_path", "")
			if skin_path != "" and ResourceLoader.exists(skin_path):
				return skin_path

	# Fallback to default portrait
	var template_id: String = god.template_id if god.template_id else god.id
	return "res://assets/gods/" + template_id + ".png"

func get_portrait_path_from_data(god_data: Dictionary) -> String:
	"""Get portrait path from serialized god data (for PvP opponents)"""
	var skin_id: String = god_data.get("equipped_skin_id", "")
	if skin_id != "":
		var skin: Dictionary = get_skin(skin_id)
		if not skin.is_empty():
			var skin_path: String = skin.get("portrait_path", "")
			if skin_path != "" and ResourceLoader.exists(skin_path):
				return skin_path

	# Fallback to default
	var template_id: String = god_data.get("template_id", god_data.get("id", ""))
	return "res://assets/gods/" + template_id + ".png"

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
		"owned_skins": _owned_skins.duplicate(),
		"equipped_skins": _equipped_skins.duplicate()
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("owned_skins"):
		_owned_skins = data.owned_skins.duplicate()
	if data.has("equipped_skins"):
		_equipped_skins = data.equipped_skins.duplicate()

	# Sync equipped skins to God objects (deferred to ensure CollectionManager is ready)
	call_deferred("_sync_equipped_skins_to_gods")

func _sync_equipped_skins_to_gods() -> void:
	"""Sync equipped_skins dictionary to God.equipped_skin_id on load"""
	if not _collection_manager:
		_cache_system_references()

	if not _collection_manager:
		return

	for god_id: String in _equipped_skins:
		var god: God = _collection_manager.get_god_by_id(god_id)
		if god:
			god.equipped_skin_id = _equipped_skins[god_id]

func shutdown() -> void:
	_owned_skins.clear()
	_equipped_skins.clear()
	_pending_free_skin_god = ""

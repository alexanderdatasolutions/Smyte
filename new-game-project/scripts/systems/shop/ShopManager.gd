# scripts/systems/shop/ShopManager.gd
# Main shop orchestration - handles crystal packs and shop navigation
extends Node
class_name ShopManager

signal crystals_purchased(pack_id: String, amount: int)
signal special_offer_purchased(offer_id: String)

# Shop data loaded from JSON
var _crystal_packs: Array = []
var _special_offers: Array = []

# Track purchase history (for future analytics)
var _purchase_history: Array = []

# Active subscription tracking
var _active_subscriptions: Dictionary = {}  # offer_id -> expiry_timestamp

# System references
var _resource_manager: Node = null
var _event_bus: Node = null
var _skin_manager: Node = null

func _ready():
	name = "ShopManagerSystem"

func initialize():
	_load_shop_data()
	_cache_system_references()

func _cache_system_references():
	var registry = SystemRegistry.get_instance()
	if registry:
		_resource_manager = registry.get_system("ResourceManager")
		_event_bus = registry.get_system("EventBus")
		_skin_manager = registry.get_system("SkinManager")

func _load_shop_data():
	var file = FileAccess.open("res://data/shop_items.json", FileAccess.READ)
	if not file:
		push_error("ShopManager: Failed to load shop_items.json")
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()

	if error != OK:
		push_error("ShopManager: Failed to parse shop_items.json")
		return

	var data = json.data

	if data.has("crystal_packs"):
		_crystal_packs = data.crystal_packs

	if data.has("special_offers"):
		_special_offers = data.special_offers

# ==============================================================================
# CRYSTAL PACKS
# ==============================================================================

func get_crystal_packs() -> Array:
	"""Get all available crystal packs"""
	return _crystal_packs.duplicate()

func get_crystal_pack(pack_id: String) -> Dictionary:
	"""Get a specific crystal pack by ID"""
	for pack in _crystal_packs:
		if pack.get("id", "") == pack_id:
			return pack
	return {}

func get_featured_packs() -> Array:
	"""Get featured/best value packs"""
	var featured = []
	for pack in _crystal_packs:
		if pack.get("featured", false) or pack.get("best_value", false):
			featured.append(pack)
	return featured

func purchase_crystal_pack(pack_id: String) -> bool:
	"""
	Purchase a crystal pack.
	NOTE: This is a placeholder for real IAP integration.
	In production, this would go through platform-specific IAP.
	"""
	var pack = get_crystal_pack(pack_id)
	if pack.is_empty():
		return false

	var base_crystals = pack.get("crystals", 0)
	var bonus_crystals = pack.get("bonus", 0)
	var total = base_crystals + bonus_crystals

	# Add crystals
	if _resource_manager:
		_resource_manager.add_resource("divine_crystals", total)

	# Record purchase
	_record_purchase({
		"type": "crystal_pack",
		"pack_id": pack_id,
		"crystals": total,
		"price_usd": pack.get("price_usd", 0),
		"timestamp": Time.get_unix_time_from_system()
	})

	crystals_purchased.emit(pack_id, total)

	if _event_bus and _event_bus.has_signal("crystals_purchased"):
		_event_bus.emit_signal("crystals_purchased", pack_id, total)

	return true

# ==============================================================================
# SPECIAL OFFERS
# ==============================================================================

func get_special_offers() -> Array:
	"""Get all special offers"""
	return _special_offers.duplicate()

func get_special_offer(offer_id: String) -> Dictionary:
	"""Get a specific offer by ID"""
	for offer in _special_offers:
		if offer.get("id", "") == offer_id:
			return offer
	return {}

func can_purchase_offer(offer_id: String) -> Dictionary:
	"""Check if an offer can be purchased"""
	var offer = get_special_offer(offer_id)
	if offer.is_empty():
		return {"can_purchase": false, "reason": "Offer not found"}

	# Check one-time purchase
	if offer.get("one_time_purchase", false):
		if _has_purchased_offer(offer_id):
			return {"can_purchase": false, "reason": "Already purchased"}

	# Check active subscription
	if offer.has("duration_days"):
		if is_subscription_active(offer_id):
			return {"can_purchase": false, "reason": "Subscription still active"}

	return {"can_purchase": true, "price": offer.get("price_usd", 0)}

func purchase_special_offer(offer_id: String) -> bool:
	"""
	Purchase a special offer.
	NOTE: This is a placeholder for real IAP integration.
	"""
	var check = can_purchase_offer(offer_id)
	if not check.can_purchase:
		return false

	var offer = get_special_offer(offer_id)

	# Apply immediate rewards
	if offer.has("rewards"):
		_apply_rewards(offer.rewards)
	if offer.has("immediate_reward"):
		_apply_rewards(offer.immediate_reward)

	# Setup subscription if applicable
	if offer.has("duration_days"):
		var duration_seconds = offer.duration_days * 24 * 60 * 60
		_active_subscriptions[offer_id] = Time.get_unix_time_from_system() + duration_seconds

	# Record purchase
	_record_purchase({
		"type": "special_offer",
		"offer_id": offer_id,
		"price_usd": offer.get("price_usd", 0),
		"timestamp": Time.get_unix_time_from_system()
	})

	special_offer_purchased.emit(offer_id)

	return true

func is_subscription_active(offer_id: String) -> bool:
	"""Check if a subscription is currently active"""
	if not _active_subscriptions.has(offer_id):
		return false
	return Time.get_unix_time_from_system() < _active_subscriptions[offer_id]

func get_subscription_days_remaining(offer_id: String) -> int:
	"""Get days remaining on a subscription"""
	if not is_subscription_active(offer_id):
		return 0
	var remaining = _active_subscriptions[offer_id] - Time.get_unix_time_from_system()
	return int(remaining / (24 * 60 * 60))

func claim_daily_reward(offer_id: String) -> bool:
	"""Claim daily reward from an active subscription"""
	if not is_subscription_active(offer_id):
		return false

	var offer = get_special_offer(offer_id)
	if not offer.has("daily_reward"):
		return false

	_apply_rewards(offer.daily_reward)
	return true

# ==============================================================================
# SKIN SHOP INTEGRATION
# ==============================================================================

func get_available_skins() -> Array:
	"""Get all available skins from SkinManager"""
	if _skin_manager:
		return _skin_manager.get_all_skins()
	return []

func get_skins_for_god(god_id: String) -> Array:
	"""Get skins for a specific god"""
	if _skin_manager:
		return _skin_manager.get_skins_for_god(god_id)
	return []

func purchase_skin(skin_id: String) -> bool:
	"""Purchase a skin through SkinManager"""
	if _skin_manager:
		return _skin_manager.purchase_skin(skin_id)
	return false

# ==============================================================================
# HELPER METHODS
# ==============================================================================

func _apply_rewards(rewards: Dictionary):
	"""Apply a set of rewards to the player"""
	if not _resource_manager:
		return

	for resource_type in rewards:
		var amount = rewards[resource_type]
		_resource_manager.add_resource(resource_type, amount)

func _record_purchase(purchase_data: Dictionary):
	"""Record a purchase for history/analytics"""
	_purchase_history.append(purchase_data)

func _has_purchased_offer(offer_id: String) -> bool:
	"""Check if a one-time offer has been purchased"""
	for purchase in _purchase_history:
		if purchase.get("type") == "special_offer" and purchase.get("offer_id") == offer_id:
			return true
	return false

# ==============================================================================
# SAVE/LOAD
# ==============================================================================

func get_save_data() -> Dictionary:
	return {
		"purchase_history": _purchase_history.duplicate(),
		"active_subscriptions": _active_subscriptions.duplicate()
	}

func load_save_data(data: Dictionary):
	if data.has("purchase_history"):
		_purchase_history = data.purchase_history.duplicate()
	if data.has("active_subscriptions"):
		_active_subscriptions = data.active_subscriptions.duplicate()

func shutdown():
	_purchase_history.clear()
	_active_subscriptions.clear()

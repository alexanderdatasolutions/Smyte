# scripts/utilities/GodUIHelpers.gd
# Centralized element, tier, and rarity color/name helpers for UI
extends RefCounted
class_name GodUIHelpers

# =============================================================================
# ELEMENT COLORS - Canonical values using God.ElementType enum
# =============================================================================

static func get_element_color(element: God.ElementType) -> Color:
	match element:
		God.ElementType.FIRE: return Color(1.0, 0.4, 0.2)
		God.ElementType.WATER: return Color(0.3, 0.6, 1.0)
		God.ElementType.EARTH: return Color(0.6, 0.45, 0.2)
		God.ElementType.LIGHTNING: return Color(1.0, 0.9, 0.3)
		God.ElementType.LIGHT: return Color(1.0, 1.0, 0.8)
		God.ElementType.DARK: return Color(0.5, 0.3, 0.6)
		_: return Color(0.5, 0.5, 0.5)

static func get_element_color_from_string(element: String) -> Color:
	match element.to_lower():
		"fire": return Color(1.0, 0.4, 0.2)
		"water": return Color(0.3, 0.6, 1.0)
		"earth": return Color(0.6, 0.45, 0.2)
		"lightning": return Color(1.0, 0.9, 0.3)
		"air": return Color(0.8, 0.9, 1.0)
		"light": return Color(1.0, 1.0, 0.8)
		"dark": return Color(0.5, 0.3, 0.6)
		"nature": return Color(0.3, 0.7, 0.3)
		_: return Color(0.5, 0.5, 0.5)

# =============================================================================
# ELEMENT NAMES
# =============================================================================

static func get_element_name(element: God.ElementType) -> String:
	match element:
		God.ElementType.FIRE: return "Fire"
		God.ElementType.WATER: return "Water"
		God.ElementType.EARTH: return "Earth"
		God.ElementType.LIGHTNING: return "Lightning"
		God.ElementType.LIGHT: return "Light"
		God.ElementType.DARK: return "Dark"
		_: return "Unknown"

static func get_element_name_with_emoji(element: God.ElementType) -> String:
	match element:
		God.ElementType.FIRE: return "🔥 Fire"
		God.ElementType.WATER: return "💧 Water"
		God.ElementType.EARTH: return "🌍 Earth"
		God.ElementType.LIGHTNING: return "⚡ Lightning"
		God.ElementType.LIGHT: return "✨ Light"
		God.ElementType.DARK: return "🌙 Dark"
		_: return "⚪ Neutral"

static func get_element_name_from_int(element_id: int) -> String:
	if element_id >= 0 and element_id <= 5:
		return get_element_name(element_id as God.ElementType)
	return "Unknown"

static func get_element_emoji(element: God.ElementType) -> String:
	match element:
		God.ElementType.FIRE: return "🔥"
		God.ElementType.WATER: return "💧"
		God.ElementType.EARTH: return "🌍"
		God.ElementType.LIGHTNING: return "⚡"
		God.ElementType.LIGHT: return "✨"
		God.ElementType.DARK: return "🌑"
		_: return "?"

# =============================================================================
# TIER COLORS - Using God.TierType enum (0-based: COMMON=0, RARE=1, EPIC=2, LEGENDARY=3)
# =============================================================================

static func get_tier_color(tier: God.TierType) -> Color:
	match tier:
		God.TierType.COMMON: return Color(0.6, 0.6, 0.6)
		God.TierType.RARE: return Color(0.4, 0.8, 0.4)
		God.TierType.EPIC: return Color(0.7, 0.4, 1.0)
		God.TierType.LEGENDARY: return Color(1.0, 0.8, 0.2)
		_: return Color.WHITE

static func get_subtle_tier_color(tier: God.TierType) -> Color:
	match tier:
		God.TierType.COMMON: return Color(0.25, 0.25, 0.25, 0.7)
		God.TierType.RARE: return Color(0.2, 0.3, 0.2, 0.7)
		God.TierType.EPIC: return Color(0.3, 0.2, 0.4, 0.7)
		God.TierType.LEGENDARY: return Color(0.4, 0.3, 0.1, 0.7)
		_: return Color(0.2, 0.2, 0.3, 0.7)

static func get_tier_border_color(tier: God.TierType) -> Color:
	match tier:
		God.TierType.COMMON: return Color(0.5, 0.5, 0.5, 0.8)
		God.TierType.RARE: return Color(0.4, 0.8, 0.4)
		God.TierType.EPIC: return Color(0.7, 0.4, 1.0)
		God.TierType.LEGENDARY: return Color(1.0, 0.8, 0.2)
		_: return Color(0.6, 0.6, 0.6, 0.8)

# =============================================================================
# TIER NAMES
# =============================================================================

static func get_tier_name(tier: God.TierType) -> String:
	match tier:
		God.TierType.COMMON: return "Common"
		God.TierType.RARE: return "Rare"
		God.TierType.EPIC: return "Epic"
		God.TierType.LEGENDARY: return "Legendary"
		_: return "Unknown"

static func get_tier_short_name(tier: God.TierType) -> String:
	match tier:
		God.TierType.COMMON: return "Common"
		God.TierType.RARE: return "Rare"
		God.TierType.EPIC: return "Epic"
		God.TierType.LEGENDARY: return "Legend"
		_: return "Unknown"

static func get_tier_stars(tier: God.TierType) -> String:
	match tier:
		God.TierType.COMMON: return "★"
		God.TierType.RARE: return "★★"
		God.TierType.EPIC: return "★★★"
		God.TierType.LEGENDARY: return "★★★★"
		_: return "?"

static func get_tier_stars_emoji(tier: God.TierType) -> String:
	match tier:
		God.TierType.COMMON: return "⭐"
		God.TierType.RARE: return "⭐⭐"
		God.TierType.EPIC: return "⭐⭐⭐"
		God.TierType.LEGENDARY: return "⭐⭐⭐⭐"
		_: return "⭐"

static func get_tier_name_with_stars(tier: God.TierType) -> String:
	return "%s %s" % [get_tier_name(tier), get_tier_stars(tier)]

# =============================================================================
# RARITY COLORS - For equipment (Equipment.Rarity enum)
# =============================================================================

static func get_rarity_color(rarity: Equipment.Rarity) -> Color:
	match rarity:
		Equipment.Rarity.COMMON: return Color(0.6, 0.6, 0.6)
		Equipment.Rarity.RARE: return Color(0.4, 0.8, 0.4)
		Equipment.Rarity.EPIC: return Color(0.6, 0.4, 0.9)
		Equipment.Rarity.LEGENDARY: return Color(1.0, 0.8, 0.2)
		Equipment.Rarity.MYTHIC: return Color(1.0, 0.4, 0.4)
		_: return Color.WHITE

static func get_rarity_color_from_string(rarity: String) -> Color:
	match rarity.to_lower():
		"common": return Color(0.6, 0.6, 0.6)
		"uncommon": return Color(0.4, 0.8, 0.4)
		"rare": return Color(0.4, 0.6, 1.0)
		"epic": return Color(0.7, 0.4, 0.9)
		"legendary": return Color(1.0, 0.8, 0.2)
		"mythic": return Color(1.0, 0.4, 0.4)
		_: return Color(0.7, 0.7, 0.7)

static func get_rarity_color_from_int(rarity: int) -> Color:
	if rarity >= 0 and rarity <= 4:
		return get_rarity_color(rarity as Equipment.Rarity)
	return Color.WHITE

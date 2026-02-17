# scripts/utilities/GodPortraitHelper.gd
# Centralized helper for loading god portraits with skin support
# RULE 2: Single responsibility - portrait path resolution
class_name GodPortraitHelper
extends RefCounted

## Get the correct portrait path for a God object, considering equipped skin
static func get_portrait_path(god: God) -> String:
	if god == null:
		return ""

	# Check for equipped skin first
	if god.equipped_skin_id != "":
		var registry: Node = SystemRegistry.get_instance()
		var skin_manager: Node = registry.get_system("SkinManager") if registry else null
		if skin_manager:
			var skin: Dictionary = skin_manager.get_skin(god.equipped_skin_id)
			var skin_path: String = skin.get("portrait_path", "")
			if skin_path != "" and ResourceLoader.exists(skin_path):
				return skin_path

	# Fallback to default portrait
	var template_id: String = god.template_id if god.template_id else god.id
	return "res://assets/gods/" + template_id + ".png"

## Get portrait path from serialized god data (for PvP opponents)
static func get_portrait_path_from_data(god_data: Dictionary) -> String:
	if god_data.is_empty():
		return ""

	var skin_id: String = god_data.get("equipped_skin_id", "")
	if skin_id != "":
		var registry: Node = SystemRegistry.get_instance()
		var skin_manager: Node = registry.get_system("SkinManager") if registry else null
		if skin_manager:
			var skin: Dictionary = skin_manager.get_skin(skin_id)
			var skin_path: String = skin.get("portrait_path", "")
			if skin_path != "" and ResourceLoader.exists(skin_path):
				return skin_path

	# Fallback to default
	var template_id: String = god_data.get("template_id", god_data.get("id", ""))
	return "res://assets/gods/" + template_id + ".png"

## Load and return the portrait texture for a god
static func load_portrait_texture(god: God) -> Texture2D:
	var path: String = get_portrait_path(god)
	if ResourceLoader.exists(path):
		return load(path)
	return null

## Load portrait texture from dictionary data (for PvP opponents)
static func load_portrait_texture_from_data(god_data: Dictionary) -> Texture2D:
	var path: String = get_portrait_path_from_data(god_data)
	if ResourceLoader.exists(path):
		return load(path)
	return null

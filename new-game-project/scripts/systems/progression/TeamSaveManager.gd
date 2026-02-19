# scripts/systems/progression/TeamSaveManager.gd
# Manages saved team compositions - save, load, delete named teams
class_name TeamSaveManager
extends Node

signal teams_changed  # Emitted when saved teams are loaded or modified

const MAX_SAVED_TEAMS: int = 10

# Saved teams: { "team_name": ["god_template_id1", "god_template_id2", ...] }
var _saved_teams: Dictionary = {}

func _ready() -> void:
	_load_from_save()
	_connect_to_save_manager()

func _connect_to_save_manager() -> void:
	"""Connect to SaveManager's load_completed signal to reload when cloud data arrives"""
	var registry: Node = SystemRegistry.get_instance()
	var save_manager: Node = registry.get_system("SaveManager") if registry else null
	if save_manager and save_manager.has_signal("load_completed"):
		if not save_manager.load_completed.is_connected(_on_save_loaded):
			save_manager.load_completed.connect(_on_save_loaded)

func _on_save_loaded(_success: bool, _data: Dictionary) -> void:
	"""Reload saved teams when cloud data is loaded"""
	_load_from_save()
	teams_changed.emit()

## Save a team with a given name
func save_team(team_name: String, god_ids: Array) -> bool:
	if team_name.is_empty():
		return false

	if _saved_teams.size() >= MAX_SAVED_TEAMS and not _saved_teams.has(team_name):
		push_warning("TeamSaveManager: Maximum saved teams reached (%d)" % MAX_SAVED_TEAMS)
		return false

	# Store template IDs only (not instance IDs)
	var template_ids: Array = []
	for god_id in god_ids:
		if god_id and god_id is String and not god_id.is_empty():
			template_ids.append(god_id)

	if template_ids.is_empty():
		return false

	_saved_teams[team_name] = template_ids
	_persist_to_save()
	teams_changed.emit()
	return true

## Load a saved team by name - returns array of template IDs
func load_team(team_name: String) -> Array:
	return _saved_teams.get(team_name, []).duplicate()

## Delete a saved team
func delete_team(team_name: String) -> bool:
	if _saved_teams.has(team_name):
		_saved_teams.erase(team_name)
		_persist_to_save()
		teams_changed.emit()
		return true
	return false

## Rename a saved team
func rename_team(old_name: String, new_name: String) -> bool:
	if not _saved_teams.has(old_name) or new_name.is_empty():
		return false
	if _saved_teams.has(new_name):
		return false  # Name already exists

	var team_data: Array = _saved_teams[old_name]
	_saved_teams.erase(old_name)
	_saved_teams[new_name] = team_data
	_persist_to_save()
	return true

## Get all saved team names
func get_saved_team_names() -> Array:
	return _saved_teams.keys()

## Get saved team count
func get_saved_team_count() -> int:
	return _saved_teams.size()

## Check if a team name exists
func has_team(team_name: String) -> bool:
	return _saved_teams.has(team_name)

## Get team preview info (god names) for display
func get_team_preview(team_name: String) -> Array:
	var template_ids: Array = _saved_teams.get(team_name, [])
	var preview: Array = []

	var registry: Node = SystemRegistry.get_instance()
	var config_manager: Node = registry.get_system("ConfigurationManager") if registry else null

	for template_id: String in template_ids:
		if config_manager:
			var god_config: Dictionary = config_manager.get_god_config(template_id)
			preview.append(god_config.get("name", template_id))
		else:
			preview.append(template_id)

	return preview

## Convert saved template IDs to actual God instances from player's collection
func resolve_team_to_gods(team_name: String) -> Array:
	var template_ids: Array = _saved_teams.get(team_name, [])
	var gods: Array = []

	var registry: Node = SystemRegistry.get_instance()
	var collection_manager: CollectionManager = registry.get_system("CollectionManager") if registry else null

	if not collection_manager:
		return gods

	for template_id: String in template_ids:
		# Find the player's god instance with this template
		var god: God = collection_manager.get_god_by_template_id(template_id)
		if god:
			gods.append(god)

	return gods

## Get save data for persistence
func get_save_data() -> Dictionary:
	return {
		"saved_teams": _saved_teams.duplicate(true)
	}

## Load from save data
func load_save_data(data: Dictionary) -> void:
	_saved_teams = data.get("saved_teams", {}).duplicate(true)

## Load saved teams from main save
func _load_from_save() -> void:
	var registry: Node = SystemRegistry.get_instance()
	var save_manager: Node = registry.get_system("SaveManager") if registry else null
	if save_manager:
		var data: Variant = save_manager.get_player_value("saved_teams", {})
		if data is Dictionary and not data.is_empty():
			_saved_teams = data.duplicate(true)

## Persist saved teams to main save
func _persist_to_save() -> void:
	var registry: Node = SystemRegistry.get_instance()
	var save_manager: Node = registry.get_system("SaveManager") if registry else null
	if save_manager:
		save_manager.set_player_value("saved_teams", _saved_teams.duplicate(true))
		save_manager.save_game()

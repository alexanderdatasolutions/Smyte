# scripts/utilities/JSONDataLoader.gd
# Replaces 10+ duplicate JSON loading implementations across the codebase
# Note: class_name is derived from filename (JSONDataLoader.gd -> JSONDataLoader)
extends RefCounted

# Cache for loaded JSON data to avoid repeated file I/O
static var _cache: Dictionary = {}
static var _cache_enabled: bool = true

## Load a single JSON file and return its data as Dictionary
static func load_file(path: String) -> Dictionary:
	# Check cache first if enabled
	if _cache_enabled and _cache.has(path):
		return _cache[path].duplicate()
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("JSONDataLoader: Could not open file: " + path)
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		push_error("JSONDataLoader: Error parsing JSON from " + path + ": " + json.error_string)
		return {}
	
	var data = json.data
	
	# Cache the result if caching is enabled
	if _cache_enabled:
		_cache[path] = data.duplicate()
	
	return data

## Load multiple JSON files and merge them into a single Dictionary
static func load_files(paths: Array) -> Dictionary:
	var result = {}
	for path in paths:
		var file_data = load_file(path)
		result.merge(file_data)
	return result

## Load JSON files from a directory matching a pattern
static func load_directory(dir_path: String, file_pattern: String = "*.json") -> Dictionary:
	var result = {}
	var dir = DirAccess.open(dir_path)
	
	if not dir:
		push_error("JSONDataLoader: Could not open directory: " + dir_path)
		return {}
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.match(file_pattern):
			var file_path = dir_path + "/" + file_name
			var file_data = load_file(file_path)
			
			# Use filename without extension as key
			var key = file_name.get_basename()
			result[key] = file_data
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return result

## Validate that required fields exist in loaded data
static func validate_data(data: Dictionary, required_fields: Array) -> bool:
	for field in required_fields:
		if not data.has(field):
			push_error("JSONDataLoader: Missing required field: " + field)
			return false
	return true

## Clear the JSON cache
static func clear_cache():
	_cache.clear()

## Enable/disable caching
static func set_cache_enabled(enabled: bool):
	_cache_enabled = enabled
	if not enabled:
		clear_cache()

## Get cache statistics for debugging
static func get_cache_stats() -> Dictionary:
	return {
		"enabled": _cache_enabled,
		"cached_files": _cache.size(),
		"files": _cache.keys()
	}

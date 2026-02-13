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

extends Node
## Note: No class_name to avoid conflict with autoload singleton

## Test harness for automated UI testing via MCP
## Listens on TCP port for commands and executes them against the running game

const PORT = 9999
const POLL_INTERVAL = 0.05  # 50ms polling

var _server: TCPServer
var _client: StreamPeerTCP
var _buffer: String = ""

signal command_received(command: Dictionary)
signal response_sent(response: Dictionary)


func _ready() -> void:
	_server = TCPServer.new()
	var err = _server.listen(PORT)
	if err != OK:
		push_error("TestHarness: Failed to listen on port %d: %s" % [PORT, error_string(err)])
		return
	print("TestHarness: Listening on port %d" % PORT)


func _process(_delta: float) -> void:
	_check_for_connections()
	_read_client_data()


func _check_for_connections() -> void:
	if _server and _server.is_connection_available():
		_client = _server.take_connection()
		print("TestHarness: Client connected")


func _read_client_data() -> void:
	if not _client or _client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return

	var available = _client.get_available_bytes()
	if available > 0:
		var data = _client.get_utf8_string(available)
		_buffer += data
		_process_buffer()


func _process_buffer() -> void:
	# Commands are newline-delimited JSON
	while "\n" in _buffer:
		var newline_pos = _buffer.find("\n")
		var line = _buffer.substr(0, newline_pos)
		_buffer = _buffer.substr(newline_pos + 1)

		if line.strip_edges().is_empty():
			continue

		var json = JSON.new()
		var parse_result = json.parse(line)
		if parse_result != OK:
			_send_error("Invalid JSON: " + json.get_error_message())
			continue

		var command = json.data
		if command is Dictionary:
			command_received.emit(command)
			_handle_command(command)


func _handle_command(command: Dictionary) -> void:
	var action = command.get("action", "")
	var response: Dictionary

	match action:
		"ping":
			response = {"success": true, "result": "pong"}

		"get_current_screen":
			response = _get_current_screen()

		"get_visible_screens":
			response = _get_visible_screens()

		"click_button":
			response = _click_button(command.get("path", ""), command.get("by_text", ""))

		"get_node_property":
			response = _get_node_property(command.get("path", ""), command.get("property", ""))

		"set_node_property":
			response = _set_node_property(command.get("path", ""), command.get("property", ""), command.get("value"))

		"get_node_exists":
			response = _get_node_exists(command.get("path", ""))

		"get_node_visible":
			response = _get_node_visible(command.get("path", ""))

		"get_buttons":
			response = _get_buttons(command.get("path", "/root"))

		"get_labels":
			response = _get_labels(command.get("path", "/root"))

		"get_tree_structure":
			response = _get_tree_structure(command.get("path", "/root"), command.get("depth", 3))

		"call_method":
			response = _call_method(command.get("path", ""), command.get("method", ""), command.get("args", []))

		"emit_signal":
			response = _emit_signal(command.get("path", ""), command.get("signal_name", ""))

		"wait_for_node":
			# This is async - handle separately
			_handle_wait_for_node(command.get("path", ""), command.get("timeout", 5.0))
			return

		"get_system":
			response = _get_system_info(command.get("system_name", ""))

		"navigate_to_screen":
			# This is async - handle separately
			_handle_navigate_to_screen(command.get("screen_name", ""))
			return

		"take_screenshot":
			# This is async - handle separately
			_handle_take_screenshot(command.get("path", ""))
			return

		_:
			response = {"success": false, "error": "Unknown action: " + action}

	_send_response(response)


func _handle_wait_for_node(path: String, timeout: float) -> void:
	var response = await _wait_for_node(path, timeout)
	_send_response(response)


func _handle_navigate_to_screen(screen_name: String) -> void:
	var response = await _navigate_to_screen(screen_name)
	_send_response(response)


func _handle_take_screenshot(save_path: String) -> void:
	var response = await _take_screenshot(save_path)
	_send_response(response)


func _send_response(response: Dictionary) -> void:
	if not _client or _client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return

	var json_str = JSON.stringify(response) + "\n"
	# Use put_data instead of put_utf8_string to avoid length prefix
	_client.put_data(json_str.to_utf8_buffer())
	response_sent.emit(response)


func _send_error(message: String) -> void:
	_send_response({"success": false, "error": message})


# ============================================================================
# Command Implementations
# ============================================================================

func _get_current_screen() -> Dictionary:
	var screen_manager = _get_system("ScreenManager")
	if not screen_manager:
		return {"success": false, "error": "ScreenManager not found"}

	var current = screen_manager.get("current_screen")
	if current == null:
		# Try method
		if screen_manager.has_method("get_current_screen"):
			current = screen_manager.get_current_screen()

	return {"success": true, "result": str(current) if current else "unknown"}


func _get_visible_screens() -> Dictionary:
	var visible_screens = []
	var root = get_tree().root

	for child in root.get_children():
		if child.visible if "visible" in child else true:
			if "Screen" in child.name or "View" in child.name:
				visible_screens.append(child.name)

	return {"success": true, "result": visible_screens}


func _click_button(path: String, by_text: String) -> Dictionary:
	var button: BaseButton = null

	if not path.is_empty():
		var node = get_node_or_null(path)
		if node and node is BaseButton:
			button = node
	elif not by_text.is_empty():
		button = _find_button_by_text(by_text)

	if not button:
		return {"success": false, "error": "Button not found: " + (path if path else by_text)}

	if not button.visible:
		return {"success": false, "error": "Button not visible: " + button.name}

	if button.disabled:
		return {"success": false, "error": "Button disabled: " + button.name}

	button.pressed.emit()
	return {"success": true, "result": "Clicked: " + button.name}


func _find_button_by_text(text: String) -> BaseButton:
	return _find_button_by_text_recursive(get_tree().root, text)


func _find_button_by_text_recursive(node: Node, text: String) -> BaseButton:
	if node is BaseButton:
		var button_text = ""
		if node.has_method("get_text"):
			button_text = node.get_text()
		elif "text" in node:
			button_text = node.text

		if button_text.to_lower().contains(text.to_lower()):
			return node

	for child in node.get_children():
		var found = _find_button_by_text_recursive(child, text)
		if found:
			return found

	return null


func _get_node_property(path: String, property: String) -> Dictionary:
	var node = get_node_or_null(path)
	if not node:
		return {"success": false, "error": "Node not found: " + path}

	if not property in node:
		return {"success": false, "error": "Property not found: " + property}

	var value = node.get(property)
	return {"success": true, "result": _serialize_value(value)}


func _set_node_property(path: String, property: String, value) -> Dictionary:
	var node = get_node_or_null(path)
	if not node:
		return {"success": false, "error": "Node not found: " + path}

	if not property in node:
		return {"success": false, "error": "Property not found: " + property}

	node.set(property, value)
	return {"success": true, "result": "Property set"}


func _get_node_exists(path: String) -> Dictionary:
	var node = get_node_or_null(path)
	return {"success": true, "result": node != null}


func _get_node_visible(path: String) -> Dictionary:
	var node = get_node_or_null(path)
	if not node:
		return {"success": false, "error": "Node not found: " + path}

	var visible = true
	if "visible" in node:
		visible = node.visible

	return {"success": true, "result": visible}


func _get_buttons(root_path: String) -> Dictionary:
	var root = get_node_or_null(root_path)
	if not root:
		return {"success": false, "error": "Root node not found: " + root_path}

	var buttons = []
	_collect_buttons(root, buttons)
	return {"success": true, "result": buttons}


func _collect_buttons(node: Node, buttons: Array) -> void:
	if node is BaseButton:
		var info = {
			"path": node.get_path(),
			"name": node.name,
			"visible": node.visible if "visible" in node else true,
			"disabled": node.disabled if "disabled" in node else false,
		}
		if "text" in node:
			info["text"] = node.text
		buttons.append(info)

	for child in node.get_children():
		_collect_buttons(child, buttons)


func _get_labels(root_path: String) -> Dictionary:
	var root = get_node_or_null(root_path)
	if not root:
		return {"success": false, "error": "Root node not found: " + root_path}

	var labels = []
	_collect_labels(root, labels)
	return {"success": true, "result": labels}


func _collect_labels(node: Node, labels: Array) -> void:
	if node is Label or node is RichTextLabel:
		var info = {
			"path": node.get_path(),
			"name": node.name,
			"visible": node.visible if "visible" in node else true,
		}
		if node is Label:
			info["text"] = node.text
		elif node is RichTextLabel:
			info["text"] = node.get_parsed_text()
		labels.append(info)

	for child in node.get_children():
		_collect_labels(child, labels)


func _get_tree_structure(root_path: String, max_depth: int) -> Dictionary:
	var root = get_node_or_null(root_path)
	if not root:
		return {"success": false, "error": "Root node not found: " + root_path}

	var structure = _build_tree_structure(root, 0, max_depth)
	return {"success": true, "result": structure}


func _build_tree_structure(node: Node, depth: int, max_depth: int) -> Dictionary:
	var info = {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
	}

	if "visible" in node:
		info["visible"] = node.visible

	if node is BaseButton and "text" in node:
		info["text"] = node.text
	elif node is Label:
		info["text"] = node.text.substr(0, 50)  # Truncate long labels

	if depth < max_depth and node.get_child_count() > 0:
		info["children"] = []
		for child in node.get_children():
			info["children"].append(_build_tree_structure(child, depth + 1, max_depth))

	return info


func _call_method(path: String, method: String, args: Array) -> Dictionary:
	var node = get_node_or_null(path)
	if not node:
		return {"success": false, "error": "Node not found: " + path}

	if not node.has_method(method):
		return {"success": false, "error": "Method not found: " + method}

	var result = node.callv(method, args)
	return {"success": true, "result": _serialize_value(result)}


func _emit_signal(path: String, signal_name: String) -> Dictionary:
	var node = get_node_or_null(path)
	if not node:
		return {"success": false, "error": "Node not found: " + path}

	if not node.has_signal(signal_name):
		return {"success": false, "error": "Signal not found: " + signal_name}

	node.emit_signal(signal_name)
	return {"success": true, "result": "Signal emitted: " + signal_name}


func _wait_for_node(path: String, timeout: float) -> Dictionary:
	var start_time = Time.get_ticks_msec()
	var timeout_ms = timeout * 1000

	while Time.get_ticks_msec() - start_time < timeout_ms:
		var node = get_node_or_null(path)
		if node:
			return {"success": true, "result": "Node found: " + path}
		await get_tree().create_timer(POLL_INTERVAL).timeout

	return {"success": false, "error": "Timeout waiting for node: " + path}


func _get_system_info(system_name: String) -> Dictionary:
	var system = _get_system(system_name)
	if not system:
		return {"success": false, "error": "System not found: " + system_name}

	var info = {
		"name": system_name,
		"class": system.get_class(),
		"methods": [],
		"properties": []
	}

	# Get some basic info about the system
	for method in system.get_method_list():
		if not method.name.begins_with("_"):
			info["methods"].append(method.name)

	for prop in system.get_property_list():
		if not prop.name.begins_with("_") and prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			info["properties"].append(prop.name)

	return {"success": true, "result": info}


func _navigate_to_screen(screen_name: String) -> Dictionary:
	var screen_manager = _get_system("ScreenManager")
	if not screen_manager:
		return {"success": false, "error": "ScreenManager not found"}

	if screen_manager.has_method("show_screen"):
		screen_manager.show_screen(screen_name)
		# Give it a frame to process
		await get_tree().process_frame
		return {"success": true, "result": "Navigated to: " + screen_name}
	elif screen_manager.has_method("change_screen"):
		screen_manager.change_screen(screen_name)
		await get_tree().process_frame
		return {"success": true, "result": "Navigated to: " + screen_name}

	return {"success": false, "error": "ScreenManager has no navigation method"}


func _take_screenshot(save_path: String) -> Dictionary:
	# Get the viewport's rendered image
	var viewport = get_viewport()
	if not viewport:
		return {"success": false, "error": "Could not access viewport"}

	# Wait for the next frame to ensure we capture current state
	await RenderingServer.frame_post_draw

	var image = viewport.get_texture().get_image()
	if not image:
		return {"success": false, "error": "Could not capture viewport image"}

	# Generate default path if not provided
	if save_path.is_empty():
		var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
		save_path = "user://screenshots/screenshot_%s.png" % timestamp

	# Ensure the directory exists
	var dir_path = save_path.get_base_dir()
	if dir_path.begins_with("user://"):
		var dir = DirAccess.open("user://")
		if dir:
			var relative_dir = dir_path.replace("user://", "")
			if not relative_dir.is_empty():
				dir.make_dir_recursive(relative_dir)

	# Save the image
	var error = image.save_png(save_path)
	if error != OK:
		return {"success": false, "error": "Failed to save screenshot: " + error_string(error)}

	# Get the actual file path for returning
	var actual_path = save_path
	if save_path.begins_with("user://"):
		actual_path = ProjectSettings.globalize_path(save_path)

	return {
		"success": true,
		"result": {
			"path": actual_path,
			"width": image.get_width(),
			"height": image.get_height()
		}
	}


# ============================================================================
# Utilities
# ============================================================================

func _get_system(system_name: String):
	# Try SystemRegistry singleton first
	var registry = SystemRegistry.get_instance()
	if registry and registry.has_method("get_system"):
		var system = registry.get_system(system_name)
		if system:
			return system

	# Try GameCoordinator path (where SystemRegistry lives)
	var game_coordinator = get_node_or_null("/root/GameCoordinator")
	if game_coordinator and game_coordinator.has_method("get_system"):
		var system = game_coordinator.get_system(system_name)
		if system:
			return system

	# Try as direct autoload
	var autoload = get_node_or_null("/root/" + system_name)
	if autoload:
		return autoload

	return null


func _serialize_value(value) -> Variant:
	if value == null:
		return null
	elif value is bool or value is int or value is float or value is String:
		return value
	elif value is Array:
		var arr = []
		for item in value:
			arr.append(_serialize_value(item))
		return arr
	elif value is Dictionary:
		var dict = {}
		for key in value:
			dict[key] = _serialize_value(value[key])
		return dict
	elif value is Vector2:
		return {"x": value.x, "y": value.y, "_type": "Vector2"}
	elif value is Vector3:
		return {"x": value.x, "y": value.y, "z": value.z, "_type": "Vector3"}
	elif value is Node:
		return {"path": str(value.get_path()), "name": value.name, "_type": "Node"}
	else:
		return str(value)

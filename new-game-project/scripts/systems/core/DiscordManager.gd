# scripts/systems/core/DiscordManager.gd
# Manages Discord Rich Presence integration
extends Node
class_name DiscordManager

"""
DiscordManager - Discord RPC Integration via discord-rpc-gd plugin
RULE 2: Single responsibility - Discord API only
RULE 5: SystemRegistry integration
"""

# ==============================================================================
# CONSTANTS
# ==============================================================================
const DISCORD_APP_ID: int = 1473114461446340650

# ==============================================================================
# STATE
# ==============================================================================
var _is_initialized: bool = false
var _is_connected: bool = false
var _start_time: int = 0

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready() -> void:
	name = "DiscordManager"
	_start_time = int(Time.get_unix_time_from_system())
	# Wait for plugin autoload to initialize first
	call_deferred("_init_discord")

func initialize() -> void:
	"""Called by SystemRegistry after all systems registered."""
	if _is_initialized:
		return
	_is_initialized = true

	# Connect to screen changes to auto-update Discord presence
	var registry: Variant = SystemRegistry.get_instance()
	if registry:
		var screen_manager: Variant = registry.get_system("ScreenManager")
		if screen_manager and screen_manager.has_signal("screen_changed"):
			screen_manager.screen_changed.connect(_on_screen_changed)

func _init_discord() -> void:
	# Check if DiscordRPC singleton exists (plugin enabled)
	if not Engine.has_singleton("DiscordRPC") and not ClassDB.class_exists("DiscordRPC"):
		print("[DiscordManager] DiscordRPC not available - plugin may not be enabled")
		return

	# Set the Application ID
	DiscordRPC.app_id = DISCORD_APP_ID

	# Check if Discord is running
	_is_connected = DiscordRPC.get_is_discord_working()
	print("[DiscordManager] Discord working: %s" % _is_connected)

	if _is_connected:
		set_default_presence()

# ==============================================================================
# RICH PRESENCE
# ==============================================================================

func set_default_presence() -> void:
	"""Set default presence showing the game is running"""
	if not _is_connected:
		return

	DiscordRPC.details = "Playing Smyte"
	DiscordRPC.state = "In Menu"
	DiscordRPC.large_image = "smyte_logo"
	DiscordRPC.large_image_text = "Smyte - Divine Strategy"
	DiscordRPC.start_timestamp = _start_time
	DiscordRPC.refresh()

func update_activity(details: String, state: String = "") -> void:
	"""Update Discord Rich Presence"""
	if not _is_connected:
		print("[DiscordManager] Not connected, skipping update: %s" % details)
		return

	DiscordRPC.details = details
	DiscordRPC.state = state
	DiscordRPC.large_image = "smyte_logo"
	DiscordRPC.large_image_text = "Smyte - Divine Strategy"
	# Note: small_image omitted - only add if you upload "smyte_icon" asset to Discord
	DiscordRPC.start_timestamp = _start_time
	DiscordRPC.refresh()
	print("[DiscordManager] Activity updated: %s - %s" % [details, state])

func clear_activity() -> void:
	"""Clear the current activity"""
	if not _is_connected:
		return
	DiscordRPC.clear()

# ==============================================================================
# ACTIVITY SHORTCUTS
# ==============================================================================

func set_in_battle(enemy_info: String = "") -> void:
	var state: String = "Fighting %s" % enemy_info if not enemy_info.is_empty() else "In Combat"
	update_activity("In Battle", state)

func set_in_dungeon(dungeon_name: String, floor_num: int = 0) -> void:
	var state: String = dungeon_name
	if floor_num > 0:
		state += " - Floor %d" % floor_num
	update_activity("Exploring Dungeon", state)

func set_managing_territory() -> void:
	update_activity("Managing Territory", "Building Empire")

func set_summoning() -> void:
	update_activity("Summoning Gods", "At the Altar")

func set_crafting() -> void:
	update_activity("Crafting", "At the Forge")

func set_pvp(opponent: String = "") -> void:
	var state: String = "vs %s" % opponent if not opponent.is_empty() else "Finding Opponent"
	update_activity("PvP Battle", state)

func set_tower(floor_num: int) -> void:
	update_activity("Climbing Tower", "Floor %d" % floor_num)

func set_idle() -> void:
	update_activity("Playing Smyte", "In Menu")

# ==============================================================================
# SCREEN CHANGE HANDLER
# ==============================================================================

func _on_screen_changed(screen_name: String) -> void:
	"""Auto-update Discord presence based on current screen"""
	match screen_name:
		"worldview":
			set_idle()
		"territory", "hex_territory":
			set_managing_territory()
		"summon":
			set_summoning()
		"dungeon":
			update_activity("Exploring Dungeons", "Selecting Dungeon")
		"battle":
			set_in_battle()
		"equipment":
			update_activity("Managing Equipment", "Gearing Up")
		"sacrifice", "sacrifice_selection":
			update_activity("Sacrificing Gods", "Gaining Power")
		"shop":
			update_activity("Browsing Shop", "Shopping")
		"tower":
			update_activity("Tower of Trials", "Climbing")
		"arena", "pvp_territory":
			set_pvp()
		"collection":
			update_activity("Viewing Collection", "My Gods")
		"leaderboard":
			update_activity("Leaderboards", "Checking Rankings")
		_:
			set_idle()

# ==============================================================================
# UTILITY
# ==============================================================================

func is_discord_connected() -> bool:
	return _is_connected

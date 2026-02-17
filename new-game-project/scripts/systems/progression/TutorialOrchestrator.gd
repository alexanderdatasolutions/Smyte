# scripts/systems/progression/TutorialOrchestrator.gd
extends Node
class_name TutorialOrchestrator

# ==============================================================================
# TUTORIAL ORCHESTRATOR - Interactive tutorial flow management
# ==============================================================================
# Handles tutorial progression with highlighting, action waiting, and dialogs.
# Single responsibility: Orchestrate tutorial flow and guide new players.

signal tutorial_started(tutorial_name: String)
signal tutorial_completed(tutorial_name: String)
signal tutorial_step_completed(tutorial_name: String, step: int)
signal highlight_requested(target_id: String, message: String, title: String, show_button: bool)
signal highlight_cleared()

# Tutorial state
var current_tutorial: String = ""
var current_step: int = 0
var tutorial_active: bool = false
var completed_tutorials: Array[String] = []
var waiting_for_action: String = ""

# Highlight overlay instance
var _highlight_overlay: Control = null

# Cached system references
var _save_manager: Node = null
var _event_bus: Node = null
var _feature_unlock_manager: Node = null
var _achievement_manager: Node = null
var _analytics: Node = null

# ==============================================================================
# TUTORIAL DEFINITIONS
# ==============================================================================
# Each tutorial has steps with types: dialog, highlight, wait_action

var tutorial_definitions: Dictionary = {
	# =========================================================================
	# ONBOARDING TUTORIALS
	# =========================================================================
	"new_user_welcome": {
		"trigger": "new_game",
		"steps": [
			{
				"type": "dialog",
				"title": "Welcome, Divine Summoner!",
				"message": "Your journey to build a pantheon of gods begins here.\n\nLet's summon your first divine ally!",
				"button_text": "Let's go!"
			},
			{
				"type": "highlight",
				"target_screen": "worldview",
				"target_id": "summon",
				"title": "Summon Temple",
				"message": "Tap here to summon your first god!",
				"wait_for_action": "summon_button_pressed"
			},
			{
				"type": "highlight",
				"target_screen": "summon",
				"target_id": "free_tab",
				"title": "Free Summon",
				"message": "Tap the Free tab for a free daily summon!",
				"wait_for_action": "free_tab_pressed"
			}
		]
	},

	"first_summon_complete": {
		"trigger": "achievement:first_summon",
		"steps": [
			{
				"type": "dialog",
				"title": "Excellent!",
				"message": "You've summoned your first god!\n\nNow let's claim some territory for your divine empire.",
				"button_text": "Continue"
			},
			{
				"type": "highlight",
				"target_screen": "worldview",
				"target_id": "territory",
				"title": "Territory",
				"message": "Tap here to view the hex map and capture territories!",
				"wait_for_action": "territory_button_pressed"
			}
		]
	},

	"hex_territory_intro": {
		"trigger": "screen:hex_territory",
		"prerequisite": "first_summon_complete",
		"steps": [
			{
				"type": "dialog",
				"title": "The Hex Territory Map",
				"message": "This is your divine empire!\n\n• Green hexes are yours\n• Gray hexes are neutral - claim them!\n\nLet's capture your first territory!",
				"button_text": "Got it!"
			},
			{
				"type": "highlight",
				"target_screen": "hex_territory",
				"target_id": "barren_outcrop_hex",
				"title": "Capture Territory",
				"message": "Tap this Barren Outcrop to select it!",
				"wait_for_action": "hex_node_selected"
			}
		]
	},

	"hex_capture_tutorial": {
		"trigger": "hex_node_selected_tutorial",
		"prerequisite": "hex_territory_intro",
		"steps": [
			{
				"type": "highlight",
				"target_screen": "node_info",
				"target_id": "capture_button",
				"title": "Capture!",
				"message": "Now tap Capture to claim this territory!",
				"wait_for_action": "capture_button_pressed"
			}
		]
	},

	"team_selection_tutorial": {
		"trigger": "screen:team_selection",
		"prerequisite": "hex_capture_tutorial",
		"steps": [
			{
				"type": "dialog",
				"title": "Select Your Team",
				"message": "Choose gods to fight for this territory!\n\nTap gods on the right to add them to your team.",
				"button_text": "Got it!"
			},
			{
				"type": "highlight",
				"target_screen": "team_selection",
				"target_id": "team_bonuses",
				"title": "Team Bonuses",
				"message": "Watch these bonuses! Same-element gods give combat boosts.",
				"wait_for_action": "team_bonuses_seen"
			}
		]
	},

	"battle_intro_tutorial": {
		"trigger": "screen:battle",
		"prerequisite": "hex_capture_tutorial",
		"steps": [
			{
				"type": "dialog",
				"title": "Battle Time!",
				"message": "Your gods will fight automatically!\n\n• Tap a god to use their special ability\n• The Auto button lets battles run hands-free\n\nGood luck!",
				"button_text": "Fight!"
			}
		]
	},

	"building_selection_tutorial": {
		"trigger": "first_capture_complete",
		"prerequisite": "hex_capture_tutorial",
		"steps": [
			{
				"type": "dialog",
				"title": "Choose a Building",
				"message": "Each captured territory can have a building!\n\n• Different buildings produce different resources\n• Choose based on what you need most\n\nSelect a building to place on this tile.",
				"button_text": "Got it!"
			}
		]
	},

	"garrison_intro": {
		"trigger": "building_placed",
		"prerequisite": "building_selection_tutorial",
		"steps": [
			{
				"type": "highlight",
				"target_screen": "node_info",
				"target_id": "production_section",
				"title": "Production",
				"message": "This shows what resources your building produces per hour.",
				"show_button": true
			},
			{
				"type": "highlight",
				"target_screen": "node_info",
				"target_id": "garrison_section",
				"title": "Garrison",
				"message": "Gods assigned here defend your territory from attacks. More garrison = stronger defense!",
				"show_button": true
			},
			{
				"type": "highlight",
				"target_screen": "node_info",
				"target_id": "workers_section",
				"title": "Workers",
				"message": "Gods assigned as workers boost production. Higher tier buildings unlock more worker slots!",
				"show_button": true
			},
			{
				"type": "highlight",
				"target_screen": "node_info",
				"target_id": "garrison_slot",
				"title": "Assign a God",
				"message": "Tap an empty slot to assign a god to this territory!",
				"wait_for_action": "garrison_slot_tapped"
			}
		]
	},

	"expansion_ready": {
		"trigger": "garrison_assigned",
		"prerequisite": "garrison_intro",
		"steps": [
			{
				"type": "dialog",
				"title": "You're Ready!",
				"message": "Great job! Your territory is now defended.\n\nKeep expanding your empire by capturing more hexes. Each territory produces resources that help you grow stronger!",
				"button_text": "Let's conquer!"
			}
		]
	},

	# =========================================================================
	# FEATURE INTRODUCTION TUTORIALS
	# =========================================================================
	"sacrifice_intro": {
		"trigger": "feature_unlocked:sacrifice",
		"steps": [
			{
				"type": "dialog",
				"title": "Sacrifice Altar Unlocked!",
				"message": "Sacrifice duplicate gods to strengthen your favorites!\n\n• Sacrificing grants XP to a chosen god\n• Higher tier sacrifices give more XP",
				"button_text": "Show me!"
			},
			{
				"type": "highlight",
				"target_screen": "worldview",
				"target_id": "sacrifice",
				"title": "Sacrifice Altar",
				"message": "Tap here to sacrifice gods!",
				"wait_for_action": "sacrifice_button_pressed",
				"show_button": true
			}
		]
	},

	"equipment_intro": {
		"trigger": "feature_unlocked:equipment",
		"steps": [
			{
				"type": "dialog",
				"title": "Equipment Unlocked!",
				"message": "Equip your gods with powerful gear!\n\n• 6 equipment slots per god\n• Higher rarity = stronger bonuses",
				"button_text": "Show me!"
			},
			{
				"type": "highlight",
				"target_screen": "worldview",
				"target_id": "equipment",
				"title": "Equipment",
				"message": "Tap here to manage god equipment!",
				"wait_for_action": "equipment_button_pressed",
				"show_button": true
			}
		]
	},

	"dungeon_intro": {
		"trigger": "feature_unlocked:dungeon",
		"steps": [
			{
				"type": "dialog",
				"title": "Dungeons Unlocked!",
				"message": "Clear dungeons for valuable rewards!\n\n• Element Dungeons: Farm powders for summoning\n• Equipment Dungeons: Find gear",
				"button_text": "Show me!"
			},
			{
				"type": "highlight",
				"target_screen": "worldview",
				"target_id": "dungeon",
				"title": "Dungeons",
				"message": "Tap here to explore dungeons!",
				"wait_for_action": "dungeon_button_pressed",
				"show_button": true
			}
		]
	},

	"tower_intro": {
		"trigger": "feature_unlocked:tower",
		"steps": [
			{
				"type": "dialog",
				"title": "Tower Unlocked!",
				"message": "Climb the tower for progressive rewards!\n\n• Each floor gets harder\n• How high can you climb?",
				"button_text": "Show me!"
			},
			{
				"type": "highlight",
				"target_screen": "worldview",
				"target_id": "tower",
				"title": "Infinite Tower",
				"message": "Tap here to climb the tower!",
				"wait_for_action": "tower_button_pressed",
				"show_button": true
			}
		]
	},

	"arena_intro": {
		"trigger": "feature_unlocked:arena",
		"steps": [
			{
				"type": "dialog",
				"title": "Arena Unlocked!",
				"message": "Battle other players for glory!\n\n• Climb the leaderboard\n• Earn rewards based on your league",
				"button_text": "Show me!"
			},
			{
				"type": "highlight",
				"target_screen": "worldview",
				"target_id": "arena",
				"title": "PvP Arena",
				"message": "Tap here to enter the arena!",
				"wait_for_action": "arena_button_pressed",
				"show_button": true
			}
		]
	},

	"pvp_territory_intro": {
		"trigger": "feature_unlocked:pvp",
		"steps": [
			{
				"type": "dialog",
				"title": "PvP Territory Wars!",
				"message": "Compete with other players for special territories!\n\n• Capture contested hexes\n• Control powerful resource nodes",
				"button_text": "To war!"
			}
		]
	},

	"forge_intro": {
		"trigger": "building_opened:forge",
		"steps": [
			{
				"type": "dialog",
				"title": "The Forge",
				"message": "Craft equipment at the forge!\n\n• Use materials from dungeons\n• Crafting takes time but is worth it",
				"button_text": "Let's craft!"
			}
		]
	},

	"awakening_intro": {
		"trigger": "feature_unlocked:awakening",
		"steps": [
			{
				"type": "dialog",
				"title": "Awakening Unlocked!",
				"message": "Awaken your gods to break their limits!\n\n• Increases max level\n• Requires duplicate gods",
				"button_text": "Understood"
			}
		]
	}
}

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready() -> void:
	_cache_system_references()

func initialize() -> void:
	_cache_system_references()
	_connect_events()

func _cache_system_references() -> void:
	var registry: Node = SystemRegistry.get_instance()
	if not registry:
		return
	_save_manager = registry.get_system("SaveManager")
	_event_bus = registry.get_system("EventBus")
	_feature_unlock_manager = registry.get_system("FeatureUnlockManager")
	_achievement_manager = registry.get_system("AchievementManager")
	_analytics = registry.get_system("FirebaseAnalytics")

func _connect_events() -> void:
	if not _event_bus:
		return

	# Listen for tutorial actions from UI
	if _event_bus.has_signal("tutorial_action_completed"):
		if not _event_bus.tutorial_action_completed.is_connected(_on_action_completed):
			_event_bus.tutorial_action_completed.connect(_on_action_completed)

	# Listen for feature unlocks
	if _feature_unlock_manager and _feature_unlock_manager.has_signal("feature_unlocked"):
		if not _feature_unlock_manager.feature_unlocked.is_connected(_on_feature_unlocked):
			_feature_unlock_manager.feature_unlocked.connect(_on_feature_unlocked)

	# Listen for achievement completions
	if _achievement_manager and _achievement_manager.has_signal("achievement_completed"):
		if not _achievement_manager.achievement_completed.is_connected(_on_achievement_completed):
			_achievement_manager.achievement_completed.connect(_on_achievement_completed)
			print("TutorialOrchestrator: Connected to AchievementManager.achievement_completed signal")

# ==============================================================================
# MAIN TUTORIAL FLOW
# ==============================================================================

func start_tutorial(tutorial_name: String) -> bool:
	"""Start a tutorial by name. Returns false if already active/completed."""
	var display_name: String = _get_tutorial_display_name(tutorial_name)
	print("TutorialOrchestrator: start_tutorial('%s') - %s" % [tutorial_name, display_name])

	if tutorial_active:
		print("TutorialOrchestrator: Cannot start '%s' - another tutorial is active (%s)" % [tutorial_name, current_tutorial])
		return false

	if tutorial_name in completed_tutorials:
		print("TutorialOrchestrator: Cannot start '%s' - already completed" % tutorial_name)
		return false

	if not tutorial_definitions.has(tutorial_name):
		push_warning("TutorialOrchestrator: Unknown tutorial '%s'" % tutorial_name)
		return false

	# Check prerequisite
	var definition: Dictionary = tutorial_definitions[tutorial_name]
	var prerequisite: String = definition.get("prerequisite", "")
	if not prerequisite.is_empty() and prerequisite not in completed_tutorials:
		return false

	current_tutorial = tutorial_name
	current_step = 0
	tutorial_active = true
	waiting_for_action = ""

	# Log analytics
	var steps: Array = definition.get("steps", [])
	if _analytics:
		_analytics.log_tutorial_started(tutorial_name, display_name, steps.size())

	tutorial_started.emit(tutorial_name)
	_process_current_step()
	return true

func advance_tutorial() -> bool:
	"""Advance to the next step. Returns false if tutorial ended."""
	if not tutorial_active:
		return false

	var definition: Dictionary = tutorial_definitions[current_tutorial]
	var steps: Array = definition.get("steps", [])

	# Log step completion analytics
	if _analytics and current_step < steps.size():
		var step_data: Dictionary = steps[current_step]
		var step_title: String = step_data.get("title", "Step %d" % (current_step + 1))
		_analytics.log_tutorial_step_completed(current_tutorial, current_step, step_title, steps.size())

	tutorial_step_completed.emit(current_tutorial, current_step)
	current_step += 1

	if current_step >= steps.size():
		_complete_tutorial()
		return false

	_process_current_step()
	return true

func _process_current_step() -> void:
	"""Process the current tutorial step."""
	var definition: Dictionary = tutorial_definitions[current_tutorial]
	var steps: Array = definition.get("steps", [])

	if current_step >= steps.size():
		_complete_tutorial()
		return

	var step_data: Dictionary = steps[current_step]
	var step_type: String = step_data.get("type", "dialog")

	match step_type:
		"dialog":
			_show_dialog_step(step_data)
		"highlight":
			_show_highlight_step(step_data)
		"wait_action":
			_setup_wait_action(step_data)

func _complete_tutorial() -> void:
	"""Complete the current tutorial and save."""
	var finished_tutorial := current_tutorial
	var display_name: String = _get_tutorial_display_name(finished_tutorial)
	var steps_count: int = current_step + 1  # current_step is 0-indexed
	print("TutorialOrchestrator: COMPLETED '%s' - %s" % [finished_tutorial, display_name])

	# Log analytics
	if _analytics:
		_analytics.log_tutorial_completed(finished_tutorial, display_name, steps_count)

	# Clear highlight if any
	_clear_highlight()

	completed_tutorials.append(finished_tutorial)
	print("  - Total completed: %d tutorials" % completed_tutorials.size())
	tutorial_completed.emit(finished_tutorial)

	tutorial_active = false
	current_tutorial = ""
	current_step = 0
	waiting_for_action = ""

	# Save progress
	if _save_manager:
		_save_manager.save_game()

	# Check for chained tutorials
	_check_for_chained_tutorials(finished_tutorial)

func _check_for_chained_tutorials(_finished: String) -> void:
	"""Check if completing a tutorial should trigger another."""
	# Chain: new_user_welcome -> (user summons) -> first_summon_complete
	# Chain: first_summon_complete -> (user opens territory) -> hex_territory_intro
	# These are triggered by actions, not direct chaining
	pass

# ==============================================================================
# STEP HANDLERS
# ==============================================================================

func _show_dialog_step(step_data: Dictionary) -> void:
	"""Show a dialog step using EventBus."""
	if not _event_bus:
		advance_tutorial()
		return

	var dialog_data := {
		"title": step_data.get("title", "Tutorial"),
		"message": step_data.get("message", ""),
		"button_text": step_data.get("button_text", "Continue")
	}

	_event_bus.show_tutorial_requested.emit(dialog_data)
	# Dialog will call advance_tutorial() when closed

func _show_highlight_step(step_data: Dictionary) -> void:
	"""Show a highlight step - spotlights a UI element."""
	var target_id: String = step_data.get("target_id", "")
	var message: String = step_data.get("message", "")
	var title: String = step_data.get("title", "")
	var wait_action: String = step_data.get("wait_for_action", "")
	var show_button: bool = step_data.get("show_button", false)
	var target_screen: String = step_data.get("target_screen", "")

	# Check if target screen is currently visible
	if not target_screen.is_empty() and not _is_screen_visible(target_screen):
		print("TutorialOrchestrator: Target screen '%s' not visible, waiting for navigation" % target_screen)
		# Set up waiting for action - the screen will show highlight when it becomes visible
		if not wait_action.is_empty():
			waiting_for_action = wait_action
		# Don't emit highlight_requested yet - screen will check pending highlights when visible
		return

	if wait_action.is_empty():
		# No action to wait for, just show and continue
		highlight_requested.emit(target_id, message, title, true)  # Always show button when no action
		# Will be dismissed and advance when user clicks target
	else:
		# Wait for specific action
		waiting_for_action = wait_action
		highlight_requested.emit(target_id, message, title, show_button)

func _is_screen_visible(screen_name: String) -> bool:
	"""Check if a screen is currently visible."""
	var registry: Node = SystemRegistry.get_instance()
	if not registry:
		return false

	var screen_manager: Node = registry.get_system("ScreenManager")
	if not screen_manager:
		return false

	# Check current screen name
	var current_screen_name: String = ""
	if screen_manager.has_method("get_current_screen_name"):
		current_screen_name = screen_manager.get_current_screen_name()
	elif screen_manager.get("current_screen_name"):
		current_screen_name = screen_manager.current_screen_name
	else:
		# Try to get current screen and check its name
		var current: Node = screen_manager.get_current_screen() if screen_manager.has_method("get_current_screen") else null
		if current:
			current_screen_name = current.name.to_lower()

	# Normalize screen names for comparison
	var normalized_target: String = screen_name.to_lower().replace("_", "")
	var normalized_current: String = current_screen_name.to_lower().replace("_", "")

	# WorldView is a special case - it's visible when on main menu
	if normalized_target == "worldview":
		return normalized_current == "worldview" or normalized_current == "mainmenu" or normalized_current == ""

	return normalized_target == normalized_current

func _setup_wait_action(step_data: Dictionary) -> void:
	"""Set up waiting for a user action without visual."""
	var wait_action: String = step_data.get("wait_for_action", "")
	if wait_action.is_empty():
		advance_tutorial()
		return

	waiting_for_action = wait_action

func _clear_highlight() -> void:
	"""Clear any active highlight."""
	highlight_cleared.emit()
	if _highlight_overlay and is_instance_valid(_highlight_overlay):
		_highlight_overlay.clear_highlight()

# ==============================================================================
# ACTION HANDLING
# ==============================================================================

func _on_action_completed(action_id: String) -> void:
	"""Handle a tutorial action being completed."""
	var display_name: String = _get_tutorial_display_name(current_tutorial) if tutorial_active else "none"
	print("TutorialOrchestrator: Action '%s' received (tutorial: %s, waiting: '%s')" % [action_id, display_name, waiting_for_action])

	if not tutorial_active or waiting_for_action.is_empty():
		return

	if action_id == waiting_for_action:
		print("  - MATCH! Advancing %s step %d" % [current_tutorial, current_step])
		waiting_for_action = ""
		_clear_highlight()
		advance_tutorial()

func _on_feature_unlocked(feature_name: String, _feature_data: Dictionary) -> void:
	"""Handle feature unlock - may trigger introduction tutorial."""
	# Block feature tutorials during initial onboarding to avoid interruptions
	if not is_onboarding_complete():
		print("TutorialOrchestrator: Feature '%s' unlocked - tutorial blocked (still onboarding)" % feature_name.capitalize())
		return

	var trigger_id := "feature_unlocked:" + feature_name

	# Find tutorial that triggers on this feature
	for tutorial_name: String in tutorial_definitions:
		var definition: Dictionary = tutorial_definitions[tutorial_name]
		if definition.get("trigger", "") == trigger_id:
			# Delay slightly to let UI update
			call_deferred("start_tutorial", tutorial_name)
			break

func _on_achievement_completed(achievement_id: String, _achievement_data: Dictionary) -> void:
	"""Handle achievement completion - may trigger tutorial."""
	print("TutorialOrchestrator: Achievement completed - %s" % achievement_id)
	var trigger_id := "achievement:" + achievement_id

	# Find tutorial that triggers on this achievement
	for tutorial_name: String in tutorial_definitions:
		var definition: Dictionary = tutorial_definitions[tutorial_name]
		if definition.get("trigger", "") == trigger_id:
			print("TutorialOrchestrator: Found matching tutorial '%s' for trigger '%s'" % [tutorial_name, trigger_id])
			# Delay slightly to let UI update
			call_deferred("start_tutorial", tutorial_name)
			break

# ==============================================================================
# TUTORIAL STATE QUERIES
# ==============================================================================

func is_tutorial_active() -> bool:
	return tutorial_active

func is_tutorial_completed(tutorial_name: String) -> bool:
	return tutorial_name in completed_tutorials

func get_current_tutorial_info() -> Dictionary:
	if not tutorial_active:
		return {}

	var definition: Dictionary = tutorial_definitions.get(current_tutorial, {})
	var steps: Array = definition.get("steps", [])

	return {
		"name": current_tutorial,
		"step": current_step,
		"total_steps": steps.size()
	}

func _get_tutorial_display_name(tutorial_name: String) -> String:
	"""Get a human-readable display name for a tutorial."""
	if not tutorial_definitions.has(tutorial_name):
		return tutorial_name
	var definition: Dictionary = tutorial_definitions[tutorial_name]
	var steps: Array = definition.get("steps", [])
	if steps.is_empty():
		return tutorial_name
	# Get title from first step
	var first_step: Dictionary = steps[0]
	var title: String = first_step.get("title", "")
	if title.is_empty():
		return tutorial_name
	return "\"%s\"" % title

func should_show_onboarding() -> bool:
	"""Check if we should show the new user onboarding."""
	return not is_tutorial_completed("new_user_welcome")

func is_onboarding_complete() -> bool:
	"""Check if the core onboarding flow is complete.
	Used to block feature unlock tutorials during initial onboarding."""
	# Onboarding is complete when user has finished the garrison tutorial
	# This ensures feature tutorials don't interrupt the capture/build/garrison flow
	return is_tutorial_completed("garrison_intro") or is_tutorial_completed("expansion_ready")

func skip_tutorial() -> void:
	"""Skip the current tutorial."""
	if tutorial_active:
		# Log skip analytics before completing
		if _analytics:
			var display_name: String = _get_tutorial_display_name(current_tutorial)
			var definition: Dictionary = tutorial_definitions.get(current_tutorial, {})
			var steps: Array = definition.get("steps", [])
			_analytics.log_tutorial_skipped(current_tutorial, display_name, current_step, steps.size())
		_complete_tutorial()

# ==============================================================================
# HIGHLIGHT OVERLAY MANAGEMENT
# ==============================================================================

func set_highlight_overlay(overlay: Control) -> void:
	"""Set the highlight overlay instance for direct control."""
	_highlight_overlay = overlay

func get_highlight_overlay() -> Control:
	return _highlight_overlay

# ==============================================================================
# TRIGGER HELPERS (called by screens)
# ==============================================================================

func trigger_tutorial_for_screen(screen_name: String) -> bool:
	"""Check and trigger tutorials for a specific screen."""
	var trigger := "screen:" + screen_name

	for tutorial_name: String in tutorial_definitions:
		var definition: Dictionary = tutorial_definitions[tutorial_name]
		if definition.get("trigger", "") == trigger:
			if not is_tutorial_completed(tutorial_name):
				return start_tutorial(tutorial_name)
	return false

func trigger_building_opened(building_id: String) -> bool:
	"""Trigger tutorial when a building is first opened."""
	var trigger := "building_opened:" + building_id

	for tutorial_name: String in tutorial_definitions:
		var definition: Dictionary = tutorial_definitions[tutorial_name]
		if definition.get("trigger", "") == trigger:
			if not is_tutorial_completed(tutorial_name):
				return start_tutorial(tutorial_name)
	return false

func trigger_node_info_opened() -> bool:
	"""Trigger garrison tutorial when node info is opened (after building placed)."""
	if is_tutorial_completed("garrison_intro"):
		return false

	# Only trigger if building_selection_tutorial is complete
	if not is_tutorial_completed("building_selection_tutorial"):
		return false

	return start_tutorial("garrison_intro")

func trigger_garrison_assigned() -> bool:
	"""Trigger expansion ready tutorial after first garrison."""
	if is_tutorial_completed("expansion_ready"):
		return false

	if not is_tutorial_completed("garrison_intro"):
		return false

	return start_tutorial("expansion_ready")

func trigger_hex_selected_tutorial() -> bool:
	"""Trigger hex capture tutorial after hex selection (shows Capture button highlight)."""
	if is_tutorial_completed("hex_capture_tutorial"):
		return false

	# Only trigger if hex_territory_intro is complete
	if not is_tutorial_completed("hex_territory_intro"):
		return false

	return start_tutorial("hex_capture_tutorial")

func trigger_first_capture_complete() -> bool:
	"""Trigger building selection tutorial after first capture."""
	print("TutorialOrchestrator: First capture complete - checking building tutorial")

	if is_tutorial_completed("building_selection_tutorial"):
		print("  - Already done, skipping")
		return false

	if not is_tutorial_completed("hex_capture_tutorial"):
		print("  - BLOCKED: Need to complete hex capture tutorial first")
		return false

	if tutorial_active:
		print("  - BLOCKED: Tutorial '%s' still active" % _get_tutorial_display_name(current_tutorial))
		return false

	return start_tutorial("building_selection_tutorial")

func trigger_building_placed() -> bool:
	"""Trigger garrison tutorial after building is placed."""
	if is_tutorial_completed("garrison_intro"):
		return false

	# Only trigger if building_selection_tutorial is complete
	if not is_tutorial_completed("building_selection_tutorial"):
		return false

	return start_tutorial("garrison_intro")

func get_current_step_data() -> Dictionary:
	"""Get the current step data for screens to check highlight requests."""
	if not tutorial_active or current_tutorial.is_empty():
		return {}

	var definition: Dictionary = tutorial_definitions.get(current_tutorial, {})
	var steps: Array = definition.get("steps", [])

	if current_step >= steps.size():
		return {}

	return steps[current_step]

func check_pending_highlight_for_screen(screen_name: String) -> bool:
	"""Check if there's a pending highlight for this screen and re-emit if so.
	Called by screens when they become visible."""
	if not tutorial_active:
		return false

	var step_data: Dictionary = get_current_step_data()
	if step_data.is_empty():
		return false

	if step_data.get("type") != "highlight":
		return false

	var target_screen: String = step_data.get("target_screen", "")
	var normalized_target: String = target_screen.to_lower().replace("_", "")
	var normalized_screen: String = screen_name.to_lower().replace("_", "")

	# Special case for worldview
	if normalized_target == "worldview" and (normalized_screen == "worldview" or normalized_screen == "mainmenu"):
		# This highlight is for WorldView, re-emit it
		print("TutorialOrchestrator: Re-emitting pending highlight for %s" % target_screen)
		_show_highlight_step(step_data)
		return true

	if normalized_target == normalized_screen:
		print("TutorialOrchestrator: Re-emitting pending highlight for %s" % target_screen)
		_show_highlight_step(step_data)
		return true

	return false

# ==============================================================================
# SAVE/LOAD INTEGRATION
# ==============================================================================

func get_tutorial_save_data() -> Dictionary:
	return {
		"completed_tutorials": completed_tutorials,
		"current_tutorial": current_tutorial if tutorial_active else "",
		"current_step": current_step if tutorial_active else 0
	}

func load_tutorial_save_data(data: Dictionary) -> void:
	var raw_tutorials: Array = data.get("completed_tutorials", [])
	completed_tutorials.clear()
	for t: Variant in raw_tutorials:
		if t is String:
			completed_tutorials.append(t)

	var saved_tutorial: String = data.get("current_tutorial", "")
	if not saved_tutorial.is_empty() and tutorial_definitions.has(saved_tutorial):
		current_tutorial = saved_tutorial
		current_step = int(data.get("current_step", 0))
		tutorial_active = true
		# Resume tutorial processing
		call_deferred("_process_current_step")

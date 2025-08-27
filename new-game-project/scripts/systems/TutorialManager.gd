# scripts/systems/TutorialManager.gd
extends Node
class_name TutorialManager

# ==============================================================================
# TUTORIAL SYSTEM - First Time User Experience (FTUE)
# ==============================================================================
# Handles the Summoners War style tutorial flow for new players
# Following the architecture blueprint for clean modular design

signal tutorial_started(tutorial_name: String)
signal tutorial_completed(tutorial_name: String)
signal tutorial_step_completed(tutorial_name: String, step_number: int)
signal feature_unlocked(feature_name: String)
signal resource_granted(resource_type: String, amount: int)
signal tutorial_dialog_created(dialog: Control)  # For MainUIOverlay to handle positioning

# Tutorial state tracking
var current_tutorial: String = ""
var current_step: int = 0
var tutorial_active: bool = false
var _pending_navigation: String = ""

# Tutorial UI
# Tutorial dialog (MYTHOS ARCHITECTURE - Scene-based UI)
var tutorial_dialog: TutorialDialog
var tutorial_dialog_scene = preload("res://scenes/TutorialDialog.tscn")

# Tutorial data
var tutorial_definitions: Dictionary = {}
var completed_tutorials: Array = []

# System dependencies
var player_data: PlayerData
var game_manager: Node
var progression_manager: Node
var ui_manager: UIManager

func _ready():
	print("TutorialManager: Initializing tutorial system...")
	
	# Wait for GameManager to be ready
	if not GameManager:
		await get_tree().process_frame
	
	game_manager = GameManager
	player_data = GameManager.player_data if GameManager else null
	progression_manager = GameManager.progression_manager if GameManager else null
	
	# Load and setup tutorial dialog UI
	_setup_tutorial_dialog()
	
	# Load tutorial definitions
	setup_tutorial_definitions()
	
	print("TutorialManager: Ready - Tutorial system initialized")

func _setup_tutorial_dialog():
	"""Setup tutorial dialog using scene-based approach (MYTHOS ARCHITECTURE)"""
	print("TutorialManager: Setting up tutorial dialog...")
	
	# Don't create if already exists and valid
	if tutorial_dialog and is_instance_valid(tutorial_dialog):
		print("TutorialManager: Dialog already exists and is valid")
		return
	
	# Load the TutorialDialog scene
	if not tutorial_dialog_scene:
		print("TutorialManager: ERROR - Could not load TutorialDialog scene")
		return
	
	tutorial_dialog = tutorial_dialog_scene.instantiate() as TutorialDialog
	if not tutorial_dialog:
		print("TutorialManager: ERROR - Failed to create TutorialDialog instance")
		return
	
	print("TutorialManager: TutorialDialog instantiated successfully")
	
	# Connect to the dialog's completion signal
	tutorial_dialog.dialog_completed.connect(_on_dialog_completed)
	print("TutorialManager: Connected to dialog_completed signal")
	
	print("TutorialManager: Tutorial dialog setup complete - will add to scene when needed")

func _ensure_dialog_in_scene():
	"""Ensure the tutorial dialog is added to the MainUIOverlay"""
	if not tutorial_dialog:
		print("TutorialManager: ERROR - No dialog to add to scene")
		return
		
	# Check if already in scene tree
	if tutorial_dialog.get_parent():
		print("TutorialManager: Dialog already in scene tree")
		return
	
	# Emit signal for MainUIOverlay to handle positioning
	print("TutorialManager: Emitting tutorial_dialog_created signal for MainUIOverlay")
	tutorial_dialog_created.emit(tutorial_dialog)
	
	# Use call_deferred for fallback check instead of await
	call_deferred("_check_dialog_fallback")

func _check_dialog_fallback():
	"""Check if dialog was handled by MainUIOverlay, if not use fallback"""
	if not tutorial_dialog:
		return
		
	if not tutorial_dialog.get_parent():
		print("TutorialManager: MainUIOverlay not available, using fallback scene positioning")
		var tree = get_tree()
		if tree and tree.current_scene:
			tree.current_scene.add_child(tutorial_dialog)
			tutorial_dialog.z_index = 1000  # Make sure it's on top
			print("TutorialManager: Added TutorialDialog to scene tree with high z-index (fallback)")
		else:
			print("TutorialManager: ERROR - No scene tree available")

# ==============================================================================# ==============================================================================
# TUTORIAL DEFINITIONS
# ==============================================================================

func setup_tutorial_definitions():
	"""Define all tutorial sequences"""
	tutorial_definitions = {
		"first_time_experience": {
			"name": "Divine Commander Journey",
			"description": "Your complete journey from novice to master",
			"steps": [
				{
					"id": "welcome",
					"type": "dialog",
					"title": "Welcome, Divine Commander! 🎯",
					"text": "Greetings, chosen one! You have been selected to command a pantheon of legendary gods and goddesses.\n\nBefore you begin your conquest, let me show you the power that awaits...",
					"button_text": "Show Me!",
					"auto_advance": false
				},
				{
					"id": "combat_showcase",
					"type": "battle",
					"title": "Divine Combat Demonstration",
					"text": "Watch as legendary champions battle a mighty foe! This is the power you'll command.",
					"battle_setup": {
						"team": ["max_level_demo_god_1", "max_level_demo_god_2", "max_level_demo_god_3"],
						"enemy": "tutorial_boss",
						"auto_play": true,
						"showcase_mode": true
					}
				},
				{
					"id": "god_selection",
					"type": "selection",
					"title": "🎭 Your Divine Starting Pantheon!",
					"text": "Every great commander begins with a powerful foundation! You are being granted these three legendary champions to start your conquest:\n\n⚔️ **ARES** - God of War (Fire Element)\n• Devastating attack abilities\n• High damage output\n• Perfect for aggressive playstyles\n\n🧠 **ATHENA** - Goddess of Wisdom (Light Element)\n• Strategic battlefield control\n• Protective abilities and buffs\n• Excellent for tactical players\n\n🌊 **POSEIDON** - Lord of the Seas (Water Element)\n• Elemental magic mastery\n• Crowd control abilities\n• Great for controlling the battlefield\n\nThese three champions will form the foundation of your divine army!",
					"button_text": "Summon Champions!",
					"selection_pool": ["ares", "athena", "poseidon"],
					"selection_count": 3,
					"auto_grant": true  # Grant all 3 base gods automatically
				},
				{
					"id": "first_territory_intro",
					"type": "dialog",
					"title": "🏰 Your First Territory Awaits!",
					"text": "Now that you have your champion, it's time to prove your worth in battle!\n\nTerritories contain multiple stages of increasing difficulty. Clear all stages to claim the territory and unlock its rewards.\n\n**Your Goal**: Clear Stage 1 of the Enchanted Grove to begin your conquest!",
					"button_text": "To Battle!",
					"navigation_target": "territory_screen"
				}
			]
		},
		
		# Progressive tutorial stages triggered by territory completion
		"territory_stage_1_complete": {
			"name": "First Victory Collection Unlock",
			"description": "Level up and unlock Collection screen",
			"trigger": "territory_stage_cleared",
			"steps": [
				{
					"id": "victory_celebration",
					"type": "dialog", 
					"title": "🎉 Victory! Your Legend Begins!",
					"text": "Magnificent! You've cleared your first stage and proven your worth as a Divine Commander!\n\n**Experience Gained**: +25 XP\n**Level Progress**: {level_after_reward}\n\n🏆 **NEW FEATURE UNLOCKED**: Collection Screen\nView all your gods, check their stats, and track your growing pantheon!",
					"button_text": "Explore Collection!",
					"xp_reward": 25,
					"unlock_features": ["collection"],
					"navigation_target": "collection_screen"
				}
			]
		},
		
		"territory_stage_2_complete": {
			"name": "Summoning Portal Unlock",
			"description": "Unlock divine summoning system",
			"trigger": "territory_stage_cleared",
			"steps": [
				{
					"id": "summon_unlock",
					"type": "dialog",
					"title": "✨ The Summoning Portal Awakens!",
					"text": "Your growing power has awakened an ancient portal!\n\n**Experience Gained**: +35 XP\n**Level Progress**: {level_after_reward}\n\n🌟 **NEW FEATURE UNLOCKED**: Divine Summoning\nCall forth new gods to join your pantheon! Each summon brings a chance for legendary champions.",
					"button_text": "Access Portal!",
					"xp_reward": 35,
					"unlock_features": ["summon"],
					"navigation_target": "summon_screen"
				}
			]
		},

		"territory_stage_3_complete": {
			"name": "Sacrifice Altar Unlock",
			"description": "Learn to strengthen champions through sacrifice",
			"trigger": "territory_stage_cleared", 
			"steps": [
				{
					"id": "sacrifice_unlock",
					"type": "dialog",
					"title": "🔥 Ancient Sacrifice Altar Revealed!",
					"text": "Your conquests have revealed a sacred altar of power!\n\n**Experience Gained**: +45 XP\n**Level Progress**: {level_after_reward}\n\n⚡ **NEW FEATURE UNLOCKED**: Divine Sacrifice\nSacrifice weaker gods to strengthen your champions! Transfer power between your divine beings.",
					"button_text": "Approach Altar!",
					"xp_reward": 45,
					"unlock_features": ["sacrifice"],
					"navigation_target": "sacrifice_screen"
				}
			]
		},

		"territory_stage_4_complete": {
			"name": "Territory Management Mastery",
			"description": "Master territorial control and resource generation",
			"trigger": "territory_stage_cleared",
			"steps": [
				{
					"id": "management_unlock",
					"type": "dialog",
					"title": "👑 Territory Management Mastery!",
					"text": "You've proven yourself a true strategic commander!\n\n**Experience Gained**: +55 XP\n**Level Progress**: You're now Level 5!\n\n🏰 **NEW FEATURE UNLOCKED**: Territory Management\nAssign gods to defend territories, manage resources, and optimize your empire's growth!",
					"button_text": "Rule Empire!",
					"xp_reward": 55,
					"unlock_features": ["territory_management"],
					"navigation_target": "territory_role_screen"
				}
			]
		},

		"territory_stage_5_complete": {
			"name": "Divine Armory Access",
			"description": "Unlock equipment and gear system",
			"trigger": "territory_stage_cleared",
			"steps": [
				{
					"id": "equipment_unlock",
					"type": "dialog",
					"title": "⚔️ Divine Armory Unlocked!",
					"text": "Your legendary status has opened the divine armory!\n\n**Experience Gained**: +65 XP\n**Level Progress**: You're now Level 6!\n\n🛡️ **NEW FEATURE UNLOCKED**: Divine Equipment\nEquip your gods with legendary weapons, armor, and artifacts to enhance their divine powers!",
					"button_text": "Enter Armory!",
					"xp_reward": 65,
					"unlock_features": ["equipment"],
					"navigation_target": "equipment_screen"
				}
			]
		},
		"summon_system_tutorial": {
			"name": "Divine Summoning",
			"description": "Learn to call forth new gods",
			"steps": [
				{
					"id": "summon_intro",
					"type": "dialog", 
					"title": "The Summoning Portal",
					"text": "You've unlocked the power to summon new gods! Each summon requires souls - the essence of divine power.",
					"auto_advance": false
				},
				{
					"id": "free_summon",
					"type": "summon_action",
					"title": "Your First Summon",
					"text": "Use your free summon ticket to call forth a new ally!",
					"summon_type": "free_ticket"
				},
				{
					"id": "summon_explanation",
					"type": "dialog",
					"title": "Building Your Pantheon",
					"text": "Collect different gods with various elements and roles. Rare gods are more powerful!",
					"auto_advance": true
				}
			]
		},
		"sacrifice_system_tutorial": {
			"name": "Divine Sacrifice", 
			"description": "Learn to empower gods through sacrifice",
			"steps": [
				{
					"id": "sacrifice_intro",
					"type": "dialog",
					"title": "The Altar of Sacrifice",
					"text": "Weaker gods can be sacrificed to empower your champions. This is the path to divine ascension!",
					"auto_advance": false
				},
				{
					"id": "sacrifice_demo",
					"type": "sacrifice_action",
					"title": "First Sacrifice",
					"text": "Select the sacrificial god I've given you, then choose a champion to receive the power.",
					"required_sacrifice": true
				}
			]
		},
		"territory_management_tutorial": {
			"name": "Divine Administration",
			"description": "Learn to manage conquered territories",
			"steps": [
				{
					"id": "management_intro",
					"type": "dialog",
					"title": "Territory Management",
					"text": "Conquered territories can be assigned gods to generate resources passively. This is your divine economy!",
					"auto_advance": false
				},
				{
					"id": "role_assignment",
					"type": "management_action",
					"title": "Assign Your First God",
					"text": "Assign one of your gods to the Gatherer role in your conquered territory.",
					"action_type": "assign_god_to_role"
				},
				{
					"id": "resource_explanation",
					"type": "dialog",
					"title": "Passive Income",
					"text": "Your assigned gods will now generate resources over time. Check back regularly to collect them!",
					"auto_advance": true
				}
			]
		},
		"equipment_system_tutorial": {
			"name": "Divine Equipment",
			"description": "Learn to equip gods with artifacts",
			"steps": [
				{
					"id": "equipment_intro",
					"type": "dialog",
					"title": "Divine Artifacts",
					"text": "You've discovered divine equipment! These artifacts greatly enhance your gods' power.",
					"auto_advance": false
				},
				{
					"id": "equip_demo",
					"type": "equipment_action",
					"title": "Equip Your First Artifact",
					"text": "Select a god and equip them with the artifact you found. Watch their power increase!",
					"action_type": "equip_item"
				},
				{
					"id": "equipment_explanation",
					"type": "dialog",
					"title": "Growing Stronger",
					"text": "Equipment can be enhanced and combined. Seek out dungeons for the best artifacts!",
					"auto_advance": true
				}
			]
		}
	}

# ==============================================================================
# TUTORIAL EXECUTION
# ==============================================================================

func start_tutorial(tutorial_name: String):
	"""Start a specific tutorial sequence with robust error handling"""
	print("TutorialManager: Attempting to start tutorial: %s" % tutorial_name)
	
	# Validate tutorial dialog is ready (MYTHOS ARCHITECTURE - robust error handling)
	if not tutorial_dialog or not is_instance_valid(tutorial_dialog):
		print("WARNING: Tutorial dialog not ready, re-initializing...")
		_setup_tutorial_dialog()
		
		if not tutorial_dialog or not is_instance_valid(tutorial_dialog):
			print("ERROR: TutorialManager - Failed to initialize tutorial dialog!")
			return false
	
	# Validate system readiness (MYTHOS ARCHITECTURE - robust error handling)
	if not game_manager or not is_instance_valid(game_manager):
		print("ERROR: TutorialManager - GameManager reference invalid!")
		return false
		
	if not player_data or not is_instance_valid(player_data):
		print("ERROR: TutorialManager - PlayerData reference invalid!")
		return false
	
	# Validate tutorial exists
	if not tutorial_definitions.has(tutorial_name):
		print("ERROR: TutorialManager - Tutorial not found: %s" % tutorial_name)
		return false
	
	# Check if already completed
	if is_tutorial_completed(tutorial_name):
		print("TutorialManager: Tutorial already completed: %s" % tutorial_name)
		return false
	
	# Check if another tutorial is already active
	if tutorial_active:
		print("WARNING: TutorialManager - Another tutorial is active. Stopping previous tutorial.")
		stop_current_tutorial()
	
	# Start the tutorial
	current_tutorial = tutorial_name
	current_step = 0
	tutorial_active = true
	
	print("🎯 TutorialManager: Starting Tutorial: %s" % tutorial_name)
	tutorial_started.emit(tutorial_name)
	
	# Execute first step with error handling
	execute_current_step()
	return true

func stop_current_tutorial():
	"""Stop any currently active tutorial"""
	if tutorial_active and current_tutorial != "":
		print("TutorialManager: Stopping tutorial: %s" % current_tutorial)
		tutorial_active = false
		current_tutorial = ""
		current_step = 0
		
		# Hide dialog if visible
		if tutorial_dialog and tutorial_dialog.visible:
			tutorial_dialog.visible = false
			
		# Unpause the game if it was paused
		if get_tree():
			get_tree().paused = false

func execute_current_step():
	"""Execute the current tutorial step"""
	print("TutorialManager: execute_current_step() called")
	print("TutorialManager: Tutorial active: ", tutorial_active, " Current tutorial: ", current_tutorial)
	
	if not tutorial_active or current_tutorial == "":
		print("TutorialManager: Tutorial not active or no current tutorial, returning")
		return
	
	var tutorial_data = tutorial_definitions[current_tutorial]
	var steps = tutorial_data.get("steps", [])
	
	print("TutorialManager: Current step: ", current_step, " Total steps: ", steps.size())
	
	if current_step >= steps.size():
		print("TutorialManager: Reached end of tutorial, completing...")
		complete_tutorial()
		return
	
	var step_data = steps[current_step]
	var step_type = step_data.get("type", "dialog")
	
	print("📋 Tutorial Step: ", step_data.get("title", "Step " + str(current_step + 1)))
	print("TutorialManager: Step type: ", step_type)
	
	match step_type:
		"dialog":
			execute_dialog_step(step_data)
		"battle":
			execute_battle_step(step_data)
		"selection":
			execute_selection_step(step_data)
		"navigation":
			execute_navigation_step(step_data)
		"summon_action":
			execute_summon_step(step_data)
		"sacrifice_action":
			execute_sacrifice_step(step_data)
		"management_action":
			execute_management_step(step_data)
		"equipment_action":
			execute_equipment_step(step_data)
		_:
			print("Unknown tutorial step type: ", step_type)
			advance_tutorial_step()

func execute_dialog_step(step_data: Dictionary):
	"""Execute a dialog tutorial step using modular UI system"""
	print("🗨️ Tutorial Dialog: ", step_data.get("title", "Tutorial Step"))
	
	# Ensure dialog is ready
	if not tutorial_dialog or not is_instance_valid(tutorial_dialog):
		print("TutorialManager: Re-creating tutorial dialog for step...")
		_setup_tutorial_dialog()
	
	if not tutorial_dialog or not is_instance_valid(tutorial_dialog):
		print("ERROR: Could not create tutorial dialog for step")
		return
	
	# Ensure dialog is in scene tree
	_ensure_dialog_in_scene()
	
	# Process any immediate rewards/unlocks from this step
	_process_step_rewards(step_data)
	
	# Show the tutorial step using the scene-based dialog with enhanced data
	var enhanced_data = step_data.duplicate()
	enhanced_data["tutorial_step"] = current_step + 1
	enhanced_data["total_steps"] = tutorial_definitions[current_tutorial].get("steps", []).size()
	enhanced_data["tutorial_name"] = current_tutorial
	
	tutorial_dialog.show_tutorial_step(enhanced_data)
	print("TutorialManager: Dialog step displayed with enhanced tutorial data")

func _process_step_rewards(step_data: Dictionary):
	"""Process XP rewards and feature unlocks for a tutorial step"""
	
	# Grant XP reward if specified
	if step_data.has("xp_reward"):
		var xp_amount = step_data["xp_reward"]
		if progression_manager and is_instance_valid(progression_manager):
			print("TutorialManager: Granting XP reward: ", xp_amount)
			progression_manager.add_player_experience(xp_amount)
		else:
			print("WARNING: Cannot grant XP - ProgressionManager not available")
	
	# Unlock features if specified
	if step_data.has("unlock_features"):
		var features = step_data["unlock_features"]
		for feature in features:
			print("TutorialManager: Unlocking feature: ", feature)
			# Signal feature unlock to game systems
			feature_unlocked.emit(feature)
	
	# Grant resources if specified  
	if step_data.has("grant_resources"):
		var resources = step_data["grant_resources"]
		for resource_data in resources:
			var resource_type = resource_data.get("type", "")
			var amount = resource_data.get("amount", 0)
			print("TutorialManager: Granting resource: ", resource_type, " x", amount)
			# Signal resource grant to game systems
			resource_granted.emit(resource_type, amount)
	
	# Handle navigation target
	if step_data.has("navigation_target"):
		# Store navigation target for after dialog completion
		_pending_navigation = step_data["navigation_target"]

func execute_battle_step(step_data: Dictionary):
	"""Execute a battle demonstration step"""
	var battle_setup = step_data.get("battle_setup", {})
	
	# Set up demo battle with max level gods
	setup_tutorial_battle(battle_setup)

func execute_selection_step(step_data: Dictionary):
	"""Execute a god selection step with player choice support (MYTHOS ARCHITECTURE)"""
	var selection_pool = step_data.get("selection_pool", [])
	var selection_count = step_data.get("selection_count", 1)
	var auto_grant = step_data.get("auto_grant", false)
	
	if auto_grant:
		# Auto-grant all gods in the selection pool (old starter team method)
		print("🎁 TutorialManager: Auto-granting starter gods: ", selection_pool)
		grant_starter_gods(selection_pool)
		# Auto-advance to next step
		advance_tutorial_step()
	else:
		# Show god selection UI for player choice (NEW Summoners War style)
		print("⚡ TutorialManager: Showing god selection UI for player choice")
		show_god_selection_ui(selection_pool, selection_count)

func show_god_selection_ui(god_pool: Array, selection_count: int):
	"""Display god selection UI for player to choose their starter god"""
	# For now, implement a simple auto-selection of the first god
	# TODO: Create proper god selection UI scene
	print("TutorialManager: Player selecting from: ", god_pool)
	print("TutorialManager: Selection count: ", selection_count)
	
	# For demo purposes, automatically select the first god
	# In the real implementation, this would show a selection UI
	var selected_gods = []
	for i in range(min(selection_count, god_pool.size())):
		selected_gods.append(god_pool[i])
	
	print("TutorialManager: Selected gods (auto for now): ", selected_gods)
	handle_god_selection_completed(selected_gods)

func grant_starter_gods(god_ids: Array):
	"""Grant starter gods to the player (MYTHOS ARCHITECTURE)"""
	print("🎭 TutorialManager: Granting %d starter gods: %s" % [god_ids.size(), god_ids])
	
	if not game_manager or not player_data:
		print("ERROR: Cannot grant starter gods - missing references")
		return
	
	var granted_count = 0
	for god_id in god_ids:
		# Create god using the JSON system
		var new_god = God.create_from_json(god_id)
		if new_god:
			player_data.add_god(new_god)
			granted_count += 1
			print("✨ Granted starter god %d/%d: %s (Level %d)" % [granted_count, god_ids.size(), new_god.name, new_god.level])
		else:
			print("ERROR: Failed to create starter god: %s" % god_id)
	
	# No XP awarded for receiving starter gods - players level up through gameplay
	# XP will be awarded when they clear territory stages (following Summoners War progression)
	print("� Tutorial: Starter gods granted - player will level up through territory clearing")
	
	# Save the game after granting starter gods
	if game_manager.has_method("save_game"):
		game_manager.save_game()
	
	print("🎉 Starter pantheon complete! Player now has %d total gods." % player_data.gods.size())
	
	# Verify player stays at Level 1 until first stage clear
	if progression_manager:
		var current_level = progression_manager.player_level if progression_manager.has_method("get_player_level") else 1
		print("🎯 Tutorial: Player remains at Level %d - will level up after clearing first territory stage" % current_level)
	
	print("🎉 Starter pantheon complete! Player now has %d gods." % player_data.gods.size())

func execute_navigation_step(step_data: Dictionary):
	"""Execute a navigation step"""
	var target = step_data.get("navigation_target", "")
	
	# Guide player to specific screen
	guide_to_screen(target)

func execute_summon_step(step_data: Dictionary):
	"""Execute a summon action step"""
	var summon_type = step_data.get("summon_type", "free_ticket")
	
	# Guide player through summoning
	guide_summon_action(summon_type)

func execute_sacrifice_step(step_data: Dictionary):
	"""Execute a sacrifice action step"""
	var required = step_data.get("required_sacrifice", false)
	
	# Guide player through sacrifice system
	guide_sacrifice_action(required)

func execute_management_step(step_data: Dictionary):
	"""Execute a territory management step"""
	var action_type = step_data.get("action_type", "assign_god_to_role")
	
	# Guide player through territory management
	guide_management_action(action_type)

func execute_equipment_step(step_data: Dictionary):
	"""Execute an equipment action step"""
	var action_type = step_data.get("action_type", "equip_item")
	
	# Guide player through equipment system
	guide_equipment_action(action_type)

# ==============================================================================
# TUTORIAL UI METHODS (To be implemented by UI system)
# ==============================================================================

func show_tutorial_dialog(title: String, text: String, _auto_advance: bool):
	"""Show tutorial dialog using programmatic UI system (MYTHOS ARCHITECTURE)"""
	if not tutorial_dialog:
		print("TutorialManager: No tutorial dialog available, auto-advancing: ", title)
		# Don't block the game - just advance
		call_deferred("advance_tutorial_step")
		return
	
	print("🗨️ Tutorial Dialog: ", title)
	
	# Get UI elements from metadata
	var title_label = tutorial_dialog.get_meta("title_label") if tutorial_dialog.has_meta("title_label") else null
	var message_label = tutorial_dialog.get_meta("message_label") if tutorial_dialog.has_meta("message_label") else null
	var continue_button = tutorial_dialog.get_meta("continue_button") if tutorial_dialog.has_meta("continue_button") else null
	
	# Update dialog content (with null checks)
	if title_label:
		title_label.text = title
	else:
		print("TutorialManager: Warning - title_label not found")
		
	if message_label:
		message_label.text = text  
	else:
		print("TutorialManager: Warning - message_label not found")
		
	if continue_button:
		continue_button.text = "Continue"
	else:
		print("TutorialManager: Warning - continue_button not found, auto-advancing")
		call_deferred("advance_tutorial_step")
		return
	
	# Show the dialog
	tutorial_dialog.visible = true
	
	# Pause the game while tutorial is active
	get_tree().paused = true
	
	# Safety timeout in case dialog gets stuck (10 seconds)
	get_tree().create_timer(10.0).timeout.connect(_on_dialog_timeout, CONNECT_ONE_SHOT)

func _on_dialog_timeout():
	"""Safety timeout for stuck dialogs"""
	print("TutorialManager: Dialog timeout - force advancing")
	_on_dialog_completed()

func _on_dialog_completed():
	"""Handle tutorial dialog completion"""
	print("TutorialManager: Dialog completed button pressed!")
	print("TutorialManager: Current tutorial: ", current_tutorial)
	print("TutorialManager: Current step: ", current_step)
	print("TutorialManager: Tutorial active: ", tutorial_active)
	
	# Hide the dialog
	if tutorial_dialog:
		tutorial_dialog.visible = false
		print("TutorialManager: Dialog hidden")
	else:
		print("TutorialManager: WARNING - No tutorial dialog to hide")
	
	# Unpause the game
	get_tree().paused = false
	print("TutorialManager: Game unpaused")
	
	# Handle pending navigation if specified
	if _pending_navigation != "":
		print("TutorialManager: Navigating to: ", _pending_navigation)
		_navigate_to_screen(_pending_navigation)
		_pending_navigation = ""  # Clear after navigation
	
	# Advance tutorial
	print("TutorialManager: Advancing tutorial step...")
	advance_tutorial_step()

func _navigate_to_screen(screen_name: String):
	"""Navigate to specified screen after dialog completion"""
	print("TutorialManager: Requesting navigation to: ", screen_name)
	
	# Find the WorldView in the scene tree to trigger navigation
	var world_view = _find_world_view()
	if world_view:
		print("TutorialManager: Found WorldView, triggering navigation")
		# Map tutorial screen names to WorldView button presses  
		match screen_name:
			"collection_screen":
				world_view._on_collection_building_pressed()
			"summon_screen":
				world_view._on_summon_building_pressed()
			"sacrifice_screen": 
				world_view._on_sacrifice_building_pressed()
			"territory_screen":
				world_view._on_territory_building_pressed()
			"territory_role_screen":
				# This goes to TerritoryRoleScreen which is different from TerritoryScreen
				# For now, go to territory screen as fallback
				world_view._on_territory_building_pressed()
			"equipment_screen":
				world_view._on_equipment_building_pressed()
			"dungeon_screen":
				world_view._on_dungeon_building_pressed()
			_:
				print("WARNING: Unknown screen name for navigation: ", screen_name)
	else:
		print("WARNING: Cannot navigate - WorldView not found in scene tree")

func _find_world_view() -> Control:
	"""Find WorldView node in the scene tree"""
	# Check if current scene is WorldView or has it as child
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.name == "WorldView":
		return current_scene
	
	# Search for WorldView in the scene tree
	var world_view = _search_node_by_name(get_tree().root, "WorldView")
	return world_view

func _search_node_by_name(node: Node, target_name: String) -> Node:
	"""Recursively search for a node by name"""
	if node.name == target_name:
		return node
	
	for child in node.get_children():
		var result = _search_node_by_name(child, target_name)
		if result:
			return result
	
	return null

func setup_tutorial_battle(battle_setup: Dictionary):
	"""Set up tutorial battle - instant completion for streamlined tutorial flow"""
	print("⚔️ Tutorial Battle: ", battle_setup)
	
	# Show battle explanation instantly without delay (MYTHOS ARCHITECTURE - simple flow)
	print("TutorialManager: Battle demo completed instantly - advancing to god granting")
	advance_tutorial_step()

func guide_to_screen(screen_name: String):
	"""Guide player to specific screen - to be implemented by UI system"""
	print("🧭 Navigate to: ", screen_name)
	
	# No XP awarded for navigation - players level up only by clearing territory stages
	# Following Summoners War progression: Level 1 with 3 gods → Clear first stage → Level 2 + unlock collection
	print("🎯 Tutorial: Navigating to %s - XP will be awarded after stage completion" % screen_name)
	
	# For now, auto-advance
	advance_tutorial_step()

func guide_summon_action(summon_type: String):
	"""Guide player through summon - to be implemented by summon system"""
	print("✨ Guide Summon: ", summon_type)
	
	# For now, auto-advance
	advance_tutorial_step()

func guide_sacrifice_action(required: bool):
	"""Guide player through sacrifice - to be implemented by sacrifice system"""
	print("🔥 Guide Sacrifice: Required=", required)
	
	# For now, auto-advance
	advance_tutorial_step()

func guide_management_action(action_type: String):
	"""Guide player through management - to be implemented by management system"""
	print("🏛️ Guide Management: ", action_type)
	
	# For now, auto-advance
	advance_tutorial_step()

func guide_equipment_action(action_type: String):
	"""Guide player through equipment - to be implemented by equipment system"""
	print("⚔️ Guide Equipment: ", action_type)
	
	# For now, auto-advance
	advance_tutorial_step()

# ==============================================================================
# TUTORIAL FLOW CONTROL
# ==============================================================================

func advance_tutorial_step():
	"""Advance to the next tutorial step"""
	print("TutorialManager: advance_tutorial_step() called")
	print("TutorialManager: Tutorial active: ", tutorial_active)
	
	if not tutorial_active:
		print("TutorialManager: Tutorial not active, returning")
		return
	
	current_step += 1
	print("TutorialManager: Advanced to step ", current_step)
	tutorial_step_completed.emit(current_tutorial, current_step - 1)
	
	# Execute next step or complete tutorial
	print("TutorialManager: Calling execute_current_step()...")
	execute_current_step()

func complete_tutorial():
	"""Complete the current tutorial"""
	if not tutorial_active:
		return
	
	var tutorial_name = current_tutorial
	
	# Mark as completed
	completed_tutorials.append(tutorial_name)
	
	# Save completion state
	if player_data:
		if not player_data.resources.has("completed_tutorials"):
			player_data.resources["completed_tutorials"] = {}
		player_data.resources["completed_tutorials"][tutorial_name] = true
	
	# Mark tutorial completed in progression manager
	if progression_manager:
		progression_manager.mark_tutorial_completed(tutorial_name)
	
	# Special handling for FTUE completion
	if tutorial_name == "first_time_experience":
		# Mark player as no longer first time
		if GameManager and GameManager.player_data:
			GameManager.player_data.is_first_time_player = false
			GameManager.save_game()  # Save the change immediately
			print("🎉 First Time User Experience completed!")
	
	# Reset state
	tutorial_active = false
	current_tutorial = ""
	current_step = 0
	
	print("✅ Tutorial Completed: ", tutorial_name)
	tutorial_completed.emit(tutorial_name)
	
	# Check if this unlocks anything
	handle_tutorial_completion(tutorial_name)

func handle_tutorial_completion(tutorial_name: String):
	"""Handle what happens when a tutorial is completed"""
	match tutorial_name:
		"first_time_experience":
			# Award small completion bonus XP - don't jump too many levels
			if progression_manager:
				var completion_xp = 50  # Small bonus, let natural gameplay drive progression
				progression_manager.add_player_experience(completion_xp)
				print("🎯 Tutorial: Granted %d XP for completing first-time experience" % completion_xp)
			print("FTUE completed - player ready for normal gameplay")
		"summon_system_tutorial":
			print("Player can now summon freely")
		"sacrifice_system_tutorial":
			print("Player can now sacrifice gods")
		"territory_management_tutorial":
			print("Player can now manage territories")
		"equipment_system_tutorial":
			print("Player can now use equipment system")

# ==============================================================================
# TUTORIAL STATE MANAGEMENT
# ==============================================================================

func is_tutorial_completed(tutorial_name: String) -> bool:
	"""Check if a tutorial has been completed"""
	if completed_tutorials.has(tutorial_name):
		return true
	
	# Also check player data
	if player_data:
		var completed = player_data.resources.get("completed_tutorials", {})
		return completed.get(tutorial_name, false)
	
	return false

func is_tutorial_active() -> bool:
	"""Check if any tutorial is currently active"""
	return tutorial_active

func get_current_tutorial() -> String:
	"""Get the name of the currently active tutorial"""
	return current_tutorial if tutorial_active else ""

func get_current_step() -> int:
	"""Get the current tutorial step number"""
	return current_step if tutorial_active else -1

# ==============================================================================
# TUTORIAL TRIGGERING SYSTEM
# ==============================================================================

func should_trigger_first_time_experience() -> bool:
	"""Check if player should go through FTUE"""
	return not is_tutorial_completed("first_time_experience")

func trigger_feature_tutorial(feature_name: String):
	"""Trigger tutorial for a newly unlocked feature"""
	var tutorial_map = {
		"summon_system": "summon_system_tutorial",
		"sacrifice_system": "sacrifice_system_tutorial", 
		"territory_management": "territory_management_tutorial",
		"equipment_system": "equipment_system_tutorial"
	}
	
	var tutorial_name = tutorial_map.get(feature_name, "")
	if tutorial_name != "" and not is_tutorial_completed(tutorial_name):
		start_tutorial(tutorial_name)

func trigger_territory_stage_completion(stage_number: int):
	"""Trigger progressive tutorial when player completes a territory stage"""
	var tutorial_name = "territory_stage_" + str(stage_number) + "_complete"
	
	# Check if this tutorial exists and hasn't been completed
	if tutorial_definitions.has(tutorial_name) and not is_tutorial_completed(tutorial_name):
		print("TutorialManager: Triggering territory stage completion tutorial: ", tutorial_name)
		start_tutorial(tutorial_name)
	else:
		print("TutorialManager: No tutorial for stage ", stage_number, " or already completed")

# ==============================================================================
# TUTORIAL ACTION HANDLERS
# ==============================================================================

func handle_god_selection_completed(selected_gods: Array):
	"""Handle when player completes god selection"""
	print("God selection completed: ", selected_gods)
	
	# Add selected gods to player collection
	if player_data and game_manager:
		for god_id in selected_gods:
			var god = God.create_from_json(god_id)
			if god:
				player_data.add_god(god)
				print("Added god to collection: ", god.name)
	
	advance_tutorial_step()

func handle_battle_completed():
	"""Handle when tutorial battle is completed"""
	if tutorial_active and current_tutorial.ends_with("battle"):
		advance_tutorial_step()

func handle_summon_completed():
	"""Handle when tutorial summon is completed"""
	if tutorial_active:
		advance_tutorial_step()

func handle_sacrifice_completed():
	"""Handle when tutorial sacrifice is completed"""
	if tutorial_active:
		advance_tutorial_step()

func handle_management_action_completed():
	"""Handle when tutorial management action is completed"""
	if tutorial_active:
		advance_tutorial_step()

func handle_equipment_action_completed():
	"""Handle when tutorial equipment action is completed"""
	if tutorial_active:
		advance_tutorial_step()

# ==============================================================================
# DEBUG FUNCTIONS
# ==============================================================================

func debug_reset_tutorials():
	"""Reset all completed tutorials"""
	completed_tutorials.clear()
	
	if player_data:
		player_data.resources["completed_tutorials"] = {}
	
	print("DEBUG: All tutorials reset")

func debug_complete_tutorial(tutorial_name: String):
	"""Debug function to mark tutorial as completed"""
	if tutorial_definitions.has(tutorial_name):
		completed_tutorials.append(tutorial_name)
		
		if player_data:
			if not player_data.resources.has("completed_tutorials"):
				player_data.resources["completed_tutorials"] = {}
			player_data.resources["completed_tutorials"][tutorial_name] = true
		
		print("DEBUG: Tutorial marked complete: ", tutorial_name)
	else:
		print("DEBUG: Tutorial not found: ", tutorial_name)

func get_debug_info() -> Dictionary:
	"""Get debug information about tutorial system"""
	return {
		"tutorial_active": tutorial_active,
		"current_tutorial": current_tutorial,
		"current_step": current_step,
		"completed_tutorials": completed_tutorials,
		"available_tutorials": tutorial_definitions.keys()
	}

func debug_trigger_stage_completion(stage_number: int):
	"""Debug function to manually trigger territory stage completion tutorials"""
	print("DEBUG: Manually triggering stage ", stage_number, " completion tutorial")
	trigger_territory_stage_completion(stage_number)

func debug_show_available_tutorials():
	"""Debug function to show all available tutorials"""
	print("DEBUG: Available tutorials:")
	for tutorial_name in tutorial_definitions.keys():
		var completed = is_tutorial_completed(tutorial_name)
		print("  - ", tutorial_name, " (completed: ", completed, ")")

func debug_test_summoners_war_flow():
	"""Debug function to test the complete Summoners War tutorial flow"""
	print("DEBUG: Testing Summoners War tutorial flow...")
	print("1. Resetting all tutorials and player data")
	debug_reset_tutorials()
	_debug_reset_player_data()
	
	print("2. Starting first time experience")
	start_tutorial("first_time_experience")

func _debug_reset_player_data():
	"""Reset player data for testing purposes"""
	if player_data:
		# Reset level and experience
		if progression_manager:
			progression_manager.player_level = 1
			progression_manager.player_experience = 0
		
		# Clear gods collection (except for testing)
		player_data.gods.clear()
		
		# Reset completed tutorials
		player_data.resources["completed_tutorials"] = {}
		
		print("DEBUG: Player data reset for tutorial testing")

# ==============================================================================
# FEATURE INTRODUCTION DIALOGS
# ==============================================================================

func show_feature_introduction_dialog(title: String, message: String):
	"""Show a feature introduction dialog when new systems are unlocked"""
	print("🎯 TutorialManager: Showing feature introduction - %s" % title)
	
	# Ensure dialog is ready
	if not tutorial_dialog or not is_instance_valid(tutorial_dialog):
		print("TutorialManager: Re-creating tutorial dialog...")
		_setup_tutorial_dialog()
	
	if not tutorial_dialog or not is_instance_valid(tutorial_dialog):
		print("ERROR: Could not create feature introduction dialog")
		return
	
	# Ensure dialog is in scene tree
	_ensure_dialog_in_scene()
	
	# Create tutorial data for the feature introduction
	var feature_data = {
		"title": title,
		"text": message,
		"message": message,  # Support both "text" and "message" fields
		"button_text": "Got It!",
		"tutorial_step": "Feature Introduction",
		"total_steps": 1,
		"tutorial_name": "feature_introduction"
	}
	
	# Show the dialog
	tutorial_dialog.show_tutorial_step(feature_data)
	
	print("TutorialManager: Feature introduction dialog displayed")

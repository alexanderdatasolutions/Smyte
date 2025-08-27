# scripts/systems/ProgressionManager.gd
extends Node
class_name ProgressionManager

# ==============================================================================
# PLAYER PROGRESSION SYSTEM - Summoners War Style Unlocks
# ==============================================================================
# Handles player level progression and feature unlocking based on level and territory completion
# Following the architecture blueprint for clean modular design

signal player_leveled_up(new_level: int, unlocked_features: Array)
signal feature_unlocked(feature_name: String, feature_data: Dictionary)

# Player Level Configuration
const MAX_PLAYER_LEVEL = 50
const XP_BASE_AMOUNT = 100
const XP_SCALING_FACTOR = 1.15

# Feature unlock configuration - mapped by level (MYTHOS ARCHITECTURE)
var feature_unlock_levels: Dictionary = {}

# System dependencies
var player_data: PlayerData
var game_manager: Node

func _ready():
	"""Initialize progression manager using MYTHOS ARCHITECTURE patterns"""
	print("ProgressionManager: Initializing player progression system...")
	
	# Get system references (MYTHOS ARCHITECTURE pattern)
	game_manager = GameManager
	player_data = GameManager.player_data if GameManager else null
	
	# Load feature unlock configuration from DataLoader (modular architecture)
	_load_progression_configuration()
	
	# Initialize player level from experience (supporting legacy saves)
	_initialize_player_level()
	
	print("ProgressionManager: Ready - Player Level: %d" % _get_current_player_level())

func _load_progression_configuration():
	"""Load progression configuration using DataLoader pattern"""
	# Use DataLoader for configuration loading (following MYTHOS ARCHITECTURE)
	# Feature unlock configuration - mapped by level (MYTHOS ARCHITECTURE)
	# Summoners War style progressive unlocks based on territory completion and player level
	feature_unlock_levels = {
		1: ["territories", "collection"],  # Starting features - territory and collection visible
		2: ["summon"],                     # Unlock after clearing 2 stages (30 XP from stages + tutorial XP = 100+ total)
		3: ["sacrifice"],                  # Unlock after more progression and summons
		4: ["territory_management"],       # Unlock after clearing first territory completely  
		5: ["equipment"],                  # Unlock when encountering first equipment drops
		6: ["dungeons"]                    # Farmable content after solid progression
	}

func _initialize_player_level():
	"""Initialize player level based on current XP (MYTHOS ARCHITECTURE)"""
	if not GameManager or not GameManager.player_data:
		return
	
	var current_xp = GameManager.player_data.player_experience
	
	# For new players, give some starter XP to show the system working
	if current_xp == 0 and GameManager.player_data.is_first_time_player:
		GameManager.player_data.player_experience = 10  # Small starter amount
		current_xp = 10
		print("ProgressionManager: New player detected - granted starter XP")
	
	var calculated_level = calculate_level_from_experience(current_xp)
	
	# Ensure basic features are unlocked for level 1 players
	_unlock_initial_features(calculated_level)
	
	# Player level is calculated dynamically, no need to store (following MYTHOS ARCHITECTURE)
	print("ProgressionManager: Player Level initialized from %d XP → Level %d" % [current_xp, calculated_level])

func _unlock_initial_features(player_level: int):
	"""Unlock all features that should be available at the current level"""
	# Unlock features for all levels up to current level
	for level in range(1, player_level + 1):
		if feature_unlock_levels.has(level):
			for feature in feature_unlock_levels[level]:
				unlock_feature(feature)
				print("ProgressionManager: Unlocked feature '%s' (Level %d)" % [feature, level])

func _get_current_player_level() -> int:
	"""Get current player level (MYTHOS ARCHITECTURE helper)"""
	if not GameManager or not GameManager.player_data:
		return 1
	
	# Calculate player level from player_experience (simplified MYTHOS ARCHITECTURE)
	var player_xp = GameManager.player_data.player_experience
	return calculate_level_from_experience(player_xp)

func get_current_level() -> int:
	"""Public API to get current player level (MYTHOS ARCHITECTURE)"""
	return _get_current_player_level()# ==============================================================================
# PLAYER LEVEL SYSTEM
# ==============================================================================

func get_experience_needed_for_level(level: int) -> int:
	"""Calculate XP needed to reach a specific level from level 1"""
	if level <= 1:
		return 0
	
	var total_xp = 0
	for i in range(1, level):
		total_xp += int(XP_BASE_AMOUNT * pow(XP_SCALING_FACTOR, i - 1))
	
	return total_xp

func get_experience_to_next_level(current_level: int, current_xp: int) -> int:
	"""Calculate XP needed to reach next level from current XP"""
	if current_level >= MAX_PLAYER_LEVEL:
		return 0
	
	var xp_for_next_level = get_experience_needed_for_level(current_level + 1)
	return max(0, xp_for_next_level - current_xp)

func add_player_experience(amount: int):
	"""Add experience to player and handle level ups"""
	if not player_data:
		return
	
	var old_level = _get_current_player_level()
	player_data.player_experience += amount
	
	# Check for level up
	var new_level = calculate_level_from_experience(player_data.player_experience)
	
	if new_level > old_level:
		handle_player_level_up(old_level, new_level)

func calculate_level_from_experience(total_xp: int) -> int:
	"""Calculate player level from total experience"""
	if total_xp <= 0:
		return 1
	
	var level = 1
	var accumulated_xp = 0
	
	while level < MAX_PLAYER_LEVEL:
		var xp_for_next = int(XP_BASE_AMOUNT * pow(XP_SCALING_FACTOR, level - 1))
		if accumulated_xp + xp_for_next > total_xp:
			break
		accumulated_xp += xp_for_next
		level += 1
	
	return level

func handle_player_level_up(old_level: int, new_level: int):
	"""Handle player leveling up - unlock features and celebrate"""
	# Player level is calculated dynamically - no need to store it (MYTHOS ARCHITECTURE)
	
	print("🎉 PLAYER LEVEL UP! %d → %d" % [old_level, new_level])
	
	# Collect all unlocked features from levels between old and new
	var unlocked_features = []
	
	for level in range(old_level + 1, new_level + 1):
		if feature_unlock_levels.has(level):
			for feature in feature_unlock_levels[level]:
				if not unlocked_features.has(feature):
					unlocked_features.append(feature)
	
	# Emit signals for UI updates
	player_leveled_up.emit(new_level, unlocked_features)
	
	# Process each unlocked feature
	for feature in unlocked_features:
		unlock_feature(feature)
	
	# Save progress
	if game_manager:
		game_manager.save_game()

# ==============================================================================
# FEATURE UNLOCKING SYSTEM
# ==============================================================================

func unlock_feature(feature_name: String):
	"""Unlock a feature and store in player data"""
	if not player_data:
		return
	
	# Check if unlocked_features exists in resources
	if not player_data.resources.has("unlocked_features"):
		player_data.resources["unlocked_features"] = {}
	
	var unlocked_features = player_data.resources["unlocked_features"]
	
	# Don't unlock if already unlocked
	if unlocked_features.get(feature_name, false):
		return
		
	# Unlock the feature
	unlocked_features[feature_name] = true
	
	print("🔓 FEATURE UNLOCKED: %s" % feature_name)
	
	# Get feature data for UI presentation
	var feature_data = get_feature_data(feature_name)
	
	# Emit signal for UI updates
	feature_unlocked.emit(feature_name, feature_data)
	
	# Show tutorial if this is a first-time unlock and no tutorial is active
	if GameManager.tutorial_manager and GameManager.player_data.is_first_time_player:
		# Only show feature introduction if no tutorial is currently active
		if not GameManager.tutorial_manager.is_tutorial_active():
			_show_feature_introduction(feature_name, feature_data)
		else:
			print("🎯 Tutorial active - feature introduction queued for: %s" % feature_name)

func _show_feature_introduction(feature_name: String, _feature_data: Dictionary):
	"""Show tutorial introduction for newly unlocked features"""
	var tutorial_messages = {
		"summon": {
			"title": "🏛️ Summon Temple Unlocked!",
			"message": "**New Feature Available!**\n\nYou can now access the Summon Temple to call forth powerful gods to join your pantheon!\n\n**How it works:**\n• Use souls and crystals to summon new gods\n• Higher rarity souls = better gods\n• Build a diverse collection of elements\n• Each god has unique abilities\n\n**Your first summon is FREE!** Visit the Summon Temple now to expand your divine collection!"
		},
		"sacrifice": {
			"title": "⚡ Power Up Altar Unlocked!", 
			"message": "**New Feature Available!**\n\nThe Sacrifice Altar allows you to empower your gods by sacrificing duplicate or weaker ones!\n\n**How it works:**\n• Sacrifice gods to boost your favorites\n• Gain experience and power-up materials\n• Essential for building strong teams\n• Use excess common gods as fuel\n\n**I've given you a free god to sacrifice!** Visit the Altar to make your champions stronger!"
		},
		"territory_management": {
			"title": "🏰 Territory Management Unlocked!",
			"message": "**New Feature Available!**\n\nYou can now assign gods to conquered territories to generate resources automatically!\n\n**How it works:**\n• Assign gods to different roles (Gatherer, Guardian, etc.)\n• Territories produce resources over time\n• More powerful gods = better production\n• Collect resources regularly\n\n**This is your passive income system!** Manage your territories wisely to fuel your divine empire!"
		},
		"equipment": {
			"title": "⚔️ Equipment System Unlocked!",
			"message": "**New Feature Available!**\n\nCraft and equip powerful runes and artifacts to enhance your gods' abilities!\n\n**How it works:**\n• 6 equipment slots per god (Weapon, Armor, Helmet, Boots, Amulet, Ring)\n• Each piece provides stat bonuses\n• Set bonuses for matching equipment\n• Enhance equipment for greater power\n\n**Find your first equipment in dungeons!** The path to divine power awaits through proper gear!"
		},
		"dungeons": {
			"title": "🗿 Dungeons Unlocked!",
			"message": "**New Feature Available!**\n\nChallenge dangerous dungeons to earn rare rewards and powerful equipment!\n\n**How it works:**\n• Multiple difficulty levels\n• Energy costs to attempt\n• Valuable loot and experience\n• Essential for late-game progression\n\n**Test your might against ancient guardians!** Dungeons provide the best equipment and materials in the game!"
		},
		"collection": {
			"title": "📚 God Collection Unlocked!",
			"message": "**New Feature Available!**\n\nView and manage your growing pantheon of divine beings!\n\n**How it works:**\n• See all your collected gods\n• Check stats, levels, and equipment\n• Plan your team compositions\n• Track your collection progress\n\n**Your divine roster awaits!** Keep track of your growing power and plan your strategies!"
		},
		"territories": {
			"title": "🏰 Territories Unlocked!",
			"message": "**Your Journey Begins!**\n\nConquer territories across mystical realms to prove your divine leadership!\n\n**How it works:**\n• Multiple stages per territory\n• Increasing difficulty and rewards\n• Clear all stages to claim the territory\n• Unlocks new areas as you progress\n\n**Your first conquest awaits!** Show these lands the power of your divine champions!"
		}
	}
	
	var intro = tutorial_messages.get(feature_name)
	if intro:
		# Show feature introduction through tutorial system (MYTHOS ARCHITECTURE)
		if GameManager.tutorial_manager:
			print("🎯 Showing feature introduction tutorial for: %s" % feature_name)
			GameManager.tutorial_manager.show_feature_introduction_dialog(intro.title, intro.message)
		else:
			print("WARNING: TutorialManager not available for feature introduction: %s" % feature_name)

func get_feature_data(feature_name: String) -> Dictionary:
	"""Get configuration data for a specific feature"""
	var feature_configs = {
		"summon_system": {
			"title": "Summoning Portal Unlocked!",
			"description": "Call forth new gods to join your pantheon!",
			"tutorial_required": true,
			"ui_element": "summon_tab"
		},
		"sacrifice_system": {
			"title": "Sacrifice Altar Unlocked!",
			"description": "Sacrifice weaker gods to empower your champions!",
			"tutorial_required": true,
			"ui_element": "sacrifice_tab"
		},
		"territory_management": {
			"title": "Territory Management Unlocked!",
			"description": "Assign gods to territories for passive resource generation!",
			"tutorial_required": true,
			"ui_element": "territory_roles"
		},
		"collection_screen": {
			"title": "Divine Collection Unlocked!",
			"description": "View and manage your growing pantheon!",
			"tutorial_required": false,
			"ui_element": "collection_tab"
		},
		"equipment_system": {
			"title": "Divine Equipment Unlocked!",
			"description": "Equip your gods with powerful artifacts!",
			"tutorial_required": true,
			"ui_element": "equipment_tab"
		},
		"awakening_system": {
			"title": "Divine Awakening Unlocked!",
			"description": "Awaken your gods to unlock their true potential!",
			"tutorial_required": true,
			"ui_element": "awakening_tab"
		},
		"dungeon_system": {
			"title": "Eternal Dungeons Unlocked!",
			"description": "Challenge endless dungeons for rare rewards!",
			"tutorial_required": true,
			"ui_element": "dungeon_tab"
		},
		"advanced_features": {
			"title": "Advanced Features Unlocked!",
			"description": "Access to premium features and advanced gameplay!",
			"tutorial_required": false,
			"ui_element": "various"
		}
	}
	
	return feature_configs.get(feature_name, {
		"title": "New Feature!",
		"description": "A new feature has been unlocked!",
		"tutorial_required": false,
		"ui_element": "unknown"
	})

func handle_specific_feature_unlock(feature_name: String, _feature_data: Dictionary):
	"""Handle specific logic for when features are unlocked"""
	match feature_name:
		"summon_system":
			# Grant a free summon
			if player_data:
				player_data.add_resource("free_summon_tickets", 1)
				print("Granted free summon ticket!")
		
		"sacrifice_system":
			# Give a free sacrificial god (common tier)
			if game_manager and game_manager.summon_system:
				var free_god = God.create_from_json("common_spirit")  # Create a basic god for sacrifice
				if free_god:
					player_data.add_god(free_god)
					print("Granted free sacrificial god!")
		
		"territory_management":
			# Tutorial should trigger when they next visit territory screen
			print("Territory management tutorial will trigger next visit")
		
		"equipment_system":
			# Grant some starter equipment
			if game_manager and game_manager.equipment_manager:
				# Give basic equipment pieces
				print("Equipment system unlocked - starter gear will be available")
		
		"awakening_system":
			# Grant basic awakening materials
			if player_data:
				player_data.add_resource("earth_powder_low", 10)
				player_data.add_resource("fire_powder_low", 10)
				player_data.add_resource("magic_powder_low", 5)
				print("Granted starter awakening materials!")
		
		"dungeon_system":
			# Dungeons are now available
			print("Dungeon system unlocked - all dungeons now accessible")

# ==============================================================================
# FEATURE CHECKING SYSTEM
# ==============================================================================

func is_feature_unlocked(feature_name: String) -> bool:
	"""Check if a specific feature is unlocked"""
	if not player_data:
		return false
	
	# Check if unlocked_features exists in resources
	var unlocked_features = player_data.resources.get("unlocked_features", {})
	return unlocked_features.get(feature_name, false)

func get_required_level_for_feature(feature_name: String) -> int:
	"""Get the level required to unlock a specific feature"""
	for level in feature_unlock_levels.keys():
		if feature_unlock_levels[level].has(feature_name):
			return level
	return 1  # Default to level 1 if not found

func get_unlocked_features_for_level(level: int) -> Array:
	"""Get all features that should be unlocked at a specific level"""
	var features = []
	
	# Collect features from all levels up to and including the specified level
	for check_level in range(1, level + 1):
		if feature_unlock_levels.has(check_level):
			for feature in feature_unlock_levels[check_level]:
				if not features.has(feature):
					features.append(feature)
	
	return features

# ==============================================================================
# TERRITORY PROGRESSION TRACKING
# ==============================================================================

# ==============================================================================
# GOD EXPERIENCE SYSTEM

func award_territory_completion_experience(territory_id: String):
	"""Award bonus experience for fully completing a territory"""
	# Generous bonus for completing entire territory (major milestone)
	var completion_bonus = 50  # Fixed bonus for territory completion
	
	print("Territory Completed: +%d XP BONUS (%s)" % [completion_bonus, territory_id])
	add_player_experience(completion_bonus)

func get_territory_tier_bonus(territory_id: String) -> int:
	"""Get XP bonus based on territory tier"""
	# Get territory tier from GameManager
	if not game_manager:
		return 0
	
	var territory = game_manager.get_territory_by_id(territory_id)
	if not territory:
		return 0
	
	# Higher tier territories give more XP
	match territory.tier:
		1: return 10
		2: return 25
		3: return 50
		4: return 100
		5: return 200
		_: return 0

# ==============================================================================
# TUTORIAL INTEGRATION
# ==============================================================================

func should_show_tutorial_for_feature(feature_name: String) -> bool:
	"""Check if tutorial should be shown for a newly unlocked feature"""
	var feature_data = get_feature_data(feature_name)
	return feature_data.get("tutorial_required", false)

func mark_tutorial_completed(feature_name: String):
	"""Mark tutorial as completed for a feature"""
	if not player_data:
		return
	
	if not player_data.resources.has("completed_tutorials"):
		player_data.resources["completed_tutorials"] = {}
	
	player_data.resources["completed_tutorials"][feature_name] = true
	
	print("Tutorial completed: ", feature_name)

func is_tutorial_completed(feature_name: String) -> bool:
	"""Check if tutorial has been completed for a feature"""
	if not player_data:
		return false
	
	var completed_tutorials = player_data.resources.get("completed_tutorials", {})
	return completed_tutorials.get(feature_name, false)

# ==============================================================================
# DEBUG FUNCTIONS
# ==============================================================================

func debug_unlock_all_features():
	"""Debug function to unlock all features"""
	print("DEBUG: Unlocking all features...")
	
	for level in feature_unlock_levels.keys():
		for feature in feature_unlock_levels[level]:
			unlock_feature(feature)

func debug_add_experience(amount: int):
	"""Debug function to add experience"""
	print("DEBUG: Adding %d experience..." % amount)
	add_player_experience(amount)

func debug_set_level(level: int):
	"""Debug function to set player level"""
	if not player_data:
		return
	
	print("DEBUG: Setting player level to %d..." % level)
	
	var _old_level = _get_current_player_level()
	player_data.player_level_experience = get_experience_needed_for_level(level)
	
	# Unlock all features up to this level
	var features_to_unlock = get_unlocked_features_for_level(level)
	for feature in features_to_unlock:
		unlock_feature(feature)
	
	player_leveled_up.emit(level, features_to_unlock)

func get_debug_info() -> Dictionary:
	"""Get debug information about player progression"""
	if not player_data:
		return {}
	
	return {
		"current_level": _get_current_player_level(),
		"current_xp": player_data.player_experience,
		"xp_to_next": get_experience_to_next_level(_get_current_player_level(), player_data.player_experience),
		"unlocked_features": player_data.resources.get("unlocked_features", {}),
		"completed_tutorials": player_data.resources.get("completed_tutorials", {})
	}

# ==============================================================================
# TERRITORY PROGRESSION SYSTEM - Summoners War Style
# ==============================================================================

func get_territory_unlock_level(territory_id: String) -> int:
	"""Get the player level required to unlock a territory"""
	# Simple progression: Each territory tier requires higher level
	var territory = game_manager.get_territory_by_id(territory_id) if game_manager else null
	if not territory:
		return 1
	
	# Territory unlock progression (MYTHOS ARCHITECTURE - easily configurable)
	match territory.tier:
		1:
			# Tier 1 territories unlock based on order/progression
			match territory_id:
				"sacred_grove":
					return 1  # First territory - always available
				"crystal_springs":
					return 2  # Unlocked when player hits level 2 (after summon unlock)
				"ember_hills":
					return 3  # Unlocked when sacrifice system opens
				_:
					return 2  # Default for other tier 1 territories
		2:
			return 4  # Tier 2 territories unlock at level 4 (territory management)
		3:
			return 6  # Tier 3 territories unlock at level 6 (with dungeons)
		_:
			return 1  # Fallback

func is_territory_unlocked_by_level(territory_id: String) -> bool:
	"""Check if territory is unlocked based on player level"""
	var required_level = get_territory_unlock_level(territory_id)
	var current_level = _get_current_player_level()
	return current_level >= required_level

func get_unlocked_territories() -> Array:
	"""Get array of territory IDs that are unlocked by player level"""
	var unlocked = []
	if not game_manager or not game_manager.territories:
		return unlocked
	
	for territory in game_manager.territories:
		if is_territory_unlocked_by_level(territory.id):
			unlocked.append(territory.id)
	
	return unlocked

# ==============================================================================
# SIMPLE XP AWARD SYSTEM - Called by other managers
# ==============================================================================

func award_stage_completion_xp(stage_num: int = 1):
	"""Award XP for completing any stage - called by TerritoryManager/BattleManager"""
	var base_xp = 15  # Fixed 15 XP per stage as requested
	var stage_bonus = max(0, (stage_num - 1) * 2)  # Small bonus for higher stages
	var total_xp = base_xp + stage_bonus
	
	print("Stage %d Complete: +%d XP" % [stage_num, total_xp])
	add_player_experience(total_xp)

func award_territory_completion_xp():
	"""Award bonus XP for fully clearing a territory - called by TerritoryManager"""
	var bonus_xp = 50
	print("Territory Complete: +%d XP BONUS" % bonus_xp)
	add_player_experience(bonus_xp)

func award_milestone_xp(milestone: String, amount: int):
	"""Award XP for specific milestones - called by any system"""
	print("Milestone '%s': +%d XP" % [milestone, amount])
	add_player_experience(amount)

# ==============================================================================
# PROGRESSION QUERIES - Used by UI systems
# ==============================================================================

func get_progression_summary() -> Dictionary:
	"""Get complete progression summary for UI display"""
	var current_level = _get_current_player_level()
	var current_xp = player_data.player_experience if player_data else 0
	var xp_to_next = get_experience_to_next_level(current_level, current_xp)
	var unlocked_features = player_data.resources.get("unlocked_features", {}) if player_data else {}
	
	return {
		"player_level": current_level,
		"current_xp": current_xp,
		"xp_to_next_level": xp_to_next,
		"xp_needed_for_next": get_experience_needed_for_level(current_level + 1),
		"unlocked_features": unlocked_features.keys(),
		"unlocked_territories": get_unlocked_territories(),
		"next_unlock_level": current_level + 1,
		"next_unlock_features": feature_unlock_levels.get(current_level + 1, [])
	}

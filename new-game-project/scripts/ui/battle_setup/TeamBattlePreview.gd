# scripts/ui/battle_setup/TeamBattlePreview.gd
# Handles enemy and rewards preview display for battle setup
extends RefCounted

var enemy_preview_container: VBoxContainer = null
var rewards_preview_container: VBoxContainer = null

func initialize(enemy_container: VBoxContainer, rewards_container: VBoxContainer) -> void:
	enemy_preview_container = enemy_container
	rewards_preview_container = rewards_container

func update_enemy_preview(battle_context: Dictionary) -> void:
	if not enemy_preview_container:
		return

	for child: Node in enemy_preview_container.get_children():
		child.queue_free()

	var enemies: Array = []
	match battle_context.get("type", ""):
		"dungeon":
			enemies = _get_dungeon_enemies(battle_context)
		"hex_capture":
			enemies = _get_hex_node_defenders(battle_context)
		"territory":
			enemies = _get_territory_enemies(battle_context)
		"pvp":
			enemies = _get_pvp_enemies(battle_context)
		"tower":
			enemies = _get_tower_enemies(battle_context)
		_:
			enemies = [{"name": "Unknown", "level": 1}]

	if enemies.is_empty():
		var no_enemy: Label = Label.new()
		no_enemy.text = "No enemy info available"
		no_enemy.add_theme_font_size_override("font_size", 10)
		no_enemy.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		enemy_preview_container.add_child(no_enemy)
	else:
		for enemy: Dictionary in enemies.slice(0, 4):
			var enemy_row: HBoxContainer = HBoxContainer.new()
			enemy_row.add_theme_constant_override("separation", 8)

			var name_label: Label = Label.new()
			name_label.text = enemy.get("name", "Enemy")
			name_label.add_theme_font_size_override("font_size", 10)
			name_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.6))
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			enemy_row.add_child(name_label)

			var level_label: Label = Label.new()
			level_label.text = "Lv." + str(enemy.get("level", 1))
			level_label.add_theme_font_size_override("font_size", 10)
			level_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
			enemy_row.add_child(level_label)

			enemy_preview_container.add_child(enemy_row)

func update_rewards_preview(battle_context: Dictionary) -> void:
	if not rewards_preview_container:
		return

	for child: Node in rewards_preview_container.get_children():
		child.queue_free()

	var rewards: Dictionary = {}
	match battle_context.get("type", ""):
		"dungeon":
			rewards = _get_dungeon_rewards(battle_context)
		"hex_capture":
			rewards = _get_hex_node_rewards(battle_context)
		"territory":
			rewards = _get_territory_rewards(battle_context)
		"tower":
			rewards = _get_tower_rewards(battle_context)
		_:
			rewards = {"mana": 100}

	if rewards.is_empty():
		var no_rewards: Label = Label.new()
		no_rewards.text = "No reward info available"
		no_rewards.add_theme_font_size_override("font_size", 10)
		no_rewards.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		rewards_preview_container.add_child(no_rewards)
	else:
		for resource_id: String in rewards:
			var amount: int = int(rewards[resource_id])
			var reward_row: HBoxContainer = HBoxContainer.new()
			reward_row.add_theme_constant_override("separation", 8)

			var name_label: Label = Label.new()
			name_label.text = resource_id.capitalize().replace("_", " ")
			name_label.add_theme_font_size_override("font_size", 10)
			name_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.9))
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			reward_row.add_child(name_label)

			var amount_label: Label = Label.new()
			amount_label.text = "x" + _format_number(amount)
			amount_label.add_theme_font_size_override("font_size", 10)
			amount_label.add_theme_color_override("font_color", Color.GOLD)
			reward_row.add_child(amount_label)

			rewards_preview_container.add_child(reward_row)

# ============================================================================
# ENEMY DATA FETCHERS
# ============================================================================

func _get_dungeon_enemies(context: Dictionary) -> Array:
	var dungeon_id: String = context.get("dungeon_id", "")
	var difficulty: String = context.get("difficulty", "normal")
	var registry: Node = SystemRegistry.get_instance()
	if not registry:
		return [{"name": "Dungeon Monster", "level": 5}]
	var dungeon_manager: Node = registry.get_system("DungeonManager")
	if dungeon_manager and dungeon_manager.has_method("get_dungeon_enemies"):
		return dungeon_manager.get_dungeon_enemies(dungeon_id, difficulty)
	return [{"name": "Dungeon Monster", "level": 5}]

func _get_hex_node_defenders(context: Dictionary) -> Array:
	var hex_node: Variant = context.get("hex_node")
	if not hex_node:
		return []
	var defenders: Array = []
	for defender_name: String in hex_node.base_defenders:
		defenders.append({"name": defender_name, "level": hex_node.tier * 5})
	return defenders

func _get_territory_enemies(context: Dictionary) -> Array:
	var territory: Variant = context.get("territory")
	var stage: int = int(context.get("stage", 1))
	if not territory:
		return []
	return [{"name": "Territory Guardian", "level": stage * 3}]

func _get_pvp_enemies(context: Dictionary) -> Array:
	var opponent: Dictionary = context.get("opponent", {})
	var team: Array = opponent.get("defense_team", [])
	return team

func _get_tower_enemies(context: Dictionary) -> Array:
	var floor_num: int = int(context.get("floor", 1))
	return [{"name": "Tower Guardian", "level": floor_num * 2}]

# ============================================================================
# REWARD DATA FETCHERS
# ============================================================================

func _get_dungeon_rewards(context: Dictionary) -> Dictionary:
	var dungeon_id: String = context.get("dungeon_id", "")
	var difficulty: String = context.get("difficulty", "normal")
	var registry: Node = SystemRegistry.get_instance()
	if not registry:
		return {"mana": 500}
	var dungeon_manager: Node = registry.get_system("DungeonManager")
	if dungeon_manager and dungeon_manager.has_method("get_dungeon_rewards"):
		return dungeon_manager.get_dungeon_rewards(dungeon_id, difficulty)
	match difficulty:
		"easy": return {"mana": 500, "gold": 100}
		"normal": return {"mana": 1000, "gold": 250}
		"hard": return {"mana": 2000, "gold": 500, "divine_crystals": 5}
		"expert": return {"mana": 5000, "gold": 1000, "divine_crystals": 15}
		_: return {"mana": 500}

func _get_hex_node_rewards(context: Dictionary) -> Dictionary:
	var hex_node: Variant = context.get("hex_node")
	if not hex_node:
		return {}
	var rewards: Dictionary = {}
	if hex_node.base_production and not hex_node.base_production.is_empty():
		for resource_id: String in hex_node.base_production:
			rewards[resource_id] = hex_node.base_production[resource_id]
	return rewards

func _get_territory_rewards(context: Dictionary) -> Dictionary:
	var territory: Variant = context.get("territory")
	var stage: int = int(context.get("stage", 1))
	if not territory:
		return {}
	return {"mana": 500 * stage, "gold": 100 * stage}

func _get_tower_rewards(context: Dictionary) -> Dictionary:
	var floor_num: int = int(context.get("floor", 1))
	return {"mana": 1000 * floor_num, "divine_crystals": floor_num}

# ============================================================================
# HELPERS
# ============================================================================

func _format_number(num: int) -> String:
	if num >= 1000000:
		return "%.1fM" % (num / 1000000.0)
	elif num >= 1000:
		return "%.1fK" % (num / 1000.0)
	return str(num)

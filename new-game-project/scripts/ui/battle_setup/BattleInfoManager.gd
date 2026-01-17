# scripts/ui/battle_setup/BattleInfoManager.gd
# Single responsibility: Manage battle information display (enemies, rewards, etc)
class_name BattleInfoManager
extends Node

var enemy_preview_container: VBoxContainer = null
var rewards_container: VBoxContainer = null
var title_label: Label = null
var description_label: Label = null

var battle_context: Dictionary = {}

func initialize(enemy_container: VBoxContainer, reward_container: VBoxContainer, title_lbl: Label = null, desc_lbl: Label = null):
	"""Initialize with node references from the scene"""
	enemy_preview_container = enemy_container
	rewards_container = reward_container
	title_label = title_lbl
	description_label = desc_lbl

func update_for_context(context: Dictionary):
	battle_context = context
	_update_display()

func update_team_preview(_team: Array):
	# Could show team power preview, element balance, etc.
	pass

func _update_display():
	match battle_context.get("type", ""):
		"territory":
			_display_territory_info()
		"dungeon":
			_display_dungeon_info()
		"pvp":
			_display_pvp_info()
		"hex_capture":
			_display_hex_capture_info()

func _display_territory_info():
	var territory = battle_context.get("territory")
	var stage = battle_context.get("stage", 1)

	if title_label:
		title_label.text = "Territory Battle"
	if description_label:
		description_label.text = "Attack %s - Stage %d" % [territory.name, stage]

	_show_territory_enemies(territory, stage)
	_show_territory_rewards(territory, stage)

func _display_dungeon_info():
	var dungeon_id = battle_context.get("dungeon_id")
	var difficulty = battle_context.get("difficulty")

	if title_label:
		title_label.text = "Dungeon Battle"
	if description_label:
		description_label.text = "%s - %s" % [dungeon_id.capitalize(), difficulty.capitalize()]

	_show_dungeon_enemies(dungeon_id, difficulty)
	_show_dungeon_rewards(dungeon_id, difficulty)

func _display_pvp_info():
	var opponent = battle_context.get("opponent")

	if title_label:
		title_label.text = "PvP Battle"
	if description_label:
		description_label.text = "vs %s" % opponent.get("name", "Unknown Player")

	_show_pvp_enemies(opponent)
	_show_pvp_rewards()

func _display_hex_capture_info():
	var hex_node = battle_context.get("hex_node")

	if title_label:
		title_label.text = "Hex Node Capture"
	if description_label and hex_node:
		description_label.text = "Capture: %s (Tier %d)" % [hex_node.name, hex_node.tier]

	if hex_node:
		_show_hex_node_defenders(hex_node)
		_show_hex_node_rewards(hex_node)

func _show_territory_enemies(territory: Territory, stage: int):
	_clear_enemy_preview()
	
	var enemy_factory = SystemRegistry.get_instance().get_system("EnemyFactory")
	var enemies = enemy_factory.get_territory_enemies(territory.id, stage)
	
	for enemy in enemies:
		var enemy_card = _create_enemy_preview_card(enemy)
		enemy_preview_container.add_child(enemy_card)

func _show_dungeon_enemies(dungeon_id: String, difficulty: String):
	_clear_enemy_preview()
	
	var dungeon_manager = SystemRegistry.get_instance().get_system("DungeonManager")
	var enemies = dungeon_manager.get_dungeon_enemies(dungeon_id, difficulty)
	
	for enemy in enemies:
		var enemy_card = _create_enemy_preview_card(enemy)
		enemy_preview_container.add_child(enemy_card)

func _show_pvp_enemies(opponent: Dictionary):
	_clear_enemy_preview()
	
	var opponent_team = opponent.get("defense_team", [])
	for god_data in opponent_team:
		var enemy_card = _create_god_preview_card(god_data)
		enemy_preview_container.add_child(enemy_card)

func _show_territory_rewards(territory: Territory, stage: int):
	_clear_rewards()
	
	var territory_manager = SystemRegistry.get_instance().get_system("TerritoryManager")
	var rewards = territory_manager.get_battle_rewards(territory.id, stage)
	
	_display_rewards(rewards)

func _show_dungeon_rewards(dungeon_id: String, difficulty: String):
	_clear_rewards()
	
	var dungeon_manager = SystemRegistry.get_instance().get_system("DungeonManager")
	var rewards = dungeon_manager.get_dungeon_rewards(dungeon_id, difficulty)
	
	_display_rewards(rewards)

func _show_pvp_rewards():
	_clear_rewards()
	
	var pvp_manager = SystemRegistry.get_instance().get_system("ArenaManager")
	var rewards = pvp_manager.get_battle_rewards()
	
	_display_rewards(rewards)

func _display_rewards(rewards: Dictionary):
	for resource_type in rewards:
		var amount = rewards[resource_type]
		var reward_item = _create_reward_item(resource_type, amount)
		rewards_container.add_child(reward_item)

func _create_enemy_preview_card(enemy: Dictionary) -> Control:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(80, 100)
	
	var container = VBoxContainer.new()
	card.add_child(container)
	
	var name_label = Label.new()
	name_label.text = enemy.get("name", "Enemy")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(name_label)
	
	var level_label = Label.new()
	level_label.text = "Lv." + str(enemy.get("level", 1))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(level_label)
	
	return card

func _create_god_preview_card(god_data: Dictionary) -> Control:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(80, 100)
	
	var container = VBoxContainer.new()
	card.add_child(container)
	
	var name_label = Label.new()
	name_label.text = god_data.get("name", "God")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(name_label)
	
	var level_label = Label.new()
	level_label.text = "Lv." + str(god_data.get("level", 1))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(level_label)
	
	return card

func _create_reward_item(resource_type: String, amount: int) -> Control:
	var item = HBoxContainer.new()
	
	var icon = TextureRect.new()  # Would load resource icon
	item.add_child(icon)
	
	var label = Label.new()
	label.text = "%s x%d" % [resource_type.capitalize(), amount]
	item.add_child(label)
	
	return item

func _show_hex_node_defenders(hex_node: HexNode):
	_clear_enemy_preview()

	# Show base defenders for the hex node
	for defender_id in hex_node.base_defenders:
		var collection_manager = SystemRegistry.get_instance().get_system("CollectionManager")
		var defender = collection_manager.get_god_by_id(defender_id)
		if defender:
			var card = _create_enemy_preview_card({
				"name": defender.name,
				"level": defender.level
			})
			enemy_preview_container.add_child(card)

func _show_hex_node_rewards(hex_node: HexNode):
	_clear_rewards()

	# Show rewards based on node tier and resource type
	var base_reward = hex_node.tier * 10
	var rewards = {
		hex_node.resource_type: base_reward
	}

	_display_rewards(rewards)

func _clear_enemy_preview():
	if enemy_preview_container:
		for child in enemy_preview_container.get_children():
			child.queue_free()

func _clear_rewards():
	if rewards_container:
		for child in rewards_container.get_children():
			child.queue_free()

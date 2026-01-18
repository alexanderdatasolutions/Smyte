extends SceneTree

func _init():
	var dm = DungeonManager.new()
	dm._ready()
	
	print("\n=== NEW BALANCE TEST ===")
	print("\nLevel 10 Basic Enemy (Fire Sanctum Beginner - Wave 1):")
	var basic = dm._calculate_enemy_stats(10, "basic")
	print("  HP: ", basic.hp, " | ATK: ", basic.attack, " | DEF: ", basic.defense, " | SPD: ", basic.speed)
	
	print("\nLevel 15 Leader Enemy:")
	var leader = dm._calculate_enemy_stats(15, "leader")
	print("  HP: ", leader.hp, " | ATK: ", leader.attack, " | DEF: ", leader.defense, " | SPD: ", leader.speed)
	
	print("\nLevel 25 Boss Enemy:")
	var boss = dm._calculate_enemy_stats(25, "boss")
	print("  HP: ", boss.hp, " | ATK: ", boss.attack, " | DEF: ", boss.defense, " | SPD: ", boss.speed)
	
	print("\n=== COMPARISON TO GODS ===")
	print("Average Level 10 God: ~228 HP, ~110 ATK, ~140 DEF, ~80 SPD")
	print("\n=== ENERGY COSTS ===")
	var fire_sanctum = dm.get_dungeon_info("fire_sanctum")
	print("Fire Sanctum Beginner: ", fire_sanctum.difficulty_levels.beginner.energy_cost, " energy")
	print("Fire Sanctum Expert: ", fire_sanctum.difficulty_levels.expert.energy_cost, " energy")
	
	print("\n=== MANA REWARDS (First Clear) ===")
	print("Beginner: ", fire_sanctum.difficulty_levels.beginner.first_clear_rewards.mana, " mana")
	print("Expert: ", fire_sanctum.difficulty_levels.expert.first_clear_rewards.mana, " mana")
	
	quit()

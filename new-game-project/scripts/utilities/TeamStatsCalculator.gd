# scripts/utilities/TeamStatsCalculator.gd
# Single responsibility: Calculate team combat power and bonuses from team_bonuses.json
class_name TeamStatsCalculator
extends RefCounted

## Cached bonus data from JSON
static var _bonus_data: Dictionary = {}
static var _data_loaded: bool = false

## Load bonus data from JSON (called once, cached for future use)
static func _ensure_data_loaded() -> void:
	if _data_loaded:
		return

	var file_path = "res://data/team_bonuses.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("TeamStatsCalculator: Could not load team_bonuses.json")
		_data_loaded = true
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("TeamStatsCalculator: Failed to parse team_bonuses.json")
		_data_loaded = true
		return

	_bonus_data = json.get_data()
	_data_loaded = true

## Calculate total team combat power
static func calculate_team_power(team: Array) -> int:
	var total_power = 0
	for god in team:
		if god != null:
			total_power += CombatCalculator.calculate_total_power(god)
	return total_power

## Calculate individual god power for display
static func calculate_god_power(god: God) -> int:
	return CombatCalculator.calculate_total_power(god)

## Get all active team bonuses
static func get_team_bonuses(team: Array, node_type: String = "") -> Array:
	_ensure_data_loaded()

	var bonuses = []
	var valid_team = _get_valid_team(team)

	if valid_team.is_empty():
		return bonuses

	# Check each category of bonuses
	var element_bonuses = _check_element_bonuses(valid_team)
	bonuses.append_array(element_bonuses)

	var pantheon_bonuses = _check_pantheon_bonuses(valid_team)
	bonuses.append_array(pantheon_bonuses)

	var tier_bonuses = _check_tier_bonuses(valid_team)
	bonuses.append_array(tier_bonuses)

	var special_bonuses = _check_special_synergies(valid_team)
	bonuses.append_array(special_bonuses)

	# Check territory synergies if node type is specified
	if node_type != "":
		var territory_bonuses = _check_territory_synergies(valid_team, node_type)
		bonuses.append_array(territory_bonuses)

	return bonuses

## Get summary text for team bonuses
static func get_bonuses_summary(team: Array) -> String:
	var bonuses = get_team_bonuses(team)
	if bonuses.is_empty():
		return "No team bonuses"

	var summary_parts = []
	for bonus in bonuses:
		summary_parts.append(bonus.name)
	return ", ".join(summary_parts)

## Get leader skill info from the first god in the team
## Returns Dictionary with god_name, leader_skill, description, and applicable_count
static func get_leader_skill_info(team: Array) -> Dictionary:
	var valid_team = _get_valid_team(team)
	if valid_team.is_empty():
		return {}

	var leader: God = valid_team[0]
	if leader.leader_skill.is_empty():
		return {}

	var skill_area: String = leader.leader_skill.get("area", "all")

	# Check for new "bonuses" format OR legacy "type"/"value" format
	var has_bonuses: bool = leader.leader_skill.has("bonuses") and not leader.leader_skill.bonuses.is_empty()
	var skill_type: String = leader.leader_skill.get("type", "")
	var skill_value: int = int(leader.leader_skill.get("value", 0))

	# Must have either new bonuses format or legacy type/value format
	if not has_bonuses and (skill_type == "" or skill_value == 0):
		return {}

	# Count how many team members this applies to
	var applicable_count: int = 0
	for god: God in valid_team:
		if _leader_skill_applies_to(leader.leader_skill, god):
			applicable_count += 1

	var skill_name: String = leader.leader_skill.get("name", "")
	if skill_name.is_empty():
		skill_name = skill_type.capitalize() + " Boost" if skill_type else "Leader Skill"

	return {
		"leader": leader,
		"leader_name": leader.get_display_name(),
		"skill": leader.leader_skill,
		"skill_name": skill_name,
		"type": skill_type,
		"value": skill_value,
		"area": skill_area,
		"description": _format_leader_skill_description(leader.leader_skill),
		"applicable_count": applicable_count,
		"total_count": valid_team.size()
	}

## Check if leader skill applies to a specific god
static func _leader_skill_applies_to(leader_skill: Dictionary, god: God) -> bool:
	var area: String = leader_skill.get("area", "all")
	if area == "all":
		return true
	# Check if god's element matches the area
	var god_element: String = God.element_to_string(god.element).to_lower()
	return god_element == area.to_lower()

## Format leader skill for display
static func _format_leader_skill_description(leader_skill: Dictionary) -> String:
	var skill_area: String = leader_skill.get("area", "all")

	# Format area
	var area_display: String = ""
	if skill_area == "all":
		area_display = "All allies"
	else:
		area_display = skill_area.capitalize() + " allies"

	# Multi-stat format (new)
	if leader_skill.has("bonuses"):
		var parts: Array = []
		var skill_bonuses: Dictionary = leader_skill.bonuses
		for stat: String in skill_bonuses:
			var val: int = int(skill_bonuses[stat])
			var stat_display: String = stat.replace("_", " ").capitalize()
			parts.append("+%d%% %s" % [val, stat_display])
		return "%s: %s" % [area_display, ", ".join(parts)]

	# Legacy single-stat format
	var skill_type: String = leader_skill.get("type", "")
	var skill_value: int = int(leader_skill.get("value", 0))
	var type_display: String = skill_type.replace("_", " ").capitalize()

	return "%s: +%d%% %s" % [area_display, skill_value, type_display]

## Calculate leader skill stat bonuses for a specific god
static func get_leader_skill_bonuses(leader_skill: Dictionary, target_god: God) -> Dictionary:
	"""Returns stat multipliers from leader skill if applicable to target god."""
	if leader_skill.is_empty():
		return {}

	if not _leader_skill_applies_to(leader_skill, target_god):
		return {}

	var bonuses: Dictionary = {}

	# Support for multi-stat leader skills (new "bonuses" format)
	if leader_skill.has("bonuses"):
		var skill_bonuses: Dictionary = leader_skill.bonuses
		for stat: String in skill_bonuses:
			bonuses[stat] = float(skill_bonuses[stat]) / 100.0
		return bonuses

	# Legacy single-stat format
	var skill_type: String = leader_skill.get("type", "")
	var skill_value: float = float(leader_skill.get("value", 0)) / 100.0  # Convert percentage

	match skill_type:
		"attack":
			bonuses["attack"] = skill_value
		"defense":
			bonuses["defense"] = skill_value
		"hp":
			bonuses["hp"] = skill_value
		"speed":
			bonuses["speed"] = skill_value
		"crit_rate":
			bonuses["crit_rate"] = skill_value
		"crit_damage":
			bonuses["crit_damage"] = skill_value
		"resistance":
			bonuses["resistance"] = skill_value
		"accuracy":
			bonuses["accuracy"] = skill_value

	return bonuses

## Filter out null entries from team
static func _get_valid_team(team: Array) -> Array:
	var valid = []
	for god in team:
		if god != null:
			valid.append(god)
	return valid

## Check for element-based bonuses
static func _check_element_bonuses(team: Array) -> Array:
	var bonuses = []

	if not _bonus_data.has("element_bonuses"):
		return bonuses

	var element_data = _bonus_data.element_bonuses
	var element_counts = {}

	# Count elements
	for god in team:
		var element = god.element
		if not element_counts.has(element):
			element_counts[element] = 0
		element_counts[element] += 1

	# Check full match (all same element)
	if element_data.has("full_match"):
		var full_match = element_data.full_match
		for element in element_counts:
			if element_counts[element] == team.size() and team.size() >= 2:
				bonuses.append({
					"id": "element_full_match",
					"name": "Elemental Unity",
					"desc": _format_bonus_desc(full_match.bonuses),
					"element": God.element_to_string(element),
					"bonus": _get_primary_bonus(full_match.bonuses),
					"bonuses": full_match.bonuses
				})
				break

	# Check majority match (3+)
	if element_data.has("majority_match"):
		var majority = element_data.majority_match
		var required = majority.required_count if majority.has("required_count") else 3
		for element in element_counts:
			if element_counts[element] >= required and element_counts[element] < team.size():
				bonuses.append({
					"id": "element_majority",
					"name": "Elemental Mastery",
					"desc": _format_bonus_desc(majority.bonuses),
					"element": God.element_to_string(element),
					"bonus": _get_primary_bonus(majority.bonuses),
					"bonuses": majority.bonuses
				})
				break

	# Check duo match (2)
	if bonuses.is_empty():
		for element in element_counts:
			if element_counts[element] >= 2:
				bonuses.append({
					"id": "element_duo",
					"name": "Elemental Harmony",
					"desc": "+10% Elemental DMG",
					"element": God.element_to_string(element),
					"bonus": 0.10
				})
				break

	return bonuses

## Check for pantheon-based bonuses
static func _check_pantheon_bonuses(team: Array) -> Array:
	var bonuses = []

	if not _bonus_data.has("pantheon_bonuses"):
		return bonuses

	var pantheon_data = _bonus_data.pantheon_bonuses
	var pantheon_counts = {}

	# Count pantheons (using god's pantheon property if available)
	for god in team:
		var pantheon = god.pantheon if "pantheon" in god else "unknown"
		if pantheon == "" or pantheon == null:
			pantheon = "unknown"
		if not pantheon_counts.has(pantheon):
			pantheon_counts[pantheon] = 0
		pantheon_counts[pantheon] += 1

	# Skip if all unknown
	if pantheon_counts.size() == 1 and pantheon_counts.has("unknown"):
		return bonuses

	# Check full match
	if pantheon_data.has("full_match"):
		var full_match = pantheon_data.full_match
		for pantheon in pantheon_counts:
			if pantheon != "unknown" and pantheon_counts[pantheon] == team.size() and team.size() >= 2:
				bonuses.append({
					"id": "pantheon_full",
					"name": "Divine Pantheon",
					"desc": _format_bonus_desc(full_match.bonuses),
					"pantheon": pantheon,
					"bonus": _get_primary_bonus(full_match.bonuses),
					"bonuses": full_match.bonuses
				})
				return bonuses  # Don't check for lower tiers

	# Check majority (3+)
	if pantheon_data.has("majority_match"):
		var majority = pantheon_data.majority_match
		var required = majority.required_count if majority.has("required_count") else 3
		for pantheon in pantheon_counts:
			if pantheon != "unknown" and pantheon_counts[pantheon] >= required:
				bonuses.append({
					"id": "pantheon_majority",
					"name": "Pantheon Synergy",
					"desc": _format_bonus_desc(majority.bonuses),
					"pantheon": pantheon,
					"bonus": _get_primary_bonus(majority.bonuses),
					"bonuses": majority.bonuses
				})
				return bonuses

	# Check duo (2)
	if pantheon_data.has("duo_match"):
		var duo = pantheon_data.duo_match
		for pantheon in pantheon_counts:
			if pantheon != "unknown" and pantheon_counts[pantheon] >= 2:
				bonuses.append({
					"id": "pantheon_duo",
					"name": "Kindred Spirits",
					"desc": _format_bonus_desc(duo.bonuses),
					"pantheon": pantheon,
					"bonus": _get_primary_bonus(duo.bonuses),
					"bonuses": duo.bonuses
				})
				break

	return bonuses

## Check for tier-based bonuses
static func _check_tier_bonuses(team: Array) -> Array:
	var bonuses = []

	if not _bonus_data.has("tier_bonuses"):
		return bonuses

	if team.size() < 2:
		return bonuses

	var tier_data = _bonus_data.tier_bonuses
	var tier_counts = {}

	# Count tiers
	for god in team:
		var tier = god.tier
		if not tier_counts.has(tier):
			tier_counts[tier] = 0
		tier_counts[tier] += 1

	# Check all legendary
	if tier_data.has("all_legendary"):
		var all_leg = tier_data.all_legendary
		var all_are_legendary = true
		for god in team:
			if god.tier < God.TierType.LEGENDARY:
				all_are_legendary = false
				break

		if all_are_legendary and team.size() >= 2:
			bonuses.append({
				"id": "all_legendary",
				"name": "Divine Assembly",
				"desc": _format_bonus_desc(all_leg.bonuses),
				"bonus": _get_primary_bonus(all_leg.bonuses),
				"bonuses": all_leg.bonuses
			})

	# Check mixed tiers
	if tier_data.has("mixed_tiers"):
		var mixed = tier_data.mixed_tiers
		var min_unique = mixed.min_unique_tiers if mixed.has("min_unique_tiers") else 3
		if tier_counts.size() >= min_unique:
			bonuses.append({
				"id": "mixed_tiers",
				"name": "Diverse Ranks",
				"desc": _format_bonus_desc(mixed.bonuses),
				"bonus": _get_primary_bonus(mixed.bonuses),
				"bonuses": mixed.bonuses
			})

	return bonuses

## Check for special god synergies
static func _check_special_synergies(team: Array) -> Array:
	var bonuses = []

	if not _bonus_data.has("special_synergies"):
		return bonuses

	var special_data = _bonus_data.special_synergies

	# Build team info once
	var god_ids: Array = []
	var god_pantheons: Array = []
	var god_elements: Array = []
	var god_tiers: Array = []

	for god in team:
		# Use template_id for synergy matching (id is the unique instance ID)
		# Handle both God objects and Dictionary (from PvP serialization)
		var god_template: String
		var pantheon: String
		var element: Variant
		var tier: int

		if god is Dictionary:
			god_template = god.get("template_id", god.get("id", ""))
			pantheon = god.get("pantheon", "unknown")
			element = god.get("element", 0)
			tier = god.get("tier", 0)
		else:
			god_template = god.template_id if god.template_id else god.id
			pantheon = god.pantheon if "pantheon" in god else "unknown"
			element = god.element
			tier = god.tier

		god_ids.append(god_template.to_lower())
		god_pantheons.append(pantheon.to_lower() if pantheon else "unknown")
		god_elements.append(element)
		god_tiers.append(tier)

	var unique_pantheons: int = _count_unique(god_pantheons)
	var unique_elements: int = _count_unique(god_elements)

	# Check each special synergy
	for synergy_id in special_data:
		if synergy_id.begins_with("_"):
			continue

		var synergy = special_data[synergy_id]

		if _check_synergy_match(synergy, god_ids, god_pantheons, god_elements, god_tiers, unique_pantheons, unique_elements, team.size()):
			var synergy_name: String = _extract_synergy_name(synergy, synergy_id)
			bonuses.append({
				"id": synergy_id,
				"name": synergy_name,
				"desc": _format_bonus_desc(synergy.bonuses),
				"bonus": _get_primary_bonus(synergy.bonuses),
				"bonuses": synergy.bonuses
			})

	return bonuses

## Check if a synergy matches the current team
static func _check_synergy_match(synergy: Dictionary, god_ids: Array, god_pantheons: Array, god_elements: Array, god_tiers: Array, unique_pantheons: int, unique_elements: int, team_size: int) -> bool:
	# Check required_gods (all must be present)
	if synergy.has("required_gods"):
		for req_god in synergy.required_gods:
			if req_god not in god_ids:
				return false

	# Check required_gods_any (at least N from the list)
	if synergy.has("required_gods_any"):
		var required_count: int = synergy.get("required_count", 2)
		var match_count: int = 0
		for req_god in synergy.required_gods_any:
			if req_god in god_ids:
				match_count += 1
		if match_count < required_count:
			return false

	# Check required_pantheon (all/N from a specific pantheon)
	if synergy.has("required_pantheon"):
		var req_pantheon: String = synergy.required_pantheon.to_lower()
		var required_count: int = _parse_required_count(synergy.get("required_count", team_size), team_size)
		var match_count: int = 0
		for pantheon in god_pantheons:
			if pantheon == req_pantheon:
				match_count += 1
		if match_count < required_count:
			return false

	# Check unique_pantheons (team has N different pantheons)
	if synergy.has("unique_pantheons"):
		if unique_pantheons < int(synergy.unique_pantheons):
			return false

	# Check unique_elements (team has N different elements)
	if synergy.has("unique_elements"):
		if unique_elements < int(synergy.unique_elements):
			return false

	# Check max_tier (all/N gods at or below this tier)
	if synergy.has("max_tier"):
		var max_tier: int = int(synergy.max_tier)
		var required_count: int = _parse_required_count(synergy.get("required_count", team_size), team_size)
		var match_count: int = 0
		for tier in god_tiers:
			if tier <= max_tier:
				match_count += 1
		if match_count < required_count:
			return false

	# Check required_tier (all/N gods at exactly this tier)
	if synergy.has("required_tier"):
		var req_tier: int = int(synergy.required_tier)
		var required_count: int = _parse_required_count(synergy.get("required_count", team_size), team_size)
		var match_count: int = 0
		for tier in god_tiers:
			if tier == req_tier:
				match_count += 1
		if match_count < required_count:
			return false

	# If we reach here and synergy had no requirements, it shouldn't match
	# (needs at least one condition)
	var has_condition: bool = (
		synergy.has("required_gods") or
		synergy.has("required_gods_any") or
		synergy.has("required_pantheon") or
		synergy.has("unique_pantheons") or
		synergy.has("unique_elements") or
		synergy.has("max_tier") or
		synergy.has("required_tier")
	)

	return has_condition

## Count unique values in an array
static func _count_unique(arr: Array) -> int:
	var unique: Dictionary = {}
	for item in arr:
		unique[item] = true
	return unique.size()

## Parse required_count which can be "all" or an int
static func _parse_required_count(value, team_size: int) -> int:
	if value is String and value == "all":
		return team_size
	return int(value)

## Extract a nice display name from synergy
static func _extract_synergy_name(synergy: Dictionary, synergy_id: String) -> String:
	if synergy.has("description"):
		var desc: String = synergy.description
		# Try to get the name before the dash or use first few words
		var dash_pos: int = desc.find(" - ")
		if dash_pos > 0:
			return desc.substr(0, dash_pos)
		# Otherwise use synergy_id formatted nicely
	return synergy_id.replace("_", " ").capitalize()

## Check for territory-specific synergies
static func _check_territory_synergies(team: Array, node_type: String) -> Array:
	var bonuses = []

	if not _bonus_data.has("territory_synergies"):
		return bonuses

	var territory_data = _bonus_data.territory_synergies

	for synergy_id in territory_data:
		if synergy_id.begins_with("_"):
			continue

		var synergy = territory_data[synergy_id]

		# Check if this synergy applies to this node type
		if synergy.has("node_types"):
			if node_type not in synergy.node_types:
				continue

		# Check element requirements
		if synergy.has("required_elements"):
			var required_count = synergy.required_count if synergy.has("required_count") else 1
			var count = 0
			for god in team:
				var element_str = God.element_to_string(god.element).to_lower()
				for req_element in synergy.required_elements:
					if element_str == req_element.to_lower():
						count += 1
						break

			if count >= required_count:
				bonuses.append({
					"id": synergy_id,
					"name": _format_synergy_name(synergy_id),
					"desc": _format_bonus_desc(synergy.bonuses),
					"bonus": _get_primary_bonus(synergy.bonuses),
					"bonuses": synergy.bonuses
				})

	return bonuses

## Format bonus description from bonuses dict
static func _format_bonus_desc(bonuses: Dictionary) -> String:
	var parts = []
	for key in bonuses:
		var value = bonuses[key]
		var formatted_key = key.replace("_", " ").capitalize()
		parts.append("+%d%% %s" % [int(value * 100), formatted_key])
	return ", ".join(parts) if not parts.is_empty() else "Bonus"

## Get the primary (first/highest) bonus value
static func _get_primary_bonus(bonuses: Dictionary) -> float:
	var highest = 0.0
	for key in bonuses:
		if bonuses[key] > highest:
			highest = bonuses[key]
	return highest

## Format synergy name from ID
static func _format_synergy_name(synergy_id: String) -> String:
	return synergy_id.replace("_", " ").capitalize()

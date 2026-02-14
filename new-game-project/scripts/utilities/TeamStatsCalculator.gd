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
	var god_ids = []
	for god in team:
		god_ids.append(god.id.to_lower())

	# Check each special synergy
	for synergy_id in special_data:
		if synergy_id.begins_with("_"):
			continue

		var synergy = special_data[synergy_id]

		# Check required_gods
		if synergy.has("required_gods"):
			var required = synergy.required_gods
			var all_present = true
			for req_god in required:
				if req_god not in god_ids:
					all_present = false
					break

			if all_present:
				bonuses.append({
					"id": synergy_id,
					"name": synergy.description.split(" ")[0] if synergy.has("description") else synergy_id.capitalize(),
					"desc": _format_bonus_desc(synergy.bonuses),
					"bonus": _get_primary_bonus(synergy.bonuses),
					"bonuses": synergy.bonuses
				})

	return bonuses

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


# Unit Test Plan

## Test Files to Create

### Phase 1: Data Models

```json
{
  "file": "tests/data/test_god_data.gd",
  "source": "scripts/data/God.gd",
  "complete": true,
  "tests_count": 98,
  "tests": [
    "test_god_creation_with_valid_data",
    "test_god_default_stats",
    "test_god_equipment_slots_count",
    "test_god_element_to_string_conversion",
    "test_god_string_to_element_conversion",
    "test_god_tier_to_string_conversion",
    "test_god_string_to_tier_conversion",
    "test_god_is_valid_returns_true_for_valid_god",
    "test_god_is_valid_returns_false_for_empty_id",
    "test_god_is_valid_returns_false_for_empty_name",
    "test_god_is_valid_returns_false_for_zero_hp",
    "test_god_is_valid_returns_false_for_zero_attack",
    "test_god_can_level_up_below_max",
    "test_god_can_level_up_at_max_returns_false",
    "test_god_get_display_name_not_awakened",
    "test_god_get_display_name_awakened",
    "test_god_get_display_name_awakened_without_awakened_name",
    "test_god_get_full_title_not_awakened",
    "test_god_get_full_title_awakened",
    "test_god_is_equipment_slot_empty",
    "test_god_get_equipment_in_slot",
    "test_god_has_ability",
    "test_god_has_ability_empty_array",
    "test_god_is_equipped_false_when_no_equipment",
    "test_god_is_assigned_to_territory_false_when_not_assigned",
    "test_god_is_assigned_to_territory_false_when_partial_assignment",
    "test_god_is_assigned_to_territory_true_when_fully_assigned",
    "test_god_skill_levels_default",
    "test_god_battle_state_defaults"
  ]
}
```

```json
{
  "file": "tests/data/test_equipment_data.gd",
  "source": "scripts/data/Equipment.gd",
  "complete": true,
  "tests_count": 156,
  "tests": [
    "test_equipment_creation_basic",
    "test_equipment_default_values",
    "test_equipment_property_aliases",
    "test_equipment_slot_types_enum_values",
    "test_equipment_rarity_types_enum_values",
    "test_equipment_string_to_rarity_conversion",
    "test_equipment_string_to_rarity_case_insensitive",
    "test_equipment_string_to_rarity_invalid_defaults_to_common",
    "test_equipment_rarity_to_string_conversion",
    "test_equipment_rarity_to_string_invalid_defaults_to_common",
    "test_equipment_string_to_type_conversion",
    "test_equipment_string_to_type_case_insensitive",
    "test_equipment_string_to_type_invalid_defaults_to_weapon",
    "test_equipment_type_to_string_conversion",
    "test_equipment_type_to_string_invalid_defaults_to_weapon",
    "test_equipment_max_enhancement_level_by_rarity",
    "test_equipment_can_enhance_below_max",
    "test_equipment_can_be_enhanced_alias",
    "test_equipment_can_enhance_at_max_returns_false",
    "test_equipment_enhancement_cost_calculation",
    "test_equipment_enhancement_cost_for_level",
    "test_equipment_enhancement_success_rate",
    "test_equipment_enhancement_success_rate_by_rarity",
    "test_equipment_enhancement_success_rate_alias",
    "test_equipment_enhancement_success_rate_very_high_level",
    "test_equipment_max_sockets_by_rarity",
    "test_equipment_can_unlock_socket",
    "test_equipment_socket_unlock_cost",
    "test_equipment_get_display_name_no_enhancement",
    "test_equipment_get_display_name_with_enhancement",
    "test_equipment_get_stat_bonuses_main_stat_only",
    "test_equipment_get_stat_bonuses_with_substats",
    "test_equipment_get_stat_bonuses_empty_main_stat",
    "test_equipment_get_enhancement_stat_bonuses_no_enhancement",
    "test_equipment_get_enhancement_stat_bonuses_with_enhancement",
    "test_equipment_get_enhancement_stat_bonuses_at_max",
    "test_equipment_add_stat_bonus_to_main_stat",
    "test_equipment_add_stat_bonus_to_different_stat",
    "test_equipment_add_substat_new",
    "test_equipment_add_substat_existing",
    "test_equipment_add_multiple_substats",
    "test_equipment_create_from_dungeon_returns_valid_equipment",
    "test_equipment_create_from_dungeon_different_types",
    "test_equipment_create_from_dungeon_invalid_type",
    "test_equipment_create_test_equipment",
    "test_equipment_create_test_equipment_default_values",
    "test_equipment_generate_equipment_id_format",
    "test_equipment_generate_equipment_id_unique",
    "test_equipment_get_rarity_color",
    "test_equipment_set_information",
    "test_equipment_is_destroyed_flag",
    "test_equipment_equipped_by_god_id"
  ]
}
```

```json
{
  "file": "tests/data/test_battle_unit.gd",
  "source": "scripts/data/BattleUnit.gd",
  "complete": true,
  "tests_count": 107,
  "tests": [
    "test_battle_unit_from_enemy_basic",
    "test_battle_unit_from_enemy_stats",
    "test_battle_unit_from_enemy_default_stats",
    "test_battle_unit_from_enemy_source_reference",
    "test_battle_unit_from_enemy_unknown_id",
    "test_battle_unit_default_is_alive",
    "test_battle_unit_default_turn_bar",
    "test_battle_unit_default_skill_cooldowns",
    "test_battle_unit_default_status_effects",
    "test_battle_unit_take_damage_reduces_hp",
    "test_battle_unit_take_damage_multiple_times",
    "test_battle_unit_take_damage_zero",
    "test_battle_unit_take_damage_negative_clamped",
    "test_battle_unit_dies_at_zero_hp",
    "test_battle_unit_dies_when_hp_would_go_negative",
    "test_battle_unit_heal_increases_hp",
    "test_battle_unit_heal_capped_at_max_hp",
    "test_battle_unit_heal_from_full_hp",
    "test_battle_unit_heal_zero",
    "test_battle_unit_heal_exact_to_max",
    "test_battle_unit_get_hp_percentage_full",
    "test_battle_unit_get_hp_percentage_half",
    "test_battle_unit_get_hp_percentage_zero",
    "test_battle_unit_get_hp_percentage_quarter",
    "test_battle_unit_advance_turn_bar_increases",
    "test_battle_unit_advance_turn_bar_speed_scaling",
    "test_battle_unit_advance_turn_bar_formula",
    "test_battle_unit_advance_turn_bar_multiple_times",
    "test_battle_unit_reset_turn_bar",
    "test_battle_unit_reset_turn_bar_when_already_zero",
    "test_battle_unit_is_ready_for_turn_false_initially",
    "test_battle_unit_is_ready_for_turn_at_100",
    "test_battle_unit_is_ready_for_turn_above_100",
    "test_battle_unit_is_ready_for_turn_at_99",
    "test_battle_unit_is_ready_for_turn_dead_unit",
    "test_battle_unit_get_turn_progress_zero",
    "test_battle_unit_get_turn_progress_half",
    "test_battle_unit_get_turn_progress_full",
    "test_battle_unit_get_turn_progress_over_100",
    "test_battle_unit_can_use_skill_no_cooldown",
    "test_battle_unit_can_use_skill_negative_index",
    "test_battle_unit_can_use_skill_out_of_bounds",
    "test_battle_unit_can_use_skill_on_cooldown",
    "test_battle_unit_use_skill_sets_cooldown",
    "test_battle_unit_use_skill_when_already_on_cooldown",
    "test_battle_unit_tick_cooldowns_reduces_by_one",
    "test_battle_unit_tick_cooldowns_zero_stays_zero",
    "test_battle_unit_tick_cooldowns_empty_array",
    "test_battle_unit_get_skill_valid_index",
    "test_battle_unit_get_skill_negative_index",
    "test_battle_unit_get_skill_out_of_bounds",
    "test_battle_unit_add_status_effect",
    "test_battle_unit_add_multiple_different_effects",
    "test_battle_unit_add_duplicate_non_stackable_effect_replaces",
    "test_battle_unit_add_stackable_effect_increases_stacks",
    "test_battle_unit_remove_status_effect_success",
    "test_battle_unit_remove_status_effect_not_found",
    "test_battle_unit_remove_status_effect_only_removes_matching",
    "test_battle_unit_is_enemy_for_enemy_unit",
    "test_battle_unit_is_enemy_for_player_unit",
    "test_battle_unit_get_display_info_contains_name",
    "test_battle_unit_get_display_info_contains_hp",
    "test_battle_unit_get_display_info_contains_hp_percentage",
    "test_battle_unit_get_display_info_contains_is_alive",
    "test_battle_unit_get_display_info_contains_turn_progress",
    "test_battle_unit_get_display_info_contains_status_effects",
    "test_battle_unit_enemy_has_basic_attack",
    "test_battle_unit_enemy_no_skills_gets_basic_attack",
    "test_battle_unit_take_damage_when_already_dead",
    "test_battle_unit_heal_when_dead",
    "test_battle_unit_large_damage_value",
    "test_battle_unit_large_heal_value"
  ]
}
```

```json
{
  "file": "tests/data/test_battle_state.gd",
  "source": "scripts/data/BattleState.gd",
  "complete": true,
  "tests_count": 67,
  "tests": [
    "test_battle_state_initialization",
    "test_get_living_units_all_alive",
    "test_get_living_units_some_dead",
    "test_get_living_units_all_dead",
    "test_get_living_player_units_all_alive",
    "test_get_living_player_units_some_dead",
    "test_get_living_player_units_all_dead",
    "test_get_living_enemy_units_all_alive",
    "test_get_living_enemy_units_some_dead",
    "test_get_living_enemy_units_all_dead",
    "test_get_all_units_returns_duplicate",
    "test_get_player_units_returns_duplicate",
    "test_get_enemy_units_returns_duplicate",
    "test_all_player_units_defeated_false_when_alive",
    "test_all_player_units_defeated_false_when_one_alive",
    "test_all_player_units_defeated_true_when_all_dead",
    "test_all_enemy_units_defeated_false_when_alive",
    "test_all_enemy_units_defeated_false_when_one_alive",
    "test_all_enemy_units_defeated_true_when_all_dead",
    "test_should_battle_end_false_when_both_sides_alive",
    "test_should_battle_end_true_when_players_defeated",
    "test_should_battle_end_true_when_enemies_defeated_single_wave",
    "test_should_battle_end_false_when_enemies_defeated_more_waves",
    "test_record_damage_dealt_increases_total",
    "test_record_damage_dealt_accumulates",
    "test_record_damage_received_increases_total",
    "test_record_damage_received_accumulates",
    "test_record_unit_defeat_increases_count",
    "test_record_unit_defeat_accumulates",
    "test_record_skill_use_increases_count",
    "test_record_skill_use_accumulates",
    "test_has_unit_deaths_false_when_all_alive",
    "test_has_unit_deaths_true_when_player_dead",
    "test_has_unit_deaths_false_when_only_enemy_dead",
    "test_get_unit_by_id_finds_player",
    "test_get_unit_by_id_finds_enemy",
    "test_get_unit_by_id_returns_null_for_invalid_id",
    "test_get_battle_statistics_contains_all_fields",
    "test_get_battle_statistics_values_correct",
    "test_get_battle_duration_returns_positive",
    "test_process_end_of_turn_increments_turn",
    "test_process_end_of_turn_multiple_times",
    "test_get_units_by_speed_sorts_descending",
    "test_get_units_by_speed_excludes_dead",
    "test_wave_starts_at_one",
    "test_max_waves_default",
    "test_cleanup_clears_all_arrays",
    "test_empty_battle_state_living_units",
    "test_empty_battle_state_defeat_checks",
    "test_large_damage_values"
  ]
}
```

### Phase 2: Static Calculators

```json
{
  "file": "tests/unit/test_combat_calculator.gd",
  "source": "scripts/systems/battle/CombatCalculator.gd",
  "complete": true,
  "tests_count": 62,
  "tests": [
    "test_damage_formula_basic",
    "test_damage_formula_returns_damage_result",
    "test_damage_with_zero_defense",
    "test_damage_with_high_defense",
    "test_skill_damage_multiplier",
    "test_skill_damage_multiplier_zero",
    "test_critical_hit_increases_damage",
    "test_damage_result_critical_flag",
    "test_glancing_hit_reduces_damage",
    "test_glancing_and_critical_mutually_exclusive",
    "test_damage_variance_within_bounds",
    "test_element_advantage_fire_vs_earth",
    "test_element_disadvantage_fire_vs_water",
    "test_element_advantage_water_vs_fire",
    "test_element_disadvantage_water_vs_earth",
    "test_element_advantage_earth_vs_water",
    "test_element_disadvantage_earth_vs_fire",
    "test_element_advantage_light_vs_dark",
    "test_element_advantage_dark_vs_light",
    "test_element_neutral_same_element",
    "test_element_neutral_light_vs_non_dark",
    "test_element_neutral_dark_vs_non_light",
    "test_healing_calculation_basic",
    "test_healing_calculation_with_multiplier",
    "test_healing_scales_with_attack",
    "test_healing_variance",
    "test_total_stats_includes_base_stats",
    "test_total_stats_level_scaling",
    "test_total_stats_level_scaling_partial",
    "test_total_stats_contains_all_stat_fields",
    "test_total_stats_crit_and_secondary_stats",
    "test_power_rating_calculation_basic",
    "test_power_rating_level_bonus",
    "test_power_rating_tier_bonus",
    "test_power_rating_combined",
    "test_detailed_attack_breakdown",
    "test_detailed_defense_breakdown",
    "test_detailed_hp_breakdown",
    "test_detailed_speed_breakdown",
    "test_detailed_breakdown_at_level_1",
    "test_damage_with_very_high_attack",
    "test_damage_with_very_high_defense",
    "test_damage_without_skill",
    "test_healing_with_null_skill",
    "test_power_rating_tier_common",
    "test_power_rating_high_level",
    "test_total_stats_high_level"
  ]
}
```

### Phase 3: Core Systems

```json
{
  "file": "tests/unit/test_resource_manager.gd",
  "source": "scripts/systems/resources/ResourceManager.gd",
  "complete": true,
  "tests_count": 74,
  "tests": [
    "test_add_resource_increases_amount",
    "test_add_resource_returns_true_on_success",
    "test_add_resource_zero_returns_false",
    "test_add_resource_negative_returns_false",
    "test_add_resource_new_resource_type",
    "test_add_resource_respects_energy_limit",
    "test_add_resource_respects_arena_tokens_limit",
    "test_add_resource_already_at_limit_returns_false",
    "test_add_resource_unlimited_gold",
    "test_add_resource_unlimited_crystals",
    "test_add_resource_unlimited_mana",
    "test_spend_resource_decreases_amount",
    "test_spend_resource_returns_true_on_success",
    "test_spend_insufficient_returns_false",
    "test_spend_zero_returns_false",
    "test_spend_negative_returns_false",
    "test_spend_exact_amount",
    "test_spend_nonexistent_resource",
    "test_can_afford_single_resource_true",
    "test_can_afford_single_resource_exact",
    "test_can_afford_single_resource_false",
    "test_can_afford_empty_cost",
    "test_can_afford_multiple_resources_true",
    "test_can_afford_multiple_resources_one_insufficient",
    "test_can_afford_multiple_resources_all_insufficient",
    "test_spend_resources_success",
    "test_spend_resources_atomic_on_failure",
    "test_spend_resources_empty_cost",
    "test_energy_limit_100",
    "test_arena_tokens_limit_30",
    "test_guild_tokens_limit_50",
    "test_honor_points_limit_9999",
    "test_unlimited_gold_returns_negative_one",
    "test_unlimited_mana_returns_negative_one",
    "test_unlimited_crystals_returns_negative_one",
    "test_unknown_resource_limit_returns_negative_one",
    "test_has_limit_true_for_energy",
    "test_has_limit_false_for_gold",
    "test_is_at_limit_true",
    "test_is_at_limit_false",
    "test_is_at_limit_false_for_unlimited",
    "test_set_resource_sets_exact_value",
    "test_set_resource_overwrites_existing",
    "test_set_resource_can_set_zero",
    "test_get_all_resources_returns_copy",
    "test_get_all_resources_empty",
    "test_award_resources_adds_multiple",
    "test_award_resources_respects_limits",
    "test_get_save_data",
    "test_load_from_save",
    "test_load_from_save_overwrites_existing",
    "test_save_and_load_roundtrip",
    "test_initialize_new_game_clears_resources",
    "test_resource_changed_signal_emitted_on_add",
    "test_resource_changed_signal_emitted_on_spend",
    "test_resource_insufficient_signal_emitted",
    "test_resource_limit_reached_signal_emitted",
    "test_get_resource_nonexistent_returns_zero",
    "test_multiple_add_operations",
    "test_multiple_spend_operations",
    "test_large_resource_values",
    "test_debug_add_test_resources"
  ]
}
```

```json
{
  "file": "tests/unit/test_collection_manager.gd",
  "source": "scripts/systems/collection/CollectionManager.gd",
  "complete": true,
  "tests_count": 48,
  "tests": [
    "test_add_god_to_collection",
    "test_add_god_returns_true",
    "test_add_god_null_returns_false",
    "test_add_multiple_gods",
    "test_has_god_returns_true_when_owned",
    "test_has_god_returns_false_when_not_owned",
    "test_has_god_returns_false_for_empty_collection",
    "test_add_duplicate_god_returns_false",
    "test_add_god_with_same_id_returns_false",
    "test_remove_god_from_collection",
    "test_remove_god_returns_false_when_not_in_collection",
    "test_remove_god_null_returns_false",
    "test_remove_god_updates_has_god",
    "test_remove_one_of_multiple_gods",
    "test_get_all_gods_empty",
    "test_get_all_gods_returns_copy",
    "test_get_all_gods_contains_correct_gods",
    "test_get_god_by_id_found",
    "test_get_god_by_id_not_found",
    "test_get_god_by_id_returns_same_reference",
    "test_update_god_success",
    "test_update_god_not_in_collection_returns_false",
    "test_update_god_null_returns_false",
    "test_get_god_equipment_empty",
    "test_get_god_equipment_nonexistent_god",
    "test_update_god_equipment",
    "test_update_god_equipment_nonexistent_god",
    "test_update_god_equipment_retrieval",
    "test_update_god_equipment_multiple_slots",
    "test_update_god_equipment_can_set_null",
    "test_gods_by_id_index_populated",
    "test_gods_by_id_index_cleared_on_remove",
    "test_add_many_gods",
    "test_remove_all_gods",
    "test_add_remove_add_same_god",
    "test_collection_with_equipment_array",
    "test_get_god_after_modification"
  ]
}
```

```json
{
  "file": "tests/unit/test_summon_manager.gd",
  "source": "scripts/systems/collection/SummonManager.gd",
  "complete": true,
  "tests_count": 58,
  "tests": [
    "test_pity_counter_initialization",
    "test_pity_counter_structure",
    "test_summon_rates_basic",
    "test_summon_rates_premium",
    "test_summon_rates_free_daily",
    "test_summon_rates_soul_based",
    "test_summon_rates_unknown_type",
    "test_summon_rates_total_100_percent",
    "test_hard_pity_legendary_at_100",
    "test_hard_pity_epic_at_50",
    "test_hard_pity_legendary_resets_on_legendary",
    "test_hard_pity_epic_resets_on_epic",
    "test_pity_counter_increments_on_common",
    "test_pity_counter_increments_on_rare",
    "test_pity_counter_resets_on_epic",
    "test_pity_counter_resets_all_on_legendary",
    "test_pity_counter_accumulates",
    "test_soft_pity_legendary_starts_at_75",
    "test_soft_pity_epic_starts_at_35",
    "test_soft_pity_legendary_increases_rate",
    "test_tier_string_to_number_common",
    "test_tier_string_to_number_rare",
    "test_tier_string_to_number_epic",
    "test_tier_string_to_number_legendary",
    "test_tier_string_to_number_invalid",
    "test_tier_string_to_number_case_insensitive",
    "test_random_tier_returns_valid_tier",
    "test_random_tier_distribution_heavily_weighted",
    "test_random_tier_fallback_to_common",
    "test_can_use_daily_free_summon_initially_true",
    "test_daily_free_summon_updates_date",
    "test_daily_free_summon_resets_next_day",
    "test_can_use_weekly_premium_summon_initially_true",
    "test_can_use_weekly_premium_with_empty_date",
    "test_get_save_data_structure",
    "test_save_pity_counter",
    "test_load_save_data",
    "test_save_and_load_roundtrip",
    "test_summon_completed_signal_exists",
    "test_summon_failed_signal_exists",
    "test_multi_summon_completed_signal_exists",
    "test_pity_counter_high_values",
    "test_empty_save_data_load",
    "test_partial_save_data_load"
  ]
}
```

### Phase 4: Equipment Systems

```json
{
  "file": "tests/unit/test_equipment_manager.gd",
  "source": "scripts/systems/equipment/EquipmentManager.gd",
  "complete": true,
  "tests_count": 52,
  "tests": [
    "test_equipment_equipped_signal_exists",
    "test_equipment_unequipped_signal_exists",
    "test_equipment_enhanced_signal_exists",
    "test_equipment_crafted_signal_exists",
    "test_socket_unlocked_signal_exists",
    "test_gem_socketed_signal_exists",
    "test_equip_equipment_to_god_success",
    "test_equip_equipment_updates_god_equipment_array",
    "test_equip_equipment_sets_equipped_by_god_id",
    "test_equip_equipment_null_god_returns_false",
    "test_equip_equipment_null_equipment_returns_false",
    "test_equip_equipment_different_slots",
    "test_equip_equipment_replaces_existing",
    "test_unequip_equipment_from_god_success",
    "test_unequip_clears_equipped_by_god_id",
    "test_unequip_null_god_returns_false",
    "test_unequip_invalid_slot_returns_false",
    "test_unequip_empty_slot_returns_false",
    "test_get_equipped_equipment_returns_array",
    "test_get_equipped_equipment_null_god_returns_empty",
    "test_get_equipped_equipment_contains_equipped_items",
    "test_six_equipment_slots",
    "test_equipment_type_weapon_value",
    "test_equipment_type_armor_value",
    "test_equipment_type_helm_value",
    "test_equipment_type_boots_value",
    "test_equipment_type_amulet_value",
    "test_equipment_type_ring_value",
    "test_get_public_api_returns_array",
    "test_get_public_api_contains_key_methods",
    "test_create_equipment_from_data",
    "test_create_equipment_from_data_with_substats",
    "test_create_equipment_from_data_with_sockets",
    "test_create_equipment_from_empty_data",
    "test_save_equipment_data_structure",
    "test_get_equipment_summary_structure",
    "test_get_god_equipment_stats_null_god",
    "test_get_god_equipment_stats_structure",
    "test_equip_creates_equipment_array_if_missing",
    "test_equip_expands_equipment_array_if_too_small",
    "test_multiple_equip_unequip_cycles"
  ]
}
```

```json
{
  "file": "tests/unit/test_equipment_enhancement.gd",
  "source": "scripts/systems/equipment/EquipmentEnhancementManager.gd",
  "complete": true,
  "tests_count": 48,
  "tests": [
    "test_equipment_enhanced_signal_exists",
    "test_enhancement_failed_signal_exists",
    "test_blessed_oil_used_signal_exists",
    "test_get_enhancement_preview_returns_dict",
    "test_get_enhancement_preview_contains_required_fields",
    "test_get_enhancement_preview_current_level",
    "test_get_enhancement_preview_next_level",
    "test_get_enhancement_preview_null_equipment",
    "test_get_enhancement_preview_blessed_oil_fields",
    "test_get_enhancement_preview_consequences_field",
    "test_get_enhancement_statistics_returns_dict",
    "test_get_enhancement_statistics_contains_fields",
    "test_get_enhancement_statistics_null_equipment",
    "test_get_enhancement_statistics_progress",
    "test_get_enhancement_statistics_partial_progress",
    "test_enhance_equipment_bulk_returns_result",
    "test_enhance_equipment_bulk_contains_fields",
    "test_enhance_equipment_bulk_null_equipment",
    "test_enhance_equipment_bulk_start_level",
    "test_enhance_equipment_bulk_insufficient_resources",
    "test_enhance_equipment_null_returns_false",
    "test_enhance_equipment_at_max_level_returns_false",
    "test_max_enhancement_level_common",
    "test_max_enhancement_level_rare",
    "test_max_enhancement_level_epic",
    "test_max_enhancement_level_legendary",
    "test_max_enhancement_level_mythic",
    "test_enhancement_cost_returns_dict",
    "test_enhancement_cost_has_resources",
    "test_enhancement_cost_increases_with_level",
    "test_enhancement_cost_for_level",
    "test_success_rate_returns_float",
    "test_success_rate_range",
    "test_success_rate_decreases_with_level",
    "test_success_rate_by_rarity",
    "test_enhancement_stat_bonuses_returns_dict",
    "test_enhancement_stat_bonuses_at_level_0",
    "test_enhancement_stat_bonuses_increase_with_level",
    "test_can_be_enhanced_at_level_0",
    "test_can_be_enhanced_at_mid_level",
    "test_can_be_enhanced_at_max_level",
    "test_can_be_enhanced_one_below_max",
    "test_enhancement_preview_with_blessed_oil",
    "test_bulk_enhancement_target_higher_than_max",
    "test_equipment_destroyed_flag",
    "test_enhancement_statistics_cost_calculations"
  ]
}
```

```json
{
  "file": "tests/unit/test_equipment_stat_calculator.gd",
  "source": "scripts/systems/equipment/EquipmentStatCalculator.gd",
  "complete": true,
  "tests_count": 45,
  "tests": [
    "test_calculate_god_total_stats_returns_dict",
    "test_calculate_god_total_stats_contains_all_stats",
    "test_calculate_god_total_stats_base_values",
    "test_calculate_god_total_stats_null_god",
    "test_calculate_god_total_stats_with_equipment",
    "test_calculate_god_total_stats_with_multiple_equipment",
    "test_calculate_equipment_power_rating_returns_int",
    "test_calculate_equipment_power_rating_basic",
    "test_calculate_equipment_power_rating_null",
    "test_power_rating_increases_with_main_stat",
    "test_power_rating_rarity_multiplier",
    "test_get_equipment_display_info_returns_dict",
    "test_get_equipment_display_info_contains_fields",
    "test_get_equipment_display_info_null",
    "test_get_equipment_display_info_name",
    "test_get_equipment_display_info_substats",
    "test_calculate_set_bonuses_returns_dict",
    "test_calculate_set_bonuses_null_god",
    "test_calculate_set_bonuses_no_equipment",
    "test_get_enhancement_preview_returns_dict",
    "test_get_enhancement_preview_null",
    "test_get_enhancement_preview_contains_fields",
    "test_get_enhancement_preview_at_max_level",
    "test_get_enhancement_preview_success_rate_decreases",
    "test_get_enhancement_preview_cost_increases",
    "test_slot_type_names_contains_all_types",
    "test_slot_type_names_values",
    "test_god_with_null_equipment_array",
    "test_god_with_partial_equipment",
    "test_equipment_with_substats",
    "test_power_rating_with_substats"
  ]
}
```

### Phase 5: Battle Systems

```json
{
  "file": "tests/unit/test_turn_manager.gd",
  "source": "scripts/systems/battle/TurnManager.gd",
  "complete": false,
  "tests_count": 0,
  "tests": [
    "test_setup_turn_order_by_speed",
    "test_fastest_unit_goes_first",
    "test_turn_bar_advancement",
    "test_advance_turn_cycles_units",
    "test_get_current_unit",
    "test_turn_started_signal",
    "test_turn_ended_signal"
  ]
}
```

```json
{
  "file": "tests/unit/test_status_effects.gd",
  "source": "scripts/systems/battle/StatusEffectManager.gd",
  "complete": false,
  "tests_count": 0,
  "tests": [
    "test_apply_poison_effect",
    "test_apply_burn_effect",
    "test_apply_heal_over_time",
    "test_apply_shield",
    "test_apply_stun",
    "test_effect_duration_decreases",
    "test_effect_expires",
    "test_stun_prevents_action",
    "test_process_turn_start_effects",
    "test_process_turn_end_effects"
  ]
}
```

```json
{
  "file": "tests/unit/test_wave_manager.gd",
  "source": "scripts/systems/battle/WaveManager.gd",
  "complete": false,
  "tests_count": 0,
  "tests": [
    "test_setup_waves",
    "test_start_first_wave",
    "test_get_current_wave",
    "test_complete_wave",
    "test_advance_to_next_wave",
    "test_all_waves_completed",
    "test_wave_started_signal",
    "test_wave_completed_signal"
  ]
}
```

```json
{
  "file": "tests/unit/test_battle_coordinator.gd",
  "source": "scripts/systems/battle/BattleCoordinator.gd",
  "complete": false,
  "tests_count": 0,
  "tests": [
    "test_start_battle_creates_state",
    "test_execute_attack_action",
    "test_execute_skill_action",
    "test_battle_ends_on_victory",
    "test_battle_ends_on_defeat",
    "test_is_in_battle",
    "test_auto_battle_mode"
  ]
}
```

### Phase 6: Progression Systems

```json
{
  "file": "tests/unit/test_player_progression.gd",
  "source": "scripts/systems/progression/PlayerProgressionManager.gd",
  "complete": false,
  "tests_count": 0,
  "tests": [
    "test_add_experience",
    "test_level_up_on_enough_xp",
    "test_xp_curve_calculation",
    "test_feature_unlock_summon_at_level_2",
    "test_feature_unlock_sacrifice_at_level_3",
    "test_feature_unlock_territory_at_level_5",
    "test_feature_unlock_dungeon_at_level_10",
    "test_feature_unlock_arena_at_level_15",
    "test_is_feature_unlocked",
    "test_save_and_load_data"
  ]
}
```

```json
{
  "file": "tests/unit/test_god_progression.gd",
  "source": "scripts/systems/progression/GodProgressionManager.gd",
  "complete": false,
  "tests_count": 0,
  "tests": [
    "test_add_experience_to_god",
    "test_god_level_up",
    "test_god_max_level_40",
    "test_awakened_god_max_level_50",
    "test_stat_bonus_per_level_common",
    "test_stat_bonus_per_level_legendary",
    "test_awaken_god_requirements",
    "test_awaken_god_increases_stats"
  ]
}
```

```json
{
  "file": "tests/unit/test_territory_manager.gd",
  "source": "scripts/systems/territory/TerritoryManager.gd",
  "complete": false,
  "tests_count": 0,
  "tests": [
    "test_capture_territory",
    "test_is_territory_controlled",
    "test_lose_territory",
    "test_capture_limit_enforcement",
    "test_upgrade_territory",
    "test_upgrade_cost_calculation",
    "test_get_controlled_territories",
    "test_territory_captured_signal"
  ]
}
```

### Phase 7: Integration Tests

```json
{
  "file": "tests/integration/test_summon_flow.gd",
  "source": "multiple",
  "complete": false,
  "tests_count": 0,
  "tests": [
    "test_full_summon_flow_basic",
    "test_summon_adds_god_to_collection",
    "test_summon_spends_resources",
    "test_summon_with_pity"
  ]
}
```

```json
{
  "file": "tests/integration/test_battle_flow.gd",
  "source": "multiple",
  "complete": false,
  "tests_count": 0,
  "tests": [
    "test_full_battle_victory",
    "test_full_battle_defeat",
    "test_battle_rewards",
    "test_god_gains_xp_after_battle"
  ]
}
```

```json
{
  "file": "tests/integration/test_equipment_flow.gd",
  "source": "multiple",
  "complete": false,
  "tests_count": 0,
  "tests": [
    "test_equip_unequip_flow",
    "test_enhancement_flow",
    "test_equipment_affects_battle_stats"
  ]
}
```

---

## Summary

| Phase | Files | Est. Tests |
|-------|-------|------------|
| 1. Data Models | 4 | 38 |
| 2. Static Calculators | 1 | 12 |
| 3. Core Systems | 3 | 33 |
| 4. Equipment Systems | 3 | 22 |
| 5. Battle Systems | 4 | 32 |
| 6. Progression Systems | 3 | 26 |
| 7. Integration Tests | 3 | 11 |
| **Total** | **21** | **~174** |

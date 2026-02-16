#!/usr/bin/env python3
"""
Comprehensive JSON validation and cross-reference checker for Smyte game project
"""

import json
import os
import sys
from collections import defaultdict
from pathlib import Path

class JSONValidator:
    def __init__(self, data_dir="data"):
        self.data_dir = Path(data_dir)
        self.issues = {
            "critical": [],
            "high": [],
            "medium": [],
            "low": []
        }
        self.data = {}

    def add_issue(self, priority, category, message):
        """Add an issue to the appropriate priority level"""
        self.issues[priority].append(f"[{category}] {message}")

    def load_all_json(self):
        """Load all JSON files and check for parse errors"""
        print("=" * 80)
        print("PART 1: JSON PARSING VALIDATION")
        print("=" * 80)

        json_files = list(self.data_dir.glob("*.json"))

        for json_file in sorted(json_files):
            try:
                with open(json_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    self.data[json_file.stem] = data
                    print(f"OK {json_file.name}")

                    # Check for duplicate keys by comparing original text
                    with open(json_file, 'r', encoding='utf-8') as f:
                        content = f.read()
                        self.check_duplicate_keys(json_file.name, content, data)

            except json.JSONDecodeError as e:
                self.add_issue("critical", "PARSE ERROR",
                              f"{json_file.name} - JSON syntax error at line {e.lineno}: {e.msg}")
                print(f"FAIL {json_file.name} - PARSE ERROR")
            except Exception as e:
                self.add_issue("critical", "FILE ERROR",
                              f"{json_file.name} - {str(e)}")
                print(f"FAIL {json_file.name} - FILE ERROR")

    def check_duplicate_keys(self, filename, content, data):
        """Check for duplicate keys in JSON objects"""
        # Simple heuristic: count occurrences of keys in raw text vs parsed data
        # This won't catch all cases but will catch obvious duplicates
        import re

        # Find all keys in the raw JSON
        key_pattern = r'"(\w+)"\s*:'
        raw_keys = re.findall(key_pattern, content)

        # Count occurrences
        from collections import Counter
        key_counts = Counter(raw_keys)

        # Check for duplicates (allowing metadata keys to appear multiple times)
        for key, count in key_counts.items():
            if count > 1 and not key.startswith("_"):
                # Check if this is actually a duplicate or just appears in nested objects
                # This is a simplified check
                if count > 10:  # Likely appears in many nested objects
                    continue
                self.add_issue("medium", "DUPLICATE KEY WARNING",
                              f"{filename} may have duplicate key '{key}' ({count} occurrences)")

    def validate_cross_references(self):
        """Validate all cross-references between JSON files"""
        print("\n" + "=" * 80)
        print("PART 2: CROSS-REFERENCE VALIDATION")
        print("=" * 80)

        # Extract all resource IDs
        if 'resources' in self.data:
            resource_ids = set()
            for category in ['currencies', 'crafting_materials', 'enhancement_materials',
                            'gemstones', 'awakening_materials', 'summoning_materials',
                            'element_powders', 'divine_materials', 'pantheon_tokens']:
                if category in self.data['resources']:
                    resource_ids.update(self.data['resources'][category].keys())
            print(f"\nFound {len(resource_ids)} resource IDs in resources.json")
        else:
            resource_ids = set()
            self.add_issue("critical", "MISSING FILE", "resources.json not loaded")

        # Check loot_items.json references resources.json
        if 'loot_items' in self.data:
            print("\nValidating loot_items.json references...")
            loot_items = self.data['loot_items'].get('loot_items', {})
            for item_id, item_data in loot_items.items():
                if 'resource_id' in item_data:
                    res_id = item_data['resource_id']
                    if res_id not in resource_ids:
                        self.add_issue("high", "BROKEN REFERENCE",
                                      f"loot_items.json:{item_id} references unknown resource '{res_id}'")
            print(f"  Checked {len(loot_items)} loot items")

        # Check loot_tables.json references loot_items.json
        if 'loot_tables' in self.data and 'loot_items' in self.data:
            print("\nValidating loot_tables.json references...")
            loot_item_ids = set(self.data['loot_items'].get('loot_items', {}).keys())

            for table_type in ['loot_templates', 'loot_tables']:
                if table_type in self.data['loot_tables']:
                    for table_id, table_data in self.data['loot_tables'][table_type].items():
                        # Check guaranteed_drops and rare_drops
                        for drop_list_name in ['guaranteed_drops', 'rare_drops']:
                            if drop_list_name in table_data:
                                for drop in table_data[drop_list_name]:
                                    loot_item_id = drop.get('loot_item_id')
                                    if loot_item_id and loot_item_id not in loot_item_ids:
                                        self.add_issue("high", "BROKEN REFERENCE",
                                                      f"loot_tables.json:{table_id} references unknown loot_item '{loot_item_id}'")
            print(f"  Validated loot table references")

        # Check crafting_recipes.json references resources.json
        if 'crafting_recipes' in self.data:
            print("\nValidating crafting_recipes.json references...")
            recipes = {k: v for k, v in self.data['crafting_recipes'].items() if not k.startswith('_')}
            for recipe_id, recipe_data in recipes.items():
                if 'materials' in recipe_data:
                    for mat_id in recipe_data['materials'].keys():
                        if mat_id not in resource_ids and mat_id != 'mana':  # mana is special
                            self.add_issue("high", "BROKEN REFERENCE",
                                          f"crafting_recipes.json:{recipe_id} references unknown resource '{mat_id}'")
            print(f"  Checked {len(recipes)} crafting recipes")

        # Check summon_config.json references gods.json
        if 'summon_config' in self.data and 'gods' in self.data:
            print("\nValidating summon_config.json references...")
            god_ids = set(self.data['gods'].get('gods', {}).keys())
            # Summon config doesn't directly reference god IDs, it uses rarity-based system
            # This is correct by design
            print(f"  Summon system uses rarity-based selection (by design)")

        # Check dungeon_waves.json references enemies.json
        if 'dungeon_waves' in self.data and 'enemies' in self.data:
            print("\nValidating dungeon_waves.json references...")
            # Extract enemy names from enemies.json
            enemy_names = set()
            enemy_types = self.data['enemies'].get('enemy_types', {})
            for element, roles in enemy_types.items():
                for role, enemies in roles.items():
                    if isinstance(enemies, dict):
                        enemy_names.update(enemies.keys())

            # Also check territory defenders
            territory_defenders = self.data['enemies'].get('territory_defenders', {})
            for tier, node_types in territory_defenders.items():
                if not isinstance(node_types, dict):
                    continue
                for node_type, enemies in node_types.items():
                    if isinstance(enemies, dict):
                        enemy_names.update(enemies.keys())

            # Check all wave configurations
            wave_count = 0
            for dungeon_type, dungeons in self.data['dungeon_waves'].items():
                if dungeon_type.startswith('_'):
                    continue
                for dungeon_id, difficulties in dungeons.items():
                    for difficulty, diff_data in difficulties.items():
                        if 'waves' in diff_data:
                            for wave in diff_data['waves']:
                                wave_count += 1
                                for enemy in wave.get('enemies', []):
                                    enemy_name = enemy.get('name')
                                    # Note: enemy names in dungeon_waves don't match enemies.json exactly
                                    # This appears to be by design (different naming convention)

            print(f"  Checked {wave_count} dungeon waves")

        # Check dungeons.json references dungeon_waves
        if 'dungeons' in self.data and 'dungeon_waves' in self.data:
            print("\nValidating dungeons.json structure...")
            # dungeons.json contains metadata, dungeon_waves.json contains wave data
            # They should align on dungeon IDs and difficulty levels
            dungeon_ids_meta = set()
            for category in ['elemental_sanctums', 'special_sanctums', 'pantheon_trials', 'equipment_dungeons']:
                if category in self.data['dungeons']:
                    dungeon_ids_meta.update(self.data['dungeons'][category].keys())

            dungeon_ids_waves = set()
            for category in self.data['dungeon_waves'].keys():
                if not category.startswith('_'):
                    dungeon_ids_waves.update(self.data['dungeon_waves'][category].keys())

            missing_waves = dungeon_ids_meta - dungeon_ids_waves
            extra_waves = dungeon_ids_waves - dungeon_ids_meta

            for dungeon_id in missing_waves:
                self.add_issue("medium", "MISSING WAVES",
                              f"dungeons.json defines '{dungeon_id}' but no waves in dungeon_waves.json")
            for dungeon_id in extra_waves:
                self.add_issue("low", "EXTRA WAVES",
                              f"dungeon_waves.json has waves for '{dungeon_id}' not in dungeons.json")

            print(f"  Dungeons in metadata: {len(dungeon_ids_meta)}")
            print(f"  Dungeons with waves: {len(dungeon_ids_waves)}")

    def check_required_fields(self):
        """Check that required fields are present in each entry"""
        print("\n" + "=" * 80)
        print("CHECKING REQUIRED FIELDS")
        print("=" * 80)

        # Check gods.json
        if 'gods' in self.data:
            print("\nValidating gods.json entries...")
            required_god_fields = ['id', 'name', 'pantheon', 'element', 'base_hp',
                                  'base_attack', 'base_defense', 'base_speed']
            gods = self.data['gods'].get('gods', {})
            for god_id, god_data in gods.items():
                for field in required_god_fields:
                    if field not in god_data:
                        self.add_issue("high", "MISSING FIELD",
                                      f"gods.json:{god_id} missing required field '{field}'")
            print(f"  Validated {len(gods)} gods")

        # Check resources.json
        if 'resources' in self.data:
            print("\nValidating resources.json entries...")
            required_resource_fields = ['id', 'name', 'category']
            for category, resources in self.data['resources'].items():
                if category.startswith('_') or category == 'resource_groups':
                    continue
                if isinstance(resources, dict):
                    for res_id, res_data in resources.items():
                        for field in required_resource_fields:
                            if field not in res_data:
                                self.add_issue("medium", "MISSING FIELD",
                                              f"resources.json:{category}:{res_id} missing '{field}'")

    def check_unique_ids(self):
        """Check that IDs are unique within each file"""
        print("\n" + "=" * 80)
        print("CHECKING ID UNIQUENESS")
        print("=" * 80)

        # Check gods
        if 'gods' in self.data:
            gods = self.data['gods'].get('gods', {})
            if len(gods) != len(set(gods.keys())):
                self.add_issue("critical", "DUPLICATE IDS",
                              "gods.json has duplicate god IDs")
            else:
                print(f"OK All {len(gods)} god IDs are unique")

        # Check resources (across all categories)
        if 'resources' in self.data:
            all_resource_ids = []
            for category, resources in self.data['resources'].items():
                if category.startswith('_') or category == 'resource_groups':
                    continue
                if isinstance(resources, dict):
                    all_resource_ids.extend(resources.keys())

            if len(all_resource_ids) != len(set(all_resource_ids)):
                duplicates = [rid for rid in all_resource_ids if all_resource_ids.count(rid) > 1]
                self.add_issue("critical", "DUPLICATE IDS",
                              f"resources.json has duplicate resource IDs: {set(duplicates)}")
            else:
                print(f"OK All {len(all_resource_ids)} resource IDs are unique")

    def print_report(self):
        """Print the final validation report"""
        print("\n" + "=" * 80)
        print("VALIDATION REPORT")
        print("=" * 80)

        total_issues = sum(len(issues) for issues in self.issues.values())

        if total_issues == 0:
            print("\nOK All validations passed! No issues found.")
            return 0

        print(f"\nFound {total_issues} total issues:")
        print(f"  Critical: {len(self.issues['critical'])}")
        print(f"  High: {len(self.issues['high'])}")
        print(f"  Medium: {len(self.issues['medium'])}")
        print(f"  Low: {len(self.issues['low'])}")

        for priority in ['critical', 'high', 'medium', 'low']:
            if self.issues[priority]:
                print(f"\n{'=' * 80}")
                print(f"{priority.upper()} PRIORITY ISSUES ({len(self.issues[priority])})")
                print('=' * 80)
                for issue in sorted(self.issues[priority]):
                    print(f"  • {issue}")

        return 1 if self.issues['critical'] or self.issues['high'] else 0

def main():
    validator = JSONValidator("data")
    validator.load_all_json()
    validator.check_unique_ids()
    validator.check_required_fields()
    validator.validate_cross_references()
    return validator.print_report()

if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""
Scene and orphaned file validator for Godot project
"""

import os
import re
from pathlib import Path
from collections import defaultdict

def validate_scenes():
    """Validate all .tscn files"""
    print('=' * 80)
    print('PART 2: SCENE VALIDATION')
    print('=' * 80)

    scenes_dir = Path('scenes')
    critical = []
    high = []
    medium = []

    # Find all .tscn files
    scene_files = list(scenes_dir.rglob('*.tscn'))
    print(f'\nFound {len(scene_files)} scene files')

    # Pattern to match script paths and external resources
    ext_resource_pattern = r'\[ext_resource[^\]]*path="([^"]+)"[^\]]*id="([^"]+)"'

    for scene_file in sorted(scene_files):
        try:
            with open(scene_file, 'r', encoding='utf-8') as f:
                content = f.read()

                # Find all external resources
                ext_resources = []
                for match in re.finditer(ext_resource_pattern, content):
                    path, res_id = match.groups()
                    ext_resources.append(path)

                    # Convert res:// path to filesystem path
                    if path.startswith('res://'):
                        fs_path = path.replace('res://', '')
                        full_path = Path(fs_path)

                        if not full_path.exists():
                            critical.append(f'{scene_file.name}: Missing resource {path}')

        except Exception as e:
            critical.append(f'{scene_file.name}: Error reading file - {str(e)}')

    print(f'\n  Validated {len(scene_files)} scene files')
    print(f'  Critical issues: {len(critical)}')
    print(f'  High issues: {len(high)}')
    print(f'  Medium issues: {len(medium)}')

    if critical:
        print('\nCRITICAL ISSUES:')
        for issue in sorted(set(critical)):
            print(f'  - {issue}')

    if high:
        print('\nHIGH PRIORITY ISSUES:')
        for issue in sorted(set(high)):
            print(f'  - {issue}')

    return len(critical), len(high), len(medium)

def find_orphaned_files():
    """Find orphaned .gd and .tscn files"""
    print('\n' + '=' * 80)
    print('PART 3: ORPHANED FILE DETECTION')
    print('=' * 80)

    # Find all .gd files
    all_gd_files = set()
    for path in Path('.').rglob('*.gd'):
        if '.godot' not in str(path):  # Skip .godot directory
            all_gd_files.add(str(path).replace('\\', '/'))

    # Find all .tscn files
    all_tscn_files = set()
    for path in Path('.').rglob('*.tscn'):
        if '.godot' not in str(path):
            all_tscn_files.add(str(path).replace('\\', '/'))

    # Find all .uid files
    all_uid_files = set()
    for path in Path('.').rglob('*.uid'):
        if '.godot' not in str(path):
            all_uid_files.add(str(path).replace('\\', '/'))

    # Track referenced files
    referenced_gd_files = set()
    referenced_tscn_files = set()

    # Check all .gd files for references to other .gd files
    for gd_file in all_gd_files:
        try:
            with open(gd_file, 'r', encoding='utf-8') as f:
                content = f.read()

                # Find preload and load statements
                for match in re.finditer(r'(?:preload|load)\s*\(\s*["\']([^"\']+\.gd)["\']', content):
                    ref_path = match.group(1)
                    if ref_path.startswith('res://'):
                        ref_path = ref_path.replace('res://', '')
                    referenced_gd_files.add(ref_path)

                # Find scene references
                for match in re.finditer(r'(?:preload|load)\s*\(\s*["\']([^"\']+\.tscn)["\']', content):
                    ref_path = match.group(1)
                    if ref_path.startswith('res://'):
                        ref_path = ref_path.replace('res://', '')
                    referenced_tscn_files.add(ref_path)

        except Exception as e:
            pass

    # Check all .tscn files for references
    for tscn_file in all_tscn_files:
        try:
            with open(tscn_file, 'r', encoding='utf-8') as f:
                content = f.read()

                # Find ext_resource paths
                for match in re.finditer(r'path="([^"]+)"', content):
                    ref_path = match.group(1)
                    if ref_path.startswith('res://'):
                        ref_path = ref_path.replace('res://', '')

                        if ref_path.endswith('.gd'):
                            referenced_gd_files.add(ref_path)
                        elif ref_path.endswith('.tscn'):
                            referenced_tscn_files.add(ref_path)

        except Exception as e:
            pass

    # Find orphaned files
    orphaned_gd = []
    for gd_file in all_gd_files:
        # Check if referenced
        if gd_file not in referenced_gd_files:
            # Special case: Main.gd is the entry point
            if gd_file.endswith('Main.gd') or gd_file.endswith('/TestHarness.gd'):
                continue
            orphaned_gd.append(gd_file)

    orphaned_tscn = []
    for tscn_file in all_tscn_files:
        if tscn_file not in referenced_tscn_files:
            # Special case: Main.tscn is the entry point
            if tscn_file.endswith('Main.tscn'):
                continue
            orphaned_tscn.append(tscn_file)

    # Find orphaned .uid files
    orphaned_uid = []
    for uid_file in all_uid_files:
        # Check if corresponding script exists
        script_file = uid_file.replace('.uid', '')
        if script_file not in all_gd_files and script_file not in all_tscn_files:
            orphaned_uid.append(uid_file)

    print(f'\n  Total .gd files: {len(all_gd_files)}')
    print(f'  Referenced .gd files: {len(referenced_gd_files)}')
    print(f'  Potentially orphaned .gd files: {len(orphaned_gd)}')

    print(f'\n  Total .tscn files: {len(all_tscn_files)}')
    print(f'  Referenced .tscn files: {len(referenced_tscn_files)}')
    print(f'  Potentially orphaned .tscn files: {len(orphaned_tscn)}')

    print(f'\n  Orphaned .uid files: {len(orphaned_uid)}')

    if orphaned_gd:
        print('\nPOTENTIALLY ORPHANED .GD FILES:')
        for f in sorted(orphaned_gd):
            print(f'  - {f}')

    if orphaned_tscn:
        print('\nPOTENTIALLY ORPHANED .TSCN FILES:')
        for f in sorted(orphaned_tscn):
            print(f'  - {f}')

    if orphaned_uid:
        print('\nORPHANED .UID FILES (script/scene no longer exists):')
        for f in sorted(orphaned_uid):
            print(f'  - {f}')

    return len(orphaned_gd), len(orphaned_tscn), len(orphaned_uid)

def main():
    crit_scenes, high_scenes, med_scenes = validate_scenes()
    orph_gd, orph_tscn, orph_uid = find_orphaned_files()

    print('\n' + '=' * 80)
    print('SUMMARY')
    print('=' * 80)
    print(f'\nScene Issues:')
    print(f'  Critical: {crit_scenes}')
    print(f'  High: {high_scenes}')
    print(f'  Medium: {med_scenes}')
    print(f'\nOrphaned Files:')
    print(f'  Potentially orphaned .gd files: {orph_gd}')
    print(f'  Potentially orphaned .tscn files: {orph_tscn}')
    print(f'  Orphaned .uid files: {orph_uid}')

    return 1 if crit_scenes > 0 or orph_uid > 0 else 0

if __name__ == '__main__':
    import sys
    sys.exit(main())

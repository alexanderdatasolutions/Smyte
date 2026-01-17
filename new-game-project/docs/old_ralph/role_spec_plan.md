# God Role & Specialization System Implementation Plan

## Status Tracking
Track implementation progress. Update `complete` from `false` to `true` after each task.

---

## Phase 1: Design Documentation (MANDATORY FIRST)

```json
[
  {
    "id": "P1-01",
    "task": "Create complete design document",
    "file": "docs/god_roles_and_specializations.md",
    "description": "Full design doc with role taxonomy, specialization trees, progression requirements, stat effects, and JSON schemas. Must have 5+ roles, 60+ specialization nodes.",
    "complete": true
  }
]
```

---

## Phase 2: Data Files

```json
[
  {
    "id": "P2-01",
    "task": "Create roles.json",
    "file": "data/roles.json",
    "description": "Define 5 base roles (Fighter, Gatherer, Crafter, etc) with bonuses and requirements",
    "complete": true
  },
  {
    "id": "P2-02",
    "task": "Update specializations.json with full tree",
    "file": "data/specializations.json",
    "description": "Complete specialization tree: 3-4 paths per role, 3 tiers each (Lvl 20/30/40). ~60+ nodes total.",
    "complete": true
  }
]
```

---

## Phase 3: Data Classes

```json
[
  {
    "id": "P3-01",
    "task": "Create GodRole.gd data class",
    "file": "scripts/data/GodRole.gd",
    "description": "Role data class with enum, bonuses, requirements. Use load().new() pattern for from_dict().",
    "complete": true
  },
  {
    "id": "P3-02",
    "task": "Update GodSpecialization.gd for tree structure",
    "file": "scripts/data/GodSpecialization.gd",
    "description": "Add parent/child relationships, tier support, unlock requirements. Rename from Specialization if needed.",
    "complete": true
  }
]
```

---

## Phase 4: System Implementation

```json
[
  {
    "id": "P4-01",
    "task": "Create RoleManager.gd",
    "file": "scripts/systems/roles/RoleManager.gd",
    "description": "Manages role definitions, queries, and role-based bonuses. Register in SystemRegistry.",
    "complete": true
  },
  {
    "id": "P4-02",
    "task": "Update SpecializationManager.gd",
    "file": "scripts/systems/specialization/SpecializationManager.gd",
    "description": "Support full tree structure, unlock validation, specialization progression.",
    "complete": true
  },
  {
    "id": "P4-03",
    "task": "Register systems in SystemRegistry.gd",
    "file": "scripts/systems/core/SystemRegistry.gd",
    "description": "Add RoleManager registration, verify SpecializationManager is registered correctly.",
    "complete": true
  }
]
```

---

## Phase 5: God Integration

```json
[
  {
    "id": "P5-01",
    "task": "Update God.gd with role/spec fields",
    "file": "scripts/data/God.gd",
    "description": "Add primary_role, secondary_role, specialization_path, can_specialize(), get_available_specializations(), apply_specialization()",
    "complete": true
  },
  {
    "id": "P5-02",
    "task": "Update gods.json with role data",
    "file": "data/gods.json",
    "description": "Add default_role and role_affinities to all god definitions based on lore.",
    "complete": true
  },
  {
    "id": "P5-03",
    "task": "Update GodFactory.gd",
    "file": "scripts/systems/collection/GodFactory.gd",
    "description": "Initialize role data when creating new gods, set innate roles from definition.",
    "complete": true
  },
  {
    "id": "P5-04",
    "task": "Update SaveLoadUtility.gd",
    "file": "scripts/utilities/SaveLoadUtility.gd",
    "description": "Save/load role and specialization data for all gods.",
    "complete": true
  }
]
```

---

## Phase 6: Unit Tests (MANDATORY)

```json
[
  {
    "id": "P6-01",
    "task": "Create test_god_role.gd",
    "file": "tests/unit/test_god_role.gd",
    "description": "Unit tests for GodRole.gd - all public methods, edge cases, from_dict()",
    "tests_count": 78,
    "complete": true
  },
  {
    "id": "P6-02",
    "task": "Create test_god_specialization.gd",
    "file": "tests/unit/test_god_specialization.gd",
    "description": "Unit tests for GodSpecialization.gd - tree structure, tier validation",
    "tests_count": 107,
    "complete": true
  },
  {
    "id": "P6-03",
    "task": "Create test_role_manager.gd",
    "file": "tests/unit/test_role_manager.gd",
    "description": "Unit tests for RoleManager.gd - all queries, bonus calculations",
    "tests_count": 60,
    "complete": true
  },
  {
    "id": "P6-04",
    "task": "Create test_specialization_manager.gd",
    "file": "tests/unit/test_specialization_manager.gd",
    "description": "Unit tests for SpecializationManager.gd - tree loading, unlock logic",
    "tests_count": 95,
    "complete": true
  }
]
```

---

## Phase 7: UI Screens

```json
[
  {
    "id": "P7-01",
    "task": "Create SpecializationNode.gd component",
    "file": "scripts/ui/components/SpecializationNode.gd",
    "description": "Reusable tree node display - shows name, icon, locked/unlocked state, requirements",
    "complete": true
  },
  {
    "id": "P7-02",
    "task": "Create SpecializationTree.gd component",
    "file": "scripts/ui/components/SpecializationTree.gd",
    "description": "Visual tree container - renders full specialization path with connections",
    "complete": true
  },
  {
    "id": "P7-03",
    "task": "Create GodSpecializationScreen.gd",
    "file": "scripts/ui/screens/GodSpecializationScreen.gd",
    "description": "Full screen for viewing and selecting specializations. Dark fantasy theme.",
    "complete": true
  },
  {
    "id": "P7-04",
    "task": "Create GodSpecializationScreen.tscn",
    "file": "scenes/GodSpecializationScreen.tscn",
    "description": "Scene file for GodSpecializationScreen with proper node hierarchy",
    "complete": true
  }
]
```

---

## Role Definitions Reference

| Role | Primary Bonus | Best Tasks | Description |
|------|---------------|------------|-------------|
| **Fighter** | +Combat stats | Battle, Defense | Gods suited for war and conflict |
| **Gatherer** | +Resource yield | Mining, Harvesting, Fishing, Hunting | Gods connected to nature and resources |
| **Crafter** | +Crafting quality | Forging, Alchemy, Enchanting | Gods of creation and artifice |
| **Scholar** | +Research/XP speed | Research, Scouting, Training | Gods of wisdom and knowledge |
| **Support** | +Team buffs | Healing, Buffing, Leadership | Gods who empower others |

## Specialization Tiers

- **Tier 1 (Level 20)**: Choose sub-path, gain +10% path bonus
- **Tier 2 (Level 30)**: Advance path, gain +20% bonus + unique ability
- **Tier 3 (Level 40)**: Master path, gain +30% bonus + passive effect

## Example Tree: Gatherer Role

```
Gatherer (Base - Level 1+)
├── Miner (T1 - Level 20)
│   ├── Gem Cutter (T2 - Level 30)
│   │   └── Master Jeweler (T3 - Level 40)
│   └── Deep Miner (T2 - Level 30)
│       └── Earth Shaper (T3 - Level 40)
├── Fisher (T1 - Level 20)
│   ├── Pearl Diver (T2 - Level 30)
│   │   └── Ocean Master (T3 - Level 40)
│   └── Whale Hunter (T2 - Level 30)
│       └── Sea Lord (T3 - Level 40)
├── Herbalist (T1 - Level 20)
│   ├── Alchemist (T2 - Level 30)
│   │   └── Potion Master (T3 - Level 40)
│   └── Naturalist (T2 - Level 30)
│       └── Grove Keeper (T3 - Level 40)
└── Hunter (T1 - Level 20)
    ├── Tracker (T2 - Level 30)
    │   └── Beast Master (T3 - Level 40)
    └── Trapper (T2 - Level 30)
        └── Monster Slayer (T3 - Level 40)
```

---

## Critical Implementation Notes

1. **Reserved Keywords**: NEVER use `var trait` or `var task` - use `god_trait`, `current_task`, etc.
2. **Static Factory Pattern**: Use `load("res://path.gd").new()` not `ClassName.new()` in static methods
3. **File Size Limit**: Keep files under 500 lines
4. **Test First**: Create unit tests before or alongside implementation
5. **Screenshots**: Take screenshot after UI changes to verify nothing broke

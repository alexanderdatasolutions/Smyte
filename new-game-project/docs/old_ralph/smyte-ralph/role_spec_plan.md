# God Role & Specialization System Implementation Plan

## Status Tracking
Track implementation progress. Update `complete` from `false` to `true` after each task.

## Tasks

### Phase 1: Data Layer (Foundation)
```json
[
  {
    "id": "P1-01",
    "task": "Create GodRole.gd data class",
    "file": "scripts/data/GodRole.gd",
    "description": "Define role enum and data class for Fighter, Gatherer, Crafter, Scholar, Support",
    "complete": false
  },
  {
    "id": "P1-02",
    "task": "Create GodSpecialization.gd data class",
    "file": "scripts/data/GodSpecialization.gd",
    "description": "Define specialization tree structure with level requirements (20, 30, 40)",
    "complete": false
  },
  {
    "id": "P1-03",
    "task": "Create roles.json data file",
    "file": "data/roles.json",
    "description": "Define all 5 base roles with their bonuses and unlock requirements",
    "complete": false
  },
  {
    "id": "P1-04",
    "task": "Update specializations.json",
    "file": "data/specializations.json",
    "description": "Add full specialization tree for each role (Tier 1/2/3 at levels 20/30/40)",
    "complete": false
  }
]
```

### Phase 2: System Layer (Logic)
```json
[
  {
    "id": "P2-01",
    "task": "Create RoleManager.gd",
    "file": "scripts/systems/specialization/RoleManager.gd",
    "description": "Handle role assignment, role bonuses calculation, role requirements checking",
    "complete": false
  },
  {
    "id": "P2-02",
    "task": "Update SpecializationManager.gd",
    "file": "scripts/systems/specialization/SpecializationManager.gd",
    "description": "Connect specializations to roles, handle specialization unlocks and progression",
    "complete": false
  },
  {
    "id": "P2-03",
    "task": "Register systems in SystemRegistry.gd",
    "file": "scripts/systems/core/SystemRegistry.gd",
    "description": "Add RoleManager and update SpecializationManager registration",
    "complete": false
  }
]
```

### Phase 3: God Integration
```json
[
  {
    "id": "P3-01",
    "task": "Update God.gd with role fields",
    "file": "scripts/data/God.gd",
    "description": "Add current_role, specialization_path, specialization_tier fields",
    "complete": false
  },
  {
    "id": "P3-02",
    "task": "Update gods.json with role data",
    "file": "data/gods.json",
    "description": "Add default_role and role_affinities to god definitions",
    "complete": false
  },
  {
    "id": "P3-03",
    "task": "Update GodFactory.gd",
    "file": "scripts/systems/collection/GodFactory.gd",
    "description": "Initialize role data when creating new gods",
    "complete": false
  }
]
```

### Phase 4: Unit Tests
```json
[
  {
    "id": "P4-01",
    "task": "Create test_god_role.gd",
    "file": "tests/unit/test_god_role.gd",
    "description": "Unit tests for GodRole.gd data class",
    "tests_count": 0,
    "complete": false
  },
  {
    "id": "P4-02",
    "task": "Create test_god_specialization.gd",
    "file": "tests/unit/test_god_specialization.gd",
    "description": "Unit tests for GodSpecialization.gd data class",
    "tests_count": 0,
    "complete": false
  },
  {
    "id": "P4-03",
    "task": "Create test_role_manager.gd",
    "file": "tests/unit/test_role_manager.gd",
    "description": "Unit tests for RoleManager.gd",
    "tests_count": 0,
    "complete": false
  },
  {
    "id": "P4-04",
    "task": "Create test_specialization_manager.gd",
    "file": "tests/unit/test_specialization_manager.gd",
    "description": "Unit tests for SpecializationManager.gd",
    "tests_count": 0,
    "complete": false
  }
]
```

### Phase 5: UI Integration (Optional)
```json
[
  {
    "id": "P5-01",
    "task": "Create RoleSelectionPanel.gd",
    "file": "scripts/ui/god/RoleSelectionPanel.gd",
    "description": "UI for selecting a god's role when they reach level requirements",
    "complete": false
  },
  {
    "id": "P5-02",
    "task": "Create SpecializationTreeView.gd",
    "file": "scripts/ui/god/SpecializationTreeView.gd",
    "description": "Visual tree showing specialization paths and current progress",
    "complete": false
  }
]
```

---

## Role Definitions

| Role | Primary Bonus | Best Tasks | Specializations |
|------|---------------|------------|-----------------|
| **Fighter** | +Combat stats | Battle, Defense | Berserker, Paladin, Assassin |
| **Gatherer** | +Resource yield | Mining, Harvesting, Fishing | Master Miner, Master Harvester, Master Hunter |
| **Crafter** | +Crafting quality | Forging, Alchemy, Enchanting | Blacksmith, Alchemist, Enchanter |
| **Scholar** | +Research speed | Research, Scouting | Sage, Strategist, Explorer |
| **Support** | +Team buffs | Training, Healing | Commander, Mentor, Healer |

## Specialization Tiers

- **Tier 1 (Level 20)**: Choose base role, gain +10% role bonus
- **Tier 2 (Level 30)**: Choose sub-specialization, gain +20% spec bonus + unique ability
- **Tier 3 (Level 40)**: Master specialization, gain +30% mastery bonus + passive effect

---

## Design Notes

1. **Roles are permanent** - once chosen, cannot be changed (unless future respec system)
2. **Specializations branch from roles** - must have role before specializing
3. **Gods have role affinities** - some gods are better suited for certain roles (e.g., Hephaestus → Crafter)
4. **Traits complement roles** - traits provide task bonuses, roles provide stat/efficiency bonuses

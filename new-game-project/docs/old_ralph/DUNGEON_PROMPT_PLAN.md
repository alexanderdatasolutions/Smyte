@docs/DUNGEON_WAVE_SYSTEM_SPEC.md

# Dungeon System - Planning Phase

## Your Role

You are an expert game designer analyzing the dungeon system for a mobile god-collection RPG.

## Context

The user wants a comprehensive dungeon system with:
- **Multi-wave battles** - Progressive difficulty waves per dungeon
- **Meaningful loot drops** - Materials for crafting, equipment, resources
- **Daily dungeon loop** - Core gameplay mechanic players engage with daily
- **Full app polish** - Professional quality, ready for production

## Current State Analysis Needed

Using Glob and Grep tools, analyze:

1. **What exists**:
   - `data/dungeons.json` - Current dungeon definitions
   - `scripts/systems/dungeon/` - DungeonCoordinator, DungeonManager
   - `scripts/systems/battle/` - WaveManager, BattleCoordinator
   - `scripts/ui/screens/DungeonScreen.gd` - UI implementation
   - `scripts/data/BattleConfig.gd` - Wave configuration structure

2. **What's missing**:
   - Multi-wave configurations in dungeon data
   - Reward configurations (mana, materials, equipment)
   - Loot drop system integration with crafting
   - Daily reset mechanic
   - Dungeon completion tracking
   - Visual polish (animations, effects, feedback)

3. **How it connects**:
   - Crafting system (`scripts/systems/crafting/`)
   - Equipment system (`scripts/systems/equipment/`)
   - Resource system (`scripts/systems/resources/`)
   - Progression system

## Your Task

Create a comprehensive implementation plan in a new file:

**File**: `new-game-project/DUNGEON_IMPLEMENTATION_PLAN.md`

**Structure**:
```markdown
# Dungeon System - Implementation Plan

## Analysis

### Current State
[What exists and how it works]

### Gaps
[What's missing for the full vision]

### Integration Points
[How dungeons connect to crafting, equipment, progression]

---

## Task List

```json
[
  {
    "category": "data",
    "description": "Add multi-wave configurations to all dungeons",
    "steps": [...],
    "passes": false
  },
  {
    "category": "data",
    "description": "Design reward tables for each dungeon tier",
    "steps": [...],
    "passes": false
  },
  ...
]
```
```

## Planning Checklist

Your plan MUST include tasks for:

**Data & Configuration**:
- [ ] Multi-wave enemy configurations (2-5 waves per dungeon)
- [ ] Reward tables (mana, materials, equipment drops)
- [ ] Material drops mapped to crafting recipes
- [ ] Dungeon difficulty scaling (heroic → legendary)
- [ ] Daily dungeon energy costs

**Systems**:
- [ ] Loot drop calculation system
- [ ] Daily dungeon reset mechanic
- [ ] Dungeon completion tracking (first-time bonuses)
- [ ] Integration with crafting system (materials unlock recipes)
- [ ] Integration with progression (dungeon completion unlocks hex nodes)

**Polish**:
- [ ] Wave transition animations
- [ ] Loot reveal animations
- [ ] Victory screen polish
- [ ] Sound effects for wave clear
- [ ] Particle effects for rewards

**Testing & Verification**:
- [ ] Multi-wave progression works correctly
- [ ] Rewards granted properly
- [ ] Gods NOT deleted on defeat (bug verification)
- [ ] Save/load persistence
- [ ] Daily reset functionality

## Completion

When the plan is complete and comprehensive, output:

`<promise>COMPLETE</promise>`

Then the build phase can begin.

## Critical Rules

- ❌ Do NOT implement anything yet - this is PLANNING ONLY
- ✅ Study existing code first using Glob/Grep
- ✅ Create task list using JSON format with "passes": false
- ✅ Each task should be specific and actionable
- ✅ Include acceptance criteria in steps
- ✅ Prioritize: data → systems → polish → testing

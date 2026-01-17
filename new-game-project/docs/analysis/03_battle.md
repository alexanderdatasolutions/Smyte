# Battle System Analysis

## Files Analyzed
- BattleCoordinator.gd - Main orchestrator for battle flow, replaces monolithic BattleManager
- BattleActionProcessor.gd - Processes attack/skill/defend actions and applies effects
- BattleAI.gd - Simple enemy AI for choosing actions
- BattleEffectProcessor.gd - Handles damage/heal/buff/debuff/shield/cleanse effects
- BattleFactory.gd - Creates battle configurations for different battle types
- CombatCalculator.gd - Damage formulas, stat calculations, element multipliers
- StatusEffectManager.gd - Turn-based status effect processing (poison, burn, stun, etc.)
- TurnManager.gd - Turn bar system and turn progression
- WaveManager.gd - Multi-wave PvE battle management

## What It Does
A complete turn-based combat system inspired by Summoners War:

**Turn System**: Uses a turn bar (ATB-style) system where units accumulate turn bar based on speed. When a unit reaches 100% turn bar, they take a turn. Fastest units go first; multiple ready units are sorted by speed.

**Combat Flow**:
1. BattleFactory creates battle config (territory/dungeon/arena)
2. BattleCoordinator initializes subsystems and begins battle flow
3. TurnManager calculates turn order and cycles through units
4. Actions (attack/skill/defend) are processed by BattleActionProcessor
5. CombatCalculator handles damage using authentic SW formula: `ATK * Multiplier * (1000 / (1140 + 3.5 * DEF))`
6. StatusEffectManager processes DoTs and buffs each turn
7. WaveManager handles multi-wave PvE progression
8. Victory/defeat conditions checked after each action

**Damage Features**: Critical hits (crit rate + crit damage), glancing hits (70% damage), elemental advantages (Fire > Earth > Water > Fire, Light <> Dark), ±10% random variance.

## Status: WORKING

The battle system is well-architected and mostly complete. Core combat loop is functional.

## Code Quality
- [x] Clean architecture - refactored from 1043-line god class into 9 focused components
- [x] Proper typing - GDScript type hints used throughout
- [x] Error handling - validation, null checks, safety counters
- [x] Comments/docs - good docstrings and inline comments

## Key Findings
- Clean separation of concerns: coordinator, turn management, action processing, and damage calculation are all separate
- Authentic Summoners War damage formula implemented correctly
- Turn bar system follows SW mechanics (speed-based ATB)
- Support for multiple battle types: territory, dungeon, arena, raid, guild war
- Auto-battle AI with skill prioritization
- Wave system for PvE content
- Elemental advantage system (Fire/Water/Earth triangle, Light/Dark mutual)
- Status effect system with poison, burn, heal-over-time, shield, stun
- Equipment stat integration marked as TODO but architecture is ready

## Issues Found
- **EventBus integration disabled**: Multiple TODOs note "Re-enable EventBus once parsing issues resolved" - battle events not propagating to global event system
- **BattleEffectProcessor uses wrong pattern**: Tries to get CombatCalculator from SystemRegistry but CombatCalculator is a static class, not a registered system
- **Skill.get_target_count() assumed**: BattleAI and BattleCoordinator call `skill.get_target_count()` but Skill.gd was noted as a stub in data analysis
- **_find_best_targets null skill issue**: `_find_best_targets(null, targets)` is called when falling back to basic attack, but the function calls `skill.get_target_count()` on a null skill
- **TurnManager._end_current_turn bug**: Calls `get_current_unit()` which returns the NEXT unit in queue (after pop_front), not the one whose turn just ended
- **Missing EnemyFactory system**: BattleFactory references `EnemyFactory` system that doesn't appear to exist
- **BattleEffectProcessor emit_signal pattern**: Uses string-based `emit_signal()` which is deprecated in Godot 4

## Dependencies
- **Depends on:**
  - Data models: BattleUnit, BattleAction, BattleState, BattleResult, ActionResult, DamageResult, Skill, StatusEffect, God, BattleConfig
  - Core: SystemRegistry, EventBus (partially disabled), ResourceManager
  - Missing: EnemyFactory
- **Used by:** UI screens (battle screen), dungeon system, territory system, arena system

# Dungeon Wave System - Verification Plan

## Overview
Verify and fix the dungeon/wave battle system to ensure:
- Multi-wave battles work correctly
- Gods are NOT deleted on defeat
- Rewards are properly granted
- Save/load preserves god collection

**Reference:** `docs/DUNGEON_WAVE_SYSTEM_SPEC.md`

---

## Task List

```json
[
  {
    "category": "data",
    "description": "Add multi-wave configurations to dungeons.json",
    "steps": [
      "Read data/dungeons.json to understand current structure",
      "Add enemy_waves array to at least 2 dungeons (e.g., Olympian Trials, Sanctum of Flames)",
      "Each wave should have 2-3 enemies with proper level scaling",
      "Verify JSON is valid",
      "Git commit the change"
    ],
    "passes": false
  },
  {
    "category": "testing",
    "description": "Verify multi-wave battle progression works",
    "steps": [
      "Run the game via mcp__godot__run_project",
      "Navigate to DungeonScreen",
      "Enter a multi-wave dungeon",
      "Complete wave 1, verify wave 2 spawns",
      "Complete wave 2, verify wave 3 spawns (if configured)",
      "Complete all waves, verify victory",
      "Check console output for errors via get_debug_output",
      "Take screenshot of victory screen",
      "Git commit verification notes to dungeon-activity.md"
    ],
    "passes": false
  },
  {
    "category": "data",
    "description": "Add rewards configuration to dungeons",
    "steps": [
      "Read data/dungeons.json difficulty_levels structure",
      "Add rewards object to each difficulty (mana, equipment_chance, materials)",
      "Match reward tiers to difficulty (heroic=500 mana, legendary=1000 mana)",
      "Verify JSON is valid",
      "Git commit the change"
    ],
    "passes": false
  },
  {
    "category": "testing",
    "description": "Verify dungeon rewards are granted on victory",
    "steps": [
      "Run the game",
      "Note current mana count before battle",
      "Win a dungeon battle",
      "Check mana count increased by configured amount",
      "Check console for reward grant messages",
      "Take screenshot showing mana increase",
      "Git commit verification notes"
    ],
    "passes": false
  },
  {
    "category": "testing",
    "description": "Verify gods are NOT deleted on battle defeat",
    "steps": [
      "Run the game",
      "Count gods in collection (use game_interact to call get_all_gods)",
      "Start a difficult battle with weak team",
      "Intentionally lose the battle",
      "Check console for 'REMOVING GOD' messages (should be NONE)",
      "Count gods again - should be UNCHANGED",
      "Return to CollectionScreen, verify all gods visible",
      "Take screenshot of collection",
      "Git commit verification notes"
    ],
    "passes": false
  },
  {
    "category": "testing",
    "description": "Verify save/load preserves god collection through battles",
    "steps": [
      "Run the game",
      "Count gods before battle",
      "Fight and win a battle",
      "Save the game",
      "Stop the game completely",
      "Restart the game and load save",
      "Count gods again - should match",
      "Git commit verification notes"
    ],
    "passes": false
  },
  {
    "category": "documentation",
    "description": "Create final verification report",
    "steps": [
      "Create docs/DUNGEON_WAVE_VERIFICATION_REPORT.md",
      "Document all findings from testing",
      "Confirm bug status (gods deletion - confirmed or debunked)",
      "List any remaining issues or recommendations",
      "Mark wave system as production-ready or list blockers",
      "Git commit the report"
    ],
    "passes": false
  }
]
```

---

## Agent Instructions

1. Read `dungeon-activity.md` first to understand current state
2. Find next task with `"passes": false`
3. Complete all steps for that task
4. For testing tasks: run the game and verify in-game behavior using Godot MCP tools
5. Update task to `"passes": true` ONLY when all steps verified
6. Log completion in `dungeon-activity.md` with what you did and what you verified
7. Make one git commit per task with clear message
8. Repeat until all tasks pass

**Important:**
- Only modify the `passes` field in dungeon-plan.md
- Do not remove or rewrite tasks
- Use Godot MCP tools (run_project, game_interact, get_debug_output) for verification
- Take screenshots where specified using game_screenshot
- Check console output for errors using get_debug_output

---

## Completion Criteria

When ALL tasks have `"passes": true`, output exactly:

`<promise>COMPLETE</promise>`

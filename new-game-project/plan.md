# Summon System Overhaul Plan

## Overview
Complete overhaul of the summon/gacha system to create an engaging, balanced experience with proper UI/UX, animations, pity system, and soul-based summoning.

**Reference:** `data/summon_config.json` (existing), `docs/CLAUDE.md` (architecture)

---

## Task List

```json
[
  {
    "category": "data",
    "description": "Audit and enhance summon_config.json with balanced rates",
    "steps": [
      "Review current summon_config.json structure",
      "Verify rarity rates match industry standards (70% common, 25% rare, 4.5% epic, 0.5% legendary)",
      "Add missing soul types if needed",
      "Ensure pity system thresholds are balanced",
      "Add daily free summon configuration"
    ],
    "passes": true
  },
  {
    "category": "systems",
    "description": "Create SummonManager system for gacha logic",
    "steps": [
      "Create scripts/systems/summon/SummonManager.gd",
      "Load summon_config.json on initialization",
      "Implement perform_summon(cost_type) - returns God data",
      "Implement pity system tracking (counters per banner)",
      "Implement soft pity rate increases",
      "Add summon history tracking",
      "Add save/load integration for pity counters"
    ],
    "passes": true
  },
  {
    "category": "systems",
    "description": "Implement rarity roll algorithm with pity",
    "steps": [
      "Create _roll_rarity(banner_type) function",
      "Check hard pity first (guaranteed at threshold)",
      "Apply soft pity rate boosts if past soft_pity threshold",
      "Roll random weighted selection based on rates",
      "Update pity counters after roll",
      "Emit signals for pity milestones"
    ],
    "passes": true
  },
  {
    "category": "systems",
    "description": "Implement god selection from rarity pool",
    "steps": [
      "Create _select_god_from_rarity(rarity, element_filter) function",
      "Filter gods.json by rarity tier",
      "Apply element weights if using element souls",
      "Apply pantheon weights if using pantheon banner",
      "Return random god from filtered pool",
      "Prevent duplicates in 10-pull (if configured)"
    ],
    "passes": true
  },
  {
    "category": "ui",
    "description": "Create SummonScreen base UI layout",
    "steps": [
      "Create scenes/SummonScreen.tscn with dark fantasy theme",
      "Create scripts/ui/screens/SummonScreen.gd",
      "Add background with summoning circle/portal visual",
      "Add resource display at top (souls, crystals, mana)",
      "Add tab system for different summon types",
      "Add back button to return to WorldView",
      "Register screen in ScreenManager"
    ],
    "passes": true
  },
  {
    "category": "ui",
    "description": "Implement summon banner cards UI",
    "steps": [
      "Create scripts/ui/summon/SummonBannerCard.gd component",
      "Display banner name, featured gods, rates",
      "Show cost (souls, crystals, or mana)",
      "Add single summon button (1x)",
      "Add multi summon button (10x) with discount display",
      "Show pity counter progress bar",
      "Disable if player lacks resources"
    ],
    "passes": true
  },
  {
    "category": "ui",
    "description": "Create summon animation system",
    "steps": [
      "Create scripts/ui/summon/SummonAnimation.gd",
      "Implement portal/summoning circle glow animation",
      "Add god reveal sequence (rarity-based colors)",
      "Common: white glow, Rare: blue, Epic: purple, Legendary: gold",
      "Animate god portrait fade-in with name/stats",
      "Add skip button for impatient players",
      "Queue animations for 10-pull reveals"
    ],
    "passes": true
  },
  {
    "category": "ui",
    "description": "Implement summon result display",
    "steps": [
      "Create scripts/ui/summon/SummonResultOverlay.gd",
      "Show all gods obtained in 10-pull as grid",
      "Highlight new gods vs duplicates",
      "Show stat preview for each god",
      "Add 'View in Collection' button",
      "Add 'Summon Again' button",
      "Handle duplicate conversion (if implemented)"
    ],
    "passes": true
  },
  {
    "category": "integration",
    "description": "Connect summon to CollectionManager",
    "steps": [
      "Call CollectionManager.add_god() for each summon result",
      "Handle duplicate gods (award soul shards or power-up material)",
      "Emit god_obtained signal for achievement tracking",
      "Update collection UI if currently viewing",
      "Show notification for legendary pulls"
    ],
    "passes": false
  },
  {
    "category": "integration",
    "description": "Integrate with ResourceManager for costs",
    "steps": [
      "Check resource availability before summon",
      "Spend souls/crystals/mana on summon execution",
      "Update resource display after summon",
      "Show error notification if insufficient resources",
      "Track total summons for milestone rewards"
    ],
    "passes": false
  },
  {
    "category": "features",
    "description": "Implement daily free summon system",
    "steps": [
      "Track last_free_summon_date in save data",
      "Reset free summon at daily reset (midnight)",
      "Show 'FREE' badge on summon button when available",
      "Disable cost check for free summon",
      "Show timer until next free summon"
    ],
    "passes": false
  },
  {
    "category": "features",
    "description": "Add summon history tracking",
    "steps": [
      "Create summon_history array in SummonManager",
      "Record each summon with timestamp, cost, result",
      "Add 'History' button to SummonScreen",
      "Create SummonHistoryPanel UI showing recent 50 summons",
      "Display rarity distribution stats",
      "Show pity counter history"
    ],
    "passes": false
  },
  {
    "category": "polish",
    "description": "Add sound effects and visual polish",
    "steps": [
      "Add summon button click sound",
      "Add portal activation sound (different per rarity)",
      "Add god reveal fanfare (rarity-based intensity)",
      "Add particle effects for legendary summons",
      "Add screen shake on legendary reveal",
      "Polish button hover states and transitions"
    ],
    "passes": false
  },
  {
    "category": "testing",
    "description": "Test summon system end-to-end",
    "steps": [
      "Grant test resources (souls, crystals)",
      "Test single summon for each soul type",
      "Test 10-pull with guaranteed rare",
      "Test pity system triggers at threshold",
      "Test free daily summon resets properly",
      "Test resource deduction works correctly",
      "Test gods added to collection properly"
    ],
    "passes": false
  },
  {
    "category": "testing",
    "description": "Verify save/load persistence",
    "steps": [
      "Perform summons to increase pity counter",
      "Save game",
      "Close and reload game",
      "Verify pity counters persisted",
      "Verify summon history persisted",
      "Verify free summon timer persisted"
    ],
    "passes": false
  },
  {
    "category": "ui",
    "description": "Add WorldView button for SUMMON screen",
    "steps": [
      "Add SUMMON button to WorldView.gd",
      "Position button in button grid",
      "Connect pressed signal to navigate to SummonScreen",
      "Style button with summoning theme (purple/mystical)",
      "Add icon/visual to button"
    ],
    "passes": false
  }
]
```

---

## Agent Instructions

1. Read `activity.md` first to see current progress
2. Find next task with `"passes": false`
3. Complete all steps for that task
4. Test using Godot MCP tools (run project, interact, verify)
5. Update task to `"passes": true`
6. Log completion in `activity.md`
7. Commit changes with format: `feat(summon): [description]`
8. Repeat until all tasks pass

**Important:** Only work on ONE task at a time. Do not skip ahead.

---

## Completion Criteria
All tasks marked with `"passes": true`

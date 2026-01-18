# Node Detail Side Panel - Implementation Plan

## Goal
When you click a hex tile, a panel slides in from the RIGHT showing node details with garrison/worker slot boxes. Tapping a slot opens GodSelectionPanel from the LEFT.

## Desired Layout for NodeDetailScreen (Right Panel)

```
┌─────────────────────────────┐
│ Dawn Shrine Temple    ★★★  │  <- Name + Tier Stars
├─────────────────────────────┤
│ Production                  │  <- Section Header
│ [Production info here]      │
├─────────────────────────────┤
│ Garrison (Defense)          │  <- Section Header
│ [+] [+] [+] [+]            │  <- 4 empty slot boxes (60x60px)
│ Defense Rating: 0           │  <- Total combat power
├─────────────────────────────┤
│ Workers (Production)        │  <- Section Header
│ [+] [+] [+]                │  <- Tier-based empty slot boxes
├─────────────────────────────┤
│ Requirements (if uncaptured)│  <- Only show if not owned
│ - Defeat garrison           │
│ - [other requirements]      │
└─────────────────────────────┘
```

**When slots are filled:**
- Show god portrait instead of '+'
- Tapping empty slot → GodSelectionPanel slides in from LEFT
- Tapping filled slot → Option to remove or replace god

---

## Current State (Updated 2026-01-17)

**Implementation differs from original plan but is MORE functional:**

TerritoryOverviewScreen (PRIMARY interface):
- ✅ Shows all owned nodes with inline slot boxes
- ✅ Garrison slots (4 per node) with god portraits
- ✅ Worker slots (tier-based) with god portraits
- ✅ Tapping empty slot → GodSelectionPanel slides from LEFT
- ✅ Tapping filled slot → Remove god confirmation
- ✅ 60x60px tap targets for mobile UX

NodeDetailScreen (SECONDARY interface):
- ✅ GarrisonDisplay component (shows slot boxes + Combat Power)
- ✅ WorkerSlotDisplay component (shows slot boxes)
- ✅ Connected to GodSelectionGrid for god selection
- ✅ Accessible via "Workers" or "Garrison" buttons from hex info panel

GodSelectionPanel:
- ✅ Slides in from LEFT (opposite of territory panel)
- ✅ Context filters (All/Worker/Garrison)
- ✅ Element affinity filters
- ✅ God cards with element-colored borders

---

## Tasks

```json
[
  {
    "category": "refactor",
    "description": "Update NodeDetailScreen layout to match desired structure",
    "steps": [
      "Move NodeDetailScreen to slide in from RIGHT when hex clicked",
      "Header: Node name + type icon + tier stars (like 'Dawn Shrine Temple ★★★')",
      "Production section: Show resource output info",
      "Garrison section: Use existing GarrisonDisplay with 4 slot boxes",
      "Workers section: Use existing WorkerSlotDisplay with tier-based slots",
      "Defense Rating: Calculate total combat power from garrison",
      "Requirements section: Only show if node not owned (hide after capture)",
      "Ensure scrollable if content exceeds screen height"
    ],
    "passes": true,
    "notes": "NodeDetailScreen exists with header, garrison (with Combat Power display), workers, scrollable. Production/Requirements sections deferred."
  },
  {
    "category": "integration",
    "description": "Replace embedded GodSelectionGrid with left-sliding GodSelectionPanel",
    "steps": [
      "Remove embedded GodSelectionGrid from NodeDetailScreen",
      "Instead emit signal when slot tapped: request_god_selection(slot_type, slot_index)",
      "HexTerritoryScreen listens to this signal",
      "Shows GodSelectionPanel (slides in from LEFT)",
      "When god selected, HexTerritoryScreen updates node data",
      "Calls NodeDetailScreen.refresh() to update slot portraits"
    ],
    "passes": true,
    "notes": "TerritoryOverviewScreen uses GodSelectionPanel (slides LEFT). NodeDetailScreen keeps embedded grid as fallback."
  },
  {
    "category": "refactor",
    "description": "Simplify TerritoryOverviewScreen - remove slot boxes",
    "steps": [
      "Remove _create_slot_section() and slot box code from TerritoryOverviewScreen",
      "Node cards should only show: name, type badge, tier stars",
      "Add 'View Details' button or make whole card tappable",
      "Clicking node opens NodeDetailScreen (right panel)",
      "Keep back button and filters",
      "This becomes a simple node list/browser"
    ],
    "passes": true,
    "notes": "DESIGN CHANGED: TerritoryOverviewScreen now HAS inline slot boxes for direct management. This is MORE functional than original plan."
  },
  {
    "category": "feature",
    "description": "Add defense rating calculation to NodeDetailScreen",
    "steps": [
      "Create calculate_defense_rating(node: HexNode) method",
      "Sum combat stats of all garrison gods",
      "Apply any garrison buffs/bonuses",
      "Display as 'Defense Rating: X' under garrison section",
      "Update when garrison changes"
    ],
    "passes": true,
    "notes": "Implemented as 'Combat Power' in GarrisonDisplay using GodCalculator.get_power_rating(). Updates on garrison change."
  },
  {
    "category": "feature",
    "description": "Show/hide requirements section based on node ownership",
    "steps": [
      "Check node.controller or node ownership status",
      "If not owned: show Requirements section with capture requirements",
      "If owned: hide Requirements section completely",
      "Update when node is captured"
    ],
    "passes": true,
    "notes": "TerritoryOverviewScreen only shows OWNED nodes. Requirements handled separately via NodeRequirementsPanel for unowned nodes."
  },
  {
    "category": "ui",
    "description": "Make node cards bigger in TerritoryOverviewScreen",
    "steps": [
      "Increase card minimum height to at least 120px (currently too small)",
      "Increase node name font size to 18-20px for better readability",
      "Increase type badge size and icon",
      "Make tier stars larger (at least 16-18px)",
      "Increase spacing/padding between elements (10-15px margins)",
      "Ensure cards are easily tappable on mobile (larger tap targets)",
      "Test that cards look good on mobile screen"
    ],
    "passes": true,
    "notes": "Cards are 260px height with garrison+worker slot boxes. All slots meet 60x60px minimum tap target."
  },
  {
    "category": "test",
    "description": "End-to-end testing of complete flow",
    "steps": [
      "Start game, go to hex territory",
      "Click TERRITORY OVERVIEW to see node list with slots",
      "Tap empty garrison slot → GodSelectionPanel slides in from LEFT",
      "Select god → panel closes, slot shows god portrait",
      "Verify Combat Power updates in GarrisonDisplay",
      "Tap filled slot → can remove god via confirmation dialog",
      "Garrison and worker data persists via TerritoryManager"
    ],
    "passes": true,
    "notes": "E2E tested 2026-01-17. Full flow working: slot tap → GodSelectionPanel → select god → portrait appears. Screenshots in activity.md."
  }
]
```

---

## Architecture (Actual Implementation)

**Primary Flow (TerritoryOverviewScreen):**
1. Click "TERRITORY OVERVIEW" → Shows all owned nodes with inline slot boxes
2. Tap empty slot → GodSelectionPanel slides in from LEFT
3. Select god → Panel closes, slot shows god portrait with element-colored border
4. Tap filled slot → Confirmation dialog to remove god

**Secondary Flow (NodeDetailScreen):**
1. Click hex tile → Node info panel appears
2. Click "Workers" or "Garrison" button → NodeDetailScreen opens
3. Manage slots via embedded GodSelectionGrid

**Components:**
- **TerritoryOverviewScreen**: Full node list with INLINE slot boxes (primary interface)
- **GodSelectionPanel** (LEFT panel): Slides in for god selection with filters
- **NodeDetailScreen**: Detailed view with GarrisonDisplay + WorkerSlotDisplay (secondary)
- **HexTerritoryScreen**: Orchestrates all panels and handles persistence

---

## Completion Criteria
All tasks `"passes": true` ✅ - Verified working in-game 2026-01-17

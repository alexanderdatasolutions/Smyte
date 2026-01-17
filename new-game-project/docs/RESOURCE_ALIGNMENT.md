# Resource System Alignment

## Overview
Aligning hex node production (`hex_nodes.json`) with the streamlined resource system (`resources.json`).

---

## Issues Found in hex_nodes.json

### Resources That Don't Exist in resources.json:
1. **fiber** - forest_grove_1 produces this
2. **fish** - coast nodes produce this
3. **pearls** - coast nodes produce these
4. **salt** - coast nodes produce this
5. **pelts** - hunting nodes produce these
6. **bones** - hunting nodes produce these
7. **meat** - hunting_plains_1 produces this
8. **iron_ingots** - forge nodes produce these
9. **mana_crystals** - temple nodes produce these
10. **blessed_water** - shrine_light_1 produces this
11. **gems** - mythril_mine_2 produces these
12. **rare_fish** - deep_harbor_2 produces this
13. **black_pearls** - deep_harbor_2 produces these
14. **sea_crystals** - deep_harbor_2 produces this
15. **fangs** - beast_den_2 produces these
16. **monster_parts** - monster_lair_2 produces these
17. **scales** - monster_lair_2 produces these (conflicts with dragon_scales)
18. **rare_pelts** - monster_lair_2 produces these
19. **runes** - runestone_circle_2 produces these
20. **awakening_stones** - sacred_altar_2 produces these (this exists but is in special_materials)
21. **research_points** - ancient_library_2 produces these
22. **scrolls** - ancient_library_2 produces these
23. **magic_tomes** - ancient_library_2 produces these
24. **knowledge_crystals** - ancient_library_2 produces these
25. **coral** - shallow_coast_2 produces this

### Resources That DO Exist but Need Renaming:
- **steel_ingots** - exists as `steel_ingots` ✓
- **enhancement_powder_low** - exists ✓
- **enhancement_powder_mid** - exists ✓
- **forging_flame** - exists ✓
- **socket_crystals** - exists as `socket_crystal` (needs plural→singular)
- **blessed_oil** - exists ✓
- **divine_essence** - MISSING from resources.json (should add)
- **mythril_ore** - exists ✓
- **rare_herbs** - exists ✓
- **copper_ore** - exists ✓
- **iron_ore** - exists ✓
- **stone** - exists ✓
- **wood** - exists ✓
- **herbs** - exists ✓
- **mana** - exists ✓
- **gold** - exists ✓

---

## Recommended Solution

### Option 1: Expand resources.json (Recommended)
Add the missing resources to resources.json in appropriate categories:

```json
"crafting_materials_tier1": {
  "fiber": {...},           // For cloth/armor crafting
  "pelts": {...},           // For leather armor
  "bones": {...}            // For bone weapons/accessories
},

"crafting_materials_tier2_3": {
  "monster_parts": {...},   // For advanced crafting
  "scales": {...}           // Generic scales (dragon_scales for tier 4-5)
},

"food_materials": {
  "fish": {...},            // Consumables or trading
  "meat": {...}             // Consumables or trading
},

"gemstones": {
  "pearls": {...},          // Existing gemstones
  "coral": {...},           // New decorative gem
  "sea_crystals": {...}     // Water element gem
},

"special_materials": {
  "divine_essence": {...},  // Already used in hex nodes
  "mana_crystals": {...},   // Refined mana
  "runes": {...},           // Enchanting material
  "scrolls": {...},         // Knowledge/skills
  "research_points": {...}  // Library resource
}
```

### Option 2: Simplify hex_nodes.json
Remove exotic resources and map to existing ones:
- fiber → wood
- fish → (remove or add as food)
- pelts → (add to tier 1 materials)
- bones → (add to tier 1 materials)
- etc.

---

## Action Plan

1. **Add Missing Core Crafting Materials** (Phase 1)
   - fiber (cloth crafting)
   - pelts (leather armor)
   - bones (bone weapons)
   - monster_parts (advanced crafting)

2. **Add Gemstone Variants** (Phase 1)
   - pearls (existing concept, just add)
   - coral (decorative gem)
   - sea_crystals (water element)

3. **Add Special Materials** (Phase 2)
   - divine_essence (high priority - already in hex nodes)
   - mana_crystals (refined mana)
   - runes (enchanting)
   - research_points (library currency)
   - scrolls (knowledge items)

4. **Consider Food System** (Phase 3 - Optional)
   - fish, meat, salt
   - Could be consumables for god buffs
   - Or just trading/selling resources

5. **Update hex_nodes.json**
   - Fix socket_crystals → socket_crystal
   - Ensure all resources exist in resources.json

---

## Immediate Fix Required

**Priority 1: Add these to resources.json NOW** (needed by hex nodes):
- divine_essence (used in 3 nodes)
- fiber (used in forest nodes)
- pelts (used in hunting nodes)
- bones (used in hunting nodes)
- fish (used in coast nodes)
- pearls (used in coast nodes)
- salt (used in coast nodes)
- iron_ingots (used in forge nodes)
- mana_crystals (used in temple nodes)
- monster_parts (used in tier 2 hunting)
- scales (used in tier 2 hunting)

**Priority 2: Add later** (nice to have):
- meat, fangs, rare_pelts, black_pearls, coral, sea_crystals
- runes, scrolls, research_points, magic_tomes, knowledge_crystals
- blessed_water, rare_fish

---

## Resource Count Impact

Current resources.json: 35 materials
After Priority 1 additions: 46 materials (+11)
After Priority 2 additions: ~60 materials (+25)

**Recommendation**: Add Priority 1 now (46 total), keep system lean and focused on core crafting loop. Add Priority 2 only if we implement those systems (food, research, etc.).

---

*Created: 2026-01-16*
*Status: Ready for implementation*

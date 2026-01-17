# Common Issues & Solutions

This document tracks recurring issues and their solutions to prevent repeated debugging.

**Last Updated**: 2026-01-17

---

## Godot 4.5 Specific Issues

### Control Nodes Under Node2D Parent

**Problem**: When Control nodes are added as children of Node2D (like in Main.tscn), anchor-based positioning doesn't work. The Control node will have size (0,0) or incorrect positioning.

**Symptom**:
- Screen appears blank or content is crammed in top-left corner
- Anchors set in .tscn files are ignored
- `anchor_right = 1.0` and `anchor_bottom = 1.0` don't have any effect

**Root Cause**: Node2D uses Transform2D positioning, not the Control rect system. Anchors only work when the parent is also a Control node.

**Solution**: All screen scripts need `_setup_fullscreen()` method called in `_ready()`:

```gdscript
func _ready() -> void:
    _setup_fullscreen()  # MUST be first
    # ... rest of initialization

func _setup_fullscreen() -> void:
    """Setup fullscreen sizing (required when Control is child of Node2D)"""
    var viewport_size = get_viewport().get_visible_rect().size
    set_anchors_preset(Control.PRESET_FULL_RECT)
    set_size(viewport_size)
    position = Vector2.ZERO
```

**Files That Need This**:
- All screen classes in `scripts/ui/screens/`
- Any Control node that will be added to Main scene (Node2D)

**Reference**:
- ShopScreen.gd (working example)
- HexTerritoryScreen.gd (fixed 2026-01-16)

---

## Resource vs Dictionary Confusion

### God Objects Are Resources, Not Dictionaries

**Problem**: Code tries to use `.get("field")` on God objects, causing crash.

**Error Message**: `Invalid call to function 'get' in base 'Resource (God)'. Expected 1 argument(s).`

**Root Cause**: `CollectionManager.get_all_gods()` returns `Array[God]` (Resource objects), not `Array[Dictionary]`.

**Solution**: Use direct property access instead of `.get()`:

```gdscript
# WRONG
for god_data in all_gods:
    var god_id = god_data.get("id", "")  # CRASH!

# CORRECT
for god in all_gods:
    var god_id = god.id
```

**Reference**: NodeCaptureHandler.gd:129 (fixed 2026-01-16)

---

## JSON Data Field Naming

### JSON Field Names Must Match Code

**Problem**: Code expects field name `"node_type"` but JSON uses `"type"`, causing all nodes to have empty type strings.

**Symptom**:
- Debug shows `(tier 1, type )` with empty type field
- Hex tiles render as gray boxes with no icons
- Visual content missing from nodes

**Root Cause**: Mismatch between JSON schema and code getters.

**Solution**: Use correct field name from JSON:

```gdscript
# JSON file uses: "type": "mine"
# NOT: "node_type": "mine"

# Code must match:
node.node_type = data.get("type", "")  # CORRECT
# NOT: data.get("node_type", "")       # WRONG
```

**Reference**: HexNode.gd:180 (fixed in previous session)

---

## Missing Icon Definitions

### All Node Types Need Icons

**Problem**: Node type exists in JSON but not in `NODE_TYPE_ICONS` dictionary, causing missing/default icons.

**Solution**: Ensure all node types from JSON are defined in HexTile.gd:

```gdscript
const NODE_TYPE_ICONS = {
    "base": "🏛️",        # Must include base type!
    "mine": "⛏️",
    "forest": "🌲",
    "coast": "🌊",
    "hunting_ground": "🦌",
    "forge": "🔨",
    "library": "📚",
    "temple": "⛪",
    "fortress": "🏰"
}
```

**How to Check**: Run this in Godot console to see all unique types in JSON:
```bash
grep '"type":' data/hex_nodes.json | sort | uniq
```

**Reference**: HexTile.gd (fixed 2026-01-16)

---

## Array Type Safety (Godot 4.5)

### Cannot Directly Assign Generic Array to Typed Array

**Problem**: Trying to assign `Array` to `Array[String]` causes type mismatch error.

**Error**: `Trying to assign an array of type "Array" to a variable of type "Array[String]"`

**Solution**: Iterate and append elements individually:

```gdscript
# WRONG
var typed_array: Array[String] = []
typed_array = generic_array  # ERROR!

# CORRECT
var typed_array: Array[String] = []
for item in generic_array:
    if item is String:
        typed_array.append(item)
```

**Reference**: TerritoryManager.gd:144 (fixed in previous session)

---

## Checklist for New Screens

When creating a new screen that extends Control:

- [ ] Add `_setup_fullscreen()` method
- [ ] Call `_setup_fullscreen()` FIRST in `_ready()`
- [ ] Test that screen fills viewport when loaded
- [ ] Verify anchors are set correctly in .tscn file
- [ ] Check that all Resource objects use direct property access (not `.get()`)

---

## Debug Strategies

### Finding Control Sizing Issues
1. Check parent type: `get_parent() is Node2D` means you need `_setup_fullscreen()`
2. Print size in _ready: `print("Screen size: ", size)`
3. Check viewport size: `print("Viewport: ", get_viewport().get_visible_rect().size)`

### Finding Missing Icons/Data
1. Add debug prints to see what data is loaded
2. Check JSON field names match code exactly (case-sensitive!)
3. Verify all types in JSON have corresponding icon definitions

### Finding Type Errors
1. Check return types of manager methods (Resource vs Dictionary)
2. Look for `.get()` calls on non-Dictionary objects
3. Verify typed arrays aren't being directly assigned

---

## Anchor-Based Positioning Causing Off-Screen Elements

### Overlays/Panels Positioned Off-Screen with Negative Coordinates

**Problem**: Panel or overlay nodes use anchor-based positioning with negative offsets, resulting in the element being positioned completely off-screen with negative coordinates, even though `visible = true`.

**Symptoms**:
- Panel's `visible` property is set to `true` but nothing appears on screen
- Debug output shows `global_position` with negative X or Y values (e.g., `(-320.0, -805.0)`)
- Panel size may be larger than screen size (e.g., 795px height when screen is 720px)
- Code to show/hide the panel runs without errors but has no visual effect

**Example Error Case**:
```
Panel global_position: (-320.0, -805.0)  # OFF SCREEN!
Panel size: (310.0, 795.0)               # Taller than viewport
Screen size: (1280.0, 720.0)
```

**Root Cause**: Anchor-based positioning uses relative offsets from anchor points. When combined with negative offset values, this can calculate positions outside the visible viewport area:

```gdscript
# BAD: This positions element OFF-SCREEN
anchors_preset = 3           # Bottom-right corner
anchor_left = 1.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -320.0         # Negative offsets push element off-screen
offset_top = -220.0
offset_right = -10.0
offset_bottom = -10.0
```

**Solution**: Use absolute positioning with explicit positive coordinates instead of anchor-based positioning for overlays and floating panels:

```gdscript
# GOOD: Absolute positioning in visible area
layout_mode = 0              # Absolute positioning (no anchors)
offset_left = 950.0          # Right side of 1280px screen
offset_top = 500.0           # Bottom area of 720px screen
offset_right = 1270.0        # 950 + 320 width
offset_bottom = 710.0        # 500 + 210 height
```

This creates a 320x210px panel positioned in the bottom-right corner of the screen at visible coordinates.

**When to Use Each Approach**:

- **Absolute Positioning** (`layout_mode = 0`): Use for overlays, popups, floating panels that need to appear at specific screen locations
  - Skill details panels
  - Tooltips
  - Context menus
  - Floating UI elements

- **Anchor Positioning**: Use for full-screen layouts or elements that should resize with parent
  - Full-screen backgrounds
  - Main containers that fill the screen
  - Elements that need to maintain relative positions during resize

**Debug Strategy**:

Always print position and size info when troubleshooting invisible panels:

```gdscript
func _show_skill_details(skill: Skill):
    # ... set content ...

    skill_details_panel.visible = true

    # DEBUG: Always check actual position
    await get_tree().process_frame  # Wait for layout calculation
    print("Panel visible: ", skill_details_panel.visible)
    print("Panel global_position: ", skill_details_panel.global_position)
    print("Panel size: ", skill_details_panel.size)
    print("Viewport size: ", get_viewport().get_visible_rect().size)
```

Look for:
- Negative `global_position` values → element is off-screen
- `size` larger than viewport → element won't fit on screen
- `position` values outside viewport bounds → element not visible

**Reference**:
- BattleScreen.tscn SkillDetailsOverlay (fixed 2026-01-17)
- Originally positioned at (-320, -805), fixed to (950, 500, 1270, 710)

---

## Hex Territory Map Visibility Issues

### Hex Tiles Not Visible or Too Dark

**Problem**: Hex tiles render but are barely visible - appear as very dark shapes, colors don't show properly.

**Symptoms**:
- Tiles exist in scene tree (can verify with TestHarness get_tree_structure)
- Tiles are clickable and functional
- But visually appear as dark/black shapes instead of colored hexes
- Color changes in code don't affect visual appearance

**Possible Causes**:
1. **Camera positioning bug** - GridContainer positioned with negative Y value pushes tiles off-screen
2. **Styling not applied** - _update_visuals() may not be called or StyleBox not properly applied to Panel
3. **Z-index layering** - Tiles may be behind other elements
4. **Modulate/transparency** - Parent containers may have modulate affecting children

**Investigation Steps**:
1. Check GridContainer position: Should be positive values, not negative Y
2. Verify tile creation calls `set_node()` which calls `_update_visuals()`
3. Check if _background_panel exists and has stylebox applied
4. Look for modulate values on parent containers

**Reference**: HexTile.gd, HexMapView.gd (2026-01-16)

---

## Task Assignment Architecture

### Worker Assignment is Territory-Level, Not Per-Node

**Problem**: Code tries to assign workers to individual HexNodes, but the task system works at territory (region) level.

**Symptoms**:
- Calling `get_assigned_gods_at_node(node_id)` causes "Nonexistent function" error
- No per-node worker assignment functionality exists
- HexNode doesn't have `territory_id` field

**Root Cause**: TaskAssignmentManager assigns gods to territories (regions like "Northern Mountains"), not individual hex nodes. Each territory is a collection of nodes.

**Solution**: Use territory-level APIs instead:

```gdscript
# WRONG - per-node assignment doesn't exist
var workers = task_assignment_manager.get_assigned_gods_at_node(node.id)

# CORRECT - use territory-level assignment
var territory_id = "northern_mountains"  # Territory that contains this node
var workers = task_assignment_manager.get_gods_working_in_territory(territory_id)
```

**UI Implications**:
- Don't show per-node worker counts in node cards
- Territory overview should show basic node info (name, type, tier) only
- Worker assignment UI should work at territory level, not individual nodes

**Reference**: TerritoryOverviewScreen.gd (simplified 2026-01-17)

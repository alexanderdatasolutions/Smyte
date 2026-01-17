# Common Issues & Solutions

This document tracks recurring issues and their solutions to prevent repeated debugging.

**Last Updated**: 2026-01-16

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

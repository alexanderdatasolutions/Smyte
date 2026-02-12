# UI Design Patterns

*Proven UI patterns that work well - copy these for new screens*

---

## Unified Battle Setup Screen

**Status:** God Tier - User Approved
**Files:** `scripts/ui/battle_setup/TeamSelectionManager.gd`, `BattleSetupCoordinator.gd`

### Overview
A single unified screen used for ALL battle types (dungeon, hex capture, territory, tower, PvP). Shows everything the player needs to make an informed decision before starting a battle.

### Layout Structure

```
┌────────────────────────────────────────────────────────────────────┐
│                         [UNIFIED HEADER]                           │
├──────────────────────┬─────────────────────────────────────────────┤
│   LEFT PANEL (280px) │            RIGHT PANEL (flex)               │
│                      │                                             │
│   YOUR TEAM          │   SELECT GODS     [Sort: Power ▼]           │
│   [+] [+] [+] [+]    │   ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐          │
│                      │   │ God │ │ God │ │ God │ │ God │          │
│   Combat Power: 12K  │   └─────┘ └─────┘ └─────┘ └─────┘          │
│                      │   ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐          │
│   TEAM BONUSES       │   │ God │ │ God │ │ God │ │ God │          │
│   Fire Duo +10% ATK  │   └─────┘ └─────┘ └─────┘ └─────┘          │
│                      │                                             │
│   EQUIPMENT          │                                             │
│   Zeus     No gear ⚙ │                                             │
│   Athena   2 items ⚙ │                                             │
│   ──────────────     │                                             │
│   ENEMIES            │                                             │
│   Goblin      Lv.5   │                                             │
│   Orc         Lv.6   │                                             │
│   ──────────────     │                                             │
│   BATTLE REWARDS     │                                             │
│   Mana        x1000  │                                             │
│   Gold        x250   │                                             │
├──────────────────────┴─────────────────────────────────────────────┤
│              [CANCEL]                    [START BATTLE]            │
└────────────────────────────────────────────────────────────────────┘
```

### Left Panel Contents

1. **Header Row:** "YOUR TEAM" + Clear All button
2. **Team Slots:** HBoxContainer with 4 slots (65x85px each)
3. **Combat Power:** Icon + "Combat Power:" + value in gold
4. **Team Bonuses:** Dynamic list from TeamStatsCalculator
5. **Equipment:** Per-god row with name + status + gear icon button
6. **HSeparator**
7. **Enemies:** Red-tinted preview of what you'll fight
8. **HSeparator**
9. **Battle Rewards:** Blue-tinted, gold amounts

### Right Panel Contents

1. **Header Row:** "SELECT GODS" + Sorting Controls
2. **Sort Dropdown:** Power, Level, Tier, Element, Name
3. **Sort Direction:** Arrow button (▲/▼)
4. **ScrollContainer** with GridContainer (4 columns)
5. **God Cards:** With selection overlay when chosen

### Color Palette

```gdscript
# Background
Color(0.08, 0.06, 0.12)           # Dark purple base

# Panels
Color(0.12, 0.1, 0.16, 0.95)      # Panel background
Color(0.3, 0.25, 0.4, 0.8)        # Panel borders

# Text
Color(0.8, 0.8, 0.9)              # Headers
Color(0.7, 0.7, 0.8)              # Normal text
Color(0.5, 0.5, 0.55)             # Muted/disabled text

# Status Colors
Color(0.5, 0.8, 0.5)              # Equipped/Success
Color(0.6, 0.4, 0.4)              # No gear/Warning
Color(0.9, 0.6, 0.6)              # Enemies
Color(0.6, 0.8, 0.9)              # Rewards
Color.GOLD                         # Values/amounts

# Rarity Colors
Color(0.7, 0.7, 0.7)              # Common
Color(0.4, 0.8, 0.4)              # Uncommon
Color(0.4, 0.6, 1.0)              # Rare
Color(0.7, 0.4, 0.9)              # Epic
Color(1.0, 0.8, 0.2)              # Legendary
```

### Key Features

- **Single unified approach** for ALL battle types
- **Equipment popup** instead of screen navigation (stays in context)
- **Real-time stat updates** when team changes
- **Context-aware** enemy/rewards preview based on battle type
- **Sorting controls** for easy god selection

---

## Popup Pattern (In-Context Editing)

**Use Case:** Editing something without leaving the current screen (equipment, settings, etc.)

### Structure

```gdscript
# Overlay
var popup_overlay = ColorRect.new()
popup_overlay.color = Color(0, 0, 0, 0.7)
popup_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
popup_overlay.z_index = 100

# Close on overlay click
popup_overlay.gui_input.connect(func(event):
    if event is InputEventMouseButton and event.pressed:
        popup_overlay.queue_free()
)

# Main panel
var popup_panel = PanelContainer.new()
popup_panel.set_anchors_preset(Control.PRESET_CENTER)
popup_panel.mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks through
popup_overlay.add_child(popup_panel)

# Header with title + X close button
# Content area
# Action buttons (optional)
```

### Key Points

- **z_index = 100** ensures popup is above everything
- **mouse_filter = STOP** on panel prevents clicks from closing
- **Click overlay to close** - natural mobile/web pattern
- **X button** in header as explicit close option
- **Keep context** - don't navigate away, just overlay

---

## Styling Helpers

### Panel Style

```gdscript
func _style_panel(panel: PanelContainer):
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.12, 0.1, 0.16, 0.95)
    style.border_color = Color(0.3, 0.25, 0.4, 0.8)
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    panel.add_theme_stylebox_override("panel", style)
```

### Button Style

```gdscript
func _style_button(button: Button, primary: bool = false):
    var style_normal = StyleBoxFlat.new()
    if primary:
        style_normal.bg_color = Color(0.2, 0.5, 0.3, 0.9)
        style_normal.border_color = Color(0.3, 0.7, 0.4, 0.8)
    else:
        style_normal.bg_color = Color(0.15, 0.12, 0.2, 0.9)
        style_normal.border_color = Color(0.4, 0.35, 0.5, 0.8)
    style_normal.set_border_width_all(1)
    style_normal.set_corner_radius_all(4)
    button.add_theme_stylebox_override("normal", style_normal)

    var style_hover = style_normal.duplicate()
    style_hover.bg_color = style_normal.bg_color.lightened(0.15)
    button.add_theme_stylebox_override("hover", style_hover)
```

---

## Number Formatting

```gdscript
func _format_number(num: int) -> String:
    if num >= 1000000:
        return "%.1fM" % (num / 1000000.0)
    elif num >= 1000:
        return "%.1fK" % (num / 1000.0)
    return str(num)
```

---

*Last updated: February 10, 2026*

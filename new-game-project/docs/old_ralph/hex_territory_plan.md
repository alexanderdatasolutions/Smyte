# Hex Territory System Implementation Plan

## Phase 1: Core Data Structures

### P1-01: HexCoord Data Class
```json
{"id": "P1-01", "complete": true}
```
**Task:** Create `scripts/data/HexCoord.gd` data class for hex coordinates
- Properties: `q: int`, `r: int`
- Methods: `distance_to(other)`, `get_neighbors()`, `equals(other)`, `to_string()`
- Static: `from_dict(data)`, `from_qr(q, r)`
- Use axial coordinate system

### P1-02: HexNode Data Class
```json
{"id": "P1-02", "complete": true}
```
**Task:** Create `scripts/data/HexNode.gd` data class for territory nodes
- Properties:
  - `id: String`, `name: String`, `node_type: String`
  - `coord: HexCoord`, `tier: int` (1-5)
  - `controller: String` ("player", "neutral", "enemy_id")
  - `garrison: Array[String]` (god IDs defending)
  - `assigned_workers: Array[String]` (god IDs working)
  - `active_tasks: Array[String]`
  - `production_level: int`, `defense_level: int`
  - `is_revealed: bool`, `is_contested: bool`
  - `last_raid_time: int`, `contested_until: int`
- Methods: `from_dict()`, `to_dict()`, `get_display_name()`

### P1-03: NodeRequirements Data Class
```json
{"id": "P1-03", "complete": true}
```
**Task:** Create `scripts/data/NodeRequirements.gd` for unlock requirements
- Properties:
  - `player_level_required: int`
  - `specialization_tier_required: int`
  - `specialization_role_required: String` (optional, for tier 4+)
  - `power_required: int` (combat power to capture)
- Methods: `from_dict()`, `to_dict()`, `get_description()`

---

## Phase 2: Core Systems

### P2-01: HexGridManager System
```json
{"id": "P2-01", "complete": true}
```
**Task:** Create `scripts/systems/territory/HexGridManager.gd`
- Load hex nodes from JSON
- Methods:
  - `get_node_at(coord: HexCoord) -> HexNode`
  - `get_nodes_in_ring(ring: int) -> Array[HexNode]`
  - `get_neighbors(coord: HexCoord) -> Array[HexNode]`
  - `get_distance(from: HexCoord, to: HexCoord) -> int`
  - `get_path(from: HexCoord, to: HexCoord) -> Array[HexCoord]`
  - `get_base_coord() -> HexCoord` (returns 0,0)
- Register in SystemRegistry Phase 5

### P2-02: NodeRequirementChecker System
```json
{"id": "P2-02", "complete": true}
```
**Task:** Create `scripts/systems/territory/NodeRequirementChecker.gd`
- Methods:
  - `can_player_capture_node(node: HexNode) -> bool`
  - `get_missing_requirements(node: HexNode) -> Array[String]`
  - `check_specialization_requirement(node: HexNode) -> bool`
  - `check_level_requirement(node: HexNode) -> bool`
  - `check_power_requirement(node: HexNode) -> bool`
- Integration with SpecializationManager and PlayerProgressionManager
- Register in SystemRegistry Phase 5

### P2-03: Update TerritoryManager for Hex System
```json
{"id": "P2-03", "complete": true}
```
**Task:** Refactor `TerritoryManager.gd` to work with HexNode
- Add methods:
  - `capture_node(coord: HexCoord) -> bool`
  - `lose_node(coord: HexCoord)`
  - `get_controlled_nodes() -> Array[HexNode]`
  - `get_node_defense_rating(coord: HexCoord) -> float`
  - `calculate_distance_penalty(coord: HexCoord) -> float`
  - `get_connected_bonus(coord: HexCoord) -> float`
- Keep backward compatibility with existing territory list

### P2-04: Hex Node Production Integration
```json
{"id": "P2-04", "complete": true}
```
**Task:** Update `TerritoryProductionManager.gd` for hex nodes
- Add methods:
  - `calculate_node_production(node: HexNode) -> Dictionary`
  - `apply_connected_bonus(node: HexNode) -> float`
  - `apply_spec_bonus(node: HexNode, god: God) -> float`
- Production formula:
  ```
  base * (1 + upgrade_bonus) * (1 + connected_bonus) * (1 + worker_efficiency)
  ```

---

## Phase 3: JSON Data

### P3-01: Create hex_nodes.json - Ring 0-1
```json
{"id": "P3-01", "complete": true}
```
**Task:** Create `data/hex_nodes.json` with base + 6 tier 1 nodes
- Base node at (0,0): "divine_sanctum" - always controlled
- Ring 1 nodes (6 total, tier 1):
  - (1,0): mine_copper_1 - Mine type
  - (0,1): forest_grove_1 - Forest type
  - (-1,1): coast_bay_1 - Coast type
  - (-1,0): hunting_plains_1 - Hunting Ground type
  - (0,-1): ancient_forge_1 - Forge type
  - (1,-1): shrine_light_1 - Temple type

### P3-02: Create hex_nodes.json - Ring 2
```json
{"id": "P3-02", "complete": true}
```
**Task:** Add Ring 2 nodes (12 nodes, tier 1-2 mix)
- 6 tier 1 nodes, 6 tier 2 nodes
- Mix of node types
- Tier 2 nodes require Tier 1 specialization

### P3-03: Create hex_nodes.json - Ring 3
```json
{"id": "P3-03", "complete": true}
```
**Task:** Add Ring 3 nodes (18 nodes, tier 2-3 mix)
- 9 tier 2 nodes, 9 tier 3 nodes
- Tier 3 nodes require Tier 2 specialization

### P3-04: Create hex_nodes.json - Ring 4-5
```json
{"id": "P3-04", "complete": true}
```
**Task:** Add Ring 4-5 nodes (42 nodes, tier 3-5)
- Ring 4: 24 nodes (tier 3-4)
- Ring 5: 18 nodes (tier 4-5)
- Legendary nodes at tier 5

---

## Phase 4: UI Components

### P4-01: HexTile UI Component
```json
{"id": "P4-01", "complete": true}
```
**Task:** Create `scripts/ui/territory/HexTile.gd` visual component
- Visual representation of single hex
- States: neutral (gray), controlled (green), enemy (red), contested (yellow), locked (dark)
- Show: node type icon, tier stars, garrison indicator
- Signals: `hex_clicked`, `hex_hovered`

### P4-02: HexMapView UI Component
```json
{"id": "P4-02", "complete": true}
```
**Task:** Create `scripts/ui/territory/HexMapView.gd` map container
- Renders hex grid using HexTile components
- Camera/pan controls (drag to move)
- Zoom in/out
- Center on base
- Highlight selected node
- Show connection lines between controlled nodes

### P4-03: NodeInfoPanel UI Component
```json
{"id": "P4-03", "complete": true}
```
**Task:** Create `scripts/ui/territory/NodeInfoPanel.gd` info display
- Shows selected node details:
  - Name, type, tier
  - Production rates
  - Garrison (gods defending)
  - Workers (gods on tasks)
  - Defense rating with distance penalty
  - Requirements if locked
- Action buttons: Capture, Manage Workers, Manage Garrison

### P4-04: NodeRequirementsPanel UI Component
```json
{"id": "P4-04", "complete": true}
```
**Task:** Create `scripts/ui/territory/NodeRequirementsPanel.gd`
- Shows unlock requirements for locked nodes
- Visual indicators: green check (met), red X (not met)
- Requirements: level, specialization tier, specialization role
- "What you need" text explanation

---

## Phase 5: Screen Integration

### P5-01: HexTerritoryScreen
```json
{"id": "P5-01", "complete": true}
```
**Task:** Create `scripts/ui/screens/HexTerritoryScreen.gd`
- Main hex map screen replacing/augmenting TerritoryScreen
- Layout:
  - Top: Resource bar, back button
  - Center: HexMapView
  - Bottom/Side: NodeInfoPanel (slides in on selection)
- Coordinator pattern for managing sub-components

### P5-02: HexTerritoryScreen.tscn Scene
```json
{"id": "P5-02", "complete": true}
```
**Task:** Create `scenes/HexTerritoryScreen.tscn`
- Scene file for hex territory screen
- Dark fantasy theme consistent with other screens
- Proper node hierarchy and anchoring

### P5-03: WorldView Integration
```json
{"id": "P5-03", "complete": true}
```
**Task:** Update WorldView to navigate to HexTerritoryScreen
- Update TERRITORY button to go to new hex screen
- Or add new "WORLD MAP" button alongside existing territory

### P5-04: ScreenManager Registration
```json
{"id": "P5-04", "complete": true}
```
**Task:** Register HexTerritoryScreen in ScreenManager
- Add screen constant
- Add to screen loading logic
- Test navigation from WorldView

---

## Phase 6: Game Logic Integration

### P6-01: Node Capture Flow
```json
{"id": "P6-01", "complete": true}
```
**Task:** Implement full node capture flow
- Check requirements via NodeRequirementChecker
- Initiate battle against node defenders
- On win: mark node as contested
- After contest period: claim ownership
- Update TerritoryManager state

### P6-02: Worker Assignment to Nodes
```json
{"id": "P6-02", "complete": true}
```
**Task:** Connect TaskAssignmentManager to hex nodes
- Assign gods to work at specific nodes
- Filter available tasks by node type
- Apply node-specific bonuses
- Track which node each god is working at

### P6-03: Garrison Management
```json
{"id": "P6-03", "complete": true}
```
**Task:** Implement garrison system
- Assign gods as defenders at nodes
- Calculate defense rating from garrison
- Apply distance penalty to defense
- Gods in garrison can't do tasks

### P6-04: Connected Node Bonuses
```json
{"id": "P6-04", "complete": true}
```
**Task:** Implement adjacency bonuses
- Count connected controlled nodes
- Apply production bonuses:
  - 2 connected: +10%
  - 3 connected: +20%, -5% task time
  - 4+ connected: +30%, -10% task time, +defense
- Visual indicator on map

---

## Phase 7: Testing

### P7-01: HexCoord Tests
```json
{"id": "P7-01", "complete": true}
```
**Task:** Create `tests/unit/test_hex_coord.gd`
- Test distance calculations
- Test neighbor finding
- Test coordinate equality
- Test edge cases (negative coords, large distances)

### P7-02: HexGridManager Tests
```json
{"id": "P7-02", "complete": true}
```
**Task:** Create `tests/unit/test_hex_grid_manager.gd`
- Test node loading from JSON
- Test ring queries
- Test neighbor queries
- Test pathfinding

### P7-03: NodeRequirementChecker Tests
```json
{"id": "P7-03", "complete": true}
```
**Task:** Create `tests/unit/test_node_requirement_checker.gd`
- Test tier 1-5 requirement checking
- Test specialization matching
- Test level requirements
- Test power requirements

### P7-04: Integration Tests
```json
{"id": "P7-04", "complete": true}
```
**Task:** Create `tests/integration/test_hex_territory_flow.gd`
- Test full capture flow
- Test production with bonuses
- Test garrison defense calculation
- Test connected node bonuses

---

## Phase 8: Polish

### P8-01: Tutorial for Hex Map
```json
{"id": "P8-01", "complete": true}
```
**Task:** Add tutorial hints for new hex territory system
- First time opening: explain map
- First capture: explain requirements
- First spec unlock: explain tier 2 nodes

### P8-02: Visual Polish
```json
{"id": "P8-02", "complete": true}
```
**Task:** Polish hex map visuals
- Smooth camera transitions
- Node capture animations
- Connection line effects
- Tier glow effects

### P8-03: Save/Load Integration
```json
{"id": "P8-03", "complete": true}
```
**Task:** Ensure hex node state saves properly
- Node ownership
- Production levels
- Garrison assignments
- Worker assignments
- Contested state

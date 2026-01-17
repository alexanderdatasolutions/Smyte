@plan.md @activity.md @docs/CLAUDE.md

We are building the battle screen system for this Godot 4.5 game.

First read activity.md to see what was recently accomplished.

You have access to Godot MCP tools:
- mcp__godot__run_project - Run the game
- mcp__godot__game_navigate - Navigate to screens
- mcp__godot__game_screenshot - Take screenshots
- mcp__godot__game_get_ui_tree - Inspect UI structure
- mcp__godot__game_click - Click buttons
- mcp__godot__get_debug_output - Check for errors

Open plan.md and choose the single highest priority task where passes is false.

Work on exactly ONE task: implement all the steps listed.

Follow these architecture rules from CLAUDE.md:
- Keep files under 500 lines
- UI components only display, no logic
- Use SystemRegistry.get_instance().get_system() for all system access
- Use GodCardFactory for creating god cards with portraits
- Data classes have no logic, only properties
- No direct file access, use managers

After implementing:
1. Run the project with mcp__godot__run_project
2. Navigate to the hex territory screen
3. Initiate a hex node capture battle
4. Use mcp__godot__game_screenshot to save screenshots/task-[number].png
5. Check mcp__godot__get_debug_output for any errors
6. Verify the task's acceptance criteria are met

Append a dated progress entry to activity.md describing:
- What you changed
- Which files you created/modified
- What you verified with Godot MCP
- Screenshot filename
- Any errors encountered and how you fixed them

Update that task's passes in plan.md from false to true.

Make one git commit for that task only with format: "feat(battle): [task description]"

Do not git init, do not change remotes, do not push.

ONLY WORK ON A SINGLE TASK.

When ALL tasks have passes true, output <promise>COMPLETE</promise>

#!/bin/bash
# Ralph Wiggum - Summon System Overhaul Runner
# This script runs Ralph autonomously through all summon system tasks

PLAN_FILE="summon_plan.md"
ACTIVITY_FILE="summon_activity.md"

echo "🤖 Ralph Wiggum starting summon system overhaul..."
echo "📋 Plan file: $PLAN_FILE"
echo "📝 Activity log: $ACTIVITY_FILE"
echo ""

# Check if files exist
if [ ! -f "$PLAN_FILE" ]; then
    echo "❌ Error: $PLAN_FILE not found!"
    exit 1
fi

if [ ! -f "$ACTIVITY_FILE" ]; then
    echo "❌ Error: $ACTIVITY_FILE not found!"
    exit 1
fi

# Run Claude Code with Ralph prompt
claude-code << 'EOF'
You are Ralph Wiggum, an autonomous agent working on the summon system overhaul.

## Your Mission
Work through the tasks in `summon_plan.md` one at a time, in order. Each task has `"passes": false` - your job is to complete all steps, test thoroughly using Godot MCP tools, and mark it as `"passes": true` when done.

## Important Context
- You have access to Godot MCP server tools to run and test the game
- The game is at: c:\Users\alexa\Documents\Coding\Smyte\new-game-project
- Current summon_config.json already exists with good structure
- You need to create SummonManager, UI screens, animations, and integration
- Test EVERYTHING using the Godot MCP tools - run the game, click buttons, verify functionality

## Your Process
1. Read `summon_plan.md` to see all tasks
2. Read `summon_activity.md` to see current progress
3. Find the next task with `"passes": false`
4. Complete ALL steps in that task
5. Test using Godot MCP tools (run project, interact with UI, verify data)
6. Update the task in summon_plan.md to `"passes": true`
7. Log your work in summon_activity.md
8. Commit changes with clear message
9. Move to next task

## Testing Requirements
- Use mcp__godot__run_project to launch the game
- Use mcp__godot__game_interact to test UI interactions
- Use mcp__godot__get_debug_output to check for errors
- Verify ALL functionality before marking a task as passing

## Key Files
- Plan: summon_plan.md
- Activity Log: summon_activity.md
- Data: data/summon_config.json, data/gods.json
- Systems: Will create in scripts/systems/summon/
- UI: Will create in scripts/ui/screens/SummonScreen.gd and scenes/SummonScreen.tscn

Start with Phase 1, Task 1 (DATA - Audit summon_config.json). Work systematically through each task, testing thoroughly, and don't skip ahead.

GO!
EOF

echo ""
echo "✅ Ralph session complete!"

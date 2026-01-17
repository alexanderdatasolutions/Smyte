#!/bin/bash

# Overnight Polish - Wake up to a playable game
# Usage: ./ralph.sh [max_iterations]

MAX=${1:-75}
i=0

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🎮 SMYTE OVERNIGHT POLISH"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Goal: Playable, polished game by morning"
echo "  Max iterations: $MAX"
echo "  Started: $(date)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

while [ $i -lt $MAX ]; do
    i=$((i + 1))
    
    # Progress
    DONE=$(grep -c '"passes": true' plan.md 2>/dev/null || echo 0)
    TODO=$(grep -c '"passes": false' plan.md 2>/dev/null || echo 0)
    
    echo ""
    echo "══════ ITERATION $i | $(date '+%H:%M') | Done: $DONE | Left: $TODO ══════"
    
    cat PROMPT.md | claude -p --model sonnet --dangerously-skip-permissions --output-format text
    
    # Check if complete - exit IMMEDIATELY if no tasks left
    TODO=$(grep -c '"passes": false' plan.md 2>/dev/null || echo 0)
    
    if [ "$TODO" -eq 0 ]; then
        # Double check there are actually completed tasks (not empty plan)
        DONE=$(grep -c '"passes": true' plan.md 2>/dev/null || echo 0)
        if [ "$DONE" -gt 0 ]; then
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "  ✅ ALL TASKS COMPLETE!"
            echo "  Tasks finished: $DONE"
            echo "  Iterations: $i"
            echo "  Finished: $(date)"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "  🎮 Open Godot and play your game!"
            echo ""
            exit 0
        fi
    fi
    
    sleep 2
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ⏰ Hit max iterations: $MAX"
echo "  Check activity.md for progress"
echo "  Finished: $(date)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
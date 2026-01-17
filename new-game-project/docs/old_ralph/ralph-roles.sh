#!/bin/bash

# Ralph Role & Specialization System Runner
# Usage: ./ralph-roles.sh [max_iterations]

cd "$(dirname "$0")"

MAX=${1:-20}
i=0

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🏛️ SMYTE ROLE & SPECIALIZATION SYSTEM"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Max iterations: $MAX"
echo "  Started: $(date)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

while [ $i -lt $MAX ]; do
    i=$((i + 1))

    # Progress check
    DONE=$(grep -c '"complete": true' smyte-ralph/role_spec_plan.md 2>/dev/null || echo 0)
    TODO=$(grep -c '"complete": false' smyte-ralph/role_spec_plan.md 2>/dev/null || echo 0)

    echo ""
    echo "══════ ITERATION $i | $(date '+%H:%M') | Done: $DONE | Left: $TODO ══════"

    # Build combined prompt and pipe to claude
    {
        cat PROMPT_ROLES.md
        echo ""
        echo "---"
        echo "# CLAUDE.md (Project Context)"
        cat CLAUDE.md
        echo ""
        echo "---"
        echo "# smyte-ralph/role_spec_plan.md (Task List)"
        cat smyte-ralph/role_spec_plan.md
        echo ""
        echo "---"
        echo "# smyte-ralph/role_spec_activity.md (Activity Log)"
        cat smyte-ralph/role_spec_activity.md
    } | claude -p --model sonnet --dangerously-skip-permissions --output-format stream-json --verbose

    # Check if complete
    TODO=$(grep -c '"complete": false' smyte-ralph/role_spec_plan.md 2>/dev/null || echo 0)

    if [ "$TODO" -eq 0 ]; then
        DONE=$(grep -c '"complete": true' smyte-ralph/role_spec_plan.md 2>/dev/null || echo 0)
        if [ "$DONE" -gt 0 ]; then
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "  ✅ ALL TASKS COMPLETE!"
            echo "  Tasks finished: $DONE"
            echo "  Iterations: $i"
            echo "  Finished: $(date)"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            exit 0
        fi
    fi

    sleep 2
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ⏰ Hit max iterations: $MAX"
echo "  Check smyte-ralph/role_spec_activity.md for progress"
echo "  Finished: $(date)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
exit 1

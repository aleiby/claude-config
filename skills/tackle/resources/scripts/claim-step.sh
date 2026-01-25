#!/usr/bin/env bash
# claim-step.sh - Claim ownership of current molecule step
#
# Usage: source claim-step.sh
#
# Inputs (required):
#   MOL_ID - The molecule ID to find steps in
#
# Outputs (exported variables):
#   STEP_ID - The claimed step ID (or empty if none available)
#
# Notes:
#   - Use when bd mol current shows a step but you're not the assignee
#   - Updates step to in_progress with current BD_ACTOR as assignee
#   - Uses bd ready --mol (primary) or bd dep list (fallback)

set -euo pipefail

# Verify MOL_ID is set
if [ -z "${MOL_ID:-}" ]; then
  echo "ERROR: MOL_ID must be set before sourcing claim-step.sh"
  exit 1
fi

# DISABLED: gt hook --json doesn't respect blocking deps (bug gt-h5fg12)
# HOOK_JSON=$(gt hook --json 2>/dev/null || echo '{}')
# STEP_ID=$(echo "$HOOK_JSON" | jq -r '.progress.ready_steps[0] // empty')

# Primary: Use bd ready --mol to find actually-ready steps (respects blocking deps)
# Note: --mol requires --no-daemon for direct database access
STEP_ID=$(bd --no-daemon ready --mol "$MOL_ID" --json 2>/dev/null | \
  jq -r '[.steps[].issue | select(.status == "open")][0].id // empty' || echo "")

# Second fallback: Find steps via parent-child deps if bd ready fails
if [ -z "$STEP_ID" ]; then
  STEP_ID=$(bd dep list "$MOL_ID" --direction=up --type=parent-child --json 2>/dev/null | \
    jq -r '[.[] | select(.status == "open")][0].id // empty' || echo "")
fi

if [ -n "$STEP_ID" ]; then
  bd update "$STEP_ID" --status=in_progress --assignee="${BD_ACTOR:-}"
fi

# Export variable for use by calling script
export STEP_ID

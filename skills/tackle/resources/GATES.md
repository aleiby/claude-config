# Approval Gates

**MANDATORY STOPS** - Do not proceed without explicit approval.

## Gate Behavior

At any gate:
1. Present the gate UI
2. **STOP** - Do not continue automatically
3. Wait for user input
4. Parse approval or rejection
5. Only proceed on explicit approval

## Approval Detection

Accept these as **approval**:
- `/tackle --gate approve`
- "approve"
- "approved"
- "proceed"
- "continue"
- "yes"
- "lgtm"
- "looks good"
- "go ahead"
- "submit" (at gate-submit only)
- "ship it"

Accept these as **rejection**:
- `/tackle --gate reject`
- "reject"
- "no"
- "stop"
- "wait"
- "revise"
- "hold"
- "change"

## Gate 1: Plan Review

Present after plan is created:

```
╔══════════════════════════════════════════════════════════════════╗
║                    GATE: Plan Review                             ║
╚══════════════════════════════════════════════════════════════════╝

Plan for <issue-id>: <issue-title>

## Scope
  - Files: <list of files to modify>
  - Estimated changes: ~<n> lines

## Approach
<brief description of implementation approach>

## Upstream Context
  - Conflicting PRs: <none | list>
  - Hot areas: <none | list with reasons>

┌─────────────────────────────────────────────────────────────────┐
│ What would you like to do?                                      │
│                                                                 │
│   /tackle --gate approve    Continue to implementation          │
│   /tackle --gate reject     Revise the plan                     │
│                                                                 │
│ Or respond naturally: "approve", "looks good", "revise", etc.   │
└─────────────────────────────────────────────────────────────────┘
```

### On Approve

Update molecule:
```yaml
phase: "branch"
plan_approved: true
plan_approved_at: "2026-01-19T12:00:00Z"
```

Proceed to branch creation.

### On Reject

```
What would you like to change about the plan?
```

Stay in plan phase, revise based on feedback.

## Gate 2: Pre-Submit Review

Present after validation passes. **Create a draft PR directly on UPSTREAM for review.**

### Step 1: Push and Create Draft PR on Upstream

```bash
# Push branch to origin (your fork)
git push -u origin <branch-name>
# Note: If pre-push hooks block feature branches, use --no-verify

# Detect fork owner from origin remote
FORK_OWNER=$(gh repo view --json owner --jq '.owner.login')

# Create draft PR directly on UPSTREAM (visible but marked as draft)
gh pr create --repo <upstream-org>/<upstream-repo> --draft \
  --head "$FORK_OWNER:<branch-name>" \
  --title "<title>" --body "<body>"

# Get the PR URL
PR_URL=$(gh pr view --repo <upstream-org>/<upstream-repo> --json url --jq '.url')
```

This creates the actual PR on upstream as a draft. The reviewer can see the exact PR that will be submitted.

### Step 2: Present Gate with Review Link

```
╔══════════════════════════════════════════════════════════════════╗
║                  GATE: Pre-Submit Review                         ║
╚══════════════════════════════════════════════════════════════════╝

Draft PR for <issue-id>:

## Review on GitHub (DRAFT)
<upstream-pr-url>

## Title
<pr-title>

## Target
<upstream-org>/<upstream-repo> ← <fork-owner>:<branch-name>

## Summary
<pr-body-preview>

## Changes
<file-list with +/- counts>

## Validation
  - Tests: PASSED
  - Isolation: PASSED (single concern)
  - Rebased: Yes, on upstream default branch

┌─────────────────────────────────────────────────────────────────┐
│ This is the actual PR on upstream (in draft state).             │
│ Review on GitHub, then:                                         │
│                                                                 │
│   /tackle --gate approve    Mark PR ready for review            │
│   /tackle --gate reject     Return to implementation            │
│                                                                 │
│ Or respond naturally: "submit", "looks good", "wait", etc.      │
└─────────────────────────────────────────────────────────────────┘

ℹ️  PR exists on upstream as DRAFT. Approval marks it ready for maintainer review.
```

### On Approve

**IMPORTANT**: Store PR info in the gate bead before closing so it survives session handoffs:

```bash
# Get the current step ID (the gate we're at)
GATE_BEAD=$(bd --no-daemon mol current --json | jq -r '.current_step.id')

# Store PR info in notes for recovery after compaction
bd update "$GATE_BEAD" --notes="pr_number: $PR_NUMBER
pr_url: $PR_URL
approved_at: $(date -Iseconds)"

# Close the gate
bd close "$GATE_BEAD" --reason "Approved - PR #$PR_NUMBER ready for review" --continue
```

Proceed to submit phase (marks the draft PR as ready for review).

### On Reject

```
What would you like to change before submission?
Options:
  - Modify implementation (will force-push to update draft PR)
  - Update PR title/body (can edit draft PR directly)
  - Add more tests
  - Close draft PR and start over
  - Other changes
```

Return to implement phase for revisions. The draft PR remains open - changes will be force-pushed to update it.

## Help at Gates

If user asks for help or seems confused:

```
You're at the <gate-name> gate.

This is a mandatory approval checkpoint. The skill will not proceed
until you explicitly approve or reject.

Commands:
  /tackle --gate approve    Approve and continue
  /tackle --gate reject     Go back and revise
  /tackle --status          Show current state
  /tackle --help            Show all options

You can also respond naturally:
  "yes", "approve", "looks good" → approve
  "no", "wait", "revise" → reject
```

## Agent Safety

**Critical for autonomous agents:**

Gates apply to ALL agents equally:
- Mayor: stops at gates
- Crew: stops at gates
- Polecats: stops at gates

No agent can bypass gates. No role-specific exceptions.

If an agent reaches a gate without a human in the loop:
1. Present gate
2. Wait for human approval
3. Do not timeout and auto-approve
4. Do not proceed on any heuristic

This ensures no autonomous PR submission.

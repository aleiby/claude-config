---
name: tackle
description: |
  Upstream-aware issue implementation workflow with mandatory approval gates.
  Checks upstream for existing fixes. Enforces review gates before PR submission.

  INVOKE THIS SKILL when user says "tackle" in any form:
  - "tackle", "let's tackle", "tackle this", "tackle the X issue"
user-invocable: true
---

# Tackle - Upstream-Aware Implementation Workflow

## Quick Reference

```
/tackle <issue>       Start working on issue
/tackle --status      Show current state
/tackle --abort       Abandon tackle, clean up
/tackle --refresh     Force refresh upstream research
/tackle --help        Show this help
```

When user asks for help, show this Quick Reference section.

## Resumption Protocol (ALWAYS FIRST)

**When to run this:** After session restart (compaction, handoff, new terminal), or when checking status with `/tackle --status`. This ensures you have accurate state before taking any action.

```bash
bd --no-daemon mol current   # 1. Verify molecule state
gt mol status                # 2. Verify hook attachment
# If detached, get MOL_ID from gt hook or bd mol current output, then:
# gt mol attach "$MOL_ID"
```

**NEVER trust summary alone. State is truth.**

If `bd mol current` shows a step but you're not the assignee:
```bash
# MOL_ID from bd --no-daemon mol current output
STEP_ID=$(bd ready --parent "$MOL_ID" --json | jq -r '.[0].id')
bd update "$STEP_ID" --status=in_progress --assignee="$BD_ACTOR"
```

## Resource Loading (Progressive Disclosure)

**DO NOT load all resource files.** Load only what's needed for your current step.

Check current step with `bd --no-daemon mol current`, then use this lookup:

| If Current Step Is | Load Resource |
|--------------------|---------------|
| plan, branch, implement | IMPLEMENT.md |
| gate-plan, gate-submit | (none - see gate details in this file) |
| validate | VALIDATION.md |
| submit, record | SUBMIT.md |
| reflect | REFLECT.md |

**Pre-molecule research:** Handled by sub-agents (see Sub-Agent Usage below). Main agent only loads compact YAML results.

## Sub-Agent Usage (Context Optimization)

**Use sub-agents for research phases** to reduce context in the main conversation. Sub-agents load their own resource files, execute API calls, and return compact structured summaries.

### When to Use Sub-Agents

| Phase | Sub-Agent? | Reason |
|-------|------------|--------|
| Project Research (Step 4) | **Yes** | Only when cache stale; fetches lots of API data |
| Pending PR Check (Step 6) | **Yes** | Runs every tackle, loops through multiple issues |
| Issue Research (Step 7) | **Yes** | Runs every tackle, checks multiple repos |
| Implementation | No | Needs full codebase context |
| Gates | No | Requires user interaction |

**Important:** Cache freshness checks stay in SKILL.md to avoid spawning sub-agents unnecessarily.

## State Management via Beads Molecules

**Molecule workflow:**
```bash
# Create molecule (requires --no-daemon)
# $ISSUE_ID set in Step 2, $ORG_REPO set in Step 3
MOL_OUTPUT=$(bd --no-daemon mol pour tackle --var issue="$ISSUE_ID" --var upstream="$ORG_REPO" 2>&1)
MOL_ID=$(echo "$MOL_OUTPUT" | grep "Root issue:" | sed 's/.*Root issue: //')

# Add formula label for pattern detection in reflect phase
bd update "$MOL_ID" --add-label "formula:tackle"

# Attach molecule to track your work (auto-detects your agent bead from cwd)
gt mol attach "$MOL_ID"

# If you get "not pinned" error, your agent bead needs setup first:
#   AGENT_BEAD=$(bd list --type=agent --json | jq -r '.[0].id')
#   bd update "$AGENT_BEAD" --status=pinned
#   gt mol attach "$MOL_ID"  # retry
```

**Check current state:**
```bash
bd --no-daemon mol current   # Show active molecule and current step
bd ready                     # Find next executable step
bd show "$STEP_ID"           # View step details (STEP_ID from bd ready output)
```

**Two ways to get molecule ID:**
- `gt hook --json | jq -r '.attached_molecule'` - from hook attachment (simpler, preferred for resume)
- `bd --no-daemon mol current --json | jq -r '.molecule.id'` - from molecule state (works even if hook detached)

Use `gt hook` for resumption checks; use `bd mol current` for step-level operations.

**Advance through steps:**
```bash
bd close "$STEP_ID" --continue   # Complete step and auto-advance
```

## Phase Flow

```
Pre-molecule (research):
  - Detect Upstream
  - [Project Research → Project Report] (only if cache stale)
  - Issue Research (checks all tracked repos)
      → Existing Work Decision → (skip | wait | proceed)
  - Create Molecule

Molecule steps (implementation):
  Plan → GATE:Plan
    → Branch → Implement → Validate → GATE:Submit
      → Submit → Record → Reflect
```

## Execution Instructions

### Parse Command

First, parse what the user wants:

| Input | Action |
|-------|--------|
| `/tackle <issue>` | Start or resume tackle for issue |
| `/tackle --status` | Show current tackle state via `bd --no-daemon mol current` |
| `/tackle --abort` | Abandon tackle, clean up molecule and branch |
| `/tackle --refresh` | Force refresh upstream research |
| `/tackle --help` | Show Quick Reference to user |

### Starting Tackle

When starting `/tackle <issue>`:

#### 1. Check for Existing Molecule

```bash
gt mol status
```

If attached, resume from current step:
```bash
bd --no-daemon mol current
bd ready
```

If no molecule attached, continue with fresh tackle setup below.

#### 2. Resolve Issue

The user's input may be an issue ID, partial match, or description.

```bash
# Try direct lookup (use || true to avoid exit on not found)
bd show <issue> || true
```

If not found, search for matches:
```bash
bd ready -n 0 --json | jq -r '.[] | "\(.id): \(.title)"'
```

If no matches, offer to create a bead for the work.

Once resolved, set the variable for subsequent steps:
```bash
ISSUE_ID="<resolved-issue-id>"  # e.g., "hq-1234"
```

#### 3. Detect Upstream

```bash
# Detect remote (prefer upstream, then fork-source, then origin)
UPSTREAM_REMOTE="upstream"
UPSTREAM_URL=$(git remote -v | grep -E '^upstream\s' | head -1 | awk '{print $2}')
if [ -z "$UPSTREAM_URL" ]; then
  UPSTREAM_REMOTE="fork-source"
  UPSTREAM_URL=$(git remote -v | grep -E '^fork-source\s' | head -1 | awk '{print $2}')
fi
if [ -z "$UPSTREAM_URL" ]; then
  UPSTREAM_REMOTE="origin"
  UPSTREAM_URL=$(git remote -v | grep -E '^origin\s' | head -1 | awk '{print $2}')
fi

# Error if no remote found
if [ -z "$UPSTREAM_URL" ]; then
  echo "ERROR: No git remote found. Expected 'upstream', 'fork-source', or 'origin'."
  echo "Add a remote with: git remote add origin <url>"
  exit 1
fi

# Extract org/repo, strip .git suffix if present
ORG_REPO=$(echo "$UPSTREAM_URL" | sed -E 's#.*github.com[:/]##' | sed 's/\.git$//')

# Verify we got a valid org/repo
if [ -z "$ORG_REPO" ] || [ "$ORG_REPO" = "$UPSTREAM_URL" ]; then
  echo "ERROR: Could not parse org/repo from URL: $UPSTREAM_URL"
  echo "Expected GitHub URL format (https or ssh)"
  exit 1
fi

# Detect default branch
DEFAULT_BRANCH=$(gh api repos/$ORG_REPO --jq '.default_branch')
UPSTREAM_REF="$UPSTREAM_REMOTE/$DEFAULT_BRANCH"
```

Variables set:
- `$UPSTREAM_REMOTE` - the git remote name (upstream, fork-source, or origin)
- `$UPSTREAM_URL` - the remote URL
- `$ORG_REPO` - the org/repo format (e.g., "steveyegge/beads")
- `$DEFAULT_BRANCH` - the default branch name (e.g., "main")
- `$UPSTREAM_REF` - the full ref (e.g., "upstream/main")

**Placeholder aliases used in this skill:**

Angle-bracket placeholders indicate values to substitute with actuals:
- `<upstream>` = `$ORG_REPO` (e.g., "steveyegge/beads")
- `<issue-id>` = the local bead ID being tackled
- `<molecule-id>` = the tackle molecule ID (gt-mol-xxx)
- `<skill-dir>` = directory where this skill was loaded from
- `<cache-bead-id>` = cache bead ID from Step 4
- `<pending-issues-json>` = JSON array from PENDING_JSON
- `<tracked-repos-json>` = JSON array from TRACKED_REPOS
- `<search-terms-array>` = keywords extracted from issue title
- `<upstream-issue-number>` = GitHub issue number (or null)
- `<upstream-pr-url>` = the draft PR URL on upstream repo

**Sub-agent prompts:** Replace all `<placeholders>` with actual values before spawning - sub-agents don't inherit shell variables.

**Persistence:** These variables don't persist across sessions. Store `$ORG_REPO` in the molecule for recovery:
```bash
bd --no-daemon mol pour tackle --var issue="$ISSUE_ID" --var upstream="$ORG_REPO"
```
When resuming, re-run upstream detection or retrieve from molecule:
```bash
ORG_REPO=$(bd show <molecule-id> --json | jq -r '.[0].vars.upstream // empty')
```

#### 4. Project Research (cache check + sub-agent if stale)

Check if project-level research cache needs refreshing.

**Cache freshness check (stays in main agent):**
```bash
# Fast path: Check config for cached bead ID (requires yq)
CACHE_BEAD=$(yq ".tackle.cache_beads[\"$ORG_REPO\"]" .beads/config.yaml 2>/dev/null)

# Fallback: Label search if not in config
if [ -z "$CACHE_BEAD" ] || [ "$CACHE_BEAD" = "null" ]; then
  CACHE_BEAD=$(bd list --label=tackle-cache --title-contains="$ORG_REPO" --json | jq -r '.[0].id // empty')
fi

# Check freshness (24h threshold)
CACHE_FRESH=false
if [ -n "$CACHE_BEAD" ] && [ "$CACHE_BEAD" != "null" ]; then
  LAST_CHECKED=$(bd show "$CACHE_BEAD" --json | jq -r '.[0].notes' | grep -oE 'last_checked: [^ ]+' | sed 's/last_checked: //' || echo "")
  if [ -n "$LAST_CHECKED" ]; then
    # Cross-platform date parsing (handles +TZ offset, Z suffix, or bare timestamp)
    # Strip timezone suffix for parsing: remove trailing Z, or +/-HH:MM offset
    BARE_TS=$(echo "$LAST_CHECKED" | sed -E 's/(Z|[+-][0-9]{2}:[0-9]{2})$//')
    if date -d "$LAST_CHECKED" +%s >/dev/null 2>&1; then
      # GNU date (Linux)
      LAST_TS=$(date -d "$LAST_CHECKED" +%s)
    elif date -j -f "%Y-%m-%dT%H:%M:%S" "$BARE_TS" +%s >/dev/null 2>&1; then
      # BSD date (macOS) - use stripped timestamp
      LAST_TS=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$BARE_TS" +%s)
    else
      LAST_TS=0
    fi
    NOW_TS=$(date +%s)
    AGE_HOURS=$(( (NOW_TS - LAST_TS) / 3600 ))
    [ "$AGE_HOURS" -lt 24 ] && CACHE_FRESH=true
  fi
fi
```

**If cache is fresh:** Skip to Step 6 (Pending PR Check).

**If cache is stale or missing:** Invoke sub-agent:
```
Use Task tool with:
  subagent_type: "general-purpose"
  prompt: |
    Read resource file: <skill-dir>/resources/subagents/PROJECT-RESEARCH.md

    Execute with inputs:
    ```yaml
    inputs:
      org_repo: "<upstream>"
      cache_bead: "<cache-bead-id>"  # or "null" if not found
    ```

    Return structured YAML as specified in the resource file.
```

#### 5. Project Report (only if new data found)

If project research sub-agent ran, present checkpoint with the returned data:
- Guidelines summary
- Related repos detected (offer to track)

User can add more related repos or continue to Step 6.

#### 6. Check Pending PR Outcomes (Sub-Agent)

**Before proceeding with any new work, clean up stale PR submissions.**

This is a housekeeping gate - check ALL issues with `pr-submitted` label.

**Gather inputs for sub-agent:**
```bash
# Build pending issues list
# Notes contain "PR: https://github.com/org/repo/pull/123" format
# Extract PR number from the URL path
PENDING_JSON=$(bd list --label=pr-submitted --json 2>/dev/null | jq '[.[] | {
  id: .id,
  pr_number: ((.notes // "") | capture("pull/(?<n>[0-9]+)")? | .n // null),
  title: .title
}] | map(select(.pr_number != null))')

echo "$PENDING_JSON"
```

**Invoke sub-agent:**
```
Use Task tool with:
  subagent_type: "general-purpose"
  prompt: |
    Read resource file: <skill-dir>/resources/subagents/PR-CHECK.md

    Execute with inputs:
    ```yaml
    inputs:
      org_repo: "<upstream>"
      pending_issues: <pending-issues-json>
    ```

    Return structured YAML as specified in the resource file.
```

**Handle result:**
The sub-agent returns a `pr_check` YAML with `summary` and `actions_taken`.

Report to user:
```
Checked N pending PR(s): <actions_taken summary>
```

If no pending PRs, sub-agent returns `checked_count: 0` - report explicitly.

#### 7. Issue Research (Sub-Agent)

**Check if the current issue is already addressed.**

**Gather inputs for sub-agent:**
```bash
# Get tracked repos from cache (requires yq: https://github.com/mikefarah/yq)
TRACKED_REPOS=$(yq -o=json '.tackle.tracked_repos // []' .beads/config.yaml 2>/dev/null)
# Falls back to just ORG_REPO if no cache
[ "$TRACKED_REPOS" = "[]" ] || [ -z "$TRACKED_REPOS" ] && TRACKED_REPOS="[\"$ORG_REPO\"]"

# Extract upstream issue number from external_ref field
# Format convention: "gh:<org>/<repo>#<number>" or "issue:<number>" for simple cases
# Examples: "gh:steveyegge/beads#123", "issue:456"
# Set via: bd create --external-ref "gh:org/repo#123" or bd update --external-ref "..."
UPSTREAM_ISSUE=$(bd show "$ISSUE_ID" --json | jq -r '.[0].external_ref // empty' | grep -oE '#[0-9]+$|issue:[0-9]+' | grep -oE '[0-9]+')

# Extract search terms from issue title
ISSUE_TITLE=$(bd show "$ISSUE_ID" --json | jq -r '.[0].title')
```

**Invoke sub-agent:**
```
Use Task tool with:
  subagent_type: "general-purpose"
  prompt: |
    Read resource file: <skill-dir>/resources/subagents/ISSUE-RESEARCH.md

    Execute with inputs:
    ```yaml
    inputs:
      org_repo: "<upstream>"
      tracked_repos: <tracked-repos-json>
      issue_id: "<issue-id>"
      upstream_issue: <upstream-issue-number>  # or null if not set
      search_terms: <search-terms-array>
    ```

    Return structured YAML as specified in the resource file.
```

**Handle result:**
The sub-agent returns an `issue_research` YAML with `decision` and `reason`.

Use the `decision` field to determine next action:
- `proceed` → Continue to Step 8 (create molecule)
- `skip` → Present skip option to user
- `wait` → Present wait option with `blocking_work` details
- `fix_existing` → Present fix option with user's open PR details

#### 8. Existing Work Decision

If existing work found, present options:

```
Found existing work for this issue:
  - Upstream issue #123 is CLOSED
  - PR #456 already addresses this
  - You have PR #789 open (CI failing)

Options:
  - Skip tackle (close local issue)
  - Wait for existing PR to merge
  - Fix your existing PR
  - Proceed anyway
```

Accept natural language responses. If user chooses to skip/wait, do not create molecule.

#### 9. Sync Formula

Before creating the molecule, install the formula to town-level (user formulas, not project-specific):

```bash
# <skill-dir> is the directory containing SKILL.md (where you loaded this skill from)
FORMULA_SRC="<skill-dir>/resources/tackle.formula.toml"

# Install to town-level formulas (Tier 2 - cross-project, user workflows)
# GT_TOWN_ROOT is set by Gas Town, defaults to ~/gt
TOWN_FORMULAS="${GT_TOWN_ROOT:-$HOME/gt}/.beads/formulas"
mkdir -p "$TOWN_FORMULAS"
cp "$FORMULA_SRC" "$TOWN_FORMULAS/tackle.formula.toml"
```

#### 10. Create Molecule (only if proceeding)

```bash
# Create molecule and capture ID (requires --no-daemon)
# Note: mol pour outputs "Root issue: <id>" - parse that line
MOL_OUTPUT=$(bd --no-daemon mol pour tackle --var issue="$ISSUE_ID" --var upstream="$ORG_REPO" 2>&1)
MOL_ID=$(echo "$MOL_OUTPUT" | grep "Root issue:" | sed 's/.*Root issue: //')
echo "Created molecule: $MOL_ID"

if [ -z "$MOL_ID" ]; then
  echo "ERROR: Failed to create molecule"
  echo "$MOL_OUTPUT"
  exit 1
fi

# Add formula label for pattern detection
bd update "$MOL_ID" --add-label "formula:tackle"

# Link source issue to molecule (bd show <issue> will show parent)
bd update "$ISSUE_ID" --parent "$MOL_ID"

# Attach molecule to your hook
gt mol attach "$MOL_ID"
# If "not pinned" error: see molecule workflow section above

# Verify hook is set (critical for session recovery)
gt hook | grep -q "$MOL_ID" || echo "WARNING: Hook not set - check gt mol attach"

# Mark the source issue as in_progress (keeps bd ready clean)
bd update "$ISSUE_ID" --status=in_progress

# CRITICAL: Claim first step with assignee so bd mol current works
FIRST_STEP=$(bd ready --parent "$MOL_ID" --json 2>/dev/null | jq -r '.[0].id // empty')
if [ -n "$FIRST_STEP" ]; then
  bd update "$FIRST_STEP" --status=in_progress --assignee "$BD_ACTOR"
fi
```

### Phase Execution

Based on current step (from `bd --no-daemon mol current`), take the appropriate action.
See Resource Loading table above for which resource file to load.

| Step ID | Action |
|---------|--------|
| `plan` | Create implementation plan |
| `gate-plan` | **STOP** - Wait for plan approval |
| `branch` | Create clean branch from upstream |
| `implement` | Write code following upstream conventions |
| `validate` | Run tests, check isolation |
| `gate-submit` | **STOP** - Wait for submit approval |
| `submit` | Mark draft PR ready for review |
| `record` | Update local issue with PR link |
| `reflect` | Reflect on skill issues (see Reflect section) |

### Completing Steps

After completing work for a step:
```bash
bd close "$STEP_ID" --continue

# CRITICAL: Set assignee so bd mol current can find you
NEXT_STEP=$(bd ready --parent "$MOL_ID" --json 2>/dev/null | jq -r '.[0].id // empty')
if [ -n "$NEXT_STEP" ]; then
  bd update "$NEXT_STEP" --assignee "$BD_ACTOR"
fi
```

This marks the step complete and advances to the next step. The assignee step is required because `bd mol current` filters by assignee - without it, the molecule becomes invisible.

**Continue until reflect is complete and root molecule is closed.** Tackle is not done until then.

---

## Project Research Notes

Project research logic is in **Step 4** of Starting Tackle:
- Cache freshness check runs in main agent (avoids unnecessary sub-agent spawn)
- If stale: PROJECT-RESEARCH sub-agent fetches data and updates cache bead
- 24-hour cache threshold

**Force Refresh:** `/tackle --refresh` bypasses the cache check and always spawns the sub-agent.

---

## APPROVAL GATES

**CRITICAL SAFETY RULES - READ THIS SECTION COMPLETELY**

### Response Detection

Accept natural language **approval**:
- "approve", "approved", "proceed", "continue"
- "yes", "lgtm", "looks good", "go ahead"
- "submit", "ship it" (at gate-submit only)

Accept natural language **explain** (gate-plan only):
- "explain", "why", "rationale", "reasoning"
- "tell me more", "justify", "alternatives"

Accept natural language **decline**:
- "decline", "reject", "no", "stop"
- "wait", "revise", "hold", "change"

### Gate Rules (NEVER VIOLATE)

1. **NEVER** proceed past a gate without explicit user approval
2. **NEVER** auto-approve based on heuristics or timeouts
3. **NEVER** submit a PR without gate-submit approval
4. **ALL agents** stop at gates - no exceptions
5. If no human in loop, **WAIT INDEFINITELY** at the gate

---

## Gate 1: `gate-plan` (Plan Review)

**MANDATORY STOP** - Present the plan, then wait for explicit user approval before proceeding.

### Pre-Gate Preparation (Internal)

Before presenting the checkpoint, prepare internally (but don't show unless asked):

1. **Why this approach over alternatives** - What other solutions were considered? Why were they rejected?
2. **Key tradeoffs** - What are we accepting? Why is it acceptable?
3. **Root cause confidence** - How does this address the actual problem, not just symptoms?

Only present this if the user asks to "explain".

### Show to User

```
┌────────────────────────────────────────────────────────────────────┐
│  📝 CHECKPOINT: Plan Review                                        │
└────────────────────────────────────────────────────────────────────┘

Plan for <issue-id>: <issue-title>

## Scope
  - Files: <list of files to modify>
  - Estimated changes: ~<n> lines

## Approach
<brief description of implementation approach>

## Upstream Context
  - Conflicting PRs: <none | list>
  - Hot areas: <none | list with reasons>

## Testing
<one of:>
  - Recommend: <specific tests to add or modify>
  - Existing coverage sufficient: <brief justification>
  - N/A: <reason, e.g., "documentation-only change">

## Claim
<one of:>
  - Will claim: issue #<n> is open, unclaimed, on upstream
  - Skip: <reason, e.g., "internal-only issue", "already assigned to me", "I filed this issue">

Options:
  1. Approve (continue to implementation)
  2. Explain (show rationale for this approach)
  3. Decline (request changes)
```

### On Approve

```bash
# STEP_ID from bd --no-daemon mol current
bd close "$STEP_ID" --continue
```

**If claiming** (plan indicated "Will claim"):
```bash
# Extract upstream issue number from the local issue's external_ref
# See Step 7 for format convention (gh:org/repo#123 or issue:123)
UPSTREAM_ISSUE=$(bd show "$ISSUE_ID" --json | jq -r '.[0].external_ref // empty' | grep -oE '#[0-9]+$|issue:[0-9]+' | grep -oE '[0-9]+')
if [ -n "$UPSTREAM_ISSUE" ]; then
  gh issue comment "$UPSTREAM_ISSUE" --repo "$ORG_REPO" --body "I'd like to work on this. I'll submit a PR soon."
fi
```

Proceed to branch creation.

### On Explain

Present the rationale you prepared internally:

```
## Rationale

**Why this approach:**
<explanation of the chosen solution>

**Alternatives considered:**
<what was rejected and why>

**Tradeoffs:**
<what we're accepting and why it's acceptable>

---
Options:
  - Approve (continue to implementation)
  - Decline (request changes)
```

After presenting rationale, wait for approve or decline.

### On Decline

```
What would you like to change about the plan?
```

Stay in plan phase, revise based on feedback. After making changes:
1. Update the plan in the `plan` step bead
2. Re-present the gate-plan checkpoint with updated content
3. Wait for approval again

Do NOT close the gate step until explicitly approved.

---

## Gate 2: `gate-submit` (Pre-Submit Review)

**MANDATORY STOP** - Create draft PR, present for review, wait for explicit user approval before marking ready.

### Variable Recovery (Required After Session Resume)

If resuming at this gate after compaction or new session, recover required variables:

```bash
# Get molecule ID from hook (field is 'attached_molecule' in gt hook --json output)
MOL_ID=$(gt hook --json 2>/dev/null | jq -r '.attached_molecule // empty')
if [ -z "$MOL_ID" ]; then
  echo "ERROR: Not attached to a molecule. Run: gt mol attach <molecule-id>"
  exit 1
fi

# Recover ORG_REPO from molecule vars
ORG_REPO=$(bd show "$MOL_ID" --json | jq -r '.[0].vars.upstream // empty')
if [ -z "$ORG_REPO" ]; then
  # Fallback: re-detect from git remote (see "Detect Upstream" section)
  UPSTREAM_URL=$(git remote get-url upstream 2>/dev/null || git remote get-url fork-source 2>/dev/null || git remote get-url origin 2>/dev/null)
  ORG_REPO=$(echo "$UPSTREAM_URL" | sed -E 's#.*github.com[:/]##' | sed 's/\.git$//')
fi

# Recover DEFAULT_BRANCH
DEFAULT_BRANCH=$(gh api repos/$ORG_REPO --jq '.default_branch')
```

### Idempotent Entry (Critical for Session Recovery)

When entering gate-submit, FIRST check if a draft PR already exists:

```bash
BRANCH=$(git branch --show-current)
FORK_OWNER=$(gh repo view --json owner --jq '.owner.login')
PR_JSON=$(gh pr list --repo $ORG_REPO --head "$FORK_OWNER:$BRANCH" --json number,isDraft,url --jq '.[0]')

if [ -n "$PR_JSON" ]; then
  PR_NUMBER=$(echo "$PR_JSON" | jq -r '.number')
  IS_DRAFT=$(echo "$PR_JSON" | jq -r '.isDraft')
  PR_URL=$(echo "$PR_JSON" | jq -r '.url')

  if [ "$IS_DRAFT" = "false" ]; then
    # Already submitted - skip to record phase
    echo "PR #$PR_NUMBER already marked ready - continuing to record"
  else
    # Draft exists - present it for review
    echo "Found existing draft PR #$PR_NUMBER"
  fi
else
  # No PR exists - create draft
  git push -u origin $BRANCH
  gh pr create --repo $ORG_REPO --draft \
    --head "$FORK_OWNER:$BRANCH" \
    --title "<title>" --body "<body>"
  PR_URL=$(gh pr view --repo $ORG_REPO --json url --jq '.url')
fi
```

GitHub is the source of truth for PR state.

### Show to User

```
┌────────────────────────────────────────────────────────────────────┐
│  📤 CHECKPOINT: Pre-Submit Review                                  │
└────────────────────────────────────────────────────────────────────┘

Draft PR for <issue-id>:

## Review on GitHub (DRAFT)
<upstream-pr-url>

## Title
<pr-title>

## Target
<upstream> <- <fork-owner>:<branch-name>

## Summary
<pr-body-preview>

## Changes
<file-list with +/- counts>

## Validation
  - Tests: PASSED
  - Isolation: PASSED (single concern)
  - Rebased: Yes, on upstream default branch

Approve to mark PR ready for maintainer review.
```

### On Approve

**First, check CI status** before marking PR ready:

```bash
# Get CI status from PR
CHECKS=$(gh pr view $PR_NUMBER --repo $ORG_REPO --json statusCheckRollup)
PENDING=$(echo "$CHECKS" | jq '[.statusCheckRollup[] | select(.status == "COMPLETED" | not)] | length')
FAILED=$(echo "$CHECKS" | jq '[.statusCheckRollup[] | select(.conclusion == "FAILURE")] | length')

# If checks still running, wait and poll
while [ "$PENDING" -gt 0 ]; do
  echo "CI still running ($PENDING checks pending). Waiting 30s..."
  sleep 30
  CHECKS=$(gh pr view $PR_NUMBER --repo $ORG_REPO --json statusCheckRollup)
  PENDING=$(echo "$CHECKS" | jq '[.statusCheckRollup[] | select(.status == "COMPLETED" | not)] | length')
done

# Re-check for failures after completion
FAILED=$(echo "$CHECKS" | jq '[.statusCheckRollup[] | select(.conclusion == "FAILURE")] | length')
```

**If CI failed**, check if failures are pre-existing on main:

```bash
if [ "$FAILED" -gt 0 ]; then
  # Get names of failed checks
  FAILED_NAMES=$(echo "$CHECKS" | jq '[.statusCheckRollup[] | select(.conclusion == "FAILURE") | .name]')

  # Get failures on main/default branch
  MAIN_FAILURES=$(gh api repos/$ORG_REPO/commits/$DEFAULT_BRANCH/check-runs --jq '[.check_runs[] | select(.conclusion == "failure") | .name]')

  # Check if all PR failures also fail on main (pre-existing)
  PRE_EXISTING=$(jq -n --argjson pr "$FAILED_NAMES" --argjson main "$MAIN_FAILURES" '($pr - $main) | length == 0')

  if [ "$PRE_EXISTING" = "true" ]; then
    echo "CI failures are pre-existing on $DEFAULT_BRANCH (not caused by this PR)"
  fi
fi
```

Present CI status to user:
```
CI Status:
  - Passed: <n>
  - Failed: <n> <if pre-existing: "(pre-existing on main)">
  - Skipped: <n>

<if failures are NOT pre-existing>
Options:
  - Fix failures and re-push (returns to implement phase)
  - Submit anyway (maintainer may reject)

<if all failures are pre-existing>
All failures are pre-existing on main. Safe to proceed.
```

**If CI passed** (or failures are pre-existing, or user chooses to submit anyway), store PR info and proceed:

```bash
GATE_BEAD=$(bd --no-daemon mol current --json | jq -r '.current_step.id')

bd update "$GATE_BEAD" --notes="pr_number: $PR_NUMBER
pr_url: $PR_URL
ci_status: passed
approved_at: $(date -Iseconds)"

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

Return to implement phase for revisions. After making changes:
1. Force-push updated branch: `git push -f origin <branch>`
2. Update draft PR if needed: `gh pr edit $PR_NUMBER --repo $ORG_REPO ...`
3. Re-run validation (tests, linter, isolation)
4. Re-present the gate-submit checkpoint
5. Wait for approval again

Do NOT close the gate step until explicitly approved.

---

## Gate Help

If user asks for help or seems confused at a gate:

```
You're at the <gate-name> gate.

This is a mandatory approval checkpoint. The skill will not proceed
until you explicitly approve or decline.

Respond naturally:
  "yes", "approve", "looks good" -> approve
  "why", "explain", "rationale" -> explain (gate-plan only)
  "no", "wait", "revise"        -> decline
```

## Agent Safety

**Critical for autonomous agents:**

Gates apply to ALL agents equally. No agent can bypass gates. No role-specific exceptions.

If an agent reaches a gate without a human in the loop:
1. Present gate
2. Wait for human approval
3. Do not timeout and auto-approve
4. Do not proceed on any heuristic

---

## Reflect

**⚠️ You are NOT done until this step is complete.** PR submission is not the end of the workflow.

The `reflect` step captures issues with the tackle process itself (not task-specific problems).

**Load REFLECT.md for full instructions.** At minimum, answer these before closing:

1. **Skill issues?** Wrong commands, unclear instructions, missing steps?
2. **Research issues?** Missed existing work, stale data, duplicated effort?
3. **Agent issues?** Needed user correction? Forgot steps? Wrong assumptions?

If any issues found: load REFLECT.md for recording format and pattern detection.

After completing the reflect assessment:

```bash
# 1. Close the reflect step (STEP_ID from bd --no-daemon mol current)
bd close "$STEP_ID" --reason "Clean run - no issues"  # or summary of findings

# 2. CRITICAL: Close the ROOT MOLECULE (not just the steps!)
MOL_ID=$(bd --no-daemon mol current --json | jq -r '.molecule.id')
bd close "$MOL_ID" --reason "Tackle complete - PR submitted"

# 3. Verify cleanup
bd --no-daemon mol current   # Should show "No molecules in progress"
gt mol status                # Should show "Nothing on hook"
```

### Aborting (`/tackle --abort`)

To abandon a tackle mid-workflow:

1. **Burn the molecule** (discard without squashing):
   ```bash
   bd --no-daemon mol burn <molecule-id> --force
   ```

2. **Clean up branch** (if created):
   ```bash
   git checkout main  # or default branch
   git branch -D <tackle-branch>
   ```

3. **Update issue** (optional):
   ```bash
   bd update "$ISSUE_ID" --status=open --notes="Tackle aborted"
   ```

The issue returns to ready state for future work.

## Resource Loading

Resources are in the `resources/` folder relative to this SKILL.md file.

When you loaded this skill, note the directory path. Resources are at:

**Phase resources (main agent loads as needed):**
- `<skill-dir>/resources/IMPLEMENT.md`
- `<skill-dir>/resources/VALIDATION.md`
- `<skill-dir>/resources/SUBMIT.md`
- `<skill-dir>/resources/REFLECT.md`
- `<skill-dir>/resources/tackle.formula.toml`

**Sub-agent resources (sub-agents load their own):**
- `<skill-dir>/resources/subagents/PROJECT-RESEARCH.md`
- `<skill-dir>/resources/subagents/ISSUE-RESEARCH.md`
- `<skill-dir>/resources/subagents/PR-CHECK.md`

Only load the resource needed for the current phase to minimize context.

## Session Handoff

When handing off mid-tackle, include this context for the next session:

### Handoff Message Should Include

```markdown
## Tackle Status: <issue-id>

Molecule: <molecule-id>
Current step: <step-name> (from bd --no-daemon mol current)
Branch: <branch-name>

### Completed
- [x] plan (approved)
- [ ] implement (in progress)

### Key State
- Draft PR: #<number> (if created)
- PR URL: <url>
- Gate approvals: plan ok, submit pending

### Next Action
<what the next session should do>
```

### Resuming After Handoff

1. Check molecule status: `bd --no-daemon mol current`
2. Check for existing PR: `gh pr list --head <branch-name>`
3. If PR exists, don't recreate - just continue from current step
4. Load the appropriate resource for the current step

### Compaction Recovery

**CRITICAL**: If your hook is empty after compaction but you were working on a tackle:

```bash
# 1. Check for orphaned tackle molecules
bd list --label=formula:tackle --status=open --json | jq '.[] | {id, title, status}'

# 2. If molecule found, check its state
bd show <molecule-id>

# 3. Re-attach molecule to your hook
gt mol attach <molecule-id>

# 4. Verify and resume
gt hook
bd ready --parent <molecule-id>
```

You can also find your molecule via the source issue (linked via parent-child):
```bash
bd show <issue-id>
```

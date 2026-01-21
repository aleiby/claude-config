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

**Pre-molecule:** Only load RESEARCH.md when the project research cache is stale (at most daily).

## State Management via Beads Molecules

State persists via beads molecules. The tackle formula is shipped with this skill
and installed to the town's `.beads/formulas/` directory.

**Molecule workflow:**
```bash
# Create molecule (requires --no-daemon)
bd --no-daemon mol pour tackle --var issue=<id>
# Returns: Root issue: gt-mol-xxxxx

# Add formula label for pattern detection in reflect phase
bd update <molecule-id> --add-label "formula:tackle"

# Attach molecule to track your work (auto-detects your agent bead from cwd)
gt mol attach <molecule-id>

# If you get "not pinned" error, your agent bead needs setup first:
#   1. Find your agent bead: bd list --type=agent --title-contains="<your-name>"
#   2. Set to pinned: bd update <agent-bead-id> --status=pinned
#   3. Retry: gt mol attach <molecule-id>
```

**Check current state:**
```bash
bd --no-daemon mol current   # Show active molecule and current step
bd ready                     # Find next executable step
bd show <step-id>            # View step details
```

**Advance through steps:**
```bash
bd close <step-id> --continue   # Complete step and auto-advance
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
bd show <input> || true
```

If not found, search for matches:
```bash
bd list --status=open --json | jq -r '.[] | "\(.id): \(.title)"'
```

If no matches, offer to create a bead for the work.

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
- `<upstream>` = `$ORG_REPO`
- `<upstream-org>/<upstream-repo>` = `$ORG_REPO`

**Persistence:** These variables don't persist across sessions. Store `$ORG_REPO` in the molecule for recovery:
```bash
bd --no-daemon mol pour tackle --var issue=<issue-id> --var upstream="$ORG_REPO"
```
When resuming, re-run upstream detection or retrieve from molecule:
```bash
ORG_REPO=$(bd show <molecule-id> --json | jq -r '.[0].vars.upstream // empty')
```

#### 4. Project Research (cache check)

Check if project-level research cache needs refreshing. This identifies the main upstream AND related repos (dependencies, etc.).

See "Project Research Step" section below for cache check logic.

- If cache is fresh: use cached list of tracked repos
- If cache is stale: load RESEARCH.md, refresh cache (this discovers related repos)

#### 5. Project Report (only if new data found)

If project research found new data, present the checkpoint (see RESEARCH.md Section 5).

User can add more related repos to track, or continue.

#### 6. Issue Research

**First, check for pending PR outcomes:**

Look for any local issues with `pr-submitted` label and check their PR outcomes:

```bash
# Find issues awaiting PR outcomes
PENDING_PRS=$(bd list --label=pr-submitted --json | jq -r '.[] | {id, title, notes}')
```

For each issue with `pr-submitted` label, extract the PR URL from notes and check its status:

```bash
PR_STATE=$(gh pr view <pr-number> --repo $ORG_REPO --json state --jq '.state')
```

- If `MERGED`: `bd close <issue-id> --reason "PR merged"` (label auto-removed on close)
- If `CLOSED`: `bd update <issue-id> --remove-label pr-submitted --notes="PR rejected/closed"` to retry, or `bd close <issue-id> --reason "PR rejected"` if not worth retrying
- If `OPEN`: leave as-is (still awaiting review)

**Then, check if the current issue is already addressed.**

Check ALL tracked repos (main upstream + related repos from project research cache), not just the primary upstream.

```bash
# Get tracked repos from cache (requires yq: https://github.com/mikefarah/yq)
TRACKED_REPOS=$(yq '.tackle.tracked_repos[]' .beads/config.yaml 2>/dev/null)
# Falls back to just ORG_REPO if no cache
[ -z "$TRACKED_REPOS" ] && TRACKED_REPOS="$ORG_REPO"
```

For each tracked repo, check:

**Check if upstream issue is closed:**
```bash
# Extract issue number from external_ref (portable regex, works on Linux and macOS)
UPSTREAM_ISSUE=$(bd show <issue-id> --json | jq -r '.[0].external_ref // empty' | grep -oE 'issue:[0-9]+' | sed 's/issue://')
if [ -n "$UPSTREAM_ISSUE" ]; then
  ISSUE_STATE=$(gh api repos/$REPO/issues/$UPSTREAM_ISSUE --jq '.state')
fi
```

**Check for linked PRs:**
```bash
gh api repos/$REPO/issues/$UPSTREAM_ISSUE/timeline \
  --jq '.[] | select(.event == "cross-referenced") | .source.issue | {number, title, state}'
```

**Check own open PRs:**
```bash
gh pr list --repo $REPO --author @me --json number,title,headRefName,statusCheckRollup,mergeable
```

**Check for claims:**
```bash
gh api repos/$REPO/issues/$UPSTREAM_ISSUE/comments --jq '
  .[-10:] | .[] | {user: .user.login, date: .created_at, body: .body[:200]}'
```

Review the recent comments and use judgment to determine if someone has claimed this issue (e.g., "I'll work on this", "taking this", "on it", etc.).

#### 7. Existing Work Decision

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

#### 8. Sync Formula

Before creating the molecule, install the formula to town-level (user formulas, not project-specific):

```bash
FORMULA_SRC="/home/aleiby/.claude/skills/tackle/resources/tackle.formula.toml"

# Install to town-level formulas (Tier 2 - cross-project, user workflows)
# GT_TOWN_ROOT is set by Gas Town, defaults to ~/gt
TOWN_FORMULAS="${GT_TOWN_ROOT:-$HOME/gt}/.beads/formulas"
mkdir -p "$TOWN_FORMULAS"
cp "$FORMULA_SRC" "$TOWN_FORMULAS/tackle.formula.toml"
```

#### 9. Create Molecule (only if proceeding)

```bash
# Create molecule and capture ID (requires --no-daemon)
# Note: mol pour outputs "Root issue: <id>" - parse that line
MOL_OUTPUT=$(bd --no-daemon mol pour tackle --var issue=<issue-id> --var upstream="$ORG_REPO" 2>&1)
MOL_ID=$(echo "$MOL_OUTPUT" | grep "Root issue:" | sed 's/.*Root issue: //')
echo "Created molecule: $MOL_ID"

if [ -z "$MOL_ID" ]; then
  echo "ERROR: Failed to create molecule"
  echo "$MOL_OUTPUT"
  exit 1
fi

# Add formula label for pattern detection
bd update "$MOL_ID" --add-label "formula:tackle"

# Attach molecule
gt mol attach "$MOL_ID"
# If "not pinned" error: see molecule workflow section above
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
bd close <step-id> --continue
```

This marks the step complete and advances to the next step. Use `bd ready` to find it.

**Continue until reflect is complete and root molecule is closed.** Tackle is not done until then.

---

## Project Research Step (Pre-Molecule)

This pre-molecule step checks if project-level research needs refreshing. **Only load RESEARCH.md if the cache is stale.**

### Check Cache Freshness

```bash
# ORG_REPO should be set from upstream detection earlier
# Fast path: Check config for cached bead ID (requires yq: https://github.com/mikefarah/yq)
CACHE_BEAD=$(yq ".tackle.cache_beads[\"$ORG_REPO\"]" .beads/config.yaml 2>/dev/null)

# Fallback: Label search if not in config
if [ -z "$CACHE_BEAD" ] || [ "$CACHE_BEAD" = "null" ]; then
  CACHE_BEAD=$(bd list --label=tackle-cache --title-contains="$ORG_REPO" --json | jq -r '.[0].id // empty')
fi

# Check freshness (24h threshold)
if [ -n "$CACHE_BEAD" ] && [ "$CACHE_BEAD" != "null" ]; then
  # Portable regex (works on Linux and macOS)
  LAST_CHECKED=$(bd show "$CACHE_BEAD" --json | jq -r '.[0].notes' | grep -oE 'last_checked: [^ ]+' | sed 's/last_checked: //' || echo "")
  if [ -n "$LAST_CHECKED" ]; then
    # Cross-platform date parsing (Linux uses -d, macOS uses -j -f)
    if date -d "$LAST_CHECKED" +%s >/dev/null 2>&1; then
      LAST_TS=$(date -d "$LAST_CHECKED" +%s)
    elif date -j -f "%Y-%m-%dT%H:%M:%S" "$LAST_CHECKED" +%s >/dev/null 2>&1; then
      LAST_TS=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${LAST_CHECKED%%+*}" +%s)
    else
      LAST_TS=0
    fi
    NOW_TS=$(date +%s)
    AGE_HOURS=$(( (NOW_TS - LAST_TS) / 3600 ))
    if [ "$AGE_HOURS" -lt 24 ]; then
      CACHE_FRESH=true
    fi
  fi
fi
```

### If Cache Fresh

Skip loading RESEARCH.md. Update last_checked and continue to Issue Research (step 6 in Starting Tackle):

```bash
bd update "$CACHE_BEAD" --notes "last_checked: $(date -Iseconds)"
# Continue to step 6 (Issue-Specific Research)
```

### If Cache Stale or Missing

Load `resources/RESEARCH.md` for full refresh instructions. This discovers related repos (dependencies, etc.) and caches them. After refresh, present the Project Report (Section 5) if new data was found, then continue to Issue Research (step 6 in Starting Tackle).

### Force Refresh

`/tackle --refresh` forces a refresh regardless of cache age. Load RESEARCH.md.

---

## APPROVAL GATES

**CRITICAL SAFETY RULES - READ THIS SECTION COMPLETELY**

### Approval Detection

Accept natural language **approval**:
- "approve", "approved", "proceed", "continue"
- "yes", "lgtm", "looks good", "go ahead"
- "submit", "ship it" (at gate-submit only)

Accept natural language **rejection**:
- "reject", "no", "stop"
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

Approve to continue, or request changes.
```

### On Approve

```bash
bd close <gate-plan-step-id> --continue
```

**If claiming** (plan indicated "Will claim"):
```bash
# Extract upstream issue number from the local issue's external_ref or labels
UPSTREAM_ISSUE=$(bd show <issue-id> --json | jq -r '.[0].external_ref // empty' | grep -oE 'issue:[0-9]+' | sed 's/issue://')
gh issue comment $UPSTREAM_ISSUE --repo $ORG_REPO --body "I'd like to work on this. I'll submit a PR soon."
```

Proceed to branch creation.

### On Reject

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

This ensures the session can end anywhere and resume cleanly. GitHub is the source of truth.

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
<upstream-org>/<upstream-repo> <- <fork-owner>:<branch-name>

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
until you explicitly approve or reject.

Respond naturally:
  "yes", "approve", "looks good" -> approve
  "no", "wait", "revise" -> reject
```

## Agent Safety

**Critical for autonomous agents:**

Gates apply to ALL agents equally. No agent can bypass gates. No role-specific exceptions.

If an agent reaches a gate without a human in the loop:
1. Present gate
2. Wait for human approval
3. Do not timeout and auto-approve
4. Do not proceed on any heuristic

This ensures no autonomous PR submission.

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
# 1. Close the reflect step
bd close <reflect-step-id> --reason "<summary of findings>"

# 2. CRITICAL: Close the ROOT MOLECULE (not just the steps!)
MOL_ID=$(bd --no-daemon mol current --json | jq -r '.molecule.id')
bd close "$MOL_ID" --reason "Tackle complete - PR submitted"

# 3. Verify cleanup
bd --no-daemon mol current   # Should show "No molecules in progress"
gt mol status                # Should show "Nothing on hook"
```

**Why close the root molecule?** Open molecules pollute future queries. Pattern detection depends on closed molecules with proper close_reason fields.

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
   bd update <issue-id> --status=open --notes="Tackle aborted"
   ```

The issue returns to ready state for future work.

### Upstream Detection

Priority for detecting upstream:
1. Git remote named `upstream`
2. Git remote named `fork-source`
3. Origin (if not a fork)

## Resource Loading

Resources are in the `resources/` folder relative to this SKILL.md file.

When you loaded this skill, note the directory path. Resources are at:
- `<skill-dir>/resources/RESEARCH.md`
- `<skill-dir>/resources/IMPLEMENT.md`
- `<skill-dir>/resources/VALIDATION.md`
- `<skill-dir>/resources/SUBMIT.md`
- `<skill-dir>/resources/REFLECT.md`
- `<skill-dir>/resources/tackle.formula.toml`

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

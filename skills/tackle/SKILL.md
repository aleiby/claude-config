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

**DO NOT load all resource files.** Each contains phase-specific instructions.
Loading unnecessary resources wastes context and may cause confusion.

| Current Step | Load Resource |
|--------------|---------------|
| bootstrap, gate-bootstrap | RESEARCH.md |
| context, existing-pr-check | RESEARCH.md |
| plan, branch, implement | IMPLEMENT.md |
| validate | VALIDATION.md |
| gate-plan, gate-submit | (gate details below) |
| submit, record | SUBMIT.md |
| retro | REFLECT.md |

Check current step with `bd --no-daemon mol current`, then load ONLY the matching resource.

## State Management via Beads Molecules

State persists via beads molecules. The tackle formula is shipped with this skill
and installed to the rig's `.beads/formulas/` on first use.

**Molecule workflow:**
```bash
# Create molecule (requires --no-daemon)
bd --no-daemon mol pour tackle --var issue=<id>
# Returns: Root issue: gt-mol-xxxxx

# Add formula label for pattern detection in retro phase
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
Bootstrap → GATE:Bootstrap → Context → [Existing PR Check] → Plan → GATE:Plan → Branch → Implement → Validate → GATE:Submit → Submit → Record → Retro
                                              ↓                                                                                              ↑
                                    [apply | wait | implement anyway]                                                              (can defer until PR merged)
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

### Starting New Tackle

When starting `/tackle <issue>`:

1. **First-time setup**: Install formula if not present (see RESEARCH.md)
2. **Check for attached molecule**: `gt mol status` shows attached molecule if present
3. **If attached**: Resume with `bd --no-daemon mol current`, `bd ready`
4. **If new**: Create and attach molecule:
   ```bash
   # Create molecule (note: requires --no-daemon)
   bd --no-daemon mol pour tackle --var issue=<issue-id>
   # Returns molecule ID like gt-mol-xxxxx

   # Add formula label for pattern detection in retro phase
   bd update <molecule-id> --add-label "formula:tackle"

   # Attach molecule (auto-detects your agent bead from cwd)
   gt mol attach <molecule-id>
   # If "not pinned" error: see molecule workflow section above
   ```

### Phase Execution

Based on current step (from `bd --no-daemon mol current`), load the appropriate resource:

| Step ID | Load Resource | Then |
|---------|---------------|------|
| `bootstrap` | `resources/RESEARCH.md` | Check/refresh upstream research |
| `gate-bootstrap` | (see below) | **CHECKPOINT** - Present research summary |
| `context` | `resources/RESEARCH.md` | Search upstream, check for existing PRs |
| `existing-pr-check` | `resources/RESEARCH.md` | Present options if PR found |
| `plan` | `resources/IMPLEMENT.md` | Create implementation plan |
| `gate-plan` | (see below) | **STOP** - Wait for approval |
| `branch` | `resources/IMPLEMENT.md` | Create clean branch |
| `implement` | `resources/IMPLEMENT.md` | Write code |
| `validate` | `resources/VALIDATION.md` | Run tests, check isolation |
| `gate-submit` | (see below) | **STOP** - Wait for approval |
| `submit` | `resources/SUBMIT.md` | Mark PR ready |
| `record` | `resources/SUBMIT.md` | Record outcome |
| `retro` | `resources/REFLECT.md` | Reflect on skill issues (see below) |

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

## Gate 0: `gate-bootstrap` (Research Checkpoint)

**CHECKPOINT** - Appears when research cache is updated.

This is a soft gate for presenting research results and suggesting related upstreams.

```
┌────────────────────────────────────────────────────────────────────┐
│  🔍 CHECKPOINT: Bootstrap Research Complete                        │
└────────────────────────────────────────────────────────────────────┘

Upstream: steveyegge/gastown
Guidelines: Found CONTRIBUTING.md
Open issues: 12 | Open PRs: 3

## Research Summary
- Commit style: present tense, max 72 chars
- Testing: go test ./...
- PR requires: description, test plan

## Related Projects Detected
From README:
  - steveyegge/beads (mentioned in dependencies)

Track these for additional context?
```

### On Response

- If user wants to add related upstreams: fetch research for them, then continue
- If user skips: continue to context phase

```bash
bd close <gate-bootstrap-step-id> --continue
```

---

## Gate 1: `gate-plan` (Plan Review)

**MANDATORY STOP** - Present the plan, then wait for explicit user approval before proceeding.

### Show to User

```
📝 CHECKPOINT: Plan Review

Plan for <issue-id>: <issue-title>

## Scope
  - Files: <list of files to modify>
  - Estimated changes: ~<n> lines

## Approach
<brief description of implementation approach>

## Upstream Context
  - Conflicting PRs: <none | list>
  - Hot areas: <none | list with reasons>

Approve to continue, or request changes.
```

### On Approve

```bash
bd close <gate-plan-step-id> --continue
```

Proceed to branch creation.

### On Reject

```
What would you like to change about the plan?
```

Stay in plan phase, revise based on feedback.

---

## Gate 2: `gate-submit` (Pre-Submit Review)

**MANDATORY STOP** - Create draft PR, present for review, wait for explicit user approval before marking ready.

### Idempotent Entry (Critical for Session Recovery)

When entering gate-submit, FIRST check if a draft PR already exists:

```bash
BRANCH=$(git branch --show-current)
FORK_OWNER=$(gh repo view --json owner --jq '.owner.login')
PR_JSON=$(gh pr list --repo <upstream> --head "$FORK_OWNER:$BRANCH" --json number,isDraft,url --jq '.[0]')

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
  gh pr create --repo <upstream> --draft \
    --head "$FORK_OWNER:$BRANCH" \
    --title "<title>" --body "<body>"
  PR_URL=$(gh pr view --repo <upstream> --json url --jq '.url')
fi
```

This ensures the session can end anywhere and resume cleanly. GitHub is the source of truth.

### Show to User

```
📤 CHECKPOINT: Pre-Submit Review

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

Store PR info in the gate bead before closing (for recovery after compaction):

```bash
GATE_BEAD=$(bd --no-daemon mol current --json | jq -r '.current_step.id')

bd update "$GATE_BEAD" --notes="pr_number: $PR_NUMBER
pr_url: $PR_URL
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

Return to implement phase for revisions.

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

## Retrospective (Quick Reference)

The `retro` step captures issues with the tackle process itself (not task-specific problems).

**If the run was smooth** - no need to load REFLECT.md:
```bash
bd close <retro-step-id> --reason "Clean run - no issues"
```

**If there were issues** - load REFLECT.md for full guidance:
- **Fix immediately**: Objective errors (wrong flags, syntax errors)
- **Note for patterns**: Subjective friction detected via molecule history

### Completing Steps

After completing work for a step:
```bash
bd close <step-id> --continue
```

This marks the step complete and advances to the next step. Use `bd ready` to find it.

### Aborting (`/tackle --abort`)

To abandon a tackle mid-workflow:

1. **Burn the molecule** (discard without squashing):
   ```bash
   bd --no-daemon mol burn <molecule-id>
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

See RESEARCH.md Section 2 for canonical upstream and default branch detection.

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

On first use, RESEARCH.md copies the formula to the rig's `.beads/formulas/`.

## Session Handoff

When handing off mid-tackle, include this context for the next session:

### Handoff Message Should Include

```markdown
## Tackle Status: <issue-id>

Molecule: <molecule-id>
Current step: <step-name> (from bd --no-daemon mol current)
Branch: <branch-name>

### Completed
- [x] bootstrap
- [x] context
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

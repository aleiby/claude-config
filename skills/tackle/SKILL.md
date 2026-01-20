---
name: tackle
description: |
  Upstream-aware issue implementation workflow with mandatory approval gates.
  Use when: working on bugs, features, or issues resulting in a PR;
  user says "tackle", "work on hq-", "work on bd-", "implement hq-", "fix hq-";
  implementing contributions to upstream repositories.
  Checks upstream for existing fixes. Enforces review gates before PR submission.
user-invocable: true
---

# Tackle - Upstream-Aware Implementation Workflow

## Quick Reference

```
/tackle <issue-id>              Start working on issue
/tackle --status                Show current state
/tackle --gate approve          Approve current gate
/tackle --gate reject           Return to previous phase
/tackle --abort                 Abandon tackle, clean up
/tackle --refresh               Force refresh upstream research
/tackle --help                  Show all options

When existing PR found:
/tackle --apply-pr <number>     Apply upstream PR locally
/tackle --wait-upstream         Wait for upstream merge
/tackle --implement-anyway      Proceed with own implementation

Upstream management:
/tackle add-upstream <org/repo>     Add upstream to track
/tackle list-upstreams              Show tracked upstreams
/tackle remove-upstream <org/repo>  Remove upstream
```

## Resource Loading (Progressive Disclosure)

**DO NOT load all resource files.** Each contains phase-specific instructions.
Loading unnecessary resources wastes context and may cause confusion.

| Current Step | Load Resource |
|--------------|---------------|
| bootstrap | BOOTSTRAP.md |
| context, existing-pr-check | CONTEXT.md |
| plan, branch, implement | IMPLEMENT.md |
| validate | VALIDATION.md |
| gate-plan, gate-submit | GATES.md (detailed UI below) |
| submit, record | SUBMIT.md |
| retro | RETRO.md |

Check current step with `bd --no-daemon mol current`, then load ONLY the matching resource.

## State Management via Beads Molecules

State persists via beads molecules. The tackle formula is shipped with this skill
and installed to the rig's `.beads/formulas/` on first use.

**Molecule workflow:**
```bash
# Create molecule (requires --no-daemon)
bd --no-daemon mol pour tackle --var issue=<id>
# Returns: Root issue: gt-mol-xxxxx

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
Bootstrap → Context → [Existing PR Check] → Plan → GATE:Plan → Branch → Implement → Validate → GATE:Submit → Submit → Record → Retro
                              ↓                                                                                              ↑
                    [--apply-pr | --wait-upstream | --implement-anyway]                                            (can defer until PR merged)
```

## Execution Instructions

### Parse Command

First, parse what the user wants:

| Input | Action |
|-------|--------|
| `/tackle <id>` | Start or resume tackle for issue |
| `/tackle --status` | Show current tackle state via `bd --no-daemon mol current` |
| `/tackle --gate approve` | Approve current gate, proceed |
| `/tackle --gate reject` | Reject, return to previous phase |
| `/tackle --abort` | Abandon tackle, clean up molecule and branch |
| `/tackle --refresh` | Force refresh upstream research |
| `/tackle --apply-pr <n>` | Apply upstream PR #n locally |
| `/tackle --wait-upstream` | Mark blocked on upstream PR |
| `/tackle --implement-anyway` | Skip existing PR, implement fresh |
| `/tackle add-upstream <org/repo>` | Add upstream to track |
| `/tackle list-upstreams` | List tracked upstreams |
| `/tackle remove-upstream <org/repo>` | Remove tracked upstream |
| `/tackle --help` | Show help |

### Starting New Tackle

When starting `/tackle <issue-id>`:

1. **First-time setup**: Install formula if not present (see BOOTSTRAP.md)
2. **Check for attached molecule**: `gt mol status` shows attached molecule if present
3. **If attached**: Resume with `bd --no-daemon mol current`, `bd ready`
4. **If new**: Create and attach molecule:
   ```bash
   # Create molecule (note: requires --no-daemon)
   bd --no-daemon mol pour tackle --var issue=<issue-id>
   # Returns molecule ID like gt-mol-xxxxx

   # Attach molecule (auto-detects your agent bead from cwd)
   gt mol attach <molecule-id>
   # If "not pinned" error: see molecule workflow section above
   ```

### Phase Execution

Based on current step (from `bd --no-daemon mol current`), load the appropriate resource:

| Step ID | Load Resource | Then |
|---------|---------------|------|
| `bootstrap` | `resources/BOOTSTRAP.md` | Check/refresh upstream research |
| `context` | `resources/CONTEXT.md` | Search upstream, check for existing PRs |
| `existing-pr-check` | `resources/CONTEXT.md` | Present options if PR found |
| `plan` | `resources/IMPLEMENT.md` | Create implementation plan |
| `gate-plan` | `resources/GATES.md` | **STOP** - Wait for approval |
| `branch` | `resources/IMPLEMENT.md` | Create clean branch |
| `implement` | `resources/IMPLEMENT.md` | Write code |
| `validate` | `resources/VALIDATION.md` | Run tests, check isolation |
| `gate-submit` | `resources/GATES.md` | **STOP** - Wait for approval |
| `submit` | `resources/SUBMIT.md` | Mark PR ready |
| `record` | `resources/SUBMIT.md` | Record outcome |
| `retro` | `resources/RETRO.md` | Reflect on skill issues (see below) |

## MANDATORY APPROVAL GATES

**CRITICAL SAFETY RULE - READ THIS SECTION COMPLETELY**

There are TWO mandatory gates that require explicit human approval:

### Gate 1: `gate-plan` (after plan creation)

```
╔═══════════════════════════════════════════════════════════════════╗
║  🛑  MANDATORY STOP - GATE: Plan Review                           ║
║                                                                   ║
║  DO NOT PROCEED until user explicitly approves.                   ║
║                                                                   ║
║  Present the plan, then STOP and WAIT.                            ║
║                                                                   ║
║  Approval required:                                               ║
║    /tackle --gate approve   OR   "approve", "yes", "lgtm"         ║
║                                                                   ║
║  To reject and revise:                                            ║
║    /tackle --gate reject    OR   "reject", "no", "revise"         ║
╚═══════════════════════════════════════════════════════════════════╝
```

### Gate 2: `gate-submit` (before PR submission)

```
╔═══════════════════════════════════════════════════════════════════╗
║  🛑  MANDATORY STOP - GATE: Pre-Submit Review                     ║
║                                                                   ║
║  DO NOT SUBMIT PR until user explicitly approves.                 ║
║                                                                   ║
║  1. Push branch to origin for review                              ║
║  2. Create draft PR on origin (or provide compare URL)            ║
║  3. Show PR link so user can review on GitHub                     ║
║  4. STOP and WAIT for approval                                    ║
║                                                                   ║
║  Approval required:                                               ║
║    /tackle --gate approve   OR   "approve", "submit", "ship it"   ║
║                                                                   ║
║  To reject and revise:                                            ║
║    /tackle --gate reject    OR   "reject", "wait", "hold"         ║
╚═══════════════════════════════════════════════════════════════════╝
```

**Pre-submit review workflow:**
```bash
# Push branch to origin (your fork)
git push -u origin <branch-name>

# Create draft PR directly on UPSTREAM (visible but not ready for review)
gh pr create --repo <upstream-org>/<upstream-repo> --draft \
  --head <fork-owner>:<branch-name> --title "<title>" --body "<body>"

# Get the PR URL for review
PR_URL=$(gh pr view --repo <upstream-org>/<upstream-repo> --json url --jq '.url')
```

This creates the actual PR on upstream as a draft. You can review exactly what will be submitted. On approval, we mark the draft as "ready for review" with `gh pr ready`.

### Gate Rules (NEVER VIOLATE)

1. **NEVER** proceed past a gate without explicit user approval
2. **NEVER** auto-approve based on heuristics or timeouts
3. **NEVER** submit a PR without gate-submit approval
4. **ALL agents** (mayor, crew, polecats) stop at gates - no exceptions
5. If no human in loop, **WAIT INDEFINITELY** at the gate

See `resources/GATES.md` for gate UI formatting details.

## Retrospective (Quick Reference)

The `retro` step captures issues with the tackle process itself (not task-specific problems).

**If the run was smooth** - no need to load RETRO.md:
```bash
bd close <retro-step-id> --reason "Clean run - no issues"
```

**If there were issues** - load RETRO.md for full guidance:
- **Fix immediately**: Objective errors (wrong flags, syntax errors)
- **Log to journal**: Subjective friction (confusing steps, systemic issues that tackle could help prevent)

Journal tracks patterns. Only propose fixes for subjective issues after 2+ occurrences.

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

Priority for detecting upstream:
1. Git remote named `upstream`
2. Git remote named `fork-source`
3. Origin (if not a fork)

```bash
git remote -v | grep -E '^(upstream|fork-source|origin)' | head -1
```

## Resource Loading

Resources are in the `resources/` folder relative to this SKILL.md file.

When you loaded this skill, note the directory path. Resources are at:
- `<skill-dir>/resources/BOOTSTRAP.md`
- `<skill-dir>/resources/CONTEXT.md`
- `<skill-dir>/resources/GATES.md`
- `<skill-dir>/resources/IMPLEMENT.md`
- `<skill-dir>/resources/VALIDATION.md`
- `<skill-dir>/resources/SUBMIT.md`
- `<skill-dir>/resources/RETRO.md`
- `<skill-dir>/resources/tackle.formula.toml`

Only load the resource needed for the current phase to minimize context.

On first use, BOOTSTRAP copies the formula to the rig's `.beads/formulas/`.

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
- Gate approvals: plan ✓, submit pending

### Next Action
<what the next session should do>
```

### Resuming After Handoff

1. Check molecule status: `bd --no-daemon mol current`
2. Check for existing PR: `gh pr list --head <branch-name>`
3. If PR exists, don't recreate - just continue from current step
4. Load the appropriate resource for the current step

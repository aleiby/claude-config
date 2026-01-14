# Claude Code Session Best Practices

Global best practices and patterns for working effectively with Claude Code across projects.

## Table of Contents
- [Landing the Plane (Session Completion)](#landing-the-plane-session-completion)
- [Issue Tracking Best Practices](#issue-tracking-best-practices)
- [Code Quality Principles](#code-quality-principles)
- [Testing and Verification](#testing-and-verification)

---

## Landing the Plane (Session Completion)

**CRITICAL**: Work is NOT complete until changes are pushed to the remote repository.

### Mandatory Workflow

When ending a work session, you MUST complete ALL steps below:

1. **File issues for remaining work**
   - Create issues for anything that needs follow-up
   - Document blockers or dependencies discovered during the session
   - Use `bd create` for actionable work items

2. **Run quality gates** (if code changed)
   - Run tests: `npm test`, `pytest`, etc.
   - Run linters: `eslint`, `ruff`, etc.
   - Run builds: `npm run build`, `cargo build`, etc.
   - Fix any failures before proceeding

3. **Update issue status**
   - Close finished work: `bd close <id1> <id2> ...`
   - Update in-progress items with current state
   - Add any discovered dependencies

4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync              # If using beads
   git push
   git status           # MUST show "up to date with origin"
   ```

5. **Clean up**
   - Clear stashes: `git stash clear` (if appropriate)
   - Remove temporary branches
   - Delete temporary files or test fixtures

6. **Verify**
   - All changes committed: `git status` shows clean tree
   - All changes pushed: `git status` shows "up to date with origin"
   - No orphaned work left on local machine

7. **Hand off**
   - Provide context for next session
   - Document any complex state or decisions
   - Note any environment-specific setup required

8. **Learn from session** (optional but recommended)
   - Run `autoskill` to analyze corrections and preferences
   - Propose skill updates based on patterns observed
   - Document new workflows or techniques discovered

### Critical Rules

- **Work is NOT complete until `git push` succeeds**
- **NEVER stop before pushing** - that leaves work stranded locally
- **NEVER say "ready to push when you are"** - YOU must push
- **If push fails, resolve and retry until it succeeds**
- Don't batch multiple sessions before pushing - push after each session

### Why This Matters

Local-only work is:
- Lost if the machine fails or is reset
- Invisible to collaborators and CI/CD
- Not backed up to remote repositories
- Creates merge conflicts when multiple sessions accumulate
- Defeats the purpose of version control

---

## Issue Tracking Best Practices

### General Principles

**Track strategic work in issues, not in code comments.**

Issues are:
- Searchable and discoverable
- Tracked over time with history
- Can have dependencies and relationships
- Visible to the entire team
- Integrated with git workflow

### No TODOs in Code

**Rule**: Use issue tracker instead of TODO/FIXME comments in code.

```bash
# ❌ BAD: TODO comment
# TODO: Add error handling for edge case

# ✅ GOOD: Create tracked issue
bd create --title="Add error handling for edge case" --type=task
```

**Exception**: Brief contextual comments are fine when they're not actionable work items:
```python
# ✅ OK: Contextual note
api_key = None  # Set after deployment
```

**Why?**
- Inline comments get lost and forgotten
- Issues are tracked, searchable, and have dependencies
- Issues can be prioritized and assigned
- Issues integrate with CI/CD and project management

### Labels for Grouping Related Issues

Use labels to organize and discover related work:

```bash
# Add labels for logical grouping
bd label add <issue-id> frontend
bd label add <issue-id> backend
bd label add <issue-id> security
bd label add <issue-id> performance

# Find issues by label
bd list --label=frontend

# View all labels in use
bd label list-all
```

**Common label patterns:**
- **Component labels**: `frontend`, `backend`, `database`, `api`
- **Technology labels**: `react`, `python`, `rust`, `docker`
- **Type labels**: `refactor`, `documentation`, `testing`
- **Status labels**: `blocked`, `needs-review`, `urgent`

**Documenting related work:**
If closing an issue should trigger review of related issues, document this in the issue description:

```
On close: Review related issues with label:security for consistency
```

### Future Work Gate Pattern

**Problem**: You don't want future/deferred work cluttering your "ready" list.

**Solution**: Create a "Future Work Gate" issue that blocks all deferred work.

```bash
# One-time setup: Create the gate
bd create --title="Future Work Gate - Review before starting deferred items" \
  --type=epic --priority=3

# Note the issue ID (e.g., project-123)

# When creating future work, add dependency
bd create --title="Implement feature X" --type=feature --priority=3
bd dep add <new-issue-id> project-123  # New issue depends on gate
```

**Benefits:**
- Future work is tracked but doesn't appear in `bd ready`
- You can review all deferred work: `bd list --blocked`
- When ready to start future work, remove the dependency
- Prevents scope creep and maintains focus

### Issue Hygiene

**Create specific, actionable issues:**
```bash
# ❌ TOO VAGUE
bd create --title="Fix bugs"

# ✅ SPECIFIC
bd create --title="Fix login error when password contains special characters"
```

**Use appropriate priorities:**
- **0 (P0)**: Critical - system down, data loss, security breach
- **1 (P1)**: High - major feature broken, significant user impact
- **2 (P2)**: Medium - normal bugs and features (default)
- **3 (P3)**: Low - minor issues, nice-to-haves
- **4 (P4)**: Backlog - future considerations

**Close issues promptly:**
```bash
# Close multiple issues at once (more efficient)
bd close <id1> <id2> <id3>

# Add reason if not obvious
bd close <id> --reason="Fixed by upstream library update"
```

---

## Code Quality Principles

### Verify with Metrics, Not Narratives

**Rule**: When checking test results or system behavior, verify quantitative metrics first.

**Why?**
- Message logs may be historical, cached, or misleading
- Test output can show old results from previous runs
- Chat messages or UI feedback might not reflect current state

**Examples:**

```bash
# ✅ GOOD: Check quantitative metrics
npm test | grep "Tests: 25 passed"
echo $?  # Check exit code (0 = success)

# ❌ BAD: Relying only on narrative
# "I see test messages in the output" (might be cached)
```

```python
# ✅ GOOD: Verify counts and values
assert len(results) == expected_count
assert game.rounds_played > 0

# ❌ BAD: Trusting only log messages
# "Rounds played: 0" but logs say "Game in progress"
```

**What to verify:**
- Exit codes: `$?` in bash, return values in code
- Counts: items processed, tests passed, records created
- Timing: duration, timestamps, sequence
- File existence: `[ -f file ]`, not just "should be created"
- Process state: `ps`, `systemctl status`, not assumptions

### Start Simple, Add Complexity Only When Needed

**Rule**: Begin with the simplest solution that could work. Don't add defensive logic, validation, or abstraction until there's a demonstrated need.

**Why?**
- Premature complexity is harder to understand, debug, and maintain
- Downstream consumers (agents, tools, users) can handle edge cases
- Simple solutions reveal actual requirements faster than complex ones
- Over-defensive code wastes time solving problems that may never occur

**Common overengineering patterns to avoid:**

❌ **Pre-validation before delegation:**
```bash
# BAD: Check if files exist before asking agent to create them
if [ ! -f README.md ]; then
  create_readme_task
fi

# GOOD: Delegate the check to the task itself
create_task "Create README.md (if missing)"
```

❌ **Defensive error handling for impossible cases:**
```python
# BAD: Handling errors that can't happen
try:
    user = get_authenticated_user()  # Already validated by middleware
    if user is None:
        raise Exception("User should never be None here!")
except Exception as e:
    log_error(e)
    # Complex recovery logic...

# GOOD: Trust the system invariants
user = get_authenticated_user()
```

❌ **Abstraction for single use:**
```javascript
// BAD: Creating helpers for one-time operations
function buildWorktreePathForIssue(root, issueId) {
  return `${root}/.worktrees/${issueId}`;
}
const path = buildWorktreePathForIssue(root, id);

// GOOD: Inline it
const path = `${root}/.worktrees/${issueId}`;
```

**When to add complexity:**
- After the simple version fails in practice
- When the pattern repeats 3+ times
- When the cost of the problem exceeds the cost of the solution
- When requirements explicitly demand it

**In practice:**
1. Try the obvious solution first
2. If it fails, understand why before adding guards
3. Let agents/tools handle their own edge cases
4. Trust explicit requirements over imagined scenarios

---

## Testing and Verification

### Test-Driven Verification

**Before implementing a fix:**
1. Write or run a test that reproduces the bug
2. Verify the test fails
3. Implement the fix
4. Verify the test passes
5. Run full test suite to check for regressions

### Quality Gates

**Establish project-specific quality gates:**

```bash
# Example quality gate script
#!/bin/bash
set -e  # Exit on first failure

echo "Running quality gates..."

# Tests
npm test

# Linting
npm run lint

# Type checking
npm run type-check

# Build
npm run build

echo "✅ All quality gates passed"
```

**Run before:**
- Committing code
- Creating pull requests
- Ending a session (Landing the Plane)
- Deploying to production

### Ad-hoc Verification

**For quick checks that don't need permanent tests:**

Create temporary test scripts in appropriate directories:
- `e2e/verify-*.spec.ts` for Playwright checks
- `scripts/verify-*.sh` for shell checks
- `tests/tmp/` for temporary unit tests

**Cleanup rule**: Delete one-off verification scripts after use. Keep only scripts useful for recurring checks (smoke tests, regression verification).

---

## Additional Resources

- **Beads Setup**: `~/.claude/guides/beads-setup-guide.md`
- **Parallel Work**: `~/.claude/skills/parallel-work/SKILL.md`
- **Project-specific**: `CLAUDE.md` in each repository

---

*This guide is maintained at: `~/.claude/guides/session-best-practices.md`*

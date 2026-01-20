# Context Phase

Search upstream for related work. Present context, NOT suggestions.

## Steps

### 1. Load Issue Details

Get the issue being tackled:
```bash
bd show <issue-id>
```

Extract: title, description, type, any labels/tags.

### 2. Setup Variables from Bootstrap

If resuming after handoff, re-extract upstream info and detect default branch:

```bash
# Detect upstream (same as bootstrap)
UPSTREAM=$(git remote -v | grep -E '^upstream\s' | head -1 | awk '{print $2}')
if [ -z "$UPSTREAM" ]; then
  UPSTREAM=$(git remote -v | grep -E '^fork-source\s' | head -1 | awk '{print $2}')
fi
if [ -z "$UPSTREAM" ]; then
  UPSTREAM=$(git remote -v | grep -E '^origin\s' | head -1 | awk '{print $2}')
fi

# Extract org/repo
ORG_REPO=$(echo "$UPSTREAM" | sed -E 's#.*github.com[:/]([^/]+/[^/]+)(\.git)?$#\1#')

# Detect default branch (same as IMPLEMENT.md and VALIDATION.md)
DEFAULT_BRANCH=$(git remote show upstream 2>/dev/null | grep 'HEAD branch' | cut -d: -f2 | xargs)
if [ -z "$DEFAULT_BRANCH" ]; then
  DEFAULT_BRANCH=$(git remote show origin | grep 'HEAD branch' | cut -d: -f2 | xargs)
fi
UPSTREAM_REF="upstream/$DEFAULT_BRANCH"
```

### 3. Load Research Cache

Get cached research from the cache bead (created in bootstrap):

```bash
# Fast path: Check config for cached bead ID
CACHE_BEAD=$(yq ".tackle.cache_beads[\"$ORG_REPO\"]" .beads/config.yaml 2>/dev/null)

# Fallback: Label search if not in config
if [ -z "$CACHE_BEAD" ] || [ "$CACHE_BEAD" = "null" ]; then
  CACHE_BEAD=$(bd list --label=tackle-cache --title-contains="$ORG_REPO" --json | jq -r '.[0].id // empty')
fi

# Load research data from bead description
RESEARCH=$(bd show "$CACHE_BEAD" --json | jq -r '.[0].description')
```

Extract from cached research:
- `open_issues_json`: for fuzzy issue matching
- `open_prs_json`: for fuzzy PR matching
- `guidelines`: for implementation conventions

### 4. Check Fork Status

```bash
git fetch upstream 2>/dev/null || git fetch origin

# Commits behind upstream
git rev-list --count HEAD..$UPSTREAM_REF
```

### 5. Recent Commits Ahead of Fork

```bash
git log --oneline HEAD..$UPSTREAM_REF | head -20
```

Review these commits for:
- Fixes related to our issue
- Changes in files we plan to modify
- New patterns/conventions

### 6. Fuzzy Search for Related Issues

From cached `open_issues_json` in research bead, find issues with:
- Similar keywords in title
- Overlapping labels
- Similar description terms

```bash
# Parse open_issues_json from research cache
echo "$RESEARCH" | yq '.open_issues_json' | jq '.[] | select(.title | test("keyword"; "i"))'
```

### 7. Fuzzy Search for Related PRs

From cached `open_prs_json`, find PRs that:
- Touch similar files
- Have similar titles
- Address related concerns

```bash
echo "$RESEARCH" | yq '.open_prs_json' | jq '.[] | select(.title | test("keyword"; "i"))'
```

### 8. Check for Existing Fix

**Critical**: If a highly-relevant open PR exists that would fix our issue:

1. Transition to `existing-pr-check` phase
2. Present decision point (see below)

## Existing PR Check

When relevant PR found, present:

```
Found upstream PR #1234 that appears to address this issue:
  Title: Fix doctor indentation
  Status: Open (ready for review)
  Files: cmd/bd/doctor/database.go

Options:
  /tackle --apply-pr 1234      Apply this PR locally and test
  /tackle --wait-upstream      Wait for upstream merge (marks issue blocked)
  /tackle --implement-anyway   Proceed with our own implementation
```

### --apply-pr <number>

1. Fetch the PR branch:
   ```bash
   gh pr checkout <number> --repo <upstream>
   ```

2. Run tests (use command from cached guidelines):
   ```bash
   # From research.guidelines.testing.commands
   go test ./...
   ```

3. If tests pass:
   - Report success
   - Offer to close local issue (upstream PR solves it)
   - No new PR needed

4. If tests fail:
   - Report failures
   - Offer to fix issues or implement fresh

### --wait-upstream

1. Update issue status:
   ```bash
   bd update <issue-id> --status=blocked --notes="Blocked on upstream PR #1234"
   ```

2. Skill pauses. Can resume when PR merges.

### --implement-anyway

1. Note the existing PR for reference
2. Continue to plan phase
3. May want to coordinate with existing PR author

## Context Output

Present as **context only**, never suggestions:

```
## Upstream Context for <issue-id>

**Fork Status:**
Your fork is 12 commits behind upstream/main.

**Recent relevant commits:**
- abc1234 (3 days ago): "fix(doctor): improve error messages"
- def5678 (5 days ago): "refactor(cmd): standardize output"

**Related Issues:**
- #1234: "Doctor output formatting" (open) - similar area
- #1230: "CLI improvements" (closed) - may have patterns

**Related PRs:**
- #1235: "Fix doctor indentation" (open, draft)

**Guidelines (from CONTRIBUTING.md):**
- Commit format: present tense, max 72 chars
- Testing: `go test ./...`
- PR requires: description, test plan

This is context to inform your approach.
You are working on YOUR assigned issue: <issue-id>
```

## Never Do This

```
## Recommended Issues  <-- NEVER
- #1234 looks like a good starting point!  <-- NEVER
- Consider working on #1230 first  <-- NEVER
```

## Advance to Next Step

After context phase:
```bash
bd close <context-step-id> --continue
```

Use `bd ready` to find the next step (plan or existing-pr-check).

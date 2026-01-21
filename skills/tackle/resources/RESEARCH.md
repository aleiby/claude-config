# Project-Level Research

This resource handles **project-level research** - information about the upstream project that applies to all issues and can be cached for reuse.

**Issue-specific research** (is this issue already solved?) is handled in SKILL.md before molecule creation.

---

## Section 1: First-Time Setup

### Install Formula

On first use in a rig, install the tackle formula.

```bash
# Check if installed
bd formula list | grep -q "^tackle " && echo "installed" || echo "not installed"
```

If not installed, copy from skill folder:

```bash
FORMULA_SRC="<skill-dir>/resources/tackle.formula.toml"

# Follow redirect if present to find shared .beads location
if [ -f ".beads/redirect" ]; then
  BEADS_DIR=$(cat .beads/redirect)
  BEADS_DIR=$(cd .beads && cd "$BEADS_DIR" && pwd)
else
  BEADS_DIR=".beads"
fi

FORMULA_DST="$BEADS_DIR/formulas/tackle.formula.toml"

if [ ! -f "$FORMULA_DST" ]; then
  mkdir -p "$BEADS_DIR/formulas"
  cp "$FORMULA_SRC" "$FORMULA_DST"
  echo "Installed tackle formula to $BEADS_DIR/formulas/"

  # Add to .gitignore if not already present
  if ! grep -q "formulas/tackle.formula.toml" "$BEADS_DIR/.gitignore" 2>/dev/null; then
    echo "formulas/tackle.formula.toml" >> "$BEADS_DIR/.gitignore"
  fi
fi
```

---

## Section 2: Refresh Research

### Fetch CONTRIBUTING.md

```bash
CONTRIB_PATH=$(gh api repos/$ORG_REPO/contents/CONTRIBUTING.md --jq '.path' 2>/dev/null || echo "")
if [ -n "$CONTRIB_PATH" ]; then
  CONTRIB_CONTENT=$(gh api repos/$ORG_REPO/contents/CONTRIBUTING.md --jq '.content' | base64 --decode 2>/dev/null || base64 -d)
fi
```

### Fetch PRs and Issues

```bash
RECENT_PRS=$(gh pr list --repo $ORG_REPO --state merged --limit 10 --json number,title,additions,deletions)
OPEN_PRS=$(gh pr list --repo $ORG_REPO --state open --json number,title,headRefName)
OPEN_ISSUES=$(gh issue list --repo $ORG_REPO --state open --limit 30 --json number,title,labels)
```

### Distill Guidelines

Parse CONTRIBUTING.md and extract actionable requirements:

```yaml
upstream: steveyegge/beads
contributing_path: CONTRIBUTING.md

guidelines:
  coding_style:
    formatter: gofmt
    linter: go vet
  commits:
    tense: present
    max_length: 72
    reference_format: "(issue-id)"
  pull_requests:
    required_sections:
      - description
      - test plan
  testing:
    commands:
      - go test ./...
  build:
    command: go build ./...
  critical_rules:
    - "Run tests before submitting"
    - "Keep PRs focused and small"

patterns:
  avg_pr_size: 75
  reviewer: steveyegge

# Raw caches for fuzzy matching (used by issue-specific research)
open_issues_json: |
  [...]
open_prs_json: |
  [...]
```

### Create or Update Cache Bead

```bash
NOW=$(date -Iseconds)

if [ -z "$CACHE_BEAD" ]; then
  CACHE_BEAD=$(bd create \
    --title "Upstream research: $ORG_REPO" \
    --type task \
    --status deferred \
    --label tackle-cache \
    --external-ref "upstream:$ORG_REPO" \
    --description "$RESEARCH_YAML" \
    --notes "last_checked: $NOW" \
    --json | jq -r '.id')
  echo "Created cache bead: $CACHE_BEAD"

  # Store bead ID in config for fast lookup
  # Add to .beads/config.yaml under tackle.cache_beads
else
  bd update "$CACHE_BEAD" --description "$RESEARCH_YAML" --notes "last_checked: $NOW"
  echo "Updated cache bead: $CACHE_BEAD"
fi
```

---

## Section 3: Related Upstream Discovery

Parse the upstream README for dependencies or related projects:

```bash
# Fetch README
README=$(gh api repos/$ORG_REPO/contents/README.md --jq '.content' 2>/dev/null | base64 --decode 2>/dev/null || echo "")

# Look for dependencies/requirements sections
# Parse for github.com links or org/repo patterns
```

Present any related upstreams found for user review (see Section 5: Project Report below).

---

## Section 4: Project Research Output

After project research completes, report:

```
Upstream: steveyegge/beads
Research cache: hq-abc123 (refreshed 2h ago | refreshed now)
Guidelines: CONTRIBUTING.md found
```

Then continue to Project Report (Section 5) if new data was found, otherwise skip to Issue Research (step 6 in Starting Tackle).

---

## Section 5: Project Report

**CHECKPOINT** - Only present if new data was found.

When cache is fresh or no new data was found, this step is skipped. Only present when there's new research to review.

```
┌────────────────────────────────────────────────────────────────────┐
│  🔍 CHECKPOINT: Contribution Research                              │
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

If user wants to add related upstreams, fetch research for them first. Then continue to Issue Research (step 6 in Starting Tackle).

---

## Section 6: Using Cached Research

When planning implementation, reference the cached research:

```bash
RESEARCH=$(bd show "$CACHE_BEAD" --json | jq -r '.[0].description')
```

Use this to inform your approach - guidelines, conventions, patterns.

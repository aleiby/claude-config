# Beads Setup Guide

This guide helps you set up Beads (bd) issue tracking in any project. Beads is an AI-native, git-integrated issue tracker designed for modern development workflows.

## When to Use This Guide

Reference this when:
- Setting up Beads in a new project
- A skill requires Beads but it's not installed/initialized
- You need to configure Claude Code integration with Beads

## Prerequisites Check

Before starting, verify your environment:

```bash
# Check if bd is installed
which bd && bd --version

# Check if this is a git repository
git rev-parse --git-dir

# Check if beads is already initialized
[ -d .beads ] && echo "Already initialized" || echo "Not initialized"
```

## Installation

### Install Beads (if not already installed)

```bash
# Official installation script
curl -sSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash

# Verify installation
bd --version
```

Alternative installation methods:
- **Homebrew**: `brew install steveyegge/tap/bd`
- **Manual**: Download from [github.com/steveyegge/beads/releases](https://github.com/steveyegge/beads/releases)

## Project Initialization

### 1. Initialize Beads in Your Repository

```bash
# Must be in a git repository
cd /path/to/your/project

# Initialize beads
# If directory name has hyphens, sanitize the prefix (remove hyphens)
# Example: my-new-project → mynewproject
DIRNAME=$(basename $(pwd))
if [[ "$DIRNAME" == *"-"* ]]; then
  SANITIZED="${DIRNAME//-/}"
  bd init --prefix "$SANITIZED"
  echo "Initialized with prefix: $SANITIZED (sanitized from $DIRNAME)"
else
  bd init
fi

# This creates:
# - .beads/ directory with configuration and database
# - AGENTS.md with workflow instructions
# - Initial configuration files
```

**Important:** Hyphens in issue prefixes cause compatibility issues with some beads-based tools (e.g., Gas Town). The prefix is based on the directory name, so if your directory has hyphens, use `--prefix` to specify a sanitized version without hyphens.

### 2. Install Git Hooks

Install git hooks for automatic sync:

```bash
bd hooks install
```

This installs hooks for:
- `pre-commit` - Flushes pending changes to JSONL before commit
- `post-merge` - Imports updated JSONL after pull/merge
- `pre-push` - Prevents pushing stale JSONL
- `post-checkout` - Imports JSONL after branch checkout
- `prepare-commit-msg` - Adds agent identity trailers

Verify installation:
```bash
bd hooks list
```

### 3. Set Up Claude Code Integration

```bash
bd setup claude
```

**What this does:**
- Creates startup hooks that auto-inject beads workflow context
- Runs `bd prime` at session start when `.beads/` directory detected
- Ensures Claude always has current beads workflow knowledge
- Safe to run multiple times (will reinstall or report already installed)

### 4. Set Up CLAUDE.md (Recommended)

Create `CLAUDE.md` in your project root to guide Claude Code sessions:

```bash
# Check if CLAUDE.md already exists
if [ -f CLAUDE.md ]; then
  echo "CLAUDE.md exists - review and merge template sections manually"
  echo "Template: ~/.claude/guides/templates/CLAUDE.md"
else
  # Copy the template
  cp ~/.claude/guides/templates/CLAUDE.md ./CLAUDE.md
  echo "CLAUDE.md created from template"
fi

# View the template
cat ~/.claude/guides/templates/CLAUDE.md
```

**What's included in the template:**
- Beads commands reference
- Session Completion Protocol (Landing the Plane)
- Critical rules that MUST be followed
- Placeholders for project-specific content

**After copying, customize:**
1. Add your project's quality gates (tests, linters, build commands)
2. Document architecture and key components
3. Define common labels for your project
4. Add project-specific code style guidelines

**Why CLAUDE.md matters:**
- Always loaded at session start - ensures critical rules are seen
- Project-specific guidance in one place
- Helps Claude understand your workflow and conventions

### 5. Verify and Fix Issues

Run the doctor command to check for any remaining issues:

```bash
# Check for issues
bd doctor

# Automatically fix any issues found
bd doctor --fix

# Or fix with confirmation for each issue
bd doctor --fix -i
```

**Common issues fixed:**
- Missing git hooks
- Plugin version mismatches
- Sync divergences
- Uncommitted changes
- Missing upstream configuration

## Verification

After setup, verify everything works:

```bash
# Check beads status
bd list

# Verify basic functionality
bd create --title "Verify beads setup" --type task
bd close <issue-id>

# Create test issues for parallel work validation
bd create --title "Create README.md with project description (if missing)" --type task
bd create --title "Create .gitignore with common patterns (if missing)" --type task
bd create --title "Add MIT LICENSE file (if missing)" --type task

# Note: If using /parallel-work skill, add .worktrees/ to .gitignore
# The skill creates worktrees in .worktrees/ directory
echo ".worktrees/" >> .gitignore

# Commit test issues
git add . && git commit -m "Add test issues for parallel work"

# Verify git hooks work (should see them run during commit)
git status

# Check ready issues
bd ready
# Should show 3 issues ready to work
```

**To test parallel work execution:**
If you have the `/parallel-work` skill installed, run it now:
```bash
# In Claude Code
> /parallel-work
```

This will create git worktrees for each issue and spawn parallel agents to work on all 3 simultaneously.

## Common Workflows

### Creating Your First Issues

```bash
# Create a task
bd create --title "Add authentication" --type task --priority 2

# Create a bug
bd create --title "Fix login error" --type bug --priority 1

# Create a feature
bd create --title "Dark mode support" --type feature --priority 3
```

**Priority levels**: 0 (critical), 1 (high), 2 (medium), 3 (low), 4 (backlog)

### Working on Issues

```bash
# Find available work (no blockers)
bd ready

# View issue details
bd show <issue-id>

# Start working
bd update <issue-id> --status in_progress

# Complete work
bd close <issue-id>
```

### Managing Dependencies

```bash
# Add dependency (issue-A depends on issue-B)
bd dep add <issue-A-id> <issue-B-id>

# View blocked issues
bd blocked

# See what's blocking an issue
bd show <issue-id>
```

### Labels and Organization

```bash
# Add labels for grouping
bd label add <issue-id> frontend
bd label add <issue-id> backend

# Find issues by label
bd list --label=frontend

# View all labels in use
bd label list-all
```

### Session Completion (Landing the Plane)

**Critical**: Always complete the full session workflow when ending your work.

```bash
# 1. Close completed issues
bd close <id1> <id2> <id3>

# 2. Run quality gates (if code changed)
npm test && npm run lint && npm run build

# 3. Push everything
git pull --rebase
bd sync
git push
git status  # Must show "up to date with origin"
```

**See detailed workflow**: `~/.claude/guides/session-best-practices.md#landing-the-plane-session-completion`

**Critical rules:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- If push fails, resolve and retry until it succeeds

## Advanced Configuration

### Custom Workflow Context

Override default `bd prime` output with project-specific context:

```bash
# Create custom prime output
cat > .beads/PRIME.md << 'EOF'
# Project-Specific Beads Workflow

[Your custom instructions here]

Run `bd onboard --export` to see default template
EOF
```

### Disable Git Operations (Stealth Mode)

If you want manual control over when commits happen:

```bash
bd config set no-git-ops true
```

This prevents `bd prime` from including git commands in session close protocol.

## Troubleshooting

### Issue: "bd command not found"

```bash
# Check PATH
echo $PATH | grep -o "$HOME/.local/bin"

# If not in PATH, add to shell config
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Issue: Git hooks not running

```bash
# Reinstall hooks
bd hooks install

# Verify they're executable
ls -la .git/hooks/ | grep -E "(pre-commit|prepare-commit-msg)"
chmod +x .git/hooks/pre-commit
chmod +x .git/hooks/prepare-commit-msg
```

### Issue: Sync conflicts

```bash
# Check sync status
bd sync --status

# Force sync (careful - may lose local changes)
bd sync --force

# If issues persist, check for JSONL merge conflicts
git status | grep issues.jsonl
```

### Issue: Database locked

```bash
# Check for hung processes
ps aux | grep bd

# Kill daemon if needed
bd daemon stop
bd daemon start

# Or use direct mode (bypass daemon)
bd list --no-daemon
```

## Resources

### Local Resources
- **Session Best Practices**: `~/.claude/guides/session-best-practices.md` - Landing the Plane workflow, issue tracking patterns, code quality principles
- **Parallel Work Skill**: `~/.claude/skills/parallel-work/SKILL.md` - Work on multiple issues in parallel

### Official Documentation
- **Beads Documentation**: [github.com/steveyegge/beads](https://github.com/steveyegge/beads)
- **Quick Start**: Run `bd quickstart` in your project
- **Command Reference**: Run `bd --help` or `bd <command> --help`
- **Examples**: [github.com/steveyegge/beads/tree/main/examples](https://github.com/steveyegge/beads/tree/main/examples)

## Integration with Other Tools

### Claude Code Skills

Skills that require Beads (like `/parallel-work`) will check for:
1. `bd` command available in PATH
2. `.beads/` directory exists in project
3. Valid Beads configuration

If any checks fail, they'll reference this guide.

### CI/CD Integration

Add Beads checks to your CI pipeline:

```yaml
# Example GitHub Actions
- name: Check issue tracking
  run: |
    bd list --status=open
    bd blocked  # Fail if blockers exist
```

### IDE Integration

Beads works entirely through CLI, so it integrates with any editor that can run shell commands:
- VSCode: Use terminal or tasks
- Vim/Neovim: Use `:!bd` commands
- Emacs: Use `M-x shell-command`

---

*This guide is maintained at: `~/.claude/guides/beads-setup-guide.md`*

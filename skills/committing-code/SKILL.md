---
name: committing-code
description: Creates clean, atomic commits following Conventional Commits specification. Use when committing code changes, writing commit messages, or when user mentions commit, conventional commits, or atomic commits.
---

# Committing Code

Create well-structured, atomic commits that follow Conventional Commits specification.

**Use this skill when** making commits, writing commit messages, splitting changes into logical units, or following project commit conventions.

**Supporting files:** [CONVENTIONAL-COMMITS.md](references/CONVENTIONAL-COMMITS.md) for commit message format, [ATOMIC-COMMITS.md](references/ATOMIC-COMMITS.md) for splitting changes.

## Quick Start

```bash
# Stage specific changes (not all at once)
git add -p

# Commit with conventional format
git commit -m "feat(parser): add support for array parsing"
```

## Commit Message Format

```text
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Common types:**
| Type | Purpose | SemVer |
|------|---------|--------|
| `feat` | New feature | MINOR |
| `fix` | Bug fix | PATCH |
| `docs` | Documentation only | - |
| `style` | Formatting, whitespace | - |
| `refactor` | Code restructure, no behavior change | - |
| `perf` | Performance improvement | - |
| `test` | Adding/fixing tests | - |
| `chore` | Build, tooling, deps | - |
| `ci` | CI/CD configuration | - |

## Workflow Checklist

When committing, follow these steps:

```
Commit Workflow:
- [ ] Step 1: Review all changes (git diff)
- [ ] Step 2: Identify logical units of work
- [ ] Step 3: Stage changes for first unit (git add -p)
- [ ] Step 4: Write commit message (conventional format)
- [ ] Step 5: Verify commit is atomic (single purpose)
- [ ] Step 6: Repeat for remaining units
```

## Step 1: Review Changes

```bash
git status
git diff
```

Look for mixed concerns:
- Whitespace changes mixed with logic changes
- Multiple unrelated features
- Bug fixes mixed with refactoring

## Step 2: Identify Logical Units

Each commit should be:
- **Single-purpose**: One logical change
- **Complete**: Codebase works after commit
- **Reversible**: Can be reverted independently

**Bad (mixed concerns):**
```text
Add user authentication and fix typo in README and update deps
```

**Good (separate commits):**
```text
feat(auth): add user authentication
docs: fix typo in README
deps: update lodash to 4.17.21
```

## Step 3: Stage Selectively

Use interactive staging to pick specific changes:

```bash
# Stage by hunks
git add -p

# Commands in interactive mode:
# y - stage this hunk
# n - skip this hunk
# s - split into smaller hunks
# e - manually edit hunk
# q - quit
```

## Step 4: Write Commit Message

**Format:**
```text
<type>(<scope>): <imperative description>

<body explaining why, not what>

<footer with references/breaking changes>
```

**Examples:**

Simple fix:
```text
fix(api): handle null response from payment gateway
```

Feature with body:
```text
feat(search): add fuzzy matching for product names

Users frequently misspell product names. Fuzzy matching
improves search success rate by ~40% based on analytics.

Closes #234
```

Breaking change:
```text
feat(api)!: change authentication to OAuth2

BREAKING CHANGE: API now requires OAuth2 tokens instead of
API keys. See migration guide in docs/auth-migration.md.
```

## Step 5: Verify Atomicity

Before finalizing, check:
- [ ] Does this commit do ONE thing?
- [ ] Can it be described in one short sentence?
- [ ] Would reverting it break unrelated features?
- [ ] Are tests passing after this commit?

## Step 6: Repeat

Continue staging and committing remaining logical units.

## Common Patterns

### After Large Refactoring Session

```bash
# You've made many changes. Split them:
git stash                    # Save current state
git stash show -p | head     # Review what you have
git checkout -p stash        # Selectively apply changes
git add -p                   # Stage first logical unit
git commit -m "refactor: ..."
# Repeat until stash is empty
```

### Fix-up Previous Commit

```bash
# Made a mistake in last commit (not yet pushed)
git add <files>
git commit --amend --no-edit

# Or with new message
git commit --amend -m "fix: corrected message"
```

### Interactive Rebase (cleanup before PR)

```bash
# Squash/reorder last N commits
git rebase -i HEAD~N

# In editor:
# pick   abc1234 feat: add feature
# fixup  def5678 fix typo
# squash ghi9012 more changes
```

## Tips

- Write commit messages in **imperative mood** ("add feature" not "added feature")
- Keep subject line under **50 characters**
- Wrap body at **72 characters**
- Reference issues in footer: `Closes #123`, `Fixes #456`
- Breaking changes require exclamation mark (!) or BREAKING CHANGE: footer
- When unsure about scope, omit it: `feat: add new feature`

## Resources

- [Conventional Commits Spec](https://www.conventionalcommits.org/en/v1.0.0/)
- [Atomic Commits Guide](references/ATOMIC-COMMITS.md)
- [Commit Message Format](references/CONVENTIONAL-COMMITS.md)

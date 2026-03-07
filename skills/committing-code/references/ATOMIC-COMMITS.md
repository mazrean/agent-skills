# Atomic Commits (Untangled Commits)

Guide to creating focused, single-purpose commits.

## What is an Atomic Commit?

An atomic commit is:
- **As small as possible, but complete**
- Contains a single, coherent unit of work
- Can stand on its own without dependencies
- Leaves the codebase in a working state

> "A commit is atomic when it's impossible to divide it further."

## Why Atomic Commits Matter

### 1. Easier Debugging

```bash
# Find the commit that introduced a bug
git bisect start
git bisect bad HEAD
git bisect good v1.0.0
# Git will binary search through commits
```

With atomic commits, `git bisect` pinpoints the exact change.

### 2. Simplified Reverting

```bash
# Undo a single feature without affecting others
git revert abc1234
```

Atomic commits can be reverted cleanly without side effects.

### 3. Cleaner Code Review

Reviewers can understand each change in isolation:
- Smaller diffs = faster reviews
- Focused changes = fewer mistakes

### 4. Easier Merging

- Smaller commits = smaller conflicts
- Related changes stay together
- Independent changes can be cherry-picked

### 5. Better Git History

```bash
git log --oneline
# abc1234 feat(auth): add OAuth2 login
# def5678 fix(api): handle null response
# ghi9012 refactor: extract validation logic
```

Each commit tells a clear story.

## Anti-Patterns to Avoid

### Mixed Concerns

**Bad:**
```text
Add authentication, fix typo, update deps
```

This commit:
- Adds a feature
- Fixes documentation
- Updates dependencies

If auth has a bug, reverting also removes the typo fix.

**Good:**
```text
feat(auth): add OAuth2 authentication
docs: fix typo in README
deps: update lodash to 4.17.21
```

### Whitespace Mixed with Logic

**Bad:**
```diff
- function   calculate(x,y){
-   return x+y
- }
+ function calculate(x: number, y: number): number {
+   // Added logging for debugging
+   console.log('Calculating', x, y);
+   return x + y;
+ }
```

Reviewers can't distinguish formatting from logic changes.

**Good (two commits):**
```text
style: apply consistent formatting to calculate function
feat: add debug logging to calculate function
```

### WIP Commits

**Bad:**
```text
WIP
more WIP
fix stuff
final changes hopefully
ok now it works
```

**Good:**
Use interactive rebase before pushing:
```bash
git rebase -i HEAD~5
# Squash WIP commits into meaningful ones
```

## Workflow for Atomic Commits

### 1. Work First, Commit Later

Don't worry about commits while coding. Focus on solving the problem.

```bash
# Code freely
# ...make many changes...

# Then organize into commits
git status
git diff
```

### 2. Review All Changes

```bash
git diff                    # Unstaged changes
git diff --cached           # Staged changes
git diff HEAD              # All changes
```

### 3. Identify Logical Units

Ask yourself:
- What distinct problems did I solve?
- What features did I add?
- What bugs did I fix?
- What refactoring did I do?

### 4. Stage Selectively

#### Using `git add -p` (Interactive)

```bash
git add -p
```

Commands:
| Key | Action |
|-----|--------|
| `y` | Stage this hunk |
| `n` | Skip this hunk |
| `s` | Split into smaller hunks |
| `e` | Manually edit hunk |
| `q` | Quit |
| `?` | Show help |

#### Using `git add -i` (Interactive Mode)

```bash
git add -i
# Choose 'patch' for hunk-by-hunk staging
```

#### Stage Specific Files

```bash
git add path/to/file.go
git add src/auth/*.ts
```

### 5. Commit and Repeat

```bash
git commit -m "feat: first logical change"
git add -p
git commit -m "fix: second logical change"
# Continue until working directory is clean
```

## Advanced Techniques

### Stash Workflow

When you have many interleaved changes:

```bash
# Save everything
git stash

# Selectively restore
git stash show -p              # See what's in stash
git checkout -p stash          # Pick specific changes

# Stage and commit
git add -p
git commit -m "first change"

# Restore more from stash
git checkout -p stash
git add -p
git commit -m "second change"

# Clean up stash when done
git stash drop
```

### Fix-up Commits

When you realize you missed something in a recent commit:

```bash
# Stage the fix
git add path/to/file

# Create fixup commit
git commit --fixup=abc1234

# Later, squash fixups
git rebase -i --autosquash HEAD~5
```

### Interactive Rebase

Clean up history before pushing:

```bash
git rebase -i HEAD~N
```

In editor:
```text
pick abc1234 feat: add feature
fixup def5678 fix typo
squash ghi9012 add tests
reword jkl3456 unclear message
```

| Command | Action |
|---------|--------|
| `pick` | Use commit as-is |
| `reword` | Edit commit message |
| `edit` | Stop to amend commit |
| `squash` | Combine with previous, edit message |
| `fixup` | Combine with previous, discard message |
| `drop` | Delete commit |

### Splitting a Commit

If you already committed mixed changes:

```bash
git rebase -i HEAD~N
# Mark the commit as 'edit'

# Rebase stops at that commit
git reset HEAD~1              # Unstage the commit
git add -p                    # Stage first logical unit
git commit -m "first change"
git add -p                    # Stage second logical unit
git commit -m "second change"
git rebase --continue
```

## Checklist Before Committing

- [ ] Does this commit contain only ONE logical change?
- [ ] Can I describe it in one short sentence?
- [ ] Does the codebase still work after this commit?
- [ ] Are related changes (tests, docs) included?
- [ ] Are unrelated changes excluded?
- [ ] Would reverting this affect only one feature?

## Common Scenarios

### Scenario: Feature + Bug Fix

You fixed a bug while implementing a feature.

```bash
# Stage only the bug fix
git add -p
git commit -m "fix: handle edge case in parser"

# Stage the feature
git add -p
git commit -m "feat: add array parsing support"
```

### Scenario: Refactor Before Feature

You refactored to make the feature easier.

```bash
# Commit refactor first
git add -p
git commit -m "refactor: extract validation to helper"

# Then the feature
git add -p
git commit -m "feat: add input validation"
```

### Scenario: Large Feature

Break into sub-features:

```bash
git commit -m "feat(auth): add OAuth2 provider interface"
git commit -m "feat(auth): implement Google OAuth2 provider"
git commit -m "feat(auth): add OAuth2 callback handler"
git commit -m "test(auth): add OAuth2 integration tests"
```

## Tools

### GUI Clients with Staging

- **GitKraken**: Visual staging of individual lines
- **Sublime Merge**: Powerful hunk editing
- **VS Code Git**: Built-in staging UI
- **GitHub Desktop**: Simple staging interface

### CLI Helpers

- **tig**: Terminal UI for git
- **lazygit**: Terminal UI with staging
- **git-cola**: GUI staging tool

## References

- [How atomic Git commits dramatically increased my productivity](https://dev.to/samuelfaure/how-atomic-git-commits-dramatically-increased-my-productivity-and-will-increase-yours-too-4a84)
- [Make Atomic Git Commits](https://www.aleksandrhovhannisyan.com/blog/atomic-git-commits/)
- [The Power of Atomic Commits in Git](https://dev.to/this-is-learning/the-power-of-atomic-commits-in-git-how-and-why-to-do-it-54mn)

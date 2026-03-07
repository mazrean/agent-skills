# Conventional Commits Specification

Detailed reference for Conventional Commits v1.0.0.

## Message Structure

```text
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Type (Required)

Indicates the kind of change:

| Type | Description | SemVer Impact |
|------|-------------|---------------|
| `feat` | New feature for the user | MINOR bump |
| `fix` | Bug fix for the user | PATCH bump |
| `docs` | Documentation changes only | None |
| `style` | Formatting, whitespace, semicolons (no code change) | None |
| `refactor` | Code restructure without behavior change | None |
| `perf` | Performance improvement | None |
| `test` | Adding or correcting tests | None |
| `build` | Build system or external dependencies | None |
| `ci` | CI configuration files and scripts | None |
| `chore` | Other changes that don't modify src or test | None |
| `revert` | Reverts a previous commit | Varies |

### Scope (Optional)

Noun describing the section of codebase:

```text
feat(parser): add ability to parse arrays
fix(api): handle null response
docs(readme): update installation steps
```

Common scopes:
- Component names: `auth`, `parser`, `router`
- Layer names: `api`, `db`, `ui`
- Feature names: `search`, `checkout`, `user`

### Description (Required)

- Use imperative mood: "add" not "added" or "adds"
- No capitalization at start
- No period at end
- Max 50 characters recommended

**Good:**
```text
feat: add user authentication
fix: prevent race condition in worker
```

**Bad:**
```text
feat: Added user authentication.
fix: Fixes the race condition bug in worker threads
```

### Body (Optional)

- Separated from description by blank line
- Explain **why**, not what (code shows what)
- Wrap at 72 characters
- Can have multiple paragraphs

```text
fix(api): handle null response from payment gateway

The payment gateway occasionally returns null instead of
an error object when the service is degraded. This caused
unhandled exceptions in production.

Added null check and fallback to generic error message.
```

### Footer (Optional)

Used for:
1. **Breaking changes**
2. **Issue references**
3. **Co-authors**

```text
feat(api)!: change response format to JSON:API

BREAKING CHANGE: Response format changed from custom JSON
to JSON:API specification. All clients must update their
parsers.

Closes #123
Reviewed-by: Alice
Co-authored-by: Bob <bob@example.com>
```

## Breaking Changes

Two ways to indicate breaking changes:

### 1. Exclamation Mark

```text
feat!: remove deprecated endpoints
feat(api)!: change authentication method
```

### 2. Footer

```text
feat: change authentication method

BREAKING CHANGE: API now uses OAuth2 instead of API keys.
All existing API keys will be invalidated.
```

Both trigger MAJOR version bump in SemVer.

## Examples by Type

### feat

```text
feat: add email notifications for orders
feat(auth): implement OAuth2 login
feat(search)!: change search API response format

BREAKING CHANGE: search results now return paginated format
```

### fix

```text
fix: correct calculation of shipping costs
fix(parser): handle escaped quotes in strings
fix(db): prevent connection leak on error
```

### docs

```text
docs: add API documentation
docs(readme): update installation instructions
docs(contributing): add code style guidelines
```

### refactor

```text
refactor: extract validation logic to separate module
refactor(auth): simplify token refresh logic
refactor!: rename User to Account across codebase

BREAKING CHANGE: User class renamed to Account
```

### perf

```text
perf: cache database queries for product list
perf(images): lazy load images below fold
```

### test

```text
test: add unit tests for order service
test(e2e): add checkout flow tests
```

### chore

```text
chore: update dependencies
chore(release): bump version to 2.0.0
```

### ci

```text
ci: add GitHub Actions workflow
ci: configure automated releases
```

## Semantic Versioning Integration

Conventional Commits maps directly to SemVer:

| Commit Type | Version Bump | Example |
|-------------|--------------|---------|
| `fix:` | PATCH (0.0.X) | 1.2.3 -> 1.2.4 |
| `feat:` | MINOR (0.X.0) | 1.2.3 -> 1.3.0 |
| BREAKING CHANGE or ! | MAJOR (X.0.0) | 1.2.3 -> 2.0.0 |

## Commit Message Template

Configure git to use a template:

```bash
git config --global commit.template ~/.gitmessage
```

Create `~/.gitmessage`:

```text
# <type>(<scope>): <description>
# |<----  Using a Maximum Of 50 Characters  ---->|

# [optional body]
# |<----   Try To Limit Each Line to 72 Characters   ---->|

# [optional footer(s)]
# - BREAKING CHANGE: <description>
# - Closes #<issue>
# - Co-authored-by: Name <email>

# --- TYPES ---
# feat:     New feature
# fix:      Bug fix
# docs:     Documentation
# style:    Formatting (no code change)
# refactor: Restructure (no behavior change)
# perf:     Performance
# test:     Tests
# build:    Build system
# ci:       CI configuration
# chore:    Other
```

## Validation Tools

- **commitlint**: Lint commit messages in CI
- **husky**: Git hooks for pre-commit validation
- **semantic-release**: Automated versioning based on commits

Example commitlint config (`.commitlintrc.json`):

```json
{
  "extends": ["@commitlint/config-conventional"],
  "rules": {
    "scope-enum": [2, "always", ["api", "ui", "db", "auth"]]
  }
}
```

## References

- [Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)
- [SemVer 2.0.0](https://semver.org/)
- [Angular Commit Guidelines](https://github.com/angular/angular/blob/main/CONTRIBUTING.md#commit)

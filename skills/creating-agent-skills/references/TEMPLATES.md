# Skill Templates

Starter templates for common skill types.

## Basic Skill (Instructions Only)

Minimal skill with just instructions:

```markdown
---
name: my-skill
description: Brief description of what this does. Use when [specific triggers].
---

# My Skill

Brief intro explaining the skill's purpose.

**Use this skill when** [list specific scenarios].

## Quick Start

[Most common use case with example]

## Core Features

### Feature 1
[Instructions]

### Feature 2
[Instructions]

## Tips
- Tip 1
- Tip 2
```

## Skill with References

Skill with supporting documentation:

```markdown
---
name: processing-data
description: Analyzes datasets, generates reports, creates visualizations. Use when working with CSV, Excel, or database exports.
---

# Data Processing

Analyze and transform datasets efficiently.

**Use this skill when** processing tabular data, generating reports, or creating visualizations.

**Supporting files:** [FORMATS.md](references/FORMATS.md) for file formats, [EXAMPLES.md](references/EXAMPLES.md) for common patterns.

## Quick Start

```python
import pandas as pd
df = pd.read_csv("data.csv")
print(df.describe())
```

## Common Tasks

### Load Data
[Brief instructions]

### Clean Data
[Brief instructions]

### Generate Report
[Brief instructions]

## Detailed Guides

**File format handling**: See [FORMATS.md](references/FORMATS.md)
**Example workflows**: See [EXAMPLES.md](references/EXAMPLES.md)
```

## Skill with Scripts

Skill including executable scripts:

```markdown
---
name: validating-forms
description: Validates form data against schemas, checks required fields, reports errors. Use when processing user input or validating configuration files.
---

# Form Validation

Validate form data with automated checks.

**Use this skill when** validating user submissions, checking config files, or ensuring data integrity.

## Quick Start

```bash
python scripts/validate.py input.json schema.json
```

## Workflow

1. **Analyze input**: `python scripts/analyze.py input.json`
2. **Validate**: `python scripts/validate.py input.json schema.json`
3. If errors, fix and re-validate
4. **Only proceed when validation passes**

## Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `analyze.py` | Inspect structure | `python scripts/analyze.py <file>` |
| `validate.py` | Check against schema | `python scripts/validate.py <input> <schema>` |
| `fix.py` | Auto-fix common issues | `python scripts/fix.py <input>` |

## Error Handling

Common validation errors and fixes:

**Missing required field**
```
Error: Field 'email' is required
Fix: Add email field to input
```

**Invalid format**
```
Error: Field 'date' must be ISO8601
Fix: Convert to YYYY-MM-DD format
```
```

## Domain-Specific Skill

Skill organized by domain areas:

```markdown
---
name: querying-databases
description: Writes SQL queries, optimizes performance, manages schemas. Use when working with PostgreSQL, MySQL, or SQLite databases.
---

# Database Queries

Write and optimize SQL queries.

**Use this skill when** writing queries, optimizing performance, or managing database schemas.

## Quick Reference

```sql
SELECT column FROM table WHERE condition;
```

## By Database Type

**PostgreSQL**: See [references/postgres.md](references/postgres.md)
**MySQL**: See [references/mysql.md](references/mysql.md)
**SQLite**: See [references/sqlite.md](references/sqlite.md)

## Common Patterns

### Basic Select
```sql
SELECT name, email FROM users WHERE active = true;
```

### Join Tables
```sql
SELECT u.name, o.total
FROM users u
JOIN orders o ON u.id = o.user_id;
```

### Aggregate
```sql
SELECT category, COUNT(*), AVG(price)
FROM products
GROUP BY category;
```

## Optimization Tips
- Index frequently queried columns
- Use EXPLAIN to analyze query plans
- Avoid SELECT * in production
```

## Workflow-Heavy Skill

Skill with detailed step-by-step processes:

```markdown
---
name: reviewing-code
description: Reviews code for bugs, style issues, security vulnerabilities. Use when reviewing pull requests or auditing codebases.
---

# Code Review

Systematic code review process.

**Use this skill when** reviewing PRs, auditing code, or ensuring quality standards.

## Review Checklist

Copy and track progress:

```
Review Progress:
- [ ] Step 1: Understand context
- [ ] Step 2: Check functionality
- [ ] Step 3: Review style
- [ ] Step 4: Security audit
- [ ] Step 5: Performance check
- [ ] Step 6: Write feedback
```

## Step 1: Understand Context

- Read PR description
- Understand the problem being solved
- Check related issues/tickets

## Step 2: Check Functionality

- Does code do what it claims?
- Are edge cases handled?
- Are error conditions covered?

## Step 3: Review Style

- Consistent with codebase conventions?
- Clear naming?
- Appropriate comments?

## Step 4: Security Audit

- Input validation?
- SQL injection prevention?
- XSS prevention?
- Secrets/credentials exposed?

## Step 5: Performance Check

- Unnecessary loops?
- N+1 queries?
- Memory leaks?

## Step 6: Write Feedback

Organize by priority:
1. **Blocking**: Must fix before merge
2. **Suggestions**: Improvements to consider
3. **Nitpicks**: Minor style preferences

## Feedback Templates

**Blocking issue:**
```
🔴 **Blocking**: [Description]
This needs to be fixed because [reason].
Suggested fix: [solution]
```

**Suggestion:**
```
💡 **Suggestion**: [Description]
Consider [alternative] because [benefit].
```
```

## Directory Structure Templates

### Minimal
```
my-skill/
└── SKILL.md
```

### With References
```
my-skill/
├── SKILL.md
└── references/
    ├── REFERENCE.md
    └── EXAMPLES.md
```

### Full Structure
```
my-skill/
├── SKILL.md
├── scripts/
│   ├── analyze.py
│   ├── validate.py
│   └── process.py
├── references/
│   ├── REFERENCE.md
│   ├── EXAMPLES.md
│   └── TROUBLESHOOTING.md
└── assets/
    ├── template.json
    └── schema.json
```

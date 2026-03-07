# Agent Skills Specification

Complete format specification for Agent Skills.

## Directory Structure

```
skill-name/
├── SKILL.md          # Required
├── scripts/          # Optional: executable code
├── references/       # Optional: documentation
└── assets/           # Optional: templates, resources
```

## SKILL.md Format

### Required Frontmatter

```yaml
---
name: skill-name
description: A description of what this skill does and when to use it.
---
```

### Optional Frontmatter Fields

```yaml
---
name: pdf-processing
description: Extract text and tables from PDF files, fill forms, merge documents.
license: Apache-2.0
compatibility: Requires pdfplumber, pytesseract
metadata:
  author: example-org
  version: "1.0"
allowed-tools: Bash(git:*) Read Write
---
```

## Field Constraints

### name (Required)

| Constraint | Value |
|------------|-------|
| Max length | 64 characters |
| Allowed chars | lowercase `a-z`, numbers `0-9`, hyphens `-` |
| Cannot start/end with | hyphen |
| Cannot contain | consecutive hyphens `--` |
| Must match | parent directory name |

**Valid:**
- `pdf-processing`
- `data-analysis`
- `code-review`

**Invalid:**
- `PDF-Processing` (uppercase)
- `-pdf` (starts with hyphen)
- `pdf--processing` (consecutive hyphens)

### description (Required)

| Constraint | Value |
|------------|-------|
| Max length | 1024 characters |
| Min length | 1 character (non-empty) |
| Cannot contain | XML tags |

### license (Optional)

License name or reference to bundled license file.

### compatibility (Optional)

| Constraint | Value |
|------------|-------|
| Max length | 500 characters |

Environment requirements: intended product, system packages, network access, etc.

### metadata (Optional)

Arbitrary key-value mapping for additional metadata.

### allowed-tools (Optional)

Space-delimited list of pre-approved tools. Experimental feature.

## Body Content

The Markdown body after frontmatter contains skill instructions. No format restrictions.

**Recommended sections:**
- Step-by-step instructions
- Examples of inputs and outputs
- Common edge cases

## Optional Directories

### scripts/

Executable code for agents to run.

**Guidelines:**
- Self-contained or clearly document dependencies
- Include helpful error messages
- Handle edge cases gracefully

### references/

Additional documentation loaded on demand.

**Common files:**
- `REFERENCE.md` - Technical reference
- `FORMS.md` - Form templates
- Domain-specific files (`finance.md`, `legal.md`)

Keep individual files focused for efficient context usage.

### assets/

Static resources:
- Templates (document, configuration)
- Images (diagrams, examples)
- Data files (lookup tables, schemas)

## File References

Use relative paths from skill root:

```markdown
See [the reference guide](references/REFERENCE.md) for details.

Run the script:
scripts/extract.py
```

**Keep references one level deep from SKILL.md.** Avoid nested reference chains.

## Token Budget Guidelines

| Content | Target |
|---------|--------|
| Metadata (name + description) | ~100 tokens |
| SKILL.md body | < 5000 tokens (< 500 lines) |
| Reference files | As needed (loaded on demand) |

## Validation

Use the skills-ref CLI to validate:

```bash
skills-ref validate ./my-skill
```

Checks frontmatter validity and naming conventions.

# Skill Authoring Best Practices

Guidelines for writing effective skills that Claude can discover and use successfully.

## Core Principles

### 1. Concise is Key

The context window is shared with conversation history, other skills, and user requests.

**Default assumption:** Claude is already very smart. Only add context it doesn't have.

**Good (concise):**
```markdown
## Extract PDF text

Use pdfplumber:
```python
import pdfplumber
with pdfplumber.open("file.pdf") as pdf:
    text = pdf.pages[0].extract_text()
```

**Bad (verbose):**
```markdown
## Extract PDF text

PDF (Portable Document Format) files are a common file format...
[unnecessary explanation Claude already knows]
```

### 2. Set Appropriate Degrees of Freedom

Match specificity to task fragility:

| Freedom | When to Use | Example |
|---------|-------------|---------|
| High | Multiple valid approaches | "Analyze code structure and suggest improvements" |
| Medium | Preferred pattern exists | Pseudocode with parameters |
| Low | Fragile operations | "Run exactly: `python scripts/migrate.py --verify`" |

**Analogy:**
- **Narrow bridge with cliffs**: One safe path → specific instructions
- **Open field**: Many paths → general direction

### 3. Test with All Target Models

- **Haiku**: Does it provide enough guidance?
- **Sonnet**: Is it clear and efficient?
- **Opus**: Does it avoid over-explaining?

## Writing Descriptions

### Use Third Person

Descriptions are injected into system prompts.

- **Good:** "Processes Excel files and generates reports"
- **Bad:** "I can help you process Excel files"

### Be Specific with Keywords

Include both what and when:

```yaml
# Good
description: Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when user mentions PDFs, forms, or document extraction.

# Bad
description: Helps with documents.
```

## Progressive Disclosure Patterns

### Pattern 1: High-Level Guide with References

```markdown
# PDF Processing

## Quick start
[Minimal example]

## Advanced features
**Form filling**: See [FORMS.md](references/FORMS.md)
**API reference**: See [REFERENCE.md](references/REFERENCE.md)
```

### Pattern 2: Domain-Specific Organization

```
bigquery-skill/
├── SKILL.md (overview)
└── reference/
    ├── finance.md
    ├── sales.md
    └── product.md
```

### Pattern 3: Conditional Details

```markdown
## Editing documents

For simple edits, modify XML directly.

**For tracked changes**: See [REDLINING.md](references/REDLINING.md)
```

## Workflows and Feedback Loops

### Use Checklists for Complex Tasks

```markdown
## Research synthesis workflow

Copy this checklist:
- [ ] Step 1: Read all source documents
- [ ] Step 2: Identify key themes
- [ ] Step 3: Cross-reference claims
- [ ] Step 4: Create structured summary
- [ ] Step 5: Verify citations
```

### Implement Feedback Loops

Run validator → fix errors → repeat

```markdown
1. Make edits
2. **Validate immediately**: `python scripts/validate.py`
3. If validation fails, fix and re-validate
4. **Only proceed when validation passes**
```

## Content Guidelines

### Avoid Time-Sensitive Information

**Bad:**
```markdown
If before August 2025, use old API.
```

**Good:**
```markdown
## Current method
Use v2 API endpoint.

<details>
<summary>Legacy v1 API (deprecated)</summary>
[Old info here]
</details>
```

### Use Consistent Terminology

Pick one term and stick with it:
- Always "API endpoint" (not "URL", "route", "path")
- Always "field" (not "box", "element", "control")

## Common Patterns

### Template Pattern

For strict requirements:
```markdown
ALWAYS use this exact template:
[template]
```

For flexible guidance:
```markdown
Sensible default format, adapt as needed:
[template]
```

### Examples Pattern

Provide input/output pairs:
```markdown
**Example 1:**
Input: Added user auth
Output: `feat(auth): implement JWT-based authentication`
```

## Anti-Patterns to Avoid

### 1. Windows-Style Paths

- **Good:** `scripts/helper.py`
- **Bad:** `scripts\helper.py`

### 2. Too Many Options

**Bad:** "Use pypdf, or pdfplumber, or PyMuPDF, or..."

**Good:** "Use pdfplumber. For OCR, use pdf2image with pytesseract instead."

### 3. Deeply Nested References

Keep references one level deep from SKILL.md.

**Bad:**
```
SKILL.md → advanced.md → details.md → actual info
```

**Good:**
```
SKILL.md → advanced.md (complete info)
         → reference.md (complete info)
```

## Iterative Development

1. **Complete task without skill** to identify what context you provide
2. **Create minimal skill** addressing those gaps
3. **Test with real tasks**
4. **Observe behavior** and refine based on actual usage
5. **Repeat** the observe-refine-test cycle

## Checklist

### Core Quality
- [ ] Description is specific with key terms
- [ ] Description explains what AND when
- [ ] SKILL.md body under 500 lines
- [ ] Details split to reference files
- [ ] No time-sensitive information
- [ ] Consistent terminology
- [ ] Concrete examples
- [ ] References one level deep
- [ ] Progressive disclosure applied
- [ ] Clear workflow steps

### Scripts (if applicable)
- [ ] Scripts handle errors explicitly
- [ ] No magic numbers (all values justified)
- [ ] Dependencies listed and verified
- [ ] Clear documentation
- [ ] Forward slashes in paths
- [ ] Validation steps for critical operations

### Testing
- [ ] At least 3 evaluation scenarios
- [ ] Tested with target models
- [ ] Tested with real usage

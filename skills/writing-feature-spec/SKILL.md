---
name: writing-feature-spec
description: Creates feature specifications (PRD) as Agent Skills with progressive disclosure. Use when writing product requirements, feature specs, user stories, acceptance criteria, or when starting spec-driven development for a new feature. The PRD is output as a skill directory with SKILL.md and reference files.
---

# Writing Feature Specs as Agent Skills

Create feature specifications structured as Agent Skills. The PRD becomes a skill that Claude can discover and activate, giving it contextual knowledge about the feature automatically.

**Use this skill when** defining what to build and why, writing product requirements, user stories, or acceptance criteria.

**Supporting files:** [CONTEXT-LAYERS.md](references/CONTEXT-LAYERS.md) for layer mapping details, [EXAMPLES.md](references/EXAMPLES.md) for complete examples.

## Why Agent Skill?

A PRD as an Agent Skill provides:
- **Auto-discovery**: Claude finds the spec via skill metadata without searching
- **Progressive disclosure**: SKILL.md body = core spec (L3), reference files = deep context (L4)
- **Token efficiency**: Only loaded when the feature is relevant to the conversation

## Output Structure

```
skills/prd-{feature-name}/
├── SKILL.md              # Core spec: TL;DR, requirements, user stories, constraints
└── references/
    ├── BACKGROUND.md     # Deep reference: background, research, edge cases (L4)
    └── RULES.md          # Code-area constraints to extract to L2
```

## Template: `skills/prd-{feature-name}/SKILL.md`

```markdown
---
name: prd-{feature-name}
description: PRD for {Feature Name}. {1-sentence summary of capability and who benefits}. Use when implementing, testing, or reviewing code related to {feature area}.
---

# {Feature Name} - PRD

## TL;DR

[1-3 sentences. Must answer: What capability? Who benefits? Why now?
This is the most critical section — Claude reads this to decide relevance.]

## Requirements

### Functional Requirements

- **FR-1**: [Imperative statement: "The system SHALL..."]
  - Acceptance: [Testable condition]
- **FR-2**: [Imperative statement]
  - Acceptance: [Testable condition]

### Non-Functional Requirements

- **NFR-1**: [Measurable quality attribute]
  - Metric: [Threshold, e.g., "p99 latency < 200ms"]

## User Stories

- As a [role], I want [action], so that [benefit]
  - Given [precondition], when [action], then [expected result]
  - Given [alt precondition], when [action], then [alt result]

## Constraints

- [Technical: e.g., must use existing auth middleware]
- [Business: e.g., must work on mobile viewports >= 375px]

## Non-Goals

- [Explicitly excluded scope item]
- [Another exclusion with reason or link to future spec]

## Open Questions

- [ ] [Unresolved question] (@owner)
- [x] [Resolved question] -> Decision: [answer]

## Deep Reference

**Background & research**: See [BACKGROUND.md](references/BACKGROUND.md)
**Code-area constraints**: See [RULES.md](references/RULES.md)
```

## Template: `references/BACKGROUND.md`

```markdown
# {Feature Name} - Background & Research

## Background

[Why this feature exists. Keep under 300 words.]

## Research

[User research, data analysis, competitive analysis that
informed requirements.]

## Edge Cases

| Case | Expected Behavior | Requirement |
|------|-------------------|-------------|
| [Edge case 1] | [Behavior] | FR-1 |
| [Edge case 2] | [Behavior] | FR-2 |
```

## Template: `references/RULES.md`

```markdown
# {Feature Name} - Code-Area Constraints

These constraints should be extracted to L2 path-conditional rules
after the spec is approved.

## Constraints

- [Constraint derived from requirements]
- [Another constraint]

## L2 Extraction Target

Extract to `.claude/rules/{feature-name}.md` with appropriate path globs:

    ---
    paths:
      - "path/to/relevant/code/**/*.ext"
    ---

    {Feature} constraints (from skills/prd-{feature}/SKILL.md):
    - [constraint 1]
    - [constraint 2]
```

## Writing Guidelines

### TL;DR: The Gate for Skill Activation

The TL;DR combined with the skill `description` determines whether Claude loads this spec. Both must be:

- **Self-contained**: Understandable without reading anything else
- **Decision-enabling**: Claude can determine relevance from description alone
- **Concrete**: Specific capability, not vague aspiration

```markdown
<!-- BAD description: Too vague -->
description: PRD for notification improvements.

<!-- GOOD description: Specific, includes trigger keywords -->
description: PRD for push notifications on order status changes (FCM/APNs). Use when implementing notification handlers, order status events, or device token management.
```

### Requirements: Atomic and Testable

Each requirement is a unit of implementation. Agents use requirements to:
1. Determine what code to write
2. Generate test cases from acceptance criteria
3. Verify completeness

```markdown
<!-- BAD: Compound, untestable -->
- **FR-1**: Handle notifications properly with good performance

<!-- GOOD: Atomic, testable, with acceptance criterion -->
- **FR-1**: The system SHALL deliver push notifications within 5 seconds
  of an order status change event.
  - Acceptance: Test device receives notification within 5s of
    status update via API call. Measured over 100 consecutive events.
```

### User Stories: Given-When-Then for Test Derivation

Agents directly convert Given-When-Then into test cases:

```markdown
- As a customer, I want to receive push notifications when my order ships
  - Given I have a confirmed order AND push notifications enabled,
    when the order status changes to "shipped",
    then I receive a notification with title "Order Shipped"
    and body containing the tracking number.
  - Given I have push notifications DISABLED,
    when the order status changes to "shipped",
    then NO notification is sent
    and the event is logged for later retrieval.
```

### Non-Goals: Preventing Agent Scope Creep

```markdown
## Non-Goals

- Email notification fallback (planned: skills/prd-email-notifications/)
- Notification preferences UI (Phase 2, not yet specced)
- Rich media notifications (images, action buttons)
```

## Layer Mapping (Skill Edition)

```
Layer   What goes here                  Location
======================================================================
L1      Skill metadata (auto)           SKILL.md frontmatter
        Claude discovers via description, no manual constitution entry needed

L2      Code-area constraints           .claude/rules/{feature}.md
        Extract from references/RULES.md after approval

L3      Core spec (auto-loaded)         SKILL.md body
        Requirements, user stories, constraints, non-goals

L4      Deep reference (on demand)      references/BACKGROUND.md
        Background, research, edge cases
======================================================================
```

**Key advantage over plain files**: L1 is automatic. No need to manually add references to CLAUDE.md — the skill system handles discovery.

## L2 Integration: Path-Conditional Rules

After spec approval, extract code-area constraints from `references/RULES.md` into `.claude/rules/`:

```markdown
<!-- .claude/rules/notification-handlers.md -->
---
paths:
  - "internal/notification/**/*.go"
---

Notification handler rules (from skills/prd-notifications/SKILL.md):
- All notifications must go through the NotificationSender interface
- Never send notifications synchronously in HTTP handlers
- Log all notification failures with structured error context
```

## Lifecycle

```
1. Create skills/prd-{feature}/ directory with references/ subdirectory
2. Write SKILL.md with template (TL;DR first)
3. Write references/BACKGROUND.md for deep context
4. Write references/RULES.md for code-area constraints
5. Review -> refine description for discoverability
6. Create technical design (writing-technical-design skill)
7. Extract L2 rules from RULES.md to .claude/rules/
8. Create implementation task commands (writing-implementation-tasks skill)
9. After completion -> remove skill or archive
```

## Quality Checklist

```
Feature Spec (Agent Skill) Quality Check:
- [ ] Skill name: prd-{feature-name}, matches directory name
- [ ] Description answers what/who/when with trigger keywords
- [ ] TL;DR answers what/who/why in under 3 sentences
- [ ] Every FR has a testable acceptance criterion
- [ ] User stories use Given-When-Then format
- [ ] Non-goals list at least one exclusion
- [ ] No implementation details (those belong in technical design)
- [ ] references/BACKGROUND.md contains L4 content
- [ ] references/RULES.md contains extractable L2 constraints
- [ ] SKILL.md body under 500 lines
- [ ] Description is specific enough for auto-discovery
```

## Detailed Guides

**Context layer mapping details**: See [CONTEXT-LAYERS.md](references/CONTEXT-LAYERS.md)
**Complete feature spec examples**: See [EXAMPLES.md](references/EXAMPLES.md)

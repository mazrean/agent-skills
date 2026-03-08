# Feature Spec Context Layer Mapping

Detailed guide on distributing feature spec information across context layers.

## The Four-Layer Model

```
                    Token Cost
Layer   Frequency   Per Request   Purpose
=============================================
L1      Every req   ~20 tokens    Feature discovery
L2      Path match  ~100 tokens   Code-area constraints
L3      On demand   ~500 tokens   Implementation reference
L4      Explicit    ~300 tokens   Clarification & context
=============================================
```

## L1: Constitution Reference

**What goes here:** A single line identifying the feature and its spec file.

**Why:** The agent needs to know which features exist and where their specs live. Without this, the agent must search the filesystem to find relevant specs.

**Format in CLAUDE.md / AGENTS.md:**
```markdown
## Active Specs

- `specs/prd-notifications.md` - Push notifications for order status changes
```

**When to add:** After spec reaches "approved" status.
**When to remove:** After feature reaches "done" status.

**Token cost:** ~20 tokens per feature. Budget for 5-10 active features max.

## L2: Path-Conditional Constraints

**What goes here:** Code-area rules derived from feature requirements that the agent must follow when editing specific files.

**Why:** Some requirements translate directly into coding constraints. Loading these only when the agent touches relevant code saves context vs. keeping them in L1.

**Example extraction from spec:**

Feature spec says:
```markdown
- **FR-3**: Notifications must be delivered asynchronously. The HTTP
  handler must not block on notification delivery.
- **NFR-1**: Notification delivery must not increase API response time
  by more than 10ms.
```

Extracted L2 rule (`.claude/rules/notification-handlers.md`):
```markdown
---
paths:
  - "internal/handler/**/*.go"
---

From specs/prd-notifications.md:
- Never send notifications synchronously in HTTP handlers
- Use the async NotificationSender interface
- API response time budget: existing baseline + max 10ms
```

**What NOT to extract:** Requirements that apply during implementation planning (not coding). Those stay in L3.

## L3: Spec Body (Core Content)

**What goes here:** The main spec document loaded when the agent starts working on this feature.

**Content and ordering (optimized for early-exit reading):**

```
1. TL;DR (100 tokens)
   Agent reads this first. If not relevant, stops here.

2. Requirements (300 tokens)
   Agent reads when implementing. Each FR is a unit of work.

3. User Stories (200 tokens)
   Agent reads when writing tests or understanding user flow.

4. Constraints (100 tokens)
   Agent reads to understand boundaries.

5. Non-Goals (100 tokens)
   Agent reads to avoid scope creep.

6. Open Questions (50 tokens)
   Agent reads when encountering ambiguity.
```

**Total L3 budget:** ~850 tokens for the core spec. This is loaded once when the agent starts working on the feature.

## L4: Deep Reference

**What goes here:** Supporting context that the agent rarely needs but should be available.

**Content:**
- Background / motivation (why this feature exists)
- Research data that informed requirements
- Edge case catalog
- Competitive analysis
- User research summaries

**Loading trigger:** The agent loads L4 content when:
- A requirement seems contradictory and needs context
- An edge case arises during implementation
- The agent needs to understand "why" behind a decision

**The L3/L4 separator convention:**
```markdown
## Open Questions
[last L3 section]

---
<!-- Below this line = L4 (deep reference, loaded only when needed) -->

## Background
[first L4 section]
```

## Decision Flow: Which Layer?

```
Is this information needed on EVERY agent request?
├─ Yes → L1 (constitution)
│        BUT: only a one-line reference, not details
└─ No
   │
   Is this triggered by editing specific files?
   ├─ Yes → L2 (path-conditional rules)
   │        Extract as a coding constraint
   └─ No
      │
      Is this needed to implement the feature?
      ├─ Yes → L3 (spec body, above separator)
      │        Requirements, user stories, constraints
      └─ No → L4 (deep reference, below separator)
               Background, research, edge cases
```

## Example: Full Layer Distribution

Feature: "Push notifications for order status changes"

### L1 (in CLAUDE.md):
```markdown
- `specs/prd-notifications.md` - Push notifications for order status
```

### L2 (in .claude/rules/notification-code.md):
```markdown
---
paths:
  - "internal/notification/**/*.go"
  - "internal/handler/order*.go"
---

Notification constraints (specs/prd-notifications.md):
- Async delivery only; never block HTTP handlers
- Use NotificationSender interface
- All failures must be logged with structured context
- Respect user notification preferences before sending
```

### L3 (in specs/prd-notifications.md, above separator):
```markdown
## TL;DR
Real-time push notifications for order status changes...

## Requirements
- FR-1: Send push within 5s of status change
  - Acceptance: Measured over 100 events on test device
- FR-2: Support FCM (Android) and APNs (iOS)
  ...

## User Stories
- As a customer, Given order status changes to "shipped"...

## Constraints
- Must use existing auth middleware
- Must not increase API response time > 10ms

## Non-Goals
- Email notifications (separate spec)
- SMS fallback

## Open Questions
- [ ] Batch rapid status changes? (@product)
```

### L4 (in specs/prd-notifications.md, below separator):
```markdown
---

## Background
Support tickets show 40% are "where is my order?" questions.
Push notifications would reduce this by an estimated 60%.

## Edge Cases
| Case | Behavior | FR |
|------|----------|-----|
| User disabled notifications | Skip, log event | FR-4 |
| Device token expired | Remove token, log | FR-5 |
| Rapid status changes (< 1min) | TBD (open question) | - |
```

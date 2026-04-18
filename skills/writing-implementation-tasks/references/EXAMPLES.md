# Implementation Tasks Examples (Command Format)

## Example: Notification System Tasks

### Directory Structure

```
.claude/commands/notifications/
├── overview.md
├── task-1-data-model.md
├── task-2-sender-interface.md
├── task-3-event-wiring.md
├── task-4-push-delivery.md
├── task-5-consumer.md
└── task-6-integration-tests.md
```

### overview.md

```markdown
---
description: Show progress and next steps for push notification implementation
allowed-tools: Bash, Read, Glob, Grep
---

# Push Notifications - Implementation Overview

<background_information>
- **PRD**: skills/prd-notifications/SKILL.md
- **Design**: specs/design-notifications.md
- **Mission**: Track implementation progress and guide to next task
</background_information>

<instructions>
## Execution Steps

1. For each task below, check if the verification commands pass
2. Report which tasks are complete, which is current, which are pending
3. Recommend the next task command to run

## Progress

- [ ] Task 1: Define notification data model → `/notifications/task-1-data-model`
- [ ] Task 2: Implement NotificationSender interface → `/notifications/task-2-sender-interface`
- [ ] Task 3: Wire up order status change events → `/notifications/task-3-event-wiring`
- [ ] Task 4: Add push notification delivery (FCM/APNs) → `/notifications/task-4-push-delivery`
- [ ] Task 5: Implement notification consumer → `/notifications/task-5-consumer`
- [ ] Task 6: Integration tests and error handling → `/notifications/task-6-integration-tests`

## Dependency Order

```
Task 1: Data model (no deps)
├─► Task 2: Sender interface (depends: Task 1)
├─► Task 3: Event wiring (depends: Task 1)
│    └─► Task 5: Consumer (depends: Task 3, Task 4)
└─► Task 4: Push delivery (depends: Task 2)
     └─► Task 5: Consumer (depends: Task 3, Task 4)
          └─► Task 6: Integration tests (depends: Task 5)
```
</instructions>

## Output Description
Report: which tasks are done, which is next, and the command to run it.
```

### task-1-data-model.md

```markdown
---
description: Create notification data model and database migrations for push notifications
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Task 1: Define notification data model and migrations

<background_information>
- **PRD**: skills/prd-notifications/SKILL.md
- **Design**: specs/design-notifications.md
- **Depends on**: none
- **Spec refs**: FR-1, FR-5
</background_information>

<instructions>
## Core Task

Create the notification data model types and database migration for the
device_tokens and notifications tables as defined in
specs/design-notifications.md (Data Model section).

## Scope

Files to create:
- `internal/notification/model.go`
- `migrations/005_notifications.sql`

Do NOT modify files outside this scope.

## Steps

1. Read specs/design-notifications.md Data Model section for schema
2. Create `internal/notification/model.go` with Go struct types:
   - `Notification` struct matching notifications table
   - `DeviceToken` struct matching device_tokens table
   - Platform enum type (FCM, APNs)
3. Create `migrations/005_notifications.sql` with DDL:
   - device_tokens table with user_id FK, platform, token, created_at
   - notifications table with user_id FK, title, body, status, created_at
   - Appropriate indexes per design doc
</instructions>

## Done When

Run these verification commands. ALL must pass:

```bash
go build ./internal/notification/...
go vet ./internal/notification/...
```

## Safety & Fallback

- If design doc doesn't exist, report: "Design doc required. Create specs/design-notifications.md first."
- If migration numbering conflicts, check existing migrations and adjust
```

### task-3-event-wiring.md

```markdown
---
description: Wire up order status change events to notification stream
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Task 3: Wire up order status change events

<background_information>
- **PRD**: skills/prd-notifications/SKILL.md
- **Design**: specs/design-notifications.md
- **Depends on**: Task 1 (data model — task-1-data-model)
- **Spec refs**: FR-1, FR-3
</background_information>

<instructions>
## Pre-check

Before starting, verify dependencies are complete:
1. Check that `internal/notification/model.go` exists (from Task 1)
2. If missing, report: "Task 1 must be completed first. Run /notifications/task-1-data-model"

## Core Task

Create event types and publisher for order status change events.
Add event publishing to the order status update handler.

## Scope

Files to create or modify:
- `internal/notification/event/event.go` (create)
- `internal/notification/event/publisher.go` (create)
- `internal/handler/order.go` (modify)

Do NOT modify files outside this scope.

## Steps

1. Create event types in `internal/notification/event/event.go`:
   - Define `OrderStatusChanged` struct matching the event schema
     in specs/design-notifications.md (Event Schema section)

2. Create `internal/notification/event/publisher.go`:
   - `Publisher` struct with `Publish(ctx, event) error` method
   - Accept Redis client via constructor injection

3. Add event publishing to `internal/handler/order.go`:
   - After successful status update in `UpdateOrderStatus` handler
   - Publish `OrderStatusChanged` event to Redis Stream "notifications"
   - Use `XADD` with `MAXLEN ~100000` per design doc decision
</instructions>

## Done When

```bash
go test ./internal/notification/event/...
go test ./internal/handler/...
go vet ./...
```

## Safety & Fallback

- If `internal/handler/order.go` doesn't exist, search for the order handler location with Grep
- If Redis client injection pattern is unclear, check existing handler patterns in the codebase
- If verification fails, fix and re-run — do not skip
```

### task-4-push-delivery.md

```markdown
---
description: Implement FCM and APNs push notification delivery senders
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Task 4: Add push notification delivery (FCM/APNs)

<background_information>
- **PRD**: skills/prd-notifications/SKILL.md
- **Design**: specs/design-notifications.md
- **Depends on**: Task 2 (sender interface — task-2-sender-interface)
- **Spec refs**: FR-2, FR-5
</background_information>

<instructions>
## Pre-check

Before starting, verify dependencies are complete:
1. Check that `internal/notification/sender/sender.go` exists (from Task 2)
2. If missing, report: "Task 2 must be completed first. Run /notifications/task-2-sender-interface"

## Core Task

Implement FCM and APNs delivery using the Sender interface from Task 2.
Handle expired device tokens per FR-5.

## Scope

Files to create:
- `internal/notification/sender/fcm.go`
- `internal/notification/sender/apns.go`
- `internal/notification/sender/multi.go`

Do NOT modify files outside this scope.

## Steps

1. Implement FCM delivery in `sender/fcm.go`:
   - Use firebase-admin-go SDK (per design doc Decision Summary)
   - Implement `Sender` interface from Task 2
   - Handle expired token errors: remove token, return specific error

2. Implement APNs delivery in `sender/apns.go`:
   - Use sideshow/apns2 (per design doc Decision Summary)
   - Implement `Sender` interface from Task 2
   - Handle expired token errors same as FCM

3. Create `sender/multi.go`:
   - Route to FCM or APNs based on device token platform field
   - Query device tokens from `DeviceTokenRepository`
</instructions>

## Done When

```bash
go test ./internal/notification/sender/...
go vet ./...
```

## Safety & Fallback

- If go module dependencies need adding, run `go get` for firebase-admin-go and apns2
- If the Sender interface has changed since Task 2, read the current version first
```

## Anti-Patterns

### Anti-Pattern 1: Tasks Too Large

```markdown
<!-- BAD: This is 3+ tasks bundled into one command -->
---
description: Implement the notification system
---
# Task 1: Implement everything

## Steps
Create the data model, implement the sender interface,
wire up events, add FCM and APNs support...
```

**Fix:** Split into 6 focused task commands as shown above.

### Anti-Pattern 2: Repeating Design Doc Content

```markdown
<!-- BAD: Repeating interface definition from design doc -->
## Steps

Implement the following interface:
```go
type Sender interface {
    Send(ctx context.Context, userID string, n Notification) error
    SendBatch(ctx context.Context, reqs []SendRequest) []Result
}
```

<!-- GOOD: Reference the design doc -->
## Steps

Implement the `Sender` interface defined in
specs/design-notifications.md (Interface Contracts section).
```

### Anti-Pattern 3: No Pre-check for Dependencies

```markdown
<!-- BAD: No dependency verification -->
## Steps
1. Import the model types from Task 1...

<!-- GOOD: Explicit pre-check -->
## Pre-check
1. Check that `internal/notification/model.go` exists (from Task 1)
2. If missing, report: "Task 1 must be completed first."
```

### Anti-Pattern 4: No Verification Commands

```markdown
<!-- BAD: No way to verify completion -->
## Done When
- The code works correctly

<!-- GOOD: Specific, executable -->
## Done When
```bash
go test ./internal/notification/sender/...
go vet ./...
```
```

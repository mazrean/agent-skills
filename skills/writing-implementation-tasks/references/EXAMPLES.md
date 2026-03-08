# Implementation Tasks Examples

## Example: Notification System Tasks

```markdown
---
title: "Push Notifications - Implementation Tasks"
status: in-progress
prd: prd-notifications.md
design: design-notifications.md
last-updated: 2026-03-05
---

# Push Notifications - Implementation Tasks

## Progress

- [x] Task 1: Define notification data model and migrations
- [x] Task 2: Implement NotificationSender interface
- [ ] Task 3: Wire up order status change events  <-- current
- [ ] Task 4: Add push notification delivery (FCM/APNs)
- [ ] Task 5: Implement notification consumer
- [ ] Task 6: Integration tests and error handling

## Task 1: Define notification data model and migrations

- **Status**: done
- **Commit**: a1b2c3d

<!-- Details collapsed -->

---

## Task 2: Implement NotificationSender interface

- **Status**: done
- **Commit**: e4f5g6h

<!-- Details collapsed -->

---

## Task 3: Wire up order status change events

- **Status**: in-progress
- **Depends on**: Task 1
- **Spec refs**: FR-1, FR-3
- **Scope**: `internal/handler/order.go`, `internal/notification/event/`
- **Verify**: `go test ./internal/handler/... ./internal/notification/event/...`

### What to do

1. Create event types in `internal/notification/event/event.go`:
   - Define `OrderStatusChanged` struct matching the event schema
     in specs/design-notifications.md (Event Schema section)

2. Add event publishing to `internal/handler/order.go`:
   - After successful status update in `UpdateOrderStatus` handler
   - Publish `OrderStatusChanged` event to Redis Stream "notifications"
   - Use `XADD` with `MAXLEN ~100000` per design doc decision

3. Create `internal/notification/event/publisher.go`:
   - `Publisher` struct with `Publish(ctx, event) error` method
   - Accept Redis client via constructor injection

### Done when

- [ ] `go test ./internal/notification/event/...` passes
- [ ] `go test ./internal/handler/...` passes
- [ ] Event struct matches schema in design doc
- [ ] Publisher uses XADD with MAXLEN as specified
- [ ] `go vet ./...` reports no issues

---

## Task 4: Add push notification delivery (FCM/APNs)

- **Status**: pending
- **Depends on**: Task 2
- **Spec refs**: FR-2, FR-5
- **Scope**: `internal/notification/sender/fcm.go`, `internal/notification/sender/apns.go`
- **Verify**: `go test ./internal/notification/sender/...`

### What to do

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

### Done when

- [ ] `go test ./internal/notification/sender/...` passes
- [ ] FCM sender handles expired tokens correctly
- [ ] APNs sender handles expired tokens correctly
- [ ] Multi-sender routes to correct provider by platform

---

## Task 5: Implement notification consumer

- **Status**: pending
- **Depends on**: Task 3, Task 4
- **Spec refs**: FR-1, FR-4, NFR-2
- **Scope**: `internal/notification/consumer/`
- **Verify**: `go test ./internal/notification/consumer/...`

### What to do

1. Create consumer in `consumer/consumer.go`:
   - Use XREADGROUP for Redis Stream consumption
   - Consumer group: "notification-workers" (per design doc)
   - Process events through sender (from Task 4)

2. Add user preference checking:
   - Check notification preferences before sending (FR-4)
   - Skip silently if user disabled notifications
   - Log skipped events for audit

3. Add retry with exponential backoff:
   - Max 3 retries per design doc Decision Summary
   - Move to dead letter after max retries (if decided, see open question)

4. Wire consumer startup in `cmd/server/main.go`:
   - Start as background goroutine
   - Graceful shutdown via context cancellation

### Done when

- [ ] `go test ./internal/notification/consumer/...` passes
- [ ] Consumer reads from Redis Stream correctly
- [ ] User preferences are checked before sending
- [ ] Retry logic works with exponential backoff
- [ ] Consumer starts and stops gracefully with server

---

## Task 6: Integration tests and error handling

- **Status**: pending
- **Depends on**: Task 5
- **Spec refs**: FR-1 through FR-5, NFR-1, NFR-2
- **Scope**: `internal/notification/integration_test.go`, error handling across all notification packages
- **Verify**: `go test ./internal/notification/... -tags=integration`

### What to do

1. Create integration test in `internal/notification/integration_test.go`:
   - End-to-end: status change -> event -> consumer -> mock sender
   - Verify delivery within expected latency (FR-1, NFR-1)
   - Test user preference opt-out flow (FR-4)
   - Test expired token handling (FR-5)

2. Review error handling across all notification packages:
   - Ensure all errors are wrapped with context
   - Ensure structured logging for failures (slog)
   - Verify no panics on nil/empty inputs

3. Add metrics instrumentation:
   - notification_sent_total (counter, labels: platform, status)
   - notification_latency_seconds (histogram)

### Done when

- [ ] `go test ./internal/notification/... -tags=integration` passes
- [ ] All error paths produce structured log output
- [ ] Metrics are emitted for sent/failed notifications
- [ ] No `go vet` or linter warnings
```

## Anti-Patterns

### Anti-Pattern 1: Tasks Too Large

```markdown
<!-- BAD: This is 3+ tasks bundled into one -->
## Task 1: Implement the notification system

- **Scope**: `internal/notification/`

### What to do

Create the data model, implement the sender interface,
wire up events, add FCM and APNs support, create the
consumer, and write tests.
```

**Fix:** Split into 6 focused tasks as shown in the example above.

### Anti-Pattern 2: Repeating Design Doc Content

```markdown
<!-- BAD: Repeating interface definition from design doc -->
### What to do

Implement the following interface:
```go
type Sender interface {
    Send(ctx context.Context, userID string, n Notification) error
    SendBatch(ctx context.Context, reqs []SendRequest) []Result
}
// ... 20 more lines of type definitions
```

<!-- GOOD: Reference the design doc -->
### What to do

Implement the `Sender` interface defined in
specs/design-notifications.md (Interface Contracts section).
```

### Anti-Pattern 3: No Verification Commands

```markdown
<!-- BAD: No way to verify completion -->
### Done when

- [ ] The code works correctly
- [ ] Tests pass

<!-- GOOD: Specific, executable -->
### Done when

- [ ] `go test ./internal/notification/sender/...` passes
- [ ] `go vet ./...` reports no issues
```

### Anti-Pattern 4: Missing Dependencies

```markdown
<!-- BAD: No dependency info, agent may start in wrong order -->
## Task 4: Add push delivery

- **Status**: pending

<!-- GOOD: Explicit dependencies -->
## Task 4: Add push delivery

- **Status**: pending
- **Depends on**: Task 2
```

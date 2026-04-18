# Feature Spec Examples (Agent Skill Format)

## Example: Push Notification System

### Directory Structure

```
skills/prd-notifications/
├── SKILL.md
└── references/
    ├── BACKGROUND.md
    └── RULES.md
```

### SKILL.md

```markdown
---
name: prd-notifications
description: PRD for push notifications on order status changes (placed, shipped, delivered) via FCM and APNs. Use when implementing notification handlers, order status events, device token management, or reviewing notification-related code.
---

# Push Notifications for Order Status - PRD

## TL;DR

Real-time push notifications for order status changes (placed, confirmed,
shipped, delivered). Reduces support ticket volume from users manually
checking order status. Uses FCM for Android and APNs for iOS.

## Requirements

### Functional Requirements

- **FR-1**: The system SHALL send a push notification within 5 seconds
  of an order status change event.
  - Acceptance: Notification received on test device within 5s of
    status update via API. Measured over 100 consecutive events.

- **FR-2**: The system SHALL support FCM (Android) and APNs (iOS)
  as delivery channels.
  - Acceptance: Notifications delivered successfully on both
    Android 12+ and iOS 16+ test devices.

- **FR-3**: The system SHALL deliver notifications asynchronously
  without blocking the HTTP request that triggers the status change.
  - Acceptance: API response time for status update does not increase
    by more than 10ms (p99) with notifications enabled.

- **FR-4**: The system SHALL respect user notification preferences.
  Users who disabled notifications SHALL NOT receive push messages.
  - Acceptance: Status change for user with disabled notifications
    produces no push delivery attempt. Event logged for audit.

- **FR-5**: The system SHALL handle expired device tokens by removing
  them and logging the removal.
  - Acceptance: Expired token triggers removal from user's device
    list. Subsequent notifications skip the removed token.

### Non-Functional Requirements

- **NFR-1**: Notification delivery latency SHALL be under 5 seconds
  (p99) from event to device.
  - Metric: p99 < 5s, measured over 24h production window.

- **NFR-2**: The notification system SHALL handle 1000 concurrent
  status change events without degradation.
  - Metric: No message loss at 1000 events/second sustained for 60s.

## User Stories

- As a customer, I want to receive push notifications when my order
  status changes, so that I don't have to check manually.
  - Given I have a confirmed order AND push notifications enabled,
    when the order status changes to "shipped",
    then I receive a push notification within 5 seconds
    with title "Order Shipped" and body containing tracking number.
  - Given I have push notifications DISABLED,
    when the order status changes,
    then NO push notification is sent
    and the status change event is logged for later retrieval.
  - Given my device token has EXPIRED,
    when the order status changes,
    then the expired token is removed from my profile
    and the notification is delivered to my other active devices.

- As an operations engineer, I want notification delivery failures
  logged with structured context, so that I can diagnose issues.
  - Given a notification delivery fails (FCM/APNs error),
    when the failure is recorded,
    then the log entry includes: user_id, device_token (masked),
    error_code, error_message, notification_id, timestamp.

## Constraints

- Must use existing auth middleware (session-based, gorilla/sessions)
- Must use existing user model (no schema changes to users table)
- Must work within current infrastructure (no new message brokers)
- Redis Streams available for async processing (already in stack)

## Non-Goals

- Email notification channel (planned: skills/prd-email-notifications/)
- SMS notification channel
- Rich notifications (images, action buttons)
- Notification preferences UI (Phase 2)
- Notification history / inbox UI (Phase 2)
- Cross-device notification sync

## Open Questions

- [ ] Should rapid status changes (< 1 minute apart) be batched
  into a single notification? (@product-owner)
- [x] Which push provider SDK? -> Decision: google/firebase-admin-go
  for FCM, sideshow/apns2 for APNs.
- [x] Where to store device tokens? -> Decision: New device_tokens
  table, see design doc.

## Deep Reference

**Background & research**: See [BACKGROUND.md](references/BACKGROUND.md)
**Code-area constraints**: See [RULES.md](references/RULES.md)
```

### references/BACKGROUND.md

```markdown
# Push Notifications - Background & Research

## Background

Support ticket analysis (Jan-Feb 2026) shows 40% of tickets are
"where is my order?" questions. Users currently must open the app and
navigate to order history to check status. Push notifications would
provide proactive updates, estimated to reduce these tickets by 60%.

Competitor analysis: All top-5 competitors offer push notifications
for order status. Our NPS feedback specifically mentions lack of
proactive order updates as a pain point.

## Research

Push notification delivery benchmarks (industry):
- FCM typical latency: 200-500ms
- APNs typical latency: 100-300ms
- Combined with our event processing: ~2s estimated end-to-end
- 5s SLA provides comfortable margin

## Edge Cases

| Case | Expected Behavior | Requirement |
|------|-------------------|-------------|
| User has no devices registered | Skip silently, log event | FR-4 |
| All device tokens expired | Remove all, log, no delivery | FR-5 |
| Status changes while notification in flight | Send both | FR-1 |
| Same status set twice (idempotent) | Send only once | FR-1 |
| User deletes account mid-delivery | Cancel pending, clean up tokens | FR-4 |
| FCM rate limit hit | Retry with exponential backoff, max 3 | NFR-2 |
| APNs certificate expiry | Alert ops, graceful degradation | NFR-1 |
```

### references/RULES.md

```markdown
# Push Notifications - Code-Area Constraints

These constraints should be extracted to L2 path-conditional rules
after the spec is approved.

## Constraints

- All notifications must go through the NotificationSender interface
- Never send notifications synchronously in HTTP handlers
- Log all notification failures with structured error context
- Respect user notification preferences before sending
- API response time budget: existing baseline + max 10ms

## L2 Extraction Target

Extract to `.claude/rules/notification-code.md`:

    ---
    paths:
      - "internal/notification/**/*.go"
      - "internal/handler/order*.go"
    ---

    Notification constraints (from skills/prd-notifications/SKILL.md):
    - Async delivery only; never block HTTP handlers
    - Use NotificationSender interface
    - All failures must be logged with structured context
    - Respect user notification preferences before sending
```

## Anti-Patterns

### Anti-Pattern 1: Implementation Details in Spec

```markdown
<!-- BAD: This is a technical design decision, not a requirement -->
- **FR-3**: Use Redis Streams with consumer groups to process
  notifications asynchronously. Set MAXLEN to 10000.

<!-- GOOD: State the requirement, let design doc decide how -->
- **FR-3**: The system SHALL deliver notifications asynchronously
  without blocking the HTTP request that triggers the status change.
```

### Anti-Pattern 2: Vague Description

```markdown
<!-- BAD: Claude can't determine when to activate this skill -->
description: PRD for notification improvements.

<!-- GOOD: Specific keywords enable auto-discovery -->
description: PRD for push notifications on order status changes (FCM/APNs). Use when implementing notification handlers, order status events, or device token management.
```

### Anti-Pattern 3: Missing Non-Goals

```markdown
<!-- BAD: No non-goals section. Agent will add email, SMS, etc. -->

<!-- GOOD: Explicit exclusions prevent scope creep -->
## Non-Goals
- Email notification channel (planned: skills/prd-email-notifications/)
- SMS notification channel
- Rich notifications (images, action buttons)
```

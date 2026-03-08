# Constitution Examples

## Example 1: Go Web Application

```markdown
# Project Constitution

## Commands

- Build: `go build ./cmd/server/`
- Test: `go test ./...`
- Test single: `go test ./internal/path/... -run TestName`
- Lint: `golangci-lint run`
- Generate: `go generate ./...`
- Migrate: `goose -dir migrations postgres "$DATABASE_URL" up`

## Tech Stack

- Language: Go 1.23
- HTTP: Echo v4
- Database: PostgreSQL 16 via sqlc
- Migrations: goose
- Frontend: templ + htmx + UnoCSS
- Auth: session-based via gorilla/sessions

## Project Structure

```
cmd/server/        # Main entry point
internal/
  handler/         # HTTP handlers (Echo)
  service/         # Business logic
  repository/      # Data access (sqlc-generated)
  model/           # Domain types
  middleware/      # HTTP middleware
migrations/        # SQL migrations (goose)
web/
  templates/       # templ components
  static/          # Static assets
specs/             # Feature specs, designs, tasks
```

## Coding Standards

- Error wrapping: `fmt.Errorf("context: %w", err)`
- Logging: `slog` with structured fields
- DB columns: snake_case; Go fields: CamelCase
- HTTP errors: `echo.NewHTTPError(status, message)`
- Tests: table-driven with `map[string]struct{}`

## Boundaries

- ALWAYS: Run `go test ./...` before considering done
- ALWAYS: Run `sqlc generate` after changing queries
- ALWAYS: Follow existing patterns in adjacent code
- ASK FIRST: New dependencies, schema changes, API changes
- NEVER: Commit .env, modify CI, use `//nolint` without reason

## Active Specs

- `specs/prd-notifications.md` - Push notification system
- `specs/design-notifications.md` - Notification architecture
- `specs/tasks-notifications.md` - Implementation tasks (Task 3)

## Current Work

Working on: specs/tasks-notifications.md, Task 3
```

## Example 2: TypeScript/React Application

```markdown
# Project Constitution

## Commands

- Dev: `npm run dev`
- Build: `npm run build`
- Test: `npm test`
- Test single: `npm test -- --testPathPattern="path" -t "name"`
- Lint: `npm run lint`
- Type check: `npx tsc --noEmit`

## Tech Stack

- Language: TypeScript 5.4 (strict mode)
- Framework: Next.js 15 (App Router)
- Styling: Tailwind CSS v4
- State: Zustand
- API: tRPC v11
- Database: Prisma + PostgreSQL
- Testing: Vitest + Testing Library

## Project Structure

```
src/
  app/             # Next.js routes (App Router)
  components/      # React components
  server/          # tRPC routers and procedures
  lib/             # Shared utilities
  hooks/           # Custom React hooks
prisma/            # Schema and migrations
specs/             # Feature specs
```

## Coding Standards

- Components: named exports, PascalCase files
- Hooks: `use` prefix, one hook per file
- Server actions: `"use server"` directive
- Error handling: Result type pattern, no throwing in lib code
- Imports: absolute `@/` paths only

## Boundaries

- ALWAYS: Run `npx tsc --noEmit` after changes
- ALWAYS: Use server components by default, client only when needed
- ASK FIRST: New npm packages, Prisma schema changes
- NEVER: Use `any` type, commit .env.local, disable ESLint rules
```

## Anti-Pattern: Overloaded Constitution

This constitution is too long and includes information that belongs elsewhere:

```markdown
<!-- BAD: 400+ lines, includes L3/L4 content -->

# Project Constitution

## Commands
[10 lines - OK]

## Tech Stack
[5 lines - OK]

## Detailed API Documentation        <!-- MOVE TO: L4 Agent Skill -->
### GET /api/orders
Returns paginated list of orders...
[50 lines of API docs]

## Database Schema                    <!-- MOVE TO: L3 design doc -->
CREATE TABLE orders (
    ...
);
CREATE TABLE order_items (
    ...
);
[80 lines of DDL]

## Architecture Decisions             <!-- MOVE TO: L3/L4 design doc -->
We chose PostgreSQL because...
We considered MongoDB but...
[100 lines of rationale]

## Current Sprint Tasks               <!-- MOVE TO: L3 tasks doc -->
- [ ] Implement order creation
- [ ] Add payment processing
- [ ] Create notification system
[30 lines of tasks with details]

## Code Examples                      <!-- MOVE TO: L2 rules or L4 -->
Here's how to write a handler:
```go
func (h *Handler) CreateOrder(c echo.Context) error {
    ...
}
```
[60 lines of code examples]
```

**Fix:** Extract each section to its appropriate context layer and replace with one-line references.

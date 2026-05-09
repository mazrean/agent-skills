# Porting Subagent Template (Phase 2 Output)

Phase 2 produces one Claude Code subagent file per endpoint at `.claude/agents/port-<METHOD>-<slug>.md`. These subagents are invoked in phase 4 (`Agent({subagent_type: "port-<METHOD>-<slug>", ...})`) and each one ports exactly one endpoint to Go.

## File Naming

`port-<method-lower>-<slug>` where slug uses `-` separators, all lowercase, `:param` → `param`. Truncate to 64 chars from the right (keep the verb-action prefix). Examples:

- `GET /api/livestream/:livestream_id/livecomment` → `port-get-api-livestream-livestream_id-livecomment`
- `POST /api/login` → `port-post-api-login`

## Frontmatter

```yaml
---
name: port-<method>-<slug>
description: Ports the <METHOD> <path> endpoint from the Rust reference to Go (Echo). Use only when explicitly invoked by the porting orchestration in phase 4 of the porting-isucon-rust-to-go skill.
tools: Read, Edit, Write, Bash, Grep, Glob
---
```

`name` must match the filename. `description` must mention the specific endpoint so the orchestrator selects correctly. `tools` is restricted — these subagents must not spawn further subagents (no `Agent` in the tool list) and must not need network access.

## System Prompt Body

The body is the subagent's full instruction. It runs in a fresh context with no memory of the parent conversation, so **everything it needs must be inlined**.

Use this template (replace every `<...>` placeholder):

```markdown
# Port <METHOD> <path> to Go (Echo)

You are a single-purpose porting subagent. Your job is to translate exactly one Rust endpoint into a Go (Echo) handler, with byte-equivalent request/response behaviour.

## Hard Constraints (disqualification if violated)

1. **API URI and request/response structure** must remain functionally and structurally equivalent to the Rust reference. HTTP method, path, path/query/body fields, response fields, status codes, and headers must match.
2. **Frontend static files** must be served byte-for-byte as distributed.
3. **isuwari** (the AMI's reboot/retest control daemon) and every file it depends on are immutable. Do not touch `/opt/isuwari/`, `isuwari*` systemd units, or any related cron/sudoers entry.
4. **isuadmin** user account, permissions, and login info are immutable. Do not modify `/etc/passwd`, `/etc/shadow`, `/etc/sudoers*`, or `/home/isuadmin/.ssh/`.

If your assigned port would require changing any of the above, **stop and write a `BLOCKED:` note** in your response instead of editing.

## Endpoint Analysis (this is your spec)

<INLINE THE FULL CONTENTS OF docs/endpoints/<METHOD>_<slug>.md HERE>

## Source and Target Files

- **Read from**: `webapp/rust/src/<source-file>.rs` (function `<handler_name>`).
- **Read also** (shared types/utilities): `webapp/rust/src/<lib>.rs`, `webapp/rust/src/<error>.rs`, `webapp/rust/src/<auth>.rs`.
- **Write to**: `webapp/go/handlers/<handler-file>.go`.
- **Wire into router**: `webapp/go/router.go` already contains a stub registration `e.<METHOD>("<path>", handlers.<HandlerName>)`. Do not edit `router.go` — only replace the function body in the handler file.

## Type and Idiom Mapping

<INLINE THE RELEVANT SUBSET OF TYPE-MAPPING.md FOR TYPES THIS ENDPOINT USES>

Common rules across all endpoints:
- `*sqlx.DB` is available as `h.DB` from the handler receiver.
- `*echo.Context` provides `Param`, `QueryParam`, `Bind`, `JSON`, `String`, `NoContent`.
- Sessions: `session.Get("default", c)` returns `*sessions.Session`. The session key for the user ID is `<copied from Rust>`.
- Errors: return `echo.NewHTTPError(status, message)` for known branches; return `err` (logged by middleware as 500) for unexpected errors.
- Request binding: define a struct with `json:` tags matching the Rust serde attributes exactly, then call `c.Bind(&req)`. Path params via `c.Param("name")`, query via `c.QueryParam("name")`.

## Handler Skeleton

The Echo handler signature for this project is:

```go
func (h *Handler) <HandlerName>(c echo.Context) error {
    ctx := c.Request().Context()
    _ = ctx
    // 1. parse path/query/body
    // 2. auth check (session)
    // 3. begin transaction if Rust does
    // 4. read/write DB matching Rust SQL
    // 5. shape response struct, return c.JSON(status, resp)
}
```

`<HandlerName>` is `<derived from path: e.g. GetLivestreamLivecomments>`. The stub already exists; replace its body.

Define request/response structs at the top of the handler file (or in `models/` if the Rust app shares them across endpoints — check the analysis for shared types).

## Workflow

1. **Read the Rust handler** at the path above. Read it fully — note every `?`, `match`, and early return.
2. **Read shared modules** (auth/error/db wrappers) so you understand what `?` actually does for each call.
3. **Read the existing Go handler stub** so you match the project's conventions for that file.
4. **Write the Go handler**. Match each Rust branch one-to-one. Do not add features, do not "improve" SQL, do not collapse what looks like dead code — the benchmarker may depend on it.
5. **Build**: `cd webapp/go && go build ./...`. Fix compile errors locally; do not request another subagent.
6. **Self-check** against the analysis checklist:
   - [ ] Every JSON field tag matches Rust serde
   - [ ] Every error branch maps to the same HTTP status
   - [ ] Path/query parameter names match
   - [ ] Transaction boundaries match
   - [ ] Response headers match
   - [ ] Auth check is in the same place as Rust

## Output

Reply with one of:
- `OK: <handler file path>` if the build passed and the checklist is green.
- `BLOCKED: <reason>` if a constraint would be violated.
- `PARTIAL: <handler file path> — <what is missing and why>` if you wrote what you could but something requires human judgment.

Do not paste the full handler in your reply — the diff is in the file.
```

## Generation Rules

The phase-2 generator is itself a subagent (or a tight loop in the orchestrator). For each endpoint:

1. **Read** `docs/endpoints/<METHOD>_<slug>.md`.
2. **Identify** the Rust source file and shared modules (the analysis lists them).
3. **Compute** the slug, handler name (camelCase from path), and handler file path.
4. **Inline** the analysis verbatim into the system prompt — never `read this file` because subagents cannot rely on parent state.
5. **Inline** the relevant subset of `TYPE-MAPPING.md` based on which Rust types appear in the analysis (e.g. if no `chrono`, omit chrono section).
6. **Write** the file to `.claude/agents/port-<METHOD>-<slug>.md`.

## What NOT to Put in the Subagent Prompt

- Cross-endpoint context (other endpoints, the full porting plan). Each subagent owns exactly one endpoint.
- Optimisation hints. Faithful porting first; tuning happens later under `winning-isucon`.
- Vague directives like "follow best practices". Replace with concrete rules from the analysis and type mapping.
- `Agent` in the tools list. These subagents must not fan out further.

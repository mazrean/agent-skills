---
name: porting-isucon-rust-to-go
description: Ports an ISUCON-style Rust reference implementation to Go (Echo) using parallel subagents. Use when the contest provides a Rust reference but the team wants to compete in Go, or when the user asks to migrate a Rust web app to Go Echo endpoint by endpoint. Preserves API URI, request/response shape, frontend static files, the isuwari reboot/retest daemon, and the isuadmin account exactly as distributed (changing them = disqualification).
---

# Porting ISUCON Rust → Go (Echo)

Systematic, mostly-parallel port of an ISUCON-style Rust reference implementation to Go using the Echo framework. The work is broken into 4 phases. Phases 1, 2, and 3 fan out across many subagents at once; phase 4 fires the per-endpoint subagents created in phase 2 to produce the actual Go handlers.

**Use this skill when** the contest distributes a Rust reference implementation, the team has chosen Go for the run, and the user asks to "port from Rust to Go" or generate per-endpoint porting agents.

**Do NOT use this skill** for greenfield Go work, for porting *to* Rust, or for general performance tuning of an existing Go app — see `winning-isucon` for tuning.

## Hard Constraints (changing any of these = disqualification)

Read [references/CONSTRAINTS.md](references/CONSTRAINTS.md) before doing anything. The four immutable items are:

1. **API URI and request/response structure** — must remain functionally and structurally equivalent to the Rust reference.
2. **Frontend static files** (HTML / CSS / JS / images) — must be served byte-for-byte as distributed.
3. **isuwari** (the AMI's reboot/retest control daemon) and every file it depends on.
4. **isuadmin** user account, permissions, and login info.

Every generated subagent prompt MUST include this constraint list. The skeleton templates already do — keep it that way.

## Workflow Overview

```
Phase 0  Discovery & locate Rust source
   │
   ├─── Phase 1 (parallel): per-endpoint analysis subagents
   │         output: docs/endpoints/<METHOD>_<slug>.md
   │
   ├─── Phase 2 (parallel, after phase 1 per-endpoint):
   │         generate .claude/agents/port-<METHOD>-<slug>.md
   │
   └─── Phase 3 (parallel with 1 & 2): Echo base implementation
             output: webapp/go/{main.go, db.go, models/, handlers/}

Phase 4  Fire all port-* subagents in parallel → real Go handlers
Phase 5  Build, smoke test, swap systemd unit, run benchmark
```

Phase 2 generation per endpoint can begin as soon as that endpoint's phase 1 doc lands; you do not need to wait for all of phase 1 before starting phase 2 work.

## Phase 0: Discovery (do this first, sequentially)

1. **Locate the Rust source.** ISUCON repos typically use `webapp/rust/`. Confirm the framework (axum, actix-web, hyper) and the SQL crate (sqlx, diesel) — the porting strategy depends on it. Note the binary name, Cargo workspace layout, and any non-default modules (sessions, auth middleware).
2. **Locate frontend statics.** Usually `webapp/public/` or `webapp/frontend/`. Note where the Rust app serves them from. The Go port must serve the **identical bytes** from the **same URL paths**.
3. **Locate `isuwari` and `isuadmin`.** Typically `/opt/isuwari/` and `/etc/systemd/system/isuwari*.service`, `getent passwd isuadmin`. List these as untouchable. Any work that would create files under those paths must stop and ask.
4. **Locate the systemd unit for the Rust app** (`isuride-rust.service`, `isupipe-rust.service`, etc.). The Go port will register a parallel `*-go.service`. Do not delete the Rust unit yet — keep it as a fallback until the Go port passes the benchmark.
5. **Inventory endpoints.** Grep the Rust router for routes — `Router::new().route(...)`, `.route(METHOD)`, etc. Produce `docs/endpoints/INDEX.md` listing every (METHOD, path) pair with the handler function name and source file. This list drives phase 1.
6. **Decide the Go target directory.** If `webapp/go/` already contains a stub Go reference, port into it (overwriting handlers but preserving any deploy glue). If absent, create `webapp/go/`.

Write `docs/PORTING-PLAN.md` with: framework detected, SQL crate detected, endpoint count, target directory, deploy unit name. This is your shared context for the next three phases.

## Phase 1: Per-Endpoint Analysis (parallel subagents)

For each endpoint in `docs/endpoints/INDEX.md`, dispatch one Agent (`subagent_type: general-purpose`) in parallel. Each subagent reads the Rust handler and produces a single markdown file at `docs/endpoints/<METHOD>_<slug>.md` matching the format in [references/ENDPOINT-ANALYSIS.md](references/ENDPOINT-ANALYSIS.md).

**Send all phase-1 subagent calls in one message** so they run concurrently. A typical batch is 10–40 endpoints.

**Each phase-1 subagent prompt must contain:**
- The (METHOD, path) it owns and the Rust handler file/function.
- The path to write the analysis markdown to.
- The constraints summary from [references/CONSTRAINTS.md](references/CONSTRAINTS.md).
- The exact output format from [references/ENDPOINT-ANALYSIS.md](references/ENDPOINT-ANALYSIS.md).
- Instruction: read the Rust source and shared modules (auth, error types, DB pool wrappers) before writing the analysis.

**What the analysis must capture** (full list in [references/ENDPOINT-ANALYSIS.md](references/ENDPOINT-ANALYSIS.md)):
- Role / business purpose (one paragraph).
- Method, path, path params, query params, request body schema, content-type.
- Response: status codes, body schema, headers, content-type.
- Auth/middleware (session, role check, CSRF).
- DB tables read and written, including transaction boundaries.
- External services / other endpoints called.
- Side effects (cache writes, file IO, async tasks).
- Notable Rust-specific details that need careful porting (e.g. `serde(rename_all)`, custom `FromRow`, `IntoResponse`).

After all phase-1 subagents return, spot-check 2–3 outputs for completeness. If an analysis is missing a field, re-run that one endpoint.

## Phase 2: Generate Porting Subagents (parallel)

For each completed phase-1 analysis, generate a Claude Code subagent file at `.claude/agents/port-<METHOD>-<slug>.md` following [references/PORTING-AGENT-TEMPLATE.md](references/PORTING-AGENT-TEMPLATE.md).

**Each generated subagent file embeds:**
- The full endpoint analysis (inline, not by reference — the subagent runs in a fresh context).
- The constraint list from [references/CONSTRAINTS.md](references/CONSTRAINTS.md).
- The relevant slice of [references/TYPE-MAPPING.md](references/TYPE-MAPPING.md).
- Concrete file paths: where to read the Rust source, where to write the Go handler, which Echo router file to wire it into.
- The Echo handler signature template the project standardised on in phase 3.
- Allowed tools: `Read, Edit, Write, Bash, Grep, Glob`.
- Strict instructions: do not change request/response shape, do not invent endpoints, port the logic faithfully first (optimisation is a later skill — `winning-isucon`).

**Generate these in parallel** as well. Spawn an Agent per endpoint to write the subagent file (the work is small but I/O-bound across many files).

**File naming**: `port-<METHOD>-<slug>` lowercase, hyphens only, slug is path with `/` → `-` and any `:param` → `param`. Example: `GET /api/livestream/:livestream_id/livecomment` → `port-get-api-livestream-livestream_id-livecomment`. Truncate sensibly if names exceed 64 chars (Claude Code subagent name limit).

## Phase 3: Echo Base Implementation (parallel with 1 and 2)

While phases 1 and 2 are running, build the Go skeleton at `webapp/go/`. This is sequential within the phase but runs concurrently with the analysis fan-out. See [references/ECHO-BASE.md](references/ECHO-BASE.md) for the full scaffold.

**Minimum scaffold:**
- `go.mod` pinning Go version matching the AMI, with `github.com/labstack/echo/v4`, `github.com/jmoiron/sqlx`, `github.com/go-sql-driver/mysql`, plus whatever the Rust app uses (sessions: `github.com/gorilla/sessions` + `github.com/labstack/echo-contrib/session`; bcrypt: `golang.org/x/crypto/bcrypt`; UUID: `github.com/google/uuid`).
- `main.go`: Echo bootstrap, DB connection pool, middleware (logger, recover, session), static file mount matching the Rust app's mount, graceful shutdown, listen on the same address/port as the Rust unit.
- `db.go`: sqlx `*sqlx.DB` initialisation, DSN from env (match Rust env names exactly).
- `models/`: structs translated from Rust DTOs/entities. Each struct has `db:"..."` and `json:"..."` tags matching Rust's `serde` attributes — get this wrong once and every endpoint diverges.
- `handlers/`: empty package with one stub per endpoint that returns `echo.NewHTTPError(http.StatusNotImplemented, "stub")`. Phase 4 subagents replace these stubs.
- `router.go`: every route from phase 0's `INDEX.md` wired to its stub. The router file is the single source of truth phase-4 subagents will edit to swap stubs for real implementations.
- Match the deploy glue: `Makefile` target, `systemd/isu*-go.service` with `User=isucon`, `WorkingDirectory=/home/isucon/webapp/go`, identical env vars to the Rust unit.

**Do not** start phase 4 until the skeleton compiles (`go build ./...` succeeds) and starts (`./isu-go &` returns 501s for every endpoint). A broken skeleton wastes every parallel subagent's run.

## Phase 4: Execute Porting (parallel subagent invocations)

Once phase 2 has produced every `port-*` subagent file AND phase 3's skeleton compiles, fire the porting subagents.

**Send invocations in batches of ~10 in a single message** so they run concurrently. (A single message with N Agent calls = N parallel runs; one message per agent = serial.) Each invocation:

```
Agent({
  description: "Port <METHOD> <path>",
  subagent_type: "port-<METHOD>-<slug>",
  prompt: "Port this endpoint per your system prompt. Confirm build passes after your edit."
})
```

Each subagent edits its own handler file plus the relevant `router.go` line. Conflicts on `router.go` are real — to avoid lost edits, either:
- (preferred) have phase 3 wire **all** stubs upfront so phase 4 subagents only edit handler files, never `router.go`, OR
- run phase 4 in batches and run `go build ./...` after each batch to catch and fix conflicts before the next batch.

After all batches complete, run from `webapp/go/`:
```bash
go build ./... && go vet ./...
```

If build fails, inspect the failing handler, hand-fix the obvious type/import errors, and re-fire the offending subagent only if the issue is logic-shaped rather than typo-shaped.

## Phase 5: Verify and Swap

1. **Diff a few request/responses** against the Rust app side by side using `curl`. Pick one read endpoint and one write endpoint per resource. Bytes (or canonical JSON) must match.
2. **Disable Rust, enable Go**:
   ```bash
   sudo systemctl disable --now isu*-rust.service
   sudo systemctl enable --now isu*-go.service
   ```
3. **Run the benchmarker once** with the Go app. The first run after a port commonly fails on a few endpoints (forgotten field, wrong tag); fix and re-run.
4. **Commit**: one commit per fix during stabilisation, then a single "switch to Go" milestone tag once the benchmark passes.
5. **Hand off to `winning-isucon`** for the actual tuning. Porting buys you nothing on its own — the Go path is the foundation for the optimisations that earn the score.

## Reference Files

- [CONSTRAINTS.md](references/CONSTRAINTS.md) — the four immutable items, in detail. Embedded into every subagent prompt.
- [ENDPOINT-ANALYSIS.md](references/ENDPOINT-ANALYSIS.md) — exact output format for phase 1 subagents.
- [PORTING-AGENT-TEMPLATE.md](references/PORTING-AGENT-TEMPLATE.md) — the template for `.claude/agents/port-*.md` files generated in phase 2.
- [ECHO-BASE.md](references/ECHO-BASE.md) — Echo skeleton: main.go, db, middleware, models, router, deploy parity.
- [TYPE-MAPPING.md](references/TYPE-MAPPING.md) — Rust → Go cheatsheet (sqlx, Option, Vec, chrono, anyhow, bcrypt, axum extractors → Echo binders).

## Key Rules

1. **Preserve the wire shape.** A faster wrong response is still a 0. The benchmarker compares bytes, not intent.
2. **Port faithfully first, optimise later.** Tuning belongs to `winning-isucon`. Mixing the two during the port produces bugs you cannot bisect.
3. **Phase 3 wires every route up front** so phase 4 never touches `router.go`. This eliminates the only realistic merge-conflict surface across parallel subagents.
4. **Send parallel work in a single message.** N Agent calls in one assistant turn = N concurrent runs. One per turn = serial. The whole skill assumes the former.
5. **Never modify isuwari, isuadmin, frontend statics, or the API contract.** Any subagent that would do so must stop and ask.
6. **Keep the Rust unit installed but disabled** until the Go port passes a full benchmark. Rolling back to Rust is the only safety net.
7. **The Rust source is the spec, not the docs.** When in doubt, read `webapp/rust/` — generated docs and contest manuals lag behind the code.

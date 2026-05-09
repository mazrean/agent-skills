# Endpoint Analysis Format (Phase 1 Output)

Each phase-1 subagent produces exactly one markdown file at `docs/endpoints/<METHOD>_<slug>.md` using the template below. The file is consumed by the phase-2 subagent generator and embedded verbatim into the per-endpoint porting subagent's system prompt — completeness here directly determines port correctness.

## Filename Convention

`<METHOD>_<slug>.md` where:
- `METHOD` is uppercase: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`.
- `slug` is the path with `/` → `_`, `:param` → `param`, leading/trailing `_` stripped.

Examples:
- `GET /api/livestream/:livestream_id/livecomment` → `GET_api_livestream_livestream_id_livecomment.md`
- `POST /api/login` → `POST_api_login.md`
- `GET /api/user/me` → `GET_api_user_me.md`

## Template

```markdown
# <METHOD> <path>

## Role

<One paragraph: what this endpoint does in business terms. Why it exists. Who calls it (frontend page, other service, benchmarker probe).>

## Source

- Rust handler: `webapp/rust/src/<file>.rs::<function_name>`
- Router registration: `webapp/rust/src/<file>.rs:<line>`
- Shared modules used: `<list of util/middleware modules>`

## Request

- **Method**: `<METHOD>`
- **Path**: `<path with :params>`
- **Path params**:
  | Name | Type | Notes |
  |------|------|-------|
  | livestream_id | i64 | path-encoded |
- **Query params**:
  | Name | Type | Required | Default | Notes |
  |------|------|----------|---------|-------|
  | limit | i64 | no | none | if absent, return all |
- **Headers required**: `<list>` (Cookie session, X-Forwarded-*, etc.)
- **Body**: `<Content-Type>` or `none`
  ```json
  { "field": "type — required/optional — notes" }
  ```
- **Auth/middleware**: <session required? role check? CSRF? rate limit?>

## Response

- **Success status**: `<200 / 201 / 204>`
- **Success body**: `<Content-Type>` or `empty`
  ```json
  { "field": "type — notes (nullable? omitempty? camelCase?)" }
  ```
- **Error branches**:
  | Status | Trigger | Body |
  |--------|---------|------|
  | 401 | no session | `{ "error": "..." }` or empty |
  | 404 | livestream not found | ... |
  | 500 | DB error | ... |
- **Response headers set**: `<Set-Cookie / Location / Cache-Control / ...>`

## Database

- **Tables read**:
  | Table | Columns | Predicates |
  |-------|---------|------------|
  | livestreams | id, user_id, title | WHERE id = ? |
- **Tables written**:
  | Table | Operation | Columns |
  |-------|-----------|---------|
  | livecomments | INSERT | livestream_id, user_id, comment, created_at |
- **Transaction**: <none / begin..commit on success, rollback on error>
- **Locking**: <none / SELECT ... FOR UPDATE on which rows>
- **Notable queries**: <any non-trivial JOIN / subquery / aggregation, write the SQL>

## External Calls

- **Other endpoints invoked**: <none / list>
- **External services**: <none / Redis, S3, third-party HTTP>
- **Async tasks spawned**: <none / list>

## Side Effects

- Cache writes/invalidations
- File system writes (uploads, logs beyond standard)
- Anything else not visible in the response

## Rust-Specific Notes

Anything that needs careful translation. Examples worth flagging if present:
- Custom `serde` attributes (`rename_all`, `skip_serializing_if`, `with = "..."`).
- Custom `FromRow` / `sqlx::Type` impls.
- Custom error type → IntoResponse mapping (which Rust error variant → which HTTP status).
- `Option<T>` fields and how they serialise.
- Numeric types other than `i64`/`f64` (especially `BigDecimal`, `u64`, `u32`).
- `chrono` timestamp formatting.
- Use of `tokio::spawn`, `Arc<Mutex<...>>`, channels.
- Use of `tower` middleware that affects this endpoint specifically.

## Porting Checklist (consumed by phase 2)

- [ ] Echo handler signature: `func(c echo.Context) error`
- [ ] Bind path/query/body via Echo's `c.Param/QueryParam/Bind`
- [ ] Match every JSON tag to Rust serde attribute
- [ ] Match every error branch HTTP status
- [ ] Match transaction/locking semantics
- [ ] Match auth/middleware (session, role)
- [ ] Match response headers
```

## Authoring Rules for the Phase-1 Subagent

1. **Read the Rust source, not the contest manual.** Manuals lag behind code.
2. **Quote SQL verbatim** when it is non-trivial. Do not paraphrase joins.
3. **List every error branch** including the implicit ones (`?` operator on a DB call → 500 unless mapped).
4. **Note serde attributes per field**, not just per struct. One `rename_all` on the parent does not mean every nested struct shares it.
5. **If something is ambiguous in the Rust code**, write `AMBIGUOUS:` followed by what you observed and what you guessed. Do not silently invent semantics.
6. **Do not propose Go code** in the analysis. The analysis is a contract; phase 4 writes the Go.

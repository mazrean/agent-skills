# Rust → Go Type and Idiom Mapping

Cheatsheet for the porting subagents. Phase 2 inlines the relevant subset of this file into each subagent prompt, based on which Rust types appear in that endpoint's analysis. Keep entries terse — these are reminders for Claude, not a tutorial.

## Primitives

| Rust | Go | Notes |
|------|-----|-------|
| `i32` | `int32` | match width — JSON numeric range matters |
| `i64` | `int64` | |
| `u32` | `uint32` | rare in MySQL — usually a Rust-side choice; if column is unsigned, mirror it |
| `u64` | `uint64` | |
| `f32` / `f64` | `float32` / `float64` | |
| `bool` | `bool` | |
| `String` | `string` | |
| `&str` | `string` | Go has no borrow distinction |
| `Vec<u8>` | `[]byte` | |
| `BigDecimal` / `Decimal` | `string` (or `github.com/shopspring/decimal`) | **never `float64`** — precision drift |

## Option, Vec, HashMap

| Rust | Go (DB scan) | Go (JSON) |
|------|--------------|-----------|
| `Option<i64>` | `sql.NullInt64` | `*int64` with `json:",omitempty"` if Rust uses `skip_serializing_if = "Option::is_none"`, else `*int64` |
| `Option<String>` | `sql.NullString` | `*string` (same omitempty rule) |
| `Option<DateTime<Utc>>` | `sql.NullTime` | `*time.Time` |
| `Vec<T>` | `[]T` | `[]T` |
| `HashMap<K, V>` | `map[K]V` | `map[K]V` |
| `BTreeMap<K, V>` | `map[K]V` (sort if order matters) | order check: does Rust serialise sorted? Replicate. |

**Critical**: Rust `Option<T>` without `skip_serializing_if` serialises `None` as `null`. In Go, `*T` with `nil` and no `omitempty` does the same — leave the tag off. With `omitempty`, the field is dropped entirely. **Match the Rust attribute exactly**.

## Time

| Rust (`chrono`) | Go (`time`) | Notes |
|-----------------|-------------|-------|
| `DateTime<Utc>` | `time.Time` | sqlx reads with `parseTime=true&loc=UTC` |
| `DateTime<Local>` | `time.Time` | `loc=Local` in DSN; check Rust app's actual loc |
| `NaiveDateTime` | `time.Time` | naive = no TZ; treat as UTC unless Rust does otherwise |
| `Duration` | `time.Duration` | |

JSON serialisation defaults differ:
- `chrono` `DateTime<Utc>` with default `serde` → RFC3339 with subseconds (`2024-01-02T03:04:05.123456Z`).
- Go `time.Time` JSON marshal → RFC3339Nano (`2024-01-02T03:04:05.123456789Z`).

If the benchmarker compares strings, this is a real divergence. Mitigations:
- Use a custom `MarshalJSON` that truncates to microseconds.
- Or define a wrapper type with the desired format.

If Rust uses Unix epoch seconds in JSON (common in ISUCON), mirror with `.Unix()` in Go.

## serde → encoding/json

| Rust serde | Go json tag |
|-----------|-------------|
| `#[serde(rename = "foo")]` | `json:"foo"` |
| `#[serde(rename_all = "camelCase")]` (struct) | apply camelCase to every field tag |
| `#[serde(skip_serializing_if = "Option::is_none")]` | `,omitempty` |
| `#[serde(skip)]` | `json:"-"` |
| `#[serde(flatten)]` | embed the struct (anonymous field) |
| `#[serde(default)]` on deserialise | Go zero values are the default — usually no extra work |
| `#[serde(with = "...")]` (custom (de)serialise) | implement `MarshalJSON`/`UnmarshalJSON` |

## sqlx (Rust) → sqlx (Go, jmoiron)

| Rust sqlx | Go sqlx | Notes |
|-----------|---------|-------|
| `sqlx::query!("SELECT ...")` | `db.QueryxContext(ctx, "SELECT ...")` + `Scan` | macros do not exist in Go; no compile-time check |
| `sqlx::query_as!(T, "SELECT ...")` | `db.SelectContext(ctx, &dst, "SELECT ...")` for slices, `db.GetContext(ctx, &dst, "SELECT ...")` for one row | |
| `query.fetch_one(&pool).await?` | `db.GetContext(ctx, &dst, q, args...)` (errors `sql.ErrNoRows`) | |
| `query.fetch_all(&pool).await?` | `db.SelectContext(ctx, &dst, q, args...)` | |
| `query.execute(&pool).await?` | `db.ExecContext(ctx, q, args...)` | |
| `pool.begin().await?` | `tx, err := db.BeginTxx(ctx, nil)` | |
| `tx.commit().await?` | `tx.Commit()` | |
| `tx.rollback().await?` | `tx.Rollback()` | use `defer tx.Rollback()` after begin; `Commit` makes rollback a no-op |
| `?` after `fetch_one` returning `RowNotFound` | `errors.Is(err, sql.ErrNoRows)` | map to 404 only if Rust does |
| `FromRow` / `#[derive(FromRow)]` | `db:"col"` tags on struct fields | |

**Transactions:** if the Rust handler `begin`s, the Go port must wrap the same range in a transaction. Do not collapse a transaction-wrapped read into a non-transactional read just because Go feels "lighter".

## axum / actix → Echo

### Extractors → Echo binders

| Rust | Go (Echo) |
|------|-----------|
| `Path((id,)): Path<(i64,)>` | `id, _ := strconv.ParseInt(c.Param("id"), 10, 64)` |
| `Query<T>` | `var q T; if err := c.Bind(&q); err != nil { ... }` (binds query for GET) |
| `Json<T>` | `var body T; if err := c.Bind(&body); err != nil { ... }` (binds JSON for non-GET) |
| `Form<T>` | `var f T; if err := c.Bind(&f); err != nil { ... }` (Echo Bind handles content-type) |
| `Extension<DbPool>` | `h.DB` from the handler receiver |
| `State<AppState>` | fields on `*Handler` |

### Responses

| Rust | Go (Echo) |
|------|-----------|
| `Json(payload)` | `return c.JSON(http.StatusOK, payload)` |
| `(StatusCode::CREATED, Json(payload))` | `return c.JSON(http.StatusCreated, payload)` |
| `StatusCode::NO_CONTENT` | `return c.NoContent(http.StatusNoContent)` |
| `Redirect::to("/x")` | `return c.Redirect(http.StatusFound, "/x")` |
| `(StatusCode::BAD_REQUEST, "msg")` | `return echo.NewHTTPError(http.StatusBadRequest, "msg")` |
| custom `IntoResponse` for `Error` enum | one Go switch on the error → matching `echo.NewHTTPError` |

### Middleware

| Rust | Go (Echo) |
|------|-----------|
| `tower_http::trace::TraceLayer` | `middleware.Logger()` |
| `tower::ServiceBuilder::layer(...)` chain | `e.Use(...)` calls in order |
| `axum_extra::extract::cookie::SignedCookieJar` | `session.Middleware(sessions.NewCookieStore(...))` from `echo-contrib/session` |
| custom auth extractor | per-route middleware: `e.GET("/x", h.X, RequireUser)` |

## actix-web specifics (if used instead of axum)

| actix | Echo |
|-------|------|
| `web::Path<T>` | `c.Param(...)` |
| `web::Query<T>` | `c.Bind(&q)` |
| `web::Json<T>` | `c.Bind(&body)` |
| `HttpResponse::Ok().json(x)` | `c.JSON(http.StatusOK, x)` |
| `actix_session::Session` | `session.Get("default", c)` |

## anyhow / thiserror → Go errors

- `anyhow::Result<T>` → `(T, error)`. The `?` operator becomes `if err != nil { return ..., err }`.
- `thiserror::Error` enums → in Go, define sentinel errors (`var ErrXxx = errors.New("xxx")`) and check with `errors.Is`. Map each variant to its HTTP status at the boundary, not deep in the call stack.
- `bail!("msg")` → `return ..., fmt.Errorf("msg")`.
- `.context("...")` → `fmt.Errorf("...: %w", err)`.

## bcrypt

| Rust (`bcrypt` crate) | Go (`golang.org/x/crypto/bcrypt`) |
|-----------------------|-----------------------------------|
| `bcrypt::hash(pw, DEFAULT_COST)` | `bcrypt.GenerateFromPassword([]byte(pw), bcrypt.DefaultCost)` |
| `bcrypt::verify(pw, &hash)` | `bcrypt.CompareHashAndPassword([]byte(hash), []byte(pw)) == nil` |

Cost factor must match the Rust app's, or the benchmarker's pre-existing seed users will fail to authenticate.

## UUID

| Rust (`uuid` crate) | Go (`github.com/google/uuid`) |
|---------------------|-------------------------------|
| `Uuid::new_v4()` | `uuid.New()` |
| `uuid.to_string()` | `id.String()` |
| `Uuid::parse_str(s)` | `uuid.Parse(s)` |

## Tokio → Goroutines

- `tokio::spawn(async { ... })` → `go func() { ... }()`. Beware: `*sqlx.DB` is goroutine-safe; raw `*sql.Conn` is not.
- `Arc<Mutex<T>>` → `sync.Mutex` + value, or `sync.Map` if the access pattern fits.
- `tokio::sync::RwLock` → `sync.RWMutex`.
- `tokio::time::sleep` → `time.Sleep`.
- Channels `tokio::sync::mpsc` → `chan T`.

## Logging

Match level. If the Rust app logs at `info`, the Go app should not log at `debug` (more I/O = slower benchmark). Use `log` standard lib for the skeleton; tune later.

## Sessions

The Rust app's session backend determines the cookie format. Common patterns:
- `axum-sessions` with `MemoryStore` → cookie holds session ID, server holds state. Go equivalent: `gorilla/sessions` with a memory store, but **the cookie format will differ** — existing benchmarker cookies will NOT carry over. Acceptable only if the benchmarker logs in fresh each run.
- `tower-sessions` with `CookieStore` (signed cookie holds the data) → Go `gorilla/sessions` `CookieStore` with the **same secret** can read the same cookies — only if the encoding format matches, which is rarely true across libraries. Safer: log in fresh each benchmark run.

If session compatibility matters, port the cookie format faithfully (write a custom Echo middleware that emits the same cookie shape). Otherwise, accept that existing sessions are invalidated at deploy time — the benchmarker will re-login.

## What This File Does NOT Cover

- Project-specific business logic. That is in the per-endpoint analysis.
- Performance tuning. That is in `winning-isucon`.
- Generic Go syntax. Claude already knows it.

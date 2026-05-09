# Echo Base Implementation (Phase 3)

The phase-3 deliverable is a compiling, runnable Go (Echo) skeleton that returns 501 from every endpoint. Phase 4 subagents replace those stubs with real handlers. The skeleton must be in place — and must compile — before phase 4 fires.

## Directory Layout

```
webapp/go/
├── go.mod
├── go.sum
├── main.go             # bootstrap (server + DB + middleware + static + signal)
├── db.go               # sqlx pool init, DSN from env
├── router.go           # ALL routes wired to stubs (single source of truth)
├── handlers/
│   ├── handler.go      # *Handler with shared deps (DB, sessions, etc.)
│   ├── <resource_a>.go # one stub per endpoint, returns 501
│   └── <resource_b>.go
├── models/             # structs translated from Rust DTOs/entities
│   └── <entity>.go
├── middleware/         # session, auth helpers (port from Rust middleware)
│   └── auth.go
└── Makefile            # build, run, deploy targets
```

`systemd/` parallel to `webapp/`:
```
systemd/
└── isu<app>-go.service
```

## go.mod Baseline

Pin the Go version to the AMI's installed version (`go version` on the box). Likely Go 1.22+ for recent ISUCON.

```go
module github.com/<isucon-org>/isu<app>/webapp/go

go 1.22

require (
    github.com/labstack/echo/v4 v4.x
    github.com/labstack/echo-contrib v0.x
    github.com/jmoiron/sqlx v1.x
    github.com/go-sql-driver/mysql v1.x
    github.com/gorilla/sessions v1.x
    github.com/google/uuid v1.x
    golang.org/x/crypto v0.x
)
```

Add only what the Rust app imports equivalents for. Do not pre-add observability libraries — they belong to the tuning skill.

## main.go

```go
package main

import (
    "context"
    "fmt"
    "log"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"

    "github.com/labstack/echo/v4"
    "github.com/labstack/echo/v4/middleware"
    "github.com/labstack/echo-contrib/session"
    "github.com/gorilla/sessions"

    "<module>/handlers"
)

func main() {
    db, err := connectDB()
    if err != nil {
        log.Fatalf("db: %v", err)
    }
    defer db.Close()

    e := echo.New()
    e.HideBanner = true
    e.HidePort = true

    e.Use(middleware.Recover())
    e.Use(middleware.Logger()) // tune verbosity later in winning-isucon
    e.Use(session.Middleware(sessions.NewCookieStore([]byte(os.Getenv("SESSION_SECRET")))))

    h := &handlers.Handler{DB: db}
    registerRoutes(e, h)

    // static files — match the Rust app's mount exactly
    e.Static("/", os.Getenv("FRONTEND_PATH"))
    // SPA fallback if Rust does it
    e.File("/*", os.Getenv("FRONTEND_PATH")+"/index.html")

    addr := fmt.Sprintf(":%s", envOr("PORT", "8080"))
    go func() {
        if err := e.Start(addr); err != nil && err != http.ErrServerClosed {
            log.Fatalf("listen: %v", err)
        }
    }()

    sig := make(chan os.Signal, 1)
    signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
    <-sig
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()
    _ = e.Shutdown(ctx)
}

func envOr(k, d string) string {
    if v := os.Getenv(k); v != "" {
        return v
    }
    return d
}
```

**Match exactly:**
- The listen port the Rust app uses (read from its config or `*-rust.service` env).
- The static file mount path (read from Rust router).
- The session cookie name and key — diverging breaks login on every existing client cookie the benchmarker holds.
- Env var names. If Rust reads `MYSQL_HOST`, Go reads `MYSQL_HOST`, not `DB_HOST`.

## db.go

```go
package main

import (
    "fmt"
    "os"
    "time"

    _ "github.com/go-sql-driver/mysql"
    "github.com/jmoiron/sqlx"
)

func connectDB() (*sqlx.DB, error) {
    dsn := fmt.Sprintf(
        "%s:%s@tcp(%s:%s)/%s?parseTime=true&loc=Local&interpolateParams=true",
        os.Getenv("MYSQL_USER"),
        os.Getenv("MYSQL_PASSWORD"),
        os.Getenv("MYSQL_HOST"),
        envOr("MYSQL_PORT", "3306"),
        os.Getenv("MYSQL_DATABASE"),
    )
    db, err := sqlx.Open("mysql", dsn)
    if err != nil {
        return nil, err
    }
    db.SetMaxOpenConns(20)         // baseline; tune in winning-isucon
    db.SetMaxIdleConns(20)
    db.SetConnMaxLifetime(0)
    if err := db.Ping(); err != nil {
        return nil, err
    }
    // optional: set session timezone to match Rust's, e.g.
    if _, err := db.Exec("SET time_zone = '+00:00'"); err != nil {
        return nil, err
    }
    return db, nil
}
```

Match `parseTime`, `loc`, and timezone behaviour to whatever the Rust crate sets — `chrono` in `sqlx` typically expects UTC.

## router.go (single source of truth)

Phase 3 wires **every** route to a stub. Phase 4 subagents only edit handler bodies. This avoids merge conflicts on `router.go`.

```go
package main

import (
    "github.com/labstack/echo/v4"
    "<module>/handlers"
)

func registerRoutes(e *echo.Echo, h *handlers.Handler) {
    // Auth
    e.POST("/api/login", h.PostLogin)
    e.POST("/api/logout", h.PostLogout)
    e.GET("/api/user/me", h.GetUserMe)

    // ... one line per endpoint from docs/endpoints/INDEX.md ...
}
```

Generate this file mechanically from `INDEX.md` so you do not miss endpoints.

## handlers/handler.go

```go
package handlers

import "github.com/jmoiron/sqlx"

type Handler struct {
    DB *sqlx.DB
}
```

Add fields here as phase 1 reveals shared dependencies (e.g. an HTTP client, a Redis pool). Phase-4 subagents will not add fields here — they only fill bodies.

## Stub Handler Files

For every endpoint, create a stub:

```go
package handlers

import (
    "net/http"
    "github.com/labstack/echo/v4"
)

func (h *Handler) GetUserMe(c echo.Context) error {
    return echo.NewHTTPError(http.StatusNotImplemented, "stub")
}
```

Group by resource (`livestreams.go`, `livecomments.go`, `users.go`) matching how the Rust app groups its handlers. Phase-4 subagents replace each stub body.

## models/

Translate every Rust struct that crosses an API boundary or maps to a DB row.

Rules:
- `db:"column_name"` tags must match the actual MySQL column.
- `json:"field_name"` tags must match the Rust `serde` field name (including `rename_all = "camelCase"`).
- For nullable DB columns, use `sql.NullString`, `sql.NullInt64`, `sql.NullTime`, or `*T` — match the Rust app's choice (`Option<T>` in Rust → `*T` with `omitempty` is usually right for JSON, but a DB read may need `NullX` for the scan and a conversion before serialising).
- Time fields: `time.Time` with `parseTime=true`. If the Rust app uses Unix seconds in JSON, mirror with a custom `MarshalJSON`.

## middleware/auth.go

Port the Rust auth middleware (session lookup, role check, error mapping). Common shape:

```go
package middleware

import (
    "net/http"
    "github.com/labstack/echo/v4"
    "github.com/labstack/echo-contrib/session"
)

func RequireUser(next echo.HandlerFunc) echo.HandlerFunc {
    return func(c echo.Context) error {
        sess, err := session.Get("default", c)
        if err != nil { return echo.NewHTTPError(http.StatusInternalServerError) }
        if _, ok := sess.Values["user_id"]; !ok {
            return echo.NewHTTPError(http.StatusUnauthorized)
        }
        return next(c)
    }
}
```

The session key (`"user_id"`, `"USERID"`, etc.) must match what the Rust app stores — the benchmarker reuses cookies across the session.

## systemd Unit

`systemd/isu<app>-go.service`:

```ini
[Unit]
Description=isu<app> Go
After=network.target mysql.service

[Service]
Type=simple
User=isucon
WorkingDirectory=/home/isucon/webapp/go
EnvironmentFile=/home/isucon/env.sh
ExecStart=/home/isucon/webapp/go/isu<app>
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Match `User=`, `WorkingDirectory=`, and `EnvironmentFile=` to the Rust unit. Different env file = different DB credentials = startup failure.

**Do not** `enable` this unit until phase 5. Keep the Rust unit running through phases 1–4.

## Makefile

```makefile
APP := isu<app>

build:
	go build -o $(APP) .

run:
	./$(APP)

deploy: build
	sudo systemctl restart $(APP)-go.service

vet:
	go vet ./...

.PHONY: build run deploy vet
```

## Verification Before Phase 4

```bash
cd webapp/go
go mod tidy
go build ./...
./isu<app> &
sleep 1
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:<PORT>/api/user/me
# expect: 501
kill %1
```

If any of those steps fail, **fix before phase 4**. A broken skeleton wastes every parallel subagent run.

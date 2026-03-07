# HTTP Integration

Integrate templ components with Go HTTP servers and frameworks.

## templ.Handler

Convert a component to `http.Handler`:

```go
package main

import (
    "net/http"
    "github.com/a-h/templ"
)

func main() {
    // Basic handler
    http.Handle("/", templ.Handler(HomePage()))

    http.ListenAndServe(":8080", nil)
}
```

### Handler Options

```go
// Custom status code
http.Handle("/404", templ.Handler(
    NotFoundPage(),
    templ.WithStatus(http.StatusNotFound),
))

// Custom content type
http.Handle("/xml", templ.Handler(
    XMLPage(),
    templ.WithContentType("application/xml"),
))

// Streaming response
http.Handle("/stream", templ.Handler(
    LargePage(),
    templ.WithStreaming(),
))

// Custom error handler
http.Handle("/", templ.Handler(
    Page(),
    templ.WithErrorHandler(func(r *http.Request, err error) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            log.Printf("Render error: %v", err)
            w.WriteHeader(http.StatusInternalServerError)
            io.WriteString(w, "Error rendering page")
        })
    }),
))
```

## Direct Render

Render components directly in handlers:

```go
func userHandler(w http.ResponseWriter, r *http.Request) {
    userID := r.URL.Query().Get("id")
    user, err := fetchUser(userID)
    if err != nil {
        http.Error(w, "User not found", http.StatusNotFound)
        return
    }

    // Render component directly
    UserPage(user).Render(r.Context(), w)
}

func main() {
    http.HandleFunc("/user", userHandler)
    http.ListenAndServe(":8080", nil)
}
```

### With Error Handling

```go
func handler(w http.ResponseWriter, r *http.Request) {
    data := fetchData()

    err := DataPage(data).Render(r.Context(), w)
    if err != nil {
        log.Printf("Render error: %v", err)
        // Note: headers may already be sent
    }
}
```

## Framework Integration

### Chi

```go
import (
    "github.com/go-chi/chi/v5"
    "github.com/a-h/templ"
)

func main() {
    r := chi.NewRouter()

    r.Get("/", templ.Handler(HomePage()).ServeHTTP)

    r.Get("/users/{id}", func(w http.ResponseWriter, r *http.Request) {
        id := chi.URLParam(r, "id")
        user := fetchUser(id)
        UserPage(user).Render(r.Context(), w)
    })

    http.ListenAndServe(":8080", r)
}
```

### Echo

```go
import (
    "github.com/labstack/echo/v4"
)

func Render(c echo.Context, component templ.Component) error {
    return component.Render(c.Request().Context(), c.Response())
}

func main() {
    e := echo.New()

    e.GET("/", func(c echo.Context) error {
        return Render(c, HomePage())
    })

    e.GET("/users/:id", func(c echo.Context) error {
        id := c.Param("id")
        user := fetchUser(id)
        return Render(c, UserPage(user))
    })

    e.Start(":8080")
}
```

### Gin

```go
import (
    "github.com/gin-gonic/gin"
)

func Render(c *gin.Context, component templ.Component) {
    component.Render(c.Request.Context(), c.Writer)
}

func main() {
    r := gin.Default()

    r.GET("/", func(c *gin.Context) {
        Render(c, HomePage())
    })

    r.GET("/users/:id", func(c *gin.Context) {
        id := c.Param("id")
        user := fetchUser(id)
        Render(c, UserPage(user))
    })

    r.Run(":8080")
}
```

### Fiber

```go
import (
    "github.com/gofiber/fiber/v2"
    "github.com/gofiber/fiber/v2/middleware/adaptor"
)

func main() {
    app := fiber.New()

    app.Get("/", adaptor.HTTPHandler(templ.Handler(HomePage())))

    app.Get("/users/:id", func(c *fiber.Ctx) error {
        id := c.Params("id")
        user := fetchUser(id)

        c.Set("Content-Type", "text/html")
        return UserPage(user).Render(c.Context(), c.Response().BodyWriter())
    })

    app.Listen(":8080")
}
```

## Streaming

Enable streaming for faster Time to First Byte:

```go
// Enable streaming
http.Handle("/", templ.Handler(Page(), templ.WithStreaming()))
```

### Using templ.Flush

```templ
templ StreamingPage(items chan Item) {
    <!DOCTYPE html>
    <html>
        <body>
            for item := range items {
                @templ.Flush() {
                    <div class="item">{ item.Name }</div>
                }
            }
        </body>
    </html>
}
```

## Context Values

### Pass Data via Context

```go
type contextKey string

const userKey contextKey = "user"

func WithUser(ctx context.Context, user User) context.Context {
    return context.WithValue(ctx, userKey, user)
}

func UserFromContext(ctx context.Context) User {
    return ctx.Value(userKey).(User)
}

// In handler
func handler(w http.ResponseWriter, r *http.Request) {
    user := authenticate(r)
    ctx := WithUser(r.Context(), user)
    Page().Render(ctx, w)
}
```

```templ
templ Page() {
    @Header(UserFromContext(ctx))
    <main>Content</main>
}
```

### CSP Nonce

```go
func handler(w http.ResponseWriter, r *http.Request) {
    nonce := generateSecureNonce()
    ctx := templ.WithNonce(r.Context(), nonce)

    w.Header().Set("Content-Security-Policy",
        fmt.Sprintf("script-src 'nonce-%s'", nonce))

    Page().Render(ctx, w)
}
```

## HTMX Fragments

Render partial content for HTMX:

```go
http.Handle("/partial", templ.Handler(
    FullPage(),
    templ.WithFragments("content"),
))
```

```templ
templ FullPage() {
    <!DOCTYPE html>
    <html>
        <body>
            @templ.Fragment("content") {
                <div id="content">
                    Dynamic content here
                </div>
            }
        </body>
    </html>
}
```

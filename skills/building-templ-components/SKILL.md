---
name: building-templ-components
description: Builds type-safe HTML components in Go using templ templating language. Use when creating templ components, defining component parameters, handling children, conditional rendering, loops, CSS styling, JavaScript integration, or setting up templ with HTTP servers.
---

# Building Templ Components

Build type-safe HTML user interfaces in Go with the templ templating language. Templ compiles `.templ` files into Go code, providing compile-time type checking and excellent developer tooling.

**Use this skill when** creating templ components, working with templ syntax, integrating templ with HTTP servers, or setting up templ development workflows.

## Quick Start

### Installation

```bash
go install github.com/a-h/templ/cmd/templ@latest
```

### Basic Component

Create a `.templ` file:

```templ
// hello.templ
package main

templ Hello(name string) {
    <div class="greeting">
        <h1>Hello, { name }!</h1>
    </div>
}
```

Generate Go code:

```bash
templ generate
```

Use in Go:

```go
// main.go
package main

import (
    "net/http"
    "github.com/a-h/templ"
)

func main() {
    http.Handle("/", templ.Handler(Hello("World")))
    http.ListenAndServe(":8080", nil)
}
```

## Core Concepts

### Components

Components are Go functions returning `templ.Component`:

```templ
// Basic component
templ Greeting() {
    <p>Hello!</p>
}

// Component with parameters
templ UserCard(name string, age int) {
    <div class="card">
        <h2>{ name }</h2>
        <p>Age: { strconv.Itoa(age) }</p>
    </div>
}

// Exported component (uppercase)
templ Button(text string) {
    <button type="button">{ text }</button>
}
```

### Expressions

Use `{ }` for Go expressions:

```templ
templ Profile(user User) {
    <h1>{ user.Name }</h1>
    <p>{ fmt.Sprintf("Member since %d", user.Year) }</p>
}
```

### Children

Wrap other components:

```templ
templ Layout(title string) {
    <!DOCTYPE html>
    <html>
        <head><title>{ title }</title></head>
        <body>
            { children... }
        </body>
    </html>
}

// Usage
@Layout("Home") {
    <main>Content here</main>
}
```

### Conditional Rendering

```templ
templ Alert(show bool, message string) {
    if show {
        <div class="alert">{ message }</div>
    }
}

templ Status(level int) {
    if level > 80 {
        <span class="high">High</span>
    } else if level > 40 {
        <span class="medium">Medium</span>
    } else {
        <span class="low">Low</span>
    }
}
```

### Loops

```templ
templ ItemList(items []string) {
    <ul>
        for _, item := range items {
            <li>{ item }</li>
        }
    </ul>
}

templ UserTable(users []User) {
    <table>
        for i, user := range users {
            <tr>
                <td>{ strconv.Itoa(i + 1) }</td>
                <td>{ user.Name }</td>
            </tr>
        }
    </table>
}
```

### Component Composition

```templ
// Call other components with @
templ Page() {
    @Header()
    <main>
        @Sidebar()
        @Content()
    </main>
    @Footer()
}

// Pass components as parameters
templ Card(header templ.Component, body templ.Component) {
    <div class="card">
        <div class="card-header">@header</div>
        <div class="card-body">@body</div>
    </div>
}
```

## CLI Commands

```bash
# Generate Go code from .templ files
templ generate

# Watch mode with live reload
templ generate --watch

# Format templ files
templ fmt .

# Start LSP server (for IDE support)
templ lsp
```

## HTTP Integration

### Using templ.Handler

```go
// Simple handler
http.Handle("/", templ.Handler(HomePage()))

// With status code
http.Handle("/404", templ.Handler(NotFound(), templ.WithStatus(http.StatusNotFound)))

// With streaming
http.Handle("/stream", templ.Handler(LargePage(), templ.WithStreaming()))
```

### Direct Render

```go
func handler(w http.ResponseWriter, r *http.Request) {
    data := fetchData()
    component := DataPage(data)
    component.Render(r.Context(), w)
}
```

## Reference Files

- **Syntax details**: See [SYNTAX.md](references/SYNTAX.md)
- **CSS styling**: See [CSS-STYLING.md](references/CSS-STYLING.md)
- **JavaScript**: See [JAVASCRIPT.md](references/JAVASCRIPT.md)
- **CLI commands**: See [CLI.md](references/CLI.md)
- **HTTP integration**: See [HTTP.md](references/HTTP.md)
- **Best practices**: See [PATTERNS.md](references/PATTERNS.md)

## Common Patterns

### Layout Pattern

```templ
templ Base(title string) {
    <!DOCTYPE html>
    <html lang="en">
        <head>
            <meta charset="UTF-8"/>
            <title>{ title }</title>
        </head>
        <body>
            { children... }
        </body>
    </html>
}

templ HomePage() {
    @Base("Home") {
        <h1>Welcome</h1>
    }
}
```

### Form Pattern

```templ
templ LoginForm(errors map[string]string) {
    <form method="POST" action="/login">
        <label for="email">Email</label>
        <input type="email" id="email" name="email"/>
        if err, ok := errors["email"]; ok {
            <span class="error">{ err }</span>
        }

        <label for="password">Password</label>
        <input type="password" id="password" name="password"/>
        if err, ok := errors["password"]; ok {
            <span class="error">{ err }</span>
        }

        <button type="submit">Login</button>
    </form>
}
```

### HTMX Integration

```templ
templ SearchButton() {
    <button
        hx-get="/search"
        hx-target="#results"
        hx-trigger="click"
    >
        Search
    </button>
    <div id="results"></div>
}
```
